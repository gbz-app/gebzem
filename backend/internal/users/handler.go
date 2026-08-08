package users

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

type Handler struct {
	db *pgxpool.Pool
	// TURU 74: medya (R2) yapilandirilmis mi. Istemci atac dugmesini buna gore gizler.
	// ⚠️ Sunucu env eksikse medya uclari HIC KAYDEDILMEZ; istemci bunu ONCEDEN
	//    bilmezse kullaniciya "yukleniyor..." gosterip 404 alirdi.
	medyaAcik bool
}

func NewHandler(db *pgxpool.Pool) *Handler {
	return &Handler{db: db}
}

// MedyaDurumu — main.go acilista bir kez cagirir.
func (h *Handler) MedyaDurumu(acik bool) { h.medyaAcik = acik }

type userResp struct {
	ID        string `json:"id"`
	Phone     string `json:"phone,omitempty"` // gizlilik: aramada donmez
	Username  string `json:"username"`
	Name      string `json:"name"`
	About     string `json:"about"`
	AvatarURL string `json:"avatar_url"`
	// TURU 74: yeni avatarlar R2'de; istemci /media/{id}/url ile imzali adresi alir
	// ve ONBELLEGI media_id'ye gore tutar (URL 600sn omurlu, anahtar OLAMAZ).
	AvatarMediaID *string    `json:"avatar_media_id,omitempty"`
	CoinBalance   int64      `json:"coin_balance,omitempty"`
	LastSeen      *time.Time `json:"last_seen,omitempty"`
}

// GET /users/me — kendi profilim (jeton bakiyesi dahil)
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var u userResp
	err := h.db.QueryRow(r.Context(), `
		SELECT id, phone, COALESCE(username,''), name, about, avatar_url, avatar_media_id, coin_balance, last_seen
		FROM users WHERE id=$1`, userID).
		Scan(&u.ID, &u.Phone, &u.Username, &u.Name, &u.About, &u.AvatarURL, &u.AvatarMediaID, &u.CoinBalance, &u.LastSeen)
	if err != nil {
		writeErr(w, http.StatusNotFound, "kullanıcı bulunamadı")
		return
	}
	// TURU 74: istemci medya kapaliysa atac dugmesini gostermesin.
	writeJSON(w, http.StatusOK, meYanit{userResp: u, MedyaAcik: h.medyaAcik})
}

// meYanit — /users/me yanitina TURU 74'te eklenen tek alan.
// ⚠️ ANONIM GOMME kullaniliyor: `userResp`un alanlari duz JSON'a ackilir, yani
//
//	mevcut istemciler HICBIR degisiklik gormez; yalnizca yeni `media_acik`
//	alani eklenir (geriye donuk uyumlu).
type meYanit struct {
	userResp
	MedyaAcik bool `json:"media_acik"`
}

var usernameRe = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

