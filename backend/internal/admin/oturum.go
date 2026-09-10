package admin

import (
	"crypto/rand"
	"encoding/hex"
	"net"
	"net/http"
	"os"
	"sync"
	"time"
)

// ⚠️⚠️⚠️ TURU 181 — ADMIN OTURUMU: **ADMIN_KEY ARTIK TARAYICIYA GITMIYOR.**
//
// ═══════════ ONCEKI HAL VE NEDEN DEGISTI ═══════════
//
// `POST /admin/login` dogru kullanici/sifre karsiliginda **ADMIN_KEY'in
// KENDISINI** JSON ile donduruyor, panel onu `localStorage['gbzkey']`e
// yaziyor ve bundan sonra HER istek `?key=<ADMIN_KEY>` ile gidiyordu.
// Uc somut sorun:
//
//  1. **Sorgu parametresi LOGLANIR**: Caddy/Cloudflare erisim loglari,
//     tarayici gecmisi ve `Referer` basligi anahtari tasir.
//  2. **XSS = KALICI ANAHTAR SIZINTISI**: panelde tek bir XSS, sunucunun
//     ANA admin anahtarini disari tasir; anahtar degistirilene kadar
//     gecerli kalir.
//  3. Panel bu turda **YAZMA YETKISI** aliyor (isletme sil, kullanici
//     askiya al, icerik karantina). Salt-okur bir panelde tolere
//     edilebilir olan sey, yazan bir panelde edilemez.
//
// ═══════════ YENI HAL ═══════════
//
// Login basarili olursa **kisa omurlu, rastgele bir OTURUM JETONU** doner.
// Jeton bellekte tutulur, `oturumOmru` sonra duser ve ADMIN_KEY ile
// HICBIR ILISKISI yoktur (sizsa bile anahtari ele vermez).
//
// ⚠️⚠️ `?key=<ADMIN_KEY>` YOLU **KALDIRILMADI** (bkz. `yetki.go`):
//
//	`tools/` betikleri ve elle `curl` cagrilari onu kullaniyor; kaldirmak
//	calisan bir yolu kirardi. Yeni olan sey, PANELIN artik onu
//	KULLANMAMASI.
//
// ⚠️ Jetonlar SUNUCU YENIDEN BASLAYINCA DUSER (bellekte). Bu bilincli:
//
//	kalici oturum tablosu, admin tarafinda ek bir saldiri yuzeyi ve
//	temizlik isi demek; yeniden giris 5 saniyelik bir islem.
const (
	oturumOmru = 12 * time.Hour

	// ⚠️ BRUTE-FORCE PENCERESI: ayni IP'den `denemeTavani` basarisiz
	//	denemeden sonra `denemeCezasi` boyunca 429 doner.
	//	Sunucu tarafi bir kapi ZORUNLU: `/admin/login` kimlik istemeyen
	//	tek admin ucu ve sifre 12 karakterlik bir dize.
	denemeTavani = 6
	denemePenc   = 5 * time.Minute
	denemeCezasi = 15 * time.Minute
)

type oturumDeposu struct {
	mu       sync.RWMutex
	jetonlar map[string]time.Time // jeton -> son gecerlilik
}

var depo = &oturumDeposu{jetonlar: map[string]time.Time{}}

func (d *oturumDeposu) ac() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	j := hex.EncodeToString(b)
	d.mu.Lock()
	// ⚠️ Suresi gecmisleri BURADA temizle: ayri bir supurge goroutine'i
	//	acmaya deger bir hacim yok (admin sayisi tek haneli).
	simdi := time.Now()
	for k, t := range d.jetonlar {
		if simdi.After(t) {
			delete(d.jetonlar, k)
		}
	}
	d.jetonlar[j] = simdi.Add(oturumOmru)
	d.mu.Unlock()
	return j, nil
}

func (d *oturumDeposu) gecerli(j string) bool {
	if j == "" {
		return false
	}
	d.mu.RLock()
	t, ok := d.jetonlar[j]
	d.mu.RUnlock()
	return ok && time.Now().Before(t)
}

func (d *oturumDeposu) kapat(j string) {
	d.mu.Lock()
	delete(d.jetonlar, j)
	d.mu.Unlock()
}

// ---- brute-force sayaci ----

type denemeKaydi struct {
	adet int
	ilk  time.Time
	ceza time.Time
}

var (
	denemeMu  sync.Mutex
	denemeler = map[string]*denemeKaydi{}
)

