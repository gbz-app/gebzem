-- Grup aramalari: calls tablosunu genislet + katilimci durumlari.
-- 1:1 GERIYE UYUMLU: mevcut 1:1 kodu callee_id dolu + is_group=false + chat_id NULL yazmaya devam eder.
-- Tum ifadeler additive + IF NOT EXISTS -> mevcut veri/aramalar DEGISMEZ (regresyon riski dusuk).

-- Grup aramasinda tekil karsi taraf yok; chat_id odanin hangi gruba ait oldugunu, is_group turu belirtir.
ALTER TABLE calls ADD COLUMN IF NOT EXISTS chat_id UUID REFERENCES chats(id) ON DELETE CASCADE;
ALTER TABLE calls ADD COLUMN IF NOT EXISTS is_group BOOLEAN NOT NULL DEFAULT false;

-- Grup satirinda tekil callee YOK -> callee_id NULL olabilmeli. 1:1 hala dolu yazar (etkilenmez).
ALTER TABLE calls ALTER COLUMN callee_id DROP NOT NULL;

-- Her grup katilimcisinin kendi durum + zaman damgasi (1:1'de tek satirdaki status/answered_at grupta yetmez).
CREATE TABLE IF NOT EXISTS call_participants (
    call_id   UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status    TEXT NOT NULL DEFAULT 'ringing'
              CHECK (status IN ('ringing','joined','left','rejected','missed')),
    joined_at TIMESTAMPTZ,
    left_at   TIMESTAMPTZ,
    PRIMARY KEY (call_id, user_id)
);

-- Kullanicinin CALAN/AKTIF oldugu grup aramalarini hizli bulmak icin (Active/checkActive).
CREATE INDEX IF NOT EXISTS idx_call_participants_user
    ON call_participants (user_id) WHERE status IN ('ringing','joined');
