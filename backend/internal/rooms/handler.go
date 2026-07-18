// Package rooms — SPACES (sesli oda): host + konusmacilar + kalabalik dinleyici + el kaldirma.
// oda-yayin-plani.md Bolum 1. IZOLASYON: internal/calls'a ve calls tablolarina DOKUNMAZ.
// In-app ozellik: CallKit/VoIP push YOK, zil YOK. LiveKit oda oneki "oda_" (log filtresi
// "call_" ile karismaz). Rol kaynagi DB; LiveKit izinleri UpdateParticipant ile senkron tutulur.
package rooms

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/livekit"
)

const (
	maxDinleyici  = 500 // cx33 ust sinir (yol haritasi: tek Space ~200-500)
	maxKonusmaci  = 10  // host dahil (SFU yuku konusmaci sayisiyla buyur)
	odaKapasitesi = 520 // LiveKit CreateRoom override (global max_participants:32 tavanini ezer)
	tokenOmru     = 8 * time.Hour
)

type Handler struct {
	db     *pgxpool.Pool
	hub    *chat.Hub
	lk     *livekit.Client
	lkURL  string
	key    string
	secret string
}

func NewHandler(db *pgxpool.Pool, hub *chat.Hub) *Handler {
	key := os.Getenv("LIVEKIT_API_KEY")
	secret := os.Getenv("LIVEKIT_API_SECRET")
	apiURL := getEnv("LIVEKIT_API_URL", "http://167.233.229.88:7880") // twirp (dogrudan, CF'siz)
	return &Handler{
		db:     db,
		hub:    hub,
		lk:     livekit.NewClient(apiURL, key, secret),
		lkURL:  getEnv("LIVEKIT_URL", "wss://rtc.gebzem.app"),
		key:    key,
		secret: secret,
	}
}

func (h *Handler) Enabled() bool { return h.key != "" && h.secret != "" }

// Rol -> istemci token grant'i. Dinleyici: canPublish:false (uplink yok — SFU yuku sifir),
// canPublishData:false (500 kisilik odada data-spam kapisi kapali; el kaldirma REST'ten).
// Konusmaci/host: yalniz mikrofon ("microphone" — kucuk harf, grant formati).
func (h *Handler) clientToken(room, identity, name, role string) (string, error) {
	video := map[string]any{"room": room, "roomJoin": true, "canSubscribe": true}
	if role == "host" || role == "speaker" {
		video["canPublish"] = true
		video["canPublishData"] = true
		video["canPublishSources"] = []string{"microphone"}
	} else {
		video["canPublish"] = false
		video["canPublishData"] = false
	}
	return livekit.AccessToken(h.key, h.secret, identity, name, video, tokenOmru)
}

func (h *Handler) audit(ctx context.Context, roomID, userID, action, ip string) {
	h.db.Exec(ctx, `INSERT INTO room_audit (room_id, user_id, action, ip) VALUES ($1, NULLIF($2,''), $3, NULLIF($4,''))`,
		roomID, userID, action, ip)
}

