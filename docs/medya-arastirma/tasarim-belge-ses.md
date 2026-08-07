# GEBZEM — BELGE PAYLAŞIMI + SESLİ MESAJ (SES NOTU) MÜHENDİSLİK TASARIMI

Tüm iddialar kaynaktan doğrulandı. Keşif çıktılarıyla **iki noktada çeliştim**, ikisi de aşağıda açıkça işaretli.

---

## 0. ZEMİN — KENDİ DOĞRULAMAM (keşifle çelişkiler dahil)

| İddia | Durum | Kanıt (dosya:satır) |
|---|---|---|
| Tip beyaz listesi `text,image,video,audio,location`; `system` dışarıda | ✅ | `backend/internal/chat/handler.go:152-157` |
| DB CHECK `('text','image','video','audio','location','system')` | ✅ | `backend/internal/database/migrations/001_init.sql:55` |
| `media_url` istemciden geliyor, **hiç doğrulanmıyor** | ✅ | `chat/handler.go:128` → `:169-171` (ham INSERT) |
| `SendMessage`'da engel kontrolü YOK (satır 159'daki yorum yanlış) | ✅ | `chat/handler.go:159-164`, `chatMemberIDs` `:409-431` sadece üyelik bakıyor |
| Son migration 013 | ✅ | `migrations/013_call_hold.sql` → yeni iş **014** |
| Migration çalıştırıcısı: dosya adına göre `sort.Strings`, çok ifadeli SQL tek `Exec` | ✅ | `internal/database/database.go:28-72` — argümansız `Exec` ⇒ **basit protokol ⇒ örtük tek transaction**, migration atomik |
| `_Bubble` tip ayrımı yapmıyor, koşulsuz `Text(content)` | ✅ | `chat_screen.dart:652` |
| Ataç butonu yok (yalnız yer tutucu yorum) | ✅ | `chat_screen.dart:291` |
| `chats_screen` önizlemesi `audio` → "Sesli mesaj" ZATEN hazır | ✅ | `chats_screen.dart:225` (ikon `LucideIcons.mic`), `:245` (metin) |
| Flutter'da medya paketi yok | ✅ | `pubspec.yaml:30-68` |
| iOS ses birimi **proses geneli** manuel mod | ✅ | `ios/Runner/AppDelegate.swift:32-33` `useManualAudio=true`, `isAudioEnabled=false` |
| `SesSahipligi` defteri (`arama_`/`oda_`/`yayin_`) mevcut | ✅ | `mobile/lib/features/calls/medya_beklet.dart:29-53` |
| `iosSesBirimiAc` merdiveni mevcut | ✅ | `medya_beklet.dart:155-185` |
| `SesSahipligi.kaydol("arama_$id")` **çalar fazı dahil** `baslat()` içinde | ✅ | `active_call_controller.dart:1348` (bir üstü `_svc.ekranAcildi(id)` — "calar fazi dahil") |

### ÇELİŞKİ 1 — Keşif "medya izin gerektirir" varsaymış; **bu iki özellik SIFIR yeni izin istiyor**
- `RECORD_AUDIO` **zaten var**: `android/app/src/main/AndroidManifest.xml:4`
- `NSMicrophoneUsageDescription` **zaten var**: `ios/Runner/Info.plist:61-62`
- Belge seçimi sistem seçicisiyle (SAF / `UIDocumentPickerViewController`) → **hiçbir platformda izin yok**.
> **Sonuç: bu tasarım `Info.plist`'e ve `AndroidManifest.xml`'e TEK SATIR eklemez.** Tur 34-36'da kayıt akışını patlatan "izin diyaloğu çakışması" riski bu iki özellikte **yapısal olarak yok**.

### ÇELİŞKİ 2 — `record` paketinin iOS ses oturumu **kapatılamıyor** (keşifte "gate koy" denmiş ama sebebi eksik)
`IosRecordConfig` API'sinde **`manageAudioSession` diye bir alan YOK**; yalnız `categoryOptions` ve `allowHapticsAndSystemSoundsDuringRecording` var ([record_platform_interface 2.1.0 API](https://pub.dev/documentation/record_platform_interface/latest/record_platform_interface/IosRecordConfig-class.html)). Yani **`record` her kayıtta `AVAudioSession.setCategory` yazar ve bunu engelleyemeyiz.** Paketin kendi README'si de uyarıyor: *"If using other audio plugins (particularly VoIP/WebRTC solutions), verify there are no conflicts."*
Ayrıca `audioplayers` **iOS'ta ses bağlamını GLOBAL uygular**: v4.0.0 changelog — *"set player context globally on `setAudioContext` for iOS only"*.
→ Bölüm 7'deki **sert kapı** bir tercih değil, **zorunluluk**.

---

## 1. KULLANICI AKIŞI (dokunuştan karşı tarafta görünmeye)

### 1.A BELGE — gönderme
1. Sohbet ekranı, giriş çubuğunun **solunda** `LucideIcons.paperclip`.
2. Dokun → alttan panel (`showModalBottomSheet`): tek satır **"Belge"** (`LucideIcons.fileText`). (Fotoğraf/Video/Konum satırları sonraki fazlarda aynı panele eklenir.)
3. `FilePicker.platform.pickFiles(allowMultiple: false, withData: false, withReadStream: false)`
   ⚠️ **`withData: false` ZORUNLU** — `true` 25 MB'ı RAM'e alır, cx33 değil telefon patlar (LiveKit + PiP ile aynı süreç).
4. **İstemci kapısı** (sunucuya gitmeden):
   - Uzantı kara listede mi → *"Bu dosya türü gönderilemez."*
   - `> 25 MB` → *"Dosya 25 MB'den büyük olamaz (seçilen: 41,2 MB)."*
5. **Onay sayfası** (küçük `Dialog`): tür ikonu + dosya adı + boyut + `TextField` "Açıklama ekle" + **Gönder**.
6. **Gönder** → mesaj balonu **ANINDA** listeye düşer (`id: -<epochMs>`, `yerel: true`, `ilerleme: 0`) ve zincir başlar:
   `POST /media/upload` → `PUT <presigned>` (ilerlemeli) → `POST /media/{id}/commit` → `POST /chats/{id}/messages`
7. Sunucu yanıtı gelince yerel balon gerçek mesajla değiştirilir (`id` pozitif olur).
8. Karşı taraf **WS `message.new`** ile balonu anında görür — **indirilmemiş** halde (ok ikonu + boyut).

### 1.B BELGE — alma/açma
1. Balonda `LucideIcons.arrowDownToLine`. Dokun → `GET /media/{id}/url` → presigned GET → `dio.download(...)` → `<cache>/gebzem/medya/<media_id>.pdf`
2. İnerken: halka ilerleme + `LucideIcons.x` (iptal).
3. Bitince ikon kaybolur; balona dokunmak `OpenFilex.open(yol)` çağırır (iOS Quick Look / Android sistem seçici).
4. Sonraki dokunuşlarda **dosya diskte** → URL bile istenmez, doğrudan açılır.

### 1.C SES NOTU — kayıt
1. Metin alanı **boşken** sağdaki FAB `LucideIcons.mic`; metin girilince `LucideIcons.send` (WhatsApp deseni).
2. **Basılı tut** (`LongPressGestureRecognizer(duration: 200ms)` — varsayılan 500 ms çok yavaş hissettiriyor):
   - **KAPI**: `SesKapisi.engelSebebi()` doluysa **hiç başlamaz**, SnackBar (Bölüm 7).
   - Mikrofon izni: `permission_handler` (`record.hasPermission()` DEĞİL — projede tek kaynak `permission_handler`).
   - 30 ms titreşim (`vibration` zaten bağımlı) + kayıt başlar.
3. Giriş çubuğu yerini **kayıt şeridine** bırakır:
   `[kırmızı yanıp sönen nokta] 0:03  │ ~~~canlı dalga~~~ │  ← İptal için kaydırın   [trash2]`
4. **Sola kaydır** (`dx < -80`) → iptal: titreşim + dosya silinir + şerit kapanır.
5. **Yukarı kaydır** (`dy < -70`) → **kilit**: şerit değişir → `[Durdur] [Dinle] [Sil] [Gönder]`, parmak kalkabilir.
6. Bırakınca (kilitsiz): `stop()` → süre `< 1 sn` ise **gönderilmez**, *"Sesli mesaj için basılı tutun."*
7. Dalga formu 48 kovaya indirgenir, upload zinciri (1.A/6 ile **aynı**) → `type: 'audio'`.

### 1.D SES NOTU — dinleme
1. Balonda `LucideIcons.play`. İlk dokunuş: indirmediyse **indirir sonra çalar** (tek dokunuş, kullanıcı fark etmez).
2. Oynarken dalga çubukları soldan sağa dolar; **sürüklenebilir** (scrubbing).
3. Sağdaki hız rozeti: `1x → 1.5x → 2x` döngüsü (`AudioPlayer.setPlaybackRate`).
4. İlk oynatmada `POST /chats/{chatID}/messages/{id}/played` → gönderende mikrofon rozeti **maviye** döner.
5. Yarım bırakıp çıkılırsa **kaldığı yerden** devam (pozisyon bellekte, mesaj id başına).

---

## 2. BACKEND — UÇLAR VE DEĞİŞECEK DOSYALAR

