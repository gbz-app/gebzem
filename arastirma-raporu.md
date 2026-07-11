# Gebzem — Derin Araştırma Raporu (Tur 1)

*11 Temmuz 2026 — 103 ajan, 21 kaynak, 103 iddia çıkarıldı, en kritik 25'i üçlü doğrulamadan geçti (24 onay, 1 çürütüldü). Tüm kaynaklar resmi/birincil ağırlıklı.*

---

## 🪙 1. JETON + HEDİYE EKONOMİSİ (en kritik bulgular)

### ✅ Model yasal ve mümkün — ama kurallar net:

| Karar | Sonuç | Neden |
|---|---|---|
| Jeton satışı | **Sadece Apple IAP + Google Play Billing** | Türkiye vitrini için harici ödeme istisnası YOK (Epic kararları sadece ABD/AEA'yı açtı; Türkiye'ye en erken Eylül 2027) |
| Komisyon | **%15** (yıllık ilk 1M USD gelire kadar) | 50K kullanıcı ölçeğinde tamamen %15 diliminde kalırsın. ⚠️ TUZAK: %15 otomatik DEĞİL — Play Console'da "15% Service Fee Tier"a kaydolman şart, yoksa %30 keserler! |
| Hediye modeli | **TikTok modeli Apple'da açıkça izinli** (Guideline 3.1.1: "tip" maddesi) | TikTok/Bigo aynı modeli çalıştırıyor. Google'da da OK ama "bahşiş muafiyeti" bizim için geçersiz (komisyon aldığımız an IAP zorunlu) |
| Jeton süresi | **Jetonlar ASLA yanmamalı** | "30 gün içinde kullan yoksa silinir" = direkt App Store reddi |
| Satın alma doğrulama | **Go backend'de sunucu taraflı** (App Store Server API, JWS imzalı; Go kütüphanesi hazır: `richzw/appstore`) | İstemciye güvenme; transactionId ile çift harcama engelle |
| Yayıncıya ödeme (payout) | **Kendi bünyende YAPMA — banka/İyzico/Papara üzerinden** | 6493 sayılı Kanun: lisanssız ödeme hizmeti = 1-3 yıl hapis. Gelir paylaşımını banka havalesiyle yaparsan sorun yok |

**Ekonomi kurgusu:** Kullanıcı ₺100'lük jeton alır → Google/Apple ₺15 keser → ₺85 sana gelir → hediye yayıncıya gidince payını banka/lisanslı kuruluşla ödersin. Komisyonu fiyatlara baştan yedir.

---

## 💬 2. MESAJLAŞMA MİMARİSİ

