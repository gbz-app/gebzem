package admin

import (
	"fmt"
	"net/http"
)

// ⚠️⚠️⚠️ TURU 181 — SIKAYET KUYRUGU VE ICERIK MODERASYONU.
//
// ═══════════ SIKAYET: YAZILIYORDU, HIC OKUNMUYORDU ═══════════
//
// `reports` tablosu `014_reports.sql` ile App Store Guideline 1.2 icin
// acilmisti ve `POST /reports` ona YAZIYORDU — ama okuyan TEK BIR SORGU
// bile yoktu (olculdu: `grep "FROM reports"` = 0). Yani her sikayet bir
// KARA DELIGE dusuyor, `durum` sutunu daima 'yeni' kaliyordu. 5651'in
// "4 saat icinde kaldirma" yukumlulugu ancak elle SQL ile karsilanabilirdi.
//
// ═══════════ KARANTINA: BEDAVA BIR SLOT ═══════════
//
// `posts` (021:40), `post_comments` (021:84), `channels` (022:49) ve
// `channel_posts` (022:100) semalarinda **`karantina` durumu ILK GUNDEN
// TANIMLI** ama HICBIR YERDEN YAZILMIYORDU. Yani moderasyon icin yeni bir
// migration GEREKMEDI: yalniz UPDATE + okuma yuklemlerinin karantinayi
// zaten eledigini dogrulamak yetti.
//
// ⚠️⚠️ **SILME DEGIL KARANTINA** (veri politikasi: VERI SILINMEZ):
//
//	karantina GERI ALINABILIR. Yanlis bir moderasyon karari, silme ile
//	telafi edilemez; karantina ile tek dokunusta geri alinir.

// icerikTablo — moderasyona acik icerik turleri.
//
// ⚠️⚠️ **BEYAZ LISTE ZORUNLU**: tablo adi istemciden geliyor ve SQL'e
//
//	gomuluyor. Serbest birakilsaydi SQL enjeksiyonu olurdu. Harita
//	disindaki her deger 400 ile reddedilir.
//
// ⚠️ Her girdi: tablo · kimlik tipi · sahiplik sutunu · ONIZLEME sutunu.
//
//	`durum` sutunu HEPSINDE var ve 'karantina' degerini KABUL EDER
//	(CHECK'lerden dogrulandi).
//
// ⚠️⚠️ **ONIZLEME SUTUNU BURADA, SORGUDA DEGIL** (turu 181 canli hatasi):
//
//	ilk yazimda sorgu icinde `COALESCE(icerik,'')` VARSAYILMISTI ve uc
//	tur birden **500** dondu — gercek sutun adi `metin` (canli semadan
//	olculdu; `channels`ta ise `ad`). Sutun adini tabloyla AYNI YERDE
//	tutmak, yeni bir tur eklenirken atlanmasini yapisal olarak zorlastirir.
//
// ⚠️ YAPMA: sutun adini sorguya elle yazma; buraya ekle.
//
// ⚠️⚠️ **KIMLIK TIPLERI CANLI SEMADAN OLCULDU** (turu 181), tahmin
//
//	EDILMEDI — ilk yazimda `posts.id` BIGINT sanilmisti ve o haliyle
//	gecerli bir gonderi UUID'si **400** alirdi (moderasyon dugmesi
//	calismazdi). Olcum:
//	  posts.id         = uuid
//	  post_comments.id = bigint
//	  channels.id      = uuid
//	  channel_posts.id = bigint
//
// ⚠️ Yeni bir tur eklerken kimlik tipini VARSAYMA; `information_schema`dan
//
//	oku.
var icerikTablo = map[string]struct {
	tablo    string
	idUUID   bool // kimlik UUID mi (yoksa BIGINT)
	sahipCol string
	metinCol string
}{
	"gonderi":       {"posts", true, "author_id", "metin"},
	"yorum":         {"post_comments", false, "author_id", "metin"},
	"kanal":         {"channels", true, "owner_id", "ad"},
	"kanal_gonderi": {"channel_posts", false, "author_id", "metin"},
}

