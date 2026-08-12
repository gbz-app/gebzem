package isletme

import (
	"log"
	"net/http"

	"github.com/gbz-app/gebzem/backend/internal/auth"
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
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       i.kategori, i.il, i.ilce, i.adres, u.onayli, u.kapak_media_id,
		       i.calisma,
		       (SELECT min(p.fiyat_kurus) FROM isletme_urunleri p
		         WHERE p.isletme_id = u.id AND p.durum = 'yayinda'
		           AND p.fiyat_kurus > 0),
		       (SELECT count(*) FROM isletme_urunleri p
		         WHERE p.isletme_id = u.id AND p.durum <> 'kaldirildi'),
		       i.min_tutar_kurus, i.teslimat_dk_min, i.teslimat_dk_max,
		       i.puan, i.puan_sayisi, i.kampanyalar
		  FROM isletme_favoriler f
		  JOIN users u      ON u.id = f.isletme_id
		  JOIN isletmeler i ON i.user_id = u.id
		 WHERE f.user_id = $1
		   AND u.hesap_turu='isletme'
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		                    WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		                       OR (b.blocker_id=u.id AND b.blocked_id=$1))
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
