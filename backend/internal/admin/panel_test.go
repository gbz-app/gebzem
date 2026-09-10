package admin

import (
	"os"
	"regexp"
	"sort"
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 181 — PANEL <-> UC HIZASI MUHAFIZI.
//
// ═══════════ NEDEN YAZILDI ═══════════
//
// Bu projedeki EN SIK hata sinifi: **"uc yazildi, cagiran yol yazilmadi"**
// (CLAUDE.md'de DOKUZ kez kayitli). Bu turda somut ornegi de bulundu:
// `GET /admin/streams` ve `POST /admin/streams/{id}/end` uclari turu
// 78'den beri SUNUCUDA VARDI ama panelde onlari cagiran HICBIR ARAYUZ
// YOKTU — 5651'in "4 saat icinde kaldirma" kurali icin yazilmis moderasyon
// ozelligi FIILEN ULASILAMAZDI ve kimse fark etmedi.
//
// Muhafiz IKI YONU DE olcer:
//   - PANELDE CAGRILAN ama `main.go`da KAYITLI OLMAYAN yol -> panel dugmesi
//     404 alir (kullaniciya "bir seyler ters gitti" der).
//   - `main.go`da KAYITLI ama PANELDE HIC CAGRILMAYAN yol -> olu uc.
//
// ⚠️ Ayristirilamazsa `t.Fatal` ile DURUR: sessizce gecen bir muhafiz,
//
//	olmayan bir muhafizdan KOTUDUR (turu 93b dersi).
//
// ⚠️ YAPMA: bu testi silme. Yeni bir admin ucu eklerken panele de bagla
//
//	(ya da bilincli olarak `panelsizUclar`a ekle).
func TestPanelVeUclarHizali(t *testing.T) {
	panelYollar := panelCagrilari(t)
	rotaYollar := adminRotalari(t)

	// ⚠️ PANELSIZ uclar — bilincli istisnalar, GEREKCESIYLE.
	panelsiz := map[string]string{
		// Panel HTML'ini ve varliklarini tarayici dogrudan ister.
		"/admin/izle":   "tarayici dogrudan acar",
		"/admin/varlik": "stylesheet/script etiketiyle yuklenir",
		// Giris/cikis `fetch` ile cagriliyor ama `api()` sarmalayicisi
		// disinda (jeton HENUZ yok) — desen onlari yakalamaz.
		"/admin/giris": "login formu, api() disinda cagriliyor",
		"/admin/cikis": "cikisYap() icinde, api() disinda cagriliyor",
		// ESKI uclar: geriye uyumluluk icin duruyorlar, yeni panel
		// kullanmiyor. Silinmediler cunku eski sekmeler/betikler cagirabilir.
		"/admin/login": "eski panel ucu (geriye uyumluluk)",
		"/admin/stats": "eski panel ucu (geriye uyumluluk)",
		"/admin/users": "eski panel ucu (geriye uyumluluk)",
		"/admin/user":  "eski panel ucu (geriye uyumluluk)",
		"/admin/calls": "eski panel ucu (geriye uyumluluk)",
		"/admin/audio": "eski panel ucu (canli ses teshis)",
		"/admin/ws":    "eski panel ucu (WebSocket)",
	}

	// (1) Panelde cagrilan her yol KAYITLI olmali.
	for _, y := range panelYollar {
		if !rotaYollar[y] {
			t.Errorf(
				"panel `%s` cagiriyor ama `cmd/api/main.go`da KAYITLI DEGIL.\n"+
					"Dugme 404 alir ve kullaniciya \"bir seyler ters gitti\" der.\n"+
					"Cozum: rotayi main.go'ya ekle ya da panelden cagriyi kaldir.", y)
		}
	}

	// (2) Kayitli her uc panelde cagrilmali (istisnalar disinda).
	var oluUclar []string
	for y := range rotaYollar {
		if panelsiz[y] != "" {
			continue
		}
		bulundu := false
		for _, p := range panelYollar {
			if p == y {
				bulundu = true
				break
			}
		}
		if !bulundu {
			oluUclar = append(oluUclar, y)
		}
	}
	sort.Strings(oluUclar)
	if len(oluUclar) > 0 {
		t.Errorf(
			"su admin uclari KAYITLI ama PANELDE HIC CAGRILMIYOR: %v\n"+
				"Bu, projede DOKUZ kez tekrarlayan \"uc yazildi, cagiran yol "+
				"yazilmadi\" sinifidir (turu 181'de `/admin/streams` tam boyle "+
				"UC TUR boyunca ULASILAMAZ kalmisti).\n"+
				"Cozum: panele bagla ya da gerekcesiyle `panelsiz` haritasina ekle.",
			oluUclar)
	}
}

// ⚠️⚠️ TURU 181 — XSS MUHAFIZI.
//
// Panel DB'den gelen metinleri (isletme adi, urun adi, sikayet aciklamasi)
// HTML sablonlarina basiyor. Bunlarin HEPSI kullanici girdisi; ham
// basilirsa yoneticinin oturum jetonunu calan bir XSS olur — ve o jeton
// TUM yonetim yetkisidir.
//
// Kural: sablon icindeki her `${...}` ifadesi ya `esc(` ile sarilmali ya
// da SAYISAL/sabit bir ifade olmali.
//
// ⚠️ YAPMA: sablona `${x}` yazma; `${esc(x)}` yaz.
func TestPanelHamDegerBasmiyor(t *testing.T) {
	js := oku(t, "panel/panel.js")
	// ⚠️⚠️ OLCUT **NESNE ALANLARI** (`x.y`), her ifade DEGIL.
	//
	//	Ilk yazimda desen `' + IFADE + '` biciminin TAMAMINI yakaliyordu
	//	ve 23 YANLIS POZITIF verdi: yerel degiskenler (`et`, `durum`,
	//	`opt`), sabit harita degerleri (`turAd[t]`), URL kacisli ifadeler
	//	(`encodeURIComponent(q)`) ve ZATEN kacisli HTML parcalari
	//	(`hedef`, `metin`). Hepsi guvenliydi.
	//
	//	Gercek risk DB'den gelen NESNE ALANLARIDIR (`f.name`, `u.ad`,
	//	`s.aciklama`): yalniz onlar kullanici girdisi tasiyabilir.
	//
	// ⚠️ `.dataset.` MUAF: DOM'dan okunur ve URL'e girer (HTML'e degil);
	//	oraya yazilirken zaten `esc()` uygulanmistir.
	re := regexp.MustCompile(
		`'\s*\+\s*((?:[A-Za-z_$][\w$]*\.)+[\w$]+)\s*\+\s*'`)
	// Sayisal olduklari BILINEN alanlar (SQL'de int/bigint): HTML kacisi
	// gerekmez ama listelenmis olmalari GEREKCELIDIR — yeni bir alan
	// eklendiginde bilincli bir karar verilsin.
	sayisal := map[string]bool{
		"s.id": true, "k.coin": true, "k.gonderi_sayisi": true,
		"k.sikayet_sayisi": true, "f.urun_sayisi": true,
		"u.medya_sayisi": true, "s.tekrar": true, "i.sikayet_sayisi": true,
		"s.viewers": true, "s.izleyici": true,
		"f.enlem": true, "f.boylam": true,
	}
	var kotu []string
	for _, m := range re.FindAllStringSubmatch(js, -1) {
		ifade := strings.TrimSpace(m[1])
		if sayisal[ifade] || strings.Contains(ifade, ".dataset.") {
			continue
		}
		kotu = append(kotu, ifade)
	}
	if len(kotu) > 0 {
		sort.Strings(kotu)
		t.Errorf(
			"panel.js su ifadeleri HTML'e HAM basiyor: %v\n"+
				"Bunlar kullanici girdisi olabilir; ham basmak yoneticinin "+
				"OTURUM JETONUNU calan bir XSS'e yol acar.\n"+
				"Cozum: `esc(...)` ile sar; gercekten sayisal ise testteki "+
				"`sayisal` haritasina GEREKCESIYLE ekle.", kotu)
	}
}

// ⚠️⚠️ TURU 181 — PANEL ANAHTARI SORGU PARAMETRESIYLE GONDERMEMELI.
//
// Eski panel `?key=<ADMIN_KEY>` kullaniyordu: anahtar Caddy/Cloudflare
// erisim loglarina, tarayici gecmisine ve `Referer` basligina duser.
// Yeni panel kisa omurlu jetonu **BASLIKLA** gonderir.
//
// ⚠️ YAPMA: panele `?key=` geri koyma.
func TestPanelSorguParametresiKullanmiyor(t *testing.T) {
	js := oku(t, "panel/panel.js")
	// Yorum satirlarini ele: serhlerde ESKI yolu ANLATIYORUZ.
	var kod []string
	for _, l := range strings.Split(js, "\n") {
		t := strings.TrimSpace(l)
		if strings.HasPrefix(t, "*") || strings.HasPrefix(t, "//") ||
			strings.HasPrefix(t, "/*") {
			continue
		}
		kod = append(kod, l)
	}
	govde := strings.Join(kod, "\n")
	if strings.Contains(govde, "key=") {
		t.Error(
			"panel.js icinde `key=` gecen bir istek var.\n" +
				"ADMIN_KEY sorgu parametresiyle gonderilirse erisim loglarina " +
				"ve tarayici gecmisine DUSER. Jeton `X-Admin-Jeton` BASLIGIYLA " +
				"gonderilmeli (bkz. internal/admin/oturum.go).")
	}
	if !strings.Contains(govde, "X-Admin-Jeton") {
		t.Fatal("panel.js `X-Admin-Jeton` basligini HIC kullanmiyor — " +
			"kimlik yolu degistiyse BU TESTI DE guncelle")
	}
}

// ---- yardimcilar ----

func oku(t *testing.T, yol string) string {
	t.Helper()
	b, err := os.ReadFile(yol)
	if err != nil {
		t.Fatalf("%s okunamadi: %v", yol, err)
	}
	return string(b)
}

// panelCagrilari — panel.js icinde gecen `/admin/...` yollarini toplar.
//
// ⚠️ Dinamik parcalar (`+ id +`) NORMALLESTIRILIR: `/admin/isletmeler/' + x`
//
//	-> `/admin/isletmeler`. Karsilastirma KOK YOL uzerinden yapilir cunku
//	chi deseni (`{id}`) ile JS ifadesi birebir eslesemez.
func panelCagrilari(t *testing.T) []string {
	t.Helper()
	js := oku(t, "panel/panel.js")
	// Yorumlari ele — serhler eski yollari anlatiyor.
	var kod []string
	for _, l := range strings.Split(js, "\n") {
		s := strings.TrimSpace(l)
		if strings.HasPrefix(s, "*") || strings.HasPrefix(s, "//") ||
			strings.HasPrefix(s, "/*") {
			continue
		}
		kod = append(kod, l)
	}
	re := regexp.MustCompile(`'(/admin/[a-z_/]*)`)
	gorulen := map[string]bool{}
	var out []string
	for _, m := range re.FindAllStringSubmatch(strings.Join(kod, "\n"), -1) {
		y := kokYol(m[1])
		if y != "" && !gorulen[y] {
			gorulen[y] = true
			out = append(out, y)
		}
	}
	if len(out) == 0 {
		t.Fatal("panel.js icinde hic `/admin/...` cagrisi bulunamadi — " +
			"desen bozulmus olabilir (sessizce gecmesindense DURMASI dogrudur)")
	}
	sort.Strings(out)
	return out
}

// adminRotalari — `cmd/api/main.go` icinde kayitli `/admin/...` yollari.
func adminRotalari(t *testing.T) map[string]bool {
	t.Helper()
	src := oku(t, "../../cmd/api/main.go")
	// Yorum satirlarini ele: serhlerde uc adlari geciyor.
	var kod []string
	for _, l := range strings.Split(src, "\n") {
		s := strings.TrimSpace(l)
		if strings.HasPrefix(s, "//") {
			continue
		}
		kod = append(kod, l)
	}
	re := regexp.MustCompile(`r\.(?:Get|Post|Patch|Delete|Put)\("(/admin/[^"]*)"`)
	out := map[string]bool{}
	for _, m := range re.FindAllStringSubmatch(strings.Join(kod, "\n"), -1) {
		if y := kokYol(m[1]); y != "" {
			out[y] = true
		}
	}
	if len(out) == 0 {
		t.Fatal("main.go icinde hic `/admin/...` rotasi bulunamadi — " +
			"desen bozulmus olabilir")
	}
	return out
}

// kokYol — yolu ilk DEGISKEN parcaya kadar kirpar.
//
//	/admin/isletmeler/{id}/onay -> /admin/isletmeler
//	/admin/icerik/{tur}         -> /admin/icerik
//
// ⚠️ Bu KABA bir eslestirmedir ve BILINCLI: amac "panelde hic cagrilmayan
//
//	uc" ve "kayitli olmayan cagri" sinifini yakalamak; HTTP METODU ya da
//	alt yol farkini olcmek DEGIL. Daha siki bir olcut, JS ifadeleriyle
//	chi desenlerini birebir eslestirmeyi gerektirirdi ve kirilgan olurdu.
func kokYol(y string) string {
	p := strings.Split(strings.Trim(y, "/"), "/")
	if len(p) < 2 || p[0] != "admin" {
		return ""
	}
	return "/admin/" + p[1]
}
