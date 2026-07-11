-- Gebzem Faz 1 semasi: kullanicilar + 1:1 sohbet
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone         TEXT UNIQUE NOT NULL,           -- E.164: +905xxxxxxxxx
    password_hash TEXT NOT NULL,
    name          TEXT NOT NULL DEFAULT '',
    about         TEXT NOT NULL DEFAULT 'Merhaba! Gebzem kullaniyorum.',
    avatar_url    TEXT NOT NULL DEFAULT '',
    verified      BOOLEAN NOT NULL DEFAULT FALSE, -- OTP dogrulandi mi
    coin_balance  BIGINT NOT NULL DEFAULT 100,    -- kayit bonusu (prototip: bedava jeton)
    last_seen     TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- OTP kodlari (kayit, sifre sifirlama)
CREATE TABLE IF NOT EXISTS otp_codes (
    id         BIGSERIAL PRIMARY KEY,
    phone      TEXT NOT NULL,
    code       TEXT NOT NULL,
    purpose    TEXT NOT NULL CHECK (purpose IN ('register','reset_password','change_phone')),
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_codes (phone, purpose, used);

-- Sohbetler: Telegram modeli — tek tablo, type ile ayrilir (direct/group; kanal V2'de ayni tabloya megagroup bayragiyla)
CREATE TABLE IF NOT EXISTS chats (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type       TEXT NOT NULL DEFAULT 'direct' CHECK (type IN ('direct','group','channel')),
    title      TEXT NOT NULL DEFAULT '',
    avatar_url TEXT NOT NULL DEFAULT '',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_members (
    chat_id    UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role       TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member','admin','owner')),
    pinned     BOOLEAN NOT NULL DEFAULT FALSE,
    archived   BOOLEAN NOT NULL DEFAULT FALSE,
    muted_until TIMESTAMPTZ,
    joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (chat_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_members_user ON chat_members (user_id);

CREATE TABLE IF NOT EXISTS messages (
    id          BIGSERIAL PRIMARY KEY,
    chat_id     UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    sender_id   UUID NOT NULL REFERENCES users(id),
    type        TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text','image','video','audio','location','system')),
    content     TEXT NOT NULL DEFAULT '',            -- metin ya da konum "lat,lng"
    media_url   TEXT NOT NULL DEFAULT '',
    reply_to_id BIGINT REFERENCES messages(id),
    deleted_for_all BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages (chat_id, id DESC);

-- Teslim/okundu (tik sistemi): her mesaj x alici
CREATE TABLE IF NOT EXISTS message_receipts (
    message_id   BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ,
    read_at      TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id)
);

-- Engelleme
CREATE TABLE IF NOT EXISTS blocks (
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id)
);

-- Jeton hareketleri (ledger — arastirma karari: her islem kayitli)
CREATE TABLE IF NOT EXISTS coin_ledger (
    id         BIGSERIAL PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id),
    amount     BIGINT NOT NULL,                     -- +yukleme / -harcama
    reason     TEXT NOT NULL,                       -- signup_bonus, admin_grant, gift_sent, gift_received
    ref_id     TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ledger_user ON coin_ledger (user_id, id DESC);
