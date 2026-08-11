# TURU 91 — BIRLESIK UYGULAMA PLANI

## 1. KARAR OZETI

**Tasarim 1 temel alindi** (talep = `ilanlar.tur='talep'`, teklif = `ilan_basvurular` + 2 sutun, diyet = 2 yeni tablo), **Tasarim 2'nin dort teshisi graftlandi**. Sebep: Tasarim 1 tek sevk edilebilir plan — her sunucu yetenegin adi konmus bir cagiran ekrani var; Tasarim 2 daha keskin teshis koyuyor ama sifir ekran/uc yaziyor (bu projede dokuz ozelligi olduren seklin ta kendisi).

**Uc sartli degisiklik hakem raporundan uygulandi:**
1. **Izgara menu geri alimi BU TURDAN CIKARILDI** — `hizmet_menusu.dart:178-186` kullanicinin acik emrini kayit altina almis ("kartlar 5 TANE ALT ALTA olacak"). Tek sutun KALIR; yerine olculmus tek satirlik bir duzeltme yapilir (bkz. bolum 5).
2. **"TALEP HERKESE ACIKTIR"** karari 045'in basina ve kullaniciya gosterilen forma ACIKCA yazilir (`media/handler.go:607-611` (g) dali dogrulandi: ilana bagli her gorsel `durum <> 'kaldirildi'` + engel disinda korumasiz).
3. **`internal/ilan/sutun_test.go` GENISLETILIR** — mevcut hali yalniz `handler.go` okuyor, degisen sorgu `basvuru.go:163`'te, yani muhafizin TAMAMEN DISINDA.

**Ek sadelestirme (plan disi karar):** `dugun` ISLETME KATEGORISI ACILMIYOR. Teklif verme kapisi kategori eslesmesine bagli degil; kategori eklemek `Kategoriler` + `isletme_servisi.dart:114` + `moduller` uclusunu gereksiz riske atardi. Hedefleme YALNIZ bildirim fan-out'unda, Go'daki `talepHedefKategori` haritasiyla yapilir.

---

## 2. MIGRATION 045

