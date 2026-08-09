// Package ai — AI YARDIMCILARI (turu 77).
//
// Kullanici emri: "isletmeler urunlerini yukleyebilecek ya da ChatGPT
// yardimiyla AI gorsel, AI menu, AI ile tek tek fotograftan problemleri ...".
//
// ═══════════ ⚠️⚠️⚠️ ENV KAPISI — R2 KALIBININ BIREBIR AYNISI ═══════════
//
// AI UCRETLI bir dis servistir ve bu projede anahtar YOK. Bu yuzden ozellik
// TAMAMEN `OPENAI_API_KEY` kapisinin arkasindadir:
//
//	· anahtar YOKSA `Acik()` false doner, uclar 503 doner ve **istemci
//	  ozelligi HIC CIZMEZ** (`GET /ai/durum` ile sorar),
//	· acilista log: "ai: OPENAI_API_KEY yok — AI KAPALI" / "ai: aktif".
//
// ⚠️⚠️ TURU 75'IN BIREBIR TEKRARI RISKI: R2 anahtarlari sunucudaki `.env`e
//
//	yazilmis ama `docker-compose.yml`in **`environment:` blogu** guncellenmemis
//	ve medya SESSIZCE KAPALI kalmisti (/health "ok" donuyordu!).
//	`OPENAI_API_KEY` eklenirken **IKI YER** de guncellenmeli.
//	⚠️ YAPMA: yalniz `.env`e yazip birakma.
//
// ⚠️ GUVENLIK: istemci ASLA anahtari gormez; her istek sunucudan gecer.
// ⚠️ KOTA: AI ucretli — kullanici basina GUNLUK limit uygulanir, yoksa tek
//
//	kullanici bir gecede faturayi patlatir.
package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️ Gunluk kota — kullanici basina. Ucretli servis icin ZORUNLU emniyet.
const gunlukKota = 20

// ⚠️ Model adlari TEK YERDE. Gorsel analizi ve metin uretimi ayni modelle
//
//	yapiliyor (vision destekli) — ikinci bir model adi ikinci bir drift kaynagi.
const (
	modelMetin = "gpt-4o-mini"
	zamanAsimi = 60 * time.Second

	// ⚠️⚠️ TURU 79 — GORSEL URETIM MODELI.
	//
	//	`dall-e-3` SECILDI, `gpt-image-1` DEGIL: ikincisi bazi hesaplarda
	//	**kurulus dogrulamasi** istiyor ve dogrulanmamis bir hesapta 403 doner —
	//	yani ozellik sahada SESSIZCE olu olurdu. `dall-e-3` boyle bir kapi
	//	tasimiyor. Model adi TEK YERDE: degistirmek tek satir.
	//	⚠️ `response_format: "b64_json"` ZORUNLU (bkz. `GorselUret` serhi).
	modelGorsel = "dall-e-3"

	// Gorsel uretimi zaman asimi — metinden UZUN surer.
	gorselZamanAsimi = 120 * time.Second

	// ⚠️⚠️ GORSEL KOTASI METINDEN **AYRI VE COK DAHA DUSUK**.
	//
	//	Maliyet: dall-e-3 1024x1024 standart ~$0.040/gorsel; metin cagrisi
	//	~$0.001. Yani BIR gorsel ~40 metin cagrisina bedel. Gunluk 20 gorsel
	//	kullanici basina ~$0.80/gun eder ve odeme sistemi YOK.
	//	5 gorsel/gun (~$0.20) urun fotografi ihtiyacini karsilar, kotu niyetli
	//	kullanimda ise maliyeti sinirli tutar.
	// ⚠️ Sayim `tur='gorsel'` uzerinden AYRI yapilir; metin kotasini YEMEZ ve
	//    metin kotasi da gorseli kilitlemez.
	gunlukGorselKota = 5

	// Uretilen PNG icin ust sinir. ⚠️ `io.LimitReader` ile UYGULANIR: OpenAI
	// beklenmedik sekilde devasa bir govde donerse cx33'un RAM'ini yemesin.
	aiGorselTavani = 12 << 20 // 12 MB

	// Kota kontrolu icin tahmini boyut (1024x1024 PNG ~2-4 MB).
	aiGorselTahmini = 4 << 20
)

