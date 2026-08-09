// Package sutunkontrol — SELECT sutun sayisi ile rows.Scan argüman sayisini
// KAYNAK KODU OKUYARAK karsilastirir.
//
// ⚠️⚠️ NEDEN VAR (turu 76'da yasanan GERCEK sevk engeli):
//
//	Bir paket TEK bir `satirlariOku` fonksiyonuyla BIRDEN COK sorgunun
//	sonucunu okur. Sorguya bir sutun eklenip `Scan`e eklenmezse (ya da tersi)
//	**DERLEME HATASI OLMAZ**: `rows.Scan` calisma aninda hata doner, dongu
//	`continue` eder ve uc **BOS LISTE** dondurur — log yok, olcum yok.
//	Turu 76'da "Kaydedilenler" sayfasi tam bu yuzden HERKESTE BOMBOS
//	gorunecekti.
//
// ⚠️ Bu paket `internal/social/sutun_test.go`daki ELLE YAZILMIS liste
//
//	yaklasiminin yerine gecer: orada yeni sutun eklerken UC yeri (sorgu, Scan,
//	beklenen liste) guncellemek gerekiyordu ve UCUNCUSU unutulabilirdi.
//	Burada sayim KAYNAKTAN yapilir, elle liste YOKTUR — drift imkansiz.
package sutunkontrol

import (
	"fmt"
	"strings"
)

// UstDuzeyVirgul — bir ifade listesindeki UST DUZEY virgulleri sayarak oge
// sayisini dondurur.
//
// ⚠️ Parantez DERINLIGI takip edilir: `(SELECT count(*) FROM x WHERE a=$1)`
//
//	gibi alt sorgular ve `COALESCE(a, b)` gibi cagrilar TEK oge sayilir.
//	Bu olmadan sayim yanlis cikar ve test yalanci alarm verir.
//
// ⚠️ Tek tirnakli SQL dizeleri ATLANIR: `COALESCE(u.username,'')` icindeki
//
//	virgul zaten parantez icinde, ama `'a,b'` gibi bir sabit ust duzeyde
//	olsaydi yanlis sayardik.
func UstDuzeyVirgul(s string) int {
	derinlik, adet := 0, 0
	dizede := false
	for i := 0; i < len(s); i++ {
		c := s[i]
		if dizede {
			if c == '\'' {
				dizede = false
			}
			continue
		}
		switch c {
		case '\'':
			dizede = true
		case '(', '[':
			derinlik++
		case ')', ']':
			derinlik--
		case ',':
			if derinlik == 0 {
				adet++
			}
		}
	}
	return adet
}

// SutunSayisi — `const sutunlar = ` + ters tirnakli blogu bulup oge sayar.
func SutunSayisi(kaynak, sabitAdi string) (int, error) {
	anahtar := "const " + sabitAdi + " = `"
	i := strings.Index(kaynak, anahtar)
	if i < 0 {
		return 0, fmt.Errorf("`const %s` bulunamadi", sabitAdi)
	}
	govde := kaynak[i+len(anahtar):]
	j := strings.Index(govde, "`")
	if j < 0 {
		return 0, fmt.Errorf("`const %s` kapanmamis", sabitAdi)
	}
	return UstDuzeyVirgul(govde[:j]) + 1, nil
}

// ScanSayisi — `rows.Scan(` cagrisindaki argüman sayisini dondurur.
//
// ⚠️ Kaynakta birden cok `rows.Scan(` varsa ILKI alinir; bu paketlerde
//
//	`satirlariOku` TEK Scan tasiyor (tasarim geregi — coklu Scan zaten
//	bu testin engellemeye calistigi drift demektir).
func ScanSayisi(kaynak string) (int, error) {
	anahtar := "rows.Scan("
	i := strings.Index(kaynak, anahtar)
	if i < 0 {
		return 0, fmt.Errorf("`rows.Scan(` bulunamadi")
	}
	govde := kaynak[i+len(anahtar):]
	// Kapanis parantezini derinlik sayarak bul.
	derinlik := 0
	for j := 0; j < len(govde); j++ {
		switch govde[j] {
		case '(':
			derinlik++
		case ')':
			if derinlik == 0 {
				return UstDuzeyVirgul(govde[:j]) + 1, nil
			}
			derinlik--
		}
	}
	return 0, fmt.Errorf("`rows.Scan(` kapanmamis")
}
