package auth

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

// ⚠️⚠️⚠️ TURU 84 — ADIMLI KAYIT: **TELEFON -> OTP -> KISISEL BILGILER**.
//
// Kullanici emri: *"kayit sayfasi da step step: ilk telefon, sonra otp, sonra
// kisisel bilgiler seklinde olacak"*.
//
// ═══════════ NEDEN YENI UCLAR GEREKTI ═══════════
//
// Mevcut `/auth/register` **TUM ALANLARI BIRDEN** istiyor (telefon + sifre +
// ad + kullanici adi) ve ancak ondan sonra SMS gonderiyor. Yani istenen sira
// (once telefon, sonra dogrulama, en son bilgiler) o ucla **YAPISAL OLARAK
// MUMKUN DEGIL**: hesap zaten olusmus oluyor.
//
// ⚠️ **ESKI UCLARA DOKUNULMADI** (`/auth/register`, `/auth/verify` AYNEN
//    duruyor). Sebep: sahadaki eski surumler onlari kullaniyor ve bir kayit
//    akisini yayindayken kirmak, kullanicinin uygulamaya HIC giremmesi
//    demektir. Yeni akis AYRI uclar uzerinden ilerler; ikisi ayni
//    `otp_codes` tablosunu ve ayni dogrulama kurallarini paylasir.
//
// ═══════════ NEDEN "KAYIT JETONU" ═══════════
//
// OTP `consumeOTP` ile **TUKETILIR** (tek kullanimlik). Adim 2'de tuketilip
// adim 3'te hesap olusturulacagi icin, adim 3'un "bu telefon DOGRULANDI"
// iddiasini kanitlayacak bir seye ihtiyaci var.
//
// ⚠️ ALTERNATIF REDDEDILDI: "adim 2 kodu tuketmesin, adim 3 tuketsin" —
//    o zaman kullanici adim 2'yi gecer ama adim 3'te BASKA bir telefon
//    gonderebilir ya da kod hala gecerliyken baska bir istemci ayni kodu
//    kullanabilirdi.
//
// COZUM: adim 2 kodu tuketir ve **KISA OMURLU (15 dk) IMZALI bir jeton**
// dondurur. Jeton yalnizca TELEFONU ve amaci tasir; hesap ID'si TASIMAZ
// (henuz hesap yok) ve oturum jetonu OLARAK KULLANILAMAZ (`amac` alani
// ayirt eder — `auth.ParseToken` bunu okumaz, yani yanlislikla oturum
// jetonu sanilamaz).
// ⚠️ YAPMA: bu jetonun omrunu uzatma; 15 dk kayit formunu doldurmaya fazlasiyla
//    yeter ve calinmis bir jetonun penceresini dar tutar.

const kayitJetonOmru = 15 * time.Minute

// ⚠️⚠️⚠️ OTP AMACI **'register'** — 'kayit' DEGIL.
//
// Ilk yazimda `"kayit"` yazilmisti ve adim 1 CANLIDA **500 donuyordu**.
// Sebep `otp_codes` uzerindeki CHECK:
//
//	CHECK (purpose = ANY (ARRAY['register','reset_password','change_phone']))
//
// ⚠️ Bu, CLAUDE.md'de turu 78'den beri yazili olan tuzagin BIREBIR TEKRARI:
//   **"yeni bir kind/durum/tur/amac DEGERI eklerken ONCE CHECK'i ac."**
//   `go build` + `go vet` + `flutter analyze` UCU DE TEMIZ geciyordu; hata
//   yalnizca GERCEK POSTGRES'te ortaya cikti (uctan uca testi yakaladi).
//
// ⚠️ MIGRATION ACILMADI, mevcut deger KULLANILDI: yeni bir amac eklemek
//    CHECK'i DROP/ADD etmeyi gerektirirdi ve 015'in "iki migration kisiti
//    bagimsiz yeniden kurarsa sonraki oncekinin degerlerini SILER" tuzagini
//    acardi. Adimli kayit da SONUCTA bir "register" akisidir; ayri bir amac
//    degeri urun olarak da bir sey ifade etmiyor.
// ⚠️ YAPMA: burayi 'kayit' gibi yeni bir degere cevirme.
const otpAmaciKayit = "register"

