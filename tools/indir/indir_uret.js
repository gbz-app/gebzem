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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — GÖNDERİ DETAYI, YORUMLAR ve AKIŞ:</b><br><br><b>1 · GÖNDERİ DETAYI YENİ:</b> Bir gönderinin yorum ikonuna dokununca <b>Yazışma</b> ekranı açılıyor: üstte görüntülenme sayısı, altında <b>Başlıca</b> / <b>Hareketi gör</b> satırı, sonra <b>bağlantı çizgili yorumlar</b>. Yorumlarda <b>mavi tik</b>, <b>yazarın beğenisi</b> (kırmızı kalp), <b>Gönderi sahibi</b> rozeti ve <b>Yanıtları göster</b> var; her yorumun kendi beğeni/yorum/alıntı/paylaş satırı bulunuyor.<br><br><b>2 · AKIŞTA YANIT:</b> Bazı gönderilerin altında <b>bir yanıt</b> görünüyor.<br><br><b>3 · SPONSORLU GÖNDERİ:</b> Zaman yerine <b>Sponsorlu</b> yazıyor; görselin altında <b>alan adı + &quot;Şimdi Sipariş Ver&quot;</b> kartı çiziliyor.<br><br><b>4 · ETKİLEŞİM SATIRI:</b> Beğenince kalp <b>tamamen kırmızı</b> doluyor, <b>sayı da kırmızı</b> oluyor ve <b>aşağıdan yukarı kayarak</b> değişiyor. Sayılar <b>ikon boyuna</b> büyüdü; paylaş ikonu diğerleriyle <b>eşitlendi</b>; yeniden paylaş ikonu <b>redo</b> oldu.<br><br><b>5 · ÜST ÇUBUK ve ŞERİT:</b> <b>Arkadaşlar · Keşfet · Canlı Yayın</b> artık <b>header ortasında</b>, <b>+</b> ile <b>bildirim</b> arasında; iki ikon da <b>alt menüyle aynı boyutta</b>. Hikâye daireleri <b>65 dp</b> ve <b>hepsi eşit</b> (ekleme dairesi dahil); aralarındaki boşluk ve şerit ile ilk gönderi arası <b>9 dp</b>. Canlı/oda öğesinde <b>iki profil üst üste</b>, sağ üstte <b>izleyici sayısı</b>.<br><br><b>6 · DÜZELTİLEN HATALAR (ölçüldü):</b> Dar telefonlarda (360dp) etkileşim satırı <b>taşıyor</b> ve kaydet ikonu ekran dışında kalıyordu. Alt menüdeki <b>logonun üst kenarına</b> basınca dokunuş alttaki gönderiye geçiyordu. Alt menü köşelerinde <b>sayfa geçişlerinde beyazlık</b> görünüyordu. Gönderi detayı <b>bomboş</b> açılıyordu (yerleşim hatası). Üçü de kapatıldı.<br><br><b>Dürüst sınırlar:</b> Bu sürümde ana sayfa <b>tasarım demosu</b> — gönderiler, yorumlar, canlı/oda ve izleyici sayıları <b>örnek veridir</b>, sunucudan gelmez ve dokunulduğunda <b>sunucuya hiçbir şey gitmez</b>. <b>Sponsorlu kart tıklanmaz</b> (reklam altyapısı yok). <b>Yeniden paylaş</b> ikonu paylaşma sayfasını açar (repost altyapısı yok).<br><br><b>Not:</b> Sunucu değişmedi; <b>hesaplar ve profiller duruyor</b>, yeniden kayıt olman gerekmiyor.</div>`

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
  [cikti.includes('GÖNDERİ DETAYI, YORUMLAR ve AKIŞ') &&
      cikti.includes('Gönderi sahibi'),
    'turu 98i icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
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
