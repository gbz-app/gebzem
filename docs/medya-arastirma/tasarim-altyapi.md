# MEDYA ALTYAPISI — MÜHENDİSLİK TASARIMI

Keşif çıktılarını zemin aldım, kritik iddiaları kaynaktan tekrar doğruladım. **Üç yerde keşiften bilinçli olarak ayrıldım** (§0.2), gerekçeleri yazılı.

---

## 0. DOĞRULAMA VE SAPMALAR

### 0.1 Kaynaktan tekrar doğruladıklarım

| İddia | Sonuç | Kanıt |
|---|---|---|
| Tip beyaz listesi `text,image,video,audio,location`, `system` dışarıda | ✅ | `backend/internal/chat/handler.go:152-157` |
| `media_url` istemciden doğrulanmadan INSERT | ✅ **AÇIK** | `handler.go:128` → `handler.go:169-171` |
| **İstemci bugün `media_url` HİÇ göndermiyor** | ✅ | `mobile/lib/features/chats/chats_provider.dart:80` → gövde yalnız `{'type','content'}` |
| `messages` tablosu: `media_url TEXT NOT NULL DEFAULT ''`, CHECK'te `document` YOK | ✅ | `001_init.sql:55,57` |
| Son migration 013 | ✅ | `backend/internal/database/migrations/` (001…013) |
| Migration runner: embed + `schema_migrations` + sırayla, tekrar çalıştırmaz | ✅ | `backend/internal/database/*.go:13,27-62` |
| `chatMemberIDs` göndereni listeden ÇIKARIYOR | ✅ | `handler.go:417-425` → gönderenin diğer cihazları `message.new` almaz |
| `preview[:80]` bayt kesme (UTF-8 bozar) | ✅ **HATA** | `handler.go:207-209` |
| `SendMessage`'da blok kontrolü YOK (yorum yanıltıcı) | ✅ | `handler.go:159` yorumu "uyelik + engel" diyor, `chatMemberIDs` yalnız üyelik bakıyor |
| `config.Config`'de R2 alanı yok | ✅ | `backend/internal/config/config.go` — yalnız Port/DB/Redis/JWT/Sentry/Firebase/DevMode |
| Flutter'da medya paketi yok | ✅ | `mobile/pubspec.yaml:30-77` |
| Sohbet giriş çubuğunda ataç yok, yer tutucu yorum var | ✅ | `chat_screen.dart:291` `// Faz 2: atas (medya) butonu buraya` |
| `_Bubble` tip ayrımı yapmıyor, düz `Text(content)` | ✅ | `chat_screen.dart:647-652` |
| `mesgulMu({haric, etiket, odaYayinMuaf})` tek kaynak | ✅ | `mobile/lib/features/calls/call_provider.dart:162-198` |

### 0.2 Keşiften SAPTIĞIM ÜÇ NOKTA (gerekçeli)

**(A) `tmp/` prefiksi + commit'te CopyObject → İPTAL. Doğrudan nihai anahtara yüklüyoruz.**
Keşif "gecici/ → doğrula → medya/'ya taşı" öneriyordu. Reddediyorum:
- CopyObject **+1 Class A** işlemi ve ardından DeleteObject; 900K medya/ay senaryosunda gereksiz maliyet.
- Keşfin kendi "bilmediklerim" listesinde **"R2'nin CopyObject davranışı büyük nesnelerde teyit edilmeli"** yazıyor — teyit edilmemiş bir işlemi kritik yola koymam.
- Güvenlik kaybı YOK: nesneye erişim **yalnız sunucunun ürettiği imzalı GET** ile mümkün ve sunucu `status='aktif'` olmayan hiçbir kayıt için imza üretmez. Yani commit edilmemiş nesne fiilen erişilemez.
- Yetim temizliği prefiks/lifecycle yerine **DB tabanlı gecelik sweeper** ile yapılır — daha kesin (lifecycle 24 saat gecikmeli ve DB ile senkron değil, keşif de bunu itiraf ediyor).

**(B) Erişim modelinde iki keşif çelişiyordu (public+CDN vs private+imzalı). Karar: ÖZEL BUCKET + imzalı GET, `cacheKey = media_id`.**
Cloudflare ajanı "public custom domain + immutable cache" (CDN kazancı), güvenlik ajanı "private + imzalı GET" (gizlilik) dedi. Bu **özel mesajlaşma medyası**; URL bir kez sızarsa (Sentry breadcrumb, ekran görüntüsü, log) içerik süresiz açık kalır ve 5651 kapsamında "kaldırdık" diyemeyiz. Özel bucket seçildi.
CDN kaybının bedeli ölçülebilir: her görüntüleme bir R2 **Class B** ($0,36/M, ilk 10M/ay ücretsiz). Asıl önbellek zaten **cihazda** olacak (§9). `cached_network_image`'a `cacheKey: media_id` verilerek imzalı URL değişse bile disk önbelleği korunur — imzalı URL'in klasik "cache tutmaz" sorunu böyle kapanıyor.