### 2.1 YENİ PAKET: `backend/internal/media/`

| Dosya | İçerik |
|---|---|
| `sigv4.go` | AWS SigV4 **query-string** imzalama (presigned PUT/GET). `crypto/hmac`+`crypto/sha256` — **yeni go.mod bağımlılığı YOK**. Referans desen: `scratchpad/r2put.js` (kDate/kRegion(`auto`)/kService(`s3`)/kSigning) |
| `r2.go` | `HeadObject`, `DeleteObject` (SigV4 **header** imzası, `net/http`) |
| `limits.go` | Tip/uzantı beyaz listesi, boyut tavanları, MIME haritası |
| `kota.go` | Redis Lua (atomik saatlik/günlük/aylık-bayt) |
| `handler.go` | 3 uç + `StartSweeper` |

**Presigned PUT — kanonik istek (birebir):**
```
PUT
/gebzem-media/m/doc/2026/08/07/9f3c1a7e-4b2d-4c88-a1f0-5d7e2b9c4a13
X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=<AK>%2F20260807%2Fauto%2Fs3%2Faws4_request
  &X-Amz-Date=20260807T101500Z&X-Amz-Expires=300&X-Amz-SignedHeaders=content-type%3Bhost
content-type:application/octet-stream
host:<hesap>.r2.cloudflarestorage.com

content-type;host
UNSIGNED-PAYLOAD
```
- ⚠️ **`content-type` imzaya DAHİL** — istemci farklı gönderirse R2 `403 SignatureDoesNotMatch` verir ([R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)).
- ⚠️ **`content-length` İMZALANMAZ.** R2'de `content-length-range` (POST policy) **yok**; `content-length` imzalamanın dayattığı belgelenmemiş. Boyut **commit'te `HeadObject` ile** dayatılır.
- ⚠️ **`If-None-Match: *` KULLANILMIYOR** — güvenlik keşfi "tek kullanımlık olsun" diye önermişti; **reddediyorum**: mobil şebekede asıl sorun yarıda kalan yüklemenin **tekrar denenmesi**dir ve `If-None-Match` bunu öldürür. Tek-kullanım güvencesi bunun yerine **`media_assets.status` durum makinesi** ile sağlanır (`bagli` olan varlığa ikinci mesaj bağlanamaz — 2.2'deki `UPDATE ... WHERE status='hazir'`).

**⚠️ TÜM NESNELER `Content-Type: application/octet-stream` VE UZANTISIZ SAKLANIR.**
Gerçek MIME **yalnız DB'de** (`media_assets.mime`). Gerekçe: hiçbir tarayıcı/WebView bu nesneleri **asla render edemez** → SVG/HTML polyglot, `.exe` indirme tuzağı ve admin panelinden XSS sınıfı **yapısal olarak kapanır**. Yerel önbellek dosyasına doğru uzantıyı istemci verir.

**Anahtar düzeni:** `m/<doc|aud>/<yyyy>/<mm>/<dd>/<uuid>`
- Kullanıcı/sohbet/telefon **anahtarta YOK** (anahtar sızsa bile kimin kiminle konuştuğu anlaşılmaz).
- Orijinal dosya adı **anahtarta YOK** (DB'de).
- ⚠️ **Keşiften ayrıldığım nokta:** güvenlik keşfi `gecici/` → `medya/` **taşıma** öneriyordu. **Yapmıyorum**: `CopyObject` fazladan bir Class A + büyük nesnede risk; anahtar **baştan nihai**, yetim temizliği **DB güdümlü sweeper** ile (`DeleteObject` **ücretsiz**).

---

### 2.2 UÇLAR

#### `POST /media/upload` (Bearer)
```jsonc
// istek
{ "kind":"document",              // "document" | "audio"
  "mime":"application/pdf",
  "file_name":"sozlesme_2026.pdf", // yalnız document
  "bytes":2415616,
  "sha256":"a1b2...",              // ⚠️ İSTEMCİ BEYANI — güvenlik değil, ileride dedup/moderasyon
  "duration_ms":0,                 // yalnız audio
  "waveform":"",                   // yalnız audio: base64(48 bayt, 0..100)
  "upload_id":null }               // DOLU ise: mevcut 'beklemede' satır icin TAZE URL (tekrar deneme)
// yanıt 201
{ "upload_id":"5f2c...","put_url":"https://<hesap>.r2.cloudflarestorage.com/...&X-Amz-Signature=...",
  "content_type":"application/octet-stream","expires_in":300 }
```
Hatalar: `400` *"geçersiz istek"* · `413` *"Dosya çok büyük (en fazla 25 MB)"* · `415` *"Bu dosya türü gönderilemez"* · `429` *"Çok hızlı gönderiyorsunuz"* · `503` *"Medya servisi kapalı"*

#### `POST /media/{id}/commit` (Bearer, **yalnız sahibi**)
Sunucu sırasıyla:
1. `HeadObject(key)` → gerçek `Content-Length` + `ETag`
2. `boyut != beyan` **veya** `boyut > tavan` → `DeleteObject` + `400 "Dosya doğrulanamadı"` + Sentry
3. `UPDATE media_assets SET status='hazir', bytes=<gerçek> WHERE id=$1 AND owner_id=$2 AND status='beklemede'`
```jsonc
// yanıt 200
{ "id":"5f2c...","kind":"document","mime":"application/pdf",
  "file_name":"sozlesme_2026.pdf","bytes":2415616,"duration_ms":0,"waveform":"" }
```
Hatalar: `404` · `409 "Yükleme tamamlanmamış"` (HeadObject 404) · `400` · `413`

#### `GET /media/{id}/url` (Bearer, **üyelik kontrollü**)
```sql
SELECT ma.object_key, ma.mime, ma.file_name, ma.status
FROM media_assets ma
WHERE ma.id=$1
  AND ma.status IN ('hazir','bagli')
  AND ( ma.owner_id=$2
        OR EXISTS (SELECT 1 FROM messages m
                   JOIN chat_members cm ON cm.chat_id=m.chat_id AND cm.user_id=$2
                   WHERE m.media_id=ma.id AND NOT m.deleted_for_all) )
```
→ `200 {"url":"<presigned GET, 600 sn>","expires_at":"..."}` · `403` · `404` · `410 "Bu içerik kaldırıldı"`
> **Bu, "capability URL" açığını kapatan asıl kapıdır**: özel bucket + gerçek yetkilendirme + 10 dk TTL. İstemci dosyayı **diske önbelleğe alır**, yani cihaz başına dosya başına **tek** GET → CDN'siz olmanın maliyeti yok.

#### `POST /chats/{chatID}/messages` — **DEĞİŞİYOR** (`chat/handler.go:125-214`)
```go
// handler.go:125-130 -> YENI
type sendMessageReq struct {
	Type      string  `json:"type"`
	Content   string  `json:"content"`
	MediaID   *string `json:"media_id"`   // YENI
	ReplyToID *int64  `json:"reply_to_id"`
	// MediaURL KALDIRILDI — 🔴 istemci artik URL YAZAMAZ (SSRF/oltalama/izleme pikseli)
}
```
- `handler.go:152-157` beyaz listeye **`"document"` eklenir**. ⚠️ **`system` EKLENMEZ** (turu 59b kimlik taklidi açığı).
- `handler.go:160`'dan **ÖNCE engel kontrolü** (bugün YOK — bu açık burada kapanır):
```go
var engelli bool
h.db.QueryRow(r.Context(), `
  SELECT EXISTS(SELECT 1 FROM blocks b
    JOIN chat_members cm ON cm.chat_id=$1 AND cm.user_id=b.blocker_id
    WHERE (b.blocker_id<>$2 AND b.blocked_id=$2) OR (b.blocker_id=$2 AND b.blocked_id=cm.user_id))`,
  chatID, userID).Scan(&engelli)
if engelli { httpErr(w, http.StatusForbidden, "bu kullanıcıya mesaj gönderilemiyor"); return }
```
- Medya bağlama (**tek transaction**, `handler.go:168` yerine):
```go
tx, _ := h.db.Begin(r.Context()); defer tx.Rollback(r.Context())
var mediaID *string
if req.MediaID != nil {
    // ⚠️ TEK KULLANIM: 'hazir' -> 'bagli'. Ikinci mesaj ayni varliga BAGLANAMAZ.
    ct, err := tx.Exec(r.Context(),
      `UPDATE media_assets SET status='bagli'
       WHERE id=$1 AND owner_id=$2 AND status='hazir'`, *req.MediaID, userID)
    if err != nil || ct.RowsAffected() == 0 {
        httpErr(w, http.StatusBadRequest, "medya bulunamadı veya zaten kullanıldı"); return
    }
    mediaID = req.MediaID
}
err = tx.QueryRow(r.Context(), `
  INSERT INTO messages (chat_id, sender_id, type, content, media_id, reply_to_id)
  VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, created_at`, ...).Scan(&msgID,&createdAt)
tx.Commit(r.Context())
```
- ⚠️ **Tip↔medya tutarlılığı** (`document`/`audio` → `media_id` zorunlu; `text` → yasak):
```go
if (req.Type=="document" || req.Type=="audio") && req.MediaID==nil {
    httpErr(w, http.StatusBadRequest, "medya eksik"); return }
if req.Type=="text" && req.MediaID!=nil {
    httpErr(w, http.StatusBadRequest, "geçersiz istek"); return }
```
Ayrıca `media_assets.kind` ile `messages.type` eşleşmeli (`document↔document`, `audio↔audio`) — `UPDATE`'e `AND kind=$3` eklenir.
- **Push önizlemesi** (`handler.go:197-209`) genişler + 🔴 **UTF-8 kesme hatası düzeltilir**:
```go
case "audio":    preview = "Sesli mesaj"          // ZATEN VAR
case "document": preview = belgeAdi               // media_assets.file_name
...
if r := []rune(preview); len(r) > 80 { preview = string(r[:80]) }  // eskiden preview[:80] -> BOZUK UTF-8
```

#### `POST /chats/{chatID}/messages/{id}/played` (Bearer) — **YENİ**
```sql
UPDATE message_receipts SET played_at=now()
WHERE message_id=$1 AND user_id=$2 AND played_at IS NULL
```
Sonra göndereni bulup WS `receipt.played` yayınlar (`To: [sender_id]`). `RowsAffected()==0` ise **WS yayını YAPILMAZ** (tekrar dokunuşlarda gürültü olmasın).
→ `200 {"ok":true}` · `403` (üye değil) · `404`

#### `GET /chats/{chatID}/messages` — `chat/handler.go:234-265` genişler
```sql
SELECT m.id, m.sender_id, m.type,
       CASE WHEN m.deleted_for_all THEN '' ELSE m.content END,
       m.reply_to_id, m.deleted_for_all, m.created_at,
       CASE WHEN m.deleted_for_all THEN NULL ELSE m.media_id END,     -- ⚠️ silinmiste medya da DUSER
       ma.kind, ma.mime, ma.file_name, ma.bytes, ma.duration_ms, ma.waveform, ma.status,
       (SELECT MIN(mr.played_at) IS NOT NULL FROM message_receipts mr
        WHERE mr.message_id=m.id AND mr.user_id<>$4) AS played        -- gonderen icin "dinlendi"
FROM messages m
LEFT JOIN media_assets ma ON ma.id = m.media_id AND NOT m.deleted_for_all
WHERE m.chat_id=$1 AND m.id<$2 ORDER BY m.id DESC LIMIT $3
```
⚠️ `media_url` alanı JSON'da **boş string olarak KALIR** (eski istemci `Message.fromJson` kırılmasın); yeni istemci `media` nesnesini kullanır.

#### Router (`cmd/api/main.go:145-210` korumalı grup)
```go
r.Post("/media/upload", mediaH.Upload)
r.Post("/media/{id}/commit", mediaH.Commit)
r.Get("/media/{id}/url", mediaH.SignedURL)
r.Post("/chats/{chatID}/messages/{id}/played", chatH.MarkPlayed)
```
- `main.go:76` → `chatH := chat.NewHandler(db, hub, pushSender)` **değişmez**.
- `main.go:90` civarına: `mediaH := media.NewHandler(db, rdb, cfg)` + `if mediaH.Enabled() { log.Println("medya (R2): aktif"); mediaH.StartSweeper(ctx) } else { log.Println("medya: R2_* env yok — kapali") }`
- ⚠️ **`api.dart:52-57` 401 muafiyet listesine `/media/` EKLENMEZ** — normal 401 davranışı doğru.
- ⚠️ **Gövde boyutu sınırı**: `main.go:97` zincirine `r.Use(middleware.RequestSize(1 << 20))` (1 MB). Presign/commit JSON'ları küçük; dosya zaten API'den geçmiyor.

#### `config.Load()` (`internal/config/config.go`) — yeni alanlar
`R2Endpoint`, `R2Bucket`, `R2AccessKey`, `R2Secret` (env: `R2_ENDPOINT`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`).
⚠️ **FAIL-CLOSED**: herhangi biri boşsa `Enabled()==false`, uçlar `503` döner. Fallback anahtar **YASAK** (repo PUBLIC). `.env.infra` ve `backend/.env` git'e **girmez**.

---

### 2.3 SINIRLAR VE KOTALAR

| | Tavan | Gerekçe |
|---|---|---|
| Belge | **25 MB** | cx33'ten geçmiyor ama R2 depolama ücretli; 50K kullanıcıda tavansız = fatura |
| Ses notu | **120 sn / 2 MB** | AAC-LC 32 kbps mono → 120 sn ≈ 480 KB; 2 MB bol pay |
| Presign | 60/saat, 300/gün | normal kullanıcı asla yaklaşmaz |
| Aylık bayt | 2 GB/kullanıcı | kötüye kullanım freni |
| Yeni hesap (<24 sa) | 20 medya/gün, 100 MB | spam hesabının en verimli anı ilk saattir |

**Belge uzantı beyaz listesi:** `pdf, doc, docx, xls, xlsx, ppt, pptx, txt, csv, rtf, odt, ods, odp, zip, rar, 7z`
**Kesin kara liste** (beyaz listede olsa bile reddedilir): `exe, apk, ipa, msi, dll, bat, cmd, com, scr, ps1, vbs, jar, sh, html, htm, svg, js, xhtml`
> `Content-Type: application/octet-stream` + uzantısız anahtar zaten render'ı imkânsız kılıyor; kara liste **ikinci katman** (kullanıcı "indir → aç" derse cihazda çalışmasın).

**Kota Lua (atomik, `streams/guests.go:53` deseni):**
```lua
-- KEYS[1]=saat KEYS[2]=gun KEYS[3]=aybayt  ARGV=saatMax,gunMax,baytMax,istenenBayt
if tonumber(redis.call("GET",KEYS[1]) or 0) >= tonumber(ARGV[1]) then return -1 end
if tonumber(redis.call("GET",KEYS[2]) or 0) >= tonumber(ARGV[2]) then return -2 end
if tonumber(redis.call("GET",KEYS[3]) or 0) + tonumber(ARGV[4]) > tonumber(ARGV[3]) then return -3 end
redis.call("INCR",KEYS[1]); redis.call("EXPIRE",KEYS[1],3600)
redis.call("INCR",KEYS[2]); redis.call("EXPIRE",KEYS[2],86400)
redis.call("INCRBY",KEYS[3],ARGV[4]); redis.call("EXPIRE",KEYS[3],2678400)
return 1
```

**Sweeper (`StartSweeper`, 10 dk periyot — `streams`/`rooms` deseni):**
- `status='beklemede' AND created_at < now()-interval '1 hour'` → `DeleteObject` + `status='red'`
- `status='hazir' AND created_at < now()-interval '24 hours'` (hiç mesaja bağlanmamış) → `DeleteObject` + `status='silindi'`
- ⚠️ `status='bagli'` olanlara **DOKUNMAZ**.

---

## 3. VERİTABANI — `014_medya.sql` (TAM SQL)

```sql
-- ============================================================================
-- TURU 74 — MEDYA MESAJLASMA: BELGE + SES NOTU
--
-- ⚠️ ADDITIVE: mevcut hicbir sutun/kisit DARALTILMAZ, hicbir veri tasinmaz.
--    Eski istemci (medya_id bilmeyen) AYNEN calisir: yeni sutun NULL kalir.
-- ⚠️ Migration calistiricisi argumansiz Exec kullanir (database.go:60) -> basit
--    protokol -> ORTUK TEK TRANSACTION. Asagidaki tum ifadeler ya hep ya hic.
-- ============================================================================

-- 1) MEDYA VARLIKLARI -------------------------------------------------------
CREATE TABLE IF NOT EXISTS media_assets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind        TEXT NOT NULL CHECK (kind IN ('document','audio','image','video')),
    object_key  TEXT NOT NULL UNIQUE,          -- m/doc/2026/08/07/<uuid>  (UZANTISIZ)
    mime        TEXT NOT NULL DEFAULT '',      -- GERCEK mime YALNIZ BURADA (R2'de octet-stream)
    bytes       BIGINT NOT NULL DEFAULT 0,
    sha256      TEXT NOT NULL DEFAULT '',      -- ⚠️ ISTEMCI BEYANI — guvenlik degil, dedup/moderasyon
    file_name   TEXT NOT NULL DEFAULT '',      -- orijinal ad (yalniz belge). ⚠️ ANAHTARDA YOK.
    duration_ms INTEGER NOT NULL DEFAULT 0,    -- ses notu suresi
    waveform    TEXT NOT NULL DEFAULT '',      -- base64(48 bayt, 0..100) — dalga formu
    status      TEXT NOT NULL DEFAULT 'beklemede'
                CHECK (status IN ('beklemede','hazir','bagli','red','silindi')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_sahip  ON media_assets (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_yetim  ON media_assets (created_at)
       WHERE status IN ('beklemede','hazir');   -- sweeper YALNIZ bu ikisini tarar
CREATE INDEX IF NOT EXISTS idx_media_sha    ON media_assets (sha256) WHERE sha256 <> '';

-- 2) MESAJ -> MEDYA BAGI ----------------------------------------------------
-- ⚠️ ON DELETE SET NULL: 5651 kapsaminda medya kaldirilirsa MESAJ SATIRI YASAR
--    (istemci "Bu icerik kaldirildi" cizer). Mesaj silinirse medya satiri KALIR
--    (delil/temizlik sweeper'in isi).
ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_id UUID
      REFERENCES media_assets(id) ON DELETE SET NULL;

-- 3) 'document' TIPI --------------------------------------------------------
-- Sutun-ici CHECK'in otomatik adi <tablo>_<sutun>_check'tir; yine de ADA GUVENME:
-- pg_constraint'ten BUL ve dusur (isim farkliysa da calisir).
DO $$
DECLARE k text;
BEGIN
  SELECT conname INTO k FROM pg_constraint
   WHERE conrelid='messages'::regclass AND contype='c'
     AND pg_get_constraintdef(oid) ILIKE '%type%location%';
  IF k IS NOT NULL THEN EXECUTE format('ALTER TABLE messages DROP CONSTRAINT %I', k); END IF;
END $$;
-- ⚠️ SADECE GENISLETME (ustkume) — hicbir mevcut satir gecersizlesemez.
-- ⚠️ 'system' HALA VAR: sunucunun kendi yazdigi arama kayitlari (calls/handler.go:1654,
--    calls/grup_sohbet.go:105) dogrudan INSERT eder. ISTEMCI beyaz listesine EKLENMEZ.
ALTER TABLE messages ADD CONSTRAINT messages_type_check
      CHECK (type IN ('text','image','video','audio','location','system','document')) NOT VALID;
ALTER TABLE messages VALIDATE CONSTRAINT messages_type_check;

-- 4) "DINLENDI" MAKBUZU (ses notu mavi mikrofon) ----------------------------
-- ⚠️ read_at'ten AYRI: sohbeti acmak mesaji "okundu" yapar ama ses notunu DINLEMEZ.
ALTER TABLE message_receipts ADD COLUMN IF NOT EXISTS played_at TIMESTAMPTZ;

-- 5) OKUNMAMIS SAYACI ICIN EKSIK INDEX (ListChats alt sorgusu, handler.go:333-335)
-- ⚠️ Bugun message_receipts'te YALNIZ (message_id,user_id) PK var; alt sorgu her
--    sohbet icin tabloyu tariyor. Medya ile mesaj hacmi artacagi icin simdi eklenir.
CREATE INDEX IF NOT EXISTS idx_receipts_okunmamis
       ON message_receipts (user_id) WHERE read_at IS NULL;
```

**Geri alma (rollback) — sorun çıkarsa:**
`R2_*` env'lerini boşalt → `mediaH.Enabled()==false` → medya uçları `503`, istemci ataç butonunu gizler (`GET /users/me` yanıtına `media_enabled` bayrağı eklenir). **Migration geri alınmaz** (additive, zararsız).

---

## 4. WEBSOCKET SÖZLEŞMESİ

Hub'da (`chat/hub.go`) **hiçbir değişiklik yok** — `Event.Payload` ham JSON.

### 4.1 `message.new` — **GENİŞLİYOR** (yeni olay değil)
```jsonc
{ "type":"message.new","chat_id":"<uuid>",
  "payload":{
    "id":1234,"chat_id":"<uuid>","sender_id":"<uuid>",
    "type":"document","content":"Sözleşmenin son hali","media_url":"",
    "reply_to_id":null,"created_at":"2026-08-07T10:15:00Z",
    "media":{ "id":"5f2c...","kind":"document","mime":"application/pdf",
              "file_name":"sozlesme_2026.pdf","bytes":2415616,
              "duration_ms":0,"waveform":"" } } }
```
Ses notunda: `"type":"audio"`, `kind:"audio"`, `mime:"audio/mp4"`, `duration_ms:14200`, `waveform:"<base64 48 bayt>"`, `file_name:""`.
- ⚠️ **`media_url` boş string olarak KALIYOR** — silinmiyor; eski istemcinin `Message.fromJson` çağrısı kırılmasın (deprecated).
- ⚠️ **`media` nesnesi presigned URL TAŞIMAZ.** URL ayrı uçtan, dokunuşta, 10 dk ömürle alınır. Sebep: WS payload'ı istemci loglarına/Sentry breadcrumb'ına düşer.

### 4.2 `receipt.played` — **YENİ OLAY**
```jsonc
{ "type":"receipt.played","chat_id":"<uuid>",
  "payload":{ "message_id":1234,"user_id":"<dinleyen uuid>" } }
```
`To: [sender_id]` (yalnız gönderen).
- ⚠️ **Neden yeni olay:** mevcut `receipt.read` (`chat/handler.go:403-404`) **sohbet geneli**dir ve mesaj id taşımaz; istemci `chats_provider.dart:103-105`'te **tüm** mesajları `read=true` yapıyor. "Dinlendi" **tekil mesaj** bilgisidir; `receipt.read`'e binemez.
- ⚠️ **YAPMA:** `receipt.read` semantiğini değiştirme (turu 59 mavi tik regresyonu sınıfı).

### 4.3 Yükleme ilerlemesi WS'ten **GİTMEZ**
Tamamen yerel durum. 25 MB'lık bir yükleme saniyede 10 olay üretirse cx33'te LiveKit ile aynı Redis pub/sub kanalını (`hub.go:64` `"events"`) gereksiz yere doldurur.

---

## 5. FLUTTER — DOSYALAR, WIDGET AĞACI, DURUM YÖNETİMİ

### 5.1 `pubspec.yaml` — eklenecekler
```yaml
  # ---- MEDYA MESAJLASMA (belge + ses notu) ----
  # Belge secimi: iOS UIDocumentPicker / Android SAF -> ⚠️ HICBIR IZIN ISTEMEZ.
  # ⚠️ pickFiles(withData: false) ZORUNLU — true 25MB'i RAM'e alir.
  file_picker: ^11.0.3

  # Ses notu kaydi (AAC-LC/m4a; opus Android 29+ ister, minSdk 24).
  # 🔴 ZORUNLU KAPI: arama/oda/yayin varken KAYIT YOK (bkz. ses_notu_kontrol.dart).
  #    Sebep: IosRecordConfig'te manageAudioSession YOK -> paket AVAudioSession
  #    kategorisini KOSULSUZ yazar; AppDelegate.swift:32 useManualAudio GLOBAL.
  record: ^7.1.1

  # Gecici kayit + indirilen medya onbellegi (secure storage UYGUN DEGIL).
  path_provider: ^2.1.6

  # Belgeyi SISTEM goruntuleyicisiyle ac (ic PDF goruntuleyici EKLEME: +native, +APK).
  open_filex: ^4.7.0

  # sha256 (dedup beyani) — saf Dart, native kod yok.
  crypto: ^3.0.6
```
**Eklenmeyenler ve gerekçeleri:**
- `camera` → ❌ iOS'ta `flutter_webrtc` **TEK paylaşılan `videoCapturer`** tutuyor (`AppDelegate.swift:668,737,905`); üçüncü capture tüketicisi turu 50/67 hatasını geri getirir. **Bu iki özellik kamerayı hiç kullanmıyor.**
- `background_downloader` → ❌ Android'de **kendi foreground service'ini** açar; projede `AramaServisi` (`foregroundServiceType="microphone|camera"`, `AndroidManifest.xml:60-63`) zaten var → Android 14 FGS tip/kota çatışması. Yerine **ön planda dio + kalıcı outbox** (5.3).
- `audio_waveforms` → ❌ kendi kayıt **ve** çalma motorunu getirir → `record` + `audioplayers` ile **üçlü** `AVAudioSession` çakışması.
- `just_audio` → ❌ `audioplayers ^6.5.0` zaten bağımlı; ikinci ses motoru = ikinci global iOS bağlamı.

**TAHMİN — boyut artışı:** APK (arm64) **+0,8 – 1,5 MB** · IPA **+0,3 – 0,6 MB** (`file_picker`+`record`+`path_provider`+`open_filex` native tarafı ince; `crypto` saf Dart). ⚠️ Ölçülmedi — `flutter build apk --analyze-size` ile doğrulanmalı.

### 5.2 Yeni dosyalar
```
mobile/lib/core/medya/
  medya_servisi.dart      # presign -> PUT -> commit -> url -> download; onbellek yollari
  medya_kuyrugu.dart      # GidenMedya modeli + MedyaKuyruguNotifier + outbox (shared_preferences)
mobile/lib/features/chats/medya/
  ses_notu_kontrol.dart   # 🔴 SES KAPISI + "arama kazanir" yikim (Bolum 7)
  ek_paneli.dart          # atac -> alttan panel
  belge_balonu.dart
  ses_notu_balonu.dart
  ses_notu_kayit.dart     # basili tut serit + jestler
  ses_notu_oynatici.dart  # TEK global AudioPlayer(playerId:'gebzem_sesnotu')
  dalga_formu.dart        # CustomPainter (kayit + oynatma ortak)
  dosya_ikon.dart         # uzanti -> Lucide ikon + renk
```

### 5.3 Durum yönetimi (Riverpod)

```dart
// ⚠️⚠️ UYGULAMA OMURLU — autoDispose YOK.
// SEBEP: messagesProvider `family.autoDispose` (chats_provider.dart:121-123).
// Yukleme oraya baglansaydi kullanici sohbetten cikinca notifier olur ve
// YUKLEME IPTAL OLURDU. CLAUDE.md deseni: aktif arama da ayni sebeple
// global ActiveCallController'da yasiyor.
final medyaKuyruguProvider =
    StateNotifierProvider<MedyaKuyruguNotifier, List<GidenMedya>>(MedyaKuyruguNotifier.new);

final sesNotuOynaticiProvider = ChangeNotifierProvider<SesNotuOynatici>((ref) => SesNotuOynatici());
final medyaIndirmeProvider   = ChangeNotifierProvider<MedyaIndirme>((ref) => MedyaIndirme(ref));

// R2'ye PUT/GET icin AYRI Dio — 🔴 apiProvider'in interceptor'i (api.dart:34-40)
// Authorization: Bearer ekliyor; presigned istekte fazladan bir baslik IMZAYI BOZAR
// (403 SignatureDoesNotMatch) ve 401 dali (api.dart:52-63) OTURUMU SILEBILIRDI.
final r2Provider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout:    const Duration(minutes: 5),   // ⚠️ apiProvider'da sendTimeout TANIMSIZ
      receiveTimeout: const Duration(minutes: 5),
    )));
