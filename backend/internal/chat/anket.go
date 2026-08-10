package chat

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

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

// ⚠️⚠️⚠️ TURU 83 — ANKET ARTIK **GONDERIDE DE** OLABILIR (kullanici emri).
//
// Sema: migration 042 (`polls.message_id` ve `chat_id` NULL olabilir,
// `polls.post_id` eklendi, CHECK "tam olarak BIR sahip" zorluyor).
//
// ═══ NEDEN IKINCI BIR TABLO/PAKET ACILMADI ═══
//
// Oylama mantigi (tek/cok secim, `vote_seq`, kapatma, sayim) 040'ta yazildi
// ve uctan uca SINANDI. Ikinci bir kopya **kacinilmaz olarak DRIFT EDER** —
// bu projede "ayni kuralin iki kopyasi" hatasi ALTI kez yasandi. Bu yuzden
// `polls` yeniden kullaniliyor ve DEGISEN TEK SEY **YETKI KAPISI**:
//
//	sohbet anketi  -> `chatMemberIDs` (uyelik + engel)
//	gonderi anketi -> gonderinin GORUNURLUGU (gizli hesap, engel, yayin ani)
//
// ═══ NEDEN GERI CAGIRIM (dependency injection) ═══
//
// Gonderi gorunurlugu `internal/social`da. `chat` -> `social` importu bugun
// YOK; eklemek iki paketi birbirine baglar ve ileride `social`in `chat`e
// ihtiyaci olursa DERLEME DONGUSU olusur. Bunun yerine `main` bir fonksiyon
// gecirir; `chat` paketi `social`i HIC BILMEZ.
//
// ⚠️ NIL ISE **FAIL-CLOSED**: geri cagirim baglanmazsa gonderi anketleri
//    erisilemez olur (403). Sessizce ACIK birakmak gizli hesap gonderisinin
//    anketini herkese oylatirdi.
// ⚠️ YAPMA: bu alani kaldirip `chat` icine `internal/social` importu ekleme.
type GonderiGorunur func(ctx context.Context, postID, userID string) (bool, error)

// SetGonderiGorunur — `main` tarafindan acilista BIR KEZ cagrilir.
func (h *Handler) SetGonderiGorunur(f GonderiGorunur) { h.gonderiGorunur = f }

// GonderiAnketiYaz — bir GONDERIYE anket baglar. `internal/social` cagirir.
//
// ⚠️ `tx` DISARIDAN gelir: gonderi ve anketi AYNI islemde yazilmali. Ayri
//    islemler olsaydi anket yazilirken hata alan bir istek ANKETSIZ bir
//    gonderi birakirdi (kullanici "anket ekledim ama yok" derdi).
// ⚠️ Dogrulama (soru/secenek uzunlugu, adet) SOHBET yoluyla AYNI sabitleri
//    kullanir — iki yuzeyde farkli sinir olmasi kullaniciya aciklanamaz.
// ⚠️ Donen `pollID` cagirana verilir; `social` onu yanitta dondurur.
func (h *Handler) GonderiAnketiYaz(
	ctx context.Context, tx pgx.Tx,
	postID, creatorID, soru string, secenekler []string, coklu bool,
) (int64, error) {
	soru = strings.TrimSpace(soru)
	if soru == "" || utf8.RuneCountInString(soru) > anketMaksSoru {
		return 0, errAnketGecersiz
	}
	temiz := make([]string, 0, len(secenekler))
	for _, s := range secenekler {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if utf8.RuneCountInString(s) > anketMaksSecenek {
			return 0, errAnketGecersiz
		}
		temiz = append(temiz, s)
	}
	if len(temiz) < 2 || len(temiz) > anketMaksAdet {
		return 0, errAnketGecersiz
	}

	var pollID int64
	if err := tx.QueryRow(ctx,
		`INSERT INTO polls (post_id, creator_id, question, multi)
		 VALUES ($1,$2,$3,$4) RETURNING id`,
		postID, creatorID, soru, coklu).Scan(&pollID); err != nil {
		return 0, err
	}
	for i, s := range temiz {
		if _, err := tx.Exec(ctx,
			`INSERT INTO poll_options (poll_id, idx, text) VALUES ($1,$2,$3)`,
			pollID, i, s); err != nil {
			return 0, err
		}
	}
	return pollID, nil
}

