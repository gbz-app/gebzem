package isletme

// ⚠️⚠️⚠️ TURU 96h — KULLANICI ADRESLERI (kayitli konumlar).
//
// Arayuz turu 96f'de konum secici ekledi ve konumlari CIHAZDA tutuyordu;
// durust sinir kodda yaziliydi: telefon degisince adresler KAYBOLUYORDU.
// Bu dosya o borcu kapatir (migration 048).
//
// ⚠️ Adresler KISIYE OZELDIR: her sorgu `user_id = $1` ile baglanir.
//    "Sahiplik kontrolu cagirana birakildi" gibi bir kapi YOKTUR — bu
//    projede o varsayim turu 77b'de GIZLILIK ACIGI uretti.

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/auth"
)

type AdresHandler struct{ db *pgxpool.Pool }

func NewAdresHandler(db *pgxpool.Pool) *AdresHandler { return &AdresHandler{db: db} }

type adresIstek struct {
	Ad     string  `json:"ad"`
	Enlem  float64 `json:"enlem"`
	Boylam float64 `json:"boylam"`
}

// GET /users/me/adresler
func (h *AdresHandler) Liste(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	rows, err := h.db.Query(r.Context(), `
		SELECT id, ad, enlem, boylam, secili
		  FROM user_adresler
		 WHERE user_id = $1
		 ORDER BY created_at`, me)
	if err != nil {
		log.Printf("adres liste: %v", err)
		hata(w, 500, "adresler alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad string
		var enlem, boylam float64
		var secili bool
		if e := rows.Scan(&id, &ad, &enlem, &boylam, &secili); e != nil {
			log.Printf("adres scan: %v", e)
			continue
		}
		out = append(out, map[string]any{
			"id": id, "ad": ad, "enlem": enlem, "boylam": boylam,
			"secili": secili,
		})
	}
	// ⚠️ `rows.Err()` OKUNUR: dongu sessizce yarida kesilmis olabilir
	//    (turu 93b dersi — liste HICBIR IZ BIRAKMADAN kisalirdi).
	if e := rows.Err(); e != nil {
		log.Printf("adres rows: %v", e)
	}
	json.NewEncoder(w).Encode(map[string]any{"adresler": out})
}

// POST /users/me/adresler
//
// ⚠️⚠️ AYNI AD IKINCI KEZ GONDERILIRSE **GUNCELLENIR** (`ON CONFLICT`):
//
//	istemci "Ev"i haritadan yeniden secebilmeli. Hata dondurseydik
//	kullanici once silip sonra eklemek zorunda kalirdi.
//
// ⚠️ Yeni eklenen adres DAIMA SECILI olur: kullanici bir adres ekliyorsa
//
//	amaci onu kullanmaktir. Secim ayri bir istek olsaydi mesafe bir
//	sonraki dokunusa kadar ESKI adrese gore hesaplanirdi.
func (h *AdresHandler) Ekle(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	var in adresIstek
	if json.NewDecoder(r.Body).Decode(&in) != nil {
		hata(w, 400, "geçersiz istek")
		return
	}
	in.Ad = strings.TrimSpace(in.Ad)
	if in.Ad == "" {
		hata(w, 400, "ad gerekli")
		return
	}
	// ⚠️ TAVAN: ad 40 karakter. Sinirsiz birakilsaydi arayuzdeki konum
	//    dugmesi (genislik tavani var) yalnizca "..." gosterirdi.
	if len([]rune(in.Ad)) > 40 {
		hata(w, 400, "ad çok uzun")
		return
	}
	// ⚠️⚠️ KOORDINAT DOGRULAMASI: `NaN` her karsilastirmadan GECER ve
	//    `ParseFloat("NaN")` hata DONDURMEZ (turu 85b dersi) — bu yuzden
	//    aralik kontrolu `IsNaN` ile BIRLIKTE yapilir.
	if math.IsNaN(in.Enlem) || math.IsNaN(in.Boylam) ||
		in.Enlem < -90 || in.Enlem > 90 ||
		in.Boylam < -180 || in.Boylam > 180 {
		hata(w, 400, "geçersiz konum")
		return
	}
	// ⚠️ TAVAN: kullanici basina 20 adres. Sinirsiz olsaydi tek hesap
	//    tabloyu sisirebilirdi ve konum secici paneli kullanilamaz olurdu.
	var adet int
	if e := h.db.QueryRow(r.Context(),
		`SELECT count(*) FROM user_adresler WHERE user_id=$1`, me).
		Scan(&adet); e == nil && adet >= 20 {
		hata(w, 400, "en fazla 20 konum kaydedebilirsin")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "konum kaydedilemedi")
		return
	}
	defer tx.Rollback(r.Context())

	// ⚠️⚠️ ONCE HEPSI SECILMEZ YAPILIR, SONRA YENISI SECILI EKLENIR.
	//    Ters sirada yapilsaydi kisimli tekil indeks (`user_adresler_tek_
	//    secili`) ihlal edilir ve INSERT patlardi.
	if _, e := tx.Exec(r.Context(),
		`UPDATE user_adresler SET secili=false WHERE user_id=$1 AND secili`,
		me); e != nil {
		log.Printf("adres secim sifirla: %v", e)
		hata(w, 500, "konum kaydedilemedi")
		return
	}
	var id string
	if e := tx.QueryRow(r.Context(), `
		INSERT INTO user_adresler (user_id, ad, enlem, boylam, secili)
		VALUES ($1,$2,$3,$4,true)
		ON CONFLICT (user_id, ad) DO UPDATE
		   SET enlem = EXCLUDED.enlem,
		       boylam = EXCLUDED.boylam,
		       secili = true
		RETURNING id`, me, in.Ad, in.Enlem, in.Boylam).Scan(&id); e != nil {
		log.Printf("adres ekle: %v", e)
		hata(w, 500, "konum kaydedilemedi")
		return
	}
	if e := tx.Commit(r.Context()); e != nil {
		log.Printf("adres commit: %v", e)
		hata(w, 500, "konum kaydedilemedi")
		return
	}
	w.WriteHeader(201)
	json.NewEncoder(w).Encode(map[string]any{"id": id})
}

