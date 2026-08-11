package isletme

import (
	"net/http"

	"github.com/gbz-app/gebzem/backend/internal/ilan"
)

// ⚠️⚠️⚠️ TURU 89 — KATEGORIYE OZEL ISLETME MODULLERI.
//
// Kullanici emri: *"otel ekledin ama ODALAR var mi? isletme oda eklemeli,
// doktorlar vs HIZMET ALANI eklemeli, belirli baslikli MODULLER olacakti"*.
//
// ═══════════ SORUN ═══════════
//
// `isletme_urunleri` TEK ve GENEL bir katalogdu: otelci de kuafor de doktor da
// **"Bölüm (Ana Yemekler, Tatlılar...)"** yazan bir restoran formu goruyordu.
// Kategoriye gore degisen HICBIR arayuz yoktu; `kategori` yalnizca bir etiket
// cipiydi.
//
// ═══════════ COZUM: TANIM SUNUCUDA, FORM ISTEMCIDE URETILIR ═══════════
//
// Bu desen projede ZATEN COZULMUS: `ilan` paketi `tur` + `ozellikler JSONB`
// tutuyor, alan tanimlarini `GET /ilan-kategoriler` ile gonderiyor ve Flutter
// formu SUNUCUDAN uretiyor. Ayni yol burada da izleniyor.
//
// ⚠️ `ilan.Alan` tipi YENIDEN TANIMLANMADI, IMPORT EDILDI. Ikinci bir `Alan`
//    tipi acmak istemci tarafinda da ikinci bir ayristirici gerektirirdi ve
//    iki tanim KACINILMAZ OLARAK DRIFT EDERDI (bu projede alti kez yasandi).
//    Dairesel bagimlilik YOK: `ilan` paketi `isletme`yi import etmiyor.
// ⚠️ TANIM ISTEMCIYE GOMULMEDI: gomulseydi Go + Dart arasinda UCUNCU bir
//    kopya acilirdi. `isletmeKategorileri` zaten itiraf edilmis bir kopya ve
//    o kopyanin ucuncusu (vitrin) turu 85b'de SESSIZCE KIRILMISTI.

// Modul, bir isletme kategorisinin katalog davranisini tanimlar.
type Modul struct {
	// Katalog basligi ve dugme etiketi ("Odalar", "Hizmetler", "Menü").
	Ad string `json:"ad"`
	// Tekil ad ("Oda ekle", "Hizmet ekle").
	Tekil string `json:"tekil"`
	// `isletme_urunleri.tur` sutununa yazilacak deger.
	Tur string `json:"tur"`
	// Bolum alaninin etiketi — kategoriye gore ornek degisir.
	BolumEtiketi string `json:"bolum_etiketi"`
	// Kategoriye ozel ek alanlar (`ozellikler` JSONB'sine yazilir).
	Alanlar []ilan.Alan `json:"alanlar"`
}

// ⚠️ `tur` BEYAZ LISTESI — DB'de CHECK YOK (bkz. migration 043 serhi).
//
//	Gecersiz bir tur gelirse `'urun'`a duser; istek REDDEDILMEZ, cunku tur
//	kullanicinin yazdigi bir sey degil KATEGORIDEN turetilen bir detaydir.
var gecerliTurler = map[string]bool{"urun": true, "oda": true, "hizmet": true}

// TurGecerli, istemciden gelen turu beyaz listeye gore normalize eder.
func TurGecerli(t string) string {
	if gecerliTurler[t] {
		return t
	}
	return "urun"
}

// ⚠️ Haritada OLMAYAN kategori `varsayilanModul`e duser — yani yeni bir
//
//	kategori eklemek bu dosyayi degistirmeyi ZORUNLU kilmaz (ozellik
//	"var gorunup calismiyor" haline gelmez).
var varsayilanModul = Modul{
	Ad: "Ürünler", Tekil: "Ürün", Tur: "urun",
	BolumEtiketi: "Bölüm (İçecekler, Tatlılar...)",
}

