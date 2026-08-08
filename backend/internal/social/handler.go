package social

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 75 — GONDERI + ANA SAYFA AKISI.
//
// ═══════════ FAN-OUT KARARI: **READ-TIME (okurken birlestir)** ═══════════
//
// Uc secenek vardi:
//   (a) WRITE-TIME fan-out — her gonderi TUM takipcilerin kutusuna KOPYALANIR.
//   (b) READ-TIME fan-out  — okurken "takip ettiklerimin gonderileri" sorgulanir.
//   (c) HIBRIT — cok takipcililer read-time, digerleri write-time.
//
// **(b) SECILDI.** Gerekce:
//  · OLCEK: 50K kullanici hedefi. Write-time fan-out'un TEK avantaji cok yuksek
//    okuma/yazma oraninda ortaya cikar; bizim olcegimizde `posts` tablosu
//    milyonlarca satira bile ulasmaz ve `(created_at DESC)` kismi index'i
//    siralamayi index'ten karsilar.
//  · MALIYET: write-time fan-out, 10.000 takipcisi olan biri gonderi atinca
//    10.000 SATIR YAZAR. cx33'te Postgres LiveKit ile AYNI 4 vCPU'yu paylasiyor;
//    bu yazma firtinasi SFU'yu ac birakir. Okuma tarafi ise sayfa basina TEK
//    sorgu.
//  · GERI DONULEBILIRLIK: read-time'dan hibrite gecmek KOLAY (kutu tablosu
//    eklenir); tersi zordur (kutular tutarsiz kalir, yeniden doldurmak gerekir).
//    Yani UCUZ olani once secip olcumle buyumek dogru sira.
// ⚠️ YAPMA: olcum gormeden write-time fan-out'a gecme. Once `EXPLAIN ANALYZE`
//    ile akis sorgusunun sahadaki suresine bak.
//
// ═══════════ SIRALAMA: **KRONOLOJIK** ═══════════
// Algoritmik siralama SOGUK BASLANGIC sorununu COZMEZ, saklar. Prototipte
// kullanici sayisi azken algoritmik akis BOS gorunur ve urunun olum sebebi olur.
// ⚠️ SOGUK BASLANGIC COZUMU: takip edilen yoksa akis BOS DONMEZ — "kesfet"
//    (herkese acik, yeni gonderiler) doner. Bkz. `Akis`.

type Handler struct {
	db *pgxpool.Pool
}

func NewHandler(db *pgxpool.Pool) *Handler { return &Handler{db: db} }

// ---------------------------------------------------------------- GONDERI

type postReq struct {
	Tur         string   `json:"tur"` // foto | video | reels | yazi
	Metin       string   `json:"metin"`
	MediaIDs    []string `json:"media_ids"`
	YorumKapali bool     `json:"yorum_kapali"`
	ClientRef   string   `json:"client_ref"`
}

// POST /posts — gonderi olustur.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req postReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	// ⚠️ TIP BEYAZ LISTESI (turu 59 dersi: istemciden gelen tip DOGRULANMADAN
	//    yazilmamali — DB CHECK'i son savunma, ILK savunma burasi).
	switch req.Tur {
	case "foto", "video", "reels", "yazi":
	default:
		hata(w, 400, "geçersiz gönderi türü")
		return
	}
	// ⚠️ TUTARLILIK: medya tipi ise medya ZORUNLU, 'yazi' ise medya OLMAMALI.
	//    Aksi halde akista BOS KART cizilir (kullanici "paylastim" sanir).
	if req.Tur == "yazi" {
		if strings.TrimSpace(req.Metin) == "" {
			hata(w, 400, "yazı boş olamaz")
			return
		}
		req.MediaIDs = nil
	} else if len(req.MediaIDs) == 0 {
		hata(w, 400, "medya bulunamadı")
		return
	}
	// ⚠️ Coklu gorsel TAVANI: 10 (Instagram deseni). Sinirsiz dizi hem akis
	//    yanitini sisirir hem istemcide bellek sorunu yapar.
	if len(req.MediaIDs) > 10 {
		hata(w, 400, "en fazla 10 medya")
		return
	}
	if req.Tur != "foto" && len(req.MediaIDs) > 1 {
		hata(w, 400, "bu türde tek medya olabilir")
		return
	}
	if len(req.Metin) > 2200 {
		req.Metin = kisalt(req.Metin, 2200)
	}

	// ⚠️⚠️ MEDYA SAHIPLIGI + DURUMU DOGRULANIR (mesaj tarafiyla AYNI kural).
	//    Aksi halde biri BASKASININ medya id'sini kendi gonderisine baglayabilir
	//    ya da dogrulanmamis ('beklemede') bir kaydi yayinlayabilirdi.
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
		hata(w, 500, "gönderi oluşturulamadı")
		return
	}
	defer tx.Rollback(r.Context())

	var id string
	var createdAt time.Time
	err = tx.QueryRow(r.Context(), `
		INSERT INTO posts (author_id, tur, metin, media_ids, yorum_kapali)
		VALUES ($1,$2,$3,$4,$5) RETURNING id, created_at`,
		me, req.Tur, req.Metin, req.MediaIDs, req.YorumKapali).Scan(&id, &createdAt)
	if err != nil {
		log.Printf("gonderi insert: %v", err)
		hata(w, 500, "gönderi oluşturulamadı")
		return
	}
	// ⚠️ Sayac AYNI TRANSACTION'da (turu 75 takip sisteminde alinan karar).
	tx.Exec(r.Context(), `UPDATE users SET gonderi_sayisi = gonderi_sayisi + 1 WHERE id=$1`, me)
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "gönderi oluşturulamadı")
		return
	}
	yaz(w, 201, map[string]any{"id": id, "created_at": createdAt})
}

