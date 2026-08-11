package isletme

import "testing"

// ⚠️⚠️⚠️ TURU 90b — KALICI MUHAFIZ: HER KATEGORININ BIR MODULU OLMALI.
//
// ═══════════ NEDEN VAR ═══════════
//
// Turu 89 kategoriye ozel modulleri getirdi (`otel -> Odalar`,
// `saglik -> Hizmetler`, `yemek -> Menü`). Turu 90 `Kategoriler` haritasina
// IKI YENI KATEGORI ekledi (`diyetisyen`, `guzellik`) ama `moduller`
// haritasini GUNCELLEMEDI. Ikisi de sessizce `varsayilanModul`e dustu.
//
// ⚠️ HATA **TAMAMEN SESSIZDI**: `go build` + `go vet` + `flutter analyze`
//    ucu de temiz gecer, uc 200 doner, hicbir log dusmez. Bedel YALNIZ
//    KULLANICININ EKRANINDA gorunurdu:
//      · bir DIYETISYEN "Hizmet ekle" yerine **"Ürün ekle"** goruyordu,
//      · bolum etiketi **"Bölüm (İçecekler, Tatlılar...)"** diyordu,
//      · `sure_dakika` HICBIR YERDE cizilmiyordu (`alanlar` BOS),
//      · o kaydi DUZENLEYINCE tur `'hizmet'` -> `'urun'` **SESSIZCE**
//        donuyordu (istemci `modul.tur`u geri gonderiyor).
//
// Bu, bu projenin en sik hata sinifinin ("iki harita/liste birlikte
// guncellenmedi") kategori duzeyindeki tekrariydi. Muhafiz onu YAPISAL
// OLARAK imkansiz kilar: yeni bir kategori eklerken modulu yazmayi
// unutan gelistirici KIRMIZI test gorur.
//
// ⚠️ YAPMA: bu testi silme ya da `varsayilanModul`u "zaten var" diye
//    gecerli sayma — varsayilan bir YEDEKTIR, KARAR DEGILDIR.
func TestHerKategorininModuluVar(t *testing.T) {
	// ⚠️ MUAFIYETLER **GEREKCESIYLE** yazilir. Bir kategori burada yer
	//    aliyorsa, varsayilan modulun ("Ürünler") onun icin GERCEKTEN
	//    dogru oldugu ONCEDEN dusunulmus demektir.
	// ⚠️ ILK KOSUDA MUHAFIZ **IKI KATEGORI DAHA** yakaladi (`eglence`,
	//    `teknoloji`) — yani sorun turu 90'in getirdigi iki kategoriden
	//    ibaret DEGILDI, kategori listesi zaten modul haritasinin ONUNDE
	//    buyumustu. Ayrica ilk yazdigim muafiyet anahtarlarinin ucu
	//    (`teknik`/`nakliye`/`temizli`) HIC VAR OLMAYAN kategorilerdi;
	//    gercek liste `handler.go`daki `Kategoriler`den okundu.
	muaf := map[string]string{
		"market":    "raf urunu satar — varsayilan 'Ürünler' DOGRU",
		"giyim":     "urun satar — varsayilan 'Ürünler' DOGRU",
		"teknoloji": "cihaz/aksesuar satar — varsayilan 'Ürünler' DOGRU",
		"eglence":   "bilet/etkinlik agirlikli; katalog ikincil",
		"diger":     "kategorisi belirsiz — varsayilan tek makul secim",
		"hizmet":    "genel hizmet — ozel alan tanimlanamaz (tur belirsiz)",
		"emlak":     "ilan uzerinden yurur, katalog ikincil",
		"oto":       "parca (urun) + servis (hizmet) karisik — varsayilan yeterli",
	}

	for anahtar, ad := range Kategoriler {
		if _, ok := moduller[anahtar]; ok {
			continue
		}
		if gerekce, ok := muaf[anahtar]; ok {
			t.Logf("muaf: %s (%s) — %s", anahtar, ad, gerekce)
			continue
		}
		t.Errorf(
			"KATEGORI %q (%s) icin `moduller` haritasinda giris YOK.\n"+
				"  Bu kategori sessizce varsayilan module ('Ürünler') duser:\n"+
				"  katalog basligi, bolum etiketi ve ALAN TANIMLARI YANLIS olur;\n"+
				"  ozel alanlar (or. sure_dakika) HIC CIZILMEZ ve duzenlemede\n"+
				"  kayit turu sessizce 'urun'a doner.\n"+
				"  COZUM: modul.go icindeki `moduller` haritasina giris ekle,\n"+
				"  ya da varsayilan GERCEKTEN dogruysa bu testteki `muaf`\n"+
				"  haritasina GEREKCESIYLE yaz.", anahtar, ad)
	}
}

// Modulun kendi ic tutarliligi: `hizmet`/`oda` turu bir modul ALAN
// tanimlamadan ise yaramaz (istemci yalniz `modul.alanlar`i cizer).
//
// ⚠️ Bu, turu 90b'de olculen somut hatanin ikinci yarisiydi: `diyetisyen`
//    kaydi `sure_dakika` TASIYORDU ama modulde alan olmadigi icin deger
//    OLU VERIYDI — yazilir, okunur, HIC GOSTERILMEZ.
func TestOzelModullerAlanTanimliyor(t *testing.T) {
	for anahtar, m := range moduller {
		if m.Tur == "urun" {
			continue // urun modulleri ek alan gerektirmez
		}
		if len(m.Alanlar) == 0 {
			t.Errorf("modul %q turu %q ama ALAN TANIMI YOK — istemci yalniz "+
				"`modul.alanlar`i cizer, yani bu modulun ozel verisi OLU "+
				"VERI olur (yazilir, okunur, HIC GOSTERILMEZ).", anahtar, m.Tur)
		}
		if m.Ad == "" || m.Tekil == "" || m.BolumEtiketi == "" {
			t.Errorf("modul %q eksik etiket: Ad=%q Tekil=%q Bolum=%q",
				anahtar, m.Ad, m.Tekil, m.BolumEtiketi)
		}
	}
}
