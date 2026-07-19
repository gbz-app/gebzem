package calls

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/push"
)

// Sesli/goruntulu arama — LiveKit (kendi sunucumuzda).
// Akis: arayan /calls baslatir -> aliciya WS "call.incoming" + push gider
//       alici kabul edince ikisi de LiveKit odasina token'la baglanir.

type Handler struct {
	db   *pgxpool.Pool
	hub  *chat.Hub
	push *push.Sender
	apns *push.APNs // iOS kilit ekrani aramasi (VoIP push)

	lkURL    string // istemcinin baglanacagi adres (wss://rtc.gebzem.app)
	apiKey   string
	apiSecret string
}

func NewHandler(db *pgxpool.Pool, hub *chat.Hub, pushSender *push.Sender, apns *push.APNs) *Handler {
	return &Handler{
		db:        db,
		hub:       hub,
		push:      pushSender,
		apns:      apns,
		lkURL:     getEnv("LIVEKIT_URL", "wss://rtc.gebzem.app"),
		apiKey:    os.Getenv("LIVEKIT_API_KEY"),
		apiSecret: os.Getenv("LIVEKIT_API_SECRET"),
	}
}

func (h *Handler) Enabled() bool { return h.apiKey != "" && h.apiSecret != "" }

// Temizleyici: takili kalmis aramalari kapatir.
// Neden gerekli: zil zaman asimi ISTEMCIDE (45 sn). Arayanin uygulamasi cokerse /
// sebeke giderse End() hic cagrilmaz -> kayit sonsuza dek 'ringing' kalir, aranana
// cevapsiz arama yazilmaz; 'active' kalan kayit ise kullaniciyi kalici "mesgul" yapar.
func (h *Handler) StartSweeper(ctx context.Context) {
	go func() {
		t := time.NewTicker(15 * time.Second)
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
	// 1) 60 sn'dir calan ama cevaplanmayanlar -> cevapsiz (istemcinin 45 sn'lik
	//    timer'i normalde once davranir; bu sadece emniyet subabi)
	rows, err := h.db.Query(ctx, `
		UPDATE calls SET status='missed', ended_at=now()
		WHERE status='ringing' AND created_at < now() - interval '50 seconds'
		RETURNING id, caller_id, callee_id, type`)
	if err != nil {
		return
	}
	type kayit struct{ id, caller, callee, callType string }
	var bitenler []kayit
	for rows.Next() {
		var k kayit
		if rows.Scan(&k.id, &k.caller, &k.callee, &k.callType) == nil {
			bitenler = append(bitenler, k)
		}
	}
	rows.Close()

	for _, k := range bitenler {
		payload, _ := json.Marshal(map[string]string{"call_id": k.id, "status": "missed"})
		h.hub.Publish(ctx, &chat.Event{
			Type: "call.ended", Payload: payload, To: []string{k.caller, k.callee},
		})
		// Aliciya (callee) push ile de kapat: kilit ekranindaki CallKit ekrani asili kalmasin.
		// iOS VoIP cancel: HER ZAMAN (Start ile simetrik; stale-online callee'de hayalet CallKit'i
		// susturur). Android FCM cancel: SADECE offline (online ise WS zaten kapatti).
		if h.apns != nil {
			go h.apns.CallCancel(context.Background(), k.callee, k.id)
		}
		if !h.hub.Online(k.callee) && h.push != nil {
			go h.push.CallInvite([]string{k.callee}, map[string]string{
				"type": "call.cancel", "call_id": k.id,
			})
		}
		// Cevapsiz arama -> sohbete kayit + (offline ise) bildirim (WhatsApp gibi)
		go h.logMissedToChat(context.Background(), k.caller, k.callee, k.callType)
	}

	// 2) 2 saatten uzun "suren" aramalar -> bitmis say (uygulama cokmus / End ulasmamis).
	//    KRITIK: bu esik created_at'e gore ve answered_at / LiveKit oda durumuna BAKMAZ,
	//    yani o an GERCEKTEN konusulan bir aramayi da yakalar. Bu yuzden UZUN tutulur:
	//    kisa deger (or. 30dk) 30dk+ suren MESRU gorusmeyi ortadan koparirdi (regresyon).
	//    Takili 'active' zaten (a) ayni cift tekrar arayinca pairwise temizlikle, (b) istemci
	//    End retry'siyle aninda kapaniyor; sweep sadece hicbiri olmazsa son emniyet.
	//    KALICI cozum (ayri adim): LiveKit room_finished webhook -> oda bosalinca DB'yi kapatir.
	h.db.Exec(ctx, `
		UPDATE calls SET status='ended', ended_at=now()
		WHERE status='active' AND created_at < now() - interval '2 hours'`)

	if len(bitenler) > 0 {
		log.Printf("arama temizleyici: %d cevapsiz arama kapatildi", len(bitenler))
	}
}

// LiveKit erisim token'i uret (JWT — LiveKit'in kendi formati)
func (h *Handler) token(roomName, identity, name string) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":  h.apiKey,
		"sub":  identity,
		"name": name,
		"nbf":  now.Add(-10 * time.Second).Unix(),
		"exp":  now.Add(4 * time.Hour).Unix(),
		"video": map[string]any{
			"room":         roomName,
			"roomJoin":     true,
			"canPublish":   true,
			"canSubscribe": true,
			"canPublishData": true,
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(h.apiSecret))
}

type startReq struct {
	CalleeID  string   `json:"callee_id"`
	Video     bool     `json:"video"`
	ChatID    string   `json:"chat_id"`    // GRUP: kalici grup sohbeti ile (uyeler chat_members'tan)
	MemberIDs []string `json:"member_ids"` // GRUP: kalici sohbet olmadan anlik grup (secilen kisiler)
}

// POST /calls — arama baslat (davet gonderir, arayana token doner)
func (h *Handler) Start(w http.ResponseWriter, r *http.Request) {
	if !h.Enabled() {
		writeErr(w, http.StatusServiceUnavailable, "arama servisi kapali")
		return
	}
	callerID := auth.UserID(r.Context())

	var req startReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	// GRUP ARAMASI: chat_id VEYA member_ids doluysa AYRI yol (1:1 koduna DOKUNMAZ, callee_id gerekmez).
	if req.ChatID != "" || len(req.MemberIDs) > 0 {
		h.startGroup(w, r, req, callerID)
		return
	}
	if req.CalleeID == "" {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}
	if req.CalleeID == callerID {
		writeErr(w, http.StatusBadRequest, "kendinizi arayamazsiniz")
		return
	}

	// Engel kontrolu (cift yonlu)
	var blocked bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		callerID, req.CalleeID).Scan(&blocked)
	if blocked {
		writeErr(w, http.StatusForbidden, "bu kullanici aranamiyor")
		return
	}

	// Arayan bilgisi
	var callerName, callerAvatar string
	h.db.QueryRow(r.Context(),
		`SELECT name, avatar_url FROM users WHERE id=$1`, callerID).Scan(&callerName, &callerAvatar)

	callType := "audio"
	if req.Video {
		callType = "video"
	}

	// MESGUL MU? Alici zaten baska bir aramadaysa (calan ya da suren) yeni arama
	// gonderme; "mesgul" olarak kaydet ki iki tarafin gecmisinde de gorunsun.
	// DIKKAT: 'active' icin ZAMAN SINIRI SART. Uygulama arama sirasinda cokerse
	// End() hic cagrilmaz, satir sonsuza dek 'active' kalir ve o kullaniciya gelen
	// HER arama "mesgul" doner (kullanici kalici olarak aranamaz olur).
	// BUG2 (art arda arama gitmiyor / "kapattim karsida devam"): A tekrar B'yi ararken,
	// A<->B cifti arasindaki takili ringing VE active kayitlarini (HER IKI YON) busy
	// kontrolunden ONCE kapat. Sebep:
	//  - 'ringing' takili: Terminated reddetme sunucuya ulasmayabiliyor (CallKit siniri) ->
	//    1. arama ~45sn KALICI 'mesgul', 2. arama gitmiyor.
	//  - 'active' takili: End istemciden ulasmayinca (ag hatasi/crash) satir 'active' kalip
	//    callee'yi ~2 saat "mesgul" yapiyor -> 2. aramaya HIC push atilmiyor.
	// GUVENLI: A yeni arama baslatiyorsa A o an B ile CANLI gorusmede OLAMAZ -> A<->B arasindaki
	// 'active' kesin zombidir. Pairwise oldugu icin B'nin ucuncu kisi C ile GERCEK aramasina
	// dokunmaz (busy dogru kalir). 'active' icin 15sn yas siniri: nadir cok-cihaz senaryosunda
	// yeni kurulan gercek aramayi yanlislikla kapatmasin.
	h.db.Exec(r.Context(),
		`UPDATE calls
		 SET status = CASE WHEN status='active' THEN 'ended' ELSE 'missed' END, ended_at=now()
		 WHERE ((caller_id=$1 AND callee_id=$2) OR (caller_id=$2 AND callee_id=$1))
		   AND COALESCE(is_group,false)=false
		   AND (status='ringing'
		        OR (status='active' AND created_at < now() - interval '15 seconds'))`,
		callerID, req.CalleeID)
	// ^ is_group=false KEMERI (parite-hukum B2c): yukseltilmis grup aramasi callee_id=NULL
	// ile zaten eslesmiyor; bu kosul gelecekte callee_id doldurulursa da canli grubu korur.

	// 'active' penceresi UZUN (2 saat): kisa deger, MESRU uzun gorusme suren callee'yi
	// "musait" gosterip araya 2. arama sokardi. Ayni cift takili 'active'i zaten yukaridaki
	// pairwise temizlik kapatti; burada kalan 'active' cross-pair GERCEK gorusme demektir.
	var busy bool
	h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM calls
		WHERE (caller_id=$1 OR callee_id=$1)
		  AND ((status='active'  AND created_at > now() - interval '2 hours')
		       OR (status='ringing' AND created_at > now() - interval '45 seconds')))`,
		req.CalleeID).Scan(&busy)
	if busy {
		h.db.Exec(r.Context(), `
			INSERT INTO calls (caller_id, callee_id, type, status, ended_at)
			VALUES ($1,$2,$3,'busy',now())`, callerID, req.CalleeID, callType)
		writeErr(w, http.StatusConflict, "Kullanici su anda baska bir gorusmede")
		return
	}

	// Arama kaydi
	var callID string
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO calls (caller_id, callee_id, type, status)
		VALUES ($1,$2,$3,'ringing') RETURNING id`,
		callerID, req.CalleeID, callType).Scan(&callID)
	if err != nil {
		log.Printf("arama kaydi: %v", err)
		writeErr(w, http.StatusInternalServerError, "arama baslatilamadi")
		return
	}

	roomName := "call_" + callID
	tok, err := h.token(roomName, callerID, callerName)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}

	// Aliciya canli davet (WebSocket) + push (uygulama kapaliysa)
	payload, _ := json.Marshal(map[string]any{
		"call_id":       callID,
		"room":          roomName,
		"type":          callType,
		"caller_id":     callerID,
		"caller_name":   callerName,
		"caller_avatar": callerAvatar,
	})
	h.hub.Publish(r.Context(), &chat.Event{
		Type:    "call.incoming",
		Payload: payload,
		To:      []string{req.CalleeID},
	})
	// Uygulama kapali/kilitliyken de calmasi icin:
	//  - Android: FCM data-only push -> arka plan isleyicisi CallKit ekranini acar
	//  - iOS: APNs VoIP push -> CallKit (FCM VoIP GONDEREMEZ)
	davet := map[string]string{
		"type":          "call.incoming",
		"call_id":       callID,
		"room":          roomName,
		"call_type":     callType,
		"caller_id":     callerID,
		"caller_name":   callerName,
		"caller_avatar": callerAvatar,
	}
	// HER ZAMAN push at (online-gating KALDIRILDI). KANIT (canli loglar): callee arka
	// planda/kilitliyken WS ~35sn "online" (stale) gorunup push'u engelliyordu; o pencerede
	// gelen aramalar (ozellikle art arda) sadece WS'e gidiyor, kilitli cihaz isleyemiyor ->
	// CALMIYOR. Loglarda online=true kayitlar 'missed', online=false kayitlar 'rejected'
	// (gorulup reddedildi) cikiyordu = birebir korelasyon.
	// CIFT-UI (Oturum 7) onlemi ISTEMCIDE: iOS'ta call.incoming WS overlay'i BASTIRILIR
	// (arama yalniz CallKit/VoIP push ile gelir); Android'de on planda onMessage call.incoming'i
	// zaten islemez (WS overlay gosterir), arka planda FCM data -> CallKit. Boylece cift gosterim yok.
	online := h.hub.Online(req.CalleeID)
	log.Printf("arama daveti: call=%s callee online=%v (iOS VoIP her zaman, Android FCM offline)", callID[:8], online)
	// iOS VoIP push: HER ZAMAN (online'a bakma). Sebep: iOS uygulama askiya alininca WS ~35sn
	// "online" (stale) gorunuyor; online-gating push'u engelleyince kilitli iPhone CALMIYORDU.
	// VoIP push (PushKit) ayni arama icin CallKit'i acar; iOS'ta uygulama-ici overlay bastirildigi
	// icin (call_provider) cift-UI olmaz. Callee Android ise voip token yok -> apns no-op.
	if h.apns != nil {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()
			h.apns.CallInvite(ctx, req.CalleeID, map[string]any{
				"call_id":       callID,
				"room":          roomName,
				"call_type":     callType,
				"caller_id":     callerID,
				"caller_name":   callerName,
				"caller_avatar": callerAvatar,
			})
		}()
	}
	// Android FCM data-push: SADECE offline. Android WS'i arka planda DUZGUN kapatiyor (online
	// guvenilir). Online iken FCM gondermek, on planda baslayan aramada kullanici arka plana
	// gecince ana-isolate WS overlay + arka-plan-isolate CallKit CIFT-UI'sine yol aciyordu (Oturum 7).
	if !online && h.push != nil {
		go h.push.CallInvite([]string{req.CalleeID}, davet)
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"call_id": callID,
		"room":    roomName,
		"url":     h.lkURL,
		"token":   tok,
		"type":    callType,
	})
}

