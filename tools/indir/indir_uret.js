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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — senin saydığın eksiklerin hepsi:</b><br><br><b>1 · &quot;Sosyal&quot; artık ANASAYFAYI açıyor</b> (aramaya gidiyordu).<br><br><b>2 · ARAMA TİKTOK TARZI:</b> yazınca sonuçlar sekmelere ayrılıyor — <b>Kullanıcılar · İşletmeler · Gönderiler · İlanlar · Ses · Yer</b>. Gönderi metni araması için <b>sunucuya yeni bir uç yazıldı</b> (daha önce hiç yoktu).<br><br><b>3 · YAKINIMDA YANDEX DÜZENİNDE:</b> harita <b>tam ekran</b>, altta çekilebilir panel — arama kutusu, hızlı kategori çipleri, <b>filtreler</b> (2/5 km · 4+ puan · kampanyalı · onaylı) ve <b>tam kategori ızgarası</b>. Kategori seçince harita ve liste birlikte süzülüyor.<br><br><b>4 · PROFİLDE SOL-SAĞ KAYDIRMA GERÇEK OLDU:</b> sekmeler artık parmağı takip ediyor (önceki sürümde sadece anında atlıyordu).<br><br><b>5 · HESABIM&#39;A YENİ SATIRLAR:</b> <b>İlanlarım · Hizmetlerim · Düğünüm · Taleplerim</b> — &quot;Başvurularım&quot; ve &quot;Diyetim&quot; ile aynı grupta.<br><br><b>6 · BİLDİRİMLER ARTIK DOLU</b> (tasarımı görebilmen için örnek içerik).<br><br><b>7 · MAHALLE:</b> akışta <b>Arkadaş · Keşfet · Mahalle</b>; Mahalle çevrendeki konumlu gönderileri gösteriyor.<br><br><b>Ayrıca:</b> düğün ve hizmet <b>adım adım</b> + yemek düzeninde · işletme hesabı <b>3 adımda</b> · randevular <b>ajanda</b> gibi · başvurularda durum özeti · ilan kartında <b>kim satıyor</b> · etkinlik kapağında tarih rozeti · mesajlarda <b>topluluk oluştur/keşfet</b> · GebzemAI sohbet arayüzü.<br><br><b>Dürüst sınırlar:</b> <b>Akaryakıt fiyatı</b> bu projede hiçbir yerde yok — o yüzden Yakınımda&#39;da fiyat aralığı filtresi <b>koymadım</b>; uydurma bir aralık yanlış bilgi olurdu. Filtreler sunucunun gerçekten döndürdüğü alanlardan. Mahalle yalnız <b>konum paylaşılmış</b> gönderileri gösterir. GebzemAI&#39;da akan yazı yok, sohbet kaydedilmiyor. Ana sayfadaki gönderiler, örnek ilanlar ve bildirimler <b>tasarım demosudur</b>.<br><br><b>Not:</b> Sunucu güncellendi; <b>hesaplar ve profiller duruyor</b>.</div>`

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
  [!/body\s*\{[^}]*align-items:\s*center/.test(cikti),
    'body flex ortalama GERI GELMIS (turu 50 regresyonu: saat kirpilir)'],
  // ⚠️ ICERIK MUHAFIZI **BU SURUME** SABITLENIR (her turda guncellenir).
  //    Amaci: sablon degistirilip `YENI_ICERIK` guncellenmeden sayfa
  //    uretilmesini ENGELLEMEK — yoksa kullaniciya BIR ONCEKI surumun
  //    notlari gosterilir ve "yeni ne var" yalan olur.
  // ⚠️ YAPMA: bu satiri silme; yeni turda ANAHTAR IFADEYI degistir.
  [cikti.includes('ARAMA TİKTOK TARZI') &&
      cikti.includes('YAKINIMDA YANDEX DÜZENİNDE'),
    'turu 115 icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
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
