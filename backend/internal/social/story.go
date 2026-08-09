package social

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
)

// ⚠️⚠️⚠️ TURU 76b — HIKAYE (STORY). Kullanici emri: *"story olayini getirmemiz
// gerekiyor, anasayfada storyler"*.
//
// ═══════════ "24 SAAT" GORUNURLUKTUR, SILME DEGIL ═══════════
// Satirlar KALICIDIR; kaybolma yalnizca bu suzgecle olur. Sebep: bu projede
// VERI SILINMEZ (kullanici karari, CLAUDE.md). Bkz. migration 026 serhi.
// ⚠️ YAPMA: buraya bir sup rge/DELETE isi ekleme.
const aktifPencere = ` AND s.created_at > now() - interval '24 hours' `

// ⚠️ GIZLILIK: hikaye, gonderiyle AYNI kurala tabidir —
//   - gizli hesabin hikayesini yalniz ONAYLI takipcileri gorur,
//   - engelli taraf HICBIR SEY gormez (iki yonlu).
//
// ⚠️ Bu yuklem `stories s` + `users u` takma adlarini varsayar ve $1 = OKUYAN.
// ⚠️ YAPMA: bu kurali sorgulara elle kopyalama (turu 72b/H: iki kopya DRIFT eder).
const storyGorunur = `
		   AND (NOT u.gizli_hesap
		        OR s.user_id = $1
		        OR EXISTS(SELECT 1 FROM follows f
		              WHERE f.follower_id=$1 AND f.followee_id=s.user_id
		                AND f.durum='onayli'))
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=s.user_id)
		            OR (b.blocker_id=s.user_id AND b.blocked_id=$1))`

type storyReq struct {
	MediaID string `json:"media_id"`
	Kind    string `json:"kind"` // image | video | metin
	Metin   string `json:"metin"`

	// ⚠️ TURU 77 — METIN KATMANLARI (hikaye editoru). Bicim sozlesmesi
	//    migration 027'de yazili. Sunucu ICERIGI dogrular ama CIZMEZ.
	Katmanlar []storyKatman `json:"katmanlar"`

	// SADECE METIN hikayesinde zemin gradyan ANAHTARI ('mor','okyanus'...).
	ArkaPlan string `json:"arka_plan"`
}

// ⚠️ Katman alanlari SUNUCUDA DOGRULANIR. Sebep: bunlar istemciden gelir ve
//
//	BASKALARININ ekraninda cizilir. Sinirsiz `boyut` ya da 10.000 katman,
//	izleyicinin cihazini kilitleyebilirdi (ucuz bir hizmet reddi).
type storyKatman struct {
	Metin string  `json:"metin"`
	X     float64 `json:"x"`     // 0..1 (ORAN — piksel DEGIL)
	Y     float64 `json:"y"`     // 0..1
	Boyut float64 `json:"boyut"` // mantiksal punto
	Renk  string  `json:"renk"`  // #RRGGBB
	Font  string  `json:"font"`  // sade | kalin | ince | serif | daktilo | el
	Hiza  string  `json:"hiza"`  // sol | orta | sag
	Kutu  string  `json:"kutu"`  // yok | dolu | seffaf
	Aci   float64 `json:"aci"`   // radyan
}

// ⚠️ TAVANLAR: istemci arayuzu zaten bunlarin icinde kalir; buradaki kontrol
// KOTU NIYETLI istemciye karsidir (istemci kapisi guvenlik DEGILDIR).
const (
	enFazlaKatman   = 12
	enFazlaKatmanCh = 400
	enKucukPunto    = 8
	enBuyukPunto    = 96
)

// Katmanlari SINIRLARA CEKER (reddetmek yerine kirpar).
//
// ⚠️ REDDETMEK YERINE KIRPMA bilincli: kullanici hikayeyi hazirlamis ve
//
//	yuklemis oluyor; tek bir sayi sinir disi diye TUM paylasimi 400 ile
//	geri cevirmek, kullanicinin emegini cope atar. Sinira cekmek gorunur
//	bir bozulma yaratmaz.
func katmanlariDuzelt(k []storyKatman) []storyKatman {
	if len(k) > enFazlaKatman {
		k = k[:enFazlaKatman]
	}
	out := make([]storyKatman, 0, len(k))
	for _, s := range k {
		s.Metin = strings.TrimSpace(s.Metin)
		if s.Metin == "" {
			continue // bos katman cizilmez, saklamanin anlami yok
		}
		if len(s.Metin) > enFazlaKatmanCh {
			s.Metin = kisalt(s.Metin, enFazlaKatmanCh)
		}
		s.X = sinirla(s.X, 0, 1)
		s.Y = sinirla(s.Y, 0, 1)
		s.Boyut = sinirla(s.Boyut, enKucukPunto, enBuyukPunto)
		s.Aci = sinirla(s.Aci, -3.2, 3.2)
		if !renkGecerli(s.Renk) {
			s.Renk = "#FFFFFF"
		}
		switch s.Font {
		case "sade", "kalin", "ince", "serif", "daktilo", "el":
		default:
			s.Font = "sade"
		}
		switch s.Hiza {
		case "sol", "orta", "sag":
		default:
			s.Hiza = "orta"
		}
		switch s.Kutu {
		case "yok", "dolu", "seffaf":
		default:
			s.Kutu = "yok"
		}
		out = append(out, s)
	}
	return out
}