```

**`GidenMedya` (outbox kaydı, `shared_preferences`'ta JSON listesi):**
```dart
class GidenMedya {
  final String geciciId;   // yerel balon anahtari
  final String chatId, tip /*document|audio*/, yerelYol, dosyaAdi, sha256, aciklama;
  final int bytes, sureMs; final String dalga;
  String? uploadId, mediaId;
  String asama;            // 'presign' | 'put' | 'commit' | 'send' | 'hata'
  double ilerleme;         // 0..1
}
```
- ⚠️ **Aşama kaydedilir** → uygulama öldürülse bile açılışta `MedyaKuyruguNotifier.surdur()` **kaldığı aşamadan** devam eder.
- Tekrar denemede `POST /media/upload {upload_id: mevcut}` → **aynı anahtara taze imza** (bu yüzden `If-None-Match: *` kullanılmadı).

### 5.4 `models.dart` — genişleme (`models.dart:52-85`)
```dart
class MedyaBilgi {
  final String id, kind, mime, fileName, waveform;
  final int bytes, durationMs;
  factory MedyaBilgi.fromJson(Map<String,dynamic> j) => ...;
}

class Message {
  ...
  final MedyaBilgi? media;   // YENI (null = medyasiz veya kaldirilmis)
  bool read;                 // MEVCUT (mavi tik)
  bool played;               // YENI: karsi taraf ses notunu DINLEDI mi
  // Yerel gonderim durumu (sunucudan GELMEZ):
  final String? yerelYol; final double? ilerleme; final bool hata;
}
```

### 5.5 `chats_provider.dart` — değişecek yerler
- `:61-75` `load()` → `media` nesnesi ve `played` ayrıştırılır.
  ⚠️ **`before_id` kullanımı bu turda EKLENMİYOR** (kapsam dışı) ama medya balonları uzun olduğu için 50 mesaj sınırı daha çabuk hissedilir — ayrı iş olarak not.
- `:77-83` `send()` imzası:
```dart
Future<void> send(String content, {String type='text', String? mediaId}) async {
  await _ref.read(apiProvider).post('/chats/$chatId/messages',
      data: {'type':type, 'content':content, if (mediaId!=null) 'media_id':mediaId});
  await load();
}
```
⚠️ Medya yolunda `await load()` **kuyruktan** çağrılır; sohbet ekranı kapalıysa notifier yoktur → kuyruk `chatsProvider.load()`'u tetikler, ekran tekrar açılınca mesaj zaten gelir.
- `_onEvent` → `case 'receipt.played':` eklenir, **yalnız** `payload['message_id']` eşleşen mesaja `played=true`.

### 5.6 `chat_screen.dart` — değişecek yerler

**(a) Tip dallanması (`:251-261`) — sıralama KRİTİK:**
```dart
if (msg.type == 'system')            _CallLogChip(...)
// ⚠️ SILINMIS KONTROLU TIP DALLANMASININ USTUNDE: aksi halde media==null olan
//    silinmis bir belge/ses notu icin BelgeBalonu cizilir ve null patlar.
else if (msg.deletedForAll)          _Bubble(message: msg, mine: mine)
else if (msg.type == 'document')     BelgeBalonu(message: msg, mine: mine)
else if (msg.type == 'audio')        SesNotuBalonu(message: msg, mine: mine)
else                                 _Bubble(message: msg, mine: mine)
```
`BelgeBalonu`/`SesNotuBalonu` içinde `message.media == null` ise → *"Bu içerik kaldırıldı"* satırı (5651 kaldırma yolunun karşılığı).

**(b) Giriş çubuğu (`:269-303`) — yeni ağaç:**
```
SafeArea > Padding > AnimatedSwitcher(180ms)
 ├─ [kayit YOK]  Row
 │    ├─ IconButton(LucideIcons.paperclip)          -> EkPaneli.ac(context)
 │    ├─ Expanded(TextField)                        -- MEVCUT, aynen
 │    └─ ValueListenableBuilder(_metinBos)
 │         ├─ bos ise : RawGestureDetector(LongPressGestureRecognizer(duration:200ms))
 │         │              > FloatingActionButton.small(Icon(LucideIcons.mic))
 │         └─ dolu ise: FloatingActionButton.small(Icon(LucideIcons.send))  -- MEVCUT
 └─ [kayit VAR]  SesNotuKayitSeridi(...)
