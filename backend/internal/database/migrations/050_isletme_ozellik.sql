-- ⚠️⚠️⚠️ TURU 180 — ISLETME OZELLIKLERI + ODEME SECENEKLERI.
--
-- Kullanici emri (IKINCI kez): *"bilgi kisminda odeme secenekleri, ozellikler
-- yok; sigara icilmez, cocuk yeri vs — onlari da koyman gerekiyor"*.
--
-- ⚠️⚠️ TURU 176'DA BILEREK YAZILMAMISTI: `Isletme` modelinde ve sunucuda
--    boyle bir alan YOKTU ve sabit bir liste basmak *"bu isletme kredi karti
--    aliyor"* YALANI olurdu. Kullanici ozelligi tekrar isteyince dogru yol
--    ARAYUZE SAHTE LISTE KOYMAK DEGIL, alani ACMAKTIR.
--
-- ⚠️ **ADDITIVE**: yalniz iki sutun ekler, hicbir seyi DUSURMEZ -> mevcut
--    veriye dokunmaz, DB TRUNCATE gerektirmez.
--
-- ⚠️⚠️ **NOT NULL DEFAULT '{}'**: `nil` bir Go dilimi SQL NULL'a cevrilir ve
--    NOT NULL sutunda `23502` verir. Bu proje o hatayi turu 75b'de
--    `posts.media_ids` uzerinde YASADI (her yazi gonderisi 500 donuyordu);
--    yazan taraf DAIMA bos dilim gondermeli (bkz. `profil.TemizIlgi` deseni).
--
-- ⚠️ CHECK YOK: gecerli anahtar kumesi Go'da (`isletme.OzellikGecerli`).
--    036/037'de CHECK constraint IKI KEZ sevk engeli uretmisti — yeni bir
--    ozellik eklemek migration GEREKTIRMEMELI.
ALTER TABLE isletmeler
  ADD COLUMN IF NOT EXISTS ozellikler TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS odeme      TEXT[] NOT NULL DEFAULT '{}';
