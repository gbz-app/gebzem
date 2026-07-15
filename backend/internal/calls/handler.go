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

const adminHTML = `<!doctype html><html lang=tr><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Gebzem · Arama İzleme</title>
<style>
:root{--card:#141b22;--card2:#1b242d;--line:#232f39;--txt:#e9edef;--dim:#8696a0;--green:#25d366;--yellow:#ffb020;--red:#f04747;--orange:#ff8c42;--purple:#b57edc}
*{box-sizing:border-box}
body{background:radial-gradient(1200px 600px at 50% -10%,#12202b,#0a0e12);color:var(--txt);font-family:-apple-system,system-ui,'Segoe UI',sans-serif;margin:0;padding:16px;min-height:100vh}
.wrap{max-width:900px;margin:0 auto}
.head{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin-bottom:16px}
.title{font-size:21px;font-weight:800;display:flex;align-items:center;gap:8px}
.title .sub{color:var(--dim);font-weight:400;font-size:15px}
.live{display:flex;align-items:center;gap:7px;font-size:12.5px;color:var(--green);background:rgba(37,211,102,.12);padding:6px 13px;border-radius:20px;font-variant-numeric:tabular-nums}
.d{width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 8px var(--green);animation:p 1.4s infinite}
@keyframes p{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.35;transform:scale(1.35)}}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(115px,1fr));gap:10px;margin-bottom:18px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:13px 15px}
.stat .n{font-size:25px;font-weight:800;line-height:1}
.stat .l{font-size:11.5px;color:var(--dim);margin-top:5px}
.list{display:flex;flex-direction:column;gap:8px}
.c{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--dim);border-radius:13px;padding:12px 15px;display:flex;align-items:center;justify-content:space-between;gap:12px;transition:.15s}
.c:hover{background:var(--card2);transform:translateX(2px)}
.c.g{border-left-color:var(--green)}.c.y{border-left-color:var(--yellow)}.c.r{border-left-color:var(--red);animation:gl 1.6s infinite}.c.o{border-left-color:var(--orange)}.c.p{border-left-color:var(--purple)}.c.m{border-left-color:#3a4750;opacity:.72}
@keyframes gl{50%{background:rgba(240,71,71,.10);border-left-color:#ff8a8a}}
.who{font-size:15px;font-weight:600}.who .ar{color:var(--dim);margin:0 5px}
.meta{font-size:12px;color:var(--dim);margin-top:4px;display:flex;gap:12px;flex-wrap:wrap}
.right{text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:5px}
.badge{font-size:12px;font-weight:700;padding:4px 11px;border-radius:8px;white-space:nowrap}
.badge.g{background:rgba(37,211,102,.16);color:#4be089}
.badge.y{background:rgba(255,176,32,.16);color:var(--yellow)}
.badge.r{background:rgba(240,71,71,.20);color:#ff8a8a}
.badge.o{background:rgba(255,140,66,.16);color:var(--orange)}
.badge.p{background:rgba(181,126,220,.16);color:var(--purple)}
.badge.m{background:rgba(134,150,160,.14);color:var(--dim)}
.dur{font-size:19px;font-weight:800}.dur small{font-size:11px;color:var(--dim);font-weight:600}
.empty{text-align:center;padding:64px 20px;color:var(--dim)}.empty .i{font-size:52px;margin-bottom:14px}
.foot{margin-top:20px;font-size:11.5px;color:var(--dim);text-align:center;line-height:1.9;border-top:1px solid var(--line);padding-top:14px}
</style></head><body><div class=wrap>
<div class=head>
 <div class=title>📞 Gebzem <span class=sub>Arama İzleme</span></div>
 <div class=live><span class=d></span><span id=st>bağlanıyor…</span></div>
</div>
<div class=stats id=stats></div>
<div class=list id=list></div>
<div class=foot id=foot></div>
</div><script>
var key=new URLSearchParams(location.search).get('key')||'';
function esc(s){var e=document.createElement('span');e.textContent=s==null?'':s;return e.innerHTML;}
function sb(s,t){
 if(s=='active')return['r','🔴 Canlı'];
 if(s=='missed')return['m','⚪ Cevapsız'];
 if(s=='rejected')return['o','🟠 Reddedildi'];
 if(s=='busy')return['p','🟣 Meşgul'];
 if(s=='ended')return t>=2?['g','🟢 Konuşuldu']:['y','🟡 Hemen koptu'];
 return['m',s];}
function stat(n,l,c){return '<div class=stat><div class=n'+(c?' style="color:'+c+'"':'')+'>'+n+'</div><div class=l>'+l+'</div></div>';}
function render(d){
 var L=document.getElementById('list'),S=document.getElementById('stats'),F=document.getElementById('foot');
 F.innerHTML='🟢 konuşuldu (2sn+) &nbsp;·&nbsp; 🟡 hemen koptu (patlama şüphesi) &nbsp;·&nbsp; ⚪ cevapsız &nbsp;·&nbsp; 🟠 reddedildi &nbsp;·&nbsp; 🟣 meşgul &nbsp;·&nbsp; 🔴 canlı<br>⚡ = kaç saniyede açıldı (art arda arama hızı) &nbsp;·&nbsp; sağdaki büyük sayı = konuşma süresi';
 if(!d.length){L.innerHTML='<div class=empty><div class=i>📭</div>Henüz arama yok.<br>İki telefonla arama yap — burada <b>anlık</b> göreceksin.</div>';S.innerHTML='';return;}
 var kon=0,cev=0,pat=0,rt=0,rn=0;
 for(var i=0;i<d.length;i++){var c=d[i];
  if(c.status=='ended'&&c.talk_sec>=2)kon++;
  if(c.status=='missed'||c.status=='rejected')cev++;
  if(c.status=='ended'&&c.talk_sec>=0&&c.talk_sec<2)pat++;
  if(c.ring_sec>=0){rt+=c.ring_sec;rn++;}}
 var ort=rn?(Math.round(rt/rn*10)/10):'—';
 S.innerHTML=stat(d.length,'Toplam')+stat(kon,'Konuşuldu','#4be089')+stat(cev,'Cevapsız/Red')+stat(pat,'Patlama şüphesi',pat?'var(--yellow)':null)+stat(ort+'sn','Ort. bağlanma');
 var h='';
 for(var i=0;i<d.length;i++){var c=d[i];var b=sb(c.status,c.talk_sec);
  var tip=c.type=='video'?'📹 Görüntülü':'🎤 Sesli';
  var ring=c.ring_sec>=0?('⚡ '+c.ring_sec+'sn\'de açıldı'):'';
  var zaman='🕐 '+c.basla+(c.bitis!='-'?' → '+c.bitis:'');
  var sure=(c.status=='ended'&&c.talk_sec>=0)?('<div class=dur>'+c.talk_sec+'<small>sn</small></div>'):'';
  h+='<div class="c '+b[0]+'"><div><div class=who>'+esc(c.caller)+'<span class=ar>→</span>'+esc(c.callee)+'</div>'+
   '<div class=meta><span>'+tip+'</span><span>'+zaman+'</span>'+(ring?'<span>'+ring+'</span>':'')+'</div></div>'+
   '<div class=right><span class="badge '+b[0]+'">'+b[1]+'</span>'+sure+'</div></div>';}
 L.innerHTML=h;}
async function yenile(){
 try{var r=await fetch('/admin/calls?key='+encodeURIComponent(key));
  if(!r.ok){document.getElementById('st').textContent='yetkisiz — key yanlış';return;}
  render(await r.json());
  document.getElementById('st').textContent='canlı · '+new Date().toLocaleTimeString('tr');
 }catch(e){document.getElementById('st').textContent='bağlantı yok';}}
function ws(){try{var s=new WebSocket((location.protocol=='https:'?'wss':'ws')+'://'+location.host+'/admin/ws?key='+encodeURIComponent(key));s.onmessage=function(){yenile();};s.onclose=function(){setTimeout(ws,2000);};}catch(e){setTimeout(ws,2000);}}
yenile();ws();setInterval(yenile,10000);
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
