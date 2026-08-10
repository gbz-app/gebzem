-- ⚠️⚠️⚠️ TURU 81 — ILERI TARIHLI (ZAMANLANMIS) PAYLASIM.
--
-- Kullanici emri: "ileri tarihli paylasim, bunlarin da olmasi gerekiyor".
--
-- ═══════════ NEDEN ARKA PLAN ISI (SWEEPER) YOK ═══════════
--
-- Akis bu projede **OKUMA ZAMANI** calisiyor (turu 75 karari: yazma zamani
-- fan-out'ta 10.000 takipcili biri gonderi atinca 10.000 satir yazilir ve
-- cx33'te Postgres LiveKit ile AYNI 4 vCPU'yu paylastigi icin SFU ac kalir).
--
-- Bunun DOGRUDAN sonucu: zamanlanmis gonderiyi "yayinlayacak" bir ise GEREK
-- YOKTUR. Gonderi zaten her okuma aninda suzuluyor; yuklem `yayin_at <= now()`
-- olunca gonderi zamani geldigi ANDA kendiliginden gorunur olur.
--
-- ⚠️ Bu, bir sweeper'dan SADECE daha basit degil, DAHA GUVENLIDIR: sweeper
--    calismazsa (surec restart, kilit, hata) gonderi HIC yayinlanmaz ve
--    kullanici sebebini bilemez. Zaman yuklemi HIC BOZULMAZ.
-- ⚠️ YAPMA: buraya "zamani gelenleri yayinla" diye bir cron/sweeper ekleme.
--
-- ═══════════ NEDEN NULL = HEMEN ═══════════
--
-- `NULL` (varsayilan) "zamanlanmamis, yani hemen yayinda" demektir. Mevcut
-- TUM satirlar NULL kalir ve davranislari DEGISMEZ — geriye donuk uyumluluk
-- icin `DEFAULT now()` yerine NULL secildi. `DEFAULT now()` olsaydi migration
-- anindaki saat kaymalari yuzunden bazi eski gonderiler bir an "gelecekte"
-- gorunebilirdi.
--
-- ⚠️ VERI SILINMEZ kurali: iptal edilen zamanlanmis gonderi SILINMEZ; mevcut
--    silme yolu zaten satiri birakip `deleted_at` yaziyor.

ALTER TABLE posts ADD COLUMN IF NOT EXISTS yayin_at TIMESTAMPTZ;

-- ⚠️ KISMI INDEKS: yalnizca ZAMANLANMIS satirlari kapsar. Tam indeks
--    milyonlarca NULL satiri da tutardi ve akis sorgusuna faydasi olmazdi
--    (o sorgular zaten `author_id` / `created_at` indekslerinden yuruyor).
--    Bu indeksin tek musterisi "zamanlanmis gonderilerim" listesidir.
CREATE INDEX IF NOT EXISTS idx_posts_yayin_at
  ON posts (author_id, yayin_at) WHERE yayin_at IS NOT NULL;
