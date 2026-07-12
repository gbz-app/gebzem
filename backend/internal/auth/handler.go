package auth

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"github.com/gbz-app/gebzem/backend/internal/config"
)

type Handler struct {
	db  *pgxpool.Pool
	cfg *config.Config
}

func NewHandler(db *pgxpool.Pool, cfg *config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

var phoneRe = regexp.MustCompile(`^\+[1-9]\d{9,14}$`)

type registerReq struct {
	Phone    string `json:"phone"`
	Password string `json:"password"`
	Name     string `json:"name"`
	Username string `json:"username"`
}

var usernameRe = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

// POST /auth/register — kayit baslat: kullanici olustur (verified=false) + OTP uret
func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	req.Phone = strings.TrimSpace(req.Phone)
	if !phoneRe.MatchString(req.Phone) {
		writeErr(w, http.StatusBadRequest, "telefon +90... formatinda olmali")
		return
	}
	if len(req.Password) < 6 {
		writeErr(w, http.StatusBadRequest, "sifre en az 6 karakter olmali")
		return
	}
	uname := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(req.Username, "@")))
	if !usernameRe.MatchString(uname) {
		writeErr(w, http.StatusBadRequest, "kullanici adi 3-20 karakter olmali (harf, rakam, alt cizgi)")
		return
	}

	var exists bool
	err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE phone=$1 AND verified=true)`, req.Phone).Scan(&exists)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	if exists {
		writeErr(w, http.StatusConflict, "bu numara zaten kayitli")
		return
	}

	// kullanici adi baskasinda mi?
	var taken bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE lower(username)=$1 AND phone<>$2)`, uname, req.Phone).Scan(&taken)
	if taken {
		writeErr(w, http.StatusConflict, "bu kullanici adi alinmis")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}

	// verified=false kullaniciyi olustur/guncelle (tekrar kayit denemesine izin ver)
	_, err = h.db.Exec(r.Context(), `
		INSERT INTO users (phone, password_hash, name, username)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (phone) DO UPDATE SET password_hash=$2, name=$3, username=$4`,
		req.Phone, string(hash), strings.TrimSpace(req.Name), uname)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "kullanici adi alinmis olabilir")
		return
	}

	otp, err := h.createOTP(r.Context(), req.Phone, "register")
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "otp uretilemedi")
		return
	}

	resp := map[string]any{"message": "otp gonderildi"}
	if h.cfg.DevMode {
		resp["dev_otp"] = otp // prototip: SMS yerine yanitta doner
	}
	writeJSON(w, http.StatusOK, resp)
}

type verifyReq struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

// POST /auth/verify — OTP dogrula, hesabi aktifle, token ver
func (h *Handler) Verify(w http.ResponseWriter, r *http.Request) {
	var req verifyReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	if !h.consumeOTP(r.Context(), req.Phone, req.Code, "register") {
		writeErr(w, http.StatusUnauthorized, "kod hatali veya suresi dolmus")
		return
	}

	var userID string
	err := h.db.QueryRow(r.Context(), `
		UPDATE users SET verified=true WHERE phone=$1 RETURNING id`, req.Phone).Scan(&userID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "kullanici bulunamadi")
		return
	}

	// Kayit bonusu jetonu ledger'a isle (bir kez)
	h.db.Exec(r.Context(), `
		INSERT INTO coin_ledger (user_id, amount, reason)
		SELECT $1, 100, 'signup_bonus'
		WHERE NOT EXISTS (SELECT 1 FROM coin_ledger WHERE user_id=$1 AND reason='signup_bonus')`, userID)

	token, err := GenerateToken(h.cfg.JWTSecret, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token, "user_id": userID})
}

type loginReq struct {
	Phone    string `json:"phone"`
	Password string `json:"password"`
}

// POST /auth/login
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	var userID, hash string
	var verified bool
	err := h.db.QueryRow(r.Context(),
		`SELECT id, password_hash, verified FROM users WHERE phone=$1`, strings.TrimSpace(req.Phone)).
		Scan(&userID, &hash, &verified)
	if err == pgx.ErrNoRows || (err == nil && bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil) {
		writeErr(w, http.StatusUnauthorized, "telefon veya sifre hatali")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	if !verified {
		writeErr(w, http.StatusForbidden, "hesap dogrulanmamis, kayit akisini tamamlayin")
		return
	}
	token, err := GenerateToken(h.cfg.JWTSecret, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token, "user_id": userID})
}

// POST /auth/forgot — sifre sifirlama OTP'si
func (h *Handler) Forgot(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone string `json:"phone"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	var exists bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE phone=$1 AND verified=true)`, req.Phone).Scan(&exists)
	// Numara kayitli degilse de ayni yanit doner (numara avlamayi engelle)
	resp := map[string]any{"message": "kayitliysa otp gonderildi"}
	if exists {
		otp, err := h.createOTP(r.Context(), req.Phone, "reset_password")
		if err == nil && h.cfg.DevMode {
			resp["dev_otp"] = otp
		}
	}
	writeJSON(w, http.StatusOK, resp)
}

// POST /auth/reset — OTP + yeni sifre
func (h *Handler) Reset(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone       string `json:"phone"`
		Code        string `json:"code"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	if len(req.NewPassword) < 6 {
		writeErr(w, http.StatusBadRequest, "sifre en az 6 karakter olmali")
		return
	}
	if !h.consumeOTP(r.Context(), req.Phone, req.Code, "reset_password") {
		writeErr(w, http.StatusUnauthorized, "kod hatali veya suresi dolmus")
		return
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	h.db.Exec(r.Context(), `UPDATE users SET password_hash=$1 WHERE phone=$2`, string(hash), req.Phone)
	writeJSON(w, http.StatusOK, map[string]any{"message": "sifre guncellendi"})
}

// --- yardimcilar ---

func (h *Handler) createOTP(ctx context.Context, phone, purpose string) (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	code := fmt.Sprintf("%06d", n.Int64())
	_, err = h.db.Exec(ctx, `
		INSERT INTO otp_codes (phone, code, purpose, expires_at)
		VALUES ($1, $2, $3, $4)`, phone, code, purpose, time.Now().Add(5*time.Minute))
	if err != nil {
		return "", err
	}
	// TODO: gercek SMS entegrasyonu (Firebase/Netgsm) — prototipte dev_otp yanitta donuyor
	return code, nil
}

func (h *Handler) consumeOTP(ctx context.Context, phone, code, purpose string) bool {
	tag, err := h.db.Exec(ctx, `
		UPDATE otp_codes SET used=true
		WHERE id = (
			SELECT id FROM otp_codes
			WHERE phone=$1 AND code=$2 AND purpose=$3 AND used=false AND expires_at > now()
			ORDER BY id DESC LIMIT 1
		)`, phone, code, purpose)
	return err == nil && tag.RowsAffected() == 1
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
