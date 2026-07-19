package rooms

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/chat"
)

// POST /rooms/{id}/invite {user_ids:[...]} — odaya DAVET (Bolum 5 B3). In-app bildirim
// (CallKit YOK). Davet eden: odadaki HERKES (joined; removed zaten joined olamaz).
func (h *Handler) Invite(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	roomID := chi.URLParam(r, "id")
	var req struct {
		UserIDs []string `json:"user_ids"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if len(req.UserIDs) == 0 || len(req.UserIDs) > 10 {
		writeErr(w, http.StatusBadRequest, "1-10 kisi secin")
		return
	}

	var title, hostID, hostAd string
	err := h.db.QueryRow(r.Context(), `
		SELECT r.title, r.host_id, u.name FROM rooms r JOIN users u ON u.id=r.host_id
		WHERE r.id=$1 AND r.status='live'`, roomID).Scan(&title, &hostID, &hostAd)
	if err != nil {
		writeErr(w, http.StatusNotFound, "oda bulunamadi veya bitti")
		return
	}
	var uyeMi bool
	h.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM room_participants
		WHERE room_id=$1 AND user_id=$2 AND status='joined')`, roomID, userID).Scan(&uyeMi)
	if !uyeMi {
		writeErr(w, http.StatusForbidden, "odada degilsiniz")
		return
	}
	if h.dinleyiciSayisi(r.Context(), roomID) >= maxDinleyici {
		writeErr(w, http.StatusTooManyRequests, "oda dolu")
		return
	}
	var davetciAd string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&davetciAd)

	sent := 0
	seen := map[string]bool{userID: true}
	for _, hedef := range req.UserIDs {
		if hedef == "" || seen[hedef] {
			continue
		}
		seen[hedef] = true
		var ok bool
		h.db.QueryRow(r.Context(),
			`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND verified=true)`, hedef).Scan(&ok)
		if !ok {
			continue
		}
		// removed (banli) veya zaten joined -> atla
		var durum string
		h.db.QueryRow(r.Context(), `SELECT status FROM room_participants
			WHERE room_id=$1 AND user_id=$2`, roomID, hedef).Scan(&durum)
		if durum == "removed" || durum == "joined" {
			continue
		}
		var blocked bool
		h.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM blocks
			WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1)
			   OR (blocker_id=$3 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$3))`,
			hostID, hedef, userID).Scan(&blocked)
		if blocked {
			continue
		}
		if ok, _ := h.rdb.SetNX(r.Context(), "oda:"+roomID+":inv:"+hedef, "1", 60*time.Second).Result(); !ok {
			continue
		}
		payload, _ := json.Marshal(map[string]any{
			"room_id": roomID, "title": title,
			"from_id": userID, "from_name": davetciAd, "host_name": hostAd,
		})
		h.hub.Publish(r.Context(), &chat.Event{Type: "room.invite", Payload: payload, To: []string{hedef}})
		if !h.hub.Online(hedef) && h.push != nil {
			go h.push.DataNotify([]string{hedef}, "Sesli oda daveti",
				davetciAd+" seni sesli odaya davet etti", map[string]string{
					"type": "room.invite", "room_id": roomID, "title": title, "from_name": davetciAd,
				})
		}
		sent++
	}
	h.audit(r.Context(), roomID, userID, "invite", clientIP(r))
	log.Printf("oda davet: %s -> %d kisi (davetci=%s)", kisaID(roomID), sent, kisaID(userID))
	writeJSON(w, http.StatusOK, map[string]int{"sent": sent})
}