func sinirla(v, alt, ust float64) float64 {
	// ⚠️ NaN/Inf kapisi: JSON'dan gelen bozuk sayi Postgres'e yazilirsa
	//    izleyicide cizim PATLAR. `v != v` NaN testidir.
	if v != v {
		return alt
	}
	if v < alt {
		return alt
	}
	if v > ust {
		return ust
	}
	return v
}

func renkGecerli(s string) bool {
	if len(s) != 7 || s[0] != '#' {
		return false
	}
	for i := 1; i < 7; i++ {
		c := s[i]
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') && (c < 'A' || c > 'F') {
			return false
		}
	}
	return true
}

// Metin hikayesi zeminleri — ANAHTARLA saklanir, ham renkle DEGIL (bkz. 027).
var arkaPlanlar = map[string]bool{
	"mor": true, "gun_batimi": true, "okyanus": true, "orman": true,
	"gece": true, "seftali": true, "kor": true, "gumus": true,
}

// POST /stories — hikaye paylas.
func (h *Handler) StoryOlustur(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req storyReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.MediaID = strings.TrimSpace(req.MediaID)
	req.Katmanlar = katmanlariDuzelt(req.Katmanlar)

	// ⚠️ TURU 77 — UC TUR: image | video | metin.
	//    'metin' = medyasiz, gradyan zeminli hikaye (Instagram deseni).
	if req.Kind != "image" && req.Kind != "video" && req.Kind != "metin" {
		req.Kind = "image"
	}
	if req.Kind == "metin" {
		// ⚠️ Medyasiz hikayede ZEMIN ZORUNLU (migration 027 CHECK'i de bunu
		//    dayatiyor) — aksi halde izleyicide SIYAH BOS EKRAN cizilirdi.
		if !arkaPlanlar[req.ArkaPlan] {
			req.ArkaPlan = "mor"
		}
		if len(req.Katmanlar) == 0 {
			hata(w, 400, "metin hikâyesi boş olamaz")
			return
		}
		req.MediaID = ""
	} else {
		if req.MediaID == "" {
			hata(w, 400, "medya bulunamadı")
			return
		}
		// Medyali hikayede zemin ANLAMSIZ — CHECK'i yaniltmasin diye temizlenir.
		req.ArkaPlan = ""
	}
	if len(req.Metin) > 300 {
		req.Metin = kisalt(req.Metin, 300)
	}

	// ⚠️⚠️ MEDYA SAHIPLIGI + DURUMU DOGRULANIR (gonderi/mesajla AYNI kural).
	//    Aksi halde biri BASKASININ medya id'sini kendi hikayesine baglayabilir
	//    ya da dogrulanmamis ('beklemede') bir kaydi yayinlayabilirdi.
	if req.MediaID != "" {
		var sahipOk bool
		if h.db.QueryRow(r.Context(), `
			SELECT EXISTS(SELECT 1 FROM media_assets
			        WHERE id=$1 AND owner_id=$2 AND status IN ('aktif','bagli'))`,
			req.MediaID, me).Scan(&sahipOk) != nil || !sahipOk {
			hata(w, 403, "geçersiz medya")
			return
		}
	}

	katmanJSON, err := json.Marshal(req.Katmanlar)
	if err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}

	// ⚠️ `media_id` artik NULL olabilir (metin hikayesi). Bos string GONDERILEMEZ:
	//    `uuid` sutunu bos metni kabul etmez -> 500. Bu yuzden *string kullaniliyor.
	var medyaParam *string
	if req.MediaID != "" {
		medyaParam = &req.MediaID
	}

	var id string
	var t time.Time
	if h.db.QueryRow(r.Context(), `
		INSERT INTO stories (user_id, media_id, kind, metin, katmanlar, arka_plan)
		VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, created_at`,
		me, medyaParam, req.Kind, req.Metin, katmanJSON, req.ArkaPlan).
		Scan(&id, &t) != nil {
		hata(w, 500, "hikaye paylaşılamadı")
		return
	}
	// Medyayi 'bagli' yap — supurge onu bosta sanip silmesin.
	if req.MediaID != "" {
		h.db.Exec(r.Context(),
			`UPDATE media_assets SET status='bagli' WHERE id=$1`, req.MediaID)
	}

	yaz(w, 201, map[string]any{"id": id, "created_at": t})
}

