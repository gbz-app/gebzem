# ENTEGRASYON RİSKİ DENETİMİ — MEDYA ÖZELLİĞİ vs MEVCUT ÇALIŞAN SİSTEMLER

Tüm iddialar kaynaktan okundu. Aşağıda **tasarımların GÖRMEDİĞİ** riskler önce, gördüğü ve doğru çözdüğü yerler sonra.

---

## A. ALTI SORUNUN NET CEVABI

| Soru | Cevap |
|---|---|
| Sohbette **kamera** açmak aramayı/yayını öldürür mü? | **EVET, iki ayrı yoldan.** (1) iOS paylaşılan `videoCapturer` (tasarımlar bunu görmüş, engelliyor). (2) **Tasarımların GÖRMEDİĞİ:** picker açılışı `AppLifecycleState.paused/inactive` üretir ve mevcut lifecycle kodu bunu "arka plana geçti" sanıp **kamerayı KENDİ kapatır** — galeri seçiminde bile. Bkz. **Y2**. |
| Sohbette **ses notu** aramanın/odanın sesini öldürür mü? | **EVET.** `record` iOS'ta `AVAudioSession` kategorisini yazar; `AppDelegate.swift:96-99` zaten "zorla toggle" yapıyor. Sert kapı ZORUNLU (tasarım doğru). **Ses notu `SesSahipligi` defterine YAZILMAMALI** — doğrulandı, gerekçesi **Y4**'te. Ama kapının kaynak listesi eksik: **Y4**. |
| Büyük dosya yüklerken **WS/arama sinyali** etkilenir mi? | Yükleme kendisi WS'i etkilemez. **AMA** picker/kamera açılışı `paused` üretir → `main.dart:505-511` `ws.goOffline()` → sunucu kullanıcıyı **anında offline** yapar (`chat/handler.go:106-111`). Arama sürerken `call.held`/`call.ended` WS olayları kaçar. Bkz. **O1**. |
| Yeni migration'lar mevcut sorguları bozar mı? | **`SELECT *` HİÇBİR YERDE YOK** (backend genelinde 0 sonuç) → sütun eklemek Scan sırasını kırmaz. **AMA iki gerçek risk var:** (a) dört tasarımın DÖRDÜ de `014` numarasını ve `messages_type_check`'i istiyor → **son uygulanan öncekinin tiplerini SİLER** (**O4**); (b) migration hatası `log.Fatalf` (`main.go:55-57`) → **API HİÇ AÇILMAZ** (**Y6**). |
| Tip beyaz listesine yeni tip eklemek turu 59b **kimlik taklidi** açığını geri getirir mi? | **HAYIR** — `system` dışarıda kaldığı sürece. `document`/`poll`/`contact` gönderen kimliği taşır, `_CallLogChip` yoluna girmez. **AMA:** `chat_screen.dart:251` dallanması `type=='system'` → `_CallLogChip`, aksi → `_Bubble`. Yeni tip **eklemek** güvenli; `system`'i eklemek açığı geri getirir. Tasarımların dördü de doğru karar vermiş. |
| Önizleme (`onizleme()`) ve `call:ended:*` ayrıştırması yeni tiplerle **çakışır mı**? | **HAYIR.** `AramaKaydi.coz()` yalnız `lastType=='system'` dalından çağrılıyor (`chats_screen.dart:238-260`) ve `content.startsWith('call:')` kapısı var. Yeni tipler o dala HİÇ girmez. **Küçük sorun:** yeni tipler `default:` dalına düşer → **ham `content` basılır** (`chats_screen.dart:257-259`). Bkz. **D1**. |

---

## B. YÜKSEK RİSKLER

### Y1 — `launchMode="singleInstance"` + `taskAffinity=""` → **image_picker / file_picker Android'de SONUÇ DÖNDÜRMEYEBİLİR**
**Severity: YÜKSEK** · `mobile/android/app/src/main/AndroidManifest.xml:36-37`

```xml
android:launchMode="singleInstance"
android:taskAffinity=""
```

`singleInstance` tanım gereği: *"activity her zaman kendi görevinin TEK üyesidir; buradan başlatılan her activity AYRI bir görevde açılır."* `startActivityForResult` **farklı göreve** giden activity için `RESULT_CANCELED`'ı **anında** döndürür. `image_picker`, `file_picker`, `open_filex`, `record`'un izin akışı — hepsi `startActivityForResult`/`ActivityResultContracts` üzerine kurulu.

