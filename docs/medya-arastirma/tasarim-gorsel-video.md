# GEBZEM — FOTOĞRAF & VİDEO PAYLAŞIMI: MÜHENDİSLİK TASARIMI

Tüm iddialar kaynaktan doğrulandı. Keşif çıktısındaki iki çelişki aşağıda **§0.3**'te karara bağlandı.

---

## §0 — TEMEL KARARLAR (gerekçeleriyle)

### 0.1 Doğruladığım zemin (dosya:satır)

| Zemin | Kanıt |
|---|---|
| Tip beyaz listesi `text,image,video,audio,location` | `backend/internal/chat/handler.go:152-157` |
| `media_url` istemciden geliyor, **hiç doğrulanmıyor** | `handler.go:128` → `handler.go:171` (ham INSERT) |
| `messages.type` CHECK'i `image`/`video`'yu **zaten içeriyor** | `001_init.sql:55` |
| `media_url TEXT NOT NULL DEFAULT ''` **zaten var** | `001_init.sql:57` |
| Son migration **013** → yeni iş **014** | `backend/internal/database/migrations/` listesi |
| Migration'lar `embed.FS` + `schema_migrations` ile açılışta otomatik | `backend/internal/database/database.go:13,28-67` |
| Backend'de R2/S3/presign kodu **yok**, `go.mod`'da bulut SDK'sı **yok** | `backend/go.mod` (chi, pgx, redis, websocket, jwt, sentry, crypto, net) |
| Flutter'da medya paketi **yok** | `mobile/pubspec.yaml:30-68` |
| Sohbet giriş çubuğunda ataç **yok** (yer tutucu yorum) | `chat_screen.dart:291` |
| `_Bubble` tip ayrımı yapmıyor, koşulsuz `Text(content)` | `chat_screen.dart:652` |
| Sohbet listesi önizlemesi `Fotoğraf`/`Video` **zaten hazır** | `chats_screen.dart:240-243`, ikon `:219-236` |
| `mesgulMu({haric, etiket, odaYayinMuaf})` tek kaynak | `call_provider.dart:162-198` |
| iOS ses birimi **proses geneli manuel** | `AppDelegate.swift:32-33` |
| iOS'ta **TEK paylaşılan** `videoCapturer` | `AppDelegate.swift:668, 737, 905` |
| `Event.Payload` ham JSON → hub değişmeden yeni alan taşınır | `chat/hub.go:30-36`, `deliver` `:79-104` |
| Redis Lua deseni mevcut | `streams/guests.go:52` (`redis.NewScript`) |
| `.env.infra`'da R2 anahtarları hazır | `R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY / R2_ENDPOINT / R2_BUCKET / CLOUDFLARE_ZONE_ID` |
| `chatMemberIDs` göndereni **listeden çıkarıyor** | `handler.go:421-425` → gönderenin diğer cihazları `message.new` almıyor |
| `preview[:80]` **bayt** kesiyor (UTF-8 bozar) | `handler.go:207-209` |
| Lucide ikon adları doğrulandı | `lucide_icons_flutter-3.1.15`: paperclip, images, camera, play, pause, download, x, eye, eyeOff, trash2, chevronLeft, share2, imageOff, timer ✓ |

### 0.2 Ürün limitleri (sabit, env ile ayarlanabilir)

| | İstemci hedefi | Sunucu SERT tavanı |
|---|---|---|
| Fotoğraf (normal) | uzun kenar **1600px**, JPEG q82 → ~250-400 KB | **4 MB** |
| Fotoğraf (HD) | uzun kenar **2560px**, q88 | **4 MB** |
| Küçük resim (thumb) | uzun kenar **320px**, q70 → ~15-40 KB | **200 KB** |
| Video | kısa kenar **720p**, ~2.5 Mbps, **≤ 90 sn** | **32 MB** |
| Piksel tavanı | — | **50 MP** (dekompresyon bombası) |
| Kabul edilen MIME | `image/jpeg`, `image/webp`, `video/mp4` | başka hiçbir şey |

⚠️ **HEIC, PNG, GIF, SVG, HEVC/MOV kabul edilmez.** İstemci iPhone'un HEIC'ini JPEG'e, PNG'yi JPEG'e çevirir (`flutter_image_compress` `format: CompressFormat.jpeg` zaten bunu yapar). Sunucuya ulaşan tek görsel formatı JPEG/WebP olur → sihirli bayt doğrulaması iki satıra iner ve SVG/polyglot sınıfı yapısal olarak imkânsızlaşır.

### 0.3 Keşif ajanları arasındaki İKİ ÇELİŞKİ — kararım

**Çelişki 1 — bucket public mi private mi?**
`CLOUDFLARE` keşfi "Faz 1: açık bucket + custom domain" dedi; `GUVENLIK-YASAL` keşfi "PRIVATE, kesin" dedi.

> **KARAR: Faz 1'de PUBLIC custom domain (`medya.gebzem.app`) + 122 bit entropili UUID anahtar + Cloudflare Response Header Transform Rules.**
> **Gerekçe:** (a) presigned GET custom domain ile **çalışmıyor** → CDN önbelleği ölür, her görüntüleme bir Class B işlemi olur; (b) Worker kapısı doğru çözüm ama +$5/ay ve yeni bir dağıtım birimi — prototipte erken; (c) asıl saldırı yüzeyi olan "tarayıcıda çalışan içerik" §0.2'deki **3 formatlık beyaz liste** ile zaten kapanıyor; (d) başlık zorlaması Worker'sız da yapılabiliyor (Transform Rules).
> **DÜRÜST SINIR:** URL'i ele geçiren herkes içeriği görür (capability URL). Uçtan uca şifreleme YOK, "uçtan uca şifreli" **iddia edilmeyecek**.
> **YÜKSELTME YOLU ÜCRETSİZ OLSUN DİYE:** DB'de **tam URL değil `object_key` saklanır**; URL sunucuda okuma anında `MEDIA_BASE_URL + "/" + key` ile üretilir. Faz 2'de aynı satır imzalı URL üretmeye çevrilir — **istemcide tek satır değişmez**.

**Çelişki 2 — dedupe/moderasyon hash'i SHA-256 mı?**
`GUVENLIK-YASAL` keşfi `sha256` sütunu önerdi. Ama sunucu dosyayı indirmiyor (sadece 256 KB okuyor) → SHA-256'yı **hesaplayamaz**; istemciye güvenmek de anlamsız.

> **KARAR: MD5.** R2 tek parça PUT'ta ETag = MD5 hex döndürür; `HeadObject` ile **bedava** gelir. `Content-MD5` zaten imzalanıyor (§2.3), yani MD5 hem bütünlük hem dedupe hem hash-bazlı toplu kaldırma anahtarı olur. `sha256` sütunu **eklenmiyor** (kullanılmayan sütun eklemiyoruz).

### 0.4 Bu turda YAPILMAYACAKLAR (bilinçli)

