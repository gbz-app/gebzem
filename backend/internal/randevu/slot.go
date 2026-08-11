package randevu

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ⚠️⚠️⚠️ SLOT URETIMI **SUNUCUDA**, ISTEMCIDE DEGIL.
//
// Calisma saati kurali (gece yarisi sarmasi dahil) istemcide ZATEN var
// (`Isletme.simdiAcik` — "su an acik mi" rozeti icin). Ayni kurali bir de Go'da
// yazip ustune istemcide slot uretmek, kuralin **UC KOPYASI** demekti.
//
// Bunun yerine sunucu HAZIR SLOT LISTESI donduruyor:
//   - calisma saatleri uygulanir,
//   - kapali gunler (bayram/tatil) elenir,
//   - GECMIS saatler elenir,
//   - DOLU slotlar isaretlenir (kapasiteye gore).
//
// Istemcide kural KALMIYOR — yalnizca gelen listeyi ciziyor.
// ⚠️ YAPMA: istemciye slot uretme mantigi yazma.
// ⚠️ `Isletme.simdiAcik` (Dart) DOKUNULMAZ — o BASKA bir soruya cevap veriyor.

// Konum — Turkiye saat dilimi.
//
// ⚠️ Sunucu UTC calisiyor ama calisma saatleri YEREL ("09:00" = Turkiye 09:00).
// ⚠️ `LoadLocation` konteynerde tzdata yoksa HATA doner; o durumda sabit +03
//
//	kullanilir. Turkiye'de 2016'dan beri YAZ SAATI UYGULAMASI YOK, dolayisiyla
//	sabit ofset DOGRUDUR (DST olan bir ulkede bu kabul edilemezdi).
func Konum() *time.Location {
	if l, err := time.LoadLocation("Europe/Istanbul"); err == nil {
		return l
	}
	log.Printf("randevu: Europe/Istanbul yuklenemedi, sabit +03 kullaniliyor")
	return time.FixedZone("+03", 3*3600)
}

// Calisma JSONB satiri: {"gun":1,"acilis":"09:00","kapanis":"22:00","kapali":false}
//
// ⚠️ `gun` degeri istemcinin yazdigi bicimdedir; Dart tarafinda
//
//	`DateTime.weekday` (1=Pazartesi ... 7=Pazar) kullaniliyor.
type calismaGun struct {
	Gun     int    `json:"gun"`
	Acilis  string `json:"acilis"`
	Kapanis string `json:"kapanis"`
	Kapali  bool   `json:"kapali"`
}

// Slot — istemciye donen tek zaman dilimi.
type Slot struct {
	Saat   string `json:"saat"`   // "14:30" (yerel)
	Zaman  string `json:"zaman"`  // RFC3339 (UTC) — istemci BUNU geri gonderir
	Musait bool   `json:"musait"` // kapasite doldu mu
}

// Ayar — isletmenin randevu ayarlari (satir yoksa VARSAYILAN doner).
type Ayar struct {
	Acik         bool   `json:"acik"`
	Tur          string `json:"tur"`
	SlotDakika   int    `json:"slot_dakika"`
	SlotKapasite int    `json:"slot_kapasite"`
	IleriGun     int    `json:"ileri_gun"`
	OtomatikOnay bool   `json:"otomatik_onay"`
}

