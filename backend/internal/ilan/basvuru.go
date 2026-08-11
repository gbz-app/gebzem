package ilan

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
)

// ⚠️⚠️⚠️ TURU 90 — IS ILANINA BASVURU.
//
// Kullanici emri: *"is ilani da olacak, HERKES verebilmeli, normal
// kullanicilar haricinde BASVURU YAPILABILMELI"*.
//
// ⚠️ AYRI PAKET ACILMADI: basvuru `ilanlar`a bagli ve ayni `Handler` (db)
//
//	yeterli. Ikinci bir paket `yaz`/`hata`in bir kopyasini daha dogururdu.
//
// ⚠️ BASVURU YALNIZ `tur='is'` ILANLARA yapilir. Kapi olmasaydi kullanici bir
//
//	ARABA ilanina "basvuru" gonderebilir ve satici bunu anlamlandiramazdi.

type basvuruReq struct {
	Not string `json:"not"`
}

// POST /ilanlar/{id}/basvuru — is ilanina basvur.
//
// ⚠️ KENDI ILANINA BASVURU 400: anlamsiz ve basvuru listesini kirletir.
// ⚠️ TEKRAR BASVURU **HATA DEGIL**: `ON CONFLICT DO NOTHING` + 200. Kullanici
//
//	iki kez dokunursa hata gormemeli; UNIQUE zaten tek satir birakir.
func (h *Handler) BasvuruYap(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "ilan bulunamadı")
		return
	}
	var req basvuruReq
	json.NewDecoder(r.Body).Decode(&req)
	req.Not = kisalt(strings.TrimSpace(req.Not), 1000)

	// ⚠️ TEK SORGUDA: ilan var mi · IS ilani mi · yayinda mi · sahibi ben miyim
	//    · engel var mi. Ayri sorgular yazmak "ayni kuralin iki kopyasi"
	//    sinifini acardi; `engelYok` TEK KAYNAKTAN geliyor.
	// ⚠️ `engelYok` icinde parametre **$1 = OKUYAN** olarak yaziliyor.
	var sahip, tur, durum string
	err := h.db.QueryRow(r.Context(), `
		SELECT i.sahibi_id, i.tur, i.durum
		  FROM ilanlar i
		 WHERE i.id=$2`+engelYok, me, id).Scan(&sahip, &tur, &durum)
	if err != nil {
		hata(w, 404, "ilan bulunamadı")
		return
	}
	if tur != "is" {
		hata(w, 400, "bu ilan bir iş ilanı değil")
		return
	}
	if durum != "yayinda" {
		hata(w, 400, "bu ilan artık yayında değil")
		return
	}
	if sahip == me {
		hata(w, 400, "kendi ilanına başvuramazsın")
		return
	}

	if _, err := h.db.Exec(r.Context(), `
		INSERT INTO ilan_basvurular (ilan_id, user_id, not_metin)
		VALUES ($1,$2,$3)
		ON CONFLICT (ilan_id, user_id) DO NOTHING`, id, me, req.Not); err != nil {
		log.Printf("basvuru: %v", err)
		hata(w, 500, "başvuru gönderilemedi")
		return
	}

	// ⚠️ ILAN SAHIBINE BILDIRIM. Bildirimci `nil` olabilir (test/kurulum) —
	//    kapi ZORUNLU, aksi halde nil pointer panik ederdi.
	// ⚠️ Bildirim turu `ilan_basvuru`; ISTEMCI SWITCH'I DE GUNCELLENDI
	//    (turu 80b dersi: sunucuya yeni tur eklerken istemciyi atlamak
	//    "bir islem yaptı" jenerik metnine ve Sentry gurultusune yol acar).
	if h.bs != nil {
		h.bs.Bildir(r.Context(), sahip, me, "ilan_basvuru", "ilan", id)
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// DELETE /ilanlar/{id}/basvuru — basvuruyu geri cek.
//
// ⚠️ SATIR SILINMEZ (veri politikasi): `durum='geri_cekildi'`.
func (h *Handler) BasvuruGeriCek(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	tag, err := h.db.Exec(r.Context(), `
		UPDATE ilan_basvurular SET durum='geri_cekildi'
		 WHERE ilan_id=$1 AND user_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "geri çekilemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "başvuru bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /ilanlar/{id}/basvurular — ILAN SAHIBI basvuranlari gorur.
//
// ⚠️ YALNIZ SAHIBI: baskasi 404 alir (403 DEGIL — 403 "bu ilanin basvurusu
//
//	var" bilgisini SIZDIRIRDI).
// ⚠️ Geri cekilen basvurular GOSTERILMEZ.
func (h *Handler) Basvurular(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT b.id, b.user_id, COALESCE(u.name,''), COALESCE(u.username,''),
		       u.avatar_media_id, b.not_metin, b.durum, b.created_at
		  FROM ilan_basvurular b
		  JOIN users u ON u.id = b.user_id
		 WHERE b.ilan_id=$1
		   AND b.durum <> 'geri_cekildi'
		   -- ⚠️ SAHIPLIK KAPISI SORGUNUN ICINDE: ayri bir SELECT ile
		   --    dogrulamak "iki kopya drift eder" sinifini acardi.
		   AND EXISTS(SELECT 1 FROM ilanlar i
		               WHERE i.id=$1 AND i.sahibi_id=$2)
		 ORDER BY b.created_at DESC
		 LIMIT 200`, id, me)
	if err != nil {
		log.Printf("basvurular: %v", err)
		hata(w, 500, "başvurular alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var bid, uid, ad, kadi, notM, durum string
		var avatar *string
		var t any
		if rows.Scan(&bid, &uid, &ad, &kadi, &avatar, &notM, &durum, &t) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": bid, "user_id": uid, "name": ad, "username": kadi,
			"avatar_media_id": avatar, "not": notM, "durum": durum,
			"created_at": t,
		})
	}
	yaz(w, 200, map[string]any{"basvurular": out})
}

