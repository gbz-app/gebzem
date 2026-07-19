# Gebzem Projesi — Claude Kuralları

WhatsApp + Twitter Spaces + TikTok Live karışımı sosyal uygulama. Hedef: ~50K kullanıcı, Türkiye pazarı. Domain: gebzem.app

## ZORUNLU KURALLAR (kullanıcı emri)
1. **Her oturumda `oturum.md` güncellenir** — yapılanlar, denenenler (oldu/olmadı), kararlar, devir notları. Oturum başında OKU, her önemli adımdan sonra GÜNCELLE (sadece oturum sonunda değil!).
2. **Bu dosya (CLAUDE.md) da güncel tutulur** — proje durumu/komutlar/uçlar değiştikçe.
3. **Her adımda git push** — her anlamlı değişiklik commit + push edilir; başarı `git rev-parse origin/main` karşılaştırmasıyla doğrulanır.
4. **Onaysız işlem yok** — kullanıcı "yap" demeden kurulum/silme/deploy yapma. Önce öner, onay gelince uygula.
5. **Kısa yaz** — uzun tablolar yok; net cevap + gereken aksiyon.
6. **`.env.infra` ve `backend/.env` ASLA git'e girmez** (.gitignore'da — değiştirme!)
7. Türkçe konuş.
8. **"Devam eden iş" izlenebilirliği (18 Tem):** aktif iş sürerken oturum.md'deki adım listesi
   ([ ]→[x]) HER ADIMDAN SONRA güncellenip push'lanır; aşağıdaki ŞU AN DEVAM EDEN İŞ bloğu da
   senkron tutulur. Amaç: pencere kapansa bile tam kalınan yerden devam edilebilmesi.

## ŞU AN DEVAM EDEN İŞ (canlı — her adımda güncelle, iş bitince "YOK" yaz)
- **İş: SPACES (SESLİ ODA) — kullanıcı onaylı sıra (18 Tem gece):**
- YOK — **SPACES (sesli oda) YAYINLANDI** (18 Tem gece, a06a2d5): backend canlı, doğrulama
  20 bulgu düzeltildi (2 blocker dahil), build+R2+purge+DB temiz. **Kullanıcı dışarıda oda
  testi yapacak** (rehber: oturum.md "SPACES SURUMU YAYINLANDI"). Sonra sırayla: kapsamlı
  test → CANLI YAYIN (plan hazır: oda-yayin-plani.md Bölüm 2) → arayüz → güvenlik denetimi.
- Spaces özet: /rooms uçları (11), rol=DB, dinleyici publish yok, el kaldırma REST, sweep
  (LiveKit ListRooms kontrolü dahil), LiveKit pin v1.13.3, internal/livekit ortak twirp paketi.
- Grup görüntülü fazı 18 Tem akşam YAYINLANDI (oturum.md "Oturum 16": adımlar, test rehberi,
  bilinen sınırlar). Sonraki adaylar: test bulguları → geç-katılma/kişi-ekleme → kalıcı grup
  sohbeti → Spaces (yol haritası).
- Kritik bağlam: backend startGroup videoyu zaten destekliyordu; eklenenler = kapasite sınırı
  (video≤8/sesli≤32), grup düşük video profili (540p), grid video tile, başlatma ekranı seçimi,
  grup kamera butonu, overlay metni. 1:1 ve SESLİ grup davranışı DEĞİŞMEDİ (isGroup dalları +
  "video track yoksa eski avatar ızgara birebir").

