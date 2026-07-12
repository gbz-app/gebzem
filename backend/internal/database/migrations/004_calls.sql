-- Sesli/goruntulu aramalar (LiveKit odalari)
CREATE TABLE IF NOT EXISTS calls (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caller_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    callee_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL DEFAULT 'audio' CHECK (type IN ('audio','video')),
    status      TEXT NOT NULL DEFAULT 'ringing'
                CHECK (status IN ('ringing','active','ended','rejected','missed')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    answered_at TIMESTAMPTZ,
    ended_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_calls_caller ON calls (caller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_calls_callee ON calls (callee_id, created_at DESC);
