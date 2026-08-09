package users

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// ⚠️⚠️ TURU 78 — "SCAN EDILDI AMA YANITA KONMADI" MUHAFIZI.
//
// GERCEK BIR SEVK ENGELINDEN DOGDU: `Profile()` sorgusu `kapak_media_id` ve
// `onayli` sutunlarini SELECT edip `u.KapakMediaID` / `u.Onayli` alanlarina
// tariyordu, ama yanit ELLE KURULAN `map[string]any` ile donuyor ve o haritada
// bu iki ANAHTAR YOKTU. Sonuc: kapak gorseli ve onayli rozeti HICBIR PROFILDE
// gorunmeyecekti.
//
// ⚠️ NEDEN HICBIR MEVCUT KONTROL YAKALAMADI:
//   - `go build`: alanlar Scan'e verildigi icin "kullanilmiyor" hatasi CIKMAZ.
//   - `internal/sutunkontrol`: SELECT sutun sayisi ile Scan arguman sayisini
//     karsilastirir — ikisi de HIZALIYDI. Sorun Scan'den SONRAYDI.
//   - `flutter analyze`: Dart alanlari opsiyonel; eksik anahtar SESSIZCE
//     null/false uretir.
//   - Tek cihazda elle test: kullanici kendi kapagini DUZENLEME ekraninda
//     gorur (o `/users/me`den beslenir) ve "calisiyor" sanir.
//
// BU TEST NE YAPAR: `Profile()` govdesindeki `Scan(&u.X, ...)` argumanlarini
// okur, her `u.X` alaninin `userResp`taki JSON etiketini bulur ve o etiketin
// yanit haritasinda ANAHTAR olarak gectigini dogrular.
//
// ⚠️ YAPMA: bu testi silme. Yeni bir sutun eklerken UC yeri birlikte guncelle:
//
//	sorgu · Scan · yanit haritasi.
func TestProfileYanitiScanEdilenTumAlanlariIceriyor(t *testing.T) {
	kaynakBytes, err := os.ReadFile("takip.go")
	if err != nil {
		t.Fatalf("takip.go okunamadi: %v", err)
	}
	kaynak := string(kaynakBytes)

	handlerBytes, err := os.ReadFile("handler.go")
	if err != nil {
		t.Fatalf("handler.go okunamadi: %v", err)
	}

	// 1) `userResp` alan adi -> json etiketi haritasi.
	//    Ornek satir:  AvatarMediaID *string `json:"avatar_media_id,omitempty"`
	etiket := map[string]string{}
	alanRe := regexp.MustCompile(
		"(?m)^\\s*([A-Z][A-Za-z0-9]*)\\s+[^`\\n]+`json:\"([^\",]+)")
	govde := string(handlerBytes)
	bas := strings.Index(govde, "type userResp struct {")
	if bas < 0 {
		t.Fatal("`type userResp struct` bulunamadi")
	}
	son := strings.Index(govde[bas:], "\n}")
	if son < 0 {
		t.Fatal("`userResp` kapanmamis")
	}
	for _, m := range alanRe.FindAllStringSubmatch(govde[bas:bas+son], -1) {
		etiket[m[1]] = m[2]
	}
	if len(etiket) < 5 {
		t.Fatalf("userResp alanlari ayristirilamadi (bulunan: %d)", len(etiket))
	}

	// 2) `Profile()` govdesini ayikla.
	pBas := strings.Index(kaynak, "func (h *Handler) Profile(")
	if pBas < 0 {
		t.Fatal("`Profile` fonksiyonu bulunamadi")
	}
	pSon := strings.Index(kaynak[pBas:], "\n}\n")
	if pSon < 0 {
		t.Fatal("`Profile` kapanmamis")
	}
	profil := kaynak[pBas : pBas+pSon]

	// 3) Scan(&u.X, ...) argumanlarindaki alanlar.
	scanRe := regexp.MustCompile(`&u\.([A-Z][A-Za-z0-9]*)`)
	taranan := map[string]bool{}
	for _, m := range scanRe.FindAllStringSubmatch(profil, -1) {
		taranan[m[1]] = true
	}
	if len(taranan) == 0 {
		t.Fatal("`Profile` icinde `&u.Alan` taramasi bulunamadi")
	}

	// 4) Her taranan alanin json etiketi yanit haritasinda ANAHTAR olmali.
	var eksik []string
	for alan := range taranan {
		j, ok := etiket[alan]
		if !ok {
			// `userResp` disi bir alan taranmis olabilir — bu testin konusu degil.
			continue
		}
		if !strings.Contains(profil, `"`+j+`"`) {
			eksik = append(eksik, alan+" (json: "+j+")")
		}
	}
	if len(eksik) > 0 {
		t.Fatalf("SCAN EDILDI AMA YANITA KONMADI: %s\n"+
			"Bu alanlar sorgudan okunuyor ama `Profile` yanit haritasinda "+
			"ANAHTARLARI YOK — istemciye HIC gitmezler ve ozellik sahada "+
			"SESSIZCE calismaz (derleme de analiz de yakalamaz).",
			strings.Join(eksik, ", "))
	}
}