// katilimcilar — hedef listesi. kim: "herkes" | "yonetim" (host+speaker) | "host"
func (h *Handler) katilimcilar(ctx context.Context, roomID, kim string) []string {
	q := `SELECT user_id FROM room_participants WHERE room_id=$1 AND status='joined'`
	switch kim {
	case "yonetim":
		q += ` AND role IN ('host','speaker')`
	case "host":
		q += ` AND role='host'`
	}
	rows, err := h.db.Query(ctx, q, roomID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	return ids
}

// yayinla — WS olayi (chat hub / Redis uzerinden; hub'a dokunulmaz, hazir altyapi).
// FAN-OUT KURALI (Baglayici Karar 8): speaker/host olaylari HERKESE; dinleyici join/left
// yalniz yonetime (500 kisiye her giris/cikista yayin hub'i bogar; dinleyici sayisi
// olaylarin listener_count alaninda gider).
func (h *Handler) yayinla(ctx context.Context, tip string, payload map[string]any, hedef []string) {
	if len(hedef) == 0 {
		return
	}
	b, _ := json.Marshal(payload)
	h.hub.Publish(ctx, &chat.Event{Type: tip, Payload: b, To: hedef})
}

func (h *Handler) dinleyiciSayisi(ctx context.Context, roomID string) int {
	var n int
	h.db.QueryRow(ctx,
		`SELECT count(*) FROM room_participants WHERE room_id=$1 AND status='joined' AND role='listener'`,
		roomID).Scan(&n)
	return n
}

// POST /rooms {title} — oda ac. Host aninda joined; LiveKit odasi CreateRoom ile
// ODA-BASI kapasite override'iyla ONCEDEN yaratilir (TUZAK: global max_participants:32).
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	if !h.Enabled() {
		writeErr(w, http.StatusServiceUnavailable, "oda servisi kapali")
		return
	}
	userID := auth.UserID(r.Context())
	var req struct {
		Title string `json:"title"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	req.Title = strings.TrimSpace(req.Title)
	if req.Title == "" {
		writeErr(w, http.StatusBadRequest, "oda basligi gerekli")
		return
	}
	if len([]rune(req.Title)) > 80 {
		req.Title = string([]rune(req.Title)[:80])
	}

	// Ayni host'un ikinci canli odasi olamaz (zombi/cift oda muhafizi)
	var acikOdaVar bool
	h.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM rooms WHERE host_id=$1 AND status='live')`, userID).Scan(&acikOdaVar)
	if acikOdaVar {
		writeErr(w, http.StatusConflict, "zaten acik bir odaniz var")
		return
	}

	var roomID string
	if err := h.db.QueryRow(r.Context(),
		`INSERT INTO rooms (host_id, title, status) VALUES ($1, $2, 'live') RETURNING id`,
		userID, req.Title).Scan(&roomID); err != nil {
		log.Printf("oda kaydi: %v", err)
		writeErr(w, http.StatusInternalServerError, "oda acilamadi")
		return
	}
	h.db.Exec(r.Context(),
		`INSERT INTO room_participants (room_id, user_id, role, status) VALUES ($1, $2, 'host', 'joined')`,
		roomID, userID)

	roomName := "oda_" + roomID
	// Kapasite override SART — basarisizsa odayi geri al (32 tavanli sakat oda dogurma)
	if err := h.lk.CreateRoom(r.Context(), roomName, odaKapasitesi, 300); err != nil {
		log.Printf("oda livekit create: %v", err)
		h.db.Exec(r.Context(), `UPDATE rooms SET status='ended', ended_at=now() WHERE id=$1`, roomID)
		writeErr(w, http.StatusInternalServerError, "oda acilamadi")
		return
	}

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	tok, err := h.clientToken(roomName, userID, name, "host")
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	h.audit(r.Context(), roomID, userID, "create", clientIP(r))
	log.Printf("oda acildi: %s host=%s baslik=%q", kisaID(roomID), kisaID(userID), req.Title)

	writeJSON(w, http.StatusCreated, map[string]any{
		"room_id": roomID, "room": roomName, "url": h.lkURL, "token": tok,
		"title": req.Title, "role": "host", "host_id": userID,
	})
}

// GET /rooms — kesfet listesi (canli odalar, en yeni ustte)
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.Query(r.Context(), `
		SELECT r.id, r.title, r.created_at, u.id, u.name, COALESCE(u.avatar_url,''),
		       count(*) FILTER (WHERE p.status='joined' AND p.role IN ('host','speaker')),
		       count(*) FILTER (WHERE p.status='joined' AND p.role='listener')
		FROM rooms r
		JOIN users u ON u.id = r.host_id
		LEFT JOIN room_participants p ON p.room_id = r.id
		WHERE r.status='live'
		GROUP BY r.id, u.id
		ORDER BY r.created_at DESC
		LIMIT 50`)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "liste alinamadi")
		return
	}
	defer rows.Close()
	type oda struct {
		ID         string    `json:"id"`
		Title      string    `json:"title"`
		CreatedAt  time.Time `json:"created_at"`
		HostID     string    `json:"host_id"`
		HostName   string    `json:"host_name"`
		HostAvatar string    `json:"host_avatar"`
		Speakers   int       `json:"speaker_count"`
		Listeners  int       `json:"listener_count"`
	}
	list := []oda{}
	for rows.Next() {
		var o oda
		if rows.Scan(&o.ID, &o.Title, &o.CreatedAt, &o.HostID, &o.HostName, &o.HostAvatar,
			&o.Speakers, &o.Listeners) == nil {
			list = append(list, o)
		}
	}
	writeJSON(w, http.StatusOK, list)
}

