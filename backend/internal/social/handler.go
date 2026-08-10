package social

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/bildirim"
	"github.com/gbz-app/gebzem/backend/internal/chat"
)

// ⚠️⚠️⚠️ TURU 75 — GONDERI + ANA SAYFA AKISI.
//
// ═══════════ FAN-OUT KARARI: **READ-TIME (okurken birlestir)** ═══════════
//
// Uc secenek vardi:
//   (a) WRITE-TIME fan-out — her gonderi TUM takipcilerin kutusuna KOPYALANIR.
//   (b) READ-TIME fan-out  — okurken "takip ettiklerimin gonderileri" sorgulanir.
//   (c) HIBRIT — cok takipcililer read-time, digerleri write-time.
//
// **(b) SECILDI.** Gerekce:
//  · OLCEK: 50K kullanici hedefi. Write-time fan-out'un TEK avantaji cok yuksek
//    okuma/yazma oraninda ortaya cikar; bizim olcegimizde `posts` tablosu
//    milyonlarca satira bile ulasmaz ve `(created_at DESC)` kismi index'i
//    siralamayi index'ten karsilar.
//  · MALIYET: write-time fan-out, 10.000 takipcisi olan biri gonderi atinca
//    10.000 SATIR YAZAR. cx33'te Postgres LiveKit ile AYNI 4 vCPU'yu paylasiyor;
//    bu yazma firtinasi SFU'yu ac birakir. Okuma tarafi ise sayfa basina TEK
//    sorgu.
//  · GERI DONULEBILIRLIK: read-time'dan hibrite gecmek KOLAY (kutu tablosu
//    eklenir); tersi zordur (kutular tutarsiz kalir, yeniden doldurmak gerekir).
//    Yani UCUZ olani once secip olcumle buyumek dogru sira.
// ⚠️ YAPMA: olcum gormeden write-time fan-out'a gecme. Once `EXPLAIN ANALYZE`
//    ile akis sorgusunun sahadaki suresine bak.
//
// ═══════════ SIRALAMA: **KRONOLOJIK** ═══════════
// Algoritmik siralama SOGUK BASLANGIC sorununu COZMEZ, saklar. Prototipte
// kullanici sayisi azken algoritmik akis BOS gorunur ve urunun olum sebebi olur.
// ⚠️ SOGUK BASLANGIC COZUMU: takip edilen yoksa akis BOS DONMEZ — "kesfet"
//    (herkese acik, yeni gonderiler) doner. Bkz. `Akis`.

// ⚠️⚠️ TURU 75b (DENETIM BULGUSU) — ENGEL YUKLEMI **TEK KAYNAK**.
//
// Bu predikat DORT sorguya kopyalanmisti (Akis-takipli, Akis-kesfet, Reels,
// erisebilirMi) ve BESINCISINDE — UserPosts — DUSMUSTU. Sonuc: engellenen kisi
// akista goremedigi kullanicinin PROFILINE girip TUM gonderilerini
// okuyabiliyordu. Engellemenin asil vitrini tam da buydu (App Store 1.2).
//
// CLAUDE.md'deki "AYNI KURALIN IKI KOPYASI DRIFT EDER" dersinin (turu 72b/H)
// birebir tekrari oldugu icin kural artik TEK STRINGDE yasiyor.
// ⚠️ YAPMA: bu yuklemi tekrar sorgulara elle kopyalama.
// ⚠️ Kural CIFT YONLU: hangi taraf digerini engellediyse icerik gorunmez.
// ⚠️ Kullanildigi HER sorguda $1 = OKUYAN kullanici olmali; tablo takma adi p.
// ⚠️⚠️ TURU 76 — HER MEDYANIN TURU (`media_kinds`) + DUZENLENME DAMGASI.
//
// KOK NEDEN: `posts.media_ids` yalnizca UUID dizisiydi; her medyanin FOTO mu
// VIDEO mu oldugu istemciye HIC DONMUYORDU. Bu yuzden kart, gonderi seviyesindeki
// `tur` bayragina bakarak TUM medyayi ayni sekilde ciziyordu — yani kullanicinin
// istedigi "birden fazla gorsel VE video, galeri gibi sol/sag" YAPISAL OLARAK
// IMKANSIZDI: sunucu izin verse bile kart yanlis cizerdi.
//
// ⚠️ SIRA KORUNUR: `unnest(...) WITH ORDINALITY` + `ORDER BY idx` sayesinde
//
//	`media_kinds[i]` ile `media_ids[i]` AYNI medyayi gosterir. Duz bir JOIN
//	kullanilsaydi sira GARANTI OLMAZDI ve galeri yanlis tip cizerdi.
//
// ⚠️ SILINMIS medya icin 'yok' doner (NULL DEGIL): `array_agg` NULL elemani
//
//	uretirse `[]string`e tarama PATLAR ve satir SESSIZCE ATLANIR (akis bosalir).
//	Istemci 'yok' gorunce "bu icerik kaldirildi" cizer.
// ⚠️⚠️ MEDYA TURLERI + OLCULERI. **YEDI gonderi sorgusu da bu sabiti kullanir**
//
//	(handler.go x4, etkilesim.go x3) — yani buraya eklenen bir sutun HEPSINE
//	birden gider ve "6 sorguya ekleyip 7.'yi atlama" hatasi (turu 76'da
//	"Kaydedilenler" sayfasini BOMBOS birakan sinif) YAPISAL OLARAK imkansizdir.
//
// ⚠️ `unnest(...) WITH ORDINALITY` SIRA KORUR: `media_kinds[i]` ve
//
//	`media_boyut[i]`, `media_ids[i]` ile BIREBIR hizalidir. Duz JOIN
//	kullanilsaydi sira GARANTI OLMAZDI.
//
// ⚠️⚠️⚠️ TURU 81 — `media_boyut` EKLENDI ("WxH" metni, or. "1080x1920").
//
//	Kullanici UC KEZ "gorseller cok uzun / boyutlar tutarsiz" dedi. Threads
//	modeli YUKSEKLIK SABIT + GENISLIK GERCEK ORANDAN ister; bunun icin
//	istemcinin medyanin oranini BILMESI gerekir. `media_assets.width/height`
//	015'ten beri VARDI ama HIC DOLDURULMUYORDU (17 yukleme cagrisinin hicbiri
//	deger gecmiyordu) ve sorgular da DONDURMUYORDU — sutun bastan beri OLUYDU.
//
// ⚠️ TEK METIN DIZISI ("WxH") secildi, iki AYRI int dizisi DEGIL: her ek dizi
//
//	`satirlariOku`ya bir Scan hedefi daha ekler ve o hizanin bozulmasi
//	SATIRLARI SESSIZCE DUSURUR. Tek dizi = tek hedef = daha az kirilma yuzeyi.
//
// ⚠️ Olcusu bilinmeyen (eski) medya "0x0" doner; istemci bunu guvenli
//
//	varsayilana dusurur. NULL DONDURULMEZ — `array_agg` NULL uretirse
//	`[]string` taramasi PATLAR ve satir SESSIZCE atlanir (turu 76 dersi).
const medyaTurleri = `
		       COALESCE((SELECT array_agg(COALESCE(ma.kind,'yok') ORDER BY mm.idx)
		                   FROM unnest(p.media_ids) WITH ORDINALITY AS mm(mid, idx)
		                   LEFT JOIN media_assets ma ON ma.id = mm.mid), '{}'),
		       COALESCE((SELECT array_agg(COALESCE(ma.width,0) || 'x' || COALESCE(ma.height,0) ORDER BY mb.idx)
		                   FROM unnest(p.media_ids) WITH ORDINALITY AS mb(mid, idx)
		                   LEFT JOIN media_assets ma ON ma.id = mb.mid), '{}'),
		       p.duzenlendi_at, p.yayin_at,`