// SikayetListesi — GET /admin/sikayetler?durum=&limit=
//
// ⚠️ Varsayilan suzgec `yeni`: kuyruk ekrani BEKLEYENLERI gostermeli;
//
//	kapatilmislari gormek icin acikca secilir.
//
// ⚠️⚠️ `hedef_id` bir FK DEGIL serbest metin (014 karari: kullanici id'si
//
//	UUID, mesaj id'si BIGINT). Bu yuzden hedefin ADI ancak `hedef_tur`
//	'kullanici' oldugunda cozulebilir; digerleri ham kimlikle gosterilir.
func (h *Handler) SikayetListesi(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	durum := r.URL.Query().Get("durum")
	if durum == "" {
		durum = "yeni"
	}
	if durum == "hepsi" {
		durum = ""
	}
	limit := sayi(r, "limit", 100, 1, 500)

	rows, err := h.db.Query(r.Context(), `
		SELECT rp.id, rp.hedef_tur, rp.hedef_id, rp.sebep, rp.aciklama,
		       rp.durum, COALESCE(rp.admin_notu,''),
		       to_char(rp.created_at,'DD.MM.YY HH24:MI'),
		       COALESCE(sikayetci.name,''), COALESCE(sikayetci.username,''),
		       COALESCE(hedefK.name,''), COALESCE(hedefK.username,''),
		       (SELECT count(*) FROM reports r2
		         WHERE r2.hedef_tur = rp.hedef_tur AND r2.hedef_id = rp.hedef_id)
		  FROM reports rp
		  LEFT JOIN users sikayetci ON sikayetci.id = rp.reporter_id
		  -- hedef_id TEXT; yalniz 'kullanici' turunde UUID'ye cevrilebilir.
		  -- Cast'i kosula BAGLAMAK ZORUNLU: bir mesaj id'sini (BIGINT)
		  -- uuid'ye cevirmek TUM SORGUYU patlatirdi.
		  -- (Serhte BACKTICK YOK: Go ham dizesini KAPATIR — turu 180 tuzagi.)
		  LEFT JOIN users hedefK
		         ON rp.hedef_tur = 'kullanici'
		        AND rp.hedef_id ~ '^[0-9a-fA-F-]{36}$'
		        AND hedefK.id = rp.hedef_id::uuid
		 WHERE ($1 = '' OR rp.durum = $1)
		 ORDER BY rp.created_at DESC
		 LIMIT $2`, durum, limit)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	defer rows.Close()

	out := []map[string]any{}
	for rows.Next() {
		var id int64
		var ht, hid, sebep, aciklama, drm, notu, zaman string
		var sAd, sKadi, hAd, hKadi string
		var tekrar int
		if rows.Scan(&id, &ht, &hid, &sebep, &aciklama, &drm, &notu, &zaman,
			&sAd, &sKadi, &hAd, &hKadi, &tekrar) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "hedef_tur": ht, "hedef_id": hid,
			"sebep": sebep, "aciklama": aciklama, "durum": drm,
			"admin_notu": notu, "zaman": zaman,
			"sikayetci": sAd, "sikayetci_kadi": sKadi,
			"hedef_ad": hAd, "hedef_kadi": hKadi,
			// ⚠️ "Bu hedef kac kez sikayet edildi": otomatik onceliklendirme
			//	icin (014'un `reports_hedef_idx` index'i tam bunun icin).
			"tekrar": tekrar,
		})
	}
	yaz(w, http.StatusOK, out)
}

