# WhatsApp-Parite Paketi — YARGIC HUKMU (wf_9bb15cc8, 19 Tem 2026)

Tüm doğrulamalar tamam. Hüküm planını yazıyorum.

---

# YARGIÇ HÜKMÜ — TEK UYGULAMA PLANI (WhatsApp-parite paketi, 19 Tem 2026)

## 0) KOD DOĞRULAMASI (yargıç kendi baktı — kanıt/düzeltmeler)

1. **Plan 0 kök nedeni KESİN doğrulandı:** flutter_webrtc 1.4.0 `CameraEventsHandler.waitForCameraOpen` (satır 20-29) `OPENED VEYA ERROR`'da döner; `GetUserMediaImpl.getUserVideo` (803 sonrası) state'i HİÇ kontrol etmez → kamera açılamasa da track üretilir, sinyalde publish olur, medya akmaz. `waitForCameraClosed` da dispose'ta gerçekten bekliyor (kapat-aç yarışı dar ama gerçek).
2. **Plan 0 çözüm zemini doğrulandı:** livekit_client 2.8.1 `publishVideoTrack` public (local.dart:262), SDK'nın kendi PreJoin deseni (room.dart:465-466 birebir), `stopLocalTrackOnUnpublish` varsayılan true (options.dart:138).
3. **Plan 1 kök nedeni doğrulandı:** self-view renderer'da `fit:` yok (call_screen.dart:1092) → varsayılan `VideoViewFit.contain` (video_track_renderer.dart:82) → letterbox + ClipRRect(24) tuhaf eğri. AYRICA: mobil LOCAL track renderer'ı flutter_webrtc'de `GestureDetector(onTapDown→onViewFinderTap)` ile sarılı (video_track_renderer.dart ~267-280) → swap'ta büyük pencere NPE riski GERÇEK; Plan 1 Adım 4'ün IgnorePointer'ı şart.
4. **DÜZELTME — migration numarası:** Plan 3 "010_call_invite.sql" diyor; `010_jeton_10k.sql` ZATEN VAR → yeni dosya **`011_call_invite.sql`** olacak.
5. **Backend iddiaları doğru:** pairwise temizlik 222-228 (is_group filtresi yok → K1 kemeri gerekli), endGroup 766-767 `c.created_at > now()-45s` (K2 doğru), Status 978 is_group dönmüyor (2b gerekli), answerGroup elapsed_ms DÖNDÜRMÜYOR (K4 doğru), History 1019 `is_group=false`, Active 992 callee_id+ringing, sweep yalnız 'ringing' (78-81), Status yetkisi call_participants'ı zaten içeriyor (954-955 → callee_id NULL güvenli).
6. **007 CHECK kısıtı:** call_participants.status yalnız `('ringing','joined','left','rejected','missed')` — /add asla 'invited' yazmamalı (Plan 3 zaten 'ringing' kullanıyor, uyumlu).
7. **DÜZELTME — push noktası sayısı:** 5 değil **6** (main.dart:251, incoming_call_overlay:104, chat_screen:104, calls_tab:187, group_call_start_screen:78 + **call_screen._geriAra:299**). Faz-C Adım C2 altısını da dönüştürür.
8. Logout yeri doğrulandı: `mobile/lib/features/auth/auth_provider.dart:90 logout()` (Faz-C Adım C5).
9. Yayın renderer key'i bugün `'yayin-${video.sid}'` (live_broadcast_screen.dart:286) — publish öncesi sid null olduğundan mediaStreamTrack.id'ye geçiş gerekçesi doğru.

## 1) ÇELİŞKİ KARARLARI

