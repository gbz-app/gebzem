package auth

import (
	"context"
	"net/http"
	"strings"
	"sync"
	"time"

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

// Middleware: Authorization: Bearer <token> dogrular, user_id'yi context'e koyar.
// Token gecerli olsa bile kullanici DB'de yoksa (ornegin hesaplar silindiyse)
// 401 doner — boylece uygulama otomatik cikis yapip giris ekranina doner.
// Aksi halde sonraki uclar 404/500 dondurup "bir seyler ters gitti" ekranina yol acar.
func Middleware(secret string, db *pgxpool.Pool) func(http.Handler) http.Handler {
	cache := &userCache{seen: make(map[string]time.Time, 1024)}

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
				writeErr(w, http.StatusUnauthorized, "token gecersiz")
				return
			}

			if !cache.valid(claims.UserID) {
				var exists bool
				err := db.QueryRow(r.Context(),
					`SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)`, claims.UserID).Scan(&exists)
				if err != nil {
					writeErr(w, http.StatusServiceUnavailable, "sunucu mesgul")
					return
				}
				if !exists {
					writeErr(w, http.StatusUnauthorized, "oturum sona erdi")
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
