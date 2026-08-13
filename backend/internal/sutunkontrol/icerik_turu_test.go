package sutunkontrol

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// TestIcerikTuru — JSON yazan HER yol `Content-Type: application/json`
// baslığını da yazmalidir.
//
// ⚠️⚠️⚠️ TURU 96i — SAHADA GORULEN HATA. `internal/isletme/adres.go`
//
//	paketin kendi `yaz()` yardimcisini ATLAYIP ciplak
//	`json.NewEncoder(w).Encode(...)` yaziyordu. Go, basligi elle yazmazsan
//	govdeyi koklar ve `text/plain; charset=utf-8` koyar.
//
// ⚠️⚠️ ETKI ISTEMCIDE, SUNUCUDA DEGIL: Dio yaniti YALNIZ `application/json`
//
//	basligiyla ayristirir; aksi halde `response.data` bir **String** olur.
//	`data['adresler']` cagrisi *"type 'String' is not a subtype of type
//	'int' of 'index'"* atar, istemcideki `catch` bunu yutar ve kullanici
//	**"Kayıtlı konumun yok"** gorur — oysa sunucuda adres VARDIR.
//
// ⚠️⚠️ NEDEN DIGER MUHAFIZLAR GOREMEDI:
//   - `go build` / `go vet`: baslik yazmamak GECERLI Go'dur.
//   - Birim testler: govde DOGRU uretiliyordu.
//   - **UCTAN UCA (`tools/uctan_uca.js`) BILE GECTI**: Node tarafinda
//     `JSON.parse(govde)` icerik turune BAKMAZ. Yani 365/365 yesildi ve
//     ozellik yine de OLU dogdu.
//     **DERS: bir yanitin DOGRU olmasi, ISTEMCININ onu OKUYABILECEGI
//     anlamina gelmez. Sozlesme govdeden ibaret degildir — BASLIK DA
//     SOZLESMENIN PARCASIDIR.**
//
// ⚠️ YAPMA: bu testi silme; yeni bir uc yazarken paketin `yaz()`
//
//	yardimcisini kullan.
func TestIcerikTuru(t *testing.T) {
	kok, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("kok dizin: %v", err)
	}

	// Fonksiyon basligi: `func ... {`
	fonkBas := regexp.MustCompile(`^func\s`)

	var bulgular []string

	for _, alt := range []string{"internal", "cmd"} {
		dizin := filepath.Join(kok, "backend", alt)
		_ = filepath.Walk(dizin, func(yol string, bilgi os.FileInfo, e error) error {
			if e != nil || bilgi.IsDir() {
				return nil
			}
			if !strings.HasSuffix(yol, ".go") || strings.HasSuffix(yol, "_test.go") {
				return nil
			}
			ham, e2 := os.ReadFile(yol)
			if e2 != nil {
				return nil
			}
			// ⚠️ YORUMLAR TEMIZLENIR: bu testin ve duzeltilen dosyalarin
			//    SERHLERINDE hatali desenin KENDISI ornek olarak geciyor.
			//    Temizlenmezse muhafiz kendi aciklamasini yakalar ve YANLIS
			//    ALARM verir (turu 80b/83/86/93b tuzagi).
			satirlar := strings.Split(YorumsuzGo(string(ham)), "\n")

			// Her fonksiyonu ayri govde olarak degerlendir.
			bas := -1
			for i := 0; i <= len(satirlar); i++ {
				son := i == len(satirlar)
				if son || fonkBas.MatchString(satirlar[i]) {
					if bas >= 0 {
						govde := strings.Join(satirlar[bas:i], "\n")
						if strings.Contains(govde, "json.NewEncoder(w)") &&
							!strings.Contains(govde, `Header().Set("Content-Type"`) {
							rel, _ := filepath.Rel(kok, yol)
							bulgular = append(bulgular,
								filepath.ToSlash(rel)+":"+
									strings.TrimSpace(satirlar[bas]))
						}
					}
					if !son {
						bas = i
					}
				}
			}
			return nil
		})
	}

	if len(bulgular) > 0 {
		t.Fatalf("JSON yazan ama Content-Type BASLIGINI yazmayan fonksiyon(lar):\n%s\n\n"+
			"Istemci (Dio) bu yaniti AYRISTIRMAZ, govdeyi String okur ve ozellik "+
			"SESSIZCE OLU DOGAR. Paketin `yaz()` yardimcisini kullan.",
			strings.Join(bulgular, "\n"))
	}
}
