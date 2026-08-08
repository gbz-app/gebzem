package chat

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5"
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
			if err != nil {
				continue
			}
			// ⚠️⚠️ TURU 76 — ENGEL KAPISI. Bu kapi YOKTU: engelleme sonrasi sohbet
			//    satiri iki tarafta da duruyor (silinmiyor) ve engellenen kisi
			//    sohbeti acip klavyeye dokununca ENGELLEYENIN EKRANINDA
			//    "yazıyor..." cikiyordu — yani engellenen kisi CANLI GORUNMEYE
			//    DEVAM EDIYOR, ustelik gostergeyi surekli titreterek TACIZ
			//    ARACINA cevirebiliyordu (mesaj gitmese bile).
			// ⚠️ MEVCUT TEK KAYNAK kullaniliyor (`engelliMi`) — yeni SQL YAZILMADI.
			// ⚠️ FAIL-CLOSED: sorgu patlarsa olay GONDERILMEZ.
			if engelli, herr := h.engelliMi(r, ev.ChatID, userID, members); herr != nil || engelli {
				continue
			}
			ev.To = members
			payload, _ := json.Marshal(map[string]string{"user_id": userID})
			ev.Payload = payload
			h.hub.Publish(r.Context(), &ev)
		}
	}
}

// ⚠️⚠️ TURU 74 — `MediaURL` ALANI KALDIRILDI (guvenlik).
//
// Eskiden istemci `media_url`i SERBESTCE gonderebiliyor ve sunucu onu DOGRULAMADAN
// `messages` tablosuna INSERT ediyordu. Istemci bu alani HIC GONDERMIYOR
// (`chats_provider.dart:80` govdesi yalnizca `{'type','content'}`) — yani alan
// KULLANILMIYOR ama ACIK duruyordu. Sonuc: herhangi bir kullanici
// `{"type":"image","media_url":"https://kotu-site/izleme.gif"}` gonderip karsi tarafta
// KENDI SUNUCUSUNDAN icerik cektirebilirdi:
//
//	· IZLEME PIKSELI — mesaj acilir acilmaz alicinin IP'si ve saati saldirgana gider
//	· OLTALAMA — sohbet icinde sahte gorsel/banner
//	· SSRF/ic ag taramasi — sunucu tarafi onizleme eklenirse
//
// `models.dart:80` bu alani ZATEN okuyor, yani gorsel cizimi eklendigi ANDA sahada
// somurulebilir hale gelirdi.
//
// ⚠️ YAPMA: bu alani geri ekleme. Medya gelince URL **sunucuda turetilecek**
//
//	(medya kaydinin id'sinden; bkz. medya-plani.md). Istemci ASLA URL vermez.
type sendMessageReq struct {
	Type      string `json:"type"`    // text, image, video, audio, location, document
	Content   string `json:"content"` // metin ya da medya ALTYAZISI
	ReplyToID *int64 `json:"reply_to_id"`
	// TURU 74: yuklenmis ve DOGRULANMIS medya kaydinin kimligi.
	// ⚠️ URL DEGIL id: istemci adres veremez (bkz. media_url serhi).
	MediaID *string `json:"media_id"`
	// TURU 74: ag zaman asimindan sonra tekrar denenen POST IKINCI MESAJ URETMESIN.
	// ⚠️ Kismi UNIQUE index (chat_id, sender_id, client_ref) bunu DB seviyesinde garanti eder.
	ClientRef string `json:"client_ref"`
}

