package isletme

import (
	"log"
	"math"
	"net/http"
	"strconv"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
)

// ⚠️⚠️⚠️ TURU 85 — "YAKINIMDA": KONUMA GORE ISLETME LISTESI.
//
// Kullanici emri: *"menuye tikladigimizda acilan pencereye yakinimda
// eklemeliyiz; ustte harita altta kartlar olacak — isletmeler, eczane vs"*.
//
// ═══════════ ON KOSUL (turu 78'de acikca yazilmisti) ═══════════
//
// `isletmeler.enlem/boylam` sutunlari **028'den beri VAR** ama turu 78'de
// soyle not edilmisti: *"hicbir kayitta DOLU DEGIL ve dolduracak arayuz yok;
// harita bos tuval olurdu. Once koordinat girisi lazim."*
// Turu 85'te o giris eklendi (`isletme_duzenle.dart` KONUM bolumu), yani bu
// uc artik GERCEK veri uzerinde calisabilir.
//
// ⚠️ **KONUMU OLMAYAN ISLETME LISTEDE CIKMAZ** (`enlem<>0 OR boylam<>0`).
//    Cikarilsaydi (0,0) koordinati Gine Korfezi'ndeki "Null Island"a denk
//    gelir ve TUM konumsuz isletmeler kullanici Turkiye'deyken ~6000 km
//    uzakta gorunurdu — liste anlamsizlasirdi.
//
// ═══════════ NEDEN PostGIS DEGIL ═══════════
//
// Mesafe HAVERSINE ile SQL icinde hesaplaniyor. PostGIS eklemek (a) yeni bir
// uzanti + migration, (b) Docker imajinda ek bagimlilik demekti. Bu olcekte
// (bir sehir, birkac bin isletme) kazanci YOK: sorgu zaten `LIMIT 60` ve
// once KABA BIR KUTU ile daraltiliyor (asagi bak).
//
// ⚠️ KABA KUTU (bounding box) OPTIMIZASYONU: once `enlem`/`boylam` araligina
//    dusenler suzuluyor, Haversine YALNIZ onlarda hesaplaniyor. Bu, mevcut
//    `idx_isletme_kategori` disinda index olmasa bile taramayi kucultur.
//
// ⚠️⚠️⚠️ TURU 85b — SERH **TERS YONU** ANLATIYORDU VE KUTU SONUC DUSURUYORDU.
//
//	Eski serh *"ihmal edilirse kutu gereginden GENIS olur, yalniz performans
//	kaybi"* diyordu. **YANLIS — TAM TERSI.** Kutu, yaricapi DERECEYE cevirmek
//	icin boylamda da `111.0`a boluyordu; oysa 1 derece BOYLAM enleme gore
//	KISALIR: `111 * cos(enlem)`.
//	  · Gebze enleminde (40.8°) `cos = 0.757` -> 1 derece boylam ~**84 km**.
//	  · Kutu `km/111` derece geniyor, oysa `km` mesafeye `km/84` derece lazim.
//	  · Yani kutu boylamda **~%24 DAR** ve dogu-batida yaricap icinde KALAN
//	    isletmeler kaba kutuda ELENIYOR.
//	Haversine "son sozu soyler" iddiasi da bu yuzden GECERSIZDI: Haversine
//	yalnizca kutudan GECENLERE uygulaniyor; kutu elediyse SORGU HIC GORMEZ.
//	Kayip SESSIZDIR — kullanici "yakinimda az isletme var" saniyordu.
//
// ⚠️ `greatest(..., 0.01)` ZORUNLU: kutuplara yakin `cos` sifira gider ve
//    bolme PATLAR (division by zero). 0.01 ~ 89.4° enlem; oranin uzerinde
//    kutu pratikte "tum boylamlar" olur ki DOGRU davranistir.
// ⚠️ YAPMA: boylam bolenini tekrar duz `111.0` yapma.

const (
	yakinVarsayilanKm = 10.0
	yakinEnFazlaKm    = 50.0
	yakinLimit        = 60
)