// AyarOku — ayar satirini + isletme kategorisinden turetilen turu doner.
//
// ⚠️ Satir YOKSA `acik=false` ile VARSAYILAN doner (hata DEGIL): ozellik
//
//	acilmamis bir isletme icin bu normal durumdur.
//
// ⚠️⚠️ TURU 80b — `hesap_turu='isletme'` KAPISI (denetim bulgusu).
//
//	Sorgu yalnizca `isletmeler` satirina bakiyordu. Ama hesap kisisele
//	dondugunde o satir SILINMIYOR (veri politikasi: VERI SILINMEZ) —
//	yalnizca `users.hesap_turu` degisiyor. Kapi olmadigi icin kisisel
//	hesaba donmus biri randevu ALMAYA DEVAM EDIYORDU: profilde
//	"Randevu al" cizilmez (orasi `Detay`in kendi kapisiyla korunuyor)
//	ama uc dogrudan cagrilabiliyordu ve slotlar uretiliyordu.
//
// ⚠️ KAPI **RANDEVU ALMA** YOLUNDADIR: `UygunSaatler` ve `Olustur` buradan
//
//	gecer. SALT OKUMA olan `AyarGetir` ise `AyarOkuSahip`i kullanir —
//	kapiyi oraya da uygulamak, kisisele donmus isletmenin ayar ekranini
//	(dolayisiyla "Gelen randevular" kutusuna giden TEK yolu) oldururdu.
//
// ⚠️ Gecmis randevularin LISTELENMESI bundan ETKILENMEZ: o uclar `AyarOku`
//
//	cagirmaz, dogrudan `randevular` tablosunu okur.
func AyarOku(ctx context.Context, db *pgxpool.Pool, isletmeID string) (Ayar, error) {
	return ayarOku(ctx, db, isletmeID, true)
}

// AyarOkuSahip — SAHIBIN kendi ayarlarini okur; `hesap_turu` kapisi YOKTUR.
// ⚠️ YALNIZ salt-okuma yollarinda kullan; randevu ALMA yolunda ASLA.
func AyarOkuSahip(ctx context.Context, db *pgxpool.Pool, isletmeID string) (Ayar, error) {
	return ayarOku(ctx, db, isletmeID, false)
}

func ayarOku(ctx context.Context, db *pgxpool.Pool,
	isletmeID string, hesapKapisi bool) (Ayar, error) {
	a := Ayar{SlotDakika: 30, SlotKapasite: 1, IleriGun: 14}
	var kategori string
	kapi := ""
	if hesapKapisi {
		kapi = ` AND u.hesap_turu = 'isletme'`
	}
	err := db.QueryRow(ctx, `
		SELECT COALESCE(i.kategori,'diger'),
		       COALESCE(r.acik,false), COALESCE(r.slot_dakika,30),
		       COALESCE(r.slot_kapasite,1), COALESCE(r.ileri_gun,14),
		       COALESCE(r.otomatik_onay,false)
		  FROM isletmeler i
		  JOIN users u ON u.id = i.user_id`+kapi+`
		  LEFT JOIN randevu_ayar r ON r.isletme_id = i.user_id
		 WHERE i.user_id = $1`, isletmeID).
		Scan(&kategori, &a.Acik, &a.SlotDakika, &a.SlotKapasite,
			&a.IleriGun, &a.OtomatikOnay)
	if err != nil {
		return a, err
	}
	a.Tur = TurBul(kategori)
	// ⚠️ SAVUNMA: bozuk/eski satirlar 0 tasiyabilir; 0 slot_dakika SONSUZ DONGU
	//    uretirdi.
	if a.SlotDakika < 5 {
		a.SlotDakika = 30
	}
	if a.SlotKapasite < 1 {
		a.SlotKapasite = 1
	}
	if a.IleriGun < 1 || a.IleriGun > 60 {
		a.IleriGun = 14
	}
	return a, nil
}

