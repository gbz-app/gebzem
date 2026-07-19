package push

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

// DataNotify — GENEL bildirim: notification tipli (sistem tepsisinde gorunur) + data payload
// (dokununca uygulama yonlendirme yapar). Davet sistemi icin (Bolum 5 B1): CallKit/VoIP DEGIL.
// NotifyUsers/CallInvite/send'e DOKUNULMADI (arama+mesaj akislari ayni kalir); TUM platform
// token'larina gider (iOS'a FCM->APNs koprusuyle normal bildirim duser).
func (s *Sender) DataNotify(userIDs []string, title, body string, data map[string]string) {
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
	var tokens []string
	for rows.Next() {
		var u, t string
		if rows.Scan(&u, &t) == nil {
			tokens = append(tokens, t)
		}
	}
	for _, t := range tokens {
		if err := s.sendData(t, title, body, data); err != nil {
			log.Printf("push: data-notify (%s...): %v", t[:min(12, len(t))], err)
			if errors.Is(err, errUnregistered) {
				s.db.Exec(ctx, `DELETE FROM device_tokens WHERE token=$1`, t)
			}
		}
	}
}

func (s *Sender) sendData(token, title, body string, data map[string]string) error {
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
			"data": data,
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
