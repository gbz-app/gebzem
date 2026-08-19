// Package ilan — ILANLAR + HIZMETLER (turu 77).
//
// Kullanici emri: "ilanlar olacak sahibinden gibi araba ev 2.el alim satim vs"
// + "hizmetler kategorisi olacak".
//
// ⚠️ HIZMET AYRI DIKEY DEGIL, bir `tur` degeridir (bkz. migration 030 serhi).
package ilan

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
)

// Bildirimci — is ilani BASVURUSU geldiginde ilan sahibine bildirim.
//
// TURU 90: arayuz `isletme`/`randevu` paketlerindekiyle AYNI imza; ayri bir
// bildirim yolu yazmak ikinci bir kopya olurdu.
type Bildirimci interface {
	Bildir(ctx context.Context, alici, aktor, tur, hedefTur, hedefID string)
}

type Handler struct {
	db *pgxpool.Pool
	bs Bildirimci
}

// NOT: `bs` NIL olabilir; cagiran yerlerde kapi ZORUNLU.
func NewHandler(db *pgxpool.Pool, bs Bildirimci) *Handler {
	return &Handler{db: db, bs: bs}
}

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, m string) {
	yaz(w, kod, map[string]string{"error": m})
}

func kisalt(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}

// ⚠️⚠️ KATEGORI AGACI — Go'da SABIT, DB tablosunda DEGIL.
//
//	Gerekce: kucuk, sabit ve nadiren degisen bir liste icin tablo + JOIN +
//	yonetim ekrani gereksiz karmasiklik. Istemci bu agaci `/ilan-kategoriler`
//	ucundan ALIR — Dart'ta ikinci bir kopya TUTULMAZ (turu 77 denetim
//	bulgusu: "kategori listesi Go + Dart iki kopya = itiraf edilmis drift").
//
// ⚠️ YAPMA: Dart'a bu agacin kopyasini yazma.
type Tur struct {
	Anahtar     string `json:"anahtar"`
	Ad          string `json:"ad"`
	Kategoriler []Kat  `json:"kategoriler"`
	// Bu turde arayuzun soracagi TIPE OZEL alanlar.
	Alanlar []Alan `json:"alanlar"`
}

type Kat struct {
	Anahtar string `json:"anahtar"`
	Ad      string `json:"ad"`
}

// Tipe ozel alan tanimi — istemci formu BUNDAN uretir.
// ⚠️ Boylece yeni bir alan eklemek icin ISTEMCI GUNCELLEMESI GEREKMEZ.
type Alan struct {
	Anahtar    string   `json:"anahtar"`
	Ad         string   `json:"ad"`
	Tip        string   `json:"tip"` // metin | sayi | secim | cok_secim | tarih
	Secenekler []string `json:"secenekler,omitempty"`
	Birim      string   `json:"birim,omitempty"`

	// ⚠️⚠️ TURU 91 — ADIM ADIM FORM (kullanici emri: *"burada STEP STEP...
	//    salon sececek, misafir sayisi, dis mekan mi"*).
	//
	//    `Adim` alani tanimin ICINDE tasinir; istemci alanlari `Adim`e gore
	//    GRUPLAYIP her adimi ayri ekran cizer. Sirayi istemciye YAZMAK,
	//    "alan sunucudan gelir ama SIRASI istemcide" gibi YARI-SUNUCU bir
	//    tasarim olurdu ve yeni alan eklemek yine istemci guncellemesi
	//    isterdi — turu 77'nin "Dart'a kategori/tur sabiti yazma" kuralinin
	//    ihlali.
	// ⚠️ `omitempty`: 0 = adimsiz (mevcut TUM turler DEGISMEDEN calisir).
	Adim int `json:"adim,omitempty"`

	// ⚠️⚠️⚠️ TURU 93b — ALAN **KATEGORIYE GORE** SUZULUR (denetim).
	//
	//	Onceden `talep` turunun alan listesi TEK ve 15 kategorinin HEPSINDE
	//	ayni ciziliyordu. "Temizlik" talebi acan kullaniciya sorulan sorular:
	//	*"Kişi sayısı"*, *"Mekân: Kapalı salon / KIR DÜĞÜNÜ / Otel"*,
	//	*"İhtiyacın olanlar: GELİNLİK, GELİN ARABASI, Saç & makyaj,
	//	Davetiye"*, *"Bütçe: 250.000 - 500.000 ₺"*. **"Diyet & Beslenme
	//	Programı"** talebinde de aynisi. Kullanicinin emri acikca IKI DALDI
	//	(*"düğün mü yapmak istiyorsun HIZMET mi almak istiyorsun"*);
	//	istemci dali ayiriyordu ama SORULAR ayrilmiyordu.
	//
	// ⚠️ BOS = HER KATEGORIDE gorunur (tarih, esneklik, butce, not gibi
	//    ortak alanlar). Yani mevcut TUM turler DEGISMEDEN calisir.
	// ⚠️ Suzme SUNUCUDA yapilir: istemciye "hangi alan hangi kategoride"
	//    kurali yazmak, turu 77'nin "Dart'a tur/kategori sabiti YAZMA"
	//    kuralinin ihlali olurdu ve yeni bir alan MAGAZA ONAYI gerektirirdi.
	Kategoriler []string `json:"-"`

	// ⚠️ Zorunlu alan istemcide "Devam" dugmesini kilitler. Sunucu tarafi
	//    DOGRULAMA YAPMAZ (talep alanlari serbest JSONB) — bu bir ARAYUZ
	//    kolayligidir, guvenlik kapisi DEGILDIR.
	Zorunlu bool `json:"zorunlu,omitempty"`
}

