package calls

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/livekit"
)

// POST /livekit/webhook — TEST TURU 19: "kapatinca ANINDA bitsin".
//
// Neden: uygulama zorla kapatilinca / ag kopunca istemci `end` GONDEREMEZ; arama satiri
// 'active' kalir ve o kullanici ~90sn (sweeper) "baska gorusmede" gorunur. LiveKit
// webhook'u odadan cikisi ANINDA haber verir -> satir hemen kapanir, kullanici saniyesinde
// yeniden aranabilir/arayabilir. Ayni sey CANLI YAYIN icin de gecerli (yeni yayin acabilme).
//
// KURAL: satiri YALNIZ oda GERCEKTEN BOSALDIGINDA kapatiyoruz (numParticipants==0 veya
// room_finished). Tek katilimcinin ANLIK KOPUP geri baglanmasi (mobil ag) aramayi OLDURMEZ —
// karsi taraf odada kaldigi surece dokunulmaz.
func (h *Handler) LiveKitWebhook(w http.ResponseWriter, r *http.Request) {
	olay, err := livekit.WebhookCoz(r, os.Getenv("LIVEKIT_API_KEY"), os.Getenv("LIVEKIT_API_SECRET"))
	if err != nil {
		log.Printf("livekit webhook dogrulama: %v", err)
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	w.WriteHeader(http.StatusOK) // LiveKit'i bekletme; isi arka planda bitir
	oda := olay.Room.Name
	bos := olay.Room.NumParticipants == 0

	switch olay.Event {
	case "room_finished":
		bos = true
	case "participant_left":
		// bos = numParticipants==0 (yukarida)
	default:
		return
	}
	if !bos || oda == "" {
		return
	}
	ctx := context.Background()
	switch {
	case strings.HasPrefix(oda, "call_"):
		h.webhookAramaKapat(ctx, strings.TrimPrefix(oda, "call_"))
	case strings.HasPrefix(oda, "stream_"):
		h.webhookYayinKapat(ctx, strings.TrimPrefix(oda, "stream_"))
	}
}

// Oda bosaldi -> arama satirini ANINDA kapat (idempotent) + kalanlara call.ended.
func (h *Handler) webhookAramaKapat(ctx context.Context, callID string) {
	if callID == "" {
		return
	}
	// YALNIZ 'active': 'ringing' fazini istemci/sweeper 'missed' olarak kapatir
	// (arama gecmisinde "Cevapsiz" yazisi bozulmasin).
	var isGroup bool
	var caller, callee string
	if h.db.QueryRow(ctx, `
		SELECT COALESCE(is_group,false), caller_id, COALESCE(callee_id::text,'')
		FROM calls WHERE id=$1 AND status='active'`, callID).
		Scan(&isGroup, &caller, &callee) != nil {
		return // zaten kapali
	}
	hedefler := h.groupRingingOrJoined(ctx, callID)
	ct, err := h.db.Exec(ctx,
		`UPDATE calls SET status='ended', ended_at=now() WHERE id=$1 AND status='active'`,
		callID)
	if err != nil || ct.RowsAffected() == 0 {
		return
	}
	if isGroup {
		h.db.Exec(ctx, `UPDATE call_participants SET status='left', left_at=now()
			WHERE call_id=$1 AND status IN ('ringing','joined')`, callID)
	} else {
		hedefler = []string{}
		if caller != "" {
			hedefler = append(hedefler, caller)
		}
		if callee != "" {
			hedefler = append(hedefler, callee)
		}
	}
	if len(hedefler) > 0 {
		payload, _ := json.Marshal(map[string]string{"call_id": callID, "status": "ended"})
		h.hub.Publish(ctx, &chat.Event{Type: "call.ended", Payload: payload, To: hedefler})
	}
	log.Printf("livekit webhook: arama ANINDA kapatildi %s (oda bosaldi)", kisaID(callID))
}

// Oda bosaldi -> canli yayin satirini ANINDA kapat. Yayin paketine dokunmadan (import
// dongusu olmasin) SQL + WS ile ayni isi yapar; Redis anahtarlari TTL'li, sweeper temizler.
func (h *Handler) webhookYayinKapat(ctx context.Context, streamID string) {
	if streamID == "" {
		return
	}
	ct, err := h.db.Exec(ctx,
		`UPDATE streams SET status='ended', ended_at=now() WHERE id=$1 AND status IN ('live','paused')`,
		streamID)
	if err != nil || ct.RowsAffected() == 0 {
		return
	}
	// Kesfet listesi aninda guncellensin (yayin listeden dussun)
	h.hub.BroadcastEvent(ctx, "stream.list.changed",
		map[string]any{"action": "ended", "id": streamID})
	log.Printf("livekit webhook: yayin ANINDA kapatildi %s (oda bosaldi)", kisaID(streamID))
}
