# Gebzem Projesi — Claude Kuralları

WhatsApp + Twitter Spaces + TikTok Live karışımı sosyal uygulama. Hedef: ~50K kullanıcı, Türkiye pazarı. Domain: gebzem.app

## ZORUNLU KURALLAR (kullanıcı emri)
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
- **KALDIGIMIZ YER (31 Tem 02:05):** TEST TURU 52 YAYINLANDI — android 30588794092 +
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
  · Grup aramasi (sesli VE goruntulu): **8 kisi** (arayan dahil). Backend tek sabit
    `internal/calls/handler.go` **`maxGrupKatilimci`** (Start + Add ayni yerden okur);
    istemci `toggleCam` kapisi da 8. ⚠️ Iki tarafa farkli sayi yazma.
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