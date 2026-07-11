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

### ⏭️ Sonraki oturuma devir
- SIRADA: Flutter Faz 1 ekranları (giriş/OTP/kayıt + sohbet listesi + sohbet ekranı) ve backend'i yerelde docker-compose ile ayağa kaldırıp uçtan uca test
- Sonra: sunucuya (gebzem-1) deploy + Google `gebzem` projesi yeniden kurulumu (silindi — kullanıcı onayıyla) + FCM push
- PowerShell notu: `git push` çıktısı stderr'e gider — başarıyı `git rev-parse origin/main` ile doğrula
- Kullanıcı KURALLARI: (1) her adımda git push, (2) her oturumda bu dosya güncellenecek, (3) kullanıcı onayı olmadan kurulum/işlem yapma, (4) kısa yaz
