package users

import (
	"net/http"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/engel"
)

// ⚠️⚠️ TURU 76 — KULLANICI OZETI (id -> ad + avatar).
//
// KOK NEDEN (kullanici sikayeti: "profil fotograflari her yerde gorunmuyor"):
// avatar bir yuzeyde ancak o yuzeyin verisi `avatar_media_id` TASIYORSA cizilebilir.
// Arama katmani bunu HIC tasimiyordu: `AramaBilgisi` yalnizca `peerName` ve `peerId`
// iceriyor; gelen arama VoIP push'undan / CallKit'ten geldiginde elimizde ZATEN
// yalnizca kimlik var. Yani "her cagiran yere avatar alani ekle" yaklasimi
// CallKit yolunda YAPISAL OLARAK IMKANSIZ.
//
// COZUM: kimlikten ozet cozen TEK bir uc + istemcide onbellekli saglayici.
// Boylece avatar gerektiren her yuzey (arama ekrani, yesil bant, yayin ici
// listeler, oda katilimcilari) AYNI kaynaktan besleniyor.
//
// ⚠️ `/users/{id}/profile` KULLANILMADI: o uc takipci sayilari + gizlilik kapisi
//
//	tasiyor ve GIZLI hesapta hata/eksik veri donebiliyor. Arama ekraninin
//	avatari, karsi tarafi ARAYABILIYOR olmamiza ragmen kaybolamaz.
//
// ⚠️ ENGEL KAPISI VAR: engelli taraf 404 alir (FAZ 3 ile ayni davranis —
//
//	403 DEGIL, cunku "var ama goremezsin" cevabi kendisi de bilgidir).
//
// ⚠️ COKLU SORGU: `?ids=a,b,c` ile 50'ye kadar kimlik TEK istekte cozulur.
//
//	Yayin izleyici listesi gibi yuzeyler aksi halde kisi basina bir istek
//	atardi (N+1) — CLAUDE.md turu 17'de bu tam olarak yasaklandi.
//
// GET /users/ozet?ids=<uuid>[,<uuid>...] -> [{id,name,username,avatar_url,avatar_media_id}]
func (h *Handler) Ozet(w http.ResponseWriter, r *http.Request) {
	me := auth.UserID(r.Context())
	if me == "" {
		writeErr(w, http.StatusUnauthorized, "yetkisiz")
		return
	}
	idler := ayirVeSinirla(r.URL.Query().Get("ids"), 50)
	if len(idler) == 0 {
		writeJSON(w, http.StatusOK, []map[string]any{})
		return
	}
	// ⚠️ `= ANY($2)` ile TEK sorgu. `[]string` -> `uuid[]` yazimi pgx'te
	//    TEXT formatina duserek calisir (bkz. social/tip_test.go).
	// ⚠️ GECERSIZ UUID: dizide bozuk bir deger varsa Postgres TUM sorguyu
	//    reddeder. `ayirVeSinirla` bu yuzden bicim suzgeci uyguluyor.
	rows, err := h.db.Query(r.Context(), `
		SELECT u.id, u.name, COALESCE(u.username,''),
		       COALESCE(u.avatar_url,''), u.avatar_media_id
		  FROM users u
		 WHERE u.id = ANY($2)`+engel.Yuklem("$1", "u.id"), me, idler)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "özet alınamadı")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, ad, kullanici, avatar string
		var medya *string
		if rows.Scan(&id, &ad, &kullanici, &avatar, &medya) == nil {
			out = append(out, map[string]any{
				"id": id, "name": ad, "username": kullanici,
				"avatar_url": avatar, "avatar_media_id": medya,
			})
		}
	}
	writeJSON(w, http.StatusOK, out)
}

// Virgullu listeyi ayirir, UUID BICIMINE UYMAYANLARI ATAR, tekrarlari eler
// ve en fazla [tavan] tane dondurur.
//
// ⚠️ BICIM SUZGECI ZORUNLU: tek bir bozuk deger `= ANY($2)` sorgusunun
// TAMAMINI 500'e dusururdu (Postgres diziyi butun halinde cozer).
func ayirVeSinirla(ham string, tavan int) []string {
	out := make([]string, 0, 8)
	gorulen := map[string]bool{}
	bas := 0
	for i := 0; i <= len(ham); i++ {
		if i != len(ham) && ham[i] != ',' {
			continue
		}
		p := ham[bas:i]
		bas = i + 1
		if !uuidMu(p) || gorulen[p] {
			continue
		}
		gorulen[p] = true
		out = append(out, p)
		if len(out) >= tavan {
			break
		}
	}
	return out
}

// 8-4-4-4-12 onaltilik bicim. (Harici paket eklemeye deger bir is degil.)
func uuidMu(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if c != '-' {
				return false
			}
			continue
		}
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') && (c < 'A' || c > 'F') {
			return false
		}
	}
	return true
}
