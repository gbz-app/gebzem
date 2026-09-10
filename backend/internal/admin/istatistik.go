package admin

import "net/http"

// ⚠️⚠️ TURU 181 — GENEL ISTATISTIK.
//
// Mevcut `/admin/stats` (calls paketi) YALNIZ kullanici + arama sayiyor;
// ilan/etkinlik/randevu/gonderi/kanal/urun/talep/sikayet HIC sayilmiyordu.
// Bu uc onun YERINE gecmez, yaninda durur — panel yeni olani kullanir.
//
// ⚠️⚠️ TEK SORGU, COK ALT SORGU: her sayac icin ayri `QueryRow` yazmak 14
//
//	gidis-donus demekti. Alt sorgular kucuk tablolarda index taramasiyla
//	karsilanir.
//
// ⚠️ Hata YUTULMAZ: sayaclar 0 gorunurse panel "sistem bos" der ve bu
//
//	YANLIS BILGIDIR. Sorgu patlarsa 500.
func (h *Handler) Istatistik(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	var (
		kullanici, isletme, askida, onayli              int
		urun, ilan, etkinlik, randevu                   int
		gonderi, karantina, kanal, hikaye               int
		sikayetYeni, sikayetTop, aramaAktif, yayinAktif int
		medyaAktif, medyaSilinen                        int
	)
	err := h.db.QueryRow(r.Context(), `
		SELECT
		  (SELECT count(*) FROM users),
		  (SELECT count(*) FROM users WHERE hesap_turu='isletme'),
		  (SELECT count(*) FROM users WHERE suspended_at IS NOT NULL),
		  (SELECT count(*) FROM users WHERE onayli),
		  (SELECT count(*) FROM isletme_urunleri WHERE durum <> 'kaldirildi'),
		  (SELECT count(*) FROM ilanlar   WHERE durum='yayinda'),
		  (SELECT count(*) FROM etkinlikler WHERE durum='yayinda'),
		  (SELECT count(*) FROM randevular WHERE durum IN ('bekliyor','onaylandi')),
		  (SELECT count(*) FROM posts WHERE durum='yayinda'),
		  (SELECT count(*) FROM posts WHERE durum='karantina'),
		  (SELECT count(*) FROM channels WHERE durum='aktif'),
		  (SELECT count(*) FROM stories
		    WHERE durum='yayinda' AND created_at > now() - interval '24 hours'),
		  (SELECT count(*) FROM reports WHERE durum='yeni'),
		  (SELECT count(*) FROM reports),
		  (SELECT count(*) FROM calls   WHERE status='active'),
		  (SELECT count(*) FROM streams WHERE status='live'),
		  (SELECT count(*) FROM media_assets WHERE status IN ('aktif','bagli')),
		  (SELECT count(*) FROM media_assets WHERE status='silindi')`).
		Scan(&kullanici, &isletme, &askida, &onayli,
			&urun, &ilan, &etkinlik, &randevu,
			&gonderi, &karantina, &kanal, &hikaye,
			&sikayetYeni, &sikayetTop, &aramaAktif, &yayinAktif,
			&medyaAktif, &medyaSilinen)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	yaz(w, http.StatusOK, map[string]int{
		"kullanici": kullanici, "isletme": isletme,
		"askida": askida, "onayli": onayli,
		"urun": urun, "ilan": ilan, "etkinlik": etkinlik, "randevu": randevu,
		"gonderi": gonderi, "karantina": karantina,
		"kanal": kanal, "hikaye": hikaye,
		"sikayet_yeni": sikayetYeni, "sikayet_toplam": sikayetTop,
		"arama_aktif": aramaAktif, "yayin_aktif": yayinAktif,
		"medya_aktif": medyaAktif, "medya_silinen": medyaSilinen,
	})
}

// UrunListesi — GET /admin/urunler?isletme=&q=&limit=&offset=
//
// ⚠️ Mevcut `/users/{id}/urunler` ucu KIMLIK ister ve baskasinin
//
//	katalogunda `durum <> 'kaldirildi'` suzgeci uygular. Admin listesi
//	kaldirilmis kalemleri de gormek zorunda (geri alma karari icin).
func (h *Handler) UrunListesi(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	isl := r.URL.Query().Get("isletme")
	if isl != "" && !uuidBicimi(isl) {
		hata(w, http.StatusBadRequest, "geçersiz işletme kimliği")
		return
	}
	q := kisalt(r.URL.Query().Get("q"), 60)
	limit := sayi(r, "limit", 100, 1, 300)
	offset := sayi(r, "offset", 0, 0, 100000)

	rows, err := h.db.Query(r.Context(), `
		SELECT p.id::text, p.ad, COALESCE(p.aciklama,''), COALESCE(p.bolum,''),
		       p.fiyat_kurus, p.durum, p.tur,
		       COALESCE(array_length(p.media_ids,1),0),
		       p.isletme_id::text, COALESCE(u.name,''),
		       to_char(p.created_at,'DD.MM.YY HH24:MI')
		  FROM isletme_urunleri p
		  LEFT JOIN users u ON u.id = p.isletme_id
		 WHERE ($1 = '' OR p.isletme_id = $1::uuid)
		   AND ($2 = '' OR p.ad ILIKE '%'||$2||'%')
		 ORDER BY p.created_at DESC
		 LIMIT $3 OFFSET $4`, isl, q, limit, offset)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, aciklama, bolum, drm, tur, islID, islAd, zaman string
		var fiyat int64
		var medya int
		if rows.Scan(&id, &ad, &aciklama, &bolum, &fiyat, &drm, &tur,
			&medya, &islID, &islAd, &zaman) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "ad": ad, "aciklama": aciklama, "bolum": bolum,
			"fiyat_kurus": fiyat, "durum": drm, "tur": tur,
			"medya_sayisi": medya, "isletme_id": islID, "isletme_ad": islAd,
			"zaman": zaman,
		})
	}
	yaz(w, http.StatusOK, out)
}

// UrunDurum — POST /admin/urunler/{id}/durum {durum}
//
// ⚠️ `durum` beyaz listesi `internal/isletme/urun.go:171` ile AYNI kume:
//
//	yayinda | tukendi | kaldirildi. Ayrisirsa panel DB CHECK'ine takilip
//	500 dondururdu.
func (h *Handler) UrunDurum(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id := yolParam(r, "id")
	if !uuidBicimi(id) {
		hata(w, http.StatusBadRequest, "geçersiz kimlik")
		return
	}
	var req struct {
		Durum string `json:"durum"`
	}
	if !govde(w, r, &req) {
		return
	}
	switch req.Durum {
	case "yayinda", "tukendi", "kaldirildi":
	default:
		hata(w, http.StatusBadRequest, "durum: yayinda | tukendi | kaldirildi")
		return
	}
	var islID string
	if err := h.db.QueryRow(r.Context(), `
		UPDATE isletme_urunleri SET durum=$2, updated_at=now()
		 WHERE id=$1::uuid RETURNING isletme_id::text`, id, req.Durum).
		Scan(&islID); err != nil {
		hata(w, http.StatusNotFound, "ürün bulunamadı")
		return
	}
	Yaz(r, h.db, "urun."+req.Durum, "urun", id,
		map[string]any{"isletme_id": islID}, map[string]any{"durum": req.Durum})
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}
