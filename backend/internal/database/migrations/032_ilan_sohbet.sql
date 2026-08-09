-- 032_ilan_sohbet.sql — TURU 78: ILAN MESAJLASMA.
--
-- Kullanici emri: "ilan mesajlasma sistemi olmali".
--
-- ⚠️⚠️ NEDEN `chats` TABLOSUNA SUTUN, AYRI TABLO DEGIL:
--    Mevcut sohbet hatti (messages / message_receipts / WS message.new /
--    okunmamis sayaci / engelleme kapisi / push bildirimi) TAMAMEN `chats`
--    uzerine kurulu. Ilan mesajlari icin AYRI bir tablo acmak bu SEKIZ
--    mekanizmanin HEPSININ ikinci bir kopyasini yazmak demekti — bu projede
--    "ayni kuralin iki kopyasi drift eder" hatasi ALTI kez tekrarladi.
--    Tek sutunla ilan sohbeti mevcut hattin TUM yeteneklerini devralir.
--
-- ⚠️⚠️ `type` HALA 'direct' KALIR, yeni bir tur ACILMAZ.
--    `chats.type` CHECK'ini DROP/ADD etmek 015'te yasanan migration tuzagini
--    acar. Ustelik ilan sohbeti DAVRANIS olarak birebir direkt sohbettir;
--    tek fark HANGI BAGLAMDA acildigidir.
--    ⚠️ SONUC: kisisel sohbet arayan HER sorgu artik `ilan_id IS NULL`
--       yuklemini TASIMAK ZORUNDA (bkz. internal/sohbet/direkt.go).
--       Bu yuklem olmadan profildeki "Mesaj gonder" kullaniciyi rastgele bir
--       ILAN sohbetine dusurur ve cevapsiz arama kaydi oraya yazilir.
--
-- ⚠️ VERI SILINMEZ: ilan satildi/kaldirildi olsa bile sohbet DURUR.
--    `ON DELETE SET NULL` yalnizca ilan satiri GERCEKTEN silinirse (ki bu
--    projede silinmiyor) sohbetin oksuz kalmamasi icin bir emniyettir.

ALTER TABLE chats ADD COLUMN IF NOT EXISTS ilan_id UUID
    REFERENCES ilanlar(id) ON DELETE SET NULL;

-- ⚠️ KISMI INDEX: satirlarin EZICI COGUNLUGU kisisel sohbet (ilan_id NULL).
--    Kismi index hem kucuk kalir hem de `ilan_id IS NULL` taramasini
--    hizlandirmaz — o zaten cok satirli daldir ve seq scan dogru plandir.
--    Bu index ILAN sohbetini bulan sorgu icindir.
-- ⚠️ AD TABLO ONEKLI (`idx_chats_...`): bu projede `idx_isletme_kategori`
--    cakismasi yasandi.
CREATE INDEX IF NOT EXISTS idx_chats_ilan
    ON chats (ilan_id) WHERE ilan_id IS NOT NULL;
