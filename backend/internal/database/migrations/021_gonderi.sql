-- 021_gonderi.sql — GONDERI + BEGENI + YORUM (ana sayfa akisinin veri modeli).
--
-- ⚠️ ADDITIVE. ⚠️ `messages.type` CHECK'ine DOKUNULMAZ (015'in serhi).
--
-- ⚠️⚠️ KULLANICI KARARI (8 Agu): **VERI SILINMEZ.** Bu semada yas tabanli silme
--    YOKTUR. Silme yalnizca: sahibi siler, hesap silinir (KVKK), yasal kaldirma
--    karari, ya da moderasyon (CSAM/yasa disi).
--    ⚠️ YAPMA: buraya `expires_at` / otomatik temizlik ekleme.

-- ============ 1) GONDERI ============
CREATE TABLE IF NOT EXISTS posts (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 'foto'  : 1-10 gorsel (media_ids)
    -- 'video' : tek video
    -- 'reels' : dikey kisa video (AYRI sekmede + akista)
    -- 'yazi'  : yalniz metin
    -- ⚠️ CHECK burada TEK SEFER tanimlanir; sonraki migration'lar DOKUNMAYACAK
    --    (015'te `messages_type_check` ile yasadigimiz tuzagin ayni sinifi).
    tur        TEXT NOT NULL CHECK (tur IN ('foto','video','reels','yazi')),

    metin      TEXT NOT NULL DEFAULT '',   -- aciklama / caption

    -- ⚠️ MEDYA DIZISI: `posts_media` ara tablosu YERINE UUID[] secildi.
    --    Gerekce: akis sorgusu N gonderi cekerken her biri icin JOIN + sira
    --    korumasi gerekirdi; dizi SIRAYI DOGAL olarak korur ve tek satirda gelir.
    --    ⚠️ Bedeli: FK yok — silinen medya id'si dizide KALIR. Istemci o id icin
    --       404/410 alir ve "bu icerik kaldirildi" cizer (mesaj tarafiyla AYNI
    --       davranis). Kabul edilen bir odun.
    media_ids  UUID[] NOT NULL DEFAULT '{}',

    -- Sayaclar DENORMALIZE (akista her gonderi icin count(*) tam tarama olurdu).
    begeni_sayisi  INT NOT NULL DEFAULT 0,
    yorum_sayisi   INT NOT NULL DEFAULT 0,
    goruntulenme   INT NOT NULL DEFAULT 0,

    -- Moderasyon / silme
    durum      TEXT NOT NULL DEFAULT 'yayinda'
               CHECK (durum IN ('yayinda','silindi','karantina')),

    -- Yorumlara kapali gonderi (yazar karari)
    yorum_kapali BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Profil sekmesi: bir kullanicinin gonderileri, yeniden eskiye.
CREATE INDEX IF NOT EXISTS idx_posts_yazar
    ON posts (author_id, created_at DESC) WHERE durum = 'yayinda';
-- ⚠️ AKIS SORGUSU: `WHERE author_id = ANY(takip) ORDER BY created_at DESC`.
--    Bu index (created_at DESC) siralamayi index'ten karsilar; `author_id`
--    filtresi bitmap ile uygulanir.
CREATE INDEX IF NOT EXISTS idx_posts_akis
    ON posts (created_at DESC) WHERE durum = 'yayinda';
-- Reels sekmesi AYRI (kendi kaydirma akisi).
CREATE INDEX IF NOT EXISTS idx_posts_reels
    ON posts (created_at DESC) WHERE durum = 'yayinda' AND tur = 'reels';

-- ============ 2) BEGENI ============
-- ⚠️ Ayri tablo (sayac degil): "ben begendim mi" sorusu ve begenenler listesi
--    icin gerekli. Sayac ise `posts.begeni_sayisi`nda denormalize.
CREATE TABLE IF NOT EXISTS post_likes (
    post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);
-- "Bu kullanici neleri begendi" + akista toplu "begendim mi" sorgusu.
CREATE INDEX IF NOT EXISTS idx_likes_kullanici ON post_likes (user_id, created_at DESC);

-- ============ 3) YORUM ============
CREATE TABLE IF NOT EXISTS post_comments (
    id         BIGSERIAL PRIMARY KEY,
    post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- ⚠️ Yanit: TEK SEVIYE (Instagram deseni). Sinirsiz ic ice yorum hem arayuzde
    --    okunmaz hem sorguyu ozyinelemeli yapar.
    parent_id  BIGINT REFERENCES post_comments(id) ON DELETE CASCADE,
    metin      TEXT NOT NULL,
    begeni_sayisi INT NOT NULL DEFAULT 0,
    durum      TEXT NOT NULL DEFAULT 'yayinda'
               CHECK (durum IN ('yayinda','silindi','karantina')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_yorum_gonderi
    ON post_comments (post_id, created_at) WHERE durum = 'yayinda' AND parent_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_yorum_yanit
    ON post_comments (parent_id, created_at) WHERE durum = 'yayinda' AND parent_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS comment_likes (
    comment_id BIGINT NOT NULL REFERENCES post_comments(id) ON DELETE CASCADE,
    user_id    UUID   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (comment_id, user_id)
);

-- ============ 4) KAYDEDILENLER ============
CREATE TABLE IF NOT EXISTS post_saves (
    post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, post_id)
);

-- ============ 5) MEDYA BAGLANTISI ============
-- ⚠️ `media_assets.kind` CHECK'ine 'gonderi' EKLENMEZ — mevcut degerler
--    (image/video/audio/document/avatar) gonderi medyasi icin de DOGRU.
--    Gonderi medyasi 'image'/'video' kind'iyla yuklenir; sahiplik `owner_id`de.
--    ⚠️ YAPMA: yeni kind ekleyip iki yerde tip listesi tutma (drift eder).

-- ============ 6) SIKAYET TURLERI ============
-- ⚠️ `reports.hedef_tur` SERBEST METIN (014'un bilincli karari) — 'gonderi',
--    'yorum', 'reels' icin migration GEREKMEZ. Yalniz uygulama katmanindaki
--    beyaz liste genisletilir.
