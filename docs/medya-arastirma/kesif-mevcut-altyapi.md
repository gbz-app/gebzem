# GEBZEM — SOHBET/MESAJLAŞMA ALTYAPISI ENVANTERİ

Tüm iddialar kaynaktan doğrulandı; dosya:satır verildi. Yol kökü: `C:/Users/gebze/OneDrive/Desktop/gbz-a3/`

---

## 1. BACKEND — `backend/internal/chat/`

Sadece 2 dosya: `handler.go` (442 satır), `hub.go` (137 satır). Router: `backend/cmd/api/main.go:157-162`.

### 1.1 Uçlar (main.go:157-162) — TAMAMI
| Uç | Handler | Satır |
|---|---|---|
| `GET /ws` | `chatH.WebSocket` | handler.go:35 |
| `GET /chats` | `ListChats` | handler.go:323 |
| `POST /chats/direct` | `CreateDirect` | handler.go:269 |
| `GET /chats/{chatID}/messages` | `GetMessages` | handler.go:217 |
| `POST /chats/{chatID}/messages` | `SendMessage` | handler.go:133 |
| `POST /chats/{chatID}/read` | `MarkRead` | handler.go:387 |

**Mesaj SİLME veya DÜZENLEME ucu YOK.** Grup oluşturma/üye ekleme ucu YOK (`chats` tablosu `group` tipini destekliyor ama sadece `direct` açılabiliyor — handler.go:306 `VALUES ('direct',$1)` sabit).

### 1.2 SendMessage tam akışı (handler.go:133-214)
1. **İstek gövdesi** (handler.go:125-130): `type`, `content`, `media_url`, `reply_to_id`. **`media_url` alanı BUGÜN DE KABUL EDİLİYOR ve DB'ye yazılıyor** (handler.go:169-171) — yani şema medyaya hazır, eksik olan sadece dosyanın nereye yükleneceği.
2. `type` boşsa `text` (handler.go:142-144).
3. **Tip beyaz listesi** (handler.go:152-157): `text, image, video, audio, location`. `system` bilerek dışarıda (kimlik taklidi açığı, turu 59b).
4. **Üyelik kontrolü**: `chatMemberIDs` (handler.go:160) → yoksa 403.
5. **INSERT** (handler.go:168-171) → `id, created_at` döner.
6. **Teslim kaydı**: her alıcı için `message_receipts` INSERT (handler.go:179-183) — döngü içinde tek tek, transaction YOK, hata YUTULUYOR.
7. **WS yayını** (handler.go:190): `Event{Type:"message.new", ChatID, Payload, To: members}`.
8. **Push** (handler.go:193-211): gönderen adı + önizleme. Tip→metin eşlemesi handler.go:197-206 (`image`→"Fotoğraf", `video`→"Video", `audio`→"Sesli mesaj", `location`→"Konum").
9. **Yanıt** (handler.go:213): `{id, created_at}` — tam mesaj nesnesi DÖNMEZ.

### 1.3 GetMessages / sayfalama (handler.go:217-266)
- Sayfalama **VAR**: `?before_id=` + `?limit=` (varsayılan 50, tavan 100) — handler.go:225-232.
- Sıralama `ORDER BY id DESC` (yeni→eski).
- `deleted_for_all` ise `content` ve `media_url` boş string olarak döner (handler.go:236-237).
- Dönen alanlar (handler.go:247-256): `id, sender_id, type, content, media_url, reply_to_id, deleted_for_all, created_at`. **`read` / teslim bilgisi DÖNMEZ.**

### 1.4 Okundu bilgisi (MarkRead, handler.go:387-406)
- Sohbetteki tüm okunmamış makbuzları `read_at=now()` yapar (toplu, mesaj bazlı değil).
- WS `receipt.read` yayınlar (payload: `chat_id`, `reader_id`) — handler.go:403-404.
- `delivered_at` sütunu var ama **HİÇBİR YERDE YAZILMIYOR** (tek tik/çift tik ayrımı fiilen yok).

