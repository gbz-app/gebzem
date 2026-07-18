// Package streams — CANLI YAYIN (prototip: SAF WebRTC, <=300 izleyici, HLS yok).
// oda-yayin-plani.md Bolum 2 + Baglayici Kararlar. internal/calls ve internal/rooms'a DOKUNMAZ.
// LiveKit oda oneki "stream_". Izleyici listesi/sayaci REDIS (DB satiri yok); yasam dongusu
// sinyalleri (viewers/paused/resumed/ended/gift/chat/hearts) LiveKit SendData'dan gider —
// izleyiciler zaten odada, WS hub'ina yuk bindirmez. TUM data sinyalleri SUNUCUDAN: istemci
// token'larinda canPublishData:false (yayinci dahil) -> sahte hediye/chat data'si IMKANSIZ.
package streams

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/livekit"
)

const tokenOmru = 8 * time.Hour

type Handler struct {
	db     *pgxpool.Pool
	rdb    *redis.Client
	lk     *livekit.Client
	lkURL  string
	key    string
	secret string
	maxIzleyici int
}

func NewHandler(db *pgxpool.Pool, rdb *redis.Client) *Handler {
	key := os.Getenv("LIVEKIT_API_KEY")
	secret := os.Getenv("LIVEKIT_API_SECRET")
	maxV := 300
	if v, err := strconv.Atoi(os.Getenv("STREAM_MAX_VIEWERS")); err == nil && v > 0 {
		maxV = v
	}
	return &Handler{
		db:     db,
		rdb:    rdb,
		lk:     livekit.NewClient(getEnv("LIVEKIT_API_URL", "http://167.233.229.88:7880"), key, secret),
		lkURL:  getEnv("LIVEKIT_URL", "wss://rtc.gebzem.app"),
		key:    key,
		secret: secret,
		maxIzleyici: maxV,
	}
}

func (h *Handler) Enabled() bool { return h.key != "" && h.secret != "" }

// Yayinci token'i: kamera+mikrofon yayinlar; DATA YAYINLAYAMAZ (tum sinyaller sunucudan).
func (h *Handler) yayinciToken(room, identity, name string) (string, error) {
	return livekit.AccessToken(h.key, h.secret, identity, name, map[string]any{
		"room": room, "roomJoin": true, "canSubscribe": true,
		"canPublish": true, "canPublishData": false,
		"canPublishSources": []string{"camera", "microphone"},
	}, tokenOmru)
}

// Izleyici token'i: SADECE izler; hidden (300 kisinin gir/cikisi sinyal firtinasi uretmesin).
func (h *Handler) izleyiciToken(room, identity, name string) (string, error) {
	return livekit.AccessToken(h.key, h.secret, identity, name, map[string]any{
		"room": room, "roomJoin": true, "canSubscribe": true,
		"canPublish": false, "canPublishData": false, "hidden": true,
	}, tokenOmru)
}

func (h *Handler) audit(ctx context.Context, streamID, userID, action, ip string) {
	h.db.Exec(ctx, `INSERT INTO stream_audit (stream_id, user_id, action, ip) VALUES ($1, NULLIF($2,''), $3, NULLIF($4,''))`,
		streamID, userID, action, ip)
}

// data — odaya sunucudan sinyal (RELIABLE). Hata olumcul degil, loglanir.
func (h *Handler) data(ctx context.Context, streamID string, v map[string]any) {
	b, _ := json.Marshal(v)
	if err := h.lk.SendData(ctx, "stream_"+streamID, b, "meta"); err != nil {
		log.Printf("yayin data: %v", err)
	}
}

func (h *Handler) izleyiciSayisi(ctx context.Context, streamID string) int {
	n, _ := h.rdb.ZCard(ctx, "stream:"+streamID+":viewers").Result()
	return int(n)
}

