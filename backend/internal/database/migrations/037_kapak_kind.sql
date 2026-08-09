-- 037_kapak_kind.sql — TURU 78b: `media_assets.kind` CHECK'ine 'kapak' eklenmesi.
--
-- ⚠️⚠️⚠️ SEVK ENGELI (denetimde yakalandi, CANLI DB'DE DOGRULANDI).
--
--    FAZ A profil kapagi icin YENI bir medya turu tanimladi:
--      · `media/limits.go`  -> Tavanlar["kapak"] = 8 MB
--      · `media/sniff.go`   -> izinliTipler["kapak"] = jpeg/png/webp
--      · `users.UpdateMe`   -> `AND kind='kapak'` sartiyla bagliyor
--      · istemci            -> `yukle(kind: 'kapak', ...)`
--    ANCAK `media_assets.kind` sutunundaki CHECK 015'ten beri yalnizca
--    ('image','video','audio','document','avatar') kabul ediyordu:
--
--      media_assets_kind_check:
--        CHECK (kind = ANY (ARRAY['image','video','audio','document','avatar']))
--
--    Sonuc: `POST /media/upload` (presign) satiri INSERT ederken **CHECK
--    IHLALI** ile patlardi. Yani kapak gorseli **HICBIR ZAMAN YUKLENEMEZDI** —
--    kullanicinin gordugu: "Kapak seç" -> galeri -> yukleme -> HATA.
--    Kullanicinin ozellikle istedigi iki maddeden biri (arka plan resmi)
--    %100 OLU olacakti.
--
--    ⚠️ NEDEN HICBIR KONTROL YAKALAMADI: Go tarafi CHECK'i BILMEZ; `go build`,
--       `go vet` ve `flutter analyze` temiz. Kisit YALNIZ calisma aninda,
--       GERCEK Postgres'te patlar. Statik denetim bu sinifi GORMEZ.
--    📌 Ayni sinif turu 78 FAZ 6'da da yasandi (`ai_istekleri.durum` CHECK'i
--       'beklemede' kabul etmiyordu) — YENI BIR ENUM DEGERI KULLANIRKEN
--       SUTUNUN CHECK'INI MUTLAKA KONTROL ET.
--
-- ⚠️ DROP/ADD burada GUVENLI: yeni kume ESKISININ USTKUMESI, dolayisiyla
--    mevcut HICBIR satir ihlal etmez (kisit dogrulamasi tam tablo taramasi
--    yapar ama tablo kucuk ve deploy penceresinde).

ALTER TABLE media_assets DROP CONSTRAINT IF EXISTS media_assets_kind_check;

ALTER TABLE media_assets ADD CONSTRAINT media_assets_kind_check
    CHECK (kind IN ('image', 'video', 'audio', 'document', 'avatar', 'kapak'));
