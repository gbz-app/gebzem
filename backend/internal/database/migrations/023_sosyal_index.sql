-- 023_sosyal_index.sql — TURU 75b DENETIM BULGULARI: eksik/yanlis indeksler.
--
-- ⚠️ 021 ve 022 GERIYE DONUP DEGISTIRILMEDI: migration'lar bir kez calisir ve
--    mevcut kurulumlarda ZATEN uygulanmis olabilir; ayrica 015'in dersi —
--    "ayni kisiti iki migration yeniden kurmasin".
-- ⚠️ ADDITIVE, yalniz index. Veri/kisit degistirmez.

-- ============ 1) YORUM LISTESI ============
-- ⚠️⚠️ 021'deki iki index KISMI ve ikisi de `parent_id` yuklemi tasiyor:
--        idx_yorum_gonderi ... WHERE durum='yayinda' AND parent_id IS NULL
--        idx_yorum_yanit   ... WHERE durum='yayinda' AND parent_id IS NOT NULL
--    Ama yorumlari okuyan TEK sorgu (social/etkilesim.go) KOK + YANITI BIRLIKTE
--    cekiyor ve `parent_id` uzerine HICBIR kosul icermiyor. Postgres kismi
--    index'i ancak sorgunun WHERE'i index yuklemini MANTIKSAL OLARAK
--    GEREKTIRIYORSA kullanir -> iki index de KULLANILAMIYOR ve `post_comments`
--    HER yorum acilisinda TAM TARANIYOR.
-- ⚠️ Bu index'in yuklemi (`durum='yayinda'`) sorguda LITERAL olarak VAR, o yuzden
--    cikarsanabilir ve index GERCEKTEN kullanilir.
CREATE INDEX IF NOT EXISTS idx_yorum_liste
    ON post_comments (post_id, created_at) WHERE durum = 'yayinda';

-- ⚠️ Eski iki index BILEREK DUSURULMUYOR: yanit sayfalama ileride eklenirse
--    `idx_yorum_yanit` ise yarar. Uc index'in yazma maliyeti bu olcekte onemsiz.

-- ============ 2) MEDYA REFERANS SAYIMI ============
-- `medyayiKopar` (social + kanal) bir medyanin BASKA yerde kullanilip
-- kullanilmadigini sayiyor. Uc alt sorgunun ikisi indekssizdi:
--
--   · `users.avatar_media_id` — sutun 015'te eklendi, index YOKTU -> `users` TAM TARANIR.
--   · `posts.media_ids` UUID[] uzerinde `$1 = ANY(media_ids)` -> dizi taramasi.
--
-- ⚠️ GIN index `= ANY(dizi)` bicimini DOGRUDAN kullanamaz; sorgu
--    `media_ids @> ARRAY[$1]::uuid[]` bicimine cevrilirse kullanir. Index'i
--    SIMDI kuruyoruz ki sorgu bicimi degistiginde hazir olsun; bugunku hali
--    zaten kucuk tabloda calisiyor.
CREATE INDEX IF NOT EXISTS idx_users_avatar_media
    ON users (avatar_media_id) WHERE avatar_media_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_posts_media_gin
    ON posts USING GIN (media_ids);

CREATE INDEX IF NOT EXISTS idx_kanal_gonderi_media_gin
    ON channel_posts USING GIN (media_ids);

CREATE INDEX IF NOT EXISTS idx_channels_avatar_media
    ON channels (avatar_media_id) WHERE avatar_media_id IS NOT NULL;

-- ============ 3) KANAL ADI ON-EK ARAMASI ============
-- ⚠️ `LOWER(c.ad) LIKE $2 || '%'` sorgusu, veritabani C DISI bir collation ile
--    kuruluysa (tr_TR.UTF-8 / en_US.UTF-8 — Docker postgres:17 varsayilani)
--    normal B-tree index'i KULLANAMAZ. `text_pattern_ops` tam da bunun icindir.
-- ⚠️ YAPMA: bunu esitlik aramasi icin kullanma (text_pattern_ops yalniz
--    on-ek/LIKE icin dogru siralama verir).
CREATE INDEX IF NOT EXISTS idx_channels_ad_prefix
    ON channels (LOWER(ad) text_pattern_ops);

CREATE INDEX IF NOT EXISTS idx_channels_kadi_prefix
    ON channels (kullanici_adi text_pattern_ops) WHERE kullanici_adi IS NOT NULL;

-- ============ 4) KAYDEDILENLER ============
-- Yeni uc `GET /users/me/saved` bu index'ten okur.
CREATE INDEX IF NOT EXISTS idx_post_saves_kullanici
    ON post_saves (user_id, created_at DESC);
