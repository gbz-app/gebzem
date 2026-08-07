## FLUTTER MEDYA PAKET SEÇİMİ — KARAR RAPORU

### Doğrulanan zemin (kaynaktan)

| İddia | Kanıt |
|---|---|
| iOS'ta WebRTC ses birimi **global manuel modda** | `mobile/ios/Runner/AppDelegate.swift:32-33` — `RTCAudioSession.sharedInstance().useManualAudio = true` + `isAudioEnabled = false`, uygulama açılışında |
| iOS'ta **TEK paylaşılan** `videoCapturer` | `AppDelegate.swift:668, 737, 905` — üç yerde de `FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer` (tekil singleton) |
| Meşguliyet kapısı tek kaynak olarak mevcut | `mobile/lib/features/calls/call_provider.dart:162` `mesgulMu({haric, etiket, odaYayinMuaf})` |
| Android **minSdk = 24** | Flutter 3.44 `FlutterExtension.kt:26` (`val minSdkVersion: Int = 24`); `android/app/build.gradle.kts:34` `flutter.minSdkVersion` kullanıyor |
| iOS hedef 16.0 | CLAUDE.md kuralı — aday paketlerin en yükseği iOS 14 → **hepsi uyumlu** |

---

## 1. Görsel/video seçme → **image_picker 1.2.3**

| Paket | Sürüm / tarih | Beğeni / puan / haftalık | Karar |
|---|---|---|---|
| **image_picker** | 1.2.3 · 38 gün | 7.7k / 160 / 3.79M | ✅ **SEÇİLDİ** |
| file_picker | 11.0.3 · 7 gün | 4.93k / 140 / 3.28M | ✅ yalnız **belge** için |
| wechat_assets_picker | 10.1.3 · 19 gün | 867 / 155 / 53.2k | ❌ elendi |

**Gerekçe:** image_picker iOS'ta **PHPicker**, Android'de **Photo Picker** kullanıyor → **hiç izin istemiyor**. Bu proje zaten izin diyaloğu yükü altında (kamera, mikrofon, telefon durumu, bildirim, tam ekran intent) ve tur 34-36'da izin diyaloğu çakışması kayıt akışını patlatmıştı. `pickMultiImage()` çoklu seçim zaten var.

wechat_assets_picker **elendi:** `photo_manager ^3.5.0` getiriyor → Android 13+ için `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`, EXIF için `ACCESS_MEDIA_LOCATION` — dört yeni izin, sıfır fonksiyonel kazanç. Ayrıca kamera için ayrıca `wechat_camera_picker` gerekiyor (kendi dokümanı: "does *not* handle photo/video capture").

> ⚠️ **RİSK:** image_picker dokümanı — Android'de bellek baskısında sistem `MainActivity`'yi öldürebilir, `retrieveLostData()` **zorunlu**. Bu projede risk **yüksek**: PiP + foreground service + LiveKit aynı anda çalışıyor. Uygulamaya dönüşte `retrieveLostData()` çağrısı atlanırsa kullanıcı seçtiği fotoğrafı sessizce kaybeder.

---

## 2. Kamera → **`camera` paketi KULLANMA. image_picker `ImageSource.camera`**

Bu, raporun en kritik maddesi.

**`camera` paketi kendi `AVCaptureSession`'ını kurar.** Bu projede iOS'ta flutter_webrtc **tek** paylaşılan `videoCapturer` tutuyor (yukarıda kanıt). Geçmiş:
- **Tur 50:** iki capture oturumu birbirinin oturumunu çaldı → video track odaya hiç ulaşmadı (%14 arama tek taraflı video).
- **Tur 67:** aynı sınıf hata tekrar etti → `_kameraKuyruguna` ile açma/bırakma **tek slotluk zincire** dizildi.

`camera` paketi bu kuyruğun **tamamen dışında** üçüncü bir tüketici olur. Aynı hata sınıfı geri gelir ve bu kez sohbet ekranından tetiklenir.

`image_picker` `ImageSource.camera` ise iOS'ta `UIImagePickerController` açar — **sistem-sahipli modal**, oturumu iOS yönetir, bizim capture oturumumuza doğrudan tutamak vermez. Yapısal olarak çok daha güvenli.

