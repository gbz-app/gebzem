// Package vitrin — KATEGORI INIS SAYFASININ UST SLIDER'I.
//
// Kullanici emri: "kategori sayfasinin ustunde slider reklam alani olacak".
//
// ═══════════════ ⚠️⚠️⚠️ NEDEN `reklamlar` TABLOSU YOK ═══════════════
//
// Bir reklam tablosu acmak ILK BAKISTA dogru gorunur ama bu projede BUGUN
// ICERIGINI GIRECEK KIMSE YOK ve sonuc "olu tablo" olurdu:
//
//	· ODEME SISTEMI YOK (bedava jeton) — reklam SATILAMAZ.
//	· `hesap_turu='isletme'` hesap sayisi SIFIR — reklam VEREN de yok.
//	· ⚠️⚠️ EN KRITIGI: admin panelinden GORSEL YUKLENEMEZ. Admin uclari
//	  `?key=` ile JWT grubunun **DISINDA** (`main.go` acik grup), medya
//	  presign/commit ise JWT grubunun **ICINDE**. Yani admin bir banner
//	  yukleyemez; onay kuyrugu yalnizca bir UUID LISTESI olurdu = KOR ONAY.
//
// Bu yuzden slider ORGANIK VITRINDEN beslenir: dogrulanmis isletmeler ve
// yaklasan etkinlikler. Odeme geldiginde `reklamlar` tablosu BU UCUN ARKASINA
// eklenir ve **istemci sozlesmesi DEGISMEZ**.
// ⚠️ YAPMA: icerigini girecek yol olmadan `reklamlar` tablosu acma.
//
// ⚠️⚠️ YENI MEDYA KAPISI GEREKMIYOR — bu KASITLI bir kisit:
//
//	slaytlar YALNIZ `users.avatar_media_id` (erisebilir dali (b)) ve
//	`etkinlikler.media_ids` (dal (f)) kullanir. Ikisi de ZATEN herkese acik.
//	Yeni bir medya alani `erisebilir()` icine dal yazmayi gerektirirdi ve o
//	dal unutuldugunda gorsel YUKLEYENDEN BASKA HERKESE 403 donerdi — bu sinif
//	hata turu 75b'de ve turu 77'de SAHAYA CIKTI.
//
// ⚠️ GOSTERIM/TIKLAMA SAYACI YAZILMIYOR: uc 6 slayt donuyor ve cogu
//
//	GORULMEYECEK. CLAUDE.md'nin "akista 20 kart tek istekte gelir ama cogu hic
//	gorulmez, orada saymak sayiyi YALAN yapar" karariyla ayni gerekce.
package vitrin

import (
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	// ⚠️ TURU 85b — dikeyler `isletme.Kategoriler`den TURETILIYOR (drift yok).
	//    Dongu riski YOK: `isletme` paketi `vitrin`i IMPORT ETMIYOR.
	"github.com/gbz-app/gebzem/backend/internal/isletme"
)

type Handler struct{ db *pgxpool.Pool }

func NewHandler(db *pgxpool.Pool) *Handler { return &Handler{db: db} }

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

// ⚠️⚠️⚠️ TURU 85b — DIKEYLER ARTIK **TEK KAYNAKTAN TURETILIYOR**.
//
// Onceden burada ELLE yazilmis bir kopya vardi ve turu 85'te `eczane` ile
// `otel` eklenince **BU KOPYA GUNCELLENMEDI**: `/vitrin?dikey=eczane`
// `isletmeDikeyleri[dikey]` kapisindan GECEMIYOR ve sessizce "yaklasan
// etkinlikler" daline dusuyordu — yani yeni kategorilerin inis sayfasinda
// UST SLIDER HIC CIZILMEZDI.
//
// Bu, CLAUDE.md'de ALTI kez yazili **"ayni kuralin iki kopyasi DRIFT EDER"**
// sinifinin UCUNCU kopyayla yasanan halidir (Go `Kategoriler` · Dart
// `isletmeKategorileri` · buradaki liste).
//
// ⚠️ Artik `isletme.Kategoriler` haritasindan uretiliyor: yeni bir kategori
//
//	eklendiginde burasi OTOMATIK ogrenir, drift YAPISAL OLARAK imkansiz.
//
// ⚠️ `"isletme"` bir KATEGORI DEGIL, "tum isletmeler" dikeyidir — bu yuzden
//
//	ayrica ekleniyor.
//
// ⚠️ YAPMA: buraya tekrar elle liste yazma.
var isletmeDikeyleri = func() map[string]bool {
	m := map[string]bool{"isletme": true}
	for k := range isletme.Kategoriler {
		m[k] = true
	}
	return m
}()

