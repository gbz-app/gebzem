# Grup Araması — Uygulama Planı (araştırma: 12 Tem 2026)

> Motor hazır (LiveKit çok kişilik oda destekliyor). Bu plan 1:1 aramayı BOZMADAN genişletir.
> Uygulama: 1:1 + CallKit sürümü test edilip sağlamlaşınca başlanacak.

# GEBZEM GRUP ARAMASI — UYGULAMA PLANI

Mevcut 1:1 arama CALISIYOR; onu bozmadan gruba genisletme plani. Her madde: DOSYA + NE DEGISIR + NEDEN.

---

## 1) VERI MODELI (backend)

**1.1 — Yeni migration `007_group_calls.sql`**
- DOSYA: `backend/internal/database/migrations/007_group_calls.sql` (yeni)
- NE DEGISIR:
  - `ALTER TABLE calls ADD COLUMN chat_id UUID REFERENCES chats(id)` (grup icin dolu, 1:1 icin NULL kalir).
  - `ALTER TABLE calls ADD COLUMN is_group BOOLEAN NOT NULL DEFAULT false`.
  - `ALTER TABLE calls ALTER COLUMN callee_id DROP NOT NULL` (grup satirinda tekil karsi taraf yok).
  - Yeni tablo:
    ```sql
    CREATE TABLE call_participants (
      call_id   UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
      user_id   UUID NOT NULL REFERENCES users(id),
      status    TEXT NOT NULL DEFAULT 'invited',   -- invited/ringing/joined/left/rejected/missed
      joined_at TIMESTAMPTZ,
      left_at   TIMESTAMPTZ,
      PRIMARY KEY (call_id, user_id)
    );
    CREATE INDEX idx_call_participants_user ON call_participants(user_id) WHERE status IN ('ringing','joined');
    ```
- NEDEN: 1:1'de tek satirda tutulan `status/answered_at/ended_at` (`004_calls.sql:10-11`) grupta yetmez; her katilimcinin kendi durum + zaman damgasi olmali. `calls` satiri artik yalnizca odanin yasam dongusu (baslama/bitme).

**1.2 — 1:1 GERIYE UYUMLU KALIR**
- NE DEGISIR: Mevcut 1:1 kodu `callee_id` dolu + `is_group=false` yazmaya devam eder. Yeni `call_participants` tablosuna 1:1 icin de iki satir yazilirsa (caller+callee) tum sorgular tek yoldan gider — ama bu 1:1 handler'i degistirmeyi gerektirir. RISKSIZ YOL: 1:1 eski kolonlarla calismaya devam etsin, grup ayri kod yolu kullansin (bkz. madde 6).
- NEDEN: Calisan 1:1'i migrationda dokunmadan birakmak, en dusuk regresyon riski.

---

## 2) BACKEND (`backend/internal/calls/handler.go`)

**2.1 — Grup baslatma: `Start` icinde dallanma**
- DOSYA: `handler.go` (`startReq` `126-129`, `Start` `144-200`)
- NE DEGISIR: `startReq`'e `ChatID *string` + opsiyonel `InviteeIDs []string` ekle. `CalleeID` bos & `ChatID` doluysa GRUP yolu:
  - `chat_members`'tan uyeleri cek (owner haric); `InviteeIDs` verildiyse onunla kesistir (buyuk grupta "herkesi cagirma").
  - `INSERT INTO calls (id, caller_id, chat_id, is_group, video, status='ringing')` — `callee_id` YOK.
  - Her hedef icin `INSERT INTO call_participants(call_id,user_id,status='ringing')`; baslatan icin `status='joined', joined_at=now()`.
  - `CalleeID` doluysa ESKI 1:1 yolu aynen calisir (dokunma).
- NEDEN: Tek karsi taraf varsayimi (`184`, `192-195`) grup icin gecersiz; fan-out uye listesine gore olmali.

