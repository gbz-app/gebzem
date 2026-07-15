package calls

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
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
	apns *push.APNs // iOS kilit ekrani aramasi (VoIP push)

	lkURL    string // istemcinin baglanacagi adres (wss://rtc.gebzem.app)
	apiKey   string
	apiSecret string
}

func NewHandler(db *pgxpool.Pool, hub *chat.Hub, pushSender *push.Sender, apns *push.APNs) *Handler {
	return &Handler{
		db:        db,
		hub:       hub,
		push:      pushSender,
		apns:      apns,
		lkURL:     getEnv("LIVEKIT_URL", "wss://rtc.gebzem.app"),
		apiKey:    os.Getenv("LIVEKIT_API_KEY"),
		apiSecret: os.Getenv("LIVEKIT_API_SECRET"),
	}
}

func (h *Handler) Enabled() bool { return h.apiKey != "" && h.apiSecret != "" }

// Temizleyici: takili kalmis aramalari kapatir.
// Neden gerekli: zil zaman asimi ISTEMCIDE (45 sn). Arayanin uygulamasi cokerse /
// sebeke giderse End() hic cagrilmaz -> kayit sonsuza dek 'ringing' kalir, aranana
// cevapsiz arama yazilmaz; 'active' kalan kayit ise kullaniciyi kalici "mesgul" yapar.
func (h *Handler) StartSweeper(ctx context.Context) {
	go func() {
		t := time.NewTicker(30 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				h.sweep(ctx)
			}
		}
	}()
}

