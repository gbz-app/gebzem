package chat

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/push"
)

type Handler struct {
	db   *pgxpool.Pool
	hub  *Hub
	push *push.Sender // nil olabilir (push devre disi)
}

func NewHandler(db *pgxpool.Pool, hub *Hub, pushSender *push.Sender) *Handler {
	return &Handler{db: db, hub: hub, push: pushSender}
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin:     func(r *http.Request) bool { return true }, // mobil istemci — origin kontrolu gereksiz
}

// GET /ws — WebSocket baglantisi (token middleware'den gecmis)
func (h *Handler) WebSocket(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	client := &Client{UserID: userID, Conn: conn, Send: make(chan []byte, 64)}
	h.hub.Register(client)
	h.db.Exec(r.Context(), `UPDATE users SET last_seen=now() WHERE id=$1`, userID)

	// yazici
	go func() {
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()
		defer conn.Close()
		for {
			select {
			case msg, ok := <-client.Send:
				if !ok {
					return
				}
				// Yari-acik sokette WriteMessage kuyrugu dolar -> call.answered/call.ended
				// SESSIZCE dusurulur. NOT: askiya alinmis istemcide kucuk yazi kernel gonderim
				// buffer'ina dusup ANINDA nil doner (deadline TETIKLENMEZ) -> bayat soketin tek
				// gercek dedektoru read-deadline'dir (pong gelmezse). Write-deadline yalniz
				// buffer GERCEKTEN dolunca (buyuk/cok mesaj) devreye girer.
				conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if err := conn.WriteMessage(websocket.TextMessage, msg); err != nil {
					return
				}
			case <-ticker.C:
				conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			}
		}
	}()

	// okuyucu: istemciden gelen olaylar (typing vb.)
	defer func() {
		h.hub.Unregister(client)
		conn.Close() // read-deadline dolunca yaziciyi da aninda coz (WriteMessage'da kilitliyse)
		h.db.Exec(r.Context(), `UPDATE users SET last_seen=now() WHERE id=$1`, userID)
	}()
	conn.SetReadLimit(64 << 10)
	// Yari-acik soket tespiti: yazici 15sn'de bir ping atiyor, istemci pong doner.
	// Pong (ya da herhangi bir mesaj) gelince okuma zaman asimini tazele. 35sn boyunca
	// hicbir sey gelmezse ReadMessage hata verir -> Unregister -> Online() GERCEGI yansitir.
	// Onemli: arka planda askiya alinmis/kopmus (temiz FIN atmadan giden) istemci
	// "cevrimici" gorunup gelen aramaya push atilmasini engellemesin. Client paused'da
	// 'bg' cercevesi gonderiyor (aninda offline) AMA ani askida o da flush olmayabilir;
	// bu 35sn (2x15sn pong toleransi) worst-case emniyet agidir. 70sn cok uzundu (kilit
	// ekrani araması ~70sn "online" sanilip push'suz gecikiyordu = regresyon).
	const wsOkumaZamanAsimi = 35 * time.Second
	conn.SetReadDeadline(time.Now().Add(wsOkumaZamanAsimi))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(wsOkumaZamanAsimi))
		return nil
	})
	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			return
		}
		conn.SetReadDeadline(time.Now().Add(wsOkumaZamanAsimi))
		var ev Event
		if json.Unmarshal(raw, &ev) != nil {
			continue
		}
		switch ev.Type {
		case "bg":
			// Istemci arka plana/kilit ekranina gecti: presence'tan ANINDA dus.
			// return -> defer Unregister + conn.Close() + last_seen calisir (double-close YOK).
			// Boylece Online()=false olur; bu kullaniciya gelen sonraki arama push/VoIP-push
			// alir (kilit ekraninda ANINDA calar). FIN flush'ini beklemeye gerek kalmaz.
			return
		case "typing":
			// yaziyor... olayini sohbetin diger uyelerine ilet (DB'ye yazilmaz)
			members, err := h.chatMemberIDs(r, ev.ChatID, userID)
			if err == nil {
				ev.To = members
				payload, _ := json.Marshal(map[string]string{"user_id": userID})
				ev.Payload = payload
				h.hub.Publish(r.Context(), &ev)
			}
		}
	}
}

type sendMessageReq struct {
	Type      string `json:"type"` // text, image, video, audio, location
	Content   string `json:"content"`
	MediaURL  string `json:"media_url"`
	ReplyToID *int64 `json:"reply_to_id"`
}

