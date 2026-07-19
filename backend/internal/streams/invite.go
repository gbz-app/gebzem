package streams

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/chat"
)

// POST /streams/{id}/invite {user_ids:[...]} — yayina DAVET (Bolum 5 B2).
// In-app bildirim modeli: WS stream.invite + offline'a NOTIFICATION-tipli FCM (CallKit YOK).
// Davet eden: yayinci VEYA aktif izleyici. Hedef basina SESSIZ atlama (engel sizdirmamak
// icin nedenler donmez); throttle 60sn hedef-basina (davetci-bagimsiz).
func (h *Handler) Invite(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var req struct {
		UserIDs []string `json:"user_ids"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if len(req.UserIDs) == 0 || len(req.UserIDs) > 10 {
		writeErr(w, http.StatusBadRequest, "1-10 kisi secin")
		return
	}

	var status, title, tip, bID, bName string
	err := h.db.QueryRow(r.Context(), `
		SELECT s.status, s.title, s.type, u.id, u.name
		FROM streams s JOIN users u ON u.id=s.broadcaster_id WHERE s.id=$1`,
		streamID).Scan(&status, &title, &tip, &bID, &bName)
	if err != nil || (status != "live" && status != "paused") {
		writeErr(w, http.StatusGone, "yayin bulunamadi veya bitti")
		return
	}
	// Davet eden yetkisi: yayinci veya aktif izleyici (Chat ucuyla ayni kural)
	if userID != bID {
		if _, err := h.rdb.ZScore(r.Context(), "stream:"+streamID+":viewers", userID).Result(); err != nil {
			writeErr(w, http.StatusForbidden, "yayinda degilsiniz")
			return
		}
	}
	if h.izleyiciSayisi(r.Context(), streamID) >= h.maxIzleyici {
		writeErr(w, http.StatusTooManyRequests, "yayin dolu")
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
		// SESSIZ atlamalar: gecersiz/unverified · engel (yayinci<->hedef VE davetci<->hedef) ·
		// banli · zaten iceride · 60sn throttle
		var ok bool
		h.db.QueryRow(r.Context(),
			`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND verified=true)`, hedef).Scan(&ok)
		if !ok {
			continue
		}
		var blocked bool
		h.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM blocks
			WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1)
			   OR (blocker_id=$3 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$3))`,
			bID, hedef, userID).Scan(&blocked)
		if blocked {
			continue
		}
		if banli, _ := h.rdb.SIsMember(r.Context(), "stream:"+streamID+":banned", hedef).Result(); banli {
			continue
		}
		if _, err := h.rdb.ZScore(r.Context(), "stream:"+streamID+":viewers", hedef).Result(); err == nil {
			continue // zaten iceride
		}
		if ok, _ := h.rdb.SetNX(r.Context(), "stream:"+streamID+":inv:"+hedef, "1", 60*time.Second).Result(); !ok {
			continue // throttle
		}
		payload, _ := json.Marshal(map[string]any{
			"stream_id": streamID, "title": title, "type": tip,
			"from_id": userID, "from_name": davetciAd,
			"broadcaster_id": bID, "broadcaster_name": bName,
		})
		h.hub.Publish(r.Context(), &chat.Event{Type: "stream.invite", Payload: payload, To: []string{hedef}})
		if !h.hub.Online(hedef) && h.push != nil {
			go h.push.DataNotify([]string{hedef}, "Canlı yayın daveti",
				davetciAd+" seni canlı yayına davet etti", map[string]string{
					"type": "stream.invite", "stream_id": streamID, "title": title,
					"from_name": davetciAd, "broadcaster_name": bName,
				})
		}
		sent++
	}
	h.audit(r.Context(), streamID, userID, "invite", clientIP(r))
	log.Printf("yayin davet: %s -> %d kisi (davetci=%s)", kisaID(streamID), sent, kisaID(userID))
	writeJSON(w, http.StatusOK, map[string]int{"sent": sent})
}
