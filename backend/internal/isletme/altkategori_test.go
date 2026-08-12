package isletme

import (
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 92 — MUHAFIZ: ALT KATEGORI VE SLIDER HARITALARI TUTARLI MI?
//
// Kullanici emri: *"her kategori FARKLI dostum onu demek istedim"* — yani
// alt kategori kartlari ve slider metinleri KATEGORIYE OZEL olmali.
//
// ⚠️ DRIFT SESSIZDIR: `Kategoriler`e yeni bir kategori eklenip
//
//	`altKategoriler`e giris yazilmazsa, o kategoride serit HIC CIZILMEZ —
//	uc 200 doner, ekran acilir, kullanici yalnizca "burada kart yok" gorur
//	ve sebebini bilemez. Bu, projede DOKUZ kez yasanan "ozellik var
//	gorunup calismiyor" sinifinin bu turdaki bicimi.
//
// ⚠️ YAPMA: bu testi silme. Kategori eklerken `Kategoriler` + `moduller` +
//
//	`altKategoriler` UCUNU BIRLIKTE degerlendir (ilk ikisi icin ayri
//	muhafiz: `modul_test.go`).
func TestAltKategorilerKapsamli(t *testing.T) {
	// ⚠️ MUAFIYETLER **GEREKCESIYLE**: alt kategorisi anlamsiz olan
	//    kategoriler. Muaf olmak "serit cizilmez" demektir ve bu BILINCLI
	//    bir karardir.
	muaf := map[string]string{
		"diger": "kategorisi belirsiz — alt kategori turetilemez",
	}

	for anahtar, ad := range Kategoriler {
		liste, ok := altKategoriler[anahtar]
		if ok && len(liste) > 0 {
			continue
		}
		if gerekce, muafMi := muaf[anahtar]; muafMi {
			t.Logf("muaf: %s (%s) — %s", anahtar, ad, gerekce)
			continue
		}
		t.Errorf("KATEGORI %q (%s) icin ALT KATEGORI YOK.\n"+
			"  O kategoride 60x60 kart seridi HIC CIZILMEZ; uc 200 doner,\n"+
			"  ekran acilir ve kullanici sebebini bilemez.\n"+
			"  COZUM: altkategori.go icindeki `altKategoriler` haritasina\n"+
			"  giris ekle, ya da alt kategori GERCEKTEN anlamsizsa bu\n"+
			"  testteki `muaf` haritasina GEREKCESIYLE yaz.", anahtar, ad)
	}

	// Ters yon: haritada OLU giris var mi (yazim hatasi)?
	for anahtar := range altKategoriler {
		if _, ok := Kategoriler[anahtar]; !ok {
			t.Errorf("`altKategoriler` icinde %q girisi var ama boyle bir "+
				"ISLETME KATEGORISI YOK — bu giris HIC KULLANILMAZ.", anahtar)
		}
	}
	for anahtar := range kategoriSlider {
		if _, ok := Kategoriler[anahtar]; !ok {
			t.Errorf("`kategoriSlider` icinde %q girisi var ama boyle bir "+
				"ISLETME KATEGORISI YOK — bu giris HIC KULLANILMAZ.", anahtar)
		}
	}

	// ⚠️⚠️⚠️ TURU 93b — SLIDER ICIN **ILERI YON** KAPSAMA (kullanici emri:
	//	*"butun kategoriler AYRI olmali ... kategorilerin HEPSI AYRI"*).
	//
	//	Muhafiz ASIMETRIKTI: `altKategoriler` icin ileri yon (her kategorinin
	//	girisi OLMALI) zorlaniyor, `kategoriSlider` icin YALNIZ ters yon
	//	(olu giris) olculuyordu. Sonuc: `giyim`, `eczane`, `emlak`,
	//	`teknoloji`, `eglence`, `hizmet` sessizce `sliderVarsayilan`a
	//	dusuyordu ve kullanici Giyim, Teknoloji, Eczane, Emlak ekranlarinda
	//	**BIREBIR AYNI UC SLAYDI** goruyordu.
	//	Ayni testte, ayni amac icin IKI FARKLI sikilik — "asimetrinin
	//	KENDISI hataydi" desenin tekrari.
	//
	// ⚠️ YAPMA: yeni bir kategori eklerken bu haritaya girisini yazmadan
	//    gecme; gercekten ozel metin turetilemiyorsa `sliderMuaf`a
	//    GEREKCESIYLE ekle (sessizce varsayilana dusurme).
	sliderMuaf := map[string]string{
		"diger": "kategorisi belirsiz — ozel bir slider metni turetilemez; " +
			"genel varsayilan ORASI ICIN dogrudur",
	}
	for anahtar, ad := range Kategoriler {
		if _, ok := kategoriSlider[anahtar]; ok {
			continue
		}
		if _, muaf := sliderMuaf[anahtar]; muaf {
			continue
		}
		t.Errorf("`kategoriSlider` icinde %q (%s) YOK — bu kategori "+
			"`sliderVarsayilan`a duser ve kullanici BASKA kategorilerle "+
			"BIREBIR AYNI slaytlari gorur. Kullanici emri: HER KATEGORI "+
			"FARKLI. Ozel metin turetilemiyorsa `sliderMuaf`a GEREKCESIYLE "+
			"ekle.", anahtar, ad)
	}

	// ⚠️ SLAYT METINLERI KATEGORILER ARASINDA **TEKRARLAMAMALI**. Girisi
	//    olmak yetmez: birinden kopyalanmis bir metin de kullaniciya "ayni
	//    ekran" hissi verir (hatanin GORUNEN bicimi tam buydu).
	gorulen := map[string]string{}
	for anahtar, slaytlar := range kategoriSlider {
		for _, s := range slaytlar {
			if once, ok := gorulen[s.Baslik]; ok {
				t.Errorf("slider basligi %q hem %q hem %q kategorisinde "+
					"kullanilmis — kategoriler AYRI gorunmeli.",
					s.Baslik, once, anahtar)
			}
			gorulen[s.Baslik] = anahtar
		}
	}
}

// Alt kategori kalemlerinin KENDI IC tutarliligi.
//
// ⚠️ `Ara` BOS OLAMAZ: kart bir ARAMA KISAYOLUDUR ve bos arama metni, karta
//
//	dokunmayi TAMAMEN ETKISIZ yapar (kullanici basar, hicbir sey degismez).
//	Bu, "dugme var ama hicbir sey yapmiyor" sinifidir.
//
// ⚠️ AD UZUNLUGU: kart 60x60 ve yazi ALTINDA iki satira sariyor. 16
//
//	karakterden uzun bir ad iki satira da SIGMAZ ve ellipsis'e girer —
//	"Dermokozme…" gibi okunamaz bir etiket olusur.
func TestAltKategoriKalemleriGecerli(t *testing.T) {
	for kat, liste := range altKategoriler {
		if len(liste) > 12 {
			t.Errorf("%s: %d alt kategori — serit YATAY kaydiriliyor ve 12'den "+
				"fazlasi kaydirmayi anlamsiz uzatir", kat, len(liste))
		}
		gorulen := map[string]bool{}
		for _, a := range liste {
			if strings.TrimSpace(a.Ad) == "" {
				t.Errorf("%s: ADI BOS bir alt kategori var", kat)
			}
			if strings.TrimSpace(a.Ara) == "" {
				t.Errorf("%s / %q: `Ara` BOS — karta dokunmak HICBIR SEY "+
					"yapmaz (arama metni yok). Bu, 'dugme var ama calismiyor' "+
					"sinifidir.", kat, a.Ad)
			}
			if n := len([]rune(a.Ad)); n > 16 {
				t.Errorf("%s / %q: ad %d karakter — 60px kartin altinda iki "+
					"satira SIGMAZ ve okunamaz bir ellipsis olusur "+
					"(tavan 16).", kat, a.Ad, n)
			}
			if gorulen[a.Ad] {
				t.Errorf("%s: %q IKI KEZ gecti", kat, a.Ad)
			}
			gorulen[a.Ad] = true
		}
	}
}

// Slider metinlerinin uzunlugu.
//
// ⚠️ Metinler SUNUCUDAN geliyor ve istemcide `maxLines: 2` + ellipsis var.
//
//	Cok uzun bir baslik 350px'lik slaytta KIRPILIR; muhafiz onu YAZARKEN
//	yakalar, kullanicinin ekraninda degil.
//
// ⚠️ SLAYT SAYISI 3-4 (kullanici emri). Iki slayt "slider" hissi vermez,
//
//	bes slayt 3 saniyelik donguyu 15 saniyeye cikarir ve son slayti kimse
//	gormez.
func TestSliderMetinleriMakul(t *testing.T) {
	tumu := map[string][]SliderKarti{"(varsayilan)": sliderVarsayilan}
	for k, v := range kategoriSlider {
		tumu[k] = v
	}
	for kat, liste := range tumu {
		if len(liste) < 3 || len(liste) > 4 {
			t.Errorf("%s: %d slayt — kullanici emri 3-4 slayt "+
				"(2 slayt slider hissi vermez, 5 slayt donguyu 15 sn'ye "+
				"cikarir ve son slayti kimse gormez)", kat, len(liste))
		}
		for _, s := range liste {
			if n := len([]rune(s.Baslik)); n == 0 || n > 34 {
				t.Errorf("%s / %q: baslik %d karakter (tavan 34) — 350px'lik "+
					"slaytta `maxLines: 2` ile KIRPILIR", kat, s.Baslik, n)
			}
			if n := len([]rune(s.AltMetn)); n == 0 || n > 52 {
				t.Errorf("%s / %q: alt metin %d karakter (tavan 52)",
					kat, s.AltMetn, n)
			}
		}
	}
}
