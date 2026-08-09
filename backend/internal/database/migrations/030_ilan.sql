-- 030_ilan.sql — TURU 77: ILANLAR (+ HIZMETLER).
--
-- Kullanici emri: "ilanlar olacak dostum sahibinden gibi araba ev 2.el alim
-- satim vs bunlar olacak" + "hizmetler kategorisi olacak".
--
-- ⚠️ ADDITIVE.
--
-- ═══════════ KARAR: HIZMET **AYRI DIKEY DEGIL**, BIR ILAN TURU ═══════════
--
-- "Tadilat yapiyorum", "ozel ders veriyorum" bir ILANDIR: basligi, aciklamasi,
-- fiyati, konumu, fotografi var ve satici ile MESAJLASILIR. Ayri bir tablo +
-- ayri uclar + ayri ekranlar acmak AYNI ISI IKI KEZ yazmak olurdu (bu projede
-- "iki kopya DRIFT eder" dersi turu 72b/H'de yazili).
-- ⚠️ YAPMA: `hizmetler` diye ikinci bir tablo acma.
-- ⚠️ NOT: `isletmeler.kategori='hizmet'` BAMBASKA bir seydir (bir ISLETME
--    profili). Menude "Hizmetler" karti ILAN listesine (tur='hizmet'),
--    "Isletmeler" karti isletme rehberine gider.

CREATE TABLE IF NOT EXISTS ilanlar (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sahibi_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- vasita | emlak | ikinci_el | hizmet
    -- ⚠️ CHECK YOK: yeni tur (is ilani, hayvan...) migration GEREKTIRMESIN
    --    (turu 74 `reports.hedef_tur` karari, 015 CHECK tuzagindan kacinma).
    tur          TEXT NOT NULL DEFAULT 'ikinci_el',
    kategori     TEXT NOT NULL DEFAULT '',
    baslik       TEXT NOT NULL,
    aciklama     TEXT NOT NULL DEFAULT '',
    -- ⚠️⚠️ KURUS + BIGINT. INT kurus cinsinden 21,4 milyon TL'de TASAR ve
    --    emlak ilanlari bunu RAHATLIKLA asar (bir daire = 500 milyon kurus).
    --    Etkinlik ve urun tablolari da AYNI birimi kullanir — dikeyler arasi
    --    birim driftini onlemek icin (turu 77 denetim bulgusu).
    fiyat_kurus  BIGINT NOT NULL DEFAULT 0,
    para_birimi  TEXT NOT NULL DEFAULT 'TRY',
    -- Fiyat "belirtilmemis" olabilir (hizmetlerde sik): 0 + bu bayrak.
    fiyat_gizli  BOOLEAN NOT NULL DEFAULT false,
    il           TEXT NOT NULL DEFAULT '',
    ilce         TEXT NOT NULL DEFAULT '',
    -- ⚠️ NOT NULL + '{}': `nil` dilim SQL NULL gonderir ve NOT NULL sutunu
    --    PATLATIR (turu 75b'de HER YAZI GONDERISI bu yuzden 500 donuyordu).
    media_ids    UUID[] NOT NULL DEFAULT '{}',
    -- ⚠️⚠️ TIPE OZEL ALANLAR **JSONB** — ayri tablolar DEGIL.
    --    Vasita: {marka, model, yil, km, vites, yakit}
    --    Emlak:  {m2, oda, kat, isitma, esyali}
    --    Ayri tablo secilseydi her tur icin: yeni tablo + yeni JOIN + yeni
    --    handler dali + yeni migration. Dort tur = dort kat is ve her yeni
    --    tur yine migration isterdi. JSONB ile yeni tur SIFIR sema degisikligi.
    -- ⚠️ Bedeli: tip guvenligi yok ve aralik sorgusu (yil > 2015) index'siz.
    --    Ilk surumde YALNIZ ESITLIK suzgeci destekleniyor (`@>` + GIN).
    ozellikler   JSONB NOT NULL DEFAULT '{}'::jsonb,
    durum        TEXT NOT NULL DEFAULT 'yayinda'
                 CHECK (durum IN ('yayinda','satildi','kaldirildi')),
    goruntulenme INTEGER NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ⚠️ SATILAN/KALDIRILAN ILAN SILINMEZ, `durum` degisir (veri politikasi).
--    Kismi index'ler yalniz yayindakileri tarar.
CREATE INDEX IF NOT EXISTS idx_ilan_liste
    ON ilanlar (tur, created_at DESC) WHERE durum = 'yayinda';
CREATE INDEX IF NOT EXISTS idx_ilan_kategori
    ON ilanlar (kategori, created_at DESC) WHERE durum = 'yayinda';
CREATE INDEX IF NOT EXISTS idx_ilan_konum
    ON ilanlar (il, ilce) WHERE durum = 'yayinda';
CREATE INDEX IF NOT EXISTS idx_ilan_sahibi
    ON ilanlar (sahibi_id, created_at DESC);
-- Fiyat araligi suzgeci icin.
CREATE INDEX IF NOT EXISTS idx_ilan_fiyat
    ON ilanlar (fiyat_kurus) WHERE durum = 'yayinda';
-- ⚠️ GIN: `ozellikler @> '{"marka":"Ford"}'` esitlik suzgeci icin.
CREATE INDEX IF NOT EXISTS idx_ilan_ozellik
    ON ilanlar USING GIN (ozellikler);

-- ============ FAVORILER ============
--
-- ⚠️⚠️ FAVORI TABLOSU **YALNIZCA** "Favorilerim" EKRANI ILE BIRLIKTE anlamli.
--    Bu projede `post_saves` yazilip LISTELEYEN UC/EKRAN YAZILMAMISTI
--    ("kara delik", turu 75b). Ayni hataya dusmemek icin bu tablo ile birlikte
--    `GET /users/me/ilan-favoriler` ucu VE "Favorilerim" ekrani AYNI TURDA yazildi.
CREATE TABLE IF NOT EXISTS ilan_favoriler (
    ilan_id    UUID NOT NULL REFERENCES ilanlar(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (ilan_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_ilan_favori_kullanici
    ON ilan_favoriler (user_id, created_at DESC);