| Karar | Sonuç | Neden |
|---|---|---|
| Veritabanı | **PostgreSQL ile başla** | Cassandra/ScyllaDB ihtiyacı TRİLYONLARCA mesaj ölçeğinde doğuyor (Discord 177 node'a gelince geçti). 50K kullanıcı o ölçeğe yıllarca yaklaşmaz |
| Kanal/grup şeması | **Telegram modelini kopyala: tek "kanal" varlığı + "megagroup" bayrağı** | Telegram süper grupları aslında bayraklı kanallardır — tek veri modeliyle hem kanal (sınırsız üye, tek yön) hem büyük grup (200K üye, çift yön) çözülür. WhatsApp'ın 256 sınırıyla kendini kısıtlama |

---

## 📡 3. CANLI YAYIN + LIVEKIT (kritik boyutlandırma gerçekleri)

| Bulgu | Detay |
|---|---|
| **Sesli odalar çok ucuz** ✅ | 16 çekirdekte 10 konuşmacı + 3.000 dinleyici = %80 CPU, sadece 23 MB/s. Ses, videodan ~23 kat ucuz. **cx33'ümüz sesli odalara rahat yeter** |
| **Video yayın pahalı** ⚠️ | Benchmark: 1 yayıncı + 3.000 izleyici (720p) = %92 CPU + ~4,2 Gbps trafik — ama bu 16 DEDICATED çekirdekte. Bizim cx33 = 4 paylaşımlı vCPU → kapasiteyi agresif düşür. Gerçekçi plan: benchmark'ın ~%50'si. cx33'ün 1 Gbps portu ~700 izleyicide dolar |
| **Oda tek sunucuya sığmak zorunda** ⚠️ | Self-hosted LiveKit'te bir oda sunuculara bölünEMEZ. 100 izleyicili yayınlar sorun değil; risk = tek yayının viral olması ("viral yayın tavanı" olarak nota al) |
| **Hediye/yorum için ayrı WebSocket KURMA** ✅ | LiveKit'in yerleşik Text Streams (yorum akışı) + Data Packets (hediye animasyonu, reliable mod) yeter. Go SDK'daki `RoomService.SendData` ile backend hediyeyi odaya enjekte eder |
| **Hediye İŞLEMİ ledger'da** ⚠️ | LiveKit data kanalı best-effort — kopan kullanıcı paketi kaçırır. Bakiye düşme/yayıncı kazancı HER ZAMAN sunucu veritabanında (ledger) işlenmeli; LiveKit sadece animasyonu taşır |
| Büyüme planı | Sesli odalar cx33'te başlar → video yayın büyüyünce dedicated CPU'lu makine (CCX/AX) eklenir |

---

## ⚠️ ÇÜRÜTÜLEN İDDİA
- "Discord 2017'de 12 Cassandra node ile milyarlarca mesaj saklıyordu" → 0-3 çürütüldü (doğrusu: 2022'de 177 node/trilyonlarca mesaj). PostgreSQL önerisi yine geçerli ama bu gerekçeyle değil.

## ❓ AÇIK SORULAR (2. tur araştırma gereken konular)
Bu turda doğrulama en kritik konulara (para + hukuk + LiveKit + veritabanı) odaklandı. Şu bölümler doğrulanmış kanıt üretmedi, 2. tur gerekiyor:
1. **Tam özellik envanteri + MVP tablosu** (WhatsApp 155 özellik listesi kaynağı bulundu ama doğrulanmadı)
2. **Mesaj kuyruğu seçimi** (NATS vs Kafka vs Redis Streams) + E2E şifreleme kararı
3. **Moderasyon + 5651 kanunu yükümlülükleri**
4. **Flutter mimarisi** (Riverpod/Bloc, Drift/Isar, story görüntüleyici)
5. **İzin akışları + Google Maps vs OpenStreetMap maliyeti**
6. **Codemagic/CI-CD kurulumu**
7. **1K/10K/50K maliyet projeksiyon tablosu**
8. Yayıncı kazançlarının vergi boyutu (stopaj — mali müşavir görüşü şart)

## 📌 Kesinleşen Kararlar Özeti
1. Jeton satışı: IAP/Play Billing, %15 komisyon (tier kaydını unutma), jeton yanmaz
2. Doğrulama: sunucu taraflı, Go backend, JWS imza + transactionId dedup
3. Payout: banka/İyzico/Papara üzerinden — asla kendi bünyende değil
4. Veritabanı: PostgreSQL
5. Kanal/grup: Telegram'ın tek-model şeması
6. RTC: LiveKit self-hosted; sesli odalar cx33'te, video yayın için büyümede dedicated makine
7. Hediye animasyonu: LiveKit data API; hediye parası: sunucu ledger

---
---

# TUR 2 RAPORU (11 Temmuz 2026, 22:43)
*108 ajan, 26 kaynak, 123 iddia → 25 doğrulandı (23 onay, 2 çürütüldü)*

## ⚖️ 1. TÜRKİYE YASAL YÜKÜMLÜLÜKLERİ (yayına çıkmadan ŞART)

| Yükümlülük | Detay |
|---|---|
| **BTK yer sağlayıcı bildirimi** | yersaglayici.btk.gov.tr'den form doldurulacak (e-Devlet girişli). Bildirmeme cezası: 100 bin - 1 milyon TL |
| **Trafik kayıtları** | 1-2 yıl saklanmalı (Md. 5/3) — log altyapısını buna göre kuracağız |
| **İçerik kaldırma** | Mahkeme/BTK kararını **en geç 4 saat içinde** uygulama zorunluluğu — admin panelde acil kaldırma butonu şart |
| ⚠️ **Sosyal ağ sağlayıcı rejimi** | "1M kullanıcı altı muaf" iddiası doğrulamada **ÇÜRÜTÜLDÜ (0-3)** — yayın öncesi bilişim hukukçusuna danışılmalı |

## 📡 2. LIVEKIT / SUNUCU GERÇEKLERİ

- Resmi kapasite rakamları 16 dedike çekirdekte; **cx33 için 4-8 kat düşür** (GitHub'da aynı donanımda ancak yarısına ulaşılmış)
- **Sesli odalar: agresif planla** (video'dan ~23 kat ucuz) ✅ · **Video yayın: temkinli** — tek viral yayın cx33'ün CPU'sunu VE 1 Gbps portunu tek başına doldurabilir
- Hetzner'in 20 TB dahil trafiği, 3.000 izleyicili tek yayında ~10,5 saatte biter (aşım €1/TB — felaket değil ama takip şart)
- **Oda tek sunucuya sığmak zorunda** — en büyük yayın = en büyük tek sunucu. Büyürken "viral yayın node'u" olarak 1 dedike makine eklenir
- Hetzner zam: cx33 artık €8,49+IPv4≈€8,99/ay (bizim fiyatımız bu, doğru)

## 🗺️ 3. HARİTA KARARI (net sonuç!)

**Google Maps SEÇ, çünkü fiilen bedava:**
- Mobil harita gösterimi (google_maps_flutter): **SINIRSIZ ÜCRETSİZ** ⚠️ tek şart: `cloudMapId` KULLANMA (kullanırsan ücretli SKU'ya düşer!)
- Mesajdaki konum önizlemesi (Static Maps): ayda 10.000 bedava — bunun yerine mini harita widget'ı kullanırsak o da bedava
- ❌ OpenStreetMap'in bedava tile sunucusu ticari uygulamada YASAK/güvenilmez (50K kullanıcıda bloklanırız) — alternatif olsaydı da paralı tile sağlayıcı gerekecekti

## 📱 4. ÖZELLİK KIYASLARI (doğrulanan)
- WhatsApp grup görüntülü arama sınırı: **32 kişi** — bizim hedef de bu olur
- TikTok Live: moderatör atama + sabitli yorum + çift para birimi (Coin→hediye→Diamond→nakit) doğrulandı. Prototipte sadece jeton→hediye→ledger modellenecek

## 💰 5. MALİYET NOTLARI
- **R2: egress tamamen bedava** (medya uygulaması için en büyük avantaj), 10 GB depolama + 10M okuma/ay bedava
- **Firebase PNV Türkiye'yi desteklemiyor** — OTP, klasik phone-auth SMS ile (~$0,06/SMS, doğrulanmamış). Gerçek SMS'e geçerken Netgsm karşılaştırması yapılacak
- Prototip dönemi sabit gider: **~€9/ay sunucu + $0 Cloudflare + $0 Google** ✅

## 🔧 6. DOĞRULANAMAYAN KONULAR (pratik varsayılanlarla gidilecek)
Kuyruk (Redis pub/sub + PostgreSQL inbox/outbox deseni — 5K eşzamanlıda standart), E2E (prototipte yok, V2'de Signal protokolü), Flutter (Riverpod + Drift önerisi), NSFW tespiti (Sightengine ~$29/ay'dan başlıyor, V2 konusu), Codemagic (ücretsiz ~500 dk/ay). Bunlar kod aşamasında pratikte test edilecek — araştırma kaynakları toplandı ama 3'lü doğrulamadan geçmedi.