var moduller = map[string]Modul{
	"otel": {
		Ad: "Odalar", Tekil: "Oda", Tur: "oda",
		BolumEtiketi: "Bölüm (Standart, Suit...)",
		Alanlar: []ilan.Alan{
			{Anahtar: "kapasite", Ad: "Kapasite", Tip: "sayi", Birim: "kişi"},
			{Anahtar: "yatak", Ad: "Yatak", Tip: "secim",
				Secenekler: []string{"Tek kişilik", "Çift kişilik", "İki ayrı yatak", "Kanepe dahil"}},
			{Anahtar: "kahvalti", Ad: "Kahvaltı", Tip: "secim",
				Secenekler: []string{"Dahil", "Dahil değil"}},
			{Anahtar: "metrekare", Ad: "Büyüklük", Tip: "sayi", Birim: "m²"},
		},
	},
	"saglik": {
		Ad: "Hizmetler", Tekil: "Hizmet", Tur: "hizmet",
		BolumEtiketi: "Bölüm (Muayene, Tahlil...)",
		Alanlar: []ilan.Alan{
			// ⚠️ `sure_dakika` ANAHTARI RANDEVUYLA ORTAK: `randevular.sure_dakika`
			//    sutunu 038'den beri VAR. Ileride randevu bu degeri okuyacak.
			{Anahtar: "sure_dakika", Ad: "Süre", Tip: "sayi", Birim: "dk"},
		},
	},
	"kuafor": {
		Ad: "Hizmetler", Tekil: "Hizmet", Tur: "hizmet",
		BolumEtiketi: "Bölüm (Saç, Bakım...)",
		Alanlar: []ilan.Alan{
			{Anahtar: "sure_dakika", Ad: "Süre", Tip: "sayi", Birim: "dk"},
		},
	},
	"eczane": {
		Ad: "Ürünler", Tekil: "Ürün", Tur: "urun",
		BolumEtiketi: "Bölüm (İlaç, Bakım...)",
	},
	"yemek": {
		Ad: "Menü", Tekil: "Ürün", Tur: "urun",
		BolumEtiketi: "Bölüm (Ana Yemekler, Tatlılar...)",
	},
	"kafe": {
		Ad: "Menü", Tekil: "Ürün", Tur: "urun",
		BolumEtiketi: "Bölüm (Kahveler, Tatlılar...)",
	},
	"spor": {
		Ad: "Hizmetler", Tekil: "Hizmet", Tur: "hizmet",
		BolumEtiketi: "Bölüm (Üyelik, Ders...)",
		Alanlar: []ilan.Alan{
			{Anahtar: "sure_dakika", Ad: "Süre", Tip: "sayi", Birim: "dk"},
		},
	},
	"egitim": {
		Ad: "Hizmetler", Tekil: "Hizmet", Tur: "hizmet",
		BolumEtiketi: "Bölüm (Kurs, Özel ders...)",
		Alanlar: []ilan.Alan{
			{Anahtar: "sure_dakika", Ad: "Süre", Tip: "sayi", Birim: "dk"},
		},
	},
	// ⚠️⚠️ TURU 90b — BU IKISI TURU 90'DA `Kategoriler`E EKLENDI AMA BURAYA
	// EKLENMEDI ve `varsayilanModul`e (= "Ürünler") dusuyorlardi. Somut bedel:
	// bir DIYETISYEN katalogunda "Hizmet ekle" yerine "Ürün ekle" ve bolum
	// etiketinde **"Bölüm (İçecekler, Tatlılar...)"** goruyordu; ustelik
	// `sure_dakika` HICBIR YERDE cizilmiyordu (`alanlar` bos) ve o kaydi
	// DUZENLEYINCE turu sessizce `'hizmet'` -> `'urun'` donuyordu.
	// ⚠️ DERS (turu 89'un aynisi): yeni bir KATEGORI eklerken `Kategoriler`
	//    ve `moduller` HARITALARINI BIRLIKTE guncelle.
	"diyetisyen": {
		Ad: "Hizmetler", Tekil: "Hizmet", Tur: "hizmet",
		BolumEtiketi: "Bölüm (Danışmanlık, Program...)",
		Alanlar: []ilan.Alan{
			{Anahtar: "sure_dakika", Ad: "Süre", Tip: "sayi", Birim: "dk"},
		},
	},
	"guzellik": {
		Ad: "Hizmetler", Tekil: "Hizmet", Tur: "hizmet",
		BolumEtiketi: "Bölüm (Cilt, Bakım...)",
		Alanlar: []ilan.Alan{
			{Anahtar: "sure_dakika", Ad: "Süre", Tip: "sayi", Birim: "dk"},
		},
	},
}

// ModulBul, kategoriye gore modulu doner (bilinmeyen kategori -> varsayilan).
//
// ⚠️ `randevu.TurBul()` ile AYNI desen: kategori -> davranis turetmesi TEK
//
//	YERDE yapilir ve istemci onu SUNUCUDAN ogrenir.
func ModulBul(kategori string) Modul {
	if m, ok := moduller[kategori]; ok {
		return m
	}
	return varsayilanModul
}

// GET /isletme-modulleri — tum kategori -> modul haritasi.
//
// ⚠️ Istemci bunu bir kez cekip onbellekler; boylece yeni bir alan eklemek
//
//	ISTEMCI GUNCELLEMESI GEREKTIRMEZ (`ilan.Agac` ucuyla ayni gerekce).
func (h *Handler) Moduller(w http.ResponseWriter, r *http.Request) {
	yaz(w, 200, map[string]any{
		"moduller":   moduller,
		"varsayilan": varsayilanModul,
	})
}
