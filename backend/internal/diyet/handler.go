// Package diyet — DIYET TAKIBI (turu 91).
//
// Kullanici emri: *"diyetisyende mesela profilde DIYETIM olsun... diyetimde
// KALORI, YIYECEK ADI, KALORI SAYIMI, OLCUM vb. seyler olacak; DIYET LISTESI —
// hangi diyetisyenle calisiyorsan diyet listesi olacak"*.
//
// ═══════════ UC SATIRLIK AYRIM KURALI (migration 045'ten) ═══════════
//
//	(a) SATILABILIR paket/danismanlik   -> `isletme_urunleri` (herkese acik)
//	(b) KISIYE OZEL kayit/olcum/liste   -> `diyet_kayit`      (riza kapili)
//	(c) RIZA                            -> `diyet_bag`
//
// ⚠️⚠️ SAGLIK VERISI HASSASTIR. Bu paketteki HER okuma `diyetErisim()`
//
//	kapisindan gecer ve o kapi TEK KAYNAKTIR. Yuklemi cagri yerlerine
//	kopyalamak, bu projede DORT kez sahaya cikan "ayni kuralin iki kopyasi
//	drift eder" sinifini acardi — ve buradaki bedeli SAGLIK VERISI SIZINTISI
//	olurdu.
package diyet

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
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

func kisalt(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return strings.TrimSpace(string(r[:n]))
}

// ⚠️ KAYIT TURU BEYAZ LISTESI — DB'de CHECK YOK (045 gerekcesi: yeni bir tur
//
//	(su takibi, adim, uyku) MIGRATION GEREKTIRMESIN).
var diyetTurleri = map[string]bool{
	"ogun": true, "olcum": true, "liste": true,
}

// ⚠️ BAG DURUMLARI. `aktif` DISINDAKI hicbir durum okuma yetkisi VERMEZ.
var bagDurumlari = map[string]bool{
	"aktif": true, "reddedildi": true, "sonlandi": true,
}

// ═══════════════════════ RIZA KAPISI — TEK KAYNAK ═══════════════════════

