-- 016: TURU 74b DENETIM BULGUSU — eksik index.
--
-- ⚠️ SORUN: `media.erisebilir()` her `GET /media/{id}/url` isteginde
--    `WHERE m.media_id = $1` sorguyor. 015'te kurulan index
--    `(chat_id, id DESC) WHERE media_id IS NOT NULL` idi — yani `media_id`
--    YUKLEM, ANAHTAR DEGIL; bu sorgu onu KULLANAMAZ ve `messages` TAM TARANIR.
--    50 fotografli bir sohbet acilisi = 50 tam tarama. Kimlik dogrulamali her
--    kullaniciya acik ve ucta hiz siniri yok -> LiveKit ile paylasilan 4 vCPU'da
--    ucuz bir DoS yuzeyi.
-- ⚠️ ADDITIVE: yalnizca index ekler.
CREATE INDEX IF NOT EXISTS idx_messages_media_id
    ON messages (media_id) WHERE media_id IS NOT NULL;

-- Sikayet: hedef basina sayim (moderasyon onceliklendirme) zaten 014'te var.
-- Burada yalniz medya erisim yolu duzeltiliyor.