// GET /users/search?q= — isim veya kullanici adiyla ara (telefon numarasi gerekmez)
func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	q := strings.TrimSpace(strings.TrimPrefix(r.URL.Query().Get("q"), "@"))
	if len(q) < 2 {
		writeErr(w, http.StatusBadRequest, "en az 2 karakter yazın")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, COALESCE(username,''), name, about, avatar_url, avatar_media_id
		FROM users
		WHERE verified = true
		  AND id <> $1
		  AND id NOT IN (SELECT blocker_id FROM blocks WHERE blocked_id = $1)
		  AND id NOT IN (SELECT blocked_id FROM blocks WHERE blocker_id = $1)
		  AND (lower(username) LIKE lower($2) || '%' OR lower(name) LIKE '%' || lower($2) || '%')
		ORDER BY
		  CASE WHEN lower(username) = lower($2) THEN 0
		       WHEN lower(username) LIKE lower($2) || '%' THEN 1
		       ELSE 2 END,
		  name
		LIMIT 20`, me, q)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "arama başarısız")
		return
	}
	defer rows.Close()

	out := []userResp{}
	for rows.Next() {
		var u userResp
		if rows.Scan(&u.ID, &u.Username, &u.Name, &u.About, &u.AvatarURL, &u.AvatarMediaID) == nil {
			out = append(out, u) // telefon numarasi DONMEZ (gizlilik)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /users/me/username — kullanici adi belirle/degistir
func (h *Handler) SetUsername(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req struct {
		Username string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	uname := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(req.Username, "@")))
	if !usernameRe.MatchString(uname) {
		writeErr(w, http.StatusBadRequest, "kullanıcı adı 3-20 karakter olmalı (harf, rakam, alt çizgi)")
		return
	}
	var taken bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE lower(username)=$1 AND id<>$2)`, uname, userID).Scan(&taken)
	if taken {
		writeErr(w, http.StatusConflict, "bu kullanıcı adı alınmış")
		return
	}
	if _, err := h.db.Exec(r.Context(),
		`UPDATE users SET username=$1 WHERE id=$2`, uname, userID); err != nil {
		writeErr(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	h.Me(w, r)
}

// GET /users/by-phone?phone=+90... — numaradan kullanici bul (sohbet baslatmak icin)
func (h *Handler) ByPhone(w http.ResponseWriter, r *http.Request) {
	phone := strings.TrimSpace(r.URL.Query().Get("phone"))
	if phone == "" {
		writeErr(w, http.StatusBadRequest, "phone parametresi gerekli")
		return
	}
	var u userResp
	err := h.db.QueryRow(r.Context(), `
		SELECT id, phone, name, about, avatar_url, avatar_media_id
		FROM users WHERE phone=$1 AND verified=true`, phone).
		Scan(&u.ID, &u.Phone, &u.Name, &u.About, &u.AvatarURL, &u.AvatarMediaID)
	if err == pgx.ErrNoRows {
		writeErr(w, http.StatusNotFound, "bu numarada kayıtlı kullanıcı yok")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatası")
		return
	}
	writeJSON(w, http.StatusOK, u)
}

// PATCH /users/me — profil guncelle (isim, hakkimda, avatar)
func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	// ⚠️⚠️ TURU 74 — `avatar_url` ISTEMCI ALANI KALDIRILDI (guvenlik).
	//
	// Eskiden istemci profil fotografi olarak HERHANGI BIR URL yazabiliyordu ve
	// sunucu DOGRULAMADAN kaydediyordu. `messages.media_url` acigiyla AYNI SINIF:
	//   · IZLEME PIKSELI — avatar sohbet listesinde HERKESE cizilir; saldirgan
	//     kendi sunucusunu adres verip mesajlastigi herkesin IP'sini/saatini toplar,
	//   · OLTALAMA — sahte "dogrulanmis" rozeti gorseli,
	//   · ic ag taramasi (sunucu tarafi onizleme eklenirse).
	// Avatar artik YALNIZCA bizim R2'mize yuklenmis, SAHIPLIGI DOGRULANMIS bir
	// medya kaydiyla degistirilebilir.
	// ⚠️ YAPMA: `avatar_url`u istege geri ekleme.
	// ⚠️ `users.avatar_url` SUTUNU DURUYOR (eski kayitlar + geriye donuk uyum) ama
	//    artik yalnizca SUNUCU yazar.
	var req struct {
		Name          *string `json:"name"`
		About         *string `json:"about"`
		AvatarMediaID *string `json:"avatar_media_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	if req.AvatarMediaID != nil && *req.AvatarMediaID != "" {
		// ⚠️ SAHIPLIK + DURUM kontrolu TEK sorguda: baskasinin medyasini avatar
		//    yapmak ya da dogrulanmamis ('beklemede') bir kaydi baglamak ENGELLENIR.
		tag, err := h.db.Exec(r.Context(), `
			UPDATE media_assets SET status='bagli', linked_at=now()
			 WHERE id=$1 AND owner_id=$2 AND kind='avatar'
			   AND status IN ('aktif','bagli')`, *req.AvatarMediaID, userID)
		if err != nil || tag.RowsAffected() == 0 {
			writeErr(w, http.StatusForbidden, "geçersiz profil fotoğrafı")
			return
		}
	}
	_, err := h.db.Exec(r.Context(), `
		UPDATE users SET
			name = COALESCE($1, name),
			about = COALESCE($2, about),
			avatar_media_id = COALESCE($3::uuid, avatar_media_id)
		WHERE id=$4`, req.Name, req.About, req.AvatarMediaID, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "güncellenemedi")
		return
	}
	h.Me(w, r)
}

// POST /users/me/fcm-token — cihaz push token kaydi
// POST /users/me/voip-token — iOS PushKit (VoIP) token'i.
// FCM token'indan AYRIDIR; kilit ekraninda arama caldirmak icin APNs'e dogrudan gonderilir.
func (h *Handler) SaveVoIPToken(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		writeErr(w, http.StatusBadRequest, "token gerekli")
		return
	}
	h.db.Exec(r.Context(), `DELETE FROM voip_tokens WHERE token=$1 AND user_id<>$2`,
		req.Token, userID)
	_, err := h.db.Exec(r.Context(), `
		INSERT INTO voip_tokens (user_id, token)
		VALUES ($1,$2)
		ON CONFLICT (user_id, token) DO UPDATE SET updated_at=now()`,
		userID, req.Token)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

func (h *Handler) SaveFCMToken(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req struct {
		Token    string `json:"token"`
		Platform string `json:"platform"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		writeErr(w, http.StatusBadRequest, "token gerekli")
		return
	}
	if req.Platform != "ios" {
		req.Platform = "android"
	}
	// Bu token BASKA bir kullaniciya bagliysa once onu kaldir — yoksa ayni cihazda
	// hesap degisince yeni kullanici oncekinin bildirimlerini/aramalarini alir.
	h.db.Exec(r.Context(), `DELETE FROM device_tokens WHERE token=$1 AND user_id<>$2`,
		req.Token, userID)
	_, err := h.db.Exec(r.Context(), `
		INSERT INTO device_tokens (user_id, token, platform)
		VALUES ($1,$2,$3)
		ON CONFLICT (user_id, token) DO UPDATE SET platform=$3, updated_at=now()`,
		userID, req.Token, req.Platform)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

// DELETE /users/me/fcm-token — cikis yaparken bu cihazin token'ini sil
func (h *Handler) DeleteFCMToken(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		writeErr(w, http.StatusBadRequest, "token gerekli")
		return
	}
	h.db.Exec(r.Context(), `DELETE FROM device_tokens WHERE user_id=$1 AND token=$2`,
		userID, req.Token)
	h.db.Exec(r.Context(), `DELETE FROM voip_tokens WHERE user_id=$1 AND token=$2`,
		userID, req.Token)
	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
