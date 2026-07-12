-- iOS VoIP push (PushKit) cihaz token'lari — kilit ekraninda arama caldirmak icin.
-- FCM token'indan AYRI bir token; APNs'e dogrudan gonderilir (konu: <bundle>.voip).
CREATE TABLE IF NOT EXISTS voip_tokens (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_voip_tokens_user ON voip_tokens (user_id);
