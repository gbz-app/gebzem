package isletme

import (
	"log"
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
//    ⚠️ Kutu yaricapi DERECEYE cevrilirken enlem 1 derece ~111 km sabittir
//       ama BOYLAM enleme gore DARALIR (`cos(enlem)`) — ihmal edilirse
//       kuzeyde kutu gereginden GENIS olur (yalniz performans kaybi,
//       DOGRULUK kaybi degil, cunku Haversine son sozu soyler).

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
	if lat < -90 || lat > 90 || lng < -180 || lng > 180 {
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
		   -- ⚠️ KABA KUTU: Haversine'den ONCE daraltir.
		   AND i.enlem BETWEEN $2 - ($4 / 111.0) AND $2 + ($4 / 111.0)
		   AND i.boylam BETWEEN $3 - ($4 / 111.0) AND $3 + ($4 / 111.0)
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
