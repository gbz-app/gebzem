package chat

import (
	"context"
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

// Hub: bagli WebSocket istemcilerini tutar; Redis pub/sub ile coklu-instance'a hazir.
// Akis (arastirma karari): mesaj once PostgreSQL'e yazilir, sonra Redis'e publish edilir,
// hub kanaldan okuyup alicilarin acik soketlerine iter. Cevrimdisi kullanici, REST ile
// gecmisi ceker (inbox deseni) — pub/sub kacirmasi sorun olmaz.

type Client struct {
	UserID string
	Conn   *websocket.Conn
	Send   chan []byte
}

type Hub struct {
	mu      sync.RWMutex
	clients map[string]map[*Client]bool // userID -> baglantilar (coklu cihaz)
	rdb     *redis.Client
}

type Event struct {
	Type    string          `json:"type"`              // message.new, receipt.read, typing, presence
	ChatID  string          `json:"chat_id,omitempty"`
	Payload json.RawMessage `json:"payload,omitempty"`
	To      []string        `json:"to,omitempty"` // alici user id'leri
}

func NewHub(rdb *redis.Client) *Hub {
	return &Hub{clients: make(map[string]map[*Client]bool), rdb: rdb}
}

// Run: Redis kanalini dinle, gelen olaylari bagli istemcilere dagit
func (h *Hub) Run(ctx context.Context) {
	sub := h.rdb.Subscribe(ctx, "events")
	defer sub.Close()
	for {
		msg, err := sub.ReceiveMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			log.Printf("redis sub hatasi: %v", err)
			continue
		}
		var ev Event
		if err := json.Unmarshal([]byte(msg.Payload), &ev); err != nil {
			continue
		}
		h.deliver(&ev, []byte(msg.Payload))
	}
}

// Publish: olayi Redis'e yayinla (tum instance'lar alir)
func (h *Hub) Publish(ctx context.Context, ev *Event) error {
	b, err := json.Marshal(ev)
	if err != nil {
		return err
	}
	return h.rdb.Publish(ctx, "events", b).Err()
}

func (h *Hub) deliver(ev *Event, raw []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, uid := range ev.To {
		for c := range h.clients[uid] {
			select {
			case c.Send <- raw:
			default: // yavas istemci — kuyruk dolu, atla (gecmis REST'ten gelir)
			}
		}
	}
}

func (h *Hub) Register(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.clients[c.UserID] == nil {
		h.clients[c.UserID] = make(map[*Client]bool)
	}
	h.clients[c.UserID][c] = true
}

func (h *Hub) Unregister(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if conns, ok := h.clients[c.UserID]; ok {
		delete(conns, c)
		if len(conns) == 0 {
			delete(h.clients, c.UserID)
		}
	}
	close(c.Send)
}

// Subscribe: "events" kanalina ham abonelik (admin izleme paneli anlik guncelleme icin)
func (h *Hub) Subscribe(ctx context.Context) *redis.PubSub {
	return h.rdb.Subscribe(ctx, "events")
}

// Online: kullanicinin bu instance'da acik soketi var mi
func (h *Hub) Online(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients[userID]) > 0
}
