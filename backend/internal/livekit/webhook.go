package livekit

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
)

// LIVEKIT WEBHOOK (test turu 19 — "kapatinca ANINDA bitsin").
//
// LiveKit, oda/katilimci olaylarini backend'e POST eder:
//   Content-Type: application/webhook+json
//   Authorization: <JWT>   (api_key ile HMAC-SHA256 imzali; `sha256` claim'i = govdenin
//                           SHA-256 ozetinin base64'u)
// Govde (protojson): {"event":"participant_left","room":{"name":"call_<id>","numParticipants":0},
//                     "participant":{"identity":"<uuid>"},"id":"...","createdAt":...}
//
// Bu paket YALNIZ dogrulama + cozme yapar; ne yapilacagina calls/streams karar verir.

// WebhookOlay — ihtiyacimiz olan alanlar (protojson camelCase).
type WebhookOlay struct {
	Event string `json:"event"`
	Room  struct {
		Name            string `json:"name"`
		NumParticipants int    `json:"numParticipants"`
	} `json:"room"`
	Participant struct {
		Identity string `json:"identity"`
	} `json:"participant"`
}

// WebhookCoz — istegi DOGRULAR (imza + govde ozeti) ve olayi cozer.
// key/secret: LiveKit ile ayni anahtar cifti (livekit.yaml webhook.api_key = key).
func WebhookCoz(r *http.Request, key, secret string) (*WebhookOlay, error) {
	if key == "" || secret == "" {
		return nil, errors.New("livekit anahtari yok")
	}
	govde, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	tok := strings.TrimSpace(r.Header.Get("Authorization"))
	tok = strings.TrimPrefix(tok, "Bearer ")
	if tok == "" {
		return nil, errors.New("imza yok")
	}
	claims, err := jwtDogrula(tok, secret)
	if err != nil {
		return nil, err
	}
	if iss, _ := claims["iss"].(string); iss != key {
		return nil, errors.New("anahtar uyusmuyor")
	}
	// Govde ozeti: JWT'deki sha256 claim'i ile birebir olmali (replay/oynama korumasi)
	if beklenen, ok := claims["sha256"].(string); ok && beklenen != "" {
		toplam := sha256.Sum256(govde)
		if base64.StdEncoding.EncodeToString(toplam[:]) != beklenen {
			return nil, errors.New("govde ozeti uyusmuyor")
		}
	}
	var olay WebhookOlay
	if err := json.Unmarshal(govde, &olay); err != nil {
		return nil, err
	}
	return &olay, nil
}

// jwtDogrula — HS256 JWT imza dogrulama (harici bagimlilik yok; AccessToken uretimiyle simetrik).
func jwtDogrula(tok, secret string) (map[string]any, error) {
	parcalar := strings.Split(tok, ".")
	if len(parcalar) != 3 {
		return nil, errors.New("gecersiz jwt")
	}
	imzaGirdi := parcalar[0] + "." + parcalar[1]
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(imzaGirdi))
	beklenen := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(beklenen), []byte(parcalar[2])) {
		return nil, errors.New("imza gecersiz")
	}
	ham, err := base64.RawURLEncoding.DecodeString(parcalar[1])
	if err != nil {
		return nil, err
	}
	var claims map[string]any
	if err := json.Unmarshal(ham, &claims); err != nil {
		return nil, err
	}
	return claims, nil
}
