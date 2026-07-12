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
}

func NewHandler(db *pgxpool.Pool) *Handler {
	return &Handler{db: db}
}

type userResp struct {
	ID          string     `json:"id"`
	Phone       string     `json:"phone,omitempty"` // gizlilik: aramada donmez
	Username    string     `json:"username"`
	Name        string     `json:"name"`
	About       string     `json:"about"`
	AvatarURL   string     `json:"avatar_url"`
	CoinBalance int64      `json:"coin_balance,omitempty"`
	LastSeen    *time.Time `json:"last_seen,omitempty"`
}

// GET /users/me — kendi profilim (jeton bakiyesi dahil)
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var u userResp
	err := h.db.QueryRow(r.Context(), `
		SELECT id, phone, COALESCE(username,''), name, about, avatar_url, coin_balance, last_seen
		FROM users WHERE id=$1`, userID).
		Scan(&u.ID, &u.Phone, &u.Username, &u.Name, &u.About, &u.AvatarURL, &u.CoinBalance, &u.LastSeen)
	if err != nil {
		writeErr(w, http.StatusNotFound, "kullanici bulunamadi")
		return
	}
	writeJSON(w, http.StatusOK, u)
}

var usernameRe = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

// GET /users/search?q= — isim veya kullanici adiyla ara (telefon numarasi gerekmez)
func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	q := strings.TrimSpace(strings.TrimPrefix(r.URL.Query().Get("q"), "@"))
	if len(q) < 2 {
		writeErr(w, http.StatusBadRequest, "en az 2 karakter yazin")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, COALESCE(username,''), name, about, avatar_url
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
		writeErr(w, http.StatusInternalServerError, "arama basarisiz")
		return
	}
	defer rows.Close()

	out := []userResp{}
	for rows.Next() {
		var u userResp
		if rows.Scan(&u.ID, &u.Username, &u.Name, &u.About, &u.AvatarURL) == nil {
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
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	uname := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(req.Username, "@")))
	if !usernameRe.MatchString(uname) {
		writeErr(w, http.StatusBadRequest, "kullanici adi 3-20 karakter olmali (harf, rakam, alt cizgi)")
		return
	}
	var taken bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE lower(username)=$1 AND id<>$2)`, uname, userID).Scan(&taken)
	if taken {
		writeErr(w, http.StatusConflict, "bu kullanici adi alinmis")
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
		SELECT id, phone, name, about, avatar_url
		FROM users WHERE phone=$1 AND verified=true`, phone).
		Scan(&u.ID, &u.Phone, &u.Name, &u.About, &u.AvatarURL)
	if err == pgx.ErrNoRows {
		writeErr(w, http.StatusNotFound, "bu numarada kayitli kullanici yok")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	writeJSON(w, http.StatusOK, u)
}

// PATCH /users/me — profil guncelle (isim, hakkimda, avatar)
func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req struct {
		Name      *string `json:"name"`
		About     *string `json:"about"`
		AvatarURL *string `json:"avatar_url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	_, err := h.db.Exec(r.Context(), `
		UPDATE users SET
			name = COALESCE($1, name),
			about = COALESCE($2, about),
			avatar_url = COALESCE($3, avatar_url)
		WHERE id=$4`, req.Name, req.About, req.AvatarURL, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "guncellenemedi")
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

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