func (h *Handler) sweep(ctx context.Context) {
	// 1) 60 sn'dir calan ama cevaplanmayanlar -> cevapsiz (istemcinin 45 sn'lik
	//    timer'i normalde once davranir; bu sadece emniyet subabi)
	rows, err := h.db.Query(ctx, `
		UPDATE calls SET status='missed', ended_at=now()
		WHERE status='ringing' AND created_at < now() - interval '60 seconds'
		RETURNING id, caller_id, callee_id, type`)
	if err != nil {
		return
	}
	type kayit struct{ id, caller, callee, callType string }
	var bitenler []kayit
	for rows.Next() {
		var k kayit
		if rows.Scan(&k.id, &k.caller, &k.callee, &k.callType) == nil {
			bitenler = append(bitenler, k)
		}
	}
	rows.Close()

	for _, k := range bitenler {
		payload, _ := json.Marshal(map[string]string{"call_id": k.id, "status": "missed"})
		h.hub.Publish(ctx, &chat.Event{
			Type: "call.ended", Payload: payload, To: []string{k.caller, k.callee},
		})
		// Aliciya (callee) push ile de kapat: kilit ekranindaki CallKit ekrani asili
		// kalmasin. Online ise WS zaten kapatti — ek push cirkin banner uretir (End gibi).
		if !h.hub.Online(k.callee) {
			if h.push != nil {
				go h.push.CallInvite([]string{k.callee}, map[string]string{
					"type": "call.cancel", "call_id": k.id,
				})
			}
			if h.apns != nil {
				go h.apns.CallCancel(context.Background(), k.callee, k.id)
			}
		}
		// Cevapsiz arama -> sohbete kayit + (offline ise) bildirim (WhatsApp gibi)
		go h.logMissedToChat(context.Background(), k.caller, k.callee, k.callType)
	}

	// 2) 2 saatten uzun "suren" aramalar -> bitmis say (uygulama cokmus demektir)
	h.db.Exec(ctx, `
		UPDATE calls SET status='ended', ended_at=now()
		WHERE status='active' AND created_at < now() - interval '2 hours'`)

	if len(bitenler) > 0 {
		log.Printf("arama temizleyici: %d cevapsiz arama kapatildi", len(bitenler))
	}
}

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

	callType := "audio"
	if req.Video {
		callType = "video"
	}

	// MESGUL MU? Alici zaten baska bir aramadaysa (calan ya da suren) yeni arama
	// gonderme; "mesgul" olarak kaydet ki iki tarafin gecmisinde de gorunsun.
	// DIKKAT: 'active' icin ZAMAN SINIRI SART. Uygulama arama sirasinda cokerse
	// End() hic cagrilmaz, satir sonsuza dek 'active' kalir ve o kullaniciya gelen
	// HER arama "mesgul" doner (kullanici kalici olarak aranamaz olur).
	var busy bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM calls
		WHERE (caller_id=$1 OR callee_id=$1)
		  AND ((status='active'  AND created_at > now() - interval '2 hours')
		       OR (status='ringing' AND created_at > now() - interval '45 seconds')))`,
		req.CalleeID).Scan(&busy)
	if busy {
		h.db.Exec(r.Context(), `
			INSERT INTO calls (caller_id, callee_id, type, status, ended_at)
			VALUES ($1,$2,$3,'busy',now())`, callerID, req.CalleeID, callType)
		writeErr(w, http.StatusConflict, "Kullanici su anda baska bir gorusmede")
		return
	}

	// Arama kaydi
	var callID string
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
	// Uygulama kapali/kilitliyken de calmasi icin:
	//  - Android: FCM data-only push -> arka plan isleyicisi CallKit ekranini acar
	//  - iOS: APNs VoIP push -> CallKit (FCM VoIP GONDEREMEZ)
	davet := map[string]string{
		"type":          "call.incoming",
		"call_id":       callID,
		"room":          roomName,
		"call_type":     callType,
		"caller_id":     callerID,
		"caller_name":   callerName,
		"caller_avatar": callerAvatar,
	}
	// Callee'nin bu sunucuda CANLI WebSocket'i var mi?
	//  VAR  -> uygulama on planda; WS "call.incoming" (yukarida) zaten gelen arama ekranini
	//          gosteriyor. Push GONDERME — yoksa iOS'ta CallKit de acilir ve uygulama ici
	//          ekranla CIFT gosterim + ses oturumu cakismasi olur.
	//  YOK  -> uygulama kapali/arka planda; kilit ekraninda calmasi icin push SART
	//          (iOS'ta VoIP push -> CallKit zorunlu).
	online := h.hub.Online(req.CalleeID)
	log.Printf("arama daveti: call=%s callee online=%v (online->WS, offline->push)", callID[:8], online)
	if !online {
		if h.push != nil {
			go h.push.CallInvite([]string{req.CalleeID}, davet)
		}
		if h.apns != nil {
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
				defer cancel()
				h.apns.CallInvite(ctx, req.CalleeID, map[string]any{
					"call_id":       callID,
					"room":          roomName,
					"call_type":     callType,
					"caller_id":     callerID,
					"caller_name":   callerName,
					"caller_avatar": callerAvatar,
				})
			}()
		}
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

	var callerID, callType string
	err := h.db.QueryRow(r.Context(), `
		SELECT caller_id, type FROM calls WHERE id=$1 AND callee_id=$2`,
		callID, userID).Scan(&callerID, &callType)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}

	// ATOMIK kabul: tek kosullu UPDATE. Iki es zamanli Answer (cift ekran) ikisi de
	// 'ringing' okuyup gecemez -> sadece BIRI 'active' yapar (rows-affected=1), digeri 0 -> 409.
	ct, err := h.db.Exec(r.Context(),
		`UPDATE calls SET status='active', answered_at=now()
		 WHERE id=$1 AND callee_id=$2 AND status='ringing'`, callID, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	if ct.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "arama artik gecerli degil")
		return
	}

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)

	roomName := "call_" + callID
	tok, err := h.token(roomName, userID, name)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}

	// Arayana "kabul edildi" bildir — WS + PUSH (yedek).
	// KRITIK: arayan calarken ekrana bakmayi birakinca (paused) WS kapaniyor; tam o an
	// kabul edilirse call.answered WS'te KAYBOLUYOR -> arayan sonsuza kadar "Caliyor".
	// End'deki gibi push fallback ekliyoruz (istemci ayrica poll ile de kurtarir).
	payload, _ := json.Marshal(map[string]string{"call_id": callID})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.answered", Payload: payload, To: []string{callerID},
	})
	if h.push != nil {
		go h.push.CallInvite([]string{callerID}, map[string]string{
			"type": "call.answered", "call_id": callID,
		})
	}

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

	var callerID, calleeID, status, callType string
	err := h.db.QueryRow(r.Context(), `
		SELECT caller_id, callee_id, status, type FROM calls
		WHERE id=$1 AND (caller_id=$2 OR callee_id=$2)`, callID, userID).
		Scan(&callerID, &calleeID, &status, &callType)
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
	// ATOMIK bitirme: sadece hala 'ringing'/'active' ise. Zaten bitmisse (cift end,
	// answer+end yarisi) tekrar yazma ve TEKRAR OLAY YAYINLAMA -> karsi tarafa cift
	// call.ended / stale durum gitmesin.
	ct, err := h.db.Exec(r.Context(),
		`UPDATE calls SET status=$1, ended_at=now()
		 WHERE id=$2 AND status IN ('ringing','active')`, newStatus, callID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	if ct.RowsAffected() == 0 {
		// Zaten bitmis — sessizce basarili don, olay yayinlama
		writeJSON(w, http.StatusOK, map[string]string{"status": "ended"})
		return
	}

	// Diger tarafa bildir
	other := callerID
	if userID == callerID {
		other = calleeID
	}
	payload, _ := json.Marshal(map[string]string{"call_id": callID, "status": newStatus})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.ended", Payload: payload, To: []string{other},
	})

	// call.cancel push'u SADECE diger taraf OFFLINE ise. Online (uygulama acik,
	// WS bagli) ise call.ended WS olayi ekrani zaten kapatiyor; ek VoIP push iOS'ta
	// reportNewIncomingCall+endCall zorunlulugu yuzunden ekranda kisa ve CIRKIN
	// (base64 isimli) bir arama banner'i uretiyordu. Start() ile ayni gating.
	if !h.hub.Online(other) {
		if h.push != nil {
			go h.push.CallInvite([]string{other}, map[string]string{
				"type":    "call.cancel",
				"call_id": callID,
			})
		}
		if h.apns != nil {
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
				defer cancel()
				h.apns.CallCancel(ctx, other, callID)
			}()
		}
	}

	// Cevapsiz arama (arayan iptal etti / callee cevaplamadi) -> sohbete "cevapsiz arama"
	// kaydi + (callee offline ise) bildirim. Reddedilen aramada BILDIRIM/kayit yok.
	if newStatus == "missed" {
		go h.logMissedToChat(context.Background(), callerID, calleeID, callType)
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": newStatus})
}

// GET /calls/{id}/status — arayan "aramam cevaplandi mi / bitti mi" diye sorar.
// call.answered/call.ended WS olaylari (arka planda WS kopukken) KAYBOLABILIR;
// arayan calarken bunu 2 sn'de bir sorup 'active' gorunce baglanir, biterse kapatir.
// WS'in guvenilmezligini telafi eden KURTARMA agi.
func (h *Handler) Status(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")
	var status string
	err := h.db.QueryRow(r.Context(),
		`SELECT status FROM calls WHERE id=$1 AND (caller_id=$2 OR callee_id=$2)`,
		callID, userID).Scan(&status)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": status})
}

// GET /calls/active — beni su an arayan var mi?
// Uygulama arka plandayken WebSocket kopuk olabilir; kullanici bildirime dokunup
// uygulamayi acinca "call.incoming" olayi coktan gecmis olur. Uygulama acilista ve
// on plana her donusunde burayi sorar, calan arama varsa gelen arama ekranini gosterir.
func (h *Handler) Active(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())

	var callID, callType, callerName, callerAvatar string
	err := h.db.QueryRow(r.Context(), `
		SELECT c.id, c.type, u.name, COALESCE(u.avatar_url,'')
		FROM calls c JOIN users u ON u.id = c.caller_id
		WHERE c.callee_id=$1 AND c.status='ringing'
		  AND c.created_at > now() - interval '45 seconds'
		ORDER BY c.created_at DESC LIMIT 1`, userID).
		Scan(&callID, &callType, &callerName, &callerAvatar)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]any{}) // calan arama yok
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"call_id":      callID,
		"type":         callType,
		"caller_name":  callerName,
		"caller_avatar": callerAvatar,
	})
}

// GET /calls — arama gecmisi (kim, ne zaman, cevapsiz/reddedildi/mesgul, ne kadar surdu)
func (h *Handler) History(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT c.id, c.type, c.status, c.created_at,
		       c.caller_id = $1 AS outgoing,
		       COALESCE(EXTRACT(EPOCH FROM (c.ended_at - c.answered_at))::int, 0) AS duration,
		       u.id, u.name, COALESCE(u.username,''), COALESCE(u.avatar_url,'')
		FROM calls c
		JOIN users u ON u.id = CASE WHEN c.caller_id=$1 THEN c.callee_id ELSE c.caller_id END
		WHERE c.caller_id=$1 OR c.callee_id=$1
		ORDER BY c.created_at DESC LIMIT 100`, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	defer rows.Close()

	type item struct {
		ID        string    `json:"id"`
		Type      string    `json:"type"`     // audio | video
		Status    string    `json:"status"`   // ended|missed|rejected|busy|active|ringing
		CreatedAt time.Time `json:"created_at"`
		Outgoing  bool      `json:"outgoing"` // ben mi aradim
		Duration  int       `json:"duration"` // saniye (cevaplanmadiysa 0)
		PeerID    string    `json:"peer_id"`
		PeerName  string    `json:"peer_name"`
		PeerUser  string    `json:"peer_username"`
		PeerPhoto string    `json:"peer_avatar"`
	}
	out := []item{}
	for rows.Next() {
		var it item
		if rows.Scan(&it.ID, &it.Type, &it.Status, &it.CreatedAt, &it.Outgoing, &it.Duration,
			&it.PeerID, &it.PeerName, &it.PeerUser, &it.PeerPhoto) == nil {
			out = append(out, it)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// logMissedToChat: cevapsiz aramayi WhatsApp gibi sohbet thread'ine "cevapsiz arama"
// kaydi (type='system', content 'call:missed:audio|video') olarak dusurur ve callee
// OFFLINE ise bildirim gonderir. Direct sohbet yoksa olusturur. SADECE 'missed' icin
// cagrilir. Cift kayit, End()/sweep()'in atomik tek-sefer 'missed' gecisiyle onlenir.
func (h *Handler) logMissedToChat(ctx context.Context, callerID, calleeID, callType string) {
	// direct sohbeti bul, yoksa olustur (chat.CreateDirect ile ayni desen)
	var chatID string
	err := h.db.QueryRow(ctx, `
		SELECT c.id FROM chats c
		JOIN chat_members m1 ON m1.chat_id=c.id AND m1.user_id=$1
		JOIN chat_members m2 ON m2.chat_id=c.id AND m2.user_id=$2
		WHERE c.type='direct' LIMIT 1`, callerID, calleeID).Scan(&chatID)
	if err != nil {
		tx, txErr := h.db.Begin(ctx)
		if txErr != nil {
			return
		}
		defer tx.Rollback(ctx)
		if tx.QueryRow(ctx,
			`INSERT INTO chats (type, created_by) VALUES ('direct',$1) RETURNING id`, callerID).Scan(&chatID) != nil {
			return
		}
		for _, uid := range []string{callerID, calleeID} {
			if _, e := tx.Exec(ctx,
				`INSERT INTO chat_members (chat_id, user_id) VALUES ($1,$2)`, chatID, uid); e != nil {
				return
			}
		}
		if tx.Commit(ctx) != nil {
			return
		}
	}

	if callType != "video" {
		callType = "audio"
	}
	content := "call:missed:" + callType

	var msgID int64
	var createdAt time.Time
	if h.db.QueryRow(ctx,
		`INSERT INTO messages (chat_id, sender_id, type, content) VALUES ($1,$2,'system',$3)
		 RETURNING id, created_at`, chatID, callerID, content).Scan(&msgID, &createdAt) != nil {
		return
	}
	// Okunmamis rozeti icin teslim kaydi (callee icin unread sayilir; sender_id=caller)
	for _, uid := range []string{callerID, calleeID} {
		h.db.Exec(ctx,
			`INSERT INTO message_receipts (message_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			msgID, uid)
	}

	payload, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": callerID,
		"type": "system", "content": content, "media_url": "",
		"reply_to_id": nil, "created_at": createdAt,
	})
	h.hub.Publish(ctx, &chat.Event{
		Type: "message.new", ChatID: chatID, Payload: payload, To: []string{callerID, calleeID},
	})

	// Callee offline ise gercek bir "cevapsiz arama" bildirimi (mesaj push deseniyle ayni yol)
	if h.push != nil && !h.hub.Online(calleeID) {
		var callerName string
		h.db.QueryRow(ctx, `SELECT name FROM users WHERE id=$1`, callerID).Scan(&callerName)
		onizleme := "Cevapsiz sesli arama"
		if callType == "video" {
			onizleme = "Cevapsiz goruntulu arama"
		}
		go h.push.NotifyUsers([]string{calleeID}, callerName, onizleme, chatID)
	}
}

// ---- ADMIN IZLEME PANELI (test icin canli arama gorunumu) ----

func adminYetkili(r *http.Request) bool {
	key := os.Getenv("ADMIN_KEY")
	if key == "" {
		key = "gbz-izle-2026" // prototip varsayilan
	}
	return r.URL.Query().Get("key") == key
}

var adminUpgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

// GET /admin/ws?key=X — arama olayi (call.incoming/answered/ended) olunca panele ANINDA
// "guncelle" push eder (Redis "events" dinlenir). Panel bunu alinca /admin/calls'i taze ceker.
func (h *Handler) AdminWS(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	conn, err := adminUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	sub := h.hub.Subscribe(r.Context())
	defer sub.Close()
	ch := sub.Channel()
	for {
		select {
		case <-r.Context().Done():
			return
		case msg, ok := <-ch:
			if !ok {
				return
			}
			if strings.Contains(msg.Payload, "call.") {
				conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
				if conn.WriteMessage(websocket.TextMessage, []byte("guncelle")) != nil {
					return
				}
			}
		}
	}
}

// GET /admin/calls?key=X — son 50 arama (isim + sureler), panel JS'i buradan ceker
func (h *Handler) AdminCalls(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT substr(c.id::text,1,8), c.type, c.status,
		       COALESCE(uc.name,'?'), COALESCE(ue.name,'?'),
		       to_char(c.created_at,'HH24:MI:SS'),
		       COALESCE(to_char(c.answered_at,'HH24:MI:SS'),'-'),
		       COALESCE(to_char(c.ended_at,'HH24:MI:SS'),'-'),
		       COALESCE(EXTRACT(EPOCH FROM (c.answered_at-c.created_at))::int, -1),
		       COALESCE(EXTRACT(EPOCH FROM (c.ended_at-c.answered_at))::int, -1)
		FROM calls c
		JOIN users uc ON uc.id=c.caller_id
		JOIN users ue ON ue.id=c.callee_id
		ORDER BY c.created_at DESC LIMIT 50`)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sorgu hatasi")
		return
	}
	defer rows.Close()
	type row struct {
		ID      string `json:"id"`
		Type    string `json:"type"`
		Status  string `json:"status"`
		Caller  string `json:"caller"`
		Callee  string `json:"callee"`
		Basla   string `json:"basla"`
		Cevap   string `json:"cevap"`
		Bitis   string `json:"bitis"`
		RingSec int    `json:"ring_sec"`
		TalkSec int    `json:"talk_sec"`
	}
	out := []row{}
	for rows.Next() {
		var x row
		if rows.Scan(&x.ID, &x.Type, &x.Status, &x.Caller, &x.Callee,
			&x.Basla, &x.Cevap, &x.Bitis, &x.RingSec, &x.TalkSec) == nil {
			out = append(out, x)
		}
	}
	w.Header().Set("Access-Control-Allow-Origin", "*")
	writeJSON(w, http.StatusOK, out)
}

// GET /admin/izle?key=X — canli arama izleme paneli (HTML)
func (h *Handler) AdminPanel(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte("yetkisiz — dogru ?key= gerekli"))
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(adminHTML))
}

