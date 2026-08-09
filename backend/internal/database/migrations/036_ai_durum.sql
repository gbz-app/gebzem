-- 036_ai_durum.sql — TURU 78: AI KOTA REZERVASYONU icin durum genisletme.
--
-- ⚠️⚠️⚠️ SEVK ENGELI DUZELTMESI (kod okunarak yakalandi).
--
--    Turu 77b'de AI kotasi ATOMIK REZERVASYONA cevrildi: istek OpenAI'ya
--    gitmeden ONCE `ai_istekleri`ne `durum='beklemede'` ile bir satir aciliyor.
--    ANCAK migration 031'deki CHECK yalnizca ('tamam','hata') kabul ediyordu:
--
--        durum TEXT NOT NULL DEFAULT 'tamam' CHECK (durum IN ('tamam','hata'))
--
--    Yani rezervasyon INSERT'i **CHECK IHLALI** ile patlardi.
--
--    ⚠️⚠️ EN KOTU YANI: `kapi()` INSERT hatasini "satir donmedi = KOTA DOLDU"
--       diye yorumluyor ve kullaniciya **429 "Günlük yapay zekâ hakkın doldu"**
--       diyordu. Yani AI acildigi ANDA, HENUZ TEK ISTEK BILE ATILMAMISKEN
--       herkes "kotan doldu" mesaji alacakti — tamamen YANILTICI bir hata.
--
--    Bugun INERT: `OPENAI_API_KEY` yok, `kapi()` daha INSERT'e gelmeden 503
--    donuyor. Anahtar eklendigi GUN aktif olacakti.
--
-- ⚠️ CHECK'i DROP/ADD etmek migration tuzagi acabilir (015 dersi) ama burada
--    GUVENLI: tablo turu 77'de olusturuldu, uretimde SIFIR satir var (AI hic
--    calismadi) ve yeni kume ESKISININ USTKUMESI — mevcut hicbir satir
--    ihlal etmez.
-- ⚠️ 'iptal' de eklendi: kota sayimi `durum <> 'iptal'` uzerinden yapiliyor,
--    yani ileride bir istegi kotadan DUSURMEK gerekirse deger HAZIR olmali.
--    (Bugun yazan yol yok; sayim ifadesi onu ZATEN okuyor.)

ALTER TABLE ai_istekleri DROP CONSTRAINT IF EXISTS ai_istekleri_durum_check;

ALTER TABLE ai_istekleri ADD CONSTRAINT ai_istekleri_durum_check
    CHECK (durum IN ('beklemede', 'tamam', 'hata', 'iptal'));

-- ⚠️ KOTA SORGUSUNUN INDEKSI: `kapi()` her istekte
--    `WHERE user_id=$1 AND durum <> 'iptal' AND created_at > now() - 24h`
--    sayimini yapiyor. 031'deki `idx_ai_kota` yalnizca (user_id, created_at)
--    tasiyor; bu yeterlidir (durum suzgeci cok az satir eler) — YENI INDEX
--    EKLENMEDI. Gereksiz index yazma yukudur.