var Turler = []Tur{
	{
		Anahtar: "vasita", Ad: "Vasıta",
		Kategoriler: []Kat{
			{"otomobil", "Otomobil"}, {"suv", "Arazi & SUV"},
			{"motosiklet", "Motosiklet"}, {"ticari", "Ticari Araç"},
			{"kiralik_arac", "Kiralık Araç"}, {"vasita_diger", "Diğer"},
		},
		Alanlar: []Alan{
			{Anahtar: "marka", Ad: "Marka", Tip: "metin"},
			{Anahtar: "model", Ad: "Model", Tip: "metin"},
			{Anahtar: "yil", Ad: "Yıl", Tip: "sayi"},
			{Anahtar: "km", Ad: "Kilometre", Tip: "sayi", Birim: "km"},
			{Anahtar: "vites", Ad: "Vites", Tip: "secim",
				Secenekler: []string{"Manuel", "Otomatik", "Yarı otomatik"}},
			{Anahtar: "yakit", Ad: "Yakıt", Tip: "secim",
				Secenekler: []string{"Benzin", "Dizel", "LPG", "Hibrit", "Elektrik"}},
		},
	},
	{
		Anahtar: "emlak", Ad: "Emlak",
		Kategoriler: []Kat{
			{"satilik_daire", "Satılık Daire"}, {"kiralik_daire", "Kiralık Daire"},
			{"satilik_mustakil", "Satılık Müstakil"}, {"arsa", "Arsa"},
			{"isyeri", "İş Yeri"}, {"emlak_diger", "Diğer"},
		},
		Alanlar: []Alan{
			{Anahtar: "m2", Ad: "Metrekare", Tip: "sayi", Birim: "m²"},
			{Anahtar: "oda", Ad: "Oda sayısı", Tip: "secim",
				Secenekler: []string{"1+0", "1+1", "2+1", "3+1", "4+1", "5+ ve üzeri"}},
			{Anahtar: "kat", Ad: "Bulunduğu kat", Tip: "metin"},
			{Anahtar: "isitma", Ad: "Isıtma", Tip: "secim",
				Secenekler: []string{"Doğalgaz", "Merkezi", "Klima", "Soba", "Yok"}},
			{Anahtar: "esyali", Ad: "Eşyalı", Tip: "secim",
				Secenekler: []string{"Evet", "Hayır"}},
		},
	},
	{
		Anahtar: "ikinci_el", Ad: "İkinci El",
		Kategoriler: []Kat{
			{"elektronik", "Elektronik"}, {"ev_esyasi", "Ev Eşyası"},
			{"giyim", "Giyim & Aksesuar"}, {"bebek", "Anne & Bebek"},
			{"hobi", "Hobi & Oyun"}, {"spor_ekipman", "Spor"},
			{"ikinci_el_diger", "Diğer"},
		},
		Alanlar: []Alan{
			{Anahtar: "durum", Ad: "Ürün durumu", Tip: "secim",
				Secenekler: []string{"Sıfır", "Yeni gibi", "İyi", "Orta", "Yıpranmış"}},
			{Anahtar: "marka", Ad: "Marka", Tip: "metin"},
		},
	},
	{
		Anahtar: "hizmet", Ad: "Hizmet",
		Kategoriler: []Kat{
			{"tadilat", "Tadilat & Tamirat"}, {"nakliyat", "Nakliyat"},
			{"temizlik", "Temizlik"}, {"ozel_ders", "Özel Ders"},
			{"organizasyon", "Organizasyon"}, {"teknik_servis", "Teknik Servis"},
			{"hizmet_diger", "Diğer"},
		},
		Alanlar: []Alan{
			{Anahtar: "deneyim", Ad: "Deneyim (yıl)", Tip: "sayi"},
			{Anahtar: "bolge", Ad: "Hizmet bölgesi", Tip: "metin"},
		},
	},
	// ⚠️⚠️⚠️ TURU 90 — **IS ILANI** (kullanici emri: *"is ilani da olacak,
	//    HERKES verebilmeli, normal kullanicilar haricinde BASVURU
	//    YAPILABILMELI"*).
	//
	// ⚠️ MIGRATION GEREKMEDI: `ilanlar.tur` serbest TEXT (030'da CHECK YOK) ve
	//    tura ozel alanlar `ozellikler JSONB`e yazilir. 030'un kendi serhi:
	//    *"JSONB ile yeni tur SIFIR sema degisikligi"*.
	// ⚠️ "HERKES verebilmeli": `ilan.Olustur` ISLETME HESABI ISTEMEZ (yalnizca
	//    oturum) — yani bu istek EK BIR KAPI ACMADAN karsilaniyor.
	// ⚠️ `fiyat_kurus` is ilaninda MAAS anlamina gelir; istemci etiketi
	//    tura gore degistirir (0 = "belirtilmemiş").
	{
		Anahtar: "is", Ad: "İş İlanı",
		Kategoriler: []Kat{
			{"satis", "Satış & Pazarlama"}, {"garson", "Garson & Servis"},
			{"mutfak", "Mutfak & Aşçı"}, {"kasiyer", "Kasiyer"},
			{"guvenlik", "Güvenlik"}, {"temizlik_is", "Temizlik"},
			{"sofor", "Şoför & Kurye"}, {"ofis", "Ofis & Muhasebe"},
			{"saglik_is", "Sağlık"}, {"egitim_is", "Eğitim"},
			{"teknik", "Teknik & Usta"}, {"is_diger", "Diğer"},
		},
		Alanlar: []Alan{
			{Anahtar: "pozisyon", Ad: "Pozisyon", Tip: "metin"},
			{Anahtar: "calisma_sekli", Ad: "Çalışma şekli", Tip: "secim",
				Secenekler: []string{"Tam zamanlı", "Yarı zamanlı", "Stajyer", "Sözleşmeli", "Vardiyalı"}},
			{Anahtar: "deneyim_yil", Ad: "Deneyim", Tip: "sayi", Birim: "yıl"},
			{Anahtar: "egitim", Ad: "Eğitim", Tip: "secim",
				Secenekler: []string{"Fark etmez", "İlköğretim", "Lise", "Ön lisans", "Lisans"}},
		},
	},
	// ⚠️⚠️⚠️ TURU 91 — **TEKLIF ISTEGI** (kullanici emri: *"dugun mu yapmak
	//    istiyorsun hizmet mi almak istiyorsun, burada STEP STEP... sonra bu
	//    bilgiler ornegin kuafore teklif gidecek, digerlerine gidecek, onlar
	//    da KARSI TEKLIF verecekler"*). Armut deseni.
	//
	// ═══════════ YON: DIGER TURLERIN TERSI ═══════════
	//
	// Diger turlerde ilani SATICI acar, alici mesaj atar. Talepte ilani
	// ALICI acar ("dugun yapacagim") ve ISLETMELER teklif verir. Ayni tablo,
	// TERS YON — `ilan_basvurular` bu yonu ZATEN dogru modelliyor
	// (cok kisi -> tek ilan).
	//
	// ⚠️ MIGRATION GEREKMEDI: `ilanlar.tur` serbest TEXT, tura ozel alanlar
	//    `ozellikler JSONB`. Turu 90'daki `is` turu de tam boyle eklendi.
	// ⚠️ `fiyat_kurus` TALEPTE **BUTCE** anlamina gelir (0 = belirtilmemis);
	//    isletmenin verdigi teklif `ilan_basvurular.fiyat_kurus`tur. Ikisi
	//    AYRI sutunlardir — karistirilirsa musterinin butcesi teklif diye
	//    gorunurdu.
	// ⚠️ TALEP HERKESE ACIKTIR (migration 045 basindaki karar). Forma
	//    telefon/adres alani EKLEME.
	{
		Anahtar: "talep", Ad: "Teklif İsteği",
		Kategoriler: []Kat{
			// Dugun dali (alan suzgeci icin `dugunKategorileri` sabiti)
			{"dugun_organizasyon", "Düğün Organizasyonu"},
			{"dugun_mekan", "Düğün Salonu & Mekân"},
			{"dugun_fotograf", "Düğün Fotoğrafçısı"},
			{"gelinlik", "Gelinlik & Damatlık"},
			{"sac_makyaj", "Saç & Makyaj"},
			{"dugun_muzik", "Müzik & Orkestra"},
			{"dugun_pasta", "Pasta & İkram"},
			{"davetiye", "Davetiye & Nikâh Şekeri"},
			{"gelin_arabasi", "Gelin Arabası"},
			// Hizmet dali
			{"tadilat_talep", "Tadilat & Tamirat"},
			{"nakliyat_talep", "Nakliyat"},
			{"temizlik_talep", "Temizlik"},
			{"ozel_ders_talep", "Özel Ders"},
			{"diyet_program", "Diyet & Beslenme Programı"},
			{"talep_diger", "Diğer"},
		},
		// ⚠️ ADIMLAR: 1) ne zaman  2) olcek  3) yer/tercih  4) butce+not
		//    Her adim TEK EKRAN. Alan sayisi adim basina 1-3 tutuldu —
		//    daha fazlasi "adim adim" hissini bozar ve kucuk telefonda
		//    klavye acikken tasar.
		Alanlar: []Alan{
			{Anahtar: "tarih", Ad: "Ne zaman?", Tip: "tarih", Adim: 1,
				Zorunlu: true},
			{Anahtar: "esneklik", Ad: "Tarih esnek mi?", Tip: "secim", Adim: 1,
				Secenekler: []string{"Kesin tarih", "Birkaç gün esnek",
					"Ay içinde herhangi bir gün", "Henüz belirsiz"}},

			// ── DUGUN DALI ──────────────────────────────────────────────
			{Anahtar: "kisi_sayisi", Ad: "Kişi sayısı", Tip: "sayi", Adim: 2,
				Birim: "kişi", Kategoriler: dugunKategorileri},
			{Anahtar: "mekan_tipi", Ad: "Mekân", Tip: "secim", Adim: 2,
				Secenekler: []string{"Kapalı salon", "Dış mekân / bahçe",
					"Kır düğünü", "Otel", "Fark etmez"},
				Kategoriler: dugunKategorileri},

			{Anahtar: "hizmetler", Ad: "İhtiyacın olanlar", Tip: "cok_secim",
				Adim: 3,
				Secenekler: []string{"Organizasyon", "Mekân", "Fotoğraf & video",
					"Saç & makyaj", "Gelinlik", "Müzik", "Pasta & ikram",
					"Davetiye", "Gelin arabası", "Diğer"},
				Kategoriler: dugunKategorileri},

			// ── HIZMET DALI ─────────────────────────────────────────────
			// ⚠️ Bu alanlar dugun dalinda CIZILMEZ: "kaç oda / kaç m²"
			//    sorusu bir dugun talebinde anlamsizdir.
			{Anahtar: "yer_tipi", Ad: "Nerede?", Tip: "secim", Adim: 2,
				Secenekler: []string{"Ev", "İş yeri", "Ofis", "Fark etmez"},
				Kategoriler: []string{"tadilat_talep", "nakliyat_talep",
					"temizlik_talep"}},
			{Anahtar: "metrekare", Ad: "Yaklaşık büyüklük", Tip: "sayi",
				Adim: 2, Birim: "m²",
				Kategoriler: []string{"tadilat_talep", "temizlik_talep"}},
			{Anahtar: "oda_sayisi", Ad: "Oda sayısı", Tip: "secim", Adim: 2,
				Secenekler: []string{"1+0", "1+1", "2+1", "3+1", "4+1",
					"5+1 ve üzeri"},
				Kategoriler: []string{"tadilat_talep", "nakliyat_talep",
					"temizlik_talep"}},
			{Anahtar: "kat", Ad: "Bulunduğu kat", Tip: "secim", Adim: 3,
				Secenekler: []string{"Zemin", "1-3", "4-6", "7 ve üzeri",
					"Asansör var"},
				Kategoriler: []string{"nakliyat_talep", "tadilat_talep"}},
			{Anahtar: "is_kapsami", Ad: "Neye ihtiyacın var?", Tip: "cok_secim",
				Adim: 3,
				Secenekler: []string{"Boya & badana", "Tesisat", "Elektrik",
					"Zemin & parke", "Mutfak / banyo", "Alçı & tavan",
					"Kapı & pencere", "Diğer"},
				Kategoriler: []string{"tadilat_talep"}},
			{Anahtar: "temizlik_kapsami", Ad: "Ne tür temizlik?",
				Tip: "cok_secim", Adim: 3,
				Secenekler: []string{"Genel temizlik", "İnşaat sonrası",
					"Cam temizliği", "Koltuk & halı yıkama", "Düzenli (haftalık)"},
				Kategoriler: []string{"temizlik_talep"}},

			// ── OZEL DERS ───────────────────────────────────────────────
			{Anahtar: "ders_konusu", Ad: "Hangi konu?", Tip: "metin", Adim: 2,
				Kategoriler: []string{"ozel_ders_talep"}},
			{Anahtar: "seviye", Ad: "Seviye", Tip: "secim", Adim: 2,
				Secenekler: []string{"İlkokul", "Ortaokul", "Lise", "Üniversite",
					"Yetişkin / hobi"},
				Kategoriler: []string{"ozel_ders_talep"}},
			{Anahtar: "ders_bicimi", Ad: "Nasıl olsun?", Tip: "secim", Adim: 3,
				Secenekler: []string{"Yüz yüze", "Online", "Fark etmez"},
				Kategoriler: []string{"ozel_ders_talep"}},

			// ── DIYET ───────────────────────────────────────────────────
			// ⚠️ KILO/BOY SORULMUYOR: bu SAGLIK VERISIDIR ve talep
			//    **HERKESE ACIKTIR** (`ilanlar` genel listede gorunur).
			//    Hedefi sormak yeterli; olcumler diyetisyenle BAG kurulunca
			//    `diyet_kayit`ta RIZAYLA tutulur.
			{Anahtar: "diyet_hedef", Ad: "Hedefin ne?", Tip: "secim", Adim: 2,
				Secenekler: []string{"Kilo vermek", "Kilo almak",
					"Sporcu beslenmesi", "Sağlıklı beslenme", "Hastalık kaynaklı"},
				Kategoriler: []string{"diyet_program"}},
			{Anahtar: "diyet_bicimi", Ad: "Görüşme şekli", Tip: "secim",
				Adim: 3,
				Secenekler: []string{"Yüz yüze", "Online", "Fark etmez"},
				Kategoriler: []string{"diyet_program"}},

			// ── ORTAK (kategori BOS = hepsinde) ─────────────────────────
			{Anahtar: "butce_araligi", Ad: "Bütçe aralığı", Tip: "secim",
				Adim: 4,
				Secenekler: []string{"Belirtmek istemiyorum", "50.000 ₺ altı",
					"50.000 - 100.000 ₺", "100.000 - 250.000 ₺",
					"250.000 - 500.000 ₺", "500.000 ₺ üzeri"}},
		},
	},
}

