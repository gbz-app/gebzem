// Package admin — yonetim paneli: kimlik, panel HTML'i ve CRUD uclari.
//
// ⚠️⚠️⚠️ NEDEN AYRI PAKET: admin uclari turu 78'den beri `internal/calls`
//
//	icinde yasiyordu (arama handler'i). O dosya 2120 satir ve admin kismi
//	orada yalnizca "canli arama izleme" ihtiyaci icin dogmustu. Panel artik
//	isletme/kullanici/icerik YONETIMI yapiyor; arama paketinin icinde
//	buyutmek, iki alakasiz sorumlulugu tek dosyada kilitlerdi.
//
// ⚠️ ESKI UCLAR (`/admin/stats`, `/admin/users`, `/admin/user/{id}`,
//
//	`/admin/calls`, `/admin/audio`, `/admin/ws`) **YERINDE BIRAKILDI**:
//	calisiyorlar, `h.hub` gibi arama-ic bagimliliklari var ve tasimak
//	kazancsiz risk olurdu. Panel ikisini de cagirir.
//
// ⚠️⚠️ YETKI **TEK KAYNAK**: `admin.Yetkili`. `internal/calls` kendi
//
//	kopyasini SILDI ve buraya devretti — iki kopya kacinilmaz olarak
//	ayrisir (bu projede "ayni kuralin iki kopyasi drift eder" sinifi ALTI
//	kez sahaya cikti).
package admin

import (
	"crypto/subtle"
	"encoding/json"
	"net/http"
	"os"
	"strings"
)

// Key — ADMIN_KEY. BOS ise admin tarafi TAMAMEN KAPALIDIR (fail-closed).
//
// ⚠️⚠️ SABIT YEDEK ANAHTAR **YASAK** (turu 78 denetimi): repo PUBLIC.
//
//	Kodda bir varsayilan birakmak, herkesin panele girebilmesi demektir.
//
// ⚠️ YAPMA: buraya `if k == "" { k = "..." }` yazma.
func Key() string { return os.Getenv("ADMIN_KEY") }

// Yetkili — istegin admin anahtarini tasiyip tasimadigini soyler.
//
// ⚠️⚠️ IKI KAYNAK KABUL EDILIR ve bu BILINCLI:
//   - `?key=` — mevcut panelin ve `tools/` betiklerinin kullandigi yol;
//     GERIYE UYUMLULUK icin KALDIRILAMAZ.
//   - `X-Admin-Key` basligi — YENI yol. Query parametresi Caddy/Cloudflare
//     erisim loglarina ve tarayici gecmisine DUSER; yazma islemleri
//     (silme, askiya alma) icin baslik tercih edilir.
//
// ⚠️⚠️ KARSILASTIRMA **SABIT ZAMANLI** (`subtle.ConstantTimeCompare`):
//
//	duz `==` erken cikar ve anahtarin ilk baytlarini zamanlama ile
//	sizdirabilir. Bedeli sifir, kazanci gercek.
//
// ⚠️ Uzunluk farkinda da sabit zamanli dal kullanilir: `ConstantTimeCompare`
//
//	farkli uzunlukta 0 doner, yani ayni kod yolu.
func Yetkili(r *http.Request) bool {
	k := Key()
	if k == "" {
		return false
	}
	aday := r.Header.Get("X-Admin-Key")
	if aday == "" {
		aday = r.URL.Query().Get("key")
	}
	return subtle.ConstantTimeCompare([]byte(aday), []byte(k)) == 1
}

// kapi — her admin ucunun ILK satiri. Yetkisizse 401 yazar ve false doner.
//
// ⚠️ Cagri yerinde `if !kapi(w, r) { return }` deseni ZORUNLU: yetki
//
//	kontrolunu her handler'a elle yazmak, birinde unutulunca SESSIZ bir
//	veri sizintisi demektir.
func kapi(w http.ResponseWriter, r *http.Request) bool {
	if Yetkili(r) {
		return true
	}
	hata(w, http.StatusUnauthorized, "yetkisiz")
	return false
}

// ---- yanit yardimcilari ----

// yaz — JSON yanit.
//
// ⚠️⚠️ `Content-Type` **ACIKCA** yazilir (turu 96i sevk engeli): basliksiz
//
//	`json.NewEncoder(w).Encode` cagrisinda Go govdeyi koklayip
//	`text/plain` koyar; Dio/fetch ayristirmaz ve istemci yaniti bir DIZE
//	olarak alir. `internal/sutunkontrol/icerik_turu_test.go` bunu ZORLUYOR.
func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	// Panel ayni kokten servis ediliyor; yine de tools/ betikleri ve yerel
	// gelistirme icin acik birakiliyor (mevcut admin uclarinin davranisi).
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, m string) {
	yaz(w, kod, map[string]string{"error": m})
}

// govde — istek govdesini cozer. Bos/bozuk govde 400 yazar ve false doner.
//
// ⚠️ Tavan `http.MaxBytesReader` ile: admin de olsa 100 MB'lik bir govde
//
//	sunucuyu bellekten dusurebilir.
func govde(w http.ResponseWriter, r *http.Request, hedef any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MB
	if err := json.NewDecoder(r.Body).Decode(hedef); err != nil {
		hata(w, http.StatusBadRequest, "geçersiz istek")
		return false
	}
	return true
}

// kisalt — metni tavana ceker (RUNE bazli).
//
// ⚠️⚠️ BAYT DEGIL RUNE: Turkce harfler UTF-8'de 2 bayt; bayt bazli kesme
//
//	bir harfi ORTADAN bolup gecersiz UTF-8 uretir ve Postgres'e yazilan
//	deger bozulur.
func kisalt(s string, n int) string {
	s = strings.TrimSpace(s)
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}
