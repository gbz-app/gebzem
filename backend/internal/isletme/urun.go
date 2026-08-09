package isletme

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
)

// ⚠️⚠️ TURU 77 — ISLETME URUNLERI / MENU.
//
// Kullanici emri: "isletmeler urunlerini yukleyebilecek".
//
// ⚠️ AYRI PAKET ACILMADI: urunler isletme profiline BAGLI ve ayni `Handler`
//
//	(db) yeterli. Ikinci bir paket `yaz`/`hata`/`kisalt`in DORDUNCU kopyasini
//	dogururdu (turu 77 denetim bulgusu Ç11).
//
// ⚠️ SUTUN LISTESI TEK KAYNAK — `urunleriOku` ile BIREBIR ayni sirada
//
//	(turu 76 `Kaydedilenler` sevk engelinin sinifi).
const urunSutunlari = `
		p.id, p.isletme_id, p.ad, p.aciklama, p.bolum,
		p.fiyat_kurus, p.media_ids, p.sira, p.durum, p.created_at`

func (h *Handler) urunleriOku(rows pgx.Rows) []map[string]any {
	out := []map[string]any{}
	for rows.Next() {
		var id, isletme, ad, aciklama, bolum, durum string
		var medya []string
		var fiyat int64
		var sira int
		var t time.Time
		if rows.Scan(&id, &isletme, &ad, &aciklama, &bolum,
			&fiyat, &medya, &sira, &durum, &t) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "isletme_id": isletme, "ad": ad, "aciklama": aciklama,
			"bolum": bolum, "fiyat_kurus": fiyat, "media_ids": medya,
			"sira": sira, "durum": durum, "created_at": t,
		})
	}
	return out
}

type urunReq struct {
	Ad         string   `json:"ad"`
	Aciklama   string   `json:"aciklama"`
	Bolum      string   `json:"bolum"`
	FiyatKurus int64    `json:"fiyat_kurus"`
	MediaIDs   []string `json:"media_ids"`
	Sira       int      `json:"sira"`
	Durum      string   `json:"durum"`
}

// POST /isletme/urunler — urun ekle (YALNIZ kendi isletmene).
func (h *Handler) UrunEkle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req urunReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	// ⚠️ ISLETME HESABI KAPISI: kisisel hesap urun ekleyemez. Aksi halde
	//    katalog "isletme" kavramindan koparadi ve profilde gosterilecek yer
	//    olmazdi.
	var isletmeMi bool
	h.db.QueryRow(r.Context(),
		`SELECT hesap_turu='isletme' FROM users WHERE id=$1`, me).Scan(&isletmeMi)
	if !isletmeMi {
		hata(w, 403, "önce işletme hesabına geçmelisin")
		return
	}
	req.Ad = kisalt(strings.TrimSpace(req.Ad), 120)
	if req.Ad == "" {
		hata(w, 400, "ürün adı boş olamaz")
		return
	}
	req.Aciklama = kisalt(strings.TrimSpace(req.Aciklama), 1000)
	req.Bolum = kisalt(strings.TrimSpace(req.Bolum), 60)
	if req.FiyatKurus < 0 {
		req.FiyatKurus = 0
	}
	// ⚠️⚠️ nil DEGIL BOS DILIM (turu 75b sevk engeli).
	if req.MediaIDs == nil {
		req.MediaIDs = []string{}
	}
	if len(req.MediaIDs) > 6 {
		req.MediaIDs = req.MediaIDs[:6]
	}
	if len(req.MediaIDs) > 0 {
		tag, err := h.db.Exec(r.Context(), `
			SELECT 1 FROM media_assets
			 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
			req.MediaIDs, me)
		if err != nil || int(tag.RowsAffected()) != len(req.MediaIDs) {
			hata(w, 403, "geçersiz medya")
			return
		}
	}
	var id string
	if h.db.QueryRow(r.Context(), `
		INSERT INTO isletme_urunleri
		  (isletme_id, ad, aciklama, bolum, fiyat_kurus, media_ids, sira)
		VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
		me, req.Ad, req.Aciklama, req.Bolum, req.FiyatKurus,
		req.MediaIDs, req.Sira).Scan(&id) != nil {
		hata(w, 500, "ürün eklenemedi")
		return
	}
	if len(req.MediaIDs) > 0 {
		h.db.Exec(r.Context(),
			`UPDATE media_assets SET status='bagli' WHERE id = ANY($1)`, req.MediaIDs)
	}
	yaz(w, 201, map[string]any{"id": id})
}

// PATCH /isletme/urunler/{id}
func (h *Handler) UrunGuncelle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Ad         *string `json:"ad"`
		Aciklama   *string `json:"aciklama"`
		Bolum      *string `json:"bolum"`
		FiyatKurus *int64  `json:"fiyat_kurus"`
		Sira       *int    `json:"sira"`
		Durum      *string `json:"durum"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if req.Durum != nil {
		switch *req.Durum {
		case "yayinda", "tukendi", "kaldirildi":
		default:
			hata(w, 400, "geçersiz durum")
			return
		}
	}
	tag, err := h.db.Exec(r.Context(), `
		UPDATE isletme_urunleri SET
		  ad          = COALESCE($3, ad),
		  aciklama    = COALESCE($4, aciklama),
		  bolum       = COALESCE($5, bolum),
		  fiyat_kurus = COALESCE($6, fiyat_kurus),
		  sira        = COALESCE($7, sira),
		  durum       = COALESCE($8, durum),
		  updated_at  = now()
		 WHERE id=$1 AND isletme_id=$2`,
		id, me, req.Ad, req.Aciklama, req.Bolum, req.FiyatKurus,
		req.Sira, req.Durum)
	if err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "ürün bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// DELETE /isletme/urunler/{id}
// ⚠️ SATIR SILINMEZ (veri politikasi): `durum='kaldirildi'`.
func (h *Handler) UrunSil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	tag, err := h.db.Exec(r.Context(),
		`UPDATE isletme_urunleri SET durum='kaldirildi', updated_at=now()
		  WHERE id=$1 AND isletme_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "kaldırılamadı")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "ürün bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /users/{id}/urunler — bir isletmenin KATALOGU / MENUSU.
//
// ⚠️ ENGEL KAPISI: engelli taraf 404 alir.
// ⚠️ Sahibi KALDIRILMIS urunleri de gorur (kendi gecmisi); baskasi gormez.
func (h *Handler) UrunListesi(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	if engel.Var(r.Context(), h.db, me, hedef) {
		hata(w, 404, "işletme bulunamadı")
		return
	}
	durumKosulu := " AND p.durum <> 'kaldirildi'"
	if hedef == me {
		durumKosulu = ""
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT `+urunSutunlari+`
		  FROM isletme_urunleri p
		 WHERE p.isletme_id=$1`+durumKosulu+`
		 ORDER BY p.bolum ASC, p.sira ASC, p.created_at ASC
		 LIMIT 300`, hedef)
	if err != nil {
		log.Printf("urun liste: %v", err)
		hata(w, 500, "ürünler alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"urunler": h.urunleriOku(rows)})
}

var _ = strconv.Itoa
