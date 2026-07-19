-- Kullanici karari (19 Tem): test doneminde herkese 10.000 jeton.
-- Yeni kayitlarin varsayilani 10000; mevcut kullanicilar 10000'e tamamlanir (dusurmez).
ALTER TABLE users ALTER COLUMN coin_balance SET DEFAULT 10000;
UPDATE users SET coin_balance = 10000 WHERE coin_balance < 10000;
