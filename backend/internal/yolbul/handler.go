// Package yolbul — ADRES ARAMA + YAYA ROTASI (turu 152).
//
// Kullanici emri: *"rota olustururken arama yok yani SOKAK ADI CADDE"* +
// *"shape guzel ciziyor ama bizim yurume EVLERIN UZERINDEN gidiyor, sokak
// cadde guzel cizmiyor"* + *"ben 1711 sokak dedigimde Google ile arama yapip
// TAM SOKAK CADDEYI bulacak mi"*.
//
// ═══════════ ⚠️⚠️⚠️ NEDEN VEKIL (PROXY) — ANAHTAR ISTEMCIYE GIRMEZ ═══════════
//
// Google **Places API (New)** ve **Routes API** birer WEB SERVISIDIR. Google'in
// resmi guvenlik dokumani bu grup icin tek kisitlama olarak **IP ADRESI**
// veriyor; Maps SDK'daki gibi "Android paketi / iOS bundle" kisitlamasi
// DESTEKLENMIYOR.
//
// Bu repo **PUBLIC** ve derlenmis APK/IPA'dan dize cikarmak onemsiz bir is.
// Anahtar uygulamaya gomulseydi:
//
//	· cikaran kisi bizim faturamiza istek atardi,
//	· kotayi doldurup ozelligi GERCEK kullanicilar icin kapatabilirdi.
//
// Bu yuzden anahtar YALNIZ sunucuda durur (`GOOGLE_SERVIS_KEY`) ve Google'a
// **yalnizca bu iki uc** cikar. Istemci Google'i HIC gormez; kendi API'mizi
// cagirir ve zaten JWT ile kimliklenmistir.
//
// ⚠️ Anahtar Google tarafinda AYRICA kisitli: yalniz `places.googleapis.com`
//
//	ve `routes.googleapis.com`, yalniz sunucunun IPv4+IPv6 adresi.
//
// ═══════════ ⚠️⚠️ ENV KAPISI — R2/AI KALIBININ AYNISI ═══════════
//
// Anahtar YOKSA `Acik()` false doner ve uclar **503** verir; istemci
// `GET /yolbul/durum` ile sorup ozelligi HIC CIZMEZ (olu arayuz olmaz).
//
// ⚠️⚠️ **TURU 75'IN BIREBIR TEKRARI RISKI:** R2 anahtarlari sunucudaki
//
//	`.env`e yazilmis ama `docker-compose.yml`in **`environment:` blogu**
//	guncellenmemis ve medya SESSIZCE KAPALI kalmisti (`/health` "ok"
//	donuyordu!). `GOOGLE_SERVIS_KEY` icin **IKI YER** de guncellendi.
//	⚠️ YAPMA: yalniz `.env`e yazip birakma.
//
// ═══════════ ⚠️⚠️ MALIYET ═══════════
//
// Ikisi de SKU basina **aylik 10.000 istek UCRETSIZ** (1 Mart 2025'ten beri
// $200 kredi yerine bu geldi). Bizim olcegimizde fiili maliyet **0**.
// Yine de iki koruma var:
//
//	· **Redis onbellegi** — ayni sorgu/rota tekrar FATURALANMAZ,
//	· **dar FieldMask** — Routes'ta istenen alan kumesi SKU'yu belirliyor;
//	  genis maske Enterprise katmanina atlatir. Buradaki maske Essentials'ta
//	  kalir.
//
// ⚠️ YAPMA: FieldMask'e `routes.travelAdvisory.tollInfo` gibi alanlar ekleme.
package yolbul

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
)

// Google'a giden isteklerin zaman asimi.
//
// ⚠️ ZORUNLU: dis servis asili kalirsa istemci de asili kalir ve kullanici
//
//	"arama calismiyor" der. 8 sn, Places'in p99'unun belirgin ustunde.
const disZamanAsimi = 8 * time.Second

// Onbellek omurleri.
//
// ⚠️ Adres aramasi 7 gun: sokak adlari degismez, ayni sorgu tekrar
//
//	faturalanmasin.
//
// ⚠️ Yaya rotasi 1 gun: yol agi nadiren degisir ama yol kapanmalari icin
//
//	sonsuz tutulmaz.
const (
	adresOmru = 7 * 24 * time.Hour
	rotaOmru  = 24 * time.Hour
)

