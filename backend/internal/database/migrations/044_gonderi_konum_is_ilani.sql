-- ⚠️⚠️⚠️ TURU 90 — GONDERIDE KONUM + IS ILANI BASVURUSU.
--
-- Kullanici emirleri:
--   · *"normal paylasimda konum paylasamiyoruz, bunu eklememissin"*
--   · *"is ilani da olacak, HERKES verebilmeli, normal kullanicilar
--      haricinde BASVURU YAPILABILMELI"*

-- ═══════════ 1) GONDERIDE KONUM ═══════════
--
-- ⚠️ CLAUDE.md'de bu ACIKCA "durust sinir" olarak yaziliydi: *"gonderide
--    KONUM yok — `posts`ta enlem/boylam sutunu yok; dugme var ama durust
--    'yakinda' diyor (yarim baglamak yerine)"*. Kullanici artik istiyor.
--
-- ⚠️ SOHBETTEKI konum paylasimi (turu 81) mesaj govdesinde METIN olarak
--    tasiniyor; gonderide AYRI SUTUN secildi cunku ileride "yakinimdaki
--    gonderiler" sorgusu ancak sayisal sutunla yapilabilir.
-- ⚠️ `0,0` = KONUM YOK (Gine Korfezi'nde gonderi paylasan kullanici YOK).
--    Ayri bir `konum_var BOOLEAN` sutunu, iki alanin DRIFT ETMESI riskini
--    getirirdi (bu projede "ayni bilginin iki kopyasi" alti kez zarar verdi).
-- ⚠️ `konum_ad`: kullaniciya GOSTERILEN metin ("Gebze, Kocaeli"). Istemci
--    cihazin geocoder'indan uretir; sunucu DOGRULAMAZ (yalnizca kirpar).

ALTER TABLE posts ADD COLUMN IF NOT EXISTS enlem     DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS boylam    DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS konum_ad  TEXT NOT NULL DEFAULT '';

-- ═══════════ 2) IS ILANI BASVURUSU ═══════════
--
-- ⚠️ IS ILANI ICIN YENI TABLO ACILMADI: `ilanlar` (030) zaten `tur TEXT`
--    (CHECK YOK) + `ozellikler JSONB` tasiyor ve 030'un kendi serhi diyor ki
--    *"JSONB ile yeni tur SIFIR sema degisikligi"*. "is" turu yalnizca Go
--    tarafindaki `Turler` dizisine eklenir.
--    ⚠️ 030:14 ACIKCA yaziyor: "YAPMA: hizmetler diye ikinci bir tablo acma".
--
-- BASVURU ise GERCEKTEN yeni bir iliskidir (kim, hangi ilana, ne zaman) ve
-- `ilan_favoriler` ile AYNI sekilde ayri bir tabloyu hak eder.
--
-- ⚠️ `UNIQUE(ilan_id, user_id)`: ayni kisi ayni ilana IKI KEZ basvuramaz.
--    `reports` tablosunun (014) `UNIQUE(reporter_id,hedef_tur,hedef_id)`
--    deseniyle ayni gerekce: tekrar basvuru satir biriktirir ve ilan
--    sahibinin listesini kullanilamaz hale getirir.
-- ⚠️ `durum` SERBEST METIN (CHECK YOK): yeni durumlar (`goruldu`,
--    `gorusme`, `olumsuz`) migration GEREKTIRMESIN. CHECK bu projede IKI KEZ
--    sevk engeli uretti (036 `ai_istekleri.durum`, 037 `media_assets.kind`);
--    `go build`+`go vet`+`flutter analyze` UCU DE temiz gecer, hata YALNIZ
--    gercek Postgres'te cikar. Beyaz liste Go tarafinda.
-- ⚠️ SATIR SILINMEZ (veri politikasi): geri cekme `durum='geri_cekildi'`.

CREATE TABLE IF NOT EXISTS ilan_basvurular (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ilan_id    UUID NOT NULL REFERENCES ilanlar(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    -- Basvuranin kisa notu / on yazi.
    not_metin  TEXT NOT NULL DEFAULT '',
    -- 'bekliyor' | 'goruldu' | 'olumlu' | 'olumsuz' | 'geri_cekildi'
    durum      TEXT NOT NULL DEFAULT 'bekliyor',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (ilan_id, user_id)
);

-- ⚠️ IKI YONLU okuma: ilan sahibi "ilanima kimler basvurdu", kullanici
--    "ben nerelere basvurdum" diye sorar. Iki index de GEREKLI.
CREATE INDEX IF NOT EXISTS idx_basvuru_ilan
    ON ilan_basvurular (ilan_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_basvuru_user
    ON ilan_basvurular (user_id, created_at DESC);
