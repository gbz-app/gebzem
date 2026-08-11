package randevu

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

type Bildirimci interface {
	Bildir(ctx context.Context, alici, aktor, tur, hedefTur, hedefID string)
}

type Handler struct {
	db *pgxpool.Pool
	bs Bildirimci
}

func NewHandler(db *pgxpool.Pool, bs Bildirimci) *Handler {
	return &Handler{db: db, bs: bs}
}

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, m string) {
	yaz(w, kod, map[string]string{"error": m})
}

// ⚠️⚠️ ENGEL YUKLEMI — YALNIZ OLUSTURMADA. Mevcut randevuyu GIZLEMEZ.
//
//	GEREKCE: onaylanmis bir randevu GERCEK DUNYADA bir taahhuttur. Listeden
//	sessizce dusseydi musteri restorana yine gider, isletme hazirliksiz
//	yakalanirdi. Isletme kaldirmak istiyorsa `iptal_isletme` ile ACIKCA
//	iptal eder ve musteri BILDIRIM alir.
//
// ⚠️ Bu, `engel` yukleminin diger yuzeylerdeki kullanimindan **BILINCLI
//
//	SAPMADIR** — ileride "tutarlilik" adina duzeltilmesin.
const engelYok = `NOT EXISTS(SELECT 1 FROM blocks b
     WHERE (b.blocker_id=$1 AND b.blocked_id=$2)
        OR (b.blocker_id=$2 AND b.blocked_id=$1))`

// ---------------------------------------------------------------- MUSAIT SAAT

// GET /isletmeler/{id}/uygun-saatler?tarih=YYYY-MM-DD
func (h *Handler) UygunSaatler(w http.ResponseWriter, r *http.Request) {
	isletmeID := chi.URLParam(r, "id")
	a, err := AyarOku(r.Context(), h.db, isletmeID)
	if err != nil {
		hata(w, 404, "işletme bulunamadı")
		return
	}
	if !a.Acik {
		// ⚠️ 200 + `acik:false` — 404 DEGIL. Istemci "kapali" ile "yok"u
		//    ayirt edebilmeli; 404 gorseydi hata mesaji cizerdi.
		yaz(w, 200, map[string]any{"acik": false, "slotlar": []any{}})
		return
	}

	loc := Konum()
	gun := time.Now().In(loc)
	if s := r.URL.Query().Get("tarih"); s != "" {
		if t, err := time.ParseInLocation("2006-01-02", s, loc); err == nil {
			gun = t
		}
	}
	gun = time.Date(gun.Year(), gun.Month(), gun.Day(), 0, 0, 0, 0, loc)

	// ⚠️ ILERI GUN SINIRI: cok uzak tarihe randevu, isletmenin planini
	//    kilitler ve no-show orani artar.
	if IleriGunDisi(gun, a) {
		yaz(w, 200, map[string]any{
			"acik": true, "tur": a.Tur, "slotlar": []any{},
			"mesaj": "Bu tarih için randevu açık değil",
		})
		return
	}

	slotlar, err := Slotlar(r.Context(), h.db, isletmeID, gun, a)
	if err != nil {
		log.Printf("randevu slot: %v", err)
		hata(w, 500, "saatler alınamadı")
		return
	}
	yaz(w, 200, map[string]any{
		"acik": true, "tur": a.Tur, "slot_dakika": a.SlotDakika,
		"ileri_gun": a.IleriGun, "slotlar": slotlar,
	})
}

// ---------------------------------------------------------------- OLUSTUR

type olusturReq struct {
	Baslangic  string `json:"baslangic"` // RFC3339
	KisiSayisi int    `json:"kisi_sayisi"`
	Hizmet     string `json:"hizmet"`
	NotMusteri string `json:"not_musteri"`
}