// ⚠️⚠️ TURU 93b — DUGUN DALININ KATEGORILERI (alan suzgeci icin TEK KAYNAK).
//
//	`Turler` icindeki "talep" kategorileri IKI DALDIR: dugun ve hizmet.
//	Kisi sayisi / mekan tipi / "İhtiyacın olanlar" YALNIZ dugun dalinda
//	sorulmali; aksi halde "Temizlik" talebi acan kullaniciya **Gelinlik**
//	ve **Gelin arabası** soruluyordu.
//
// ⚠️ SABIT LISTE, "dugun_" ONEKI DEGIL: `gelinlik`, `sac_makyaj`,
//
//	`davetiye`, `gelin_arabasi` dugun dalindadir ama o oneki TASIMAZ.
//	Onek kontrolu bu dordunu SESSIZCE hizmet dalina dusururdu.
//
// ⚠️ Yeni bir DUGUN kategorisi eklerken bu listeye de ekle; muhafiz
//
//	(`talep_test.go`) kapsamayi zorluyor.
var dugunKategorileri = []string{
	"dugun_organizasyon", "dugun_mekan", "dugun_fotograf", "gelinlik",
	"sac_makyaj", "dugun_muzik", "dugun_pasta", "davetiye", "gelin_arabasi",
}

// TalepTuru — bu tur bir TEKLIF ISTEGI mi?
//
// ⚠️ TEK KAYNAK: "talep" dizesi kod tabaninda BES yerde kontrol ediliyor
//
//	(liste suzgeci · basvuru kapisi · isletme kapisi · fiyat zorunlulugu ·
//	bildirim fan-out). Elle karsilastirma yazmak, birini guncelleyip
//	otekini unutma sinifini acardi (bu projede DORT kez sahaya cikti).
func TalepTuru(t string) bool { return t == "talep" }

