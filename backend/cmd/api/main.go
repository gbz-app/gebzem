package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/redis/go-redis/v9"

	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/config"
	"github.com/gbz-app/gebzem/backend/internal/database"
	"github.com/gbz-app/gebzem/backend/internal/users"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg := config.Load()

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

	authH := auth.NewHandler(db, cfg)
	chatH := chat.NewHandler(db, hub)
	usersH := users.NewHandler(db)

	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Logger, middleware.Recoverer)

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})

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
		r.Use(auth.Middleware(cfg.JWTSecret))
		r.Get("/users/me", usersH.Me)
		r.Patch("/users/me", usersH.UpdateMe)
		r.Get("/users/by-phone", usersH.ByPhone)
		r.Get("/ws", chatH.WebSocket)
		r.Get("/chats", chatH.ListChats)
		r.Post("/chats/direct", chatH.CreateDirect)
		r.Get("/chats/{chatID}/messages", chatH.GetMessages)
		r.Post("/chats/{chatID}/messages", chatH.SendMessage)
		r.Post("/chats/{chatID}/read", chatH.MarkRead)
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
