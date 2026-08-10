# Gebzem Projesi — Claude Kuralları

WhatsApp + Twitter Spaces + TikTok Live karışımı sosyal uygulama. Hedef: ~50K kullanıcı, Türkiye pazarı. Domain: gebzem.app

## ZORUNLU KURALLAR (kullanıcı emri)
0. **BUILD ALMADAN ÖNCE SOR** (31 Tem emri) — kod hazır olsa bile derlemeyi/yayını
   kullanıcı "al" demeden başlatma. Kod yaz, analiz et, commit+push et, sonra SOR.
1. **Her oturumda `oturum.md` güncellenir** — yapılanlar, denenenler (oldu/olmadı), kararlar, devir notları. Oturum başında OKU, her önemli adımdan sonra GÜNCELLE (sadece oturum sonunda değil!).
2. **Bu dosya (CLAUDE.md) da güncel tutulur** — proje durumu/komutlar/uçlar değiştikçe.
3. **Her adımda git push** — her anlamlı değişiklik commit + push edilir; başarı `git rev-parse origin/main` karşılaştırmasıyla doğrulanır.
4. **Onaysız işlem yok** — kullanıcı "yap" demeden kurulum/silme/deploy yapma. Önce öner, onay gelince uygula.
5. **Kısa yaz** — uzun tablolar yok; net cevap + gereken aksiyon.
6. **`.env.infra` ve `backend/.env` ASLA git'e girmez** (.gitignore'da — değiştirme!)
7. Türkçe konuş.
8. **"Devam eden iş" izlenebilirliği (18 Tem):** aktif iş sürerken oturum.md'deki adım listesi
   ([ ]→[x]) HER ADIMDAN SONRA güncellenip push'lanır; aşağıdaki ŞU AN DEVAM EDEN İŞ bloğu da
   senkron tutulur. Amaç: pencere kapansa bile tam kalınan yerden devam edilebilmesi.

## ŞU AN DEVAM EDEN İŞ (canlı — her adımda güncelle, iş bitince "YOK" yaz)
- **KALDIGIMIZ YER (10 Agu 04:30): TURU 81 KODU BITTI, BACKEND DEPLOY EDILDI**
  (**3efe91e**; migration 001->041 atilabilir kopyada dogrulandi, canlida
  uygulandi = 51 tablo) + health ok, DB TRUNCATE edildi.
  ✅ **CANLI SUNUCUDA 208/208 UCTAN UCA GECTI** · **192 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata 0 uyari**.
  Build tetiklendi: android **31355519304** · ios **31355521019**.
- **TURU 81 — YEDI OZELLIK** (kullanici istegi): medya olcusu (3. kez) · ses
  paylasma · konum · anket · ileri tarihli paylasim · IBAN/kisi/etkinlik ·
  acik-koyu tema + Ayarlar · 4 ekran onboarding · bolme secici (yazi).
- ⚠️⚠️⚠️ **TURU 81 — ONCE KESIF YAPILDI (9 alt sistem, KOD YAZMADAN).**
  Bu adim olmasaydi isin YARISI YENIDEN YAZILACAKTI, cunku cogunun altyapisi
  ZATEN VARDI ve yalnizca BAGLANMAMISTI:
  · **SES**: kayit + genlik + sunucu alanlari + oynatma balonu HEPSI calisiyor;
    eksik olan `onTap` ve `kayitSeridi()`nin CAGRILMAMASIYDI.
  · **KONUM**: `location` tipi DB CHECK'inde ve sunucu beyaz listesinde VARDI.
  · **KISI**: `contact` tipi CHECK'te VARDI, Go beyaz listesi REDDEDIYORDU.
  · **ANKET**: `docs/medya-arastirma/tasarim-anket.md` icinde **669 satirlik
    tam muhendislik tasarimi** duruyordu.
  ⚠️ **DERS: buyuk bir istek geldiginde ONCE "bunun ne kadari zaten var?"
     diye SOR.** Bu projede ozelliklerin buyuk kismi "yazilmis ama
     baglanmamis" durumda.
- ⚠️⚠️⚠️ **TURU 81 — MEDYA OLCUSU: MODEL TERSINE DONDU (kullanicinin UCUNCU
  sikayeti).** Kullanici: *"tek fotograflarda BAZILARI GENISLIK DAHA AZ
  BAZILARI BUYUK, bunun mantigi nedir, BIZIM DE BOYLE OLMASI GEREKIYOR"*.
      ESKI: genislik sabit -> yukseklik hesaplanir -> `cover` KIRPAR (%41-51)
      YENI: **yukseklik sabit -> genislik ORANDAN gelir -> KIRPMA YOK**
  ⚠️ ON KOSUL: `media_assets.width/height` 015'ten beri VARDI, presign ucu
     kabul ediyordu, `yukle()` parametreleri tasiyordu — ama **17 CAGRI
     YERININ HICBIRI DEGER GECMIYORDU**. Sutun bastan beri OLUYDU.
  ⚠️ Olcum **`yukle()` ICINDE** yapilir, CAGRI YERLERINDE DEGIL (17 yerden
     biri kesin unutulurdu). Gorselde `ui.ImageDescriptor.encoded` (yalniz
     BASLIK okunur; tam decode 1600x1600 icin ~10 MB gecici RAM demekti).
  ⚠️ `media_boyut` ("WxH") **`medyaTurleri` sabitine** eklendi — o sabiti YEDI
     sorgu da kullandigi icin "6'ya ekleyip 7.'yi atlama" hatasi YAPISAL
     OLARAK imkansiz.
  ⚠️ Coklu galeri **`PageView` -> `ScrollController` + `ListView`**: `PageView`
     TANIM GEREGI esit genislik ister. Turu 76b'nin yasagi `ListView`in
     KENDISINE degil **`PageScrollPhysics`e** aitti (sabit-viewport varsayimi).
     ⚠️ YAPMA: buraya `PageScrollPhysics`/`snap` ekleme.
- ⚠️⚠️ **TURU 81 — SES: OZELLIK VARDI, KESFEDILEMEZDI.** Mikrofonda YALNIZ
  `onLongPressStart/End` vardi (`onTap` YOK) ve `kayitSeridi()` REPODA
  HICBIR YERDEN CAGRILMIYORDU — serhi *"turu 74b'de duzeltildi"* dese de
  yalnizca `kayitAlani()` baglanmisti. Genlik 100ms'de bir okunuyordu ama
  YALNIZCA sunucuya gonderilmek uzere; kayit aninda HICBIR SEY cizilmiyordu.
  ⚠️ **DERS: "test edildi" yazan bir ozellik KESFEDILEBILIR mi diye ayrica sor.**
- ⚠️⚠️ **TURU 81 — ANKET: TASARIMIN KENDI TUZAGINA DUSMEDIK.** Tasarim
  `messages_type_check`i YENIDEN KURUYORDU; migration 039 (ayni tur) onu
  ZATEN kurmustu. Tasarimin yazdigi kume `document`, `contact`, `iban`,
  `etkinlik` tiplerini ICERMIYOR ve calissaydi **DORDUNU BIRDEN SESSIZCE
  DUSURURDU**. Migration 040 kisita HIC DOKUNMUYOR.
  ⚠️ 015'in "DOKUNMAYIN" serhinin korudugu sey tip kumesini DONDURMAK DEGIL,
     **BIRBIRINDEN HABERSIZ IKI YENIDEN KURULUM**dur.
- ⚠️⚠️ **TURU 81 — ZAMANLANMIS PAYLASIMDA SUPURGE YOK (tasarim kazanci).**
  Akis OKUMA ZAMANI calistigi icin (turu 75) `yayin_at <= now()` yuklemi
  yeterli. Bir sweeper'dan yalniz daha basit degil **DAHA GUVENLI**: sweeper
  calismazsa gonderi HIC yayinlanmaz ve kullanici sebebini bilemez.
  ⚠️ `created_at = yayin_at` YAZILIR: siralama ve imlec `created_at` uzerinden
     yuruyor; olusturma ani birakilsaydi yarina zamanlanan gonderi
     yayinlandiginda **DUNUN SIRASINDA** belirip GOMULURDU.
- 🛡️ **TURU 81 — YENI MUHAFIZ: `internal/social/yayin_test.go`.**
  Mevcut `sutun_test.go` YALNIZCA SELECT sutun listesini dogruluyor,
  **WHERE yuklemini DEGIL** — yani yuklem bir sorguda eksik kalirsa
  YAPISAL OLARAK yakalayamaz. Yeni muhafiz **ANINDA GERCEK BIR BOSLUK BULDU**
  (`erisebilirMi`: yayinlanmamis gonderi ETKILESIME ACIKTI).
  ⚠️ Calistigi, yuklem BIR SORGUDAN CIKARILIP test kirmiziya dusurulerek
     KANITLANDI. Denetim ayrica muhafizin **IKI YUZEYDE calismadigini** buldu
     (arama deseni `FROM posts p JOIN users` idi) -> `FROM posts p`ye
     genisletildi; 9 sorgu taraniyor, iki mesru istisna GEREKCESIYLE yazili.
- ⚠️⚠️⚠️ **TURU 81b — DENETIM: 31 AJAN, 25 BULGU -> 21 ONAYLANDI, 6 SEVK
  ENGELI. HEPSI DUZELTILDI.** En agirlari:
  · **ACIK TEMADA TUM SOHBET OKUNAMAZ**: balon renkleri SABIT KOYU, icindeki
    yazi TEMADAN (acik temada siyah) -> **1.23:1 kontrast** (olculdu). Turun
    getirdigi acik tema, uygulamanin EN COK KULLANILAN ekranini yok ediyordu.
    FIX: `ChatColors` `brightness`e baglandi.
    ⚠️ **DURUST SINIR: kod tabaninda ~500 sabit renk noktasi var**; tema
       iskeleti dogru olsa da o noktalar acik temada TEMANIN DISINDA kalir.
       Sohbet EN KRITIGIYDI ve kapatildi; digerleri kademeli cevrilmeli.
  · **BASILI TUT BOZULDU**: kayit baslayinca `build()` seride donuyor ->
    mikrofonun `GestureDetector`i AGACTAN SILINIYOR -> `onLongPressEnd` BIR
    DAHA CALISAMAZ -> parmagini kaldiran kullanicinin kaydi 10 dk tavana
    kadar TAKILI kaliyordu. Serhim *"WhatsApp deseni KORUNDU"* diyordu —
    **KORUNMAMISTI** (projenin en sik sinifi, kendi eklememde).
    ⚠️ Jest ONARILMADI **KALDIRILDI**: serit tasarimiyla YAPISAL OLARAK
       bagdasmiyor ve kullanici zaten "bir defa tiklama yeterli" dedi.
  · **CANLI DALGA HIC CIZILMIYORDU**: `shouldRepaint` AYNI liste nesnesinin
    uzunlugunu KENDISIYLE karsilastiriyordu -> her zaman `false`. Uzunluk
    artik KURULUM ANINDA yakalaniyor.
  · **`poll.vote`/`poll.closed` ISTEMCIDE DINLENMIYORDU** (sunucu uretiyor,
    tuketen yok) — biri oy verdiginde digerlerinin ekraninda HICBIR SEY
    degismiyordu.
  · **SOHBET LISTESI ONIZLEMESI HAM ICERIK BASIYORDU**: sunucudaki switch
    duzeltilmisti ama **ISTEMCININ KENDI KOPYASI** atlanmisti -> listede
    `TR33...|Ahmet` gorunurdu (**IBAN SIZINTISI**, ayrica PUSH'a da giderdi).
  · **ZAMANLANMIS GONDERI GECMISE YAYINLANIYORDU** (siralama `created_at`).
  · **WS DUZELTMEM `mine` ALANLARINI EZIYORDU**: yayin govdesi ORTAKTIR
    (sifir UUID), yani `mine` her secenekte false. Dogrudan atayinca BASKA
    BIRI oy verdiginde **KULLANICININ KENDI OYU EKRANDAN SILINIYORDU**.
    FIX: `yayinlaBirlestir()` — sayimlar yayindan, `benim` YERELDEN.
- ⚠️⚠️ **TURU 81 — KENDI BULDUKLARIM (denetim beklerken):**
  · **ANKET YAYINI HIC YAPILMIYORDU**: `anketOku(ctx, pollID, "")` — bos dize
    gecerli UUID DEGIL. **CANLI DB'DE DOGRULANDI:**
    `invalid input syntax for type uuid: ""`. `anketOku` hata doner,
    `anketYayinla` log basip cikar ve **WS yayini HIC yapilmaz.**
    FIX: sifir UUID (`00000000-...`).
  · **ONBOARDING HICBIR CIHAZDA ACILMAYACAKTI**: `_p?.getBool(k) ?? true`
    ifadesi "depo ACILAMADI" ile "anahtar HENUZ YAZILMADI" (= TEMIZ KURULUM)
    durumlarinin IKISINI DE `true`ya ceviriyordu. Dort ekran yazilmis olmasina
    ragmen kullanici onlari HIC GORMEYECEKTI.
- 📊 **TURU 81 — E2E 181 -> 208.** En degerli kontrol: **"GERCEK olcu
  ZINCIRDEN geciyor"** — ilk yazimda **KIRMIZI DUSTU** ve gercek bir bosluk
  gosterdi: e2e araci presign'da `width/height` GONDERMIYORDU, yani zincir
  (presign -> sutun -> gonderi sorgusu) HIC SINANMIYORDU. Cikti artik
  `["1080x1350","0x0"]`.
  ⚠️ E2E ayrica **KENDI DUZELTMEMIN YAN ETKISINI YAKALADI**:
     `created_at = yayin_at` degisikligi yazarin kendi zamanladigi gonderisini
     **GORUNURLUK yuklemine degil IMLECE** takiyordu (`now + 1 saat` tavani).
     Statik denetim GOREMEZDI.
- 📌 **MIGRATION NUMARALARI (guncel):** 039 = mesaj tipleri (`iban`,`etkinlik`)
  · 040 = anket (`polls`,`poll_options`,`poll_votes`) · 041 = `posts.yayin_at`.
  Sonraki **042**'den.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **KALDIGIMIZ YER (10 Agu 00:35): TEST TURU 80 YAYINLANDI** — android **31336651933**
  + ios **31336653481** (**edc0da8**), R2 apk=117730375 (md5 f97e5cb7) ipa=24040413
  (md5 63b38976) index=9624 (md5 50bc97cb), purge OK, **CDN BIREBIR** (apk + ipa +
  index.html UCU DE MD5 esit), indir sayfasi 10 Agu 00:35 (saat 5 yerde + canli saat),
  debug imza YOK, **iOS min 16.0 dogrulandi**, IPA icinde turu 80 kodu var
  ("Rezervasyon" gecti), **BACKEND DEPLOY EDILDI** (edc0da8; migration 001->038
  atilabilir kopya DB'de dogrulandi = 47 tablo; `medya: aktif (R2)` +
  `ai: aktif (metin gpt-4o-mini · gorsel gpt-image-1.5)`) + health ok, DB TEMIZ
  (0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 181/181 UCTAN UCA GECTI** · **188 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata**.
  ⚠️ **KULLANICIYA VERILEN ADRES:** https://indir.gebzem.app/index.html?v=20260810-0035
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 80b — IKI TUR DENETIM. IKINCI TUR **KENDI DUZELTMELERIMDE** 2 SEVK
  ENGELI DAHA BULDU (17/20 onaylandi, 3 elendi). "Build ALMAK yayinlamak DEGILDIR"
  dersinin BESINCI dogrulanmasi: UC build alindi, ilk IKISI YAYINLANMADI.**
- ⚠️⚠️⚠️ **(A) `KisiselYap` GECMIS RANDEVULARI DA IPTAL EDIYORDU (SEVK ENGELI).**
  Yuklemde `baslangic` KOSULU YOKTU, ama HEMEN USTUNDEKI KENDI SERHIM
  *"gecmis randevulara DOKUNULMAZ"* diyordu — projenin en sik tekrarlayan sinifi
  ("yorumun anlattigi kontrol GOVDEDE yok") ve bunu KENDI DUZELTMEMDE yaptim.
  `'onaylandi'` GELECEK demek DEGIL: `geldi`/`gelmedi` gecisleri OPSIYONEL ve o
  dugmeler turu 80b'ye kadar HIC YOKTU -> **GERCEKLESMIS TUM GECMIS RANDEVULAR
  hala 'onaylandi'**. Kisisele donen isletme aylar once tamamlanmis rezervasyonlari
  "isletme iptal etti"ye ceviriyor, musterilere o eski ziyaretler icin BILDIRIM
  yagdiriyordu. `Gecisler` tablosunda `iptal_isletme`den DONUS YOK -> **GERI
  ALINAMAZ KAYIT TAHRIFATI**. FIX: `AND baslangic > now()`.
- ⚠️⚠️⚠️ **(B) GECE YARISINI ASAN CALISMA SAATLERINDE HER SLOT 409 DONUYORDU
  (SEVK ENGELI).** `Slotlar(gun)` "22:00-02:00" mesaide gece yarisini ASAR ve
  ertesi takvim gunune tasan slotlari da uretir; yani 11 Agu 00:30 slotu **10 Agu'nun**
  calisma gunune aittir. Turu 80b'de ekledigim yazma-yolu dogrulamasi ise anin
  KENDI takvim gunune bakiyordu -> arayuzun GOSTERDIGI her gece slotu POST'ta 409.
  **Bar/restoran gibi gece calisan mekanlar randevu ALAMAZDI.**
  ⚠️ Bu, AYNI COMMIT'te `ileri_gun` icin duzelttigim *"okuma ve yazma FARKLI TABAN
  kullaniyor"* hatasinin TEKRARIYDI. FIX: `SlotVarMi()` tek kaynagi — anin kendi
  gunu VE bir onceki gun denenir.
  ✅ E2E'de AMPIRIK dogrulandi: saatler gecici gece vardiyasina cevrilip
  `GECE YARISI SONRASI slot POST ile KABUL EDILIYOR | HTTP 201 saat=00:15`.
- ⚠️⚠️ **(C) `randevu_iptal` CIFT YONLUDUR, istemci TEK YON varsayiyordu.**
  `IptalIsletme` -> alici MUSTERI · `Iptal` -> alici ISLETME. Ikisi de ayni tur
  adini gonderiyordu; istemci `randevu_iptal`i KOSULSUZ musteri listesine
  yonlendiriyordu -> musteri iptal edince ISLETME bildirime dokunup KENDI musteri
  listesine dusuyor, iptali gelen kutusunda GOREMIYORDU.
  FIX: `randevu_iptal_musteri` AYRI turu + istemcide `isletmeyeGiden` kumesi.
  ⚠️ YAPMA: ikisini tekrar tek tur adina indirgeme.
- 📌 **TURU 80b — DIGER (ikinci tur):** gun seridi sunucunun izin verdigi SON GUNU
  HIC gostermiyordu (`+1`) · `_yenile` catch dali bolme kimligini kontrol etmiyordu
  (bir bolmenin ag hatasi DIGER bolmenin dolu ekraninda hata cizdiriyordu) ·
  yukleme dali hikaye seridini ve **BOLME SECICISINI** cizmiyordu (Keşfet
  yuklenirken geri donme yolu KAYBOLUYORDU) · asagi-cek kurtarmasi tam gerektigi
  anda no-op oluyordu (`_elleYenile`: ucustaki istegi bekler) · tam ekran dugmesi
  SARKAN KOMSUDA da ciziliyordu ve dokunma alani **27dp** idi -> 44dp (turu 78b
  dersi; bu dugme KIRPILAN ICERIGIN TEK kurtarma yolu) · `AyarKaydet` okuma
  hatasini YUTUP uydurma varsayilanlari 200 ile donduruyordu · `AyarGetir`
  `AyarOkuSahip` kullaniyor (kapi RANDEVU ALMA yolundadir; salt-okumaya
  uygulanmasi ex-isletmenin gecmis kayitlarina giden TEK arayuz yolunu kapatiyordu).
- 🛡️ **TURU 80b — MUHAFIZLAR KANITLANDI:** `internal/isletme/sutun_test.go` artik
  SIRAYI da olcuyor (`il`<->`ilce` TAKAS EDILIP test KIRMIZIYA dusuruldu — ayni
  tipteki iki sutun yer degistirse Postgres HATA VERMEZ, degerler SESSIZCE takas
  olur) · `internal/randevu/sutun_test.go` (`oku()` IKI Scan dali) da
  `not_isletme` yanittan cikarilarak dogrulandi · **E2E 172 -> 181**.
- **KALDIGIMIZ YER (9 Agu 23:45): TURU 80 + 80b KODU BITTI, BACKEND DEPLOY EDILDI**
  (**001e2db**; migration 001->038 atilabilir kopya DB'de dogrulandi = 47 tablo;
  `medya: aktif (R2)` + `ai: aktif (metin gpt-4o-mini · gorsel gpt-image-1.5)`)
  + health ok, DB TRUNCATE edildi.
  ✅ **CANLI SUNUCUDA 178/178 UCTAN UCA GECTI** · **188 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata**.
  Build tetiklendi: android **31334733441** · ios **31334734942**.
- ⚠️⚠️⚠️ **TURU 80b — DENETIM: 19/19 ONAYLANDI, 0 ELENDI (24 ajan, 5 mercek).**
  Dordu SEVK ENGELI; hepsi build ONCESI yakalandi.
- ⚠️⚠️⚠️ **(1) `randevu_ayar` UPSERT'te `COALESCE(EXCLUDED.x, mevcut)` OLU KODDU.**
  `EXCLUDED.acik` ZATEN `COALESCE($2,false)` sonucudur -> **ASLA NULL OLAMAZ** ->
  `randevu_ayar.acik` yedegi HIC degerlendirilmez. Istemci alanlari TEK TEK
  gonderdigi icin isletme "Randevu suresi"ni degistirince `acik` FALSE'a dusuyor,
  ayar bloku ekrandan kayboluyor: **ozellik ILK AYAR DOKUNUSUNDA KENDINI
  KAPATIYORDU** (turu 80'in manset ozelligi varsayilanlar disinda
  YAPILANDIRILAMAZDI). Gercek Postgres'te gecici tablo + ROLLBACK ile AMPIRIK
  kanitlandi. FIX: UPDATE dalinda EXCLUDED yerine **HAM PARAMETRE** (`$2..$6`);
  VALUES tarafindaki COALESCE'lar KALIR (INSERT'te NOT NULL sutunlar icin sart).
  ⚠️ **DERS: `ON CONFLICT` dalinda `EXCLUDED.x`, VALUES'ta COALESCE'lanmis bir
  parametreyse "gonderilmedi" bilgisi ZATEN KAYBOLMUSTUR.**
  ⚠️ **E2E NEDEN GOREMEDI: tum alanlari TEK cagrida gonderiyordu** -> hicbir
  parametre NULL olmuyor, COALESCE yedegi HIC sinanmiyordu. Artik KISMI govde
  gonderen kontrol var.
- ⚠️⚠️⚠️ **(2) `_yukleniyor` SIZINTISI — AKIS KALICI KILITLENIYORDU.**
  `if (!mounted || bolme != _bolme) return;` erken donusu `_yukleniyor = false`
  satirini ATLIYORDU. Bayrak **PAYLASILAN**: yukleme surerken bolme degistirilirse
  surec boyunca true kalir; `_yenile` ve `_dahaGetir`in ILK SATIRI her cagriyi
  reddeder -> asagi-cek CALISMAZ, sayfalama DURUR, paylasilan gonderi akista
  GORUNMEZ. `AkisEkrani` keepAlive oldugu icin **uygulama OLDURULMEDEN duzelmez**
  (turu 77b'de kapatilan hatanin AYNISI). Iki yerde birden duzeltildi.
  ⚠️ **DERS: bir bayragi await'ten once yazip erken donus ekliyorsan, o donusun
  bayragi TEMIZLEYIP temizlemedigini SOR.** Bayrak bolmeye ozgu DEGILSE, listeye
  yazmayi kapiyla koru ama BAYRAGI HER DURUMDA temizle.
- ⚠️⚠️ **(3) DORT RANDEVU BILDIRIM TURU ISTEMCIDE TANIMSIZDI** -> hepsi
  "bir işlem yaptı" genel metnine dusuyordu (**onay ile red AYIRT EDILEMIYORDU**)
  + her biri Sentry'ye alarm basiyordu. Turu 75b'deki `takip_onaylandi` hatasinin
  aynisi ve uyarisi HEMEN USTUNDE yaziliydi.
  ⚠️ **(4)** Randevu bildirimine dokunmak AKTORUN PROFILINE gidiyordu.
  ⚠️ YAPMA: sunucuya yeni bildirim turu eklerken `bildirimler_sayfasi.dart`
  switch'ini ve `_git()` yonlendirmesini atlama.
- ⚠️⚠️ **TURU 80b — `Olustur` TAKVIM KURALLARININ HICBIRINI DOGRULAMIYORDU.**
  Kapali gun · calisma saati · slot hizasi YALNIZ okuma yolunda (`Slotlar`)
  vardi; istemci takvimi HIC ACMADAN POST atarak **bayramda 03:17'ye** randevu
  yazdirabilirdi. **Arayuzun kurala uymasi, kuralin UYGULANDIGI anlamina GELMEZ.**
  ⚠️ FIX'te kural **IKINCI KEZ YAZILMADI**: uretecin KENDISI cagrilip istenen anin
  uretilen slotlar arasinda olup olmadigina bakiliyor (`Musait` BILEREK yok
  sayilir — kapasite karari advisory kilitli tek deyimde kalsin).
- ⚠️⚠️ **TURU 80b — `ileri_gun` IKI FARKLI TABANDA olculuyordu** (okuma GUN BASI,
  yazma AN) -> son gunun ogleden sonraki slotlari "musait" gorunup POST'ta **400**
  donuyordu. `IleriGunDisi()` TEK KAYNAGINA alindi (iki taraf da gun basi).
- ⚠️⚠️ **TURU 80b — `myProfileProvider` OTURUMA BAGLI DEGILDI.** `keepAlive`
  oldugu icin cikis sonrasi onbellek yasiyordu: baska hesapla girildiginde alt
  menude ve Profil sekmesinde **ONCEKI kullanicinin adi + avatari** ciziliyordu.
  Turu 80 profil ikonunu GERCEK RESME cevirdigi icin bedel gorunur oldu.
  FIX: govdenin ilk satirinda `ref.watch(authProvider)` (`myUserIdProvider` ile
  birebir ayni desen). ⚠️ YAPMA: `logout()` icine elle `invalidate` koyarak cozme
  — bir sonraki oturuma bagli saglayicida yine unutulur.
- ⚠️⚠️ **TURU 80b — E2E KALICI YALANCI-YESIL (yontem dersi).** Isletmenin calisma
  saatleri YALNIZ `gun: 1` (Pazartesi) tanimliydi; randevu blogu haftada TEK GUN
  calisiyordu. **172/172 gecmesinin sebebi, kosuldugu gunun (Pazar) yarininin
  PAZARTESI olmasiydi** — yesil, kodun dogrulugunu DEGIL **TAKVIMI** olcuyordu.
  ⚠️ **DERS: bir testin yesili, testin GERCEKTEN KOSTUGU anlamina gelmez.**
  Kosul-bagimli bloklarda (`if (musait) {...}`) sartın saglandigini de DOGRULA.
- ⚠️⚠️ **TURU 80b — OLU OZELLIKLER (bu sinifin YEDINCI tekrari):**
  · **KAPALI GUNLER**: `randevu_kapali` tablosu (038) + IKI uc + `Slotlar`daki dal
    + IKI servis metodu VARDI, **CAGIRAN EKRAN YOKTU** -> isletme bayramda randevu
    almayi DURDURAMIYORDU. `KapaliGunlerEkrani` eklendi.
  · **'geldi'/'gelmedi'**: gecis tablosunda tanimli, rozet 'geldi'yi YESIL
    ciziyordu — **YAZAN DUGME YOKTU**.
  · **`not_isletme`**: sutun + istek alani + SQL + yanit + Dart modeli vardi, ne
    YAZAN ne CIZEN yol vardi. Isletme artik red/iptal sebebi yaziyor (OPSIYONEL),
    musteri sebebi randevu satirinda goruyor.
    ⚠️ Ayrica **MUSTERI isletmenin ozel notuna yazabiliyordu** (`iptal` gecisini
    musteri yapiyor) — yetki `Gecisler` tablosuyla hizalandi.
  ⚠️ **DERS (yedinci kez): bir sutun/uc/servis ekledigin AN onu KULLANAN yolu da yaz.**
- 📌 **TURU 80b — MEDYA OLCULERI: DURUST NOT.** Yukseklik tavani DOGRU sonucu
  verdi (kutu her cihazda ekranin ~%32'si; Threads ~%28-31). AMA **`kMedyaEnBoy`
  BUGUN HICBIR CIHAZDA BAGLAYICI DEGIL** — `medyaYuksekligi` bir `math.min`dir ve
  tavan HER ZAMAN kazanir (sabitin baglayici olmasi icin oge genisliginin
  ~216dp ALTINA inmesi gerekir; en dar telefonda bile tek medya ~296dp).
  SONUC: kutu en-boyu ~1.06-1.65 ve `cover` ile **dikey fotograf %41-51, video
  %58-66 KIRPILIR.** Bu, *"cok uzun"* sikayetinin KACINILMAZ karsi tarafidir.
  ⚠️ **KIRPMANIN KURTARMA YOLU ZORUNLU**: fotografta VARDI (`TamEkranGorsel`),
  **VIDEODA HIC YOKTU** — yani videonun yalniz ORTA SERIDI gorulebiliyordu.
  `TamEkranVideo` eklendi; giris **NOKTASAL DUGME** (sol alt).
  ⚠️ YAPMA: videoya TAM ALANLI `GestureDetector` koyma — oynaticinin kendi tam
  ekran dinleyicisi jest arenasini kazanip dokunuslari YUTAR (turu 77b'de
  video hikayede ileri/geri dokunusu tam bu yuzden calismiyordu).
  ⚠️ YAPMA: `cover`i `contain`e cevirme (yatay kutuda dikey icerik kus kadar
  kalir + siyah bant).
- 🛡️ **TURU 80b — KALICI MUHAFIZLAR:**
  · **`internal/isletme/sutun_test.go`** (pakette HIC test yoktu): SELECT/Scan
    hizasi + **"Scan edilip yanit haritasina konmayan alan"** sinifi (turu 78'de
    kapak + onayli rozeti tam boyle kaybolmustu). ⚠️ Muhafizin calistigi,
    `randevu_acik` yanittan CIKARILIP test KIRMIZIYA dusurulerek **KANITLANDI**.
    ⚠️ Test ILK YAZIMDA kendi serhindeki "SELECT" kelimesini eslestirip YANLIS
    ALARM verdi -> ayristiriciya YORUM TEMIZLIGI eklendi. Kaynak okuyan her
    testte bu tuzagi hatirla.
  · **`rota_test.go`**: turu 80'in 13 ucu cozumleme vakalarina eklendi. En riskli
    ayrim `/isletme/...` (STATIK) vs `/isletmeler/{id}/...` (PARAMETRELI).
    **188 rota cakismasiz.**
  · **E2E 172 -> 178**: kapali gune dogrudan POST reddi · calisma saati disi reddi
    · slot hizasi disi reddi · **kismi ayar kaydinin diger ayarlari korudugu** ·
    kapali gun listeleme + geri alma.
- 📌 **TURU 80b — DIGER DUZELTMELER:**
  · Isletme kisisele donunce **bekleyen randevular YETIM kaliyordu** (musterinin
    listesinde gorunmeye devam ediyor; isletmenin iptal yolu TAMAMEN kapanmis —
    gelen kutusu 404). `KisiselYap` artik aktifleri `iptal_isletme` yapip
    musteriye BILDIRIYOR. **Satir SILINMEZ** (veri politikasi).
  · **`AyarOku`ya `hesap_turu='isletme'` kapisi**: hesap kisisellesince
    `isletmeler` satiri SILINMIYOR, kapi olmadigi icin randevu almaya DEVAM
    ediyordu. Kapi **TEK KAYNAGA** kondu (dort uc oradan gecer).
  · `_dahaVar` ve `_kesfet` **BOLME BASINA** tasindi (soguk baslangic seridi
    Keşfet'te de ciziliyordu; tukenmis sayfalama bolme degisiminde diriliyordu).
  · `_bolmeDegistir`in tetikledigi `_yenile()` **sessizce yutulabiliyordu**
    (`_yukleniyor` kapisi) ve TEKRAR DENEYEN yol yoktu -> **Keşfet KALICI BOS**.
    `_bolmeYukle()`: ucustaki istegin bitmesini bekler (10 x 150ms).
  · Yuklenmemis bolme artik SPINNER gosteriyor ("Henüz gönderi yok" YERINE).
  · Gonderi silme **HER IKI BOLMEDEN** (ayni gonderi iki listede de bulunabilir).
  · `IsletmeSeridi._yukle` **try/catch'siz** idi: tek ag kopmasi "Randevu al"
    dugmesini TAMAMEN dusuruyordu (tekrar deneme yolu yok). Tek tekrar eklendi.
  · `randevu_al` AppBar alt basligi **sabit 20px** idi; yazi olcegi 1.3'te tasip
    **RenderFlex seridi** cikariyordu -> olcege gore + ellipsis.
  · `u.username` COALESCE'siz taraniyordu (18 sorgunun tek istisnasi).
  · Bayat serhler: iki dosya *"flutter_localizations YOK"* diyordu, turu 80 onu
    **EKLEDI**; buna dayanan *"showDatePicker EKLEME"* hukmu GECERSIZDI.
    (Saat secici karari AYRI gerekceyle DURUYOR: serbest saat, calisma saatine
    uymayan secim demektir.)
- ⚠️⚠️⚠️ **INDIR SAYFASI — KOK NEDEN NIHAYET OLCULDU (kullanici UCUNCU KEZ
  "saati goremiyorum" dedi).** Sunucu tarafi YINE dogru cikti (`no-cache,
  no-store, must-revalidate` + `cf-cache-status: DYNAMIC` + saat 5 yerde + canli
  saat + turu 50 flexbox fix'i duruyor). **GERCEK SEBEP:**

      https://indir.gebzem.app/?v=123  --302-->  /index.html   <- SORGU DUSUYOR

  Yani **ciplak alan adina cache-busting parametresi eklemek ISE YARAMIYOR**;
  R2'nin 302'si sorgu dizesini KORUMUYOR. Ana ekrana eklenmis kisayoldan ya da
  agresif onbellekli bir webview'dan girildiginde tarayici `no-store` basligina
  **RAGMEN** eski kopyayi cizebiliyor.
  ✅ **COZUM: kullaniciya `/index.html?v=<surumEtiketi>` VERILECEK** — 302'ye HIC
  ugramaz ve her surumde FARKLI adres oldugu icin hicbir onbellek katmani
  eslestiremez. Uretici bu adresi kosu sonunda BASIYOR.
  ⚠️ **YAPMA: kullaniciya ciplak alan adini verme.**
  ⚠️ Icerik muhafizi turu 79'a SABITLENMISTI -> her turda BU SURUME sabitlenir
  (muhafiz calisti: turu 80 metnini yazinca eski kontrol PATLADI, sayfa
  uretilmedi).
- 📌 **MIGRATION NUMARALARI (guncel):** 038 = randevu (`randevu_ayar`,
  `randevu_kapali`, `randevular`). Sonraki **039**'dan.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **TURU 79 — YAPAY ZEKA ILE GORSEL URETME (kod BITTI, backend DEPLOY d335af6).**
  Kullanici: *"yapay zeka ile görsel oluşturma nerede?"* -> *"tamamda olacak
  dedim ya"*. HAKLIYDI: anahtari verirken **"hepsi olsun"** demisti; turu 77/78'de
  yalniz METIN uclari baglanmisti. ✅ **CANLI DOGRULANDI** (uc kez: 21-28 sn,
  ~1,5 MB PNG, imzali adresten indi, kota dogru dustu) ve **GORSEL GOZLE
  KONTROL EDILDI**. ✅ **150/150 UCTAN UCA.**
- ⚠️⚠️⚠️ **TURU 79 — DIS SERVISIN MODEL ADINI VE PARAMETRELERINI VARSAYMA.**
  Iki varsayimim CANLI SUNUCUDA curudu:
  · `response_format: "b64_json"` -> **400 Unknown parameter** (images ucunda
    ARTIK YOK). Kaldirildi; artik `b64_json` VE `url` **IKI BICIM** de
    destekleniyor (URL gelirse sunucu INDIRIR) — API bir daha degisirse ozellik
    sessizce olmesin.
  · `dall-e-3` -> **"The model does not exist"**. `GET /v1/models` ile hesabin
    GERCEKTEN erisebildikleri listelendi -> **`gpt-image-1-mini`** (ailenin en
    ucuzu, urun fotografi icin yeterli).
  ⚠️ **YONTEM: once `/v1/models` ile listele, istegi `curl` ile SINA, SONRA kod yaz.**
- 📌 **TURU 79 — `media.Yukle` (SUNUCU TARAFI PUT) EKLENDI.** "Medya API'DEN
  GECMEZ" kuralinin **BILINCLI ISTISNASI**; kullanici dosyalari (100 MB video)
  HALA presigned PUT ile dogrudan R2'ye gidiyor. AI gorseli **ISTEMCIDE HIC
  YOKTUR** (OpenAI -> sunucu). Istemciye gonderip ondan yukletmek (a) baytlari
  IKI KEZ tasirdi, (b) istemcinin yuklemeyi ATLAYIP kendi baska bir gorselini
  "AI uretti" diye kaydetmesine izin verirdi. `Content-MD5` gonderilir (commit
  adimi YOK, butunluk BURADA kanitlanir).
  ⚠️ YAPMA: bu fonksiyonu kullanici yuklemelerine acma.
- 📌 **TURU 79 — `kind='image'` KULLANILDI, YENI TUR ACILMADI.** Yeni bir `kind`
  (a) `media_assets.kind` CHECK'ini genisletmeyi gerektirirdi (turu 78'de bu
  tuzaga IKI KEZ dusuldu), (b) `erisebilir()` icine YENI DAL gerektirirdi ve o
  dal unutuldugunda **yukleyenden baska HERKESE 403** donerdi (DORT kez sahaya
  cikti). Mevcut urun/ilan dallari zaten kapsiyor.
- ⚠️⚠️⚠️ **TURU 79b — `/ai/urun-metni` GORSEL KOTASINI YIYORDU (KENDI
  REGRESYONUM, SEVK ENGELI).** Turu 77'de `tur` YALNIZCA BIR ETIKETTI ve o uc
  "gorsel" yaziyordu — ZARARSIZDI. Turu 79'da `kapi()` icine
  `gorselMi := tur == "gorsel"` ekleyip etiketi **"pahali gorsel kotasi"**
  olcutune cevirdim ama CAGRI YERINI guncellemedim. Sonuc: "Yapay zekâ ile
  açıklama yaz" dugmesine her dokunus, turun MANSET OZELLIGINDEN bir hak
  yakiyordu; 10 aciklama yazdiran kisi HIC GORSEL URETMEDEN "gorsel hakkin
  doldu" goruyordu.
  FIX: `tur="urun-metni"` + olcut **TEK KAYNAGA** alindi (`gorselKotasiMi`).
  ⚠️ **DERS: bir kota/yetki olcutunu SERBEST METIN etiketine baglarken TUM
     cagri yerlerini TARA** (`grep 'h.kapi(w, r,'` dort satir donduruyor).
- ⚠️⚠️ **TURU 79b — ISTEMCI ZAMAN ASIMI SUNUCUNUN USTUNDE OLMALI (SEVK ENGELI).**
  Istemci 90 sn, sunucu gorsel uretimine 120 sn veriyordu: yavas uretim
  **GARANTILI KAYIP** — sunucu tamamlar, OpenAI FATURAYI KESER, gorsel R2'ye
  yazilir, kota 'tamam' kapanir, ama istemci `media_id`yi HIC ALMAZ; gorsel
  yetim kalir, kullanici jenerik hata gorup TEKRAR dener (ikinci hak da gider).
  FIX: istemci 150 sn. ⚠️ Sunucudaki `gorselZamanAsimi` degisirse BURASI DA.
- ⚠️⚠️ **TURU 79b — `durum='iptal'` YAZAN YOL YOKTU** ("sutun var, yazan yol
  yok" sinifinin **ALTINCI** tekrari). Sutun 036'da TAM BU IS ICIN eklenmis ve
  kota sayimi `durum <> 'iptal'` yuklemini ZATEN kullaniyordu. Icerik politikasi
  reddi **PARA HARCAMADIGI HALDE** gunluk hakki 24 saat yakiyordu.
  FIX: OpenAI'ya ULASIP reddettiyse `'iptal'`; zaman asimi/5xx -> `'hata'`
  (faturalanmis OLABILIR — turu 77b ilkesiyle ayni).
- ⚠️⚠️ **TURU 79b — KOTA REZERVASYONU ATOMIK DEGILDI.** `INSERT ... SELECT
  WHERE (count) < kota` READ COMMITTED'da escamanli iki istegi de gecirir; kota
  asilir ve GORSEL tarafinda bu **GERCEK PARA** demektir. FIX:
  `pg_advisory_xact_lock(hashtext(havuz+userID))` — islem bitince otomatik
  birakilir (kilit SIZMAZ). ⚠️ Anahtar HAVUZU da icerir: metin ve gorsel
  havuzlari birbirini gereksiz BEKLETMESIN. ⚠️ COMMIT sart (defer Rollback var).
- 📌 **TURU 79b — REDDEDILEN GORSEL: `DELETE /ai/gorsel/{id}`.** Onceden
  "Vazgec" denen gorsel R2'de kalip kullanicinin AYLIK DEPOLAMA kotasini KALICI
  yiyordu ve temizleyecek yol YOKTU. Silme kapilari: sahiplik + `kind='image'` +
  `status='aktif'` + **HICBIR YERE BAGLI OLMAMA** (urun/ilan/etkinlik/gonderi/
  kanal/avatar/kapak/grup/mesaj). ⚠️ **AI hakki IADE EDILMEZ** (uretim gercekten
  para harcadi); yalniz DEPOLAMA iade edilir — aksi halde "begenene kadar
  sinirsiz deneme" olurdu.
- ⚠️ **TURU 79b — `GorselAcik()` HICBIR SEY OLCMUYORDU** (deploy sonrasi kendi
  yakaladigim hata): `gorselKaydet != nil` kontrolu YAPISAL OLARAK her zaman
  true, cunku `mediaH.AIGorseliKaydet` bir **METOT DEGERIDIR**. R2 kapali bir
  kurulumda dugme cizilir, kullanici basinca hata alirdi.
  FIX: `medyaAcik func() bool` = `mediaH.Enabled`.
  ⚠️ **DERS: bir yetenegi "geri cagirim nil mi" ile yoklama — metot degeri ise
     HICBIR SEY OLCMEZ. Gercek durumu SORAN bir fonksiyon iste.**
- 📌 **TURU 79 — UCTAN UCA 148 -> 150; URETIM CAGRILMIYOR (bilincli).** Uretim
  her surumde kosulsaydi her e2e calistirmasi PARA harcar ve kullanicinin gunluk
  gorsel kotasindan duserdi. Onun yerine BAGLANTI ve KAPILAR ucretsiz yollardan
  dogrulaniyor + **`/ai/urun-metni` GORSEL kotasini YEMIYOR** (regresyon kaniti:
  metin 20->19, gorsel 10->10). Gercek uretim ELLE: `scratchpad/gorsel_test.js`.
- **ONCEKI (9 Agu 16:33): TEST TURU 78 YAYINLANDI** — android 31315541995 +
  ios 31315543585 (**7240bfb**), R2 apk=115648043 (md5 2911b24e) ipa=23723742
  (md5 99442aaf), purge OK, **CDN BIREBIR** (apk + ipa + index.html UCU DE MD5
  esit), indir sayfasi 16:33 (saat 5 yerde + **canli saat**), debug imza YOK,
  iOS min 16.0 dogrulandi, surum 1.0.127 build 127, **BACKEND DEPLOY EDILDI**
  (7240bfb; migration 032-037; `ai: aktif (gpt-4o-mini)` + `medya: aktif (R2)`)
  + health ok, DB temiz. ✅ **CANLI SUNUCUDA 144/144 UCTAN UCA GECTI.**
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 78b — ILK BUILD (79466d9) ALINDI AMA YAYINLANMADI.** Yayin oncesi
  adversaryal denetim (7 mercek + curutucu dogrulama, 35 ajan) **27 BULGU**
  buldu, **27'si de DOGRULANDI, 0 curutuldu**; hepsi duzeltilip build YENIDEN
  alindi. *"build ALMAK yayinlamak DEGILDIR"* dersinin **DORDUNCU** dogrulanmasi.
- ⚠️⚠️⚠️ **TURU 78b — `erisebilir()`DE GRUP SOHBETI AVATARI DALI YOKTU (SEVK
  ENGELI).** `chats.avatar_media_id` migration **024**'ten beri VAR ve grup
  olusturma ekrani onu DOLDURUYOR — ama dal HIC YAZILMAMISTI. Tum migration'lar
  tarandiginda **TEK KARSILIKSIZ MEDYA SUTUNU** buydu. Grubu KURAN fotografi
  gorur (kapi `sahip != userID` ile KISA DEVRE); gruptaki **DIGER HERKES**
  sohbet listesinde, baslikta ve grup bilgisinde KIRIK GORSEL gorurdu.
  Turu 75b (akis) · 77 (hikaye) · 78 (kapak) ile AYNI sinifin **DORDUNCU** tekrari.
  FIX: (i) dali, gorunurluk kurali **UYELIK** (kanal gibi "herkese acik" DEGIL).
  ⚠️ `medyayiKopar` referans sayimi da `users.kapak_media_id` ve
     `chats.avatar_media_id`i SAYMIYORDU -> paylasilan medya kopariliyordu.
  ⚠️ **YENI BIR MEDYA SUTUNU EKLERKEN UCUNU BIRLIKTE GUNCELLE:** `erisebilir()`
     dali · `medyayiKopar` sayimi · uctan uca kontrolu.
- ⚠️⚠️ **TURU 78b — VERI SILME: "AYNI KURALIN IKI KOPYASI DRIFT EDER" (iki yer).**
  · `isletme_duzenle`: turu 77b `_yuklemeHatasi` kapisini YALNIZ `catch` daline
    koymus, KARDES DAL (`id.isEmpty`) acik kalmisti. `/users/me` bir kez hata
    verirse `FutureProvider` hatayi KALICI onbellekler -> form BOS acilir,
    Kaydet ETKINDIR, kosulsuz `ON CONFLICT DO UPDATE` adres/il/ilce/web'i BOSA
    CEKER ve kategori 'yemek'e duser (**bir KUAFOR sessizce "Yemek" olur**).
  · `profil_duzenle`: profil yuklenemezse Kaydet `PATCH {name:''}` gonderip
    **GORUNEN ADI SILIYORDU**. FIX: `_dolduruldu` kapisi.
  ⚠️ Ikisinde de cozum `.future` ile BEKLEMEK + hata ekrani.
- ⚠️⚠️ **TURU 78b — AI MENUSU DORT AYRI YERDEN KIRIKTI:**
  · **"0 URUN EKLENDI"**: onizleme tip korumali (turu 77b), KAYDETME yolu ciplak
    `as num?` ile kalmisti ve `catch(_){}` yutuyordu. Model `"1250"` (METIN)
    dondurunce diyalog DOGRU gosteriyor, kaydetme HEPSINI atliyordu.
    FIX: `_kurusOku` **TEK KAYNAK**. ⚠️ YAPMA: iki yolda ayri ayristirma yazma.
  · **BEKLEME DIYALOGU KATALOG EKRANINI KAPATIYORDU**: `barrierDismissible:false`
    YALNIZ perdeyi engeller; **ANDROID GERI TUSU diyalogu YINE DE pop eder**,
    `diyalogAcik` yalanci kalir ve basari dalindaki kosulsuz `pop()` bir ustteki
    ekrani kapatirdi. FIX: `PopScope(canPop:false)` + `whenComplete` +
    `_BeklemeKapisi`. ⚠️ YAPMA: bayragi elle yonetmeye donme.
  · **ISTEMCI 20 sn'DE VAZGECIYORDU** (sunucu 60 sn'ye izin veriyor): kota
    rezervasyon yuzunden YANIYOR, sonuc URETILIYOR ama KAYBOLUYORDU.
    FIX: AI uclarina 90 sn. ⚠️ Sunucu tavani degisirse BURASI DA degismeli.
  · `aiDurumProvider` tek gecici ag hatasinda `acik:false`u SUREC OMRU BOYUNCA
    onbellekliyordu -> AI ozelligi uygulama yeniden baslatilana kadar KAYBOLUR,
    kurtarma yolu da YOKTU. FIX: hata onbelleklenmez (`invalidateSelf`).
- ⚠️⚠️⚠️ **TURU 78b — SESI ACILAN VIDEO DEFTERE GIRMIYORDU (SEVK ENGELI).**
  `_oynat()`in serhi *"ses acilinca `_sesiCevir` yeniden kaydolur"* diyordu ama
  **GOVDEDE O SATIR YOKTU** (CLAUDE.md turu 74 dersi). Galerilerdeki TUM videolar
  SESSIZ baslar; kullanici sesi acinca video SESLI calar ama `SesNotuKontrol`
  defterinde KAYITLI DEGILDIR -> **GELEN ARAMA O SESI SUSTURAMAZ.** Turu 78
  ilan + etkinlik galerileriyle bu yuzeyi IKIYE KATLADI.
  FIX: `_defteriGuncelle()` **TEK KAYNAK**, hem `_oynat` hem `_sesiCevir`ten.
- ⚠️⚠️ **TURU 78b — `ref.read` YUKLEME AWAIT'LERININ ALTINDAYDI** (ilan ·
  etkinlik · urun · iki AI yolu). Bu ekranlarda `PopScope` YOK; kullanici
  kaydetme surerken geri basarsa State DISPOSE olur, `ref.read` `StateError`
  firlatir, `catch` yutar: **medya R2'ye YUKLENIR ama POST HIC ATILMAZ.**
  Turu 77b'nin HIKAYE hatasinin birebir aynisi; duzeltmesi `story_seridi.dart:122`
  de duruyordu ve yeni ekranlar dersi TEKRARLADI.
  ⚠️ Servis yakalandigi icin is artik kullanici ekrandan ciksa bile TAMAMLANIR.
- ⚠️ **TURU 78b — DUZENLEME SERITLERI VIDEOYU KIRIK CIZIYORDU.** `_mevcutMedya`
  duz `List<String>`ti, `mediaKinds` ATILIYORDU -> video id'si `MedyaGorsel`e
  gidiyor ve kullanici **videosunu bozuk sanip SILEBILIYORDU**. FIX:
  `MedyaKucukResmi` + `_mevcutTurler` (ilan + etkinlik). ⚠️ IKI LISTE BIRLIKTE
  degisir (ekleme/silmede ikisine de dokun).
- ⚠️ **TURU 78b — GALERI VIDEOSU: rota kapisi YOKTU + `dongu` varsayilani TRUE**
  -> uste ekran acilinca ALTTA SONSUZ DONGUDE caliyordu. FIX: `_kapiyiYokla`
  icine `ModalRoute.isCurrent` kapisi (akistaki dort kapidan biri) + `dongu:false`.
  ⚠️ `MedyaSecici.videoSuresi` de `donanimSerbest` KAPISIZ oynatici kuruyordu —
  `mixWithOthers:true` **"oturumu ELE GECIRME"** demek, "HIC DOKUNMA" DEMEK DEGIL.
- ⚠️ **TURU 78b — ILAN DUZENLEMEDE TIPE OZEL METIN ALANLARI BOS ACILIYORDU.**
  `TextField`in `initialValue`u YOKTUR ve controller da verilmemisti: SECIM
  alanlari DOLU, Marka/Model/Yıl/Km/Metrekare BOS geliyordu (mansett ozellik
  yarim). FIX: `TextFormField` + `initialValue`. ⚠️ `ValueKey` ZATEN VAR ve
  ZORUNLU (`FormField.didUpdateWidget` `initialValue` degisimini YOK SAYAR —
  turu 77b hayalet-veri hatasi).
- 📌 **TURU 78b — DIGER KAPATILANLAR:** `VitrinSlider` `didUpdateWidget` yoktu
  (kategori degisince BAYAT kaliyor, slayta dokununca YANLIS kayda gidiyordu) ·
  "Satıcıya mesaj" cift dokunma korumasizdi · istemci `enlem/boylam`i HER
  ISTEKTE 0 gonderip sunucudaki `COALESCE` korumasini ATIL birakiyordu ·
  Reels sure uyarisi `inMinutes` TAM SAYI bolmesi yuzunden 90 sn icin
  "1 dakika" diyordu · medya kaldirma dugmesi 17x17 dp idi (Material 48/Apple 44)
  · `MedyaSecici.video` secici patlarsa SESSIZCE oluyordu · `bas_min`/`bas_maks`
  OLU YETENEKTI -> **"Bugün" / "Bu hafta sonu"** hizli kartlari eklendi.
- 📌 **TURU 78b — UCTAN UCA 140 -> 144 (GRUP AVATARI).** ⚠️ Son iki kontrol
  BIRLIKTE bir **KANIT**: B ile C arasindaki TEK fark sohbet UYELIGIDIR; B'nin
  200, C'nin **403** almasi erisimi verenin YALNIZCA yeni (i) dali oldugunu
  gosterir. Bu sinif **ancak IKI HESAPLA** yakalanir.
- 📌 **TURU 78b — INDIR SAYFASI ARACLARI REPOYA TASINDI: `tools/indir/`.**
  Kullanici IKI AYRI TURDA "saati goremiyorum" dedi; dosyalar scratchpad'de
  oldugu icin her oturum yeniden yaziliyor ve muhafizlar da yeniden kuruluyordu.
  Uretici; saat 5 yerden azsa · canli saat kaybolmussa · `?v=` yoksa · body'ye
  flex ortalama geri gelmisse · gorunen metinde emoji kalmissa **DERLEMEYI
  DURDURUR**. ⚠️ Yeni surumde `YENI_ICERIK` blogu ile onu dogrulayan
  `'turu NN icerigi yazilmadi'` satiri **BIRLIKTE** guncellenir.
- **ONCEKI (9 Agu 15:10):** TURU 78 KODU BITTI, BACKEND DEPLOY EDILDI
  (**fe104a8**; migration **032-037** uygulandi; `ai: aktif (model gpt-4o-mini)` +
  `medya: aktif (R2)`) + health ok, DB TRUNCATE edildi (7 tablo 0).
  ✅ **CANLI SUNUCUDA 140/140 UCTAN UCA KONTROL GECTI** (`node tools/uctan_uca.js`,
  IKI AYRI HESAPLA). **BUILD ALINMADI — KULLANICIYA SORULACAK (kural 0).**
- ⚠️⚠️⚠️ **TURU 78 — `Profile()` KAPAK/ONAYLI ALANLARINI YANIT HARITASINA KOYMUYORDU
  (SEVK ENGELI).** Sutunlar SELECT ediliyor, `rows.Scan(&u.KapakMediaID, &u.Onayli)`
  kosuyordu — ama yanit `map[string]any{...}` ELLE kuruluyor ve iki alan oraya
  YAZILMAMISTI. Derleyici goremez (Scan'in yan etkisi var, degisken "kullaniliyor").
  Sonuc: **kapak HICBIR PROFILDE gorunmez, onayli rozeti HIC cizilmezdi** —
  kullanicinin ACIKCA istedigi iki sey.
  **KALICI MUHAFIZ: `internal/users/profil_yanit_test.go`** — `Profile()`in `&u.Alan`
  taramalarini ayristirir, her birini `userResp` JSON etiketine cozer ve o etiketi
  yanit haritasinda ARAR. Muhafizin calistigi, duzeltme GERI ALINIP test KIRMIZIYA
  dusurulerek KANITLANDI.
  ⚠️ YAPMA: bu testi silme; `Profile()`e yeni sutun eklerken SELECT + Scan + yanit
  haritasi UCUNU BIRLIKTE guncelle. (`sutun_test.go` ailesinin kardesi.)
- ⚠️⚠️ **TURU 78 — CHECK CONSTRAINT TUZAGI IKI KEZ (SEVK ENGELI).**
  `media_assets.kind` `'kapak'` KABUL ETMIYORDU -> presign HER SEFERINDE 500 =
  kapak ozelligi **%100 OLU DOGARDI**. `ai_istekleri.durum` da `'iptal'` kabul
  etmiyordu. `go build` + `go vet` + `flutter analyze` UCU DE TEMIZ; hata YALNIZ
  gercek Postgres'te cikar. Migration **036** (durum) + **037** (kind).
  ⚠️ **DERS: yeni bir `kind`/`durum`/`tur` DEGERI eklerken once CHECK'i ac.**
- ⚠️⚠️ **TURU 78b — `PUT /users/me/isletme` HER SEFERINDE 500 (KENDI FAZ 0
  REGRESYONUM).** Koordinatlar ISARETCI yapildi ("gonderilmedi" != "0") ve UPDATE
  dali dogru kuruldu — **INSERT dali ATLANDI**. Istemci enlem/boylam HIC gondermedigi
  icin pgx `nil`i SQL NULL'a cevirdi, sutun NOT NULL: `SQLSTATE 23502`. Buna bagli
  **ALTI kontrol daha** coktu (isletme detayi, rehber, `hesap_turu`, urun ekleme,
  katalog, urun medyasi).
  ⚠️ CLAUDE.md'de defalarca yazili **"nil -> SQL NULL"** sinifini KENDI DUZELTMEMDE
  tekrarladim. Statik denetim GORMEDI; **UCTAN UCA TESTI YAKALADI** — surum
  rutinindeki "deploy sonrasi e2e" adimi bu yuzden ZORUNLU.
  FIX: INSERT'te `COALESCE($9,0)`; ON CONFLICT dalindaki COALESCE eski degeri KORUR.
- 📌 **TURU 78 — `etkinlik_kadro`DA MEDYA SUTUNU YOK (bilincli).** Sanatci fotografi
  `media_assets`e baglansaydi `erisebilir()` icine YENI BIR DAL gerekirdi; o dal
  unutuldugunda **yukleyenden baska HERKESE 403** donerdi (turu 75b + 77'de SAHAYA
  CIKTI). Kadro simdilik ad + rol. `user_id` **NULLABLE** — unluler kayitli degil.
  ⚠️ **KAYITLI kisinin adi SUNUCUDAN alinir**, istemcinin gonderdigi ad YOK SAYILIR
  (kimlik taklidi kapisi); e2e "SAHTE AD" gondererek dogruluyor.
- 📌 **TURU 78 — `reklamlar` TABLOSU ACILMADI (icerigini girecek YOL YOK).**
  Odeme yok · isletme hesabi sayisi SIFIR · **admin panelinden GORSEL YUKLENEMEZ**
  (admin uclari `?key=` ile JWT grubunun DISINDA, presign ICINDE -> onay kuyrugu
  yalnizca bir UUID LISTESI olurdu = KOR ONAY). Slider ORGANIK vitrinden beslenir
  (`/vitrin?dikey=`); odeme gelince tablo BU UCUN ARKASINA eklenir ve **istemci
  sozlesmesi DEGISMEZ**. ⚠️ Vitrin ilk **FOTOGRAFI** secer, ilk medyayi DEGIL
  (video olsaydi slider'da KIRIK GORSEL cizilirdi).
- 📌 **TURU 78 — `chats.ilan_id` (032) EKLENDI ama `type` HALA `'direct'`.**
  Kisisel sohbetin ilan sohbetine DUSMEMESI icin tum dogrudan-sohbet SQL'i TEK
  KAYNAGA alindi: **`internal/sohbet/direkt.go`** (`ilan_id IS NULL` yuklemi orada).
  ⚠️ YAPMA: yuklemi cagiran yerlere elle kopyalama (drift eder — turu 75b/H dersi).
  Kendi ilanina mesaj 400; ayni ilan icin ikinci cagri AYNI satiri doner.
- 📌 **TURU 78 — KALDIRMA NOBETCISI: BOS DIZE = SIL.** `null` "degistirme" demektir;
  ikisi ayrilmadan `kapak_media_id` / etkinlik `bitis` alani TEMIZLENEMEZ.
- ⚠️ **TURU 78 — UCTAN UCA 104 -> 140 KONTROL.** Turu 78'in sekiz fazi icin **36 yeni
  kontrol**; oncesinde bu fazlarin HICBIRI otomatik dogrulanmiyordu. En kritikleri:
  profil ucunun kapagi **yanit haritasinda** dondurmesi · `kind='kapak'` presign'in
  CHECK'ten gecmesi · kapagin **IKINCI HESAPTA** acilmasi · sadece `durum`
  degisiminin `duzenlendi_at` damgasini **DEGISTIRMEMESI** · kisisel sohbetin ilan
  sohbetine **DUSMEMESI** · kadroda **ad'in SUNUCUDAN** gelmesi.
- ⏳ **TURU 78 — DURUST SINIRLAR (yapilmadi, sebebiyle):** HARITA ve "yakinimda"
  YOK — `isletmeler.enlem/boylam` VAR ama **hicbir kayitta DOLU DEGIL** ve
  dolduracak arayuz yok; harita bos tuval olurdu. Once koordinat girisi lazim.
  Kartlar bugun calisan olcutlerle (onayli, yeni) besleniyor. **AI ile GORSEL
  URETME yok** — yalniz metin -> menu.
- 🔑 **BEKLEYEN:** kullanici OpenAI anahtarini sohbete yazdi ve "calistirdiginizda
  degistirecegim" dedi. Anahtar sunucuda CALISIYOR (canli test: metin -> 5,7 sn'de
  gecerli Turkce JSON menu, kota 20->19) -> **ARTIK DONDURULMELI.**
- 📌 **MIGRATION NUMARALARI (guncel):** 032 = `chats.ilan_id` · 033 = kapak + onayli ·
  034 = `ilanlar.duzenlendi_at` · 035 = `etkinlik_kadro` · 036 = `ai_istekleri.durum`
  CHECK · 037 = `media_assets.kind` CHECK. Sonraki **038**'den.
- **KALDIGIMIZ YER (9 Agu 06:40): TEST TURU 77 YAYINLANDI** — android 31292449948 +
  ios 31292451069 (fd5fbaa), R2 apk=115303523 (md5 685c27b1) ipa=23688271
  (md5 19616914), purge OK, **CDN BIREBIR** (apk + ipa + index.html MD5 esit),
  indir sayfasi 06:40 (saat **5 yerde + canli saat**), debug imza YOK,
  iOS min 16.0 dogrulandi, **BACKEND DEPLOY EDILDI** (fd5fbaa; migration
  **027-031** uygulandi, "medya: aktif (R2)", "ai: KAPALI" beklenen) + health ok,
  DB temiz (0/0/0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 105/105 UCTAN UCA KONTROL GECTI** (duzeltmelerden SONRA tekrar).
  ✅ **171 ROTA CAKISMASIZ** + turu 77 uclari dogru cozuluyor.
  **KULLANICI TEST EDECEK.**
- **ONCEKI ADIM:** TURU 77 — 6 YENI DIKEY + 77b DENETIMI.
  Kullanici emri (uyurken, ONAYSIZ ILERLEME ACIKCA ISTENDI): hikaye editoru ·
  isletme profilleri · etkinlikler · ilanlar (sahibinden) · hizmetler · isletme
  urunleri + AI. ⚠️ **CLAUDE.md kural 0 (build oncesi sor) BU TUR ICIN ASKIYA ALINDI**
  — kullanici *"durma sakin hepsini bitirene kadar"* dedi.
- ⚠️⚠️ **GO TESTLERI 3 TURDUR KOSTURULAMIYORDU — KOK NEDEN BULUNDU.**
  Windows Application Control, `go test`in VARSAYILAN gecici dizinde
  (`%LOCALAPPDATA%\Temp`) urettigi YENI ikilileri engelliyor; sunucuda da Go
  KURULU DEGIL (yalniz Docker derlemesi). Yani `internal/rota/rota_test.go`
  **HICBIR ORTAMDA** kosmamisti. COZUM: `GOTMPDIR="$(pwd)/.gotmp" go test ./...`
  (proje dizinindeki ikili engellenmiyor). `.gotmp/` gitignore'da.
  ⚠️ YAPMA: bir daha "test kosturulamiyor" diye gecme.
  SONUC: **171 rota cakismasiz** + turu 77'nin 33 yeni yolu dogru cozuluyor;
  `sutun_test.go` (7 sorgu SELECT-vs-Scan) da gecti.
- 📌 **MIGRATION NUMARALARI (guncel):** 027 = hikaye editoru (`stories.katmanlar`
  JSONB + `arka_plan` + `media_id` NULL olabilir), 028 = `users.hesap_turu` +
  `isletmeler`, 029 = `etkinlikler` + `etkinlik_katilim`, 030 = `ilanlar` +
  `ilan_favoriler`, 031 = `isletme_urunleri` + `ai_istekleri`. Sonraki **032**'den.
- ⚠️⚠️⚠️ **TURU 77 — AI KAPISI: `OPENAI_API_KEY` (R2 KALIBININ AYNISI).**
  Anahtar YOKSA `Acik()` false, uclar **503**, ve **istemci ozelligi HIC CIZMEZ**
  (`GET /ai/durum`). Acilista log: `ai: OPENAI_API_KEY yok — AI KAPALI`.
  ⚠️⚠️ **TURU 75'IN TEKRARI RISKI:** R2 anahtarlari sunucudaki `.env`e yazilmis
  ama `docker-compose.yml`in **`environment:` blogu** guncellenmemis ve medya
  SESSIZCE KAPALI kalmisti (/health "ok" donuyordu!). `OPENAI_API_KEY` compose'a
  ONCEDEN eklendi. ⚠️ YAPMA: yeni env'i yalniz `.env`e yazip birakma.
- ⚠️⚠️⚠️ **TURU 77b — SES SAHIPLIGI PING-PONG'U (SEVK ENGELIYDI, EN AGIR).**
  `SesNotuKontrol` **TEK SLOTLUDUR** (yeni sahip oncekini SUSTURUR) ama
  `MedyaVideo._oynat()` **SESSIZ** akis videolarinda bile KOSULSUZ kaydoluyordu.
  Akista bir video gorunurken Reels'e gecince Reels ~1sn oynayip DONUYOR
  (akistaki 1sn'lik `_kapiYoklama` sahipligi geri caliyor); ayni sekilde VIDEO
  HIKAYE ve **turu 74'te test edilip ONAYLANMIS SESLI MESAJ** susup basa donuyordu.
  Reels'te `kontrolGoster:false` oldugu icin kullanicinin duzeltme yolu da YOKTU.
  FIX: (a) deftere YALNIZ `_sesVerilebilir` ise girilir, (b) susturma SEBEBI
  ayrilir — `_aramaDurdurdu = !MedyaKapisi.donanimSerbest(ref)`.
  ⚠️ YAPMA: kosulsuz `kaydol`a donme; iki sebebi tek bayrakla temsil etme.
- ⚠️⚠️ **TURU 77b — AKIS VIDEOSU ARTIK DORT KAPILI.** `IndexedStack` secili
  OLMAYAN cocuklari da CANLI + LAYOUT EDILMIS tutar; sekme degisimi kaydirma
  uretmedigi icin gorunurluk gozcusu de yeniden olcmuyordu (ustelik Stack hepsini
  AYNI konuma koydugu icin gozcuyu duzeltmek TEK BASINA yetmezdi). Kapilar:
  `_gorunurOran>=0.6` · `_sayfa==sira` · **`aktifSekme==0`** ·
  **`ModalRoute.isCurrent`**. ⚠️ YAPMA: dortten birini kaldirma.
- ⚠️⚠️⚠️ **TURU 77b — HIKAYE CIZIM SOZLESMESI: TUVAL **SABIT 9:16**.**
  Onceki surumde hem editor hem izleyici katmanlari **EKRANIN TAMAMINA** gore
  konumluyordu. Ikisi ayni ekranda ayni sonucu verdigi icin **TEK CIHAZDA TEST
  EDILSE GORULMEZDI** — ama medya `contain` cizildigi icin fotografin kapladigi
  dikey oran EKRAN EN-BOYUNA gore degisiyor: ayni hikaye 390x844 ile 360x640
  arasinda fotografa gore **~%19 kayiyordu**; ucta yazi letterbox bandina dusuyordu.
  · `StoryTuvali` — medya DA katmanlar DA ayni 9:16 dikdortgene cizilir.
  · `storyKatmanGovdesi()` + `storyKatmanYerlestir()` **TEK KAYNAK** (eskiden
    editor kendi sarmalayicisini yazmisti: kutu acikken metin tavani 350 vs 338 ->
    editorde tek satira sigan cumle izleyicide IKI SATIRA sariyordu).
  · Editorun secim cercevesi **`foregroundDecoration`** — `border`/`padding`
    YERLESIMI DEGISTIRIR ve kaymayi geri getirir.
  · Konum `Align` DEGIL **`Positioned` + `FractionalTranslation(-0.5,-0.5)`**:
    `Align` cocugu `(alan-cocuk)*x`e koyar, metin sarip genisleyince hareket alani
    sifira gider ve **YATAY SURUKLEME SESSIZCE OLURDU**.
  ⚠️ YAPMA: tuvali `MediaQuery.size`a baglama; `Align`e donme; editorde ayri
    govde yazma.
- ⚠️⚠️ **TURU 77b — HIKAYE YUKLEMESI SESSIZCE IPTAL OLUYORDU** ("paylastim
  sandim, gitmemis" — dosyanin KENDI serhinin engellemeye calistigi senaryo).
  Serit bir `ListView` OGESI ve `AutomaticKeepAliveClientMixin` KULLANMIYORDU;
  akis ~356px kaydirilinca State dispose oluyor, `ref.read` `StateError` atiyor,
  `catch` + `if(!mounted) return` mesaji da yutuyordu. Medya R2'ye yukleniyor,
  `POST /stories` HIC ATILMIYOR, medya yetim kaliyordu.
  FIX: servisler TUM await'lerden ONCE yakalanir (turu 67 dersi) + KeepAlive +
  mesajlar `rootMessengerKey`ten. ⚠️ YAPMA: `ref.read`i await'lerin altina tasima.
- ⚠️⚠️⚠️ **TURU 77b — GIZLILIK: AI UCU MEDYA SAHIPLIK KAPISINI ATLIYORDU.**
  `media.ImzaliAdres(ctx, mediaID)` imzasi userID TASIMIYORDU, yani yapisal olarak
  sahiplik kontrolu YAPAMAZDI; govde yalniz `status`a bakiyordu. Ustundeki yorum
  *"cagiran yetkiyi kendisi dogrulamis olmali"* diyordu ama AI paketinde O
  DOGRULAMA YAZILMAMISTI. Elinde herhangi bir `media_id` olan biri
  `POST /ai/danisma` ile fotografin ICERIGINI okutabilirdi; AYNI id ile
  `GET /media/{id}/url` **403** donuyordu -> `erisebilir()`in TUM dallari (gizli
  hesap, engelleme, "herkesten silinmis" mesaj medyasi, 24 saati gecmis hikaye)
  tek seferde deliniyordu. Bu surumde INERT'ti (anahtar yok) ama anahtar eklendigi
  GUN aktif olacakti. FIX: `(ctx, mediaID, sahipID)` + `AND owner_id=$2` — yetki
  argumani artik TIP SISTEMINDE gorunuyor, vermeden DERLENMEZ.
  📌 CLAUDE.md turu 74 dersinin tekrari: **bir yorumun anlattigi kontrolun GOVDEDE
     gercekten olup olmadigini dogrula.**
- ⚠️⚠️ **TURU 77b — AI KOTASI FIILEN YOKTU.** `kapi()` `SELECT count(*)` okuyor,
  sayaci artiran `kaydet()` ise OpenAI cagrisi DONDUKTEN SONRA (60sn'ye kadar)
  kosuyordu; 100 escamanli istek 100'u de `count=0` gorup FATURALANIRDI.
  FIX: cagridan ONCE atomik rezervasyon
  (`INSERT ... SELECT ... WHERE (count) < kota RETURNING id`), sonuc `UPDATE`.
  Sayim `durum <> 'iptal'` (zaman asimina ugrayan istek de faturalanmis olabilir).
  ⚠️ YAPMA: sayimi `kaydet` icine geri koyma.
- ⚠️⚠️ **TURU 77b — VERI KAYBI: `isletme.detay()` HER hatayi yutup `null`
  donuyordu.** "Isletme degil (404)" ile "ag hatasi" ayirt edilemiyordu; ekran BOS
  aciliyor, kullanici tek alan doldurup kaydediyor ve sunucudaki `ON CONFLICT DO
  UPDATE` MEVCUT adres + telefon + 7 gunluk calisma saatlerini BOSA CEKIYORDU.
  FIX: 404'te `null`, digerlerinde FIRLAT; hata dalinda form CIZILMEZ + Kaydet YOK.
- 📌 **TURU 77b — DIGER KAPATILAN BULGULAR (hepsi "olu ozellik" ya da drift):**
  · Metin hikayesinde **zemin secici ULASILAMAZDI** (`_panel` otomatik 'yazi'ya
    geciyordu) — gradyan seridi HIC cizilmiyor, zemin 'mor'da kilitli kaliyordu.
  · `aci` (dondurme) modelde/JSON'da/sunucu kirpmasinda/cizimde VARDI ama ONA
    YAZAN SATIR YOKTU — iki parmak jesti eklendi.
  · Video hikayede oynaticinin tam ekran `GestureDetector`i jest arenasinda
    kazanip ILERI/GERI dokunusu YUTUYORDU -> `kontrolGoster:false`.
  · Ilan formunda **hayalet veri**: dinamik alanlar `key`siz oldugu icin tur
    degisince element yeniden kullaniliyor, `FormField.didUpdateWidget`
    `initialValue` degisimini YOK SAYIYOR -> "Metrekare" kutusunda "Ford"
    gorunuyor, `_ozellikler` bos, ilan EKSIK yayinlaniyordu.
    FIX: `ValueKey('$_tur:${a.anahtar}')`.
  · **`pickMultiImage(limit:1)` `ArgumentError` FIRLATIR** ("cannot be lower than
    2") ve UC ekranda `catch` yutuyordu: tavanin bir altinda "Fotoğraf ekle"
    SESSIZCE OLUYORDU. Ayrica `limit` platformlarca YOK SAYILABILIR -> 30
    secilirse 18 YETIM yukleme. FIX: `MedyaSecici.coklu()` + `take(kalan)`.
  · Ilan goruntulenme sayaci sahada HEP 0 (turu 76'nin gonderi hatasinin birebir
    tekrari) · "İlanlarım" HERKESIN ilanini aciyordu · urun "Tükendi" olu
    ozellikti (sunucu kabul ediyor, rozet ciziliyor, istemci HIC gondermiyordu).
  · Bos akista Android'de asagi-cek-yenile CALISMIYORDU
    (`AlwaysScrollableScrollPhysics` yok + IndexedStack canli tutuyor) — YENI
    kullanici uygulamayi oldurmeden akisini tazeleyemiyordu.
- ⚠️ **TURU 77b — ELENEN ALARM (kaynaktan curutuldu):** "urun medyasinda engelleme
  calismiyor; `blocks` kullanici id'siyle `p.isletme_id` karsilastiriliyor" iddiasi
  **YANLIS** — `isletme_urunleri.isletme_id UUID REFERENCES users(id)`, yani zaten
  kullanici id'si. ⚠️ Bunu bir daha "olasi risk" diye yazma.
- 📌 **TURU 77 — INDIR SAYFASI SAATI ALTI YERDE (kullanici ikinci kez "goremiyorum"
  dedi).** Sunucu tarafi DOGRUYDU: `no-cache, no-store, must-revalidate` +
  `cf-cache-status: DYNAMIC` + cubuk en ustte + turu 50'nin flexbox fix'i duruyor.
  Geriye kalan tek aciklama TARAYICI ONBELLEGI. Saat artik: `<title>` · mor serit ·
  **saniyesi AKAN CANLI SAAT** (sayfanin bayat olmadigini KANITLAR) · iki indirme
  dugmesinin ICI · dosya satiri. Uretici yer tutucu tabanli ve saat 5 yerden azsa
  **derlemeyi DURDURUR**. ⚠️ YAPMA: canli saati kaldirma; body'ye flex ortalama koyma.
- **ONCEKI (9 Agu 03:50):** TEST TURU 76b YAYINLANDI — android 31286588553 +
  ios 31286593307 (**751c5fc**), R2 apk=113053743 (md5 053f2e3e) ipa=23397403
  (md5 6079c71d), purge OK, **CDN birebir** (apk + ipa + index.html MD5 esit),
  indir sayfasi 03:50 (saat 3 yerde), debug imza YOK,
  **BACKEND DEPLOY EDILDI** (d0328a6; migration **026** uygulandi) + health ok,
  DB temiz (0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 65/65 UCTAN UCA KONTROL GECTI** — `node tools/uctan_uca.js`.
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 76b — GALERI KAYDIRMASI YANLIS YASLANIYORDU (build ONCESI yakalandi).**
  Ilk surumde `ListView` + `PageScrollPhysics` kullanilmisti. O fizik sayfa
  genisligini **VIEWPORT'UN TAMAMI** sanar; ogeler ekranin %78'i oldugu icin
  yaslanma her ogede biraz daha kayar ve **ucuncu-dorduncu medyada tamamen bozulur**.
  FIX: `PageView.builder` + `viewportFraction: 0.78` + **`padEnds: false`**.
  ⚠️ `padEnds: false` ZORUNLU — varsayilan `true` sayfayi ORTALAR ve ILK medyanin
  SOLUNDA bosluk birakir; Threads/Instagram'da ilk medya SOLA DAYALIDIR.
  ⚠️ `PageController` **initState**te kurulur (build icinde kurulsaydi her cizimde
  yeni controller olusur ve kaydirma konumu SIFIRLANIRDI) ve dispose edilir.
  ⚠️ YAPMA: `ListView` + `PageScrollPhysics`e geri donme.
  📌 **SUREC:** ilk build (8a47ca3) **YAYINLANMADI**, bulgu sonrasi IPTAL edilip
  yeniden alindi — *"build ALMAK yayinlamak DEGILDIR"* (turu 59b dersi, ucuncu tekrar).
- ⚠️⚠️ **TURU 76b — "GRUP OLUSTURMA NEREDE?" IKI KOK NEDEN.**
  (1) Alt menude **IKI TANE "+"** vardi ve FARKLI IS YAPIYORLARDI: ust (AppBar)
  dogrudan kisi aramaya gidiyordu (grup secenegi YOK), alt (FAB) ise
  "Yeni sohbet | Yeni grup" sheet'i aciyordu. Ust dugme daha gorunurdu ->
  kullanici "grup yok" sonucuna vardi. **AppBar'daki "+" KALDIRILDI, TEK GIRIS FAB.**
  ⚠️ YAPMA: AppBar'a tekrar "+" ekleme; yeni eylem gerekirse `_yeniSecenek` sheet'ine koy.
  (2) Sunucudaki **UC grup-uye ucu ISTEMCIDEN HIC CAGRILMIYORDU**
  (`GET/POST/DELETE /chats/{id}/members`) -> grup KURULABILIYOR ama uyeleri
  GORULEMIYOR, uye EKLENEMIYOR/CIKARILAMIYORDU. Bu sinifin **BESINCI** tekrari.
  FIX: `chats/grup_bilgi.dart` + sohbet basligina dokunma ("Grup bilgisi icin dokun"
  alt yazisi + chevron). ⚠️ `ChatScreen.isGroup` ACIKCA tasinir (`chat.type=='group'`);
  `peerId==null` varsayimi YEDEK.
- ⚠️⚠️ **TURU 76b — AKISTA OTOMATIK VIDEO (`sosyal/gorunurluk.dart`, HARICI PAKET YOK).**
  Kullanici ekran goruntusu (Threads) gonderdi: galeri **YAN YANA KAYAR**, sonraki
  medya SAGDAN SARKAR (%78 genislik, yuvarlak kose, nokta gostergesi YOK).
  **IKI KAPI birden** saglanmadan video oynamaz: kart ekranda **>=%60 gorunur** VE
  galeride **ORTADAKI oge**. Aksi halde 20 kartin videosu ayni anda calar ->
  isinma + veri + iOS'ta proses-genelinde TEK ses oturumu yuzunden **ARAMA SAGIRLASIR**.
  ⚠️ **SESSIZ baslar** — tercih degil ZORUNLULUK (kaydirirken ses patlatmak
  AVAudioSession'i ele gecirip aramayi bozar). ⚠️ YAPMA: kapilardan birini kaldirma.
  ⚠️⚠️ **SEVK ENGELI (kod okunarak yakalandi):** kart EKRAN DISINDA kuruldugu icin
  `MedyaVideo` `_tembel` moda giriyor ve **oynatici HIC YARATILMIYOR**; gorunur
  olunca `didUpdateWidget` dogrudan `_oynat()` cagiriyordu, `_c` NULL oldugu icin
  **HICBIR SEY OLMUYORDU** = otomatik oynatma sahada HIC CALISMAZDI. FIX: tembel ise `_kur()`.
- 📌 **TURU 76b — ETKILESIM CUBUGU ESITLENDI (kullanici: "ikonlarin hepsi esit
  gorunmeli"):** begeni/yorum/paylas `TextButton.icon` (21px + degisken etiket),
  kaydet ciplak `IconButton` (24px) idi. Hepsi tek `_eylem` bileseni: **SABIT 22px**
  ikon + sabit dokunma alani. "Secili" hali artik BOYUT DEGISTIRMEZ (eskiden 21->23
  buyuyup satiri kaydiriyordu). **ISTATISTIK IKONU cubuga eklendi** — eskiden yalniz
  `•••` menusunun icindeydi, yani pratikte YOKTU (yalniz YAZARA gorunur).
- 📌 **TURU 76b — KANALDA VIDEO + ISTATISTIK.** Eski "kanalda video yok" siniri
  SUNUCU YASAGI DEGILDI: `channel_posts.media_ids` turu tasimiyordu. Gonderi
  tarafiyla AYNI `media_kinds` cozumu uygulandi. Yeni
  `GET /channel-posts/{id}/istatistik` (yalniz yazar + kanal sahibi, baskasina 404).
- ⚠️⚠️⚠️ **TURU 76b — HIKAYE (STORY): "24 SAAT" GORUNURLUKTUR, SILME DEGIL.**
  Alisilmis cozum `expires_at` + supurge ile SILMEK; **bu projede VERI SILINMEZ**
  (kullanici karari 8 Agu). Satirlar KALICI, kaybolma YALNIZCA sorgu suzgeciyle
  (`created_at > now() - interval '24 hours'`). Boylece ileride "hikaye arsivi"
  EK IS GEREKTIRMEZ. ⚠️ YAPMA: `stories`e `expires_at` ekleme; yas tabanli DELETE yazma.
  · migration **026** = `stories` + `story_views` (PK `(story_id,user_id)` -> ayni
    kisi tekrar izleyince YENI SATIR ACILMAZ).
  · 6 uc: `POST/GET /stories` · `GET /stories/{userId}` · `POST /stories/{id}/view`
    · `GET /stories/{id}/viewers` · `DELETE /stories/{id}`.
  · `GET /stories` **KULLANICI BASINA GRUPLU** doner — gruplamayi SUNUCU yapar;
    istemci de yapsaydi "hepsi izlendi" hesabi iki yerde yasar ve DRIFT ederdi.
  · Gizlilik gonderiyle AYNI (gizli hesabi yalniz onayli takipci gorur, engel IKI
    YONLU); izlenme sayisi YALNIZ SAHIBINE; kendi hikayeni izlemek SAYILMAZ.
  · Istemci: serit HER ZAMAN cizilir (hikaye yokken de) — "Hikâyen" halkasi
    ozelligin VARLIGINI ogrenmenin TEK yolu.
  · Video hikaye **SABIT 15 sn**: `MedyaVideo` sureyi disari VERMIYOR; oynaticiya
    gizli kanal acmak yerine durust sabit sure secildi (oynatici zaten kirilgan).
- 📌 **TURU 76b — ANASAYFA SOL UST HAMBURGER (`sosyal/hizmet_menusu.dart`).**
  Kullanici emri: **2 SATIR cizgi** (Lucide `menu` UC cizgidir -> ikon KULLANILMADI,
  cizgiler ELLE cizildi) · kartlar **Yemek/Restoran/Alisveris** · **IKON YOK**,
  yazi KARTIN ALTINDA. Bolumler urun olarak tanimli olmadigi icin durust "yakinda"
  bildirimi gosteriliyor. ⚠️ YAPMA: kartlarin icine ikon koyma; bos ekrana baglama.
- ⚠️ **TURU 76b — UCTAN UCA ARAC 65 KONTROL.** Story SQL'leri (`BOOL_AND` +
  `GROUP BY` + 24sa penceresi) ve kanal `media_kinds` GERCEK POSTGRES'TE ILK KEZ
  kosturuldu. ⚠️ **TEST SIRASI TUZAGI:** engelleme TAKIBI DE DUSURUR ve engel
  kaldirilinca takip GERI GELMEZ; hikaye seridi "takip ettiklerim" uzerinden
  calistigi icin takip geri kurulmadan serit HAKLI OLARAK bos doner.
- **ONCEKI (9 Agu 02:36):** TEST TURU 76 YAYINLANDI — android 31283866106 +
  ios 31283871070 (0eabe4a), R2 apk=112758779 (md5 85765bc9) ipa=23363163 (md5 8ce058e5),
  purge OK, **CDN birebir** (apk + ipa + index.html MD5 esit), indir sayfasi 02:36
  (saat 3 yerde gorunuyor), debug imza YOK, iOS deployment target 16.0 dogrulandi,
  **BACKEND DEPLOY EDILDI** (deb05b2; migration **024 + 025** uygulandi, "medya: aktif (R2)")
  + health ok, DB temiz (0/0/0/0).
  ✅ **CANLI SUNUCUDA 46/46 UCTAN UCA KONTROL GECTI** — `node tools/uctan_uca.js`.
  **KULLANICI TEST EDECEK.**
- 📌 **TURU 76 — UCTAN UCA ARAC GENISLETILDI (`tools/uctan_uca.js`, 46 kontrol).**
  EN KRITIK dogrulama: `media_kinds` alt sorgusu (`unnest ... WITH ORDINALITY` +
  `array_agg`) GERCEK POSTGRES'TE HIC KOSMAMISTI. Tip/sozdizim hatasi olsaydi
  **HER gonderi sorgusu 500 dondururdu** = akis + profil + kesfet + reels +
  kaydedilenler TAMAMEN olu. Statik denetim bunu YAKALAYAMAZ.
  ⚠️ Yeni bir SQL/uc eklerken bu araca da kontrol ekle; calistirdiktan sonra
  **DB'yi TRUNCATE et** (arac gercek hesap + gonderi + medya uretir).
  ⚠️ **DUZELTILEN ESKI VARSAYIM:** "engelden sonra akis TAMAMEN BOS" YANLIS —
  engelleme takibi de DUSURUYOR (turu 75 `Block` -> `takibiKaldir`, iki yonlu),
  kullanici SOGUK BASLANGIC dalina duser ve KESFET doner. Bos DB'de tesadufen 0
  cikiyordu. Dogru olcut: **engellenenin gonderisi YOK**.
- ⚠️⚠️ **TURU 76 — GORUNTULENME SAYACI ANA GIRIS YOLLARINDA HIC ARTMIYORDU**
  (ucuncu denetim bulgusu, build yeniden alindi). Sunucu sayaci YALNIZ
  `GET /posts/{id}` icinde artiriyor; detay ekrani hazir bir `Gonderi` NESNESIYLE
  acildiginda (profil izgarasi, kesfet izgarasi, kaydedilenler — GERCEK giris
  yollarinin COGU) o istek HIC ATILMIYORDU. Kullanicinin ozellikle istedigi
  istatistik pratikte HEP 0 kalirdi. FIX: nesneyle acilista SESSIZ tazeleme.
  ⚠️ `_g` NESNESI DEGISTIRILMEZ, ALANLARI guncellenir — model akis/izgara ile
  PAYLASILIYOR; yeni nesne atansaydi detayda yapilan begeni geri donuldugunde
  izgarada gorunmezdi.
- 📌 **SUREC (turu 59b dersinin tekrari):** ILK build (`deb05b2`) **YAYINLANMADI** —
  ucuncu bulgu build ALINDIKTAN sonra cikti, kod duzeltilip build YENIDEN alindi.
  *"build ALMAK yayinlamak DEGILDIR."*
- **ONCEKI (9 Agu):** TURU 76 — KOD BITTI, 8 FAZ + DENETIM TAMAM, BUILD ALINIYOR.
  Kullanicinin 10 maddelik eksik listesi (test sonrasi) TAMAMEN karsilandi:
  1 anlik mesaj/bildirim · 2 engelleme her yuzeyde · 3 profil fotograflari ·
  4 Instagram etkilesim + istatistik · 5 ALT MENUDE ARAMA (profil arama) ·
  6 grup olusturma · 7 sohbet filtre/arsiv/sil/kaydirma · 8 gonderi duzenleme ·
  9 karma medya galerisi (foto+video) · 10 video 100 MB.
- ⚠️⚠️⚠️ **TURU 76 — DENETIMDE YAKALANAN SEVK ENGELI (build ONCESI):**
  `media_kinds` + `duzenlendi_at` ALTI gonderi sorgusuna eklendi, **YEDINCISI**
  (`Kaydedilenler`, etkilesim.go) ATLANDI -> sorgu 16 sutun donuyor, `satirlariOku`
  18 bekliyordu -> `rows.Scan` hata -> `continue` -> **HER SATIR SESSIZCE ATLANIR**.
  Derleme hatasi YOK, log YOK, olcum YOK: "Kaydedilenler" sayfasi HERKESTE BOMBOS.
  **KALICI MUHAFIZ: `internal/social/sutun_test.go`** — kaynagi okuyup 7 sorgunun
  SELECT sirasini Scan sirasiyla karsilastirir, sorgu SAYISI dususe de uyarir.
  ⚠️ YAPMA: bu testi silme; yeni sutun eklerken sorgu + Scan + `beklenenSutunlar`
  UCUNU BIRLIKTE guncelle.
- ⚠️⚠️ **TURU 76 — SESSIZE ALMA PUSH'TA UYGULANMIYORDU (ikinci denetim bulgusu).**
  FAZ 6 `muted_until`i ekledi, liste ikonu da ciziliyordu; ama bildirim yolu
  `chatMemberIDs` sonucunu OLDUGU GIBI kullaniyordu -> sessize alinan sohbet
  TELEFONU CALDIRMAYA DEVAM EDIYORDU (ozellik "acik" gorunup FIILEN calismiyor —
  turu 74'un "yorumun anlattigi kontrol govdede var mi" dersinin tekrari).
  FIX: `sessizOlmayanlar()`. ⚠️ WS yayini (`To: members`) FILTRELENMEZ — sessize
  alma BILDIRIMI susturur, SOHBETI degil. ⚠️ Rozet sayaci da degismez (WhatsApp
  da sessiz sohbette sayaci gosterir). ⚠️ FAIL-OPEN bilincli.
- ⚠️⚠️ **TURU 76 — KARMA MEDYA GALERISININ KOK NEDENI YAPISALDI.**
  `posts.media_ids` yalnizca UUID diziisiydi; her medyanin FOTO mu VIDEO mu oldugu
  istemciye **HIC DONMUYORDU**. Kart, gonderi seviyesindeki `tur` bayragina bakip
  TUM medyayi ayni cizdigi icin "foto + video ayni gonderide" sunucu izin verse
  bile YANLIS CIZILIRDI. Yeni `media_kinds` dizisi `unnest(...) WITH ORDINALITY`
  ile **SIRA KORUYARAK** doner (`media_kinds[i]` <-> `media_ids[i]`).
  ⚠️ Duz JOIN kullanma — sira GARANTI OLMAZ. ⚠️ Silinmis medya icin `'yok'`
  (NULL DEGIL: `array_agg` NULL uretirse `[]string` taramasi PATLAR ve satir
  SESSIZCE atlanir = akis bosalir).
  ⚠️ **YENI `tur` DEGERI EKLENMEDI**: `tur='foto'` artik "GALERI (1-10 karma
  medya)" demek. `posts.tur` CHECK'ini DROP/ADD etmek 015'te yasanan migration
  tuzagini acar. `video`/`reels` TEK medya olarak KALIR (reels oynaticisi tek
  kaynak varsayiyor).
- ⚠️⚠️ **TURU 76 — REELS SEKMESI `IndexedStack`TE **KOSULLU** KURULUR (SES GUVENLIGI).**
  `IndexedStack` TUM cocuklari agacta CANLI tutar; reels sekmesinden cikinca video
  oynaticisi yasar ve **SES ARKA PLANDA CALMAYA DEVAM EDERDI**. iOS'ta ses oturumu
  PROSES GENELINDE TEK nesnedir (turu 64/65/73'te aramalar tam bu yuzden sagirlasti).
  `_index == _reels ? const ReelsSayfasi() : const SizedBox.shrink()`.
  ⚠️ YAPMA: kosulsuz `ReelsSayfasi()` yapma. ⚠️ Akis AppBar'indaki Reels dugmesi
  KALDIRILDI (ayni ekrana iki giris = push edilen kopya sekme degisince ustte kalir).
- 📌 **TURU 76 — ALT MENU YENIDEN KURULDU:** Anasayfa · Ara · Reels · Mesaj · Canli ·
  Profil. **"Ara" = PROFIL ARAMA** (kullanici: "aramadan kastim normal profil arama
  instagram gibi") — CAGRI GECMISI **SILINMEDI**, `Mesaj` sekmesinin segmentine
  tasindi; SESLI ODALAR da `Canli` segmentine. ⚠️ YAPMA: `CallsTab`/`RoomsTab`i
  kaldirma (`mesgulMu` muhafizlari `oda_`/`yayin_` onlara bagli).
  ⚠️ Akis/Ara/Reels sekmelerinde AppBar YOK -> o ekranlar KENDI `SafeArea`sini
  koymak ZORUNDA.
- 📌 **TURU 76 — AVATAR KOK COZUM: `GET /users/ozet?ids=a,b,c`.** Bir yuzey avatari
  ancak verisi `avatar_media_id` TASIYORSA cizebilir; arama katmani bunu tasimiyordu
  ve **TASIYAMAZDI** (gelen arama VoIP push/CallKit yolundan gelir, orada yalnizca
  kimlik vardir). "Her cagirana avatar alani ekle" o yolda YAPISAL OLARAK cozmez.
  · `POST /calls/{id}/answer` artik `peer_id` doner — gelen aramada TEK guvenilir
    kimlik kaynagi (WS olayi kaybolabilir, CallKit ek alanlari tutarsiz).
  · `IncomingCall.callerId`: sunucu `caller_id`yi ZATEN gonderiyordu, istemci OKUMUYORDU.
  · `medya/kullanici_ozeti.dart`: **40ms toplu istek penceresi** (N+1 YOK — turu 17
    dersi), negatif onbellek, ag hatasinda onbellege YAZMAZ, logout'ta temizlenir.
  ⚠️ `/users/{id}/profile` KULLANILMADI: gizlilik kapisi + takipci sayilari tasiyor;
  arama ekraninin avatari gizli hesapta kaybolamaz. ⚠️ `/users/ozet`te UUID BICIM
  SUZGECI ZORUNLU — tek bozuk deger `= ANY($2)` sorgusunun TAMAMINI 500 yapar.
- 📌 **MIGRATION NUMARALARI (guncel):** 024 = grup sohbet (`chats.avatar_media_id`,
  `chat_members.cleared_at`), 025 = `posts.duzenlendi_at`. Sonraki **026**'dan.
- **ONCEKI (8 Agu 22:40):** TEST TURU 75 YAYINLANDI — android 31274404137 +
  ios 31274409665 (1aa6274), R2 apk=112201055 (md5 024bc3af) ipa=23288435 (md5 f9cd1183),
  purge OK, **CDN birebir**, indir sayfasi 22:40, debug imza YOK, iOS min 16.0 dogrulandi,
  **BACKEND DEPLOY EDILDI** (turu 64 -> 75; migration 020/021/022/023) + health ok,
  DB temiz (0/0/0/0).
- ✅✅ **TEST SONUCU (8 Agu, kullanici): "hepsini test ettim, mukemmel calisiyor".**
  Tek seferde dogrulanan yigin — ucu de ILK KEZ sahada test edildi:
  · **turu 73** oda/yayin duraklatma (iOS dahil), SesSahipligi defteri, ses birimi merdiveni
  · **turu 74** medya (fotograf + sesli mesaj), engelleme, sikayet, mesaj silme
  · **turu 75** sosyal katman (akis/profil/takip/gonderi/begeni/yorum/kaydetme/reels/
    bildirimler) + kanal
  ⏳ **KULLANICI EKSIKLERI YAZACAK — BEKLENIYOR.**
- ⚠️⚠️⚠️ **TURU 75 YAYINDA YAKALANAN SEVK ENGELI: MEDYA SUNUCUDA KAPALIYDI.**
  Deploy sonrasi log: **"medya: R2_* env EKSIK — MEDYA KAPALI"**. /health "ok"
  donuyordu, API saglikli aciliyordu — hata SATIR ARASINDAYDI.
  **KOK NEDEN:** `backend/docker-compose.yml` **env_file: DEGIL** acik **environment:**
  eslemesi kullaniyor. Sunucudaki `.env` dosyasina R2 anahtarlarini eklemek
  **TEK BASINA YETMEDI**; degiskenlerin KABA gecmesi icin compose'da da eslenmesi
  gerekiyordu.
  **ETKISI:** yukleme, profil fotografi, gonderi/kanal gorselleri ve REELS tamamen olu
  olacakti (turu 74 medya + turu 75 sosyal katmanin GORSEL ayaginin hepsi).
  ⚠️ **YAPMA: yeni bir env degiskeni eklerken yalniz `.env`e yazip birakma; compose'daki
  `environment:` blogunu da guncelle (IKISI AYRI YERDIR).**
- ✅ **TURU 75 — UCTAN UCA CANLI DOGRULAMA: 27/27 GECTI** (scratchpad/uctan_uca.js).
  Gercek sunucuda, **IKI AYRI HESAPLA** (tek cihazda gorunmeyen hatalar icin SART):
  presign -> R2 PUT -> commit -> gonderi -> takip -> akis -> **B'nin A'nin gorselini
  imzali adresten BIREBIR indirmesi** -> begeni/yorum/kaydetme -> kaydedilenler ->
  **engelleme sonrasi profil gonderilerinin BOSALMASI** -> kanal ac/gonderi/abone/
  `sessiz` alani/kesfet filtresi -> reels -> bildirimler.
  ⚠️ Bu betik SURUM RUTININE EKLENDI: sosyal/medya degisen her turda kosulmali.
- 📌 **MIGRATION DOGRULAMA YONTEMI (yeni rutin adimi):** deploy ONCESI sunucuda
  ATILABILIR kopya DB (`CREATE DATABASE mig_dogrula`) acilip TUM migration'lar sirayla
  `psql -v ON_ERROR_STOP=1` ile uygulanir, sonra DROP edilir. Gercek veriye DOKUNULMAZ.
  Hatali bir migration API'yi ACILISTA oldurur; bu adim onu deploy'dan once yakalar.
  (Turu 75'te 9/9 temiz gecti.)
- **ONCEKI (8 Agu):** TURU 75 kodu — sosyal katman + kanal.
  Kullanici karari: **"testi en son yapacagiz, arastirma bittikten sonra hersyi bitir"**.
  Turu 73/74 HENUZ TEST EDILMEDI — hepsi TEK SEFERDE test edilecek.
  ⏳ **KULLANICIYA SORULACAK: build alalim mi?** (CLAUDE.md kural 0)
- ✅ **TURU 75 — SOSYAL KATMAN + KANAL TAMAMLANDI.**
  · migration **020** takip+sayaclar+gizli hesap+bildirimler · **021** gonderi/begeni/
    yorum/kaydetme · **022** kanal · **023** denetimde bulunan eksik indeksler
  · `internal/users/takip.go` · `internal/social/{handler,etkilesim}.go` ·
    `internal/kanal/handler.go` · 13 yeni Flutter ekrani (sosyal/ + kanal/)
  · Alt menu **6 sekme**: Akış · Sohbet · Arama · Oda · Canlı · Profil
    ⚠️ `_index` sabitleri ustune yazilmis kosullar var (0=akis -> ust AppBar GIZLENIR
    cunku akis kendi AppBar'ini cizer; 1=sohbet -> "yeni sohbet" + dugmesi).
    ⚠️ YAPMA: sirayi degistirme, 7. sekme ekleme (360dp'de etiketler sinirda).
  · Kanallar, Akis'in ustundeki **"Akış | Kanallar" segment secicisinde** (IndexedStack).
- ⚠️⚠️ **TURU 75 — FAN-OUT KARARI: OKUMA ZAMANI (akis VE kanal).**
  Yazma zamani fan-out'ta 10.000 takipcili biri gonderi atinca **10.000 satir yazilir**.
  cx33'te Postgres LiveKit ile **AYNI 4 vCPU'yu** paylasiyor — bu yazma firtinasi SFU'yu
  ac birakir (aramalar/yayinlar bozulur). Geri donulebilirlik de bu yonde: read-time ->
  hibrit KOLAY, tersi zor. ⚠️ YAPMA: olcum gormeden yazma zamanina gecme.
- ⚠️⚠️⚠️ **TURU 75 — KANAL `chats` HATTINI KULLANMIYOR (kod okunarak bulundu).**
  CLAUDE.md "tek chats tablosu, type: channel" diyor ve CHECK'i 'channel'i kabul ediyor.
  Ama `chat.SendMessage` her mesajda **UYE BASINA AYRI INSERT** yapiyor
  (`for _, uid := range members { INSERT INTO message_receipts ... }`) -> 10.000 aboneli
  kanalda TEK gonderi = **10.000 ayri sorgu**. `hub.Publish(To: members)` ve
  `push.NotifyUsers(members,...)` ayni diziyi tasiyor; `ListChats` okunmamisi
  `message_receipts` COUNT(*) ile buluyor. Ustelik kanalda **okundu bilgisi zaten
  istenmiyor** (WhatsApp kanallarinda tik yok) — o satirlarin urun karsiligi da YOK.
  COZUM: okunmamis = (kanal,kullanici) basina **TEK damga** (`son_okuma`).
  ⚠️ YAPMA: kanali `messages`/`message_receipts` hattina tasima.
  ⚠️ Kanal push'u **bilincli olarak YOK** (ilk surum): `NotifyUsers` tum aliciyi tek
  cagrida isliyor, FCM'in 500 hedef/istek siniri asilir. Parcali+kuyruklu gonderim AYRI IS.
- ⚠️⚠️⚠️ **TURU 75b DENETIMI — 5 SEVK ENGELI (38 bulgu, 18 onaylandi, 20 elendi):**
  **(1) AKISTAKI TUM GORSEL/VIDEO IZLEYICIYE 403 DONUYORDU.** `media.erisebilir()`
  yalniz iki dal taniyordu (mesaja bagli / avatar); `posts.media_ids` ve
  `channel_posts.media_ids` icin DAL YOKTU. Akis sadece id donduruyor, istemci her
  gorsel icin `GET /media/{id}/url` cagiriyor -> PAYLASANDAN BASKA HERKESE 403.
  ⚠️⚠️ **TEK CIHAZDA TEST EDILSE GORULMEZDI**: kapi `if sahip != userID && ...` —
  paylasan kendi gorselini kisa devreyle gorur; hata YALNIZ ikinci hesapta cikar.
  ⚠️ YAPMA: yeni dallari "herhangi bir gonderiye bagliysa serbest"e gevsetme (gizli
  hesap medyasi sizar + engelleme delinir).
  **(2) `/users/{id}/posts` ENGEL KONTROLUNU ATLIYORDU** — engellenen kisi profile girip
  her seyi okuyabiliyordu. Predikat DORT sorguya kopyalanmis, BESINCISINDE dusmustu
  (turu 72b/H "ayni kuralin iki kopyasi drift eder" dersinin tekrari).
  Artik `const engelYok` TEK KAYNAK. ⚠️ YAPMA: yuklemi sorgulara elle kopyalama.
  **(3) YUKLEME BITERKEN `Navigator.pop()` YANLIS ROUTE'U KAPATIYORDU** (acik onay
  diyalogu varsa) -> gonderi sunucuda OLUSUR ama ekran kalir, kullanici tekrar basar
  -> **CIFT GONDERI**. FIX: `ModalRoute.of` ile kendi route'unu ADRESLE + `popUntil`.
  **(4) VIDEO OYNATICI KURULUMU KAPISIZDI.** `video_player` iOS'ta `initialize()`
  sirasinda `setMixWithOthers(...)` gonderir; bu RTCAudioSession kilidinin **DISINDAN**
  AVAudioSession'i yeniden yapilandirir. ⚠️ **`mixWithOthers: true` "oturumu ele gecirme"
  demek, "oturuma HIC DOKUNMA" DEMEK DEGIL.** FIX: `_kur()` basinda
  `MedyaKapisi.donanimSerbest` kapisi. ⚠️ YAPMA: bu kapiyi kaldirma.
  **(5) KENDI PROFILIMDE "Takip et/Mesaj/Engelle/Şikayet"** cikiyordu (hicbir "bu benim"
  kapisi yoktu). FIX: `_benimMi` + "Profili düzenle/Kaydedilenler/**Gizli hesap**".
- ⚠️⚠️ **TURU 75b — OLU OZELLIKLER (ayni sinif ucuncu ve dorduncu kez):**
  · **Gizli hesap TAMAMEN ULASILAMAZDI**: `gizlilikAyarla()` yazilmis ama HIC
    cagrilmiyordu -> hicbiri gizli hesap olamiyor, dolayisiyla takip isteginin
    'bekliyor' dali + FollowApprove/Reject uclari + "Takip istekleri" ekrani + profil
    kilit dallari HEPSI olu kaliyordu.
  · **Kaydetme "KARA DELIK"ti**: `post_saves` yaziliyor, LISTELEYEN uc/ekran YOK.
    Yeni `GET /users/me/saved` + `kaydedilenler_sayfasi.dart`.
  · `posts.goruntulenme` OLU SUTUNDU (021'de var, yazan/okuyan yok) — baglandi.
  ⚠️ **DERS (dorduncu tekrar): bir sutun/servis/dugme ekledigin AN onu OKUYAN yolu da
  yaz. Onceki ornekler: `deleted_for_all`, `blocks`, foto gonderme, ses notu.**
- ⚠️⚠️ **TURU 75b — `nil` DILIM SQL NULL GONDERIR (SEVK ENGELIYDI).**
  `social.Create` icinde `req.MediaIDs = nil` yaziliyordu; `posts.media_ids` **NOT NULL**
  -> **HER YAZI GONDERISI 500 DONECEKTI.** FIX: `[]string{}`.
  ⚠️ YAPMA: `MediaIDs`i tekrar `nil`e set etme.
- ⚠️⚠️ **TURU 75b — KENDI ALARMIMI KENDIM CURUTTUM (yontem dersi).**
  Once "pgx `[]string`i `uuid[]`e kodlayamiyor, dolayisiyla TUM `= ANY($1)` cagrilari
  (push, engelleme, medya sahipligi) BOZUK" sonucuna vardim. **YANLISTI.** pgx v5.7.4
  `extended_query_builder.go:55-76` tercih edilen bicim hata verirse **DIGER bicimi
  dener** ve metin bicimi calisir. Kaynak okunarak curutuldu -> buyuk ve gereksiz bir
  refactor'dan donuldu.
  📌 **DERS: "kanit" diye sunulan bir olcumun HANGI KATMANI olctugune bak.**
  `Map.Encode`i dogrudan cagirmak, sorgu yolundaki geri donus mantigini ATLIYOR.
  ⚠️ YAPMA: `[]string` -> `[]pgtype.UUID` donusumu ekleme; OLCULDU, gerek YOK.
- ⚠️⚠️ **TURU 75 — YENI KALICI TESTLER (ikisi de canli DB GEREKTIRMEZ):**
  · `cmd/api/rota_test.go` — chi CAKISAN desenlerde **calisma aninda PANIK** atar ve
    `go build`/`go vet` bunu YAKALAMAZ. Desenleri `main.go` **KAYNAGINDAN** regex ile
    okur -> DRIFT YOK. **126 rota cakismasiz**; riskli STATIK-vs-PARAMETRE yollari
    (`/users/me/follow-requests` vs `/users/{id}/profile`, `/channels/kesfet` vs
    `/channels/{id}`) chi'nin GERI DONUS davranisiyla dogru cozuluyor — test kanitliyor.
    ⚠️ YAPMA: desenleri teste elle kopyalama.
  · `internal/social/tip_test.go` — `uuid[]` tarama (bozulsaydi `satirlariOku`daki
    `if rows.Scan(...) != nil { continue }` satirlari SESSIZCE atlar, akis BOMBOS
    donerdi) + `nil` vs bos dilim + `bigint -> int64`.
- ⚠️ **TURU 75 — GORUNTULENME YALNIZ REELS + GONDERI DETAYINDA ARTAR, AKISTA ARTMAZ.**
  Akista 20 kart TEK ISTEKTE gelir ama cogu HIC gorulmez; orada saymak sayiyi YALAN yapar.
  Kart uzerinde goruntulenme YALNIZ YAZARINA gorunur (Instagram deseni); reels'te herkese.
  ⚠️ YAPMA: sayimi `Akis` icine kopyalama.
- ⚠️ **DURUST SINIR — kanal gonderisinde VIDEO YOK (ilk surum):** `channel_posts.media_ids`
  medyanin TURUNU tasimiyor; istemci bir id'nin video mu foto mu oldugunu BILEMEZ ve
  video id'sini `MedyaGorsel`e verirse KIRIK GORSEL cizer. Once sunucu `media_kinds`
  dondurmeli. ⚠️ YAPMA: tur bilgisi olmadan medyayi video sanip oynatmaya calisma.
- ⚠️⚠️ **VERI POLITIKASI (kullanici karari 8 Agu): VERI SILINMEZ.** Hicbir semada yas
  tabanli silme YOK; depolama buyur, maliyet kabul edildi. Istisnalar yalnizca yasal
  zorunluluk: sahibi siler · hesap silinir (KVKK) · mahkeme/BTK karari · CSAM.
  ⚠️ YAPMA: herhangi bir tabloya `expires_at`/otomatik supurge ekleme.
- **KALDIGIMIZ YER (8 Agu):** TURU 74 — KOD YAZILIYOR, BUILD ALINMADI.
  Kullanici karari: **"testi en son yapacagiz, arastirma bittikten sonra hersyi bitir"** —
  yani medya + sosyal katman TAMAMLANIP TEK SEFERDE test edilecek. Turu 73 HENUZ TEST EDILMEDI.
  ⏳ Arka planda **sosyal katman arastirmasi** kosuyor (profil/takip/kanal/akis/gonderi/reels).
- ⚠️⚠️⚠️ **TURU 74 — BEKLEYEN OLCUMLER OKUNDU, UC ACIK SORU KAPANDI (Sentry, 14 gun):**
  **(1) TURU 68 KAPANDI — `supportsHolding: false` SAHADA DOGRULANDI.** `activeCalls()`
  yaniti: `maximumCallGroups: 2, maximumCallsPerCallGroup: 1, supportsHolding: false,
  supportsGrouping: false`. Deger CallKit'e ULASIYOR.
  🚫 **BEKLEYEN "maximumCallGroups 2 -> 1" KARARI ARTIK GEREKSIZ — KALICI IPTAL.**
  ⚠️ YAPMA: bir daha onerme. `maximumCallsPerCallGroup:1` ile birlikte toplam kapasite 1
  olur ve ikinci `reportNewIncomingCall` HATA donebilir -> telefon CALMAZ + iOS 13 kurali
  ihlali (turu 33/67 "arama karsilanmiyor" semptomu geri gelir).
  **(2) TURU 69 — IKI KAPATMA YOLU DA CALISIYOR:** `kaynak=eklenti` **25 olay**,
  `kaynak=native` **9 olay**. KRITIK ayrinti: `kaynak=native yasam=AppLifecycleState.paused`
  **8 kez** -> native kanca UYGULAMA ARKA PLANDAYKEN devreye giriyor, yani tam da kullanicinin
  sikayet ettigi senaryoyu yakaliyor. ⚠️ Kanca GEREKSIZ DEGIL, kaldirma.
  **(3) ⚠️ TURU 63 HIPOTEZI OLCUMLE CURUTULDU:** duzeltilmis metrikle
  `tamponMs=13 jitterMs=4.0 gizlenenOrnek=0 recvPaketSn=8`. **13 ms jitter tamponu YOK
  HUKMUNDEDIR** — bekletmeden cikista BIRIKMIS SES YOK.
  ⚠️ "Ses gecikmesi jitter tamponundan geliyor" aciklamasi **GECERSIZ**; bir daha bu
  hipotezle yola cikma. Gecikme yine bildirilirse BASKA yerde ara.
- ⚠️⚠️ **TURU 74 — OLCUM KUSURU (`holdDurumunuOlc`) DUZELTILDI:** iOS'ta
  `FlutterCallkitIncoming.activeCalls()` **Map DEGIL `CallKitParams` NESNESI** donduruyor;
  `c is Map` FALSE kalip `c.toString()` TUM NESNEYI (~900 karakter: id, isim, extra,
  bildirim ayarlari) mesaja basiyordu. Iki zarari: (a) aranan `hold=` degeri BASLIKTAN
  TASIP gorunmuyordu, (b) mesajda callId gectigi icin Sentry **her aramayi AYRI ISSUE**
  yapmis (tek olcum 6 kayda dagilmis). Artik tipten bagimsiz ALAN CIKARILIR; mesaj KISA
  ve SABIT -> tek issue'da gruplanir.
  ⚠️ YAPMA: `c.toString()`e geri donme; olcum mesajina callId koyma.
  ⚠️ **GENEL DERS: bir olcum eklerken DONEN TIPI DOGRULA.** Bu olcum 6 turdur
  yaziliyordu ve okunamaz oldugu icin sorunun cevabini 6 tur GECIKTIRDI.
- ⚠️⚠️⚠️ **TURU 74 — ENGELLEME SAHADA HIC CALISMIYORDU (kod okunarak tespit).**
  `blocks` tablosu **001_init.sql'den beri VAR** ama ONA YAZAN DA OKUYAN DA YOKTU.
  Ustelik `SendMessage` icinde `chatMemberIDs` cagrisinin ustundeki yorum yillardir
  **"uyelik + engel kontrolu"** diyordu — YANLIS; o fonksiyon yalnizca uyelige bakiyor.
  Yani engellemenin ne YOLU vardi ne de olsa UYGULANIRDI.
  ⚠️ **DERS: bir yorumun anlattigi kontrolun GOVDEDE gercekten olup olmadigini dogrula.**
  **EKLENENLER (turu 74):**
  · migration **014_reports.sql** — `reports` tablosu. `hedef_tur` SERBEST METIN (CHECK YOK):
    yeni icerik tipleri (medya/gonderi/reels/kanal) migration GEREKTIRMEZ.
    `UNIQUE(reporter_id,hedef_tur,hedef_id)` -> sikayet spam'i satir biriktirmez.
    ⚠️ YAPMA: `hedef_tur`a CHECK constraint koyma.
  · `internal/users/moderasyon.go` — POST/DELETE `/users/{id}/block` · GET `/users/me/blocks`
    · POST `/reports`. Hepsi IDEMPOTENT; hedef yoksa 404 (FK hatasi 500'e dusmesin).
  · `internal/chat.engelliMi()` **TEK KAYNAK** + `SendMessage`da uygulama.
    ⚠️ Kural **CIFT YONLU**: taraflardan HANGISI digerini engellediyse mesaj GITMEZ
    (tek yonlu olsaydi engelleyen taraf karsisindakini rahatsiz etmeye DEVAM edebilirdi).
    ⚠️ **FAIL-CLOSED**: engel sorgusu patlarsa mesaj GECMEZ.
    ⚠️ Hata metni **NOTR** ("bu kişiye mesaj gönderilemiyor") — "seni engelledi" demek
    engellemeyi IFSA eder (WhatsApp da gizler).
  · `DELETE /chats/{chatID}/messages/{msgID}` — herkesten silme. `deleted_for_all` sutunu
    001'den beri VARDI ve listeleme sorgulari onu OKUYORDU ama SILME UCU YOKTU (olu sutun).
    Yalniz GONDEREN siler; satir FIZIKSEL SILINMEZ (icerik bosaltilir) -> sira ve okundu
    bilgisi bozulmaz. WS `message.deleted` GONDERENE DE gider (ikinci cihaz).
    ⚠️ YAPMA: sure siniri koyma (icerik kaldirma yukumlulugu sureli olamaz).
    ⚠️ YAPMA: satiri fiziksel DELETE etme (`message_receipts` FK'si + sohbet sirasi bozulur).
  **NEDEN SIMDI:** App Store Review Guideline 1.2 (UGC) engelleme + sikayet + icerik
  kaldirmayi BIRLIKTE sart kosuyor; medya ve herkese acik gonderi gelmeden ONCE durmali.
- ⚠️ **TURU 74 — `media_url` ISTEMCI ALANI KALDIRILDI (guvenlik).** `sendMessageReq.MediaURL`
  istemciden SERBESTCE alinip DOGRULANMADAN `messages`a INSERT ediliyordu. Istemci bu alani
  HIC GONDERMIYOR (`chats_provider.dart:80` yalnizca `{'type','content'}`) — KULLANILMIYOR
  ama ACIK duruyordu. Herhangi biri `{"type":"image","media_url":"https://kotu/izleme.gif"}`
  gonderip alicinin IP'sini/saatini toplayabilir (IZLEME PIKSELI), sahte banner cizdirebilir
  (OLTALAMA), sunucu onizlemesi eklenirse SSRF acabilirdi. `models.dart:80` bu alani ZATEN
  okuyor -> gorsel cizimi eklendigi ANDA somurulebilir olacakti.
  ⚠️ YAPMA: alani geri ekleme. Medya gelince URL **SUNUCUDA turetilecek** (medya kaydinin
  id'sinden), istemci ASLA URL vermez.
- 📌 **MIGRATION NUMARALARI:** 014 = `reports` (turu 74). Medya migration'lari **015'ten**,
  sosyal katman **020'den** baslar (medya-plani.md "014'ten devam" diyordu — GUNCELLENDI).
- ⏳ **ERTELENDI (bilincli karar, turu 74):** ~500 satirlik olu bekletme/park zinciri
  (`ParkEdilenArama`/`parkEt`/`devamEt`/`beklemeyeAl` govdesi/`_iosSesOturumuGarantile`/
  `GebzemSesKurtar` + call_screen bekletme paneli) HALA DURUYOR.
  **GEREKCE:** `active_call_controller.dart` bu projenin en kirilgan dosyasi (3600+ satir,
  74 turluk birikim) ve turu 67'de bu silme denenirken dosya BOZULDU. Test EN SONDA tek
  seferde yapilacagi icin, oradan 500 satir silip ustune medya + sosyal katman koymak,
  arama bozulursa SEBEBI AYIRT EDILEMEZ hale getirir. **Buyuk testten SONRA kendi turunda.**
  ⚠️ `beklemeyeAl`in `!bekletmeAcik` dali **CANLI** (kacak CallKit hold olayinda aramayi
  BITIRIYOR) — silinirken o dal KORUNMALI.
- **ONCEKI (7 Agu 22:31):** TEST TURU 73 YAYINLANDI — android 31210896371 +
  ios 31210908402 (c5ccec7), R2 apk=108271245 (md5 07f4b9dc) ipa=22365997 (md5 43ccd140),
  purge OK, **CDN birebir**, indir sayfasi 22:31, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz (0/0/0/0). **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 73 — ODA/YAYIN DURAKLATMASI ARTIK iOS'TA DA ACIK (kullanici emri:
  "hepsine yapsana android ne alaka test edelim iste").**
  Turu 72'de yalniz Android acikti; gerekce turu 65'te OLCULEN `!pri` idi. Acmanin
  BEDELI IKI YAPISAL KAPIYLA odendi — ikisi de ZORUNLU, biri kaldirilirsa iOS BOZULUR:
  · **`SesSahipligi` DEFTERI** (`medya_beklet.dart`) — iOS'ta `isAudioEnabled` PROSES
    GENELINDE TEK bayraktir ve turu 73'e kadar arama ile oda/yayin AYNI ANDA hic
    yasamamisti. Iki yonlu yikim vardi: (a) ARAMA kapanisi (`_odaTemizle`) hala bagli
    odanin sesini OLDURUYORDU ("devam"da SESSIZLIK — turu 72'nin iOS'ta calismamasinin
    GERCEK sebebi; `!pri` TEK BASINA degil); (b) ODA/YAYIN kapanisi SUREN ARAMAYI
    sessize dusuruyordu. Artik her tuketici kaydolur (`arama_` / `oda_` / `yayin_b_` /
    `yayin_i_`) ve kapanirken BASKA TURDEN sahip varsa ses birimine DOKUNMAZ.
    ⚠️ Nesil jetonu (`_sesNesilSayaci`) yalniz ARAMA-ARAMA yarisini korur, oda/yayini GORMEZ.
  · **`iosSesBirimiAc` MERDIVENI** — "devam" ile arama kapanisi YARIS halinde; oturumu
    CallKit tutuyor olabilir. 5 basamak (0/200/600/1200/2000ms), olcut native
    `configOk && active`, tukenirse GERCEK Sentry olayi + kullaniciya durust mesaj.
    ⚠️ `required gecerli` canlilik kapisi ZORUNLU (bkz. turu 73b/1).
  · `mesgulMu` muafiyetindeki `Platform.isAndroid` KALDIRILDI -> iPhone'da odadayken/
    yayindayken arama artik GERCEKTEN kabul edilebiliyor (eskiden `answer()` null
    donuyor, CallKit kapaniyor, arayan "reddedildi" goruyordu).
  📌 **OLCUM — TEST SONRASI BAK:** `oda/yayin ses birimi ACILAMADI (oda|yayinci|
  izleyici): hata=..` cikarsa `!pri` iOS'ta HALA gecerli demektir; `N. denemede
  ACILDI` cikarsa merdiven kurtardi ve basamak sayisi ayarlanabilir.
- ⚠️⚠️ **TURU 73b — DENETIM 4 YUKSEK BULDU (ucu iOS ACILISININ YENI SINIF HATASI):**
  **(1) MERDIVENDE CANLILIK KAPISI YOKTU** — ~4sn await ediyor, hicbir basamakta
  `mounted`/`_ayrildi`/`_kapandi` kontrolu yoktu. Kullanici "devam"a basip odadan
  CIKARSA kapanis ses birimini kapatir, merdivenin sonraki basamagi GERI ACAR ->
  **AVAudioSession SAHIPSIZ ACIK** kalir (iPhone mikrofon gostergesi SONMEZ, sonraki
  aramanin kurulumuyla cekisir). ⚠️ YAPMA: `gecerli`yi opsiyonel yapma veya yalniz basa koyma.
  **(2) ODA/YAYIN `resumed` DALINDAKI `_sesiAc(true)` AKTIF ARAMAYI YIKIYORDU** —
  native `setAudioEnabled(true)` KOSULSUZ ZORLA TOGGLE yapar (yikip yeniden kurar).
  Turu 72'ye kadar zararsizdi cunku iOS'ta oda ile arama AYNI ANDA YASAYAMIYORDU.
  Gorusme surerken uygulamayi arka plana alip donmek (kilit ekrani/bildirim — arama
  sirasinda COK SIK) ARAMANIN ses birimini ~50-150ms sagirlastiriyor, hata da
  `catch (_)` ile yutuluyordu. FIX: uc ekranda da `if (!SesSahipligi.aramaCanli)`.
  ⚠️⚠️ **DERS: bir ozelligi YENI BIR PLATFORMA acarken, o platformda DAHA ONCE
  ULASILAMAYAN kod yollarinin artik ULASILABILIR oldugunu varsay ve HEPSINI yeniden
  degerlendir.** Buradaki uc bulgunun ortak koku tam olarak buydu.
  **(3) `geriAra()` DEFTERDE KALICI `arama_` SIZINTISI BIRAKIYORDU** — eski id'yi
  dusurebilecek tek yer `leave(eskiId)` ve o bir daha CAGRILAMAZ (`arama` artik yeni
  aramayi gosterir). "Geri ara"ya BIR KEZ basmak yeter: `aramaCanli` proses omru
  boyunca true takilir ve odadan/yayindan cikinca ses birimi BIR DAHA kapanmaz.
  **(4)** Ayni sizintinin ikinci yolu: bayat-`leave` kapisi (turu 69b'de sahada
  gerceklestigi KANITLI) `birak`i atliyordu -> kapinin USTUNE tasindi.
  ⚠️ YAPMA: `birak`i tekrar kapinin ALTINA tasima; `_odaTemizle` yalniz `oda_`/`yayin_`
  onekine baktigi icin erken birakma ZARARSIZ.
  **(5 ORTA) MERDIVEN `_micHedef` EZILME PENCERESINI ~100ms'DEN ~4sn'YE CIKARMISTI:**
  `_micOn` UI bayragi merdivenin ALTINDA yaziliyordu, yani 4sn boyunca BAYAT `false`.
  O pencerede gelen ikinci arama `_micHedef`i **false** yakalar ve arama bitince
  mikrofon BIR DAHA ACILMAZ. `live_broadcast_screen` bu deseni ZATEN dogru yapiyordu —
  **uc ekran arasindaki ASIMETRI hatanin kendisiydi.**
  **(6 ORTA)** Defter statikti, sifirlama yoktu + yayinci ile izleyici AYNI anahtari
  kullaniyordu (ust uste binmede biri digerinin kaydini siler) -> `SesSahipligi.sifirla()`
  (logout'ta cagrilir) + `yayin_b_` / `yayin_i_` ayrimi.
  **(8 DUSUK) KENDI TURU 72b UYARIM KAYNAKTAN CURUTULDU:** "`medyaBeklet` iOS'ta
  DOLAYLI olarak AVAudioSession'i yeniden yapilandirabilir" yolu YOK —
  `setMicrophoneEnabled(false)` -> `publication.mute(...)`; `onUnpublish` YALNIZ
  `unpublishTrack`/`removePublishedTrack` yolundan cagrilir (`_localTrackCount`
  DEGISMEZ); `RemoteTrackPublication.disable()` de `track.stop()` YAPMAZ
  (`_remoteTrackCount` DEGISMEZ). Yani `_onAudioTrackCountDidChange` HIC tetiklenmiyor.
  ⚠️ Bunu "olasi risk" diye geri yazma — kaynak okundu, tetiklenmiyor.
- **ONCEKI (7 Agu 16:35):** TEST TURU 70+71+72 YAYINLANDI — android 31182191326 +
  ios 31182204197 (7084341), R2 apk=108254865 (md5 024156c0) ipa=22361813 (md5 341a1981),
  purge OK, CDN birebir, indir sayfasi 16:35, backend DEGISMEDI + health ok, DB temiz.
- ⚠️⚠️⚠️ **TURU 72 — ODA/YAYIN DURAKLATMA (KULLANICI TASARIMI).**
  *"Oda kurdum konusuyorum, telefona cevap verdigimde odadaki mikrofonu kapat ve
  profilde pause isareti Bekliyor olsun; canli yayinda da mikrofonu kapat ve ekrani
  blurla; gorusme bitince 'Sohbete devam' / 'Canli yayina devam' olsun."*
  · Ortak primitif **`mobile/lib/features/calls/medya_beklet.dart`** — arama
    tarafindaki kanitli govde KOPYALANMADI, ORAYA CIKARILDI (tek kaynak).
  · **`disable()` kullanilir, `unsubscribe()` DEGIL** (abonelik korunur, donus ANINDA;
    unsubscribe ile yeniden pazarlik gerekir ve ses saniyelerce gec gelir).
  · **BAGLANTI ACIK KALIR:** sunucuda oda/yayin BITMEZ, nabiz SURER, izleyiciler DUSMEZ.
  · **DEVAM OTOMATIK DEGIL, DUGMEYLE** — telefon kapanir kapanmaz mikrofonun
    kendiliginden acilmasi gizlilik riski. ⚠️ YAPMA: otomatik devama cevirme.
  · Mesgulluk kapisi gevsetildi: odadayken/yayindayken telefon artik **CALAR**.
  ⚠️⚠️ **iOS'TA DURAKLATMA KAPALI (BILINCLI):** turu 65'te CallKit sonrasi ses birimini
    geri acma denememizin **`!pri` (InsufficientPriority)** ile REDDEDILDIGI OLCUMLE
    KANITLANDI. Acsaydik "odaya dondum ama ses yok" yasanirdi.
    ⚠️ YAPMA: olcum yesil donmeden iOS'u acma.
  ⚠️⚠️ **`medyaBeklet` `_sesiAc(false)` CAGIRAMAZ** — o native `gebzem/audio` uzerinden
    `RTCAudioSession.isAudioEnabled` yazar; PROSES GENELINDE TEK nesnedir ve AKTIF
    ARAMANIN sesini de OLDURUR. (iOS'ta livekit'in modul-global track sayaci uzerinden
    DOLAYLI dokunma yolu VAR — dosya serhinde yazili, iOS acilirsa ILK bakilacak yer.)
- ⚠️⚠️⚠️ **TURU 72b — BUILD ONCESI DENETIM 16 SEVK ENGELI BULDU (4 ajan). KALICI DERSLER:**
  **(A) GSM ARAMASI TETIGI HIC BAGLI DEGILDI** — tetikleyici yalniz `_aramaCtrl`
  (Gebzem aramasi) dinliyordu; `PipService.gsmAramada` bir ValueNotifier ve uc ekranda
  da `addListener` YOKTU. Yani ozelligin **MANSET SENARYOSU** ("telefona cevap
  verdigimde") calismiyordu, ustelik `odayaDevam`daki GSM kapisi **HIC GIRILEMEYEN**
  bir durum icin yazilmisti. ⚠️ YAPMA: iki dinleyiciden birini kaldirma.
  **(B) "DEVAM" DUGMESI AKTIF GEBZEM ARAMASINI SORMUYORDU** (yalniz GSM). Kullanici
  arama ekranini KUCULTUP (`call_screen._minimize` -> `Navigator.pop`) odaya/yayina
  donebiliyor; serit HER ZAMAN etkin oldugu icin basinca mikrofon + uzak sesler GERI
  ACILIYOR -> odadakiler/izleyiciler GORUSMEYI DUYUYOR (turu 56/63/71 aciginin aynisi).
  ⚠️ YAPMA: `arama != null` kapisini kaldirma.
  **(C) DURAKLATMA KATMANI STACK'IN ORTASINDAYDI** — Stack SON cocugu EN USTE cizer ve
  hit-test'i TERS sirada yapar. Ust bar (**MIKROFON DUGMESI**) ve alt serit ("Canliya
  katil") hem BLUR'LANMIYOR hem TIKLANABILIYORDU; basan kullanici yayini GERI ACIYOR,
  ekran "Bekliyor" demeye DEVAM ediyordu (`_duraklatildi` true kaldigi icin tetikleyici
  de KENDINI ONARMIYOR). ⚠️ Katman **EN SONDA** + `GestureDetector(HitTestBehavior.opaque)`.
  ⚠️ YAPMA: `IgnorePointer` kullanma (dokunus alttakilere GECER); katmani ortaya tasima.
  **(D) BAGLANIRKEN DURAKLATMA KILITLENIP NO-OP KALIYORDU** — `_room` connect'ten ONCE
  atanir ama livekit `localParticipant`i ancak `RoomConnectedEvent` ile yaratir.
  O pencerede `medyaBeklet` TAMAMEN no-op, `_duraklatildi = true` ise KILITLENIYOR;
  ardindan connect `setMicrophoneEnabled(true)` cagiriyordu. Sonuc KALICI: ekran
  "Bekliyor", oda SENI DUYUYOR. FIX: connect'te `&& !_duraklatildi` + connect sonunda
  `if (_duraklatildi) await medyaBeklet(room, true);`.
  ⚠️ **GENEL DERS: bir bayragi await'ten ONCE yazip is'i await'ten SONRA yapan her
  yerde, o penceredeki BASKA yazicilari da say.** (turu 68'in "kuyruga sararken hangi
  alanlar ne zaman okunuyor" dersinin kardesi.)
  **(E) `_konukOl()` / ROL TERFISI / HOST SUSTURMASI / `restartTrack()` KAPISIZDI** —
  dordu de duraklatmada medyayi YAYINA sokuyor ya da tercihi bozuyordu. Ozellikle
  livekit `restartTrack()` **`muted` bayragina HIC BAKMAZ**: stop -> createStream
  (KAMERAYI FIZIKSEL ACAR) -> replaceTrack -> start.
  ⚠️ YAPMA: `_videoSagligiKur` timer'indan `_duraklatildi` kapisini cikarma.
  **(F) ARKA PLAN KAMERA DEFTERI UZLASTIRILMIYORDU** — telefon CALARKEN uygulama
  >=900ms arka planda kalirsa oto-mute `_kameraAcik=false` yazar; duraklatma onu
  KULLANICI TERCIHI sanip `_kamHedef=false` yakaliyordu -> "devam" sonrasi kamera
  **BIR DAHA ACILMIYORDU** (yayincida kamera ac/kapa dugmesi YOK = kurtarma yolu yok).
  FIX: `yayiniDuraklat` basinda `_pipKameraGecikme?.cancel()` + `_kameraOtoKapandi`
  uzlastirmasi. ⚠️ **DERS: ayni alanin IKI SAHIBI varsa yeni sahip, eskisinin
  defterini OKUMADAN tercih yakalayamaz.**
  **(G) MESGULLUK MUAFIYETI FAIL-OPEN'DI:** `live_start_screen`in muhafizi
  **`yayin-onizleme`** ve iki kapi da `startsWith('yayin')` kullaniyordu ->
  DURAKLATILAMAYAN, ustelik FIZIKSEL KAMERAYI TUTAN o ekran muafiyete giriyordu
  (arama kabul edilince IKI capture oturumu cakisir).
  ⚠️ **MUAFIYET ONEKI ALT CIZGILI OLMAK ZORUNDA** (`oda_` / `yayin_`) + `every`
  (FAIL-CLOSED). ⚠️ YAPMA: `startsWith('yayin')`e genisletme. ⚠️ YENI duraklatilabilir
  ekran eklersen muhafiz onekini `oda_`/`yayin_` yap; duraklatilamayanlara BASKA onek ver.
  **(H) AYNI KURALIN IKI KOPYASI DRIFT ETMISTI:** `_onEvent` `every`, `mesgulMu` `any`
  kullaniyordu -> kumede bayat bir arama id'si varken **ON PLANDA telefon CALMIYOR ama
  ayni arama KILIT EKRANINDAN (CallKit -> answer -> mesgulMu) KABUL EDILIYORDU.**
  Karar `mesgulMu`ya DEVREDILDI. ⚠️ YAPMA: bu kurali tekrar `_onEvent`e kopyalama.
  **(I) BAYAT MUHAFIZ SELF-HEAL'I ULASILAMAZDI:** eski kodda `if (gercekArama ||
  odaVeyaYayin) return true;` satirinin ALTINDAYDI; kumede bir `oda_` kaydi varsa bayat
  arama id'sine HIC ULASILMIYOR ve muhafiz **KALICI** asili kaliyordu. Artik gercek
  arama yoksa arama id'li her kayit tanim geregi bayattir ve temizlenir.
- ⚠️⚠️ **TURU 70b — "%20 UZAT" ARITMETIGI YANLIS UYGULANMISTI (kullaniciya gorunen).**
  PiP kose kutusu **%20 degil %42** uzamisti. Sebep: sayilar ARAMA EKRANI kutusundan
  kopyalandi ama **IKI YUZEYIN TABANI FARKLIYDI** — arama ekrani 140x200 (en-boy
  **1.4286**), PiP kutusu 0.34W / 6:5 (en-boy **1.2**). 5:6 pencerede karsi tarafin
  videosunun ~yarisini yiyordu.
  **DOGRUSU — HER YUZEY KENDI TABANINDAN:**
  · PiP kutusu: `0.3740` genislik / `1.3091` en-boy  (= 0.34*1.10 ve (0.34*1.2*1.20)/0.3740)
    -> `mini_izgara.dart` **VE** `AppDelegate.swift yerelAyarla` BIREBIR AYNI.
  · Arama ekrani self-view: `_selfOran = 0.3720` / `_selfEnBoy = 1.5584` (140*1.10=154,
    200*1.20=240) — AYRI YUZEY, esitleme.
  ⚠️ **DERS: "ucu birden ayni sayi olmali" kurali burada HIC GECERLI DEGILDI; kural
  VARSAYILARAK kopyalandi. Bir sabiti baska yuzeye tasirken once TABANLAR AYNI MI diye sor.**
  ⚠️ `tavan` `0.55*H` — 5:6 pencerede kh=0.4896W, tavan=0.66W (pay %26). YAPMA: 0.405'e dondurme.
- ⚠️⚠️ **TURU 70b — KONUM PUANDA, BOYUT ORANLI.** Self-view'in KONUM ofsetleri de orana
  cevrilmisti (0.15625 / 0.14509, 414x896'dan). Ama **KACINILACAK OGELER SABIT PUANDA
  CAPALI**: ust bilgi blogu `Positioned(top: 48)`, alt kontroller `bottom: 48`.
  375x667'de (SE) kutu **BASLIK + UYARI SERIDININ USTUNE BINIYOR**, alt sinirda
  kontrollere 140 yerine 104pt kaliyordu. **TEST CIHAZI 414x896 OLDUGU ICIN REGRESYON
  ORADA GORUNMEZDI.** ⚠️ YAPMA: bu ofsetleri tekrar orana cevirme.
- ⚠️ **TURU 70 — PiP'TEN BUYUTURKEN SIYAH KAPAK:** `restoreUserInterfaceForPictureInPictureStop`
  -> `kapakGoster()` **FLUTTER KOK VIEW'INA** (`flutterKok`, weak) siyah katman koyar;
  Dart ilk kareyi cizince (`iosPipGeriYukleniyor` -> post-frame -> `iosGeriYuklemeTamam`)
  kalkar, 700ms emniyet timer'i var.
  ⚠️ **YAPMA: kapagi `callVC?.view.window`a koyma** (AVKit'in PiP penceresidir, non-nil
  oldugu icin keyWindow yedegi HIC kosmaz ve kapak HICBIR ISE YARAMAZ — ilk denemede oldu).
  ⚠️ Route gecisinde siyah **PUSH'ta opak, POP'ta ALFA ANIMASYONLU** (turu 59'un
  "POP yonunu opaklastirma" kurali). YAPMA: pop'u opak yapma.
- ⚠️⚠️ **TURU 71/72b — `gsmDinle` SAHIPLIK SAYACI (`_gsmSahipleri`).** Arama + oda +
  yayin AYNI native gozcuyu paylasir; **SON sahip** birakmadan dinleyici kapanmaz.
  ⚠️ Sahip adlari **ORNEGE BAGLI** olmali (`oda_<id>` / `yayin_<id>`) — sabit ad
  kullanirsan ayni isimli iki ekran bir an ust uste yasadiginda (Flutter'da yeni
  route'un `initState`i eskinin `dispose`indan ONCE kosar) gozcu ERKEN kapanir ve
  gizlilik kapilari SESSIZCE oler.
  ⚠️ `gsmAramada.value = false` temizligi **`try`IN USTUNDE** — icindeyken
  `invokeMethod` firlatirsa bayrak SUREC BOYUNCA true takili kalir ve dort ekran
  mikrofonu bir daha ACMAZ, hicbir olcum dusmeden.
- **ONCEKI (5 Agu 18:06):** TEST TURU 69 YAYINLANDI — android 31017049686 +
  ios 31017055749 (522f908), R2 apk=108238365 (md5 da3eb963) ipa=22353814 (md5 b2a11ea7),
  purge OK, **CDN birebir**, indir sayfasi 18:06, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 69 — "GSM'DE BITIR DEDIM, KARSI TARAF KAPANDI AMA BENDE EKRAN ARKADA
  DURUYOR; GSM'i kapatinca ekran ANLIK gorunup gidiyor."**
  **YAPILAN:** `AppDelegate.onEnd` ve `onDecline` artik `GebzemGsmGozcu
  .callkitBittiBildir(call.data.uuid)` ile MEVCUT `gebzem/pip` kanalindan Dart'a
  `callkitBitti` gonderiyor; `PipService.callkitBittiCb` -> controller kimlik kapisiyla
  dogrulayip TEK KAPIDAN `leave(notifyServer: true)` cagiriyor.
  ⚠️ `notifyServer: TRUE` BILEREK — `/end` genelde zaten gitmis olur ama iki yol da
  kacirirsa arama sunucuda 'active' ASILI kalir; `/end` IDEMPOTENT (turu 59).
  ⚠️ YAPMA: `action.fulfill()`i geciktirme; `onEnd` icinde agir is yapma.
  ⚠️ `call.data.uuid` DOGRU alan (plugin `Data.init(id:)` -> `self.uuid = id`).
  🔴 **KOK NEDEN HALA KANITLANMADI (durustluk):** ilk aciklamam ("olay arka plan
  isolate'ine dusuyor") **iOS ICIN YANLISTI** — bkz. asagidaki teshis duzeltmesi.
  Bu kanca semptomu KESIN kapatir ama NEDEN gec kapandigini olcum gosterecek.
- ⚠️⚠️ **TESHIS DUZELTMESI — `onBackgroundMessage` YALNIZ ANDROID'DE VAR.**
  `FlutterCallkitIncoming.onBackgroundMessage` eklentinin iOS tarafinda UYGULANMAMIS;
  `MissingPluginException` firlatiyor ve `catch (_)` YUTUYOR -> **`_callkitArkaPlan`
  iPHONE'DA HIC CALISMIYOR.** Eski yorum ("iOS DAHIL ... iOS reddi de arka plandan
  sunucuya ulasabilir") YANLISTI. Kayit artik `if (Platform.isAndroid)` kapisinda.
  ⚠️ YAPMA: Android'de kaldirma (terminated Android'de CallKit reddi/bitisi YALNIZ
  bu yoldan sunucuya ulasir). ⚠️ Bunu bir daha "iOS'ta da calisiyor" diye varsayma.
- ⚠️⚠️ **TURU 69b — DENETIM KENDI KANCAMDA 2 SEVK ENGELI BULDU:**
  **(E1) KENDI `bitir()` CAGRIMIZ KANCAYI TETIKLIYORDU:** `CallKitService.bitir()` ->
  `endCall` -> plugin `CXEndCallAction` -> `AppDelegate.onEnd` -> callback -> `leave()`.
  Yani `_cevapsizGoster`/`geriAra` yollarinda **"Cevap yok — Geri Ara" ekrani ~50-150ms
  sonra KENDILIGINDEN kapaniyor**, kullanici "Geri ara"ya BASAMIYORDU.
  ⚠️⚠️ **`_bizBitirdik` BU IS ICIN KULLANILAMAZ:** (a) yalniz Dart olay yolunu korur,
  (b) okurken TUKETIR (`remove`), (c) plugin Dart olayini native `onEnd`TEN ONCE
  gonderir -> kume native kanca gelmeden BOSALMIS olur.
  FIX: AYRI + ZAMAN PENCERELI defter `_programatikBitirilen` (10sn) + `bizMiBitirdik()`;
  callback'in **ILK** kapisi bu, ayrica `_cevapsiz` kapisi.
  ⚠️ YAPMA: iki defteri birlestirme; okurken silme; kapiyi kimlik kapilarinin altina koyma.
  **(E2) BAYAT `leave` YENI ARAMAYI OLDURUYORDU (eski gizli hata, kanca gorunur yapti):**
  `leave()` icinde SENKRON olan tek sey `_ayrildi = true`; asil yikim
  `await CallSounds.durdur(...).timeout(250ms)` SONRASI. O pencerede "Bitir ve Kabul"
  ikinci aramayi baslatirsa (`main.dart`teki `await ctrlOn.leave()` `_ayrildi` yuzunden
  ANINDA doner) asili eski `leave` YENI aramanin aboneliklerini oldurur, ekranini pop
  eder, ESKI id ile `ekranKapandi` cagirdigi icin mesgul muhafizini ASILI birakir.
  FIX: await'ten hemen sonra **`if (arama?.callId != id) return;`** (tek satir).
  ⚠️ YAPMA: bu kapiyi kaldirma; `_kapatOdayiKuyrugaKoy()`u await'in ALTINA tasima.
- 📌 **TURU 69 OLCUMU — TEST SONRASI BAK:** iki kapatma yolu damgalandi:
  `callkit bitir: kaynak=native yasam=..` ve `callkit bitir: kaynak=eklenti`.
  Ikisinin ZAMAN FARKI, ekranin neden gec kapandigini KESIN gosterecek
  (native once gelirse kanca kurtardi; eklenti hic gelmiyorsa asil delik orada).
- **ONCEKI (5 Agu 00:59):** TEST TURU 68 YAYINLANDI — android 30953817519 +
  ios 30953819602 (e8215da), R2 apk=108238369 (md5 0925d92d) ipa=22353332 (md5 06475a23),
  purge OK, **CDN birebir**, indir sayfasi 00:59, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 68 — "ARKADA ACIK KALIYOR"UN IKI SEBEBI DE TURU 67'DE BENIM EKLEDIGIM
  KODDU.** Kanit: sunucu TEMIZ (son 12 arama satirinin hepsi ended/missed/rejected,
  asili `active` YOK) -> acik kalan sey CIHAZDA.
  **(1) KILIT SIRASI TERSINE DONMUS (ASIL SEBEP):** turu 67'de kapanis animasyonu icin
  `CallRoomLock.calistir(_odaTemizle)` cagrisini `Future.delayed(260ms)` closure'inin
  **ICINE** koymustum. O kilit GLOBAL ve SERIDIR; TEK varolus sebebi *"yeni oda
  BAGLANMADAN once eskisinin kapanisi TAMAMEN bitmis olsun"*. Kuyruga **GIRIS** gecikince
  sira TERSINE donebiliyor: "Bitir ve kabul et"te `leave -> /end -> /answer -> yeni
  _odayaBaglan` tipik **120-200ms**; 260ms'in ALTINA dusunce YENI baglanti kilidi ONCE
  aliyor ve **ESKI ODA LiveKit'e BAGLI + MIKROFONU YAYINDA** kaliyordu.
  ("bazen" = wifi HIZLI -> olur; hucresel YAVAS -> olmaz.)
  **FIX:** kuyruga GIRIS senkron (`leave` govdesinde), **260ms BEKLEME closure'in ICINDE**.
  Animasyon fix'i AYNEN korunur.
  ⚠️ **YAPMA: `CallRoomLock.calistir`i BIR GECIKMENIN ARKASINA koyma** — kuyruga giris
  ANI sirayi belirler, closure'in ICI degil. ⚠️ YAPMA: 260ms'i tamamen kaldirma.
  **(2) `_onizlemeBirak` NO-OP OLMUS (kamera arkada ACIK = iPhone'da YESIL NOKTA):**
  turu 67'de govdeyi `_kameraKuyruguna` ile sarmistim. Ama `baslat()` icinde
  `unawaited(_onizlemeBirak()); _onizlemeTrack = null;` ARASINDA **await YOK** (turu 32'nin
  "once SAL sonra sifirla" deseni). Kuyruk mikrotask sonrasi kostugunda `_onizlemeTrack`
  ARTIK NULL okunuyor, metot `if (t == null) return;` ile cikiyor -> `t.stop()`/`t.dispose()`
  **HIC CAGRILMIYOR** -> yayinlanmamis track + NATIVE capture oturumu ACIK kaliyor,
  sonraki aramada kamera MESGUL.
  **FIX:** track VE `_onizlemeYayinda` **kuyruga GIRMEDEN SENKRON** yakalanir.
  ⚠️ **DERS: bir govdeyi kuyruga/gecikmeye sararken, o govdenin okudugu ALANLAR cagri
  aninda mi yoksa calisma aninda mi gecerli — MUTLAKA sor.** Ayni hatanin iki turemesi
  (kilit girisi + alan okuma) ayni turda olustu.
  **(3) EK EMNIYET:** `_odaTemizle` icinde `disconnect()` ONCESI `setMicrophoneEnabled(false)`
  (300ms timeout) — `disconnect().timeout(1200ms)` ALTTAKI ISI IPTAL ETMEZ (turu 50).
  ⚠️ YAPMA: buraya `setCameraEnabled(false)` ekleme (paylasilan `videoCapturer` + gelen
  arama kamera DEVRI -> yeni aramanin videosu olur).
- ⚠️⚠️ **TURU 68 — "TUT VE KABUL ET"IN KAYNAGI: `setCallConnected`.**
  Bizim kodda UC yerde `supportsHolding: false` DOGRUYDU; deger CallKit'e ULASMIYORDU.
  `CallKitService.baglandi()` (`setCallConnected`) TURU 56'DA **TAM DA BEKLETMEYI ACMAK
  ICIN** eklenmisti ("iOS bagli olmayan aramayi HOLD EDILEBILIR saymaz"). Bekletme turu
  66'da kapatilinca satir GERIDE KALDI. Ustelik plugin `setCallConnected`e yalniz
  `{'id':...}` gonderiyor; harita **"ios" alani ICERMEDIGI** icin plugin `data`yi
  **VARSAYILANLARLA** yeniden kuruyor -> `supportsHolding = true`. Yani yazdigimiz `false`
  TAM BURADA EZILIYORDU. **FIX:** `if (bekletmeAcik && b.outgoing)`.
  ⚠️ YAPMA: `gidenArama` CallKit kaydini kaldirma (ikinci arama arayuzu + turu 57
  `gidenler` kapisi ona bagli).
  **IKINCI SIZINTI:** AppDelegate **IPTAL dali** `Data(...)` uretip `supportsHolding`
  YAZMIYORDU -> plugin varsayilani TRUE (`Call.swift:194`). FIX: `false` + `supportsGrouping=false`.
  ⚠️ **PLUGIN VARSAYILANI TRUE — yeni bir `Data(...)` uretilen HER yerde ACIKCA yaz.**
- ✅ **TURU 68 OLCUMU:** `CallKitService.holdDurumunuOlc()` — `activeCalls()` yanitindaki
  `supportsHolding`/`maximumCallGroups` Sentry'e yazilir (arama basina TEK).
  **TEST SONRASI BAK:** `callkit aktif arama (giden|gelen): adet=.. hold=.. grup=..`
  -> `hold=false` cikarsa deger CallKit'e ULASMIS demektir.
  ⚠️ **ERTELENDI (SON CARE, once olcume bak):** `maximumCallGroups 2 -> 1`.
  `maximumCallsPerCallGroup:1` ile birlikte toplam kapasite 1 olur ve ikinci
  `reportNewIncomingCall` **HATA donebilir** -> telefon CALMAZ + iOS 13 kurali ihlali
  (turu 33/67 "arama karsilanmiyor" semptomu geri gelir). OLCMEDEN UYGULAMA.
- ✅ **TURU 67 FIX'I TUTTU (kanit):** `Bad state: Cannot use "ref" after the widget was
  disposed.` hatasi Sentry'den **TAMAMEN KAYBOLDU** — "bitir sonrasi aramayi HIC
  karsilamama" kok nedeni cozuldu.
- **ONCEKI (4 Agu 23:55):** TEST TURU 67 YAYINLANDI — android 30949200253 +
  ios 30949203156 (e24e7d1), R2 apk=108238369 (md5 1cdad676) ipa=22352640 (md5 da21c05c),
  purge OK, **CDN birebir**, indir sayfasi 23:55, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 67 — "BITIR DEDIKTEN SONRA GELEN ARAMAYI BAZEN KARSILAMIYOR" KOK NEDENI**
  (Sentry kaniti: `Bad state: Cannot use "ref" after the widget was disposed.`):
  ZINCIR: "Bitir ve kabul et" -> `leave()` -> `_svc.end()` -> `call_provider` `state=null`
  -> gelen-arama katmanini cizen kosul FALSE -> **WIDGET DISPOSE** -> hemen ardindan
  `_accept()` icindeki `ref.read(...)` PATLAR. O cagri **try blogunun DISINDA** oldugu icin
  **`answer` REST'i HIC GITMEZ**. "Bazen" = dispose ile `_accept` arasindaki YARIS.
  **FIX:** `_notifier` + `_ctrl` `initState`te BIR KEZ yakalanir (tum `ref.read`lar cevrildi).
  ⚠️ YAPMA: bu alanlari tekrar gec `ref.read`e cevirme; provider'lari `autoDispose` yapma;
  `call_provider`daki `state = null` yan etkisini kosullu yapma (turu 27-31 regresyonu).
  **IKINCI KAPI:** 3sn'lik durum yoklamasi `s != 'ringing'` gorunce ekrani kapatiyordu —
  kabul akisinda arama ZATEN 'active' oluyor. FIX: `if (_busy) return;` + answer basarili
  olunca yoklama IPTAL. **UCUNCU KAPI:** `catch` KOSULSUZ `end()` cagiriyordu -> `answer`
  OK'ten SONRAKI bir hata YENI KABUL EDILEN aramayi olduruyordu. FIX: `_cevaplandi` bayragi.
- ⚠️⚠️ **TURU 67 — "DONMA"NIN KOK NEDENI: KAPANIS ANIMASYONU BOS EKRANDA OYNUYORDU.**
  `_kapatOdayiKuyrugaKoy` `_room = null`i SENKRON yapiyordu; `notifyListeners()` cok sonra.
  220ms'lik solmanin ILK KARESINDE `c.room` null -> `_remoteVideo`/`_localVideo` null ->
  renderer'lar agactan SILINIYOR -> canli goruntu ANINDA kayboluyordu.
  **FIX:** mandal + timer iptalleri + yakalama SENKRON kalir; yalniz alan null'lama ve oda
  temizligi **260ms GECIKIR**. ⚠️ `identical(_room, room)` kapilari ZORUNLU (seri aramada
  YENI aramanin Room'unu null'lamasin — turu 54/59 sinifi). ⚠️ YAPMA: gecikmeyi
  `call_screen` dispose/pop tarafina tasima ("leave TEK KAPI" hukmu).
  **IKINCI SEBEP:** `await CallSounds.durdur(...)` ZAMAN ASIMSIZDI (`Vibration.cancel` +
  `player.stop`); takilirsa `arama=null` + `notifyListeners()` HIC calismaz, ekran son
  karede ASILI kalir -> 250ms timeout. ⚠️ YAPMA: `unawaited`a cevirme (yeni aramanin
  zilini keser — nesil jetonu).
- ⚠️⚠️ **TURU 67 — "GORUNTU GEC GIDIYOR": KAMERA TEARDOWN YARISI.** `_onizlemeAc()` hicbir
  kilit arkasinda DEGILDI; onceki aramanin `leave()` yolundaki `_onizlemeBirak()`
  (unawaited) HALA kosarken yeni onizleme kamerayi aciyordu. iOS'ta flutter_webrtc
  **TEK PAYLASILAN `videoCapturer`** tutar (turu 50 kok nedeni) -> iki capture birbirinin
  oturumunu CALAR. **FIX:** `_kameraKuyruguna` — acma/birakma TEK SLOTLUK zincire dizildi.
  ⚠️ YAPMA: bunu `CallRoomLock` ile yapma (GLOBAL kilit; `_onizlemeAc` icinde izin
  DIYALOGU var -> oda/yayin girisi kilitlenir). ⚠️ YAPMA: zinciri `await` edip `baslat()`i
  bloklama. `_onizlemeBirak` hatasi artik arama basina TEK Sentry olcumu.
- ⚠️⚠️ **OLCUM TUZAGI — `izin:NNNN` IZIN SURESI DEGILDIR (kendi teshisimi curuttum).**
  `_kurulumSaat` YALNIZ `baslat()`ta kuruluyor; GIDEN aramada `_connect()` ancak
  `call.answered` gelince kosar -> `izin` degeri **ZIL SURESINI de icerir**. Sahada
  gorulen `izin:3992` "izin 4 saniye surdu" ANLAMINA GELMEZ.
  ⚠️ YAPMA: `_kurulumSaat`i `_connect()` icinde yeniden baslatma (zil suresi bilgisi
  kaybolur, eski turlarla kiyas biter). Ayrim icin `giden` alani eklendi.
- ✅ **TURU 67 — BEKLETMENIN GORUNEN TUM KALINTILARI SILINDI:** main.dart `_heldSub`
  (WS `call.held` ALMA — karsi taraf ESKI surumdeyse turuncu serit YAPISIYORDU) ·
  controller `peer_held` uzlastirmasi · bant bekletme metinleri + "Devam et" dugmesi +
  park seridi + `_bandanDevamEt` + `_gsmUyarisiGoster`.
  ⚠️ `_holdSub` KALDI — kendi cihazimizdaki KACAK CallKit hold olayina karsi tek emniyet
  (artik aramayi BITIRIYOR). ⚠️ Backend `held_by`/`peer_held` + migration 013'e DOKUNULMADI
  (additive, turu 61).
- ⏳ **TURU 67 — YAPILMADI (durust not):** `call_screen.dart` bekletme paneli/rozeti ve
  controller'daki ~500 satirlik olu park zinciri (`ParkEdilenArama`/`parkEt`/`devamEt`/
  `beklemeyeAl`/`_medyaBeklet`/`_iosSesOturumuGarantile`/`GebzemSesKurtar`) HALA DURUYOR.
  Hepsi `bekletmeAcik=false` arkasinda **ULASILAMAZ** = kullaniciya GORUNMEZ.
  Toplu silme denendi, satir sinirlari yanlis hesaplandi, dosya bozuldu, `git checkout`
  ile geri alindi. ⚠️ **DERS: coklu-blok silmeyi script'le yapma — Edit ile TEK TEK ve
  her adimda `flutter analyze`.** Ayri turda yapilacak.
- **ONCEKI (4 Agu 22:48):** TEST TURU 66 YAYINLANDI — android 30943942830 +
  ios 30943945392 (c8a6c9d), R2 apk=**108238477** (md5 579cd292, KUCULDU = bekletme
  arayuzu gitti) ipa=22349753 (md5 49cd6b0e), purge OK, **CDN birebir**, indir sayfasi
  22:48, debug imza YOK, **backend DEGISMEDI** (19d0a96) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 66 — ARAMA BEKLETME KALDIRILDI (KULLANICI EMRI 4 Agu).**
  Kullanici: *"beklemeyi yapmayalim, arama geldiginde KABUL ET ve BITIR olsun."*
  **GEREKCE (uc turluk OLCULMUS kanit):** bekletmeden CIKIS iOS'ta BIZIM
  KONTROLUMUZDE DEGIL — turu 65 kaniti: CallKit unhold ediyor ama `didActivate`i HIC
  cagirmiyor; bizim aktive denememiz `!pri` (InsufficientPriority) ile REDDEDILIYOR.
  **TEK BAYRAK: `ActiveCallController.bekletmeAcik = false`** (kod SILINMEDI —
  CLAUDE.md "bayrakla kapat" kurali). Geri istenirse: bayrak + `supportsHolding`
  (Dart gelen+giden) + Swift `data.supportsHolding` UCU BIRLIKTE true.
  · CallKit `supportsHolding=false` + `maximumCallsPerCallGroup=1` -> iOS "Beklet ve
    Kabul" YERINE **"Bitir ve Kabul"** cizer (Gebzem VE hucresel aramalar icin).
  · GSM olayi -> `leave(notifyServer:true)`; `parkEt`/`beklemeyeAl` son savunma kapilari.
  ✅ **VoIP PUSH RISKI ELENDI (denetim, plugin kaynagi okundu):**
    `maximumCallsPerCallGroup=1` `reportNewIncomingCall`i ETKILEMEZ — plugin 3.1.3
    `Call.swift:191-194` VoIP push yolunda ZATEN 1 kullaniyordu; Dart'i 2->1 cekmek
    push yolunu DEGISTIRMEDI, HIZALADI. `supportsHolding` yalnizca CXCallUpdate susu.
    ⚠️ Bunu bir daha arastirma.
- ⚠️⚠️ **TURU 66b — DENETIM 3 SEVK ENGELI BULDU (biri HER aramayi olduruyordu):**
  · **EN AGIR:** `_connect` sonundaki SEVIYE kontrolu (turu 56 emniyet agi)
    `beklemeyeAl(id,true)` cagiriyordu; bekletme kapaliyken bu `leave()` demek ->
    **hucresel gorusme SURERKEN kurulan HER Gebzem aramasi KENDINI OLDURUYORDU**
    (yaris DEGIL, deterministik: `gsmDinle` oda baglantisindan once kosuyor).
    Ustelik OLEN, kullanicinin YENI KABUL ETTIGI aramaydi — emrin TERSI.
    FIX: `if (bekletmeAcik && PipService.gsmAramada.value && !beklemede)`.
    ⚠️ YAPMA: `bekletmeAcik` sartini kaldirma.
  · **YESIL "Beklet ve kabul et" DUGMESI EKRANDA KALMISTI** (yalniz govde
    degistirilmisti) -> basan kullanici "bekletiyorum" sanarken gorusme BITIYORDU.
    Bu Android'in BIRINCIL ikinci-arama arayuzu. FIX: dugme `bekletmeAcik` ile sarildi
    + "Önceki arama sonlandırıldı" bildirimi (rootMessengerKey — widget Navigator DISINDA).
    ⚠️ **DERS: bir ozelligi bayrakla kapatirken GOVDEYI degistirmek YETMEZ — o ozelligi
    CAGIRAN ARAYUZ de gizlenmeli, yoksa dugme SESSIZCE BASKA IS YAPAR.**
  · **CEVAPLANMAMIS GIDEN HUCRESEL CAGRI ARAMAYI OLDURUYORDU:** iOS kapisi
    `!c.isOutgoing && !c.hasConnected` idi (turu 64'te GERI DONULEBILIR bir eylem icin
    yazilmisti; artik geri donusu YOK). FIX iOS: `if !c.hasConnected { continue }`.
    FIX Android (native "baglandi" sinyali YOK): Dart'ta **2sn TEYIT** — kimlik SENKRON
    yakalanir, 2sn sonra hucresel HALA suruyorsa ve AYNI arama devam ediyorsa bitirilir.
    ⚠️ YAPMA: bu teyidi kaldirma; `isOutgoing` dalini geri ekleme.
- ⚠️⚠️ **YANILTICI SERH DUZELTILDI (gelecek denetimler icin):** "bekletme yokken turu 56
  GSM gizlilik acigi YAPISAL OLARAK IMKANSIZ" iddiasi **YALNIZ 1:1 ARAMA** icin dogru.
  `gsmDinle` YALNIZ arama akisinda (`_connect`) aciliyor; `features/rooms` ve
  `features/live` altinda `gsmAramada` **HIC OKUNMUYOR** ve `room_screen` `resumed`da
  mikrofonu KOSULSUZ geri aciyor. Bu acik turu 66'nin getirdigi DEGIL (turu 56'dan beri
  var). ⏳ **AYRI IS: oda/yayin icin GSM kapisi.**
- 📌 **ODA/YAYIN SIRASINDA GELEN ARAMA — MEVCUT DAVRANIS (koddan dogrulandi, kullanici sordu):**
  · Android + uygulama ON PLANDA: `call_provider.dart:173` `aramadaMi` true (`oda_`/`yayin`
    muhafizi) -> overlay HIC acilmaz, telefon CALMAZ.
  · iOS her zaman + Android arka plan: VoIP/FCM push gelir, CallKit **CALAR** (iOS 13
    kurali geregi raporlamak ZORUNLU; `callkit_service.goster`da mesguliyet kapisi YOK).
  · KABUL EDILIRSE: `mesgulMu(haric:)` `oda_`/`yayin` kaydini gorur -> `answer()` **null**
    -> `main.dart` `baskaIsleMesgul` -> `CallKitService.bitir` + `end` -> CallKit ekrani
    kapanir, **arayan "reddedildi" gorur**, oda/yayin sesi BOZULMAZ.
  · Turu 66 bu akisin HICBIRINI degistirmedi (oda/yayinin CallKit kaydi yok).
  ⏳ **ONERI (kullaniciya sunuldu, KARAR BEKLIYOR):** mikrofonu KAPALI olanda telefon
    CALSIN (oda dinleyicisi + yayin izleyicisi), konusmaci uyariyla, YAYINCI'da CALMASIN.
- **ONCEKI (4 Agu 21:51):** TEST TURU 65 YAYINLANDI — android 30939684916 +
  ios 30939688331 (7109a2c), R2 apk=108254861 (md5 **d7b16b8c**) ipa=22361701
  (md5 e266567b), purge OK, **CDN'den indirilen apk+ipa yerelle MD5 BIREBIR**,
  indir sayfasi saati 21:51, debug imza YOK, **BACKEND DEGISMEDI** (19d0a96'da kaldi)
  + health ok, DB temiz (0/0/0/0). **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 65 — "!pri" KANITI: ASIL KOK NEDEN ARTIK OLCULDU (tahmin DEGIL).**
  Turu 64'te ekledigim olcum sahada su olayi yazdi (4 Agu 18:02, arama d31f6fc5):
  `ses oturumu ACILAMADI (unhold): configOk=false hata=NSOSStatusErrorDomain#561017449`
  **561017449 = 0x21707269 = "!pri" = AVAudioSessionErrorCodeInsufficientPriority.**
  iOS diyor ki: *"ses oturumunu SEN aktive edemezsin, oncelik sende degil."*
  ⚠️⚠️ **BU BIR ZAMANLAMA SORUNU DEGIL, YETKI SORUNU** — tekrar denemek TEK BASINA
  COZMEZ. (Turu 64'un 3 basamakli merdiveni bu yuzden yetmedi.)
  **PLUGIN KAYNAGI OKUNDU** (flutter_callkit_incoming 3.1.3):
  · `provider(_:didActivate:)` (satir 775-779) AppDelegate'e **KOSULSUZ** iletiyor
    -> `aktif=false` olmasi "iletilmedi" degil, **"CallKit didActivate'i HIC CAGIRMADI"**.
  · `CXSetHeldCallAction` (719-732) ses oturumuna **DOKUNMUYOR**, yalnizca sahte bir
    "interruption ended" bildirimi atiyor.
  **YANI: hucresel arama bitince CallKit aramayi unhold ediyor ama SESI GERI VERMIYOR.**
  **FIX (kademeli):** (1) merdiven 3 -> 6 basamak (~11sn), (2) tukenirse SON CARE
  `GebzemSesKurtar`: `CXCallController` ile arama BEKLET + 400ms + DEVAM -> aktivasyonu
  Apple'in izin verdigi TEK sahip (CXProvider) yapar, `didActivate` zinciri BASTAN calisir.
  ⚠️ `CXCallController` STATIK olmali (asenkron istek boyunca yasamali).
  ⚠️ Iki istek arasi gecikme SART (CallKit birlestirip NO-OP yapabilir).
  ⚠️ YAPMA: kurtarmayi merdivenden ONCE calistirma; arama basina 1'den fazla denetme.
- ✅ **TURU 65 — "SES AVIZEDEN GELIYOR" (kullanici):** sunucu logunda SESLI aramada
  `rota=Speaker`. KOK: bekletmeden sonra iOS rotayi KENDI seciyor; Android'de
  `_androidSesTazele` geri uyguluyordu ama o metot **iOS'ta ERKEN DONER** — iOS'ta
  rotayi geri uygulayan **HICBIR SEY YOKTU** (bayrak/donanim celiskisi: hoparlor
  dugmesi "kapali" gorunurken donanim ACIK). FIX: `_sesYolunuGeriUygula()`
  (mic -> hoparlor sirasi). ⚠️ **SAGLIKLI DALDA DA CAGRILIR** — bekletmelerin COGU
  ilk denemede acilan daldan gecer; orada ciplak `return` vardi ve fix HIC devreye
  girmiyordu (denetimde yakalandi).
- ⚠️⚠️ **TURU 65b — DENETIM TURUN ASIL FIX'INI OLU KOD OLARAK YAKALADI (6 sevk engeli).**
  🔴 **KANAL UYUSMAZLIGI:** native `case "callkitSesKurtar"` **`gebzem/pip`** handler'ina
  yazilmisti, Dart ise `_audioCh` (**`gebzem/audio`**) uzerinden cagiriyordu ->
  `MissingPluginException` -> `catch (_)` yutuyor -> **kurtarma blogu HIC calismiyordu.**
  FIX: `PipService.callkitSesKurtar()` (mevcut `gsmDinle`/`gebzemAramaKaydet` deseni).
  ⚠️ **DERS: yeni bir native `case` eklerken HANGI KANALA yazdigini Dart cagirisiyla
  KARSILASTIR** — iki kanal var (`gebzem/audio` ve `gebzem/pip`) ve uyusmazlik
  derleme zamani YAKALANMAZ (`invokeMethod` string'i kontrol edilmez).
  · **KOR PENCERE:** bastirma penceresi cagridan ONCE ve KOSULSUZ aciliyordu; cagri
    her zaman basarisiz oldugu icin HER aramada 4sn kor pencere olusacakti.
    FIX: pencere yalniz istek BASARILI ise acilir, `finally` ile kapanir, callId'ye bagli.
  · **PARK SIRASI:** bastirma kapisi park dalinin USTUNDEYDI -> park edilmis aramaya
    gelen "devam" olayini yutup parki SONSUZA KADAR sikistirabilirdi (turu 54).
    FIX: park dali EN USTE.
  · **PARK KAPISI YOK:** `parkEt()` `arama`yi temizlemez/`beklemede` yazmaz, yalniz
    `_room`u null'lar -> kurtarma kapilari park edilmis aramada da GECIYORDU.
    FIX: `if (parkEdilen != null || _room == null) return;`.
  · **OLCUM YANLIS POZITIF:** kurtarma sonucu `getAudioState` ile olculuyordu ama o uc
    `configOk` DONDURMUYOR; merdivenin olcutu `active && configOk`. FIX: ayni yoldan
    (`_sesiAc`) yeniden olculur. (turu 60/61 olcum korlugu dersi)
- ⚠️ **TAMPON OLCUMU OLCEK HATASI:** `jitterBufferDelay` ORNEK-AGIRLIKLI; dogru bolen
  ornek SAYISI. livekit 2.5 `jitterBufferEmittedCount` acmadigi icin `sure x 48000`
  ile TAHMIN ediliyor (sahadaki `tamponMs=5510400` bu yuzdendi). ⚠️ Deger TAHMINI.
- **ONCEKI (4 Agu 20:30):** TEST TURU 64 YAYINLANDI — android 30933267247 +
  ios 30933270300 (19d0a96), R2 apk=108254861 (md5 **22aac748**) ipa=22358493
  (md5 fd7c8d44), purge OK, **CDN'den indirilen APK yerelle MD5 BIREBIR**, indir sayfasi
  saati 20:30, **BACKEND DEPLOY EDILDI** (19d0a96 + health ok + yeni `held_by` SQL'i
  canli DB'de EXPLAIN ile dogrulandi), DB temiz (0/0/0/0), debug imza YOK,
  iOS deployment target 16.0 korunuyor. **KULLANICI TEST EDECEK.**
  ⚠️ **APK BOYUTU TURU 63 ILE BIREBIR AYNI CIKTI (108254861) ama MD5 FARKLI**
  (63: `2b466ce4` -> 64: `22aac748`). "Boyut ayni = build eski" DEME kurali yine dogrulandi.
  ⚠️ IPA BUYUDU (22349602 -> 22358493) = yeni Swift (`GebzemGsmGozcu`) DERLENDI kaniti.
- ⚠️⚠️ **TURU 64 — "GSM SONRASI SES GITMIYOR" KOK NEDENI OLCUMLE KANITLANDI.**
  Kullanici (3 Agu gecesi) uc sikayet bildirdi; 25 ajanlik kok-neden + 23 ajanlik
  adversaryal denetim kosuldu. **Sunucu logu + Sentry, arama `be27eed9`:**
  · 21:11:24 iOS bekletti -> `POST /hold` 200, Android `call.held on=true` ALDI ✓
  · 21:11:37 unhold -> 200, Android `on=false` ALDI ✓
  · 21:11:38+ iOS: **`iOS[acik=true aktif=FALSE]`** · `recv delta=100` (INIS SAGLAM)
    · `sent sdelta=0` `mikE=0.0` -> **MIK-OLU-SENT0**. Sunucu `KURTARMA=sent0` denedi, olmadi.
  **Yani sinyal/sunucu/LiveKit CALISTI; bozulan tek sey iOS YEREL SES GIRISI.**
  **KOK-A:** bekletmede CallKit `didDeactivate` ile oturumu kapatir; unhold'da simetrik
  `didActivate` **GELMEYEBILIR** — `flutter_callkit_incoming`in `CXSetHeldCallAction`
  isleyicisi ses oturumuna DOKUNMAZ, yalnizca SAHTE bir "interruption ended" atar
  (plugin 3.1.3, `SwiftFlutterCallkitIncomingPlugin.swift:719-731`). Geriye kalan TEK
  aktivasyon denemesi bizim `_sesiAc(true)`imizdi ve GSM hatti kaynagi BIRAKMADAN
  kostugu icin patliyordu. `AppDelegate.swift` `setConfiguration(active:true)` hatasi
  **YALNIZ NSLog'a** yaziliyor, `result(nil)` ile Dart'a **KOSULSUZ BASARI** donuyordu.
  ⚠️ **AYNI YARISIN ANDROID KANITI:** `ses tazelendi: oncekiMod=2` (= MODE_IN_CALL) —
  biz tazelerken telefon HALA hatti tutuyordu.
  **FIX:** native artik `{configOk,hata,enabled,active}` DONDURUR; yeni
  `_iosSesOturumuGarantile` 200/600/1200ms artan araliklarla TEKRAR dener, basarinca
  mikrofonu YENIDEN uygular, olmazsa **arama basina TEK** Sentry GERCEK olayi yazar.
  ⚠️ YAPMA: hatayi tekrar yutma; `result`u `nil`e dondurme; FAZ-7'nin "zorla toggle"ini
  kaldirma (ilk arama sessizligi geri gelir); `_sesiAc`i ISTISNA FIRLATIR yapma
  (`_connect` await ediyor, catch `_svc.end` ile SAGLIKLI aramayi oldurur).
- ⚠️⚠️ **TURU 64 — iOS'TA HUCRESEL ARAMA KORLUGU (kullanici: "iPhone'da bekletme
  gorunmedi, Android'de devam et/iptal yoktu").** `gsmAramada` bayragini yazan TEK
  kaynak Android `TelefonDurumu.kt` idi; `gsmDinle` iOS'ta **kosulsuz false** donuyordu.
  CallKit yalniz **GELEN** hucresel aramada bizimkini bekletir — kullanici **KENDISI
  arama YAPINCA** hicbir olay gelmez. Turu 63'un "Devam et" GSM kapisi iPhone'da
  **OLU KODDU**. **FIX:** `GebzemGsmGozcu` (CXCallObserver, AppDelegate.swift dosya
  kapsaminda — ⚠️ pbxproj'a AYRI dosya EKLENMEDI, BOM tuzagi).
  ⚠️⚠️ **FILTRE HAYATI ONEM TASIR:** kendi CallKit aramalarimiz da bu listede gorunur;
  filtresiz birakilirsa uygulama KENDI aramasini beklemeye alir.
  · Defter `bizimAramalar`; `gsmDinle(true, callId:)` gozcu BASLAMADAN ONCE doldurur.
  · ⚠️⚠️ **iOS'TA GELEN ARAMA DART'TAN KAYDEDILEMEZ** — `CallKitService.goster`
    iOS'ta CAGRILMAZ (`call_provider.dart` IKI yerde `if (Platform.isIOS) return;`);
    gelen arama VoIP push ile **native `pushRegistry` icinde** olusur. Bu yuzden
    `aramaEkle` HER IKI `showCallkitIncoming` cagrisinin **ONUNE** konur.
    ⚠️ YAPMA: bu satirlari closure'in ICINE veya cagrinin ALTINA tasima (CXCall SENKRON olusur).
  · ⚠️ **RINGING KURALI (turu 62'nin iOS karsiligi):** `if !c.isOutgoing &&
    !c.hasConnected { continue }` — yalniz BAGLANMIS ya da GIDEN arama bekletme baslatir.
    GIZLILIK KORUNUR: suren GSM zaten `hasConnected`, ikinci cagri calarken de sayilir.
  · ⚠️ **SILME ASLA YENI YABANCI URETMEZ:** `aramaSil` icinde `degerlendir()` YOK
    (`CallKitService.bitir` silmeyi `endCall`in ONUNDE, `parkiDusur` ise AKTIF ARAMA
    SURERKEN yapiyor). Defter temizligi `callObserver`daki `hasEnded` dalinda.
  · ⚠️ Gozcu kanali **WEAK OLAMAZ** (GebzemPip ile ayni tuzak).
  · Dart'ta IKINCI suzgec: `PipService.gsmYabanciId` == kendi callId ise olay YOK SAYILIR.
    ⚠️ NOT: bu suzgec "ikinci GEBZEM aramasi" vakasini YAKALAMAZ — onu native defter kapatir.
- ⚠️⚠️ **TURU 64 GIZLILIK (turu 56/63 acigina UC YENI KAPI — denetimde yakalandi):**
  (a) `_iosSesOturumuGarantile`: kapilar `_sesiAc` await'inin ONUNDEYDI, mikrofon acilisi
  ARKASINDA -> await sirasinda GSM baslarsa mikrofon acilir ve `beklemeyeAl`
  `beklemede==aktif` kapisinda erken donecegi icin **bir daha KAPANMAZ**. Kapilar await
  SONRASI tekrar okunur, hedef DURUMDAN turetilir.
  (b) `devamEt`: `_medyaBeklet(..., false)` mikrofonu KOSULSUZ aciyordu, GSM kontrolu
  metodun SONUNDAYDI; arada `setSpeakerOn` + `_androidSesTazele` (native stop/start +
  120ms) var -> **yuzlerce ms canli sizinti**. Karar (`gsmVar`) artik MEDYADAN ONCE.
  ⚠️ YAPMA: oraya `return` koyma (turu 54 park sikismasi) — karar DEGERE donusur.
  (c) Park seridi (turuncu) `devamEt()`i **GSM KAPISIZ** cagiriyordu. Uc "devam" yolu
  (call_screen · yesil bant · park seridi) artik AYNI `_gsmUyarisiGoster()` kapisindan gecer.
  ⚠️ YAPMA: yeni bir "devam" yolu eklerken bu kapiyi unutma.
- ✅ **TURU 64 DIGER:** `devamEt` unhold sinyali medyanin ONUNE (kardes `beklemeyeAl`
  turu 60'ta duzeltilmisti, bu ATLANMISTI) + await'ler arasi kimlik kapisi ·
  `hold()` **per-callId son-karar kapisi** (3 kor tekrar hold/unhold yarisi uretiyordu) ·
  backend `held_by` artik `AND (held_by IS NULL OR held_by=$2)` ·
  `_birimYenidenKur` basina `if (_ayrildi || beklemede) return;` (GSM'de mikrofon aciyordu) ·
  **`devamEt`e `_statsBaslat()` GERI KONDU** — `parkEt` timer'i iptal ediyor, geri kuran
  YOKTU: park/devam sonrasi ses olcumu VE olu-mik OTO KURTARMASI arama boyunca OLUYDU.
  ⚠️ ERTELENDI: migration 014 + `hold_seq` (tek turda sema+deploy riski, kazanc orantisiz).
- ⚠️⚠️ **TELEMETRI DUZELTMESI — TURU 63'UN "JITTER HIPOTEZI CURUDU" HUKMU GECERSIZ.**
  `tamponDeltaMs` ham `jitterBufferDelay` farkiydi; `totalSamplesDuration`a BOLUNMEDIGI
  icin **ms DEGILDI** (ayrica `jitter` bambaska bir metriktir). Negatif degerlerin
  (`-199939200`, `gizlenenOrnek=-2128`) sebebi: olcum tabanlari arama basinda
  SIFIRLANMIYORDU. `recvDelta` de gecen sureye bolunmuyordu (arka planda Timer BOGULUR).
  FIX: `tamponMs = delta(jitterBufferDelay)/delta(totalSamplesDuration)*1000`, bolen<=0 ise
  olcum GONDERILMEZ; `recvPaketSn` gercek tik suresiyle; tabanlar `baslat()`ta sifirlanir.
  ⚠️ Ses gecikmesi konusu KAPALI DEGIL — dogru metrikle tekrar bakilacak.
- 📌 **SUREC DERSI (turu 59b'nin TEKRARI — bu adimi ASLA atlama):** kod yazilip
  `go build`+`flutter analyze` gectikten SONRA kosulan adversaryal denetim, kendi
  turu 64 kodumda **YUKSEK bir regresyon** (E1) buldu. Build ALINMADAN yakalandi.
- 📌 **TEKRARLAYAN DESEN (turu 50·56·60·63·64 — CLAUDE.md'ye kalici not):** bu hatalarin
  ORTAK koku karmasiklik degil, **YUTULAN HATA + BREADCRUMB-ONLY LOG**. Yeni bir hata
  yolu yazarken sor: "bu patlarsa TELEMETRIDE gorur muyum?" Cevap hayirsa once olcumu koy.
- 📌 **IKINCI DESEN:** bir yol icin yazilmis primitif BASKA yola baglanirsa dogrulugu
  ORADA TEKRAR sorgula (FAZ-7'nin arama-BASLANGICI ses fixi, turu 56'da bekletme yoluna
  baglaninca YIKICI oldu).
- **ONCEKI (3 Agu 02:05):** TEST TURU 63 YAYINLANDI — android 30771106968 +
  ios 30771107969 (5187fc8), R2 apk=108254861 (md5 2b466ce4) ipa=22349602 (md5 d322b588),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 02:05,
  **BACKEND DEPLOY EDILDI** (5187fc8) + health ok + canli dogrulama
  (`{"error":"telefon veya şifre hatalı"}` — Turkce duzeltmeler SUNUCUDA), DB temiz.
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 63 — "DEVAM ET" GSM KAPISI (YENI GIZLILIK ACIGI KAPATILDI):**
  Kullanici sordu: "devam et dedigimde GSM aramasini kapatmasi gerekmiyor mu?"
  **CEVAP: KAPATAMAYIZ** — Android ucuncu parti uygulamanin hucresel aramayi
  sonlandirmasina IZIN VERMEZ (`TelephonyManager.endCall()` API 29'da KALDIRILDI;
  `MODIFY_PHONE_STATE` sistem izni). iOS'ta da imkansiz. ⚠️ Bunu bir daha arastirma.
  **ASIL BULGU (kullanicinin sorusu sayesinde):** GSM gorusmesi SURERKEN "Devam et"e
  basilinca Gebzem mikrofonu geri aciliyordu -> **KARSI TARAF GSM KONUSMASINI
  DUYABILIYORDU.** Ustelik bir daha otomatik bekletilmiyordu: `gsmAramada` bir
  ValueNotifier ve yalniz DEGISIMDE tetiklenir; GSM zaten "suruyor" durumunda oldugu
  icin yeni olay gelmez ve mikrofon GSM BOYUNCA ACIK kalirdi. Turu 56 aciginin BASKA kapisi.
  **FIX (kullanici karari — zorlama YOK):** kisa profesyonel aciklama gosterilir,
  bekletme SURER: "Telefon görüşmeniz sürüyor. Önce onu sonlandırın; Gebzem araması
  kaldığı yerden devam edecek." GSM bitince ZATEN kendiliginden devam eder.
  ⚠️ YAPMA: bu kapiyi kaldirma; GSM surerken elle devam ettirmeye izin verme.
- ✅ **TURU 63 — TURKCE KARAKTER SUPURGESI: 204 DUZELTME** (13 ajan tarama+denetim).
  Dagilim: backend 132 · auth 42 · calls 19 · chats/rooms 9 · core 2.
  Ornek: Caliyor->Çalıyor · Mesgul->Meşgul · Sifre->Şifre · Giris Yap->Giriş Yap ·
  "gecersiz istek"->"geçersiz istek" (sunucu hatalari SnackBar'da GORUNUYOR).
  ⚠️ **UYGULAMA GUVENLIGI (bir daha ayni yontemi kullan):** once KURU CALISMA ile her
  `eski` metnin dosyada BIREBIR var oldugu dogrulandi (204/204, 0 kayip); uygulayici
  ayrica YENI metinde Turkce karakter YOKSA degisikligi ATLAR.
  ⚠️ DOKUNULMAYANLAR: yorumlar (bilerek ASCII — CLAUDE.md regex/encoding tuzagi) ·
  protokol dizeleri (`call:ended:audio`, `oda_`, `yayin`) · JSON alan adlari ·
  MethodChannel adlari · Sentry/log mesajlari (gelistirici icin).
- ✅ **TURU 63 — SOHBETTEKI ARAMA BALONU (kullanici ekran goruntusu: Messenger):**
  yuvarlak ikon + baslik + saat, ALTINDA tam genislikte **"Geri ara"** dugmesi.
  Cevapsizda daire KIRMIZI dolu, baslik "Cevapsız sesli/görüntülü arama".
  "Geri ara" -> alttan "Sesli ara / Görüntülü ara" paneli.
- ⏳ **SES GECIKMESI — OLCUME BAGLANDI (kullanici: "gecikme NORMALDE OLMUYOR, biri GSM
  aradiktan SONRA devam ettikten sonra oluyor"):** bu tarif jitter tamponu hipoteziyle
  BIREBIR uyusuyor (kesintide paketler birikir, devam edince birikmis ses calinir).
  Bekletmeden CIKISTAN 5sn sonra TEK SEFER Sentry olcumu:
  `devam sonrasi ses: jitterMs=.. tamponDeltaMs=.. gizlenenOrnek=.. recvDelta=..`
  **TEST SONRASI BAK** — degere gore hedefli duzeltme yapilacak.
  ⚠️ YAPMA: bu olcumu her istatistik tikinda gondermeye cevirme (Sentry gurultusu).
- **ONCEKI (3 Agu 01:18):** TEST TURU 62 YAYINLANDI — android 30769340134 +
  ios 30769341238 (05ec544), R2 apk=108254861 (md5 d29009c4) ipa=22344495 (md5 f240450f),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 01:18,
  **backend DEGISMEDI** (8276219'da kaldi) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 62 — UC SORUN + TUM ARAYUZ IKONLARI 2B'YE CEVRILDI**
  **(A) GSM ZIL ≠ KABUL (kok neden):** `TelefonDurumu.bildir()` karari
  `durum != CALL_STATE_IDLE` ile uretiyordu; sabitler IDLE=0/RINGING=1/OFFHOOK=2 —
  telefon SADECE CALARKEN de bekletme basliyordu. Kullanici reddederse/kacirirsa
  Gebzem bos yere kesilip geri aciliyordu.
  **YENI TABLO:** `OFFHOOK -> BEKLET` · `IDLE -> DEVAM` · `RINGING -> KARAR DEGISMEZ (latch)`.
  ⚠️⚠️ **RINGING NEDEN `false` DEGIL:** Android `CALL_STATE_RINGING`i "zaten aktif
  gorusme varken IKINCI cagri geldi" (GSM cagri bekletme) durumunda DA uretir. `false`
  yazsaydik SUREN GSM gorusmesinin ORTASINDA mikrofonu geri acardik ve karsi taraf GSM
  konusmasini DUYARDI — turu 56 GIZLILIK aciginin aynisi.
  ⚠️ `dur()` icinde `sonBildirilen` DE sifirlanir (ZORUNLU — nesne aramalar arasi yasiyor;
  yoksa GSM SURERKEN yeni arama baslayinca OFFHOOK olayi YUTULUR, mikrofon ACIK kalir).
  ⚠️ YAPMA: RINGING dalini `false` yapma; `sonBildirilen` sifirlamasini kaldirma.
  **(B) UYARI SERIDI SURENIN ALTINA ALINDI** (kullanici emri: "pil seviyen dusuk —
  bu butonlar zamanin altina olmali").
  ⚠️⚠️ `Flexible` sarmali KALDIRILDI — ZORUNLU: turu 60'ta bu Padding bir ROW cocuguyken
  `Flexible` DOGRUYDU; COLUMN cocugu olunca DIKEY eksende esner ve Column'un yuksekligi
  SINIRSIZ oldugu icin RenderFlex ASSERTION ile PATLAR (kirmizi ekran).
  ⚠️ YAPMA: buraya Flexible/Expanded koyma.
  **(C) "BEKLETMEDEN SONRA SES ARKADAN GELIYOR" (kok neden):** Android'de ses MODU
  (MODE_IN_COMMUNICATION), AUDIO FOCUS ve cihaz secimi YALNIZCA flutter_webrtc'nin
  `AudioSwitch.activate()` gecisinde uygulanir; o gecis `AudioSwitchManager.start()`in
  `if (!isActive)` kilidiyle korunur ve `isActive` ARAMA BOYUNCA true takilidir. GSM
  bitince Android modu MODE_NORMAL'a dondurur + cihaz secimini temizler -> ses kulaklik
  yerine HOPARLORDEN calar. Geri alan HICBIR SEY yoktu.
  **FIX:** native `sesOturumunuTazele` -> `AudioSwitchManager.stop()` + `start()`.
  ⚠️⚠️ **`stop(); start()` ARKA ARKAYA CAGRILIRSA CALISMAZ** (kaynak okunarak bulundu):
  ikisi de `handler.removeCallbacksAndMessages(null)` yapar, yani `start()` `stop()`un
  kuyruga koydugu `deactivate` isini SILER; `isActive` true kalir ve `activate()`
  `if (!isActive)` kapisinda NO-OP olur. `start()` BIR SONRAKI dongu turunda
  (postDelayed 120ms) cagriliyor. ⚠️ YAPMA: bu gecikmeyi kaldirma.
  ⚠️ YAPMA: `am.mode`u KENDIMIZ yazma (Activity'nin AudioManager'i AYRI istemcidir;
  birakan kod olmadigi icin MODE_IN_COMMUNICATION SIZAR).
  ⚠️ Dart'tan `setAndroidAudioConfiguration` YETMEZ — kaynak okundu: `setAudioMode`
  yalniz DEGERI saklar, uygulamayi `activate()` yapar.
  **(C-2)** `_androidSesTazele` AYNI degeri yaziyordu -> alt katman fark-kontrolunde
  ERKEN DONUP NO-OP kaliyordu. Artik once TERS deger, sonra dogrusu. ⚠️ AMA KULAKLIK
  KAPISI VAR: `setSpeakerOn(true)` BT/kablolu kulakligi YOK SAYIP hoparloru secer;
  kulaklikta ara deger olarak hoparlor secmek SCO'yu koparir + ses patlatir.
  ⚠️ YAPMA: kulaklik kapisini kaldirma; toggle'i kosulsuz yapma.
  **(C-3)** `devamEt()` `_speakerOn`i geri yuklemiyordu -> park edilmis SESLI arama,
  uzerine gelen GORUNTULU arama bitince HOPARLORDEN aciliyordu. `ParkEdilenArama
  .speakerOn` eklendi; bayrak await'lerden ONCE senkron, ROTA `_medyaBeklet` sonrasi +
  `_sesiAc(true)` ONCESI (CLAUDE.md iOS ses sirasi hukmu).
  **OLCUM:** `ses tazelendi: oncekiMod=N ...` GERCEK Sentry olayi. `oncekiMod=0`
  (NORMAL) -> teshis DOGRU; `=3` (IN_COMMUNICATION) -> mod bozulmuyor, baska yerde ara.
- ✅ **TURU 62 — ARAYUZDE EMOJI KALMADI (kullanici emri: "hicbir 3B ikon istemiyorum").**
  Emoji sistem emoji fontuyla (Apple Color Emoji / Noto Color Emoji) PARLAK ve 3B cizilir
  — 3B gorunumun kaynagi buydu. 35 arayuz noktasi Lucide (2B cizgi) ikona cevrildi:
  bekletme rozeti · sohbet listesi onizlemeleri (ayri `_previewIkon()`) · silinen mesaj ·
  canli yayin izleyici/jeton sayaclari · kesfet listesi · oda basliklari · host taci ·
  kalp animasyonu · kalan 3 Material ikon da Lucide'a.
  ⚠️ YAPMA: arayuze emoji geri koyma (metin ICINE de). Yeni ikon gerekirse Lucide.
  ⏳ **HEDIYE SIMGELERI BILINCLI BIRAKILDI:** sunucudan geliyor (`v['emoji']`), 30
  hediyelik katalog backend'de emoji olarak tanimli. Cevirmek ARAYUZ degil URUN
  degisikligi (katalog + backend + animasyonlar). **KULLANICI KARARI BEKLENIYOR.**
- **ONCEKI (3 Agu 00:07):** TEST TURU 61 YAYINLANDI — android 30766687222 +
  ios 30766688233 (8276219), R2 apk=108254021 (md5 1e589c3e) ipa=22344434 (md5 776ce510),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 00:07,
  **BACKEND DEPLOY EDILDI** (8276219; migration 013 uygulandi, `calls.held_by` sutunu
  canli DB'de DOGRULANDI) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 61 — KAYBOLAN `call.held` OLAYI SENTRY ILE KANITLANDI (tahmin DEGIL).**
  Turu 60'ta ekledigim olcum kok nedeni KANITA cevirdi. Kullanici testi (Android GSM
  bekletme, karsi taraf iPhone) — Sentry olaylari:
  · `20:48:04  gsm olayi: gsm=true  beklemede=false platform=android`  <- Android BEKLETTI
  · `20:48:32  gsm olayi: gsm=false beklemede=true  platform=android`  <- 28sn sonra kaldirdi
  · `20:48:35  call.held alindi: on=false eslesti=true ekran=true`     <- iPhone SADECE bunu aldi
  **`call.held alindi: on=true` olayi HIC YOK.** Android gonderdi, sunucu 200 dondu, ama
  iPhone o 28 saniye boyunca HICBIR SEY ALMADI. Ustelik `ekran=true` — arama ekrani ACIKTI.
  **KOK NEDEN:** `call.held` KAYBOLABILIR bir olaydi (ne kuyruk, ne tekrar, ne sunucu
  durumu). Istemci HER arka plana geciste WS'i kapatir (`bg` cercevesi; kilit ekraninda
  arama caldirmak icin ZORUNLU — turu 33) ve iPhone 47 dakikada 27 kez kopup baglaniyor.
  Olay o bosluga denk gelirse BIR DAHA ogrenilemiyordu.
  ⚠️ Turu 60 denetiminde ajanlar bunu **DUSUK** derecelendirmisti; SAHA VERISI ASIL SEBEP
  oldugunu gosterdi. **DERS:** "nadir gorunuyor" != "onemsiz"; olcum koyup BAKMAK sart.
  **FIX (durum sunucuda, istemci KENDINI ONARIR):**
  · migration **013**: `calls.held_by UUID` (en son beklemeye alan; cikinca NULL).
  · `Hold` handler: on=true -> `held_by=$user`; on=false -> yalniz KENDI kaydini siler
    (`AND held_by=$user`) ki karsi tarafin bekletmesi silinmesin.
  · `Status` ucu additive **`peer_held`** doner. ⚠️ `elapsed_ms` semantigine DOKUNULMADI.
  · Istemci `_durumKontrol` (ZATEN var olan **3sn'lik** yoklama) `peer_held` ile uzlastirir
    -> yeni trafik YOK, yeni uc YOK, yeni bagimlilik YOK.
  · WS olayi HIZLI YOL olarak KALIR (aninda tepki); yoklama EMNIYET AGI.
  ⚠️ YAPMA: `Hold`daki UPDATE'i kaldirip yalniz WS'e donme; `peer_held` uzlastirmasini
  istemciden cikarma; `held_by`yi grup aramasi acilirsa tek-kisi varsayimiyla kullanma.
- **ONCEKI (2 Agu 20:52):** TEST TURU 60 YAYINLANDI — android 30759365570 +
  ios 30759366701 (1159115), R2 apk=108254021 (md5 6562395b) ipa=22344917 (md5 6aa52c46),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 20:52,
  **backend DEGISMEDI** (db7e8a8'de kaldi) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 60 — "ANDROID GSM BEKLETMESI KARSI TARAFA GITMIYOR": ROZET CIZILIYORDU
  AMA EKRANDAN TASIP KIRPILIYORDU** (15 ajanlik kok-neden arastirmasi).
  🔴 **ILK HIPOTEZIM CURUTULDU:** "Android hold gondermiyor" YANLISTI. Mikrofon-enerjisi
  korelasyonuyla KANITLANDI: hold POST'uyla ES ZAMANLI olarak Android cihazin mikrofon
  enerjisi 0.0'a dusuyor, hold-off'ta geri geliyor; ayni anda iOS tarafi konusuyor.
  19 hold'un 6'si ANDROID, 6'si iOS, 7'si park (cagri bekletme) yolundan.
  **Android GSM zinciri CALISIYOR — sorun GONDERMEDE degil GORUNMEDE idi.**
  **KOK NEDEN:** bekletme rozeti DIKEY yigin icin yazilmisti (`top: 6` payi ele veriyor)
  ama bir `Row`un cocuguydu. Row'un hicbir cocugu `Flexible` degil -> RenderFlex hepsini
  SINIRSIZ genislikle olcer, Row ise `Positioned(left:0,right:0)` ile EKRAN GENISLIGINE
  tutturuludur. Karsi taraf GSM'i kabul edince uygulamasi arka plana gecer -> `karsiKalite`
  duser -> `uyariMetni` ("X baglantisi zayif") DOLAR (o kapi `!c.beklemede`ye bagli, yani
  KARSI tarafta ACIKTIR) -> sure + uyari + rozet ~490px, ekran 360-414px -> rozet sagdan
  TASAR ve ust `Stack` (varsayilan `Clip.hardEdge`) KIRPAR.
  **Rozet CIZILIR ama EKRANDA GORUNMEZ.**
  **FIXLER:** (1) rozet Row'dan CIKARILDI -> ust Column'un dogrudan cocugu; tam genislikte,
  14px kalin, ortali turuncu serit. ⚠️ YAPMA: rozeti tekrar o Row'un icine koyma.
  (2) bekletme aktifken uyari seridi BASTIRILDI (`!c.karsiBeklemede` eklendi) — hem
  yaniltici (sebep ag degil, bekletme) hem tasmaya katki.
  (3) uyari seridi `Flexible` ile sarildi: icindeki `Flexible` OLU KODDU (dis Row'un flex
  OLMAYAN cocugu -> sinirsiz kisit -> ellipsis HIC calismiyordu; turu 23'un "uzun uyari
  metni tasiyor" duzeltmesi fiilen TUTMAMIS). ⚠️ YAPMA: bu Flexible'i kaldirma.
  (4) `_svc.hold` MEDYANIN ONUNE alindi — eskiden UC await ve IKI kimlik kapisinin
  ARKASINDAYDI; unhold yolunda bir kapi tetiklenirse karsi taraf SONSUZA KADAR
  "beklemede" kaliyordu (temizleyecek baska yol YOK). ⚠️ YAPMA: await'lerin altina tasima.
  (5) `hold()` REST: hata TAMAMEN yutuluyordu (`catch (_) {}`) + TEK deneme -> 3 deneme
  (artan aralik) + basarisizsa Sentry olcumu. ⚠️ YAPMA: sessiz yutmaya donme.
  (6) bekletme bilgisi KUCULTULMUS aramada da gorunuyor (yesil bant). Rozet yalniz
  CallScreen agacindaydi; GSM konusurken Gebzem arka planda oldugu icin kullanicinin
  BAKTIGI yerde hicbir gosterge YOKTU.
  (7) **IKI OLCUM KORLUGU KAPATILDI:** GSM olayi ve `call.held` alimi artik GERCEK Sentry
  olayi. Ikisi de `_sesLog` = yalniz BREADCRUMB idi; breadcrumb ancak baska bir olayla
  yuklenir, bu yuzden 4 turdur telemetriyle KANITLAYAMIYORDUK (turu 50 ile ayni tuzak).
  ⚠️ YAPMA: bunlari tekrar breadcrumb'a cevirme.
  🚫 **AJANLARIN ELEDIGI COZUMLER — TEKRAR ONERME:**
  · hold icin PUSH YEDEGI -> iOS'ta VoIP push = HAYALET GELEN ARAMA ekrani (CLAUDE.md
    "reportNewIncomingCall KOSULSUZ" kurali).
  · `calls` tablosuna `held_by` sutunu -> GRUP icin YANLIS model (ayni anda birden fazla
    kisi beklemede olabilir) + handler'in acik tasarim kararini tersine cevirir.
  · wakelock / ekrani-acik-tut -> projede YAKINLIK SENSORU YOK; sesli aramada yanak
    dokunuslari dugmelere basar + pil akar (WhatsApp TAM TERSINI yapar: ekrani karartir).
  · WS'i arama boyunca acik tutmak -> turu 33: yari-acik soket yuzunden push atilmiyor,
    telefon CALMIYOR.
- **ONCEKI (2 Agu 19:05):** TEST TURU 58+59 YAYINLANDI — android 30755334616 +
  ios 30755335791 (db7e8a8), R2 apk=108254021 (md5 7d33c2d6) ipa=22342407, purge OK,
  CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 19:05 gorunuyor,
  **BACKEND DEPLOY EDILDI** (db7e8a8, health ok, yeni SQL canli DB'de test edildi),
  DB temiz (0/0/0/0). **KULLANICI TEST EDECEK.**
  ⚠️ APK boyutu bir onceki (yayinlanmayan) build ile BIREBIR AYNI cikti — MD5 farkli.
  "Boyut ayni = build eski" DEME kurali yine dogrulandi.
- ⚠️⚠️ **TURU 59b — BUILD ALINDIKTAN SONRA, YAYINDAN ONCE 19 AJANLIK ADVERSARYAL
  DOGRULAMA KOSULDU ("bu fixler YANLIS, kanitla") ve KENDI TURU 59 FIX'IMDE YUKSEK
  REGRESYON BULDU. Ilk build YAYINLANMADI, kod duzeltilip YENIDEN build alindi.**
  · **(1)(2) YUKSEK — IKI BAGIMSIZ AJAN AYNI HATAYI BULDU:** `nav.pop()` EN USTTEKI
    route'u kapatir, "beni" DEGIL. Turu 59'un (5) numarali fix'i bayat ekrani pop
    akisina DUSURDUGU icin, ustunde duran YENI aramanin **CANLI ekranini OLDURUYORDU**
    (bayat yasar, canli olur — sorunu TERSINE cevirmisti).
    **FIX:** arama hala yasiyorsa `ModalRoute.of(context)` + `removeRoute` ile YALNIZ
    KENDI route'umuz kaldirilir (animasyonsuz); ustteki ekrana DOKUNULMAZ.
    ⚠️ YAPMA: buraya kosulsuz `nav.pop()` geri koyma.
    **DERS:** "kendi ekranimi kapat" niyetiyle `Navigator.pop()` yazmak, ekran YIGINDA
    en ustte DEGILSE baskasini kapatir. Route'u ADRESLE.
  · **(8) ORTA — "siyahi `barrierColor` sagliyor" PREMISIM YANLISMIS:** Flutter'da
    `barrierColor` SABIT DEGIL, route animasyonuyla saydamdan renge gider
    (`AnimatedModalBarrier`). Container'i kaldirinca gecisin ortasinda arama ekrani
    YARI SAYDAM oluyor, ALTTAKI SAYFA ICINDEN gorunuyordu.
    **FIX:** siyah zemin `ColoredBox` olarak FADE'IN ICINE alindi.
    ⚠️ YAPMA: `ColoredBox`u kaldirip yalniz `barrierColor`a guvenme.
  · **(3) ORTA — KIMLIK TAKLIDI ACIGI (beklenmedik bulgu):** backend `SendMessage`
    mesaj TIPINI HIC dogrulamiyordu; DB CHECK 'system'e izin verdigi icin HERHANGI
    BIR KULLANICI `{"type":"system","content":"Gebzem Destek: hesabiniz askiya
    alindi..."}` gonderip karsi tarafta **gonderen adi/avatari/tiki OLMAYAN**, sunucu
    uretimi gibi gorunen satir cizdirebiliyordu.
    **FIX:** TIP BEYAZ LISTESI (text/image/video/audio/location). 'system' YALNIZ
    sunucunun kendi yazdigi arama kayitlari icin (calls paketi dogrudan INSERT eder).
    ⚠️ YAPMA: beyaz listeye 'system' ekleme. Ayrica iki istemci cagirani da ham
    icerik yerine notr "Sistem mesajı" basiyor.
  · **(4) DUSUK:** `End()` mutex UPDATE'i istek-omurlu `r.Context()` kullaniyordu —
    istemci tam o anda kapanirsa Postgres COMMIT etse bile pgx iptal hatasi doner,
    handler 500 yazip cikar, balon HIC yazilmaz (webhook da satiri 'ended' buldugu
    icin telafi edemez). Artik ayri, 5sn zaman asimli context.
    ⚠️ YAPMA: burayi `r.Context()`e dondurme.
  · **(5) DUSUK:** sohbet listesi onizlemesi ARAYANA da "Cevapsız" diyordu. Sunucu
    listede gondereni DONDURMUYORDU -> `last_sender_id` eklendi (SELECT + Scan sirasi
    birebir dogrulandi, canli DB'de test edildi); `onizleme({benimMi})` yon biliyorsa
    ayirir, BILMIYORSA yon iddiasinda BULUNMAZ.
  · **(7) DUSUK:** `devamEt()` ekrani UC await SONRASI aciyordu; o pencerede
    `minimized` zaten false yazildigi icin yesil bant da cizilmiyordu -> arama
    yasarken NE EKRAN NE BANT. Ekran artik await'lerden ONCE aciliyor.
    ⚠️ YAPMA: `ekraniAc()`i tekrar await'lerin altina tasima.
  · ✅ **"oda-yayin-dokunulmamis-mi" boyutu 0 BULGU** — sesli oda ve canli yayin
    akislari turu 58/59'dan ETKILENMIYOR (kullanici emri dogrulandi).
  **SUREC DERSI:** build ALMAK yayinlamak DEGILDIR. Artifact hazirken kosulan
  adversaryal dogrulama, sahaya cikacak YUKSEK bir regresyonu yakaladi. Bu adimi
  atlama.
- ⚠️⚠️ **TURU 59 — TURU 58'DE EKLEDIGIM OZELLIK OLU DOGMUSTU (build oncesi denetim):**
  "Cevaplanan arama" sohbet balonu kaydi YALNIZ `End()` handler'ina konmustu. Kullanici
  kapatinca istemci AYNI ANDA hem odadan cikar hem `/end` atar; LiveKit webhook'u
  **localhost'tan ms'ler icinde** gelir, istemcinin REST'i mobil agdan. Yani
  `UPDATE ... WHERE status IN ('ringing','active')` yarisini **neredeyse HER ZAMAN
  webhook kazanir** ve `/end` bir ustteki `RowsAffected()==0` kapisinda sessizce doner
  -> balon SAHADA HIC YAZILMAZDI.
  **FIX:** ortak `bitenAramayiSohbeteYaz()`; yarisi KAZANAN **her iki yoldan** cagriliyor.
  ⚠️ YAPMA: cagriyi `RowsAffected>0` kapisinin DISINA tasima (CIFT BALON); cop
  toplayicilara (sweep 2sa / olu-arama 90sn / `oluAramaTemizle`) ekleme (orada
  `ended_at` gercek kapanistan cok sonra -> SISMIS sure gosterir).
  **GENEL DERS:** "iki yazicidan biri kazanir" mimarisinde yeni yan etkiyi TEK yaziciya
  koymak = o yan etkinin hic calismamasi.
- **TURU 59 DIGER FIXLER:** (1) sohbet listesinde HAM `call:ended:audio:75` ->
  yeni `chats/arama_kaydi.dart` ayristirmanin TEK kaynagi (balon + onizleme).
  (2) `call:ended:*` artik `read_at=now()` ile OKUNMUS dogar (rozet gurultusu bitti);
  `call:missed:*` rozet URETMEYE DEVAM eder. (3) **BAYAT EKRAN CANLI EKRANI EZIYORDU**
  (dispose pop kararindan ~400ms sonra calisir; arada yeni arama devralirsa yesil bant
  canli ekranin ustune biner, banta dokunmak IKINCI push yapar) -> `ekranSahibi`
  NESNE KIMLIGI jetonu; ⚠️ callId karsilastirmasi YETMEZ (`geriAra()` callId'yi degistirir).
  (4) 240ms dirilme dali bayat ekrani pop etmiyordu -> ayni track'e iki renderer.
  (5) ELLE minimize'da yesil bant 1sn'ye kadar cizilmiyordu (`notifyListeners` `if`
  icindeydi, `minimized` zaten true) -> disari alindi. (6) GECIS: siyah katman
  `FadeTransition`in DISINDAYDI -> pop yonunde 160ms duz siyah + sert kesme + arama
  boyunca 2 fazla opak katman; Container kaldirildi (siyahi `barrierColor` veriyor),
  `CurvedAnimation` -> `CurveTween` (her karede kurulup dispose edilmiyordu).
  (7) Android `PipService.pipModu` PAYLASILAN bayragi hicbir yerde oz-iyilestirilmiyordu
  -> kacan bir `pipDegisti(false)` sonraki YAYIN ekranini kalici "PiP sade gorunumu"nde
  birakabilirdi; `resumed` dalinda temizleniyor.
  ⚠️ YAPMA: (3)(4) jeton kapilarini kaldirma; (5) notify'i geri `if` icine alma;
  (6) siyah Container'i geri koyma.
- **KALDIGIMIZ YER (2 Agu 16:58):** TEST TURU 57 YAYINLANDI — android 30750686204 +
  ios 30750682791 (33089f9), R2 apk=105211469 ipa=19313086, purge OK, CDN birebir,
  backend degismedi + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 57 — "GSM SONRASI DEVAM ETMIYOR" + "ARAMA BULUNAMADI" TEK KOK NEDEN**
  (turu 55 REGRESYONU, sunucu loguyla KANITLI):
  Sunucuda `POST /calls/{id}/answer` **6 kez 404**; hepsi ARAYANIN cihazindan ve aramanin
  ZATEN cevaplanmasindan SANIYELER SONRA (19be2fd1: cevap 13:29:34, 404 **13:29:38**).
  **MEKANIZMA:** turu 55'te giden aramayi da CallKit'e kaydettik (`gidenArama`). Amac
  dogruydu (iOS "Beklet ve Kabul"u ancak CallKit'te AKTIF arama varsa cizer) ama yan
  etkisi: ARAYAN tarafta da CallKit araması olusuyor ve CallKit **"kabul" olayi** uretince
  `main._callKitKabul` **KENDI GIDEN ARAMAMIZI** cevaplamaya calisiyordu -> sunucu 404
  (`WHERE id=$1 AND callee_id=$2` — arayan callee DEGIL).
  **ZINCIRLEME (iki semptom TEK kaynak):** 404 -> `main.dart` catch -> `CallKitService
  .bitir(callId)` -> **CallKit kaydimiz YOK EDILIYOR** -> iOS ses oturumunu birakip GERI
  VERMIYOR -> GSM sonrasi Gebzem **SESSIZ**; ayni catch SnackBar ile **"arama bulunamadi"**
  gosteriyor.
  **FIX:** `CallKitService.gidenler` kumesi — kendi baslattigimiz aramalarin **kabul
  olaylari YOK SAYILIR** (o olay yalniz GERCEKTEN GELEN aramalar icin anlamlidir).
  `gidenArama()` doldurur; `bitir()` ve `davetSifirla()` bosaltir.
  ⚠️ YAPMA: bu kapiyi kaldirma; `gidenler`i `gidenArama` disinda doldurma.
  ⚠️ **DERS:** CallKit'e giden arama kaydetmek, GELEN arama icin yazilmis TUM olay
  yollarini (kabul/red/timeout) arayan tarafta da tetikler — her birini ayrica ele al.
- ✅ **TURU 56 TESTI SONUCU (kanit):** cokme YOK · **`callkit izin durumu ... telefon=TRUE`**
  (36 turdur alinamayan Android GSM izni ARTIK ALINIYOR — izin sirasi fix'i TUTTU) ·
  17 aramada tek tarafli video YOK · 3 oda + 3 yayin sorunsuz · `bayat mesgul muhafizi` /
  `kamera acilamadi` / `video yayin yok` / `arama tipi CELISKI` HICBIRI CIKMADI ·
  PiP `oturum=true yerel3=90 cagri=2 iptal=0 msMax=0`.
- **ONCEKI (2 Agu 15:50):** TEST TURU 56 YAYINLANDI — android 30748279270 +
  ios 30748275465 (91f2b00), R2 apk=105211469 (KUCULDU) ipa=19312972, purge OK, CDN birebir,
  **BACKEND DEPLOY** (`grupAramaAcik=false` dogrulandi) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ✅ **URUN KAPSAMI (kullanici karari 2 Agu): 1:1 SESLI + 1:1 GORUNTULU + SESLI ODA +
  CANLI YAYIN. GRUP ARAMASI YOK.**
  · Istemci: `calls_tab` grup FAB'i ve `call_screen` "Kisi ekle" iki kapisi KALDIRILDI.
  · Backend: **`grupAramaAcik = false`** — `Start` (grup dali) ve `Add` KOSULSUZ reddeder.
  ⚠️ **DENETIM DERSI:** yalniz `maxGrupKatilimci`yi 2'ye indirmek YETMIYORDU — tek kisilik
  grupta `2 > 2` FALSE olup 2 kisilik grup ACILIYORDU. Bayrak SART.
  ⚠️ `return` sonrasi OLU KOD BIRAKMA (turu 48: "gozcu ULASILAMAZ KODDU") — bayrakla kapat.
  ⚠️ **GRUP KODU SILINMEDI** (37 dal 1:1 yollarina orulmus). `mini_izgara.dart` DURUYOR —
  oda/yayin kullaniyor. ⚠️ YAPMA: silmeye calisma.
- ✅ **GSM BEKLET — IKI KOK NEDEN (36 turdur sessizce bozuktu):**
  (1) **iOS HARF UYUSMAZLIGI:** CallKit hold olayi `action.callUUID.uuidString` ile gelir
  ve Foundation bunu **BUYUK HARF** dondurur; callId'lerimiz Postgres `gen_random_uuid()`
  = **kucuk harf**. Tam esitlik ESLESMIYOR -> `beklemeyeAl` SESSIZCE return ediyordu
  (medya durmuyor, sunucuya hold gitmiyor). Kabul/Reddet/Bitir ETKILENMIYOR — yalniz
  **hold ve mute** olaylari uuidString kullanir. FIX: `CallKitService._asilId` cevrimi +
  `beklemeyeAl`da harf-duyarsiz karsilastirma (ikinci katman).
  (2) **ANDROID IZNI HIC VERILMIYORDU:** `Permission.phone.request()`,
  `requestFullIntentPermission()`ten SONRA cagriliyordu; o cagri SISTEM AYARLAR ekranini
  acar, Activity duraklayinca izin diyalogu GOSTERILMEZ, Future ASILI KALIR.
  FIX: telefon izni ONCE, ayar ekranina sicrama EN SON. + sonuc okunuyor (Sentry olcumu).
  ⚠️ YAPMA: bu iki blogun sirasini degistirme; `gsmDinle` sonucunu `unawaited` ile atma.
- ⚠️ **GIZLILIK:** GSM gorusmesi surerken Gebzem'e gecince `resumed` dali MIKROFONU geri
  aciyordu -> **karsi taraf GSM konusmasini duyuyordu.** `resumed` sartina `&& !beklemede`
  + `_kesintidenTopla` basina savunma kapisi. ⚠️ YAPMA: bu kapilari kaldirma.
- ⚠️ **TURU 55/56 KENDI REGRESYONLARIM (build oncesi denetimde yakalandi):**
  · `beklemeyeAl`: uc await'ten sonra `arama!` -> NULL-CHECK PATLAMASI + `beklemede` TAKILI
    kalmasi. Kimlik await'lerden ONCE yakalanir + her await sonrasi kimlik kapisi.
  · `!beklemede` kapisi `resumed`daki `_kameraOtoAc()`i de blokluyordu -> GSM sonrasi
    GORUNTULU aramada kamera BIR DAHA ACILMIYORDU. unhold dalina `_kameraOtoAc()` eklendi.
  · `gidenArama` (turu 55) **HAYALET CALLKIT ARAMASI** birakiyordu: `_cevapsizGoster` ve
    `geriAra` yollarinda `CallKitService.bitir` CAGRILMIYORDU.
  · Giden arama CallKit'te "araniyor" kaliyordu; iOS bagli olmayan aramayi HOLD EDILEBILIR
    saymaz -> `CallKitService.baglandi()` (`setCallConnected`) eklendi (YALNIZ giden).
  ⚠️ YAPMA: bu dort duzeltmeyi geri alma.
- ✅ **MESGULLUK KONTROLU TEK KAYNAK:** `CallService.mesgulMu({haric, etiket})` —
  start/answer/oda/yayin AYNI yolu kullanir. Bayat kayit bulursa temizler + Sentry olcumu;
  GERCEK arama veya `oda_`/`yayin` kaydi varsa ENGELLER.
  ⚠️ YAPMA: bu mantigi cagiran yerlere kopyalama (drift eder — `rooms_tab`/`live_tab` ham
  `aramadaMi`ye bakiyordu ve self-heal'den yararlanmiyordu).
- ✅ **ANDROID SES TAZELEME:** `_sesiAc` Android'de kosulsuz erken donuyordu; GSM sonrasi
  ses SAGIR kalabiliyordu. `_androidSesTazele()` eklendi — YALNIZ kurtarma yollarindan
  (`beklemeyeAl(false)`, `devamEt`) cagrilir. ⚠️ YAPMA: `_connect` akisina sokma.
- **ONCEKI (1 Agu 19:23):** TEST TURU 54 YAYINLANDI — android 30707620654 +
  ios 30707617339 (384920c), R2 apk=105227853 ipa=19322064, purge OK, CDN birebir,
  backend 384920c'ye senkron + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ✅ **TURU 54 — TEKRAR DAVET TAKILMASININ ASIL KOKU (sunucu kaniti):** grup aramasi
  `7bc32718`e **4 x `/add` (hepsi 200), 0 x `/answer`** — davet ulasiyor, telefon caliyor,
  KABUL SUNUCUYA HIC VARMIYOR. Arama-id bazli **UC KUME** surec omru boyunca HIC
  temizlenmiyordu: `_cevaplanan` (ikinci kabul REST'e GITMEDEN null doner — ASIL KOK),
  `_bitenler`, `CallKitService.islenenler` (Android'de gelen-arama katmani bir daha acilmaz).
  FIX: `CallService.davetSifirla(id)` — `aramaBitti()`, `grupDavetiGoster()`, `leave()`ten.
  ⚠️ YAPMA: kapilarin KENDISINI kaldirma (ayni ZIL episodunda cift kabul korumasi);
  `davetSifirla`yi arama SURERKEN cagirma.
- ✅ **GRUP ARAMASINA DONUS (`devamEt`)**: WS aboneliklerini GERI KURMUYORDU (ikinci
  aramanin `baslat()`i `_iptalAbonelikler()` ile oldurmustu) -> devam edilen arama sunucuda
  'ended' olsa bile istemcide SONSUZA KADAR acik kaliyor, mesgul muhafizi dusmuyor,
  kullanici bir daha arama YAPAMIYOR/ALAMIYOR. Abonelikler `_aboneliklerKur(id)` ile TEK
  yere alindi (`baslat()` + `devamEt()`); `devamEt()` ayrica `_aktifPollBaslat()` +
  `_pilTakibiBaslat()` cagiriyor. ⚠️ YAPMA: `_aboneliklerKur`u yalniz `baslat()`a baglama.
- ✅ **PARK SURESI**: parkta gecen sure KAYBOLUYORDU. `ParkEdilenArama.parkSayaci`
  (MONOTONIK Stopwatch) + `_sureBaz = p.gecen + p.parkSayaci.elapsed`.
  ⚠️ YAPMA: DateTime/sunucu saati karsilastirmasiyla hesaplama (CLAUDE.md sure hukmu).
- ⚠️ **TURU 53 DARALTMASI:** `_iosPipBasarisiz` kapisi `inactive`i de kapsiyordu ama
  **EKRAN KILIDI de `inactive`ten GECER** -> durust mute atlanip karsi taraf DONMUS KARE
  goruyordu ("kamera duraklatildi kaldirmissin"). Kapi yalniz `resumed`e daraltildi.
  Kendi iptalimizi ayirt etme isi NATIVE `iptalIstendi` kapisinda (kesin bilgi).
  ⚠️ YAPMA: buraya `inactive`i geri ekleme; native kapiyi kaldirma.
- ⚠️ **"BEKLET/DURDUR KALDIRMISSIN" — KALDIRILMADI, HIC VAR OLMADI.**
  `git log -S "Beklet" -- call_screen.dart` BOS doner. "Arama beklemede" paneli yalnizca
  (a) CallKit hold, (b) Android GSM aramasi, (c) ikinci gelen arama ile ACILIR; elle
  basilacak dugme YOK. Kullanicinin gordugu sesli/goruntulu farki `_gizliEfektif`ten:
  GORUNTULUDE ekrana dokununca alt kontrol cubugu GIZLENIYOR ve geri gelmiyor.
- **HENUZ YAPILMADI (kok neden bulundu, kullanici karari bekliyor):**
  (1) **Goruntuluede "Beklet ve Kabul" gelmiyor** — ANA KOK: GIDEN aramalar CallKit'e HIC
  bildirilmiyor (`FlutterCallkitIncoming.startCall` kod tabaninda YOK); iOS o ekrani ancak
  CallKit'te aktif arama varsa cizer. Fark sesli/goruntulu DEGIL, **ARAYAN/ARANAN** farki.
  (2) **Gecis animasyonu** — minimize/restore Navigator PUSH/POP; ekran her buyutmede
  SIFIRDAN kuruluyor, `VideoTrackRenderer` dispose oluyor.
- **ONCEKI (31 Tem 23:30):** TEST TURU 53 YAYINLANDI — android 30662374718 +
  ios 30662368371 (53512fc), R2 apk=105227853 ipa=19165051, purge OK, CDN birebir,
  **BACKEND DEPLOY EDILDI** (53512fc, `maxGrupKatilimci=4` sunucuda dogrulandi) + health ok,
  DB temiz. **KULLANICI TEST EDECEK.**
- ✅ **TURU 53 — "APP SWITCHER'DA KAMERA KAPANIYOR"UN KOK NEDENI: BIZ (16 ajanlik denetim)**
  **iOS KURALI (Apple):** kamera YALNIZ uygulama GERCEKTEN `.background`a gecerse kesilir
  ("Camera usage is prohibited while in the background"); tek istisna PiP'in AKTIF olmasi.
  **App switcher / Kontrol Merkezi uygulamayi YALNIZ `.inactive` yapar** (Flutter belgesi)
  ve iOS orada kamerayi HIC KESMEZ. **WhatsApp'in yaptigi sey: HICBIR SEY YAPMAMAK.**
  **BIZIM ZINCIR:** `inactive`te PiP baslat -> donuste `resumed` dalinda KOSULSUZ
  `iosPipDurdur()` ile PiP'i BIZ iptal et -> yarida kesilen acilis AVKit'in
  `failedToStartPictureInPicture`ini atesler -> 800ms teyit blogu yalnizca
  `isPictureInPictureActive`e bakar (biz kapattik, false) -> `iosPipBasarisiz` Dart'a iner
  -> uygulama ON PLANDA, AKTIF, ekran acikken `setCameraEnabled(false)`. Ustelik geri acma
  `resumed` KENARINA bagli oldugu icin kamera BIR DAHA ACILMIYORDU.
  **FIX:** (a) native `failedToStart` 800ms blogunun basina `if self.iptalIstendi { return }`
  (turu 49'un "800ms'i kaldirma" kuralini IHLAL ETMEZ; "`.background` kapisi" kurali
  `baslat()` icindir, BURASI DEGIL), (b) Dart `_iosPipBasarisiz` on-plan kapisi.
  **ILKE: kamerayi yalnizca iOS'un KENDI kesinti olayi veya GERCEK arka plan gecisi kapatir.**
  ⚠️ YAPMA: bu iki kapiyi kaldirma.
- ✅ **`_kameraOtoAc` (seviye-tetiklemeli geri acma):** bekleyen `_kesintiMuteGecikme`yi
  IPTAL EDER + `resumed` dalindan VE `_iosKameraKesinti(false)`tan cagrilir (o dal eskiden
  bos `return` = OLU KOD idi). ⚠️ YAPMA: icine `_iosArkaPlanKamera = true` yazma
  ("yalan bayrak" regresyonu, turu 32-33).
- ✅ **AKTIF KONUSAN TAKIBI KAPATILDI** (kullanici: "bu tur ozellikleri kapa"):
  `miniKatilimcilar` ve `_uzakVideoTrackId` icindeki `activeSpeakers` bloklari SILINDI ->
  sira SABIT (katilma sirasi). Tam ekrandaki yesil "konusuyor" cercevesi KORUNDU.
  ⚠️ YAPMA: bu iki yere tekrar `activeSpeakers` siralamasi koyma.
- ✅ **DONUSTE "CIZME":** renderer anahtarlari TRACK KIMLIGINE bagliydi; on plana donuste
  `setCameraEnabled(true)` -> livekit `restartTrack()` -> YENI `mediaStreamTrack` ->
  anahtar degisiyor -> renderer YIKILIP yeniden kuruluyordu. Artik ROL bazli
  (`vid-yerel`/`vid-uzak`) ve grup tile'i `tile-${p.identity}`.
  ⚠️ YAPMA: anahtarlara tekrar track kimligi (id/sid) koyma.
- ✅ **IZGARA SIYAHLIKLARI:** Flutter `bosluk` 2.0 -> 0 · iOS native `yigin.spacing` ve
  `satir.spacing` 1 -> 0 · `callVC.view.backgroundColor` lacivere sabitlendi (bosluklardan
  ATANMAMIS SIYAH zemin gorunuyordu) · grup izgarasi padding `(8,108,8,132)` -> **zero** +
  tile boslugu 6 -> 0. ⚠️ Grup kapasitesi 4'un UZERINE cikarilirsa padding'i GERI GETIR
  (5-6 kisilik SESLI grupta alt satirin adi kontrollerin altinda kaybolur).
- ✅ **PiP ORANI:** ⚠️ `preferredContentSize` **MUTLAK BOYUT DEGIL** — iOS yalniz ORANI
  kullanir; Android'de de `setAspectRatio` disinda boyut API'si YOK. Bu yuzden "%10 buyut"
  = ORTAK VE DAHA GENIS ORAN: iOS 0.563 / Android 3:4 -> **ikisi de 5:6 (0.833)**.
  ⚠️ YAPMA: orani calisma aninda degistirme; iki platformu farkli oranda birakma.
- ✅ **GORUNTULU ARAMA "SESLI" BASLIYORDU (aranan tarafta):** `_camOn=false` olunca kamera
  blogu KOMPLE atlanir ve turu 50'nin `_videoYayinDogrula`si DA O BLOGUN ICINDE oldugu icin
  hicbir iz kalmiyordu (DB `type=video`, LiveKit'te yalniz audio, Sentry bombos).
  `_camOn` CallKit yukundeki bayraktan geliyordu. FIX: `answer()` yanitindaki `type`
  (backend handler.go ZATEN donduruyor) **OTORITER**; CallKit yuku YEDEK. Ayrica
  `arama.video==true && camOn==false` ise artik Sentry'e olay dusuyor (korluk kapandi).
  ⚠️ YAPMA: arama tipini tekrar yalniz `c['video']`ya baglama.
- ✅ **"CIKIP HEMEN TEKRAR ARAYAMIYORUM":** sunucu TEMIZDI (asili arama 0, 409 yok).
  Engel istemcideki `ekrandakiAramalar` mesgul muhafizi — 5 ekrandan giriliyor, 9 yerden
  birakiliyor; biri kacinca id asili kalip `start()` kosulsuz hata firlatiyordu.
  Artik GERCEKLIGE soruluyor: gercek aktif arama VEYA `oda_`/`yayin` muhafizi varsa engelle,
  yoksa BAYAT kabul edip temizle + Sentry olcumu.
  ⚠️ YAPMA: bu kapiyi kosulsuz temizlemeye cevirme (ses cakismasi korumasi orada).
- **ONCEKI (31 Tem 02:05):** TEST TURU 52 YAYINLANDI — android 30588794092 +
  ios 30588788364 (33fc2d9), R2 apk=105227853 ipa=19317028 (+169KB = native izgara),
  purge OK, CDN birebir, backend degismedi (678f5fc) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ✅ **TURU 52 — KUCUK PENCERE IZGARASI (24 ajanlik denetim):**
  Native `ekKaynaklarAyarla` + Flutter `miniIzgara` AYNI merdiven: 1 tam · 2 UST/ALT ·
  3-8 iki sutunlu satirlar (son satirda tek kalirsa tam genislik). Kose kutusu (ben)
  yalniz 1-2 uzak kutu varken cizilir.
  ⚠️ **ONCEKI ISRARIM YANLISTI:** "iOS sistem PiP'inde izgara yapilamaz, orayi iOS ciziyor"
  DEMISTIM — YANLIS. `AVPictureInPictureVideoCallViewController` BIZIM VC'miz, icine ne
  koyacagimiza BIZ karar veriyoruz (AppDelegate.swift:583). Izgara orada da calisir.
  **DENETIM KENDI YENI KODUMDA 5 HATA BULDU** (hepsi duzeltildi): (1) sira duyarli
  karsilastirma + `activeSpeakers` sirasi -> biri konusunca izgara komple yikiliyordu;
  (2) PiP yeniden kurulunca `_iosPipEkIdler` sifirlanmiyordu -> izgara bir daha
  cizilmiyordu; (3) gozcu ek kutulari izlemiyordu -> donmus kare deligi geri acilmisti;
  (4) izgarada kose kutusu bir katilimciyi kapatiyordu; (5) 8 renderer = kare basina
  CVPixelBufferCreate + ornek-basina kuyruk -> **HAVUZ + TEK paylasilan kuyruk**.
  ⚠️ YAPMA: karsilastirmayi sira duyarli yapma; ek listeyi `activeSpeakers` ile siralama;
  `_iosPipEkIdler` sifirlamalarini kaldirma; gozcuden ek kutulari cikarma; izgarada kose
  kutusunu geri acma; havuzu/tek kuyrugu kaldirma.
- ✅ **"KAMERA DURAKLATILDI" TEK GORUNUM:** ayni durum 3 farkli bicimde ciziliyordu
  (uygulama ici blur+yazi · iOS PiP MOR DAIRE+yazi · Android PiP mor daire+HARF, yazi YOK).
  Hepsi TEK dile indi: koyu zemin + siyah seffaf hap + beyaz yazi. `_bantIlkVideo` mute
  track'i ELIYORDU (kutu mor daireye dusuyordu) -> yeni `_miniVideo` + `MiniKatilimci.beklemede`.
  ⚠️ YAPMA: mor daireyi geri koyma; native tarafa `UIVisualEffectView` (blur) ekleme
  (katman flush edildigi icin bulaniklastirilacak goruntu YOK, ustelik riskli).
- ✅ **KOSE KUTUSU:** cerceve KALDIRILDI · yaricap iOS 5 / Flutter 7 -> **ikisi de 14**
  (buyuk ekranla ayni) · yukseklik **%10 kisaldi** (4:3 -> 6:5; Flutter tavani 0.45 -> 0.405)
  · genislik %34 ve kenar boslugu 5 DEGISMEDI -> iOS/Android BIREBIR ayni.
- ⚠️ **"cagri=10" YORUMUM YANLISTI (duzeltme):** `baslatCagri` YALNIZ didStart'in BASARILI
  dalinda sifirlaniyordu; iptal/failedToStart olan acilislar sayaci artirip HIC
  sifirlamiyordu -> deger tek bir alta almayi degil BIRIKMIS gecisleri sayiyordu.
  "10 kez ust uste istendi" TESHISI GECERSIZ. Artik `iptalCagri` ayri sayilir (`iptal=N`)
  ve ikisi de `durdur()`ta (= on plana donus) sifirlanir.
  ⚠️ YAPMA: sayaclari yalniz basarili dalda sifirlamaya donme.
- **ONCEKI (31 Tem 00:06):** TEST TURU 51 YAYINLANDI — android 30581163737 +
  ios 30581157141 (f7f5040), R2 apk=105227857 (MD5 degisti) ipa=19148243 (BUYUDU = Swift
  derlendi), purge OK, CDN birebir, **backend DEGISMEDI** (678f5fc) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ✅ **TURU 51 — PiP BOLUNME DENETIMININ 6 DUZELTMESI (28 ajanlik denetim sonucu):**
  (1) **ALTA ALMA COKMESI COZULDU** (EXC_BAD_ACCESS, Sentry 29 Tem, son iz
  `app.lifecycle:background`): kare teslimi WebRTC thread'inde kosarken ANA thread
  `track.remove(renderer)` + nil yapip nesneyi serbest birakiyordu. FIX: `PipRenderer`a
  NSLock + `aktif` bayragi + **MEZARLIK** (sokulen renderer 2sn canli tutulur).
  (2) `toplamKare`/`sayac` kilide alindi (iki thread'den kilitsizdi).
  (3) `gozcuDur()` artik `durdur()` ve `didStopPictureInPicture` icinde de cagriliyor
  (gozcu KAPANMIS pencere icin sink ameliyati tetikliyordu).
  (4) **KOSE KUTUSU KOR TRACK SECIMI BITTI**: yalniz `.live && isEnabled`; birden fazla
  aday varsa TAHMIN YOK (`belirsiz`); olu track `track-olu`. (NSMutableDictionary anahtar
  sirasi deterministik DEGIL — "ilkini al" yanlis kamerayi da seciyordu.)
  (5) **KIMLIK DEGISIMINDE PENCERE KAPANMASI**: once SICAK GECIS denenir, yalniz
  basarisizsa `iosPipKur` (o native `birak()` -> `stopPictureInPicture` yapar).
  (6) **"IKI KUTUDA DA BENI GOSTERIYOR"**: kose kutusu YALNIZ `_iosPipKurulanId == uzakId`
  iken cizilir (eskiden yalniz `uzakId != null` bakiyordu).
  (7) **SESLI->GORUNTULU ARAMADA PENCERE KAYBI**: `pipModunda` iken `iosPipBirak`
  CAGRILMAZ (arka planda kamera kesilince `uygun` dusup pencereyi kapatiyordu).
  (8) Kose kutusu hatasi Sentry'e ARAMA BASINA 1 kez (eskiden saniyede bir -> 195 kayit).
  ⚠️ YAPMA: mezarligi/kilidi kaldirma; `gozcuDur()` cagrilarini geri alma; kose kutusunda
  canlilik kontrolunu kaldirma veya coklu adayda tahmin yurutme; kimlik degisiminde sicak
  gecis denemesini atlama; kose kutusu sartini yalniz `uzakId != null`a indirgeme;
  `pipModunda` birakma kapisini kaldirma.
- **KAMERA "DURAKLATILDI" NEDIR (kullanici sorusu 30 Tem):** referans **iOS**, WhatsApp
  degil. iOS uygulama gorunmuyorken kameraya izin VERMEZ — capture session
  `videoDeviceNotAvailableInBackground` (sebep=1) ile kesilir. Bu bir GUVENLIK/GIZLILIK
  kurali; WhatsApp da ayni seyi yasar, sadece durustce "video duraklatildi" yazar.
  Tek istisna: iOS 16+ PiP AKTIFKEN kamera yasayabilir (turu 43-49'un konusu).
- **ONCEKI (30 Tem 21:39):** TEST TURU 50 YAYINLANDI — android 30570448293 +
  ios 30570457011 (678f5fc), R2 apk=105227857 ipa=19146222 index=6945, purge OK, CDN birebir,
  backend deploy (678f5fc) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
  ⚠️ **APK BOYUTU YANILTIR:** turu 44-50 boyunca apk hep 105227857 cikiyor ama ICERIK farkli
  (eski ETag `31161020…` / yeni MD5 `5d1381a2…`). "Boyut ayni = build eski" DEME, MD5 karsilastir.
- **INDIR SAYFASI — "SAATI GOREMIYORUM" KOK NEDENI:** saat sayfada VARDI ama ERISILEMIYORDU.
  `body { display:flex; align-items:center }` + karttan uzun icerik = **ust tasma kaydirilamaz**
  (klasik flexbox tuzagi) -> mor saat cubugu telefonda kirpiliyordu. FIX: body'den flex ortalama
  KALDIRILDI, saat cubugu **kartin DISINA, sayfanin en ustune** tasindi. Uretici:
  `scratchpad/indir_uret.js` (saat UTC+3, surum etiketi APK linkine `?v=`).
  ⚠️ YAPMA: body'ye tekrar `display:flex; align-items:center` koyma.
- **TURU 50 OLCUMLERI (Sentry, gebzem-mobile — test sonrasi BAK):**
  `kamera acilamadi: …` (kamera yolu hala patliyor) · `video yayin yok — kamera tekrar
  deneniyor` (emniyet agi kurtardi) · `video tekrar denemesi BASARISIZ: …` (kurtarma da
  tutmadi). Hicbiri cikmazsa kok cozum TUTTU.
- ✅ **BIREBIR VIDEO DUSMESI — KOK NEDEN KANITLI COZULDU (sunucu logu, tahmin degil):**
  LiveKit 96 saatlik log oda-oda sayildi: **64 aramanin 9'unda tek tarafli video (%14)**;
  patlayan taraf **9/9 iOS, 0 Android**, **8/9 iPhone11,6 (XS Max)**, **7/9 ARANAN**.
  Ag 6 hucresel/2 wifi -> **internet hizi veya sarj DEGIL, KOD.**
  KOK: `_odayaBaglan`da `await _onizlemeIsi?.timeout(700ms)` — **`Future.timeout` alttaki
  isi IPTAL ETMEZ**. Sure asilinca yedek yol `setCameraEnabled(true)` IKINCI kamerayi acar;
  `createCameraTrack` hala calisiyordur ve iOS'ta flutter_webrtc **TEK paylasilan
  `videoCapturer`** tuttugu icin iki capture oturumu birbirini oldurur -> video track odaya
  HIC ulasmaz. ARANAN'da onizleme ancak answer REST'inden SONRA basladigi icin pencere yok
  denecek kadar az; ARAYAN'da erken basladigi icin neredeyse hic patlamaz.
  **NEDEN 20+ TUR GORUNMEDI:** hata `_sesLog` ile yutuluyordu, `_sesLog` Sentry'e yalniz
  **BREADCRUMB** yazar (breadcrumb ancak baska bir olay/crash olursa yuklenir).
  Bagimsiz teyit: Sentry `ios pip alt gorunum sonuc=track-yok` **195 kayit**.
  FIX: `_onizlemeIptal` (gec biten onizleme ATILIR) · pencere 700ms -> **2500ms** · kamera
  hatasi artik `Sentry.captureMessage` (gorunur olcum) · **`_videoYayinDogrula`**: baglantidan
  1.5sn sonra video track yoksa TEK SEFER tekrar dener (yapisal emniyet).
  ⚠️ YAPMA: `_onizlemeIptal`i kaldirma; beklemeyi 700ms'e dusurme veya suresiz yapma;
  `_videoYayinDogrula`yi kaldirma/dongu yapma; kamera hatasini tekrar yalniz breadcrumb'a yazma.
- **SINIRLAR (kullanici karari 30 Tem — koda islendi):**
  · Grup aramasi (sesli VE goruntulu): **4 kisi** (arayan dahil) — 31 Tem'de 8'den
    INDIRILDI (kullanici: "aciklari ve buglari minimumda tutmak istiyorum").
    GEREKCE (olculere dayali): SFU iletimi N*(N-1) — 4 kisi 12 akis, 8 kisi 56 akis
    (4.7 kati) ve tum trafik TURN relay'den geciyor; istemci N-1 video COZER, VP8
    iPhone'da yazilimla cozuluyor (XS Max'te 7 cozme + simulcast = isinma/pil);
    kucuk pencerede 8 kutu ~74x64pt + 8 yazilim i420 donusumu.
    **DORT YER AYNI SAYI OLMALI:** backend `maxGrupKatilimci` · `toggleCam` kapisi ·
    `_ekUzakVideoTrackIdleri` (`>= 3`) · `kMiniEnFazlaKutu`.
    ⚠️ YAPMA: bu dordunu farkli birakma; PiP tavanini backend kapasitesinden buyuk yapma.
  · Sohbet odasi: **konusmaci 20** (odayi kuran dahil) + **dinleyici SINIRSIZ**
    (`internal/rooms/handler.go` `maxKonusmaci=20`, `maxDinleyici=0`, `odaKapasitesi=0`;
    kapasite kontrolleri `maxDinleyici > 0` sartli). ⚠️ Sartsiz geri koyma.
  · Canli yayin: **yayinci + 3 konuk = 4** + **izleyici SINIRSIZ** (zaten boyleydi;
    `STREAM_MAX_GUESTS=3`, `STREAM_MAX_VIEWERS=0`).
- **GRUP IZGARASI ALT TASMASI:** satir yukseklikleri `box.maxHeight`e TAM oturuyordu;
  ondalik yuvarlama alt kenarda sari-siyah "RenderFlex overflowed" seridi cizdiriyordu
  (kullanici: "toplu goruntuluda altta patliyor"). Yarim piksel pay + `math.max(1.0, ...)`.
- **SUNUCU SAGLIKLI:** %79-82 bosta CPU, wa=0, LiveKit hatasiz. ⚠️ `top -bn1`in ILK
  iterasyonu YANILTICI (surec omru ortalamasi verir) — CPU'yu vmstat/2. ornekle olc.
- **KALDIGIMIZ YER (28 Tem 01:06):** TEST TURU 49 YAYINLANDI — android 30308483234 +
  ios 30308485130 (a2ead0e), R2 apk=105227857 ipa=19145592 (buyudu), purge OK, CDN birebir,
  backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 49:** OLCUM `kesinti ... pip=FALSE` + olcum satiri YOK -> turu 48te ekledigim
  `applicationState == .background` kapisi TEK BASLATMA denemesini de yutmus (Dart tetigi
  method channel ile ASENKRON iniyor). Kapi KALDIRILDI; `SceneDelegate.sceneWillResignActive`
  kancasi GERI ama **DispatchQueue.main.async** ile (turu 43 SENKRONDU -> kamera yasadi ama
  alta alma takildi; turu 46 kanca yoktu -> takilma gecti ama kamera oldu). failedToStart
  artik 800ms teyit gecikmesiyle bildiriliyor.
  ⚠️ YAPMA: `.background` kapisini geri koyma; kancayi senkron yapma veya kaldirma;
  failedToStart gecikmesini kaldirma.
- **KALDIGIMIZ YER (28 Tem 00:32):** TEST TURU 48 YAYINLANDI — android 30306342017 +
  ios 30306343945 (91a9661), R2 apk=105227857 ipa=19145142 (buyudu = yeni native kod),
  purge OK, CDN birebir, backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 48 — "kose kutusu (kendi goruntum) donuyor" KOK SEBEP:**
  (1) **GOZCU ULASILAMAZ KODDU** (gorunen sebep): `gozcuBaslat()` once BUYUK kutuya bakip
  `if n != sonGorulenKare { ...; RETURN }` yapiyordu; KOSE kutusu kontrolu O RETURN'UN
  ALTINDAYDI. Karsi tarafin videosu aktigi surece (kullanicinin tam durumu, `arka=89`)
  kose kutusunun donmasi HIC fark edilmiyordu. FIX: kose kontrolu EN BASA, iki kutu bagimsiz.
  (2) **YANLIS BAYRAK** (20 turdur): `isMultitaskingCameraAccessEnabled` yalnizca sebep 4
  (`...WithMultipleForegroundApps`) kesintisini engelliyor; bizimki `sebep=1`
  (`videoDeviceNotAvailableInBackground`). Uc olcumde de `coklu=true` — bayrak degisken
  DEGIL. Arka planda kamerayi ayakta tutan tek sey PiP'in AKTIF olmasi.
  (3) Turu 47 GERI ALINDI (`arka=0` regresyonu): `cokluGorevKameraAc()` tekrar SALT OKUMA.
  (4) Arka planda `startRunning()` kurtarmasi SILINDI (Apple: arka planda kamera YASAK;
  yapisal olarak imkansiz — `kurtarma=null`).
  (5) `yereliBosalt()` / `iosPipKareBosalt(yalnizYerel:true)` — eskiden kendi kamera
  kapaninca KARSI TARAFIN kutusuna da "duraklatildi" basiyordu.
  (6) PiP baslatma 1200ms TEKRAR PENCERESI + native `applicationState == .background` kapisi.
  (7) Olcum: `yerelOn/yerel1/yerel3`, `arka1/arka3`, `durum`, `pipAktif`.
  ⚠️ YAPMA: kose gozcusunu tekrar buyuk kutunun dalinin altina tasima; capture session'i
  disaridan yeniden yapilandirma (45: takilma / 47: medya durur); arka planda `startRunning()`
  kurtarmasi ekleme; `.background` kapisini kaldirma.
- **KALDIGIMIZ YER (27 Tem 23:10):** TEST TURU 47 YAYINLANDI — android 30300476213 +
  ios 30300478407 (e160976), R2 apk=105227857 ipa=19144584, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 47 — "kose kutusu (kendi goruntum) yine donuyor":**
  OLCUM: turu 44 (tazeleme VAR) `oturum=true` · turu 46 (tazeleme YOK)
  `oturum=false cagri=1 msMax=0`. Yani turu 46'nin TAKILMA duzeltmesi tuttu ama AYNI turda
  (45) kaldirdigim **kamera-izni tazelemesi YUK TASIYORMUS** — kaldirinca kamera arka planda
  yine oluyor. Kesinti kaydi: `sinif=AVCaptureMultiCamSession` (webrtc-sdk PAYLASILAN statik
  multicam oturumu — bayrak orada sarkabiliyor; Apple'in "baslatmadan once yaz" kurali
  GEREKLI ama TEK BASINA YETMIYOR) ve `kurtarma=null` (kosulda `!calisiyor` vardi ama kesinti
  aninda `isRunning` HALA true).
  **FIX:** tazeleme GERI GELDI ama yazma **ARKA PLAN KUYRUGUNDA** (turu 45'teki takilmanin
  sebebi yazmanin kendisi degil, ANA IS PARCACIGINDA yapilmasiydi) · Dart `inactive` dalindaki
  tazeleme cagrisi geri geldi · kurtarma kesintiden **400ms sonra** kontrol edip deniyor.
  ⚠️ YAPMA: tazelemeyi ana is parcacigina tasima (takilma doner) veya kaldirma (kamera oluyor);
  `!calisiyor` sartini kesinti anina geri koyma.
- **KALDIGIMIZ YER (27 Tem 21:54):** TEST TURU 46 YAYINLANDI — android 30294743012 +
  ios 30294745045 (e07c24d), R2 apk=105227857 ipa=19144256, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK (alta alma akici mi).
- **TEST TURU 46 — "ALTA ALIRKEN ZORLANIYORUM, EKRAN KAYIYOR AMA INMIYOR":**
  Tek bir home hareketinde `startPictureInPicture()` **5 KAYNAKTAN** cagriliyordu:
  (1) SceneDelegate `sceneWillResignActive` (turu 43) — SENKRON, UIKit gecis callout'unun
  ICINDE ve parmak HENUZ EKRANDAYKEN (home hareketi INTERAKTIFTIR), (2) Dart `inactive`,
  (3) Dart `hidden` (Flutter iOS'ta SENTEZLER), (4) Dart `paused`, (5) iOS auto-enter.
  Tek koruma `isPictureInPictureActive` ACILIS ANIMASYONU boyunca FALSE doner — hicbirini
  durdurmuyordu. Hareket IPTAL edilirse `.active`e donulur -> didStart kapisi
  `stopPictureInPicture()` cagirir -> ac-kapa savasi.
  **FIX:** SceneDelegate kancasi KALDIRILDI · NATIVE tek-istek kapisi (`baslatIstendi` +
  1.5sn emniyet timer'i, tum delegate dallarinda sifirlanir; `isPictureInPicturePossible`
  false iken bayrak SET EDILMEZ) · DART yalniz `inactive` + YON KONTROLU (`_sonYasamDurumu`,
  yalniz `resumed`dan geliyorsak) · OLCUM `cagri`/`msMax` Sentry'e.
  ⚠️ YAPMA: `paused`/`hidden` dallarini geri ekleme; yon kontrolunu kaldirma; SceneDelegate'e
  tekrar senkron `startPictureInPicture` koyma; tek-istek bayragini `possible==false` iken
  set etme (pencere HIC acilmaz — turu 20 regresyonu).
- **KALDIGIMIZ YER (27 Tem 20:45):** TEST TURU 45 YAYINLANDI — android 30289622533 +
  ios 30289624993 (5c07af0), R2 apk=105227857 ipa=19143856, purge OK, CDN birebir, IPA icinde
  MinimumOSVersion=16.0, backend degismedi + health ok, DB temiz.
  **ARAMA/PiP FAZI TAMAMLANDI** (kullanici onayi: "on numara").
- **TEST TURU 45:** "alta alirken zorlaniyorum, ekrani zorla ciziyor gibi" —
  KOK: turu 31'de `didChangeAppLifecycleState` `inactive` dalina konan
  `iosArkaPlanKamerayiTazele()`, CALISAN `AVCaptureSession` uzerinde
  `beginConfiguration`/`commitConfiguration` yapiyordu: AGIR is + TAM GECIS ANI + ana is
  parcacigi. Kaldirildi; `cokluGorevKameraAc()` SALT OKUMA yapildi.
  ⚠️ YAPMA: gecis aninda (inactive/paused) capture session yeniden yapilandirma; bu metoda
  tekrar begin/commitConfiguration koyma. (Bayragi turu 37 swizzle'i zaten DOGRU anda yaziyor.)
- **SIRADAKI IS:** teshis/olcum kodlarinin temizligi -> **MEDYA MESAJLASMA (foto/video/sesli
  mesaj)** -> kalici grup sohbeti -> profil -> yayin oncesi temizlik (admin "Ses Teshis"
  sekmesi, BTK yer saglayici bildirimi).
- **KALDIGIMIZ YER (27 Tem 20:12):** TEST TURU 44 YAYINLANDI — android 30287113321 +
  ios 30287115762 (26c8854), R2 apk=105227857 ipa=19143659, purge OK, CDN birebir, IPA icinde
  MinimumOSVersion=16.0 dogrulandi, backend degismedi + health ok, DB temiz.
- ✅ **iOS ARKA PLAN KAMERASI KANITLI COZULDU (20+ turluk sorun):**
  Sentry: ONCE `oturum=false` + `kamera kesinti sebep=1` -> SONRA `oturum=TRUE`, kesinti
  kaydi YOK. Kullanici: "alta indirdigimde donma vs olmadi." KOK COZUM =
  `IPHONEOS_DEPLOYMENT_TARGET` 15.0 -> **16.0**.
  ⚠️ **BIR DAHA YANILMA:** `isMultitaskingCameraAccessSupported=true` olcumu BIZI 20 TUR
  YANILTTI — o AYRI kapidir ("iOS 18 SDK'ya link + UIBackgroundModes'ta voip" ile true doner).
  PiP'te kamera KULLANMA izni **deployment target**'a bakar (Apple: "Apps that have a
  deployment target earlier than iOS 16 require the multitasking-camera-access entitlement").
  ⚠️ Deployment target'i 16'nin ALTINA dusurme — arka plan kamerasi ANINDA bozulur.
- **TEST TURU 44 FIX:** "iki kutuda da beni gosteriyor" — PiP, karsi tarafin videosu HENUZ
  abone olunmadan kurulabiliyor; `aday` YEREL'e dusuyor ve turu 36 kimlik-calkanti korumasi
  onu KILITLIYORDU. Uzak video gelince pencereyi KAPATMADAN sicak gecis
  (`PipService.iosPipKaynak` -> native `kaynakDegistir`; yalniz sink tasir).
  ⚠️ YAPMA: bu gecisi `iosPipKur` ile yapma (pencere kapanir — turu 24/26 dersi).
- **SIRADAKI (kullaniciya sunuldu):** teshis/olcum kodlarinin temizligi ->
  **MEDYA MESAJLASMA (foto/video/sesli mesaj)** -> kalici grup sohbeti -> profil ->
  yayin oncesi temizlik (admin "Ses Teshis" sekmesi, BTK yer saglayici bildirimi).
- **KALDIGIMIZ YER (27 Tem 19:47):** TEST TURU 43 YAYINLANDI — android 30285412862 +
  ios 30285415219 (0a14f97), R2 apk=105227857 ipa=19142958, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. **IPA icinde MinimumOSVersion=16.0 DOGRULANDI.**
  KULLANICI TEST EDECEK — kok neden HIPOTEZ, cihazda kanitlanmadi.
- **TEST TURU 43 — iOS ARKA PLAN KAMERASININ ASIL KAPISI (Apple dokumani):**
  *"In iOS 16 and later, you can use the camera in Picture in Picture mode by enabling a
  capture session's isMultitaskingCameraAccessEnabled property. **Apps that have a deployment
  target earlier than iOS 16 require the com.apple.developer.avfoundation.multitasking-
  camera-access entitlement to use the camera in PiP mode.**"
  BIZIM `IPHONEOS_DEPLOYMENT_TARGET` **15.0** IDI -> kapi kapaliydi. Artik **16.0**.
  ⚠️ `isMultitaskingCameraAccessSupported=true` olcumu BIZI YANILTTI: o AYRI bir kapidir
  ("iOS 18 SDK'ya link + UIBackgroundModes'ta voip" ile true doner). PiP'te kamera KULLANMA
  izni DEPLOYMENT TARGET'a bakar. Ayrica Apple `enabled` icin yalniz
  `videoDeviceNotAvailableWithMultipleForegroundApps` kesintisini bastirmayi taahhut eder —
  bizim aldigimiz sebep=1 (InBackground) o degildi. Olcum tutarliydi, YORUM yanlisti.
  ⚠️ **ENTITLEMENT EKLEME**: profilde olmayan entitlement imzayi patlatir, ad-hoc IPA hic
  uretilmez (jitsi-meet #12839 ayni hatayi yasamis). Ancak Apple'a basvurup profil
  yenilendikten sonra eklenebilir.
  ⚠️ **UYGULAMA SCENE TABANLI**: Apple "If you're using scenes, UIKit will not call this
  method" — AppDelegate'e yazilacak yasam dongusu kancalari OLU KODDUR. Dogru yer
  `SceneDelegate.swift` (pbxproj'da KAYITLI, yeni dosya ekleme YOK). PiP artik oradan,
  arka plana gecmeden ONCE baslatiliyor.
  ⚠️ Kesintide kamerayi ANINDA mute etme: Apple "If you don't explicitly call stopRunning(),
  your startRunning() request is preserved" — native 1 kez `startRunning()` deniyor, Dart
  durust mute'u 1.5sn erteliyor; kurtarma tutarsa mute ATLANIR.
- **ETKI:** iOS 15'te kalmis cihazlar (iPhone 6s/7/SE1) artik uygulamayi KURAMAZ.
- **KALDIGIMIZ YER (27 Tem 18:38):** TEST TURU 41-42 YAYINLANDI — android 30279978077 +
  ios 30279981045 (6fef48a), R2 apk=105227857 ipa=19142325, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 41-42:**
  (1) **UYGULAMA-ICI YUZEN PENCERE KALDIRILDI** (kullanici: "gereksiz"). Yerine SESLI
  aramadaki ince serit (dokun -> aramaya don). `_yuzenVideo` kodu SILINMEDI — geri istenirse
  `active_call_banner.build()` icinde tek satir yeter.
  (2) **KOSE KUTUSU (WhatsApp gorunumu):** karsi taraf tam pencere + BEN sag-altta %34
  genislikte 4:3 kucuk kutu. iOS'ta native `yerelAyarla` artik UIStackView'a degil
  `callVC.view` uzerine KOSE KISITLARIYLA ekliyor; Android PiP icerigi icin
  `miniIzgara(..., ustUste: true)`.
  (3) **KOSE KUTUSUNA AYRI KARE GOZCUSU:** iOS arka planda kamerayi DURDURUR (olcum kaniti
  asagida) -> kutu 1.5sn kare gormezse DONMUS KARE yerine "Sen" yazisina duser. Kutu HEP
  durur, icerigi DURUSTTUR; Android'de kamera yasadigi icin kutu CANLI olur.
  ⚠️ YAPMA: kose kutusunu gozcusuz birakma (donmus kare geri gelir); yuzen pencereyi
  serit koymadan tamamen kaldirma (goruntulu aramada geri donus yolu kalmaz).
- **OLCUM KANITI (turu 40, Sentry — bir daha tartisma):**
  `ios pip olcum on=177 arka=75 kaynak=uzak oturum=false coklu=true` + `kamera kesinti sebep=1`
  (= videoDeviceNotAvailableInBackground). Yani coklu-gorev kamera izni DOGRU veriliyor ama
  **iPhone arka planda kamerayi yine de kapatiyor**; pencere saglikli (arka planda 3sn'de 75
  kare — karsi tarafin videosu agdan geldigi icin akiyor).
  SONUC: iPhone'da arka planda KENDI CANLI goruntun kucuk pencerede GOSTERILEMEZ (Apple).
  Uygulama-ici ve Android'de gosterilir.
- **SIRADAKI ONERI (kullaniciya sunuldu, karar bekliyor):** teshis kodlarinin temizligi ->
  **MEDYA MESAJLASMA (foto/video/sesli mesaj)** -> kalici grup sohbeti -> profil ->
  yayin oncesi temizlik (admin "Ses Teshis" sekmesi, BTK yer saglayici bildirimi).
- **KALDIGIMIZ YER (27 Tem 00:42):** TEST TURU 40 YAYINLANDI — android 30221177316 +
  ios 30221178264 (adfb558), R2 apk=105227857 ipa=19152061, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 40 — "ONCEDEN CALISIYORDU" SORUSUNUN CEVABI (git kaniti):**
  Kucuk pencerede KENDI kamerayi gosterme (`yerelId ?? uzakId`) YALNIZ 0bb2660 (turu 36) ile
  girdi; oncesi `uzakId ?? yerelId` (KARSI TARAF) idi ve CALISIYORDU. "Donuyor" sikayetleri
  turu 36'dan SONRA basladi. GERI ALINDI.
  **FIZIK:** iPhone uygulama arka plana gecince KENDI kamerayi DURDURUR; karsi tarafin
  videosu AGDAN geldigi icin AKMAYA DEVAM EDER. Kucuk pencereye kendi kamerani koymak =
  arka planda gosterilecek goruntu olmamasi = son karede donma.
  **KULLANICI GOZLEMI (teshisi kesinlestirdi):** "uygulama ICINDE kucultunce ust/alt bolme
  cok iyi calisiyor, uygulamadan CIKINCA gidiyor; Android'de ikisi de calisiyor."
   · uygulama ici pencere = BIZIM Flutter widget'imiz, uygulama ON PLANDA -> kamera yasiyor
   · iOS arka plan = SISTEM PiP'i (native), uygulama ARKA PLANDA -> kamera duruyor
   · Android PiP = uygulamanin KENDISI kucuk pencerede ("gorunur") -> kamera yasiyor
  ⚠️ YAPMA: kucuk pencere kaynagini tekrar YEREL yapma (kullanici istese bile once bu fizik
  anlatilmali); "sadece bizim goruntu" gibi belirsiz istegi UYARMADAN uygulama.
  **ACIK OLCUM:** Sentry "ios pip olcum on=.. arka=.. oturum=.. coklu=.." — `oturum=true`
  cikarsa arka planda kamera YASIYOR demektir ve kucuk pencereye WhatsApp gibi UFAK kendi
  goruntusu EKLENEBILIR; `false` ise Apple/cihaz kisitidir, kullaniciya kesin soylenecek.
- **KALDIGIMIZ YER (27 Tem 00:11):** TEST TURU 39 YAYINLANDI — android 30220063911 +
  ios 30220064859 (84066ac), R2 apk=105227857 ipa=19151962, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
  ⚠️ Kullanici "iki sorun var" demisti, ikincisini henuz tarif etmedi — SORULACAK.
- **TEST TURU 39 — DONMUS KARE ARTIK YAPISAL OLARAK IMKANSIZ:**
  KANIT: Sentry "ios pip 3sn kare=0" (yerel kaynak) + "kesinti kaydi YOK". Ama "kesinti yok"
  KAMERA CALISIYOR demek DEGIL (Apple yalniz `videoDeviceNotAvailableWithMultipleForeground
  Apps`i bastirir). Ayrica turu 32'de kullanici "karsinin goruntusu VAR, benimki YOK" demisti
  -> UZAK sink'e kare akiyor, YEREL sink'e akmiyor.
  (1) **KARE GOZCUSU** (native `gozcuBaslat`): 500ms tik, 3 tik (~1.5sn) yeni kare yoksa
  katman BOSALTILIR ("Kamera duraklatildi") + Dart'a `iosPipKareDurdu`.
  (2) **SICAK KAYNAK DEGISIMI** (`kaynakDegistir` / `PipService.iosPipKaynak`): YALNIZ sink
  tasinir; `pipController`/`callVC`/`videoView` DOKUNULMAZ -> `stopPictureInPicture`
  CAGRILMAZ -> PENCERE KAPANMAZ. Yerel kare durunca karsi tarafin videosuna gecilir; kamera
  DURUSTCE kapatilir (TAHMIN degil OLCUM).
  (3) **IKI TARAFLI OLCUM**: on/arka kare + `captureSession.isRunning` + `isMultitasking
  CameraAccessEnabled`; ON PLANA DONUNCE Sentry'e yazilir (arka planda teslim garantisiz).
  (4) **`_iosPipGuncelle` YENIDEN-GIRME KILIDI** (`_iosPipMesgul`): metot her notifyListeners
  ve saniyelik sayacla cagriliyor, `_iosPipKurulanId` await'ten SONRA yaziliyordu -> iki es
  zamanli akis `iosPipKur` cagirip native `birak()` ile PENCEREYI KAPATIYORDU (turu 24-29
  "pencere gidiyor" sikayetlerinin yapisal koku).
  ⚠️ YAPMA: gozcu esigini 1 tike dusurme; kaynak degisimini `kur()`/`birak()` ile yapma
  (pencere kapanir); yeniden-girme kilidini kaldirma; olcumu arka planda Sentry'e yollamaya
  calisma (teslim garantisiz — on planda gonder).
- **KALDIGIMIZ YER (26 Tem 22:22):** TEST TURU 38 YAYINLANDI — android 30216228929 +
  ios 30216229892 (6605a16), R2 apk=105227857 ipa=19148842, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
  ⚠️ Kullanici "iki sorun var" dedi, YALNIZ BIRINI (donma) tarif etti — ikincisi SORULACAK.
- **TEST TURU 38 — "ALTA ALINCA DONUYOR"UN GERCEK SEBEBI (Sentry kaniti):**
  · "ios coklu-gorev kamera destek=true" -> 70 kayit VAR · "ios kamera kesinti" -> HIC YOK.
  Yani **iOS kamerayi KESMIYOR**; kamerayi durduran BIZIM 900ms'lik arka plan kamera-mute
  yolumuzdu. livekit `stopCameraCaptureOnMute=true` oldugundan mute CAPTURE'I DURDURUR ve bu
  "nazik" durdurma `AVCaptureSessionWasInterrupted` URETMEZ -> ne haberimiz oluyor ne de
  "Kamera duraklatildi" etiketi cikiyor -> kucuk pencere SON KAREDE DONUYOR. Turu 36'dan beri
  pencere KENDI kamerami gosterdigi icin bu MANTIKSAL CELISKIYDI.
  **FIX:** iOS'ta PiP kuruluysa (`_iosPipKurulanId` dolu) kamera artik KENDILIGINDEN
  KAPATILMAZ. Yedek kaybolmadi — kamera gercekten durdurulursa OS soyler (turu 37 kesinti
  dinleyicisi) ve orada DURUSTCE mute edilir. Ayrica kamera her kapatildiginda
  `iosPipKareBosalt()` ile katman bosaltilir (donmus kare yerine etiket).
  **OLCUM:** PiP basladiktan 3sn sonraki kare sayisi Sentry'e yazilir ("ios pip 3sn kare=N").
  ⚠️ YAPMA: iOS'ta zamanlayiciyla kamera-mute'a geri donme (donma geri gelir); kamera
  kapatirken `iosPipKareBosalt` cagrisini atlama.
- **KALDIGIMIZ YER (26 Tem 21:55):** TEST TURU 37 YAYINLANDI — android 30215341399 +
  ios 30215342412 (26a2cf3), R2 apk=105227857 ipa=19148233 (BUYUDU=swizzle derlendi), purge OK,
  CDN birebir, backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
  ⚠️ Kullanici "iki sorun var" dedi, YALNIZ BIRINI tarif etti (donma) — ikincisi SORULACAK.
- **TEST TURU 37 — iOS ARKA PLAN KAMERA KOK NEDENI (Apple dokumaniyla kanitli):**
  Apple: *"you can enable multitasking camera access by setting this value to true **PRIOR TO
  STARTING THE CAPTURE SESSION**"*. Biz `isMultitaskingCameraAccessEnabled` bayragini ZATEN
  CALISAN session'a yaziyorduk (Dart tetikleyicilerin HEPSI startRunning SONRASI). iOS yazmayi
  KABUL ediyor, geri okuma `true` donuyor, ama **FIILEN ETKISIZ** -> arka planda capture durur,
  PiP SON KAREDE DONAR ve bayrak "true" gorundugu icin DURUST MUTE yedegi de calismaz (karsi
  taraf donmus kare gorur). flutter_webrtc bunu upstream'de HIC set etmiyor (1.4.0/1.5.2).
  **COZUM:** `GebzemKameraKanca` — `RTCCameraVideoCapturer.startCapture(with:format:fps:
  completionHandler:)` SWIZZLE edilir, ORIJINAL cagrilmadan HEMEN ONCE bayrak yazilir
  (uygulama acilisinda kurulur). Bu, "her mute/unmute YENI capture session yaratir, bayrak
  sifirlanir" sorununu da kokten kapatir. `cokluGorevKameraAc()` artik YALNIZ dogrulama.
  Ayrica `kesintileriDinle()` (AVCaptureSessionWasInterrupted) -> Dart `_iosKameraKesinti`:
  OS gercekten kestiyse kamerayi DURUSTCE mute et + PiP'te "Kamera duraklatildi" + sebep Sentry'e.
  ⚠️ YAPMA: kancayi kaldirip bayragi yalniz calisan session'a yazmaya donme; capture session'i
  stopRunning/startRunning ile "bounce" etme (WebRTC capturer disaridan durdurulmayi beklemez);
  pbxproj'a AYRI Swift dosyasi ekleme (BOM tuzagi — kod AppDelegate.swift icinde);
  coklu-gorev kamerasi icin ENTITLEMENT ekleme (imza patlar);
  deployment target'i 15->16 yapma (Apple'in "supported" kosulu OR'lu, cihazda zaten TRUE).
- **KALDIGIMIZ YER (26 Tem 20:23):** TEST TURU 34-36 YAYINLANDI — android 30212040142 +
  ios 30212041360 (0bb2660), R2 apk=105227857 ipa=19143161, purge OK, CDN birebir, sayfadaki
  saat GERCEK yukleme saati, backend DEGISMEDI (865c5f0) + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 34-36 (16 ajanlik denetim sonucu):**
  (1) **GRUP "KATIL" EKRANI**: ekran hic silinmemisti; yalniz "Android + uygulama ON PLANDA +
  WS call.incoming" yolunda cizilebiliyordu. iOS'ta WS call.incoming KOSULSUZ atlanir
  (cift-UI tuzagi — GEVSETME), Android kilitli/arka planda FCM->CallKit gelir. **`is_group`
  bayragi CallKit yukunde UC yerde dusuruluyordu**: `AppDelegate.swift` data.extra,
  `CallKitService.goster` extra, `_ayikla`. Artik ucdan uca tasinir; `main._callKitKabul`
  GRUP dalinda arama HENUZ cevaplanmaz -> `callServiceProvider.grupDavetiGoster` ile davet
  ekrani acilir; "Katil" normal `_accept` akisini calistirir. `_reject` artik
  `CallKitService.bitir` + onizleme kapatma da yapar (hayalet CallKit aramasi kalmasin).
  ⚠️ YAPMA: bu dali 1:1'e acma (CallKit'te zaten kabul edildi, ikinci onay yanlis);
  `hazirlaVeAc` hizli-acilisini 1:1'de bozma.
  (2) **ILK KAYITTA PATLAMA/IZIN GELMEMESI**: VoIP token OTURUMSUZ POST -> 401 -> `api.dart`
  interceptor TUM OTURUMU siler + `authProvider` invalidate -> GoRouter sifirdan kurulur ->
  kullanici KAYIT ekranindan LOGIN'e firlar, acik izin diyaloglari duser. Turu 33'te 5
  denemeyle 5 KAT siklasti. FIX: token POST'u oturum varsa yapilir; `/users/me/voip-token`
  ve `/users/me/fcm-token` 401'i oturumu SILMEZ. ⚠️ YAPMA: bu muafiyetleri kaldirma.
  (3) **iPHONE KUCUK PENCERE = SADECE KENDI KAMERAM** (kullanici karari): kaynak sirasi
  yerel -> uzak; ust/alt bolunme o TURDA `pipBolunme=false` ile kapatildi;
  `preferredContentSize` 120x213 (120x400 asiri uzundu, geri alindi).
  ⚠️ **BU MADDE ESKIDI (30 Tem denetimi):** `pipBolunme` turu 41-42'den beri **TRUE (ACIK)** —
  bolunme artik KOSE KUTUSU olarak ciziliyor. false yaparsan kose kutusu TAMAMEN kaybolur. **KIMLIK CALKANTISI KORUMASI**: kurulmus `_iosPipKurulanId` hala gecerli bir
  track'e isaret ediyorsa DEGISTIRILMEZ — aksi halde kaynak degisince `kur()`->`birak()`->
  stopPictureInPicture PENCEREYI KAPATIYOR (turu 24 dersi). `_yerelVideoTrackId` MUTE track
  de dondurur (arka planda oto-mute'ta id sabit kalsin diye KASITLI).
  (4) `iosKameraCanli` artik `!_iosCokluGorevDeniyor` sartini da tasir (bayrak tazeleme
  ucarken bayat deger okunup durust kamera-mute atlaniyordu -> karsi tarafta donmus kare).
- **DURUST SINIR:** iPhone'da CALARKEN kendi kamerani goremezsin (gelen arama ekranini Apple/
  CallKit cizer). Grup aramasinda kabul sonrasi "Katil" ekraninda gorunur; 1:1'de kabul eder
  etmez. Uygulama OLDURULURSE arama devam ettirilemez (OS kurali).
- **KALDIGIMIZ YER (26 Tem 18:44):** TEST TURU 32-33 YAYINLANDI — android 30208385166 +
  ios 30208386190 (7aca13b), R2 apk=105227857 ipa=19139678, purge OK, CDN birebir, sayfadaki
  saat GERCEK yukleme saati, **BACKEND DEPLOY EDILDI** (health ok), DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 32-33 (arka plan + kilit ekrani — 19 ajanlik arastirma sonucu):**
  (1) **ANDROID ONDEPLAN SERVISI** `AramaServisi.kt` + manifest `<service
  foregroundServiceType="microphone|camera">` + kanal `aramaServisiBasla/Dur` +
  `PipService.aramaServisi`. KOK: Android 14+ arka plana gecen sureci **10sn sonra DONDURUR**
  (cached apps freezer) -> WebRTC durur -> arama biter (kullanici: "5-10sn sonra bitiyor").
  Android 11+ arka plan mikrofonu icin `microphone` tipi ZORUNLU. Izinler alinmisti ama
  HICBIR servis yoktu. Baslat: `_connect` icinde `aktifKonusmaBasladi` ile ayni yer (izin
  KESIN + ekran GORUNUR). Durdur: `leave` icindeki `parkEdilen == null` kapisi + `parkiDusur`.
  (2) **KILITLI iPHONE CALMIYORDU**: VoIP token TEK denemede gonderiliyordu; PushKit kaydi
  ASENKRON oldugu icin giris aninda `getDevicePushTokenVoIP()` BOS donuyor ve BIR DAHA
  denenmiyordu -> `voip_tokens` satiri HIC olusmuyor. Her surumde DB TRUNCATE edildigi icin
  surekli tekrarliyordu. Artik istemcide 5 deneme (token alma + POST) ve sunucuda
  `voip push: VOIP TOKEN YOK` / `gonderildi` / `gonderim HATASI` loglari.
  (3) **ARANANDA KAMERA ACILMIYOR**: `_onizlemeAc()` unawaited + `_odayaBaglan` SENKRON
  okuma = iki kamera track'i (iOS'ta flutter_webrtc TEK `videoCapturer` uzerine yazar ->
  coklu-gorev bayragi YANLIS oturuma gider). Artik `_onizlemeIsi` en fazla **700ms** beklenir.
  `setCameraEnabled` try'siz idi -> istisna `_connect` catch'ine dusup `_svc.end` ile aramayi
  OLDURUYORDU; artik try/catch + "Kamera acilamadi". Zombi onizleme track'i `baslat`ta salinir.
  Gelen arama ekrani onizlemesi artik izin ISTIYOR (parite).
  (4) **iOS PiP ALT KUTU**: `preferredContentSize` 120x200 -> **120x400** (iki kutu 6:5 iken
  9:16 kaynak kirpiliyordu); `yerelAyarla` SONUC METNI dondurur (eklendi/track-yok/...),
  Dart Sentry'e yazar + bayragi sifirlayip TEKRAR dener; `localTracks` defterinden yedek
  cozumleme; `PipVideoView` bos siyah yerine "Kamera duraklatildi" etiketi (kare gelince gizlenir).
  (5) `cokluGorevKameraAc` artik sonucu GERI OKUR (kosulsuz true = yalan bayrak, durust mute
  yolunu kapatiyordu). `RoomDisconnectedEvent.reason` Sentry'e yazilir (olcum).
  ⚠️ YAPMA: ondeplan servisini izin alinmadan/arka plandayken baslatma; `_onizlemeIsi`
  await'ini kaldirma; VoIP token gonderimini tek denemeye dondurme; `yerelAyarla`yi tekrar
  sessiz-basarisiz yapma; Objective-C `NSMutableDictionary` icin Swift'te `.keys` kullanma
  (`allKeys` + String cast — iOS build bu yuzden patladi).
- **DURUST SINIR (kullaniciya soylendi):** iOS/Android'de kullanici uygulamayi OLDURURSE
  (app switcher'dan yukari atma) arama devam ETTIRILEMEZ — OS kurali, WhatsApp da yapamaz.
  Kilit ekrani ise devam EDER.
- **KALDIGIMIZ YER (26 Tem 16:40):** TEST TURU 27-31 YAYINLANDI — android 30204095501 +
  ios 30204096587 (eb29925), R2 apk=105227813 ipa=19138192, purge OK, CDN birebir, sayfadaki
  saat GERCEK yukleme saati, backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 27-31 (31 AJANLIK DENETIMLE BULUNAN KOKLER):**
  (1) **SIYAH PATLAMA KOKU**: video renderer'i if/else dallarinda YER DEGISTIRIYORDU (tam ekran
  dali -> kucuk pencere dali) -> element yeniden kurulur -> texture sifirdan. Artik iki video da
  anahtarli `AnimatedPositioned` icinde, YALNIZ dikdortgen animasyonla degisir (`_videoKutu`,
  260ms easeOutCubic). GRUPTA ayni kok: tile anahtari `video.sid` idi — sid YAYINLANANA KADAR
  NULL -> `mediaStreamTrack.id`.
  (2) **KARSI TARAF MUTE OLUNCA KUTU SILINIYORDU** (`_remoteVideo` muted'da null donuyordu) ->
  buyuk goruntu BANA zipliyor + donuste patlama. Artik mute track de doner, kutu KALIR, ustune
  `BeklemedeOrtusu` biner ("Kamera duraklatıldı" — WhatsApp yazisi; hold ise "Beklemede").
  (3) **HIZ**: 1:1'de `adaptiveStream`/`dynacast` KAPALI (grupta acik); gelen-arama onizleme
  kamerasi kapatilmadan controller'a DEVREDILIR (`baslat(hazirKamera:)`).
  (4) **CALLKIT KABULUNDE EKRAN ANINDA**: `hazirlaVeAc()` — answer REST'i beklemeden "Baglaniliyor"
  ekrani acilir (eskiden once sohbet listesi gorunuyordu). Navigator bekleme adimi 100ms -> 16ms.
  (5) **iOS PiP**: `uygun` sartindan `ekranGorunur` KALKTI (kucultulmus aramada PiP hic acilmiyordu);
  resumed'da `iosPipDurdur` KOSULSUZ; native `durdur()` kosulsuz + `iptalIstendi`; `didStart`
  uygulama ON PLANDAYSA pencereyi aninda kapatir; UIStackView ile ust/alt bolunme (`yerelAyarla`,
  kimlik SADECE uzak track); uzak video yoksa KENDI kameram ana kutu.
  (6) **iOS ARKA PLAN KAMERA BAYRAGI**: `isMultitaskingCameraAccessEnabled` capture SESSION'a
  yazilir; livekit `stopCameraCaptureOnMute=true` her kamera ac/kapa YENI session yaratip bayragi
  sifirliyordu -> `iosArkaPlanKamerayiTazele()` baglantida + kamera her acildiginda + arka plana
  GECMEDEN ONCE ('inactive') yeniden uygular.
  (7) **••• MENUSU ACIKKEN EKRAN KILITLENMESI**: `_sheetAcik` isaretlenmiyordu -> yanlis pop,
  kullanici bos ekranda kaliyor + SONRAKI arama ekrani hic acilmiyordu.
  (8) **YUZEN PENCERE SURUKLEME**: delta BUILD'deki bayat `pos`a ekleniyordu -> parmagin gerisinde
  kaliyordu. Artik guncel `_pos` + kenara 180ms yapisma.
  (9) Canli yayin ekranlarinda `pipModu` sade gorunumu YALNIZ Android (bayat bayrak iOS'ta
  kontrolsuz/cikissiz ekran = "ekran gidiyor").
  (10) Sohbette "Aramaya don" HEADER -> MESAJ BALONU (`_AktifAramaBalonu`).
  ⚠️ YAPMA: video renderer'i kosullu dallarda farkli konumlarda cizme; tile anahtarina sid koyma;
  `_remoteVideo`/`_katilimciVideosu`a `!muted` sarti geri koyma; `_iosPipGuncelle` `uygun` sartina
  `ekranGorunur` koyma; resumed'daki `iosPipDurdur`a `pipModunda` sarti koyma; arka plan kamera
  bayragini tek seferlik yapma; grupta adaptiveStream/dynacast kapatma; yeni sheet/dialog eklerken
  `_sheetAcik` + `whenComplete` unutma.
- **KALDIGIMIZ YER (26 Tem 13:13):** TEST TURU 24 YAYINLANDI — android 30197469551 +
  ios 30197470722 (3c52912), R2 apk=105211301 (SHA 716d9c6d) ipa=19134680, purge OK, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 23-24 (arama deneyimi):** (1) YUZEN PENCERE yalniz `minimized && !ekranGorunur`
  iken cizilir (arama ekraniyla UST USTE binme hatasi). (2) CALARKEN kendi kameram TAM EKRAN
  (`kendimBuyuk`), karsi taraf acinca buyuk ONA gecer. (3) **iOS ARKA PLAN KAMERA**: kamera-mute
  900ms ERTELENIR; PiP basladi + `_iosArkaPlanKamera` (isMultitaskingCameraAccessEnabled)
  varsa HIC mute edilmez -> karsi taraf gormeye devam eder; destek yoksa mute (bulanik
  "Beklemede"). (4) **KUCUK PENCERE 2 KISI UST/ALT** (miniIzgara) + iOS native PiP'te IKI video
  (`GebzemPip.kur(trackId:, yerelTrackId:)`, `pipAddStacked`, kurulanId = "uzak|yerel").
  (5) **PiP'ten DONUS HIZI**: CallScreen PiP dalinda bos Scaffold YERINE `Offstage` — renderer'lar
  canli kalir (eskiden agac sifirdan kuruluyordu = yavas cizim). (6) Grup tile'lari 180ms hafif
  belirme. (7) **BILDIRIM SERIDI** `controller.bildirim` (5sn, yenisi eskisinin yerine):
  "X sessize alındı/sesini açtı/kamerasını kapattı-açtı", grupta "X katıldı/ayrıldı".
  (8) Kucuk ekranlarda border/golge KALDIRILDI.
  ⚠️ YAPMA: PiP dalinda tekrar bos Scaffold dondurme (yavas cizim geri gelir); iOS'ta kamerayi
  PiP baslamadan mute etme (karsi taraf goruntuyu kaybeder); miniIzgara'da 2 kisiyi tekrar
  yan yana yapma; yuzen pencereyi `ekranGorunur` kontrolsuz cizme.
- **KALDIGIMIZ YER (26 Tem 12:03):** TEST TURU 22 YAYINLANDI — android 30195338773 +
  ios 30195339779 (4f04497), R2 apk=105211301 ipa=19131169, purge OK, backend deploy + health ok,
  DB temiz. KULLANICI TEST EDECEK. **KALAN IS:** sohbetteki "aramaya don" kaydi HEADER yerine
  MESAJ BALONU olarak istendi (su an ust serit).
- **TEST TURU 22 (kok fixler):** (1) **"KULLANICI ZATEN ARAMADA" KOK COZUM** —
  `internal/calls/mesgul.go` `gercektenMesgul()`: DB 'active'/'joined' dese bile LiveKit'e
  `ListParticipantIdentities` ile SORULUR; kisi odada degilse satir OLU sayilir
  (`oluAramaTemizle`: katilimci 'left', oda bossa arama 'ended' + call.ended) ve kisi MUSAIT
  kabul edilir. `Add` (hem "zaten aramada" hem "baska gorusmede") ve `Start` (1:1 'active')
  yollarinda. LiveKit'e ULASILAMAZSA mesgul kabul (canli gorusme bolunmesin).
  (2) **ANINDA KAMERA**: giden goruntulu aramada kamera odaya BAGLANMADAN acilir
  (`_onizlemeAc` -> `kendiGoruntum`), baglantida AYNI track `publishVideoTrack` ile yayinlanir
  (canli yayin P1 deseni); yayinlanmadan biterse `_onizlemeBirak` kapatir.
  (3) **GRUP IZGARA**: sesli grup da ayni izgarayi kullanir (eski Wrap SILINDI — "hepsi
  gorunmuyor"); kamerasiz katilimci ORTADA daire avatar + ALTINDA renkli ad.
  ⚠️ YAPMA: mesgulluk kararini tekrar SADECE DB'ye baglama; LiveKit hatasinda kisiyi musait
  sayma; onizleme track'ini publish edildikten sonra stop etme (yayin kesilir).
- **KALDIGIMIZ YER (26 Tem 11:17):** TEST TURU 21 YAYINLANDI — android 30193969124 +
  ios 30193969987 (e101c8f), R2 apk=105211305 ipa=19129943, purge OK, backend deploy + health ok,
  DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 21 (WhatsApp grup-arama deneyimi + uyarilar):**
  (1) **BULANIK "Beklemede"** (`beklemede_katmani.dart`): uzak katilimcinin video track'i MUTED
  ise SON KARE blur + "Beklemede" (1:1 tam ekran + grup tile). `_beklemedekiVideo(p)` = subscribed
  && muted && track!=null.
  (2) **GRUP DAVET EKRANI**: gelen arama katmani `isGroup` ise WhatsApp duzeni — kendi kamera
  ONIZLEMESI (LocalVideoTrack, izin varsa) + kamera/mik ON-AYAR dugmeleri + "Yok say / Katil".
  Secim aramaya tasinir: `baslat(b, micAcik:, kameraAcik:)`. 1:1 ekrani AYNEN korundu.
  (3) **SOHBET KAYITLARI** (`internal/calls/grup_sohbet.go`): `call:group:invite:<id>` /
  `call:group:end:<id>` sistem mesajlari — kalici grupta grup sohbetine, ANLIK grupta arayanla
  olan DIREKT sohbete (grup sohbeti UI'si yok). Flutter `_CallLogChip` bunlari cizer.
  (4) **SOHBET UST SERIDI**: arama kucultulmusken "Aramada · Geri dönmek için dokun".
  (5) **PIL/BAGLANTI UYARILARI**: `battery_plus` + LiveKit veri kanali (`{"t":"batt","v":n}`,
  1 dk'da bir) -> `karsiPil`; `ParticipantConnectionQualityUpdated` yerel+UZAK -> `karsiKalite`;
  RoomReconnecting/Reconnected. Tek satir `uyariMetni` (oncelik: yeniden baglanma > baglanti > pil).
  ⚠️ YAPMA: `_beklemedekiVideo`u muted olmayan track'e acma (canli video bulaniklasir);
  grup davet onizlemesini kabul sonrasi kapatmayi unutma (kamera cakismasi);
  `call:group:*` sistem mesajlarini 1:1 arama kaydi (`call:missed:*`) ile karistirma.
- **KALDIGIMIZ YER (26 Tem 10:46):** TEST TURU 20 YAYINLANDI — android 30193050269 +
  ios 30193051177 (86e6717), R2 apk=105112813 ipa=19114885, purge OK, CDN birebir, backend
  deploy + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 20:** (1) **GSM ARAMA BEKLETME (Android)**: `READ_PHONE_STATE` izni +
  `TelefonDurumu.kt` (API31+ TelephonyCallback.CallStateListener / altinda PhoneStateListener)
  -> kanal olayi `gsmDurum` -> `PipService.gsmAramada` -> controller `beklemeyeAl` (medya durur,
  arama SUNUCUDA OLMEZ; telefon bitince kaldigi yerden devam). Izin verilmezse ozellik SESSIZCE
  kapali. iOS'ta ayni isi CallKit yapar (turu 18). Arama basinda `gsmDinle(true)`, bitince false.
  (2) **"Arama beklemede" paneli** (WhatsApp duzeni): beklemedeyken alt kontroller yerine
  "Aramayi bitir" / "Devam et".
  (3) **iOS KUCUK PENCERE AYARDAN BAGIMSIZ**: otomatik PiP telefon Ayari + Dusuk Guc Modu'na
  bagliydi; artik uygulama arka plana GECERKEN (inactive/paused) `GebzemPip.baslat()` ->
  `startPictureInPicture()` ELLE cagriliyor (arama + yayinci + izleyici ekranlari).
  (4) **OLU KATILIMCI**: webhook `participant_left` ANINDA islenir — 1:1 arama BITER, grupta
  katilimci 'left' + `call.participant.left`; kimse kalmadiysa arama biter; `participant_joined`
  -> 'joined' geri (reconnect). Boylece "iPhone kapatilinca karsida ekran donuyor / sonra
  'zaten aramada'" sorunu biter.
  ⚠️ YAPMA: GSM dinleyicisini izin olmadan zorlama (crash/ANR riski, sessiz kalsin);
  `iosPipBaslat`i on plandayken (resumed) cagirma (Apple reddeder); webhook'ta 1:1 icin
  `participant_left`i yok sayma (donma geri gelir).
- **SORU-CEVAP (kullaniciya):** bekletme MALIYETI ~sifir — beklemedeki arama SFU'da medya
  TASIMAZ (disable), yalniz sinyal baglantisi durur. Binlerce bekleyen arama sunucuyu zorlamaz;
  yuk KONUSAN aramalardadir.
- **KALDIGIMIZ YER (26 Tem 09:30):** TEST TURU 19 YAYINLANDI — android 30190799515 +
  ios 30190800266 (e2198ef), R2 apk=105112781 ipa=19111472, purge OK, CDN birebir, backend +
  LiveKit deploy, health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 19 (ANLIK KAPANIS):** (1) **LIVEKIT WEBHOOK** (yeni): `livekit.yaml` ->
  `webhook: api_key: <LIVEKIT_KEYS adi>, urls: [http://127.0.0.1:8080/livekit/webhook]`
  (LiveKit HOST aginda, api 8080'i host'a aciyor). Backend: `internal/livekit/webhook.go`
  (HS256 JWT dogrulama + govde SHA-256 ozeti; harici bagimlilik YOK) + `internal/calls/webhook.go`
  (`POST /livekit/webhook`, auth middleware DISINDA). KURAL: oda GERCEKTEN bosalinca
  (`participant_left` + numParticipants==0 VEYA `room_finished`) `calls` ('active') ve `streams`
  satirlari ANINDA 'ended'. 'ringing' fazina DOKUNULMAZ (gecmis "Cevapsiz" semantigi).
  DOGRULANDI: gecerli imza 200 / sahte 401 + LiveKit logu "sent webhook room_finished 1.7ms".
  (2) Sohbet basligindaki "Sesli aramada" YAZISI kaldirildi; arama ikonlari KILITLENMEZ (yalniz
  renk ipucu) + arama bitince durum ANINDA tazelenir (kullanici "kapattim hemen arayamiyorum").
  (3) YUMUSAK KAPANIS: arama/yayin ekranlari 220ms solma + %94 kuculme ile kapanir (_kapanisSarmal).
  (4) Oda kapatma zaman asimlari 3sn -> 1.2sn (yeni arama kilit sirasinda beklemesin).
  ⚠️ YAPMA: webhook'ta 'ringing' aramalari kapatma (cevapsiz gecmisi bozulur); tek katilimci
  ayrilinca (numParticipants>0) arama kapatma (mobil ag kopmasi aramayi oldurur); webhook ucunu
  auth middleware'e sokma (LiveKit Bearer token gondermez, kendi JWT'siyle gelir);
  livekit.yaml'daki webhook.api_key'i LIVEKIT_KEYS'teki ANAHTAR ADINDAN farkli yazma.
- **KALDIGIMIZ YER (26 Tem 08:51):** TEST TURU 18 YAYINLANDI — android 30189717769 +
  ios 30189718708 (508208a), debug imza YOK, R2 apk=105096401 ipa=19108493 index=6437, purge OK,
  CDN birebir, backend deploy + health ok, DB temiz. KULLANICI TEST EDECEK (ozellikle ARAMA
  BEKLETME + iOS CallKit hold).
- **TEST TURU 18:** (1) **KONUK SINIRI 4** (yayinci dahil): `STREAM_MAX_GUESTS` varsayilan **3**
  konuk; 0 = sinirsiz. IZLEYICI sinirsiz KALDI (STREAM_MAX_VIEWERS=0).
  (2) **ARAMA BEKLETME (call waiting + hold):**
  · BACKEND: mesgul kullaniciya ikinci arama ARTIK ILETILIR — `Start` 'active' ise
    `waiting:true` ile WS/push gonderir (yalniz callee'nin telefonu ZATEN CALIYORSA eski 409).
    Yeni uc `POST /calls/{id}/hold {on}` -> karsi tarafa WS `call.held`.
  · CONTROLLER: `ParkEdilenArama` (oda+listener+sure+mic/cam) · `parkEt()` (medya durur, ODA
    ACIK kalir: LiveKit `RemoteTrackPublication.disable()` + yerel mic/kam kapali) · `devamEt()`
    (sure KALDIGI YERDEN `_sureBaz`, ses birimi `_sesiAc(true)` ile tazelenir) · `parkiDusur()`
    · `beklemeyeAl(callId,on)` (CallKit/GSM hold, id-farkindalikli) · aktif arama bitince
    beklemedekine 500ms sonra OTOMATIK donus.
  · UI: gelen arama katmani `waiting` ise UC dugme; uygulama genelinde turuncu
    "Beklemede: X — dokun ve gec" seridi (✕ bitirir); arama ekraninda "⏸ Beklemede" rozeti.
  · iOS: `IOSParams.supportsHolding=true` + `maximumCallsPerCallGroup=2` + AppDelegate VoIP
    yolunda `data.supportsHolding = true` -> "Beklet ve Kabul / Bitir ve Kabul / Reddet"
    ekranini SISTEM cizer; `CallEventActionCallToggleHold` artik ISLENIYOR.
  ⚠️ **GERI ALMA (iOS beklet sorun cikarirsa):** callkit_service.dart `IOSParams.supportsHolding`
  + AppDelegate.swift `data.supportsHolding` -> **false**. (Eskiden false idi cunku hold olayi
  ISLENMIYORDU; artik medya durdurma + ses birimi tazeleme var.)
  ⚠️ YAPMA: `answer(zorla:)` kapisini gelisiguzel acma (yalniz beklet/bitir-kabul yolunda);
  `parkEt` sonrasi eski odayi `leave` ile kapatma (park BITMEZ, sunucuda 'active' kalir);
  `baslat()`te `parkEdilen`i sifirlama (beklemedeki arama kaybolur); oda/canli yayin
  ekranlarinda ikinci aramayi gosterme (ses cakismasi — `aktifAramaVar` kapisi).
- **KALDIGIMIZ YER (26 Tem 08:15):** TEST TURU 17 YAYINLANDI — android 30188758448 +
  ios 30188759300 (9c00366), debug imza YOK, R2 apk=105014357 ipa=19103992 index=6442, purge OK,
  CDN birebir, backend deploy + health ok (yeni uc /users/{id}/presence canli), DB temiz.
- **TEST TURU 17 FIXLERI:** (1) **IZLEYICI SINIRI KALDIRILDI**: STREAM_MAX_VIEWERS varsayilani
  300 -> **0 (SINIRSIZ)**; watch/heartbeat/invite kapasite kontrolleri `maxIzleyici > 0` sartli;
  LiveKit odasi max_participants=0. (Konuk siniri turu 16'da kalkmisti.) (2) **KUCUK PENCERE
  IZGARASI** `mobile/lib/features/calls/mini_izgara.dart`: 1 tam · 2 SOL/SAG · 3 ustte 2 + ALTTA 1
  TAM GENISLIK · 4 CEYREK (2x2); en fazla 4 kutu (+N rozeti); kutular alani DOLDURUR (bosluk yok),
  video yoksa harf avatari. Kullanan: arama sistem PiP + uygulama-ici yuzen pencere
  (`ActiveCallController.miniKatilimcilar` — uzaklar/grupta aktif konusan once, BEN en sonda),
  canli yayin yayinci PiP'i (yayinci+konuklar) ve izleyici PiP'i (yayinci+konuklar, kimlik kapisi
  korunur). (3) **KISI ARAMA DURUMU**: yeni uc `GET /users/{id}/presence` ->
  {in_call, call_type, in_stream} (1:1 + grup 'joined' + yayincilik). Sohbet basliginda
  "🎙 Sesli aramada / 🎥 Goruntulu aramada / 🔴 Canli yayinda"; ilgili ikon YESIL-AKTIF digeri
  PASIF; mesgulken dokunus arama BASLATMAZ, durumu soyler; 15sn'de tazelenir.
  ⚠️ YAPMA: miniIzgara'ya en-boy koruma ekleme (kucuk pencerede bosluk kotu duruyor); PiP
  izgarasinda 4'ten fazla kutu cizme (okunmuyor); presence ucunu liste ekranlarinda (sohbet
  listesi/arama sonuclari) kisi basina cagirma (N+1 sorgu) — tekil sohbet ekraninda kalsin;
  maxIzleyici kontrollerini `> 0` sartsiz geri koyma (sinir geri gelir).
- **KALDIGIMIZ YER (26 Tem 07:46):** TEST TURU 16 YAYINLANDI — android 30187982072 +
  ios 30187982757 (c2c7b3b), debug imza YOK, R2 apk=104997973 (SHA effad2c9) ipa=19099167
  index=6444, purge OK, CDN birebir, backend deploy + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 16 FIXLERI:** (1) **KONUK SINIRI KALDIRILDI** (kullanici karari): maxKonuk sabiti (4)
  -> `var maxKonuk = konukSinirOku()` env `STREAM_MAX_GUESTS` (0/tanimsiz = SINIRSIZ); Lua
  `max <= 0` ise kapasite kontrolu ATLANIR. Pratik tavan cx33'te ~5-8 video yayinci (kod
  engellemez). (2) **IZGARA SON SATIR TAM GENISLIK:** son satirda TEK kisi kalirsa yarim
  genislikte solda durmaz, TAM GENISLIK (yatik) olur — `yayinIzgara` (canli yayin) ve
  `_grupVideoIzgara` (grup aramasi; GridView.count -> elle satir/sutun, 4 satir ustu kaydirma
  KORUNDU). 3 kisi: ustte 2 + altta 1 genis (WhatsApp duzeni). (3) **GERI SAYIM SADE:** karartma
  katmani + mor golge + pop animasyonu KALDIRILDI; sayarken TUM arayuz gizli (yalniz kamera +
  ortada beyaz rakam). ⚠️ YAPMA: geri sayima golge/karartma/animasyon geri koyma; izgarada son
  satir tek kisiyi tekrar yarim genislige dusurme; maxKonuk'u tekrar SABIT yapma (env kalsin).
- **KALDIGIMIZ YER (26 Tem 07:11):** TEST TURU 15 YAYINLANDI (yayin arka plan/PiP + yayin sonrasi
  ARAMA DUSMESI kritik fix), KULLANICI TEST EDECEK. android 30187028051 + ios 30187028788 (d468ef8),
  debug imza YOK, R2 apk=104997973 (SHA farkli!) ipa=19101212 index=6540, purge OK, CDN birebir,
  backend degismedi + health ok, DB temiz.
- **TEST TURU 15 FIXLERI:** (1) **KRITIK — yayin sonrasi arama duser:** izleyici ekraninda yayin
  bitince MODAL DIALOG aciliyor, `_cik()` ancak "Tamam"da calisiyordu -> `yayin_<id>` MESGUL
  MUHAFIZI askida kaliyor -> gelen arama `answer()` null -> CallKit bitir + end -> ARAYANIN HATTI
  ANINDA DUSUYORDU. Artik yayin bitince muhafiz+oda+ekran ANINDA birakilir, bilgi kok SnackBar.
  (2) **Yayinda arka plan/PiP:** yayin ekranlarinda PiP davranisi HIC YOKTU -> yayinci alta alinca
  kamera capture durur, IZLEYENLER DONMUS KARE gorurdu. PipService yeniden yapilandirildi (kanal
  handler TEK yerde; `pipModu` ValueNotifier; `pipIzinli(sahip:)` sahiplik korumasi; dugmeleriGoster),
  MainActivity `setPipDugmeler` (yayin PiP'inde arama dugmeleri gizli, BOS liste acikca set edilir),
  AppDelegate GebzemPip.kur uzak track yoksa YEREL track'e duser (iOS yayincisi kendi kamerasi),
  yayinci+izleyici ekranlarina PiP izni + PiP'te SADE gorunum, PiP YOKSA arka planda kamera
  DURUSTCE mute (donmus kare yerine avatar) + donuste geri ac.
  ⚠️ YAPMA: yayin bitisini tekrar MODAL DIALOG'a baglama (mesgul muhafizi askida kalir, aramalar
  duser); PipService kanal handler'ini tekrar tek sahibe (controller) verme (yayin ekrani dinleyemez);
  `pipIzinli`yi sahipsiz cagirma (yayin PiP'ini arama controller'i kapatir); yayinci arka plan
  kamera-mute'unu kaldirma (izleyicide DONMUS kare geri gelir).
- **BILINEN DAVRANIS:** yayin/oda ekrani ACIKKEN gelen arama "mesgul" sayilir (ses cakismasi
  karari) — telefon CALMAZ. Istenirse ayri faz: "yayin izlerken arama calsin, kabulde yayindan cik".
- **TEST TURU 14 SURUMU YAYINLANDI (26 Tem 06:11) — KULLANICI TEST EDECEK:** android 30185398548 +
  ios 30185399247 (ae26a76), debug imza YOK, R2 apk=104997973 ipa=19096351 index=6570, purge OK,
  CDN birebir, backend deploy + health ok, DB temiz. ARAMA KUCUK EKRAN (PiP) + HAT DUSME:
  (1) **1:1'de PiP gelmiyordu** — `_pipIstenir` kapisi `(_camOn || _uzakVideoVar())` idi; arka plana
  inince kamera OTO-MUTE oluyor (_camOn=false) ve karsi taraf da alta alininca uzak video mute ->
  izin kapaniyordu (grupta 3+ kisiden biri hep acik oldugu icin sorun gorunmuyordu). Artik
  `goruntuluMu` (arama tipi video VEYA biri kamera acmis). (2) **PiP'te buton yoktu** — MainActivity
  RemoteAction (mikrofon ac/kapa + kapat) -> broadcast -> 'pipEylem' -> toggleMic/leave; ikon durumla
  guncellenir (setMicDurum); kendi vektor ikonlarimiz res/drawable/pip_*.xml. (3) **Pencere kucuktu**
  — PiP orani 9:16 -> 3:4; uygulama-ici yuzen pencere 116x168 -> 152x232 (mic+HOPARLOR+kapat 36px).
  (4) **PiP'te kendi kameram kapaniyordu** — lifecycle 'paused' pipDegisti'dan once gelebiliyor;
  kamera-mute 900ms ERTELENIR, PiP baslarsa hic yapilmaz. (5) **PiP icerigi UYGULAMA KATMANINDA**
  (AktifAramaBanner/MaterialApp.builder, tam ekran) -> arama kucultulup baska sayfadayken de PiP'te
  karsi taraf gorunur; CallScreen PiP dalinda renderer YOK. Arama bitince PiP kapanir (moveTaskToBack).
  (6) **HAT DUSME (backend)** — uygulama zorla kapatilinca End gelmiyor, satir 2 SAAT 'active'
  kaliyordu; grup satirini pairwise temizlik (is_group=false) hic kapatmiyordu -> grup baslatan
  2 saat "baska gorusmede". Sweeper artik LiveKit'e soruyor (ListRoomNames + ListParticipants):
  odasi YOK/BOS olan >=90sn 'active' aramalar kapatilir + call.ended. (7) Goruntulu aramada
  HOPARLOR varsayilan ACIK. ⚠️ YAPMA: `_pipIstenir`e tekrar `_camOn/_uzakVideoVar` sarti koyma
  (1:1 PiP olur); PiP icerigini CallScreen'e geri tasima (kucultulmus aramada PiP bozulur);
  kamera-mute gecikmesini kaldirma (PiP'te karsi taraf seni goremez); olu-arama sweeper'inda
  LiveKit hatasinda arama KAPATMA (yanlis pozitif); 90sn yas sinirini dusurme.
- **KALDIGIMIZ YER (26 Tem 06:11):** TEST TURU 14 YAYINLANDI (arama PiP/yuzen pencere + hat dusme,
  7 fix), KULLANICI TEST EDECEK. Onceki turda test turu 13 (canli yayin 6 fix) yayinlandi — o turun
  geri bildirimi de bekleniyor. Her sey commit+push, backend deploy + health ok, DB temiz.
  BEKLEYEN/ACIK: (1) kullanici test turu 13 + 14 geri bildirimi. (2) CANLI YAYIN MINIMIZE = AYRI FAZ
  (arama minimize/PiP test turu 14'te tamamlandi; YAYIN icin ayni desen uygulanabilir).
  (3) iOS GERCEK arka plan sistem PiP telefon Ayari + Dusuk Guc Modu'na bagli (bizim kod disi).
  Rutin: yeni surumde build->R2->purge->boyut dogrula->DB TRUNCATE->health. gh token .env.infra
  GITHUB_TOKEN, CF zone a8af9ee51c2c3ed70cc30d705038abfd, r2put.js scratchpad'de (her oturumda
  yeniden yaz — ⚠️ .env.infra'da satir-sonu YORUMLARI var, deger okurken `\s+#.*` KES).
- **TEST TURU 13 SURUMU YAYINLANDI (26 Tem 05:25) — KULLANICI TEST EDECEK:** android 30184022784 +
  ios 30184023533 (83ddcb4), debug imza YOK, R2 apk=104979437 ipa=19095161 index=6354, purge OK,
  CDN birebir, backend deploy + health ok, DB temiz. CANLI YAYIN 6 FIX:
  (1) **BAYAT NABIZ** (kok): nabiz UCARKEN konuk durumu degisirse donen yanit kosulsuz uygulaniyordu ->
  izleyiciyi konukluktan DUSURUYOR (hayalet slot), yayincida yeni konugun tile'i 15sn kayboluyordu.
  `_konukEpok` nesli (istek oncesi yakala, yerel degisiklikte artir, nesil degistiyse UYGULAMA).
  (2) **HAYALET KONUK SLOTU:** app-kill sonrasi geri donen konuk sunucuda `:guests` uyesi kalir,
  nabiz attigi icin sweeper ASLA dusurmez -> 4 slottan biri yayin boyu kilitli. Ekran acilisindaki
  guest_ids'te kendi id'im varsa (>=2. nabiz) slot BIRAKILIR. (3) **KACAN guest.accepted onarimi**
  (elle ✕ Ayril sonrasi geri sokmaz — `_elleAyrildim`). (4) **SESLI konuk kamera acamiyordu**
  (pill izin istemiyordu). (5) **KONUK ADLARI** izleyicide "Konuk" yerine gercek ad (guest.joined +
  backend watch `guest_list`). (6) **app-kill sonrasi eski yayin ~2 dk yeni yayini engelliyordu**
  (409'da stream_id doner -> "Kapat ve baslat" onayi). ⚠️ YAPMA: nabiz mutabakatini epok kapisi
  OLMADAN uygulama; hayalet-slot temizligini ilk nabizda yapma (gercek kabul yarisir); auto-promote'u
  `_elleAyrildim` guard'siz birakma; guest_list'i heartbeat'e tasima (300 izleyici x 15sn DB yuku).
- **TEST TURU 12 SURUMU YAYINLANDI (23 Tem 21:19) — KULLANICI TEST EDECEK:** android 30032129115 +
  ios 30032132733 (71a0e36), debug imza YOK, R2 apk=104979441 ipa=19092619, purge OK, CDN birebir,
  DB temiz, health ok. FIX: yayinIzgara TAM-BOY (Expanded-doldur, yarim-genislik x tam-yukseklik ~1:4.3)
  KOTU gorunuyordu (9:16 goruntu `cover` ile korkunc kirpiliyordu) -> **LayoutBuilder ile tile'lar
  DOGAL 9:16 PORTRE en-boy korur + ORTALANIR + yukseklige sigmazsa KUCULUR**. 2 kisi -> yarim-genislik
  x 9:16, ekran ortasinda (UZAMAZ). Seamless 2px koyu bosluk. ⚠️ YAPMA: yayinIzgara'yi tekrar Expanded-
  doldur (tam-boy) yapma; en-boyu bozma (kirpma artar); border/ClipRRect ekleme.
- Onceki: **TEST TURU 11 SURUMU YAYINLANDI (23 Tem 02:17):** android 29965135036 +
  ios 29965136743 (dc70108), debug imza YOK, R2 apk=104979437 ipa=19093092, purge OK, CDN birebir,
  backend deploy + health ok, DB temiz. **CANLI YAYIN COKLU-KONUK:** tek-konuk (Redis STRING/SETNX/
  cadScript) -> COKLU (`stream:{id}:guests` SET, **maxKonuk=4**); guestAddScript atomik kapasite Lua
  SADD; konukDusur SREM (uye-bazli); GuestRefresh SISMEMBER; is_guest=guestSet[id]; Watch/Heartbeat
  **guest_ids DIZI** (guest_id DEGIL); sweeper SMEMBERS dongusu; endStream `:guests`. FRONTEND:
  yayinSplitAlani(ust/alt) SILINDI -> **yayinIzgara(tiles)** (2 kisi YAN YANA/sol-sag, 3-4 grid,
  SEAMLESS border/ClipRRect YOK); SplitVideoPaneli avatarHarf (SESLI konuk avatar tile); broadcast
  `_konuklar` Map + _konukTile(id,ad) + _konukVideoBul; viewer `_aktifKonuklar` Set + ilkKonukIds +
  _konukOl KAMERA OPSIYONEL (mik zorunlu, kamerasiz SESLI katil, _kameramAcik) + pill kamera ac/kapa;
  live_start_screen geri sayim daire KALDIRILDI -> tam ortada 140px rakam (border yok).
  ⚠️ YAPMA: guests SET'i STRING yapma; yayinIzgara'ya border/ClipRRect ekleme; _konukOl kamerayi
  ZORUNLU yapma (sesli konuk bozulur); guest_ids'i guest_id'e dondurme; maxKonuk'u cx33'te cok buyutme
  (yayinci+4 konuk video publish = SFU yuku). kimlik-kapisi (bayat kendi id tile uretmez) KORUNSUN.
- Onceki: **TEST TURU 10 SURUMU YAYINLANDI (22 Tem 20:16):** android 29939980308 +
  ios 29939982616 (a710627), debug imza YOK, R2 apk=104963053 ipa=19087218, purge OK, CDN birebir,
  DB temiz, health ok. ASIL FIX: **UYGULAMA-ICI SURUKLENEBILIR YUZEN VIDEO** (active_call_banner.dart
  ConsumerStatefulWidget) — goruntulu aramada arama ekranindan cikip gezinince karsi tarafin canli
  videosunu gosteren mini pencere (116x168, dokun->don, mic toggle + kapat butonu, grupta aktif
  konusan, avatar yedegi). controller.bantVideo getter (uzak !muted / activeSpeakers). %100 Flutter
  kontrolu -> iOS Dusuk Guc Modu/ayar BAGIMSIZ, crash yok (arama==null->render durur). SESLI arama
  eski yesil bant. iOS PiP REGRESYON FIX: _iosPipGuncelle cokluGorevKamera artik iosPipKur SONRASI +
  bloklamayan (fire-and-forget, _iosCokluGorevDeniyor guard) — agir capture-reconfig PiP kurulumunu
  geciktirip auto-enter'i kaciriyordu.
  ⚠️ KRITIK OGRENME: iOS SISTEM PiP GUVENILIR YAPILAMAZ (arastirma kaniti) — auto-PiP telefon
  Ayari "PiP'i Otomatik Baslat" + Dusuk Guc Modu KAPALI sartina bagli (kullanici "sarj azken gelmedi"
  = Dusuk Guc Modu). ASIL COZUM uygulama-ici yuzen video (kontrolumuzde). YAPMA: bantVideo'yu yerel
  kameraya cevirme (karsiyi gormek istiyor); yuzen video renderer'ini track guard'siz cizme (crash);
  cokluGorevKamera'yi tekrar iosPipKur ONUNE await koyma (regresyon). Canli yayin minimize AYRI faz.
- Onceki: **TEST TURU 9 SURUMU YAYINLANDI (22 Tem 01:13):**
  android 29871829312 + ios 29871831125 (headSha 3dcdf3b), iOS Swift DERLEME GECTI (IPA
  19082928->19085286 buyudu=yeni native kaniti), debug imza YOK, R2 apk=104946669 ipa=19085286,
  purge OK, CDN boyut birebir, index saati BELIRGIN, health ok, DB temiz. FIXLER:
  (1) iOS PiP'te KENDI KAMERA CANLI: AppDelegate.cokluGorevKameraAc ->
  FlutterWebRTCPlugin.sharedSingleton.videoCapturer.captureSession.isMultitaskingCameraAccessEnabled
  (iOS16+ property, ENTITLEMENT YOK -> imza riski YOK; iOS16-17 destek cihaza bagli, desteksizse
  false->avatar yedegi). PiP delegate didStart/Stop/failed -> pipCh.invokeMethod -> pip_service.iosDinle
  -> controller pipModunda/_iosPipBasarisiz. Arka planda _iosArkaPlanKamera acikken kamera MUTE
  EDILMEZ (capture surer, karsi taraf gorur); PiP basarisizsa avatar yedegi. (2) GRUP iOS PiP:
  `!_isGroup` kapisi KALDIRILDI; _uzakVideoTrackId grupta room.activeSpeakers'tan baskin uzak
  konusanin videosunu secer (ActiveSpeakersChangedEvent zaten notifyListeners->_iosPipGuncelle).
  (3) CANLI YAYIN 3-2-1 GERI SAYIM: live_start_screen _basla REST ONCESI (hayalet live yok).
  ⚠️ YAPMA: cokluGorevKamera icin entitlement ekleme (imza patlar; iOS16+ property yeter);
  GebzemPip.kanal weak yapma (dealloc->geri bildirim gitmez); grup PiP'te yerel kamerayi PiP'e
  sokma (yalniz uzak konusan); geri sayimi REST SONRASINA koyma (hayalet live); _uzakVideoTrackId'e
  muted serti koyma (PiP kaybolur). iOS PiP GERCEK cihazda test edilir (simulatorde CALISMAZ).
- Onceki: **TEST TURU 8 FIX SURUMU YAYINLANDI (21 Tem 23:45) — KULLANICI KURUP TEST EDECEK:**
  android 29866251897 + ios 29866254208 (headSha 25419ff), debug imza YOK, R2 apk=104946669
  ipa=19082928, purge OK, CDN boyut birebir, index saati BELIRGIN, backend deploy + health ok,
  DB temiz. FIXLER: (1) iOS PiP donma (PipRenderer host-clock PTS + DisplayImmediately +
  isReadyForMoreMediaData — frame.timeStampNs RTP saati donduruyordu; referans videosdk/rn-webrtc)
  + PiP muted'ta sokulmez (_uzakVideoTrackId muted DAHIL — gecici kamera-kapamada pencere kaybolmasin).
  (2) Konuk-split OWN-DEVICE (3. nuks kok neden): atilan konugun KENDI ekraninda _aktifKonuk
  (kendi id'si) hic temizlenmiyordu -> "Görüntü bekleniyor" sonsuz. Fix: guest.left ben-dali +
  _konuktanCik + build KIMLIK KAPISI (_aktifKonuk != benim -> split cizilmez, takilma yapisal
  imkansiz) + 15sn NABIZ MUTABAKATI (heartbeat guest_id doner, kacan guest.* kendini onarir).
  (3) Watch guest_id -> gec katilan izleyici split gorur. (4) Cikis REST unawaited (olu agda
  10-20sn donma). (5) _konukOl re-entrancy + konukAyril catchError + mic mounted guard.
  ⚠️ PiP GERCEK iPhone'da test edilir (simulatorde CALISMAZ). YAPMA: _uzakVideoTrackId'e muted
  serti geri koyma (PiP kaybolur); split'e track-OR koyma (siyah bug diriltir); _cik'e REST await
  geri koyma (donma). Nabiz artik Future<String> (guest_id) doner — void'e cevirme.
- Onceki: **iOS PiP + KONUK-PANEL + YENI MENU SURUMU YAYINLANDI (20 Tem 22:50):** iPhone goruntulu aramada arka plana alininca UZAK video sistem PiP penceresinde (native GebzemPip AppDelegate.swift icinde; flutter_webrtc sharedSingleton+remoteTrackForId->RTCVideoRenderer->AVSampleBufferDisplayLayer->AVPictureInPictureController auto-enter; SES BIRIMINE DOKUNULMADI; kurulamazsa kamera-mute avatar yedegi); konuk SERT-KAPATINCA panel kalkar (ParticipantDisconnected); yeni menu (tap dairesi yok, radius, sik gorusulenler). **Kullanici GERCEK iPhone test edecek (PiP simulatorde test EDILEMEZ).** ⚠️ iOS PiP: pbxproj'a AYRI dosya EKLEME (BOM tuzagi) — kod AppDelegate.swift icinde; flutter_webrtc header <flutter_webrtc/FlutterWebRTCPlugin.h> public; V1 yalniz 1:1 goruntulu UZAK video (kendi kamera bg'de OS durur); ses sirasina DOKUNMA.
- Bu oturumda ayrıca YAYINLANDI (19 Tem 20:20 sürümü): Faz-A/B/C (minimize+yeşil bant,
  mesaj ikonu, kişi ekleme, davet, konuk+listeler, 30 hediye, 10k jeton) + 16 tarama fix'i.
  Mimari: aktif arama ActiveCallController'da (tuzaklar bölümüne bakın).
- Spaces özet: /rooms uçları (11), rol=DB, dinleyici publish yok, el kaldırma REST, sweep
  (LiveKit ListRooms kontrolü dahil), LiveKit pin v1.13.3, internal/livekit ortak twirp paketi.
- Grup görüntülü fazı 18 Tem akşam YAYINLANDI (oturum.md "Oturum 16": adımlar, test rehberi,
  bilinen sınırlar). Sonraki adaylar: test bulguları → geç-katılma/kişi-ekleme → kalıcı grup
  sohbeti → Spaces (yol haritası).
- Kritik bağlam: backend startGroup videoyu zaten destekliyordu; eklenenler = kapasite sınırı
  (video≤8/sesli≤32), grup düşük video profili (540p), grid video tile, başlatma ekranı seçimi,
  grup kamera butonu, overlay metni. 1:1 ve SESLİ grup davranışı DEĞİŞMEDİ (isGroup dalları +
  "video track yoksa eski avatar ızgara birebir").

## TELEMETRİ & İZLEME (12 Tem 2026 — hepsi canlı)
- **Sentry:** https://gebzem.sentry.io — gebzem-mobile + gebzem-backend projeleri; hatalar dosya+satır ile otomatik düşer. OTURUM BAŞINDA KONTROL ET. sentry_flutter ^9.6 (8.x KULLANMA — Kotlin/Swift derleme hatası)
- **Paneller (Caddy basic auth: gebzem/cKIZMzFJCyNERn):** nabiz.gebzem.app (Netdata), log.gebzem.app (Dozzle) · bekci.gebzem.app (Uptime Kuma: gebzem/Gebzem2026!, 4 monitor)
- **Admin panel:** https://api.gebzem.app/admin/izle (giriş: **admin / Gebzem2026!** — env ADMIN_USER/ADMIN_PASS override; login gövdesi `{"user","pass"}` alanları!). **ADMIN_KEY artık güçlü** (19 Tem, sunucu .env + .env.infra'da; eski `gbz-izle-2026` GEÇERSİZ) — kullanıcılar, aramalar + **canlı Ses Teşhis sekmesi** (audio-stat renk kodlu, 2sn yenilenir: 🟢SES-VAR 🔴iOS-CIKIS-YOK 🟠SES-GELMIYOR 🟣TRACK-YOK 🟡SES-DUSUK). Veri: bellek ring buffer (son 120) + docker log. GEÇİCİ teşhis — üretim öncesi kaldır.
- **Nöbetçi:** sunucuda dakikalık cron (backend/watchdog.sh) — API 2 kez sağlıksızsa otomatik restart, disk ≥%90 docker prune. Log: /var/log/gebzem-watchdog.log
- **API HTTPS:** https://api.gebzem.app (Cloudflare flexible SSL → Caddy:80 → api:8080). Caddyfile değişince `docker compose -f monitoring-compose.yml restart caddy` ŞART
- **Cloudflare Global API Key** .env.infra'da (CF_GLOBAL_KEY; legacy header: X-Auth-Email + X-Auth-Key — Bearer ÇALIŞMAZ). DNS tam kontrolde
- **ufw:** sadece 22/80/8080 açık
- **KURAL: Codemagic build tetikledikten sonra ANLIK izle** (arka plan poll scripti), patlarsa subactions[].logUrl'den logu çek, düzelt
- Kullanıcı anahtarları sohbete YAZMAZ → gbz-a3/token.txt'ye koyar, oradan oku (güvenlik filtresi tetiklenmesin)

## DAĞITIM KONTROL LİSTESİ (her yeni sürümde ZORUNLU — kullanıcı boşuna eski sürüm kurdu)
1. Build bitti mi + artifact var mı (status=finished ve .apk/.ipa mevcut)
2. APK debug imzayla mı derlendi? (logda "Signing with debug keys" OLMAMALI — SMS/Firebase çalışmaz)
3. R2'ye yükle (scratchpad/r2put.js — Cache-Control: no-cache gönderiyor)
4. **Cloudflare zone purge ŞART** (Global API Key ile) — yoksa CDN eski dosyayı servis eder
5. **Yayın sonrası doğrula:** sunucudaki Content-Length == yerel dosya boyutu; /health = ok
6. Ancak bundan sonra kullanıcıya "hazır" de

## CI/CD: GITHUB ACTIONS (Codemagic ücretsiz dakikaları bitti — 12 Tem 2026)
- Workflow'lar: `.github/workflows/android.yml`, `ios.yml` (workflow_dispatch ile tetiklenir)
- Tetikle: `gh workflow run android.yml --repo gbz-app/gebzem` · Takip: `gh run list/view --log-failed`
- Artifact indir: `gh run download <id> --repo gbz-app/gebzem --dir <klasor>`
- ⚠️⚠️ **SECRET KURALI:** `gh secret set NAME --body "deger"` KULLAN. **PowerShell borusu (`$x | gh secret set`) secret'ları BOZUYOR** (base64 invalid / keystore tampered / Apple 401). Çok satırlı anahtarlar (p8, pem) → **base64'le, workflow'da çöz**
- Kota: özel repoda 2000 dk/ay, **iOS 10x sayılır** (~12 iOS build/ay). Repo public yapılırsa sınırsız bedava

## RUTİN: HER YENİ SÜRÜMDE
1. Build (GitHub Actions) → artifact indir → içerik doğrula
2. R2'ye yükle → **Cloudflare purge** → sunucudaki boyut = yerel boyut kontrolü
3. **Veritabanını temizle:** `TRUNCATE users CASCADE; TRUNCATE otp_codes;` (kullanıcı isteği — her sürümde temiz başlangıç)
4. Ancak sonra "hazır" de

## ARAMA SİSTEMİ (LiveKit — kendi sunucumuzda)
- LiveKit v1.13.3: `backend/livekit-compose.yml` + `livekit.yaml` (host network, TURN açık)
- Adresler: **wss://rtcd.gebzem.app:7443** (sinyal DOĞRUDAN, CF'siz — hız için 20 Tem; gri DNS + Caddy LE cert; istemcide `rtc.gebzem.app` fallback'i var. GERİ ALMA: docker-compose.yml LIVEKIT_URL=wss://rtc.gebzem.app + api restart, ANINDA). Eski **wss://rtc.gebzem.app** (CF proxied) hâlâ çalışır/fallback · **turn.gebzem.app: TLS 443 + UDP 3478** (DNS proxy KAPALI olmalı!)
- **use_ice_lite: true** (livekit.yaml, 20 Tem hız) — connectTime 2.6s→~0.55s. Geri alma: satırı sil + livekit force-recreate.
- ⚠️ **TURN TLS ŞART** (mobil operatör NAT'ı): Let's Encrypt sertifikası /opt/gebzem/letsencrypt (certbot+dns-cloudflare, Global Key ile). `external_tls: false` + cert_file/key_file. TLS'siz TURN = `dtls timeout`, ses gitmez!
- Sertifika yenileme (90 günde bir): `docker run --rm -v /opt/gebzem/letsencrypt:/etc/letsencrypt -v /opt/gebzem/cf:/cf certbot/dns-cloudflare renew` + livekit restart
- Portlar (ufw): 7880, 7881, 443, 3478/udp, 50000-50200/udp, 30000-40000/udp
- Teşhis: `node scratchpad/stuntest.js` (UDP/TCP erişim testi) · LiveKit logunda `dtls timeout` = medya geçmiyor, `"network":"cellular"` = operatör NAT'ı
- Backend: `internal/calls` — /calls (başlat), /calls/{id}/answer, /calls/{id}/end, GET /calls (geçmiş); WS: call.incoming/answered/ended
- Env: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET (sunucu .env'inde)
- Flutter: livekit_client + permission_handler; adaptiveStream/dynacast/simulcast açık (zayıf bağlantı + otomatik yeniden bağlanma)

## KRİTİK TUZAKLAR (tekrar yaşamayalım)
- **CallKit/VoIP push (iOS):** FCM VoIP push GÖNDEREMEZ → Go'dan doğrudan APNs (`app.gebzem.voip`).
  VoIP push gelince CallKit'e KOŞULSUZ `reportNewIncomingCall` (iOS 13+ kuralı: bildirmezsen Apple
  uygulamayı öldürür + VoIP push'ları keser). Android: `notification` DEĞİL **data-only** push +
  `@pragma('vm:entry-point')` (yoksa release'de tree-shake). Test: simülatörde CallKit ÇALIŞMAZ, gerçek cihaz şart.
- **1080p video:** H264 KULLANMA (SDK level 3.1 = 720p tavanı). VP8 + simulcast + `degradationPreference: balanced`
  (varsayılan `maintainResolution` → ağ kötüleşince fps çakılır). `restartTrack()` sender encoding'i
  yeniden HESAPLAMAZ → arama ortasında çözünürlük yükseltme temiz çalışmaz, BWE'ye bırak.
- **ARAMA HATASI ARARKEN ÖNCE ODA LOGUNU OKU** (12 Tem'de 3 saat kaybettim):
  `docker logs livekit | grep call_<id>` → `participant active` + `mediaTrack published`
  varsa **WebRTC/TURN ÇALIŞIYOR**, hatayı istemci mantığında ara.
  `dtls timeout` uyarılarının çoğu **kendi test scriptlerimin** odalarından gelir
  (`medyatest`, `icecheck`, `turntest`) — sinyale bağlanıp WebRTC yapmayan istemciler
  bunu üretir. **Oda/katılımcı adını filtrelemeden log okuma.**
- **iOS SES BİRİMİ (19 Tem, grup-host sessiz-mic dersi):** iOS'ta CallKit'siz bağlanan HER yol
  (grup hostu, giden arama) için ses birimi start'ı ÖNCESİ oturum aktivasyonu ŞART —
  AppDelegate setAudioEnabled(true) artık `setConfiguration(webRTC(), active:true)` yapıyor
  (CallKit'li yolda no-op). Bu satırı SİLME. Grup hostu ringback ÇALMAZ (kabulEdilenler
  kısayolu `|| widget.isGroup`) — geri getirme. Yeni CallKit'siz ses yolu eklerken (oda/yayın
  deseni) aynı sıra: bağlan → mic → hoparlör → setAudioEnabled EN SON.
- **ARAMA SÜRE SENKRONU (18 Tem, 3. kez elden geçti — REGRESYON YAPMA):** İki cihaz sayacı
  **monotonik `Stopwatch`** ile sayar (`_sureBaz + _sureSayaci.elapsed`), ASLA `DateTime.now()` ile
  sunucu zamanı karşılaştırmasıyla değil (saat kayması = yanlış başlangıç). Backend `answer()`/WS
  `call.answered` → `elapsed_ms` (~0); Status → `answered_at NULL iken -1` (**created_at'e DÜŞÜRME**
  → arayan zil fazında sahte referans kilitler, sayaç şişer!). İstemci referansı **yalnız `s=='active'`
  iken** alır. Push süre TAŞIMAZ (zamanlama güvenilmez). Grup HARİÇ (`!widget.isGroup`) → yerel sayaç.
- **AKTİF ARAMA = ActiveCallController (GLOBAL, Faz-C):** Room+timer+süre+ses birimi+muhafızlar
  `active_call_controller.dart`'ta; CallScreen SAF GÖRÜNÜM. **Ekran dispose'u aramayı BİTİRMEZ**
  (minimize sayılır — `ekranBeklenmedikKapandi`). Aramayı yalnız `leave` TEK KAPISI bitirir;
  yeni ekran-kapatan kod da leave'i kullanmalı. Teardown "ENQUEUE ANINDA YAKALA": kuyruğa koyarken
  room/listener/nesil senkron yakalanır (tek controller'da alanlar yeni aramada resetlenir —
  bekleyen eski teardown yeni Room'u öldürmesin). Minimize bitiş DEĞİL: muhafızlar dolu, timer'lar
  akar, CallKit aktif. Bant `AktifAramaBanner` (builder içinde — Navigator.of YASAK, root key'ler).
- **STALE-ASYNC DESENLERİ (19 Tem taraması — 16 bulgunun ortak kökleri, TEKRAR ETME):**
  (1) Uygulama-boyu controller/serviste HER async akış + event listener kendi kimliğini
  yakalar (`final id = b.callId;` → `if (arama?.callId != id) return;`) — "null mu" kontrolü
  YETMEZ, yeni arama devralmış olabilir. (2) Stale akış paylaşılan bayrak/timer/alanlara
  DOKUNMAZ — yalnız kendi yakaladığı nesneleri temizler (`_staleTemizle`). (3) Singleton
  provider'ı (wsProvider) INVALIDATE ETME — constructor'da abone olan singleton'lar (CallService,
  DavetServisi) ölü stream'de kalır; close()+connect() aynı instance'ı canlandırır.
  (4) Kullanıcı-tetiklemeli async akışa re-entrancy kilidi (çift dokunuş = çift REST/ekran).
  (5) Redis'te sahiplikli anahtar silme = compare-and-delete Lua (koşulsuz DEL yarışta yanlış
  sahibi siler). (6) Yetki/anahtar fallback'i YASAK — env boşsa fail-closed (repo PUBLIC!).
  (7) "Üyelik tazeleme" uçları (heartbeat) ilk-katılım kurallarını (blok/kapasite) atlamamalı.
- **Riverpod + overlay:** Bir widget'ı gösteren state'i, o widget'ın `async` işleminin
  ORTASINDA sıfırlama → widget dispose olur, sonraki `if (!mounted) return;` sessizce
  devreye girer ve **sonraki satır (Navigator.push) hiç çalışmaz**. Önce ekranı aç, sonra state'i temizle.
- **`MaterialApp.builder` içindeki widget Navigator'ın DIŞINDADIR** → `Navigator.of(context)`
  çalışmaz. `rootNavigatorKey` (GoRouter navigatorKey) + `scaffoldMessengerKey` kullan.
- **Firebase SMS bölge politikası:** yeni projelerde `smsRegionConfig = allowlistOnly{}` (BOŞ = tüm ülkeler engelli!) → `{"allowlistOnly":{"allowedRegions":["TR"]}}` PATCH et
- Firebase Flutter paketleri: **core ≥4, auth ≥6, messaging ≥16** (eski sürümler iOS'ta EXC_BREAKPOINT ile çöküyor); iOS deployment target ≥ **15.0**
- **PowerShell ile Dart/emoji içeren dosyalarda toplu regex replace YAPMA** — `Get-Content -Raw` UTF-8'i bozar, Türkçe karakterler/emoji mahvolur. Edit tool kullan.
- pbxproj'a yazarken `[System.IO.File]::WriteAllText` (BOM'suz) — `Set-Content -Encoding utf8` BOM ekler, Xcode imzalama patlar
- AGP 9 Kotlin DSL: `java.util.Properties()` inline ÇALIŞMAZ → dosya başına `import java.util.Properties`
- sentry_flutter 8.x → Android Kotlin + iOS Swift derleme hatası; **9.x kullan**
- Codemagic: private repo klonu **SSH deploy key** ile (token'lı HTTPS URL kabul edilmiyor); çok satırlı secure var'larda `\r` temizle
- Firebase APNs anahtarı yükleme ve bazı Console işlemleri API'de YOK → kullanıcıya adım adım tarif et
- Cloudflare Global API Key: `X-Auth-Email` + `X-Auth-Key` başlıkları (Bearer değil)

## PROJE DURUMU (son güncelleme: 12 Temmuz 2026)
- ✅ **Faz 1 CANLIDA:** kayıt/OTP(kendi 6 hane)/giriş/şifre yenileme + 1:1 mesajlaşma (tikler, yazıyor, okunmamış)
- ✅ Kullanıcı arama (@kullanıcıadı / isim) — rehber yerine gerçek profiller
- ✅ Backend + LiveKit + Caddy + Postgres + Redis sunucuda Docker'da; https://api.gebzem.app, wss://rtc.gebzem.app
- ✅ Push: FCM v1 (Android ✓, iOS APNs anahtarı yüklü); Sentry (mobil + backend) açık
- ✅ **CI/CD: GitHub Actions** (Codemagic'in bedava dakikaları bitti) → APK + ad hoc IPA → **https://indir.gebzem.app**
- ✅ **ARAMA (1:1 sesli/görüntülü):** CANLI, kullanıcı testlerinden geçti (süre senkron, CallKit, ses teşhis dahil)
- ✅ **GRUP ARAMASI (sesli + görüntülü, 18 Tem):** sesli ≤32, görüntülü ≤8 kişi; video ızgara + mid-call kamera; anlık grup (member_ids) — kalıcı grup sohbeti UI'si sonraki faz
- ⏳ Sonraki: geç-katılma/kişi-ekleme → Faz 2 (gruplar, story, profil, medya) → odalar+yayın (Spaces) → admin
- ✅ Uygulama ikonu: kullanıcı tasarımı (mor/kıvrımlı logo) koda işlendi 18 Tem — kaynak
  mobile/assets/icon/kaynak.jpg; güncelleme: `dart run tool/ikon_uret.dart` + `dart run
  flutter_launcher_icons` (⚠️ sonrasında pbxproj'daki GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS
  bozulmasını git checkout ile geri al — araç bug'ı, APPICON_NAME zaten şablonda var)
- Test kullanıcıları: her sürümde DB temizleniyor (aşağıdaki rutin) → kullanıcı sıfırdan kayıt olur

## REPO YAPISI (monorepo: github.com/gbz-app/gebzem — **PUBLIC** 15 Tem 2026: Actions kotası doldu → sınırsız bedava için public yapıldı; secrets Actions'ta gizli, kodda/geçmişte hassas dosya YOK)
- `backend/` — Go API (chi + pgx + go-redis + gorilla/websocket)
- `mobile/` — Flutter (org: app.gebzem). lib/: core/ (api, ws, storage, theme), features/ (auth, chats, home), router.dart
- `admin/` — yer tutucu (Faz 5: Next.js)
- Kök: CLAUDE.md, oturum.md, arastirma-raporu.md, ozellik-listesi.md, .env.infra (gitignore'lu)

## API UÇLARI (backend)
Açık: POST /auth/register, /auth/verify (test OTP), **/auth/verify-firebase (GERÇEK SMS)**, /auth/login, /auth/forgot, /auth/reset · GET /health
Korumalı (Bearer): GET/PATCH /users/me · POST /users/me/username · POST /users/me/fcm-token · **GET /users/search?q=** (isim/@username; telefon dönmez) · GET /users/by-phone · GET /chats · POST /chats/direct · GET+POST /chats/{id}/messages · POST /chats/{id}/read · GET /ws (WebSocket; ?token= de kabul eder)
WS olayları: message.new, receipt.read, typing
**Kimlik doğrulama:** GERÇEK SMS aktif (Firebase Phone Auth → Google imzalı ID token → backend doğrular). Test moduna dönmek için Flutter: `--dart-define=REAL_SMS=false` (o zaman /auth/register+verify akışı, dev_otp yanıtta döner).
**Kullanıcı adı:** kayıtta zorunlu (@handle, 3-20 karakter a-z0-9_). Arama isim veya @username ile.

## KOMUTLAR
- **Backend yerel derleme:** `cd backend && go build ./...`
- **Flutter analiz:** `cd mobile && flutter analyze`
- **Mobil çalıştırma (emülatör, yerel backend):** `cd mobile && flutter run` (API varsayılanı 10.0.2.2:8080)
- **Mobil canlı sunucuya karşı:** `flutter run --dart-define=API_URL=http://167.233.229.88:8080`
- **DEPLOY (sunucuda güncelleme):** `ssh -i ~/.ssh/gebzem_ed25519 root@167.233.229.88 "cd /opt/gebzem/repo && git pull && cd backend && docker compose up -d --build"`
- Sunucuda log: `docker compose logs -f api` (dizin: /opt/gebzem/repo/backend)
- **YENİ SÜRÜM DAĞITIMI:** Codemagic API ile derleme tetikle (appId 6a52c71564181d764c0d9c88, workflow `android-build` / `ios-adhoc`) → artifact indir → R2 `gebzem-dist` bucket'a yükle (scratchpad/r2put.js, SigV4) → indir.gebzem.app'te güncellenir

## SUNUCU (Hetzner gebzem-1)
- IP: 167.233.229.88 · Ubuntu 24.04 · cx33 (4 vCPU/8GB) · Falkenstein · €8,99/ay
- SSH: `ssh -i ~/.ssh/gebzem_ed25519 root@167.233.229.88`
- Docker compose stack: /opt/gebzem/repo/backend → api (8080 dışa açık) + postgres:17 + redis:7 (ikisi sadece 127.0.0.1)
- `backend/.env` sunucuda JWT_SECRET içerir (git dışı). Repo klonu token'lı HTTPS remote
- ⚠️ Güvenlik duvarı henüz YOK (prototip); API şimdilik HTTP — yayın öncesi: firewall + HTTPS (api.gebzem.app + Caddy)

## MİMARİ KARARLAR (arastirma-raporu.md'ye dayalı)
- Kanal/grup: Telegram modeli (tek chats tablosu, type: direct/group/channel)
- Mesaj akışı: PostgreSQL'e yaz → Redis pub/sub "events" → hub → WebSocket; çevrimdışı = REST gecmisi (inbox deseni) + ileride FCM push
- Hediye: animasyon LiveKit data API; bakiye/işlem coin_ledger tablosunda (kayıt bonusu 100 jeton kodda çalışıyor)
- Prototipte ödeme YOK (bedava jeton); IAP V2 (%15 tier kaydı unutulmasın); payout ileride banka/İyzico (6493 — asla kendi bünyede değil)
- Harita: google_maps_flutter, cloudMapId KULLANMA (bedava kalması için); OSMF bedava tile YASAK
- Yayın öncesi yasal: BTK yer sağlayıcı bildirimi + 4 saat içerik kaldırma + trafik logu 1-2 yıl + hukukçu teyidi (sosyal ağ eşiği)
- LiveKit: sesli odalar cx33'te OK; video yayında benchmark'ın %50'si varsay + büyümede dedicated makine

## CI/CD + DAĞITIM (Codemagic)
- App: `6a52c71564181d764c0d9c88` (SSH deploy key ile bağlı — token'lı HTTPS klon ÇALIŞMIYOR!)
- Workflow'lar (codemagic.yaml): `android-build` (APK), `ios-adhoc` (IPA — keychain initialize + fetch-signing-files --create + add-certificates ŞART)
- Apple: bundle `app.gebzem`, ASC API anahtarı BYRG6K58NK (.p8 kökte, gitignore'lu), Issuer dd626245-204e-4b73-a98a-3fa9241b4a47; iPhone XS Max cihaz kayıtlı (ad hoc'a otomatik dahil)
- Codemagic'te güvenli değişken grubu: `appstore_credentials` (ISSUER_ID, KEY_IDENTIFIER, PRIVATE_KEY=p8, CERTIFICATE_PRIVATE_KEY=cert_key.pem)
- ⚠️ Codemagic API çok satırlı değerlerde CR kabul etmez → `-replace "\`r",""` şart
- ⚠️ Codemagic build logu: `GET /builds/{id}` → buildActions[].subactions[].logUrl (üst seviyede logUrl BOŞ gelir)

## HESAPLAR & ARAÇLAR
- GitHub: gbz-app · Cloudflare: Gebzemapp@outlook.com (zone gebzem.app; R2: gebzem-media + gebzem-dist→indir.gebzem.app) · Google: gebzemapp@gmail.com (gcloud girişli; API çağrılarında `x-goog-user-project` başlığı şart) · Codemagic + Apple: yukarıda
- Anahtarlar: `.env.infra` · gh CLI: `C:\Users\gebze\tools\gh\bin\gh.exe` (PATH'te yok) · gcloud: `C:\Users\gebze\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd` · Firebase CLI (npm), Node 24, git 2.54, Flutter 3.44, Go 1.26
- PowerShell tuzakları: git/gcloud çıktısı stderr'e gider (`2>&1` NativeCommandError yanıltır — kullanma); Dart 3.12'de `(_, __)` yerine `(_, _)`
Dostum sen şimdi ben test yaparken detaylı bir şekilde ve dikkatli bir şekilde canlı yayın yap ve temiz bir bıild alt öncesin çok kapsamlı bug fix araştırması yap ve en son derinlemesine yap step step ve temiz build al indir sitesi ne r saat yazmıyor göremiyorum orada saatte yazdım buna arada