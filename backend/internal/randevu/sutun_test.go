package randevu

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 80b — `oku()` MUHAFIZI (denetim bulgusu).
//
// `oku` **IKI AYRI `rows.Scan`** tasir (`karsiAd` dalli/dalsiz). Diger
// paketlerdeki standart muhafiz yalnizca ILK Scan'i okudugu icin buraya
// oldugu gibi EKLENEMEZ — bu dosya iki dali da ayri ayri dogrular.
//
// RISK: `sutunlar` sabitine bir sutun eklenip Scan dallarindan YALNIZ BIRI
// guncellenirse, o dali kullanan uc **BOMBOS LISTE** dondurur. Hata `continue`
// ile yutulur (yalnizca log). Turu 76'da "Kaydedilenler" sayfasi tam boyle
// herkeste bos kalmisti.
//
// ⚠️ YAPMA: bu testi silme. `sutunlar`a sutun eklerken **IKI Scan dalini ve
//
//	yanit haritasini** BIRLIKTE guncelle.
//
// (Kardesleri: `internal/social/sutun_test.go`, `internal/isletme/sutun_test.go`,
// `internal/users/profil_yanit_test.go`.)

func kaynakOku(t *testing.T) string {
	t.Helper()
	b, err := os.ReadFile("handler.go")
	if err != nil {
		t.Fatalf("handler.go okunamadi: %v", err)
	}
	// ⚠️ Yorum satirlari atilir: serhlerde "rows.Scan" gibi ifadeler geciyor ve
	//    ayristirici onlari GERCEK kod sanardi (isletme muhafizinda tam bu oldu).
	var temiz []string
	for _, satir := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(strings.TrimSpace(satir), "//") {
			continue
		}
		temiz = append(temiz, satir)
	}
	return strings.Join(temiz, "\n")
}

func hedefSay(scanGovde string) int {
	n := 0
	for _, p := range strings.Split(scanGovde, ",") {
		if strings.TrimSpace(p) != "" {
			n++
		}
	}
	return n
}

func TestRandevuOkuScanDallariSutunlarlaUyumlu(t *testing.T) {
	src := kaynakOku(t)

	sab := regexp.MustCompile("(?s)const sutunlar = `(.*?)`").FindStringSubmatch(src)
	if sab == nil {
		t.Fatal("`const sutunlar` bulunamadi")
	}
	sutunSayisi := 0
	for _, p := range strings.Split(sab[1], ",") {
		if strings.TrimSpace(p) != "" {
			sutunSayisi++
		}
	}
	if sutunSayisi < 10 {
		t.Fatalf("sutunlar beklenenden kisa (%d) — ayristirma bozulmus olabilir",
			sutunSayisi)
	}

	// `oku` govdesi
	i := strings.Index(src, "func (h *Handler) oku(")
	if i < 0 {
		t.Fatal("oku() bulunamadi — yeniden adlandirildiysa BU TESTI DE guncelle")
	}
	govde := src[i:]
	if j := strings.Index(src[i+10:], "\nfunc "); j >= 0 {
		govde = src[i : i+10+j]
	}

	scanlar := regexp.MustCompile(`(?s)rows\.Scan\((.*?)\)\n`).
		FindAllStringSubmatch(govde, -1)
	if len(scanlar) != 2 {
		t.Fatalf("oku() icinde 2 rows.Scan bekleniyordu, %d bulundu — dal "+
			"eklendiyse BU TESTI DE guncelle", len(scanlar))
	}

	var kisa, uzun int
	for _, s := range scanlar {
		n := hedefSay(s[1])
		if uzun == 0 || n > uzun {
			if uzun > 0 {
				kisa = uzun
			}
			uzun = n
		} else {
			kisa = n
		}
	}

	// KISA dal = `sutunlar`in tamami.
	if kisa != sutunSayisi {
		t.Errorf("KISA Scan dali %d hedef, `sutunlar` %d sutun — uyusmuyor.\n"+
			"Bu dali kullanan uc BOMBOS liste donduracek (hata `continue` ile yutulur).",
			kisa, sutunSayisi)
	}
	// UZUN dal = `sutunlar` + JOIN'den gelen 3 alan (ad, kullanici adi, avatar).
	if uzun != sutunSayisi+3 {
		t.Errorf("UZUN Scan dali %d hedef, beklenen %d (`sutunlar` + ad/kadi/avatar).\n"+
			"JOIN alani eklendiyse bu testi de guncelle.", uzun, sutunSayisi+3)
	}
}

func TestRandevuOkuAlanlariYanittaVar(t *testing.T) {
	src := kaynakOku(t)
	i := strings.Index(src, "func (h *Handler) oku(")
	if i < 0 {
		t.Fatal("oku() bulunamadi")
	}
	govde := src[i:]
	if j := strings.Index(src[i+10:], "\nfunc "); j >= 0 {
		govde = src[i : i+10+j]
	}

	// `sutunlar` sabitindeki her SUTUN ADI yanit haritasinda bir anahtar olmali.
	sab := regexp.MustCompile("(?s)const sutunlar = `(.*?)`").FindStringSubmatch(src)
	if sab == nil {
		t.Fatal("`const sutunlar` bulunamadi")
	}
	for _, p := range strings.Split(sab[1], ",") {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		ad := p
		if k := strings.LastIndex(ad, "."); k >= 0 {
			ad = ad[k+1:]
		}
		// `isletme_id`/`musteri_id` gibi alanlar aynen; `id` de var.
		if !strings.Contains(govde, `"`+ad+`"`) {
			t.Errorf("`%s` SELECT ediliyor ama yanit haritasinda `\"%s\"` anahtari YOK.\n"+
				"Alan istemciye HIC ULASMAZ ve derleyici bunu goremez "+
				"(turu 78: kapak + onayli rozeti tam boyle kayboldu).", p, ad)
		}
	}
}