- `background_downloader` **eklenmiyor.** Gerekçe: Android 14'te `AramaServisi` (`foregroundServiceType="microphone|camera"`, `AndroidManifest.xml:60-63`) zaten bir ön plan servisi; paketin kendi `dataSync` FGS'i ile tip/kota çakışması bu projede daha önce çok pahalıya patlamış bir sınıf. Yükler küçük (foto ~350 KB, video ~4-8 MB) ve kalıcı kuyruk (`§5.3`) uygulama öldürülse bile devam ettiriyor. **Tekrar değerlendirme tetiği:** sahada videoların medyanı 10 MB'ı geçerse ya da "arka plana alınca gönderilmedi" şikâyeti gelirse.
- Ses notu, konum, belge, anket, çıkartma, iletme, düzenleme — **kapsam dışı**.
- Sunucuda ffmpeg/libvips **yok** (LiveKit ile aynı 4 vCPU'yu paylaşıyoruz).
- `system` **beyaz listeye eklenmiyor** (turu 59b).

---

## §1 — KULLANICI AKIŞI (dokunuştan karşı tarafta görünmesine)

### 1.1 Gönderme — fotoğraf, galeriden, altyazılı

1. **Dokunuş 1** — Giriş çubuğunda **ataç** (`LucideIcons.paperclip`, `chat_screen.dart:291`'deki yer tutucunun yeri) → alttan panel açılır: **Galeri** (`LucideIcons.images`) · **Kamera** (`LucideIcons.camera`).
   - ⚠️ **Kamera satırı, aktif arama/oda/yayın varsa HİÇ ÇİZİLMEZ** (§7.1).
2. **Dokunuş 2** — "Galeri" → `ImagePicker.pickMultiImage(limit: 10)`. iOS'ta **PHPicker**, Android'de **Photo Picker** açılır → **izin diyaloğu YOK**.
3. **Dokunuş 3..n** — Kullanıcı 1-10 öğe seçer, "Ekle"ye basar.
4. **Önizleme ekranı** (`medya_onizleme_screen.dart`, tam sayfa route):
   - Üstte seçilen öğe tam ekran; altta yatay küçük resim şeridi (öğeler arası geçiş).
   - Alt çubuk: **altyazı alanı (her öğeye ayrı)** + **HD** metin rozeti (aç/kapa) + **tek seferlik** (`LucideIcons.eye`/`eyeOff`) + gönder (`LucideIcons.send`).
   - Video seçildiyse: süre etiketi + tahmini boyut; 90 sn'yi aşıyorsa kırmızı uyarı ve gönder düğmesi kapalı.
5. **Dokunuş son** — Gönder. **Ekran ANINDA kapanır**, sohbete döner. Seçilen her öğe için sohbetin en altında **iyimser balon** belirir: küçük resim + üstünde dairesel ilerleme + `LucideIcons.x` (iptal).
6. Arka planda, öğe başına sırayla:
   `hazirlaniyor` → (video ise) `bekliyor-gorusme` gerekiyorsa → `yukleniyor %n` → `dogrulaniyor` → `gonderiliyor` → `gonderildi`.
7. `gonderildi` olunca iyimser balon **aynı yerde** gerçek mesaj balonuna dönüşür (id sunucudan gelir, kaydırma zıplaması olmaz).

**Zaman çizelgesi (TAHMİN, ölçülmedi):** 4 MP fotoğraf → sıkıştırma ~180 ms + thumb ~60 ms + MD5 (isolate) ~25 ms + presign RTT ~120 ms + PUT 350 KB (4G) ~600 ms + commit (HEAD + 2 Range GET + Copy) ~350 ms + mesaj POST ~120 ms ≈ **1,4 sn**.
Video 8 MB → transcode 15-40 sn (cihaza bağlı) + PUT ~8 sn ≈ **25-50 sn**.

### 1.2 Alma

1. Karşı tarafın soketine `message.new` düşer (payload'da `thumb_url`, `media_url`, `width`, `height`, `duration_ms`, `bytes`, `view_once`).
2. İstemci **hemen `thumb_url`'ü çeker** (~20 KB, `cached_network_image`) → balon dolar. Asıl dosya **otomatik indirilmez** varsayılan olarak hücresel ağda (§1.4).
3. Otomatik indirme kuralı karşılanıyorsa asıl görsel arka planda çekilir, thumb yerini alır (aynı `Hero` etiketiyle, titremeden).
4. Uygulama kapalıysa push: **"Ahmet: Fotoğraf"** / **"Ahmet: Video"** (`handler.go:197-206` zaten yazıyor; altyazı varsa **"Ahmet: Fotoğraf · altyazı"** olacak şekilde genişletilir).
5. Sohbet listesi satırında `LucideIcons.image`/`video` + "Fotoğraf"/"Video" (`chats_screen.dart:219-247` **zaten hazır**, sadece altyazı birleştirmesi eklenecek).

### 1.3 Görüntüleme

- Balona dokunuş → **tam ekran görüntüleyici** (`Hero`, `PageView` sohbetteki tüm medya üzerinde, `InteractiveViewer` ile pinch-zoom, aşağı sürükleyince kapanır).
- Video → aynı görüntüleyicide `video_player` + **kendi Lucide kontrollerimiz** (play/pause, sürükleme çubuğu, süre). ⚠️ chewie YOK (Material ikon + wakelock_plus + provider getiriyor).
- Üst çubukta gönderen adı + tarih; alt çubukta **Kaydet** (`LucideIcons.download`) · **Sil** (`LucideIcons.trash2`, kendi mesajıysa).
- Sohbet başlığı → "Medya" → **sohbet medya galerisi** (3 sütunlu ızgara, tarihe göre gruplu).

### 1.4 Otomatik indirme ayarı

`shared_preferences` (zaten var) anahtarları: `medya_oto_wifi` (varsayılan: **foto+video açık**), `medya_oto_hucresel` (varsayılan: **yalnız foto**). Ayar ekranı olmadığı için Faz 1'de **ayar yok, sabit politika**: Wi-Fi'de foto otomatik / video **manuel**; hücreselde ikisi de **manuel**. Thumb her zaman otomatik (20 KB).
Ağ tipi tespiti: `connectivity_plus` **eklenmiyor** — bunun yerine "video her zaman manuel, foto her zaman otomatik" sabit kuralı. Basit, ölçülebilir, sıfır bağımlılık. ⚠️ Ayar ekranı geldiğinde gevşetilir.

---

## §2 — BACKEND

### 2.1 Yeni paket: `backend/internal/media/`

Yeni Go bağımlılığı **YOK** (go.mod değişmez).

| Dosya | İçerik |
|---|---|
| `sigv4.go` | Elle AWS SigV4 presign (`crypto/hmac` + `crypto/sha256`). `scratchpad/r2put.js`'teki algoritmanın Go karşılığı: kanonik istek → `AWS4-HMAC-SHA256` → `kDate/kRegion("auto")/kService("s3")/kSigning`. Ayrıca header-auth (HEAD/GET/COPY/DELETE için). |
| `r2.go` | `Head(key)`, `RangeGet(key, from, to)`, `Copy(src,dst)`, `Delete(key)` — hepsi `net/http` + SigV4 header auth. |
| `dogrula.go` | Sihirli bayt + EXIF/GPS reddi + JPEG SOF boyut ayrıştırma + MP4 `ftyp`/`moov` tarama. |
| `limit.go` | Redis Lua kota (desen: `streams/guests.go:52`). |
| `handler.go` | Uçlar. |
| `sweeper.go` | Gecelik: yetim `gecici/`, bağlanmamış `hazir`, süresi dolan `view_once`. Desen: `callsH.StartSweeper` (`cmd/api/main.go:81`). |

**Env (yeni, `backend/.env` — git'e GİRMEZ):**
```
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_ENDPOINT=https://<acct>.r2.cloudflarestorage.com
R2_BUCKET=gebzem-media
MEDIA_BASE_URL=https://medya.gebzem.app
MEDIA_MAX_IMAGE=4194304
MEDIA_MAX_VIDEO=33554432
MEDIA_MAX_THUMB=204800
```
⚠️ `config.Load()` (`config/config.go:20-38`) bunları **okumaz** — proje deseni gereği paket kendi env'ini okur (`calls/handler.go:83-84`, `streams/handler.go:44-45`). `media.NewHandler()` aynı şekilde `os.Getenv` kullanır ve `R2_ACCESS_KEY_ID` boşsa `Enabled()=false` döner → `main.go` "medya: R2 anahtari yok — kapali" yazar, uçlar **kaydedilmez**. **Fail-closed.**

### 2.2 Uç 1 — presign

```
POST /media/upload-url          (Bearer, korumali grup: main.go:145-210)
```
**İstek**
```json
{
  "tip": "image",
  "mime": "image/jpeg",
  "boyut": 284119,
  "md5": "n2Zx...==",
  "en": 1600, "boy": 1200, "sure_ms": 0,
  "kucuk_mime": "image/jpeg",
  "kucuk_boyut": 14203,
  "kucuk_md5": "Qk9y...=="
}
```
**Yanıt 200**
```json
{
  "upload_id": "3f2a…uuid",
  "asil":  { "url": "https://…/gebzem-media/gecici/3f2a….bin?X-Amz-…",
             "basliklar": {"Content-Type":"image/jpeg","Content-MD5":"n2Zx…==","If-None-Match":"*"} },
  "kucuk": { "url": "…/gecici/3f2a….thm?X-Amz-…",
             "basliklar": {"Content-Type":"image/jpeg","Content-MD5":"Qk9y…==","If-None-Match":"*"} },
  "gecerlilik_sn": 300
}
```

**Kapılar (sırayla):**
1. `tip ∈ {image, video}`, `mime` tipe uygun (`image` → jpeg|webp, `video` → mp4). Aksi **415 `desteklenmeyen dosya türü`**.
2. `boyut` > tavan → **413 `dosya çok büyük`**. `kucuk_boyut` > 200 KB → 413.
3. `en*boy > 50_000_000` → **413 `görsel çok büyük`**.
4. `sure_ms > 92_000` (video) → **413 `video en fazla 90 saniye olabilir`**.
5. `md5` geçerli base64 ve 16 bayt değilse → 400.
6. **Kota (Redis Lua, atomik):** saatlik 120, günlük 400, aylık bayt 3 GB; hesap < 24 saatlik ise günlük 30 / 200 MB. Aşımda **429 `çok fazla medya gönderdiniz, biraz sonra tekrar deneyin`**.
7. `media_assets` satırı `status='beklemede'` olarak açılır (`upload_id` = satır id'si).
8. İki presigned PUT üretilir; **`Content-Type`, `Content-MD5`, `If-None-Match` imzaya dahil**, `X-Amz-Expires=300`.

**İmzalanan başlıkların gerekçesi (§2.3):**
- `Content-Type` — Cloudflare presign'da imzaya dahildir; istemci farklı gönderirse **403 SignatureDoesNotMatch**.
- `Content-MD5` — R2 PutObject'te desteklenir; **istemci tam olarak beyan ettiği baytları yükleyebilir, başka hiçbir şeyi**. R2'de `content-length-range` **YOK** (presigned POST policy desteklenmiyor), boyut doğrudan dayatılamıyor; MD5 bu deliği kapatır.
- `If-None-Match: *` — nesne varsa PUT **412** döner ⇒ presigned URL **fiilen tek kullanımlık**.

### 2.3 Uç 2 — commit (doğrulama)

```
POST /media/{upload_id}/commit     (Bearer)
```
**Yanıt 200**
```json
{ "media_id":"3f2a…", "media_url":"https://medya.gebzem.app/img/2026/08/07/3f2a….jpg",
  "thumb_url":"https://medya.gebzem.app/thm/2026/08/07/3f2a….jpg",
  "en":1600,"boy":1200,"sure_ms":0,"boyut":284119 }
```

**Sunucu adımları (hepsi zorunlu):**
1. Satır: `id=upload_id AND owner_id=$user AND status='beklemede' AND created_at > now()-'15 min'`. Yoksa **404**; `status='hazir'|'bagli'` ise **409 `bu yükleme zaten tamamlandı`**.
2. `HEAD gecici/<id>.bin` → `Content-Length == beklenen_boyut` (**tam eşitlik**), `ETag == md5_hex`. Uymazsa reddet.
3. `Range GET bytes=0-262143`:
   - **JPEG**: `FF D8 FF`. Ardından APP1 (`FF E1`) + `Exif\0\0` bulunursa → **REDDET** (`konum/metadata bilgisi içeriyor`). `flutter_image_compress` varsayılan olarak EXIF **taşımaz** → uyumlu istemci asla bu dala düşmez. Boyut, **SOF0/SOF2 işaretçisinden okunur** (istemcinin beyanına güvenilmez) ve 50 MP kapısı buradan uygulanır.
   - **WebP**: `RIFF` + offset 8 `WEBP`; boyut `VP8X`/`VP8L`/`VP8 ` başlığından.
   - **MP4**: offset 4 `ftyp`, marka ∈ {isom,iso2,mp41,mp42,avc1,mp4v}. Üst düzey kutular gezilir; `moov` ilk 256 KB'da yoksa **son 256 KB da Range GET** edilir. `moov` içinde `©xyz` veya `com.apple.quicktime.location` bulunursa → **REDDET**.
4. Küçük resim aynı şekilde (yalnız JPEG, ≤200 KB, EXIF yok).
5. `CopyObject gecici/… → img|vid/<yyyy>/<mm>/<dd>/<uuid>.<ext>` ve `thm/…`; ardından `DeleteObject gecici/…`.
6. `status='hazir'`, `object_key`, `thumb_key`, `md5_hex`, gerçek `bytes`, ayrıştırılmış `width/height` yazılır. `committed_at=now()`.
7. Reddedilen her yolda: `DeleteObject` (iki nesne) + `status='reddedildi'` + `reject_reason` + **422 `dosya doğrulanamadı`** (+ Türkçe alt sebep).

⚠️ **CopyObject teyit maddesi:** R2'nin `CopyObject`'i ≤5 GB nesnelerde belgelenmiş; bizim nesneler ≤32 MB. **Sahada 1 kez ölçülecek.** Çalışmazsa yedek plan: presign doğrudan **nihai** anahtara yapılır, `gecici/` kalkar, doğrulanmamış nesneyi 24 saatte sweeper siler — güvenlik farkı: doğrulanmamış nesne kısa süre erişilebilir olur (anahtar tahmin edilemez, ama "bedava dosya barındırma" riski doğar).

### 2.4 Uç 3 — iptal (kota/çöp temizliği)

```
POST /media/{upload_id}/cancel  → 200 {"status":"ok"}
```
`status='reddedildi'`, iki nesne silinir. Kota **iade edilmez** (kötüye kullanım freni).

### 2.5 DEĞİŞEN: `POST /chats/{chatID}/messages`

**Dosya:** `backend/internal/chat/handler.go`

| Satır | Değişiklik |
|---|---|
| `:125-130` | `sendMessageReq`'e `MediaID string`, `ViewOnce bool` eklenir. ⚠️ **`MediaURL` alanı struct'ta KALIR ama ARTIK YOK SAYILIR** — kaldırılırsa eski istemciler 400 almaz ama alan sessizce yazılmaya devam ederdi; yok saymak hem eski istemciyi kırmaz hem açığı kapatır. Boş değilse Sentry'e ölçüm (`istemci media_url gonderdi`). |
| `:152-157` | Beyaz liste **DEĞİŞMEZ** (`image`/`video` zaten var). ⚠️ `system` EKLENMEZ. |
| **YENİ (`:157` sonrası)** | `if req.Type=="image"\|\|req.Type=="video"` → `media_id` **zorunlu**; `text` ise `media_id` **boş olmalı** (aksi 400). `audio`/`location` + `media_id` → 400 (bu fazda tasarlanmadı). |
| **YENİ** | Medya sahiplik kapısı — tek sorgu: `UPDATE media_assets SET status='bagli', linked_at=now() WHERE id=$1 AND owner_id=$2 AND status IN ('hazir','bagli') AND deleted_at IS NULL RETURNING kind, object_key, thumb_key, mime, bytes, width, height, duration_ms`. Satır dönmezse **403 `bu medya size ait değil`**. ⚠️ `kind` ile `type` uyuşmalı (`image↔image`, `video↔video`), yoksa 400. ⚠️ `'bagli'` da kabul → **aynı fotoğrafı ikinci kez göndermek çalışır** (dedupe, §6.6). |
| `:159-164` | **Engel kontrolü eklenir.** Bugün yorumda "uyelik + engel kontrolu" yazıyor ama engel bakılmıyor (`chatMemberIDs` `:409-431` yalnız üyelik). `len(members)==1` (yani 1:1) ise tek `EXISTS` sorgusu → engelliyse **403 `bu kullanıcıya mesaj gönderemezsiniz`**. Grupta uygulanmaz (tek engelli üye tüm grubu kilitlemesin). |
| `:168-171` | INSERT: `media_id`, `view_once` sütunları eklenir. `media_url` sütununa **''** yazılır (artık URL DB'de tutulmuyor, `object_key`'den türetiliyor). |
| `:185-189` | WS payload'ı genişler (§4). |
| `:207-209` | 🔴 **HATA DÜZELTMESİ:** `preview[:80]` bayt kesiyor → Türkçe karakter ortadan bölünüp push gövdesine geçersiz UTF-8 gidiyor. `[]rune(preview)` üzerinden kesilecek. |
| `:197-206` | Altyazı varsa `"Fotoğraf · " + altyazı` / `"Video · " + altyazı`. |
| `:213` | Yanıt **tam mesaj nesnesi** döner (`id, created_at, type, content, media_url, thumb_url, width, height, duration_ms, bytes, view_once, reply_to_id`) — istemci iyimser balonu tam listeyi yeniden çekmeden değiştirebilsin diye. Eski alanlar korunur (ek).ative |
| `:190` (isteğe bağlı, ayrı işaretli) | `To: members` gönderenin **kendi diğer cihazlarını** dışlıyor (`:421-425`). `append(members, userID)` yapılırsa çok cihazlı senkron çalışır; istemci zaten id ile tekilliyor (`chats_provider.dart:93`) → çift balon riski yok. **Bu turda YAPILMASI önerilir ama ayrı commit.** |

### 2.6 DEĞİŞEN: `GET /chats/{chatID}/messages`

**Dosya:** `handler.go:234-265`

```sql
SELECT m.id, m.sender_id, m.type,
       CASE WHEN m.deleted_for_all THEN '' ELSE m.content END,
       m.reply_to_id, m.deleted_for_all, m.created_at,
       m.view_once, m.viewed_at,
       COALESCE(a.object_key,''), COALESCE(a.thumb_key,''), COALESCE(a.mime,''),
       COALESCE(a.width,0), COALESCE(a.height,0), COALESCE(a.duration_ms,0),
       COALESCE(a.bytes,0), COALESCE(a.status,'')
FROM messages m
LEFT JOIN media_assets a ON a.id = m.media_id
WHERE m.chat_id=$1 AND m.id<$2
ORDER BY m.id DESC LIMIT $3
```
Go tarafında `media_url` **türetilir**:
```go
url := ""
if key != "" && !delForAll && status != "silindi" &&
   !(viewOnce && viewedAt != nil) {           // tek seferlik + acilmis -> URL YOK
    url = mediaBase + "/" + key
}
```
⚠️ **`media_url` sütunu artık okunmuyor** ama tabloda duruyor (additive kural). Eski satırlar (bugün hepsi `''`) etkilenmiyor.

### 2.7 YENİ: sohbet medya galerisi

```
GET /chats/{chatID}/media?before_id=&limit=      (varsayilan 60, tavan 120)
```
`WHERE m.chat_id=$1 AND m.media_id IS NOT NULL AND NOT m.deleted_for_all AND NOT m.view_once AND a.status<>'silindi'`
Yanıt: `[{id, sender_id, type, media_url, thumb_url, width, height, duration_ms, created_at}]`
Index: `idx_messages_media` (§3).

### 2.8 YENİ: tek seferlik görüntüleme

```
POST /messages/{id}/view      (Bearer)
```
- Yalnız **alıcı** (gönderen değil) + sohbet üyesi.
- `UPDATE messages SET viewed_at=now() WHERE id=$1 AND view_once AND viewed_at IS NULL RETURNING media_id` — atomik, ikinci çağrı **410 `bu medya zaten görüntülendi`**.
- Yanıt: `{"media_url":"…","gecerlilik_sn":120}`.
- WS `message.viewed` yayınlanır (§4).
- Sunucu **120 sn sonra** nesneyi siler: `time.AfterFunc` + sweeper yedeği (`viewed_at < now()-'5 min' AND a.deleted_at IS NULL` → `Delete` + `status='silindi'`).
- ⚠️ **DÜRÜST SINIR:** o 120 sn içinde URL kopyalanabilir; iOS'ta ekran görüntüsü **engellenemez**. Android'de `FLAG_SECURE` uygulanır (§7.5). Kullanıcıya "kimse kaydedemez" **vaat edilmeyecek**.

### 2.9 YENİ: mesaj silme (5651 "4 saat" ve tek seferlik için zorunlu)

```
DELETE /messages/{id}          (Bearer, yalniz gonderen, gonderimden <60 dk)
```
`deleted_for_all=true` + `media_assets.status='silindi'` + R2 iki nesne silinir + WS `message.deleted`.
⚠️ `deleted_for_all` sütunu **bugün hiçbir yerde yazılmıyor** (`handler.go:236-238` sadece okuyor; Flutter `chat_screen.dart:647-650` "Bu mesaj silindi" balonunu **zaten çiziyor**) — yani bu uç, var olan ölü dalı canlandırıyor.

### 2.10 `main.go` değişikliği

```go
mediaH := media.NewHandler(db, rdb)          // main.go:78 civari
if mediaH.Enabled() { log.Println("medya (R2): aktif"); mediaH.StartSweeper(ctx) }
...
// korumali grup icinde (main.go:162 civari):
if mediaH.Enabled() {
    r.Post("/media/upload-url", mediaH.UploadURL)
    r.Post("/media/{id}/commit", mediaH.Commit)
    r.Post("/media/{id}/cancel", mediaH.Cancel)
}
r.Get("/chats/{chatID}/media", chatH.ListMedia)
r.Post("/messages/{id}/view",  chatH.ViewOnce)
r.Delete("/messages/{id}",     chatH.DeleteMessage)
```
⚠️ **Gövde boyutu sınırı:** `main.go:97-102` zincirinde `http.MaxBytesReader` yok. Eklenir: korumalı grubun başına `middleware.RequestSize(64<<10)` (64 KB) — **medya gövdesi sunucudan geçmediği için** bu tavan bol bol yeter ve JSON bombasını keser. ⚠️ `/livekit/webhook` (`main.go:133`) bu grubun DIŞINDA, etkilenmez.

### 2.11 Cloudflare (elle, tek seferlik)

1. `gebzem-media` bucket'ına custom domain **`medya.gebzem.app`** bağla (zone `.env.infra`'da).
2. **Response Header Transform Rule** (`hostname eq "medya.gebzem.app"`): `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; sandbox`, `X-Frame-Options: DENY`, `Cross-Origin-Resource-Policy: same-site`, `Referrer-Policy: no-referrer`.
3. **Yaşam döngüsü:** `gecici/` → 1 gün sil · `img|vid|thm/` → 30 gün Infrequent Access, 365 gün sil · tamamlanmamış multipart → 1 gün iptal.
4. **Cache Rule:** `img|vid|thm/` → Edge TTL 1 yıl (anahtar zaten benzersiz).

⚠️ **Medya ASLA `api.gebzem.app` üzerinden sunulmaz** — admin paneli (`/admin/izle`, `ADMIN_KEY`) o host'ta.

---

## §3 — VERİTABANI: `014_medya.sql`

**TAMAMEN ADDITIVE.** Eski binary yeni sütunları görmezden gelir, yeni binary eski satırlarla çalışır → migration ile deploy aynı turda güvenli.

```sql
-- 014_medya.sql — foto/video paylasimi (ADDITIVE)
-- Not: messages.type CHECK'i (001_init.sql:55) 'image','video' iceriyor -> ALTER GEREKMEZ.
-- Not: messages.media_url (001_init.sql:57) DOKUNULMADAN kalir; yeni medya mesajlarinda ''
--      olur, URL media_assets.object_key'den OKUMA ANINDA turetilir (Faz-2'de imzali URL'e
--      gecis istemciyi kirmasin diye).

CREATE TABLE IF NOT EXISTS media_assets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK (kind IN ('image','video')),
    object_key    TEXT NOT NULL DEFAULT '',   -- commit'ten ONCE bos (nesne gecici/ altinda)
    thumb_key     TEXT NOT NULL DEFAULT '',
    mime          TEXT NOT NULL DEFAULT '',
    bytes         BIGINT NOT NULL DEFAULT 0,
    thumb_bytes   BIGINT NOT NULL DEFAULT 0,
    width         INT NOT NULL DEFAULT 0,
    height        INT NOT NULL DEFAULT 0,
    duration_ms   INT NOT NULL DEFAULT 0,
    md5_hex       TEXT NOT NULL DEFAULT '',   -- R2 ETag (tek parca PUT) = dedupe + toplu kaldirma anahtari
    status        TEXT NOT NULL DEFAULT 'beklemede'
                  CHECK (status IN ('beklemede','hazir','bagli','reddedildi','silindi')),
    reject_reason TEXT NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    committed_at  TIMESTAMPTZ,
    linked_at     TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ
);

-- Sweeper: yetim 'beklemede' (>15 dk) ve baglanmamis 'hazir' (>7 gun) satirlar
CREATE INDEX IF NOT EXISTS idx_media_sweep
    ON media_assets (status, created_at)
    WHERE status IN ('beklemede','hazir');

-- Kullanicinin kotasi / admin incelemesi
CREATE INDEX IF NOT EXISTS idx_media_owner
    ON media_assets (owner_id, created_at DESC);

-- Ayni dosyanin tum kopyalari (5651: tek hamlede kaldirma) + dedupe
CREATE INDEX IF NOT EXISTS idx_media_md5
    ON media_assets (md5_hex)
    WHERE md5_hex <> '';

-- Anahtar tekilligi: ayni nesneye iki satir isaret etmesin
CREATE UNIQUE INDEX IF NOT EXISTS idx_media_key
    ON media_assets (object_key)
    WHERE object_key <> '';

-- ⚠️ ON DELETE SET NULL — CASCADE DEGIL: bir medya kaldirilinca MESAJ SATIRI DURMALI
--    (balon "Medya kaldirildi" yazar; sohbet gecmisi delik acmaz).
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS media_id  UUID REFERENCES media_assets(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS view_once BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS viewed_at TIMESTAMPTZ;

-- Sohbet medya galerisi (GET /chats/{id}/media) — kismi index, tablo buyumesin
CREATE INDEX IF NOT EXISTS idx_messages_media
    ON messages (chat_id, id DESC)
    WHERE media_id IS NOT NULL;

-- Tek seferlik temizligi (sweeper): acilmis ama nesnesi hala duran satirlar
CREATE INDEX IF NOT EXISTS idx_messages_viewonce
    ON messages (viewed_at)
    WHERE view_once AND viewed_at IS NOT NULL;
```

**`messages` ile bağlantı:** `messages.media_id → media_assets.id`. Bir mesajın medyası = bir asset. Küçük resim **ayrı satır değil**, aynı satırın `thumb_key` alanı (1:1 ilişki; ayrı tablo gereksiz JOIN üretirdi).

**Sweeper kuralları (`media/sweeper.go`, 10 dakikada bir):**
| Durum | Koşul | Eylem |
|---|---|---|
| Yetim yükleme | `status='beklemede' AND created_at < now()-'15 min'` | `gecici/` iki nesne sil, `status='reddedildi'` |
| Bağlanmamış hazır | `status='hazir' AND created_at < now()-'7 days'` | nesneler sil, `status='silindi'` |
| Açılmış tek seferlik | `messages.view_once AND viewed_at < now()-'5 min' AND a.deleted_at IS NULL` | nesneler sil, `status='silindi'` |
| Süresi dolan medya | `committed_at < now()-'365 days'` | `status='silindi'` (R2 lifecycle nesneyi zaten sildi — DB senkronu) |

---

## §4 — WEBSOCKET SÖZLEŞMESİ

`chat/hub.go` **hiç değişmez** (`Event.Payload` ham JSON, `:33`).

### 4.1 `message.new` — genişletilir (kırıcı değil)

```json
{
  "type":"message.new",
  "chat_id":"…",
  "payload":{
    "id": 12345,
    "chat_id":"…", "sender_id":"…",
    "type":"image",
    "content":"altyazi metni",
    "media_url":"https://medya.gebzem.app/img/2026/08/07/3f2a….jpg",
    "thumb_url":"https://medya.gebzem.app/thm/2026/08/07/3f2a….jpg",
    "mime":"image/jpeg",
    "width":1600, "height":1200, "duration_ms":0, "bytes":284119,
    "view_once":false,
    "reply_to_id":null,
    "created_at":"2026-08-07T12:33:01Z"
  }
}
```
⚠️ Eski istemciler yeni anahtarları görmezden gelir (`models.dart:75-84` hepsi `??` varsayılanlı) → **ileri uyumlu**.
⚠️ `view_once=true` ise `media_url` **payload'da BOŞ gönderilir** — alıcı yalnız `thumb_url`... hayır: tek seferlikte thumb da gösterilmez. **`view_once=true` → hem `media_url` hem `thumb_url` BOŞ**; alıcı `POST /messages/{id}/view` ile URL alır.

### 4.2 YENİ: `message.viewed`

```json
{"type":"message.viewed","chat_id":"…","payload":{"message_id":12345,"viewer_id":"…"}}
```
Hedef: `To = [gönderen]` (**alıcılar değil**). Gönderenin balonu "Açıldı" olur.

### 4.3 YENİ: `message.deleted`

```json
{"type":"message.deleted","chat_id":"…","payload":{"message_id":12345}}
```
Hedef: `To = chatMemberIDs`. Alıcıda balon **anında** "Bu mesaj silindi"ye döner (`chat_screen.dart:647-650` dalı zaten var).

### 4.4 Yükleme ilerlemesi — **WS'ten GİTMEZ**

Tamamen yerel durum. Gerekçe: 50K kullanıcıda saniyede binlerce ilerleme çerçevesi hub'ı ve Redis pub/sub'ı boğar; ayrıca `hub.deliver` kuyruk dolunca **sessizce düşürüyor** (`hub.go:99-101`) → güvenilmez kanal.

---

## §5 — FLUTTER

### 5.1 pubspec.yaml — eklenecekler (YALNIZ bu faz)

```yaml
  # ---- MEDYA: FOTOGRAF + VIDEO (Faz 2 medya) ----
  # Galeri/kamera secimi. iOS PHPicker / Android Photo Picker -> IZIN DIYALOGU YOK.
  # ⚠️ `camera` paketi KULLANILMADI: iOS'ta flutter_webrtc TEK paylasilan videoCapturer
  #    tutuyor (AppDelegate.swift:668/737/905); ucuncu bir AVCaptureSession turu 50/67
  #    hatasini geri getirir. image_picker sistem-sahipli modal acar.
  # ⚠️ Android'de MainActivity oldurulebilir -> donuste retrieveLostData() ZORUNLU.
  image_picker: ^1.2.3

  # Gorsel sikistirma (native). VARSAYILAN OLARAK EXIF SILER -> GPS sizintisi kapali.
  # ⚠️ YAPMA: keepExif: true yazma. ⚠️ format: CompressFormat.jpeg (HEIC/PNG -> JPEG).
  flutter_image_compress: ^2.5.1

  # Video sikistirma + getMediaInfo + getFileThumbnail. %100 NATIVE
  # (AVAssetExportSession / MediaCodec), FFmpeg binary'si YOK.
  # ⚠️ 18 aydir guncellenmemis; API yuzeyi kucuk oldugu icin kabul edildi.
  # ⚠️ ffmpeg_kit_flutter ARSIVLENDI (1 Nis 2025 binary'ler silindi); fork
  #    ffmpeg_kit_flutter_new "effectively GPL v3.0" + ~30MB -> BILEREK ALINMADI.
  # 🔴 ZORUNLU: sikistirma AKTIF ARAMA/ODA/YAYIN SIRASINDA CALISTIRILMAZ (donanim
  #    video kodlayici cakismasi) -> medya_kapisi.dart
  video_compress: ^3.1.4

  # Video oynatma. chewie EKLENMEDI: Material ikon (Lucide kurali ihlali) +
  # wakelock_plus (turu 60'ta elendi) + provider (Riverpod var) getiriyor.
  # Kontroller KENDIMIZ + Lucide.
  # 🔴 ZORUNLU: oynatma AKTIF ARAMA/ODA/YAYIN SIRASINDA ENGELLENIR (iOS'ta AVAudioSession
  #    kategorisini playAndRecord'dan playback'e cevirir -> turu 64 (!pri) sinifi hata).
  video_player: ^2.13.0

  # Gorsel disk onbellegi. ⚠️ flutter_cache_manager'i AYRICA ekleme (bu paket getiriyor).
  cached_network_image: ^3.4.1

  # Gecici/kalici dizinler (sikistirma ciktisi, giden kuyrugu dosyalari)
  path_provider: ^2.1.6

  # Content-MD5 (base64) — presigned PUT imzasina dahil. ⚠️ compute() ile ISOLATE'te.
  crypto: ^3.0.6
```
⚠️ Sürümler `flutter pub add` ile teyit edilecek; **`flutter_webrtc: 1.4.0` pini ve `sentry_flutter 9.x` bozulmamalı** → `flutter pub deps` çakışma kontrolü zorunlu.
⚠️ **Info.plist:** `NSPhotoLibraryUsageDescription` + `NSPhotoLibraryAddUsageDescription` (kaydetme için). `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` **zaten var** (arama).
⚠️ **AndroidManifest:** yeni izin **GEREKMİYOR** (Photo Picker). `READ_MEDIA_*` eklenmeyecek.
**TAHMİN APK artışı: +2,5 – 4,5 MB** (en büyük kalem `video_player` → Media3/ExoPlayer). Ölçüm: `flutter build apk --analyze-size`.

### 5.2 Yeni/değişen dosyalar

| Dosya | Rol |
|---|---|
| **YENİ** `features/chats/medya/medya_kapisi.dart` | 🔴 Tek çakışma kapısı. `mesgulMu`yu **çağırır, kopyalamaz**. |
| **YENİ** `features/chats/medya/giden_medya.dart` | `GidenMedya` modeli + durum enum'u. |
| **YENİ** `features/chats/medya/medya_kuyrugu.dart` | `StateNotifier` outbox, **app-scoped** (autoDispose DEĞİL), disk kalıcı. |
| **YENİ** `features/chats/medya/medya_yukleyici.dart` | sıkıştır → MD5 → presign → PUT → commit → mesaj POST zinciri. |
| **YENİ** `features/chats/medya/medya_secici.dart` | Ataç alt paneli. |
| **YENİ** `features/chats/medya/medya_onizleme_screen.dart` | Önizleme/altyazı/HD/tek-seferlik ekranı. |
| **YENİ** `features/chats/medya/medya_balonu.dart` | `MedyaBalonu` (foto+video, iyimser+gerçek). |
| **YENİ** `features/chats/medya/medya_goruntuleyici.dart` | Tam ekran görüntüleyici (PageView + zoom + video). |
| **YENİ** `features/chats/medya/sohbet_medya_galerisi.dart` | 3 sütunlu ızgara. |
| **YENİ** `core/r2_dio.dart` | R2 PUT için **ayrı Dio** (§5.6). |
| DEĞİŞEN `features/chats/models.dart:52-85` | `Message`'a `thumbUrl, mime, width, height, durationMs, bytes, viewOnce, viewedAt` |
| DEĞİŞEN `features/chats/chats_provider.dart:61-83` | `load()` sayfalama + `send()` iyimser ekleme (tam `load()` **kaldırılır**) |
| DEĞİŞEN `features/chats/chat_screen.dart:251-261` | `msg.type` switch → `system` / `image`\|`video` / diğer |
| DEĞİŞEN `features/chats/chat_screen.dart:269-303` | Giriş çubuğuna ataç (`:291` yer tutucunun yeri) |
| DEĞİŞEN `features/chats/chat_screen.dart:235-265` | Liste `itemCount: list.length + kuyruk.length + 1` |
| DEĞİŞEN `features/chats/chats_screen.dart:238-260` | `_preview` altyazı birleştirmesi (ikon zaten hazır) |
| DEĞİŞEN `core/api.dart` | ⚠️ **`/media/` 401 muafiyet listesine EKLENMEZ** (`:52-57`) |

### 5.3 Durum yönetimi (Riverpod)

```dart
// medya_kuyrugu.dart
enum GidenDurum { hazirlaniyor, gorusmeBekliyor, yukleniyor, dogrulaniyor,
                  gonderiliyor, gonderildi, hata, iptal }

class GidenMedya {
  final String yerelId;      // uuid — iyimser balonun kimligi
  final String chatId;
  final String tip;          // image | video
  final String kaynakYol;    // sikistirilmis ASIL dosya (kalici dizin)
  final String kucukYol;     // sikistirilmis KUCUK resim
  final String altyazi;
  final bool viewOnce, hd;
  final int en, boy, sureMs, boyut;
  final String md5;
  GidenDurum durum;
  double ilerleme;           // 0..1
  int deneme;                // <=4
  String? uploadId, mediaId, hataMetni;
  int? sunucuMesajId;
}

final medyaKuyruguProvider =
    StateNotifierProvider<MedyaKuyrugu, List<GidenMedya>>(MedyaKuyrugu.new);
```

⚠️⚠️ **KRİTİK:** `messagesProvider` **`family.autoDispose`** (`chats_provider.dart:121-123`). Kuyruk oraya konulursa **kullanıcı sohbetten çıkar çıkmaz yükleme iptal olur**. Bu yüzden `medyaKuyruguProvider` **uygulama ömürlü**, `autoDispose` **DEĞİL**, ve `ProviderScope` kökünde yaşar.

**Kalıcılık:** kuyruk meta verisi `shared_preferences` anahtarı `medya_kuyrugu_v1` (JSON dizi) — her durum değişiminde yazılır. Dosyalar `getApplicationDocumentsDirectory()/medya_giden/` altında (⚠️ **`getTemporaryDirectory()` DEĞİL** — iOS tmp'yi haber vermeden siler). Gönderim bitince dosyalar silinir.

**Uygulama açılışında:** `MedyaKuyrugu` kurucusunda disk okunur; `yukleniyor`/`dogrulaniyor`/`gonderiliyor` durumundakiler `hata`ya değil **kaldıkları adıma** geri alınır ve yeniden denenir (commit ve mesaj POST **idempotent** — §6.3).

### 5.4 `medya_kapisi.dart` — TEK ÇAKIŞMA KAPISI

```dart
/// ⚠️⚠️ TEK KAYNAK. `mesgulMu` MANTIGINI BURAYA KOPYALAMA — CAGIR.
/// (call_provider.dart:162 — CLAUDE.md: "bu mantigi cagiran yerlere kopyalama, drift eder")
class MedyaKapisi {
  static bool kameraSerbest(WidgetRef ref) =>
      !ref.read(callServiceProvider.notifier)
           .mesgulMu(etiket: 'medya-kamera');       // odaYayinMuaf: false (VARSAYILAN, fail-closed)

  static bool kodlayiciSerbest(WidgetRef ref) =>
      !ref.read(callServiceProvider.notifier)
           .mesgulMu(etiket: 'medya-kodlayici');

  static bool oynatmaSerbest(WidgetRef ref) =>
      !ref.read(callServiceProvider.notifier)
           .mesgulMu(etiket: 'medya-oynatma');
}
```
⚠️ Üçü de `odaYayinMuaf: false` (varsayılan) geçer: oda/yayın **duraklatılabiliyor** (turu 72/73) ama duraklatma **gelen arama için** yazıldı; bir fotoğraf çekimi uğruna sesli odayı duraklatmak ürün olarak yanlış. **Fail-closed.**

### 5.5 Balon görünümü (Lucide, EMOJİ YOK)

```
Align(mine ? right : left)
└ ConstrainedBox(maxWidth: min(ekranGenislik*0.72, 280))
  └ Material(color: bubbleMine/bubbleOther, radius 12, clip: antiAlias)
     └ Column(min)
        ├ Stack
        │   ├ AspectRatio(en/boy, 0.62..1.85 arasina KISILIR)
        │   │   └ CachedNetworkImage(thumb_url)          // asil gelince cross-fade
        │   ├ [video]   ortada 48px daire + LucideIcons.play
        │   ├ [video]   sol alt hap: LucideIcons.timer + "0:42"
        │   ├ [indirilmemis] sag alt hap: LucideIcons.download + "8,4 MB"
        │   ├ [yukleniyor]  merkez: CircularProgressIndicator(value) + LucideIcons.x
        │   ├ [hata]        merkez: LucideIcons.imageOff + "Tekrar dene"
        │   ├ [tek seferlik] merkez: LucideIcons.eye + "Tek seferlik"  (thumb CIZILMEZ)
        │   └ [altyazi YOK] sag alt: saat + LucideIcons.checkCheck (siyah %45 hap uzerinde)
        ├ [altyazi VAR] Padding(10,8,10,2) → Text(content, 15.5)
        └ [altyazi VAR] Row(end): saat + LucideIcons.checkCheck
```
- `checkCheck` ikonu + `scheme.tickRead` **mevcut desenle birebir** (`chat_screen.dart:661-665`).
- ⚠️ **Emoji yok, Material ikon yok** (turu 62). "HD" bir **metin rozeti** (ikon değil).
- ⚠️ `Hero(tag: 'medya-${msg.id}')` — iyimser balonda `tag: 'medya-yerel-${yerelId}'`; gönderim bitince **tag değişir**, bu yüzden geçiş sırasında `AnimatedSwitcher` **kullanılmaz** (turu 27-31 dersi: renderer/element dallar arası yer değiştirince yeniden kurulur). Sadece `setState` ile içerik değişir, **widget ağacındaki konum sabit kalır**.

### 5.6 R2 PUT için AYRI Dio — iki sorunu tek kararla çözer

```dart
// core/r2_dio.dart
final r2DioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 180),   // ⚠️ api.dart'ta sendTimeout HIC TANIMLI DEGIL
      receiveTimeout: const Duration(seconds: 30),
    )));
// ⚠️ Interceptor YOK  -> Authorization: Bearer EKLENMEZ (eklenirse SigV4 imzasi BOZULUR)
// ⚠️ addSentry() YOK  -> presigned URL'deki X-Amz-Signature Sentry breadcrumb'ina SIZMAZ
//    (sentry_dio: ^9.6.0 pubspec.yaml:55'te KURULU — apiProvider'i kullanirsak sizar)
```
İki bağımsız tuzak (imza bozulması + gizli anahtar sızıntısı) tek kararla kapanıyor.

### 5.7 Yükleme zinciri (`medya_yukleyici.dart`)

```
1  hazirla()
   · gorsel: FlutterImageCompress.compressWithFile(
        minWidth/minHeight = hd?2560:1600, quality = hd?88:82,
        format: CompressFormat.jpeg, keepExif: FALSE)          // ⚠️ keepExif ASLA true
   · gorselin GERCEK boyutu: ui.ImageDescriptor.encoded(...)   // TAM DECODE YOK
   · video: MedyaKapisi.kodlayiciSerbest() FALSE ise -> durum=gorusmeBekliyor, DUR
            TRUE ise VideoCompress.compressVideo(quality: Res1280x720)
            + VideoCompress.getMediaInfo (en/boy/sure)
            + VideoCompress.getFileThumbnail(quality:60)  -> kucuk resim
   · md5 = await compute(_md5b64, bytes)                       // ⚠️ ISOLATE
2  presign()  POST /media/upload-url
3  yukle()    r2Dio.put(url, data: Stream, options: Options(headers: basliklar),
                        onSendProgress: ..., cancelToken: ...)
              iki nesne SIRAYLA (once kucuk, sonra asil — kucuk basarisizsa buyugu bosuna gitmesin)
4  commit()   POST /media/{upload_id}/commit
5  gonder()   POST /chats/{chatId}/messages {type, content: altyazi, media_id, view_once}
6  temizle()  yerel dosyalar sil, kuyruktan cikar, messagesProvider'a gercek mesaji ekle
```
**Eşzamanlılık:** aynı anda **1** öğe (`Completer` zinciri). Gerekçe: mobil şebekede paralel yükleme toplam süreyi kısaltmaz, WebRTC ile bant genişliği rekabetini artırır.
**Tekrar:** 2 sn → 6 sn → 15 sn → 40 sn, **en fazla 4 deneme**, sonra `hata`. Otomatik sonsuz tekrar **yok** (kota yakar).

---

## §6 — KENAR DURUMLAR

### 6.1 Ağ koptu
- **PUT sırasında:** `DioExceptionType.connectionError` → durum `yukleniyor`da kalır, geri sayımlı tekrar. Balonda `LucideIcons.imageOff` + "Bağlantı bekleniyor".
- ⚠️ **Yarım PUT sonrası tekrar:** `If-None-Match: *` yüzünden ikinci PUT **412** dönebilir (R2 kısmi nesne yazdıysa). Çözüm: **412 alınca doğrudan `commit`e geç** — nesne zaten oradadır; `HEAD` boyut/ETag'i doğrular, bozuksa 422 alır ve kullanıcı yeni bir `upload_id` ile baştan dener (`presign` yeniden çağrılır, **yeni UUID**).
- **`commit` sırasında:** idempotent değil (satır `beklemede`den çıkar). Ağ hatası alınırsa istemci **aynı `upload_id` ile tekrar dener**; sunucu `409` dönerse (zaten commit edilmiş) istemci `409` gövdesindeki `media_id`yi kullanır. → **`409` yanıtı `media_id` taşımalı.**
- **Mesaj POST sırasında:** `media_id` elde; tekrar denenir. Çift mesaj riski: istemci `Idempotency-Key` göndermez; ⚠️ **çift balon olabilir**. Karşı önlem: mesaj POST'u başarısız olup zaman aşımına düşerse istemci önce `GET /chats/{id}/messages?limit=5` ile aynı `media_id`li mesaj var mı bakar; varsa tekrar göndermez.

### 6.2 Uygulama arka plana geçti
- iOS: Dart isolate askıya alınır → PUT donar. Ön plana dönüşte `AppLifecycleState.resumed` → kuyruk `devamEt()` çağrılır.
- Android 14+: cached-app freezer ~10 sn sonra süreci dondurur (turu 32-33 kanıtı). Aynı davranış.
- ⚠️ **Arama sürerken** `AramaServisi` FGS ayakta olduğu için süreç donmaz → yükleme devam eder. Bu **istenmeyen** bir yan etki değil, ama §7.3'teki video kuralı zaten büyük yüklemeyi engelliyor.

### 6.3 Uygulama ÖLDÜRÜLDÜ
- Kuyruk diskte (`shared_preferences` + `medya_giden/` dosyaları). Açılışta okunur, kaldığı adımdan devam.
- ⚠️ Kayıp senaryosu: **PUT tamamlandı ama `commit` yazılmadan öldürüldü** → sweeper 15 dk sonra `gecici/` nesnesini siler; istemci `commit` denediğinde `404` alır → `presign`den baştan (dosya hâlâ yerelde). Doğru davranış.
- ⚠️ **Android'de `image_picker` sırasında MainActivity öldürülebilir** → `retrieveLostData()` uygulamaya dönüşte **zorunlu** çağrılır; yoksa kullanıcının seçtiği fotoğraf sessizce kaybolur.

### 6.4 İzin reddedildi
- Galeri: **izin istenmez** (PHPicker / Photo Picker). iOS'ta "Seçili fotoğraflar" (limited) modu da sorunsuz — PHPicker bundan bağımsızdır.
- Kamera: izin zaten arama akışında alınmış. Reddedilmişse satır içi açıklama + "Ayarları aç". ⚠️ **`openAppSettings()` çağrısı bir arama/oda/yayın sırasında YAPILMAZ** (turu 56: ayar ekranına sıçrama Activity'yi duraklatır, izin diyaloğu asılı kalır) — zaten kamera o durumda engelli.
- Kaydetme (iOS `NSPhotoLibraryAddUsageDescription`): reddedilirse "Fotoğraf kaydedilemedi, galeri izni gerekli".

### 6.5 Dosya çok büyük
- Sıkıştırma **öncesi**: video ham dosya > 300 MB → hiç açma, "Bu video çok büyük".
- Sıkıştırma **sonrası** hâlâ > tavan (32 MB) → "Video çok uzun veya çok yüksek kaliteli. En fazla 90 saniye gönderebilirsiniz."
- Sunucu **413** dönerse aynı metin gösterilir (`apiErrorMessage`, `api.dart:80`, sunucunun `error` alanını **aynen** basıyor → sunucu mesajları **Türkçe ve doğru karakterli** yazılacak).

### 6.6 Aynı dosya iki kez
- İstemci `shared_preferences`'ta `md5 → media_id` haritası tutar (son 200 kayıt). Eşleşme varsa **sıkıştırma + yükleme atlanır**, doğrudan mesaj POST edilir.
- Sunucu tarafı bunu destekler: sahiplik sorgusunda `status IN ('hazir','bagli')` (§2.5) → **aynı asset yeni bir mesaja bağlanabilir**.
- ⚠️ Farklı kullanıcı aynı `media_id`yi kullanamaz (`owner_id=$user` kapısı).
- ⚠️ Yerel harita bayatsa (asset silinmişse) sunucu **403** döner → istemci haritadan siler ve normal yükleme yolunu çalıştırır.

### 6.7 Gönderim sırasında sohbetten çıkıldı
- Kuyruk **app-scoped** olduğu için hiçbir şey iptal olmaz (`messagesProvider` autoDispose olsa bile).
- Sohbete geri dönünce `medyaKuyruguProvider` `chatId`ye göre filtrelenip aynı iyimser balonlar yeniden çizilir.
- Uygulama başka bir sohbetteyken gönderim biterse: sohbet listesi WS `message.new` ile zaten tazeleniyor (`chats_provider.dart:32-35`).

### 6.8 Alıcı engelledi
- `SendMessage` içindeki yeni engel kapısı **403 `bu kullanıcıya mesaj gönderemezsiniz`** döner.
- ⚠️ O ana kadar medya **zaten R2'ye yüklenmiş** olur → asset `hazir` durumunda kalır, 7 gün sonra sweeper siler. Kabul edilebilir (kota zaten harcandı, kötüye kullanım freni bozulmuyor).
- İstemci balonu `hata` durumuna alır, mesajı gösterir, "Tekrar dene" **gizlenir** (kalıcı hata).

### 6.9 Tek seferlik — iki kez açma / iki cihazdan açma
- `UPDATE … WHERE viewed_at IS NULL RETURNING` atomik → ikinci istek **410**.
- Aynı kullanıcının ikinci cihazı da 410 alır (WhatsApp davranışı ile aynı).
- Gönderen kendi tek seferlik medyasını **görebilir** (silinene kadar) — `view` çağrısı gönderen için `viewed_at` yazmaz.

### 6.10 Diğerleri
| Durum | Davranış |
|---|---|
| Cihazda yer yok | Sıkıştırma `FileSystemException` → "Cihazda yeterli alan yok" |
| HEIC/PNG/GIF seçildi | Sessizce JPEG'e çevrilir (`CompressFormat.jpeg`) — kullanıcı görmez |
| MP4 dışı video (MOV/HEVC) | `VideoCompress` çıktısı H.264/MP4'tür; değilse sunucu 415 → "Bu video biçimi desteklenmiyor" |
| Sohbet silindi / üyelikten çıkarıldı | Mesaj POST **403** → balon `hata`, "Bu sohbete artık mesaj gönderemezsiniz" |
| Sunucu 429 (kota) | Kuyruk **duraklar** (tekrar denemez), "Çok fazla medya gönderdiniz" + 1 saat sonra otomatik devam |
| WS olayı kayboldu (hub kuyruğu dolu, `hub.go:99-101`) | Sohbet açılışında `GET /chats/{id}/messages` gerçeği getirir; ayrıca `chats_provider` 15 sn'lik yeniden bağlanmada tazeleniyor |
| `media_assets.status='silindi'` ama mesaj duruyor | `media_url` boş döner → balon `LucideIcons.imageOff` + "Medya kaldırıldı" |
| R2 ulaşılamıyor (commit'te 5xx) | **502 `depolamaya ulaşılamadı`**, istemci tekrar dener |

---

## §7 — ⚠️⚠️ BU PROJEYE ÖZEL ÇAKIŞMA RİSKLERİ (zorunlu bölüm)

Bu uygulamada aynı anda **1:1 arama / sesli oda / canlı yayın** olabilir. iOS'ta ses birimi **proses geneli tektir** (`AppDelegate.swift:32-33`: `useManualAudio=true`, `isAudioEnabled=false`) ve `flutter_webrtc` **TEK paylaşılan `videoCapturer`** tutar (`AppDelegate.swift:668, 737, 905`). Aşağıdaki dört risk somut olarak çözülmüştür.

### 7.1 🔴 KAMERA — sohbetten foto/video çekimi

**Ne olur (çözülmezse):**
- **iOS:** `UIImagePickerController` kendi `AVCaptureSession`'ını açar. `flutter_webrtc`'nin paylaşılan `videoCapturer.captureSession`'ı `AVCaptureSessionWasInterrupted` (`videoDeviceInUseByAnotherClient`) alır. Turu 50'nin kök nedeni tam olarak buydu: **iki capture oturumu birbirinin oturumunu çalar, video track odaya HİÇ ulaşmaz** (%14 arama tek taraflı video). Turu 67'de bu `_kameraKuyruguna` (`active_call_controller.dart:565`) ile **tek slotluk zincire** dizildi — ama `image_picker` o kuyruğun **tamamen dışında üçüncü bir tüketici** olur.
- **Android:** sistem kamera uygulaması kamera HAL'ini alır; `AramaServisi` FGS'i `camera` tipiyle çalışıyor olsa bile donanım geri gelmez.

> ### KARAR: **ENGELLE.**
> Ataç panelinde **Kamera satırı, `MedyaKapisi.kameraSerbest()` false ise HİÇ ÇİZİLMEZ** (gri değil — **yok**).
> ⚠️ Neden gri değil: turu 66b dersi — *"bir özelliği bayrakla kapatırken gövdeyi değiştirmek yetmez, o özelliği ÇAĞIRAN ARAYÜZ de gizlenmeli, yoksa düğme SESSİZCE BAŞKA İŞ YAPAR."*
> Kullanıcı yine de bir yoldan tetiklerse (yarış: panel açıkken arama gelirse) `_kameraAc()` gövdesinin **ilk satırı** yine kapıyı okur ve SnackBar basar: **"Görüşme sürerken kamera kullanılamaz. Galeriden seçebilirsiniz."** — çift kapı, fail-closed.
> **Galeri seçimi HER ZAMAN serbest** (PHPicker/Photo Picker kamerayı açmaz).
> ⚠️ `odaYayinMuaf: false` (varsayılan): oda/yayın turu 72/73'te duraklatılabilir hâle geldi ama duraklatma **gelen arama** için tasarlandı; bir fotoğraf için sesli odayı susturmak ürün olarak yanlış.

### 7.2 🔴 VİDEO OYNATMA — `video_player` + AVAudioSession

**Ne olur (çözülmezse):** `video_player` iOS'ta `AVPlayer` kullanır ve oynatma için `AVAudioSession` kategorisini `playback` (veya `mixWithOthers`) yapar. Aktif arama sırasında kategori **canlı VPIO biriminin altından** `playAndRecord`'dan çıkar → turu 64'ün ölçülmüş hatası: `NSOSStatusErrorDomain#561017449` = `0x21707269` = **`!pri` = InsufficientPriority**; turu 65: CallKit unhold ediyor ama `didActivate` **hiç gelmiyor**. Yani **aramanın mikrofonu ölür ve geri gelmez**.
`mixWithOthers` **çözmez** — kategori yine değişir.

> ### KARAR: **ENGELLE (oynatma).**
> Aktif arama/oda/yayın varken video balonuna dokunuş oynatıcıyı açmaz; SnackBar: **"Görüşme sürerken video oynatılamaz."**
> **Fotoğraf görüntüleme SERBEST** (ses birimine dokunmaz).
> Görüntüleyici açıkken arama gelirse: `ref.listen(activeCallProvider)` ile **oynatma durdurulur ve controller `dispose` edilir** (`AVPlayer` serbest bırakılır), ekran kapanmaz — kullanıcı fotoğraf gezmeye devam edebilir.
> ⚠️ Bu ihtiyatlı bir karardır. Gevşetme koşulu: `AVAudioSession` kategorisinin oynatma sırasında değişip değişmediği sahada ölçülür (Sentry olayı: `medya oynatma: kategori=… mod=…`), değişmiyorsa serbest bırakılır. **Ölçmeden gevşetme.**

### 7.3 🔴 VİDEO SIKIŞTIRMA — donanım kodlayıcı çakışması

**Ne olur (çözülmezse):** `VideoCompress` Android'de **MediaCodec** donanım H.264 kodlayıcısı açar. Birçok cihazda eşzamanlı donanım kodlayıcı örneği sayısı **1-2** ile sınırlıdır; LiveKit yayın yaparken ikinci bir kodlayıcı istemek `MediaCodec.CodecException` veya **yayının kodlayıcısının düşmesi** demektir. iOS'ta `AVAssetExportSession` **capture ve audio oturumuna dokunmaz** (offline export) ama CPU/termal olarak SFU ile aynı 4 çekirdeği yer ve turu 60'ta zaten "bağlantı kalitesi zayıf" uyarı şeridi var.

> ### KARAR: **KUYRUĞA AL (engelleme değil, erteleme).**
> `MedyaKapisi.kodlayiciSerbest()` false ise öğe `GidenDurum.gorusmeBekliyor` olur.
> Balonda küçük gri şerit: **"Görüşme bittiğinde gönderilecek"** (`LucideIcons.clock`).
> `MedyaKuyrugu` kurucusunda `ref.listen(activeCallProvider)` — arama/oda/yayın bitip muhafız düşünce **250 ms gecikmeyle** kuyruk devam eder.
> ⚠️ 250 ms gecikme **zorunlu**: turu 67/68'deki `leave()` yıkımı `CallSounds.durdur` + `disconnect()` await'lerinden **sonra** tamamlanıyor; hemen başlarsak kodlayıcıyı hâlâ ayakta olan yayının üstüne açarız.
> **Fotoğraf sıkıştırma bu kapıdan GEÇMEZ** — saf CPU JPEG işi, ~180 ms, donanım kodlayıcı kullanmaz. Arama sırasında da çalışır.

### 7.4 🔶 YÜKLEME BANT GENİŞLİĞİ

**Ne olur:** 8 MB'lık bir video yüklemesi hücresel şebekede WebRTC'nin BWE'sini yanıltır → turu 60'taki "bağlantın zayıf" şeridi ve gerçek kalite düşüşü.

> ### KARAR: **Fotoğraf yüklemesi arama sırasında DEVAM EDER** (≤400 KB, ~1 sn).
> **Video yüklemesi arama/oda/yayın bitene kadar BEKLETİLİR** — zaten §7.3'teki kodlayıcı kapısı onu `gorusmeBekliyor`da tuttuğu için **ek kod gerekmiyor**; aynı kapı iki riski birden kapatıyor.

### 7.5 🔶 `FLAG_SECURE` (tek seferlik) ile Android PiP çakışması

**Ne olur:** Tek seferlik görüntüleyici için `WindowManager.LayoutParams.FLAG_SECURE` set edilirse ve o sırada gelen arama kabul edilip PiP'e geçilirse **PiP yüzeyi siyah** çizilir (ekran yakalama korumasının kapsamı PiP'i de içerir).

> ### KARAR: `FLAG_SECURE` **yalnız görüntüleyici açıkken** set edilir; `dispose()` **ve** `AppLifecycleState.inactive` **ve** `activeCallProvider` bir arama bildirdiğinde **derhal temizlenir** — üç ayrı çıkış, `finally` ile.
> Kanal: mevcut **`gebzem/pip`** kanalına iki yeni `case` (`ekranKorumaAc` / `ekranKorumaKapat`).
> ⚠️⚠️ **KANAL UYUŞMAZLIĞI TUZAĞI (turu 65b):** projede iki kanal var (`gebzem/audio` ve `gebzem/pip`) ve yanlış kanala yazılan native `case` **derleme zamanı yakalanmaz**, `MissingPluginException` `catch (_)` ile yutulur → kod **hiç çalışmaz**. Dart çağrısı `PipService` üzerinden yapılacak ve native `case`in hangi handler'a yazıldığı **satır satır karşılaştırılacak**.
> iOS'ta karşılığı **YOK** (Apple engellemez) — kullanıcıya "ekran görüntüsü alınamaz" **denmeyecek**.

### 7.6 Çakışma özeti tablosu

| Eylem | Arama/oda/yayın aktifken | Gerekçe |
|---|---|---|
| Galeriden seçme | ✅ Serbest | Kamera/ses birimine dokunmaz |
| Kamerayla çekim | 🔴 **Engelli** (arayüzden kaldırılır) | iOS paylaşılan `videoCapturer` (turu 50/67) |
| Fotoğraf sıkıştırma | ✅ Serbest | Saf CPU, ~180 ms |
| Video sıkıştırma | 🟠 **Kuyruğa alınır** | Donanım kodlayıcı + termal |
| Fotoğraf yükleme | ✅ Serbest | ~400 KB |
| Video yükleme | 🟠 **Kuyruğa alınır** | Bant genişliği (§7.3 kapısıyla aynı) |
| Fotoğraf görüntüleme | ✅ Serbest | Ses birimine dokunmaz |
| Video oynatma | 🔴 **Engelli** | `AVAudioSession` kategorisi (turu 64 `!pri`) |
| Video küçük resmi üretme | ✅ Serbest | `AVAssetImageGenerator`/`MediaMetadataRetriever`, ~100 ms |
| `FLAG_SECURE` | 🟠 Arama gelince **derhal temizlenir** | PiP siyah yüzey |

---

## §8 — TEST SENARYOLARI (elle, madde madde)

### A. Temel gönderme
1. Sohbet aç → ataç → **Galeri** → 1 fotoğraf seç → altyazısız gönder. Balon anında görünmeli, ilerleme dolmalı, ~2 sn içinde tik çıkmalı.
2. Aynı akış **altyazılı**. Altyazı görselin ALTINDA, saat+tik altyazının sağ altında olmalı.
3. **5 fotoğraf** aynı anda seç → hepsi sırayla gönderilmeli, sıra bozulmamalı.
4. Ataç → **Kamera** → fotoğraf çek → gönder.
5. Ataç → **Kamera** → video çek (30 sn) → gönder.
6. Galeriden **90 sn'den uzun** video seç → "en fazla 90 saniye" uyarısı, gönder düğmesi kapalı.
7. **HD** rozetini açıp fotoğraf gönder → karşı tarafta belirgin şekilde daha net olmalı.

### B. Alma
8. Karşı cihazda balon **thumb ile anında** dolmalı (asıl inmeden önce).
9. Uygulama kapalıyken fotoğraf al → push **"Ahmet: Fotoğraf"**; altyazılıysa **"Ahmet: Fotoğraf · merhaba"**.
10. ⚠️ **Türkçe karakterli 80+ karakterlik altyazı** gönder → push metninde bozuk karakter (�) OLMAMALI (`preview[:80]` düzeltmesinin testi).
11. Sohbet listesinde satır: `LucideIcons.image` + "Fotoğraf" / `video` + "Video".
12. Video balonunda: kapak karesi + ortada play + sol altta süre + (inmemişse) sağ altta boyut.

### C. Görüntüleyici & galeri
13. Fotoğrafa dokun → tam ekran, **Hero geçişi akıcı**, pinch-zoom çalışıyor, aşağı sürükleyince kapanıyor.
14. Görüntüleyicide **sağa/sola kaydır** → sohbetteki diğer medyalar geliyor.
15. Video oynat → play/pause, sürükleme çubuğu, süre doğru.
16. **Kaydet** → cihaz galerisinde görünüyor.
17. Sohbet başlığı → Medya → 3 sütunlu ızgara, videolarda play rozeti; birine dokununca görüntüleyici açılıyor.

### D. ⚠️⚠️ ÇAKIŞMA TESTLERİ (en kritik blok)
18. **Sesli arama başlat** → aramayı küçült → sohbete gir → ataç aç → **"Kamera" satırı GÖRÜNMEMELİ**, "Galeri" görünmeli.
19. Aynı durumda **galeriden fotoğraf gönder** → gönderilmeli, **aramanın sesi bozulmamalı**.
20. **Görüntülü arama sürerken** galeriden fotoğraf gönder → **karşı taraf videoyu kaybetmemeli** (turu 50 regresyon testi).
21. **Arama sürerken galeriden VİDEO gönder** → balonda **"Görüşme bittiğinde gönderilecek"** çıkmalı, yükleme başlamamalı.
22. Aramayı bitir → **~0,5 sn içinde** aynı video kendiliğinden yüklenip gönderilmeli.
23. **Arama sürerken video balonuna dokun** → **"Görüşme sürerken video oynatılamaz"** çıkmalı, oynatıcı açılmamalı.
24. **Video oynatırken gelen arama kabul et** → oynatma durmalı, **aramanın mikrofonu çalışmalı** (karşı taraf seni duymalı — bu turu 64 `!pri` regresyon testidir).
25. **Sesli odadayken** ataç aç → Kamera **yok**; galeriden fotoğraf gönder → **odanın sesi kesilmemeli**.
26. **Canlı yayın yaparken** aynı test → yayın videosu donmamalı.
27. Sohbetten fotoğraf gönderirken **gelen arama** → arama normal çalmalı, yükleme kesintisiz bitmeli.

### E. Dayanıklılık
28. Fotoğraf gönderirken **uçak modu aç** → "Bağlantı bekleniyor"; kapat → kendiliğinden devam etmeli.
29. Video yüklenirken **uygulamayı arka plana al**, 60 sn bekle, geri dön → kaldığı yerden devam veya baştan, ama **kaybolmamalı**.
30. Video yüklenirken **uygulamayı app switcher'dan öldür** → yeniden aç → **gönderim kendiliğinden devam etmeli**.
31. Yükleme sırasında **X (iptal)** → balon kaybolmalı, karşı tarafa hiçbir şey gitmemeli.
32. **Aynı fotoğrafı ikinci kez** gönder → gözle görülür şekilde **çok daha hızlı** (yükleme atlanır) ama balon normal görünmeli.
33. Gönderim sürerken **sohbetten çık, başka sohbete gir, geri dön** → ilerleme kaybolmamalı.
34. **Depolama neredeyse dolu** cihazda video gönder → net Türkçe hata.

### F. Tek seferlik
35. Tek seferlik fotoğraf gönder → alıcıda **görsel görünmemeli**, "Tek seferlik" yazmalı.
36. Alıcı açar → görsel açılır; **geri gel, tekrar dokun** → "Bu medya zaten görüntülendi".
37. Gönderende balon **"Açıldı"** olmalı (WS `message.viewed`).
38. Açıldıktan **3 dakika sonra** medya URL'i doğrudan tarayıcıda denenirse **404** dönmeli.
39. Android'de tek seferlik açıkken **ekran görüntüsü** al → siyah çıkmalı. Sonra normal bir ekranda tekrar dene → **normal çıkmalı** (FLAG_SECURE temizliği).
40. Tek seferlik açıkken **gelen aramayı kabul et → PiP'e geç** → PiP **siyah OLMAMALI**.

### G. Güvenlik / sınırlar
41. Fotoğraf gönder → sunucu logunda/DB'de `messages.media_url` **boş** olmalı, `media_id` dolu olmalı.
42. **EXIF'li (GPS'li) bir JPEG'i** doğrudan presigned URL'e yükleyip commit et (elle curl) → **422 `konum bilgisi içeriyor`**.
43. Bir **PNG**'yi `image/jpeg` diye beyan edip yükle → **422 `içerik türü eşleşmiyor`**.
44. Beyan edilen boyuttan **farklı** bayt yükle → R2 **`BadDigest`** ya da commit'te **422**.
45. Aynı presigned URL'e **ikinci kez** PUT → **412**.
46. Başka kullanıcının `media_id`si ile mesaj göndermeyi dene → **403 `bu medya size ait değil`**.
47. 500 fotoğrafı arka arkaya göndermeyi dene → belli bir noktada **429 `çok fazla medya gönderdiniz`**.
48. `https://medya.gebzem.app/...` yanıt başlıklarında **`x-content-type-options: nosniff`** ve **`content-security-policy`** olmalı (`curl -I`).
49. `https://api.gebzem.app/` üzerinden hiçbir medya servis edilmemeli.
50. Sentry'de **hiçbir olayda `X-Amz-Signature` geçmemeli** (r2Dio testinin doğrulaması).

### H. Silme / 5651
51. Kendi fotoğraf mesajını sil → iki cihazda da **"Bu mesaj silindi"**.
52. Silinen medyanın URL'i **404** dönmeli.
53. Admin: aynı `md5_hex`e sahip tüm kopyaları tek hamlede kaldırma çalışmalı (4 saat yükümlülüğü).

---

## §9 — AÇIK BIRAKTIKLARIM (dürüst notlar)

1. **`video_compress` 18 aydır güncellenmemiş.** API yüzeyi küçük olduğu için kabul edildi. Bozulursa yedek plan: iOS `AVAssetExportSession` + Android `androidx.media3.transformer` ile ~200 satırlık kendi platform kanalımız.
2. **`VideoQuality.Res1280x720Quality` enum adı** paketin kurulu sürümünde teyit edilecek; yoksa `MediumQuality`.
3. **`ImageSource.camera` + `maxDuration`** galeri seçimlerinde süre kırpması **garanti değil** — asıl koruma istemci süre kapısı + sunucu 413.
4. **R2 `CopyObject`** davranışı bizim boyutlarda sahada 1 kez doğrulanacak (§2.3 yedek plan var).
5. **MP4 `moov` konumu**: `video_compress` `shouldOptimizeForNetworkUse` bayrağını dışa açmıyor; `moov` dosya sonundaysa uzaktan oynatma ekstra bir Range isteği yapar (çalışır, ~200 ms gecikme). Ölçülecek.
6. **APK/IPA boyut artışı TAHMİN** (+2,5–4,5 MB / +2–3 MB); `--analyze-size` ile ölçülecek.
7. **Maliyet:** R2'de 90 günlük saklamayla orta senaryo ≈ **$60-70/ay**, egress **$0**. Cloudflare Images ($450/ay dönüşüm) ve Stream (sohbet videosu için 12. ayda ~$4.000/ay) **bilinçli olarak elendi**.
8. **PhotoDNA / CSAM taraması bu tasarımın kapsamında DEĞİL** ama medya yayına çıkmadan **önce** gerekir; PhotoDNA Cloud Service başvurusunun vetting süresi bilinmiyor → **şimdi başlatılmalı**.
9. **BTK yer sağlayıcı bildirimi, KVKK aydınlatma metni, topluluk kuralları, 7/24 tebligat kanalı** — hukukçu teyidiyle, yayın öncesi. Bu tasarım teknik tarafı (silme ucu + admin kaldırma + hash-bazlı toplu kaldırma) hazırlıyor.
10. **Faz 2 (yayın öncesi):** `medya.gebzem.app` önüne Worker HMAC kapısı. Tasarım buna göre yapıldı — DB'de `object_key` tutulduğu için değişiklik **tek bir sunucu fonksiyonuyla** sınırlı, istemci kodu etkilenmez.