# İndir sayfası araçları

`https://indir.gebzem.app` sayfasını üretir ve R2'ye yükler.

> ⚠️ **Bu dosyalar 78b turunda scratchpad'den repoya taşındı.** Önceden her
> oturumda yeniden yazılıyorlardı ve kullanıcı **iki ayrı turda** "indir
> sitesinde saati göremiyorum" dedi. Kaynak repoda durursa şablon da,
> doğrulama muhafızları da kaybolmaz.

## Kullanım

```bash
node tools/indir/indir_uret.js                       # index.html üretir
node tools/indir/r2put.js <dosya> <anahtar> [tip]    # R2'ye yükler
```

Yayın sırası (CLAUDE.md dağıtım kontrol listesiyle aynı):

1. `indir_uret.js` — saat **UTC+3**, sürüm etiketi APK linkine `?v=` olarak yazılır
2. `r2put.js` ile `gebzem.apk`, `gebzem.ipa`, `index.html` yüklenir
3. **Cloudflare purge ŞART** (Global API Key: `X-Auth-Email` + `X-Auth-Key`;
   Bearer **çalışmaz**), zone `a8af9ee51c2c3ed70cc30d705038abfd`
4. CDN'den indirip **MD5 karşılaştır** — "boyut aynı = build eski" DEME

## Üreticinin muhafızları (derlemeyi DURDURUR)

`indir_uret.js` aşağıdakilerden biri bozulursa `exit 1` verir:

- doldurulmamış `{{...}}` yer tutucu kalmışsa
- saat **5 yerden az** görünüyorsa
- APK linkinde `?v=<sürüm>` yoksa
- `class="saatbar"` (mor şerit) kaybolmuşsa
- **canlı saat** (`id="ss"` + `setInterval`) kaybolmuşsa — sayfanın bayat
  olmadığını kanıtlayan tek şey budur
- `body`ye `display:flex; align-items:center` geri gelmişse (turu 50
  regresyonu: üst taşma kaydırılamaz olur ve saat çubuğu telefonda kırpılır)
- görünen metinde emoji kalmışsa (kullanıcı emri: arayüzde emoji yok;
  HTML/CSS/JS **yorumlarındaki** işaretler taranmaz)

## Yeni sürümde ne değişir

`indir_uret.js` içindeki `YENI_ICERIK` bloğu ve onu doğrulayan
`'turu NN icerigi yazilmadi'` satırı. **İkisi birlikte** güncellenir; yoksa
üretici doğru sayfayı "hatalı" sayıp derlemeyi durdurur.

⚠️ `.env.infra` satır sonu **yorumları** içerir — değer okurken `\s+#.*`
kesilmelidir, yoksa R2 imzası bozulur ve 403 alınır. (`r2put.js` bunu yapıyor.)
