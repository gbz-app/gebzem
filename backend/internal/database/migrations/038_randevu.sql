-- 038_randevu.sql — TURU 80: REZERVASYON (restoran) + RANDEVU (doktor vb.)
--
-- Kullanici emri: "restoran/yemek firmalarindan REZERVASYON, doktor vs.den
-- RANDEVU alinabilmeli".
--
-- ═══════════ ⚠️⚠️ NEDEN TEK TABLO (`randevular`) ═══════════
--
-- Rezervasyon ile randevu AYNI ISTIR: "bir isletmeden belirli bir ZAMAN DILIMI
-- almak". Durum makinesi, yetki kapilari, cakisma mantigi, bildirim yolu, engel
-- yuklemi ve SELECT/Scan cifti IKISINDE DE AYNI. Fark yalnizca IKI ALAN:
-- `kisi_sayisi` (rezervasyon) ve `hizmet` (randevu).
--
-- Ayri tablo = iki handler = **AYNI KURALIN IKI KOPYASI** ve bu proje o siniftan
-- ALTI kez zarar gordu (72b/H, 75b/2, 77b, 78 direkt sohbet...).
-- ⚠️ YAPMA: ileride `rezervasyonlar` diye ikinci bir tablo acma.
--
-- ═══════════ ⚠️ VERI SILINMEZ ═══════════
-- Iptal bir SILME DEGIL, bir DURUM degisimidir. Bu semada `expires_at` ya da
-- yas tabanli temizlik YOKTUR. "Gecmis randevu" bir DURUM degil, bir SORGU
-- SUZGECIDIR (`baslangic < now()`) — `etkinlikler` icin verilen kararin aynisi.