// POST /chats/{chatID}/messages — mesaj gonder (once DB, sonra Redis yayini)
func (h *Handler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")

	var req sendMessageReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	if req.Type == "" {
		req.Type = "text"
	}
	// ⚠️ TURU 59 — TIP BEYAZ LISTESI. Eskiden istemcinin gonderdigi `type` DOGRULANMADAN
	// INSERT ediliyordu; DB CHECK'i 'system'e izin verdigi icin HERHANGI BIR KULLANICI
	// `{"type":"system","content":"Gebzem Destek: hesabiniz askiya alindi..."}` gonderip
	// karsi tarafta GONDEREN ADI/AVATARI/TIKI OLMAYAN, sunucu uretimi gibi gorunen bir
	// satir cizdirebiliyordu (kimlik taklidi). 'system' YALNIZ sunucunun kendi yazdigi
	// arama kayitlari icindir (calls paketi dogrudan INSERT eder, buradan gecmez).
	// ⚠️ YAPMA: bu beyaz listeye 'system' ekleme.
	switch req.Type {
	case "text", "image", "video", "audio", "location", "document":
	default:
		httpErr(w, http.StatusBadRequest, "geçersiz mesaj tipi")
		return
	}

	// uyelik kontrolu
	members, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	// ⚠️⚠️ TURU 74 — ENGEL KONTROLU (eskiden YOKTU; yukaridaki yorum "engel kontrolu"
	// diyordu ama `chatMemberIDs` yalnizca uyelige bakiyordu -> engelleme SAHADA
	// HIC CALISMIYORDU). ⚠️ YAPMA: bu blogu kaldirma.
	// ⚠️ Hata durumunda FAIL-CLOSED: engel sorgusu patlarsa mesaji GECIRME.
	// ⚠️⚠️ TURU 74b (DENETIM BULGUSU): engel kontrolu YALNIZ 1:1 sohbette.
	// `engelliMi` uyelerden HERHANGI biriyle engel iliskisi varsa true doner;
	// 20 kisilik grupta biri seni engellemisse GRUBA HIC MESAJ ATAMAZDIN ve
	// hata metni bilincli olarak notr oldugu icin sebebini de anlayamazdin.
	// WhatsApp'ta da engelleme yalniz 1:1'i etkiler.
	engelli, err := h.engelliMi(r, chatID, userID, members)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "mesaj gönderilemedi")
		return
	}
	if engelli {
		// ⚠️ Neden 403 ve NOTR metin: "seni engelledi" demek engellemeyi IFSA eder.
		//     WhatsApp da bunu gizler. Istemci mesaji gonderilmemis olarak isaretler.
		httpErr(w, http.StatusForbidden, "bu kişiye mesaj gönderilemiyor")
		return
	}

	// ⚠️⚠️ TURU 74 — MEDYA BAGLAMA. Istemci URL DEGIL `media_id` verir; sahiplik ve
	// durum BURADA dogrulanir. Aksi halde biri baskasinin (ya da dogrulanmamis)
	// medyasini kendi mesajina baglayabilirdi.
	// ⚠️ `status IN ('aktif','bagli')`: 'beklemede' KABUL EDILMEZ — o kayit commit'ten
	//    gecmemis, yani tipi/boyutu/GPS'i DOGRULANMAMIS demektir.
	// ⚠️ 'bagli' de kabul: ayni medya birden fazla mesaja baglanabilir (iletme).
	if req.MediaID != nil && *req.MediaID != "" {
		tag, err := h.db.Exec(r.Context(), `
			UPDATE media_assets SET status='bagli', linked_at=now()
			 WHERE id=$1 AND owner_id=$2 AND status IN ('aktif','bagli')`,
			*req.MediaID, userID)
		if err != nil || tag.RowsAffected() == 0 {
			httpErr(w, http.StatusForbidden, "geçersiz medya")
			return
		}
	}
	// ⚠️ Medya tipi ISE medya ZORUNLU: `{"type":"image"}` ama media_id yoksa
	//    alicida BOS balon cizilir (kullanici "gonderdim" sanir, karsi taraf hicbir
	//    sey gormez). Tip ve icerik TUTARLI olmali.
	if (req.Type == "image" || req.Type == "video" || req.Type == "audio" ||
		req.Type == "document") && (req.MediaID == nil || *req.MediaID == "") {
		httpErr(w, http.StatusBadRequest, "medya bulunamadı")
		return
	}

	var msgID int64
	var createdAt time.Time
	// ⚠️⚠️ IDEMPOTENCY: `client_ref` doluysa ve AYNI (chat, gonderen, ref) zaten
	// varsa YENI SATIR ACILMAZ; mevcut satir DONER. Mobil sebekede istemci yaniti
	// alamadan tekrar denedi diye CIFT MESAJ olusmasin.
	// ⚠️ `ON CONFLICT ... DO UPDATE SET id=EXCLUDED.id` yerine `DO NOTHING` +
	//    ikinci SELECT kullaniyoruz: DO UPDATE gereksiz yazma yapar ve sirayi bozar.
	err = h.db.QueryRow(r.Context(), `
		INSERT INTO messages (chat_id, sender_id, type, content, reply_to_id, media_id, client_ref)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		ON CONFLICT (chat_id, sender_id, client_ref) WHERE client_ref <> '' DO NOTHING
		RETURNING id, created_at`,
		chatID, userID, req.Type, req.Content, req.ReplyToID, req.MediaID,
		kisaltRef(req.ClientRef)).Scan(&msgID, &createdAt)
	if err == pgx.ErrNoRows && req.ClientRef != "" {
		// Ayni istek daha once islenmis — mevcut mesaji don (200), yenisini ACMA.
		if e := h.db.QueryRow(r.Context(), `
			SELECT id, created_at FROM messages
			 WHERE chat_id=$1 AND sender_id=$2 AND client_ref=$3`,
			chatID, userID, kisaltRef(req.ClientRef)).Scan(&msgID, &createdAt); e != nil {
			httpErr(w, http.StatusInternalServerError, "mesaj kaydedilemedi")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"id": msgID, "created_at": createdAt, "tekrar": true,
		})
		return
	}
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

	// ⚠️ TURU 76 — WS yukune de GONDEREN ADI + AVATARI. `GetMessages` bunlari
	//    donduruyor; WS yolu dondurmezse GRUPTA canli gelen mesaj ISIMSIZ cizilir
	//    ve ancak ekran yenilenince adi belirir (gorunur tutarsizlik).
	var gonderenAd string
	var gonderenAvatar *string
	h.db.QueryRow(r.Context(),
		`SELECT name, avatar_media_id FROM users WHERE id=$1`, userID).
		Scan(&gonderenAd, &gonderenAvatar)

	payload, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": userID,
		// media_url sabit BOS: istemci URL veremez (turu 74). Medya gelince sunucu turetecek.
		"type": req.Type, "content": req.Content, "media_url": "",
		"media_id":    req.MediaID,
		"reply_to_id": req.ReplyToID, "created_at": createdAt,
		"sender_name":            gonderenAd,
		"sender_avatar_media_id": gonderenAvatar,
	})
	h.hub.Publish(r.Context(), &Event{Type: "message.new", ChatID: chatID, Payload: payload, To: members})

	// Push bildirimi (async): gonderen adiyla alicilara
	if h.push != nil {
		var senderName string
		h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&senderName)
		preview := req.Content
		switch req.Type {
		case "image":
			preview = "Fotoğraf"
		case "video":
			preview = "Video"
		case "audio":
			preview = "Sesli mesaj"
		case "location":
			preview = "Konum"
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
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
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
		SELECT m.id, m.sender_id, m.type,
		       CASE WHEN m.deleted_for_all THEN '' ELSE m.content END,
		       CASE WHEN m.deleted_for_all THEN '' ELSE m.media_url END,
		       -- ⚠️ TURU 74: silinen mesajda medya da GIZLENIR (id sizmasin).
		       CASE WHEN m.deleted_for_all THEN NULL ELSE m.media_id END,
		       m.reply_to_id, m.deleted_for_all, m.created_at,
		       -- ⚠️ TURU 74: medya USTVERISI mesajla BIRLIKTE doner. Ayri istek
		       --    yapilsaydi 50 mesajlik sayfa 50 EK ISTEK uretirdi (N+1).
		       --    Kaldirilmis medyada (karantina/silindi) alanlar BOS doner ama
		       --    mesaj satiri DURUR — balon "bu icerik kaldirildi" cizer.
		       COALESCE(a.duration_ms,0), COALESCE(a.waveform,''),
		       COALESCE(a.width,0), COALESCE(a.height,0),
		       COALESCE(a.file_name,''), COALESCE(a.bytes,0),
		       -- ⚠️⚠️ TURU 76 — GONDEREN ADI + AVATARI. GRUP ICIN ZORUNLU:
		       --    olmadan 20 kisilik grupta tum mesajlar ISIMSIZ gri balon
		       --    olarak gorunur ve kimin yazdigi AYIRT EDILEMEZ. Yani grup
		       --    ucunu tek basina eklemek YETMEZDI.
		       --    1:1'de istemci bunlari CIZMEZ (gereksiz gurultu).
		       COALESCE(u.name,''), u.avatar_media_id
		FROM messages m
		LEFT JOIN media_assets a
		       ON a.id = m.media_id AND a.status IN ('aktif','bagli')
		LEFT JOIN users u ON u.id = m.sender_id
		WHERE m.chat_id=$1 AND m.id<$2
		  -- ⚠️ TURU 76: "sohbeti temizle" damgasindan onceki mesajlar GORUNMEZ.
		  --    Satirlar SILINMEZ (karsi tarafin gecmisi + "veri silinmez" karari).
		  AND m.created_at > COALESCE(
		        (SELECT cleared_at FROM chat_members
		          WHERE chat_id=$1 AND user_id=$4), '-infinity'::timestamptz)
		ORDER BY m.id DESC LIMIT $3`, chatID, beforeID, limit, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatası")
		return
	}
	defer rows.Close()

	type msg struct {
		ID            int64     `json:"id"`
		SenderID      string    `json:"sender_id"`
		Type          string    `json:"type"`
		Content       string    `json:"content"`
		MediaURL      string    `json:"media_url"`
		MediaID       *string   `json:"media_id,omitempty"` // turu 74
		ReplyToID     *int64    `json:"reply_to_id"`
		DeletedForAll bool      `json:"deleted_for_all"`
		CreatedAt     time.Time `json:"created_at"`
		// TURU 74 — medya ustverisi (N+1 istekten kacinmak icin mesajla birlikte)
		DurationMs int    `json:"duration_ms,omitempty"`
		Waveform   string `json:"waveform,omitempty"`
		Width      int    `json:"width,omitempty"`
		Height     int    `json:"height,omitempty"`
		FileName   string `json:"file_name,omitempty"`
		Bytes      int64  `json:"bytes,omitempty"`
		// ⚠️ TURU 76 — GRUP ICIN ZORUNLU (bkz. sorgudaki serh).
		SenderName          string  `json:"sender_name,omitempty"`
		SenderAvatarMediaID *string `json:"sender_avatar_media_id,omitempty"`
	}
	out := []msg{}
	for rows.Next() {
		var m msg
		// ⚠️ SCAN SIRASI SELECT ile BIREBIR.
		if err := rows.Scan(&m.ID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.MediaID,
			&m.ReplyToID, &m.DeletedForAll, &m.CreatedAt,
			&m.DurationMs, &m.Waveform, &m.Width, &m.Height, &m.FileName, &m.Bytes,
			&m.SenderName, &m.SenderAvatarMediaID); err == nil {
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
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}

	// engel kontrolu (cift yonlu)
	var blocked bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		userID, req.UserID).Scan(&blocked)
	if blocked {
		httpErr(w, http.StatusForbidden, "bu kullanıcıyla sohbet başlatılamıyor")
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
			httpErr(w, http.StatusInternalServerError, "sunucu hatası")
			return
		}
		defer tx.Rollback(r.Context())
		if err := tx.QueryRow(r.Context(),
			`INSERT INTO chats (type, created_by) VALUES ('direct',$1) RETURNING id`, userID).Scan(&chatID); err != nil {
			httpErr(w, http.StatusInternalServerError, "sohbet oluşturulamadı")
			return
		}
		for _, uid := range []string{userID, req.UserID} {
			if _, err := tx.Exec(r.Context(),
				`INSERT INTO chat_members (chat_id, user_id) VALUES ($1,$2)`, chatID, uid); err != nil {
				httpErr(w, http.StatusInternalServerError, "sohbet oluşturulamadı")
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
		       -- ⚠️ TURU 76: grupta sohbetin KENDI avatari, 1:1'de karsi tarafinki.
		       CASE WHEN c.type='direct' THEN peer.avatar_media_id ELSE c.avatar_media_id END,
		       cm.pinned, cm.archived,
		       COALESCE(lm.content,''), COALESCE(lm.type,''),
		       COALESCE(lm.sender_id::text,''), lm.created_at,
		       (SELECT COUNT(*) FROM message_receipts mr
		        JOIN messages m ON m.id=mr.message_id
		        WHERE m.chat_id=c.id AND mr.user_id=$1 AND mr.read_at IS NULL AND m.sender_id<>$1
		          -- ⚠️ TURU 76: temizlenen sohbetin ESKI okunmamislari sayilmasin.
		          AND m.created_at > COALESCE(cm.cleared_at, '-infinity'::timestamptz)) AS unread,
		       peer.id AS peer_id,
		       cm.muted_until IS NOT NULL AND cm.muted_until > now() AS sessiz
		FROM chats c
		JOIN chat_members cm ON cm.chat_id=c.id AND cm.user_id=$1
		LEFT JOIN LATERAL (
			SELECT u.id, u.name, u.avatar_url, u.avatar_media_id FROM chat_members cm2
			JOIN users u ON u.id = cm2.user_id
			WHERE cm2.chat_id = c.id AND cm2.user_id <> $1
			LIMIT 1
		) peer ON c.type='direct'
		LEFT JOIN LATERAL (
			SELECT content, type, sender_id, created_at FROM messages
			WHERE chat_id=c.id AND NOT deleted_for_all
			  -- ⚠️ TURU 76: "sohbeti temizle" damgasindan ONCEKI mesajlar
			  --    ONIZLEMEDE de gorunmemeli, yoksa kullanici sildigi sohbetin
			  --    son mesajini listede gormeye devam ederdi.
			  AND created_at > COALESCE(cm.cleared_at, '-infinity'::timestamptz)
			ORDER BY id DESC LIMIT 1
		) lm ON true
		ORDER BY cm.pinned DESC, lm.created_at DESC NULLS LAST`, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatası")
		return
	}
	defer rows.Close()

	type chatRow struct {
		ID        string `json:"id"`
		Type      string `json:"type"`
		Title     string `json:"title"`
		AvatarURL string `json:"avatar_url"`
		// ⚠️⚠️ TURU 76: `avatar_url` sunucuda HIC YAZILMIYOR (kalici bos string) —
		//    sohbet listesi ve "Sik gorustuklerin" seridi bu yuzden DAIMA harf
		//    cizyordu. Fotograf ancak bu alanla gorunur.
		AvatarMediaID *string `json:"avatar_media_id,omitempty"`
		Pinned        bool    `json:"pinned"`
		Archived      bool    `json:"archived"`
		LastMessage   string  `json:"last_message"`
		LastType      string  `json:"last_type"`
		// TURU 59: son mesajin gondereni. Sohbet LISTESI arama kaydi onizlemesinde
		// YON gerekiyor ("Cevapsiz sesli arama" yalniz ARANAN icin dogrudur; arayan
		// icin "Sesli arama" yazilmali — WhatsApp da boyle). Bu alan olmadan
		// onizleme arayana da "Cevapsiz" diyordu.
		LastSender string     `json:"last_sender_id"`
		LastAt     *time.Time `json:"last_at"`
		Unread     int        `json:"unread"`
		PeerID     *string    `json:"peer_id"` // direct sohbette karsi taraf (arama icin)
		// ⚠️ TURU 76: `muted_until` sutunu 001'den beri vardi ama ONA YAZAN DA
		//    OKUYAN DA YOKTU (olu sutun). Artik sessize alma calisiyor.
		Sessiz bool `json:"muted"`
	}
	out := []chatRow{}
	for rows.Next() {
		var c chatRow
		// ⚠️ SIRA SELECT ile BIREBIR ayni olmali (pgx konuma gore tarar).
		if err := rows.Scan(&c.ID, &c.Type, &c.Title, &c.AvatarURL, &c.AvatarMediaID, &c.Pinned, &c.Archived,
			&c.LastMessage, &c.LastType, &c.LastSender, &c.LastAt, &c.Unread, &c.PeerID,
			&c.Sessiz); err == nil {
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
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	_, err = h.db.Exec(r.Context(), `
		UPDATE message_receipts mr SET read_at=now()
		FROM messages m
		WHERE m.id=mr.message_id AND m.chat_id=$1 AND mr.user_id=$2 AND mr.read_at IS NULL`, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatası")
		return
	}
	payload, _ := json.Marshal(map[string]string{"chat_id": chatID, "reader_id": userID})
	h.hub.Publish(r.Context(), &Event{Type: "receipt.read", ChatID: chatID, Payload: payload, To: members})
	writeJSON(w, http.StatusOK, map[string]string{"message": "ok"})
}

// chatMemberIDs: sohbet uyeligini dogrular, DIGER uyelerin id'lerini dondurur
// ⚠️⚠️ TURU 74 — ENGEL KONTROLU. Bu fonksiyonun cagri yerindeki yorum yillardir
// "uyelik + engel kontrolu" diyordu ama govdede ENGEL KONTROLU YOKTU: `blocks`
// tablosu 001_init.sql'den beri duruyor, ona YAZAN DA OKUYAN DA yoktu.
// Yani engelleme SAHADA HIC CALISMIYORDU (engellenen kisi mesaj gondermeye devam eder).
//
// Kural: 1:1 sohbette taraflardan HERHANGI BIRI digerini engellediyse mesaj GITMEZ.
// (Engelleyen de engellenene yazamaz — WhatsApp davranisi; aksi halde tek yonlu bir
// kanal olusur ve engelleyen taraf karsisindakini rahatsiz etmeye devam edebilir.)
//
// ⚠️ Grup sohbetinde bu kural UYGULANMAZ (gruba yazmak engellenmez) — grup geldiginde
//
//	ayrica ele alinacak; bugun tum sohbetler 'direct'.
//
// ⚠️ TEK SORGU: uyelik ve engel ayni gidis-donuste cozulur (mesaj gonderme sicak yol).
// ⚠️ YAPMA: engel kontrolunu cagiranlara kopyalama — TEK KAYNAK burasi.
func (h *Handler) engelliMi(r *http.Request, chatID, userID string,
	digerleri []string) (bool, error) {
	if len(digerleri) == 0 {
		return false, nil
	}
	// ⚠️⚠️ TURU 74b (DENETIM BULGUSU): engel kontrolu YALNIZ 1:1 sohbette.
	// Bu fonksiyon uyelerden HERHANGI biriyle engel iliskisi varsa true doner;
	// grupta uygulandiginda 20 kisilik bir grupta biri seni engellemisse GRUBA
	// HIC MESAJ ATAMIYORDUN ve hata metni bilincli olarak notr oldugu icin
	// sebebini de anlayamiyordun. WhatsApp'ta da engelleme yalniz 1:1'i etkiler.
	// ⚠️ Bugun tum sohbetler 'direct'; grup gelince bu kapi ZATEN dogru davranir.
	var tur string
	if err := h.db.QueryRow(r.Context(),
		`SELECT type FROM chats WHERE id=$1`, chatID).Scan(&tur); err != nil {
		return false, err
	}
	if tur != "direct" {
		return false, nil
	}
	var n int
	err := h.db.QueryRow(r.Context(), `
		SELECT count(*) FROM blocks
		 WHERE (blocker_id = $1 AND blocked_id = ANY($2))
		    OR (blocked_id = $1 AND blocker_id = ANY($2))`,
		userID, digerleri).Scan(&n)
	return n > 0, err
}

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

// ⚠️⚠️ TURU 74 — MESAJ SILME (herkesten).
//
// DURUM TESPITI: `messages.deleted_for_all` sutunu 001_init.sql'den beri VAR ve
// listeleme sorgulari onu ZATEN okuyor (`CASE WHEN deleted_for_all THEN ” ELSE ...`),
// ama SILME UCU HIC YOKTU — yani sutun olu duruyordu.
//
// ⚠️ NEDEN ZORUNLU: App Store 1.2 (UGC) icerik kaldirmayi sart kosuyor; ayrica
// 5651 "4 saat icinde kaldirma" yukumlulugunun istemci tarafi ayagi budur.
//
// KURALLAR:
//
//	· Yalniz GONDEREN silebilir (moderator/admin yolu AYRI — admin panelinden).
//	· Icerik BOSALTILIR ama satir SILINMEZ: karsi tarafta "Bu mesaj silindi" cizilir
//	  ve mesaj sirasi/okundu bilgisi bozulmaz.
//	  ⚠️ Bu, kullanicinin "veri silinmesin" karariyla CELISMEZ — burada silmeyi
//	     KULLANICININ KENDISI talep ediyor (yasal olarak da saglanmasi ZORUNLU).
//	· Idempotent: iki kez silme 200 doner.
//	· Medya geldiginde: bu ucun icine R2 nesnesinin silinmesi de eklenecek.
//
// ⚠️ YAPMA: satiri fiziksel DELETE etme (`message_receipts` FK'si ve sohbet sirasi bozulur).
// ⚠️ YAPMA: sure siniri koyma (WhatsApp'ta var ama bizde icerik kaldirma yukumlulugu
//
//	sureli olamaz — kullanici her zaman kendi icerigini kaldirabilmeli).
func (h *Handler) DeleteMessage(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	msgID, err := strconv.ParseInt(chi.URLParam(r, "msgID"), 10, 64)
	if err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz mesaj")
		return
	}
	members, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	// ⚠️ `sender_id=$3` SART: baskasinin mesajini silmeyi ENGELLER.
	//    `chat_id=$2` SART: baska sohbetten mesaj id'si vererek silmeyi engeller.
	//
	// ⚠️⚠️ TURU 74b (DENETIM BULGUSU) — `media_id` de NULL'lanir.
	// Eskiden yalniz `content` ve `media_url` bosaltiliyor, `media_id` satirda
	// KALIYORDU. `media.erisebilir()` `deleted_for_all`a BAKMADIGI icin alici
	// `GET /media/{id}/url` ile SONSUZA KADAR yeni imzali adres alabiliyordu:
	// "herkesten sil" fotografi KALDIRMIYORDU (5651'in "4 saat icinde kaldirma"
	// ayagi da saglanmiyordu).
	// ⚠️ `RETURNING media_id` YENI degeri (NULL) dondururdu; ESKI degeri almak icin
	//    guncellemeden ONCEKI anlik goruntuye self-join yapiyoruz.
	var eskiMedya *string
	err = h.db.QueryRow(r.Context(), `
		UPDATE messages m SET deleted_for_all=true, content='', media_url='',
		                      media_id=NULL
		  FROM messages eski
		 WHERE m.id = eski.id AND m.id=$1 AND m.chat_id=$2 AND m.sender_id=$3
		 RETURNING eski.media_id`, msgID, chatID, userID).Scan(&eskiMedya)
	if err == pgx.ErrNoRows {
		// Mesaj yok, baskasina ait, ya da baska sohbette. Hangisi oldugunu SOYLEME
		// (varlik sizintisi) — tek notr yanit.
		httpErr(w, http.StatusForbidden, "bu mesaj silinemez")
		return
	}
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "mesaj silinemedi")
		return
	}
	// ⚠️ Medya BASKA bir mesaja da bagliysa (iletme) R2'den SILINMEZ — yalniz bu
	//    mesajdan kopar. Hicbir yere bagli degilse nesne silme kuyruguna girer.
	// ⚠️ Bu, "veri silinmez" karariyla CELISMEZ: silmeyi KULLANICININ KENDISI
	//    talep ediyor ve yasal olarak saglanmasi ZORUNLU.
	if eskiMedya != nil && *eskiMedya != "" {
		h.medyayiKopar(r.Context(), *eskiMedya)
	}
	payload, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "deleted_for_all": true,
	})
	// ⚠️ Kendimize de gitmeli (`append(members, userID)`) — kullanici IKINCI CIHAZINDA
	//    da silinmis gormeli. `members` cagiran kisiyi ICERMEZ (chatMemberIDs disliyor).
	h.hub.Publish(r.Context(), &Event{
		Type: "message.deleted", ChatID: chatID, Payload: payload,
		To: append(append([]string{}, members...), userID),
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// kisaltRef — istemci referansini sinirla.
// ⚠️ Sinirsiz metin UNIQUE index'i sisirir; 64 karakter bir UUID icin fazlasiyla yeter.
func kisaltRef(s string) string {
	if len(s) > 64 {
		return s[:64]
	}
	return s
}

// ⚠️⚠️ TURU 74b — MESAJ SILININCE MEDYAYI DA KALDIR.
//
// Denetim bulgusu: "herkesten sil" yalniz metni bosaltiyordu; `media_id` satirda
// kaldigi icin alici `GET /media/{id}/url` ile fotografi SONSUZA KADAR indirebiliyordu.
//
// KURALLAR:
//
//	· Medya BASKA bir mesaja da bagliysa (iletme) R2 nesnesi SILINMEZ — baskasinin
//	  sohbetindeki mesaj bozulmaz.
//	· Hicbir yere bagli degilse: satir 'silindi' isaretlenir ve nesneler silme
//	  kuyruguna girer (sweeper R2'den kaldirir).
//	· Avatar olarak kullaniliyorsa DOKUNULMAZ.
//
// ⚠️ Bu, kullanicinin "veri silinmesin" karariyla CELISMEZ: burada silmeyi
//
//	KULLANICININ KENDISI talep ediyor ve yasal olarak (KVKK + 5651 + magaza
//	kurali) saglanmasi ZORUNLU.
//
// ⚠️ Hata YUTULUR: mesaj silme islemi medya temizligi yuzunden BASARISIZ OLMAZ.
func (h *Handler) medyayiKopar(ctx context.Context, mediaID string) {
	var kalan int
	if err := h.db.QueryRow(ctx, `
		SELECT (SELECT count(*) FROM messages WHERE media_id=$1)
		     + (SELECT count(*) FROM users WHERE avatar_media_id=$1)`,
		mediaID).Scan(&kalan); err != nil {
		return
	}
	if kalan > 0 {
		return // baska mesaj/avatar hala kullaniyor
	}
	var anahtar, thumb string
	if err := h.db.QueryRow(ctx, `
		UPDATE media_assets SET status='silindi', deleted_at=now()
		 WHERE id=$1 AND status IN ('aktif','bagli')
		 RETURNING object_key, thumb_key`, mediaID).Scan(&anahtar, &thumb); err != nil {
		return
	}
	for _, a := range []string{anahtar, thumb} {
		if a != "" {
			h.db.Exec(ctx, `INSERT INTO media_delete_queue (object_key) VALUES ($1)`, a)
		}
	}
}
