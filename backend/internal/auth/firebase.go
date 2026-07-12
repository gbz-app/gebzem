package auth

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Firebase Phone Auth dogrulayici:
// Telefon SMS'i Firebase gonderir, istemci ID token alir, biz burada dogrularz.
// Google'in acik anahtarlariyla imza kontrolu — ek bagimlilik yok.

const googleCertsURL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

type FirebaseVerifier struct {
	projectID string
	mu        sync.RWMutex
	keys      map[string]*rsa.PublicKey
	expiresAt time.Time
	client    *http.Client
}

func NewFirebaseVerifier(projectID string) *FirebaseVerifier {
	return &FirebaseVerifier{
		projectID: projectID,
		keys:      map[string]*rsa.PublicKey{},
		client:    &http.Client{Timeout: 10 * time.Second},
	}
}

// VerifyPhone: ID token'i dogrular, icindeki telefon numarasini dondurur
func (v *FirebaseVerifier) VerifyPhone(idToken string) (string, error) {
	token, err := jwt.Parse(idToken, func(t *jwt.Token) (any, error) {
		if t.Method.Alg() != "RS256" {
			return nil, errors.New("beklenmeyen imza yontemi")
		}
		kid, _ := t.Header["kid"].(string)
		if kid == "" {
			return nil, errors.New("kid yok")
		}
		return v.publicKey(kid)
	},
		jwt.WithIssuer("https://securetoken.google.com/"+v.projectID),
		jwt.WithAudience(v.projectID),
		jwt.WithExpirationRequired(),
	)
	if err != nil {
		return "", fmt.Errorf("token gecersiz: %w", err)
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return "", errors.New("token gecersiz")
	}
	phone, _ := claims["phone_number"].(string)
	if phone == "" {
		return "", errors.New("token'da telefon numarasi yok")
	}
	return phone, nil
}

// publicKey: Google'in x509 sertifikalarini cekip cache'ler (1 saat)
func (v *FirebaseVerifier) publicKey(kid string) (*rsa.PublicKey, error) {
	v.mu.RLock()
	if key, ok := v.keys[kid]; ok && time.Now().Before(v.expiresAt) {
		v.mu.RUnlock()
		return key, nil
	}
	v.mu.RUnlock()

	resp, err := v.client.Get(googleCertsURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var certs map[string]string
	if err := json.Unmarshal(body, &certs); err != nil {
		return nil, err
	}

	keys := make(map[string]*rsa.PublicKey, len(certs))
	for k, certPEM := range certs {
		block, _ := pem.Decode([]byte(certPEM))
		if block == nil {
			continue
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			continue
		}
		if pub, ok := cert.PublicKey.(*rsa.PublicKey); ok {
			keys[k] = pub
		}
	}

	v.mu.Lock()
	v.keys = keys
	v.expiresAt = time.Now().Add(time.Hour)
	v.mu.Unlock()

	if key, ok := keys[kid]; ok {
		return key, nil
	}
	return nil, errors.New("anahtar bulunamadi: " + kid)
}