// TalepPenceresi — bir talep KAC SURE acik kalir.
//
// ⚠️⚠️ OKUMA **VE** YAZMA yollari AYNI sabiti kullanir. Turu 80b'de
//
//	`ileri_gun` IKI FARKLI TABANDA olculmus ve arayuzun GOSTERDIGI slot
//	POST'ta 400 donmustu ("arayuzun kurala uymasi, kuralin UYGULANDIGI
//	anlamina gelmez"). Ayni hatayi tekrarlamamak icin sabit disari alindi.
//
// ⚠️ Talep SILINMEZ, yalnizca GORUNMEZ olur (veri politikasi).
const TalepPenceresi = 7 * 24 * time.Hour

func turGecerli(t string) bool {
	for _, x := range Turler {
		if x.Anahtar == t {
			return true
		}
	}
	return false
}

// ⚠️⚠️ SUTUN LISTESI TEK KAYNAK — `satirlariOku` ile BIREBIR ayni sirada.
//
//	Turu 76'da alti sorguya sutun eklenip yedincisi atlanmisti; `rows.Scan`
//	sessizce hata verip HER SATIRI ATLIYORDU ve sayfa BOMBOS donuyordu.
//
// ⚠️ YAPMA: sutunlari sorgulara elle kopyalama.
const sutunlar = `
		i.id, i.sahibi_id, u.name, COALESCE(u.username,''), u.avatar_media_id,
		COALESCE(u.hesap_turu, 'kisisel'), u.onayli,
		i.tur, i.kategori, i.baslik, i.aciklama,
		i.fiyat_kurus, i.para_birimi, i.fiyat_gizli,
		i.il, i.ilce, i.media_ids, i.ozellikler, i.durum,
		i.goruntulenme, i.created_at,
		` + medyaTurleri + `
		i.duzenlendi_at,
		EXISTS(SELECT 1 FROM ilan_favoriler f
		        WHERE f.ilan_id=i.id AND f.user_id=$1)`

// ⚠️⚠️ TURU 78 — MEDYA TURLERI (foto/video karma galeri).
//
//	`media_ids` yalnizca UUID dizisi; hangi medyanin FOTO hangisinin VIDEO
//	oldugu istemciye HIC donmuyordu. Istemci bir video id'sini goruntu
//	bilesenine verirse KIRIK GORSEL cizer (kanal gonderilerinde turu 76b'ye
//	kadar tam bu sorun vardi).
//
// ⚠️ `unnest(...) WITH ORDINALITY` + `array_agg(... ORDER BY idx)` SIRA KORUR:
//
//	`media_kinds[i]` ile `media_ids[i]` AYNI medyayi gosterir. Duz bir JOIN
//	kullanilsaydi sira GARANTI OLMAZDI ve galeri yanlis tip cizerdi.
//
// ⚠️⚠️ SILINMIS medya icin 'yok' doner (NULL DEGIL): `array_agg` NULL eleman
//
//	uretirse `[]string`e tarama PATLAR ve satir SESSIZCE ATLANIR — liste
//	bombos gorunur, log da dusmez.
//
// ⚠️ DIS `COALESCE('{}')` ZORUNLU: `media_ids` bossa `array_agg` NULL doner.
const medyaTurleri = `
		COALESCE((SELECT array_agg(COALESCE(ma.kind,'yok') ORDER BY mm.idx)
		            FROM unnest(i.media_ids) WITH ORDINALITY AS mm(mid, idx)
		            LEFT JOIN media_assets ma ON ma.id = mm.mid), '{}'),`