```
⚠️ **Ataç butonu `InputDecoration.prefixIcon` DEĞİL, Row'un ilk çocuğu.** Sebep: `TextField` `maxLines: 5` (`:281`) — çok satırlı metinde `prefixIcon` dikeyde ortalanıp zıplar.

### 5.7 BELGE BALONU (görünüm — **EMOJİ YOK, hepsi Lucide**)
```
┌──────────────────────────────────────────────┐
│ ┌────┐  sozlesme_2026_son...pdf              │   maxWidth: ekran*0.78
│ │ 📄 │  PDF · 2,4 MB              [↓]        │   ← ikon Lucide fileText
│ └────┘                                       │      [↓] = arrowDownToLine
│ Sözleşmenin son hali                         │   ← aciklama (content), varsa
│                                   10:42  ✓✓ │
└──────────────────────────────────────────────┘
```
- Sol kare 44x44, `scheme.surfaceContainerHigh`, `BorderRadius.circular(10)`.
- İkon eşlemesi (`dosya_ikon.dart`, **hepsi doğrulandı — pakette mevcut**):
  `pdf/doc/docx/txt/rtf/odt` → `LucideIcons.fileText` · `xls/xlsx/csv/ods` → `fileSpreadsheet`
  `ppt/pptx/odp` → `presentation` · `zip/rar/7z` → `fileArchive` · diğer → `file`
- Dosya adı **ortadan kısaltılır** (`_ortadanKisalt(ad, bas:16, son:9)`) — sondaki uzantı görünmeli.
  ⚠️ **RTL/kontrol karakterleri temizlenir** (`\u202A-\u202E`, `\u2066-\u2069`): `fatura‮gpj.exe` saldırısı klasiktir.
- Sağ durum düğmesi: `arrowDownToLine` (inmemiş) → halka + `x` (iniyor) → düğme yok (inmiş, balon tıklanır)
- **Gönderirken (benim tarafım):** halka ilerleme + `x`; hata → `rotateCw` + *"Gönderilemedi · Tekrar dene"*.

### 5.8 SES NOTU BALONU
```
┌────────────────────────────────────────────────────┐
│  (o)   ▶   ▁▃▅█▆▃▁▂▅▇█▅▂▁▃▅▄▂▁▃▅▇▆▄▂▁▃▄▂▁▂▃▅▄▂▁   │
│ [mic]                                       1.5x   │
│        0:14                            10:42  ✓✓  │
└────────────────────────────────────────────────────┘
```
- `(o)` 40px avatar dairesi (harf yedeği — `avatar_url` prototipte boş), **sağ altında 16px `LucideIcons.mic` rozeti**:
  - dinlenmemiş → `scheme.primary` (dolu)
  - dinlenmiş → `scheme.outline`
  - **benim mesajım** → karşı taraf dinlediyse `scheme.tickRead` (mavi), yoksa `scheme.outline`
- `▶` = `LucideIcons.play` / `LucideIcons.pause`, 34px.
- Dalga: 48 çubuk, `CustomPaint`. Çalınan kısım `scheme.primary`, kalan `scheme.outline.withValues(alpha:.45)`.
  `GestureDetector.onHorizontalDragUpdate` → `player.seek(...)`.
- Hız rozeti: küçük `Material` hap, metin `1x` / `1.5x` / `2x` (⚠️ metin — ikon değil; `LucideIcons.gauge` çok belirsiz).
- İnmemişse: dalga %35 opaklıkta + `▶` yerine `arrowDownToLine`; **tek dokunuş indirir ve çalar.**

### 5.9 SES NOTU KAYIT ŞERİDİ
```
[●]  0:07   ~~~~~~~~~~~~~~~~~~~~~~~~     ← İptal için kaydırın   [🗑]
```
- `[●]` 900 ms'de bir yanıp sönen kırmızı daire (`AnimatedOpacity`).
- Canlı dalga: son 40 örnek, sağdan sola akar (`record.onAmplitudeChanged(Duration(milliseconds:100))`).
  dBFS → yükseklik: `((dbfs + 50) / 50).clamp(0,1)`
- Kilit modunda şerit: `[circleStop Durdur] [play Dinle] [trash2 Sil] [send Gönder]`
- Metinler: *"İptal için kaydırın"* · *"Kilitlemek için yukarı kaydırın"* — **emoji yok**.

### 5.10 `chats_screen.dart` — sohbet listesi önizlemesi
- `_previewIkon()` (`:219-236`): `case 'document': return LucideIcons.fileText;`
- `_preview()` (`:238-260`): `case 'document': return chat.lastMessage.isEmpty ? 'Belge' : chat.lastMessage;`
  ⚠️ Dosya adını göstermek için `ListChats` sorgusuna `ma.file_name` eklenmeli (`chat/handler.go:345-348` LATERAL). Yapılmazsa açıklama, o da yoksa "Belge".
- `case 'audio'` → **HİÇ DOKUNULMUYOR**, zaten *"Sesli mesaj"* + `LucideIcons.mic` (`:225`, `:245`).

---

## 6. KENAR DURUMLAR

| # | Durum | Davranış |
|---|---|---|
| 1 | **Ağ koptu (yükleme)** | Balon *"Gönderilemedi · Tekrar dene"* (`rotateCw`). Outbox `shared_preferences`'ta. Tekrar → `POST /media/upload {upload_id}` ile **taze imza, aynı anahtar** → kaldığı aşamadan devam. |
| 2 | **Ağ koptu (indirme)** | `.part` dosyasına yazılır, hata olursa **silinir** (yarım dosya `open_filex`'e verilmez). Balon indirme durumuna döner. |
| 3 | **Arka plana geçti** | **Kayıt: ANINDA durur + taslak** (`AppLifecycleState.inactive`). Yükleme: dio devam eder; Android 14+ cached-app freezer (~10 sn, turu 32-33 kanıtı) süreci dondurabilir → dönüşte outbox sürdürür. ⚠️ Aktif arama varsa `AramaServisi` FGS süreci ayakta tutar, yükleme kesilmez. |
| 4 | **Uygulama ÖLDÜRÜLDÜ** | R2'de yetim `beklemede` nesne → **sunucu sweeper 1 saat sonra siler**. Outbox kalıcı → açılışta `surdur()` mesajı gönderir. Kayıt yarıdaysa `tmp/gebzem_kayit_*` açılışta temizlenir (**taslak kaybolur** — WhatsApp da kaybeder, dürüst sınır). |
| 5 | **Mikrofon izni reddi** | 1. red → satır içi açıklama + *"İzin ver"*. `permanentlyDenied` → *"Ayarları aç"* (`openAppSettings()`). ⚠️ **Belge için izin YOK** — sistem seçici. |
| 6 | **Dosya çok büyük** | Üç katman: istemci (seçimde), sunucu `POST /media/upload` (`413`), sunucu `commit` `HeadObject` (gerçek boyut → `DeleteObject` + `400`). |
| 7 | **Aynı dosya iki kez** | **Dedup YOK (V1).** Her gönderim yeni `object_key`. ⚠️ Gerekçe: dedup = iki mesajın aynı nesneyi paylaşması; birinin silinmesi diğerini kırar → referans sayacı gerekir. `sha256` yine de saklanır (ileride dedup + moderasyonda "aynı içeriğin tüm kopyalarını tek hamlede kaldırma"). |
| 8 | **Gönderim sırasında sohbetten çıkıldı** | 🔴 **Gerçek hata kaynağı, yapısal çözüldü:** yükleme `messagesProvider`'da (`family.autoDispose`, `chats_provider.dart:121-123`) **DEĞİL**, uygulama ömürlü `medyaKuyruguProvider`'da yaşar. Ekran ölse bile yükleme sürer, mesaj gider. |
| 9 | **Alıcı engelledi** | `SendMessage`'a engel kontrolü **eklendi** (2.2). ⚠️ Bugün bu kontrol YOK (`handler.go:159` yorumu yanlış) — sohbet bir kez açılınca engelleme mesajı durdurmuyordu. Geçmiş medya `GET /media/{id}/url` üyelik kapısından geçmeye devam eder (mesaj silinmedikçe) — bilinçli. |
| 10 | **Kayıt sırasında GSM araması geldi** | `record` iOS varsayılanı `allowHapticsAndSystemSoundsDuringRecording: false` → **zil sesi bastırılır, kullanıcı aramayı kaçırır.** ⚠️ Bu yüzden **`true` set ediliyor** (zilin duyulması, kayda hafif sızıntıdan önemli). iOS'ta gelen hücresel arama `AVAudioSession`'ı kesince `record` hata verir → **taslak olarak saklanır, atılmaz.** |
| 11 | **Kayıt sırasında Gebzem araması geldi** | `SesNotuKontrol.kapat()` (Bölüm 7) kaydı durdurur + **taslak yapar**; arama ekranı açılır. Arama bitince taslak giriş çubuğunda "Gönder / Sil" olarak bekler. |
| 12 | **İki ses notu aynı anda** | Tek `AudioPlayer(playerId:'gebzem_sesnotu')` → yenisi eskisini keser. **Zincir oynatma (WhatsApp) V1'de YOK.** |
| 13 | **Silinmiş mesaj** | `GetMessages` `media_id`'yi de NULL döndürür → balon *"Bu içerik kaldırıldı"*. `media_url` zaten boşalıyordu (`handler.go:236-237`). |
| 14 | **Sunucu R2'siz** | `mediaH.Enabled()==false` → uçlar `503`; istemci ataç + mikrofon butonlarını **gizler** (`/users/me` yanıtındaki `media_enabled`). Sessiz patlama yok. |
| 15 | **Depolama dolu (cihaz)** | `dio.download` `FileSystemException` → *"Cihazda yeterli alan yok."* Kısmi `.part` silinir. |
| 16 | **Presigned URL süresi doldu (10 dk)** | İndirme `403` → istemci **bir kez** URL'yi yeniler ve tekrar dener; ikinci `403` → hata gösterir (sonsuz döngü yok). |

---

## 7. ⚠️⚠️ BU PROJEYE ÖZEL ÇAKIŞMA RİSKLERİ — **KARAR: SERT KAPI + "ARAMA KAZANIR"**

### 7.1 Kamera — **RİSK YOK, bilinçli tasarım**
Belge ve ses notu **kamerayı hiç kullanmıyor**. `image_picker`'ın `ImageSource.camera`'sı ve `camera` paketi **bu tasarımda yok**. Dolayısıyla iOS'taki tek paylaşılan `videoCapturer` (`AppDelegate.swift:668, 737, 905`) çakışması **oluşamaz**. Fotoğraf/video fazı geldiğinde bu risk **yeniden** ele alınmalı.

### 7.2 Mikrofon / ses birimi — ÜÇ AYRI ÇAKIŞMA MEKANİZMASI

**(M1) iOS — `RTCAudioSession` proses genelinde tek.**
`AppDelegate.swift:32-33` uygulama açılışında `useManualAudio = true` + `isAudioEnabled = false` yazıyor; `gebzem/audio` kanalı `setConfiguration(webRTC(), active:true)` ile oturumu **deterministik** kuruyor. `record` paketi ise kayıtta `AVAudioSession.setCategory` yazar ve **bunu kapatmanın yolu yok** (`IosRecordConfig`'te `manageAudioSession` alanı **yok** — doğrulandı). Canlı bir VPIO biriminin altından kategori değiştirmek bu projede **iki kez ölçülmüş** felaket:
- turu 64: `NSOSStatusErrorDomain#561017449` = `0x21707269` = `!pri` = `InsufficientPriority`
- turu 65: CallKit unhold ediyor ama `didActivate` **hiç gelmiyor**
`iosSesBirimiAc` merdiveni (`medya_beklet.dart:155`) **tam bu yüzden** var — yani kurtarma **güvenilir değil**, o merdiven bir son çare.

