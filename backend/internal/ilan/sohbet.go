package ilan

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/kimlik"
	"github.com/gbz-app/gebzem/backend/internal/sohbet"
)

// POST /ilanlar/{id}/sohbet — ILAN HAKKINDA saticiya yaz.
//
// ⚠️⚠️ TURU 78 — ILAN MESAJLASMA (kullanici emri: "ilan mesajlasma sistemi
// olmali"). Daha once ilan detayindaki "Saticiya mesaj" duz `POST /chats/direct`
// cagiriyordu; mesaj ILAN BAGLAMI TASIMIYORDU. 20 ilani olan bir satici gelen
// mesajin HANGI ILAN icin oldugunu bilemiyordu ve her seferinde sormak
// zorundaydi.
//
// ⚠️⚠️ MIMARI KARAR: `chats` tablosuna `ilan_id` SUTUNU (ayri tablo DEGIL).
//
//	Mevcut sohbet hatti — messages, message_receipts, WS `message.new`,
//	okunmamis sayaci, ENGELLEME kapisi, push bildirimi, sessize alma —
//	TAMAMEN `chats` uzerine kurulu. Ilan mesajlari icin ayri tablo acmak bu
//	YEDI mekanizmanin HEPSININ ikinci kopyasini yazmak demekti.
//	⚠️ `type` HALA 'direct' KALIR: davranis olarak birebir direkt sohbet, tek
//	   fark HANGI BAGLAMDA acildigi. Yeni bir `type` degeri `chats.type`
//	   CHECK'ini DROP/ADD etmeyi gerektirirdi (015'te yasanan migration tuzagi).
//
// ⚠️ ILAN BASINA AYRI SOHBET (sahibinden/Letgo davranisi): ayni kisi ayni ilan
//
//	icin tekrar yazarsa AYNI sohbet acilir; BASKA bir ilan icin AYRI sohbet.
//
// ⚠️ KENDI ILANINA mesaj atilamaz — kendisiyle sohbet satiri olusurdu.
func (h *Handler) SohbetAc(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	if !kimlik.Gecerli(id) {
		hata(w, 404, "ilan bulunamadı")
		return
	}

	// ⚠️ ILAN GORULEBILIR OLMALI + ENGEL KAPISI. `engelYok` TEK KAYNAK ve
	//    $1'i OKUYAN kullanici kabul eder (bkz. handler.go serhi) — bu yuzden
	//    $1=me, $2=ilan id.
	//    ⚠️ Ters yazilsaydi engel yuklemi ilan id'siyle karsilastirilir, HICBIR
	//       ZAMAN eslesmez ve kontrol SESSIZCE FAIL-OPEN olurdu.
	var sahibi string
	err := h.db.QueryRow(r.Context(), `
		SELECT i.sahibi_id FROM ilanlar i
		 WHERE i.id=$2 AND i.durum <> 'kaldirildi'`+engelYok, me, id).Scan(&sahibi)
	if err != nil {
		hata(w, 404, "ilan bulunamadı")
		return
	}
	if sahibi == me {
		hata(w, 400, "kendi ilanına mesaj gönderemezsin")
		return
	}

	// ⚠️ MEVCUT ilan sohbeti var mi (TEK KAYNAK sorgu).
	var chatID string
	if h.db.QueryRow(r.Context(), sohbet.IlanSorgu, me, sahibi, id).
		Scan(&chatID) == nil {
		yaz(w, 200, map[string]string{"chat_id": chatID})
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "sohbet açılamadı")
		return
	}
	defer tx.Rollback(r.Context())
	if tx.QueryRow(r.Context(), `
		INSERT INTO chats (type, created_by, ilan_id)
		VALUES ('direct',$1,$2) RETURNING id`, me, id).Scan(&chatID) != nil {
		hata(w, 500, "sohbet açılamadı")
		return
	}
	// ⚠️⚠️ IKI UYE DE `'member'` — 'owner' DEGIL. `chat/grup.go` uye yonetimi
	//    yetkisini role gore veriyor ve `chats.type`a BAKMIYOR; birine 'owner'
	//    yazsaydik direkt sohbette uye ekleme/cikarma yetkisi acilirdi.
	for _, uid := range []string{me, sahibi} {
		if _, e := tx.Exec(r.Context(),
			`INSERT INTO chat_members (chat_id, user_id) VALUES ($1,$2)`,
			chatID, uid); e != nil {
			hata(w, 500, "sohbet açılamadı")
			return
		}
	}
	if tx.Commit(r.Context()) != nil {
		hata(w, 500, "sohbet açılamadı")
		return
	}
	yaz(w, 200, map[string]string{"chat_id": chatID})
}
