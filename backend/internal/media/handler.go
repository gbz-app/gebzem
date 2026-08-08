package media

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️ TURU 74 — MEDYA UCLARI.
//
// AKIS (uc adim, hepsi ZORUNLU):
//   1. POST /media/upload   -> sunucu `media_assets` satiri acar (status=beklemede)
//                              ve presigned PUT URL'i doner.
//   2. istemci DOGRUDAN R2'ye PUT eder (API'den GECMEZ).
//   3. POST /media/{id}/commit -> sunucu HeadObject + ilk 256 KB Range GET ile
//                              GERCEGI dogrular; gecerse status=aktif, degilse
//                              nesne SILINIR ve status=reddedildi.
//   4. GET  /media/{id}/url -> kisa omurlu imzali indirme URL'i (TTL 600 sn).
//
// ⚠️ NEDEN UC ADIM: tek adimda "yukledim" demek istemcinin sozune guvenmek olurdu.
//    Commit, boyut/tip/GPS dogrulamasinin YAPILDIGI TEK yerdir.

type Handler struct {
	db    *pgxpool.Pool
	rdb   *redis.Client
	r2    *Istemci
	kota  *Kota
	acik  bool
	uyari func(string) // Sentry'e GERCEK olay yazan geri cagri (breadcrumb DEGIL)
}

func NewHandler(db *pgxpool.Pool, rdb *redis.Client,
	endpoint, anahtarID, gizli, bucket string, uyari func(string)) *Handler {
	h := &Handler{db: db, rdb: rdb, kota: YeniKota(rdb), uyari: uyari}
	if uyari == nil {
		h.uyari = func(s string) { log.Println("medya UYARI:", s) }
	}
	h.r2 = YeniIstemci(endpoint, anahtarID, gizli, bucket)
	if h.r2 == nil {
		log.Println("medya: R2_* env EKSIK — MEDYA KAPALI")
		return h
	}
	// ⚠️ ACILIS OZ-TESTI: SigV4 hatalari sessizdir. Tutmazsa medya KAPALI acilir;
	//    sahada "yukleme calismiyor ama sebebi belli degil" yasanmaz.
	if err := SelfTest(); err != nil {
		log.Printf("medya: SigV4 OZ-TESTI TUTMADI (%v) — MEDYA KAPALI", err)
		return h
	}
	h.acik = true
	log.Println("medya: aktif (R2)")
	return h
}

func (h *Handler) Enabled() bool { return h.acik }

// ---------------------------------------------------------------- 1) PRESIGN

type presignReq struct {
	Kind       string `json:"kind"` // image | video | audio | document | avatar
	MIME       string `json:"mime"`
	Bytes      int64  `json:"bytes"`
	MD5        string `json:"md5"`       // base64, istemci hesaplar (butunluk)
	FileName   string `json:"file_name"` // yalniz belge gosterimi icin
	Width      int    `json:"width"`
	Height     int    `json:"height"`
	DurationMs int    `json:"duration_ms"`
	Waveform   string `json:"waveform"`
	ThumbBytes int64  `json:"thumb_bytes"` // 0 ise kucuk resim yok
	ThumbMD5   string `json:"thumb_md5"`
}

type presignResp struct {
	MediaID    string `json:"media_id"`
	UploadURL  string `json:"upload_url"`
	ThumbURL   string `json:"thumb_url,omitempty"`
	ExpiresSec int    `json:"expires_sec"`
}