### 1.5 WS olayları ve Redis pub/sub (hub.go)
- Desen: PostgreSQL'e yaz → `rdb.Publish(ctx, "events", ...)` (hub.go:64-70) → `Hub.Run` abone (hub.go:43-61) → `deliver` (hub.go:79-104) → istemci soketi.
- `Event` yapısı (hub.go:30-36): `type, chat_id, payload, to[], broadcast`.
- Kanal adı tek: `"events"`.
- İstemciden sunucuya kabul edilen olaylar sadece 2 tane (handler.go:105-121): `bg` (offline sinyali) ve `typing`. **Başka hiçbir istemci olayı işlenmiyor.**
- Gönderim kuyruğu dolu ise mesaj **sessizce düşürülür** (hub.go:99-101) — geçmiş REST'ten gelir varsayımı.
- WS ping/pong: 15sn ping, 35sn okuma zaman aşımı (handler.go:47, 89-94).

### 1.6 Yetki / blok / rate limit
- **Üyelik**: `chatMemberIDs` (handler.go:409-431) — her uçta çağrılıyor, doğru.
- **BLOK KONTROLÜ SADECE `CreateDirect`'te** (handler.go:281-288). `SendMessage`, `GetMessages`, `MarkRead`'de blok kontrolü **YOK** → sohbet bir kez açıldıktan sonra engelleme mesajlaşmayı durdurmuyor. (Doğrulama: `grep -rn "blocks" --include=*.go` → chat paketinde tek eşleşme handler.go:282.)
- **RATE LIMIT YOK.** `rooms/handler.go:402` (10sn el kaldırma) ve `streams/handler.go:445` (2sn yayın sohbeti) throttle'ları var; **chat paketinde hiçbiri yok**.
- **Gövde boyutu sınırı YOK** — `main.go:96-102` middleware zinciri sadece `RequestID, RealIP, Logger, sentryhttp, Recoverer`. `http.MaxBytesReader` / `middleware.RequestSize` hiçbir yerde yok.
- **`content` uzunluk doğrulaması YOK** (DB'de de sınırsız TEXT).

### 1.7 Backend'de bulduğum hatalar (medya işine dokunuyor)
- **`preview[:80]` UTF-8 kesme hatası** — handler.go:207-209. `preview` byte olarak kesiliyor; Türkçe karakter çok baytlı olduğu için 80. baytta ortadan bölünebilir → push gövdesine geçersiz UTF-8 gider. Doğrusu `[]rune` üzerinden kesmek.
- **Gönderenin DİĞER CİHAZLARI `message.new` ALMAZ.** `chatMemberIDs` gönderenin kendisini listeden ÇIKARIYOR (handler.go:421-425), `To: members` de bu liste (handler.go:190). Hub yalnız `ev.To`ya dağıtır (hub.go:96-103). Çok cihazlı kullanımda kendi mesajın diğer cihazında görünmez.
- **`message_receipts` INSERT döngüsü hatasız varsayılıyor** (handler.go:179-183) — bir alıcı için başarısız olursa o kişide okunmamış sayacı sonsuza kadar yanlış kalır, log bile düşmez.

---

## 2. VERİTABANI ŞEMASI

Migration klasörü: `backend/internal/database/migrations/` — **001…013**. `messages`/`chats`/`chat_members`/`message_receipts` tablolarına **yalnızca 001_init.sql dokunuyor**; 002-013 arasında hiçbir ALTER yok (tek istisna 007_group_calls.sql:6 → `calls.chat_id` FK ekliyor). Doğrulama: `grep -n "messages|chats|chat_members|message_receipts"` çıktısı yukarıdaki tarama.

**Yeni migration numarası: `014_...`**

### `messages` (001_init.sql:51-62)
| Sütun | Tip | Null | Default | Not |
|---|---|---|---|---|
| `id` | BIGSERIAL | NO | seq | PK |
| `chat_id` | UUID | NO | — | FK chats ON DELETE CASCADE |
| `sender_id` | UUID | NO | — | FK users (CASCADE YOK) |
| `type` | TEXT | NO | `'text'` | **CHECK IN ('text','image','video','audio','location','system')** — 001:55 |
| `content` | TEXT | NO | `''` | **Sınırsız uzunluk.** Yorum: "metin ya da konum lat,lng" |
| `media_url` | TEXT | NO | `''` | **Zaten var, kullanılmıyor** |
| `reply_to_id` | BIGINT | YES | — | FK messages(id) — kendine referans |
| `deleted_for_all` | BOOLEAN | NO | FALSE | |
| `created_at` | TIMESTAMPTZ | NO | now() | |

Index: `idx_messages_chat (chat_id, id DESC)` — 001:62. **`updated_at`/`edited_at` YOK → düzenleme desteklenmiyor.** Medya için gerekli olan `mime_type`, `size`, `width`, `height`, `duration`, `thumb_url`, `blurhash` gibi hiçbir sütun YOK.

### `chats` (001:30-37)
`id UUID PK`, `type TEXT NOT NULL DEFAULT 'direct' CHECK IN ('direct','group','channel')`, `title TEXT ''`, `avatar_url TEXT ''`, `created_by UUID FK users`, `created_at`.

### `chat_members` (001:39-49)
`chat_id UUID FK CASCADE`, `user_id UUID FK CASCADE`, `role TEXT 'member' CHECK IN ('member','admin','owner')`, `pinned BOOL false`, `archived BOOL false`, `muted_until TIMESTAMPTZ NULL`, `joined_at`. PK `(chat_id,user_id)`. Index `idx_members_user (user_id)`.

### `message_receipts` (001:65-71)
`message_id BIGINT FK CASCADE`, `user_id UUID FK CASCADE`, `delivered_at TIMESTAMPTZ NULL` (**hiç yazılmıyor**), `read_at TIMESTAMPTZ NULL`. PK `(message_id,user_id)`. **`user_id` üzerinde ayrı index YOK** — `ListChats`'teki okunmamış sayacı alt sorgusu (handler.go:333-335) her sohbet için bu tabloyu tarıyor.

### `blocks` (001:74-79)
`blocker_id`, `blocked_id`, PK ikili.

### Mesaj silme/düzenleme durumu
- **Silme: yarım.** `deleted_for_all` sütunu var, `GetMessages` (handler.go:236-238) ve `ListChats` (handler.go:347) OKUYOR, Flutter "Bu mesaj silindi" balonunu ÇİZİYOR (chat_screen.dart:647-650) — ama sütunu **YAZAN hiçbir kod yok**. Doğrulama: `grep -rn "deleted_for_all" --include=*.go` → sadece 5 okuma eşleşmesi, 0 UPDATE. Yani bu dal bugün **ULAŞILAMAZ KOD**.
- **Düzenleme: hiç yok.**

### `system` mesajını yazan yerler (beyaz listeyi atlayanlar — bilerek)
- `backend/internal/calls/handler.go:1654` (1:1 arama kaydı, `read_at` dolu doğuyor — 1665)
- `backend/internal/calls/grup_sohbet.go:105` (grup arama kaydı)

---

## 3. FLUTTER — `mobile/lib/features/chats/` (6 dosya, 1504 satır)

### 3.1 `models.dart` (85 satır)
- **`Chat`** (satır 2-49): `id, type, title, avatarUrl, pinned, archived, lastMessage, lastType, lastSenderId, lastAt, unread, peerId`.
- **`Message`** (satır 52-85): `id(int), senderId, type, content, mediaUrl, replyToId, deletedForAll, createdAt, read(bool, sadece istemci)`.
  - `mediaUrl` **zaten parse ediliyor** (satır 80) — hiçbir yerde KULLANILMIYOR.
  - `read` sunucudan gelmez; varsayılan `false` (satır 62).
  - Medya için gereken alanların hiçbiri yok (boyut, süre, thumb, yerel dosya yolu, yükleme durumu).

### 3.2 `chats_provider.dart` (123 satır) — VERİ KATMANI
- `ChatsNotifier` (10-45): `GET /chats`; WS'te `message.new`/`receipt.read` gelince **listenin TAMAMINI yeniden çeker** (satır 30-35).
- `MessagesNotifier` (48-119):
  - `load()` (61-75): `GET /chats/$chatId/messages` — **`before_id`/`limit` HİÇ KULLANILMIYOR** → yalnızca son 50 mesaj, **yukarı kaydırıp eskiye gitme YOK**. Sayfalama sunucuda var, istemcide hiç bağlanmamış.
  - `send()` (77-83): gövde sadece `{'type','content'}` — **`media_url` ve `reply_to_id` GÖNDERİLMİYOR**. Ardından `await load()` ile tüm listeyi tazeler (iyimser ekleme yok, ilerleme göstergesi yok).
  - `_onEvent` (85-112): `message.new` → listeye ekle + okundu işaretle; `receipt.read` → **tüm mesajlara `m.read = true`** (satır 103-105, ayrım yapmıyor); `typing` → zaman damgası.
  - Provider `family.autoDispose` (121-123) → ekran kapanınca durum kaybolur, her açılışta yeniden çeker.

### 3.3 `chat_screen.dart` (674 satır) — EKRAN
- `_ChatScreenState` (34-314): giriş alanı, typing throttle (2sn, satır 99-104), presence yoklaması (15sn, satır 60), arama başlatma (136-163).
- **Mesaj listesi** (235-265): `ListView.builder`, `itemCount: list.length + 1` (son eleman aktif arama balonu). `msg.type == 'system'` → `_CallLogChip`, **aksi halde KOŞULSUZ `_Bubble`** (satır 251-261).
- **`_Bubble` (610-674): `Text(message.content)` — TİP AYRIMI YOK.** Satır 652. Bugün bir `image` mesajı gelse ekranda boş/ham metin görünür, `media_url` hiç çizilmez. **Medya balonlarının ekleneceği ASIL NOKTA burası.**
- **Giriş çubuğu** (269-303): `TextField` + `FloatingActionButton.small(send)`. **Ataç/medya butonu YOK** — satır 291'de kod içinde yer tutucu yorum duruyor: `// Faz 2: atas (medya) butonu buraya`.
- `_CallLogChip` (406-608): arama kaydı kartı (Messenger tarzı), `AramaKaydi.coz` kullanır.
- `_AktifAramaBalonu` (347-401): küçültülmüş aramaya dönüş balonu.

### 3.4 `chats_screen.dart` (360 satır) — SOHBET LİSTESİ
- `_previewIkon()` (219-236): `image`→`LucideIcons.image`, `video`→`video`, `audio`→`mic`, `location`→`mapPin`, `system`→arama ikonu. **Medya tipleri İÇİN İKON ZATEN HAZIR.**
- `_preview()` (238-260): `'Fotoğraf' / 'Video' / 'Sesli mesaj' / 'Konum'` metinleri **ZATEN YAZILMIŞ**.
- Yani sohbet listesi önizlemesi medyaya hazır; sadece o tipte mesaj hiç üretilmiyor.
- Avatar: `NetworkImage(chat.avatarUrl)` (satır 171, 274) — önbellek paketi yok.

### 3.5 `arama_kaydi.dart` (93 satır)
`call:missed:*`, `call:ended:*:<sn>`, `call:group:*` ayrıştırmasının TEK kaynağı. Medyayla ilgisi yok ama **sözleşme önemli**: tanınmayan `system` içeriği ham basılmaz (satır 14-15).

### 3.6 `user_search_screen.dart` (169 satır)
Kullanıcı arama + `POST /chats/direct`. Medyayla ilgisi yok.

---

## 4. `mobile/lib/core/` — AĞ KATMANI

### `api.dart` (87 satır)
- Dio yapılandırması (satır 22-26): `baseUrl: apiUrl`, `connectTimeout: 10sn`, `receiveTimeout: 20sn`. **`sendTimeout` TANIMSIZ** → büyük dosya yüklemede varsayılan (sonsuz) davranış.
- `onRequest` (34-40): Bearer token secure storage'dan.
- `onError` 401 (41-64): oturumu siler + `authProvider` invalidate. **Muafiyetler** (52-57): `/auth/`, `/calls/`, `/users/me/voip-token`, `/users/me/fcm-token`. ⚠️ Yeni yükleme ucu bu muafiyet listesinde OLMAMALI (normal 401 davranışı doğru).
- `oturumBitiyor` tek-seferlik kilidi (satır 31, 62): 3sn.
- `dio.addSentry()` (satır 69).
- `apiErrorMessage()` (75-87): sunucunun `{"error": "..."}` alanını aynen gösterir.
- **Yükleme için bugün mevcut olan: HİÇBİR ŞEY.** `FormData`, `MultipartFile`, `onSendProgress` kullanımı tüm `mobile/lib` içinde **0 eşleşme** (doğrulandı).

### `storage.dart` (44 satır)
`flutter_secure_storage` ile yalnızca `auth_token` + `user_id`. iOS `first_unlock` erişilebilirliği (satır 10-13). **Dosya/medya önbelleği için hiçbir şey yok; `path_provider` bağımlılığı da yok.**

### `ws.dart` (138 satır)
`IOWebSocketChannel`, `?token=` ile bağlanır (satır 62-65), 20sn ping, artan bekleme ile yeniden bağlanma (85-92), `goOffline()` ile `bg` çerçevesi (108-121). İstemciden yalnızca `typing` gönderilir (95-99).

---

## 5. MEVCUT "MEDYA BENZERİ" ÖRNEKLER — HEPSİ SAHTE ÇIKTI

Doğrulama taramaları (hepsi 0 eşleşme): backend'de `r2|s3|presign|multipart|FormFile|aws` → **0**; `go.mod`'da hiçbir bulut/depolama bağımlılığı yok (yalnız chi, pgx, redis, websocket, jwt, sentry, crypto, net).

1. **Avatar — YÜKLEME AKIŞI YOK.**
   - Sunucu: `PATCH /users/me` `avatar_url` alanını kabul eder (`users/handler.go:144-167`) ama bu sadece **düz metin URL yazar**, dosya almaz.
   - İstemci: `mobile/lib` içinde `.patch(` veya `.put(` kullanımı **0 eşleşme** → bu ucu çağıran hiçbir kod yok. `features/` altında profil/ayarlar ekranı da yok (klasörler: auth, calls, chats, home, invites, live, rooms).
   - Sonuç: **`avatar_url` prototipte her zaman boş.** 7 yerdeki `NetworkImage(...)` (calls_tab.dart:98, group_call_start_screen.dart:154, incoming_call_overlay.dart:368/469, chats_screen.dart:171/274, user_search_screen.dart:155) fiilen hiç resim yüklemiyor, hep harf/ikon yedeğine düşüyor.
   - Ayrıca `cached_network_image` yok → disk önbelleği yok, yalnız Flutter'ın bellek içi `ImageCache`'i.

2. **Hediye görselleri — GÖRSEL DEĞİL, EMOJİ.** `backend/internal/streams/gifts.go:21` (`Emoji string`), `:124` (katalog sunucuda), `:282` (LiveKit data kanalıyla `"emoji": g.Emoji` yayını). Yani hediyeler **dosya değil karakter**; hiçbir depolama kullanmıyor. (CLAUDE.md'deki "hediye simgeleri bilinçli bırakıldı, kullanıcı kararı bekleniyor" notuyla tutarlı.)

3. **R2 bucket'ları**: `gebzem-media` var ama koda **hiç bağlanmamış**; `gebzem-dist` yalnız APK/IPA dağıtımı için `scratchpad/r2put.js` ile kullanılıyor (uygulama kodu değil, dağıtım aracı).

**Özet: Gebzem'de bugün kullanıcı üretimi hiçbir dosya hiçbir yere yüklenmiyor. Sıfırdan kurulacak.**

---

## 6. MEDYA EKLEMEK İÇİN DOKUNULMASI GEREKEN YERLER

### A. Yeni backend paketi (SIFIRDAN — bugün karşılığı yok)
- `backend/internal/storage/` (yeni): R2 imzalama. Seçenek 1 = presigned PUT üretimi (S3 SigV4; `aws-sdk-go-v2` eklenir ya da elle SigV4 — `scratchpad/r2put.js` zaten elle SigV4 yapıyor, desen mevcut). Seçenek 2 = sunucu üzerinden proxy yükleme (cx33 tek makine, bant genişliği maliyeti; presign tercih edilmeli).
- Yeni uçlar `main.go:145-210` korumalı grubuna eklenecek — örn. `POST /media/upload-url` (presign) + `POST /media/complete` (doğrulama). **Uç adı ne olursa olsun `api.dart:52-57`'deki 401 muafiyet listesine EKLENMEMELİ.**
- `backend/internal/config/` (config.Load): R2 hesap kimliği, bucket, erişim anahtarları, public CDN kökü için yeni env alanları. **`.env.infra` ve `backend/.env` git'e girmez.**

### B. Değişecek backend dosyaları
| Dosya:satır | Değişiklik |
|---|---|
| `chat/handler.go:152-157` | Tip beyaz listesi zaten `image/video/audio/location` içeriyor — **DOKUNMA**. `system` EKLEME. |
| `chat/handler.go:125-130` | `sendMessageReq`'e medya meta alanları (`mime`, `size`, `duration`, `width`, `height`, `thumb_url`) eklenecek |
| `chat/handler.go:168-171` | INSERT yeni sütunları da yazacak |
| `chat/handler.go:234-256` | SELECT + `msg` struct yeni sütunları döndürecek |
| `chat/handler.go:207-209` | **HATA: `preview[:80]` byte kesme → `[]rune` ile düzeltilmeli** |
| `chat/handler.go:160` | **Blok kontrolü SendMessage'a eklenmeli** (bugün yalnız CreateDirect'te, handler.go:281-288) |
| `chat/handler.go:133` | **Rate limit yok** — medya spam'i için gerekli (desen: `streams/handler.go:445` Redis throttle) |
| `main.go:96-102` | **Gövde boyutu sınırı yok** — `http.MaxBytesReader` / `middleware.RequestSize` eklenmeli |
| `chat/handler.go:190` | `To: members` gönderenin kendi cihazlarını dışlıyor — çok cihazlı yükleme senkronu isteniyorsa `chatMemberIDs`'in davranışı (handler.go:421-425) gözden geçirilmeli |
| `chat/handler.go:236-237` | Medya silinince R2 nesnesinin de temizlenmesi kararı (5651 "4 saat içinde kaldırma" yükümlülüğüyle bağlantılı) |

### C. Veritabanı
- **`014_media.sql`** (sonraki numara — 013 son): `messages` tablosuna `mime_type TEXT ''`, `file_size BIGINT 0`, `duration_ms INT 0`, `width INT 0`, `height INT 0`, `thumb_url TEXT ''` (additive, `DEFAULT` + `NOT NULL` ile geriye uyumlu).
- `type` CHECK'i (001_init.sql:55) **zaten `image/video/audio/location` içeriyor** → yeni tip eklenmezse CHECK'e dokunmaya gerek YOK. `document`/`file` gibi yeni tip istenirse CHECK ALTER edilmeli.
- **Mesaj silme istenirse**: `deleted_for_all`'ı yazan uç yok (bugün ölü kod) — `DELETE /chats/{chatID}/messages/{id}` eklenmeli.
- Öneri: `message_receipts (user_id, read_at)` index — okunmamış sayacı alt sorgusu için (`chat/handler.go:333-335`). *Ölçülmedi, gözlem.*

### D. WebSocket
- **Yeni olay tipi GEREKMEZ**: `message.new` payload'ı (handler.go:185-189) genişletilerek medya alanları taşınabilir. `hub.go`'da hiçbir değişiklik gerekmiyor (`Event.Payload` ham JSON — hub.go:33).
- Yükleme ilerlemesi WS'ten gitmemeli (yerel durum; sunucuya yük bindirmesin).

### E. Flutter — pubspec.yaml
Bugün **hiçbiri yok**, eklenecekler: `image_picker` (galeri/kamera), `record` veya muadili (sesli mesaj), `path_provider` (geçici dosya + önbellek), `flutter_image_compress` (yükleme öncesi küçültme), `video_player`/`chewie` (video oynatma), `cached_network_image` (disk önbelleği), konum için `geolocator` + harita (**`cloudMapId` KULLANMA**, OSMF bedava tile YASAK).
⚠️ `flutter_webrtc: 1.4.0` **pinli** (livekit ile çakışmasın) — yeni paketlerin bunu yukarı çekmediği doğrulanmalı. `sentry_flutter` 9.x, `permission_handler ^12.0.3` zaten var (kamera/mikrofon/galeri izinleri için yeniden kurulum gerekmez).

### F. Flutter — değişecek dosyalar
| Dosya:satır | Değişiklik |
|---|---|
| `chats/models.dart:52-85` | `Message`'a medya meta alanları + yerel yükleme durumu (`gonderiliyor`, `yerelYol`, `ilerleme`) |
| `chats/chats_provider.dart:77-83` | `send()` `media_url` ve `reply_to_id` göndermiyor — imza genişletilecek; iyimser ekleme + ilerleme için `send()` yeniden yazılacak (`await load()` deseni yükleme sırasında kullanılamaz) |
| `chats/chats_provider.dart:61-75` | `before_id`/`limit` kullanılmıyor → **yukarı kaydırma sayfalaması eklenmeli** (medya sohbetinde 50 mesaj sınırı daha çabuk vuruyor) |
| `chats/chat_screen.dart:610-674` | **`_Bubble` ASIL NOKTA** — `message.type` switch'i + `_ImageBubble`/`_VideoBubble`/`_AudioBubble`/`_LocationBubble` |
| `chats/chat_screen.dart:269-303` | Giriş çubuğuna ataç butonu (satır 291'deki yer tutucu yorumun yeri) + alttan medya seçim paneli |
| `chats/chat_screen.dart:251-261` | `system`/`_Bubble` dallanması korunacak; medya dalı `_Bubble` içinde çözülmeli |
| `chats/chats_screen.dart:219-260` | `_previewIkon()` + `_preview()` **ZATEN HAZIR** — dokunmaya gerek yok |
| `core/api.dart:22-26` | **`sendTimeout` eklenmeli** (bugün tanımsız); büyük dosya için ayrı Dio örneği veya per-request `Options` |
| `core/api.dart:52-57` | Yeni yükleme ucu **muafiyet listesine EKLENMEYECEK** |
| `core/storage.dart` | Medya disk önbelleği için ayrı katman gerekir (secure storage uygun değil — `path_provider`) |
| **Yeni** `chats/medya_yukle.dart` | Seç → sıkıştır → presign al → R2'ye PUT (`onSendProgress`) → `POST /chats/{id}/messages` zinciri; iptal/tekrar deneme |

### G. Kural uyumu (plan bunlara uymak zorunda)
- **Arayüzde emoji YOK** — tüm yeni ikonlar Lucide (2B). Medya balonlarında oynat/duraklat/indir ikonları Lucide olacak (CLAUDE.md turu 62).
- Tüm kullanıcıya görünen metinler **Türkçe ve doğru Türkçe karakterli** (turu 63 süpürgesi).
- Sunucu hataları SnackBar'da aynen gösteriliyor (`api.dart:80`) → yeni uçların `error` mesajları Türkçe yazılmalı.
- Yorumlar bilerek ASCII (regex/encoding tuzağı).
- cx33 tek makine + LiveKit aynı makinede → medya trafiği **sunucudan geçmemeli** (presign zorunlu).
- 5651: yüklenen içeriğin 4 saat içinde kaldırılabilmesi → admin tarafında medya silme + R2 nesne temizliği düşünülmeli.

---

## 7. DOĞRULANMIŞ "YOK" LİSTESİ (bir daha aramaya gerek yok)
- Backend'de R2/S3/presign/multipart/AWS kodu: **0 eşleşme**
- `go.mod`'da depolama bağımlılığı: **yok**
- Flutter'da `FormData`/`MultipartFile`/`onSendProgress`: **0 eşleşme**
- Flutter'da `.patch(`/`.put(`: **0 eşleşme** (profil güncelleme ekranı yok)
- Chat paketinde rate limit / gövde sınırı: **yok**
- Mesaj silme/düzenleme ucu: **yok** (`deleted_for_all` yalnız okunuyor)
- `delivered_at` yazan kod: **yok**
- Sohbet ekranında ataç/medya arayüzü: **yok** (satır 291'de sadece yorum)
- `features/` altında profil veya ayarlar ekranı: **yok**