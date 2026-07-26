package calls

import (
	"context"
	"encoding/json"
	"log"

	"github.com/gbz-app/gebzem/backend/internal/chat"
)

// GERCEK MESGULLUK KONTROLU (test turu 22 — kullanici: "gruptan cikip tekrar davet edince
// hala 'kullanici zaten aramada' diyor").
//
// Eski kod SADECE DB satirina bakiyordu: `calls.status='active'` veya
// `call_participants.status='joined'`. Uygulama zorla kapatilinca / ag kopunca bu satirlar
// bir sure OLU kalabiliyor (webhook gecikirse, ya da katilimci hic 'left' isaretlenmediyse)
// ve kullanici "mesgul" gorunup ARANAMIYOR.
//
// Yeni kural: DB "mesgul" diyorsa LiveKit'e SOR — kisi gercekten o odada mi?
//
//	· odada  -> GERCEKTEN mesgul (true)
//	· odada DEGIL -> satir OLU: katilimci 'left' yapilir, oda bossa arama 'ended' olur (temizlik)
//	                 ve kisi MUSAIT sayilir (false)
//
// LiveKit'e ulasilamazsa GUVENLI tarafta kaliriz (mesgul kabul) — yanlislikla ikinci arama
// baslatip canli gorusmeyi bolmeyelim.
func (h *Handler) gercektenMesgul(ctx context.Context, uid, haricCallID string) bool {
	if uid == "" {
		return false
	}
	rows, err := h.db.Query(ctx, `
		SELECT DISTINCT c.id, COALESCE(c.is_group,false)
		FROM calls c
		LEFT JOIN call_participants p ON p.call_id=c.id AND p.user_id=$1
		WHERE c.id <> COALESCE(NULLIF($2,'')::uuid, '00000000-0000-0000-0000-000000000000'::uuid)
		  AND c.status='active'
		  AND c.created_at > now() - interval '2 hours'
		  AND (c.caller_id=$1 OR c.callee_id=$1 OR p.status='joined')`, uid, haricCallID)
	if err != nil {
		return false
	}
	type kayit struct {
		id   string
		grup bool
	}
	var liste []kayit
	for rows.Next() {
		var k kayit
		if rows.Scan(&k.id, &k.grup) == nil {
			liste = append(liste, k)
		}
	}
	rows.Close()
	if len(liste) == 0 {
		return false
	}
	if !h.Enabled() {
		return true // LiveKit yoksa eski davranis
	}
	for _, k := range liste {
		ids, lerr := h.lk.ListParticipantIdentities(ctx, "call_"+k.id)
		if lerr != nil {
			// Oda YOK hatasi = arama olu; baska hata = LiveKit'e ulasilamadi (guvenli: mesgul)
			if !lkOdaYok(lerr) {
				return true
			}
			h.oluAramaTemizle(ctx, k.id, uid, k.grup, true)
			continue
		}
		icinde := false
		for _, id := range ids {
			if id == uid {
				icinde = true
				break
			}
		}
		if icinde {
			return true // GERCEKTEN o odada -> mesgul
		}
		// Odada DEGIL -> bu satir onun icin OLU: temizle, mesgul SAYMA
		h.oluAramaTemizle(ctx, k.id, uid, k.grup, len(ids) == 0)
	}
	return false
}

// oluAramaTemizle — kisiyi aramadan dusur; oda bossa aramayi tamamen kapat.
func (h *Handler) oluAramaTemizle(ctx context.Context, callID, uid string, grup, odaBos bool) {
	if grup {
		h.db.Exec(ctx, `UPDATE call_participants SET status='left', left_at=now()
			WHERE call_id=$1 AND user_id=$2 AND status IN ('ringing','joined')`, callID, uid)
	}
	if !odaBos && grup {
		// Grupta baskalari duruyorsa arama surer
		var kalan int
		h.db.QueryRow(ctx, `SELECT count(*) FROM call_participants
			WHERE call_id=$1 AND status='joined'`, callID).Scan(&kalan)
		if kalan > 0 {
			log.Printf("mesgul temizlik: %s aramadan dusuruldu (%s surer)", kisaID(uid), kisaID(callID))
			return
		}
	}
	hedefler := h.groupRingingOrJoined(ctx, callID)
	ct, err := h.db.Exec(ctx,
		`UPDATE calls SET status='ended', ended_at=now() WHERE id=$1 AND status='active'`, callID)
	if err != nil || ct.RowsAffected() == 0 {
		return
	}
	h.db.Exec(ctx, `UPDATE call_participants SET status='left', left_at=now()
		WHERE call_id=$1 AND status IN ('ringing','joined')`, callID)
	if len(hedefler) == 0 {
		var caller, callee string
		h.db.QueryRow(ctx, `SELECT caller_id, COALESCE(callee_id::text,'') FROM calls WHERE id=$1`,
			callID).Scan(&caller, &callee)
		for _, x := range []string{caller, callee} {
			if x != "" {
				hedefler = append(hedefler, x)
			}
		}
	}
	if len(hedefler) > 0 {
		payload, _ := json.Marshal(map[string]string{"call_id": callID, "status": "ended"})
		h.hub.Publish(ctx, &chat.Event{Type: "call.ended", Payload: payload, To: hedefler})
	}
	log.Printf("mesgul temizlik: OLU arama kapatildi %s", kisaID(callID))
}

// lkOdaYok — twirp "oda bulunamadi" hatasi (rooms/streams'teki lkYok kopyasi)
func lkOdaYok(err error) bool {
	s := err.Error()
	for _, k := range []string{"not_found", "does not exist", "not found", "requested room does not exist"} {
		if containsIgnoreCase(s, k) {
			return true
		}
	}
	return false
}

func containsIgnoreCase(s, sub string) bool {
	ls, lsub := []rune(s), []rune(sub)
	if len(lsub) == 0 || len(ls) < len(lsub) {
		return false
	}
	kucuk := func(r rune) rune {
		if r >= 'A' && r <= 'Z' {
			return r + 32
		}
		return r
	}
	for i := 0; i+len(lsub) <= len(ls); i++ {
		e := true
		for j := range lsub {
			if kucuk(ls[i+j]) != kucuk(lsub[j]) {
				e = false
				break
			}
		}
		if e {
			return true
		}
	}
	return false
}
