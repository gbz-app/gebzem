package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ctxKey string

const UserIDKey ctxKey = "user_id"

// Var olan kullanicilari kisa sure hatirlar — her istekte DB'ye gitmeyelim.
type userCache struct {
	mu   sync.RWMutex
	seen map[string]time.Time
}

func (c *userCache) valid(id string) bool {
	c.mu.RLock()
	t, ok := c.seen[id]
	c.mu.RUnlock()
	return ok && time.Since(t) < 5*time.Minute
}

func (c *userCache) mark(id string) {
	c.mu.Lock()
	if len(c.seen) > 20000 {
		c.seen = make(map[string]time.Time, 1024)
	}
	c.seen[id] = time.Now()
	c.mu.Unlock()
}

func (c *userCache) sil(id string) {
	c.mu.Lock()
	delete(c.seen, id)
	c.mu.Unlock()
}

// ⚠️⚠️⚠️ TURU 181 — ONBELLEK **PAKET DUZEYINDE** (eskiden `Middleware`in
//
//	kapanisindaydi ve disaridan ERISILEMIYORDU).
//
// NEDEN DEGISTI: askiya alma (`users.suspended_at`) bu turda urune girdi.
// Onbellek 5 DAKIKA pozitif hatirliyor; disaridan gecersizlestirilemezse
// admin bir hesabi askiya aldiginda o kisi **5 dakika daha** uygulamayi
// kullanmaya devam ederdi. Taciz/spam vakasinda bu kabul edilemez.
//
// ⚠️ `Middleware` bugun TEK KEZ cagriliyor (`cmd/api/main.go`); global
//
//	yapmak davranisi DEGISTIRMEZ. Birden fazla kez cagrilirsa onbellek
//	PAYLASILIR — bu da istenen sey (askiya alma her ornekte gecerli olur).
var kullaniciOnbellek = &userCache{seen: make(map[string]time.Time, 1024)}

// Gecersizlestir — bir kullanicinin onbellek kaydini ANINDA duşurur.
//
// ⚠️ Askiya alma / askiyi kaldirma / hesap silme yollarindan CAGRILMALI.
//
//	Cagrilmazsa degisiklik 5 dakikaya kadar gecikir (sessizce).
func Gecersizlestir(userID string) { kullaniciOnbellek.sil(userID) }

// Middleware: Authorization: Bearer <token> dogrular, user_id'yi context'e koyar.
// Token gecerli olsa bile kullanici DB'de yoksa (ornegin hesaplar silindiyse)
// 401 doner — boylece uygulama otomatik cikis yapip giris ekranina doner.
// Aksi halde sonraki uclar 404/500 dondurup "bir seyler ters gitti" ekranina yol acar.
func Middleware(secret string, db *pgxpool.Pool) func(http.Handler) http.Handler {
	cache := kullaniciOnbellek // turu 181: paket duzeyinde (bkz. serh)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			// WebSocket icin query parametresi de kabul edilir (?token=...)
			token := strings.TrimPrefix(header, "Bearer ")
			if token == "" || token == header {
				token = r.URL.Query().Get("token")
			}
			if token == "" {
				writeErr(w, http.StatusUnauthorized, "token gerekli")
				return
			}
			claims, err := ParseToken(secret, token)
			if err != nil {
				writeErr(w, http.StatusUnauthorized, "token geçersiz")
				return
			}

			if !cache.valid(claims.UserID) {
				// ⚠️⚠️⚠️ TURU 181 — **ASKIYA ALMA KAPISI** (migration 052).
				//
				//	`users.suspended_at` sutunu `015_medya.sql:132`'den beri
				//	VARDI ama kod tabaninda TEK BIR OKUYAN/YAZAN YOKTU
				//	(olculdu: `grep -rn suspended --include=*.go` = 0).
				//	Yani "askiya alma" altyapisi semada duruyor, urunde HIC
				//	YOKTU: bir taciz hesabini durdurmanin TEK yolu satiri
				//	elle SILMEKTI (geri donusu olmayan, KVKK acisindan da
				//	yanlis bir islem).
				//
				// ⚠️ Varlik + askı durumu **TEK SORGUDA**: ayri iki sorgu
				//	her istekte iki gidis-donus demekti.
				// ⚠️ `sebep` de okunur ki kullanici NEDEN giremedigini
				//	gorsun — sessizce 401 dondurmek, kullanicinin
				//	"uygulama bozuk" sanmasina yol acar.
				var askida bool
				var sebep string
				err := db.QueryRow(r.Context(), `
					SELECT suspended_at IS NOT NULL, COALESCE(suspend_sebep,'')
					  FROM users WHERE id = $1`, claims.UserID).Scan(&askida, &sebep)
				if err != nil {
					// ⚠️ `pgx.ErrNoRows` = kullanici YOK (hesap silinmis).
					//	Eskiden `EXISTS` ile bool donuyordu; `QueryRow`
					//	yolunda karsiligi budur. Diger hatalar 503.
					if errors.Is(err, pgx.ErrNoRows) {
						writeErr(w, http.StatusUnauthorized, "oturum sona erdi")
						return
					}
					writeErr(w, http.StatusServiceUnavailable, "sunucu meşgul")
					return
				}
				if askida {
					// ⚠️⚠️ **403, 401 DEGIL**: 401 istemcinin oturumu silip
					//	giris ekranina atmasina yol acar ve kullanici
					//	sifresini yanlis sanip tekrar tekrar dener.
					//	403 + SEBEP metni, ne oldugunu SOYLER.
					// ⚠️ Onbellege YAZILMAZ: askida kullanici her istekte
					//	yeniden sorulur, boylece askı KALDIRILDIGINDA
					//	ANINDA geri doner.
					if sebep == "" {
						sebep = "hesabınız askıya alındı"
					}
					writeErr(w, http.StatusForbidden, sebep)
					return
				}
				cache.mark(claims.UserID)
			}

			ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func UserID(ctx context.Context) string {
	id, _ := ctx.Value(UserIDKey).(string)
	return id
}
