# KONUM (anlık + canlı) ve KİŞİ KARTI — Mühendislik Tasarımı

Tüm kod iddiaları dosyadan okunarak doğrulandı; satır numaraları verildi. Harici iddialar (fiyat/kota/platform kuralı) için kaynak URL'leri en altta.

---

## 0. KARAR ÖZETİ

| Konu | Karar | Neden |
|---|---|---|
| Harita sağlayıcı | **Geoapify** (statik önizleme + raster tile) | Ücretsiz katmanda **Static Maps DAHİL** ve **üretilen görselleri saklama/önbellekleme İZİNLİ**. MapTiler ve Stadia'nın ücretsiz katmanlarında Static Maps **YOK**. |
| Balondaki önizleme | **Sunucu üretir → R2'ye yazar → istemci R2/CDN'den çeker** | Koordinat başına Geoapify'a **1 kez** gidilir; sonraki tüm görüntülemeler $0 (R2 egress ücretsiz). Cihazın IP'si Geoapify'a **hiç gitmez** (KVKK kazancı). |
| Balonda interaktif harita | **YOK** (statik PNG) | Her balon için tile yüklemek maliyeti patlatır. |
| Harita seçme ekranı | `flutter_map` + tile'lar **kendi API'mizden** (`/maps/tile/...`, R2'de kalıcı önbellek, sıcak tile'da 302) | API anahtarı uygulamaya gömülmez; ikinci kez bakılan her tile $0. |
| Canlı konum taşıması | **Gönderim REST (POST), alım WS + 10 sn yoklama** | ⚠️ Proje WS'i her arka plana geçişte **bilerek kapatıyor** (`ws.dart:108-121`, turu 33). WS'e dayanan canlı konum yapısal olarak çalışmaz. |
| Koordinat saklama | **Sadece Redis, TTL'li.** Postgres'te **koordinat YOK** | KVKK: iz (trail) tutmuyoruz. Postgres yalnız "kim, ne zaman, ne kadar süre" (5651 trafik logu). |
| Kişi kartı kaynağı | **Uygulama içi kullanıcı arama** (`/users/search`) | Rehber yükleme YOK → KVKK riski sıfır, `flutter_contacts` paketi gerekmez. |
| Kamera / mikrofon | **HİÇ KULLANILMIYOR** | Bölüm 7'de kanıtlandı. Ama üç başka çakışma var, orada çözüldü. |
| Yeni paket | `geolocator ^14.0.3`, `flutter_map ^8.3.1`, `latlong2`, `url_launcher` | 4 paket. `google_maps_flutter` ELENDİ (SKU faturası + `cloudMapId` yasağı). |

---

## 1. HARİTA MALİYETİ — KARAR VE KANIT

### 1.1 Elenenler

| Seçenek | Neden elendi |
|---|---|
| **MapTiler** | Ücretsiz plan: 5.000 map session + 100.000 API isteği/ay — ama **Static Maps API ücretsiz plana DAHİL DEĞİL**, Flex ($30/ay) gerekiyor. |
| **Stadia Maps** | Ücretsiz plan 200.000 kredi/ay ama **Static Maps ücretsiz katmanda yok**; Starter'dan ($20/ay) itibaren ve **istek başına 20 kredi**. Önbelleklenebilir statik harita **2.000 kredi/istek**. |
| **google_maps_flutter** | CLAUDE.md'de `cloudMapId` yasak; ayrıca Google Mart 2025'te evrensel $200 kredisini kaldırdı, SKU başına ücretsiz eşik 10.000/ay. 50K kullanıcıda günlerce sürmez. *(Bu Google fiyat bilgisi kardeş keşif ajanından geliyor, ben doğrudan doğrulamadım.)* |
| **OSM Foundation tile'ları** | Proje kuralı: YASAK (kullanım politikası). |
| **Tile'ları/önizlemeyi cx33'ten proxy'lemek (bytes olarak)** | LiveKit aynı makinede; bant genişliği değil **gecikme rekabeti** sorunu. Bytes R2'den akacak, cx33 yalnız 302 üretecek. |

### 1.2 Seçilen: Geoapify

Doğrulanmış rakamlar:
- Ücretsiz plan: **3.000 kredi/gün** (~90.000/ay), kredi kartı istemiyor.
- **Statik harita maliyeti = 1 (istek) + tile_sayısı/4 + marker_sayısı** kredi. Belgede örnek: 800×600 + 6 marker = 9 kredi.
- **Tile maliyeti = 0,25 kredi/tile** (1 kredi = 4 tile).
- Maksimum boyut 4096×4096.
- **Saklama/önbellekleme İZİNLİ**: Geoapify kendi sayfasında *"you can freely cache, store, and redistribute the maps at no extra cost"* diyor. OSM verisi kullandığı için mümkün.
- Ücretsiz planda **atıf zorunlu**: "Powered by Geoapify" + OpenStreetMap + OpenMapTiles. (Ücretli planlarda white-label; OSM atfı yine kalır.)
- İlk ücretli basamak: API 10 = **$59/ay**, 10.000 kredi/gün.

### 1.3 Bizim maliyet hesabımız

**Statik önizleme parametreleri (karar):** `width=400&height=225&scaleFactor=2&zoom=16` + 1 marker.
Render edilen alan 800×450 px → 4×2 = 8 tile → **1 + 8/4 + 1 = 4 kredi**.
⚠️ `scaleFactor`ın tile sayımını gerçekten 2× artırıp artırmadığını belgede bulamadım — **TAHMİN**. İlk hafta Geoapify panosundan ölçülüp buraya yazılacak.

