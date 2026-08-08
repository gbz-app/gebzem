package social

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️ TURU 75 — ETKILESIM: begeni, yorum, kaydetme.
//
// ORTAK KURALLAR (hepsi bilincli):
//  · SAYACLAR DENORMALIZE ve begeni/yorum satiriyla AYNI TRANSACTION'da.
//  · IDEMPOTENT: `ON CONFLICT DO NOTHING` + `RowsAffected()` -> cift dokunus
//    sayaci IKI KEZ ARTIRMAZ.
//  · `GREATEST(...,0)`: sayac kaymissa negatife dusmez.
//  · BILDIRIM yalniz GERCEKTEN yeni etkilesimde ve KENDI gonderine degilse.
//  · ERISIM: gizli hesabin gonderisine yalniz onayli takipci etkilesebilir.

// erisebilirMi — bu kullanici bu gonderiyi GOREBILIR mi?
// ⚠️ TEK KAYNAK: begeni, yorum, kaydetme ve gonderi detayi AYNI kapiyi kullanir.
//
//	Kopyalanirsa drift eder (turu 56'nin "mesgulluk kontrolu tek kaynak" dersi).
func (h *Handler) erisebilirMi(ctx context.Context, me, postID string) (bool, string) {
	var yazar, durum string
	var yorumKapali, gizli bool
	err := h.db.QueryRow(ctx, `
		SELECT p.author_id, p.durum, p.yorum_kapali, u.gizli_hesap
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.id=$1`, postID).Scan(&yazar, &durum, &yorumKapali, &gizli)
	if err != nil {
		return false, ""
	}
	if durum != "yayinda" {
		return false, ""
	}
	// ⚠️ ENGEL: iki yonlu. Engelli taraf etkilesemez.
	var engelli bool
	h.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM blocks
		 WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		me, yazar).Scan(&engelli)
	if engelli {
		return false, ""
	}
	if gizli && yazar != me {
		var onayli bool
		h.db.QueryRow(ctx, `
			SELECT EXISTS(SELECT 1 FROM follows
			 WHERE follower_id=$1 AND followee_id=$2 AND durum='onayli')`,
			me, yazar).Scan(&onayli)
		if !onayli {
			return false, ""
		}
	}
	return true, yazar
}