**2.2 — Mesgul mantigi grupta gevser**
- DOSYA: `handler.go:175-188`
- NE DEGISIR: Grup davetinde "callee zaten aramada => busy" kontrolunu UYGULAMA. Sadece 1:1 davette kalsin. Ek: bir kullanici zaten AYNI grup aramasindaysa tekrar davet etme (idempotent).
- NEDEN: Grupta biri baska aramadaysa bile davet gecerli; "busy" sadece 1:1 nezaket kurali.

**2.3 — Davet fan-out (WS + push)**
- DOSYA: `handler.go:209-251`
- NE DEGISIR: `To: []string{req.CalleeID}` -> `To: memberIDs` (baslatan haric). `call.incoming` payload'ina ekle: `chat_id`, `chat_title`, `is_group=true`, `starter_name`, `starter_avatar`, `participant_count`. FCM/APNs push her uyeye ayri, hepsi AYNI `call_id`.
- NEDEN: CallKit + overlay grup basligini gostermeli; her cihaz ayni odaya (`call_<callID>`) girecek.

**2.4 — `Answer` -> katilma**
- DOSYA: `handler.go:263-306`
- NE DEGISIR: Grup icin `WHERE callee_id=$2` (`269`) yerine `call_participants`'ta `(call_id,user_id)` satiri var mi + `chat_members` uyeligi dogrula. Tek satir `status='active'` (`281`) yerine: kullanicinin `call_participants.status='joined', joined_at=now()`; ilk katilan gelince `calls.status='active'`. `call.answered` sadece arayana degil, TUM aktif katilimcilara + `call.participant.joined {user_id,name}` yayinla.
- NEDEN: Grupta "cevaplayan" birden fazla; herkesin izgarayi guncellemesi gerekir.

**2.5 — `End` -> ayrilma (leave semantigi)**
- DOSYA: `handler.go:309-355`
- NE DEGISIR: Grup icin `End` = "ben ayrildim": `call_participants` kendi satirim `status='left', left_at=now()`; tum kalanlar icin `call.participant.left {user_id}` yayinla. Aktif katilimci sayisi 0/1'e dusunce `calls.status='ended'` + `call.ended`. Reddetme: ayri path veya `status='rejected'` (yalniz o katilimci; arama DIGERLERI icin surer). Tekil "diger taraf" blogu (`336-343`) grup icin listeye cevrilir.
- NEDEN: 1:1'de biri kapatinca arama biter; grupta biri ayrilinca SURMELI. Bu davranis farki kritik.

**2.6 — Yeni endpoint `POST /calls/{id}/join`**
- DOSYA: `handler.go` (yeni handler) + route kaydi
- NE DEGISIR: Devam eden (`active`) grup aramasina gec katilma / davetsiz uyenin katilmasi. Uyelik dogrula, `call_participants` upsert `status='joined'`, `call.participant.joined` yayinla, LiveKit token don.
- NEDEN: `Answer` yalniz davetliye ozel; gruba sonradan katilma icin ayri kapi gerekir.

**2.7 — Devam eden aramaya kisi ekleme `POST /calls/{id}/invite`**
- DOSYA: `handler.go` (yeni handler)
- NE DEGISIR: Aktif aramada `+ Kisi ekle` — verilen `user_ids` icin `call_participants status='ringing'` + davet fan-out (madde 2.3 gibi).
- NEDEN: UI/UX "aktif aramaya kisi ekle" akisi icin gerekli.

**2.8 — `Active` / `sweep` / `History`**
- DOSYA: `handler.go` `Active 361-383`, `sweep 69-104`, `History 386-424`
- NE DEGISIR:
  - `Active`: `callee_id` tekil sorgu -> `call_participants` join; kullanicinin `joined/ringing` oldugu aramalari don.
  - `sweep`: "60 sn ringing -> missed" (`72-75`) her `call_participants` satiri icin ayri; hepsi `ringing/missed` olunca `calls.status='missed'`.
  - `History`: `JOIN users ON callee_id` (`394`) grupta patlar. Grup satiri icin peer yerine `chat_title` + katilimci sayisi don; `is_group` ile ayir.
