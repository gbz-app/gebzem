# ADVERSARYAL DENETİM — MEDYA TASARIMLARI

Kaynaktan doğruladıklarım: `database.go` Migrate döngüsü (dosya başına **tek `pool.Exec`**, hata → `return` → `main.go:55-57` **`log.Fatalf`**, `schema_migrations` kaydı **ancak başarıdan sonra**) · `chats_provider.dart:77-83` `send()` gövdesi gerçekten yalnız `{type,content}` · `chat/handler.go:128,169-171,187,237,252,260` `media_url` zinciri · `medya_beklet.dart:29-53` `SesSahipligi` (statik Set, `ozet`, `sifirla()`) · `pubspec.yaml` (medya paketi yok, `flutter_webrtc: 1.4.0` pin, `sentry_dio` var) · migrations 001-013.

---

## 🔴 SEVK ENGELİ (bu haliyle yayına çıkarsa sistem ölür)

### 1. BEŞ TASARIM DA "014" DİYOR VE ÜÇÜ `messages_type_check`'i BİRBİRİNİ EZEREK YENİDEN KURUYOR → API KALICI ÇÖKME DÖNGÜSÜ

**Hangi madde:** GORSEL-VIDEO §3 · BELGE-SES §3 madde 3 · KONUM-KISI §4 · ANKET §3 madde 1 · ALTYAPI §3 madde 5.

**Neden patlar (kanıt):**
`Migrate()` her dosyayı **tek `Exec`** ile çalıştırır; hata olursa `fmt.Errorf` döner → `main.go:55` `log.Fatalf`. **Ve başarısız migration `schema_migrations`'a YAZILMAZ** → sonraki açılışta tekrar denenir → docker restart policy + `watchdog.sh` (API 2 kez sağlıksızsa restart) ile **sonsuz çökme döngüsü**. Sadece medya değil, **arama/oda/yayın dahil tüm sistem ölür.**

**Somut senaryo:**
1. `014_medya.sql` (BELGE-SES) `document`'i CHECK'e ekler, sahada `type='document'` satırlar oluşur.
2. Sonraki tur `015_anket.sql` (ANKET) çalışır: `ALTER TABLE messages ADD CONSTRAINT messages_type_check CHECK (type IN ('text','image','video','audio','location','system','poll'))` — **`document` YOK, üstelik `NOT VALID` de yok**.
3. Postgres mevcut `document` satırlarını tarar → `check constraint ... is violated by some row` → Exec hata → `log.Fatalf` → **API bir daha açılmaz.**

Aynı tuzak KONUM-KISI'de de var (kümesinde `poll` ve `document` yok) ve o `NOT VALID` + `VALIDATE CONSTRAINT` kullanıyor — `VALIDATE` de aynı satırlarda patlar.

**Neden test turlarında YAKALANMAZ:** CLAUDE.md rutini her sürümde `TRUNCATE users CASCADE` yapıyor → `messages` **boş** → CHECK çakışması **hiçbir test turunda görünmez**, yalnız DB kalıcı hale geldiği gün (yani gerçek yayında) patlar.

**Ek ölümcül alt bulgu:** üç tasarım `CREATE TABLE IF NOT EXISTS media_assets` yazıyor ama **üç farklı şema** ile:
| | GORSEL-VIDEO | BELGE-SES | ALTYAPI |
|---|---|---|---|
| status enum | `beklemede/hazir/bagli/reddedildi/silindi` | `beklemede/hazir/bagli/red/silindi` | `gecici/aktif/reddedildi/karantina/silindi` |
| beyan sütunları | `md5_hex` | `sha256`+`waveform`+`file_name` | `expected_bytes/expected_md5/thumb_expected_*` |
| küçük resim | `thumb_key` | yok | `thumb_key` |
`IF NOT EXISTS` yüzünden **ikinci migration sessizce hiçbir şey yapmaz**; tablo ilk tasarımın şemasıyla kalır, ikinci tasarımın Go kodu çalışma anında `column "expected_md5" does not exist` verir. Migration "başarılı" görünür, hata sahada çıkar.

