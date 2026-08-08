
> ## ⚠️⚠️ KULLANICI KARARI (8 Ağustos) — BU PLANI EZER: **VERİ SİLİNMEZ**
>
> Kullanıcı: *"90 günlük silme vs olmasın, böyle şeyler sakın, insanların verisini silmek yok;
> evet sürekli veri olacak, büyüyecek, bunu Cloudflare'e ödeyeceğiz."*
>
> · Aşağıdaki **90 gün saklama** kararı ve ona bağlı tüm maliyet tabloları **GEÇERSİZDİR**.
> · Depolama sınırsız büyür; maliyet kabul edilmiştir. Maliyet düşürme artık silmeyle değil,
>   **sıkıştırma + doğru çözünürlük + depolama sınıfı** ile yapılır.
> · ⚠️ **TEK İSTİSNA — bunlar "veri silme politikası" değil, YASAL ZORUNLULUK ve KALMALIDIR:**
>   (a) kullanıcı kendi mesajını/gönderisini siler, (b) kullanıcı **hesabını** siler (KVKK
>   unutulma hakkı), (c) mahkeme/BTK kaldırma kararı, (d) CSAM/yasa dışı içerik kaldırma.
> · ⚠️ YAPMA: plana "otomatik silme / arşivleme / yaşam döngüsü temizliği" geri koyma.
>
> **Ayrıca (turu 74):** migration **014** `reports` tablosuna gitti — bu plandaki
> medya migration'ları **015'ten** başlar. Ayrıca planın Faz 2'sindeki `media_url`
> kaldırma ve moderasyon (engelle/şikâyet/sil) adımları **turu 74'te YAPILDI** (070f4c7).

---
## 1. KARAR ÖZETİ

**Depolama: Cloudflare R2, TEK BAŞINA. Images ve Stream ELENDİ.**
· R2 egress **$0** — 50K kullanıcıda aylık ~2,6 TB indirme AWS S3'te ~$234/ay, R2'de $0. Anahtarlar, `gebzem-media` bucket'ı ve zone **zaten `.env.infra`'da hazır**, yeni abonelik yok.
· **Images elendi:** fiyat *görsel başına* ($5/100k saklanan + $1/100k sunulan) → orta senaryoda $153/ay vs R2'de $8,5. Sohbet = çok sayıda küçük dosya, model tam aleyhimize.
· **Images Transformations elendi:** 900k benzersiz dönüşüm/ay = $447/ay. Küçük resmi **istemci** üretir = $0.
· **Stream elendi:** 12. ayda ~$4.050/ay. Stream az sayıda çok izlenen video içindir; sohbet videosu tam tersi.
· **Erişim: ÖZEL (private) bucket + kısa ömürlü imzalı GET.** Public + 1 yıl edge TTL kararı **KABUL EDİLMEDİ**: R2'den silmek Cloudflare edge önbelleğini boşaltmaz → 5651'in "4 saat içinde kaldırma" beyanı **yanlış beyan** olur. Önbellek cihazda (`cacheKey = media_id`).
· **Medya API'den GEÇMEZ** (presigned PUT). cx33'te LiveKit aynı 4 vCPU'da; bu pazarlık dışı.
· **Sunucuda ffmpeg YOK**, sıkıştırma ve küçük resim istemcide.

