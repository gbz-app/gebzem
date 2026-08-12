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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde:</b><br><br><b>1 · KATEGORİ EKRANI BAŞTAN TASARLANDI:</b> Üstte sade bir <b>başlık şeridi</b> (solda geri, sağda harita), altında <b>kayan tanıtım</b> — 3 saniyede bir değişir, düğme yoktur. Onun altında <b>İşletme ara</b>, sonra <b>küçük kartlar</b>, en altta <b>Filtrele</b> ve sık kullanılan süzgeçler. Artık her şey <b>tek bir hizada</b>; sağ-sol boşluklar birbirini tutuyor.<br><br><b>2 · İŞLETME KARTLARI YEMEK UYGULAMALARINDAKİ GİBİ:</b> Her işletmenin <b>geniş kapak görseli</b>, altında adı, onaylıysa rozeti, kategorisi ve ilçesi. Kapak yoksa profil fotoğrafı, o da yoksa <b>işletmenin baş harfiyle renkli bir kapak</b> çizilir — <b>hiçbir kartta kırık görsel çıkmaz</b>.<br><br><b>3 · ARAMA KUTUSU:</b> Dokununca çerçevesi <b>siyaha</b> döner, arama ikonu biraz daha belirgin. Süzgeç düğmeleri de aynı dili konuşuyor — <b>renk karmaşası yok</b>.<br><br><b>4 · HER KATEGORİ KENDİNE ÖZEL:</b> Yemek&#39;te Döner/Kebap/Pide, Kuaför&#39;de Saç Kesim/Boya, Otel&#39;de Butik/Apart... Bir karta dokun, liste anında süzülsün. Sağ üstteki <b>harita</b> ile o kategorinin işletmelerini haritada gör.<br><br><b>5 · DÜĞÜN &amp; HİZMET TEKLİF İSTEĞİ:</b> Menüden <b>Düğün &amp; Organizasyon</b>&#39;a gir, <b>adım adım</b> cevapla (tarih, kişi sayısı, kapalı salon mu dış mekân mı, bütçe). Talebin ilgili işletmelere gider, sana <b>fiyatlı karşı teklif</b> verirler; <b>ucuzdan pahalıya sıralı</b> görür, birini <b>seçersin</b>.<br><br><b>6 · DİYET TAKİBİ:</b> <b>Diyetim</b>&#39;de gün gün öğün ekle (yiyecek ara, gramı kaydır, kalori anında), ölçüm gir. Bir diyetisyenle bağlantı kurunca sana <b>haftalık liste</b> gönderebilir. Diyetisyensen <b>Danışanlarım</b>&#39;dan onaylar, liste yazarsın.<br><br><b>7 · HAZIR TEST HESAPLARI:</b> Veritabanı sıfırlandı; <b>18 işletme</b> (6 restoran + 2 kafe + doktor, diyetisyen, kuaför, güzellik, otel) + 2 kullanıcı, <b>10/10&#39;undan randevu alınabiliyor</b>, hazır bir <b>düğün talebi + 3 teklif</b> ve <b>dolu bir diyet günü</b> var — hesap listesi ayrıca verildi.<br><br><b>Sınırlar:</b> Teklif isteğin <b>7 gün</b> açık kalır, en fazla <b>5 teklif</b> alır. Talepler <b>herkese açıktır</b> — telefon/adres yazma. Otel odaları hâlâ <b>vitrin</b>. İşletme kartlarında <b>puan, teslimat süresi ve minimum tutar YOKTUR</b>: bu veriler projede henüz üretilmiyor, uydurma değer göstermek istemedik. Ödeme yok.</div>`;

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
  // ⚠️ ICERIK MUHAFIZI **BU SURUME** SABITLENIR (her turda guncellenir).
  //    Amaci: sablon degistirilip `YENI_ICERIK` guncellenmeden sayfa
  //    uretilmesini ENGELLEMEK — yoksa kullaniciya BIR ONCEKI surumun
  //    notlari gosterilir ve "yeni ne var" yalan olur.
  // ⚠️ YAPMA: bu satiri silme; yeni turda ANAHTAR IFADEYI degistir.
  [cikti.includes('KATEGORİ EKRANI BAŞTAN TASARLANDI') &&
   cikti.includes('YEMEK UYGULAMALARINDAKİ GİBİ'),
    'turu 93 icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
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
