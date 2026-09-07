package isletme

import (
	"net/http"
	"strings"
)

// ⚠️⚠️⚠️ TURU 180 — ISLETME OZELLIKLERI VE ODEME SECENEKLERI (TEK KAYNAK).
//
// Kullanici emri (ikinci kez): *"bilgi kisminda odeme secenekleri, ozellikler
// yok; sigara icilmez, cocuk yeri vs — onlari da koyman gerekiyor"*.
//
// ⚠️⚠️ **KATALOG SUNUCUDA, ISTEMCIDE DEGIL** (turu 77 kurali). Istemciye
//	gomulseydi yeni bir ozellik eklemek MAGAZA ONAYI gerektirir ve eski
//	surumler listeyi EKSIK gosterirdi. Ad ve ikon adi sunucudan gelir;
//	istemci yalnizca cizer.
//
// ⚠️ Ikon adlari **Lucide** kimlikleri; istemci `_ikonBul` ile cozer ve
//	bilinmeyen adda notr bir ikona duser (yeni bir ozellik eski istemcide
//	ETIKETSIZ degil, YANLIS IKONLU degil, NOTR ikonlu gorunur).
//
// ⚠️ Anahtarlar **DEGISMEZ**: veritabaninda saklanan sey bunlar. Etiket
//	degistirmek serbest, ANAHTAR degistirmek eski kayitlari OKUNAMAZ yapar.

// OzellikAdlari — anahtar -> (etiket, ikon).
var OzellikAdlari = map[string][2]string{
	"wifi":         {"Ücretsiz Wi-Fi", "wifi"},
	"otopark":      {"Otopark", "circleParking"},
	"sigara_yok":   {"Sigara içilmez", "cigaretteOff"},
	"sigara_alani": {"Sigara alanı", "cigarette"},
	"cocuk":        {"Çocuk oyun alanı", "baby"},
	"bebek":        {"Bebek bakım odası", "babyCarriage"},
	"engelli":      {"Engelli erişimi", "accessibility"},
	"paket":        {"Paket servis", "package"},
	"gel_al":       {"Gel-al", "shoppingBag"},
	"rezervasyon":  {"Rezervasyon", "calendarCheck"},
	"acik_alan":    {"Açık alan / bahçe", "treePine"},
	"evcil":        {"Evcil hayvan kabul", "pawPrint"},
	"klima":        {"Klima", "airVent"},
	"tv":           {"Maç yayını", "tv"},
	"vale":         {"Vale", "car"},
	"24_saat":      {"24 saat açık", "clock"},
}

// OdemeAdlari — anahtar -> (etiket, ikon).
var OdemeAdlari = map[string][2]string{
	"nakit":       {"Nakit", "banknote"},
	"kredi":       {"Kredi kartı", "creditCard"},
	"banka":       {"Banka kartı", "creditCard"},
	"temassiz":    {"Temassız", "nfc"},
	"yemek_karti": {"Yemek kartı", "utensils"},
	"online":      {"Online ödeme", "globe"},
	"qr":          {"QR ile ödeme", "qrCode"},
}

// temizListe — istemciden gelen listeyi beyaz listeden gecirir.
//
// ⚠️⚠️ **`nil` DONMEZ**: cagiran onu dogrudan SQL'e veriyor ve `nil` bir Go
//	dilimi SQL NULL'a cevrilir; sutun NOT NULL oldugu icin `23502` gelir.
//	Bu proje o hatayi turu 75b'de `posts.media_ids` uzerinde YASADI (her
//	yazi gonderisi 500 donuyordu).
//
// ⚠️ Isaretci `nil` ise (alan HIC gonderilmedi) yine `nil` doner — o durumda
//	SQL tarafindaki `COALESCE` mevcut degeri KORUR. Bos DILIM ise
//	"bosalt" demektir ve `{}` yazilir. Ikisi FARKLI seylerdir.
//
// ⚠️ Yinelenenler elenir ve tavan uygulanir: bozuk bir istemci 10.000 kayit
//	gonderip satiri sisiremesin.
func temizListe(kaynak *[]string, gecerli map[string][2]string) []string {
	if kaynak == nil {
		return nil
	}
	const tavan = 40
	gorulen := map[string]bool{}
	cikti := []string{}
	for _, k := range *kaynak {
		if _, ok := gecerli[k]; !ok || gorulen[k] {
			continue
		}
		gorulen[k] = true
		cikti = append(cikti, k)
		if len(cikti) >= tavan {
			break
		}
	}
	return cikti
}

// katalogListe — istemcinin cizecegi tanim listesi.
//
// ⚠️ Sira DETERMINISTIK olmali: Go'da map yinelemesi RASTGELEDIR ve liste
//	her istekte farkli siralanirsa duzenleme ekranindaki cipler her
//	acilista YER DEGISTIRIRDI.
func katalogListe(m map[string][2]string, sira []string) []map[string]string {
	out := make([]map[string]string, 0, len(sira))
	for _, k := range sira {
		v, ok := m[k]
		if !ok {
			continue
		}
		out = append(out, map[string]string{"anahtar": k, "ad": v[0], "ikon": v[1]})
	}
	return out
}