// POST /chats/{chatID}/messages — mesaj gonder (once DB, sonra Redis yayini)
func (h *Handler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")

	var req sendMessageReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	if req.Type == "" {
		req.Type = "text"
	}

	// uyelik + engel kontrolu
	members, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin uyesi degilsiniz")
		return
	}

	var msgID int64
	var createdAt time.Time
	err = h.db.QueryRow(r.Context(), `
		INSERT INTO messages (chat_id, sender_id, type, content, media_url, reply_to_id)
		VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, created_at`,
		chatID, userID, req.Type, req.Content, req.MediaURL, req.ReplyToID).Scan(&msgID, &createdAt)
	if err != nil {
		log.Printf("mesaj insert: %v", err)
		httpErr(w, http.StatusInternalServerError, "mesaj kaydedilemedi")
		return
	}

	// alicilara teslim kaydi ac
	for _, uid := range members {
		h.db.Exec(r.Context(),
			`INSERT INTO message_receipts (message_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			msgID, uid)
	}

	payload, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": userID,
		"type": req.Type, "content": req.Content, "media_url": req.MediaURL,
		"reply_to_id": req.ReplyToID, "created_at": createdAt,
	})
	h.hub.Publish(r.Context(), &Event{Type: "message.new", ChatID: chatID, Payload: payload, To: members})

	// Push bildirimi (async): gonderen adiyla alicilara
	if h.push != nil {
		var senderName string
		h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&senderName)
		preview := req.Content
		switch req.Type {
		case "image":
			preview = "📷 Fotograf"
		case "video":
			preview = "🎥 Video"
		case "audio":
			preview = "🎤 Sesli mesaj"
		case "location":
			preview = "📍 Konum"
		}
		if len(preview) > 80 {
			preview = preview[:80]
		}
		go h.push.NotifyUsers(members, senderName, preview, chatID)
	}

	writeJSON(w, http.StatusCreated, map[string]any{"id": msgID, "created_at": createdAt})
}

// GET /chats/{chatID}/messages?before_id=&limit= — gecmis (sayfali)
func (h *Handler) GetMessages(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	if _, err := h.chatMemberIDs(r, chatID, userID); err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin uyesi degilsiniz")
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	beforeID, _ := strconv.ParseInt(r.URL.Query().Get("before_id"), 10, 64)
	if beforeID <= 0 {
		beforeID = 1<<62 - 1
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, sender_id, type,
		       CASE WHEN deleted_for_all THEN '' ELSE content END,
		       CASE WHEN deleted_for_all THEN '' ELSE media_url END,
		       reply_to_id, deleted_for_all, created_at
		FROM messages WHERE chat_id=$1 AND id<$2
		ORDER BY id DESC LIMIT $3`, chatID, beforeID, limit)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	defer rows.Close()

	type msg struct {
		ID            int64      `json:"id"`
		SenderID      string     `json:"sender_id"`
		Type          string     `json:"type"`
		Content       string     `json:"content"`
		MediaURL      string     `json:"media_url"`
		ReplyToID     *int64     `json:"reply_to_id"`
		DeletedForAll bool       `json:"deleted_for_all"`
		CreatedAt     time.Time  `json:"created_at"`
	}
	out := []msg{}
	for rows.Next() {
		var m msg
		if err := rows.Scan(&m.ID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL,
			&m.ReplyToID, &m.DeletedForAll, &m.CreatedAt); err == nil {
			out = append(out, m)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /chats/direct — 1:1 sohbet ac (varsa mevcut olani dondur)
func (h *Handler) CreateDirect(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	var req struct {
		UserID string `json:"user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.UserID == "" || req.UserID == userID {
		httpErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}

	// engel kontrolu (cift yonlu)
	var blocked bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		userID, req.UserID).Scan(&blocked)
	if blocked {
		httpErr(w, http.StatusForbidden, "bu kullaniciyla sohbet baslatilamiyor")
		return
	}

	// mevcut direct sohbeti bul
	var chatID string
	err := h.db.QueryRow(r.Context(), `
		SELECT c.id FROM chats c
		JOIN chat_members m1 ON m1.chat_id=c.id AND m1.user_id=$1
		JOIN chat_members m2 ON m2.chat_id=c.id AND m2.user_id=$2
		WHERE c.type='direct' LIMIT 1`, userID, req.UserID).Scan(&chatID)
	if err != nil {
		// yoksa olustur
		tx, err := h.db.Begin(r.Context())
		if err != nil {
			httpErr(w, http.StatusInternalServerError, "sunucu hatasi")
			return
		}
		defer tx.Rollback(r.Context())
		if err := tx.QueryRow(r.Context(),
			`INSERT INTO chats (type, created_by) VALUES ('direct',$1) RETURNING id`, userID).Scan(&chatID); err != nil {
			httpErr(w, http.StatusInternalServerError, "sohbet olusturulamadi")
			return
		}
		for _, uid := range []string{userID, req.UserID} {
			if _, err := tx.Exec(r.Context(),
				`INSERT INTO chat_members (chat_id, user_id) VALUES ($1,$2)`, chatID, uid); err != nil {
				httpErr(w, http.StatusInternalServerError, "sohbet olusturulamadi")
				return
			}
		}
		tx.Commit(r.Context())
	}
	writeJSON(w, http.StatusOK, map[string]string{"chat_id": chatID})
}

// GET /chats — sohbet listesi (son mesaj + okunmamis sayisi)
func (h *Handler) ListChats(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	// Direct sohbetlerde baslik/avatar karsi tarafin adindan gelir; peer_id arama icin
	rows, err := h.db.Query(r.Context(), `
		SELECT c.id, c.type,
		       CASE WHEN c.type='direct' THEN COALESCE(peer.name, '') ELSE c.title END AS title,
		       CASE WHEN c.type='direct' THEN COALESCE(peer.avatar_url, '') ELSE c.avatar_url END AS avatar_url,
		       cm.pinned, cm.archived,
		       COALESCE(lm.content,''), COALESCE(lm.type,''), lm.created_at,
		       (SELECT COUNT(*) FROM message_receipts mr
		        JOIN messages m ON m.id=mr.message_id
		        WHERE m.chat_id=c.id AND mr.user_id=$1 AND mr.read_at IS NULL AND m.sender_id<>$1) AS unread,
		       peer.id AS peer_id
		FROM chats c
		JOIN chat_members cm ON cm.chat_id=c.id AND cm.user_id=$1
		LEFT JOIN LATERAL (
			SELECT u.id, u.name, u.avatar_url FROM chat_members cm2
			JOIN users u ON u.id = cm2.user_id
			WHERE cm2.chat_id = c.id AND cm2.user_id <> $1
			LIMIT 1
		) peer ON c.type='direct'
		LEFT JOIN LATERAL (
			SELECT content, type, created_at FROM messages
			WHERE chat_id=c.id AND NOT deleted_for_all ORDER BY id DESC LIMIT 1
		) lm ON true
		ORDER BY cm.pinned DESC, lm.created_at DESC NULLS LAST`, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	defer rows.Close()

	type chatRow struct {
		ID          string     `json:"id"`
		Type        string     `json:"type"`
		Title       string     `json:"title"`
		AvatarURL   string     `json:"avatar_url"`
		Pinned      bool       `json:"pinned"`
		Archived    bool       `json:"archived"`
		LastMessage string     `json:"last_message"`
		LastType    string     `json:"last_type"`
		LastAt      *time.Time `json:"last_at"`
		Unread      int        `json:"unread"`
		PeerID      *string    `json:"peer_id"` // direct sohbette karsi taraf (arama icin)
	}
	out := []chatRow{}
	for rows.Next() {
		var c chatRow
		if err := rows.Scan(&c.ID, &c.Type, &c.Title, &c.AvatarURL, &c.Pinned, &c.Archived,
			&c.LastMessage, &c.LastType, &c.LastAt, &c.Unread, &c.PeerID); err == nil {
			out = append(out, c)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /chats/{chatID}/read — okundu isaretle (mavi tik)
func (h *Handler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	members, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin uyesi degilsiniz")
		return
	}
	_, err = h.db.Exec(r.Context(), `
		UPDATE message_receipts mr SET read_at=now()
		FROM messages m
		WHERE m.id=mr.message_id AND m.chat_id=$1 AND mr.user_id=$2 AND mr.read_at IS NULL`, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	payload, _ := json.Marshal(map[string]string{"chat_id": chatID, "reader_id": userID})
	h.hub.Publish(r.Context(), &Event{Type: "receipt.read", ChatID: chatID, Payload: payload, To: members})
	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

// chatMemberIDs: sohbet uyeligini dogrular, DIGER uyelerin id'lerini dondurur
func (h *Handler) chatMemberIDs(r *http.Request, chatID, userID string) ([]string, error) {
	rows, err := h.db.Query(r.Context(),
		`SELECT user_id FROM chat_members WHERE chat_id=$1`, chatID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	found := false
	for rows.Next() {
		var id string
		rows.Scan(&id)
		if id == userID {
			found = true
		} else {
			ids = append(ids, id)
		}
	}
	if !found {
		return nil, http.ErrNoCookie // uyelik yok isareti
	}
	return ids, nil
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func httpErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
