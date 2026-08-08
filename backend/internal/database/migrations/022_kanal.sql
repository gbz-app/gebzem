-- 022_kanal.sql — KANAL (WhatsApp "Kanallar" deseni: tek yonlu yayin).
--
-- ⚠️⚠️⚠️ NEDEN `chats` TABLOSUNU KULLANMIYORUZ (mimari karar — okumadan degistirme):
--   CLAUDE.md "Kanal/grup: Telegram modeli (tek chats tablosu, type: channel)"
--   diyor ve `chats.type` CHECK'i 'channel'i ZATEN kabul ediyor. Ama mevcut mesaj
--   hatti kanal olceginde CALISMAZ — kod okunarak dogrulandi:
--
--   (1) `chat.SendMessage` her mesajda **UYE BASINA AYRI INSERT** yapiyor:
--         for _, uid := range members { INSERT INTO message_receipts ... }
--       10.000 aboneli bir kanalda TEK gonderi = 10.000 ayri INSERT sorgusu.
--       cx33'te Postgres LiveKit ile AYNI 4 vCPU'yu paylasiyor; bu yazma
--       firtinasi SFU'yu ac birakir (aramalar/yayinlar bozulur).
--   (2) `hub.Publish(To: members)` ve `push.NotifyUsers(members, ...)` ayni
--       10.000 elemanli diziyi tasiyor.
--   (3) `ListChats` okunmamis sayisini `message_receipts` uzerinden `COUNT(*)`
--       ile buluyor — kanal basina milyonlarca satirda tam tarama.
--   (4) Kanalda "okundu bilgisi" ZATEN ISTENMIYOR (WhatsApp kanallarinda tik
--       yoktur, yalniz TOPLAM goruntulenme vardir). Yani receipt satirlarinin
--       urun karsiligi da YOK.
--
--   COZUM: OKUMA ZAMANI fan-out (akis karariyla ayni). Abone kendi
--   `son_okuma` damgasindan sonraki gonderileri sayar: (kanal,kullanici) basina
--   TEK SATIR, (mesaj,kullanici) basina satir YOK.
-- ⚠️ YAPMA: kanali `chats`/`messages`/`message_receipts` hattina tasima.
-- ⚠️ YAPMA: gonderi basina abone satiri yazan bir "teslim" mekanizmasi ekleme.
--
-- ⚠️⚠️ KULLANICI KARARI (8 Agu): VERI SILINMEZ. Burada yas tabanli temizlik YOK.
-- ⚠️ YAPMA: `expires_at` / otomatik supurge ekleme.

-- ============ 1) KANAL ============
CREATE TABLE IF NOT EXISTS channels (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ad            TEXT NOT NULL,
    -- Herkese acik tanitici (@kanaladi). Kullanici adlariyla AYNI havuzda DEGIL:
    -- kanal ve kisi ayri ad uzaylari (Telegram bunlari birlestirir, biz
    -- birlestirmiyoruz — birlestirmek `users.username` uzerinde kilit yarisi
    -- ve goc riski demek).
    kullanici_adi TEXT UNIQUE,
    aciklama      TEXT NOT NULL DEFAULT '',
    avatar_media_id UUID REFERENCES media_assets(id) ON DELETE SET NULL,

    -- ⚠️ DENORMALIZE: her kanal kartinda `count(*)` tam tarama olurdu.
    --    Abonelik islemiyle AYNI TRANSACTION'da guncellenir.
    abone_sayisi  INT NOT NULL DEFAULT 0,
    gonderi_sayisi INT NOT NULL DEFAULT 0,

    durum         TEXT NOT NULL DEFAULT 'aktif'
                  CHECK (durum IN ('aktif','kapali','karantina')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_channels_sahip ON channels (owner_id);
-- Kesfet: cok aboneli aktif kanallar.
CREATE INDEX IF NOT EXISTS idx_channels_kesfet
    ON channels (abone_sayisi DESC, created_at DESC) WHERE durum = 'aktif';

-- ⚠️ Kanal adi aramasi icin: `LOWER(ad)` ile ON prefix. `pg_trgm` KULLANILMADI
--    (uzanti kurulumu gerektirir; bu boyutta prefix yeterli).
CREATE INDEX IF NOT EXISTS idx_channels_ad ON channels (LOWER(ad));

-- ============ 2) YETKILILER ============
-- ⚠️ Sahibi de BURAYA yazilir (kanal olusturulurken) — "sahip mi yoksa yetkili
--    mi" ayrimini her sorguda yapmak yerine TEK kontrol: bu tabloda var mi.
--    `channels.owner_id` yalnizca SILME/DEVIR yetkisi icin ayrica bakilir.
CREATE TABLE IF NOT EXISTS channel_admins (
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (channel_id, user_id)
);

-- ============ 3) ABONELER ============
CREATE TABLE IF NOT EXISTS channel_subscribers (
    channel_id   UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- ⚠️ OKUNMAMIS SAYIMININ TEMELI: (mesaj,kullanici) satiri YERINE tek damga.
    --    `COUNT(*) FROM channel_posts WHERE channel_id=.. AND created_at > son_okuma`
    son_okuma    TIMESTAMPTZ NOT NULL DEFAULT now(),
    sessiz       BOOLEAN NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, channel_id)
);
-- "Bu kanalin aboneleri" (yonetici listesi + push hedefi).
CREATE INDEX IF NOT EXISTS idx_kanal_abone ON channel_subscribers (channel_id);

-- ============ 4) KANAL GONDERILERI ============
CREATE TABLE IF NOT EXISTS channel_posts (
    id         BIGSERIAL PRIMARY KEY,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    -- Hangi yetkili yazdi (kanal adina gorunur ama denetim izi kalir).
    author_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    metin      TEXT NOT NULL DEFAULT '',
    -- ⚠️ `posts.media_ids` ile AYNI karar: ara tablo yerine dizi (sira dogal
    --    korunur, tek satirda gelir). FK yok — silinen medya id'si dizide kalir
    --    ve istemci "kaldirildi" cizer.
    media_ids  UUID[] NOT NULL DEFAULT '{}',
    begeni_sayisi INT NOT NULL DEFAULT 0,
    goruntulenme  INT NOT NULL DEFAULT 0,
    durum      TEXT NOT NULL DEFAULT 'yayinda'
               CHECK (durum IN ('yayinda','silindi','karantina')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Kanal akisi (yeniden eskiye) + okunmamis sayimi AYNI index'ten karsilanir.
CREATE INDEX IF NOT EXISTS idx_kanal_gonderi
    ON channel_posts (channel_id, created_at DESC) WHERE durum = 'yayinda';

-- ============ 5) BEGENI ============
-- ⚠️ WhatsApp kanallarinda EMOJI TEPKI var; bizde EMOJI YASAK (CLAUDE.md, turu 62
--    "arayuzde 3B emoji istemiyorum" emri). Bu yuzden tek tip BEGENI (Lucide kalp).
-- ⚠️ YAPMA: emoji tepki sutunu ekleme.
CREATE TABLE IF NOT EXISTS channel_post_likes (
    post_id BIGINT NOT NULL REFERENCES channel_posts(id) ON DELETE CASCADE,
    user_id UUID   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, user_id)
);

-- ============ 6) SIKAYET ============
-- ⚠️ `reports.hedef_tur` SERBEST METIN (014) — 'kanal' ve 'kanal_gonderi' icin
--    migration GEREKMEZ; yalniz uygulama katmanindaki beyaz liste genisletilir.
