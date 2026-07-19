package streams

import (
	"context"
	"strconv"
	"time"
)

// StartSweeper — 15 sn'de bir (calls deseni):
// 1) Olu izleyici temizligi (45 sn nabizsiz ZREMRANGEBYSCORE) + viewer_peak + sayac yayini
//    (SendData {"t":"viewers"} — YALNIZ degistiyse; 300 kisiye gereksiz sinyal yok).
// 2) Kalp toplama: birikmis kalpleri 5 sn'de bir toplu yayinla (istek basi SendData seli olmaz).
// 3) Yayinci nabzi: pub anahtari dustu + live -> 'paused' + grace(60sn); nabiz geri geldi ->
//    'resumed'; grace da doldu -> endStream. Emniyet: 12 saatten uzun yayin -> bitir.
func (h *Handler) StartSweeper(ctx context.Context) {
	go func() {
		t := time.NewTicker(15 * time.Second)
		kalpT := time.NewTicker(5 * time.Second)
		defer t.Stop()
		defer kalpT.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-kalpT.C:
				h.kalpleriYayinla(ctx)
			case <-t.C:
				h.sweep(ctx)
			}
		}
	}()
}

func (h *Handler) canliYayinlar(ctx context.Context) []struct{ id, status string } {
	rows, err := h.db.Query(ctx,
		`SELECT id, status FROM streams WHERE status IN ('live','paused')`)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []struct{ id, status string }
	for rows.Next() {
		var s struct{ id, status string }
		if rows.Scan(&s.id, &s.status) == nil {
			out = append(out, s)
		}
	}
	return out
}

func (h *Handler) kalpleriYayinla(ctx context.Context) {
	for _, s := range h.canliYayinlar(ctx) {
		n, err := h.rdb.GetDel(ctx, "stream:"+s.id+":hearts").Result()
		if err != nil || n == "" || n == "0" {
			continue
		}
		if sayi, _ := strconv.Atoi(n); sayi > 0 {
			h.data(ctx, s.id, map[string]any{"t": "hearts", "n": sayi})
		}
	}
}

func (h *Handler) sweep(ctx context.Context) {
	esik := float64(time.Now().Add(-45 * time.Second).Unix())
	for _, s := range h.canliYayinlar(ctx) {
		vKey := "stream:" + s.id + ":viewers"
		h.rdb.ZRemRangeByScore(ctx, vKey, "-inf", strconvF(esik)) // olu izleyiciler
		// TARAMA #15: 10 dk'dan eski katilma istekleri de dussun (Leave/Kick temizligi
		// kacaklari + hic islenmeyenler 100 tavanini kalici dolduruyordu)
		istekEsik := float64(time.Now().Add(-10 * time.Minute).Unix())
		h.rdb.ZRemRangeByScore(ctx, "stream:"+s.id+":guest_reqs", "-inf", strconvF(istekEsik))
		n := h.izleyiciSayisi(ctx, s.id)

		// KONUK kopmus mu (Bolum 6 B6): guest anahtari dolu ama viewers'ta yok
		// (45sn nabizsiz -> az once silindi) -> otomatik dusur
		if guest, _ := h.rdb.Get(ctx, "stream:"+s.id+":guest").Result(); guest != "" {
			if _, err := h.rdb.ZScore(ctx, vKey, guest).Result(); err != nil {
				h.konukDusur(ctx, s.id, guest, "sweep")
			}
		}

		// Tepe izleyici + sayac yayini (yalniz DEGISTIYSE)
		h.db.Exec(ctx, `UPDATE streams SET viewer_peak = GREATEST(viewer_peak, $1) WHERE id=$2`, n, s.id)
		son, _ := h.rdb.Get(ctx, "stream:"+s.id+":lastn").Result()
		if son != strconv.Itoa(n) {
			h.rdb.Set(ctx, "stream:"+s.id+":lastn", strconv.Itoa(n), time.Hour)
			h.data(ctx, s.id, map[string]any{"t": "viewers", "n": n})
		}

		// Yayinci nabzi
		pubVar, _ := h.rdb.Exists(ctx, "stream:"+s.id+":pub").Result()
		switch {
		case s.status == "live" && pubVar == 0:
			// Yayinci koptu -> duraklat + 60 sn grace (izleyiciler odada bekler)
			h.db.Exec(ctx, `UPDATE streams SET status='paused' WHERE id=$1 AND status='live'`, s.id)
			h.rdb.Set(ctx, "stream:"+s.id+":grace", "1", 60*time.Second)
			h.data(ctx, s.id, map[string]any{"t": "stream.paused"})
		case s.status == "paused" && pubVar == 1:
			// Nabiz geri geldi -> devam
			h.db.Exec(ctx, `UPDATE streams SET status='live' WHERE id=$1 AND status='paused'`, s.id)
			h.data(ctx, s.id, map[string]any{"t": "stream.resumed"})
		case s.status == "paused" && pubVar == 0:
			if g, _ := h.rdb.Exists(ctx, "stream:"+s.id+":grace").Result(); g == 0 {
				h.endStream(ctx, s.id, "sweep-kopma") // grace doldu
			}
		}
	}
	// Emniyet: 12 saatten uzun yayinlar
	rows, err := h.db.Query(ctx,
		`SELECT id FROM streams WHERE status IN ('live','paused') AND started_at < now() - interval '12 hours'`)
	if err != nil {
		return
	}
	var eski []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			eski = append(eski, id)
		}
	}
	rows.Close()
	for _, id := range eski {
		h.endStream(ctx, id, "sweep-12h")
	}
}

func strconvF(f float64) string { return strconv.FormatFloat(f, 'f', 0, 64) }
