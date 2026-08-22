// indir.gebzem.app/index.html uretici — TURU 77.
//
// ⚠️ SABLON: `indir_sablon.html`. Duzen kullanici tarafindan ONAYLANDI —
//    yeniden tasarlamak RISK. Yalniz yer tutucular ve "Bu surumde" blogu degisir.
//
// ⚠️⚠️ SAAT GORUNURLUGU (kullanici 9 Agu: "indir sitesinde saati goremiyorum",
//    IKINCI kez). Sunucu tarafi DOGRUYDU: `Cache-Control: no-cache, no-store,
//    must-revalidate` + `cf-cache-status: DYNAMIC` + saat cubugu sayfanin EN
//    USTUNDE ve body'de flex ortalama YOK (turu 50 fix'i duruyor). Yani sayfa
//    TAZE servis ediliyordu. Geriye kalan tek makul aciklama: TARAYICI (iOS
//    Safari geri-ileri onbellegi / ana ekrana eklenmis kisayol) bayat kopya
//    gosteriyor ya da saat cubugu goz taramasinda kaciriliyor.
//    BU YUZDEN SAAT ARTIK **ALTI YERDE** YAZAR:
//      1) <title>  -> tarayici sekmesi + gecmis + paylas menusu
//      2) saat cubugu (buyuk mor serit, en ust)
//      3) CANLI SAAT (saniye akar) -> sayfanin BAYAT OLMADIGINI KANITLAR
//      4) iPhone dugmesinin icinde
//      5) Android dugmesinin icinde
//      6) "Indirdigin dosyanin surumu" satiri
//    ⚠️ YAPMA: canli saati kaldirma — bayat-onbellek suphesini cozen TEK sey.
//    ⚠️ YAPMA: body'ye `display:flex; align-items:center` geri koyma
//       (turu 50: kart ekrandan uzun olunca UST TASMA KAYDIRILAMAZ, saat kirpilir).
//
// ⚠️ APK linkindeki `?v=` CDN'i atlatmak icin ZORUNLU (purge gecikse bile
//    tarayici yeni dosyayi ceker).
//
// ⚠️ YER TUTUCU KULLANILIR ({{SAAT}}/{{SURUM}}), eski tarihi regex ile
//    degistirmek DEGIL: eski yontemde sablon bir onceki kosunun tarihini
//    tasimak ZORUNDAYDI ve biri sablonu elle guncellerse uretici SESSIZCE
//    hicbir seyi degistirmezdi.
const fs = require('fs');
const path = require('path');

const DIZIN = __dirname;
const sablon = fs.readFileSync(path.join(DIZIN, 'indir_sablon.html'), 'utf8');

// UTC+3 (Turkiye) — makine saati UTC olabilir.
const now = new Date(Date.now() + 3 * 3600 * 1000);
const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const p2 = (n) => String(n).padStart(2, '0');
const saat = `${now.getUTCDate()} ${aylar[now.getUTCMonth()]} ` +
  `${p2(now.getUTCHours())}:${p2(now.getUTCMinutes())}`;