**Somut senaryo:** Kullanıcı ataç → Galeri'ye basar. Photo Picker açılır (ayrı görevde), kullanıcı fotoğraf seçer, ama `pickMultiImage()` Future'ı **null ile çoktan tamamlanmıştır**. Kullanıcı "hiçbir şey olmuyor" der. Ya da daha kötüsü: seçici ayrı görevde açık kalır, MainActivity arka plana düşer, `paused` → **Y2**'deki kamera kapanması + `goOffline()` tetiklenir.

**Bu satır CallKit için konuldu** (`git log -S singleInstance` → `ecc63ac "arama: kilit ekrani / uygulama kapaliyken gelen arama (CallKit + VoIP push)"`, `oturum.md:387`). Yani **değiştirmek turu 33'ün "kilit ekranında telefon çalmıyor" regresyonunu riske atar.**

**Korunma yolu (sırayla):**
1. **ÖLÇ, VARSAYMA.** Sevkten önce tek özellikli bir deneme build'i: mevcut manifest ile `image_picker.pickImage()` gerçek Android cihazda sonuç döndürüyor mu? (Emülatör yeterli.) Bu ölçüm yapılmadan medya fazına başlanmamalı.
2. Kırıksa: `launchMode`'u **değiştirme**. Bunun yerine picker'ı **kendi kaydettiğimiz ayrı bir şeffaf Activity**'den (`MedyaSeciciActivity`, `launchMode` varsayılan `standard`, `taskAffinity` varsayılan) başlat ve sonucu MethodChannel ile Dart'a döndür. CallKit yolu hiç etkilenmez.
3. ⚠️ **YAPMA:** `singleInstance` → `singleTop` denemesini "hızlı çözüm" diye sevk etme; full-screen intent + `showWhenLocked` davranışı bu bayrağa bağlı ve regresyonu ancak kilitli telefonda görülür.

---

### Y2 — Picker açılışı **"arka plana geçiş" sanılıyor**: görüntülü aramada kamera KAPANIYOR, PiP açılıyor
**Severity: YÜKSEK** · `mobile/lib/features/calls/active_call_controller.dart:1494-1595`

Dört tasarım da "Galeriden seçme ✅ SERBEST — kamera/ses birimine dokunmaz" diyor. **Bu premis yanlış**, çünkü sorun picker'ın kamerayı açması değil, **bizim lifecycle kodumuz**:

```dart
// active_call_controller.dart:1496-1512
final arkaPlanaGidiyor = state == AppLifecycleState.inactive && onceki == AppLifecycleState.resumed;
if (Platform.isIOS && (arkaPlanaGidiyor || tekrarPenceresi) && ... ) {
  unawaited(PipService.iosPipBaslat());          // <-- PHPicker açılırken PiP başlatılır
}
// :1520-1527
if (Platform.isIOS && state == AppLifecycleState.inactive && ... && _camOn) {
  unawaited(iosArkaPlanKamerayiTazele());         // <-- capture session yeniden yapılandırma
}
// :1565-1595
if ((state == paused || state == hidden) && ... && _camOn) {
  ... _camOn = false; _room?.localParticipant?.setCameraEnabled(false);   // <-- KAMERA KAPANIR
}
```

**Somut senaryo (Android):** Görüntülü arama sürüyor, kullanıcı aramayı küçültüp sohbete girdi, ataç → Galeri. Picker Activity öne gelir → Flutter `inactive` → `paused`. `pipBekleniyor = Platform.isAndroid && _pipIzinliSon` **true** (görüntülü arama, `:716`) → 900ms sonra `_camOn=false; setCameraEnabled(false)`. Ayrıca `MainActivity.kt:246` `setAutoEnterEnabled(pipIzinli)` **true** → Android 12+ picker açılırken **PiP penceresi çıkabilir**. Kullanıcı fotoğraf seçip dönünce `_kameraOtoAc()` kamerayı geri açar ama karşı taraf 3-10 saniye **"Kamera duraklatıldı"** görmüştür.

