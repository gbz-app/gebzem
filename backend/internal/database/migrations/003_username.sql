-- Gercek profiller: kullanici adi (@handle) ile arama
ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT;

-- Mevcut kullanicilara telefon sonundan gecici kullanici adi ver
UPDATE users
SET username = 'kullanici' || right(phone, 4) || substr(md5(id::text), 1, 3)
WHERE username IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users (lower(username));
-- Isim + kullanici adi aramasi icin (ILIKE prefix aramalarini hizlandirir)
CREATE INDEX IF NOT EXISTS idx_users_name_lower ON users (lower(name));
