package admin

import (
	"net/http"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

// ⚠️⚠️⚠️ TURU 181 — KULLANICI YONETIMI.
//
// ═══════════ ASKIYA ALMA: SEMADA VARDI, URUNDE YOKTU ═══════════
//
// `users.suspended_at` sutunu `015_medya.sql:132`'den beri duruyordu ama
// kod tabaninda TEK BIR OKUYAN/YAZAN YOKTU (olculdu: sifir eslesme).
// Yani bir taciz/spam hesabini durdurmanin TEK yolu satiri ELLE SILMEKTI —
// geri donusu olmayan, KVKK acisindan da yanlis bir islem.
//
// Turu 181'de UC parca birlikte yazildi (biri eksik olsa ozellik OLU kalir):
//  1. YAZAN yol      -> bu dosya
//  2. OKUYAN kapilar -> `auth.Middleware` + `auth.Handler.Login`
//  3. ONBELLEK       -> `auth.Gecersizlestir` (yoksa askı 5 dakika gecikir)
//
// ⚠️ YAPMA: askiya alirken `auth.Gecersizlestir` cagrisini atlama.

// KullaniciListesi — GET /admin/kullanicilar?q=&askida=&limit=&offset=
//
// ⚠️ Mevcut `/admin/users` ucu (calls paketi) YERINDE DURUYOR ama arama /
//
//	sayfalama / askı suzgeci YOK ve LIMIT 300 SABIT. Bu uc onun yerine
//	gecmez, YANINDA durur: panel yeni olani kullanir.
func (h *Handler) KullaniciListesi(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	q := kisalt(r.URL.Query().Get("q"), 60)
	limit := sayi(r, "limit", 50, 1, 200)
	offset := sayi(r, "offset", 0, 0, 100000)
	// ⚠️ Uc durumlu suzgec: "" = hepsi, "1" = yalniz askidakiler,
	//	"0" = yalniz aktifler. Bool olsaydi "hepsi" ifade EDILEMEZDI.
	askidaF := r.URL.Query().Get("askida")

	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.phone,
		       u.hesap_turu, u.verified, u.onayli, u.coin_balance,
		       u.suspended_at IS NOT NULL, COALESCE(u.suspend_sebep,''),
		       COALESCE(to_char(u.suspended_at,'DD.MM.YY HH24:MI'),''),
		       to_char(u.created_at,'DD.MM.YY HH24:MI'),
		       COALESCE(to_char(u.last_seen,'DD.MM HH24:MI'),'-'),
		       (SELECT count(*) FROM posts p WHERE p.author_id=u.id AND p.durum='yayinda'),
		       (SELECT count(*) FROM reports rp
		         WHERE rp.hedef_tur='kullanici' AND rp.hedef_id = u.id::text)
		  FROM users u
		 WHERE ($1 = '' OR u.name ILIKE '%'||$1||'%'
		                OR COALESCE(u.username,'') ILIKE '%'||$1||'%'
		                OR u.phone ILIKE '%'||$1||'%')
		   AND ($2 = '' OR (u.suspended_at IS NOT NULL) = ($2 = '1'))
		 ORDER BY u.created_at DESC
		 LIMIT $3 OFFSET $4`, q, askidaF, limit, offset)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	defer rows.Close()

	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kadi, tel, hesapTuru, sebep, askiZaman, olusma, gorulme string
		var dogrulandi, onayli, askida bool
		var jeton int64
		var gonderi, sikayet int
		if rows.Scan(&id, &ad, &kadi, &tel, &hesapTuru, &dogrulandi, &onayli,
			&jeton, &askida, &sebep, &askiZaman, &olusma, &gorulme,
			&gonderi, &sikayet) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "name": ad, "username": kadi, "phone": tel,
			"hesap_turu": hesapTuru, "verified": dogrulandi, "onayli": onayli,
			"coin": jeton, "askida": askida, "askı_sebep": sebep,
			"askı_zaman": askiZaman, "olusma": olusma, "gorulme": gorulme,
			"gonderi_sayisi": gonderi, "sikayet_sayisi": sikayet,
		})
	}
	yaz(w, http.StatusOK, out)
}

// KullaniciAski — POST /admin/kullanicilar/{id}/aski {askida:bool, sebep:string}
//
// ⚠️⚠️ SEBEP KULLANICIYA GOSTERILIR (`auth.Middleware` 403 govdesinde ve
//
//	`Login` yanitinda). Bos birakilirsa jenerik metin kullanilir —
//	sessizce engellemek, kullanicinin "uygulama bozuk" sanmasina yol acar
//	ve destek yukunu artirir.
//
// ⚠️⚠️ `auth.Gecersizlestir` ZORUNLU: `auth.Middleware` var olan
//
//	kullanicilari **5 DAKIKA** pozitif onbellekliyor. Cagrilmazsa askiya
//	alinan kisi 5 dakika daha uygulamayi kullanmaya devam eder —
//	taciz vakasinda kabul edilemez.
func (h *Handler) KullaniciAski(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id, ok := kimlik(w, r, "id")
	if !ok {
		return
	}
	var req struct {
		Askida bool   `json:"askida"`
		Sebep  string `json:"sebep"`
	}
	if !govde(w, r, &req) {
		return
	}
	sebep := kisalt(req.Sebep, 300)
	if req.Askida && sebep == "" {
		sebep = "Hesabınız topluluk kurallarını ihlal ettiği için askıya alındı."
	}
	var tag string
	if req.Askida {
		tag = "kullanici.askiya_al"
		if _, err := h.db.Exec(r.Context(), `
			UPDATE users SET suspended_at = now(), suspend_sebep = $2
			 WHERE id = $1`, id, sebep); err != nil {
			hata(w, http.StatusInternalServerError, "kaydedilemedi")
			return
		}
	} else {
		tag = "kullanici.askiyi_kaldir"
		if _, err := h.db.Exec(r.Context(), `
			UPDATE users SET suspended_at = NULL, suspend_sebep = ''
			 WHERE id = $1`, id); err != nil {
			hata(w, http.StatusInternalServerError, "kaydedilemedi")
			return
		}
	}
	// ⚠️ Onbellegi HER IKI YONDE de dusur: askiyi kaldirinca da kullanici
	//	ANINDA geri donebilmeli.
	auth.Gecersizlestir(id)
	Yaz(r, h.db, tag, "kullanici", id, nil,
		map[string]any{"askida": req.Askida, "sebep": sebep})
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}

// KullaniciOnay — POST /admin/kullanicilar/{id}/onay {onayli:bool}
//
// ⚠️ `IsletmeOnay` ile AYNI sutunu (`users.onayli`) yazar; ayri uc olmasinin
//
//	sebebi panelin iki farkli listeden (kullanicilar / isletmeler) ayni
//	islemi sunmasi. Govde `isletme.AdminOnay` TEK KAYNAGINA gider.
func (h *Handler) KullaniciOnay(w http.ResponseWriter, r *http.Request) {
	h.IsletmeOnay(w, r)
}

// KullaniciJeton — POST /admin/kullanicilar/{id}/jeton {miktar:int}
//
// ⚠️⚠️ **MUTLAK DEGER DEGIL, DELTA**: `coin_balance = $2` yazsaydik iki
//
//	escamanli islem birbirini EZERDI. `+ $2` ile toplama atomiktir.
//
// ⚠️ Negatif deger DUSURME anlamina gelir; bakiye SIFIRIN ALTINA dusmez
//
//	(`GREATEST(...,0)`) — negatif bakiye urunde hicbir yerde ele
//	alinmiyor ve sessiz bir hata sinifi acardi.
func (h *Handler) KullaniciJeton(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id, ok := kimlik(w, r, "id")
	if !ok {
		return
	}
	var req struct {
		Miktar int64 `json:"miktar"`
	}
	if !govde(w, r, &req) {
		return
	}
	if req.Miktar == 0 {
		hata(w, http.StatusBadRequest, "miktar sıfır olamaz")
		return
	}
	if req.Miktar > 1_000_000 || req.Miktar < -1_000_000 {
		hata(w, http.StatusBadRequest, "miktar sınır dışı")
		return
	}
	var yeni int64
	if err := h.db.QueryRow(r.Context(), `
		UPDATE users SET coin_balance = GREATEST(coin_balance + $2, 0)
		 WHERE id = $1 RETURNING coin_balance`, id, req.Miktar).Scan(&yeni); err != nil {
		hata(w, http.StatusNotFound, "kullanıcı bulunamadı")
		return
	}
	Yaz(r, h.db, "kullanici.jeton", "kullanici", id, nil,
		map[string]any{"delta": req.Miktar, "yeni": yeni})
	yaz(w, http.StatusOK, map[string]any{"ok": true, "bakiye": yeni})
}
