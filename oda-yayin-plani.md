# Gebzem — Spaces (Sesli Oda) + Canlı Yayın UYGULAMA PLANI
> 18 Tem 2026 gece. Kaynak: wf_853d55bc (3 uzman plan + eleştirmen çatlak analizi).
> Strateji: arama-yol-haritasi.md (16 Tem). SIRA (kullanıcı onaylı): ODA bitir + build →
> kapsamlı test → CANLI YAYIN → arayüz → güvenlik denetimi.

## BAĞLAYICI KARARLAR (eleştirmen düzeltmeleri — planlardaki çelişkilerde BU LİSTE kazanır)
1. Twirp istemcisi TEK paket: `internal/livekit`; adres env `LIVEKIT_API_URL=http://167.233.229.88:7880`.
2. Oda Create'te LiveKit CreateRoom override ŞART (maxParticipants=520) — livekit.yaml global max_participants:32 tavanını aşmanın tek yolu. Join'de auto-create'e asla düşme.
3. Sözleşme: uçlar /rooms + /streams; LiveKit oda önekleri oda_ / stream_; WS olay adları Plan-1 seti
   (room.participant.joined/left, room.hand.raised, room.role.changed, room.participant.muted, room.ended);
   canlı yayın yaşam döngüsü/sayaç SendData (Plan-2 seti); izleyici≤300, konuşmacı≤10; hediye kataloğu backend'den GET.
