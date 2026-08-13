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

const YENI_ICERIK = `<div class="yeni"><b>Bu sürümde — KATEGORİ EKRANI BAŞTAN DÜZENLENDİ:</b><br><br><b>1 · KONUM:</b> Sol üstte <b>konum düğmesi</b>. Dokun, <b>Yeni konum ekle</b> ile bulunduğun yeri <b>Ev</b> ya da <b>İş</b> diye kaydet. Kaydettiğin konum işletme kartlarındaki <b>uzaklığı</b> besler (<b>1,2 km</b> / <b>300 m</b>). <b>Not:</b> konumlar şimdilik <b>telefonda</b> saklanıyor — uygulamayı silersen kaybolur.<br><br><b>2 · KEŞİF KARTLARI:</b> Kayan alanın altında <b>8 kart</b> — <b>Ne Yesem?</b> (rastgele bir işletme açar), <b>İndirimli</b>, <b>4+</b>, <b>Şimşek</b> (en hızlı), <b>Yakınımda</b>, <b>Gece Kuşu</b> (geç saate kadar açık), <b>Yeni Restourant</b>, <b>Favori</b>. Sekizi de gerçekten süzüyor/sıralıyor.<br><br><b>3 · FİLTRELEME:</b> Süzgeç şeridindeki <b>Filtre</b>ye dokun — tam ekran açılır: Sıralama, Minimum sepet tutarı, Puan, Teslimat süresi, Kampanyalı, Şu an açık, Gece Kuşu. Altta <b>Listele</b> ve <b>Temizle</b>.<br><br><b>4 · MUTFAKLAR:</b> Arama kutusunun altında <b>Mutfaklar</b> başlığı ve Döner/Kebap/Pide — <b>her kategori kendine özel</b> (Kuaför&#39;de Saç Kesim/Boya...).<br><br><b>5 · GÖRÜNÜM:</b> Liste başlığında solda <b>İşletmeler (N)</b>, sağda tek kutuda <b>liste · kart · harita</b>; aktif olan gri zeminle işaretli.<br><br><b>6 · TASARIM:</b> Yeşil vurgular kaldırıldı — seçili her şey <b>siyah kenarlık</b>. Köşe yuvarlaklığı tek kurala bağlandı. Tüm bölümler <b>ekrandan piksel piksel ölçülerek</b> hizalandı (hepsi 16 dp). Kayan alanda <b>yandaki slaytlar</b> hafifçe görünüyor.<br><br><b>7 · HAZIR TEST HESAPLARI:</b> Veritabanı sıfırlandı; <b>14 işletme</b> (2 restoran + 2 kafe + doktor, diyetisyen, kuaför, güzellik, otel) + 2 kullanıcı, <b>14/14&#39;ünden randevu alınabiliyor</b>, hazır bir <b>düğün talebi + 3 teklif</b> ve <b>dolu bir diyet günü</b> var — hesap listesi ayrıca verildi.<br><br><b>Sınırlar:</b> Karttaki <b>puan, teslimat süresi ve minimum tutar</b> işletmenin girdiği değerlerdir; <b>değerlendirme sistemi ve sipariş/kurye modeli henüz yok</b>. Filtrede <b>ödeme yöntemi</b> bölümü yok — o veri hiç tutulmuyor, boş seçenek koymadık. <b>Yeni Restourant</b> kartı <b>puanı olmayan</b> işletmeleri gösterir (kayıt tarihi henüz sunucuda yok), tohumdaki herkesin puanı olduğu için <b>şimdilik boş döner</b>. Süzme <b>uygulama içinde</b> yapılıyor (ilk 60 kayıt). Kategori ekranında <b>geri düğmesi yok</b> — telefonun geri tuşu/kenar çekme ile çıkılır. Kayan alan hâlâ <b>boş</b>. Teklif isteğin <b>7 gün</b> açık kalır, en fazla <b>5 teklif</b> alır. Talepler <b>herkese açıktır</b> — telefon/adres yazma. Ödeme yok.</div>`;

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
  [cikti.includes('Gece Kuşu') && cikti.includes('Yeni konum ekle'),
    'turu 96f icerigi yazilmadi (YENI_ICERIK guncellenmemis)'],
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
