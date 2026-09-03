// ⚠️⚠️⚠️ TURU 160 — **GUZERGAH SEKLINI YOLA OTURTMA** (snap to roads).
//
// Kullanici (gercek iPhone testi, ekran goruntusuyle): *"otobus rota shape
// KALDIRIMIN USTUNDE geciyor, bazen koselerde kaldirim ustunden geciyor...
// Yandex'te tam U donusu MUKEMMEL, yolun ortasindan tasmadan gidiyor"*.
//
// ⚠️⚠️ **KOK NEDEN OLCULDU — SEKIL YANLIS YERDE DEGIL, COK KABA.**
//
//	Belediyenin GTFS sekli iki durak arasini ORTALAMA 6 NOKTA ile ciziyor
//	ve guzergahin **%34'u 200 metreden uzun DUZ parcalar** (en uzun tek
//	segment 4.070 m). Yol kivrilinca cizgi koseyi KESIYOR:
//	  viraj yaricapi 15 m, kiris 53 m  ->  sapma **23,4 m**
//	  ayni viraj, kiris 25 m           ->  sapma 5,2 m
//	  ayni viraj, kiris 10 m           ->  sapma 0,8 m
//	Sekillerin **%35,3'unde** gercek viraj var (yaricap <200 m), virajlarin
//	onda biri 22 m'den keskin. z17'de cizginin yari genisligi 3,6 m; yani
//	23 m'lik sapma GOZLE GORULUR — kullanicinin gordugu tam bu.
//
// ⚠️⚠️⚠️ **NEDEN SUNUCUDA, NEDEN VARLIGA GOMULMUYOR — SOZLESME.**
//
//	Google Maps Platform sartlari donen yol koordinatlarini en fazla
//	**30 TAKVIM GUNU** onbelleklemeye izin verir; ayrica "yollari
//	dijitallestirme" ve "icerigi servis disina cikarip saklama" ACIKCA
//	yasaktir. Sekli `sekiller.json`a gomup APK/IPA ile dagitmak tam da
//	bu yasagin kapsamina girer (ve repo PUBLIC).
//	Bu yuzden sonuc SUNUCUDA, **omru 30 gunun ALTINDA** bir onbellekte
//	tutulur ve istemciye calisma aninda verilir.
//	⚠️ YAPMA: bu ciktiyi `assets/ulasim/sekiller.json`a yazma.
//	⚠️ YAPMA: onbellek omrunu 30 gune ya da uzerine cikarma.
//
// ⚠️⚠️ **MALIYET OLCULDU: AYDA ~0 USD.**
//
//	202 sekil / 69.357 nokta; istek basina 100 nokta tavani ve parcalar
//	arasi 10 nokta ortusme ile **845 istek**. Roads API ayda 5.000 cagri
//	ucretsiz. Onbellek icerik ozetine gore calistigi icin AYNI sekil
//	kac kullanici isterse istesin Google'a BIR KEZ gider; yani fatura
//	kullanici sayisiyla DEGIL, sekil sayisiyla olceklenir.
//	⚠️ Fiyatlandirma degisebilir — buyuk bir kullanim artisindan once
//	   resmi fiyat sayfasi YENIDEN kontrol edilmeli.
//
// ⚠️⚠️ **FAIL-OPEN**: her hata dalinda ORIJINAL sekil geri dondurulur.
//
//	Ozellik COKMEZ, yalnizca kabalasir — kullanici bugunku cizgiyi gorur.
//	Bu, `yayaRotasi`nin "rota alinamazsa duz cizgiye dusulur" karariyla
//	AYNI ilkedir.
package yolbul

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
	"time"
)

// Sekil onbellek omru.
//
// ⚠️⚠️ **30 GUNUN ALTINDA OLMAK ZORUNDA** (Google Maps Platform Service
//
//	Specific Terms md. 17.3: donen enlem/boylam degerleri en fazla 30
//	ardisik takvim gunu onbelleklenebilir, sonra SILINMELIDIR).
//	25 gun secildi: sinira yapismamak icin pay birakir.
//
// ⚠️ YAPMA: bu degeri 30 gune ya da uzerine cikarma.
const sekilOmru = 25 * 24 * time.Hour

// snapToRoads istek basina EN FAZLA 100 nokta kabul eder (resmi sinir).
//
// ⚠️ Parcalar arasi ORTUSME ZORUNLU: ortusme olmadan dikis yerlerinde
//
//	eslestirici baglami kaybeder ve iki parca farkli yollara oturabilir
//	(gorunur bir "sicrama" olusur).
const (
	sekilParca   = 100
	sekilOrtusme = 10
)

