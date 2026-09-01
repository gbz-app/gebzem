// TURU 153 — ADRES ARAMA: **AUTOCOMPLETE + PLACE DETAILS**.
//
// Kullanici sikayeti (ekran goruntusuyle): *"aramada Mustafa Pasa Cami
// yazdigimda SACMA SAPAN SEYLER cikiyor, GOOGLE MAPS'TEKI GIBI olmali,
// BILINEN YERLER DIREK CIKMALI"*.
//
// ═══════════ ⚠️⚠️⚠️ NEDEN `searchText` YANLISTI ═══════════
//
// Turu 152'de `places:searchText` (Text Search) kullanilmisti. Google'in
// resmi dokumani bunu ACIKCA soyluyor: Text Search *"designed for completed
// search queries rather than partial, in-progress typing"*; Autocomplete ise
// *"can match on full words AND SUBSTRINGS of the input"*.
//
// Yani "Mustafa pasa" gibi YAZILMAKTA OLAN bir sorguda az/alakasiz sonuc
// gelmesinin sebebi `maxResultCount` degil, **ESLESME MANTIGIYDI**.
//
// ═══════════ ⚠️⚠️⚠️ VE DAHA ONEMLISI: FIYAT ═══════════
//
// Turu 152'de *"Places aylik 10.000 ucretsiz"* diye yazmistim — **YANLIS**.
// SKU alan maskesine gore belirleniyor ve o turdaki maske
// (`displayName` + `formattedAddress` + `location`) aramayi
// **Text Search PRO** yapiyordu:
//
//	Text Search Pro          : ayda  5.000 ucretsiz, sonra **$32 / 1.000**
//	Autocomplete Requests    : ayda 10.000 ucretsiz, sonra   $2.83 / 1.000
//	Autocomplete Session     : **SINIRSIZ UCRETSIZ**
//	Place Details Essentials : ayda 10.000 ucretsiz, sonra   $5.00 / 1.000
//
// Yani yeni akis hem DAHA IYI sonuc veriyor hem ~10 kat UCUZ.
//
// ═══════════ ⚠️⚠️ OTURUM JETONU (SESSION TOKEN) TUZAGI ═══════════
//
// Autocomplete istekleri bir "oturum" olusturur ve oturum bir **Place
// Details** cagrisiyla KAPANIR. Kapanisin TURU, o oturumdaki TUM autocomplete
// isteklerinin fiyatini belirler:
//
//	· Details **ESSENTIALS** ile kapanirsa -> autocomplete'ler ucuz/ucretsiz
//	· Details **PRO / ENTERPRISE** ile kapanirsa -> oturum
//	  **Enterprise + Atmosphere** olarak faturalanir: **$25 / 1.000** ve
//	  ayda yalnizca **1.000** ucretsiz — *"regardless of the fields
//	  requested"*.
//
// ⚠️⚠️⚠️ **BU YUZDEN `yerAlanMaskesi` ESSENTIALS DISINA CIKAMAZ.**
//
//	Details'te tek bir `displayName` (Pro alani) istemek bile TUM oturumu
//	$25/1.000'lik banda atlatir. Koordinat (`location`) Essentials'tadir ve
//	bize yeten TEK sey odur; ad/adres zaten autocomplete'ten geliyor.
//	⚠️ YAPMA: bu maskeye `displayName`, `formattedAddress`, `rating`,
//	   `photos` gibi alanlar ekleme.
//
// ⚠️ Jeton **ISTEMCIDE** uretilir (kullanici yazmaya baslayinca) ve secim
//
//	yapilinca ATILIR. Sunucu onu yalnizca Google'a GECIRIR — kendi
//	uretseydi tum kullanicilar tek oturumu paylasir ve faturalama bozulurdu.
package yolbul

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
)

// Bir arama onerisi.
//
// ⚠️ **KOORDINAT YOK — BILEREK.** Autocomplete koordinat DONDURMEZ; koordinat
//
//	yalnizca secim yapilinca `Yer` ucundan alinir. Boylece her harf icin
//	degil, YALNIZ SECIM icin Details faturalanir.
type oneri struct {
	Ad      string `json:"ad"`
	Adres   string `json:"adres"`
	MesafeM int    `json:"mesafe_m,omitempty"`
	YerID   string `json:"yer_id"`
}

// ⚠️⚠️ **ESSENTIALS DISINA CIKMAYACAK** (bkz. dosya serhi). Yalniz konum.
const yerAlanMaskesi = "location"

