package chat

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
)

// ⚠️⚠️⚠️ TURU 76 — GRUP SOHBETI + SOHBET YONETIMI (sabitle/arsivle/sessize al/sil).
//
// ═══════════ NEDEN SIMDI ═══════════
// Kullanici: "Grupta grup olusturma yok onu eklemeliyiz" +
//
//	"mesajlarda sil arsivle vs yok, mesaj sol sag yapinca cikmali".
//
// ⚠️⚠️ GRUP SOHBETI SAHADA HIC OLUSAMIYORDU: backend'deki UC `INSERT INTO chats`
//
//	ifadesinin UCU DE `'direct'` SABITINI kullaniyordu. `chats.type` CHECK'i
//	'group'a izin veriyor, `chat_members.role` sutunu 001'den beri duruyor, ama
//	`type='group'` bir satir URETILEMIYORDU.
//	Bunun bir yan etkisi daha vardi: `calls/handler.go`daki "kalici grup
//	aramasi" dali `chats.type='group'` okuyor — o dal SAHADA HIC CALISAMAZDI.
//
// ⚠️⚠️ DORT OLU SUTUN: `pinned`, `archived`, `role`, `muted_until` 001_init'ten
//
//	beri var; istemci `pinned`/`archived`i OKUYUP ekrana ciziyor ama backend'de
//	bunlara YAZAN TEK BIR UPDATE YOKTU. Projenin bilinen `blocks` (turu 74) ve
//	`deleted_for_all` (turu 74) olu-sutun sinifinin DORT yeni ornegi.
//	⚠️ DERS (besinci tekrar): bir sutun eklerken ONU YAZAN ucu da yaz.
//
// ═══════════ TASARIM KARARLARI ═══════════
//   - "Sohbeti sil" = KENDIMDEN sil. `chat_members` satiri SILINMEZ, `cleared_at`
//     damgasi atilir ve listeleme/gecmis sorgulari o damgadan sonrasini gosterir.
//     ⚠️ Satiri fiziksel silmek KARSI TARAFIN gecmisini de kaybettirirdi
//     (mesajlar paylasilan `messages` tablosunda) ve "veri silinmez" karariyla
//     celisir. WhatsApp da "sohbeti temizle"yi boyle yapar.
//   - Gruptan CIKMAK ayri: `chat_members` satiri GERCEKTEN silinir + sistem mesaji.
//   - Grup uye tavani 256 (WhatsApp deseni). ⚠️ Bu sayi `SendMessage`in
//     UYE BASINA receipt INSERT eden dongusunu de belirler; buyutulecekse once
//     o dongu toplu INSERT'e cevrilmelidir.
const grupUyeTavani = 256

// ---------------------------------------------------------------- GRUP KURMA

type grupOlusturReq struct {
	Baslik        string   `json:"title"`
	AvatarMediaID string   `json:"avatar_media_id"`
	UyeIDler      []string `json:"member_ids"`
}

