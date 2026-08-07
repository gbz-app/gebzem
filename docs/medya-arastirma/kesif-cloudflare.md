`.env.infra`, `r2put.js`, backend ve pubspec okundu; Cloudflare R2/Images/Stream/Workers fiyat ve yetenek sayfaları çekildi. Rapor aşağıda.

---

# MEDYA DEPOLAMA KARARI — Cloudflare R2 (+ istemci tarafı sıkıştırma)

## 0. Mevcut zemin (kaynaktan doğrulandı)

**`.env.infra` içinde HAZIR olan anahtarlar** (değerler yazılmadı):
| Anahtar | Kapsam |
|---|---|
| `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY` | R2 S3-uyumlu API erişimi (SigV4 imzalama) |
| `R2_ENDPOINT` | `https://<hesap-id>.r2.cloudflarestorage.com` |
| `R2_BUCKET` = `gebzem-media` | **BOŞ / kullanılmıyor** — medya için hazır bekliyor |
| `R2_DIST_BUCKET` = `gebzem-dist` + `DIST_URL` | APK/IPA dağıtımı (indir.gebzem.app) |
| `CLOUDFLARE_ACCOUNT_ID` | Images/Stream/Workers REST API'leri için gerekli hesap kimliği |
| `CLOUDFLARE_API_TOKEN` | Kapsamlı API token |
| `CF_GLOBAL_EMAIL` + `CF_GLOBAL_KEY` | Legacy tam yetki (X-Auth-Email + X-Auth-Key) — purge/DNS |
| `CLOUDFLARE_ZONE_ID` | `gebzem.app` zone — custom domain + Transformations açma için |

**Sonuç: yeni abonelik/hesap GEREKMİYOR.** R2 anahtarları zaten var, bucket zaten açık, zone zaten bizde.

**Yükleme deseni zaten kanıtlanmış:** `scratchpad/r2put.js` (satır 32-96) AWS SigV4'ü **harici bağımlılık olmadan** `crypto` ile üretiyor: kanonik istek → `AWS4-HMAC-SHA256` → `kDate/kRegion('auto')/kService('s3')/kSigning` → `authorization` başlığı. Aynı algoritma Go'da `crypto/hmac` + `crypto/sha256` ile ~60 satır. **`backend/go.mod`'da AWS SDK YOK (doğrulandı)** — presign'ı elle yazmak "harici bağımlılık yok" desenini korur ve go.mod'a tek satır bile eklemez.

**Backend durumu:**
- `backend/internal/chat/handler.go:153` — tip beyaz listesi: `text, image, video, audio, location`. `system` bilinçli olarak dışarıda (turu 59b). **Dokunulmayacak.**
- `backend/internal/database/migrations/001_init.sql:55,57` — `messages.type` CHECK'i ve `media_url TEXT NOT NULL DEFAULT ''` sütunu **zaten var**.
- Son migration `013_call_hold.sql` → yeni iş **014**'ten başlar.
- `backend/internal/` altında R2/presign/upload kodu **SIFIR** (grep ile doğrulandı; tek eşleşme `monitoring-compose.yml`).
- 🔴 **GÜVENLİK AÇIĞI (bu iş kapsamında kapatılmalı):** `handler.go:172` `req.MediaURL`'i **hiç doğrulamadan** INSERT ediyor. Şu anda herhangi bir kullanıcı `media_url`'e istediği harici URL'i (`https://kötü.site/…`) yazabilir; alıcının istemcisi onu çeker → IP sızması + oltalama + izleme pikseli. Beyaz liste `type` için var ama `media_url` için **yok**.

---

## 1. KARAR

> ## **R2 tek başına. Cloudflare Images ve Stream ELENDİ.**
> **Mimari:** istemcide sıkıştır + küçük resmi (thumbnail) istemcide üret → backend'den **presigned PUT** al → **doğrudan R2'ye** yükle → backend `HeadObject` ile **doğrula ve commit et** → mesaja yalnız commit edilmiş `key` iliştirilir → dağıtım `medya.gebzem.app` custom domain'inden CDN önbellekli.

### Neden R2

