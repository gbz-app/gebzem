package isletme

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 80b — `Detay()` MUHAFIZI (denetim bulgusu: bu pakette HIC test yoktu).
//
// Bu dosya, projenin IKI KEZ SAHAYA CIKMIS hata sinifini kapatir:
//
//	(1) SELECT ile `Scan` SIRASI/SAYISI ayrilirsa `QueryRow(...).Scan(...)`
//	    hata doner, `Detay` **404 "işletme bulunamadı"** yazar ve HICBIR
//	    log/olcum dusmez. Isletme profili herkeste bos gorunur.
//	    (turu 76: `Kaydedilenler` sayfasi tam boyle BOMBOS kalmisti.)
//
//	(2) Sutun SELECT + Scan edilir ama YANIT HARITASINA konmaz. Derleyici
//	    bunu GOREMEZ (Scan'in yan etkisi vardir, degisken "kullanilmis"
//	    sayilir). Turu 78'de `Profile()`da tam bu olmustu: kapak ve onayli
//	    rozeti HICBIR PROFILDE cizilmiyordu.
//	    Turu 80 ayni sorguya `randevu_acik` ekledi — yani ayni tuzagin
//	    kapisi TEKRAR aralandi.
//
// ⚠️ YAPMA: bu testi silme. `Detay`a yeni sutun eklerken **SELECT + Scan +
//
//	yanit haritasi** UCUNU BIRLIKTE guncelle.
//
// (Kardesleri: `internal/social/sutun_test.go`, `internal/users/profil_yanit_test.go`.)

