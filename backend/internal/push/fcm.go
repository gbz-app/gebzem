package push

import (
	"bytes"
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FCM v1 gonderici — servis hesabi anahtariyla (fcm-sa.json) OAuth token alir,
// https://fcm.googleapis.com/v1/projects/{proje}/messages:send cagirir.
// Ek bagimlilik yok: JWT RS256 imzasi golang-jwt ile.

type Sender struct {
	db         *pgxpool.Pool
	projectID  string
	saEmail    string
	saKey      *rsa.PrivateKey
	mu         sync.Mutex
	token      string
	tokenExp   time.Time
	httpClient *http.Client
}

type saFile struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
}

// New: FCM_SA_PATH env'inden servis hesabini yukler; yoksa nil doner (push devre disi)
func New(db *pgxpool.Pool) *Sender {
	path := os.Getenv("FCM_SA_PATH")
	if path == "" {
		log.Println("push: FCM_SA_PATH tanimsiz — push devre disi")
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		log.Printf("push: sa dosyasi okunamadi (%v) — push devre disi", err)
		return nil
	}
	var sa saFile
	if err := json.Unmarshal(raw, &sa); err != nil {
		log.Printf("push: sa json hatali (%v) — push devre disi", err)
		return nil
	}
	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		log.Println("push: private_key pem cozulemedi — push devre disi")
		return nil
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		log.Printf("push: anahtar parse (%v) — push devre disi", err)
		return nil
	}
	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		log.Println("push: anahtar RSA degil — push devre disi")
		return nil
	}
	log.Printf("push: aktif (proje: %s)", sa.ProjectID)
	return &Sender{
		db: db, projectID: sa.ProjectID, saEmail: sa.ClientEmail, saKey: rsaKey,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}
}

// accessToken: OAuth2 SA akisi (JWT bearer grant), 55 dk cache
func (s *Sender) accessToken() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token != "" && time.Now().Before(s.tokenExp) {
		return s.token, nil
	}
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":   s.saEmail,
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
		"aud":   "https://oauth2.googleapis.com/token",
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}
	assertion, err := jwt.NewWithClaims(jwt.SigningMethodRS256, claims).SignedString(s.saKey)
	if err != nil {
		return "", err
	}
	form := url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {assertion},
	}
	resp, err := s.httpClient.PostForm("https://oauth2.googleapis.com/token", form)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var tr struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tr); err != nil || tr.AccessToken == "" {
		return "", errors.New("token yaniti gecersiz: " + string(body))
	}
	s.token = tr.AccessToken
	s.tokenExp = time.Now().Add(time.Duration(tr.ExpiresIn-300) * time.Second)
	return s.token, nil
}

// NotifyUsers: verilen kullanicilarin tum cihazlarina bildirim yollar (async kullanin)
func (s *Sender) NotifyUsers(userIDs []string, title, body, chatID string) {
	if s == nil || len(userIDs) == 0 {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	rows, err := s.db.Query(ctx, `
		SELECT user_id, token FROM device_tokens WHERE user_id = ANY($1)`, userIDs)
	if err != nil {
		log.Printf("push: token sorgusu: %v", err)
		return
	}
	defer rows.Close()
	type tk struct{ user, token string }
	var tokens []tk
	for rows.Next() {
		var t tk
		if rows.Scan(&t.user, &t.token) == nil {
			tokens = append(tokens, t)
		}
	}
	for _, t := range tokens {
		if err := s.send(t.token, title, body, chatID); err != nil {
			log.Printf("push: gonderim (%s...): %v", t.token[:min(12, len(t.token))], err)
			// UNREGISTERED ise token'i sil
			if errors.Is(err, errUnregistered) {
				s.db.Exec(ctx, `DELETE FROM device_tokens WHERE token=$1`, t.token)
			}
		}
	}
}

var errUnregistered = errors.New("unregistered")

func (s *Sender) send(token, title, body, chatID string) error {
	at, err := s.accessToken()
	if err != nil {
		return err
	}
	msg := map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]string{
				"title": title,
				"body":  body,
			},
			"data": map[string]string{"chat_id": chatID},
			"android": map[string]any{
				"priority":     "HIGH",
				"notification": map[string]string{"channel_id": "messages"},
			},
			"apns": map[string]any{
				"payload": map[string]any{"aps": map[string]any{"sound": "default"}},
			},
		},
	}
	b, _ := json.Marshal(msg)
	req, _ := http.NewRequest("POST",
		"https://fcm.googleapis.com/v1/projects/"+s.projectID+"/messages:send", bytes.NewReader(b))
	req.Header.Set("Authorization", "Bearer "+at)
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return nil
	}
	respBody, _ := io.ReadAll(resp.Body)
	if bytes.Contains(respBody, []byte("UNREGISTERED")) {
		return fmt.Errorf("%w: %s", errUnregistered, resp.Status)
	}
	return fmt.Errorf("fcm %s: %s", resp.Status, string(respBody[:min(200, len(respBody))]))
}