// POST /isletmeler/{id}/randevu
func (h *Handler) Olustur(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	isletmeID := chi.URLParam(r, "id")
	if isletmeID == me {
		hata(w, 400, "Kendi işletmenden randevu alamazsın")
		return
	}

	var req olusturReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	bas, err := time.Parse(time.RFC3339, req.Baslangic)
	if err != nil {
		hata(w, 400, "geçersiz tarih")
		return
	}
	if bas.Before(time.Now()) {
		hata(w, 400, "Geçmiş bir saate randevu alınamaz")
		return
	}

	a, err := AyarOku(r.Context(), h.db, isletmeID)
	if err != nil || !a.Acik {
		hata(w, 404, "Bu işletme randevu almıyor")
		return
	}
	if IleriGunDisi(bas, a) {
		hata(w, 400, "Bu tarih için randevu açık değil")
		return
	}

	// ⚠️ ENGEL: iki yonlu.
	var engelsiz bool
	h.db.QueryRow(r.Context(),
		`SELECT `+engelYok, me, isletmeID).Scan(&engelsiz)
	if !engelsiz {
		hata(w, 403, "Bu işletmeden randevu alınamıyor")
		return
	}

	// ⚠️⚠️⚠️ TURU 80b — TAKVIM KURALLARI YAZMA YOLUNDA DA DOGRULANIR (denetim).
	//
	//	Onceki surumde `Olustur` yalnizca "gecmis mi", "ileri_gun" ve KAPASITE'ye
	//	bakiyordu; KAPALI GUN · CALISMA SAATI · SLOT HIZASI kurallari YALNIZ
	//	okuma yolunda (`UygunSaatler` -> `Slotlar`) yasiyordu. Yani istemci
	//	takvimi hic acmadan dogrudan POST atarak **bayramda saat 03:17'ye**
	//	randevu yazdirabilirdi; isletme kapali oldugunu bilmeden musteri bekler.
	//	Arayuzun kurala uymasi kuralin UYGULANDIGI anlamina GELMEZ.
	//
	// ⚠️ KURAL IKINCI KEZ YAZILMAZ: uretecin KENDISI cagrilir (`SlotVarMi`) ve
	//    istenen anin uretilen slotlar arasinda olup olmadigina bakilir.
	//    Boylece calisma saati / GECE YARISI SARMASI / gecmis-slot eleme
	//    mantigi TEK KAYNAKTA kalir (turu 75b/H "ayni kuralin iki kopyasi
	//    drift eder" dersi).
	// ⚠️ Gun secimi `SlotVarMi` icinde: bir slot ONCEKI gunun calisma
	//    penceresine ait olabilir (22:00-02:00). Burada elle gun hesaplama.
	uygun, err := SlotVarMi(r.Context(), h.db, isletmeID, bas, a)
	if err != nil {
		log.Printf("randevu slot dogrulama: %v", err)
		hata(w, 500, "randevu oluşturulamadı")
		return
	}
	if !uygun {
		hata(w, 409, "Bu saat için randevu alınamıyor")
		return
	}

	if req.KisiSayisi < 1 {
		req.KisiSayisi = 1
	}
	if req.KisiSayisi > 50 {
		req.KisiSayisi = 50
	}
	tur := a.Tur
	durum := Bekliyor
	if a.OtomatikOnay {
		durum = Onaylandi
	}

	// ⚠️⚠️⚠️ CAKISMA KONTROLU — ISLETME BASINA **ADVISORY KILIT** + TEK DEYIM.
	//
	//	`INSERT ... SELECT ... WHERE (count) < kapasite` TEK BASINA ATOMIK
	//	DEGILDIR: READ COMMITTED'da escamanli iki istek AYNI sayimi okur ve
	//	IKISI DE gecer. `kapasite=1` olan bir DOKTORDA bu, BEKLEME ODASINDA
	//	IKI HASTA demektir.
	//	Kilit ISLETME BASINA ve mikrosaniyelik; GLOBAL degil, yani cx33'te
	//	LiveKit'i ac birakmaz. Islem bitince OTOMATIK birakilir (unlock yolu
	//	YOK -> hata dalinda kilit SIZMAZ).
	// ⚠️ YAPMA: kilidi kaldirip yalniz `count < kapasite`ya guvenme.
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "randevu oluşturulamadı")
		return
	}
	defer tx.Rollback(context.WithoutCancel(r.Context()))

	if _, err := tx.Exec(r.Context(),
		`SELECT pg_advisory_xact_lock(hashtext($1))`,
		"randevu:"+isletmeID); err != nil {
		hata(w, 500, "randevu oluşturulamadı")
		return
	}

	bit := bas.Add(time.Duration(a.SlotDakika) * time.Minute)
	var id string
	err = tx.QueryRow(r.Context(), `
		INSERT INTO randevular
		  (isletme_id, musteri_id, tur, baslangic, sure_dakika,
		   kisi_sayisi, hizmet, not_musteri, durum)
		SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9
		 WHERE (SELECT count(*) FROM randevular x
		         WHERE x.isletme_id=$1
		           AND x.durum = ANY($10)
		           -- ⚠️ ARALIK ORTUSMESI (esitlik DEGIL): bkz. slot.go serhi.
		           AND x.baslangic < $11
		           AND x.baslangic + (x.sure_dakika || ' minutes')::interval > $4
		       ) < $12
		RETURNING id`,
		isletmeID, me, tur, bas, a.SlotDakika,
		req.KisiSayisi, kisalt(req.Hizmet, 120), kisalt(req.NotMusteri, 500),
		durum, AktifDurumlar, bit, a.SlotKapasite).Scan(&id)

	if errors.Is(err, pgx.ErrNoRows) {
		hata(w, 409, "Bu saat doldu, başka bir saat seç")
		return
	}
	if err != nil {
		log.Printf("randevu olustur: %v", err)
		hata(w, 500, "randevu oluşturulamadı")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		log.Printf("randevu commit: %v", err)
		hata(w, 500, "randevu oluşturulamadı")
		return
	}

	// ⚠️ Bildirim ISLETMEYE. `WithoutCancel`: istemci kapansa bile isletme
	//    talebi ogrenmeli.
	if h.bs != nil {
		h.bs.Bildir(context.WithoutCancel(r.Context()),
			isletmeID, me, BildirimYeni, "randevu", id)
	}
	yaz(w, 201, map[string]any{"id": id, "durum": durum, "tur": tur})
}