**(M2) iOS — `audioplayers` bağlamı GLOBAL.**
audioplayers v4.0.0 changelog: *"set player context globally on `setAudioContext` for iOS only"*. Proje bunu bildiği için `CallSounds` iOS'ta `setAudioContext`'i **hiç çağırmıyor** (`call_sounds.dart:73` `if (Platform.isAndroid)`).
> **KURAL: `SesNotuOynatici` de iOS'ta `setAudioContext`/`AudioPlayer.global.setAudioContext` ÇAĞIRMAZ.** Yalnız Android'de `AndroidUsageType.media` bağlamı set edilir.

**(M3) Android — audio focus + mod, LiveKit'in `AudioSwitchManager`'ında kilitli.**
Turu 62-C'de kaynak okunarak kanıtlandı: mod (`MODE_IN_COMMUNICATION`), audio focus ve cihaz seçimi **yalnız** `AudioSwitch.activate()` geçişinde uygulanır, o geçiş `if (!isActive)` ile korunur ve `isActive` **arama boyunca true takılıdır**. `record` MediaRecorder ile focus alırsa, focus geri döndüğünde **onu geri uygulayan hiçbir şey yok** → ses rotası bozulur (turu 62'de yaşandı: "bekletmeden sonra ses hoparlörden geliyor").