// ⚠️ ENGEL YUKLEMI TEK KAYNAK. $1 = OKUYAN; tablo takma adi i.
const engelYok = `
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=i.sahibi_id)
		            OR (b.blocker_id=i.sahibi_id AND b.blocked_id=$1))`

func (h *Handler) satirlariOku(rows pgx.Rows) []map[string]any {
	out := []map[string]any{}
	for rows.Next() {
		var id, sahibi, ad, kullanici, tur, kategori, baslik, aciklama string
		var paraBirimi, il, ilce, durum string
		// ⚠️ TURU 114 — ilan kartinda SAHIBI KIMLIGI gosteriliyor (kullanici
		//    emri: "ilanda ... isletme/kisi kart bilgileri olsun").
		var hesapTuru string
		var sahibiOnayli bool
		var avatar *string
		var ozellikler []byte
		var medya, medyaKind []string
		var fiyat int64
		var goruntulenme int
		var fiyatGizli, favori bool
		var t time.Time
		var duzenlendi *time.Time
		// ⚠️ SCAN SIRASI `sutunlar` ILE BIREBIR. Uyusmazlik derleme hatasi
		//    VERMEZ; satir SESSIZCE atlanir ve liste BOMBOS doner.
		//    Bu hizalama `sutun_test.go` ile OTOMATIK dogrulanir.
		if rows.Scan(&id, &sahibi, &ad, &kullanici, &avatar,
			&hesapTuru, &sahibiOnayli,
			&tur, &kategori, &baslik, &aciklama,
			&fiyat, &paraBirimi, &fiyatGizli,
			&il, &ilce, &medya, &ozellikler, &durum,
			&goruntulenme, &t, &medyaKind, &duzenlendi, &favori) != nil {
			continue
		}
		if len(ozellikler) == 0 {
			ozellikler = []byte("{}")
		}
		out = append(out, map[string]any{
			"id": id, "sahibi_id": sahibi, "sahibi_ad": ad,
			"sahibi_username": kullanici, "sahibi_avatar_media_id": avatar,
			// ⚠️ UCU BIRLIKTE: SELECT + Scan + yanit haritasi. Biri atlanirsa
			//    alan istemciye HIC ULASMAZ (turu 78 `Profile()` dersi).
			"sahibi_hesap_turu": hesapTuru, "sahibi_onayli": sahibiOnayli,
			"tur": tur, "kategori": kategori,
			"baslik": baslik, "aciklama": aciklama,
			"fiyat_kurus": fiyat, "para_birimi": paraBirimi,
			"fiyat_gizli": fiyatGizli,
			"il":          il, "ilce": ilce, "media_ids": medya,
			// ⚠️ `media_kinds[i]` <-> `media_ids[i]` SIRA GARANTILI (bkz. medyaTurleri).
			"media_kinds": medyaKind,
			"ozellikler":  json.RawMessage(ozellikler),
			"durum":       durum, "goruntulenme": goruntulenme,
			"created_at": t, "favorim": favori,
			// ⚠️ NULL = hic duzenlenmedi. Istemci bunu "Düzenlendi" etiketi
			//    olarak cizer — alici guveni icin (bkz. migration 034 serhi).
			"duzenlendi_at": duzenlendi,
		})
	}
	return out
}

type ilanReq struct {
	Tur        string          `json:"tur"`
	Kategori   string          `json:"kategori"`
	Baslik     string          `json:"baslik"`
	Aciklama   string          `json:"aciklama"`
	FiyatKurus int64           `json:"fiyat_kurus"`
	FiyatGizli bool            `json:"fiyat_gizli"`
	Il         string          `json:"il"`
	Ilce       string          `json:"ilce"`
	MediaIDs   []string        `json:"media_ids"`
	Ozellikler json.RawMessage `json:"ozellikler"`
}