// POST /calls (chat_id ile) — GRUP sesli/goruntulu arama baslat.
// 1:1 Start'tan TAMAMEN AYRI (pairwise busy/zombi temizligi grupta YOK). Host odaya ANINDA
// katilir (status='active', call_participants='joined'); diger tum grup uyeleri 'ringing' +
// davet fan-out. callee_id NULL (grupta tekil karsi taraf yok). Herkes AYNI call_id/room'a girer.
func (h *Handler) startGroup(w http.ResponseWriter, r *http.Request, req startReq, callerID string) {
	callType := "audio"
	if req.Video {
		callType = "video"
	}
	// Katilimci listesi + baslik: KALICI grup (chat_id) VEYA ANLIK grup (member_ids).
	var chatTitle string
	var memberIDs []string
	var chatIDForCall any // kalici grupta chat_id, anlik grupta nil (calls.chat_id NULL)
	if req.ChatID != "" {
		var isGroup bool
		err := h.db.QueryRow(r.Context(), `
			SELECT c.type='group', COALESCE(NULLIF(c.title,''),'Grup')
			FROM chats c JOIN chat_members m ON m.chat_id=c.id
			WHERE c.id=$1 AND m.user_id=$2`, req.ChatID, callerID).Scan(&isGroup, &chatTitle)
		if err != nil || !isGroup {
			writeErr(w, http.StatusForbidden, "grup bulunamadi veya uye degilsiniz")
			return
		}
		rows, qerr := h.db.Query(r.Context(),
			`SELECT user_id FROM chat_members WHERE chat_id=$1 AND user_id<>$2`, req.ChatID, callerID)
		if qerr == nil {
			for rows.Next() {
				var uid string
				if rows.Scan(&uid) == nil {
					memberIDs = append(memberIDs, uid)
				}
			}
			rows.Close()
		}
		chatIDForCall = req.ChatID
	} else {
		// Anlik grup: secilen kisiler (kendini/tekrari cikar, gercek+verified dogrula)
		seen := map[string]bool{callerID: true}
		for _, uid := range req.MemberIDs {
			if uid == "" || seen[uid] {
				continue
			}
			var ok bool
			h.db.QueryRow(r.Context(),
				`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND verified=true)`, uid).Scan(&ok)
			if ok {
				seen[uid] = true
				memberIDs = append(memberIDs, uid)
			}
		}
		chatTitle = "Grup araması"
	}
	if len(memberIDs) == 0 {
		writeErr(w, http.StatusBadRequest, "gecerli katilimci yok")
		return
	}
	// KAPASITE — WHATSAPP STANDARDI (kullanici karari 19 Tem): sesli VE goruntulu grup 32 kisi.
	// Not: 32 video cx33'u asar — kullanici "sunucu ekleriz" dedi (buyumede dedicated/egress
	// makinesi, yol haritasi karari). Istemci tarafi korumalar: dusuk grup video profili
	// (540p) + adaptiveStream (gorunmeyen tile'lar duraklar) + kaydirmali izgara.
	// LiveKit global max_participants:32 ile tavan uyumlu (calls odalari auto-create).
	toplam := len(memberIDs) + 1
	if toplam > 32 {
		writeErr(w, http.StatusBadRequest, "grup aramasi en fazla 32 kisi olabilir")
		return
	}

	var callerName, callerAvatar string
	h.db.QueryRow(r.Context(),
		`SELECT name, avatar_url FROM users WHERE id=$1`, callerID).Scan(&callerName, &callerAvatar)

	// calls satiri: host ANINDA active, callee_id NULL (chat_id kalicida dolu, anlikta NULL)
	var callID string
	err := h.db.QueryRow(r.Context(), `
		INSERT INTO calls (caller_id, chat_id, is_group, type, status)
		VALUES ($1,$2,true,$3,'active') RETURNING id`,
		callerID, chatIDForCall, callType).Scan(&callID)
	if err != nil {
		log.Printf("grup arama kaydi: %v", err)
		writeErr(w, http.StatusInternalServerError, "arama baslatilamadi")
		return
	}

	// Host = joined; diger uyeler = ringing
	h.db.Exec(r.Context(),
		`INSERT INTO call_participants (call_id,user_id,status,joined_at) VALUES ($1,$2,'joined',now())`,
		callID, callerID)
	for _, uid := range memberIDs {
		h.db.Exec(r.Context(),
			`INSERT INTO call_participants (call_id,user_id,status) VALUES ($1,$2,'ringing')`,
			callID, uid)
	}

	roomName := "call_" + callID
	tok, err := h.token(roomName, callerID, callerName)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}

	// Davet fan-out (WS + push) her uyeye — hepsi AYNI call_id/room. call.incoming'e grup alanlari eklenir.
	payload, _ := json.Marshal(map[string]any{
		"call_id": callID, "room": roomName, "type": callType,
		"caller_id": callerID, "caller_name": callerName, "caller_avatar": callerAvatar,
		"is_group": true, "chat_id": req.ChatID, "chat_title": chatTitle,
		"participant_count": len(memberIDs) + 1,
	})
	h.hub.Publish(r.Context(), &chat.Event{Type: "call.incoming", Payload: payload, To: memberIDs})

	davet := map[string]string{
		"type": "call.incoming", "call_id": callID, "room": roomName, "call_type": callType,
		"caller_id": callerID, "caller_name": callerName, "caller_avatar": callerAvatar,
		"is_group": "true", "chat_id": req.ChatID, "chat_title": chatTitle,
	}
	for _, uid := range memberIDs {
		uid := uid
		if h.apns != nil {
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
				defer cancel()
				// iOS CallKit'te grup adi gorunsun diye caller_name = grup basligi
				h.apns.CallInvite(ctx, uid, map[string]any{
					"call_id": callID, "room": roomName, "call_type": callType,
					"caller_id": callerID, "caller_name": chatTitle, "caller_avatar": callerAvatar,
					"is_group": true, "chat_id": req.ChatID, "chat_title": chatTitle,
				})
			}()
		}
		if !h.hub.Online(uid) && h.push != nil {
			go h.push.CallInvite([]string{uid}, davet)
		}
	}
	log.Printf("grup arama: call=%s uye=%d tip=%s", kisaID(callID), len(memberIDs), callType)

	writeJSON(w, http.StatusCreated, map[string]any{
		"call_id": callID, "room": roomName, "url": h.lkURL, "token": tok,
		"type": callType, "is_group": true,
	})
}

