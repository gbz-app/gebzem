-- Push bildirimleri: cihaz FCM token kayitlari
CREATE TABLE IF NOT EXISTS device_tokens (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT NOT NULL,
    platform   TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android','ios')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens (user_id);