// SlotVarMi — verilen AN, isletmenin uretilen slotlarindan biri mi?
//
// ⚠️⚠️⚠️ TURU 80b — **GECE YARISI SARMASI** (denetim: SEVK ENGELIYDI).
//
//	Ilk yazimda `Olustur` yalnizca `bas`in KENDI TAKVIM GUNUNE bakiyordu:
//
//	    gunBasi := gun(bas);  Slotlar(gunBasi) icinde bas var mi?
//
//	Ama `Slotlar(gun)` "22:00 - 02:00" gibi calisma saatlerinde gece
//	yarisini ASAR ve ertesi takvim gunune tasan slotlari da URETIR
//	(kapanis <= acilis ise +1 gun, bkz. asagisi). Yani 11 Agustos 00:30
//	slotu **10 Agustos'un** calisma gunune aittir.
//	Dogrulama onu 11 Agustos'un listesinde aradigi icin BULAMIYOR ve
//	arayuzun GOSTERDIGI her gece-yarisi-sonrasi slot POST'ta **409**
//	donuyordu. Gece calisan mekanlar (bar, restoran) randevu ALAMAZDI —
//	ustelik bu, `ileri_gun` icin AYNI COMMIT'te duzelttigim
//	"okuma ve yazma FARKLI TABAN kullaniyor" hatasinin tekrariydi.
//
// ⚠️ Bu yuzden IKI GUN denenir: anin kendi gunu VE bir onceki gun.
//
//	(Bir slot en fazla bir gun tasabilir: `kapanis` en cok +24 saat kayar.)
//
// ⚠️ `Musait` BILEREK yok sayilir — kapasite karari advisory kilitli tek
//
//	deyimde verilir; burada okunsaydi karar IKI yerde yasardi.
//
// ⚠️ YAPMA: cagiran yerlerde bu kontrolu elle yazma (drift eder).
func SlotVarMi(ctx context.Context, db *pgxpool.Pool,
	isletmeID string, an time.Time, a Ayar) (bool, error) {
	loc := Konum()
	y := an.In(loc)
	gun := time.Date(y.Year(), y.Month(), y.Day(), 0, 0, 0, 0, loc)
	hedef := an.UTC().Format(time.RFC3339)

	for _, g := range []time.Time{gun, gun.AddDate(0, 0, -1)} {
		slotlar, err := Slotlar(ctx, db, isletmeID, g, a)
		if err != nil {
			return false, err
		}
		for _, s := range slotlar {
			if s.Zaman == hedef {
				return true, nil
			}
		}
	}
	return false, nil
}

// IleriGunDisi — verilen an, isletmenin "kac gun ileriye randevu alinabilir"
// penceresinin DISINDA mi?
//
// ⚠️⚠️ TURU 80b — IKI TARAF DA **GUN BASINA** normalize edilir (denetim).
//
//	Onceki surumde okuma yolu GUN BASINI (00:00), yazma yolu ise ISTENEN ANI
//	`time.Now().AddDate(0,0,IleriGun)` ile karsilastiriyordu; yani olcunun
//	TABANI farkliydi. Sonuc: ileriGun=14 ve saat 15:00 iken 14. gunun
//	takvimi ACILIYOR ve 18:00 slotu "musait" ciziliyor, ama o slota POST
//	atilinca 18:00 > 15:00 oldugu icin **400** donuyordu — kullanicinin
//	gordugu ile sunucunun kabul ettigi AYRISIYORDU.
//
// ⚠️ YAPMA: cagiran yerlerde bu karsilastirmayi elle tekrar yazma.
func IleriGunDisi(an time.Time, a Ayar) bool {
	loc := Konum()
	g := an.In(loc)
	gun := time.Date(g.Year(), g.Month(), g.Day(), 0, 0, 0, 0, loc)
	n := time.Now().In(loc)
	son := time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, loc).
		AddDate(0, 0, a.IleriGun)
	return gun.After(son)
}

