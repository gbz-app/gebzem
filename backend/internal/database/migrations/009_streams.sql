-- CANLI YAYIN (prototip: saf WebRTC, <=300 izleyici) — oda-yayin-plani.md Bolum 2.
-- Tamami additive; calls/rooms tablolarina DOKUNMAZ. Izleyici basina DB satiri YOK
-- (anti-pattern: churn yazma yuku) — izleyici listesi/sayaci Redis'te.
CREATE TABLE IF NOT EXISTS streams (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcaster_id UUID NOT NULL REFERENCES users(id),
  title          TEXT NOT NULL DEFAULT '',
  type           TEXT NOT NULL DEFAULT 'video' CHECK (type IN ('audio','video')),
  status         TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live','paused','ended')),
  viewer_peak    INT    NOT NULL DEFAULT 0,
  gift_coins     BIGINT NOT NULL DEFAULT 0,     -- bu yayinda toplanan toplam jeton
  started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_streams_live ON streams(status) WHERE status IN ('live','paused');
-- Ayni yayincinin ikinci es zamanli yayini olamaz (cift-tik/retry muhafizi)
CREATE UNIQUE INDEX IF NOT EXISTS uq_streams_broadcaster_live
  ON streams(broadcaster_id) WHERE status IN ('live','paused');

CREATE TABLE IF NOT EXISTS stream_reports (
  id          BIGSERIAL PRIMARY KEY,
  stream_id   UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id),
  reason      TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (stream_id, reporter_id)
);

-- 5651 minimal iz (watch/leave/kick/end/gift) — FK YOK (bilincli): TRUNCATE users CASCADE
-- rutini bu tabloyu bosaltmasin; append-only.
CREATE TABLE IF NOT EXISTS stream_audit (
  id        BIGSERIAL PRIMARY KEY,
  stream_id UUID NOT NULL,
  user_id   UUID,
  action    TEXT NOT NULL,
  ip        TEXT,
  at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- HEDIYE IDEMPOTENCY: ayni kullanicinin ayni (reason, ref_id) cifti IKINCI KEZ yazilamaz
-- (retry cift harcamaz). (user_id, reason, ref_id) — kullanici-bagimsiz indeks baskasinin
-- hediyesini "duplicate"e dusurebilirdi (dogrulama bulgusu, Baglayici Karar 9).
CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_idem
  ON coin_ledger(user_id, reason, ref_id) WHERE ref_id <> '';
