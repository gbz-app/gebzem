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
// ⚠️ TEKRAR BASVURU **HATA DEGIL** (200): kullanici iki kez dokunursa ya da
//
//	zayif agda istek tekrarlanirsa hata gormemeli.
//
// ⚠️ Govde KOSULLU `ON CONFLICT ... DO UPDATE`tir — `DO NOTHING` DEGIL.
// Gerekcesi asagida, INSERT'in hemen ustunde yazili (geri ceken kullaniciyi
// o ise KALICI KILITLIYORDU). ⚠️ Bu serh turu 90b'de govdeyle YENIDEN
// HIZALANDI; ilk hali hala "DO NOTHING" diyordu.
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
	// ⚠️ TURU 90b — 404, 400 DEGIL: 400 + "artık yayında değil", ilanin VAR
	//    OLDUGUNU ve KALDIRILDIGINI dogrular. Bu dosyanin kendi kurali
	//    (asagida `Basvurular`) "403 varligi sizdirir" diyor; ayni olcut
	//    burada da gecerli.
	if durum != "yayinda" {
		hata(w, 404, "ilan bulunamadı")
		return
	}
	if sahip == me {
		hata(w, 400, "kendi ilanına başvuramazsın")
		return
	}

	// ⚠️⚠️⚠️ TURU 90b — `DO NOTHING` DEGIL, KOSULLU `DO UPDATE`.
	//
	// Ilk yazimda `DO NOTHING` vardi ve GERI CEKEN KULLANICIYI O ISE KALICI
	// KILITLIYORDU: geri cekme satiri SILMEZ (`durum='geri_cekildi'` —
	// veri politikasi), yeniden basvuruda UNIQUE cakisir, `DO NOTHING`
	// satira DOKUNMAZ, uc yine de 200 doner. Kullanici "basvurum gitti"
	// sanar; ilan sahibi ise onu HIC GORMEZ (liste `geri_cekildi`yi eler).
	// Kurtarma yolu YOKTU. Turu 85b'nin "OTP'de vazgecen hesabina KALICI
	// KILITLENIYORDU" hatasiyla ayni sinif.
	//
	// ⚠️ `WHERE durum='geri_cekildi'` ZORUNLU: kosulsuz DO UPDATE, sahibinin
	//    'olumsuz' verdigi bir basvuruyu her dokunusta 'bekliyor'a
	//    dondurup listenin basina tasirdi = SPAM KAPISI.
	// ⚠️ Buradaki `EXCLUDED.not_metin` OLU KOD DEGIL: VALUES tarafinda
	//    `$3` COALESCE'lanmiyor, yani gonderilen NOT gercekten tasiniyor
	//    (turu 78/80b/85b'deki `EXCLUDED` tuzagi burada GECERLI DEGIL).
	tag, err := h.db.Exec(r.Context(), `
		INSERT INTO ilan_basvurular (ilan_id, user_id, not_metin)
		VALUES ($1,$2,$3)
		ON CONFLICT (ilan_id, user_id) DO UPDATE
		   SET durum='bekliyor', not_metin=EXCLUDED.not_metin, created_at=now()
		 WHERE ilan_basvurular.durum='geri_cekildi'`, id, me, req.Not)
	if err != nil {
		log.Printf("basvuru: %v", err)
		hata(w, 500, "başvuru gönderilemedi")
		return
	}

	// ⚠️⚠️ TURU 90b — BILDIRIM YALNIZ SATIR DEGISTIYSE.
	//
	// Ilk yazimda `RowsAffected()` ATILIYOR ve bildirim KOSULSUZ gidiyordu.
	// Bildirim katmani ayni dortluyu 1 SAAT bastirdigi icin sonuc "sessiz"
	// degil, SAATTE BIR HAYALET BILDIRIM idi: basvurusu ZATEN duran biri
	// ucu tekrar cagirdiginda hicbir satir degismiyor ama ilan sahibinin
	// telefonu caliyor ve actiginda listede YENI HICBIR SEY olmuyordu.
	if h.bs != nil && tag.RowsAffected() > 0 {
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
//
// ⚠️ Geri cekilen basvurular GOSTERILMEZ.
func (h *Handler) Basvurular(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	// ⚠️⚠️ TURU 91 — SIRALAMA TURE GORE. Is ilaninda basvuru sirasi (yeni
	//    once) anlamli; TEKLIFTE kullanicinin bakmak istedigi ilk sey
	//    FIYATTIR. `ORDER BY` sunucuda yapilir — istemcide siralamak, ayni
	//    kuralin ikinci kopyasini dogurur ve "ucuz teklif ustte" davranisi
	//    iki ekranda drift ederdi.
	// ⚠️ `fiyat_kurus` teklif DISI turlerde 0'dir; is ilaninda ikincil
	//    olcut `created_at` oldugu icin siralama BOZULMAZ.
	rows, err := h.db.Query(r.Context(), `
		SELECT b.id, b.user_id, COALESCE(u.name,''), COALESCE(u.username,''),
		       u.avatar_media_id, b.not_metin, b.durum, b.created_at,
		       b.fiyat_kurus, b.guncellendi_at
		  FROM ilan_basvurular b
		  JOIN users u ON u.id = b.user_id
		 WHERE b.ilan_id=$1
		   AND b.durum <> 'geri_cekildi'
		   -- ⚠️ SAHIPLIK KAPISI SORGUNUN ICINDE: ayri bir SELECT ile
		   --    dogrulamak "iki kopya drift eder" sinifini acardi.
		   AND EXISTS(SELECT 1 FROM ilanlar i
		               WHERE i.id=$1 AND i.sahibi_id=$2)
		 ORDER BY CASE WHEN b.fiyat_kurus > 0 THEN 0 ELSE 1 END,
		          b.fiyat_kurus ASC, b.created_at DESC
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
		var fiyat int64
		var t, gunc any
		if rows.Scan(&bid, &uid, &ad, &kadi, &avatar, &notM, &durum, &t,
			&fiyat, &gunc) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": bid, "user_id": uid, "name": ad, "username": kadi,
			"avatar_media_id": avatar, "not": notM, "durum": durum,
			"created_at": t, "fiyat_kurus": fiyat, "guncellendi_at": gunc,
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
	// ⚠️⚠️ TURU 90b — `durum <> 'geri_cekildi'` ZORUNLU.
	//
	// Beyaz liste 'geri_cekildi'yi ICERMEZ, yani sahibi bir basvuruyu geri
	// cekilmis YAPAMAZ — ama bu yuklem olmadan geri CEKILMIS bir basvuruyu
	// 'olumlu' yapip listeye GERI SOKABILIYORDU. Sonuc: adayin RIZASINI
	// GERI ALMASI karsi tarafca iptal edilebiliyor ve basvuru adayin kendi
	// listesinde "olumlu" olarak DIRILIYORDU.
	// ⚠️ Geri cekilmis basvuruyu yalnizca ADAYIN KENDISI yeniden acabilir
	//    (`BasvuruYap`in kosullu `DO UPDATE` dali).
	tag, err := h.db.Exec(r.Context(), `
		UPDATE ilan_basvurular SET durum=$3
		 WHERE id=$1
		   AND ilan_id=$2
		   AND durum <> 'geri_cekildi'
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
	// ⚠️ TURU 91 — `tur` SUZGECI: ayni uc hem "Başvurularım" (is ilanlari)
	//    hem "Tekliflerim" (talepler) ekranini besler. Iki AYRI uc acmak,
	//    ayni yetki yuklemini ve ayni sirali okumayi IKI KEZ yazmak demekti.
	//    Bos birakilirsa HEPSI doner (mevcut davranis KORUNUR).
	turSuzgec := strings.TrimSpace(r.URL.Query().Get("tur"))
	rows, err := h.db.Query(r.Context(), `
		SELECT b.id, b.ilan_id, COALESCE(i.baslik,''), b.durum, b.created_at,
		       b.fiyat_kurus
		  FROM ilan_basvurular b
		  JOIN ilanlar i ON i.id = b.ilan_id
		 WHERE b.user_id=$1
		   AND ($2 = '' OR i.tur = $2)
		 ORDER BY b.created_at DESC
		 LIMIT 200`, me, turSuzgec)
	if err != nil {
		hata(w, 500, "başvurular alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var bid, ilanID, baslik, durum string
		var fiyat int64
		var t any
		if rows.Scan(&bid, &ilanID, &baslik, &durum, &t, &fiyat) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": bid, "ilan_id": ilanID, "baslik": baslik,
			"durum": durum, "created_at": t, "fiyat_kurus": fiyat,
		})
	}
	yaz(w, 200, map[string]any{"basvurular": out})
}