const surumEtiketi =
  `${now.getUTCFullYear()}${p2(now.getUTCMonth() + 1)}${p2(now.getUTCDate())}` +
  `-${p2(now.getUTCHours())}${p2(now.getUTCMinutes())}`;

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — GİRİŞ VE KAYIT BAŞTAN YAZILDI</b><br><br><b>1 · ARTIK &quot;GİRİŞ Mİ KAYIT MI&quot; SEÇMİYORSUN.</b> Numaranı yazıp &quot;Giriş yap&quot;a basıyorsun; numara kayıtlıysa şifre soruluyor, kayıtlı değilse kod gönderilip doğrudan kayda geçiliyor. &quot;Hesabın yok mu? Kayıt ol&quot; bağlantısı bu yüzden kalktı.<br><br><b>2 · GİRİŞ EKRANI.</b> Sol üstte geri oku, <b>Seni görmek ne güzel</b> / <b>Hadi başlayalım</b>, altında tek satır telefon: <code>+90 512 345 67 89</code>. Numara yazarken kendiliğinden gruplanıyor, yazdıkça hem numara hem <code>+90</code> koyulaşıyor, alt çizgi siyaha dönüyor. Düğmenin üstünde kısa bir not var.<br><br><b>3 · KAYIT DOKUZ ADIM.</b> Numara · şifre · kod · ad · kullanıcı adı · yaş · cinsiyet · ilgi alanları · fotoğraf. Her adımda üstte ince bir satır, altında kalın başlık. <b>Step çizgileri kaldırıldı.</b><br><br><b>4 · KOD EKRANI TELEFON ALANIYLA AYNI DİLDE.</b> Altı ayrı kutu ve aralarındaki tire kalktı; artık <b>tek alan, tek alt çizgi</b>, haneler yalnızca boşlukla ayrık.<br><br><b>5 · ETİKETLER KALKTI.</b> &quot;Adın soyadın&quot; ve &quot;Kullanıcı adı&quot; yazıları alanların üstünden kaldırıldı — başlık zaten ne istendiğini söylüyor. <b>Bu üç turdur yapılamıyordu:</b> kodda &quot;etiketi sil&quot; yazıyordu ama Flutter&#39;da o yazım etiketi <b>silmiyor, olduğu gibi bırakıyor</b>. Gerçekten silen bir yol yazıldı.<br><br><b>6 · ŞİFRE DAİRELERİ.</b> Siyah ve <b>%25 küçük</b> — giriş ve kayıt ekranında artık <b>birebir aynı</b> (ikisi tek kaynaktan okuyor). Göz ikonu yerine <b>Göster / Gizle</b> yazısı var, şifre kuralları alanın altında yazıyor ve karşılandıkça yeşile dönüyor.<br><br><b>7 · KULLANICI ADI AYRI SAYFADA</b> ve sağında yeşil daire içinde tik ya da kırmızı çarpı. <b>Dikkat:</b> bu işaret &quot;bu ad müsait&quot; demiyor, <b>&quot;biçim doğru&quot;</b> diyor — sunucuda müsaitlik soran bir uç yok, çakışma ancak kayıt tamamlanırken çıkıyor.<br><br><b>8 · YAŞ 20&#39;de açılıyor</b>, seçim bandının mor zemini ve yuvarlak köşesi kaldırıldı. Cinsiyette iki seçenek var, boş bırakılabiliyor; <b>Tuttuğun takım</b> kayıttan çıkarıldı. Fotoğraf adımında dairenin gölgesi/çerçevesi yok, düğme tam yuvarlak.<br><br><b>9 · TANITIM EKRANLARI DEĞİŞTİ.</b> &quot;Gelen aramayı kaçırma&quot; sayfası <b>&quot;Teklifler ve mesajlar anında&quot;</b> oldu (hizmet dili). &quot;Telefon kilitliyken arama ekranı&quot; sayfası kaldırıldı; yerine iki yeni sayfa geldi: <b>Alım satım komşunla</b> (ilanlar) ve <b>Şehrinde ne var</b> (etkinlikler). İkisinin de altında kendi kategorileri akıyor.<br><br><b>10 · KLAVYE ARTIK SAYFAYI OYNATMIYOR.</b> Her dokunuşta bütün sayfa zıplıyordu; sebep Flutter&#39;ın varsayılan davranışıydı (klavye açılırken gövdenin tamamı kısalıyor). Kapatıldı — üst içerik kıpırdamıyor, yalnızca düğme klavyeyle birlikte yumuşak çıkıyor.<br><br><b>Yakalanan hatalar:</b> (a) Giriş ekranından kayda geçince <b>şifre adımı tamamen atlanıyordu</b>, yani o kayıt son adımda sunucudan hata alırdı. (b) &quot;Adın ne?&quot; adımında <b>&quot;Devam&quot; hiçbir şey yapmıyordu</b> — adım sayısı artınca geçiş kendi adımına gidiyordu. (c) Yeni tanıtım sayfalarının altında <b>yanlış kartlar</b> akıyordu: ilan sayfasında restoran/kafe, etkinlik sayfasında bir önceki sayfanın haritası.<br><br><b>Bu sayfa hakkında:</b> Sürüm saati artık <b>sekiz yerde</b> yazıyor ve en görüneni logonun hemen altında. Sayfa açılırken saati sunucudan tazeliyor ve <b>hepsini birden</b> güncelliyor — daha önce yalnızca en üstteki güncelleniyordu, yani eski bir kopyada altı eski + bir yeni saat görünebiliyordu.<br><br><b>Dürüst sınırlar:</b> <b>Cinsiyet sunucuya gönderilmiyor</b> (veritabanında sütunu yok, ekranda tutuluyor). <b>&quot;Şifremi unuttum&quot; ve &quot;Kod gelmedi mi?&quot; ekranda yok</b> — gerçek SMS&#39;e geçilince ikisi de gerekecek. Kaldırılan tanıtım sayfası <b>tam ekran bildirim iznini</b> istiyordu; o izin telefon kilitliyken gelen arama ekranının açılmasını sağlıyor. Artık yalnızca <b>Ayarlar &gt; İzinler</b> üzerinden verilebiliyor.<br><br><b>Not:</b> <b>Yalnızca arayüz</b>, <b>yalnızca iPhone</b>. Sunucu değişmedi, hesaplar duruyor.</div>`;