func (h *Handler) Presign(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req presignReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if !TipIzinli(req.Kind, req.MIME) {
		hata(w, 400, "bu dosya türü desteklenmiyor")
		return
	}
	tavan, ok := Tavanlar[req.Kind]
	if !ok {
		hata(w, 400, "geçersiz medya türü")
		return
	}
	if req.Bytes <= 0 || req.Bytes > tavan {
		hata(w, 413, fmt.Sprintf("dosya çok büyük (en fazla %d MB)", tavan>>20))
		return
	}
	// ⚠️⚠️ TURU 74b (DENETIM BULGUSU — EN AGIR ACIK): md5 alani ZORUNLU.
	// Bos birakilabildigi surece Content-MD5 IMZAYA GIRMIYOR ve presigned URL
	// omru boyunca (300-1800sn) ayni adrese ISTEDIGIN KADAR farkli govde
	// yuklenebiliyordu. Saldiri: temiz JPEG yukle -> commit GECER (status=aktif)
	// -> AYNI URL'e zararli/GPS'li/dev icerik yeniden PUT et -> sihirli bayt,
	// TehlikeliMi, EXIF ve BOYUT kontrollerinin HEPSI devre disi kalir.
	// MD5 imzaya girdigi anda govde DEGISTIRILEMEZ hale gelir.
	// ⚠️ YAPMA: bu kontrolu opsiyonel yapma.
	if req.MD5 == "" {
		hata(w, 400, "bütünlük anahtarı eksik")
		return
	}
	// ⚠️⚠️ KUCUK RESIM (thumb) TAVANI — eskiden HIC YOKTU: istemci
	// istemci thumb_bytes=1 beyan edip o adrese 5 GB yukleyebiliyordu (thumb HEAD
	// edilmiyor, dogrulanmiyor, kotaya yazilmiyor, sweeper gormuyor, reddet
	// silmiyor -> "veri silinmez" karari geregi KALICI maliyet).
	if req.ThumbBytes < 0 || req.ThumbBytes > ThumbTavan {
		hata(w, 413, "küçük resim çok büyük")
		return
	}
	if req.ThumbBytes > 0 && req.ThumbMD5 == "" {
		hata(w, 400, "küçük resim bütünlük anahtarı eksik")
		return
	}
	// ⚠️ HIZ SINIRI kotadan ONCE: presign almak ama yuklememek kotayi tuketmez,
	//    dolayisiyla imza uretimi bedava DDoS olurdu.
	if !h.kota.PresignIzni(r.Context(), userID) {
		hata(w, 429, "çok fazla yükleme isteği, biraz bekleyin")
		return
	}
	kalan := h.kota.Kalan(r.Context(), userID)
	if h.kota.Hata != nil {
		// ⚠️ Kota FAIL-OPEN ama GORUNUR (denetim bulgusu): Redis dustugunde
		//    sinirlar sessizce kalkiyordu.
		h.uyari("medya kota Redis hatasi — SINIRLAR GECICI OLARAK KALKTI")
		h.kota.Hata = nil
	}
	if kalan < req.Bytes {
		hata(w, 507, "aylık yükleme kotanız doldu")
		return
	}

	// ⚠️ ANAHTAR TASARIMI: kullanici id / sohbet id / telefon / dosya adi YOK.
	//    Anahtar sizarsa kimlik bilgisi de sizmasin. Tarih klasoru yalnizca
	//    operasyonel gorunurluk icin (R2 konsolunda gezinmek).
	rastgele := make([]byte, 16)
	rand.Read(rastgele)
	ad := hex.EncodeToString(rastgele)
	tarih := time.Now().UTC().Format("2006/01")
	anahtar := fmt.Sprintf("m/%s/%s", tarih, ad)
	thumbAnahtar := ""
	if req.ThumbBytes > 0 {
		thumbAnahtar = anahtar + "_t"
	}

	var id string
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO media_assets
		  (owner_id, kind, object_key, thumb_key, mime, file_name,
		   width, height, duration_ms, waveform,
		   expected_bytes, expected_md5, thumb_expected_bytes, thumb_expected_md5)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		RETURNING id`,
		userID, req.Kind, anahtar, thumbAnahtar, req.MIME, kisalt(req.FileName, 120),
		req.Width, req.Height, req.DurationMs, kisalt(req.Waveform, 400),
		req.Bytes, req.MD5, req.ThumbBytes, req.ThumbMD5).Scan(&id)
	if err != nil {
		log.Printf("medya presign insert: %v", err)
		hata(w, 500, "yükleme başlatılamadı")
		return
	}

	sure := PresignSuresi(req.Bytes)
	// ⚠️ Content-Type ve Content-MD5 IMZAYA DAHIL: istemci farkli tip ya da farkli
	//    icerik yuklerse R2 imzayi REDDEDER (403/BadDigest). Butunluk boyle saglanir.
	//    `If-None-Match: *` KULLANILMADI (mobil sebekede tekrar denemeyi oldurur).
	bas := map[string]string{"Content-Type": req.MIME, "Content-MD5": req.MD5}
	yuklemeURL, err := h.r2.ImzaliURL("PUT", anahtar, sure, bas)
	if err != nil {
		hata(w, 500, "yükleme adresi üretilemedi")
		return
	}
	yanit := presignResp{MediaID: id, UploadURL: yuklemeURL, ExpiresSec: int(sure.Seconds())}
	if thumbAnahtar != "" {
		tb := map[string]string{"Content-Type": "image/jpeg", "Content-MD5": req.ThumbMD5}
		yanit.ThumbURL, _ = h.r2.ImzaliURL("PUT", thumbAnahtar, sure, tb)
	}
	yaz(w, 200, yanit)
}

// ---------------------------------------------------------------- 2) COMMIT

func (h *Handler) Commit(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")

	kayit, err := h.kaydiOku(r.Context(), id, userID)
	if err == pgx.ErrNoRows {
		// ⚠️ 404 DEGIL 403: baskasinin medya id'sini deneyerek varlik sorgulanmasin.
		hata(w, 403, "bu içeriğe erişiminiz yok")
		return
	}
	if err != nil {
		hata(w, 500, "doğrulanamadı")
		return
	}
	// ⚠️ IDEMPOTENT: ag zaman asimindan sonra tekrar gelen commit hata DEGIL.
	if kayit.durum == "aktif" || kayit.durum == "bagli" {
		yaz(w, 200, map[string]string{"media_id": id, "status": kayit.durum})
		return
	}
	if kayit.durum != "beklemede" {
		hata(w, 409, "bu içerik kullanılamaz")
		return
	}

	kabul, mesaj, boyut := h.dogrulaVeAktifEt(r.Context(), userID, kayit)
	if kabul {
		yaz(w, 200, map[string]any{"media_id": id, "status": "aktif", "bytes": boyut})
		return
	}
	switch mesaj {
	case "":
		hata(w, 502, "dosya doğrulanamadı") // gecici hata — tekrar denenebilir
	case "dosya yüklenmemiş":
		hata(w, 409, mesaj)
	default:
		hata(w, 422, mesaj)
	}
}

type medyaKayit struct {
	id, kind, anahtar, thumbAnahtar, mime, durum string
	beklenen, thumbBeklenen                      int64
}

func (h *Handler) kaydiOku(ctx context.Context, id, sahip string) (medyaKayit, error) {
	var k medyaKayit
	k.id = id
	var err error
	if sahip == "" {
		err = h.db.QueryRow(ctx, `
			SELECT kind, object_key, thumb_key, mime, status, expected_bytes,
			       thumb_expected_bytes
			  FROM media_assets WHERE id=$1`, id).
			Scan(&k.kind, &k.anahtar, &k.thumbAnahtar, &k.mime, &k.durum,
				&k.beklenen, &k.thumbBeklenen)
	} else {
		err = h.db.QueryRow(ctx, `
			SELECT kind, object_key, thumb_key, mime, status, expected_bytes,
			       thumb_expected_bytes
			  FROM media_assets WHERE id=$1 AND owner_id=$2`, id, sahip).
			Scan(&k.kind, &k.anahtar, &k.thumbAnahtar, &k.mime, &k.durum,
				&k.beklenen, &k.thumbBeklenen)
	}
	return k, err
}

// ⚠️⚠️ TURU 74b — ORTAK DOGRULAMA. **Commit VE sweeper AYNI yoldan gecer.**
//
// DENETIM BULGUSU: sweeper'in "kurtarma" dali yalnizca BOYUTA bakiyordu;
// `BasParcasi` + `Dogrula` ve kota CAGRILMIYORDU. Saldiri sudur: presign al,
// beyan edilen boyut kadar KEYFI icerik yukle, commit'i HIC cagirma -> 2 saat
// sonra sweeper onu 'aktif' yapardi. Boylece sihirli bayt / EXIF-GPS / tip
// kontrolu VE aylik kota TAMAMEN atlaniyordu (60 presign/dk x 8 MB =
// 480 MB/dk KALICI depolama, hicbiri kotaya yazilmadan).
// ⚠️ YAPMA: iki yoldan birini bu fonksiyonun disinda birakma.
//
// Doner: (kabulEdildi, kullaniciyaMesaj, gercekBoyut).
// Mesaj bos ise GECICI hata (reddetme, sonra tekrar denenebilir).
func (h *Handler) dogrulaVeAktifEt(ctx context.Context, sahip string,
	k medyaKayit) (bool, string, int64) {
	bilgi, err := h.r2.Head(ctx, k.anahtar)
	if err == ErrNesneYok {
		return false, "dosya yüklenmemiş", 0
	}
	if err != nil {
		if r2h, ok := err.(*R2Hata); ok && r2h.ImzaHatasiMi() {
			// ⚠️ GERCEK Sentry olayi: SigV4 bozulmus olabilir, sessiz kalmamali.
			h.uyari("medya HEAD 403 — R2 imza/anahtar sorunu")
		}
		return false, "", 0
	}
	// ⚠️ TAM ESITLIK: "yaklasik" kabul edilmez. Farkli boyut = farkli dosya.
	if bilgi.Bytes != k.beklenen {
		h.reddet(ctx, k, "boyut uyuşmuyor")
		return false, "dosya eksik veya bozuk yüklendi", 0
	}
	// ⚠️⚠️ PENCERE 256 KB -> 1 MB (denetim bulgusu): saldirgan APP1 (EXIF)
	//    segmentini dolgu segmentleriyle 256 KB'in OTESINE itip GPS taramasindan
	//    kacabiliyordu. 1 MB pratikte tum EXIF'leri kapsar.
	bas, err := h.r2.BasParcasi(ctx, k.anahtar, 1<<20)
	if err != nil {
		return false, "", 0
	}
	if temiz, sebep := Dogrula(k.kind, k.mime, bas); !temiz {
		h.reddet(ctx, k, sebep)
		return false, sebep, 0
	}
	// ⚠️ KUCUK RESIM de DOGRULANIR: eskiden HIC HEAD edilmiyordu ve tavani yoktu,
	//    yani o adrese sinirsiz veri yuklenip kalici olarak birakilabiliyordu.
	//    Bozuksa ANA dosya reddedilmez — yalniz thumb dusurulur (balon tam
	//    gorseli kucultup gosterir).
	if k.thumbAnahtar != "" && k.thumbBeklenen > 0 {
		if tb, terr := h.r2.Head(ctx, k.thumbAnahtar); terr != nil || tb.Bytes != k.thumbBeklenen {
			h.r2.Sil(ctx, k.thumbAnahtar)
			h.db.Exec(ctx, `UPDATE media_assets SET thumb_key='' WHERE id=$1`, k.id)
			k.thumbBeklenen = 0
		}
	}
	// ⚠️⚠️ KOTA **UPDATE'TEN SONRA** ve YALNIZ KAZANAN yolda (denetim bulgusu):
	//    eskiden UPDATE'ten ONCE cagriliyordu; es zamanli iki commit IKISI DE
	//    kotayi dusuyor ama UPDATE'in yalniz biri tutuyordu -> kullanici N
	//    paralel commit ile kendi kotasini N katina cikarabiliyordu.
	tag, err := h.db.Exec(ctx, `
		UPDATE media_assets SET status='aktif', bytes=$2, committed_at=now()
		 WHERE id=$1 AND status='beklemede'`, k.id, bilgi.Bytes)
	if err != nil {
		return false, "", 0
	}
	if tag.RowsAffected() == 1 {
		if _, kerr := h.kota.Ekle(ctx, sahip, bilgi.Bytes+k.thumbBeklenen); kerr != nil {
			log.Printf("medya kota: %v", kerr)
		}
	}
	return true, "", bilgi.Bytes
}

// reddet — dogrulama basarisiz: nesneleri SIL, satiri isaretle.
// ⚠️ Nesne R2'de birakilmaz — hem maliyet hem zararli icerik riski.
// ⚠️ THUMB DA SILINIR (denetim bulgusu: eskiden yalniz `object_key` siliniyordu,
//
//	kucuk resim nesnesi R2'de KALICI olarak kaliyordu).
func (h *Handler) reddet(ctx context.Context, k medyaKayit, sebep string) {
	for _, anahtar := range []string{k.anahtar, k.thumbAnahtar} {
		if anahtar == "" {
			continue
		}
		if err := h.r2.Sil(ctx, anahtar); err != nil {
			// Silinemezse kuyruga at — sweeper tekrar dener (nesne SIZMASIN).
			h.db.Exec(ctx, `INSERT INTO media_delete_queue (object_key) VALUES ($1)`, anahtar)
		}
	}
	h.db.Exec(ctx, `UPDATE media_assets SET status='reddedildi', reject_reason=$2,
	                  deleted_at=now() WHERE id=$1`, k.id, kisalt(sebep, 200))
}

// ---------------------------------------------------------------- 3) URL

// URL — kisa omurlu imzali indirme adresi.
// ⚠️ Bucket PRIVATE. Public + edge cache KABUL EDILMEDI: R2'den silmek Cloudflare
//
//	edge onbellegini bosaltmaz -> 5651 "4 saat icinde kaldirma" beyani YANLIS
//	BEYAN olurdu. Onbellek CIHAZDA (istemci media_id'ye gore saklar).
func (h *Handler) URL(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")

	var anahtar, thumbAnahtar, mime, durum, sahip string
	err := h.db.QueryRow(r.Context(), `
		SELECT object_key, thumb_key, mime, status, owner_id::text
		  FROM media_assets WHERE id=$1`, id).
		Scan(&anahtar, &thumbAnahtar, &mime, &durum, &sahip)
	if err != nil {
		hata(w, 404, "içerik bulunamadı")
		return
	}
	if durum == "karantina" || durum == "silindi" || durum == "reddedildi" {
		hata(w, 410, "bu içerik kaldırıldı")
		return
	}
	// ⚠️ ERISIM KONTROLU: sahibi ya da medyanin baglandigi sohbetin uyesi olmali.
	//    Aksi halde media_id tahmin eden biri BASKASININ fotografini indirebilirdi.
	if sahip != userID && !h.erisebilir(r.Context(), userID, id) {
		hata(w, 403, "bu içeriğe erişiminiz yok")
		return
	}

	const ttl = 600 * time.Second
	u, err := h.r2.ImzaliURL("GET", anahtar, ttl, nil)
	if err != nil {
		hata(w, 500, "adres üretilemedi")
		return
	}
	yanit := map[string]any{"url": u, "mime": mime, "expires_sec": int(ttl.Seconds())}
	if thumbAnahtar != "" {
		yanit["thumb_url"], _ = h.r2.ImzaliURL("GET", thumbAnahtar, ttl, nil)
	}
	yaz(w, 200, yanit)
}

// erisebilir — bu medya, kullanicinin uyesi oldugu bir sohbetteki mesaja mi bagli?
// (Avatar icin ayrica: profil fotograflari herkese aciktir — asagida.)
func (h *Handler) erisebilir(ctx context.Context, userID, mediaID string) bool {
	// (a) mesaja bagli ve kullanici o sohbetin uyesi
	// ⚠️ TURU 74b: count(*) yerine EXISTS (ilk isabette durur) + kismi index (016).
	//    Ayrica SILINMIS mesaj erisim VERMEZ (denetim: "herkesten sil" sonrasi
	//    alici fotografi sonsuza kadar indirebiliyordu).
	var varMi bool
	h.db.QueryRow(ctx, `
		SELECT EXISTS(
		  SELECT 1 FROM messages m
		    JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $2
		   WHERE m.media_id = $1 AND NOT m.deleted_for_all)`, mediaID, userID).Scan(&varMi)
	if varMi {
		return true
	}
	// (b) birinin AVATARI — profil fotograflari uygulama icinde herkese gorunur
	h.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE avatar_media_id=$1)`,
		mediaID).Scan(&varMi)
	return varMi
}

