-- 031_urun_ai.sql — TURU 77: ISLETME URUNLERI/MENU + AI ISTEKLERI.
--
-- Kullanici emri: "isletmeler urunlerini yukleyebilecek ya da ChatGPT
-- yardimiyla AI gorsel, AI menu, AI ile tek tek fotograftan problemleri ...".
--
-- ⚠️ ADDITIVE.
--
-- ⚠️⚠️ ISLETME PROFILI TABLOSU BURADA **YARATILMAZ**. `isletmeler` tablosu
--    migration 028'de kuruldu ve TEK KAYNAKTIR. Ikinci bir profil tablosu
--    acilsaydi `hesap_turu='isletme'` olan kullanicinin bir tabloda kaydi
--    olur digerinde olmazdi (turu 77 denetim bulgusu Ç1).
--    ⚠️ YAPMA: `isletme_profilleri` diye ikinci bir tablo acma.

CREATE TABLE IF NOT EXISTS isletme_urunleri (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ⚠️ FK `users(id)` — `isletmeler(user_id)` DEGIL. Sebep: kullanici
    --    kisisel hesaba donerse `isletmeler` satiri KALIR (silinmiyor) ama
    --    ileride farkli bir modele gecilirse urunler yetim kalmasin.
    isletme_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ad           TEXT NOT NULL,
    aciklama     TEXT NOT NULL DEFAULT '',
    -- Menu bolumu ("Ana Yemekler", "Tatlilar", "Icecekler") — SERBEST METIN.
    -- ⚠️ Sabit liste YAPILMADI: bir kuafor "Sac", bir market "Kahvalti" der.
    bolum        TEXT NOT NULL DEFAULT '',
    -- ⚠️⚠️ KURUS + BIGINT — etkinlik ve ilan ile AYNI birim (turu 77 denetim
    --    bulgusu: uc dikeyde uc farkli birim = yanlis bicimlendirilmis fiyat).
    fiyat_kurus  BIGINT NOT NULL DEFAULT 0,
    -- ⚠️ NOT NULL + '{}': `nil` dilim SQL NULL gonderir ve NOT NULL sutunu
    --    PATLATIR (turu 75b sevk engeli).
    media_ids    UUID[] NOT NULL DEFAULT '{}',
    -- Menude gosterim sirasi (kucuk once).
    sira         INTEGER NOT NULL DEFAULT 0,
    durum        TEXT NOT NULL DEFAULT 'yayinda'
                 CHECK (durum IN ('yayinda','tukendi','kaldirildi')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ⚠️ Index adinda TABLO ONEKI: 028'de `idx_isletme_kategori` ZATEN `isletmeler`
--    uzerinde yaratildi. Ayni adi burada kullansaydik `CREATE INDEX IF NOT
--    EXISTS` SESSIZCE NO-OP olurdu ve index yanlis tabloya ait sanilirdi
--    (turu 77 denetim bulgusu Ç2).
CREATE INDEX IF NOT EXISTS idx_urun_isletme
    ON isletme_urunleri (isletme_id, sira, created_at) WHERE durum <> 'kaldirildi';

-- ============ AI ISTEKLERI ============
--
-- ⚠️⚠️ AI TAMAMEN BIR ENV KAPISININ ARKASINDA (`OPENAI_API_KEY`). Anahtar
--    yoksa uclar 503 doner ve arayuzde ozellik HIC GORUNMEZ. Bu, projedeki
--    medya (R2) kapisinin BIREBIR AYNISIDIR.
--
-- ⚠️⚠️ KOTA TABLOSU: AI UCRETLI. Kota olmadan tek kullanici bir gecede
--    faturayi patlatabilir. Gunluk sayim BU TABLODAN yapilir.
-- ⚠️ Satirlar SILINMEZ (veri politikasi); gunluk sayim `created_at` suzgeciyle.
CREATE TABLE IF NOT EXISTS ai_istekleri (
    id         BIGSERIAL PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- gorsel | menu | danisma
    tur        TEXT NOT NULL,
    -- Girdi ozeti (denetim izi; ham fotograf SAKLANMAZ).
    girdi      TEXT NOT NULL DEFAULT '',
    -- Modelin dondurdugu metin/JSON.
    sonuc      TEXT NOT NULL DEFAULT '',
    durum      TEXT NOT NULL DEFAULT 'tamam'
               CHECK (durum IN ('tamam','hata')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Gunluk kota sayimi bu index'ten karsilanir.
CREATE INDEX IF NOT EXISTS idx_ai_kota
    ON ai_istekleri (user_id, created_at DESC);
