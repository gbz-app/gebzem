-- 020_sosyal.sql — SOSYAL KATMAN TEMELI: takip + profil alanlari.
--
-- ⚠️ NUMARA: 014 reports · 015 medya · 016 medya index (turu 74).
--    Sosyal katman 020'den baslar (arada bosluk BILEREK: medya 2. dalgasi
--    017-019'u kullanabilsin).
--
-- ⚠️ ADDITIVE: mevcut hicbir sutun daraltilmaz/kaldirilmaz.
-- ⚠️ `messages.type` CHECK'ine DOKUNULMAZ — 015'te TUM gelecek tipler tek seferde
--    tanimlandi. Iki migration kisiti birbirinden habersiz yeniden kurarsa sonra
--    calisan oncekinin tiplerini SILER (015'in serhi).

-- ============ 1) TAKIP ============
-- ⚠️ `blocks` ile AYRI: engelleme mesajlasmayi keser, takip iceriktir. Ama
--    engelleme takibi de DUSURUR (asagidaki tetikleyici yerine uygulama katmani
--    yapar — tetikleyici DB'ye gizli davranis gomer, hata ayiklamasi zorlasir).
CREATE TABLE IF NOT EXISTS follows (
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Gizli hesapta takip ONAY bekler.
    durum       TEXT NOT NULL DEFAULT 'onayli' CHECK (durum IN ('onayli','bekliyor')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id),
    -- ⚠️ Kendini takip ETMEYI DB seviyesinde engelle (uygulama katmani da kontrol
    --    eder; iki kapi cunku sayaclar bozulursa geri donmek pahali).
    CONSTRAINT follows_kendini_takip CHECK (follower_id <> followee_id)
);

-- "Beni kimler takip ediyor" (profil ekrani + akis fan-out'u)
CREATE INDEX IF NOT EXISTS idx_follows_followee
    ON follows (followee_id, created_at DESC) WHERE durum = 'onayli';
-- "Ben kimi takip ediyorum" (akis sorgusu)
CREATE INDEX IF NOT EXISTS idx_follows_follower
    ON follows (follower_id, created_at DESC) WHERE durum = 'onayli';
-- Bekleyen istekler (gizli hesap onay kuyrugu)
CREATE INDEX IF NOT EXISTS idx_follows_bekleyen
    ON follows (followee_id, created_at DESC) WHERE durum = 'bekliyor';

-- ============ 2) PROFIL ALANLARI ============
-- ⚠️ SAYACLAR DENORMALIZE: `count(*)` her profil acilisinda tam tarama demek.
--    Uygulama katmani takip/birak islemlerinde AYNI TRANSACTION'da gunceller.
--    ⚠️ Kaymaya karsi: admin panelinde yeniden hesaplama yolu olacak (sayac
--       tutarsizligi urunu bozmaz, yalniz sayi yanlis gorunur).
ALTER TABLE users ADD COLUMN IF NOT EXISTS takipci_sayisi INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS takip_sayisi   INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gonderi_sayisi INT NOT NULL DEFAULT 0;

-- Gizli hesap: gonderileri yalniz onayli takipciler gorur.
ALTER TABLE users ADD COLUMN IF NOT EXISTS gizli_hesap BOOLEAN NOT NULL DEFAULT false;

-- Profil baglantisi (biyografideki tek link).
ALTER TABLE users ADD COLUMN IF NOT EXISTS baglanti TEXT NOT NULL DEFAULT '';

-- ============ 3) BILDIRIMLER ============
-- ⚠️ WS ile ANLIK gonderilir AMA kalici da tutulur: `ws.goOffline()` yuzunden
--    (turu 33: kilit ekraninda arama calsin diye) arka planda WS KAPALI oldugundan
--    olay KAYBOLABILIR. Bildirim ekrani DB'den okur.
CREATE TABLE IF NOT EXISTS bildirimler (
    id         BIGSERIAL PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- alici
    aktor_id   UUID REFERENCES users(id) ON DELETE CASCADE,          -- eylemi yapan
    tur        TEXT NOT NULL,   -- takip | takip_istegi | begeni | yorum | bahsetme
    hedef_tur  TEXT NOT NULL DEFAULT '', -- gonderi | reels | yorum
    hedef_id   TEXT NOT NULL DEFAULT '',
    okundu     BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bildirim_kullanici
    ON bildirimler (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bildirim_okunmamis
    ON bildirimler (user_id) WHERE NOT okundu;