1. **Egress ÜCRETSİZ** ([R2 pricing](https://developers.cloudflare.com/r2/pricing/)). Orta senaryoda aylık ~2,6 TB indirme oluyor; AWS S3'te bu tek başına ~$234/ay eder, R2'de **$0**.
2. **Zaten kurulu.** Anahtar, bucket, zone, imzalama kodu deseni hepsi mevcut.
3. **Sunucuyu korur.** Medya cx33'ün (4 vCPU / 8GB) üzerinden **hiç geçmiyor**. O makinede LiveKit SFU koşuyor — yüksek senaryoda 5,4 TB yükleme + ~10 TB indirme proxy'lemek hem Hetzner'in 20 TB kotasını yer hem SFU ile CPU/ağ için yarışır. Doğrudan-R2 bunu tamamen ortadan kaldırır.
4. **Ücretsiz katman prototipi tamamen karşılıyor:** 10 GB depolama + 1M Class A + 10M Class B / ay.

---

## 2. Alternatifler ve NEDEN elendikleri

### ❌ Cloudflare Images (barındırmalı) — 18× pahalı
Fiyat: **$5 / 100.000 saklanan görsel/ay + $1 / 100.000 sunulan görsel/ay** ([Images pricing](https://developers.cloudflare.com/images/pricing/)).
Orta senaryoda 900.000 görsel/ay, 90 gün saklama → 2,7M saklanan → **$135/ay** + teslim $18 → **$153/ay**.
Aynı görseller R2'de: 189 GB/ay × 3 ay × $0,015 → **$8,5/ay**.
> **Fiyat "görsel BAŞINA", bayt başına değil.** Sohbet uygulaması = çok sayıda küçük dosya. Bu model tam bizim aleyhimize çalışıyor. **ELENDİ.**

### ❌ Cloudflare Images "Transformations" (R2'deki orijinali dönüştürme) — 447× pahalı
Mümkün: R2 orijinali custom domain arkasındaysa `/cdn-cgi/image/...` ile dönüştürülebilir, resize'lanmış kopyalar R2'ye yazılmaz ([Reference Architecture](https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/optimizing-image-delivery-with-cloudflare-image-resizing-and-r2/)). Fiyat: ilk 5.000 bedava, sonra **$0,50 / 1.000 benzersiz dönüşüm/ay**.
Orta senaryoda görsel başına 1 varyant = 900.000 benzersiz dönüşüm → **$447/ay**.
İstemcide küçük resim üretmek = **$0**. WhatsApp'ın yaptığı da budur.
> **ELENDİ.** (5.000 bedava kotası, yalnız *sunucu tarafı kurtarma* için — istemci küçük resmi üretemezse — küçük bir güvenlik ağı olarak durabilir.)

### ❌ Cloudflare Stream — 65× pahalı
Fiyat: **$5 / 1.000 dakika saklanan + $1 / 1.000 dakika izlenen**; kodlama ve bant genişliği dahil ([Stream pricing](https://developers.cloudflare.com/stream/pricing/)).
Orta senaryo: 90.000 video/ay × 2 dk = 180.000 dk/ay; 90 gün saklama → 540.000 dk → **$2.700/ay** + teslim $360 → **$3.060/ay**.
Aynı videolar R2'de: **$47/ay**.
> Stream, *az sayıda çok izlenen* video kütüphanesi için tasarlanmış. Sohbet videosu tam tersi: *çok sayıda, 1-2 kez izlenen*. HLS/ABR paketlemesinin 1-3 dakikalık, önceden 720p'ye sıkıştırılmış sohbet videosunda getirisi yok — `video_player` doğrudan MP4'ü progressive oynatır. **ELENDİ.**
> ⏳ **İSTİSNA (şimdi değil):** *canlı yayın kaydı / tekrar izleme* özelliği istenirse Stream mantıklı olur (düşük hacim, yüksek değer). Ayrı karar.

### ❌ Media Transformations ile sunucu tarafı video küçük resmi
Mümkün ve ucuz görünüyor: R2'deki videodan `mode=frame` ile kare çıkarır; girdi sınırı **<100 MB ve ≤10 dakika**; **$0,50 / 1.000 benzersiz işlem, 5.000 bedava** ([Transform videos](https://developers.cloudflare.com/stream/transform-videos/)).
Orta senaryoda 90.000 video/ay → **$45/ay**. İstemcide ilk kareyi almak → **$0**.
> **Birincil yol olarak ELENDİ**, yedek olarak tutulabilir (5.000 bedava kota).

### ❌ Backend üzerinden proxy yükleme (medya Go API'den geçsin)
Kod olarak en basiti, presign gerektirmez. Ama:
- Medya cx33'ten **iki kez** geçer (istemci→API girişi, API→R2 çıkışı). Hetzner çıkış kotası 20 TB — yüksek senaryoda tek başına ~5,4 TB'ı yükleme yolunda yer.
- **LiveKit ile aynı makinede CPU/ağ yarışı** → aramada ses/görüntü bozulması riski. CLAUDE.md'de sunucunun sağlıklı olması (%79-82 boşta CPU) ölçülmüş bir kazanım; onu medya trafiğiyle harcamak mantıksız.
> **ELENDİ.**

### ❌ AWS S3 / Backblaze B2 / Hetzner Object Storage
S3: egress ~$0,09/GB → orta senaryoda yalnız egress **~$234/ay** (R2'de $0). Ayrıca Cloudflare zaten elimizde, ikinci sağlayıcı = ikinci fatura + ikinci sır yönetimi. **ELENDİ.**

---

## 3. AYLIK MALİYET TABLOSU

### Varsayımlar (⚠️ hepsi TAHMİN — ölçümle değiştirilecek)

| Varsayım | Düşük | Orta | Yüksek |
|---|---|---|---|
| Günlük aktif kullanıcı (50K kayıtlıdan) | 5.000 (%10) | 15.000 (%30) | 25.000 (%50) |
| Görsel / kişi / gün | 1 | 2 | 5 |
| Video / kişi / gün | 0,05 | 0,2 | 0,5 |
| Ses notu / kişi / gün | 0,5 | 1 | 3 |
| Belge / kişi / gün | 0 | 0,05 | 0,1 |

**Nesne boyutları — bunlar bir TASARIM KARARIDIR, ölçüm değil:**
görsel 200 KB (uzun kenar 1280px, JPEG q80) · küçük resim 15 KB · video 12 MB (2 dk, 720p ~800 kbps H.264) · ses notu 150 KB (30 sn, AAC 40 kbps mono) · belge 500 KB.
*İstemci sıkıştırması olmazsa bu tablodaki her rakam 4-8× büyür.* Sıkıştırma opsiyonel değil, maliyet modelinin temeli.

### Hacim

| | Düşük | Orta | Yüksek |
|---|---|---|---|
| Yeni nesne / ay | 390.000 | 2.452.500 | 10.575.000 |
| Yeni veri / ay | **131 GB** | **1,29 TB** | **5,42 TB** |

### Maliyet — R2 Standard, **90 günlük yaşam döngüsü kuralı** (önerilen)

| Kalem | Birim fiyat | Düşük | Orta | Yüksek |
|---|---|---|---|---|
| Depolama (kararlı durum = 3 aylık birikim) | $0,015/GB-ay | $5,72 | $59,34 | $249,70 |
| Class A (PutObject) — ilk 1M bedava | $4,50/M | $0 | $6,54 | $43,09 |
| Class B (HeadObject + önbellek ıskası GET) — ilk 10M bedava | $0,36/M | $0 | $0 | $3,25 |
| Egress / bant genişliği | **$0** | $0 | $0 | $0 |
| DeleteObject (temizlik) | **$0** | $0 | $0 | $0 |
| **TOPLAM** | | **≈ $6 / ay** | **≈ $66 / ay** | **≈ $296 / ay** |

### Saklama politikası maliyeti nasıl değiştiriyor

| Politika | Düşük | Orta | Yüksek |
|---|---|---|---|
| 90 gün sonra sil (önerilen) | $6 | $66 | $296 |
| Süresiz sakla — 12. ay | $23 | $238 | **$999** |
| Hibrit: 30 gün Standard → sonrası Infrequent Access, süresiz — 12. ay | $17 | **$168** | **$694** |

Infrequent Access: $0,01/GB-ay depolama ama Class B $0,90/M ve **$0,01/GB veri çekme** + **30 gün minimum saklama**. Eski sohbet medyası nadiren tekrar açıldığı için tam uygun; ~%30 tasarruf. ([R2 pricing](https://developers.cloudflare.com/r2/pricing/))

### Elenen seçeneklerin aynı hacimdeki maliyeti (orta senaryo, 90 gün)

| Seçenek | Aylık | R2'ye göre |
|---|---|---|
| **R2 (seçilen)** | **$66** | 1× |
| Görseller Cloudflare Images'ta | +$153 (yalnız görsel) | görsel için 18× |
| Görsel dönüşümü Images ile (R2 orijinali) | +$447 | 53× |
| Videolar Cloudflare Stream'de | +$3.060 (yalnız video) | video için 65× |
| Video küçük resmi Media Transformations | +$45 | istemci = $0 |

### İleride gerekirse
Cloudflare **Workers** ücretli plan: **$5/ay taban**, 10M istek + 30M CPU-ms dahil, **bant genişliği ücretsiz** ([Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)). Ücretsiz plan 100.000 istek/gün. Erişim denetimli teslim (Faz 2, aşağıda) için toplam maliyete +$5/ay.

---

## 4. PRESIGNED AKIŞ — adım adım

```
┌──────────┐                    ┌───────────────┐              ┌─────────┐
│ Flutter  │                    │  Go backend   │              │   R2    │
└────┬─────┘                    └───────┬───────┘              └────┬────┘
     │                                  │                           │
 (0) │ SIKIŞTIR + KÜÇÜK RESİM ÜRET      │                           │
     │ boyut + sha/md5 hesapla          │                           │
     │                                  │                           │
 (1) │ POST /media/upload  (Bearer)     │                           │
     │ {tip, mime, boyut, md5_b64}      │                           │
     ├─────────────────────────────────>│                           │
     │                                  │ (2) YETKİ + LİMİT KAPISI  │
     │                                  │  · tip beyaz listesi      │
     │                                  │  · boyut ≤ tip tavanı     │
     │                                  │  · mime ↔ tip uyumu       │
     │                                  │  · kullanıcı kotası (gün) │
     │                                  │ (3) key üret (UUIDv4)     │
     │                                  │ (4) DB: media_uploads     │
     │                                  │     state='pending'       │
     │                                  │ (5) SigV4 presign PUT     │
     │                                  │     imzalanan başlıklar:  │
     │                                  │     host, content-type,   │
     │                                  │     content-md5,          │
     │                                  │     if-none-match:*       │
     │                                  │     X-Amz-Expires = 300s  │
     │ {upload_id, url, gerekli_bşlk}   │                           │
     │<─────────────────────────────────┤                           │
     │                                  │                           │
 (6) │ PUT <url>  (gövde = dosya)       │                           │
     │ Content-Type / Content-MD5 / If-None-Match: *                │
     ├──────────────────────────────────────────────────────────────>│
     │                                  │        (7) R2 doğrular:   │
     │                                  │   imza ✓ · md5 ✓ · yok ✓  │
     │<─────────────────────────────────────────── 200 / 403 / 412 ──┤
     │                                  │                           │
 (8) │ POST /media/{upload_id}/commit   │                           │
     ├─────────────────────────────────>│                           │
     │                                  │ (9) HeadObject(key) ──────>│
     │                                  │<─── size, etag, ctype ────┤
     │                                  │ (10) BEKLENENLE KARŞILAŞTIR│
     │                                  │   eşleşmezse DeleteObject │
     │                                  │      + state='reddedildi' │
     │                                  │   eşleşirse state='ready' │
     │       {media_key}                │                           │
     │<─────────────────────────────────┤                           │
     │                                  │                           │
(11) │ POST /chats/{id}/messages        │                           │
     │ {type:"image", media_key:...}    │                           │
     ├─────────────────────────────────>│ (12) media_uploads'ta     │
     │                                  │   state='ready' + sahibi  │
     │                                  │   ben + henüz bağlanmamış │
     │                                  │   → state='bagli'         │
     │                                  │   media_url = TÜRETİLİR   │
     │                                  │   (istemciden GELMEZ)     │
     │                                  │                           │
(13) │ GET https://medya.gebzem.app/<key>   ← CDN önbellekli, egress $0
```

### Kritik adımların gerekçesi

**(5) İmzalanan başlıklar — üçü de kanıta dayalı:**
- `content-type`: Cloudflare açıkça söylüyor — imzaya dahil edilir, istemci farklı gönderirse **403 SignatureDoesNotMatch** ([presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)).
- `content-md5`: R2 PutObject'te **Content-MD5 desteklenir** ([S3 API uyumluluk](https://developers.cloudflare.com/r2/api/s3/api/)). Bu, boyut sınırlamasından **daha güçlü**: istemci **tam olarak o baytları** yükleyebilir, başka hiçbir şeyi. Yanlış içerik → `BadDigest`. Yani "boyut dayatılabilir mi?" sorusunun pratik cevabı: **evet, dolaylı ama kesin biçimde.**
- `if-none-match: *`: R2 PutObject'te koşullu başlıklar (`If-None-Match`) **desteklenir** (aynı kaynak). Nesne zaten varsa PUT **412** döner ⇒ presigned URL **fiilen tek kullanımlık** olur. Bu, Cloudflare'in "aynı presigned URL süresi dolana kadar defalarca kullanılabilir" uyarısını kapatan tek satırlık çözüm.

**⚠️ YAPAMADIĞIMIZ ŞEY — dürüst not:**
- R2'de **`content-length-range` YOK**. S3'ün POST-policy'si (form upload) R2'de **desteklenmiyor** ([S3 API uyumluluk](https://developers.cloudflare.com/r2/api/s3/api/); [topluluk](https://community.cloudflare.com/t/how-to-limit-the-object-size-when-using-presigned-put-url/806025)). Yani presigned URL'e "en fazla 10 MB" yazılamaz.
- `content-length`'i imzalamak teorik olarak *tam eşitlik* dayatır ama **R2'nin bunu doğruladığını gösteren resmî belge bulamadım** ve pratikte imza uyuşmazlığı hataları raporlanmış ([aws-sdk-ruby #2581](https://github.com/aws/aws-sdk-ruby/issues/2581)). **TAHMİN düzeyinde — güvenme.** Boyut zorlaması için `content-md5` + (10) numaralı `HeadObject` doğrulaması kullanılacak; ikisi birlikte deliği kapatıyor.
- Platform tavanı: tek parça PUT **5 GiB**, nesne **5 TiB**, çok parçalı en fazla **10.000 parça**, aynı nesneye **saniyede 1 yazma** (aşarsa 429) ([R2 limits](https://developers.cloudflare.com/r2/platform/limits/)). Bizim tavanlarımız bunların çok altında.

**Süre:** `X-Amz-Expires = 300 sn` (5 dk). R2 aralığı 1 sn – 7 gün.

**Çok parçalı yükleme (multipart):** ≤100 MB dosyalar için **gerekmiyor**; tek PUT + yeniden deneme yeterli. Mobil şebekede yarıda kalan büyük video için ileride eklenebilir — ama her `UploadPart` ayrı **Class A** ($4,50/M) olduğunu unutma; 12 MB'lık videoyu 5 MB'lık parçalara bölmek Class A maliyetini 3× yapar. **Şimdilik yapma.**

**CORS:** R2 CORS **yalnız tarayıcı** için gerekli; Dio ile native mobil istemci CORS'a tabi değil ([R2 CORS](https://developers.cloudflare.com/r2/buckets/cors/)). İleride web istemcisi gelirse `AllowedOrigins`/`AllowedMethods: PUT,GET` eklenecek.

---

## 5. Anahtar (key) uzayı tasarımı

```
img/2026/08/07/9f3c1a7e-4b2d-4c88-a1f0-5d7e2b9c4a13.jpg
thm/2026/08/07/9f3c1a7e-4b2d-4c88-a1f0-5d7e2b9c4a13.jpg     ← küçük resim: AYNI uuid
vid/2026/08/07/2c8b0d51-...-....mp4
aud/2026/08/07/....m4a
doc/2026/08/07/....bin                                       ← uzantı YOK
tmp/2026/08/07/....                                          ← henüz commit edilmemiş
```

**Kurallar:**
1. **Kullanıcı id / sohbet id / telefon ASLA anahtarta yok.** Anahtar sızsa bile kimin, kiminle konuştuğu anlaşılmaz. (Anahtar 1.024 bayta kadar serbest ama biz kısa tutuyoruz.)
2. **UUIDv4 = 122 bit entropi.** Tahmin edilemez; "capability URL" güvenliği buna dayanıyor.
3. **Orijinal dosya adı ASLA anahtarta yok** (kişi adı/şirket adı sızdırır). DB'de saklanır, indirmede `Content-Disposition` ile verilir.
4. **Belgede uzantı yok** (`.bin`) — `.exe`/`.html` uzantısı CDN'den servis edilirse XSS/indirme tuzağı olur. `Content-Type` PUT'ta `application/octet-stream` olarak sabitlenir.
5. **Tip prefiksi (`img/`,`vid/`,`aud/`,`doc/`,`thm/`,`tmp/`)** yaşam döngüsü kurallarını tipe göre ayırmayı sağlar (aşağıda).
6. **Tarih prefiksi** operasyonel ayıklama ve prefiks kapsamlı kural için; sızdırdığı tek şey yükleme günü — zararsız.

---

## 6. Erişim denetimi — iki fazlı

### Faz 1 (şimdi): açık bucket + custom domain + tahmin edilemez anahtar
`medya.gebzem.app` → `gebzem-media` bucket (zone `gebzem.app` zaten bizde).
`Cache-Control: public, max-age=31536000, immutable` (anahtar zaten benzersiz).
✅ CDN önbellekli, hızlı, egress $0, R2 Class B ıskası minimum.
⚠️ **Dürüst sınır:** URL'i ele geçiren herkes içeriği görür ("capability URL"). Uçtan uca şifreleme YOK. KVKK açısından savunulabilir bir prototip duruşu ama **kalıcı çözüm değil.**

### Faz 2 (gerçek yayından önce): Worker HMAC kapısı
`medya.gebzem.app` önüne Worker: `?e=<son_kullanma>&s=<hmac>` doğrulanır, geçerliyse R2 binding üzerinden nesne döner. Önbellek anahtarı imza parametreleri **hariç** yol olur → CDN önbelleği korunur. Backend, mesajı görmeye yetkili kullanıcıya (sohbet üyeliği kontrolüyle) kısa ömürlü imzalı URL üretir. Maliyet: **+$5/ay**. ([Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/))

### ❌ Presigned GET ile teslim — elendi
Presigned URL'ler **custom domain ile kullanılamaz**, yalnız S3 API alan adında çalışır ([presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)). Yani **CDN önbelleği devre dışı** → her görüntüleme bir Class B işlemi + her kullanıcıya farklı URL → mesaj listesinde önbellek tutmaz. Faz 2'deki Worker yaklaşımı hem güvenli hem önbellekli. **ELENDİ.**

---

## 7. Silme ve temizlik

| Kural | Prefiks | Eylem |
|---|---|---|
| Yetim yükleme | `tmp/` | **1 gün** sonra sil |
| Yarım kalan multipart | tümü | **1 gün** sonra iptal et (varsayılan 7 gün) |
| Sohbet medyası | `img/`,`vid/`,`aud/`,`doc/`,`thm/` | **30 gün** sonra Infrequent Access'e geçir, **90/180 gün** sonra sil *(ürün kararı)* |

- Yaşam döngüsü: bucket başına **1.000 kurala kadar**; silmeler tipik olarak **24 saat içinde** uygulanır; IA'ya geçiş **bir Class A** işlemi sayılır ([Object lifecycles](https://developers.cloudflare.com/r2/buckets/object-lifecycles/)).
- **`DeleteObject` ÜCRETSİZ** — kullanıcı mesajı silince nesneyi hemen silmek maliyetsiz.
- **BTK/5651 uyumu:** "4 saat içinde içerik kaldırma" yükümlülüğü için `DELETE /admin/media/{key}` ucu + admin panelde arama gerekiyor. Yaşam döngüsü kuralı bunun yerini **tutmaz** (24 saat gecikmeli).
- **Sızıntı denetçisi:** haftalık iş — `media_uploads` tablosunda `state='ready'` ama hiçbir mesaja bağlanmamış, 7 günden eski satırları sil. Aksi halde iptal edilen gönderimler sonsuza kadar depolamada kalır.

---

## 8. Şimdi yapılması gereken somut değişiklikler

**Backend (Go, yeni bağımlılık YOK):**
1. `backend/internal/media/` — `sigv4.go` (r2put.js:57-77 algoritmasının Go karşılığı), `handler.go` (`POST /media/upload`, `POST /media/{id}/commit`), `limits.go`.
2. **Migration `014_media_uploads.sql`** — `id, user_id, key, tip, mime, beklenen_boyut, beklenen_md5, state('pending'|'ready'|'bagli'|'reddedildi'), created_at, expires_at`.
3. 🔴 **`handler.go:172` düzeltmesi:** istemciden gelen `media_url` **artık kabul edilmeyecek**. Yerine `media_key` alınıp `media_uploads`'ta doğrulanacak (`state='ready'` + `user_id = gönderen` + henüz bağlanmamış), `media_url` **sunucuda türetilecek**. Bu, mevcut SSRF/oltalama açığını kapatır.
4. Tavanlar: görsel 10 MB · video 100 MB · ses 16 MB · belge 25 MB · kullanıcı başına günlük nesne ve toplam bayt kotası (kötüye kullanım freni).
5. `.env`'e: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`, `R2_BUCKET=gebzem-media`, `MEDIA_BASE_URL=https://medya.gebzem.app`. ⚠️ `backend/.env` git'e girmez.

**Cloudflare (elle, tek seferlik):**
6. `gebzem-media` bucket'ına custom domain **`medya.gebzem.app`** bağla (zone id `.env.infra`'da).
7. Yaşam döngüsü kurallarını yukarıdaki tabloya göre gir.

**Flutter (pubspec'e eklenecek — hiçbiri şu an yok, doğrulandı):**
8. `image_picker`, `flutter_image_compress` (görsel), `video_compress` *veya* `ffmpeg_kit_flutter_min` (video — ⚠️ APK boyutunu ciddi büyütür, ölçülmeli), `record` (ses notu), `file_picker` (belge), `path_provider`, `crypto` (MD5), `cached_network_image`, `video_player`.
   ⚠️ `crypto` MD5'i **base64** olarak `Content-MD5`'e yazılır (hex değil).
   ⚠️ Arayüzde **emoji yok** — ek/dosya ikonları **Lucide** (`lucide_icons_flutter` zaten var).
9. `dio` ile `PUT` — presigned URL'e **Authorization başlığı GÖNDERME** (interceptor'ın Bearer eklememesi için ayrı `Dio` örneği veya `extra` bayrağı şart; aksi halde imza bozulur).

---

## Kaynaklar

- [R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)
- [R2 S3 API uyumluluğu](https://developers.cloudflare.com/r2/api/s3/api/)
- [R2 limits](https://developers.cloudflare.com/r2/platform/limits/)
- [R2 object lifecycles](https://developers.cloudflare.com/r2/buckets/object-lifecycles/)
- [R2 CORS](https://developers.cloudflare.com/r2/buckets/cors/)
- [Cloudflare Images pricing](https://developers.cloudflare.com/images/pricing/)
- [Images direct creator upload](https://developers.cloudflare.com/images/upload-images/direct-creator-upload/)
- [Images + R2 referans mimarisi](https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/optimizing-image-delivery-with-cloudflare-image-resizing-and-r2/)
- [Stream pricing](https://developers.cloudflare.com/stream/pricing/)
- [Media Transformations (video)](https://developers.cloudflare.com/stream/transform-videos/)
- [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [R2 presigned PUT boyut sınırı — topluluk](https://community.cloudflare.com/t/how-to-limit-the-object-size-when-using-presigned-put-url/806025)
- [Content-Length imzalama sorunu — aws-sdk-ruby #2581](https://github.com/aws/aws-sdk-ruby/issues/2581)

**İlgili dosyalar:** `c:/Users/gebze/OneDrive/Desktop/gbz-a3/backend/internal/chat/handler.go` (satır 153 beyaz liste, satır 172 `media_url` açığı) · `c:/Users/gebze/OneDrive/Desktop/gbz-a3/backend/internal/database/migrations/001_init.sql` (satır 55, 57) · `c:/Users/gebze/OneDrive/Desktop/gbz-a3/backend/go.mod` (AWS SDK yok) · `c:/Users/gebze/OneDrive/Desktop/gbz-a3/mobile/pubspec.yaml` (medya paketi yok) · `C:/Users/gebze/AppData/Local/Temp/claude/c--Users-gebze-OneDrive-Desktop-gbz-a3/0c8992f5-0fef-42de-9a37-263414f4ce95/scratchpad/r2put.js` (SigV4 referans deseni)