// ---------------------------------------------------------------- DURUM

type durumReq struct {
	Durum      string `json:"durum"`
	NotIsletme string `json:"not_isletme"`
}

// POST /randevular/{id}/durum
func (h *Handler) DurumDegistir(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")

	var req durumReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	g, ok := Gecisler[req.Durum]
	if !ok {
		hata(w, 400, "geçersiz durum")
		return
	}

	var isletmeID, musteriID, mevcut string
	err := h.db.QueryRow(r.Context(), `
		SELECT isletme_id, musteri_id, durum FROM randevular WHERE id=$1`, id).
		Scan(&isletmeID, &musteriID, &mevcut)
	if err != nil {
		hata(w, 404, "randevu bulunamadı")
		return
	}

	// ⚠️ KIM YAPABILIR: gecis tablosundan. `iptal` YALNIZ musteri, digerleri
	//    YALNIZ isletme.
	yapan := isletmeID
	karsi := musteriID
	if !g.IsletmeYapar {
		yapan = musteriID
		karsi = isletmeID
	}
	if me != yapan {
		hata(w, 403, "bu işlem için yetkin yok")
		return
	}
	if !slices.Contains(g.Onceki, mevcut) {
		hata(w, 409, "Bu randevu artık değiştirilemez")
		return
	}

	// ⚠️⚠️ TURU 80b — `not_isletme`YE YALNIZ ISLETME YAZAR (denetim).
	//
	//	Alan adi "isletme notu" olmasina ragmen yetki kapisi YALNIZ `durum`
	//	gecisini kontrol ediyordu; `iptal` gecisini MUSTERI yaptigi icin
	//	musteri ayni istekte `not_isletme` gonderip isletmenin kendi
	//	kayitlarina metin yazabiliyordu (musteriye gorunen alan `not_musteri`).
	// ⚠️ YAPMA: bu kapiyi kaldirip alani tek `COALESCE`a dondurme.
	notIsletme := ""
	if g.IsletmeYapar {
		notIsletme = kisalt(req.NotIsletme, 500)
	}

	// ⚠️ `AND durum=$3` YARIS KAPISI: iki es zamanli istek ayni gecisi
	//    yapamaz (ikincisi 0 satir etkiler).
	tag, err := h.db.Exec(r.Context(), `
		UPDATE randevular SET durum=$2, not_isletme=COALESCE(NULLIF($4,''), not_isletme),
		       updated_at=now()
		 WHERE id=$1 AND durum=$3`,
		id, req.Durum, mevcut, notIsletme)
	if err != nil || tag.RowsAffected() == 0 {
		hata(w, 409, "Bu randevu artık değiştirilemez")
		return
	}

	if g.Bildirim != "" && h.bs != nil {
		h.bs.Bildir(context.WithoutCancel(r.Context()),
			karsi, yapan, g.Bildirim, "randevu", id)
	}
	yaz(w, 200, map[string]any{"ok": true, "durum": req.Durum})
}

// ---------------------------------------------------------------- LISTELER

