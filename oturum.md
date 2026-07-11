# OTURUM GÜNLÜĞÜ — Gebzem Projesi

> Her oturumda ne yaptık, ne denedik, ne oldu/olmadı. Zaman kazanmak için her oturum sonunda güncellenir. KURAL: Proje başladığında her adım git push'lanır.

---

## Oturum 1 — 11 Temmuz 2026

### ✅ Yapılanlar
- **İzin ayarları:** Claude'un onay sormadan çalışması için `bypassPermissions` + araç izin listesi kuruldu (`~/.claude/settings.json`)
- **GitHub temizliği:** gbz-app hesabındaki 2 eski repo silindi (gebzem, gapp2yxq1) — hesap boş, token elimizde (.env.infra)
- **Cloudflare kurulumu:** API token alındı; R2 aktif + `gebzem-media` bucket oluşturuldu; Images + Stream aboneliği $0/ay planla açıldı; gebzem.app zone'unda Transformations aktifleştirildi ("This zone only")
- **Hetzner:** Eski proje kullanıcı tarafından zaten silinmişti. Yeni proje `gebzem` + API token; **gebzem-1 sunucusu kuruldu: 167.233.229.88** (cx33: 4 vCPU/8GB/80GB, Ubuntu 24.04, Falkenstein, €8,99/ay); SSH anahtarı: `~/.ssh/gebzem_ed25519`; paketler güncellendi + **Docker 29.6.1 kuruldu**
- **Google/Firebase:** gcloud CLI zaten kuruluymuş ve gebzemapp@gmail.com ile girişliymiş (eski projeden) — bu erişimle çalışıyoruz, token gerekmedi. Firebase CLI npm ile kuruldu. Eski `gebzem-app-push` + Gemini projesi silindi (30 gün geri alınabilir). ⚠️ Yeni `gebzem` projesi de kullanıcı isteğiyle silindi — **proje başlarken Google projesi YENİDEN kurulacak**
- **Araştırma Tur 1 tamamlandı** → `arastirma-raporu.md`: jeton/hediye yasal çerçevesi, payout kuralı (banka/İyzico üzerinden şart), PostgreSQL kararı, Telegram kanal modeli, LiveKit boyutlandırma gerçekleri
- **Araştırma Tur 2 başlatıldı** (devam ediyor): özellik envanteri + MVP tablosu, Redis/kuyruk, moderasyon+5651, Flutter paketleri, izinler+harita, CI/CD, maliyet projeksiyonu

### ❌ Denenip olmayanlar / öğrenilenler
- GitHub CLI winget MSI kurulumu UAC'ye takıldı → **çözüm: portable zip** (`C:\Users\gebze\tools\gh\bin\gh.exe`)
- Cloudflare "$0 plan" içinde depolama blokları paralıydı → **çözüm: depolamasız abonelik + R2 + zone Transformations (bedava)**
- Cloudflare token'ının DNS yetkisi hesap-düzeyinde kaldı → zone DNS kayıtları API'den okunamıyor; DNS işleri deploy sırasında dashboard'dan veya token güncellenerek yapılacak
- Firebase API çağrılarında `x-goog-user-project: gebzem` başlığı şart (kota hatası veriyor yoksa)
- gcloud çıktıları PowerShell'de `2>&1` ile NativeCommandError gürültüsü veriyor → stderr yönlendirmeden çalıştır
- Google admin.google.com kullanıcı hesabıyla açılmıyor (Workspace gerekli) — gerek de yok, Firebase Console + gcloud yeterli

