package etkinlik

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
)

// ⚠️⚠️ TURU 78 — ETKINLIK KADROSU (oyuncu / sarkici / konusmaci).
//
// Kullanici emri: "katilimci oyuncu sarkici ekleme bunlar olmali".
//
// ⚠️ "KADRO" ile "KATILIMCI" AYRI KAVRAMLAR (bkz. migration 035 serhi):
//
//	kadro SAHNEDEKILER, katilim ise RSVP'dir.
//
// ⚠️ Kadroda AYRI FOTOGRAF ALANI YOK — kayitli kisi kendi avatarini kullanir
//
//	(medya dali (b) zaten herkese acik), kayitsiz kisi harf avatari alir.
//	Yeni bir `media_id` sutunu `erisebilir()` icine YENI DAL gerektirirdi ve o
//	dal unutuldugunda medya YUKLEYENDEN BASKA HERKESE 403 doner (turu 75b/77
//	sinifi). Risk YAPISAL OLARAK kaldirildi.

const kadroSutunlari = `
		k.id, k.user_id, k.ad, k.rol, k.sira,
		COALESCE(u.username,''), u.avatar_media_id`

// GET /etkinlikler/{id}/kadro — herkese acik (etkinligi gorebiliyorsa).
func (h *Handler) KadroListe(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	// ⚠️ ETKINLIGI GOREBILIYOR MU: engel kapisi ETKINLIK uzerinden uygulanir.
	//    Kadro ayri bir yetki yuzeyi DEGIL — etkinligin PARCASI.
	var olusturan string
	if h.db.QueryRow(r.Context(),
		`SELECT olusturan_id FROM etkinlikler WHERE id=$1 AND durum<>'silindi'`,
		id).Scan(&olusturan) != nil {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	if engel.Var(r.Context(), h.db, me, olusturan) {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT `+kadroSutunlari+`
		  FROM etkinlik_kadro k
		  LEFT JOIN users u ON u.id = k.user_id
		 WHERE k.etkinlik_id=$1
		 ORDER BY k.sira, k.created_at`, id)
	if err != nil {
		hata(w, 500, "kadro alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var kid, ad, rol, kullanici string
		var uid, avatar *string
		var sira int
		// ⚠️ SCAN SIRASI `kadroSutunlari` ILE BIREBIR.
		if rows.Scan(&kid, &uid, &ad, &rol, &sira, &kullanici, &avatar) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": kid, "user_id": uid, "ad": ad, "rol": rol, "sira": sira,
			"username": kullanici, "avatar_media_id": avatar,
		})
	}
	yaz(w, 200, map[string]any{"kadro": out})
}

type kadroReq struct {
	// ⚠️ Kayitli kisi icin doldurulur; UNLU biri icin bos birakilir.
	UserID *string `json:"user_id"`
	Ad     string  `json:"ad"`
	Rol    string  `json:"rol"`
	Sira   int     `json:"sira"`
}

// POST /etkinlikler/{id}/kadro — YALNIZ olusturan ekleyebilir.
func (h *Handler) KadroEkle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	var req kadroReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Ad = kisalt(strings.TrimSpace(req.Ad), 80)
	req.Rol = kisalt(strings.TrimSpace(req.Rol), 40)
	if req.UserID != nil && !kimlik.Gecerli(*req.UserID) {
		req.UserID = nil
	}
	// ⚠️ `sira` INTEGER sutun; Go tarafi 64 bit oldugu icin tasma INSERT'i
	//    patlatir ve kullanici sebepsiz bir hata gorur (turu 77b dersi).
	if req.Sira < 0 || req.Sira > 10000 {
		req.Sira = 0
	}

	// ⚠️ Kayitli kisi secildiyse ADI SUNUCUDAN alinir — istemcinin gonderdigi
	//    ada guvenmek KIMLIK TAKLIDI acardi ("Tarkan" yazip baska birinin
	//    profiline baglamak). Ad bos kalirsa da bu doldurur.
	if req.UserID != nil {
		var gercekAd string
		if h.db.QueryRow(r.Context(),
			`SELECT name FROM users WHERE id=$1`, *req.UserID).Scan(&gercekAd) != nil {
			hata(w, 400, "kullanıcı bulunamadı")
			return
		}
		req.Ad = gercekAd
	}
	if req.Ad == "" {
		hata(w, 400, "isim boş olamaz")
		return
	}

	// ⚠️ SAHIPLIK: yalniz olusturan. `RowsAffected()==0` -> 404 (403 DEGIL:
	//    "var ama yetkin yok" cevabi kendisi de bilgidir).
	var kid string
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO etkinlik_kadro (etkinlik_id, user_id, ad, rol, sira)
		SELECT $1,$2,$3,$4,$5
		 WHERE EXISTS(SELECT 1 FROM etkinlikler
		               WHERE id=$1 AND olusturan_id=$6 AND durum<>'silindi')
		-- ⚠️ Ayni kayitli kisi IKI KEZ eklenmesin (kismi UNIQUE index).
		ON CONFLICT (etkinlik_id, user_id) WHERE user_id IS NOT NULL
		DO UPDATE SET rol=EXCLUDED.rol, sira=EXCLUDED.sira
		RETURNING id`, id, req.UserID, req.Ad, req.Rol, req.Sira, me).Scan(&kid)
	if err != nil {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	yaz(w, 201, map[string]string{"id": kid})
}

// DELETE /etkinlikler/{id}/kadro/{kadroId}
func (h *Handler) KadroSil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	kadroID := chi.URLParam(r, "kadroId")
	if !kimlik.Gecerli(id) || !kimlik.Gecerli(kadroID) {
		hata(w, 404, "bulunamadı")
		return
	}
	// ⚠️ Kadro satiri ETKINLIGIN ALT VERISIDIR ve gercekten SILINIR — burada
	//    "veri silinmez" politikasi gecerli degil: yanlis yazilmis bir sanatci
	//    adini gizlemek degil KALDIRMAK gerekir (afiste yanlis bilgi kalmasin).
	tag, err := h.db.Exec(r.Context(), `
		DELETE FROM etkinlik_kadro k
		 USING etkinlikler e
		 WHERE k.id=$1 AND k.etkinlik_id=$2
		   AND e.id=k.etkinlik_id AND e.olusturan_id=$3`, kadroID, id, me)
	if err != nil || tag.RowsAffected() == 0 {
		hata(w, 404, "bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}