type Handler struct {
	db      *pgxpool.Pool
	anahtar string
	// Medya adresini cozmek icin geri cagirim. ⚠️ IKINCI BIR R2 ISTEMCISI
	// KURULMADI: ayri istemci = ayri imzalama yapilandirmasi = drift
	// (turu 77 denetim bulgusu Ç12).
	// ⚠️⚠️ Imza `sahipID` TASIR — AI yolu KULLANICININ KENDI medyasi disina
	//    cikamaz (turu 77b gizlilik bulgusu; ayrinti: media.ImzaliAdres serhi).
	medyaURL func(ctx context.Context, mediaID, sahipID string) (string, error)

	// ⚠️⚠️ TURU 79 — URETILEN GORSELI KAYDEDEN GERI CAGIRIM.
	//    `medyaURL` ile AYNI gerekce: AI paketi R2'ye ve `media_assets`e
	//    DOGRUDAN DOKUNMAZ (ikinci istemci = drift). Govde OpenAI'dan SUNUCUYA
	//    gelir; istemci ona hic dokunmaz.
	gorselKaydet func(ctx context.Context, sahipID, mime string, govde []byte) (string, error)

	// Uretimden ONCE depolama kotasi yeterli mi? ⚠️ ONCE sorulur: OpenAI cagrisi
	// PARA HARCAR, sonradan "yer yok" demek parayi bosa yakar.
	gorselIzni func(ctx context.Context, sahipID string, tahminiBayt int64) bool

	// ⚠️⚠️⚠️ MEDYA KATMANI GERCEKTEN ACIK MI (`media.Handler.Enabled`).
	//
	//    Bu alan ZORUNLU: `gorselKaydet != nil` kontrolu HICBIR SEY OLCMEZ
	//    cunku `mediaH.AIGorseliKaydet` bir METOT DEGERIDIR ve R2 kapali olsa
	//    bile ASLA nil olmaz. Ilk yazimda tam bu hataya dustum; sonuc:
	//    R2 env'i eksik bir kurulumda `/ai/durum` `gorsel:true` der, istemci
	//    dugmeyi CIZER ve kullanici basinca hata alirdi — projede alti kez
	//    tekrarlayan "ozellik var gorunup fiilen yok" sinifinin yenisi.
	// ⚠️ YAPMA: bunu tekrar `!= nil` kontroluyle degistirme.
	medyaAcik func() bool
}

func NewHandler(db *pgxpool.Pool,
	medyaURL func(context.Context, string, string) (string, error),
	gorselKaydet func(context.Context, string, string, []byte) (string, error),
	gorselIzni func(context.Context, string, int64) bool,
	medyaAcik func() bool) *Handler {
	a := strings.TrimSpace(os.Getenv("OPENAI_API_KEY"))
	h := &Handler{
		db: db, anahtar: a, medyaURL: medyaURL,
		gorselKaydet: gorselKaydet, gorselIzni: gorselIzni, medyaAcik: medyaAcik,
	}
	switch {
	case a == "":
		log.Printf("ai: OPENAI_API_KEY yok — AI KAPALI")
	case !h.GorselAcik():
		// ⚠️ GORUNUR OLMALI: metin calisir ama gorsel calismaz. Sessiz kalsaydi
		//    "AI acik ama gorsel dugmesi yok" teshisi imkansiz olurdu.
		log.Printf("ai: aktif (metin %s) — GORSEL KAPALI (medya kapali)", modelMetin)
	default:
		log.Printf("ai: aktif (metin %s · gorsel %s)", modelMetin, modelGorsel)
	}
	return h
}

// GorselAcik — gorsel uretimi kullanilabilir mi?
//
// ⚠️ Anahtar VAR ama medya KAPALI ise (R2 env eksik) gorsel URETILEMEZ: uretilen
//
//	bayti koyacak yer yoktur. Istemci `/ai/durum`daki `gorsel` bayragina bakip
//	dugmeyi HIC CIZMEZ — "ozellik var gorunup fiilen yok" hatasina dusmemek icin.
func (h *Handler) GorselAcik() bool {
	return h.Acik() && h.gorselKaydet != nil &&
		h.medyaAcik != nil && h.medyaAcik()
}

