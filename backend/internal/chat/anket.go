package chat

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 81 — SOHBET ICI ANKET.
//
// Tasarim: docs/medya-arastirma/tasarim-anket.md (669 satir). Bu dosya onun
// 2. bolumunun uyarlamasidir. Sema: migration 040.
//
// ⚠️ `chat` PAKETININ ICINDE, ayri bir paket DEGIL: uyelik kontrolu
//
//	(`chatMemberIDs`), WS yayini (`h.hub`) ve push (`h.push`) burada. Ayri
//	pakete tasinsaydi ucu de disari acilmak zorunda kalirdi.
//
// ⚠️ TIP: `messages.type='poll'` — 015'ten beri CHECK'te VARDI (olu tip),
//
//	turu 81'de beyaz listeye eklendi.
const (
	anketMaksSoru    = 300 // rune
	anketMaksSecenek = 100 // rune
	anketMaksAdet    = 12
)

type anketOlusturReq struct {
	Question string   `json:"question"`
	Options  []string `json:"options"`
	Multi    bool     `json:"multi"`
}

// POST /chats/{chatID}/polls
func (h *Handler) AnketOlustur(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")

	var req anketOlusturReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}

	// ⚠️ UZUNLUKLAR **RUNE** ILE OLCULUR. Bayt ile olcmek Turkce'de yanlis
	//    sinir verir: "ğ" UTF-8'de IKI bayttir, yani 300 baytlik bir sinir
	//    Turkce metinde ~150 harfe denk gelir ve kullanici sebepsiz reddedilir.
	soru := strings.TrimSpace(req.Question)
	if soru == "" {
		httpErr(w, http.StatusBadRequest, "Anket sorusu boş olamaz")
		return
	}
	if utf8.RuneCountInString(soru) > anketMaksSoru {
		httpErr(w, http.StatusBadRequest, "Anket sorusu çok uzun")
		return
	}

	// ⚠️ TRIM + BOS ELEME: arayuz sabit sayida alan cizdigi icin doldurulmamis
	//    kutular bos dize olarak gelir; onlari "secenek" saymak 12 sinirini
	//    yanlis tetiklerdi.
	var secenekler []string
	gorulen := map[string]bool{}
	for _, o := range req.Options {
		o = strings.TrimSpace(o)
		if o == "" {
			continue
		}
		if utf8.RuneCountInString(o) > anketMaksSecenek {
			httpErr(w, http.StatusBadRequest, "Seçenek metni çok uzun")
			return
		}
		// ⚠️ TEKRAR KONTROLU: ayni metinli iki secenek, oy sonuclarini
		//    anlamsiz kilar (kullanici hangisine bastigini ayirt edemez).
		if gorulen[o] {
			httpErr(w, http.StatusBadRequest, "Seçenekler birbirinden farklı olmalı")
			return
		}
		gorulen[o] = true
		secenekler = append(secenekler, o)
	}
	if len(secenekler) < 2 {
		httpErr(w, http.StatusBadRequest, "En az 2 seçenek gerekli")
		return
	}
	if len(secenekler) > anketMaksAdet {
		httpErr(w, http.StatusBadRequest, "En fazla 12 seçenek ekleyebilirsiniz")
		return
	}

	// ⚠️ UYELIK: `chatMemberIDs` hata verirse uye DEGILIZ (fonksiyon uyelik
	//    bulunamazsa hata doner) -> 403.
	uyeler, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}

	// ⚠️⚠️ ENGEL KONTROLU — `SendMessage` ile AYNI TEK KAYNAK (`engelliMi`).
	//    Yeni bir yuzey acarken engeli atlamak, turu 74'te kapatilan acigi
	//    baska bir kapidan geri getirirdi.
	//    ⚠️ FAIL-CLOSED: sorgu patlarsa anket OLUSTURULMAZ.
	digerleri := make([]string, 0, len(uyeler))
	for _, u := range uyeler {
		if u != userID {
			digerleri = append(digerleri, u)
		}
	}
	engelli, err := h.engelliMi(r, chatID, userID, digerleri)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}
	if engelli {
		httpErr(w, http.StatusForbidden, "bu kullanıcıyla anket paylaşılamıyor")
		return
	}

	// ---- TEK ISLEM: mesaj + anket + secenekler + makbuzlar
	//
	// ⚠️⚠️ MAKBUZLAR **ISLEMIN ICINDE**. Mevcut `SendMessage` onlari islem
	//    DISINDA, dongude ve HATAYI YUTARAK yaziyor; bir alicida basarisiz
	//    olursa o kisinin okunmamis sayaci SONSUZA KADAR yanlis kalir.
	//    Yeni yuzeyde o hatayi TEKRARLAMIYORUZ.
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}
	defer tx.Rollback(context.WithoutCancel(r.Context()))

	var msgID int64
	var olusma any
	// ⚠️ `content` = SORU: sohbet listesi onizlemesi ve arama bu alani okur.
	if err := tx.QueryRow(r.Context(), `
		INSERT INTO messages (chat_id, sender_id, type, content)
		VALUES ($1,$2,'poll',$3) RETURNING id, created_at`,
		chatID, userID, soru).Scan(&msgID, &olusma); err != nil {
		log.Printf("anket mesaj: %v", err)
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}

	var pollID int64
	if err := tx.QueryRow(r.Context(), `
		INSERT INTO polls (message_id, chat_id, creator_id, question, multi)
		VALUES ($1,$2,$3,$4,$5) RETURNING id`,
		msgID, chatID, userID, soru, req.Multi).Scan(&pollID); err != nil {
		log.Printf("anket: %v", err)
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}

	// ⚠️ `WITH ORDINALITY`: secenek SIRASI korunur. `id`ye guvenilemez —
	//    BIGSERIAL GLOBAL bir dizidir ve es zamanli iki anket olusturulursa
	//    id'ler CAPRAZLASIR.
	if _, err := tx.Exec(r.Context(), `
		INSERT INTO poll_options (poll_id, idx, text)
		SELECT $1, (i-1)::smallint, t
		  FROM unnest($2::text[]) WITH ORDINALITY AS a(t, i)`,
		pollID, secenekler); err != nil {
		log.Printf("anket secenek: %v", err)
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}

	if _, err := tx.Exec(r.Context(), `
		INSERT INTO message_receipts (message_id, user_id)
		SELECT $1, user_id FROM chat_members WHERE chat_id=$2
		ON CONFLICT DO NOTHING`, msgID, chatID); err != nil {
		log.Printf("anket makbuz: %v", err)
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		log.Printf("anket commit: %v", err)
		httpErr(w, http.StatusInternalServerError, "anket oluşturulamadı")
		return
	}

	anket, err := h.anketOku(r.Context(), pollID, userID)
	if err != nil {
		// ⚠️ Anket OLUSTU; okuma hatasi yuzunden 500 donmek yaniltici olurdu.
		//    Istemci listeyi tazeleyince gorecek.
		log.Printf("anket okuma (olusturma basarili): %v", err)
	}

	govde := map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": userID,
		"type": "poll", "content": soru, "created_at": olusma,
		"poll": anket,
	}

	// ⚠️ YAYIN **COMMIT SONRASI**: once yayinlansaydi islem geri alindiginda
	//    istemcide VAR OLMAYAN bir anket cizilirdi.
	// ⚠️  : govde ONCE marshal edilir.
	if ham, err := json.Marshal(govde); err == nil {
		h.hub.Publish(r.Context(), &Event{
			Type: "message.new", ChatID: chatID, Payload: ham, To: uyeler,
		})
	}
	if h.push != nil {
		digerleri := make([]string, 0, len(uyeler))
		for _, u := range uyeler {
			if u != userID {
				digerleri = append(digerleri, u)
			}
		}
		go h.push.NotifyUsers(digerleri, "Anket", runeKirp(soru, 70), chatID)
	}

	writeJSON(w, http.StatusCreated, govde)
}

