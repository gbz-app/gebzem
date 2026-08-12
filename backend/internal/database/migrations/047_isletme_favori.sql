-- ⚠️⚠️ TURU 94 — ISLETME FAVORILERI.
--
-- Kullanici kategori ekraninin sag ustune **kalp (favoriler)** istedi.
-- Kalbin bir listeye gitmesi icin once FAVORILEMENIN bir yerde yapilabilmesi
-- gerekiyordu; aksi halde "dugme var, hicbir sey yapmiyor" sinifina yeni bir
-- ornek eklenirdi (bu projede DOKUZ kez sahaya cikti).
--
-- ⚠️ `ilan_favoriler` (030) YENIDEN KULLANILMADI: o tablo `ilanlar`a FK ile
--    bagli ve bir ilan ile bir ISLETME ayni kavram degil (ilan gecici bir
--    kayit, isletme kalici bir hesap). Ayni tabloya iki farkli hedef turu
--    sokmak, her sorguya bir `tur` suzgeci eklemek ve onu bir yerde unutmak
--    demekti.
--
-- ⚠️ PK **(user_id, isletme_id)**: ayni kisi ayni isletmeyi iki kez
--    favorileyemez. Ayri bir `id` sutunu + UNIQUE yerine dogrudan bileske
--    anahtar — sorgular zaten hep bu ikiliyle geliyor.
-- ⚠️ `ON DELETE CASCADE`: hesap silinince (KVKK) favori satiri da gider.
--
-- ⚠️ VERI SILINMEZ politikasi burada GECERLI DEGIL: favoriden cikarmak
--    kullanicinin ACIK eylemidir ve satirin kalmasi "hala favorimde mi"
--    sorusunu belirsiz kilardi. Bu bir ICERIK degil, bir TERCIH kaydi.

CREATE TABLE IF NOT EXISTS isletme_favoriler (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    isletme_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, isletme_id)
);

-- ⚠️ "Favorilerim" listesi EN YENI ONCE siralanir; PK (user_id, isletme_id)
--    bu siralamayi karsilamaz.
CREATE INDEX IF NOT EXISTS isletme_favoriler_kullanici_idx
    ON isletme_favoriler (user_id, created_at DESC);
