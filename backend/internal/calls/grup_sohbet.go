package calls

import (
	"context"
	"encoding/json"
	"time"

	"github.com/gbz-app/gebzem/backend/internal/chat"
)

// GRUP ARAMASI SOHBET KAYITLARI (test turu 21 — WhatsApp deneyimi).
//
// WhatsApp'ta grup aramasi baslatilinca sohbete "Grup aramasi · Davet edildiniz" satiri
// duser; arayanin tarafinda "N kisi davet edildi" yazar; arama bitince satir "sona erdi"e
// doner. Bizde ayni is SISTEM MESAJI ile yapilir (mevcut 'call:missed:*' deseninin kardesi):
//
//	content = "call:group:invite:<callID>"  -> davet kaydi
//	content = "call:group:end:<callID>"     -> arama sona erdi kaydi
//
// Hedef sohbet:
//   - KALICI grup aramasi (chat_id dolu) -> o grup sohbeti
//   - ANLIK grup (chat_id NULL)          -> her davetlinin ARAYANLA olan DIREKT sohbeti
//     (grup sohbeti UI'si henuz yok; kullanici daveti sohbet listesinde boyle gorur)
func (h *Handler) grupAramaKaydi(ctx context.Context, callID, callerID, chatID string,
	uyeler []string, bitti bool) {
	icerik := "call:group:invite:" + callID
	if bitti {
		icerik = "call:group:end:" + callID
	}
	if chatID != "" {
		hedefler := append([]string{callerID}, uyeler...)
		h.sohbeteSistemMesaji(ctx, chatID, callerID, icerik, hedefler)
		return
	}
	for _, uid := range uyeler {
		if uid == "" || uid == callerID {
			continue
		}
		dc := h.direktSohbet(ctx, callerID, uid)
		if dc == "" {
			continue
		}
		h.sohbeteSistemMesaji(ctx, dc, callerID, icerik, []string{callerID, uid})
	}
}

// grupTumKatilimcilar — aramanin TUM katilimcilari (durumdan bagimsiz; sohbet kaydinin
// hedefleri icin). Kaydi herkes gorsun diye 'left' olanlar da dahildir.
func (h *Handler) grupTumKatilimcilar(ctx context.Context, callID string) []string {
	rows, err := h.db.Query(ctx,
		`SELECT user_id FROM call_participants WHERE call_id=$1`, callID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var uid string
		if rows.Scan(&uid) == nil {
			out = append(out, uid)
		}
	}
	return out
}

// direktSohbet — iki kullanici arasindaki direkt sohbeti bulur, yoksa olusturur
// (logMissedToChat ile ayni desen; orada satir ici yazilmisti).
func (h *Handler) direktSohbet(ctx context.Context, a, b string) string {
	var chatID string
	err := h.db.QueryRow(ctx, `
		SELECT c.id FROM chats c
		JOIN chat_members m1 ON m1.chat_id=c.id AND m1.user_id=$1
		JOIN chat_members m2 ON m2.chat_id=c.id AND m2.user_id=$2
		WHERE c.type='direct' LIMIT 1`, a, b).Scan(&chatID)
	if err == nil {
		return chatID
	}
	tx, txErr := h.db.Begin(ctx)
	if txErr != nil {
		return ""
	}
	defer tx.Rollback(ctx)
	if tx.QueryRow(ctx,
		`INSERT INTO chats (type, created_by) VALUES ('direct',$1) RETURNING id`, a).Scan(&chatID) != nil {
		return ""
	}
	for _, uid := range []string{a, b} {
		if _, e := tx.Exec(ctx,
			`INSERT INTO chat_members (chat_id, user_id) VALUES ($1,$2)`, chatID, uid); e != nil {
			return ""
		}
	}
	if tx.Commit(ctx) != nil {
		return ""
	}
	return chatID
}

// sohbeteSistemMesaji — 'system' tipli mesaj + okundu kayitlari + WS message.new.
func (h *Handler) sohbeteSistemMesaji(ctx context.Context, chatID, senderID, icerik string,
	hedefler []string) {
	var msgID int64
	var createdAt time.Time
	if h.db.QueryRow(ctx,
		`INSERT INTO messages (chat_id, sender_id, type, content) VALUES ($1,$2,'system',$3)
		 RETURNING id, created_at`, chatID, senderID, icerik).Scan(&msgID, &createdAt) != nil {
		return
	}
	for _, uid := range hedefler {
		if uid == "" {
			continue
		}
		h.db.Exec(ctx,
			`INSERT INTO message_receipts (message_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			msgID, uid)
	}
	payload, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": senderID,
		"type": "system", "content": icerik, "media_url": "",
		"reply_to_id": nil, "created_at": createdAt,
	})
	h.hub.Publish(ctx, &chat.Event{
		Type: "message.new", ChatID: chatID, Payload: payload, To: hedefler,
	})
}