// POST /posts/{id}/like — begen. Idempotent.
func (h *Handler) Like(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")

	ok, yazar := h.erisebilirMi(r.Context(), me, id)
	if !ok {
		hata(w, 403, "bu gönderiye erişemiyorsunuz")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	defer tx.Rollback(r.Context())

	tag, err := tx.Exec(r.Context(), `
		INSERT INTO post_likes (post_id, user_id) VALUES ($1,$2)
		ON CONFLICT DO NOTHING`, id, me)
	if err != nil {
		hata(w, 500, "beğenilemedi")
		return
	}
	if tag.RowsAffected() == 1 {
		tx.Exec(r.Context(),
			`UPDATE posts SET begeni_sayisi = begeni_sayisi + 1 WHERE id=$1`, id)
		// ⚠️ KENDI gonderine begeni bildirimi GITMEZ.
		if yazar != me {
			tx.Exec(r.Context(), `
				INSERT INTO bildirimler (user_id, aktor_id, tur, hedef_tur, hedef_id)
				VALUES ($1,$2,'begeni','gonderi',$3)`, yazar, me, id)
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "beğenilemedi")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// DELETE /posts/{id}/like — begeniyi geri al. Idempotent.
func (h *Handler) Unlike(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	defer tx.Rollback(r.Context())

	tag, err := tx.Exec(r.Context(),
		`DELETE FROM post_likes WHERE post_id=$1 AND user_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	if tag.RowsAffected() == 1 {
		tx.Exec(r.Context(),
			`UPDATE posts SET begeni_sayisi = GREATEST(begeni_sayisi - 1, 0) WHERE id=$1`, id)
	}
	tx.Commit(r.Context())
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /posts/{id}/likes — begenenler listesi.
func (h *Handler) Likes(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if ok, _ := h.erisebilirMi(r.Context(), me, id); !ok {
		hata(w, 403, "bu gönderiye erişemiyorsunuz")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, COALESCE(u.username,''), u.name, u.avatar_url, u.avatar_media_id
		  FROM post_likes l JOIN users u ON u.id = l.user_id
		 WHERE l.post_id=$1 ORDER BY l.created_at DESC LIMIT 100`, id)
	if err != nil {
		hata(w, 500, "liste alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var uid, kullanici, ad, avatar string
		var medya *string
		if rows.Scan(&uid, &kullanici, &ad, &avatar, &medya) == nil {
			out = append(out, map[string]any{
				"id": uid, "username": kullanici, "name": ad,
				"avatar_url": avatar, "avatar_media_id": medya,
			})
		}
	}
	yaz(w, 200, out)
}

// ---------------------------------------------------------------- YORUM

type yorumReq struct {
	Metin    string `json:"metin"`
	ParentID *int64 `json:"parent_id"`
}

// POST /posts/{id}/comments — yorum yap.
func (h *Handler) Comment(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var req yorumReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Metin = strings.TrimSpace(req.Metin)
	if req.Metin == "" {
		hata(w, 400, "yorum boş olamaz")
		return
	}
	if len(req.Metin) > 1000 {
		req.Metin = kisalt(req.Metin, 1000)
	}

	ok, yazar := h.erisebilirMi(r.Context(), me, id)
	if !ok {
		hata(w, 403, "bu gönderiye erişemiyorsunuz")
		return
	}
	// Yorumlara kapali mi (yazarin karari)?
	var kapali bool
	h.db.QueryRow(r.Context(), `SELECT yorum_kapali FROM posts WHERE id=$1`, id).Scan(&kapali)
	if kapali && yazar != me {
		hata(w, 403, "bu gönderide yorumlar kapalı")
		return
	}
	// ⚠️ YANIT TEK SEVIYE: bir yanita yanit verilirse KOK yoruma baglanir
	//    (Instagram deseni). Sinirsiz ic ice yorum hem okunmaz hem sorguyu
	//    ozyinelemeli yapar.
	if req.ParentID != nil {
		var kok *int64
		var ustPost string
		if err := h.db.QueryRow(r.Context(),
			`SELECT parent_id, post_id FROM post_comments WHERE id=$1 AND durum='yayinda'`,
			*req.ParentID).Scan(&kok, &ustPost); err != nil || ustPost != id {
			hata(w, 400, "geçersiz yanıt")
			return
		}
		if kok != nil {
			req.ParentID = kok
		}
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "yorum eklenemedi")
		return
	}
	defer tx.Rollback(r.Context())

	var yorumID int64
	var t time.Time
	if err := tx.QueryRow(r.Context(), `
		INSERT INTO post_comments (post_id, author_id, parent_id, metin)
		VALUES ($1,$2,$3,$4) RETURNING id, created_at`,
		id, me, req.ParentID, req.Metin).Scan(&yorumID, &t); err != nil {
		hata(w, 500, "yorum eklenemedi")
		return
	}
	tx.Exec(r.Context(), `UPDATE posts SET yorum_sayisi = yorum_sayisi + 1 WHERE id=$1`, id)
	if yazar != me {
		tx.Exec(r.Context(), `
			INSERT INTO bildirimler (user_id, aktor_id, tur, hedef_tur, hedef_id)
			VALUES ($1,$2,'yorum','gonderi',$3)`, yazar, me, id)
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "yorum eklenemedi")
		return
	}
	yaz(w, 201, map[string]any{"id": yorumID, "created_at": t})
}

// GET /posts/{id}/comments — yorumlar (kok + yanitlar).
func (h *Handler) Comments(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if ok, _ := h.erisebilirMi(r.Context(), me, id); !ok {
		hata(w, 403, "bu gönderiye erişemiyorsunuz")
		return
	}
	limit := 50
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 100 {
		limit = v
	}
	// ⚠️ Tek sorguda kok + yanitlar: N+1 istekten kacinmak icin. Istemci
	//    `parent_id`e gore gruplar.
	rows, err := h.db.Query(r.Context(), `
		SELECT c.id, c.parent_id, c.metin, c.begeni_sayisi, c.created_at,
		       u.id, u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM comment_likes cl
		               WHERE cl.comment_id=c.id AND cl.user_id=$1)
		  FROM post_comments c JOIN users u ON u.id = c.author_id
		 WHERE c.post_id=$2 AND c.durum='yayinda'
		 ORDER BY c.created_at LIMIT $3`, me, id, limit)
	if err != nil {
		hata(w, 500, "yorumlar alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var cid int64
		var parent *int64
		var metin, uid, ad, kullanici, avatar string
		var begeni int
		var t time.Time
		var medya *string
		var begendim bool
		if rows.Scan(&cid, &parent, &metin, &begeni, &t, &uid, &ad, &kullanici,
			&avatar, &medya, &begendim) == nil {
			out = append(out, map[string]any{
				"id": cid, "parent_id": parent, "metin": metin,
				"begeni_sayisi": begeni, "created_at": t, "begendim": begendim,
				"yazar_id": uid, "yazar_ad": ad, "yazar_username": kullanici,
				"yazar_avatar": avatar, "yazar_avatar_media_id": medya,
			})
		}
	}
	yaz(w, 200, out)
}

// DELETE /comments/{id} — yorumu sil (yorum sahibi VEYA gonderi sahibi).
func (h *Handler) CommentDelete(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	cid, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		hata(w, 400, "geçersiz yorum")
		return
	}
	// ⚠️ GONDERI SAHIBI DE SILEBILIR: kendi gonderisindeki tacizi kaldirabilmeli
	//    (App Store 1.2 icerik kaldirma sarti).
	var postID string
	err = h.db.QueryRow(r.Context(), `
		UPDATE post_comments c SET durum='silindi'
		 WHERE c.id=$1 AND c.durum='yayinda'
		   AND (c.author_id=$2 OR EXISTS(
		        SELECT 1 FROM posts p WHERE p.id=c.post_id AND p.author_id=$2))
		 RETURNING c.post_id`, cid, me).Scan(&postID)
	if err == pgx.ErrNoRows {
		hata(w, 403, "bu yorum silinemez")
		return
	}
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	h.db.Exec(r.Context(),
		`UPDATE posts SET yorum_sayisi = GREATEST(yorum_sayisi - 1, 0) WHERE id=$1`, postID)
	yaz(w, 200, map[string]bool{"ok": true})
}

// POST/DELETE /posts/{id}/save — kaydet / kaydı kaldır.
func (h *Handler) Save(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if ok, _ := h.erisebilirMi(r.Context(), me, id); !ok {
		hata(w, 403, "bu gönderiye erişemiyorsunuz")
		return
	}
	h.db.Exec(r.Context(),
		`INSERT INTO post_saves (post_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
		id, me)
	yaz(w, 200, map[string]bool{"ok": true})
}

func (h *Handler) Unsave(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	h.db.Exec(r.Context(),
		`DELETE FROM post_saves WHERE post_id=$1 AND user_id=$2`, id, me)
	yaz(w, 200, map[string]bool{"ok": true})
}
