package ilan

import (
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