// ⚠️⚠️ SELECT sutun sirasi ile `Scan` sirasi BIREBIR — bu projede ayrildiginda
//
//	satirlar SESSIZCE atlanir ve liste BOMBOS doner (turu 76 "Kaydedilenler").
const sutunlar = `r.id, r.isletme_id, r.musteri_id, r.tur, r.baslangic,
	r.sure_dakika, r.kisi_sayisi, r.hizmet, r.not_musteri, r.not_isletme,
	r.durum, r.created_at`

func (h *Handler) oku(rows pgx.Rows, karsiAd, karsiKadi, karsiAvatar bool) []map[string]any {
	out := []map[string]any{}
	for rows.Next() {
		var id, isletmeID, musteriID, tur, hizmet, notM, notI, durum string
		var bas, olusma time.Time
		var sure, kisi int
		var ad, kadi string
		var avatar *string
		var err error
		if karsiAd {
			err = rows.Scan(&id, &isletmeID, &musteriID, &tur, &bas, &sure,
				&kisi, &hizmet, &notM, &notI, &durum, &olusma,
				&ad, &kadi, &avatar)
		} else {
			err = rows.Scan(&id, &isletmeID, &musteriID, &tur, &bas, &sure,
				&kisi, &hizmet, &notM, &notI, &durum, &olusma)
		}
		if err != nil {
			log.Printf("randevu scan: %v", err)
			continue
		}
		m := map[string]any{
			"id": id, "isletme_id": isletmeID, "musteri_id": musteriID,
			"tur": tur, "baslangic": bas, "sure_dakika": sure,
			"kisi_sayisi": kisi, "hizmet": hizmet,
			"not_musteri": notM, "not_isletme": notI,
			"durum": durum, "created_at": olusma,
		}
		if karsiAd {
			m["karsi_ad"] = ad
			m["karsi_kullanici_adi"] = kadi
			m["karsi_avatar_media_id"] = avatar
		}
		out = append(out, m)
	}
	return out
}

