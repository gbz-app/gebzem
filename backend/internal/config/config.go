package config

import (
	"log"
	"os"
)

type Config struct {
	Port        string
	DatabaseURL string
	RedisURL    string
	JWTSecret   string
	SentryDSN   string // bos ise hata telemetrisi kapali
	// Firebase proje kimligi — gercek SMS dogrulamasi icin (bos ise kapali)
	FirebaseProjectID string
	// Dev modunda OTP SMS gonderilmez, API yanitinda doner (prototip)
	DevMode bool
}

func Load() *Config {
	cfg := &Config{
		Port:        getEnv("PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", "postgres://gebzem:gebzem@localhost:5432/gebzem?sslmode=disable"),
		RedisURL:    getEnv("REDIS_URL", "redis://localhost:6379/0"),
		JWTSecret:   getEnv("JWT_SECRET", ""),
		SentryDSN:   getEnv("SENTRY_DSN", ""),

		FirebaseProjectID: getEnv("FIREBASE_PROJECT_ID", ""),
		DevMode:           getEnv("DEV_MODE", "true") == "true",
	}
	if cfg.JWTSecret == "" {
		if !cfg.DevMode {
			log.Fatal("JWT_SECRET zorunlu (uretim modunda)")
		}
		cfg.JWTSecret = "dev-secret-degistir"
	}
	return cfg
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
