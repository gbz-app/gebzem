-- 045_talep_diyet.sql — TURU 91: TEKLIF AKISI (dugun/hizmet) + DIYET TAKIBI
--
-- ADDITIVE. Hicbir sutun/tablo DUSURULMEZ, hicbir CHECK yeniden kurulmaz.
-- VERI SILINMEZ (kullanici karari 8 Agu): hicbir tabloda `expires_at` ya da
-- yas tabanli supurge YOKTUR. Talebin "7 gun sonra kapanmasi" OKUMA ZAMANI
-- yuklemidir (turu 81'in zamanlanmis paylasim karariyla ayni ilke: supurge
-- calismazsa ozellik SESSIZCE bozulur, yuklem calismazsa HICBIR SEY bozulmaz).

-- ═══════════════ GORUNURLUK KARARI — KOD YAZMADAN ONCE OKU ═══════════════
--
-- ⚠️⚠️⚠️ TALEP **HERKESE ACIKTIR**. Bu bir tercih degil, `ilanlar` tablosunun
--    HER YERINE gomulu bir gercek: `GET /ilanlar`, `Detay`, favori ve en
--    onemlisi `media/handler.go` ilan dali — o dal TEK KAPI olarak
--    `i.durum <> 'kaldirildi'` + engel diyor, yani **BIR ILANA BAGLI HER
--    GORSEL TUM OTURUM SAHIPLERINE ACIKTIR**.
--
-- ⚠️ YAPMA: talep satirina isim / telefon / adres / "gizli butce" alani
--    EKLEME. Eklenecekse `ilanlar` YANLIS EVDIR ve yukaridaki dal MIRAS
--    ALINAMAZ — "bu satir aslinda gizli" istisnasini ALTI sorguya ve BIR
--    GUVENLIK FONKSIYONUNA elle eklemek gerekirdi. Turu 75b'de engel yuklemi
--    dort sorguya kopyalanmis, BESINCISINDE dusmustu.
--
-- ⚠️ Talep formu kullaniciya "Bu talep herkese açıktır" der (ekran karari).

