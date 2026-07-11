# Gebzem Uygulaması — Derin Araştırma Talimatı (TASLAK)

## Uygulama Vizyonu
WhatsApp + Twitter Spaces + TikTok Live karışımı bir sosyal uygulama:
- **Mesajlaşma:** 1:1 sohbet, gruplar, kanallar (Telegram tarzı), story/durum, konum paylaşımı
- **Arama:** 1:1 ve grup sesli/görüntülü arama
- **Sesli odalar:** Twitter Spaces tarzı (host, konuşmacı, dinleyici rolleri)
- **Canlı yayın:** TikTok Live tarzı — izleyiciler yayıncıya HEDİYE atabilir
- **Jeton ekonomisi:** Google Play / App Store içi satın alma ile jeton al → hediyeye çevir → yayıncıya gönder → yayıncı kazanç elde eder
- **Hedef:** ~50.000 aktif kullanıcı, Türkiye pazarı
- **Teknoloji tabanı (kesinleşen):** Flutter (mobil), Go (backend), Hetzner sunucu, LiveKit (RTC), Cloudflare R2 (medya), Firebase (OTP+push)

## Araştırılacak Konular

### 0. TAM ÖZELLİK ENVANTERİ (kullanıcının fikri yok — liste araştırmadan çıkacak)
- **WhatsApp'ın TÜM özelliklerinin dökümü:** okundu/iletildi (tik sistemi), sohbet sabitleme, arşivleme, sessize alma, mesaj iletme, herkesten silme, yanıtlama/alıntı, emoji tepkileri, sesli mesaj, yıldızlı mesajlar, süreli/kaybolan mesajlar, anketler, @bahsetme, engelleme, son görülme/gizlilik ayarları, grup yönetici yetkileri, grup davet linkleri, topluluklar — eksiksiz liste
- **Telegram'dan farklı/ekstra özellikler:** kanallar, botlar, süper gruplar — hangileri değerli
- **Sesli/görüntülü arama özellikleri dökümü:** grup aramasında grid görünüm, konuşanı büyütme, mikrofon/kamera kapatma, hoparlör değiştirme, aramaya kişi ekleme, ekran paylaşımı, küçük pencere (PiP), arka planda arama, arama geçmişi, cevapsız arama bildirimi
- **TikTok Live özellik dökümü:** hediye çeşitleri/animasyonları, sıralama (leaderboard), yayıncı seviye sistemi, PK/karşılaşma modu, yorum akışı, sabitlenmiş yorum, moderatör atama
- **Twitter Spaces özellik dökümü:** el kaldırma, konuşmacı daveti, kayıt, planlama, dinleyici listesi
- **ÇIKTI:** Tüm özelliklerin MVP (ilk sürümde şart) / V2 (sonra) / V3 (lüks) diye önceliklendirilmiş tablosu — "WhatsApp kullanıcısı neyi ararsa bulamayınca uygulamayı siler" kriteriyle

### 1. Jeton + Hediye Ekonomisi (EN KRİTİK)
- Google Play Billing ve Apple StoreKit ile sanal para (jeton) satışı nasıl kurulur? Komisyon oranları (%15/%30) ve 2026 güncel kuralları
- TikTok/Bigo Live hediye sistemleri teknik olarak nasıl çalışıyor? (hediye animasyonları, gerçek zamanlı bildirim, bakiye yönetimi)
- Yayıncıya para ödeme (payout) nasıl yapılır? Türkiye'de yasal gereklilikler (vergi, ödeme kuruluşu lisansı gerekir mi, Papara/İyzico/banka entegrasyonu)
- Apple/Google politikaları: sanal hediye/jeton uygulamalarında yasak ve zorunluluklar, uygulama reddi riskleri
- Çifte harcama/sahtecilik önleme: sunucu taraflı satın alma doğrulaması (receipt validation)

