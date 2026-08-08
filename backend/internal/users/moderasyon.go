package users

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️ TURU 74 — ENGELLEME + SIKAYET UCLARI.
//
// DURUM TESPITI (kod okunarak): `blocks` tablosu 001_init.sql'den beri VAR ama
// ONA YAZAN DA OKUYAN DA YOKTU. Ustelik `chat/handler.go`da `chatMemberIDs`
// cagrisinin ustundeki yorum "uyelik + engel kontrolu" diyordu — YANLIS; o fonksiyon
// yalnizca uyelige bakiyordu. Yani engelleme SAHADA HIC CALISMIYORDU.
//
// ⚠️ NEDEN SIMDI: App Store Review Guideline 1.2 kullanici uretimi icerik barindiran
// uygulamalarda ENGELLEME + SIKAYET + icerik kaldirmayi birlikte sart kosuyor.
// Sohbete medya ve herkese acik gonderi eklemeden ONCE bunlar durmali.

type blockResp struct {
	ID        string `json:"id"`
	Username  string `json:"username"`
	Name      string `json:"name"`
	AvatarURL string `json:"avatar_url"`
}

// POST /users/{id}/block — bu kullaniciyi engelle.
// Idempotent: zaten engelliyse yine 200 doner.
func (h *Handler) Block(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	if hedef == "" || hedef == me {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "geçersiz kullanıcı"})
		return
	}
	// ⚠️ Hedefin GERCEKTEN var oldugunu dogrula — yoksa FK hatasi 500 olarak doner
	//     ve istemci "sunucu hatasi" gorur.
	var varMi bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1)`, hedef).Scan(&varMi); err != nil || !varMi {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "kullanıcı bulunamadı"})
		return
	}
	if _, err := h.db.Exec(r.Context(),
		`INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
		me, hedef); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "engellenemedi"})
		return
	}
	// ⚠️⚠️ TURU 75 — ENGELLEME TAKIBI DE DUSURUR (IKI YONLU).
	// Aksi halde engelleme DELINIRDI: engellenen kisi seni takip etmeye ve
	// gonderilerini gormeye DEVAM ederdi. Sayaclar takibiKaldir icinde
	// AYNI TRANSACTION'da guncellenir.
	// ⚠️ DB tetikleyicisi KULLANILMADI: gizli davranis hata ayiklamayi zorlastirir.
	// ⚠️ Hata YUTULUR — engelleme islemi takip temizligi yuzunden BASARISIZ OLMAZ.
	h.takibiKaldir(r.Context(), me, hedef)
	h.takibiKaldir(r.Context(), hedef, me)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// DELETE /users/{id}/block — engeli kaldir. Idempotent.
func (h *Handler) Unblock(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	// ⚠️ TURU 74b: gecersiz UUID pgx tip hatasi -> 500 doneriyordu (Block'ta
	//    bu kontrol vardi, Unblock'ta yoktu).
	if hedef == "" || hedef == me {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "geçersiz kullanıcı"})
		return
	}
	if _, err := h.db.Exec(r.Context(),
		`DELETE FROM blocks WHERE blocker_id=$1 AND blocked_id=$2`, me, hedef); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "kaldırılamadı"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// GET /users/me/blocks — engellediklerim (ayarlar ekrani icin).
func (h *Handler) ListBlocks(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.username, u.name, u.avatar_url
		  FROM blocks b JOIN users u ON u.id = b.blocked_id
		 WHERE b.blocker_id=$1
		 ORDER BY b.created_at DESC`, me)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "liste alınamadı"})
		return
	}
	defer rows.Close()
	// ⚠️ Bos dilim yerine `[]` donmeli — Flutter tarafinda `null` liste patlatiyor.
	out := []blockResp{}
	for rows.Next() {
		var b blockResp
		if err := rows.Scan(&b.ID, &b.Username, &b.Name, &b.AvatarURL); err == nil {
			out = append(out, b)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

type reportReq struct {
	HedefTur string `json:"hedef_tur"` // kullanici | mesaj
	HedefID  string `json:"hedef_id"`
	Sebep    string `json:"sebep"`
	Aciklama string `json:"aciklama"`
}

// POST /reports — sikayet et.
// ⚠️ Idempotent: ayni kullanici ayni hedefi tekrar sikayet ederse yeni satir ACILMAZ
//
//	(UNIQUE + ON CONFLICT DO NOTHING) ama istemciye yine 200 doner — kullanici
//	"sikayetim gitti" gorur, biz spam satiri biriktirmeyiz.
func (h *Handler) Report(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req reportReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "geçersiz istek"})
		return
	}
	// ⚠️ TUR BEYAZ LISTESI (turu 59 dersi: istemciden gelen tip DOGRULANMADAN
	//     yazilmamali). Yeni icerik tipleri geldikce BURAYA eklenecek.
	switch req.HedefTur {
	case "kullanici", "mesaj":
	default:
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "geçersiz şikâyet türü"})
		return
	}
	// ⚠️ TURU 74b: hedef_id SERBEST METINDI -> UNIQUE(reporter,tur,hedef) her
	//    farkli deger icin YENI SATIR demek; tek kullanici sinirsiz satir yazabilirdi.
	if len(req.HedefID) > 64 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "geçersiz hedef"})
		return
	}
	if req.HedefID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "hedef belirtilmedi"})
		return
	}
	// ⚠️ Serbest metni SINIRLA — sinirsiz metin hem depolama hem admin paneli sorunu.
	if len(req.Aciklama) > 1000 {
		req.Aciklama = req.Aciklama[:1000]
	}
	if len(req.Sebep) > 40 {
		req.Sebep = req.Sebep[:40]
	}
	if _, err := h.db.Exec(r.Context(), `
		INSERT INTO reports (reporter_id, hedef_tur, hedef_id, sebep, aciklama)
		VALUES ($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING`,
		me, req.HedefTur, req.HedefID, req.Sebep, req.Aciklama); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "şikâyet kaydedilemedi"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