**Tek dosya:** `backend/internal/database/migrations/045_talep_diyet.sql`
(Bir onceki numara 044; sonraki tur **046**'dan baslar.)

```sql
-- 045_talep_diyet.sql — TURU 91: TEKLIF AKISI + DIYET TAKIBI
--
-- ADDITIVE. Hicbir sutun/tablo DUSURULMEZ, hicbir CHECK yeniden kurulmaz.
-- VERI SILINMEZ (kullanici karari 8 Agu): hicbir tabloda `expires_at` ya da
-- yas tabanli supurge YOKTUR. Talebin "7 gun sonra kapanmasi" OKUMA ZAMANI
-- yuklemidir (turu 81 zamanlanmis paylasim karari).
--
-- ═══════════ GORUNURLUK KARARI — KOD YAZMADAN ONCE OKU ═══════════
--
-- !! TALEP HERKESE ACIKTIR. `ilanlar` tablosunun her yerine "herkese acik"
--    gomulu: `idx_ilan_liste`, `GET /ilanlar`, `Detay`, favori ve en
--    onemlisi `media/handler.go:607-611` (g) dali — o dal tek kapi olarak
--    `i.durum <> 'kaldirildi'` + engel diyor, yani BIR ILANA BAGLI HER
--    GORSEL TUM OTURUM SAHIPLERINE ACIKTIR.
--
-- !! YAPMA: talep satirina isim / telefon / adres / "gizli butce" alani
--    EKLEME. Eklenecekse `ilanlar` YANLIS EVDIR ve (g) dali MIRAS
--    ALINAMAZ — "bu satir aslinda gizli" istisnasini ALTI sorguya ve BIR
--    GUVENLIK FONKSIYONUNA elle eklemek gerekir (turu 75b: engel yuklemi
--    dort sorguya kopyalanmis, BESINCISINDE dusmustu).
--
-- !! Talep formu kullaniciya "Bu talep herkese aciktir" der (ekran karari,
--    bolum 4).

-- ═══════════ 1) KARSI TEKLIF = `ilan_basvurular` + IKI SUTUN ═══════════
--
-- !! YENI TABLO ACILMADI (`teklifler` YAZILMADI). Gerekce, UC migration'da
--    ISIMLE yazili yasagin aynisi (030:14, 038:15, 031:12): `ilan_basvurular`
--    ZATEN "cok kisi -> tek ilan" istek/yanit iliskisidir ve teklif akisi da
--    "cok isletme -> tek talep"tir. Yon BIREBIR AYNI.
--    YASAK TESTI (turu 91'de formullestirildi): bir migration yasagi ancak
--    AYNI KAVRAM + AYNI GORUNURLUK + AYNI AKTORLER ucu birden tutuyorsa
--    baglayicidir. Burada ucu de tutuyor.
--
-- !! `durum`a CHECK YOK (044:42-46) — 'secildi'/'elendi' MIGRATION
--    GEREKTIRMEZ. Beyaz liste Go'da: `basvuruDurumlari`.
-- !! DEFAULT ZORUNLU: mevcut satirlar icin ve "nil -> SQL NULL" tuzagi icin
--    (turu 75b/78b: NOT NULL sutuna nil gidince HER YAZMA 500 donuyordu).

ALTER TABLE ilan_basvurular
  ADD COLUMN IF NOT EXISTS fiyat_kurus BIGINT NOT NULL DEFAULT 0;

-- !! `created_at` REVIZEDE KORUNUR (bumplanmaz): isletme teklifini her
--    guncelledinde listenin BASINA ziplayabilseydi bu bir SPAM KAPISI olurdu
--    (044/basvuru.go:94-96'daki "kosulsuz DO UPDATE = spam" dersinin aynisi).
-- !! Bu sutun ARAYUZDE CIZILIR ("revize edildi · 12:40"). Cizilmezse projenin
--    SEKIZ kez yasadigi "sutun var, okuyan yol yok" sinifina yeni ornek olur.
ALTER TABLE ilan_basvurular
  ADD COLUMN IF NOT EXISTS guncellendi_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Acik talep listesi (isletme gorunumu). Index adinda TABLO+TUR ONEKI
-- (031:39 dersi: ayni adli index sessizce NO-OP olur).
CREATE INDEX IF NOT EXISTS idx_ilan_talep_liste
  ON ilanlar (kategori, created_at DESC)
  WHERE durum = 'yayinda' AND tur = 'talep';

CREATE INDEX IF NOT EXISTS idx_ilan_talep_il
  ON ilanlar (il, ilce, created_at DESC)
  WHERE durum = 'yayinda' AND tur = 'talep';

-- ═══════════ 2) DIYET AYRIM KURALI — UC SATIR, DEGISTIRILEMEZ ═══════════
--
-- (a) SATILABILIR paket/danismanlik  -> `isletme_urunleri` (tur='hizmet').
--     HERKESE ACIK; `isletme/modul.go:135` diyetisyen modulu HAZIR.
-- (b) KISIYE OZEL kayit/olcum/liste  -> `diyet_kayit` (asagida).
-- (c) RIZA (kim kimin verisini gorur) -> `diyet_bag` (asagida).
--
-- !! YAPMA: kisiye ozel diyet listesini `isletme_urunleri`ne yazma.
--    `GET /users/{id}/urunler` HERKESE ACIK ve `media/handler.go:612-616`
--    (h) dali urun medyasini herkese acar -> SAGLIK VERISI ANINDA SIZAR.

-- ═══════════ 3) DANISAN <-> DIYETISYEN RIZA KAYDI ═══════════
--
-- !! BU TABLO KACINILMAZDIR ve gerekcesi teknik degil HUKUKIDIR. Mevcut
--    hicbir tablo "bu kisi benim saglik verimi gorebilir" rizasini temsil
--    etmiyor: `follows` tek yonlu sosyal takip; `randevular` TEK SEFERLIK
--    bir zaman dilimi; `chats` mesajlasma. Riza kaydi olmadan `diyet_kayit`
--    okuma kapisi YAZILAMAZ.
-- !! `durum` SERBEST METIN, CHECK YOK (043:27-31 gerekcesi).
-- !! `baslatan_id`: ONAYLAYAN, baslatanin KARSISINDAKI taraftir. Bu sutun
--    olmadan "kim onaylayacak" cevaplanamaz ve taraflardan biri kendi
--    istegini kendisi onaylayabilirdi.
-- !! SATIR SILINMEZ: iliski bitince `durum='sonlandi'`. Sonlanmis bag OKUMA
--    YETKISI VERMEZ (yuklem `durum='aktif'`).

CREATE TABLE IF NOT EXISTS diyet_bag (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    danisan_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    diyetisyen_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    baslatan_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- 'bekliyor' | 'aktif' | 'reddedildi' | 'sonlandi'
    durum          TEXT NOT NULL DEFAULT 'bekliyor',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    guncellendi_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Ayni cift icin IKINCI satir ACILMAZ (reports 014 / ilan_basvurular 044
    -- deseni). Yeniden baslatma = ayni satirin durumunu degistirmek.
    UNIQUE (danisan_id, diyetisyen_id)
);

CREATE INDEX IF NOT EXISTS idx_diyet_bag_danisan
    ON diyet_bag (danisan_id, guncellendi_at DESC);
CREATE INDEX IF NOT EXISTS idx_diyet_bag_diyetisyen
    ON diyet_bag (diyetisyen_id, guncellendi_at DESC);

-- ═══════════ 4) DIYET KAYDI — TEK TABLO, UC TUR ═══════════
--
-- !! UC AYRI TABLO ACILMADI (`diyet_ogun`+`diyet_olcum`+`diyet_liste`).
--    `ilanlar` (tur+JSONB) ve `isletme_urunleri` (043) ile BIREBIR AYNI
--    desen: uc kaydin da SAHIBI ayni, YETKI KAPISI ayni, zaman ekseni ayni.
-- !! `tur`a CHECK YOK — beyaz liste Go'da (`diyetTurGecerli`).
-- !! `tarih` ISTEMCIDEN GELIR, `CURRENT_DATE` YALNIZ YEDEKTIR. Sunucu UTC;
--    TR'de gece 00:00-03:00 arasi girilen ogun bir onceki gune yazilir ve
--    "bugunun kalorisi" YANLIS cikar. YAPMA: gunu sunucuda `now()`tan turetme.
-- !! `kalori` AYRI SUTUN (JSONB icinde DEGIL): gunluk toplam TEK SORGUDA
--    `SUM(kalori)` ile alinir (turu 17 N+1 dersi).
-- !! MEDYA SUTUNU YOK — bilincli (bkz. bolum 10).

CREATE TABLE IF NOT EXISTS diyet_kayit (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Kaydin AIT OLDUGU kisi (danisan). Yetki kapisi HEP buna bakar.
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Kaydi YAZAN kisi. 'liste'de diyetisyen, digerlerinde danisan.
    yazan_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- 'ogun' | 'olcum' | 'liste'
    tur        TEXT NOT NULL DEFAULT 'ogun',
    tarih      DATE NOT NULL DEFAULT CURRENT_DATE,
    ad         TEXT NOT NULL DEFAULT '',
    kalori     INTEGER NOT NULL DEFAULT 0,
    -- ogun : {"ogun":"kahvalti","miktar":"1 porsiyon","gram":150,
    --         "protein":12,"karbonhidrat":30,"yag":8}
    -- olcum: {"kilo":78.4,"bel":92,"boy":176,"yag_orani":21.5}
    -- liste: {"gunler":[{"gun":1,"ogunler":[{"ad":"Kahvaltı","kalori":320,
    --         "icerik":"2 yumurta..."}]}],"hedef_kalori":1800}
    -- NOT NULL + '{}': nil harita SQL NULL gonderir ve NOT NULL sutunu
    -- PATLATIR (turu 75b: HER YAZI GONDERISI 500 donuyordu).
    veri       JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- 'aktif' | 'kaldirildi'  (SATIR SILINMEZ)
    durum      TEXT NOT NULL DEFAULT 'aktif',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diyet_kayit_gun
    ON diyet_kayit (user_id, tarih DESC, tur) WHERE durum = 'aktif';
CREATE INDEX IF NOT EXISTS idx_diyet_kayit_yazan
    ON diyet_kayit (yazan_id, created_at DESC) WHERE tur = 'liste';
CREATE INDEX IF NOT EXISTS idx_diyet_kayit_veri
    ON diyet_kayit USING GIN (veri);
```

---

## 3. UC LISTESI

### A. Talep / teklif — YENI ROTA YOK (rota_test.go degismez)

| Yontem + yol | Degisiklik | Yetki | Govde / yanit |
|---|---|---|---|
| `POST /ilanlar` | **Genisletilir** (`handler.go:305`) | her oturum | `tur='talep'` de kabul; `Turler`e `talep` blogu eklenince `turGecerli` otomatik gecirir. Yeni: talep ise `h.talepBildir(ctx, ilanID, kategori, il)` fan-out (LIMIT 20). Yanit `{id}` DEGISMEZ. |
| `GET /ilan-kategoriler` | **Degismez** (`Agac`) | her oturum | `talep` turu + dallari + `Adim`li alanlar BURADAN doner. Istemci guncellemesi GEREKMEZ. |
| `GET /ilanlar?tur=talep&kategori=&il=&ilce=` | **Genisletilir** (`handler.go:410`) | her oturum | **SEVK ENGELI FIX:** `tur` BOSSA `AND i.tur <> 'talep'` eklenir; ayrica talep dalinda `AND i.created_at > now() - interval '7 days'`. |
| `GET /ilanlar?tur=talep&benim=1` | **Degismez** | sahibi | "Taleplerim" — `benim=1` dali tum durumlari donduruyor (kapanmis talepler de gorunur). |
| `GET /ilanlar/{id}` | **Degismez** | engellenmemis her oturum | Talep detayi. |
| `PATCH /ilanlar/{id}` | **Degismez** | sahibi | `{durum:'kaldirildi'}` = talebi iptal et. |
| `POST /ilanlar/{id}/basvuru` | **Genisletilir** (`basvuru.go:43`) | isletme hesabi, talep sahibi DEGIL | Govde `{not, fiyat_kurus}`. Degisiklikler: (a) `basvuru.go:67` kapisi `tur != "is" && tur != "talep"`, (b) talep dalinda `users.hesap_turu='isletme'` ZORUNLU, (c) `fiyat_kurus > 0` ZORUNLU, (d) 7 gunluk pencere YAZMA yolunda da uygulanir, (e) TEKLIF TAVANI 5 — `pg_advisory_xact_lock(hashtext('teklif:'||ilanID))` icinde, (f) `ON CONFLICT` dali `WHERE ilan_basvurular.durum IN ('bekliyor','goruldu','geri_cekildi')`, `created_at` KORUNUR, `guncellendi_at=now()`. |
| `DELETE /ilanlar/{id}/basvuru` | **Degismez** | teklifi veren | `durum='geri_cekildi'` (satir SILINMEZ). |
| `GET /ilanlar/{id}/basvurular` | **Genisletilir** (`basvuru.go:162`) | YALNIZ talep sahibi (baskasina 404) | SELECT + Scan + **YANIT HARITASI** UCUNE `b.fiyat_kurus` + `b.guncellendi_at` eklenir. Talep dalinda `ORDER BY b.fiyat_kurus ASC, b.created_at DESC`. |
| `PATCH /ilanlar/{id}/basvurular/{basvuruID}` | **Genisletilir** (`basvuru.go:204`) | talep sahibi | `basvuruDurumlari`ne `secildi`, `elendi`. `secildi` YAN ETKILI ve TEK ISLEMDE: kazanan `secildi` + `ilanlar.durum='satildi'` + digerleri `elendi` + kazanana `teklif_secildi` bildirimi. `RowsAffected>0` kapisi korunur. |
| `GET /users/me/basvurular?tur=talep` | **Genisletilir** (`basvuru.go:248`) | kendisi | `tur` suzgeci + `b.fiyat_kurus` eklenir. "Tekliflerim" ve "Basvurularim" AYNI uctan. |
| `POST /ilanlar/{id}/sohbet` | **Degismez** (`sohbet.go`) | teklif veren isletme | `sahibi == me` kapisi (sohbet.go:57) KORUNUR — pazarligi isletme baslatir. |

### B. Diyet — YENI (10 uc)

Rotalar `main.go`'da `r.Get("/isletme-modulleri", ...)` blogunun altina, tek grup halinde:

| Yontem + yol | Yetki | Istek / yanit |
|---|---|---|
| `POST /diyet/bag` | her oturum; diyetisyen tarafi icin `isletmeler.kategori='diyetisyen'` kapisi | `{diyetisyen_id}` **veya** `{danisan_id}` -> `{id, durum}`. `baslatan_id=me`, `durum='bekliyor'`. Bildirim `diyet_istek`. |
| `PATCH /diyet/bag/{id}` | `aktif` YALNIZ `baslatan_id <> me`; `reddedildi`/`sonlandi` her iki taraf | `{durum}` -> `{ok}`. **RIZA KAPISI.** |
| `GET /diyet/baglarim` | kendisi | `{baglar:[{id, diyetisyen_id, ad, username, avatar_media_id, durum, guncellendi_at}]}` |
| `GET /diyet/danisanlarim` | `kategori='diyetisyen'` isletme hesabi | `{danisanlar:[{... , son_liste_at, bugun_kalori}]}` — **TEK SORGU** (`LATERAL`), N+1 YASAK. |
| `POST /diyet/kayit` | `ogun`/`olcum` -> yalniz kendine (`user_id` yok sayilir, `me` yazilir); `liste` -> `diyet_bag(danisan_id=user_id, diyetisyen_id=me, durum='aktif')` ZORUNLU | `{user_id?, tur, tarih, ad, kalori, veri}` -> `{id}`. Bildirim `diyet_liste`. |
| `GET /diyet/kayitlar?user_id=&tur=&bas=&bit=` | `diyetErisim(ctx, me, hedef)` TEK KAYNAK; baskasina 404 | `{kayitlar:[...]}` |
| `PATCH /diyet/kayit/{id}` | kaydi YAZAN (`yazan_id`) veya SAHIBI (`user_id`) | `{ad?, kalori?, veri?, durum?}`. SILME UCU YOK. |
| `GET /diyet/ozet?user_id=&bas=&bit=` | `diyetErisim` | `{gunler:[{tarih, kalori}], son_olcum:{...}}` — `SUM(kalori) GROUP BY tarih` TEK SORGU, gruplama **`tarih`** sutunundan (`created_at`ten DEGIL). |
| `GET /diyet/besinler?q=` | her oturum | `{besinler:[{ad, kalori, gram, protein, karbonhidrat, yag}]}`. **TABLO YOK** — ~150 kalem Go'da gomulu (`internal/diyet/besin.go`), "kimseye ait olmayan LOOKUP". Buyurse AYRI lookup tablosuna tasinir; ASLA `isletme_urunleri`ne, ASLA kullanici basina satira. |
| `POST /ai/kalori` | AI acikken her oturum; kapaliysa 503 | `{metin?, media_id?}` -> `{ad, kalori, gram, protein, karbonhidrat, yag}`. `/ai/menu` (`ai/handler.go:526`) BIREBIR kalibi. **`h.kapi(w, r, "kalori")`** — "gorsel" YAZILMAZ (turu 79b sevk engeli). Sonuc DOGRUDAN KAYDEDILMEZ, ONERI doner. Sistem mesaji saglik tavsiyesi VERMEZ, "diyetisyenine danis" der. |

### C. Yeni Go dosyalari

- `backend/internal/diyet/handler.go` — 9 uc + `diyetErisim()` + `const diyetYuklemi`
- `backend/internal/diyet/besin.go` — gomulu liste + `Ara(q)`
- `backend/internal/ilan/talep.go` — `talepHedefKategori` haritasi + `talepBildir()` (fan-out LIMIT 20) + `const talepPenceresi = 7 * 24 * time.Hour` (okuma VE yazma yolu ayni sabiti kullanir)

---

## 4. EKRAN LISTESI (her satirda ULASILAN YOL zorunlu)

### Yeni dosyalar

| Dosya / ekran | Ne yapar | **NEREDEN ULASILIR** |
|---|---|---|
| `mobile/lib/features/talep/talep_ekranlari.dart` -> **`TalepAkisiEkrani`** | Ust: "Düğün mü, hizmet mi?" iki secenek; alt: dal listesi (dugun_organizasyon, dugun_fotografcisi, dugun_mekan, gelinlik, sac_makyaj, dugun_muzik, nikah_sekeri, davetiye, gelin_arabasi, dugun_pasta / tadilat, nakliyat, temizlik, ozel_ders, diyet_program). AppBar'da "Taleplerim" dugmesi. | **Hamburger menu -> "Düğün & Organizasyon" karti** (bolum 5). Ikincil: Profil -> "Taleplerim" -> AppBar "+". |
| ayni dosya -> **`TalepSihirbaziEkrani`** | Adim adim form; `ilan.Alan.Adim` alanina gore gruplanir, her adim TEK EKRAN, ustte ilerleme cubugu. Adimlar: 1) dala ozel sorular 2) tarih 3) il/ilce 4) butce 5) serbest not 6) ozet + **"Bu talep herkese aciktir"** uyarisi + gonder. | `TalepAkisiEkrani`'nda dal secilince. |
| `mobile/lib/features/diyet/diyet_servisi.dart` | 9 diyet ucu + `Besin`/`DiyetKayit`/`DiyetBag` modelleri + `diyetOzetProvider`. | (servis) |
| `mobile/lib/features/diyet/diyet_ekranlari.dart` -> **`DiyetimEkrani`** | Ustte gunluk kalori halkasi (alinan/hedef), tarih seridi, ogun bolumleri (Kahvaltı/Ara/Öğle/Ara/Akşam), altta "Diyetisyenim" karti (yoksa "Diyetisyen bul"). | **Hamburger menu -> "Diyet" karti** + **Profil -> "Diyetim"**. |
| ayni dosya -> **`OgunEkleSayfasi`** | Besin arama, miktar/gram, ogun secimi, kalori. AI acikken "Yapay zekâ ile hesapla". | `DiyetimEkrani` -> ogun bolumundeki "+" . |
| ayni dosya -> **`OlcumEkleSayfasi`** | kilo/bel/boy/yag orani; `CustomPainter` ile basit cizgi grafik (harici paket YOK). | `DiyetimEkrani` -> "Ölçüm ekle". |
| ayni dosya -> **`DiyetListesiEkrani`** | Diyetisyenden gelen liste (gunler -> ogunler). Her ogunde "Bugüne ekle" -> `tur='ogun'` kaydi (liste PLAN, kayit GERCEK). | `DiyetimEkrani` -> "Diyetisyenim" karti; ayrica `diyet_liste` bildirimi. |
| `mobile/lib/features/diyet/danisan_ekranlari.dart` -> **`DanisanlarimEkrani`** | Bekleyen istekler (onayla/reddet/sonlandir) + aktif danisanlar; danisana dokun -> ozet + gecmis + "Liste gönder". | **Profil -> "Danışanlarım"** (yalniz `isletme.kategori=='diyetisyen'`); ayrica `diyet_istek` bildirimi. |
| ayni dosya -> **`DiyetListeYazEkrani`** | Gun/ogun editoru; kendi katalogundan (`GET /users/me/urunler`) ogun secebilir. | `DanisanlarimEkrani` -> danisan -> "Liste gönder". |