// GET /vitrin?dikey=yemek — kategori inis sayfasinin ust slider'i.
//
// ⚠️ BOS DIZI DONMESI NORMALDIR (yeni kurulumda hicbir sey yok). Istemci o
//
//	durumda slider'i HIC CIZMEZ — bos gri kutu gostermek kotu olurdu.
func (h *Handler) Liste(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	dikey := r.URL.Query().Get("dikey")

	if isletmeDikeyleri[dikey] {
		h.isletmeler(w, r, me, dikey)
		return
	}
	// ilan / hizmet / etkinlik / bilinmeyen -> YAKLASAN ETKINLIKLER.
	// ⚠️ Ilan icin "one cikan ilan" secmek ADIL DEGIL (hangi ilan? en yeni mi,
	//    en pahali mi?) ve odeme olmadan bir siralamayi mesrulastiramayiz.
	//    Yaklasan etkinlikler ise HERKES icin ayni ve zamana bagli — durust.
	h.etkinlikler(w, r, me)
}

func (h *Handler) isletmeler(w http.ResponseWriter, r *http.Request, me, dikey string) {
	// ⚠️ `dikey='isletme'` = TUM kategoriler (hamburger menudeki "İşletmeler").
	kategori := dikey
	if dikey == "isletme" {
		kategori = ""
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(i.ilce,''), u.avatar_media_id
		  FROM isletmeler i
		  JOIN users u ON u.id = i.user_id
		 WHERE u.hesap_turu='isletme'
		   AND ($2 = '' OR i.kategori = $2)
		   -- ⚠️ Slider VITRINDIR: gorseli olmayan isletme bos kutu cizerdi.
		   AND u.avatar_media_id IS NOT NULL
		   -- ⚠️ ENGEL KAPISI: engellenen taraf vitrinde de gorunmemeli.
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		            OR (b.blocker_id=u.id AND b.blocked_id=$1))
		 -- ⚠️ ONAYLI hesaplar once (tek gercek kaynak: users.onayli).
		 ORDER BY u.onayli DESC, u.name ASC
		 LIMIT 6`, me, kategori)
	if err != nil {
		yaz(w, 200, map[string]any{"slaytlar": []any{}})
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, ilce string
		var medya *string
		if rows.Scan(&id, &ad, &ilce, &medya) != nil {
			continue
		}
		out = append(out, map[string]any{
			"tur": "isletme", "baslik": ad, "alt_baslik": ilce,
			"media_id": medya, "hedef_tur": "isletme", "hedef_id": id,
		})
	}
	yaz(w, 200, map[string]any{"slaytlar": out})
}

func (h *Handler) etkinlikler(w http.ResponseWriter, r *http.Request, me string) {
	// ⚠️⚠️ TURU 78b — ILK **FOTOGRAF** SECILIR, ilk MEDYA DEGIL (denetim bulgusu).
	//    Eskiden `e.media_ids[1]` aliniyordu; o medya VIDEO ise istemci onu
	//    `MedyaGorsel`e verir ve slider'da **KIRIK GORSEL** cizilirdi (video
	//    yuklemesinde kucuk resim gonderilmedigi icin `thumb_url` de bos).
	//    Alt sorgu `media_assets.kind='image'` suzgeciyle SIRA KORUYARAK ilk
	//    fotografi bulur; hic fotograf yoksa NULL doner ve WHERE kapisi o
	//    etkinligi vitrinden ELER (bos kutu cizmektense HIC gostermemek dogru).
	rows, err := h.db.Query(r.Context(), `
		SELECT e.id, e.baslik, COALESCE(e.konum,''),
		       (SELECT mm.mid FROM unnest(e.media_ids) WITH ORDINALITY AS mm(mid, idx)
		          JOIN media_assets ma ON ma.id = mm.mid AND ma.kind='image'
		         ORDER BY mm.idx LIMIT 1) AS kapak
		  FROM etkinlikler e
		 WHERE e.durum='yayinda'
		   AND e.baslangic > now()
		   -- ⚠️ FOTOGRAFI OLMAYAN etkinlik vitrine GIRMEZ.
		   AND EXISTS(SELECT 1 FROM unnest(e.media_ids) AS m(mid)
		                JOIN media_assets ma2 ON ma2.id = m.mid AND ma2.kind='image')
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=e.olusturan_id)
		            OR (b.blocker_id=e.olusturan_id AND b.blocked_id=$1))
		 ORDER BY e.baslangic ASC
		 LIMIT 6`, me)
	if err != nil {
		yaz(w, 200, map[string]any{"slaytlar": []any{}})
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, baslik, konum string
		var medya *string
		if rows.Scan(&id, &baslik, &konum, &medya) != nil {
			continue
		}
		out = append(out, map[string]any{
			"tur": "etkinlik", "baslik": baslik, "alt_baslik": konum,
			"media_id": medya, "hedef_tur": "etkinlik", "hedef_id": id,
		})
	}
	yaz(w, 200, map[string]any{"slaytlar": out})
}