### 2. Mesajlaşma Mimarisi (WhatsApp ölçeği)
- Go ile 50K kullanıcılık gerçek zamanlı mesajlaşma: WebSocket mimarisi, hangi kütüphaneler, kaç sunucu
- Veritabanı seçimi: PostgreSQL yeterli mi, ne zaman ScyllaDB/Cassandra gerekir? Mesaj saklama şeması
- Mesaj kuyruk sistemi: NATS vs Kafka vs Redis Streams — hangisi bu ölçek için doğru
- Çevrimdışı mesaj teslimi, okundu bilgisi (çift tik/mavi tik), "yazıyor..." göstergesi standart implementasyonları
- Kanallar (tek yönlü yayın, sınırsız üye) ile grupların (çift yönlü, ~256 üye) mimari farkları
- Uçtan uca şifreleme (E2E): prototipte gerekli mi, sonradan eklenebilir mi, Signal protokolü entegrasyon maliyeti

### 3. Canlı Yayın + Hediye Entegrasyonu
- LiveKit ile TikTok tarzı yayın: hediye animasyonlarının yayına gerçek zamanlı bindirilmesi (data channel vs ayrı WebSocket)
- Eşzamanlı 100+ yayın, yayın başına 100+ izleyici için LiveKit sunucu boyutlandırması (Hetzner cx33'ten başlayarak büyüme planı)
- Yayın kaydı (VOD) gerekli mi, maliyeti ne
- Moderasyon: canlı yayında yasaklı içerik tespiti — hazır servisler (ücretsiz/ucuz), Türkiye yasal zorunlulukları (5651 sayılı kanun, yer sağlayıcı yükümlülükleri)

### 4. Flutter Uygulama Mimarisi
- 2026 itibarıyla büyük Flutter sohbet uygulaması için en iyi durum yönetimi (Riverpod/Bloc) ve yerel veritabanı (Drift/Isar/ObjectBox) seçimi
- Mesaj listesi performansı: 10K+ mesajlı sohbette akıcı kaydırma teknikleri
- LiveKit Flutter SDK + CallKit (iOS) / ConnectionService (Android) entegrasyonu — arama gelme deneyimi
- Story görüntüleyici (Instagram tarzı) hazır paketler vs özel yapım

### 4.5 İzinler + Harita Maliyetleri
- **İzin akışları:** Uygulama ilk açılışta hangi izinleri ne zaman istemeli (mikrofon, kamera, konum, rehber, bildirim)? iOS ve Android farkları, izin reddedilirse ne yapılmalı, App Store/Play Store'un izin gerekçesi zorunlulukları, en iyi UX pratiği (hepsini başta isteme vs özellik kullanılırken isteme)
- **Google Maps maliyet dökümü (2026 güncel):** Flutter'da haritada pin gösterme (Maps SDK for Android/iOS) ücretsiz mi ve limiti ne? Mesajda konum gönderince statik harita önizlemesi (Static Maps API) fiyatı? Adres arama (Geocoding) fiyatı? Aylık ücretsiz kotalar tam olarak ne kadar, 50K kullanıcıda aylık harita maliyeti tahmini
- **Ücretsiz alternatifler:** OpenStreetMap (flutter_map paketi) Google Maps yerine kullanılabilir mi — kalite/maliyet karşılaştırması, konum pin gönderme senaryosunda tamamen bedava çözüm mümkün mü

### 5. CI/CD + Test Dağıtımı
- Codemagic ücretsiz katmanla Flutter build + Firebase App Distribution / TestFlight dağıtımı kurulumu
- Alternatifler: GitHub Actions ile ücretsiz Android build mümkün mü, iOS için Mac zorunluluğu

### 6. Maliyet Projeksiyonu
- 1K / 10K / 50K kullanıcı senaryolarında aylık toplam maliyet tablosu (sunucu, SMS, medya, IAP komisyonları düşülmüş hediye geliri)

## Rapor Formatı
- Her bölüm için: net öneri + alternatifler + tuzaklar/riskler + kaynaklı kanıt
- Türkçe, tablolarla
- Kritik kararlar için "bunu seç, çünkü..." netliğinde sonuç
