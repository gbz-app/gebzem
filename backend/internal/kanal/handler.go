package kanal

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 75 — KANAL (WhatsApp "Kanallar" deseni: TEK YONLU yayin).
//
// ═══════════ NEDEN AYRI HAT (mimari karar) ═══════════
// `chats.type` CHECK'i 'channel'i zaten kabul ediyor ama mevcut mesaj hatti
// kanal olceginde CALISMAZ — kod okunarak dogrulandi:
//
//	· `chat.SendMessage` her mesajda UYE BASINA AYRI `INSERT INTO
//	  message_receipts` yapiyor (dongu icinde, her biri ayri sorgu).
//	  10.000 aboneli kanalda TEK gonderi = 10.000 sorgu.
//	· `hub.Publish(To: members)` + `push.NotifyUsers(members, ...)` ayni
//	  10.000 elemanli diziyi tasiyor.
//	· `ListChats` okunmamis sayisini `message_receipts` COUNT(*) ile buluyor.
//	· Ustelik kanalda OKUNDU BILGISI zaten ISTENMIYOR (WhatsApp kanallarinda tik
//	  yok, yalniz toplam goruntulenme var) — yani o satirlarin urun karsiligi YOK.
//
// COZUM: OKUMA ZAMANI fan-out. Okunmamis sayisi (kanal,kullanici) basina TEK
// damgadan (`son_okuma`) hesaplanir.
// ⚠️ YAPMA: kanali `messages`/`message_receipts` hattina tasima.
//
// ═══════════ PUSH ═══════════
// ⚠️ Kanal gonderisinde push GONDERILMIYOR (bilincli, ILK SURUM).
//
//	Sebep: `push.NotifyUsers` tum aliciyi TEK cagrida isliyor; 10.000 aboneli
//	kanalda bu istek is parcaciginda saniyelerce takilir ve FCM kota siniri
//	(500 hedef/toplu istek) asilir. Dogrusu parcali + kuyruklu gonderim —
//	AYRI IS. Kullanici uygulamayi acinca okunmamis rozetini gorur.
//
// ⚠️ YAPMA: buraya duz `NotifyUsers(aboneler, ...)` ekleme.
type Handler struct {
	db *pgxpool.Pool
}

func NewHandler(db *pgxpool.Pool) *Handler { return &Handler{db: db} }

// @kanaladi kurallari: 3-24, kucuk harf/rakam/alt cizgi.
// ⚠️ `users.username` ile AYNI HAVUZDA DEGIL — kanal ve kisi ayri ad uzaylari.
//
//	Birlestirmek `users` uzerinde kilit yarisi ve goc riski demek olurdu.
var kullaniciAdiDesen = regexp.MustCompile(`^[a-z0-9_]{3,24}$`)

// ---------------------------------------------------------------- KANAL

type kanalReq struct {
	Ad            string `json:"ad"`
	KullaniciAdi  string `json:"kullanici_adi"`
	Aciklama      string `json:"aciklama"`
	AvatarMediaID string `json:"avatar_media_id"`
}

