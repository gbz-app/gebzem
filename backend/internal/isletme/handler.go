// Package isletme — ISLETME PROFILLERI (turu 77).
//
// Kullanici emri: "isletme profilleri olacak, normal ve isletme profilleri".
//
// ⚠️ SEMA KARARI migration 028'de yazili: `users.hesap_turu` TEK SUTUN,
// detaylar AYRI `isletmeler` tablosunda. Sebebi orada.
package isletme

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
)

type Handler struct{ db *pgxpool.Pool }

func NewHandler(db *pgxpool.Pool) *Handler { return &Handler{db: db} }

func yaz(w http.ResponseWriter, kod int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(kod)
	json.NewEncoder(w).Encode(v)
}

func hata(w http.ResponseWriter, kod int, m string) {
	yaz(w, kod, map[string]string{"error": m})
}

// ⚠️⚠️ KATEGORILER — Go ve Dart'ta AYNI liste olmak ZORUNDA.
//
//	Dart karsiligi: mobile/lib/features/isletme/isletme_kategori.dart
//	⚠️ YAPMA: yalniz birini guncelleme; istemci bilmedigi anahtari "Diğer"
//	   gosterir ve kullanici kendi sectigi kategoriyi goremez.
//
// ⚠️ DB tablosuna alinmadi: sabit, kucuk, nadiren degisen liste (bkz. 028 serhi).
var Kategoriler = map[string]string{
	"yemek":     "Yemek",
	"kafe":      "Kafe",
	"market":    "Market",
	"giyim":     "Giyim",
	"kuafor":    "Kuaför & Güzellik",
	"oto":       "Oto & Servis",
	"saglik":    "Sağlık",
	"egitim":    "Eğitim",
	"emlak":     "Emlak",
	"spor":      "Spor",
	"teknoloji": "Teknoloji",
	"eglence":   "Eğlence",
	"hizmet":    "Hizmet",
	"diger":     "Diğer",
}

type isletmeReq struct {
	Kategori string          `json:"kategori"`
	Adres    string          `json:"adres"`
	Il       string          `json:"il"`
	Ilce     string          `json:"ilce"`
	Telefon  string          `json:"telefon"`
	Web      string          `json:"web"`
	Calisma  json.RawMessage `json:"calisma"`
	// ⚠️⚠️ TURU 78 — **ISARETCI** (pointer): "gonderilmedi" ile "0" AYRI seydir.
	//    Duz `float64` olsaydi istemcinin alani HIC gondermemesi de 0 olarak
	//    okunur ve UPSERT mevcut koordinati SIFIRA EZERDI — sahada tam olarak
	//    bu yasandi ve sistemde hicbir koordinat birikemedi.
	Enlem  *float64 `json:"enlem"`
	Boylam *float64 `json:"boylam"`
}

func kisalt(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}