type Handler struct {
	rdb *redis.Client
	hc  *http.Client
}

func NewHandler(rdb *redis.Client) *Handler {
	return &Handler{rdb: rdb, hc: &http.Client{Timeout: disZamanAsimi}}
}

func anahtar() string { return strings.TrimSpace(os.Getenv("GOOGLE_SERVIS_KEY")) }

// Acik — ozellik kullanilabilir mi (anahtar var mi)?
func Acik() bool { return anahtar() != "" }

// LogDurum — acilista bir satir (AI/medya kalibinin aynisi).
func LogDurum() {
	if Acik() {
		log.Printf("yolbul: aktif (Places + Routes)")
		return
	}
	log.Printf("yolbul: GOOGLE_SERVIS_KEY yok — ADRES ARAMA ve YAYA ROTASI KAPALI")
}

// ⚠️ `yaz` — **Content-Type DAIMA yazilir**.
//
// Turu 96i dersi: `internal/isletme/adres.go` paketin kendi yardimcisini
// ATLAYIP ciplak `json.NewEncoder(w).Encode` kullanmisti; Go govdeyi koklayip
// `text/plain` koydu, Dio ayristirmadi ve ozellik SESSIZCE olu dogdu — ustelik
// uctan uca testler GECIYORDU (Node `JSON.parse` baslıga bakmaz).
func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	_ = json.NewEncoder(w).Encode(v)
}

func (h *Handler) kapali(w http.ResponseWriter) bool {
	if Acik() {
		return false
	}
	yaz(w, http.StatusServiceUnavailable, map[string]any{
		"error": "adres servisi kapalı",
	})
	return true
}

// Durum — istemci ozelligi cizmeden ONCE sorar.
func (h *Handler) Durum(w http.ResponseWriter, _ *http.Request) {
	yaz(w, http.StatusOK, map[string]any{"acik": Acik()})
}

// ═══════════════════════════════════════════════════════════════════
// 2) YAYA ROTASI  —  POST /yolbul/yaya
// ═══════════════════════════════════════════════════════════════════

type yayaIstek struct {
	BasEnlem  float64 `json:"bas_enlem"`
	BasBoylam float64 `json:"bas_boylam"`
	VarEnlem  float64 `json:"var_enlem"`
	VarBoylam float64 `json:"var_boylam"`
}

type yayaYanit struct {
	Noktalar [][2]float64 `json:"noktalar"`
	MesafeM  int          `json:"mesafe_m"`
	SureSn   int          `json:"sure_sn"`
	Adimlar  []string     `json:"adimlar"`
	// ⚠️ SOZLESME GEREGI: Google, WALK rotalarinin BETA oldugunu ve kaldirim/
	//    yaya yolu bilgisinin eksik olabilecegini kullaniciya GOSTERMEYI
	//    zorunlu tutuyor. Metin sunucudan gelir ki tek yerden degistirilebilsin.
	Uyari string `json:"uyari"`
}

const yayaUyarisi = "Yaya rotası kaldırım ve geçit bilgisi içermeyebilir."