// diyetErisim — `me`, `hedef` kisinin diyet verisini gorebilir mi?
//
// ⚠️⚠️ BU FONKSIYON BU PAKETIN GUVENLIK CEKIRDEGIDIR. Iki dal:
//
//  1. Kendi verisi (`me == hedef`)                     -> HER ZAMAN evet
//  2. `diyet_bag` satiri `aktif`                        -> evet
//     Baska HICBIR yol yoktur: takip, randevu, sohbet ya da isletme olmak
//     TEK BASINA yetki VERMEZ.
//
// ⚠️ FAIL-CLOSED: sorgu patlarsa `false` doner (log'lanir). Saglik verisinde
//
//	"emin degilsem gostereyim" kabul edilemez.
//
// ⚠️ YAPMA: bu yuklemi cagri yerlerine kopyalama.
func (h *Handler) diyetErisim(ctx context.Context, me, hedef string) bool {
	if me == hedef {
		return true
	}
	// ⚠️⚠️⚠️ TURU 93b — OKUMA **TEK YONLU** (denetimde yakalanan gizlilik acigi).
	//
	//	Yuklem CIFT YONLUYDU: `(danisan=$1 AND diyetisyen=$2) OR (danisan=$2 AND diyetisyen=$1)`
	//	Yani aktif bagi olan bir DANISAN, `GET /diyet/kayitlar?user_id=<diyetisyen>`
	//	ve `GET /diyet/ozet?user_id=<diyetisyen>` cagirip **DIYETISYENIN
	//	KENDI KILOSUNU, BEL OLCUSUNU VE OGUNLERINI** okuyabiliyordu.
	//	Bu SAGLIK VERISIDIR ve boyle bir urun karsiligi YOK (istemcide
	//	danisanin diyetisyenin verisine baktigi HICBIR ekran yok).
	//
	// ⚠️ DOGRU YON: diyetisyen DANISANI gorur; danisan diyetisyeni GORMEZ.
	//    (`me == hedef` kisa devresi zaten ustte — herkes KENDI verisini
	//    her zaman gorur.)
	// ⚠️ YAPMA: yuklemi tekrar cift yonlu yapma.
	var v bool
	err := h.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM diyet_bag
			 WHERE durum='aktif'
			   AND danisan_id=$1 AND diyetisyen_id=$2)`, hedef, me).Scan(&v)
	if err != nil {
		log.Printf("diyet erisim: %v", err)
		return false
	}
	return v
}

// ═══════════════════════ BAG (RIZA) UCLARI ═══════════════════════

type bagReq struct {
	DiyetisyenID string `json:"diyetisyen_id"`
	DanisanID    string `json:"danisan_id"`
}

// POST /diyet/bag — bag istegi.
//
// ⚠️ IKI YONLU: danisan diyetisyene ("seninle calismak istiyorum") ya da
//
//	diyetisyen danisana ("seni danisan olarak ekleyeyim mi") istek atabilir.
//	`baslatan_id` KIMIN ISTEDIGINI tutar ve ONAY karsi taraftan gelir.
//
// ⚠️ Ayni cift icin IKINCI SATIR ACILMAZ (UNIQUE): yeniden baslatma AYNI
//
//	satirin durumunu degistirir. Aksi halde "sonlandi" bir satir dururken
//	ikinci bir "aktif" satir acilabilir ve okuma kapisi DELINIRDI.
func (h *Handler) BagIste(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req bagReq
	json.NewDecoder(r.Body).Decode(&req)

	danisan, diyetisyen := me, strings.TrimSpace(req.DiyetisyenID)
	if diyetisyen == "" {
		// Diyetisyen tarafi baslatiyor.
		danisan, diyetisyen = strings.TrimSpace(req.DanisanID), me
	}
	if !kimlik.Gecerli(danisan) || !kimlik.Gecerli(diyetisyen) ||
		danisan == diyetisyen {
		hata(w, 400, "geçersiz istek")
		return
	}

	// ⚠️ DIYETISYEN TARAFI GERCEKTEN DIYETISYEN MI: aksi halde herhangi biri
	//    kendini "diyetisyen" ilan edip baskasinin saglik verisine erisim
	//    istegi gonderebilirdi. Kapi ISLETME KATEGORISINE bakar.
	var uygun bool
	if err := h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM isletmeler i JOIN users u ON u.id=i.user_id
		               WHERE i.user_id=$1 AND i.kategori='diyetisyen'
		                 AND u.hesap_turu='isletme')`, diyetisyen).Scan(&uygun); err != nil {
		hata(w, 500, "istek gönderilemedi")
		return
	}
	if !uygun {
		hata(w, 400, "seçilen hesap diyetisyen değil")
		return
	}

	var id string
	// ⚠️ TEKRAR ISTEK: mevcut satir 'reddedildi'/'sonlandi' ise YENIDEN
	//    'bekliyor'a doner (kullanici fikrini degistirebilmeli). 'aktif' ya da
	//    'bekliyor' ise DOKUNULMAZ — ve bu HATA DEGILDIR (idempotent).
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO diyet_bag (danisan_id, diyetisyen_id, baslatan_id)
		VALUES ($1,$2,$3)
		ON CONFLICT (danisan_id, diyetisyen_id) DO UPDATE
		   SET durum='bekliyor', baslatan_id=EXCLUDED.baslatan_id,
		       guncellendi_at=now()
		 WHERE diyet_bag.durum IN ('reddedildi','sonlandi')
		RETURNING id`, danisan, diyetisyen, me).Scan(&id)
	if err != nil {
		// ⚠️ Satir DOKUNULMADIYSA (zaten bekliyor/aktif) `RETURNING` bos doner
		//    ve pgx `ErrNoRows` verir. Bu BASARIDIR, hata degil.
		var mevcut, durum string
		if h.db.QueryRow(r.Context(), `
			SELECT id, durum FROM diyet_bag
			 WHERE danisan_id=$1 AND diyetisyen_id=$2`,
			danisan, diyetisyen).Scan(&mevcut, &durum) != nil {
			hata(w, 500, "istek gönderilemedi")
			return
		}
		yaz(w, 200, map[string]any{"id": mevcut, "durum": durum})
		return
	}

	// ⚠️ Bildirim KARSI TARAFA gider (baslatan degil).
	if h.bs != nil {
		alici := diyetisyen
		if me == diyetisyen {
			alici = danisan
		}
		h.bs.Bildir(r.Context(), alici, me, "diyet_istek", "diyet", id)
	}
	yaz(w, 200, map[string]any{"id": id, "durum": "bekliyor"})
}

// PATCH /diyet/bag/{id} — bagi onayla / reddet / sonlandir.
//
// ⚠️⚠️ RIZA KAPISI: `aktif` YALNIZCA `baslatan_id <> me` olan taraf
//
//	yapabilir. Bu sutun olmasaydi kisi KENDI istegini KENDISI onaylayip
//	baskasinin saglik verisine erisebilirdi.
//
// ⚠️ `reddedildi`/`sonlandi` HER IKI taraftan yapilabilir: rizayi geri almak
//
//	tek tarafli bir haktir.
func (h *Handler) BagDurum(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Durum string `json:"durum"`
	}
	if json.NewDecoder(r.Body).Decode(&req) != nil || !bagDurumlari[req.Durum] {
		hata(w, 400, "geçersiz durum")
		return
	}

	kosul := ` AND (danisan_id=$3 OR diyetisyen_id=$3)`
	if req.Durum == "aktif" {
		// ⚠️ ONAY: yalniz KARSI taraf + yalniz 'bekliyor' durumundan.
		kosul += ` AND baslatan_id <> $3 AND durum='bekliyor'`
	}
	tag, err := h.db.Exec(r.Context(),
		`UPDATE diyet_bag SET durum=$2, guncellendi_at=now()
		  WHERE id=$1`+kosul, id, req.Durum, me)
	if err != nil {
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		// ⚠️ 404: "yetkin yok" ile "boyle bir bag yok" ayrimi SIZDIRILMAZ.
		hata(w, 404, "bağ bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /diyet/baglarim — kendi baglarim (danisan gorunumu).
func (h *Handler) Baglarim(w http.ResponseWriter, r *http.Request) {
	h.bagListe(w, r, "danisan_id", "diyetisyen_id")
}

// GET /diyet/danisanlarim — diyetisyen gorunumu.
func (h *Handler) Danisanlarim(w http.ResponseWriter, r *http.Request) {
	h.bagListe(w, r, "diyetisyen_id", "danisan_id")
}

// ⚠️ TEK GOVDE, IKI YON: iki ayri fonksiyon yazmak ayni sorgunun ve ayni
//
//	Scan'in ikinci kopyasini dogururdu.
func (h *Handler) bagListe(w http.ResponseWriter, r *http.Request, benSutun, otekiSutun string) {
	me := auth.UserID(r.Context())
	// ⚠️ Sutun adlari SABIT dizelerden geliyor (kullanici girdisi DEGIL) —
	//    SQL enjeksiyonu yuzeyi YOK.
	rows, err := h.db.Query(r.Context(), `
		SELECT b.id, b.`+otekiSutun+`, COALESCE(u.name,''),
		       COALESCE(u.username,''), u.avatar_media_id, b.durum,
		       b.baslatan_id, b.guncellendi_at
		  FROM diyet_bag b
		  JOIN users u ON u.id = b.`+otekiSutun+`
		 WHERE b.`+benSutun+`=$1
		 ORDER BY CASE b.durum WHEN 'bekliyor' THEN 0 WHEN 'aktif' THEN 1
		                       ELSE 2 END,
		          b.guncellendi_at DESC
		 LIMIT 200`, me)
	if err != nil {
		log.Printf("diyet bag liste: %v", err)
		hata(w, 500, "alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var bid, uid, ad, kadi, durum, baslatan string
		var avatar *string
		var t any
		if rows.Scan(&bid, &uid, &ad, &kadi, &avatar, &durum, &baslatan, &t) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": bid, "user_id": uid, "name": ad, "username": kadi,
			"avatar_media_id": avatar, "durum": durum,
			// ⚠️ Istemci "onayla" dugmesini bununla cizer: `baslatan_id == me`
			//    ise beklenen taraf KARSISIDIR, dugme CIZILMEZ.
			"baslatan_id": baslatan, "guncellendi_at": t,
		})
	}
	yaz(w, 200, map[string]any{"baglar": out})
}

// ═══════════════════════ KAYIT UCLARI ═══════════════════════

type kayitReq struct {
	UserID string          `json:"user_id"`
	Tur    string          `json:"tur"`
	Tarih  string          `json:"tarih"` // YYYY-MM-DD
	Ad     string          `json:"ad"`
	Kalori int             `json:"kalori"`
	Veri   json.RawMessage `json:"veri"`
}

// POST /diyet/kayit
//
// ⚠️⚠️ IKI FARKLI YETKI KURALI:
//
//	· `ogun`/`olcum` -> YALNIZ KENDINE. `user_id` govdede gelse bile YOK
//	  SAYILIR ve `me` yazilir. Aksi halde biri baskasinin gunune 5000 kalori
//	  ekleyebilirdi.
//	· `liste`        -> DIYETISYEN DANISANA yazar; `diyet_bag` AKTIF olmali.
func (h *Handler) KayitEkle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req kayitReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if !diyetTurleri[req.Tur] {
		hata(w, 400, "geçersiz kayıt türü")
		return
	}

	sahip := me
	if req.Tur == "liste" {
		sahip = strings.TrimSpace(req.UserID)
		if !kimlik.Gecerli(sahip) {
			hata(w, 400, "danışan seçilmedi")
			return
		}
		// ⚠️ LISTE YAZMA KAPISI: `diyetErisim` YETMEZ — o kapi CIFT YONLU
		//    (danisan da diyetisyenin verisini "gorebilir" sayilir). Liste
		//    YAZMA yalniz DIYETISYEN yonunde olmali.
		var yetkili bool
		if err := h.db.QueryRow(r.Context(), `
			SELECT EXISTS(SELECT 1 FROM diyet_bag
			               WHERE danisan_id=$1 AND diyetisyen_id=$2
			                 AND durum='aktif')`, sahip, me).Scan(&yetkili); err != nil {
			hata(w, 500, "kaydedilemedi")
			return
		}
		if !yetkili {
			hata(w, 403, "bu kişinin diyetisyeni değilsin")
			return
		}
	}

	// ⚠️ TARIH ISTEMCIDEN: kullanici DUN yedigini BUGUN girebilmeli.
	//    Bos ya da bozuksa BUGUN (sunucu saati) kullanilir.
	tarih := strings.TrimSpace(req.Tarih)
	if _, err := time.Parse("2006-01-02", tarih); err != nil {
		tarih = time.Now().Format("2006-01-02")
	}
	if req.Kalori < 0 {
		req.Kalori = 0
	}
	if req.Kalori > 20000 {
		// ⚠️ Ust tavan: yazim hatasi (or. 25000) gunluk ozeti anlamsiz yapar.
		hata(w, 400, "kalori değeri geçersiz")
		return
	}
	veri := req.Veri
	if len(veri) == 0 {
		veri = json.RawMessage(`{}`)
	}

	var id string
	if err := h.db.QueryRow(r.Context(), `
		INSERT INTO diyet_kayit (user_id, yazan_id, tur, tarih, ad, kalori, veri)
		VALUES ($1,$2,$3,$4::date,$5,$6,$7)
		RETURNING id`, sahip, me, req.Tur, tarih,
		kisalt(strings.TrimSpace(req.Ad), 200), req.Kalori, veri).Scan(&id); err != nil {
		log.Printf("diyet kayit: %v", err)
		hata(w, 500, "kaydedilemedi")
		return
	}

	if h.bs != nil && req.Tur == "liste" {
		h.bs.Bildir(r.Context(), sahip, me, "diyet_liste", "diyet", id)
	}
	yaz(w, 201, map[string]any{"id": id})
}

// GET /diyet/kayitlar?user_id=&tur=&bas=&bit=
func (h *Handler) Kayitlar(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	q := r.URL.Query()
	hedef := strings.TrimSpace(q.Get("user_id"))
	if hedef == "" {
		hedef = me
	}
	if !kimlik.Gecerli(hedef) {
		hata(w, 404, "bulunamadı")
		return
	}
	// ⚠️ RIZA KAPISI — TEK KAYNAK. 404 (403 DEGIL): "bu kisinin diyet kaydi
	//    var" bilgisi de HASSASTIR.
	if !h.diyetErisim(r.Context(), me, hedef) {
		hata(w, 404, "bulunamadı")
		return
	}

	tur := strings.TrimSpace(q.Get("tur"))
	bas, bit := tarihAralik(q.Get("bas"), q.Get("bit"))

	rows, err := h.db.Query(r.Context(), `
		SELECT k.id, k.user_id, k.yazan_id, k.tur, k.tarih, k.ad, k.kalori,
		       k.veri, k.created_at
		  FROM diyet_kayit k
		 WHERE k.user_id=$1
		   AND k.durum='aktif'
		   AND ($2 = '' OR k.tur = $2)
		   AND k.tarih BETWEEN $3::date AND $4::date
		 ORDER BY k.tarih DESC, k.created_at DESC
		 LIMIT 500`, hedef, tur, bas, bit)
	if err != nil {
		log.Printf("diyet kayitlar: %v", err)
		hata(w, 500, "alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, uid, yazan, t, ad string
		var kalori int
		var tarih time.Time
		var veri json.RawMessage
		var olustu any
		if rows.Scan(&id, &uid, &yazan, &t, &tarih, &ad, &kalori, &veri,
			&olustu) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "user_id": uid, "yazan_id": yazan, "tur": t,
			"tarih": tarih.Format("2006-01-02"), "ad": ad, "kalori": kalori,
			"veri": veri, "created_at": olustu,
		})
	}
	yaz(w, 200, map[string]any{"kayitlar": out})
}

// PATCH /diyet/kayit/{id}
//
// ⚠️ SILME UCU YOK (veri politikasi): `durum='kaldirildi'` ile gizlenir.
// ⚠️ Kaydi YAZAN ya da SAHIBI degistirebilir: diyetisyen yazdigi listeyi
//
//	duzeltebilmeli, danisan da kendi gununden yanlis girdigi ogunu
//	cikarabilmeli.
func (h *Handler) KayitGuncelle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Ad     *string          `json:"ad"`
		Kalori *int             `json:"kalori"`
		Veri   *json.RawMessage `json:"veri"`
		Durum  *string          `json:"durum"`
	}
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if req.Durum != nil && *req.Durum != "aktif" && *req.Durum != "kaldirildi" {
		hata(w, 400, "geçersiz durum")
		return
	}
	if req.Ad != nil {
		*req.Ad = kisalt(strings.TrimSpace(*req.Ad), 200)
	}
	// ⚠️⚠️⚠️ TURU 93b — KALORI TAVANI **PATCH'TE DE** UYGULANIR (denetim).
	//
	//	POST'ta tavan vardi (`> 20000 -> 400`), PATCH'te **HIC YOKTU**.
	//	`kalori INTEGER` (int4, tavan 2.147.483.647). Uc kayda 2.000.000.000
	//	yazilirsa `/diyet/ozet` sorgusundaki `SUM(k.kalori)::int` cast'i
	//	**`integer out of range`** verir -> ozet uc KALICI **500** doner ve
	//	danisanin "Diyetim" ozeti ile diyetisyenin danisan detayi BIR DAHA
	//	ACILMAZ. Asimetri (ayni kural bir yolda var, kardes yolda yok) bu
	//	projenin turu 85c/90b'de adi konmus hata sinifi.
	if req.Kalori != nil && (*req.Kalori < 0 || *req.Kalori > 20000) {
		hata(w, 400, "kalori değeri geçersiz")
		return
	}
	var veri any
	if req.Veri != nil {
		veri = []byte(*req.Veri)
	}

	// ⚠️⚠️ TURU 93b — YAZMA KAPISI: `yazan_id` TEK BASINA YETMEZ (denetim).
	//
	//	Eski yuklem `(yazan_id=$2 OR user_id=$2)` idi ve `diyetErisim`
	//	YENIDEN SORULMUYORDU. Danisan bagi `sonlandi` yaptiktan SONRA bile
	//	eski diyetisyen, yazdigi `liste` kayitlarinin ad/kalori/veri
	//	alanlarini degistirmeye DEVAM edebiliyordu — yani RIZA GERI
	//	ALINDIKTAN SONRA danisanin saglik kaydina yazma suruyordu.
	//	Migration 045'in kendi sozu: *"sonlanmis bag OKUMA YETKISI VERMEZ...
	//	gecmis korunur, ERISIM KORUNMAZ"*. Yazma icin bu soz tutulmuyordu.
	// ⚠️ SAHIBI (`user_id=$2`) HER ZAMAN kendi kaydina dokunabilir.
	tag, err := h.db.Exec(r.Context(), `
		UPDATE diyet_kayit SET
		  ad     = COALESCE($3, ad),
		  kalori = COALESCE($4, kalori),
		  veri   = COALESCE($5::jsonb, veri),
		  durum  = COALESCE($6, durum)
		 WHERE id=$1
		   AND (user_id=$2
		     OR (yazan_id=$2 AND EXISTS(
		           SELECT 1 FROM diyet_bag
		            WHERE durum='aktif'
		              AND danisan_id=diyet_kayit.user_id
		              AND diyetisyen_id=$2)))`,
		id, me, req.Ad, req.Kalori, veri, req.Durum)
	if err != nil {
		log.Printf("diyet guncelle: %v", err)
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "kayıt bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /diyet/ozet?user_id=&bas=&bit=
//
// ⚠️ GUNLUK TOPLAM **`tarih` SUTUNUNDAN** gruplanir, `created_at`ten DEGIL:
//
//	gece yarisindan sonra girilen ogun aksi halde BIR ONCEKI gune yazilirdi
//	ve gecmise kayit imkansiz olurdu.
//
// ⚠️ TEK SORGU (N+1 yasak).
func (h *Handler) Ozet(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	q := r.URL.Query()
	hedef := strings.TrimSpace(q.Get("user_id"))
	if hedef == "" {
		hedef = me
	}
	if !kimlik.Gecerli(hedef) || !h.diyetErisim(r.Context(), me, hedef) {
		hata(w, 404, "bulunamadı")
		return
	}
	bas, bit := tarihAralik(q.Get("bas"), q.Get("bit"))

	rows, err := h.db.Query(r.Context(), `
		SELECT k.tarih, SUM(k.kalori)::int
		  FROM diyet_kayit k
		 WHERE k.user_id=$1 AND k.durum='aktif' AND k.tur='ogun'
		   AND k.tarih BETWEEN $2::date AND $3::date
		 GROUP BY k.tarih
		 ORDER BY k.tarih`, hedef, bas, bit)
	if err != nil {
		log.Printf("diyet ozet: %v", err)
		hata(w, 500, "alınamadı")
		return
	}
	defer rows.Close()
	gunler := []map[string]any{}
	for rows.Next() {
		var t time.Time
		var k int
		if rows.Scan(&t, &k) != nil {
			continue
		}
		gunler = append(gunler, map[string]any{
			"tarih": t.Format("2006-01-02"), "kalori": k,
		})
	}

	// Son olcum (ayri, kucuk sorgu — JOIN'lemek gunluk gruplamayi bozardi).
	sonOlcum := map[string]any{}
	var ov json.RawMessage
	var ot time.Time
	if h.db.QueryRow(r.Context(), `
		SELECT k.veri, k.tarih FROM diyet_kayit k
		 WHERE k.user_id=$1 AND k.durum='aktif' AND k.tur='olcum'
		 ORDER BY k.tarih DESC, k.created_at DESC LIMIT 1`,
		hedef).Scan(&ov, &ot) == nil {
		sonOlcum = map[string]any{
			"veri": ov, "tarih": ot.Format("2006-01-02"),
		}
	}
	yaz(w, 200, map[string]any{"gunler": gunler, "son_olcum": sonOlcum})
}

// GET /diyet/besinler?q=
func (h *Handler) Besinler(w http.ResponseWriter, r *http.Request) {
	yaz(w, 200, map[string]any{"besinler": Ara(r.URL.Query().Get("q"))})
}

// tarihAralik — varsayilan SON 30 GUN.
//
// ⚠️ Bozuk tarih 500 DEGIL varsayilana duser: istemci hatasi yuzunden ekran
//
//	bos kalmasin.
func tarihAralik(bas, bit string) (string, string) {
	simdi := time.Now()
	b := simdi.AddDate(0, 0, -30).Format("2006-01-02")
	s := simdi.Format("2006-01-02")
	if _, err := time.Parse("2006-01-02", strings.TrimSpace(bas)); err == nil {
		b = strings.TrimSpace(bas)
	}
	if _, err := time.Parse("2006-01-02", strings.TrimSpace(bit)); err == nil {
		s = strings.TrimSpace(bit)
	}
	return b, s
}
