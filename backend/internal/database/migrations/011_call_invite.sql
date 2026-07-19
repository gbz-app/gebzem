-- ARAMAYA KISI EKLEME (1:1 -> grup yukseltme, parite-hukum B0).
-- endGroup'un "taze davet" kontrolu c.created_at yerine davet ANINA bakabilsin diye.
ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE call_participants p SET invited_at = c.created_at
  FROM calls c WHERE c.id = p.call_id;
