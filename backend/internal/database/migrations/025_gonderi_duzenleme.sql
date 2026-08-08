-- 025_gonderi_duzenleme.sql — TURU 76: gonderi DUZENLEME.
--
-- ⚠️ ADDITIVE.
-- ⚠️ `posts.tur` CHECK'ine DOKUNULMUYOR — 021'in serhi geregi. Karma medya
--    (foto + video ayni gonderide) YENI BIR TUR GEREKTIRMIYOR: `tur='foto'`
--    artik "GALERI (1-10 karma medya)" anlamina geliyor ve her medyanin
--    turu `media_assets.kind`ten okunup istemciye AYRI BIR DIZI olarak
--    (`media_kinds`) donuyor.
--    ⚠️ YAPMA: karma medya icin yeni bir `tur` degeri eklemek amaciyla CHECK'i
--       DROP/ADD etme; iki migration bagimsiz olarak kisiti yeniden kurarsa
--       sonra calisan oncekinin degerlerini SILER (015'te yasandi).

-- Duzenlenme damgasi. NULL = hic duzenlenmedi.
-- ⚠️ Instagram/X deseni: duzenlenen gonderide "düzenlendi" etiketi GORUNUR.
--    Sessizce degistirmek, baskalarinin yorum yaptigi bir icerigin altini
--    bosaltmaya izin verir (kotu niyetli kullanim).
ALTER TABLE posts ADD COLUMN IF NOT EXISTS duzenlendi_at TIMESTAMPTZ;
