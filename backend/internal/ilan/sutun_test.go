package ilan

import (
	"errors"
	"os"
	"strings"
	"testing"

	"github.com/gbz-app/gebzem/backend/internal/sutunkontrol"
)

// ⚠️⚠️ SUTUN/SCAN MUHAFIZI — bkz. internal/sutunkontrol paket serhi.
//
// Turu 76'da `social` paketinde bu sinif hata SEVK ENGELI oldu: sorguya sutun
// eklendi, `Scan`e eklenmedi, `rows.Scan` sessizce hata dondu, dongu `continue`
// etti ve sayfa **BOMBOS** gorundu — derleme hatasi YOK, log YOK.
//
// Turu 78'de `ilanlar` sorgusuna `duzenlendi_at` ve `media_kinds` eklenecek;
// muhafiz ONCE yaziliyor ki o degisiklikte sessiz bosalma olmasin.
//
// ⚠️ YAPMA: bu testi silme.
func TestIlanSutunlariScanIleUyumlu(t *testing.T) {
	b, err := os.ReadFile("handler.go")
	if err != nil {
		t.Fatalf("handler.go okunamadi: %v", err)
	}
	kaynak := string(b)

	sutun, err := sutunkontrol.SutunSayisi(kaynak, "sutunlar")
	if err != nil {
		t.Fatalf("sutun sayilamadi: %v", err)
	}
	scan, err := sutunkontrol.ScanSayisi(kaynak)
	if err != nil {
		t.Fatalf("scan sayilamadi: %v", err)
	}
	if sutun != scan {
		t.Fatalf("SUTUN/SCAN UYUSMAZLIGI: `const sutunlar` %d oge, "+
			"`rows.Scan` %d arguman.\n"+
			"Bu uyusmazlik DERLENIR ama calisma aninda HER SATIR sessizce "+
			"atlanir ve ilan listesi BOMBOS doner.", sutun, scan)
	}

	// ⚠️ `sutunlar` sabitini KULLANMAYAN bir SELECT eklenmis mi?
	//    Elle kopyalanan bir SELECT bu muhafizin DISINDA kalir (turu 76'da
	//    yedinci sorgu tam boyle atlanmisti).
	elleSelect := strings.Count(kaynak, "SELECT i.id")
	if elleSelect > 0 {
		t.Fatalf("ELLE YAZILMIS %d adet `SELECT i.id` var — `sutunlar` "+
			"sabitini kullanmayan sorgu muhafizin DISINDA kalir", elleSelect)
	}
}