// POST /channels — kanal olustur. Olusturan OTOMATIK yetkili + abone olur.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req kanalReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Ad = strings.TrimSpace(req.Ad)
	if len([]rune(req.Ad)) < 2 || len([]rune(req.Ad)) > 60 {
		hata(w, 400, "kanal adı 2-60 karakter olmalı")
		return
	}
	req.KullaniciAdi = strings.ToLower(strings.TrimSpace(req.KullaniciAdi))
	if req.KullaniciAdi != "" && !kullaniciAdiDesen.MatchString(req.KullaniciAdi) {
		hata(w, 400, "kanal adresi 3-24 karakter olmalı (a-z, 0-9, _)")
		return
	}
	if len([]rune(req.Aciklama)) > 500 {
		req.Aciklama = string([]rune(req.Aciklama)[:500])
	}
	if !h.medyaSahibiMi(r.Context(), me, req.AvatarMediaID) {
		hata(w, 403, "geçersiz medya")
		return
	}

	// ⚠️ KANAL SAYISI SINIRI: sinirsiz kanal acmak spam kapisidir (bir hesap
	//    binlerce kanal acip kesfeti doldurabilir).
	var mevcut int
	h.db.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM channels WHERE owner_id=$1 AND durum<>'kapali'`, me).Scan(&mevcut)
	if mevcut >= 10 {
		hata(w, 400, "en fazla 10 kanal açabilirsiniz")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "kanal oluşturulamadı")
		return
	}
	defer tx.Rollback(r.Context())

	var id string
	var kadi any
	if req.KullaniciAdi != "" {
		kadi = req.KullaniciAdi
	}
	var mid any
	if req.AvatarMediaID != "" {
		mid = req.AvatarMediaID
	}
	err = tx.QueryRow(r.Context(), `
		INSERT INTO channels (owner_id, ad, kullanici_adi, aciklama, avatar_media_id, abone_sayisi)
		VALUES ($1,$2,$3,$4,$5,1) RETURNING id`,
		me, req.Ad, kadi, req.Aciklama, mid).Scan(&id)
	if err != nil {
		// ⚠️ UNIQUE ihlali KULLANICI HATASI (500 degil) — "bu adres alınmış".
		if strings.Contains(err.Error(), "channels_kullanici_adi_key") ||
			strings.Contains(err.Error(), "duplicate key") {
			hata(w, 409, "bu kanal adresi alınmış")
			return
		}
		log.Printf("kanal insert: %v", err)
		hata(w, 500, "kanal oluşturulamadı")
		return
	}
	// ⚠️ Sahibi HEM yetkili HEM abone: aksi halde kendi kanalini "Kanallarım"
	//    listesinde GOREMEZ (o liste abonelikten okunuyor).
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO channel_admins (channel_id, user_id) VALUES ($1,$2)`, id, me); err != nil {
		hata(w, 500, "kanal oluşturulamadı")
		return
	}
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO channel_subscribers (channel_id, user_id) VALUES ($1,$2)`, id, me); err != nil {
		hata(w, 500, "kanal oluşturulamadı")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "kanal oluşturulamadı")
		return
	}
	yaz(w, 201, map[string]any{"id": id})
}

// PATCH /channels/{id} — kanal bilgilerini duzenle (YALNIZ sahibi).
func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !h.sahipMi(r.Context(), me, id) {
		hata(w, 403, "bu işlem için yetkiniz yok")
		return
	}
	var req kanalReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Ad = strings.TrimSpace(req.Ad)
	if len([]rune(req.Ad)) < 2 || len([]rune(req.Ad)) > 60 {
		hata(w, 400, "kanal adı 2-60 karakter olmalı")
		return
	}
	if len([]rune(req.Aciklama)) > 500 {
		req.Aciklama = string([]rune(req.Aciklama)[:500])
	}
	// ⚠️ Avatar DEGISTIRILMEK ISTENMIYORSA (bos gelirse) MEVCUDU KORU —
	//    `COALESCE(NULLIF($3,''), avatar_media_id::text)::uuid` yerine acik dal:
	//    okunabilirlik + yanlislikla avatari silmeyi engeller.
	if req.AvatarMediaID != "" {
		if !h.medyaSahibiMi(r.Context(), me, req.AvatarMediaID) {
			hata(w, 403, "geçersiz medya")
			return
		}
		h.db.Exec(r.Context(), `UPDATE channels SET avatar_media_id=$2 WHERE id=$1`,
			id, req.AvatarMediaID)
	}
	if _, err := h.db.Exec(r.Context(),
		`UPDATE channels SET ad=$2, aciklama=$3 WHERE id=$1`,
		id, req.Ad, req.Aciklama); err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// DELETE /channels/{id} — kanali kapat (YALNIZ sahibi).
// ⚠️ Satir SILINMEZ (`durum='kapali'`): gonderiler, begeniler ve abonelik
//
//	gecmisi FK ile bagli; fiziksel silme veri kaybi + FK zinciri demek.
//	Ayrica kullanici karari: VERI SILINMEZ.
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !h.sahipMi(r.Context(), me, id) {
		hata(w, 403, "bu işlem için yetkiniz yok")
		return
	}
	h.db.Exec(r.Context(), `UPDATE channels SET durum='kapali' WHERE id=$1`, id)
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /channels/{id} — kanal detayi.
func (h *Handler) Detay(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if len(id) != 36 {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	var k kanalOzet
	var durum string
	err := h.db.QueryRow(r.Context(), `
		SELECT c.id, c.ad, COALESCE(c.kullanici_adi,''), c.aciklama,
		       c.avatar_media_id, c.abone_sayisi, c.gonderi_sayisi, c.durum,
		       c.owner_id,
		       EXISTS(SELECT 1 FROM channel_subscribers s
		               WHERE s.channel_id=c.id AND s.user_id=$2),
		       EXISTS(SELECT 1 FROM channel_admins a
		               WHERE a.channel_id=c.id AND a.user_id=$2),
		       -- ⚠️ TURU 75b (DENETIM): sessiz alani DONMUYORDU. Istemci onu
		       -- okuyor; yok oldugu icin DAIMA false geliyordu -> kanali sessize
		       -- alan kullanici ekrani tekrar acinca menude yine "Sessize al"
		       -- goruyor ve basinca sunucuya sessiz=true yaziliyordu:
		       -- SESI BIR DAHA ACAMIYORDU.
		       -- ⚠️ LEFT JOIN degil skaler alt sorgu: abone OLMAYAN da detayi gorebilir.
		       COALESCE((SELECT s2.sessiz FROM channel_subscribers s2
		                  WHERE s2.channel_id=c.id AND s2.user_id=$2), false)
		  FROM channels c WHERE c.id=$1`, id, me).
		Scan(&k.ID, &k.Ad, &k.KullaniciAdi, &k.Aciklama, &k.AvatarMediaID,
			&k.AboneSayisi, &k.GonderiSayisi, &durum, &k.SahipID,
			&k.AboneMiyim, &k.YetkiliMiyim, &k.Sessiz)
	if err != nil {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	// ⚠️ Kapali kanal SAHIBINE gorunur (geri acabilsin/gecmisi gorsun),
	//    baskasina 404. "Silindi" demek yerine bulunamadi demek dogru:
	//    kanalin VAR OLDUGU bilgisi de bir bilgidir.
	if durum != "aktif" && k.SahipID != me {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	yaz(w, 200, map[string]any{
		"id": k.ID, "ad": k.Ad, "kullanici_adi": k.KullaniciAdi,
		"aciklama": k.Aciklama, "avatar_media_id": k.AvatarMediaID,
		"abone_sayisi": k.AboneSayisi, "gonderi_sayisi": k.GonderiSayisi,
		"durum": durum, "sahip_id": k.SahipID,
		"abone_miyim": k.AboneMiyim, "yetkili_miyim": k.YetkiliMiyim,
		"sessiz": k.Sessiz,
	})
}

type kanalOzet struct {
	ID, Ad, KullaniciAdi, Aciklama, SahipID string
	AvatarMediaID                           *string
	AboneSayisi, GonderiSayisi              int
	AboneMiyim, YetkiliMiyim, Sessiz        bool
}

// GET /channels — abone oldugum kanallar + OKUNMAMIS sayisi.
//
// ⚠️ OKUNMAMIS SAYIMI BURADA: (mesaj,kullanici) satiri OLMADAN, `son_okuma`
//
//	damgasindan sonraki gonderiler sayilir. `idx_kanal_gonderi` bu sorguyu
//	index'ten karsilar.
func (h *Handler) Listem(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT c.id, c.ad, COALESCE(c.kullanici_adi,''), c.avatar_media_id,
		       c.abone_sayisi, s.sessiz,
		       (SELECT COUNT(*) FROM channel_posts p
		         WHERE p.channel_id=c.id AND p.durum='yayinda'
		           AND p.created_at > s.son_okuma) AS okunmamis,
		       COALESCE((SELECT p2.metin FROM channel_posts p2
		         WHERE p2.channel_id=c.id AND p2.durum='yayinda'
		         ORDER BY p2.created_at DESC LIMIT 1), '') AS son_metin,
		       (SELECT p3.created_at FROM channel_posts p3
		         WHERE p3.channel_id=c.id AND p3.durum='yayinda'
		         ORDER BY p3.created_at DESC LIMIT 1) AS son_zaman,
		       EXISTS(SELECT 1 FROM channel_admins a
		               WHERE a.channel_id=c.id AND a.user_id=$1) AS yetkili
		  FROM channel_subscribers s
		  JOIN channels c ON c.id = s.channel_id
		 WHERE s.user_id=$1 AND c.durum='aktif'
		 ORDER BY son_zaman DESC NULLS LAST`, me)
	if err != nil {
		log.Printf("kanal listem: %v", err)
		hata(w, 500, "kanallar alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kadi, sonMetin string
		var medya *string
		var abone, okunmamis int
		var sessiz, yetkili bool
		var sonZaman *time.Time
		if rows.Scan(&id, &ad, &kadi, &medya, &abone, &sessiz, &okunmamis,
			&sonMetin, &sonZaman, &yetkili) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "ad": ad, "kullanici_adi": kadi, "avatar_media_id": medya,
			"abone_sayisi": abone, "sessiz": sessiz, "okunmamis": okunmamis,
			"son_metin": sonMetin, "son_zaman": sonZaman, "yetkili_miyim": yetkili,
		})
	}
	yaz(w, 200, out)
}