// GET /stories — ANASAYFA HIKAYE SERIDI.
//
// Donen bicim: KULLANICI BASINA gruplanmis liste (Instagram deseni) —
//
//	[{user_id, name, username, avatar_media_id, adet, hepsi_izlendi, son_zaman}]
//
// ⚠️ NEDEN GRUPLU: serit kisi basina TEK halka gosterir. Duz liste donseydi
//
//	istemci gruplamayi kendi yapardi ve "hepsi izlendi mi" hesabi iki yerde
//	(sunucu + istemci) ayri ayri yasardi = DRIFT.
//
// ⚠️ KENDI hikayem HER ZAMAN ilk sirada (Instagram) — istemci "Hikayen" halkasini
//
//	buradan cizer; ayri bir istek atmaz.
//
// ⚠️ SIRALAMA: once IZLENMEMISLER (yeni icerik one gelir), sonra en yeni.
func (h *Handler) StoryAkis(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT s.user_id, u.name, COALESCE(u.username,''), u.avatar_media_id,
		       COUNT(*)::int AS adet,
		       BOOL_AND(EXISTS(SELECT 1 FROM story_views v
		                        WHERE v.story_id=s.id AND v.user_id=$1)) AS hepsi,
		       MAX(s.created_at) AS son
		  FROM stories s JOIN users u ON u.id = s.user_id
		 WHERE s.durum='yayinda'`+aktifPencere+`
		   AND (s.user_id = $1 OR s.user_id IN (
		         SELECT followee_id FROM follows
		          WHERE follower_id=$1 AND durum='onayli'))
		`+storyGorunur+`
		 GROUP BY s.user_id, u.name, u.username, u.avatar_media_id
		 ORDER BY (s.user_id = $1) DESC, hepsi ASC, son DESC
		 LIMIT 50`, me)
	if err != nil {
		log.Printf("story akis: %v", err)
		hata(w, 500, "hikayeler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var uid, ad, kullanici string
		var avatar *string
		var adet int
		var hepsi bool
		var son time.Time
		if rows.Scan(&uid, &ad, &kullanici, &avatar, &adet, &hepsi, &son) != nil {
			continue
		}
		out = append(out, map[string]any{
			"user_id": uid, "name": ad, "username": kullanici,
			"avatar_media_id": avatar, "adet": adet,
			"hepsi_izlendi": hepsi, "son_zaman": son,
			"benim": uid == me,
		})
	}
	yaz(w, 200, map[string]any{"users": out})
}

// GET /stories/{userId} — bir kullanicinin AKTIF hikayeleri (izleyici ekrani).
func (h *Handler) StoryKullanici(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "userId")
	// ⚠️ TURU 77: `katmanlar` (JSONB) + `arka_plan` eklendi; `media_id` artik
	//    NULL olabilir (metin hikayesi). SCAN SIRASI SORGUYLA BIREBIR olmali —
	//    uyusmazlik derleme hatasi VERMEZ, satir SESSIZCE atlanir ve hikaye
	//    listesi BOMBOS doner (turu 76'da `Kaydedilenler`de tam bu yasandi).
	rows, err := h.db.Query(r.Context(), `
		SELECT s.id, s.media_id, s.kind, s.metin, s.katmanlar, s.arka_plan,
		       s.created_at,
		       EXISTS(SELECT 1 FROM story_views v
		               WHERE v.story_id=s.id AND v.user_id=$1),
		       (SELECT count(*)::int FROM story_views v2 WHERE v2.story_id=s.id)
		  FROM stories s JOIN users u ON u.id = s.user_id
		 WHERE s.user_id=$2 AND s.durum='yayinda'`+aktifPencere+storyGorunur+`
		 ORDER BY s.created_at ASC`, me, hedef)
	if err != nil {
		log.Printf("story kullanici: %v", err)
		hata(w, 500, "hikayeler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, kind, metin, arkaPlan string
		// ⚠️ `media_id` NULL olabilir -> *string. Duz string olsaydi metin
		//    hikayesinde Scan HATA verir ve satir sessizce atlanirdi.
		var mediaID *string
		var katmanlar []byte
		var t time.Time
		var izledim bool
		var izlenme int
		if rows.Scan(&id, &mediaID, &kind, &metin, &katmanlar, &arkaPlan,
			&t, &izledim, &izlenme) != nil {
			continue
		}
		// ⚠️ `json.RawMessage` ile GECIRILIYOR: sunucu katmanlari yeniden
		//    ayristirip yeniden kurmuyor (gereksiz is + bilgi kaybi riski).
		//    Bos/bozuk ise istemci `[]` gorsun diye yedek deger veriliyor.
		if len(katmanlar) == 0 {
			katmanlar = []byte("[]")
		}
		m := map[string]any{
			"id": id, "media_id": mediaID, "kind": kind, "metin": metin,
			"katmanlar": json.RawMessage(katmanlar), "arka_plan": arkaPlan,
			"created_at": t, "izledim": izledim,
		}
		// ⚠️ IZLENME SAYISI YALNIZ SAHIBINE: baskasinin hikayesinde kac kisinin
		//    izledigini gormek Instagram'da da YOK (gizlilik).
		if hedef == me {
			m["izlenme"] = izlenme
		}
		out = append(out, m)
	}
	yaz(w, 200, map[string]any{"stories": out})
}

// POST /stories/{id}/view — izlendi isaretle.
//
// ⚠️ IDEMPOTENT (`ON CONFLICT DO NOTHING`): izleyici ekraninda ileri-geri
//
//	gidildikce tekrar tekrar cagrilir; her seferinde satir acmak populer bir
//	hikayede tabloyu sisirirdi.
//
// ⚠️ KENDI hikayeni izlemen SAYILMAZ — kendi izlenme sayini kendin sisirmeyesin.
func (h *Handler) StoryIzlendi(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var sahip string
	if h.db.QueryRow(r.Context(),
		`SELECT user_id FROM stories WHERE id=$1 AND durum='yayinda'`, id).
		Scan(&sahip) != nil {
		hata(w, 404, "hikaye bulunamadı")
		return
	}
	if sahip == me {
		yaz(w, 200, map[string]bool{"ok": true})
		return
	}
	// ⚠️ ENGEL KAPISI: engelli taraf hikayeyi zaten goremez; buraya elle istek
	//    atarak izlenme sayisini sisirmesin.
	if engel.Var(r.Context(), h.db, me, sahip) {
		hata(w, 404, "hikaye bulunamadı")
		return
	}
	h.db.Exec(r.Context(), `
		INSERT INTO story_views (story_id, user_id) VALUES ($1,$2)
		ON CONFLICT DO NOTHING`, id, me)
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /stories/{id}/viewers — bu hikayeyi kimler izledi (YALNIZ SAHIBI).
func (h *Handler) StoryIzleyenler(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var sahip string
	if h.db.QueryRow(r.Context(),
		`SELECT user_id FROM stories WHERE id=$1 AND durum='yayinda'`, id).
		Scan(&sahip) != nil || sahip != me {
		// ⚠️ 404 (403 DEGIL): "var ama goremezsin" cevabi kendisi de bilgidir.
		hata(w, 404, "hikaye bulunamadı")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_media_id
		  FROM story_views v JOIN users u ON u.id = v.user_id
		 WHERE v.story_id=$1
		 ORDER BY v.created_at DESC LIMIT 200`, id)
	if err != nil {
		hata(w, 500, "liste alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var uid, ad, kullanici string
		var avatar *string
		if rows.Scan(&uid, &ad, &kullanici, &avatar) == nil {
			out = append(out, map[string]any{
				"id": uid, "name": ad, "username": kullanici,
				"avatar_media_id": avatar,
			})
		}
	}
	yaz(w, 200, out)
}

// DELETE /stories/{id} — kendi hikayeni kaldir.
//
// ⚠️ SATIR FIZIKSEL SILINMEZ (veri politikasi): `durum='silindi'` yazilir.
// ⚠️ `story_views` DOKUNULMAZ — izlenme gecmisi korunur.
func (h *Handler) StorySil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	tag, err := h.db.Exec(r.Context(),
		`UPDATE stories SET durum='silindi' WHERE id=$1 AND user_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "hikaye bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}
