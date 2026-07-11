# Gebzem Projesi — Claude Kuralları

WhatsApp + Twitter Spaces + TikTok Live karışımı sosyal uygulama. Hedef: ~50K kullanıcı, Türkiye pazarı. Domain: gebzem.app

## ZORUNLU KURALLAR (kullanıcı emri)
1. **Her oturumda `oturum.md` güncellenir** — yapılanlar, denenenler (oldu/olmadı), kararlar, devir notları. Oturum başında OKU, oturum sonunda/önemli adımlarda GÜNCELLE.
2. **Her adımda git push** — repo oluştuğunda her anlamlı değişiklik commit + push edilir.
3. **Onaysız işlem yok** — kullanıcı "yap" demeden kurulum/silme/deploy yapma. Önce öner, onay gelince uygula.
4. **Kısa yaz** — uzun tablo/özet yok; net cevap + gereken aksiyon.
5. **`.env.infra` ASLA git'e girmez** — tüm anahtarlar orada; repo kurulurken ilk iş .gitignore'a ekle.
6. Türkçe konuş.

## STACK (kesinleşti — tekrar tartışma)
- **Mobil:** Flutter (paket adı: `app.gebzem`)
- **Backend:** Go — REST + WebSocket
- **Veritabanı:** PostgreSQL (mesaj deposu) + Redis (pub/sub, cache, presence)
- **RTC:** LiveKit self-hosted (arama, görüntülü, grup arama, sesli oda, canlı yayın)
- **Medya:** Cloudflare R2 (`gebzem-media` bucket) + Image Transformations (gebzem.app zone)
- **Auth/Push:** Firebase — telefon OTP + FCM (Google projesi YENİDEN kurulacak, eskisi silindi)
- **Admin:** React (Next.js) — admin.gebzem.app
- **Sunucu:** Hetzner gebzem-1 — 167.233.229.88 (cx33, Ubuntu 24.04, Docker kurulu; SSH: `~/.ssh/gebzem_ed25519`, kullanıcı root)
- **CI/CD:** Codemagic (planlandı)

## MİMARİ KARARLAR (araştırma raporlarına dayalı — arastirma-raporu.md)
- Kanal/grup: Telegram modeli (tek "channel" varlığı + megagroup bayrağı)
- Hediye: animasyon LiveKit data API'siyle; bakiye/işlem HER ZAMAN sunucu ledger'ında (PostgreSQL)
- Prototipte ödeme YOK: bedava jeton (kayıt bonusu + admin panelden yükleme). IAP sonra eklenecek
- Yayıncı payout: ileride banka/İyzico/Papara üzerinden (6493 sayılı kanun — asla kendi bünyede değil)
- Sesli odalar cx33'te çalışır; video canlı yayın büyüyünce dedicated makine (CCX/AX) eklenecek
- Mesaj akışı: Go → PostgreSQL'e yaz → Redis pub/sub ile ilet → çevrimdışıysa FCM push

## HESAPLAR
- GitHub: gbz-app (boş — repolar proje başında açılacak)
- Cloudflare: Gebzemapp@outlook.com (zone: gebzem.app)
- Google: gebzemapp@gmail.com (gcloud girişli; Firebase API çağrılarında `x-goog-user-project` başlığı şart)
- Anahtarlar: `.env.infra`

## ARAÇLAR (bilgisayarda hazır)
- GitHub CLI: `C:\Users\gebze\tools\gh\bin\gh.exe` (PATH'te yok, tam yol kullan)
- gcloud: `C:\Users\gebze\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd`
- Firebase CLI (npm global), Node 24, git 2.54
- gcloud çıktılarında `2>&1` kullanma (PowerShell NativeCommandError gürültüsü)