// ip — istegin kaynak adresi.
//
// ⚠️ `X-Forwarded-For` **EN SOLDAKI** degeri alinir: Caddy arkasindayiz ve
//
//	gercek istemci en solda durur. Basligin tamamini anahtar yapmak,
//	saldirganin basligi degistirip sayaci sifirlamasina izin verirdi
//	(zaten oyle de yapabilir — bu kapi MUTLAK degil, MALIYET artiricidir).
func ip(r *http.Request) string {
	if f := r.Header.Get("X-Forwarded-For"); f != "" {
		for i := 0; i < len(f); i++ {
			if f[i] == ',' {
				return trimSp(f[:i])
			}
		}
		return trimSp(f)
	}
	h, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return h
}

func trimSp(s string) string {
	for len(s) > 0 && (s[0] == ' ' || s[0] == '\t') {
		s = s[1:]
	}
	for len(s) > 0 && (s[len(s)-1] == ' ' || s[len(s)-1] == '\t') {
		s = s[:len(s)-1]
	}
	return s
}

// cezaliMi — bu IP su an kilitli mi?
func cezaliMi(adr string) bool {
	denemeMu.Lock()
	defer denemeMu.Unlock()
	k := denemeler[adr]
	if k == nil {
		return false
	}
	return time.Now().Before(k.ceza)
}

// basarisizDeneme — sayaci artirir, tavan asilirsa ceza uygular.
func basarisizDeneme(adr string) {
	denemeMu.Lock()
	defer denemeMu.Unlock()
	simdi := time.Now()
	// ⚠️ Harita buyumesini sinirla: admin girisi nadir, ama kotu niyetli
	//	bir tarama binlerce IP uretebilir.
	if len(denemeler) > 5000 {
		denemeler = map[string]*denemeKaydi{}
	}
	k := denemeler[adr]
	if k == nil || simdi.Sub(k.ilk) > denemePenc {
		denemeler[adr] = &denemeKaydi{adet: 1, ilk: simdi}
		return
	}
	k.adet++
	if k.adet >= denemeTavani {
		k.ceza = simdi.Add(denemeCezasi)
	}
}

func basariliDeneme(adr string) {
	denemeMu.Lock()
	delete(denemeler, adr)
	denemeMu.Unlock()
}

// ---- uclar ----

type girisIstek struct {
	User string `json:"user"`
	Pass string `json:"pass"`
}

// Giris — POST /admin/giris {user,pass} -> {jeton}
//
// ⚠️⚠️ **FAIL-CLOSED**: `ADMIN_USER`/`ADMIN_PASS`/`ADMIN_KEY` ucunden biri
//
//	bile tanimsizsa panel KAPALI (503). Eski kod `ADMIN_PASS` bossa
//	**koda gomulu `Gebzem2026!`** varsayilanini kullaniyordu ve repo
//	PUBLIC — yani sunucuda o env yoksa panel HERKESE aciktı.
//
// ⚠️ Hata mesaji kullanici adiyla sifreyi AYIRT ETMEZ ("hatalı kullanıcı
//
//	adı veya şifre"): ayirmak, gecerli kullanici adini dogrulayan bir
//	kesif araci olurdu.
func (h *Handler) Giris(w http.ResponseWriter, r *http.Request) {
	adr := ip(r)
	if cezaliMi(adr) {
		hata(w, http.StatusTooManyRequests,
			"çok fazla başarısız deneme, birazdan tekrar deneyin")
		return
	}
	var req girisIstek
	if !govde(w, r, &req) {
		return
	}
	u, p := os.Getenv("ADMIN_USER"), os.Getenv("ADMIN_PASS")
	if u == "" || p == "" || Key() == "" {
		hata(w, http.StatusServiceUnavailable,
			"yönetim paneli kapalı (ADMIN_USER / ADMIN_PASS / ADMIN_KEY tanımsız)")
		return
	}
	// ⚠️ Sabit zamanli karsilastirma (`esit`, yetki.go): duz `==` sifrenin
	//	ilk baytlarini zamanlama ile sizdirabilir.
	if !esit(req.User, u) || !esit(req.Pass, p) {
		basarisizDeneme(adr)
		hata(w, http.StatusUnauthorized, "hatalı kullanıcı adı veya şifre")
		return
	}
	jeton, err := depo.ac()
	if err != nil {
		hata(w, http.StatusInternalServerError, "oturum açılamadı")
		return
	}
	basariliDeneme(adr)
	Yaz(r, h.db, "admin.giris", "", "", nil, nil)
	yaz(w, http.StatusOK, map[string]any{
		"jeton":     jeton,
		"omur_saat": int(oturumOmru / time.Hour),
	})
}

// Cikis — POST /admin/cikis. Jetonu DUSURUR.
//
// ⚠️ Panel `localStorage`i temizlese bile jeton sunucuda gecerli kalirdi;
//
//	gercek cikis icin sunucu tarafinda dusurulmesi gerekir.
func (h *Handler) Cikis(w http.ResponseWriter, r *http.Request) {
	depo.kapat(jetonAl(r))
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}