// GET /isletmeler/yakinimda?lat=..&lng=..&km=..&kategori=..
func (h *Handler) Yakinimda(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())

	lat, err1 := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lng, err2 := strconv.ParseFloat(r.URL.Query().Get("lng"), 64)
	if err1 != nil || err2 != nil || (lat == 0 && lng == 0) {
		hata(w, 400, "konum gerekli")
		return
	}
	// ⚠️ Dunya disi koordinat REDDEDILIR: bozuk bir istemci degeri sorguyu
	//    anlamsiz kilar ve kullaniciya "yakininda hicbir sey yok" dedirtir.
	// ⚠️⚠️ TURU 85b — `NaN`/`Inf` AYRICA ELENIR (denetim bulgusu).
	//    `strconv.ParseFloat("NaN", 64)` **HATA DONDURMEZ**; ustelik NaN her
	//    karsilastirmadan (`<`, `>`) `false` ile gecer, yani ustteki arali
	//    kontrolu onu YAKALAYAMAZ. Sorguya girdiginde her Haversine ve her
	//    kutu karsilastirmasi NULL/false uretir -> istemci 400 yerine
	//    **SESSIZ BOS LISTE** gorur ve hatayi "cevremde isletme yok" sanar.
	//    `Inf` de ayni sinif (`+Inf > 180` true oldugu icin o aslinda
	//    yakalaniyordu, ama olcutu ACIK yazmak niyeti belgeler).
	if math.IsNaN(lat) || math.IsNaN(lng) || math.IsInf(lat, 0) || math.IsInf(lng, 0) ||
		lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		hata(w, 400, "konum geçersiz")
		return
	}

	km := yakinVarsayilanKm
	if v, err := strconv.ParseFloat(r.URL.Query().Get("km"), 64); err == nil && v > 0 {
		km = v
	}
	if km > yakinEnFazlaKm {
		km = yakinEnFazlaKm
	}
	kategori := r.URL.Query().Get("kategori")
	if kategori != "" {
		if _, ok := Kategoriler[kategori]; !ok {
			hata(w, 400, "geçersiz kategori")
			return
		}
	}

	// ⚠️ Haversine (km). 6371 = Dunya yaricapi.
	// ⚠️ `least(1, ...)` ZORUNLU: kayan nokta yuvarlamasi cok yakin iki nokta
	//    icin `acos` argumanini 1'in HAFIFCE USTUNE cikarabilir ve Postgres
	//    "input is out of range" ile PATLAR (klasik Haversine tuzagi).
	const mesafe = `
		(6371 * acos(least(1.0,
			cos(radians($2)) * cos(radians(i.enlem)) *
			cos(radians(i.boylam) - radians($3)) +
			sin(radians($2)) * sin(radians(i.enlem))
		)))`

	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_url,
		       u.avatar_media_id, i.kategori, i.il, i.ilce, i.adres, u.onayli,
		       i.enlem, i.boylam, `+mesafe+` AS km
		  FROM isletmeler i JOIN users u ON u.id = i.user_id
		 WHERE u.hesap_turu='isletme'
		   -- ⚠️ KONUMSUZ ISLETME LISTEDE CIKMAZ (bkz. dosya serhi).
		   AND (i.enlem <> 0 OR i.boylam <> 0)
		   -- KABA KUTU: Haversine'den ONCE daraltir. Boylam boleni enleme
		   -- gore duzeltilir (bkz. dosya serhi: duz 111.0 SONUC DUSURUYORDU).
		   AND i.enlem BETWEEN $2 - ($4 / 111.0) AND $2 + ($4 / 111.0)
		   AND i.boylam BETWEEN
		         $3 - ($4 / (111.0 * greatest(cos(radians($2)), 0.01)))
		     AND $3 + ($4 / (111.0 * greatest(cos(radians($2)), 0.01)))
		   AND ($5 = '' OR i.kategori = $5)
		`+engel.Yuklem("$1", "u.id")+`
		   AND `+mesafe+` <= $4
		 ORDER BY km ASC
		 LIMIT `+strconv.Itoa(yakinLimit),
		me, lat, lng, km, kategori)
	if err != nil {
		log.Printf("yakinimda: %v", err)
		hata(w, 500, "yakındaki işletmeler alınamadı")
		return
	}
	defer rows.Close()

	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kullanici, avatar, kat, il, ilce, adres string
		var medya *string
		var dogru bool
		var enlem, boylam, uzaklik float64
		// ⚠️ SCAN SIRASI SELECT SIRASIYLA BIREBIR. Uyusmazlik derleme hatasi
		//    VERMEZ; satir SESSIZCE atlanir ve liste bosalir (turu 76 dersi).
		if rows.Scan(&id, &ad, &kullanici, &avatar, &medya, &kat, &il, &ilce,
			&adres, &dogru, &enlem, &boylam, &uzaklik) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "name": ad, "username": kullanici,
			"avatar_url": avatar, "avatar_media_id": medya,
			"kategori": kat, "kategori_ad": Kategoriler[kat],
			"il": il, "ilce": ilce, "adres": adres,
			// ⚠️⚠️ ANAHTAR **`dogrulandi`** — `onayli` DEGIL. Ilk yazimda
			//    `onayli` yazilmisti; `IsletmeOzet.json` `dogrulandi` okuyor,
			//    yani onayli rozeti bu listede **HIC CIZILMEZDI**. Sutun adi
			//    (`u.onayli`) ile JSON adi FARKLI ve mevcut `Liste` ucu
			//    `dogrulandi` donduruyor — iki uc AYNI sozlesmeyi konusmali.
			// ⚠️ Bu, turu 78'de `Profile()`in kapak/onayli alanlarini yanit
			//    haritasina koymamasiyla AYNI SINIF hata.
			"dogrulandi": dogru,
			"enlem": enlem, "boylam": boylam,
			// ⚠️ Mesafe SUNUCUDA hesaplanip donuyor: istemcide tekrar
			//    hesaplamak "ayni kuralin iki kopyasi" olurdu ve siralama ile
			//    gosterilen deger AYRISABILIRDI.
			"km": uzaklik,
		})
	}
	yaz(w, 200, map[string]any{"isletmeler": out})
}
