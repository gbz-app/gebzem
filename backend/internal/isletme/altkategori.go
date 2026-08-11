package isletme

import (
	"net/http"
	"strings"
)

// ⚠️⚠️⚠️ TURU 92 — KATEGORI ICI **ALT KATEGORILER** (kullanici emri:
// *"yemek kategorisinde aramanin altinda ufak kartlar olacak, 60x60
// radiuslu, iste doner kebap gibi"*).
//
// ═══════════ NEDEN SUNUCUDA ═══════════
//
// Turu 77'nin kurali: *"Dart'a kategori/tur sabiti YAZMA"* — bu projede
// "ayni listenin Go + Dart iki kopyasi" itiraf edilmis bir drift bombasi
// (turu 72b/H). Alt kategori listesi de ayni sinif: istemciye yazilsaydi
// yeni bir alt kategori eklemek ISTEMCI GUNCELLEMESI + magaza onayi
// gerektirirdi ve eski surumler listeyi EKSIK gosterirdi.
//
// ⚠️ ARAMA METNINE CEVRILIR, AYRI SUTUN ACILMAZ.
//
//	Alt kategori bir SUZGEC KISAYOLUDUR: "Döner"e dokunmak `q=döner`
//	aramasi yapar. `isletmeler` tablosuna `alt_kategori` sutunu eklemek
//	(a) migration + doldurma isi, (b) isletmelerin o alani DOLDURMASINI
//	gerektirir — bugun hicbir isletmede dolu olmayan bir sutun, kartlarin
//	HEPSINI BOS SONUC dondururdu. Ad/aciklama uzerinde arama BUGUN calisir.
//	⚠️ YAPMA: bunun icin migration acma; once isletmelerin dolduracagi bir
//	   arayuz ve veri lazim.
//
// ⚠️ `Ara` alani ad DISINDA olabilir: "Ev Yemeği" karti `ev yemeği` arar.
type AltKategori struct {
	Ad string `json:"ad"`
	// Karta dokununca calisacak arama metni.
	Ara string `json:"ara"`
}

// ⚠️ Kategori anahtari -> alt kategoriler. Bir kategorinin girisi YOKSA
//
//	istemci serit CIZMEZ (bos gri kutu birakmiyoruz).
//
// ⚠️ HER LISTE 6-10 KALEM: kullanici emri "ufak kartlar" ve serit YATAY
//
//	kaydiriliyor; 20 kalem kaydirmayi anlamsiz uzatirdi.
var altKategoriler = map[string][]AltKategori{
	"yemek": {
		{"Döner", "döner"}, {"Kebap", "kebap"}, {"Pide", "pide"},
		{"Lahmacun", "lahmacun"}, {"Pizza", "pizza"}, {"Burger", "burger"},
		{"Balık", "balık"}, {"Ev Yemeği", "ev yemeği"},
		{"Çorba", "çorba"}, {"Tatlı", "tatlı"},
	},
	"kafe": {
		{"Kahve", "kahve"}, {"Pastane", "pasta"}, {"Waffle", "waffle"},
		{"Tost", "tost"}, {"Kahvaltı", "kahvaltı"}, {"Nargile", "nargile"},
	},
	"market": {
		{"Bakkal", "bakkal"}, {"Manav", "manav"}, {"Kasap", "kasap"},
		{"Şarküteri", "şarküteri"}, {"Kuruyemiş", "kuruyemiş"},
		{"Su", "su"},
	},
	"kuafor": {
		{"Saç Kesim", "saç"}, {"Boya", "boya"}, {"Bakım", "bakım"},
		{"Gelin Saçı", "gelin"}, {"Sakal", "sakal"},
	},
	"guzellik": {
		{"Cilt Bakımı", "cilt"}, {"Ağda", "ağda"}, {"Manikür", "manikür"},
		{"Kalıcı Makyaj", "makyaj"}, {"Lazer", "lazer"},
	},
	"saglik": {
		{"Diş", "diş"}, {"Göz", "göz"}, {"Dahiliye", "dahiliye"},
		{"Fizik Tedavi", "fizik"}, {"Psikolog", "psikolog"},
		{"Veteriner", "veteriner"},
	},
	"diyetisyen": {
		{"Kilo Verme", "kilo"}, {"Sporcu", "sporcu"},
		{"Çocuk", "çocuk"}, {"Hamile", "hamile"},
	},
	"otel": {
		{"Butik Otel", "butik"}, {"Apart", "apart"}, {"Pansiyon", "pansiyon"},
		{"Termal", "termal"}, {"Bungalov", "bungalov"},
	},
	"oto": {
		{"Servis", "servis"}, {"Lastik", "lastik"}, {"Yıkama", "yıkama"},
		{"Kaporta", "kaporta"}, {"Yedek Parça", "parça"},
	},
	"egitim": {
		{"Dershane", "dershane"}, {"Kurs", "kurs"}, {"Dil", "dil"},
		{"Müzik", "müzik"}, {"Sürücü", "sürücü"},
	},
	"spor": {
		{"Spor Salonu", "salon"}, {"Yüzme", "yüzme"}, {"Pilates", "pilates"},
		{"Dövüş", "dövüş"}, {"Halı Saha", "saha"},
	},
	"giyim": {
		{"Kadın", "kadın"}, {"Erkek", "erkek"}, {"Çocuk", "çocuk"},
		{"Ayakkabı", "ayakkabı"}, {"Aksesuar", "aksesuar"},
	},
	"teknoloji": {
		{"Telefon", "telefon"}, {"Bilgisayar", "bilgisayar"},
		{"Tamir", "tamir"}, {"Aksesuar", "aksesuar"},
	},
	"eglence": {
		{"Sinema", "sinema"}, {"Oyun", "oyun"}, {"Bowling", "bowling"},
		{"Kafe Bar", "bar"}, {"Organizasyon", "organizasyon"},
	},
	"eczane": {
		{"Nöbetçi", "nöbetçi"}, {"Dermokozmetik", "dermokozmetik"},
		{"Medikal", "medikal"},
	},
	"emlak": {
		{"Satılık", "satılık"}, {"Kiralık", "kiralık"},
		{"Arsa", "arsa"}, {"İş Yeri", "iş yeri"},
	},
	"hizmet": {
		{"Tadilat", "tadilat"}, {"Nakliyat", "nakliyat"},
		{"Temizlik", "temizlik"}, {"Tesisat", "tesisat"},
		{"Elektrik", "elektrik"},
	},
}

