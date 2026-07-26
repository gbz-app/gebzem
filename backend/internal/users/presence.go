package users

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// KISI ARAMA DURUMU (test turu 17 — kullanici istegi: "baska kullanicinin profilinde
// sesli aramadaysa ses ikonu acik, goruntu kapali olsun"). Sohbet ekrani bu ucu 15sn'de
// bir sorar; karsinin SESLI/GORUNTULU aramada olup olmadigini gosterir.
//
// Kaynak DB (Redis presence'a gerek yok): 'active' arama satiri + grup katilimciligi.
// 2 saat yas siniri calls paketindeki mesgul kontrolunun AYNISI (takili satir yaniltmasin);
// olu aramalari zaten calls sweeper'i (LiveKit oda kontrolu) kapatiyor.
//
// GET /users/{id}/presence -> {"in_call":true,"call_type":"audio|video","in_stream":true}
func (h *Handler) Presence(w http.ResponseWriter, r *http.Request) {
	if auth.UserID(r.Context()) == "" {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	hedef := chi.URLParam(r, "id")
	if hedef == "" {
		writeErr(w, http.StatusBadRequest, "kullanici yok")
		return
	}
	var tip string
	// 1:1 (caller/callee) VEYA grup katilimcisi (joined)
	h.db.QueryRow(r.Context(), `
		SELECT c.type FROM calls c
		WHERE c.status='active'
		  AND c.created_at > now() - interval '2 hours'
		  AND (c.caller_id=$1::uuid OR c.callee_id=$1::uuid
		       OR EXISTS (SELECT 1 FROM call_participants p
		                  WHERE p.call_id=c.id AND p.user_id=$1::uuid AND p.status='joined'))
		ORDER BY c.created_at DESC LIMIT 1`, hedef).Scan(&tip)

	// Canli yayin yapiyor mu (yayinci) — profilde "yayinda" isareti icin
	var yayinda bool
	h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM streams WHERE broadcaster_id=$1::uuid AND status IN ('live','paused'))`,
		hedef).Scan(&yayinda)

	writeJSON(w, http.StatusOK, map[string]any{
		"in_call":   tip != "",
		"call_type": tip,
		"in_stream": yayinda,
	})
}
