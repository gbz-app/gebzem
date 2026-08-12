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
// ⚠️⚠️ TURU 95 — HIZLI KESIF KARTLARI (kullanici emri: *"oraya yeni kartlar
//	olsun, mesela Indirim, Gece Kusu gibi"*).
//
//	Bunlar 60x60 alt kategori kartlarindan FARKLIDIR: alt kategori bir
//	ARAMA metnine cevrilir (`q=döner`), bu kartlar ise SUNUCU TARAFI BIR
//	YUKLEM secer (`hizli=kampanyali`). Ikisini tek listede toplamak,
//	istemcinin "bu metin mi yoksa suzgec mi" diye ayirmasini gerektirirdi.
//
// ⚠️ HER KARTIN GERCEK BIR KARSILIGI VAR — dekoratif kart YOK. Bir kart
//
//	eklerken `Liste` icindeki yuklemi de yaz; yoksa dokunulunca HICBIR SEY
//	olmayan bir dugme kalir (bu projede DOKUZ kez sahaya cikti).
type HizliKart struct {
	Ad      string `json:"ad"`
	Anahtar string `json:"anahtar"`
}

// ⚠️ KATEGORIDEN BAGIMSIZ: uc kart da her kategoride anlamli (kampanya,
//
//	gec saat, su an acik). Kategoriye ozel kart gerekirse bu harita
//	`map[string][]HizliKart`a cevrilir; bugun oyle bir ihtiyac yok ve
//	17 kategori icin ayni ucluyu yazmak olu tekrar olurdu.
var hizliKartlar = []HizliKart{
	{"İndirim", "kampanyali"},
	{"Gece Kuşu", "gec_acik"},
	{"Şu an açık", "acik"},
}

type SliderKarti struct {
	Baslik  string `json:"baslik"`
	AltMetn string `json:"alt"`
}

var kategoriSlider = map[string][]SliderKarti{
	"yemek": {
		{"Ne yemek istersin?", "Çevrendeki mutfaklar bir dokunuş uzakta"},
		{"Acıktın mı?", "Yakınındaki açık restoranlar"},
		{"Kalabalık mısınız?", "Ailece oturulacak mekânlar"},
	},
	"kafe": {
		{"Kahve molası?", "Yakınındaki kafeler ve pastaneler"},
		{"Kahvaltı nerede?", "Serpme ve açık büfe seçenekleri"},
		{"Tatlı krizi mi?", "Waffle, pasta ve daha fazlası"},
	},
	"market": {
		{"Bir şey mi lazım?", "Semtindeki market ve bakkallar"},
		{"Taze mi arıyorsun?", "Manav, kasap ve şarküteriler"},
		{"Son dakika alışverişi", "En yakın açık marketler"},
	},
	"kuafor": {
		{"Saç zamanı mı?", "Çevrendeki kuaför ve berberler"},
		{"Yeni bir görünüm?", "Kesim, boya ve bakım"},
		{"Özel bir gün mü var?", "Gelin saçı ve makyaj"},
	},
	"guzellik": {
		{"Kendine vakit ayır", "Yakınındaki güzellik merkezleri"},
		{"Cildin nasıl?", "Bakım ve temizlik seçenekleri"},
		{"Randevu almak kolay", "Uygun saati seç, sıra bekleme"},
	},
	"saglik": {
		{"Bir doktora mı ihtiyacın var?", "Çevrendeki hekim ve klinikler"},
		{"Kontrol zamanı", "Diş, göz ve dahiliye"},
		{"Hızlı randevu", "Uygun saati seç, hemen al"},
	},
	"diyetisyen": {
		{"Hedefin ne?", "Sana uygun diyetisyenler"},
		{"Beslenme planı mı arıyorsun?", "Kişiye özel programlar"},
		{"Takipte kal", "Ölçüm ve öğün takibi tek yerde"},
	},
	"otel": {
		{"Nerede kalacaksın?", "Çevrendeki oteller ve apartlar"},
		{"Kaç gece?", "Uygun oda seçenekleri"},
		{"Erken rezervasyon", "Uygun saati seç, yerini ayır"},
	},
	"spor": {
		{"Harekete hazır mısın?", "Yakınındaki salon ve sahalar"},
		{"Hangi spor?", "Fitness, yüzme, dövüş ve daha fazlası"},
		{"Yalnız değilsin", "Grup dersleri ve takımlar"},
	},
	"oto": {
		{"Aracın bakımda mı?", "Çevrendeki servis ve ustalar"},
		{"Lastik mi değişecek?", "Yıkama, kaporta ve lastikçiler"},
		{"Hızlı çözüm", "Yakınındaki açık servisler"},
	},
	"egitim": {
		{"Ne öğrenmek istersin?", "Kurs ve özel ders seçenekleri"},
		{"Sınava mı hazırlanıyorsun?", "Dershane ve etüt merkezleri"},
		{"Yeni bir dil", "Yakınındaki dil kursları"},
	},
	"giyim": {
		{"Ne giyeceksin?", "Çevrendeki mağazalar"},
		{"Yeni sezon geldi", "Vitrini telefonundan gör"},
		{"Terzi mi lazım?", "Tadilat ve dikiş"},
	},
	"eczane": {
		{"Reçeten mi var?", "Yakınındaki eczaneler"},
		{"Cilt bakımı", "Dermokozmetik ürünler"},
		{"Aradığını sor", "Adres ve telefon tek dokunuşta"},
	},
	"emlak": {
		{"Yeni bir yer mi arıyorsun?", "Kiralık ve satılık seçenekler"},
		{"Semtini tanı", "Bölgendeki emlak ofisleri"},
		{"Acele etme", "Değerleme ve danışmanlık"},
	},
	"teknoloji": {
		{"Cihazın mı bozuldu?", "Telefon ve bilgisayar servisleri"},
		{"Aynı gün çözüm", "Yakınındaki ustalar"},
		{"Aksesuar lazım mı?", "Kılıf, şarj ve kulaklık"},
	},
	"eglence": {
		{"Bu akşam ne var?", "Çevrendeki mekânlar"},
		{"Arkadaşlarını topla", "Bilardo, oyun ve langırt"},
		{"Hafta sonu planı", "Yakınındaki seçenekler"},
	},
	"hizmet": {
		{"Bir usta mı lazım?", "Tesisat, boya ve nakliyat"},
		{"Semtinden çağır", "Yakınındaki ustalar"},
		{"Önce fiyat sor", "Mesajla teklif al"},
	},
	// ⚠️ `diger` BILEREK YOK: kategorisi belirsiz bir isletmeye ozel bir
	//    slider metni turetilemez; genel varsayilan ORASI ICIN dogrudur.
}
var sliderVarsayilan = []SliderKarti{
	{"Ne arıyorsun?", "Çevrendeki işletmeler tek yerde"},
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
		"hizli_kartlar":   hizliKartlar,
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
