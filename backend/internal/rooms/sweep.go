package rooms

import (
	"context"
	"time"
)

// StartSweeper — takili odalari kapatir (calls.StartSweeper deseni; sweep zorunlulugu
// calls'ta kanitli: istemciden End gelmeyebilir).
// 1) HOST KOPMASI: host 2 dk'dir 'joined' degil -> oda biter (Twitter Spaces davranisi;
//    co-host devri Faz-2). 2 dk tolerans: GSM aramasi/kisa kopma odayi oldurmesin.
// 2) BOS ODA: 2 dk'dir hic 'joined' yok -> biter.
// 3) EMNIYET: 8 saatten eski canli oda -> biter (Spaces uzun olabilir; calls'taki 2 saat az).
func (h *Handler) StartSweeper(ctx context.Context) {
	go func() {
		t := time.NewTicker(30 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				h.sweep(ctx)
			}
		}
	}()
}

func (h *Handler) sweep(ctx context.Context) {
	rows, err := h.db.Query(ctx, `
		SELECT r.id FROM rooms r
		WHERE r.status='live' AND (
		  -- host kopmus (joined degil + 2 dk gecmis)
		  EXISTS (SELECT 1 FROM room_participants p
		          WHERE p.room_id=r.id AND p.role='host' AND p.status<>'joined'
		            AND p.left_at < now() - interval '2 minutes')
		  -- bos oda (kimse joined degil, 2 dk oldu)
		  OR (r.created_at < now() - interval '2 minutes'
		      AND NOT EXISTS (SELECT 1 FROM room_participants p
		                      WHERE p.room_id=r.id AND p.status='joined'))
		  -- emniyet: 8 saat
		  OR r.created_at < now() - interval '8 hours'
		)`)
	if err != nil {
		return
	}
	var ids []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()
	for _, id := range ids {
		h.odayiBitir(ctx, id, "sweep")
	}
}
