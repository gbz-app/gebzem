-- 014: SIKAYET (report) tablosu.
--
-- ⚠️ NEDEN ZORUNLU: App Store Review Guideline 1.2 (kullanici uretimi icerik) bir
-- uygulamada UC seyi birlikte sart kosuyor: icerik filtreleme, KULLANICIYI ENGELLEME
-- ve TACIZ EDICI ICERIGI BILDIRME. `blocks` tablosu 001'de zaten vardi ama SIKAYET
-- yolu hic yoktu. Sohbete medya ve herkese acik gonderi eklemeden ONCE kurulmali.
--
-- ⚠️ ADDITIVE: mevcut hicbir tabloya dokunmaz, mevcut sorgular etkilenmez.
--
-- `hedef_tur`: neyin sikayet edildigi. Bugun 'kullanici' ve 'mesaj'; medya/gonderi/
-- reels geldiginde AYNI tabloya 'medya','gonderi','reels','kanal' eklenecek —
-- bu yuzden CHECK degil, serbest metin + index (yeni tur eklemek migration GEREKTIRMEZ).
-- ⚠️ YAPMA: buraya CHECK constraint koyma (her yeni icerik tipi migration'a mal olur).
--
-- `hedef_id` TEXT: kullanici id'si UUID, mesaj id'si BIGINT — tek sutunda tutmak icin
-- metin. Sorgular her zaman `hedef_tur` ile birlikte filtreler.
CREATE TABLE IF NOT EXISTS reports (
    id          BIGSERIAL PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hedef_tur   TEXT NOT NULL,              -- kullanici | mesaj | (ileride: medya, gonderi, reels, kanal)
    hedef_id    TEXT NOT NULL,
    sebep       TEXT NOT NULL DEFAULT '',   -- spam | taciz | cinsel | siddet | diger
    aciklama    TEXT NOT NULL DEFAULT '',
    durum       TEXT NOT NULL DEFAULT 'yeni' CHECK (durum IN ('yeni','incelendi','islem_yapildi','reddedildi')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- ⚠️ AYNI kullanici AYNI hedefi bir kez sikayet edebilir (spam koruma).
    --    Tekrar sikayet 200 doner ama yeni satir ACMAZ (ON CONFLICT DO NOTHING).
    UNIQUE (reporter_id, hedef_tur, hedef_id)
);

-- Admin kuyrugu: bekleyen sikayetler en yeniden eskiye.
CREATE INDEX IF NOT EXISTS reports_durum_idx ON reports (durum, created_at DESC);
-- "Bu hedef kac kez sikayet edildi" — otomatik onceliklendirme icin.
CREATE INDEX IF NOT EXISTS reports_hedef_idx ON reports (hedef_tur, hedef_id);