// ⚠️⚠️⚠️ TURU 81 — ZAMANLANMIS GONDERI SUZGECI. **TEK KAYNAK.**
//
// `posts.yayin_at` NULL ise gonderi zamanlanmamistir (hemen yayinda);
// doluysa o ANA KADAR HIC KIMSEYE gorunmez.
//
// ⚠️⚠️ BU YUKLEM **AKIS/KESFET/PROFIL/REELS/KAYDEDILENLER** sorgularinin
//
//	HEPSINDE olmak zorunda. Birinde eksik kalirsa zamanlanmis gonderi o
//	yuzeyden SIZAR — ve bu, "6 sorguya ekleyip 7.'yi atlama" hatasinin
//	(turu 76'da Kaydedilenler'i BOMBOS birakan sinif) YENI bir bicimidir.
//
// ⚠️⚠️ MEVCUT MUHAFIZ BU HATAYI **YAKALAYAMAZ**: `sutun_test.go` yalnizca
//
//	SELECT sutun listesini dogruluyor, WHERE yuklemini DEGIL. Bu yuzden
//	turu 81'de AYRI bir muhafiz eklendi: `yayin_test.go`.
//
// ⚠️ YAZARIN KENDI listesi BILEREK HARIC: kullanici zamanladigi gonderiyi
//
//	kendi profilinde GORMELI (yoksa "kayboldu" sanar). O sorguda yuklem
//	`p.author_id = $me` ile gevsetiliyor.
const yayindaOlan = `
			   AND (p.yayin_at IS NULL OR p.yayin_at <= now())`

const engelYok = `
			   AND NOT EXISTS(SELECT 1 FROM blocks b
			         WHERE (b.blocker_id=$1 AND b.blocked_id=p.author_id)
			            OR (b.blocker_id=p.author_id AND b.blocked_id=$1))`

type Handler struct {
	db *pgxpool.Pool
	// TURU 76: sosyal bildirimlerin WS + push ayagi. nil olabilir (test).
	bil *bildirim.Servis

	// ⚠️⚠️ TURU 83 — GONDERI ANKETI. Anketin TUM mantigi (dogrulama, sayim,
	//    oylama, kapatma) `internal/chat`te; burada YENIDEN YAZILMAZ.
	//    `main` acilista baglar (`SetAnketYazar` / `SetAnketOkuyucu`).
	// ⚠️ NIL ISE anketli gonderi 500 doner ve akista anket cizilmez —
	//    SESSIZCE anketsiz kaydetmek "anket ekledim ama yok" demekti.
	anketYazar   AnketYazar
	anketOkuyucu AnketOkuyucu
}

// AnketYazar — gonderi olusturulurken AYNI islemde anketi yazar.
type AnketYazar func(ctx context.Context, tx pgx.Tx,
	postID, creatorID, soru string, secenekler []string, coklu bool) (int64, error)

// AnketOkuyucu — bir gonderi kumesinin anketlerini TEK sorguda okur.
type AnketOkuyucu func(ctx context.Context, postIDs []string,
	userID string) map[string]map[string]any

func NewHandler(db *pgxpool.Pool, bil *bildirim.Servis) *Handler {
	return &Handler{db: db, bil: bil}
}

// SetAnket — `main` acilista BIR KEZ cagirir.
func (h *Handler) SetAnket(yaz AnketYazar, oku AnketOkuyucu) {
	h.anketYazar, h.anketOkuyucu = yaz, oku
}

// ---------------------------------------------------------------- GONDERI

