# WhatsApp "Ekle" (attach) menüsü — tam envanter ve ürün davranışı

## 0. Doğrulanmış zemin (kaynaktan okundu)

| İddia | Durum | Kanıt |
|---|---|---|
| Mesaj tipi beyaz listesi var | DOĞRU | `backend/internal/chat/handler.go:152-157` → `"text","image","video","audio","location"`; `'system'` bilerek dışarıda (satır 145-151) |
| DB şeması medyaya kısmen hazır | DOĞRU | `backend/internal/database/migrations/001_init.sql:55-60` → `type CHECK(text,image,video,audio,location,system)`, `content`, `media_url`, `reply_to_id`, `deleted_for_all` |
| Yükleme altyapısı YOK | DOĞRU | `backend/internal/` altında R2/presign/upload paketi yok; `SendMessage` `media_url`'i istemciden **doğrulamadan** alıp INSERT ediyor (`handler.go:169-171`) |
| Son migration 013 | DOĞRU | `013_call_hold.sql` — yeni migration **014**'ten devam eder |
| Flutter'da medya paketi yok | DOĞRU | `mobile/pubspec.yaml:31-77` — image_picker/file_picker/record/geolocator/google_maps_flutter/video_player/path_provider/cached_network_image **hiçbiri yok** |
| Sohbet ekranında ek butonu yok | DOĞRU | `chat_screen.dart:275-298` — sadece `TextField` + `LucideIcons.send` |
| Sohbet listesi önizlemesi medya metinlerini ZATEN yazıyor | DOĞRU | `chats_screen.dart:241-247` → "Fotoğraf" / "Video" / "Sesli mesaj" / "Konum" (ölü kod, tip hiç üretilmiyor) |
| Push önizlemesi de hazır | DOĞRU | `handler.go:197-206` — aynı 4 metin |

Yani: **veri modeli ve önizleme katmanı 4 medya tipi için hazır, taşıma katmanı sıfır.** Anket, belge, kişi kartı, etkinlik, çıkartma için ne tip ne kolon var — migration 014 gerekecek.

---

## 1. WhatsApp EKLE menüsünün tam envanteri (2026 itibarıyla)

Menüdeki sırayla (Android/iOS ufak sıra farkları var):

1. **Galeri / Fotoğraf ve video** — son çekilenler menü içinde şerit olarak gösteriliyor (2025 sonu değişikliği)
2. **Kamera** — doğrudan çekim (foto/video)
3. **Dosyalar** — eski adı "Belge"; artık ses dosyalarını da içeriyor
4. **Ses** — cihazdaki müzik/ses dosyası (Android'de ayrı, iOS'ta "Dosyalar" altında)
5. **Konum** — anlık konum + canlı konum + yer arama
6. **Kişi** — rehberden kişi kartı (vCard)
7. **Anket**
8. **Etkinlik** — önce sadece gruptaydı, artık 1:1'de de var
9. **Çıkartma** — çıkartma oluşturucu + GIF (giriş noktası klavye tarafında da var)
10. **Ödeme** — sadece Hindistan/Brezilya/Singapur gibi ülkelerde. **Türkiye'de YOK.**

Kaydedici (ses notu) menüde değil — giriş satırının sağındaki mikrofon.

---

## 2. FOTOĞRAF (galeri + kamera, çoklu seçim, altyazı)

**Gönderme akışı**
- Ek → Galeri → grid. **Çoklu seçim**: ilk dokunuş seçer, seçilenler numaralanır (1,2,3…), üst limit 30 medya/seferde.
- Seçimden sonra **her zaman** düzenleme/önizleme ekranı açılır: kırp/döndür, çizim, metin, çıkartma, filtre, **HD anahtarı**, "tek seferlik görüntüleme" anahtarı, altyazı alanı.
- Altyazı **her medyaya ayrı** yazılabilir (alt şeritte medya arasında gezinerek).
- Dokunuş sayısı: ek → galeri → seç → gönder = **4 dokunuş** (altyazısız).
- İzin: iOS'ta "Seçili fotoğraflar" (limited) desteklenmeli — tam kütüphane izni zorunlu tutulmamalı. Android 13+ `READ_MEDIA_IMAGES`, altında `READ_EXTERNAL_STORAGE`; Android 14+ "seçili medya" (Photo Picker) — Photo Picker kullanılırsa **izin hiç istenmez**, en doğrusu bu.

**Balon görünümü**
- Küçük resim balonun kendisidir: max ~%65 ekran genişliği, en-boy oranı korunur, min ~120px, max ~240px yükseklik; köşe yarıçapı balonla aynı.
- Altyazı varsa görselin ALTINDA aynı balon içinde, normal metin gibi.
- Alt sağda saat + tik; altyazısızsa saat görselin üstüne yarı saydam koyu hap içinde biner.
- İndirilmemişse: bulanık/karartılmış placeholder + ortada indirme dairesi + **boyut etiketi** ("1,2 MB").
- Yüklenirken (gönderende): görselin üstünde iptal edilebilir dairesel ilerleme (X ile iptal).
- 2+ görsel arka arkaya gönderilince **albüm** olarak gruplanır (2'li/4'lü mozaik + "+3" rozeti).