// kayitClaims — YALNIZ kayit akisi icin. `Claims`ten AYRI bir tiptir:
// ⚠️ Ayni tip kullanilsaydi bu jeton `Authorization: Bearer` ile gonderilip
//    `ParseToken` tarafindan GECERLI bir oturum jetonu gibi cozulebilirdi
//    (`UserID` bos olurdu ama bazi yollar bos id'yi kontrol etmiyor).
type kayitClaims struct {
	Phone string `json:"tel"`
	Amac  string `json:"amac"` // daima "kayit"
	jwt.RegisteredClaims
}

func kayitJetonuUret(secret, phone string) (string, error) {
	c := kayitClaims{
		Phone: phone,
		Amac:  "kayit",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(kayitJetonOmru)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "gebzem",
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString([]byte(secret))
}

func kayitJetonuCoz(secret, tok string) (string, bool) {
	t, err := jwt.ParseWithClaims(tok, &kayitClaims{},
		func(t *jwt.Token) (any, error) { return []byte(secret), nil },
		// ⚠️ ALGORITMA KILITLI: `alg: none` ya da RS256 kabul edilseydi
		//    saldirgan kendi imzasiyla jeton uretebilirdi (klasik JWT acigi).
		jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		return "", false
	}
	c, ok := t.Claims.(*kayitClaims)
	if !ok || c.Amac != "kayit" || c.Phone == "" {
		return "", false
	}
	return c.Phone, true
}

// ---------------------------------------------------------------- ADIM 1

type kayitTelefonReq struct {
	Phone string `json:"phone"`
}

// POST /auth/kayit/telefon — telefonu al, SMS kodu gonder.
//
// ⚠️ Hesap OLUSTURULMAZ. Bu, eski `/auth/register`den en onemli farki.
func (h *Handler) KayitTelefon(w http.ResponseWriter, r *http.Request) {
	var req kayitTelefonReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		writeErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	req.Phone = strings.TrimSpace(req.Phone)
	if !phoneRe.MatchString(req.Phone) {
		writeErr(w, http.StatusBadRequest, "telefon numarası geçersiz")
		return
	}

	// ⚠️⚠️ KAYITLI TELEFON KONTROLU **BURADA** yapilir ki kullanici uc adim
	//    boyunca form doldurup EN SONDA "bu numara zaten kayitli" duvarina
	//    toslamasin. Bu, adimli akisin varlik sebebiyle dogrudan ilgili.
	// ⚠️ Yanit "zaten kayitli" DER — bu bir numara sayimi (enumeration)
	//    acigidir ama giris ekraninda zaten ayni bilgi veriliyor ve
	//    kullanicinin "neden giremiyorum" sorusunu cozmek daha degerli.
	// ⚠️⚠️ OLCUT **`verified`** — `password_hash <> ''` DEGIL.
	//
	//	Ilk yazimda `password_hash <> ''` kullaniliyordu ve bu, GIRISIN
	//	olcutunden (`verified`) AYRISIYORDU. Eski `/auth/register` satiri
	//	OTP'den ONCE yaziyor; yani OTP adiminda vazgecen kullanicinin satiri
	//	`password_hash` DOLU + `verified=false` halinde kaliyor. O kullanici:
	//	  · giris yapamiyor  (Login: `if !verified {403}`)
	//	  · YENIDEN KAYIT DA OLAMIYOR (buradaki kapi 409 doner)
	//	yani hesabina KALICI OLARAK kilitleniyordu.
	// ⚠️ `verified` olcutuyle yarim kalmis kayitlar akisi yeniden baslatabilir
	//    ve `ON CONFLICT DO UPDATE` onlari TAMAMLAR.
	// ⚠️ YAPMA: olcutu `password_hash`e dondurme; uc uc (kayit/giris/sifirlama)
	//    AYNI "kayitli mi" tanimini paylasmali.
	var kayitli bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE phone=$1 AND verified=true)`,
		req.Phone).Scan(&kayitli); err != nil {
		writeErr(w, http.StatusInternalServerError, "kayıt başlatılamadı")
		return
	}
	if kayitli {
		writeErr(w, http.StatusConflict, "Bu numara zaten kayıtlı — giriş yapabilirsin")
		return
	}

	code, err := h.createOTP(r.Context(), req.Phone, otpAmaciKayit)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "kod gönderilemedi")
		return
	}
	// ⚠️ GERCEK SMS acik ise kodu GONDER; gonderilemezse akisi DURDUR —
	//    yoksa kullanici gelmeyecek bir kodu ekranda bekler.
	if h.sms.Enabled() {
		if err := h.sms.SendOTP(req.Phone, code); err != nil {
			log.Printf("kayit sms gonderilemedi (%s): %v", req.Phone, err)
			writeErr(w, http.StatusBadGateway, "SMS gönderilemedi, tekrar deneyin")
			return
		}
	}
	resp := map[string]any{"ok": true}
	// ⚠️ Test modunda kod yanitta doner — kosul `/auth/register` ile BIREBIR
	//    AYNI (`!sms.Enabled() && cfg.DevMode`). Farkli olsaydi iki kayit
	//    akisindan biri test ortaminda calisir digeri calismazdi.
	if !h.sms.Enabled() && h.cfg.DevMode {
		resp["dev_otp"] = code
	}
	writeJSON(w, http.StatusOK, resp)
}

// ---------------------------------------------------------------- ADIM 2

type kayitDogrulaReq struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

// POST /auth/kayit/dogrula — kodu tuket, KAYIT JETONU ver.
func (h *Handler) KayitDogrula(w http.ResponseWriter, r *http.Request) {
	var req kayitDogrulaReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		writeErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	req.Phone = strings.TrimSpace(req.Phone)
	req.Code = strings.TrimSpace(req.Code)
	if !h.consumeOTP(r.Context(), req.Phone, req.Code, otpAmaciKayit) {
		writeErr(w, http.StatusBadRequest, "Kod hatalı ya da süresi dolmuş")
		return
	}
	jeton, err := kayitJetonuUret(h.cfg.JWTSecret, req.Phone)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "doğrulama tamamlanamadı")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"kayit_jetonu": jeton})
}

// ---------------------------------------------------------------- ADIM 3

type kayitTamamlaReq struct {
	Jeton    string `json:"kayit_jetonu"`
	Name     string `json:"name"`
	Username string `json:"username"`
	Password string `json:"password"`
}

// POST /auth/kayit/tamamla — hesabi OLUSTUR, oturum jetonu ver.
func (h *Handler) KayitTamamla(w http.ResponseWriter, r *http.Request) {
	var req kayitTamamlaReq
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		writeErr(w, http.StatusBadRequest, "geçersiz istek")
		return
	}
	// ⚠️ TELEFON **JETONDAN** gelir, istekten DEGIL. Istekten alinsaydi biri
	//    kendi telefonunu dogrulayip BASKASININ numarasina hesap acabilirdi.
	phone, ok := kayitJetonuCoz(h.cfg.JWTSecret, req.Jeton)
	if !ok {
		writeErr(w, http.StatusUnauthorized,
			"Doğrulama süresi doldu — numaranı yeniden doğrula")
		return
	}

	name := strings.TrimSpace(req.Name)
	// ⚠️⚠️ TURU 85b — `TrimPrefix(..., "@")` EKLENDI (denetim bulgusu).
	//    Serhim *"kurallar eski `/auth/register` ile BIREBIR AYNI"* diyordu
	//    ama DEGILDI. Eski uc `@` on ekini KIRPIYOR; kayit formu kullanici
	//    adini `@` ile GOSTERDIGI icin insanlar onu yaziyor ve yeni akista
	//    "kullanıcı adı 3-20 karakter olmalı" hatasi aliyorlardi — hicbir
	//    sey ACIKLAMADAN, cunku yazdiklari zaten 3-20 karakterdi.
	uname := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(
		strings.TrimSpace(req.Username), "@")))
	if name == "" {
		writeErr(w, http.StatusBadRequest, "adını yaz")
		return
	}
	if !usernameRe.MatchString(uname) {
		writeErr(w, http.StatusBadRequest,
			"kullanıcı adı 3-20 karakter olmalı (a-z, 0-9, _)")
		return
	}
	if len(req.Password) < 6 {
		writeErr(w, http.StatusBadRequest, "şifre en az 6 karakter olmalı")
		return
	}
	// ⚠️⚠️ 72 BAYT TAVANI ZORUNLU (eski ucta VARDI, burada ATLANMISTI).
	//    `bcrypt.GenerateFromPassword` 72 bayttan uzun parolada **HATA
	//    DONDURUR**; o hata asagida jenerik `500 kayıt tamamlanamadı`ya
	//    dusuyordu. Yani uzun parola secen kullanici, SEBEBINI OGRENEMEDEN
	//    kayit olamiyordu ve tekrar denemesi de ise yaramiyordu.
	// ⚠️ Olcut BAYT (`len`), karakter DEGIL: Turkce harfler 2 bayt.
	if len(req.Password) > 72 {
		writeErr(w, http.StatusBadRequest, "şifre çok uzun (en fazla 72 karakter)")
		return
	}

	var taken bool
	if err := h.db.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE lower(username)=$1 AND phone<>$2)`,
		uname, phone).Scan(&taken); err != nil {
		writeErr(w, http.StatusInternalServerError, "kayıt tamamlanamadı")
		return
	}
	if taken {
		writeErr(w, http.StatusConflict, "bu kullanıcı adı alınmış")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "kayıt tamamlanamadı")
		return
	}

	// ⚠️ `ON CONFLICT (phone) DO UPDATE`: eski `/auth/register` ile AYNI desen.
	//    Yarim kalmis bir kayit (telefon satiri var, sifre bos) TAMAMLANIR.
	//
	// ⚠️⚠️⚠️ **`verified=true` ZORUNLU — YOKLUGU SEVK ENGELIYDI.**
	//
	//	Ilk yazimda bu sutun HIC yazilmiyordu. `users.verified` varsayilani
	//	FALSE (001_init.sql) ve `SET verified=true` yazan TEK yer eski
	//	`/auth/verify` ucuydu — yeni akis onu HIC cagirmiyor. Sonuc: yeni
	//	akisla acilan **HER HESAP HAYALETTI**:
	//	  · `Login` -> `if !verified { 403 }`  (giris IMKANSIZ)
	//	  · `Forgot`/`Reset` -> `AND verified=true` (sifre sifirlama da yok)
	//	  · kullanici arama · telefondan bulma · profil goruntuleme
	//	  · akis + kesfet (`u.verified` yuklemi)
	//	Yani kullanici kayit olur, uygulamayi kapatir ve BIR DAHA GIREMEZ;
	//	kurtarma yolu da YOKTUR.
	//
	// ⚠️ Neden burada dogru: kayit jetonu ZATEN "OTP tuketildi" kanitidir ve
	//    `verified` tam olarak bunu ifade eder.
	// ⚠️ YAPMA: bu sutunu cikarma.
	// ⚠️⚠️⚠️ TURU 85b — UPDATE DALI **`verified=false` ILE KORUNUYOR**.
	//
	//	Kayit jetonu 15 dakika yasar ve TEK KULLANIMLIK DEGILDIR. Korumasiz
	//	`DO UPDATE` ile ayni jeton, kayit TAMAMLANDIKTAN sonra tekrar
	//	oynatilarak hesabin **sifresini ve kullanici adini EZEBILIYORDU**.
	//	Kapi, guncellemeyi YALNIZ yarim kalmis (dogrulanmamis) satirlara
	//	uygular; tamamlanmis hesap ARTIK DEGISTIRILEMEZ.
	//
	// ⚠️ 0 SATIR = "hesap ZATEN tamamlanmis" demektir ve bu **HATA DEGIL**:
	//    ag koptugunda istemci ayni istegi tekrarlar. O yuzden asagida
	//    mevcut hesap bulunup OTURUM VERILIR (jeton telefon sahipligini
	//    kanitliyor; bu, SMS ile giris ile ayni guvenceye sahiptir).
	//    Boylece yeniden deneme CALISIR ama VERI EZILMEZ.
	// ⚠️ YAPMA: `WHERE users.verified = false` kapisini kaldirma.
	// ⚠️ YAPMA: 0 satir durumunu 500'e cevirme (flaky agda kayit tamamlanamaz).
	var userID string
	err = h.db.QueryRow(r.Context(), `
		INSERT INTO users (phone, password_hash, name, username, verified)
		VALUES ($1,$2,$3,$4,true)
		ON CONFLICT (phone) DO UPDATE
		   SET password_hash=$2, name=$3, username=$4, verified=true
		 WHERE users.verified = false
		RETURNING id`,
		phone, string(hash), name, uname).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		// Tamamlanmis hesap: yalniz oturum ver, HICBIR ALANI DEGISTIRME.
		if e2 := h.db.QueryRow(r.Context(),
			`SELECT id FROM users WHERE phone=$1`, phone).Scan(&userID); e2 != nil {
			writeErr(w, http.StatusInternalServerError, "kayıt tamamlanamadı")
			return
		}
	} else if err != nil {
		writeErr(w, http.StatusInternalServerError, "kayıt tamamlanamadı")
		return
	}

	// ⚠️⚠️ KAYIT BONUSU — eski `/auth/verify` ile AYNI (handler.go). Bu satir
	//    olmadan yeni akisla acilan hesabin `coin_ledger` DENETIM SATIRI
	//    olusmuyordu; bakiye `coin_balance` varsayilanindan geliyor ama
	//    "nereden geldi" izi KAYBOLUYORDU.
	// ⚠️ `NOT EXISTS` kapisi: iki akistan hangisi once kosarsa kossun bonus
	//    BIR KEZ islenir.
	h.db.Exec(r.Context(), `
		INSERT INTO coin_ledger (user_id, amount, reason)
		SELECT $1, 10000, 'signup_bonus'
		WHERE NOT EXISTS (
			SELECT 1 FROM coin_ledger WHERE user_id=$1 AND reason='signup_bonus')`,
		userID)

	tok, err := GenerateToken(h.cfg.JWTSecret, userID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "oturum açılamadı")
		return
	}
	// ⚠️⚠️⚠️ **`user_id` ZORUNLU — YOKLUGU SEVK ENGELIYDI.**
	//
	//	Istemcideki `_saveSession` (auth_provider.dart) `data['user_id'] as
	//	String` okuyor; ilk yazimda yanit yalnizca ic ice `user.id`
	//	donduruyordu -> `null as String` -> **TypeError** -> jeton diske HIC
	//	yazilmiyor ve oturum ACILMIYORDU. Yani hesap sunucuda olusuyor ama
	//	kullanici jenerik bir hata goruyor ve akis TAMAMLANAMIYORDU.
	//
	// ⚠️ Eski `/auth/verify` ve `/auth/login` de `{"token","user_id"}`
	//    donduruyor — uc uc artik AYNI sozlesmeyi konusuyor.
	// ⚠️ `user` nesnesi de KALIR (additive): ileride istemci ada/kullanici
	//    adina ihtiyac duyarsa ikinci istek atmasin.
	// ⚠️ YAPMA: `user_id`yi kaldirma.
	writeJSON(w, http.StatusOK, map[string]any{
		"token":   tok,
		"user_id": userID,
		"user": map[string]any{
			"id": userID, "phone": phone, "name": name, "username": uname,
		},
	})
}