// GET /channels/kesfet?q= — kanal kesfet/arama.
func (h *Handler) Kesfet(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	q := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))
	var rows pgx.Rows
	var err error
	if q == "" {
		rows, err = h.db.Query(r.Context(), `
			SELECT c.id, c.ad, COALESCE(c.kullanici_adi,''), c.aciklama,
			       c.avatar_media_id, c.abone_sayisi,
			       EXISTS(SELECT 1 FROM channel_subscribers s
			               WHERE s.channel_id=c.id AND s.user_id=$1)
			  FROM channels c
			 WHERE c.durum='aktif' AND c.owner_id <> $1
			   AND NOT EXISTS(SELECT 1 FROM channel_subscribers s
			         WHERE s.channel_id=c.id AND s.user_id=$1)
			 ORDER BY c.abone_sayisi DESC, c.created_at DESC LIMIT 30`, me)
	} else {
		// ⚠️ Arama HEM ada HEM adrese bakar. `LIKE 'x%'` (ON EK) secildi:
		//    '%x%' index KULLANAMAZ ve tam tarama yapar.
		rows, err = h.db.Query(r.Context(), `
			SELECT c.id, c.ad, COALESCE(c.kullanici_adi,''), c.aciklama,
			       c.avatar_media_id, c.abone_sayisi,
			       EXISTS(SELECT 1 FROM channel_subscribers s
			               WHERE s.channel_id=c.id AND s.user_id=$1)
			  FROM channels c
			 WHERE c.durum='aktif' AND c.owner_id <> $1
			   AND (LOWER(c.ad) LIKE $2 || '%' OR c.kullanici_adi LIKE $2 || '%')
			 ORDER BY c.abone_sayisi DESC LIMIT 30`, me, q)
	}
	if err != nil {
		log.Printf("kanal kesfet: %v", err)
		hata(w, 500, "kanallar alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kadi, aciklama string
		var medya *string
		var abone int
		var aboneMiyim bool
		if rows.Scan(&id, &ad, &kadi, &aciklama, &medya, &abone, &aboneMiyim) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "ad": ad, "kullanici_adi": kadi, "aciklama": aciklama,
			"avatar_media_id": medya, "abone_sayisi": abone,
			"abone_miyim": aboneMiyim,
		})
	}
	yaz(w, 200, out)
}