type anketOyReq struct {
	OptionIDs []int64 `json:"option_ids"`
}

// POST /polls/{id}/vote — istenen TAM kume. `[]` = tum oylarimi geri cek.
func (h *Handler) AnketOyVer(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	pollID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz anket")
		return
	}
	var req anketOyReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}

	var chatID string
	var multi bool
	var kapali *string
	if err := h.db.QueryRow(r.Context(),
		`SELECT chat_id, multi, closed_at::text FROM polls WHERE id=$1`, pollID).
		Scan(&chatID, &multi, &kapali); err != nil {
		httpErr(w, http.StatusNotFound, "anket bulunamadı")
		return
	}
	if kapali != nil {
		httpErr(w, http.StatusConflict, "Bu anket kapandı")
		return
	}
	uyeler, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	// ⚠️ TEK SECIMLIK ankette birden fazla secenek gonderilmesi ISTEMCI
	//    HATASIDIR; sessizce ilkini almak yerine ACIKCA reddediyoruz.
	if !multi && len(req.OptionIDs) > 1 {
		httpErr(w, http.StatusBadRequest, "Bu ankette tek seçenek seçebilirsiniz")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "oy verilemedi")
		return
	}
	defer tx.Rollback(context.WithoutCancel(r.Context()))

	// ⚠️ ONCE TEMIZLE SONRA YAZ: istek "istenen TAM kume"dir, artimsal degil.
	//    Boylece oy DEGISTIRME ve GERI CEKME ayni yoldan yurur ve istemcinin
	//    "once sil sonra ekle" gibi iki istek atmasina gerek kalmaz.
	if _, err := tx.Exec(r.Context(),
		`DELETE FROM poll_votes WHERE poll_id=$1 AND user_id=$2`,
		pollID, userID); err != nil {
		httpErr(w, http.StatusInternalServerError, "oy verilemedi")
		return
	}
	if len(req.OptionIDs) > 0 {
		// ⚠️ `AND o.poll_id=$1`: baska bir ankete ait secenek id'si
		//    gonderilirse SESSIZCE ELENIR (satir eklenmez). Kontrol SQL'de
		//    cunku Go tarafinda dogrulamak ikinci bir sorgu demekti.
		if _, err := tx.Exec(r.Context(), `
			INSERT INTO poll_votes (poll_id, option_id, user_id)
			SELECT $1, o.id, $3
			  FROM poll_options o
			 WHERE o.poll_id=$1 AND o.id = ANY($2)
			ON CONFLICT DO NOTHING`,
			pollID, req.OptionIDs, userID); err != nil {
			httpErr(w, http.StatusInternalServerError, "oy verilemedi")
			return
		}
	}
	// ⚠️ `vote_seq` HER islemde artar — WS olaylarinin sirasi bu degerle
	//    korunur (bkz. migration 040 serhi).
	if _, err := tx.Exec(r.Context(),
		`UPDATE polls SET vote_seq = vote_seq + 1 WHERE id=$1`, pollID); err != nil {
		httpErr(w, http.StatusInternalServerError, "oy verilemedi")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		httpErr(w, http.StatusInternalServerError, "oy verilemedi")
		return
	}

	h.anketYayinla(r.Context(), pollID, chatID, uyeler, "poll.vote")
	anket, _ := h.anketOku(r.Context(), pollID, userID)
	writeJSON(w, http.StatusOK, anket)
}