// POST /calls/{id}/add {user_id} — AKTIF aramaya kisi ekle (parite-hukum B1).
// 1:1 arama GRUBA YUKSELTILIR (is_group=true, callee_id=NULL — K1: pairwise zombi
// temizligi canli grubu oldurmesin); zaten-grupta yalniz davet eklenir. Ayni LiveKit
// odasi (call_<id>) kullanildigi icin mevcut katilimcilarin baglantisina DOKUNULMAZ.
func (h *Handler) Add(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")
	var req struct {
		UserID string `json:"user_id"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if req.UserID == "" || req.UserID == userID {
		writeErr(w, http.StatusBadRequest, "gecersiz istek")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "eklenemedi")
		return
	}
	defer tx.Rollback(r.Context())

	// Kilit + yetki: cagiran aramanin AKTIF bir katilimcisi olmali (FOR UPDATE:
	// es zamanli iki add serilesir — cifte yukseltme yarisi biter)
	var callerID string
	var calleeID *string
	var callType string
	var isGroup bool
	var chatID *string
	err = tx.QueryRow(r.Context(), `
		SELECT caller_id, callee_id, type, COALESCE(is_group,false), chat_id FROM calls
		WHERE id=$1 AND status='active'
		  AND (caller_id=$2 OR callee_id=$2 OR EXISTS(
		       SELECT 1 FROM call_participants WHERE call_id=$1 AND user_id=$2 AND status='joined'))
		FOR UPDATE`, callID, userID).Scan(&callerID, &calleeID, &callType, &isGroup, &chatID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi veya bitti")
		return
	}

	// Hedef gecerli + engel yok
	var verified bool
	tx.QueryRow(r.Context(), `SELECT COALESCE(verified,false) FROM users WHERE id=$1`, req.UserID).Scan(&verified)
	if !verified {
		writeErr(w, http.StatusBadRequest, "kullanici bulunamadi")
		return
	}
	var blocked bool
	tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM blocks
		WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		userID, req.UserID).Scan(&blocked)
	if blocked {
		writeErr(w, http.StatusForbidden, "bu kullanici eklenemiyor")
		return
	}
	// Zaten bu aramada mi
	var hedefDurum string
	tx.QueryRow(r.Context(), `SELECT status FROM call_participants WHERE call_id=$1 AND user_id=$2`,
		callID, req.UserID).Scan(&hedefDurum)
	if hedefDurum == "joined" {
		writeErr(w, http.StatusConflict, "kullanici zaten aramada")
		return
	}
	// Hedef baska gorusmede mi (K3): calls VEYA participants (bu arama haric)
	var mesgul bool
	tx.QueryRow(r.Context(), `
		SELECT EXISTS(
		  SELECT 1 FROM calls WHERE id<>$2 AND (caller_id=$1 OR callee_id=$1)
		    AND (status='active' AND created_at > now() - interval '2 hours'
		         OR status='ringing' AND created_at > now() - interval '45 seconds')
		) OR EXISTS(
		  SELECT 1 FROM call_participants p JOIN calls c ON c.id=p.call_id
		  WHERE p.user_id=$1 AND p.call_id<>$2 AND c.status='active'
		    AND (p.status='joined' OR (p.status='ringing' AND p.invited_at > now() - interval '45 seconds'))
		)`, req.UserID, callID).Scan(&mesgul)
	if mesgul {
		writeErr(w, http.StatusConflict, "kullanici su anda baska bir gorusmede")
		return
	}
	// Kapasite (32): 1:1'de taban 2 say
	var aktifSayi int
	tx.QueryRow(r.Context(), `SELECT count(*) FROM call_participants
		WHERE call_id=$1 AND status IN ('ringing','joined')`, callID).Scan(&aktifSayi)
	if !isGroup && aktifSayi < 2 {
		aktifSayi = 2
	}
	if aktifSayi+1 > 32 {
		writeErr(w, http.StatusBadRequest, "grup aramasi en fazla 32 kisi olabilir")
		return
	}

	// 1:1 ise YUKSELT
	if !isGroup {
		if _, err := tx.Exec(r.Context(),
			`UPDATE calls SET is_group=true, callee_id=NULL WHERE id=$1 AND is_group=false AND status='active'`,
			callID); err != nil {
			writeErr(w, http.StatusInternalServerError, "eklenemedi")
			return
		}
		if calleeID != nil {
			tx.Exec(r.Context(), `
				INSERT INTO call_participants (call_id, user_id, status, joined_at)
				VALUES ($1,$2,'joined',now()),($1,$3,'joined',now())
				ON CONFLICT (call_id, user_id) DO NOTHING`, callID, callerID, *calleeID)
		}
	}
	// Davetli upsert (left/rejected/missed -> yeniden ringing; joined'a DOKUNMA)
	if _, err := tx.Exec(r.Context(), `
		INSERT INTO call_participants (call_id, user_id, status, invited_at)
		VALUES ($1,$2,'ringing',now())
		ON CONFLICT (call_id, user_id) DO UPDATE SET status='ringing', invited_at=now()
		WHERE call_participants.status <> 'joined'`, callID, req.UserID); err != nil {
		writeErr(w, http.StatusInternalServerError, "eklenemedi")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "eklenemedi")
		return
	}

	// ---- fan-out (TX DISI, startGroup deseni) ----
	chatTitle := "Grup araması"
	if chatID != nil {
		h.db.QueryRow(r.Context(),
			`SELECT COALESCE(NULLIF(title,''),'Grup araması') FROM chats WHERE id=$1`, *chatID).Scan(&chatTitle)
	}
	var ekleyenAd, ekleyenAvatar string
	h.db.QueryRow(r.Context(), `SELECT name, COALESCE(avatar_url,'') FROM users WHERE id=$1`, userID).
		Scan(&ekleyenAd, &ekleyenAvatar)
	roomName := "call_" + callID
	katilimciSayi := aktifSayi + 1

	// Eski katilimcilara: ekran grup moduna gecsin (idempotent)
	upgPayload, _ := json.Marshal(map[string]any{
		"call_id": callID, "is_group": true, "chat_title": chatTitle,
		"added_by": userID, "added_name": ekleyenAd, "participant_count": katilimciSayi,
	})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.upgraded", Payload: upgPayload,
		To: h.groupJoinedOthers(r.Context(), callID, ""),
	})

	// Davetliye: call.incoming (WS) + iOS VoIP + Android FCM (offline) — startGroup birebir
	incPayload, _ := json.Marshal(map[string]any{
		"call_id": callID, "room": roomName, "type": callType,
		"caller_id": userID, "caller_name": ekleyenAd, "caller_avatar": ekleyenAvatar,
		"is_group": true, "chat_title": chatTitle, "participant_count": katilimciSayi,
	})
	h.hub.Publish(r.Context(), &chat.Event{Type: "call.incoming", Payload: incPayload, To: []string{req.UserID}})
	if h.apns != nil {
		go func(uid string) {
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()
			h.apns.CallInvite(ctx, uid, map[string]any{
				"call_id": callID, "room": roomName, "call_type": callType,
				"caller_id": userID, "caller_name": chatTitle, "caller_avatar": ekleyenAvatar,
				"is_group": true, "chat_title": chatTitle,
			})
		}(req.UserID)
	}
	if !h.hub.Online(req.UserID) && h.push != nil {
		go h.push.CallInvite([]string{req.UserID}, map[string]string{
			"type": "call.incoming", "call_id": callID, "room": roomName, "call_type": callType,
			"caller_id": userID, "caller_name": ekleyenAd, "caller_avatar": ekleyenAvatar,
			"is_group": "true", "chat_title": chatTitle,
		})
	}
	log.Printf("aramaya ekleme: call=%s ekleyen=%s hedef=%s (toplam=%d)",
		kisaID(callID), kisaID(userID), kisaID(req.UserID), katilimciSayi)

	writeJSON(w, http.StatusOK, map[string]any{
		"status": "invited", "call_id": callID, "is_group": true, "participant_count": katilimciSayi,
	})
}

// POST /calls/{id}/answer — aramayi kabul et (aliciya token doner)
func (h *Handler) Answer(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")

	// GRUP mu? is_group ise KATILMA yolu (1:1 Answer'a dokunmaz).
	var isGroup bool
	h.db.QueryRow(r.Context(), `SELECT COALESCE(is_group,false) FROM calls WHERE id=$1`, callID).Scan(&isGroup)
	if isGroup {
		h.answerGroup(w, r, callID, userID)
		return
	}

	var callerID, callType string
	err := h.db.QueryRow(r.Context(), `
		SELECT caller_id, type FROM calls WHERE id=$1 AND callee_id=$2`,
		callID, userID).Scan(&callerID, &callType)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}

	// ATOMIK kabul + answered_at'i GERI AL. Iki es zamanli Answer (cift ekran) ikisi de
	// 'ringing' okuyup gecemez -> sadece BIRI 'active' yapar; digeri 0 satir -> ErrNoRows -> 409.
	// answered_at = SURE SENKRONU cikis noktasi: iki tarafa GECEN-SURE (elapsed_ms) uretiriz;
	// istemci bunu monotonik Stopwatch ile sayar (duvar-saati kaymasindan ETKILENMEZ).
	var answeredAt time.Time
	err = h.db.QueryRow(r.Context(),
		`UPDATE calls SET status='active', answered_at=now()
		 WHERE id=$1 AND callee_id=$2 AND status='ringing'
		 RETURNING answered_at`, callID, userID).Scan(&answeredAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeErr(w, http.StatusConflict, "arama artik gecerli degil")
		} else {
			writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		}
		return
	}
	// Kabul YENI olustu -> gecen sure ~0. Aninda gonderilen kanallar (WS + answer cevabi)
	// icin bu deger dogru; gecikmeli/kayip WS'te ARAYAN gercek gecen-sureyi Status'tan alir.
	elapsedNow := time.Now().UnixMilli() - answeredAt.UnixMilli()
	if elapsedNow < 0 {
		elapsedNow = 0
	}

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)

	roomName := "call_" + callID
	tok, err := h.token(roomName, userID, name)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}

	// Arayana "kabul edildi" bildir — WS + PUSH (yedek).
	// KRITIK: arayan calarken ekrana bakmayi birakinca (paused) WS kapaniyor; tam o an
	// kabul edilirse call.answered WS'te KAYBOLUYOR -> arayan sonsuza kadar "Caliyor".
	// End'deki gibi push fallback ekliyoruz (istemci ayrica poll ile de kurtarir).
	payload, _ := json.Marshal(map[string]any{"call_id": callID, "elapsed_ms": elapsedNow})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.answered", Payload: payload, To: []string{callerID},
	})
	if h.push != nil {
		// PUSH ZAMANLAMASI GUVENILMEZ (gecikmeli teslim) -> sure referansi TASIMAZ; yalniz
		// "kabul edildi" tetikleyicisi. Arayan gercek gecen-sureyi WS veya Status'tan alir.
		go h.push.CallInvite([]string{callerID}, map[string]string{
			"type": "call.answered", "call_id": callID,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"call_id":    callID,
		"room":       roomName,
		"url":        h.lkURL,
		"token":      tok,
		"type":       callType,
		"elapsed_ms": elapsedNow, // SURE SENKRONU: aranan tarafin gecen-sure baslangici (~0)
	})
}

// POST /calls/{id}/end — aramayi bitir/reddet (iki taraf da cagirabilir)
func (h *Handler) End(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")

	// GRUP mu? is_group ise AYRIL yolu (1:1 End'e dokunmaz). Grupta End = "ben ayrildim";
	// arama DIGERLERI icin surer, yalniz oda bosalinca biter.
	var isGroup bool
	h.db.QueryRow(r.Context(), `SELECT COALESCE(is_group,false) FROM calls WHERE id=$1`, callID).Scan(&isGroup)
	if isGroup {
		h.endGroup(w, r, callID, userID)
		return
	}

	var callerID, calleeID, status, callType string
	err := h.db.QueryRow(r.Context(), `
		SELECT caller_id, callee_id, status, type FROM calls
		WHERE id=$1 AND (caller_id=$2 OR callee_id=$2)`, callID, userID).
		Scan(&callerID, &calleeID, &status, &callType)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}

	// Cevaplanmadan kapandiysa: cevapsiz/reddedildi
	newStatus := "ended"
	if status == "ringing" {
		if userID == calleeID {
			newStatus = "rejected"
		} else {
			newStatus = "missed"
		}
	}
	// ATOMIK bitirme: sadece hala 'ringing'/'active' ise. Zaten bitmisse (cift end,
	// answer+end yarisi) tekrar yazma ve TEKRAR OLAY YAYINLAMA -> karsi tarafa cift
	// call.ended / stale durum gitmesin.
	ct, err := h.db.Exec(r.Context(),
		`UPDATE calls SET status=$1, ended_at=now()
		 WHERE id=$2 AND status IN ('ringing','active')`, newStatus, callID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	if ct.RowsAffected() == 0 {
		// Zaten bitmis — sessizce basarili don, olay yayinlama
		writeJSON(w, http.StatusOK, map[string]string{"status": "ended"})
		return
	}

	// Diger tarafa bildir
	other := callerID
	if userID == callerID {
		other = calleeID
	}
	payload, _ := json.Marshal(map[string]string{"call_id": callID, "status": newStatus})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.ended", Payload: payload, To: []string{other},
	})

	// iOS VoIP CallCancel: SADECE cevaplanmadan iptal edilen aramada (newStatus=="missed",
	// yani ARAYAN vazgecti/45sn doldu -> other=callee). Sebep: callee'nin CALAN kilit-ekrani
	// CallKit'i kapanmali. KRITIK: 'rejected' (callee kapatti -> other=CALLER) ve 'ended'
	// (cevaplanmis, iki taraf da CallScreen'de) durumlarinda ARAYANDA o arama icin CallKit
	// HIC gosterilmedi (davet yalniz callee'ye gider). Yine de cancel atarsak AppDelegate
	// iOS 13+ kurali geregi reportNewIncomingCall cagirip closure'da endCall yapiyor -> arayanda
	// "hayalet gelen-arama" bir an belirip kapaniyordu (kullanicinin bildirdigi 'bitince popup').
	// Cevaplanmis arama zaten WS call.ended ile kapaniyor; VoIP cancel gereksiz.
	if newStatus == "missed" && h.apns != nil {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()
			h.apns.CallCancel(ctx, other, callID)
		}()
	}
	// Android FCM cancel: SADECE offline. Online (WS bagli) ise call.ended WS olayi ekrani
	// zaten kapatiyor; online iken data-push cift-UI/gurultu uretir.
	if !h.hub.Online(other) && h.push != nil {
		go h.push.CallInvite([]string{other}, map[string]string{
			"type":    "call.cancel",
			"call_id": callID,
		})
	}

	// Cevapsiz arama (arayan iptal etti / callee cevaplamadi) -> sohbete "cevapsiz arama"
	// kaydi + (callee offline ise) bildirim. Reddedilen aramada BILDIRIM/kayit yok.
	if newStatus == "missed" {
		go h.logMissedToChat(context.Background(), callerID, calleeID, callType)
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": newStatus})
}

// --- GRUP ARAMA yardimcilari (1:1'den tamamen ayri) ---

// Bir grup aramasinda JOINED (aktif konusan) katilimcilar (exceptID haric).
func (h *Handler) groupJoinedOthers(ctx context.Context, callID, exceptID string) []string {
	rows, err := h.db.Query(ctx,
		`SELECT user_id FROM call_participants WHERE call_id=$1 AND status='joined' AND user_id<>$2`,
		callID, exceptID)
	var ids []string
	if err == nil {
		for rows.Next() {
			var u string
			if rows.Scan(&u) == nil {
				ids = append(ids, u)
			}
		}
		rows.Close()
	}
	return ids
}

// Bir grup aramasinda SADECE CALAN (ringing) davetliler — oda kapanirken VoIP/FCM CANCEL yalniz
// bunlara gider (kilit-ekrani CallKit kapansin). JOINED katilimci (CallScreen'de) cancel ALMAMALI:
// call.ended WS zaten kapatir; cancel iOS'ta hayalet "gelen arama" flash'i yaratir.
func (h *Handler) groupRinging(ctx context.Context, callID string) []string {
	rows, err := h.db.Query(ctx,
		`SELECT user_id FROM call_participants WHERE call_id=$1 AND status='ringing'`, callID)
	var ids []string
	if err == nil {
		for rows.Next() {
			var u string
			if rows.Scan(&u) == nil {
				ids = append(ids, u)
			}
		}
		rows.Close()
	}
	return ids
}

// Bir grup aramasinda CALAN veya AKTIF tum katilimcilar (oda kapanirken haber vermek icin).
func (h *Handler) groupRingingOrJoined(ctx context.Context, callID string) []string {
	rows, err := h.db.Query(ctx,
		`SELECT user_id FROM call_participants WHERE call_id=$1 AND status IN ('ringing','joined')`, callID)
	var ids []string
	if err == nil {
		for rows.Next() {
			var u string
			if rows.Scan(&u) == nil {
				ids = append(ids, u)
			}
		}
		rows.Close()
	}
	return ids
}

// Grup davetini KABUL = odaya katil. Token doner + diger aktiflere call.participant.joined.
func (h *Handler) answerGroup(w http.ResponseWriter, r *http.Request, callID, userID string) {
	// Davetli mi (call_participants satiri var mi) + arama hala aktif mi + grup basligi
	var callType, chatTitle string
	err := h.db.QueryRow(r.Context(), `
		SELECT c.type, COALESCE(NULLIF(ch.title,''),'Grup araması')
		FROM calls c
		LEFT JOIN chats ch ON ch.id=c.chat_id
		JOIN call_participants p ON p.call_id=c.id AND p.user_id=$2
		WHERE c.id=$1 AND c.status='active'`, callID, userID).Scan(&callType, &chatTitle)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi veya bitti")
		return
	}
	// Katil: ringing/left -> joined (idempotent)
	h.db.Exec(r.Context(),
		`UPDATE call_participants SET status='joined', joined_at=COALESCE(joined_at,now())
		 WHERE call_id=$1 AND user_id=$2`, callID, userID)

	var name string
	h.db.QueryRow(r.Context(), `SELECT name FROM users WHERE id=$1`, userID).Scan(&name)
	roomName := "call_" + callID
	tok, err := h.token(roomName, userID, name)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "token uretilemedi")
		return
	}
	// Diger AKTIF katilimcilara "X katildi" -> grid guncelle (call.ended DEGIL)
	payload, _ := json.Marshal(map[string]any{"call_id": callID, "user_id": userID, "name": name})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.participant.joined", Payload: payload,
		To:   h.groupJoinedOthers(r.Context(), callID, userID),
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"call_id": callID, "room": roomName, "url": h.lkURL, "token": tok,
		"type": callType, "is_group": true, "chat_title": chatTitle,
	})
}

// Grup aramasindan AYRIL. Ben cikarim; arama DIGERLERI icin SURER. Oda bosalinca (joined=0) biter.
// KRITIK: 1:1'deki gibi call.ended yaymayiz -> tek kisinin cikisi tum grubu kapatmaz.
func (h *Handler) endGroup(w http.ResponseWriter, r *http.Request, callID, userID string) {
	h.db.Exec(r.Context(),
		`UPDATE call_participants SET status='left', left_at=now()
		 WHERE call_id=$1 AND user_id=$2 AND status IN ('ringing','joined')`, callID, userID)

	// Kalan AKTIF katilimcilara "X ayrildi" (call.ended DEGIL -> ekranlari kapanmaz)
	leftPayload, _ := json.Marshal(map[string]any{"call_id": callID, "user_id": userID})
	h.hub.Publish(r.Context(), &chat.Event{
		Type: "call.participant.left", Payload: leftPayload,
		To:   h.groupJoinedOthers(r.Context(), callID, userID),
	})

	// Konusabilecek kimse kaldi mi? Arama biter EGER: hic aktif yok VEYA tek aktif kaldi + TAZE davet yok
	// (2-kisilik grupta biri cikinca digeri tek/yalniz kalmasin). Taze ringing (45sn) varsa -> onlar
	// katilabilir, arama surer (3+ kisi / host+bekleyenler senaryosu bozulmaz).
	var joinedCount, ringingFresh int
	// invited_at bazli tazelik (parite-hukum B2a): aramaya SONRADAN eklenen davetli
	// (created_at eski!) daha calarken son joined cikarsa arama olmesin.
	h.db.QueryRow(r.Context(), `
		SELECT count(*) FILTER (WHERE p.status='joined'),
		       count(*) FILTER (WHERE p.status='ringing' AND p.invited_at > now() - interval '45 seconds')
		FROM call_participants p
		WHERE p.call_id=$1`, callID).Scan(&joinedCount, &ringingFresh)
	if joinedCount == 0 || (joinedCount == 1 && ringingFresh == 0) {
		h.db.Exec(r.Context(),
			`UPDATE calls SET status='ended', ended_at=now() WHERE id=$1 AND status='active'`, callID)
		// WS call.ended: TUM kalanlara (ringing + joined) -> ekranlari kapansin.
		herkes := h.groupRingingOrJoined(r.Context(), callID)
		endPayload, _ := json.Marshal(map[string]string{"call_id": callID, "status": "ended"})
		h.hub.Publish(r.Context(), &chat.Event{Type: "call.ended", Payload: endPayload, To: herkes})
		// VoIP/FCM CANCEL yalniz CALAN (ringing) davetlilere -> JOINED katilimci (CallScreen'de)
		// hayalet "gelen arama" flash'i almasin (call.ended WS onu zaten kapatir; dogrulama bulgusu).
		for _, uid := range h.groupRinging(r.Context(), callID) {
			uid := uid
			if h.apns != nil {
				go func() {
					ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
					defer cancel()
					h.apns.CallCancel(ctx, uid, callID)
				}()
			}
			if !h.hub.Online(uid) && h.push != nil {
				go h.push.CallInvite([]string{uid}, map[string]string{"type": "call.cancel", "call_id": callID})
			}
		}
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

// POST /calls/{id}/audio-stat — CANLI ESZAMANLI ses takibi. Istemci 2sn'de bir karsidan aldigi
// ses paketlerini (getStats packetsReceived DELTA) yollar; api log'da ANLIK izlenir:
//   docker logs -f api | grep AUDIO
// delta>0 -> karsinin sesi GELIYOR; delta=0 -> ses GELMIYOR; recv=-1 -> remote audio track YOK.
// Boylece "acildi ama konusamiyoruz" aninda hangi telefon ses aliyor/almiyor kesin gorunur.
func (h *Handler) AudioStat(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")
	var req struct {
		Recv     int            `json:"recv"`
		Delta    int            `json:"delta"`
		Enerji   string         `json:"enerji"` // gelen sesin seviye deltasi ("0.0" = sessizlik)
		Sent     int            `json:"sent"`   // GONDEREN tarafi: kendi mic paketlerim (grup teshisi)
		SDelta   int            `json:"sdelta"`
		Mik      string         `json:"mik"` // kendi mikrofon CAPTURE seviyem ("0.0" = olu mikrofon adayi)
		Mic      bool           `json:"mic"` // mikrofon dugmesi acik mi
		Outgoing bool           `json:"outgoing"`
		Video    bool           `json:"video"`
		Speaker  bool           `json:"speaker"`
		Peer     bool           `json:"peer"`
		Sorun    bool           `json:"sorun"` // kullanici "ses gelmiyor" isaretledi
		Sure     int            `json:"sure"`
		Kurtarma string         `json:"kurtarma"` // FAZ-3: istemci oto-kurtarma tetikledi (imza adi)
		IOS      map[string]any `json:"ios"`      // audioEnabled, active, category, route
	}
	json.NewDecoder(r.Body).Decode(&req)
	yon := "GELEN"
	if req.Outgoing {
		yon = "GIDEN"
	}
	tip := "SESLI"
	if req.Video {
		tip = "VIDEO"
	}
	// iOS cikis durumunu tek dizeye topla (audioEnabled/active/route).
	// temizle(): istemci-kontrollu route dizesindeki newline'lari at -> sahte log satiri enjeksiyonu onle.
	// iosCikisKapali: audioEnabled=false -> iPhone ses birimi kapali -> playout FIZIKSEL imkansiz (kok neden).
	iosStr := "-"
	iosCikisKapali := false
	if req.IOS != nil {
		// kategori teshis icin SART (grup-host mic bulgusu: birim-start anindaki kategori
		// logdan dusuruluyordu; istemci zaten yolluyor)
		iosStr = temizle(fmt.Sprintf("acik=%v aktif=%v kat=%v rota=%v",
			req.IOS["audioEnabled"], req.IOS["active"], req.IOS["category"], req.IOS["route"]))
		if v, ok := req.IOS["audioEnabled"].(bool); ok && !v {
			iosCikisKapali = true
		}
	}
	// enerji delta'sini sayiya cevir (sessizlik ayrimi icin)
	enerji, _ := strconv.ParseFloat(req.Enerji, 64)
	saat := time.Now().Add(3 * time.Hour).Format("15:04:05") // TR saati (UTC+3)

	// Kullanici sorun isaretlediyse AYRI, dikkat cekici satir
	if req.Sorun {
		log.Printf("!!! SORUN-BILDIRIMI call=%s user=%s %s %s sure=%ds recv=%d peer=%v hoparlor=%v iOS[%s]",
			kisaID(callID), kisaID(userID), yon, tip, req.Sure, req.Recv, req.Peer, req.Speaker, iosStr)
		audioEkle(audioKayit{Saat: saat, Call: kisaID(callID), User: kisaID(userID), Yon: yon, Tip: tip,
			Recv: req.Recv, Durum: "!! SORUN-BILDIRIMI", Peer: req.Peer, Hoparlor: req.Speaker, IOS: iosStr})
		w.WriteHeader(http.StatusOK)
		return
	}

	// TESHIS onceligi — KOK NEDENE gore sirali (adversarial dogrulama duzeltmesi):
	//   TRACK-YOK     : remote audio track yok (abonelik/baglanti)
	//   SES-GELMIYOR  : paket akmiyor (delta<=0) -> ag/TURN
	//   iOS-CIKIS-YOK : paket AKIYOR ama iPhone ses birimi KAPALI -> ses geliyor CALMIYOR.
	//                   ENERJIDEN ONCE bakilir: cikis oluyken WebRTC playout ilerlemez, enerji de
	//                   duser; enerjiye once baksaydik yanlislikla "karsi sessiz" derdik (YANLIS telefon).
	//                   Bu, ilk-arama-ses-yok (didActivate gelmeyen soguk baslangic) durumunu tam yakalar.
	//   SES-DUSUK     : paket+cikis var ama bu 2sn penceresinde enerji ~0. Tek pencere KESIN degil
	//                   (dogal konusma duraksamasi olabilir) -> "mic bozuk" IDDIA ETME; ardisik enerji=X
	//                   satirlarina bak (SUREKLI 0 = gercek sorun, ARALIKLI 0 = normal).
	//   SES-VAR       : paket akiyor, cikis acik, enerji var -> ses gidiyor (duyulmali)
	durum := "SES-VAR"
	if req.Recv < 0 {
		durum = "TRACK-YOK"
	} else if req.Delta <= 0 {
		durum = "SES-GELMIYOR"
	} else if iosCikisKapali {
		durum = "iOS-CIKIS-YOK"
	} else if enerji < 0.5 {
		// FAZ-3: paket AKIYOR + cikis bayraklari dogru + enerji tam 0 -> OLU PLAYOUT
		// adayi (19 Tem ilk-grup-arama kaniti: birim olu, kategori dogru). SES-DUSUK'un
		// ICINDE dallanir (TRACK-YOK/SES-GELMIYOR/iOS-CIKIS-YOK'u ezmez — yargic duzeltmesi).
		if req.IOS != nil && !iosCikisKapali && req.Delta > 60 && enerji <= 0.01 {
			durum = "CIKIS-OLU?"
		} else {
			durum = "SES-DUSUK"
		}
	}
	// GONDEREN-TARAFI teshis (grup "kimin sesi gitmiyor"): mic ACIK + kendi paketlerim
	// AKIYOR + capture enerjim SIFIR = OLU MIKROFON (bu telefonun sesi kimseye gitmiyor).
	// OLCEK NOTU (19 Tem canli veri): outbound media-source enerjisi inbound'dan ~1000x
	// kucuk — SAGLIKLI mikrofon 0.1-0.3 gosteriyor. Esik 0.5 herkesi MIK-OLU isaretledi
	// (yanlis alarm); gercek olu mikrofon DUZ 0.0 basar -> esik 0.01.
	mikE, _ := strconv.ParseFloat(req.Mik, 64)
	if req.Mic && req.SDelta > 60 && mikE <= 0.01 {
		durum = "MIK-OLU(" + durum + ")"
	} else if req.Mic && req.Sent >= 0 && req.SDelta <= 0 && req.Delta > 60 {
		// FAZ-3: mic ACIK + track VAR ama HIC paket cikmiyor (karsi yon akarken) =
		// OLU GONDERICI (19 Tem: iOS davetli sent=0 tum arama — eski imza kacirdi)
		durum = "MIK-OLU-SENT0(" + durum + ")"
	}
	if req.Kurtarma != "" {
		durum = "KURTARMA=" + temizle(req.Kurtarma) + " " + durum
	}
	log.Printf("AUDIO call=%s user=%s %s %s recv=%d delta=%d enerji=%.1f sent=%d sdelta=%d mikE=%.1f mic=%v %s peer=%v hoparlor=%v iOS[%s]",
		kisaID(callID), kisaID(userID), yon, tip, req.Recv, req.Delta, enerji, req.Sent, req.SDelta, mikE, req.Mic, durum, req.Peer, req.Speaker, iosStr)
	audioEkle(audioKayit{Saat: saat, Call: kisaID(callID), User: kisaID(userID), Yon: yon, Tip: tip,
		Recv: req.Recv, Delta: req.Delta, Enerji: enerji, Durum: durum, Peer: req.Peer, Hoparlor: req.Speaker, IOS: iosStr})
	w.WriteHeader(http.StatusOK)
}

// temizle: log enjeksiyonuna karsi istemci dizesindeki satir sonlarini bosluga cevirir.
func temizle(s string) string {
	return strings.NewReplacer("\n", " ", "\r", " ").Replace(s)
}

// Canli ses teshis kayitlari (bellek ring buffer) — admin panel /admin/audio ile gosterir.
// GECICI teshis araci; uretim oncesi kaldirilacak (bkz. oturum.md).
type audioKayit struct {
	Saat     string  `json:"saat"`
	Call     string  `json:"call"`
	User     string  `json:"user"`
	Yon      string  `json:"yon"`
	Tip      string  `json:"tip"`
	Recv     int     `json:"recv"`
	Delta    int     `json:"delta"`
	Enerji   float64 `json:"enerji"`
	Durum    string  `json:"durum"`
	Peer     bool    `json:"peer"`
	Hoparlor bool    `json:"hoparlor"`
	IOS      string  `json:"ios"`
}

var (
	audioMu  sync.Mutex
	audioBuf []audioKayit // son 120 kayit
)

func audioEkle(k audioKayit) {
	audioMu.Lock()
	audioBuf = append(audioBuf, k)
	if len(audioBuf) > 120 {
		audioBuf = audioBuf[len(audioBuf)-120:]
	}
	audioMu.Unlock()
}

func kisaID(s string) string {
	if len(s) >= 8 {
		return s[:8]
	}
	return s
}

// GET /calls/{id}/status — arayan "aramam cevaplandi mi / bitti mi" diye sorar.
// call.answered/call.ended WS olaylari (arka planda WS kopukken) KAYBOLABILIR;
// arayan calarken bunu 2 sn'de bir sorup 'active' gorunce baglanir, biterse kapatir.
// WS'in guvenilmezligini telafi eden KURTARMA agi.
func (h *Handler) Status(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	callID := chi.URLParam(r, "id")
	var status string
	var isGroup bool
	var elapsedMs int64 // SURE SENKRONU KURTARMA: WS/push call.answered kaybolursa arayan gercek
	// gecen-sureyi buradan alir. answered_at NULL (henuz cevaplanmadi / grup) -> -1 (istemci YOK SAYAR;
	// KRITIK: created_at'e DUSURME -> yoksa arayan zil fazinda sahte referans kilitler, sayac siser).
	// GRUP UYUMU: grup katilimcisi caller/callee degildir -> call_participants'tan da yetkilendir.
	err := h.db.QueryRow(r.Context(),
		`SELECT status, COALESCE(is_group,false),
		        CASE WHEN answered_at IS NULL THEN -1
		             ELSE (EXTRACT(EPOCH FROM (now() - answered_at))*1000)::bigint END
		   FROM calls WHERE id=$1 AND (caller_id=$2 OR callee_id=$2
		   OR id IN (SELECT call_id FROM call_participants WHERE user_id=$2))`,
		callID, userID).Scan(&status, &isGroup, &elapsedMs)
	if err != nil {
		writeErr(w, http.StatusNotFound, "arama bulunamadi")
		return
	}
	// GRUP: calls.status host yuzunden hemen 'active'; davetlinin GERCEK durumu kendi call_participants
	// satirinda. Boylece CALAN davetlinin gelen-arama ekrani 'ringing' gorup KALIR (yoksa 'active' gorup
	// ~2sn'de kapaniyordu). Oda tamamen bitmisse (calls != active) ham deger doner -> herkes cikar.
	if isGroup && status == "active" {
		var p string
		if h.db.QueryRow(r.Context(),
			`SELECT status FROM call_participants WHERE call_id=$1 AND user_id=$2`,
			callID, userID).Scan(&p) == nil {
			switch p {
			case "ringing":
				status = "ringing" // hala davetli -> ekran kalir
			case "left", "rejected":
				status = "ended" // ayrildi -> ekran kapansin
				// "joined" -> "active" kalir (CallScreen bagli)
			}
		}
	}
	// is_group additive (parite-hukum B2b): WS call.upgraded kaybolursa istemci 3sn'lik
	// aktif poll'dan grup moduna gecisi kurtarir. Eski istemci alani yok sayar.
	writeJSON(w, http.StatusOK, map[string]any{
		"status": status, "elapsed_ms": elapsedMs, "is_group": isGroup,
	})
}

// GET /calls/active — beni su an arayan var mi?
// Uygulama arka plandayken WebSocket kopuk olabilir; kullanici bildirime dokunup
// uygulamayi acinca "call.incoming" olayi coktan gecmis olur. Uygulama acilista ve
// on plana her donusunde burayi sorar, calan arama varsa gelen arama ekranini gosterir.
func (h *Handler) Active(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())

	var callID, callType, callerName, callerAvatar string
	err := h.db.QueryRow(r.Context(), `
		SELECT c.id, c.type, u.name, COALESCE(u.avatar_url,'')
		FROM calls c JOIN users u ON u.id = c.caller_id
		WHERE c.callee_id=$1 AND c.status='ringing'
		  AND c.created_at > now() - interval '45 seconds'
		ORDER BY c.created_at DESC LIMIT 1`, userID).
		Scan(&callID, &callType, &callerName, &callerAvatar)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]any{}) // calan arama yok
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"call_id":      callID,
		"type":         callType,
		"caller_name":  callerName,
		"caller_avatar": callerAvatar,
	})
}

// GET /calls — arama gecmisi (kim, ne zaman, cevapsiz/reddedildi/mesgul, ne kadar surdu)
func (h *Handler) History(w http.ResponseWriter, r *http.Request) {
	userID := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT c.id, c.type, c.status, c.created_at,
		       c.caller_id = $1 AS outgoing,
		       COALESCE(EXTRACT(EPOCH FROM (c.ended_at - c.answered_at))::int, 0) AS duration,
		       u.id, u.name, COALESCE(u.username,''), COALESCE(u.avatar_url,'')
		FROM calls c
		JOIN users u ON u.id = CASE WHEN c.caller_id=$1 THEN c.callee_id ELSE c.caller_id END
		WHERE (c.caller_id=$1 OR c.callee_id=$1) AND c.is_group=false
		ORDER BY c.created_at DESC LIMIT 100`, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sunucu hatasi")
		return
	}
	defer rows.Close()

	type item struct {
		ID        string    `json:"id"`
		Type      string    `json:"type"`     // audio | video
		Status    string    `json:"status"`   // ended|missed|rejected|busy|active|ringing
		CreatedAt time.Time `json:"created_at"`
		Outgoing  bool      `json:"outgoing"` // ben mi aradim
		Duration  int       `json:"duration"` // saniye (cevaplanmadiysa 0)
		PeerID    string    `json:"peer_id"`
		PeerName  string    `json:"peer_name"`
		PeerUser  string    `json:"peer_username"`
		PeerPhoto string    `json:"peer_avatar"`
	}
	out := []item{}
	for rows.Next() {
		var it item
		if rows.Scan(&it.ID, &it.Type, &it.Status, &it.CreatedAt, &it.Outgoing, &it.Duration,
			&it.PeerID, &it.PeerName, &it.PeerUser, &it.PeerPhoto) == nil {
			out = append(out, it)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// logMissedToChat: cevapsiz aramayi WhatsApp gibi sohbet thread'ine "cevapsiz arama"
// kaydi (type='system', content 'call:missed:audio|video') olarak dusurur ve callee
// OFFLINE ise bildirim gonderir. Direct sohbet yoksa olusturur. SADECE 'missed' icin
// cagrilir. Cift kayit, End()/sweep()'in atomik tek-sefer 'missed' gecisiyle onlenir.
func (h *Handler) logMissedToChat(ctx context.Context, callerID, calleeID, callType string) {
	// direct sohbeti bul, yoksa olustur (chat.CreateDirect ile ayni desen)
	var chatID string
	err := h.db.QueryRow(ctx, `
		SELECT c.id FROM chats c
		JOIN chat_members m1 ON m1.chat_id=c.id AND m1.user_id=$1
		JOIN chat_members m2 ON m2.chat_id=c.id AND m2.user_id=$2
		WHERE c.type='direct' LIMIT 1`, callerID, calleeID).Scan(&chatID)
	if err != nil {
		tx, txErr := h.db.Begin(ctx)
		if txErr != nil {
			return
		}
		defer tx.Rollback(ctx)
		if tx.QueryRow(ctx,
			`INSERT INTO chats (type, created_by) VALUES ('direct',$1) RETURNING id`, callerID).Scan(&chatID) != nil {
			return
		}
		for _, uid := range []string{callerID, calleeID} {
			if _, e := tx.Exec(ctx,
				`INSERT INTO chat_members (chat_id, user_id) VALUES ($1,$2)`, chatID, uid); e != nil {
				return
			}
		}
		if tx.Commit(ctx) != nil {
			return
		}
	}

	if callType != "video" {
		callType = "audio"
	}
	content := "call:missed:" + callType

	var msgID int64
	var createdAt time.Time
	if h.db.QueryRow(ctx,
		`INSERT INTO messages (chat_id, sender_id, type, content) VALUES ($1,$2,'system',$3)
		 RETURNING id, created_at`, chatID, callerID, content).Scan(&msgID, &createdAt) != nil {
		return
	}
	// Okunmamis rozeti icin teslim kaydi (callee icin unread sayilir; sender_id=caller)
	for _, uid := range []string{callerID, calleeID} {
		h.db.Exec(ctx,
			`INSERT INTO message_receipts (message_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			msgID, uid)
	}

	payload, _ := json.Marshal(map[string]any{
		"id": msgID, "chat_id": chatID, "sender_id": callerID,
		"type": "system", "content": content, "media_url": "",
		"reply_to_id": nil, "created_at": createdAt,
	})
	h.hub.Publish(ctx, &chat.Event{
		Type: "message.new", ChatID: chatID, Payload: payload, To: []string{callerID, calleeID},
	})

	// Callee offline ise gercek bir "cevapsiz arama" bildirimi (mesaj push deseniyle ayni yol)
	if h.push != nil && !h.hub.Online(calleeID) {
		var callerName string
		h.db.QueryRow(ctx, `SELECT name FROM users WHERE id=$1`, callerID).Scan(&callerName)
		onizleme := "Cevapsiz sesli arama"
		if callType == "video" {
			onizleme = "Cevapsiz goruntulu arama"
		}
		go h.push.NotifyUsers([]string{calleeID}, callerName, onizleme, chatID)
	}
}

// ---- ADMIN IZLEME PANELI (test icin canli arama gorunumu) ----

func adminKey() string {
	// TARAMA #16: sabit yedek anahtar KALDIRILDI — repo PUBLIC; ADMIN_KEY bos kalirsa
	// admin uclari KAPALI kalir (fail-closed), eski 'gbz-izle-2026' ile ACILMAZ.
	return os.Getenv("ADMIN_KEY")
}

func adminYetkili(r *http.Request) bool {
	k := adminKey()
	return k != "" && r.URL.Query().Get("key") == k
}

// POST /admin/login {user,pass} -> {key}. Panel key'i localStorage'da saklar.
func (h *Handler) AdminLogin(w http.ResponseWriter, r *http.Request) {
	var req struct {
		User string `json:"user"`
		Pass string `json:"pass"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	u := os.Getenv("ADMIN_USER")
	if u == "" {
		u = "admin"
	}
	p := os.Getenv("ADMIN_PASS")
	if p == "" {
		p = "Gebzem2026!"
	}
	if req.User == u && req.Pass == p {
		if adminKey() == "" { // TARAMA #16: env yoksa panel kapali (bos key sizdirma)
			writeErr(w, http.StatusServiceUnavailable, "admin kapali (ADMIN_KEY tanimsiz)")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"key": adminKey()})
		return
	}
	writeErr(w, http.StatusUnauthorized, "hatali kullanici adi veya sifre")
}

// GET /admin/stats?key= -> ozet sayilar
func (h *Handler) AdminStats(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	var uc, cc, cok, ccev, cakt, cvid int
	h.db.QueryRow(r.Context(), `SELECT count(*) FROM users`).Scan(&uc)
	h.db.QueryRow(r.Context(), `SELECT count(*) FROM calls`).Scan(&cc)
	h.db.QueryRow(r.Context(), `SELECT count(*) FROM calls WHERE status='ended' AND ended_at-answered_at >= interval '2 seconds'`).Scan(&cok)
	h.db.QueryRow(r.Context(), `SELECT count(*) FROM calls WHERE status IN ('missed','rejected')`).Scan(&ccev)
	h.db.QueryRow(r.Context(), `SELECT count(*) FROM calls WHERE status='active'`).Scan(&cakt)
	h.db.QueryRow(r.Context(), `SELECT count(*) FROM calls WHERE type='video'`).Scan(&cvid)
	w.Header().Set("Access-Control-Allow-Origin", "*")
	writeJSON(w, http.StatusOK, map[string]int{
		"users": uc, "calls": cc, "konusuldu": cok, "cevapsiz": ccev, "aktif": cakt, "video": cvid,
	})
}

// GET /admin/users?key= -> kullanici listesi (arama/mesaj sayilariyla)
func (h *Handler) AdminUsers(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.phone, COALESCE(u.avatar_url,''),
		       u.coin_balance, u.verified, to_char(u.created_at,'DD.MM.YY HH24:MI'),
		       COALESCE(to_char(u.last_seen,'DD.MM HH24:MI'),'-'),
		       (SELECT count(*) FROM calls c WHERE c.caller_id=u.id OR c.callee_id=u.id),
		       (SELECT count(*) FROM messages m WHERE m.sender_id=u.id)
		FROM users u ORDER BY u.created_at DESC LIMIT 300`)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sorgu hatasi")
		return
	}
	defer rows.Close()
	type u struct {
		ID       string `json:"id"`
		Name     string `json:"name"`
		Username string `json:"username"`
		Phone    string `json:"phone"`
		Avatar   string `json:"avatar"`
		Coin     int64  `json:"coin"`
		Verified bool   `json:"verified"`
		Created  string `json:"created"`
		LastSeen string `json:"last_seen"`
		Calls    int    `json:"calls"`
		Msgs     int    `json:"msgs"`
	}
	out := []u{}
	for rows.Next() {
		var x u
		if rows.Scan(&x.ID, &x.Name, &x.Username, &x.Phone, &x.Avatar, &x.Coin, &x.Verified,
			&x.Created, &x.LastSeen, &x.Calls, &x.Msgs) == nil {
			out = append(out, x)
		}
	}
	w.Header().Set("Access-Control-Allow-Origin", "*")
	writeJSON(w, http.StatusOK, out)
}

// GET /admin/user/{id}?key= -> profil + tum aramalari
func (h *Handler) AdminUserDetail(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	id := chi.URLParam(r, "id")
	var name, username, phone, avatar, about, created, lastSeen string
	var coin int64
	var verified bool
	err := h.db.QueryRow(r.Context(), `
		SELECT name, COALESCE(username,''), phone, COALESCE(avatar_url,''), about,
		       coin_balance, verified, to_char(created_at,'DD.MM.YYYY HH24:MI'),
		       COALESCE(to_char(last_seen,'DD.MM.YY HH24:MI'),'-')
		FROM users WHERE id=$1`, id).
		Scan(&name, &username, &phone, &avatar, &about, &coin, &verified, &created, &lastSeen)
	if err != nil {
		writeErr(w, http.StatusNotFound, "kullanici bulunamadi")
		return
	}
	rows, _ := h.db.Query(r.Context(), `
		SELECT c.type, c.status, (c.caller_id=$1) AS giden,
		       COALESCE(p.name,'?'), to_char(c.created_at,'DD.MM HH24:MI'),
		       COALESCE(EXTRACT(EPOCH FROM (c.ended_at-c.answered_at))::int, -1)
		FROM calls c
		JOIN users p ON p.id = CASE WHEN c.caller_id=$1 THEN c.callee_id ELSE c.caller_id END
		WHERE c.caller_id=$1 OR c.callee_id=$1
		ORDER BY c.created_at DESC LIMIT 100`, id)
	type call struct {
		Type   string `json:"type"`
		Status string `json:"status"`
		Giden  bool   `json:"giden"`
		Peer   string `json:"peer"`
		Zaman  string `json:"zaman"`
		Talk   int    `json:"talk"`
	}
	calls := []call{}
	if rows != nil {
		for rows.Next() {
			var c call
			if rows.Scan(&c.Type, &c.Status, &c.Giden, &c.Peer, &c.Zaman, &c.Talk) == nil {
				calls = append(calls, c)
			}
		}
		rows.Close()
	}
	w.Header().Set("Access-Control-Allow-Origin", "*")
	writeJSON(w, http.StatusOK, map[string]any{
		"name": name, "username": username, "phone": phone, "avatar": avatar, "about": about,
		"coin": coin, "verified": verified, "created": created, "last_seen": lastSeen, "calls": calls,
	})
}

var adminUpgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

// GET /admin/ws?key=X — arama olayi (call.incoming/answered/ended) olunca panele ANINDA
// "guncelle" push eder (Redis "events" dinlenir). Panel bunu alinca /admin/calls'i taze ceker.
func (h *Handler) AdminWS(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	conn, err := adminUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	sub := h.hub.Subscribe(r.Context())
	defer sub.Close()
	ch := sub.Channel()
	for {
		select {
		case <-r.Context().Done():
			return
		case msg, ok := <-ch:
			if !ok {
				return
			}
			if strings.Contains(msg.Payload, "call.") {
				conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
				if conn.WriteMessage(websocket.TextMessage, []byte("guncelle")) != nil {
					return
				}
			}
		}
	}
}

// GET /admin/calls?key=X — son 50 arama (isim + sureler), panel JS'i buradan ceker
func (h *Handler) AdminCalls(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	rows, err := h.db.Query(r.Context(), `
		SELECT substr(c.id::text,1,8), c.type, c.status,
		       COALESCE(uc.name,'?'), COALESCE(ue.name,'?'),
		       to_char(c.created_at,'HH24:MI:SS'),
		       COALESCE(to_char(c.answered_at,'HH24:MI:SS'),'-'),
		       COALESCE(to_char(c.ended_at,'HH24:MI:SS'),'-'),
		       COALESCE(EXTRACT(EPOCH FROM (c.answered_at-c.created_at))::int, -1),
		       COALESCE(EXTRACT(EPOCH FROM (c.ended_at-c.answered_at))::int, -1)
		FROM calls c
		JOIN users uc ON uc.id=c.caller_id
		JOIN users ue ON ue.id=c.callee_id
		ORDER BY c.created_at DESC LIMIT 50`)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "sorgu hatasi")
		return
	}
	defer rows.Close()
	type row struct {
		ID      string `json:"id"`
		Type    string `json:"type"`
		Status  string `json:"status"`
		Caller  string `json:"caller"`
		Callee  string `json:"callee"`
		Basla   string `json:"basla"`
		Cevap   string `json:"cevap"`
		Bitis   string `json:"bitis"`
		RingSec int    `json:"ring_sec"`
		TalkSec int    `json:"talk_sec"`
	}
	out := []row{}
	for rows.Next() {
		var x row
		if rows.Scan(&x.ID, &x.Type, &x.Status, &x.Caller, &x.Callee,
			&x.Basla, &x.Cevap, &x.Bitis, &x.RingSec, &x.TalkSec) == nil {
			out = append(out, x)
		}
	}
	w.Header().Set("Access-Control-Allow-Origin", "*")
	writeJSON(w, http.StatusOK, out)
}

// GET /admin/audio?key=X — canli ses teshis kayitlari (bellek; yeni ustte)
func (h *Handler) AdminAudio(w http.ResponseWriter, r *http.Request) {
	if !adminYetkili(r) {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	audioMu.Lock()
	out := make([]audioKayit, len(audioBuf))
	for i := range audioBuf {
		out[i] = audioBuf[len(audioBuf)-1-i] // ters: en yeni ustte
	}
	audioMu.Unlock()
	w.Header().Set("Access-Control-Allow-Origin", "*")
	writeJSON(w, http.StatusOK, out)
}

// GET /admin/izle?key=X — canli arama izleme paneli (HTML)
func (h *Handler) AdminPanel(w http.ResponseWriter, r *http.Request) {
	// Panel HTML herkese acik (login ekrani icinde); asil koruma /admin/stats|users|calls (key ile)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(adminHTML))
}

const adminHTML = `<!doctype html><html lang=tr><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Gebzem · Admin</title>
<style>
:root{--bg:#0b0f17;--side:#111725;--card:#161d2e;--card2:#1c2436;--line:#242d42;--txt:#e8ecf4;--dim:#8b95ad;--acc:#6366f1;--acc2:#8b5cf6;--green:#22c55e;--yellow:#eab308;--red:#ef4444;--orange:#f97316;--purple:#a855f7}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--txt);font-family:-apple-system,system-ui,'Segoe UI',sans-serif;min-height:100vh}
.login{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px;background:radial-gradient(900px 500px at 50% -10%,#1a2340,#0b0f17)}
.lcard{background:var(--card);border:1px solid var(--line);border-radius:22px;padding:36px 30px;width:100%;max-width:360px;box-shadow:0 30px 80px rgba(0,0,0,.5)}
.llogo{font-size:30px;font-weight:800;text-align:center;background:linear-gradient(90deg,var(--acc),var(--acc2));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.lsub{text-align:center;color:var(--dim);margin:4px 0 26px;font-size:14px}
.login input{width:100%;background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:13px 15px;color:var(--txt);font-size:15px;margin-bottom:12px;outline:none;transition:.15s}
.login input:focus{border-color:var(--acc)}
.login button{width:100%;background:linear-gradient(90deg,var(--acc),var(--acc2));color:#fff;border:0;border-radius:12px;padding:14px;font-size:15px;font-weight:700;cursor:pointer;margin-top:6px}
.login button:active{transform:scale(.98)}
.lerr{color:var(--red);font-size:13px;text-align:center;margin-top:12px;min-height:18px}
.app{display:flex;min-height:100vh}
.side{width:225px;background:var(--side);border-right:1px solid var(--line);padding:22px 16px;display:flex;flex-direction:column;position:sticky;top:0;height:100vh}
.brand{font-size:21px;font-weight:800;margin-bottom:28px;padding:0 8px;background:linear-gradient(90deg,var(--acc),var(--acc2));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.side nav{display:flex;flex-direction:column;gap:4px}
.side nav a{display:flex;align-items:center;gap:11px;padding:12px 14px;border-radius:11px;color:var(--dim);font-size:14.5px;font-weight:600;cursor:pointer;transition:.15s}
.side nav a:hover{background:var(--card);color:var(--txt)}
.side nav a.active{background:linear-gradient(90deg,rgba(99,102,241,.20),rgba(139,92,246,.08));color:#fff}
.logout{margin-top:auto;padding:12px 14px;border-radius:11px;color:var(--dim);font-size:14px;cursor:pointer;font-weight:600}
.logout:hover{background:rgba(239,68,68,.12);color:var(--red)}
.main{flex:1;padding:22px 26px;overflow-x:hidden}
.topbar{display:flex;align-items:center;justify-content:space-between;margin-bottom:22px}
.ptitle{font-size:22px;font-weight:800}
.live{display:flex;align-items:center;gap:7px;font-size:12.5px;color:var(--green);background:rgba(34,197,94,.12);padding:6px 13px;border-radius:20px}
.dd{width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 8px var(--green);animation:pp 1.4s infinite}
@keyframes pp{0%,100%{opacity:1}50%{opacity:.35}}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:14px;margin-bottom:24px}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px 20px;position:relative;overflow:hidden}
.kpi:before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,var(--acc),var(--acc2))}
.kpi .n{font-size:32px;font-weight:800;line-height:1}
.kpi .l{font-size:12.5px;color:var(--dim);margin-top:7px}
.kpi .ic{position:absolute;top:16px;right:18px;font-size:22px;opacity:.5}
.ulist{display:flex;flex-direction:column;gap:9px}
.u{background:var(--card);border:1px solid var(--line);border-radius:15px;padding:13px 16px;display:flex;align-items:center;gap:14px;cursor:pointer;transition:.15s}
.u:hover{background:var(--card2);transform:translateX(3px);border-color:var(--acc)}
.av{width:44px;height:44px;border-radius:50%;background:linear-gradient(135deg,var(--acc),var(--acc2));display:flex;align-items:center;justify-content:center;font-weight:700;font-size:18px;flex-shrink:0;color:#fff}
.uinfo{flex:1;min-width:0}
.uname{font-size:15px;font-weight:700;display:flex;align-items:center;gap:7px}
.tik{color:var(--acc);font-size:13px}
.umeta{font-size:12.5px;color:var(--dim);margin-top:3px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ustat{text-align:right;font-size:12px;color:var(--dim);white-space:nowrap}
.ustat b{color:var(--txt);font-size:15px}
.clist{display:flex;flex-direction:column;gap:8px}
.c{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--dim);border-radius:13px;padding:12px 15px;display:flex;align-items:center;justify-content:space-between;gap:12px;transition:.15s}
.c:hover{background:var(--card2)}
.c.g{border-left-color:var(--green)}.c.y{border-left-color:var(--yellow)}.c.r{border-left-color:var(--red)}.c.o{border-left-color:var(--orange)}.c.p{border-left-color:var(--purple)}.c.m{border-left-color:#3a4258;opacity:.7}
.who{font-size:14.5px;font-weight:600}.who .ar{color:var(--dim);margin:0 5px}
.cmeta{font-size:12px;color:var(--dim);margin-top:4px;display:flex;gap:11px;flex-wrap:wrap}
.badge{font-size:11.5px;font-weight:700;padding:4px 10px;border-radius:8px;white-space:nowrap}
.badge.g{background:rgba(34,197,94,.16);color:#4ade80}.badge.y{background:rgba(234,179,8,.16);color:var(--yellow)}.badge.r{background:rgba(239,68,68,.18);color:#f87171}.badge.o{background:rgba(249,115,22,.16);color:var(--orange)}.badge.p{background:rgba(168,85,247,.16);color:var(--purple)}.badge.m{background:rgba(139,149,173,.14);color:var(--dim)}
.dur{font-size:18px;font-weight:800}.dur small{font-size:11px;color:var(--dim)}
.empty{text-align:center;padding:60px 20px;color:var(--dim)}.empty .i{font-size:50px;margin-bottom:12px}
.back{color:var(--acc);cursor:pointer;font-size:14px;margin-bottom:16px;display:inline-block;font-weight:600}
.prof{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:22px;display:flex;gap:18px;align-items:center;margin-bottom:20px;flex-wrap:wrap}
.prof .pn{font-size:20px;font-weight:800}
.prof .pm{color:var(--dim);font-size:13.5px;margin-top:5px;line-height:1.7}
.pill{display:inline-block;background:var(--card2);border:1px solid var(--line);border-radius:8px;padding:3px 10px;font-size:12px;margin:3px 4px 0 0}
@media(max-width:720px){.side{width:60px;padding:18px 6px}.side nav a span,.brand span,.logout span{display:none}.brand{text-align:center}.side nav a{justify-content:center}.main{padding:16px 13px}}
</style></head><body>
<div id=login class=login>
 <div class=lcard>
  <div class=llogo>Gebzem</div>
  <div class=lsub>Yönetim Paneli</div>
  <input id=lu placeholder="Kullanıcı adı" autocomplete=username>
  <input id=lp type=password placeholder="Şifre" autocomplete=current-password>
  <button id=lbtn>Giriş Yap</button>
  <div id=lerr class=lerr></div>
 </div>
</div>
<div id=app class=app style=display:none>
 <aside class=side>
  <div class=brand>📞 <span>Gebzem</span></div>
  <nav id=nav>
   <a data-t=genel class=active>📊 <span>Genel Bakış</span></a>
   <a data-t=users>👥 <span>Kullanıcılar</span></a>
   <a data-t=calls>📞 <span>Aramalar</span></a>
   <a data-t=ses>🔊 <span>Ses Teşhis</span></a>
  </nav>
  <div class=logout id=logout>🚪 <span>Çıkış</span></div>
 </aside>
 <main class=main>
  <div class=topbar><div class=ptitle id=ptitle>Genel Bakış</div><div class=live><span class=dd></span><span id=st>canlı</span></div></div>
  <div id=content></div>
 </main>
</div>
<script>
var key=localStorage.getItem('gbzkey')||'',sekme='genel';
function esc(s){var e=document.createElement('span');e.textContent=s==null?'':s;return e.innerHTML;}
function ic(s){return s&&s.length?s[0].toUpperCase():'?';}
function api(p){return fetch(p+(p.indexOf('?')<0?'?':'&')+'key='+encodeURIComponent(key)).then(function(r){if(r.status==401){cikis();throw 0;}return r.json();});}
document.getElementById('lbtn').onclick=giris;
document.getElementById('lp').addEventListener('keydown',function(e){if(e.key=='Enter')giris();});
function giris(){var u=document.getElementById('lu').value,p=document.getElementById('lp').value;
 fetch('/admin/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user:u,pass:p})})
  .then(function(r){return r.json().then(function(j){return{ok:r.ok,j:j};});})
  .then(function(x){if(x.ok&&x.j.key){key=x.j.key;localStorage.setItem('gbzkey',key);basla();}else{document.getElementById('lerr').textContent=x.j.error||'giriş başarısız';}})
  .catch(function(){document.getElementById('lerr').textContent='bağlantı hatası';});}
function cikis(){localStorage.removeItem('gbzkey');key='';document.getElementById('app').style.display='none';document.getElementById('login').style.display='flex';}
document.getElementById('logout').onclick=cikis;
document.querySelectorAll('#nav a').forEach(function(a){a.onclick=function(){window._detayAcik=false;document.querySelectorAll('#nav a').forEach(function(x){x.classList.remove('active');});a.classList.add('active');sekme=a.getAttribute('data-t');document.getElementById('ptitle').textContent=a.textContent.trim();ac();};});
function sb(s,t){if(s=='active')return['r','🔴 Canlı'];if(s=='missed')return['m','⚪ Cevapsız'];if(s=='rejected')return['o','🟠 Reddedildi'];if(s=='busy')return['p','🟣 Meşgul'];if(s=='ended')return t>=2?['g','🟢 Konuşuldu']:['y','🟡 Hemen koptu'];return['m',s];}
function callRow(c,pm){var talk=pm?c.talk:c.talk_sec;var b=sb(c.status,talk);var tip=c.type=='video'?'📹 Görüntülü':'🎤 Sesli';
 var who=pm?((c.giden?'→ ':'← ')+esc(c.peer)):(esc(c.caller)+'<span class=ar>→</span>'+esc(c.callee));
 var zaman=pm?('🕐 '+c.zaman):('🕐 '+c.basla+(c.bitis&&c.bitis!='-'?' → '+c.bitis:''));
 var ring=(!pm&&c.ring_sec>=0)?'<span>⚡ '+c.ring_sec+'sn</span>':'';
 var sure=(c.status=='ended'&&talk>=0)?'<div class=dur>'+talk+'<small>sn</small></div>':'';
 return '<div class="c '+b[0]+'"><div><div class=who>'+who+'</div><div class=cmeta><span>'+tip+'</span><span>'+zaman+'</span>'+ring+'</div></div><div style=text-align:right><span class="badge '+b[0]+'">'+b[1]+'</span>'+sure+'</div></div>';}
function kpi(n,l,i){return '<div class=kpi><div class=ic>'+i+'</div><div class=n>'+n+'</div><div class=l>'+l+'</div></div>';}
function box(i,t){return '<div class=empty><div class=i>'+i+'</div>'+t+'</div>';}
function ac(){var C=document.getElementById('content');
 if(sekme=='genel'){api('/admin/stats').then(function(s){C.innerHTML='<div class=grid>'+kpi(s.users,'Kullanıcı','👥')+kpi(s.calls,'Toplam Arama','📞')+kpi(s.konusuldu,'Konuşuldu','🟢')+kpi(s.cevapsiz,'Cevapsız/Red','⚪')+kpi(s.video,'Görüntülü','📹')+kpi(s.aktif,'Şu An Aktif','🔴')+'</div><div style="color:var(--dim);font-size:13px">Kullanıcılar için sol menüyü kullan · Aramalar sekmesi anlık güncellenir.</div>';});}
 else if(sekme=='users'){api('/admin/users').then(function(d){window._u=d;if(!d.length){C.innerHTML=box('👥','Henüz kullanıcı yok');return;}var h='<div class=ulist>';for(var i=0;i<d.length;i++){var u=d[i];h+='<div class=u onclick=detay('+i+')><div class=av>'+esc(ic(u.name))+'</div><div class=uinfo><div class=uname>'+esc(u.name||'(isimsiz)')+(u.verified?'<span class=tik>✔</span>':'')+'</div><div class=umeta>'+(u.username?'@'+esc(u.username)+' · ':'')+esc(u.phone)+' · '+esc(u.created)+'</div></div><div class=ustat><b>'+u.calls+'</b> arama<br><b>'+u.msgs+'</b> mesaj</div></div>';}C.innerHTML=h+'</div>';});}
 else if(sekme=='calls'){yenile();}
 else if(sekme=='ses'){sesYenile();}}
function sesRenk(d){if(d.indexOf('KURTARMA')>=0)return'o';if(d.indexOf('SORUN')>=0)return'r';if(d.indexOf('MIK-OLU')>=0)return'r';if(d.indexOf('CIKIS-OLU')>=0)return'r';if(d=='SES-VAR')return'g';if(d=='iOS-CIKIS-YOK')return'r';if(d=='SES-GELMIYOR')return'o';if(d=='TRACK-YOK')return'p';if(d=='SES-DUSUK')return'y';return'm';}
function sesYenile(){if(sekme!='ses')return;api('/admin/audio').then(function(d){var C=document.getElementById('content');
 if(!d.length){C.innerHTML=box('🔊','Henüz ses verisi yok. İki telefonla arama başlat — konuşurken her 2 saniyede bir durum buraya düşer.');return;}
 var h='<div style="color:var(--dim);font-size:12px;line-height:1.9;margin-bottom:14px;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px 15px">🟢 <b>SES-VAR</b> ses gidiyor · 🔴 <b>iOS-CIKIS-YOK</b> ses geliyor ama iPhone çalmıyor · 🟠 <b>SES-GELMIYOR</b> paket akmıyor (ağ) · 🟣 <b>TRACK-YOK</b> ses kanalı yok · 🟡 <b>SES-DUSUK</b> o an sessiz (doğal olabilir) · 🔴 <b>MIK-OLU / CIKIS-OLU?</b> ölü birim adayı · 🟠 <b>KURTARMA</b> istemci ses birimini yeniden kurdu</div><div class=clist>';
 for(var i=0;i<d.length;i++){var x=d[i];var r=sesRenk(x.durum);var tip=x.tip=='VIDEO'?'📹':'🎤';
  h+='<div class="c '+r+'"><div style=min-width:0><div class=who>'+tip+' '+esc(x.yon)+' <span class=ar>·</span> '+esc(x.user)+' <span style=color:var(--dim);font-weight:400>('+esc(x.call)+')</span></div><div class=cmeta><span>🕐 '+esc(x.saat)+'</span><span>📦 '+x.recv+' (Δ'+x.delta+')</span><span>🔊 '+(x.enerji!=null?x.enerji.toFixed(1):'0')+'</span>'+(x.ios&&x.ios!='-'?'<span>📱 '+esc(x.ios)+'</span>':'')+'<span>'+(x.hoparlor?'📢 hop':'📞 kulak')+'</span></div></div><span class="badge '+r+'">'+esc(x.durum)+'</span></div>';}
 C.innerHTML=h+'</div>';});}
window.detay=function(i){window._detayAcik=true;var u=window._u[i];api('/admin/user/'+u.id).then(function(d){document.getElementById('ptitle').textContent='Kullanıcı Profili';
 var h='<span class=back onclick=geriUsers()>← Kullanıcılar</span><div class=prof><div class=av style=width:70px;height:70px;font-size:28px>'+esc(ic(d.name))+'</div><div><div class=pn>'+esc(d.name||'(isimsiz)')+(d.verified?' <span class=tik>✔</span>':'')+'</div><div class=pm>'+(d.username?'@'+esc(d.username)+'<br>':'')+'📱 '+esc(d.phone)+'<br>'+esc(d.about||'')+'</div><div style=margin-top:8px><span class=pill>🪙 '+d.coin+' jeton</span><span class=pill>📅 '+esc(d.created)+'</span><span class=pill>👁 '+esc(d.last_seen)+'</span></div></div></div>';
 h+='<div style="font-weight:700;margin:6px 0 12px">📞 Görüşmeleri ('+d.calls.length+')</div>';
 if(!d.calls.length)h+=box('📭','Bu kullanıcının araması yok');else{h+='<div class=clist>';for(var i=0;i<d.calls.length;i++)h+=callRow(d.calls[i],true);h+='</div>';}
 document.getElementById('content').innerHTML=h;});};
window.geriUsers=function(){window._detayAcik=false;document.getElementById('ptitle').textContent='Kullanıcılar';sekme='users';ac();};
function yenile(){if(sekme!='calls')return;api('/admin/calls').then(function(d){var C=document.getElementById('content');if(!d.length){C.innerHTML=box('📭','Henüz arama yok. İki telefonla arama yap — anlık göreceksin.');return;}var h='<div class=clist>';for(var i=0;i<d.length;i++)h+=callRow(d[i],false);C.innerHTML=h+'</div>';});}
function ws(){try{var s=new WebSocket((location.protocol=='https:'?'wss':'ws')+'://'+location.host+'/admin/ws?key='+encodeURIComponent(key));s.onmessage=function(){if(sekme=='calls')yenile();document.getElementById('st').textContent='canlı · '+new Date().toLocaleTimeString('tr');};s.onclose=function(){setTimeout(ws,2000);};}catch(e){setTimeout(ws,2000);}}
function basla(){document.getElementById('login').style.display='none';document.getElementById('app').style.display='flex';ac();ws();setInterval(function(){if(sekme=='calls')yenile();},10000);setInterval(function(){if(sekme=='ses')sesYenile();},2000);setInterval(function(){if(sekme=='genel'||(sekme=='users'&&!window._detayAcik))ac();},2000);}
if(key)basla();
</script></body></html>`

func getEnv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": fmt.Sprint(msg)})
}