// ⚠️⚠️ SLIDER METINLERI DE SUNUCUDAN (kullanici emri: *"sliderda kisa
// baslik, altinda kisa PROFESYONEL baslik, 3-4 tane"*).
//
// ⚠️ Istemciye yazilsaydi metni degistirmek MAGAZA ONAYI gerektirirdi.
//
//	Sunucuda oldugu icin bir cumleyi duzeltmek DEPLOY yeter.
//
// ⚠️ Kategori girisi YOKSA `sliderVarsayilan` kullanilir — slider HICBIR
//
//	kategoride BOS kalmaz (kullanici 350px'lik bos gri kutu gormemeli).
type SliderKarti struct {
	Baslik  string `json:"baslik"`
	AltMetn string `json:"alt"`
}

var kategoriSlider = map[string][]SliderKarti{
	"yemek": {
		{"Bugün ne yesek?", "Çevrendeki lezzetleri keşfet"},
		{"Sıcak ve taze", "Yakınındaki mutfaklar seni bekliyor"},
		{"Kalabalık sofralar", "Ailece gidebileceğin mekânlar"},
	},
	"kafe": {
		{"Bir kahve molası", "Sakin köşeler, iyi kahveler"},
		{"Tatlı bir ara", "Pastane ve tatlıcılar"},
		{"Kahvaltı zamanı", "Güne iyi başla"},
	},
	"kuafor": {
		{"Yeni bir görünüm", "Çevrendeki kuaförler"},
		{"Randevunu şimdi al", "Sıra beklemeden"},
		{"Özel günler", "Gelin saçı ve bakım"},
	},
	"guzellik": {
		{"Kendine iyi bak", "Güzellik merkezleri yakınında"},
		{"Cilt bakımı", "Uzman eller"},
		{"Randevu kolaylığı", "Uygun saati seç, gel"},
	},
	"saglik": {
		{"Sağlığın önce gelir", "Yakınındaki sağlık hizmetleri"},
		{"Randevu al", "Beklemeden, kolayca"},
		{"Uzman hekimler", "Alanında deneyimli"},
	},
	"diyetisyen": {
		{"Hedefine ulaş", "Sana özel beslenme planı"},
		{"Takipte kal", "Öğün ve ölçüm takibi tek yerde"},
		{"Uzman desteği", "Diyetisyenin her adımda yanında"},
	},
	"otel": {
		{"Konaklama bul", "Çevrendeki oteller ve apartlar"},
		{"Kısa kaçamaklar", "Hafta sonu için"},
		{"Uygun fiyat", "Karşılaştır, seç"},
	},
	"market": {
		{"Günlük alışveriş", "Yakınındaki marketler"},
		{"Taze ürünler", "Manav ve kasaplar"},
		{"Hemen yanında", "Adım atmadan bul"},
	},
	"egitim": {
		{"Öğrenmeye devam", "Kurslar ve dershaneler"},
		{"Yeni bir beceri", "Dil, müzik, meslek"},
		{"Yakınında", "Ulaşımı kolay seçenekler"},
	},
	"spor": {
		{"Harekete geç", "Salonlar ve sahalar"},
		{"Bugün başla", "Çevrendeki spor tesisleri"},
		{"Birlikte daha iyi", "Grup dersleri"},
	},
	"oto": {
		{"Aracın emin ellerde", "Servis ve tamirciler"},
		{"Bakım zamanı", "Yakınındaki ustalar"},
		{"Hızlı çözüm", "Lastik, yıkama, kaporta"},
	},
}

var sliderVarsayilan = []SliderKarti{
	{"Çevrende keşfet", "Yakınındaki işletmeler tek yerde"},
	{"Kolayca ulaş", "Adres, telefon ve mesaj tek dokunuşta"},
	{"Randevu al", "Uygun saati seç, sıra bekleme"},
}

// GET /isletme-kesif?kategori=
//
// ⚠️ TEK UC, IKI VERI: alt kategoriler + slider metinleri. Ayri iki uc
//
//	acmak, ekran acilisinda IKI istek demekti (turu 91 performans dersi:
//	acilistaki es zamanli istek sayisi olculebilir bir maliyet).
func (h *Handler) Kesif(w http.ResponseWriter, r *http.Request) {
	kat := strings.TrimSpace(r.URL.Query().Get("kategori"))

	alt := altKategoriler[kat]
	if alt == nil {
		alt = []AltKategori{}
	}
	slayt := kategoriSlider[kat]
	if len(slayt) == 0 {
		slayt = sliderVarsayilan
	}
	yaz(w, 200, map[string]any{
		"alt_kategoriler": alt,
		"slaytlar":        slayt,
		"kategori_ad":     KategoriAdi(kat),
	})
}

// KategoriAdi — anahtardan gorunen ad. Bilinmeyen anahtar bos dize doner
// (cagiran taraf "İşletmeler" gibi genel bir baslik secebilsin).
func KategoriAdi(k string) string {
	if k == "" {
		return ""
	}
	return Kategoriler[k]
}