## TELEMETRİ & İZLEME (12 Tem 2026 — hepsi canlı)
- **Sentry:** https://gebzem.sentry.io — gebzem-mobile + gebzem-backend projeleri; hatalar dosya+satır ile otomatik düşer. OTURUM BAŞINDA KONTROL ET. sentry_flutter ^9.6 (8.x KULLANMA — Kotlin/Swift derleme hatası)
- **Paneller (Caddy basic auth: gebzem/cKIZMzFJCyNERn):** nabiz.gebzem.app (Netdata), log.gebzem.app (Dozzle) · bekci.gebzem.app (Uptime Kuma: gebzem/Gebzem2026!, 4 monitor)
- **Admin panel:** https://api.gebzem.app/admin/izle (giriş: **admin / Gebzem2026!** — env ADMIN_USER/ADMIN_PASS override; login gövdesi `{"user","pass"}` alanları!). **ADMIN_KEY artık güçlü** (19 Tem, sunucu .env + .env.infra'da; eski `gbz-izle-2026` GEÇERSİZ) — kullanıcılar, aramalar + **canlı Ses Teşhis sekmesi** (audio-stat renk kodlu, 2sn yenilenir: 🟢SES-VAR 🔴iOS-CIKIS-YOK 🟠SES-GELMIYOR 🟣TRACK-YOK 🟡SES-DUSUK). Veri: bellek ring buffer (son 120) + docker log. GEÇİCİ teşhis — üretim öncesi kaldır.
- **Nöbetçi:** sunucuda dakikalık cron (backend/watchdog.sh) — API 2 kez sağlıksızsa otomatik restart, disk ≥%90 docker prune. Log: /var/log/gebzem-watchdog.log
- **API HTTPS:** https://api.gebzem.app (Cloudflare flexible SSL → Caddy:80 → api:8080). Caddyfile değişince `docker compose -f monitoring-compose.yml restart caddy` ŞART
- **Cloudflare Global API Key** .env.infra'da (CF_GLOBAL_KEY; legacy header: X-Auth-Email + X-Auth-Key — Bearer ÇALIŞMAZ). DNS tam kontrolde
- **ufw:** sadece 22/80/8080 açık
- **KURAL: Codemagic build tetikledikten sonra ANLIK izle** (arka plan poll scripti), patlarsa subactions[].logUrl'den logu çek, düzelt
- Kullanıcı anahtarları sohbete YAZMAZ → gbz-a3/token.txt'ye koyar, oradan oku (güvenlik filtresi tetiklenmesin)

## DAĞITIM KONTROL LİSTESİ (her yeni sürümde ZORUNLU — kullanıcı boşuna eski sürüm kurdu)
1. Build bitti mi + artifact var mı (status=finished ve .apk/.ipa mevcut)
2. APK debug imzayla mı derlendi? (logda "Signing with debug keys" OLMAMALI — SMS/Firebase çalışmaz)
3. R2'ye yükle (scratchpad/r2put.js — Cache-Control: no-cache gönderiyor)
4. **Cloudflare zone purge ŞART** (Global API Key ile) — yoksa CDN eski dosyayı servis eder
5. **Yayın sonrası doğrula:** sunucudaki Content-Length == yerel dosya boyutu; /health = ok
6. Ancak bundan sonra kullanıcıya "hazır" de

## CI/CD: GITHUB ACTIONS (Codemagic ücretsiz dakikaları bitti — 12 Tem 2026)
- Workflow'lar: `.github/workflows/android.yml`, `ios.yml` (workflow_dispatch ile tetiklenir)
- Tetikle: `gh workflow run android.yml --repo gbz-app/gebzem` · Takip: `gh run list/view --log-failed`
- Artifact indir: `gh run download <id> --repo gbz-app/gebzem --dir <klasor>`
- ⚠️⚠️ **SECRET KURALI:** `gh secret set NAME --body "deger"` KULLAN. **PowerShell borusu (`$x | gh secret set`) secret'ları BOZUYOR** (base64 invalid / keystore tampered / Apple 401). Çok satırlı anahtarlar (p8, pem) → **base64'le, workflow'da çöz**
- Kota: özel repoda 2000 dk/ay, **iOS 10x sayılır** (~12 iOS build/ay). Repo public yapılırsa sınırsız bedava

## RUTİN: HER YENİ SÜRÜMDE
1. Build (GitHub Actions) → artifact indir → içerik doğrula
2. R2'ye yükle → **Cloudflare purge** → sunucudaki boyut = yerel boyut kontrolü
3. **Veritabanını temizle:** `TRUNCATE users CASCADE; TRUNCATE otp_codes;` (kullanıcı isteği — her sürümde temiz başlangıç)
4. Ancak sonra "hazır" de

