-- ⚠️⚠️⚠️ TURU 96h — KULLANICI KONUMLARI (kayitli adresler).
--
-- Arayuz turu 96f'de konum secici ekledi ve konumlari CIHAZDA
-- (`SharedPreferences`) tutuyordu; o zaman sunucuda karsiligi YOKTU ve
-- durust sinir kodda yazildi: *"telefon degisince ya da uygulama silinince
-- adresler KAYBOLUR"*. Bu migration o borcu kapatir.
--
-- ⚠️ `ad` KULLANICIYA AITTIR, sabit bir kume DEGIL: "Ev"/"İş" yalnizca
--    arayuzdeki kisayollar. CHECK constraint konulsaydi kullanici
--    "Babaannem" yazamazdi ve istemci 500 alirdi.
--    (Turu 89 dersi: `tur`a CHECK koymak IKI KEZ sevk engeli uretti.)
--
-- ⚠️⚠️ AYNI KULLANICIDA AD **TEKIL**: istemci secili konumu INDEKSLE degil
--    ADLA tutuyor (liste sirasi degisince indeks BASKA konumu gosterirdi).
--    Iki "Ev" olsaydi hangisinin secili oldugu belirsizlesirdi.
--
-- ⚠️ Koordinat NOT NULL: adressiz bir "adres" satirinin kart mesafesine
--    hicbir katkisi yok; bos satir yalnizca listeyi kirletirdi.
--
-- ⚠️ VERI SILINMEZ politikasi: burada `ON DELETE CASCADE` VAR ve bu
--    ISTISNA DEGIL — kullanicinin KENDI hesabi silindiginde (KVKK) onun
--    adresleri de gitmelidir. Yas tabanli bir supurge YOK.
CREATE TABLE IF NOT EXISTS user_adresler (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ad         TEXT NOT NULL,
  enlem      DOUBLE PRECISION NOT NULL,
  boylam     DOUBLE PRECISION NOT NULL,
  secili     BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS user_adresler_ad_uq
  ON user_adresler (user_id, ad);

-- ⚠️ Liste sorgusu HER ZAMAN kullaniciya gore filtreler; indeks o yuzden
--    `user_id` ile baslar. Sira `created_at` (eklenme sirasi korunur).
CREATE INDEX IF NOT EXISTS user_adresler_kullanici_idx
  ON user_adresler (user_id, created_at);

-- ⚠️⚠️ **AYNI ANDA EN FAZLA BIR SECILI ADRES.** Kisimli tekil indeks bunu
--    VERITABANI SEVIYESINDE dayatir; uygulama katmaninda "once hepsini
--    false yap, sonra birini true yap" iki deyimdir ve arada bir istek
--    araya girerse IKI SECILI adres kalirdi.
CREATE UNIQUE INDEX IF NOT EXISTS user_adresler_tek_secili
  ON user_adresler (user_id) WHERE secili;