**Alıcının deneyimi**
- **Otomatik indirme kuralı**: Wi-Fi'de foto+ses otomatik, hücreselde varsayılan sadece foto (ayarlardan değiştirilebilir), dolaşımda hiçbiri.
- Dokununca tam ekran görüntüleyici: kaydırarak sohbetteki diğer medyalar arasında gezinme, çift dokunuş/pinch zoom, altta küçük resim şeridi, üstte gönderen adı + tarih, altta yıldızla/ilet/paylaş/sil.
- Aşağı sürükleyince kapanır (kaybolma animasyonu balona geri).

**Sohbet listesi önizlemesi**
- "Fotoğraf" (altyazı varsa: "Fotoğraf · altyazı metni"). Bizde `chats_screen.dart:241` zaten "Fotoğraf" yazıyor — altyazı birleştirmesi eklenmeli.
- Solunda Lucide `image` ikonu (emoji değil).

**Bildirim**
- "Ahmet: Fotoğraf". Ayarlarda medya önizleme açıksa Android'de BigPictureStyle ile küçük resim; iOS'ta Notification Service Extension ile attachment. **Tek seferlik görüntülemede önizleme ASLA gösterilmez.**

**Kenar durumlar**
- Ağ koptu: mesaj balonu "saat" tiki yerine bekleme tiki, arka planda kuyrukta; ağ gelince devam. Yükleme %0'dan değil, **resumable** (multipart) olmalı — 20 MB'lık videoyu 3 kez baştan yüklemek Türkiye hücresel ağında ciddi kayıp.
- Dosya çok büyük: WhatsApp yeniden kodlar; kodlama sonrası hâlâ büyükse "Dosya çok büyük" (medya limiti 16 MB, resmi).
- İzin reddedildi: satır içi açıklama + "Ayarları aç" düğmesi; ikinci kez reddedilirse bir daha sorma.
- Gönderim iptali: yükleme sırasında X → balon silinir, sunucuya hiçbir şey yazılmaz (bizde: `SendMessage` **yükleme tamamlandıktan sonra** çağrılmalı, önce değil).

---

## 3. KAMERA (doğrudan)

**Gönderme akışı**
- Ek → Kamera (veya giriş satırındaki kamera ikonu). Deklanşöre bas = foto, **basılı tut = video** (bırakınca durur, yukarı kaydırarak kilitle).
- Önizleme ekranı fotoğrafla aynı (düzenleme + altyazı + tek seferlik).
- Ön/arka çevirme, flaş, zoom (basılı tutarken yukarı kaydırma).

**Balon / alıcı / önizleme / bildirim:** fotoğraf veya video ile birebir aynı — kamera ayrı bir mesaj tipi DEĞİL.

**Kenar durumlar**
- Kamera izni reddi: siyah ekran yerine açıklayıcı boş durum.
- **Bizde özel risk**: `flutter_webrtc` iOS'ta **TEK paylaşılan `videoCapturer`** tutuyor (CLAUDE.md turu 50/67). Arama/yayın sürerken sohbetten kamera açmak capture oturumunu çalar. **Kural: aktif arama veya yayın varken sohbet kamerası engellenmeli** (mevcut `mesgulMu` kapısına benzer bir kapı).

---

## 4. VİDEO

**Gönderme akışı**
- Galeriden veya kameradan. Önizlemede **kırpma şeridi** (başlangıç/bitiş tutamakları, seçili aralığın süresi ve tahmini boyutu canlı yazar), sessize alma anahtarı, "GIF'e çevir" (6 sn altına kırpılırsa çıkar), altyazı, HD anahtarı, tek seferlik.
- Uzunsa: WhatsApp kesmez, sadece boyut sınırına takılırsa uyarır ve kırpmayı önerir.

**Balon görünümü**
- Kapak karesi + ortada oynat düğmesi + **sol altta süre etiketi** ("0:42") ve indirilmemişse yanında boyut ("8,4 MB").
- İndirme dairesi kapak üstünde; ilerleme yüzdesi ring olarak.
- Altyazı varsa altta.

