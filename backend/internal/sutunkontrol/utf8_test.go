package sutunkontrol

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 83 — CIFT UTF-8 KODLAMA MUHAFIZI.
//
// ═══════════ NEDEN VAR ═══════════
//
// Bu turda **IKI KEZ** kaynak dosya bozuldu. Sebep her ikisinde de ayni:
// Git Bash'in `sed -i` / `perl -0pi` araclari Windows'ta dosyayi UTF-8 olarak
// DEGIL, sistem kod sayfasi olarak okuyup geri yaziyor. Sonuc:
//
//	orijinal  "ç"  = C3 A7          (iki bayt)
//	bozulmus  aynisi = C3 83 C2 A7  (DORT bayt — her bayt AYRI yeniden kodlanmis)
//
// ⚠️⚠️ BU SERHTE BOZUK ORNEK **HARF OLARAK YAZILMAZ** — yalnizca BAYT olarak
//    anlatilir. Ilk yazimda ornekler harfle yazilmisti ve muhafiz **KENDI
//    DOSYASINI** yakalayip yanlis alarm verdi. Bu, projede daha once
//    `isletme/sutun_test.go`da yasanan "test kendi serhindeki kelimeyi
//    eslestiriyor" tuzaginin BIREBIR tekrari.
// ⚠️ YAPMA: buraya ornek bozuk metni harfle yazma.
//
// ETKISI SESSIZ VE AGIR: `go build`, `go vet`, `flutter analyze` UCU DE TEMIZ
// gecer — cunku bozulan sey KOD DEGIL, DIZE ICERIGIDIR. Hata yalnizca
// KULLANICININ EKRANINDA gorunur: "Görüşme sürüyor" yerine okunamaz bir
// karakter yigini cizilir.
//
// Yani bu tam olarak bu projenin en cok tekrarlayan sinifi: **derleme temiz,
// sahada bozuk**. Bir surum bu haliyle yayinlansaydi TUM Turkce hata
// mesajlari, dugme yazilari ve bildirimleri okunamaz hale gelirdi.
//
// ═══════════ NASIL YAKALAR ═══════════
//
// `C3 83` bayt cifti (Latin-1 buyuk A-tilde) gecerli Turkce metinde
// **PRATIKTE OLUSMAZ**: o harf Turkce alfabede yoktur ve projede hicbir
// dilde kullanilmiyor.
// Cift kodlamada ise C3 83 KACINILMAZ olarak ortaya cikar, cunku Turkce'nin
// tum ozel harfleri (ç ğ ı ö ş ü) C3 ile baslar ve C3 kendisi C3 83'e doner.
//
// ⚠️ YAPMA: bu testi silme. Iki kez yasandi, ucuncusu yayina cikabilirdi.
// ⚠️ ⚠️ ARAC KURALI: Turkce ya da emoji iceren dosyalarda `sed -i` / `perl -pi`
//    KULLANMA. `Edit`/`Write` araclarini kullan (CLAUDE.md'de zaten yazili:
//    "PowerShell ile Dart/emoji iceren dosyalarda toplu regex replace YAPMA" —
//    ayni tuzak Git Bash araclarinda da var).
func TestCiftUTF8KodlamaYok(t *testing.T) {
	// Depo koku: bu paket `backend/internal/sutunkontrol` altinda.
	kok, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("kok bulunamadi: %v", err)
	}

	// C3 83 — cift kodlamanin imzasi (harf olarak YAZILMAZ, bkz. serh).
	imza := []byte{0xC3, 0x83}

	taranan := 0
	var bozuk []string

	tarala := func(dizin string, uzantilar ...string) {
		filepath.Walk(dizin, func(yol string, bilgi os.FileInfo, e error) error {
			if e != nil || bilgi.IsDir() {
				// Uretilen/indirilen agaclar taranmaz.
				if bilgi != nil && bilgi.IsDir() {
					ad := bilgi.Name()
					if ad == ".git" || ad == "build" || ad == ".dart_tool" ||
						ad == "node_modules" || ad == ".gotmp" || ad == "Pods" {
						return filepath.SkipDir
					}
				}
				return nil
			}
			uygun := false
			for _, u := range uzantilar {
				if strings.HasSuffix(yol, u) {
					uygun = true
					break
				}
			}
			if !uygun {
				return nil
			}
			icerik, e2 := os.ReadFile(yol)
			if e2 != nil {
				return nil
			}
			taranan++
			if idx := indexBytes(icerik, imza); idx >= 0 {
				bag, _ := filepath.Rel(kok, yol)
				bozuk = append(bozuk, bag+" (ilk konum: bayt "+itoa(idx)+")")
			}
			return nil
		})
	}

	tarala(filepath.Join(kok, "backend"), ".go", ".sql")
	tarala(filepath.Join(kok, "mobile", "lib"), ".dart")

	if taranan == 0 {
		t.Fatal("hicbir dosya taranmadi — muhafiz YANLIS DIZINE bakiyor olabilir")
	}
	if len(bozuk) > 0 {
		t.Fatalf("CIFT UTF-8 KODLAMA bulundu (%d dosya):\n  %s\n\n"+
			"ONARIM: dosyayi UTF-8 okuyup latin1 bayta cevir, tekrar UTF-8 coz.\n"+
			"SEBEP: Git Bash `sed -i` / `perl -pi` Windows'ta UTF-8'i bozar —\n"+
			"Turkce/emoji iceren dosyalarda `Edit`/`Write` kullan.",
			len(bozuk), strings.Join(bozuk, "\n  "))
	}
	t.Logf("%d dosya tarandi, cift kodlama YOK", taranan)
}

func indexBytes(h, n []byte) int {
	for i := 0; i+len(n) <= len(h); i++ {
		e := true
		for j := range n {
			if h[i+j] != n[j] {
				e = false
				break
			}
		}
		if e {
			return i
		}
	}
	return -1
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}