### Degisen dosyalar (yeni ekran ACMADAN, turev)

| Dosya | Degisiklik | **ULASILAN YOL** |
|---|---|---|
| `mobile/lib/features/sosyal/hizmet_menusu.dart` | Iki yeni `_Bolum`: **"Düğün & Organizasyon"** -> `TalepAkisiEkrani`, **"Diyet"** -> `DiyetimEkrani`. Yerlesim MODELI DEGISMEZ (bolum 5). | anasayfa hamburger |
| `mobile/lib/features/home/home_screen.dart` (Profil sekmesi, ~satir 498 civari) | Dort yeni `ListTile`: **"Taleplerim"** (`LucideIcons.heartHandshake`) -> `IlanListesiEkrani(tur:'talep', benim:true, baslik:'Taleplerim')`; **"Diyetim"** (`LucideIcons.salad`) -> `DiyetimEkrani`; kosullu `hesap_turu=='isletme'`: **"Gelen talepler"** -> `IlanListesiEkrani(tur:'talep', baslik:'Gelen Talepler')` ve **"Tekliflerim"** -> `BasvurularimEkrani(tur:'talep')`; kosullu `isletme.kategori=='diyetisyen'`: **"Danışanlarım"**. **Ayrica mevcut kesif bosluğu kapatilir:** "Başvurularım" bugun YALNIZ `ilan_ekranlari.dart:167` AppBar'indan ulasiliyor -> profile de eklenir. | Profil sekmesi |
| `mobile/lib/features/ilan/ilan_ekranlari.dart` (`IlanDetayEkrani`, ~satir 793) | `ilan.tur=='talep'` dali: "Başvur" yerine **"Teklif ver"** (fiyat + mesaj sheet'i), kalan kontenjan ("5 teklifin 3'ü verildi"), sahibi ise **"Gelen teklifler"** -> `BasvuranlarEkrani(teklifModu:true)`. | menu/profil -> talep listesi -> detay |
| `mobile/lib/features/ilan/basvuru_ekranlari.dart` | `BasvuranlarEkrani({bool teklifModu})`: fiyat buyuk puntoyla, **fiyata gore sirali**, "revize edildi · HH:mm" (`guncellendi_at`), "Profili gör" / "Mesaj gönder" / **"Teklifi seç"** (onay diyalogu + `PopScope` + cift dokunus kilidi). `BasvurularimEkrani({String tur})`. `basvurSheet(...)` fiyat alani alir. | yukaridakiler |
| `mobile/lib/features/ilan/ilan_servisi.dart` | `Basvuru` modeline `fiyatKurus` + `guncellendiAt`; `teklifVer(ilanID, not, fiyatKurus)`; `basvurularim({tur})`. **Fiyat ayristirmasi TEK KAYNAK** (`kurusOku`) — ciplak `as num?` YASAK (turu 78b "0 URUN EKLENDI"). | (servis) |
| `mobile/lib/features/sosyal/bildirimler_sayfasi.dart` | `_tur()` switch'ine BES yeni tur; `_git()` icinde **`hedefTur=='ilan'` dali ayrisir**: `const isletmeyeGidenIlan = {'talep_yeni'}` -> talep detayina, degilse `BasvuranlarEkrani(teklifModu: tur=='teklif_geldi')`. `hedefTur=='diyet'` -> danisana `DiyetimEkrani`, diyetisyene `DanisanlarimEkrani`. | bildirimler |

> **Dikkat:** `bildirimler_sayfasi.dart:235-239` bugun `hedefTur=='ilan'`i KOSULSUZ `BasvuranlarEkrani`na goturuyor. `talep_yeni` bildirimi ISLETMEYE gider ve o ekran ona BOS liste gosterir. Bu dal AYRISTIRILMAZSA ozellik ilk gunden kirik gorunur.

---

## 5. KATEGORI IZGARASI — OLCULMUS KARAR

**KARAR: TEK SUTUN KALIR.** `hizmet_menusu.dart:178-186` kullanicinin emrini kayit altina almis ("kartlar 5 TANE ALT ALTA olacak; YAKINIMDA YUKARIDA AYRI"). Bu turda arkasinda hicbir kullanici istegi olmayan bir duzen degisikligi yapilmaz.

**Mevcut olculer:** satir `height: 62`, ayirici `10` -> adim **72dp**. Sheet tavani `0.82 * H`. Sabit ust blok (padding 10 + tutamak 4 + 16 + baslik 26 + 2 + alt baslik 17 + 14 + Yakinimda 78 + 18 + "KATEGORİLER" 15 + 10 + alt padding 20) = **230dp**.

Gorunur satir sayisi: `72n - 10 <= (0.82*H - 230)`

| Cihaz | Sheet | Liste alani | Tam gorunen satir |
|---|---|---|---|
| 360x640 | 524.8 | 294.8 | **4** (278dp; 5.'nin ~17dp'si) |
| 414x896 | 734.7 | 504.7 | **7** (494dp; 8.'nin ~11dp'si) |

Iki yeni kart eklenince kategori sayisi **14** olur (AI acikken; kapaliyken 13). Yani 360dp'de 10 satir kaydirilir.

**Uygulanacak TEK degisiklik — tavan `0.82 -> 0.92`:**

| Cihaz | Yeni liste alani | Tam gorunen satir |
|---|---|---|
| 360x640 | `0.92*640 - 230 = 358.8` | **5** (350dp) — kullanicinin istedigi sayi |
| 414x896 | `0.92*896 - 230 = 594.3` | **8** (566dp) |

360x640'ta sheet 588.8dp, ustte 51dp bosluk kalir (durum cubugu 24 + 27 gorunur zemin) — hala acikca bir sheet. `Flexible` + `ListView` kaydirma KORUNUR.

**Sira = kesif.** Iki yeni kart, kategorilerin **1. ve 2. sirasina** konur (Etkinlikler'in ustune): "Düğün & Organizasyon", "Diyet". Boylece 360dp'de kaydirma yapmadan gorunurler. Olcum: satir yuksekligini 62->58 veya Yakinimda'yi 78->66 yapmak 360dp'de **fazladan satir kazandirmiyor** (4'te kaliyor) — bu yuzden yapilmaz.

**`shrinkWrap: true` KALDIRILIR** -> `ListView.separated` `Flexible` icinde zaten sinirli yukseklik aliyor; `shrinkWrap` her karede 14 cocugu birden layout ettiriyor (bolum 6/madde 3).

**IZGARAYA DONULECEKSE (yalniz kullanici acikca isterse) — hazir blok:**
`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: 0.82)`; kart = `Column[Expanded(AspectRatio(1, gradyan, radius 18)), SizedBox(7), Text(12px w600 maxLines 1 ellipsis)]`.
Hucre genisligi 360dp'de `(360-32-20)/3 = 102.7` -> yukseklik `125.2`; 414dp'de `120.7` -> `147.2`. 14 kart = 5 satir. Gorunur: 360dp'de **2 satir = 6 kart**, 414dp'de **3 satir = 9 kart**. (Yani izgara daha yogun; ama emir tek sutun.)

---

## 6. PERFORMANS — "bir tik kasiyor" icin en cok etkili 5 is (siralı)

1. **Gorsel COZUNURLUK sinirlamasi (`memCacheWidth`) — EN BUYUK KAZANC.**
   `medya_gorsel.dart:119` `CachedNetworkImage`'a `memCacheWidth`/`maxWidthDiskCache` VERILMIYOR. 1600x1600 bir fotograf 120dp'lik izgara hucresi icin tam cozunurlukte decode ediliyor: kare basina ~10 MB gecici RAM + CPU. Duzeltme: `memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round()` (width null ise `kucuk ? 320 : 1080`). Liste kaydirmasindaki takilmanin birincil kaynagi budur.
2. **Ilk acilistaki N paralel `/media/{id}/url` istegi.**
   `_adresOnbellek` (`medya_gorsel.dart:80-92`) VAR ve dogru calisiyor, ama SOGUK acilista 60 hucre = 60 es zamanli Dio istegi -> baglanti havuzu doyuyor, ana isolate JSON cozmekle mesgul. Duzeltme: `MedyaServisi.adres` icine **es zamanlilik semaforu (6)** + ayni `mediaId` icin ucusan istegi paylasan `Map<String, Future>` (dedupe). Sunucu degisikligi GEREKMEZ.
3. **`shrinkWrap: true` kaldirma + `RepaintBoundary` + `const`.**
   `hizmet_menusu.dart:206` ve liste ekranlarindaki `shrinkWrap` tum cocuklari her karede layout ettirir. `Flexible` zaten sinirli yukseklik veriyor -> kaldirilir. Kart widget'lari `RepaintBoundary` ile sarilir ve gradyan `Container`lar `const` yapilabilecek yerlerde `const` olur.
4. **Liste sayfalamasi: `LIMIT 60 -> 20 + imlec.**
   `ilan/handler.go:410` her cagrida 60 satir + her satirda `media_kinds` alt sorgusu + favori `EXISTS` donduruyor. Ilk boyama 20 satirla belirgin hizlanir; `q` aramasindaki `ILIKE '%..%'` de yalniz 20 satir icin calisir. (`pg_trgm` GIN indexi ayri turun isi.)
5. **Olcum: `flutter run --profile` + DevTools Timeline, `--trace-skia` ile ILK olcum alinir.**
   Bu projede tekrar eden ders: "bir ozelligin calistiginin tek kaniti ona bakmaktir". 1-4 uygulanmadan once **bir baseline kare suresi** kaydedilir (Yakinimda + Ilanlar listesi kaydirmasi), sonra tekrar olculur. Olcusuz optimizasyon yapilmaz.

---

## 7. ADIM ADIM UYGULAMA SIRASI

Her adim **bagimsiz test edilebilir** ve sonunda `go build ./...` + `flutter analyze` + ilgili muhafiz kosulur; her adimda commit + push.

**Adim 0 — MUHAFIZI ONCE GENISLET (kod yazmadan).**
`internal/ilan/sutun_test.go`, `basvuru.go`'yu da okuyacak sekilde genisletilir (bkz. bolum 9). Sonra `basvuru.go:163` SELECT'inden bir sutun ELLE CIKARILIR ve testin **KIRMIZIYA DUSTUGU GORULUR**, sonra geri alinir. *Turu 89 dersi: bir muhafizin yesil olmasi gercekten olctugu anlamina gelmez.*
Test: `GOTMPDIR="$(pwd)/.gotmp" go test ./internal/ilan/...`

**Adim 1 — Migration 045 + atilabilir kopyada dogrulama.**
Sunucuda `CREATE DATABASE mig_dogrula` -> 001..045 sirayla `psql -v ON_ERROR_STOP=1` -> `DROP`. Gercek veriye dokunulmaz.
Test: migration 045 iki kez kosar (IF NOT EXISTS idempotent).

**Adim 2 — `ilan.Turler`e `talep` blogu + `Alan`a `Adim`/`Zorunlu` + iki yeni `Tip` (`cok_secim`, `tarih`), hepsi `omitempty`.**
Bagimlilik: yok. Test: `curl /ilan-kategoriler | jq '.[] | select(.anahtar=="talep")'`.

**Adim 3 — SEVK ENGELI FIX'I: `Liste`de `tur` bossa `AND i.tur <> 'talep'` + 7 gunluk pencere sabiti (`talep.go`).**
Bagimlilik: Adim 2. **Bu adim Adim 4'ten ONCE gelmeli** — aksi halde ilk talep genel Ilanlar listesini kirletir ve fark edilmeyebilir.
Test: talep olustur -> `GET /ilanlar` (tur bos) icinde GORUNMEMELI; `GET /ilanlar?tur=talep` icinde GORUNMELI.

**Adim 4 — `basvuru.go`: `fiyat_kurus` + `guncellendi_at` (SELECT + Scan + yanit haritasi UCU BIRDEN), `tur=='talep'` kapisi, isletme kapisi, advisory kilitli 5 tavani, revizyon `ON CONFLICT`, `secildi`/`elendi` + tek islemli yan etki.**
Bagimlilik: Adim 0, 1, 3. Test: Adim 0'daki muhafiz + elle iki hesapla curl.

**Adim 5 — `talepBildir()` fan-out + `bildirim.Metin()`e 5 yeni tur.**
Bagimlilik: Adim 4. Test: talep ac -> hedef isletmenin `GET /notifications`'inda `talep_yeni` gorunur; alici sayisi <= 20.

**Adim 6 — `internal/diyet` paketi (9 uc) + `diyetErisim()` TEK KAYNAK + `besin.go` + main.go rotalari + `rota_test.go` vakalari.**
Bagimlilik: Adim 1. `rota_test.go` vakasi ROTALARLA AYNI COMMIT'te (chi cakismasi calisma aninda panik atar, `go build` yakalamaz).
Test: `go test ./internal/rota/...` + iki hesapli curl (bag yokken 404, bag `aktif` olunca 200).

**Adim 7 — `POST /ai/kalori`.**
Bagimlilik: Adim 6. Ekledikten sonra `grep 'h.kapi(w, r,'` ile TUM cagri yerleri taranir (turu 79b kendi regresyonu). Test: `/ai/durum` kapaliyken 503; acikken metin -> gecerli JSON; metin kotasi duser, **gorsel kotasi DEGISMEZ**.

**Adim 8 — Flutter: `ilan_servisi.dart` modeli + `basvuru_ekranlari.dart` teklif modu + `ilan_ekranlari.dart` talep dali.**
Bagimlilik: Adim 4. Test: uygulamada talep detayindan teklif ver -> gelen tekliflerde fiyatla gorun.

**Adim 9 — Flutter: `talep_ekranlari.dart` (akis + sihirbaz).**
Bagimlilik: Adim 2 (alan tanimlari sunucudan gelir). **Her dinamik alana `ValueKey('$dal:${a.anahtar}')`** — turu 77b "hayalet veri". Test: dal degistir, onceki dalin degeri TASINMAMALI.

**Adim 10 — Flutter: diyet ekranlari + servisi.**
Bagimlilik: Adim 6, 7.

**Adim 11 — Flutter: `hizmet_menusu.dart` (2 kart + tavan 0.92 + `shrinkWrap` kaldirma) ve `home_screen.dart` (4 ListTile + "Başvurularım").**
Bagimlilik: Adim 9, 10 (ekranlar var olmali — "yakında" karti YASAK).
Test: 360x640 emulatorde 5 satir kaydirmasiz gorunur; yazi olcegi 1.5'te RenderFlex YOK.

**Adim 12 — `bildirimler_sayfasi.dart` 5 tur + `hedefTur=='ilan'` yon ayrimi + `hedefTur=='diyet'`.**
Bagimlilik: Adim 5, 10. Test: her bildirim turune dokunuldugunda DOGRU ekran acilir; hicbiri "X bir işlem yaptı"ya dusmez.

**Adim 13 — Performans (bolum 6, madde 1-4) + baseline/sonra olcumu.**

**Adim 14 — E2E (bolum 8) canli sunucuda, IKI+ hesapla; ardindan DB TRUNCATE.**

**Adim 15 — `flutter analyze` 0/0, `go build`+`go vet`+`go test ./...`, `utf8_test.go`, sonra KULLANICIYA SOR (kural 0).**

---

## 8. E2E KONTROLLERI (`tools/uctan_uca.js` — mevcut 276'nin ustune)

**Talep / teklif (14):**
1. A talep acar (`tur='talep'`) -> 201.
2. `GET /ilanlar` (tur BOS) -> A'nin talebi listede **YOK** (sizinti muhafizi).
3. `GET /ilanlar?tur=talep` -> talep **VAR**.
4. B (isletme) teklif verir `{not, fiyat_kurus:250000}` -> 200.
5. C (**kisisel hesap**) teklif verir -> **403** (isletme kapisi).
6. A kendi talebine teklif verir -> **400**.
7. `fiyat_kurus:0` ile teklif -> **400**.
8. A `GET /ilanlar/{id}/basvurular` -> B'nin teklifi ve **`fiyat_kurus` yanitta VAR** (yanit haritasi muhafizi).
9. D (**baska isletme**) A'nin teklif listesini ister -> **404** (403 DEGIL).
10. B teklifini revize eder (yeni fiyat) -> 200; `created_at` **DEGISMEDI**, `guncellendi_at` **DEGISTI**.
11. Alti isletme teklif verir -> 6.'si **409/400** (tavan 5, advisory kilitli).
12. A `PATCH .../basvurular/{id} {durum:'secildi'}` -> 200; talep `durum='satildi'`, diger teklifler `elendi`, B'ye `teklif_secildi` bildirimi.
13. Kapanmis talebe yeni teklif -> **404**.
14. 8 gun once acilmis talep (`created_at` elle geri alinir) -> listede YOK **ve** dogrudan POST **404** (arayuzun kurala uymasi, kuralin uygulandigi anlamina gelmez — turu 80b).

**Diyet (11):**
15. D (danisan) -> E (diyetisyen) bag ister -> `durum='bekliyor'`.
16. D kendi istegini `aktif` yapmaya calisir -> **403** (`baslatan_id <> me`).
17. E bagi `aktif` yapar -> 200.
18. **Bag YOKKEN** F (baska diyetisyen) D'nin kayitlarini ister -> **404**.
19. Bag `aktif` iken E, D'nin kayitlarini ister -> **200**.
20. E, D'ye `tur='liste'` kaydi yazar -> 201; `yazan_id=E`, `user_id=D`.
21. F, D'ye liste yazmaya calisir -> **403**.
22. D `tur='ogun'` kaydini `user_id=E` ile gondermeye calisir -> kayit **D'ye** yazilir (user_id yok sayilir).
23. `POST /diyet/kayit {tarih:'2026-08-11'}` -> `GET /diyet/ozet` gununu **`tarih`ten** gruplar (UTC kaymasi yok).
24. Bag `sonlandi` yapilir -> E artik **404** alir.
25. `PATCH /diyet/kayit/{id} {durum:'kaldirildi'}` -> `GET /diyet/kayitlar` icinde **YOK**, satir DB'de **DURUYOR**.

**AI (2):**
26. `/ai/kalori` cagrisi **metin** kotasindan duser, **gorsel** kotasi DEGISMEZ (turu 79b regresyon kaniti: metin 20->19, gorsel 10->10).
27. AI kapaliyken `/ai/kalori` -> **503**.

**Toplam: 276 -> 303.**

---

## 9. MUHAFIZLAR (kalici testler)

1. **`internal/ilan/sutun_test.go` — GENISLETILIR** (mevcut dosya, 51 satir).
   Bugun yalniz `handler.go` + `const sutunlar` okuyor. Eklenecek: `basvuru.go` okunur, `Basvurular` ve `Basvurularim` sorgularindaki SELECT sutun sayisi ile o fonksiyonlarin `rows.Scan` arguman sayisi karsilastirilir; ayrica **Scan edilip yanit haritasina konmayan alan** aranir (turu 78 `Profile()` sinifi: `internal/users/profil_yanit_test.go` kardesi).
   *Dogrulama zorunlu:* `fiyat_kurus` yanit haritasindan CIKARILIR -> test KIRMIZI duser -> geri konur.

2. **`internal/ilan/talep_test.go` — YENI: TALEP SIZINTI MUHAFIZI.**
   `handler.go` kaynagini okur ve `Liste` sorgusunda **`tur` bos iken `i.tur <> 'talep'` yuklemi VAR MI** diye bakar. Ayrica `talepPenceresi` sabitinin **iki yerde** (okuma `Liste`, yazma `BasvuruYap`) kullanildigini dogrular — turu 80b'nin "okuma ve yazma FARKLI TABAN kullaniyor" sinifi.
   *Dogrulama:* yuklem silinir -> KIRMIZI.

3. **`internal/diyet/yetki_test.go` — YENI: SAGLIK VERISI YETKI MUHAFIZI.**
   `handler.go` kaynagindaki her `SELECT ... FROM diyet_kayit` icin ya `diyetYuklemi` sabitinin ya da `diyetErisim(` cagrisinin AYNI fonksiyonda gectigini dogrular. Yuklem elle kopyalanmis (inline yazilmis) bir sorgu bulursa PATLAR.
   *Gerekce:* turu 75b'de engel yuklemi dort sorguya kopyalanmis, besincisinde dusmustu; burada bedeli KVKK ozel nitelikli veri.
   *Dogrulama:* bir sorguda `diyetErisim` cagrisi kaldirilir -> KIRMIZI.

4. **`internal/bildirim/tur_test.go` — YENI: BILDIRIM UCLUSU MUHAFIZI.**
   `bildirim.go` `Metin()` switch'indeki her `case` etiketini cikarir ve `mobile/lib/features/sosyal/bildirimler_sayfasi.dart` dosyasinda **o dizeyi arar**. Bulamazsa PATLAR.
   *Gerekce:* bu uyari kod tabaninda YAZILI olmasina ragmen UC KEZ ihlal edildi (turu 75b, 80b, 90b) ve her seferinde onay ile red ayirt edilemez oldu.
   *Dogrulama:* `teklif_secildi` Dart'tan silinir -> KIRMIZI.

5. **`internal/rota/rota_test.go` — VAKA EKLENIR.**
   Yeni `/diyet/*` grubu icin cozumleme vakalari: `/diyet/bag` (STATIK) vs `/diyet/kayit/{id}` (PARAMETRELI), `/diyet/kayit` vs `/diyet/kayitlar`, `/diyet/baglarim` vs `/diyet/bag/{id}`. Rota kaydiyla **AYNI COMMIT'te**.

6. **`internal/isletme/modul_test.go` — DOKUNULMAZ.** `dugun` kategorisi acilmadigi icin bu turda tetiklenmez; bu bilincli bir risk azaltmadir.

7. **`internal/sutunkontrol/utf8_test.go` — YENI DOSYALARI DA TARAMALI.** Sihirbaz formunda onlarca Turkce etiket var. `sed -i`/`perl -0pi` KULLANILMAZ; `Edit`/`Write` kullanilir ve degisiklik `grep`le dogrulanir (turu 89 CRLF dersi).

---

## 10. KAPSAM DISI (bilincli, durust gerekcelerle)

1. **IZGARA MENU GERI ALIMI — YAPILMADI.** `hizmet_menusu.dart:178-186` kullanicinin acik emrini kayit altina almis ("5 TANE ALT ALTA"). Duzeni degistirmek ayri bir turun isi ve **ancak kullanici isterse**. Yerine olculmus tek satirlik tavan duzeltmesi (0.82 -> 0.92) yapildi.

2. **`dugun` ISLETME KATEGORISI — ACILMADI.** Teklif verme kapisi kategoriye bagli degil ("Diğer" kategorili bir organizator yanlis eslesme yuzunden hic teklif verememesin). Kategori eklemek `Kategoriler` + `isletme_servisi.dart:114` + `moduller` uclusunu senkron tutmayi gerektirir ve ikisi guncellenip ucuncusu atlanirsa kategori sessizce `varsayilanModul`e duser (turu 90b'de birebir yasandi). Hedefleme YALNIZ bildirim fan-out'unda, Go'daki `talepHedefKategori` haritasiyla.

3. **DAGITIM DEFTERI (`talep_gonderim`) — ACILMADI.** Bedeli durustce: "talep kime gitti / kim gordu" **cevaplanamaz** ve "5 isletmeye gitti" **garanti edilemez**. Yerine: talep listesi herkese acik + teklif tavani 5 (advisory kilitli) + bildirim en fazla 20 isletmeye. Gerekce: dagitim tablosu tek basina yetmez, yanina "gorulme", "yeniden dagitim", "kapasite dolunca yeni isletme sec" mantigi gerekir ve bu, teklif ucreti modeli gelmeden yazilirsa "sutun var, okuyan yol yok" sinifinin **dokuzuncu** tekrari olur.

4. **TEKLIF UCRETI / KOMISYON / BAKIYE — YOK.** Isletme havuzu sifirdan kuruluyor; ilk gunden para isteyen bir pazaryerine isletme gelmez. Eklenirse kota rezervasyonu `pg_advisory_xact_lock` ile atomik olmali (turu 79b: GERCEK PARA).

5. **TEKLIF VERSIYON GECMISI — YOK.** `UNIQUE(ilan_id,user_id)` bir isletmeye tek satir verir; revizyon uzerine yazar ("3.000 demistin" kaniti kalmaz). Gecmis icin ya unique kaldirilmali (liste kirlenir, 5 tavani anlamsizlasir) ya da ayri `teklif_gecmis` tablosu gerekir. **Pazarlik kaydi zaten sohbette duruyor** (`chats.ilan_id`, 032).

6. **TARIH-ARALIGI / TUM-GUN REZERVASYON — YOK.** `randevular` SLOT bazlidir (038); `slot_kapasite` "ayni anda kac randevu" demektir, "o gun bos mu" DEMEK DEGILDIR. CLAUDE.md turu 89 ayni siniri otel icin zaten kapsam disi ilan etti. Dugun mekan musaitligi teklif akisinda mesajla konusulur.

7. **DIYET KAYDINDA FOTOGRAF — YOK.** Eklemek `media.erisebilir()`e ONUNCU dal gerektirir ve o dal mevcut dokuz dalin hicbirine benzemez: hepsi "herkese acik icerik + engel kapisi" iken bu "yalniz danisan + aktif bagli diyetisyen" olmali. Yanlis yazilirsa saglik verisi id bilen herkese sizar; unutulursa hata **yalniz ikinci hesapta** gorunur (turu 75b/77/78/78b'de dort kez sahaya cikti). Ayrica `medyayiKopar` referans sayimi ucuncu ayak. **Medya olmadigi icin bu turda `media` paketine HIC DOKUNULMUYOR.**

8. **GERCEK BESIN VERITABANI (TUBER/USDA) + BARKOD — YOK.** ~150 yaygin Turk yiyecegi Go'da gomulu. Tam veritabani lisans + ~10 bin satirlik seed + guncelleme sureci demek; barkod ayrica kamera + urun API'si ister. Kullanici elle kalori girebilir; AI tahmini var. **Buyurse AYRI lookup tablosuna tasinir** (uc sozlesmesi degismez); ASLA `isletme_urunleri`ne, ASLA kullanici basina satira.

9. **DIYETISYEN ONAYSIZ OTOMATIK DIYET PLANI — YOK.** `/ai/kalori` yalnizca bir yiyecegin kalorisini TAHMIN eder. `ai/handler.go:691-692` bu projede saglik tavsiyesi verilmeyecegini zaten karara baglamis; yanlis diyet tavsiyesi gercek zarar dogurur.

10. **DUGUN BUTCE TAKIBI / OTURMA PLANI / DAVETLI LISTESI — YOK.** "Taleplerim" ekrani bu turda taleplerin ve secilen tekliflerin ozetidir ve TURETILMISTIR (yeni tablo yok). Bu uc arac gercek veri modeli ister (davetli, masa, harcama kalemi) ve teklif akisindan bagimsiz calisir.

11. **TALEP SAHIBININ ISLETMEYE ILK MESAJI — YOK.** `sohbet.go:57`deki `sahibi == me` kapisi korunur; gevsetilseydi talep listesi bir REKLAM YUZEYINE donerdi. Teklif geldikten sonra ayni sohbetten yazilabiliyor.

12. **TALEP/TEKLIF ICIN AYRI WS OLAYI — YOK.** `bildirim.Duyur` zaten WS + push gonderiyor; ikinci olay tipi ikinci dinleyici demekti (turu 81b: `poll.vote` sunucuda uretiliyor, tuketen YOKTU).

---

### Ilgili dosyalar (mutlak yollar)

- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\ilan\basvuru.go` (kapi: satir 67 `if tur != "is"`; sorgu: 162; beyaz liste: 199)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\ilan\handler.go` (`Turler`: 93; `sutunlar`: ~200; `Liste` tur suzgeci: `AND ($2 = '' OR i.tur = $2)`)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\ilan\sutun_test.go` (genisletilecek muhafiz)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\media\handler.go` (satir 607-611 ilan dali, 612-616 urun dali — **dokunulmuyor**)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\isletme\modul.go` (satir 135 `diyetisyen` modulu — mevcut)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\ai\handler.go` (`kapi`: 285-393; `Menu`: 526)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\cmd\api\main.go` (ilan rotalari 276-291; ai 299-309)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\sosyal\hizmet_menusu.dart` (tavan 149; tek sutun karari 178-186)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\sosyal\bildirimler_sayfasi.dart` (`_git` 193; `hedefTur=='ilan'` dali 235-239)
- `C:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\medya\medya_gorsel.dart` (URL onbellegi 80-92; `CachedNetworkImage` 119 — `memCacheWidth` YOK)