package calls

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/push"
)

// Sesli/goruntulu arama — LiveKit (kendi sunucumuzda).
// Akis: arayan /calls baslatir -> aliciya WS "call.incoming" + push gider
//       alici kabul edince ikisi de LiveKit odasina token'la baglanir.

type Handler struct {
	db   *pgxpool.Pool
	hub  *chat.Hub
	push *push.Sender

	lkURL    string // istemcinin baglanacagi adres (wss://rtc.gebzem.app)
	apiKey   string
	apiSecret string
}

func NewHandler(db *pgxpool.Pool, hub *chat.Hub, pushSender *push.Sender) *Handler {
	return &Handler{
		db:        db,
		hub:       hub,
		push:      pushSender,
		lkURL:     getEnv("LIVEKIT_URL", "wss://rtc.gebzem.app"),
		apiKey:    os.Getenv("LIVEKIT_API_KEY"),
		apiSecret: os.Getenv("LIVEKIT_API_SECRET"),
	}
}

func (h *Handler) Enabled() bool { return h.apiKey != "" && h.apiSecret != "" }

// LiveKit erisim token'i uret (JWT — LiveKit'in kendi formati)
func (h *Handler) token(roomName, identity, name string) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":  h.apiKey,
		"sub":  identity,
		"name": name,
		"nbf":  now.Add(-10 * time.Second).Unix(),
		"exp":  now.Add(4 * time.Hour).Unix(),
		"video": map[string]any{
			"room":         roomName,
			"roomJoin":     true,
			"canPublish":   true,
			"canSubscribe": true,
			"canPublishData": true,
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(h.apiSecret))
}

type startReq struct {
	CalleeID string `json:"callee_id"`
	Video    bool   `json:"video"`
}

// POST /calls — arama baslat (davet gonderir, arayana token doner)
func (h *Handler) Start(w http.ResponseWriter, r *http.Request) {
	if !h.Enabled() {
		writeErr(w, http.StatusServiceUnavailable, "arama servisi kapali")
		return
	}
	callerID := auth.UserID(r.Context())

	var req startReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.CalleeID == "" {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	if req.CalleeID == callerID {
		writeErr(w, http.StatusBadRequest, "kendinizi arayamazsiniz")
		return
	}

	// Engel kontrolu (cift yonlu)
	var blocked bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		callerID, req.CalleeID).Scan(&blocked)
	if blocked {
		writeErr(w, http.StatusForbidden, "bu kullanici aranamiyor")
		return
	}

	// Arayan bilgisi
	var callerName, callerAvatar string
	h.db.QueryRow(r.Context(),
		`SELECT name, avatar_url FROM users WHERE id=$1`, callerID).Scan(&callerName, &callerAvatar)

	// Arama kaydi
	var callID string
	callType := "audio"
	if req.Video {
		callType = "video"
	}
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO calls (caller_id, callee_id, type, status)
		VALUES ($1,$2,$3,'ringing') RETURNING id`,
		callerID, req.CalleeID, callType).Scan(&callID)
	if err != nil {
		log.Printf("arama kaydi: %v", err)
		writeErr(w, http.StatusInternalServerError, "arama baslatilamadi")
		return
	}

	roomName := "call_" + callID
	tok, err := h.token(roomName, callerID, callerName)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}

	// Aliciya canli davet (WebSocket) + push (uygulama kapaliysa)
	payload, _ := json.Marshal(map[string]any{
		"call_id":       callID,
		"room":          roomName,
		"type":          callType,
		"caller_id":     callerID,
		"caller_name":   callerName,
		"caller_avatar": callerAvatar,
	})
	h.hub.Publish(r.Context(), &chat.Event{
		Type:    "call.incoming",
		Payload: payload,
		To:      []string{req.CalleeID},
	})
	if h.push != nil {
		title := callerName
		body := "📞 Sesli arama"
		if req.Video {
			body = "📹 Goruntulu arama"
		}
		go h.push.NotifyUsers([]string{req.CalleeID}, title, body, "")
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"call_id": callID,
		"room":    roomName,
		"url":     h.lkURL,
		"token":   tok,
		"type":    callType,
	})
}

// POST /calls/{id}/answer — aramayi kabul et (aliciya token doner)
func (h *Handler) Answer(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")

	var callerID, callType, status string
	err := h.db.QueryRow(r.Context(), `
		SELECT caller_id, type, status FROM calls WHERE id=$1 AND callee_id=$2`,
		callID, userID).Scan(&callerID, &callType, &status)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}
	if status != "ringing" {
		writeErr(w, http.StatusConflict, "arama artik gecerli degil")
		return
	}

	h.db.Exec(r.Context(),
		`UPDATE calls SET status='active', answered_at=now() WHERE id=$1`, callID)

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)

	roomName := "call_" + callID
	tok, err := h.token(roomName, userID, name)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}

	// Arayana "kabul edildi" bildir
	payload, _ := json.Marshal(map[string]string{"call_id": callID})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.answered", Payload: payload, To: []string{callerID},
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"call_id": callID,
		"room":    roomName,
		"url":     h.lkURL,
		"token":   tok,
		"type":    callType,
	})
}

// POST /calls/{id}/end — aramayi bitir/reddet (iki taraf da cagirabilir)
func (h *Handler) End(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")

	var callerID, calleeID, status string
	err := h.db.QueryRow(r.Context(), `
		SELECT caller_id, callee_id, status FROM calls
		WHERE id=$1 AND (caller_id=$2 OR callee_id=$2)`, callID, userID).
		Scan(&callerID, &calleeID, &status)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}

	// Cevaplanmadan kapandiysa: cevapsiz/reddedildi
	newStatus := "ended"
	if status == "ringing" {
		if userID == calleeID {
			newStatus = "rejected"
		} else {
			newStatus = "missed"
		}
	}
	h.db.Exec(r.Context(),
		`UPDATE calls SET status=$1, ended_at=now() WHERE id=$2`, newStatus, callID)

	// Diger tarafa bildir
	other := callerID
	if userID == callerID {
		other = calleeID
	}
	payload, _ := json.Marshal(map[string]string{"call_id": callID, "status": newStatus})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.ended", Payload: payload, To: []string{other},
	})

	writeJSON(w, http.StatusOK, map[string]string{"status": newStatus})
}

// GET /calls — arama gecmisi
func (h *Handler) History(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT c.id, c.type, c.status, c.created_at,
		       c.caller_id = $1 AS outgoing,
		       u.id, u.name, COALESCE(u.username,''), u.avatar_url
		FROM calls c
		JOIN users u ON u.id = CASE WHEN c.caller_id=$1 THEN c.callee_id ELSE c.caller_id END
		WHERE c.caller_id=$1 OR c.callee_id=$1
		ORDER BY c.created_at DESC LIMIT 50`, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	defer rows.Close()

	type item struct {
		ID        string    `json:"id"`
		Type      string    `json:"type"`
		Status    string    `json:"status"`
		CreatedAt time.Time `json:"created_at"`
		Outgoing  bool      `json:"outgoing"`
		PeerID    string    `json:"peer_id"`
		PeerName  string    `json:"peer_name"`
		PeerUser  string    `json:"peer_username"`
		PeerPhoto string    `json:"peer_avatar"`
	}
	out := []item{}
	for rows.Next() {
		var it item
		if rows.Scan(&it.ID, &it.Type, &it.Status, &it.CreatedAt, &it.Outgoing,
			&it.PeerID, &it.PeerName, &it.PeerUser, &it.PeerPhoto) == nil {
			out = append(out, it)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

func getEnv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": fmt.Sprint(msg)})
}