// ⚠️ Gorunen SIRA burada; `OzellikAdlari`/`OdemeAdlari` yalniz TANIM tutar.
//
//	⚠️ Yeni bir ozellik eklerken **IKI YERE** de yaz: haritaya (tanim) ve
//	   bu diziye (sira). Yalniz haritaya yazilirsa katalogda GORUNMEZ —
//	   bu projede "sutun var, okuyan yol yok" sinifinin ta kendisi.
var ozellikSira = []string{
	"wifi", "otopark", "vale", "sigara_yok", "sigara_alani", "cocuk", "bebek",
	"engelli", "evcil", "acik_alan", "klima", "tv", "paket", "gel_al",
	"rezervasyon", "24_saat",
}

var odemeSira = []string{
	"nakit", "kredi", "banka", "temassiz", "yemek_karti", "online", "qr",
}

// Katalog — GET /isletme-katalog
//
// ⚠️ Ozellik ve odeme TANIMLARI istemciye BURADAN gider; istemcide ikinci bir
//
//	kopya YOKTUR (turu 77 kurali: yeni bir ozellik magaza onayi
//	GEREKTIRMEMELI).
func (h *Handler) Katalog(w http.ResponseWriter, r *http.Request) {
	yaz(w, 200, map[string]any{
		"ozellikler": katalogListe(OzellikAdlari, ozellikSira),
		"odeme":      katalogListe(OdemeAdlari, odemeSira),
	})
}

// temizMedya — kapak slideri icin gonderilen medya id listesini dogrular.
//
// ⚠️⚠️ TURU 180k — `temizListe`den AYRI bir yardimci ve bu bilincli: oradaki
//
//	dogrulama SABIT BIR BEYAZ LISTEYE bakiyor (`OzellikAdlari`), burada ise
//	deger bir medya id'si — kume ONCEDEN BILINEMEZ. Ayni fonksiyona
//	"beyaz liste nil ise her seyi kabul et" gibi bir dal eklemek, ozellik
//	tarafindaki kapiyi da tek satirlik bir hatayla ACARDI.
//
// ⚠️⚠️ **`nil` KAYNAK -> `nil` DONER** (`temizListe` ile ayni sozlesme):
//
//	cagri yerindeki `COALESCE($n::text[], isletmeler.kapak_medyalari)`
//	bunu "alan gonderilmedi, MEVCUDU KORU" diye okur. Bos dilim
//	(`[]string{}`) ise "slideri BOSALT" demektir — ikisi AYRI seydir.
//
// ⚠️⚠️ **BOS DILIM ASLA `nil` DONMEZ**: NOT NULL sutuna `nil` dilim yazmak
//
//	SQL NULL'a cevrilir ve `23502` verir (turu 75b `posts.media_ids`
//	sevk engelinin birebir aynisi).
//
// ⚠️ UUID BICIM SUZGECI ZORUNLU: tek bozuk deger `text[]` sutununa yazilir,
//
//	istemci onu cozemez ve slaytta KIRIK bir kutu cizilir. Ayrica ileride
//	bu sutun bir sorguda `= ANY(...)` ile uuid'ye karsi kullanilirsa
//	**TUM SORGU 500 doner** (turu 113'te `favorim` cast'inda yasandi).
//
// ⚠️ Tavan **8**: slider bir vitrindir, albüm degil. Sinirsiz birakilsaydi
//
//	istemci acilista onlarca medya id'si icin imzali adres cozmeye
//	calisirdi (turu 91'de olculen N+1 sinifi).
func temizMedya(kaynak *[]string) []string {
	if kaynak == nil {
		return nil
	}
	const tavan = 8
	gorulen := map[string]bool{}
	cikti := []string{}
	for _, k := range *kaynak {
		k = strings.TrimSpace(k)
		if !uuidBicimi(k) || gorulen[k] {
			continue
		}
		gorulen[k] = true
		cikti = append(cikti, k)
		if len(cikti) >= tavan {
			break
		}
	}
	return cikti
}

// uuidBicimi — 8-4-4-4-12 onaltilik bicim (surum/varyant SORGULANMAZ).
//
// ⚠️ `regexp` KULLANILMADI: bu fonksiyon her kayitta 8 kez kosuyor ve elle
//
//	tarama hem daha ucuz hem bagimliliksiz. Ayrica projede regex'in
//	Turkce/kacis tuzaklariyla defalarca sorun yasandi (turu 157).
func uuidBicimi(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if c != '-' {
				return false
			}
			continue
		}
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') && (c < 'A' || c > 'F') {
			return false
		}
	}
	return true
}
