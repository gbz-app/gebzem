package admin

import (
	"net/http"
	"strings"

	"golang.org/x/crypto/bcrypt"

	"github.com/gbz-app/gebzem/backend/internal/isletme"
)

// ⚠️⚠️⚠️ TURU 181 — ADMIN ISLETME (FIRMA) YONETIMI.
//
// Kullanici emri: *"adminden firma ekleme silme vs her seyi adminle bagla"*.
//
// ═══════════ ONCEKI DURUM ═══════════
// Bir isletme SADECE o hesaba GIRIP `PUT /users/me/isletme` cagirarak
// acilabiliyordu. Yonetici bir firma ekleyemiyor, duzenleyemiyor,
// kapatamiyor ve mavi tik veremiyordu (`users.onayli`ya yazan TEK BIR UC
// bile yoktu — rozet elle SQL ile veriliyordu).
//
// ═══════════ YAZMA YOLU **ISLETME PAKETINDE** ═══════════
// Butun INSERT/UPDATE `isletme.AdminKaydet`/`AdminKapat`/`AdminOnay`
// uzerinden gider. Admin burada kendi SQL'ini YAZMAZ — ayni tablonun iki
// yazicisi kacinilmaz olarak ayrisir (bu projede ALTI kez sahaya cikti).
//
// ⚠️ YAPMA: buraya `INSERT INTO isletmeler` / `UPDATE isletmeler` yazma.

type isletmeIstek struct {
	// Mevcut bir kullaniciyi isletmeye cevirmek icin.
	UserID string `json:"user_id"`

	// ⚠️ YENI HESAP acmak icin (user_id BOS ise). `isletmeler.user_id` bir
	//	`users(id)` FK'sidir — yani "firma eklemek" once bir HESAP acmak
	//	demektir. Panel bunu tek adimda yapar.
	Phone    string `json:"phone"`
	Name     string `json:"name"`
	Username string `json:"username"`
	Password string `json:"password"`

	Kategori string   `json:"kategori"`
	Aciklama string   `json:"aciklama"`
	Adres    string   `json:"adres"`
	Il       string   `json:"il"`
	Ilce     string   `json:"ilce"`
	Telefon  string   `json:"telefon"`
	Web      string   `json:"web"`
	Enlem    *float64 `json:"enlem"`
	Boylam   *float64 `json:"boylam"`
}

func (i isletmeIstek) bilgi() isletme.AdminBilgi {
	return isletme.AdminBilgi{
		Kategori: i.Kategori, Aciklama: i.Aciklama, Adres: i.Adres,
		Il: i.Il, Ilce: i.Ilce, Telefon: i.Telefon, Web: i.Web,
		Enlem: i.Enlem, Boylam: i.Boylam,
	}
}

