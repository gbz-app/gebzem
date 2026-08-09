-- 026_story.sql — TURU 76b: HIKAYE (story).
--
-- ⚠️ ADDITIVE. Mevcut hicbir tabloya/kisita DOKUNULMAZ.
--
-- ═══════════ EN ONEMLI KARAR: "24 SAAT" GORUNURLUKTUR, SILME DEGIL ═══════════
--
-- Hikaye tanimi geregi 24 saat sonra KAYBOLUR. Alisilmis uygulama satiri
-- `expires_at` ile isaretleyip bir sup rge isiyle SILMEKTIR.
--
-- ⚠️⚠️ BU PROJEDE VERI SILINMEZ (kullanici karari, 8 Agu — CLAUDE.md):
--    *"90 gunluk silme vs olmasin, sakan insanlarin verisini silmek yok,
--      surekli veri olacak buyuyecek"*. Hicbir semada yas tabanli silme YOK.
--
-- COZUM: satir KALICIDIR; "kaybolma" YALNIZCA SORGU SUZGECIYLE olur
--        (`created_at > now() - interval '24 hours'`).
--        Boylece hem urun davranisi dogru (24 saat sonra gorunmez) hem veri
--        korunur (ileride "hikaye arsivi" ozelligi ek is GEREKTIRMEZ).
-- ⚠️ YAPMA: bu tabloya `expires_at` ekleme.
-- ⚠️ YAPMA: yas tabanli DELETE/sup rge isi yazma.
-- ⚠️ Index `created_at DESC` uzerinde: 24 saat suzgeci indexten karsilanir,
--    tablo buyuse de sorgu YAVASLAMAZ.

CREATE TABLE IF NOT EXISTS stories (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- ⚠️ Tek medya (Instagram deseni). Coklu medya hikayesi = ard arda AYRI
    --    satirlar; boylece her parca ayri izlenme/ilerleme cubugu alir.
    media_id   UUID NOT NULL,
    -- 'image' | 'video'. `media_assets.kind`in KOPYASI DEGIL, gonderi
    -- tarafindaki `media_kinds` ile ayni amac: istemci ne cizecegini
    -- EK SORGU OLMADAN bilsin.
    -- ⚠️ CHECK YOK: ileride 'text' hikayesi eklenirse migration GEREKMESIN
    --    (turu 74'un `reports.hedef_tur` karari).
    kind       TEXT NOT NULL DEFAULT 'image',
    metin      TEXT NOT NULL DEFAULT '',
    durum      TEXT NOT NULL DEFAULT 'yayinda'
               CHECK (durum IN ('yayinda','silindi')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- "Bu kullanicinin AKTIF hikayeleri" + "takip ettiklerimin aktif hikayeleri"
-- sorgularinin ikisi de bu index'ten karsilanir.
CREATE INDEX IF NOT EXISTS idx_story_kullanici
    ON stories (user_id, created_at DESC) WHERE durum = 'yayinda';
CREATE INDEX IF NOT EXISTS idx_story_zaman
    ON stories (created_at DESC) WHERE durum = 'yayinda';

-- ============ IZLENME ============
-- Halkanin RENKLI mi GRI mi cizilecegini belirler + yazara "kimler izledi".
--
-- ⚠️ (story_id, user_id) BIRINCIL ANAHTAR: ayni kisi tekrar izlerse YENI SATIR
--    ACILMAZ. Aksi halde populer bir hikaye milyonlarca satir uretirdi.
-- ⚠️ Bu tablo da SILINMEZ (veri politikasi).
CREATE TABLE IF NOT EXISTS story_views (
    story_id   UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (story_id, user_id)
);

-- "Bu hikayeyi kimler izledi" (yazara gosterilir).
CREATE INDEX IF NOT EXISTS idx_story_izlenme ON story_views (story_id);
