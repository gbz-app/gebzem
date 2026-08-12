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
	return govdeAl(t, "func (h *Handler) Detay(")
}

// ⚠️⚠️⚠️ TURU 93 — GOVDE CIKARMA GENELLESTIRILDI.
//
// Eskiden bu is YALNIZ `Detay` icin yaziliydi. Turu 93'te `Liste` sorgusuna
// `u.kapak_media_id` eklendi ve **muhafiz onu GORMEDI**: yanit haritasindan
// alan CIKARILIP test kosuldu, test **YESIL GECTI**. Yani muhafiz duruyordu
// ama olcmedigi bir yuzey vardi.
// ⚠️ DERS (turu 89'un tekrari): bir muhafizin YESIL olmasi, DEGISTIRDIGIN
//    YUZEYI olctugu anlamina GELMEZ. Yeni sutun eklerken once "bu sorgu
//    muhafizin KAPSAMINDA mi" diye sor.
func govdeAl(t *testing.T, imza string) string {
	t.Helper()
	b, err := os.ReadFile("handler.go")
	if err != nil {
		t.Fatalf("handler.go okunamadi: %v", err)
	}
	src := string(b)
	i := strings.Index(src, imza)
	if i < 0 {
		t.Fatalf("%q bulunamadi — yeniden adlandirildiysa BU TESTI DE guncelle", imza)
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

// ⚠️⚠️⚠️ TURU 93 — ISLETME **LISTE** SORGUSU DA KAPSAMA ALINDI.
//
// Bu, isletme rehberini ve kategori ekranini besleyen sorgu. Turu 93 kartlari
// 16:9 kapak cizdigi icin `u.kapak_media_id` eklendi.
//
// ⚠️ NEDEN AYRI BIR TEST: `Liste` govdesinde `if rows.Scan(...) != nil {
//    continue }` var — yani hata **YUTULUYOR**. SELECT ile Scan sayisi
//    ayrisirsa HER SATIR SESSIZCE ATLANIR: derleme temiz gecer, log dusmez,
//    ve isletme rehberi **HERKESTE BOMBOS** gorunur. Kullaniciya bu, "hic
//    isletme yok" gibi gorunur — bir hata gibi DEGIL.
//
// ⚠️ Yanit haritasi kontrolu de ZORUNLU: Scan calisir, derleyici susar, alan
//    istemciye HIC ULASMAZ ve kartlar sessizce gradyan yer tutucuya duser.
//    Bu sinif projede DORT KEZ sahaya cikti.
func TestListeSelectScanVeYanitHizali(t *testing.T) {
	govde := govdeAl(t, "func (h *Handler) Liste(")

	// ⚠️⚠️ ALT SORGU FARKINDALIGI: duz `SELECT ... FROM` regexi, sutun
	//	listesindeki bir ALT SORGUNUN `FROM`unda kesiliyordu ve sutunlari
	//	EKSIK sayiyordu. Turu 93c'de `min(fiyat_kurus)` alt sorgusu eklenince
	//	test "13 sutun ama 14 Scan" diye YANLIS ALARM verdi.
	//	⚠️ Yine de DOGRU davrandi: ayristiramadiginda GECMEK yerine DURDU.
	//	   Sessizce gecen bir muhafiz, olmayan muhafizdan KOTUDUR.
	//	Dis `FROM` **parantez derinligi 0**da olandir.
	selBas := strings.Index(govde, "SELECT")
	if selBas < 0 {
		t.Fatal("Liste icinde SELECT bulunamadi")
	}
	govdeSel := govde[selBas+len("SELECT"):]
	d, fromIdx := 0, -1
	for i := 0; i+4 <= len(govdeSel); i++ {
		switch govdeSel[i] {
		case '(':
			d++
		case ')':
			d--
		}
		if d == 0 && strings.HasPrefix(govdeSel[i:], "FROM") {
			fromIdx = i
			break
		}
	}
	if fromIdx < 0 {
		t.Fatal("Liste icinde dis FROM bulunamadi — sorgu yapisi degistiyse " +
			"BU AYRISTIRICIYI DA guncelle")
	}

	// Parantez derinligi tutulur — COALESCE(u.username,'') icindeki virgul
	// sutun ayirici DEGILDIR.
	var sutunlar []string
	derinlik, son := 0, 0
	ham := govdeSel[:fromIdx]
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

	// ⚠️ Desen HEM `rows.Scan(...) != nil` HEM `if e := rows.Scan(...); e != nil`
	//    bicimini yakalar. Turu 93b'de hata loglanmak icin ikinci bicime
	//    gecildi ve dar desen ESLESMEYI KAYBETTI — ama test SESSIZCE
	//    GECMEDI, `t.Fatal` ile DURDU. Ayristiramadiginda GECEN bir muhafiz,
	//    olmayan bir muhafizdan KOTUDUR (yanlis guven verir).
	scan := regexp.MustCompile(`(?s)rows\.Scan\((.*?)\)\s*;?\s*e?\s*!=\s*nil`).
		FindStringSubmatch(govde)
	if scan == nil {
		t.Fatal("Liste icinde rows.Scan(...) bulunamadi — yazim degistiyse " +
			"BU DESENI DE guncelle (sessizce gecmesindense DURMASI dogrudur)")
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
			"SELECT %d sutun donduruyor ama Scan %d alan bekliyor — "+
				"HER SATIR SESSIZCE ATLANIR (rehber BOMBOS gorunur).\nSELECT: %v",
			len(sutunlar), len(hedefler), sutunlar)
	}
	if len(sutunlar) < 9 {
		t.Fatalf("SELECT beklenenden kisa (%d) — ayristirma bozulmus olabilir",
			len(sutunlar))
	}

	// ⚠️⚠️⚠️ TURU 93b — **SIRA DA OLCULUR** (denetim: kardes `Detay` testi
	//	bunu yapiyordu, turu 93'te yazdigim `Liste` testi YAPMIYORDU).
	//
	//	SAYI esitligi TEK BASINA YETMEZ: `i.il`, `i.ilce`, `i.adres` UCU DE
	//	TEXT ve YAN YANA. Yer degistirseler Postgres **HATA VERMEZ** —
	//	degerler SESSIZCE TAKAS olur ve isletme rehberinde sehir ile ilce
	//	yer degistirir. Sutun sayisi degismedigi ve anahtarlar yanitta
	//	durdugu icin eski test **YESIL KALIRDI**.
	//
	// ⚠️ `Liste`de degisken adlari sutunlardan FARKLI (`ad` <- `u.name`),
	//    bu yuzden istisna haritasi ZORUNLU. Uymayanlar burada ACIKCA
	//    listelenir — bilincli sapmalar gorunur kalir.
	// ⚠️ ALT SORGULAR: adlari sutundan turetilemez, ACIKCA yazilir. Anahtar
	//    alt sorgunun ILK SATIRIYLA eslestirilir (govde cok satirli).
	altSorgu := map[string]string{
		"min(p.fiyat_kurus)": "minFiyat",
		"count(*)":           "urunSayisi",
	}
	scanIstisna := map[string]string{
		"u.name":                  "ad",
		"COALESCE(u.username,'')": "kullanici",
		"u.avatar_url":            "avatar",
		"u.avatar_media_id":       "medya",
		"i.kategori":              "kat",
		"i.il":                    "il2",
		"u.onayli":                "dogru",
		"u.kapak_media_id":        "kapak",
		// ⚠️ Degisken adinda "dk" eki YOK; sutunda VAR. Bilincli sapma.
		"i.teslimat_dk_min": "teslimatMin",
		"i.teslimat_dk_max": "teslimatMax",
	}
	for i, s := range sutunlar {
		bekle, ok := scanIstisna[s]
		if !ok {
			for imza, hedef := range altSorgu {
				if strings.Contains(s, imza) {
					bekle, ok = hedef, true
					break
				}
			}
		}
		if !ok {
			bekle = s
			if k := strings.LastIndex(bekle, "."); k >= 0 {
				bekle = bekle[k+1:]
			}
		}
		// ⚠️ camelCase Scan degiskeni (`minTutar`) ile snake_case sutun
		//    (`min_tutar_kurus`) esittir: karsilastirma YILAN-HARFE cevrilir.
		//    Aksi halde her yeni sutun icin `scanIstisna`ya elle satir
		//    yazmak gerekirdi ve unutuldugunda test YANLIS ALARM verirdi.
		// ⚠️ Onek eslesmesi (`min_tutar` <- `min_tutar_kurus`) KABUL EDILIR:
		//    degisken adi genelde birim ekini tasimaz.
		hedefYilan := yilanla(hedefler[i])
		uyar := hedefler[i] != bekle &&
			hedefYilan != bekle &&
			!strings.HasPrefix(bekle, hedefYilan+"_") &&
			!strings.HasPrefix(hedefYilan, bekle+"_")
		if uyar {
			t.Errorf(
				"SIRA BOZUK — %d. sutun `%s` ama %d. Scan hedefi `%s` "+
					"(beklenen `%s`).\nAyni tipteki iki sutun yer degistirirse "+
					"Postgres HATA VERMEZ; degerler SESSIZCE TAKAS olur "+
					"(or. il <-> ilce).\nBilincli bir sapmaysa `scanIstisna`ya ekle.",
				i+1, s, i+1, hedefler[i], bekle)
		}
	}

	// ── YANIT HARITASI (`out = append(out, map[string]any{...})`) ──
	yanit := regexp.MustCompile(`(?s)out\s*=\s*append\(out,\s*map\[string\]any\{(.*?)\}\)`).
		FindStringSubmatch(govde)
	if yanit == nil {
		t.Fatal("Liste yanit haritasi bulunamadi")
	}

	// SELECT sutunu -> beklenen JSON anahtari. Uymayanlar ACIKCA yazili;
	// boylece bilincli sapmalar gorunur kalir.
	istisna := map[string]string{
		"COALESCE(u.username,'')": "username",
		"u.onayli":                "dogrulandi",
	}
	// ⚠️ Alt sorgularin JSON anahtari sutundan turetilemez — ACIKCA yazilir.
	altAnahtar := map[string]string{
		"min(p.fiyat_kurus)": "min_fiyat_kurus",
		"count(*)":           "urun_sayisi",
	}
	for _, s := range sutunlar {
		anahtar, ok := istisna[s]
		if !ok {
			for imza, a := range altAnahtar {
				if strings.Contains(s, imza) {
					anahtar, ok = a, true
					break
				}
			}
		}
		if !ok {
			anahtar = s
			if k := strings.LastIndex(anahtar, "."); k >= 0 {
				anahtar = anahtar[k+1:]
			}
		}
		if !strings.Contains(yanit[1], `"`+anahtar+`"`) {
			t.Errorf(
				"`%s` SELECT+Scan ediliyor ama YANIT HARITASINDA YOK (beklenen `%q`).\n"+
					"Alan istemciye HIC ULASMAZ; kart sessizce yer tutucuya duser.\n"+
					"Bilincli bir sapmaysa `istisna` haritasina ekle.", s, anahtar)
		}
	}
}

// ⚠️⚠️⚠️ TURU 89 — URUN SORGUSU DA KAPSAMA ALINDI.
//
// `urunSutunlari` (SELECT) ile `urunleriOku` (Scan) BIREBIR ayni sirada
// olmak ZORUNDA. Govdede `if rows.Scan(...) != nil { continue }` var, yani
// hata **YUTULUYOR**: sira ayrisirsa HER SATIR SESSIZCE ATLANIR, derleme
// temiz gecer, log dusmez ve **KATALOG HERKESTE BOMBOS** gorunur.
// Turu 76'da "Kaydedilenler" sayfasi tam bu sekilde bosalmisti.
//
// ⚠️ Bu test turu 89'da `tur` + `ozellikler` eklenirken yazildi: iki sutun
//
//	UC YERE (SELECT · Scan · yanit haritasi) birlikte eklenmeliydi.
func TestUrunSelectVeScanHizali(t *testing.T) {
	govde := yorumsuzKaynak(t, "urun.go")

	sel := regexp.MustCompile("(?s)const urunSutunlari = `(.*?)`").
		FindStringSubmatch(govde)
	if sel == nil {
		t.Fatal("urunSutunlari sabiti bulunamadi")
	}
	var sutunlar []string
	for _, p := range strings.Split(sel[1], ",") {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		// "p.fiyat_kurus" -> "fiyat_kurus"
		if i := strings.LastIndex(p, "."); i >= 0 {
			p = p[i+1:]
		}
		sutunlar = append(sutunlar, strings.TrimSpace(p))
	}

	scan := regexp.MustCompile(`(?s)rows\.Scan\((.*?)\)\s*!=\s*nil`).
		FindStringSubmatch(govde)
	if scan == nil {
		t.Fatal("urunleriOku icinde rows.Scan(...) bulunamadi")
	}
	var tarananlar []string
	for _, p := range strings.Split(scan[1], ",") {
		ad := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(p), "&"))
		if ad != "" {
			tarananlar = append(tarananlar, ad)
		}
	}

	if len(sutunlar) != len(tarananlar) {
		t.Fatalf(
			"SELECT %d sutun donduruyor ama Scan %d alan bekliyor.\n"+
				"Sira/sayi ayrisirsa `rows.Scan` hata doner, `continue` onu YUTAR "+
				"ve KATALOG HERKESTE BOMBOS gorunur (turu 76 sinifi).\n"+
				"SELECT: %v\nScan  : %v",
			len(sutunlar), len(tarananlar), sutunlar, tarananlar)
	}

	// Yanit haritasinda her sutunun karsiligi olmali (turu 78 sinifi).
	yanit := regexp.MustCompile(`(?s)out = append\(out, map\[string\]any\{(.*?)\}\)`).
		FindStringSubmatch(govde)
	if yanit == nil {
		t.Fatal("urunleriOku yanit haritasi bulunamadi")
	}
	for _, s := range sutunlar {
		if !strings.Contains(yanit[1], `"`+s+`"`) {
			t.Errorf(
				"`%s` SELECT+Scan ediliyor ama YANIT HARITASINDA YOK — "+
					"alan istemciye HIC ULASMAZ (turu 78 sinifi).", s)
		}
	}
}

// Bir kaynak dosyayi YORUMLARDAN TEMIZLEYEREK okur.
//
// ⚠️ Yorum temizligi ZORUNLU: bu paketin serhleri "SELECT sirasi ile Scan
//
//	sirasi BIREBIR" gibi cumleler iceriyor ve ayristirici onlari GERCEK
//	sorgu sanip YANLIS ALARM veriyordu (turu 80b'de tam bu oldu; turu 83'te
//	`utf8_test.go` ayni tuzaga dustu).
func yorumsuzKaynak(t *testing.T, dosya string) string {
	t.Helper()
	b, err := os.ReadFile(dosya)
	if err != nil {
		t.Fatalf("%s okunamadi: %v", dosya, err)
	}
	var temiz []string
	for _, satir := range strings.Split(string(b), "\n") {
		k := strings.TrimSpace(satir)
		if strings.HasPrefix(k, "//") || strings.HasPrefix(k, "--") {
			continue
		}
		temiz = append(temiz, satir)
	}
	return strings.Join(temiz, "\n")
}
