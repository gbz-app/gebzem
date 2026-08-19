package social

import (
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 115 — GONDERI ARAMASI (kullanici emri: *"arama kismi icin sana
// TIKTOK TARZI olsun dedim"*).
//
// TikTok'un arama ekraninda sonuclar SEKMELERE ayrilir. Mevcut uclar uc sekmeyi
// zaten besliyordu:
//
//	· Kullanicilar -> GET /users/search?q=
//	· Isletmeler   -> GET /isletmeler?q=
//	· Ilanlar      -> GET /ilanlar?q=
//
// Ama **GONDERI metni uzerinde arama yapan HICBIR UC YOKTU**
// (`grep -rn "metin ILIKE" internal/` = 0). Yani "Top / Video / Ses / Yer"
// sekmeleri sunucudan BESLENEMEZDI. Bu uc tam o boslugu kapatir.
//
// ═══════════ MIGRATION GEREKMEDI ═══════════
//
// Aranan her sey ZATEN duruyor: `posts.metin` (021), `posts.konum_ad/enlem/
// boylam` (044) ve `media_assets.kind` (015). Yeni sutun/tablo ACILMADI.
//
// ⚠️⚠️ **`posts.tur`a 'ses' EKLENMEDI.** O sutunun CHECK'i
//
//	`('foto','video','reels','yazi')` ve CLAUDE.md turu 81/83'te CHECK'i
//	DROP/ADD etmenin tuzagi kayitli. Sesli gonderi bu projede zaten
//	`tur='foto'` + ILK MEDYANIN `kind='audio'` olmasidir; istemci de
//	(`Gonderi.sesliMi`) bunu boyle turetiyor. Suzgec de oyle yazildi.
//
// ═══════════ KELIME BAZLI **AND** ═══════════
//
// Sorgu kelimelere bolunur ve HER KELIME metinde (ya da konum adinda) gecmek
// ZORUNDADIR. Turu 93b'de isletme aramasi TEK BITISIK ALT DIZE ariyordu ve
// `q="saç serkan"` -> `ILIKE '%saç serkan%'` yuzunden **"Serkan Saç" bile
// eslesmiyordu**; ayni tuzagi burada tekrarlamamak icin bastan AND yazildi.
//
// ⚠️ `lower()` KULLANILMAZ: `ILIKE` zaten harf duyarsiz ve `lower()` Turkce'de
//
//	"İ" icin YANLIS sonuc verir (turu 93b).
//
// ⚠️ Kelimeler TEK PARAMETREDE (`$3::text[]`) gonderilir: degisken sayida
//
//	parametreyle SQL ORMEK, parametre numaralarini kaydirir ve `engelYok`
//	gibi paylasilan sabitlerin `$1`ini bozardi.
const araYuklemi = `
		   AND (SELECT bool_and(
		          (COALESCE(p.metin,'') || ' ' || COALESCE(p.konum_ad,''))
		            ILIKE '%' || w || '%')
		        FROM unnest($3::text[]) AS w)`

// GET /ara?q=...&tur=video|ses|konum&limit=&before=
//
// ⚠️ Donus sozlesmesi `/feed`, `/kesfet` ve `/mahalle` ile BIREBIR ayni
//
//	(`{"posts":[...]}`) — istemci ayni `Gonderi.json` ayristirmasini ve ayni
//	sayfalama kodunu kullanir.
func (h *Handler) Ara(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())

	q := strings.TrimSpace(r.URL.Query().Get("q"))
	// ⚠️ EN AZ 2 KARAKTER — `/users/search` ile AYNI esik. Tek harflik arama
	//    tum tabloyu tarar ve kullaniciya da bir sey anlatmaz.
	//    ⚠️ Rune ile sayilir: "iş" iki HARFTIR ama UTF-8'de 3 bayttir.
	if len([]rune(q)) < 2 {
		hata(w, 400, "en az 2 karakter yaz")
		return
	}
	kelimeler := strings.Fields(q)
	// ⚠️ TAVAN: bir kullanici 50 kelimelik bir dize gonderip sorguyu
	//    agirlastirmasin. Ilk 6 kelime pratikte fazlasiyla yeter.
	if len(kelimeler) > 6 {
		kelimeler = kelimeler[:6]
	}

	// ⚠️ Beyaz liste: bilinmeyen `tur` degeri SESSIZCE "hepsi" gibi
	//    davranmamali — istemci yeni bir sekme eklerse ve sunucu eski surumse
	//    kullanici YANLIS sonuc gorurdu.
	tur := r.URL.Query().Get("tur")
	ekKosul := ""
	switch tur {
	case "":
		// hepsi
	case "video":
		ekKosul = ` AND p.tur IN ('video','reels')`
	case "ses":
		// ⚠️ Sesli gonderi = ILK MEDYASI `audio` olan gonderi (bkz. dosya serhi).
		ekKosul = ` AND cardinality(p.media_ids) > 0
		   AND EXISTS(SELECT 1 FROM media_assets ma
		               WHERE ma.id = p.media_ids[1] AND ma.kind = 'audio')`
	case "konum":
		ekKosul = ` AND (p.enlem <> 0 OR p.boylam <> 0)`
	default:
		hata(w, 400, "geçersiz tür")
		return
	}

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
		   AND (p.author_id = $1 OR (NOT u.gizli_hesap AND u.verified))
		`+araYuklemi+ekKosul+engelYok+yayindaOlan+`
		 ORDER BY p.created_at DESC LIMIT $4`,
		me, before, kelimeler, limit)
	if err != nil {
		log.Printf("ara: %v", err)
		hata(w, 500, "arama yapılamadı")
		return
	}
	defer rows.Close()
	yaz(w, 200, map[string]any{"posts": h.satirlariOku(r.Context(), me, rows)})
}