// ⚠️ DURUM BEYAZ LISTESI — DB'de CHECK YOK (bkz. migration 044 serhi).
var basvuruDurumlari = map[string]bool{
	"bekliyor": true, "goruldu": true, "olumlu": true, "olumsuz": true,
}

// PATCH /ilanlar/{id}/basvurular/{basvuruID} — SAHIBI durumu degistirir.
func (h *Handler) BasvuruDurum(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	bid := chi.URLParam(r, "basvuruID")
	if !kimlik.Gecerli(id) || !kimlik.Gecerli(bid) {
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Durum string `json:"durum"`
	}
	if json.NewDecoder(r.Body).Decode(&req) != nil || !basvuruDurumlari[req.Durum] {
		hata(w, 400, "geçersiz durum")
		return
	}
	tag, err := h.db.Exec(r.Context(), `
		UPDATE ilan_basvurular SET durum=$3
		 WHERE id=$1
		   AND ilan_id=$2
		   AND EXISTS(SELECT 1 FROM ilanlar i
		               WHERE i.id=$2 AND i.sahibi_id=$4)`,
		bid, id, req.Durum, me)
	if err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "başvuru bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /users/me/basvurular — KENDI basvurularim.
func (h *Handler) Basvurularim(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT b.id, b.ilan_id, COALESCE(i.baslik,''), b.durum, b.created_at
		  FROM ilan_basvurular b
		  JOIN ilanlar i ON i.id = b.ilan_id
		 WHERE b.user_id=$1
		 ORDER BY b.created_at DESC
		 LIMIT 200`, me)
	if err != nil {
		hata(w, 500, "başvurular alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var bid, ilanID, baslik, durum string
		var t any
		if rows.Scan(&bid, &ilanID, &baslik, &durum, &t) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": bid, "ilan_id": ilanID, "baslik": baslik,
			"durum": durum, "created_at": t,
		})
	}
	yaz(w, 200, map[string]any{"basvurular": out})
}
