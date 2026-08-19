package social

import (
	"log"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 114 — "MAHALLE" AKISI (kullanici emri).
//
// Kullanici akistaki bolme secicisini geri istedi ve UCUNCU bolmenin adini
// **"Mahalle"** koydu (*"anasayfada ustte Arkadas Keşfet Mahalle kaldirmissin
// dikkat et"*). Onceki halde ucuncu oge "Canli Yayin" idi ve bir AKIS BOLMESI
// DEGIL, alt menudeki Canli sekmesine giden bir KISAYOLDU.
//
// ═══════════ YENI TABLO/MIGRATION **ACILMADI** ═══════════
//
// `posts.konum_ad/enlem/boylam` **migration 044'ten beri VAR** ve gonderi
// sorgularinin ORTAK sutun sabitinde (`medyaTurleri`) zaten donuyor; eksik olan
// tek sey KONUMA GORE SUZEN bir sorguydu. Yasak testi ("ayni kavram + ayni
// gorunurluk + ayni aktorler") burada tutuyor: Mahalle, `/feed` ile AYNI
// gonderileri AYNI gorunurluk kurallariyla dondurur, yalnizca ek bir mekansal
// yuklem uygular.
//
// ═══════════ NEDEN `/feed`E PARAMETRE OLARAK EKLENMEDI ═══════════
//
// `/feed` donus sozlesmesinde `kesfet` bayragi var ve o bayrak "takip
// etmiyorsun, sana kesfet gosteriyorum" ANLAMINA gelir. Mahalle'de o anlam
// YOKTUR (takip iliskisi hic sorulmaz); ayni ucta iki anlam birbirine karisirdi.
// Bu, `Kesfet` ucunun kendi serhinde yazili olan gerekcenin AYNISI.
// ⚠️ YAPMA: bunu `/feed`e bayrak olarak baglama.
//
// ═══════════ MEKANSAL SUZGEC — `isletme/yakinimda.go` ILE AYNI DESEN ═══════════
//
// Once KABA KUTU (bounding box), sonra Haversine. PostGIS EKLENMEDI (yeni
// uzanti + migration + imaj bagimliligi; bu olcekte kazanci yok).
//
// ⚠️⚠️ BOYLAM BOLENI `111 * cos(enlem)` OLMAK ZORUNDA. Duz `111.0` yazmak
//
//	kutuyu Gebze enleminde (~40.8°) **%24 DAR** yapar ve yaricap ICINDEKI
//	gonderiler kaba kutuda SESSIZCE elenir. Bu hata turu 85b'de isletme
//	tarafinda SAHAYA CIKTI; ayni tuzagi burada tekrarlamamak icin bolen
//	birebir oradan alindi.
//	⚠️ `greatest(cos(...), 0.01)` ZORUNLU: kutuplarda `cos` sifira gider ve
//	   bolme PATLAR.
// ⚠️ `least(1.0, ...)` ZORUNLU: kayan nokta yuvarlamasi cok yakin iki nokta
//
//	icin `acos` argumanini 1'in USTUNE cikarabilir ve Postgres
//	"input is out of range" ile PATLAR (klasik Haversine tuzagi).
const (
	mahalleVarsayilanKm = 15.0
	mahalleEnFazlaKm    = 100.0
)

// GET /mahalle?lat=..&lng=..&km=..&limit=..&before=..
//
// ⚠️ Donus sozlesmesi `/feed` ve `/kesfet` ile BIREBIR ayni (`{"posts":[...]}`)
//
//	ki istemci ayni `Gonderi.fromJson` ve ayni sayfalama kodunu kullansin.
//	Ek olarak `km` doner: istemci "15 km icindeki gonderiler" diye yazabilsin.
func (h *Handler) Mahalle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())

	lat, err1 := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lng, err2 := strconv.ParseFloat(r.URL.Query().Get("lng"), 64)
	if err1 != nil || err2 != nil || (lat == 0 && lng == 0) {
		hata(w, 400, "konum gerekli")
		return
	}
	// ⚠️⚠️ `NaN`/`Inf` AYRICA ELENIR: `strconv.ParseFloat("NaN", 64)` **HATA
	//    DONDURMEZ** ve NaN her karsilastirmadan `false` ile gecer, yani
	//    asagidaki aralik kontrolu onu YAKALAYAMAZ. Sorguya girerse her kutu
	//    karsilastirmasi false uretir ve istemci 400 yerine **SESSIZ BOS LISTE**
	//    gorur — hatayi "mahallemde gonderi yok" sanardi (turu 85b dersi).
	if math.IsNaN(lat) || math.IsNaN(lng) || math.IsInf(lat, 0) || math.IsInf(lng, 0) ||
		lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		hata(w, 400, "konum geçersiz")
		return
	}

	km := mahalleVarsayilanKm
	if v, err := strconv.ParseFloat(r.URL.Query().Get("km"), 64); err == nil && v > 0 &&
		!math.IsNaN(v) && !math.IsInf(v, 0) {
		km = v
	}
	if km > mahalleEnFazlaKm {
		km = mahalleEnFazlaKm
	}

	limit := 20
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 50 {
		limit = v
	}
	before := time.Now().Add(time.Hour)
	if s := r.URL.Query().Get("before"); s != "" {
		if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			before = t
		}
	}

	// ⚠️ `$4` = km, `$5` = lat, `$6` = lng. `$1/$2/$3` sirasi `engelYok`
	//    ($1 = me) ve mevcut sorgu duzeniyle uyumlu tutuldu.
	const mesafe = `
		(6371 * acos(least(1.0,
			cos(radians($5)) * cos(radians(p.enlem)) *
			cos(radians(p.boylam) - radians($6)) +
			sin(radians($5)) * sin(radians(p.enlem))
		)))`

	rows, err := h.db.Query(r.Context(), `
		SELECT p.id, p.author_id, p.tur, p.metin, p.media_ids,
		       p.begeni_sayisi, p.yorum_sayisi, p.goruntulenme,`+medyaTurleri+`
		       p.yorum_kapali, p.created_at,
		       u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=$1),
		       EXISTS(SELECT 1 FROM post_saves s WHERE s.post_id=p.id AND s.user_id=$1)
		  FROM posts p JOIN users u ON u.id = p.author_id
		 WHERE p.durum='yayinda' AND p.created_at < $2
		   AND (p.enlem <> 0 OR p.boylam <> 0)
		   AND p.enlem BETWEEN $5 - ($4 / 111.0) AND $5 + ($4 / 111.0)
		   AND p.boylam BETWEEN
		         $6 - ($4 / (111.0 * greatest(cos(radians($5)), 0.01)))
		     AND $6 + ($4 / (111.0 * greatest(cos(radians($5)), 0.01)))
		   AND `+mesafe+` <= $4
		   AND (p.author_id = $1 OR (NOT u.gizli_hesap AND u.verified))
		`+engelYok+yayindaOlan+`
		 ORDER BY p.created_at DESC LIMIT $3`,
		me, before, limit, km, lat, lng)
	if err != nil {
		log.Printf("mahalle: %v", err)
		hata(w, 500, "mahalle akışı alınamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{
		"km":    km,
		"posts": h.satirlariOku(r.Context(), me, rows),
	})
}