// Cok buyuk sekiller icin ust sinir — kotuye kullanim kapisi.
//
// ⚠️ En uzun gercek seklimiz 924 nokta; 4.000 bol bir pay birakir ve
//
//	istemcinin kazara devasa bir govde gondermesini engeller.
const sekilEnCokNokta = 4000

type sekilIstek struct {
	Kod string `json:"kod"`
}

type sekilYanit struct {
	Kod string `json:"kod"`
	// Oturtuldu — cizgi GERCEKTEN yola oturtuldu mu? Istemci bunu
	// kullaniciya "guzergah yaklasik" gibi bir ibare gostermek icin
	// okuyabilir. ⚠️ `false` doner ve `kod` ORIJINALDIR (fail-open).
	Oturtuldu bool `json:"oturtuldu"`
}

// Sekil — POST /yolbul/sekil
//
// Govde: {"kod": "<encoded polyline>"}
// Yanit: {"kod": "<yola oturtulmus polyline>", "oturtuldu": true}
func (h *Handler) Sekil(w http.ResponseWriter, r *http.Request) {
	if h.kapali(w) {
		return
	}
	var req sekilIstek
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&req); err != nil {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "geçersiz istek"})
		return
	}
	req.Kod = strings.TrimSpace(req.Kod)
	if req.Kod == "" {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "kod gerekli"})
		return
	}

	noktalar := polyCoz(req.Kod)
	if len(noktalar) < 2 {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "en az iki nokta gerekli"})
		return
	}
	if len(noktalar) > sekilEnCokNokta {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "şekil çok büyük"})
		return
	}

	// ── Onbellek: ICERIK OZETINE gore ──
	//
	// ⚠️⚠️ Anahtar SEKIL KIMLIGI degil, POLYLINE'IN OZETI. Sebep: sunucu
	//	GTFS varliklarini TASIMIYOR (onlar uygulama paketinde) ve
	//	sekil kimliginin ne anlama geldigini BILMIYOR. Icerik ozeti
	//	hem kimlikten bagimsiz hem de varlik yenilendiginde kendini
	//	otomatik gecersiz kilar.
	ozet := sha256.Sum256([]byte(req.Kod))
	ck := "yolbul:sekil:" + hex.EncodeToString(ozet[:16])
	if h.rdb != nil {
		if v, err := h.rdb.Get(r.Context(), ck).Result(); err == nil && v != "" {
			yaz(w, http.StatusOK, sekilYanit{Kod: v, Oturtuldu: true})
			return
		}
	}

	ctx, iptal := context.WithTimeout(r.Context(), 30*time.Second)
	defer iptal()

	yeni, err := h.sekliOturt(ctx, noktalar)
	if err != nil || len(yeni) < 2 {
		// ⚠️ FAIL-OPEN: orijinal geri doner (bkz. dosya serhi).
		yaz(w, http.StatusOK, sekilYanit{Kod: req.Kod, Oturtuldu: false})
		return
	}

	// ⚠️⚠️ **MAKULLUK KAPISI**: eslestirici yanlis yola atlarsa cizgi
	//	bugunkunden DAHA KOTU gorunur. Yeni cizgi eskisinin
	//	`sekilUzunlukTavani` katindan uzunsa sonuc ATILIR.
	//	(Turu 158b'de `_guzergahDilimi` icin ogrenilen ders: bir
	//	 duzeltmeyi kendi hedef metrigiyle degil SONUCUYLA olc.)
	eskiU, yeniU := yolUzunlugu(noktalar), yolUzunlugu(yeni)
	if eskiU > 0 && yeniU > eskiU*sekilUzunlukTavani {
		yaz(w, http.StatusOK, sekilYanit{Kod: req.Kod, Oturtuldu: false})
		return
	}

	kod := polyKodla(yeni)
	if h.rdb != nil {
		_ = h.rdb.Set(ctx, ck, kod, sekilOmru).Err()
	}
	yaz(w, http.StatusOK, sekilYanit{Kod: kod, Oturtuldu: true})
}

// ⚠️ Yeni cizgi eskisinin bu katindan uzunsa eslestirme BASARISIZ
//
//	sayilir. 1,5: gercek bir yola oturmak cizgiyi biraz uzatir (koseler
//	yuvarlanir, viraj icleri dolar) ama iki katina cikarmaz.
const sekilUzunlukTavani = 1.5