// camelCase -> snake_case ("randevuAcik" -> "randevu_acik")
func yilanla(s string) string {
	var b strings.Builder
	for i, r := range s {
		if r >= 'A' && r <= 'Z' {
			if i > 0 {
				b.WriteByte('_')
			}
			b.WriteRune(r - 'A' + 'a')
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// Detay govdesini kaynaktan cikarir.
func detayGovdesi(t *testing.T) string {
	t.Helper()
	b, err := os.ReadFile("handler.go")
	if err != nil {
		t.Fatalf("handler.go okunamadi: %v", err)
	}
	src := string(b)
	i := strings.Index(src, "func (h *Handler) Detay(")
	if i < 0 {
		t.Fatal("Detay() bulunamadi — yeniden adlandirildiysa BU TESTI DE guncelle")
	}
	// Bir sonraki ust duzey fonksiyona kadar.
	govde := src[i:]
	if j := strings.Index(src[i+10:], "\nfunc "); j >= 0 {
		govde = src[i : i+10+j]
	}

	// ⚠️ YORUM SATIRLARI ATILIR. Bu dosyanin serhleri "SELECT sirasi ile Scan
	//    sirasi BIREBIR" gibi cumleler iceriyor; ayristirici onlari GERCEK
	//    sorgu sanip yanlis alarm veriyordu (ilk yazimda tam bu oldu).
	var temiz []string
	for _, satir := range strings.Split(govde, "\n") {
		if strings.HasPrefix(strings.TrimSpace(satir), "//") {
			continue
		}
		temiz = append(temiz, satir)
	}
	return strings.Join(temiz, "\n")
}

func TestDetaySelectVeScanHizali(t *testing.T) {
	govde := detayGovdesi(t)

	sel := regexp.MustCompile(`(?s)SELECT\s+(.*?)\s+FROM`).FindStringSubmatch(govde)
	if sel == nil {
		t.Fatal("Detay icinde SELECT ... FROM bulunamadi")
	}
	// Sutunlari virgulden ayir. ⚠️ Fonksiyon cagrilarindaki virguller
	//    (COALESCE(ra.acik, false)) sayilmamali — parantez derinligi tutulur.
	var sutunlar []string
	derinlik, son := 0, 0
	ham := sel[1]
	for i, c := range ham {
		switch c {
		case '(':
			derinlik++
		case ')':
			derinlik--
		case ',':
			if derinlik == 0 {
				sutunlar = append(sutunlar, strings.TrimSpace(ham[son:i]))
				son = i + 1
			}
		}
	}
	sutunlar = append(sutunlar, strings.TrimSpace(ham[son:]))

	scan := regexp.MustCompile(`(?s)\.\s*Scan\((.*?)\)\s*!=\s*nil`).
		FindStringSubmatch(govde)
	if scan == nil {
		t.Fatal("Detay icinde .Scan(...) != nil bulunamadi")
	}
	var hedefler []string
	for _, p := range strings.Split(scan[1], ",") {
		p = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(p), "&"))
		if p != "" {
			hedefler = append(hedefler, p)
		}
	}

	if len(sutunlar) != len(hedefler) {
		t.Fatalf(
			"SELECT %d sutun, Scan %d hedef — SESSIZ 404 riski.\nSELECT: %v\nScan:   %v",
			len(sutunlar), len(hedefler), sutunlar, hedefler)
	}
	if len(sutunlar) < 8 {
		t.Fatalf("SELECT beklenenden kisa (%d) — ayristirma bozulmus olabilir",
			len(sutunlar))
	}

	// ⚠️⚠️ SIRA DA OLCULUR (turu 80b denetimi: test adi "Hizali" diyordu ama
	//    govde YALNIZ SAYIYI karsilastiriyordu).
	//
	//	SAYI esitligi TEK BASINA yetmez: `i.il` ile `i.ilce` (ikisi de TEXT)
	//	yer degistirse Postgres HATA VERMEZ — sehir ile ilce SESSIZCE TAKAS
	//	olur ve isletme rehberinde yanlis konum gorunur. Ayni tuzak
	//	`telefon`/`web` icin de gecerli.
	//
	// ⚠️ Esleme KURALI: SELECT sutununun son parcasi (`i.kategori` -> kategori)
	//    Scan hedefinin adiyla ESLESMELI. Uymayanlar `istisna`da ACIKCA
	//    listelenir — boylece bilincli sapmalar gorunur kalir.
	istisna := map[string]string{
		"u.onayli":                 "dogrulandi",
		"COALESCE(ra.acik, false)": "randevuAcik",
	}
	for i, s := range sutunlar {
		bekle, ok := istisna[s]
		if !ok {
			bekle = s
			if k := strings.LastIndex(bekle, "."); k >= 0 {
				bekle = bekle[k+1:]
			}
		}
		if hedefler[i] != bekle {
			t.Errorf(
				"SIRA BOZUK — %d. sutun `%s` ama %d. Scan hedefi `%s` (beklenen `%s`).\n"+
					"Ayni tipteki iki sutun yer degistirirse Postgres HATA VERMEZ; "+
					"degerler SESSIZCE TAKAS olur (or. il <-> ilce).\n"+
					"Bilincli bir sapmaysa `istisna` haritasina ekle.",
				i+1, s, i+1, hedefler[i], bekle)
		}
	}
}

func TestDetayScanEdilenAlanlarYanittaVar(t *testing.T) {
	govde := detayGovdesi(t)

	scan := regexp.MustCompile(`(?s)\.\s*Scan\((.*?)\)\s*!=\s*nil`).
		FindStringSubmatch(govde)
	if scan == nil {
		t.Fatal("Detay icinde .Scan(...) != nil bulunamadi")
	}
	// Yanit haritasi: `yaz(w, 200, map[string]any{ ... })`
	yanit := regexp.MustCompile(`(?s)yaz\(w,\s*200,\s*map\[string\]any\{(.*)`).
		FindStringSubmatch(govde)
	if yanit == nil {
		t.Fatal("Detay icinde yanit haritasi bulunamadi")
	}
	govdeYanit := yanit[1]

	for _, p := range strings.Split(scan[1], ",") {
		ad := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(p), "&"))
		if ad == "" {
			continue
		}
		// Degisken yanitta DOGRUDAN kullaniliyor mu, ya da snake_case
		// karsiligi bir anahtar var mi?
		anahtar := `"` + yilanla(ad) + `"`
		kullanilmis := regexp.MustCompile(`\b` + regexp.QuoteMeta(ad) + `\b`).
			MatchString(govdeYanit)
		if !kullanilmis && !strings.Contains(govdeYanit, anahtar) {
			t.Errorf(
				"`%s` SELECT+Scan ediliyor ama YANIT HARITASINDA YOK.\n"+
					"Derleyici bunu goremez (Scan'in yan etkisi var) — alan "+
					"istemciye HIC ULASMAZ. Turu 78'de kapak/onayli tam boyle kayboldu.\n"+
					"Beklenen anahtar: %s", ad, anahtar)
		}
	}
}
