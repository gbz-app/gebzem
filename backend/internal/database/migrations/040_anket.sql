-- ⚠️⚠️⚠️ TURU 81 — SOHBET ICI ANKET (kullanici emri: "anket de yok, bunlari
-- eklememiz gerekiyor").
--
-- Tasarim: docs/medya-arastirma/tasarim-anket.md (669 satir, dosya:satir
-- referansli). Bu migration o tasarimin 3. bolumunun uyarlanmasidir.
--
-- ⚠️⚠️ TASARIMDAN **BILINCLI SAPMA**: tasarim `messages_type_check`i YENIDEN
--    KURUYORDU. BU MIGRATION ONA **DOKUNMUYOR**.
--
--	Gerekce: 'poll' tipi migration **039**'da (turu 81) CHECK'e ZATEN
--	eklendi. Ikisi de kisiti yeniden kursaydi, tasarimin kendi uyardigi
--	tuzaga duserdik: *"birbirinden habersiz iki migration kisiti yeniden
--	kurarsa, sonra calisan oncekinin tiplerini SILER"* — nitekim tasarimin
--	yazdigi kume 039'daki 'document', 'contact', 'iban', 'etkinlik'
--	tiplerini ICERMIYOR ve calissaydi DORDUNU BIRDEN dusururdu.
-- ⚠️ YAPMA: buraya `ALTER TABLE messages ... type_check` ekleme.
--
-- ⚠️ VERI SILINMEZ kurali: anket KAPANIR (`closed_at`), satir SILINMEZ.
--    `ON DELETE CASCADE` yalnizca mesajin/sohbetin kendisi silinirse devreye
--    girer (bugun mesaj silme fiziksel DELETE yapmiyor — icerik bosaltiliyor).

-- ============ 1) ANKETLER ============
CREATE TABLE IF NOT EXISTS polls (
    id         BIGSERIAL PRIMARY KEY,
    -- ⚠️ UNIQUE: bir mesajin EN FAZLA bir anketi olur.
    message_id BIGINT NOT NULL UNIQUE REFERENCES messages(id) ON DELETE CASCADE,
    -- ⚠️ `chat_id` DENORMALIZE: uyelik/engel kontrolu icin her oy isteginde
    --    `messages`a JOIN atmayalim. `messages.chat_id` ile AYNI olmak
    --    zorunda; YAZAN TEK UC oldugumuz icin trigger konmadi.
    chat_id    UUID   NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    creator_id UUID   NOT NULL REFERENCES users(id),
    question   TEXT   NOT NULL,
    multi      BOOLEAN NOT NULL DEFAULT FALSE,   -- birden fazla yanit secilebilir
    closed_at  TIMESTAMPTZ,                      -- NULL = ACIK
    -- ⚠️⚠️ `vote_seq`: HER oy/kapatma islemi bunu 1 artirir. WS olaylari bu
    --    degeri tasir ve istemci `yeniSeq <= mevcutSeq` ise olayi YOK SAYAR.
    --    ZORUNLU, cunku WS bu projede KAYBOLABILIR: hub kuyrugu dolunca olay
    --    DUSER ve istemci her arka plana geciste soketi KAPATIR (turu 33,
    --    kilit ekraninda arama caldirabilmek icin). Turu 61'de `call.held`
    --    olayi TAM BOYLE kaybolmus ve Sentry ile kanitlanmisti.
    -- ⚠️ YAPMA: bu sutunu kaldirip "son gelen kazanir" davranisina donme.
    vote_seq   BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_polls_chat ON polls (chat_id, id DESC);

-- ============ 2) SECENEKLER ============
CREATE TABLE IF NOT EXISTS poll_options (
    id      BIGSERIAL PRIMARY KEY,
    poll_id BIGINT   NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    -- ⚠️ GORUNTULEME SIRASI. `id`ye guvenilemez: BIGSERIAL global bir dizidir
    --    ve es zamanli iki anket olusturulursa siralar CAKISIR.
    idx     SMALLINT NOT NULL,
    text    TEXT     NOT NULL,
    UNIQUE (poll_id, idx)
);
CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON poll_options (poll_id, idx);

-- ============ 3) OYLAR ============
-- ⚠️ PK = (poll_id, option_id, user_id): ayni oy IKI KEZ atilamaz
--    (`ON CONFLICT DO NOTHING` ile idempotent). Coklu secimde ayni kullanici
--    birden cok satir tutar.
CREATE TABLE IF NOT EXISTS poll_votes (
    poll_id    BIGINT NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_id  BIGINT NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
    user_id    UUID   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (poll_id, option_id, user_id)
);
-- "benim oylarim" + oy degistirmedeki DELETE icin
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_user ON poll_votes (poll_id, user_id);
-- secenek basina sayim icin
CREATE INDEX IF NOT EXISTS idx_poll_votes_option ON poll_votes (option_id);
