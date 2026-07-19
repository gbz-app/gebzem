-- HEDIYE LEADERBOARD (Bolum 6 B1): kim hangi hediyeden kac adet — coin_ledger'dan
-- turetilemez (gift_id yok). TRUNCATE users CASCADE rutini bunu da bosaltir (bilincli:
-- leaderboard yayina bagli gecici veri; 5651 izi FK'siz stream_audit'te zaten var).
CREATE TABLE IF NOT EXISTS stream_gifts (
  id         BIGSERIAL PRIMARY KEY,
  stream_id  UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
  sender_id  UUID NOT NULL REFERENCES users(id),
  gift_id    TEXT NOT NULL,
  coins      BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_stream_gifts_stream ON stream_gifts(stream_id, sender_id);