// IsletmeListesi — GET /admin/isletmeler?q=&kategori=&limit=&offset=
//
// ⚠️ Mevcut `/isletmeler` ucu KULLANILMADI: o uc yalniz `hesap_turu='isletme'`
//
//	VE yayindaki kayitlari dondurur, kimlik ister ve engel yuklemi tasir.
//	Admin listesi BUNLARIN HICBIRINI istemez — kapatilmis, onaysiz,
//	askidaki her kaydi gormek zorundadir.
func (h *Handler) IsletmeListesi(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	q := kisalt(r.URL.Query().Get("q"), 60)
	kat := kisalt(r.URL.Query().Get("kategori"), 30)
	limit := sayi(r, "limit", 50, 1, 200)
	offset := sayi(r, "offset", 0, 0, 100000)

	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.phone,
		       u.hesap_turu, u.onayli, u.suspended_at IS NOT NULL,
		       COALESCE(i.kategori,''), COALESCE(i.aciklama,''),
		       COALESCE(i.il,''), COALESCE(i.ilce,''), COALESCE(i.telefon,''),
		       COALESCE(i.enlem,0), COALESCE(i.boylam,0),
		       (SELECT count(*) FROM isletme_urunleri p
		         WHERE p.isletme_id = u.id AND p.durum <> 'kaldirildi'),
		       to_char(u.created_at,'DD.MM.YY HH24:MI')
		  FROM users u
		  LEFT JOIN isletmeler i ON i.user_id = u.id
		 WHERE (u.hesap_turu = 'isletme' OR i.user_id IS NOT NULL)
		   AND ($1 = '' OR u.name ILIKE '%'||$1||'%'
		                OR COALESCE(u.username,'') ILIKE '%'||$1||'%'
		                OR u.phone ILIKE '%'||$1||'%')
		   AND ($2 = '' OR i.kategori = $2)
		 ORDER BY u.created_at DESC
		 LIMIT $3 OFFSET $4`, q, kat, limit, offset)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	defer rows.Close()

	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kadi, tel, hesapTuru, kategori, aciklama, il, ilce, iTel, olusma string
		var onayli, askida bool
		var enlem, boylam float64
		var urunSayisi int
		if rows.Scan(&id, &ad, &kadi, &tel, &hesapTuru, &onayli, &askida,
			&kategori, &aciklama, &il, &ilce, &iTel,
			&enlem, &boylam, &urunSayisi, &olusma) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "name": ad, "username": kadi, "phone": tel,
			"hesap_turu": hesapTuru, "onayli": onayli, "askida": askida,
			"kategori": kategori, "kategori_ad": isletme.Kategoriler[kategori],
			"aciklama": aciklama, "il": il, "ilce": ilce, "telefon": iTel,
			"enlem": enlem, "boylam": boylam,
			"urun_sayisi": urunSayisi, "olusma": olusma,
			// ⚠️ `kapali`: `isletmeler` satiri VAR ama `hesap_turu` kisisel.
			//	Panel bunu "kapatilmis firma" olarak gosterir; satir
			//	SILINMEDIGI icin tek dokunusla geri acilabilir.
			"kapali": hesapTuru != "isletme",
		})
	}
	yaz(w, http.StatusOK, out)
}

// IsletmeOlustur — POST /admin/isletmeler
//
// IKI MOD:
//   - `user_id` verilirse MEVCUT kullanici isletmeye cevrilir.
//   - verilmezse YENI HESAP acilir (phone/name/username/password) ve
//     ardindan isletme yapilir.
//
// ⚠️⚠️ HESAP ACARKEN `verified=true` YAZILIR: admin panelinden acilan bir
//
//	firma hesabi OTP akisindan gecmez; `verified=false` kalsaydi hesap
//	GIRIS YAPAMAZDI (`Login` o bayragi sart kosuyor) ve panel sessizce
//	kullanilamaz bir kayit uretirdi.
//
// ⚠️ Sifre bcrypt ile hashlenir — **72 BAYT TAVANI** ZORUNLU: bcrypt daha
//
//	uzununu reddeder ve jenerik 500 doner (turu 85b dersi).
func (h *Handler) IsletmeOlustur(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	var req isletmeIstek
	if !govde(w, r, &req) {
		return
	}

	userID := strings.TrimSpace(req.UserID)
	yeniHesap := userID == ""

	if yeniHesap {
		tel := kisalt(req.Phone, 20)
		ad := kisalt(req.Name, 80)
		kadi := strings.ToLower(kisalt(req.Username, 20))
		if tel == "" || ad == "" {
			hata(w, http.StatusBadRequest, "telefon ve ad zorunlu")
			return
		}
		if len(req.Password) < 6 {
			hata(w, http.StatusBadRequest, "şifre en az 6 karakter olmalı")
			return
		}
		if len(req.Password) > 72 {
			// ⚠️ bcrypt 72 BAYT ustunu REDDEDER; kapi olmadan jenerik 500.
			hata(w, http.StatusBadRequest, "şifre çok uzun (en fazla 72 karakter)")
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			hata(w, http.StatusInternalServerError, "hesap açılamadı")
			return
		}
		// ⚠️ Kullanici adi BOS gonderilirse NULL yazilir: `users.username`
		//	UNIQUE ve bos dize IKINCI kayitta cakisirdi.
		var kadiParam *string
		if kadi != "" {
			kadiParam = &kadi
		}
		if err := h.db.QueryRow(r.Context(), `
			INSERT INTO users (phone, password_hash, name, username, verified, hesap_turu)
			VALUES ($1,$2,$3,$4,true,'isletme')
			RETURNING id`, tel, string(hash), ad, kadiParam).Scan(&userID); err != nil {
			// ⚠️ En sik hata TELEFON/KULLANICI ADI CAKISMASI (UNIQUE).
			//	Jenerik 500 yerine anlasilir mesaj.
			hata(w, http.StatusConflict,
				"bu telefon ya da kullanıcı adı zaten kayıtlı")
			return
		}
	} else if !uuidBicimi(userID) {
		hata(w, http.StatusBadRequest, "geçersiz kullanıcı kimliği")
		return
	}

	if err := h.isletmeler.AdminKaydet(r.Context(), userID, req.bilgi()); err != nil {
		hata(w, http.StatusInternalServerError, "işletme kaydedilemedi")
		return
	}
	eylem := "isletme.olustur"
	if !yeniHesap {
		eylem = "isletme.hesaptan_cevir"
	}
	Yaz(r, h.db, eylem, "isletme", userID, nil, req)
	yaz(w, http.StatusOK, map[string]any{"ok": true, "user_id": userID})
}

// IsletmeGuncelle — PATCH /admin/isletmeler/{id}
func (h *Handler) IsletmeGuncelle(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id, ok := kimlik(w, r, "id")
	if !ok {
		return
	}
	var req isletmeIstek
	if !govde(w, r, &req) {
		return
	}
	// ⚠️⚠️ ONCEKI DEGERLER denetim kaydi icin OKUNUR: yalniz "guncelledi"
	//	yazmak yetmez, NEYIN degistigi de kayitta olmali (5651).
	onceki := h.isletmeOzet(r, id)
	if err := h.isletmeler.AdminKaydet(r.Context(), id, req.bilgi()); err != nil {
		hata(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	Yaz(r, h.db, "isletme.guncelle", "isletme", id, onceki, req)
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}

// IsletmeOnay — POST /admin/isletmeler/{id}/onay {onayli:true|false}
//
// ⚠️⚠️ `users.onayli` (mavi tik) icin bu, projedeki ILK yazma yolu.
//
//	`033_kapak_onay.sql`in kendi serhi "ILK SURUMDE ELLE SQL" diyordu.
func (h *Handler) IsletmeOnay(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id, ok := kimlik(w, r, "id")
	if !ok {
		return
	}
	var req struct {
		Onayli bool `json:"onayli"`
	}
	if !govde(w, r, &req) {
		return
	}
	if err := h.isletmeler.AdminOnay(r.Context(), id, req.Onayli); err != nil {
		hata(w, http.StatusInternalServerError, "kaydedilemedi")
		return
	}
	Yaz(r, h.db, "isletme.onay", "isletme", id, nil,
		map[string]bool{"onayli": req.Onayli})
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}

// IsletmeKapat — DELETE /admin/isletmeler/{id}
//
// ⚠️⚠️ **SATIR SILINMEZ** (veri politikasi: VERI SILINMEZ). Yalniz
//
//	`hesap_turu` kisisele doner; `isletmeler` kaydi ve urunler DURUR.
//	Panel bunu "Firmayı kapat" olarak adlandirir — "sil" demek, geri
//	donusu olmayan bir islem oldugu izlenimi verirdi.
func (h *Handler) IsletmeKapat(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	id, ok := kimlik(w, r, "id")
	if !ok {
		return
	}
	onceki := h.isletmeOzet(r, id)
	if err := h.isletmeler.AdminKapat(r.Context(), id); err != nil {
		hata(w, http.StatusInternalServerError, "kapatılamadı")
		return
	}
	Yaz(r, h.db, "isletme.kapat", "isletme", id, onceki, nil)
	yaz(w, http.StatusOK, map[string]bool{"ok": true})
}

// isletmeOzet — denetim kaydi icin kucuk bir anlik goruntu.
//
// ⚠️ Hata YUTULUR: denetim kaydinin "oncesi" alani eksik kalabilir ama asil
//
//	islem BUNUN YUZUNDEN basarisiz olmamali.
func (h *Handler) isletmeOzet(r *http.Request, id string) map[string]any {
	var ad, kadi, kategori, aciklama, adres, il, ilce, tel, web, hesapTuru string
	var onayli bool
	if h.db.QueryRow(r.Context(), `
		SELECT u.name, COALESCE(u.username,''), u.hesap_turu, u.onayli,
		       COALESCE(i.kategori,''), COALESCE(i.aciklama,''),
		       COALESCE(i.adres,''), COALESCE(i.il,''), COALESCE(i.ilce,''),
		       COALESCE(i.telefon,''), COALESCE(i.web,'')
		  FROM users u LEFT JOIN isletmeler i ON i.user_id = u.id
		 WHERE u.id = $1`, id).
		Scan(&ad, &kadi, &hesapTuru, &onayli, &kategori, &aciklama,
			&adres, &il, &ilce, &tel, &web) != nil {
		return nil
	}
	return map[string]any{
		"name": ad, "username": kadi, "hesap_turu": hesapTuru, "onayli": onayli,
		"kategori": kategori, "aciklama": aciklama, "adres": adres,
		"il": il, "ilce": ilce, "telefon": tel, "web": web,
	}
}

// Kategoriler — GET /admin/kategoriler
//
// ⚠️⚠️ Liste **SUNUCUDAN** doner (turu 77 kurali): panele sabit yazilsaydi
//
//	yeni bir kategori eklemek panel dosyasini da degistirmeyi gerektirir
//	ve ikisi ayrisirsa yonetici var olmayan bir anahtar secebilirdi.
func (h *Handler) Kategoriler(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	out := []map[string]string{}
	for k, ad := range isletme.Kategoriler {
		out = append(out, map[string]string{"anahtar": k, "ad": ad})
	}
	yaz(w, http.StatusOK, out)
}
