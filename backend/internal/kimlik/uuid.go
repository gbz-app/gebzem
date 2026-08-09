// Package kimlik — UUID bicim dogrulamasi icin **TEK KAYNAK**.
//
// ⚠️⚠️ NEDEN AYRI BIR PAKET (turu 77b denetim bulgusu):
//
//	URL parametresi (`/ilanlar/abc`) dogrudan sorguya giderse Postgres
//	`invalid input syntax for type uuid` doner, handler 500 yazar ve log
//	gurultusu birikir — dogrusu 404'tur. Ayrica `= ANY($2)` bicimindeki
//	sorgularda TEK bozuk deger sorgunun TAMAMINI 500 yapar (turu 76'da
//	`/users/ozet`te tam bu yasandi).
//
//	Kontrol dort ayri handler'a KOPYALANABILIRDI; bu projede "ayni kuralin
//	iki kopyasi DRIFT eder" dersi (turu 72b/H, 75b/2) bes kez tekrarladi.
//	Bu yuzden tek yerde duruyor.
//	⚠️ YAPMA: bu fonksiyonu handler'lara kopyalama.
package kimlik

// Gecerli — 8-4-4-4-12 onaltilik bicim (surum/varyant bitleri KONTROL EDILMEZ).
//
// ⚠️ Amac GUVENLIK degil, Postgres'in cast hatasini ONLEMEK. Bicimi dogru olan
//
//	ama var olmayan bir id zaten sorgudan bos doner -> 404.
func Gecerli(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i := 0; i < 36; i++ {
		c := s[i]
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if c != '-' {
				return false
			}
			continue
		}
		onaltilik := (c >= '0' && c <= '9') ||
			(c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
		if !onaltilik {
			return false
		}
	}
	return true
}
