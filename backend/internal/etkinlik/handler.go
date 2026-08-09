// Package etkinlik — ETKINLIKLER (turu 77).
//
// Kullanici emri: "etkinlikler olacak, bu etkinlik soldaki menuye tikladiginda
// ekranda olacak".
//
// ⚠️ GECMIS ETKINLIK SILINMEZ — "gecmis" bir SORGU SUZGECIDIR (bkz. 029 serhi).
package etkinlik

import (
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
	"github.com/gbz-app/gebzem/backend/internal/engel"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
)

type Handler struct{ db *pgxpool.Pool }

func NewHandler(db *pgxpool.Pool) *Handler { return &Handler{db: db} }

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
	return string(r[:n])
}

// ⚠️ Go ve Dart'ta AYNI liste (mobile/lib/features/etkinlik/etkinlik_servisi.dart).
var Kategoriler = map[string]string{
	"konser":   "Konser",
	"spor":     "Spor",
	"egitim":   "Eğitim & Atölye",
	"yemek":    "Yemek & İçecek",
	"sanat":    "Sanat & Sergi",
	"festival": "Festival",
	"is":       "İş & Networking",
	"topluluk": "Topluluk",
	"cocuk":    "Çocuk & Aile",
	"diger":    "Diğer",
}

// ⚠️⚠️ SUTUN LISTESI TEK KAYNAK — `satirlariOku` ile BIREBIR ayni sirada.
//
//	Bu projede turu 76'da alti sorguya sutun eklenip yedincisi atlanmisti;
//	`rows.Scan` sessizce hata verip HER SATIRI ATLIYORDU ve sayfa BOMBOS
//	donuyordu. Tek stringte tutmak o sinifi yapisal olarak kapatir.
//
// ⚠️ YAPMA: sutunlari sorgulara elle kopyalama.
const sutunlar = `
		e.id, e.olusturan_id, u.name, u.avatar_media_id,
		e.baslik, e.aciklama, e.kategori, e.baslangic, e.bitis,
		e.konum, e.il, e.ilce, e.enlem, e.boylam, e.media_ids,
		e.ucretsiz, e.fiyat_kurus, e.kontenjan, e.durum, e.created_at,
		(SELECT count(*)::int FROM etkinlik_katilim k
		  WHERE k.etkinlik_id=e.id AND k.durum='katiliyor'),
		COALESCE((SELECT k2.durum FROM etkinlik_katilim k2
		  WHERE k2.etkinlik_id=e.id AND k2.user_id=$1),''),
		` + medyaTurleri

// ⚠️⚠️ TURU 78 — MEDYA TURLERI (foto + video karma galeri).
//
//	`media_ids` yalnizca UUID dizisiydi; hangi medyanin FOTO hangisinin VIDEO
//	oldugu istemciye HIC donmuyordu ve istemci bir video id'sini goruntu
//	bilesenine verirse KIRIK GORSEL cizerdi.
//
// ⚠️ `unnest(...) WITH ORDINALITY` + `array_agg(... ORDER BY idx)` SIRA KORUR:
//
//	`media_kinds[i]` <-> `media_ids[i]`. Duz JOIN sira GARANTI ETMEZ.
//
// ⚠️⚠️ Silinmis medya icin 'yok' (NULL DEGIL): `array_agg` NULL uretirse
//
//	`[]string` taramasi PATLAR ve satir SESSIZCE ATLANIR = liste bosalir.
//
// ⚠️ Dis `COALESCE('{}')` ZORUNLU: `media_ids` bossa `array_agg` NULL doner.
const medyaTurleri = `
		COALESCE((SELECT array_agg(COALESCE(ma.kind,'yok') ORDER BY mm.idx)
		            FROM unnest(e.media_ids) WITH ORDINALITY AS mm(mid, idx)
		            LEFT JOIN media_assets ma ON ma.id = mm.mid), '{}')`

// ⚠️ ENGEL YUKLEMI TEK KAYNAK (turu 75b dersi: kopyalanan yuklem DRIFT eder).
//
//	$1 = OKUYAN kullanici; tablo takma adi e.
const engelYok = `
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=e.olusturan_id)
		            OR (b.blocker_id=e.olusturan_id AND b.blocked_id=$1))`