// POST /polls/{id}/close — YALNIZ olusturan.
func (h *Handler) AnketKapat(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	pollID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz anket")
		return
	}
	var chatID, creator string
	if err := h.db.QueryRow(r.Context(),
		`SELECT chat_id, creator_id FROM polls WHERE id=$1`, pollID).
		Scan(&chatID, &creator); err != nil {
		httpErr(w, http.StatusNotFound, "anket bulunamadı")
		return
	}
	if creator != userID {
		httpErr(w, http.StatusForbidden, "anketi yalnızca oluşturan kapatabilir")
		return
	}
	uyeler, err := h.chatMemberIDs(r, chatID, userID)
	if err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	// ⚠️ `closed_at IS NULL` kapisi: ikinci kapatma isteği 0 satir etkiler ve
	//    `vote_seq` bosuna artmaz.
	tag, err := h.db.Exec(r.Context(),
		`UPDATE polls SET closed_at=now(), vote_seq=vote_seq+1
		  WHERE id=$1 AND closed_at IS NULL`, pollID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "anket kapatılamadı")
		return
	}
	if tag.RowsAffected() == 0 {
		httpErr(w, http.StatusConflict, "Bu anket zaten kapalı")
		return
	}
	h.anketYayinla(r.Context(), pollID, chatID, uyeler, "poll.closed")
	anket, _ := h.anketOku(r.Context(), pollID, userID)
	writeJSON(w, http.StatusOK, anket)
}

