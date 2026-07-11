package users

import (
	"encoding/json"
	"net/http"
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
	Phone       string     `json:"phone"`
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
		SELECT id, phone, name, about, avatar_url, coin_balance, last_seen
		FROM users WHERE id=$1`, userID).
		Scan(&u.ID, &u.Phone, &u.Name, &u.About, &u.AvatarURL, &u.CoinBalance, &u.LastSeen)
	if err != nil {
		writeErr(w, http.StatusNotFound, "kullanici bulunamadi")
		return
	}
	writeJSON(w, http.StatusOK, u)
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
