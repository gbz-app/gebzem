package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 79 — YAPAY ZEKA ILE GORSEL URETME.
//
// Kullanici emri (turu 77'den beri listede): *"AI gorsel"*, ve turu 79'da
// acikca: *"tamamda olacak dedim ya"*. Turu 77/78'de yalniz METIN uclari
// baglanmisti; bu dosya eksigi kapatiyor.
//
// ═══════════════ AKIS ═══════════════
//
//	POST /ai/gorsel {metin}
//	  -> kota rezervasyonu (AYRI ve DUSUK gorsel kotasi)
//	  -> DEPOLAMA kotasi kontrolu (uretimden ONCE!)
//	  -> OpenAI images/generations (b64_json)
//	  -> baytlar SUNUCUDAN R2'ye yazilir + `media_assets` satiri 'aktif' dogar
//	  -> {media_id} doner; istemci onu ZATEN bildigi `MedyaGorsel` ile cizer
//
// ⚠️ ISTEMCIYE URL DEGIL **media_id** DONER. URL donseydi (a) imzali adres
//
//	kisa omurlu oldugu icin kullanici gorseli kaydedemeden ölürdü, (b) istemci
//	o URL'yi bir yere yazsa medya kaydi olmadan yetim kalirdi. `media_id`
//	mevcut TUM medya boru hattina (erisim dallari, kota, silme kuyrugu) oturur.
//
// ⚠️⚠️ URETILEN GORSEL **HICBIR YERE OTOMATIK BAGLANMAZ**. Kullanici onay
//
//	ekraninda gorur ve isterse urune/ilana ekler. Otomatik baglamak, modelin
//	uydurdugu bir gorseli kullanicinin haberi olmadan yayina sokmak olurdu
//	(menu onerisindeki ayni ilke).
type gorselReq struct {
	Metin string `json:"metin"`
}

// OpenAI images/generations yaniti.
// ⚠️ `response_format:"b64_json"` istendigi icin `URL` alani BOS gelir; yine de
//
//	tanimli — model/politika degisirse SESSIZ nil deref yerine ACIK hata verelim.
type gorselYanit struct {
	Data []struct {
		B64 string `json:"b64_json"`
		URL string `json:"url"`
	} `json:"data"`
	Error *struct {
		Message string `json:"message"`
		Code    string `json:"code"`
	} `json:"error"`
}

// ⚠️⚠️ URUN FOTOGRAFI ICIN SABIT CERCEVE.
//
//	Kullanicinin yazdigi metin SERBESTTIR ama sonucun "urun fotografi" gibi
//	gorunmesi urun karari. Cerceve olmadan model illustrasyon/karikatur
//	uretebiliyor ve katalogda YABANCI duruyor.
//
// ⚠️ Metin cercevenin ICINE gomulur; cerceveyi EZEMEZ cunku talimat SONDA
//
//	tekrarlanir (basit ama etkili bir prompt-injection savunmasi).
const gorselCerceve = "Profesyonel ürün fotoğrafı: %s. " +
	"Sade ve temiz arka plan, doğal ve yumuşak ışık, yemek/ürün fotoğrafçılığı " +
	"stili, gerçekçi. Görselde YAZI, LOGO, MARKA veya filigran OLMASIN."

// POST /ai/gorsel — metinden urun gorseli uretir.
func (h *Handler) Gorsel(w http.ResponseWriter, r *http.Request) {
	// ⚠️ AYRI KAPI: anahtar VAR ama medya KAPALI ise uretilen bayti koyacak yer
	//    yoktur. `kapi()` bunu bilmez, bu yuzden BURADA kontrol edilir.
	if !h.GorselAcik() {
		hata(w, 503, "Görsel oluşturma şu anda kullanılamıyor")
		return
	}
	var req gorselReq
	if json.NewDecoder(io.LimitReader(r.Body, 1<<16)).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Metin = metniKirp(req.Metin)
	if strings.TrimSpace(req.Metin) == "" {
		hata(w, 400, "Ne çizilmesini istediğini yaz")
		return
	}

	me := auth.UserID(r.Context())

	// ⚠️⚠️ DEPOLAMA KOTASI **URETIMDEN ONCE** SORULUR. Sonra sorulsaydi para
	//    harcanir, gorsel uretilir ve "yerin yok" denip ATILIRDI.
	if h.gorselIzni != nil && !h.gorselIzni(r.Context(), me, aiGorselTahmini) {
		hata(w, 413, "Depolama alanın dolu, yer açıp tekrar dene")
		return
	}

	// AI kotasi (gorsel icin AYRI ve DUSUK) — atomik rezervasyon.
	_, istekID, ok := h.kapi(w, r, "gorsel")
	if !ok {
		return
	}

	ham, err := h.gorselUret(r.Context(), req.Metin)
	if err != nil {
		h.kaydet(context.WithoutCancel(r.Context()), istekID, req.Metin, "", "hata")
		log.Printf("ai gorsel uretimi: %v", err)
		// ⚠️ ICERIK POLITIKASI hatasi AYIRT EDILIR: kullanici "sunucu bozuk"
		//    sanmasin, ne yapmasi gerektigini bilsin.
		if strings.Contains(strings.ToLower(err.Error()), "content_policy") ||
			strings.Contains(strings.ToLower(err.Error()), "safety") {
			hata(w, 400, "Bu isteği çizemiyorum, farklı bir şekilde anlat")
			return
		}
		hata(w, 502, "Görsel oluşturulamadı, tekrar dene")
		return
	}

	// ⚠️ `WithoutCancel`: istemci tam bu anda kapanirsa bile URETILMIS gorsel
	//    kaydedilmeli — aksi halde para harcanmis ama sonuc kaybolmus olur.
	ctx := context.WithoutCancel(r.Context())
	mediaID, err := h.gorselKaydet(ctx, me, "image/png", ham)
	if err != nil {
		h.kaydet(ctx, istekID, req.Metin, "", "hata")
		log.Printf("ai gorsel kaydi: %v", err)
		hata(w, 500, "Görsel kaydedilemedi")
		return
	}

	h.kaydet(ctx, istekID, req.Metin, mediaID, "tamam")
	yaz(w, 200, map[string]any{"media_id": mediaID})
}