// Yaya — Routes API `computeRoutes`, travelMode WALK.
//
// ⚠️⚠️ **FieldMask ZORUNLU**: Google *"If you don't specify a field mask, the
//
//	methods return an error"* diyor. Ayrica MALIYET SKU'su maskeye gore
//	degisiyor — buradaki maske Essentials katmaninda kalir.
//
// ⚠️ `routingPreference` VERILMEZ: dokumanda *"only for DRIVE or
//
//	TWO_WHEELER"*; yaya modunda gonderilirse istek REDDEDILIR.
//
// ⚠️ Cok uzak noktalarda yaya rotasi anlamsizdir ve bosuna faturalanir;
//
//	30 km ustu ISTEK ATILMADAN reddedilir.
func (h *Handler) Yaya(w http.ResponseWriter, r *http.Request) {
	if h.kapali(w) {
		return
	}
	var req yayaIstek
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<12)).Decode(&req); err != nil {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "geçersiz istek"})
		return
	}
	if !gecerliKoordinat(req.BasEnlem, req.BasBoylam) ||
		!gecerliKoordinat(req.VarEnlem, req.VarBoylam) {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "geçersiz koordinat"})
		return
	}
	if kabaMetre(req.BasEnlem, req.BasBoylam, req.VarEnlem, req.VarBoylam) > 30000 {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "yürüme için çok uzak"})
		return
	}

	// ⚠️ Onbellek anahtari ~11 m'ye yuvarlanir (5 ondalik): GPS gurultusu
	//    her istekte yeni bir fatura uretmesin.
	ck := fmt.Sprintf("yolbul:yaya:%.5f,%.5f>%.5f,%.5f",
		req.BasEnlem, req.BasBoylam, req.VarEnlem, req.VarBoylam)
	if s, err := h.rdb.Get(r.Context(), ck).Result(); err == nil && s != "" {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, s)
		return
	}

	istek := map[string]any{
		"origin": map[string]any{"location": map[string]any{
			"latLng": map[string]any{"latitude": req.BasEnlem, "longitude": req.BasBoylam},
		}},
		"destination": map[string]any{"location": map[string]any{
			"latLng": map[string]any{"latitude": req.VarEnlem, "longitude": req.VarBoylam},
		}},
		"travelMode":   "WALK",
		"languageCode": "tr",
		"units":        "METRIC",
		// ⚠️ HIGH_QUALITY: OVERVIEW cizgiyi kabalastirir ve dar sokaklarda
		//    yol yine "evlerin uzerinden" gecmis gibi gorunurdu.
		"polylineQuality": "HIGH_QUALITY",
	}

	var yanit struct {
		Routes []struct {
			DistanceMeters int    `json:"distanceMeters"`
			Duration       string `json:"duration"`
			Polyline       struct {
				EncodedPolyline string `json:"encodedPolyline"`
			} `json:"polyline"`
			Legs []struct {
				Steps []struct {
					NavigationInstruction struct {
						Instructions string `json:"instructions"`
					} `json:"navigationInstruction"`
				} `json:"steps"`
			} `json:"legs"`
		} `json:"routes"`
	}
	err := h.google(r.Context(),
		"https://routes.googleapis.com/directions/v2:computeRoutes",
		"routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,"+
			"routes.legs.steps.navigationInstruction",
		istek, &yanit)
	if err != nil {
		log.Printf("yolbul yaya: %v", err)
		yaz(w, http.StatusBadGateway, map[string]any{"error": "rota servisi yanıt vermedi"})
		return
	}
	if len(yanit.Routes) == 0 {
		// ⚠️ HATA DEGIL: iki nokta arasi yaya rotasi gercekten olmayabilir
		//    (otoyol arasi, deniz asiri). Istemci duz cizgiye DUSER.
		yaz(w, http.StatusOK, yayaYanit{Noktalar: [][2]float64{}, Uyari: yayaUyarisi})
		return
	}
	rt := yanit.Routes[0]

	adimlar := []string{}
	for _, l := range rt.Legs {
		for _, s := range l.Steps {
			if t := strings.TrimSpace(s.NavigationInstruction.Instructions); t != "" {
				adimlar = append(adimlar, t)
			}
		}
	}

	out := yayaYanit{
		Noktalar: polyCoz(rt.Polyline.EncodedPolyline),
		MesafeM:  rt.DistanceMeters,
		SureSn:   sureSn(rt.Duration),
		Adimlar:  adimlar,
		Uyari:    yayaUyarisi,
	}
	govde, _ := json.Marshal(out)
	_ = h.rdb.Set(r.Context(), ck, string(govde), rotaOmru).Err()
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(govde)
}

// ═══════════════════════════════════════════════════════════════════
// YARDIMCILAR
// ═══════════════════════════════════════════════════════════════════

