package auth

import (
	"context"
	"net/http"
	"strings"
)

type ctxKey string

const UserIDKey ctxKey = "user_id"

// Middleware: Authorization: Bearer <token> dogrular, user_id'yi context'e koyar
func Middleware(secret string) func(http.Handler) http.Handler {
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
			ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func UserID(ctx context.Context) string {
	id, _ := ctx.Value(UserIDKey).(string)
	return id
}