// POST /ilanlar
func (h *Handler) Olustur(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req ilanReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if !turGecerli(req.Tur) {
		req.Tur = "ikinci_el"
	}
	req.Baslik = kisalt(strings.TrimSpace(req.Baslik), 140)
	if req.Baslik == "" {
		hata(w, 400, "başlık boş olamaz")
		return
	}
	req.Aciklama = kisalt(strings.TrimSpace(req.Aciklama), 6000)
	if req.FiyatKurus < 0 {
		req.FiyatKurus = 0
	}
	// ⚠️⚠️ nil DEGIL BOS DILIM (turu 75b sevk engeli).
	if req.MediaIDs == nil {
		req.MediaIDs = []string{}
	}
	if len(req.MediaIDs) > 12 {
		req.MediaIDs = req.MediaIDs[:12]
	}
	if len(req.MediaIDs) > 0 {
		tag, err := h.db.Exec(r.Context(), `
			SELECT 1 FROM media_assets
			 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
			req.MediaIDs, me)
		if err != nil || int(tag.RowsAffected()) != len(req.MediaIDs) {
			hata(w, 403, "geçersiz medya")
			return
		}
	}
	// ⚠️ `ozellikler` bicimi DOGRULANIR (NESNE olmali, dizi/skaler DEGIL);
	//    bozuksa '{}' yazilir. NULL yazilsaydi istemcide her okumada null
	//    kontrolu gerekir ve bir yerde unutulup CRASH ederdi.
	// ⚠️⚠️ **BAYT** SINIRI DA ZORUNLU (turu 77b denetim bulgusu).
	//    `len(deneme)` ANAHTAR SAYISIDIR, bayt DEGIL: `{"a":"<50 MB metin>"}`
	//    tek anahtardir ve eski kapidan GECIP JSONB'ye aynen yazilirdi.
	//    ⚠️ YAPMA: yalniz anahtar sayisina guvenme.
	ozellikler := []byte("{}")
	if len(req.Ozellikler) > 0 && len(req.Ozellikler) <= 8<<10 {
		var deneme map[string]any
		if json.Unmarshal(req.Ozellikler, &deneme) == nil && len(deneme) <= 30 {
			ozellikler = req.Ozellikler
		}
	}

	var id string
	if h.db.QueryRow(r.Context(), `
		INSERT INTO ilanlar
		  (sahibi_id, tur, kategori, baslik, aciklama, fiyat_kurus, fiyat_gizli,
		   il, ilce, media_ids, ozellikler)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id`,
		me, req.Tur, kisalt(req.Kategori, 60), req.Baslik, req.Aciklama,
		req.FiyatKurus, req.FiyatGizli, kisalt(req.Il, 60), kisalt(req.Ilce, 60),
		req.MediaIDs, ozellikler).Scan(&id) != nil {
		hata(w, 500, "ilan oluşturulamadı")
		return
	}
	if len(req.MediaIDs) > 0 {
		h.db.Exec(r.Context(),
			`UPDATE media_assets SET status='bagli' WHERE id = ANY($1)`, req.MediaIDs)
	}
	// ⚠️⚠️ TURU 91 — TALEP ACILINCA ILGILI ISLETMELERE BILDIRIM.
	//    Bu satir olmasaydi ozellik yarim kalirdi: talep acilir, listede
	//    durur, ama HICBIR ISLETME ondan HABERDAR OLMAZDI — kullanici
	//    "kimse teklif vermiyor" derdi ve sebebini bulmak imkansiz olurdu.
	// ⚠️ Hata YUTULUR (icinde log var): bildirim gonderilemedi diye ilan
	//    olusturma basarisiz sayilmaz.
	if TalepTuru(req.Tur) {
		h.talepBildir(r.Context(), id, req.Kategori, req.Il, me)
	}
	yaz(w, 201, map[string]any{"id": id})
}

// GET /ilanlar?tur=&kategori=&il=&ilce=&q=&min=&max=&benim=1&favori=1
func (h *Handler) Liste(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	q := r.URL.Query()
	tur := strings.TrimSpace(q.Get("tur"))
	kategori := strings.TrimSpace(q.Get("kategori"))
	il := strings.TrimSpace(q.Get("il"))
	ilce := strings.TrimSpace(q.Get("ilce"))
	ara := strings.TrimSpace(q.Get("q"))
	min, _ := strconv.ParseInt(q.Get("min"), 10, 64)
	maks, _ := strconv.ParseInt(q.Get("maks"), 10, 64)
	if maks <= 0 {
		maks = 1 << 62 // ust sinir yok
	}

	ekKosul := ""
	switch {
	case q.Get("benim") == "1":
		// ⚠️ "Ilanlarim"da SATILAN ve KALDIRILAN da gorunur — sahibi kendi
		//    gecmisini gormeli (veri politikasi: silinmiyor).
		ekKosul = ` AND i.sahibi_id = $1 AND i.durum <> 'x'`
	case q.Get("favori") == "1":
		ekKosul = ` AND EXISTS(SELECT 1 FROM ilan_favoriler f2
		              WHERE f2.ilan_id=i.id AND f2.user_id=$1)`
	}
	durumKosulu := " AND i.durum='yayinda'"
	benim := q.Get("benim") == "1"
	if benim {
		durumKosulu = "" // kendi ilanlarinda tum durumlar
	}

	// ⚠️⚠️⚠️ TURU 91 — TALEP SIZINTI KAPISI.
	//
	// Talepler `ilanlar` tablosunda yasiyor; hicbir sey yapilmasaydi
	// "Sahibinden 2019 Ford Focus" ile "Düğün yapacağım, teklif bekliyorum"
	// AYNI LISTEDE yan yana cikardi. Kullanicinin gordugu ilk ekran
	// (hamburger > Ilanlar) ANINDA bozulurdu ve bu, ozelligin kendisinden
	// ONCE fark edilirdi.
	//
	// ⚠️ Kapi `tur` BOSKEN uygulanir: `?tur=talep` diyen ACIKCA talep
	//    istiyordur, `?tur=vasita` zaten suzuyor.
	// ⚠️ `benim=1` MUAF: kullanici "Taleplerim"i gorebilmeli.
	// ⚠️ 7 GUNLUK PENCERE de burada; sabit `TalepPenceresi` — YAZMA yolu
	//    (teklif verme) AYNI sabiti kullanir. Turu 80b'de `ileri_gun` iki
	//    farkli tabanda olculunce arayuz "musait" gosterip POST 400
	//    donmustu; ayni hatayi tekrarlamamak icin tek kaynak.
	talepKosulu := ""
	if tur == "" && !benim {
		talepKosulu = " AND i.tur <> 'talep'"
	} else if TalepTuru(tur) && !benim {
		talepKosulu = fmt.Sprintf(
			" AND i.created_at > now() - interval '%d hours'",
			int(TalepPenceresi.Hours()))
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT `+sutunlar+`
		  FROM ilanlar i JOIN users u ON u.id = i.sahibi_id
		 WHERE TRUE`+durumKosulu+`
		   AND ($2 = '' OR i.tur = $2)
		   AND ($3 = '' OR i.kategori = $3)
		   AND ($4 = '' OR i.il ILIKE $4)
		   AND ($5 = '' OR i.ilce ILIKE $5)
		   AND ($6 = '' OR i.baslik ILIKE '%'||$6||'%'
		        OR i.aciklama ILIKE '%'||$6||'%')
		   AND (i.fiyat_gizli OR (i.fiyat_kurus >= $7 AND i.fiyat_kurus <= $8))
		`+talepKosulu+ekKosul+engelYok+`
		 ORDER BY i.created_at DESC LIMIT 60`,
		me, tur, kategori, il, ilce, ara, min, maks)
	if err != nil {
		log.Printf("ilan liste: %v", err)
		hata(w, 500, "ilanlar alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"ilanlar": h.satirlariOku(rows)})
}

// GET /ilanlar/{id}
func (h *Handler) Detay(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT `+sutunlar+`
		  FROM ilanlar i JOIN users u ON u.id = i.sahibi_id
		 WHERE i.id=$2
		   AND (i.durum <> 'kaldirildi' OR i.sahibi_id=$1)`+engelYok, me, id)
	if err != nil {
		hata(w, 500, "ilan alınamadı")
		return
	}
	defer rows.Close()
	l := h.satirlariOku(rows)
	if len(l) == 0 {
		hata(w, 404, "ilan bulunamadı")
		return
	}
	// ⚠️ GORUNTULENME detayda artar (liste sayfasinda DEGIL — orada 60 ilan
	//    tek istekte gelir ama cogu HIC gorulmez; orada saymak sayiyi YALAN
	//    yapardi. Gonderi tarafiyla AYNI karar).
	h.db.Exec(r.Context(),
		`UPDATE ilanlar SET goruntulenme = goruntulenme + 1 WHERE id=$1`, id)
	yaz(w, 200, l[0])
}

// PATCH /ilanlar/{id} — durum degistir (satildi / yayinda / kaldirildi) veya
// baslik/aciklama/fiyat guncelle.
func (h *Handler) Guncelle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Durum      *string `json:"durum"`
		Baslik     *string `json:"baslik"`
		Aciklama   *string `json:"aciklama"`
		FiyatKurus *int64  `json:"fiyat_kurus"`
		// ⚠️⚠️ TURU 78 — TAM DUZENLEME. Onceden bu dort alan disindaki hicbir
		//    sey guncellenemiyordu: yanlis kategori secen ya da yanlis fotograf
		//    yukleyen kullanicinin TEK CARESI ilani kaldirip yeniden vermekti
		//    (goruntulenme ve favoriler de silinirdi).
		// ⚠️ `Tur` BILINCLI OLARAK DISARIDA: tur degisirse `ozellikler` semasi
		//    tamamen degisir (vasitanin "vites"i emlakta anlamsizdir) ve
		//    kategori de gecersizlesir. Tur degistirmek YENI ILAN demektir.
		FiyatGizli *bool            `json:"fiyat_gizli"`
		Kategori   *string          `json:"kategori"`
		Il         *string          `json:"il"`
		Ilce       *string          `json:"ilce"`
		MediaIDs   *[]string        `json:"media_ids"`
		Ozellikler *json.RawMessage `json:"ozellikler"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if req.Durum != nil {
		switch *req.Durum {
		case "yayinda", "satildi", "kaldirildi":
		default:
			hata(w, 400, "geçersiz durum")
			return
		}
	}
	// ⚠️⚠️ `Olustur`DAKI DOGRULAMALARIN AYNISI (turu 77b denetim bulgusu).
	//    PATCH yolu kirpmayi yapiyordu ama (a) BOS basligi reddetmiyor,
	//    (b) NEGATIF fiyati hic kontrol etmiyordu -> `{"fiyat_kurus":-500000}`
	//    ile eksi fiyatli ilan yayinlanabiliyordu. Ayni kuralin iki kopyasi
	//    yine drift etmisti (CLAUDE.md turu 72b/H).
	if req.Baslik != nil {
		*req.Baslik = kisalt(strings.TrimSpace(*req.Baslik), 140)
		if *req.Baslik == "" {
			hata(w, 400, "başlık boş olamaz")
			return
		}
	}
	if req.Aciklama != nil {
		*req.Aciklama = kisalt(strings.TrimSpace(*req.Aciklama), 6000)
	}
	if req.FiyatKurus != nil && *req.FiyatKurus < 0 {
		*req.FiyatKurus = 0
	}
	if req.Kategori != nil {
		*req.Kategori = kisalt(strings.TrimSpace(*req.Kategori), 60)
	}
	if req.Il != nil {
		*req.Il = kisalt(strings.TrimSpace(*req.Il), 60)
	}
	if req.Ilce != nil {
		*req.Ilce = kisalt(strings.TrimSpace(*req.Ilce), 60)
	}

	// ⚠️ `ozellikler` — `Olustur`daki KAPININ AYNISI. Bicim NESNE olmali,
	//    anahtar sayisi <= 30 VE **BAYT** boyutu <= 8 KB (turu 77b: `len(map)`
	//    anahtar sayisidir, `{"a":"<50 MB>"}` tek anahtardir ve gecerdi).
	var ozellikler *[]byte
	if req.Ozellikler != nil {
		ham := []byte("{}")
		if len(*req.Ozellikler) > 0 && len(*req.Ozellikler) <= 8<<10 {
			var deneme map[string]any
			if json.Unmarshal(*req.Ozellikler, &deneme) == nil && len(deneme) <= 30 {
				ham = *req.Ozellikler
			}
		}
		ozellikler = &ham
	}

	// ⚠️⚠️ MEDYA SAHIPLIGI PATCH'TE DE DOGRULANIR. Bu kapi olmasaydi baskasinin
	//    medya id'sini kendi ilanina baglayarak `erisebilir()` (g) dalini
	//    somurmek mumkun olurdu (ilan medyasi herkese acik).
	if req.MediaIDs != nil {
		if *req.MediaIDs == nil {
			// ⚠️ nil dilim pgx'te SQL NULL gonderir; `media_ids` NOT NULL ->
			//    500. Bos dilim ZORUNLU (turu 75b sevk engeli).
			*req.MediaIDs = []string{}
		}
		if len(*req.MediaIDs) > 12 {
			*req.MediaIDs = (*req.MediaIDs)[:12]
		}
		if len(*req.MediaIDs) > 0 {
			tag, err := h.db.Exec(r.Context(), `
				SELECT 1 FROM media_assets
				 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
				*req.MediaIDs, me)
			if err != nil || int(tag.RowsAffected()) != len(*req.MediaIDs) {
				hata(w, 403, "geçersiz medya")
				return
			}
		}
	}

	// ⚠️⚠️ `duzenlendi_at` YALNIZ ICERIK degisince yazilir — `durum` degisimi
	//    (satildi/kaldirildi) DUZENLEME SAYILMAZ. Aksi halde "Satıldı"ya basan
	//    her kullanicinin ilani "Düzenlendi" damgasi yer ve etiket ANLAMINI
	//    YITIRIRDI (alici guveni icin konmustu).
	icerikDegisti := req.Baslik != nil || req.Aciklama != nil ||
		req.FiyatKurus != nil || req.FiyatGizli != nil || req.Kategori != nil ||
		req.Il != nil || req.Ilce != nil || req.MediaIDs != nil ||
		req.Ozellikler != nil

	tag, err := h.db.Exec(r.Context(), `
		UPDATE ilanlar SET
		  durum       = COALESCE($3, durum),
		  baslik      = COALESCE($4, baslik),
		  aciklama    = COALESCE($5, aciklama),
		  fiyat_kurus = COALESCE($6, fiyat_kurus),
		  fiyat_gizli = COALESCE($7, fiyat_gizli),
		  kategori    = COALESCE($8, kategori),
		  il          = COALESCE($9, il),
		  ilce        = COALESCE($10, ilce),
		  media_ids   = COALESCE($11, media_ids),
		  ozellikler  = COALESCE($12::jsonb, ozellikler),
		  duzenlendi_at = CASE WHEN $13 THEN now() ELSE duzenlendi_at END,
		  updated_at  = now()
		 WHERE id=$1 AND sahibi_id=$2`,
		id, me, req.Durum, req.Baslik, req.Aciklama, req.FiyatKurus,
		req.FiyatGizli, req.Kategori, req.Il, req.Ilce, req.MediaIDs,
		ozellikler, icerikDegisti)
	if err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		// ⚠️ 404 (403 DEGIL): baskasinin ilaninin VAR OLDUGU bilgisi de bilgidir.
		hata(w, 404, "ilan bulunamadı")
		return
	}
	// ⚠️ Yeni eklenen medyalar 'bagli' yapilir (`Olustur` ile AYNI kural) —
	//    yoksa medya supurgesi 'aktif' kaydi bir sure sonra atilabilir sanip
	//    islem yapar ve ilan gorseli KAYBOLURDU.
	// ⚠️ CIKARILAN medya 'bagli' KALIR ve SILINMEZ — veri politikasi geregi.
	//    Kullanici fikrini degistirip geri eklerse dosya yerinde durur.
	//    Bedeli: kucuk bir depolama artisi (kabul edildi, 8 Agu karari).
	if req.MediaIDs != nil && len(*req.MediaIDs) > 0 {
		h.db.Exec(r.Context(),
			`UPDATE media_assets SET status='bagli' WHERE id = ANY($1)`, *req.MediaIDs)
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// POST /ilanlar/{id}/favori  ·  DELETE /ilanlar/{id}/favori
//
// ⚠️ Bu uclarin KARSILIGI OLAN EKRAN da ayni turda yazildi
// (`/ilanlar?favori=1` + "Favorilerim"). Bu projede `post_saves` yazilip
// listeleyen yol yazilmamisti (turu 75b "kara delik").
func (h *Handler) FavoriEkle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	// ⚠️⚠️ ILAN GORULEBILIR OLMALI (turu 77b denetim bulgusu). Eskiden duz
	//    INSERT vardi: (a) olmayan id'de FK ihlali **500** doner (dogrusu 404),
	//    (b) ENGELLENEN taraf da favoriye ekleyebiliyordu — okuyamadigi bir
	//    ilani favorileyip listesinde bos satir tasirdi.
	//    `INSERT ... SELECT ... WHERE EXISTS` ile ikisi de tek deyimde kapanir.
	// ⚠️⚠️ PARAMETRE SIRASI: `engelYok` sabiti **$1'i OKUYAN KULLANICI** kabul
	//    eder (dosyanin ustundeki serh). Bu yuzden burada $1=me, $2=ilan id.
	//    Ters yazilsaydi engel yuklemi ilan id'siyle karsilastirilir, HICBIR
	//    ZAMAN eslesmez ve kontrol SESSIZCE FAIL-OPEN olurdu.
	tag, err := h.db.Exec(r.Context(), `
		INSERT INTO ilan_favoriler (ilan_id, user_id)
		SELECT $2,$1 WHERE EXISTS(
		  SELECT 1 FROM ilanlar i
		   WHERE i.id=$2 AND i.durum <> 'kaldirildi'`+engelYok+`)
		ON CONFLICT DO NOTHING`, me, id)
	if err != nil {
		hata(w, 500, "eklenemedi")
		return
	}
	// ⚠️ `ON CONFLICT DO NOTHING` zaten favorideyse 0 satir doner — o da BASARIDIR.
	//    Bu yuzden 0 satiri "yok" saymak icin varligi AYRICA sormak gerekir.
	if tag.RowsAffected() == 0 {
		var v bool
		h.db.QueryRow(r.Context(),
			`SELECT EXISTS(SELECT 1 FROM ilan_favoriler WHERE ilan_id=$1 AND user_id=$2)`,
			id, me).Scan(&v)
		if !v {
			hata(w, 404, "ilan bulunamadı")
			return
		}
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

func (h *Handler) FavoriSil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	h.db.Exec(r.Context(),
		`DELETE FROM ilan_favoriler WHERE ilan_id=$1 AND user_id=$2`, id, me)
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /ilan-kategoriler — TUR + KATEGORI + TIPE OZEL ALAN AGACI.
//
// ⚠️⚠️ ISTEMCI BU AGACI SUNUCUDAN ALIR, kendi kopyasini TUTMAZ.
//
//	Turu 77 denetim bulgusu: "kategori listesi Go + Dart iki kopya" bu
//	projede itiraf edilmis bir drift bombasiydi. Ustelik `alanlar` dizisi
//	sayesinde ILAN VERME FORMU SUNUCUDAN URETILIYOR — yeni bir alan eklemek
//	icin istemci guncellemesi GEREKMIYOR.
func (h *Handler) Agac(w http.ResponseWriter, r *http.Request) {
	// ⚠️⚠️⚠️ TURU 93b — `?kategori=` VERILIRSE ALANLAR **SUZULUR**.
	//
	//	Kullanicinin emri iki daldi: *"düğün mü yapmak istiyorsun HIZMET mi
	//	almak istiyorsun"*. Istemci dali ayiriyordu ama SORULAR ayni kaliyor
	//	ve "Temizlik" talebi acana **Gelinlik / Gelin arabası / Kır düğünü**
	//	soruluyordu.
	//
	// ⚠️ GERIYE DONUK UYUMLU: `kategori` verilmezse TAM agac doner (ilan
	//    verme formu ve mevcut TUM turler DEGISMEDEN calisir).
	// ⚠️ Suzme SUNUCUDA: istemciye "hangi alan hangi kategoride" kurali
	//    yazmak turu 77'nin "Dart'a sabit YAZMA" kuralini ihlal ederdi.
	kat := strings.TrimSpace(r.URL.Query().Get("kategori"))
	if kat == "" {
		yaz(w, 200, map[string]any{"turler": Turler})
		return
	}
	suzulmus := make([]Tur, 0, len(Turler))
	for _, t := range Turler {
		alanlar := make([]Alan, 0, len(t.Alanlar))
		for _, a := range t.Alanlar {
			if alanGecerli(a, kat) {
				alanlar = append(alanlar, a)
			}
		}
		t.Alanlar = alanlar
		suzulmus = append(suzulmus, t)
	}
	yaz(w, 200, map[string]any{"turler": suzulmus})
}

// alanGecerli — alan bu kategoride cizilmeli mi?
//
// ⚠️ BOS `Kategoriler` = HER KATEGORIDE gorunur (tarih, butce, not gibi
//
//	ortak alanlar). Varsayilanin "hepsinde gorunur" olmasi ZORUNLU: aksi
//	halde mevcut turlerin TUM alanlari kategori suzgeciyle KAYBOLURDU.
func alanGecerli(a Alan, kategori string) bool {
	if len(a.Kategoriler) == 0 {
		return true
	}
	for _, k := range a.Kategoriler {
		if k == kategori {
			return true
		}
	}
	return false
}