// POST /streams {title, video} — yayin baslat (yayinci token'i doner)
func (h *Handler) Start(w http.ResponseWriter, r *http.Request) {
	if !h.Enabled() {
		writeErr(w, http.StatusServiceUnavailable, "yayin servisi kapali")
		return
	}
	userID := auth.UserID(r.Context())
	var req struct {
		Title string `json:"title"`
		Video *bool  `json:"video"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	req.Title = strings.TrimSpace(req.Title)
	if req.Title == "" {
		req.Title = "Canlı yayın"
	}
	if len([]rune(req.Title)) > 80 {
		req.Title = string([]rune(req.Title)[:80])
	}
	tip := "video"
	if req.Video != nil && !*req.Video {
		tip = "audio"
	}

	var streamID string
	err := h.db.QueryRow(r.Context(),
		`INSERT INTO streams (broadcaster_id, title, type, status) VALUES ($1, $2, $3, 'live') RETURNING id`,
		userID, req.Title, tip).Scan(&streamID)
	if err != nil {
		// uq_streams_broadcaster_live: ayni yayincinin ikinci canli yayini
		writeErr(w, http.StatusConflict, "zaten canli bir yayininiz var")
		return
	}

	roomName := "stream_" + streamID
	// CreateRoom SART (Baglayici Karar 2 / global max_participants:32 tuzagi):
	// izleyici tavani + yayinci payi. empty_timeout 300: yayinci kisa kopmada oda olmesin.
	if err := h.lk.CreateRoom(r.Context(), roomName, h.maxIzleyici+10, 300); err != nil {
		log.Printf("yayin livekit create: %v", err)
		h.db.Exec(r.Context(), `UPDATE streams SET status='ended', ended_at=now() WHERE id=$1`, streamID)
		writeErr(w, http.StatusInternalServerError, "yayin baslatilamadi")
		return
	}
	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	tok, err := h.yayinciToken(roomName, userID, name)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	// Yayinci nabzi: sweeper 45 sn nabizsiz kalirsa 'paused' yapar
	h.rdb.Set(r.Context(), "stream:"+streamID+":pub", "1", 45*time.Second)
	h.audit(r.Context(), streamID, userID, "start", clientIP(r))
	log.Printf("yayin basladi: %s yayinci=%s tip=%s", kisaID(streamID), kisaID(userID), tip)

	writeJSON(w, http.StatusCreated, map[string]any{
		"stream_id": streamID, "room": roomName, "url": h.lkURL, "token": tok,
		"title": req.Title, "type": tip,
	})
}

// GET /streams — kesfet (canli + durakli yayinlar)
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.Query(r.Context(), `
		SELECT s.id, s.title, s.type, s.status, s.started_at, s.gift_coins,
		       u.id, u.name, COALESCE(u.avatar_url,'')
		FROM streams s JOIN users u ON u.id = s.broadcaster_id
		WHERE s.status IN ('live','paused')
		ORDER BY s.started_at DESC
		LIMIT 50`)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "liste alinamadi")
		return
	}
	defer rows.Close()
	type yayin struct {
		ID        string    `json:"id"`
		Title     string    `json:"title"`
		Type      string    `json:"type"`
		Status    string    `json:"status"`
		StartedAt time.Time `json:"started_at"`
		GiftCoins int64     `json:"gift_coins"`
		BID       string    `json:"broadcaster_id"`
		BName     string    `json:"broadcaster_name"`
		BAvatar   string    `json:"broadcaster_avatar"`
		Viewers   int       `json:"viewer_count"`
	}
	list := []yayin{}
	for rows.Next() {
		var y yayin
		if rows.Scan(&y.ID, &y.Title, &y.Type, &y.Status, &y.StartedAt, &y.GiftCoins,
			&y.BID, &y.BName, &y.BAvatar) == nil {
			list = append(list, y)
		}
	}
	// Izleyici sayilari Redis'ten (pipeline — N yayin tek turda)
	if len(list) > 0 {
		pipe := h.rdb.Pipeline()
		cmds := make([]*redis.IntCmd, len(list))
		for i, y := range list {
			cmds[i] = pipe.ZCard(r.Context(), "stream:"+y.ID+":viewers")
		}
		pipe.Exec(r.Context())
		for i := range list {
			list[i].Viewers = int(cmds[i].Val())
		}
	}
	writeJSON(w, http.StatusOK, list)
}

// GET /streams/gifts — hediye katalogu (fiyat SUNUCUDA — istemcide sabit tutulmaz)
func (h *Handler) Gifts(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, katalogListesi())
}

// POST /streams/{id}/watch — izleyici olarak katil (subscribe-only token)
func (h *Handler) Watch(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")

	var status, title, tip, bID, bName string
	err := h.db.QueryRow(r.Context(), `
		SELECT s.status, s.title, s.type, u.id, u.name
		FROM streams s JOIN users u ON u.id=s.broadcaster_id
		WHERE s.id=$1`, streamID).Scan(&status, &title, &tip, &bID, &bName)
	if err != nil || (status != "live" && status != "paused") {
		writeErr(w, http.StatusGone, "yayin bulunamadi veya bitti")
		return
	}
	if bID == userID {
		writeErr(w, http.StatusBadRequest, "kendi yayininizi izleyemezsiniz")
		return
	}
	// Engel (cift yonlu, calls deseni) + yayinci kick bani
	var blocked bool
	h.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		bID, userID).Scan(&blocked)
	if blocked {
		writeErr(w, http.StatusForbidden, "bu yayini izleyemezsiniz")
		return
	}
	banli, _ := h.rdb.SIsMember(r.Context(), "stream:"+streamID+":banned", userID).Result()
	if banli {
		writeErr(w, http.StatusForbidden, "yayindan cikarildiniz")
		return
	}
	// Kapasite (cx33 NIC muhafizi; LiveKit max_participants ikinci savunma hatti)
	if h.izleyiciSayisi(r.Context(), streamID) >= h.maxIzleyici {
		writeErr(w, http.StatusTooManyRequests, "yayin dolu")
		return
	}
	h.rdb.ZAdd(r.Context(), "stream:"+streamID+":viewers",
		redis.Z{Score: float64(time.Now().Unix()), Member: userID})

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	roomName := "stream_" + streamID
	tok, err := h.izleyiciToken(roomName, userID, name)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	h.audit(r.Context(), streamID, userID, "watch", clientIP(r))
	writeJSON(w, http.StatusOK, map[string]any{
		"stream_id": streamID, "room": roomName, "url": h.lkURL, "token": tok,
		"title": title, "type": tip, "status": status,
		"broadcaster_id": bID, "broadcaster_name": bName,
		"viewer_count": h.izleyiciSayisi(r.Context(), streamID),
	})
}

// POST /streams/{id}/heartbeat — izleyici: ZADD tazele; yayinci: pub nabzi (15 sn'de bir)
func (h *Handler) Heartbeat(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var bID string
	if h.db.QueryRow(r.Context(), `SELECT broadcaster_id FROM streams WHERE id=$1 AND status IN ('live','paused')`,
		streamID).Scan(&bID) != nil {
		writeErr(w, http.StatusGone, "yayin bitti")
		return
	}
	if userID == bID {
		h.rdb.Set(r.Context(), "stream:"+streamID+":pub", "1", 45*time.Second)
	} else {
		// DUZ ZADD (dogrulama bulgusu): 45sn+ askidan (kilit/ag) donen mesru izleyici
		// sweeper tarafindan silinmis olabilir — ZAddXX onu SONSUZA disarida birakiyordu
		// (sayacta gorunmez + chat 403). Kick hayaleti banned kontrolatiyle onlenir;
		// leave sonrasi tek gecikmis nabiz zararsiz (ekran kapali, yenisi gelmez, 45sn'de duser).
		if banli, _ := h.rdb.SIsMember(r.Context(), "stream:"+streamID+":banned", userID).Result(); banli {
			writeErr(w, http.StatusForbidden, "yayindan cikarildiniz")
			return
		}
		h.rdb.ZAdd(r.Context(), "stream:"+streamID+":viewers",
			redis.Z{Score: float64(time.Now().Unix()), Member: userID})
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/leave — izleyici ayrildi (nazik cikis; kaba cikisi sweeper yakalar)
func (h *Handler) Leave(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	h.rdb.ZRem(r.Context(), "stream:"+streamID+":viewers", userID)
	h.audit(r.Context(), streamID, userID, "leave", "")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/end — yayini bitir (yalniz yayinci; admin ucu ayrica)
func (h *Handler) End(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var sahibi bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM streams WHERE id=$1 AND broadcaster_id=$2)`, streamID, userID).Scan(&sahibi)
	if !sahibi {
		writeErr(w, http.StatusForbidden, "yalniz yayinci")
		return
	}
	h.endStream(r.Context(), streamID, "end")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ended"})
}

