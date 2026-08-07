# GEBZEM — MEDYA PAYLAŞIMI: GÜVENLİK / KÖTÜYE KULLANIM / MALİYET / YASAL ANALİZ

## 0. ZEMİN DOĞRULAMASI (kaynaktan okundu)

| İddia | Durum | Kanıt |
|---|---|---|
| Mesaj tipi beyaz listesi var, 'system' dışarıda | ✅ DOĞRU | `backend/internal/chat/handler.go:152-157` |
| Yükleme altyapısı yok (R2/presign/S3/upload kodu SIFIR) | ✅ DOĞRU | `grep -riE "r2\|presign\|s3\|upload\|cloudflare" backend/internal/` → **0 sonuç** |
| Son migration 013 | ✅ DOĞRU | `backend/internal/database/migrations/013_call_hold.sql` |
| Flutter'da medya paketi yok | ✅ DOĞRU | `mobile/pubspec.yaml:31-66` — image_picker/file_picker/record/video_player/path_provider **hiçbiri yok** |
| `messages.media_url` sütunu hazır | ✅ VAR | `001_init.sql:57` `media_url TEXT NOT NULL DEFAULT ''` |

**Zemin doğrulamasında ÜÇ EK BULGU çıktı (görevde yoktu, ama medya işini doğrudan etkiliyor):**

🔴 **BULGU-1 — `media_url` İSTEMCİDEN GELİYOR VE HİÇ DOĞRULANMIYOR.**
`sendMessageReq.MediaURL` (`chat/handler.go:128`) ham haliyle INSERT ediliyor (`handler.go:169-171`). Yani bugün bile herhangi bir kullanıcı `{"type":"image","media_url":"https://kotu-site.example/izleme.gif?kim=..."}` gönderip karşı tarafın uygulamasına **kendi sunucusundan içerik çektirebilir**: IP + zaman + çevrimiçilik sızdıran izleme pikseli, phishing görseli, ya da karşı tarafın uygulamasını yoran dev dosya. Medya fazına geçilirken **`media_url` ucu tamamen kaldırılmalı**, yerine sunucunun ürettiği `media_id` alınmalı ve URL'yi **sunucu üretmeli**.

🔴 **BULGU-2 — ENGELLEME ÖZELLİĞİ FİİLEN YOK.**
`blocks` tablosu 9 yerde **okunuyor** (`chat/handler.go:282`, `calls/handler.go:322`, `streams/handler.go:266` …) ama `INSERT INTO blocks` kod tabanında **hiç yok** (`grep` → 0 sonuç), `/users/{id}/block` diye bir uç da yok (`cmd/api/main.go:147-209`). Yani tablo hep boş; kullanıcı kimseyi engelleyemiyor. Üstelik engel kontrolü **yalnız sohbet AÇILIRKEN** yapılıyor (`CreateDirect`, `handler.go:280-288`); `SendMessage`'da engel kontrolü **YOK** (`chatMemberIDs`, `handler.go:409-431`, sadece üyelik bakıyor — 159. satırdaki `// uyelik + engel kontrolu` yorumu **yanlış**). Sonuç: sohbet bir kez açıldıktan sonra engelleme olsa bile mesaj/medya akmaya devam eder. **Bu, App Store Review Guideline 1.2'nin (UGC) açık şartı** ve 5651 kötüye kullanım savunmasının temel taşı.

🔴 **BULGU-3 — MESAJ SİLME UCU YOK.**
`deleted_for_all` sütunu var (`001_init.sql:59`) ve okunuyor (`chat/handler.go:236-238`) ama **hiçbir yerde TRUE yapılmıyor**. Yani bugün bir içeriği kaldırmanın **tek yolu elle SQL**. 5651'in "4 saat" yükümlülüğü bu haliyle karşılanamaz.

---

## 1. DOSYA GÜVENLİĞİ

### 1.1 Tip doğrulama — uzantıya ve `Content-Type`'a ASLA güvenme

**KARAR: Sihirli bayt (magic byte) + katı beyaz liste. Uzantı ve istemcinin gönderdiği `Content-Type` yalnızca "ipucu", karar mercii değil.**

İzin verilen (V1):

| Tip | Sihirli imza | Not |
|---|---|---|
| JPEG | `FF D8 FF` | ana foto formatı |
| PNG | `89 50 4E 47 0D 0A 1A 0A` | ekran görüntüleri |
| WebP | `52 49 46 46` … offset 8: `57 45 42 50` | istemci tercihen buna çevirsin |
| MP4/M4A | offset 4: `66 74 79 70` (`ftyp`) + marka `isom/iso2/mp41/mp42/avc1/M4A ` | video + sesli mesaj |
| Ogg/Opus | `4F 67 67 53` (`OggS`) + offset 28 `OpusHead` | sesli mesaj alternatifi |

**YASAK (kesin):** `svg`, `html/xhtml`, `js`, `apk` (`PK\x03\x04` + `AndroidManifest.xml`), `exe` (`MZ`), `zip/rar/7z`, `pdf` (V1'de kapalı), `heic/heif` (**iPhone varsayılanı — istemci JPEG'e çevirsin**, aksi halde Android'de açılmaz + moderasyon araçları HEIC okumaz), `gif` (istemci WebP'ye çevirsin — animasyon bombası + polyglot yüzeyi).

Go tarafında: `http.DetectContentType(ilk512)` **tek başına yeterli değil** (gevşek ve `text/html` gibi şeyleri de "tanır"), ama **red sinyali** olarak kullan: sniff sonucu beyaz listede değilse at. Asıl karar elle yazılmış imza tablosu olmalı.

Ek kontroller: piksel sınırı (**max 50 MP** — dekompresyon bombası; PNG'de 100×100 dosya 30000×30000'e açılabilir), MP4 için `moov` atomunun varlığı, süre sınırı (video ≤ 60 sn, ses ≤ 120 sn — istemci zorlar, sunucu doğrular).

### 1.2 SVG neden tehlikeli?

SVG **görsel değil, çalıştırılabilir XML dokümanıdır**. İçinde `<script>`, `<foreignObject>` (tam HTML gömer), `onload=`/`onclick=` işleyicileri, `<use href="...">` ile harici kaynak çekme, `<image href="data:...">` barındırabilir. Tarayıcı (veya WebView) SVG'yi `<img>` içinde değil de **doğrudan gezinerek** açtığında script **sayfanın origin'inde çalışır**.

