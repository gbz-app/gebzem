package isletme

import (
	"log"
	"net/http"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
	"github.com/go-chi/chi/v5"
)

// ⚠️⚠️ TURU 94 — ISLETME FAVORILERI (migration 047).
//
// Kullanici kategori ekraninin sag ustune kalp istedi. Kalbin gidecegi bir
// liste, listenin de dolacagi bir eylem gerekiyordu — ikisi BIRLIKTE yazildi.
// ⚠️ YAPMA: birini yazip otekini birakma; bu projede "uc var, cagiran yol
//
//	yok" sinifi DOKUZ kez sahaya cikti.

// POST /isletmeler/{id}/favori — favorile.
//
// ⚠️ IDEMPOTENT (`ON CONFLICT DO NOTHING`): cift dokunus, gec gelen bir
//
//	yeniden deneme ya da iki cihaz ayni anda favorilerse hata DONMEZ.
//	Kullanici acisindan sonuc ayni: isletme favoride.
func (h *Handler) FavoriEkle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	// ⚠️ KENDI ISLETMENI FAVORILEYEMEZSIN: listede kendini gormek anlamsiz
	//    ve favori sayaci ileride bir siralama olcutu olursa kendi kendini
	//    yukseltme kapisi acilirdi.
	if id == me {
		hata(w, 400, "kendi işletmeni favorileyemezsin")
		return
	}
	// ⚠️ HEDEF GERCEKTEN ISLETME MI: kisisel bir hesabi favorilemek
	//    "Favorilerim" listesinde isletme kartiyla cizilemeyen bir satir
	//    birakirdi. FK tek basina bunu ayirt etmez (ikisi de `users`).
	var isletmeMi bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users u JOIN isletmeler i ON i.user_id=u.id
		                WHERE u.id=$1 AND u.hesap_turu='isletme')`, id).
		Scan(&isletmeMi); err != nil || !isletmeMi {
		hata(w, 404, "işletme bulunamadı")
		return
	}
	if _, err := h.db.Exec(r.Context(), `
		INSERT INTO isletme_favoriler (user_id, isletme_id)
		VALUES ($1,$2) ON CONFLICT DO NOTHING`, me, id); err != nil {
		log.Printf("favori ekle: %v", err)
		hata(w, 500, "eklenemedi")
		return
	}
	yaz(w, 200, map[string]bool{"favorim": true})
}

// DELETE /isletmeler/{id}/favori — favoriden cikar.
//
// ⚠️ Satir YOKSA DA 200: "favoride degil" ile "cikarildi" kullanici acisindan
//
//	AYNI sonuctur. 404 donmek, iki cihazdan ayni anda cikarilinca birinde
//	hata gostermek demekti.
func (h *Handler) FavoriCikar(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "bulunamadı")
		return
	}
	if _, err := h.db.Exec(r.Context(),
		`DELETE FROM isletme_favoriler WHERE user_id=$1 AND isletme_id=$2`,
		me, id); err != nil {
		log.Printf("favori cikar: %v", err)
		hata(w, 500, "çıkarılamadı")
		return
	}
	yaz(w, 200, map[string]bool{"favorim": false})
}

// GET /users/me/favori-isletmeler — favori isletmelerim.
//
// ⚠️⚠️ SORGU **`Liste` ILE AYNI SUTUNLARI** dondurur: istemci ayni
//
//	`IsletmeOzet` modelini ve ayni karti kullanir. Farkli bir sutun kumesi
//	donseydi favori ekraninda puan/teslimat/kampanya SESSIZCE kaybolurdu
//	(turu 78 "Scan edildi ama yanita konmadi" sinifinin kardesi).
//
// ⚠️ Engel yuklemi BURADA DA uygulanir: favorilediginiz kisi sizi sonradan
//
//	engellemis olabilir.
func (h *Handler) Favorilerim(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	// ⚠️⚠️⚠️ TURU 110 — **BU LISTE CANLIDA BOSTU (sevk engeli).**
	//
	//	Sorgu kendi sutun listesini ELLE yaziyordu ve **20 sutun**
	//	donduruyordu; `favoriSatir` -> `isletmeSatiri` ise **23 hedefe**
	//	Scan ediyor. Eksik uclu: `i.enlem`, `i.boylam`, `u.created_at`.
	//	Ikisi `27b8540`da, ucuncusu `afa5a51`de `isletmeSutunlari`na
	//	eklendi — bu sorgu IKI KEZ de guncellenmedi.
	//
	//	Sonuc: pgx *"number of field descriptions must equal number of
	//	destinations"* doner, `favoriSatir` hata verir ve asagidaki
	//	`continue` **HER SATIRI SESSIZCE ATLAR** -> "Favorilerim" DAIMA
	//	BOS. `go build`, `go vet` ve `sutun_test.go` UCU DE YESILDI
	//	(muhafiz yalniz `Detay`/`Liste`/`Urun` sorgularini kapsiyor).
	//
	// ⚠️ FIX: sorgu artik **`isletmeSutunlari` TEK KAYNAGINI** kullanir —
	//    yeni bir sutun eklendiginde bu liste de otomatik dogru kalir.
	// ⚠️ Elle yazilmis `NOT EXISTS blocks` de `engel.Yuklem`e devredildi
	//    (ayni sinifin kucuk kardesi: kuralin iki kopyasi drift eder).
	// ⚠️ YAPMA: buraya tekrar elle sutun listesi yazma.
	rows, err := h.db.Query(r.Context(), `
		SELECT `+isletmeSutunlari+`
		  FROM isletme_favoriler f
		  JOIN users u      ON u.id = f.isletme_id
		  JOIN isletmeler i ON i.user_id = u.id
		 WHERE f.user_id = $1 AND u.hesap_turu='isletme'
		   `+engel.Yuklem("$1", "u.id")+`
		 ORDER BY f.created_at DESC
		 LIMIT 100`, me)
	if err != nil {
		log.Printf("favorilerim: %v", err)
		hata(w, 500, "favoriler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		m, e := favoriSatir(rows)
		if e != nil {
			log.Printf("favorilerim — satir atlandi: %v", e)
			continue
		}
		out = append(out, m)
	}
	if e := rows.Err(); e != nil {
		log.Printf("favorilerim — satirlar yarida kesildi (%d): %v", len(out), e)
	}
	yaz(w, 200, map[string]any{"isletmeler": out})
}