// DELETE /posts/{id} — kendi gonderini sil.
// ⚠️ Satir SILINMEZ, `durum='silindi'` yazilir: yorum/begeni FK'leri ve
//
//	istatistikler bozulmasin. Medya `medyayiKopar` mantigiyla dusurulur.
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var medya []string
	err := h.db.QueryRow(r.Context(), `
		UPDATE posts SET durum='silindi', deleted_at=now()
		 WHERE id=$1 AND author_id=$2 AND durum='yayinda'
		 RETURNING media_ids`, id, me).Scan(&medya)
	if err == pgx.ErrNoRows {
		hata(w, 403, "bu gönderi silinemez")
		return
	}
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	h.db.Exec(r.Context(),
		`UPDATE users SET gonderi_sayisi = GREATEST(gonderi_sayisi - 1, 0) WHERE id=$1`, me)
	// ⚠️ Medya nesneleri silme kuyruguna girer (baska yere bagli degilse).
	//    ⚠️ "Veri silinmez" karariyla CELISMEZ: silmeyi KULLANICI talep ediyor.
	for _, m := range medya {
		h.medyayiKopar(r, m)
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// medyayiKopar — gonderi silinince medyayi dusur (baska yere bagli DEGILSE).
func (h *Handler) medyayiKopar(r *http.Request, mediaID string) {
	var kalan int
	if err := h.db.QueryRow(r.Context(), `
		SELECT (SELECT count(*) FROM messages WHERE media_id=$1)
		     + (SELECT count(*) FROM users WHERE avatar_media_id=$1)
		     + (SELECT count(*) FROM posts
		         WHERE $1 = ANY(media_ids) AND durum='yayinda')`,
		mediaID).Scan(&kalan); err != nil || kalan > 0 {
		return
	}
	var anahtar, thumb string
	if err := h.db.QueryRow(r.Context(), `
		UPDATE media_assets SET status='silindi', deleted_at=now()
		 WHERE id=$1 AND status IN ('aktif','bagli')
		 RETURNING object_key, thumb_key`, mediaID).Scan(&anahtar, &thumb); err != nil {
		return
	}
	for _, a := range []string{anahtar, thumb} {
		if a != "" {
			h.db.Exec(r.Context(),
				`INSERT INTO media_delete_queue (object_key) VALUES ($1)`, a)
		}
	}
}

// ---------------------------------------------------------------- AKIS

// GET /feed?before=<ISO>&limit=N — ana sayfa akisi.
//
// ⚠️⚠️ SAYFALAMA **CURSOR** (offset DEGIL): offset ile, sen kaydirirken yeni
// gonderi gelirse satirlar KAYAR ve ayni gonderi iki kez gorunur / bazilari
// atlanir. Cursor `created_at` uzerinden ve index'ten karsilanir.
// ⚠️ YAPMA: offset sayfalamaya donme.
func (h *Handler) Akis(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	limit := 20
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 50 {
		limit = v
	}
	before := time.Now().Add(time.Hour) // ilk sayfa: "simdiden once"
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}

	// ⚠️⚠️ SOGUK BASLANGIC: takip edilen YOKSA akis BOS DONMEZ.
	// Bos akis, yeni kullanicinin urunu terk etme sebebidir. Takip yoksa
	// "kesfet" (herkese acik, gizli olmayan hesaplarin yeni gonderileri) doner.
	// ⚠️ YAPMA: bos dizi dondurup istemciye "kimseyi takip etmiyorsun" yazdirma.
	var takipVar bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1 AND durum='onayli')`,
		me).Scan(&takipVar)

	var rows pgx.Rows
	var err error
	if takipVar {
		// Takip edilenler + KENDI gonderilerim.
		// ⚠️ ENGEL KAPISI: engellenmis kisilerin gonderileri akista GORUNMEZ.
		rows, err = h.db.Query(r.Context(), `
			SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
			       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,
			       p.yorum_kapali, p.created_at,
			       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
			       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
			       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
			  FROM posts p JOIN users u ON u.id = p.author_id
			 WHERE p.durum='yayinda' AND p.created_at < $2
			   AND (p.author_id = $1 OR p.author_id IN (
			         SELECT followee_id FROM follows
			          WHERE follower_id=$1 AND durum='onayli'))
			   AND NOT EXISTS(SELECT 1 FROM blocks b
			         WHERE (b.blocker_id=$1 AND b.blocked_id=p.author_id)
			            OR (b.blocker_id=p.author_id AND b.blocked_id=$1))
			 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	} else {
		// KESFET: herkese acik hesaplarin yeni gonderileri + KENDI gonderilerim.
		//
		// ⚠️⚠️ "p.author_id = $1 OR ..." SARTI ZORUNLU (denetimde yakalandi):
		//    kimseyi takip etmeyen kullanici bu dala duser; kendi gonderisi
		//    listeye GIRMEZSE "paylastim ama akista yok" yasar. Ustelik GIZLI
		//    hesap kendi gonderisini HIC goremezdi (NOT u.gizli_hesap onu eler).
		// ⚠️⚠️ begendim/kaydettim SABIT 'false' DONUYORDU: bu dalda begenilen
		//    gonderinin kalbi DOLU cizilmez, kullanici tekrar begenmeye calisir
		//    ve sunucu idempotent oldugu icin HICBIR SEY OLMAZ (olu dokunus).
		rows, err = h.db.Query(r.Context(), `
			SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
			       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,
			       p.yorum_kapali, p.created_at,
			       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
			       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
			       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
			  FROM posts p JOIN users u ON u.id = p.author_id
			 WHERE p.durum='yayinda' AND p.created_at < $2
			   AND (p.author_id = $1 OR (NOT u.gizli_hesap AND u.verified))
			   AND NOT EXISTS(SELECT 1 FROM blocks b
			         WHERE (b.blocker_id=$1 AND b.blocked_id=p.author_id)
			            OR (b.blocker_id=p.author_id AND b.blocked_id=$1))
			 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	}
	if err != nil {
		log.Printf("akis: %v", err)
		hata(w, 500, "akış alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{
		"kesfet": !takipVar, // istemci "Keşfet" rozeti gosterir
		"posts":  h.satirlariOku(rows),
	})
}

// GET /users/{id}/posts — bir kullanicinin gonderileri (profil sekmesi).
func (h *Handler) UserPosts(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")

	// ⚠️ GIZLI HESAP: gonderileri yalniz KENDISI ve ONAYLI takipcileri gorur.
	if hedef != me {
		var gizli bool
		h.db.QueryRow(r.Context(), `SELECT gizli_hesap FROM users WHERE id=$1`, hedef).Scan(&gizli)
		if gizli {
			var onayli bool
			h.db.QueryRow(r.Context(), `
				SELECT EXISTS(SELECT 1 FROM follows
				 WHERE follower_id=$1 AND followee_id=$2 AND durum='onayli')`,
				me, hedef).Scan(&onayli)
			if !onayli {
				hata(w, 403, "bu hesap gizli")
				return
			}
		}
	}
	before := time.Now().Add(time.Hour)
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.author_id=$2 AND p.durum='yayinda' AND p.created_at < $3
		 ORDER BY p.created_at DESC LIMIT 30`, me, hedef, before)
	if err != nil {
		hata(w, 500, "gönderiler alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"posts": h.satirlariOku(rows)})
}

// GET /posts/{id} — TEK gonderi.
//
// ⚠️ NEDEN GEREKLI: bildirimden ("X gonderini begendi") ve derin baglantidan
//
//	gelen kullanici gonderiyi tek basina acabilmeli. Akisi bastan cekip icinden
//	aramak hem pahali hem GARANTISIZ (gonderi ilk 20'de olmayabilir).
//
// ⚠️ ERISIM KAPISI `erisebilirMi` ile — begeni/yorum/kaydetme ile AYNI kaynak.
func (h *Handler) Detay(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	// ⚠️ UUID BICIM DOGRULAMASI: gecersiz metin pgx'te sorgu HATASI uretir ve
	//    500 doner.  hatayi zaten "erisilemez" sayiyor ama once
	//    ucuz kontrol yapip DB'ye hic gitmemek daha dogru.
	if len(id) != 36 {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	if ok, sebep := h.erisebilirMi(r.Context(), me, id); !ok {
		kod := 404
		if sebep == "" {
			sebep = "gönderi bulunamadı"
		} else if sebep == "bu hesap gizli" {
			kod = 403
		}
		hata(w, kod, sebep)
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$2),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$2)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.id=$1 AND p.durum='yayinda'`, id, me)
	if err != nil {
		hata(w, 500, "gönderi alınamadı")
		return
	}
	defer rows.Close()
	liste := h.satirlariOku(rows)
	if len(liste) == 0 {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	// ⚠️ Detay = kullanicinin BILEREK actigi sayfa -> goruntulenme burada artar.
	//    (Akista artmaz — bkz. Reels serhi.)
	h.db.Exec(r.Context(),
		`UPDATE posts SET goruntulenme = goruntulenme + 1 WHERE id=$1`, id)
	yaz(w, 200, liste[0])
}

// GET /reels — dikey kisa video akisi.
//
// ⚠️ AKISTAN AYRI UC: reels sekmesi TAKIPTEN BAGIMSIZ calisir (TikTok/Instagram
//
//	deseni) — yeni kullanicinin bos ekran gormemesi icin tek yol bu.
//
// ⚠️ GIZLI hesaplarin reels'i yalniz onayli takipcilerine gorunur.
func (h *Handler) Reels(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	limit := 10
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 30 {
		limit = v
	}
	before := time.Now().Add(time.Hour)
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.durum='yayinda' AND p.tur='reels' AND p.created_at < $2
		   AND (p.author_id = $1
		        OR NOT u.gizli_hesap
		        OR EXISTS(SELECT 1 FROM follows f
		              WHERE f.follower_id=$1 AND f.followee_id=p.author_id
		                AND f.durum='onayli'))
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=p.author_id)
		            OR (b.blocker_id=p.author_id AND b.blocked_id=$1))
		 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	if err != nil {
		log.Printf("reels: %v", err)
		hata(w, 500, "reels alınamadı")
		return
	}
	defer rows.Close()
	liste := h.satirlariOku(rows)

	// ⚠️⚠️ GORUNTULENME YALNIZ REELS VE DETAYDA ARTAR — AKISTA ARTMAZ.
	//    Akista 20 kart TEK ISTEKTE gelir ama kullanici cogunu HIC GORMEZ;
	//    orada saymak sayiyi YALAN yapar. Reels tam ekrandir (kart = ekran),
	//    detay ise kullanicinin BILEREK actigi sayfadir.
	// ⚠️ Sayim KABA: ayni kullanici tekrar bakinca yine artar. Kesin tekil sayim
	//    (kullanici,gonderi) satiri gerektirir ve tam da kacindigimiz yazma
	//    yukunu geri getirir (fan-out karari).
	// ⚠️ TEK SORGU (`= ANY`): gonderi basina UPDATE, sayfa basina 10 yazma demekti.
	// ⚠️ YAPMA: bunu `Akis` icine kopyalama.
	if len(liste) > 0 {
		idler := make([]string, 0, len(liste))
		for _, g := range liste {
			if s, ok := g["id"].(string); ok {
				idler = append(idler, s)
			}
		}
		if len(idler) > 0 {
			h.db.Exec(r.Context(),
				`UPDATE posts SET goruntulenme = goruntulenme + 1 WHERE id = ANY($1)`, idler)
		}
	}
	yaz(w, 200, map[string]any{"posts": liste})
}

func (h *Handler) satirlariOku(rows pgx.Rows) []map[string]any {
	out := []map[string]any{}
	for rows.Next() {
		var id, yazarID, tur, metin, ad, kullanici, avatar string
		var medya []string
		var begeni, yorum, goruntulenme int
		var yorumKapali, begendim, kaydettim bool
		var t time.Time
		var avatarMedya *string
		// ⚠️ SCAN SIRASI SORGUDAKI SUTUN SIRASIYLA BIREBIR OLMALI. Uyusmazlik
		//    derleme hatasi VERMEZ; ya tip hatasiyla satir SESSIZCE ATLANIR
		//    (asagidaki 'continue') ya da alanlar BIRBIRINE KARISIR.
		if rows.Scan(&id, &yazarID, &tur, &metin, &medya, &begeni, &yorum,
			&goruntulenme, &yorumKapali, &t, &ad, &kullanici, &avatar, &avatarMedya,
			&begendim, &kaydettim) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "author_id": yazarID, "tur": tur, "metin": metin,
			"media_ids": medya, "begeni_sayisi": begeni, "yorum_sayisi": yorum,
			"goruntulenme": goruntulenme,
			"yorum_kapali": yorumKapali, "created_at": t,
			"yazar_ad": ad, "yazar_username": kullanici,
			"yazar_avatar": avatar, "yazar_avatar_media_id": avatarMedya,
			"begendim": begendim, "kaydettim": kaydettim,
		})
	}
	return out
}

func kisalt(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return strings.TrimSpace(string(r[:n]))
}

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, msg string) {
	yaz(w, kod, map[string]string{"error": msg})
}
