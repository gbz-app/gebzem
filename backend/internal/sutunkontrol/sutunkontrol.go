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
// ⚠️ Tek tirnakli SQL dizeleri ATLANIR: `COALESCE(u.username,”)` icindeki
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

// SabitGovdesi — `const AD = ...` ifadesinin TAM metnini cozer.
//
// ⚠️⚠️ SABIT BIRLESTIRMESI COZULUR. Sutun listeleri su bicimde yazilabiliyor:
//
//	const sutunlar = `
//	        i.id, i.baslik,
//	        ` + medyaTurleri + `
//	        i.duzenlendi_at`
//
//	Yalnizca ILK ters tirnakli blogu okusaydik `medyaTurleri` icindeki
//	sutunlari SAYMAZ ve muhafiz YALANCI ALARM verirdi (gercekte hizali olan
//	kodu bozuk gosterirdi). Yalanci alarm veren bir muhafiz, kapatilan
//	muhafizdir.
//
// ⚠️ Cozum OZYINELI: birlestirilen sabit de baska bir sabiti birlestirebilir.
//
//	`derinlik` sonsuz dongu emniyetidir (birbirine referans veren sabitler).
func SabitGovdesi(kaynak, sabitAdi string, derinlik int) (string, error) {
	if derinlik > 8 {
		return "", fmt.Errorf("sabit cozumu cok derin: %s", sabitAdi)
	}
	anahtar := "const " + sabitAdi + " = "
	i := strings.Index(kaynak, anahtar)
	if i < 0 {
		return "", fmt.Errorf("const %s bulunamadi", sabitAdi)
	}
	s := kaynak[i+len(anahtar):]
	var sonuc strings.Builder
	p := 0
	for {
		// bosluk atla
		for p < len(s) && (s[p] == ' ' || s[p] == '\t' || s[p] == '\n' || s[p] == '\r') {
			p++
		}
		if p >= len(s) {
			break
		}
		if s[p] == '`' {
			k := strings.IndexByte(s[p+1:], '`')
			if k < 0 {
				return "", fmt.Errorf("const %s kapanmamis", sabitAdi)
			}
			sonuc.WriteString(s[p+1 : p+1+k])
			p += k + 2
		} else if harfMi(s[p]) {
			b := p
			for p < len(s) && (harfMi(s[p]) || s[p] >= '0' && s[p] <= '9') {
				p++
			}
			ic, err := SabitGovdesi(kaynak, s[b:p], derinlik+1)
			if err != nil {
				return "", err
			}
			sonuc.WriteString(ic)
		} else {
			break
		}
		// bosluk atla, sonra '+' bekle
		q := p
		for q < len(s) && (s[q] == ' ' || s[q] == '\t' || s[q] == '\n' || s[q] == '\r') {
			q++
		}
		if q < len(s) && s[q] == '+' {
			p = q + 1
			continue
		}
		break
	}
	return sonuc.String(), nil
}

func harfMi(c byte) bool {
	return c == '_' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z'
}