type postReq struct {
	Tur         string   `json:"tur"` // foto | video | reels | yazi
	Metin       string   `json:"metin"`
	MediaIDs    []string `json:"media_ids"`
	YorumKapali bool     `json:"yorum_kapali"`
	// ⚠️ TURU 81 — ILERI TARIHLI PAYLASIM (RFC3339). Bos ya da GECMIS ise
	//    gonderi HEMEN yayinlanir.
	YayinAt string `json:"yayin_at"`
	// ⚠️⚠️ TURU 83 — GONDERI ANKETI (kullanici emri: "gonderide anket olmasi
	//    elzem"). Bos birakilirsa anket YOK.
	//    Sema: migration 042 · yazan: `chat.GonderiAnketiYaz` (TEK KAYNAK —
	//    dogrulama ve sinirlar sohbet anketiyle AYNI).
	Anket *anketReq `json:"anket,omitempty"`
	// ⚠️ TURU 75b: `ClientRef` KALDIRILDI — hicbir yerde OKUNMUYORDU ve `posts`
	//    tablosunda karsiligi da yok. Olu alan, ileride birinin "tekrar korumasi
	//    var" saniyla yanlis varsayim yapmasina yol acar. Gercekten gerekirse
	//    mesaj tarafindaki gibi TABLO SUTUNU + kismi UNIQUE index ile eklenir
	//    (015'in `messages.client_ref` deseni).
}

// Gonderiye eklenen anketin istek govdesi (sohbet anketiyle AYNI alanlar).
type anketReq struct {
	Question string   `json:"question"`
	Options  []string `json:"options"`
	Multi    bool     `json:"multi"`
}