-- ---------------------------------------------------------------- AYARLAR
--
-- ⚠️ AYRI TABLO, `isletmeler`e SUTUN EKLENMEDI. Iki sebep:
--   (1) `isletmeler` rehber listesinde ve HER profil acilisinda okunuyor;
--       rezervasyon sutunlari her sorguya biner.
--   (2) ⚠️⚠️ `isletme.Kaydet` bir **UPSERT**tir (`ON CONFLICT DO UPDATE`).
--       Oraya NOT NULL sutun eklemek, istemci o alani gondermediginde
--       `nil -> SQL NULL` tuzagini ateslerdi — turu 78b'de tam bu yuzden
--       "isletme hesabina gecis HER SEFERINDE 500" yasandi.
CREATE TABLE IF NOT EXISTS randevu_ayar (
    isletme_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    -- Ozellik ACIK MI. Kapaliysa istemci dugmeyi HIC cizmez.
    acik           BOOLEAN NOT NULL DEFAULT false,
    -- Slot uzunlugu (dakika). Doktor 20-30, restoran 60-90 tipik.
    slot_dakika    INT NOT NULL DEFAULT 30,
    -- ⚠️⚠️ KAPASITE BIRIMI = **AYNI ANDA KAC RANDEVU** (masa/koltuk sayisi),
    --    KISI SAYISI DEGIL. Tek kural, dallanma yok.
    --    Kisi bazli sayim rezervasyon ve randevu icin IKI FARKLI kural
    --    demekti (drift); ustelik 12 kisilik bir grup, isletmenin 11 bos
    --    koltugu varken SESSIZCE "dolu" alirdi. `kisi_sayisi` isletmenin
    --    onay/red karari icin BILGI olarak duruyor.
    slot_kapasite  INT NOT NULL DEFAULT 1,
    -- Kac gun ilerisi icin randevu alinabilir.
    ileri_gun      INT NOT NULL DEFAULT 14,
    -- ⚠️ ISLETME ONAYI VARSAYILAN. Onaysiz sistem no-show uretir; onayli sistem
    --    cevapsiz isletmede oludur. Bu ikilemi URUN karariyla degil ISLETME
    --    karariyla cozuyoruz. Varsayilan `false` cunku karsilayamayacagi bir
    --    saati otomatik onaylamak, bekleyen talepten DAHA KOTUDUR.
    otomatik_onay  BOOLEAN NOT NULL DEFAULT false,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- KAPALI GUNLER
--
-- Bayram/tatil. ⚠️ Bu tablo OLMADAN `calisma` JSONB'si "acik" dedigi icin
-- sunucu bayram gununde de SLOT URETMEYE DEVAM ederdi.
CREATE TABLE IF NOT EXISTS randevu_kapali (
    isletme_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- ⚠️ DATE (timestamptz DEGIL): "1 Ocak kapali" bir GUN ifadesidir, an degil.
    tarih      DATE NOT NULL,
    PRIMARY KEY (isletme_id, tarih)
);

-- ---------------------------------------------------------------- RANDEVULAR
CREATE TABLE IF NOT EXISTS randevular (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    isletme_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    musteri_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- ⚠️⚠️ `tur` SUNUCU TARAFINDAN TURETILIR ve olusturma aninda DONDURULUR.
    --    Istemci GONDERMEZ. Sebep: isletme kategorisini 'yemek'ten 'saglik'a
    --    cevirirse OKUMA ANINDA turetilen bir etiket GECMIS kayitlari da
    --    degistirir ve "4 kisilik randevu" gibi anlamsiz satirlar cizilir.
    -- ⚠️ CHECK KONMADI: `tur` buyumeye acik bir ETIKET boyutu (ileride
    --    'kurs_kaydi', 'deneme_dersi'...). Ayni gerekce `reports.hedef_tur` ve
    --    `isletmeler.kategori` icin de verildi. Beyaz liste Go tarafinda.
    tur          TEXT NOT NULL DEFAULT 'randevu',

    baslangic    TIMESTAMPTZ NOT NULL,
    -- ⚠️ SURE SATIRDA TASINIR (ayardan okuma-aninda TURETILMEZ): isletme slot
    --    uzunlugunu 30'dan 60'a cevirirse GECMIS randevularin suresi de
    --    degisir ve cakisma hesabi GERIYE DONUK bozulurdu.
    sure_dakika  INT NOT NULL DEFAULT 30,

    -- Rezervasyon tarafi (restoran): kac kisi.
    kisi_sayisi  INT NOT NULL DEFAULT 1,
    -- Randevu tarafi (doktor/kuafor): hangi hizmet. Serbest metin.
    hizmet       TEXT NOT NULL DEFAULT '',

    not_musteri  TEXT NOT NULL DEFAULT '',
    not_isletme  TEXT NOT NULL DEFAULT '',

    -- ⚠️⚠️ DURUM CHECK'I **YEDI DEGERIN HEPSIYLE ILK GUNDEN** yazildi.
    --    036/037 DERSI: mevcut bir CHECK'e sonradan deger eklemek migration
    --    ve sevk engeli uretiyor (iki kez yasandi). Yeni tabloda tam listeyi
    --    yazmak BEDAVA. Bugun yazicisi olmayan degerler ('geldi'/'gelmedi')
    --    de simdiden kabul edilir.
    durum        TEXT NOT NULL DEFAULT 'bekliyor'
                 CHECK (durum IN ('bekliyor','onaylandi','reddedildi',
                                  'iptal','iptal_isletme','geldi','gelmedi')),

    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ⚠️ CAKISMA SORGUSUNUN INDEKSI: "bu isletmenin su araliktaki AKTIF randevulari".
CREATE INDEX IF NOT EXISTS idx_randevu_isletme_zaman
    ON randevular (isletme_id, baslangic)
    WHERE durum IN ('bekliyor','onaylandi');

-- Musterinin kendi listesi.
CREATE INDEX IF NOT EXISTS idx_randevu_musteri
    ON randevular (musteri_id, baslangic DESC);

-- Isletmenin gelen kutusu (durum suzgecli).
CREATE INDEX IF NOT EXISTS idx_randevu_isletme_durum
    ON randevular (isletme_id, durum, baslangic);

-- ⚠️⚠️ **UNIQUE SLOT INDEKSI KASITLI OLARAK YOK.**
--    `UNIQUE (isletme_id, baslangic) WHERE durum IN (...)` ilk bakista dogru
--    gorunur AMA isletme basina ayni saate **TEK** randevu birakir: 10 masali
--    bir restoranda ikinci rezervasyon 409 alir. Kapasite `slot_kapasite` ile
--    ifade ediliyor ve cakisma kontrolu Go tarafinda **advisory kilit + tek
--    deyimli sayim** ile yapiliyor (bkz. `internal/randevu/`).
--    ⚠️ YAPMA: buraya unique index ekleme.
