// Package randevu — REZERVASYON (restoran) + RANDEVU (doktor vb.).
//
// Kullanici emri (turu 80): *"restoran/yemek firmalarindan rezervasyon,
// doktor vs.den randevu alinabilmeli"*.
//
// ═══════════ ⚠️⚠️ TEK TABLO, TEK KURAL ═══════════
//
// Rezervasyon ile randevu AYNI ISTIR (bir isletmeden zaman dilimi almak); fark
// yalnizca ETIKET ve iki alan. Ayri handler yazmak "ayni kuralin iki kopyasi"
// demekti ve bu proje o siniftan ALTI kez zarar gordu.
// Bu dosya, o tek kuralin YASADIGI yerdir: durum gecisleri, kim ne yapabilir,
// hangi kategori hangi turu gorur, cakisma yuklemi.
//
// ⚠️ YAPMA: bu sabitleri cagiran yerlere kopyalama.
package randevu

// Tur etiketleri. ⚠️ DB'de CHECK YOK (buyumeye acik boyut) — beyaz liste BURADA.
const (
	TurRezervasyon = "rezervasyon"
	TurRandevu     = "randevu"
)

// Durumlar. ⚠️ Yedisi de migration 038'in CHECK'inde ILK GUNDEN tanimli.
const (
	Bekliyor     = "bekliyor"
	Onaylandi    = "onaylandi"
	Reddedildi   = "reddedildi"
	Iptal        = "iptal"         // MUSTERI iptal etti
	IptalIsletme = "iptal_isletme" // ISLETME iptal etti
	Geldi        = "geldi"
	Gelmedi      = "gelmedi"
)

// ⚠️⚠️ AKTIF DURUMLAR — kapasite/cakisma sayiminda SAYILAN durumlar. **TEK
// KAYNAK**: hem `musait` slot uretimi hem `Olustur` cakisma kontrolu bunu
// kullanir. Ikisi ayrilirsa kullaniciya "musait" gosterilen bir slot
// olusturmada 409 doner (ya da tersi, kapasite asilir).
var AktifDurumlar = []string{Bekliyor, Onaylandi}

// ⚠️⚠️ KATEGORI -> TUR. Restoran/kafe/eglence REZERVASYON alir; digerleri
// RANDEVU. Kullanicinin cumlesi tam olarak bu ayrimi tarif ediyordu
// ("restoran ... rezervasyon, doktor ... randevu").
//
// ⚠️ Haritada OLMAYAN kategori RANDEVU sayilir — daha genel olan varsayilan.
var kategoriTuru = map[string]string{
	"yemek":   TurRezervasyon,
	"kafe":    TurRezervasyon,
	"eglence": TurRezervasyon,
}

// TurBul — isletme kategorisinden randevu turunu TURETIR.
//
// ⚠️ SONUC SATIRA YAZILIR VE DONDURULUR (okuma aninda tekrar turetilmez):
//
//	isletme kategorisini degistirirse GECMIS kayitlarin etiketi de degisir ve
//	"4 kisilik randevu" gibi anlamsiz satirlar cizilirdi.
func TurBul(kategori string) string {
	if t, ok := kategoriTuru[kategori]; ok {
		return t
	}
	return TurRandevu
}

// ⚠️⚠️⚠️ DURUM GECIS TABLOSU — **TEK KAYNAK**.
//
// Ayri `/onayla` `/reddet` `/iptal` uclari olsaydi "bu gecis yasal mi + dogru
// taraf miyim" kontrolu BES KOPYA olurdu. Tek uc + tek tablo.
//
// ⚠️ `iptal` YALNIZ MUSTERI, digerleri YALNIZ ISLETME. Bu ayrim olmasaydi
//
//	musteri kendini "geldi" isaretler, isletme de "musteri iptal etti" gibi
//	kayit birakirdi.
type Gecis struct {
	// Bu hedefe hangi durumlardan gecilebilir.
	Onceki []string
	// true = yalniz ISLETME, false = yalniz MUSTERI.
	IsletmeYapar bool
	// Karsi tarafa gidecek bildirim turu ("" = bildirim YOK).
	Bildirim string
}

var Gecisler = map[string]Gecis{
	Onaylandi: {
		Onceki: []string{Bekliyor}, IsletmeYapar: true,
		Bildirim: "randevu_onaylandi",
	},
	Reddedildi: {
		Onceki: []string{Bekliyor}, IsletmeYapar: true,
		Bildirim: "randevu_reddedildi",
	},
	IptalIsletme: {
		Onceki: []string{Bekliyor, Onaylandi}, IsletmeYapar: true,
		Bildirim: "randevu_iptal",
	},
	// ⚠️ 'geldi'/'gelmedi' BILDIRIM URETMEZ: "gelmedin" bildirimi saldirgan ve
	//    bu isaret isletmenin KENDI IC KAYDIDIR.
	Geldi:   {Onceki: []string{Onaylandi}, IsletmeYapar: true},
	Gelmedi: {Onceki: []string{Onaylandi}, IsletmeYapar: true},
	Iptal: {
		Onceki: []string{Bekliyor, Onaylandi}, IsletmeYapar: false,
		Bildirim: "randevu_iptal",
	},
}

// ⚠️ Yeni talep bildirimi (gecis tablosunda DEGIL — olusturma bir gecis degil).
const BildirimYeni = "randevu_yeni"