// POST /users/me/adresler/{id}/sec
func (h *AdresHandler) Sec(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	tx, err := h.db.Begin(r.Context())
	if err != nil {
		hata(w, 500, "seçilemedi")
		return
	}
	defer tx.Rollback(r.Context())
	if _, e := tx.Exec(r.Context(),
		`UPDATE user_adresler SET secili=false WHERE user_id=$1 AND secili`,
		me); e != nil {
		hata(w, 500, "seçilemedi")
		return
	}
	// ⚠️ `user_id` ZORUNLU: yalniz id ile guncellemek BASKASININ adresini
	//    secili yapardi (yatay yetki acigi).
	ct, e := tx.Exec(r.Context(),
		`UPDATE user_adresler SET secili=true WHERE id=$1 AND user_id=$2`,
		id, me)
	if e != nil {
		hata(w, 500, "seçilemedi")
		return
	}
	if ct.RowsAffected() == 0 {
		hata(w, 404, "konum bulunamadı")
		return
	}
	if tx.Commit(r.Context()) != nil {
		hata(w, 500, "seçilemedi")
		return
	}
	w.WriteHeader(204)
}

// DELETE /users/me/adresler/{id}
func (h *AdresHandler) Sil(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	id := chi.URLParam(r, "id")
	// ⚠️ `user_id` ZORUNLU (bkz. `Sec` serhi).
	ct, err := h.db.Exec(r.Context(),
		`DELETE FROM user_adresler WHERE id=$1 AND user_id=$2`, id, me)
	if err != nil {
		hata(w, 500, "silinemedi")
		return
	}
	if ct.RowsAffected() == 0 {
		hata(w, 404, "konum bulunamadı")
		return
	}
	w.WriteHeader(204)
}

// ⚠️ TURU 96h — SUZGEC PARAMETRELERI ICIN kucuk ayristiricilar.
//
// ⚠️ Bozuk deger **0 doner, hata DEGIL**: bir yazim hatasi yuzunden listenin
//    HIC gelmemesindense suzgecsiz gelmesi yeglenir (cagri yerindeki serh).
// ⚠️ NEGATIF deger de 0'a duser: `min_tutar=-5` yuklemi anlamsizca
//    daraltirdi.
func sayi(s string) int64 {
	v, err := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	if err != nil || v < 0 {
		return 0
	}
	return v
}

// ⚠️ `NaN` ozel olarak elenir: `ParseFloat("NaN")` HATA DONDURMEZ ve NaN her
//    karsilastirmadan gecerek yuklemi sessizce bozardi (turu 85b dersi).
func ondalik(s string) float64 {
	v, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil || math.IsNaN(v) || v < 0 {
		return 0
	}
	return v
}
