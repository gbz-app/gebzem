package media

import (
	"os"
	"regexp"
	"sort"
	"strings"
	"testing"
)

// ⚠️⚠️⚠️ TURU 181 — MEDYA TABLO KUMESI MUHAFIZI.
//
// ═══════════ NEDEN YAZILDI ═══════════
//
// Bu projede medya baglantilari IKI YERDE sayilir:
//
//	`erisebilir()`     (handler.go) — "bu medyayi KIM gorebilir"
//	`kullanimSayimi`   (kopar.go)   — "bu medya HALA kullaniliyor mu"
//
// Ikisi FARKLI sorular sorar ama AYNI baglanti kumesini taramak ZORUNDADIR.
// Ayrisirlarsa iki yonlu zarar olusur:
//
//	· `erisebilir`te olup `kullanimSayimi`da olmayan tablo -> medya HALA
//	  kullaniliyorken KOPARILIR = **VERI KAYBI** (kirik gorsel).
//	· `kullanimSayimi`da olup `erisebilir`te olmayan tablo -> medya
//	  korunur ama YUKLEYENDEN BASKASINA 403 = **OLU OZELLIK**
//	  (turu 75b akis · 77 hikaye · 78 kapak · 78b grup avatari · 180k
//	  isletme slideri — bu sinif SAHAYA BES KEZ cikti).
//
// ═══════════ TURU 181'DE SAHADA NE BULUNDU ═══════════
//
// `medyayiKopar` UC KOPYAYDI (chat · kanal · social), ucu de FARKLI kume
// sayiyordu ve DORT tablo (stories · isletme_urunleri · ilanlar ·
// etkinlikler) HICBIRINDE yoktu. Ustelik ucu de canli Postgres'te
// `operator does not exist: uuid = text` ile PATLIYOR, hata yutuluyordu.
//
// ⚠️ YAPMA: bu testi silme. Yeni bir medya sutunu eklerken UC yeri birden
//
//	guncelle: `erisebilir()` dali · `kullanimSayimi` · uctan uca kontrolu.
func TestMedyaKumeleriHizali(t *testing.T) {
	kopar := oku(t, "kopar.go")
	handler := oku(t, "handler.go")

	sayim := kume(t, sabitIci(t, kopar, "kullanimSayimi"))
	erisim := kume(t, erisebilirGovdesi(t, handler))

	// ⚠️ `media_assets`in KENDISI iki tarafta da gecer (UPDATE/SELECT);
	//	bir BAGLANTI tablosu degildir, muaf.
	// ⚠️ `media_delete_queue` yalniz `Kopar` icinde, kuyruk tablosu.
	// ⚠️ `follows`/`blocks`/`chat_members` `erisebilir`te GIZLILIK kapisi
	//	icin gecer, medya BAGLANTISI degildir.
	muaf := map[string]bool{
		"media_assets": true, "media_delete_queue": true,
		"follows": true, "blocks": true, "chat_members": true,
		"chat_members cm": true,
	}
	for m := range muaf {
		delete(sayim, m)
		delete(erisim, m)
	}

	eksik := fark(erisim, sayim)
	fazla := fark(sayim, erisim)

	if len(eksik) > 0 {
		t.Errorf(
			"`erisebilir()` su tablolari taniyor ama `kullanimSayimi` SAYMIYOR: %v\n"+
				"Medya HALA kullaniliyorken KOPARILIR -> VERI KAYBI "+
				"(mesaj silinince urun/ilan fotografi gider).\n"+
				"Cozum: kopar.go icindeki `kullanimSayimi` sabitine ekle.",
			eksik)
	}
	if len(fazla) > 0 {
		t.Errorf(
			"`kullanimSayimi` su tablolari sayiyor ama `erisebilir()` TANIMIYOR: %v\n"+
				"Medya korunur ama YUKLEYENDEN BASKASINA 403 doner -> OLU OZELLIK "+
				"(bu sinif sahaya BES kez cikti: turu 75b/77/78/78b/180k).\n"+
				"Cozum: handler.go icindeki `erisebilir()` fonksiyonuna dal ekle.",
			fazla)
	}
}

// ⚠️⚠️ TURU 181 — TIP CAST MUHAFIZI.
//
// `isletmeler.kapak_medyalari` **TEXT[]** (051), diger TUM medya sutunlari
// **UUID**. Ayni sorguda `$1` once bir uuid sutunuyla karsilastirilirsa
// Postgres parametreyi UUID cikarsar ve sonraki `$1 = ANY(text[])`
// karsilastirmasi **`operator does not exist: uuid = text`** verir —
// yani TUM SORGU patlar.
//
// Bu, turu 113'un `favorim` hatasinin BIREBIR tekrariydi ve turu 181'de
// canli Postgres'te olculdu. Koruma: `kullanimSayimi` icindeki HER `$1`
// ACIKCA cast edilmis olmali.
//
// ⚠️ YAPMA: sabitten `::uuid` / `::text` cast'lerini kaldirma.
func TestKullanimSayimiCastliParametreKullanir(t *testing.T) {
	ham := sabitIci(t, oku(t, "kopar.go"), "kullanimSayimi")
	// Cast'siz `$1` arayan desen: `$1` ardindan `::` GELMIYORSA yakalar.
	ciplak := regexp.MustCompile(`\$1(?:::)?`)
	for _, e := range ciplak.FindAllString(ham, -1) {
		if e == "$1" {
			t.Fatalf(
				"`kullanimSayimi` icinde CAST'SIZ bir `$1` var.\n"+
					"`isletmeler.kapak_medyalari` TEXT[], digerleri UUID; "+
					"cast'siz parametre Postgres'te `operator does not exist: "+
					"uuid = text` verir ve SORGUNUN TAMAMI patlar "+
					"(turu 113 ve turu 181'de IKI KEZ sahaya cikti).\n"+
					"Her kullanimda `$1::uuid` ya da `$1::text` yaz.")
		}
	}
}

