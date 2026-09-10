package isletme

import (
	"context"
	"strings"
)

// ⚠️⚠️⚠️ TURU 181 — ADMIN PANELININ ISLETME YAZMA YOLU.
//
// ═══════════ NEDEN BU PAKETTE ═══════════
//
// Turu 181'e kadar `isletmeler` tablosuna yazan TEK yol `Kaydet`ti
// (`PUT /users/me/isletme`) ve kimligi JWT'den aliyordu — yani **yonetici
// baskasi adina isletme ACAMIYORDU** (olculdu: `INSERT INTO isletmeler` /
// `UPDATE isletmeler` grep'i TEK sonuc veriyor).
//
// Admin paneli kendi SQL'ini yazsaydi, ayni tablonun IKI YAZICISI olurdu
// ve bu projede "ayni kuralin iki kopyasi drift eder" sinifi ALTI kez
// sahaya cikti: kategori beyaz listesi, alan tavanlari, NOT NULL sutunlar
// icin COALESCE kapilari birinde guncellenip otekinde unutulurdu.
//
// ⚠️ YAPMA: `internal/admin` icinde `isletmeler` tablosuna dogrudan
//
//	INSERT/UPDATE yazma. Yeni bir alan gerekiyorsa `AdminBilgi`ye ekle.
//
// ⚠️ `Kaydet` ile AYNI govde DEGIL, bilincli: `Kaydet` vitrin alanlarini
//
//	(puan, teslimat, kampanya, ozellikler, kapak slideri) ISARETCI
//	semantigiyle tasiyor cunku duzenleme formu onlari kismi gonderiyor.
//	Admin paneli TEMEL kunye bilgilerini yonetir; vitrin alanlarina
//	DOKUNMAZ ve boylece isletmenin kendi girdigi degerleri EZMEZ.
type AdminBilgi struct {
	Kategori string
	Aciklama string
	Adres    string
	Il       string
	Ilce     string
	Telefon  string
	Web      string

	// ⚠️ ISARETCI: "gonderilmedi" ile "sifirla" AYRI seylerdir (turu 78/85b
	//	koordinat dersi). Admin yalniz telefonu duzeltirken koordinat
	//	SIFIRLANMAMALI.
	Enlem  *float64
	Boylam *float64
}

