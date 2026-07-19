// Package livekit — ORTAK LiveKit yardimcilari (oda-yayin-plani.md Baglayici Karar 1):
// istemci erisim token'i (HS256, calls'daki desenle ayni) + SDK'siz RoomService twirp istemcisi.
// internal/calls'a DOKUNMAZ (oradaki token ureteci aynen kalir); Spaces (internal/rooms) ve
// ileride canli yayin (internal/streams) BU paketi kullanir.
//
// SDK EKLEMEME karari: server-sdk-go protobuf+psrpc zinciri surukler; bize 6-7 metot lazim,
// twirp JSON duz HTTP POST'tur (POST {base}/twirp/livekit.RoomService/{Metot}).
package livekit

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AccessToken — istemcinin odaya baglanacagi JWT. video: LiveKit grant map'i
// (roomJoin/canPublish/canSubscribe/canPublishData/canPublishSources...).
func AccessToken(apiKey, secret, identity, name string, video map[string]any, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":   apiKey,
		"sub":   identity,
		"name":  name,
		"nbf":   now.Add(-10 * time.Second).Unix(),
		"exp":   now.Add(ttl).Unix(),
		"video": video,
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

// Client — RoomService twirp istemcisi. Base ornek: http://167.233.229.88:7880
type Client struct {
	Base   string
	Key    string
	Secret string
	http   *http.Client
}

func NewClient(base, key, secret string) *Client {
	return &Client{Base: base, Key: key, Secret: secret, http: &http.Client{Timeout: 10 * time.Second}}
}

// adminToken — RoomService cagrilari icin kisa omurlu sunucu token'i.
// roomAdmin: katilimci yonetimi; roomCreate: CreateRoom/DeleteRoom; roomList: ListRooms.
func (c *Client) adminToken(room string) (string, error) {
	grant := map[string]any{"roomAdmin": true, "roomCreate": true, "roomList": true}
	if room != "" {
		grant["room"] = room
	}
	claims := jwt.MapClaims{
		"iss":   c.Key,
		"sub":   "gebzem-api",
		"nbf":   time.Now().Add(-10 * time.Second).Unix(),
		"exp":   time.Now().Add(10 * time.Minute).Unix(),
		"video": grant,
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(c.Secret))
}

func (c *Client) call(ctx context.Context, method, room string, in, out any) error {
	tok, err := c.adminToken(room)
	if err != nil {
		return err
	}
	b, err := json.Marshal(in)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.Base+"/twirp/livekit.RoomService/"+method, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	if resp.StatusCode != http.StatusOK {
		// twirp hatasi JSON {code,msg} doner — teshis icin govdeyi tasi
		return fmt.Errorf("livekit %s: %d %s", method, resp.StatusCode, string(body))
	}
	if out != nil {
		return json.Unmarshal(body, out)
	}
	return nil
}

// CreateRoom — ODA-BASI max_participants override'i. TUZAK (Baglayici Karar 2):
// livekit.yaml global max_participants:32; override edilmezse 33. katilimci SESSIZCE reddedilir.
func (c *Client) CreateRoom(ctx context.Context, room string, maxParticipants, emptyTimeoutSec int) error {
	return c.call(ctx, "CreateRoom", room, map[string]any{
		"name":              room,
		"max_participants":  maxParticipants,
		"empty_timeout":     emptyTimeoutSec,
		"departure_timeout": 60,
	}, nil)
}

// UpdateParticipant — izni CANLI baglantida degistirir (istemci yeni token/yeniden baglanma
// GEREKMEZ; ParticipantPermissionsUpdatedEvent alir). DIKKAT: can_publish_sources proto enum
// BUYUK harf ("MICROPHONE"); istemci token grant'inda ise kucuk harf ("microphone").
func (c *Client) UpdateParticipant(ctx context.Context, room, identity string, canPublish bool) error {
	perm := map[string]any{
		"can_subscribe":    true,
		"can_publish":      canPublish,
		"can_publish_data": canPublish,
	}
	if canPublish {
		perm["can_publish_sources"] = []string{"MICROPHONE"}
	}
	return c.call(ctx, "UpdateParticipant", room, map[string]any{
		"room": room, "identity": identity, "permission": perm,
	}, nil)
}

type TrackInfo struct {
	Sid   string `json:"sid"`
	Type  string `json:"type"` // AUDIO | VIDEO
	Muted bool   `json:"muted"`
}

// GetParticipantTracks — MutePublishedTrack track_sid istedigi icin zorunlu ara adim.
func (c *Client) GetParticipantTracks(ctx context.Context, room, identity string) ([]TrackInfo, error) {
	var out struct {
		Tracks []TrackInfo `json:"tracks"`
	}
	err := c.call(ctx, "GetParticipant", room, map[string]any{"room": room, "identity": identity}, &out)
	return out.Tracks, err
}

func (c *Client) MuteTrack(ctx context.Context, room, identity, sid string, muted bool) error {
	return c.call(ctx, "MutePublishedTrack", room, map[string]any{
		"room": room, "identity": identity, "track_sid": sid, "muted": muted,
	}, nil)
}

func (c *Client) RemoveParticipant(ctx context.Context, room, identity string) error {
	return c.call(ctx, "RemoveParticipant", room, map[string]any{"room": room, "identity": identity}, nil)
}

func (c *Client) DeleteRoom(ctx context.Context, room string) error {
	return c.call(ctx, "DeleteRoom", room, map[string]any{"room": room}, nil)
}

// ListRoomNames — verilen adlardan LiveKit'te HALEN VAR olanlari doner (sweep: LiveKit'in
// empty_timeout ile sildigi odalari DB'de de kapatmak icin).
func (c *Client) ListRoomNames(ctx context.Context, names []string) (map[string]bool, error) {
	var out struct {
		Rooms []struct {
			Name string `json:"name"`
		} `json:"rooms"`
	}
	if err := c.call(ctx, "ListRooms", "", map[string]any{"names": names}, &out); err != nil {
		return nil, err
	}
	m := make(map[string]bool, len(out.Rooms))
	for _, r := range out.Rooms {
		m[r.Name] = true
	}
	return m, nil
}

// SendData — odadaki istemcilere sunucudan veri (canli yayin hediye/sayac icin; Spaces'te kullanilmiyor).
func (c *Client) SendData(ctx context.Context, room string, data []byte, topic string) error {
	return c.call(ctx, "SendData", room, map[string]any{
		"room": room, "data": data, "kind": "RELIABLE", "topic": topic, // []byte -> base64 (proto3 JSON)
	}, nil)
}

// SendDataTo — YALNIZ verilen kimliklere veri (Bolum 6 D2: destination_identities destekli;
// hidden katilimcilar da ALIR — hidden yalniz gonderen kimligini gizler).
func (c *Client) SendDataTo(ctx context.Context, room string, data []byte, topic string, identities []string) error {
	return c.call(ctx, "SendData", room, map[string]any{
		"room": room, "data": data, "kind": "RELIABLE", "topic": topic,
		"destination_identities": identities,
	}, nil)
}

// SetStreamGuest — yayin izleyicisini KONUGA yukselt/dusur (Bolum 6 D1/D5).
// guest=true: kamera+mikrofon yayinlayabilir + hidden KALKAR (herkese duyurulur);
// guest=false: publish kapanir (sunucu track'leri soker) + hidden geri gelir.
// can_publish_data HER ZAMAN false (sahte hediye/chat data'si garantisi bozulmaz) —
// rooms.UpdateParticipant bu yuzden KULLANILAMAZ (o data'yi da acar, hidden bilmez).
func (c *Client) SetStreamGuest(ctx context.Context, room, identity string, guest bool) error {
	perm := map[string]any{
		"can_subscribe":    true,
		"can_publish":      guest,
		"can_publish_data": false,
		"hidden":           !guest,
	}
	if guest {
		perm["can_publish_sources"] = []string{"CAMERA", "MICROPHONE"}
	}
	return c.call(ctx, "UpdateParticipant", room, map[string]any{
		"room": room, "identity": identity, "permission": perm,
	}, nil)
}