// GET /randevularim?gecmis=1
func (h *Handler) Randevularim(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	gecmis := r.URL.Query().Get("gecmis") == "1"
	// ⚠️ "Gecmis" bir DURUM DEGIL, bir SORGU SUZGECI (veri politikasi).
	kosul := "r.baslangic >= now()"
	sira := "ASC"
	if gecmis {
		kosul = "r.baslangic < now()"
		sira = "DESC"
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT `+sutunlar+`, u.name, COALESCE(u.username,''), u.avatar_media_id
		  FROM randevular r
		  JOIN users u ON u.id = r.isletme_id
		 WHERE r.musteri_id=$1 AND `+kosul+`
		 ORDER BY r.baslangic `+sira+` LIMIT 100`, me)
	if err != nil {
		log.Printf("randevularim: %v", err)
		hata(w, 500, "randevular alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"randevular": h.oku(rows, true, true, true)})
}

// GET /isletme/randevular?gecmis=1&durum=bekliyor
func (h *Handler) IsletmeRandevulari(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	gecmis := r.URL.Query().Get("gecmis") == "1"
	kosul := "r.baslangic >= now()"
	sira := "ASC"
	if gecmis {
		kosul = "r.baslangic < now()"
		sira = "DESC"
	}
	durum := r.URL.Query().Get("durum")
	rows, err := h.db.Query(r.Context(), `
		SELECT `+sutunlar+`, u.name, COALESCE(u.username,''), u.avatar_media_id
		  FROM randevular r
		  JOIN users u ON u.id = r.musteri_id
		 WHERE r.isletme_id=$1 AND `+kosul+`
		   AND ($2 = '' OR r.durum = $2)
		 ORDER BY r.baslangic `+sira+` LIMIT 100`, me, durum)
	if err != nil {
		log.Printf("isletme randevulari: %v", err)
		hata(w, 500, "randevular alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"randevular": h.oku(rows, true, true, true)})
}

// ---------------------------------------------------------------- AYAR

// GET /isletme/randevu-ayar
// AyarGetir — SAHIBIN kendi randevu ayarlari.
//
// ⚠️⚠️ TURU 80b — BURADA `hesap_turu` KAPISI **YOKTUR** (denetim bulgusu).
//
//	Kapi `AyarOku` icindedir ve amaci RANDEVU ALINMASINI durdurmaktir
//	(`UygunSaatler` + `Olustur` oradan gecer). Ama bu uc SALT OKUMADIR ve
//	yalnizca SAHIBIN kendi ayarlarini dondurur — randevu alinmasini
//	saglamaz. Kapiyi buraya da uygulamak, kisisele donmus bir isletmeye
//	404 dondurup **ayar ekranini komple oldururdu**; o ekran ise
//	"Gelen randevular" kutusuna giden TEK arayuz yoludur. Sonuc: ex-isletme
//	KENDI GECMIS randevu kayitlarina ulasamazdi (uc `IsletmeRandevulari`
//	calisiyor olmasina RAGMEN) — "olu ozellik" sinifinin ters yonu.
//
// ⚠️ Bu yuzden ayarlar `isletmeler` satiri VARSA dondurulur; `acik`
//
//	degeri saklanan degerdir ve hesap kisiselken FIILEN ATILDIR
//	(profilde dugme cizilmez, `Olustur` reddeder).
//
// ⚠️ YAPMA: buraya `hesap_turu` kapisi ekleme; kapinin yeri `AyarOku`dur.
func (h *Handler) AyarGetir(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	a, err := AyarOkuSahip(r.Context(), h.db, me)
	if err != nil {
		hata(w, 404, "önce işletme hesabına geç")
		return
	}
	yaz(w, 200, a)
}

type ayarReq struct {
	Acik         *bool `json:"acik"`
	SlotDakika   *int  `json:"slot_dakika"`
	SlotKapasite *int  `json:"slot_kapasite"`
	IleriGun     *int  `json:"ileri_gun"`
	OtomatikOnay *bool `json:"otomatik_onay"`
}

// PUT /isletme/randevu-ayar
//
// ⚠️⚠️ TUM ALANLAR ISARETCI ("gonderilmedi" != "0"/"false") ve SQL'de
//
//	`COALESCE($n, mevcut)` kullanilir. Turu 78b'de tam bu tuzak yasandi:
//	isaretci yapilip UPDATE dali duzeltilmis ama INSERT dali atlanmisti ve
//	`nil -> SQL NULL` NOT NULL sutuna gidip HER ISTEKTE 500 dondurmustu.
//	Burada INSERT dali da COALESCE ile varsayilanlara duser.
//
// ⚠️⚠️⚠️ TURU 80b — UPDATE DALI **HAM PARAMETRELERI** ($2..$6) KULLANIR,
// `EXCLUDED`I **DEGIL**. SEVK ENGELI DUZELTMESI (denetim bulgusu):
//
//	`EXCLUDED.acik` = INSERT'te YAZILACAK deger = `COALESCE($2,false)` ve bu
//	**ASLA NULL DEGILDIR**. Dolayisiyla eski yazim
//	`COALESCE(EXCLUDED.acik, randevu_ayar.acik)` HER ZAMAN EXCLUDED'i secer
//	ve koruma **OLU KODDU**.
//
//	SONUC: kullanici yalnizca "Otomatik onayla" anahtarini cevirdiginde
//	istemci `{otomatik_onay:true}` gonderir; digerleri NULL gelir ama INSERT
//	dalindaki COALESCE onlari VARSAYILANA cevirir ve UPDATE dali o
//	varsayilanlari YAZAR: **slot suresi 60 -> 30, kapasite 10 -> 1, ileri gun
//	30 -> 14 SESSIZCE SIFIRLANIR.**
//
//	⚠️ Bu, turu 78'in koordinat ezme hatasinin BIREBIR aynisi ve uyarisi TAM
//	   BU FONKSIYONUN serhinde yaziliydi — yine de yapildi.
//	⚠️ DERS: "COALESCE yazdim" YETMEZ. COALESCE'in ILK argumaninin GERCEKTEN
//	   NULL OLABILDIGINI dogrula; INSERT'te sarilmis bir ifade EXCLUDED'da
//	   ASLA null gelmez.
//
// ⚠️ YAPMA: UPDATE dalinda `EXCLUDED`e geri donme.
func (h *Handler) AyarKaydet(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req ayarReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	// ⚠️ Isletme hesabi ZORUNLU: aksi halde kisisel hesap "randevu aliyorum"
	//    diyebilir ve profilinde ULASILAMAZ bir dugme cizilirdi.
	var isletmeVar bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM isletmeler WHERE user_id=$1)`, me).
		Scan(&isletmeVar)
	if !isletmeVar {
		hata(w, 400, "Önce işletme hesabına geç")
		return
	}
	_, err := h.db.Exec(r.Context(), `
		INSERT INTO randevu_ayar
		  (isletme_id, acik, slot_dakika, slot_kapasite, ileri_gun, otomatik_onay)
		VALUES ($1, COALESCE($2,false), COALESCE($3,30), COALESCE($4,1),
		        COALESCE($5,14), COALESCE($6,false))
		-- TURU 80b: UPDATE dali HAM PARAMETRELERI kullanir, EXCLUDED'i DEGIL.
		-- Ayrinti ve gerekce fonksiyon serhinde (SEVK ENGELI duzeltmesi).
		ON CONFLICT (isletme_id) DO UPDATE SET
		  acik          = COALESCE($2, randevu_ayar.acik),
		  slot_dakika   = COALESCE($3, randevu_ayar.slot_dakika),
		  slot_kapasite = COALESCE($4, randevu_ayar.slot_kapasite),
		  ileri_gun     = COALESCE($5, randevu_ayar.ileri_gun),
		  otomatik_onay = COALESCE($6, randevu_ayar.otomatik_onay),
		  updated_at    = now()`,
		me, req.Acik, req.SlotDakika, req.SlotKapasite, req.IleriGun,
		req.OtomatikOnay)
	if err != nil {
		log.Printf("randevu ayar: %v", err)
		hata(w, 500, "ayar kaydedilemedi")
		return
	}
	// ⚠️⚠️ TURU 80b — OKUMA HATASI YUTULMAZ (denetim bulgusu).
	//
	//	Eskiden `a, _ := AyarOku(...)` yaziliyordu. Yazma BASARILI olduktan
	//	sonra okuma patlarsa (ag/DB dalgalanmasi) `a` sifir degerli SAHTE bir
	//	yapiydi ve 200 ile donuyordu. Istemci yaniti dogrudan state'e yazdigi
	//	icin (`setState(() => _a = a)`) ekranda UYDURMA varsayilanlar
	//	gorunurdu: `acik=false` -> **ayar bloku kaybolur**, yani kullanici
	//	az once kaydettigi ayarin geri alindigini sanardi. Ustelik bu, tam
	//	da bu turda kapattigimiz SEVK ENGELININ semptomunun aynisidir.
	//
	// ⚠️ `AyarOkuSahip`: hesap turu kapisi burada ISTENMEZ — sahip kendi
	//    ayarini yazdi, okurken kapiya takilmasi anlamsiz olurdu.
	a, err := AyarOkuSahip(r.Context(), h.db, me)
	if err != nil {
		log.Printf("randevu ayar okuma (yazma basarili): %v", err)
		hata(w, 500, "ayar kaydedildi ama okunamadı, sayfayı yenile")
		return
	}
	yaz(w, 200, a)
}

