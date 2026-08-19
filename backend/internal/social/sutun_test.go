package social

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// ⚠️⚠️ TURU 76 — SUTUN SIRASI MUHAFIZI (gercek bir sevk engelinden dogdu).
//
// `satirlariOku` TEK bir `rows.Scan(...)` ile YEDI ayri sorgunun sonucunu okur.
// Sorguya bir sutun eklenip Scan'e eklenmezse (ya da tersi) **DERLEME HATASI
// OLMAZ**: `Scan` hata doner, dongu `continue` eder ve o uc **BOS LISTE**
// dondurur — sessizce.
//
// TURU 76'da tam bu oldu: `media_kinds` + `duzenlendi_at` alti sorguya eklendi,
// YEDINCISI (`Kaydedilenler`, etkilesim.go) ATLANDI. Sonuc: "Kaydedilenler"
// sayfasi HERKESTE BOMBOS gorunecekti ve hicbir log/olcum dusmeyecekti.
// Statik denetimle build ONCESI yakalandi.
//
// Bu test kaynagi OKUYARAK dogrular; bir gelistirici yeni bir gonderi sorgusu
// eklerse ya da sutun eklerse BURADAN geri bildirim alir.
//
// ⚠️ YAPMA: bu testi silme. Yeni sutun eklerken `beklenenSutunlar`i ve
//
//	`satirlariOku`daki Scan'i BIRLIKTE guncelle.
var beklenenSutunlar = []string{
	"p.id", "p.author_id", "p.tur", "p.metin", "p.media_ids",
	"p.begeni_sayisi", "p.yorum_sayisi", "p.goruntulenme",
	"MEDIA_KINDS", "MEDIA_BOYUT", "p.duzenlendi_at", "p.yayin_at",
	// ⚠️ TURU 90 — GONDERIDE KONUM. Uc sutun `medyaTurleri` SABITINE eklendi,
	//    yani YEDI sorgu da otomatik aldi; burasi da guncellendi.
	"p.konum_ad", "p.enlem", "p.boylam",
	"p.yorum_kapali", "p.created_at",
	"u.name", "USERNAME", "u.avatar_url", "u.avatar_media_id",
	"BEGENDIM", "KAYDETTIM",
}

func TestGonderiSorgulariScanIleUyumlu(t *testing.T) {
	kaynak := ""
	// ⚠️⚠️⚠️ TURU 114 — **MUHAFIZ KORDU** (denetimde yakalandi).
	//
	//	Yeni gonderi sorgulari BASKA DOSYALARA yazilabiliyor; bu liste
	//	yalniz iki dosyayi taradigi icin `mahalle.go`daki sorgu HIC
	//	olculmuyordu. SELECT/Scan ayrisirsa `satirlariOku` her satiri
	//	SESSIZCE atlar ve **Mahalle bolmesi BOMBOS** gorunurdu — turu 76
	//	"Kaydedilenler BOMBOS" hatasinin birebir tekrari.
	// ⚠️ YAPMA: yeni bir gonderi sorgusu yazip bu listeye eklemeyi atlama.
	for _, f := range []string{"handler.go", "etkilesim.go", "mahalle.go", "ara.go"} {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatalf("%s okunamadi: %v", f, err)
		}
		kaynak += strings.ReplaceAll(string(b), "\r\n", "\n")
	}
	// ⚠️ TURU 90 — SQL yorumlari ATILIR (bkz. `sqlYorumsuz` serhi): sorgu
	//    sabitine aciklama yazmak dogaldir ama ayristirici sutunlari virgulle
	//    boldugu icin yorum BIR SONRAKI sutun adina yapisir ve YANLIS ALARM
	//    verir.
	kaynak = sqlYorumsuz(kaynak)

	// Go sabitlerini yerine koy: sorgular `...`+medyaTurleri+`...` seklinde kuruluyor.
	kaynak = strings.ReplaceAll(kaynak, "`+medyaTurleri+`", medyaTurleri)
	kaynak = strings.ReplaceAll(kaynak, "`+engelYok+`", engelYok)
	// engel.Yuklem(...) cagrilari sutun listesini ETKILEMEZ (WHERE'de) — sadeleştir.
	kaynak = regexp.MustCompile("`\\+engel\\.Yuklem\\([^)]*\\)\\+`").
		ReplaceAllString(kaynak, " AND TRUE")

	bulunan := 0
	for i := 0; ; {
		j := strings.Index(kaynak[i:], "SELECT p.id, p.author_id")
		if j < 0 {
			break
		}
		bas := i + j
		i = bas + 10

		govde := kaynak[bas:]
		son := ustDuzeydeFrom(govde)
		if son < 0 {
			t.Errorf("sorgu #%d: ust duzey FROM bulunamadi", bulunan+1)
			continue
		}
		bulunan++
		sutunlar := ustDuzeydeAyir(govde[len("SELECT "):son])
		if len(sutunlar) != len(beklenenSutunlar) {
			t.Errorf("sorgu #%d: %d sutun var, Scan %d bekliyor\n%v",
				bulunan, len(sutunlar), len(beklenenSutunlar), sutunlar)
			continue
		}
		for k, s := range sutunlar {
			if !sutunEslesir(s, beklenenSutunlar[k]) {
				t.Errorf("sorgu #%d sutun %d: %q ama Scan %q bekliyor",
					bulunan, k, s, beklenenSutunlar[k])
			}
		}
	}
	// ⚠️ Sorgu sayisi DUSERSE de haber ver: biri sorguyu silmis ya da bicimini
	//    degistirmis olabilir (bu test onu bir daha goremezdi = sessiz korluk).
	if bulunan < 8 {
		t.Errorf("yalniz %d gonderi sorgusu tarandi; en az 8 bekleniyordu "+
			"(Akis x2, Kesfet, UserPosts, Detay, Reels, Kaydedilenler, Mahalle)",
			bulunan)
	}
}