// POST /posts — gonderi olustur.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req postReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	// ⚠️ TIP BEYAZ LISTESI (turu 59 dersi: istemciden gelen tip DOGRULANMADAN
	//    yazilmamali — DB CHECK'i son savunma, ILK savunma burasi).
	switch req.Tur {
	case "foto", "video", "reels", "yazi":
	default:
		hata(w, 400, "geçersiz gönderi türü")
		return
	}
	// ⚠️ TUTARLILIK: medya tipi ise medya ZORUNLU, 'yazi' ise medya OLMAMALI.
	//    Aksi halde akista BOS KART cizilir (kullanici "paylastim" sanir).
	if req.Tur == "yazi" {
		// ⚠️⚠️ TURU 83 — ANKETLI gonderide METIN BOS OLABILIR: anketin kendi
		//    SORUSU zaten icerik tasir ve kullaniciyi ayrica metin yazmaya
		//    zorlamak anlamsiz. Anket YOKSA eski kural aynen gecerli.
		if strings.TrimSpace(req.Metin) == "" && req.Anket == nil {
			hata(w, 400, "yazı boş olamaz")
			return
		}
		// ⚠️⚠️ nil DEGIL BOS DILIM — SEVK ENGELI OLURDU (kanit: tip_test.go).
		//    pgx nil bir dilimi SQL **NULL** olarak gonderir; `posts.media_ids`
		//    ise **NOT NULL**. `req.MediaIDs = nil` yazsaydik HER YAZI GONDERISI
		//    "null value in column media_ids violates not-null constraint" ile
		//    500 doner ve kullanici hicbir metin paylasamazdi.
		// ⚠️ YAPMA: burayi `nil`e dondurme.
		req.MediaIDs = []string{}
	} else if len(req.MediaIDs) == 0 {
		hata(w, 400, "medya bulunamadı")
		return
	}
	// ⚠️ Coklu gorsel TAVANI: 10 (Instagram deseni). Sinirsiz dizi hem akis
	//    yanitini sisirir hem istemcide bellek sorunu yapar.
	if len(req.MediaIDs) > 10 {
		hata(w, 400, "en fazla 10 medya")
		return
	}
	// ⚠️⚠️ TURU 76 — KARMA GALERI. `tur='foto'` artik "GALERI (1-10 karma medya)"
	//    anlamina geliyor: fotograf ve VIDEO AYNI gonderide olabilir. Kullanici
	//    emri: "paylasimda birden fazla gorsel ve video paylasabilelim, bunlari
	//    galeri seklinde sol sag olarak gorebilmemiz gerekiyor."
	// ⚠️ YENI BIR `tur` DEGERI EKLENMEDI: `posts.tur` CHECK'ini DROP/ADD etmek
	//    021'in serhindeki tuzagi acar (iki migration kisiti bagimsiz yeniden
	//    kurarsa sonra calisan oncekinin degerlerini SILER — 015'te yasandi).
	//    Her medyanin turu `media_kinds` dizisiyle AYRICA donuyor; istemci
	//    galeriyi ONA gore ciziyor.
	// ⚠️ `video` ve `reels` TEK medya olarak KALIR: reels sekmesi ve dikey
	//    oynatici tek bir videoyu varsayar.
	if req.Tur != "foto" && len(req.MediaIDs) > 1 {
		hata(w, 400, "bu türde tek medya olabilir")
		return
	}
	if len(req.Metin) > 2200 {
		req.Metin = kisalt(req.Metin, 2200)
	}

	// ⚠️⚠️ MEDYA SAHIPLIGI + DURUMU DOGRULANIR (mesaj tarafiyla AYNI kural).
	//    Aksi halde biri BASKASININ medya id'sini kendi gonderisine baglayabilir
	//    ya da dogrulanmamis ('beklemede') bir kaydi yayinlayabilirdi.
	if len(req.MediaIDs) > 0 {
		tag, err := h.db.Exec(r.Context(), `
			UPDATE media_assets SET status='bagli', linked_at=now()
			 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
			req.MediaIDs, me)
		if err != nil || int(tag.RowsAffected()) != len(req.MediaIDs) {
			hata(w, 403, "geçersiz medya")
			return
		}
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "gönderi oluşturulamadı")
		return
	}
	defer tx.Rollback(r.Context())

	var id string
	var createdAt time.Time
	// ⚠️⚠️ TURU 81 — ILERI TARIHLI PAYLASIM. `yayin_at` NULL = HEMEN.
	//    GECMIS bir zaman gonderilirse NULL'a cevrilir (yani hemen yayinlanir):
	//    "5 dakika once yayinlansin" anlamsizdir ve saat kaymasi olan bir
	//    cihazdan gelen istegi sessizce reddetmek yerine dogru davranisi
	//    uyguluyoruz.
	var yayinAt *time.Time
	if req.YayinAt != "" {
		if t, err := time.Parse(time.RFC3339, req.YayinAt); err == nil && t.After(time.Now()) {
			// ⚠️ TAVAN: 1 yil. Sinirsiz birakilsaydi bozuk/kotu niyetli bir
			//    deger gonderiyi FIILEN GORUNMEZ yapardi ve kullanici sebebini
			//    anlayamazdi.
			if t.Before(time.Now().AddDate(1, 0, 0)) {
				yayinAt = &t
			} else {
				hata(w, 400, "En fazla 1 yıl sonrasına zamanlayabilirsin")
				return
			}
		}
	}
	// ⚠️⚠️⚠️ ZAMANLANMIS GONDERIDE `created_at` = `yayin_at` (denetim bulgusu:
	//    SEVK ENGELIYDI).
	//
	//	Akis SIRALAMASI ve SAYFALAMA IMLECI `created_at` uzerinden yuruyor.
	//	`created_at` OLUSTURMA ani olarak birakilsaydi, yarina zamanlanan bir
	//	gonderi yayinlandiginda **DUNUN SIRASINDA** belirirdi — yani kimsenin
	//	gormedigi bir yere gomulurdu ve kullanici "paylasildi ama kimse
	//	gormedi" derdi. Ozellik teknik olarak calisir, URUN OLARAK COKERDI.
	//
	// ⚠️ Bu cozum siralama/imlec mantigina HIC DOKUNMADAN calisir: 7 sorgunun
	//    ORDER BY ve cursor ifadeleri AYNEN kalir. Alternatif
	//    (`COALESCE(yayin_at, created_at)` ile siralama) YEDI sorguyu VE
	//    istemcinin imlec sozlesmesini degistirmeyi gerektirirdi.
	// ⚠️ Gorunen TARIH de dogru olur: gonderi yayinlandigi gunun tarihini
	//    tasir (olusturuldugu gunun degil) — kullanicinin bekledigi budur.
	err = tx.QueryRow(r.Context(), `
		INSERT INTO posts (author_id, tur, metin, media_ids, yorum_kapali,
		                   yayin_at, created_at)
		VALUES ($1,$2,$3,$4,$5,$6, COALESCE($6, now())) RETURNING id, created_at`,
		me, req.Tur, req.Metin, req.MediaIDs, req.YorumKapali, yayinAt).
		Scan(&id, &createdAt)
	if err != nil {
		log.Printf("gonderi insert: %v", err)
		hata(w, 500, "gönderi oluşturulamadı")
		return
	}
	// ⚠️⚠️ TURU 83 — ANKET **AYNI ISLEMDE** yazilir. Ayri islem olsaydi anket
	//    yazilirken hata alan bir istek ANKETSIZ bir gonderi birakirdi ve
	//    kullanici "anket ekledim ama yok" derdi (bu projede defalarca yasanan
	//    "yarim kayit" sinifi). Hata olursa `defer tx.Rollback` GONDERIYI DE
	//    geri alir — ya ikisi de olur ya hicbiri.
	// ⚠️ Dogrulama `chat.GonderiAnketiYaz` icinde ve SOHBETLE AYNI sabitlerle
	//    yapilir; burada TEKRAR YAZILMAZ (iki kopya drift eder).
	var anketID *int64
	if req.Anket != nil {
		if h.anketYazar == nil {
			hata(w, 500, "anket eklenemedi")
			return
		}
		pid, aerr := h.anketYazar(r.Context(), tx, id, me,
			req.Anket.Question, req.Anket.Options, req.Anket.Multi)
		if aerr != nil {
			if chat.AnketGecersizMi(aerr) {
				hata(w, 400, "Anket geçersiz: soru ve en az 2 seçenek gerekli")
			} else {
				log.Printf("gonderi anketi: %v", aerr)
				hata(w, 500, "anket eklenemedi")
			}
			return
		}
		anketID = &pid
	}
	// ⚠️ Sayac AYNI TRANSACTION'da (turu 75 takip sisteminde alinan karar).
	tx.Exec(r.Context(), `UPDATE users SET gonderi_sayisi = gonderi_sayisi + 1 WHERE id=$1`, me)
	if err := tx.Commit(r.Context()); err != nil {
		hata(w, 500, "gönderi oluşturulamadı")
		return
	}
	yaz(w, 201, map[string]any{"id": id, "created_at": createdAt, "anket_id": anketID})
}

// PATCH /posts/{id} — kendi gonderini DUZENLE (aciklama + yorum ayari).
//
// ⚠️⚠️ TURU 76 — kullanici emri: "paylastigim gonderilerde duzenleme olmali".
//
//	Bu uc HICBIR KATMANDA yoktu (rota yok, handler yok, menu secenegi yok).
//
// ⚠️ YALNIZ ACIKLAMA VE YORUM AYARI degisir — MEDYA DEGISMEZ (Instagram deseni).
//
//	Sebep: medyayi degistirmek, altinda yorum/begeni birikmis bir icerigi
//	BASKA BIR SEYE cevirmeye izin verirdi (yem-degistir). Medya degisecekse
//	gonderi silinip yenisi paylasilir.
//
// ⚠️ DUZENLENDI DAMGASI GORUNUR: sessizce degistirmek ayni kotu kullanimin
//
//	daha sinsi halidir. Istemci "düzenlendi" etiketi cizer.
func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var req struct {
		Metin       *string `json:"metin"`
		YorumKapali *bool   `json:"yorum_kapali"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if req.Metin != nil {
		*req.Metin = strings.TrimSpace(*req.Metin)
		if len(*req.Metin) > 2200 {
			*req.Metin = kisalt(*req.Metin, 2200)
		}
	}
	// ⚠️ Alanlar POINTER: gonderilmeyen alan DEGISMEZ (kismi guncelleme).
	// ⚠️ `duzenlendi_at` YALNIZ metin GERCEKTEN degistiyse yazilir — yorum
	//    ayarini acip kapamak "düzenlendi" etiketi dogurmamali.
	tag, err := h.db.Exec(r.Context(), `
		UPDATE posts SET
		  metin        = COALESCE($3, metin),
		  yorum_kapali = COALESCE($4, yorum_kapali),
		  duzenlendi_at = CASE
		      WHEN $3 IS NOT NULL AND $3 <> metin THEN now()
		      ELSE duzenlendi_at END
		 WHERE id=$1 AND author_id=$2 AND durum='yayinda'`,
		id, me, req.Metin, req.YorumKapali)
	if err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		// ⚠️ 404 (403 DEGIL): baskasinin gonderisinin VAR OLDUGU bilgisi de bilgidir.
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /posts/{id}/istatistik — YAZARA OZEL sayilar.
//
// ⚠️ Kullanici emri: "orada istatistik olmali, goruntulenme sayisi vs".
// ⚠️ YALNIZ YAZAR gorebilir: baskasinin kaydetme/goruntulenme sayisi ona ait
//
//	bir bilgi degildir (Instagram da yalniz yazara gosterir).
func (h *Handler) Istatistik(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var yazar string
	if h.db.QueryRow(r.Context(),
		`SELECT author_id FROM posts WHERE id=$1 AND durum='yayinda'`, id).
		Scan(&yazar) != nil {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	if yazar != me {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	var begeni, yorum, goruntulenme, kaydetme int
	h.db.QueryRow(r.Context(), `
		SELECT p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,
		       (SELECT count(*) FROM post_saves s WHERE s.post_id=p.id)
		  FROM posts p WHERE p.id=$1`, id).
		Scan(&begeni, &yorum, &goruntulenme, &kaydetme)
	yaz(w, 200, map[string]int{
		"begeni": begeni, "yorum": yorum,
		"goruntulenme": goruntulenme, "kaydetme": kaydetme,
	})
}

// DELETE /posts/{id} — kendi gonderini sil.
// ⚠️ Satir SILINMEZ, `durum='silindi'` yazilir: yorum/begeni FK'leri ve
//
//	istatistikler bozulmasin. Medya `medyayiKopar` mantigiyla dusurulur.
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	var medya []string
	err := h.db.QueryRow(r.Context(), `
		UPDATE posts SET durum='silindi', deleted_at=now()
		 WHERE id=$1 AND author_id=$2 AND durum='yayinda'
		 RETURNING media_ids`, id, me).Scan(&medya)
	if err == pgx.ErrNoRows {
		hata(w, 403, "bu gönderi silinemez")
		return
	}
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	h.db.Exec(r.Context(),
		`UPDATE users SET gonderi_sayisi = GREATEST(gonderi_sayisi - 1, 0) WHERE id=$1`, me)
	// ⚠️ Medya nesneleri silme kuyruguna girer (baska yere bagli degilse).
	//    ⚠️ "Veri silinmez" karariyla CELISMEZ: silmeyi KULLANICI talep ediyor.
	for _, m := range medya {
		h.medyayiKopar(r, m)
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// medyayiKopar — gonderi silinince medyayi dusur (baska yere bagli DEGILSE).
func (h *Handler) medyayiKopar(r *http.Request, mediaID string) {
	var kalan int
	if err := h.db.QueryRow(r.Context(), `
		SELECT (SELECT count(*) FROM messages WHERE media_id=$1)
		     + (SELECT count(*) FROM users WHERE avatar_media_id=$1)
		     + (SELECT count(*) FROM posts
		         WHERE $1 = ANY(media_ids) AND durum='yayinda')
		     + (SELECT count(*) FROM channel_posts
		         WHERE $1 = ANY(media_ids) AND durum='yayinda')
		     + (SELECT count(*) FROM channels WHERE avatar_media_id=$1)`,
		mediaID).Scan(&kalan); err != nil || kalan > 0 {
		return
	}
	var anahtar, thumb string
	if err := h.db.QueryRow(r.Context(), `
		UPDATE media_assets SET status='silindi', deleted_at=now()
		 WHERE id=$1 AND status IN ('aktif','bagli')
		 RETURNING object_key, thumb_key`, mediaID).Scan(&anahtar, &thumb); err != nil {
		return
	}
	for _, a := range []string{anahtar, thumb} {
		if a != "" {
			h.db.Exec(r.Context(),
				`INSERT INTO media_delete_queue (object_key) VALUES ($1)`, a)
		}
	}
}

// ---------------------------------------------------------------- AKIS

// GET /feed?before=<ISO>&limit=N — ana sayfa akisi.
//
// ⚠️⚠️ SAYFALAMA **CURSOR** (offset DEGIL): offset ile, sen kaydirirken yeni
// gonderi gelirse satirlar KAYAR ve ayni gonderi iki kez gorunur / bazilari
// atlanir. Cursor `created_at` uzerinden ve index'ten karsilanir.
// ⚠️ YAPMA: offset sayfalamaya donme.
func (h *Handler) Akis(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	limit := 20
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 50 {
		limit = v
	}
	before := time.Now().Add(time.Hour) // ilk sayfa: "simdiden once"
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}

	// ⚠️⚠️ SOGUK BASLANGIC: takip edilen YOKSA akis BOS DONMEZ.
	// Bos akis, yeni kullanicinin urunu terk etme sebebidir. Takip yoksa
	// "kesfet" (herkese acik, gizli olmayan hesaplarin yeni gonderileri) doner.
	// ⚠️ YAPMA: bos dizi dondurup istemciye "kimseyi takip etmiyorsun" yazdirma.
	var takipVar bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1 AND durum='onayli')`,
		me).Scan(&takipVar)

	var rows pgx.Rows
	var err error
	if takipVar {
		// Takip edilenler + KENDI gonderilerim.
		// ⚠️ ENGEL KAPISI: engellenmis kisilerin gonderileri akista GORUNMEZ.
		rows, err = h.db.Query(r.Context(), `
			SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
			       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
			       p.yorum_kapali, p.created_at,
			       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
			       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
			       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
			  FROM posts p JOIN users u ON u.id = p.author_id
			 WHERE p.durum='yayinda' AND p.created_at < $2
			   AND (p.author_id = $1 OR p.author_id IN (
			         SELECT followee_id FROM follows
			          WHERE follower_id=$1 AND durum='onayli'))
			`+engelYok+yayindaOlan+`
			 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	} else {
		// KESFET: herkese acik hesaplarin yeni gonderileri + KENDI gonderilerim.
		//
		// ⚠️⚠️ "p.author_id = $1 OR ..." SARTI ZORUNLU (denetimde yakalandi):
		//    kimseyi takip etmeyen kullanici bu dala duser; kendi gonderisi
		//    listeye GIRMEZSE "paylastim ama akista yok" yasar. Ustelik GIZLI
		//    hesap kendi gonderisini HIC goremezdi (NOT u.gizli_hesap onu eler).
		// ⚠️⚠️ begendim/kaydettim SABIT 'false' DONUYORDU: bu dalda begenilen
		//    gonderinin kalbi DOLU cizilmez, kullanici tekrar begenmeye calisir
		//    ve sunucu idempotent oldugu icin HICBIR SEY OLMAZ (olu dokunus).
		rows, err = h.db.Query(r.Context(), `
			SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
			       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
			       p.yorum_kapali, p.created_at,
			       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
			       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
			       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
			  FROM posts p JOIN users u ON u.id = p.author_id
			 WHERE p.durum='yayinda' AND p.created_at < $2
			   AND (p.author_id = $1 OR (NOT u.gizli_hesap AND u.verified))
			`+engelYok+yayindaOlan+`
			 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	}
	if err != nil {
		log.Printf("akis: %v", err)
		hata(w, 500, "akış alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{
		"kesfet": !takipVar, // istemci "Keşfet" rozeti gosterir
		"posts":  h.satirlariOku(r.Context(), me, rows),
	})
}

// GET /kesfet — KESFET IZGARASI (arama sekmesinin alt yarisi).
//
// ⚠️⚠️ TURU 76 — kullanici emri: "alt menude arama olmali ... instagram gibi
//
//	normal profil arama". Instagram'da arama sekmesi BOS bir kutu degildir:
//	ustte arama alani, ALTINDA kesfet izgarasi vardir. O izgara icin ayri bir
//	uc gerekiyordu.
//
// ⚠️ `/feed`ten AYRI OLMAK ZORUNDA: `/feed` kesfeti YALNIZ "hic kimseyi takip
//
//	etmiyorsan" doner (soguk baslangic dali). Birini takip eden kullanici
//	`/feed`ten kesfet ALAMAZ; arama sekmesi ONA DA izgara gostermeli.
//	⚠️ YAPMA: bunu `/feed`e bir parametre olarak baglama — o ucun donus
//	   sozlesmesinde `kesfet` bayragi var ve iki anlam birbirine karisir.
//
// ⚠️ YALNIZ MEDYALI gonderiler: izgara kucuk kare kapaklardan olusur, yazi
//
//	gonderisinin kapagi YOKTUR (bos kare cizerdi).
//
// ⚠️ KENDI gonderilerim ELENMEZ: bu olcekte (prototip) izgara aksi halde bos
//
//	kalabilir. Kullanici buyudugunde `p.author_id <> $1` eklenebilir.
func (h *Handler) Kesfet(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	limit := 30
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 60 {
		limit = v
	}
	before := time.Now().Add(time.Hour)
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.durum='yayinda' AND p.created_at < $2
		   AND cardinality(p.media_ids) > 0
		   AND (p.author_id = $1 OR (NOT u.gizli_hesap AND u.verified))
		`+engelYok+yayindaOlan+`
		 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	if err != nil {
		log.Printf("kesfet: %v", err)
		hata(w, 500, "keşfet alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"posts": h.satirlariOku(r.Context(), me, rows)})
}

// GET /users/{id}/posts — bir kullanicinin gonderileri (profil sekmesi).
func (h *Handler) UserPosts(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")

	// ⚠️ GIZLI HESAP: gonderileri yalniz KENDISI ve ONAYLI takipcileri gorur.
	if hedef != me {
		var gizli bool
		h.db.QueryRow(r.Context(), `SELECT gizli_hesap FROM users WHERE id=$1`, hedef).Scan(&gizli)
		if gizli {
			var onayli bool
			h.db.QueryRow(r.Context(), `
				SELECT EXISTS(SELECT 1 FROM follows
				 WHERE follower_id=$1 AND followee_id=$2 AND durum='onayli')`,
				me, hedef).Scan(&onayli)
			if !onayli {
				hata(w, 403, "bu hesap gizli")
				return
			}
		}
	}
	before := time.Now().Add(time.Hour)
	// ⚠️⚠️⚠️ TURU 81 — KENDI PROFILINDE IMLEC TAVANI YUKSELIR (E2E BULGUSU).
	//
	//	Zamanlanmis gonderide `created_at = yayin_at` (yani GELECEKTE).
	//	Varsayilan tavan `now + 1 saat` oldugu icin bir saatten UZAGA
	//	zamanlanan gonderi, GORUNURLUK yuklemine degil **IMLECE** takilip
	//	yazarin KENDI profilinden de kayboluyordu — "yazar kendi
	//	zamanladigini gorur" kurali fiilen CALISMIYORDU.
	//	⚠️ Bu, kendi `created_at = yayin_at` duzeltmemin YAN ETKISIYDI;
	//	   statik denetim GOREMEZ, UCTAN UCA testi yakaladi.
	//
	// ⚠️ YALNIZ kendi profilinde ve YALNIZ ILK SAYFADA: istemci sayfalarken
	//    acik `before` gonderir ve o AYNEN kullanilir (asagida ezilir), yani
	//    sayfalama mantigi DEGISMEZ.
	// ⚠️ Baskasinin profilinde tavan DEGISMEZ: `yayindaOlan` zaten eliyor,
	//    tavani yukseltmek gereksiz satir tarardi.
	if hedef == me {
		before = time.Now().AddDate(1, 0, 1) // sunucu tavani 1 yil + pay
	}
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}
	// ⚠️ TUR SUZGECI (profil sekmeleri: foto/video/reels). Bos ise TUMU.
	//    Istemci bu parametreyi ZATEN gonderiyordu ama sunucu OKUMUYORDU —
	//    sessizce yok sayilan parametre, ileride "neden calismiyor" tuzagidir.
	tur := r.URL.Query().Get("tur")
	switch tur {
	case "", "foto", "video", "reels", "yazi":
	default:
		hata(w, 400, "geçersiz tür")
		return
	}
	// ⚠️⚠️ ENGEL KAPISI (denetim bulgusu — SEVK ENGELIYDI): bu sorguda YOKTU.
	//    Engellenen kisi akista goremedigi kullanicinin profiline girip TUM
	//    gonderilerini okuyabiliyordu. Artik `engelYok` TEK KAYNAGINDAN geliyor.
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.author_id=$2 AND p.durum='yayinda' AND p.created_at < $3
		   AND ($4 = '' OR p.tur = $4)`+engelYok+`
		   -- ⚠️⚠️ TURU 81 — ZAMANLANMIS GONDERI: yazar KENDI listesinde GORUR.
		   --    `+`Diger yuzeylerde `+"`yayindaOlan`"+` yuklemi kosulsuzdur; burada
		   --    `+`YAZARIN KENDISI icin gevsetiliyor. Aksi halde kullanici
		   --    `+`zamanladigi gonderiyi HICBIR YERDE goremez ve "gitmedi"
		   --    `+`sanip tekrar paylasirdi.
		   AND (p.yayin_at IS NULL OR p.yayin_at <= now() OR p.author_id = $1)
		 ORDER BY p.created_at DESC LIMIT 30`, me, hedef, before, tur)
	if err != nil {
		hata(w, 500, "gönderiler alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"posts": h.satirlariOku(r.Context(), me, rows)})
}

// GET /posts/{id} — TEK gonderi.
//
// ⚠️ NEDEN GEREKLI: bildirimden ("X gonderini begendi") ve derin baglantidan
//
//	gelen kullanici gonderiyi tek basina acabilmeli. Akisi bastan cekip icinden
//	aramak hem pahali hem GARANTISIZ (gonderi ilk 20'de olmayabilir).
//
// ⚠️ ERISIM KAPISI `erisebilirMi` ile — begeni/yorum/kaydetme ile AYNI kaynak.
func (h *Handler) Detay(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	// ⚠️ UUID BICIM DOGRULAMASI: gecersiz metin pgx'te sorgu HATASI uretir ve
	//    500 doner.  hatayi zaten "erisilemez" sayiyor ama once
	//    ucuz kontrol yapip DB'ye hic gitmemek daha dogru.
	if len(id) != 36 {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	if ok, sebep := h.erisebilirMi(r.Context(), me, id); !ok {
		kod := 404
		if sebep == "" {
			sebep = "gönderi bulunamadı"
		} else if sebep == "bu hesap gizli" {
			kod = 403
		}
		hata(w, kod, sebep)
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$2),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$2)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.id=$1 AND p.durum='yayinda'`, id, me)
	if err != nil {
		hata(w, 500, "gönderi alınamadı")
		return
	}
	defer rows.Close()
	liste := h.satirlariOku(r.Context(), me, rows)
	if len(liste) == 0 {
		hata(w, 404, "gönderi bulunamadı")
		return
	}
	// ⚠️ Detay = kullanicinin BILEREK actigi sayfa -> goruntulenme burada artar.
	//    (Akista artmaz — bkz. Reels serhi.)
	h.db.Exec(r.Context(),
		`UPDATE posts SET goruntulenme = goruntulenme + 1 WHERE id=$1`, id)
	yaz(w, 200, liste[0])
}

// GET /reels — dikey kisa video akisi.
//
// ⚠️ AKISTAN AYRI UC: reels sekmesi TAKIPTEN BAGIMSIZ calisir (TikTok/Instagram
//
//	deseni) — yeni kullanicinin bos ekran gormemesi icin tek yol bu.
//
// ⚠️ GIZLI hesaplarin reels'i yalniz onayli takipcilerine gorunur.
func (h *Handler) Reels(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	limit := 10
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 30 {
		limit = v
	}
	before := time.Now().Add(time.Hour)
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.durum='yayinda' AND p.tur='reels' AND p.created_at < $2
		   AND (p.author_id = $1
		        OR NOT u.gizli_hesap
		        OR EXISTS(SELECT 1 FROM follows f
		              WHERE f.follower_id=$1 AND f.followee_id=p.author_id
		                AND f.durum='onayli'))
		`+engelYok+yayindaOlan+`
		 ORDER BY p.created_at DESC LIMIT $3`, me, before, limit)
	if err != nil {
		log.Printf("reels: %v", err)
		hata(w, 500, "reels alınamadı")
		return
	}
	defer rows.Close()
	liste := h.satirlariOku(r.Context(), me, rows)

	// ⚠️⚠️ GORUNTULENME YALNIZ REELS VE DETAYDA ARTAR — AKISTA ARTMAZ.
	//    Akista 20 kart TEK ISTEKTE gelir ama kullanici cogunu HIC GORMEZ;
	//    orada saymak sayiyi YALAN yapar. Reels tam ekrandir (kart = ekran),
	//    detay ise kullanicinin BILEREK actigi sayfadir.
	// ⚠️ Sayim KABA: ayni kullanici tekrar bakinca yine artar. Kesin tekil sayim
	//    (kullanici,gonderi) satiri gerektirir ve tam da kacindigimiz yazma
	//    yukunu geri getirir (fan-out karari).
	// ⚠️ TEK SORGU (`= ANY`): gonderi basina UPDATE, sayfa basina 10 yazma demekti.
	// ⚠️ YAPMA: bunu `Akis` icine kopyalama.
	if len(liste) > 0 {
		idler := make([]string, 0, len(liste))
		for _, g := range liste {
			if s, ok := g["id"].(string); ok {
				idler = append(idler, s)
			}
		}
		if len(idler) > 0 {
			h.db.Exec(r.Context(),
				`UPDATE posts SET goruntulenme = goruntulenme + 1 WHERE id = ANY($1)`, idler)
		}
	}
	yaz(w, 200, map[string]any{"posts": liste})
}

// �� TURU 83 — IMZA DEGISTI: ctx + userID ALIYOR.
//
// Sebep YAPISAL: gonderi anketi ALTI ayri sorgunun sonucunda cizilmeli
// (akis, kesfet, profil, kaydedilenler, detay, istatistik). Anketi cagri
// yerlerinde ayri ayri eklemek "alti yere ekle, YEDINCISINI unut" hatasini
// acardi — bu projede turu 76'da tam boyle olmus ve "Kaydedilenler" sayfasi
// HERKESTE BOMBOS kalmisti.
// Imzayi degistirmek DERLEYICIYI zorlayici kilar: yeni bir cagri yeri
// eklendiginde ctx/userID vermeden DERLENMEZ.
// � YAPMA: anket eklemeyi cagri yerlerine tasima.
func (h *Handler) satirlariOku(ctx context.Context, userID string, rows pgx.Rows) []map[string]any {
	out := []map[string]any{}
	for rows.Next() {
		var id, yazarID, tur, metin, ad, kullanici, avatar string
		var medya, turler, boyutlar []string
		var begeni, yorum, goruntulenme int
		var yorumKapali, begendim, kaydettim bool
		var t time.Time
		var duzenlendi, yayinAt *time.Time
		var avatarMedya *string
		// ⚠️ SCAN SIRASI SORGUDAKI SUTUN SIRASIYLA BIREBIR OLMALI. Uyusmazlik
		//    derleme hatasi VERMEZ; ya tip hatasiyla satir SESSIZCE ATLANIR
		//    (asagidaki 'continue') ya da alanlar BIRBIRINE KARISIR.
		// ⚠️ `turler`, `boyutlar` ve `duzenlendi` `goruntulenme`den HEMEN SONRA
		//    gelir (bkz. `medyaTurleri` sabiti — uc parca da oraya ekleniyor).
		if rows.Scan(&id, &yazarID, &tur, &metin, &medya, &begeni, &yorum,
			&goruntulenme, &turler, &boyutlar, &duzenlendi, &yayinAt,
			&yorumKapali, &t, &ad, &kullanici, &avatar, &avatarMedya,
			&begendim, &kaydettim) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "author_id": yazarID, "tur": tur, "metin": metin,
			"media_ids": medya,
			// ⚠️ `media_kinds[i]` <-> `media_ids[i]` AYNI medya (sira korunur).
			"media_kinds": turler,
			// ⚠️⚠️ TURU 81 — "WxH" (or. "1080x1920"); istemci ORANI buradan
			//    turetir ve medyayi KIRPMADAN cizer. Bilinmeyen olcu "0x0".
			"media_boyut":   boyutlar,
			"begeni_sayisi": begeni, "yorum_sayisi": yorum,
			"goruntulenme": goruntulenme,
			"duzenlendi":   duzenlendi != nil,
			// ⚠️⚠️ TURU 81 — ZAMANLANMIS MI (denetim bulgusu). Alan DONMEDEN
			//    istemci "zamanlandi" rozetini CIZEMEZ ve yazar hangi
			//    gonderisinin bekledigini AYIRT EDEMEZ.
			"yayin_at":     yayinAt,
			"yorum_kapali": yorumKapali, "created_at": t,
			"yazar_ad": ad, "yazar_username": kullanici,
			"yazar_avatar": avatar, "yazar_avatar_media_id": avatarMedya,
			"begendim": begendim, "kaydettim": kaydettim,
		})
	}
	// �� TURU 83  GONDERI ANKETLERI **TEK SORGUDA** eklenir (N+1 YASAK).
	//    Okuma `chat.GonderiAnketleri`de; sayim/secenek/benim-oylarim mantigi
	//    orada TEK KAYNAK olarak duruyor ve burada YENIDEN YAZILMIYOR.
	// � `anketOkuyucu` nil ise (test kurulumu) anket alani hic eklenmez ve
	//    akis AYNEN calisir  anket opsiyonel bir sustur, akisin sarti degil.
	if h.anketOkuyucu != nil && len(out) > 0 {
		idler := make([]string, 0, len(out))
		for _, g := range out {
			if s, ok := g["id"].(string); ok {
				idler = append(idler, s)
			}
		}
		anketler := h.anketOkuyucu(ctx, idler, userID)
		if len(anketler) > 0 {
			for _, g := range out {
				if s, ok := g["id"].(string); ok {
					if a, var2 := anketler[s]; var2 {
						g["anket"] = a
					}
				}
			}
		}
	}
	return out
}

func kisalt(s string, n int) string {
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