-- ═══════════════ 1) KARSI TEKLIF = `ilan_basvurular` + IKI SUTUN ═══════════
--
-- ⚠️⚠️ YENI TABLO ACILMADI (`teklifler` YAZILMADI).
--    Gerekce, UC migration'da ISIMLE yazili yasagin aynisi (030:14, 038:15,
--    031:12): `ilan_basvurular` ZATEN "cok kisi -> tek ilan" istek/yanit
--    iliskisidir; teklif akisi da "cok isletme -> tek talep"tir. Yon BIREBIR.
--
--    YASAK TESTI (turu 91'de formullestirildi): bir migration yasagi ancak
--    AYNI KAVRAM + AYNI GORUNURLUK + AYNI AKTORLER ucu birden tutuyorsa
--    baglayicidir. Burada ucu de tutuyor.
--
--    GIZLI KAZANC (turu 89'un birebir tekrari): tablo DEGISMEDIGI icin
--    turu 90'da yazilan BES UC, yetki kapilari, `geri_cekildi` semantigi ve
--    1 saatlik bildirim bastirmasi **DOKUNULMADAN** miras alinir.
--
-- ⚠️ `durum`a CHECK YOK (044 karari) — 'secildi'/'elendi' MIGRATION
--    GEREKTIRMEZ. Beyaz liste Go'da: `basvuruDurumlari`.
-- ⚠️ DEFAULT ZORUNLU: hem mevcut satirlar icin hem "nil -> SQL NULL" tuzagi
--    icin (turu 75b/78b: NOT NULL sutuna nil gidince HER YAZMA 500 donuyordu).

ALTER TABLE ilan_basvurular
  ADD COLUMN IF NOT EXISTS fiyat_kurus BIGINT NOT NULL DEFAULT 0;

-- ⚠️ `created_at` REVIZEDE **KORUNUR** (bumplanmaz): isletme teklifini her
--    guncelledinde listenin BASINA ziplayabilseydi bu bir SPAM KAPISI olurdu
--    (044'teki "kosulsuz DO UPDATE = spam kapisi" dersinin aynisi).
-- ⚠️ Bu sutun ARAYUZDE CIZILIR ("revize edildi · 12:40"). Cizilmezse projenin
--    SEKIZ kez yasadigi "sutun var, okuyan yol yok" sinifina yeni ornek olur.
ALTER TABLE ilan_basvurular
  ADD COLUMN IF NOT EXISTS guncellendi_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Acik talep listesi. ⚠️ Index adinda TABLO + TUR oneki: ayni adli bir index
--    zaten varsa `IF NOT EXISTS` sessizce NO-OP olur ve yanlis index'e
--    guvenirsin (031 dersi).
CREATE INDEX IF NOT EXISTS idx_ilan_talep_liste
  ON ilanlar (kategori, created_at DESC)
  WHERE durum = 'yayinda' AND tur = 'talep';

CREATE INDEX IF NOT EXISTS idx_ilan_talep_il
  ON ilanlar (il, ilce, created_at DESC)
  WHERE durum = 'yayinda' AND tur = 'talep';

-- ═══════════════ 2) DIYET AYRIM KURALI — UC SATIR, DEGISTIRILEMEZ ═════════
--
--   (a) SATILABILIR paket/danismanlik   -> `isletme_urunleri` (tur='hizmet')
--       HERKESE ACIK; `isletme/modul.go` diyetisyen modulu turu 90b'de HAZIR.
--   (b) KISIYE OZEL kayit/olcum/liste   -> `diyet_kayit` (asagida)
--   (c) RIZA (kim kimin verisini gorur) -> `diyet_bag`   (asagida)
--
-- ⚠️⚠️ YAPMA: kisiye ozel diyet listesini `isletme_urunleri`ne yazma.
--    `GET /users/{id}/urunler` HERKESE ACIK ve `media/handler.go` urun dali
--    urun medyasini herkese acar -> **SAGLIK VERISI ANINDA SIZAR**.

-- ═══════════════ 3) DANISAN <-> DIYETISYEN RIZA KAYDI ═══════════════
--
-- ⚠️⚠️ BU TABLO KACINILMAZDIR ve gerekcesi teknik degil, HUKUKIDIR.
--    Mevcut hicbir tablo "bu kisi benim SAGLIK VERIMI gorebilir" rizasini
--    temsil etmiyor: `follows` tek yonlu sosyal takip; `randevular` TEK
--    SEFERLIK bir zaman dilimi; `chats` yalnizca mesajlasma. Riza kaydi
--    olmadan `diyet_kayit` okuma kapisi YAZILAMAZ.
--
-- ⚠️ `baslatan_id`: ONAYLAYAN, baslatanin KARSISINDAKI taraftir. Bu sutun
--    olmadan "kim onaylayacak" sorusu cevaplanamaz ve taraflardan biri KENDI
--    istegini KENDISI onaylayabilirdi.
-- ⚠️ SATIR SILINMEZ: iliski bitince `durum='sonlandi'`. Sonlanmis bag OKUMA
--    YETKISI VERMEZ (yuklem `durum='aktif'`) — yani gecmis korunur, erisim
--    korunmaz.
-- ⚠️ `durum` SERBEST METIN, CHECK YOK (043 gerekcesi). Beyaz liste Go'da.

CREATE TABLE IF NOT EXISTS diyet_bag (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    danisan_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    diyetisyen_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    baslatan_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- 'bekliyor' | 'aktif' | 'reddedildi' | 'sonlandi'
    durum          TEXT NOT NULL DEFAULT 'bekliyor',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    guncellendi_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- ⚠️ Ayni cift icin IKINCI satir ACILMAZ (`reports` 014 ve
    --    `ilan_basvurular` 044 deseni). Yeniden baslatma = AYNI satirin
    --    durumunu degistirmek. Aksi halde "sonlandi" bir satir dururken
    --    ikinci bir "aktif" satir acilabilir ve okuma kapisi DELINIRDI.
    UNIQUE (danisan_id, diyetisyen_id)
);

CREATE INDEX IF NOT EXISTS idx_diyet_bag_danisan
    ON diyet_bag (danisan_id, guncellendi_at DESC);
CREATE INDEX IF NOT EXISTS idx_diyet_bag_diyetisyen
    ON diyet_bag (diyetisyen_id, guncellendi_at DESC);

-- ═══════════════ 4) DIYET KAYDI — TEK TABLO, UC TUR ═══════════════
--
-- ⚠️⚠️ UC AYRI TABLO ACILMADI (`diyet_ogun` + `diyet_olcum` + `diyet_liste`).
--    Ucu de AYNI sahibe, AYNI riza kapisina ve AYNI tarih eksenine bagli;
--    ayri tablolar UC KEZ ayni yetki yuklemini yazmayi gerektirirdi ve bu
--    projede "ayni kuralin iki kopyasi drift eder" DORT kez sahaya cikti
--    (turu 72b/H, 75b, 78b, 80b). `tur` + `veri JSONB` deseni `ilanlar` ve
--    `isletme_urunleri`nde ZATEN kanitli.
--
-- ⚠️ `tur`a CHECK YOK: yeni bir kayit turu (su takibi, adim, uyku)
--    MIGRATION GEREKTIRMEZ. Beyaz liste Go'da (`diyetTurleri`).
--
-- ⚠️ `tarih` AYRI BIR `DATE` SUTUNU — `created_at`ten TURETILMEZ.
--    Gerekce: kullanici DUN yedigi bir ogunu BUGUN girebilir. Gunluk kalori
--    ozeti `created_at`ten gruplansaydi (a) gecmise kayit imkansiz olurdu,
--    (b) UTC ile yerel saat farki yuzunden gece yarisindan sonra girilen
--    ogun BIR ONCEKI gune yazilirdi.
--
-- ⚠️ `yazan_id` ve `user_id` AYRI: diyetisyen DANISANA liste yazar.
--    `user_id` = verinin SAHIBI (yetki bunun uzerinden), `yazan_id` = kaydi
--    OLUSTURAN. Tek sutun olsaydi "kimin listesi" ile "kim yazdi" ayrilamaz
--    ve danisan diyetisyenin listesini KENDI kaydi sanardi.
--
-- ⚠️ `durum`: 'aktif' | 'kaldirildi'. SILME UCU YOK — veri politikasi.