func (h *Handler) satirlariOku(rows pgx.Rows) []map[string]any {
	out := []map[string]any{}
	for rows.Next() {
		var id, olusturan, olusturanAd, baslik, aciklama, kategori string
		var konum, il, ilce, durum, benimDurum string
		var olusturanAvatar *string
		var bitis *time.Time
		var baslangic, olusturma time.Time
		var enlem, boylam float64
		var medya, medyaKind []string
		var ucretsiz bool
		var kontenjan, katilan int
		var fiyatKurus int64
		// ⚠️ SCAN SIRASI `sutunlar` ILE BIREBIR OLMALI. Uyusmazlik derleme
		//    hatasi VERMEZ; satir SESSIZCE atlanir ve liste BOMBOS doner.
		if rows.Scan(&id, &olusturan, &olusturanAd, &olusturanAvatar,
			&baslik, &aciklama, &kategori, &baslangic, &bitis,
			&konum, &il, &ilce, &enlem, &boylam, &medya,
			&ucretsiz, &fiyatKurus, &kontenjan, &durum, &olusturma,
			&katilan, &benimDurum, &medyaKind) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "olusturan_id": olusturan, "olusturan_ad": olusturanAd,
			"olusturan_avatar_media_id": olusturanAvatar,
			"baslik":                    baslik, "aciklama": aciklama,
			"kategori": kategori, "kategori_ad": Kategoriler[kategori],
			"baslangic": baslangic, "bitis": bitis,
			"konum": konum, "il": il, "ilce": ilce,
			"enlem": enlem, "boylam": boylam, "media_ids": medya,
			// media_kinds[i] <-> media_ids[i] SIRA GARANTILI (bkz. medyaTurleri).
			"media_kinds": medyaKind,
			"ucretsiz":    ucretsiz, "fiyat_kurus": fiyatKurus, "kontenjan": kontenjan,
			"durum": durum, "created_at": olusturma,
			"katilan_sayisi": katilan, "benim_durumum": benimDurum,
		})
	}
	return out
}

type etkinlikReq struct {
	Baslik     string   `json:"baslik"`
	Aciklama   string   `json:"aciklama"`
	Kategori   string   `json:"kategori"`
	Baslangic  string   `json:"baslangic"` // RFC3339
	Bitis      string   `json:"bitis"`
	Konum      string   `json:"konum"`
	Il         string   `json:"il"`
	Ilce       string   `json:"ilce"`
	Enlem      float64  `json:"enlem"`
	Boylam     float64  `json:"boylam"`
	MediaIDs   []string `json:"media_ids"`
	Ucretsiz   bool     `json:"ucretsiz"`
	FiyatKurus int64    `json:"fiyat_kurus"`
	Kontenjan  int      `json:"kontenjan"`
}

