# EKSİKLİK KRİTİĞİ — "NE UNUTULDU?"

Altı keşif/tasarım çıktısını kullanıcının isteğine ve mevcut koda karşı taradım. Kod iddialarını doğruladım (aşağıda dosya:satır). **Beş sevk engeli, on dört sahipsiz özellik, sekiz sessizce ertelenmiş mimari karar** buldum.

---

## 0. ÖNCE: KULLANICININ İSTEDİĞİ AMA HİÇBİR ÇIKTIDA GÖRÜNMEYEN İKİ ŞEY

### 0.1 "İndir sayfasında saati göremiyorum" — HİÇ ELE ALINMADI
**NE:** Kullanıcı isteğinde açıkça yazıyor: *"indir sitesinde saat yazmıyor göremiyorum, orada saat yazsın"*. Altı çıktının hiçbirinde `scratchpad/indir_uret.js`, indir sayfası veya saat çubuğu geçmiyor.
**NEDEN:** Bu, CLAUDE.md'de daha önce **bir kez çözülmüş** bir sorun ("body flex ortalama kaldırıldı, saat çubuğu kartın DIŞINA taşındı") — yani **regresyon** olma ihtimali yüksek ve kullanıcı aynı şikâyeti tekrar ediyor. Medya fazı aylar sürerken bu 10 dakikalık iş kaybolur.
**KİME:** Medya işinden **tamamen ayrı**, bir sonraki build'den **önce** yapılacak tek maddelik iş. `scratchpad/indir_uret.js` + CDN purge.

### 0.2 "Temiz build öncesi kapsamlı bug-fix araştırması" — HİÇ YAPILMADI
**NE:** Kullanıcı *"temiz bir build almadan önce çok kapsamlı bug fix araştırması yap"* dedi. Altı çıktının tamamı **yeni özellik tasarımı**. Mevcut kodda bilinen açık hatalar (turu 69 ölçümleri — `callkit bitir: kaynak=native/eklenti` zaman farkı, turu 67 park zinciri ölü kodu, turu 68 `hold=false` ölçümü) **okunmadı bile**.
**NEDEN:** Kullanıcı test turu 69'u test edecek durumda; medya kodu o testin sonuçlarının üstüne yazılırsa iki iş birbirine karışır ve teşhis imkânsızlaşır (CLAUDE.md'nin 70 turluk ana dersi).
**KİME:** Medya fazından **önce** ayrı bir "turu 70: ölçüm okuma + temizlik" turu. Bekleyen üç ölçüm sonucu Sentry'den okunmalı.

---

## 1. SEVK ENGELLERİ — KOD YAZILMADAN ÖNCE ÇÖZÜLMESİ ZORUNLU

### 1.1 🔴 BEŞ TASARIM DA `014` MIGRATION'INI TALEP EDİYOR ve ÜÇÜ `messages_type_check`'İ BİRBİRİNDEN HABERSİZ YENİDEN KURUYOR
**NE:**
| Tasarım | Dosya | `type` CHECK'e yazdığı küme |
|---|---|---|
| görsel-video | `014_medya.sql` | dokunmuyor |
| belge-ses | `014_medya.sql` | `…,'system','document'` |
| konum-kişi | `014_konum_kisi.sql` | `…,'location','contact','system'` |
| anket | `014_anket.sql` | `…,'location','system','poll'` |
| altyapı | `014_media.sql` | `…,'system','document'` (opsiyonel blok) |

`database.go` migration'ları **dosya adına göre sıralayıp sırayla** uygular ve `schema_migrations`'a ada göre yazar. Beş farklı ad = **beşi de uygulanır**. Her biri CHECK'i düşürüp kendi kümesiyle yeniden kuruyor → **son çalışan, diğerlerinin tipini siler.** `poll` migration'ı en son çalışırsa `document` ve `contact` mesajları **INSERT edilemez hale gelir** ve hata `SendMessage`'ın 500 dalında görünür.
**NEDEN:** Canlı DB'de sessiz veri kaybı + teşhisi çok zor bir üretim hatası. CLAUDE.md'nin "şema + deploy aynı turda riskli" uyarısının tam olarak öngördüğü durum.
**KİME:** **Tek bir 014** yazılacak; tüm yeni tipler (`document`, `contact`, `poll`) **tek CHECK ifadesinde** birleşecek ve o tipin arayüzü henüz yoksa bile CHECK'e girecek. Migration sahibi tek bir ajan/tur olmalı; diğerleri 015, 016… alacak ve **CHECK'e bir daha dokunmayacak**.

