# Gebzem — Kesin Özellik Listesi ve Ekran Haritası

> **MVP** = ilk sürümde şart ("kullanıcı bulamayınca siler" kriteri) · **V2** = ikinci dalga · **V3** = lüks
> Kaynak: kullanıcı istekleri + araştırma raporu (WhatsApp/Telegram/TikTok Live/Spaces envanteri)

## 1️⃣ GİRİŞ & HESAP
| Özellik | Öncelik |
|---|---|
| Telefon + şifre ile kayıt, OTP doğrulama | **MVP** |
| Giriş (telefon + şifre) | **MVP** |
| Şifremi unuttum → OTP ile şifre yenileme | **MVP** |
| Profil kurulumu (isim, fotoğraf, hakkımda) | **MVP** |
| Rehber eşleştirme (kimler uygulamada) | **MVP** |
| Çoklu cihaz desteği | V3 |

## 2️⃣ MESAJLAŞMA (ana sekme)
| Özellik | Öncelik |
|---|---|
| 1:1 sohbet — metin, emoji | **MVP** |
| Tik sistemi: iletildi ✓ / okundu ✓✓ (mavi) | **MVP** |
| Fotoğraf, video, sesli mesaj gönderme | **MVP** |
| Konum gönderme (Google Maps pin, bedava SDK) | **MVP** |
| "Yazıyor..." + çevrimiçi/son görülme | **MVP** |
| Yanıtlama/alıntı | **MVP** |
| Mesaj silme (benden / herkesten) | **MVP** |
| Sohbet listesi: sabitleme, arşivleme, sessize alma, okunmadı işareti | **MVP** |
| Sohbette ve tüm mesajlarda arama | **MVP** |
| Engelleme | **MVP** |
| Emoji tepkileri (mesaja basılı tut) | **MVP** |
| Mesaj iletme | **MVP** |
| Medya galerisi (sohbet başına) | V2 |
| Yıldızlı/favori mesajlar | V2 |
| Kaybolan mesajlar (süreli) | V2 |
| Anketler, @bahsetme | V2 |
| Mesaj düzenleme (Telegram tarzı) | V2 |
| E2E şifreleme (Signal protokolü) | V3 |

## 3️⃣ GRUPLAR & KANALLAR (Telegram modeli: tek altyapı)
| Özellik | Öncelik |
|---|---|
| Grup kurma, üye ekleme/çıkarma (256 üye) | **MVP** |
| Grup yönetici yetkileri (sil, sustur, at) | **MVP** |
| Grup davet linki | **MVP** |
| Kanallar (tek yönlü yayın, sınırsız abone) | V2 |
| Kanal gönderi istatistikleri (görüntülenme) | V2 |
| Süper grup (200K üye) | V3 |

## 4️⃣ STORY / DURUM
| Özellik | Öncelik |
|---|---|
| Fotoğraf/video/yazı story, 24 saatte silinir | **MVP** |
| Kim görüntüledi listesi | **MVP** |
| Story gizlilik ayarları (kimler görsün) | **MVP** |
| Story'ye yanıt (DM düşer) | V2 |

## 5️⃣ ARAMALAR (sesli + görüntülü)
| Özellik | Öncelik |
|---|---|
| 1:1 sesli/görüntülü arama (LiveKit) | **MVP** |
| Gerçek arama deneyimi: CallKit/ConnectionService (kilit ekranında çalar, GSM araması gelince beklet/reddet) | **MVP** |
| Zayıf bağlantıda otomatik kalite düşürme + kopunca otomatik yeniden bağlanma | **MVP** (LiveKit hazır veriyor) |
| Mikrofon/kamera/hoparlör kontrolleri | **MVP** |
| Arama geçmişi + cevapsız arama bildirimi | **MVP** |
| Grup araması (32 kişiye kadar, grid + konuşanı büyütme) | **MVP** |
| Aramaya kişi ekleme | V2 |
| PiP (küçük pencere) | V2 |
| Ekran paylaşımı | V3 |