// GET /rooms/{id} — oda detayi: konusmacilar (herkese) + eli kalkik dinleyiciler (yalniz host).
func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")

	var title, status, hostID string
	if err := h.db.QueryRow(r.Context(),
		`SELECT title, status, host_id FROM rooms WHERE id=$1`, roomID).Scan(&title, &status, &hostID); err != nil {
		writeErr(w, http.StatusNotFound, "oda bulunamadi")
		return
	}

	type kisi struct {
		UserID   string `json:"user_id"`
		Name     string `json:"name"`
		Avatar   string `json:"avatar"`
		Role     string `json:"role"`
		HandUp   bool   `json:"hand_up"`
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT p.user_id, u.name, COALESCE(u.avatar_url,''), p.role, p.hand_raised_at IS NOT NULL
		FROM room_participants p JOIN users u ON u.id=p.user_id
		WHERE p.room_id=$1 AND p.status='joined'
		ORDER BY CASE p.role WHEN 'host' THEN 0 WHEN 'speaker' THEN 1 ELSE 2 END, p.joined_at`,
		roomID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "detay alinamadi")
		return
	}
	defer rows.Close()
	speakers := []kisi{}
	eller := []kisi{}
	dinleyici := 0
	for rows.Next() {
		var k kisi
		if rows.Scan(&k.UserID, &k.Name, &k.Avatar, &k.Role, &k.HandUp) != nil {
			continue
		}
		if k.Role == "listener" {
			dinleyici++
			if k.HandUp && userID == hostID {
				eller = append(eller, k) // el listesi YALNIZ host'a
			}
			continue
		}
		speakers = append(speakers, k)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": roomID, "title": title, "status": status, "host_id": hostID,
		"speakers": speakers, "listener_count": dinleyici, "hands": eller,
	})
}

// POST /rooms/{id}/join — dinleyici olarak katil (ayrilip donen speaker rolunu KORUR).
func (h *Handler) Join(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")

	var title, hostID string
	if err := h.db.QueryRow(r.Context(),
		`SELECT title, host_id FROM rooms WHERE id=$1 AND status='live'`, roomID).Scan(&title, &hostID); err != nil {
		writeErr(w, http.StatusNotFound, "oda bulunamadi veya bitti")
		return
	}
	// Kapasite: yalniz dinleyici sayilir (konusmacilar ayri sinirda)
	if h.dinleyiciSayisi(r.Context(), roomID) >= maxDinleyici {
		writeErr(w, http.StatusConflict, "oda dolu")
		return
	}
	// Upsert; 'removed' (atilan) upsert'e giremez -> kalici oda bani (LiveKit'te ban yok)
	var role string
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO room_participants (room_id, user_id, role, status)
		VALUES ($1, $2, 'listener', 'joined')
		ON CONFLICT (room_id, user_id) DO UPDATE
		SET status='joined', joined_at=now(), left_at=NULL, hand_raised_at=NULL
		WHERE room_participants.status <> 'removed'
		RETURNING role`, roomID, userID).Scan(&role)
	if err != nil {
		writeErr(w, http.StatusForbidden, "bu odaya katilamazsiniz")
		return
	}

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	roomName := "oda_" + roomID
	// LiveKit odasi empty_timeout ile silinmis olabilir (herkes cikti, DB'de hala live) —
	// token vermeden once YENIDEN yarat (idempotent): istemci auto-create'e dusup GLOBAL
	// max_participants:32 tavanina takilmasin (dogrulama bulgusu; Baglayici Karar 2).
	if err := h.lk.CreateRoom(r.Context(), roomName, odaKapasitesi, 300); err != nil {
		log.Printf("oda join create: %v", err) // olumcul degil: oda buyuk ihtimalle zaten var
	}
	tok, err := h.clientToken(roomName, userID, name, role)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	h.audit(r.Context(), roomID, userID, "join", clientIP(r))

	hedef := h.katilimcilar(r.Context(), roomID, "yonetim")
	if role != "listener" { // donen speaker/host -> herkese (izgara guncellensin)
		hedef = h.katilimcilar(r.Context(), roomID, "herkes")
	}
	h.yayinla(r.Context(), "room.participant.joined", map[string]any{
		"room_id": roomID, "user_id": userID, "name": name, "role": role,
		"listener_count": h.dinleyiciSayisi(r.Context(), roomID),
	}, hedef)

	writeJSON(w, http.StatusOK, map[string]any{
		"room_id": roomID, "room": roomName, "url": h.lkURL, "token": tok,
		"role": role, "title": title, "host_id": hostID,
	})
}

