-- ⚠️⚠️⚠️ TURU 94 — ISLETME VITRIN ALANLARI (kullanici emri).
--
-- Kullanici referans olarak bir yemek uygulamasi ekrani verdi ve kartlarda
-- **puan · teslimat suresi · minimum tutar · kampanya rozetleri** istedi.
-- Bu alanlarin HICBIRI projede YOKTU; iki turdur "yok, uydurmuyorum" denip
-- gecilmisti. Kullanici istegi TEKRARLADIGI icin artik GERCEK SUTUN olarak
-- ekleniyor — arayuzde sabit metin YAZILMIYOR.
--
-- ⚠️ HEPSI **OPSIYONEL** (NULL/0 = "bilgi yok"). Istemci NULL alani CIZMEZ;
--    sifir/bos deger gostermek "0 dakikada teslim" gibi YANLIS BILGI olurdu.
--
-- ⚠️⚠️ `puan` BIR **DEGERLENDIRME SISTEMI DEGILDIR** — bu sutun yalnizca
--    isletmenin/yoneticinin girdigi bir sayidir. Gercek puan icin
--    kullanicilarin oy verdigi ayri bir tablo + ortalama hesabi gerekir
--    (siparis/ziyaret dogrulamasiyla birlikte). O AYRI BIR IS.
--    ⚠️ YAPMA: bu sutunu "kullanici puani" diye sunma; bugun editoryal bir
--       degerdir ve arayuzde de oyle davranilmali.
--
-- ⚠️ `teslimat_dk_min/max`: TESLIMAT MODELI YOK (siparis, kurye, adres
--    dogrulama hicbiri yazilmadi). Bu iki sutun isletmenin BEYAN ettigi
--    tahmini suredir. ⚠️ YAPMA: buradan siparis akisi turetme.
--
-- ⚠️ `kampanyalar` JSONB **DIZI** (["300 TL indirim", ...]). Ayri tablo
--    ACILMADI: kampanya bugun yalnizca bir ETIKETTIR — kosulu, butcesi,
--    tarihi, kullanim sayaci YOK. Tablo acmak, doldurulmayacak on sutun
--    ve bos bir yonetim ekrani demekti (turu 77/89 dersi: alan tanimlanip
--    kullanan yol yazilmazsa OLU VERI olur).
--    ⚠️ Gercek kampanya motoru gerektiginde bu sutun MIGRATION ile tabloya
--       tasinir; istemci sozlesmesi (dize dizisi) DEGISMEZ.

ALTER TABLE isletmeler
    ADD COLUMN IF NOT EXISTS min_tutar_kurus BIGINT,
    ADD COLUMN IF NOT EXISTS teslimat_dk_min INTEGER,
    ADD COLUMN IF NOT EXISTS teslimat_dk_max INTEGER,
    ADD COLUMN IF NOT EXISTS puan NUMERIC(2,1),
    ADD COLUMN IF NOT EXISTS puan_sayisi INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS kampanyalar JSONB NOT NULL DEFAULT '[]'::jsonb;

-- ⚠️ Makul araliklar CHECK ile zorlanir: "3,6" bekleyen bir arayuze 47
--    gelirse kart bozulur ve sebebi ANLASILMAZ. Hata VERI GIRISINDE dussun.
-- ⚠️ `NOT VALID` KULLANILMADI: tablo bugun kucuk ve mevcut satirlarin hepsi
--    NULL (yeni sutun) — dogrulama maliyeti sifir.
ALTER TABLE isletmeler
    ADD CONSTRAINT isletmeler_puan_araligi
        CHECK (puan IS NULL OR (puan >= 0 AND puan <= 5)),
    ADD CONSTRAINT isletmeler_teslimat_araligi
        CHECK (
            (teslimat_dk_min IS NULL AND teslimat_dk_max IS NULL)
            OR (teslimat_dk_min > 0 AND teslimat_dk_max >= teslimat_dk_min
                AND teslimat_dk_max <= 600)
        ),
    ADD CONSTRAINT isletmeler_min_tutar_araligi
        CHECK (min_tutar_kurus IS NULL OR min_tutar_kurus >= 0);