const adminHTML = `<!doctype html><html><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Gebzem — Arama Izle</title>
<style>
body{background:#0b141a;color:#e9edef;font-family:system-ui,-apple-system,sans-serif;margin:0;padding:12px}
h1{font-size:18px;margin:0 0 4px}
#durum{color:#25d366;font-size:13px;margin-bottom:8px}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{padding:7px 8px;text-align:left;border-bottom:1px solid #222d34;white-space:nowrap}
th{color:#8696a0;font-weight:600;font-size:11px;text-transform:uppercase}
tr.okk{background:rgba(37,211,102,.10)}
tr.sus{background:rgba(255,193,7,.14)}
tr.mis{opacity:.55}
tr.rej{background:rgba(255,152,0,.12)}
tr.bsy{background:rgba(156,39,176,.14)}
tr.act{background:rgba(244,67,54,.20);animation:bl 1s infinite}
@keyframes bl{50%{opacity:.55}}
.dur{font-weight:700;font-size:15px}
#aciklama{color:#8696a0;font-size:12px;margin-top:10px;line-height:1.5}
</style></head><body>
<h1>📞 Gebzem — Canli Arama Izleme</h1>
<div id=durum>baglaniyor…</div>
<table><thead><tr>
<th>Arayan → Aranan</th><th>Tip</th><th>Durum</th><th>Basladi</th><th>Cevap(sn)</th><th>Bitti</th><th>Sure(sn)</th>
</tr></thead><tbody id=govde></tbody></table>
<div id=aciklama></div>
<script>
var key=new URLSearchParams(location.search).get('key')||'';
function ikon(t){return t=='video'?'📹':'🎤';}
function sinif(s,talk){
 if(s=='active')return 'act';
 if(s=='missed')return 'mis';
 if(s=='rejected')return 'rej';
 if(s=='busy')return 'bsy';
 if(s=='ended')return (talk!=null&&talk>=2)?'okk':'sus';
 return '';}
function durum(s,talk){
 if(s=='active')return '🔴 CANLI/acik';
 if(s=='missed')return '⚪ cevapsiz';
 if(s=='rejected')return '🟠 reddedildi';
 if(s=='busy')return '🟣 mesgul';
 if(s=='ended')return (talk>=2)?'🟢 konusuldu':'🟡 hemen koptu?';
 return s;}
async function yenile(){
 try{
  var r=await fetch('/admin/calls?key='+encodeURIComponent(key));
  if(!r.ok){document.getElementById('durum').textContent='❌ yetkisiz — key yanlis';return;}
  var d=await r.json();var g=document.getElementById('govde');g.innerHTML='';
  for(var i=0;i<d.length;i++){var c=d[i];
   var tr=document.createElement('tr');tr.className=sinif(c.status,c.talk_sec);
   var ring=c.ring_sec>=0?c.ring_sec:'-';var talk=c.talk_sec>=0?c.talk_sec:'-';
   tr.innerHTML='<td>'+c.caller+' → '+c.callee+'</td>'+
    '<td>'+ikon(c.type)+' '+(c.type=='video'?'Goruntulu':'Sesli')+'</td>'+
    '<td>'+durum(c.status,c.talk_sec)+'</td>'+
    '<td>'+c.basla+'</td><td>'+ring+'</td><td>'+c.bitis+'</td>'+
    '<td class=dur>'+talk+'</td>';
   g.appendChild(tr);}
  document.getElementById('durum').textContent='🟢 canli • '+d.length+' arama • '+new Date().toLocaleTimeString('tr');
 }catch(e){document.getElementById('durum').textContent='baglanti hatasi';}}
document.getElementById('aciklama').innerHTML='🟢 konusuldu (2sn+) &nbsp; 🟡 baglandi hemen koptu (patlama suphesi) &nbsp; ⚪ cevapsiz &nbsp; 🟠 reddedildi &nbsp; 🟣 mesgul &nbsp; 🔴 acik/canli<br>Cevap(sn) = kac saniyede acildi (art arda arama hizi) &nbsp;|&nbsp; Sure(sn) = konusma suresi';
function baglanWs(){try{
 var ws=new WebSocket((location.protocol=='https:'?'wss':'ws')+'://'+location.host+'/admin/ws?key='+encodeURIComponent(key));
 ws.onmessage=function(){yenile();};
 ws.onclose=function(){setTimeout(baglanWs,2000);};
}catch(e){setTimeout(baglanWs,2000);}}
yenile();baglanWs();setInterval(yenile,10000);
</script></body></html>`

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