**Bu proje için somut senaryo:** admin paneli `https://api.gebzem.app/admin/izle` adresinde ve `ADMIN_KEY` ile korunuyor (`calls/handler.go:1696-1727`). Medya da aynı host'tan sunulsaydı, yüklenen bir SVG'yi admin'in görüntülemesi = **admin oturumunun/anahtarının çalınması** = tüm kullanıcı ve arama verisine erişim. Bu yüzden aşağıdaki "ayrı host" kuralı pazarlık konusu değil.

### 1.3 Sunum başlıkları (ZORUNLU)

```
Content-Type: <sunucunun belirlediği, beyaz listeden>   # istemcininki değil
X-Content-Type-Options: nosniff                          # polyglot'u öldürür
Content-Disposition: inline; filename="medya.jpg"        # sadece doğrulanmış görsel/video
                     attachment                          # diğer her şey
Content-Security-Policy: default-src 'none'; sandbox
X-Frame-Options: DENY
Cross-Origin-Resource-Policy: same-site
Referrer-Policy: no-referrer
Strict-Transport-Security: max-age=31536000
```

**+ ORIGIN AYRIMI (en önemli tek karar):** medya **`medya.gebzem.app`** üzerinden sunulacak; **asla `api.gebzem.app` üzerinden değil.** Böylece bir tip-doğrulama açığı bile admin paneline/API çerezlerine ulaşamaz.

### 1.4 R2: public bucket mı, imzalı GET mi?

**KARAR: PRIVATE bucket. Public bucket / `r2.dev` YOK.**

Gerekçe: bunlar **özel mesajlaşma medyası**. Public bucket'ta anahtar tahmin edilemez olsa bile URL bir kez sızdığında (ekran görüntüsü, log, tarayıcı geçmişi, üçüncü taraf SDK) içerik **süresiz** herkese açık kalır; 5651 kapsamında "kaldırdık" diyemezsin. Ayrıca indeksleme riski var.

Erişim iki aşamalı:

- **V1 (hızlı, sunucusuz risk):** backend kısa ömürlü **imzalı GET** üretir (TTL 10 dk). R2 S3-uyumlu presigned URL'leri destekliyor, 1 sn–7 gün arası ([R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)). ⚠️ **7 gün TAVANI KULLANMA** — 10 dakika yeterli, istemci gerekirse yeniler.
- **V2 (hedef):** `medya.gebzem.app` = R2 custom domain + **Cloudflare Worker**. Worker kısa ömürlü HMAC'i doğrular, R2 binding'den okur, yukarıdaki başlıkları **zorla** ekler, cache anahtarını imzadan arındırıp edge cache'e alır. Başlık kontrolü ve CDN faydası ancak böyle birlikte elde edilir.