### 7.3 KARAR

> ## Arama / sesli oda / canlı yayın (çalar fazı dahil) varken **SES NOTU KAYDI VE OYNATMASI TAMAMEN ENGELLİDİR.**
> ## Ses notu **hiçbir koşulda** aramayı engellemez, geciktirmez veya bekletmez; arama başlarsa ses notu **anında yıkılır**.

**Neden kuyruğa alma DEĞİL:** arama dakikalarca sürer; "şimdi ses notu göndereyim" niyeti o zaman ölmüştür. Kuyruk, kullanıcıya 4 dakika sonra kendiliğinden başlayan bir kayıt vaat etmek demektir — kabul edilemez.
**Neden izin verme DEĞİL:** M1/M2/M3 ölçülmüş; kaybedilen oturum deterministik geri alınamıyor.
**Referans:** WhatsApp da görüşme sırasında ses notu kaydettirmez.

### 7.4 UYGULAMA — `ses_notu_kontrol.dart`

```dart
/// 🔴 SES KAPISI — arama/oda/yayin ile ses notu arasindaki TEK sozlesme.
///
/// ⚠️ `CallService.mesgulMu()` KULLANILMAZ: o EKRAN muhafizlarina bakar, ustelik
///    `odaYayinMuaf` gevsetmesi ve bayat-muhafiz self-heal'i var. Burada sorulan
///    soru "ekran acik mi" degil, "iOS SES BIRIMINI tutan biri var mi" -> dogru
///    kaynak `SesSahipligi` (medya_beklet.dart:29-53).
/// ⚠️ Ikinci kaynak: CALAR fazi. `SesSahipligi.kaydol("arama_$id")`
///    `baslat()` icindedir (active_call_controller.dart:1348) ve GIDEN aramada
///    calar fazini kapsar; ama GELEN arama kabul edilene kadar yalniz
///    `callServiceProvider` doludur -> ikisi de sorulur.
class SesKapisi {
  static String? engelSebebi(WidgetRef ref) {
    if (SesSahipligi.aramaCanli)          return 'Görüşme sürerken sesli mesaj kullanılamaz.';
    if (SesSahipligi.odaVeyaYayinCanli)   return 'Oda veya canlı yayın sürerken sesli mesaj kullanılamaz.';
    if (ref.read(activeCallProvider).arama != null)
                                          return 'Görüşme sürerken sesli mesaj kullanılamaz.';
    if (ref.read(callServiceProvider) != null)
                                          return 'Gelen arama var — sesli mesaj kullanılamaz.';
    return null;
  }
}

/// 🔴 "ARAMA KAZANIR" YIKIMI.
/// ⚠️ Ses notu `SesSahipligi`ne KAYDOLMAZ — o defter WebRTC ses biriminin
///    sahiplerini sayar; ses notu oraya yazilirsa `aramaCanli`/`odaVeyaYayinCanli`
///    YALAN SOYLER ve arama kapanisinda ses birimi kapatilmaz.
class SesNotuKontrol {
  SesNotuKontrol._();
  static bool _kapali = false;                 // SENKRON kapi
  static Future<void>? _yikim;
  static bool get kapali => _kapali;

  /// SENKRON kapatir + yikimi ATESLER (beklemez). Cagiran ses birimini kurmadan
  /// once `sustur()`u await etmeli.
  static void kapat() {
    _kapali = true;
    _yikim = _hepsiniDurdur();
  }

  /// Yikim GERCEKTEN bitene kadar bekler. ⚠️ Cagiran MUTLAKA timeout ile sarmali.
  static Future<void> sustur() async => await (_yikim ?? Future<void>.value());

  static void ac() {
    // ⚠️ Yalniz HIC sahip kalmadiysa ac (arama bitti ama oda suruyor olabilir).
    if (SesSahipligi.aramaCanli || SesSahipligi.odaVeyaYayinCanli) return;
    _kapali = false;
  }

  static Future<void> _hepsiniDurdur() async {
    await SesNotuKayitDurumu.instance.acilIptal();   // kaydi durdur -> TASLAK yap
    await SesNotuOynatici.instance.durdur();         // oynatmayi durdur
  }
}
```

