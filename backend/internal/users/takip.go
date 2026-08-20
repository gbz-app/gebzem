package users

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
)

// ⚠️⚠️ TURU 75 — TAKIP SISTEMI.
//
// Sosyal katmanin temeli: akis, kanal ve bildirimlerin HEPSI buna dayanir.
//
// TASARIM KARARLARI:
//  · `follows` `blocks`tan AYRI: engelleme mesajlasmayi keser, takip icerik
//    iliskisidir. AMA engelleme takibi de DUSURUR (asagida, uygulama katmaninda —
//    DB tetikleyicisi kullanilmadi: gizli davranis hata ayiklamayi zorlastirir).
//  · SAYACLAR DENORMALIZE (`users.takipci_sayisi` vb.): her profil acilisinda
//    `count(*)` tam tarama demek. AYNI TRANSACTION'da guncellenir.
//  · GIZLI HESAP: takip ONAY bekler (`durum='bekliyor'`).
//
// ⚠️ TUM sayac guncellemeleri takip satiriyla AYNI TRANSACTION'da — aksi halde
//    ag hatasinda sayac ile gercek AYRISIR ve geri donmek pahali olur.

type takipDurumResp struct {
	TakipEdiyorMu  bool `json:"takip_ediyor_mu"`
	BekliyorMu     bool `json:"bekliyor_mu"`
	TakipEdiyorMu2 bool `json:"beni_takip_ediyor_mu"`
	Engelli        bool `json:"engelli"`
}