func (h *Handler) Acik() bool { return h.anahtar != "" }

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, m string) {
	yaz(w, kod, map[string]string{"error": m})
}

// GET /ai/durum — istemci ozelligi CIZMEDEN ONCE bunu sorar.
//
// ⚠️ Bu uc OLMASAYDI istemci AI dugmelerini cizer, kullanici basar ve 503
//
//	alirdi — "ozellik var gorunup fiilen yok" hatasinin ta kendisi.
func (h *Handler) Durum(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	kalan, gorselKalan := 0, 0
	if h.Acik() {
		if k := gunlukKota - h.bugunKullanilan(r.Context(), me, false); k > 0 {
			kalan = k
		}
		if k := gunlukGorselKota - h.bugunKullanilan(r.Context(), me, true); k > 0 {
			gorselKalan = k
		}
	}
	yaz(w, 200, map[string]any{
		"acik": h.Acik(), "gunluk_kota": gunlukKota, "kalan": kalan,
		// ⚠️⚠️ TURU 79 — GORSEL AYRI BAYRAK VE AYRI SAYAC.
		//    `gorsel` yalniz `Acik()`e bakmaz: anahtar VAR ama medya KAPALI ise
		//    (R2 env eksik) uretilen bayti koyacak yer YOKTUR. Istemci bu
		//    bayraga bakip dugmeyi HIC CIZMEZ.
		"gorsel":             h.GorselAcik(),
		"gorsel_gunluk_kota": gunlukGorselKota,
		"gorsel_kalan":       gorselKalan,
	})
}

// ⚠️⚠️ `durum <> 'iptal'` — YALNIZ 'tamam' DEGIL (turu 77b denetim bulgusu).
//
//	'tamam' sayilsaydi (a) rezerve edilmis ('beklemede') istekler
//	sayilmaz ve kota asilirdi, (b) zaman asimina ugrayan istek OpenAI
//	tarafinda ISLENIP FATURALANMIS olabilecegi halde kotadan dusmezdi.
//
// ⚠️ TURU 79 — [gorsel] ile AYRISIR; `kapi()`deki sayimla AYNI yuklem
//
//	kullanilir (ikisi ayrilirsa kullaniciya gosterilen "kalan" ile gercek
//	kota BIRBIRINI TUTMAZ — CLAUDE.md "ayni kuralin iki kopyasi drift eder").
func (h *Handler) bugunKullanilan(ctx context.Context, me string, gorsel bool) int {
	var n int
	h.db.QueryRow(ctx, `
		SELECT count(*)::int FROM ai_istekleri
		 WHERE user_id=$1 AND durum <> 'iptal'
		   AND ($2 = (tur = 'gorsel'))
		   AND created_at > now() - interval '24 hours'`, me, gorsel).Scan(&n)
	return n
}