// GonderiAnketleri — bir GONDERI KUMESININ anketlerini **TEK SORGUDA** okur.
//
// ⚠️ N+1 YASAK: 20 kartlik bir akista gonderi basina ayri sorgu atmak 20 tur
//    demekti (turu 17 dersi). Once `post_id -> poll_id` esleme tek sorguyla
//    alinir, sonra her anket `anketOku` ile okunur (o zaten secenek+sayim+
//    benim oylarim iceren TEK KAYNAK cozumdur).
// ⚠️ Hatalar YUTULUR ve o gonderi anketsiz doner: bir anket okunamadi diye
//    TUM AKISIN bosalmasi kabul edilemez (turu 76'nin "satir sessizce
//    atlaniyor" hatasinin tersi — burada gonderi cizilir, yalniz anketi yok).
func (h *Handler) GonderiAnketleri(
	ctx context.Context, postIDs []string, userID string,
) map[string]map[string]any {
	sonuc := map[string]map[string]any{}
	if len(postIDs) == 0 {
		return sonuc
	}
	rows, err := h.db.Query(ctx,
		`SELECT post_id::text, id FROM polls WHERE post_id = ANY($1)`, postIDs)
	if err != nil {
		return sonuc
	}
	tip := map[string]int64{}
	for rows.Next() {
		var pid string
		var pollID int64
		if rows.Scan(&pid, &pollID) == nil {
			tip[pid] = pollID
		}
	}
	rows.Close()
	for pid, pollID := range tip {
		if a, e := h.anketOku(ctx, pollID, userID); e == nil {
			sonuc[pid] = a
		}
	}
	return sonuc
}

var errAnketGecersiz = errors.New("gecersiz anket")

// AnketGecersizMi — cagiranin hatayi 400'e cevirebilmesi icin.
func AnketGecersizMi(err error) bool { return errors.Is(err, errAnketGecersiz) }