**Çağrı noktaları — `SesSahipligi.kaydol(...)` ile YAN YANA:**

| Dosya:satır | Ne eklenecek |
|---|---|
| `active_call_controller.dart:1348` | `SesSahipligi.kaydol("arama_$id");` **satırının hemen üstüne** `SesNotuKontrol.kapat();` |
| `active_call_controller.dart` `_connect()` (`:1763`), `_sesiAc(true)`'dan **hemen önce** | `await SesNotuKontrol.sustur().timeout(const Duration(milliseconds: 400), onTimeout: () { unawaited(Sentry.captureMessage('ses notu yikimi 400ms icinde bitmedi')); });` |
| `active_call_controller.dart:3066` (`SesSahipligi.birak("arama_$id")` yanı) | `SesNotuKontrol.ac();` |
| `room_screen.dart:130` / `:434` | `kapat()` / `ac()` |
| `live_broadcast_screen.dart:109` / `:576` | `kapat()` / `ac()` |
| `live_viewer_screen.dart:131` / `:714` | `kapat()` / `ac()` |
| `incoming_call_overlay.dart` `initState` / `dispose` | `kapat()` / `ac()` — ⚠️ **kabul edilmeden önceki çalar fazı**; `CallSounds` zili ile kayıt aynı anda çalmasın |