**Somut senaryo (iOS):** `PHPickerViewController` süreç dışıdır; sunumu uygulamayı `.inactive` yapar. `PipService.iosPipBaslat()` çağrılır → PiP açılamaz (uygulama gerçekte ön planda) → AVKit `failedToStartPictureInPicture` → `_iosPipBasarisiz()` (`:1120`). Oradaki koruma `if (_sonYasamDurumu == AppLifecycleState.resumed) return;` — **biz `inactive`'iz, kapı GEÇER** → `setCameraEnabled(false)`. Turu 53'te tam olarak bu zincir "app switcher'da kamera kapanıyor" olarak teşhis edilmişti; picker onu **yeni bir kapıdan** geri getiriyor.

**Korunma yolu:**
- `medya_kapisi.dart` içine **zaman sınırlı senkron mandal**:
  ```dart
  class MedyaSecici {
    static DateTime? _acildi;
    static void ac()  => _acildi = DateTime.now();
    static void kapat() => _acildi = null;
    /// ⚠️ ZAMAN SINIRI ZORUNLU: mandal sızarsa kamera-mute yedegi KALICI olarak ölür.
    static bool get acik =>
        _acildi != null && DateTime.now().difference(_acildi!) < const Duration(seconds: 45);
  }
  ```
- Mandal, picker çağrısından **SENKRON ÖNCE** set edilir (`await` ile arasına hiçbir şey girmeden — turu 68'in "gövdeyi kuyruğa sararken alan okuma anı" dersi), `finally`'de düşürülür.
- `active_call_controller.dart` lifecycle metodunun **ÜÇ dalına da** ilk kapı olarak konur: PiP başlat (`:1504`), `iosArkaPlanKamerayiTazele` (`:1520`), kamera-mute (`:1565`).
- ⚠️ **YAPMA:** Mandalı `resumed` dalına da koyma — `_kameraOtoAc()` / `_kesintidenTopla()` dönüşte çalışmalı.
- ⚠️ **YAPMA:** Mandalı `bool` sabit yapma (sızarsa arka planda kamera kapanmaz = turu 15'in "izleyiciler donmuş kare görüyor" sınıfı geri gelir).

---

### Y3 — Aynı lifecycle deliği **oda/yayında**: her picker açılışında ses birimi ZORLA YENİDEN KURULUYOR, yayıncının kamerası kapanıyor
**Severity: YÜKSEK** · `mobile/lib/features/rooms/room_screen.dart:159-188` · `live_broadcast_screen.dart:127-196` · `live_viewer_screen.dart:231-240`

```dart
// room_screen.dart:170
if (!SesSahipligi.aramaCanli) _sesiAc(true);
```
`_sesiAc(true)` → native `setAudioEnabled` → `AppDelegate.swift:96-99`:
```swift
if s.isAudioEnabled { NSLog("gebzem/audio unit rebuild (zorla toggle)"); s.isAudioEnabled = false }
```
Yorumun kendisi maliyeti yazıyor: **~50-150ms sağırlık**.

**Somut senaryo:** Kullanıcı sesli odada konuşuyor, sohbete geçip fotoğraf gönderiyor. Picker açılışı+kapanışı = **iki lifecycle turu** = odada iki kez ses kesilmesi. Kullanıcı "oda takılıyor" der, teşhis edilemez (hata `catch (_)` ile yutuluyor, `room_screen.dart:316`).

**Daha ağırı — yayıncı:** `live_broadcast_screen.dart:144-159`, `paused` → 900ms sonra `_kameraAcik = false; setCameraEnabled(false)`. Yayıncı sohbetten fotoğraf seçerken **TÜM İZLEYİCİLER yayıncının kamerasını kaybeder**. Turu 15'te tam olarak bu semptom ("yayıncı alta alınca izleyenlerin ekranı donuyor") çözülmüştü.

**Korunma yolu:** **Y2**'deki aynı mandal, üç ekranın `didChangeAppLifecycleState` metotlarında da okunur.
- ⚠️ `resumed` dalını **komple `return` ile kesme** — `room_screen.dart:186` `_detayYenile()` ve `live_broadcast_screen` `_nabizAt()` çalışmaya DEVAM etmeli. Nabız kesilirse `stream:{id}:pub` TTL 45sn'de düşer ve **sweeper yayını KAPATIR** (turu 15 notu).
- Yalnız `_sesiAc(true)`, kamera-mute ve `iosPipBaslat` satırları atlanmalı.

---

### Y4 — Ses notu kapısının kaynak listesi EKSİK; ayrıca `SesSahipligi`'ye yazmak YIKICI olur
**Severity: YÜKSEK** · `mobile/lib/features/calls/medya_beklet.dart:29-53` · `active_call_controller.dart:1348, 3066`

**(a) `SesSahipligi` çalar fazını GÜVENİLİR kapsamaz.** Kayıt `SesSahipligi.kaydol("arama_$id")` `baslat()` içindedir (`:1348`) — giden aramada çalar fazını kapsar, ama **gelen aramada** kabul edilene kadar yalnız `callServiceProvider` doludur. Ayrıca iOS'ta gelen arama `call_provider.dart:211` gereği WS'ten HİÇ gelmez, CallKit'ten gelir → `CallKitService.islenenler` bakılmalı.

**Somut senaryo:** iPhone'da CallKit gelen arama çalıyor (kullanıcı henüz kabul etmedi), kullanıcı sohbette mikrofona basılı tutuyor. `SesSahipligi` **boş**, `activeCallProvider.arama` **null**, `callServiceProvider` iOS'ta **null** (WS atlanıyor) → **kapı GEÇER**, `record` `AVAudioSession` kategorisini yazar → CallKit zili ve kabul sonrası ses birimi bozulur (turu 64 `!pri` sınıfı).

**Korunma:** Kapı **dört kaynağı birden** sorsun:
```dart
SesSahipligi.ozet.isNotEmpty                       // arama/oda/yayin canli
|| ref.read(activeCallProvider).arama != null      // hazirlik dahil
|| ref.read(callServiceProvider) != null           // Android on plan gelen arama
|| CallKitService.islenenler.isNotEmpty            // ⚠️ iOS gelen arama TEK BU YOLDAN gorunur
```

**(b) Ses notunu `SesSahipligi`'ye kaydetme — DOĞRULANDI, kesinlikle yapma.** `active_call_controller.dart:2932-2938` (`_odaTemizle`) ve `room_screen.dart:435` / `live_broadcast_screen.dart:577` / `live_viewer_screen.dart:715` bu deftere **`setAudioEnabled(false)` kararını** veriyor. Ses notu oraya yazılırsa `aramaCanli`/`odaVeyaYayinCanli` **yalan söyler**, ses birimi kapanmaz, iPhone'da mikrofon göstergesi sönmez. BELGE-SES tasarımı bunu doğru söylüyor — **onaylanmıştır, değiştirilmemeli**.

**(c) `audioplayers` global bağlam.** `call_sounds.dart:20` `AudioPlayer(playerId: 'gebzem_arama')` ve `:74-85` `setAudioContext` **yalnız Android'de** çağrılıyor (iOS'ta bağlam GLOBAL olduğu için bilerek atlanmış). Ses notu oynatıcısı **aynı kuralı izlemek zorunda**: iOS'ta `setAudioContext` ÇAĞIRMA. BELGE-SES tasarımı bunu da doğru yakalamış.

---

### Y5 — Video sıkıştırma kuyruğunun tetikleyicisi YANLIŞ: `SesSahipligi` boşaldığında oda HÂLÂ bağlı
**Severity: YÜKSEK (video akışı için)** · `active_call_controller.dart:3038, 3066, 2914-2919, 2947-2961`

GÖRSEL-VIDEO §7.3: *"arama/oda/yayın bitip muhafız düşünce **250 ms gecikmeyle** kuyruk devam eder."* Bu **yetmez**, çünkü:

```dart
// leave() :3038  — teardown KUYRUĞA konur (henüz çalışmadı)
_kapatOdayiKuyrugaKoy();
// :3066 — ses sahipliği BURADA düşer (kapının ÜSTÜNDE, turu 73b kararı)
SesSahipligi.birak("arama_$id");
```
Gerçek yıkım ise `CallRoomLock` sırasında, **260ms bekleme + `disconnect().timeout(1200ms)` + `dispose().timeout(1200ms)`** sonrasında (`:2914-2919`, `:2954-2961`). Yani `SesSahipligi.aramaCanli == false` olduğunda **LiveKit odası hâlâ bağlı, kamera capture ve donanım H.264 kodlayıcı hâlâ açık.**

**Somut senaryo:** Görüntülü arama bitti. 250ms sonra `VideoCompress.compressVideo` MediaCodec donanım kodlayıcı ister; `_odaTemizle` hâlâ `disconnect()` bekliyor → tek kodlayıcı örneğinde `MediaCodec.CodecException` ya da (daha kötü) **sonraki aramanın kamerası açılmaz** (turu 68'in "kamera meşgul" sınıfı).

**Korunma:** Tetikleyici `SesSahipligi` veya sabit gecikme DEĞİL, projenin **zaten var olan doğru primitifi** olsun:
```dart
// medya_kuyrugu.dart — sıkıştırmadan HEMEN ÖNCE
await CallRoomLock.calistir(() async {});   // sıra boşalınca teardown TAMAMEN bitmiştir
```
`CallRoomLock` (`call_room_lock.dart:22-31`) seri bir Future zinciri; boş bir iş kuyruğa girip döndüğünde önündeki tüm oda kapanışları bitmiştir. **Bu tam da o kilidin varoluş sebebi.**
- ⚠️ **YAPMA:** Sıkıştırmayı `CallRoomLock` **içinde** çalıştırma (kilit global; oda/yayın girişini 30 saniye bloklarsın).

---

### Y6 — Migration: `messages_type_check` **adına güvenmek servisi tamamen düşürür**
**Severity: YÜKSEK** · `backend/cmd/api/main.go:55-57` · `backend/internal/database/database.go:57-60`

```go
if err := database.Migrate(ctx, db); err != nil { log.Fatalf("migration: %v", err) }
```
Migration hatası **`log.Fatalf`** → API süreci ölür → `docker compose` restart döngüsü → **tüm sistem kapalı** (arama, oda, yayın dahil).

**ALTYAPI tasarımı §3 blok 5** şunu yazıyor:
```sql
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check;
ALTER TABLE messages ADD CONSTRAINT messages_type_check CHECK (...);
```
Kısıt `001_init.sql:55`'te **satır içi** tanımlı; adı Postgres tarafından üretilir ve `messages_type_check` olması **garanti değil**. Ad farklıysa: `DROP IF EXISTS` **sessizce hiçbir şey yapmaz**, `ADD` ise *"constraint already exists"* ile **patlar** → migration `schema_migrations`'a yazılmaz → **her açılışta tekrar patlar.**

**Korunma:** GÖRSEL-VIDEO / BELGE-SES / ANKET / KONUM tasarımlarındaki `pg_constraint`'ten **arayarak bulan** `DO $$` bloğunu kullan (üç tasarım bunu doğru yapıyor). ALTYAPI'nın kısa versiyonu **kullanılmamalı**.
- ⚠️ Ayrıca sevkten önce canlı DB'de doğrula: `SELECT conname FROM pg_constraint WHERE conrelid='messages'::regclass AND contype='c';`

---

## C. ORTA RİSKLER

### O1 — Picker açılışı `ws.goOffline()` tetikler → arama sinyali WS'ten kesilir
**Severity: ORTA** · `mobile/lib/main.dart:505-511` · `mobile/lib/core/ws.dart:108-121` · `backend/internal/chat/handler.go:106-111`

`paused` → `ws.goOffline()` → `{"type":"bg"}` → sunucu `return` → **Unregister** → kullanıcı anında offline.

**Somut senaryo:** Arama sürerken sohbetten fotoğraf gönderiliyor. Picker açık olduğu ~10 saniye boyunca WS kapalı; o pencerede karşı taraf kapatırsa `call.ended` **kaybolur** (turu 61'in `call.held` kaybıyla aynı sınıf). Kurtaran: `_durumKontrol` 3sn yoklaması ve `/calls/{id}/status`. Yani **ölümcül değil ama gecikme üretir**.

**Korunma:** `goOffline()`'a **DOKUNMA** (turu 33: `bg` gitmezse kilit ekranında telefon çalmaz). Bunun yerine dönüşteki `resumed` dalında (`main.dart:501-504`) `ws.connect()` **zaten var** — yeterli. Yalnız Sentry'e tek ölçüm: `medya secici acikti: ws kapali kaldi=Nms`.
- ⚠️ **YAPMA:** Mandal ile `goOffline()`'ı atlama. Mandal sızarsa uygulama gerçekten arka plana geçtiğinde de `bg` gitmez → **kilit ekranı araması çalmaz** = turu 33 regresyonu.

### O2 — Kalıcı medya kuyruğu + `api.dart` 401 → OTURUM SİLİNİR, kullanıcı kayıt/login ekranından atılır
**Severity: ORTA** · `mobile/lib/core/api.dart:52-63`

Muafiyet listesi: `/auth/`, `/calls/`, `/users/me/voip-token`, `/users/me/fcm-token`. Medya uçları **listeye eklenmemeli** (dört tasarım da doğru diyor) — ama o zaman şu senaryo açık kalır:

**Somut senaryo:** Kullanıcı çıkış yaptı (`storage.clear()`), kuyrukta bekleyen bir video var. Kuyruk **uygulama ömürlü** (`autoDispose` değil — tasarım gereği). Uygulama açılışında `MedyaKuyrugu.surdur()` → `POST /media/upload` → token yok/bayat → **401** → `storage.clear()` + `ref.invalidate(authProvider)` → GoRouter sıfırdan kurulur → **kullanıcı kayıt ekranından LOGIN'e fırlar, açık izin diyalogları düşer.** Turu 34-36'da tam olarak bu hata yaşandı ve o zaman iki uç muaf edilmişti.

**Korunma:**
1. Kuyruk işçisi **oturum kapısı** taşısın: `if (await storage.token == null) return;` — VoIP token yolundaki desenin aynısı.
2. Çıkış (logout) akışında kuyruk temizlensin — `SesSahipligi.sifirla()`'nın çağrıldığı yerle **aynı satırda** (`medya_beklet.dart:49` serhi: "sızan bir kayıt ses birimini kalıcı kilitler" — kuyruk için de aynısı geçerli).
3. ⚠️ **YAPMA:** `/media/` yolunu muafiyet listesine ekleme (bayat oturum tespiti orada da doğru davranış).

### O3 — İki tasarım **birbiriyle çelişen erişim modeli** öneriyor; ikisi aynı turda uygulanamaz
**Severity: ORTA (sevk engeli)**

| | GÖRSEL-VIDEO §0.3 | BELGE-SES §2.2 / ALTYAPI §0.2-B |
|---|---|---|
| Bucket | **PUBLIC** custom domain `medya.gebzem.app` | **PRIVATE** + `GET /media/{id}/url` imzalı |
| DB'de | `object_key` → URL okuma anında türetilir | `object_key` → imzalı URL her istekte |
| İstemci | doğrudan `cached_network_image(media_url)` | önce `/url` ucu, sonra indirme |

`media_assets` şeması, `messages` JSON sözleşmesi ve Flutter önbellek katmanı **üç tasarımda üç farklı**. Karışık uygulanırsa: bir yerde `media_url` gömülü gelir, başka yerde boş → balon "medya kaldırıldı" der.

**Korunma:** Tek karar verilmeden kod yazılmamalı. **Öneri: PRIVATE + `GET /media/{id}/url`** — çünkü (a) 5651 "4 saat içinde kaldırma" yükümlülüğünü public capability-URL ile karşılayamazsın (URL sızmışsa kaldırdım diyemezsin), (b) `sentry_dio` kurulu (`pubspec.yaml`) ve public URL'ler breadcrumb'a düşer, (c) DB'de `object_key` tutulduğu için ileride public'e geçiş **tek sunucu fonksiyonu**, istemci değişmez.

### O4 — Dört tasarım da **`014`** numarasını ve **aynı CHECK'i** istiyor → son uygulanan öncekinin tiplerini SİLER
**Severity: ORTA** · `backend/internal/database/database.go:39-43` (`sort.Strings`)

Dosya adına göre alfabetik: `014_anket.sql` → `014_konum_kisi.sql` → `014_media.sql` → `014_medya.sql`. Her biri `messages_type_check`'i **düşürüp kendi listesiyle** yeniden kuruyor.

**Somut senaryo:** Anket + belge aynı turda sevk edilir. `014_medya.sql` (belge) listesi `('text','image','video','audio','location','system','document')` — **`poll` YOK**. Anket migration'ı önce uygulandığı için `poll` CHECK'ten **düşer** → anket gönderimi `INSERT` sırasında 500 verir, sebebi teşhis edilemez.

**Korunma:**
1. Sevk sırası netleşince **yeniden numaralandır** (014, 015, 016…).
2. CHECK'i **yalnız BİR migration** değiştirsin; o migration **tüm gelecek tipleri birden** eklesin: `('text','image','video','audio','location','system','document','contact','poll')`. Diğerleri kısıta **DOKUNMASIN**.
3. ⚠️ `NOT VALID` + ayrı `VALIDATE` kullan (üstküme olduğu için tarama gereksiz, ACCESS EXCLUSIVE kilit süresi milisaniyeye iner).

### O5 — `rows.Scan` hatası mesajı/sohbeti **SESSİZCE DÜŞÜRÜYOR** — yeni sütunlarla risk büyür
**Severity: ORTA** · `backend/internal/chat/handler.go:258-263` ve `:375-381`

```go
for rows.Next() {
    var m msg
    if err := rows.Scan(...); err == nil { out = append(out, m) }   // hata YUTULUYOR
}
```
`SELECT *` yok, sütunlar açık — ama `LEFT JOIN media_assets` ile gelen **NULL sütunlar** `COALESCE`'siz taranırsa Scan patlar ve **mesaj listeden kaybolur, hiçbir yere log düşmez.** `ListChats` aynı desende → **sohbet listeden yok olur**.

**Korunma:** Scan hatasını `log.Printf` + `Sentry.CaptureMessage` ile görünür yap (CLAUDE.md'nin tekrarlayan tuzağı: *"bu patlarsa telemetride görür müyüm?"*). Tüm nullable JOIN sütunlarına `COALESCE(...)` ya da `*T` işaretçi kullan; `msg` struct alan sırası SELECT ile **birebir** (`:377` uyarısının aynısı).

### O6 — `SendMessage`'da hız sınırı ve gövde tavanı YOK
**Severity: ORTA** · `backend/cmd/api/main.go:96-102`

Middleware zinciri: `RequestID, RealIP, Logger, sentryhttp, Recoverer`. `middleware.RequestSize` **yok**, hız sınırı **yok**. Medya öncesi bu düşük riskti (metin mesajı ucuz); presign/commit uçları eklendiğinde **R2 kotası ve fatura** doğrudan buna bağlanır.

**Korunma:** Korumalı grubun başına `r.Use(middleware.RequestSize(1 << 20))` (medya API'den geçmiyor, 1 MB bol). Presign ucuna Redis Lua kota (`streams/guests.go:52` deseni). ⚠️ `/livekit/webhook` (`main.go:133`) bu grubun DIŞINDA — etkilenmez, doğru.

### O7 — `preview[:80]` bayt kesme
**Severity: ORTA** · `backend/internal/chat/handler.go:207-209`

Mevcut hata; medya ile **büyür** çünkü belge adı ve altyazı push gövdesine girecek. `"Sözleşme özeti çalışması ğüşiöç…"` 80. baytta ortadan bölünüp geçersiz UTF-8 üretir.
**Korunma:** `if r := []rune(preview); len(r) > 80 { preview = string(r[:80]) }`. Dört tasarım da aynı fix'i öneriyor — **tek bir turda, tek bir kez** uygulanmalı.

---

## D. DÜŞÜK RİSKLER

**D1 — Sohbet listesi önizlemesi yeni tipleri tanımaz** · `mobile/lib/features/chats/chats_screen.dart:219-236, 238-260`
`document`/`contact`/`poll` → `_previewIkon()` `default: return null` (ikon yok) ve `_preview()` `default: return chat.lastMessage` → **ham içerik**. `contact` için `content=''` → boş satır; `document` için altyazı yoksa boş satır.
**Korunma:** Her yeni tip için `case` ekle. ⚠️ `AramaKaydi.coz()` ile **çakışma YOK** (yalnız `system` dalında, `call:` önekli) — bu doğrulandı.

**D2 — `_Bubble` yeni tipleri düz metin basar (eski istemci + geçiş dönemi)** · `chat_screen.dart:251-261`
Dallanma yalnız `system` vs diğer. Yeni tip eklenmeden sevk edilen bir sunucu sürümünde `type='document'` mesajı **düz metin balonu** olur — `content` altyazı olduğu için zararsız, ama `media_id`li ve altyazısız bir belgede **bomboş balon** çıkar.
**Korunma:** İstemci sunucudan ÖNCE sevk edilmemeli; ya da `_Bubble` boş `content` + bilinmeyen tip için "Bu mesaj bu sürümde görüntülenemiyor" bassın.

**D3 — Ataç yer tutucusu `InputDecoration` içinde** · `chat_screen.dart:291`
Yorum (`// Faz 2: atas (medya) butonu buraya`) `InputDecoration` bloğunun içinde — yani `prefixIcon` yuvası. `TextField` çok satırlı olduğu için `prefixIcon` dikeyde ortalanıp zıplar. BELGE-SES tasarımı bunu doğru yakalamış (**Row'un ilk çocuğu**); GÖRSEL-VIDEO "`:291`'in yeri" diyor — **Row'a alınmalı**.

**D4 — `Message.fromJson` ileri uyumlu, ama `sender_id` null-güvenli DEĞİL** · `mobile/lib/features/chats/models.dart:75-84`
`senderId: j['sender_id'] as String` — cast, `??` yok. Yeni WS payload'ları `sender_id`'yi taşıdığı sürece sorun yok; medya uçlarından dönen "tam mesaj nesnesi" bu alanı **atlamamalı**, yoksa `_TypeError` ile sohbet ekranı patlar.

**D5 — `messages.media_url` sütununun "artık okunmuyor" hale gelmesi**
`001_init.sql:57` `media_url TEXT NOT NULL DEFAULT ''`. İstemci bugün bu alanı **hiç göndermiyor** (`chats_provider.dart:80` gövdesi yalnız `{type, content}`), dolayısıyla mevcut tüm satırlarda değer `''`. `sendMessageReq.MediaURL` alanını kaldırmak **geriye dönük güvenlidir** — doğrulandı.

---

## E. TASARIMLARIN DOĞRU YAKALADIKLARI (onaylandı, değiştirilmemeli)

- ✅ `system` beyaz listeye **EKLENMİYOR** (`handler.go:151-157` turu 59b) — dördü de doğru.
- ✅ **Ayrı Dio** R2 PUT/GET için: `api.dart:33-40` `Authorization` ekliyor (SigV4 imzasını bozar) ve `:69` `addSentry()` imzalı URL'i breadcrumb'a yazar. İkisi de kapatılmalı.
- ✅ `/media/` **401 muafiyet listesine EKLENMEZ** (`api.dart:52-57`) — doğru; ama **O2**'deki oturum kapısı eklenmeli.
- ✅ Medya kuyruğu **`autoDispose` DEĞİL** — `messagesProvider` gerçekten `family.autoDispose` (`chats_provider.dart:121-123`), doğrulandı.
- ✅ `mesgulMu` **kopyalanmıyor, çağrılıyor** (`call_provider.dart:162-198`).
- ✅ Ses notu `SesSahipligi`'ye **yazılmıyor** (**Y4-b** gerekçesi).
- ✅ Yükleme ilerlemesi **WS'ten gitmiyor** (`hub.go` kuyruk dolunca sessizce düşürüyor).
- ✅ `camera` paketi **eklenmiyor** (iOS paylaşılan `videoCapturer`, `AppDelegate.swift:668/737/905`).
- ✅ `background_downloader`'ın kendi FGS'i **istenmiyor** — `AramaServisi` (`AndroidManifest.xml:63-66`, `foregroundServiceType="microphone|camera"`) zaten var; tip maskesi çalışma zamanında hesaplanıyor (`AramaServisi.kt:88-101`). ⚠️ **YAPMA:** o maskeye `dataSync`/`location` ekleme.

---

## F. SEVKTEN ÖNCE ZORUNLU ÜÇ ÖLÇÜM

1. **Y1:** Mevcut `singleInstance` manifesti ile `image_picker.pickImage()` Android'de sonuç döndürüyor mu? (Tek özellikli deneme build'i, yayınlanmaz.)
2. **Y2/Y3:** Görüntülü arama + oda + yayın sürerken picker aç/kapat → karşı tarafta kamera kesintisi ve ses kesilmesi ölçülür (Sentry: `medya secici: yasam=<state> camOn=<bool> sesiAc=<bool>`).
3. **Y5:** Arama bittikten sonra `CallRoomLock` sırası ne kadar sürüyor? (`leave()` → sıra boşalması arası ms.) 250ms varsayımı ölçümle çürütülür/doğrulanır.

**Bu üç ölçüm yapılmadan medya kodu yazılmaya başlanmamalı** — üçü de "kod hazır, sonra teşhis edilemeyen semptom" sınıfı.