### 1.2 🔴 PRESIGN/COMMIT SÖZLEŞMESİ ÜÇ FARKLI — AYNI `internal/media/` PAKETİNİ YAZACAKLAR
| Konu | görsel-video | belge-ses | altyapı |
|---|---|---|---|
| Geçici prefiks + CopyObject | **VAR** (`gecici/` → taşı) | **YOK** (nihai anahtar) | **YOK** — CopyObject'i açıkça reddediyor |
| `If-None-Match: *` | **VAR** (tek kullanımlık) | **BİLEREK YOK** (tekrar denemeyi öldürür der) | **VAR** (412'yi "zaten yüklü" sayar) |
| Bütünlük anahtarı | MD5 (ETag) | SHA-256 (istemci beyanı) | MD5 + SHA-256 (dedup) |
| Erişim | **PUBLIC** custom domain + CDN | PRIVATE + imzalı GET | PRIVATE + imzalı GET |
| `media_url` alanı | struct'ta kalır, yok sayılır | **kaldırılır** | **kaldırılır** |
| Presign TTL | 300 sn sabit | 300 sn sabit | boyuta göre 300–1800 sn |

**NEDEN:** Bunlar birbirini dışlayan kararlar; "hepsini uygula" mümkün değil. Özellikle **public vs private** kararı, `medya.gebzem.app` DNS kaydı, Cloudflare Transform Rules ve istemci önbellek stratejisini komple belirliyor — sonradan değiştirmek istemci + sunucu + CDN üçünü birden dokundurur.
**KİME:** Bir "medya sözleşmesi" turu; tek karar metni yazılıp diğer tasarımlar ona uyarlanacak. **Önerim:** altyapı tasarımının hattı (private + imzalı GET + doğrudan nihai anahtar + `If-None-Match` + boyuta göre TTL), çünkü tek gerekçesi kanıta dayalı olan o ve CopyObject'in doğrulanmamış olduğunu kabul eden tek çıktı o.

### 1.3 🔴 ÇAKIŞMA KAPISI İKİ TASARIMDA BİRBİRİNİN TERSİ
- **görsel-video:** `MedyaKapisi` → `mesgulMu()` çağırır, "`mesgulMu` TEK KAYNAK, kopyalama".
- **belge-ses:** `SesKapisi` → **"`CallService.mesgulMu()` KULLANILMAZ"** diyor, `SesSahipligi` kullanıyor.
- **altyapı:** `MedyaKapi` → `SesSahipligi`, ayrıca "`mesgulMu` DEĞİL" diyor.

**NEDEN:** Bu, projenin en pahalı hata sınıfının (turu 50 tek taraflı video, turu 64 `!pri`, turu 62-C ses rotası) tek savunması. **İki farklı kapı = kaçınılmaz drift** — CLAUDE.md'nin `rooms_tab`/`live_tab` dersinin birebir tekrarı. Ayrıca ikisi farklı şeyi ölçüyor: `mesgulMu` **ekran muhafızlarına**, `SesSahipligi` **fiilen açık medya oturumuna** bakar; çalar fazında ve oda/yayın duraklatmasında **farklı cevap verirler**.
**KİME:** Tek dosya, tek sınıf, üç yöntem (`kameraSerbest`, `sesBirimiSerbest`, `kodlayiciSerbest`), her biri **hangi kaynağa neden baktığını** yorumda yazacak. Medya kodu yazılmadan önce.

### 1.4 🔴 TAVANLAR VE KOTALAR ÜÇ TASARIMDA FARKLI
| | görsel-video | belge-ses | altyapı |
|---|---|---|---|
| Fotoğraf | 4 MB | — | **2 MB** |
| Video | **32 MB** / 90 sn | — | **16 MB** / 60 sn |
| Ses notu | — | 2 MB / 120 sn | 2 MB / 120 sn |
| Belge | — | **25 MB** | 25 MB |
| Presign kotası | 120/sa · 400/gün | 60/sa · 300/gün | 60/sa · 300/gün |
| Aylık bayt | 3 GB | 2 GB | 2 GB |

**NEDEN:** CLAUDE.md hükmü: *"DÖRT YER AYNI SAYI OLMALI"* (grup kapasitesi dersi). Üç yerde farklı sayı = istemci 4 MB'a izin verir, sunucu 2 MB'da 413 döner, kullanıcı "gönderemiyorum" der.
**KİME:** `limits.go` + `medya_tip.dart` + önizleme uyarı metni **tek tablodan** türetilecek. Sayıyı tek bir tasarım belirleyecek.

### 1.5 🔴 SUNUCUDAKİ `backend/.env`'E R2 ANAHTARLARI EKLEME ADIMI HİÇBİR YERDE YOK
**NE:** Anahtarlar **yerel `.env.infra`**'da. Sunucudaki `backend/.env`'de yok. Üç tasarım da `Enabled()==false` → medya sessizce kapalı davranışı seçmiş.
**NEDEN:** Deploy edilir, health ok döner, uygulama açılır, ataç butonu **yok** olur ve kimse nedenini anlamaz. "Fail-closed" doğru bir tercih ama **sessiz** fail-closed teşhis felaketi. En azından `log.Println("medya: R2 anahtari yok — KAPALI")` + admin panelinde görünür bayrak şart.
**KİME:** Dağıtım kontrol listesine (CLAUDE.md) yeni madde: *"medya turunda: sunucuda `backend/.env`'e R2_* eklendi mi + açılış logunda `medya: aktif` görüldü mü"*.

---

## 2. HER SÜRÜMDE ÇALIŞAN RUTİNİN MEDYAYI KIRDIĞI YER — KİMSE GÖRMEDİ

### 2.1 🔴 `TRUNCATE users CASCADE` HER SÜRÜMDE R2'DE YETİM NESNE BIRAKIR
**NE:** CLAUDE.md rutini: *"Veritabanını temizle: `TRUNCATE users CASCADE`"* — her sürümde. `media_assets.owner_id → users(id) ON DELETE CASCADE` (üç tasarımda da böyle). Satırlar gider, **R2 nesneleri kalır**. Sweeper'lar DB tabanlı çalıştığı için (üç tasarım da lifecycle yerine DB sweeper seçti) o nesneleri **bir daha asla göremez**.
**NEDEN:** Her test turunda R2'de kalıcı çöp birikir; depolama faturası ve 5651 "kaldırma" iddiası ikisi de bozulur. Test turu 70'te 100 medya, turu 90'da 2000 yetim nesne.
**KİME:** Ya truncate rutinine `aws s3 rm --recursive` benzeri bir R2 prefiks temizleme adımı eklenecek, ya da `media_assets` **CASCADE değil** `RESTRICT`/soft-delete olacak. Karar migration yazılmadan verilmeli.

### 2.2 🟠 SENTRY'YE İMZALI URL SIZINTISI — İKİ TASARIMDA VAR, BİRİNDE YOK
`sentry_dio: ^9.6.0` kurulu (`pubspec.yaml:56`). görsel-video ve altyapı `beforeBreadcrumb` maskesi koyuyor; belge-ses ayrı Dio'da `addSentry()` yok diyor ama **indirme yolu** için maske belirtmiyor.
**KİME:** Maske `api.dart`'ta tek yerde, tüm medya hostları için.

---

## 3. KULLANICI "NE VARSA HEPSİ" DEDİ — SESSİZCE DÜŞEN ÖZELLİKLER

Aşağıdakiler WhatsApp envanterinde **sayıldı**, hiçbir tasarımda **yok** ve "yapılmayacak" diye de **işaretlenmedi**. Sessiz düşüş, en tehlikeli eksiklik türü.

| # | NE eksik | NEDEN önemli | KİME / hangi faza |
|---|---|---|---|
| 3.1 | **Uzun basma menüsü (mesaj bağlam menüsü)** — doğruladım: `chat_screen.dart`'ta hiçbir balonda `onLongPress` **yok** | altyapı tasarımı `DELETE /messages/{id}` ucunu yazdı ve test #28'de *"uzun bas → Herkesten sil"* diyor. **O menü yok.** Sil/Yanıtla/İlet/Yıldızla/Kopyala hepsi bu menüye bağlı. Ucu yazıp arayüzü yazmamak = ölü uç (turu 48 "ULAŞILAMAZ KOD" dersi) | **MVP, medya ile aynı turda.** Sahibi belirsiz — hiçbir tasarım almadı |
| 3.2 | **Yanıtlama (reply) arayüzü** | `reply_to_id` DB'de var (`001_init.sql`), `Message.replyToId` modelde var, `send()` **göndermiyor**, balonda **çizilmiyor**. Envanter *"en ucuz kazanç budur"* dedi. Medya gelince zorunlu: medyaya yanıt = küçük resimli alıntı | **MVP.** Sahipsiz |
| 3.3 | **İletme (forward)** | Hiçbir tasarımda yok. Daha kötüsü: altyapı `media_id`'yi NULL'lamama gerekçesini *"iletme geldiğinde"* diye yazdı ama **`media_assets.owner_id = $me` kapısı iletmeyi yapısal olarak imkânsız kılıyor** — ileten kişi medyanın sahibi değil. Bu bir **mimari karar** ve şimdi verilmeli (sahiplik mi, referans sayımı mı, kopya mı) | **Mimari karar ŞİMDİ; özellik 2. dalga** |
| 3.4 | **Fotoğraf düzenleme (kırp/döndür/çiz/metin)** | görsel-video önizleme ekranını tasarladı ama içine sadece altyazı/HD/tek-seferlik koydu. **Kırpma bile yok.** WhatsApp önizleme ekranının kalbi bu | 2. dalga — ama **kullanıcıya söylenmeli** |
| 3.5 | **Albüm gruplama (2+ görsel mozaik)** | 5 fotoğraf gönderince tasarım 5 ayrı balon üretiyor; WhatsApp mozaik yapar. Sohbet 5 fotoğrafta okunamaz hale gelir | 2. dalga |
| 3.6 | **Konum: yakındaki yerler / yer arama** | Envanterde var, konum tasarımında **hiç geçmiyor**, "eksik" olarak da işaretlenmemiş. WhatsApp konum akışının yarısı | 2. dalga — açıkça not edilmeli |
| 3.7 | **Kişi kartı: çoklu seçim + vCard** | v1 tek kişi. Envanter "en fazla ~10" diyor | 2. dalga |
| 3.8 | **Etkinlik (event)** | Envanterde tam tarif var, tasarım yok | 3. dalga — kullanıcıya "yapılmayacak" denmeli |
| 3.9 | **Çıkartma / GIF** | Envanter *"Türkiye'de çok kullanılıyor"* dedi. Harici servis + içerik filtreleme (5651) yükümlülüğü var | 3. dalga — **karar gerekli**, sessiz bırakılmamalı |
| 3.10 | **Tepkiler (reaction)** | Envanter **emoji politikası kararının kullanıcıya sorulması gerektiğini** yazdı. Hediye simgeleri kararı da hâlâ bekliyor (CLAUDE.md turu 62). **İki bekleyen karar aynı konuda ve ikisi de sorulmadı** | **Karar ŞİMDİ sorulmalı** |
| 3.11 | **Süresi dolan mesajlar** | Medya yaşam döngüsüyle iç içe; lifecycle kuralları bugün yazılıyor. Sonra eklemek R2 politikasını değiştirmek demek | **Mimari not şimdi, özellik 3. dalga** |
| 3.12 | **Yıldızlama / sabitleme** | Ucuz, beklenen | 2. dalga |
| 3.13 | **Mesaj arama (medya dahil)** | Uygulamada **hiçbir arama yok** (`/search` sadece kişi arama). 50 mesaj sınırıyla birleşince medya sohbetinde eski içeriğe ulaşmak imkânsız | 2. dalga |
| 3.14 | **Taslak (draft) koruma** | `grep taslak` **boş**. Sohbetten çıkınca yazılan metin kayboluyor; medya önizleme ekranından çıkınca seçim kayboluyor. Belge-ses tasarımı ses notu için "taslak" vaat ediyor — **taslak altyapısı yok** | MVP (ses notu taslağı buna bağımlı) |

---

## 4. VAROLMAYAN EKRANLARA BAĞLANMIŞ TASARIMLAR

### 4.1 🔴 AYARLAR EKRANI YOK — ama üç tasarım ona bağlanıyor
**NE (doğruladım):** `mobile/lib/features/` altında **auth, calls, chats, home, invites, live, rooms** — ayarlar yok. `router.dart`'ta `/`, `/login`, `/register`, `/otp`, `/forgot`, `/search`, `/chat/:id` — **ayar rotası yok.**
Buna rağmen: altyapı tasarımı test #25-27'de *"Ayarlar → hücresel için Video kapalı"*, *"Ayarlar → Depolama → Önbelleği temizle"* diyor; `medya_ayarlari.dart` "ayarlar ekranında değiştirilebilir" diyor.
**NEDEN:** Otomatik indirme kuralı (§8.1) Türkiye'de **ürünün yaşaması için kritik** — hücresel veri paketi sınırlı, varsayılan yanlışsa kullanıcı uygulamayı siler. O kuralı değiştirecek ekran yok.
**KİME:** MVP'ye **Ayarlar ekranı** eklenecek (medya + depolama sekmeleri). Sahipsiz.

### 4.2 🔴 PROFİL EKRANI / AVATAR YÜKLEME YOK
**NE:** Keşif net: `avatar_url` prototipte **her zaman boş**, `.patch(`/`.put(` çağrısı kod tabanında **0 eşleşme**, 7 yerdeki `NetworkImage` fiilen hiç resim yüklemiyor.
Buna rağmen belge-ses tasarımı ses notu balonuna *"solda gönderenin yuvarlak avatarı"* koyuyor; konum tasarımı kişi kartına avatar koyuyor; canlı konum marker'ı avatar kullanıyor. **Hepsi harf yedeğine düşecek.**
**NEDEN:** Medya altyapısı kurulduktan sonra avatar yükleme **en ucuz kazanç** (aynı presign/commit zinciri, tek ekran). Yapılmazsa yeni medya arayüzleri boş dairelerle dolu görünür.
**KİME:** Medya altyapısının **ilk müşterisi** avatar olmalı — fotoğraf balonundan bile önce, çünkü tek dosya/tek boyut/tek tip ile tüm zinciri kanıtlar.

### 4.3 🟠 GRUP SOHBETİ YOK — anket tasarımı bunu itiraf etti, diğerleri görmezden geldi
**NE:** `INSERT INTO chats` üç yerde de `'direct'`; `chat_members.role` hiçbir yerde yazılmıyor.
**NEDEN:** Anket 1:1'de **2 kişilik anket** demek — özelliğin değerinin ~%10'u. Belge paylaşımının asıl yeri (iş/veli/apartman grubu) da grup. Kullanıcı "WhatsApp gibi" derken kastettiğinin büyük kısmı grupta yaşıyor.
**KİME:** Ürün kararı: **grup sohbeti medyadan önce mi sonra mı?** Anket ve belge özelliklerinin değeri buna bağlı. Kullanıcıya sorulmalı.

---

## 5. DOĞRULANMADAN KABUL EDİLEN İDDİALAR

| # | İddia | Kim kabul etti | Neden riskli |
|---|---|---|---|
| 5.1 | **`video_player` iOS'ta `AVAudioSession` kategorisini değiştirir → arama ölür** | Üç tasarım da buna dayanarak video oynatmayı **engelliyor** | altyapı tasarımı dürüstçe *"KAYNAKTAN DOĞRULAMADIM"* diyor. Fail-closed doğru ama **hiçbirinde ölçüm planı yok** → "arama sürerken video izlenemez" kalıcı ve belki gereksiz bir kısıt olarak donar. **Ölçüm maddesi eklenmeli** (Sentry: kategori/mod okuması) |
| 5.2 | **R2 `CopyObject` bizim boyutlarda sorunsuz** | görsel-video kritik yola koydu | Kendi "bilmediklerim"inde teyit edilmemiş diyor. altyapı bu yüzden reddetti. **Karar 1.2'de** |
| 5.3 | **Geoapify "saklama/önbellekleme serbest"** | Konum tasarımının **tüm maliyet modeli** buna dayanıyor | Tasarım *"ToS tam metnini okumadım, pazarlama sayfasından"* diyor. Yanlışsa maliyet modeli çöker. **Sözleşme okunmadan Geoapify hesabı açılmamalı** |
| 5.4 | **`background_downloader` `UploadTask` PUT + ham gövde + özel başlık destekler** | Üç tasarımın arka plan yükleme hikâyesi | altyapı *"doğrulamadım"* diyor. Desteklemiyorsa "uygulama öldürüldükten sonra devam" vaadi düşer |
| 5.5 | **`scaleFactor=2` kredi hesabını 2× yapar/yapmaz** | Konum maliyet tablosu | TAHMİN olarak işaretli ama tablo o rakamla kurulmuş |
| 5.6 | **`record` Android'de AudioFocus'u nasıl alıyor** | Ses notu kapısının gerekçesi | Kaynak okunmamış; sert kapı bunu örtüyor ama gevşetme kararı ölçümsüz verilemez |
| 5.7 | **APK/IPA boyut artışı +2,5–7 MB** | Üç ayrı TAHMİN, hiçbiri ölçülmemiş | 108 MB'lık APK zaten büyük. `flutter build apk --analyze-size` **build alınmadan önce** koşulmalı |

---

## 6. "SONRA BAKARIZ" DENİP ERTELENEN AMA MİMARİYİ BELİRLEYEN KARARLAR

Bunlar sonradan değiştirmesi pahalı; **şimdi karara bağlanmalı**.

### 6.1 🔴 ÇOKLU CİHAZ — üç tasarım üç farklı yama, `message.new` için karar YOK
**NE:** `chatMemberIDs` göndereni listeden çıkarıyor (`handler.go:421-425`) → **gönderenin diğer cihazı kendi mesajını WS'ten almıyor**. altyapı `message.deleted` için `append(userID)`, anket `poll.vote` için `append(userID)`, görsel-video `message.new` için *"önerilir ama ayrı commit"* diyor.
**NEDEN:** Medya ile bu görünür hale gelir: telefondan gönderdiğin fotoğraf tablette/ikinci cihazda görünmez. Üç yerde üç farklı `To` mantığı = drift.
**KİME:** Tek karar: `chatMemberIDs`'in davranışı **değişmeyecek**, ama olay yayınlayan her yer `To`'yu açıkça belirtecek ve bunun bir tablosu yazılacak. Medya kodundan önce.

### 6.2 🔴 İLETME İÇİN SAHİPLİK MODELİ (bkz. 3.3) — `owner_id=$me` kapısı iletmeyi kilitliyor
Şimdi verilmezse, iletme geldiğinde `media_assets` şeması ve tüm yetki sorguları değişir.

### 6.3 🟠 WS KAYIP OLAY ONARIMI — sadece anket tasarımında var
**NE:** Anket `ws.acildi` sentetik olayını icat edip yeniden bağlanınca durumu tazeliyor (turu 61 `call.held` dersi). **Medya tasarımlarının hiçbirinde yok.**
**NEDEN:** `hub.deliver` kuyruk dolunca mesajı **sessizce düşürüyor** (`hub.go:99-101`) ve istemci her arka plana geçişte soketi **bilerek kapatıyor** (`ws.dart:108-121`, turu 33 gereği zorunlu). Medya mesajı o pencereye denk gelirse alıcı **hiç görmez**; sohbeti açınca `load()` kurtarır ama **sohbet listesindeki okunmamış rozeti yanlış kalır** ve push da kaçmışsa mesaj tamamen kaybolur.
**KİME:** `ws.acildi` **tek yerde** tanımlanıp hem anket hem sohbet listesi hem medya tarafından kullanılacak. MVP.

### 6.4 🟠 İDEMPOTENCY — iki farklı çözüm, biri yarışa açık
altyapı `client_ref` + UNIQUE index (doğru). görsel-video *"zaman aşımında `GET son 5 mesaj` ile aynı `media_id` var mı bak"* (yarışa açık, iki cihazda kırılır).
**KİME:** `client_ref` kazanmalı; migration'a girmeli (1.1 ile aynı dosya).

### 6.5 🟠 `medya.gebzem.app` CUSTOM DOMAIN — private bucket kararıyla **gereksizleşiyor**
görsel-video DNS + Transform Rules kuruyor; altyapı private bucket seçince aynı domain kullanılmıyor. Karar verilmezse ya boşuna DNS kurulur ya da güvenlik başlıkları hiç uygulanmaz.

### 6.6 🟠 PAYLAŞ SHEET'İNDEN GEBZEM'E GÖNDERME — hiçbir tasarımda yok, sonradan pahalı
**NE (doğruladım):** `AndroidManifest.xml`'de tek intent-filter var (MAIN/LAUNCHER). `ACTION_SEND` yok, iOS'ta `CFBundleDocumentTypes`/Share Extension yok.
**NEDEN:** WhatsApp'ın en çok kullanılan medya giriş noktalarından biri: galeriden/tarayıcıdan "Paylaş → Gebzem". iOS Share Extension **ayrı target + App Group + pbxproj değişikliği** demek — CLAUDE.md'de *"pbxproj'a AYRI dosya EKLEME (BOM tuzağı)"* uyarısı var, yani bu proje için özellikle riskli ve **sonradan yapmak daha da pahalı**.
**KİME:** Karar şimdi; uygulama 2. dalga.

### 6.7 🟠 BİLDİRİMDE MEDYA ÖNİZLEMESİ — aynı pbxproj riski
Android `BigPictureStyle` + iOS **Notification Service Extension** (ayrı target). Envanterde var, tasarımda yok. NSE ayrıca "tek seferlik medyada önizleme **asla** gösterilmez" kuralını uygulayacak yer.

### 6.8 🟠 `delivered_at` HİÇ YAZILMIYOR — tek tik/çift tik sahte
Medya gelince görünür hale gelir: 8 MB video 40 saniye yüklenirken kullanıcı "gitti mi?" diye bakar. "Gönderiliyor / gönderildi / iletildi / okundu" dört durum gerekir; bugün ikisi sahte. Hiçbir tasarım dokunmadı.

---

## 7. HİÇ KONUŞULMAYAN KATEGORİLER

| # | NE eksik | NEDEN önemli | KİME |
|---|---|---|---|
| 7.1 | **Düşük bellekli cihaz / OOM** | 12 MP fotoğrafı decode etmek Flutter `ImageCache`'ini patlatır. Hiçbir tasarımda `memCacheWidth` / `maxWidthDiskCache` yok. Görüntüleyicide `PageView` 3 tam çözünürlüklü görseli aynı anda bellekte tutar → düşük RAM'li Android'de **çökme**. Test cihazı iPhone XS Max; düşük segment Android **hiç test edilmiyor** | MVP — balon ve görüntüleyici için bellek sınırı + Sentry OOM ölçümü |
| 7.2 | **Erişilebilirlik** | Hiçbir tasarımda `Semantics`, ekran okuyucu etiketi, dokunma hedefi boyutu yok. Medya balonu ekran okuyucuda **hiçbir şey** söylemiyor. Ses notunun dalga formu erişilemez | 2. dalga, ama `Semantics` etiketleri MVP'de ucuz |
| 7.3 | **Karanlık tema** | Medya balonlarının koyu temada davranışı (görsel üstündeki saat hapı, dalga formu renkleri, ilerleme halkası, "indir" rozeti) hiçbir tasarımda yok, **test maddesi de yok**. `scheme.*` kullanıldığı için muhtemelen çalışır — ama "muhtemelen" | MVP test listesine madde |
| 7.4 | **Tablet / büyük ekran** | Balon `maxWidth: ekran*0.65` tablette devasa; 3 sütunlu galeri ızgarası tablette 3 sütun kalır | 3. dalga |
| 7.5 | **Galeriye kaydetme paketi seçilmedi** | görsel-video test #16 *"Kaydet → cihaz galerisinde görünüyor"* diyor, `NSPhotoLibraryAddUsageDescription` ekliyor — ama **kaydetme paketi yok** (`gal` / `image_gallery_saver` hiçbir listede değil). Test bugün geçemez | MVP — paket seçimi eksik |
| 7.6 | **Hazırlık ana thread'i bloklama riski** | görsel-video MD5'i `compute()` ile isolate'e atıyor; belge-ses **atmıyor**. 25 MB belgenin SHA-256'sı ana thread'de = birkaç saniye donma | MVP — kural: tüm hash işleri isolate'te |
| 7.7 | **Medya indirilirken/ yüklenirken bildirim** | Uzun video yüklemesinde kullanıcı uygulamadan çıkarsa hiçbir gösterge yok. Android'de FGS zaten yasak (arama FGS'i var) → en azından uygulama içi kalıcı şerit | MVP (uygulama içi şerit) |
| 7.8 | **Yakınlık sensörü (ses notunu kulağa götürme)** | Envanter "projede yakınlık sensörü yok" dedi; belge-ses bunu ele almadı, "kulaklık rotası" davranışı sessizce düştü | 2. dalga — açıkça not |

