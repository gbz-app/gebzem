package streams

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// Hediye katalogu SUNUCUDA (istemciden fiyat ALINMAZ — manipulasyon engeli).
// Baglayici Karar 3: gul=10, kalp=50, roket=500.
type hediye struct {
	ID    string `json:"id"`
	Ad    string `json:"ad"`
	Emoji string `json:"emoji"`
	Jeton int64  `json:"jeton"`
}

var katalog = []hediye{
	{ID: "gul", Ad: "Gül", Emoji: "🌹", Jeton: 10},
	{ID: "kalp", Ad: "Kalp", Emoji: "💜", Jeton: 50},
	{ID: "roket", Ad: "Roket", Emoji: "🚀", Jeton: 500},
}

func katalogListesi() []hediye { return katalog }

func hediyeBul(id string) *hediye {
	for i := range katalog {
		if katalog[i].ID == id {
			return &katalog[i]
		}
	}
	return nil
}

// POST /streams/{id}/gift {gift, idem} — jeton dus + yayinciya ekle + animasyon fan-out.
// TEK transaction; (user_id, reason, ref_id) unique indeksi retry'da cift harcamayi keser.
func (h *Handler) Gift(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	streamID := chi.URLParam(r, "id")
	var req struct {
		Gift string `json:"gift"`
		Idem string `json:"idem"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	g := hediyeBul(req.Gift)
	req.Idem = strings.TrimSpace(req.Idem)
	if g == nil || req.Idem == "" || len(req.Idem) > 64 {
		writeErr(w, http.StatusBadRequest, "gecersiz hediye")
		return
	}
	// Gonderen ref'i kullanici-kapsamli unique (uq_ledger_idem user_id'li); alici ref'ine
	// GONDEREN de eklenir — iki FARKLI gonderen ayni idem stringini kullanirsa yayincinin
	// gift_received satiri 23505'e takilip tx'i oldurmesin (dogrulama bulgusu).
	refGonderen := streamID + ":" + req.Idem
	refAlici := streamID + ":" + userID + ":" + req.Idem

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}
	defer tx.Rollback(r.Context())

	var bID, status string
	if err := tx.QueryRow(r.Context(),
		`SELECT broadcaster_id, status FROM streams WHERE id=$1 FOR UPDATE`, streamID).Scan(&bID, &status); err != nil {
		writeErr(w, http.StatusGone, "yayin bulunamadi")
		return
	}
	if status != "live" && status != "paused" {
		writeErr(w, http.StatusGone, "yayin bitti")
		return
	}
	if bID == userID {
		writeErr(w, http.StatusBadRequest, "kendinize hediye gonderemezsiniz")
		return
	}
	// GUVENLIK (dogrulama bulgusu): kick bani + engel + izleyici uyeligi — Watch/Chat ile
	// ayni kurallar; atilan/engellenen kullanici hediye yoluyla yayina geri sizamaz.
	if banli, _ := h.rdb.SIsMember(r.Context(), "stream:"+streamID+":banned", userID).Result(); banli {
		writeErr(w, http.StatusForbidden, "yayindan cikarildiniz")
		return
	}
	var blocked bool
	tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		bID, userID).Scan(&blocked)
	if blocked {
		writeErr(w, http.StatusForbidden, "hediye gonderilemez")
		return
	}
	if _, err := h.rdb.ZScore(r.Context(), "stream:"+streamID+":viewers", userID).Result(); err != nil {
		writeErr(w, http.StatusForbidden, "yayinda degilsiniz")
		return
	}
	// KILITLENME ONLEMI (dogrulama bulgusu): iki kullanici birbirinin yayinlarina ayni anda
	// hediye atarsa AB-BA deadlock olabilir — users satir kilitlerini HEP ayni sirada
	// (kucuk id once) al.
	ilk, son := userID, bID
	if son < ilk {
		ilk, son = son, ilk
	}
	var bir int
	if err := tx.QueryRow(r.Context(), `SELECT 1 FROM users WHERE id=$1 FOR UPDATE`, ilk).Scan(&bir); err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}
	if err := tx.QueryRow(r.Context(), `SELECT 1 FROM users WHERE id=$1 FOR UPDATE`, son).Scan(&bir); err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}
	// Bakiye kontrolu + dusme ATOMIK (ayri SELECT yarisi yok)
	tag, err := tx.Exec(r.Context(),
		`UPDATE users SET coin_balance = coin_balance - $1 WHERE id=$2 AND coin_balance >= $1`,
		g.Jeton, userID)
	if err != nil || tag.RowsAffected() == 0 {
		writeErr(w, http.StatusPaymentRequired, "yetersiz jeton")
		return
	}
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO coin_ledger (user_id, amount, reason, ref_id) VALUES ($1, $2, 'gift_sent', $3)`,
		userID, -g.Jeton, refGonderen); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			// Idempotent tekrar (retry): harcama ZATEN yapildi — rollback, cift dusme yok
			writeJSON(w, http.StatusOK, map[string]string{"status": "duplicate"})
			return
		}
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}
	// Alici tarafi: hatalar YUTULMAZ (para tutarliligi — dogrulama bulgusu)
	if _, err := tx.Exec(r.Context(),
		`UPDATE users SET coin_balance = coin_balance + $1 WHERE id=$2`, g.Jeton, bID); err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO coin_ledger (user_id, amount, reason, ref_id) VALUES ($1, $2, 'gift_received', $3)`,
		bID, g.Jeton, refAlici); err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}
	if _, err := tx.Exec(r.Context(),
		`UPDATE streams SET gift_coins = gift_coins + $1 WHERE id=$2`, g.Jeton, streamID); err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}

	var bakiye int64
	tx.QueryRow(r.Context(), `SELECT coin_balance FROM users WHERE id=$1`, userID).Scan(&bakiye)
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "hediye gonderilemedi")
		return
	}

	// Commit SONRASI fan-out: herkes (yayinci dahil) animasyonu sunucudan alir
	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	h.data(r.Context(), streamID, map[string]any{
		"t": "gift", "gift": g.ID, "emoji": g.Emoji, "coins": g.Jeton,
		"from_id": userID, "from_name": name,
	})
	h.audit(r.Context(), streamID, userID, "gift:"+g.ID, "")
	log.Printf("yayin hediye: %s -> %s %s (%d jeton)", kisaID(userID), kisaID(streamID), g.ID, g.Jeton)
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "balance": bakiye})
}
