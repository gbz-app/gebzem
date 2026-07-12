// Package udid: iOS test cihazi kaydi (Apple "Over-The-Air" cihaz kaydi).
// Kisi indir.gebzem.app/udid-al.html acar -> profil yukler -> iOS cihaz kimligini
// (UDID) buraya POST eder -> biz loglariz -> Apple Developer'a ekleyip build aliriz.
// Ad hoc dagitimda yeni iPhone'lari UDID uğrasi olmadan eklemenin en kolay yolu.
package udid

import (
	"io"
	"log"
	"net/http"
	"regexp"
)

// Apple imzali (PKCS7) plist'i binary gelir ama icindeki plist ASCII'dir;
// alanlari duz metin arayarak cikariyoruz (imza dogrulamaya gerek yok — sadece UDID).
var (
	reUDID    = regexp.MustCompile(`<key>UDID</key>\s*<string>([^<]+)</string>`)
	reProduct = regexp.MustCompile(`<key>PRODUCT</key>\s*<string>([^<]+)</string>`)
	reVersion = regexp.MustCompile(`<key>VERSION</key>\s*<string>([^<]+)</string>`)
)

// Handle: iOS cihaz profili yukleyince buraya POST eder.
func Handle(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "okunamadi", http.StatusBadRequest)
		return
	}
	s := string(body)
	udid, product, version := "", "", ""
	if m := reUDID.FindStringSubmatch(s); len(m) > 1 {
		udid = m[1]
	}
	if m := reProduct.FindStringSubmatch(s); len(m) > 1 {
		product = m[1]
	}
	if m := reVersion.FindStringSubmatch(s); len(m) > 1 {
		version = m[1]
	}

	// UDID sunucu loguna dusuyor -> `docker compose logs api | grep 'CIHAZ KAYDI'`
	log.Printf("CIHAZ KAYDI (UDID): udid=%s cihaz=%s ios=%s", udid, product, version)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if udid == "" {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(sayfa("Cihaz kimligi alinamadi",
			"Bir sorun olustu. Lutfen tekrar deneyin veya baglantiyi gonderen kisiye bildirin.")))
		return
	}
	w.Write([]byte(sayfa("Cihaz kimligin alindi ✓",
		"Tesekkurler! Kaydin bize ulasti. Uygulama hazir olunca sana indirme baglantisi gonderilecek. Bu sayfayi kapatabilirsin.")))
}

func sayfa(baslik, mesaj string) string {
	return `<!doctype html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gebzem</title>
<style>
  body{font-family:-apple-system,system-ui,sans-serif;background:#0B141A;color:#fff;
       margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px}
  .k{max-width:360px;text-align:center}
  h1{font-size:22px;margin:0 0 12px}
  p{color:#b9c4cc;line-height:1.5;font-size:16px}
  .l{width:72px;height:72px;border-radius:20px;background:#25D366;margin:0 auto 20px;
     display:flex;align-items:center;justify-content:center;font-size:36px}
</style></head><body><div class="k">
<div class="l">📱</div><h1>` + baslik + `</h1><p>` + mesaj + `</p></div></body></html>`
}