// ⚠️⚠️ TURU 181 — UC KOPYA GERI GELMESIN.
//
// `medyayiKopar` chat/kanal/social paketlerinde AYRI AYRI yaziliydi ve
// AYRISMISTI. Govdeleri `media.Kopar`a devredildi; bu test kopyalarin
// KENDI SAYIMLARINI geri yazmadigini kilitler.
//
// ⚠️ Test `media` paketinde ama KARDES paketlerin kaynagini okur — bu
//
//	bilincli: kural MEDYA tarafina ait ve tek yerde durmali.
func TestMedyayiKoparKopyalariSayimYapmaz(t *testing.T) {
	for _, yol := range []string{
		"../chat/handler.go", "../kanal/handler.go", "../social/handler.go",
	} {
		b, err := os.ReadFile(yol)
		if err != nil {
			t.Fatalf("%s okunamadi: %v", yol, err)
		}
		govde := medyayiKoparGovdesi(t, string(b), yol)
		if strings.Contains(govde, "SELECT") || strings.Contains(govde, "count(*)") {
			t.Errorf(
				"%s icindeki `medyayiKopar` KENDI SAYIMINI yapiyor.\n"+
					"Sayim TEK KAYNAK olmali (`internal/media/kopar.go`); "+
					"uc kopya turu 181'de AYRISMIS ve UCU DE BOZUK bulundu.\n"+
					"Govde yalnizca `media.Kopar(...)` cagirmali.", yol)
		}
		if !strings.Contains(govde, "media.Kopar(") {
			t.Errorf("%s icindeki `medyayiKopar` `media.Kopar` CAGIRMIYOR — "+
				"medya hic koparilmaz (sessiz depolama sizintisi).", yol)
		}
	}
}

// ---- yardimcilar ----

func oku(t *testing.T, ad string) string {
	t.Helper()
	b, err := os.ReadFile(ad)
	if err != nil {
		t.Fatalf("%s okunamadi: %v", ad, err)
	}
	return string(b)
}

// sabitIci — `const <ad> = ` ardindaki ham dizenin ICINI dondurur.
func sabitIci(t *testing.T, kaynak, ad string) string {
	t.Helper()
	i := strings.Index(kaynak, "const "+ad+" = ")
	if i < 0 {
		t.Fatalf("`%s` sabiti bulunamadi — yeniden adlandirildiysa BU TESTI DE guncelle", ad)
	}
	a := strings.Index(kaynak[i:], "`")
	if a < 0 {
		t.Fatalf("`%s` ham dizesi ayristirilamadi", ad)
	}
	b := strings.Index(kaynak[i+a+1:], "`")
	if b < 0 {
		t.Fatalf("`%s` ham dizesi kapanmamis", ad)
	}
	return kaynak[i+a+1 : i+a+1+b]
}

// erisebilirGovdesi — `func (h *Handler) erisebilir(` govdesini dondurur.
//
// ⚠️ Ayristirilamazsa `t.Fatal` ile DURUR. Sessizce gecen bir muhafiz,
//
//	olmayan bir muhafizdan KOTUDUR (turu 93b dersi).
func erisebilirGovdesi(t *testing.T, kaynak string) string {
	t.Helper()
	i := strings.Index(kaynak, ") erisebilir(")
	if i < 0 {
		t.Fatal("`erisebilir(` bulunamadi — yeniden adlandirildiysa BU TESTI DE guncelle")
	}
	return blokAl(t, kaynak, i)
}

func medyayiKoparGovdesi(t *testing.T, kaynak, yol string) string {
	t.Helper()
	i := strings.Index(kaynak, ") medyayiKopar(")
	if i < 0 {
		t.Fatalf("%s icinde `medyayiKopar(` bulunamadi — yeniden "+
			"adlandirildiysa BU TESTI DE guncelle", yol)
	}
	return blokAl(t, kaynak, i)
}

// blokAl — verilen konumdan sonraki ilk `{` ile eslesen `}` arasini dondurur.
func blokAl(t *testing.T, kaynak string, i int) string {
	t.Helper()
	j := strings.Index(kaynak[i:], "{")
	if j < 0 {
		t.Fatal("govde acilis parantezi bulunamadi")
	}
	j += i
	d := 0
	for k := j; k < len(kaynak); k++ {
		switch kaynak[k] {
		case '{':
			d++
		case '}':
			d--
			if d == 0 {
				return kaynak[j : k+1]
			}
		}
	}
	t.Fatal("govde kapanis parantezi bulunamadi")
	return ""
}

// kume — SQL metnindeki `FROM <tablo>` adlarini toplar.
//
// ⚠️ Takma adlar (`posts p`) ATILIR: kume karsilastirmasi TABLO ADIYLA
//
//	yapilir, yoksa `posts p` ile `posts` ayri sayilirdi.
func kume(t *testing.T, sql string) map[string]bool {
	t.Helper()
	re := regexp.MustCompile(`(?i)\bFROM\s+([a-z_][a-z0-9_]*)`)
	out := map[string]bool{}
	for _, m := range re.FindAllStringSubmatch(sql, -1) {
		out[strings.ToLower(m[1])] = true
	}
	if len(out) == 0 {
		t.Fatal("hic tablo adi ayristirilamadi — desen bozulmus olabilir")
	}
	return out
}

func fark(a, b map[string]bool) []string {
	var out []string
	for k := range a {
		if !b[k] {
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out
}