**(C) V1 kapsamına `document` (belge) DAHİL, ama `messages.type` CHECK değişikliği migration içinde AYRI ve İSTEĞE BAĞLI blok olarak duruyor.**
CLAUDE.md "şema değişikliği + deploy aynı turda RİSKLİ" diyor. `document` olmadan da altyapı tam çalışır (image/video/audio mevcut CHECK'te var). Belge istenmiyorsa 014'ün son bloğu silinir, başka hiçbir şey değişmez.

---

## 1. KULLANICI AKIŞI — dokunuştan karşı tarafta görünmeye

Örnek: **galeriden 3 fotoğraf, altyazılı.**

| # | Ne olur | Nerede |
|---|---|---|
| 1 | Kullanıcı giriş çubuğundaki **ataç** (`LucideIcons.paperclip`) düğmesine dokunur | `chat_screen.dart:291` |
| 2 | Alttan `EkPaneli` açılır: Galeri · Kamera · Belge · Konum. **Kamera ve ses notu kapıları burada değerlendirilir** (§7) | `ek_paneli.dart` (yeni) |
| 3 | Galeri → `image_picker.pickMultiImage(limit: 10)`. **İzin diyaloğu ÇIKMAZ** (PHPicker / Photo Picker) | `medya_hazirla.dart` |
| 4 | Önizleme ekranı: seçilenler alt şeritte, üstte büyük önizleme, altta altyazı alanı. Her medyaya ayrı altyazı | `medya_onizleme_ekrani.dart` (yeni) |
| 5 | "Gönder" → her dosya için **hazırlık** (arka planda, ana thread'i bloklamadan): sıkıştır (uzun kenar 1600px, q80) → 320px küçük resim üret → `md5(base64)` + `sha256(hex)` hesapla → **Documents/medya_giden/** altına KOPYALA | `medya_hazirla.dart` |
| 6 | Kuyruğa yazılır (kalıcı defter, shared_preferences). **Bu andan sonra sohbet kapansa, uygulama öldürülse bile iş kaybolmaz** | `medya_kuyrugu.dart` |
| 7 | Ekranda **iyimser balon** anında görünür: küçük resim + üstünde halka ilerleme + iptal (`LucideIcons.x`). `Message.id` negatif (yerel) | `chat_screen.dart` + `foto_balonu.dart` |
| 8 | Kuyruk işçisi: `POST /media/upload` → sunucu kota/tavan/mime kontrolü, **dedup kısa devresi**, iki parça için (asıl + küçük) presigned PUT URL'i döner | `internal/media/handler.go` |
| 9 | İstemci **doğrudan R2'ye** PUT eder (önce küçük resim, sonra asıl — küçük resim erken bitsin diye). Sunucudan hiç geçmez | `medya_yukleyici.dart` |
| 10 | `POST /media/upload/{id}/commit` → sunucu `HeadObject` (gerçek boyut/etag) + `Range GET ilk 256 KB` (+ video için son 256 KB) → **sihirli bayt**, boyut, **EXIF/GPS reddi** kontrolü. Geçerse `status='aktif'` | `internal/media/handler.go` |
| 11 | `POST /chats/{id}/messages` `{type:"image", media_id, content:"altyazı", client_ref}` | `chats_provider.dart` |
| 12 | Sunucu: üyelik + **blok** + `media_assets` sahiplik/durum/kind↔type kontrolü → INSERT → `message_receipts` → WS `message.new` (medya meta gömülü) → push ("Ahmet: Fotoğraf") | `chat/handler.go` |
| 13 | İstemci yanıtta **tam mesaj nesnesini** alır, yerel balonu onunla değiştirir, kuyruk kaydını siler, Documents'tan giden dosyayı siler | `medya_kuyrugu.dart` |
| 14 | **Karşı taraf**: WS `message.new` → balon çizilir. Küçük resim `GET /media/{id}/url` ile alınıp **hemen** indirilir (her zaman, çok küçük). Asıl dosya **otomatik indirme kuralına** göre (§9) indirilir ya da "indir" halkası gösterilir | `medya_onbellek.dart` |
| 15 | Karşı taraf balona dokunur → tam ekran görüntüleyici; asıl indirilmemişse önce indirilir | `medya_goruntuleyici.dart` |

**Toplam dokunuş: ataç → Galeri → seç → Gönder = 4.**

---

## 2. BACKEND — uçlar ve değişen dosyalar

### 2.1 Yeni paket: `backend/internal/media/`

| Dosya | İçerik |
|---|---|
| `sigv4.go` | AWS SigV4 presign — **harici bağımlılık YOK**, `crypto/hmac`+`crypto/sha256`. Referans: `scratchpad/r2put.js:32-96` aynı algoritmayı JS'te yapıyor. `go.mod`'a tek satır eklenmez. |
| `r2.go` | `HeadObject`, `RangeGet(key, start, end)`, `DeleteObject` — imzalı `http.Client` çağrıları. |
| `sniff.go` | Sihirli bayt tablosu + EXIF/GPS tespiti + MP4 `moov`/`ftyp` kontrolü. |
| `limits.go` | Tip başına tavanlar + Redis Lua kota script'i. |
| `handler.go` | 4 uç (aşağıda). |
| `sweeper.go` | `StartSweeper(ctx)` — yetim/yaşlı nesne temizliği + silme kuyruğu. |

### 2.2 Uçlar

Hepsi **korumalı grupta** (`main.go:145` `r.Use(auth.Middleware(...))` içinde).
⚠️ Hiçbiri `api.dart:52-57`'deki 401 muafiyet listesine **EKLENMEYECEK** — normal 401 davranışı doğru.

---

#### `POST /media/upload` — presign

```jsonc
// İSTEK
{
  "kind": "image",                 // image | video | audio | document
  "mime": "image/jpeg",
  "bytes": 214553,
  "md5": "kZLm3Q==",               // Content-MD5, BASE64 (hex DEĞİL)
  "sha256": "a3f1...",             // hex — dedup + moderasyon kancası
  "width": 1280, "height": 960,    // görsel/video
  "duration_ms": 0,                // ses/video
  "file_name": "",                 // YALNIZ belge (anahtara GİRMEZ, DB'de durur)
  "waveform": "",                  // YALNIZ ses notu: 60 adet 0-99, virgüllü
  "thumb": { "mime": "image/jpeg", "bytes": 14210, "md5": "Bq7x1Q==" }  // ops.
}

// 200 — normal
{
  "media_id": "9f3c1a7e-...",
  "hazir": false,
  "expires_in": 300,
  "asil":  { "url": "https://<hesap>.r2.cloudflarestorage.com/gebzem-media/img/2026/08/07/9f3c….jpg?X-Amz-…",
             "headers": { "Content-Type": "image/jpeg", "Content-MD5": "kZLm3Q==", "If-None-Match": "*" } },
  "kucuk": { "url": "…", "headers": { … } }
}

// 200 — DEDUP KISA DEVRESİ (aynı kullanıcı aynı sha256'yı daha önce yüklemiş)
{ "media_id": "…", "hazir": true }
```

**Kapılar (sırayla):**
1. Hesap askıda mı (`users.suspended_at`) → `403 "hesabınız askıya alınmış"`
2. `kind` ∈ beyaz liste, `mime` ↔ `kind` eşleşiyor mu → `400 "desteklenmeyen dosya türü"`
3. `bytes` ≤ tavan → `413 {"error":"Dosya çok büyük (en fazla 16 MB)"}`
4. `md5` base64 çözülebiliyor ve 16 bayt mı → `400 "geçersiz istek"`
5. Redis Lua kota (§2.4) → `429 {"error":"Çok fazla medya gönderdiniz, biraz bekleyin"}`
6. Dedup: `SELECT id FROM media_assets WHERE owner_id=$me AND sha256=$s AND status='aktif' LIMIT 1` → varsa `{hazir:true}` (yükleme HİÇ yapılmaz)
7. `media_assets` INSERT `status='gecici'`, `expected_bytes`, `expected_md5`
8. Presign üret

**Presign detayları (kanıta dayalı):**
- İmzaya **`content-type`** dahil → istemci farklı tip gönderirse R2 `403 SignatureDoesNotMatch`.
- İmzaya **`content-md5`** dahil → istemci **tam olarak o baytları** yükleyebilir; farklıysa `BadDigest`. R2'de presigned PUT'a boyut sınırı yazılamadığı için (**`content-length-range` yok, POST policy desteklenmiyor**) boyut zorlamasının pratik karşılığı budur.
- İmzaya **`if-none-match: *`** dahil → nesne varsa `412` → presigned URL **fiilen tek kullanımlık**.
  ⚠️ İstemci `412`'yi "hata" saymaz, **"zaten yüklenmiş"** sayıp doğrudan commit'e geçer (kayıp yanıt sonrası tekrar deneme senaryosu).
- **TTL boyuta göre**: `ttl = clamp(300sn, bytes/20000 sn, 1800sn)`. 16 MB → 800 sn. Sabit 5 dk yavaş hücresel ağda 16 MB'lık videoyu bitiremez.

---

#### `POST /media/upload/{id}/commit`

```jsonc
// 200
{ "media_id":"…", "kind":"image", "mime":"image/jpeg", "bytes":214553,
  "width":1280, "height":960, "duration_ms":0, "file_name":"", "waveform":"" }
// 409 {"error":"yükleme bulunamadı veya süresi doldu"}
// 422 {"error":"dosya doğrulanamadı"}   -> sunucu nesneyi SİLER, status='reddedildi'
```

**Doğrulama zinciri (sunucu tarafı — istemciye asla güvenilmez):**
1. Satır sahibi = ben, `status='gecici'`, `created_at > now()-1 saat` → değilse `409`
2. `HeadObject(object_key)` → gerçek `Content-Length`. `!= expected_bytes` → red
3. `RangeGet(0..262143)` → **sihirli bayt** kontrolü:
   - JPEG `FF D8 FF` · PNG `89 50 4E 47 0D 0A 1A 0A` · WebP `RIFF`+off8`WEBP`
   - MP4/M4A off4 `ftyp` + marka ∈ {isom,iso2,mp41,mp42,avc1,M4A }
   - Ogg `OggS` + off28 `OpusHead`
   - **YASAK ve red**: SVG, HTML/XHTML, JS, `PK\x03\x04` (zip/apk/docx), `MZ` (exe), `%PDF` (V1'de belge = octet-stream, PDF içerik tipi olarak sunulmaz), HEIC/HEIF, GIF
4. **EXIF/GPS reddi**: JPEG'te `APP1` + `Exif\0\0` bloğu ve içinde GPS IFD (`0x8825`) varsa **red**. İstemci yeniden kodlarken EXIF'i zaten düşürür; EXIF gelmesi "değiştirilmiş istemci" işaretidir.
5. Video için ek `RangeGet(son 256 KB)` → `moov` atomu ve `©xyz` / `com.apple.quicktime.location.ISO6709` konum anahtarı taranır → varsa red.
   ⚠️ `moov` faststart uygulanmamışsa **dosyanın SONUNDA** olur; bu yüzden iki uçtan da okunur.
6. Piksel sınırı: `width*height ≤ 50 MP` (dekompresyon bombası)
7. Küçük resim varsa aynı 1-4 kontrolü
8. Geçerse `status='aktif'`, `committed_at=now()`, gerçek boyut yazılır
9. Geçmezse **`DeleteObject` (ücretsiz)** + `status='reddedildi'` + Sentry olayı (breadcrumb değil)

---

#### `DELETE /media/upload/{id}` — iptal
Sahibi + `status='gecici'` → `DeleteObject` (varsa) + satır silinir → `204`.
İstemci kullanıcı iptal ettiğinde çağırır. Çağrılmasa da sweeper temizler.

---

#### `GET /media/{id}/url` — kısa ömürlü imzalı GET

```jsonc
// 200
{ "asil": "https://…?X-Amz-Expires=600&X-Amz-Signature=…",
  "kucuk": "https://…",
  "expires_in": 600,
  "mime": "image/jpeg", "bytes": 214553, "file_name": "" }
// 403 {"error":"bu medyaya erişim yetkiniz yok"}
// 410 {"error":"medya artık mevcut değil"}
```

**Yetki (tek sorgu):**
```sql
SELECT a.id FROM media_assets a
WHERE a.id=$1 AND a.status='aktif' AND (
  a.owner_id=$2 OR EXISTS (
    SELECT 1 FROM messages m
    JOIN chat_members cm ON cm.chat_id=m.chat_id AND cm.user_id=$2
    WHERE m.media_id=a.id AND NOT m.deleted_for_all))
```
⚠️ **`media_url` DB'de saklanmaz.** Bir kayıt sızsa bile içeriğe ulaşılamaz; erişim her seferinde üyelikten türetilir. `messages.media_url` sütunu (`001_init.sql:57`) **kullanılmadan durur** (kaldırmak yıkıcı değişiklik, gerek yok) ve API'de hep `""` döner.

---

#### `POST /chats/{chatID}/messages` — DEĞİŞİYOR

`backend/internal/chat/handler.go:125-214`

```go
// handler.go:125-130 -> YENI HALI
type sendMessageReq struct {
    Type      string  `json:"type"`
    Content   string  `json:"content"`      // metin ya da MEDYA ALTYAZISI
    MediaID   string  `json:"media_id"`     // YENI — media_url'in yerine
    ClientRef string  `json:"client_ref"`   // YENI — idempotency (tekrar deneme)
    ReplyToID *int64  `json:"reply_to_id"`
}
```

⚠️ **`MediaURL` alanı SİLİNİR.** Risk sıfır: mevcut istemci bu alanı hiç göndermiyor (`chats_provider.dart:80` doğrulandı). Bu, bugünkü SSRF/oltalama açığını (`handler.go:169-171`) kapatan tek satırlık kök çözümdür.

**Değişiklik listesi:**

| Konum | Ne değişiyor |
|---|---|
| `handler.go:152-157` | Beyaz listeye **yalnız `"document"`** eklenir (belge kapsama alınırsa). ⚠️ **`system` EKLENMEZ** — turu 59b kimlik taklidi açığı. |
| `handler.go:158` (yeni blok) | **Blok kontrolü**: `direct` sohbette çift yönlü `blocks` sorgusu → `403 "bu kullanıcıya mesaj gönderilemiyor"`. Bugün YOK (`handler.go:159` yorumu yanıltıcı, `chatMemberIDs` yalnız üyelik bakıyor). Medya bu boşluğu tehlikeli hale getirir. |
| `handler.go:158` (yeni blok) | **Medya kilidi**: `type ∈ {image,video,audio,document}` ise `media_id` zorunlu; `media_assets` satırı `owner_id=$me AND status='aktif' AND kind` ↔ `type` eşleşmeli → aksi `400 "medya bulunamadı"`. |
| `handler.go:158` (yeni blok) | **Idempotency**: `client_ref` doluysa önce `SELECT id, created_at FROM messages WHERE chat_id=$1 AND sender_id=$2 AND client_ref=$3` — varsa **yeni satır açmadan** o satır döner (`201`). |
| `handler.go:168-171` | INSERT `media_id`, `client_ref` de yazar; `media_url` alanına `''` yazılır. |
| `handler.go:185-189` | WS payload'a `media` nesnesi eklenir (§4). |
| `handler.go:196-209` | Push önizlemesine `document` → dosya adı eklenir **ve** `preview[:80]` hatası düzeltilir: `[]rune(preview)[:80]`. Bugün Türkçe karakter 80. baytta ortadan bölünüp push gövdesine bozuk UTF-8 gidiyor. |
| `handler.go:213` | Yanıt **tam mesaj nesnesi** döner (id, created_at, type, content, media{…}) — istemci iyimser balonu tek hamlede gerçek veriyle değiştirsin. Bugün yalnız `{id, created_at}` dönüyor. |
| `handler.go:234-256` | `GetMessages` SELECT'ine `LEFT JOIN media_assets` + `media` nesnesi + `client_ref`. `deleted_for_all` maskesi medyayı da kapsar (media alanı `null` döner). |
| `handler.go:326-349` | `ListChats` önizlemesi: `document` için dosya adını göstermek üzere `lm.media_id`'den `file_name` çekilir (LATERAL'e eklenir). |

---

#### `DELETE /chats/{chatID}/messages/{id}` — YENİ (herkesten sil)

Bugün `deleted_for_all` **yazan hiçbir kod yok** — `handler.go:236-238` ve `chat_screen.dart:647-650` ölü dallar. 5651'in "4 saat içinde kaldırma" yükümlülüğü bu uç olmadan karşılanamaz.

```jsonc
// 200 { "message":"ok" }
// 403 {"error":"bu mesajı silemezsiniz"}
// 404 {"error":"mesaj bulunamadı"}
```

```sql
-- 1) mesajı maskele (media_id KORUNUR — referans sayımı ona bağlı)
UPDATE messages SET deleted_for_all=true, content=''
WHERE id=$1 AND chat_id=$2 AND sender_id=$3 AND NOT deleted_for_all
RETURNING media_id;

-- 2) medya artık HİÇBİR canlı mesajda geçmiyorsa nesneyi sil
SELECT count(*) FROM messages WHERE media_id=$1 AND NOT deleted_for_all;
-- 0 ise: UPDATE media_assets SET status='silindi', deleted_at=now() WHERE id=$1;
--        INSERT INTO media_delete_queue (object_key) VALUES (...), (thumb_key);
--        R2 DeleteObject SATIR İÇİNDE denenir (ücretsiz, hızlı); başarısızsa kuyrukta kalır.
```

⚠️ **`media_id`'yi NULL'lama.** NULL'larsan referans sayımı kırılır ve **iletme (forward) geldiğinde başkasının mesajının medyasını silersin.** `deleted_for_all` maskesi zaten yeterli.

WS: `message.deleted` yayınlanır — **alıcılara VE gönderenin diğer cihazlarına** (`append(members, userID)`).

---

### 2.3 `main.go` değişiklikleri

```go
// main.go:86-94 desenine göre (roomsH / streamsH ile aynı yer)
mediaH := media.NewHandler(db, rdb, cfg)
if mediaH.Enabled() {                 // R2 env'leri yoksa medya SESSİZCE kapalı
    log.Println("medya: aktif")
    mediaH.StartSweeper(ctx)          // yetim + silme kuyruğu + yaş sınırı
}

// main.go:96-102 middleware zinciri — YENİ
r.Use(middleware.RequestSize(1 << 20)) // 1 MB gövde tavanı: JSON uçları için.
                                        // ⚠️ Medya R2'ye GİDİYOR, API'den geçmiyor.

// main.go:157-162 korumalı grup — YENİ SATIRLAR
r.Post("/media/upload", mediaH.Presign)
r.Post("/media/upload/{id}/commit", mediaH.Commit)
r.Delete("/media/upload/{id}", mediaH.Cancel)
r.Get("/media/{id}/url", mediaH.SignedURL)
r.Delete("/chats/{chatID}/messages/{id}", chatH.DeleteMessage)
```

### 2.4 `config.go` — yeni env alanları

```go
// backend/internal/config/config.go
R2AccessKeyID     string // .env.infra'da ZATEN VAR
R2SecretAccessKey string //  "
R2Endpoint        string //  "  https://<hesap>.r2.cloudflarestorage.com
R2Bucket          string // gebzem-media (BOŞ bucket, hazır bekliyor)
MedyaTavanMB      int    // varsayılan 16
```
⚠️ Hepsi boşsa `mediaH.Enabled()==false` → ataç butonu istemcide gizlenir (`GET /users/me` yanıtına `media_acik: bool` eklenir). **Fail-closed**: yetki/anahtar fallback'i YASAK (repo PUBLIC).
⚠️ `backend/.env` ve `.env.infra` git'e **girmez** — dokunulmaz.

### 2.5 Kota / hız sınırı — Redis Lua (`limits.go`)

Desen mevcut: `streams/guests.go:52` `redis.NewScript`.

```lua
-- KEYS[1] medya:kota:{uid}:sa:{yyyymmddHH}
-- KEYS[2] medya:kota:{uid}:gun:{yyyymmdd}
-- KEYS[3] medya:kota:{uid}:bayt:{yyyymm}
-- ARGV: saatlik, gunluk, aylikBayt, istenenBayt
local a=tonumber(redis.call('GET',KEYS[1]) or 0)
local b=tonumber(redis.call('GET',KEYS[2]) or 0)
local c=tonumber(redis.call('GET',KEYS[3]) or 0)
if a>=tonumber(ARGV[1]) then return 1 end
if b>=tonumber(ARGV[2]) then return 2 end
if c+tonumber(ARGV[4])>tonumber(ARGV[3]) then return 3 end
redis.call('INCR',KEYS[1]); redis.call('EXPIRE',KEYS[1],7200)
redis.call('INCR',KEYS[2]); redis.call('EXPIRE',KEYS[2],172800)
redis.call('INCRBY',KEYS[3],ARGV[4]); redis.call('EXPIRE',KEYS[3],2764800)
return 0
```

| Kural | Normal hesap | **Yeni hesap (<24 saat)** |
|---|---|---|
| Medya presign | 60/saat · 300/gün | **20/gün** |
| Aylık bayt | 2 GB | **100 MB** |
| Mesaj gönderimi (metin dahil) | 20/10sn burst · 600/saat | aynı |

⚠️ Mesaj hız sınırı bugün **hiç yok** (`main.go:96-102` zincirinde yok, `SendMessage`'da yok). Medya bunu spam açısından kritik hale getiriyor.

### 2.6 Tavanlar — TEK KAYNAK

| kind | İstemci hedefi | **Sunucu SERT tavanı** | mime |
|---|---|---|---|
| `image` | 1600px uzun kenar, JPEG q80, ≤400 KB | **2 MB** | image/jpeg, image/webp, image/png |
| küçük resim | 320px, ≤20 KB | **128 KB** | image/jpeg |
| `audio` | AAC-LC 32 kbps mono, ≤120 sn | **2 MB** | audio/mp4 |
| `video` | 720p H.264, ≤60 sn | **16 MB** | video/mp4 |
| `document` | — | **25 MB** | application/octet-stream (sabit) |

⚠️ Bu tablo **üç yerde birebir aynı** olmalı: `internal/media/limits.go` · `mobile/lib/features/media/medya_tip.dart` · önizleme ekranındaki uyarı metni. (CLAUDE.md "dört yer aynı sayı olmalı" dersinin aynısı.)

---

## 3. VERİTABANI — `014_media.sql`

```sql
-- 014_media.sql — MEDYA MESAJLASMA ALTYAPISI
-- ⚠️ ADDITIVE: mevcut tablolara YALNIZ yeni sutun/index eklenir.
--    Hicbir sutun degistirilmez, kaldirilmaz, tip donusturulmez.
--    Bu migration uygulanmis bir DB'de ESKI istemci ve ESKI backend AYNEN calisir.

-- ============ 1) MEDYA VARLIKLARI ============
CREATE TABLE IF NOT EXISTS media_assets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK (kind IN ('image','video','audio','document')),

    -- R2 nesne anahtarlari. TAM URL SAKLANMAZ: erisim her istekte imzalanir.
    -- Anahtarda kullanici id / sohbet id / telefon / dosya adi YOKTUR (sizinti onlemi).
    object_key    TEXT NOT NULL UNIQUE,          -- img/2026/08/07/<uuid>.jpg
    thumb_key     TEXT NOT NULL DEFAULT '',      -- thm/2026/08/07/<uuid>.jpg (AYNI uuid)

    mime          TEXT NOT NULL,
    bytes         BIGINT NOT NULL DEFAULT 0,     -- COMMIT'te HeadObject ile DOGRULANMIS deger
    sha256        TEXT NOT NULL DEFAULT '',      -- dedup + moderasyon kancasi (hex)
    width         INT NOT NULL DEFAULT 0,
    height        INT NOT NULL DEFAULT 0,
    duration_ms   INT NOT NULL DEFAULT 0,
    file_name     TEXT NOT NULL DEFAULT '',      -- belge gosterim adi (ANAHTARDA yok)
    waveform      TEXT NOT NULL DEFAULT '',      -- ses notu: 60 adet 0-99, virgullu

    status        TEXT NOT NULL DEFAULT 'gecici'
                  CHECK (status IN ('gecici','aktif','reddedildi','karantina','silindi')),

    -- presign aninda istemcinin BEYAN ettigi degerler; commit'te GERCEKLE karsilastirilir
    expected_bytes       BIGINT NOT NULL DEFAULT 0,
    expected_md5         TEXT   NOT NULL DEFAULT '',
    thumb_expected_bytes BIGINT NOT NULL DEFAULT 0,
    thumb_expected_md5   TEXT   NOT NULL DEFAULT '',

    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    committed_at  TIMESTAMPTZ,
    deleted_at    TIMESTAMPTZ
);

-- sweeper: yetim 'gecici' satirlari + yasi dolmus 'aktif' satirlari bulur
CREATE INDEX IF NOT EXISTS idx_media_status_created ON media_assets (status, created_at);
-- dedup kisa devresi (presign yolunda HER istekte kosar -> kismi index sart)
CREATE INDEX IF NOT EXISTS idx_media_dedup ON media_assets (owner_id, sha256)
    WHERE status = 'aktif';
-- moderasyon: bir hash'in TUM kopyalarini tek hamlede kaldirmak icin
CREATE INDEX IF NOT EXISTS idx_media_sha ON media_assets (sha256);

-- ============ 2) MESSAGES BAGLANTISI (additive) ============
ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_id UUID
    REFERENCES media_assets(id) ON DELETE SET NULL;
-- ⚠️ ON DELETE SET NULL bilincli: medya satiri silinse bile MESAJ KAYBOLMAZ
--    (balon "medya artik mevcut degil" gosterir). CASCADE olsaydi bir medya
--    temizligi kullanicinin mesaj gecmisini SILERDI.

ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_ref TEXT NOT NULL DEFAULT '';
-- Idempotency: ag zaman asimindan sonra tekrar denenen POST IKINCI MESAJ URETMEZ.

-- referans sayimi sorgusu (silmede kosar) + medya galerisi ekrani
CREATE INDEX IF NOT EXISTS idx_messages_media ON messages (media_id)
    WHERE media_id IS NOT NULL;

-- ayni istemci referansi ikinci kez INSERT edilemez
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_ref
    ON messages (chat_id, sender_id, client_ref) WHERE client_ref <> '';

-- ============ 3) SILME KUYRUGU ============
-- R2 DeleteObject satir ici denenir; basarisiz olursa nesne SIZMASIN diye kuyruk.
CREATE TABLE IF NOT EXISTS media_delete_queue (
    id         BIGSERIAL PRIMARY KEY,
    object_key TEXT NOT NULL,
    tries      INT NOT NULL DEFAULT 0,
    last_error TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_delq ON media_delete_queue (tries, created_at);

-- ============ 4) OKUNMAMIS SAYACI ICIN EKSIK INDEX ============
-- ListChats (chat/handler.go:333-335) her sohbet icin message_receipts'i tariyor;
-- user_id uzerinde index YOK (001_init.sql:65-71). Medya ile mesaj hacmi artacak.
CREATE INDEX IF NOT EXISTS idx_receipts_user_unread ON message_receipts (user_id)
    WHERE read_at IS NULL;

-- ============ 5) OPSIYONEL — BELGE TIPI ============
-- ⚠️⚠️ BU BLOK AYRI TUTULDU. Belge V1 kapsaminda DEGILSE bu blogu SIL;
--    geri kalan migration image/video/audio icin TAM calisir (001_init.sql:55
--    CHECK'i bu ucunu ZATEN iceriyor). CLAUDE.md: "sema degisikligi + deploy
--    ayni turda RISKLI" -> tek satirlik da olsa bilincli bir karar olsun.
-- ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check;
-- ALTER TABLE messages ADD CONSTRAINT messages_type_check
--     CHECK (type IN ('text','image','video','audio','location','system','document'));
```

**`ON DELETE` özeti:**
- `media_assets.owner_id` → `CASCADE` (kullanıcı silinirse varlıkları da gider; nesneler silme kuyruğuna sweeper tarafından girer)
- `messages.media_id` → **`SET NULL`** (medya gider, mesaj kalır)
- `media_delete_queue` → FK yok (bilinçli: satır silinse bile kuyruk yaşar)

---

## 4. WS OLAY SÖZLEŞMESİ

`Hub`da (`hub.go:30-36`) **hiçbir değişiklik yok** — `Event.Payload` ham JSON.

### 4.1 `message.new` — GENİŞLETİLDİ (kırıcı değil)

```jsonc
{
  "type": "message.new",
  "chat_id": "…",
  "payload": {
    "id": 4711,
    "chat_id": "…",
    "sender_id": "…",
    "type": "image",
    "content": "Kahvaltı hazır",        // ALTYAZI
    "media_url": "",                     // ⚠️ ARTIK HEP BOS — geriye uyum icin duruyor
    "reply_to_id": null,
    "client_ref": "…",
    "created_at": "2026-08-07T09:12:44Z",
    "media": {                           // YENI — null olabilir
      "id": "9f3c1a7e-…",
      "kind": "image",
      "mime": "image/jpeg",
      "bytes": 214553,
      "width": 1280, "height": 960,
      "duration_ms": 0,
      "file_name": "",
      "waveform": "",
      "thumb": true                      // kucuk resim var mi
    }
  }
}
```

⚠️ **Eski istemci güvenli**: `Message.fromJson` (`models.dart:75-84`) bilinmeyen alanları yok sayar, `media_url` boş gelir → medya mesajı boş metin balonu olur. Çirkin ama çökmez. **Yeni istemci + eski sunucu** da güvenli: `media` yoksa `null`.

### 4.2 `message.deleted` — YENİ

```jsonc
{ "type":"message.deleted", "chat_id":"…", "payload": { "message_id": 4711 } }
```
`To` = üyeler **+ gönderenin kendisi** (diğer cihazları için). Bu, `chatMemberIDs`'in gönderen-hariç davranışına (`handler.go:421-425`) **bilinçli istisnadır**.

### 4.3 EKLENMEYECEK olanlar (gerekçeli)

- ❌ **Yükleme ilerlemesi WS'ten gitmez.** Tamamen yerel durum. 900K medya/ay × ~20 ilerleme çerçevesi = 18M gereksiz Redis publish. Ayrıca hub yavaş istemcide mesajı **sessizce düşürüyor** (`hub.go:99-101`) — ilerleme için güvenilmez kanal.
- ❌ **`media.ready` yok** — commit senkron; istemci yanıtı zaten alıyor.
- ❌ Yeni Redis kanalı yok; `"events"` tek kanal kalır.

---

## 5. FLUTTER — mimari

### 5.1 Yeni paketler (`pubspec.yaml`)

```yaml
  # ---- MEDYA MESAJLASMA ----
  # Galeri/kamera. iOS PHPicker / Android Photo Picker -> IZIN ISTEMEZ.
  # ⚠️ `camera` paketi KULLANILMADI: iOS'ta flutter_webrtc TEK paylasilan
  #    videoCapturer tutuyor; ucuncu bir AVCaptureSession turu 50/67 hatasini
  #    (tek tarafli video) geri getirir.
  # ⚠️ Android'de uygulama oldurulebilir -> donuste retrieveLostData() ZORUNLU.
  image_picker: ^1.2.3
  file_picker: ^11.0.3              # belge (sistem secici -> izin yok)
  flutter_image_compress: ^2.5.1    # ⚠️ keepExif: true YAZMA (varsayilan EXIF'i siler)
  video_compress: ^3.1.4            # %100 native; ⚠️ 18 aydir guncellenmemis
  video_player: ^2.13.0             # ⚠️ chewie EKLEME (Material ikon + wakelock_plus + provider)
  record: ^7.1.1                    # ses notu, AAC-LC (opus Android 29+ ister, minSdk 24)
  path_provider: ^2.1.6
  cached_network_image: ^3.4.1      # ⚠️ cacheKey = media_id (imzali URL degisse de onbellek tutar)
  background_downloader: ^9.5.7     # arka planda yukleme/indirme
  open_filex: ^4.7.0                # belge acma (ic goruntuleyici EKLEME)
  crypto: ^3.0.6                    # md5(base64) + sha256(hex)   ⚠️ surumu pub.dev'den DOGRULA
  connectivity_plus: ^6.1.0         # wifi/hucresel ayrimi        ⚠️ surumu pub.dev'den DOGRULA
```

⚠️ **Dürüst not:** `background_downloader`'ın `UploadTask`'ında **PUT + ham ikili gövde + özel başlık** üçlüsünü pub.dev dokümanından **doğrulamadım**. Tasarım buna bağımlı **değil** (§5.3): taşıma katmanı arayüz arkasında; desteklemiyorsa V1 taşıması Dio ile yapılır, arka plan devamı Android'de mevcut `AramaServisi` deseninde bir `dataSync` ön plan servisiyle, iOS'ta ise `beginBackgroundTask` penceresiyle sağlanır. **Kuyruk defteri her iki durumda da aynı.**

### 5.2 Yeni dosyalar

```
mobile/lib/features/media/
├── medya_tip.dart          MedyaTip enum, TAVANLAR (backend limits.go ile BIREBIR), mime tablosu
├── medya_kapi.dart         ⚠️ CAKISMA KAPILARI — mesgulMu + SesSahipligi sarmali (§7)
├── medya_hazirla.dart      sec -> sikistir -> kucuk resim -> md5/sha256 -> Documents'a KOPYALA
├── medya_kuyrugu.dart      KALICI KUYRUK (durum makinesi + shared_preferences defteri)
├── medya_yukleyici.dart    presign -> PUT -> commit  (tasima arayuzu)
├── medya_onbellek.dart     imzali URL alma + indirme + LRU + otomatik indirme kurallari
├── medya_ayarlari.dart     wifi/hucresel otomatik indirme ayarlari (shared_preferences)
└── medya_kayit.dart        ses notu kaydi (record) + dalga formu toplama + arama kesintisi

mobile/lib/features/chats/
├── ek_paneli.dart          alttan acilan ataç paneli
├── medya_onizleme_ekrani.dart   coklu secim + altyazi + gonder
├── medya_goruntuleyici.dart     tam ekran (kaydirmali, zoom)
└── balonlar/
    ├── foto_balonu.dart
    ├── video_balonu.dart
    ├── ses_balonu.dart
    └── belge_balonu.dart
```

### 5.3 Kuyruk — durum makinesi

**Kuyruk `Provider` (autoDispose DEĞİL, kök kapsamda).** `messagesProvider` `family.autoDispose` (`chats_provider.dart:121-123`) — sohbet kapanınca ölür; kuyruk ona bağlanamaz.

```
secildi → hazirlaniyor → beklemede → yukleniyor(0-100%) → dogrulaniyor → gonderiliyor → tamam
                                          ↓                    ↓              ↓
                                    hata_gecici ──(ustel tekrar: 2s,5s,15s,60s,180s; max 5)──┘
                                          ↓ (tukendi)
                                    hata_kalici  → kullaniciya "Tekrar dene / Sil"
   herhangi bir durumda: iptal → nesne varsa DELETE /media/upload/{id} → kayit silinir
```

**Kalıcılık — üç parça:**
1. **Defter**: `shared_preferences` (`^2.5.5`, zaten var) anahtarı `medya_kuyrugu_v1`, JSON dizi.
   Yazma **yalnız durum geçişlerinde** (ilerleme yüzdesi belleğe yazılır, diske DEĞİL) → tipik gönderimde 5-6 yazma.
2. **Dosya**: hazırlanan çıktı `<Documents>/medya_giden/<yerelId>.<uzanti>`'ye **kopyalanır**.
   ⚠️ **Kritik**: `image_picker`/sıkıştırıcı çıktısı **geçici dizindedir** ve OS onu istediği an siler. Documents kalıcıdır ve "uygulama öldürüldü, tekrar açıldı" senaryosunun tek şartıdır.
3. **`media_id`**: presign yanıtı defterde saklanır → yeniden başlatmada presign **tekrarlanmaz**, commit'ten devam edilir.

**Yeniden başlatma davranışı (`main.dart` açılışında `MedyaKuyrugu.canlandir()`):**

| Kaydedilmiş durum | Ne yapılır |
|---|---|
| `hazirlaniyor` | Dosya yoksa kayıt düşürülür + kullanıcıya bildirim; varsa baştan hazırlanır |
| `beklemede` / `yukleniyor` | `media_id` varsa **commit denenir** (nesne yüklenmiş olabilir); `409` gelirse presign yenilenir ve PUT baştan |
| `dogrulaniyor` | Doğrudan commit |
| `gonderiliyor` | `client_ref` ile POST tekrarlanır → sunucu idempotent, **çift mesaj olmaz** |

⚠️ **Dürüst sınır:** R2 tek parça PUT'ta **bayt seviyesinde devam YOKTUR**. "Kaldığı yerden" **görev seviyesindedir**: uygulama öldürülürse yarım kalan aktarım baştan başlar. Çok parçalı (multipart) yükleme bilinçli olarak yapılmadı — her `UploadPart` ayrı **Class A** ($4,50/M); 12 MB'lık videoyu 5 MB parçalara bölmek Class A maliyetini 3× yapar. **16 MB tavanında bu takas doğru.**
`background_downloader` kullanılabilirse **uygulama arka plandayken/öldürüldükten sonra bile aktarım OS tarafından sürdürülür** (iOS URLSession background, Android WorkManager) — bu, tavanın da üstünde bir kazanç.

### 5.4 Değişen dosyalar

| Dosya:satır | Değişiklik |
|---|---|
| `chats_provider.dart:77-83` | `send()` imzası: `send({String? metin, String? mediaId, MedyaTip? tip, int? replyToId, required String clientRef})`. **`await load()` KALDIRILIR** — tüm listeyi tazelemek yükleme akışında kullanılamaz; yanıttaki tam mesaj nesnesi yerel balonu değiştirir. |
| `chats_provider.dart:61-75` | `before_id`/`limit` bağlanır → yukarı kaydırma sayfalaması. Medya sohbetinde 50 mesaj sınırı çabuk vuruyor. |
| `chats_provider.dart:85-112` | `message.deleted` dalı eklenir. `message.new`'de `media` ayrıştırılır. **Kuyruktaki bekleyen öğeler listeye enjekte edilir** (negatif id). |
| `models.dart:52-85` | `Message`'a `final MedyaBilgi? media;` + `final String clientRef;` + **yalnız yerel** `YerelDurum? yerel` (durum, ilerleme, hata). |
| `chat_screen.dart:251-261` | `_Bubble` yerine `_balonSec(msg)`: `system`→`_CallLogChip` · `image`→`FotoBalonu` · `video`→`VideoBalonu` · `audio`→`SesBalonu` · `document`→`BelgeBalonu` · `location`→`KonumBalonu` · aksi→`_Bubble`. |
| `chat_screen.dart:269-303` | Giriş çubuğu: sol **ataç** (`LucideIcons.paperclip`), sağda metin boşsa **mikrofon** (`LucideIcons.mic`), doluysa **gönder** (`LucideIcons.send`). |
| `chat_screen.dart:610-674` | `_Bubble` **korunur** (metin yolu değişmez), medya balonları onun görsel dilini (yarıçap, gölge, saat+tik satırı) `_BalonKabuk` olarak paylaşır. |
| `api.dart:22-26` | `sendTimeout: 60sn` eklenir (bugün TANIMSIZ). |
| `api.dart` (yeni) | **`medyaDioProvider`** — ayrı Dio: **Authorization interceptor'ı YOK**. Presigned URL'e Bearer başlığı eklenirse **imza bozulur** (`SignatureDoesNotMatch`). |
| `api.dart:69` | `dio.addSentry()` + **`beforeBreadcrumb` maskesi**: R2 host'una giden isteklerin query string'i `?…` olarak kesilir. `sentry_dio: ^9.6.0` kurulu (`pubspec.yaml:56`) ve imzalı URL'ler üçüncü tarafa gider. |
| `chats_screen.dart:219-260` | **DOKUNULMAZ** — `_previewIkon()` ve `_preview()` medya tiplerini zaten çiziyor. Yalnız `document` satırı eklenir (`LucideIcons.fileText` + dosya adı). |

### 5.5 Balon görünümleri (Lucide, **EMOJİ YOK**)

**Fotoğraf** — `foto_balonu.dart`
```
┌───────────────────────┐
│                       │   maxWidth = ekran*0.65, en-boy KORUNUR,
│   [kucuk resim/asil]  │   min 120px, max 240px yukseklik, yaricap balonla ayni
│                       │
│              ┌──────┐ │   altyazi YOKSA: saat+tik gorselin uzerinde
│              │09:12✓│ │   yari saydam koyu hap icinde
│              └──────┘ │
├───────────────────────┤
│ Kahvaltı hazır  09:12✓│   altyazi VARSA: gorselin ALTINDA, normal metin gibi
└───────────────────────┘
```
- İndirilmemiş: küçük resim **bulanık** + ortada `LucideIcons.arrowDownToLine` halkası + **boyut etiketi** ("1,2 MB")
- Yükleniyor (gönderen): halka ilerleme + `LucideIcons.x` iptal
- Hata: `LucideIcons.rotateCw` + "Tekrar dene"
- Medya silinmiş/süresi dolmuş: `LucideIcons.imageOff` + "Bu medya artık mevcut değil"

**Video** — kapak karesi + ortada `LucideIcons.play` (dolu daire içinde) + **sol altta** `LucideIcons.clock` yerine düz süre metni `0:42`; indirilmemişse yanında boyut.

**Ses notu** — `ses_balonu.dart`
```
( AV )  [▶]  ▁▂▅▇▆▃▁▂▅▇▄▂▁▃▅▂▁   0:14   [1x]
```
- Avatar dairesi + üstünde küçük `LucideIcons.mic` rozeti (dinlenmemişse vurgulu renk, dinlenmişse `outline`)
- Oynat/duraklat: `LucideIcons.play` / `LucideIcons.pause`
- Dalga formu: **kayıt sırasında toplanan** 60 değer (`waveform` alanı), sürüklenebilir (scrubbing)
- Hız rozeti: metin `1x → 1.5x → 2x` (ikon değil)

**Belge** — yatay kart: solda tip ikonu (`fileText` / `fileSpreadsheet` / `fileArchive` / `file`), sağda dosya adı **ortadan kısaltma** (`sozlesme_2026_fin…pdf`), altında `PDF · 2,4 MB`, sağda `LucideIcons.arrowDownToLine`.
⚠️ **Dosya adı çizilirken RTL override karakterleri (`U+202E`, `U+202B`…) TEMİZLENİR.** `fatura‮gpj.exe` klasik saldırısıdır.

---

## 6. KENAR DURUMLAR

| Durum | Davranış |
|---|---|
| **Ağ koptu (yükleme ortasında)** | Kuyruk `hata_gecici` → üstel tekrar (2s,5s,15s,60s,180s). Balon: gri halka + `LucideIcons.cloudOff` + "Bekleniyor". Bağlantı gelince (`connectivity_plus` dinleyicisi) tekrar **anında** tetiklenir, beklemeden. |
| **Ağ koptu (mesaj POST'unda)** | `client_ref` ile idempotent tekrar. Sunucuda mesaj oluşmuşsa aynı satır döner — **çift balon olmaz**. |
| **Uygulama arka plana geçti** | `background_downloader` ile aktarım OS tarafında sürer. Android'de ⚠️ **arama FGS'i (`AramaServisi.kt`) aktifse ikinci ön plan servisi İSTENMEZ** — süreç zaten ayakta, ikinci FGS Android 14 tip/kota çatışması yaratır. |
| **Uygulama ÖLDÜRÜLDÜ** | Defter + Documents'taki dosya + `media_id` sayesinde açılışta §5.3 tablosuna göre devam. **Bayt seviyesinde devam yok** (dürüst sınır). Kullanıcıya "3 medya gönderiliyor" şeridi gösterilir. |
| **İzin reddedildi (kamera/mikrofon)** | Satır içi açıklama kartı + "Ayarları aç" (`permission_handler.openAppSettings()`). İkinci redde bir daha sorulmaz, düğme pasifleşir. **Galeri ve belge izin İSTEMEZ** (sistem seçici). |
| **Dosya çok büyük** | Sıkıştırma sonrası hâlâ tavanın üstündeyse: video → "Video çok uzun. 60 saniyeden kısa bir bölüm seçin." + kırpma önerisi; diğerleri → "Dosya çok büyük (en fazla 16 MB)". Sunucu ayrıca `413` ile fail-closed. |
| **Aynı dosya iki kez** | (a) Kullanıcı aynı fotoğrafı tekrar gönderiyor → `sha256` dedup, **yükleme HİÇ yapılmaz**, yeni mesaj oluşur. (b) Ağ zaman aşımı sonrası tekrar → `If-None-Match:*` PUT'ta `412` → istemci "zaten yüklü" sayar → commit. |
| **Gönderim sırasında sohbetten çıkıldı** | Kuyruk **kök kapsamlı** (`messagesProvider` gibi `autoDispose` DEĞİL) → devam eder. Sohbete geri dönüldüğünde bekleyen balonlar defterden yeniden enjekte edilir. |
| **Alıcı engelledi** | `SendMessage`'a eklenen çift yönlü blok kontrolü → `403 "bu kullanıcıya mesaj gönderilemiyor"`. Kuyruk bunu **kalıcı hata** sayar (tekrar denemez), balon "Gönderilemedi" olur, **medya nesnesi silinir** (`DELETE /media/upload/{id}` çalışmaz çünkü commit olmuş → istemci `media_id`'yi bırakır, sweeper 7 gün sonra yetim olarak temizler). |
| **Medya commit oldu ama mesaj hiç gönderilmedi** | 7 günden eski, `status='aktif'` ama hiçbir mesajda geçmeyen varlıklar gecelik sweeper tarafından silinir. |
| **Karşı taraf mesajı sildi, ben indiriyordum** | `GET /media/{id}/url` → `410` → balon "Bu medya artık mevcut değil" + yerel önbellek kaydı silinir. |
| **İmzalı URL süresi indirme ortasında doldu** | R2 aktarım başladıktan sonra kesmez; ama tekrar denemede `403` gelirse istemci **otomatik olarak yeni URL alır** (`GET /media/{id}/url`) ve indirmeyi yeniler. Bu, indirme yolunun standart hata dalıdır. |
| **Cihaz depolaması dolu** | Hazırlık aşamasında `path_provider` yazma hatası → "Cihazda yeterli alan yok" + kuyruk kalıcı hata. İndirmede aynı mesaj + önbellek LRU **zorla** çalıştırılır. |
| **Aynı anda 10 medya seçildi** | Kuyruk **eşzamanlılık 2** ile işler (hücresel ağda 10 paralel PUT hepsini yavaşlatır ve TCP tıkanıklığı yaratır). Sıra: küçük resimler önce. |

---

## 7. ⚠️⚠️ BU PROJEYE ÖZEL ÇAKIŞMA RİSKLERİ

Bu bölüm tasarımın **en kritik** parçası. Doğrulanmış zemin:

| Gerçek | Kanıt |
|---|---|
| `SesSahipligi` kaydı: `arama_*`, `oda_*`, `yayin_*` önekleri, **statik küme, proses ömürlü** | `mobile/lib/features/calls/medya_beklet.dart:29-53` |
| iOS'ta `RTCAudioSession.sharedInstance().isAudioEnabled` **PROSES GENELİNDE TEK** | `medya_beklet.dart:75-78` (kod yorumu, kaynak okunarak yazılmış) |
| iOS'ta flutter_webrtc **TEK paylaşılan `videoCapturer`** | Keşif: `AppDelegate.swift:668,737,905` — üç yerde de `sharedSingleton()?.videoCapturer` |
| Meşguliyet tek kaynak: `mesgulMu({haric, etiket, odaYayinMuaf})` | `call_provider.dart:162-198` |
| Ses birimi aktivasyonu yarışı ölçülmüş: `!pri` = `InsufficientPriority` (561017449) | `medya_beklet.dart:157-163` yorumu (turu 65 saha ölçümü) |

### 7.1 Tek kapı: `medya_kapi.dart`

⚠️ **`mesgulMu` mantığı KOPYALANMAZ, ÇAĞRILIR** (CLAUDE.md: "bu mantığı çağıran yerlere kopyalama — drift eder").

```dart
/// TEK KAYNAK. Medyanin ses/kamera birimine dokunan HER yolu bu kapidan gecer.
class MedyaKapi {
  /// Herhangi bir arama / sesli oda / canli yayin CANLI mi?
  /// ⚠️ SesSahipligi kullanilir (mesgulMu DEGIL): mesgulMu "ekrandakiAramalar"
  ///    muhafizina bakar; bize gereken sey FIILEN ACIK BIR MEDYA OTURUMU olup
  ///    olmadigi. SesSahipligi tam olarak bunu tutuyor (medya_beklet.dart:32).
  static bool get medyaOturumuVar => SesSahipligi.ozet.isNotEmpty;
}
```

### 7.2 Karar tablosu

| Medya işlemi | Arama/oda/yayın SÜRERKEN | Gerekçe |
|---|---|---|
| **Galeriden seçme** (PHPicker / Photo Picker) | ✅ **SERBEST** | Sistem sahipli modal; kamera veya ses birimi **açmaz**. Kullanıcı arama sırasında fotoğraf gönderebilmeli — WhatsApp da izin verir. |
| **Belge seçme** (SAF / Files) | ✅ **SERBEST** | Aynı gerekçe. |
| **KAMERA ile çekim** (`ImageSource.camera`) | 🔴 **ENGELLE** | iOS'ta `UIImagePickerController` kendi `AVCaptureSession`'ını açar → **tek paylaşılan `videoCapturer`**'ı çalar → turu 50 (%14 tek taraflı video) ve turu 67 (kamera teardown yarışı) hata sınıfı **birebir geri gelir**. Bu kez sohbet ekranından tetiklenir ve teşhisi çok daha zor olur. ⚠️ `mesgulMu(odaYayinMuaf: true)` **KULLANILMAZ** — duraklatma videoCapturer'ı serbest bıraksa bile yayını bozar. **FAIL-CLOSED.** UI: ataç panelinde "Kamera" öğesi soluk + altında "Görüşme sürerken kamera kullanılamaz". |
| **SES NOTU KAYDI** (`record`) | 🔴 **ENGELLE** | `record` iOS'ta `AVAudioSession.setCategory(.playAndRecord)` çağırır. Canlı VPIO biriminin **altından** kategori değişimi turu 64 (`!pri`) ve turu 65 (`didActivate` hiç gelmiyor) hatalarını üretmişti — bu ölçülmüş, tahmin değil (`medya_beklet.dart:157-163`). Android'de `record` AudioFocus alır → `AudioSwitchManager` ile çakışır (turu 62-C: ses rotası bozulması). UI: mikrofon düğmesi pasif, dokununca **"Görüşme sürerken ses notu kaydedilemez"**. |
| **SES NOTU ÇALMA** (`audioplayers`) | 🔴 **ENGELLE** | `audioplayers` her `play()`de iOS'ta `AudioContextIOS` kategorisini uygular — aynı kategori savaşı. ⚠️ Ayrıca arama zil/çalma tonu (`CallSounds`) aynı paketi kullanıyor. Balona dokununca: **"Görüşme sürerken sesli mesaj dinlenemez"**. |
| **VİDEO OYNATMA** (`video_player`) | 🔴 **ENGELLE** (fail-closed) | ⚠️ **DÜRÜST NOT: `video_player`'ın iOS eklentisinin `AVAudioSession` kategorisine dokunduğunu KAYNAKTAN DOĞRULAMADIM.** AVPlayer'ın tipik davranışı `.playback` kategorisidir ve bu canlı aramayı öldürür. Kanıtlanana kadar engelli. Eklenti kaynağı okunup kategoriye dokunmadığı kanıtlanırsa **sessiz oynatmaya** açılabilir. |
| **VİDEO SIKIŞTIRMA** (`video_compress`) | 🟡 **KUYRUKTA BEKLET** | `AVAssetExportSession` / `MediaCodec` **donanım kodlayıcıyı** kullanır. iPhone'da tek donanım H.264 kodlayıcı var ve WebRTC de onu kullanıyor → arama video kalitesi düşer/fps çakılır. Ses/kamera birimine dokunmadığı için tehlikeli değil ama **gereksiz rekabet**. Karar: sıkıştırma işi kuyrukta bekletilir, `SesSahipligi` boşalınca çalışır. Kullanıcıya balon "Bekleniyor" gösterir. |
| **Görsel sıkıştırma** (`flutter_image_compress`) | ✅ **SERBEST** | CPU/GPU, medya birimi yok. |
| **YÜKLEME / İNDİRME** (ağ I/O) | ✅ **SERBEST** | Ses/kamera birimine dokunmaz. ⚠️ **Android istisnası**: `background_downloader`'ın kendi ön plan servisi **istenmez** çünkü `AramaServisi.kt` (`foregroundServiceType="microphone|camera"`) zaten süreci ayakta tutuyor; ikinci FGS Android 14 tip/kota çatışması riski. Kod: `MedyaKapi.medyaOturumuVar` ise `foregroundOnAndroid=false`. |
| **KONUM** (`geolocator`) | ✅ **SERBEST** | GPS ayrı donanım. (Arka plan canlı konum ayrı iş — 3. dalga.) |

### 7.3 Ters yön: **medya işi sürerken arama gelirse**

Bu, keşifte hiç ele alınmamış ama gerçek bir delik.

| Senaryo | Çözüm |
|---|---|
| **Ses notu kaydı sürerken arama geliyor** | `MedyaKayit.aramaGeldi()` çağrılır → kayıt **durdurulur ve TASLAK olarak saklanır** (silinmez!), giriş çubuğunda "Kaydedilen ses notu · Gönder / Sil" şeridi olarak durur. Çağrı noktaları: `call_provider._onEvent` `call.incoming` dalı (`call_provider.dart:206`) **ve** `CallKitService` gelen-arama yolu (iOS'ta WS `call.incoming` `Platform.isIOS` ile atlanıyor — `call_provider.dart:211`, bu yüzden **iki kapı da şart**). ⚠️ Tek kapıya bağlarsan iPhone'da hiç çalışmaz. |
| **Ses notu çalarken arama geliyor** | Aynı kanca; oynatma duraklatılır, konum korunur ("kaldığı yerden devam"). |
| **Video oynatılırken arama geliyor** | Aynı kanca; duraklatılır. |
| **Kamera önizlemesi (medya) açıkken arama geliyor** | Kamera zaten §7.2 ile açılamıyor → bu durum **yapısal olarak imkânsız**. |
| **Yükleme sürerken arama geliyor** | Devam eder (ağ I/O). Android FGS bayrağı canlı olarak `false`'a çekilir. |

⚠️ **YAPMA:** `MedyaKayit`'i `SesSahipligi`'ye kaydetme. O küme `mesgulMu` tarafından okunuyor (`call_provider.dart:185`) ve bir ses notu kaydı yüzünden kullanıcı **arama alamaz/yapamaz** hale gelir.

---

## 8. OTOMATİK İNDİRME, ÖNBELLEK, TEMİZLİK

### 8.1 Otomatik indirme kuralları (varsayılanlar)

| | Küçük resim | Fotoğraf | Ses notu | Video | Belge |
|---|---|---|---|---|---|
| **Wi-Fi** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Hücresel** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Bağlantı yok** | — | — | — | — | — |

Ayarlar ekranında değiştirilebilir (`medya_ayarlari.dart`, `shared_preferences`).
Küçük resim **her zaman** indirilir (≤20 KB) — balonun boş görünmemesi için.

⚠️ **Dolaşım (roaming) tespiti YOK.** `connectivity_plus` yalnız wifi/mobile/none ayrımı verir. Keşifteki "dolaşımda hiçbiri" kuralı **V1'de uygulanamaz**; ayarlarda "Dolaşımda indirme" seçeneği **gösterilmez** (yalan vaat etmemek için). Faz 2.

### 8.2 Yerel önbellek

| Ne | Nerede | Ömür |
|---|---|---|
| Küçük resimler | `cached_network_image` kendi disk önbelleği, **`cacheKey: media_id`** | paketin LRU'su |
| İndirilen asıl medya | `<Application **Cache** Dir>/medya/<media_id>.<uzanti>` | LRU + 30 gün |
| **Giden** (henüz gönderilmemiş) | `<Application **Documents** Dir>/medya_giden/<yerelId>.<uzanti>` | gönderim başarılı olunca **hemen silinir** |

⚠️ **Cache vs Documents ayrımı kritiktir**: Cache dizinini OS temizleyebilir (indirilen medya için doğru — sunucudan tekrar alınır); Documents temizlenmez (gönderilmemiş iş için **zorunlu**).

**Temizlik (`MedyaOnbellek.temizle()`)** — uygulama açılışında + her 20 indirmede bir:
1. 30 günden eski dosyalar silinir
2. Toplam > **500 MB** ise en eski erişilenden başlayarak (LRU) 400 MB'a inene kadar silinir
3. DB'de karşılığı olmayan (`410` almış) dosyalar silinir

Ayarlarda "Depolama": toplam boyut + "Önbelleği temizle" düğmesi (`LucideIcons.trash2`).

### 8.3 Sunucu tarafı temizlik — `media.StartSweeper(ctx)`

`main.go:86-94`'teki `roomsH.StartSweeper` / `streamsH.StartSweeper` desenine birebir.

| Süre | İş |
|---|---|
| 10 dakikada bir | `status='gecici' AND created_at < now()-1 saat` → `DeleteObject` + `status='reddedildi'` |
| Gecelik | `status='aktif' AND committed_at < now()-7 gün AND NOT EXISTS(mesaj)` → yetim, silinir |
| Gecelik | `media_delete_queue` işlenir (`tries<10`, üstel aralık) |
| Gecelik | `status='aktif' AND committed_at < now()-365 gün` → silinir (mesaj kalır, balon "artık mevcut değil") |

⚠️ **R2 lifecycle kuralı KULLANILMIYOR** (§0.2-A). Lifecycle DB ile senkron değildir ve 24 saat gecikmelidir; sweeper hem nesneyi hem satırı **aynı anda** doğru duruma getirir.

---

## 9. GÜVENLİK ÖZETİ (bu tasarımın kapattıkları)

| Açık | Kapanış |
|---|---|
| `media_url` istemciden, doğrulanmadan (`handler.go:169-171`) — IP sızdıran izleme pikseli, oltalama | `media_url` API'den **kaldırıldı**; URL sunucuda türetiliyor |
| Beyaz liste yalnız `type` için, dosya içeriği hiç bakılmıyor | Sihirli bayt + boyut + EXIF/GPS doğrulaması (commit) |
| SVG/HTML ile admin paneli XSS'i (`/admin/izle` + `ADMIN_KEY`) | SVG/HTML/JS **kesin yasak** + medya **`api.gebzem.app` üzerinden ASLA sunulmuyor** (ayrı R2 host) + `nosniff` |
| Blok fiilen yok (`SendMessage`'da kontrol yok) | `SendMessage`'a çift yönlü blok kontrolü |
| Hız sınırı yok | Redis Lua kota + yeni hesap sıkı limiti |
| Gövde boyutu sınırı yok (`main.go:96-102`) | `middleware.RequestSize(1 MB)` |
| İçerik kaldırma yolu yok (`deleted_for_all` ölü kod) | `DELETE /chats/{id}/messages/{mid}` + R2 silme + WS |
| Push önizlemesinde bozuk UTF-8 (`handler.go:207-209`) | `[]rune` kesme |
| İmzalı URL'ler Sentry'e gidiyor (`sentry_dio` kurulu) | `beforeBreadcrumb` query maskesi |

⚠️ **Bu tasarımın KAPSAMADIKLARI (dürüst liste):** CSAM taraması (PhotoDNA başvurusu ayrı iş, vetting süresi belirsiz), şikayet/moderasyon kuyruğu, admin medya arama ekranı, 5651 trafik/erişim logu, BTK bildirimi, KVKK metinleri. Bunlar **yayın öncesi zorunlu** ama bu turun konusu değil.

---

## 10. TEST SENARYOLARI (kullanıcının elle yapacağı)

### A — Temel gönderim
1. Sohbet aç → ataç → **Galeri** → 1 fotoğraf seç → altyazı yaz → Gönder. Balon **anında** görünmeli, halka dolmalı, tik çıkmalı.
2. Karşı cihazda balon ve altyazı görünmeli; küçük resim **hemen**, asıl otomatik indirilmeli.
3. Sohbet listesinde önizleme: `LucideIcons.image` + **"Fotoğraf"** yazmalı.
4. Kilitli telefonda push: **"Ahmet: Fotoğraf"**.
5. Aynı fotoğrafı **tekrar** gönder → yükleme çubuğu neredeyse anında bitmeli (dedup), yeni balon oluşmalı.

### B — Çoklu ve büyük
6. 5 fotoğraf birden seç → hepsi kuyrukta, ikişer ikişer yüklenmeli, sıra karışmamalı.
7. 60 sn'den uzun bir video seç → **"Video çok uzun"** uyarısı.
8. 1080p 30 sn video gönder → sıkıştırılıp 16 MB altına inmeli, karşı tarafta oynamalı.

### C — Ses notu
9. Mikrofonu **basılı tut** → titreşim + sayaç + canlı dalga. Bırak → gönderilsin.
10. Kayıt sırasında **sola kaydır** → iptal, hiçbir şey gönderilmemeli.
11. **Yukarı kaydır** → kilit, "Durdur/Gönder" düğmeleri çıkmalı.
12. Karşı tarafta ses notu balonu: dalga formu **kayıttaki sesle uyumlu** görünmeli; 1x→1.5x→2x çalışmalı.
13. Yarım dinle → başka sohbete geç → dön → **kaldığı yerden** devam etmeli.

### D — Ağ / kesinti
14. **Uçak modunu aç**, fotoğraf gönder → "Bekleniyor". Uçak modunu kapat → **kendiliğinden** gönderilmeli (dokunmadan).
15. Yükleme %50'deyken **uygulamayı öldür** (app switcher'dan yukarı at) → tekrar aç → gönderim devam etmeli/yeniden başlamalı, **çift mesaj OLMAMALI**.
16. Yükleme sürerken **sohbetten çık**, başka sohbete git → yükleme devam etmeli, geri dönünce balon tamamlanmış olmalı.
17. Yükleme %70'te **iptal (X)** → balon kaybolmalı, karşı tarafa hiçbir şey gitmemeli.

### E — ⚠️ ÇAKIŞMA TESTLERİ (en kritik bölüm)
18. **Görüntülü arama başlat** → küçült → sohbete git → ataç aç. **"Kamera" öğesi PASİF** olmalı ve dokununca *"Görüşme sürerken kamera kullanılamaz"* demeli.
19. Aynı durumda **mikrofon düğmesi PASİF** olmalı: *"Görüşme sürerken ses notu kaydedilemez"*.
20. Aynı durumda **Galeri'den fotoğraf gönder** → sorunsuz gitmeli **ve aramanın sesi/görüntüsü BOZULMAMALI** (en önemli test).
21. Aynı durumda bir **ses notu balonuna dokun** → çalmamalı, açıklama vermeli. Arama bitince aynı balon çalmalı.
22. **Sesli oda**ya gir → aynı 18-21 adımları. Sonra **canlı yayın** başlat → aynı adımlar.
23. **Ses notu kaydederken karşıdan arama geldir** → kayıt durmalı, **taslak olarak durmalı** (silinmemeli), aramayı reddedince gönderilebilmeli.
24. Fotoğraf yüklenirken arama geldir → arama kurulmalı, yükleme **devam etmeli**.

### F — Otomatik indirme / önbellek
25. Ayarlar → hücresel için "Video" kapalıyken hücresel ağda video gelsin → **indirme halkası** görünmeli, otomatik inmemeli. Dokununca inmeli.
26. Wi-Fi'ye geç → yeni gelen video **otomatik** inmeli.
27. Ayarlar → Depolama → boyut görünmeli; "Önbelleği temizle" sonrası medyalar tekrar indirme durumuna dönmeli (mesajlar kaybolmamalı).

### G — Silme ve yetki
28. Kendi medya mesajına uzun bas → **"Herkesten sil"** → iki tarafta da "Bu mesaj silindi" olmalı.
29. Silinen medyanın URL'i (varsa daha önce alınmış) artık **çalışmamalı**.
30. Karşı tarafın mesajını silmeye çalış → seçenek çıkmamalı.
31. Bir kullanıcıyı engelle → ona medya göndermeyi dene → **"bu kullanıcıya mesaj gönderilemiyor"**.

### H — İzin ve kenar
32. Kamera iznini **reddet** → satır içi açıklama + "Ayarları aç".
33. Galeri seçiminde iOS'ta **"Seçili fotoğraflar"** ile devam et → çalışmalı.
34. Belge gönder (PDF) → karşı tarafta ad + boyut kartı, dokununca sistem görüntüleyicide açılmalı.
35. Adı çok uzun bir dosya gönder → balonda **ortadan kısaltılmış** görünmeli, taşmamalı.

---

## 11. UYGULAMA SIRASI (bağımlılık zinciri)

| # | İş | Bağımlılık | Yayınlanabilir mi? |
|---|---|---|---|
| 1 | `014_media.sql` + `config.go` env + `internal/media/` (sigv4, r2, sniff, limits, handler, sweeper) | — | Backend tek başına deploy edilebilir; istemci görmez |
| 2 | `chat/handler.go` değişiklikleri (media_id, client_ref, blok, preview fix, DELETE ucu) + `main.go` route'lar | 1 | Eski istemci **bozulmaz** (doğrulandı: `media_url` göndermiyor) |
| 3 | Cloudflare: `gebzem-media` bucket'ına CORS **gerekmez** (native istemci), yalnız erişim anahtarı doğrulaması | 1 | — |
| 4 | Flutter paketleri + `medya_tip` + `medya_kapi` + `medya_hazirla` + `medya_kuyrugu` + `medya_yukleyici` | 2 | — |
| 5 | Fotoğraf ucu uçtan uca (ataç → önizleme → balon → indirme → görüntüleyici) | 4 | **İLK TEST TURU** |
| 6 | Ses notu (`record` + dalga + `MedyaKayit` arama kancaları) | 5 | İkinci tur |
| 7 | Video (`video_compress` + `video_player` + kuyrukta bekletme) | 5 | Üçüncü tur |
| 8 | Belge (+ opsiyonel CHECK ALTER) | 5 | Dördüncü tur |

⚠️ **Adım 5'ten önce test turu ALMA.** Fotoğraf yolu tek başına presign+commit+kuyruk+önbellek+silme zincirinin **tamamını** kanıtlar; ses/video/belge aynı zincire takılan dallardır. Hepsini tek turda yayınlamak, bir hata çıktığında hangi katmanın bozuk olduğunu ayırt etmeyi imkânsızlaştırır — CLAUDE.md'deki 70 turluk teşhis geçmişinin ana dersi budur.