// POST /users/{id}/follow — takip et.
// ⚠️ IDEMPOTENT: zaten takip ediyorsa 200 doner, sayac IKI KEZ ARTMAZ.
func (h *Handler) Follow(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	if hedef == "" || hedef == me {
		writeErr(w, http.StatusBadRequest, "geçersiz kullanıcı")
		return
	}

	// ⚠️ ENGEL KAPISI: engellenmis (ya da engellemis) birini takip EDEMEZSIN.
	//    Aksi halde engelleme delinir: engellenen kisi takip edip gonderilerini
	//    gormeye devam ederdi.
	var engelli bool
	if err := h.db.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM blocks
		 WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		me, hedef).Scan(&engelli); err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	if engelli {
		// ⚠️ NOTR metin: engellenmis olduğunu IFSA etme.
		writeErr(w, http.StatusForbidden, "bu kullanıcı takip edilemiyor")
		return
	}

	var gizli bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT gizli_hesap FROM users WHERE id=$1`, hedef).Scan(&gizli); err == pgx.ErrNoRows {
		writeErr(w, http.StatusNotFound, "kullanıcı bulunamadı")
		return
	} else if err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}

	durum := "onayli"
	if gizli {
		durum = "bekliyor"
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	defer tx.Rollback(r.Context())

	// ⚠️ `ON CONFLICT DO NOTHING` + `RowsAffected` -> sayac YALNIZ GERCEKTEN yeni
	//    satirda artar (idempotency).
	tag, err := tx.Exec(r.Context(), `
		INSERT INTO follows (follower_id, followee_id, durum) VALUES ($1,$2,$3)
		ON CONFLICT DO NOTHING`, me, hedef, durum)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "takip edilemedi")
		return
	}
	yeni := tag.RowsAffected() == 1
	if yeni && durum == "onayli" {
		tx.Exec(r.Context(), `UPDATE users SET takipci_sayisi = takipci_sayisi + 1 WHERE id=$1`, hedef)
		tx.Exec(r.Context(), `UPDATE users SET takip_sayisi   = takip_sayisi   + 1 WHERE id=$1`, me)
	}
	// ⚠️ TURU 76: satir tx icinde, DUYURU (WS+push) COMMIT SONRASI.
	bildirimTuru := ""
	duyur := false
	if yeni {
		bildirimTuru = "takip"
		if durum == "bekliyor" {
			bildirimTuru = "takip_istegi"
		}
		if h.bil != nil {
			duyur = h.bil.Yaz(r.Context(), tx, hedef, me, bildirimTuru, "", "")
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "takip edilemedi")
		return
	}
	if duyur {
		h.bil.Duyur(r.Context(), hedef, me, bildirimTuru, "", "")
	}
	writeJSON(w, http.StatusOK, map[string]any{"durum": durum})
}

// DELETE /users/{id}/follow — takibi birak. Idempotent.
func (h *Handler) Unfollow(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	if hedef == "" || hedef == me {
		writeErr(w, http.StatusBadRequest, "geçersiz kullanıcı")
		return
	}
	if err := h.takibiKaldir(r.Context(), me, hedef); err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// takibiKaldir — ORTAK YOL: hem "takibi birak" hem "engelle" bunu kullanir.
// ⚠️ Sayac YALNIZ 'onayli' satir silindiyse duser (bekleyen istek sayaca girmemisti).
func (h *Handler) takibiKaldir(ctx context.Context, takipci, takipEdilen string) error {
	tx, err := h.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var durum string
	err = tx.QueryRow(ctx, `
		DELETE FROM follows WHERE follower_id=$1 AND followee_id=$2
		RETURNING durum`, takipci, takipEdilen).Scan(&durum)
	if err == pgx.ErrNoRows {
		return tx.Commit(ctx) // zaten takip etmiyor — idempotent
	}
	if err != nil {
		return err
	}
	if durum == "onayli" {
		// ⚠️ `GREATEST(...,0)`: sayac bir sekilde kaymissa NEGATIFE dusmesin.
		tx.Exec(ctx, `UPDATE users SET takipci_sayisi = GREATEST(takipci_sayisi - 1, 0) WHERE id=$1`, takipEdilen)
		tx.Exec(ctx, `UPDATE users SET takip_sayisi   = GREATEST(takip_sayisi   - 1, 0) WHERE id=$1`, takipci)
	}
	return tx.Commit(ctx)
}

// POST /users/{id}/follow/approve — takip istegini onayla (gizli hesap).
func (h *Handler) FollowApprove(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	istekci := chi.URLParam(r, "id")

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	defer tx.Rollback(r.Context())

	tag, err := tx.Exec(r.Context(), `
		UPDATE follows SET durum='onayli'
		 WHERE follower_id=$1 AND followee_id=$2 AND durum='bekliyor'`, istekci, me)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "bekleyen istek yok")
		return
	}
	tx.Exec(r.Context(), `UPDATE users SET takipci_sayisi = takipci_sayisi + 1 WHERE id=$1`, me)
	tx.Exec(r.Context(), `UPDATE users SET takip_sayisi   = takip_sayisi   + 1 WHERE id=$1`, istekci)
	onayDuyur := false
	if h.bil != nil {
		onayDuyur = h.bil.Yaz(r.Context(), tx, istekci, me, "takip_onaylandi", "", "")
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "işlem yapılamadı")
		return
	}
	if onayDuyur {
		h.bil.Duyur(r.Context(), istekci, me, "takip_onaylandi", "", "")
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// DELETE /users/{id}/follow/approve — takip istegini reddet.
func (h *Handler) FollowReject(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	istekci := chi.URLParam(r, "id")
	// ⚠️ Sayac DOKUNULMAZ: bekleyen istek sayaca hic girmemisti.
	h.db.Exec(r.Context(), `
		DELETE FROM follows WHERE follower_id=$1 AND followee_id=$2 AND durum='bekliyor'`,
		istekci, me)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// GET /users/{id}/followers · /users/{id}/following — listeler (sayfali).
func (h *Handler) FollowList(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	takipciler := chi.URLParam(r, "tur") == "followers"

	// ⚠️⚠️ TURU 76 — ENGEL KAPISI (erisim). Engellenen kisi engelleyenin
	//    takipci/takip listesini okuyup SOSYAL GRAFIGINI dokebiliyordu.
	if engel.Var(r.Context(), h.db, me, hedef) {
		writeErr(w, http.StatusNotFound, "kullanıcı bulunamadı")
		return
	}
	// ⚠️ GIZLILIK: gizli hesabin listelerini yalniz KENDISI ve ONAYLI TAKIPCILERI gorur.
	if hedef != me {
		var gizli bool
		h.db.QueryRow(r.Context(), `SELECT gizli_hesap FROM users WHERE id=$1`, hedef).Scan(&gizli)
		if gizli {
			var onayli bool
			h.db.QueryRow(r.Context(), `
				SELECT EXISTS(SELECT 1 FROM follows
				 WHERE follower_id=$1 AND followee_id=$2 AND durum='onayli')`,
				me, hedef).Scan(&onayli)
			if !onayli {
				writeErr(w, http.StatusForbidden, "bu hesap gizli")
				return
			}
		}
	}

	limit := 30
	if v, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && v > 0 && v <= 100 {
		limit = v
	}
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	var sorgu string
	if takipciler {
		// ⚠️ ICERIK SUZGECI: ucuncu bir kisinin listesinde de engelli taraflar
		//    birbirini GORMEZ ($4 = okuyan kullanici).
		sorgu = `SELECT u.id, COALESCE(u.username,''), u.name, u.about, u.avatar_url, u.avatar_media_id
		           FROM follows f JOIN users u ON u.id = f.follower_id
		          WHERE f.followee_id=$1 AND f.durum='onayli'` + engel.Yuklem("$4", "u.id") + `
		          ORDER BY f.created_at DESC LIMIT $2 OFFSET $3`
	} else {
		sorgu = `SELECT u.id, COALESCE(u.username,''), u.name, u.about, u.avatar_url, u.avatar_media_id
		           FROM follows f JOIN users u ON u.id = f.followee_id
		          WHERE f.follower_id=$1 AND f.durum='onayli'` + engel.Yuklem("$4", "u.id") + `
		          ORDER BY f.created_at DESC LIMIT $2 OFFSET $3`
	}
	rows, err := h.db.Query(r.Context(), sorgu, hedef, limit, offset, me)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "liste alınamadı")
		return
	}
	defer rows.Close()
	out := []userResp{}
	for rows.Next() {
		var u userResp
		if rows.Scan(&u.ID, &u.Username, &u.Name, &u.About, &u.AvatarURL,
			&u.AvatarMediaID) == nil {
			out = append(out, u)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// GET /users/me/follow-requests — bekleyen takip istekleri (gizli hesap).
func (h *Handler) FollowRequests(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, COALESCE(u.username,''), u.name, u.about, u.avatar_url, u.avatar_media_id
		  FROM follows f JOIN users u ON u.id = f.follower_id
		 WHERE f.followee_id=$1 AND f.durum='bekliyor'
		 ORDER BY f.created_at DESC LIMIT 100`, me)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "liste alınamadı")
		return
	}
	defer rows.Close()
	out := []userResp{}
	for rows.Next() {
		var u userResp
		if rows.Scan(&u.ID, &u.Username, &u.Name, &u.About, &u.AvatarURL,
			&u.AvatarMediaID) == nil {
			out = append(out, u)
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// GET /users/{id}/profile — herkese acik profil + iliski durumu.
func (h *Handler) Profile(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")

	// ⚠️⚠️ TURU 76 — ENGEL KAPISI. Bu kapi YOKTU: engellenen kisi engelleyenin
	//    TAM profilini goruyordu (ad, @kullaniciadi, hakkimda, AVATAR, takipci/
	//    takip/gonderi sayilari, dis baglanti). Kullanicinin "HİÇ görememeli"
	//    talebinin tam merkezi.
	// ⚠️ 403 DEGIL **404**: 403 "bu kisi seni engelledi" bilgisini IFSA eder.
	//    "kullanıcı bulunamadı" WhatsApp/Instagram davranisidir.
	if engel.Var(r.Context(), h.db, me, hedef) {
		writeErr(w, http.StatusNotFound, "kullanıcı bulunamadı")
		return
	}

	var u userResp
	var gizli bool
	var takipci, takip, gonderi int
	var baglanti string
	err := h.db.QueryRow(r.Context(), `
		SELECT id, COALESCE(username,''), name, about, avatar_url, avatar_media_id,
		       kapak_media_id, onayli,
		       dogum_yili, ilgi_alanlari, takim,
		       gizli_hesap, takipci_sayisi, takip_sayisi, gonderi_sayisi, baglanti
		  FROM users WHERE id=$1 AND verified=true`, hedef).
		Scan(&u.ID, &u.Username, &u.Name, &u.About, &u.AvatarURL, &u.AvatarMediaID,
			&u.KapakMediaID, &u.Onayli,
			&u.DogumYili, &u.IlgiAlanlari, &u.Takim,
			&gizli, &takipci, &takip, &gonderi, &baglanti)
	if err == pgx.ErrNoRows {
		writeErr(w, http.StatusNotFound, "kullanıcı bulunamadı")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "profil alınamadı")
		return
	}

	// Iliski durumu (tek sorguda).
	var d takipDurumResp
	h.db.QueryRow(r.Context(), `
		SELECT
		  EXISTS(SELECT 1 FROM follows WHERE follower_id=$1 AND followee_id=$2 AND durum='onayli'),
		  EXISTS(SELECT 1 FROM follows WHERE follower_id=$1 AND followee_id=$2 AND durum='bekliyor'),
		  EXISTS(SELECT 1 FROM follows WHERE follower_id=$2 AND followee_id=$1 AND durum='onayli'),
		  EXISTS(SELECT 1 FROM blocks  WHERE blocker_id=$1 AND blocked_id=$2)`,
		me, hedef).Scan(&d.TakipEdiyorMu, &d.BekliyorMu, &d.TakipEdiyorMu2, &d.Engelli)

	// ⚠️⚠️⚠️ TURU 78 — SEVK ENGELI DUZELTMESI (denetim bulgusu).
	//
	//    Yanit ELLE KURULAN bir harita ve bu BILINCLI bir guvenlik tercihi:
	//    profil HERKESE ACIK bir uctur, `userResp`u gomseydik `phone` ve
	//    `coin_balance` gibi alanlar ileride SESSIZCE sizabilirdi. Yani
	//    "beyaz liste" dogru desendir.
	//
	//    ⚠️ AMA BEDELI SU: sorguya sutun eklemek TEK BASINA YETMEZ, buraya da
	//    ANAHTAR eklenmeli. Turu 78'de tam bu atlandi: `kapak_media_id` ve
	//    `onayli` SELECT ediliyor, Scan ile struct'a yaziliyor ve sonra
	//    SESSIZCE ATILIYORDU. Sonuc: kapak gorseli ve onayli rozeti HICBIR
	//    PROFILDE gorunmeyecekti — yani FAZ A'nin kullaniciya donuk TEK
	//    ciktisi sahada YOK olacakti.
	//    ⚠️ TEK CIHAZDA TEST EDILSE DE GORULMEZDI: kullanici kendi kapagini
	//       DUZENLEME ekraninda gorur (o `/users/me`den beslenir) ve
	//       "calisiyor" sanir.
	//    ⚠️ Derleme de yakalamaz: alanlar Scan'e verildigi icin "kullanilmiyor"
	//       hatasi cikmaz; sutun/Scan muhafizi da hizali oldugu icin susar.
	//
	//    ⚠️ YAPMA: `userResp`u buraya gomme (telefon sizar).
	//    ⚠️ YAPMA: sorguya sutun ekleyip bu haritayi guncellemeyi unutma —
	//       `profil_yanit_test.go` bunu artik OTOMATIK dogruluyor.
	writeJSON(w, http.StatusOK, map[string]any{
		"id": u.ID, "username": u.Username, "name": u.Name, "about": u.About,
		"avatar_url": u.AvatarURL, "avatar_media_id": u.AvatarMediaID,
		"kapak_media_id": u.KapakMediaID, "onayli": u.Onayli,
		// ⚠️ TURU 120 — SELECT + Scan + BU HARITA UCU BIRLIKTE degisir;
		//    `profil_yanit_test.go` bunu otomatik dogruluyor.
		"dogum_yili": u.DogumYili, "ilgi_alanlari": u.IlgiAlanlari,
		"takim": u.Takim,
		"gizli_hesap": gizli, "baglanti": baglanti,
		"takipci_sayisi": takipci, "takip_sayisi": takip, "gonderi_sayisi": gonderi,
		"iliski": d,
		// ⚠️ Gonderiler AYRI ucta (`/users/{id}/posts`) — profil acilisini
		//    yavaslatmamak icin; ayrica gizli hesapta ERISIM KURALI farkli.
	})
}

// GET /notifications — bildirimler.
func (h *Handler) Notifications(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT b.id, b.tur, b.hedef_tur, b.hedef_id, b.okundu, b.created_at,
		       COALESCE(a.id::text,''), COALESCE(a.name,''), COALESCE(a.username,''),
		       COALESCE(a.avatar_url,''), a.avatar_media_id
		  FROM bildirimler b LEFT JOIN users a ON a.id = b.aktor_id
		 WHERE b.user_id=$1
		   -- ⚠️ TURU 76 — ENGEL SUZGECI: engelledigin kisinin gecmis "seni takip
		   -- etti / gonderini begendi / yorum yapti" satirlari ADI ve AVATARIYLA
		   -- listede duruyordu; engelleme sonrasi izi ekrandan SILINMIYORDU.
		   -- ⚠️ aktor_id IS NULL dali ZORUNLU: sistem bildirimlerinde aktor yoktur
		   -- ve o satirlar da elenmemelidir.
		   AND (b.aktor_id IS NULL OR NOT EXISTS(
		        SELECT 1 FROM blocks bl
		         WHERE (bl.blocker_id=$1 AND bl.blocked_id=b.aktor_id)
		            OR (bl.blocker_id=b.aktor_id AND bl.blocked_id=$1)))
		 ORDER BY b.created_at DESC LIMIT 100`, me)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "bildirimler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id int64
		var tur, hedefTur, hedefID, aktorID, aktorAd, aktorKullanici, aktorAvatar string
		var aktorMedya *string
		var okundu bool
		var t any
		if rows.Scan(&id, &tur, &hedefTur, &hedefID, &okundu, &t,
			&aktorID, &aktorAd, &aktorKullanici, &aktorAvatar, &aktorMedya) == nil {
			out = append(out, map[string]any{
				"id": id, "tur": tur, "hedef_tur": hedefTur, "hedef_id": hedefID,
				"okundu": okundu, "created_at": t,
				"aktor_id": aktorID, "aktor_ad": aktorAd,
				"aktor_username": aktorKullanici, "aktor_avatar": aktorAvatar,
				"aktor_avatar_media_id": aktorMedya,
			})
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// GET /notifications/count — okunmamis bildirim sayisi (rozet icin).
//
// ⚠️ AYRI UC: tam listeyi (LIMIT 100 + JOIN users) yalnizca rozet icin cekmek
//
//	savurganlik olurdu; rozet uygulama acilisinda ve WS olayinda sorulur.
//
// ⚠️ `idx_bildirim_okunmamis` (migration 020) tam bu sorgu icin var.
func (h *Handler) NotificationsCount(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var adet int
	h.db.QueryRow(r.Context(),
		`SELECT count(*) FROM bildirimler WHERE user_id=$1 AND NOT okundu`,
		me).Scan(&adet)
	writeJSON(w, http.StatusOK, map[string]int{"okunmamis": adet})
}

// POST /notifications/read — hepsini okundu isaretle.
func (h *Handler) NotificationsRead(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	h.db.Exec(r.Context(), `UPDATE bildirimler SET okundu=true WHERE user_id=$1 AND NOT okundu`, me)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// PATCH /users/me/privacy — gizli hesap ac/kapa.
func (h *Handler) SetPrivacy(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req struct {
		Gizli *bool `json:"gizli_hesap"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Gizli == nil {
		writeErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	// ⚠️ Gizliden ACIGA gecerken BEKLEYEN ISTEKLER OTOMATIK ONAYLANIR — aksi
	//    halde kullanici "hesabımı açtım ama istekler hala bekliyor" yasar.
	// ⚠️ COMMIT SONRASI duyurulacak alicilar (transaction icinde duyuru YAPILMAZ:
	//    geri alinan bir islem icin telefon titremesin).
	var topluOnaylananlar []string
	if !*req.Gizli {
		tx, err := h.db.Begin(r.Context())
		if err == nil {
			defer tx.Rollback(r.Context())
			// ⚠️⚠️ YALNIZ YENI ONAYLANANLARIN sayaci artar.
			// Ilk yazimda ikinci UPDATE `durum='onayli'` OLAN HERKESI guncelliyordu —
			// yani ZATEN onayli olan eski takipcilerin `takip_sayisi` da artiyordu
			// (cift sayim). `RETURNING` ile SADECE bu islemde degisen satirlar alinir.
			rows, qerr := tx.Query(r.Context(), `
				UPDATE follows SET durum='onayli'
				 WHERE followee_id=$1 AND durum='bekliyor'
				 RETURNING follower_id`, me)
			var yeniler []string
			if qerr == nil {
				for rows.Next() {
					var fid string
					if rows.Scan(&fid) == nil {
						yeniler = append(yeniler, fid)
					}
				}
				rows.Close()
			}
			if len(yeniler) > 0 {
				tx.Exec(r.Context(),
					`UPDATE users SET takipci_sayisi = takipci_sayisi + $2 WHERE id=$1`,
					me, len(yeniler))
				tx.Exec(r.Context(),
					`UPDATE users SET takip_sayisi = takip_sayisi + 1 WHERE id = ANY($1)`,
					yeniler)
				for _, fid := range yeniler {
					if h.bil != nil {
						h.bil.Yaz(r.Context(), tx, fid, me, "takip_onaylandi", "", "")
					}
				}
				// ⚠️ Duyuru COMMIT SONRASI, asagida (toplu).
				topluOnaylananlar = yeniler
			}
			if tx.Commit(r.Context()) != nil {
				topluOnaylananlar = nil // commit tutmadi -> duyurma
			}
		}
	}
	for _, fid := range topluOnaylananlar {
		if h.bil != nil {
			h.bil.Duyur(r.Context(), fid, me, "takip_onaylandi", "", "")
		}
	}
	if _, err := h.db.Exec(r.Context(),
		`UPDATE users SET gizli_hesap=$2 WHERE id=$1`, me, *req.Gizli); err != nil {
		writeErr(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