// gorselUret — OpenAI images/generations cagrisi. PNG baytlarini DONER.
//
// ⚠️⚠️ `response_format: "b64_json"` ZORUNLU. Varsayilan `url` olsaydi sunucunun
//
//	o adresi AYRICA indirmesi gerekirdi: fazladan bir ag turu, fazladan bir
//	hata yolu ve OpenAI'nin gecici CDN adresi (1 saat) ile YARIS. Base64 ile
//	govde TEK cagrida elimize gelir.
//
// ⚠️ `LimitReader` SART: beklenmedik devasa bir yanit cx33'un RAM'ini yemesin.
func (h *Handler) gorselUret(ctx context.Context, metin string) ([]byte, error) {
	// ⚠️⚠️⚠️ `response_format` **GONDERILMEZ** (canli sunucuda kanitlandi).
	//
	//	Ilk surumde `"response_format": "b64_json"` gonderiliyordu ve OpenAI
	//	**400 "Unknown parameter: 'response_format'"** dondu — yani parametre
	//	images ucunda ARTIK YOK. Gondermek ozelligi TAMAMEN oldururdu.
	//
	// ⚠️ Bu yuzden yanit IKI BICIMDE de gelebilir ve IKISI DE desteklenir:
	//    `b64_json` (dogrudan bayt) ya da `url` (sunucu INDIRIR).
	//    Tek bicime bel baglamak, API'nin bir sonraki degisiminde ozelligi
	//    yine sessizce oldururdu.
	govde, _ := json.Marshal(map[string]any{
		"model":  modelGorsel,
		"prompt": fmt.Sprintf(gorselCerceve, metin),
		"n":      1,
		"size":   "1024x1024",
	})

	c, iptal := context.WithTimeout(ctx, gorselZamanAsimi)
	defer iptal()
	req, err := http.NewRequestWithContext(c, http.MethodPost,
		"https://api.openai.com/v1/images/generations", bytes.NewReader(govde))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+h.anahtar)
	req.Header.Set("Content-Type", "application/json")

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	ham, _ := io.ReadAll(io.LimitReader(res.Body, aiGorselTavani))
	var y gorselYanit
	if json.Unmarshal(ham, &y) != nil {
		return nil, fmt.Errorf("gorsel yaniti ayristirilamadi (HTTP %d)", res.StatusCode)
	}
	if y.Error != nil {
		// ⚠️ Kod da tasinir: cagiran taraf `content_policy` ayrimini BUNDAN yapar.
		return nil, fmt.Errorf("openai: %s (%s)", y.Error.Message, y.Error.Code)
	}
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("openai HTTP %d", res.StatusCode)
	}
	if len(y.Data) == 0 {
		return nil, fmt.Errorf("openai bos gorsel dondu")
	}

	// ⚠️⚠️ IKI BICIM DE DESTEKLENIR (bkz. istek govdesindeki serh):
	//    (a) `b64_json` -> bayt ELIMIZDE,
	//    (b) `url`      -> sunucu INDIRIR (OpenAI'nin adresi ~1 saat gecerli).
	var png []byte
	switch {
	case y.Data[0].B64 != "":
		var derr error
		png, derr = base64.StdEncoding.DecodeString(y.Data[0].B64)
		if derr != nil {
			return nil, fmt.Errorf("base64 cozulemedi: %w", derr)
		}
	case y.Data[0].URL != "":
		var ierr error
		png, ierr = h.gorseliIndir(c, y.Data[0].URL)
		if ierr != nil {
			return nil, fmt.Errorf("gorsel indirilemedi: %w", ierr)
		}
	default:
		return nil, fmt.Errorf("openai ne b64 ne url dondu")
	}
	if len(png) == 0 {
		return nil, fmt.Errorf("bos gorsel govdesi")
	}
	// ⚠️ SIHIRLI BAYT KONTROLU: gelen seyin GERCEKTEN PNG oldugunu dogrula.
	//    `mime: image/png` diye kaydedip baska bir sey yazmak, istemcide KIRIK
	//    GORSEL olarak cikardi ve sebebi aylarca bulunamazdi.
	if len(png) < 8 || string(png[1:4]) != "PNG" {
		return nil, fmt.Errorf("donen govde PNG degil")
	}
	return png, nil
}

// gorseliIndir — OpenAI'nin dondurdugu gecici adresten baytlari ceker.
//
// ⚠️ YALNIZ `b64_json` GELMEDIGINDE kullanilir. Adres ~1 saat gecerlidir ve
//
//	istemciye VERILMEZ: kaydedilmemis bir adres kullanicinin elinde olurken
//	suresi dolar ve gorsel "kayboldu" gorunurdu.
//
// ⚠️ `LimitReader` SART (cx33'un RAM'i) ve ayni `ctx` kullanilir — uretim
//
//	zaman asimi indirmeyi de KAPSAR, boylece toplam sure sinirli kalir.
func (h *Handler) gorseliIndir(ctx context.Context, adres string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, adres, nil)
	if err != nil {
		return nil, err
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", res.StatusCode)
	}
	return io.ReadAll(io.LimitReader(res.Body, aiGorselTavani))
}