// GET /polls/{id}
func (h *Handler) AnketGetir(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	pollID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz anket")
		return
	}
	var chatID string
	if err := h.db.QueryRow(r.Context(),
		`SELECT chat_id FROM polls WHERE id=$1`, pollID).Scan(&chatID); err != nil {
		httpErr(w, http.StatusNotFound, "anket bulunamadı")
		return
	}
	if _, err := h.chatMemberIDs(r, chatID, userID); err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	anket, err := h.anketOku(r.Context(), pollID, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "anket okunamadı")
		return
	}
	writeJSON(w, http.StatusOK, anket)
}

// ---------------------------------------------------------------- ORTAK

// anketOku — anketin TAM anlik goruntusu (secenekler + sayimlar + benim oylarim).
//
// ⚠️ TEK KAYNAK: dort uc da bunu kullanir. Yanit sekli bir yerde elle
//
//	kurulsaydi kacinilmaz olarak DRIFT ederdi.
func (h *Handler) anketOku(ctx context.Context, pollID int64, userID string) (map[string]any, error) {
	var soru, creator string
	var multi bool
	var kapali *string
	var seq int64
	if err := h.db.QueryRow(ctx, `
		SELECT question, creator_id, multi, closed_at::text, vote_seq
		  FROM polls WHERE id=$1`, pollID).
		Scan(&soru, &creator, &multi, &kapali, &seq); err != nil {
		return nil, err
	}

	rows, err := h.db.Query(ctx, `
		SELECT o.id, o.idx, o.text,
		       (SELECT count(*) FROM poll_votes v WHERE v.option_id=o.id),
		       EXISTS(SELECT 1 FROM poll_votes v
		               WHERE v.option_id=o.id AND v.user_id=$2)
		  FROM poll_options o
		 WHERE o.poll_id=$1
		 ORDER BY o.idx`, pollID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	secenekler := []map[string]any{}
	toplam := 0
	for rows.Next() {
		var id int64
		var idx int16
		var metin string
		var sayi int
		var benim bool
		if rows.Scan(&id, &idx, &metin, &sayi, &benim) != nil {
			continue
		}
		toplam += sayi
		secenekler = append(secenekler, map[string]any{
			"id": id, "idx": idx, "text": metin,
			"votes": sayi, "mine": benim,
		})
	}

	return map[string]any{
		"id": pollID, "question": soru, "creator_id": creator,
		"multi": multi, "closed": kapali != nil, "vote_seq": seq,
		"options": secenekler, "total_votes": toplam,
	}, nil
}

// ⚠️ Yayin govdesi `anketOku` ile AYNI: istemci tek bir cozumleyici kullanir.
func (h *Handler) anketYayinla(ctx context.Context, pollID int64,
	chatID string, uyeler []string, tur string) {
	// ⚠️ Yayin govdesi olusturanin degil, ALICININ gozunden olmali ("benim
	//    oylarim" kisiye ozeldir). Ortak govdede `mine` ANLAMSIZ olurdu, bu
	//    yuzden bos kullanici ile okunuyor ve istemci kendi oyunu YEREL
	//    durumundan biliyor; `vote_seq` ile de eskimis olayi eliyor.
	anket, err := h.anketOku(ctx, pollID, "")
	if err != nil {
		log.Printf("anket yayin: %v", err)
		return
	}
	ham, err := json.Marshal(anket)
	if err != nil {
		log.Printf("anket yayin marshal: %v", err)
		return
	}
	h.hub.Publish(ctx, &Event{
		Type: tur, ChatID: chatID, Payload: ham, To: uyeler,
	})
}