| Kalem | Hesap |
|---|---|
| Ücretsiz katmanda üretilebilecek **YENİ** önizleme | 3.000 / 4 = **750 yeni koordinat/gün** |
| Aynı koordinatın 2. gönderimi | **0 kredi** (R2'de var) |
| Aynı önizlemenin N kişi tarafından görüntülenmesi | **0 kredi, 0 egress ücreti** (R2 + CDN) |
| Ücretsiz katmanda soğuk tile | 3.000 / 0,25 = **12.000 soğuk tile/gün** |
| Isınmış tile | **0 kredi** — R2'den CDN ile |
| R2 depolama | önizleme ~45 KB, tile ~25 KB. 100.000 benzersiz nesne ≈ 3 GB ≈ **$0,05/ay** |

**Sonuç:** prototipte ve ilk büyümede **$0**. Kota dolarsa API 10 ($59/ay) tek adım. Türkiye küçük bir coğrafya; kullanıcılar aynı ilçelerde gezindiği için tile önbelleği haftalar içinde doyar ve kredi tüketimi düşmeye devam eder.

### 1.4 Anahtar (key) uzayı

```
harita/onizleme/<sha256(MAPS_KEY_SALT|stil|z|lat5|lng5)[:40]>.png
harita/kare/<stil>/<z>/<x>/<y>.png
```

⚠️ **Önizleme anahtarı TUZLU HASH — düz koordinat DEĞİL.** Düz koordinat yazsaydık anahtar tahmin edilebilir olurdu ve biri "bu adresi daha önce biri paylaşmış mı?" diye yoklayabilirdi (varlık sızıntısı). Tile anahtarları düz kalabilir: tile jenerik OSM verisidir, kişisel içerik taşımaz.

⚠️ **YAPMA:** anahtara `user_id` / `chat_id` / `message_id` koyma. Önizleme birden çok mesaj arasında paylaşılır ve kimseye ait değildir.

### 1.5 Atıf (compliance)

- **Tam ekran harita ekranlarında (seçici + detay + canlı):** sağ alt köşede küçük satır → `© Geoapify · © OpenStreetMap katkıcıları · © OpenMapTiles`, dokununca kaynak linkleri.
- **Balondaki küçük önizlemede:** yer yok, atıf gösterilmiyor (WhatsApp da göstermiyor). Bu bir **yorum**, hukuki garanti değil — ücretli plana geçilince Geoapify ibaresi zaten kalkar, OSM ibaresi kalır. Hukukçu teyidine bırakılıyor.

---

## 2. KULLANICI AKIŞLARI (adım adım)

### 2.1 Anlık konum gönderme

1. Sohbet ekranı, giriş çubuğunun solundaki **ataç** (`LucideIcons.paperclip`) → alttan panel.
2. Panel: **Konum** (`LucideIcons.mapPin`) · **Kişi** (`LucideIcons.userRound`). *(Medya fazı buraya Fotoğraf/Video/Dosya/Ses ekleyecek.)*
3. "Konum" → ikinci panel:
   - `LucideIcons.locateFixed` **Mevcut konumu gönder**
   - `LucideIcons.map` **Haritadan seç**
   - `LucideIcons.radio` **Canlı konumu paylaş**
4. "Mevcut konumu gönder":
   - `Geolocator.isLocationServiceEnabled()` → kapalıysa "Konum servisi kapalı" + **Ayarları aç**.
   - `Geolocator.checkPermission()` → `denied` ise `requestPermission()`; `deniedForever` ise diyalog + `Geolocator.openAppSettings()`.
   - `getCurrentPosition(LocationAccuracy.high, timeLimit: 12sn)`; zaman aşımında `getLastKnownPosition()` yedeği, o da yoksa hata.
   - `POST /chats/{chatID}/location {lat,lng,acc}` → 201.
5. Sunucu: üyelik + engel kontrolü → koordinat doğrulama → önizleme (R2'de yoksa Geoapify'dan üret, R2'ye PUT) → `messages` INSERT (`type='location'`, `content='40.792140,29.445310'`, `media_url=<R2 URL>`) → `message.new` WS + push ("Konum").
6. Alıcı: WS ile balon anında düşer; PNG R2/CDN'den gelir. Dokununca **konum detay ekranı** (büyük `flutter_map`, marker, **Yol tarifi al**, **Kopyala**).

**Dokunuş sayısı:** ataç → Konum → Mevcut konumu gönder = **3 dokunuş.**

### 2.2 Haritadan seçerek gönderme

3'teki "Haritadan seç" → `HaritaSecimEkrani`:
- Merkez = mevcut konum (izin varsa), zoom 16.
- Ekranın **tam ortasında sabit bir artı** (`LucideIcons.crosshair`); harita altta kayar (WhatsApp/Uber deseni — marker sürüklemekten çok daha ucuz ve doğru).
- Sağ altta `LucideIcons.locateFixed` "beni bul".
- Altta tam genişlikte **"Bu konumu gönder"**; üstünde seçilen koordinat 5 haneli yazar.
- Gönder → 2.1'in 4-6. adımlarının aynısı.

### 2.3 Canlı konum paylaşma

1. "Canlı konumu paylaş" → süre paneli: **15 dakika · 1 saat · 8 saat** (`LucideIcons.timer`).
2. İzin + servis kontrolü (2.1/4 ile aynı). ⚠️ İzin diyaloğu **yalnız ön planda ve başka bir diyalog zincirinin arkasında olmadan** açılır (turu 56 dersi, bölüm 7-D).
3. `POST /chats/{chatID}/live-location {duration_sec, lat, lng, acc}`.
4. Sunucu: `live_locations` satırı (`expires_at = now()+duration`) + başlangıç noktasının önizlemesi + `messages` satırı (`type='location'`, `live_location_id=<uuid>`) → `message.new`.
5. İstemcide `CanliKonumServisi` (uygulama ömrü boyu yaşayan Riverpod singleton):
   - `Geolocator.getPositionStream(...)` **TEK** abonelik açar (birden çok sohbete paylaşım varsa yine tek akış).
   - Android: `AndroidSettings.foregroundNotificationConfig` → geolocator'ın kendi ön plan servisi (`GeolocatorLocationService`, `foregroundServiceType="location"`) başlar.
   - iOS: `AppleSettings(allowBackgroundLocationUpdates: true, showBackgroundLocationIndicator: true)` → mavi şerit.
   - Her konumda, **istemci tarafı kısıt**: hareket halinde en fazla **15 sn'de bir**, duruyorsa **60 sn'de bir** kalp atışı → `POST /live-locations/{id}/ping`.
6. Sunucu: Redis'e son konum (TTL = kalan süre), `live_locations.last_ping_at` güncel, WS `location.live` → sohbetin diğer üyeleri.
7. Alıcı: balon içindeki önizlemenin üstünde **canlı rozet** + "Güncellendi · 12 sn önce" + geri sayım. Dokununca **CanliKonumEkrani** (tam ekran `flutter_map`, kişinin avatarı marker olarak hareket eder).
8. Gönderen balonda **"Paylaşımı durdur"** görür; ayrıca sohbet listesinin üstünde uygulama geneli bir şerit: *"Canlı konum paylaşıyorsun · 42 dk"*.
9. Süre dolunca sweeper `ended_at` yazar + `location.live.ended` yayınlar → balon soluklaşır, "Canlı konum sona erdi".

### 2.4 Kişi kartı gönderme

1. Ataç → **Kişi** → `KisiSecEkrani` (`user_search_screen.dart` deseninin birebir kopyası: `GET /users/search?q=`, çoklu seçim YOK — v1 tek kişi).
2. Seçim → `POST /chats/{chatID}/contact {user_id}`.
3. Sunucu: hedef `verified=true` mi, gönderenle iki yönlü engel var mı → `messages` INSERT (`type='contact'`, `contact_user_id=<uuid>`, `content=''`).
4. `message.new` payload'ında `contact:{id,name,username,avatar_url}` **sunucu tarafından zenginleştirilmiş** gelir (istemci ayrıca istek atmaz).
5. Balon: avatar + ad + `@kullanıcıadı` + tam genişlikte **"Mesaj gönder"** → `POST /chats/direct` → `context.push('/chat/:id')`.

⚠️ **Rehber okunmuyor.** `flutter_contacts` YOK, `READ_CONTACTS` izni YOK. KVKK'da en riskli kalem olan rehber yükleme bu tasarımda **yapısal olarak imkânsız**.

---

## 3. BACKEND — UÇLAR VE DEĞİŞİKLİKLER

### 3.1 Yeni uçlar

Hepsi `main.go:145-210` korumalı gruba eklenir (`/maps/tile` HARİÇ — aşağıda).

#### `POST /chats/{chatID}/location`
```jsonc
// istek
{ "lat": 40.792140, "lng": 29.445310, "acc": 12.5 }
// 201
{ "id": 4211, "created_at": "2026-08-07T09:12:04Z",
  "media_url": "https://medya.gebzem.app/harita/onizleme/9f3c...a13.png" }
```
Hatalar: `400 geçersiz konum` (lat/lng aralık dışı, NaN/Inf) · `403 bu sohbetin üyesi değilsiniz` · `403 bu kullanıcıya mesaj gönderilemiyor` (engel) · `429 çok hızlı gönderiyorsunuz` (Redis 3 sn) · `500 mesaj kaydedilemedi`.

⚠️ **`media_url` istemciden ALINMAZ.** Bu uç var olduğu için `media_url`'i sunucu üretir. Mevcut `SendMessage` `req.MediaURL`'i doğrulamadan INSERT ediyor (`chat/handler.go:128` + `:169-171`) — bu bugün açık bir SSRF/oltalama yüzeyi.

#### `POST /chats/{chatID}/contact`
```jsonc
{ "user_id": "uuid" }
// 201
{ "id": 4212, "created_at": "...",
  "contact": { "id":"uuid", "name":"Ahmet Yılmaz", "username":"ahmet", "avatar_url":"" } }
```
Hatalar: `400 geçersiz istek` · `404 kullanıcı bulunamadı` (yok veya `verified=false`) · `403` (üyelik/engel) · `429`.

#### `POST /chats/{chatID}/live-location`
```jsonc
{ "duration_sec": 3600, "lat": 40.79, "lng": 29.44, "acc": 8.0 }
// 201
{ "share_id":"uuid", "message_id":4213, "expires_at":"2026-08-07T10:12:00Z",
  "media_url":"https://medya.gebzem.app/harita/onizleme/...png" }
```
- `duration_sec` yalnız **900 / 3600 / 28800** kabul edilir; başkası → `400 geçersiz süre`.
- Aynı (chat_id, user_id) için aktif paylaşım varsa **yenisi açılmaz**, mevcut olanın `expires_at`'i `max(mevcut, now+duration)` yapılır ve **aynı `share_id` + aynı `message_id`** döner (WhatsApp davranışı). Kısmi UNIQUE index bunu garanti eder.

#### `POST /live-locations/{id}/ping`
```jsonc
{ "lat":40.79, "lng":29.44, "acc":8.0, "hdg":91.4, "spd":4.2, "batt":73 }
// 204 No Content  (gövde YOK — en sık çağrılan uç, bant tasarrufu)
```
- Yetki: `live_locations.user_id == token sahibi` **ve** `ended_at IS NULL` **ve** `expires_at > now()`.
- `403` → istemci paylaşımı yerelde de kapatır.
- `410 Gone` → paylaşım sunucuda bitmiş; istemci akışı kapatır. *(Ayrı kod, çünkü 403'ten farklı davranış gerekiyor: kullanıcıya hata gösterme, sessizce kapat.)*
- **Sunucu tarafı kısıt:** `SETNX konum:ping:{share_id} 5s` — 5 sn içindeki fazla ping'e de `204` döner ama işlenmez (istemciyi hataya sokmamak için 429 DEĞİL).

#### `POST /live-locations/{id}/stop` → `200 {"message":"ok"}`
Sahibi çağırır. `ended_at=now()`, Redis anahtarı DEL, WS `location.live.ended {reason:"stopped"}`.

#### `GET /chats/{chatID}/live-locations`
```jsonc
[{ "share_id":"uuid", "user_id":"uuid", "name":"Ahmet", "avatar_url":"",
   "started_at":"...", "expires_at":"...",
   "last": { "lat":40.79,"lng":29.44,"acc":8.0,"hdg":91.4,"spd":4.2,"batt":73,
             "at":"2026-08-07T09:15:02Z" } }]
```
`last` **null** olabilir (hiç ping gelmemiş veya Redis TTL'i dolmuş = gönderen 8 saattir kapalı). İstemci bunu "Bağlantı yok" olarak çizer.
⚠️ Engel filtresi **okuma yolunda**: sorgu `AND NOT EXISTS(SELECT 1 FROM blocks ...)` ile beni engelleyenin/engellediğimin paylaşımını döndürmez.

#### `GET /live-locations/mine`
```jsonc
[{ "share_id":"uuid", "chat_id":"uuid", "chat_title":"Ahmet", "expires_at":"..." }]
```
Uygulama açılışında ve her `resumed`'da çağrılır → "uygulama öldürüldü, paylaşım hâlâ açık" durumunu onarır (bölüm 6.3).

#### `GET /maps/session` (korumalı)
```jsonc
{ "tile_url": "https://api.gebzem.app/maps/tile/{z}/{x}/{y}.png?t=<token>",
  "expires_at": "2026-08-07T11:00:00Z",
  "attribution": "© Geoapify · © OpenStreetMap katkıcıları · © OpenMapTiles" }
```

#### `GET /maps/tile/{z}/{x}/{y}.png?t=<token>` — ⚠️ **auth middleware DIŞINDA**
`main.go:133`'teki `/livekit/webhook` ile aynı gerekçe: kimlik doğrulama **Authorization başlığıyla değil**, sorgu dizesindeki kısa ömürlü HMAC ile yapılır.

⚠️⚠️ **BU BİR TASARIM ZORUNLULUĞU, TERCİH DEĞİL.** Uç, sıcak tile'da **302** ile `medya.gebzem.app`e yönlendirir. Dart'ın HTTP istemcisi yönlendirmede istek başlıklarını **taşır**; `Authorization: Bearer <JWT>` R2'ye giderse (a) JWT'miz üçüncü tarafa sızar, (b) R2 imzalı istek sanıp reddeder. Bu, keşif raporundaki *"presigned URL'e Authorization GÖNDERME"* tuzağının birebir aynısıdır.
- Token = `base64url(HMAC-SHA256(JWT_SECRET, userID + "|" + exp))[:32] + "." + exp`, ömür 2 saat.
- Akış: Redis'te `harita:sicak:{stil}/{z}/{x}/{y}` var mı → **302** R2'ye. Yoksa Geoapify'dan çek → R2'ye PUT → Redis'e işaretle → **302**.
- Kısıt: kullanıcı başına `SETNX harita:tilelimit:{uid}:{dakika}` + `INCR` ile **60 soğuk tile/dakika**; aşarsa `429`.
- `z` **4-18** dışında → `400`. `x`,`y` `< 2^z` değilse → `400`.

### 3.2 Mevcut dosyalarda değişecekler

| Dosya:satır | Değişiklik | Not |
|---|---|---|
| `chat/handler.go:152-157` | Beyaz listeden **`"location"` ÇIKARILIR** → `case "text", "image", "video", "audio":` | Konum artık yalnız kendi ucundan gelir. Bugün hiçbir istemci `type=location` göndermiyor, kırılma yok. ⚠️ `"contact"` bu listeye **HİÇ EKLENMEZ**. ⚠️ `'system'` de eklenmez (turu 59b). |
| `chat/handler.go:234-256` | SELECT'e `contact_user_id`, `live_location_id` + `LEFT JOIN users cu` + `LEFT JOIN live_locations ll`; `msg` struct'ına `Contact *contactResp` ve `Live *liveResp` alanları | ⚠️ pgx konuma göre tarar — `rows.Scan` sırası SELECT ile birebir olmalı (`ListChats`'teki `:377` uyarısıyla aynı tuzak). |
| `chat/handler.go:326-349` | `ListChats` LATERAL'ine `lm.live_location_id IS NOT NULL AS last_live` | Sohbet listesinde "Canlı konum" yazabilmek için. `chatRow`'a (`:356-373`) `LastLive bool` eklenir, Scan sırasına **sona** konur. |
| `chat/handler.go:197-206` | Push önizlemesine `case "contact": preview = "Kişi"` eklenir; `"location"` dalı canlıysa `"Canlı konum"` | `location` metni zaten var. |
| `chat/handler.go:207-209` | **HATA DÜZELTMESİ:** `preview[:80]` bayt keser, Türkçe karakteri ortadan böler → `[]rune(preview)[:80]` | Konum işinden bağımsız ama aynı fonksiyona dokunuyoruz, aynı turda düzeltilmeli. |
| `chat/handler.go` (yeni dosyalar) | `konum.go`, `kisi.go` — yeni uçlar. `chatMemberIDs` (`:409-431`) ve `h.hub.Publish` aynen kullanılır. | |
| `chat/handler.go:18-26` | `Handler`'a `rdb *redis.Client` ve `maps *maps.Client` alanları | |
| `cmd/api/main.go:76` | `chat.NewHandler(db, hub, pushSender, rdb, mapsClient)` | |
| `cmd/api/main.go:145-210` | 7 yeni korumalı rota | |
| `cmd/api/main.go:133` civarı | `r.Get("/maps/tile/{z}/{x}/{y}.png", mapsH.Tile)` — **auth grubunun DIŞINA** | |
| `cmd/api/main.go:81/88/93` yanına | `chatH.StartLiveLocationSweeper(ctx)` | Mevcut sweeper deseniyle birebir. |
| `config/config.go:20-38` | `GeoapifyKey`, `MapStyle` (vars. `osm-bright`), `MapsKeySalt`, `R2Endpoint`, `R2Bucket`, `R2AccessKey`, `R2Secret`, `MediaBaseURL` | ⚠️ Hepsi `.env`den; **`backend/.env` git'e girmez.** Anahtar yoksa `MapsEnabled=false` → önizleme üretilmez, uçlar çalışmaya devam eder (balon nötr karta düşer). "Bayrakla kapat" doktrini. |
| **yeni** `internal/maps/` | `client.go` (Geoapify statik harita + tile), `r2.go` (SigV4 PUT/HEAD — `scratchpad/r2put.js:32-96` algoritmasının Go karşılığı, `crypto/hmac`+`crypto/sha256`, **go.mod'a tek satır eklenmez**), `handler.go` (`Session`, `Tile`) | Medya fazı bu paketi aynen devralır. |

### 3.3 Hız sınırları (Redis, mevcut desen)

`streams/handler.go:446`'daki `SetNX` deseninin aynısı:

| Anahtar | Süre | Aşımda |
|---|---|---|
| `konum:msg:{uid}` | 3 sn | `429 çok hızlı gönderiyorsunuz` |
| `kisi:msg:{uid}` | 3 sn | `429` |
| `konum:ping:{share_id}` | 5 sn | `204` (sessiz yut) |
| `harita:tilelimit:{uid}:{dakika}` | 60 sn / 60 adet | `429` |

⚠️ Bugün `SendMessage`'da **hiçbir hız sınırı yok** (`main.go:97-102` middleware zincirinde de yok). Konum uçları bunu miras almasın diye kendi sınırlarıyla doğuyor.

---

## 4. VERİTABANI — MIGRATION 014

Son migration `013_call_hold.sql`. Yeni dosya: `backend/internal/database/migrations/014_konum_kisi.sql`.

⚠️ **Tamamen additive**: yeni tablo + 2 nullable sütun + CHECK'in GENİŞLETİLMESİ. Var olan hiçbir sütun/tip/veri değişmiyor, hiçbir satır güncellenmiyor.

```sql
-- 014 — KONUM (anlik + canli) ve KISI KARTI
--
-- TASARIM KARARLARI (degistirmeden once oku):
--  1) ANLIK KONUM icin YENI SUTUN YOK. 001_init.sql:56 zaten
--     "content: metin ya da konum lat,lng" diyor; o sozlesme AYNEN kullaniliyor:
--     content = "40.792140,29.445310" (6 hane, virgul ayracli, bosluksuz)
--     media_url = sunucunun urettigi R2 onizleme adresi (ISTEMCIDEN GELMEZ)
--  2) KOORDINAT IZI POSTGRES'E YAZILMAZ. Canli konumun anlik koordinatlari
--     YALNIZ Redis'te, TTL'li durur (KVKK: gereksiz veri saklamama).
--     Bu tablo yalniz "kim, hangi sohbette, ne zaman, ne kadar sure" tutar
--     (5651 trafik logu icin gerekli olan da tam budur).
--  3) live_locations'ta message_id YOK — bilincli. Mesaj -> paylasim yonu
--     yeterli; ters yon hicbir sorguda gerekmiyor ve iki tabloyu birbirine
--     kilitleyen zincirleme FK'dan kaciniliyor.

CREATE TABLE IF NOT EXISTS live_locations (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id      UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ NOT NULL,
    ended_at     TIMESTAMPTZ,                       -- durduruldu/suresi doldu
    last_ping_at TIMESTAMPTZ,
    created_ip   TEXT NOT NULL DEFAULT ''           -- 5651: trafik bilgisi
);

-- Sweeper'in her 30sn'de tarayacagi sorgu: WHERE ended_at IS NULL AND expires_at < now()
CREATE INDEX IF NOT EXISTS idx_live_loc_acik
    ON live_locations (expires_at) WHERE ended_at IS NULL;

-- Sohbet ekraninin "bu sohbette kim canli paylasiyor" sorgusu
CREATE INDEX IF NOT EXISTS idx_live_loc_sohbet
    ON live_locations (chat_id) WHERE ended_at IS NULL;

-- ⚠️ AYNI KISI AYNI SOHBETTE IKI AKTIF PAYLASIM ACAMAZ.
-- Bu index olmazsa kullanici "8 saat" secip sonra "15 dk" secince IKI paylasim
-- olusur; birini durdurmak digerini KAPATMAZ ve kullanici kapattigini SANIR
-- (gizlilik hatasi). Sunucu ikinci istegi UPDATE'e cevirir.
CREATE UNIQUE INDEX IF NOT EXISTS uq_live_loc_tek_aktif
    ON live_locations (chat_id, user_id) WHERE ended_at IS NULL;

-- messages -> canli paylasim (NULL ise anlik konum)
ALTER TABLE messages ADD COLUMN IF NOT EXISTS live_location_id UUID
    REFERENCES live_locations(id) ON DELETE SET NULL;

-- messages -> kisi karti hedefi.
-- ⚠️ NEDEN AYRI SUTUN, NEDEN content'e UUID YAZMIYORUZ:
-- content TEXT; oradan UUID'ye cast eden bir JOIN, plan sirasina gore
-- 'text' satirlarinda da degerlendirilip "invalid input syntax for type uuid"
-- ile PATLAYABILIR. Gercek sutun + gercek FK = yapisal olarak imkansiz.
-- ⚠️ ON DELETE SET NULL: hedef kullanici silinirse balon "Kişi (silinmiş)" olur,
-- mesaj SILINMEZ (sohbet gecmisi bozulmasin).
ALTER TABLE messages ADD COLUMN IF NOT EXISTS contact_user_id UUID
    REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_messages_canli
    ON messages (live_location_id) WHERE live_location_id IS NOT NULL;

-- type CHECK'ine 'contact' eklenir.
-- ⚠️ Kisitin ADI varsayilmaz: pg_constraint'ten BULUNUP dusurulur. Postgres
-- inline CHECK'e 'messages_type_check' adini verir ama bu GARANTI DEGIL;
-- yanlis ada guvenip DROP IF EXISTS yazarsak drop SESSIZCE hicbir sey yapmaz,
-- ADD ise "already exists"le patlar ve migration YARIM kalir.
-- ⚠️ NOT VALID: yeni kume eskinin USTKUMESI oldugu icin mevcut satirlarin
-- taranmasina gerek yok; tam tablo kilidi suresi milisaniyeye iner.
DO $$
DECLARE k text;
BEGIN
    SELECT conname INTO k FROM pg_constraint
     WHERE conrelid = 'messages'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%type%IN%text%image%';
    IF k IS NOT NULL THEN
        EXECUTE format('ALTER TABLE messages DROP CONSTRAINT %I', k);
    END IF;
END $$;

ALTER TABLE messages ADD CONSTRAINT messages_type_check
    CHECK (type IN ('text','image','video','audio','location','contact','system'))
    NOT VALID;
```

⚠️ **Dağıtım kuralı:** bu migration `database.Migrate` ile API açılışında otomatik uygulanır (`database.go`). Yani **backend deploy = şema değişikliği**. CLAUDE.md "şema + deploy aynı turda riskli" diyor → bu tur **yalnız migration + backend deploy** yapılıp `\d messages` ile canlı DB'de doğrulanmalı, istemci build'i **bir sonraki tura** bırakılmalı. Yeni sütunlar nullable ve yeni uçlar eski istemci tarafından çağrılmadığı için bu ara durum **tamamen güvenli**.

---

## 5. WEBSOCKET SÖZLEŞMESİ

`hub.go:30-36`'daki `Event` yapısı **değişmiyor**. `hub.go`'ya tek satır dokunulmuyor.

### 5.1 Genişleyen: `message.new`

Konum mesajı:
```json
{ "type":"message.new", "chat_id":"...", "to":["..."],
  "payload":{ "id":4211,"chat_id":"...","sender_id":"...","type":"location",
    "content":"40.792140,29.445310",
    "media_url":"https://medya.gebzem.app/harita/onizleme/9f3c...a13.png",
    "reply_to_id":null,"created_at":"2026-08-07T09:12:04Z",
    "live":{"id":"c1a...","expires_at":"2026-08-07T10:12:00Z","ended_at":null} } }
```
`live` alanı **yalnız canlı paylaşımda** vardır; anlık konumda hiç gönderilmez.

Kişi kartı:
```json
{ "payload":{ "...", "type":"contact", "content":"", "media_url":"",
  "contact":{"id":"...","name":"Ahmet Yılmaz","username":"ahmet","avatar_url":""} } }
```

### 5.2 Yeni: `location.live`

```json
{ "type":"location.live", "chat_id":"...", "to":["diger-uyeler"],
  "payload":{ "share_id":"c1a...","user_id":"...",
    "lat":40.79218,"lng":29.44603,"acc":8.4,"hdg":91.4,"spd":4.2,"batt":73,
    "at":"2026-08-07T09:15:02Z","expires_at":"2026-08-07T10:12:00Z" } }
```
⚠️ **DB'ye YAZILMAZ.** Kaybolursa alıcı `GET /chats/{id}/live-locations` yoklamasıyla kendini onarır — turu 61'de `call.held` için kurulan **`peer_held` uzlaştırma deseninin birebir aynısı**. Bu tasarım o dersin *önden* uygulanmasıdır: kaybolabilir olay + sunucu durumu + periyodik yoklama.

### 5.3 Yeni: `location.live.ended`

```json
{ "type":"location.live.ended", "chat_id":"...", "to":["tum-uyeler-dahil-gonderen"],
  "payload":{ "share_id":"c1a...","user_id":"...","reason":"stopped" } }
```
`reason`: `stopped` (kullanıcı durdurdu) · `expired` (sweeper) · `revoked` (üyelik/engel nedeniyle sunucu kapattı).
⚠️ `To` listesine **gönderenin kendisi de** eklenir (`chatMemberIDs` göndereni çıkarır — `handler.go:421-425`). Neden: kullanıcı ikinci cihazından durdurduğunda birinci cihazın da GPS akışını kapatması gerekir. Bu, `message.new` için **bilerek yapılmayan** bir şey; burada gerekli.

---

## 6. FLUTTER

### 6.1 pubspec.yaml — eklenecekler

```yaml
  # ---- KONUM (anlik + canli) ----
  # ⚠️ permission_handler ile AYNI yayinci (Baseflow) -> izin akisi tutarli.
  # ⚠️ Izin icin permission_handler DEGIL geolocator'in kendi API'si kullanilir:
  #    yalniz o, "izin var ama GPS KAPALI" durumunu ayirt eder
  #    (isLocationServiceEnabled). Ayni izni iki paketten arka arkaya ISTEME
  #    (turu 56: zincirlenen izin diyaloglari Future'i ASILI birakti).
  # ⚠️ Android compileSdk >= 35 ister; Flutter 3.44 varsayilani karsiliyor, build'de dogrula.
  geolocator: ^14.0.3

  # Harita: %100 SAF DART, native kod YOK (APK artisi ~0).
  # ⚠️ google_maps_flutter KULLANILMADI: cloudMapId yasak (CLAUDE.md) + SKU faturasi.
  # ⚠️ Tile'lar OSMF'den DEGIL, KENDI API'mizden (Geoapify -> R2 onbellek) gelir.
  flutter_map: ^8.3.1
  latlong2: ^0.9.1

  # "Yol tarifi al" -> sistem harita uygulamasi (geo: / maps.apple.com)
  url_launcher: ^6.3.1
```
⚠️ `latlong2` ve `url_launcher` sürümleri **derleme öncesi pub.dev'den doğrulanacak** — bunları doğrudan doğrulamadım. `geolocator 14.0.3` ve `flutter_map 8.3.1` pub.dev'den doğrulandı.

⚠️ **ZORUNLU ADIM:** `flutter pub deps | grep flutter_webrtc` — `flutter_webrtc: 1.4.0` **pinli** (livekit çakışmasın diye, `pubspec.yaml:59`). Yeni paketlerden hiçbiri onu yukarı çekmemeli. `flutter_map` saf Dart (doğrulandı), `geolocator` Baseflow — beklenmiyor ama **ölç, varsayma**.

### 6.2 Platform yapılandırması

**`ios/Runner/Info.plist`** — `UIBackgroundModes` (`:53-59`) dizisine `location` eklenir:
```xml
<string>location</string>
```
ve yeni anahtar:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Sohbette konumunuzu paylasabilmeniz ve canli konum gonderebilmeniz icin konum erisimi gerekir.</string>
```
⚠️ **`NSLocationAlwaysAndWhenInUseUsageDescription` EKLENMEYECEK.** "Always" izni istemiyoruz: `UIBackgroundModes: location` + `allowsBackgroundLocationUpdates=true` + **mavi şerit** ile "When In Use" izni arka planda da güncelleme almaya yeter. "Always" App Store incelemesini uzatır ve KVKK açısından gereğinden geniştir.

**`android/app/src/main/AndroidManifest.xml`** — `:10-12`'nin yanına:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
```
⚠️ **`ACCESS_BACKGROUND_LOCATION` EKLENMEYECEK.** Android belgesi: `location` tipli ön plan servisi **ön plandayken başlatıldığı sürece** bu izin gerekmez; yalnız servisi *arka plandan* başlatmak isteseydik gerekirdi. Bizim akışta paylaşımı hep kullanıcı ön plandayken başlatıyor. Bu izin ayrıca Play Store'da **ayrı gerekçe formu** ve uzun inceleme demektir.
⚠️ `geolocator_android` kendi manifestinde `GeolocatorLocationService`'i `foregroundServiceType="location"` ile **zaten bildiriyor** (doğrulandı) ama **hiçbir izin bildirmiyor** — izinler yukarıdaki gibi bizde olmak zorunda.

`<queries>` bloğuna (`:75-80`) `geo:` şeması eklenir (url_launcher'ın "Yol tarifi al"ı için):
```xml
<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="geo"/></intent>
```

### 6.3 Dosya haritası

| Dosya | İçerik |
|---|---|
| **yeni** `core/harita.dart` | `HaritaOturumu` (tile_url + attribution, `GET /maps/session`, 2 saatte bir tazelenir), `AtifSeridi` widget'ı, `geoUrl(lat,lng)` yardımcısı |
| **yeni** `features/chats/konum/konum_servisi.dart` | İzin/servis kontrolü, `mevcutKonum()`, REST çağrıları |
| **yeni** `features/chats/konum/canli_konum_servisi.dart` | **Uygulama ömrü boyu yaşayan** `StateNotifier` — GPS akışı + ping döngüsü + FGS ömrü |
| **yeni** `features/chats/konum/ek_paneli.dart` | Ataç → alttan panel (Konum / Kişi) |
| **yeni** `features/chats/konum/harita_secim_ekrani.dart` | `flutter_map` + sabit artı + "Bu konumu gönder" |
| **yeni** `features/chats/konum/konum_detay_ekrani.dart` | Tek nokta tam ekran + "Yol tarifi al" |
| **yeni** `features/chats/konum/canli_konum_ekrani.dart` | Canlı harita (marker'lar WS + 10 sn yoklama ile hareket eder) |
| **yeni** `features/chats/balonlar/konum_balonu.dart` | Anlık + canlı balon (tek widget, `live` alanına göre dallanır) |
| **yeni** `features/chats/balonlar/kisi_balonu.dart` | Kişi kartı balonu |
| **yeni** `features/chats/kisi_sec_ekrani.dart` | `user_search_screen.dart:147-168` liste deseninin kopyası, "Mesaj" yerine "Gönder" |
| `features/chats/models.dart:52-85` | `Message`'a: `contactId/contactName/contactUsername/contactAvatar`, `liveShareId/liveExpiresAt/liveEndedAt` (hepsi nullable, `fromJson`'da `j['contact']` ve `j['live']` alt nesnelerinden) |
| `features/chats/chats_provider.dart:77-83` | `send()`'in yanına `konumGonder`, `canliKonumBaslat`, `kisiGonder`. ⚠️ Hepsi POST sonrası `if (!mounted) return;` **kontrolüyle** `load()` çağırır — `messagesProvider` `autoDispose.family` (`:121-123`), kullanıcı gönderirken geri tuşuna basarsa notifier dispose olur ve `state=` atamasý patlar |
| `features/chats/chats_provider.dart:85-112` | `_onEvent`'e `location.live` ve `location.live.ended` dalları (balonun canlı durumunu günceller) |
| `features/chats/chat_screen.dart:251-261` | Dallanma: `system`→`_CallLogChip` · **`location`→`KonumBalonu`** · **`contact`→`KisiBalonu`** · else `_Bubble` |
| `features/chats/chat_screen.dart:269-303` | Row'un başına `IconButton(LucideIcons.paperclip)`. **`:291`'deki `// Faz 2: atas (medya) butonu buraya` yorumu tam olarak burayı işaret ediyor** |
| `features/chats/chats_screen.dart:219-236` | `_previewIkon`: `contact` → `LucideIcons.userRound`. `location` → `mapPin` (zaten var), canlıysa `LucideIcons.radio` |
| `features/chats/chats_screen.dart:238-260` | `_preview`: `contact` → `'Kişi'`; `location` → `chat.lastLive ? 'Canlı konum' : 'Konum'` |
| `router.dart:57` civarı | `/harita-sec`, `/konum/:msgId`, `/canli-konum/:shareId`, `/kisi-sec` rotaları |
| `main.dart` | `canliKonumProvider`ın uygulama açılışında bir kez `sunucudanTazele()` çağrılması + `resumed` kancası |

### 6.4 `CanliKonumServisi` — durum yönetimi

```dart
// features/chats/konum/canli_konum_servisi.dart  (TASLAK — imzalar ve kapilar)
class AktifPaylasim {
  final String shareId, chatId, chatBaslik;
  final DateTime expiresAt;
}

class CanliKonumDurumu {
  final Map<String, AktifPaylasim> benimkiler; // shareId -> paylasim
  bool get varMi => benimkiler.isNotEmpty;
}

class CanliKonumServisi extends StateNotifier<CanliKonumDurumu> {
  StreamSubscription<Position>? _akis;
  DateTime? _sonPing;
  bool _aramaVar = false;

  Future<String> baslat(String chatId, Duration sure) { ... }  // POST + akis
  Future<void> durdur(String shareId)                { ... }  // POST + temizle
  Future<void> sunucudanTazele()                     { ... }  // GET /live-locations/mine
  void _akisiKur()  { ... }   // tek abonelik; _aramaVar'a gore ayar
  void _akisiKapat(){ ... }   // benimkiler bosalinca
}

final canliKonumProvider =                       // ⚠️ autoDispose DEGIL
    StateNotifierProvider<CanliKonumServisi, CanliKonumDurumu>(CanliKonumServisi.new);
```

⚠️ **`autoDispose` OLMAYACAK.** Sohbet ekranı kapanınca paylaşımın ölmesi kabul edilemez — `ActiveCallController`'ın "ekran dispose'u aramayı BİTİRMEZ" hükmüyle **aynı sınıf** bir kural. Paylaşımı yalnız `durdur()` bitirir (TEK KAPI).

**Konum ayarları:**
```dart
// Android
AndroidSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 20,
  foregroundNotificationConfig: const ForegroundNotificationConfig(
    notificationTitle: 'Canlı konum paylaşılıyor',
    notificationText: 'Gebzem — durdurmak için dokun',
    notificationChannelName: 'Canlı konum',
    setOngoing: true,
    enableWakeLock: false,   // ⚠️ asagiya bak
  ),
)
// iOS
AppleSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 20,
  allowBackgroundLocationUpdates: true,
  showBackgroundLocationIndicator: true,   // mavi serit — durustluk + App Store
  pauseLocationUpdatesAutomatically: false,
)
```

⚠️ **`enableWakeLock: false` — ama bu turu 60'taki wakelock yasağıyla AYNI ŞEY DEĞİL.** Turu 60'ta elenen `wakelock_plus` **ekranı açık tutan** wakelock'tu (yanak dokunuşu + pil). Buradaki `enableWakeLock` bir **PARTIAL_WAKE_LOCK** (yalnız CPU) ve ekranı açmaz. Yine de `false` başlıyoruz: ön plan servisi tek başına dondurulmayı engelliyor. Sahada "ekran kapalıyken güncellemeler duruyor" gözlenirse **tek levye budur** — gelecek bir denetimin "turu 60 ihlali" diye geri almasını önlemek için bu ayrım kodda da yorum olarak yazılacak.

⚠️ **Ping kısıtı istemcide:** hareket halinde ≥15 sn, sabitken 60 sn kalp atışı. Hesap: şehir içi 50 km/h'de `distanceFilter: 20` saniyede birden fazla olay üretir; kısıtsız bırakılırsa 8 saatte ~15.000 HTTP isteği ve sürekli uyanık hücresel radyo demektir. 15 sn'lik kısıtla 8 saat ≈ 1.900 istek.

### 6.5 Balon görünümleri (Lucide, EMOJİ YOK)

Kullanılan ikon adları **kurulu `lucide_icons_flutter 3.1.14+2` içinde doğrulandı**: `mapPin`, `mapPinned`, `map`, `locateFixed`, `crosshair`, `navigation`, `radio`, `circleStop`, `timer`, `clock`, `userRound`, `userPlus`, `paperclip`, `externalLink`, `copy`, `triangleAlert`, `refreshCw`, `route`, `share2`.

**Anlık konum balonu** (`mine` hizalaması `_Bubble` ile aynı, `chat_screen.dart:621-642` gölge/köşe stili korunur):
```
┌──────────────────────────────┐   genislik 260, gorsel 260x146 (16:9)
│  [ STATIK HARITA PNG ]       │   ClipRRect radius 12, BoxFit.cover
│                              │   ortada mor pin katmani DEGIL — pin
│                              │   goruntunun ICINDE (Geoapify marker)
├──────────────────────────────┤
│ ⌖ Konum            09:12  ✓✓ │   LucideIcons.mapPin 14px, scheme.outline
└──────────────────────────────┘
```
Görsel yüklenemezse (önizleme üretilememiş / ağ yok): aynı kutuda nötr kart → `LucideIcons.mapPinned` 28px + "Konum" + `40.7921, 29.4453` + `LucideIcons.refreshCw` ile tekrar dene.

**Canlı konum balonu:**
```
┌──────────────────────────────┐
│  [ BASLANGIC PNG ]           │
│  ◉ Canlı konum        ← sol altta koyu saydam hap, LucideIcons.radio
│                          + 1.2sn'de bir nabiz atan 6px mor daire
├──────────────────────────────┤
│ ⏱ 42 dakika kaldı            │  geri sayim, expires_at'ten YEREL sayilir
│ Güncellendi · 12 sn önce     │  >90sn ise gri + "Bağlantı bekleniyor"
├──────────────────────────────┤
│ [   Paylaşımı durdur   ]     │  YALNIZ gonderende; chat_screen.dart:579-599
└──────────────────────────────┘  "Geri ara" dugmesiyle AYNI desen
```
Bittiğinde: görsel `ColorFiltered(greyscale)` + alt satır "Canlı konum sona erdi", buton kaybolur.

⚠️ Geri sayım **`expires_at` − `DateTime.now()`** ile hesaplanır. Bu bir "süre senkronu" değil, mutlak bir son tarihtir; CLAUDE.md'nin *"süre için `DateTime.now()` ile sunucu zamanı karşılaştırması YAPMA, monotonik `Stopwatch` kullan"* hükmü **arama süresi sayacı içindir** ve buraya uygulanmaz — burada aynı anda başlayan bir sayaç değil, sunucunun ilan ettiği bir bitiş anı var. Saat kayması en fazla geri sayımı birkaç saniye kaydırır; sunucu her hâlükârda `expired` olayını yayınlar.

**Kişi kartı balonu:**
```
┌──────────────────────────────┐
│ (◯) Ahmet Yılmaz             │  CircleAvatar 40px; avatar yoksa
│     @ahmet                   │  LucideIcons.userRound
├──────────────────────────────┤
│ [    Mesaj gönder    ]       │
└──────────────────────────────┘
```
`contact_user_id` NULL'a düşmüşse (kullanıcı silinmiş): gri kart, "Kişi (artık mevcut değil)", buton yok.

---

## 7. ⚠️⚠️ BU PROJEYE ÖZEL ÇAKIŞMA RİSKLERİ (zorunlu bölüm)

### 7.A Kamera ve mikrofon KULLANILMIYOR — kanıt

| İddia | Kanıt |
|---|---|
| iOS'ta ses birimi proses genelinde tek ve manuel modda | `ios/Runner/AppDelegate.swift:32-33` → `RTCAudioSession.sharedInstance().useManualAudio = true` + `isAudioEnabled = false` |
| iOS'ta flutter_webrtc TEK paylaşılan `videoCapturer` tutuyor | `AppDelegate.swift:668`, `:737`, `:905` → üçünde de `FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer` |
| Bu tasarım hiçbirine dokunmuyor | `geolocator` → CoreLocation / FusedLocationProvider · `flutter_map` → saf Dart raster çizim · `url_launcher` → sistem intent. Hiçbirinde `AVCaptureSession`, `AVAudioSession` veya `RTCAudioSession` yok. |

**Sonuç:** turu 50/67'nin "iki capture oturumu birbirini çalıyor" sınıfı ve turu 64/65'in `!pri` (`InsufficientPriority`) / `didActivate` gelmemesi sınıfı **bu işte yapısal olarak tetiklenemez.** Bu, tasarımın bilinçli bir kazancıdır — konum seçmek için `camera` paketi veya kamera önizlemesi gerektiren hiçbir yol seçilmedi.

⚠️ **YAPMA:** ileride "haritayı kamerayla AR modunda göster" gibi bir fikir gelirse bu bölüm geçersiz olur; o zaman `mesgulMu()` kapısı ve `_kameraKuyruguna` zinciri zorunlu hale gelir.

### 7.B ÇAKIŞMA 1 — Android: ikinci ön plan servisi

Projede zaten bir FGS var: `AramaServisi` (`AndroidManifest.xml:60-63`, `foregroundServiceType="microphone|camera"`, `BILDIRIM_ID=7317`, `AramaServisi.kt:47`). Canlı konum ikinci bir FGS başlatır (`GeolocatorLocationService`, tip `location`). Android iki FGS'ye izin verir; riskler ve çözümleri:

1. **Android 14 kuralı:** `location` tipli FGS **arka plandan başlatılamaz** (`SecurityException`). ⚠️ Bu yüzden `baslat()` yalnız ön planda çağrılır ve **sistem servisi öldürürse OTOMATİK YENİDEN BAŞLATILMAZ**; kullanıcı uygulamaya döndüğünde (`resumed`) yeniden kurulur.
2. **İzin maskesi:** `AramaServisi.kt:90-101` tip maskesini çalışma zamanında verilmiş izinlerden hesaplıyor.
   ⚠️⚠️ **YAPMA: `AramaServisi`'nin tip maskesine `location` ekleme, konumu o servise bindirme.** Bunu yaparsan aramanın arka planda ayakta kalması konum iznine bağlanır; konum reddedilirse maske değişir ve turu 32'de çözülen "5-10 saniyede arama düşüyor" hatası **başka bir kapıdan** geri gelir. İki servis **ayrı** kalacak.
3. **Bildirim çakışması:** iki kalıcı bildirim (Süren arama + Canlı konum) aynı anda görünür. Bu **doğru** davranıştır (iki ayrı kalıcı işlem var); ID'ler ve kanallar farklı olduğu için birbirini ezmez. `AramaServisi` `KANAL="gebzem_arama"`/`7317`; geolocator kendi kanalını kurar.
4. **Görev listesinden atma (swipe-kill):** her iki servis de ölür. Arama zaten biter; konum için bölüm 6.3'teki "sunucudan tazele + devam et" akışı devreye girer.

### 7.C ÇAKIŞMA 2 — WebSocket doktrini (EN KRİTİK, tasarımı belirledi)

`ws.dart:108-121` `goOffline()` uygulamayı her arka plana alışta soketi **bilerek** kapatıyor ve sunucuya `bg` çerçevesi gönderiyor; `chat/handler.go:106-111` bunu alınca kullanıcıyı **anında** çevrimdışı yapıyor. Bu **ZORUNLU** (turu 33: soket açık kalırsa sunucu kullanıcıyı "online" sanar, gelen aramaya push atmaz, **kilit ekranında telefon ÇALMAZ**).

**Sonuçlar:**
1. ⚠️ **Canlı konum ping'leri WS'ten GÖNDERİLEMEZ.** Ping'ler REST POST. (Ayrıca `handler.go:105-121` istemciden yalnız `bg` ve `typing` kabul ediyor; üçüncü bir istemci olayı eklemek o kapıyı genişletmek demek olurdu.)
2. ⚠️ **Alıcı arka plandayken WS'i yoktur** → `location.live` olayları kaybolur. Bu yüzden sunucu son konumu **Redis'te tutar** ve alıcı ön plana dönünce / canlı haritayı açınca `GET /chats/{id}/live-locations` ile uzlaştırır. **Bu, turu 61'de `call.held` için ödenen bedelin önden ödenmesidir.**
3. ⚠️⚠️ **YAPMA: "canlı konum sürerken WS'i açık tut" optimizasyonu.** Bu tam olarak turu 33 regresyonunu geri getirir: kullanıcı canlı konum paylaşırken telefonu **çalmaz**.

### 7.D ÇAKIŞMA 3 — İzin diyaloğu zinciri (turu 56 dersi)

Turu 56'da `Permission.phone.request()`, `requestFullIntentPermission()`den **sonra** çağrıldığı için sistem ayar ekranı açılıyor, Activity duraklıyor, izin diyaloğu **hiç gösterilmiyor** ve `Future` **asılı kalıyordu**.

⚠️ Konum izni:
- **Yalnız kullanıcının doğrudan bir dokunuşundan sonra** ve **başka hiçbir diyalog/ayar ekranı açık değilken** istenir.
- Uygulama açılışında **asla** istenmez (kayıt akışını bozar — turu 34-36'daki "kayıt ekranından atılma" sınıfı).
- `permission_handler` ile **paralel istenmez**; tek kaynak `Geolocator.requestPermission()`.
- Sonuç **her zaman okunur** (`unawaited` ile atılmaz) ve reddedilirse Sentry'e tek satır ölçüm yazılır.

### 7.E ÇAKIŞMA 4 — Pil / termal, arama sürerken

8 saatlik yüksek doğrulukta GPS + süren görüntülü arama, projenin test cihazında (iPhone XS Max — turu 50 notunda VP8 yazılım çözme yükü nedeniyle zaten ısınan cihaz) **termal kısılmaya** katkı yapar.

**Çözüm — durdurmak değil, düşürmek:**
```dart
// CanliKonumServisi, activeCallProvider'i dinler
_aramaVar = ctrl.arama != null;
// arama varken: distanceFilter 20 -> 100, accuracy high -> medium,
//               ping araligi 15sn -> 45sn
```
⚠️ **Gerekçe:** paylaşımı tamamen durdurmak, kullanıcının gizlilik açısından **görünür** bir sözünü (mavi şerit / bildirim duruyor, karşı taraf "canlı" görüyor) sessizce bozar. Düşürmek dürüsttür ve göstergeler doğru kalır.
⚠️ **YAPMA:** arama sırasında paylaşımı `stop` etme; karşı taraf "sona erdi" görür ve kullanıcı bunu hiç bilmez.

### 7.F ÇAKIŞMA 5 — `mesgulMu()` kapısı buraya UYGULANMAZ

`call_provider.dart:162-198`'deki `mesgulMu()` **ses cakışması** için var. Konum ne mikrofon ne hoparlör kullanıyor.
⚠️ **YAPMA:** harita seçim ekranını veya canlı konum ekranını `ekrandakiAramalar` kümesine kaydettirme. Kaydettirirsen o ekran açıkken kullanıcı **arama yapamaz/alamaz** (turu 53/56'daki "bayat muhafız" sınıfı hatanın yeni bir üreticisi olur).
⚠️ Tersi de doğru: arama sürerken ataç menüsü, konum gönderme ve kişi kartı **serbesttir** — hiçbiri engellenmez.

### 7.G ÇAKIŞMA 6 — `Authorization` başlığının 302'de sızması

`/maps/tile` R2'ye 302 atıyor. Dart HTTP istemcisi yönlendirmede başlıkları taşır → JWT'miz Cloudflare'e gider ve R2 isteği reddeder.
**Çözüm (bölüm 3.1):** tile ucu auth middleware **dışında**, kimlik sorgu dizesindeki kısa ömürlü HMAC'te. `flutter_map` tarafında `NetworkTileProvider()` **başlıksız** kullanılır.
⚠️ **YAPMA:** `TileLayer`e `headers: {'Authorization': ...}` verme.

### 7.H Bağımlılık pini

⚠️ `flutter_webrtc: 1.4.0` **kesin pin** (`pubspec.yaml:59`). Yeni 4 paketten hiçbiri onu yukarı çekmemeli. Build öncesi `flutter pub deps` ile **ölçülecek**, varsayılmayacak.
⚠️ `sentry_flutter 9.x` korunacak (8.x Kotlin/Swift derleme hatası).
⚠️ iOS deployment target **16.0** — düşürülmeyecek.

---

## 8. KENAR DURUMLAR

| Durum | Davranış |
|---|---|
| **Ağ koptu (gönderirken)** | Balon hiç oluşmaz; `apiErrorMessage(e)` → "Sunucuya ulaşılamıyor…" SnackBar. Kuyruk YOK (v1). Sunucuda yarım kayıt oluşmaz (tek INSERT). |
| **Ağ koptu (ping)** | Ping fire-and-forget + 1 tekrar (800 ms). Başarısız ping **atlanır**, bir sonraki konum yeni ping üretir. ⚠️ Ping'leri kuyruklama — eski koordinatı geç göndermek karşı tarafı **yanıltır**. |
| **Uygulama arka plana geçti** | Android: FGS çalışır, ping'ler sürer. iOS: mavi şerit, ping'ler sürer. WS kapanır (7.C) → alıcı, ön plana dönünce yoklamayla uzlaşır. |
| **Uygulama ÖLDÜRÜLDÜ (swipe-kill)** | Ping'ler durur. Sunucuda paylaşım `expires_at`'e kadar "aktif" kalır; alıcı balonu **grileşir** + "Son güncelleme 6 dk önce". Kullanıcı uygulamayı açınca `GET /live-locations/mine` → paylaşım hâlâ açıksa **akış otomatik yeniden kurulur** ve sohbet listesi üstünde şerit belirir: *"Canlı konum paylaşımın sürüyor · 22 dk"*. ⚠️ Sessizce sürdürme YOK — şerit her zaman görünür (gizlilik). |
| **Konum izni reddedildi** | Satır içi açıklama + **Ayarları aç** (`Geolocator.openAppSettings()`). `deniedForever` ise bir daha diyalog **istenmez**, doğrudan ayarlara yönlendirilir. |
| **GPS servisi kapalı** | "Konum servisi kapalı" + `Geolocator.openLocationSettings()`. |
| **Yalnızca yaklaşık konum** (Android 12+ / iOS "Yaklaşık") | `position.accuracy > 500` → gönderim öncesi uyarı şeridi (`LucideIcons.triangleAlert`) *"Yaklaşık konum paylaşılıyor"*. Gönderim **engellenmez**. |
| **Konum alınamadı (12 sn zaman aşımı)** | `getLastKnownPosition()` yedeği; o da yoksa "Konum alınamadı, açık alanda tekrar deneyin". |
| **"Dosya çok büyük" karşılığı** | Bu işte dosya yok. Karşılığı **koordinat doğrulama**: `lat ∈ [-90,90]`, `lng ∈ [-180,180]`, `NaN/Inf` reddi. ⚠️ Doğrulanmazsa NaN, Geoapify URL'ini bozar ve önizleme sonsuza kadar üretilemez. |
| **Aynı koordinat iki kez** | Aynı R2 anahtarı → Geoapify'a **ikinci istek gitmez**, R2'ye ikinci PUT atılmaz (HEAD kontrolü). Ayrıca `konum:msg:{uid}` 3 sn kısıtı çift dokunuşu keser. |
| **Aynı sohbette ikinci canlı paylaşım** | Kısmi UNIQUE index engeller; sunucu **süreyi uzatır**, aynı `share_id`/`message_id` döner. Yeni balon oluşmaz. |
| **Farklı sohbetlere aynı anda paylaşım** | Desteklenir. **Tek** GPS akışı, N ping. |
| **Gönderim sırasında sohbetten çıkıldı** | REST tamamlanır, mesaj oluşur. `MessagesNotifier` dispose olmuşsa `load()` **çağrılmaz** (`mounted` kapısı). Kullanıcı sohbete dönünce mesajı görür. |
| **Alıcı engelledi** | Okuma yolunda filtre: `GET /chats/{id}/live-locations` engelleyene **hiç veri döndürmez**. WS `To` listesi de engelleyeni çıkarır. Yeni konum/kişi mesajı `403`. ⚠️ Bugün `blocks` tablosuna **INSERT eden hiçbir kod ve uç yok** (keşif bulgusu) — yani bu kapı bugün pratikte hiç tetiklenmiyor; yine de doğru yazılıyor ki engelleme özelliği eklendiğinde çalışsın. |
| **Gönderen sohbetten atıldı/çıktı** | Ping `403` → istemci paylaşımı yerelde kapatır; sunucu `ended_at` yazar, `location.live.ended {reason:"revoked"}`. |
| **Kişi kartındaki kullanıcı silindi** | `contact_user_id` NULL olur (ON DELETE SET NULL), balon "Kişi (artık mevcut değil)". |
| **Önizleme üretilemedi** (Geoapify 5xx / kota / anahtar yok) | `media_url=''` ile mesaj **yine oluşur**; balon nötr karta düşer. Gecelik sweeper eksik önizlemeleri tamamlar. ⚠️ Konum mesajı **asla** önizleme yüzünden başarısız olmaz. |
| **Saat dilimi** | Tüm zamanlar sunucuda **UTC**; istemci `toLocal()` ile gösterir (mevcut `_DateChip` deseni, `chat_screen.dart:322-331`). |

---

## 9. GİZLİLİK VE YASAL (5651 / KVKK)

- **Kim görür:** yalnız o sohbetin üyeleri. 1:1'de tek kişi. Sunucu her uçta `chatMemberIDs` ile doğrular.
- **Ne kadar sürer:** 15 dk / 1 saat / 8 saat. Sunucu tarafında **kesin** son (`expires_at` + sweeper). İstemci öldürülse bile paylaşım sonsuza kadar sürmez.
- **Nasıl durdurulur:** balondaki "Paylaşımı durdur" · uygulama üstündeki şerit · ikinci cihazdan (`location.live.ended` `To` listesine gönderen de dahil).
- **İz tutulmuyor:** koordinatlar **yalnız Redis'te**, TTL = kalan süre. Postgres'te tek bir enlem/boylam bile yok. Paylaşım bitince Redis anahtarı **DEL** edilir.
- **5651 trafik bilgisi:** `live_locations` (kim, hangi sohbet, ne zaman başladı/bitti, `created_ip`) 1 yıl saklanır — kanunun istediği "bağlantı bilgisi" budur, içerik değil.
- **Yurt dışına aktarım:** statik önizleme için koordinat **Geoapify'a** gider. ⚠️ Ama bu istek **bizim sunucumuzdan** çıkar: kullanıcının IP'si, kimliği, sohbet kimliği Geoapify'a **hiç ulaşmaz** — yalnız "şu noktanın haritasını üret" bilgisi gider. Bu, mümkün olan en zayıf bağdır. Yine de **Aydınlatma Metni'nde açıkça yazılmalı** ve hukukçu teyidinden geçmeli.
- **Önizleme görselinin silinmesi:** önizlemeler koordinat bazlı ve **paylaşımlıdır** (birden çok mesaj aynı PNG'yi gösterebilir). Mesaj silinince PNG **silinmez**; anahtar tuzlu-hash olduğu için kimseye bağlanamaz ve içeriği herkese açık harita verisidir. R2 lifecycle: `harita/onizleme/` **365 gün** sonra sil. ⚠️ Bu bir karardır; hukukçu farklı derse lifecycle günü değiştirilir.
- **"Uçtan uca şifreli" İDDİA EDİLMEZ.** Konum sunucudan geçiyor.

---

## 10. TEST SENARYOLARI (kullanıcının elle yapacağı)

**Anlık konum**
1. Ataç → Konum → "Mevcut konumu gönder". Balon **haritalı** geldi mi? (Nötr kart geldiyse önizleme üretimi patlamıştır — sunucu logunda `harita onizleme` satırına bak.)
2. Karşı cihazda balon **anında** düştü mü, harita görseli göründü mü?
3. Aynı yerden **ikinci kez** gönder. İkinci balon anında geldi mi? (Geoapify'a gitmeden R2'den geldiği için ilkinden **belirgin hızlı** olmalı.)
4. Balona dokun → detay ekranı açıldı mı? "Yol tarifi al" sistem harita uygulamasını doğru koordinatta açtı mı?
5. Sohbet listesinde önizleme **"Konum"** ve pin ikonu göründü mü? Bildirimde "Konum" yazdı mı?

**Haritadan seçme**
6. Ataç → Konum → "Haritadan seç". Harita **yüklendi** mi (gri kalırsa tile yolu bozuk)? Sürükle-yakınlaştır akıcı mı?
7. Aynı bölgeye **ikinci kez** gir — tile'lar anında geldi mi? (R2 ısındı demektir.)
8. Ekranın sağ altında **atıf yazısı** (`© Geoapify · © OpenStreetMap`) görünüyor mu?
9. Farklı bir noktayı seçip gönder — balondaki pin **doğru yerde** mi?

**Canlı konum — temel**
10. Ataç → Konum → Canlı konum → **15 dakika**. Gönderen balonda "Canlı konum" rozeti + geri sayım + "Paylaşımı durdur" var mı?
11. Alıcı balonunda rozet ve "Güncellendi · X sn önce" ilerliyor mu?
12. Alıcı balona dokun → tam ekran harita. Gönderen **yürürken** marker hareket ediyor mu?
13. Gönderen "Paylaşımı durdur" → her iki tarafta balon **anında** "sona erdi"ye döndü mü?
14. Yeni bir paylaşım aç, **15 dakikayı doldur** → sweeper ikisini de "sona erdi" yaptı mı? (Sunucu logu: `canli konum suresi doldu`.)

**Canlı konum — zor durumlar (asıl testler)**
15. Paylaşım açıkken uygulamayı **alta al**, 5 dakika bekle, telefonla dolaş. Alıcıda marker **hareket etmeye devam etti** mi? (Android: bildirim gölgesinde "Canlı konum paylaşılıyor" duruyor mu? iOS: **mavi şerit** var mı?)
16. Paylaşım açıkken uygulamayı **görev listesinden yukarı at (öldür)**. Alıcıda balon **grileşti** mi ("Son güncelleme X dk önce")? Uygulamayı tekrar aç → *"Canlı konum paylaşımın sürüyor"* şeridi çıktı ve marker **yeniden hareket etmeye başladı** mı?
17. Paylaşım açıkken telefonu **kilitle**, 10 dk bekle. Güncellemeler devam etti mi? *(Devam etmezse Android'de `enableWakeLock: true` levyesi denenecek — bölüm 6.4.)*
18. Paylaşım açıkken **kendine gelen arama** gelsin. ⚠️ Telefon **çaldı** mı? (Çalmazsa 7.C ihlal edilmiş demektir — en kritik test.)
19. Paylaşım açıkken **görüntülü arama yap**, 5 dk konuş. Ses/görüntü bozuldu mu? Telefon aşırı ısındı mı? Arama bitince konum güncellemeleri sıklaştı mı?
20. Paylaşım açıkken **sesli odaya** ve **canlı yayına** gir/çık. Herhangi bir ses kesintisi/çakışma oldu mu? (Beklenen: hiçbir etki yok.)
21. Paylaşım açıkken **uçak modu** 2 dk → kapat. Marker kaldığı yerden devam etti mi, uygulama donmadı mı?
22. **İki farklı sohbete** aynı anda canlı konum paylaş. İkisi de güncelleniyor mu? Birini durdurmak diğerini etkiliyor mu? (Etkilememeli.)
23. Aynı sohbete "8 saat" seçip **hemen ardından "15 dakika"** seç. **İkinci bir balon oluşmadı** ve süre güncellendi mi?

**İzinler**
24. Konum iznini **Reddet** → açıklama + "Ayarları aç" çıktı mı? Uygulama çökmedi/donmadı mı?
25. İzni "Bir daha sorma" ile reddet → ikinci denemede diyalog **istemeden** doğrudan ayarlara yönlendirdi mi?
26. Ayarlarda **konumu kapat** → "Konum servisi kapalı" mesajı ve GPS ayarına yönlendirme çalıştı mı?
27. iOS'ta **"Yaklaşık konum"** seç → gönderim öncesi uyarı şeridi çıktı mı, yine de gönderilebildi mi?

**Kişi kartı**
28. Ataç → Kişi → birini ara ve gönder. Balonda **ad + @kullanıcıadı + avatar** doğru mu?
29. Alıcı "Mesaj gönder"e bastı → o kişiyle sohbet açıldı mı?
30. Sohbet listesinde önizleme **"Kişi"** ve kullanıcı ikonu göründü mü?
31. Kendini kişi kartı olarak göndermeyi dene → engellendi mi?

**Genel regresyon (bu tur bozulmamalı)**
32. Normal metin mesajı gönder/al, tik durumları, "yazıyor…" çalışıyor mu?
33. Sesli ve görüntülü arama, kilit ekranından kabul, sesli oda, canlı yayın — hepsi eskisi gibi mi?
34. Arayüzde **hiçbir emoji** görünmüyor, tüm yeni ikonlar 2B çizgi (Lucide) mi?
35. Tüm yeni metinlerde Türkçe karakterler doğru mu (ı/İ/ş/ğ/ü/ö/ç)?

---

## 11. BİLMEDİKLERİM (uydurmadım)

1. **`scaleFactor=2`'nin Geoapify kredi hesabını 2× artırıp artırmadığı.** Belge "tile sayısı" diyor ama retina çarpanının tile sayımına etkisini yazmıyor. Yukarıdaki "4 kredi/önizleme" **TAHMİN**; ilk hafta Geoapify panosundan ölçülmeli.
2. **Geoapify'ın Terms of Service'inin tam metnini okumadım.** "Saklama/önbellekleme serbest" ifadesi Geoapify'ın **kendi pazarlama/dokümantasyon sayfasından** geliyor. Sözleşme metniyle teyit edilmeli (bu tasarımın maliyet modeli tamamen buna dayanıyor).
3. **`latlong2` ve `url_launcher` sürümlerini pub.dev'den doğrulamadım.** `geolocator 14.0.3` ve `flutter_map 8.3.1` doğrulandı.
4. **Google Maps fiyat değişikliği (Mart 2025, $200 kredinin kaldırılması)** kardeş keşif ajanından geliyor; ben doğrudan doğrulamadım. Karar bundan bağımsız: `cloudMapId` zaten proje kuralıyla yasak.
5. **8 saatlik paylaşımın gerçek pil tüketimi.** Ölçmedim. TAHMİN %15-30. Ölçülmeden kullanıcıya sayı söylenmemeli.
6. **iOS'ta "When In Use" izniyle arka plan güncellemelerinin ne kadar süre kesintisiz devam ettiği.** Apple bunu garanti etmiyor; mavi şerit gizlenirse (uygulama uzun süre arka planda) iOS güncelleme sıklığını düşürebilir. Test 15/17 bunu ölçecek.
7. **BTK yer sağlayıcı bildiriminde konum verisinin ayrı bir yükümlülük doğurup doğurmadığı** ve **KVKK'da konumun "özel nitelikli veri" sayılıp sayılmayacağı.** Hukukçu teyidi şart.
8. **`enableWakeLock: false` ile Doze modunda güncellemelerin ne kadar geciktiği.** Sahada ölçülecek (test 17).

---

## Kaynaklar

- [MapTiler Cloud pricing](https://www.maptiler.com/cloud/pricing/)
- [Stadia Maps pricing](https://stadiamaps.com/pricing/)
- [Geoapify pricing](https://www.geoapify.com/pricing/)
- [Geoapify Static Maps API](https://www.geoapify.com/static-maps-api/) — ücretsiz planda dahil, önbellekleme/saklama izinli
- [Geoapify Static Maps geliştirici belgesi](https://apidocs.geoapify.com/docs/maps/static/) — `1 + tile/4 + marker` kredi formülü, 4096 px sınırı, atıf zorunluluğu
- [Geoapify Map Tiles](https://apidocs.geoapify.com/docs/maps/map-tiles/)
- [flutter_map (pub.dev)](https://pub.dev/packages/flutter_map) — 8.3.1, saf Dart
- [geolocator (pub.dev)](https://pub.dev/packages/geolocator) — 14.0.3, compileSdk 35, Android 14 `FOREGROUND_SERVICE_LOCATION`
- [geolocator_android AndroidManifest.xml](https://raw.githubusercontent.com/Baseflow/flutter-geolocator/main/geolocator_android/android/src/main/AndroidManifest.xml) — `GeolocatorLocationService` + `foregroundServiceType="location"`, izin bildirmiyor
- [ForegroundNotificationConfig (Dart API)](https://pub.dev/documentation/geolocator_android/latest/geolocator_android/ForegroundNotificationConfig-class.html)
- [AppleSettings (Dart API)](https://pub.dev/documentation/geolocator_apple/latest/geolocator_apple/AppleSettings-class.html)
- [Android — Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [Android — Restrictions on starting a foreground service from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [Android — Request location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions)
- [Apple — `allowsBackgroundLocationUpdates`](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates)

## İlgili dosyalar (mutlak yol)

- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\chat\handler.go`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\chat\hub.go`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\cmd\api\main.go`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\database\migrations\001_init.sql`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\database\migrations\013_call_hold.sql`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\config\config.go`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\streams\handler.go` (satır 446 — Redis throttle deseni)
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\chats\chat_screen.dart`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\chats\chats_screen.dart`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\chats\chats_provider.dart`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\chats\models.dart`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\core\ws.dart` (satır 108-121 — `goOffline`)
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\core\api.dart`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\calls\call_provider.dart` (satır 162-198 — `mesgulMu`)
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\ios\Runner\AppDelegate.swift` (32-33, 668, 737, 905)
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\ios\Runner\Info.plist` (53-64)
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\android\app\src\main\AndroidManifest.xml`
- `c:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\android\app\src\main\kotlin\app\gebzem\AramaServisi.kt`