// Ortak kapi: acik mi + kota var mi. Kota varsa **REZERVASYON** acar.
//
// ⚠️⚠️⚠️ REZERVASYON ZORUNLU — YOKSA KOTA FIILEN YOKTUR (turu 77b bulgusu).
//
//	Onceki surumde `kapi()` yalnizca `SELECT count(*)` okuyordu ve sayaci
//	artiran `kaydet()` **OpenAI cagrisi DONDUKTEN SONRA** (60 sn'ye kadar)
//	kosuyordu. O pencerede atilan TUM istekler ayni bayat sayiyi gorur:
//	100 escamanli `POST /ai/danisma` -> 100'u de `count=0` gorur -> 100'u de
//	OpenAI'ya gider ve FATURALANIR. Kota 20 degil, pratikte SINIRSIZDI.
//	`031_urun_ai.sql` serhi "kota olmadan tek kullanici bir gecede faturayi
//	patlatir" diyor; kontrol yazilmisti ama bu haliyle o isi GORMUYORDU.
//
//	COZUM: satir cagridan **ONCE** `beklemede` ile acilir (rezervasyon) ve
//	sayim TEK DEYIMDE, `INSERT ... SELECT ... WHERE (SELECT count(*)) < kota`
//	ile yapilir -> Postgres seviyesinde atomiktir, ayri bir transaction
//	yonetimi gerekmez.
//	⚠️ YAPMA: rezervasyonu cagrinin ALTINA tasima; sayimi `kaydet` icine geri koyma.
//
// Donen: (kullanici, istek id'si, tamam mi).
func (h *Handler) kapi(w http.ResponseWriter, r *http.Request, tur string) (string, int64, bool) {
	if !h.Acik() {
		// ⚠️ 503 + ACIK mesaj: istemci bunu kullaniciya AYNEN gosterir.
		hata(w, 503, "Yapay zekâ şu anda kullanılamıyor")
		return "", 0, false
	}
	me := auth.UserID(r.Context())
	// ⚠️⚠️ TURU 79 — GORSEL KOTASI **AYRI SAYILIR**.
	//
	//    Bir gorsel ~40 metin cagrisina bedel (bkz. `gunlukGorselKota` serhi).
	//    Tek havuz kullanilsaydi ya metin kotasi gereksiz kisilirdi ya da 20
	//    gorsel/gun (~$0.80/kullanici) serbest kalirdi.
	//    ⚠️ Sayim `tur` uzerinden AYRISIR: gorsel istekleri metin kotasini
	//       YEMEZ, metin istekleri de gorseli kilitlemez.
	kota := gunlukKota
	gorselMi := tur == "gorsel"
	if gorselMi {
		kota = gunlukGorselKota
	}
	var id int64
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO ai_istekleri (user_id, tur, girdi, sonuc, durum)
		SELECT $1, $2, '', '', 'beklemede'
		 WHERE (SELECT count(*) FROM ai_istekleri
		         WHERE user_id=$1 AND durum <> 'iptal'
		           AND ($4 = (tur = 'gorsel'))
		           AND created_at > now() - interval '24 hours') < $3
		RETURNING id`, me, tur, kota, gorselMi).Scan(&id)
	// ⚠️⚠️ TURU 78 — HATA TURU AYIRT EDILIR. Eskiden HER hata "kota doldu"
	//    sayiliyordu ve bu YANILTICIYDI: migration 031'in CHECK'i 'beklemede'
	//    degerini KABUL ETMIYORDU (036 ile duzeltildi), yani AI acildigi ANDA
	//    herkes HENUZ TEK ISTEK BILE ATMAMISKEN "Günlük hakkın doldu" mesaji
	//    alacakti. Kullanici bekleyerek cozmeye calisir, sorun ASLA gecmezdi.
	// ⚠️ `pgx.ErrNoRows` = sorgu KOSTU ama satir donmedi = GERCEKTEN kota dolu.
	//    Baska her hata SUNUCU sorunudur ve OYLE raporlanmali + LOGLANMALI.
	if errors.Is(err, pgx.ErrNoRows) {
		// ⚠️ Mesaj TURE GORE ayrisir: gorsel hakki bitince "yapay zekâ hakkın
		//    doldu" demek YANILTICI olurdu (metin hakki DURUYOR olabilir).
		if gorselMi {
			hata(w, 429, "Günlük görsel oluşturma hakkın doldu (5), yarın tekrar dene")
		} else {
			hata(w, 429, "Günlük yapay zekâ hakkın doldu, yarın tekrar dene")
		}
		return "", 0, false
	}
	if err != nil {
		log.Printf("ai kota rezervasyonu: %v", err)
		hata(w, 500, "Yapay zekâ şu anda kullanılamıyor")
		return "", 0, false
	}
	return me, id, true
}

// Rezervasyonu SONUCLANDIRIR. `durum='iptal'` ise kotadan DUSER.
//
// ⚠️ `id == 0` ise (rezervasyon acilamadi) hicbir sey yapilmaz.
func (h *Handler) kaydet(ctx context.Context, id int64, girdi, sonuc, durum string) {
	if id == 0 {
		return
	}
	h.db.Exec(ctx, `
		UPDATE ai_istekleri SET girdi=$2, sonuc=$3, durum=$4 WHERE id=$1`,
		id, girdi, sonuc, durum)
}

// ---------------------------------------------------------------- OPENAI

type icerikParca struct {
	Tip    string     `json:"type"`
	Metin  string     `json:"text,omitempty"`
	Gorsel *gorselURL `json:"image_url,omitempty"`
}

type gorselURL struct {
	URL string `json:"url"`
}

// OpenAI Chat Completions cagrisi (vision destekli).
//
// ⚠️ HARICI SDK EKLENMEDI: tek bir POST istegi icin `openai-go` bagimliligi
//
//	almak (ve onun gecis surumleriyle ugrasmak) bu projede gereksiz risk.
//	`net/http` yeterli.
func (h *Handler) sor(ctx context.Context, sistem string,
	parcalar []icerikParca) (string, error) {
	govde := map[string]any{
		"model": modelMetin,
		"messages": []map[string]any{
			{"role": "system", "content": sistem},
			{"role": "user", "content": parcalar},
		},
		"max_tokens": 900,
	}
	ham, _ := json.Marshal(govde)
	ctx, iptal := context.WithTimeout(ctx, zamanAsimi)
	defer iptal()
	req, err := http.NewRequestWithContext(ctx, "POST",
		"https://api.openai.com/v1/chat/completions", bytes.NewReader(ham))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+h.anahtar)
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	govdeHam, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if res.StatusCode != 200 {
		// ⚠️ HATA YUTULMAZ: log'a GERCEK yanit yazilir. Bu projede "yutulan
		//    hata + breadcrumb-only log" tekrarlayan kok neden (turu 50·56·60·63·64).
		log.Printf("ai: openai %d: %s", res.StatusCode,
			string(govdeHam[:min(300, len(govdeHam))]))
		return "", fmt.Errorf("openai %d", res.StatusCode)
	}
	var yanit struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if json.Unmarshal(govdeHam, &yanit) != nil || len(yanit.Choices) == 0 {
		return "", fmt.Errorf("boş yanıt")
	}
	return strings.TrimSpace(yanit.Choices[0].Message.Content), nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Medya id'sini OpenAI'nin okuyabilecegi bir gorsel adresine cevirir.
//
// ⚠️ IMZALI ADRES kullanilir (medya bucket'i GIZLI). Adres kisa omurludur ve
//
//	OpenAI onu istek sirasinda indirir.
func (h *Handler) gorselAdresi(ctx context.Context, mediaID, sahipID string) (string, error) {
	if h.medyaURL == nil {
		return "", fmt.Errorf("medya kapalı")
	}
	return h.medyaURL(ctx, mediaID, sahipID)
}

// ---------------------------------------------------------------- UCLAR

type aiReq struct {
	MediaID string `json:"media_id"`
	Metin   string `json:"metin"`
}

// ⚠️⚠️ TURU 78 — GIRDI SINIRI. `req.Metin` HICBIR YERDE sinirlanmiyordu
//
//	(turu 77b denetim bulgusu) ve iki yere tam boyuyla gidiyordu:
//	  · OpenAI istek govdesine  -> TOKEN maliyeti dogrudan faturaya yansir
//	  · `ai_istekleri.girdi TEXT` sutununa -> DB sisirme
//	Tek bir kullanici 5 MB'lik bir metin gonderip hem faturayi hem diski
//	zorlayabilirdi. 2000 karakter bir menu/urun tarifi icin FAZLASIYLA yeterli.
//
// ⚠️ RUNE ile kirpilir, BAYT ile DEGIL: Turkce harfler UTF-8'de iki bayttir ve
//
//	bayt dilimi gecersiz UTF-8 uretip JSON'da bozuk karakter yapar (turu 78
//	FAZ 0'da push onizlemesinde tam bu yasandi).
const metinTavani = 2000

func metniKirp(s string) string {
	s = strings.TrimSpace(s)
	r := []rune(s)
	if len(r) <= metinTavani {
		return s
	}
	return string(r[:metinTavani])
}

// POST /ai/menu — MENU FOTOGRAFINDAN ya da ACIKLAMADAN yapilandirilmis menu.
//
// Donen bicim: {"urunler":[{"ad":"...","aciklama":"...","fiyat_kurus":12500,
// "bolum":"..."}]}
//
// ⚠️ Sonuc DOGRUDAN KAYDEDILMEZ — istemciye ONERI olarak doner, kullanici
//
//	gozden gecirip onaylar. Otomatik kaydetmek, yanlis okunan bir fiyati
//	sessizce menuye yazardi.
func (h *Handler) Menu(w http.ResponseWriter, r *http.Request) {
	_, istekID, ok := h.kapi(w, r, "menu")
	if !ok {
		return
	}
	var req aiReq
	json.NewDecoder(r.Body).Decode(&req)
	// TURU 78: girdi tavani (bkz. metinTavani serhi).
	req.Metin = metniKirp(req.Metin)

	parcalar := []icerikParca{{
		Tip: "text",
		Metin: "Bu menüyü yapılandırılmış JSON'a çevir. YALNIZCA şu biçimde " +
			"JSON döndür, başka hiçbir şey yazma:\n" +
			`{"urunler":[{"ad":"","aciklama":"","bolum":"","fiyat_kurus":0}]}` +
			"\nfiyat_kurus KURUŞ cinsindendir (12,50 TL = 1250). " +
			"Fiyatı okunamayan ürünlerde fiyat_kurus 0 yaz. " +
			"Ürün adlarını Türkçe ve olduğu gibi yaz.",
	}}
	if req.Metin != "" {
		parcalar = append(parcalar, icerikParca{
			Tip: "text", Metin: "İşletme açıklaması: " + req.Metin,
		})
	}
	if req.MediaID != "" {
		u, err := h.gorselAdresi(r.Context(), req.MediaID, auth.UserID(r.Context()))
		if err != nil {
			hata(w, 400, "görsel okunamadı")
			return
		}
		parcalar = append(parcalar, icerikParca{
			Tip: "image_url", Gorsel: &gorselURL{URL: u},
		})
	}
	if req.Metin == "" && req.MediaID == "" {
		hata(w, 400, "menü fotoğrafı ya da açıklama gerekli")
		return
	}

	sonuc, err := h.sor(r.Context(),
		"Sen bir restoran menüsü düzenleyicisisin. Yalnızca geçerli JSON dönersin.",
		parcalar)
	if err != nil {
		h.kaydet(r.Context(), istekID, req.Metin, err.Error(), "hata")
		hata(w, 502, "Yapay zekâ şu anda yanıt veremedi")
		return
	}
	h.kaydet(r.Context(), istekID, req.Metin, sonuc, "tamam")
	// ⚠️ Model bazen JSON'u ``` blogu icinde dondurur — temizlenir.
	yaz(w, 200, map[string]any{"sonuc": jsonTemizle(sonuc)})
}

