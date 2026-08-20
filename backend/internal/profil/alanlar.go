// ⚠️⚠️⚠️ TURU 120 — YAS · ILGI ALANLARI · TAKIM alanlarinin **TEK
// DOGRULAMA KAYNAGI**.
//
// Bu uc alan IKI ayri uctan yazilabiliyor:
//
//	POST  /auth/kayit/tamamla   (internal/auth)   — kayit akisinin 4. adimi
//	PATCH /users/me             (internal/users)  — profil duzenleme
//
// Kurallari her iki pakete de KOPYALASAYDIK, bu projede ALTI KEZ yasanan
// *"ayni kuralin iki kopyasi DRIFT EDER"* hatasini yedinci kez yasardik:
// biri tavani 12'ye cikarir, oteki 8'de kalir; kayitta kabul edilen bir deger
// profil duzenlemede reddedilir.
//
// ⚠️ NEDEN YENI (KUCUK) BIR PAKET: `internal/users` zaten `internal/auth`i
//    import ediyor (`auth.UserID`). Yardimcilari `users`a koyup `auth`tan
//    cagirmak **IMPORT DONGUSU** olurdu ve derlenmezdi. Notr bir paket tek
//    cozum.
// ⚠️ YAPMA: bu kurallari cagiran paketlere geri kopyalama.
package profil

import (
	"strings"
	"time"
)

// ⚠️ Yas TAVANLARI. `EnKucukYas` 13: cogu sosyal urunun (ve App Store yas
//    derecelendirmesinin) alt siniri. Daha kucugunu kabul etmek yasal risk.
const (
	EnKucukYas = 13
	EnBuyukYas = 90
)

// Ilgi alani sayisi ve tek bir etiketin uzunluk tavani.
//
// ⚠️ Tavan ZORUNLU: sunucu bu alanlari BEYAZ LISTEYE gore dogrulamaz (bkz.
//    asagidaki serh), yani tavansiz birakilirsa istemci profile 10 KB'lik
//    metin yazdirabilir ve o metin her profil okumasinda taşınır.
const (
	EnFazlaIlgi    = 12
	EnUzunEtiket   = 32
	EnUzunTakimAdi = 32
)

// ⚠️⚠️ **BEYAZ LISTE YOK — BILINCLI.**
//
//	Ilgi alanlari ve takim listesi bugun ISTEMCIDE duruyor. Sunucuya beyaz
//	liste koymak, listeye yeni bir madde eklemeyi **DEPLOY + ISTEMCI
//	GUNCELLEMESI** gerektiren bir ise cevirirdi ve eski surumdeki kullanici
//	kendi sectigi degeri KAYBEDERDI (sunucu reddeder).
//
//	Turu 77'nin *"kategori agacini istemciye yazma"* kurali BURADA GECERLI
//	DEGIL: o kural, bir listenin SORGU DAVRANISINI (hangi isletme hangi
//	kategoride listelenir) belirledigi durum icindi. Bu alanlar hicbir
//	sorguyu, yetkiyi ya da siralamayi beslemiyor — profil suslemesi.
//
// ⚠️ Ileride "ilgi alanina gore oneri" gibi bir ozellik gelirse liste
//    SUNUCUYA tasinmali ve BURASI beyaz listeye cevrilmelidir.

// TemizIlgi ilgi alani listesini normalize eder.
//
// ⚠️⚠️ **ASLA `nil` DONMEZ.** `users.ilgi_alanlari` NOT NULL; pgx `nil` dilimi
//
//	SQL NULL'a cevirir ve INSERT **23502** ile patlar. Bu, turu 75b'de
//	`posts.media_ids` uzerinde YASANMIS bir sevk engelidir ("HER yazi
//	gonderisi 500 donuyordu").
//
// ⚠️ Tekrarlar HARF DUYARSIZ elenir: "Futbol" ve "futbol" ayni sey.
//
//	Turkce kucultme icin `strings.ToLower` KULLANILMAZ — "İ" harfini
//	birlesik noktali bir karaktere cevirir (turu 91 dersi); burada yalniz
//	KARSILASTIRMA icin `strings.EqualFold` yeter ve gorunen deger
//	KULLANICININ YAZDIGI HALIYLE saklanir.
func TemizIlgi(in []string) []string {
	out := make([]string, 0, EnFazlaIlgi)
	for _, ham := range in {
		e := strings.TrimSpace(ham)
		if e == "" {
			continue
		}
		if len(e) > EnUzunEtiket {
			// ⚠️ KIRPILMAZ, ATILIR: yarim kirpilmis bir etiket ("Fotoğrafçıl")
			//    kullaniciya YANLIS BILGI gosterirdi.
			continue
		}
		yinelenen := false
		for _, v := range out {
			if strings.EqualFold(v, e) {
				yinelenen = true
				break
			}
		}
		if yinelenen {
			continue
		}
		out = append(out, e)
		if len(out) == EnFazlaIlgi {
			break
		}
	}
	return out
}

// TemizTakim takim adini normalize eder (bos = "belirtmedi").
func TemizTakim(s string) string {
	t := strings.TrimSpace(s)
	if len(t) > EnUzunTakimAdi {
		return ""
	}
	return t
}

// TemizDogumYili makul araligin disindaki degeri **DUSURUR** (`nil`).
//
// ⚠️ 400 DONDURULMEZ: alan OPSIYONEL ve istemci secicisi zaten araligi
//
//	kisitliyor. Arali disinda bir deger ancak bozuk/eski bir istemciden
//	gelir; o durumda kaydi reddedip kullaniciyi kayit akisinda MAHSUR
//	birakmak, alani sessizce bos birakmaktan cok daha kotudur.
//
// ⚠️ Tavan `time.Now()`ten TURETILIR, sabit yil YAZILMAZ: sabit yazilsaydi
//
//	kural birkac yil icinde kendiliginden yanlislasirdi (migration serhinde
//	CHECK'in neden koyulmadiginin da gerekcesi budur).
func TemizDogumYili(y *int) *int {
	if y == nil {
		return nil
	}
	buYil := time.Now().Year()
	enErken := buYil - EnBuyukYas
	enGec := buYil - EnKucukYas
	if *y < enErken || *y > enGec {
		return nil
	}
	v := *y
	return &v
}
