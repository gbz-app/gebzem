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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — TÜM KATEGORİLER AYNI DÜZENDE + HER KATEGORİYE KENDİ FİLTRELERİ</b><br><br><b>1 · BÜTÜN KATEGORİ EKRANLARI ARTIK &quot;YEMEK&quot; DÜZENİNDE.</b> İlan, Etkinlik, Düğün ve Hizmet ekranları tek tek yazılmıştı ve her biri farklı görünüyordu. Hepsi tek bir ortak kabuğa geçti: aynı başlık, aynı arama kutusu, aynı kutu ızgarası, aynı filtre çipleri, aynı boşluklar. Ölçüler kopyalanmıyor, Yemek ekranından <b>okunuyor</b> — biri değişince hepsi birlikte değişir.<br><br><b>2 · HER KATEGORİNİN KENDİ FİLTRESİ VAR.</b> Yemekteki &quot;Min. tutar&quot; ya da &quot;Teslimat&quot; ilanda anlamsızdı. Artık <b>İlanda</b> fiyat aralığı (alt panelden en az / en çok) ve şehrin; <b>Etkinlikte</b> ücretsiz etkinlikler, bugün ve bu hafta sonu filtreleri var.<br><br><b>3 · BÜYÜK KART / KÜÇÜK KART.</b> İlan ve Etkinlik listelerinde de sağ üstteki iki düğmeyle görünüm değiştirebiliyorsun: tek sütun büyük kartlar ya da iki sütun küçük kartlar.<br><br><b>4 · MENÜDEN İŞLETMELER, TOPLULUKLAR VE DİYET KALDIRILDI.</b> Diyetle ilgili her şey menüden çıktı. Topluluklara Mesajlar ekranındaki &quot;+&quot; menüsünden ulaşmaya devam ediyorsun.<br><br><b>Bu turda yakalanan hatalar:</b> Etkinliklerde bir filtre listeyi boşalttığında ekran &quot;Yaklaşan etkinlik yok, <b>ilk etkinliği sen oluştur</b>&quot; diyordu — oysa etkinlik vardı, filtre elemişti; artık &quot;filtrelere uyan etkinlik bulunamadı&quot; yazıyor ve <b>Filtreleri temizle</b> düğmesi çıkıyor. İlanda fiyat filtresi de aynı şekilde temizlenebiliyor. Etkinlikler yüklenemezse artık <b>Tekrar dene</b> düğmesi var (önceden ekran ölü kalıyordu). Konumu olmayan ilanda yanında hiçbir şey yazmayan boş bir konum işareti duruyordu. Küçük kartlarda satır aralarında ~58px boşluk kalıyordu; yükseklik artık içerikten hesaplanıyor.<br><br><b>Dürüst sınırlar:</b> Etkinlikteki &quot;Ücretsiz&quot; süzgeci telefonda uygulanıyor (sunucuda ücret parametresi yok) — liste tek seferde geldiği için sonuç doğru. &quot;Şehrimde&quot; çipi yalnızca kayıtlı bir işletmen varsa çıkar, ilçen oradan okunuyor. İlan ve Etkinlikte harita görünümü yok, o yüzden görünüm seçicide üçüncü düğme de yok. Menüdeki kutular hâlâ boş. Yakınımda için göndereceğini söylediğin tasarımı bekliyorum.<br><br><b>Not:</b> Bu tur <b>yalnızca arayüz</b>. Sunucu değişmedi, <b>hesaplar ve tüm veriler duruyor</b>.</div>`

let cikti = sablon
  .replace(/\{\{SAAT\}\}/g, saat)
  .replace(/\{\{SURUM\}\}/g, surumEtiketi)
  .replace(/<div class="yeni">[\s\S]*?<\/div>/, YENI_ICERIK);

// --- DOGRULAMA: sessizce yanlis sayfa uretmektense PATLA ---
const kacKez = (m) =>
  (cikti.match(new RegExp(m.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length;

const kontroller = [
  [!cikti.includes('{{'), 'DOLDURULMAMIS yer tutucu kaldi'],
  // ⚠️ TURU 113 — saat artik YEDI yerde: baslik · mor serit · canli saat
  //    satiri · KART ICI ("Bu sürüm:") · iPhone dugmesi · Android dugmesi ·
  //    "Indirdigin dosyanin surumu". Tavan 5 -> 7.
  [kacKez(saat) >= 7, `saat en az 7 yerde olmali (bulundu: ${kacKez(saat)})`],
  [cikti.includes('class="kartsaat"'), 'KART ICI saat satiri kayboldu'],
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
  [cikti.includes('TÜM KATEGORİLER AYNI DÜZENDE') &&
      cikti.includes('HER KATEGORİNİN KENDİ FİLTRESİ VAR'),
    'turu 121 icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
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