// POST /channels/{id}/subscribe — abone ol. IDEMPOTENT.
func (h *Handler) Subscribe(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if len(id) != 36 {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	var durum string
	if h.db.QueryRow(r.Context(), `SELECT durum FROM channels WHERE id=$1`, id).
		Scan(&durum) != nil {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	if durum != "aktif" {
		hata(w, 400, "bu kanal kapalı")
		return
	}
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "abone olunamadı")
		return
	}
	defer tx.Rollback(r.Context())
	// ⚠️ IDEMPOTENT: `RowsAffected()==1` ise GERCEKTEN yeni satir acildi ->
	//    sayac YALNIZ o zaman artar (cift dokunusta iki kez artmaz).
	tag, err := tx.Exec(r.Context(), `
		INSERT INTO channel_subscribers (channel_id, user_id) VALUES ($1,$2)
		ON CONFLICT DO NOTHING`, id, me)
	if err != nil {
		hata(w, 500, "abone olunamadı")
		return
	}
	if tag.RowsAffected() == 1 {
		tx.Exec(r.Context(),
			`UPDATE channels SET abone_sayisi = abone_sayisi + 1 WHERE id=$1`, id)
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "abone olunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// DELETE /channels/{id}/subscribe — abonelikten cik. IDEMPOTENT.
func (h *Handler) Unsubscribe(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	// ⚠️ SAHIP KENDI KANALINDAN CIKAMAZ: cikarsa kanali "Kanallarım"da bir daha
	//    goremez ve yonetemez (liste abonelikten okunuyor).
	if h.sahipMi(r.Context(), me, id) {
		hata(w, 400, "kendi kanalınızdan çıkamazsınız")
		return
	}
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	defer tx.Rollback(r.Context())
	tag, err := tx.Exec(r.Context(),
		`DELETE FROM channel_subscribers WHERE channel_id=$1 AND user_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	if tag.RowsAffected() == 1 {
		// ⚠️ GREATEST(...,0): sayac negatife DUSMESIN (gecmis tutarsizliklar
		//    urunu bozmasin — turu 75 takip sisteminde alinan ayni onlem).
		tx.Exec(r.Context(),
			`UPDATE channels SET abone_sayisi = GREATEST(abone_sayisi - 1, 0) WHERE id=$1`, id)
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// PATCH /channels/{id}/mute — sessize al / ac.
func (h *Handler) Mute(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var req struct {
		Sessiz bool `json:"sessiz"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	h.db.Exec(r.Context(),
		`UPDATE channel_subscribers SET sessiz=$3 WHERE channel_id=$1 AND user_id=$2`,
		id, me, req.Sessiz)
	yaz(w, 200, map[string]bool{"ok": true})
}

// POST /channels/{id}/read — okundu isaretle (rozet sifirlanir).
func (h *Handler) Read(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	h.db.Exec(r.Context(),
		`UPDATE channel_subscribers SET son_okuma=now() WHERE channel_id=$1 AND user_id=$2`,
		id, me)
	yaz(w, 200, map[string]bool{"ok": true})
}

// ---------------------------------------------------------------- GONDERI

type kanalGonderiReq struct {
	Metin    string   `json:"metin"`
	MediaIDs []string `json:"media_ids"`
}

// POST /channels/{id}/posts — kanala gonderi (YALNIZ yetkililer).
func (h *Handler) PostOlustur(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !h.yetkiliMi(r.Context(), me, id) {
		hata(w, 403, "bu kanala gönderi paylaşamazsınız")
		return
	}
	var req kanalGonderiReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Metin = strings.TrimSpace(req.Metin)
	// ⚠️ TUTARLILIK: hem metin hem medya bossa BOS KART cizilir.
	if req.Metin == "" && len(req.MediaIDs) == 0 {
		hata(w, 400, "boş gönderi paylaşılamaz")
		return
	}
	if len([]rune(req.Metin)) > 4000 {
		req.Metin = string([]rune(req.Metin)[:4000])
	}
	if len(req.MediaIDs) > 10 {
		hata(w, 400, "en fazla 10 medya")
		return
	}
	// ⚠️⚠️ nil KAPISI: istemci `media_ids` alanini HIC gondermezse Go tarafinda
	//    dilim `nil` olur ve pgx bunu SQL **NULL** olarak yollar;
	//    `channel_posts.media_ids` ise **NOT NULL** -> INSERT PATLAR.
	//    (Bizim Flutter istemcisi alani hep gonderiyor ama sunucu istemciye
	//     GUVENEMEZ.) Kanit: internal/social/tip_test.go
	// ⚠️ YAPMA: bu kapiyi kaldirma.
	if req.MediaIDs == nil {
		req.MediaIDs = []string{}
	}
	// ⚠️⚠️ MEDYA SAHIPLIGI (gonderi/mesaj tarafiyla AYNI kural): baskasinin
	//    medya id'sini baglamak ya da 'beklemede' kaydi yayinlamak ENGELLI.
	if len(req.MediaIDs) > 0 {
		tag, err := h.db.Exec(r.Context(), `
			UPDATE media_assets SET status='bagli', linked_at=now()
			 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
			req.MediaIDs, me)
		if err != nil || int(tag.RowsAffected()) != len(req.MediaIDs) {
			hata(w, 403, "geçersiz medya")
			return
		}
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "gönderi paylaşılamadı")
		return
	}
	defer tx.Rollback(r.Context())

	var pid int64
	var t time.Time
	if err := tx.QueryRow(r.Context(), `
		INSERT INTO channel_posts (channel_id, author_id, metin, media_ids)
		VALUES ($1,$2,$3,$4) RETURNING id, created_at`,
		id, me, req.Metin, req.MediaIDs).Scan(&pid, &t); err != nil {
		log.Printf("kanal gonderi: %v", err)
		hata(w, 500, "gönderi paylaşılamadı")
		return
	}
	tx.Exec(r.Context(),
		`UPDATE channels SET gonderi_sayisi = gonderi_sayisi + 1 WHERE id=$1`, id)
	// ⚠️ YAZARIN KENDI ROZETI ANMASIN: yetkili paylastigi anda kendi `son_okuma`
	//    damgasi ILERLETILIR, yoksa kendi gonderisi ona "okunmamis" gorunur.
	tx.Exec(r.Context(),
		`UPDATE channel_subscribers SET son_okuma=now() WHERE channel_id=$1 AND user_id=$2`,
		id, me)
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "gönderi paylaşılamadı")
		return
	}
	yaz(w, 201, map[string]any{"id": pid, "created_at": t})
}

// GET /channels/{id}/posts?before= — kanal gonderileri (IMLEC sayfalama).
func (h *Handler) Postlar(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if len(id) != 36 {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	// ⚠️ Kapali kanalin gonderileri yalniz SAHIBINE.
	var durum, sahip string
	if h.db.QueryRow(r.Context(), `SELECT durum, owner_id FROM channels WHERE id=$1`, id).
		Scan(&durum, &sahip) != nil {
		hata(w, 404, "kanal bulunamadı")
		return
	}
	if durum != "aktif" && sahip != me {
		hata(w, 404, "kanal bulunamadı")
		return
	}

	limit := 20
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 50 {
		limit = v
	}
	before := time.Now().Add(time.Hour)
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.metin, p.media_ids, p.begeni_sayisi, p.goruntulenme,
		       p.created_at, p.author_id, u.name,
		       EXISTS(SELECT 1 FROM channel_post_likes l
		               WHERE l.post_id=p.id AND l.user_id=$2)
		  FROM channel_posts p JOIN users u ON u.id = p.author_id
		 WHERE p.channel_id=$1 AND p.durum='yayinda' AND p.created_at < $3
		 ORDER BY p.created_at DESC LIMIT $4`, id, me, before, limit)
	if err != nil {
		log.Printf("kanal postlar: %v", err)
		hata(w, 500, "gönderiler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	idler := []int64{}
	for rows.Next() {
		var pid int64
		var metin, yazarID, yazarAd string
		var medya []string
		var begeni, goruntulenme int
		var t time.Time
		var begendim bool
		if rows.Scan(&pid, &metin, &medya, &begeni, &goruntulenme, &t,
			&yazarID, &yazarAd, &begendim) != nil {
			continue
		}
		idler = append(idler, pid)
		out = append(out, map[string]any{
			"id": pid, "metin": metin, "media_ids": medya,
			"begeni_sayisi": begeni, "goruntulenme": goruntulenme,
			"created_at": t, "yazar_id": yazarID, "yazar_ad": yazarAd,
			"begendim": begendim,
		})
	}
	// ⚠️ GORUNTULENME TEK SORGUDA (`= ANY`) artirilir — gonderi basina UPDATE
	//    yapmak sayfa basina 20 yazma demek olurdu.
	// ⚠️ Sayim KABA (ayni kullanici tekrar bakinca yine artar). Kesin tekil
	//    sayim (kullanici,gonderi) satiri gerektirir ve tam da kacindigimiz
	//    yazma yukunu geri getirir. WhatsApp da kaba sayar.
	if len(idler) > 0 {
		h.db.Exec(r.Context(),
			`UPDATE channel_posts SET goruntulenme = goruntulenme + 1 WHERE id = ANY($1)`,
			idler)
	}
	yaz(w, 200, map[string]any{"posts": out})
}

// DELETE /channel-posts/{id} — gonderiyi kaldir (yazar VEYA kanal sahibi).
func (h *Handler) PostSil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	pid, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		hata(w, 400, "geçersiz gönderi")
		return
	}
	var kanalID, yazar, sahip string
	if h.db.QueryRow(r.Context(), `
		SELECT p.channel_id, p.author_id, c.owner_id
		  FROM channel_posts p JOIN channels c ON c.id=p.channel_id
		 WHERE p.id=$1 AND p.durum='yayinda'`, pid).
		Scan(&kanalID, &yazar, &sahip) != nil {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	// ⚠️ KANAL SAHIBI DE SILEBILIR — yetkilisinin paylastigi uygunsuz icerigi
	//    kaldirabilmeli (App Store 1.2).
	if yazar != me && sahip != me {
		hata(w, 403, "bu işlem için yetkiniz yok")
		return
	}
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	defer tx.Rollback(r.Context())
	// ⚠️ Satir SILINMEZ: begeni FK'si ve istatistikler bozulmasin.
	// ⚠️⚠️ TURU 75b (DENETIM): `RETURNING media_ids` ZORUNLU — UPDATE dizi
	//    uzerine `{}` yaziyor, yani ONCEKI degeri BURADA yakalamazsak id'ler
	//    SONSUZA KADAR KAYBOLUR ve R2'deki nesneler YETIM kalir (kalici depolama
	//    sizintisi; "veri silinmez" karari YETIM DOSYA demek degildir).
	// ⚠️⚠️ Hatalar ARTIK YUTULMUYOR: eskiden `tx.Exec(...)` donusu `_` ile atiliyor
	//    ve `tx.Commit` hic kontrol edilmiyordu -> transaction ABORT olsa bile
	//    istemciye KOSULSUZ `{"ok":true}` yaziliyordu (kullanici "sildim" sanip
	//    gonderiyi ekranda gormeye devam ederdi).
	var eskiMedya []string
	err = tx.QueryRow(r.Context(),
		`UPDATE channel_posts SET durum='silindi', metin='', media_ids='{}'
		  WHERE id=$1 AND durum='yayinda' RETURNING media_ids`, pid).Scan(&eskiMedya)
	if err == pgx.ErrNoRows {
		// Baska bir istek onceden sildi — idempotent kabul et.
		yaz(w, 200, map[string]bool{"ok": true})
		return
	}
	if err != nil {
		log.Printf("kanal gonderi sil: %v", err)
		hata(w, 500, "silinemedi")
		return
	}
	if _, err := tx.Exec(r.Context(),
		`UPDATE channels SET gonderi_sayisi = GREATEST(gonderi_sayisi - 1, 0) WHERE id=$1`,
		kanalID); err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	// ⚠️ Medya dusurme COMMIT'TEN SONRA: transaction geri alinirsa gonderi
	//    yasamaya devam ederken medyasini silmis olurduk.
	for _, m := range eskiMedya {
		h.medyayiKopar(r.Context(), m)
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// medyayiKopar — kanal gonderisi silinince medyayi dusur (BASKA YERE BAGLI DEGILSE).
//
// ⚠️⚠️ REFERANS SAYIMI `social.medyayiKopar` ILE AYNI KUMEYI TARAMALI. Iki
//
//	sayimin ayrismasi "hala kullanilan medya silindi" demektir — bu yuzden
//	kume burada da TAM yazildi (messages + users.avatar + posts + channel_posts
//	+ channels.avatar).
//
// ⚠️ YAPMA: kumeyi daraltma; yeni bir medya tuketicisi eklersen IKI yere de ekle.
func (h *Handler) medyayiKopar(ctx context.Context, mediaID string) {
	var kalan int
	if err := h.db.QueryRow(ctx, `
		SELECT (SELECT count(*) FROM messages WHERE media_id=$1)
		     + (SELECT count(*) FROM users WHERE avatar_media_id=$1)
		     + (SELECT count(*) FROM posts
		         WHERE $1 = ANY(media_ids) AND durum='yayinda')
		     + (SELECT count(*) FROM channel_posts
		         WHERE $1 = ANY(media_ids) AND durum='yayinda')
		     + (SELECT count(*) FROM channels WHERE avatar_media_id=$1)`,
		mediaID).Scan(&kalan); err != nil || kalan > 0 {
		return
	}
	var anahtar, thumb string
	if err := h.db.QueryRow(ctx, `
		UPDATE media_assets SET status='silindi', deleted_at=now()
		 WHERE id=$1 AND status IN ('aktif','bagli')
		 RETURNING object_key, thumb_key`, mediaID).Scan(&anahtar, &thumb); err != nil {
		return
	}
	// ⚠️ R2 silme KUYRUGA yazilir (015'in `media_delete_queue` tablosu) —
	//    istek yolunda ag cagrisi yapmiyoruz.
	for _, a := range []string{anahtar, thumb} {
		if a != "" {
			h.db.Exec(ctx,
				`INSERT INTO media_delete_queue (object_key) VALUES ($1)`, a)
		}
	}
}

// POST /channel-posts/{id}/like — begen. IDEMPOTENT.
func (h *Handler) Like(w http.ResponseWriter, r *http.Request) {
	h.begeniIslem(w, r, true)
}

// DELETE /channel-posts/{id}/like — begeniyi geri al. IDEMPOTENT.
func (h *Handler) Unlike(w http.ResponseWriter, r *http.Request) {
	h.begeniIslem(w, r, false)
}

// ⚠️ TEK KAYNAK: begen ve geri al AYNI govdeyi kullanir (drift etmesin).
func (h *Handler) begeniIslem(w http.ResponseWriter, r *http.Request, ekle bool) {
	me := auth.UserID(r.Context())
	pid, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		hata(w, 400, "geçersiz gönderi")
		return
	}
	// ⚠️ ERISIM KAPISI: yalniz ABONELER begenebilir. Aksi halde herkes herhangi
	//    bir kanalin gonderisini begenip sayaci sisirebilirdi.
	var abone bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM channel_posts p
		  JOIN channel_subscribers s ON s.channel_id = p.channel_id
		 WHERE p.id=$1 AND s.user_id=$2 AND p.durum='yayinda')`, pid, me).Scan(&abone)
	if !abone {
		hata(w, 403, "bu gönderiye erişiminiz yok")
		return
	}
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	defer tx.Rollback(r.Context())
	var tag int64
	if ekle {
		t, e := tx.Exec(r.Context(),
			`INSERT INTO channel_post_likes (post_id, user_id) VALUES ($1,$2)
			 ON CONFLICT DO NOTHING`, pid, me)
		if e != nil {
			hata(w, 500, "işlem yapılamadı")
			return
		}
		tag = t.RowsAffected()
		if tag == 1 {
			tx.Exec(r.Context(),
				`UPDATE channel_posts SET begeni_sayisi = begeni_sayisi + 1 WHERE id=$1`, pid)
		}
	} else {
		t, e := tx.Exec(r.Context(),
			`DELETE FROM channel_post_likes WHERE post_id=$1 AND user_id=$2`, pid, me)
		if e != nil {
			hata(w, 500, "işlem yapılamadı")
			return
		}
		if t.RowsAffected() == 1 {
			tx.Exec(r.Context(),
				`UPDATE channel_posts SET begeni_sayisi = GREATEST(begeni_sayisi - 1, 0) WHERE id=$1`, pid)
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// ---------------------------------------------------------------- YARDIMCI

func (h *Handler) sahipMi(ctx context.Context, me, kanalID string) bool {
	if len(kanalID) != 36 {
		return false
	}
	var v bool
	h.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM channels WHERE id=$1 AND owner_id=$2)`,
		kanalID, me).Scan(&v)
	return v
}

// ⚠️ Yetkili = `channel_admins`ta satiri olan. Sahibi kanal olusturulurken
//
//	buraya YAZILIR, bu yuzden ayrica `owner_id` kontrolu gerekmez.
func (h *Handler) yetkiliMi(ctx context.Context, me, kanalID string) bool {
	if len(kanalID) != 36 {
		return false
	}
	var v bool
	h.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM channel_admins a
		  JOIN channels c ON c.id = a.channel_id
		 WHERE a.channel_id=$1 AND a.user_id=$2 AND c.durum='aktif')`,
		kanalID, me).Scan(&v)
	return v
}

// ⚠️ Medya sahipligi: avatar da olsa istemciden gelen id DOGRULANIR
//
//	(turu 74 `avatar_url` guvenlik dersi).
func (h *Handler) medyaSahibiMi(ctx context.Context, me, mediaID string) bool {
	if mediaID == "" {
		return true // medya verilmemis — gecerli
	}
	if len(mediaID) != 36 {
		return false
	}
	tag, err := h.db.Exec(ctx, `
		UPDATE media_assets SET status='bagli', linked_at=now()
		 WHERE id=$1 AND owner_id=$2 AND status IN ('aktif','bagli')`, mediaID, me)
	return err == nil && tag.RowsAffected() == 1
}

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, msg string) {
	yaz(w, kod, map[string]string{"error": msg})
}
