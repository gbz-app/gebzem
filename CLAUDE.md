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