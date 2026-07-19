package rooms

import (
	"context"
	"time"
)

// StartSweeper — takili odalari kapatir (calls.StartSweeper deseni; sweep zorunlulugu
// calls'ta kanitli: istemciden End/Leave gelmeyebilir).
// 1) HOST KOPMASI (REST leave geldi): host 2 dk'dir 'joined' degil -> oda biter
//    (Twitter Spaces davranisi; co-host devri Faz-2). 2 dk tolerans: GSM/kisa kopma.
// 2) BOS ODA: hic 'joined' yok VE son ayrilis da 2 dk'dan eski -> biter.
//    (Yalniz-host odasinda host'un 2 dk geri-donme toleransi korunur — dogrulama bulgusu:
//    eski kosul "oda 2 dk'dan yasli + su an bos" idi, solo host aninda kapaniyordu.)
// 3) LIVEKIT'TE ODA YOK: REST leave HIC gelmeden kopanlar (force-quit/crash) DB'de 'joined'
//    kalir ve 1-2'yi kilitler; ama LiveKit odasi empty_timeout(300s) ile silinmisse HERKES
//    coktan kopmus demektir -> DB'de de bitir (dogrulama bulgusu: 8 saatlik zombi oda +
//    host'un 409 "zaten acik odaniz var" kilidi).
// 4) EMNIYET: 8 saatten eski canli oda -> biter.
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
		  EXISTS (SELECT 1 FROM room_participants p
		          WHERE p.room_id=r.id AND p.role='host' AND p.status<>'joined'
		            AND p.left_at < now() - interval '2 minutes')
		  OR (r.created_at < now() - interval '2 minutes'
		      AND NOT EXISTS (SELECT 1 FROM room_participants p
		                      WHERE p.room_id=r.id AND p.status='joined')
		      AND NOT EXISTS (SELECT 1 FROM room_participants p
		                      WHERE p.room_id=r.id AND p.left_at > now() - interval '2 minutes'))
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

	// 3) LiveKit'te SILINMIS canli odalar (force-quit senaryosu). 6 dk esigi:
	// empty_timeout(300s) + pay — yeni acilan odada LiveKit'e henuz kimse baglanmadan
	// yanlis kapanis olmasin.
	rows, err = h.db.Query(ctx, `
		SELECT id FROM rooms
		WHERE status='live' AND created_at < now() - interval '6 minutes'`)
	if err != nil {
		return
	}
	var adaylar []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			adaylar = append(adaylar, id)
		}
	}
	rows.Close()
	if len(adaylar) == 0 {
		return
	}
	names := make([]string, len(adaylar))
	for i, id := range adaylar {
		names[i] = "oda_" + id
	}
	varOlan, err := h.lk.ListRoomNames(ctx, names)
	if err != nil {
		return // LiveKit'e ulasilamiyor — yanlis kapanis riskine girme
	}
	for _, id := range adaylar {
		if !varOlan["oda_"+id] {
			h.odayiBitir(ctx, id, "sweep-lk")
		}
	}

	// 4) STALE 'joined' DINLEYICI mutabakati (FAZ-2 — kullanici bulgusu: force-quit eden
	// dinleyici REST leave atamaz, DB'de 'joined' kalir -> sayi sismis/yanlis gorunur).
	// YALNIZ listener satirlari (host/speaker'a dokunma — hukum). 90sn+ eski katilimlar
	// LiveKit'te 2 ARDISIK sweep'te gorunmezse 'left' yapilir (tek goruntu = gecici
	// reconnect olabilir). eksikSayaci tek sweep goroutine'inden kullanilir.
	if h.eksikSayaci == nil {
		h.eksikSayaci = map[string]int{}
	}
	buTur := map[string]bool{}
	for _, id := range adaylar {
		if !varOlan["oda_"+id] {
			continue // oda az once kapatildi
		}
		kimler, err := h.lk.ListParticipantIdentities(ctx, "oda_"+id)
		if err != nil {
			continue // ulasamadik — yanlis dusurme riskine girme
		}
		lkVar := map[string]bool{}
		for _, k := range kimler {
			lkVar[k] = true
		}
		prows, err := h.db.Query(ctx, `SELECT user_id FROM room_participants
			WHERE room_id=$1 AND status='joined' AND role='listener'
			  AND joined_at < now() - interval '90 seconds'`, id)
		if err != nil {
			continue
		}
		var eskiler []string
		for prows.Next() {
			var uid string
			if prows.Scan(&uid) == nil {
				eskiler = append(eskiler, uid)
			}
		}
		prows.Close()
		for _, uid := range eskiler {
			key := id + "|" + uid
			if lkVar[uid] {
				delete(h.eksikSayaci, key) // geri gelmis — sayaci sifirla
				continue
			}
			h.eksikSayaci[key]++
			if h.eksikSayaci[key] >= 2 {
				h.db.Exec(ctx, `UPDATE room_participants SET status='left', left_at=now(),
					hand_raised_at=NULL WHERE room_id=$1 AND user_id=$2 AND role='listener'`, id, uid)
				h.audit(ctx, id, uid, "sweep-stale", "")
				delete(h.eksikSayaci, key)
			} else {
				buTur[key] = true
			}
		}
	}
	// Aday olmayan/biten odalarin bayat girdilerini temizle (sinirsiz birikim olmasin)
	for k := range h.eksikSayaci {
		if !buTur[k] {
			delete(h.eksikSayaci, k)
		}
	}
}