- **K1 (UI yerleşimi ↔ minimize mimarisi):** Üst bar butonları TEK KEZ, Faz-A'da, Plan 1 Adım 3 yerleşimiyle eklenir (`_minimize()/_kisiEkle()/_mesajaDon()` boş gövdeler). Plan 2 Adım 4(a)'nın "üst bilgiye ayrı chevron ekle" maddesi İPTAL — Faz-C yalnız `_minimize()` gövdesini doldurur. Faz-C'nin büyük refactor'u (C2) build'i PİKSELİ PİKSELİNE taşır; buton iskeletleri de aynen taşınır. Görev direktifi gereği butonlar Faz-A build'inde görünür ve tıklanabilir (no-op), fazlar sırayla açar.
- **K2 (buton görünürlük kapısı):** Plan 1'in `if (!_cevapsiz)` kapısı YETERSİZ (ring fazında ölü buton + backend /add 'active' şartıyla çelişir). Üç buton için ortak kapı: **`_baglandi && !_cevapsiz && _error == null`** (Plan 2 minimize kapısı ve Plan 3 Adım 5 kapısıyla birebir aynı — üç plan tek kapıda birleşti).
- **K3 (kişi-ekleme ↔ süre senkron):** Kişi eklemede EKRAN GEÇİŞİ YOK — CallScreen yerinde `setState(_isGroup=true)` yapar (Plan 3 Adım 4); Navigator rotası, Stopwatch, `_sureBaz` DEĞİŞMEZ. `_sureReferansiAl` muhafızı `widget.isGroup`→`_isGroup` olur ama A/B'de referans zaten kilitli (`_sureReferansVar`) → çifte koruma. Davetli C grup yolundan yerel sayaçla 00:00'dan başlar (mevcut grup davranışı, WhatsApp da böyle). Çelişki yok; kural: yükseltme anında iki sayaç ZIPLAMAMALI (test ölçütü).
- **K4 (faz sırası — B önce mi C önce mi):** Görevdeki sıra korunur (B: kişi-ekleme, C: minimize). Bedeli: Faz-C refactor'u Faz-B'nin `_isGroup` state'ini, `_partSub` dinleyicisini ve Status `is_group` kurtarmasını da controller'a taşır (C1/C2 kapsamına eklendi). Gerekçe: kişi-ekleme ağırlıklı backend işi + kullanıcıya görünür değer; minimize en riskli iş en sona, sağlam tabana biner.
- **K5 (dokun-gizle ↔ refactor):** `_uiGizli`, `_selfPos/_selfBuyuk/_sorunBildirildi` gibi SAF GÖRÜNÜM state'i — Faz-C'de ekranda KALIR, controller'a taşınmaz.
- **K6 (kişi-ekle butonu konumu):** Plan 3 Adım 5'in ayrı `Positioned(top:48,right:16)` butonu İPTAL — Faz-A'daki üst bar Row'undaki `_kisiEkle()` tek giriş kapısı; Faz-B yalnız gövdesini doldurur.
- **K7 (sheet ↔ minimize bitiş pop'u):** Faz-B'nin `_sheetAcik` bayrağı Faz-C'de ekranda kalır; C2'de controller'ın "arama bitti" bildirimi ekrana düşünce ekran ÖNCE sheet'i (`if (_sheetAcik && canPop) pop`) sonra kendini kapatır (Spaces B1 dersi tek yerde çözülür).

## 2) FAZ-A — DÜŞÜK RİSK, TEK BUILD (P1 kamera + self-view + üst bar iskeleti + dokun-gizle)

Global BOZMAMA (tüm Faz-A): `calls/` mantık katmanına (provider, callkit, room_lock, `_odayaBaglan`, `_leave`, süre senkronu, `_statusText`) dokunuş YOK — A4-A7 yalnız build/görsel katman; A1-A3 yalnız `live/` iki dosya.

- **A1 — `mobile/lib/features/live/live_start_screen.dart`:** Plan 0 Adım 1 AYNEN: `_basla()`'da satır 109 `await _onizlemeBirak()` kaldırılır → sahiplik devri (`final t=_onizleme; _onizleme=null;` setState'siz) → `LiveBroadcastScreen(onizlemeTrack: t)`. Muhafız (83-87), muhafız tekrarı+geri alma (99-107), X kilidi (170), catch yolu AYNEN; muhafız/mounted dallarında devir YAPILMAZ. **Doğrulama:** önizleme aç-X-tekrar aç; önizlemedeyken arama kabulü sonrası kamera sızıntısı yok.
- **A2 — `mobile/lib/features/live/live_broadcast_screen.dart`:** Plan 0 Adım 2 AYNEN: constructor `onizlemeTrack?`; `_odayaBaglan`'da mic sonrası `_devralinan!=null` ise `publishVideoTrack(_devralinan!, publishOptions: kVideoPublishOptions)` (hata→breadcrumb+`setCameraEnabled(true)` geri düşüş), null ise bugünkü yol; sıra mic→video→`setSpeakerOn(true)`→`_sesiAc(true)` EN SON AYNEN. `_kapatOda` sonuna tek-nokta salıverme (`!_videoYayinda` ise stop+dispose). `_kameram ?? _devralinan` + renderer key `mediaStreamTrack.id`. **Bozmama:** CallRoomLock, nabız-bağlantı-sonrası, RoomDisconnected→bitir, ayna kuralı, PopScope. **Doğrulama:** Android İLK yayında video; `docker logs livekit | grep <stream_room>` audio+3 video katmanı (oda adı filtreli); 5x aç-kapat-aç; bağlantı hatası simülasyonu sonrası arama/yayın girişleri temiz; iOS yayın→hemen 1:1 ses regresyonu.
- **A3 — aynı dosya, AYRI COMMIT:** Plan 0 Adım 3 güvenlik ağı (4sn+8sn `framesSent==0` kontrolü, Sentry `yayin-video-olu`, TEK `restartTrack()` — aynı çözünürlük, tuzak kapsamı dışı; döngüsel retry YOK). **Doğrulama:** normal yayında Sentry'ye olay düşmez.
- **A4 — `mobile/lib/features/calls/call_screen.dart` `_buildSelfView` (1057-1099):** Plan 1 Adım 1 AYNEN: `fit: VideoViewFit.cover` + radius 24→14 + dış Container (border white24 1px + gölge; ClipRRect gölge çizemez, dekor dışta). **Bozmama:** opaque GestureDetector+IgnorePointer sırası, `ValueKey('small-...')`, mirrorMode. **Doğrulama:** köşeler düzgün, boşluk yok; swap/sürükle/kamera-kapat regresyonsuz.
- **A5 — aynı dosya:** Plan 1 Adım 2 AYNEN: panEnd'de köşe `_selfSagda/_selfAltta` olarak saklanır, `_selfPos` yalnız pan sırasında; clamp sınırları ve varsayılan sağ-üst top≥130 birebir.
- **A6 — aynı dosya, üst bar iskeleti:** Plan 1 Adım 3, İKİ DÜZELTMEYLE: (a) görünürlük kapısı K2 (`_baglandi && !_cevapsiz && _error==null`); (b) `_minimize()/_kisiEkle()/_mesajaDon()` boş gövdeler + "Faz-B/C'de dolacak" yorumu. Sol chevronDown, sağ userPlus+messageSquare (40x40 daire, black26); isim Text'ine yatay 60 padding. **Bozmama:** üst bilgi Column içeriği, `_statusText`, "Ses gelmiyor" butonu AYNEN. **Doğrulama:** 4 görünümde (1:1/grup x sesli/görüntülü) ikonlar köşede, isim taşmıyor, no-op zararsız; ring/cevapsız fazında ikon yok.
- **A7 — aynı dosya, dokun-gizle:** Plan 1 Adım 4 AYNEN (`_uiGizli` + `_uiToggle`; 1:1 büyük renderer `opaque GestureDetector+IgnorePointer` — NPE de kapanır; grup izgara kök Container'ına onTap; SESLİ görünümlerde toggle YOK; katmanlar `AnimatedOpacity(200ms)+IgnorePointer`; efektif maske `_uiGizli && videoModu && !_cevapsiz && _error==null && !_connecting`; `_cevapsizGoster` ve `_toggleCam` kapama dalında `_uiGizli=false`; self-view gizlide 100x143+alt marj 40, `AnimatedPositioned`, pan sürerken düz Positioned). A6'nın butonları da gizlenen katmanda. **Bozmama:** süre senkron zinciri, iOS ses sırası, PopScope, grup izgara hesabı (GridView parametreleri + `padding: EdgeInsets.zero`), muhafızlar. **Doğrulama:** Plan 1 Adım 4 listesi (a)-(f) aynen.
- **A8 — `CLAUDE.md` + `oturum.md`:** yeni tuzaklar (Android getUserMedia ERROR yutması + "önizleme→yayın track taşınır, geri döndürme") + oturum kaydı. Her adım ayrı commit+push (`git rev-parse origin/main` teyidi), `flutter analyze` temiz. **FAZ SONU: build önerisi kullanıcıya sunulur (onaysız dağıtım yok); onayda dağıtım listesi + DB temizleme rutini.**

## 3) FAZ-B — ARAMAYA KİŞİ EKLEME (1:1→grup yükseltme)

Mimari kararlar Plan 3 K1-K4 AYNEN (callee_id→NULL + is_group=true; invited_at; sınırlar /add içinde; süre senkronuna sıfır dokunuş).

- **B0 — `backend/internal/database/migrations/011_call_invite.sql` (YENİ — numara DÜZELTİLDİ):** `ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ NOT NULL DEFAULT now();` + uçuştaki satırlar için `UPDATE ... SET invited_at=c.created_at FROM calls c WHERE c.id=p.call_id`. 007 CHECK/PK aynen.
- **B1 — `backend/internal/calls/handler.go` yeni `Add` + `cmd/api/main.go` (~162): `r.Post("/calls/{id}/add", callsH.Add)`:** Plan 3 Adım 1 akışı AYNEN (TX+FOR UPDATE 'active' kilidi; K3 kontrolleri; 1:1 ise `is_group=true, callee_id=NULL` + caller/callee'ye 'joined' upsert; davetli 'ringing' upsert `WHERE status<>'joined'`; TX dışı fan-out: eskilere `call.upgraded`, davetliye `call.incoming`+VoIP(caller_name=chatTitle)+FCM-offline — startGroup 437-468 deseni birebir). Aynı oda `call_<id>` → A/B bağlantısına dokunulmaz.
- **B2 — handler.go nokta düzeltmeleri (B0+B1 ile AYNI commit — Risk-5):** (a) endGroup 767 → `p.invited_at > now()-45s`; (b) Status cevabına `"is_group": isGroup`; (c) Start pairwise 222-228'e `AND COALESCE(is_group,false)=false`. **(d) Active'e grup-davet ikinci sorgusu = OPSİYONEL AYRI COMMIT** (önerilir; istemci değişikliği gerektirmez — IncomingCall.fromJson is_group'u zaten okuyor).
- **B3 — Deploy + curl:** `go build ./...` → deploy → Plan 3 C1-C8 (scratchpad/kisi-ekle-test.sh; C7 zombi regresyonu ŞART, C8 1:1 tam regresyon).
- **B4 — `mobile/lib/features/calls/call_provider.dart`:** `_onEvent`'e `case 'call.upgraded':` → `_participantController`'a aktar (yeni controller AÇMA); `addToCall(callId, userId)` metodu. `call.incoming/answered/ended` ve muhafız setleri AYNEN.
- **B5 — `call_screen.dart` `_isGroup` state:** Plan 3 Adım 4 AYNEN (10 okuma noktası `widget.isGroup`→`_isGroup`; en kritik 405 ParticipantDisconnected; 618 süre muhafızı; `_partSub = _svc.onParticipant.listen` — dispose'ta yalnız cache'li `_svc`; `_durumKontrol`'e `is_group` kurtarması; RoomOptions initState anındaki değerle kalır — yükseltilmiş görüntülüde 720p bilinen sınır, restartTrack DENENMEZ). A6'daki üst bar/toggle koşullarında `widget.isGroup` geçen yerler de `_isGroup`'a döner. **Bozmama:** iOS ses sırası, `_statusText`, `_leave`/teardown, CallKit callId-bazlı muhafızlar. **Doğrulama:** flutter analyze + 1:1 regresyon.
- **B6 — yeni `add_participant_sheet.dart` + `_kisiEkle()` gövdesi:** Plan 3 Adım 5 AYNEN, TEK FARK: buton Faz-A'dan hazır (K6), yalnız gövde dolar: sheet aç (GroupCallStartScreen arama deseni, mevcut katılımcılar filtreli), seçimde `svc.addToCall` → snackbar + `if (!_isGroup) setState(_isGroup=true)`, sheet açık kalır; `_sheetAcik` bayrağı + `_leave`'de pop-öncesi sheet kapatma (tek dokunuş, canPop korumalı).
- **B7 — Cihaz testi (3 telefon) + yayın:** Plan 3 cihaz senaryosu (yükseltmede A/B süresi ZIPLAMAZ — K3 ölçütü; C katılır/çıkar/B çıkar; iOS host + Android host; kilit ekranı CallKit) → oturum.md → build önerisi → onayda dağıtım+DB temizleme.

## 4) FAZ-C — MİNİMİZE + MESAJ (EN RİSKLİ; her adım tek başına derlenir)

Plan 2 mimarisi AYNEN (ChangeNotifier ActiveCallController; teardown "enqueue anında yakala"; minimize yalnız bağlı aramada; v1 üst yeşil bant; video önizlemesiz) + K4 gereği Faz-B eklemeleri de taşınır.

- **C1 — `mobile/lib/features/calls/active_call_controller.dart` (YENİ, hiçbir dosyaya bağlanmadan):** Plan 2 Adım 1 AYNEN + EK: `_isGroup` alanı (AramaBilgisi.isGroup başlangıç; `call.upgraded`/Status `is_group` ile controller'da güncellenir), `onParticipant` aboneliği controller'da. Kopyalama YASAKLARI: `_sesiAc(true)` EN SON; süre tasarımı (referans yalnız s=='active', created_at'e düşürme YOK, push süre taşımaz); ParticipantDisconnected grup dalında `_leave` YOK; relay ICE; grup 540p. **Doğrulama:** analyze temiz, davranış sıfır değişiklik. Commit.
- **C2 — CallScreen saf görünüm + 6 push noktası (EN RİSKLİ ADIM):** Plan 2 Adım 2 AYNEN, DÜZELTMELERLE: (a) push noktası 6'dır — `_geriAra` dahil (call_screen:299); (b) ekranda kalan görsel state listesine `_uiGizli`, `_sheetAcik`, köşe bayrakları eklenir; (c) A6/A7/B6'nın butonları ve sheet'i birebir taşınır (görsel fark YASAK); (d) bitiş bildiriminde sıra: sheet-pop → ekran-pop (K7). PopScope bu adımda bugünkü davranış (minimize C4'te). **Doğrulama:** Plan 2 Adım 2'nin 8 maddelik tam regresyonu (2-3 gerçek cihaz, biri iOS) + Faz-B yükseltme senaryosu tekrar (süre zıplamaz). Test cihazlarına derleme bu adımda ŞART; mağaza dağıtımı beklenir.
- **C3 — `active_call_banner.dart` (YENİ) + main.dart builder (307-308):** Plan 2 Adım 3 AYNEN (pasif; `IncomingCallOverlay(child: AktifAramaBanner(child: ...))`; bant içinde `Navigator.of(context)` YASAK — rootNavigatorKey/rootMessengerKey).
- **C4 — Minimize/restore AÇ:** Plan 2 Adım 4, K1 düzeltmesiyle: yeni buton EKLENMEZ — Faz-A'daki `_minimize()` gövdesi `c.minimize(); pop;` olur; PopScope `onPopInvokedWithResult` minimize kapısı; restore'da `baslat` ÇAĞRILMAZ (callId guard). **Bozmama:** minimize bitiş DEĞİL — muhafızlar dolu, timer'lar akar, CallKit aktif. **Doğrulama:** Plan 2 Adım 4'ün 9 maddesi (özellikle: ikinci connect YOK, karşı taraf kapatınca bant ≤3sn'de gider, 5x minimize-restore).
- **C5 — Mesaj ikonu + muhafız sertleştirme + logout:** Plan 2 Adım 5 AYNEN: `_mesajaDon()` gövdesi = minimize+pop + (`peerId!=null` ise) `/chats/direct`→`/chat/:id` (router.dart:59 mevcut); peerId yoksa yalnız minimize (backend'e alan EKLENMEZ). Muhafız snackbar'larına "Aramaya dön" aksiyonu; `auth_provider.dart:90 logout()`'a `if (arama!=null) leave(notifyServer:true)`. **Doğrulama:** Plan 2 Adım 5'in 6 maddesi.
- **C6 — Dokümantasyon:** CLAUDE.md tuzaklarına controller deseni + "ekran dispose'u aramayı bitirmez"; oturum.md. FAZ SONU: build önerisi + onayda dağıtım rutini.

## 5) YAPMA / ERTELE LİSTESİ (açık hüküm)

**YAPMA (bu pakette hiç):** uygulama-dışı PiP; bantta video önizleme/sürükleme (v1 yeşil bant); ring/cevapsız fazında minimize; `restartTrack` ile çözünürlük yükseltme (tek istisna A3'ün aynı-çözünürlük kurtarması); `_statusText` kapısı ve süre tasarımına dokunma; CallKit şerit başlığını yükseltmede güncelleme (B'de eski isim — kabul edilen sınır); busy sorgusuna call_participants ekleme (canlı 1:1 yoluna dokunmama); grup History/AdminCalls'a yükseltilmiş aramayı ekleme (grup geçmişi ayrı faz); oda/yayın için AktifOdaController genelleştirmesi (yalnız tasarım notu); LiveKit port genişletme (bakım penceresi).

**ERTELE (ayrı commit/karar):** Plan 1 Adım 5 grup izgara tam-ekran paritesi (A7 sahada doğrulanınca); Plan 3 Adım 2d Active grup-davet sorgusu (önerilir, Faz-B sonrası ayrı commit); "minimize'da kamerayı otomatik kapat" opsiyonu (kullanıcıya sorulacak); canlı yayına/odaya davet işi (ayrı planlama ajanının hükmü — muhtemelen Faz-B sonrasına eklenir, bu planın parçası DEĞİL).

## 6) SÜREÇ (her fazda zorunlu)

Her adım: Edit tool (PowerShell regex YASAK) → `flutter analyze` / `go build ./...` temiz → commit+push+`git rev-parse origin/main` teyidi → oturum.md güncelle. Her faz sonu build/test edilebilir; build ve dağıtım YALNIZ kullanıcı onayıyla (dağıtım kontrol listesi + her sürümde DB temizleme). Arama hatası ararken ÖNCE oda logu (`docker logs livekit | grep call_<id>`), admin panel Ses Teşhis SES-VAR kontrolü.

---

# EK: UZMAN PLANLARI (hukumun referans verdigi tam metinler)


## PLAN 0 — P1 KAMERA

# P1 — Android yayında İLK video yok: Kök neden + Çözüm planı (SEÇİM: A — önizleme track'ini taşı)

## 0) KAYNAK İNCELEME SONUCU (kanıt, dosya:satır)

**flutter_webrtc 1.4.0 Android gerçeği (şüpheden farklı çıktı):**
- `dispose` ASLINDA kapanışı BEKLİYOR: `MethodCallHandlerImpl.trackDispose` (1723-1740) → `GetUserMediaImpl.removeVideoCapturer` (841-862) → `stopCapture()` + `cameraEventsHandler.waitForCameraClosed()` — Camera2 `onClosed` callback'ine kadar busy-wait. Yani `await t.stop()` dönünce kamera SDK seviyesinde kapalıdır. AMA `onClosed` ≠ HAL/camera-service'in cihazı gerçekten serbest bırakması (OEM'lerde gecikir) ve libwebrtc açılışta yalnız 3 deneme × 500ms yapar → dar ama gerçek yarış penceresi.
- **ASIL BOMBA — setCameraEnabled Android'de SESSİZ başarısız olur:** `GetUserMediaImpl.getUserVideo`: `startCapture` (801) → `waitForCameraOpen()` (803); `CameraEventsHandler.waitForCameraOpen` (20-29) **OPENED VEYA ERROR'da döner**, dönüşte state HİÇ KONTROL EDİLMEZ (806-838) → kamera açılamasa bile track üretilip getUserMedia BAŞARI döner. livekit `setCameraEnabled` → `createCameraTrack` (local.dart:791-796) hata görmez → **ölü (kare üretmeyen) video track sinyal seviyesinde publish edilir, medya hiç akmaz**.
- Bu, sahadaki tabloyla birebir örtüşen TEK yol: yayın sürdü (exception yok — olsa `_odayaBaglan` catch→`rethrow`→"Yayına bağlanılamadı"+bitir olurdu), ses gitti, yayıncı ekranı siyah (track var, kare yok), sunucu grep'inde video katman logu yok (kare yok → medya seviyesi log yok). 2. yayında kamera çoktan serbest → düzeldi.

**livekit_client 2.8.1 — Çözüm A'nın API zemini VAR ve SDK'nın kendi deseni:**
- `publishVideoTrack(track)` public (local.dart:262-268); Room dışında üretilmiş track publish edilebilir (createCameraTrack static, Room'a bağlı değil).
- SDK'nın kendisi aynısını yapıyor: PreJoin/FastConnect yolunda dış track `publishVideoTrack(track, publishOptions: roomOptions.defaultVideoPublishOptions)` ile yayınlanıyor (room.dart:461-471; options.dart:32-37 dokümantasyonu "PreJoin sayfasında kamera önizleme track'i üret, bağlanınca otomatik yayınla" diye açıkça tarif ediyor).
- Publish ayarları uygulanır: `_publishVideoTrack` → `publishOptions ??= track.lastPublishOptions ?? room.roomOptions.defaultVideoPublishOptions` (local.dart:279); encoding'ler `track.currentOptions.params.dimensions`tan hesaplanır (321-346) — önizleme zaten `kCameraCaptureOptions` (720p) ile üretiliyor (live_start_screen.dart:58) → VP8+simulcast+balanced profil AYNEN uygulanır.
- Oda kapanışı track'i kapatır: `stopLocalTrackOnUnpublish` varsayılan true (options.dart:138) + `room._cleanUp → unpublishAllTracks` (room.dart:1002) → publish SONRASI mevcut `_kapatOda` kamerayı serbest bırakır. Yalnız "publish edilemeden çıkış" pencereleri elle temizlik ister.

## A/B KIYASI ve SEÇİM

**(B) doğrula+retry:** Ek olarak kalır ama TEK BAŞINA zayıf: (1) kök yarışı yerinde bırakır, ilk yayında yine siyah pencere + retry döngüsü; (2) tespit güvenilmez — setCameraEnabled ölü track'te de publication DÖNER (null kontrolü işe yaramaz), kare kontrolü ise dynacast yüzünden ancak "kümülatif framesSent==0" ile sağlıklı; (3) retry = yeni kapat-aç döngüsü, aynı yarışa tekrar girebilir.
**(A) önizleme track'ini taşı:** Kamera HİÇ kapanmaz → kapat-aç yarışı TASARIMLA yok olur; SDK'nın belgeli PreJoin deseni; bonus UX (yayın ekranı siyah boşluksuz, anında görüntü). Maliyeti: track sahipliği devri disiplini (aşağıda tek-nokta kuralıyla çözülüyor).
**KARAR: A uygulanır + B'nin incecik hali (kümülatif-kare telemetrisi + TEK seferlik kurtarma) güvenlik ağı olarak üstüne konur.** Backend/LiveKit sunucu değişikliği YOK.

## GLOBAL "NEYİ BOZMAMALI" (her adımda geçerli)
- 1:1/grup arama CANLI ve KIRILGAN: `calls/` klasörüne (call_screen, call_provider, callkit, call_room_lock) DOKUNULMAZ; değişiklik yalnız `live/` iki dosyada.
- iOS ses sırası (v7/v8): `_odayaBaglan` sırası mic → video → `setSpeakerOn` → `_sesiAc(true)` EN SON — sıra AYNEN kalır, yalnız "video" adımının içi değişir.
- CallRoomLock semantiği, 'yayin-önizleme' muhafızı, F1 `_svc` initState-cache deseni, popUntil rota-adı çıkışı, X-butonu kilidi: DOKUNULMAZ.
- `restartTrack` çözünürlük yükseltmede kullanılmaz (CLAUDE tuzağı) — adım 3'teki kurtarma AYNI çözünürlükle taze capturer açar, tuzak kapsamı dışı.

## ADIM 1 — DOSYA: `mobile/lib/features/live/live_start_screen.dart`
**NE DEĞİŞİR:**
- `_basla()` içinde `await _onizlemeBirak();` (satır 109) KALDIRILIR; yerine sahiplik devri: `final onizlemeTrack = _onizleme; _onizleme = null;` (setState YOK — rebuild olursa 1 kare spinner çakar; pushReplacement zaten ekranı söküyor) ve `LiveBroadcastScreen(... onizlemeTrack: onizlemeTrack)` ile geçirilir.
- `if (!mounted)` dalı (110-113): devir henüz yapılmadıysa mevcut akış; devir SONRASI bu dal kalmaz (devir pushReplacement'ın hemen öncesinde yapılır).
- catch dalı (124-133): devir yapılmadan hata → `_onizleme` hâlâ ekranda, dispose→`_onizlemeBirak` mevcut davranış (değişmez).
**NEDEN:** Track'i öldür-yeniden-doğur yerine yaşat-taşı; kök yarış (HAL kapanış gecikmesi vs yeni open) hiç oluşmaz.
**BOZMAMALI:** REST-öncesi muhafız kontrolü (83-87), REST-sonrası muhafız TEKRARI + `bitir` geri alma (99-107), X-butonu `_basliyor` kilidi (170) AYNEN. Muhafız/mounted dallarında track devri OLMAZ (ekran açık kalıyor, önizleme sürmeli).
**DOĞRULAMA:** (a) Önizleme aç→X ile çık→tekrar önizleme aç (track bırakılıyor); (b) önizlemedeyken gelen aramayı kabul et→"yayın başlatılmadı" yolu→sonra 1:1 görüntülü arama kamera açılıyor (sızıntı yok); (c) yayın başlat→önizlemeden yayına GEÇİŞTE görüntü kesintisiz.

## ADIM 2 — DOSYA: `mobile/lib/features/live/live_broadcast_screen.dart`
**NE DEĞİŞİR:**
- Constructor'a `final lk.LocalVideoTrack? onizlemeTrack;` (null olabilir: gelecekte kamerasız/yeniden-giriş yolları için geriye uyumlu).
- State'e sahiplik alanları: `lk.LocalVideoTrack? _devralinan;` (initState'te `widget.onizlemeTrack`) + `bool _videoYayinda = false;`.
- `_odayaBaglan` (145-149 bölgesi): `setMicrophoneEnabled(true)` AYNEN; ardından video adımı:
  - `_devralinan != null` ise: `await room.localParticipant!.publishVideoTrack(_devralinan!, publishOptions: kVideoPublishOptions); _videoYayinda = true;` — try/catch ile; hata olursa (ör. track geçişte ended): Sentry breadcrumb + devralınanı yerinde bırak (temizlik `_kapatOda`'da) + geri düşüş `await setCameraEnabled(true)`; o da patlarsa mevcut catch→`_kapatOda`+`rethrow` akışı (davranış bugünkü hata yoluyla aynı).
  - `_devralinan == null` ise bugünkü `setCameraEnabled(true)` AYNEN.
  - Sonrası değişmez: `setSpeakerOn(true)` → `_sesiAc(true)` EN SON.
- `_kapatOda` (191-209): oda teardown'ının SONUNA tek-nokta salıverme: `final t = _devralinan; _devralinan = null; if (t != null && !_videoYayinda) { try { await t.stop(); await t.dispose(); } catch (_) {} }` — publish edilmişse oda zaten kapatır (`stopLocalTrackOnUnpublish:true` + unpublishAllTracks), çift-dispose YOK; `_kapandi` kilidi sayesinde tek kez koşar.
- `_kameram` getter: `... ?? _devralinan` — bağlantı sürerken de tam ekran canlı önizleme (siyah boşluk biter). Renderer key'i `ValueKey('yayin-${video.mediaStreamTrack.id}')` yapılır (publish öncesi `sid` null → publish sonrası key değişip renderer'ı boşuna söküyordu; mediaStreamTrack.id devir boyunca sabit).
**NEDEN:** publishVideoTrack SDK'nın kendi PreJoin yoluyla birebir aynı çağrı (room.dart:465-466); mute/kaynak eşlemesi bozulmaz çünkü `track.source == TrackSource.camera` (createCameraTrack bunu set ediyor) → `getTrackPublicationBySource(camera)` ve kamera çevir (`rtc.Helper.switchCamera`, mediaStreamTrack üstünden) aynen çalışır.
**BOZMAMALI:** `CallRoomLock.calistir` sarmalları, nabız timer'ının BAĞLANTI BAŞARILI olunca başlaması, `RoomDisconnected→_cik(sunucuyaBildir:true)`, PopScope onay dialogu, muhafız `yayin_<id>`, relay ICE, ayna kuralı (`_onKamera` + mirrorMode) — HİÇBİRİNE dokunulmaz. Publish sırası: mic HEP videodan önce.
**DOĞRULAMA:** (a) Android gerçek cihaz: İLK yayında görüntü izleyiciye gidiyor; `docker logs livekit | grep <stream_room>` → audio + 3 video katmanı `mediaTrack published` (oda adını filtrele — CLAUDE tuzağı); (b) art arda 5× yayın aç-kapat-aç → her seferinde ilk denemede video; (c) yayında kamera çevir ön/arka + ayna kuralı; (d) bağlanma HATASI simülasyonu (uçak modu ile connect kes) → "Yayına bağlanılamadı" + sunucuda yayın bitmiş + SONRAKİ yayın/arama girişi çalışıyor (track sızıntısı yok — en kritik yeni pencere bu); (e) iOS regresyon: yayın aç/kapat → hemen ardından 1:1 arama iki yönde ses (v7/v8 sırası).

## ADIM 3 — Güvenlik ağı (B'nin incesi): aynı DOSYA `live_broadcast_screen.dart`
**NE DEĞİŞİR:** `_baglan` başarısından ~4sn sonra TEK seferlik kontrol (Timer, `_ayrildi`/unmounted iptalli): yayınlanan video track'te `getSenderStats()` → kümülatif `framesSent` toplamı 0 VE mic-değil-video muted değilse → Sentry'ye `yayin-video-olu` olayı (cihaz modeli + stream_id) + BİR kez kurtarma: `track.restartTrack()` (aynı çözünürlük — eski ölü capturer'ın kapanışı trackDispose'ta senkron beklenir, taze open başarılı olur). İkinci kontrol 8. sn'de; hâlâ 0 ise kullanıcıya snackbar: "Kamera görüntüsü gitmiyor — kamera çevir butonunu deneyin".
**NEDEN:** framesSent KÜMÜLATİFTİR → dynacast sonradan katmanları duraklatsa bile kamera bir an çalıştıysa >0 olur; ölü kamerada sonsuza dek 0 — tek güvenilir istemci-taraflı sinyal. Çözüm A kök nedeni kaldırsa da (arka planda kamera elinden alınma vb.) kalan senaryoları GÖRÜNÜR kılar; sessiz-siyah yayın bir daha yaşanmaz.
**BOZMAMALI:** Kontrol yalnız yayıncı video track'i üstünde; ses ölçümlerine/audio-stat sistemine dokunmaz; agresif döngüsel retry YOK (tek atış).
**DOĞRULAMA:** Normal yayında Sentry'ye olay DÜŞMEMELİ; flutter analyze temiz.

## ADIM 4 — Dokümantasyon + kayıt (CLAUDE.md kural 1-2-3)
**DOSYA: `CLAUDE.md`** (KRİTİK TUZAKLAR): yeni madde — "Android getUserMedia kamera açılamazsa HATA FIRLATMAZ (flutter_webrtc GetUserMediaImpl:803-838 ERROR'u yutar) → ölü track sinyal seviyesinde publish olur, medya akmaz; 'video yok' teşhisinde sinyal/medya log ayrımına dikkat. Önizleme→yayın geçişinde kamera track'i KAPATILMAZ, publishVideoTrack ile taşınır — geri döndürme (regresyon yapma)."
**DOSYA: `oturum.md`**: kök neden + A/B kararı + kanıt satırları + test sonuçları. Her anlamlı adımda commit+push, `git rev-parse origin/main` ile doğrula. Ayrıca sunucu tarafında stream_0fd65863'ün bitiş şekli (kullanıcı mı bitirdi / sweeper mı) admin listesinden teyit edilip nota eklenir (ölü-track senaryosunun ikincil teyidi).

## ADIM 5 — Çıkış kapısı
`cd mobile && flutter analyze` TEMİZ → commit+push → kullanıcıya BUILD ÖNERİSİ sunulur (onaysız build/dağıtım YOK — kural 4). Build onayı gelirse dağıtım kontrol listesi (debug imza yok, R2, purge, boyut teyidi, DB temizliği) aynen uygulanır. Kullanıcı saha testi ölçütü: Android'den İLK yayında görüntü + admin panel/livekit logunda video katmanları; ardından 1:1 + grup + oda regresyon turu (mevcut test rehberleri).

## PLAN 1 — ARAMA-ICI UI

# ARAMA-İÇİ UI PARİTESİ PLANI (WhatsApp görünümü) — 1:1 + grup

TEK DOSYA: `C:\Users\gebze\OneDrive\Desktop\gbz-a3\mobile\lib\features\calls\call_screen.dart` (başka dosyaya dokunulmaz; backend/provider/callkit değişmez).

## KÖK NEDEN BULGUSU (görev 1 — self-view "saçma eğrilik")
Texture/platform-view kırpma sorunu DEĞİL. Kanıt: `call_screen.dart:1092` self-view `VideoTrackRenderer`'ına `fit:` VERİLMEMİŞ → livekit_client 2.8.1 varsayılanı `VideoViewFit.contain` (`video_track_renderer.dart:81`). Contain modunda renderer, videoyu kendi en-boy oranında KÜÇÜLTÜP 140x200 kutunun içinde ortalıyor (renderer `build()` 293-333: `SizedBox(width: height*aspect)` + Center). Kamera ~9:16 (0.5625), kutu 0.7 → video ~112x200, yanlarda ~14px boşluk; arkadan büyük (remote) video görünüyor. `ClipRRect(24)` ise KUTUYU kırpıyor → köşe yayı içerideki videonun düz kenarını kısmen keserek tuhaf/yarım eğri üretiyor = kullanıcının gördüğü bozukluk. Ek etken: 24px radius 140px genişlikte oransal fazla (WhatsApp ~12-14). Büyük pencere (972) ve grup tile (1369) `cover` verdiği için onlarda sorun yok — teşhis bununla da tutarlı.

## ADIM 1 — Self-view WhatsApp görünümü (radius + çerçeve + gölge + cover)
- DOSYA/YER: `_buildSelfView` (1057-1099).
- NE DEĞİŞİR:
  1. Renderer'a `fit: VideoViewFit.cover` eklenir (1092) → video kutuyu doldurur, letterbox biter.
  2. `ClipRRect borderRadius: 24 → 14` (1089).
  3. ClipRRect bir dış `Container` ile sarılır: `borderRadius: 14`, `border: Border.all(Colors.white24, width: 1)`, `boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0,4))]`. NEDEN dışta: ClipRRect gölge ÇİZEMEZ; gölge/çerçeve dekorasyonu kırpmanın dışında olmalı.
- BOZMAMALI: `GestureDetector(behavior: opaque)` + `IgnorePointer` sırası AYNEN (CameraUtils NPE koruması, 1046-1053 yorumları); `ValueKey('small-...')` (1093) AYNEN (swap bayat-texture fix'i); `mirrorMode: isLocal ? _yerelAyna : auto` AYNEN (kamera-ters fix'i F3). Swap/sürükleme mantığına dokunulmaz.
- DOĞRULAMA: `flutter analyze` temiz; gerçek cihazda görüntülü 1:1 → köşeler eşit ve yumuşak, kenarlarda boşluk yok, ince beyaz çerçeve + gölge; swap (dokun), sürükle-4-köşe, kamera kapat→aç (swap sıfırlanır) regresyonsuz.

## ADIM 2 — Self-view konumunu KÖŞE-bazlı sakla (Adım 4'ün küçülme hazırlığı)
- DOSYA/YER: state alanları 104-107 + `_buildSelfView` pan mantığı (1072-1087).
- NE DEĞİŞİR: `Offset? _selfPos` yalnız PAN SIRASINDA geçici kalır; panEnd'de köşeye yapışırken sonuç `bool _selfSagda`/`_selfAltta` olarak saklanır ve `_selfPos=null` yapılır. Build'de konum: `_selfPos ?? köşedenHesapla(genişlik, yükseklik, üst/alt marj)`.
- NEDEN: Adım 4'te pencere boyutu küçülünce Offset saklanırsa pencere sağ/alt kenardan kopar (140-w kadar boşluk); köşe saklanırsa hiza her boyutta otomatik doğru.
- BOZMAMALI: mevcut clamp sınırları (üst 60 / alt `-140`, 1076/1085) ve 4-köşe yapışma DAVRANIŞI birebir aynı kalır; varsayılan konum sağ-üst top≥130 (üst bilgiyle çakışmama kararı, 1060-1061) korunur.
- DOĞRULAMA: sürükleme akıcı, panEnd 4 köşeye yapışıyor, varsayılan konum değişmedi.

## ADIM 3 — Üst bar: sol-üst KÜÇÜLTME oku + sağ-üst KİŞİ EKLE ve MESAJ (1:1 VE grup)
- DOSYA/YER: `build()` Stack'i, üst bilgi bloğunun (991-1029) yanına iki yeni `Positioned`.
- NE DEĞİŞİR:
  1. Sol: `Positioned(top: 44, left: 12)` → 40x40 daire buton (`Colors.black26` zemin, `LucideIcons.chevronDown` beyaz 22) → `_minimize()` çağırır. `_minimize()` bu planda BOŞ gövde + `// AJAN-3: davranış buraya bağlanacak` yorumu. KESİNLİKLE pop/leave çağırmaz (PopScope `canPop:false` sözleşmesi bozulmaz).
  2. Sağ: `Positioned(top: 44, right: 12)` → Row: kişi-ekle (`LucideIcons.userPlus` → `_kisiEkle()` boş, AJAN-3/4) + 8px + mesaj (`LucideIcons.messageSquare` → `_mesajaDon()` boş, AJAN-4). Aynı 40x40 daire stil.
  3. Üst bilgi Column'undaki isim `Text`'ine (997-1002) `Padding(horizontal: 60)` → uzun isim/grup başlığı köşe ikonlarıyla çakışmaz.
  4. Koşul: iki Positioned da `if (!_cevapsiz)` (cevapsız ekranda minimize/kişi-ekle anlamsız; Geri Ara/Kapat düzeni aynen kalır).
- NEDEN: WhatsApp yerleşimi; davranışlar ajan-3/4'e ait — burada yalnız görsel iskelet + boş metodlar, böylece ajanlar çakışmadan gövdeleri doldurur.
- BOZMAMALI: üst bilgi Column içeriği (isim + `_statusText` + kalite noktası + "Ses gelmiyor" teşhis butonu) AYNEN; `_statusText` kapısına dokunulmaz (yargıç YAPMA listesi); self-view varsayılan top 130 > ikon altı 84 → çakışma yok.
- DOĞRULAMA: 1:1 sesli/görüntülü + grup sesli/görüntülü dört görünümde ikonlar köşede, isim taşmıyor; ikonlara basmak hiçbir şey bozmuyor (no-op); cevapsız ekranda ikonlar yok.

## ADIM 4 — Ekrana dokun → kontroller/üst bar GİZLE + self-view KÜÇÜLT (toggle)
- DOSYA/YER: `build()` (957-1042), `_buildSelfView`, `_grupVideoIzgara` (1307-1341), `_cevapsizGoster` (264), `_toggleCam` (860-865).
- NE DEĞİŞİR:
  1. Yeni state `bool _uiGizli = false;` + `void _uiToggle()` (`setState(() => _uiGizli = !_uiGizli)`).
  2. TOGGLE KAYNAĞI (jest çakışması sıfır olacak şekilde):
     - 1:1 video: büyük renderer'ın `Positioned.fill` child'ı `GestureDetector(behavior: HitTestBehavior.opaque, onTap: _uiToggle, child: IgnorePointer(child: VideoTrackRenderer(...)))` olur. Bu IgnorePointer AYRICA mevcut gizli bir çökme riskini kapatır: swap'ta büyük pencere LOCAL track gösteriyor ve flutter_webrtc, mobil local track'i kendi `GestureDetector(onTapDown → onViewFinderTap → setFocusPoint)` ile sarıyor (`video_track_renderer.dart:267-280`) = self-view yorumundaki CameraUtils NPE sınıfı. Bilinçli yan etki: büyük local pencerede pinch-zoom/tap-focus devre dışı (zaten kullanılmıyor, NPE riskliydi).
     - Grup video: `_grupVideoIzgara`'nın kök `Container`'ı `GestureDetector(onTap: _uiToggle)` ile SARILIR (ancestor olduğu için GridView scroll'u drag arena'da kazanmaya devam eder, tap ise tile'lar IgnorePointer'lı olduğundan bu detector'a düşer — tile başına jest EKLENMEZ, RİSKLER notundaki IgnorePointer+opaque kuralı zaten uygulanmış durumda).
     - SESLİ görünümlerde (1:1 `_buildAudioBackground` + grup avatar ızgarası) toggle YOK — sesli grup "pikseli pikseline aynı" şartı ve WhatsApp davranışı (seslide kontroller gizlenmez).
  3. GİZLENEN KATMANLAR: üst bilgi Positioned'ı (991), Adım 3'ün iki üst-bar Positioned'ı ve alt kontroller Positioned'ı (1032) → her biri `AnimatedOpacity(200ms, opacity: gizli?0:1)` + `IgnorePointer(ignoring: gizli)` ile sarılır. IgnorePointer ŞART: görünmez kırmızı tuşa/mikrofona kazara basılmasın; gizliyken ilk dokunuş SADECE geri getirir.
  4. EFEKTİF GİZLİ MASKESİ: `final videoModu = (!widget.isGroup && showVideo) || (widget.isGroup && izgaraVideoModunda); final gizli = _uiGizli && videoModu && !_cevapsiz && _error == null && !_connecting;` — state'i build içinde YAZMADAN okurken maskele (kamera kapanıp sesli görünüme dönülünce kontrollerin kilitli-görünmez kalması imkânsızlaşır). Ek emniyet: `_cevapsizGoster()` içinde `_uiGizli=false`, `_toggleCam`'in kapama dalında (`if (!on)`) `_selfBuyuk=false`'un yanına `_uiGizli=false`.
  5. SELF-VIEW KÜÇÜLME: boyutlar sabit yerine getter: normal 140x200, gizli 100x143 (oran korunur); alt marj gizliyken 140→40 (kontroller yokken pencere aşağı iner — WhatsApp). Adım 2'nin köşe-bazlı konumu sayesinde hiza otomatik. Geçiş `AnimatedPositioned(200ms)`; `_selfPos != null` (pan sürüyor) iken düz `Positioned` (sürükleme lag'lemesin).
- NEDEN: WhatsApp deseni; jest ayrışması: self-view onTap=SWAP (kendi opaque detector'ı, dokunuş asla alta geçmez), self-view onPan=SÜRÜKLE, arka plan onTap=UI TOGGLE — üçü farklı widget'ta, arena çakışması yok.
- BOZMAMALI (kritik liste):
  - SÜRE SENKRONU: `_sureReferansiAl/_startTimer/_tick/_statusText` HİÇ DEĞİŞMEZ — süre gizliyken de saymaya devam eder, yalnız opacity 0.
  - iOS SES SIRASI: `_odayaBaglan` / `_sesiAc` / `_kapatOda` / CallRoomLock'a SIFIR dokunuş (tüm değişiklik build/görsel katmanda).
  - PopScope `canPop:false`, `_leave` tek-sefer kilidi, cevapsız ekran akışı, `ParticipantDisconnected`'ın grupta `_leave` YAPMAMASI (403-414) aynen.
  - GRUP İZGARA HESABI: `GridView.count` parametreleri, `padding: EdgeInsets.zero` (safe-area tuzağı yorumu), cols/rows/kaydırma eşiği (1313-1337) bu adımda DOKUNULMAZ; dış Container padding'i de sabit kalır (gizlide kenarlarda boşluk kalması kabul — Adım 5 opsiyonu).
  - `ekranAcildi/ekranKapandi/aktifKonusma*` muhafızları ve dispose sırası değişmez.
- DOĞRULAMA (gerçek cihaz, 2 telefon):
  (a) 1:1 görüntülü: ekrana dokun → üst bar+kontroller kaybolur, self-view küçülüp köşesinde kalır; tekrar dokun → geri; gizliyken görünmez butonlara basılamıyor; self-view'e dokun → SWAP (UI toggle tetiklenmiyor); sürükleme çalışıyor; süre iki cihazda senkron saymaya devam.
  (b) Swap'ta büyük pencereye (kendi kameran) hızlı çok dokunuş → çökme YOK (NPE kapandı), yalnız toggle.
  (c) Kamera kapat (sesli görünüme dön) → kontroller kesin görünür.
  (d) Grup görüntülü: izgaraya dokun → gizle/göster; 9+ kişide kaydırma hâlâ çalışıyor; sesli grup ekranında dokunma hiçbir şey yapmıyor ve görünüm birebir eski.
  (e) Cevapsız senaryo: arama reddedilince Geri Ara/Kapat HER ZAMAN görünür (gizli açılamaz).
  (f) Regresyon: art arda arama, CallKit'ten kabul, kamera flip (ayna doğru), 1:1 sesli.

## ADIM 5 (OPSİYONEL, AYRI COMMIT — ancak Adım 4 sahada doğrulanınca)
- Grup izgara tam-ekran paritesi: dış Container padding'i `gizli ? EdgeInsets.fromLTRB(8, safeTop+8, 8, safeBottom+8) : (8,108,8,132)`. GridView içi `EdgeInsets.zero` ve hesap mantığı AYNEN. Risk düşük (LayoutBuilder rotasyondaki gibi yeniden ölçer) ama grup izgara kırılgan geçmişi nedeniyle ayrı commit + ayrı testte: 2/4/9 kişi video, alt sıra kırpılmıyor.

## GENEL KURALLAR (her adımda)
- Her adım ayrı commit + push, `git rev-parse origin/main` doğrulaması (CLAUDE.md kural 3); her adım sonrası `cd mobile && flutter analyze` temiz.
- PowerShell ile toplu regex replace YOK — Edit tool (UTF-8/emoji tuzağı).
- oturum.md her adımdan sonra güncellenir.
- Ajan-3 (minimize davranışı) ve ajan-4 (kişi ekle/mesaj davranışı) bağlanma noktaları: `_minimize() / _kisiEkle() / _mesajaDon()` boş metodları — bu planın butonları onların tek giriş kapısı.

## PLAN 2 — MINIMIZE

# UYGULAMA-İÇİ KÜÇÜLTME ("ARAMAYA DÖN") — UYGULAMA PLANI (19 Tem 2026)

## 0) KAYNAK DURUMU
- ESKİ PLAN ARŞİVİ BULUNDU VE OKUNDU: `C:\Users\gebze\.claude\projects\c--Users-gebze-OneDrive-Desktop-gbz-a3\a63d1ddb-351c-42c3-bf53-7f509b37975c\subagents\workflows\wf_0bb6353d-2b2\journal.jsonl` — 3. ajanın planı: ActiveCallController/activeCallProvider + CallScreen saf görünüm + MaterialApp.builder'a banner + minimize/restore. Bu plan o iskeleti alır ama GÜNCEL koda uyarlar; eski plan şu işlerden ÖNCE yazılmıştı ve hepsi artık call_screen.dart'ta yaşıyor, AYNEN taşınmak zorunda: süre senkronu (Stopwatch + _sureBaz + elapsed_ms, 3 kez elden geçti — REGRESYON YASAK), grup araması (isGroup dalları), cevapsız UI + Geri Ara, ses nesli jetonu (_sesNesilSayaci), stats + ölü-mik oto-kurtarma, _leave içinde CallKitService.bitir + CallRoomLock enqueue (seri arama fix'i), v13 "cevapsızda ekranKapandi" muhafız bırakması.
- Eski planın 5 risk notu bu plana işlendi: (1) bitiş-poll controller'da SÜRMELİ, (2) resume uzlaştırması controller'a, (3) banner'a dokununca çift push koruması, (4) Room mutable → ChangeNotifier (StateNotifier değil), (5) CallRoomLock/ses sayacı tek-oda olduğu için etkilenmez.
- Backend DEĞİŞMİYOR (hiçbir uç/WS olayı eklenmez). 1:1 + grup arama CANLI ve KIRILGAN — her adım tek başına derlenir/test edilir, riskli adım tam regresyonla kapanır.

## MİMARİ KARARLAR (özet)
1. **ActiveCallController** = `ChangeNotifier` + `WidgetsBindingObserver`, uygulama boyu yaşar (`ChangeNotifierProvider`, autoDispose YOK). Room, listener, TÜM timer'lar (ring/status/stats/duration/mediaYedek), süre Stopwatch'ı, muhafız çağrıları, ses birimi/nesli, CallSounds, cevapsız durumu buraya taşınır. CallScreen SAF GÖRÜNÜM olur. (StateNotifier DEĞİL: Room mutable, immutable state ile boğuşmak regresyon riski.)
2. **Minimize KAPSAMI (bilinçli daraltma):** yalnız BAĞLI aramada (`_baglandi && !_cevapsiz && _error==null`) küçültülebilir. Çalıyor/cevapsız fazında geri tuşu BUGÜNKÜ gibi bloklu kalır. Neden: ring sesi, 45sn timeout, cevapsız-UI ve zil kenar durumları ekrandayken çözülü; ilk sürümde bu fazları taşımak gereksiz risk.
3. **Yüzen pencere v1 = ÜST YEŞİL BANT** (WhatsApp deseni: 0xFF25D366, avatar harfi + isim/grup adı + CANLI süre + "dokun: aramaya dön"). Video küçük önizleme YOK, sürükleme YOK. Neden: VideoTrackRenderer'ı Navigator-dışı kalıcı overlay'e koymak texture/CameraUtils-NPE ve kamera yaşam döngüsü riski (oturum.md dersi: renderer'a dokunuş gitmemeli); avatar bant sıfır medya riski. Sürüklenebilir video penceresi ileriki iterasyon.
4. **Teardown "enqueue anında yakala"** (tek zorunlu uyarlama): bugün `_kapatOda` widget örneğinin alanlarını kullanıyor; her ekranın KENDİ kopyası var, o yüzden güvenli. Tek controller'da alanlar yeni aramada RESET'lenir → kuyrukta bekleyen eski teardown yeni Room'u öldürebilirdi. Çözüm: kuyruğa koyarken `final room=_room; final listener=_listener; final nesil=_benimSesNeslim; _room=null; _listener=null;` SENKRON yakala, kapatma closure'u yalnız bu yakalanan nesnelerle çalışsın. Sıra semantiği bugünkü `_leave` başındaki enqueue ile BİREBİR aynı kalır (seri arama fix'i korunur).
5. **Ekran aç/kapa tek kapıdan:** controller'a `ekraniAc()` (RouteSettings(name:'arama') + rootNavigatorKey push) — 5 push noktası mekanik olarak `baslat(bilgi)` + `ekraniAc()` çiftine döner. Ekran kendini controller'a kaydeder (`ekranGorunur`); bitişte pop yalnız ekran görünürse yapılır (Spaces B1 dersi: kör pop, üstteki sheet/dialog'u kapatır — CallScreen'de sheet yok ama desen baştan doğru kurulur).

---

## ADIM 1 — ActiveCallController dosyası (BAĞLANMADAN yazılır)
- **DOSYA:** `mobile/lib/features/calls/active_call_controller.dart` (YENİ)
- **NE DEĞİŞİR:** Yeni dosya; başka hiçbir dosyaya dokunulmaz.
  - `class AramaBilgisi` (meta): callId, url, token, video, peerName, peerId?, outgoing, isGroup, chatTitle, elapsedMs? — CallScreen constructor parametrelerinin birebir kopyası.
  - `class ActiveCallController extends ChangeNotifier with WidgetsBindingObserver` + `final activeCallProvider = ChangeNotifierProvider<ActiveCallController>(...)`. Constructor `Ref` alır; `CallService`'i `_ref.read(callServiceProvider.notifier)` ile kullanır (servis app-boyu — ref-in-dispose tuzağı yok çünkü controller HİÇ dispose olmaz).
  - call_screen.dart'tan TAŞINACAK (bu adımda KOPYALANIR, ekran henüz dokunulmaz) alanlar (satır 55-107): _room, _listener, _endedSub/_answeredSub, _durationTimer, _ringTimeout, _statusPoll, _statsTimer, _sonRecvPaket/_sonEnergy/_sonSentPaket/_sonMikEnerji/_oluMikSayaci/_sesKurtarmaDenendi, _sesNesli, _connecting/_kapandi/_baglandi/_ayrildi/_peerJoined/_mediaBasladi/_mediaYedek, _micOn/_camOn/_speakerOn/_frontCamera, _error, _duration+_sureSayaci+_sureBaz+_sureReferansVar, _quality, _cevapsiz/_cevapsizNeden, _audioCh, _sesNesilSayaci/_benimSesNeslim. YENİ alanlar: `AramaBilgisi? arama` (null=arama yok), `bool minimized=false`, `bool ekranGorunur=false`.
  - TAŞINACAK metotlar (birebir kopya, mekanik dönüşümlerle): initState gövdesi → `Future<void> baslat(AramaBilgisi b)` (satır 109-195: ekranAcildi, ended/answered abonelikleri, outgoing dalı: kabulEdilenler||isGroup → _connect kısayolu [grup-host mic fix'i], calmaTonu+nesil, 45sn ringTimeout, 2sn statusPoll; incoming dalı: _connect). `_durumKontrol` (200-236), `didChangeAppLifecycleState`+`_kesintidenTopla` (238-260; controller kendini `WidgetsBinding.instance.addObserver` ile constructor'da kaydeder), `_cevapsizGoster` (264-286), `_geriAra` (289-315 → `Future<AramaBilgisi?> geriAra()`: eski oturumu kapatıp yeni start atar, meta döner; push'u EKRAN yapar), `_connect` (317-367), `_odayaBaglan` (371-515 — iOS SES SIRASI bloğu karakteri karakterine: mic→cam→setSpeakerOn(false)→_sesiAc(true) EN SON), `_aktifPollBaslat`, `_statsBaslat` (530-610, ölü-mik kurtarma dahil), `_sureReferansiAl` (617-626), `_startTimer/_tick`, `_mediaBaslat/_mediaGuvenlikAgi/_remoteAudioHazir`, `_sesDurumOku`, `sorunBildir` (698-717; snackbar EKRANDA kalır), `_sesiAc` + nesil jetonu (723-740), `_sesLog`, `_kapatOda` → KARAR-4'teki "enqueue anında yakala" biçiminde `_kapatOdayiKuyrugaKoy()` + `static Future<void> _odaTemizle(room, listener, nesil)` (752-777'nin timeout'ları AYNEN), `_leave` (788-824: _ayrildi kilidi → CallKitService.bitir → _kapatOdayiKuyrugaKoy → CallSounds.durdur → [ekranGorunur ise pop tetikle] → end REST → gecmisiYenile → `arama=null; minimized=false; notifyListeners()` + aktifKonusmaBitti/ekranKapandi — bugün dispose'ta olan iki muhafız bırakması TEK KAPI _leave'e taşınır), toggleMic/Cam/Speaker/flipCamera (826-889; snackbar'lar `rootMessengerKey.currentState` ile — CLAUDE.md: builder-dışı widget kuralıyla aynı desen), `_yerelAyna` getter, `_statusText` mantığı → `String get durumMetni`.
  - Mekanik dönüşümler: `setState(...)` → alan ata + `notifyListeners()`; `if (!mounted)` → `if (arama == null || _ayrildi)`; `widget.callId/video/isGroup...` → `arama!.callId...`; `baslat()` başında TÜM tek-seferlik bayraklar resetlenir (_kapandi/_baglandi/_ayrildi/_mediaBasladi/_sureReferansVar/_cevapsiz/sayaçlar) — reset SIRASI teardown'ı etkilemez çünkü teardown artık yakalanmış nesnelerle çalışır (KARAR 4).
  - `minimize()`: `if (!_baglandi || _cevapsiz || _error != null) return;` → `minimized=true; notifyListeners();` (pop'u ekran yapar). `restore()`: `minimized=false; notifyListeners(); ekraniAc();`. `ekraniAc()`: zaten `ekranGorunur` ise no-op (çift push koruması); `rootNavigatorKey.currentState?.push(MaterialPageRoute(settings: RouteSettings(name:'arama'), builder: (_) => CallScreen(bilgi: arama!)))`.
- **NEDEN:** Tüm mantık tek dosyada, ekran bağlanmadan yazılınca davranış sıfır risk; Adım 2'nin diff'i "ekranı bağla + eskiyi sil"e iner.
- **NEYİ BOZMAMALI:** Hiçbir mevcut dosyaya dokunulmadığı için hiçbir şey. Kopyalarken YASAKLAR: `_sesiAc(true)` EN SON sırası; `_statusText` kapısı (yargıç YAPMA listesi); süre tasarımı (referans yalnız s=='active', created_at'e düşürme YOK, push süre taşımaz, grup hariç yerel sayaç); ParticipantDisconnected grup dalında otomatik _leave YOK; relay ICE; grup 540p profili.
- **DOĞRULAMA:** `cd mobile && flutter analyze` TEMİZ (kullanılmayan-eleman uyarısı çıkarsa provider'ı dosya içinde referanslayan not düş). Uygulama davranışı değişmedi (controller hiçbir yerden çağrılmıyor). Commit+push.

## ADIM 2 — CallScreen'i saf görünüme çevir + 5 push noktası (EN RİSKLİ ADIM, TAM REGRESYON)
- **DOSYA:** `mobile/lib/features/calls/call_screen.dart` (büyük diff), `mobile/lib/main.dart` (251-264), `mobile/lib/features/calls/incoming_call_overlay.dart` (103-115), `mobile/lib/features/calls/calls_tab.dart` (186-195), `mobile/lib/features/chats/chat_screen.dart` (103-112), `mobile/lib/features/calls/group_call_start_screen.dart` (77-88)
- **NE DEĞİŞİR:**
  - CallScreen constructor: tek parametre `AramaBilgisi bilgi` (5 çağrı noktası zaten tüm alanları veriyor; mekanik). Ekranda KALAN state YALNIZ görsel: `_selfPos`, `_selfBuyuk`, `_sorunBildirildi`. initState: `_c = ref.read(activeCallProvider)` (cache — ref-in-dispose F1 tuzağı: dispose'ta ref.read YASAK, cache şart); `_c.ekranGorunur=true; _c.minimized=false;` + `ref.listen` YERİNE build'de `ref.watch(activeCallProvider)`; bitiş pop'u için `ref.listenManual` veya initState'te controller'a bir `VoidCallback onBitti` kaydı: arama==null olunca `if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop()` (post-frame güvenceli). dispose: `_c.ekranGorunur=false;` + `if (_c.arama != null && !_c.minimized) _c.minimized=true;` (dıştan beklenmedik pop = güvenli minimize; arama ASLA dispose ile bitmez) — ekrandaki ESKİ dispose içerikleri (muhafız bırakma, timer cancel, CallRoomLock enqueue satır 897-912) SİLİNİR, hepsi controller._leave'de.
  - build: tüm `_xxx` okumaları `c.xxx`'e döner (remote/local video getter'ları, _buildGroupGrid/_grupVideoIzgara/_grupAvatar/_grupVideoTile, _yerelAyna, durum metni, kalite noktası). VideoTrackRenderer KULLANIMLARI (key'ler, IgnorePointer, mirrorMode, fixed(1.0) DPR) PİKSELİ PİKSELİNE AYNEN kalır. Kırmızı tuş → `c.leave(notifyServer:true)`; cevapsız butonları → `c.geriAra()` (dönen meta ile pushReplacement yerine: `c` zaten yeni aramayı başlattı → ekran kendini yeni bilgiyle rebuild eder; en basiti: geriAra sonrası `Navigator.pushReplacement(CallScreen(bilgi: yeni))`) ve `c.leave(notifyServer:false)`. PopScope: `canPop:false` KALIR; `onPopInvokedWithResult`: BU ADIMDA HİÇBİR ŞEY YAPMAZ (bugünkü davranış birebir — minimize Adım 4'te açılır).
  - 5 push noktası: `final info = await svc.start/startGroup/answer(...)` AYNEN kalır; ardından `ref.read(activeCallProvider).baslat(AramaBilgisi(...));` + `ekraniAc()`. main.dart _callKitKabul ve incoming_call_overlay._accept'te SIRA korunur: ÖNCE answer, sonra baslat+ekraniAc, EN SON `notifier.dismiss()` (Riverpod-overlay tuzağı: önce ekran, sonra state temizliği). `baslat` içindeki `ekranAcildi` çağrısı sayesinde mesgul muhafızı bugünkü anlamıyla çalışmaya devam eder (`ekrandakiAramalar` artık "oturum canlı" demek; call_provider.dart:83-96 yorumu güncellenir, İSİM DEĞİŞMEZ).
- **NEDEN:** İki özelliğin tek ön koşulu: Room+süre+bitiş-poll route pop'undan sağ çıkmalı. Bu adım görünür davranışı DEĞİŞTİRMEDEN sahipliği taşır; sonraki adımlar küçük kalır.
- **NEYİ BOZMAMALI:** (a) iOS ses sırası (mic→cam→speaker(false)→_sesiAc(true) EN SON); (b) süre senkronu — elapsedMs answer/WS/Status yolları, referans kilidi, Stopwatch; (c) seri arama: teardown enqueue'su leave ANINDA (KARAR 4 deseni bunun birebir karşılığı); (d) grup: ParticipantDisconnected'da _leave YOK, sesli grup görünümü pikseli pikseline; (e) CallKit: _leave'de bitir, onRed/onTimeout aktifKonusmalar kapısı (main.dart 171-187 DOKUNULMAZ); (f) tek-seferlik kilitler (_kapandi/_baglandi/_ayrildi) ve muhafız-tekrarı desenleri; (g) 45sn ring→önce status sor; (h) `_statusText` kapı sırası.
- **DOĞRULAMA (2-3 gerçek cihaz, biri iOS — CallKit simülatörde çalışmaz):** flutter analyze TEMİZ; (1) 1:1 sesli iki yönde ses + süre iki cihazda SENKRON (WS'siz kurtarma: bir cihaz arka planda kabul); (2) 1:1 görüntülü: swap/sürükle/flip/ayna; (3) art arda 4-5 arama (seri yarış — ses/görüntü gitmeli); (4) kilit ekranı CallKit kabul + kırmızı tuşla kapat (native şerit anında sönmeli); (5) cevapsız/red/mesgul + Geri Ara; (6) grup sesli+görüntülü: iOS host (mic sessiz regresyonu!), biri ayrılınca arama sürer, kamera aç/kapat; (7) karşı taraf kapatınca <=3sn ekran kapanır (poll); (8) admin panel Ses Teşhis: her aramada SES-VAR. `docker logs livekit | grep call_<id>` (oda logu ÖNCE kuralı). Commit+push; oturum.md güncelle.

## ADIM 3 — Banner host (PASİF: görünmez, sıfır davranış değişikliği)
- **DOSYA:** `mobile/lib/features/calls/active_call_banner.dart` (YENİ), `mobile/lib/main.dart` (307-308)
- **NE DEĞİŞİR:** `AktifAramaBanner(child: ...)` ConsumerWidget: `final c = ref.watch(activeCallProvider); if (c.arama == null || !c.minimized) return child;` → değilse Stack ile üstte SafeArea'lı yeşil bant: sol telefon/video ikonu, `c.arama.isGroup ? chatTitle : peerName`, canlı `c.durumMetni` (mm:ss; _durationTimer notifyListeners ile banner'ı da tazeler), "Aramaya dönmek için dokun"; onTap → `c.restore()`. main.dart builder: `IncomingCallOverlay(child: AktifAramaBanner(child: child ?? ...))` (gelen-arama tam ekranı bantın ÜSTÜNDE kalır; aktif aramada zaten `aramadaMi` kapısı overlay'i açtırmaz).
- **NEDEN:** MaterialApp.builder Navigator'ın DIŞI + tüm sayfaların üstü — IncomingCallOverlay ile aynı kanıtlanmış yer. `minimized` hiç true olmadığı için bu adım görsel olarak ölü: banner altyapısı riske girmeden yayına girer.
- **NEYİ BOZMAMALI:** builder içindeki widget Navigator dışındadır — bant içinde `Navigator.of(context)` KULLANMA (rootNavigatorKey/rootMessengerKey); IncomingCallOverlay sarmalama sırası değişmesin.
- **DOĞRULAMA:** flutter analyze; uygulamada hiçbir görsel/davranış farkı yok (1:1 kısa duman testi). Commit+push.

## ADIM 4 — Minimize/restore'u AÇ (özelliğin kendisi)
- **DOSYA:** `mobile/lib/features/calls/call_screen.dart` (PopScope + üst bar)
- **NE DEĞİŞİR:** (a) Üst bilgiye SOL ÜST chevron-down butonu (yalnız `c.baglandi && !c.cevapsiz && c.error==null` iken görünür): `c.minimize(); Navigator.of(context).pop();`. (b) PopScope: `canPop:false` kalır; `onPopInvokedWithResult: (didPop,_) { if (!didPop && c.minimizeEdilebilir) { c.minimize(); Navigator.of(context).pop(); } }` — ring/cevapsız fazında geri tuşu ESKİSİ gibi hiçbir şey yapmaz. (c) Restore: banner tap → `restore()` → `ekraniAc()` → ekran initState `minimized=false` + Room'a YENİDEN BAĞLANMAZ (baslat çağrılmıyor; sadece görünüm mevcut Room'u render eder — `_c.arama.callId == widget.bilgi.callId` guard'ı; uyuşmazsa sadece pop).
- **NEDEN:** Kullanıcı arama sürerken sohbetlere girip mesaj atabilir; WhatsApp davranışı.
- **NEYİ BOZMAMALI:** Minimize bir "bitiş" DEĞİL: ekranKapandi/aktifKonusmaBitti ÇAĞRILMAZ (muhafızlar dolu kalır — mesgul koruması sürer); statusPoll/statsTimer/süre controller'da akmaya devam eder; _kapatOda/CallRoomLock'a bu yolda HİÇ girilmez; CallKit aktif kalır (iOS yeşil bar normaldir).
- **DOĞRULAMA (2 cihaz):** (1) bağlı 1:1'de küçült → sohbet gez, mesaj at; süre bantta canlı akar; karşı taraf sesi kesintisiz; (2) banta dokun → ekran aynı süre/mic/speaker/kamera durumuyla döner (yeniden bağlanma YOK — LiveKit logunda ikinci connect olmamalı); (3) küçültülmüşken KARŞI TARAF kapatır → bant <=3sn'de kaybolur (poll/WS), hayalet bant YOK; (4) küçültülmüşken kırmızı tuş yok — banttan dönüp kapat; (5) küçültülmüşken uygulama arka plana → dönünce resume uzlaştırma (_kesintidenTopla) çalışır; (6) grup aramada küçült/dön; (7) görüntülü aramada küçült (kamera yayını sürer — karşı taraf görmeye devam eder; bantta video yok, tasarım gereği), dönünce renderer'lar taze (track key'leri sayesinde); (8) ring fazında geri tuşu hâlâ bloklu; (9) minimize→restore→minimize 5 kez üst üste (state sızıntısı yok). Commit+push.

## ADIM 5 — Etkileşim sertleştirme: gelen arama/CallKit/başlatma muhafızları + mesaj ikonu
- **DOSYA:** `mobile/lib/features/calls/call_screen.dart` (mesaj ikonu), `mobile/lib/features/chats/chat_screen.dart` + `mobile/lib/features/calls/calls_tab.dart` + `mobile/lib/features/calls/group_call_start_screen.dart` + `mobile/lib/features/rooms/rooms_tab.dart` + `mobile/lib/features/live/live_tab.dart` (yalnız hata metni/restore kısayolu), `mobile/lib/features/auth` (çıkış yolu — dosya uygulama sırasında doğrulanacak)
- **NE DEĞİŞİR:**
  - MESAJ İKONU (görevin ikinci yarısı): CallScreen üst sağa mesaj balonu ikonu (bağlıyken görünür). Davranış: `minimize()+pop`; ayrıca `peerId != null` (1:1 giden) ise `POST /chats/direct` ile chatId al → `rootNavigatorKey.currentContext` üzerinden `/chat/:id` aç (router.dart mevcut rota). peerId yoksa (gelen 1:1/grup) yalnız minimize — backend'e alan eklemek bu fazda YOK (1:1 backend'ine dokunmama kuralı).
  - Aramadayken (minimize durumda) yeni arama/oda/yayın başlatma denemeleri: bugünkü `aramadaMi` muhafızları zaten engelliyor (start/startGroup StateError, rooms_tab/live muhafızları). Hata snackbar'ına "Aramaya dön" aksiyonu eklenir → `restore()`. Gelen arama: `_onEvent`'teki `if (aramadaMi) return` + backend busy AYNEN (değişiklik yok, sadece test edilir). CallKit'ten kabul: `answer()==null` + `baskaIsleMesgul` dalı AYNEN (minimize'da ekrandakiAramalar dolu olduğu için doğru çalışır — test edilir).
  - ÇIKIŞ (yeni açılan kenar durumu): minimize'dayken kullanıcı ayarlardan çıkış yapabilir hale geldi → logout akışına tek satır: `if (activeCall.arama != null) await activeCall.leave(notifyServer:true);`.
- **NEDEN:** Minimize, daha önce imkânsız olan eşzamanlılıkları (aramadayken gezinme) açtı; mevcut muhafızların bu yeni yüzeyde de doğru çalıştığı KANITLANMALI, bilinen tek boşluk (logout) kapatılmalı. Mesaj ikonu görev tanımının parçası.
- **NEYİ BOZMAMALI:** answer/end idempotent kilitleri (_cevaplanan/_bitenler), busy 409 akışı, Android data-only push yolu, oda/yayın muhafız-tekrarı desenleri — hiçbirine dokunulmuyor, yalnız çevresine test+kısayol ekleniyor.
- **DOĞRULAMA (3 cihaz):** (1) minimize'dayken 3. kişiden gelen arama → arayana "mesgul", bant bozulmaz; (2) minimize'dayken kilit ekranı CallKit kabul denemesi (iOS) → CallKit kapanır + red, canlı arama yaşar; (3) minimize'dayken oda/yayın açma → snackbar + "Aramaya dön" çalışır; (4) mesaj ikonu: 1:1 giden aramada doğru sohbet açılır, mesaj gider, banttan dönülür; (5) minimize'dayken çıkış → arama sunucuda biter (karşı taraf <=3sn'de görür); (6) TAM 1:1+grup regresyonu (Adım 2 listesi kısaltılmış). Commit+push.

## ADIM 6 — Dokümantasyon + gelecek deseni (kod değişikliği yok)
- **DOSYA:** `oturum.md`, `CLAUDE.md`
- **NE DEĞİŞİR:** oturum.md'ye yapılanlar/denenenler/kararlar + test rehberi; CLAUDE.md TUZAKLAR'a: "Aktif arama ActiveCallController'da GLOBAL — CallScreen saf görünüm; teardown 'enqueue anında yakala' deseni; ekran dispose'u aramayı BİTİRMEZ (minimize sayılır); yeni ekran-kapatan kod _leave TEK KAPISINI kullanmalı".
- **ODA/YAYIN İÇİN AYNI DESEN (şimdi UYGULANMAZ, tasarım notu):** RoomScreen (rooms/room_screen.dart) ve live_broadcast/viewer aynı iskeleti sonra alır: her biri için `AktifOdaController`/`AktifYayinController` (Room + rol-WS abonelikleri + heartbeat/poll taşınır), banner host TEK genel `AktifMedyaBanner`a genelleştirilir (öncelik: arama > oda > yayın; aynı anda tek medya oturumu kuralı zaten muhafızlarla garanti). RoomScreen'in PopScope+popUntil('oda-<id>') ve _ayrildi kilidi deseni controller'a Adım 2'deki aynı reçeteyle taşınır; yayında ek kural: yayıncı minimize edilirse kamera yayını sürer (izleyiciler görür) — bu ürün kararı kullanıcıya sorulacak.

## BİLİNEN SINIRLAR (kabul, v1)
- Bant yalnız bağlı aramada; ring fazı küçültülemez (bilinçli daraltma).
- Bantta video önizleme yok (avatar/isim/süre) — sürüklenebilir video penceresi ileriki iterasyon.
- Görüntülü aramada minimize sırasında KENDİ kameran yayında kalır (WhatsApp da böyle; istenirse "minimize'da kamerayı otomatik kapat" opsiyonu sonra sorulur).
- Uygulama içi minimize bu iş; uygulama-dışı PiP (Android picture-in-picture) kapsam DIŞI.

## SÜREÇ KURALLARI
Her adım: flutter analyze → gerçek cihaz doğrulaması → commit+push (`git rev-parse origin/main` teyidi) → oturum.md güncelle. Onay gelmeden kod yazılmaz (bu bir PLANDIR). Build/dağıtım en erken Adım 4 sonrası (dağıtım kontrol listesi + DB temizleme rutini uygulanır).

## PLAN 3 — KISI EKLEME

# ARAMAYA KİŞİ EKLEME (1:1 → grup yükseltme, sesli+görüntülü) — UYGULAMA PLANI

Kod okundu: backend/internal/calls/handler.go (Start 159, startGroup 341, Answer 478, answerGroup 708, End 560, endGroup 749, Status 941, Active 985, History 1010, sweep 75), migration 007, mobile/lib/features/calls/{call_screen, call_provider, incoming_call_overlay, callkit_service, group_call_start_screen}.dart, main.dart CallKit-kabul yolu (245-264). Mevcut grup altyapısı (call_participants + startGroup/answerGroup/endGroup fan-out) İŞİN %70'ini hazır veriyor; ekleme = "aktif aramayı grup satırına çevir + startGroup davet desenini tek kişiye uygula".

## ANA MİMARİ KARARLAR (önce bunlar netleşmeli)

**K1 — Yükseltmede `callee_id` NULL'a ÇEKİLİR + `is_group=true`.** Etki analizi TEK TEK (kod satırlarıyla):
- `Start` pairwise zombi temizliği (handler.go 222-228): EN TEHLİKELİ NOKTA. A↔B yükseltilmiş grup aramasında konuşurken A çıkıp B'yi 1:1 ararsa, `callee_id=B` DOLU kalsaydı bu UPDATE canlı GRUP aramasını 'ended' yapardı (herkesin poll'u 'ended' görür, tüm ekranlar kapanır). callee_id=NULL → koşul eşleşmez → grup araması korunur. Ek kemer: bu UPDATE'e `AND is_group=false` da eklenecek (K4).
- `Start` busy kontrolü (234-239): callee_id NULL olunca B'nin meşgullüğü calls satırından görünmez OLURDU — ama B artık call_participants'ta 'joined'; busy sorgusuna participants eki YAPILMAYACAK (canlı 1:1 yoluna dokunmama kuralı; startGroup'la başlayan gruplarda da aynı boşluk zaten var, bilinen sınır). Meşgul kontrolü yalnız YENİ /add ucunda participants dahil yapılır (K3).
- `Answer`/`End` (484, 567): is_group=true olunca answerGroup/endGroup'a dallanır — caller+callee için 'joined' satırları yükseltmede yazılacağı için ikisi de çalışır. 1:1 dalları HİÇ değişmez.
- `Status` (950-977): yetki zaten `OR id IN (SELECT call_id FROM call_participants ...)` içeriyor → NULL sorun değil. Grup dalı caller/callee'nin 'joined' satırını görüp 'active' döndürür (doğru). elapsed_ms: answered_at dolu kalır ama grup modundaki istemci YOK SAYAR (aşağıda).
- `History` (1019 `is_group=false` filtresi) + `AdminCalls` (1324 INNER JOIN callee): yükseltilen arama iki listeden de düşer — startGroup aramalarıyla AYNI davranış (tutarlı; grup geçmişi ayrı faz). Kullanıcıya not edilecek bilinen sınır.
- `Active` (992 `callee_id=$1 AND status='ringing'`): yükseltilmiş arama 'active' olduğu için zaten eşleşmezdi; davetli checkActive'de grup davetini GÖRMEZ — startGroup'ta da aynı boşluk (VoIP/FCM/WS kapatıyor). Opsiyonel iyileştirme Adım 2c.
- `sweep` (78-81): yalnız `status='ringing'` calls satırlarını tarar; yükseltilmiş arama 'active' → dokunmaz. Scan'e NULL callee gelmez (grup hiç 'ringing' olmaz).
- `logMissedToChat`: yalnız 1:1 missed yolunda → yükseltilmiş aramada hiç çağrılmaz.

**K2 — `call_participants.invited_at` kolonu ŞART (migration 010).** endGroup'un "taze davet" kontrolü (767: `c.created_at > now()-45s`) startGroup'ta doğru (davetler aramayla aynı anda), ama EKLEMEDE davet DAKİKALAR sonra gelir → c.created_at eski → ringingFresh HEP 0 → yükseltilmiş 2 kişilik aramada biri çıkarsa davetli daha çalarken arama ANINDA 'ended' olur (davet ölür). Fix: `p.invited_at > now()-45s`.

**K3 — Sınırlar /add içinde:** toplam (ringing+joined) ≤ 32; hedef meşgulse 409 (calls caller/callee ringing-taze/active-2h VEYA call_participants joined/ringing-taze, bu aramanın kendisi hariç); ekleyen↔hedef çift yönlü blocks → 403; hedef verified=true; hedef zaten 'joined' → 409 "zaten aramada"; 'ringing' → upsert invited_at=now() + davet TEKRAR (WhatsApp yeniden çaldırma); 'left/rejected/missed' → yeniden 'ringing' (tekrar davet).

**K4 — Süre senkronu (CLAUDE.md tuzağı, 3 kez elden geçti — REGRESYON YASAK):** Yükseltmede A/B'nin sayacına DOKUNULMAZ. `_sureReferansiAl` muhafızı `widget.isGroup` → `_isGroup` olur; referans zaten kilitli (`_sureReferansVar=true`) olduğundan çifte korumalı. Stopwatch RESET/STOP edilmez, `_sureBaz` değişmez. Davetli C grup yolundan girer (answerGroup elapsed_ms DÖNDÜRMEZ) → yerel sayaç 00:00'dan (mevcut grup davranışı). A/B ile C'nin süreleri farklı görünür — WhatsApp'ta da böyle, DOĞRU davranış.

---

## ADIM 0 — Migration 010
- **DOSYA:** `backend/internal/database/migrations/010_call_invite.sql` (yeni)
- **NE DEĞİŞİR:**
```sql
ALTER TABLE call_participants ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE call_participants p SET invited_at = c.created_at FROM calls c WHERE c.id = p.call_id; -- uçuştaki satırlar için geri doldur
```
- **NEDEN:** K2. Additive, mevcut sorgular etkilenmez.
- **BOZMAMALI:** 007'deki CHECK/PK aynen; startGroup INSERT'leri DEFAULT now() ile otomatik doğru değer alır (kod değişikliği gerekmez).
- **DOĞRULAMA:** sunucuda `\d call_participants`; ardından startGroup curl regresyonu (T1 aşağıda).

## ADIM 1 — Backend: POST /calls/{id}/add
- **DOSYA:** `backend/internal/calls/handler.go` (yeni `Add` handler, startGroup'un hemen altına) + `backend/cmd/api/main.go` (162. satır civarı: `r.Post("/calls/{id}/add", callsH.Add)`)
- **NE DEĞİŞİR (akış):**
  1. Gövde `{user_id}` (tek kişi; istemci çoklu seçimde art arda çağırır — her POST bağımsız, kısmi başarı doğal).
  2. TX aç, kilitle: `SELECT caller_id, callee_id, type, COALESCE(is_group,false), chat_id FROM calls WHERE id=$1 AND status='active' AND (caller_id=$u OR callee_id=$u OR EXISTS(SELECT 1 FROM call_participants WHERE call_id=$1 AND user_id=$u AND status='joined')) FOR UPDATE` → yoksa 404 "arama bulunamadı veya bitti" (ringing 1:1'de ekleme YOK — WhatsApp da bağlanmadan izin vermez; istemci butonu zaten `_baglandi` iken gösterir). FOR UPDATE = iki katılımcının eş zamanlı add'i serileşir (çifte yükseltme yarışı biter).
  3. K3 kontrolleri (self-add 400, verified, blocks 403, hedef bu aramada joined → 409, meşgul → 409 "Kullanıcı şu anda başka bir görüşmede", kapasite: `count(status IN ('ringing','joined'))`; is_group=false ise taban 2 say; +1 > 32 → 400 "grup araması en fazla 32 kişi olabilir").
  4. **1:1 ise YÜKSELT:** `UPDATE calls SET is_group=true, callee_id=NULL WHERE id=$1 AND is_group=false AND status='active'` + `INSERT INTO call_participants (call_id,user_id,status,joined_at) VALUES ($1,caller,'joined',now()),($1,callee,'joined',now()) ON CONFLICT DO NOTHING`.
  5. Davetli upsert: `INSERT ... (call_id,$hedef,'ringing') ON CONFLICT (call_id,user_id) DO UPDATE SET status='ringing', invited_at=now() WHERE call_participants.status <> 'joined'`.
  6. COMMIT. Sonra fan-out (TX DIŞI, startGroup 437-468 deseni AYNEN):
     - Eski katılımcılara (groupJoinedOthers, davet eden hariç) YENİ WS olayı `call.upgraded` payload `{call_id, is_group:true, chat_title, added_by, added_name, participant_count}` — B'nin ekranı grup moduna geçsin diye (1:1→grup'ta kritik; zaten-grupta da gönder, istemci idempotent).
     - Davetliye: WS `call.incoming` (is_group:true, chat_title, caller_id/name/avatar = EKLEYENİN bilgisi, participant_count) + iOS VoIP `CallInvite` (caller_name=chatTitle — CallKit grup başlığı, startGroup 458-462 birebir) + Android FCM data (yalnız offline, 465-467 birebir). chat_title: calls.chat_id doluysa chats.title, değilse "Grup araması" (anlık grupla tutarlı).
  7. Cevap 200: `{status:"invited", call_id, is_group:true, participant_count}` (ekleyen token ALMAZ — zaten odada).
- **NEDEN:** startGroup deseninin kanıtlanmış fan-out'u; TX + FOR UPDATE yarışları kapatır; aynı LiveKit odası (`call_<id>`) kullanıldığı için A/B'nin bağlantısına DOKUNULMAZ (token/oda değişmez — yükseltmenin sıfır-kesinti sırrı).
- **BOZMAMALI:** Start/Answer/End 1:1 dallarına dokunulmuyor; startGroup/answerGroup/endGroup gövdesi değişmiyor (yalnız Adım 2'deki nokta düzeltmeler). Bilinen kabul edilen yarış: yükseltme commit'i ile B'nin End'i milisaniye aralığında çakışırsa B'nin End'i 1:1 yolundan tüm aramayı bitirebilir (2 kişilik aramada zaten B kapatıyordu — semantik kabul; belgele).
- **DOĞRULAMA:** `go build ./...` + curl C1-C6 (aşağıda).

## ADIM 2 — Backend nokta düzeltmeleri (3 küçük + 1 opsiyonel)
- **DOSYA:** `handler.go`
- **NE DEĞİŞİR / NEDEN:**
  - (a) `endGroup` 767: `p.status='ringing' AND c.created_at > ...` → `p.invited_at > now() - interval '45 seconds'` — K2 (yükseltilmiş aramada taze davet ölmesin). startGroup için davranış AYNI (invited_at=created_at anı).
  - (b) `Status` 978: cevaba `"is_group": isGroup` alanı ekle — B'nin WS `call.upgraded`'i kaybolursa 3sn'lik aktif poll'dan kurtarma (istemci Adım 4). Additive; eski istemci yok sayar.
  - (c) `Start` pairwise temizliği 222-228: WHERE'e `AND COALESCE(is_group,false)=false` — K1 kemer-pantolon askısı (callee_id NULL zaten korur; ileride biri callee_id'yi doldurursa da grup aramaları zombilenmez).
  - (d) OPSİYONEL (önerilir, ayrı commit): `Active` 985'e ikinci sorgu — 1:1 sonuç yoksa `call_participants p JOIN calls c: p.user_id=$1 AND p.status='ringing' AND p.invited_at > now()-45s AND c.status='active'` → grup davet alanlarıyla dön (`is_group`, `chat_title`, ekleyen adı). Davetli ön plana dönünce grup davetini de görür (startGroup'un da eski boşluğu kapanır). Android checkActive yolu IncomingCall.fromJson'ı zaten is_group okuyor (call_provider 37) → istemci değişikliği GEREKMEZ.
- **BOZMAMALI:** (a)-(c) mevcut curl regresyonlarını (grup-video-test.sh, oda-test.sh 1:1 kontrolü) yeşil tutmalı — özellikle T1 "biri ayrıl arama sürer" senaryosu.

## ADIM 3 — İstemci: call_provider.dart
- **DOSYA:** `mobile/lib/features/calls/call_provider.dart`
- **NE DEĞİŞİR:**
  - `_onEvent` switch'e (131 civarı) `case 'call.upgraded':` → `_participantController.add({'event':'call.upgraded', ...p})` (mevcut onParticipant akımı yeniden kullanılır; yeni controller açma — dispose listesi büyümesin).
  - Yeni metot: `Future<Map<String,dynamic>> addToCall(String callId, String userId)` → `POST /calls/$callId/add {user_id}`.
- **NEDEN:** CallScreen'in dinleyeceği tek olay kapısı zaten var; bilinmeyen tip eski istemcide güvenle yok sayılır (WS geriye uyum kuralı).
- **BOZMAMALI:** `call.incoming/answered/ended` case'leri ve muhafız setleri (ekrandakiAramalar/aktifKonusmalar/kabulEdilenler) AYNEN.

## ADIM 4 — İstemci: call_screen.dart `widget.isGroup` → `_isGroup` state
- **DOSYA:** `mobile/lib/features/calls/call_screen.dart`
- **NE DEĞİŞİR:** `late bool _isGroup;` — initState başında `_isGroup = widget.isGroup;`. 10 okuma noktası tek tek `_isGroup`'a çevrilir, HER BİRİNİN yükseltme etkisi:
  - 166 (grup hostu doğrudan _connect): initState'te koşulur, yükseltmeden ÖNCE — davranış değişmez (o an _isGroup=widget.isGroup).
  - 379/381 (RoomOptions grup profili): oda YÜKSELTMEDEN ÖNCE 1:1 720p profiliyle kurulmuş — yükseltmede yeniden yayına GEÇİLMEZ (`restartTrack` encoding hesaplamaz — CLAUDE.md tuzağı; BWE+simulcast+adaptiveStream zaten katman düşürür). Bilinen sınır olarak belgele: yükseltilmiş görüntülü grupta ekleyen/eski callee 720p yayınlar.
  - 405 (**ParticipantDisconnected — EN KRİTİK**): `_isGroup` true olunca "biri ayrılınca arama sürer" dalına geçer; salt-1:1'de otomatik `_leave` AYNEN kalır. B bu bayrağı `call.upgraded` (WS) veya Status `is_group` (≤3sn poll) ile alır — iki kanal da düşerse eski davranışa düşer (bozulma değil, mevcut 1:1 semantiği).
  - 454 (ActiveSpeakers setState): grup görünümüne geçen ekranda yeşil halka çalışır.
  - 618 (`_sureReferansiAl` muhafızı): K4 — yükseltme sonrası yeni referans kilitlenemez; MEVCUT Stopwatch/baz sürer, sıfırlama YOK. `_durumKontrol` 209'daki çağrı zaten bu muhafıza çarpar.
  - 836 (_toggleCam 32 muhafızı): yükseltilmiş grupta da çalışır.
  - 964/986/998 (grid / self-view kapatma / başlık): `setState(_isGroup=true)` tek başına ekranı grup izgarasına çevirir, self-view overlay'i kaldırır (yerel görüntü kendi tile'ında), başlık "Grup araması" olur (widget.chatTitle '' → varsayılan metin). VideoTrackRenderer dokunma yasağı korunur (tile'lar zaten IgnorePointer'lı).
  - YENİ dinleyici: initState'te `_partSub = _svc.onParticipant.listen(...)` — `event=='call.upgraded' && call_id==widget.callId` → `if (mounted && !_isGroup) setState(() => _isGroup = true);` (idempotent; participant.joined/left'te yalnız setState — izgara tazeleme, zararsız). dispose'ta `_partSub?.cancel()` — **ref-in-dispose dersi:** yalnız `_svc` cache'i kullanılıyor, ref YOK.
  - `_durumKontrol`'e: `if (st['is_group'] == true && !_isGroup && mounted) setState(() => _isGroup = true);` (kurtarma kanalı).
  - **CallKit başlığı etkileri (tam liste):** (1) Ekleyen A: giden arama, CallKit hiç yok — etkisiz. (2) Eski callee B iOS'ta CallKit'le kabul ettiyse: sistem arama şeridi ESKİ 1:1 ismi göstermeye devam eder (flutter_callkit_incoming'de güvenilir güncelleme API'si yok — KABUL EDİLEN SINIR, uygulama içi başlık grup olur; `bitir()`/aramaBitti yolları callId bazlı, isimden bağımsız → bozulma yok). (3) Davetli C: VoIP/FCM payload'ında caller_name=chatTitle → CallKit "Grup araması" başlığı (mevcut grup yolu, değişiklik yok). (4) `islenenler`/`_bizBitirdik` setleri callId bazlı — yükseltme callId'yi DEĞİŞTİRMEDİĞİ için tüm CallKit muhafızları aynen çalışır.
- **BOZMAMALI:** iOS ses sırası (mic → speaker → `_sesiAc` EN SON) — bu adım ses koduna HİÇ dokunmuyor; `_statusText` kapısı değişmiyor; `_leave`/CallRoomLock/teardown değişmiyor (Adım 5'teki sheet-pop istisnası hariç); `_mediaBasladi`/`_peerJoined` mantığı aynen.
- **DOĞRULAMA:** `flutter analyze` temiz + 1:1 regresyon (arama aç/kapa, süre senkron, self-view swap/sürükle).

## ADIM 5 — İstemci: "Kişi ekle" butonu + seçim sheet'i
- **DOSYA:** `call_screen.dart` (buton) + yeni `mobile/lib/features/calls/add_participant_sheet.dart`
- **NE DEĞİŞİR:**
  - Buton: alt kontrol çubuğuna DOKUNMA (5 buton + kırmızı zaten dar ekranda sınırda) — sağ üste `Positioned(top: 48, right: 16)` kişi-ekle ikonu (LucideIcons.userPlus). Görünürlük: `_baglandi && !_cevapsiz && _error == null` (1:1 VE grup; ringing fazında gizli — backend de 'active' şartı koyuyor, tutarlı).
  - Sheet (GroupCallStartScreen 35-67 arama deseni birebir): debounce'lu `/users/search`, sonuç listesi; MEVCUT katılımcılar elenir (LiveKit identity == userID → `_room.remoteParticipants.keys` + kendi id'si ile filtre). Kişiye dokun → `svc.addToCall(callId, id)` → başarıda snackbar "{ad} aranıyor", `if (!_isGroup) setState(_isGroup = true)`, sheet açık kalır (WhatsApp gibi art arda eklenebilir); hatada `apiErrorMessage` snackbar (409 meşgul / 400 kapasite Türkçe mesajları backend'den gelir).
  - **Sheet-açıkken-arama-biterse tuzağı (Spaces B1 dersi):** `_leave`'deki tek `nav.pop()` sheet'i kapatır, ÖLÜ CallScreen kalır. Fix: `bool _sheetAcik=false;` — sheet `await showModalBottomSheet(...)` öncesi true, dönüşte false; `_leave` içinde pop'tan önce `if (_sheetAcik && nav.canPop()) nav.pop();` (iki pop da canPop korumalı). `_leave`'e başka DOKUNUŞ YOK.
- **NEDEN:** kontrol çubuğunun kırılgan düzenini ve `_buildAramaKontroller`'ı değiştirmeden WhatsApp "kişi ekle" akışı.
- **BOZMAMALI:** sheet bir arama BAŞLATMAZ → mesgul muhafızı (aramadaMi) tetiklenmez; CallSounds'a dokunulmaz (ekleyen ringback DUYMAZ — zaten canlı konuşmada).

## ADIM 6 — Davetlinin telefonu (mevcut grup yolu — DOĞRULANDI, kod değişikliği YOK)
- WS `call.incoming` is_group:true → Android ön planda overlay: başlık chatTitle, alt satır "Grup sesli/görüntülü araması · {ekleyen}" (incoming_call_overlay 155-165 hazır); overlay poll'u grup dalında 'active' görünce KAPANMAZ (69 hazır). iOS'ta WS daveti bastırılır, VoIP→CallKit (mevcut kural).
- Kabul → `answer()` → is_group=true → `answerGroup`: participant satırı VAR (add yazdı), `status='active'` → token döner; overlay 111 ve main.dart 260 `is_group/chat_title`'ı CallScreen'e geçirir → grup modu. `call.participant.joined` eski katılımcılara gider (A+B'nin joined satırları sayesinde) → izgara LiveKit ParticipantConnected ile de tazelenir.
- Red/cevapsız → `end` → `endGroup` 'left'; 45sn sonra invited_at tazeliği düşer → 2 kişi kalmışsa arama sürer (joined=2), tek kişiyse biter (doğru).

## RİSKLER (özet)
1. **Süre senkron regresyonu** — en yüksek risk; K4 kuralları: Stopwatch'a/_sureBaz'a yükseltmede dokunma, muhafız `_isGroup`. Doğrulama: yükseltme anında A ve B'nin sayacı ZIPLAMAMALI.
2. **B'nin geçiş bilgisini alamaması** → 1:1 modunda kalır, C'nin her ayrılışında B'nin ekranı kapanır. Çift kanal (WS + 3sn Status poll) ile pencere ≤3sn; kabul edilen kalıntı risk.
3. **Yükseltme ↔ End yarışı** (Adım 1 notu) — milisaniyelik, semantik kabul.
4. **Pairwise temizlik zombisi** — K1+2c ile kapatıldı; curl C7 ile kanıtlanmalı.
5. **invited_at unutulursa** davet 45sn kuralına takılıp yükseltilmiş aramayı öldürür — Adım 0+2a birlikte gitmeli (aynı commit).
6. **720p yayın yükü** yükseltilmiş kalabalık görüntülü grupta — kabul (BWE/adaptiveStream), restartTrack DENENMEZ.
7. **CallKit başlığı B'de eski isim** — kabul edilen sınır (Adım 4).
8. Eski sürüm istemci karışımı — her yayında DB temizlendiği için pratik risk düşük; `call.upgraded` bilinmeyen tip olarak güvenle yutulur.

## CURL DOĞRULAMA LİSTESİ (canlıda, 3+ test kullanıcısı: A, B, C, D; scratchpad/kisi-ekle-test.sh)
- **C1 mutlu yol:** A→B 1:1 start + B answer (elapsed_ms~0) → A `POST /calls/{id}/add {user_id:C}` → 200; DB: `calls.is_group=true, callee_id NULL`; `call_participants`: A,B 'joined' + C 'ringing' (invited_at taze) → C `POST answer` → token + is_group:true; `call.participant.joined` yayını.
- **C2 grup içinde ekleme:** startGroup(A;B,C) → herkes joined → A add D → 200, D 'ringing' + davet; is_group zaten true, calls satırı değişmez.
- **C3 sınırlar:** kendini ekle 400 · engelli 403 · verified olmayan 400 · zaten joined 409 · 32. üzeri 400 · hedef başka aramada (D'yi ayrı 1:1'e sok) 409 meşgul.
- **C4 yetki:** aramada olmayan X add çağırır → 404; 'ringing' 1:1'de add → 404 (status='active' şartı).
- **C5 davet yaşam döngüsü:** C answer etmeden A end → endGroup: B+C'ye doğru olaylar; C 'ringing' TAZEYKEN arama SÜRMELİ (joined=1+fresh — invited_at fix kanıtı); 45sn sonra tek kişi → 'ended'.
- **C6 tekrar davet:** C reddetti ('left') → A tekrar add → 200, yeniden 'ringing' + yeni push.
- **C7 zombi regresyonu (K1 kanıtı):** A↔B yükseltilmiş grup aktifken A çıkar, A→B YENİ 1:1 start → grup araması 'active' KALMALI (pairwise temizlik dokunmamalı), B busy=409 dönmeli (B hâlâ grupta... değilse davranışı logla).
- **C8 1:1 TAM regresyon:** grup-video-test.sh T1-T4 yeniden yeşil (start/answer elapsed_ms/end/busy/History is_group=false).
- **Cihaz testi (3 telefon):** 1:1 konuşurken A "kişi ekle" → C'de CallKit/overlay GRUP başlığıyla çalar → C katılır → A/B ekranı izgara moduna geçmiş, SÜRE ZIPLAMAMIŞ → C çıkar → A/B araması SÜRER → B çıkar → herkes kapanır. iOS host + Android host iki yönde; kilit ekranı CallKit dahil. `docker logs livekit | grep call_<id>` (önce oda logu kuralı) + admin Ses Teşhis SES-VAR.

**Sıra:** Adım 0+1+2 (tek backend paketi, go build + C1-C8) → deploy → Adım 3+4+5 (flutter analyze + cihaz) → her adımda commit+push+`git rev-parse origin/main` → oturum.md güncelle → yayın rutini (build, R2, purge, boyut, DB temizle).