// Alt sorgulardaki FROM'lari atlayarak ust duzey FROM'un konumunu bulur.
func ustDuzeydeFrom(s string) int {
	derinlik := 0
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '(':
			derinlik++
		case ')':
			derinlik--
		}
		if derinlik == 0 && (strings.HasPrefix(s[i:], "FROM posts p") ||
			strings.HasPrefix(s[i:], "FROM post_saves")) {
			return i
		}
	}
	return -1
}

func ustDuzeydeAyir(liste string) []string {
	out := []string{}
	derinlik, bas := 0, 0
	for i := 0; i < len(liste); i++ {
		switch liste[i] {
		case '(':
			derinlik++
		case ')':
			derinlik--
		case ',':
			if derinlik == 0 {
				out = append(out, strings.TrimSpace(liste[bas:i]))
				bas = i + 1
			}
		}
	}
	if son := strings.TrimSpace(liste[bas:]); son != "" {
		out = append(out, son)
	}
	return out
}

// TURU 90 - SQL yorumlarini (--) atar.
//
// Sorgu sabitlerine aciklama yazmak DOGALDIR; ayristirici sutunlari
// virgulle boldugu icin yorum satiri BIR SONRAKI sutun adina YAPISIR ve
// test YANLIS ALARM verir (bu tuzak turu 80b sutun_test.go ve turu 83
// utf8_test.go'da da yasandi).
func sqlYorumsuz(s string) string {
	var b []string
	for _, satir := range strings.Split(s, "\n") {
		if i := strings.Index(satir, "--"); i >= 0 {
			satir = satir[:i]
		}
		b = append(b, satir)
	}
	return strings.Join(b, "\n")
}

func sutunEslesir(gercek, beklenen string) bool {
	d := strings.Join(strings.Fields(gercek), " ")
	switch beklenen {
	case "MEDIA_KINDS":
		return strings.Contains(d, "array_agg(COALESCE(ma.kind")
	// ⚠️ TURU 81 — medya OLCUSU ("WxH"). `ma.width` ile eslestiriyoruz;
	//    `ma.kind` ile karismasin diye AYRI dal.
	case "MEDIA_BOYUT":
		return strings.Contains(d, "array_agg(COALESCE(ma.width")
	case "USERNAME":
		return strings.Contains(d, "u.username")
	case "BEGENDIM":
		return strings.Contains(d, "post_likes")
	case "KAYDETTIM":
		// ⚠️ `Kaydedilenler` ucunda sabit `true` — tanim geregi hepsi kayitli.
		return strings.Contains(d, "post_saves") || d == "true"
	default:
		return d == beklenen
	}
}
