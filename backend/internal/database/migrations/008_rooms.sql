-- SPACES (sesli oda) — oda-yayin-plani.md Bolum 1 Adim 1.
-- Tamami additive; calls/call_participants tablolarina DOKUNMAZ.
CREATE TABLE IF NOT EXISTS rooms (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id    UUID NOT NULL REFERENCES users(id),
  title      TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live','ended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_rooms_live ON rooms(created_at DESC) WHERE status='live';

-- Katilimci basina TEK satir: rol + durum + el-kaldirma. Yeniden giriste durum sifirlanir,
-- 5651 izi room_audit'te korunur. Rol kaynagi DB (LiveKit metadata KULLANILMAZ — race #1829).
CREATE TABLE IF NOT EXISTS room_participants (
  room_id        UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role           TEXT NOT NULL DEFAULT 'listener' CHECK (role IN ('host','speaker','listener')),
  status         TEXT NOT NULL DEFAULT 'joined'   CHECK (status IN ('joined','left','removed')),
  hand_raised_at TIMESTAMPTZ,          -- NULL = el kalkik degil
  joined_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at        TIMESTAMPTZ,
  PRIMARY KEY (room_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_room_participants_room
    ON room_participants (room_id) WHERE status='joined';

-- 5651 minimal iz: append-only, satir SILINMEZ/GUNCELLENMEZ. FK YOK (bilincli):
-- TRUNCATE users CASCADE rutini bu tabloyu bosaltmasin.
CREATE TABLE IF NOT EXISTS room_audit (
  id      BIGSERIAL PRIMARY KEY,
  room_id UUID NOT NULL,
  user_id UUID,
  action  TEXT NOT NULL,
  ip      TEXT,
  at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