// ---------------------------------------------------------------- SWEEPER

// StartSweeper — YETIM yuklemeleri temizler.
//
// ⚠️⚠️ BU BIR "SAKLAMA SURESI" TEMIZLIGI DEGILDIR. Kullanici karari: **VERI SILINMEZ.**
//
//	Burada silinen sey, baslamis ama TAMAMLANMAMIS yuklemelerdir (status='beklemede')
//	ve kullanicinin gordugu hicbir icerige karsilik gelmez.
//
// ⚠️ YAPMA: buraya yas tabanli ('aktif'/'bagli' silme) kural ekleme.
//
// ⚠️ PENCERE SABIT DEGIL: PUT arka planda tamamlanabilir ama commit uygulama
//
//	acilinca yapilir. Kisa pencere HALA SUREN bir yuklemenin nesnesini silerdi.
//	Bu yuzden silmeden ONCE HeadObject denenir; nesne TAM ve DOGRUysa silinmez,
//	'aktif' yapilir (kurtarma).
func (h *Handler) StartSweeper(ctx context.Context) {
	if !h.acik {
		return
	}
	go func() {
		t := time.NewTicker(30 * time.Minute)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				h.suprur(ctx)
			}
		}
	}()
}

func (h *Handler) suprur(ctx context.Context) {
	// (1) silme kuyrugu — daha once silinemeyen nesneler
	rows, err := h.db.Query(ctx, `
		SELECT id, object_key FROM media_delete_queue
		 WHERE tries < 10 ORDER BY created_at LIMIT 200`)
	if err == nil {
		type is struct {
			id  int64
			key string
		}
		var isler []is
		for rows.Next() {
			var x is
			if rows.Scan(&x.id, &x.key) == nil {
				isler = append(isler, x)
			}
		}
		rows.Close()
		for _, x := range isler {
			if err := h.r2.Sil(ctx, x.key); err == nil {
				h.db.Exec(ctx, `DELETE FROM media_delete_queue WHERE id=$1`, x.id)
			} else {
				h.db.Exec(ctx, `UPDATE media_delete_queue SET tries=tries+1,
				                  last_error=$2 WHERE id=$1`, x.id, kisalt(err.Error(), 200))
			}
		}
	}

	// (2) yetim 'beklemede' kayitlar — en az 2 saat once acilmis
	// ⚠️ 2 saat: yavas hatta 16 MB video + arka planda askiya alinmis uygulama.
	//    Presign omru en fazla 1800sn oldugu icin HALA SUREN bir yuklemeyi
	//    silme riski YOKTUR.
	r2, err := h.db.Query(ctx, `
		SELECT id, owner_id::text FROM media_assets
		 WHERE status='beklemede' AND created_at < now() - interval '2 hours'
		 ORDER BY created_at LIMIT 200`)
	if err != nil {
		return
	}
	type yetim struct{ id, sahip string }
	var liste []yetim
	for r2.Next() {
		var y yetim
		if r2.Scan(&y.id, &y.sahip) == nil {
			liste = append(liste, y)
		}
	}
	r2.Close()

	for _, y := range liste {
		k, err := h.kaydiOku(ctx, y.id, "")
		if err != nil {
			continue
		}
		// ⚠️⚠️ KURTARMA **TAM DOGRULAMADAN GECER** (turu 74b denetim bulgusu).
		//    Eskiden burada YALNIZ BOYUT karsilastiriliyordu; icerik dogrulamasi
		//    ve kota YOKTU -> commit'i hic cagirmayan biri, keyfi icerigi 2 saat
		//    sonra sweeper'a 'aktif' yaptirabiliyordu.
		//    ⚠️ Kurtarma GEREKLI: kullanici yuklemeyi bitirmis ama commit'i
		//       (uygulama kapandi) yapamamis olabilir; silseydik VERISI KAYBOLURDU.
		kabul, mesaj, _ := h.dogrulaVeAktifEt(ctx, y.sahip, k)
		if kabul {
			continue
		}
		if mesaj == "" {
			continue // gecici hata — sonraki turda tekrar bak
		}
		// `dogrulaVeAktifEt` icerik/boyut hatasinda ZATEN `reddet` cagirdi.
		// Kalan tek durum: nesne HIC YUKLENMEMIS.
		if mesaj == "dosya yüklenmemiş" {
			h.db.Exec(ctx, `UPDATE media_assets SET status='reddedildi',
			                  reject_reason='yükleme tamamlanmadı', deleted_at=now()
			                WHERE id=$1 AND status='beklemede'`, y.id)
		}
	}
}

// ---------------------------------------------------------------- yardimcilar

func kisalt(s string, n int) string {
	if len(s) <= n {
		return s
	}
	// ⚠️ Bayt degil RUNE sinirla: Turkce karakteri ortadan bolmek gecersiz UTF-8 uretir.
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return strings.TrimSpace(string(r[:n]))
}

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, msg string) {
	yaz(w, kod, map[string]string{"error": msg})
}
