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
	Kind    string `json:"kind"` // image | video
	Metin   string `json:"metin"`
}

// POST /stories — hikaye paylas.
func (h *Handler) StoryOlustur(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req storyReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if strings.TrimSpace(req.MediaID) == "" {
		hata(w, 400, "medya bulunamadı")
		return
	}
	if req.Kind != "image" && req.Kind != "video" {
		req.Kind = "image"
	}
	if len(req.Metin) > 300 {
		req.Metin = kisalt(req.Metin, 300)
	}

	// ⚠️⚠️ MEDYA SAHIPLIGI + DURUMU DOGRULANIR (gonderi/mesajla AYNI kural).
	//    Aksi halde biri BASKASININ medya id'sini kendi hikayesine baglayabilir
	//    ya da dogrulanmamis ('beklemede') bir kaydi yayinlayabilirdi.
	var sahipOk bool
	if h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM media_assets
		        WHERE id=$1 AND owner_id=$2 AND status IN ('aktif','bagli'))`,
		req.MediaID, me).Scan(&sahipOk) != nil || !sahipOk {
		hata(w, 403, "geçersiz medya")
		return
	}

	var id string
	var t time.Time
	if h.db.QueryRow(r.Context(), `
		INSERT INTO stories (user_id, media_id, kind, metin)
		VALUES ($1,$2,$3,$4) RETURNING id, created_at`,
		me, req.MediaID, req.Kind, req.Metin).Scan(&id, &t) != nil {
		hata(w, 500, "hikaye paylaşılamadı")
		return
	}
	// Medyayi 'bagli' yap — supurge onu bosta sanip silmesin.
	h.db.Exec(r.Context(),
		`UPDATE media_assets SET status='bagli' WHERE id=$1`, req.MediaID)

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
	rows, err := h.db.Query(r.Context(), `
		SELECT s.id, s.media_id, s.kind, s.metin, s.created_at,
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
		var id, mediaID, kind, metin string
		var t time.Time
		var izledim bool
		var izlenme int
		if rows.Scan(&id, &mediaID, &kind, &metin, &t, &izledim, &izlenme) != nil {
			continue
		}
		m := map[string]any{
			"id": id, "media_id": mediaID, "kind": kind, "metin": metin,
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
