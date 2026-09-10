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
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
)

// Key — ADMIN_KEY. BOS ise admin tarafi TAMAMEN KAPALIDIR (fail-closed).
//
// ⚠️⚠️ SABIT YEDEK ANAHTAR **YASAK** (turu 78 denetimi): repo PUBLIC.
//
//	Kodda bir varsayilan birakmak, herkesin panele girebilmesi demektir.
//
// ⚠️ YAPMA: buraya `if k == "" { k = "..." }` yazma.
func Key() string { return os.Getenv("ADMIN_KEY") }

// esit — sabit zamanli dize karsilastirmasi.
//
// ⚠️ Duz `==` erken cikar ve degerin ilk baytlarini zamanlama ile
//
//	sizdirabilir. Bedeli sifir, kazanci gercek.
//
// ⚠️ Farkli uzunlukta `ConstantTimeCompare` 0 doner — ayni kod yolu.
func esit(a, b string) bool {
	return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}

// jetonAl — istekteki admin kimligini cikarir (jeton ya da ham anahtar).
//
// ⚠️ Sira: `X-Admin-Jeton` -> `X-Admin-Key` -> `?key=`.
func jetonAl(r *http.Request) string {
	if j := r.Header.Get("X-Admin-Jeton"); j != "" {
		return j
	}
	return ""
}

// Yetkili — istegin admin kimligini tasiyip tasimadigini soyler.
//
// ⚠️⚠️ **UC KAYNAK** kabul edilir ve ucu de BILINCLI:
//
//  1. `X-Admin-Jeton` — **PANELIN kullandigi yol** (turu 181). Kisa
//     omurlu, ADMIN_KEY ile ilgisi olmayan rastgele jeton (bkz.
//     `oturum.go`). Sizsa bile ana anahtari ele vermez ve 12 saatte duser.
//  2. `X-Admin-Key` basligi — betikler icin; anahtar loglara DUSMEZ.
//  3. `?key=` sorgu parametresi — `tools/` betiklerinin ve elle `curl`
//     cagrilarinin kullandigi ESKI yol. **KALDIRILAMAZ** (calisan yollari
//     kirar) ama panel artik onu KULLANMIYOR.
//
// ⚠️ YAPMA: (3)'u kaldirma — `tools/` betikleri ve `/admin/streams`
//
//	cagrilari ona bagli.
func Yetkili(r *http.Request) bool {
	if depo.gecerli(jetonAl(r)) {
		return true
	}
	k := Key()
	if k == "" {
		return false // fail-closed: anahtar yoksa admin KAPALI
	}
	aday := r.Header.Get("X-Admin-Key")
	if aday == "" {
		aday = r.URL.Query().Get("key")
	}
	return esit(aday, k)
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

// sayi — sorgu parametresini SINIRLARA CEKEREK okur.
//
// ⚠️ Tavan ZORUNLU: `?limit=100000` admin de olsa tek istekte tum tabloyu
//
//	belleğe alirdi.
func sayi(r *http.Request, ad string, varsayilan, alt, ust int) int {
	v, err := strconv.Atoi(r.URL.Query().Get(ad))
	if err != nil {
		return varsayilan
	}
	if v < alt {
		return alt
	}
	if v > ust {
		return ust
	}
	return v
}

// uuidBicimi — 8-4-4-4-12 onaltilik bicim.
//
// ⚠️⚠️ ZORUNLU: admin uclari kimlikleri dogrudan SQL parametresi yapiyor.
//
//	Bozuk bir deger pgx'te "invalid input syntax for type uuid" ile
//	**500** dondurur; bicim kapisi onu 400'e cevirir ve loglari
//	gurultuden korur.
//
// ⚠️ `regexp` KULLANILMADI: elle tarama daha ucuz ve bagimliliksiz
//
//	(`internal/isletme/ozellik.go` ile ayni karar).
func uuidBicimi(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if c != '-' {
				return false
			}
			continue
		}
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') && (c < 'A' || c > 'F') {
			return false
		}
	}
	return true
}

// kimlik — yol parametresinden UUID okur; bozuksa 400 yazip false doner.
func kimlik(w http.ResponseWriter, r *http.Request, ad string) (string, bool) {
	id := chi.URLParam(r, ad)
	if !uuidBicimi(id) {
		hata(w, http.StatusBadRequest, "geçersiz kimlik")
		return "", false
	}
	return id, true
}

// yolParam — chi yol parametresi (kisa sarmal).
func yolParam(r *http.Request, ad string) string { return chi.URLParam(r, ad) }

// sayiYol — yol parametresini int64 olarak okur; bozuksa 0.
func sayiYol(r *http.Request, ad string) int64 { return sayiCoz(chi.URLParam(r, ad)) }

func sayiCoz(s string) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 0
	}
	return v
}
