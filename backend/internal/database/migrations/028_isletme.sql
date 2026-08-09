-- 028_isletme.sql — TURU 77: ISLETME PROFILLERI.
--
-- Kullanici emri: "isletme profilleri olacak, normal ve isletme profilleri".
--
-- ⚠️ ADDITIVE.
--
-- ═══════════ KARAR: `users` a TEK SUTUN, DETAYLAR AYRI TABLODA ═══════════
--
-- Iki secenek vardi:
--   (a) Butun isletme alanlarini `users` a sutun olarak ekle
--   (b) `users` a yalniz `hesap_turu`, detaylari AYRI tabloya
--
-- **(b) SECILDI.** Gerekce:
--  · `users` bu projede HER YERDE okunuyor — auth, arama, sosyal akis, sohbet
--    listesi, arama (call) katmani, hikaye seridi... `SELECT u.*` yapan bir yer
--    olmasa bile her yeni sutun index/satir boyutu ve bakim yuku demek.
--  · Isletme alanlari kullanicilarin KUCUK BIR AZINLIGINDA dolu olacak;
--    milyonlarca NULL sutun tasimanin anlami yok.
--  · Ama `hesap_turu` `users` DA OLMAK ZORUNDA: arama sonucunda, profilde ve
--    listelerde "bu bir isletme mi" bilgisi EK SORGU OLMADAN gerekiyor.
--    Ayri tabloda olsaydi her arama sonucu icin JOIN ya da N+1 dogardi.
--
-- ⚠️ `users.verified` ZATEN VAR ve "TELEFON DOGRULANDI" anlamindadir
--    (auth/handler.go: OTP sonrasi true olur). Isletme dogrulamasi BAMBASKA
--    bir seydir — bu yuzden ayri sutun: `isletmeler.dogrulandi`.
--    ⚠️ YAPMA: isletme dogrulamasi icin `users.verified` i kullanma; kullanirsan
--       telefonu dogrulanan HER kullanici "dogrulanmis isletme" gorunur.

ALTER TABLE users ADD COLUMN IF NOT EXISTS hesap_turu TEXT NOT NULL DEFAULT 'kisisel';

-- ⚠️ CHECK YOK (bilincli): ileride 'kurum'/'resmi' gibi turler eklenebilsin ve
--    migration tuzagi (015'te yasanan CHECK DROP/ADD sorunu) acilmasin.
--    Gecerli degerler UYGULAMADA dogrulaniyor (beyaz liste).

-- Isletme listelerinde/filtrelerinde kullanilir.
CREATE INDEX IF NOT EXISTS idx_users_hesap_turu
    ON users (hesap_turu) WHERE hesap_turu <> 'kisisel';

CREATE TABLE IF NOT EXISTS isletmeler (
    -- ⚠️ user_id BIRINCIL ANAHTAR: bir kullanicinin EN FAZLA BIR isletme profili
    --    olur. Ayri bir `id` konsaydi ayni kullaniciya iki kayit acilabilirdi.
    user_id      UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    -- Kategori ANAHTARI ('yemek','kafe','market'...). Serbest metin DEGIL ama
    -- CHECK de YOK — liste uygulamada (Go + Dart ORTAK sabit) tutuluyor.
    -- ⚠️ Kategori DB tablosuna alinmadi: sabit, kucuk ve nadiren degisen bir
    --    liste icin tablo + JOIN + yonetim ekrani gereksiz karmasiklik.
    kategori     TEXT NOT NULL DEFAULT 'diger',
    adres        TEXT NOT NULL DEFAULT '',
    il           TEXT NOT NULL DEFAULT '',
    ilce         TEXT NOT NULL DEFAULT '',
    telefon      TEXT NOT NULL DEFAULT '',
    web          TEXT NOT NULL DEFAULT '',
    -- Calisma saatleri: [{"gun":1,"acilis":"09:00","kapanis":"22:00","kapali":false}, ...]
    -- ⚠️ JSONB: 7 gun x 2 alan icin 14 sutun acmak semayi cirkinlestirir ve
    --    "carsamba ogle arasi" gibi ileride gelecek varyasyonlari kilitler.
    calisma      JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- Harita/uzaklik icin. 0 = konum girilmedi.
    enlem        DOUBLE PRECISION NOT NULL DEFAULT 0,
    boylam       DOUBLE PRECISION NOT NULL DEFAULT 0,
    -- ⚠️ ISLETME dogrulamasi — `users.verified` (telefon) ILE KARISTIRILMAZ.
    dogrulandi   BOOLEAN NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- "Bu kategorideki isletmeler" (hamburger menudeki Yemek/Restoran/Alisveris
-- kartlari BURAYA baglanir — o kartlar bugune kadar hicbir yere gitmiyordu).
CREATE INDEX IF NOT EXISTS idx_isletme_kategori ON isletmeler (kategori);
CREATE INDEX IF NOT EXISTS idx_isletme_il ON isletmeler (il, ilce);