// POST /chats/group — grup sohbeti olustur.
func (h *Handler) CreateGroup(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req grupOlusturReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	req.Baslik = strings.TrimSpace(req.Baslik)
	if len([]rune(req.Baslik)) < 1 || len([]rune(req.Baslik)) > 60 {
		httpErr(w, http.StatusBadRequest, "grup adı 1-60 karakter olmalı")
		return
	}
	// ⚠️ Kendini uye listesine koymus olabilir — TEKILLESTIR, yoksa
	//    `chat_members` PK ihlali ve grup HIC olusmaz.
	kume := map[string]bool{}
	uyeler := []string{}
	for _, u := range req.UyeIDler {
		if u == "" || u == me || kume[u] {
			continue
		}
		kume[u] = true
		uyeler = append(uyeler, u)
	}
	if len(uyeler) == 0 {
		httpErr(w, http.StatusBadRequest, "en az bir kişi seçin")
		return
	}
	if len(uyeler)+1 > grupUyeTavani {
		httpErr(w, http.StatusBadRequest, "grup en fazla 256 kişi olabilir")
		return
	}
	// ⚠️ ENGEL: engellenmis (ya da engellemis) kisiyi gruba EKLEYEMEZSIN.
	//    Aksi halde engelleme delinir: engellenen kisi grup uzerinden mesajlarini
	//    gormeye devam ederdi.
	for _, u := range uyeler {
		if engel.Var(r.Context(), h.db, me, u) {
			httpErr(w, http.StatusForbidden, "seçtiğiniz kişilerden biri gruba eklenemiyor")
			return
		}
	}
	// ⚠️ Avatar: istemciden gelen media_id SAHIPLIK dogrulamasindan gecer
	//    (turu 74 `avatar_url` guvenlik dersi — istemci URL/id veremez).
	var avatarID any
	if req.AvatarMediaID != "" {
		tag, err := h.db.Exec(r.Context(), `
			UPDATE media_assets SET status='bagli', linked_at=now()
			 WHERE id=$1 AND owner_id=$2 AND status IN ('aktif','bagli')`,
			req.AvatarMediaID, me)
		if err != nil || tag.RowsAffected() != 1 {
			httpErr(w, http.StatusForbidden, "geçersiz medya")
			return
		}
		avatarID = req.AvatarMediaID
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "sunucu hatası")
		return
	}
	defer tx.Rollback(r.Context())

	var chatID string
	if err := tx.QueryRow(r.Context(), `
		INSERT INTO chats (type, title, avatar_media_id, created_by)
		VALUES ('group',$1,$2,$3) RETURNING id`,
		req.Baslik, avatarID, me).Scan(&chatID); err != nil {
		log.Printf("grup insert: %v", err)
		httpErr(w, http.StatusInternalServerError, "grup oluşturulamadı")
		return
	}
	// Kurucu SAHIP, digerleri uye.
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1,$2,'owner')`,
		chatID, me); err != nil {
		httpErr(w, http.StatusInternalServerError, "grup oluşturulamadı")
		return
	}
	for _, u := range uyeler {
		if _, err := tx.Exec(r.Context(),
			`INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1,$2,'member')`,
			chatID, u); err != nil {
			httpErr(w, http.StatusInternalServerError, "grup oluşturulamadı")
			return
		}
	}
	// ⚠️ Acilis sistem mesaji: grup bos bir ekranla acilmasin ve listede
	//    "son mesaj" alani DOLU olsun (bos olursa sohbet listede EN ALTA duser).
	var ad string
	tx.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, me).Scan(&ad)
	tx.Exec(r.Context(), `
		INSERT INTO messages (chat_id, sender_id, type, content)
		VALUES ($1,$2,'system',$3)`, chatID, me, ad+" grubu oluşturdu")

	if err := tx.Commit(r.Context()); err != nil {
		httpErr(w, http.StatusInternalServerError, "grup oluşturulamadı")
		return
	}

	// ⚠️ Uyelere ANLIK haber ver: yeni grup listelerinde ANINDA belirsin.
	//    (Yakalama kancasi da var ama WS acikken beklemeye gerek yok.)
	h.hub.Publish(r.Context(), &Event{
		Type: "chat.new", ChatID: chatID, To: append(uyeler, me),
	})
	writeJSON(w, http.StatusCreated, map[string]any{"chat_id": chatID})
}

// ---------------------------------------------------------------- UYE YONETIMI

// GET /chats/{chatID}/members — grup uyeleri.
func (h *Handler) GroupMembers(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	if _, err := h.chatMemberIDs(r, chatID, me); err != nil {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_media_id, cm.role
		  FROM chat_members cm JOIN users u ON u.id = cm.user_id
		 WHERE cm.chat_id=$1
		 ORDER BY CASE cm.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
		          u.name`, chatID)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "üyeler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kadi, rol string
		var medya *string
		if rows.Scan(&id, &ad, &kadi, &medya, &rol) == nil {
			out = append(out, map[string]any{
				"id": id, "name": ad, "username": kadi,
				"avatar_media_id": medya, "role": rol,
			})
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// POST /chats/{chatID}/members — gruba uye ekle (owner/admin).
func (h *Handler) GroupAddMember(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	var req struct {
		UserIDs []string `json:"user_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.UserIDs) == 0 {
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	if !h.grupYetkilisiMi(r, chatID, me) {
		httpErr(w, http.StatusForbidden, "bu işlem için yetkiniz yok")
		return
	}
	var mevcut int
	h.db.QueryRow(r.Context(),
		`SELECT count(*) FROM chat_members WHERE chat_id=$1`, chatID).Scan(&mevcut)
	if mevcut+len(req.UserIDs) > grupUyeTavani {
		httpErr(w, http.StatusBadRequest, "grup en fazla 256 kişi olabilir")
		return
	}
	eklenen := []string{}
	for _, u := range req.UserIDs {
		if u == "" || engel.Var(r.Context(), h.db, me, u) {
			continue
		}
		tag, err := h.db.Exec(r.Context(),
			`INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1,$2,'member')
			 ON CONFLICT DO NOTHING`, chatID, u)
		if err == nil && tag.RowsAffected() == 1 {
			eklenen = append(eklenen, u)
		}
	}
	if len(eklenen) > 0 {
		h.grupSistemMesaji(r, chatID, me, eklenen, "ekledi")
	}
	writeJSON(w, http.StatusOK, map[string]int{"eklenen": len(eklenen)})
}

// DELETE /chats/{chatID}/members/{userID} — uyeyi cikar (yetkili) ya da GRUPTAN AYRIL (kendisi).
func (h *Handler) GroupRemoveMember(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	hedef := chi.URLParam(r, "userID")

	kendisi := hedef == me
	if !kendisi && !h.grupYetkilisiMi(r, chatID, me) {
		httpErr(w, http.StatusForbidden, "bu işlem için yetkiniz yok")
		return
	}
	// ⚠️ SAHIP CIKAMAZ: grup sahipsiz kalirsa uye eklenemez/cikarilamaz ve
	//    yonetilemez bir kalinti olur. Once sahipligi devretmeli.
	if kendisi {
		var rol string
		h.db.QueryRow(r.Context(),
			`SELECT role FROM chat_members WHERE chat_id=$1 AND user_id=$2`,
			chatID, me).Scan(&rol)
		if rol == "owner" {
			httpErr(w, http.StatusBadRequest,
				"grup sahibi ayrılamaz — önce sahipliği devredin")
			return
		}
	}
	tag, err := h.db.Exec(r.Context(),
		`DELETE FROM chat_members WHERE chat_id=$1 AND user_id=$2`, chatID, hedef)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	if tag.RowsAffected() == 1 {
		eylem := "çıkardı"
		if kendisi {
			eylem = "ayrıldı"
		}
		h.grupSistemMesaji(r, chatID, me, []string{hedef}, eylem)
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// grupYetkilisiMi — owner ya da admin mi.
func (h *Handler) grupYetkilisiMi(r *http.Request, chatID, userID string) bool {
	var rol string
	if h.db.QueryRow(r.Context(),
		`SELECT role FROM chat_members WHERE chat_id=$1 AND user_id=$2`,
		chatID, userID).Scan(&rol) != nil {
		return false
	}
	return rol == "owner" || rol == "admin"
}

// grupSistemMesaji — "X, Y'yi ekledi / cikardi" · "X ayrildi".
// ⚠️ `type='system'`: istemci bunu ORTALI GRI SERIT olarak cizer, balon degil.
//
//	Kullanici bu tipi GONDEREMEZ (turu 59 tip beyaz listesi) — yalniz sunucu.
func (h *Handler) grupSistemMesaji(r *http.Request, chatID, aktor string,
	hedefler []string, eylem string) {
	var aktorAd string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, aktor).Scan(&aktorAd)
	metin := aktorAd + " " + eylem
	if eylem != "ayrıldı" {
		adlar := []string{}
		rows, err := h.db.Query(r.Context(),
			`SELECT name FROM users WHERE id = ANY($1)`, hedefler)
		if err == nil {
			for rows.Next() {
				var n string
				if rows.Scan(&n) == nil {
					adlar = append(adlar, n)
				}
			}
			rows.Close()
		}
		metin = aktorAd + ", " + strings.Join(adlar, ", ") + " kişisini " + eylem
	}
	var msgID int64
	var t time.Time
	if h.db.QueryRow(r.Context(), `
		INSERT INTO messages (chat_id, sender_id, type, content)
		VALUES ($1,$2,'system',$3) RETURNING id, created_at`,
		chatID, aktor, metin).Scan(&msgID, &t) != nil {
		return
	}
	uyeler, err := h.chatMemberIDs(r, chatID, aktor)
	if err != nil {
		return
	}
	yuk, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": aktor,
		"type": "system", "content": metin, "created_at": t,
	})
	h.hub.Publish(r.Context(), &Event{
		Type: "message.new", ChatID: chatID, Payload: yuk, To: uyeler,
	})
}

// ---------------------------------------------------------------- SOHBET AYARLARI

// PATCH /chats/{chatID} — sabitle / arsivle / sessize al.
//
// ⚠️⚠️ BU UC OLMADAN `pinned`, `archived` ve `muted_until` sutunlari OLU IDI:
//
//	istemci `pinned`/`archived`i okuyup ekrana ciziyordu ama YAZAN yoktu, yani
//	sabitleme ikonu ASLA cizilemez, arsiv filtresi HEP BOS kume donerdi.
//
// ⚠️ Alanlar POINTER: gonderilmeyen alan DEGISMEZ (kismi guncelleme).
func (h *Handler) UpdateChatSettings(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	var req struct {
		Pinned   *bool `json:"pinned"`
		Archived *bool `json:"archived"`
		Muted    *bool `json:"muted"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	// ⚠️ `muted_until` bir ZAMAN DAMGASI; istemciye bool sunuyoruz (basitlik).
	//    true -> 100 yil sonrasi, false -> NULL. Sureli sessize alma ileride
	//    eklenirse damga zaten hazir.
	var sessizDeger any
	if req.Muted != nil {
		if *req.Muted {
			sessizDeger = time.Now().AddDate(100, 0, 0)
		} else {
			sessizDeger = nil
		}
	}
	tag, err := h.db.Exec(r.Context(), `
		UPDATE chat_members SET
		  pinned      = COALESCE($3, pinned),
		  archived    = COALESCE($4, archived),
		  muted_until = CASE WHEN $5::bool IS NULL THEN muted_until ELSE $6::timestamptz END
		 WHERE chat_id=$1 AND user_id=$2`,
		chatID, me, req.Pinned, req.Archived, req.Muted, sessizDeger)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// DELETE /chats/{chatID} — sohbeti BENDEN sil (gecmisi temizle).
//
// ⚠️⚠️ SATIR SILINMEZ, `cleared_at` DAMGASI ATILIR.
//
//	`chat_members` satirini silmek KARSI TARAFIN gecmisini de bozardi (mesajlar
//	paylasilan `messages` tablosunda) ve kullanicinin "veri silinmez" karariyla
//	celisirdi. Listeleme ve gecmis sorgulari bu damgadan SONRASINI gosterir.
//
// ⚠️ GRUPTAN AYRILMA AYRI ISTIR (`DELETE /chats/{id}/members/{me}`) — orada
//
//	uyelik GERCEKTEN silinir. Karistirma.
func (h *Handler) ClearChat(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	chatID := chi.URLParam(r, "chatID")
	tag, err := h.db.Exec(r.Context(), `
		UPDATE chat_members SET cleared_at=now(), archived=false, pinned=false
		 WHERE chat_id=$1 AND user_id=$2`, chatID, me)
	if err != nil {
		httpErr(w, http.StatusInternalServerError, "silinemedi")
		return
	}
	if tag.RowsAffected() == 0 {
		httpErr(w, http.StatusForbidden, "bu sohbetin üyesi değilsiniz")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
