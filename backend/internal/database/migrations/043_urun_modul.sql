-- ⚠️⚠️⚠️ TURU 89 — KATEGORIYE OZEL ISLETME MODULLERI.
--
-- Kullanici emri: *"otel ekledin ama ODALAR var mi? isletme oda eklemeli,
-- doktorlar vs HIZMET ALANI eklemeli, belirli baslikli MODULLER olacakti"*.
--
-- ═══════════ NEDEN AYRI TABLO ACILMADI ═══════════
--
-- "Oda", "hizmet", "urun" icin uc ayri tablo acmak ILK BAKISTA temiz gorunur
-- ama bu projede UC AYRI MIGRATION bunu ISIMLE YASAKLIYOR:
--   · 030_ilan.sql:14   "YAPMA: hizmetler diye ikinci bir tablo acma"
--   · 038_randevu.sql:15 "YAPMA: rezervasyonlar diye ikinci bir tablo acma"
--   · 031_urun_ai.sql:12 "YAPMA: isletme_profilleri diye ikinci bir tablo acma"
--
-- Gerekce 030'da yazili: *"Ayri tablo secilseydi her tur icin yeni tablo +
-- yeni JOIN + yeni handler dali + yeni migration. Dort tur = dort kat is ve
-- her yeni tur yine migration isterdi. JSONB ile yeni tur SIFIR sema
-- degisikligi."*
--
-- ⚠️⚠️ GIZLI KAZANC (atlanmasi PAHALI olurdu): tablo DEGISMEDIGI icin
--    `media/handler.go` `erisebilir()` urun medyasi dali ve `ai_gorsel.go`
--    referans sayimi **DOKUNULMADAN** kalir. Yeni bir tablo acilsaydi bu iki
--    nokta sessizce bozulur ve hata YALNIZ IKINCI HESAPTA gorunurdu — bu
--    sinif turu 75b/77/78/78b'de DORT KEZ sahaya cikti.
--
-- ═══════════ NEDEN `tur`a CHECK KONMADI ═══════════
--
-- ⚠️ CHECK constraint bu projede IKI KEZ SEVK ENGELI uretti (036: `ai_istekleri
--    .durum`, 037: `media_assets.kind`): `go build` + `go vet` +
--    `flutter analyze` UCU DE TEMIZ gecer, hata YALNIZ gercek Postgres'te
--    cikar ve ozellik %100 OLU DOGAR. Beyaz liste Go tarafinda tutulur —
--    `reports.hedef_tur` (014) ve `isletmeler.kategori` (028) ile ayni karar.
--
-- ⚠️ DEFAULT degerler ZORUNLU: hem MEVCUT satirlar icin hem de "nil -> SQL
--    NULL" tuzagi icin (turu 75b/78b: `nil` deger NOT NULL sutuna gidince
--    HER YAZMA 500 donuyordu).

ALTER TABLE isletme_urunleri
  ADD COLUMN IF NOT EXISTS tur TEXT NOT NULL DEFAULT 'urun';

ALTER TABLE isletme_urunleri
  ADD COLUMN IF NOT EXISTS ozellikler JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ⚠️ GIN: `ozellikler` icinde arama/suzme ileride gerekecek (or. "2 kisilik
--    oda"). `ilanlar.ozellikler` ile AYNI desen (030_ilan.sql).
CREATE INDEX IF NOT EXISTS idx_urun_ozellikler
  ON isletme_urunleri USING GIN (ozellikler);
