package social

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 81 — ZAMANLANMIS GONDERI YUKLEMI MUHAFIZI.
//
// ═══════════ NEDEN AYRI BIR TEST ═══════════
//
// `sutun_test.go` YALNIZCA **SELECT sutun listesini** dogruluyor; `WHERE`
// yuklemine HIC BAKMIYOR. Yani "6 sorguya ekleyip 7.'yi atlama" hatasinin
// (turu 76'da `Kaydedilenler` sayfasini BOMBOS birakan sinif) YUKLEM
// bicimini o test **YAPISAL OLARAK YAKALAYAMAZ**.
//
// Zamanlanmis gonderide bu hatanin bedeli agirdir: yuklem bir sorguda eksik
// kalirsa, kullanicinin GELECEGE zamanladigi gonderi o yuzeyden **SIZAR** —
// yani "yarin yayinlansin" dedigi icerik bugun gorunur. Geri alinamaz.
//
// ⚠️ YAPMA: bu testi silme. Yeni bir gonderi sorgusu eklerken `yayindaOlan`
//
//	yuklemini de ekle (ya da yazarin kendi listesi gibi BILINCLI bir
//	istisnaysa asagidaki `istisnalar` haritasina GEREKCESIYLE yaz).
//
// (Kardesleri: `sutun_test.go`, `internal/isletme/sutun_test.go`,
// `internal/randevu/sutun_test.go`.)

// Yuklemi BILEREK tasimayan sorgular — her biri GEREKCESIYLE.
var istisnalar = map[string]string{
	// Yazar KENDI zamanladigi gonderiyi gormeli; yoksa "kayboldu" sanar.
	// O sorgu yuklemi `OR p.author_id = $1` ile GEVSETIYOR (kaldirmiyor).
	"UserPosts": "yazar kendi zamanladigini gorur (OR p.author_id)",
	// Tek gonderi ucu: id ile dogrudan erisim. Zamanlanmis gonderiye
	// LINKLE erisim yazarin kendi paylasimidir; akista GORUNMEZ.
	"Detay": "id ile dogrudan erisim",
}

func TestGonderiSorgularindaYayinYuklemi(t *testing.T) {
	var kaynak strings.Builder
	for _, f := range []string{"handler.go", "etkilesim.go"} {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatalf("%s okunamadi: %v", f, err)
		}
		kaynak.WriteString(string(b))
		kaynak.WriteString("\n")
	}
	src := kaynak.String()

	// ⚠️ Yorum satirlari ATILIR: serhlerde "FROM posts p" gibi ifadeler geciyor
	//    ve ayristirici onlari GERCEK sorgu sanardi (isletme muhafizinda ilk
	//    yazimda tam bu oldu ve YANLIS ALARM verdi).
	var temiz []string
	for _, satir := range strings.Split(src, "\n") {
		t := strings.TrimSpace(satir)
		if strings.HasPrefix(t, "//") || strings.HasPrefix(t, "--") {
			continue
		}
		temiz = append(temiz, satir)
	}
	src = strings.Join(temiz, "\n")

	// Her `FROM posts p JOIN users` (yani AKIS/LISTE sorgusu) icin, o sorgunun
	// icinde bulundugu fonksiyonu ve yuklemin varligini kontrol et.
	fnAdi := regexp.MustCompile(`func \(h \*Handler\) (\w+)\(`)
	konumlar := fnAdi.FindAllStringSubmatchIndex(src, -1)

	fonksiyonAdi := func(pos int) string {
		ad := "?"
		for _, k := range konumlar {
			if k[0] < pos {
				ad = src[k[2]:k[3]]
			} else {
				break
			}
		}
		return ad
	}

	sayac := 0
	for i := 0; i < len(src); {
		j := strings.Index(src[i:], "FROM posts p JOIN users")
		if j < 0 {
			break
		}
		mutlak := i + j
		i = mutlak + 10
		sayac++

		fn := fonksiyonAdi(mutlak)
		// ⚠️ PENCERE `FROM`UN HEM ONUNU HEM ARKASINI KAPSAR.
		//    Ilk yazimda yalnizca ARKASINA bakiyordu ve YANLIS ALARM verdi:
		//    `erisebilirMi` yuklemi SELECT LISTESINDE tasiyor (`p.yayin_at`),
		//    yani `FROM`dan ONCE. Sorgular kisa oldugu icin iki yonlu pencere
		//    guvenli; komsu sorguya tasma riski `bas` mesafesinin dar
		//    tutulmasiyla siniri.
		bas := mutlak - 400
		if bas < 0 {
			bas = 0
		}
		son := mutlak + 1400
		if son > len(src) {
			son = len(src)
		}
		pencere := src[bas:son]

		yuklemVar := strings.Contains(pencere, "yayindaOlan") ||
			strings.Contains(pencere, "p.yayin_at")

		if !yuklemVar {
			if gerekce, ok := istisnalar[fn]; ok {
				t.Logf("`%s` yuklemi tasimiyor — BILINCLI istisna: %s", fn, gerekce)
				continue
			}
			t.Errorf(
				"`%s` icindeki gonderi sorgusunda ZAMANLANMIS GONDERI YUKLEMI YOK.\n"+
					"Kullanicinin GELECEGE zamanladigi gonderi bu yuzeyden SIZAR.\n"+
					"`+yayindaOlan+` ekle; bilincli bir istisnaysa `istisnalar` "+
					"haritasina GEREKCESIYLE yaz.", fn)
		}
	}

	if sayac < 6 {
		t.Fatalf("beklenenden az gonderi sorgusu bulundu (%d) — ayristirma "+
			"bozulmus olabilir; test YANLIS NEGATIF veriyor olabilir", sayac)
	}
	t.Logf("%d gonderi sorgusu tarandi", sayac)
}