// POST /rooms/{id}/leave — ayril. Host ayrilirsa oda BITMEZ (sweep 2 dk bekler; kisa
// kesintide — GSM aramasi gibi — oda olmesin, host geri donebilsin).
func (h *Handler) Leave(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")

	var role string
	err := h.db.QueryRow(r.Context(), `
		UPDATE room_participants SET status='left', left_at=now(), hand_raised_at=NULL
		WHERE room_id=$1 AND user_id=$2 AND status='joined'
		RETURNING role`, roomID, userID).Scan(&role)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "left"}) // idempotent
		return
	}
	h.audit(r.Context(), roomID, userID, "leave", clientIP(r))

	hedef := h.katilimcilar(r.Context(), roomID, "yonetim")
	if role != "listener" {
		hedef = h.katilimcilar(r.Context(), roomID, "herkes")
	}
	h.yayinla(r.Context(), "room.participant.left", map[string]any{
		"room_id": roomID, "user_id": userID, "role": role,
		"listener_count": h.dinleyiciSayisi(r.Context(), roomID),
	}, hedef)
	writeJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

// POST /rooms/{id}/raise-hand {raised} — dinleyici el kaldirir/indirir. REST + DB
// (data sinyali DEGIL: dinleyicide canPublishData kapali + kalicilik gerekli).
func (h *Handler) RaiseHand(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")
	var req struct {
		Raised bool `json:"raised"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	// Throttle: 10 sn icinde tekrar kaldirma -> 429 (spam)
	if req.Raised {
		var yakin bool
		h.db.QueryRow(r.Context(), `
			SELECT hand_raised_at > now() - interval '10 seconds'
			FROM room_participants WHERE room_id=$1 AND user_id=$2 AND hand_raised_at IS NOT NULL`,
			roomID, userID).Scan(&yakin)
		if yakin {
			writeErr(w, http.StatusTooManyRequests, "cok sik deneme")
			return
		}
	}
	tag, err := h.db.Exec(r.Context(), `
		UPDATE room_participants
		SET hand_raised_at = CASE WHEN $3 THEN now() ELSE NULL END
		WHERE room_id=$1 AND user_id=$2 AND status='joined' AND role='listener'`,
		roomID, userID, req.Raised)
	if err != nil || tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "el kaldirilamadi")
		return
	}
	var name, avatar string
	h.db.QueryRow(r.Context(), `SELECT name, COALESCE(avatar_url,'') FROM users WHERE id=$1`, userID).Scan(&name, &avatar)
	h.audit(r.Context(), roomID, userID, "raise_hand", "")
	h.yayinla(r.Context(), "room.hand.raised", map[string]any{
		"room_id": roomID, "user_id": userID, "name": name, "avatar": avatar, "raised": req.Raised,
	}, h.katilimcilar(r.Context(), roomID, "host"))
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// hostMu — moderasyon uclari icin ortak yetki kontrolu
func (h *Handler) hostMu(ctx context.Context, roomID, userID string) bool {
	var ok bool
	h.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM rooms WHERE id=$1 AND host_id=$2 AND status='live')`,
		roomID, userID).Scan(&ok)
	return ok
}

// POST /rooms/{id}/promote {user_id} — dinleyiciyi konusmaci yap.
// Sira KRITIK: (1) DB rol -> (2) LiveKit izni (hata: DB geri al) -> (3) WS herkese.
func (h *Handler) Promote(w http.ResponseWriter, r *http.Request) {
	h.rolDegistir(w, r, true)
}

// POST /rooms/{id}/demote {user_id} — konusmaciyi dinleyici yap.
func (h *Handler) Demote(w http.ResponseWriter, r *http.Request) {
	h.rolDegistir(w, r, false)
}

