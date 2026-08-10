-- 042_gonderi_anket.sql — TURU 83: ANKET ARTIK GONDERIDE DE OLABILIR.
--
-- Kullanici emri: *"gonderide ses anket ne varsa yapilmasi gerekiyor,
-- bunlarin yapilmasi elzem"*.
--
-- ═══════════ KESIF: NE KADARI ZATEN VARDI ═══════════
--
--   · SES  -> `media_assets.kind` CHECK'i **037'den beri 'audio' KABUL
--             EDIYOR** ve `posts.media_ids` bir medya dizisi. Yani ses icin
--             SEMA DEGISIKLIGI GEREKMIYOR; eksik olan yalnizca istemcinin
--             cizim daliydi. Bu migration SESE HIC DOKUNMAZ.
--   · ANKET -> `polls` tablosu 040'ta kuruldu ama **SOHBETE CIVILI**:
--               message_id BIGINT NOT NULL UNIQUE REFERENCES messages(id)
--               chat_id    UUID   NOT NULL REFERENCES chats(id)
--             Gonderi anketi icin bu iki NOT NULL gevsetilmeli.
--
-- ═══════════ TASARIM ═══════════
--
-- `polls` tablosu YENIDEN KULLANILIR, ikinci bir tablo ACILMAZ. Sebep:
-- oylama mantigi (`poll_votes`, `vote_seq`, tek/cok secim, kapatma) 040'ta
-- YAZILDI ve SINANDI; ikinci bir kopya **kacinilmaz olarak DRIFT EDER**
-- (bu projede "ayni kuralin iki kopyasi" hatasi ALTI kez yasandi).
--
-- ⚠️ SAHIPLIK TAM OLARAK BIRI: ya `message_id` (sohbet anketi) ya `post_id`
--    (gonderi anketi). CHECK bunu ZORLAR — ikisi de dolu ya da ikisi de bos
--    bir satir yetki kontrolunu BELIRSIZ birakirdi (hangi kapiya bakilacak?).
--
-- ⚠️ `chat_id` de NULL olabilir yapildi: gonderi anketinde sohbet YOKTUR.
--    040'taki serh onu "uyelik/engel kontrolu icin denormalize" diye
--    aciklamisti; o gerekce yalnizca SOHBET anketleri icin gecerlidir.

-- ============ 1) SOHBET CIVISINI GEVSET ============
ALTER TABLE polls ALTER COLUMN message_id DROP NOT NULL;
ALTER TABLE polls ALTER COLUMN chat_id    DROP NOT NULL;

-- ============ 2) GONDERI BAGI ============
-- ⚠️ `ON DELETE CASCADE`: gonderi silinince anketi ve (poll_options/poll_votes
--    zincirlemesiyle) oylari da gider. Gonderi yokken yasayan bir anket
--    hicbir yuzeyden ulasilamaz — "olu satir" olurdu.
ALTER TABLE polls
    ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES posts(id) ON DELETE CASCADE;

-- ⚠️ Bir gonderinin EN FAZLA bir anketi olur (mesajdaki UNIQUE'in karsiligi).
--    KISMI indeks: `post_id` NULL olan (sohbet) satirlar UNIQUE kisidina
--    girmez — aksi halde tum sohbet anketleri tek bir NULL degeri paylasip
--    CAKISIRDI.
CREATE UNIQUE INDEX IF NOT EXISTS idx_polls_post_uniq
    ON polls (post_id) WHERE post_id IS NOT NULL;

-- Gonderi sorgularinda anketi cekmek icin.
CREATE INDEX IF NOT EXISTS idx_polls_post ON polls (post_id);

-- ============ 3) TAM OLARAK BIR SAHIP ============
-- ⚠️ Bu kisit OLMADAN: her iki alan da NULL olan bir satir yazilabilir ve o
--    anket HICBIR yetki kontrolunden gecmez (ne sohbet uyeligi ne gonderi
--    gorunurlugu) — sessiz bir gizlilik acigi.
ALTER TABLE polls DROP CONSTRAINT IF EXISTS polls_sahip_check;
ALTER TABLE polls ADD CONSTRAINT polls_sahip_check
    CHECK ((message_id IS NOT NULL) <> (post_id IS NOT NULL));

-- ⚠️ `chat_id` YALNIZ sohbet anketinde zorunlu kalir.
ALTER TABLE polls DROP CONSTRAINT IF EXISTS polls_chat_check;
ALTER TABLE polls ADD CONSTRAINT polls_chat_check
    CHECK (message_id IS NULL OR chat_id IS NOT NULL);