**Minimal düzeltme:**
- **Tek `014_medya.sql`, tek `media_assets` şeması, tek status enum.** Beş tasarımı bir şema sahibinin birleştirmesi (ALTYAPI'nınki en eksiksiz — onu taban al).
- `messages.type` CHECK'ine **tek seferde tüm gelecek değerleri** yaz: `('text','image','video','audio','location','system','document','contact','poll')`. Sonraki hiçbir migration bu kısıta **dokunmasın**.
- `Migrate()`'e koruma: `ADD CONSTRAINT` içeren migration'lar **her zaman `NOT VALID` + ayrı `VALIDATE`** deseniyle yazılsın (proje kuralı olarak CLAUDE.md'ye).
- **KONUM-KISI'nin `location`'ı beyaz listeden ÇIKARMA kararı iptal** — üstküme kuralını ihlal ediyor.

---

### 2. GORSEL-VIDEO: PUBLIC BUCKET + **1 YIL EDGE TTL** + PURGE'SÜZ SİLME UCU = 5651 "4 SAAT" YÜKÜMLÜLÜĞÜ **TEKNİK OLARAK KARŞILANAMAZ**

**Hangi madde:** GORSEL-VIDEO §0.3 (public custom domain) + §2.11 madde 4 ("Cache Rule: `img|vid|thm/` → Edge TTL **1 yıl**") + §2.9 (`DELETE /messages/{id}` → R2 `DeleteObject`).

**Neden patlar:** R2'den nesneyi silmek **Cloudflare edge önbelleğini boşaltmaz**. Bir kez edge'e girmiş bir görsel, TTL süresince (1 yıl) `medya.gebzem.app/<key>` adresinden servis edilmeye devam eder. `DELETE` ucu hiçbir yerde purge çağırmıyor.

**Somut senaryo:** Mahkeme/BTK kararı gelir, admin medyayı siler, `curl https://medya.gebzem.app/img/2026/08/07/9f3c….jpg` **hâlâ 200 döner**. "4 saat içinde kaldırdık" beyanı **yanlış beyandır**.

Ayrıca aynı karar ALTYAPI §0.2-B'nin **private bucket** kararıyla doğrudan çelişiyor — iki tasarım aynı bucket için zıt erişim modeli tanımlıyor.

**Minimal düzeltme:** ALTYAPI'nın private bucket + imzalı GET modeli seçilsin (edge önbelleği zaten yok → purge sorunu yapısal olarak ortadan kalkar). Public model ısrar edilirse: `DELETE` ucu **Cloudflare purge API'sini senkron çağırmak zorunda** (Global Key `.env.infra`'da var) ve purge başarısızsa uç **hata dönmeli**, sessiz geçmemeli.

---

### 3. iOS ARKA PLAN YÜKLEME PENCERESİ ile SWEEPER PENCERESİ ÇAKIŞIYOR → KULLANICININ VİDEOSU SESSİZCE SİLİNİYOR

**Hangi madde:** GORSEL-VIDEO §3 sweeper ("`status='beklemede' AND created_at < now()-'15 min'` → nesneleri sil") · BELGE-SES §2.3 ("1 saat") · ALTYAPI §8.3 ("1 saat") — üç farklı pencere, hiçbiri iOS gerçeğine bakmıyor.

**Neden patlar:** Akış **PUT → commit** iki adımlı. iOS arka plan `URLSession` PUT'u uygulama öldürülmüşken tamamlar, ama **`commit` bir REST çağrısıdır ve ancak uygulama tekrar açıldığında yapılır**. Uygulama gece kapatılıp sabah açılırsa aradan saatler geçer. Sweeper `gecici`/`beklemede` nesneyi çoktan silmiştir → `commit` `409/404` → kullanıcının 16 MB'lık videosu **baştan yüklenir**, üstelik kota **iki kez** harcanmış olur.

15 dakikalık pencere daha da kötü: yavaş hücresel hatta 16 MB'lık tek parça PUT **15 dakikayı aşabilir**; yani sweeper **hâlâ devam eden yüklemenin** nesnesini siler.

**Minimal düzeltme:**
- Sweeper penceresi **sabit değil, `expected_bytes` türevi** olsun: `max(1 saat, expected_bytes / 5000 saniye)`, tavan 24 saat.
- `commit` başarısız olduğunda istemci **presign'ı yenileyip PUT'u tekrarlayabilmeli** (bkz. bulgu 5).
- Alternatif ve daha temiz: **`commit`i sunucu tarafında tetikle** — R2 event notification yok, o yüzden pratik yol: `HeadObject`'i sweeper'ın **silmeden önce** denemesi; nesne varsa doğrula ve `aktif` yap (silme yerine kurtarma).

---

### 4. `MedyaKapi.medyaOturumuVar = SesSahipligi.ozet.isNotEmpty` — İKİ YÖNDE DE HATALI

**Hangi madde:** ALTYAPI §7.1 (`mesgulMu` yerine `SesSahipligi` kullanılıyor, üstelik açıkça "mesgulMu DEĞİL" diye gerekçelendiriliyor).

**(a) ÇALAR FAZINDA KAPI AÇIK.** Doğruladım: `SesSahipligi.kaydol("arama_$id")` `ActiveCallController.baslat()` içinde. **Gelen aramada `baslat()` kabul edilene kadar çağrılmaz.** iOS'ta `call.incoming` WS dalı zaten atlanıyor (`call_provider.dart:211`), arama CallKit'ten geliyor. Yani telefon **çalarken** `SesSahipligi` **BOŞ** → `medyaOturumuVar == false` → kullanıcı ses notu kaydına başlayabilir → `record` `AVAudioSession`'ı `playAndRecord`a çevirir → kullanıcı aramayı kabul eder → `setAudioEnabled(true)` canlı bir `record` oturumunun üstüne biner → **turu 64 `!pri` (`InsufficientPriority`) sınıfı hata birebir geri gelir.** Aynı anda kamera picker'ı da açılabilir → kabul edilen görüntülü aramada `videoCapturer` çakışması (turu 50).

BELGE-SES §7.4 bu deliği **doğru** kapatmış (4 kaynaklı `SesKapisi`: `SesSahipligi` + `activeCallProvider` + `callServiceProvider`). İki tasarım aynı kapı için biri eksik biri tam iki farklı uygulama veriyor.

**(b) KAPI KALICI KİLİTLENEBİLİR.** `_sahipler` **statik bir Set** ve proje bunu daha önce sızdırdı — turu 73b `sifirla()`yı tam bu yüzden eklemiş. Sızan tek bir `oda_x` kaydı → `medyaOturumuVar` **sonsuza kadar true** → kamera, ses notu, video oynatma **kalıcı olarak ölür**, üstelik **hiçbir ölçüm düşmez**. `mesgulMu` ise bayat kaydı temizler + Sentry ölçümü yazar (turu 53/56 self-heal). ALTYAPI, projenin zaten çözdüğü bir sorunu geri getiriyor.

**Minimal düzeltme:** BELGE-SES'in 4 kaynaklı `SesKapisi`'ni tek kaynak yap; `SesSahipligi` **yanında** `mesgulMu(etiket:'medya-*')` de sorulsun (self-heal + ölçüm için). Kapı **fail-closed ama gözlemlenebilir** olsun: engellendiğinde Sentry'e arama başına tek olay (`medya kapi: sebep=... sahipler=...`).

---

## 🟠 AĞIR (maliyet / ölçek / veri kaybı)

### 5. `If-None-Match: *` — İKİ TASARIM ZIT KARAR VERİYOR, VE MOBİL AĞDA TEKRAR DENEMEYİ ÖLDÜRÜYOR

GORSEL-VIDEO §2.2 ve ALTYAPI §2.2 imzaya `If-None-Match: *` koyup "presigned URL fiilen tek kullanımlık" diyor. BELGE-SES §2.1 bunu **açıkça reddediyor** ("mobil şebekede asıl sorun yarıda kalan yüklemenin tekrar denenmesidir").

**BELGE-SES haklı.** GORSEL-VIDEO'nun kendi §6.1'i sorunu itiraf ediyor ("412 alınca doğrudan commit'e geç") ama bu **belirsiz**: 412 hem "nesne eksiksiz yüklendi" hem "R2 kısmi nesne yazdı" anlamına gelebilir ve istemci ayırt edemez. Ayrıca **R2'nin PutObject'te koşullu başlık desteği doğrulanmamış** — üç tasarımın hiçbiri bunu test etmemiş, ama üçünün de tek-kullanım güvencesi buna dayanıyor.

**Minimal düzeltme:** `If-None-Match` **kaldırılsın**. Tek-kullanım güvencesi zaten `media_assets.status` durum makinesiyle sağlanıyor (`beklemede → aktif` geçişi tek yönlü, `aktif`e ikinci commit `409`). Aynı anahtara tekrar PUT etmek **istenen** davranıştır (tekrar deneme). Bütünlük `Content-MD5` + commit'teki `HeadObject` ile zaten kesin.

---

### 6. `Content-MD5` BOYUT DAYATMAZ — "boyut zorlamasının pratik karşılığı budur" İDDİASI YANLIŞ

**Hangi madde:** GORSEL-VIDEO §2.2, ALTYAPI §2.2, CLOUDFLARE keşfi §4.

`Content-MD5` **içerik** doğrular, **boyut** değil. R2 gövdenin **tamamını aldıktan sonra** MD5'i hesaplayıp reddeder. Yani presign alan bir istemci 400 KB beyan edip **5 GB** gönderebilir; R2 5 GB'ı alır, hesaplar, `BadDigest` döner — ama bu esnada bant genişliği ve süre harcanır ve bazı durumlarda nesne yazılır.

**Somut senaryo:** 300 presign/gün kotası olan bir hesap, her presign'da 5 GB gönderir → sweeper penceresi boyunca (1 saat) bucket'ta 1,5 TB. Kota "adet" bazlı olduğu için **bayt kotası presign anında beyan edilen değerle düşülüyor**, gerçek yüklenenle değil → aylık bayt kotası da atlatılmış olur.

**Minimal düzeltme:**
- Kota **commit'te gerçek `HeadObject` boyutuyla** düzeltilsin (presign'da rezervasyon, commit'te uzlaştırma).
- Sweeper `gecici` nesneleri silerken önce `HeadObject` yapıp **beyan edilenden büyükse hesabı işaretlesin** (`users.suspended_at` adayı + Sentry).
- İddia metni düzeltilsin ki gelecekte kimse "MD5 boyutu dayatıyor" diye gerçek kapıyı kaldırmasın.

---

### 7. MALİYET TABLOSU **90 GÜN** VARSAYIMIYLA HESAPLANDI, TASARIMLAR **365 GÜN** SEÇTİ → RAKAM 3,5× YANLIŞ

CLOUDFLARE keşfi §3: "90 gün sonra sil (önerilen) → orta $66/ay". GORSEL-VIDEO §2.11 ve ALTYAPI §8.3 **365 gün** seçiyor. GUVENLIK §6.2 de 365 gün.

Aynı hacimle 365 gün kararlı durumu: 1,29 TB/ay × 12 = **15,5 TB** → **~$232/ay**. Yüksek senaryo 5,42 TB × 12 = 65 TB → **~$975/ay**. Yani sunulan `$66` rakamı **fiilen seçilmeyen bir politikaya ait**.

**Ayrıca kota bir maliyet kontrolü DEĞİL:** 2 GB/kullanıcı/ay × 50K = teorik **100 TB/ay**. Modellenen ortalama kullanıcı başına ~86 MB/ay; kota bunun **23 katı**. Kotanın %5'i bile kullanılsa modelin 1,2 katı ek yük gelir.

**IA katmanı + private bucket birlikte YANLIŞ:** ALTYAPI private bucket + imzalı GET seçti → **CDN önbelleği yok**, her görüntüleme origin'e gidiyor. IA'da bu **$0,01/GB veri çekme ücreti** demektir (Standard'da yok). "Egress ücretsiz" başlığı IA retrieval'a **uygulanmaz**. İki ayrı belgeden gelen iki karar birbirini yiyor.

**Minimal düzeltme:** (a) Saklama **90 gün** olarak sabitlensin ve maliyet tablosuyla aynı belgede dursun. (b) Kota **500 MB/kullanıcı/ay**'a indirilsin (modellenen ortalamanın 6 katı, hâlâ bol). (c) IA geçişi **iptal** (private bucket ile birlikte net kayıp).

---

### 8. ÇOK PARÇALI YÜKLEME **$2,43/AY UĞRUNA** REDDEDİLDİ — TÜRKİYE HÜCRESEL AĞINDA EN PAHALI KARAR

**Hangi madde:** CLOUDFLARE §4 ("her `UploadPart` ayrı Class A; 12 MB'lık videoyu 5 MB parçalara bölmek Class A maliyetini 3× yapar. **Şimdilik yapma**"), ALTYAPI §5.3 aynısını tekrarlıyor.

**Aritmetik yanlış çerçevelenmiş:** 90.000 video/ay × 7 parça = 630K Class A, tek parçada 90K. Fark 540K × $4,50/M = **$2,43/ay**.

Karşılığında feda edilen: hücresel bir hatta 16-32 MB'lık tek parça PUT'un **her kopmada sıfırdan başlaması**. Operatör NAT'ı, hücre değişimi, asansör — Türkiye'de gerçek. Üstelik ALTYAPI §5.3 bunu itiraf ediyor: *"bayt seviyesinde devam YOKTUR"*.

Ayrıca **üç tasarım üç farklı video tavanı** veriyor: 16 MB (ALTYAPI) / 32 MB (GORSEL-VIDEO) / — (BELGE-SES 25 MB belge). WhatsApp envanteri 100 MB öneriyor. Bu, "üç yerde aynı sayı olmalı" kuralının (CLAUDE.md turu 53) doğrudan ihlali.

**Minimal düzeltme:** video için **çok parçalı yükleme** (5 MB parça) etkinleştirilsin; foto/ses/thumb tek parça kalsın. Tavan **tek bir yerde** (`limits.go`) tanımlansın, Flutter tarafı onu `GET /users/me` yanıtından okusun — üç yere elle yazılmasın.

---

### 9. DİSK BÜTÇESİ YOK — 80 GB'LIK PAYLAŞIMLI DİSKTE POSTGRES ŞİŞMESİ = TAM KESİNTİ

Hiçbir tasarımda disk hesabı yok. cx33'te 80 GB'ı Docker imajları + Postgres + Redis + LiveKit paylaşıyor; `watchdog.sh` %90'da `docker prune` yapıyor (yani zaten dar olduğunu biliyoruz).

Eklenen yük ("orta" senaryo):
- `media_assets`: 2,45M satır/ay (reddedilenler + geçiciler dahil) × ~250 B + 4 indeks ≈ **1 GB/ay = 12 GB/yıl**
- GUVENLIK §5.3'ün önerdiği erişim logu: **65M satır/yıl** → indekslerle **10-15 GB/yıl** (Postgres satırları sıkıştırılmaz; GUVENLIK'in "8-12 GB sıkıştırılmış" tahmini dosya logu içindir, tabloya uygulanamaz)
- Mesaj hacmi artışı + `message_receipts`

**~25 GB/yıl** yeni Postgres büyümesi. Disk dolarsa Postgres yazmayı reddeder → **arama, oda, yayın dahil her şey durur.**

**Minimal düzeltme:** (a) `media_assets`'te `status IN ('reddedildi','silindi')` satırları 30 gün sonra **fiziksel silinsin** (delil gereken karantina hariç). (b) Erişim logu Postgres'e **değil**, dönen dosyaya (`logrotate` + gzip) yazılsın. (c) `watchdog.sh`'a **Postgres veri dizini boyut alarmı** eklensin. (d) Yayın öncesi disk 160 GB'a çıkarılsın (cx33 → volume ekleme, ~€5/ay).

---

### 10. `message.new` HER MEDYA MESAJINDA TÜM `/chats` LİSTESİNİ YENİDEN ÇEKTİRİYOR

`chats_provider.dart:30-35` `message.new` gelince listenin **tamamını** yeniden çekiyor. `ListChats` (`handler.go:326-349`) sohbet başına `message_receipts` alt sorgusu + LATERAL çalıştırıyor ve tasarımlar buna bir de `media_assets` JOIN'i ekliyor.

ANKET tasarımı §4.5 bu tuzağı **doğru teşhis edip** `poll.vote`'u o tetiğe bağlamayı yasakladı. Medya tasarımlarının hiçbiri aynı soruyu sormadı — ve **medya mesajı `message.new` üretiyor**, yani tetik zaten açık.

**Somut senaryo:** Kullanıcı görüntülü aramadayken karşı taraf 5 fotoğraf gönderiyor → 5 `message.new` → 5 tam `/chats` sorgusu → cx33'te LiveKit ile aynı 4 vCPU'da Postgres iş yükü + istemcide 5 REST çağrısı, hücresel hatta medya paketleriyle yarışıyor.

**Minimal düzeltme:** `ChatsNotifier` `message.new`'de **tam yeniden çekme yerine ilgili satırı yerinde güncellesin** (payload zaten `chat_id`, `type`, `content`, `created_at` taşıyor). Bu, medyadan bağımsız olarak da bugünkü bir performans hatası.

---

## 🟡 ORTA (yanlış gerekçe / eksik kapı / uyum)

### 11. `image_picker` `ImageSource.camera`'nın "yapısal olarak güvenli" olduğu iddiası YANLIŞ

FLUTTER-PAKETLER §2 ve GORSEL-VIDEO §5.1: *"`UIImagePickerController` sistem-sahipli modal, bizim capture oturumumuza doğrudan tutamak vermez. Yapısal olarak çok daha güvenli."*

`UIImagePickerController` **uygulamanın kendi sürecinde** çalışan bir `UIViewController`'dır ve kamera modunda **kendi `AVCaptureSession`'ını uygulama sürecinde açar**. `flutter_webrtc`'nin paylaşılan `videoCapturer`'ı aynen `AVCaptureSessionWasInterrupted` (`videoDeviceInUseByAnotherClient`) alır. `camera` paketine göre tek farkı, oturumu iOS'un yönetmesi ve daha erken serbest bırakması.

Gerçek koruma **`mesgulMu` kapısıdır**, "sistem modalı" değil. Gerekçe yanlış bırakılırsa gelecekte biri "picker güvenli, kapıyı kaldıralım" der.

**Minimal düzeltme:** gerekçe metni düzeltilsin; kapı **tek koruma** olarak işaretlensin.

---

### 12. `record` paketinde `manageAudioSession` YOK İDDİASI ŞÜPHELİ — DOĞRULANMADAN KURAL YAZILMIŞ

BELGE-SES §0 ÇELİŞKİ-2: *"`IosRecordConfig` API'sinde `manageAudioSession` diye bir alan YOK"*. `record` 5.1.x'ten itibaren `RecordConfig`/`IosRecordConfig` tarafında ses oturumu yönetimini devre dışı bırakan bir seçenek eklendiği biliniyor; tasarım 7.1.1 sürümü için bunu iddia ediyor ama **paket kaynağından değil, API dokümanı sayfasından** çıkarmış.

**Kararı (sert kapı) değiştirmez** — Android AudioFocus / `AudioSwitchManager` gerekçesi tek başına yeterli. Ama gerekçe yanlışsa, gelecekte biri "artık `manageAudioSession: false` var, kapıyı kaldırabiliriz" der ve turu 64'ü geri getirir.

**Minimal düzeltme:** paket kaynağı `pubspec` çözümlemesinden sonra **fiilen okunsun**; gerekçe "Android AudioFocus + iOS proses geneli `useManualAudio`" olarak yeniden yazılsın (bu ikisi doğrulanmış ve kalıcı).

---

### 13. GORSEL-VIDEO `MediaURL` ALANINI "eski istemci kırılmasın" DİYE TUTUYOR — GEREKÇE FAKTİK OLARAK YANLIŞ

GORSEL-VIDEO §2.5: *"`MediaURL` alanı struct'ta KALIR ama YOK SAYILIR — kaldırılırsa eski istemciler 400 almaz ama..."*

İki hata: (a) Go'nun `json.Decode`'u **bilinmeyen alanı sessizce yok sayar**; alanı silmek hiçbir istemciye 400 döndürmez. (b) **Doğruladım: istemci bu alanı zaten hiç göndermiyor** (`chats_provider.dart:80` gövdesi yalnız `{type, content}`).

Yani bugünkü SSRF/oltalama/izleme-pikseli yüzeyini (`handler.go:128 → 169-171`) **hiçbir gerekçe olmadan** açık tutuyor. ALTYAPI ve BELGE-SES doğru karar veriyor (alanı sil).

**Minimal düzeltme:** `MediaURL` `sendMessageReq`'ten **silinsin**. Bu tek satır, bugün canlıda duran bir açığı kapatıyor.

---

### 14. ENGELLEME (block) VE ŞİKÂYET UÇLARI HİÇBİR TASARIMIN SAHİPLİĞİNDE DEĞİL — App Store 1.2 RİSKİ

Dört tasarım da `SendMessage`'a blok kontrolü ekliyor ve dördü de itiraf ediyor: **`blocks` tablosuna INSERT eden hiçbir uç yok** → kontrol **ölü kod**. Her biri "ayrı iş" diyor, yani **kimse yapmıyor**.

Medya, uygulamayı "kullanıcı üretimi içerik" kategorisine sokan şey. App Store Review Guideline 1.2 UGC için **filtreleme + şikâyet + engelleme + 24 saat içinde işlem** taahhüdünü şart koşar. Ad-hoc dağıtım şu an için koruyor ama TestFlight/Store'a çıkış anında **doğrudan ret sebebi**.

Ayrıca: `POST /chats/direct` herkese açık → **herhangi bir kullanıcı, herhangi birine medya gönderebilir** ve alıcının **hiçbir savunması yok**.

**Minimal düzeltme:** `POST/DELETE /users/{id}/block` + `POST /messages/{id}/report` + admin kaldırma ucu, medya ile **aynı turda** sevk edilsin. Bu, tasarımların "ayrı iş" dediği ama medyayı sevk edilebilir kılan ön koşul.

---

### 15. OTOMATİK İNDİRME AYARI MVP'DEN ÇIKARILDI — TÜRKİYE'DE KALDIRMA (uninstall) TETİKLEYİCİSİ

WHATSAPP-ENVANTER §14: *"Otomatik indirme ayarları — Türkiye'de hücresel veri paketleri sınırlı; varsayılan 'hücreselde video indirme' olursa kullanıcı uygulamayı siler. **MVP'de olmalı**."*

GORSEL-VIDEO §1.4 bunu **kaldırıyor**: *"Ayar ekranı olmadığı için Faz 1'de ayar yok, sabit politika... `connectivity_plus` eklenmiyor."*

Sonuç: hücresel hatta **fotoğraflar her zaman otomatik iniyor**, kullanıcı kapatamıyor. Grup sohbeti geldiğinde bu, günde onlarca MB demek. ALTYAPI §8.1 doğru yapıyor (`connectivity_plus` + ayarlar) — iki tasarım zıt.

**Minimal düzeltme:** ALTYAPI'nın modeli alınsın. `connectivity_plus` maliyeti ~0 ve ayar ekranı üç `SwitchListTile`.

---

### 16. GEOAPIFY TILE PROXY'Sİ, TASARIMIN KENDİ "MEDYA SUNUCUDAN GEÇMESİN" KURALINI İHLAL EDİYOR

KONUM-KISI §3.1 `GET /maps/tile/{z}/{x}/{y}.png`: soğuk tile'da cx33 **Geoapify'dan senkron çeker → R2'ye PUT eder → 302 döner**. Yani her soğuk tile'da LiveKit'in koştuğu makinede bir dış HTTP çağrısı + bir R2 yükleme.

Kullanıcı başına limit **60 soğuk tile/dakika**. Zoom 16'da tam ekran bir harita ~12-20 tile; birkaç kaydırma limiti doldurur. 10 kullanıcı aynı anda harita seçim ekranı açarsa cx33'te onlarca eşzamanlı dış istek — **görüntülü arama sürerken.**

Ayrıca **Geoapify ücretsiz katmanı 3.000 kredi/gün, sert tavan.** Kota dolunca konum önizlemeleri günün geri kalanında üretilemez → tasarımın kendi hata dalıyla ("nötr kart") **akşam saatlerinde konum balonları bozuk, sabah düzgün** — deterministik olmayan UX. Ve tasarım kendi §11'de **Geoapify ToS'unu okumadığını** itiraf ediyor; tüm maliyet modeli "önbellekleme serbest" varsayımına dayanıyor.

**Minimal düzeltme:** Konum **bu programdan tamamen çıkarılsın** (bkz. bulgu 20). Yapılacaksa: tile proxy iptal, harita seçim ekranı `flutter_map` + **doğrudan sağlayıcıya** (anahtar kısa ömürlü sunucu token'ı ile), yalnız **statik önizleme** sunucudan üretilsin (koordinat başına 1 kez, gerçek maliyet kalemi bu).

---

### 17. `client_ref` IDEMPOTENCY'Sİ YARIŞA AÇIK

ALTYAPI §2.2: önce `SELECT ... WHERE client_ref=$3`, yoksa `INSERT`. Aradaki pencerede ikinci istek gelirse **iki INSERT** denenir; `UNIQUE INDEX` ikincisini `23505` ile reddeder ama handler bu hatayı **ele almıyor** → kullanıcıya `500` döner, istemci tekrar dener, döngü.

**Minimal düzeltme:** `INSERT ... ON CONFLICT (chat_id, sender_id, client_ref) WHERE client_ref <> '' DO NOTHING RETURNING id` + boş dönerse `SELECT`. Tek sorgu, yarışsız.

---

### 18. ELLE YAZILAN SigV4 — "go.mod'a satır eklememek" İÇİN KRİPTO İMZA RİSKİ ALINIYOR

Beş tasarım da `crypto/hmac` ile elle SigV4 yazıyor, gerekçe: *"harici bağımlılık yok deseni korunur"*. Ama **böyle bir proje kuralı yok** — kural mobil paketler için. Backend'de `go.mod` zaten chi/pgx/redis/jwt/sentry taşıyor.

SigV4 elle yazmanın klasik hata kaynakları: kanonik sorgu dizesinde `/` çift kodlaması, başlık sıralaması, `UNSIGNED-PAYLOAD` vs gövde hash'i, `X-Amz-Date` biçimi. Hata **sessizdir** — `403 SignatureDoesNotMatch` gelir, `catch` yutar, medya "bazen çalışmaz" olur. Bu, projenin CLAUDE.md'de kayıtlı **tekrarlayan deseni**: "yutulan hata + breadcrumb-only log".

**Minimal düzeltme:** ya `aws-sdk-go-v2/service/s3` presigner kullanılsın, ya da elle yazılan `sigv4.go` için **açılışta bilinen test vektörüyle self-test** koşsun ve tutmuyorsa `mediaH.Enabled()=false` + `log.Println`. Ayrıca her `403` **Sentry gerçek olayı** olsun, breadcrumb değil.

---

### 19. KOTA ATLATMA: HESAP BAŞINA KOTA + ÜCRETSİZ KAYIT = KOTA YOK

Kotalar `{uid}` anahtarlı. Kayıt SMS OTP ile ücretsiz, cihaz/IP bağı yok. 10 hesap = 10× kota. GUVENLIK keşfi IP limitini öneriyor ama **uygulama tasarımlarının hiçbiri IP kotasını almamış** (GORSEL-VIDEO §2.2'de yok, ALTYAPI §2.5'te yok, BELGE-SES §2.3'te yok).

**Minimal düzeltme:** Redis Lua'ya `medya:ip:{ip}:{saat}` anahtarı eklensin (`middleware.RealIP` zaten zincirde). Yeni hesap limiti (24 saat) zaten var, onunla birlikte pratik fren olur.

---

## ⚪ KAPSAM / KARMAŞIKLIK

### 20. TOPLAM KAPSAM SEVK EDİLEMEZ BÜYÜKLÜKTE — %80 DEĞER, %25 İŞLE ALINIR

Beş tasarımın toplamı: **5 migration** (hepsi 014), **~12 yeni Go dosyası**, **~30 yeni Flutter dosyası**, **12+ yeni paket**, **15+ yeni uç**, **4 yeni WS olayı**. Ve projenin en kırılgan iki dosyasına — `chat/handler.go` `SendMessage` ve `chat_screen.dart` balon dallanması — **beşi de ayrı ayrı** dokunuyor. Entegrasyon sahibi yok.

Proje 73 tur boyunca öğrendi ki tek bir ses birimi yarışı 5 turluk teşhis istiyor. Bu paketi tek turda sevk etmek, hata çıktığında hangi katmanın bozuk olduğunu **ayırt edilemez** kılar.

**%80 değeri veren çekirdek (WHATSAPP-ENVANTER'in kendi Türkiye sıralamasına göre):**
1. **Fotoğraf** (galeri + kamera + altyazı)
2. **Ses notu**

**Çıkarılacaklar (bu turdan):** video · belge · konum (anlık **ve** canlı) · kişi kartı · anket · tek-seferlik görüntüleme · sohbet medya galerisi · HD anahtarı · dedup · IA katmanı.

Bu, tek `media_assets` şeması, tek migration, 5 paket (`image_picker`, `flutter_image_compress`, `record`, `path_provider`, `cached_network_image`), 4 uç (`presign`/`commit`/`cancel`/`url`) demektir. ALTYAPI §11'in kendi uygulama sırası zaten bunu söylüyor (*"Adım 5'ten önce test turu ALMA"*) — ama diğer dört tasarım paralel sevk edilebilirmiş gibi yazılmış.

---

### 21. HİÇBİR TASARIMDA OLMAYAN, EN UCUZ KAZANÇ: AVATAR YÜKLEME

Medya altyapısı kuruluyor ama `users.avatar_url` **hâlâ hep boş** kalıyor (7 `NetworkImage` çağrı yeri fiilen hep harf yedeğine düşüyor, `PATCH /users/me`'yi çağıran istemci kodu yok). Presign + commit zinciri kurulduktan sonra avatar **20 satırlık** ek iş ve her ekranda görünür kazanç.

**Minimal düzeltme:** `kind='avatar'` (1 MB tavan, 512px) çekirdek kapsama alınsın; `PATCH /users/me` `avatar_media_id` kabul etsin.

---

## DOĞRU BULDUKLARIM (tekrar tartışılmasın)

- Cloudflare fiyat rakamları **doğru**: R2 $0,015/GB-ay · Class A $4,50/M · Class B $0,36/M · egress $0 · ücretsiz 10 GB/1M/10M. Images $5/100k saklanan + $1/100k sunulan. Stream $5/1000dk saklanan + $1/1000dk izlenen. Transformations $0,50/1000 (5.000 ücretsiz). Workers $5/ay. **Images ve Stream'in elenmesi doğru karar** (sohbet medyası = çok sayıda, az izlenen → her iki modelin de tam tersi).
- **Medyanın cx33'ten geçmemesi** (presign) doğru ve tartışmasız — LiveKit ile CPU/gecikme rekabeti gerçek.
- **İstemcide sıkıştırma + küçük resim** doğru (sunucuda ffmpeg = LiveKit'e zarar).
- **`camera` paketinin reddi** doğru (gerekçe kısmen yanlış olsa da karar doğru).
- **`chewie`, `ffmpeg_kit`, `audio_waveforms`, `google_maps_flutter`, OSMF tile** eleme gerekçeleri sağlam.
- ANKET tasarımı, ses/kamera birimine dokunmadığını **kanıtlayarak** kapı koymaması ve `poll.vote`'u `/chats` tetiğine bağlamayı **reddetmesi** — bu belgeler içinde en disiplinli akıl yürütme.
- BELGE-SES'in 4 kaynaklı `SesKapisi`'si ve 400 ms'lik yıkım tavanı (turu 67 dersi) doğru.