func (h *Handler) rolDegistir(w http.ResponseWriter, r *http.Request, yukselt bool) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")
	if !h.hostMu(r.Context(), roomID, userID) {
		writeErr(w, http.StatusForbidden, "yalniz oda sahibi")
		return
	}
	var req struct {
		UserID string `json:"user_id"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if req.UserID == "" || req.UserID == userID { // host kendini yukseltemez/dusuremez
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}

	eskiRol, yeniRol := "listener", "speaker"
	if !yukselt {
		eskiRol, yeniRol = "speaker", "listener"
	}
	// Konusmaci siniri UPDATE'in ICINDE (atomik) — es zamanli iki promote 9 okuyup 11
	// yapamaz (dogrulama bulgusu: count-sonra-update yarisi).
	tag, err := h.db.Exec(r.Context(), `
		UPDATE room_participants SET role=$3, hand_raised_at=NULL
		WHERE room_id=$1 AND user_id=$2 AND status='joined' AND role=$4
		  AND ($3 <> 'speaker' OR (SELECT count(*) FROM room_participants
		       WHERE room_id=$1 AND status='joined' AND role IN ('host','speaker')) < $5)`,
		roomID, req.UserID, yeniRol, eskiRol, maxKonusmaci)
	if err != nil || tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "kullanici uygun durumda degil veya konusmaci siniri dolu")
		return
	}
	// LiveKit iznini CANLI baglantiya it (yeniden baglanma gerekmez).
	if err := h.lk.UpdateParticipant(r.Context(), "oda_"+roomID, req.UserID, yukselt); err != nil {
		log.Printf("oda izin (%s->%s): %v", eskiRol, yeniRol, err)
		// "not found" = hedef SU AN LiveKit'e bagli degil (kisa kopma/yeniden baglanma).
		// Rol DB'de dogru kaynak: rejoin token'i yeni role gore gelir -> geri ALMA.
		if yukselt && !lkYok(err) {
			// GERCEK hata (LiveKit erisilemedi vb): tutarlilik sart, rolu geri al
			h.db.Exec(r.Context(), `UPDATE room_participants SET role='listener'
				WHERE room_id=$1 AND user_id=$2`, roomID, req.UserID)
			writeErr(w, http.StatusBadGateway, "konusmaci yapilamadi, tekrar deneyin")
			return
		}
		// Demote'ta DB dogru kaynak: izin dusurulemese de rejoin'de listener token alir (loglandi)
	}
	islem := "promote"
	if !yukselt {
		islem = "demote"
	}
	h.audit(r.Context(), roomID, req.UserID, islem, "")
	// Rol degisimi SEYREK olay -> HERKESE (konusmaci izgarasi herkeste degismeli)
	h.yayinla(r.Context(), "room.role.changed", map[string]any{
		"room_id": roomID, "user_id": req.UserID, "role": yeniRol,
	}, h.katilimcilar(r.Context(), roomID, "herkes"))
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /rooms/{id}/mute {user_id} — host konusmaciyi susturur. UNMUTE YOK (uzaktan
// mikrofon acmak mahremiyet ihlali; enable_remote_unmute EKLENMEZ) — konusmaci kendisi acar.
func (h *Handler) Mute(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")
	if !h.hostMu(r.Context(), roomID, userID) {
		writeErr(w, http.StatusForbidden, "yalniz oda sahibi")
		return
	}
	var req struct {
		UserID string `json:"user_id"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	roomName := "oda_" + roomID
	tracks, err := h.lk.GetParticipantTracks(r.Context(), roomName, req.UserID)
	if err != nil {
		if lkYok(err) { // bagli degil -> susturacak track yok, sessiz basari
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
			return
		}
		writeErr(w, http.StatusBadGateway, "susturulamadi")
		return
	}
	for _, t := range tracks {
		if t.Type == "AUDIO" && !t.Muted {
			h.lk.MuteTrack(r.Context(), roomName, req.UserID, t.Sid, true)
		}
	}
	h.audit(r.Context(), roomID, req.UserID, "mute", "")
	h.yayinla(r.Context(), "room.participant.muted", map[string]any{
		"room_id": roomID, "user_id": req.UserID,
	}, h.katilimcilar(r.Context(), roomID, "yonetim"))
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /rooms/{id}/remove {user_id} — odadan at + kalici ban (Join 403).
// Sira: once DB 'removed' (RemoveParticipant basarisiz olsa bile geri giremez), sonra LiveKit kopar.
func (h *Handler) Remove(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")
	if !h.hostMu(r.Context(), roomID, userID) {
		writeErr(w, http.StatusForbidden, "yalniz oda sahibi")
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
	var rol string
	err := h.db.QueryRow(r.Context(), `
		UPDATE room_participants SET status='removed', left_at=now(), hand_raised_at=NULL
		WHERE room_id=$1 AND user_id=$2 AND status='joined'
		RETURNING role`, roomID, req.UserID).Scan(&rol)
	if err != nil {
		writeErr(w, http.StatusConflict, "kullanici odada degil")
		return
	}
	if err := h.lk.RemoveParticipant(r.Context(), "oda_"+roomID, req.UserID); err != nil {
		log.Printf("oda remove: %v", err) // DB 'removed' oldu; join 403 muhafizi yine calisir
	}
	h.audit(r.Context(), roomID, req.UserID, "remove", "")
	hedef := h.katilimcilar(r.Context(), roomID, "yonetim")
	if rol != "listener" {
		hedef = h.katilimcilar(r.Context(), roomID, "herkes")
	}
	h.yayinla(r.Context(), "room.participant.left", map[string]any{
		"room_id": roomID, "user_id": req.UserID, "role": rol, "removed": true,
		"listener_count": h.dinleyiciSayisi(r.Context(), roomID),
	}, hedef)
	// Atilana ozel olay: UI'si "odadan cikarildiniz" gosterip kapanir
	h.yayinla(r.Context(), "room.removed", map[string]any{"room_id": roomID}, []string{req.UserID})
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /rooms/{id}/end — odayi bitir (yalniz host). Idempotent (calls End deseni):
// yetki kontrolu status'e BAKMAZ (bitmis odada 2. end sessiz 200 doner, 403 degil).
func (h *Handler) End(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")
	var sahibi bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM rooms WHERE id=$1 AND host_id=$2)`, roomID, userID).Scan(&sahibi)
	if !sahibi {
		writeErr(w, http.StatusForbidden, "yalniz oda sahibi")
		return
	}
	h.odayiBitir(r.Context(), roomID, "end")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ended"})
}

// odayiBitir — End + sweep ortak yolu. Atomik UPDATE (0 satir = zaten bitmis, sessiz).
func (h *Handler) odayiBitir(ctx context.Context, roomID, neden string) {
	tag, err := h.db.Exec(ctx,
		`UPDATE rooms SET status='ended', ended_at=now() WHERE id=$1 AND status='live'`, roomID)
	if err != nil || tag.RowsAffected() == 0 {
		return
	}
	// Oda kapanisi TEK SEFERLIK olay -> herkese fan-out kabul (dinleyiciler dahil)
	herkes := h.katilimcilar(ctx, roomID, "herkes")
	h.yayinla(ctx, "room.ended", map[string]any{"room_id": roomID}, herkes)
	h.db.Exec(ctx, `UPDATE room_participants SET status='left', left_at=now()
		WHERE room_id=$1 AND status='joined'`, roomID)
	// LiveKit odasini SIL: WS'i kacirmis istemci bile sunucudan duser (hayalet oda kalmaz)
	if err := h.lk.DeleteRoom(ctx, "oda_"+roomID); err != nil {
		log.Printf("oda delete: %v", err)
	}
	h.audit(ctx, roomID, "", neden, "")
	log.Printf("oda bitti: %s (%s)", kisaID(roomID), neden)
}

// lkYok — twirp "katilimci/oda yok" hatasi mi (bagli-degil durumu; gercek ariza degil)
func lkYok(err error) bool {
	s := strings.ToLower(err.Error())
	return strings.Contains(s, "not_found") || strings.Contains(s, "does not exist") ||
		strings.Contains(s, "not found")
}

// ---- kucuk yardimcilar (calls'takiler private; kopya — calls'a dokunmuyoruz) ----

func clientIP(r *http.Request) string {
	return r.RemoteAddr // RealIP middleware gercek IP'yi RemoteAddr'a yazar
}

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