- NEDEN: Tekil karsi taraf varsayan tum sorgular grup satirinda NULL/yanlis sonuc uretir.

**2.9 — LiveKit token: DEGISMEZ**
- DOSYA: `handler.go:107-124`
- NE DEGISIR: Hicbir sey. `canPublish/canSubscribe/canPublishData` zaten hepsi `true`; oda adi `call_<callID>`, `identity=userID` (benzersiz). N katilimci ayni odaya girer.
- NEDEN: Grup icin izin modeli zaten uygun. (Opsiyonel: video oda icin `livekit.yaml` genelinde degil, uygulama katmaninda `maxParticipants` sinirla — madde 4.)

---

## 3) FLUTTER

**3.1 — `Room` ayarlari: adaptiveStream + dynacast AC**
- DOSYA: `mobile/lib/features/calls/call_screen.dart` (Room olusturma)
- NE DEGISIR: `RoomOptions(adaptiveStream: true, dynacast: true)` (ikisi de SDK'da varsayilan `false`). `defaultVideoPublishOptions`: simulcast acik (zaten default), grup video encoding'i ~h360 sinirla.
- NEDEN: cx33 CPU/bant korumasi; ekranda gorunmeyen/kucuk kutu otomatik dusuk katmana iner, izlenmeyen track encode edilmez. Grup icin kritik (kapasite raporu).

**3.2 — Coklu katilimci izgarasi**
- DOSYA: `call_screen.dart`
- NE DEGISIR:
  - `_peerJoined` bool (`56`) -> katilimci LISTESI/sayisi (`Room.remoteParticipants`).
  - `ParticipantConnected/DisconnectedEvent` (`164-172`): tek ayrilmada `_leave` CAGIRMA (`171-172`); yalniz `remoteParticipants.isEmpty` olunca ayril. Katildikca/ayrildikca izgarayi guncelle.
  - `_remoteVideo` getter (`333-340`) `firstOrNull` -> tum `remoteParticipants` uzerinden grid; her katilimci icin `VideoTrackRenderer`.
  - `build` (`346-452`): tek tam-ekran remote yerine grid: 2 kisi 1x2 · 3-4 2x2 · 5-6 2x3 · 7+ aktif konusmaci buyuk + altta yatay filmstrip. `Izgara <-> Konusmaci` gorunum butonu.
  - Sure timer (`166-168, 217`) ilk baskasi katilinca baslasin (mantik korunur).
- NEDEN: Tek `remoteParticipant` varsayimi grupta N kisiyi gostermez; biri ayrilinca aramayi kapatmak yanlis.

**3.3 — Aktif konusmaci**
- DOSYA: `call_screen.dart`
- NE DEGISIR: `room.createListener()..on<ActiveSpeakersChangedEvent>` -> `e.speakers.first` konusmaci gorunumunde buyur. Her kutuda `SpeakingChangedEvent` / `Participant.isSpeaking` ile yesil/renkli halka. Sesli modda avatar etrafinda ses seviyesiyle nabiz halkasi (`audioLevel`).
- NEDEN: Grup UX standardi; kim konusuyor gorunmeli.

**3.4 — `IncomingCall` modeli + WS olaylari**
- DOSYA: `mobile/lib/features/calls/call_provider.dart`
- NE DEGISIR:
  - `IncomingCall` (`11-30`): `chatTitle`, `isGroup`, `participantCount`, `starterName/starterAvatar` alanlari ekle; `fromJson` (`24-29`) `chat_id`/`is_group` okusun.
  - `start()` (`92-98`): `calleeId` tekil -> `chatId` + opsiyonel `inviteeIds`.
  - `_onEvent` (`53-75`): yeni olaylar `call.participant.joined` / `call.participant.left` / `call.declined` isle (izgara + katilimci sayfasi guncelle). Mevcut `call.answered`/`call.ended` "tek karsi taraf" mantigi grup icin listeye genisletilir.
- NEDEN: Model ve olay akisi tekil peer varsayiyor; grup icin coklu durum gerekli.

**3.5 — Sesli grup ekrani (avatar izgarasi)**
- DOSYA: `call_screen.dart` (video yoksa)
- NE DEGISIR: Video kapaliyken buyuk daire avatar izgarasi; konusan avatarda nabiz halkasi, susturulan koseye kirmizi mik rozeti, baglaniyor yari saydam. Ust: `{grup adi} · {n} katilimci` + sure. Alt bar: Mik · Hoparlor · Kameraya gec · Katilimcilar · Ayril.
- NEDEN: cx33'te ana senaryo sesli (video pahali). Discord/Spaces deseni.

**3.6 — Katilimcilar bottom sheet + toast**
- DOSYA: yeni widget `mobile/lib/features/calls/participants_sheet.dart`
- NE DEGISIR: Durum gruplu liste: `Aramada` (yesil) · `Baglaniyor` (sari) · `Cagriliyor` (gri) · `Ayrildi` (soluk + `Tekrar cagir`). Ana ekranda sadece bagli olanlar. Anlik 2 sn toast: `{ad} katildi` / `{ad} ayrildi`.
- NEDEN: Gurultu yapmadan kim ekli/baglaniyor/ayrildi gostermek.

**3.7 — Aramaya kisi ekleme ekrani**
- DOSYA: yeni widget (coklu secim) + grup sohbeti ust bar
- NE DEGISIR: Grup sohbeti ust barinda `sesli`/`goruntulu` ikon. Kucuk grup (<=8) -> hepsini cagir. Buyuk grup -> `Aramaya kimleri ekleyeceksin?` coklu secim -> secilenler `inviteeIds`. Aktif aramada `+ Kisi ekle` -> ayni ekran -> `POST /calls/{id}/invite`.
- NEDEN: WhatsApp deseni; buyuk grupta "herkesi cagirma".

**3.8 — CallKit: sadece baslik metni degisir**
- DOSYA: `mobile/lib/features/calls/callkit_service.dart`
- NE DEGISIR:
  - `_ayikla` (`96-103`): grup icin `nameCaller` = grup basligi (`Gebzem Ailesi` ya da `Ahmet + 4 kisi`); alt satir `Grup sesli aramasi · {baslatan}`.
  - `goster()` (`106-157`) grup basligiyla cagrilir; `handle`/`nameCaller` (`117,120`) grup adi.
  - iOS params `maximumCallGroups:1 / supportsGrouping:false` (`146-149`) AYNEN KALIR — grup = tek "gelen arama", N kisi.
  - `islenenler` cift-ekran korumasi (`27,63`) arama-id bazli, degismez.
- NEDEN: CallKit tek cagri nesnesi ister (tek UUID). Grup icin ayri sistem aramasi kaotik olur.

**3.9 — `incoming_call_overlay.dart`**
- DOSYA: `mobile/lib/features/calls/incoming_call_overlay.dart`
- NE DEGISIR: `_accept` (`62-94`, `83`): `CallScreen`'e `peerName` yerine grup basligi + `isGroup:true` + `chatId` gecir (ekran coklu moda gecsin). Metin (`129`): grupta `Grup goruntulu aramasi` / `Grup sesli aramasi`.
- NEDEN: Overlay tekil callerName varsayiyor; ekranin grup moduna gecmesi icin bayrak gerek.

---

## 4) UST SINIRLAR (kapasiteye gore — cx33)

- **Goruntulu grup: max 8 (tam kalite grid). 9-12 arasi "aktif konusmaci buyuk + digerleri dusuk thumbnail" ZORUNLU. Hard cap 12.**
  - N² akis egrisi 6-8 kisiden sonra dikleir; 12 kisi 132 akis ~ CPU siniri.
- **Sesli grup: max 30-40 (Opus+DTX ile rahat). Genel `livekit.yaml max_participants:32` kalabilir.**
- NE DEGISIR: Sinir UYGULAMA KATMANINDA, tur bazli. DOSYA: `handler.go` `Start`/`join`/`invite` — video oda `>12` reddet, sesli `>32` reddet. Flutter: 9+ goruntulude otomatik konusmaci gorunumune gec (grid yerine).
- NEDEN: cx33 (paylasimlan ~3 vCPU / ~700 Mbps). Video buyumesi 1 Gbps duvarina carpar -> ileride LiveKit dedicated makine (CLAUDE.md karari).

---

## 5) SIRALAMA + DOGRULAMA

| # | Adim | Nasil dogrulanir |
|---|------|------------------|
| 1 | Migration 007 (calls+call_participants) | Sunucuda `\d call_participants`; 1:1 aramasi hala calisiyor mu (regresyon testi) |
| 2 | Backend Start/Answer/End grup yolu + join/invite | `curl` ile 3 kullanici: baslat -> 2 kisi answer -> 1 ayril, oda surer -> son ayril, `ended`. `call_participants` durumlari dogru mu |
| 3 | WS olaylari (participant.joined/left/declined) | 2 cihaz WS log: katilma/ayrilma anlik dusuyor mu |
| 4 | LiveKit oda dogrulama | `docker logs livekit | grep call_<id>` -> N participant `active` + `mediaTrack published` (KRITIK: hata ararken ONCE oda logu — CLAUDE.md tuzagi) |
| 5 | Flutter grid + aktif konusmaci + sesli avatar ekrani | 3 cihaz gercek test (min); grid dogru, biri ayrilinca arama surer |
| 6 | CallKit grup basligi + overlay | Kilit ekraninda grup adi; kabul -> tek odaya girer |
| 7 | Ust sinir kontrolleri | 13. kisi video reddediliyor mu; 9. kiside konusmaci moduna geciyor mu |
| 8 | Kapasite/telemetri | Netdata (nabiz.gebzem.app) CPU %70 alti mi; Sentry temiz mi |

Her adim: commit + push + `git rev-parse origin/main` dogrula (CLAUDE.md kural 3). Her surumde DB temizle + APK debug-imza kontrolu (dagitim listesi).

---

## 6) RISKLER — 1:1'i BOZMADAN

- **AYNI EKRAN, iki mod (onerilen):** `CallScreen` `isGroup` bayragiyla dallanir. 1:1 (`isGroup:false`) kod yolu AYNEN korunur; grup yeni grid/liste yolunu kullanir. Ortak: LiveKit baglanti, kontrol bari, sure timer. Ayri ekran YAZMA — kod ikilenir, bakim zorlar.
- **Backend: 1:1 eski kolon yolu dokunulmaz.** `callee_id` dolu -> mevcut Start/Answer/End aynen. `chat_id` dolu -> yeni grup yolu. Migrationda `callee_id` NULLABLE yapmak 1:1'i bozmaz (hala dolu yazilir).
- **En tehlikeli nokta — `End` davranis farki:** 1:1'de biri kapatinca arama biter; grupta surmeli. Bu ikisini `is_group` ile KESIN ayir; yanlislikla 1:1 "leave" mantigina cevirme (biri kapatinca digeri asili kalir).
- **Riverpod + overlay tuzagi (CLAUDE.md):** grup ekranini acmadan davet state'ini sifirlama — once `CallScreen`'i ac, sonra `incoming` state'i temizle. Yoksa `Navigator.push` sessizce calismaz.
- **WS olay geriye uyum:** yeni `participant.*` olaylari eski istemcilerde bilinmez -> `_onEvent`'te bilinmeyen tip guvenli yok say (mevcut `message.new` vb. etkilenmez).
- **Kademeli cikis:** once SESLI grup (dusuk risk, cx33 rahat, video karmasikligi yok) -> sonra GORUNTULU grup (grid + kapasite sinirlari). Sesli calistiktan sonra videoyu ac.

---

**Anahtar dosyalar:** `backend/internal/calls/handler.go`, `backend/internal/database/migrations/007_group_calls.sql` (yeni), `mobile/lib/features/calls/{call_screen,call_provider,incoming_call_overlay,callkit_service}.dart`, yeni `participants_sheet.dart` + kisi-secim widget'i.