> ⚠️ **YİNE DE ZORUNLU KAPI:** aktif arama/oda/yayın sırasında `UIImagePickerController` açılırsa iOS kamerayı ondan alır → aramanın videosu ölür. Sohbetteki "kamera" butonu **`mesgulMu()` (`call_provider.dart:162`) ile korunmalı**; meşgulken yalnız galeri açılsın, kamera butonu gizlensin. Mevcut `mesgulMu` kapısını **kopyalama, çağır** (CLAUDE.md: "bu mantığı çağıran yerlere kopyalama — drift eder").

---

## 3. Görsel sıkıştırma + EXIF → **flutter_image_compress 2.5.1**

| Paket | Sürüm / tarih | Beğeni / puan / haftalık |
|---|---|---|
| **flutter_image_compress** | 2.5.1 · 13 gün | 1.82k / 150 / 928k |
| image (saf Dart) | 4.3.0 — zaten `dev_dependencies`'te | — |

**Gerekçe:** Native (Android bitmap / iOS CoreImage) → 4-12 MP fotoğrafta ana thread'i dondurmaz. `image` saf Dart'tır; runtime'a taşınırsa **isolate zorunlu** olur, ekstra karmaşıklık.

**EXIF:** Dokümanı net — varsayılan çıktı **EXIF taşımaz** ("the compressed output carries no source EXIF"). Yani **GPS sızıntısı varsayılan olarak kapalı**. `keepExif: true` **yazma**. `Orientation` her zaman `1`'e normalize edilip rotasyon piksele gömülüyor — istenen davranış.

---

## 4. Video sıkıştırma → **video_compress 3.1.4** (isteksiz seçim) · ffmpeg **ELENDİ**

**ffmpeg_kit_flutter ARŞİVLENDİ — doğrulandı.** 6 Ocak 2025 emeklilik duyurusu; **1 Nisan 2025**'te native binary'ler Maven Central / CocoaPods / npm'den **silindi**. Gerekçeler: upstream FFmpeg takip yükü + MPEG LA'nın Via-L tarafından satın alınmasıyla oluşan **codec patent belirsizliği**.

Fork: **ffmpeg_kit_flutter_new 4.6.2** (198 beğeni / 160 puan / 67.7k, 8 gün önce, aktif). **Ama elendi:**
- Lisans: LGPL-3.0 tabanlı, **GPL v3 bileşenler dahil → "effectively GPL v3.0"** (paketin kendi ifadesi). Kapalı kaynak mobil uygulama için ciddi risk.
- Boyut: **+25-40 MB** mimari başına (TAHMİN — arşiv dokümanında sayı yok, tarihsel ffmpeg-kit full-gpl ölçümlerinden).
- Patent belirsizliği projeyi devraldı (retirement gerekçesinin ta kendisi).

**video_compress 3.1.4:** 746 beğeni / 140 puan / 171k haftalık — ama **18 aydır güncellenmemiş**. Seçilme sebebi: **%100 native** (Android MediaCodec / iOS AVAssetExportSession), FFmpeg binary'si **yok**, APK'ya native kütüphane eklemiyor.

> ⚠️ **RİSK:** bakımsız. Kabul edilebilir çünkü API yüzeyi çok küçük ve altındaki platform API'leri stabil.
> 📌 **DAHA GÜVENLİ ALTERNATİF (öneri):** Faz 1'de sıkıştırmayı hiç yapma — **süre sınırı (örn. 3 dk) + boyut sınırı (örn. 100 MB)** koy, ham dosyayı yükle. Sıkıştırma gerekirse 2. turda `AVAssetExportSession` + `MediaCodec` platform kanalını kendimiz yazarız (~200 satır; video_compress'in yaptığı zaten tam olarak bu).

---

## 5. Video oynatma → **video_player 2.13.0** · chewie **ATLA**

| Paket | Sürüm / tarih | Beğeni / puan / haftalık | Karar |
|---|---|---|---|
| **video_player** | 2.13.0 · 25 gün | 3.7k / 150 / 2.79M · flutter.dev | ✅ |
| chewie | 1.14.1 · 2 ay | 2.35k / 150 / 734k | ❌ |
| better_player | 0.0.84 · **2 yıl** | 1.3k / **60** / 3k | ❌❌ |