// sekliOturt — noktalari parca parca Roads API'ye gonderir.
//
// ⚠️⚠️ Herhangi bir parca basarisiz olursa TUM islem basarisiz sayilir:
//
//	yarisi oturtulmus yarisi ham bir cizgi, ikisinden de KOTUDUR
//	(dikis yerinde gorunur bir sicrama olusur).
func (h *Handler) sekliOturt(
	ctx context.Context, noktalar [][2]float64,
) ([][2]float64, error) {
	var cikti [][2]float64
	adim := sekilParca - sekilOrtusme
	for bas := 0; bas < len(noktalar); bas += adim {
		son := bas + sekilParca
		if son > len(noktalar) {
			son = len(noktalar)
		}
		parca, err := h.snapParca(ctx, noktalar[bas:son])
		if err != nil {
			return nil, err
		}
		if len(cikti) == 0 {
			cikti = parca
		} else if len(parca) > 0 {
			// ⚠️ Ortusen bolge iki kez cizilmesin: yeni parcanin ilk
			//    noktasi eskinin sonuna cok yakinsa atlanir.
			bas := 0
			if len(cikti) > 0 &&
				kabaMetre(cikti[len(cikti)-1][0], cikti[len(cikti)-1][1],
					parca[0][0], parca[0][1]) < 1 {
				bas = 1
			}
			cikti = append(cikti, parca[bas:]...)
		}
		if son == len(noktalar) {
			break
		}
	}
	return cikti, nil
}

type snapYanit struct {
	SnappedPoints []struct {
		Location struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
		} `json:"location"`
	} `json:"snappedPoints"`
}

func (h *Handler) snapParca(
	ctx context.Context, p [][2]float64,
) ([][2]float64, error) {
	if len(p) < 2 {
		return nil, fmt.Errorf("parca cok kucuk")
	}
	var sb strings.Builder
	for i, n := range p {
		if i > 0 {
			sb.WriteByte('|')
		}
		fmt.Fprintf(&sb, "%.6f,%.6f", n[0], n[1])
	}
	// ⚠️⚠️ `interpolate=true`: Google ARADAKI yol geometrisini de doldurur.
	//	Asil kazanc budur — bizim 6 noktali kaba cizgimiz yerine yolun
	//	GERCEK egrisi gelir, viraj ve U donusleri dahil.
	// ⚠️ Roads API `X-Goog-Api-Key` DEGIL `key=` sorgu parametresi bekler
	//    (Places/Routes'tan FARKLI); bu yuzden `googleGet` KULLANILMAZ.
	url := "https://roads.googleapis.com/v1/snapToRoads?interpolate=true&path=" +
		sb.String() + "&key=" + anahtar()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	res, err := h.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	ham, err := io.ReadAll(io.LimitReader(res.Body, 4<<20))
	if err != nil {
		return nil, err
	}
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("roads %d: %s", res.StatusCode, kirp(string(ham), 300))
	}
	var y snapYanit
	if err := json.Unmarshal(ham, &y); err != nil {
		return nil, err
	}
	out := make([][2]float64, 0, len(y.SnappedPoints))
	for _, s := range y.SnappedPoints {
		out = append(out, [2]float64{s.Location.Latitude, s.Location.Longitude})
	}
	if len(out) < 2 {
		return nil, fmt.Errorf("roads bos yanit")
	}
	return out, nil
}

func yolUzunlugu(p [][2]float64) float64 {
	var t float64
	for i := 1; i < len(p); i++ {
		t += kabaMetre(p[i-1][0], p[i-1][1], p[i][0], p[i][1])
	}
	return t
}

// polyKodla — Google encoded polyline (precision 5).
//
// ⚠️ Istemcideki `polyCoz` ve varlik uretecindeki `polyKodla` ile BIREBIR
//
//	ayni algoritma; biri degisirse otekiler de degismek ZORUNDA.
func polyKodla(p [][2]float64) string {
	var sb strings.Builder
	var sonLat, sonLon int
	for _, n := range p {
		lat := int(math.Round(n[0] * 1e5))
		lon := int(math.Round(n[1] * 1e5))
		kodlaSayi(&sb, lat-sonLat)
		kodlaSayi(&sb, lon-sonLon)
		sonLat, sonLon = lat, lon
	}
	return sb.String()
}

func kodlaSayi(sb *strings.Builder, v int) {
	u := uint(v << 1)
	if v < 0 {
		u = uint(^(v << 1))
	}
	for u >= 0x20 {
		sb.WriteByte(byte((0x20 | (u & 0x1f)) + 63))
		u >>= 5
	}
	sb.WriteByte(byte(u + 63))
}
