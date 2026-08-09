-- 027_story_editor.sql — TURU 77: HIKAYE EDITORU (metin katmani + metin hikayesi).
--
-- Kullanici emri: "storyde AA gibi, renk gibi, yazi tipi gibi ne varsa olacak".
--
-- ⚠️ ADDITIVE. ⚠️ `stories.kind` sutununda CHECK YOK (026'da bilerek boyle
--    birakildi) — bu yuzden yeni 'metin' turu icin migration tuzagi ACILMIYOR.
--
-- ═══════════ KARAR: METIN "PISIRILMEZ", META VERI OLARAK SAKLANIR ═══════════
--
-- Iki secenek vardi:
--   (a) Metni goruntunun ICINE PISIR (Flutter RepaintBoundary -> toImage -> yeni
--       gorsel yukle)
--   (b) Metni META VERI olarak sakla, izleyici medyanin USTUNE cizsin
--
-- **(b) SECILDI.** Gerekce:
--  · VIDEO hikayede pisirme MUMKUN DEGIL — video karelerine yazi gomemeyiz
--    (istemcide video yeniden kodlama = agir, yavas, pil yakan bir is ve bu
--    projede ffmpeg benzeri bir bagimlilik YOK). Pisirme secilseydi metin
--    YALNIZ fotografta calisirdi = yarim ozellik.
--  · Metin her cozunurlukte KESKIN cizilir (pisirilmis metin olceklenince bulanir).
--  · Kayit KUCUK: birkac yuz bayt JSON, yeni bir medya dosyasi YOK.
--  · Ileride "hikayeyi duzenle" mumkun kalir.
-- ⚠️ YAPMA: metni goruntuye pisirip `media_id`yi degistirme.
ALTER TABLE stories ALTER COLUMN media_id DROP NOT NULL;

-- Metin katmanlari. Bicim (istemci ile sunucu ARASINDAKI SOZLESME):
--   [{ "metin": "...", "x": 0.5, "y": 0.4, "boyut": 28, "renk": "#FFFFFF",
--      "font": "sade", "hiza": "orta", "kutu": "yok", "aci": 0.0 }]
--
-- ⚠️ x/y ORANDIR (0..1), PIKSEL DEGIL. Sebep: hikaye farkli en-boy oranlarinda
--    ve farkli ekranlarda cizilir; piksel saklansaydi metin kucuk telefonda
--    ekranin disina taşardi.
-- ⚠️ `boyut` da orana bagli olcektir (ekran genisliginin yuzdesi degil, mantiksal
--    punto) — izleyici `en kucuk kenar / 390` ile olcekler; bkz. istemci serhi.
-- ⚠️ JSONB, TEXT DEGIL: sunucu bicimi dogrulayabilsin ve ileride sorgulanabilsin.
-- ⚠️ '[]' VARSAYILAN (NULL DEGIL): NULL olsaydi istemcide her okumada null
--    kontrolu gerekirdi ve bir yerde unutulup CRASH ederdi.
ALTER TABLE stories ADD COLUMN IF NOT EXISTS katmanlar JSONB NOT NULL DEFAULT '[]'::jsonb;

-- SADECE METIN hikayesi icin zemin (Instagram deseni). Bos = medyali hikaye.
-- Deger bir GRADYAN ANAHTARIDIR ('mor','gun_batimi','okyanus'...), ham renk DEGIL:
-- ⚠️ Boylece zemin paleti ILERIDE degistirilebilir ve eski hikayeler de yeni
--    paletle dogru cizilir. Ham renk saklansaydi palet degisince eski hikayeler
--    paletin disinda kalirdi.
ALTER TABLE stories ADD COLUMN IF NOT EXISTS arka_plan TEXT NOT NULL DEFAULT '';

-- ⚠️ VERI BUTUNLUGU: bir hikaye ya MEDYALI olmali ya da METIN hikayesi olmali.
--    Ikisi de bossa izleyicide SIYAH BOS EKRAN cizilirdi (sessiz bozukluk).
ALTER TABLE stories DROP CONSTRAINT IF EXISTS stories_icerik_var;
ALTER TABLE stories ADD CONSTRAINT stories_icerik_var
    CHECK (media_id IS NOT NULL OR arka_plan <> '');