## 6️⃣ SESLİ ODALAR (Spaces tarzı — alt menüde)
| Özellik | Öncelik |
|---|---|
| Oda kurma: başlık + kategori (Sağlık, Spor, Sohbet...) | **MVP** |
| Roller: host / konuşmacı / dinleyici | **MVP** |
| El kaldırma → host onayıyla konuşmacı olma | **MVP** |
| Dinleyici listesi + sayısı | **MVP** |
| Host yetkileri: sustur, konuşmacılıktan indir, at | **MVP** |
| Oda planlama (ileri tarihli) | V2 |
| Oda kaydı | V3 |

## 7️⃣ CANLI YAYIN (TikTok tarzı — alt menüde)
| Özellik | Öncelik |
|---|---|
| Yayın açma (kamera, başlık) | **MVP** |
| Yayına katılma + izleyici sayısı | **MVP** |
| Canlı yorum akışı (LiveKit text stream) | **MVP** |
| Hediye gönderme + ekranda animasyon | **MVP** |
| Jeton bakiyesi (prototipte bedava: kayıt bonusu + admin yükleme) | **MVP** |
| Yayıncı hediye kazanç sayacı (ledger) | **MVP** |
| Sabitli yorum, moderatör atama | V2 |
| Hediye leaderboard (en çok gönderenler) | V2 |
| Jeton satın alma (Play/App Store IAP) | V2 (yasal çerçeve raporda hazır) |
| Yayıncıya para ödeme (İyzico/banka) | V3 |
| PK/karşılaşma modu, yayıncı seviyesi | V3 |

## 8️⃣ PROFİL & AYARLAR
| Özellik | Öncelik |
|---|---|
| Profil düzenleme (foto, isim, hakkımda) | **MVP** |
| Telefon/kişisel bilgi değiştirme (OTP'li) | **MVP** |
| Şifre değiştirme | **MVP** |
| Gizlilik: son görülme, profil foto, story kimlere | **MVP** |
| Engellenenler listesi | **MVP** |
| Karanlık mod (dark/light/sistem) | **MVP** |
| Bildirim ayarları | **MVP** |
| Jeton bakiyem + hediye geçmişim | **MVP** |
| Hesap silme (mağaza zorunluluğu) | **MVP** |

## 9️⃣ ADMİN PANELİ (React — admin.gebzem.app)
| Özellik | Öncelik |
|---|---|
| Panel: kullanıcı sayısı, aktif arama/yayın/oda istatistikleri | **MVP** |
| Kullanıcı yönetimi: ara, engelle/yasakla, jeton yükle | **MVP** |
| Canlı izleme: kim kiminle görüşüyor (meta veri — içerik DEĞİL), aktif yayınlar/odalar | **MVP** |
| Yayın/oda acil kapatma (4 saat kuralı → tek tık kaldırma) | **MVP** |
| Şikayet (report) kutusu + işlem | **MVP** |
| Toplu duyuru push'u | V2 |
| NSFW otomatik tespit (Sightengine vb.) | V2 |
| Doğrulama rozeti verme | V2 |

## 📱 ALT MENÜ (5 sekme)
**Sohbetler** · **Aramalar** · **Odalar** · **Canlı** · **Profil** — Story çubuğu Sohbetler'in üstünde (WhatsApp tarzı)

## 🔐 İZİN AKIŞI (araştırma + mağaza kuralları)
Açılışta SADECE bildirim izni → rehber izni "kişiler" ilk açılınca → mikrofon/kamera ilk arama/yayında → konum ilk konum gönderiminde. (Hepsini başta istemek = mağaza reddi riski + kullanıcı kaçırır)

## 🔨 YAPIM FAZLARI
1. **Faz 1:** Giriş/OTP + 1:1 mesajlaşma + rehber + push → *çalışan ilk sürüm*
2. **Faz 2:** Gruplar + story + profil/ayarlar
3. **Faz 3:** Aramalar (1:1 + grup, CallKit)
4. **Faz 4:** Sesli odalar + canlı yayın + jeton/hediye
5. **Faz 5:** Admin paneli + BTK bildirimi + test dağıtımı (Codemagic)