4. Yayın chat/kalp kararı: Faz-1'de viewer grant data KAPALI kalır; chat REST → backend SendData relay. (P3-Adım 9 buna göre.)
5. Migration numaraları: rooms=008, streams=009.
6. livekit-compose.yml image v1.13.3'e PINLENIR (latest tehlikeli); port işi tek bakım penceresi + 1:1 regresyon.
7. Oda/yayın istemci token exp=8h (calls 4h kalır); reconnect test listesinde.
8. Fan-out: speaker join/left/role HERKESE; listener join/left yalnız host+speaker'a.
9. Gift idempotency indeksi (user_id, reason, ref_id).
10. 5651: room_audit (P1) + stream_audit (FK'sız, append-only) — TRUNCATE rutini bunları silmez (FK yok);
    yayın öncesi TRUNCATE rutini zaten kalkacak.


---

# BÖLÜM 1: SPACES BACKEND (uzman planı)

Gerekli dosyaları okudum (yol haritası, grup planı formatı, handler.go 1518 satır, hub.go, migration 007, main.go). Plan aşağıda — bu benim nihai çıktım.

# GEBZEM SPACES (SESLİ ODA) — BACKEND UYGULAMA PLANI

> Model (arama-yol-haritasi.md §3, sorgulanmadı): tek LiveKit odası, roller = token grant; dinleyici `canPublish:false` → uplink yok, SFU yükü yalnız konuşmacıyla artar. Rol kaynağı **DB** (metadata race #1829 nedeniyle metadata KULLANILMAZ). Moderasyon tamamı **sunucu taraflı** RoomService çağrısı.
> İZOLASYON: `internal/calls` ve `calls`/`call_participants` tablolarına DOKUNULMAZ. Yeni paket `internal/rooms`, yeni tablolar, LiveKit oda adı öneki `oda_` (`call_` ile log karışmaz — CLAUDE.md log-filtre tuzağı). Spaces in-app'tir: CallKit/VoIP push YOK, zil YOK.

---

## 0) ÖN KARAR — RoomService çağrı yöntemi: SDK EKLEME, ham twirp HTTP

- LiveKit server API'si twirp'tür: `POST {http_base}/twirp/livekit.RoomService/{Metot}` + JSON gövde + `Authorization: Bearer <admin-jwt>`. Admin JWT'yi zaten elimizdeki `golang-jwt` ile (handler.go:132'deki `token()` deseninin aynısı) üretebiliriz; tek fark grant: `{"video":{"roomAdmin":true,"room":"oda_<id>"}}` (DeleteRoom için `"roomCreate":true`).
- `livekit/server-sdk-go` EKLEMİYORUZ: protobuf + psrpc zinciri sürüklüyor, bize 4 metot lazım (UpdateParticipant, GetParticipant, MutePublishedTrack, RemoveParticipant, DeleteRoom). Ham HTTP ~80 satır, bağımlılık sıfır.
- Taban adres: yeni env `LIVEKIT_API_URL` (varsayılan: `LIVEKIT_URL`'den türet, `wss://` → `https://` = `https://rtc.gebzem.app`; Caddy zaten 7880'e proxy'liyor, twirp düz HTTP POST olduğundan geçer).

---

## 1) VERİ MODELİ — `backend/internal/database/migrations/008_rooms.sql` (yeni)

- DOSYA: `backend/internal/database/migrations/008_rooms.sql`
- NE DEGISIR (tamamı additive; `calls` tablosuna dokunmaz):
  ```sql
  CREATE TABLE IF NOT EXISTS rooms (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id    UUID NOT NULL REFERENCES users(id),
    title      TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live','ended')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at   TIMESTAMPTZ
  );
  CREATE INDEX IF NOT EXISTS idx_rooms_live ON rooms(created_at DESC) WHERE status='live';

  CREATE TABLE IF NOT EXISTS room_participants (
    room_id        UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role           TEXT NOT NULL DEFAULT 'listener' CHECK (role IN ('host','speaker','listener')),
    status         TEXT NOT NULL DEFAULT 'joined'   CHECK (status IN ('joined','left','removed')),
    hand_raised_at TIMESTAMPTZ,          -- NULL = el kalkik degil
    joined_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at        TIMESTAMPTZ,
    PRIMARY KEY (room_id, user_id)
  );
  CREATE INDEX IF NOT EXISTS idx_room_participants_room
      ON room_participants (room_id) WHERE status='joined';

  -- 5651 minimal iz: append-only, satir SILINMEZ/GUNCELLENMEZ (join/leave/promote/demote/mute/remove/end)
  CREATE TABLE IF NOT EXISTS room_audit (
    id      BIGSERIAL PRIMARY KEY,
    room_id UUID NOT NULL,
    user_id UUID,
    action  TEXT NOT NULL,
    ip      TEXT,
    at      TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ```
- NEDEN: `call_participants` deseni (007) birebir örnek alındı ama AYRI tablo — Spaces yaşam döngüsü (rol değişimi, el kaldırma, saatlerce açık oda) arama durum makinesiyle uyumsuz; ortak tablo 1:1/grup regresyon riski demek. `room_participants` tek satır/kullanıcı: yeniden girişte `status` sıfırlanır ama 5651 izi `room_audit`'te korunur (giren/çıkan + zaman + IP; `middleware.RealIP` zaten var). CHECK'ler rol/durum yazım hatasını DB'de yakalar.
- TEST: deploy sonrası `ssh … "docker exec -it backend-postgres-1 psql -U gebzem -c '\d room_participants'"` + 1:1 arama regresyon (`POST /calls` akışı değişmemiş olmalı).

---

## 2) LIVEKIT ROOMSERVICE İSTEMCİSİ — `backend/internal/rooms/livekit.go` (yeni)

- DOSYA: `backend/internal/rooms/livekit.go`
- NE DEGISIR: SDK'sız twirp istemcisi. İskelet:
  ```go
  type LK struct{ base, key, secret string } // base: LIVEKIT_API_URL

  // RoomService icin kisa omurlu admin token (istemci token'indan FARKLI grant)
  func (l *LK) adminToken(room string, deleteRoom bool) (string, error) {
      grant := map[string]any{"roomAdmin": true, "room": room}
      if deleteRoom { grant["roomCreate"] = true } // DeleteRoom roomCreate ister
      claims := jwt.MapClaims{
          "iss": l.key, "sub": "gebzem-api",
          "nbf": time.Now().Add(-10*time.Second).Unix(),
          "exp": time.Now().Add(10*time.Minute).Unix(),
          "video": grant,
      }
      return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(l.secret))
  }

  func (l *LK) call(ctx context.Context, method string, tok string, in, out any) error {
      b, _ := json.Marshal(in)
      req, _ := http.NewRequestWithContext(ctx, "POST",
          l.base+"/twirp/livekit.RoomService/"+method, bytes.NewReader(b))
      req.Header.Set("Content-Type", "application/json")
      req.Header.Set("Authorization", "Bearer "+tok)
      resp, err := http.DefaultClient.Do(req)
      // resp.StatusCode != 200 -> govdeyi logla (twirp hata JSON'i {code,msg}); out'a decode et
  }

  // Somut sarmalayicilar (twirp JSON proto alan adlari — snake_case kabul edilir):
  // UpdateParticipant: {"room":r,"identity":uid,"permission":{"can_subscribe":true,
  //                     "can_publish":canPub,"can_publish_data":canPub,
  //                     "can_publish_sources":["MICROPHONE"]}}   // enum BUYUK harf!
  // GetParticipant:    {"room":r,"identity":uid} -> tracks[]{sid,type,muted}
  // MutePublishedTrack:{"room":r,"identity":uid,"track_sid":sid,"muted":true}
  // RemoveParticipant: {"room":r,"identity":uid}
  // DeleteRoom:        {"room":r}
  ```
- NEDEN: Moderasyonun tamamı bu 5 çağrı. `UpdateParticipant.permission` sunucu tarafında izni ANINDA değiştirir — istemci yeni token/yeniden bağlanma GEREKMEZ (livekit_client `ParticipantPermissionsUpdatedEvent` alır). DİKKAT: token grant'ta kaynak adları küçük harf (`"microphone"`), `permission.can_publish_sources`'ta proto enum (`"MICROPHONE"`) — karıştırma. `metadata` alanına HİÇ dokunma (rol kaynağı DB).
- TEST (endpoint'lerden bağımsız): `node -e` ile aynı HS256 admin token'ı üretip
  `curl -X POST https://rtc.gebzem.app/twirp/livekit.RoomService/ListRooms -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" -d '{}'` → 200 + `{"rooms":[...]}` dönmeli (grant'a `"roomList":true` ekleyerek). 401 dönerse grant/secret yanlış demektir — endpoint yazmadan burada yakala.

---

## 3) PAKET İSKELETİ + ROL BAZLI İSTEMCİ TOKEN'I — `backend/internal/rooms/handler.go` (yeni) + `main.go`

- DOSYA: `backend/internal/rooms/handler.go`, `backend/cmd/api/main.go`
- NE DEGISIR:
  - `rooms.NewHandler(db, hub, lk)` — `calls.NewHandler` deseni; `chat.Hub`'ı aynen alır (WS olayları hazır altyapıdan gider, hub'a dokunulmaz).
  - Rol → grant tablosu (tek fonksiyon `clientToken(room, identity, name, role)`):

    | rol | canPublish | canPublishSources | canSubscribe | canPublishData |
    |---|---|---|---|---|
    | host | true | ["microphone"] | true | true |
    | speaker | true | ["microphone"] | true | true |
    | **listener** | **false** | — | true | **false** |

  - `main.go` korumalı gruba route'lar (calls bloğunun ALTINA, ayrı yorum bloğu):
    ```go
    r.Get("/rooms", roomsH.List)
    r.Post("/rooms", roomsH.Create)
    r.Post("/rooms/{id}/join", roomsH.Join)
    r.Post("/rooms/{id}/leave", roomsH.Leave)
    r.Post("/rooms/{id}/raise-hand", roomsH.RaiseHand)
    r.Post("/rooms/{id}/promote", roomsH.Promote)   // host: {user_id}
    r.Post("/rooms/{id}/demote", roomsH.Demote)     // host: {user_id}
    r.Post("/rooms/{id}/mute", roomsH.Mute)         // host: {user_id}
    r.Post("/rooms/{id}/remove", roomsH.Remove)     // host: {user_id}
    r.Post("/rooms/{id}/end", roomsH.End)           // yalniz host
    ```
- NEDEN: `canPublishSources:["microphone"]` sesli odada video/ekran paylaşımını TOKEN düzeyinde keser (istemci hilesi imkânsız). Dinleyicide `canPublishData:false`: 500 kişilik odada data-spam kapısı kapalı; el kaldırma REST'ten gider (aşağıda), reaksiyonlar ileride ayrıca düşünülür. Oda adı `"oda_"+roomID`.
- TEST: `cd backend && go build ./...` + deploy; `curl https://api.gebzem.app/rooms -H "Authorization: Bearer $JWT"` → `[]` (boş liste), calls uçları regresyonsuz.

---

## 4) ODA AÇ + KEŞFET — `Create` / `List`

- DOSYA: `handler.go`
- NE DEGISIR:
  - `POST /rooms {title}` → `INSERT rooms (host_id,title,status='live')` + `INSERT room_participants (role='host',status='joined')` + `room_audit('create')`. Yanıt: `{room_id, room:"oda_<id>", url:lkURL, token:<host token>, title}`. Muhafız: kullanıcının zaten `live` bir odası varsa 409 (`SELECT 1 FROM rooms WHERE host_id=$1 AND status='live'`) — çift oda/zombi önlenir.
  - `GET /rooms` → keşfet listesi: `status='live'` odalar, host adı/avatarı, başlık, konuşmacı sayısı, dinleyici sayısı, `created_at`; canlı sayılar tek sorguda `count(*) FILTER (WHERE role IN ('host','speaker'))` ile. LIMIT 50, en yeni üstte.
- NEDEN: LiveKit'te odayı ÖNCEDEN yaratmaya gerek yok (ilk katılan bağlanınca otomatik açılır, `CreateRoom` çağrısı gerekmez); DB satırı tek gerçek kaynak. Keşfet sekmesi (`home_screen.dart`'taki "Odalar" yer tutucusu) bu listeyi çekecek.
- TEST: `curl -X POST https://api.gebzem.app/rooms -H "Authorization: Bearer $JWT" -d '{"title":"Deneme"}'` → token dön; `curl …/rooms` → 1 oda + sayılar. `docker logs livekit | grep oda_` ile host bağlanınca `participant active` görülmeli.

---

## 5) KATIL + AYRIL + DİNLEYİCİ KAPASİTE MUHAFIZI — `Join` / `Leave`

- DOSYA: `handler.go`
- NE DEGISIR:
  - `POST /rooms/{id}/join`: oda `live` mi → değilse 404. Daha önce `removed` mu → 403 ("odadan çıkarıldınız"; ban kaydı LiveKit'te YOK, backend'de — yol haritası kararı). KAPASİTE: `count(*) WHERE status='joined' AND role='listener'` **>= 500 → 409 "oda dolu"**. Upsert `room_participants (role='listener', status='joined', joined_at=now(), left_at=NULL, hand_raised_at=NULL)` (`ON CONFLICT (room_id,user_id) DO UPDATE` — ama `role` KORUNUR: ayrılıp dönen speaker rolünü kaybetmez, `removed` upsert'e giremez). `room_audit('join', ip)`. Yanıt: `{room, url, token(rolüne göre!), role, title, host_id}`.
  - `POST /rooms/{id}/leave`: `status='left', left_at=now(), hand_raised_at=NULL` + `room_audit('leave')`. Host leave → odayı BİTİRMEZ (adım 9'daki sweep 2 dk bekler; host geri girebilir — telefon araması gelmesi gibi kısa kesintide oda ölmesin).
  - WS: `room.participant.joined/left {room_id,user_id,name,role,listener_count}` — **yalnız host+speaker'lara** (`role IN ('host','speaker') AND status='joined'` listesi, ≤11 kişi). Dinleyicilere anlık fan-out YOK (500 kişiye her giriş/çıkışta yayın = hub'ı boğar); dinleyici sayısı zaten her olayın `listener_count` alanında gider, dinleyicilerin kendisi sayıyı LiveKit `participants` listesinden görür.
- NEDEN: Dinleyici token'ı `canPublish:false` ile SFU uplink maliyeti sıfır — 500 sınırı cx33 için (yol haritası: tek Space ~200-500; 500 = üst uç, Netdata'da CPU %70 aşarsa düşürülecek tek sabit). Rejoin'de rol koruma UX gereği; `removed` engeli moderasyonun dişi.
- TEST: 2. kullanıcı JWT'siyle join → `token` decode edip (jwt.io) `canPublish:false` DOĞRULA; `docker logs livekit | grep oda_<id>` → 2 participant; leave → host'un WS'inde `room.participant.left`.

---

## 6) EL KALDIR — `RaiseHand`

- DOSYA: `handler.go`
- NE DEGISIR: `POST /rooms/{id}/raise-hand {raised:true|false}` (yalnız `status='joined'` dinleyici): `hand_raised_at=now()` / `NULL`. Throttle: son 10 sn içinde değiştiyse 429. WS `room.hand.raised {room_id,user_id,name,avatar,raised}` → **yalnız host'a**. `room_audit('raise_hand')`. `GET /rooms/{id}` detayına (List'in tekil versiyonu; host UI eli kalkıkları listeler) `hand_raised` alanı.
- NEDEN: Yol haritası "dinleyici data sinyali" diyordu ama dinleyicide `canPublishData:false` (adım 3, spam koruması) → REST + DB tek doğru kaynak: host uygulaması yeniden açılsa bile el listesi DB'den geri gelir (data sinyali uçucuydu, kaybolurdu). Race yok çünkü onay anında rol DB'den okunur.
- TEST: dinleyici curl ile `{"raised":true}` → host WS logunda `room.hand.raised`; aynı curl 5 sn içinde tekrar → 429.

---

## 7) SÖZ VER / SÖZ AL + KONUŞMACI MUHAFIZI — `Promote` / `Demote`

- DOSYA: `handler.go` (+ `livekit.go` çağrıları)
- NE DEGISIR:
  - `Promote {user_id}` (yalnız host): hedef `joined` dinleyici mi → değilse 409. KAPASİTE: `count(*) WHERE role IN ('host','speaker') AND status='joined'` **>= 10 → 409 "konuşmacı sınırı"**. Sıra: **(1)** DB `role='speaker', hand_raised_at=NULL` → **(2)** `lk.UpdateParticipant(oda, uid, canPublish=true)` → LiveKit izni canlı bağlantıya iter, istemci mikrofonu AÇABİLİR (yeniden bağlanma yok) → **(3)** WS `room.role.changed {user_id,role:'speaker'}` HERKESE (host+speaker anlık; dinleyicilere de — rol değişimi seyrek olay, UI'da konuşmacı ızgarası değişmeli) → `room_audit('promote')`. UpdateParticipant HATA verirse DB'yi geri al (rol/izin tutarlılığı — rol kaynağı DB ama LiveKit izniyle senkron kalmalı).
  - `Demote {user_id}`: tersi — DB `role='listener'` + `UpdateParticipant(canPublish=false)` (LiveKit izni düşen participant'ın yayınını sunucu tarafında keser) + WS `room.role.changed`. Host kendini demote EDEMEZ.
- NEDEN: Rol kaynağı DB + izin LiveKit'te permission (metadata DEĞİL) = #1829 race'ine kapalı tasarım. speaker≤10 (host dahil): SFU yükü konuşmacı sayısıyla N×dinleyici çarpanında büyür; 10 konuşmacı × 500 dinleyici Opus cx33'ün rahat sınırı (yol haritası ~20x ses kapasitesi).
- TEST: 3 kullanıcı: dinleyici el kaldırır → host promote curl → dinleyici cihazında mikrofon butonu aktifleşir + `docker logs livekit | grep oda_` içinde o identity için `mediaTrack published`; 11. promote → 409; demote → track sunucuda unpublish.

---

## 8) SUSTUR + AT — `Mute` / `Remove`

- DOSYA: `handler.go` (+ `livekit.go`)
- NE DEGISIR:
  - `Mute {user_id}` (yalnız host, hedef speaker): `lk.GetParticipant(oda, uid)` → `tracks[]` içinden `type=="AUDIO"` sid'leri → her biri için `lk.MutePublishedTrack(oda, uid, sid, muted:true)`. WS `room.participant.muted {user_id}` host+speaker'lara. `room_audit('mute')`. NOT: host UNMUTE EDEMEZ (uzaktan mikrofon açmak mahremiyet ihlali; `livekit.yaml`'a `enable_remote_unmute` EKLEME) — konuşmacı kendisi açar.
  - `Remove {user_id}` (yalnız host): **(1)** DB `status='removed', left_at=now()` → **(2)** `lk.RemoveParticipant(oda, uid)` (bağlantı sunucudan kopar) → **(3)** WS `room.participant.left {user_id, removed:true}` + atılana özel `room.removed` olayı → `room_audit('remove')`. `removed` satırı Join'deki 403 muhafızını besler (adım 5) = kalıcı oda banı; LiveKit'te ban kavramı olmadığından tek yol bu.
- NEDEN: MutePublishedTrack track-sid ister → GetParticipant zorunlu ara adım (somut çözüm; tek RPC ile olmaz). Önce-DB-sonra-LiveKit sırası: RemoveParticipant başarısız olsa bile kullanıcı yeniden join EDEMEZ (403), tutarlılık bozulmaz.
- TEST: host mute curl → konuşmacının sesi kesilir (`docker logs livekit`'te track muted), konuşmacı mikrofonu tekrar açabilir; remove → atılanın bağlantısı düşer, tekrar join → 403.

---

## 9) YAŞAM DÖNGÜSÜ — `End` + sweeper — `backend/internal/rooms/sweep.go` (yeni)

- DOSYA: `handler.go` (`End`), `sweep.go`, `main.go` (StartSweeper çağrısı)
- NE DEGISIR:
  - `POST /rooms/{id}/end` (yalnız host): `rooms.status='ended', ended_at=now()` (ATOMİK: `WHERE status='live'`; 0 satır → zaten bitmiş, sessiz 200 — calls End deseni handler.go:603). WS `room.ended {room_id}` **herkese** (`status='joined'` tüm katılımcılar — oda kapanışı tek seferlik olay, 500 kişiye fan-out kabul). `lk.DeleteRoom(oda)` → tüm bağlantılar sunucudan kopar (WS'i kaçıran istemci bile düşer). Tüm `joined` satırları `status='left'`. `room_audit('end')`.
  - `sweep.go` (calls `StartSweeper` deseni, 30 sn ticker, ayrı goroutine):
    1. **Host kopması:** `live` oda + host satırı `status<>'joined'` VE `left_at < now()-'2 minutes'` → odayı bitir (End ile aynı yol). Co-host devri Faz-2; ilk sürümde "host yoksa oda biter" (Twitter Spaces davranışı). 2 dk tolerans: GSM araması/geçici kopma odayı öldürmesin.
    2. **Boş oda:** `live` + `count(joined)=0` VE `created_at < now()-'2 minutes'` → bitir.
    3. **Emniyet:** `live` VE `created_at < now()-'8 hours'` → bitir (calls'taki 2 saat emniyet şablonu; Spaces uzun olabilir → 8 saat).
    Her kapanışta WS `room.ended` + `DeleteRoom` + audit.
- NEDEN: İstemciden End gelmeme ihtimali calls'ta yaşandı (sweep zorunluluğu kanıtlı — handler.go:56-59 yorumu). `DeleteRoom` olmadan LiveKit odası dinleyicilerle yaşamaya devam eder = hayalet oda. 5651: `room_audit` + `rooms.created_at/ended_at` + docker log = kim/ne zaman/hangi IP asgari izi; saklama süresi (1-2 yıl) yayın öncesi hukukçu maddesine bağlanır (yol haritası yasal notu).
- TEST: host end curl → tüm cihazlarda `room.ended` + LiveKit'te oda silinir (`ListRooms`'ta yok); host'u uygulamadan öldür (force-quit) → ~2,5 dk sonra sweep logu `oda temizleyici: …` + oda `ended`.

---

## 10) (SERTLEŞTİRME — opsiyonel, ilk sürüm SONRASI) LiveKit webhook + istatistik olayı

- DOSYA: `backend/internal/rooms/webhook.go` (yeni) + `livekit.yaml` (webhook bloğu) + `main.go` (`r.Post("/livekit/webhook", …)` — auth GRUBUNUN DIŞINDA, imza doğrulamalı)
- NE DEGISIR: LiveKit `participant_left` / `room_finished` webhook'ları → DB'yi gerçek zamanlı düzelt (uygulaması çöken dinleyici `joined` görünmesin; sweep 30 sn'lik yerine anlık). Webhook gövdesi LiveKit API key'iyle imzalı JWT taşır — `Authorize` başlığını mevcut HS256 doğrulama deseniyle çöz. Ek WS olayı `room.stats {listener_count, speaker_count}` 10 sn'de bir SADECE değişmişse herkese — dinleyici sayacı UI'da canlı akar.
- NEDEN: Calls tarafında "kalıcı çözüm: room_finished webhook" notu zaten düşülmüş (handler.go:121); Spaces'te katılımcı sayısı yüksek olduğundan hayalet `joined` satırları keşfet listesindeki sayıları şişirir. Ama ilk sürüm için sweep YETER — bu adım deploy edilmeden Spaces canlıya çıkabilir.
- TEST: dinleyici uygulamayı öldür → webhook logu + DB satırı `left`; keşfet listesi sayısı düşer.

---

## SIRALAMA + DOĞRULAMA

| # | Adım | Nasıl doğrulanır |
|---|------|------------------|
| 1 | Migration 008 | `\d rooms`; 1:1 + grup arama regresyon testi |
| 2 | twirp istemcisi | `ListRooms` curl 200 (endpoint'lerden bağımsız) |
| 3 | Paket + route + token | `go build ./...`; `GET /rooms` → `[]` |
| 4 | Create/List | curl aç → keşfet listesinde görün; `docker logs livekit \| grep oda_` |
| 5 | Join/Leave + 500 sınırı | 2. kullanıcı token'ında `canPublish:false` (jwt decode) |
| 6 | RaiseHand | host WS'inde `room.hand.raised`; throttle 429 |
| 7 | Promote/Demote + ≤10 | dinleyici mikrofon açabiliyor; 11. promote 409 |
| 8 | Mute/Remove + ban | ses kesildi; atılan tekrar join → 403 |
| 9 | End + sweep | herkese `room.ended`; host force-quit → 2,5 dk'da kapanış |
| 10 | (ops.) webhook | çöken istemci DB'de `left` |

Her adım tek başına deploy edilebilir (calls'a temas sıfır; adım N, N+1 olmadan çalışır). Her adım: commit + push + `git rev-parse origin/main` doğrula; `oturum.md` güncelle (CLAUDE.md kural 1/3).

**Anahtar dosyalar:** yeni `backend/internal/database/migrations/008_rooms.sql`, yeni `backend/internal/rooms/{handler,livekit,sweep}.go` (+ ops. `webhook.go`), değişen yalnız `backend/cmd/api/main.go` (route kaydı) — `backend/internal/calls/` ve `backend/internal/chat/hub.go` DEĞİŞMEZ.

---

# BÖLÜM 2: CANLI YAYIN BACKEND (uzman planı)

# GEBZEM CANLI YAYIN — BACKEND PLANI (prototip: SAF WebRTC, <500 izleyici, HLS YOK)

> Yol haritası kararı: <500 izleyici → saf WebRTC (~300ms, hediye/reaksiyon anlık). Bu plan 1:1/grup arama koduna (internal/calls, migrations 004-007) HİÇ DOKUNMAZ; her adım tek başına deploy+test edilebilir. Oda adı `stream_<id>` (log filtreleme tuzağı: `docker logs livekit | grep stream_`). Keşfet çıktısı mevcut "Canlı" sekme yer tutucusunu (mobile/lib/features/home/home_screen.dart:78, Faz 4 placeholder) besleyecek.

---

## ÖN KARAR A — streams tablosu rooms'tan AYRI (ortak DEĞİL)

- Spaces planı `rooms + room_participants` kuruyor; canlı yayın bunu TEKRAR KULLANMAZ. Gerekçe:
  1. **İzolasyon/deploy sırası:** İki plan paralel; streams'i rooms migration'ına bağlamak hangisi önce deploy edilirse kilitlenme/çakışma yaratır. Ayrı tablo = iki plan bağımsız yaşar (bu görevin ana kuralı).
  2. **Veri şekli farklı:** Spaces'ta katılımcı başına DB satırı ŞART (rol/el kaldırma/speaker durum makinesi). Canlı yayında izleyici başına DB satırı ANTİ-PATTERN: <500 izleyici × sık gir/çık churn'ü = boş yazma yükü; izleyici listesi geçici veridir → Redis. `streams` satırı yalnız yayının yaşam döngüsünü tutar (call_participants'ın grup için yaptığını burada Redis yapar).
  3. Asıl ortaklaşması gereken şey tablo değil, **LiveKit yardımcıları** (token + RoomService istemcisi) → yeni `internal/livekit` paketi (Adım 2); Spaces planı da aynı paketi kullanabilir (promote/demote/mute aynı istemciden geçer).

## ÖN KARAR B — LiveKit Server API: SDK EKLEME, raw twirp HTTP (somut)

- **SDK yok.** Gerekçe: server-sdk-go, protocol+psrpc bağımlılık ağacı getirir; token zaten el-yapımı HS256 (calls/handler.go:132-149 deseni); twirp JSON düz HTTP POST. ~150 satırlık istemci yeter; ileride egress gerekirse SDK'ya geçiş tek dosyada izole kalır.
- **Adres:** env `LIVEKIT_API_URL` (varsayılan `http://167.233.229.88:7880` — ufw'de 7880 açık, bugün compose değişikliği gerektirmez; istenirse compose'a `extra_hosts: host.docker.internal:host-gateway` ekleyip `http://host.docker.internal:7880`).
- **Auth:** `Authorization: Bearer <JWT>` — aynı HS256 el-yapımı JWT, `video` grant'ında `roomAdmin:true` + `room:"stream_<id>"` (SendData/RemoveParticipant/Mute/UpdateParticipant için); `roomCreate:true` + `roomList:true` (CreateRoom/DeleteRoom/ListRooms için).
- **Çağrı biçimi:** `POST {LIVEKIT_API_URL}/twirp/livekit.RoomService/<Method>`, `Content-Type: application/json`, proto3 JSON gövde. Hata = twirp JSON `{"code","msg"}`:
  - `CreateRoom` → `{"name":"stream_x","max_participants":310,"empty_timeout":300,"departure_timeout":60}`
  - `SendData` → `{"room":"stream_x","data":"<base64>","kind":"RELIABLE","topic":"gift"}` (proto3 JSON'da bytes = base64 string)
  - `RemoveParticipant` → `{"room":"stream_x","identity":"<user_id>"}`
  - `MutePublishedTrack` → `{"room":"stream_x","identity":"...","track_sid":"TR_...","muted":true}`
  - `UpdateParticipant` → `{"room":"stream_x","identity":"...","permission":{"can_publish":false,"can_subscribe":true,"can_publish_data":false}}`
  - `DeleteRoom` → `{"room":"stream_x"}` · `ListParticipants` → `{"room":"stream_x"}`

---

## ADIM 1 — Migration `008_streams.sql`
- DOSYA: `backend/internal/database/migrations/008_streams.sql` (yeni)
- NE DEGISIR:
  ```sql
  CREATE TABLE IF NOT EXISTS streams (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    broadcaster_id UUID NOT NULL REFERENCES users(id),
    title          TEXT NOT NULL DEFAULT '',
    type           TEXT NOT NULL DEFAULT 'video' CHECK (type IN ('audio','video')),
    status         TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live','paused','ended')),
    viewer_peak    INT  NOT NULL DEFAULT 0,
    gift_coins     BIGINT NOT NULL DEFAULT 0,     -- bu yayinda toplanan toplam jeton
    started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at       TIMESTAMPTZ
  );
  CREATE INDEX IF NOT EXISTS idx_streams_live ON streams(status) WHERE status IN ('live','paused');
  -- Ayni yayincinin ikinci es zamanli yayini olamaz (cift-tik/retry muhafizi)
  CREATE UNIQUE INDEX IF NOT EXISTS uq_streams_broadcaster_live
    ON streams(broadcaster_id) WHERE status IN ('live','paused');

  CREATE TABLE IF NOT EXISTS stream_reports (
    id          BIGSERIAL PRIMARY KEY,
    stream_id   UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES users(id),
    reason      TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- HEDIYE IDEMPOTENCY: ayni (reason, ref_id) ikinci kez yazilamaz.
  -- gift_sent + gift_received ayni ref_id ile IKI satir yazar (reason farkli -> ikisi de gecer).
  CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_idem
    ON coin_ledger(reason, ref_id) WHERE ref_id <> '';
  ```
- NEDEN: İzleyici satırı YOK (Ön Karar A); `coin_ledger` (001_init.sql:82) zaten var, sadece idempotency index'i eksik. Tümü additive — calls/chats verisine dokunmaz.
- DOĞRULAMA: deploy → `\d streams`; 1:1 + grup arama regresyon testi (dokunmadık, sadece kanıt).

## ADIM 2 — Ortak LiveKit paketi: `internal/livekit`
- DOSYA: `backend/internal/livekit/token.go` + `backend/internal/livekit/roomservice.go` (yeni paket; internal/calls'a DOKUNMA — oradaki token aynen kalır)
- NE DEGISIR:
  - `token.go`: `AccessToken(apiKey, secret, identity, name string, grants map[string]any)` — calls'daki HS256 üreticinin grant-parametreli kopyası. Hazır kurucular: `PublisherGrants(room)`, `ViewerGrants(room)` (`canPublish:false, canSubscribe:true, canPublishData:false, hidden:true`), `AdminGrants(room)` (`roomAdmin,roomCreate,roomList`).
  - `roomservice.go`: `Client{baseURL, apiKey, secret, http.Client(10s)}` + Ön Karar B'deki 6 metod; her çağrı çağrı-başı üretilmiş Bearer token ile.
- NEDEN: İzleyici `hidden:true` → 300 izleyicinin her gir/çıkışı odadaki herkese sinyal fırtınası üretmez (sayaç zaten Redis'te, Adım 4). `canPublishData:false` → izleyici odaya spam data basamaz; hediye animasyonu YALNIZ backend SendData'sından gelir (sahte hediye animasyonu engellenir). Rota yok, davranış değişmez → risksiz deploy.
- DOĞRULAMA: `go build ./...` → deploy → scratchpad scriptiyle `ListRooms` curl'ü 200 dönüyor mu.

## ADIM 3 — `internal/streams`: başlat / bitir / keşfet
- DOSYA: `backend/internal/streams/handler.go` (yeni) + `backend/cmd/api/main.go` (korumalı gruba rota: `POST /streams`, `POST /streams/{id}/end`, `GET /streams`, `GET /streams/{id}`)
- NE DEGISIR:
  - `POST /streams` `{title, video}`: (1) `INSERT INTO streams ... RETURNING id` — `uq_streams_broadcaster_live` ihlali → 409 "zaten yayindasin"; (2) **RoomService.CreateRoom** `stream_<id>`, `max_participants = STREAM_MAX_VIEWERS+10`, `empty_timeout:300`; (3) yayıncıya `PublisherGrants` token → `{stream_id, room, url, token}`.
  - `POST /streams/{id}/end` (sadece broadcaster): ortak `endStream()` → `UPDATE streams SET status='ended', ended_at=now() WHERE status IN ('live','paused')` (atomik, cift-end güvenli) + SendData `{"t":"stream.ended"}` + `DeleteRoom` (herkes düşer) + Redis anahtarlarını sil.
  - `GET /streams`: `status='live'` + yayıncı adı/avatarı + izleyici sayısı (Adım 4'e kadar 0) → "Canlı" sekmesi keşfet listesi. `GET /streams/{id}`: tekil durum (derin bağlantı/önizleme).
- NEDEN: **CreateRoom'u AÇIKÇA çağırmak ŞART — TUZAK:** `livekit.yaml room.max_participants: 32` GLOBAL; oda auto-create'e bırakılırsa 33. izleyici LiveKit tarafından reddedilir. Oda-başı CreateRoom değeri global varsayılanı ezer. `empty_timeout:300` → yayıncı kısa kopmada oda ölmez (Adım 5 grace ile uyumlu).
- DOĞRULAMA: curl start → `docker logs livekit | grep stream_<id>` (participant active + mediaTrack published) → end → odanın silindiğini gör.

## ADIM 4 — İzleyici: watch / heartbeat / leave + Redis sayaç + kapasite muhafızı
- DOSYA: `backend/internal/streams/handler.go` + `viewers.go` (yeni; Redis erişimi için `redis.Client` handler'a enjekte — main.go'da `streams.NewHandler(db, rdb, hub, lk)`)
- NE DEGISIR:
  - `POST /streams/{id}/watch`: yayın `live/paused` mi → değilse 410; engel kontrolü (blocks, calls deseni) + `SISMEMBER stream:{id}:banned` → 403; **kapasite: `ZCARD stream:{id}:viewers >= STREAM_MAX_VIEWERS` (env, varsayılan 300) → 429 "yayin dolu"**; `ZADD stream:{id}:viewers <unix_now> <user_id>` → `ViewerGrants` token döner.
  - `POST /streams/{id}/heartbeat` (izleyici + yayıncı aynı uç, 15 sn'de bir): izleyici → ZADD skor tazele; `user_id == broadcaster_id` ise → `SET stream:{id}:pub 1 EX 45` (yayıncı nabzı).
  - `POST /streams/{id}/leave`: `ZREM` (nazik çıkış; heartbeat süpürücüsü zaten kaba çıkışı yakalar).
  - `GET /streams` artık `ZCARD`'ı okur (pipeline ile N yayın tek turda).
- NEDEN: İzleyici sayacı DB'de değil Redis'te (Ön Karar A gerekçe 2); ZSET skoru = son nabız → süpürücü (Adım 5) 45 sn sessiz kalanı düşürür; kapasite muhafızı cx33 NIC sınırını uygulama katmanında korur (LiveKit max_participants ikinci savunma hattı).
- DOĞRULAMA: 2. kullanıcı watch → `redis-cli ZCARD` artar; izleyici token'ıyla publish denemesi LiveKit'te REDDEDİLİYOR mu (grant testi); 301. izleyici simülasyonu (ZADD ile doldur) → 429.

## ADIM 5 — Süpürücü + yayıncı kopma grace period + sayaç yayını
- DOSYA: `backend/internal/streams/sweeper.go` (yeni) + main.go'da `streamsH.StartSweeper(ctx)` (calls.StartSweeper deseni, 15 sn tick)
- NE DEGISIR: Her tikte, `live/paused` yayınlar için:
  1. `ZREMRANGEBYSCORE stream:{id}:viewers -inf <now-45s>` (ölü izleyici temizliği) + `viewer_peak` güncelle.
  2. İzleyici sayısı değiştiyse SendData `{"t":"viewers","n":123}` (topic `meta`) — herkes sayacı görür.
  3. **Kopma:** `status='live'` + `stream:{id}:pub` anahtarı YOK → `status='paused'` + `SET stream:{id}:grace 1 EX 60` + SendData `{"t":"stream.paused"}` (izleyici ekranı "yayıncının bağlantısı koptu" gösterir, ODADA KALIR). Heartbeat geri gelirse (Adım 4) → `status='live'` + SendData `{"t":"stream.resumed"}`.
  4. `status='paused'` + grace anahtarı da düşmüş (60 sn doldu) → `endStream()`. Emniyet: 12 saatten uzun `live` → `endStream()` (calls sweep'teki 2-saat emniyet deseni).
- NEDEN: Yaşam döngüsü sinyalleri backend WS hub'ından DEĞİL SendData'dan gider — izleyiciler zaten LiveKit odasında, hub'da kim izliyor bilgisi yok; tek SendData çağrısı 300 kişiye ulaşır (mimari karar: "hediye animasyon LiveKit data API" — aynı kanal). Grace period, mobil ağda 10-20 sn'lik kopmalarda yayını öldürmez.
- DOĞRULAMA: yayıncı uygulamayı öldür → ~45-60 sn'de `paused` + izleyicide data mesajı → 60 sn daha → `ended` + oda silinmiş; yayıncı geri gelirse `resumed`.

## ADIM 6 — HEDİYE: `POST /streams/{id}/gift` (coin_ledger + animasyon fan-out)
- DOSYA: `backend/internal/streams/gifts.go` (yeni) + rota
- NE DEGISIR:
  - Sabit katalog BACKEND'de: `var katalog = map[string]int64{"gul":10, "kalp":50, "roket":500}` — istemciden fiyat ALINMAZ (manipülasyon engeli). İstek: `{"gift":"gul","idem":"<istemci-uuid>"}`.
  - Tek pgx transaction:
    1. `SELECT broadcaster_id, status FROM streams WHERE id=$1 FOR UPDATE` → `live/paused` değilse 410; `sender==broadcaster` → 400.
    2. `UPDATE users SET coin_balance = coin_balance - $c WHERE id=$sender AND coin_balance >= $c` → 0 satır = **402 "yetersiz jeton"** (bakiye kontrolü + düşme ATOMİK, ayrı SELECT yarışı yok).
    3. `INSERT INTO coin_ledger (user_id, amount, reason, ref_id) VALUES ($sender, -$c, 'gift_sent', $streamID||':'||$idem)` — **unique ihlali (23505) → rollback → 200 `{"status":"duplicate"}`** (idempotent tekrar; retry çift harcamaz).
    4. `UPDATE users SET coin_balance = coin_balance + $c WHERE id=$broadcaster` + ledger `gift_received` aynı ref_id.
    5. `UPDATE streams SET gift_coins = gift_coins + $c`.
  - Commit SONRASI: SendData topic `gift` → `{"t":"gift","gift":"gul","coins":10,"from_id":"...","from_name":"Ayşe"}` — odadaki HERKES (yayıncı dahil) animasyonu oynatır. Yanıt: `{"balance": <yeni bakiye>}`.
- NEDEN: Prototipte ödeme YOK (bedava kayıt jetonu, kod çalışıyor — auth/handler.go:161); ledger çift-satır deseni 001'deki reason sözlüğünü (`gift_sent/gift_received`) aynen kullanır. Fan-out WS hub'dan değil SendData'dan (Adım 5 gerekçesi + izleyici `canPublishData:false` olduğundan sahte animasyon imkânsız).
- DOĞRULAMA: aynı idem ile 2 curl → coin_ledger'da TEK çift satır, bakiyeler bir kez oynar; yetersiz bakiye → 402; izleyici cihazında data mesajı düşüyor mu.

## ADIM 7 — Moderasyon minimum: rapor + admin yayın bitirme (+ yayıncı kick)
- DOSYA: `backend/internal/streams/handler.go` + main.go (admin rotası mevcut admin bloğuna: `POST /admin/streams/{id}/end`; korumalıya: `POST /streams/{id}/report`, `POST /streams/{id}/kick`)
- NE DEGISIR:
  - `POST /streams/{id}/report` `{reason}`: `stream_reports` satırı + `log.Printf("YAYIN-RAPOR ...")` (Dozzle'da görünür). Rate: aynı kullanıcı aynı yayına 1 rapor (ON CONFLICT yoksa SELECT-önce).
  - `POST /admin/streams/{id}/end`: calls admin uçlarındaki auth deseniyle → `endStream()` (DeleteRoom herkesi düşürür) + sebep loglanır.
  - `POST /streams/{id}/kick` `{user_id}` (sadece broadcaster): `RemoveParticipant` + `ZREM` + `SADD stream:{id}:banned <user_id>` (watch'taki kontrol Adım 4'te hazır → geri giremez).
- NEDEN: 5651/BTK yükümlülüğünün (4 saat kaldırma) teknik ön koşulu "yayını uzaktan bitirebilmek"; rapor tablosu Faz sonrası moderasyon panelinin tohumu. Kick, yayıncıya asgari öz-savunma verir — üçü de RoomService istemcisini (Adım 2) kullanır, yeni altyapı yok.
- DOĞRULAMA: admin end → tüm izleyiciler `stream.ended` + oda silinir; kick'lenen watch'ta 403 alır.

## ADIM 8 — Kapasite: LiveKit UDP port aralığı + env'ler (DİKKATLİ deploy)
- DOSYA: `backend/livekit.yaml` + sunucu ufw + `backend/.env` (sunucuda) + `backend/docker-compose` env geçişi
- NE DEGISIR:
  - **TUZAK: `rtc.port_range_start/end: 50000-50200` = yalnız 200 ICE portu.** 300 izleyici hedefi bu tavana takılır (Türk operatör NAT'ı çoğunu TURN 30000-40000'e itse de doğrudan-UDP izleyiciler port tüketir). → `port_range_end: 50999` + ufw `50000:50999/udp` + livekit restart.
  - Env: `STREAM_MAX_VIEWERS=300` (esnek muhafız, Adım 4), `LIVEKIT_API_URL` (Ön Karar B) — compose `environment` bloğuna.
- NEDEN: NIC/bant sınırı (yol haritası: cx33 ~200-350 video izleyici) uygulama muhafızıyla; port sınırı ise ancak yaml ile çözülür. AYRI ADIM çünkü **livekit restart canlı 1:1/grup aramalarını düşürür** → boş saatte, kullanıcı onayıyla.
- DOĞRULAMA: restart sonrası `node scratchpad/stuntest.js` + 1 adet 1:1 arama regresyon testi; `ss -lun | wc -l` port aralığı açılmış mı.

## ADIM 9 — Uçtan uca doğrulama + telemetri
- DOSYA: `backend/internal/calls/handler.go` admin paneline DOKUNMADAN `backend/internal/streams/admin.go` (admin JSON ucu: `GET /admin/streams` — canlı yayınlar, izleyici, gift_coins) + `oturum.md` / `CLAUDE.md` güncelle (kural 1-2)
- NE DEGISIR: Senaryo testi (2 cihaz + 1 emülatör): başlat → 2 izleyici → hediye → yayıncı uçak modu (paused/resumed) → kick → admin end. Netdata'da (nabiz.gebzem.app) bant/CPU izle; Sentry temiz mi; `docker logs livekit | grep stream_` ile medya doğrula (KURAL: hata ararken ÖNCE oda logu, oda adını filtrele).
- NEDEN: Dağıtım kontrol listesi + "3. cihaz testi" disiplini; admin görünürlüğü olmadan 5651 müdahale süresi tutturulamaz.
- DOĞRULAMA: yukarıdaki zincirin her halkasında beklenen WS/data olayı ve DB durumu tabloya işlenir; her adım commit+push + `git rev-parse origin/main`.

---

## RİSKLER / SINIRLAR
- **1:1/grup arama izolasyonu:** internal/calls, migrations 004-007, calls token üreticisi DEĞİŞMİYOR. Tek ortak dokunuş livekit.yaml (Adım 8) — restart penceresi planlanır.
- **SendData güvenilirliği:** `kind:RELIABLE` odaya bağlı olanlara ulaşır; yayına SONRADAN giren hediye geçmişini görmez → prototipte kabul (geçmiş `coin_ledger`'da; UI isterse `GET /streams/{id}` toplam gift_coins döner).
- **Auto-create tuzağı:** İzleyici token'ı odaya oda YOKKEN bağlanırsa LiveKit odayı global `max_participants:32` ile açar → Start'ta CreateRoom garantili; watch, yayın `live/paused` değilse zaten token vermez.
- **Redis uçuculuğu:** Redis restart'ında sayaç sıfırlanır → heartbeat 15 sn'de kendini yeniden kurar (kalıcı veri yalnız streams/coin_ledger'da; tasarım gereği).
- **Flutter tarafı bu planın DIŞINDA** (ayrı plan): izleyici Room'a `adaptiveStream:true` ile bağlanmalı, yayıncı VP8+simulcast (H264 YASAK — 720p tavanı, CLAUDE.md).

**Anahtar dosyalar:** `backend/internal/database/migrations/008_streams.sql`, `backend/internal/livekit/{token,roomservice}.go` (yeni ortak paket — Spaces planı da kullanabilir), `backend/internal/streams/{handler,viewers,sweeper,gifts,admin}.go`, `backend/cmd/api/main.go` (rota + NewHandler + StartSweeper), `backend/livekit.yaml` (yalnız Adım 8).

---

# BÖLÜM 3: FLUTTER UI (uzman planı)

# GEBZEM SPACES + CANLI YAYIN — FLUTTER UYGULAMA PLANI (18 Tem 2026)

> Yol haritası kararlarına uyar: oda/yayın = **in-app, CallKit'e SOKULMAZ**; roller = token grant + sunucu-taraflı izin; rol kaynağı **DB** (LiveKit metadata race #1829); prototip canlı yayın = saf WebRTC <500 izleyici. 1:1/grup arama koduna (**call_screen.dart, call_provider.dart, handler.go 1:1/grup yolları**) DOKUNULMAZ — yalnız `home_screen.dart`'taki iki placeholder satırı değişir. Her adım tek başına deploy+test edilebilir.

## MEVCUT DURUM TESPİTİ
- `mobile/lib/features/home/home_screen.dart:77-78`: Odalar ve Canlı sekmeleri `_PhasePlaceholder` ("Faz 4'te geliyor"); sekme/ikon altyapısı (index 2 ve 3, IndexedStack) hazır — sadece iki child değişecek.
- `mobile/lib/core/ws.dart` olay-agnostik (her olay `events` broadcast stream'ine düşer) → **ws.dart'a kod eklemek GEREKMEZ**; yeni `room.*`/`live.*` olayları yeni provider'larda dinlenir. Mevcut dinleyiciler (`call_provider._onEvent`, chats) bilinmeyen tipi zaten yok sayar → regresyon yok.
- KRİTİK BULGU: `backend/livekit.yaml:38` **`max_participants: 32` GLOBAL** — Spaces (200-500 dinleyici) ve yayın (500 izleyici) bu tavana takılır. Çözüm: oda ilk join'den ÖNCE RoomService **CreateRoom** ile oda-bazlı `maxParticipants` override (Adım 1).
- Yeniden kullanılacak mevcut parçalar: `CallRoomLock` (aynen import), `call_media_options.dart` sabitleri (aynen import), `call_screen.dart` desenleri (KOPYALANIR, dosyaya dokunulmaz — aşağıda liste), `CallService.ekranAcildi/ekranKapandi/aramadaMi` (public API, arama koduna dokunmadan muhafız entegrasyonu), `myProfileProvider` (jeton bakiyesi), `apiErrorMessage`.

---

## ADIM 1 — LiveKit RoomService köprüsü (backend ön koşul — SOMUT ÇÖZÜM)
- **DOSYA:** `backend/internal/rooms/lkadmin.go` (yeni) + `backend/docker-compose` api servisine `extra_hosts: ["host.docker.internal:host-gateway"]` + env `LIVEKIT_HTTP_URL`
- **NE DEĞİŞİR:** **SDK EKLENMEZ — raw HTTP twirp.** LiveKit RoomService düz `POST {LIVEKIT_HTTP_URL}/twirp/livekit.RoomService/{Metod}` (JSON gövde, JSON cevap). Gerekli 3-4 metod için `net/http` yeterli; mevcut "el yapımı HS256 JWT" deseniyle (handler.go:132-149) birebir tutarlı.
  - **Adres:** LiveKit host network'te, api konteynerde → `LIVEKIT_HTTP_URL=http://host.docker.internal:7880` (host-gateway ile). 7880 ufw'de zaten açık ama dış dünyaya kapatmak istenirse iç adres yeter.
  - **Auth:** `Authorization: Bearer <JWT>` — token() ile aynı imza (iss=apiKey, HS256, apiSecret), farkı grant: `"video": {"roomAdmin": true, "roomCreate": true, "room": "<odaAdi>"}`, exp 10 dk. Yeni fonksiyon `adminToken(room string)`.
  - **Metodlar + örnek gövdeler** (protojson: camelCase; snake_case de kabul edilir):
    - `CreateRoom`: `{"name":"oda_X","maxParticipants":500,"emptyTimeout":60}` → **global 32 tavanını oda bazında EZER (kritik)**
    - `UpdateParticipant`: `{"room":"oda_X","identity":"<userID>","permission":{"canSubscribe":true,"canPublish":true,"canPublishData":true}}` (promote; demote'ta `canPublish:false` → LiveKit track'leri otomatik unpublish eder)
    - `MutePublishedTrack`: `{"room":"oda_X","identity":"<userID>","trackSid":"TR_...","muted":true}` (trackSid `ListParticipants` cevabından: `participants[].tracks[].sid`, type=AUDIO)
    - `RemoveParticipant`: `{"room":"oda_X","identity":"<userID>"}`
    - `DeleteRoom`: `{"room":"oda_X"}` (host yayını/odayı bitirince herkes düşer)
    - `SendData`: `{"room":"yayin_X","data":"<base64>","kind":"RELIABLE","topic":"gift"}` (hediye sinyali YALNIZ sunucudan)
- **NEDEN:** Token'lar zaten el yapımı; SDK (protocol repo) ağır bağımlılık getirir. Moderasyonun sunucu-taraflı izinle yapılması yol haritası kararı.
- **Doğrulama:** sunucuda curl ile aktif bir `call_*` odasına `ListParticipants` → katılımcılar dönüyor mu. 1:1/grup arama koduna sıfır dokunuş.

## ADIM 2 — Backend uçları + WS sözleşmesi (Flutter'ın dayanağı)
- **DOSYA:** `backend/internal/database/migrations/008_rooms.sql` (yeni: `rooms` — id, host_id, title, topic, kind audio|live, status, created_at; `room_participants` — room_id, user_id, role host|speaker|listener, hand_raised, joined_at/left_at), `backend/internal/rooms/handler.go` (yeni), `main.go` route kaydı
- **NE DEĞİŞİR (sözleşme — ayrıntı backend planında):**
  - Odalar: `POST /rooms` (oluştur → CreateRoom maxParticipants=süre limitli 500 + host token) · `GET /rooms` (canlı keşif listesi: title, host, speaker/listener sayısı) · `POST /rooms/{id}/join` → rol'e göre token (**dinleyici: canPublish:false, canSubscribe:true, canPublishData:true → uplink yok**) · `/leave` · `/hand {up}` · host: `/promote {user_id}` `/demote` `/mute {user_id}` `/remove` `/end`. Rol değişimi: **önce DB, sonra UpdateParticipant, sonra WS olayı** (rol kaynağı DB).
  - Yayın: `POST /live` (host token, canPublish) · `GET /live` (keşif) · `POST /live/{id}/join` (izleyici token) · `/gift {gift_id}` (coin_ledger düş → `SendData topic=gift`) · `/end` (DeleteRoom).
  - WS olayları (hub.Publish, mevcut desen): `room.participant.joined/left`, `room.hand`, `room.role` (payload: user_id, role), `room.ended`, `live.viewer.count`, `live.ended`. **Push/CallKit YOK** — davet değil keşif modeli.
  - Oda adı: `oda_<id>` / `yayin_<id>` — `call_` ile çakışmaz, `docker logs livekit | grep oda_` filtresi çalışır (CLAUDE.md log tuzağı).
  - Kapasite reddi backend'de: Spaces >500 dinleyici, yayın >500 izleyici, konuşmacı >12.
- **NEDEN:** İstemci moderasyon yapamaz (token yetkisi yok); tüm rol/atma/susturma sunucudan. calls tablosu/handler'ına dokunulmaz — tamamen ayrı paket.

## ADIM 3 — Flutter provider iskeleti + arama-çakışma muhafızı
- **DOSYA:** `mobile/lib/features/rooms/room_provider.dart` (yeni), `mobile/lib/features/live/live_provider.dart` (yeni)
- **NE DEĞİŞİR:**
  - `roomsProvider = FutureProvider` (GET /rooms), `liveStreamsProvider = FutureProvider` (GET /live) — `callHistoryProvider` deseni.
  - `RoomSession extends StateNotifier<OdaDurumu?>`: aktif odanın rol/roster/el-kaldıranlar state'i. `wsProvider.events`'i dinler (CallService kurulumuyla aynı desen, call_provider.dart:45-47), `room.*` olaylarını işler; LiveKit `Room` nesnesi SERVİSTE DEĞİL ekran state'inde tutulur (CallScreen deseni). `LiveSession` aynısı `live.*` için.
  - **MUHAFIZ (arama ile aynı anda OLAMAZ):** odaya/yayına girerken `ref.read(callServiceProvider.notifier)`:
    1. `aramadaMi == true` → katılma reddi + snackbar "Önce aramayı bitir".
    2. Katılınca `svc.ekranAcildi('oda_<id>')`, çıkınca `svc.ekranKapandi('oda_<id>')` → mevcut 1:1 muhafızları KENDİLİĞİNDEN çalışır: `start()` "Zaten bir aramadasınız" fırlatır (call_provider.dart:181), gelen-arama overlay bastırılır (:116), `answer()` null döner (:216). **Arama koduna sıfır dokunuş** — public metodlar kullanılır. Oda↔yayın arası çakışma da aynı kümeyle çözülür.
- **NEDEN:** İki LiveKit Room aynı anda açılırsa tek native ses birimini çekiştirir (CallRoomLock gerekçesi); tek küme = tek doğruluk kaynağı.
- **Doğrulama:** flutter analyze + birim: aramadayken join çağrısı reddediliyor mu.

## ADIM 4 — Home sekmeleri: Odalar + Canlı keşif listeleri
- **DOSYA:** `mobile/lib/features/rooms/rooms_tab.dart` (yeni), `mobile/lib/features/live/live_tab.dart` (yeni), `mobile/lib/features/home/home_screen.dart` (**yalnız 77-78. satırlar**: `_PhasePlaceholder` → `RoomsTab()` / `LiveTab()` + iki import)
- **NE DEĞİŞİR:** RoomsTab: `roomsProvider` listesi (kart: başlık, host, konuşmacı avatarları, dinleyici sayısı, CANLI rozeti), pull-to-refresh + 15 sn periyodik invalidate, boş durum ("Şu an açık oda yok — ilk odayı sen aç"), FAB "Oda aç" → Adım 5 sheet. LiveTab aynı desen; FAB "Yayın başlat" → Adım 8. Karta dokun → join akışı (Adım 5/9).
- **NEDEN:** Keşif modeli (davet/zil yok) — Spaces/TikTok deseni; sekmeler zaten var, sadece içerik dolar.
- **Doğrulama:** Backend'de elle oda yaratıp listede görünmesi; boş durum; aramadayken FAB reddi.

## ADIM 5 — Oda oluşturma sheet'i + katılma akışı
- **DOSYA:** `mobile/lib/features/rooms/room_create_sheet.dart` (yeni; `showModalBottomSheet`)
- **NE DEĞİŞİR:** Başlık (zorunlu) + konu (opsiyonel) + "Sesli oda aç" butonu → `POST /rooms` → dönen token'la **önce `RoomScreen`'i `Navigator.push` (rootNavigatorKey ile MaterialPageRoute — CallScreen ile aynı yol, GoRouter'a route EKLENMEZ), sonra sheet state temizliği** (CLAUDE.md Riverpod+overlay tuzağı: önce ekran, sonra state). Dinleyici katılımı: kart dokunuşu → `POST /rooms/{id}/join` → RoomScreen (role: listener).
- **NEDEN:** In-app navigasyon kararı (CallKit yok); tuzak sırası v13'te kanıtlandı.
- **Doğrulama:** 2 cihaz: A oda açar, B listeden katılır; `docker logs livekit | grep oda_` → 2 participant active.

## ADIM 6 — RoomScreen (Spaces ekranı): UI + ses/oda yaşam döngüsü
- **DOSYA:** `mobile/lib/features/rooms/room_screen.dart` (yeni), `mobile/lib/features/rooms/widgets/speaker_avatar.dart` (yeni)
- **NE DEĞİŞİR:**
  - **call_screen'den KOPYALANAN desenler** (dosyaya dokunmadan — grup planındaki "aynı ekran" kuralı 1:1↔grup içindi; Spaces işlevsel olarak ayrı ekran):
    - `_grupAvatar` (call_screen.dart:1196-1231): avatar + `isSpeaking` yeşil halka → `speaker_avatar.dart`'a; `ActiveSpeakersChangedEvent` dinleme (:438-440).
    - Oda kurulum/teardown: `RoomOptions(adaptiveStream:true, dynacast:true)` (:356-370), `ConnectOptions` **iceTransportPolicy.relay** (:445-462, TR operatör NAT'ı — oda için de ŞART), `_kapatOda` sırası disconnect→listener.dispose→room.dispose hepsi 3sn timeout'lu (:691-716).
    - `_ctrlButton` alt bar (:1357-1374).
  - **AYNEN import:** `CallRoomLock` — odanın TÜM connect/teardown'u `CallRoomLock.calistir()` içinde. Bu sayede arama→oda / oda→arama sıralı geçişte global ses sayacı yarışı OLMAZ (nesil jetonuna gerek kalmaz: kilit, önceki ekranın `_sesiAc(false)`'inin yenisinin `true`'sundan ÖNCE bitmesini garantiler). `kAudioCaptureOptions/kAudioPublishOptions` da import.
  - **iOS ses sırası** (call_screen v7 dersi birebir): connect → (konuşmacıysa `setMicrophoneEnabled(true)`) → `setSpeakerOn(true)` (**oda varsayılanı HOPARLÖR** — dinleme senaryosu, 1:1'deki earpiece varsayılanının tersi) → MethodChannel `gebzem/audio` `setAudioEnabled(true)` **EN SON**. Dinleyici modunda mikrofon İZNİ HİÇ İSTENMEZ.
  - **UI:** üstte başlık + "n dinleyici"; konuşmacı avatarları üst bölümde büyük (host taç rozeti), dinleyiciler altta küçük grid (roster kaynağı: DB/WS — LiveKit `remoteParticipants` değil; dinleyici uplink'i yok ama LiveKit'te participant olarak görünür, yine de rol bilgisi WS'ten gelir). Alt bar: dinleyici → [El kaldır] [Ayrıl]; konuşmacı → [Mik] [Ayrıl]; host → + [Katılımcılar] [Odayı bitir].
  - **El kaldır:** `POST /rooms/{id}/hand` → host'a WS `room.hand` → rozet. **Terfi:** WS `room.role` gelince UI konuşmacı moduna geçer + `Permission.microphone` iste + `setMicrophoneEnabled(true)`; LiveKit tarafı `ParticipantPermissionsUpdatedEvent` ile zaten izin verir (UpdateParticipant token yenileme GEREKTİRMEZ). Terfi sonrası ses bozulursa yedek: `setAudioEnabled(false)→setMic→setAudioEnabled(true)` resync.
  - Oda biterken: WS `room.ended` VEYA `RoomDisconnectedEvent` (DeleteRoom sonucu) → tek seferlik `_leave` (idempotent `_ayrildi` bayrağı — call_screen deseni).
- **NEDEN:** Ses yaşam döngüsü hataları bu projede en pahalı sınıf ("2-3. aramada ses yok"); kanıtlanmış desenlerin kopyası en düşük risk. UI sıfırdan (yol haritası: "Flutter UI SIFIRDAN").
- **Doğrulama:** 3 cihaz: host konuşur, 2 dinleyici duyar (dinleyicide mic izni istenmediğini gör); dinleyici el kaldırır → host görür; oda ekranındayken 4. cihazdan 1:1 arama → overlay/answer bastırılıyor mu; odadan çıkıp HEMEN 1:1 arama → ses temiz mi (CallRoomLock sırası).

## ADIM 7 — Host kontrolleri: katılımcı sheet'i (promote/demote/mute/at)
- **DOSYA:** `mobile/lib/features/rooms/room_participants_sheet.dart` (yeni)
- **NE DEĞİŞİR:** Bölümlü liste: `El kaldıranlar` (üstte, [Konuşmacı yap]) · `Konuşmacılar` ([Sustur] [Dinleyiciye indir]) · `Dinleyiciler` ([At]). Her aksiyon = REST (`/promote,/demote,/mute,/remove`); **UI iyimser GÜNCELLEME YAPMAZ** — WS `room.role`/`room.participant.left` gelince state değişir (rol kaynağı DB; race yok). Atılan istemci WS `room.removed`/RemoveParticipant sonucu `RoomDisconnectedEvent` alır → "Odadan çıkarıldın" diyaloğu. Susturulan konuşmacıya bilgi banner'ı ("Host seni susturdu — tekrar konuşmak için mikrofonu aç").
- **NEDEN:** Moderasyon Spaces'in çekirdeği; tüm yetki sunucuda, sheet sadece tetikler.
- **Doğrulama:** host olmayan cihazda aksiyon butonları görünmüyor; mute sonrası LiveKit logunda track muted; at sonrası katılımcı düşüyor, tekrar join edebiliyor (ban ayrı faz).

## ADIM 8 — Canlı yayın: başlatma ekranı + yayıncı ekranı
- **DOSYA:** `mobile/lib/features/live/live_start_screen.dart`, `live_broadcast_screen.dart` (yeni)
- **NE DEĞİŞİR:**
  - **Başlatma:** kamera önizleme (`LocalVideoTrack.createCameraTrack(kCameraCaptureOptions)` + `VideoTrackRenderer` — Room'suz, CallRoomLock dışı; "Yayına başla"ya basınca önizleme track'i `stop()+dispose()` edilir, oda bağlantısı kilit içinde SIFIR track'le kurulur) + başlık alanı + kamera çevir. `POST /live` → LiveBroadcastScreen.
  - **Yayıncı ekranı:** kendi kamerası tam ekran (`VideoTrackRenderer` + `ValueKey(track.sid)` taze-renderer deseni, call_screen:899-904); publish profili **`kVideoPublishOptions` + `kCameraCaptureOptions` AYNEN import** (720p VP8 simulcast + balanced — tek yayıncı, katman seçimini izleyici tarafı adaptiveStream yapar). Üstte izleyici sayısı (WS `live.viewer.count`), altta chat/hediye şeridi (Adım 9 ile ortak widget), [Kamera çevir] [Mik] [Yayını bitir] (→ `POST /live/{id}/end` → backend DeleteRoom). Muhafız: `ekranAcildi('yayin_<id>')`.
- **NEDEN:** Yayıncı = 1:1'deki publisher ile aynı medya yolu → kanıtlanmış 720p profili aynen; önizlemenin Room dışında olması ses-birimi kilidini karıştırmaz.
- **Doğrulama:** yayın aç → `docker logs livekit | grep yayin_` → mediaTrack published; Netdata'da CPU.

## ADIM 9 — İzleyici ekranı: tam ekran video + chat + kalp (data channel)
- **DOSYA:** `mobile/lib/features/live/live_viewer_screen.dart`, `widgets/chat_strip.dart`, `widgets/heart_overlay.dart` (yeni)
- **NE DEĞİŞİR:**
  - `POST /live/{id}/join` → subscribe-only token → kilit içinde bağlan; yayıncının video track'i tam ekran (`VideoViewFit.cover`, ValueKey deseni, `IgnorePointer` NPE koruması call_screen:1294 notu). Ses: `setSpeakerOn(true)` + `setAudioEnabled(true)` en son; mic izni YOK.
  - **Data channel (LiveKit):** gönder `room.localParticipant.publishData(utf8.encode(json), topic: 'chat'|'heart')` (izleyici token'ı `canPublishData:true`); al `listener.on<DataReceivedEvent>` → topic'e göre: `chat` → alt şeritte son ~50 mesaj (yarı saydam, TikTok deseni); `heart` → sağ altta yükselen kalp animasyonu (basit `AnimationController`, paket yok; **gönderim istemcide 2/sn'ye kısılır**, alım toplanarak çizilir — 500 izleyicide fan-out taşmasın); `gift` → **YALNIZ sunucu SendData'sından render** (participant identity'si sunucu = boş/servis kimliği değilse YOK SAY — istemciden sahte hediye engellenir), tam ekran hediye animasyonu + şeride "X, Y gönderdi".
  - Yayın biterken: WS `live.ended` / `RoomDisconnectedEvent` → "Yayın sona erdi" ekranı (izleyici sayısı/süre) → geri.
- **NEDEN:** <500 izleyicide saf WebRTC + data channel = anlık reaksiyon (yol haritası kararı); chat için ayrı WS fan-out'a sunucu yükü bindirmeye gerek yok.
- **Doğrulama:** 3 cihaz: 1 yayıncı 2 izleyici; chat/kalp iki yönde anlık; izleyicide uplink ~0 (Netdata).

## ADIM 10 — Hediye sheet'i + jeton + uçtan uca sıkılaştırma
- **DOSYA:** `mobile/lib/features/live/live_gift_sheet.dart` (yeni)
- **NE DEĞİŞİR:** Sheet: üstte jeton bakiyesi (`myProfileProvider.coin_balance` — mevcut provider aynen), hediye ızgarası (v1 statik katalog: Kalp 10 · Gül 50 · Roket 200 jeton), seç → `POST /live/{id}/gift` → başarıda `ref.invalidate(myProfileProvider)`; yetersiz bakiye → backend 400 → `apiErrorMessage` snackbar (prototipte ödeme YOK, kayıt bonusu 100 jeton). Animasyon TETİKLENMEZ istemciden — herkese (gönderen dahil) sunucu SendData'sıyla gelir (tek doğruluk kaynağı). Sıkılaştırma: odadayken gelen 1:1'de RoomScreen'e bilgi banner'ı ("Gelen arama — kabul için odadan ayrıl"; iOS'ta CallKit yine çalar, kabul edilirse answer() null döner ve arama cevapsız düşer — bilinen sınır, v2'de otomatik decline); tüm yeni ekranlarda Sentry breadcrumb (`_sesLog` deseni).
- **NEDEN:** Hediye = gelir modelinin prototipi; ledger sunucuda, animasyon sunucu-imzalı → şişirilemez.
- **Doğrulama:** hediye gönder → iki cihazda animasyon + bakiye düştü (`coin_ledger` satırı) + yetersiz bakiye reddi.

---

## EKRAN/ROUTE LİSTESİ (hepsi in-app; GoRouter'a route eklenmez, CallScreen gibi `rootNavigatorKey` + MaterialPageRoute)
Sekme: `RoomsTab`, `LiveTab` (home IndexedStack) · Sheet: `RoomCreateSheet`, `RoomParticipantsSheet`, `LiveGiftSheet` · Push: `RoomScreen`, `LiveStartScreen`, `LiveBroadcastScreen`, `LiveViewerScreen`.

**Yeniden kullanım:** AYNEN import → `CallRoomLock`, `call_media_options.dart` (kVideoPublishOptions/kCameraCaptureOptions/kAudio*), `CallService.ekranAcildi/ekranKapandi/aramadaMi`, `myProfileProvider`, `apiErrorMessage`, `rootNavigatorKey`. KOPYA (call_screen'e dokunmadan) → `_grupAvatar`+isSpeaking halkası, `_kapatOda` timeout'lu teardown sırası, relay ConnectOptions, `_ctrlButton`, ValueKey'li VideoTrackRenderer + IgnorePointer koruması, `setAudioEnabled` MethodChannel deseni.

## SIRALAMA + DOĞRULAMA
| # | Adım | Nasıl doğrulanır |
|---|------|------------------|
| 1 | RoomService köprüsü | curl ListParticipants canlı call odasında; 1:1 regresyon yok |
| 2 | Backend uçları + 008 migration | curl: oda aç/join/promote/mute/remove; `\d rooms`; 33+ katılımcı (CreateRoom override) |
| 3 | Provider + muhafız | analyze; aramadayken join reddi |
| 4 | Sekmeler | listede oda/yayın görünür; boş durum |
| 5 | Oluştur/katıl | 2 cihaz aynı `oda_` odasında (livekit log) |
| 6 | RoomScreen | 3 cihaz ses; dinleyicide mic izni yok; oda→arama sıralı geçişte ses temiz |
| 7 | Host kontrolleri | promote/demote/mute/at 3 cihazda; rol WS ile senkron |
| 8 | Yayıncı | `yayin_` odasında mediaTrack published; CPU |
| 9 | İzleyici + data | chat/kalp anlık; sahte gift topic yok sayılıyor |
| 10 | Hediye | bakiye düşer, iki cihazda animasyon, yetersiz bakiye reddi |

Her adım: commit + push + `git rev-parse origin/main` doğrula; sürüm dağıtımında DB temizle + debug-imza kontrolü (CLAUDE.md rutini).

## RİSKLER — 1:1/GRUP ARAMAYI BOZMADAN
- **En tehlikeli:** oda/yayın Room yaşam döngüsünün herhangi bir parçası `CallRoomLock` DIŞINA çıkarsa → global ses sayacı yarışı geri gelir ("2-3. aramada ses yok"). TÜM connect/teardown kilitte; teardown her yerde timeout'lu.
- `livekit.yaml max_participants:32` global kalır (grup araması için doğru); Spaces/yayın odaları CreateRoom override'ına MUHTAÇ — unutulursa 33. kişi sessizce giremez.
- Rol LiveKit metadata'ya YAZILMAZ (race #1829) — kaynak DB, taşıyıcı WS; UpdateParticipant yalnız izin uygular.
- Hediye animasyonu yalnız sunucu SendData'sından; istemci `gift` topic'i yok sayılır.
- Eski istemciler `room.*`/`live.*` olaylarını bilmez → mevcut switch'ler yok sayar (geriye uyumlu).
- iOS'ta odadayken gelen 1:1 CallKit çalar (VoIP push koşulsuz — iOS 13+ kuralı, değiştirilemez); kabul answer-guard'da null'a düşer → arayan cevapsız görür. Bilinen sınır, banner ile yumuşatılır.
- Kapasite (cx33): Spaces dinleyici ucuz (~200-500), canlı VİDEO ilk zorlanan — izleyici sınırı backend'de reddedilir; büyüme = egress ayrı makine (yol haritası).

---

# BÖLÜM 4: ÇATLAK ANALİZİ (eleştirmen — tam metin)

Gerekli dosyaları doğruladım (livekit.yaml, database.go migration runner, calls/handler.go, Caddyfile, livekit-compose.yml, call_screen/call_provider/call_room_lock/call_media_options, home_screen.dart, pub cache'te livekit_client-2.8.1 kaynağı). Bulgular:

## ÇELİŞKİLER
1. **CreateRoom / max_participants (KRİTİK):** `backend/livekit.yaml:38` global `max_participants: 32`. Plan 1 "CreateRoom çağrısı gerekmez, oda otomatik açılır" diyor → Spaces'te 33. katılımcı sessizce reddedilir; Plan 2 ve Plan 3 bunu açıkça tuzak olarak işaretleyip oda-bazlı CreateRoom override şart diyor. Plan 1 bu noktada YANLIŞ ve kendi 500-dinleyici hedefiyle çelişiyor.
2. **Twirp istemcisinin yeri + adresi üçe bölünmüş:** P1 `internal/rooms/livekit.go` + `https://rtc.gebzem.app` (Cloudflare+Caddy üzerinden), P2 `internal/livekit` ortak paket + `http://167.233.229.88:7880`, P3 `internal/rooms/lkadmin.go` + `host.docker.internal` (compose değişikliği ister). Aynı istemci 3 kez, 3 adresle yazılacak.
3. **Şema:** P3'ün 008_rooms.sql taslağı rooms tablosuna `kind audio|live` koyup canlı yayını da rooms üstünden kurguluyor; P1'in rooms'unda kind yok, P2 tamamen ayrı `streams` tabloları kuruyor. Ayrıca iki backend planı da **008_*.sql** numarasını almış — runner (database.go: dosya adı sıralı, isimle takip) ikisini de uygular ama numara çakışması koordinasyonsuz.
4. **Dinleyici/izleyici canPublishData + hidden:** P1 rooms dinleyicisi `data:false` (el kaldırma REST, spam koruması); P3 aynı dinleyiciye `data:true` veriyor. Canlıda daha sert: P2 ViewerGrants `canPublishData:false + hidden:true`, P3 Adım 9 chat/kalbi istemci `publishData`'sına dayandırıyor → P2 grant'ıyla chat/kalp HİÇ çalışmaz (hidden participant zaten publish edemez).
5. **WS olay adları:** P1 `room.hand.raised` / `room.role.changed` / `room.participant.muted` ↔ P3 `room.hand` / `room.role`. İzleyici sayısı: P2 SendData `{"t":"viewers"}` ↔ P3 WS `live.viewer.count`. Yayın sonu: P2 SendData `stream.ended` ↔ P3 WS `live.ended`.
6. **Uç/önek/limit/fiyat:** `/streams`+`watch` (P2) ↔ `/live`+`join` (P3); `stream_` ↔ `yayin_`; izleyici sınırı 300 (P2) ↔ 500 (P3); konuşmacı ≤10 (P1) ↔ ≤12 (P3); raise-hand gövdesi `{raised}` ↔ `/hand {up}`. Hediye kataloğu ters: P2 gül=10/kalp=50/roket=500 ↔ P3 Kalp=10/Gül=50/Roket=200.
7. **Roster kaynağı:** P1 `participant.joined/left`i YALNIZ host+speaker'a yolluyor; P3 RoomScreen roster'ı "DB/WS'ten" bekliyor → dinleyici ekranında konuşmacı ayrılınca ızgara bayatlar (yalnız `role.changed` herkese gidiyor). Ya P1 speaker değişimlerini herkese yollamalı ya P3 roster'ı LiveKit participant listesinden kurmalı.

## RİSKLER (canlı 1:1/grup arama)
- Arama koduna dokunan tek fiziksel nokta P2-Adım 8 (livekit.yaml port aralığı + restart) — planda bakım penceresi var, iyi; ama `backend/livekit-compose.yml:5` **`image: livekit/livekit-server:latest`** — pin YOK. Restart/recreate sırasında sürüm atlarsa üç planın v1.13.3 varsayımları çöker. Önce sürümü pinle.
- P3'ün yeniden-kullanım varsayımları kodda DOĞRULANDI: `CallRoomLock` (call_room_lock.dart), `ekranAcildi/ekranKapandi/aramadaMi` public (call_provider.dart:91-96), `kVideo/kCamera/kAudio*` (call_media_options.dart), home placeholder gerçekten 77-78. satırlar. Arama dosyalarına dokunmuyor — muhafız tasarımı sağlam.
- P2'nin admin ucu: admin auth yardımcıları `calls` paketinde private — `/admin/streams/{id}/end` için export ya da kopya gerekir; calls'a dokunmamak için kopya tercih edilmeli.
- Token süresi: calls deseni `exp: 4h` (handler.go:139). P1 oda emniyeti 8 saat → 4. saatten sonra kopan dinleyici yeniden bağlanamaz. Oda/yayın istemci token exp'i oda ömrüne göre verilmeli.
- livekit_client 2.8.1 doğrulaması: `ParticipantPermissionsUpdatedEvent`, `publishData(topic:)`, `DataReceivedEvent.topic` hepsi pakette VAR — P1/P3'ün "token yenilemeden terfi" ve topic'li data varsayımları doğru. `canPublishSources`/`permission.can_publish_sources` casing iddiası (P1) makul ama sunucuda P1-Adım 2'nin curl testiyle birlikte doğrulanmalı.

## EKSİKLER
- **Port/kapasite gerçeği:** TÜM Flutter istemciler ICE'ı relay'e zorluyor (`call_screen.dart:448-461`, `RTCIceTransportPolicy.relay`). P2-8'in "doğrudan-UDP izleyici port tüketir" gerekçesi bu uygulamada geçersiz; ama sunucu tarafı katılımcı başına ICE portu yine 50000-50200'den (200 port; LiveKit'te katılımcı başına publisher+subscriber 2 PC) tükenir → **P1'de 500 dinleyici için hiç port/kapasite adımı YOK.** Port genişletme (veya UDP mux) + TURN relay CPU/band payı iki özelliğin ORTAK ön koşulu olmalı.
- **5651 canlı yayında:** P2 izleyici izini yalnız Redis'te tutuyor (uçucu) — "kim, ne zaman izledi" kalıcı izi yok. P1'in `room_audit` desenine paralel FK'sız `stream_audit` (watch/leave/gift/kick + IP) eklenmeli.
- **DB temizlik rutini:** her sürümdeki `TRUNCATE users CASCADE` FK zinciriyle rooms/streams/stream_reports/coin_ledger'ı da siler (yalnız FK'sız room_audit kalır). Test döneminde kabul edilebilir ama planlarda hiç anılmamış; yayın öncesi rutin kaldırılmalı, audit tabloları bilinçli FK'sız kalmalı.
- **Gift idempotency indeksi:** `uq_ledger_idem(reason, ref_id)` kullanıcıdan bağımsız — çakışan/replay ref_id başkasının hediyesini sessiz "duplicate"e düşürür; `(user_id, reason, ref_id)` olmalı.
- Keşfet sözleşmesi (GET liste alan adları) iki backend planında farklı; P3 iki sekmeyi tek modelle bekliyor — alan adları yazılmadan Flutter başlayamaz.

## DÜZELTMELER (öncelik sırasıyla)
1. Twirp istemcisi TEK paket: P2'nin `internal/livekit`'i kabul; adres tek env `LIVEKIT_API_URL=http://167.233.229.88:7880` (compose değişikliği gerektirmez, ufw'de açık). P1 ve P3-Adım 1 bu paketi kullanır.
2. P1 Create'e **CreateRoom override** ekle (maxParticipants = 500 + konuşmacı payı) — global 32 tavanı başka türlü aşılamaz; ayrıca Join yolunda oda auto-create'e asla düşülmemeli.
3. Sözleşmeyi tekilleştir (backend kazanır, P3 uyarlanır): uçlar `/rooms` + `/streams`; önekler `oda_`/`stream_`; WS adları P1 seti; canlı yayın yaşam döngüsü/sayaç SendData (P2 seti); izleyici 300, konuşmacı 10; hediye kataloğu+fiyat backend'den GET ile (UI'da sabit fiyat tutma).
4. Chat/kalp kararını P2+P3 birlikte revize etmeden P3-Adım 9 yazılmasın: ya viewer grant `data:true` + hidden kaldır (sinyal fan-out pahasına) ya chat REST→backend SendData relay olarak kalıp grant kapalı kalsın.
5. Migration numaraları: rooms=008, streams=009 (runner dosya-adı sıralı; çakışma teknik değil koordinasyon sorunu ama şimdi sabitle).
6. `livekit-compose.yml` image'ını v1.13.3'e pinle; port aralığı değişikliği + restart tek bakım penceresinde, 1:1 regresyon testiyle.
7. Oda/yayın token exp'ini oda azami ömrüne (8h) çıkar; reconnect senaryosu test listesine eklensin.
8. P1-Adım 5 fan-out kuralı: speaker join/left/role HERKESE, listener join/left yalnız host+speaker'a → P3 roster tasarımı çalışır hale gelir.