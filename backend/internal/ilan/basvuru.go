package ilan

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

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

	// ⚠️ TURU 91 — TEKLIF TUTARI (yalniz `tur='talep'` ilanlarda).
	//    Is ilaninda YOK SAYILIR (sifirlanir) — bkz. `BasvuruYap` kapisi.
	//    ⚠️ Bu, TALEBIN butcesiyle KARISTIRILMAMALI: butce `ilanlar.
	//       fiyat_kurus`ta, teklif `ilan_basvurular.fiyat_kurus`ta durur.
	FiyatKurus int64 `json:"fiyat_kurus"`
}

// ⚠️⚠️ TURU 91 — BIR TALEBE EN FAZLA KAC TEKLIF GELIR.
//
// Armut deseni: talep sahibi 40 teklif arasinda BOGULMAMALI, isletmeler de
// "nasil olsa doldu" diye vazgecmemeli. 5, karsilastirilabilir ama bunaltmayan
// bir sayi.
// ⚠️ Tavan ADVISORY KILIT icinde sayilir: `INSERT ... WHERE (count) < 5`
//
//	READ COMMITTED'da escamanli iki istegi de gecirir (turu 79b'de AI
//	kotasinda TAM BU sorun yasandi ve orada bedeli GERCEK PARAYDI).
const TeklifTavani = 5

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
	// ⚠️ TURU 91 — sorgu `created_at` ve BENIM hesap turumu de getiriyor:
	//    talep dalindaki UC kapi (7 gunluk pencere · isletme zorunlulugu ·
	//    teklif tavani) icin AYRI sorgular acmak, ayni yuklemleri ikinci kez
	//    yazmak olurdu.
	var sahip, tur, durum, benimHesap string
	var acilis time.Time
	err := h.db.QueryRow(r.Context(), `
		SELECT i.sahibi_id, i.tur, i.durum, i.created_at,
		       (SELECT COALESCE(hesap_turu,'kisisel') FROM users WHERE id=$1)
		  FROM ilanlar i
		 WHERE i.id=$2`+engelYok, me, id).
		Scan(&sahip, &tur, &durum, &acilis, &benimHesap)
	if err != nil {
		hata(w, 404, "ilan bulunamadı")
		return
	}
	if tur != "is" && !TalepTuru(tur) {
		hata(w, 400, "bu ilana başvurulamaz")
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
	// ⚠️⚠️ TURU 91 — SAHIPLIK KAPISI **TALEP KAPILARININ ONUNDE**.
	//    Sonda kalsaydi, kendi talebine teklif vermeye calisan (kisisel
	//    hesapli) sahibi *"teklif vermek için işletme hesabına geçmelisin"*
	//    mesajini alirdi — dogru olan "kendi ilanına başvuramazsın".
	//    Yanlis hata mesaji, kullaniciyi GEREKSIZ bir hesap turu
	//    degisikligine yonlendirirdi.
	if sahip == me {
		hata(w, 400, "kendi ilanına başvuramazsın")
		return
	}

	// ═════════ TURU 91 — TALEP (TEKLIF) DALININ EK KAPILARI ═════════
	if TalepTuru(tur) {
		// ⚠️ 7 GUNLUK PENCERE **YAZMA YOLUNDA DA** uygulanir.
		//    Turu 80b dersi: *"arayuzun kurala uymasi, kuralin UYGULANDIGI
		//    anlamina GELMEZ"* — istemci listeyi HIC ACMADAN dogrudan POST
		//    atabilir. Sabit `TalepPenceresi` OKUMA yoluyla AYNI.
		if time.Since(acilis) > TalepPenceresi {
			hata(w, 404, "ilan bulunamadı")
			return
		}
		// ⚠️ TEKLIFI YALNIZ ISLETME VERIR. Kullanicinin emri "isletmeler
		//    karsi teklif verecek"ti; kisisel hesaplarin teklif vermesi
		//    talebi spam'e acardi ve "kiminle calisiyorum" belirsizlesirdi.
		// ⚠️ 403 (404 DEGIL): burada gizlenecek bir VARLIK yok — talep zaten
		//    herkese acik. Kullaniciya NE YAPMASI GEREKTIGI soylenir.
		if benimHesap != "isletme" {
			hata(w, 403, "teklif vermek için işletme hesabına geçmelisin")
			return
		}
		// ⚠️ FIYATSIZ TEKLIF YOK: teklif listesi FIYATA gore siralaniyor ve
		//    fiyatsiz bir satir listenin anlamini bozardi.
		if req.FiyatKurus <= 0 {
			hata(w, 400, "teklif tutarı gerekli")
			return
		}
	} else if req.FiyatKurus != 0 {
		// ⚠️ Is ilaninda fiyat alani YOK SAYILIR (sessizce sifirlanir):
		//    hata dondurmek eski istemcileri kirardi, degeri yazmak ise
		//    "maas teklifi" gibi YANLIS bir anlam uretirdi.
		req.FiyatKurus = 0
	}
	// ⚠️ (Yayinda-mi ve sahiplik kapilari YUKARI TASINDI — turu 91;
	//    gerekcesi orada yazili.)

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
	// ⚠️⚠️ TURU 91 — TEKLIF TAVANI **ADVISORY KILIT** ICINDE.
	//
	// `INSERT ... WHERE (SELECT count(*)) < 5` READ COMMITTED'da escamanli
	// iki istegi de gecirir; turu 79b'de AI kotasinda TAM BU sorun yasandi.
	// Burada bedeli para degil ama tavan asilinca talep sahibi bunalir ve
	// "5 teklif" sozu YALAN olur.
	// ⚠️ Kilit anahtari ILANA OZGU: farkli talepler birbirini BEKLETMEZ.
	// ⚠️ `pg_advisory_xact_lock` islem bitince OTOMATIK birakilir (kilit
	//    SIZMAZ) — bu yuzden islem ZORUNLU.
	// ⚠️ REVIZE tavana SAYILMAZ: ayni isletmenin mevcut satiri `ON CONFLICT`
	//    dalina duser, yeni satir acilmaz.
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "başvuru gönderilemedi")
		return
	}
	defer tx.Rollback(context.Background())

	if TalepTuru(tur) {
		if _, err := tx.Exec(r.Context(),
			`SELECT pg_advisory_xact_lock(hashtext($1))`, "teklif:"+id); err != nil {
			hata(w, 500, "başvuru gönderilemedi")
			return
		}
		var adet int
		// ⚠️ `geri_cekildi` SAYILMAZ: vazgecen bir isletme kontenjani
		//    KILITLEMEMELI.
		if err := tx.QueryRow(r.Context(), `
			SELECT count(*) FROM ilan_basvurular
			 WHERE ilan_id=$1 AND user_id <> $2 AND durum <> 'geri_cekildi'`,
			id, me).Scan(&adet); err != nil {
			hata(w, 500, "başvuru gönderilemedi")
			return
		}
		if adet >= TeklifTavani {
			hata(w, 409, "bu talep için teklif kontenjanı doldu")
			return
		}
	}

	// ⚠️ `created_at` REVIZEDE **KORUNUR** (turu 91): her guncellemede
	//    listenin basina ziplamak SPAM KAPISI olurdu. Degisen `guncellendi_at`.
	// ⚠️ `WHERE` kumesi turu 90b'ye gore GENISLEDI: teklif REVIZE
	//    EDILEBILMELI, yani 'bekliyor'/'goruldu' de guncellenir. Ama
	//    'secildi'/'elendi' HARIC — karar verilmis bir teklifi degistirmek,
	//    talep sahibinin gordugu fiyati ARKASINDAN degistirmek olurdu.
	tag, err := tx.Exec(r.Context(), `
		INSERT INTO ilan_basvurular (ilan_id, user_id, not_metin, fiyat_kurus)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (ilan_id, user_id) DO UPDATE
		   SET durum='bekliyor', not_metin=EXCLUDED.not_metin,
		       fiyat_kurus=EXCLUDED.fiyat_kurus, guncellendi_at=now()
		 WHERE ilan_basvurular.durum IN ('geri_cekildi','bekliyor','goruldu')`,
		id, me, req.Not, req.FiyatKurus)
	if err != nil {
		log.Printf("basvuru: %v", err)
		hata(w, 500, "başvuru gönderilemedi")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
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
		// ⚠️⚠️ TURU 91 — TUR ALICIYA GORE SECILIR.
		//    Is ilaninda alici ISVEREN ("başvurdu"), talepte alici TALEP
		//    SAHIBI ("teklif verdi"). Tek tur kullanilsaydi istemci
		//    yonlendirmesi (`_git`) hangi ekrani acacagini bilemezdi ve
		//    metin de yanlis olurdu — turu 80b'de `randevu_iptal` tam bu
		//    yuzden IKIYE bolunmustu.
		// ⚠️ `teklif_geldi` metni `bildirim.Metin()`de TANIMLI; burasi onu
		//    GONDEREN yol. Metin tanimlanip gonderen yol yazilmasaydi, o
		//    `case` OLU KOD olurdu (bu projede DOKUZ kez yasandi).
		tip := "ilan_basvuru"
		if TalepTuru(tur) {
			tip = "teklif_geldi"
		}
		h.bs.Bildir(r.Context(), sahip, me, tip, "ilan", id)
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
	// ⚠️ TURU 91 — TEKLIF KARARLARI. `secildi` YAN ETKILIDIR (asagi bak);
	//    `elendi` yalniz etiket.
	"secildi": true, "elendi": true,
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
	// ⚠️⚠️⚠️ TURU 91 — `secildi` **TEK ISLEMDE UC YAN ETKI**.
	//
	// Kazanan isaretlenir · DIGER tum teklifler `elendi` olur · talep
	// `durum='satildi'`ye gecer. Ucu ayri isteklerde yapilsaydi araya giren
	// bir hata "kazanan var ama talep hala acik" ya da "talep kapandi ama
	// kimse kazanmadi" gibi YARIM durumlar birakirdi ve kullanicinin
	// duzeltme yolu OLMAZDI (secim GERI ALINAMAZ bir karardir).
	// ⚠️ Talep SILINMEZ, `satildi` olur — veri politikasi.
	// ⚠️ Is ilaninda (`tur='is'`) yan etki UYGULANMAZ: bir isverenin bir
	//    adayi "olumlu" isaretlemesi ilani KAPATMAZ, cunku birden fazla kisi
	//    ise alinabilir.
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	defer tx.Rollback(context.Background())

	// ⚠️ Kazananin kim oldugu ve ilanin turu AYNI UPDATE'ten `RETURNING` ile
	//    alinir: ayri bir SELECT yarisa acik olurdu ve sahiplik kapisini
	//    IKINCI KEZ yazmak gerekirdi.
	var kazanan, ilanTuru string
	err = tx.QueryRow(r.Context(), `
		UPDATE ilan_basvurular b SET durum=$3
		 WHERE b.id=$1
		   AND b.ilan_id=$2
		   AND b.durum <> 'geri_cekildi'
		   AND EXISTS(SELECT 1 FROM ilanlar i
		               WHERE i.id=$2 AND i.sahibi_id=$4)
		RETURNING b.user_id,
		          (SELECT tur FROM ilanlar WHERE id=$2)`,
		bid, id, req.Durum, me).Scan(&kazanan, &ilanTuru)
	if err != nil {
		// ⚠️ `pgx.ErrNoRows` burada "yetkin yok" ya da "boyle bir basvuru yok"
		//    demektir; ikisi de disaridan 404'tur (403 varligi sizdirirdi).
		hata(w, 404, "başvuru bulunamadı")
		return
	}

	if req.Durum == "secildi" && TalepTuru(ilanTuru) {
		if _, err := tx.Exec(r.Context(), `
			UPDATE ilan_basvurular SET durum='elendi'
			 WHERE ilan_id=$1 AND id <> $2
			   AND durum NOT IN ('geri_cekildi','elendi')`, id, bid); err != nil {
			hata(w, 500, "güncellenemedi")
			return
		}
		if _, err := tx.Exec(r.Context(),
			`UPDATE ilanlar SET durum='satildi' WHERE id=$1 AND sahibi_id=$2`,
			id, me); err != nil {
			hata(w, 500, "güncellenemedi")
			return
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}

	// ⚠️ BILDIRIM COMMIT'TEN SONRA: islem geri alinirsa "teklifin secildi"
	//    diyen bir bildirim gonderilmis olurdu ve GERI ALINAMAZDI.
	// ⚠️ Bildirim turu ALICIYA GORE ayrilmaz — burada tek alici var (teklifi
	//    veren isletme). Elenenlere bildirim GONDERILMEZ: "kaybettin"
	//    bildirimi urun degeri katmaz, gurultu yapar.
	if h.bs != nil && req.Durum == "secildi" && TalepTuru(ilanTuru) {
		h.bs.Bildir(r.Context(), kazanan, me, "teklif_secildi", "ilan", id)
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