> ⚠️ **400 ms TAVANI ZORUNLU.** Turu 67'de `await CallSounds.durdur(...)` zaman aşımsızdı ve takılınca ekran son karede asılı kalmıştı. Ses notu yıkımı **hiçbir koşulda** aramayı bloklamamalı — tıkanırsa 400 ms sonra devam edilir ve olay Sentry'ye **gerçek olay** olarak yazılır (breadcrumb değil — CLAUDE.md'nin tekrarlayan tuzağı).

**`record` yapılandırması:**
```dart
await _rec.start(
  const RecordConfig(
    encoder: AudioEncoder.aacLc,      // ⚠️ opus DEGIL: Android'de API 29+ ister, minSdk 24
    bitRate: 32000, sampleRate: 44100, numChannels: 1,
    // ⚠️ TRUE: varsayilan false GELEN ARAMA ZILINI BASTIRIR -> kullanici aramayi kacirir.
    //    Kayda hafif sistem sesi sizmasi, arama kacirmaktan iyidir.
    ios: IosRecordConfig(allowHapticsAndSystemSoundsDuringRecording: true),
  ),
  path: '$tmp/gebzem_kayit_${DateTime.now().millisecondsSinceEpoch}.m4a',
);
```

**Ses notu OYNATMA yapılandırması:**
```dart
static final _player = AudioPlayer(playerId: 'gebzem_sesnotu');   // CallSounds'unkinden AYRI
// ⚠️ iOS'ta setAudioContext CAGRILMAZ (global baglami degistirir — audioplayers v4.0.0).
if (Platform.isAndroid) {
  await _player.setAudioContext(AudioContext(android: AudioContextAndroid(
    contentType: AndroidContentType.speech,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,   // ⚠️ gain DEGIL
  )));
}
```

### 7.5 Belge yolunun ses/kamera riski — **YOK**
`file_picker` + `dio` + `open_filex` hiçbiri `AVAudioSession`'a, `AudioManager`'a veya capture oturumuna dokunmaz. **Belge paylaşımı arama sırasında serbesttir** — engellenmez.
⚠️ **Tek istisna:** aktif arama sırasında **büyük** belge yüklemesi Android'de `AramaServisi` FGS'inin altında ağ/CPU ile yarışır. Ölçülmedi; sınır zaten 25 MB olduğu için kabul ediliyor. Sorun görülürse **arama sırasında >5 MB yükleme kuyruğa alınır** (arama bitince sürer) — bu, ses notundan farklı olarak **kuyruklanabilir** bir iştir çünkü kullanıcı sonucu anlık beklemiyor.

---

## 8. TEST SENARYOLARI (elle)

### A — Belge
1. Sohbet aç → ataç → **Belge** → bir PDF seç. **İzin diyaloğu ÇIKMAMALI.**
2. Onay ekranında ad + boyut doğru mu? Açıklama yaz → **Gönder**.
3. Balon **anında** göründü mü, halka ilerliyor mu, bitince tik çıktı mı?
4. Karşı cihazda balon **indirilmemiş** halde göründü mü (ikon + `PDF · 2,4 MB` + ↓)?
5. Karşı cihazda ↓ → iniyor → dokun → **sistem PDF görüntüleyici** açıldı mı?
6. Aynı belgeye **ikinci kez** dokun → URL istemeden **anında** açılmalı.
7. **30 MB'lık** dosya seç → *"25 MB'den büyük olamaz"* çıktı mı? (gönderim başlamamalı)
8. `.apk` uzantılı dosya seç → *"Bu dosya türü gönderilemez"*.
9. **Uçak modu aç** → belge gönder → *"Gönderilemedi · Tekrar dene"*. Uçak modu kapat → **Tekrar dene** → gitti mi?
10. Yükleme %40'tayken **sohbetten çık** → sohbet listesine dön → 5 sn bekle → sohbete gir: **mesaj gönderilmiş olmalı**.
11. Yükleme %40'tayken **uygulamayı öldür** → yeniden aç → sohbete gir: mesaj tamamlanmış ya da "Tekrar dene" olmalı (**yok olmamalı**).
12. Sohbet listesinde önizleme: ikon + dosya adı/açıklama.
13. Bildirim (uygulama kapalıyken): *"Ahmet: sozlesme_2026.pdf"*.
14. Türkçe karakterli dosya adı (`özet çalışması ğüşiöç.pdf`) → balonda ve bildirimde **bozulmadan** görünmeli.

### B — Ses notu (temel)
15. Metin alanı boşken FAB **mikrofon** mu? Bir harf yaz → **gönder ikonu** oldu mu? Sil → mikrofona döndü mü?
16. Mikrofona **basılı tut** → titreşim + kayıt şeridi + süre sayıyor + **dalga oynuyor** mu?
17. Bırak → gönderildi mi? Karşı cihazda balon: dalga + süre + oynat.
18. **0,5 sn** basıp bırak → *"Sesli mesaj için basılı tutun"*, gönderilmemeli.
19. Basılı tutarken **sola kaydır** → titreşim + iptal, hiçbir şey gönderilmemeli.
20. Basılı tutarken **yukarı kaydır** → kilit; parmağı kaldır → kayıt sürüyor mu? **Dinle** → kendi kaydını duyuyor musun? **Gönder**.
21. Karşı tarafta oynat → dalga soldan sağa doluyor mu? Ortasına dokun → oradan devam ediyor mu?
22. Hız rozeti `1x → 1.5x → 2x` → ses hızlanıyor, **tiz olmuyor** mu?
23. Yarım dinle → sohbetten çık → geri gel → **kaldığı yerden** devam mı?
24. **Gönderende** mikrofon rozeti, karşı taraf dinleyince **maviye** döndü mü?
25. 2 dakikadan uzun kaydetmeye çalış → 120 sn'de **otomatik durup** göndermeye hazır hale gelmeli.

### C — 🔴 ÇAKIŞMA TESTLERİ (en kritik bölüm)
26. **Sesli arama başlat** → aramayı küçült → sohbete gir → mikrofona basılı tut → *"Görüşme sürerken sesli mesaj kullanılamaz."* çıkmalı, **kayıt BAŞLAMAMALI**.
27. Aynı durumda bir **ses notu balonuna oynat** → aynı uyarı, **çalmamalı**. Arama sesi **kesilmemeli**.
28. Aynı durumda **belge gönder** → **çalışmalı** (belge engellenmez), arama sesi bozulmamalı.
29. **Sesli oda**ya gir → sohbete geç → mikrofona basılı tut → *"Oda veya canlı yayın sürerken..."*. Odaya dön → **ses hâlâ geliyor mu?**
30. **Canlı yayın** izlerken aynısı → uyarı + yayın sesi bozulmamalı.
31. **Ses notu kaydederken karşıdan arama gelsin** → kayıt **anında durmalı**, telefon **çalmalı**, arama kabul edilince **ses gelmeli**. Aramayı bitir → giriş çubuğunda **taslak** duruyor mu?
32. **Ses notu çalarken arama gelsin** → oynatma anında dursun, zil duyulsun, kabul → ses gelsin.
33. **31 ve 32'yi iPhone'da 5 kez tekrarla.** ⚠️ `!pri` (turu 64) ve `didActivate` (turu 65) hataları burada çıkar. Sentry'de `ses notu yikimi 400ms icinde bitmedi` **çıkmamalı**.
34. Arama bitti → **hemen** mikrofona basılı tut → kayıt **normal başlamalı** (kapı açılmış olmalı).
35. **Android**: ses notu kaydet → hemen ardından arama yap → aramada **ses hoparlörden değil kulaklıktan** gelmeli (rota bozulmamalı — turu 62-C).
36. **iOS**: ses notu kaydettikten sonra iPhone'un üst çubuğunda **turuncu mikrofon göstergesi sönmeli**.
37. Ses notu kaydederken **GSM araması** gelsin (gerçek telefon) → **zil duyulmalı** (bastırılmamalı), kayıt taslağa düşmeli.
38. Arama **çalarken** (henüz kabul edilmedi) sohbete geçip mikrofona bas → *"Gelen arama var..."*.

### D — Sunucu / güvenlik
39. Admin panelinden DB kontrolü: `media_assets`'te `status='bagli'` satırlar var mı, `beklemede` kalan var mı (1 saat sonra **temizlenmeli**)?
40. Aynı `media_id` ile **ikinci** mesaj göndermeyi dene (Postman) → `400 "medya bulunamadı veya zaten kullanıldı"`.
41. Başka kullanıcının `media_id`'siyle `GET /media/{id}/url` → `403`.
42. 61 kez üst üste `POST /media/upload` → `429 "Çok hızlı gönderiyorsunuz"`.
43. `POST /chats/.../messages {"type":"system",...}` → `400 "geçersiz mesaj tipi"` (turu 59b koruması **hâlâ ayakta**).
44. `POST /chats/.../messages {"type":"document","media_url":"https://kotu.site/x.gif"}` → **`media_url` YOK SAYILMALI**, mesaj `media_id` olmadığı için `400 "medya eksik"`.

---

## 9. BİLMEDİKLERİM / DOĞRULANMASI GEREKENLER (uydurmadım)

1. **R2'nin tek parça PUT'ta `ETag = MD5` döndürüp döndürmediğini** doğrulamadım. Tasarım buna **bağımlı değil** (commit doğrulaması yalnız **boyut** kullanıyor); ETag eşleşmesi eklenirse ek katman olur.
2. **`record` 7.1.1'in Android tarafında audio focus'u tam olarak nasıl aldığını** kaynak okuyarak doğrulamadım — README'nin "VoIP/WebRTC ile çakışma kontrolü yapın" uyarısına ve turu 62-C'de ölçülmüş `AudioSwitchManager` davranışına dayanıyorum. **Sert kapı bu belirsizliği zaten kapatıyor.**
3. **APK/IPA boyut artışı TAHMİN** (+0,8–1,5 MB / +0,3–0,6 MB) — `flutter build apk --analyze-size` ile ölçülmeli.
4. **`open_filex`'in `.docx`/`.xlsx`'i iOS'ta** Quick Look ile açtığını varsaydım; cihazda test edilmeli (test #5'in varyantı).
5. **`file_picker` 11.x'in Android SAF üzerinden dönen `path`'inin** her cihazda gerçek dosya yolu olduğunu (bazı sağlayıcılarda önce cache'e kopyalanır) doğrulamadım — kopyalama olursa 25 MB'lık dosya için ek disk/gecikme var.
6. **`messages_type_check` kısıtının gerçek adını** canlı DB'de görmedim; migration bu yüzden **`pg_constraint`'ten arayarak** düşürüyor (ada güvenmiyor).
7. **5651 / KVKK**: bu tasarım "kaldırma" için gereken **teknik** yolu açıyor (`media_assets.status='silindi'` + `DeleteObject` + `messages.media_id → NULL`) ama **`DELETE /messages/{id}` ve admin kaldırma ucu bu tasarımın kapsamında DEĞİL** — yayına çıkmadan önce ayrı iş olarak yapılmalı. Hukukçu teyidi şart.

---

## 10. İLGİLİ DOSYALAR (mutlak yollar)

**Değişecek — backend**
`c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\chat\handler.go` (125-130, 152-157, 159-171, 197-209, 234-265) ·
`c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\cmd\api\main.go` (90 civarı, 97, 145-210) ·
`c:\Users\gebze\OneDrive\Desktop\gbz-a3\backend\internal\config\config.go`

**Yeni — backend**
`backend\internal\media\{sigv4.go,r2.go,limits.go,kota.go,handler.go}` ·
`backend\internal\database\migrations\014_medya.sql`

**Değişecek — Flutter**
`mobile\pubspec.yaml` (30-68) ·
`mobile\lib\core\api.dart` (21-26: `r2Provider`) ·
`mobile\lib\features\chats\{models.dart,chats_provider.dart,chat_screen.dart,chats_screen.dart}` ·
`mobile\lib\features\calls\active_call_controller.dart` (1348, `_connect` `:1763`, 3066) ·
`mobile\lib\features\rooms\room_screen.dart` (130, 434) ·
`mobile\lib\features\live\live_broadcast_screen.dart` (109, 576) ·
`mobile\lib\features\live\live_viewer_screen.dart` (131, 714) ·
`mobile\lib\features\calls\incoming_call_overlay.dart` (initState/dispose)

**Yeni — Flutter**
`mobile\lib\core\medya\{medya_servisi.dart,medya_kuyrugu.dart}` ·
`mobile\lib\features\chats\medya\{ses_notu_kontrol.dart,ek_paneli.dart,belge_balonu.dart,ses_notu_balonu.dart,ses_notu_kayit.dart,ses_notu_oynatici.dart,dalga_formu.dart,dosya_ikon.dart}`

**DEĞİŞMEYECEK (önemli):** `mobile\ios\Runner\Info.plist` · `mobile\android\app\src\main\AndroidManifest.xml` — **tek satır bile eklenmiyor.**

**Kaynaklar:** [record — pub.dev](https://pub.dev/packages/record) · [IosRecordConfig API (manageAudioSession YOK)](https://pub.dev/documentation/record_platform_interface/latest/record_platform_interface/IosRecordConfig-class.html) · [audioplayers 6.5.0 changelog (v4.0.0 global iOS context)](https://pub.dev/packages/audioplayers/versions/6.5.0/changelog) · [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/) · [R2 S3 API uyumluluğu](https://developers.cloudflare.com/r2/api/s3/api/) · [R2 pricing (egress ücretsiz, DeleteObject ücretsiz)](https://developers.cloudflare.com/r2/pricing/)