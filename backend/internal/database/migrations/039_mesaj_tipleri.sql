-- ⚠️⚠️⚠️ TURU 81 — MESAJ TIPLERI: 'iban' ve 'etkinlik' EKLENDI.
--
-- Kullanici emri: "sohbette IBAN paylasma olsun, kisi paylasma, etkinlik
-- olusturma da olacak".
--
-- ═══════════ 015'IN "DOKUNMAYIN" SERHI VE BU MIGRATION ═══════════
--
-- migration 015 su serhi tasiyor:
--     "TUM GELECEK TIPLER BURADA. Sonraki hicbir migration bu kisita
--      DOKUNMAYACAK. (Sebep: birbirinden habersiz iki migration kisiti
--      yeniden kurarsa, sonra calisan oncekinin tiplerini SILER.)"
--
-- ⚠️ O serhin KORUDUGU SEY "tip kumesini sonsuza dek dondurmak" DEGILDIR;
--    korudugu sey **BIRBIRINDEN HABERSIZ IKI YENIDEN KURULUM**dur. Nitekim
--    ayni tuzak turu 79'da tasarim denetiminde yakalanmisti: bes ayri tasarim
--    "014" numarasini istiyor ve UCU `messages_type_check`i birbirinden
--    habersiz yeniden kuruyordu; alfabetik sirada en son calisan, oncekinin
--    tiplerini SESSIZCE silecekti.
--
-- ⚠️ BU MIGRATION O TUZAGA DUSMUYOR, cunku:
--    1. Kisit adi VARSAYILMIYOR — 015'te ACIKCA `messages_type_check` olarak
--       verilmis ve bu dosya onu ADIYLA dusuruyor.
--    2. Yeni kume ESKININ USTKUMESI: hicbir tip DUSURULMUYOR, yalnizca iki
--       tip EKLENIYOR. Yani bu migration iki kez kossa bile veri kaybi olmaz.
--    3. Ayni deseni migration **037** `media_assets.kind` icin ZATEN basariyla
--       uyguladi (DROP + ADD ... NOT VALID + VALIDATE).
--
-- ⚠️ YAPMA: bu kisiti baska bir migration'da TEKRAR yeniden kurma. Yeni tip
--    gerekirse SIRADAKI numarali migration'da, YINE bu desenle ve TUM mevcut
--    tipleri yazarak ekle.
--
-- ═══════════ NEDEN YENI TIP, NEDEN 'text' DEGIL ═══════════
--
-- IBAN ve etkinlik YAPISAL veridir; balon onlari ozel cizer (IBAN'da "Kopyala",
-- etkinlikte "Etkinligi gor"). `text` olarak gonderilselerdi:
--   · sohbet listesi onizlemesi ve PUSH bildirimi HAM icerigi basardi
--     ("TR33...|Ahmet" ya da "uuid|Konser"),
--   · balon onlari sIRADAN metin sanip dokunulamaz cizerdi.
--
-- ⚠️ 'contact' (kisi paylasma) ZATEN 015'te tanimliydi — o tip icin bu
--    migration GEREKMIYOR, yalnizca sunucu beyaz listesi + arayuz gerekiyordu.
-- ⚠️ 'poll' de 015'te tanimli (anket, sonraki faz).

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check;

ALTER TABLE messages ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text','image','video','audio','location','system',
                  'document','contact','poll','iban','etkinlik')) NOT VALID;

-- ⚠️ NOT VALID + ayri VALIDATE (015 ile ayni gerekce): yeni kume eskinin
--    ustkumesi oldugu icin tam tablo taramasi gereksiz; ACCESS EXCLUSIVE
--    kilit suresi milisaniyeye iner.
ALTER TABLE messages VALIDATE CONSTRAINT messages_type_check;