**Paketler (sırayla, faz faz):** `image_picker` · `flutter_image_compress` · `path_provider` · `crypto` · `cached_network_image` · `record` · `connectivity_plus` · `gal` (galeriye kaydetme) · `video_compress` · `video_player` · `file_picker` · `open_filex`.
**Eklenmeyenler:** `camera` (iOS paylaşılan `videoCapturer`), `chewie` (Material ikon + `wakelock_plus` + `provider`), `ffmpeg_kit_*` (arşivlendi/GPL/+30 MB), `audio_waveforms` (üçlü ses oturumu çakışması), `google_maps_flutter` (SKU faturası + `cloudMapId` yasağı), `background_downloader` (Android'de ikinci ön plan servisi — `AramaServisi` zaten var).

---

## 2. KAPSAM

### MVP (ilk sevkiyat — Faz 0-7)
Kullanıcının şikâyeti (indir sayfası saati) + bekleyen ölçümlerin okunması · sohbet ekranı iskeleti (ataç paneli, **uzun basma menüsü**, yanıtla, herkesten sil) · engelleme + şikâyet · medya altyapısı (presign/commit/url/sweeper) · **avatar yükleme** · **fotoğraf** (galeri + kamera + altyazı + çoklu seçim) · **ayarlar ekranı** (otomatik indirme + depolama) · **ses notu**.

### 2. DALGA
Video (çok parçalı yükleme ile) · belge · sohbet medya galerisi · iletme (forward) · tek seferlik görüntüleme · anlık konum · kişi kartı · anket · yıldızlama · mesaj arama · albüm mozaiği · fotoğraf düzenleme (kırp/döndür/çiz) · admin medya kaldırma ekranı · paylaş-sheet'inden Gebzem'e gönderme.

### YAPILMAYACAKLAR (gerekçeli)
| Ne | Neden |
|---|---|
| **Ödeme** | Türkiye'de WhatsApp Pay yok; 6493 gereği ödeme/e-para faaliyeti kendi bünyede **yasak** (lisans şartı). Jeton satılacaksa yol IAP. |
| **Canlı konum** | Play Store arka plan konum **ayrı gerekçe formu** + uzun inceleme; 8 saat agresif GPS = pil. Anlık konum değerin %90'ını veriyor. → 3. dalga, kullanıcı kararı (§9). |
| **Etkinlik (event)** | Türkiye'de WhatsApp'ta bile kullanımı düşük; grup lojistiği anketle çözülüyor. |
| **Çıkartma mağazası / GIF** | Harici servis (Giphy/Tenor) bağımlılığı + 5651 içerik filtreleme yükümlülüğü. → kullanıcı kararı (§9). |
| **Uçtan uca şifreleme** | Moderasyon ve 5651 kaldırma yükümlülüğünü teknik olarak imkânsızlaştırır. **Pazarlamada "uçtan uca şifreli" İDDİA EDİLMEYECEK.** |
| **Süresi dolan mesajlar** | Sunucu tarafı planlı silme + R2 yaşam döngüsü oturmadan yapılmamalı. → 3. dalga. |
| **Yakınlık sensörü (ses notunu kulağa götürme)** | Projede yakınlık sensörü yok (turu 60'ta wakelock aynı gerekçeyle elenmişti). |

---

## 3. FAZ FAZ UYGULAMA PLANI

> **Her fazdan sonra:** `go build ./...` + `flutter analyze` + commit + push (`git rev-parse origin/main` ile doğrula) + `oturum.md` ve CLAUDE.md güncelle. **Build KULLANICI "al" DEYİNCE.**

---

### FAZ 0 — Kullanıcının asıl istediği iş: ölçüm okuma + indir sayfası saati
**Amaç:** Medya koduna dokunmadan önce turu 69'un bekleyen ölçümlerini okumak ve indir sayfasındaki saat şikâyetini kapatmak.
**ÖNKOŞUL:** yok.

**ADIMLAR**
1. Sentry `gebzem-mobile`'da turu 69 ölçümlerini oku: `callkit bitir: kaynak=native yasam=..` ve `callkit bitir: kaynak=eklenti` — **iki damganın zaman farkını** yaz. Native önce geliyorsa kanca kurtardı; eklenti hiç gelmiyorsa asıl delik orada.
2. Turu 68 ölçümü: `callkit aktif arama (giden|gelen): adet=.. hold=.. grup=..`. `hold=false` çıktı mı? Çıkmadıysa `maximumCallGroups 2→1` kararı **hâlâ ertelenmiş** kalır (ölçmeden uygulama).
3. Turu 63 ölçümü: `devam sonrasi ses: jitterMs=.. tamponMs=..` — düzeltilmiş metrikle değer var mı?
4. `scratchpad/indir_uret.js` yeniden yaz (her oturumda yeniden yazılıyor). ⚠️ `body`'ye **tekrar `display:flex; align-items:center` KOYMA** — saat çubuğu kartın DIŞINDA, sayfanın en üstünde kalacak. Saat UTC+3.
5. Turu 67'de bırakılan **ölü park zinciri** temizliği: `ParkEdilenArama`/`parkEt`/`devamEt`/`beklemeyeAl`/`_medyaBeklet`/`_iosSesOturumuGarantile`/`GebzemSesKurtar` + `call_screen.dart` bekletme paneli/rozeti. ⚠️ **Edit ile TEK TEK, her adımda `flutter analyze`** (turu 67'de script'le toplu silme dosyayı bozdu).
6. Commit + push.

**DOĞRULAMA:** İndir sayfasını telefondan aç → mor saat çubuğu **en üstte, kırpılmadan** görünüyor. `flutter analyze` 0 hata. Arama/oda/yayın regresyon testi (sesli, görüntülü, oda, yayın — dördü de).

**RİSK:** Ölü kod silerken canlı dala dokunmak. **Korunma:** her silmeden sonra `flutter analyze` + adım listesini `oturum.md`'ye işle.

---

### FAZ 1 — ZORUNLU ÖLÇÜM TURU (yayınlanmaz)
**Amaç:** Medya kodunun üzerine kurulacağı üç varsayımı ölçmek. Bu ölçümler yapılmadan tek satır medya kodu yazılmayacak.
**ÖNKOŞUL:** Faz 0.

**ADIMLAR**
1. **Ö1 — `singleInstance` tuzağı.** `AndroidManifest.xml:36-37` `launchMode="singleInstance"` + `taskAffinity=""` (CallKit için `ecc63ac`'ta kondu). `singleInstance`'tan başlatılan activity **ayrı görevde** açılır ve `startActivityForResult` `RESULT_CANCELED`'ı anında döndürebilir. Geçici bir ekrana `image_picker.pickImage()` + `pickMultiImage()` + `file_picker.pickFiles()` bağla, gerçek Android cihazda **sonuç dönüyor mu** ölç.
2. **Ö2 — lifecycle yalancı arka plan.** Aynı deneme build'inde: görüntülü arama / sesli oda / canlı yayın sürerken picker aç-kapat. Sentry'e **gerçek olay** (breadcrumb değil): `medya olcum: yasam=<state> camOn=<b> pipBaslat=<b> sesiAc=<b> gecen=<ms>`. Karşı tarafta kamera kesintisi ve odada ses kesilmesi **süresini** ölç.
3. **Ö3 — `CallRoomLock` sırası.** `leave()` çağrısı ile `CallRoomLock.calistir(() async {})`'ın dönmesi arasındaki süreyi ölç (`leave sonrasi kilit bosaldi: ms=..`). Video sıkıştırma kuyruğunun tetikleyicisi buna bağlanacak; 250 ms varsayımı doğrulanacak ya da çürütülecek.
4. Deneme build **YALNIZ ölçüm için**, R2'ye **YÜKLENMEZ**, indir sayfası **güncellenmez**.

**DOĞRULAMA:** Kullanıcı deneme APK'sını kurar, 5 dakikada üç senaryoyu koşar; Sentry'de üç ölçüm satırı görünür.

**RİSK / KORUNMA:**
- Ö1 kırıksa: `launchMode`'u **DEĞİŞTİRME** (turu 33 "kilit ekranında telefon çalmıyor" regresyonu). Çözüm: picker'ı kendi kaydettiğimiz şeffaf `MedyaSeciciActivity`'den (`launchMode` varsayılan) başlat, sonucu MethodChannel ile döndür. CallKit yolu etkilenmez.
- ⚠️ `singleTop` denemesini "hızlı çözüm" diye sevk etme; full-screen intent + `showWhenLocked` davranışı o bayrağa bağlı ve regresyonu ancak kilitli telefonda görülür.

---

### FAZ 2 — BACKEND HİJYENİ (şema değişikliği YOK)
**Amaç:** Medya gelmeden önce `SendMessage`'daki mevcut açıkları ve hataları kapatmak.
**ÖNKOŞUL:** Faz 1 ölçümleri okundu.

**ADIMLAR**
1. `chat/handler.go:125-130` — `sendMessageReq`'ten **`MediaURL` alanını SİL**. Doğrulandı: istemci bu alanı **hiç göndermiyor** (`chats_provider.dart:77-83` gövdesi yalnız `{'type','content'}`) → geriye dönük güvenli. Bu, bugün canlıda duran SSRF/oltalama/izleme-pikseli yüzeyini kapatır.
2. `chat/handler.go:207-209` — `preview[:80]` **bayt** kesiyor, Türkçe karakteri ortadan bölüp push gövdesine geçersiz UTF-8 gönderiyor. Ortak `onizlemeKirp(s string, n int) string` (`[]rune` tabanlı) yardımcısına çevir; tüm çağrılar oradan.
3. `chat/handler.go:159` sonrası — **engel kontrolü ekle**. Bugün yorumda "uyelik + engel kontrolu" yazıyor ama `chatMemberIDs` (`:409-431`) yalnız üyelik bakıyor. `direct` sohbette çift yönlü `blocks` sorgusu → `403 "bu kullanıcıya mesaj gönderilemiyor"`. Grupta uygulanmaz.
4. **Yeni uç:** `POST /users/{id}/block` + `DELETE /users/{id}/block`. `blocks` tablosuna INSERT eden **hiçbir kod yok** (doğrulandı) → tablo hep boş, engelleme fiilen yok. App Store 1.2 (UGC) şartı.
5. **Yeni uç:** `DELETE /chats/{chatID}/messages/{id}` — `deleted_for_all=true` + `content=''`. `deleted_for_all` bugün **hiçbir yerde yazılmıyor** (`handler.go:236-238` ve `chat_screen.dart:647-650` ölü dallar). Yalnız gönderen, gönderimden < 60 dk.
6. **Yeni WS olayı:** `message.deleted` `{message_id}` — `To` = üyeler **+ gönderenin kendisi** (`chatMemberIDs` göndereni çıkarıyor; ikinci cihaz için gerekli).
7. `chat/handler.go:213` — yanıt **tam mesaj nesnesi** dönsün (bugün yalnız `{id, created_at}`). İstemcinin `await load()` ile tüm listeyi yeniden çekmesi böylece gereksizleşecek.
8. `cmd/api/main.go:96-102` — korumalı grubun başına `r.Use(middleware.RequestSize(1 << 20))`. ⚠️ `/livekit/webhook` (`:133`) bu grubun DIŞINDA, etkilenmez.
9. `SendMessage`'a Redis hız sınırı: 20/10 sn burst, 600/saat. Bugün **hiçbir hız sınırı yok**.
10. `handler.go:258-263` ve `:375-381` — `rows.Scan` hatası **sessizce yutuluyor** (mesaj/sohbet listeden kaybolur, log bile düşmez). `log.Printf` + `Sentry.CaptureMessage` ekle.

**DOĞRULAMA:** Backend deploy + `/health` ok. Postman: `{"type":"system",...}` → `400`. `{"media_url":"https://kotu.site/x.gif"}` → alan yok sayılır. Türkçe karakterli 100 karakterlik mesaj → push gövdesinde **bozuk karakter yok**. Bir kullanıcıyı engelle → mesaj `403`. Kendi mesajını sil → iki tarafta "Bu mesaj silindi".

**RİSK:** `MediaURL` alanını silmek eski istemciyi kırar mı? **Hayır** — Go `json.Decode` bilinmeyen alanı sessizce yok sayar, üstelik istemci zaten göndermiyor (kaynaktan doğrulandı).

---

### FAZ 3 — İSTEMCİ SOHBET İSKELETİ + ÇAKIŞMA KAPISI
**Amaç:** Beş tasarımın beş kez çizdiği ortak bileşenleri **tek kez** yazmak; medya tiplerinin takılacağı iskeleti kurmak.
**ÖNKOŞUL:** Faz 2 deploy edildi.

**ADIMLAR**
1. **`mobile/lib/features/chats/medya/medya_kapisi.dart` — TEK ÇAKIŞMA KAPISI.** Üç tasarım üç farklı kapı önerdi (`mesgulMu` vs `SesSahipligi`); **ikisi de tek başına eksik**. Kapı **dört kaynağı birden** sorar:
```dart
/// ⚠️⚠️ TEK KAYNAK. Bu mantigi cagiran yerlere KOPYALAMA (turu 56 dersi: drift eder).
/// ⚠️ SesSahipligi TEK BASINA YETMEZ: kayit `baslat()` icinde (active_call_controller.dart:1348),
///    GELEN aramada kabul edilene kadar defter BOSTUR.
/// ⚠️ iOS'ta gelen arama WS'ten HIC GELMEZ (call_provider.dart:211) -> CallKit defteri SART.
class MedyaKapisi {
  static bool _oturumVar(WidgetRef ref) =>
      SesSahipligi.ozet.isNotEmpty
      || ref.read(activeCallProvider).arama != null
      || ref.read(callServiceProvider) != null
      || CallKitService.islenenler.isNotEmpty;

  /// Kamera (iOS paylasilan videoCapturer — turu 50/67)
  static bool kameraSerbest(WidgetRef ref) => !_oturumVar(ref);
  /// Ses birimi (record/audioplayers — turu 64 !pri, turu 62-C ses rotasi)
  static bool sesBirimiSerbest(WidgetRef ref) => !_oturumVar(ref);
  /// Donanim H.264 kodlayici (video_compress)
  static bool kodlayiciSerbest(WidgetRef ref) => !_oturumVar(ref);

  /// ⚠️ mesgulMu AYRICA cagrilir: bayat muhafizi TEMIZLER + Sentry olcumu yazar
  ///    (turu 53/56 self-heal). SesSahipligi statik Set'tir ve SIZABILIR.
  static void olc(WidgetRef ref, String etiket) {
    ref.read(callServiceProvider.notifier).mesgulMu(etiket: 'medya-$etiket');
  }
}
```
2. **`MedyaSecici` mandalı — Faz 1/Ö2'nin çözümü.** Picker açılışı `paused`/`inactive` üretiyor ve mevcut lifecycle kodu bunu "arka plana geçti" sanıp **kamerayı KENDİ kapatıyor**, PiP başlatıyor, oda sesini yeniden kuruyor. Zaman sınırlı senkron mandal:
```dart
class MedyaSecici {
  static DateTime? _acildi;
  static void ac()    => _acildi = DateTime.now();   // ⚠️ picker cagrisindan SENKRON ONCE
  static void kapat() => _acildi = null;             // ⚠️ finally icinde
  /// ⚠️ ZAMAN SINIRI ZORUNLU: mandal sizarsa arka planda kamera-mute yedegi KALICI OLUR.
  static bool get acik =>
      _acildi != null && DateTime.now().difference(_acildi!) < const Duration(seconds: 45);
}
```
   Kapı **beş yere ilk satır olarak** konur:
   - `active_call_controller.dart:1504` (`iosPipBaslat`), `:1520` (`iosArkaPlanKamerayiTazele`), `:1565` (kamera-mute)
   - `room_screen.dart:170` (`_sesiAc(true)`), `live_broadcast_screen.dart:144-159` (kamera-mute)
   ⚠️ **YAPMA:** `resumed` dalına koyma (`_kameraOtoAc()` dönüşte çalışmalı). ⚠️ **YAPMA:** `room_screen`/`live_broadcast`'ın `resumed` dalını komple `return` ile kesme — `_detayYenile()` ve `_nabizAt()` çalışmaya devam etmeli, nabız kesilirse sweeper **yayını kapatır** (turu 15).
   ⚠️ **YAPMA:** `main.dart:505-511`'deki `ws.goOffline()`'ı mandal ile atlama — mandal sızarsa gerçek arka planda `bg` gitmez → **kilit ekranı araması çalmaz** (turu 33). Yalnız Sentry ölçümü: `medya secici: ws kapali kaldi=Nms`.
3. **`ek_paneli.dart`** — ataç düğmesi + alttan panel. ⚠️ Düğme `InputDecoration.prefixIcon` **DEĞİL**, Row'un ilk çocuğu (`TextField` `maxLines: 5`, prefixIcon dikeyde zıplar). Panel öğe modeli `bool kameraKapisi` / `bool sesKapisi` taşır; kapı `false` dönerse öğe **HİÇ ÇİZİLMEZ** (gri değil — yok). ⚠️ turu 66b dersi: *"gövdeyi değiştirmek yetmez, çağıran arayüz de gizlenmeli, yoksa düğme sessizce başka iş yapar."*
4. **Uzun basma menüsü** (`chat_screen.dart`) — bugün **hiçbir balonda `onLongPress` yok** (doğrulandı). Menü: Yanıtla · Kopyala · Herkesten sil (kendi mesajı, <60 dk) · Şikayet et. Lucide: `reply`, `copy`, `trash2`, `flag`.
5. **Yanıtlama (reply) arayüzü** — `reply_to_id` DB'de ve `Message.replyToId` modelde **zaten var**, `send()` göndermiyor, balonda çizilmiyor. Giriş üstünde alıntı şeridi + balonda renkli dikey çizgili blok + dokununca orijinale atla.
6. **`_BalonKabuk`** — yarıçap/gölge/saat+tik satırı tek widget'a alınır; tüm medya balonları onu kullanır. `chat_screen.dart:610-674` `_Bubble` metin yolu **değişmez**.
7. **`chat_screen.dart:251-261` tip dallanması** — tek yerde, sırası **KRİTİK**:
```dart
if (msg.type == 'system')        _CallLogChip(...)
else if (msg.deletedForAll)      _Bubble(...)          // ⚠️ TIP DALLANMASININ USTUNDE
else if (msg.type == 'image')    FotoBalonu(...)
... // sonraki fazlarda dallar eklenir
else                             _Bubble(...)
```
   ⚠️ `itemCount: list.length + 1` ve son elemanın `_AktifAramaBalonu` olması **değişmez**.
8. **`chats_screen.dart:219-260`** — `_previewIkon()` ve `_preview()`'a **tüm gelecek tipler** eklenir (`image/video/audio/document/contact/poll`). `location` ve `audio` **zaten hazır**. ⚠️ `default:` dalı ham `content` basıyor — yeni tip eklemeyi unutmak = kullanıcıya teknik metin (turu 59 dersi).
9. **`ws.acildi` sentetik olayı** — `ws.dart` `_open()` içinde `_connected = true;` sonrası `_controller.add({'type': 'ws.acildi'})`. Tüm dinleyiciler tipe göre filtreliyor, çakışma yok (doğrulandı). Sohbet ekranı bunu alınca `load()` çağırır → arka planda kaçan `message.new`/`message.deleted` onarılır (turu 61 `call.held` dersi).
10. `chats_provider.dart:61-75` — `before_id`/`limit` bağlanır (yukarı kaydırma sayfalaması). Medya balonları uzun; 50 mesaj sınırı çok çabuk vuruyor.
11. `chats_provider.dart:30-35` — `ChatsNotifier` `message.new` gelince **tüm listeyi yeniden çekmeyi bıraksın**, payload'daki alanlarla **ilgili satırı yerinde güncellesin**. Bugün her mesajda tam `/chats` sorgusu koşuyor; medya gelince arama sırasında LiveKit ile aynı 4 vCPU'da yarışır.
12. Taslak (draft) koruma: sohbet başına yazılan metin `shared_preferences`'ta saklanır. Ses notu taslağı buna bağımlı.

**DOĞRULAMA:** Ataç düğmesi görünüyor, panel açılıyor (içi boş/tek satır). Arama sürerken panelde kamera satırı **yok**. Mesaja uzun bas → menü. Yanıtla → alıntı çiziliyor, dokununca atlıyor. Kendi mesajını sil → iki tarafta "Bu mesaj silindi". **Regresyon: sesli arama, görüntülü arama, kilit ekranından kabul, sesli oda, canlı yayın — beşi de eskisi gibi.**

**RİSK:** Lifecycle mandalı sızarsa arka planda kamera kapanmaz (turu 15 "izleyiciler donmuş kare"). **Korunma:** 45 sn zaman sınırı + `finally` + mandal aktifken Sentry ölçümü.

---

### FAZ 4 — MEDYA ALTYAPISI (migration 014 + `internal/media/`) — arayüzde görünen hiçbir şey yok
**Amaç:** Presign/commit/url/sweeper zincirini kurmak. **Beş tasarımın çelişen sözleşmelerini tek karara bağlamak.**
**ÖNKOŞUL:** Faz 3 sevk edildi.

**TEK SÖZLEŞME (çelişkiler çözüldü):**
| Konu | KARAR | Reddedilen |
|---|---|---|
| Prefiks | **Doğrudan nihai anahtar** | `gecici/` → CopyObject **KABUL EDİLMEDİ**: +1 Class A, ve R2 CopyObject davranışı hiçbir tasarımda doğrulanmamış |
| `If-None-Match: *` | **YOK** | **KABUL EDİLMEDİ**: mobil şebekede tekrar denemeyi öldürür; 412 "eksik mi tam mı" ayırt edilemez. Tek-kullanım güvencesi `status` durum makinesinde (`beklemede→aktif` tek yönlü) |
| Bütünlük | `Content-MD5` (imzalı) + commit'te `HeadObject` boyut **tam eşitlik** | "Content-MD5 boyut dayatır" iddiası **YANLIŞ** (R2 gövdenin tamamını alıp sonra reddeder) |
| Erişim | **Private + `GET /media/{id}/url`, TTL 600 sn** | Public custom domain **KABUL EDİLMEDİ** (5651 purge) |
| Presign TTL | `clamp(300sn, bytes/20000, 1800sn)` | Sabit 300 sn **KABUL EDİLMEDİ** (yavaş hatta 16 MB bitmez) |
| Saklama | **90 gün** | 365 gün **KABUL EDİLMEDİ**: maliyet tablosu 90 güne göre kurulmuştu, 365 gün faturayı 3,5× yapıyor |
| IA katmanı | **YOK** | Private bucket + CDN yok → IA'nın $0,01/GB veri çekme ücreti kazancı yiyor |
| Kota | **500 MB/kullanıcı/ay** | 2-3 GB **KABUL EDİLMEDİ**: 50K×2GB = teorik 100 TB/ay |
| Yaşam döngüsü | **DB tabanlı sweeper** | R2 lifecycle **KABUL EDİLMEDİ** (24 saat gecikmeli + DB ile senkron değil) |

**ADIMLAR**
1. `014_medya.sql` — **TEK migration** (§4'te tam SQL). ⚠️ Beş tasarım da "014" istiyordu ve üçü `messages_type_check`'i birbirinden habersiz yeniden kuruyordu → son çalışan öncekinin tiplerini **siler** ve migration hatası `main.go:55` `log.Fatalf` → **API sonsuz çökme döngüsü**. Tek migration, **tüm gelecek tipler tek CHECK'te**, sonraki hiçbir migration kısıta dokunmayacak.
2. `backend/internal/media/sigv4.go` — elle SigV4 (`crypto/hmac`+`crypto/sha256`, referans `scratchpad/r2put.js:32-96`). ⚠️ **Açılışta bilinen test vektörüyle self-test**; tutmuyorsa `Enabled()=false` + `log.Println`. SigV4 hataları sessizdir (`403 SignatureDoesNotMatch`) — her 403 **Sentry gerçek olayı**, breadcrumb değil.
3. `r2.go` (`HeadObject`/`RangeGet`/`DeleteObject`), `sniff.go` (sihirli bayt + EXIF/GPS reddi + MP4 `moov`), `limits.go` (tavanlar + Redis Lua kota), `handler.go` (4 uç), `sweeper.go`.
4. `config.go`'ya `R2AccessKeyID/R2SecretAccessKey/R2Endpoint/R2Bucket` + `MedyaMaxMB`. Boşsa `Enabled()=false` → uçlar kaydedilmez. **Fail-closed ama GÖRÜNÜR**: açılışta `log.Println("medya: R2_* env YOK — KAPALI")` + `GET /users/me` yanıtına `media_acik: bool` (istemci ataç butonunu ona göre gizler).
5. **Sunucudaki `backend/.env`'e R2 anahtarları eklenir.** ⚠️ Bu adım hiçbir tasarımda yoktu; unutulursa medya sessizce kapalı açılır. Dağıtım kontrol listesine yeni madde.
6. `main.go`: `mediaH := media.NewHandler(db, rdb, cfg)` + `if mediaH.Enabled() { mediaH.StartSweeper(ctx) }` + 4 rota (korumalı grupta). ⚠️ `/media/` **401 muafiyet listesine EKLENMEZ** (`api.dart:52-57`).
7. **Sweeper penceresi sabit DEĞİL:** `max(1 saat, expected_bytes/5000 sn)`, tavan 24 saat. Gerekçe: PUT arka planda tamamlanır ama `commit` uygulama açılınca yapılır; 15 dk'lık pencere **hâlâ süren yüklemenin** nesnesini siler. Sweeper silmeden **önce `HeadObject` dener**; nesne tam ve doğruysa **siler değil `aktif` yapar** (kurtarma).
8. **`TRUNCATE users CASCADE` rutini R2'de yetim bırakır** (`media_assets.owner_id CASCADE`) → sweeper o satırları bir daha göremez. Rutine adım eklenir: DB truncate'ten **ÖNCE** `media_assets`'teki tüm `object_key`'ler `media_delete_queue`'ya kopyalanır ve sweeper temizler. (CLAUDE.md dağıtım listesine işlenir.)

**DOĞRULAMA (Postman/curl, arayüz yok):**
- `POST /media/upload` → presign döner. Beyan edilenden farklı bayt PUT → `BadDigest`. Farklı `Content-Type` → `403 SignatureDoesNotMatch`.
- EXIF/GPS'li JPEG yükle → commit `422 "konum bilgisi içeriyor"` + nesne silinmiş.
- PNG'yi `image/jpeg` diye beyan et → `422`.
- 61 kez presign → `429`.
- Başkasının `media_id`'siyle `GET /media/{id}/url` → `403`.
- Sunucu logunda `medya: aktif`.

**RİSK:** Elle SigV4 sessizce yanlış olabilir. **Korunma:** açılış self-test + her 403 Sentry olayı + `Enabled()=false` fail-closed.

---

### FAZ 5 — AVATAR YÜKLEME (altyapının ilk müşterisi)
**Amaç:** Tek dosya / tek boyut / tek tip ile presign→commit→url→görüntüleme zincirinin tamamını gerçek kullanıcıyla kanıtlamak.
**ÖNKOŞUL:** Faz 4.

**Neden avatar:** `avatar_url` bugün **her zaman boş** (`.patch(`/`.put(` çağrısı kod tabanında **0 eşleşme**). 7 yerdeki `NetworkImage` fiilen hiç resim yüklemiyor — ses notu balonu, kişi kartı, arama ekranları hep harf yedeğine düşüyor. Fotoğraf balonundan **önce** yapılmalı ki yeni medya arayüzleri boş dairelerle dolu görünmesin.

**ADIMLAR**
1. `pubspec.yaml`: `image_picker`, `flutter_image_compress`, `path_provider`, `crypto`, `cached_network_image`. ⚠️ `flutter pub deps | grep flutter_webrtc` → **1.4.0 pini bozulmadı** doğrulanır. ⚠️ `flutter build apk --analyze-size` ile gerçek boyut artışı ölçülür (tahmin +1-2 MB).
2. `Info.plist`: `NSPhotoLibraryUsageDescription`. Android: **yeni izin YOK** (Photo Picker).
3. `mobile/lib/core/medya/medya_yukleyici.dart` — presign→PUT→commit zinciri. **Ayrı Dio** (`medyaDioProvider`): `Authorization` interceptor'ı **YOK** (imzayı bozar), `addSentry()` **YOK** (`sentry_dio: ^9.6.0` kurulu, imzalı URL breadcrumb'a sızar). `sendTimeout: 60sn` (`api.dart`'ta bugün **tanımsız**).
4. `api.dart:69` — `beforeBreadcrumb` maskesi: R2 host'una giden isteklerin query string'i kesilir.
5. Profil ekranı (yeni, minimal): avatar + ad + `@kullanıcıadı` + "Fotoğrafı değiştir". `PATCH /users/me` `avatar_media_id` kabul eder, `avatar_url`'i **sunucu türetir**.
6. ⚠️ Android'de picker sırasında `MainActivity` öldürülebilir → uygulamaya dönüşte **`retrieveLostData()` ZORUNLU** (bu projede risk yüksek: PiP + FGS + LiveKit aynı süreçte).
7. Hash işleri **isolate'te** (`compute`) — 25 MB dosyanın SHA-256'sı ana thread'de saniyeler sürer.

**DOĞRULAMA:** Profil → fotoğraf seç → **izin diyaloğu ÇIKMAMALI** → avatar yükleniyor → sohbet listesinde, arama ekranında, kişi aramada **gerçek resim** görünüyor. Karşı cihazda da. Uygulamayı kapat-aç → hâlâ görünüyor (disk önbelleği).

**RİSK:** Faz 1/Ö1 sonucu kırıksa picker sonuç döndürmez. **Korunma:** Faz 1 bu fazın önkoşulu.

---

### FAZ 6 — FOTOĞRAF (MVP'nin ana özelliği) + AYARLAR EKRANI
**Amaç:** Galeri/kamera, çoklu seçim, altyazı, kuyruk, otomatik indirme, tam ekran görüntüleyici.
**ÖNKOŞUL:** Faz 5.

**ADIMLAR**
1. **Kalıcı kuyruk** `medya_kuyrugu.dart` — `StateNotifierProvider`, **`autoDispose` DEĞİL, kök kapsamda**. ⚠️ `messagesProvider` `family.autoDispose` (`chats_provider.dart:121-123`); kuyruk oraya bağlanırsa **kullanıcı sohbetten çıkar çıkmaz yükleme iptal olur**.
   - Defter: `shared_preferences` `medya_kuyrugu_v1`, yalnız **durum geçişlerinde** yazılır (ilerleme belleğe).
   - Dosya: `<Documents>/medya_giden/` — ⚠️ `getTemporaryDirectory()` **DEĞİL** (iOS tmp'yi habersiz siler).
   - ⚠️ **Oturum kapısı:** kuyruk işçisi `if (await storage.token == null) return;`. Yoksa bayat token → `401` → `api.dart:52-63` **tüm oturumu siler** → kullanıcı kayıt ekranından login'e fırlar (turu 34-36 hatası).
   - ⚠️ Logout akışında kuyruk temizlenir (`SesSahipligi.sifirla()` ile aynı satırda).
2. **Eşzamanlılık 2**, üstel tekrar (2s/5s/15s/60s/180s, max 5), `connectivity_plus` dinleyicisi bağlantı gelince **anında** tetikler.
3. **`client_ref` idempotency** — `INSERT ... ON CONFLICT (chat_id, sender_id, client_ref) DO NOTHING RETURNING id` + boş dönerse `SELECT`. ⚠️ "Önce SELECT sonra INSERT" **KABUL EDİLMEDİ** (yarışa açık, `23505` → `500` → tekrar döngüsü).
4. Ataç paneline **Galeri** + **Kamera** satırı. ⚠️ Kamera satırı `MedyaKapisi.kameraSerbest()` false ise **HİÇ ÇİZİLMEZ**; `_kameraAc()` gövdesinin **ilk satırı** kapıyı tekrar okur (çift kapı, fail-closed). ⚠️ "`image_picker` sistem modalı yapısal olarak güvenli" gerekçesi **YANLIŞ** — `UIImagePickerController` **uygulamanın kendi sürecinde** `AVCaptureSession` açar; gerçek koruma **kapıdır**.
5. Önizleme ekranı: çoklu seçim şeridi, **altyazı her medyaya ayrı**, HD anahtarı (metin rozeti — ikon değil). ⚠️ Kapanış **yalnız** `Navigator.of(sheetContext).pop()` — `rootNavigatorKey` ile pop etme (turu 59b: `pop()` en üstteki route'u kapatır, araya giren arama ekranını öldürür).
6. Sıkıştırma: uzun kenar 1600px (HD 2560), `CompressFormat.jpeg` (HEIC/PNG→JPEG), ⚠️ **`keepExif: true` ASLA yazma** (varsayılan EXIF'i siler = GPS sızıntısı kapalı). Küçük resim 320px.
7. `FotoBalonu` + tam ekran görüntüleyici (`Hero` + `PageView` + `InteractiveViewer`). ⚠️ **Bellek:** `memCacheWidth`/`maxWidthDiskCache` zorunlu; `PageView` 3 tam çözünürlüklü görseli aynı anda tutarsa düşük RAM'li Android'de **çöker**. Test cihazı iPhone XS Max, düşük segment Android hiç test edilmiyor → Sentry OOM ölçümü.
8. `gal` paketi ile "Galeriye kaydet" + `NSPhotoLibraryAddUsageDescription`.
9. **Ayarlar ekranı** (yeni, `router.dart`'a rota): Medya sekmesi (Wi-Fi/hücresel × foto/video otomatik indirme) + Depolama sekmesi (toplam boyut + önbelleği temizle). ⚠️ "Ayar ekranı yok, sabit politika" kararı **KABUL EDİLMEDİ**: Türkiye'de hücresel veri sınırlı, kullanıcı kapatamazsa uygulamayı siler.
   - Varsayılan: küçük resim **her zaman**; foto Wi-Fi ✅ / hücresel ✅; video Wi-Fi ✅ / hücresel ❌.
   - ⚠️ **Dolaşım (roaming) tespiti YOK** (`connectivity_plus` vermiyor) → o seçenek **gösterilmez** (yalan vaat etmemek için).
10. Önbellek: `<Cache>/medya/` + LRU 500 MB + 30 gün. ⚠️ Cache vs Documents ayrımı kritik (OS Cache'i silebilir — indirilen medya için doğru).
11. Uygulama içi kalıcı şerit: "3 medya gönderiliyor" (arka planda FGS yok).
12. Karanlık tema kontrolü: görsel üstündeki saat hapı, ilerleme halkası, "indir" rozeti.

**DOĞRULAMA:** §3'ün altındaki **F. Test Listesi** (aşağıda).

**RİSK:** OOM ve lifecycle. **Korunma:** bellek sınırları + Faz 3 mandalı + Sentry ölçümleri.

---

### FAZ 7 — SES NOTU
**Amaç:** Basılı tut kaydet, kaydırarak iptal/kilit, dalga formu, dinlendi makbuzu.
**ÖNKOŞUL:** Faz 6.

**ADIMLAR**
1. `record: ^7.1.1`. **Yeni izin YOK**: `RECORD_AUDIO` (`AndroidManifest.xml:4`) ve `NSMicrophoneUsageDescription` (`Info.plist:61`) **zaten var**.
2. **🔴 SERT KAPI:** arama/oda/yayın (çalar fazı dahil) varken **kayıt VE oynatma YASAK**. `MedyaKapisi.sesBirimiSerbest()`. Gerekçe **ölçülmüş**: turu 64 `!pri` (`0x21707269` = `InsufficientPriority`), turu 65 `didActivate` hiç gelmiyor, turu 62-C Android ses rotası. `AppDelegate.swift:96-99` zaten "zorla toggle" yapıyor (~50-150 ms sağırlık).
   ⚠️ Kuyruğa alma **KABUL EDİLMEDİ**: arama dakikalarca sürer, "4 dakika sonra kendiliğinden başlayan kayıt" kabul edilemez. WhatsApp da engelliyor.
3. **🔴 Ses notu `SesSahipligi` defterine YAZILMAZ.** O defter `_odaTemizle`/`room_screen:435`/`live_broadcast:577`'de **`setAudioEnabled(false)` kararını** veriyor; ses notu oraya yazılırsa `aramaCanli` **yalan söyler**, ses birimi kapanmaz, iPhone'da mikrofon göstergesi sönmez.
4. **"Arama kazanır" yıkımı:** `SesNotuKontrol.kapat()` senkron, `sustur()` **400 ms timeout ile** await edilir. Çağrı noktaları `SesSahipligi.kaydol(...)` ile **yan yana**: `active_call_controller.dart:1348`, `:1763` (`_sesiAc(true)` öncesi), `:3066`; `room_screen:130/434`; `live_broadcast:109/576`; `live_viewer:131/714`; **`incoming_call_overlay` initState/dispose** (çalar fazı — bu kapı olmazsa iPhone'da hiç çalışmaz).
   ⚠️ 400 ms tavanı ZORUNLU (turu 67: zaman aşımsız `await CallSounds.durdur` ekranı asılı bıraktı); aşılırsa Sentry **gerçek olayı**.
5. `RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 44100, numChannels: 1, ios: IosRecordConfig(allowHapticsAndSystemSoundsDuringRecording: true))`.
   ⚠️ `aacLc` — opus Android 29+ ister, minSdk **24**.
   ⚠️ `allowHaptics...: true` — varsayılan `false` **gelen arama zilini bastırır**, kullanıcı aramayı kaçırır.
   ⚠️ Gerekçe metni "`manageAudioSession` alanı yok" **değil**, "Android AudioFocus + iOS proses geneli `useManualAudio`" olarak yazılır (ilki paket kaynağından doğrulanmadı; ikisi doğrulanmış ve kalıcı).
6. Dalga formu: `onAmplitudeChanged(100ms)` ile 60 kova toplanır, `media_assets.waveform` alanına yazılır. Ayrı analiz paketi yok.
7. Oynatıcı: `AudioPlayer(playerId: 'gebzem_sesnotu')` — `CallSounds`'unkinden **ayrı**. ⚠️ **iOS'ta `setAudioContext` ÇAĞRILMAZ** (bağlam GLOBAL — `call_sounds.dart:74-85` zaten yalnız Android'de çağırıyor). Android'de `AndroidAudioFocus.gainTransientMayDuck` (`gain` **değil**).
8. Kayıt sırasında arama gelirse: kayıt durur ve **TASLAK olarak saklanır** (silinmez), giriş çubuğunda "Gönder / Sil" şeridi.
9. `POST /chats/{chatID}/messages/{id}/played` + WS `receipt.played` (`To: [sender]`). ⚠️ Mevcut `receipt.read` **sohbet geneli**dir ve mesaj id taşımaz — semantiğini **değiştirme** (turu 59 mavi tik regresyonu).

**DOĞRULAMA:** §F test listesi C ve E blokları. **Özellikle:** iPhone'da "ses notu kaydederken arama geldi → kabul et → karşı taraf seni duyuyor mu" testi **5 kez** tekrarlanır; Sentry'de `ses notu yikimi 400ms icinde bitmedi` **çıkmamalı**.

---

### FAZ 8 — VİDEO (2. dalga, ilk madde)
**ÖNKOŞUL:** Faz 7 sahada sorunsuz.
**ADIMLAR:** `video_compress` (720p, ≤60 sn, tavan **16 MB**) + `video_player` + kendi Lucide kontrollerimiz (chewie yok) + **çok parçalı yükleme** (5 MB parça).
⚠️ **Çok parçalı reddi KABUL EDİLMEDİ:** ek maliyet 540K Class A = **$2,43/ay**; karşılığında hücresel hatta her kopmada sıfırdan başlama feda ediliyordu.
⚠️ Sıkıştırma tetikleyicisi **`SesSahipligi` veya sabit 250 ms DEĞİL**: `await CallRoomLock.calistir(() async {});` — sıra boşalınca teardown **tamamen** bitmiştir. Gerekçe: `SesSahipligi.birak` (`:3066`) yıkım kuyruğunun **üstünde**; o anda LiveKit odası hâlâ bağlı, kamera capture ve donanım H.264 kodlayıcı hâlâ açık. ⚠️ Sıkıştırmayı `CallRoomLock` **içinde** çalıştırma (global kilit).
⚠️ **Video oynatma arama sırasında engelli (fail-closed)** — `video_player`'ın iOS'ta `AVAudioSession` kategorisine dokunduğu **kaynaktan doğrulanmadı**. Bu faza **ölçüm maddesi** eklenir: `medya oynatma: kategori=.. mod=..` Sentry olayı; dokunmuyorsa gevşetilir. **Ölçmeden gevşetme.**

---

### FAZ 9 — BELGE
`file_picker` (⚠️ `withData: false` ZORUNLU) + `open_filex` (iç PDF görüntüleyici **yok**). Tavan **25 MB**. Uzantı beyaz listesi + kesin kara liste (`exe/apk/html/svg/js/bat/scr…`). R2'de **`application/octet-stream` + uzantısız anahtar** → tarayıcı/WebView **asla render edemez** (polyglot/XSS yapısal olarak kapalı). ⚠️ Dosya adı çizilirken **RTL override karakterleri temizlenir** (`\u202A-\u202E`, `\u2066-\u2069`) — `fatura‮gpj.exe` saldırısı.
**Belge arama sırasında SERBEST** (ses/kamera birimine dokunmaz). ⚠️ Tek istisna: arama sürerken >5 MB yükleme kuyruğa alınır.

---

### FAZ 10+ — 2. DALGA GERİ KALANI
Sırayla: sohbet medya galerisi → iletme (⚠️ **mimari karar önce**: `owner_id=$me` kapısı iletmeyi kilitliyor, referans sayımı modeli §9'da) → tek seferlik → anlık konum → kişi kartı → anket → şikâyet kuyruğu + admin medya kaldırma ekranı.

---

## 4. VERİTABANI DEĞİŞİKLİKLERİ

**TEK migration. Son mevcut: `013_call_hold.sql`.**
⚠️ Beş tasarım da "014" istiyordu ve üçü `messages_type_check`'i birbirinden habersiz yeniden kuruyordu. Bu birleşik dosya **tüm gelecek tipleri tek seferde** ekler; **sonraki hiçbir migration bu kısıta dokunmayacak**.

```sql
-- 014_medya.sql — MEDYA MESAJLASMA ALTYAPISI (BIRLESIK)
--
-- ⚠️ ADDITIVE: mevcut hicbir sutun daraltilmaz/kaldirilmaz/tip donusturulmez.
-- ⚠️ Migration calistiricisi (database.go:57-60) dosya basina TEK Exec kullanir
--    -> basit protokol -> ORTUK TEK TRANSACTION. Ya hep ya hic.
-- ⚠️ Hata durumunda main.go:55 log.Fatalf -> API HIC ACILMAZ. Bu yuzden CHECK
--    degisikligi ADA GUVENMEDEN, pg_constraint'ten ARANARAK yapilir.

-- ============ 1) MESSAGES.TYPE CHECK — TEK VE SON DEFA ============
-- ⚠️ Kisit 001_init.sql:55'te SATIR ICI tanimli; adi Postgres uretir ve
--    'messages_type_check' olmasi GARANTI DEGIL. Yanlis ada guvenirsek
--    DROP IF EXISTS sessizce hicbir sey yapmaz, ADD "already exists" ile
--    PATLAR ve migration YARIM kalir -> sonsuz cokme dongusu.
DO $$
DECLARE k text;
BEGIN
  SELECT conname INTO k FROM pg_constraint
   WHERE conrelid = 'messages'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) ILIKE '%type%location%';
  IF k IS NOT NULL THEN EXECUTE format('ALTER TABLE messages DROP CONSTRAINT %I', k); END IF;
END $$;

-- ⚠️ TUM GELECEK TIPLER BURADA. Faz 8/9/10'da bu kisita BIR DAHA DOKUNULMAYACAK.
-- ⚠️ 'system' HALA VAR (sunucunun kendi yazdigi arama kayitlari: calls/handler.go:1654,
--    calls/grup_sohbet.go:105 dogrudan INSERT eder) ama ISTEMCI BEYAZ LISTESINE
--    ASLA EKLENMEZ (turu 59b kimlik taklidi acigi).
-- ⚠️ 'location' KALIR — beyaz listeden cikarma onerisi KABUL EDILMEDI (ustkume kurali).
-- ⚠️ NOT VALID + ayri VALIDATE: yeni kume eskinin USTKUMESI, tam tablo taramasi
--    gereksiz; ACCESS EXCLUSIVE kilit suresi milisaniyeye iner.
ALTER TABLE messages ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text','image','video','audio','location','system',
                  'document','contact','poll')) NOT VALID;
ALTER TABLE messages VALIDATE CONSTRAINT messages_type_check;

-- ============ 2) MEDYA VARLIKLARI ============
CREATE TABLE IF NOT EXISTS media_assets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK (kind IN ('image','video','audio','document','avatar')),

    -- R2 nesne anahtarlari. TAM URL SAKLANMAZ: erisim her istekte imzalanir.
    -- ⚠️ Anahtarda kullanici id / sohbet id / telefon / dosya adi YOKTUR.
    object_key    TEXT NOT NULL UNIQUE,
    thumb_key     TEXT NOT NULL DEFAULT '',

    mime          TEXT NOT NULL,
    bytes         BIGINT NOT NULL DEFAULT 0,     -- COMMIT'te HeadObject ile DOGRULANMIS
    sha256        TEXT NOT NULL DEFAULT '',      -- dedup + moderasyon (hash bazli toplu kaldirma)
    width         INT NOT NULL DEFAULT 0,
    height        INT NOT NULL DEFAULT 0,
    duration_ms   INT NOT NULL DEFAULT 0,
    file_name     TEXT NOT NULL DEFAULT '',      -- belge gosterim adi (ANAHTARDA yok)
    waveform      TEXT NOT NULL DEFAULT '',      -- ses notu: 60 adet 0-99, virgullu

    status        TEXT NOT NULL DEFAULT 'beklemede'
                  CHECK (status IN ('beklemede','aktif','bagli','reddedildi','karantina','silindi')),
    reject_reason TEXT NOT NULL DEFAULT '',

    -- presign aninda ISTEMCI BEYANI; commit'te GERCEKLE karsilastirilir
    expected_bytes       BIGINT NOT NULL DEFAULT 0,
    expected_md5         TEXT   NOT NULL DEFAULT '',
    thumb_expected_bytes BIGINT NOT NULL DEFAULT 0,
    thumb_expected_md5   TEXT   NOT NULL DEFAULT '',

    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    committed_at  TIMESTAMPTZ,
    linked_at     TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ
);

-- sweeper: yetim 'beklemede' + baglanmamis 'aktif' + yasi dolmus
CREATE INDEX IF NOT EXISTS idx_media_sweep ON media_assets (status, created_at);
-- dedup kisa devresi (presign yolunda HER istekte kosar -> kismi index)
CREATE INDEX IF NOT EXISTS idx_media_dedup ON media_assets (owner_id, sha256)
    WHERE status IN ('aktif','bagli');
-- 5651: bir hash'in TUM kopyalarini tek hamlede kaldirmak
CREATE INDEX IF NOT EXISTS idx_media_sha ON media_assets (sha256) WHERE sha256 <> '';
CREATE INDEX IF NOT EXISTS idx_media_owner ON media_assets (owner_id, created_at DESC);

-- ============ 3) MESSAGES BAGLANTISI ============
-- ⚠️ ON DELETE SET NULL (CASCADE DEGIL): bir medya kaldirilinca MESAJ SATIRI DURUR
--    (balon "Bu icerik kaldirildi" yazar). CASCADE olsaydi bir medya temizligi
--    kullanicinin sohbet gecmisini SILERDI.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;

-- Idempotency: ag zaman asimindan sonra tekrar denenen POST IKINCI MESAJ URETMEZ.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_ref TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_messages_media ON messages (chat_id, id DESC)
    WHERE media_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_ref
    ON messages (chat_id, sender_id, client_ref) WHERE client_ref <> '';

-- ============ 4) SILME KUYRUGU ============
-- R2 DeleteObject satir ici denenir (UCRETSIZ); basarisiz olursa nesne SIZMASIN.
-- Ayrica: her surumdeki "TRUNCATE users CASCADE" rutininden ONCE object_key'ler
-- buraya kopyalanir, aksi halde sweeper o nesneleri BIR DAHA GOREMEZ.
CREATE TABLE IF NOT EXISTS media_delete_queue (
    id         BIGSERIAL PRIMARY KEY,
    object_key TEXT NOT NULL,
    tries      INT NOT NULL DEFAULT 0,
    last_error TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_delq ON media_delete_queue (tries, created_at);

-- ============ 5) SIKAYET / MODERASYON ============
CREATE TABLE IF NOT EXISTS message_reports (
    id          BIGSERIAL PRIMARY KEY,
    message_id  BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    reporter_id UUID   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason      TEXT   NOT NULL DEFAULT '',
    status      TEXT   NOT NULL DEFAULT 'acik'
                CHECK (status IN ('acik','kaldirildi','reddedildi')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (message_id, reporter_id)
);
CREATE INDEX IF NOT EXISTS idx_reports_acik ON message_reports (status, created_at DESC);

ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;

-- ============ 6) "DINLENDI" MAKBUZU (ses notu mavi mikrofon) ============
-- ⚠️ read_at'ten AYRI: sohbeti acmak mesaji "okundu" yapar ama ses notunu DINLEMEZ.
ALTER TABLE message_receipts ADD COLUMN IF NOT EXISTS played_at TIMESTAMPTZ;

-- ============ 7) EKSIK INDEX (okunmamis sayaci) ============
-- ListChats (chat/handler.go:333-335) her sohbet icin message_receipts'i tariyor;
-- 001_init.sql'de user_id uzerinde index YOK. Medya ile mesaj hacmi artacak.
CREATE INDEX IF NOT EXISTS idx_receipts_okunmamis ON message_receipts (user_id)
    WHERE read_at IS NULL;

-- ============ 8) AVATAR ============
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;
```

**Sonraki migration'lar (kısıta DOKUNMAZ):**
- `015_konum.sql` — `live_locations` tablosu + `messages.live_location_id`, `messages.contact_user_id` (2. dalga)
- `016_anket.sql` — `polls`, `poll_options`, `poll_votes` (2. dalga)

**Deploy güvenliği:** `database.Migrate` `main.go:56`'da, router `:96`'da → migration **HTTP servisi başlamadan** biter. Tek API instance (docker compose) → "yeni binary + eski şema" penceresi yok.
**Geri alma:** `R2_*` env'leri boşalt → `Enabled()=false` → medya uçları 503, istemci ataç butonunu gizler. Migration geri alınmaz (additive, zararsız).

---

## 5. YENİ/DEĞİŞEN API UÇLARI

| Yol | Metot | İstek | Yanıt | Yetki | Hatalar |
|---|---|---|---|---|---|
| `/media/upload` | POST | `{kind, mime, bytes, md5(b64), sha256, width, height, duration_ms, file_name, waveform, thumb:{mime,bytes,md5}}` | `{media_id, hazir, expires_in, asil:{url,headers}, kucuk:{url,headers}}` | Bearer + hesap askıda değil | 400 `desteklenmeyen dosya türü` · 413 `Dosya çok büyük (en fazla N MB)` · 429 `Çok fazla medya gönderdiniz` · 503 `Medya servisi kapalı` |
| `/media/upload/{id}/commit` | POST | — | `{media_id, kind, mime, bytes, width, height, duration_ms, file_name, waveform}` | Bearer + sahibi + `status='beklemede'` | 409 `yükleme bulunamadı veya süresi doldu` · 422 `dosya doğrulanamadı` (+Türkçe alt sebep) · 502 `depolamaya ulaşılamadı` |
| `/media/upload/{id}` | DELETE | — | 204 | Bearer + sahibi | 404 |
| `/media/{id}/url` | GET | — | `{asil, kucuk, expires_in:600, mime, bytes, file_name}` | Bearer + **sahibi VEYA mesajın bulunduğu sohbetin üyesi** | 403 `bu medyaya erişim yetkiniz yok` · 410 `medya artık mevcut değil` |
| `/chats/{chatID}/messages` | POST **(DEĞİŞTİ)** | `{type, content, media_id, client_ref, reply_to_id}` — ⚠️ `media_url` **KALDIRILDI** | **Tam mesaj nesnesi** (`{id, created_at, type, content, media:{...}, reply_to_id}`) | Bearer + üyelik + **engel kontrolü (YENİ)** | 400 `geçersiz mesaj tipi` / `medya eksik` / `medya bulunamadı veya zaten kullanıldı` · 403 `bu kullanıcıya mesaj gönderilemiyor` · 429 |
| `/chats/{chatID}/messages` | GET **(DEĞİŞTİ)** | `?before_id=&limit=` | `media` nesnesi + `client_ref` + `played` eklendi. ⚠️ `deleted_for_all` ise `media` **null** | Bearer + üyelik | — |
| `/chats/{chatID}/messages/{id}` | DELETE **(YENİ)** | — | `{message:"ok"}` | Bearer + **yalnız gönderen**, <60 dk | 403 `bu mesajı silemezsiniz` · 404 |
| `/chats/{chatID}/messages/{id}/played` | POST **(YENİ)** | — | `{ok:true}` | Bearer + üyelik | 403 · 404 |
| `/messages/{id}/report` | POST **(YENİ)** | `{reason}` | `{message:"ok"}` | Bearer + üyelik | 403 · 404 · 409 (zaten şikâyet edilmiş) |
| `/users/{id}/block` | POST / DELETE **(YENİ)** | — | `{message:"ok"}` | Bearer | 400 (kendini engelleme) · 404 |
| `/users/me` | PATCH **(DEĞİŞTİ)** | `{avatar_media_id}` | `{avatar_url}` (sunucu türetir) | Bearer + sahiplik | 400 · 403 |
| `/users/me` | GET **(DEĞİŞTİ)** | — | + `media_acik: bool` | Bearer | — |

**Yeni WS olayları** (`hub.go` **değişmiyor**, `Event.Payload` ham JSON):
| Olay | Payload | `To` |
|---|---|---|
| `message.new` **(genişledi)** | + `media:{id,kind,mime,bytes,width,height,duration_ms,file_name,waveform,thumb}`, `client_ref`. ⚠️ `media_url` alanı **boş string olarak kalır** (eski istemci `fromJson` kırılmasın) | üyeler |
| `message.deleted` **(yeni)** | `{message_id}` | üyeler **+ gönderen** |
| `receipt.played` **(yeni)** | `{message_id, user_id}` | `[sender_id]` |
| `ws.acildi` **(yerel sentetik)** | — | — (istemci içi) |

⚠️ **Yükleme ilerlemesi WS'ten GİTMEZ** — tamamen yerel durum. `hub.deliver` kuyruk dolunca mesajı **sessizce düşürüyor** (`hub.go:99-101`); güvenilmez kanal + gereksiz Redis publish.
⚠️ **Presigned URL WS payload'ında TAŞINMAZ** — istemci loglarına ve Sentry breadcrumb'ına düşer.

---

## 6. ÇAKIŞMA VE REGRESYON KORUMASI

### 6.1 Karar tablosu
| Medya işlemi | Arama / sesli oda / canlı yayın sürerken | Gerekçe |
|---|---|---|
| Galeriden / dosyadan seçme | ✅ SERBEST (**ama lifecycle mandalı ŞART** — §6.3) | Kamera/ses birimine dokunmaz |
| **Kamerayla çekim** | 🔴 **ENGELLİ** — panelden kaldırılır + gövdede ikinci kapı | iOS paylaşılan `videoCapturer` (turu 50 %14 tek taraflı video, turu 67 teardown yarışı) |
| **Ses notu kaydı** | 🔴 **ENGELLİ** | `record` `AVAudioSession` kategorisini yazar → turu 64 `!pri`, turu 65 `didActivate` yok, turu 62-C Android ses rotası |
| **Ses notu oynatma** | 🔴 **ENGELLİ** | `audioplayers` iOS'ta bağlamı GLOBAL uygular |
| **Video oynatma** | 🔴 **ENGELLİ (fail-closed)** + ölçüm maddesi | `AVPlayer` `.playback` kategorisi varsayımı; **doğrulanmadı**, ölçülecek |
| Fotoğraf görüntüleme | ✅ SERBEST | Ses birimine dokunmaz |
| Görsel sıkıştırma | ✅ SERBEST | Saf CPU, ~180 ms |
| **Video sıkıştırma** | 🟠 **KUYRUKTA BEKLER** → `CallRoomLock` boşalınca | Donanım H.264 kodlayıcı tek örnek |
| Fotoğraf/ses yükleme | ✅ SERBEST | ≤400 KB |
| Video/belge >5 MB yükleme | 🟠 KUYRUKTA BEKLER | Bant genişliği + `AramaServisi` FGS ile yarış |
| Belge seçme/açma | ✅ SERBEST | Hiçbir medya birimine dokunmaz |

### 6.2 Somut kod kapıları
1. **`medya_kapisi.dart`** — dört kaynaklı tek kapı (Faz 3, adım 1). ⚠️ `SesSahipligi` **tek başına** çalar fazını kaçırır; `mesgulMu` **tek başına** ekrana bakar. İkisi de gerekli.
2. **`MedyaSecici` mandalı** — beş lifecycle noktasında (Faz 3, adım 2).
3. **`CallRoomLock.calistir(() async {})`** — video sıkıştırma tetikleyicisi (Faz 8).
4. **Ayrı Dio** (`Authorization` yok, `addSentry()` yok) — imza bozulmasını ve anahtar sızıntısını tek kararla kapatır.
5. **`SesNotuKontrol.sustur()` 400 ms timeout** — ses notu hiçbir koşulda aramayı bloklamaz.
6. **Kuyruk oturum kapısı** — bayat token → 401 → tüm oturum silinmesi (turu 34-36) engellenir.

### 6.3 ⚠️ DOKUNULMAYACAKLAR
- `AndroidManifest.xml:36-37` `launchMode="singleInstance"` + `taskAffinity=""` — CallKit/kilit ekranı buna bağlı.
- `AramaServisi` FGS tip maskesine `dataSync`/`location` **EKLEME** — `AramaServisi.kt:88-101` maskeyi çalışma zamanında izinlerden hesaplıyor.
- `ws.goOffline()` (`ws.dart:108-121`) — kaldırılırsa kilit ekranında telefon çalmaz (turu 33).
- `chatMemberIDs` (`handler.go:421-425`) davranışı — `message.new`/`typing`/`receipt.read` ona bağlı. Yeni olaylar `To`'yu **açıkça** belirtir.
- `mesgulMu` mantığını **kopyalama** — çağır.
- `system` tipini istemci beyaz listesine **ekleme**.
- Arayüze **emoji koyma** (metin içine de). Yeni ikon = Lucide.

---

## 7. MALİYET

**Varsayımlar (TAHMİN, ilk ayda ölçülecek):** DAU %10/%30/%50 · kişi başına foto 1/2/5, ses 0,5/1/3, video 0,05/0,2/0,5 · foto 300 KB (sıkıştırılmış), ses 150 KB, video 4 MB, küçük resim 15 KB · **saklama 90 gün** · **kota 500 MB/kullanıcı/ay**.

| Kalem | Düşük (5K DAU) | **Orta (15K DAU)** | Yüksek (25K DAU) |
|---|---|---|---|
| Yeni veri / ay | 55 GB | **480 GB** | 1,9 TB |
| Depolama (90 gün birikimi, $0,015/GB-ay) | $2,5 | **$21,6** | $85,5 |
| Class A — PUT (asıl+küçük), ilk 1M ücretsiz | $0 | **$3,3** | $22 |
| Class B — HeadObject + imzalı GET, ilk 10M ücretsiz | $0 | **$0** | $4,5 |
| **Egress / bant genişliği** | **$0** | **$0** | **$0** |
| DeleteObject | $0 | $0 | $0 |
| **TOPLAM** | **≈ $3 / ay** | **≈ $25 / ay** | **≈ $112 / ay** |

**Karşılaştırma (aynı hacim, orta):** Images ile görseller **+$153** · Images Transformations **+$447** · Stream ile videolar **+$3.060** · AWS S3 egress **+$234**.
**Saklama 365 gün seçilseydi:** orta senaryo **$86/ay** (4×). → 90 gün seçildi.
**Sunucu:** medya cx33'ten geçmiyor; ek CPU yükü yalnız imza (HMAC) + commit'teki 256 KB Range GET (~230 GB/ay indirme, bellekte, diske yazılmadan).
**Disk (Postgres, 80 GB paylaşımlı):** `media_assets` ~1 GB/ay. ⚠️ `status IN ('reddedildi','silindi')` satırları **30 gün sonra fiziksel silinir**; erişim logu Postgres'e **değil** dönen dosyaya (logrotate+gzip) yazılır; `watchdog.sh`'a Postgres veri dizini boyut alarmı eklenir.

---

## 8. YAYIN ÖNCESİ ZORUNLU

**Güvenlik**
- [ ] `media_url` API alanı kaldırıldı, URL sunucuda türetiliyor (Faz 2)
- [ ] Bucket **PRIVATE**; medya `api.gebzem.app` üzerinden **asla** sunulmuyor
- [ ] Sihirli bayt beyaz listesi + SVG/HTML/JS/APK/EXE/ZIP/HEIC/GIF kesin yasak
- [ ] Sunucu tarafı EXIF/GPS reddi + video `moov` konum anahtarı taraması
- [ ] Sentry breadcrumb maskesi (imzalı URL sızıntısı)
- [ ] Redis Lua kota + **IP başına presign limiti** (hesap başına kota tek başına yetmez — ücretsiz kayıt) + yeni hesap (<24 sa) sıkı limiti
- [ ] `middleware.RequestSize(1 MB)` + `SendMessage` hız sınırı
- [ ] SigV4 açılış self-testi + her 403 Sentry gerçek olayı
- [ ] Kota **commit'te gerçek boyutla** uzlaştırılıyor (presign'da rezervasyon)

**Moderasyon / UGC (App Store 1.2 şartı)**
- [ ] **Engelleme** uçları + `SendMessage`'da engel kontrolü
- [ ] **Şikâyet** ucu + admin kuyruğu
- [ ] `DELETE /chats/{id}/messages/{id}` + R2 silme + WS
- [ ] Admin: `sha256` ile **toplu kaldırma** + kullanıcı askıya alma + `auth` middleware'inde askı kontrolü
- [ ] **PhotoDNA Cloud Service başvurusu — BUGÜN BAŞLATILMALI** (ücretsiz ama vetting süresi bilinmiyor; kritik yol olabilir). ⚠️ Cloudflare CSAM Scanning Tool'una **güvenilmeyecek**: private bucket + imzalı URL = cache MISS = araç fiilen devre dışı. Tarama **yükleme anında bizde**.

**Yasal (hukukçu teyidi şart)**
- [ ] BTK yer sağlayıcı **bildirimi** (belge değil; ilk başvuru ücretsiz). ⚠️ Sunucu Almanya'da — etkisi sorulacak
- [ ] **4 saatlik müdahale kabiliyeti**: tek tıkla kaldırma + 7/24 tebligat kanalı (abuse@gebzem.app / KEP) + anlık bildirim (bekci.gebzem.app'e monitor)
- [ ] Trafik/erişim logu (yükleme+indirme, IP+zaman+kimlik), **1 yıl**, append-only, dönen dosyada
- [ ] Aydınlatma Metni + Kullanım Şartları + Topluluk Kuralları + Saklama-İmha Politikası + **yurt dışına aktarım** dayanağı (Hetzner/Cloudflare/Sentry/Firebase)
- [ ] Kullanım Şartları'nda **"medya 90 gün sonra sunucudan silinir"** açıkça yazılı
- [ ] **"Uçtan uca şifreli" İDDİA EDİLMEYECEK**

---

## 9. AÇIK SORULAR — KULLANICIYA SORULACAK

**S1. Grup sohbeti medyadan önce mi, sonra mı?**
Bugün `INSERT INTO chats` üç yerde de `'direct'`; grup sohbeti UI'si **yok**. Belge paylaşımının asıl yeri (iş/veli/apartman grubu) ve anketin değerinin %90'ı grupta. **ÖNERİM: medyadan SONRA.** Fotoğraf ve ses notu 1:1'de tam değer veriyor; belge ve anket zaten 2. dalgada, o zamana kadar grup gelirse ikisi birden anlamlı olur.

**S2. Medya saklama süresi 90 gün — onaylıyor musunuz?**
90 gün sonra sunucudaki medya silinir, mesaj balonu "Bu içerik artık mevcut değil" der (indirilmiş kopya cihazda kalır). **ÖNERİM: EVET, 90 gün.** 365 gün faturayı 4× yapıyor ($25 → $86/ay orta senaryoda) ve prototipte karşılığı yok. Kullanım Şartları'nda açıkça yazılacak.

**S3. Emoji politikası — tepkiler (reaction) ve hediye simgeleri.**
İki karar aynı konuda ve ikisi de bekliyor (hediye simgeleri turu 62'den beri). **ÖNERİM:** (a) **Hediye simgeleri emoji kalsın** — o arayüz değil ürün içeriği, backend katalogu ve animasyonlar ona bağlı. (b) **Tepkiler Lucide tabanlı sabit 6'lı set** olsun (beğen/kalp/gülümse/şaşkın/üzgün/öfke) — arayüzde emoji yasağı korunur, WhatsApp deneyimi büyük ölçüde alınır. Tepkiler 2. dalga.

**S4. Video tavanı: 16 MB / 60 saniye mi?**
Üç tasarım üç farklı sayı verdi (16 MB/60sn, 32 MB/90sn). **ÖNERİM: 16 MB / 60 saniye.** Gerekçe: Türkiye'de hücresel hatta 32 MB yükleme çok parçalı olsa bile uzun sürüyor; 60 sn sohbet videosunun %95'ini karşılıyor; depolama maliyeti yarıya iniyor. Kullanıcı isterse ileride tek env değişikliğiyle yükseltilir.

**S5. Çıkartma (sticker) ve GIF?**
Harici servis (Giphy/Tenor) bağımlılığı + 5651 içerik filtreleme yükümlülüğü + çıkartma mağazası altyapısı. **ÖNERİM: GIF ve mağaza YOK; yalnız "kullanıcının kendi oluşturduğu çıkartma"** (galeriden foto → arka plan kaldırma → kaydet) 3. dalgada. Böylece harici içerik ve filtreleme yükümlülüğü hiç doğmaz.

**S6. Canlı konum (15 dk / 1 sa / 8 sa) yapılsın mı?**
Play Store arka plan konum izni **ayrı gerekçe formu** + uzun inceleme; 8 saat GPS pili bitirir; ön plan servisi `AramaServisi` ile aynı süreçte ikinci FGS demek. **ÖNERİM: HAYIR (şimdilik).** 2. dalgada yalnız **anlık konum** yapılsın — buluşma tarifi ("iğneyi at") ihtiyacının %90'ı bu. Canlı konum ayrı bir tur olarak, ürün oturduktan sonra değerlendirilir.

---

### F. TEST LİSTESİ (Faz 6-7 sonunda kullanıcının elle yapacağı)

**A · Temel:** 1 fotoğraf altyazılı gönder (balon anında, tik çıkıyor) · 5 fotoğraf birden (sıra bozulmuyor) · aynı fotoğrafı tekrar (belirgin hızlı — dedup) · kamerayla çek · sohbet listesinde ikon+"Fotoğraf" · kilitli telefonda push "Ahmet: Fotoğraf · altyazı" · **Türkçe karakterli 100 karakterlik altyazı → push'ta bozuk karakter YOK**.

**B · Ses notu:** basılı tut→titreşim+dalga → bırak→gönder · 0,5 sn bas → "basılı tutun" · sola kaydır→iptal · yukarı kaydır→kilit→Dinle→Gönder · karşıda dalga sürüklenebiliyor · 1x/1,5x/2x · yarım dinle→çık→dön→kaldığı yerden · gönderende mikrofon rozeti **maviye** dönüyor.

**C · 🔴 ÇAKIŞMA (en kritik):**
1. Görüntülü arama → küçült → sohbet → ataç: **"Kamera" satırı YOK**.
2. Aynı durumda galeriden fotoğraf gönder → gider, **karşı taraf videoyu KAYBETMEMELİ** (turu 50 regresyonu) ve **kamera kesintisi yaşanmamalı** (Faz 3 mandalı).
3. Aynı durumda mikrofon **pasif**: "Görüşme sürerken sesli mesaj kullanılamaz".
4. Aynı durumda ses notu balonuna dokun → çalmıyor, arama sesi bozulmuyor.
5. **Ses notu kaydederken arama geldir** → kayıt durur + **TASLAK kalır**, telefon çalar, kabul → **karşı taraf seni duyuyor**. iPhone'da **5 kez tekrarla** (turu 64/65 sınıfı).
6. Sesli odada aynı 1-4 → **oda sesi kesilmemeli**.
7. Canlı yayın yaparken aynı → **izleyicilerde kamera donmamalı** (turu 15).
8. Fotoğraf gönderirken arama geldir → arama normal çalar, yükleme kesintisiz biter.
9. Arama bitir → **hemen** mikrofona basılı tut → kayıt normal başlar (kapı açıldı).
10. **Android:** ses notu kaydet → hemen arama yap → ses **kulaklıktan** gelmeli (rota bozulmadı — turu 62-C).
11. **iOS:** ses notundan sonra üst çubuktaki **turuncu mikrofon göstergesi sönmeli**.

**D · Dayanıklılık:** uçak modu aç→gönder→"Bekleniyor"→kapat→**kendiliğinden** gider · yükleme %50'de uygulamayı öldür→aç→devam eder, **çift mesaj YOK** · yükleme sürerken sohbetten çık→dön→ilerleme duruyor · iptal (X)→balon gider, karşıya hiçbir şey gitmez · depolama dolu→net Türkçe hata.

**E · Güvenlik:** DB'de `messages.media_url` **boş**, `media_id` dolu · EXIF'li JPEG'i elle yükle→commit **422** · başkasının `media_id`'si→**403** · 61 presign→**429** · Sentry'de hiçbir olayda `X-Amz-Signature` **yok** · `{"type":"system"}`→**400**.

**F · Regresyon (bozulmamalı):** metin mesajı, tikler, "yazıyor…" · sesli/görüntülü arama · kilit ekranından kabul · sesli oda · canlı yayın · PiP · GSM bekletme · **arayüzde emoji YOK, tüm yeni ikonlar Lucide** · tüm yeni metinlerde Türkçe karakterler doğru · karanlık tema.