// Adres — `places:autocomplete`.
//
// ⚠️ **EN FAZLA 5 ONERI DONER** ve bunu artiran bir parametre YOKTUR
//
//	(resmi REST referansinda boyle bir alan yok). Kullanicinin gordugu
//	Google Maps listesi o uygulamanin KENDI ic servisidir, public API'de
//	uretilemez. Bu bir eksiklik degil, API'nin siniri.
//
// ⚠️ `origin` VERILIR: `distanceMeters` alani **yalnizca** origin varsa
//
//	doner. Kullanici listede "1,2 km" gormek istiyor.
//
// ⚠️ `includedRegionCodes` KULLANILMIYOR: set edilirse `queryPredictions`
//
//	donmuyor ve ileride onlari istersek sessizce kaybolurlardi.
//	Turkiye agirligi `regionCode` + `locationBias` ile saglaniyor.
func (h *Handler) Adres(w http.ResponseWriter, r *http.Request) {
	if h.kapali(w) {
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if len([]rune(q)) < 2 {
		yaz(w, http.StatusOK, map[string]any{"sonuclar": []oneri{}})
		return
	}
	if len(q) > 120 {
		q = q[:120]
	}
	enlem, _ := strconv.ParseFloat(r.URL.Query().Get("enlem"), 64)
	boylam, _ := strconv.ParseFloat(r.URL.Query().Get("boylam"), 64)
	oturum := strings.TrimSpace(r.URL.Query().Get("oturum"))

	// ⚠️ Onbellek anahtarinda OTURUM YOK: ayni sorgu farkli oturumlarda ayni
	//    sonucu verir ve onbellek isabeti FATURAYI DUSURUR.
	ck := fmt.Sprintf("yolbul:oneri:%s|%.2f,%.2f", strings.ToLower(q), enlem, boylam)
	if s, err := h.rdb.Get(r.Context(), ck).Result(); err == nil && s != "" {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, s)
		return
	}

	istek := map[string]any{
		"input":        q,
		"languageCode": "tr",
		"regionCode":   "TR",
	}
	if oturum != "" {
		istek["sessionToken"] = oturum
	}
	if enlem != 0 || boylam != 0 {
		istek["locationBias"] = map[string]any{
			"circle": map[string]any{
				"center": map[string]any{"latitude": enlem, "longitude": boylam},
				"radius": 30000.0,
			},
		}
		// ⚠️ `distanceMeters` icin ZORUNLU.
		istek["origin"] = map[string]any{"latitude": enlem, "longitude": boylam}
	}

	var yanit struct {
		Suggestions []struct {
			PlacePrediction struct {
				Place            string `json:"place"`
				PlaceID          string `json:"placeId"`
				DistanceMeters   int    `json:"distanceMeters"`
				StructuredFormat struct {
					MainText      struct{ Text string } `json:"mainText"`
					SecondaryText struct{ Text string } `json:"secondaryText"`
				} `json:"structuredFormat"`
				Text struct{ Text string } `json:"text"`
			} `json:"placePrediction"`
		} `json:"suggestions"`
	}
	// ⚠️ Autocomplete'te FieldMask BASLIGI KULLANILMAZ (Google bu ucta
	//    desteklemiyor); alan secimi govdedeki parametrelerle yapilir.
	err := h.google(r.Context(),
		"https://places.googleapis.com/v1/places:autocomplete", "", istek, &yanit)
	if err != nil {
		log.Printf("yolbul oneri: %v", err)
		yaz(w, http.StatusBadGateway, map[string]any{"error": "adres servisi yanıt vermedi"})
		return
	}

	out := make([]oneri, 0, len(yanit.Suggestions))
	for _, s := range yanit.Suggestions {
		p := s.PlacePrediction
		ad := p.StructuredFormat.MainText.Text
		if ad == "" {
			ad = p.Text.Text
		}
		if ad == "" || p.PlaceID == "" {
			continue
		}
		out = append(out, oneri{
			Ad:      ad,
			Adres:   p.StructuredFormat.SecondaryText.Text,
			MesafeM: p.DistanceMeters,
			YerID:   p.PlaceID,
		})
	}
	govde, _ := json.Marshal(map[string]any{"sonuclar": out})
	_ = h.rdb.Set(r.Context(), ck, string(govde), adresOmru).Err()
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(govde)
}

// Yer — secilen onerinin KOORDINATI (`places/{id}`, Place Details).
//
// ⚠️⚠️ Alan maskesi **YALNIZ `location`** (Essentials). Bkz. dosya serhindeki
//
//	oturum jetonu tuzagi: Pro/Enterprise bir alan istemek TUM oturumu
//	$25/1.000 bandina atlatir.
//
// ⚠️ Onbellek: ayni yer tekrar secilirse Details BIR DAHA faturalanmaz.
func (h *Handler) Yer(w http.ResponseWriter, r *http.Request) {
	if h.kapali(w) {
		return
	}
	id := strings.TrimSpace(r.URL.Query().Get("id"))
	// ⚠️ BICIM KAPISI: place id yalnizca harf/rakam/-/_ icerir. Serbest metin
	//    gecirmek Google'a anlamsiz istek atar ve BOSUNA faturalanir.
	if id == "" || len(id) > 300 || !yerIDGecerli(id) {
		yaz(w, http.StatusBadRequest, map[string]any{"error": "geçersiz yer"})
		return
	}
	oturum := strings.TrimSpace(r.URL.Query().Get("oturum"))

	ck := "yolbul:yer:" + id
	if s, err := h.rdb.Get(r.Context(), ck).Result(); err == nil && s != "" {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, s)
		return
	}

	url := "https://places.googleapis.com/v1/places/" + id
	if oturum != "" {
		url += "?sessionToken=" + oturum
	}
	var yanit struct {
		Location struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
		} `json:"location"`
	}
	if err := h.googleGet(r.Context(), url, yerAlanMaskesi, &yanit); err != nil {
		log.Printf("yolbul yer: %v", err)
		yaz(w, http.StatusBadGateway, map[string]any{"error": "yer bulunamadı"})
		return
	}
	if yanit.Location.Latitude == 0 && yanit.Location.Longitude == 0 {
		yaz(w, http.StatusBadGateway, map[string]any{"error": "yer bulunamadı"})
		return
	}
	govde, _ := json.Marshal(map[string]any{
		"enlem":  yanit.Location.Latitude,
		"boylam": yanit.Location.Longitude,
	})
	_ = h.rdb.Set(r.Context(), ck, string(govde), adresOmru).Err()
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(govde)
}

func yerIDGecerli(s string) bool {
	for _, c := range s {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
			(c >= '0' && c <= '9') || c == '-' || c == '_' {
			continue
		}
		return false
	}
	return true
}