// POST /ai/urun-metni — urun fotografindan/adindan ACIKLAMA + BASLIK onerisi.
//
// ⚠️ "AI GORSEL" olarak istenen sey, gorsel URETMEK degil GORSELI ANLAMAKTIR:
//
//	kullanici urun fotografini ceker, AI ondan satis metni yazar. Gercek
//	gorsel uretimi (DALL·E) ayri bir maliyet kalemi ve urun karari; bu surumde
//	YOK ve istemcide de VAAT EDILMIYOR.
func (h *Handler) UrunMetni(w http.ResponseWriter, r *http.Request) {
	_, istekID, ok := h.kapi(w, r, "gorsel")
	if !ok {
		return
	}
	var req aiReq
	json.NewDecoder(r.Body).Decode(&req)
	// TURU 78: girdi tavani (bkz. metinTavani serhi).
	req.Metin = metniKirp(req.Metin)
	if req.MediaID == "" && strings.TrimSpace(req.Metin) == "" {
		hata(w, 400, "ürün fotoğrafı ya da adı gerekli")
		return
	}
	parcalar := []icerikParca{{
		Tip: "text",
		Metin: "Bu ürün için kısa ve satış odaklı bir Türkçe açıklama yaz " +
			"(en fazla 2 cümle). Abartma, uydurma özellik ekleme. " +
			"YALNIZCA açıklamayı yaz.",
	}}
	if req.Metin != "" {
		parcalar = append(parcalar, icerikParca{
			Tip: "text", Metin: "Ürün adı: " + req.Metin,
		})
	}
	if req.MediaID != "" {
		u, err := h.gorselAdresi(r.Context(), req.MediaID, auth.UserID(r.Context()))
		if err != nil {
			hata(w, 400, "görsel okunamadı")
			return
		}
		parcalar = append(parcalar, icerikParca{
			Tip: "image_url", Gorsel: &gorselURL{URL: u},
		})
	}
	sonuc, err := h.sor(r.Context(),
		"Sen bir e-ticaret metin yazarısın. Kısa, dürüst ve Türkçe yazarsın.",
		parcalar)
	if err != nil {
		h.kaydet(r.Context(), istekID, req.Metin, err.Error(), "hata")
		hata(w, 502, "Yapay zekâ şu anda yanıt veremedi")
		return
	}
	h.kaydet(r.Context(), istekID, req.Metin, sonuc, "tamam")
	yaz(w, 200, map[string]any{"sonuc": sonuc})
}

