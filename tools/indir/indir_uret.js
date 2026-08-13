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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — ÖNEMLİ İKİ HATA DÜZELTİLDİ:</b><br><br><b>1 · KIRMIZI EKRAN GİTTİ (sen bildirdin):</b> Konumu kaydederken (ve ürün/etkinlik/randevu/gönderi düzenleme gibi <b>metin soran altı yerde</b>) ekranın tamamı kırmızı oluyordu. Sebep: yazı kutusu, pencere kapanma animasyonu <b>daha bitmeden</b> serbest bırakılıyordu. Altı yerde de düzeltildi ve bir daha olmaması için <b>kalıcı test</b> eklendi.<br><br><b>2 · KONUM KAYDEDİLİYOR AMA GÖRÜNMÜYORDU:</b> Sunucu adresi doğru kaydediyordu, uygulama <b>&quot;Kayıtlı konumun yok&quot;</b> diyordu. Sebep: sunucu yanıtı JSON olduğunu <b>söylemiyordu</b>, uygulama da okuyamıyordu. Artık <b>Konumun</b> panelinde <b>Ev</b> görünüyor, üst köşede <b>Konum: Ev</b> yazıyor ve işletme kartlarında <b>1,5 km · 948 m</b> gibi uzaklıklar çıkıyor.<br><br><b>3 · BU SAYFA ARTIK KENDİNİ KONTROL EDİYOR:</b> Telefonun tarayıcısı <b>eski bir kopyayı</b> gösterirse en üstte <b>kırmızı bir şerit</b> çıkıp &quot;BU SAYFA ESKİ&quot; diyor ve tek dokunuşla yenisini açıyor. (Saat zaten sayfada <b>5 yerde</b> yazıyor ve en üstteki <b>saniyesi akan saat</b> sayfanın az önce yüklendiğini kanıtlıyor.)<br><br><b>4 · Açılışta düşen bir hata</b> (Canlı ve Oda sekmeleri) da giderildi.<br><br><b>Önceki sürümün tamamı duruyor:</b> konum seçme (<b>GPS</b> ya da <b>haritadan pin taşıyarak</b>, hesabına kayıtlı) · 8 keşif kartı (<b>Ne Yesem? · İndirimli · 4+ · Şimşek · Yakınımda · Gece Kuşu · Yeni Restourant · Favori</b>) · <b>Filtre</b> paneli ve kısayolları (süzme <b>sunucuda</b>) · <b>Mutfaklar</b> şeridi · <b>Restoranlar (2)</b> başlığı + <b>liste · kart · harita</b> geçişi · <b>3 ikon sol · logo · 3 ikon sağ</b> alt menü.<br><br><b>HAZIR TEST HESAPLARI:</b> Veritabanı sıfırlandı; <b>14 işletme</b> (2 restoran + 2 kafe + doktor, diyetisyen, kuaför, güzellik, otel) + 2 kullanıcı, <b>14/14&#39;ünden randevu alınabiliyor</b>, hazır bir <b>düğün talebi + 3 teklif</b> ve <b>dolu bir diyet günü</b> var — hesap listesi ayrıca verildi.<br><br><b>Sınırlar:</b> Karttaki <b>puan, teslimat süresi ve minimum tutar</b> işletmenin girdiği değerlerdir; <b>değerlendirme sistemi ve sipariş/kurye modeli henüz yok</b>. Filtrede <b>ödeme yöntemi</b> bölümü yok — o veri hiç tutulmuyor. <b>Yeni Restourant</b> kartı <b>puanı olmayan</b> işletmeleri gösterir; tohumdaki herkesin puanı olduğu için <b>şimdilik boş döner</b>. Kategori ekranında <b>geri düğmesi yok</b> — telefonun geri tuşuyla çıkılır. Kayan alan hâlâ <b>boş</b>. Teklif isteğin <b>7 gün</b> açık kalır, en fazla <b>5 teklif</b> alır. Talepler <b>herkese açıktır</b> — telefon/adres yazma. Ödeme yok.</div>`;

let cikti = sablon
  .replace(/\{\{SAAT\}\}/g, saat)
  .replace(/\{\{SURUM\}\}/g, surumEtiketi)
  .replace(/<div class="yeni">[\s\S]*?<\/div>/, YENI_ICERIK);

// --- DOGRULAMA: sessizce yanlis sayfa uretmektense PATLA ---
const kacKez = (m) =>
  (cikti.match(new RegExp(m.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length;

const kontroller = [
  [!cikti.includes('{{'), 'DOLDURULMAMIS yer tutucu kaldi'],
  [kacKez(saat) >= 5, `saat en az 5 yerde olmali (bulundu: ${kacKez(saat)})`],
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
  [!/body\s*\{[^}]*align-items:\s*center/.test(cikti),
    'body flex ortalama GERI GELMIS (turu 50 regresyonu: saat kirpilir)'],
  // ⚠️ ICERIK MUHAFIZI **BU SURUME** SABITLENIR (her turda guncellenir).
  //    Amaci: sablon degistirilip `YENI_ICERIK` guncellenmeden sayfa
  //    uretilmesini ENGELLEMEK — yoksa kullaniciya BIR ONCEKI surumun
  //    notlari gosterilir ve "yeni ne var" yalan olur.
  // ⚠️ YAPMA: bu satiri silme; yeni turda ANAHTAR IFADEYI degistir.
  [cikti.includes('KIRMIZI EKRAN GİTTİ') && cikti.includes('kendini kontrol')
    || cikti.includes('KENDİNİ KONTROL EDİYOR'),
    'turu 96i icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
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