// endStream — End + sweeper + admin ortak yolu. Atomik; idempotent.
func (h *Handler) endStream(ctx context.Context, streamID, neden string) {
	tag, err := h.db.Exec(ctx,
		`UPDATE streams SET status='ended', ended_at=now() WHERE id=$1 AND status IN ('live','paused')`, streamID)
	if err != nil || tag.RowsAffected() == 0 {
		return
	}
	h.data(ctx, streamID, map[string]any{"t": "stream.ended"})
	if err := h.lk.DeleteRoom(ctx, "stream_"+streamID); err != nil {
		log.Printf("yayin delete: %v", err)
	}
	h.rdb.Del(ctx, "stream:"+streamID+":viewers", "stream:"+streamID+":pub",
		"stream:"+streamID+":banned", "stream:"+streamID+":hearts", "stream:"+streamID+":lastn")
	h.audit(ctx, streamID, "", neden, "")
	log.Printf("yayin bitti: %s (%s)", kisaID(streamID), neden)
}

// POST /streams/{id}/chat {text} — chat REST -> sunucu SendData (Baglayici Karar 4:
// istemci data yayini KAPALI; sahte mesaj/sel onlenir, throttle sunucuda)
func (h *Handler) Chat(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var req struct {
		Text string `json:"text"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	req.Text = strings.TrimSpace(req.Text)
	if req.Text == "" {
		writeErr(w, http.StatusBadRequest, "bos mesaj")
		return
	}
	if len([]rune(req.Text)) > 200 {
		req.Text = string([]rune(req.Text)[:200])
	}
	// Uyelik: izleyici (ZSCORE) veya yayinci
	var bID string
	if h.db.QueryRow(r.Context(), `SELECT broadcaster_id FROM streams WHERE id=$1 AND status IN ('live','paused')`,
		streamID).Scan(&bID) != nil {
		writeErr(w, http.StatusGone, "yayin bitti")
		return
	}
	if userID != bID {
		if _, err := h.rdb.ZScore(r.Context(), "stream:"+streamID+":viewers", userID).Result(); err != nil {
			writeErr(w, http.StatusForbidden, "yayinda degilsiniz")
			return
		}
	}
	// Throttle: kisi basi 2 sn'de 1 mesaj
	ok, _ := h.rdb.SetNX(r.Context(), "stream:"+streamID+":chat:"+userID, "1", 2*time.Second).Result()
	if !ok {
		writeErr(w, http.StatusTooManyRequests, "cok hizli yaziyorsunuz")
		return
	}
	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	h.data(r.Context(), streamID, map[string]any{
		"t": "chat", "from": name, "from_id": userID, "text": req.Text,
	})
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/heart — kalp reaksiyonu. Sunucuda TOPLANIR (INCR), sweeper 5 sn'de bir
// toplu yayinlar (300 izleyici x anlik SendData seli olmasin). Gonderen kendi kalbini
// istemcide aninda gorur.
func (h *Handler) Heart(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	// Yayin gecerli mi (dogrulama bulgusu: bitmis/gecersiz yayina kalp TTL'siz artik anahtar birakiyordu)
	var bir int
	if h.db.QueryRow(r.Context(),
		`SELECT 1 FROM streams WHERE id=$1 AND status IN ('live','paused')`, streamID).Scan(&bir) != nil {
		writeErr(w, http.StatusGone, "yayin bitti")
		return
	}
	// kisi basi saniyede 1
	ok, _ := h.rdb.SetNX(r.Context(), "stream:"+streamID+":heart:"+userID, "1", time.Second).Result()
	if !ok {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"}) // sessiz yut
		return
	}
	pipe := h.rdb.Pipeline()
	pipe.Incr(r.Context(), "stream:"+streamID+":hearts")
	pipe.Expire(r.Context(), "stream:"+streamID+":hearts", time.Hour) // artik anahtar kalmasin
	pipe.Exec(r.Context())
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/report {reason} — rapor (ayni kullanici ayni yayina 1 kez)
func (h *Handler) Report(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var req struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if len([]rune(req.Reason)) > 300 {
		req.Reason = string([]rune(req.Reason)[:300])
	}
	_, err := h.db.Exec(r.Context(), `
		INSERT INTO stream_reports (stream_id, reporter_id, reason) VALUES ($1,$2,$3)
		ON CONFLICT (stream_id, reporter_id) DO NOTHING`, streamID, userID, req.Reason)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "rapor alinamadi")
		return
	}
	log.Printf("YAYIN-RAPOR stream=%s raporlayan=%s sebep=%q", kisaID(streamID), kisaID(userID), req.Reason)
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/kick {user_id} — yayinci izleyiciyi atar + kalici ban (watch 403)
func (h *Handler) Kick(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var bID string
	if h.db.QueryRow(r.Context(), `SELECT broadcaster_id FROM streams WHERE id=$1 AND status IN ('live','paused')`,
		streamID).Scan(&bID) != nil || bID != userID {
		writeErr(w, http.StatusForbidden, "yalniz yayinci")
		return
	}
	var req struct {
		UserID string `json:"user_id"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if req.UserID == "" || req.UserID == userID {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	h.rdb.SAdd(r.Context(), "stream:"+streamID+":banned", req.UserID)
	h.rdb.ZRem(r.Context(), "stream:"+streamID+":viewers", req.UserID)
	if err := h.lk.RemoveParticipant(r.Context(), "stream_"+streamID, req.UserID); err != nil {
		log.Printf("yayin kick: %v", err) // ban Redis'te — watch yine 403
	}
	h.audit(r.Context(), streamID, req.UserID, "kick", "")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ---- admin (calls admin key deseni — paket private oldugu icin kopya) ----

func adminOK(r *http.Request) bool {
	k := os.Getenv("ADMIN_KEY")
	if k == "" {
		k = "gbz-izle-2026"
	}
	return r.URL.Query().Get("key") == k
}

// GET /admin/streams — canli yayinlar (izleyici + jeton)
func (h *Handler) AdminList(w http.ResponseWriter, r *http.Request) {
	if !adminOK(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	h.List(w, r)
}

// POST /admin/streams/{id}/end — 5651: yayini uzaktan bitir
func (h *Handler) AdminEnd(w http.ResponseWriter, r *http.Request) {
	if !adminOK(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	streamID := chi.URLParam(r, "id")
	log.Printf("YAYIN-ADMIN-END stream=%s", kisaID(streamID))
	h.endStream(r.Context(), streamID, "admin_end")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ended"})
}

// ---- yardimcilar (paket-ici kopyalar; calls/rooms'takiler private) ----

func clientIP(r *http.Request) string { return r.RemoteAddr }

func kisaID(s string) string {
	if len(s) > 8 {
		return s[:8]
	}
	return s
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
	writeJSON(w, status, map[string]string{"error": msg})
}