// POST /ai/danisma — FOTOGRAFTAN SORUN TESPITI (kullanici: "AI ile tek tek
// fotograftan problemleri ...").
//
// ⚠️ SAGLIK/HUKUK TAVSIYESI VERILMEZ: sistem mesaji modeli teknik/pratik
//
//	tespit ile sinirliyor ve emin olmadigi yerde "uzmana danis" demesini
//	istiyor. Yanlis bir tibbi/hukuki tavsiye gercek zarar dogurur.
func (h *Handler) Danisma(w http.ResponseWriter, r *http.Request) {
	_, istekID, ok := h.kapi(w, r, "danisma")
	if !ok {
		return
	}
	var req aiReq
	json.NewDecoder(r.Body).Decode(&req)
	// TURU 78: girdi tavani (bkz. metinTavani serhi).
	req.Metin = metniKirp(req.Metin)
	if req.MediaID == "" {
		hata(w, 400, "fotoğraf gerekli")
		return
	}
	u, err := h.gorselAdresi(r.Context(), req.MediaID, auth.UserID(r.Context()))
	if err != nil {
		hata(w, 400, "görsel okunamadı")
		return
	}
	parcalar := []icerikParca{
		{
			Tip: "text",
			Metin: "Bu fotoğraftaki sorunu tespit et ve ne yapılması gerektiğini " +
				"maddeler hâlinde, sade Türkçe ile anlat. Emin olmadığın yerde " +
				"açıkça 'emin değilim' de ve bir uzmana danışılmasını öner.",
		},
		{Tip: "image_url", Gorsel: &gorselURL{URL: u}},
	}
	if req.Metin != "" {
		parcalar = append(parcalar, icerikParca{
			Tip: "text", Metin: "Ek bilgi: " + req.Metin,
		})
	}
	sonuc, err := h.sor(r.Context(),
		"Sen pratik bir teknik danışmansın. Sağlık ve hukuk konularında tavsiye "+
			"VERMEZSİN, uzmana yönlendirirsin. Kısa ve maddeli yazarsın.",
		parcalar)
	if err != nil {
		h.kaydet(r.Context(), istekID, req.Metin, err.Error(), "hata")
		hata(w, 502, "Yapay zekâ şu anda yanıt veremedi")
		return
	}
	h.kaydet(r.Context(), istekID, req.Metin, sonuc, "tamam")
	yaz(w, 200, map[string]any{"sonuc": sonuc})
}

// Model yanitindaki ``` bloklarini temizler.
func jsonTemizle(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "```") {
		if i := strings.Index(s, "\n"); i > 0 {
			s = s[i+1:]
		}
		s = strings.TrimSuffix(strings.TrimSpace(s), "```")
	}
	return strings.TrimSpace(s)
}

var _ = base64.StdEncoding