### 📌 Kararlar
- Uygulama: WhatsApp + Spaces + TikTok Live karışımı; isim/domain: **gebzem.app**
- Stack: Flutter + Go + PostgreSQL + Redis + LiveKit (self-hosted) + Cloudflare R2 + Firebase + React admin
- Prototipte ödeme YOK — bedava jeton dağıtılacak, hediye sistemi ledger'la çalışacak, IAP sonra
- Android paket adı: `app.gebzem`
- Tüm anahtarlar: `.env.infra` (gitignore'a girecek!)

### ✅ Ek: Tur 2 araştırma tamamlandı (22:43)
- Rapora eklendi (`arastirma-raporu.md` Tur 2 bölümü). Öne çıkanlar: BTK yer sağlayıcı bildirimi şart + 4 saat içerik kaldırma kuralı; "1M altı sosyal ağ muafiyeti" iddiası çürütüldü (hukukçu teyidi gerekli); Google Maps mobil SDK cloudMapId'siz sınırsız bedava (harita kararı: Google Maps); OSM bedava tile yasak; cx33 için LiveKit rakamları 4-8x düşürülecek; R2 egress bedava; Firebase PNV Türkiye'de yok
- CLAUDE.md oluşturuldu (zorunlu kurallar + stack + araç yolları)
- Karar: prototipte ödeme yok → bedava jeton + ledger

### ✅ Ek: Kodlama başladı (23:00+)
- `ozellik-listesi.md` oluşturuldu ve kullanıcı onayladı (görüntülü arama MVP'de — kullanıcı özellikle teyit istedi)
- CLAUDE.md oluşturuldu, kullanıcı onayladı
- **Monorepo kuruldu ve GitHub'da: https://github.com/gbz-app/gebzem (private)** — gbz-a3 klasörü repo kökü; .gitignore `.env.infra`yı koruyor (doğrulandı)
- **Backend Faz 1 iskeleti yazıldı ve DERLENDİ:** Go + chi + pgx + go-redis + gorilla/websocket. Uçlar: /auth (register, verify, login, forgot, reset — OTP dev modda yanıtta dönüyor), /chats (listele, direct aç, mesaj gönder/çek, okundu işaretle), /ws (WebSocket + typing + Redis pub/sub hub). Şema: users, otp_codes, chats (Telegram tek-model), chat_members, messages, message_receipts (tikler), blocks, coin_ledger (kayıt bonusu 100 jeton)
- **Flutter projesi oluşturuldu:** mobile/ (org: app.gebzem, android+ios) + temel paketler (riverpod, go_router, dio, web_socket_channel, secure_storage, intl)
- admin/ yer tutucu (Faz 5)
- Git: 3 commit push'landı, origin/main doğrulandı

## Oturum 2 — 12 Temmuz 2026

### ✅ Yapılanlar
- **Backend:** /users uçları eklendi (me, by-phone, profil güncelleme) — derleme OK
- **Flutter Faz 1 ekranları tamamı yazıldı, analiz TEMİZ:**
  - Çekirdek: tema (WhatsApp-vari yeşil, dark/light), Dio API istemcisi (10.0.2.2 emülatör varsayılanı, --dart-define=API_URL ile değişir), WebSocket servisi (üstel geri çekilmeli otomatik yeniden bağlanma), güvenli token deposu
  - Giriş: login, kayıt, OTP (dev modda kod otomatik dolar), şifremi unuttum/yenileme
  - Ana ekran: 5 sekmeli NavigationBar (Sohbetler aktif; Aramalar/Odalar/Canlı Faz 3-4 yer tutucuları; Profil'de çıkış + jeton bilgisi)
  - Sohbet listesi: WhatsApp tarzı (okunmamış rozeti, sabitleme ikonu, son mesaj önizleme, Türkçe zaman etiketleri), + butonuyla numaradan yeni sohbet
  - Sohbet ekranı: balonlar (yeşil/beyaz), tarih çipleri (Bugün/Dün), tikler (gri ✓✓ → okununca mavi), "yazıyor..." göstergesi (2 sn'de bir throttle), otomatik kaydırma
- Şablon widget_test.dart silindi (MyApp kalktığı için kırıktı)

### ❌ Denenip olmayanlar / öğrenilenler
- Dart 3.12'de `(_, __)` lint uyarısı veriyor → `(_, _)` wildcard kullan
- main.dart flutter create'ten kalma — Write'tan önce Read gerekti

### ✅ SUNUCUYA DEPLOY EDİLDİ VE CANLIDA TEST EDİLDİ (12 Tem, 22:15)
**Yapılan adımlar (sırayla, detaylı):**
1. `backend/Dockerfile` yazıldı (çok aşamalı: golang:1.26-alpine build → alpine çalışma imajı)
2. `docker-compose.yml`'e `api` servisi eklendi (port 8080 dışa açık; JWT_SECRET .env'den; DEV_MODE=true — OTP yanıtla dönüyor); `.env.example` eklendi
3. Commit + push (8ecd992)
4. Sunucuda: `/opt/gebzem/repo`'ya token'lı HTTPS ile klon; `backend/.env` içine `openssl rand -hex 32` ile JWT_SECRET üretildi
5. `docker compose up -d --build` → 3 konteyner ayakta: api + postgres:17 + redis:7 (pg/redis sadece 127.0.0.1'e bağlı)
6. Migration otomatik koştu (schema_migrations tablosu + 001_init.sql)

**CANLI TEST SONUÇLARI (dışarıdan, http://167.233.229.88:8080):**
- /health → ok ✅
- Kayıt +905000000001 → dev_otp döndü → verify → token ✅
- /users/me → isim + **100 jeton kayıt bonusu ledger'dan işlendi** ✅
- 2. kullanıcı (+905000000002) → numaradan bulma → direct sohbet → **iki yönlü mesajlaşma** ✅
- Sohbet listesi: okunmamış=1, son mesaj doğru ✅
- Test kullanıcıları canlıda duruyor: +905000000001 / +905000000002 (şifre: test123)

**Öğrenilenler:**
- PowerShell konsolu emojileri ?? gösteriyor (görüntü sorunu; veritabanında UTF-8 doğru)
- CLAUDE.md'yi kullanıcı elle düzenlemiş olabilir — Write öncesi Read şart
- Kullanıcı geri bildirimi: CLAUDE.md + oturum.md HER ÖNEMLİ ADIMDA güncellenecek (sadece tur sonunda değil) — kural CLAUDE.md'ye eklendi

### ✅ CI/CD KURULDU — İLK APK BULUTTAN ÇIKTI (12 Tem, 01:00-02:00)
**Yapılanlar (detaylı):**
1. Bilgisayarda Android SDK YOK çıktı (flutter doctor [X]) → yerel APK derlenemedi → çözüm: Codemagic bulut derlemesi
2. Kullanıcı Codemagic API token verdi (hesap: gebzemapp@outlook.com — ESKİ hesabı varmış, eski "gebzem" app kaydı duruyordu)
3. **Codemagic temizliği:** eski uygulama API'den silindi (DELETE /apps/:id çalışıyor)
4. İlk deneme: token'lı HTTPS URL ile app ekleme → **klonlama BAŞARISIZ** ("Failed to clone repository" — Codemagic private repoda URL-gömülü token kabul etmiyor)
5. **Çözüm: SSH deploy key** — `~/.ssh/gebzem_deploy` üretildi, public key GitHub'a deploy key (read-only) eklendi, app SSH ile yeniden bağlandı → klon OK
6. `codemagic.yaml` yazıldı (android-build workflow: mac_mini_m2, flutter stable, APK artifact, API_URL=canlı sunucu gömülü)
7. AndroidManifest: INTERNET izni + usesCleartextTraffic=true (prototip HTTP için) + label "Gebzem"
8. **DERLEME BAŞARILI** → app-release.apk (50,6 MB) → 7 gün geçerli public link üretildi (POST artifact/public-url) → kullanıcıya verildi
9. Apple: kullanıcının **Developer Program üyeliği AKTİF** (Mikail Saban). App Store Connect API anahtarı üretildi: Key ID BYRG6K58NK, .p8 dosyası `gbz-a3/AuthKey_BYRG6K58NK.p8` (⚠️ .gitignore'a *.p8 + AuthKey_* eklendi). Issuer ID'nin TAMAMI bekleniyor (dd626245-204... diye başlıyor)
10. ASC'de eski 2 uygulama kaydı var (Gebzem App, GEBZEM) — API'den silinemiyor, kullanıcıya UI talimatı verildi (App Information → Remove App)

**KRİTİK DERS (kullanıcı haklı çıktı, güven sarsıldı):** iOS'ta "linkten kurulum YOK" dedim — YANLIŞTI. **Ad hoc imzalama + Codemagic OTA linki ile VAR** (eski projede de böyle yapılıyormuş). Özür dilendi, düzeltildi. Bir daha: emin olmadan "yok/olmaz" deme!

**iOS planı (ad hoc, TestFlight'sız):** kullanıcıdan Issuer ID (tam) + iPhone UDID (iTunes/Apple Devices'ta Seri No'ya tıklayınca görünür) → UDID'yi ASC API ile cihaz kaydet → ad hoc provisioning → codemagic.yaml'a ios-adhoc workflow → derleme → OTA kurulum linki

### ✅ APPLE TEMİZLİĞİ + iOS KURULUMU (12 Tem, 02:00+)
1. Kullanıcı Issuer ID verdi: dd626245-204e-4b73-a98a-3fa9241b4a47 (.env.infra'da). ASC API erişimi Node scriptiyle kuruldu (JWT ES256 imzalama — scratchpad/asc.js; PS 5.1'de ES256 zor, Node crypto.sign + ieee-p1363 çözümü)
2. **Apple temizliği:** 4 eski profil silindi, eski DISTRIBUTION sertifikası iptal edildi. 3 eski bundle ID (com.gebzem.social/app/app2) App Store kayıtlarına bağlı — kullanıcı 2 eski app kaydını (Gebzem App + GEBZEM) UI'dan silince (App Information → Remove App) bunlar da silinecek ← BEKLİYOR
3. **iPhone (XS Max) zaten cihaz kayıtlıymış** — UDID: 00008020-0018258A0262002E, ENABLED. UDID istemeye gerek kalmadı
4. Yeni bundle ID: **app.gebzem** (T3ARK697ZH)
5. Codemagic'e güvenli değişkenler yüklendi (appstore_credentials grubu): ISSUER_ID, KEY_IDENTIFIER, P8, CERTIFICATE_PRIVATE_KEY (yeni RSA — cert_key.pem, gitignore'da). ⚠️ DERS: Codemagic API çok satırlı değerlerde \r kabul etmiyor — `-replace "`r",""` şart (ilk deneme 400 verdi)
6. codemagic.yaml'a **ios-adhoc** workflow eklendi (fetch-signing-files --create + xcode-project use-profiles + flutter build ipa)
7. **iOS derleme #1: adımlar başarılı AMA artifact 0 adet** — IPA glob'u eşleşmedi. Düzeltme: artifact yolları genişletildi + `find` ile konum loglama → **derleme #2 çalışıyor** (6a52cb6790a34e4431e6c1f3)
8. ⚠️ DERS: Codemagic build logları API'den okunamıyor (logUrl boş) — hata ayıklama için script içine echo/find koy

### ✅ iOS IPA ÜRETİLDİ + indir.gebzem.app YAYINDA (12 Tem, 02:30)
9. **iOS derleme #2 de 0 artifact verdi** → step logu (subactions[].logUrl) çekildi → gerçek hata: `exportArchive No signing certificate "iOS Distribution" found`. Sebep: sertifika keychain'e yüklenmemiş
10. **Düzeltme:** codemagic.yaml'a `keychain initialize` + `keychain add-certificates` eklendi → **derleme #3 BAŞARILI: gebzem.ipa (7 MB)** ✅
11. Kullanıcı isteği: linkler gebzem.app üzerinden olsun → **R2 `gebzem-dist` bucket + custom domain `indir.gebzem.app`** kuruldu
    - ⚠️ DERS: custom domain POST'tan sonra `enabled` boş kalıyor → `PUT /r2/buckets/{b}/domains/custom/{domain}` ile açmak ŞART (route `custom_domains` DEĞİL, `domains/custom`)
    - ⚠️ R2 custom domain kök dizinde index.html servis ETMEZ → link `/index.html` ile verilmeli
12. R2'ye yüklendi (SigV4 Node scripti — scratchpad/r2put.js): gebzem.apk (50,6 MB), gebzem.ipa (7 MB), manifest.plist (itms-services), index.html (kurulum sayfası)
13. **Doğrulandı (HTTP 200):** indir.gebzem.app/index.html, /manifest.plist, /gebzem.apk, /gebzem.ipa
14. Model olayı: Anthropic güvenlik filtresi mesajı yanlış işaretledi → Fable 5'ten Opus 4.8'e otomatik geçildi (kullanıcı Fable 5 ödediği için rahatsız oldu; `/model fable` ile dönülebilir, `/feedback` ile bildirilebilir)

### ✅ PUSH BİLDİRİM ALTYAPISI KURULDU (12 Tem, 02:40)
1. ASC'deki 2 eski app kaydı Apple tarafından SİLİNEMİYOR ("This app is unable to be removed" — build/IAP geçmişi olan kayıtlar; zararsız hayalet, bırakıldı). Eski APNs anahtarı GebzemPush görüldü → kullanıcı revoke edip YENİ anahtar (GebzemPush2) oluşturacak — .p8 BEKLENİYOR
2. **Google projesi sıfırdan: `gebzem-app`** ("gebzem" ID'si 30 gün silinme beklemede olduğundan kullanılamadı). Firebase + fatura + FCM API tamam
3. Firebase'e Android (app.gebzem) + iOS (app.gebzem) kayıtlı; google-services.json → mobile/android/app/, GoogleService-Info.plist → mobile/ios/Runner/ (⚠️ artık repoda — bunlar gizli değil, APK içine gömülen kimlikler)
4. lib/firebase_options.dart ELLE yazıldı (flutterfire CLI'sız — config değerlerinden; iOS pbxproj değişikliği gerekmedi çünkü options programatik veriliyor)
5. Servis hesabı: gebzem-fcm@gebzem-app + roles/firebasecloudmessaging.admin (⚠️ roles/cloudmessaging.admin DEĞİL — desteklenmiyor) + fcm-sa.json (gitignore'da; sunucuya scp'lendi, compose volume: /secrets/fcm-sa.json)
6. **Backend:** internal/push/fcm.go (FCM v1, SA JWT — ek bağımlılıksız golang-jwt RS256 + oauth2 token cache; UNREGISTERED token otomatik silme), migration 002 device_tokens, POST /users/me/fcm-token, SendMessage'da async NotifyUsers (gönderen adı + önizleme)
7. **Flutter:** firebase_core + firebase_messaging; main'de Firebase.initializeApp; girişte bildirim izni + token kaydı + onTokenRefresh; gradle: settings.gradle.kts + app/build.gradle.kts'e com.google.gms.google-services
8. Sunucu yeniden deploy edildi: migration geçti, "push: aktif (proje: gebzem-app)" logda ✅
9. Yeni Android+iOS derlemeleri tetiklendi (6a52d666..., 6a52d667...) — bitince indir.gebzem.app güncellenecek

### ⏭️ Sonraki oturuma devir
- Derlemeler bitince: artifact indir → R2'ye yükle (scratchpad/r2put.js + files.json) → indir.gebzem.app güncel
- **Android push bu yeni APK ile ÇALIŞIR** (uçtan uca test: iki cihaz, biri uygulama kapalı)
- **iOS push için BEKLENEN:** kullanıcının yeni APNs anahtarı (.p8 + Key ID) → Firebase Console'a yükleme (Project settings → Cloud Messaging → Apple apps) + bundle'a PUSH_NOTIFICATIONS capability (ASC API) + Runner.entitlements (aps-environment) → yeni iOS derlemesi
- Kullanıcı testi: https://indir.gebzem.app/index.html (yeni sürümler yüklenince)
- Bilinen eksik #1: direct sohbet başlığı boş (ListChats karşı üye adı) ← kod tarafında İLK İŞ
- Yayın öncesi: ufw + HTTPS + DEV_MODE=false + gerçek SMS + BTK bildirimi
- Sonra: sunucuya (gebzem-1) deploy + Google `gebzem` projesi yeniden kurulumu (silindi — kullanıcı onayıyla) + FCM push
- PowerShell notu: `git push` çıktısı stderr'e gider — başarıyı `git rev-parse origin/main` ile doğrula
- Kullanıcı KURALLARI: (1) her adımda git push, (2) her oturumda bu dosya güncellenecek, (3) kullanıcı onayı olmadan kurulum/işlem yapma, (4) kısa yaz