**chewie neden atlandı (proje kuralı çakışması):**
1. Chewie kontrolleri **Material/Cupertino ikonu** çizer. CLAUDE.md tur 62: *"arayüzde emoji/3B ikon YOK, hepsi Lucide"* — chewie'nin ikonlarını değiştirmek için zaten kendi kontrol katmanını yazman gerekir, o zaman chewie'ye gerek kalmaz.
2. `wakelock_plus` getiriyor. Tur 60'ta wakelock **açıkça elendi** ("projede yakınlık sensörü YOK; yanak dokunuşları + pil").
3. `provider ^6.1.5` getiriyor — proje Riverpod kullanıyor, iki durum yönetimi kütüphanesi taşımak gereksiz.

**better_player elendi:** 2 yıl güncellenmemiş, pub points 60, haftalık 3k indirme. Ölü.

---

## 6. Ses kaydı → **record 7.1.1** + **zorunlu meşguliyet kapısı**

| Paket | Sürüm / tarih | Beğeni / puan / haftalık |
|---|---|---|
| **record** | 7.1.1 · 39 gün | 886 / **160** / 815k · BSD-3, verified |
| flutter_sound | 9.30.0 · 8 ay | 1.64k / 140 / 72.9k |

**flutter_sound elendi:** kendi sayfasında geliştirici *"We desperately need at least one other developer"* diyor ve halefi (Taudio / Flutter Sound 10.0) yeniden yazım hâlinde. Bakım riski + çok geniş API yüzeyi.

### ⚠️⚠️ Ses birimi çakışması — bu projeye özel analiz

**İyi haber:** `AppDelegate.swift:32-33` uygulama açılışında `useManualAudio = true` + `isAudioEnabled = false` yapıyor. Yani **arama yokken WebRTC ses birimi KAPALI** → `AVAudioSession` serbest, `record` kategoriyi `playAndRecord`a çevirir, çakışma olmaz.

**Kötü haber:** arama/oda/yayın **sırasında** `record` `setCategory` çağırırsa, **canlı VPIO biriminin altından** kategori değişir. Bu projede tam bu hata sınıfı defalarca yaşandı:
- Tur 64: `NSOSStatusErrorDomain#561017449` = `0x21707269` = `!pri` = `InsufficientPriority`
- Tur 65: CallKit unhold ediyor ama `didActivate` hiç gelmiyor

LiveKit'in kendi dokümanı da kayıt başlayınca oturumu `playAndRecord` olarak **yeniden uyguladığını** söylüyor → iki yazıcı, aynı oturum.

