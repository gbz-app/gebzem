-- 052: ADMIN TURU — isletme aciklamasi + yonetim denetim kaydi + sikayet cozumu.
--
-- ⚠️ ADDITIVE: hicbir mevcut sutun/tablo degistirilmez, hicbir CHECK yeniden
--    kurulmaz. Mevcut sorgular AYNEN calisir -> DB TRUNCATE GEREKMEZ.
--
-- ══════════════════════════════════════════════════════════════════════════
-- 1) isletmeler.aciklama — ISTEMCI BUNU ALTI TURDUR BEKLIYOR
-- ══════════════════════════════════════════════════════════════════════════
-- Turu 180ae'de isletme karti "Preply mantigina" gecirilirken referans duzende
-- bir TANITIM SATIRI vardi; sunucuda karsiligi olmadigi icin yerine ADRES
-- cizilmisti. Turu 180af'te kullanici adresi ACIKCA reddetti (*"isletme
-- aciklama olsun, ACIK ADRES YAZMA"*) ve turu 180ag'de aciklama, kategori
-- etiketinin yerine tasindi. Istemcide `IsletmeOzet.aciklama` alani ACIK ama
-- sunucu onu HIC dondurmuyordu -> satir bugune kadar HIC cizilmedi.
--
-- ⚠️ 51 migration tarandi: `isletmeler` tablosunda `aciklama` YOKTU (kanit:
--    grep 'aciklama' migrations/*.sql -> yalniz `isletme_urunleri.aciklama`
--    ve `ilanlar.aciklama`).
--
-- ⚠️ NOT NULL + DEFAULT '': istemci `(m['aciklama'] ?? '').toString()` ile
--    okuyor; NULL birakmak her okuma yerinde null kontrolu gerektirir ve bir
--    yerde unutulup CRASH eder (028'de `calisma` icin alinan ayni karar).
ALTER TABLE isletmeler ADD COLUMN IF NOT EXISTS aciklama TEXT NOT NULL DEFAULT '';

-- ══════════════════════════════════════════════════════════════════════════
-- 2) admin_log — YONETIM DENETIM KAYDI
-- ══════════════════════════════════════════════════════════════════════════
-- ⚠️⚠️ NEDEN ZORUNLU: bu turda admin paneli ilk kez YAZMA yetkisi aliyor
--    (isletme olustur/duzenle/sil, kullanici askiya al, icerik kaldir).
--    Yazma yetkisi olan ama kim-ne-yapti kaydi olmayan bir panel, bir
--    hatanin ya da kotu niyetin GERI IZLENEMEZ olmasi demektir.
--
-- ⚠️ `aktor` bir UUID DEGIL METIN: admin girisi ADMIN_KEY ile yapiliyor,
--    yani panelin arkasinda bir `users` satiri YOK. Kullanici tabanli admin
--    rolleri gelirse bu sutun kullanici id'sini de tasiyabilir (bicim
--    suzgeci YOK, bilerek).
--
-- ⚠️ `oncesi`/`sonrasi` JSONB: degisiklikten ONCEKI ve SONRAKI degerler.
--    Yalniz "sildi" yazmak yetmez — neyin silindigi de kayitta olmali.
--    NULL olabilir (olusturma/silme islemlerinde bir tarafi yoktur).
--
-- ⚠️ Satirlar SILINMEZ (veri politikasi: VERI SILINMEZ). Buyume kaygisi icin
--    once OLCUM yapilir; denetim kaydi kucuktur.
CREATE TABLE IF NOT EXISTS admin_log (
    id         BIGSERIAL PRIMARY KEY,
    aktor      TEXT NOT NULL DEFAULT 'admin',
    eylem      TEXT NOT NULL,               -- isletme.olustur | kullanici.askiya_al | ...
    hedef_tur  TEXT NOT NULL DEFAULT '',    -- isletme | kullanici | urun | ilan | ...
    hedef_id   TEXT NOT NULL DEFAULT '',
    oncesi     JSONB,
    sonrasi    JSONB,
    ip         TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Panel kuyrugu: en yeni islem ustte.
CREATE INDEX IF NOT EXISTS admin_log_zaman_idx ON admin_log (created_at DESC);
-- "Bu kayda kim dokundu": hedef bazli gecmis.
CREATE INDEX IF NOT EXISTS admin_log_hedef_idx ON admin_log (hedef_tur, hedef_id, created_at DESC);

-- ══════════════════════════════════════════════════════════════════════════
-- 3) reports — SIKAYET COZUM IZI
-- ══════════════════════════════════════════════════════════════════════════
-- 014 sikayet tablosunu acmisti ve `durum` sutunu ZATEN var
-- ('yeni','incelendi','islem_yapildi','reddedildi'). Eksik olan sey, bir
-- sikayeti KIMIN ve NE ZAMAN kapattigiydi; bu olmadan "islem_yapildi"
-- kaydi hicbir seyi kanitlamaz.
--
-- ⚠️ `durum` CHECK'i YENIDEN KURULMUYOR (015 dersi: DROP/ADD CHECK iki kez
--    sevk engeli uretti). Yeni sutunlar tamamen additive.
ALTER TABLE reports ADD COLUMN IF NOT EXISTS cozen      TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS cozuldu_at TIMESTAMPTZ;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_notu TEXT NOT NULL DEFAULT '';

-- ══════════════════════════════════════════════════════════════════════════
-- 4) users.suspended_at — OLU SUTUN CANLANDIRILIYOR
-- ══════════════════════════════════════════════════════════════════════════
-- ⚠️⚠️ SUTUN `015_medya.sql:132`'den beri VAR ama kod tabaninda TEK BIR
--    OKUYAN/YAZAN YOK (olculdu: `grep -rn suspended --include=*.go` ->
--    SIFIR eslesme). Yani "askiya alma" altyapisi semada duruyor, urunde
--    HIC YOK: medya kotuye kullanimi icin dusunulmus, hicbir zaman
--    baglanmamis.
--
-- Bu migration sutuna DOKUNMAZ; yalnizca ONA BAGLI INDEKSI acar. Asil is
-- Go tarafinda: giris kapisi + admin ucu (bu turda yaziliyor).
--
-- ⚠️ KISMI INDEKS: askiya alinmis kullanici sayisi cok kucuk olacak; tam
--    indeks tablonun tamamini tasirdi.
CREATE INDEX IF NOT EXISTS users_askida_idx ON users (suspended_at)
    WHERE suspended_at IS NOT NULL;

-- Askiya alma SEBEBI — kullaniciya gosterilecek metin ("neden giremiyorum").
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspend_sebep TEXT NOT NULL DEFAULT '';
