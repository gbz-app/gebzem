-- 035_etkinlik_kadro.sql — TURU 78: ETKINLIK KADROSU (oyuncu / sarkici / konusmaci).
--
-- Kullanici emri: "katilimci oyuncu sarkici ekleme bunlar olmali".
--
-- ⚠️⚠️ "KADRO" ILE "KATILIMCI" FARKLI IKI KAVRAMDIR — karistirilmamali:
--    · `etkinlik_katilim` = RSVP. "Ben gidiyorum" diyen KULLANICILAR.
--    · `etkinlik_kadro`   = SAHNEDEKILER. Sarkici, oyuncu, konusmaci, DJ...
--    Ikisini tek tabloda birlestirmek (ornegin `etkinlik_katilim`e rol sutunu
--    eklemek) YAPISAL OLARAK YANLIS olurdu: kadrodaki kisi ETKINLIGE KATILAN
--    biri degil, ETKINLIGIN ICERIGIDIR ve cogu zaman uygulamada HESABI BILE YOK.
--
-- ⚠️⚠️ `user_id` ZORUNLU DEGIL (NULL olabilir) — EN KRITIK TASARIM KARARI.
--    Kadroya yazilacak kisi genelde UNLU biridir ve Gebzem'e kayitli DEGILDIR.
--    `user_id` zorunlu olsaydi ozellik pratikte KULLANILAMAZDI: bir konser
--    etkinligine sarkicinin adini yazamazdiniz.
--    Kayitliysa `user_id` doldurulur ve istemci profiline BAGLAR.
--
-- ⚠️⚠️ KADRODA AYRI FOTOGRAF ALANI **YOK** — bu da bilincli:
--    Yeni bir `media_id` sutunu acmak `media.erisebilir()` icine YENI BIR DAL
--    yazmayi ZORUNLU kilardi. O dal unutuldugunda medya YUKLEYENDEN BASKA
--    HERKESE 403 doner ve bu TEK CIHAZDA TEST EDILSE GORULMEZ (kapi
--    `sahip != userID && ...` seklinde kisa devre yapar). Bu sinif hata
--    turu 75b'de (akistaki tum gorseller) ve turu 77'de (hikaye medyasi)
--    SAHAYA CIKTI. Bu turda RISK YAPISAL OLARAK KALDIRILDI:
--      · kayitli kisi  -> `users.avatar_media_id` (dal (b) ZATEN herkese acik)
--      · kayitsiz kisi -> ADIN BAS HARFI ile renkli avatar (medya YOK)
--    ⚠️ YAPMA: bu tabloya `media_id` sutunu ekleme.
--
-- ⚠️ VERI SILINMEZ politikasi: etkinlik silinirse kadro da CASCADE ile gider —
--    bu bir ISTISNA DEGIL, ALT VERIDIR (etkinliksiz kadro satirinin anlami yok).
--    Etkinligin kendisi zaten silinmiyor; `durum='silindi'` ile gizleniyor.

CREATE TABLE IF NOT EXISTS etkinlik_kadro (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    etkinlik_id  UUID NOT NULL REFERENCES etkinlikler(id) ON DELETE CASCADE,

    -- ⚠️ Kayitli kullaniciya BAGLANABILIR ama ZORUNLU DEGIL (bkz. ust serh).
    --    Kullanici hesabi silinirse kadro satiri KALIR, yalniz bag kopar —
    --    etkinligin gecmisi bozulmasin.
    user_id      UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Sahnedeki kisinin adi. `user_id` doluyken de tutulur: kullanici adini
    -- degistirse bile ETKINLIK ANINDAKI ad korunur (afis dogru kalir).
    ad           TEXT NOT NULL,

    -- Sanatci / Oyuncu / Konusmaci / DJ / Sunucu ... SERBEST METIN.
    -- ⚠️ CHECK KOYULMADI: yeni bir rol (ornegin "Stand-up") migration
    --    GEREKTIRMEMELI. Ayni gerekce `reports.hedef_tur`de de gecerliydi (014).
    rol          TEXT NOT NULL DEFAULT '',

    sira         INTEGER NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ⚠️ AD TABLO ONEKLI (bu projede `idx_isletme_kategori` cakismasi yasandi).
CREATE INDEX IF NOT EXISTS idx_kadro_etkinlik
    ON etkinlik_kadro (etkinlik_id, sira, created_at);

-- Bir kisi ayni etkinlikte IKI KEZ listelenmesin (yalniz KAYITLI kisiler icin;
-- kayitsizlarda ad tekrari serbest — iki farkli "Ahmet" olabilir).
CREATE UNIQUE INDEX IF NOT EXISTS idx_kadro_tek_kullanici
    ON etkinlik_kadro (etkinlik_id, user_id) WHERE user_id IS NOT NULL;
