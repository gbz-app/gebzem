package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/getsentry/sentry-go"
	sentryhttp "github.com/getsentry/sentry-go/http"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/redis/go-redis/v9"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/calls"
	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/config"
	"github.com/gbz-app/gebzem/backend/internal/database"
	"github.com/gbz-app/gebzem/backend/internal/push"
	"github.com/gbz-app/gebzem/backend/internal/sms"
	"github.com/gbz-app/gebzem/backend/internal/udid"
	"github.com/gbz-app/gebzem/backend/internal/users"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg := config.Load()

	// Hata telemetrisi: panik/hatalar dosya+satir+istek bilgisiyle Sentry'e duser
	if cfg.SentryDSN != "" {
		if err := sentry.Init(sentry.ClientOptions{
			Dsn:              cfg.SentryDSN,
			Environment:      "prototype",
			EnableTracing:    true,
			TracesSampleRate: 0.2,
		}); err != nil {
			log.Printf("sentry baslatilamadi: %v", err)
		} else {
			log.Println("sentry: aktif")
			defer sentry.Flush(2 * time.Second)
		}
	}

	db, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("veritabani: %v", err)
	}
	defer db.Close()
	if err := database.Migrate(ctx, db); err != nil {
		log.Fatalf("migration: %v", err)
	}

	redisOpts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		log.Fatalf("redis url: %v", err)
	}
	rdb := redis.NewClient(redisOpts)
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis: %v", err)
	}

	hub := chat.NewHub(rdb)
	go hub.Run(ctx)

	pushSender := push.New(db)
	apnsSender := push.NewAPNs(db) // iOS kilit ekrani aramasi (VoIP)
	smsSender := sms.New()
	authH := auth.NewHandler(db, cfg, smsSender)
	chatH := chat.NewHandler(db, hub, pushSender)
	usersH := users.NewHandler(db)
	callsH := calls.NewHandler(db, hub, pushSender, apnsSender)
	if callsH.Enabled() {
		log.Println("arama (LiveKit): aktif")
		callsH.StartSweeper(ctx) // takili kalan aramalari kapat (cevapsiz/mesgul hatasi)
	} else {
		log.Println("arama: LIVEKIT_API_KEY yok — kapali")
	}

	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Logger)
	if cfg.SentryDSN != "" {
		// Panikleri Sentry'e bildirir, sonra Recoverer sunucuyu ayakta tutar
		r.Use(sentryhttp.New(sentryhttp.Options{Repanic: true}).Handle)
	}
	r.Use(middleware.Recoverer)

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})

	// Admin canli arama izleme paneli (JWT DEGIL, ?key= ile korumali; WS ile anlik)
	r.Get("/admin/izle", callsH.AdminPanel)
	r.Get("/admin/calls", callsH.AdminCalls)
	r.Get("/admin/ws", callsH.AdminWS)

	// iOS test cihazi kaydi (Over-The-Air) — profil yukleyen iPhone UDID'sini buraya yollar
	r.Post("/udid", udid.Handle)

	// acik uclar
	r.Route("/auth", func(r chi.Router) {
		r.Post("/register", authH.Register)
		r.Post("/verify", authH.Verify)
		r.Post("/login", authH.Login)
		r.Post("/forgot", authH.Forgot)
		r.Post("/reset", authH.Reset)
	})

	// korumali uclar
	r.Group(func(r chi.Router) {
		r.Use(auth.Middleware(cfg.JWTSecret, db))
		r.Get("/users/me", usersH.Me)
		r.Patch("/users/me", usersH.UpdateMe)
		r.Post("/users/me/username", usersH.SetUsername)
		r.Post("/users/me/fcm-token", usersH.SaveFCMToken)
		r.Delete("/users/me/fcm-token", usersH.DeleteFCMToken) // cikista bu cihazin token'ini sil
		r.Post("/users/me/voip-token", usersH.SaveVoIPToken)   // iOS kilit ekrani aramasi
		r.Get("/users/search", usersH.Search)
		r.Get("/users/by-phone", usersH.ByPhone)
		r.Get("/ws", chatH.WebSocket)
		r.Get("/chats", chatH.ListChats)
		r.Post("/chats/direct", chatH.CreateDirect)
		r.Get("/chats/{chatID}/messages", chatH.GetMessages)
		r.Post("/chats/{chatID}/messages", chatH.SendMessage)
		r.Post("/chats/{chatID}/read", chatH.MarkRead)
		// Aramalar (LiveKit)
		r.Get("/calls", callsH.History)
		r.Get("/calls/active", callsH.Active)      // calan arama var mi (uygulama on plana donunce)
		r.Get("/calls/{id}/status", callsH.Status) // arayan: aramam cevaplandi mi/bitti mi (kurtarma)
		r.Post("/calls", callsH.Start)
		r.Post("/calls/{id}/answer", callsH.Answer)
		r.Post("/calls/{id}/end", callsH.End)
	})

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}
	go func() {
		<-ctx.Done()
		srv.Shutdown(context.Background())
	}()

	log.Printf("gebzem api :%s (dev_mode=%v)", cfg.Port, cfg.DevMode)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}