**Alıcının deneyimi**
- Otomatik indirme: **video varsayılan olarak Wi-Fi'de bile kapalı olabilir** (WhatsApp'ta hücreselde kapalı, Wi-Fi'de açık).
- Dokununca tam ekran oynatıcı: sürükleme çubuğu, sessize alma, PiP (Android), yatay çevirme. Kısa videolar sohbet içinde sessiz otomatik oynatılabilir (WhatsApp bunu GIF'ler için yapıyor).
- İndirme bitmeden **akış (streaming) oynatma** — WhatsApp yapıyor; bizde R2 + HTTP Range ile mümkün.

**Sohbet listesi önizlemesi:** "Video" (+ altyazı). Bizde `chats_screen.dart:243` hazır.

**Bildirim:** "Ahmet: Video". Küçük resim eklenebilir (kapak karesi).

**Kenar durumlar**
- Süre/boyut: WhatsApp'ta medya sınırı **16 MB** — pratikte ~90 sn-3 dk. Dosya olarak gönderilirse **2 GB** ve sıkıştırma yok.
- Kodlama telefonu ısıtır; Android'de bazı cihazlarda H.264 donanım kodlayıcı yok → yazılım kodlama = çok yavaş. **Zaman aşımı + "orijinal gönder" kaçış yolu şart.**
- Ağ koptu: parçalı yükleme devam eder.

---

## 5. BELGE / DOSYA (pdf, doc, xls, zip, apk…)

**Gönderme akışı**
- Ek → Dosyalar → sistem dosya seçici (Android SAF / iOS Files). **İzin gerekmez** (sistem seçici kendi izin modelini kullanır) — bu, izin yorgunluğunu azaltmanın en kolay yeri.
- Seçimden sonra kısa bir onay ekranı: dosya adı, boyut, ikon + "Altyazı ekle" + gönder. Çoklu seçim var (bir seferde birden fazla dosya).
- Fotoğrafı **belge olarak** gönderme yolu da var (sıkıştırmasız) — Türkiye'de "kaliteli göndersene" ihtiyacının cevabı budur.

**Balon görünümü**
- Yatay kart: solda dosya türü ikonu (Lucide `fileText` / `fileSpreadsheet` / `fileArchive` / `file`), sağında **dosya adı (2 satıra kadar, ortadan kısaltma: "sozlesme_2026_final...pdf")**, altında "12 sayfa · PDF · 2,4 MB" satırı.
- PDF'lerde WhatsApp **ilk sayfanın küçük görselini** de gösteriyor (dokümanın kapağı).
- İndirilmemişse sağda indirme oku; indiriliyorsa ring + iptal.

**Alıcının deneyimi**
- **Belgeler asla otomatik indirilmez** (varsayılan). Kullanıcı dokunur → indirir → açar.
- Dokununca: PDF ise uygulama içi görüntüleyici (WhatsApp kendi PDF görüntüleyicisini kullanıyor), diğerlerinde sistem "birlikte aç".
- Uzun basma: ilet, yıldızla, paylaş, kaydet.

**Sohbet listesi önizlemesi:** dosya adı (ikon + "sozlesme.pdf").

**Bildirim:** "Ahmet: sozlesme.pdf".

**Kenar durumlar**
- Limit **2 GB** (resmi). Bizim için bu delilik: R2'de saklama + cx33'ün 80 GB diski. **Önerilen ürün limiti: 100 MB** (aşağıda gerekçe).
- Tehlikeli uzantı: WhatsApp `.apk`'yı gönderir ama alıcıda "bilinmeyen kaynak" uyarısı sistemden gelir. Bizde **beyaz liste değil kara liste** yeterli; ama `.apk`, `.exe`, `.scr`, `.bat` için "Bu dosya türü zararlı olabilir" uyarı balonu iyi olur.
- Depolama dolu: "Cihazda yeterli alan yok".
- **Güvenlik notu (bizim için kritik)**: dosya adı alıcıda çizilirken **HTML/RTL kaçışı** yapılmalı. `fatura‮gpj.exe` gibi RTL override saldırısı klasiktir.

---

## 6. SES NOTU (basılı tut, kaydırarak iptal, dalga formu)

**Gönderme akışı**
- Mikrofonu **basılı tut** → kayıt başlar (titreşim geri bildirimi), üstte kırmızı nokta + sayaç + canlı dalga formu.
- **Sola kaydır = iptal** ("İptal etmek için kaydırın" yazısı ve çöp ikonu).
- **Yukarı kaydır = kilitle** → eller serbest kayıt; artık "Durdur" ve "Gönder" düğmeleri var, ayrıca **duraklat/devam** ve gönderim öncesi **dinleme**.
- Bırakınca doğrudan gönderilir (kilitsiz modda önizleme YOK — bu kasıtlı, hız için).
- İzin: mikrofon. Bizde zaten `permission_handler` var.

**Balon görünümü**
- Solda gönderenin yuvarlak avatarı (üstünde küçük mikrofon rozeti — dinlenmemişse **mavi/yeşil**, dinlenmişse gri).
- Oynat/duraklat düğmesi + **dalga formu çubukları** (kaydedilen gerçek genlikten türetilmiş, ~40-60 çubuk) + süre.
- Oynarken çubuklar soldan sağa dolar, sürüklenebilir (scrubbing).
- Sağda **hız rozeti**: dokunarak 1x → 1.5x → 2x döngüsü (perde bozulmadan).
- Yarım dinlenip çıkılırsa **kaldığı yerden** devam eder.

**Alıcının deneyimi**
- Otomatik indirme: ses **varsayılan olarak indirilir** (küçük).
- Sohbetten çıkınca oynatma **devam eder** — üstte kalıcı bir oynatıcı şeridi belirir (WhatsApp bunu yapıyor, çok sevilen davranış).
- Arka arkaya ses notları **otomatik zincir** halinde çalar.
- Kulaklık takılıysa/telefon kulağa götürülünce ahize hoparlörüne geçer (yakınlık sensörü). **Bizde yakınlık sensörü yok** (CLAUDE.md notu) — bu davranış atlanmalı veya paket eklenmeli.

**Sohbet listesi önizlemesi:** "Sesli mesaj" (+ süre: "Sesli mesaj (0:14)"). Bizde `chats_screen.dart:245` hazır.

**Bildirim:** "Ahmet: Sesli mesaj".

**Kenar durumlar**
- **Aktif arama/yayın varken kayıt YASAK** — ses birimi çakışır. Bizde `ActiveCallController` ve oda/yayın muhafızları var; aynı kapıdan geçmeli. (CLAUDE.md'deki "iOS ses birimi" hükmü: `AVAudioSession` kategorisi araması sürerken değiştirilirse arama sesi ölür.)
- Çok kısa kayıt (<1 sn): gönderilmez, "Basılı tutun" uyarısı.
- Kayıt sırasında telefon çalarsa: kayıt otomatik durur ve **taslak olarak saklanır**, atılmaz.
- Ağ koptu: dosya yerelde durur, kuyruğa alınır.

---

## 7. KONUM (anlık + canlı + yer arama)

**Gönderme akışı**
- Ek → Konum → harita açılır, konum izni istenir.
- Üç seçenek: **"Mevcut konumu gönder"**, **"Canlı konumu paylaş"**, aşağıda **yakındaki yerler listesi** (Foursquare/Meta yer veritabanı) + arama çubuğu.
- Canlı konum seçilince süre sorulur: **15 dakika / 1 saat / 8 saat** + isteğe bağlı not.
- Haritayı sürükleyerek farklı bir nokta seçilebilir ("Bu konumu gönder").

**Balon görünümü**
- **Anlık konum**: küçük harita görseli (~250x150) + iğne; altında yer adı/adres varsa yazar.
- **Canlı konum**: aynı harita ama üstte canlı sayaç ve "Canlı konum · 42 dakika kaldı" satırı, altında **"Paylaşımı durdur"** düğmesi (gönderen tarafında). Balon içindeki harita periyodik olarak güncellenir.
- Süre dolunca balon soluklaşır: "Canlı konum sona erdi".

**Alıcının deneyimi**
- Dokununca tam ekran harita: iğne, "Yol tarifi al" (harita uygulamasına devreder), paylaş.
- Canlı konumda: karşı tarafın avatarı harita üstünde hareket eder, "son güncelleme 12 sn önce"; grupta birden fazla kişi paylaşıyorsa hepsi aynı haritada.
- Sohbetin en üstünde kalıcı şerit: "2 kişi canlı konum paylaşıyor".

**Sohbet listesi önizlemesi:** "Konum" / "Canlı konum". Bizde `chats_screen.dart:247` "Konum" hazır.

**Bildirim:** "Ahmet: Konum".

**Kenar durumlar**
- İzin reddi: "Konum izni gerekli" + Ayarlar.
- **Yalnızca yaklaşık konum** (Android 12+ "Approximate"): WhatsApp yine gönderir ama düşük doğrulukla; uyarı gösterilmeli.
- Canlı konum + arka plan: Android'de **ön plan servisi** (`location` tipi) şart, yoksa 10 sn sonra donar. Bizde zaten `AramaServisi.kt` ön plan servisi deseni var — aynı desen.
- Pil: 8 saatlik canlı konum agresif GPS'le pili bitirir → hareketsizken güncelleme aralığı uzatılmalı.
- **Maliyet tuzağı (bizim için)**: `google_maps_flutter` ücretsiz kalmalı → `cloudMapId` KULLANMA (CLAUDE.md kuralı). Balon içindeki küçük harita için **Static Maps API ücretlidir**; bunun yerine `google_maps_flutter`'ın **lite mode**'u (Android) veya tek seferlik snapshot kullanılmalı. OSM Foundation'ın bedava tile sunucusu **yasak** (kullanım politikası).

---

## 8. KİŞİ KARTI (contact)

**Gönderme akışı**
- Ek → Kişi → rehber listesi (çoklu seçim var, en fazla ~10). Rehber izni gerekir.
- Seçtikten sonra **hangi alanların paylaşılacağı** sorulur (birden fazla telefon numarası varsa hepsi ya da seçili olanlar).

**Balon görünümü**
- Kart: solda avatar/baş harf dairesi, sağda **ad** + "Kişi"; altında **tam genişlikte "Mesaj gönder" düğmesi** (kişi uygulamada kayıtlıysa) veya "Rehbere ekle".
- Birden fazla kişi tek mesajda gönderilirse: "Ahmet Yılmaz ve 3 kişi".

**Alıcının deneyimi**
- Dokununca kişi detay sayfası: numaralar, e-posta; "Yeni kişi oluştur", "Mevcut kişiye ekle", "Mesaj gönder", "Ara".
- Rehbere eklemeden de mesaj/arama başlatılabilir.

**Sohbet listesi önizlemesi:** "Kişi: Ahmet Yılmaz"

**Bildirim:** "Ahmet: Kişi"

**Kenar durumlar**
- Rehber izni reddi: uygulama içi kullanıcı arama ekranına düş (bizde `user_search_screen.dart` zaten var — **rehber izni hiç istemeden** kişi kartı gönderilebilir, bu daha temiz).
- **KVKK notu**: rehber yükleme (contact upload) Türkiye'de riskli; WhatsApp bunu yapıyor ama biz **rehberi sunucuya yüklemeden** yalnız seçilen kişiyi göndermeliyiz.

---

## 9. ANKET (poll)

**Gönderme akışı**
- Ek → Anket → soru alanı + seçenek alanları. **2-12 seçenek** (WhatsApp limiti).
- Anahtar: **"Birden fazla yanıta izin ver"** (varsayılan açık).
- Gönder.

**Balon görünümü**
- Üstte "Anket" etiketi + soru (kalın).
- Her seçenek: yuvarlak (tekli) veya kare (çoklu) kutu + metin + **arka planda dolan yüzde çubuğu** + sağda oy sayısı.
- Altta: "Oyları gör" (dokununca kim ne oy vermiş — anketler **anonim değildir**).
- Toplam oy sayısı ("12 oy").
- Sonuçlar **canlı** güncellenir.

**Alıcının deneyimi**
- Seçeneğe dokunmak oy verir; **oy değiştirilebilir** (tekrar dokunmak geri alır).
- Çoklu seçimde birden fazla işaretlenebilir.
- Oy verdikten sonra sonuçlar görünür (WhatsApp oy vermeden de gösteriyor).
- Anket sahibi anketi **sonlandırabilir** (yeni oy kabul edilmez, sonuç donar).
- Yeni oy geldiğinde bildirim: "Ahmet ankette oy verdi" (grupta kapatılabilir).

**Sohbet listesi önizlemesi:** "Anket: Bu akşam nerede buluşalım?"

**Bildirim:** "Ahmet: Anket · Bu akşam nerede buluşalım?"

**Kenar durumlar**
- Ağ koptu: oy yerelde işaretlenir, "gönderiliyor" durumu; senkronda **sunucu otoritedir** (çakışmada sunucu kazanır).
- Aynı anda iki cihazdan oy: sunucuda `(poll_id, option_id, user_id)` UNIQUE ile idempotent.
- Anket silinince oylar da gider.
- **Bizim için**: yeni tablo gerekir (`polls`, `poll_options`, `poll_votes`) + WS olayı `poll.vote`. Mesaj tipi `poll`, `content` = poll_id.

---

## 10. ÇIKARTMA (sticker) ve GIF

**Gönderme akışı**
- Klavye üstündeki çıkartma sekmesi (ek menüsünde de giriş var). Sekmeler: Yakın kullanılanlar, favoriler, indirilen paketler, **çıkartma mağazası**, **GIF (Giphy/Tenor arama)**, **avatar çıkartmaları**.
- **Çıkartma oluşturucu**: galeriden foto seç → arka planı otomatik kaldır → kırp → kaydet (WhatsApp 2023'ten beri yapıyor).
- **Metin çıkartması** (2026 Ocak'ta geldi).
- Tek dokunuşla gönderilir — **önizleme/onay adımı YOK**.

**Balon görünümü**
- Baloncuk **yok**: şeffaf zeminde ~120x120 çıkartma; saat/tik alt sağda küçük ve gölgeli.
- Animasyonlu çıkartmalar (WebP animasyonlu) döngüde oynar.
- GIF: baloncuk içinde, otomatik oynar, sol altta "GIF" etiketi.

**Alıcının deneyimi**
- Dokununca büyütmez; uzun basınca "Favorilere ekle", "Paketi gör", "İlet".
- Aynı çıkartma arka arkaya gelirse animasyon senkronlanır.

**Sohbet listesi önizlemesi:** "Çıkartma" (WhatsApp çıkartmanın emojisini de yazar — **bizde emoji yasak**, sadece "Çıkartma" + Lucide `sticker` ikonu).

**Bildirim:** "Ahmet: Çıkartma"

**Kenar durumlar**
- GIF araması harici servise bağımlı (Giphy/Tenor API anahtarı, kota, içerik filtreleme). Türkiye'de uygunsuz içerik filtresi **zorunlu** sayılmalı (5651).
- Çıkartma paketleri depolamada büyür; "Depolamayı yönet" ekranı gerekir.

---

## 11. ETKİNLİK (event)

**Gönderme akışı**
- Ek → Etkinlik → ad, tarih/saat, **bitiş tarihi**, konum (veya "Görüntülü arama" bağlantısı), açıklama, "+1 davet edilebilir" anahtarı, hatırlatıcı.
- Hem grupta hem 1:1'de.

**Balon görünümü**
- Takvim kartı: gün/ay bloğu + başlık + saat + konum satırı; altta **Katılıyorum / Belki / Katılmıyorum** üç düğmesi; altında katılanların avatar yığını ("5 kişi katılıyor").
- Sohbete **sabitlenebilir**.

**Alıcının deneyimi**
- RSVP dokunuşu anında; değiştirilebilir.
- "Takvime ekle" ile sistem takvimine.
- Etkinlik saatinden önce **hatırlatma bildirimi**.

**Sohbet listesi önizlemesi:** "Etkinlik: Kahvaltı"

**Bildirim:** "Ahmet: Etkinlik · Kahvaltı, 12 Ağu 10:00"

**Kenar durumlar**
- Saat dilimi: **her zaman UTC sakla, yerelde göster**. Türkiye TSİ (UTC+3), yaz saati yok — kolay ama sunucuda UTC şart.
- Geçmiş etkinlik: kart soluklaşır, RSVP kapanır.

---

## 12. ÖDEME — **BİZDE YOK, ATLANIYOR**

WhatsApp Pay yalnız Hindistan, Brezilya, Singapur gibi belirli pazarlarda. **Türkiye'de yok.**
Bizde de olmayacak — CLAUDE.md kuralı: prototipte ödeme yok, jeton bedava; ayrıca 6493 sayılı kanun gereği ödeme/e-para faaliyeti **asla kendi bünyede** yapılamaz (lisans şartı). Bu satır bir uyarı olarak kalsın: ileride hediye jetonu satılacaksa yol **IAP (App Store/Play)** veya lisanslı bir ödeme kuruluşudur (İyzico vb.), kendi cüzdanımız değil.

---

## 13. Sohbet içi destekleyici özellikler

### Yanıtlama (reply / alıntı)
- Mesajı sağa kaydır (veya uzun bas → Yanıtla) → giriş satırının üstünde alıntı şeridi (gönderen adı renkli + içerik özeti + medya küçük resmi).
- Balonda: üstte renkli dikey çizgili alıntı bloğu; **dokununca orijinal mesaja atlar ve o mesaj kısa süre vurgulanır**.
- Bizde `reply_to_id` kolonu ve `models.dart:59,70,81` alanı **zaten var**, sadece UI yok. En ucuz kazanç budur.

### İletme (forward)
- Uzun bas → İlet → sohbet seçici (çoklu, en fazla 5 sohbet).
- Balonda **"İletildi"** etiketi; çok iletilmişse **"Çokça iletildi"** ve o mesaj tek seferde yalnız 1 sohbete iletilebilir (dezenformasyon freni).
- Türkiye için bu fren **önemli** — zincir mesaj kültürü güçlü.

### Tek seferlik görüntüleme (view once)
- Gönderirken önizlemede "1" rozetli anahtar. Foto, video ve **sesli mesaj** için.
- Balon: içerik yok, sadece "Fotoğraf · Tek seferlik" + açılınca "Açıldı" durumu.
- Açıldıktan sonra kalıcı silinir; **ekran görüntüsü engellenir** (Android FLAG_SECURE; iOS'ta engellenemez, sadece bildirilir).
- İletme/yıldızlama/kaydetme kapalı.

### Süresi dolan mesajlar (disappearing)
- Sohbet ayarı: **24 saat / 7 gün / 90 gün** + kapalı. Varsayılan tüm yeni 1:1 sohbetler için ayarlanabilir.
- Sayaç **okunmaya değil saate** bağlıdır (gönderim anından itibaren).
- Sohbet başlığında küçük saat ikonu; açılışta sistem mesajı.
- **Kaçaklar (dürüst not)**: alıntılanan parça, bildirim önizlemesi ve iletilen kopya kaybolmaz.

### Yıldızlama
- Uzun bas → Yıldız. Balonda küçük yıldız işareti. "Yıldızlı mesajlar" ekranı (ayarlar veya sohbet menüsü).

### Mesaj silme
- **Bende sil**: yalnız kendi cihazından; balon gider (diğer taraf görmeye devam eder).
- **Herkesten sil**: gönderimden sonra belirli süre içinde; her iki tarafta balon **"Bu mesaj silindi"** metnine döner (silinmiş olduğu görünür kalır — kanıt bırakır, bu bilinçli bir tasarım).
- Bizde `deleted_for_all` kolonu ve `handler.go:236-238` maskeleme **zaten var** — API ucu yok.

### Düzenleme (edit)
- Gönderimden sonra 15 dakika içinde; balonda "düzenlendi" etiketi. Medya düzenlenemez, sadece metin/altyazı.

### Tepkiler (reaction)
- Uzun bas → emoji çubuğu. **Bizde emoji yasağı arayüz ikonları içindir**; tepkiler ürün içeriğidir, ama tutarlılık için ya Lucide tabanlı sınırlı bir tepki seti (beğen/kalp/gülümse) ya da bilinçli bir emoji istisnası kararı gerekir. **Bu bir ürün kararı, kullanıcıya sorulmalı** (hediye simgelerinde aynı soru zaten bekliyor — CLAUDE.md turu 62).

### Medya galerisi (sohbetteki tüm medya)
- Sohbet bilgisi → "Medya, bağlantılar ve belgeler": üç sekme (Medya grid / Bağlantılar / Belgeler), tarihe göre gruplu.
- Buradan **toplu seçip silme/iletme/kaydetme**.
- Depolama yönetimi: "En büyük dosyalar", "Birden fazla kez iletilenler" — yer açma ekranı.

### Sabitleme (pin)
- Mesaj sohbetin üstüne sabitlenir (24 saat / 7 gün / 30 gün). Etkinlik ve anket için özellikle kullanışlı.

---

## 14. ÖNCELİKLENDİRME

Gerekçe zemini: tek makine (Hetzner cx33, 4 vCPU / 8 GB / 80 GB disk, LiveKit de aynı makinede), Cloudflare R2 (**egress ücreti yok** — medya dağıtımı için büyük avantaj, video/foto trafiği bant genişliği faturası üretmez), Flutter tarafında medya paketi sıfır, backend'de upload katmanı sıfır.

### MVP (1. dalga) — "olmadan mesajlaşma uygulaması sayılmaz"

| Özellik | Gerekçe |
|---|---|
| **Yükleme altyapısı (R2 presigned PUT + `media` tablosu + migration 014)** | Diğer her şeyin ön koşulu. **API sunucusundan dosya geçirilmemeli** — cx33'te 4 vCPU'yu LiveKit ile paylaşıyoruz; istemci doğrudan R2'ye yüklemeli, backend yalnız imzalı URL üretmeli. `media_url` şu an **doğrulanmıyor** (`handler.go:171`) — bu bir açık: istemci istediği URL'i yazabiliyor. Presign akışıyla birlikte sunucu tarafı doğrulama zorunlu. |
| **Fotoğraf** (galeri çoklu + kamera + altyazı) | En çok kullanılan ek. Beyaz liste ve önizleme metni zaten hazır. |
| **Sesli mesaj** | Türkiye'de yazmaktan çok kullanılıyor (özellikle 35+ yaş ve düşük yazma hızı olan kullanıcılar). Teknik olarak da en ucuzu: küçük dosya, sıkıştırma derdi yok. Bizde `audioplayers` ve `permission_handler` zaten var, sadece `record` paketi eklenecek. |
| **Video** (temel: seç, sıkıştır, gönder, akışla oynat) | Fotoğraftan sonra ikinci. Kırpma 2. dalgaya bırakılabilir. |
| **Belge/Dosya** | Sistem seçici kullandığı için **izin gerektirmez** = en ucuz özellik. İş/aile grubu kullanımının belkemiği. |
| **Yanıtlama (reply)** | Kolon ve model alanı **zaten var**, sadece UI. Maliyeti neredeyse sıfır, algılanan değeri çok yüksek. |
| **Mesaj silme (bende/herkeste)** | `deleted_for_all` zaten var. Ayrıca **5651 kapsamında "4 saat içinde içerik kaldırma" yükümlülüğünün kullanıcı tarafındaki karşılığı**; yayına çıkmadan önce olmalı. |
| **Otomatik indirme ayarları** (Wi-Fi/hücresel/dolaşım) | Türkiye'de hücresel veri paketleri sınırlı; varsayılan "hücreselde video indirme" olursa kullanıcı uygulamayı siler. MVP'de olmalı. |

### 2. DALGA — "rakip gibi hissettiren"

| Özellik | Gerekçe |
|---|---|
| **Konum (anlık)** | Yüksek kullanım, orta maliyet (`google_maps_flutter` + `geolocator`, harita SDK'sı APK'yı ~3-5 MB büyütür — TAHMİN). |
| **Anket** | Türkiye'de grup lojistiğinin (buluşma yeri, saat, sipariş) fiili aracı. Yeni tablo + WS olayı gerektirir, o yüzden MVP değil. Medyaya ihtiyaç duymaz — istenirse MVP'ye alınabilir, çünkü R2'yi beklemez. |
| **İletme (forward)** + "İletildi" etiketi + iletme limiti | Zincir mesaj kültürü nedeniyle Türkiye'de **hem çok kullanılır hem de fren gerekir**. |
| **Medya galerisi** (sohbetteki tüm medya) | Medya geldikten sonra kaçınılmaz olarak istenir; depolama yönetimiyle birlikte gelmeli. |
| **Video kırpma + HD anahtarı** | Kaliteye duyarlı kullanıcı için; sıkıştırma politikasını kullanıcıya açar. |
| **Tek seferlik görüntüleme** | Gizlilik pazarlaması için güçlü, teknik olarak orta (FLAG_SECURE + sunucuda tek okuma sayacı). |
| **Kişi kartı** | Rehber izni istemeden, **uygulama içi kullanıcı arama** üzerinden yapılırsa KVKK riski sıfır ve maliyeti düşük. |
| **Yıldızlama** | Ucuz, beklenen. |

### SONRA (3. dalga)

| Özellik | Gerekçe |
|---|---|
| **Canlı konum** | Ön plan servisi + pil optimizasyonu + arka plan konum izni (Play Store'da **ayrı gerekçe formu** ister, inceleme süresini uzatır). Değer/maliyet oranı düşük başlangıçta. |
| **Süresi dolan mesajlar** | Sunucu tarafında planlı silme işi (cron + R2 nesne silme) gerektirir; medya yaşam döngüsü oturmadan yapılmamalı. |
| **Etkinlik** | Güzel ama Türkiye'de WhatsApp'ta bile kullanımı düşük — grup lojistiği anketle çözülüyor. |
| **Çıkartma / GIF** | Çıkartma **kültürel olarak Türkiye'de çok kullanılıyor** (TAHMİN — sert veri bulamadım) ama: harici GIF servisi bağımlılığı, içerik filtreleme yükümlülüğü, çıkartma mağazası altyapısı. Ürün olgunlaşmadan girilmemeli. Ara çözüm: yalnız **kullanıcının kendi oluşturduğu çıkartma** (arka plan kaldırma), mağaza yok. |
| **Düzenleme (edit)** | Ucuz ama beklenti yaratmıyor. |
| **Tepkiler** | Emoji politikası kararı bekliyor. |
| **Ödeme** | **Yapılmayacak.** (Yukarıdaki 12. madde.) |

---

## 15. Türkiye pazarı: gerçekten kullanılan vs. süs

**Gerçekten kullanılan**
- **Sesli mesaj** — en güçlüsü. WhatsApp Türkiye'de internet kullanıcılarının %90'ında ([TÜİK 2026 verisi](https://www.gazete32.com.tr/isparta/tuik-arastirmasi-internet-kullanimi-%923e-yukseldi-her-10-kisiden-9u-whatsapp-kullaniyor/)); sesli mesajın Türkiye'deki payına dair resmi veri **bulamadım** — bu bir gözlem/TAHMİN, ama ürün kararını değiştirecek kadar güçlü bir gözlem.
- **Fotoğraf** — mutlak birinci.
- **Belge** — iş/veli/apartman grupları; PDF fatura, dekont, ders notu.
- **Anket** — grup buluşması, sipariş toplama.
- **Anlık konum** — buluşma tarifi ("iğneyi at").
- **Yanıtlama + iletme** — kalabalık gruplarda zorunlu.
- **Çıkartma** — sohbet kültürünün parçası (TAHMİN, sert veri yok).

**Süs / düşük getiri**
- **Etkinlik** — takvim kullanımı zayıf, anket ikame ediyor.
- **Canlı konum** — kullanılıyor ama dar (aile takibi, kurye); maliyeti değerinden yüksek.
- **Süresi dolan mesajlar** — gizlilik hassasiyeti yüksek bir azınlık kullanıyor.
- **Kişi kartı** — numara paylaşımı çoğu zaman düz metinle yapılıyor.
- **GIF** — Instagram/TikTok kuşağında var, WhatsApp'ta orta.
- **Ödeme** — Türkiye'de mevcut değil, konu dışı.

---

## 16. Bilmediklerim / dürüst notlar

- **Sesli mesajın Türkiye'deki kullanım oranına dair sayısal kaynak bulamadım.** Yukarıdaki sıralama gözleme dayanıyor, TAHMİN olarak işaretli.
- **Medya boyut limiti çelişkili**: WhatsApp Yardım Merkezi belge limitini **2 GB** olarak veriyor; foto/video/ses için **16 MB** sınırı ayrıca geçerli. 2026 tarihli bazı ikincil kaynaklar "medya da 2 GB" diyor — bunu doğrulayamadım. **Bizim ürünümüz için önerim ayrı**: foto ~8 MB (sıkıştırma sonrası ~300 KB), video 100 MB / 5 dk, belge 100 MB. Gerekçe: cx33'ün 80 GB diski ve R2 depolama maliyeti; **R2'de egress bedava ama depolama ücretli** — 50K kullanıcı x ortalama 200 MB = 10 TB'lık bir eğilim, sınır konmazsa faturayı bu yapar.
- **APK boyutu artışı**: `google_maps_flutter` + `image_picker` + `record` + `video_player` eklendiğinde APK'nın ne kadar büyüyeceğini ölçmedim (şu an ~108 MB). TAHMİN: +5-10 MB.
- **`view once` ekran görüntüsü engelleme iOS'ta mümkün değil** — sadece "ekran görüntüsü alındı" bildirimi verilebilir; bunu kullanıcıya vaat etme.
- Anket/etkinlik/kişi kartı/çıkartma için **DB tipi yok**: `001_init.sql:55`'teki CHECK kısıtı genişletilmeli (migration 014) ve `handler.go:152`'deki beyaz liste güncellenmeli. **`'system'` beyaz listeye EKLENMEYECEK** (turu 59b kimlik taklidi açığı).
- **Yasal (yayın öncesi)**: 5651 kapsamında yer sağlayıcı bildirimi, 4 saat içinde içerik kaldırma mekanizması, trafik logu saklama; medya geldiğinde ayrıca **şikayet/kaldırma akışı** ve CSAM taraması sorumluluğu doğar. Bu, medya fazının ürün değil **hukuk** maliyetidir ve MVP planına dahil edilmeli.

---

## Kaynaklar

- [WhatsApp Help Center — How to send media](https://faq.whatsapp.com/164676891531296/?locale=en_US) (belge 2 GB, medya 16 MB)
- [WhatsApp Blog — Reactions, 2GB File Sharing, 512 Groups](https://blog.whatsapp.com/reactions-2gb-file-sharing-512-groups)
- [WhatsApp Blog — Making Voice Messages Better](https://blog.whatsapp.com/making-voice-messages-better) (dalga formu, kaydırarak iptal, hız)
- [WhatsApp Blog — Default Disappearing Messages and Multiple Durations](https://blog.whatsapp.com/more-control-and-privacy-with-default-disappearing-messages-and-multiple-durations) (24 saat / 7 gün / 90 gün)
- [WhatsApp Blog — New Feature Roundup: group chats, events, calls, channels](https://blog.whatsapp.com/new-feature-roundup-updates-to-group-chats-events-calls-channels-and-more) (etkinlik, RSVP)
- [Ubergizmo — WhatsApp Updates Attachment Menu With Faster Photo Access](https://www.ubergizmo.com/2025/12/whatsapp-faster-photo-access/) (menü içi galeri şeridi, "Belge" → "Dosyalar")
- [Green API — WhatsApp yeni özellikler, Şubat 2026](https://green-api.com/en/blog/2026/whatsapp-new-features-of-the-past-week-121225/)
- [MacRumors — WhatsApp Enhances Group Chats With Three New Features (Ocak 2026)](https://www.macrumors.com/2026/01/07/whatsapp-group-chats-three-new-features/) (metin çıkartması, etkinlik hatırlatıcı)
- [ScreenRant — WhatsApp Live Location süreleri](https://screenrant.com/whatsapp-live-location-turn-on-off-how-long-explained/) (15 dk / 1 saat / 8 saat)
- [Periskope — How to Create a Poll in WhatsApp](https://periskope.app/blog/how-to-create-a-poll-in-whatsapp) (2-12 seçenek, çoklu yanıt anahtarı)
- [TÜİK 2026 hane halkı bilişim araştırması haberi](https://www.gazete32.com.tr/isparta/tuik-arastirmasi-internet-kullanimi-%923e-yukseldi-her-10-kisiden-9u-whatsapp-kullaniyor/) (internet kullanımı %92,3; internet kullananların %90'ı WhatsApp)