// PUT /users/me/isletme — isletme profiline GEC ya da bilgileri guncelle.
//
// ⚠️ TEK UC ile hem "isletmeye gecis" hem "guncelleme" yapiliyor (upsert).
//
//	Ayri "gecis" ucu olsaydi kullanici bir kez gecip alanlari bos birakabilir
//	ve profil BOS bir isletme olarak gorunurdu.
//
// ⚠️⚠️ TURU 78 — KOORDINAT EZME HATASI DUZELTILDI (arastirma bulgusu).
//
//	Eskiden UPSERT `enlem=EXCLUDED.enlem` yaziyordu. Istemci
//	(`isletme_duzenle.dart` `_kaydet`) yeni bir `Isletme(...)` kurarken
//	enlem/boylam VERMIYOR; Dart varsayilani 0, `json()` bunu gonderiyor ve
//	UPSERT **HER KAYITTA KOORDINATI SIFIRA EZIYORDU**. Sonuc: sisteme hicbir
//	koordinat birikemedi ve harita ozelligi bugun konsa SIFIR PIN cizerdi.
//	FIX: istek alanlari `*float64` (gonderilmedi != 0) + SQL'de
//	`COALESCE(EXCLUDED.enlem, isletmeler.enlem)`.
//	⚠️ YAPMA: alanlari duz `float64`e, SQL'i kosulsuz `EXCLUDED`e dondurme.
//
// ⚠️⚠️ TURU 78b — INSERT DALINDA `COALESCE($9,0)` ZORUNLU (uctan uca testinde
//
//	yakalandi). Yukaridaki isaretci degisikliginde UPDATE dali dogru kuruldu
//	ama INSERT dali ATLANDI: istemci enlem/boylam HIC gondermedigi icin pgx
//	`nil`i SQL NULL'a cevirdi, sutun NOT NULL oldugu icin **ISLETME HESABINA
//	GECIS HER SEFERINDE 500 DONDU** (SQLSTATE 23502) ve ona bagli alti kontrol
//	daha coktu (isletme detayi, rehber, hesap_turu, urun ekleme, katalog,
//	urun medyasi).
//	⚠️ Bu, CLAUDE.md'de defalarca yazili "nil -> SQL NULL" sinifinin ta
//	   kendisidir ve KENDI DUZELTMEMDE tekrarlandi. Statik denetim yakalamadi;
//	   GERCEK POSTGRES'e giden uctan uca testi yakaladi.
//	⚠️ Yeni satirda bilinmeyen konum 0'dir; MEVCUT satirda ON CONFLICT
//	   dalindaki COALESCE eski degeri KORUR.
func (h *Handler) Kaydet(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var req isletmeReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	if _, ok := Kategoriler[req.Kategori]; !ok {
		req.Kategori = "diger"
	}
	req.Adres = kisalt(strings.TrimSpace(req.Adres), 300)
	req.Il = kisalt(strings.TrimSpace(req.Il), 60)
	req.Ilce = kisalt(strings.TrimSpace(req.Ilce), 60)
	req.Telefon = kisalt(strings.TrimSpace(req.Telefon), 30)
	req.Web = kisalt(strings.TrimSpace(req.Web), 200)
	// ⚠️ `calisma` istemciden JSON olarak gelir; bicimi DOGRULANIR ama icerigi
	//    yeniden kurulmaz. Bos/bozuksa '[]' yazilir — NULL yazilirsa istemcide
	//    her okumada null kontrolu gerekir ve bir yerde unutulup CRASH eder.
	// ⚠️⚠️ **BAYT** SINIRI DA ZORUNLU (turu 77b): `len(deneme)` ELEMAN SAYISIDIR;
	//    tek elemanli ama devasa bir dizi eski kapidan gecip DB'ye yazilirdi.
	calisma := []byte("[]")
	if len(req.Calisma) > 0 && len(req.Calisma) <= 4<<10 {
		var deneme []map[string]any
		if json.Unmarshal(req.Calisma, &deneme) == nil && len(deneme) <= 14 {
			calisma = req.Calisma
		}
	}
	// ⚠️ Enlem/boylam SINIRLARA CEKILIR: bozuk deger haritayi patlatir.
	// ⚠️ Bozuk deger MEVCUDU KORUR (nil), SIFIRLAMAZ. Sifirlamak, gecerli bir
	//    koordinati tek bozuk istekle yok etmek demekti.
	if req.Enlem != nil && (*req.Enlem < -90 || *req.Enlem > 90 || *req.Enlem != *req.Enlem) {
		req.Enlem = nil
	}
	if req.Boylam != nil && (*req.Boylam < -180 || *req.Boylam > 180 || *req.Boylam != *req.Boylam) {
		req.Boylam = nil
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "kaydedilemedi")
		return
	}
	defer tx.Rollback(r.Context())

	// ⚠️ HESAP TURU ve DETAY AYNI ISLEMDE yazilir. Ayri olsaydi biri basarisiz
	//    olunca kullanici "isletme" gorunup detaysiz kalabilirdi (ya da tersi:
	//    detay var ama profil kisisel cizilir = olu veri).
	if _, err := tx.Exec(r.Context(),
		`UPDATE users SET hesap_turu='isletme' WHERE id=$1`, me); err != nil {
		hata(w, 500, "kaydedilemedi")
		return
	}
	if _, err := tx.Exec(r.Context(), `
		INSERT INTO isletmeler
		  (user_id, kategori, adres, il, ilce, telefon, web, calisma, enlem, boylam)
		-- TURU 78b: COALESCE(...,0) ZORUNLU — ayrinti Kaydet serhinde.
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,COALESCE($9,0),COALESCE($10,0))
		ON CONFLICT (user_id) DO UPDATE SET
		  kategori=EXCLUDED.kategori, adres=EXCLUDED.adres, il=EXCLUDED.il,
		  ilce=EXCLUDED.ilce, telefon=EXCLUDED.telefon, web=EXCLUDED.web,
		  calisma=EXCLUDED.calisma,
		  -- TURU 78 — KOORDINAT KORUNUR (bkz. Kaydet serhi: SIFIRA EZILIYORDU).
		  enlem  = COALESCE(EXCLUDED.enlem,  isletmeler.enlem),
		  boylam = COALESCE(EXCLUDED.boylam, isletmeler.boylam),
		  updated_at=now()`,
		me, req.Kategori, req.Adres, req.Il, req.Ilce, req.Telefon, req.Web,
		calisma, req.Enlem, req.Boylam); err != nil {
		log.Printf("isletme kaydet: %v", err)
		hata(w, 500, "kaydedilemedi")
		return
	}
	if tx.Commit(r.Context()) != nil {
		hata(w, 500, "kaydedilemedi")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// DELETE /users/me/isletme — kisisel hesaba DON.
//
// ⚠️ `isletmeler` SATIRI SILINMEZ (veri politikasi: VERI SILINMEZ). Yalniz
//
//	`hesap_turu` geri alinir; kullanici tekrar isletmeye gecerse eski
//	bilgileri ONUNDE hazir gelir.
func (h *Handler) KisiselYap(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	if _, err := h.db.Exec(r.Context(),
		`UPDATE users SET hesap_turu='kisisel' WHERE id=$1`, me); err != nil {
		hata(w, 500, "işlem yapılamadı")
		return
	}
	yaz(w, 200, map[string]bool{"ok": true})
}

// GET /users/{id}/isletme — isletme bilgileri (herkese acik).
//
// ⚠️ ENGEL KAPISI: engelli taraf 404 alir (403 DEGIL — "var ama goremezsin"
//
//	cevabi kendisi de bilgidir).
//
// ⚠️⚠️ TURU 78 — `dogrulandi` JSON alani artik `users.onayli`dan doldurulur
//
//	(bu dosyada `Detay` ve `Liste` sorgularinin ikisinde de `u.onayli`).
//	`isletmeler.dogrulandi` sutunu 6 Go + 8 Dart noktasinda OKUNUYORDU ama
//	ONA YAZAN TEK BIR SATIR YOKTU ve admin ucu da yoktu: tamamen OLU bir
//	ozellikti, rozet sahada ASLA gorunmezdi. Ustelik rozet iki ekranda ELLE
//	cizilmisti ve boyutlari ZATEN DRIFT ETMISTI.
//	Sutun KALDIRILMADI (veri politikasi + eski istemciler) ama TEK GERCEK
//	KAYNAK artik `users.onayli`dir. JSON alan ADI korundugu icin istemcide
//	hicbir sey degismedi.
//	⚠️ Ek JOIN GEREKMEDI: iki sorgu da zaten `JOIN users u` yapiyordu.
//	⚠️ YAPMA: `i.dogrulandi`ya geri donme; iki sutunu da yazan bir yol acma.
func (h *Handler) Detay(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	hedef := chi.URLParam(r, "id")
	if engel.Var(r.Context(), h.db, me, hedef) {
		hata(w, 404, "işletme bulunamadı")
		return
	}
	var kategori, adres, il, ilce, telefon, web string
	var calisma []byte
	var enlem, boylam float64
	var dogrulandi bool
	if h.db.QueryRow(r.Context(), `
		SELECT i.kategori, i.adres, i.il, i.ilce, i.telefon, i.web, i.calisma,
		       i.enlem, i.boylam, u.onayli
		  FROM isletmeler i JOIN users u ON u.id = i.user_id
		 WHERE i.user_id=$1 AND u.hesap_turu='isletme'`, hedef).
		Scan(&kategori, &adres, &il, &ilce, &telefon, &web, &calisma,
			&enlem, &boylam, &dogrulandi) != nil {
		hata(w, 404, "işletme bulunamadı")
		return
	}
	if len(calisma) == 0 {
		calisma = []byte("[]")
	}
	yaz(w, 200, map[string]any{
		"kategori": kategori, "kategori_ad": Kategoriler[kategori],
		"adres": adres, "il": il, "ilce": ilce,
		"telefon": telefon, "web": web,
		"calisma": json.RawMessage(calisma),
		"enlem":   enlem, "boylam": boylam, "dogrulandi": dogrulandi,
	})
}

// GET /isletmeler?kategori=&q=&il= — ISLETME REHBERI.
//
// ⚠️⚠️ Bu uc, hamburger menudeki Yemek / Restoran / Alisveris kartlarinin
//
//	BAGLANDIGI yerdir. Turu 76b'de o kartlar HICBIR YERE gitmiyordu
//	("yakinda" diyordu) — bu projede tekrar eden "olu dogmus ozellik"
//	sinifiydi. Artik gercek bir listeye baglaniyor.
func (h *Handler) Liste(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	kategori := strings.TrimSpace(r.URL.Query().Get("kategori"))
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	il := strings.TrimSpace(r.URL.Query().Get("il"))

	// ⚠️ Suzgecler OPSIYONEL ve TEK SORGUDA: her kombinasyon icin ayri sorgu
	//    yazmak (2^3 = 8 dal) drift eder. `$n = '' OR ...` deseni kullaniliyor.
	// ⚠️⚠️ TURU 78 — ILCE ve ONAYLI suzgecleri. "Şehrimde" ve "Onaylı" hizli
	//    kartlarinin ON KOSULU; bunlar olmadan o kartlar OLU DOGARDI.
	//    ⚠️ ASIMETRI DUZELTILDI: `ilce` suzgeci ILAN ucunda VARDI, isletmede YOKTU.
	ilce := strings.TrimSpace(r.URL.Query().Get("ilce"))
	yalnizOnayli := r.URL.Query().Get("dogrulandi") == "1"

	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		       i.kategori, i.il, i.ilce, i.adres, u.onayli
		  FROM isletmeler i JOIN users u ON u.id = i.user_id
		 WHERE u.hesap_turu='isletme'
		   AND ($2 = '' OR i.kategori = $2)
		   AND ($3 = '' OR i.il ILIKE $3)
		   AND ($4 = '' OR u.name ILIKE '%'||$4||'%' OR COALESCE(u.username,'') ILIKE '%'||$4||'%')
		   AND ($5 = '' OR i.ilce ILIKE $5)
		   AND (NOT $6 OR u.onayli)
		`+engel.Yuklem("$1", "u.id")+`
		 ORDER BY u.onayli DESC, u.name ASC
		 LIMIT 60`, me, kategori, il, q, ilce, yalnizOnayli)
	if err != nil {
		log.Printf("isletme liste: %v", err)
		hata(w, 500, "işletmeler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kullanici, avatar, kat, il2, ilce, adres string
		var medya *string
		var dogru bool
		if rows.Scan(&id, &ad, &kullanici, &avatar, &medya,
			&kat, &il2, &ilce, &adres, &dogru) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "name": ad, "username": kullanici,
			"avatar_url": avatar, "avatar_media_id": medya,
			"kategori": kat, "kategori_ad": Kategoriler[kat],
			"il": il2, "ilce": ilce, "adres": adres, "dogrulandi": dogru,
		})
	}
	yaz(w, 200, map[string]any{"isletmeler": out})
}

// GET /isletme-kategorileri — istemci listeyi SUNUCUDAN alir.
//
// ⚠️ Neden uc var: istemcideki sabit ile sunucudaki sabit DRIFT ederse
//
//	kullanici kendi sectigi kategoriyi "Diğer" olarak gorur. Istemci kendi
//	listesini gosterir ama BU UC ile dogrulanabilir; ayrica ileride kategori
//	eklenince ESKI SURUM ISTEMCILER de dogru adi gosterir.
func (h *Handler) KategoriListesi(w http.ResponseWriter, r *http.Request) {
	out := make([]map[string]string, 0, len(Kategoriler))
	for k, ad := range Kategoriler {
		out = append(out, map[string]string{"anahtar": k, "ad": ad})
	}
	yaz(w, 200, out)
}
