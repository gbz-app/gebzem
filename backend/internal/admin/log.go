package admin

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/isletme"
)

// Handler — yonetim paneli uclari.
//
// ⚠️ `db` disinda bagimliligi YOKTUR ve bu BILINCLI: paket `chat`/`calls`/
//
//	`social` gibi is paketlerini import etseydi hem dairesel bagimlilik
//	riski dogar hem admin, urun mantiginin ic ayrintilarina baglanirdi.
//	Admin SQL'i DOGRUDAN yazar.
type Handler struct {
	db *pgxpool.Pool

	// ⚠️⚠️ ISLETME YAZMA YOLU **DEVREDILIR**, kopyalanmaz: `isletmeler`
	//	tablosuna yazan tum dogrulama/COALESCE kurallari
	//	`internal/isletme/admin_yaz.go`da TEK KAYNAK. Admin kendi
	//	INSERT/UPDATE'ini yazsaydi iki yazici kacinilmaz olarak ayrisirdi.
	// ⚠️ Dairesel bagimlilik YOK: `isletme` paketi `admin`i import ETMIYOR.
	isletmeler *isletme.Handler
}

func NewHandler(db *pgxpool.Pool, isletmeler *isletme.Handler) *Handler {
	return &Handler{db: db, isletmeler: isletmeler}
}

// ⚠️⚠️⚠️ TURU 181 — YONETIM DENETIM KAYDI (`admin_log`, migration 052).
//
// NEDEN ZORUNLU: panel bu turda ILK KEZ yazma yetkisi aliyor (isletme
// olustur/duzenle/kapat, kullanici askiya al, icerik karantina). Yazma
// yetkisi olup "kim ne yapti" kaydi olmayan bir panel, bir hatanin ya da
// kotu niyetin GERI IZLENEMEZ olmasi demektir. 5651 acisindan da kritik:
// bir icerigin ne zaman ve kim tarafindan kaldirildigi kanitlanabilmeli.
//
// ⚠️ `oncesi`/`sonrasi`: yalniz "sildi" yazmak yetmez — NEYIN silindigi de
//
//	kayitta olmali. Ikisi de `nil` olabilir (olusturma/silmede bir taraf
//	yoktur).
//
// ⚠️⚠️ HATA **YUTULUR** ama LOGLANIR: denetim kaydi yazilamadi diye
//
//	kullanicinin (yoneticinin) islemi BASARISIZ OLMAMALI. Aksi halde
//	`admin_log` tablosundaki gecici bir sorun TUM paneli kilitlerdi.
//
// ⚠️ Cagri ISLEMIN DISINDA (commit sonrasi): geri alinan bir islem icin
//
//	"yapildi" kaydi birakmak, kaydin kendisini yalanci yapar.
func Yaz(r *http.Request, db *pgxpool.Pool, eylem, hedefTur, hedefID string,
	oncesi, sonrasi any) {
	if db == nil {
		return
	}
	var oJSON, sJSON []byte
	if oncesi != nil {
		oJSON, _ = json.Marshal(oncesi)
	}
	if sonrasi != nil {
		sJSON, _ = json.Marshal(sonrasi)
	}
	// ⚠️ AYRI CONTEXT: istek baglami (`r.Context()`) cagiran taraf yaniti
	//	yazip donunce IPTAL olur; denetim kaydi o yaristan ETKILENMEMELI
	//	(turu 78b `End()` dersi: istek-omurlu context COMMIT'i bile
	//	iptal hatasina cevirebiliyordu).
	ctx, iptal := context.WithTimeout(context.Background(), 5*time.Second)
	defer iptal()
	if _, err := db.Exec(ctx, `
		INSERT INTO admin_log (aktor, eylem, hedef_tur, hedef_id, oncesi, sonrasi, ip)
		VALUES ('admin', $1, $2, $3, $4, $5, $6)`,
		eylem, hedefTur, hedefID, oJSON, sJSON, ip(r)); err != nil {
		log.Printf("admin_log yazilamadi (%s): %v", eylem, err)
	}
}

// Gunluk — GET /admin/gunluk?limit=&hedef_tur=&hedef_id=
//
// ⚠️ Panelde "kim ne yapti" sekmesi; denetim kaydinin OKUNAN yolu.
//
//	Yazan yol var okuyan yok olsaydi bu, projede DOKUZ kez tekrarlayan
//	"sutun var, kullanan yol yok" sinifinin bir ornegi olurdu.
func (h *Handler) Gunluk(w http.ResponseWriter, r *http.Request) {
	if !kapi(w, r) {
		return
	}
	limit := sayi(r, "limit", 100, 1, 500)
	rows, err := h.db.Query(r.Context(), `
		SELECT id, aktor, eylem, hedef_tur, hedef_id,
		       COALESCE(oncesi::text,''), COALESCE(sonrasi::text,''),
		       ip, to_char(created_at,'DD.MM.YY HH24:MI:SS')
		  FROM admin_log
		 WHERE ($1 = '' OR hedef_tur = $1)
		   AND ($2 = '' OR hedef_id  = $2)
		 ORDER BY created_at DESC
		 LIMIT $3`,
		r.URL.Query().Get("hedef_tur"), r.URL.Query().Get("hedef_id"), limit)
	if err != nil {
		hata(w, http.StatusInternalServerError, "sorgu hatası")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id int64
		var aktor, eylem, ht, hid, onc, son, adres, zaman string
		if rows.Scan(&id, &aktor, &eylem, &ht, &hid, &onc, &son, &adres, &zaman) != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": id, "aktor": aktor, "eylem": eylem,
			"hedef_tur": ht, "hedef_id": hid,
			"oncesi": onc, "sonrasi": son, "ip": adres, "zaman": zaman,
		})
	}
	yaz(w, http.StatusOK, out)
}
