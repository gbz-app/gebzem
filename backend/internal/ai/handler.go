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

	// ⚠️⚠️⚠️ TURU 79 — GORSEL URETIM MODELI: **HESABIN MODEL LISTESINDEN SECILDI.**
	//
	//	Ilk yazimda `dall-e-3` secilmisti ("yaygin, dogrulama istemiyor" diye).
	//	CANLI SUNUCU onu curuttu:
	//	    openai: The model 'dall-e-3' does not exist. (invalid_value)
	//	Yani model ARTIK YOK. `GET /v1/models` ile hesabin GERCEKTEN erisebildigi
	//	gorsel modelleri listelendi: gpt-image-1 · gpt-image-1.5 · gpt-image-2 ·
	//	gpt-image-1-mini · chatgpt-image-latest.
	//
	//	Ilk secim `gpt-image-1-mini` + `quality:"medium"` idi (ailenin EN UCUZ
	//	uyesi, "urun fotografi icin yeterli" varsayimiyla). **KULLANICI SAHADA
	//	CURUTTU: "cok kotu resimler uretiyor."**
	//
	// ⚠️⚠️ TURU 79c — AYNI ISTEMLE UC MODEL YAN YANA URETILDI ve GOZLE
	//
	//	karsilastirildi (tahmin DEGIL, olcum):
	//	  · gpt-image-1-mini / medium : zayif  —  ~21 sn
	//	  · gpt-image-1.5    / high   : COK IYI — ~38 sn   <-- SECILDI
	//	  · gpt-image-2      / high   : cok iyi — **132 sn**
	//
	//	`gpt-image-2` KULLANILMADI: 132 sn sunucu tavaninin (120 sn) USTUNDE,
	//	yani oldugu gibi kullanilsa HER cagri zaman asimina duserdi. Tavani
	//	yukseltmek de cozum degil — kullaniciyi 2+ DAKIKA bekletmek urun
	//	olarak kabul edilemez.
	//
	// ⚠️ DERS: dis servisin model adini VARSAYMA — `/v1/models` ile DOGRULA.
	//    Bu tur, bir varsayimin canli sunucuda IKI KEZ curutulmesiyle gecti
	//    (`response_format` parametresi ve model adi), UCUNCUSUNU de kullanici
	//    curuttu (kalite). ⚠️ Model/kalite secimini GOZLE dogrulamadan degistirme.
	modelGorsel = "gpt-image-1.5"

	// ⚠️ `quality` gpt-image ailesinde GECERLI (canli dogrulandi).
	//    "high" secildi: kullanici sikayeti tam da KALITE uzerineydi ve fark
	//    yan yana bakildiginda BUYUK. Maliyeti gunluk kota (10) sinirliyor.
	gorselKalite = "high"

	// Gorsel uretimi zaman asimi — metinden UZUN surer.
	gorselZamanAsimi = 120 * time.Second

	// ⚠️⚠️ GORSEL KOTASI METINDEN **AYRI VE DAHA DUSUK**.
	//
	//	Maliyet: gorsel uretimi metin cagrisindan BIR KAC KAT PAHALI
	//	(metin ~$0.001). Odeme sistemi YOK, maliyet dogrudan bize ait.
	//	10 gorsel/gun secildi: bir restoran menusune fotograf eklerken ANLAMLI
	//	bir sayi (5 cok kisitliydi), kotu niyetli kullanimda ise maliyet
	//	sinirli kalir.
	// ⚠️ Sayim `tur='gorsel'` uzerinden AYRI yapilir; metin kotasini YEMEZ ve
	//    metin kotasi da gorseli kilitlemez.
	gunlukGorselKota = 10

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

	// ⚠️ TURU 79b — reddedilen uretimi siler (depolama kotasini geri verir).
	//    Ayrinti: `media.AIGorseliVazgec` serhi.
	gorselVazgec func(ctx context.Context, mediaID, sahipID string) error
}