---

## 8. SAHİPSİZ ORTAK BİLEŞENLER (dört tasarım aynı şeyi dört kez çizdi)

| Bileşen | Kim çizdi | Sorun |
|---|---|---|
| **Ataç / "Ekle" paneli** | görsel-video (`medya_secici.dart`), belge-ses (`ek_paneli.dart`), konum-kişi (`ek_paneli.dart`), anket (Ekle paneli), altyapı (`ek_paneli.dart`) | **Beş tasarım, üç farklı dosya adı, farklı öğe listeleri, farklı kapı mantığı.** Aynı 20 satırlık widget beş kez yazılacak ve hiçbiri diğerinin öğesini bilmiyor |
| **`_Bubble` kabuğu** (yarıçap/gölge/saat+tik satırı) | Beş tasarım da kendi balonunda tekrarlıyor; sadece altyapı `_BalonKabuk` diye ortaklaştırıyor | Görsel drift kesin |
| **`chat_screen.dart:251-261` tip dallanması** | Beş tasarım da aynı `if/else` zincirini kendi tipiyle yeniden yazıyor | Beş ayrı düzenleme aynı satırlara → çakışma |
| **`chats_screen.dart` `_previewIkon`/`_preview`** | Beş tasarım da `case` ekliyor | Aynı |
| **`_preview` altyazı birleştirmesi** | görsel-video "Fotoğraf · altyazı" istiyor; `ListChats` sorgusu değişmeli — belge-ses de `file_name` için aynı sorguyu değiştiriyor | İki tasarım aynı LATERAL'i farklı şekilde değiştiriyor |
| **`preview[:80]` UTF-8 hatası** | Beş tasarımın **hepsi** aynı hatayı bulup düzeltiyor | Beş kez düzeltilecek |
| **`SendMessage` blok kontrolü** | Dört tasarım ekliyor, sorguları **farklı** | Aynı |