// POST /etkinlikler — etkinlik olustur.
func (h *Handler) Olustur(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req etkinlikReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	req.Baslik = kisalt(strings.TrimSpace(req.Baslik), 140)
	if req.Baslik == "" {
		hata(w, 400, "başlık boş olamaz")
		return
	}
	req.Aciklama = kisalt(strings.TrimSpace(req.Aciklama), 4000)
	if _, ok := Kategoriler[req.Kategori]; !ok {
		req.Kategori = "diger"
	}
	bas, err := time.Parse(time.RFC3339, req.Baslangic)
	if err != nil {
		hata(w, 400, "geçersiz tarih")
		return
	}
	var bitis *time.Time
	if req.Bitis != "" {
		if b, err := time.Parse(time.RFC3339, req.Bitis); err == nil {
			// ⚠️ Bitis baslangictan ONCE olamaz — arayuzde sure "-2 saat" gorunurdu.
			if b.After(bas) {
				bitis = &b
			}
		}
	}
	if req.FiyatKurus < 0 {
		req.FiyatKurus = 0
	}
	if req.Ucretsiz {
		req.FiyatKurus = 0
	}
	// ⚠️ UST SINIR DA ZORUNLU (turu 77b): sutun `INTEGER`; Go tarafi 64 bit
	//    oldugu icin `3000000000` gonderilirse INSERT patlar ve kullanici
	//    sebepsiz "etkinlik oluşturulamadı" gorur.
	if req.Kontenjan < 0 || req.Kontenjan > 1000000 {
		req.Kontenjan = 0
	}
	// ⚠️⚠️ ENLEM/BOYLAM KIRPMASI — AYNI KURAL `isletme.Kaydet`te VARDI, BURADA
	//    DUSMUSTU (turu 77b denetim bulgusu; CLAUDE.md turu 75b/2 "ayni kuralin
	//    iki kopyasi drift eder" dersinin tekrari). `{"enlem":1e308}` gecerli
	//    JSON + gecerli float64'tur; DB'ye yazilir, `sutunlar` uzerinden
	//    istemciye doner ve harita cizimini bozar.
	//    ⚠️ `x != x` NaN kapisidir (NaN hicbir seye, kendisine bile esit degildir).
	if req.Enlem < -90 || req.Enlem > 90 || req.Enlem != req.Enlem {
		req.Enlem = 0
	}
	if req.Boylam < -180 || req.Boylam > 180 || req.Boylam != req.Boylam {
		req.Boylam = 0
	}
	// ⚠️⚠️ nil DEGIL BOS DILIM: pgx nil dilimi SQL NULL gonderir ve
	//    `media_ids` NOT NULL -> HER medyasiz etkinlik 500 donerdi
	//    (turu 75b'de yazi gonderilerinde tam bu yasandi).
	if req.MediaIDs == nil {
		req.MediaIDs = []string{}
	}
	if len(req.MediaIDs) > 10 {
		req.MediaIDs = req.MediaIDs[:10]
	}
	// ⚠️ MEDYA SAHIPLIGI DOGRULANIR (gonderi/hikaye ile AYNI kural).
	if len(req.MediaIDs) > 0 {
		tag, err := h.db.Exec(r.Context(), `
			SELECT 1 FROM media_assets
			 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
			req.MediaIDs, me)
		if err != nil || int(tag.RowsAffected()) != len(req.MediaIDs) {
			hata(w, 403, "geçersiz medya")
			return
		}
	}

	var id string
	if h.db.QueryRow(r.Context(), `
		INSERT INTO etkinlikler
		  (olusturan_id, baslik, aciklama, kategori, baslangic, bitis,
		   konum, il, ilce, enlem, boylam, media_ids, ucretsiz, fiyat_kurus, kontenjan)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
		RETURNING id`,
		me, req.Baslik, req.Aciklama, req.Kategori, bas, bitis,
		kisalt(req.Konum, 300), kisalt(req.Il, 60), kisalt(req.Ilce, 60),
		req.Enlem, req.Boylam, req.MediaIDs, req.Ucretsiz, req.FiyatKurus,
		req.Kontenjan).Scan(&id) != nil {
		hata(w, 500, "etkinlik oluşturulamadı")
		return
	}
	if len(req.MediaIDs) > 0 {
		h.db.Exec(r.Context(),
			`UPDATE media_assets SET status='bagli' WHERE id = ANY($1)`, req.MediaIDs)
	}
	// ⚠️ OLUSTURAN OTOMATIK KATILIR: kendi etkinligine "katiliyorum" demek
	//    zorunda kalmak sacma olurdu ve katilimci listesi duzenleyensiz gorunur.
	h.db.Exec(r.Context(), `
		INSERT INTO etkinlik_katilim (etkinlik_id, user_id, durum)
		VALUES ($1,$2,'katiliyor') ON CONFLICT DO NOTHING`, id, me)

	yaz(w, 201, map[string]any{"id": id})
}

// GET /etkinlikler?kategori=&gecmis=1&q=&il= — LISTE.
//
// ⚠️ VARSAYILAN: YAKLASAN etkinlikler (`baslangic >= now()`), en yakin once.
//
//	`gecmis=1` ile GECMIS etkinlikler (en yeni once). Gecmis SILINMIS DEGIL —
//	yalnizca suzgecin diger tarafi (bkz. 029 serhi).
func (h *Handler) Liste(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	kategori := strings.TrimSpace(r.URL.Query().Get("kategori"))
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	il := strings.TrimSpace(r.URL.Query().Get("il"))
	gecmis := r.URL.Query().Get("gecmis") == "1"
	// Yalniz BENIM etkinliklerim (olusturdugum + katildigim).
	benim := r.URL.Query().Get("benim") == "1"

	zamanKosulu := "e.baslangic >= now()"
	siralama := "e.baslangic ASC"
	if gecmis {
		zamanKosulu = "e.baslangic < now()"
		siralama = "e.baslangic DESC"
	}
	benimKosulu := ""
	if benim {
		benimKosulu = ` AND (e.olusturan_id = $1 OR EXISTS(
			SELECT 1 FROM etkinlik_katilim k3
			 WHERE k3.etkinlik_id=e.id AND k3.user_id=$1 AND k3.durum<>'vazgecti'))`
	}

	// ⚠️⚠️ TURU 78 — TARIH ARALIGI SUZGECI. "Bu hafta sonu" / "Bugün" gibi
	//    HIZLI KARTLARIN ON KOSULU: bu iki parametre olmadan o kartlar OLU
	//    DOGARDI (istemci tarafinda suzmek yanlis olurdu — sunucu 60 satir
	//    dondurup istemci 3'e dusurseydi liste eksik gorunurdu).
	// ⚠️ Bos dize = suzgec YOK. `NULL` yerine bos dize kullanildi cunku sorgu
	//    zaten bu kalibi kullaniyor ($2/$3/$4) ve tutarlilik onemli.
	basMin := strings.TrimSpace(r.URL.Query().Get("bas_min"))
	basMaks := strings.TrimSpace(r.URL.Query().Get("bas_maks"))

	rows, err := h.db.Query(r.Context(), `
		SELECT `+sutunlar+`
		  FROM etkinlikler e JOIN users u ON u.id = e.olusturan_id
		 WHERE e.durum='yayinda' AND `+zamanKosulu+`
		   AND ($2 = '' OR e.kategori = $2)
		   AND ($3 = '' OR e.il ILIKE $3)
		   AND ($4 = '' OR e.baslik ILIKE '%'||$4||'%'
		        OR e.aciklama ILIKE '%'||$4||'%')
		   -- ⚠️ Bicimsiz tarih gonderilirse ::timestamptz cast'i PATLAR ve uc
		   --    500 doner; bu yuzden istemci RFC3339 gondermek ZORUNDA.
		   --    Bos dize dali cast'i HIC calistirmaz (kisa devre).
		   AND ($5 = '' OR e.baslangic >= $5::timestamptz)
		   AND ($6 = '' OR e.baslangic <= $6::timestamptz)
		`+benimKosulu+engelYok+`
		 ORDER BY `+siralama+` LIMIT 60`, me, kategori, il, q, basMin, basMaks)
	if err != nil {
		log.Printf("etkinlik liste: %v", err)
		hata(w, 500, "etkinlikler alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"etkinlikler": h.satirlariOku(rows)})
}

// GET /etkinlikler/{id} — detay.
func (h *Handler) Detay(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT `+sutunlar+`
		  FROM etkinlikler e JOIN users u ON u.id = e.olusturan_id
		 WHERE e.id=$2 AND e.durum<>'silindi'`+engelYok, me, id)
	if err != nil {
		hata(w, 500, "etkinlik alınamadı")
		return
	}
	defer rows.Close()
	l := h.satirlariOku(rows)
	if len(l) == 0 {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	yaz(w, 200, l[0])
}

// POST /etkinlikler/{id}/katil  {durum: katiliyor|ilgileniyor|vazgecti}
//
// ⚠️ TEK UC ile hem katilma hem vazgecme: iki ayri uc olsaydi istemcide
//
//	"hangi durumda hangisini cagiracagim" mantigi iki yerde yasardi.
//
// ⚠️ KONTENJAN kontrolu SUNUCUDA ve AYNI ISLEMDE yapilir — istemci kapisi
//
//	yaris durumunu engellemez (iki kisi ayni anda son yeri alabilir).
func (h *Handler) Katil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Durum string `json:"durum"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	switch req.Durum {
	case "katiliyor", "ilgileniyor", "vazgecti":
	default:
		req.Durum = "katiliyor"
	}

	var olusturan string
	var kontenjan int
	var baslangic time.Time
	if h.db.QueryRow(r.Context(), `
		SELECT olusturan_id, kontenjan, baslangic FROM etkinlikler
		 WHERE id=$1 AND durum='yayinda'`, id).
		Scan(&olusturan, &kontenjan, &baslangic) != nil {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	if engel.Var(r.Context(), h.db, me, olusturan) {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	// ⚠️ OLUSTURAN kendi etkinliginden VAZGECEMEZ: katilimci listesinde
	//    duzenleyen olmayan bir etkinlik tuhaf gorunur.
	if olusturan == me && req.Durum == "vazgecti" {
		hata(w, 400, "kendi etkinliğinden ayrılamazsın")
		return
	}
	// ⚠️⚠️ KONTENJAN KONTROLU **TEK DEYIMDE** — check-then-act DEGIL
	//    (turu 77b denetim bulgusu).
	//
	//    Onceki surumde ayri bir `SELECT count(*)` ve ardindan ayri bir `INSERT`
	//    vardi; ustundeki yorum "AYNI ISLEMDE yapilir" DIYORDU ama ortada ne
	//    transaction ne kilit vardi. Son kontenjana ayni anda basan iki kisi
	//    IKISI DE gecerdi; 100 kisilik bir konserde escamanli 50 istek
	//    kontenjani asabilirdi.
	//    📌 CLAUDE.md turu 74 dersinin tekrari: **bir yorumun anlattigi
	//       kontrolun GOVDEDE gercekten olup olmadigini dogrula.**
	//
	//    `INSERT ... SELECT ... WHERE (SELECT count(*)) < kontenjan` Postgres
	//    seviyesinde TEK deyimdir; ayri transaction yonetimi gerekmez.
	//    ⚠️ `kontenjan = 0` SINIRSIZ demek -> `$4 <= 0` dali kosulu atlar.
	//    ⚠️ YAPMA: ikiye bolup geri donme.
	etiket, err := h.db.Exec(r.Context(), `
		INSERT INTO etkinlik_katilim (etkinlik_id, user_id, durum)
		SELECT $1,$2,$3
		 WHERE $4 <= 0 OR $3 <> 'katiliyor'
		    OR (SELECT count(*) FROM etkinlik_katilim
		         WHERE etkinlik_id=$1 AND durum='katiliyor' AND user_id<>$2) < $4
		ON CONFLICT (etkinlik_id, user_id) DO UPDATE SET durum=EXCLUDED.durum`,
		id, me, req.Durum, kontenjan)
	if err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	if etiket.RowsAffected() == 0 {
		hata(w, 409, "kontenjan doldu")
		return
	}
	yaz(w, 200, map[string]string{"durum": req.Durum})
}

// GET /etkinlikler/{id}/katilimcilar
func (h *Handler) Katilimcilar(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_media_id, k.durum
		  FROM etkinlik_katilim k JOIN users u ON u.id = k.user_id
		 WHERE k.etkinlik_id=$2 AND k.durum<>'vazgecti'`+
		engel.Yuklem("$1", "u.id")+`
		 ORDER BY k.created_at ASC LIMIT 300`, me, id)
	if err != nil {
		hata(w, 500, "liste alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var uid, ad, kullanici, durum string
		var avatar *string
		if rows.Scan(&uid, &ad, &kullanici, &avatar, &durum) == nil {
			out = append(out, map[string]any{
				"id": uid, "name": ad, "username": kullanici,
				"avatar_media_id": avatar, "durum": durum,
			})
		}
	}
	yaz(w, 200, out)
}

// DELETE /etkinlikler/{id} — kendi etkinligini KALDIR.
//
// ⚠️ SATIR SILINMEZ (veri politikasi): `durum='silindi'`. Katilim kayitlari
//
//	DOKUNULMADAN kalir.
func (h *Handler) Sil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		// ⚠️ Bicimsiz id sorguya girerse Postgres cast hatasi -> 500. Dogrusu 404.
		hata(w, 404, "bulunamadı")
		return
	}
	tag, err := h.db.Exec(r.Context(),
		`UPDATE etkinlikler SET durum='silindi', updated_at=now()
		  WHERE id=$1 AND olusturan_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /etkinlik-kategorileri
func (h *Handler) KategoriListesi(w http.ResponseWriter, r *http.Request) {
	out := make([]map[string]string, 0, len(Kategoriler))
	for k, ad := range Kategoriler {
		out = append(out, map[string]string{"anahtar": k, "ad": ad})
	}
	yaz(w, 200, out)
}

// Kullanilmayan importu onlemek icin (strconv ileride sayfalama icin).
var _ = strconv.Itoa

// PATCH /etkinlikler/{id} — etkinlik DUZENLE.
//
// ⚠️⚠️ TURU 78 — BU UC HIC YOKTU. Kullanici emri: "etkinlik olusturma
// DUZENLEME". Yalnizca Olustur/Liste/Detay/Katil/Katilimcilar/Sil vardi; yani
// bir yazim hatasini duzeltmenin TEK yolu etkinligi silip yeniden acmakti ve o
// zaman TUM KATILIMCILAR kayboluyordu.
//
// ⚠️ `tur` benzeri bir alan YOK ama KATEGORI degistirilebilir (semayi
//
//	etkilemiyor, yalniz suzgec).
//
// ⚠️⚠️ `durum` PATCH YUZEYINDE **YOK** (bilincli): `Liste` sorgusu
//
//	`durum='yayinda'` suzuyor ve `benim=1` dali da bununla AND'li. Kullanici
//	etkinligi 'iptal' yapsaydi KENDI LISTESINDEN DE kaybolurdu ve geri donus
//	yolu KALMAZDI. Iptal ozelligi ayri bir is (listeye 'iptal' dali gerekir).
//	⚠️ YAPMA: buraya `durum` alani ekleme.
func (h *Handler) Guncelle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	var req struct {
		Baslik     *string   `json:"baslik"`
		Aciklama   *string   `json:"aciklama"`
		Kategori   *string   `json:"kategori"`
		Baslangic  *string   `json:"baslangic"`
		Bitis      *string   `json:"bitis"`
		Konum      *string   `json:"konum"`
		Il         *string   `json:"il"`
		Ilce       *string   `json:"ilce"`
		MediaIDs   *[]string `json:"media_ids"`
		Ucretsiz   *bool     `json:"ucretsiz"`
		FiyatKurus *int64    `json:"fiyat_kurus"`
		Kontenjan  *int      `json:"kontenjan"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}

	// ⚠️⚠️ `Olustur`DAKI DOGRULAMALARIN AYNISI. Bu projede PATCH yolunun
	//    POST'un kurallarini kaybetmesi turu 77b'de yasandi (bos baslik +
	//    negatif fiyat ilanlarda gecmisti). Ayni hataya dusmemek icin her
	//    kural burada TEKRAR uygulaniyor.
	if req.Baslik != nil {
		*req.Baslik = kisalt(strings.TrimSpace(*req.Baslik), 140)
		if *req.Baslik == "" {
			hata(w, 400, "başlık boş olamaz")
			return
		}
	}
	if req.Aciklama != nil {
		*req.Aciklama = kisalt(strings.TrimSpace(*req.Aciklama), 4000)
	}
	if req.Kategori != nil {
		if _, ok := Kategoriler[*req.Kategori]; !ok {
			*req.Kategori = "diger"
		}
	}
	if req.Konum != nil {
		*req.Konum = kisalt(strings.TrimSpace(*req.Konum), 300)
	}
	if req.Il != nil {
		*req.Il = kisalt(strings.TrimSpace(*req.Il), 60)
	}
	if req.Ilce != nil {
		*req.Ilce = kisalt(strings.TrimSpace(*req.Ilce), 60)
	}
	if req.FiyatKurus != nil && *req.FiyatKurus < 0 {
		*req.FiyatKurus = 0
	}
	if req.Ucretsiz != nil && *req.Ucretsiz {
		sifir := int64(0)
		req.FiyatKurus = &sifir
	}
	if req.Kontenjan != nil && (*req.Kontenjan < 0 || *req.Kontenjan > 1000000) {
		*req.Kontenjan = 0
	}

	var bas, bitis *time.Time
	if req.Baslangic != nil {
		b, err := time.Parse(time.RFC3339, *req.Baslangic)
		if err != nil {
			hata(w, 400, "geçersiz tarih")
			return
		}
		bas = &b
	}
	if req.Bitis != nil {
		if *req.Bitis == "" {
			// ⚠️ Bos dize = BITISI KALDIR (nobetci). `nil` "degistirme"
			//    demek oldugu icin ayri bir isarete ihtiyac var — ayni
			//    tuzak kapak gorselinde de vardi (turu 78 FAZ A).
			bitis = nil
		} else if b, err := time.Parse(time.RFC3339, *req.Bitis); err == nil {
			bitis = &b
		}
	}

	if req.MediaIDs != nil {
		if *req.MediaIDs == nil {
			// ⚠️ nil dilim pgx'te SQL NULL gonderir; `media_ids` NOT NULL -> 500.
			*req.MediaIDs = []string{}
		}
		if len(*req.MediaIDs) > 10 {
			*req.MediaIDs = (*req.MediaIDs)[:10]
		}
		// ⚠️⚠️ MEDYA SAHIPLIGI PATCH'TE DE DOGRULANIR: bu kapi olmasaydi
		//    baskasinin medya id'sini kendi etkinligine baglayarak
		//    `erisebilir()` (f) dalini somurmek mumkun olurdu.
		if len(*req.MediaIDs) > 0 {
			tag, err := h.db.Exec(r.Context(), `
				SELECT 1 FROM media_assets
				 WHERE id = ANY($1) AND owner_id=$2 AND status IN ('aktif','bagli')`,
				*req.MediaIDs, me)
			if err != nil || int(tag.RowsAffected()) != len(*req.MediaIDs) {
				hata(w, 403, "geçersiz medya")
				return
			}
		}
	}

	tag, err := h.db.Exec(r.Context(), `
		UPDATE etkinlikler SET
		  baslik      = COALESCE($3, baslik),
		  aciklama    = COALESCE($4, aciklama),
		  kategori    = COALESCE($5, kategori),
		  baslangic   = COALESCE($6, baslangic),
		  bitis       = CASE WHEN $7::text IS NULL THEN bitis ELSE $8 END,
		  konum       = COALESCE($9, konum),
		  il          = COALESCE($10, il),
		  ilce        = COALESCE($11, ilce),
		  media_ids   = COALESCE($12, media_ids),
		  ucretsiz    = COALESCE($13, ucretsiz),
		  fiyat_kurus = COALESCE($14, fiyat_kurus),
		  kontenjan   = COALESCE($15, kontenjan),
		  updated_at  = now()
		 WHERE id=$1 AND olusturan_id=$2 AND durum<>'silindi'`,
		id, me, req.Baslik, req.Aciklama, req.Kategori, bas,
		req.Bitis, bitis, req.Konum, req.Il, req.Ilce, req.MediaIDs,
		req.Ucretsiz, req.FiyatKurus, req.Kontenjan)
	if err != nil {
		log.Printf("etkinlik guncelle: %v", err)
		hata(w, 500, "güncellenemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, 404, "etkinlik bulunamadı")
		return
	}
	// ⚠️ Yeni medyalar 'bagli' yapilir (`Olustur` ile AYNI kural) — yoksa medya
	//    supurgesi 'aktif' kaydi atilabilir sanip islem yapar ve gorsel KAYBOLUR.
	// ⚠️ Cikarilan medya SILINMEZ (veri politikasi).
	if req.MediaIDs != nil && len(*req.MediaIDs) > 0 {
		h.db.Exec(r.Context(),
			`UPDATE media_assets SET status='bagli' WHERE id = ANY($1)`, *req.MediaIDs)
	}
	yaz(w, 200, map[string]bool{"ok": true})
}
