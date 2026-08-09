-- 029_etkinlik.sql — TURU 77: ETKINLIKLER.
--
-- Kullanici emri: "etkinlikler olacak, bu etkinlik soldaki menuye tikladiginda
-- ekranda olacak".
--
-- ⚠️ ADDITIVE.
--
-- ⚠️⚠️ GECMIS ETKINLIK **SILINMEZ** (veri politikasi — kullanici karari 8 Agu).
--    "Gecmis" bir DURUM DEGIL, bir SORGU SUZGECIDIR (`baslangic < now()`).
--    Boylece "Geçmiş etkinlikler" sekmesi EK IS GEREKTIRMEDEN calisir ve
--    duzenleyen gecmis etkinliklerini/katilimcilarini gorebilir.
--    ⚠️ YAPMA: `expires_at` ekleme, yas tabanli supurge yazma.

CREATE TABLE IF NOT EXISTS etkinlikler (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    olusturan_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    baslik       TEXT NOT NULL,
    aciklama     TEXT NOT NULL DEFAULT '',
    -- Kategori ANAHTARI ('konser','spor','egitim'...). CHECK YOK: yeni kategori
    -- migration GEREKTIRMESIN (turu 74 `reports.hedef_tur` karari).
    kategori     TEXT NOT NULL DEFAULT 'diger',
    baslangic    TIMESTAMPTZ NOT NULL,
    -- Bitis OPSIYONEL: cogu etkinlikte "saat 20:00'de basliyor" yeter.
    bitis        TIMESTAMPTZ,
    konum        TEXT NOT NULL DEFAULT '',
    il           TEXT NOT NULL DEFAULT '',
    ilce         TEXT NOT NULL DEFAULT '',
    enlem        DOUBLE PRECISION NOT NULL DEFAULT 0,
    boylam       DOUBLE PRECISION NOT NULL DEFAULT 0,
    -- ⚠️ `posts.media_ids` ile AYNI karar: ara tablo yerine dizi (sira dogal
    --    korunur, tek satirda gelir). FK yok — silinen medya id'si dizide kalir
    --    ve istemci "kaldirildi" cizer.
    -- ⚠️ NOT NULL + '{}' varsayilan: `nil` dilim SQL NULL gonderir ve NOT NULL
    --    sutunu PATLATIR (turu 75b'de HER YAZI GONDERISI bu yuzden 500 donuyordu).
    media_ids    UUID[] NOT NULL DEFAULT '{}',
    ucretsiz     BOOLEAN NOT NULL DEFAULT true,
    -- ⚠️⚠️ KURUS cinsinden BIGINT. Denetim bulgusu (turu 77): fiyat birimi
    --    dikeyler arasinda DRIFT ediyordu (etkinlik INT/TL, ilan BIGINT/kurus,
    --    urun BIGINT/kurus). Uc yerde uc farkli birim, er ya da gec yanlis
    --    bicimlendirilmis bir fiyat demektir.
    -- ⚠️ INT KULLANILMAZ: kurus cinsinden INT 21,4 milyon TL de TASAR ve
    --    emlak ilanlari bunu asar. Simdi BIGINT yapmak bedava; sonra
    --    migration gerektirir.
    fiyat_kurus  BIGINT NOT NULL DEFAULT 0,
    -- 0 = sinirsiz kontenjan.
    kontenjan    INTEGER NOT NULL DEFAULT 0,
    durum        TEXT NOT NULL DEFAULT 'yayinda'
                 CHECK (durum IN ('yayinda','iptal','silindi')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- "Yaklasan etkinlikler" ve "gecmis etkinlikler" ayni index'ten karsilanir.
CREATE INDEX IF NOT EXISTS idx_etkinlik_zaman
    ON etkinlikler (baslangic) WHERE durum = 'yayinda';
CREATE INDEX IF NOT EXISTS idx_etkinlik_kategori
    ON etkinlikler (kategori, baslangic) WHERE durum = 'yayinda';
CREATE INDEX IF NOT EXISTS idx_etkinlik_olusturan
    ON etkinlikler (olusturan_id, baslangic DESC);

-- ============ KATILIM (RSVP) ============
--
-- ⚠️ (etkinlik_id, user_id) BIRINCIL ANAHTAR: ayni kisi iki kez katilamaz.
--    Aksi halde kontenjan sayimi YALAN soylerdi.
-- ⚠️ Katilimdan VAZGECME satiri SILMEZ, `durum='vazgecti'` yazar (veri
--    politikasi) — ayrica duzenleyen "kac kisi vazgecti" bilgisini gorebilir.
CREATE TABLE IF NOT EXISTS etkinlik_katilim (
    etkinlik_id UUID NOT NULL REFERENCES etkinlikler(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    durum       TEXT NOT NULL DEFAULT 'katiliyor'
                CHECK (durum IN ('katiliyor','ilgileniyor','vazgecti')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (etkinlik_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_etkinlik_katilim_kullanici
    ON etkinlik_katilim (user_id) WHERE durum <> 'vazgecti';
