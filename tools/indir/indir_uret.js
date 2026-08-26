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

// ⚠️⚠️⚠️ TURU 134 — **SURUM NOTU BLOGU TAMAMEN KALDIRILDI** (kullanici emri:
//	*"aciklama yazma, indir sayfasini daha modern TEK SAYFA haline getir,
//	aciklama vb LOGO GEREK YOK, surum numarasi + saati + indirme linkleri
//	YETERLI"*).
//
// ⚠️⚠️ Onceki hal bir tuzakti: blok turu **126**`da kalmis ve 127-133
//	yayinlari boyunca guncellenmemisti, yani sayfa o build`de OLMAYAN
//	seyleri anlatiyordu. Muhafiz da yalnizca "metin VAR MI" diye baktigi
//	icin bunu YAKALAYAMIYORDU. Blok artik YOK; asagidaki muhafiz onun
//	GERI GELMEDIGINI de olcuyor.
let cikti = sablon
  .replace(/\{\{SAAT\}\}/g, saat)
  .replace(/\{\{SURUM\}\}/g, surumEtiketi);

// --- DOGRULAMA: sessizce yanlis sayfa uretmektense PATLA ---
const kacKez = (m) =>
  (cikti.match(new RegExp(m.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length;

const kontroller = [
  [!cikti.includes('{{'), 'DOLDURULMAMIS yer tutucu kaldi'],
  // ⚠️⚠️⚠️ TURU 134 — SAYFA SADELESTI, SAAT SAYISI **8 -> 5**e dustu:
  //	baslik · buyuk saat · iPhone dugmesi · Android dugmesi · dip satiri.
  //	(Kaldirilan yerler kaldirilan METINLERIN icindeydi; saatin KENDISI
  //	artik sayfanin ANA OGESI — 30 px, en ustte, mor kutunun icinde.)
  // ⚠️ YAPMA: bu sayiyi dusurmeden bir saat ogesi silme.
  [kacKez(saat) >= 5, `saat en az 5 yerde olmali (bulundu: ${kacKez(saat)})`],
  // ⚠️⚠️ EN GORUNUR SAAT (30 px, mor kutu). Kullanici YEDI KEZ "goremiyorum"
  //    dedi; artik sayfada ondan buyuk baska bir sey YOK.
  [cikti.includes('class="buyuksaat saatyaz"'),
    'BUYUK SAAT (buyuksaat) kayboldu — sayfadaki EN GORUNUR oge'],
  // ⚠️⚠️ Taze saat BUTUN saat ogelerine yazilmali. Yalniz birine yazilirsa
  //    bayat bir govdede DORT ESKI + BIR YENI saat gorunur; iki farkli saat,
  //    hic saat gostermemekten DAHA KOTU.
  [kacKez('saatyaz') >= 5,
    `saat ogelerinde .saatyaz sinifi eksik (bulundu: ${kacKez('saatyaz')})`],
  [cikti.includes("querySelectorAll('.saatyaz')"),
    'taze saat TEK YERE yaziliyor (turu 126: hepsine yazilmali)'],
  [cikti.includes(`?v=${surumEtiketi}`), 'apk surum sorgusu yazilmadi'],
  // ⚠️ SURUM ETIKETI de GORUNUR olmali (kullanici emri: "surum numarasi").
  [cikti.includes('class="surum"'), 'GORUNEN SURUM ETIKETI kayboldu'],
  [cikti.includes('id="ss"') && cikti.includes('setInterval'),
    'CANLI SAAT kayboldu (bayat-onbellek suphesini cozen tek sey)'],
  // ⚠️⚠️⚠️ NOBETCI 1 (ag GEREKTIRIR): sayfanin gomulu surumu `surum.json`
  //    ile karsilastirilir; eskiyse KIRMIZI SERIT + taze baglanti.
  // ⚠️ YAPMA: bu kontrolu kaldirma.
  [cikti.includes('id="bayat"') && cikti.includes('surum.json') &&
    cikti.includes("cache: 'no-store'"),
    'BAYAT SAYFA NOBETCISI kayboldu (surum.json karsilastirmasi)'],
  // ⚠️⚠️ NOBETCI 2 (ag GEREKTIRMEZ): adresteki `?v=` ile gomulu surum.
  //    Kisitli bir webview `fetch`i HIC tamamlamayabilir; bu blok yalnizca
  //    `location.search` okur, dolayisiyla DAIMA calisir.
  // ⚠️ YAPMA: ikisinden birini otekinin yerine gecirme — FARKLI arizalari
  //    yakalarlar (bayat GOVDE vs eski BAGLANTIYLA acilmis sayfa).
  [cikti.includes('location.search') && cikti.includes('[?&]v='),
    'ADRES SURUM NOBETCISI kayboldu (?v= karsilastirmasi)'],
  // ⚠️⚠️ NOBETCI 3: gorunen saatin KENDISI `surum.json`dan yazilir. Onceki
  //    iki nobetci durumu yalniz HABER VERIYORDU; bu, bayat bir govdede bile
  //    kullanicinin OKUDUGU saati DOGRU yapar.
  [cikti.includes('id="surumsaat"'),
    'CANLI SAAT KIMLIGI (surumsaat) kayboldu'],
  [cikti.includes('d.saat'),
    'saat `surum.json`dan YAZILMIYOR (turu 115b nobetcisi)'],
  [!/body\s*\{[^}]*align-items:\s*center/.test(cikti),
    'body flex ortalama GERI GELMIS (turu 50 regresyonu: saat kirpilir)'],
  // ⚠️⚠️⚠️ TURU 134 — **SAYFA SADE KALMALI** (kullanici emri: *"aciklama
  //	yazma ... surum numarasi saati ve indirme linkleri YETERLI"*).
  //
  //	Onceki muhafiz yalnizca "BU TURUN metni VAR MI" diye bakiyordu ve
  //	tam bu yuzden 127-133 boyunca sayfada duran BAYAT turu-126 blogunu
  //	YAKALAYAMADI. Artik olcut TERSINE cevrildi: aciklama blogu HIC
  //	OLMAMALI. Bir daha sessizce bayat metin tasinamaz.
  // ⚠️ YAPMA: sayfaya "Bu surumde" / ozellik listesi / SSS geri ekleme.
  [!cikti.includes('class="yeni"'),
    'ACIKLAMA BLOGU GERI GELMIS (kullanici emri: sayfa SADE)'],
  [!cikti.includes('GİRİŞ VE KAYIT BAŞTAN YAZILDI') &&
      !cikti.includes('Bu sürümde'),
    'ESKI SURUM NOTU sayfada KALMIS'],
  // ⚠️ Kullanici *"logo gerek yok"* dedi — sayfada gorsel ETIKETI olmamali.
  //    (favicon `<link rel="icon">` DEGIL; o sekme ikonudur ve sayfada
  //    cizilmez, bu yuzden olcut `<img` uzerinde.)
  [!/<img\b/i.test(cikti), 'LOGO/GORSEL geri gelmis (kullanici emri: logo YOK)'],
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