// google — ortak istek yolu (anahtar + FieldMask + hata metni).
//
// ⚠️ Anahtar **BASLIKTA** gonderilir (`X-Goog-Api-Key`), sorgu dizesinde
//
//	DEGIL: sorgu dizesi ara vekillerin ve erisim kutuklerinin ICINE duser.
func (h *Handler) google(ctx context.Context, url, maske string, govde, hedef any) error {
	b, err := json.Marshal(govde)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", anahtar())
	// ⚠️ Autocomplete ucu FieldMask BASLIGINI DESTEKLEMIYOR; bos maske
	//    verildiginde baslik HIC yazilmaz.
	if maske != "" {
		req.Header.Set("X-Goog-FieldMask", maske)
	}

	res, err := h.hc.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	ham, err := io.ReadAll(io.LimitReader(res.Body, 1<<21))
	if err != nil {
		return err
	}
	if res.StatusCode != http.StatusOK {
		// ⚠️ Google'in hata govdesi LOGA yazilir ama ISTEMCIYE VERILMEZ:
		//    icinde proje numarasi ve servis adlari geciyor.
		return fmt.Errorf("google %d: %s", res.StatusCode, kirp(string(ham), 300))
	}
	return json.Unmarshal(ham, hedef)
}

// googleGet — Place Details gibi GET uclari icin.
//
// ⚠️ `google` POST yapiyor; Place Details GET ister. Ayni yardimciyi
//
//	zorlamak yerine ayri yazildi — govdesiz bir POST 400 verirdi.
func (h *Handler) googleGet(ctx context.Context, url, maske string, hedef any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("X-Goog-Api-Key", anahtar())
	if maske != "" {
		req.Header.Set("X-Goog-FieldMask", maske)
	}
	res, err := h.hc.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	ham, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return err
	}
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("google %d: %s", res.StatusCode, kirp(string(ham), 300))
	}
	return json.Unmarshal(ham, hedef)
}

func kirp(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

func gecerliKoordinat(en, boy float64) bool {
	// ⚠️ NaN KAPISI: `NaN` her karsilastirmadan SESSIZCE gecer
	//    (`NaN < 90` false, `NaN > -90` da false) — turu 85b dersi.
	if math.IsNaN(en) || math.IsNaN(boy) || math.IsInf(en, 0) || math.IsInf(boy, 0) {
		return false
	}
	if en == 0 && boy == 0 {
		return false
	}
	return en >= -90 && en <= 90 && boy >= -180 && boy <= 180
}

// kabaMetre — `cos(enlem)` duzeltmeli kaba mesafe.
//
// ⚠️ Duz 111320 kullanilsaydi Gebze enleminde boylam ekseni **%24** yanlis
//
//	olceklenirdi (turu 85b'de sunucu tarafinda SAHAYA CIKTI).
func kabaMetre(aEn, aBoy, bEn, bBoy float64) float64 {
	kx := 111320.0 * math.Cos(aEn*math.Pi/180)
	dx := (bBoy - aBoy) * kx
	dy := (bEn - aEn) * 111320.0
	return math.Sqrt(dx*dx + dy*dy)
}

// sureSn — Google'in "123s" bicimini saniyeye cevirir.
func sureSn(s string) int {
	s = strings.TrimSuffix(strings.TrimSpace(s), "s")
	n, err := strconv.Atoi(s)
	if err != nil {
		return 0
	}
	return n
}

// polyCoz — Google encoded polyline (precision 5) cozucusu.
//
// ⚠️ Cozum SUNUCUDA yapilir: istemciye [enlem, boylam] cifti dizisi gider.
//
//	Boylece istemci hangi motoru kullandigimizi bilmez ve motor
//	degistirilirse (or. kendi Valhalla'miza gecersek — o precision **6**
//	kullaniyor) istemci sozlesmesi DEGISMEZ.
func polyCoz(s string) [][2]float64 {
	out := [][2]float64{}
	if s == "" {
		return out
	}
	var lat, lng, i int
	n := len(s)
	oku := func() int {
		var sonuc, kaydir int
		for i < n {
			b := int(s[i]) - 63
			i++
			sonuc |= (b & 0x1f) << kaydir
			kaydir += 5
			if b < 0x20 {
				break
			}
		}
		if sonuc&1 != 0 {
			return ^(sonuc >> 1)
		}
		return sonuc >> 1
	}
	for i < n {
		lat += oku()
		lng += oku()
		out = append(out, [2]float64{float64(lat) / 1e5, float64(lng) / 1e5})
	}
	return out
}