CREATE TABLE IF NOT EXISTS diyet_kayit (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    yazan_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- 'ogun' | 'olcum' | 'liste'
    tur        TEXT NOT NULL,
    tarih      DATE NOT NULL,
    ad         TEXT NOT NULL DEFAULT '',
    kalori     INTEGER NOT NULL DEFAULT 0,
    -- ogun : {ogun:"kahvalti", gram:150, protein:12.5, karbonhidrat:30, yag:8}
    -- olcum: {kilo:78.4, bel:92, boy:178, yag_orani:22.1}
    -- liste: {gunler:[{gun:"Pazartesi", ogunler:[{ogun:"kahvalti", metin:"..."}]}]}
    veri       JSONB NOT NULL DEFAULT '{}'::jsonb,
    durum      TEXT NOT NULL DEFAULT 'aktif',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Gunluk ozet ve tarih araligi sorgusunun BIREBIR karsiligi.
CREATE INDEX IF NOT EXISTS idx_diyet_kayit_kisi
    ON diyet_kayit (user_id, tarih DESC, tur)
    WHERE durum = 'aktif';

-- "Diyetisyenim bana ne yazdi" ve "hangi danisanima ne zaman liste verdim".
CREATE INDEX IF NOT EXISTS idx_diyet_kayit_yazan
    ON diyet_kayit (yazan_id, created_at DESC)
    WHERE durum = 'aktif';

CREATE INDEX IF NOT EXISTS idx_diyet_kayit_veri
    ON diyet_kayit USING GIN (veri);