let cikti = sablon
  .replace(/\{\{SAAT\}\}/g, saat)
  .replace(/\{\{SURUM\}\}/g, surumEtiketi)
  .replace(/<div class="yeni">[\s\S]*?<\/div>/, YENI_ICERIK);

// --- DOGRULAMA: sessizce yanlis sayfa uretmektense PATLA ---
const kacKez = (m) =>
  (cikti.match(new RegExp(m.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length;

const kontroller = [
  [!cikti.includes('{{'), 'DOLDURULMAMIS yer tutucu kaldi'],
  // ⚠️ TURU 126 — saat artik SEKIZ yerde: baslik · mor serit · canli saat
  //    satiri · **BASLIK ALTI (22 px, en gorunur olan)** · KART ICI
  //    ("Bu sürüm:") · iPhone dugmesi · Android dugmesi · "Indirdigin
  //    dosyanin surumu" · sayfa dibi. Tavan 7 -> 8.
  [kacKez(saat) >= 8, `saat en az 8 yerde olmali (bulundu: ${kacKez(saat)})`],
  [cikti.includes('class="kartsaat"'), 'KART ICI saat satiri kayboldu'],
  // ⚠️⚠️ TURU 126 — EN GORUNUR SAAT. Kullanici YEDINCI KEZ "goremiyorum"
  //    dedi; yedi yerin hepsi kucuk ya da sayfanin ucundaydi.
  [cikti.includes('class="busaat saatyaz"'),
    'BASLIK ALTI SAAT (busaat) kayboldu — sayfadaki EN GORUNUR saat'],
  // ⚠️⚠️ Taze saat BUTUN saat ogelerine yazilmali. Yalniz ust seride
  //    yazilirsa bayat bir govdede ALTI ESKI + BIR YENI saat gorunur;
  //    iki farkli saat, hic saat gostermemekten DAHA KOTU.
  [kacKez('saatyaz') >= 8,
    `saat ogelerinde .saatyaz sinifi eksik (bulundu: ${kacKez('saatyaz')})`],
  [cikti.includes("querySelectorAll('.saatyaz')"),
    'taze saat TEK YERE yaziliyor (turu 126: hepsine yazilmali)'],
  [cikti.includes(`?v=${surumEtiketi}`), 'apk surum sorgusu yazilmadi'],
  [cikti.includes('class="saatbar"'), 'saat cubugu KAYBOLDU'],
  [cikti.includes('id="ss"') && cikti.includes('setInterval'),
    'CANLI SAAT kayboldu (bayat-onbellek suphesini cozen tek sey)'],
  // ⚠️⚠️⚠️ TURU 96i — BAYAT SAYFA NOBETCISI. Kullanici BES TURDUR "saati
  //    goremiyorum" diyor ve sunucu HER SEFERINDE dogru cikiyor; geriye kalan
  //    tek aciklama TARAYICI ONBELLEGI. Sayfaya "saat yaz" demek bu durumda
  //    ISE YARAMAZ (kullanici zaten ESKI sayfaya bakiyor). Nobetci sayfanin
  //    gomulu surumunu `surum.json` ile karsilastirir ve eskiyse KIRMIZI
  //    SERIT + taze baglanti gosterir.
  // ⚠️ YAPMA: bu kontrolu kaldirma.
  [cikti.includes("id=\"bayat\"") && cikti.includes('surum.json') &&
    cikti.includes("cache: 'no-store'"),
    'BAYAT SAYFA NOBETCISI kayboldu (surum.json karsilastirmasi)'],
  // ⚠️⚠️ TURU 113 — AG GEREKTIRMEYEN IKINCI NOBETCI: adresteki `?v=` ile
  //    sayfaya gomulu surum karsilastirilir. `surum.json` nobetcisi bir
  //    `fetch` gerektirir ve kisitli bir webview'da HIC tamamlanmayabilir;
  //    bu blok yalnizca `location.search` okur, dolayisiyla DAIMA calisir.
  // ⚠️ YAPMA: ikisinden birini otekinin yerine gecirme.
  [cikti.includes('location.search') && cikti.includes('[?&]v='),
    'ADRES SURUM NOBETCISI kayboldu (?v= karsilastirmasi)'],
  // ⚠️⚠️ TURU 115b — **UCUNCU NOBETCI: GORUNEN SAAT SUNUCUDAN YAZILIYOR MU.**
  //	Kullanici ALTI TURDUR "saati goremiyorum" diyor; sunucu ALTI KEZ DE
  //	dogru cikti, yani kalan tek aciklama TARAYICI ONBELLEGI. Onceki iki
  //	nobetci bu durumu yalniz HABER VERIYORDU; bu blok gorunen saatin
  //	KENDISINI `surum.json`daki degerle degistirir, yani bayat bir govdede
  //	bile kullanicinin okudugu saat DOGRU olur.
  // ⚠️ YAPMA: `surumsaat` kimligini veya `d.saat` atamasini kaldirma.
  [cikti.includes('id="surumsaat"'),
    'CANLI SAAT KIMLIGI (surumsaat) kayboldu'],
  [cikti.includes('d.saat'),
    'saat `surum.json`dan YAZILMIYOR (turu 115b nobetcisi)'],
  [!/body\s*\{[^}]*align-items:\s*center/.test(cikti),
    'body flex ortalama GERI GELMIS (turu 50 regresyonu: saat kirpilir)'],
  // ⚠️ ICERIK MUHAFIZI **BU SURUME** SABITLENIR (her turda guncellenir).
  //    Amaci: sablon degistirilip `YENI_ICERIK` guncellenmeden sayfa
  //    uretilmesini ENGELLEMEK — yoksa kullaniciya BIR ONCEKI surumun
  //    notlari gosterilir ve "yeni ne var" yalan olur.
  // ⚠️ YAPMA: bu satiri silme; yeni turda ANAHTAR IFADEYI degistir.
  [cikti.includes('GİRİŞ VE KAYIT BAŞTAN YAZILDI') &&
      cikti.includes('ETİKETLER KALKTI') &&
      cikti.includes('TANITIM EKRANLARI DEĞİŞTİ'),
    'turu 126c icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
  // ⚠️ YALNIZ GORUNEN metin taranir. HTML/CSS/JS YORUMLARINDAKI ⚠️ isaretleri
  //    kullaniciya cizilmez ve serhin okunurlugu icin BILINCLI olarak durur.
  [!/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(
    cikti.replace(/<!--[\s\S]*?-->/g, '').replace(/\/\*[\s\S]*?\*\//g, '')),
    'GORUNEN metinde EMOJI kaldi (kullanici emri: emoji YOK)'],
];
let hata = 0;
for (const [ok, mesaj] of kontroller) {
  if (!ok) { console.error('DOGRULAMA HATASI:', mesaj); hata++; }
}
if (hata) process.exit(1);

fs.writeFileSync(path.join(DIZIN, 'index.html'), cikti, 'utf8');

// ⚠️ TURU 96i — NOBETCININ OKUDUGU DOSYA. `index.html` ile AYNI KOSUDA
//    yazilir ki ikisi birbirinden ayrisamasin (ayri yazilsaydi biri
//    yuklenip oteki unutuldugunda sayfa KENDINI "eski" sanip sonsuz
//    "YENİ SAYFAYI AÇ" gosterirdi).
// ⚠️ `r2yukle.js` bunu da YUKLEMELI ve purge listesine GIRMELI.
fs.writeFileSync(path.join(DIZIN, 'surum.json'),
  JSON.stringify({ v: surumEtiketi, saat }), 'utf8');

console.log('index.html + surum.json uretildi');
console.log('  saat        :', saat, `(${kacKez(saat)} yerde)`);
console.log('  surumEtiketi:', surumEtiketi);
console.log('  bayt        :', Buffer.byteLength(cikti));

// ⚠️⚠️⚠️ TURU 80b — KULLANICIYA VERILECEK ADRES **/index.html?v=...** OLMALI.
//
//	Kullanici UCUNCU KEZ "indir sitesinde saati goremiyorum" dedi. Sunucu
//	tarafi HER SEFERINDE dogru cikti (no-cache/no-store + DYNAMIC + saat
//	alti yerde + canli saat). Bu turda OLCULEN GERCEK SEBEP:
//
//	  `https://indir.gebzem.app/?v=123`  --302-->  `/index.html`
//	                                                  ^ SORGU DUSUYOR
//
//	Yani CIPLAK ALAN ADINA cache-busting parametresi eklemek ISE YARAMIYOR;
//	R2'nin 302'si sorgu dizesini KORUMUYOR. Telefonda ana ekrana eklenmis
//	bir kisayoldan ya da agresif onbellekli bir webview'dan girildiginde
//	tarayici, `no-store` basligina RAGMEN elindeki eski kopyayi cizebiliyor
//	ve kullanici BAYAT saat goruyor.
//
//	`/index.html?v=<surumEtiketi>` ise 302'ye HIC ugramaz (dogrudan nesne)
//	ve her surumde FARKLI bir adres oldugu icin onbellek katmanlarinin
//	HICBIRI eski kopyayi eslestiremez.
//
// ⚠️ YAPMA: kullaniciya ciplak alan adini verme; asagidaki adresi ver.
const taze = `https://indir.gebzem.app/index.html?v=${surumEtiketi}`;
console.log('');
console.log('  ⚠️ KULLANICIYA VERILECEK ADRES (onbellek atlatir):');
console.log('  ' + taze);