⚠️ **İMZALI URL ↔ CSAM TARAMASI ÇELİŞKİSİ (kimse söylemez, önemli):** Cloudflare'in CSAM Scanning Tool'u **"Cloudflare cache üzerinden servis edilen içeriği"** tarar ([docs](https://developers.cloudflare.com/cache/reference/csam-scanning/)). Her isteği benzersiz query string'li imzalı URL yaparsan **cache MISS** olur ve o araç fiilen devre dışı kalır. Yani: **CSAM savunmasını Cloudflare'in cache aracına dayandırma; asıl tarama YÜKLEME ANINDA bizde olmalı** (bkz. §4). Cloudflare aracı ikincil katman.

### 1.5 R2'nin sert kısıtı: presigned PUT'ta BOYUT SINIRLANAMIYOR

R2 **presigned POST policy'yi desteklemiyor**, dolayısıyla S3'teki `content-length-range` koşulu **yok**; presigned PUT'ta maksimum dosya boyutu dayatılamıyor ([Cloudflare community](https://community.cloudflare.com/t/does-r2-support-presigned-post-policy/443246), [docs issue #19190](https://github.com/cloudflare/cloudflare-docs/issues/19190)). `Content-Type` imzaya dahil edilerek sabitlenebiliyor (yanlış tip → `403 SignatureDoesNotMatch`), ama boyut edilemiyor.

**KARAR — "yükle, sonra onayla" deseni:**

1. `POST /media/presign` → sunucu kota/hız kontrolünü yapar, **tek kullanımlık** rastgele anahtar üretir: `gecici/{32-hex}` , TTL **60 sn**, `Content-Type` imzalı.
2. İstemci doğrudan R2'ye PUT eder.
3. `POST /media/confirm {upload_id}` → sunucu **HEAD** (gerçek boyut) + **Range GET ilk 256 KB** (+ MP4 için son 256 KB) yapar → sihirli bayt + boyut + EXIF/GPS + süre kontrolü.
4. Geçerse `medya/{yyyy}/{mm}/{32-hex}.jpg`'e taşınır ve `media_id` döner; **geçmezse `DeleteObject` + 400**.
5. Mesaj gönderimi **yalnız `media_id` kabul eder**; `media_url` alanı API'den kaldırılır (BULGU-1).
6. Onaylanmamış `gecici/` nesneleri: gecelik Go sweeper siler (projede zaten `streamsH.StartSweeper` deseni var, `cmd/api/main.go:93`) **+** R2 lifecycle kuralı 1 gün (çift emniyet).

Bu, R2'nin boyut kısıtı eksikliğini kapatır: kötü niyetli 5 GB yükleme **en fazla birkaç dakika** disk işgal eder ve mesaja **hiç dönüşmez**; üstelik presign ucu hız sınırlı olduğu için tekrarlanamaz.

---

## 2. GİZLİLİK — EXIF / METADATA

### 2.1 Zorunlu mu? EVET.

iPhone/Android fotoğrafı varsayılan olarak **EXIF GPS IFD (tag `0x8825`)** taşır: enlem-boylam-rakım-yön + çekim zamanı + cihaz modeli + seri no. Bir kullanıcı tanımadığı birine fotoğraf gönderdiğinde **ev adresini** göndermiş olur. Bu, ürün açısından skandal, KVKK açısından "gereksiz veri işleme + hukuka aykırı aktarım" riskidir.

### 2.2 Nerede temizlenmeli? **İKİSİNDE DE — ama işi istemci yapar, sunucu DOĞRULAR.**

- **İSTEMCİ (asıl çözüm):** orijinali **hiç yükleme**. Flutter tarafında görsel yeniden kodlanır (max 1600px uzun kenar, kalite ~80, JPEG/WebP). Yeniden kodlama EXIF'i zaten düşürür; ayrıca yönelim (`Orientation`) bilgisi piksellere uygulanmalı yoksa fotoğraf yan döner. Bu aynı anda **maliyeti ve bant genişliğini de** düşürür (3 MB → 250 KB).
- **SUNUCU (güven ama doğrula):** değiştirilmiş bir istemci EXIF'li dosya yükleyebilir. Tam strip = dosyayı indir + yeniden kodla = **cx33'te YASAK** (§7). Yerine **ucuz denetim**: `confirm` adımındaki 256 KB'lık okumada `APP1` + `Exif\0\0` bloğu ve GPS IFD aranır; **varsa yükleme REDDEDİLİR** (istemci ya bozuk ya kötü niyetli). Maliyeti neredeyse sıfır, kesinliği yüksek.

### 2.3 Video metadata

MP4/MOV'da konum `moov/udta/©xyz` (ISO 6709) ve iOS'ta `com.apple.quicktime.location.ISO6709` anahtarında durur; ayrıca `creation_time` + cihaz modeli. ⚠️ **`moov` atomu dosyanın SONUNDA olabilir** (faststart uygulanmamışsa) — bu yüzden sunucu doğrulaması **hem ilk hem son 256 KB'yi** okumalı. İstemci videoyu yeniden kodlarken (720p, ≤60 sn) metadata'yı düşürür.

Sesli mesaj: uygulama kendi kaydettiği için (Opus/AAC) metadata taşımaz — kontrol gerekmez.

⚠️ **EK GİZLİLİK RİSKİ — SENTRY:** `mobile/pubspec.yaml`'da **`sentry_dio: ^9.6.0`** kurulu. Bu paket HTTP isteklerini breadcrumb'a yazar. İmzalı medya URL'leri (query'de `X-Amz-Signature`) **Sentry'e giderse** üçüncü tarafta özel medyaya erişim anahtarı birikir. **KARAR: `beforeBreadcrumb` içinde medya host'unun query string'i maskelenecek.**

⚠️ Cloudflare Images dönüşümü kullanılırsa varsayılan `metadata=copyright` (EXIF copyright hariç her şeyi atar) — yani **varsayılan güvenli**, ama `metadata=keep` GPS'i **korur** ([docs](https://developers.cloudflare.com/images/transform-images/transform-via-url/)). `keep` asla kullanılmayacak.

---

## 3. KÖTÜYE KULLANIM: BOYUT, KOTA, HIZ SINIRI

### 3.1 Boyut sınırları (tip başına)

| Tip | İstemci hedefi | Sunucu SERT tavanı | Gerekçe |
|---|---|---|---|
| Foto | ≤ 400 KB (1600px, q80) | **2 MB** | pay bırak, HDR/panorama |
| Sesli mesaj | ≤ 200 KB (Opus 24kbps) | **2 MB** | 120 sn tavan |
| Video | ≤ 4 MB (720p, ≤60 sn) | **16 MB** | WhatsApp benzeri; cx33 ve mobil veri gerçeği |
| Avatar | ≤ 150 KB (512px) | **1 MB** | `users.avatar_url` (`001_init.sql:11`) da yükleme ister |
| Konum | — | — | dosya değil, `content` içinde "lat,lng" |

### 3.2 Kota + hız sınırı (Redis, go-redis zaten var)

Bugün **hiçbir hız sınırı yok**: `cmd/api/main.go:97-101`'de middleware zinciri sadece `RequestID, RealIP, Logger, Recoverer`. `SendMessage` sınırsız. Yani medya olmadan bile flood mümkün.

**KARAR: tek bir atomik Lua script'i** (projede desen mevcut: `streams/guests.go:52` `redis.NewScript`):

```
KEYS: kota:{uid}:sa:{yyyymmddHH}   kota:{uid}:gun:{yyyymmdd}   kota:{uid}:bayt:{yyyymm}
ARGV: saatlikLimit  gunlukLimit  aylikBaytLimit  istenenBayt  ttl
-> hepsini kontrol et, hepsi geçerse INCR/INCRBY + EXPIRE, 1 dön; yoksa 0 dön
```

Önerilen değerler (ayarlanabilir env):

| Kural | Değer | Neden |
|---|---|---|
| Medya presign | 60/saat, 300/gün | normal kullanıcı asla yaklaşmaz |
| Aylık bayt kotası | 2 GB/kullanıcı | 50K × 2 GB teorik tavan; pratikte ~%1 kullanır |
| **Yeni hesap (< 24 saat)** | 20 medya/gün, 100 MB | **spam hesabının en verimli anı ilk saattir** |
| Mesaj gönderimi (metin dahil) | 20/10 sn burst, 600/saat | flood koruması — **bugün hiç yok** |
| Aynı kişiye ilk mesaj | 10 farklı kişi/saat | toplu taciz/spam yayılımı |
| IP başına presign | 300/saat | tek cihazdan çok hesap |

Ek: **Aynı dosyanın SHA-256'sı** `media_assets` tablosunda tutulur → aynı içeriği 50 kişiye atan spam'i tespit + moderasyon kararını **hash bazında** tüm kopyalara uygula (bir CSAM eşleşmesi tüm kopyaları öldürür). Bu, hem depolama tasarrufu (dedup) hem moderasyon kaldıracı.

Ek: **BULGU-2 kapatılmalı** — `POST /users/{id}/block` + `DELETE` uçları, ve `SendMessage` içinde engel kontrolü (`chatMemberIDs` sorgusuna `blocks` LEFT JOIN'i ekle, `handler.go:409-431`).

---

## 4. İÇERİK MODERASYONU (özellikle CSAM)

### 4.1 Seçenekler ve GERÇEK maliyetleri

| Araç | Ne yapar | Fiyat | Erişim |
|---|---|---|---|
| **Microsoft PhotoDNA Cloud Service** | Bilinen CSAM'e karşı **fuzzy hash** eşleştirme (REST API) | **ÜCRETSİZ** ("free service for qualified customers") | Başvuru + **vetting** gerekir; API anahtarı onaydan sonra verilir ([FAQ](https://www.microsoft.com/en-us/photodna/faq), [Cloud Service](https://www.microsoft.com/en-us/photodna/cloudservice)) |
| **Cloudflare CSAM Scanning Tool** | Cloudflare **cache'inden geçen** içeriği NCMEC hash listeleriyle karşılaştırır; eşleşmede günlük e-posta + **içeriği bloklar** | **ÜCRETSİZ**, tüm müşterilere açık; onboarding artık sadece doğrulanmış e-posta istiyor | Dashboard → Caching → Configuration ([docs](https://developers.cloudflare.com/cache/reference/csam-scanning/), [blog](https://blog.cloudflare.com/a-simpler-path-to-a-safer-internet-an-update-to-our-csam-scanning-tool/)) |
| **Google Cloud Vision SafeSearch** | Yetişkin/şiddet/müstehcen **olasılık skoru** (bilinen-CSAM değil, genel müstehcenlik) | İlk 1.000 birim/ay ücretsiz; **1.001–5M arası $1,50/1.000**; 5M üstü $0,60/1.000 ([fiyat](https://cloud.google.com/vision/pricing)) | Projede Google erişimi **VAR** (gcloud girişli) |

⚠️ **Cloudflare aracı bizi NCMEC'e bildirmez:** "site operators are still expected to continue to file their own reports with NCMEC or their regional equivalent." Bildirim **bizim** yükümlülüğümüz.

⚠️ **R2 kapsamı belirsiz:** araç "Cloudflare cache üzerinden servis edilen içerik" diyor; R2 nesnelerinin proxy'li custom domain üzerinden kapsanıp kapsanmadığı topluluk forumunda soruluyor ama **net cevabı doğrulayamadım (403)**. → **Cloudflare'e açıkça sorulmalı; savunmayı buna dayandırma.**

### 4.2 Maliyet gerçeği (neden "her şeyi Vision'a yollayalım" YANLIŞ)

**Varsayım (TAHMİN):** 50K kayıtlı → %20 DAU = 10K → kişi başı 3 medya/gün → **900K medya/ay**.

- Tüm medya Vision SafeSearch'e: 900.000 × $1,50/1.000 = **$1.350/ay** → **RED.**
- **Hedefli Vision:** şikayet edilenler + yeni hesapların ilk 20 medyası + %2 rastgele örnekleme ≈ 25K/ay → **~$37/ay** → **KABUL.**
- PhotoDNA: **$0** ve tam kapsam (900K/ay hepsi taranır) → **CSAM savunmasının omurgası bu.**

### 4.3 KARAR — üç katmanlı moderasyon

1. **Katman 1 — Hash (yükleme anında, senkron, ücretsiz):** `confirm` adımında görselin PhotoDNA hash'i sorgulanır. Eşleşme → **nesne `karantina/` prefix'ine taşınır, mesaj HİÇ oluşmaz, kullanıcı askıya alınır, olay kaydı (yükleyen id, IP, zaman, hash) 90 gün delil olarak saklanır, yetkili makama bildirim süreci tetiklenir.** ⚠️ Karantina içeriği **silinmez** — delil karartma riski; hukukçu teyidi şart.
2. **Katman 2 — Sinyal (asenkron, hedefli, ucuz):** şikayet + yeni hesap + örnekleme → Vision SafeSearch. `VERY_LIKELY` → otomatik gizle + insan kuyruğuna al.
3. **Katman 3 — İnsan (şikayet akışı):** kullanıcı raporu → admin kuyruğu → kaldır/askıya al.

### 4.4 Şikayet + engelleme akışı (migration 014 ile)

```sql
-- 014_moderasyon.sql
CREATE TABLE message_reports (            -- stream_reports deseniyle birebir aynı
  id BIGSERIAL PRIMARY KEY,
  message_id BIGINT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id),
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'acik' CHECK (status IN ('acik','kaldirildi','reddedildi')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, reporter_id)
);
CREATE TABLE media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id),
  object_key TEXT NOT NULL UNIQUE,
  sha256 TEXT NOT NULL, mime TEXT NOT NULL, bytes BIGINT NOT NULL,
  width INT, height INT, duration_ms INT,
  status TEXT NOT NULL DEFAULT 'gecici' CHECK (status IN ('gecici','aktif','karantina','silindi')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), deleted_at TIMESTAMPTZ
);
CREATE INDEX ON media_assets (sha256);
ALTER TABLE users ADD COLUMN suspended_at TIMESTAMPTZ, ADD COLUMN deleted_at TIMESTAMPTZ;
```

Uçlar: `POST /messages/{id}/report` · `DELETE /messages/{id}` (kendi mesajı: `deleted_for_all=true` + R2 sil + WS `message.deleted`) · `POST /users/{id}/block` + `DELETE` · admin: `GET /admin/reports`, `POST /admin/messages/{id}/remove`, `POST /admin/users/{id}/suspend`. Admin kapısı zaten var (`adminYetkili`, `calls/handler.go:1702`) ve **`AdminEnd` yayın kapatma ucu 5651 gerekçesiyle yazılmış** (`cmd/api/main.go:126`) — aynı desen medyaya genişletilir. Askıya alma `auth` middleware'inde kontrol edilmeli (`internal/auth/middleware.go`).

---

## 5. 5651 / BTK / KVKK

> ⚠️ **HUKUKÇU TEYİDİ ŞART.** Aşağısı mevzuat metni ve ikincil kaynaklardan derlenmiş **yükümlülük listesidir**, hukuki mütalaa değildir. Özellikle "sosyal ağ sağlayıcı" eşiği ve bildirim usulleri için Türkiye'de bilişim hukuku avukatıyla çalışılmalı.

### 5.1 Medya barındırmanın getirdiği EK yükümlülükler

Gebzem şu an da **yer sağlayıcı** (mesaj metni, yayın). Medya eklenince değişen şey **yükümlülüğün türü değil, riskin büyüklüğü ve müdahale hızı gereği**:

- **Md. 5 — trafik bilgisi saklama:** yer sağlayıcı, hizmetlerine ilişkin trafik bilgisini **yönetmelikte belirlenen süre kadar (bir yıldan az, iki yıldan fazla olmamak üzere)** saklamak ve **doğruluğunu, bütünlüğünü, gizliliğini** sağlamakla yükümlü.
- **Md. 5 — bildirim üzerine kaldırma:** md. 8 ve 9 uyarınca haberdar edilmesi hâlinde, **hukuka aykırı içeriği yayından çıkarmakla** yükümlü.
- **Md. 8/A — "dört saat":** millî güvenlik, kamu düzeni, suç işlenmesinin önlenmesi vb. gerekçelerle verilen içeriğin çıkarılması / erişimin engellenmesi kararları **derhal ve en geç dört saat içinde** yerine getirilir. ← **CLAUDE.md'deki "4 saat" buradan geliyor, doğru.**
- **Md. 9 — kişilik hakkı:** içerik/yer sağlayıcıya yapılan başvurulara **24 saat** içinde cevap; mahkeme kararı sonrası uygulama yine **dört saat**.
- **Ek md. 4 — sosyal ağ sağlayıcı:** **Türkiye'den günlük erişimi bir milyonu aşan** platformlar için temsilci atama, 48 saat içinde gerekçeli cevap, raporlama vb. yükümlülükler ve ağır idari para cezaları (10M TL → 30M TL → reklam yasağı → bant daraltma). **Hedef 50K kullanıcı olduğu için bu eşiğin ALTINDAYIZ — ama büyürsek devreye girer.** (Kaynak: [Kılınç Hukuk](https://kilinclaw.com.tr/sosyal-ag-saglayici-icin-yukumlulukler-sorumluluklar-ve-yaptirimlar/), [Kavlak](https://kavlak.av.tr/5651-sayili-kanun-ve-sosyal-ag-saglayici/))

**BTK bildirimi:** *Yer Sağlayıcı Faaliyet Belgesi* alma zorunluluğu **13 Ocak 2015'te kaldırıldı**; yerine **bildirim** yükümlülüğü var. BTK Yer Sağlayıcı Bildirim arayüzünden başvuru yapılır, kabul edilince site BTK listesinde **Yer Sağlayıcı Numarası** ile yayımlanır; **ilk başvuruda ücret alınmıyor** ([Natro](https://www.natro.com/hemendestek/bilgibankasi/sunucu-uzerinde-hosting-yapmak-icin-yer-saglayici-belgesine-ihtiyacim-var-mi), [Karegen](https://www.karegen.com/panel/knowledgebase/144/Yer-Salayc-Faaliyet-Belgesi-Nedir-.html)). ⚠️ Sunucu Almanya'da (Hetzner) — **yurt dışı sunucunun bildirim yükümlülüğüne etkisi kaynaklarda net değil, hukukçuya sorulmalı.**

### 5.2 "4 saat içinde kaldırma" pratikte ne demek?

Teknik olarak **üç şeyin aynı anda hazır olması** demek:

1. **Silme ucu** — bugün **YOK** (BULGU-3). Tek tıkla: `messages.deleted_for_all=true` + `media_assets.status='silindi'` + **R2 `DeleteObject`** + **CDN/edge cache purge** (imzalı-cache'siz mimaride kendiliğinden çözülür) + WS `message.deleted` (karşı taraf anında görsün).
2. **Admin paneli** — mevcut panel (`/admin/izle`) kullanıcı/arama gösteriyor; **mesaj+medya arama ve kaldırma yok**. Eklenmeli: kullanıcıya göre, tarihe göre, `sha256`'ya göre medya listeleme + toplu kaldırma (**bir hash'in tüm kopyalarını tek hamlede** — bu 4 saatlik pencerede hayat kurtarır).
3. **7/24 ulaşılabilir yetkili + tebligat kanalı** — KEP adresi / abuse@gebzem.app + telefon; siteye ve app store listelemesine yazılmalı. "4 saat" **tebligat anından** işler; gece 03:00'te gelen bir karara sabah bakarsan süre geçer. Pratik çözüm: tebligat e-postası → **Uptime Kuma/PushNotification benzeri anlık bildirim** (projede bekci.gebzem.app zaten var).

### 5.3 Trafik logu medyayı kapsıyor mu?

**Ayrım önemli:** 5651'in "trafik bilgisi" tanımı **bağlantı bilgisidir** (taraflara ait IP, port, tarih-saat, kimlik/abone bilgisi), **içeriğin kendisi değil**. Yani:

- ✅ **Saklanması gereken:** medyayı **kim, ne zaman, hangi IP'den** yükledi / indirdi kaydı → **1 yıl** (yönetmelik süresi; 1–2 yıl bandı).
- ❌ **Saklanması zorunlu olmayan:** medya dosyasının kendisi. Silme politikamız (§6) bununla çelişmez — **içerik silinse de erişim logu kalır.**
- ⚠️ Log'un kendisi de kişisel veri: erişimi kısıtlı, değiştirilemez (append-only), şifreli saklanmalı; md.5 "doğruluk, bütünlük, gizlilik" bunu istiyor.

**KARAR:** yeni tablo `medya_erisim_log` (veya Postgres partition) — `user_id, media_id, eylem('yukle'/'indir'), ip, user_agent, created_at`; 400 gün sonra partition drop. ⚠️ **900K yükleme + ~5M indirme/ay = ~65M satır/yıl** — Postgres'te aylık partition + yalnız gerekli sütunlar; aksi halde cx33'ün 80 GB diski dolar. (Alternatif: log'u dosyaya yaz + sıkıştır; 65M satır ≈ **TAHMİN** 8–12 GB sıkıştırılmış.)

### 5.4 KVKK

- Kullanıcı medyası = **kişisel veri** (fotoğrafta kişi görüntüsü, konum, ses). Yüz görüntüsü, kimlik doğrulama amacıyla işlenmedikçe tek başına "özel nitelikli/biyometrik" sayılmaz — **hukukçu teyidi**.
- Gerekli: **Aydınlatma Metni** (ne topluyoruz, ne kadar saklıyoruz, kime aktarıyoruz — **Cloudflare/R2 = yurt dışına aktarım**, bu ayrıca ele alınmalı), **Açık rıza veya meşru sebep dayanağı**, **Kullanım Şartları + Topluluk Kuralları**, **Saklama ve İmha Politikası**, **veri sahibi başvuru kanalı**.
- **VERBİS kaydı:** çalışan sayısı ve mali bilanço eşiklerinin altındaki, ana faaliyeti özel nitelikli veri işleme olmayan veri sorumluları muaf olabiliyor — **TAHMİN, hukukçu teyidi şart**.
- **Yurt dışına aktarım:** Hetzner (Almanya) + Cloudflare (küresel) + Google Vision (ABD) + Microsoft PhotoDNA (ABD) + Sentry + Firebase. KVKK md.9 kapsamında **standart sözleşme/taahhütname veya açık rıza** gerekebilir — **hukukçu teyidi.**
- ⚠️ **Uçtan uca şifreleme kararı:** E2E yaparsak moderasyon (§4) ve 5651 kaldırma yükümlülüğü **teknik olarak imkânsızlaşır**. Bu prototipte E2E **YOK** ve olmamalı; ama pazarlamada "uçtan uca şifreli" **iddia edilmemeli** (yanıltıcı beyan).

---

## 6. DEPOLAMA MALİYETİ + SİLME POLİTİKASI

### 6.1 Maliyet (TAHMİN — varsayımlar açıkça yazıldı)

Varsayım: 900K medya/ay; karışım %60 foto (250 KB) / %25 ses (60 KB) / %15 video (3 MB) → ortalama **~0,6 MB** → **~540 GB/ay yeni veri**.

R2 fiyatları: depolama **$0,015/GB-ay**, Class A **$4,50/M**, Class B **$0,36/M**, **egress ÜCRETSİZ**, ücretsiz katman 10 GB + 1M Class A + 10M Class B ([R2 pricing](https://developers.cloudflare.com/r2/pricing)).

| Kalem | 1. ay | 12. ay |
|---|---|---|
| Depolama | 540 GB → **$8** | 6,5 TB → **~$97/ay** |
| Class A (PUT: medya + küçük resim = 1,8M) | ~**$3,6** | ~**$3,6** |
| Class B (GET ~5M) | ücretsiz katman içinde → **$0** | **$0** |
| Egress | **$0** ← *asıl kazanç; S3'te bu kalem faturayı patlatırdı* | **$0** |
| **TOPLAM** | **~$12** | **~$100/ay** |

**REDDEDİLEN seçenekler (maliyet gerekçesiyle):**

- ❌ **Cloudflare Images ile küçük resim üretimi:** 900K dönüşüm × $0,50/1.000 = **$450/ay** (ücretsiz 5.000 dönüşüm/ay yetmez) ([fiyat](https://theimagecdn.com/docs/cloudflare-images-pricing)).
- ❌ **Cloudflare Stream ile video mesajları:** $5/1.000 dk **depolanan** + $1/1.000 dk **iletilen**. 135K video × 0,5 dk = 67.500 dk/ay → 1. ay **~$340**, 12. ayda birikimli 810K dk → **~$4.050/ay** ([fiyat](https://flarecalc.com/calculators/stream/)). **Stream aboneliği canlı yayın için mantıklı, sohbet videosu için felaket.** Sohbet videosu R2'de duracak.
- ❌ **Tüm medyayı Vision SafeSearch'e sokmak:** $1.350/ay (§4.2).

### 6.2 Silme politikası (KARAR TABLOSU)

| Olay | Medya nesnesi | Mesaj satırı | Erişim logu |
|---|---|---|---|
| **Mesaj silinir (herkesten)** | **HEMEN sil** (R2 DeleteObject) | `deleted_for_all=true` (satır kalır) | **KALIR** (yasal) |
| **Mesaj "benden sil"** | **SİLME** (karşı tarafta duruyor) | yalnız yerel gizleme | kalır |
| **Sohbet silinir** | "benden sil" ise **SİLME** | — | kalır |
| **Şikayet edilmiş / CSAM eşleşmesi** | **`karantina/`ya taşı, 90 gün SAKLA** (delil) | gizle | kalır |
| **Hesap silinir (KVKK unutulma hakkı)** | 30 gün soft-delete → **hard delete**: kullanıcının gönderdiği tüm nesneler silinir | gönderen anonimleştirilir ("Silinmiş kullanıcı") | **KALIR** (yasal saklama istisnası — hukukçu teyidi) |
| **Otomatik yaşam döngüsü** | **365 gün sonra sil** | mesaj satırı kalır, medya "süresi doldu" gösterilir | kalır |

**365 gün makul mü? EVET, ama şeffaflıkla.** WhatsApp medyayı sunucuda sadece teslimata kadar tutar; Telegram süresiz tutar. 1 yıl ikisinin ortası ve maliyeti platoya oturtur (§6.1). ⚠️ **Kullanım Şartları'nda AÇIKÇA yazılmalı** ve istemci indirdiği medyayı cihazda saklamalı, yoksa kullanıcı "fotoğraflarım kayboldu" der.

**R2 Object Lifecycle** bunu doğrudan destekliyor: belirtilen gün sonra **silme**, Infrequent Access'e **geçiş**, ve tamamlanmamış multipart yüklemelerini **iptal**; bucket başına **1.000 kural** sınırı; çakışmada silme öncelikli ([docs](https://developers.cloudflare.com/r2/buckets/object-lifecycles/)).

**KARAR — prefix bazlı kurallar:**
```
gecici/     → 1 gün sonra sil        (onaylanmamış yüklemeler)
medya/      → 365 gün sonra sil
medya/      → 30 gün sonra Infrequent Access'e geçir   ($0,015 → $0,010/GB, ~%33 tasarruf)
karantina/  → lifecycle YOK (elle, hukuki süreç sonrası)
AbortIncompleteMultipartUpload: 1 gün
```
⚠️ Infrequent Access'te Class B **$0,90/M** + **$0,01/GB veri çekme ücreti** var — 30 günden eski medya nadiren açıldığı için net kazanç, ama "eski sohbeti kaydıran" kullanıcı davranışı yoğunsa **ölçüp karar ver**.

⚠️ **Lifecycle DB ile senkron değildir.** 365. günde R2 nesneyi siler ama `media_assets` satırı "aktif" kalır → kırık görsel. **Gecelik sweeper**, süresi dolanları `status='silindi'` yapmalı (aynı desen: `streamsH.StartSweeper`, `cmd/api/main.go:93`).

---

## 7. SUNUCU YÜKÜ — cx33 (4 vCPU / 8 GB / 80 GB) + LiveKit AYNI MAKİNEDE

### 7.1 Medya sunucudan GEÇMELİ Mİ? **HAYIR.**

**KARAR: istemci → R2'ye DOĞRUDAN yükleme (presigned PUT). Sunucu yalnız imza üretir ve 256 KB doğrulama okur.**

Gerekçe (bu proje için özel):

- **LiveKit gerçek zamanlıdır.** Aynı makinede SFU çalışıyor (`backend/livekit-compose.yml`, host network, TURN dahil). 540 GB/ay yükleme + benzeri indirmeyi Go API üzerinden proxy'lemek **CPU ve ağ kuyruğu yaratır** → LiveKit'in UDP paketlerinde jitter → bu projede 40+ tur uğraşılan ses/görüntü sorunlarının **yeni bir kaynağı**. Hetzner'in 20 TB dahil trafiği yeterli olsa bile **sorun bant genişliği değil, gecikme rekabetidir**.
- **Disk 80 GB ve paylaşımlı** (Docker imajları + Postgres + Redis + LiveKit). Medya için **geçici dosya bile diske yazılmamalı**.
- R2 **egress ücretsiz** olduğu için doğrudan indirme ekstra para götürmüyor.

**Sunucunun payına düşen gerçek yük (ölçülebilir):**
- İmza üretimi: saf CPU, ihmal edilebilir (HMAC-SHA256).
- Doğrulama okuması: 900K × 256 KB ≈ **230 GB/ay indirme** + 256 KB'lık parse. `io.LimitReader` ile **bellekte**, asla `/tmp`'ye yazmadan. Bu, cx33 için kabul edilebilir.
- ⚠️ **V2'de bu doğrulama da Cloudflare Worker'a taşınmalı** → sunucu medyaya **hiç dokunmaz**. Worker aynı anda boyut sınırını da dayatır ve R2'nin presigned-PUT boyut eksiğini (§1.5) kökten çözer.

### 7.2 Küçük resim (thumbnail) NEREDE üretilmeli? **İSTEMCİDE.**

| Yer | Karar | Gerekçe |
|---|---|---|
| **İstemci (Flutter)** | ✅ **SEÇİLDİ** | $0, sunucu CPU'su 0, EXIF sorununu da çözer (yeniden kodlama), yükleme boyutunu 10× düşürür |
| Sunucu (ffmpeg/libvips) | ❌ | ffmpeg video karesi çıkarmak **CPU spike** yapar; LiveKit ile aynı 4 vCPU'yu paylaşır → **arama kalitesi bozulur.** Bu projede kabul edilemez. |
| Cloudflare Images | ❌ | **$450/ay** (§6.1) |

İstemci **iki nesne** üretip yükler: `gosterim` (max 1600px) + `kucuk` (320px, ~15 KB). Video için ilk kareden JPEG poster. Gereken paketler (pubspec'te **hiçbiri yok**, eklenmeli): `image_picker`, `flutter_image_compress` (veya `image`), `video_thumbnail`, `record` (sesli mesaj), `path_provider`, `video_player`, `cached_network_image`. ⚠️ Yeni paketler `sentry_flutter 9.x` ve `flutter_webrtc 1.4.0` **pin'lerini bozmamalı** — `flutter pub deps` ile çakışma kontrolü şart (CLAUDE.md: livekit ile aynı sürüm kuralı).

⚠️ **İstemci küçük resmi yalan söyleyebilir** (thumbnail'e masum görsel, aslına yasa dışı içerik). Bu yüzden moderasyon (§4) **her zaman tam nesne üzerinde** çalışmalı, küçük resim üzerinde değil.

---

# ✅ YAYIN ÖNCESİ ZORUNLU

**Güvenlik / mimari**
1. `media_url` API alanını KALDIR; sunucu üretimi `media_id` ile değiştir *(BULGU-1 — bugün açık)*.
2. R2 bucket **PRIVATE**; public bucket / `r2.dev` yok. Medya **`medya.gebzem.app`** üzerinden, **asla `api.gebzem.app`** üzerinden sunulmayacak.
3. Sihirli-bayt beyaz listesi + SVG/HTML/JS/APK/EXE/ZIP/PDF/HEIC **kesin yasak**.
4. Sunum başlıkları: `nosniff`, sunucunun belirlediği `Content-Type`, `CSP: default-src 'none'; sandbox`, `X-Frame-Options: DENY`, `CORP: same-site`.
5. "Yükle → onayla" akışı: presign (TTL 60 sn, tek kullanımlık anahtar, `Content-Type` imzalı) → `confirm` (HEAD + ilk/son 256 KB doğrulama) → geçmezse `DeleteObject` *(R2'de presigned PUT boyut sınırı YOK — §1.5)*.
6. Sunucu tarafı **EXIF/GPS reddi** + istemcide zorunlu yeniden kodlama.
7. **Sentry breadcrumb maskeleme** — imzalı medya URL'leri Sentry'e gitmeyecek (`sentry_dio` kurulu).
8. Tip başına boyut tavanları (foto 2 MB / ses 2 MB / video 16 MB / avatar 1 MB) — **sunucu tarafında**.

**Kötüye kullanım**
9. Redis Lua ile hız sınırı + kota (saatlik/günlük/aylık-bayt), **yeni hesap için sıkı limit**, IP limiti.
10. **Mesaj gönderimine hız sınırı** — bugün hiç yok, medyadan bağımsız açık.
11. **Engelleme özelliğini bitir**: `POST/DELETE /users/{id}/block` + `SendMessage` içinde engel kontrolü *(BULGU-2 — tablo var, uç yok, `SendMessage` hiç bakmıyor)*.

**Moderasyon**
12. **PhotoDNA Cloud Service başvurusu ŞİMDİ yapılmalı** — ücretsiz ama **vetting süresi belirsiz**; onay gelmeden yayına çıkmak riskli.
13. Cloudflare **CSAM Scanning Tool'u zone'da aç** (ücretsiz) + **R2 kapsamını Cloudflare'e teyit ettir**.
14. `message_reports` + `media_assets` + `users.suspended_at/deleted_at` (**migration 014**).
15. Şikayet ucu + **mesaj/medya silme ucu** *(BULGU-3 — bugün elle SQL'den başka yol yok)*.
16. Admin panelinde: rapor kuyruğu, **sha256 ile toplu kaldırma**, kullanıcı askıya alma; `auth` middleware'inde askıya alma kontrolü.

**Yasal** *(hepsi hukukçu teyidiyle)*
17. **BTK yer sağlayıcı bildirimi** (belge değil bildirim; ilk başvuru ücretsiz) — yurt dışı sunucu etkisi sorulacak.
18. **4 saatlik müdahale kabiliyeti**: tek tıkla kaldırma + 7/24 tebligat kanalı (KEP / abuse@gebzem.app) + anlık bildirim.
19. **Trafik/erişim logu** (yükleme + indirme, IP + zaman + kimlik), **1 yıl**, append-only, partition'lı.
20. Aydınlatma Metni + Kullanım Şartları + **Topluluk Kuralları** + Saklama-İmha Politikası + yurt dışına aktarım dayanağı.
21. Yaş beyanı/18+ kapısı ve **App Store 1.2 (UGC) seti**: filtreleme + şikayet + engelleme + 24 saat içinde işlem taahhüdü + yayımlanmış iletişim bilgisi.
22. **"Uçtan uca şifreli" İDDİA ETME** (E2E yok ve moderasyon için olmamalı).

**Maliyet/altyapı**
23. R2 lifecycle: `gecici/` 1 gün · `medya/` 30 gün→IA, 365 gün→sil · multipart iptali 1 gün.
24. Sohbet videosu **Stream'e DEĞİL R2'ye** (Stream 12. ayda ~$4.050/ay).
25. Thumbnail **istemcide** (sunucuda ffmpeg YOK — LiveKit ile CPU rekabeti).
26. Gecelik sweeper: yetim `gecici/` nesneleri + lifecycle-DB senkronu.

---

# ⏳ SONRA YAPILABİLİR

1. **Worker tabanlı sunum** (`medya.gebzem.app` + R2 binding): başlıkları zorla, edge cache, boyut sınırını Worker'da dayat, doğrulamayı sunucudan tamamen al.
2. Google Vision SafeSearch'ü **hedefli** devreye alma (şikayet + yeni hesap + %2 örnekleme ≈ $37/ay).
3. `sha256` ile **dedup** (aynı dosya bir kez saklanır) — depolamada ciddi tasarruf + moderasyon kaldıracı.
4. Konum mesajı (`google_maps_flutter`, **`cloudMapId` KULLANMA**, OSMF tile YASAK) — medyadan bağımsız ilerleyebilir.
5. Belge/PDF desteği (ayrı risk analizi ister).
6. Görüntülenince silinen ("view once") medya, medya iletme sayacı.
7. IA katmanı ölçümü: 30 gün eşiği doğru mu, veri çekme ücreti kazancı yiyor mu?
8. Otomatik NSFW **bulanıklaştırma** (kaldırmak yerine gizle + "göstermek için dokun").
9. Sosyal ağ sağlayıcı eşiğine (**günlük 1M erişim**) yaklaşılırsa ek md. 4 hazırlığı: Türkiye temsilcisi, raporlama, 48 saat cevap süreci.
10. Medya için ayrı depolama sunucusu / R2 bölgesel ayrım, CDN ölçümleri.

---

### Kaynaklar

- [Cloudflare CSAM Scanning Tool — docs](https://developers.cloudflare.com/cache/reference/csam-scanning/)
- [Cloudflare blog — A simpler path to a safer Internet: CSAM scanning update](https://blog.cloudflare.com/a-simpler-path-to-a-safer-internet-an-update-to-our-csam-scanning-tool/)
- [Microsoft PhotoDNA FAQ](https://www.microsoft.com/en-us/photodna/faq) · [PhotoDNA Cloud Service](https://www.microsoft.com/en-us/photodna/cloudservice)
- [Google Cloud Vision pricing (SafeSearch)](https://cloud.google.com/vision/pricing) · [SafeSearch docs](https://docs.cloud.google.com/vision/docs/detecting-safe-search)
- [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing) · [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/) · [R2 object lifecycles](https://developers.cloudflare.com/r2/buckets/object-lifecycles/)
- [R2 presigned POST desteklenmiyor — Cloudflare Community](https://community.cloudflare.com/t/does-r2-support-presigned-post-policy/443246) · [cloudflare-docs issue #19190](https://github.com/cloudflare/cloudflare-docs/issues/19190)
- [Cloudflare Images pricing (2026)](https://theimagecdn.com/docs/cloudflare-images-pricing) · [Image transform `metadata` option](https://developers.cloudflare.com/images/transform-images/transform-via-url/)
- [Cloudflare Stream pricing calculator (2026)](https://flarecalc.com/calculators/stream/)
- [5651 sayılı Kanun tam metni](https://av-saimincekas.com/kanunlar/internet-ortaminda-yapilan-yayinlarin-duzenlenmesi-ve-bu-yayinlar-yoluyla-islenen-suclarla-mucadele-edilmesi-hakkinda-kanun/) · [Erdem&Erdem — 5651 kapsamında internet aktörleri](https://www.erdem-erdem.av.tr/bilgi-bankasi/5651-sayili-kanun-kapsaminda-internet-aktorleri)
- [Kılınç Hukuk — Sosyal ağ sağlayıcı yükümlülükleri](https://kilinclaw.com.tr/sosyal-ag-saglayici-icin-yukumlulukler-sorumluluklar-ve-yaptirimlar/) · [Kavlak — 5651 ve sosyal ağ sağlayıcı](https://kavlak.av.tr/5651-sayili-kanun-ve-sosyal-ag-saglayici/)
- [Natro — Yer sağlayıcı belgesi/bildirimi](https://www.natro.com/hemendestek/bilgibankasi/sunucu-uzerinde-hosting-yapmak-icin-yer-saglayici-belgesine-ihtiyacim-var-mi) · [Karegen — Yer Sağlayıcı Faaliyet Belgesi](https://www.karegen.com/panel/knowledgebase/144/Yer-Salayc-Faaliyet-Belgesi-Nedir-.html)

**Bilmediklerim (uydurmadım):** ① Cloudflare CSAM aracının R2 nesnelerini proxy'li custom domain üzerinden kapsayıp kapsamadığı (topluluk konusu 403 verdi — Cloudflare'e sorulmalı). ② PhotoDNA vetting süresi. ③ Google "Content Safety API"nin (CSAI) erişim koşulları — araştırılmadı. ④ Yurt dışı sunucunun BTK bildirim yükümlülüğüne etkisi. ⑤ VERBİS muafiyet eşiklerinin bu şirkete uygulanışı. ⑥ R2'nin `CopyObject` davranışı büyük nesnelerde (prefix taşıma için teyit edilmeli).