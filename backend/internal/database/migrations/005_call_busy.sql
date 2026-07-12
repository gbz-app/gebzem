-- Arama gecmisi detaylari: "mesgul" durumu (alici zaten baska aramadayken gelen arama)
ALTER TABLE calls DROP CONSTRAINT IF EXISTS calls_status_check;
ALTER TABLE calls ADD CONSTRAINT calls_status_check
    CHECK (status IN ('ringing','active','ended','rejected','missed','busy'));

-- Cevapsiz aramalari hizli listelemek icin (arama sekmesindeki kirmizi rozet)
CREATE INDEX IF NOT EXISTS idx_calls_callee_missed
    ON calls (callee_id, created_at DESC)
    WHERE status IN ('missed','rejected','busy');
