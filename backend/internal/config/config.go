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

	// ⚠️ TURU 74 — MEDYA (Cloudflare R2). Dordu birden dolu degilse medya KAPALI
	//    acilir (fail-closed) ve acilista log'a yazilir — sessizce yarim calismaz.
	R2Endpoint    string
	R2AccessKeyID string
	R2SecretKey   string
	R2Bucket      string
}

// MedyaAcik — R2 yapilandirmasi tam mi.
// ⚠️ Medya uclari yalniz bu true ise KAYDEDILIR; istemci de "GET /users/me"
//
//	yanitindaki "media_acik" alanina bakip atac dugmesini gizler.
func (c *Config) MedyaAcik() bool {
	return c.R2Endpoint != "" && c.R2AccessKeyID != "" &&
		c.R2SecretKey != "" && c.R2Bucket != ""
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

		R2Endpoint:    getEnv("R2_ENDPOINT", ""),
		R2AccessKeyID: getEnv("R2_ACCESS_KEY_ID", ""),
		R2SecretKey:   getEnv("R2_SECRET_ACCESS_KEY", ""),
		R2Bucket:      getEnv("R2_BUCKET", ""),
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