> ### 🔴 ZORUNLU KURAL
> **Arama / sesli oda / canlı yayın aktifken ses notu kaydı YASAK.** Mikrofon butonu `mesgulMu()` (`call_provider.dart:162`) ile kapatılsın; kullanıcıya *"Görüşme sürerken ses notu kaydedilemez"* denilsin. WhatsApp da tam olarak bunu yapıyor.
>
> **Kendini onarma:** kayıttan sonra kalan kategori kalıntısı için ekstra iş **gerekmiyor** — bir sonraki aramanın `setAudioEnabled(true)` yolu `setConfiguration(RTCAudioSessionConfiguration.webRTC(), active: true)` ile kategoriyi deterministik yeniden kuruyor (`AppDelegate.swift:83`).
>
> **Android:** `record` AudioFocus alır → LiveKit'in `AudioSwitchManager`'ı ile çakışır (tur 62-C'de tam bu mekanizma ses rotasını bozmuştu). Aynı `mesgulMu` kapısı Android'i de korur.

**Format:** `AudioEncoder.aacLc` (m4a). Opus Android'de API 29+ ister, minSdk 24 → **AAC seç**.

---

## 7. Ses oynatma + dalga formu → **audioplayers ^6.5.0 (mevcut) YETERLİ**

Yeni paket **gerekmiyor**. Ses notu için ayrı `AudioPlayer` örneği + `setSourceUrl` + `onPositionChanged` yeterli.

**Dalga formu — audioplayers vermez.** Çözüm:
- **Kayıt sırasında canlı dalga:** `record`'un `onAmplitudeChanged(Duration)` stream'i dBFS veriyor → doğrudan çiz.
- **Çalma sırasında statik dalga:** kaydederken topladığın amplitüd dizisini (örn. 60 örnek, 0-100 arası int) **mesaj metadata'sına** göm ve gönder. WhatsApp da statik dalga gösterir. Sunucuda ayrı analiz **gerekmez**.

> ❌ **`audio_waveforms` paketini KULLANMA** — kendi kayıt *ve* çalma motorunu getiriyor, `record` + `audioplayers` ile üç yönlü `AVAudioSession` çakışması yaratır.

> ⚠️ audioplayers iOS'ta `AudioContextIOS` ile kategori ayarlar. Ses notu çalarken `mixWithOthers` **kullanma** — arama zil sesi mantığıyla (`CallSounds`) çakışır.

---

## 8. Konum + harita

### Konum → **geolocator 14.0.3** (6.12k / 160 / 2.02M · Baseflow, 56 gün)
`location` paketi yerine: çok daha yüksek benimseme ve **`permission_handler` ile aynı yayıncı (Baseflow)** → izin akışı tutarlı, mevcut `permission_handler ^12.0.3` ile uyumlu desen.
⚠️ `compileSdk ≥ 35` istiyor — Flutter 3.44 varsayılanı zaten karşılıyor, build'de doğrula.

### Harita → **flutter_map 8.3.1 + ticari tile** · google_maps_flutter **ATLA**

**google_maps_flutter 2.18.0 elendi. Sebep maliyet:**
Google, **Mart 2025**'te evrensel **$200 aylık krediyi kaldırdı**. Yerine SKU başına ücretsiz eşik: **Essentials 10.000 olay/ay**, Pro 5.000, Enterprise 1.000. Static Maps Essentials'ta → aşımı **$2-7 / 1000 istek**. Mobile Maps SDK gösterimi de SKU sayar.

**50K kullanıcı hedefinde** her konum mesajı balonu açılışta bir harita isteği demek → 10.000 ücretsiz eşik **günlerce sürmez**. Üstelik +2-3 MB APK ve API key yönetimi.

**Seçilen mimari (iki katmanlı):**

| Katman | Çözüm |
|---|---|
| **Mesaj balonu (statik önizleme)** | Sunucu koordinat başına **bir kez** statik görsel üretir → **R2'ye (`gebzem-media`, şu an boş) yazar** → mesaja R2 URL'i konur. Aynı koordinat tekrar açılınca istek **yok**. Maliyet patlamasını burası kapatır. |
| **Konum seçme ekranı (interaktif)** | **flutter_map 8.3.1** + **MapTiler** veya **Stadia Maps** tile'ı. Her ikisi de OSM *verisi* kullanır ama **kendi ticari tile sunucularını** işletir → OSMF bedava tile politikası ihlali **yok**. Stadia Maps flutter_map'i açıkça destekliyor ve statik harita API'si de veriyor. |

**flutter_map 8.3.1:** 2.17k / **160** / 643k, **%100 saf Dart, native kod yok** → APK artışı ~0. cloudMapId sorunu yapısal olarak mevcut değil.

> ⚠️ **BİLMİYORUM:** MapTiler ve Stadia Maps'in **2026 ücretsiz kota rakamlarını doğrulayamadım** (arama sonuçları plan isimlerini veriyor, net aylık ücretsiz istek sayısını vermiyor). Hesap açmadan önce ikisinin fiyat sayfası okunmalı. Stadia Maps'in 100K oturum/ay'da MapTiler'dan ~%73 ucuz olduğu iddiası kendi pazarlama sayfasından geliyor — **tarafsız kaynak değil**.

---

## 9. İndirme / önbellek

| İhtiyaç | Paket | Sürüm / tarih | Metrik |
|---|---|---|---|
| Görsel önbellek | **cached_network_image** | 3.4.1 · **24 ay** | 6.96k / 150 / 2.97M |
| Dosya yolları | **path_provider** | 2.1.6 · 53 gün | 5.55k / 160 / 6.74M · flutter.dev |
| Genel indirme | **dio ^5.8** (mevcut) | — | — |

> ⚠️ cached_network_image **24 aydır güncellenmemiş**. Yine de risk düşük: `flutter_cache_manager ^3.4.1` üstünde ince bir katman, API donmuş, haftalık 2.97M indirme.
> ❌ `flutter_cache_manager`'ı **ayrıca ekleme** — cached_network_image zaten getiriyor; ayrı önbellek grubu gerekirse aynı paketteki `CacheManager`'ı kullan.

---

## 10. Yükleme ilerlemesi + arka planda devam → **background_downloader 9.5.7**

**dio `onSendProgress` ilerleme için yeterli, ama arka planda ÇALIŞMAZ.** Bu projede kritik: Android 14+ cached-app freezer arka plandaki süreci **~10 sn sonra donduruyor** — tur 32-33'te tam bu yüzden `AramaServisi.kt` foreground service'i yazıldı. iOS'ta da Dart isolate askıya alınır.

**background_downloader 9.5.7** — 497 / **160** / 163k, 11 gün önce, verified publisher (bbflight.com):
- iOS: **URLSession background sessions**
- Android: **WorkManager / DownloadWorker**
- **`UploadTask` ile arka plan YÜKLEME** destekliyor (tek + multipart), `onProgress` / `onStatus` dinleyicileri var.

> ⚠️ **RİSK 1 (iOS):** background URLSession multipart upload'da gövdenin **diskte dosya** olmasını şart koşar (bellekten gönderim desteklenmez). Sıkıştırma çıktısı zaten geçici dosya → uyumlu, ama akış buna göre kurulmalı.
> ⚠️ **RİSK 2 (Android):** paket kendi foreground service'ini açabilir. Projede **zaten** `AramaServisi` (`foregroundServiceType="microphone|camera"`) var. İki foreground service aynı anda → Android 14 tip/kota sorunu. **Arama sırasında büyük yükleme başlatmayı `mesgulMu()` ile engelle**, veya yükleme servisini `dataSync` tipiyle ayrı tut.

---

## 11. PDF/belge → **open_filex 4.7.0** (sistem görüntüleyici)

433 / 140 / 501k · 17 ay önce. iOS `UIDocumentInteractionController` + UTI eşlemesi, Android `Intent` + MIME eşlemesi. `REQUEST_INSTALL_PACKAGES` iznini kaldırmış, Android 13+ granular medya izinleri ve Gradle 8+ ile uyumlu.

❌ **İç görüntüleyici koyma** (`flutter_pdfview` / `syncfusion_flutter_pdfviewer`): +native kod, +APK, +bakım. Sistem görüntüleyicisi yeterli.
⚠️ 17 aydır güncellenmemiş. **Yedek plan:** `url_launcher` (flutter.dev, çok aktif) + `file://` — ama Android FileProvider yapılandırmasını elle yazman gerekir; open_filex bunu paketliyor.

---

# pubspec.yaml — eklenecek tam liste

```yaml
dependencies:
  # ---- MEDYA MESAJLASMA (medya fazi) ----
  # Gorsel/video secme + kamera. iOS PHPicker / Android Photo Picker -> IZIN ISTEMEZ.
  # ⚠️ Android'de MainActivity oldurulebilir: uygulamaya donuste retrieveLostData() ZORUNLU.
  # ⚠️ ImageSource.camera YALNIZ mesgulMu()==false iken (call_provider.dart:162).
  #    `camera` paketi KULLANMA — iOS'ta flutter_webrtc TEK paylasilan videoCapturer
  #    tutuyor (AppDelegate.swift:668/737/905); ucuncu capture oturumu turu 50/67 hatasini geri getirir.
  image_picker: ^1.2.3

  # Belge/dosya secme (PDF, docx, zip...)
  file_picker: ^11.0.3

  # Gorsel sikistirma. VARSAYILAN OLARAK EXIF SILER (GPS sizintisi kapali).
  # ⚠️ YAPMA: keepExif: true yazma.
  flutter_image_compress: ^2.5.1

  # Video sikistirma — %100 NATIVE (MediaCodec / AVAssetExportSession), FFmpeg YOK.
  # ⚠️ 18 aydir guncellenmemis; API yuzeyi kucuk oldugu icin kabul edildi.
  # ⚠️ ffmpeg_kit_flutter ARSIVLENDI (1 Nis 2025 binary'ler silindi); fork
  #    ffmpeg_kit_flutter_new "effectively GPL v3.0" + ~30MB -> BILEREK KULLANILMADI.
  video_compress: ^3.1.4

  # Video oynatma. chewie EKLEME: Material ikon (Lucide kurali), wakelock_plus
  # (turu 60'ta elendi) ve provider (Riverpod var) getiriyor. Kontroller KENDIMIZ + Lucide.
  video_player: ^2.13.0

  # Ses notu kaydi (AAC-LC/m4a; opus Android 29+ ister, minSdk 24).
  # 🔴 ZORUNLU: arama/oda/yayin aktifken KAYIT YASAK -> mesgulMu() kapisi.
  #    Sebep: AppDelegate.swift:32 useManualAudio=true GLOBAL; canli VPIO altinda
  #    kategori degisimi turu 64 (!pri) / turu 65 (didActivate yok) hatalarini uretir.
  # Dalga formu: onAmplitudeChanged (dBFS) ile kayitta topla, mesaj metadata'sina goc.
  # ⚠️ audio_waveforms EKLEME (kendi kayit+calma motoru -> uclu ses oturumu cakismasi).
  record: ^7.1.1

  # Konum. permission_handler ile AYNI yayinci (Baseflow) -> izin akisi tutarli.
  geolocator: ^14.0.3

  # Harita: %100 SAF DART, native kod YOK (APK artisi ~0).
  # ⚠️ google_maps_flutter KULLANILMADI: $200 evrensel kredi Mart 2025'te KALDIRILDI,
  #    Essentials SKU 10.000/ay ucretsiz, sonrasi $2-7/1000 -> 50K kullanicida patlar.
  # ⚠️ OSM Foundation bedava tile YASAK -> MapTiler veya Stadia Maps (ticari, OSM verisi).
  # ⚠️ Mesaj balonu INTERAKTIF harita cizmez: sunucu statik onizlemeyi R2'ye BIR KEZ yazar.
  flutter_map: ^8.3.1

  # Gorsel onbellek. ⚠️ 24 aydir guncellenmemis ama API donmus, risk dusuk.
  # ⚠️ flutter_cache_manager'i AYRICA ekleme — bu paket zaten getiriyor.
  cached_network_image: ^3.4.1

  # Gecici/kalici dosya dizinleri (sikistirma ciktisi, indirilen medya).
  path_provider: ^2.1.6

  # ARKA PLANDA yukleme/indirme. dio onSendProgress arka planda CALISMAZ
  # (Android 14+ cached-app freezer ~10sn, turu 32-33 kaniti).
  # iOS: URLSession background · Android: WorkManager. UploadTask arka plan yukleme verir.
  # ⚠️ iOS multipart upload govdeyi DISKTE dosya olarak ister.
  # ⚠️ Android: AramaServisi foreground service ZATEN var -> arama sirasinda buyuk
  #    yukleme baslatmayi mesgulMu() ile engelle (iki FGS tip/kota catismasi).
  background_downloader: ^9.5.7

  # PDF/belge acma — SISTEM goruntuleyicisi (ic goruntuleyici EKLEME).
  # ⚠️ 17 aydir guncellenmemis; yedek plan url_launcher + elle FileProvider.
  open_filex: ^4.7.0
```

**Ek yapılandırma gerekecek** (bu turda kod yazılmadı, sadece not):
- `Info.plist`: `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSLocationWhenInUseUsageDescription`. (`NSCameraUsageDescription` + `NSMicrophoneUsageDescription` **zaten var** — arama için.)
- `AndroidManifest.xml`: `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`. Photo Picker kullanıldığı için `READ_MEDIA_*` **gerekmiyor**.

---

# Tahmini boyut artışı

> ⚠️ **HEPSİ TAHMİN.** Kesin rakam `flutter build apk --analyze-size` / `--target-platform android-arm64` ile ölçülür. Aşağıdakiler paketlerin taşıdığı native kütüphane türünden çıkarılmıştır.

| Paket | APK (arm64) TAHMİN | Not |
|---|---|---|
| video_player | **1.5 – 2.5 MB** | Android Media3/ExoPlayer — **en büyük kalem** |
| geolocator | 0.3 – 1.0 MB | Play Services Location bağlanırsa üst sınır |
| background_downloader | 0.3 – 0.5 MB | WorkManager |
| file_picker | 0.3 – 0.5 MB | |
| record | 0.2 – 0.4 MB | MediaRecorder / AVAudioRecorder |
| image_picker | 0.2 – 0.4 MB | sistem picker, native kod az |
| flutter_image_compress | ~0.2 MB | platform API |
| video_compress | 0.1 – 0.2 MB | native API, binary yok |
| open_filex | ~0.1 MB | |
| cached_network_image | ~0.1 MB | saf Dart |
| path_provider | ~0.05 MB | |
| flutter_map | ~0.2 – 0.4 MB | saf Dart (yalnız derlenmiş Dart kodu) |
| **TOPLAM** | **≈ +3.5 – 7 MB** | mevcut ~108 MB universal APK üzerinde **%3-6** |

**IPA TAHMİN: +3 – 5 MB** (AVFoundation/CoreLocation sistem framework'leri, kendi binary'leri yok).

**Elenen alternatiflerin bedeli (karşılaştırma için):**
- `ffmpeg_kit_flutter_new` (full-gpl): **+25 – 40 MB** mimari başına + GPL v3 + patent belirsizliği
- `google_maps_flutter`: **+2 – 3 MB** + aylık SKU faturası
- `wechat_assets_picker` + `photo_manager`: **+1.5 – 2.5 MB** + 4 yeni Android izni
- `chewie`: +provider +wakelock_plus, Lucide ikon kuralını ihlal

---

## Sources

- [image_picker](https://pub.dev/packages/image_picker) · [file_picker](https://pub.dev/packages/file_picker) · [wechat_assets_picker](https://pub.dev/packages/wechat_assets_picker) · [photo_manager](https://pub.dev/packages/photo_manager)
- [camera](https://pub.dev/packages/camera) · [flutter_image_compress](https://pub.dev/packages/flutter_image_compress) · [video_compress](https://pub.dev/packages/video_compress)
- [ffmpeg-kit (arşiv)](https://github.com/arthenica/ffmpeg-kit) · [ffmpeg_kit_flutter_new](https://pub.dev/packages/ffmpeg_kit_flutter_new) · [FFmpegKit kapanış analizi](https://www.itpathsolutions.com/ffmpegkit-shutdown-what-to-do-next)
- [video_player](https://pub.dev/packages/video_player) · [chewie](https://pub.dev/packages/chewie) · [better_player](https://pub.dev/packages/better_player)
- [record](https://pub.dev/packages/record) · [flutter_sound](https://pub.dev/packages/flutter_sound) · [LiveKit Flutter ses dokümanı](https://github.com/livekit/client-sdk-flutter/blob/main/docs/audio.md) · [LiveKit AVAudioSession çakışma issue #996](https://github.com/livekit/client-sdk-flutter/issues/996)
- [geolocator](https://pub.dev/packages/geolocator) · [google_maps_flutter](https://pub.dev/packages/google_maps_flutter) · [flutter_map](https://pub.dev/packages/flutter_map)
- [Google Maps API fiyatlandırma 2026 (SKU dökümü)](https://www.mapsi.dev/google-maps-api-pricing) · [Google Maps API ücretsiz mi? 2026](https://www.woosmap.com/blog/is-google-maps-api-free) · [Stadia Maps fiyatlandırma](https://stadiamaps.com/pricing/)
- [cached_network_image](https://pub.dev/packages/cached_network_image) · [path_provider](https://pub.dev/packages/path_provider) · [background_downloader](https://pub.dev/packages/background_downloader) · [open_filex](https://pub.dev/packages/open_filex)