// AdminKaydet — bir kullaniciyi ISLETME yapar ve kunye bilgilerini yazar.
//
// ⚠️⚠️ `hesap_turu` ve `isletmeler` satiri **AYNI ISLEMDE** yazilir:
//
//	ayri olsaydi biri basarisiz olunca kullanici "isletme" gorunup
//	detaysiz kalabilirdi (ya da tersi: detay var ama profil kisisel
//	cizilir = olu veri). `Kaydet`teki karar aynen gecerli.
//
// ⚠️ NOT NULL sutunlar icin `COALESCE` ZORUNLU: Go `nil` isaretcisi SQL
//
//	NULL'a cevrilir ve `23502` verir (turu 75b `posts.media_ids` dersi).
func (h *Handler) AdminKaydet(ctx context.Context, userID string, b AdminBilgi) error {
	if _, ok := Kategoriler[b.Kategori]; !ok {
		b.Kategori = "diger"
	}
	// ⚠️ Tavanlar `Kaydet` ile BIREBIR ayni: ayrisirlarsa panelden girilen
	//	bir aciklama uygulamadan girilenden farkli kirpilirdi.
	b.Aciklama = kisalt(strings.TrimSpace(b.Aciklama), 500)
	b.Adres = kisalt(strings.TrimSpace(b.Adres), 300)
	b.Il = kisalt(strings.TrimSpace(b.Il), 60)
	b.Ilce = kisalt(strings.TrimSpace(b.Ilce), 60)
	b.Telefon = kisalt(strings.TrimSpace(b.Telefon), 30)
	b.Web = kisalt(strings.TrimSpace(b.Web), 200)
	// ⚠️ Bozuk koordinat MEVCUDU KORUR (nil), SIFIRLAMAZ — `Kaydet` ile ayni
	//	karar. Sifirlamak, gecerli bir koordinati tek bozuk istekle yok
	//	etmek demekti.
	if b.Enlem != nil && (*b.Enlem < -90 || *b.Enlem > 90 || *b.Enlem != *b.Enlem) {
		b.Enlem = nil
	}
	if b.Boylam != nil && (*b.Boylam < -180 || *b.Boylam > 180 || *b.Boylam != *b.Boylam) {
		b.Boylam = nil
	}

	tx, err := h.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx,
		`UPDATE users SET hesap_turu='isletme' WHERE id=$1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO isletmeler
		  (user_id, kategori, aciklama, adres, il, ilce, telefon, web,
		   enlem, boylam)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,
		        COALESCE($9,  0::double precision),
		        COALESCE($10, 0::double precision))
		ON CONFLICT (user_id) DO UPDATE SET
		  kategori = EXCLUDED.kategori,
		  aciklama = EXCLUDED.aciklama,
		  adres    = EXCLUDED.adres,
		  il       = EXCLUDED.il,
		  ilce     = EXCLUDED.ilce,
		  telefon  = EXCLUDED.telefon,
		  web      = EXCLUDED.web,
		  -- HAM PARAMETRE, EXCLUDED DEGIL: EXCLUDED degeri VALUES'taki
		  -- COALESCE'in SONUCUDUR ve "gonderilmedi" bilgisi orada ZATEN
		  -- KAYBOLUR (turu 80b/85b'de IKI KEZ sahaya cikti).
		  -- (Serhte BACKTICK YOK: Go ham dizesini KAPATIR — turu 180 tuzagi.)
		  enlem  = COALESCE($9::double precision,  isletmeler.enlem),
		  boylam = COALESCE($10::double precision, isletmeler.boylam),
		  updated_at = now()`,
		userID, b.Kategori, b.Aciklama, b.Adres, b.Il, b.Ilce, b.Telefon, b.Web,
		b.Enlem, b.Boylam); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// AdminKapat — isletmeyi KAPATIR (kisisel hesaba dondurur).
//
// ⚠️⚠️ `isletmeler` SATIRI SILINMEZ (veri politikasi: VERI SILINMEZ).
//
//	`KisiselYap` ile AYNI karar: kullanici tekrar isletmeye gecerse eski
//	bilgileri ONUNDE hazir gelir.
//
// ⚠️ Bu fonksiyon randevu iptali YAPMAZ — `KisiselYap`taki o mantik
//
//	kullanicinin KENDI karari icin yazilmisti (musteriye "isletme iptal
//	etti" bildirimi gider). Admin bir isletmeyi kapatiyorsa sebep genelde
//	moderasyondur ve randevu iptali AYRI bir karardir; panel bunu ayri bir
//	dugmeyle sunar.
func (h *Handler) AdminKapat(ctx context.Context, userID string) error {
	_, err := h.db.Exec(ctx,
		`UPDATE users SET hesap_turu='kisisel' WHERE id=$1`, userID)
	return err
}

// AdminOnay — isletme dogrulama rozeti (mavi tik).
//
// ⚠️⚠️ TURU 181 — `users.onayli` sutunu `033_kapak_onay.sql`'den beri VAR
//
//	ama YAZAN TEK BIR UC YOKTU: migration'in kendi serhi "ILK SURUMDE
//	ELLE SQL" diyordu ve rozet gercekten elle veriliyordu
//	(`UPDATE users SET onayli=true WHERE username='mcdonalds'`).
//	Bu, projedeki "sutun var, yazan yol yok" sinifinin bir ornegiydi.
func (h *Handler) AdminOnay(ctx context.Context, userID string, onayli bool) error {
	_, err := h.db.Exec(ctx,
		`UPDATE users SET onayli=$2 WHERE id=$1`, userID, onayli)
	return err
}
