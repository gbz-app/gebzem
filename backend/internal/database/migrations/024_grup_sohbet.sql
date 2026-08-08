-- 024_grup_sohbet.sql — TURU 76: GRUP SOHBETI + SOHBET YONETIMI.
--
-- ⚠️ ADDITIVE. Mevcut hicbir sutun daraltilmaz/kaldirilmaz.
-- ⚠️ `chats.type` CHECK'i 001'den beri 'group'a IZIN VERIYOR — dokunulmuyor.
--    Sorun semada degildi: backend'deki UC `INSERT INTO chats` ifadesinin UCU DE
--    'direct' SABITINI kullaniyordu, yani `type='group'` bir satir SAHADA HIC
--    URETILEMIYORDU.

-- ============ 1) GRUP AVATARI ============
-- ⚠️ `chats.avatar_url` 001'den beri var ama `users.avatar_url` ile AYNI
--    KADERI paylasiyor: sunucu ONA DA hicbir zaman yazmadi (turu 76 kok neden).
--    Grup fotografi da medya kaydi uzerinden gider — istemci URL veremez
--    (turu 74 guvenlik karari).
ALTER TABLE chats ADD COLUMN IF NOT EXISTS avatar_media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;

-- ============ 2) SOHBETI "BENDEN SIL" ============
-- ⚠️⚠️ `chat_members` SATIRI SILINMEZ, damga atilir.
--    Satiri silmek KARSI TARAFIN gecmisini de bozardi (mesajlar paylasilan
--    `messages` tablosunda durur) ve kullanicinin "VERI SILINMEZ" karariyla
--    celisirdi. Listeleme ve gecmis sorgulari bu damgadan SONRASINI gosterir.
-- ⚠️ GRUPTAN AYRILMA AYRI ISTIR: orada `chat_members` satiri GERCEKTEN silinir.
ALTER TABLE chat_members ADD COLUMN IF NOT EXISTS cleared_at TIMESTAMPTZ;

-- ============ 3) INDEKSLER ============
-- Sohbet listesi zaten `chat_members (chat_id,user_id)` PK'siyle geliyor;
-- yeni bir erisim deseni YOK. Arsiv/sabit filtreleri ISTEMCIDE uygulaniyor
-- (liste zaten kullanicinin tum sohbetleri — ayri index gereksiz yazma yuku).

-- ⚠️ NOT: `pinned`, `archived`, `role`, `muted_until` sutunlari 001'den beri
--    VARDI ama onlara YAZAN TEK BIR UC YOKTU (dort olu sutun). Turu 76'da
--    `PATCH /chats/{chatID}` ve grup uclariyla hepsi CANLANDI.
--    ⚠️ DERS: bir sutun eklerken ONU YAZAN ucu da ayni turda yaz.