**KİME:** Medya fazının **0. adımı** bir "sohbet ekranı iskeleti" turu olmalı: ataç paneli + balon kabuğu + tip dallanması + önizleme tablosu + `preview` fix + blok kontrolü + uzun basma menüsü (3.1). Sonra her medya tipi bu iskelete **tek dosya** olarak takılır.

---

## 9. YASAL / MODERASYON — HERKES "AYRI İŞ" DEDİ, KİMSE SAHİPLENMEDİ

| NE | NEDEN | KİME |
|---|---|---|
| **PhotoDNA başvurusu** | Ücretsiz ama **vetting süresi bilinmiyor** (güvenlik keşfinin kendi itirafı). Bu, **yayın tarihini belirleyen kritik yol** olabilir | **Bugün başlatılmalı** — kod beklemez |
| **Cloudflare CSAM Scanning + R2 kapsamı** | Güvenlik keşfi *"R2 nesnelerini kapsayıp kapsamadığını doğrulayamadım"* dedi. Ayrıca imzalı URL → cache MISS → araç fiilen devre dışı. **altyapı tasarımı private+imzalı seçerek bu aracı yapısal olarak kapattı ve bunu fark etmedi** | Karar: CSAM savunması **yükleme anında bizde** olacak; Cloudflare aracına güvenilmeyecek |
| **Şikayet akışı + admin medya kaldırma ekranı** | `DELETE` uçları tasarlandı, **çağıran ekran yok**. `md5`/`sha256` ile toplu kaldırma sorgusu var, **arayüzü yok**. 5651 "4 saat" bu ekran olmadan karşılanamaz | Yayın öncesi zorunlu — sahipsiz |
| **Trafik/erişim logu (1 yıl, ~65M satır/yıl)** | Hiçbir tasarımda yok. 80 GB disk | Yayın öncesi |
| **BTK bildirimi, KVKK metinleri, yurt dışına aktarım dayanağı** | Hepsi "hukukçu teyidi" deyip bırakıldı; **kim, ne zaman** belirsiz | Yayın öncesi, ürün sahibi |
| **`/maps/tile` ucu auth middleware DIŞINDA** | Projedeki tek diğer auth-dışı uç LiveKit webhook'u. Yeni bir HMAC şeması icat edildi ve **güvenlik incelemesi görmedi** | Konum turu öncesi adversaryal denetim |