// ⚠️⚠️⚠️ TURU 91 — MUHAFIZ `basvuru.go`YA GENISLETILDI.
//
// ═══════════ NEDEN ═══════════
//
// Ustteki test YALNIZCA `handler.go`yu okuyor. Turu 90'da acilan bes basvuru
// ucunun SORGULARI `basvuru.go`da ve **muhafizin TAMAMEN DISINDAYDI**. Turu
// 91 o sorgulara `fiyat_kurus` + `guncellendi_at` ekliyor; koruma olmadan
// klasik sessiz bosalma yeniden mumkun olurdu:
//
//	SELECT 10 sutun  ·  rows.Scan 8 arguman  ->  Scan HATA doner
//	                                         ->  `continue`
//	                                         ->  HER SATIR ATLANIR
//	                                         ->  "Gelen teklifler" BOMBOS
//
// `go build` + `go vet` UCU DE TEMIZ gecer, log DUSMEZ.
//
// ⚠️ IKINCI KONTROL (turu 78 `Profile()` sinifi): Scan EDILIP yanit
//
//	haritasina KONMAYAN alan. Orada kapak fotografi ve onayli rozeti tam
//	boyle "kayboldu": sutun SELECT ediliyor, Scan kosuyor, ama elle kurulan
//	`map[string]any`e YAZILMIYOR. Derleyici goremez (Scan'in yan etkisi var,
//	degisken "kullaniliyor" sayilir).
//
// ⚠️ YAPMA: bu testi silme. `basvuru.go`ya sorgu eklerken SELECT + Scan +
//
//	yanit haritasi UCUNU BIRLIKTE guncelle.
func TestBasvuruSutunlariScanIleUyumlu(t *testing.T) {
	b, err := os.ReadFile("basvuru.go")
	if err != nil {
		t.Fatalf("basvuru.go okunamadi: %v", err)
	}
	// ⚠️ YORUMLAR TEMIZLENIR: serhlerdeki ornek SQL/alan adlari ayristiriciyi
	//    yaniltir (turu 80b `isletme/sutun_test.go` ve turu 83 `utf8_test.go`
	//    tuzagi — ikisi de ILK YAZIMDA yanlis alarm verdi).
	kaynak := sutunkontrol.YorumsuzGo(string(b))

	vakalar := []struct {
		fon     string // fonksiyon adi (raporda gorunur)
		bas     string // SELECT'in bulundugu benzersiz cengel
		alanlar []string
	}{
		{"Basvurular", "FROM ilan_basvurular b\n\t\t  JOIN users u",
			[]string{"id", "user_id", "name", "username", "avatar_media_id",
				"not", "durum", "created_at", "fiyat_kurus", "guncellendi_at"}},
		{"Basvurularim", "FROM ilan_basvurular b\n\t\t  JOIN ilanlar i",
			[]string{"id", "ilan_id", "baslik", "durum", "created_at",
				"fiyat_kurus"}},
	}

	for _, v := range vakalar {
		if !strings.Contains(kaynak, v.bas) {
			t.Errorf("%s: sorgu cengeli BULUNAMADI (%q).\n"+
				"Sorgu yeniden yazildiysa bu muhafizin CENGELI DE "+
				"guncellenmeli — yoksa test SESSIZCE hicbir sey olcmez "+
				"(turu 89 dersi: yesil olmasi olctugu anlamina gelmez).",
				v.fon, v.bas)
			continue
		}
		// ⚠️⚠️ ARAMA **FONKSIYON GOVDESINDE** yapilir, DOSYA GENELINDE DEGIL.
		//
		//    Ilk yazimda dosya genelinde araniyordu ve muhafiz YANLIS-YESILDI:
		//    `fiyat_kurus` YALNIZCA `Basvurular`in yanit haritasindan
		//    silindiginde test YINE DE GECIYORDU — cunku `Basvurularim`da
		//    ayni anahtar duruyordu. AMPIRIK OLARAK olculdu (alan cikarildi,
		//    test yesil kaldi) ve bu yuzden govde bazina cevrildi.
		//    ⚠️ Bu, muhafizin kendisinin turu 89'daki hataya dusmesiydi:
		//       "yesil olmasi GERCEKTEN OLCTUGU anlamina gelmez".
		govde, err := govdeAl(kaynak, v.fon)
		if err != nil {
			t.Errorf("%s: govde bulunamadi: %v", v.fon, err)
			continue
		}
		for _, alan := range v.alanlar {
			if !strings.Contains(govde, `"`+alan+`":`) {
				t.Errorf("%s: `%s` alani YANIT HARITASINDA YOK.\n"+
					"Sutun SELECT edilip Scan ediliyor olabilir ama istemciye "+
					"HIC ULASMAZ — derleyici bunu GOREMEZ (turu 78 `Profile()` "+
					"sinifi: kapak + onayli rozeti tam boyle kayboldu).",
					v.fon, alan)
			}
		}
	}

	// ⚠️ SELECT/Scan karsilastirmasi **FONKSIYON GOVDESI BAZINDA** yapilir,
	//    dosya genelinde DEGIL. Dosya genelinde saymak, `EXISTS(SELECT 1 ...)`
	//    ve `QueryRow` gibi Scan'siz/farkli yapilar yuzunden listeleri
	//    hizalayamiyor ve muhafiz SUREKLI "eslestirme yapilamiyor" diyordu —
	//    yani KAPATILAN bir muhafiz olurdu.
	for _, v := range vakalar {
		govde, err := govdeAl(kaynak, v.fon)
		if err != nil {
			t.Errorf("%s: govde bulunamadi: %v", v.fon, err)
			continue
		}
		sutunlar, err := sutunkontrol.SelectSutunlari(govde)
		if err != nil {
			t.Errorf("%s: SELECT ayristirilamadi: %v", v.fon, err)
			continue
		}
		scanlar, err := sutunkontrol.ScanSayilari(govde)
		if err != nil {
			t.Errorf("%s: Scan ayristirilamadi: %v", v.fon, err)
			continue
		}
		// ⚠️ **ILK** SELECT ve **ILK** Scan karsilastirilir: her iki fonksiyon
		//    da tek bir ANA sorgu kosuyor ve okudugu satirlari tek `Scan`e
		//    veriyor. Ana sorgunun WHERE'i icinde yetki icin alt sorgular
		//    olabilir (`EXISTS(...)`) — onlarin Scan karsiligi YOKTUR ve
		//    sayilmalari muhafizi hizalanamaz hale getirirdi.
		if len(sutunlar) == 0 || len(scanlar) == 0 {
			t.Errorf("%s: SELECT (%d) ya da Scan (%d) BULUNAMADI — muhafiz "+
				"hicbir sey olcmuyor demektir (turu 89 dersi).",
				v.fon, len(sutunlar), len(scanlar))
			continue
		}
		if sutunlar[0] != scanlar[0] {
			t.Errorf("%s: SELECT **%d** sutun donduruyor ama `Scan` **%d** "+
				"alan bekliyor.\n"+
				"Bu uyusmazlik DERLENIR; calisma aninda Scan hata doner, "+
				"dongu `continue` eder ve SATIRLAR SESSIZCE ATLANIR "+
				"(liste BOMBOS gorunur, log DUSMEZ).",
				v.fon, sutunlar[0], scanlar[0])
		}
	}
}

// govdeAl — `func (h *Handler) AD(` ile baslayan fonksiyonun govdesini
// susluk derinligi sayarak cikarir.
func govdeAl(kaynak, ad string) (string, error) {
	anahtar := ") " + ad + "("
	i := strings.Index(kaynak, anahtar)
	if i < 0 {
		return "", errYok
	}
	// Govdenin acilis suslugunu bul.
	j := strings.Index(kaynak[i:], "{")
	if j < 0 {
		return "", errYok
	}
	s := kaynak[i+j:]
	derinlik := 0
	for k := 0; k < len(s); k++ {
		switch s[k] {
		case '{':
			derinlik++
		case '}':
			derinlik--
			if derinlik == 0 {
				return s[:k], nil
			}
		}
	}
	return "", errYok
}

var errYok = errors.New("fonksiyon govdesi bulunamadi")