func NewHandler(db *pgxpool.Pool,
	medyaURL func(context.Context, string, string) (string, error),
	gorselKaydet func(context.Context, string, string, []byte) (string, error),
	gorselIzni func(context.Context, string, int64) bool,
	medyaAcik func() bool,
	gorselVazgec func(context.Context, string, string) error) *Handler {
	a := strings.TrimSpace(os.Getenv("OPENAI_API_KEY"))
	h := &Handler{
		db: db, anahtar: a, medyaURL: medyaURL,
		gorselKaydet: gorselKaydet, gorselIzni: gorselIzni, medyaAcik: medyaAcik,
		gorselVazgec: gorselVazgec,
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

// ⚠️⚠️⚠️ TURU 79b — HANGI `tur` PAHALI GORSEL HAVUZUNA DUSER. **TEK KAYNAK.**
//
// Turu 79'da bu karar `kapi()` icine `tur == "gorsel"` diye GOMULMUSTU ve
// `UrunMetni` turu 77'den kalma "gorsel" etiketini kullandigi icin METIN ucu
// gorsel kotasini yiyordu (sevk engeli).
//
// ⚠️ Kural TEK YERDE olmali cunku ayni yuklem UC yerde kullaniliyor:
//
//	`kapi()` rezervasyonu · `bugunKullanilan()` sayimi · SQL yuklemi.
//	Ucu ayrilirsa kullaniciya gosterilen "kalan" ile gercek kota TUTMAZ
//	(CLAUDE.md: "ayni kuralin iki kopyasi drift eder").
//
// ⚠️ YAPMA: yeni bir AI ucu eklerken `tur`u rastgele secme. GORSEL URETMIYORSA
//
//	buraya EKLEME; uretiyorsa EKLE. Yanlis taraf, kullanicinin gunluk hakkini
//	yanlis havuzdan yakar.
func gorselKotasiMi(tur string) bool { return tur == "gorsel" }

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
	gorselMi := gorselKotasiMi(tur)
	if gorselMi {
		kota = gunlukGorselKota
	}
	// ⚠️⚠️⚠️ TURU 79b — KULLANICI BASINA **SERILESTIRME** (denetim bulgusu).
	//
	//	`INSERT ... SELECT WHERE (count) < kota` TEK BASINA **ATOMIK DEGILDIR**:
	//	READ COMMITTED'da es zamanli iki istek AYNI sayimi okur, ikisi de
	//	`count < kota` gorur ve IKISI DE satir acar. N escamanli istekle kota
	//	ASILIR ve gorsel tarafinda bu **GERCEK PARA** demektir (her asim ~bir
	//	uretim ucreti).
	//
	//	`pg_advisory_xact_lock` kullanici+havuz basina kilit alir; islem
	//	bitince OTOMATIK birakilir (ayri bir unlock yolu YOK, dolayisiyla
	//	hata dalinda kilit SIZMAZ).
	//
	// ⚠️ Kilit anahtari HAVUZU DA icerir: metin ve gorsel havuzlari birbirini
	//	gereksiz yere BEKLETMESIN.
	// ⚠️ Ayni islemde olmalari SART — bu yuzden tek `WITH` ifadesi degil,
	//	acik bir transaction kullaniliyor.
	// ⚠️ YAPMA: kilidi kaldirip yalniz `count < kota`ya donme.
	tx, txErr := h.db.Begin(r.Context())
	if txErr != nil {
		log.Printf("ai kota tx: %v", txErr)
		hata(w, 500, "Yapay zekâ şu anda kullanılamıyor")
		return "", 0, false
	}
	defer tx.Rollback(context.WithoutCancel(r.Context()))

	havuz := "ai:metin:"
	if gorselMi {
		havuz = "ai:gorsel:"
	}
	if _, lerr := tx.Exec(r.Context(),
		`SELECT pg_advisory_xact_lock(hashtext($1))`, havuz+me); lerr != nil {
		log.Printf("ai kota kilidi: %v", lerr)
		hata(w, 500, "Yapay zekâ şu anda kullanılamıyor")
		return "", 0, false
	}

	var id int64
	err := tx.QueryRow(r.Context(), `
		INSERT INTO ai_istekleri (user_id, tur, girdi, sonuc, durum)
		SELECT $1, $2, '', '', 'beklemede'
		 WHERE (SELECT count(*) FROM ai_istekleri
		         WHERE user_id=$1 AND durum <> 'iptal'
		           AND ($4 = (tur = 'gorsel'))
		           AND created_at > now() - interval '24 hours') < $3
		RETURNING id`, me, tur, kota, gorselMi).Scan(&id)
	if err == nil {
		// ⚠️ COMMIT SART: aksi halde `defer tx.Rollback` rezervasyonu GERI ALIR
		//    ve kota FIILEN calismaz.
		if cerr := tx.Commit(r.Context()); cerr != nil {
			log.Printf("ai kota commit: %v", cerr)
			hata(w, 500, "Yapay zekâ şu anda kullanılamıyor")
			return "", 0, false
		}
	}
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
		// ⚠️⚠️ SAYI **SABITTEN URETILIR** (turu 79b denetim bulgusu). Metne
		//    gomulu "(5)" yaziyordu; sabit 10'a cikarilinca mesaj GUNCELLENMEDI
		//    ve kullaniciya YANLIS hak sayisi soyleniyordu. Bu, projede tekrar
		//    eden "ayni degerin iki kopyasi drift eder" sinifinin kucuk ama
		//    gorunur bir ornegi.
		// ⚠️ YAPMA: sayiyi tekrar metne gomme.
		if gorselMi {
			hata(w, 429, fmt.Sprintf(
				"Günlük görsel oluşturma hakkın doldu (%d), yarın tekrar dene",
				gunlukGorselKota))
		} else {
			hata(w, 429, fmt.Sprintf(
				"Günlük yapay zekâ hakkın doldu (%d), yarın tekrar dene", gunlukKota))
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
//
// ⚠️ TURU 111 — `gecmis` EKLENDI. Diger cagiranlar `nil` gecer; davranis
//
//	DEGISMEZ (sistem + tek kullanici mesaji).
func (h *Handler) sor(ctx context.Context, sistem string,
	parcalar []icerikParca, gecmis []map[string]any) (string, error) {
	mesajlar := []map[string]any{{"role": "system", "content": sistem}}
	mesajlar = append(mesajlar, gecmis...)
	mesajlar = append(mesajlar, map[string]any{"role": "user", "content": parcalar})
	govde := map[string]any{
		"model":      modelMetin,
		"messages":   mesajlar,
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

	// ⚠️⚠️⚠️ TURU 111 — **SOHBET GECMISI** (kullanici emri: *"gebzemai
	//	arayuzu Claude/Gemini gibi olsun"*).
	//
	//	Bir sohbet arayuzunun tek gercek gereksinimi BAGLAMDIR: ikinci
	//	soruda modelin birinci soruyu bilmesi gerekir. Aksi halde ekran
	//	sohbet gibi gorunur ama her mesaj SIFIRDAN cevaplanir — arayuzun
	//	vaat ettigi seyi yapmayan bir ekran olurdu.
	//
	// ⚠️ Gecmis SUNUCUDA SAKLANMAZ: tablo yok, istemci her istekte kendi
	//    ekranindakini gonderir. Boylece migration GEREKMEZ ve "sohbetlerim"
	//    gibi olmayan bir ozellik vaat edilmez.
	// ⚠️ TAVAN: son `gecmisTavani` mesaj alinir ve her biri `metinTavani`
	//    ile kirpilir — istemci 500 mesaj gonderip faturayi sisiremesin.
	Gecmis []aiMesaj `json:"gecmis"`
}

// aiMesaj — sohbet gecmisindeki tek satir.
//
// ⚠️ `Rol` BEYAZ LISTEDEN gecer: istemcinin 'system' gondermesi, sunucunun
//
//	kendi sistem talimatini EZMESINE (prompt injection) yol acardi.
type aiMesaj struct {
	Rol   string `json:"rol"`
	Metin string `json:"metin"`
}

// ⚠️ Kac gecmis mesaj tasinir. 12 = ~6 tur; token maliyeti dogrudan
//
//	faturaya yansidigi icin SINIRSIZ olamaz.
const gecmisTavani = 12

// gecmisMesajlari — istemci gecmisini OpenAI bicimine cevirir.
//
// ⚠️ Rol beyaz listesi: yalniz `user` ve `assistant`. Taninmayan rol
//
//	SESSIZCE ATILIR (400 donmek eski istemcileri kirar).
func gecmisMesajlari(g []aiMesaj) []map[string]any {
	if len(g) > gecmisTavani {
		g = g[len(g)-gecmisTavani:]
	}
	out := []map[string]any{}
	for _, m := range g {
		if m.Rol != "user" && m.Rol != "assistant" {
			continue
		}
		t := metniKirp(m.Metin)
		if t == "" {
			continue
		}
		out = append(out, map[string]any{"role": m.Rol, "content": t})
	}
	return out
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
		parcalar, nil)
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
// ⚠️ BU UC GORSEL URETMEZ, GORSELI ANLAR: kullanici urun fotografini ceker, AI
//
//	ondan satis metni yazar. (Gercek gorsel uretimi turu 79'da `gorsel.go`da
//	eklendi ve AYRI bir uctur.)
//
// ⚠️⚠️⚠️ TURU 79b — `tur` DEGERI "gorsel"DEN "urun-metni"YE CEVRILDI. SEVK ENGELI
// DUZELTMESI; kok neden BENIM turu 79 degisikligimdir:
//
//	Turu 77'de `tur` YALNIZCA BIR ETIKETTI (denetim izi) ve tum AI cagrilari
//	tek 20/gun havuzunu paylasiyordu — bu ucun "gorsel" yazmasi ZARARSIZDI.
//	Turu 79'da `kapi()` icine `gorselMi := tur == "gorsel"` eklendim ve o
//	etiketi **"pahali gorsel kotasi, gunde 10"** anlamina cevirdim; ama
//	CAGRI YERINI guncellemedim.
//
//	SONUC: isletme sahibinin "Yapay zekâ ile açıklama yaz" dugmesine her
//	dokunusu, turun MANSET OZELLIGI olan gorsel uretiminden bir hak yakiyordu.
//	10 aciklama yazdiran kisi HIC GORSEL URETMEDEN "Günlük görsel oluşturma
//	hakkın doldu" goruyordu; ustelik aciklama dugmesindeki sayac METIN havuzunu
//	gosterdigi icin 20'de CAKILI kaliyor, gercek dususu HIC gostermiyordu.
//	Tersi de bozuktu: 20'lik metin havuzu bu uc tarafindan HIC harcanmiyordu.
//
// ⚠️ Migration GEREKMEZ: `ai_istekleri.tur` sutununda CHECK YOK (031).
// ⚠️ YAPMA: bir kota olcutunu SERBEST METIN etiketine baglarken cagri
//
//	yerlerini taramadan birakma. `grep 'h.kapi(w, r,'` dort satir donduruyor.
func (h *Handler) UrunMetni(w http.ResponseWriter, r *http.Request) {
	_, istekID, ok := h.kapi(w, r, "urun-metni")
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
		parcalar, nil)
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
	// ⚠️⚠️⚠️ TURU 111 — **FOTOGRAF ARTIK ZORUNLU DEGIL.**
	//
	//	Ekran bir SOHBETE cevrildi (kullanici emri: *"Claude/Gemini gibi"*)
	//	ve sohbetin cogu mesaji fotografsizdir. Eski hal her istekte
	//	`400 "fotoğraf gerekli"` donduruyordu, yani yazi yazip gondermek
	//	YAPISAL OLARAK imkansizdi.
	// ⚠️ En az BIRI olmali: fotograf ya da metin. Ikisi de bossa istek
	//    bosuna kota yakardi.
	if req.MediaID == "" && req.Metin == "" {
		hata(w, 400, "bir soru yaz ya da fotoğraf ekle")
		return
	}
	parcalar := []icerikParca{}
	if req.MediaID != "" {
		u, err := h.gorselAdresi(r.Context(), req.MediaID, auth.UserID(r.Context()))
		if err != nil {
			hata(w, 400, "görsel okunamadı")
			return
		}
		parcalar = append(parcalar, icerikParca{
			Tip: "text",
			Metin: "Bu fotoğraftaki sorunu tespit et ve ne yapılması gerektiğini " +
				"maddeler hâlinde, sade Türkçe ile anlat. Emin olmadığın yerde " +
				"açıkça 'emin değilim' de ve bir uzmana danışılmasını öner.",
		}, icerikParca{Tip: "image_url", Gorsel: &gorselURL{URL: u}})
	}
	if req.Metin != "" {
		parcalar = append(parcalar, icerikParca{
			Tip:   "text",
			Metin: req.Metin,
		})
	}
	sonuc, err := h.sor(r.Context(),
		"Sen pratik bir teknik danışmansın. Sağlık ve hukuk konularında tavsiye "+
			"VERMEZSİN, uzmana yönlendirirsin. Kısa ve maddeli yazarsın.",
		parcalar, gecmisMesajlari(req.Gecmis))
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

// POST /ai/kalori — bir yiyecegin adindan (ya da fotografindan) KALORI TAHMINI.
//
// ⚠️⚠️⚠️ TURU 91 — `tur` **"kalori"**, "gorsel" DEGIL.
//
//	Turu 79b'de `tur` etiketini yanlis yazmak SEVK ENGELI olmustu: aciklama
//	yazan her dokunus, turun manset ozelligi olan GORSEL URETIMINDEN bir hak
//	yakiyordu. `gorselKotasiMi` yalnizca `"gorsel"`e true dondugu icin bu uc
//	METIN havuzundan (20/gun) duser — dogru olan budur, cunku bu bir metin
//	cagrisidir (gorsel gonderilse bile ANLAMA islemidir, URETME degil).
//	⚠️ Yeni bir AI ucu eklerken `grep 'h.kapi(w, r,'` ile TUM cagri yerlerini
//	   tara ve etiketin ne ANLAMA GELDIGINI dogrula.
//
// ⚠️ SONUC DOGRUDAN KAYDEDILMEZ, ONERI DONER: kullanici degeri gorup
//
//	onaylar. AI'nin urettigi bir sayiyi sessizce saglik kaydina yazmak,
//	kullanicinin gormedigi bir veriyi ona ait kilardi.
//
// ⚠️ SISTEM MESAJI SAGLIK TAVSIYESI VERMEZ. Model yalnizca besin degeri
//
//	TAHMIN eder; diyet karari diyetisyene aittir ve arayuz de bunu yazar.
func (h *Handler) Kalori(w http.ResponseWriter, r *http.Request) {
	_, istekID, ok := h.kapi(w, r, "kalori")
	if !ok {
		return
	}
	var req aiReq
	json.NewDecoder(r.Body).Decode(&req)
	req.Metin = metniKirp(req.Metin)

	parcalar := []icerikParca{{
		Tip: "text",
		Metin: "Bu yiyeceğin besin değerlerini TAHMİN et. YALNIZCA şu biçimde " +
			"JSON döndür, başka hiçbir şey yazma:\n" +
			`{"ad":"","gram":0,"kalori":0,"protein":0,"karbonhidrat":0,"yag":0}` +
			"\nkalori = verilen gram için TOPLAM kcal. " +
			"gram = tahmini porsiyon ağırlığı. " +
			"protein/karbonhidrat/yag = o porsiyondaki gram cinsinden değer. " +
			"Ad'ı Türkçe yaz. Emin değilsen en yakın tahmini ver.",
	}}
	if req.Metin != "" {
		parcalar = append(parcalar, icerikParca{
			Tip: "text", Metin: "Yiyecek: " + req.Metin,
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
		hata(w, 400, "yiyecek adı ya da fotoğrafı gerekli")
		return
	}

	sonuc, err := h.sor(r.Context(),
		"Sen bir besin değeri tahmin aracısın. Yalnızca geçerli JSON dönersin. "+
			"Tıbbi tavsiye VERMEZSİN, diyet önerisi YAPMAZSIN.",
		parcalar, nil)
	if err != nil {
		h.kaydet(r.Context(), istekID, req.Metin, err.Error(), "hata")
		hata(w, 502, "Yapay zekâ şu anda yanıt veremedi")
		return
	}
	h.kaydet(r.Context(), istekID, req.Metin, sonuc, "tamam")
	yaz(w, 200, map[string]any{"sonuc": jsonTemizle(sonuc)})
}