---

## 10. SEVK PLANI YOK — BEŞ TASARIM BEŞ FARKLI SIRA ÖNERİYOR

- **altyapı:** *"adım 5'ten önce test turu ALMA"* — fotoğraf tek başına tüm zinciri kanıtlasın.
- **anket:** *"bugün sevk edilebilir, medyayı BEKLEMEZ"*.
- **konum-kişi:** *"medyadan bağımsız ilerleyebilir"* + ayrıca *"bu tur yalnız migration + backend deploy, istemci bir sonraki tura"*.
- **belge-ses:** kendi turunu tarif ediyor.
- **görsel-video:** kendi turunu tarif ediyor.

**NEDEN önemli:** Beşi de aynı `014` migration'ını, aynı `chat_screen.dart:251` satırlarını, aynı ataç panelini değiştiriyor. Paralel sevk **imkânsız**. Kullanıcı "temiz build al" dedi — **hangi kapsamla?**

**KİME:** Tek sevk planı yazılacak. Önerim:
1. **Turu 70:** bekleyen ölçümleri oku + indir sayfası saati + ölü park zinciri temizliği *(kullanıcının asıl istediği "bug fix araştırması")*
2. **Turu 71:** `014` birleşik migration + `internal/media/` + sohbet ekranı iskeleti (ataç paneli, uzun basma menüsü, balon kabuğu) — **arayüzde görünen tek şey: avatar yükleme**
3. **Turu 72:** fotoğraf uçtan uca *(ilk gerçek test turu)*
4. **Turu 73+:** ses notu → video → belge → konum → kişi → anket

---

## ÖZET — EN KRİTİK BEŞ MADDE

1. **`014` migration çakışması** beş tasarımda; `messages_type_check` üç kez birbirini eziyor → **canlıda sessiz veri kaybı**.
2. **Presign/erişim sözleşmesi üç farklı** (public/private, CopyObject, If-None-Match, MD5/SHA256) → kod yazılamaz.
3. **Çakışma kapısı iki tasarımda birbirinin tersi** (`mesgulMu` vs `SesSahipligi`) → projenin en pahalı hata sınıfının savunması ikiye bölünmüş.
4. **Uzun basma menüsü, ayarlar ekranı, profil/avatar ekranı YOK** — ama üç tasarım onlara bağlanıyor; `DELETE` ucu ve otomatik indirme ayarı **ölü doğuyor**.
5. **Kullanıcının aynı mesajda söylediği iki şey** — "indir sayfasında saat" ve "temiz build öncesi kapsamlı bug-fix araştırması" — **altı çıktının hiçbirinde geçmiyor**.