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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — alım satım, etkinlik ve işletme menüleri:</b>
<br><br><b>0 · YAPAY ZEKÂ İLE GÖRSEL:</b> İşletme hesabında ürün eklerken
<b>"Yapay zekâ ile görsel oluştur"</b> de, ne istediğini yaz — ürün fotoğrafı
<b>senin için çizilir</b>. Beğenirsen kullanırsın, beğenmezsen atarsın (günde 10 hak).
<br><br><b>1 · İlanına GÖRSEL ve VİDEO:</b> Artık ilana <b>12 medyaya kadar</b> fotoğraf
<b>ve video</b> koyabilirsin. Galeri yan yana kayar; videolar oynatılır.
<br><br><b>2 · İlanı DÜZENLE:</b> Yayınladıktan sonra başlık, açıklama, fiyat, kategori,
il/ilçe, özellikler ve görselleri değiştirebilirsin. Düzenlenen ilanda
<b>"düzenlendi"</b> etiketi görünür — alıcı neyin değiştiğini bilir.
<br><br><b>3 · İLANA MESAJ:</b> İlan sayfasındaki <b>Mesaj gönder</b> ile satıcıya
doğrudan yazarsın. Bu sohbet <b>kişisel sohbetinden ayrıdır</b> ve listede
<b>"İlan: ..."</b> başlığıyla görünür — satıcı hangi ilan için yazıldığını görür.
<br><br><b>4 · Etkinliği DÜZENLE + KADRO:</b> Etkinliğe <b>görsel/video</b>, <b>bitiş
saati</b> ve <b>kadro</b> ekle — sahne alacak <b>sanatçı, oyuncu, konuşmacı</b>
isimlerini yazabilirsin (kayıtlı kullanıcıyı da ekleyebilirsin).
<br><br><b>5 · KAPAK GÖRSELİ + ONAY ROZETİ:</b> Profiline <b>arka plan kapak görseli</b>
koyabilirsin; logo/avatar ortada durur. Onaylı hesaplarda <b>mavi rozet</b> görünür.
İşletmelerde de aynısı.
<br><br><b>6 · KATEGORİ SAYFALARI:</b> Sol üstteki menüden bir kategoriye gir —
üstte <b>vitrin</b>, altında <b>hızlı kartlar</b> (Şehrimde · Onaylı), arama ve
işletme listesi.
<br><br><b>7 · YAPAY ZEKÂ İLE MENÜ:</b> Restoran sahibi <b>menü fotoğrafını çeker</b>
ya da <b>ne sattığını yazar</b>; ürünler otomatik çıkarılır. <b>Hepsi onayına
sunulur</b> — istediğini düzeltir, istemediğini atarsın.
<br><br><b>Sınırlar:</b> Harita ve "yakınımda" <b>henüz yok</b> (konum girişi eklenmedi);
şehir/ilçe ile süzülür. Arama <b>birebir</b> · Sohbet odası 20 konuşmacı + sınırsız
dinleyici · Canlı yayın 4 kişi + sınırsız izleyici.</div>`;

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
  [!/body\s*\{[^}]*align-items:\s*center/.test(cikti),
    'body flex ortalama GERI GELMIS (turu 50 regresyonu: saat kirpilir)'],
  [cikti.includes('YAPAY ZEKÂ İLE GÖRSEL') && cikti.includes('YAPAY ZEKÂ İLE MENÜ'),
    'turu 79 icerigi yazilmadi'],
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
console.log('index.html uretildi');
console.log('  saat        :', saat, `(${kacKez(saat)} yerde)`);
console.log('  surumEtiketi:', surumEtiketi);
console.log('  bayt        :', Buffer.byteLength(cikti));
