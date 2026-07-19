package streams

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/redis/go-redis/v9"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// KONUK SISTEMI (Bolum 6 B3): izleyici "katil istegi" -> yayinci kabul -> izleyici KONUK olur
// (kamera+mic canli, hidden kalkar). Rol kaynagi REDIS: stream:{id}:guest STRING (SET NX =
// ayni anda TEK konuk atomik) + stream:{id}:guest_reqs ZSET (istek listesi). Konuk viewers
// ZSET'inde KALIR (nabiz/chat/hediye degismez).

func (h *Handler) dataTo(ctx context.Context, streamID string, v map[string]any, hedefler []string) {
	b, _ := json.Marshal(v)
	if err := h.lk.SendDataTo(ctx, "stream_"+streamID, b, "meta", hedefler); err != nil {
		log.Printf("yayin dataTo: %v", err)
	}
}

// lkYokS — twirp "katilimci/oda yok" (bagli-degil; rooms'taki lkYok kopyasi — paket private)
func lkYokS(err error) bool {
	s := strings.ToLower(err.Error())
	return strings.Contains(s, "not_found") || strings.Contains(s, "does not exist") ||
		strings.Contains(s, "not found")
}

// POST /streams/{id}/join-request {cancel} — izleyici katilma istegi (yalniz yayinciya sinyal)
func (h *Handler) JoinRequest(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var req struct {
		Cancel bool `json:"cancel"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	var status, bID string
	if h.db.QueryRow(r.Context(), `SELECT status, broadcaster_id FROM streams WHERE id=$1`,
		streamID).Scan(&status, &bID) != nil || (status != "live" && status != "paused") {
		writeErr(w, http.StatusGone, "yayin bitti")
		return
	}
	if _, err := h.rdb.ZScore(r.Context(), "stream:"+streamID+":viewers", userID).Result(); err != nil {
		writeErr(w, http.StatusForbidden, "yayinda degilsiniz")
		return
	}
	if banli, _ := h.rdb.SIsMember(r.Context(), "stream:"+streamID+":banned", userID).Result(); banli {
		writeErr(w, http.StatusForbidden, "yayindan cikarildiniz")
		return
	}
	if req.Cancel {
		h.rdb.ZRem(r.Context(), "stream:"+streamID+":guest_reqs", userID)
		h.dataTo(r.Context(), streamID, map[string]any{"t": "guest.request.cancel", "user_id": userID}, []string{bID})
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		return
	}
	// throttle 10sn + istek listesi tavani
	if ok, _ := h.rdb.SetNX(r.Context(), "stream:"+streamID+":jreq:"+userID, "1", 10*time.Second).Result(); !ok {
		writeErr(w, http.StatusTooManyRequests, "cok sik deneme")
		return
	}
	if n, _ := h.rdb.ZCard(r.Context(), "stream:"+streamID+":guest_reqs").Result(); n >= 100 {
		writeErr(w, http.StatusTooManyRequests, "istek listesi dolu")
		return
	}
	h.rdb.ZAdd(r.Context(), "stream:"+streamID+":guest_reqs",
		redis.Z{Score: float64(time.Now().Unix()), Member: userID})
	var ad, avatar string
	h.db.QueryRow(r.Context(), `SELECT name, COALESCE(avatar_url,'') FROM users WHERE id=$1`, userID).
		Scan(&ad, &avatar)
	h.dataTo(r.Context(), streamID, map[string]any{
		"t": "guest.request", "user_id": userID, "name": ad, "avatar": avatar,
	}, []string{bID})
	h.audit(r.Context(), streamID, userID, "guest_request", "")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// GET /streams/{id}/join-requests — yayinci: bekleyen istekler (eski->yeni, ilk 50)
func (h *Handler) JoinRequests(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var bID string
	if h.db.QueryRow(r.Context(), `SELECT broadcaster_id FROM streams WHERE id=$1 AND status IN ('live','paused')`,
		streamID).Scan(&bID) != nil || bID != userID {
		writeErr(w, http.StatusForbidden, "yalniz yayinci")
		return
	}
	ids, _ := h.rdb.ZRange(r.Context(), "stream:"+streamID+":guest_reqs", 0, 49).Result()
	writeJSON(w, http.StatusOK, h.kullaniciListesi(r.Context(), ids, ""))
}

// kullaniciListesi — id sirasi korunarak ad/avatar doldur (viewers/istek listeleri ortak)
func (h *Handler) kullaniciListesi(ctx context.Context, ids []string, guestID string) []map[string]any {
	out := []map[string]any{}
	if len(ids) == 0 {
		return out
	}
	rows, err := h.db.Query(ctx,
		`SELECT id, name, COALESCE(avatar_url,'') FROM users WHERE id = ANY($1)`, ids)
	if err != nil {
		return out
	}
	defer rows.Close()
	m := map[string][2]string{}
	for rows.Next() {
		var id, ad, av string
		if rows.Scan(&id, &ad, &av) == nil {
			m[id] = [2]string{ad, av}
		}
	}
	for _, id := range ids {
		if v, ok := m[id]; ok {
			out = append(out, map[string]any{
				"user_id": id, "name": v[0], "avatar": v[1], "is_guest": id == guestID,
			})
		}
	}
	return out
}

// POST /streams/{id}/guest/accept {user_id} — yayinci izleyiciyi KONUGA alir.
// Istek SARTI ARANMAZ (izleyici listesinden dogrudan "canliya al" da bu uctan gecer).
func (h *Handler) GuestAccept(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var bID, tip string
	if h.db.QueryRow(r.Context(), `SELECT broadcaster_id, type FROM streams WHERE id=$1 AND status IN ('live','paused')`,
		streamID).Scan(&bID, &tip) != nil || bID != userID {
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
	if _, err := h.rdb.ZScore(r.Context(), "stream:"+streamID+":viewers", req.UserID).Result(); err != nil {
		writeErr(w, http.StatusConflict, "izleyici yayinda degil")
		return
	}
	if banli, _ := h.rdb.SIsMember(r.Context(), "stream:"+streamID+":banned", req.UserID).Result(); banli {
		writeErr(w, http.StatusConflict, "bu kullanici yayindan cikarilmis")
		return
	}
	// TEK konuk: SET NX atomik kapi
	ok, _ := h.rdb.SetNX(r.Context(), "stream:"+streamID+":guest", req.UserID, 12*time.Hour).Result()
	if !ok {
		writeErr(w, http.StatusConflict, "zaten bir konuk var — once onu cikarin")
		return
	}
	if err := h.lk.SetStreamGuest(r.Context(), "stream_"+streamID, req.UserID, true); err != nil {
		h.rdb.Del(r.Context(), "stream:"+streamID+":guest") // GERI AL (rooms rollback deseni)
		if lkYokS(err) {
			writeErr(w, http.StatusConflict, "izleyici su an bagli degil")
		} else {
			log.Printf("konuk accept lk: %v", err)
			writeErr(w, http.StatusBadGateway, "konuk alinamadi, tekrar deneyin")
		}
		return
	}
	h.rdb.ZRem(r.Context(), "stream:"+streamID+":guest_reqs", req.UserID)
	var ad string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, req.UserID).Scan(&ad)
	h.dataTo(r.Context(), streamID, map[string]any{"t": "guest.accepted"}, []string{req.UserID})
	h.data(r.Context(), streamID, map[string]any{"t": "guest.joined", "user_id": req.UserID, "name": ad})
	h.audit(r.Context(), streamID, req.UserID, "guest_accept", "")
	log.Printf("yayin konuk: %s -> %s KONUK", kisaID(streamID), kisaID(req.UserID))
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/guest/decline {user_id} — yayinci istegi reddeder
func (h *Handler) GuestDecline(w http.ResponseWriter, r *http.Request) {
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
	h.rdb.ZRem(r.Context(), "stream:"+streamID+":guest_reqs", req.UserID)
	h.dataTo(r.Context(), streamID, map[string]any{"t": "guest.declined"}, []string{req.UserID})
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// konukDusur — leave/remove/kick/sweep/end ortak yolu (idempotent)
func (h *Handler) konukDusur(ctx context.Context, streamID, uid, neden string) {
	cur, _ := h.rdb.Get(ctx, "stream:"+streamID+":guest").Result()
	if cur != uid || uid == "" {
		return
	}
	h.rdb.Del(ctx, "stream:"+streamID+":guest")
	if err := h.lk.SetStreamGuest(ctx, "stream_"+streamID, uid, false); err != nil {
		log.Printf("konuk dusur lk (%s): %v", neden, err) // lkYok tolere: track'ler zaten olur
	}
	h.data(ctx, streamID, map[string]any{"t": "guest.left", "user_id": uid})
	h.audit(ctx, streamID, uid, "guest_"+neden, "")
	log.Printf("yayin konuk dustu: %s %s (%s)", kisaID(streamID), kisaID(uid), neden)
}

// POST /streams/{id}/guest/leave — konuk kendisi ayrilir (izleyicilige doner)
func (h *Handler) GuestLeave(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	h.konukDusur(r.Context(), streamID, userID, "leave")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/guest/remove {user_id} — yayinci konugu yayindan alir (izleyici kalir)
func (h *Handler) GuestRemove(w http.ResponseWriter, r *http.Request) {
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
	h.konukDusur(r.Context(), streamID, req.UserID, "remove")
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// POST /streams/{id}/guest/refresh — FULL reconnect kurtarmasi (D4): konuk grant'i token'dan
// geri yuklenmis olabilir; konuk anahtari hala bendeyse izni idempotent yeniden uygula.
func (h *Handler) GuestRefresh(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	cur, _ := h.rdb.Get(r.Context(), "stream:"+streamID+":guest").Result()
	if cur != userID {
		writeErr(w, http.StatusForbidden, "konuk degilsiniz")
		return
	}
	if err := h.lk.SetStreamGuest(r.Context(), "stream_"+streamID, userID, true); err != nil {
		writeErr(w, http.StatusBadGateway, "yenilenemedi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// GET /streams/{id}/viewers — izleyici listesi (ilk 100; yetki: yayinci VEYA izleyici)
func (h *Handler) Viewers(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
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
	ids, _ := h.rdb.ZRevRange(r.Context(), "stream:"+streamID+":viewers", 0, 99).Result()
	guest, _ := h.rdb.Get(r.Context(), "stream:"+streamID+":guest").Result()
	toplam, _ := h.rdb.ZCard(r.Context(), "stream:"+streamID+":viewers").Result()
	writeJSON(w, http.StatusOK, map[string]any{
		"total": toplam, "viewers": h.kullaniciListesi(r.Context(), ids, guest),
	})
}
