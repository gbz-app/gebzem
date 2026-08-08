-- 015_medya.sql — MEDYA MESAJLASMA ALTYAPISI (BIRLESIK, TEK MIGRATION)
--
-- ⚠️ ADDITIVE: mevcut hicbir sutun daraltilmaz/kaldirilmaz/tip donusturulmez.
-- ⚠️ Migration calistiricisi dosya basina TEK Exec kullanir -> basit protokol ->
--    ORTUK TEK TRANSACTION. Ya hep ya hic.
-- ⚠️ Hata durumunda main.go log.Fatalf -> API HIC ACILMAZ. Bu yuzden CHECK
--    degisikligi ADA GUVENMEDEN, pg_constraint'ten ARANARAK yapilir.
--
-- ⚠️⚠️ KULLANICI KARARI (8 Agu): **VERI SILINMEZ.** Plandaki "90 gun sonra sil"
--    onerisi REDDEDILDI. Bu semada YAS TABANLI SILME YOKTUR; sweeper yalnizca
--    YETIM YUKLEMELERI (baslamis ama tamamlanmamis) temizler — o kullanici verisi
--    DEGILDIR. Silme yalnizca: kullanici kendi icerigini siler, hesabini siler,
--    ya da yasal kaldirma karari gelir.
--    ⚠️ YAPMA: bu semaya `expires_at` / yas tabanli temizlik ekleme.

-- ============ 1) MESSAGES.TYPE CHECK — TEK VE SON DEFA ============
-- ⚠️ Kisit 001_init.sql:55'te SATIR ICI tanimli; adini Postgres uretir ve
--    'messages_type_check' olmasi GARANTI DEGIL. Yanlis ada guvenirsek
--    DROP IF EXISTS sessizce hicbir sey yapmaz, ADD "already exists" ile PATLAR
--    ve migration YARIM kalir -> API sonsuz cokme dongusu.
DO $$
DECLARE k text;
BEGIN
  SELECT conname INTO k FROM pg_constraint
   WHERE conrelid = 'messages'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) ILIKE '%type%location%';
  IF k IS NOT NULL THEN EXECUTE format('ALTER TABLE messages DROP CONSTRAINT %I', k); END IF;
END $$;

-- ⚠️⚠️ TUM GELECEK TIPLER BURADA. Sonraki hicbir migration bu kisita DOKUNMAYACAK.
--    (Sebep: birbirinden habersiz iki migration kisiti yeniden kurarsa, sonra
--     calisan oncekinin tiplerini SILER.)
-- ⚠️ 'system' HALA VAR (sunucunun kendi yazdigi arama kayitlari dogrudan INSERT
--    eder) ama ISTEMCI BEYAZ LISTESINE ASLA EKLENMEZ (turu 59b kimlik taklidi acigi).
-- ⚠️ NOT VALID + ayri VALIDATE: yeni kume eskinin USTKUMESI oldugu icin tam tablo
--    taramasi gereksiz; ACCESS EXCLUSIVE kilit suresi milisaniyeye iner.
ALTER TABLE messages ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text','image','video','audio','location','system',
                  'document','contact','poll')) NOT VALID;
ALTER TABLE messages VALIDATE CONSTRAINT messages_type_check;

-- ============ 2) MEDYA VARLIKLARI ============
CREATE TABLE IF NOT EXISTS media_assets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK (kind IN ('image','video','audio','document','avatar')),

    -- R2 nesne anahtarlari. TAM URL SAKLANMAZ: erisim her istekte imzalanir.
    -- ⚠️ Anahtarda kullanici id / sohbet id / telefon / dosya adi YOKTUR
    --    (anahtar sizarsa kimlik bilgisi de sizmasin).
    object_key    TEXT NOT NULL UNIQUE,
    thumb_key     TEXT NOT NULL DEFAULT '',

    mime          TEXT NOT NULL,
    bytes         BIGINT NOT NULL DEFAULT 0,     -- COMMIT'te HeadObject ile DOGRULANMIS
    sha256        TEXT NOT NULL DEFAULT '',      -- dedup + hash bazli toplu kaldirma (5651)
    width         INT NOT NULL DEFAULT 0,
    height        INT NOT NULL DEFAULT 0,
    duration_ms   INT NOT NULL DEFAULT 0,
    file_name     TEXT NOT NULL DEFAULT '',      -- belge gosterim adi (ANAHTARDA yok)
    waveform      TEXT NOT NULL DEFAULT '',      -- ses notu: 60 adet 0-99, virgullu

    -- DURUM MAKINESI (tek yonlu): beklemede -> aktif -> bagli
    --   beklemede : presign verildi, yukleme dogrulanmadi
    --   aktif     : commit gecti (boyut+tip+md5 dogrulandi), henuz mesaja baglanmadi
    --   bagli     : bir mesaja/avatara baglandi
    --   reddedildi: dogrulama basarisiz (nesne silindi)
    --   karantina : moderasyon kaldirdi
    --   silindi   : sahibi ya da yasal karar sildi
    -- ⚠️ Tek-kullanim guvencesi BURADADIR (If-None-Match DEGIL — o mobil sebekede
    --    tekrar denemeyi oldururdu ve 412 "eksik mi tam mi" ayirt edilemez).
    status        TEXT NOT NULL DEFAULT 'beklemede'
                  CHECK (status IN ('beklemede','aktif','bagli','reddedildi','karantina','silindi')),
    reject_reason TEXT NOT NULL DEFAULT '',

    -- presign aninda ISTEMCI BEYANI; commit'te GERCEKLE karsilastirilir
    expected_bytes       BIGINT NOT NULL DEFAULT 0,
    expected_md5         TEXT   NOT NULL DEFAULT '',
    thumb_expected_bytes BIGINT NOT NULL DEFAULT 0,
    thumb_expected_md5   TEXT   NOT NULL DEFAULT '',

    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    committed_at  TIMESTAMPTZ,
    linked_at     TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ
);