## ARAMA SİSTEMİ (LiveKit — kendi sunucumuzda)
- LiveKit v1.13.3: `backend/livekit-compose.yml` + `livekit.yaml` (host network, TURN açık)
- Adresler: **wss://rtc.gebzem.app** (sinyal, Caddy üzerinden) · **turn.gebzem.app: TLS 443 + UDP 3478** (DNS proxy KAPALI olmalı!)
- ⚠️ **TURN TLS ŞART** (mobil operatör NAT'ı): Let's Encrypt sertifikası /opt/gebzem/letsencrypt (certbot+dns-cloudflare, Global Key ile). `external_tls: false` + cert_file/key_file. TLS'siz TURN = `dtls timeout`, ses gitmez!
- Sertifika yenileme (90 günde bir): `docker run --rm -v /opt/gebzem/letsencrypt:/etc/letsencrypt -v /opt/gebzem/cf:/cf certbot/dns-cloudflare renew` + livekit restart
- Portlar (ufw): 7880, 7881, 443, 3478/udp, 50000-50200/udp, 30000-40000/udp
- Teşhis: `node scratchpad/stuntest.js` (UDP/TCP erişim testi) · LiveKit logunda `dtls timeout` = medya geçmiyor, `"network":"cellular"` = operatör NAT'ı
- Backend: `internal/calls` — /calls (başlat), /calls/{id}/answer, /calls/{id}/end, GET /calls (geçmiş); WS: call.incoming/answered/ended
- Env: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET (sunucu .env'inde)
- Flutter: livekit_client + permission_handler; adaptiveStream/dynacast/simulcast açık (zayıf bağlantı + otomatik yeniden bağlanma)

## KRİTİK TUZAKLAR (tekrar yaşamayalım)
- **CallKit/VoIP push (iOS):** FCM VoIP push GÖNDEREMEZ → Go'dan doğrudan APNs (`app.gebzem.voip`).
  VoIP push gelince CallKit'e KOŞULSUZ `reportNewIncomingCall` (iOS 13+ kuralı: bildirmezsen Apple
  uygulamayı öldürür + VoIP push'ları keser). Android: `notification` DEĞİL **data-only** push +
  `@pragma('vm:entry-point')` (yoksa release'de tree-shake). Test: simülatörde CallKit ÇALIŞMAZ, gerçek cihaz şart.
- **1080p video:** H264 KULLANMA (SDK level 3.1 = 720p tavanı). VP8 + simulcast + `degradationPreference: balanced`
  (varsayılan `maintainResolution` → ağ kötüleşince fps çakılır). `restartTrack()` sender encoding'i
  yeniden HESAPLAMAZ → arama ortasında çözünürlük yükseltme temiz çalışmaz, BWE'ye bırak.
- **ARAMA HATASI ARARKEN ÖNCE ODA LOGUNU OKU** (12 Tem'de 3 saat kaybettim):
  `docker logs livekit | grep call_<id>` → `participant active` + `mediaTrack published`
  varsa **WebRTC/TURN ÇALIŞIYOR**, hatayı istemci mantığında ara.
  `dtls timeout` uyarılarının çoğu **kendi test scriptlerimin** odalarından gelir
  (`medyatest`, `icecheck`, `turntest`) — sinyale bağlanıp WebRTC yapmayan istemciler
  bunu üretir. **Oda/katılımcı adını filtrelemeden log okuma.**
- **iOS SES BİRİMİ (19 Tem, grup-host sessiz-mic dersi):** iOS'ta CallKit'siz bağlanan HER yol
  (grup hostu, giden arama) için ses birimi start'ı ÖNCESİ oturum aktivasyonu ŞART —
  AppDelegate setAudioEnabled(true) artık `setConfiguration(webRTC(), active:true)` yapıyor
  (CallKit'li yolda no-op). Bu satırı SİLME. Grup hostu ringback ÇALMAZ (kabulEdilenler
  kısayolu `|| widget.isGroup`) — geri getirme. Yeni CallKit'siz ses yolu eklerken (oda/yayın
  deseni) aynı sıra: bağlan → mic → hoparlör → setAudioEnabled EN SON.
- **ARAMA SÜRE SENKRONU (18 Tem, 3. kez elden geçti — REGRESYON YAPMA):** İki cihaz sayacı
  **monotonik `Stopwatch`** ile sayar (`_sureBaz + _sureSayaci.elapsed`), ASLA `DateTime.now()` ile
  sunucu zamanı karşılaştırmasıyla değil (saat kayması = yanlış başlangıç). Backend `answer()`/WS
  `call.answered` → `elapsed_ms` (~0); Status → `answered_at NULL iken -1` (**created_at'e DÜŞÜRME**
  → arayan zil fazında sahte referans kilitler, sayaç şişer!). İstemci referansı **yalnız `s=='active'`
  iken** alır. Push süre TAŞIMAZ (zamanlama güvenilmez). Grup HARİÇ (`!widget.isGroup`) → yerel sayaç.
- **AKTİF ARAMA = ActiveCallController (GLOBAL, Faz-C):** Room+timer+süre+ses birimi+muhafızlar
  `active_call_controller.dart`'ta; CallScreen SAF GÖRÜNÜM. **Ekran dispose'u aramayı BİTİRMEZ**
  (minimize sayılır — `ekranBeklenmedikKapandi`). Aramayı yalnız `leave` TEK KAPISI bitirir;
  yeni ekran-kapatan kod da leave'i kullanmalı. Teardown "ENQUEUE ANINDA YAKALA": kuyruğa koyarken
  room/listener/nesil senkron yakalanır (tek controller'da alanlar yeni aramada resetlenir —
  bekleyen eski teardown yeni Room'u öldürmesin). Minimize bitiş DEĞİL: muhafızlar dolu, timer'lar
  akar, CallKit aktif. Bant `AktifAramaBanner` (builder içinde — Navigator.of YASAK, root key'ler).
- **Riverpod + overlay:** Bir widget'ı gösteren state'i, o widget'ın `async` işleminin
  ORTASINDA sıfırlama → widget dispose olur, sonraki `if (!mounted) return;` sessizce
  devreye girer ve **sonraki satır (Navigator.push) hiç çalışmaz**. Önce ekranı aç, sonra state'i temizle.
- **`MaterialApp.builder` içindeki widget Navigator'ın DIŞINDADIR** → `Navigator.of(context)`
  çalışmaz. `rootNavigatorKey` (GoRouter navigatorKey) + `scaffoldMessengerKey` kullan.
- **Firebase SMS bölge politikası:** yeni projelerde `smsRegionConfig = allowlistOnly{}` (BOŞ = tüm ülkeler engelli!) → `{"allowlistOnly":{"allowedRegions":["TR"]}}` PATCH et
- Firebase Flutter paketleri: **core ≥4, auth ≥6, messaging ≥16** (eski sürümler iOS'ta EXC_BREAKPOINT ile çöküyor); iOS deployment target ≥ **15.0**
- **PowerShell ile Dart/emoji içeren dosyalarda toplu regex replace YAPMA** — `Get-Content -Raw` UTF-8'i bozar, Türkçe karakterler/emoji mahvolur. Edit tool kullan.
- pbxproj'a yazarken `[System.IO.File]::WriteAllText` (BOM'suz) — `Set-Content -Encoding utf8` BOM ekler, Xcode imzalama patlar
- AGP 9 Kotlin DSL: `java.util.Properties()` inline ÇALIŞMAZ → dosya başına `import java.util.Properties`
- sentry_flutter 8.x → Android Kotlin + iOS Swift derleme hatası; **9.x kullan**
- Codemagic: private repo klonu **SSH deploy key** ile (token'lı HTTPS URL kabul edilmiyor); çok satırlı secure var'larda `\r` temizle
- Firebase APNs anahtarı yükleme ve bazı Console işlemleri API'de YOK → kullanıcıya adım adım tarif et
- Cloudflare Global API Key: `X-Auth-Email` + `X-Auth-Key` başlıkları (Bearer değil)

## PROJE DURUMU (son güncelleme: 12 Temmuz 2026)
- ✅ **Faz 1 CANLIDA:** kayıt/OTP(kendi 6 hane)/giriş/şifre yenileme + 1:1 mesajlaşma (tikler, yazıyor, okunmamış)
- ✅ Kullanıcı arama (@kullanıcıadı / isim) — rehber yerine gerçek profiller
- ✅ Backend + LiveKit + Caddy + Postgres + Redis sunucuda Docker'da; https://api.gebzem.app, wss://rtc.gebzem.app
- ✅ Push: FCM v1 (Android ✓, iOS APNs anahtarı yüklü); Sentry (mobil + backend) açık
- ✅ **CI/CD: GitHub Actions** (Codemagic'in bedava dakikaları bitti) → APK + ad hoc IPA → **https://indir.gebzem.app**
- ✅ **ARAMA (1:1 sesli/görüntülü):** CANLI, kullanıcı testlerinden geçti (süre senkron, CallKit, ses teşhis dahil)
- ✅ **GRUP ARAMASI (sesli + görüntülü, 18 Tem):** sesli ≤32, görüntülü ≤8 kişi; video ızgara + mid-call kamera; anlık grup (member_ids) — kalıcı grup sohbeti UI'si sonraki faz
- ⏳ Sonraki: geç-katılma/kişi-ekleme → Faz 2 (gruplar, story, profil, medya) → odalar+yayın (Spaces) → admin
- ✅ Uygulama ikonu: kullanıcı tasarımı (mor/kıvrımlı logo) koda işlendi 18 Tem — kaynak
  mobile/assets/icon/kaynak.jpg; güncelleme: `dart run tool/ikon_uret.dart` + `dart run
  flutter_launcher_icons` (⚠️ sonrasında pbxproj'daki GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS
  bozulmasını git checkout ile geri al — araç bug'ı, APPICON_NAME zaten şablonda var)
- Test kullanıcıları: her sürümde DB temizleniyor (aşağıdaki rutin) → kullanıcı sıfırdan kayıt olur

## REPO YAPISI (monorepo: github.com/gbz-app/gebzem — **PUBLIC** 15 Tem 2026: Actions kotası doldu → sınırsız bedava için public yapıldı; secrets Actions'ta gizli, kodda/geçmişte hassas dosya YOK)
- `backend/` — Go API (chi + pgx + go-redis + gorilla/websocket)
- `mobile/` — Flutter (org: app.gebzem). lib/: core/ (api, ws, storage, theme), features/ (auth, chats, home), router.dart
- `admin/` — yer tutucu (Faz 5: Next.js)
- Kök: CLAUDE.md, oturum.md, arastirma-raporu.md, ozellik-listesi.md, .env.infra (gitignore'lu)

## API UÇLARI (backend)
Açık: POST /auth/register, /auth/verify (test OTP), **/auth/verify-firebase (GERÇEK SMS)**, /auth/login, /auth/forgot, /auth/reset · GET /health
Korumalı (Bearer): GET/PATCH /users/me · POST /users/me/username · POST /users/me/fcm-token · **GET /users/search?q=** (isim/@username; telefon dönmez) · GET /users/by-phone · GET /chats · POST /chats/direct · GET+POST /chats/{id}/messages · POST /chats/{id}/read · GET /ws (WebSocket; ?token= de kabul eder)
WS olayları: message.new, receipt.read, typing
**Kimlik doğrulama:** GERÇEK SMS aktif (Firebase Phone Auth → Google imzalı ID token → backend doğrular). Test moduna dönmek için Flutter: `--dart-define=REAL_SMS=false` (o zaman /auth/register+verify akışı, dev_otp yanıtta döner).
**Kullanıcı adı:** kayıtta zorunlu (@handle, 3-20 karakter a-z0-9_). Arama isim veya @username ile.

## KOMUTLAR
- **Backend yerel derleme:** `cd backend && go build ./...`
- **Flutter analiz:** `cd mobile && flutter analyze`
- **Mobil çalıştırma (emülatör, yerel backend):** `cd mobile && flutter run` (API varsayılanı 10.0.2.2:8080)
- **Mobil canlı sunucuya karşı:** `flutter run --dart-define=API_URL=http://167.233.229.88:8080`
- **DEPLOY (sunucuda güncelleme):** `ssh -i ~/.ssh/gebzem_ed25519 root@167.233.229.88 "cd /opt/gebzem/repo && git pull && cd backend && docker compose up -d --build"`
- Sunucuda log: `docker compose logs -f api` (dizin: /opt/gebzem/repo/backend)
- **YENİ SÜRÜM DAĞITIMI:** Codemagic API ile derleme tetikle (appId 6a52c71564181d764c0d9c88, workflow `android-build` / `ios-adhoc`) → artifact indir → R2 `gebzem-dist` bucket'a yükle (scratchpad/r2put.js, SigV4) → indir.gebzem.app'te güncellenir

## SUNUCU (Hetzner gebzem-1)
- IP: 167.233.229.88 · Ubuntu 24.04 · cx33 (4 vCPU/8GB) · Falkenstein · €8,99/ay
- SSH: `ssh -i ~/.ssh/gebzem_ed25519 root@167.233.229.88`
- Docker compose stack: /opt/gebzem/repo/backend → api (8080 dışa açık) + postgres:17 + redis:7 (ikisi sadece 127.0.0.1)
- `backend/.env` sunucuda JWT_SECRET içerir (git dışı). Repo klonu token'lı HTTPS remote
- ⚠️ Güvenlik duvarı henüz YOK (prototip); API şimdilik HTTP — yayın öncesi: firewall + HTTPS (api.gebzem.app + Caddy)

## MİMARİ KARARLAR (arastirma-raporu.md'ye dayalı)
- Kanal/grup: Telegram modeli (tek chats tablosu, type: direct/group/channel)
- Mesaj akışı: PostgreSQL'e yaz → Redis pub/sub "events" → hub → WebSocket; çevrimdışı = REST gecmisi (inbox deseni) + ileride FCM push
- Hediye: animasyon LiveKit data API; bakiye/işlem coin_ledger tablosunda (kayıt bonusu 100 jeton kodda çalışıyor)
- Prototipte ödeme YOK (bedava jeton); IAP V2 (%15 tier kaydı unutulmasın); payout ileride banka/İyzico (6493 — asla kendi bünyede değil)
- Harita: google_maps_flutter, cloudMapId KULLANMA (bedava kalması için); OSMF bedava tile YASAK
- Yayın öncesi yasal: BTK yer sağlayıcı bildirimi + 4 saat içerik kaldırma + trafik logu 1-2 yıl + hukukçu teyidi (sosyal ağ eşiği)
- LiveKit: sesli odalar cx33'te OK; video yayında benchmark'ın %50'si varsay + büyümede dedicated makine

## CI/CD + DAĞITIM (Codemagic)
- App: `6a52c71564181d764c0d9c88` (SSH deploy key ile bağlı — token'lı HTTPS klon ÇALIŞMIYOR!)
- Workflow'lar (codemagic.yaml): `android-build` (APK), `ios-adhoc` (IPA — keychain initialize + fetch-signing-files --create + add-certificates ŞART)
- Apple: bundle `app.gebzem`, ASC API anahtarı BYRG6K58NK (.p8 kökte, gitignore'lu), Issuer dd626245-204e-4b73-a98a-3fa9241b4a47; iPhone XS Max cihaz kayıtlı (ad hoc'a otomatik dahil)
- Codemagic'te güvenli değişken grubu: `appstore_credentials` (ISSUER_ID, KEY_IDENTIFIER, PRIVATE_KEY=p8, CERTIFICATE_PRIVATE_KEY=cert_key.pem)
- ⚠️ Codemagic API çok satırlı değerlerde CR kabul etmez → `-replace "\`r",""` şart
- ⚠️ Codemagic build logu: `GET /builds/{id}` → buildActions[].subactions[].logUrl (üst seviyede logUrl BOŞ gelir)

## HESAPLAR & ARAÇLAR
- GitHub: gbz-app · Cloudflare: Gebzemapp@outlook.com (zone gebzem.app; R2: gebzem-media + gebzem-dist→indir.gebzem.app) · Google: gebzemapp@gmail.com (gcloud girişli; API çağrılarında `x-goog-user-project` başlığı şart) · Codemagic + Apple: yukarıda
- Anahtarlar: `.env.infra` · gh CLI: `C:\Users\gebze\tools\gh\bin\gh.exe` (PATH'te yok) · gcloud: `C:\Users\gebze\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd` · Firebase CLI (npm), Node 24, git 2.54, Flutter 3.44, Go 1.26
- PowerShell tuzakları: git/gcloud çıktısı stderr'e gider (`2>&1` NativeCommandError yanıltır — kullanma); Dart 3.12'de `(_, __)` yerine `(_, _)`
Dostum sen şimdi ben test yaparken detaylı bir şekilde ve dikkatli bir şekilde canlı yayın yap ve temiz bir bıild alt öncesin çok kapsamlı bug fix araştırması yap ve en son derinlemesine yap step step ve temiz build al indir sitesi ne r saat yazmıyor göremiyorum orada saatte yazdım buna arada