// Slotlar — bir isletmenin BELIRLI BIR GUNUNDEKI tum slotlari.
//
// ⚠️ `gun` YEREL gunun basi olmali (00:00, Konum()).
func Slotlar(ctx context.Context, db *pgxpool.Pool,
	isletmeID string, gun time.Time, a Ayar) ([]Slot, error) {
	// ---- KAPALI GUN MU (bayram/tatil)
	var kapali bool
	db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM randevu_kapali
		               WHERE isletme_id=$1 AND tarih=$2::date)`,
		isletmeID, gun.Format("2006-01-02")).Scan(&kapali)
	if kapali {
		return []Slot{}, nil
	}

	// ---- CALISMA SAATLERI
	var ham []byte
	if err := db.QueryRow(ctx,
		`SELECT calisma FROM isletmeler WHERE user_id=$1`, isletmeID).
		Scan(&ham); err != nil {
		return nil, err
	}
	var gunler []calismaGun
	json.Unmarshal(ham, &gunler)

	var cg *calismaGun
	for i := range gunler {
		if gunler[i].Gun == int(gun.Weekday()) ||
			// ⚠️ Dart `weekday` 1..7 (Pazar=7), Go `Weekday` 0..6 (Pazar=0).
			//    Ikisini de kabul ediyoruz — istemci hangi bicimde yazdiysa.
			(gun.Weekday() == time.Sunday && gunler[i].Gun == 7) {
			cg = &gunler[i]
			break
		}
	}
	if cg == nil || cg.Kapali {
		return []Slot{}, nil
	}

	acilis, ok1 := saatAyristir(gun, cg.Acilis)
	kapanis, ok2 := saatAyristir(gun, cg.Kapanis)
	if !ok1 || !ok2 {
		return []Slot{}, nil
	}
	// ⚠️⚠️ GECE YARISI SARMASI: "22:00 - 02:00" gibi calisma saatlerinde kapanis
	//    acilistan KUCUKTUR ve dongu HIC calismazdi (ya da sonsuz olurdu).
	if !kapanis.After(acilis) {
		kapanis = kapanis.AddDate(0, 0, 1)
	}

	// ---- O GUNUN AKTIF RANDEVULARI (kapasite sayimi icin)
	rows, err := db.Query(ctx, `
		SELECT baslangic, sure_dakika FROM randevular
		 WHERE isletme_id=$1
		   AND durum = ANY($2)
		   AND baslangic >= $3 AND baslangic < $4`,
		isletmeID, AktifDurumlar, acilis.Add(-24*time.Hour), kapanis)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	type dolu struct{ bas, bit time.Time }
	var mevcut []dolu
	for rows.Next() {
		var b time.Time
		var sure int
		if rows.Scan(&b, &sure) != nil {
			continue
		}
		mevcut = append(mevcut, dolu{b, b.Add(time.Duration(sure) * time.Minute)})
	}

	// ---- SLOTLARI URET
	simdi := time.Now()
	out := []Slot{}
	adim := time.Duration(a.SlotDakika) * time.Minute
	for t := acilis; t.Add(adim).Compare(kapanis) <= 0; t = t.Add(adim) {
		// ⚠️ GECMIS SAATLER ELENIR — bugunun sabahina randevu alinamaz.
		if t.Before(simdi) {
			continue
		}
		bit := t.Add(adim)
		// ⚠️⚠️ CAKISMA = ARALIK ORTUSMESI, esit-saat DEGIL.
		//    Esitlik kullanilsaydi 10 masali bir restoran 19:00/19:30/20:00'a
		//    10'ar rezervasyon alirdi = 90 dakikada 30 rezervasyon, 10 masa.
		n := 0
		for _, m := range mevcut {
			if m.bas.Before(bit) && m.bit.After(t) {
				n++
			}
		}
		out = append(out, Slot{
			Saat:   t.Format("15:04"),
			Zaman:  t.UTC().Format(time.RFC3339),
			Musait: n < a.SlotKapasite,
		})
	}
	return out, nil
}

// "09:30" -> o gunun 09:30'u (yerel).
func saatAyristir(gun time.Time, s string) (time.Time, bool) {
	t, err := time.Parse("15:04", s)
	if err != nil {
		return time.Time{}, false
	}
	return time.Date(gun.Year(), gun.Month(), gun.Day(),
		t.Hour(), t.Minute(), 0, 0, gun.Location()), true
}