-- sweeper: YETIM yuklemeler (beklemede) + baglanmamis aktifler
-- ⚠️ Yas tabanli silme YOK (kullanici karari) — bu index yalniz yetim temizligi icin.
CREATE INDEX IF NOT EXISTS idx_media_sweep ON media_assets (status, created_at);
-- dedup kisa devresi (presign yolunda HER istekte kosar -> KISMI index)
CREATE INDEX IF NOT EXISTS idx_media_dedup ON media_assets (owner_id, sha256)
    WHERE status IN ('aktif','bagli');
-- 5651: bir hash'in TUM kopyalarini tek hamlede kaldirmak
CREATE INDEX IF NOT EXISTS idx_media_sha ON media_assets (sha256) WHERE sha256 <> '';
CREATE INDEX IF NOT EXISTS idx_media_owner ON media_assets (owner_id, created_at DESC);

-- ============ 3) MESSAGES BAGLANTISI ============
-- ⚠️ ON DELETE SET NULL (CASCADE DEGIL): bir medya kaldirilinca MESAJ SATIRI DURUR
--    (balon "Bu icerik kaldirildi" yazar). CASCADE olsaydi bir medya temizligi
--    kullanicinin SOHBET GECMISINI SILERDI.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;

-- Idempotency: ag zaman asimindan sonra tekrar denenen POST IKINCI MESAJ URETMEZ.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_ref TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_messages_media ON messages (chat_id, id DESC)
    WHERE media_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_ref
    ON messages (chat_id, sender_id, client_ref) WHERE client_ref <> '';

-- ============ 4) SILME KUYRUGU ============
-- R2 DeleteObject satir ici denenir (UCRETSIZ); basarisiz olursa nesne SIZMASIN.
-- ⚠️ Ayrica: her surumdeki "TRUNCATE users CASCADE" rutininden ONCE object_key'ler
--    buraya kopyalanmali, aksi halde CASCADE media_assets satirlarini siler ve
--    sweeper o R2 nesnelerini BIR DAHA GOREMEZ (kalici sizinti).
CREATE TABLE IF NOT EXISTS media_delete_queue (
    id         BIGSERIAL PRIMARY KEY,
    object_key TEXT NOT NULL,
    tries      INT NOT NULL DEFAULT 0,
    last_error TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_delq ON media_delete_queue (tries, created_at);

-- ============ 5) MODERASYON ============
-- ⚠️ Sikayet tablosu 014_reports.sql'de ZATEN kuruldu (genel `reports`, hedef_tur ile
--    her icerik tipini kapsar). Plandaki ayri `message_reports` tablosu KURULMADI —
--    iki sikayet kuyrugu tutmak drift uretir.
-- Askiya alma: moderasyon karari sonucu hesap kapatma.
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;

-- ============ 6) "DINLENDI" MAKBUZU (ses notu mavi mikrofon) ============
-- ⚠️ read_at'ten AYRI: sohbeti acmak mesaji "okundu" yapar ama ses notunu DINLEMEZ.
ALTER TABLE message_receipts ADD COLUMN IF NOT EXISTS played_at TIMESTAMPTZ;

-- ============ 7) EKSIK INDEX (okunmamis sayaci) ============
-- ListChats her sohbet icin message_receipts'i tariyor; 001_init.sql'de user_id
-- uzerinde index YOK. Medya ile mesaj hacmi artacak.
CREATE INDEX IF NOT EXISTS idx_receipts_okunmamis ON message_receipts (user_id)
    WHERE read_at IS NULL;

-- ============ 8) AVATAR ============
-- ⚠️ Mevcut `users.avatar_url` KALIR (geriye donuk uyum); yeni yuklemeler
--    `avatar_media_id` uzerinden imzali URL ile sunulur.
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;