// SutunSayisi — sabitin TAM govdesindeki ust duzey oge sayisi.
func SutunSayisi(kaynak, sabitAdi string) (int, error) {
	govde, err := SabitGovdesi(kaynak, sabitAdi, 0)
	if err != nil {
		return 0, err
	}
	govde = strings.TrimSpace(govde)
	// ⚠️ Birlestirilen sabitler genelde SONDA virgulle biter (`..., `). O
	//    virgul bir sonraki parcanin ONUNE geldigi icin cift saymamak sart.
	govde = strings.TrimSuffix(govde, ",")
	return UstDuzeyVirgul(govde) + 1, nil
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

// ═══════════════════ TURU 91 — COKLU SORGU DESTEGI ═══════════════════
//
// ⚠️ NEDEN GEREKTI: mevcut `SutunSayisi`/`ScanSayisi` ciftı TEK sorgulu
//    dosyalar icin yazilmisti (`satirlariOku` deseni). `internal/ilan/
//    basvuru.go` gibi dosyalarda BIRDEN COK bagimsiz sorgu var ve her biri
//    kendi `Scan`ine sahip; tek sayi donduren API onlari OLCEMEZ.
//    Kopyasini teste yazmak yerine paket genisletildi — bu paketin var olus
//    sebebi zaten "ayni ayristirma mantiginin ikinci kopyasi olmasin".

// YorumsuzGo — Go kaynagindan `//` ve `/* */` yorumlarini SILER.
//
// ⚠️ ZORUNLU: bu ailedeki testler ILK YAZIMDA IKI KEZ (turu 80b
//
//	`isletme/sutun_test.go`, turu 83 `utf8_test.go`) KENDI SERHLERINDEKI
//	ornegi eslestirip yanlis alarm verdi. Serhler SQL ve alan adi ornekleri
//	icerdigi icin ayristiriciya girmemeleri sart.
//
// ⚠️ Dize icindeki `//` KORUNUR (or. bir URL) — kaba bir silme, `"` ve
//
//	backtick takibi yaparak yapilir.
func YorumsuzGo(kaynak string) string {
	var out strings.Builder
	out.Grow(len(kaynak))
	const (
		duz = iota
		dizeCift
		dizeTers
		satirYorum
		blokYorum
	)
	durum := duz
	for i := 0; i < len(kaynak); i++ {
		c := kaynak[i]
		switch durum {
		case duz:
			if c == '"' {
				durum = dizeCift
			} else if c == '`' {
				durum = dizeTers
			} else if c == '/' && i+1 < len(kaynak) && kaynak[i+1] == '/' {
				durum = satirYorum
				continue
			} else if c == '/' && i+1 < len(kaynak) && kaynak[i+1] == '*' {
				durum = blokYorum
				i++
				continue
			}
			out.WriteByte(c)
		case dizeCift:
			out.WriteByte(c)
			if c == '\\' && i+1 < len(kaynak) {
				i++
				out.WriteByte(kaynak[i])
			} else if c == '"' {
				durum = duz
			}
		case dizeTers:
			out.WriteByte(c)
			if c == '`' {
				durum = duz
			}
		case satirYorum:
			if c == '\n' {
				out.WriteByte(c)
				durum = duz
			}
		case blokYorum:
			if c == '*' && i+1 < len(kaynak) && kaynak[i+1] == '/' {
				i++
				durum = duz
			}
		}
	}
	return out.String()
}

// SelectSutunlari — kaynaktaki HER `SELECT ... FROM` blogunun ust duzey
// sutun sayisini, GORULME SIRASIYLA dondurur.
//
// ⚠️ `UstDuzeyVirgul` kullanilir: `COALESCE(u.name,”)` gibi fonksiyon
//
//	cagrilarinin ICINDEKI virguller SAYILMAZ (paketin cekirdek islevi).
//
// ⚠️ Alt sorgular (`EXISTS(SELECT 1 ...)`) da eslesir; bu YANLIS DEGILDIR —
//
//	her SELECT'in bir Scan karsiligi olmasi beklenmez, cagiran taraf
//	sayilari SIRAYLA karsilastirir ve alt sorgular icin de bir Scan
//	bulunmasi gerekir. Bu yuzden alt sorgu ICEREN dosyalarda cagiran,
//	esitligi degil MANTIKLI ESLESMEYI dogrulamalidir.
//	⚠️ Pratikte alt sorgular `SELECT 1` oldugu icin 1 sutun sayilir ve
//	   kolayca ayirt edilir.
func SelectSutunlari(kaynak string) ([]int, error) {
	var sonuc []int
	kalan := kaynak
	for {
		i := strings.Index(kalan, "SELECT ")
		if i < 0 {
			break
		}
		govde := kalan[i+len("SELECT "):]
		j := strings.Index(govde, "FROM ")
		if j < 0 {
			break
		}
		ic := strings.TrimSpace(govde[:j])
		// ⚠️ ALT SORGULAR ATLANIR. `EXISTS(SELECT 1 FROM ...)` ve
		//    `(SELECT count(*) FROM ...)` bir `Scan`e KARSILIK GELMEZ;
		//    sayilsalardi SELECT ve Scan listeleri hizalanamaz ve muhafiz
		//    "eslestirme yapilamiyor" diye SUREKLI kirmizi kalirdi —
		//    yani KAPATILAN bir muhafiz olurdu.
		// ⚠️ Olcut ICERIK: alt sorgular sabit/toplama secer (`1`, `count(*)`),
		//    gercek satir sorgulari SUTUN ADI secer.
		altSorgu := ic == "1" || strings.HasPrefix(ic, "count(") ||
			strings.HasPrefix(ic, "COUNT(")
		if !altSorgu {
			sonuc = append(sonuc, UstDuzeyVirgul(ic)+1)
		}
		kalan = govde[j:]
	}
	if len(sonuc) == 0 {
		return nil, fmt.Errorf("hic `SELECT ... FROM` bulunamadi")
	}
	return sonuc, nil
}

// ScanSayilari — kaynaktaki HER `.Scan(` cagrisinin argüman sayisini,
// GORULME SIRASIYLA dondurur.
//
// ⚠️ `rows.Scan` ve `QueryRow(...).Scan` IKISI DE sayilir: ikisi de ayni
//
//	sessiz-bosalma sinifini uretir.
func ScanSayilari(kaynak string) ([]int, error) {
	var sonuc []int
	kalan := kaynak
	for {
		i := strings.Index(kalan, ".Scan(")
		if i < 0 {
			break
		}
		govde := kalan[i+len(".Scan("):]
		derinlik := 0
		bulundu := false
		for j := 0; j < len(govde); j++ {
			switch govde[j] {
			case '(':
				derinlik++
			case ')':
				if derinlik == 0 {
					sonuc = append(sonuc, UstDuzeyVirgul(govde[:j])+1)
					kalan = govde[j:]
					bulundu = true
				} else {
					derinlik--
				}
			}
			if bulundu {
				break
			}
		}
		if !bulundu {
			return nil, fmt.Errorf("`.Scan(` kapanmamis")
		}
	}
	if len(sonuc) == 0 {
		return nil, fmt.Errorf("hic `.Scan(` bulunamadi")
	}
	return sonuc, nil
}