// anketSahibi — anketin hangi yuzeye ait oldugunu ve cagiranin YETKISINI
// tek yerde cozer.
//
// Doner: (chatID — sohbet anketiyse dolu, degilse bos), (yetkili mi), (hata).
//
// ⚠️ TEK KAYNAK: dort uc (oy ver / kapat / getir / okuma) bunu cagirir.
// ⚠️ Yuklem cagiran yerlere KOPYALANMAZ — turu 75b'de ayni kural dort sorguya
//    kopyalanmis, BESINCISINDE dusmustu ve engellenen kisi profili okuyabiliyordu.
func (h *Handler) anketSahibi(
	r *http.Request, pollID int64, userID string,
) (chatID string, ok bool, err error) {
	var cid, pid *string
	if e := h.db.QueryRow(r.Context(),
		`SELECT chat_id::text, post_id::text FROM polls WHERE id=$1`, pollID).
		Scan(&cid, &pid); e != nil {
		return "", false, e
	}
	// ---- GONDERI ANKETI
	if pid != nil {
		if h.gonderiGorunur == nil {
			// FAIL-CLOSED (bkz. serh).
			log.Printf("anket: gonderiGorunur BAGLANMAMIS — poll=%d reddedildi", pollID)
			return "", false, nil
		}
		gor, e := h.gonderiGorunur(r.Context(), *pid, userID)
		if e != nil {
			return "", false, e
		}
		return "", gor, nil
	}
	// ---- SOHBET ANKETI
	if cid == nil {
		// 042'deki CHECK bunu imkansiz kilar; yine de savunma.
		return "", false, nil
	}
	if _, e := h.chatMemberIDs(r, *cid, userID); e != nil {
		return *cid, false, nil
	}
	return *cid, true, nil
}

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

	var multi bool
	var kapali *string
	if err := h.db.QueryRow(r.Context(),
		`SELECT multi, closed_at::text FROM polls WHERE id=$1`, pollID).
		Scan(&multi, &kapali); err != nil {
		httpErr(w, http.StatusNotFound, "anket bulunamadı")
		return
	}
	if kapali != nil {
		httpErr(w, http.StatusConflict, "Bu anket kapandı")
		return
	}
	// ⚠️ TURU 83 — YETKI TEK KAYNAKTAN (`anketSahibi`): sohbet anketinde
	//    uyelik, gonderi anketinde gonderi GORUNURLUGU kontrol edilir.
	chatID, yetkili, err := h.anketSahibi(r, pollID, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "oy verilemedi")
		return
	}
	if !yetkili {
		httpErr(w, http.StatusForbidden, "bu ankete oy veremezsiniz")
		return
	}
	// ⚠️ Uye listesi YALNIZ sohbet anketinde anlamli (WS yayini icin).
	//    Gonderi anketinde `chatID` bostur ve yayin gonderi kanalindan gider.
	var uyeler []string
	if chatID != "" {
		uyeler, _ = h.chatMemberIDs(r, chatID, userID)
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
	var creator string
	if err := h.db.QueryRow(r.Context(),
		`SELECT creator_id FROM polls WHERE id=$1`, pollID).
		Scan(&creator); err != nil {
		httpErr(w, http.StatusNotFound, "anket bulunamadı")
		return
	}
	if creator != userID {
		httpErr(w, http.StatusForbidden, "anketi yalnızca oluşturan kapatabilir")
		return
	}
	// ⚠️ Olusturan olsan bile YUZEYE erisimin surmeli (engellendiysen ya da
	//    gonderi silindiyse kapatma da yapamazsin).
	chatID, yetkili, err := h.anketSahibi(r, pollID, userID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "anket kapatılamadı")
		return
	}
	if !yetkili {
		httpErr(w, http.StatusForbidden, "bu ankete erişemezsiniz")
		return
	}
	var uyeler []string
	if chatID != "" {
		uyeler, _ = h.chatMemberIDs(r, chatID, userID)
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
	// ⚠️ TURU 83 — yetki TEK KAYNAKTAN; gonderi anketi de bu uctan okunur.
	if _, yetkili, e := h.anketSahibi(r, pollID, userID); e != nil {
		httpErr(w, http.StatusNotFound, "anket bulunamadı")
		return
	} else if !yetkili {
		httpErr(w, http.StatusForbidden, "bu ankete erişemezsiniz")
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
	// ⚠️ Yayin govdesi ORTAKTIR: "benim oylarim" kisiye ozel oldugu icin
	//    yayinda ANLAMSIZDIR. Istemci kendi secimini YEREL durumundan bilir;
	//    `vote_seq` ile de eskimis olayi eler.
	//
	// ⚠️⚠️ BOS DIZE **KULLANILAMAZ** — SIFIR UUID kullaniliyor.
	//
	//	Ilk yazimda `anketOku(ctx, pollID, "")` yaziliyordu ve bu SESSIZ bir
	//	SEVK ENGELIYDI: `poll_votes.user_id` UUID sutunu, pgx `$2`yi UUID
	//	olarak cikarsiyor ve PostgreSQL bos dizeyi REDDEDIYOR
	//	(`invalid input syntax for type uuid: ""` — canli DB'de dogrulandi).
	//	Sonuc: `anketOku` HATA doner, `anketYayinla` log basip CIKAR ve
	//	**WS YAYINI HIC YAPILMAZ.** Yani biri oy verdiginde digerleri
	//	sonucu CANLI GORMEZ; ozellik sessizce "sayfayi yenile"ye duser.
	// ⚠️ Sifir UUID hicbir kullaniciya ait olamaz, yani `mine` her secenekte
	//    dogru sekilde `false` doner.
	const kimseYok = "00000000-0000-0000-0000-000000000000"
	anket, err := h.anketOku(ctx, pollID, kimseYok)
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