// SikayetKapat — PATCH /admin/sikayetler/{id} {durum, not}
//
// ⚠️⚠️ `durum` BEYAZ LISTEDEN gecer: 014'teki CHECK zaten dort degeri
//
//	kabul ediyor ama bilinmeyen bir deger 500 dondururdu; kapi onu 400
//	yapar ve hangi degerlerin gecerli oldugunu SOYLER.
//
// ⚠️ `cozen`/`cozuldu_at` (migration 052) yazilir: "islem_yapildi" kaydi
//
//	kim ve ne zaman bilgisi olmadan hicbir seyi kanitlamaz.
func (h *Handler) SikayetKapat(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id := sayiYol(r, "id")
	if id <= 0 {
		hata(w, http.StatusBadRequest, "geçersiz kimlik")
		return
	}
	var req struct {
		Durum string `json:"durum"`
		Not   string `json:"not"`
	}
	if !govde(w, r, &req) {
		return
	}
	switch req.Durum {
	case "yeni", "incelendi", "islem_yapildi", "reddedildi":
	default:
		hata(w, http.StatusBadRequest,
			"durum: yeni | incelendi | islem_yapildi | reddedildi")
		return
	}
	tag, err := h.db.Exec(r.Context(), `
		UPDATE reports
		   SET durum = $2, admin_notu = $3,
		       cozen = CASE WHEN $2 = 'yeni' THEN NULL ELSE 'admin' END,
		       cozuldu_at = CASE WHEN $2 = 'yeni' THEN NULL ELSE now() END
		 WHERE id = $1`, id, req.Durum, kisalt(req.Not, 500))
	if err != nil {
		hata(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		hata(w, http.StatusNotFound, "şikâyet bulunamadı")
		return
	}
	Yaz(r, h.db, "sikayet."+req.Durum, "sikayet", fmt.Sprint(id), nil, req)
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}

// IcerikDurum — POST /admin/icerik/{tur}/{id}/durum {durum}
//
// `tur`: gonderi | yorum | kanal | kanal_gonderi
// `durum`: karantina | yayinda
//
// ⚠️⚠️ **SAHIPLIK KAPISI YOK VE BU BILINCLI**: mevcut silme uclarinin
//
//	hepsinde sahiplik SQL WHERE'ine gomulu (`AND author_id=$2`). Admin
//	icin o kapiyi GEVSETMEK yerine AYRI bir handler yazildi — mevcut
//	uclara bir "admin bayragi" eklemek, tek yanlis parametre bagliyla
//	sahiplik kapisini TUM kullanicilar icin acardi (streams/AdminEnd
//	deseninin ayni gerekcesi).
//
// ⚠️ Tablo adi BEYAZ LISTEDEN gelir (bkz. `icerikTablo`); istemciden gelen
//
//	bir dize DOGRUDAN SQL'e gomulmez.
func (h *Handler) IcerikDurum(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	tur := yolParam(r, "tur")
	bilgi, ok := icerikTablo[tur]
	if !ok {
		hata(w, http.StatusBadRequest,
			"tür: gonderi | yorum | kanal | kanal_gonderi")
		return
	}
	var req struct {
		Durum string `json:"durum"`
	}
	if !govde(w, r, &req) {
		return
	}
	if req.Durum != "karantina" && req.Durum != "yayinda" {
		hata(w, http.StatusBadRequest, "durum: karantina | yayinda")
		return
	}

	id := yolParam(r, "id")
	// ⚠️ Kimlik tipi tabloya gore degisir: `channels.id` UUID, digerleri
	//	BIGSERIAL. Yanlis tip pgx'te "invalid input syntax" -> 500 verir.
	if bilgi.idUUID {
		if !uuidBicimi(id) {
			hata(w, http.StatusBadRequest, "geçersiz kimlik")
			return
		}
	} else if sayiCoz(id) <= 0 {
		hata(w, http.StatusBadRequest, "geçersiz kimlik")
		return
	}

	// ⚠️ Sorgu `fmt.Sprintf` ile kuruluyor AMA tablo/sutun adlari BEYAZ
	//	LISTEDEN geliyor (kullanici girdisi DEGIL); deger `$1`/`$2` ile
	//	parametreli. Enjeksiyon yuzeyi YOK.
	// ⚠️⚠️ ONCEKI DURUM `UPDATE ... FROM` ile AYNI ISLEMDE okunur: ayri bir
	//	SELECT ile alinsaydi iki istek arasinda durum degisebilir ve
	//	denetim kaydi YANLIS bir "oncesi" yazardi.
	sorgu := fmt.Sprintf(`
		UPDATE %s t SET durum = $2
		  FROM (SELECT id, durum FROM %s WHERE id = $1) eski
		 WHERE t.id = eski.id
		 RETURNING t.%s::text, eski.durum`,
		bilgi.tablo, bilgi.tablo, bilgi.sahipCol)
	var sahip, eskiDurum string
	if err := h.db.QueryRow(r.Context(), sorgu, id, req.Durum).
		Scan(&sahip, &eskiDurum); err != nil {
		hata(w, http.StatusNotFound, "içerik bulunamadı")
		return
	}
	Yaz(r, h.db, "icerik."+req.Durum, tur, id,
		map[string]any{"sahip": sahip, "durum": eskiDurum},
		map[string]any{"durum": req.Durum})
	yaz(w, http.StatusOK, map[string]any{"ok": true, "sahip": sahip})
}

// IcerikListesi — GET /admin/icerik/{tur}?durum=&limit=&offset=
//
// ⚠️⚠️ Mevcut liste uclari `durum='yayinda'` SABIT yuklemi tasiyor
//
//	(ilan/handler.go:645, etkinlik:308, kanal:308) — yani karantinaya
//	alinmis bir icerigi ADMIN BILE goremezdi. Bu uc yuklemi
//	PARAMETRELESTIRIR.
func (h *Handler) IcerikListesi(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	tur := yolParam(r, "tur")
	bilgi, ok := icerikTablo[tur]
	if !ok {
		hata(w, http.StatusBadRequest,
			"tür: gonderi | yorum | kanal | kanal_gonderi")
		return
	}
	durum := r.URL.Query().Get("durum") // "" = hepsi
	limit := sayi(r, "limit", 50, 1, 200)
	offset := sayi(r, "offset", 0, 0, 100000)

	// ⚠️ Onizleme sutunu TABLOYA OZEL ve `icerikTablo` haritasindan gelir
	//	(bkz. harita serhi: ilk yazimda `icerik` VARSAYILMIS ve uc tur
	//	birden canlida 500 dondurmustu).
	metinCol := "COALESCE(t." + bilgi.metinCol + ",'')"
	sorgu := fmt.Sprintf(`
		SELECT t.id::text, t.durum, %s,
		       COALESCE(u.name,''), COALESCE(u.username,''),
		       to_char(t.created_at,'DD.MM.YY HH24:MI'),
		       (SELECT count(*) FROM reports rp
		         WHERE rp.hedef_tur = $1 AND rp.hedef_id = t.id::text)
		  FROM %s t
		  LEFT JOIN users u ON u.id = t.%s
		 WHERE ($2 = '' OR t.durum = $2)
		 ORDER BY t.created_at DESC
		 LIMIT $3 OFFSET $4`, metinCol, bilgi.tablo, bilgi.sahipCol)

	rows, err := h.db.Query(r.Context(), sorgu, tur, durum, limit, offset)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, drm, metin, ad, kadi, zaman string
		var sikayet int
		if rows.Scan(&id, &drm, &metin, &ad, &kadi, &zaman, &sikayet) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "durum": drm, "metin": kisalt(metin, 200),
			"sahip": ad, "sahip_kadi": kadi, "zaman": zaman,
			"sikayet_sayisi": sikayet,
		})
	}
	yaz(w, http.StatusOK, out)
}
