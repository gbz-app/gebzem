-- 033_kapak_onay.sql — TURU 78: PROFIL KAPAGI + ONAYLI HESAP ROZETI.
--
-- Kullanici emri: "isletmelerde arka plan resmi, logo ortada; ayni sekilde
-- normal kullanicilarda da arka plan resmi olacak; onayli hesap ikonu da olsun".
--
-- ═════════════════════ (1) KAPAK: TEK SUTUN, users'TA ═════════════════════
--
-- ⚠️⚠️ `isletmeler` tablosuna AYRI kapak sutunu ACILMADI. Gerekce KODDA:
--    `isletme/handler.go` `KisiselYap` yalnizca `UPDATE users SET
--    hesap_turu='kisisel'` yapar; `isletmeler` SATIRI DURUR (veri politikasi).
--    Yani hesap turu ILERI-GERI cevrilebilen bir BAYRAKTIR. Kapak orada
--    tutulsaydi kullanici kisisele donunce kapagi KAYBOLUR, isletmeye donunce
--    GERI GELIRDI — kullaniciya aciklanamaz.
--
-- ⚠️⚠️ IKINCI (ve daha sinsi) GEREKCE: `users/takip.go` `Profile()` sorgusu
--    `hesap_turu` sutununu HIC OKUMUYOR; istemci isletme bilgisini AYRI ve
--    ASENKRON uctan aliyor (`profil_sayfasi.dart` -> `/users/{id}/isletme`).
--    Yani profil acildigi ANDA "bu bir isletme mi" BILINMIYOR. Iki sutunlu
--    tasarimda istemci once kisisel kapagi cizer, isletme detayi gelince kapak
--    DEGISIRDI = gorunur takilma. Tek sutunda bu karar HIC YOKTUR.
--
-- ⚠️ LOGO ICIN AYRI SUTUN DA ACILMADI: logo = mevcut `users.avatar_media_id`.
--    `avatar_media_id` sunucuda ~20 sorgu noktasinda okunuyor (sohbet listesi,
--    yorumlar, arama sonucu, cagri ekrani...). Ayri `logo_media_id` acilsaydi
--    ya o 20 noktaya `COALESCE(logo, avatar)` yazilacakti (biri unutulur —
--    bu sinif hata BES kez tekrarladi) ya da ayni isletme farkli yuzeylerde
--    FARKLI RESIMLE gorunecekti. Fark yalnizca CIZIMDE: isletmede kare-yuvarlak
--    kenar, kisiselde daire.
--
-- ⚠️ VERI SILINMEZ: expires_at / supurge YOK.

ALTER TABLE users ADD COLUMN IF NOT EXISTS kapak_media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;

-- ⚠️ INDEX ZORUNLU ("kucuk tablo" gerekcesiyle atlanmaz): medya kopma/temizlik
--    yollari referans sayimi icin bu sutunu tarar. 023 tam bu sebeple
--    `idx_users_avatar_media`yi eklemisti.
-- ⚠️ AD TABLO ONEKLI — bu projede `idx_isletme_kategori` cakismasi yasandi.
CREATE INDEX IF NOT EXISTS idx_users_kapak_media
    ON users (kapak_media_id) WHERE kapak_media_id IS NOT NULL;

-- ═══════════════════ (2) ONAYLI HESAP — YENI KAVRAM ═══════════════════
--
-- ⚠️⚠️⚠️ `users.verified` ROZETE BAGLANAMAZ. O sutun "TELEFON DOGRULANDI"
--    demek ve `auth/handler.go` OTP dogrulamasindan sonra KAYIT OLAN HERKESTE
--    true oluyor. Rozeti ona baglamak rozeti HERKESE gostermek, yani
--    ozelligi ANLAMSIZ kilmak ve kullaniciyi YANILTMAK olurdu.
--    ⚠️ YAPMA: rozeti `verified` sutununa baglama.
--
-- ⚠️⚠️ `isletmeler.dogrulandi` ZATEN VARDI ve **TAMAMEN OLUYDU**: 6 Go noktasi
--    + 8 Dart noktasi onu OKUYOR (rozet cizimi + `ORDER BY dogrulandi DESC`)
--    ama ONA YAZAN TEK BIR SATIR YOK ve admin ucu da YOK. Ustelik rozet iki
--    ekranda ELLE cizilmisti ve boyutlari ZATEN DRIFT ETMISTI.
--    KARAR: tek kavram `users.onayli`. `isletmeler.dogrulandi` sutunu
--    KALDIRILMAZ (veri politikasi + eski istemciler) ama artik TEK GERCEK
--    KAYNAK `users.onayli`dir ve sunucu `dogrulandi` JSON alanini ONDAN
--    doldurur. Boylece istemci degismeden dogru degeri gorur.
--    ⚠️ YAPMA: iki sutunu da yazan bir yol acma (drift'in ta kendisi).

ALTER TABLE users ADD COLUMN IF NOT EXISTS onayli BOOLEAN NOT NULL DEFAULT FALSE;

-- Mevcut (varsa) isletme onaylarini TEK KAYNAGA tasi.
-- ⚠️ Bugun sifir satir etkiler (sutun olu) ama migration YENIDEN
--    KOSTURULABILIR olmali ve ileride elle verilmis onaylar kaybolmamali.
UPDATE users u SET onayli = TRUE
  FROM isletmeler i
 WHERE i.user_id = u.id AND i.dogrulandi = TRUE AND u.onayli = FALSE;

-- ⚠️ KISMI INDEX: onayli hesap sayisi TOPLAMIN cok kucuk bir yuzdesi olacak;
--    `WHERE onayli` suzgeci ve `ORDER BY onayli DESC` havuzu bundan yararlanir.
CREATE INDEX IF NOT EXISTS idx_users_onayli
    ON users (onayli) WHERE onayli;

-- ⚠️⚠️ ROZETI KIM VERIR: ILK SURUMDE **ELLE SQL** ile.
--    Admin paneli su an YALNIZ IZLEME amacli; ustelik admin uclari `?key=` ile
--    JWT grubunun DISINDA, medya presign/commit ise JWT grubunun ICINDE —
--    yani admin panelinden BELGE/GORSEL YUKLENEMEZ. Onay kuyrugu bugun
--    yalnizca bir UUID listesi olurdu = KOR ONAY.
--    Verme komutu:
--      UPDATE users SET onayli = TRUE WHERE username = 'ornek';
--    ⚠️ YAPMA: otomatik kural koyma (ornegin "X takipciyi gecen onayli olsun").
--       Yaniltici bir "onayli" rozeti platform sorumlulugu dogurur.