// POST /isletme/randevu-kapali {tarih, kapali}
//
// ⚠️ Bayram/tatil. Bu uc OLMADAN `calisma` JSONB'si "acik" dedigi icin sunucu
//
//	bayram gununde de slot uretmeye DEVAM ederdi.
func (h *Handler) KapaliGun(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req struct {
		Tarih  string `json:"tarih"`
		Kapali bool   `json:"kapali"`
	}
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if _, err := time.Parse("2006-01-02", req.Tarih); err != nil {
		hata(w, 400, "geçersiz tarih")
		return
	}
	var err error
	if req.Kapali {
		_, err = h.db.Exec(r.Context(), `
			INSERT INTO randevu_kapali (isletme_id, tarih) VALUES ($1,$2::date)
			ON CONFLICT DO NOTHING`, me, req.Tarih)
	} else {
		_, err = h.db.Exec(r.Context(),
			`DELETE FROM randevu_kapali WHERE isletme_id=$1 AND tarih=$2::date`,
			me, req.Tarih)
	}
	if err != nil {
		hata(w, 500, "kaydedilemedi")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /isletme/randevu-kapali?ay=YYYY-MM
func (h *Handler) KapaliGunler(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT to_char(tarih,'YYYY-MM-DD') FROM randevu_kapali
		 WHERE isletme_id=$1 AND tarih >= current_date
		 ORDER BY tarih LIMIT 120`, me)
	if err != nil {
		hata(w, 500, "alınamadı")
		return
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var s string
		if rows.Scan(&s) == nil {
			out = append(out, s)
		}
	}
	yaz(w, 200, map[string]any{"gunler": out})
}

func kisalt(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// ⚠️ `strconv` importu ileride sayfalama icin — su an kullanilmiyorsa derleyici
//
//	uyarir; bu yuzden burada acikca tuketiliyor.
var _ = strconv.Itoa
