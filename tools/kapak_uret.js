// Bagimliliksiz PNG uretici — tohum verisi icin **KAPAK GORSELI** olusturur.
//
// ⚠️⚠️ NEDEN VAR: turu 93 isletme kartlari 16:9 kapak ciziyor. Tohumdaki
//	isletmelerin HICBIRINDE kapak olmasaydi kullanici YALNIZ yer tutucu
//	dalini gorurdu; gercek kapak yolu (yukle -> liste -> imzali adres ->
//	16:9 cizim) **CIHAZDA HIC SINANMAZDI**. Bu projede "yalnizca ikinci
//	hesapta gorunen" medya hatalari DORT KEZ sahaya cikti.
//
// ⚠️ Uretilen gorsel bir FOTOGRAF DEGIL, desenli bir kapaktir. Sahte yemek
//    fotografi uretmek (AI ile) hem PARA harcar hem gunluk kotayi yer hem de
//    `kind='kapak'` kapisindan gecmez (AI ucu `kind='image'` uretir).
//
// ⚠️ HARICI BAGIMLILIK YOK: yalniz `zlib` + `crypto` (projenin `r2put.js`
//    deseniyle ayni ilke).

const zlib = require('zlib');

// ---- CRC32 (PNG chunk'lari icin) ----
const CRC = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(tip, veri) {
  const uzunluk = Buffer.alloc(4);
  uzunluk.writeUInt32BE(veri.length);
  const govde = Buffer.concat([Buffer.from(tip, 'ascii'), veri]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(govde));
  return Buffer.concat([uzunluk, govde, crc]);
}

/// HSL -> RGB (0-255). Renk uretimini okunur tutmak icin.
function hsl(h, s, l) {
  h = ((h % 360) + 360) % 360;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let r = 0;
  let g = 0;
  let b = 0;
  if (h < 60) [r, g, b] = [c, x, 0];
  else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x];
  else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  return [
    Math.round((r + m) * 255),
    Math.round((g + m) * 255),
    Math.round((b + m) * 255),
  ];
}

/// ⚠️⚠️⚠️ TOHUM **NORMALIZE EDILIR** — METIN tohum NaN uretiyordu.
///
///	Asagidaki iki uretecin govdesinde `tohum % PALET.length` var.
///	Cagiran bir METIN gecirirse (`kapakUret(urun.ad, ...)`) bu ifade
///	**NaN** olur, `PALET[NaN]` **undefined** doner ve destructure
///	(`const [h0, doygun] = ...`) PATLAR:
///	  "undefined is not iterable (cannot read property Symbol(Symbol.iterator))"
///	Turu 181de `tools/urun_gorsel.js` tam bunu yasadi — **45 urunun 45i**.
///
/// ⚠️⚠️ Uyari `tohum_sosyal.js` icinde YAZILIYDI ama KORUMA CAGRI
///	YERINDEYDI; yeni bir cagiran o serhi HIC gormeden ayni hataya
///	dustu. Koruma artik **TEK KAYNAKTA** (burada) — metin gecirmek
///	YAPISAL OLARAK guvenli.
///
/// ⚠️ Deterministik olmak ZORUNDA (FNV-1a): ayni ad DAIMA ayni gorseli
///	verir, yani "gorsel degisti mi" sorusu bir HATA sinyali olarak kalir.
/// ⚠️ SAYILAR DEGISMEZ: mevcut cagiranlar (tohum.js · tohum_sosyal.js)
///	tamsayi geciriyor ve BIREBIR ayni gorseli almaya devam eder.
/// ⚠️ Negatif/ondalikli sayi da guvenli (`abs` + `trunc`): negatif indeks
///	yine `undefined` dondururdu.
function tohumSayi(t) {
  if (typeof t === 'number' && Number.isFinite(t)) return Math.abs(Math.trunc(t));
  const s = String(t == null ? '' : t);
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h;
}
/// `tohum` sayisina gore DETERMINISTIK bir kapak uretir.
/// ⚠️ Deterministik olmasi SART: ayni isletme her tohumlamada AYNI kapagi
///    alir, yani "gorsel degisti mi" sorusu bir HATA sinyali olur.
function kapakUret(tohum, genislik = 1200, yukseklik = 675) {
  tohum = tohumSayi(tohum); // ⚠️ metin tohum NaN uretirdi — bkz. tohumSayi
  // ⚠️ PALET SECILI: rastgele hue "haki yesil" gibi itici tonlar uretiyordu
  //    (ilk denemede tam bu oldu). Sabit bir listeden secmek, HER kapagin
  //    sunulabilir olmasini GARANTI eder.
  const PALET = [
    [352, 0.72], // kirmizi
    [22, 0.80], // turuncu
    [268, 0.55], // mor
    [200, 0.62], // mavi
    [158, 0.48], // yesil-teal
    [330, 0.58], // pembe
  ];
  const [h0, doygun] = PALET[tohum % PALET.length];
  const [r1, g1, b1] = hsl(h0, doygun, 0.52); // acik uc
  const [r2, g2, b2] = hsl(h0 + 26, doygun * 0.9, 0.22); // koyu uc

  // Ham piksel satirlari: her satirin basinda PNG filtre baytı (0 = None).
  const satirBayt = genislik * 3 + 1;
  const ham = Buffer.alloc(satirBayt * yukseklik);

  // ⚠️ DESEN: duz gradyan kartta "bos bir renk blogu" gibi duruyordu.
  //    Uc katman eklendi — capraz gradyan + CAPRAZ SERITLER + yumusak isik
  //    lekesi. Ucu de 16:9 kirpmada ayakta kalir (kose bagimli desen,
  //    kirpilinca anlamsizlasirdi).
  // ⚠️⚠️⚠️ VARYANT: DESENI PALETTEN **BAGIMSIZ** DEGISTIRIR.
  //
  //	ESKI HALI KORELELIYDI: desen `tohum % 3`ten, palet `tohum % 6`dan
  //	geliyordu. `n % 6` matematiksel olarak `n % 3`u BELIRLER — yani
  //	ayni palete dusen iki tohum **BIREBIR AYNI BAYTI** uretiyordu.
  //	OLCULDU: sekiz urun adindan yalniz **4 farkli gorsel** cikti
  //	(5 ad ayni md5). Sirali tamsayilarda (tohum.js 0..13) gorunmuyordu
  //	cunku ardisik sayilar paletleri dolasiyor; ama MENU SERIDINDE ayni
  //	isletmenin 5 urunu YAN YANA durur ve ayni resmin tekrari
  //	**bos gri kutudan pek de iyi degildir**.
  //
  // ⚠️⚠️ MEVCUT TOHUMLAR **BIREBIR KORUNUR**: varyant tohumun 256'dan
  //	BUYUK kismindan turer, yani `tohum < 256` iken **0**'dir ve ucu de
  //	eski degerlerine coker (serit `46 + (tohum%3)*14`, yon 0, isik sag).
  //	`tohum.js` 0..13, `tohum_sosyal.js` kucuk tamsayi kullaniyor ->
  //	onlarin kapaklari DEGISMEDI (bayt bayt dogrulandi).
  //	Metin tohumlar 32 bitlik FNV-1a uretir -> varyant dolu gelir.
  // ⚠️ Cesitlilik: 6 palet x 3 serit x 2 yon x 2 isik kosesi = **72**.
  // ⚠️ YAPMA: seriti tekrar dogrudan `tohum % 3`e baglama (korelasyon geri gelir).
  const varyant = Math.floor(tohum / 256);
  const serit = 46 + (((tohum % 3) + varyant) % 3) * 14;
  const yon = (varyant >>> 2) & 1; // 0: sol-ust -> sag-alt · 1: sag-ust -> sol-alt
  const isikSol = (varyant >>> 5) & 1; // isik lekesi hangi ust kosede
  const ix = genislik * (isikSol ? 0.28 : 0.72);
  const iy = yukseklik * 0.18;
  const iR = Math.min(genislik, yukseklik) * 0.85;

  for (let y = 0; y < yukseklik; y++) {
    const satirBas = y * satirBayt;
    ham[satirBas] = 0;
    for (let x = 0; x < genislik; x++) {
      // 1) capraz gradyan
      let k = (x / genislik) * 0.62 + (y / yukseklik) * 0.38;

      // 2) capraz seritler (ince, koyu/acik dalgalanma)
      // ⚠️ `x - y + yukseklik` DAIMA >= 0 (y <= yukseklik): negatif mod
      //	JS'te negatif doner ve serit deseni koseye dogru BOZULURDU.
      const capraz = yon ? x - y + yukseklik : x + y;
      const s = (capraz % serit) / serit;
      k += (s < 0.5 ? 0.045 : -0.045) * (0.6 + 0.4 * Math.sin(s * Math.PI));

      k = Math.min(1, Math.max(0, k));
      let r = r1 + (r2 - r1) * k;
      let g = g1 + (g2 - g1) * k;
      let b = b1 + (b2 - b1) * k;

      // 3) sag ustte yumusak isik lekesi (kartlara derinlik verir)
      const d = Math.hypot(x - ix, y - iy) / iR;
      if (d < 1) {
        const isik = (1 - d) * (1 - d) * 0.38;
        r += (255 - r) * isik;
        g += (255 - g) * isik;
        b += (255 - b) * isik;
      }

      const i = satirBas + 1 + x * 3;
      ham[i] = Math.round(r);
      ham[i + 1] = Math.round(g);
      ham[i + 2] = Math.round(b);
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(genislik, 0);
  ihdr.writeUInt32BE(yukseklik, 4);
  ihdr[8] = 8; // bit derinligi
  ihdr[9] = 2; // renk tipi: truecolor (RGB)
  ihdr[10] = 0; // sikistirma
  ihdr[11] = 0; // filtre
  ihdr[12] = 0; // interlace YOK

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(ham, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/// ⚠️⚠️⚠️ TURU 180z — **PROFIL FOTOGRAFI (AVATAR)** uretir (kullanici emri:
/// *"5-6 tane sohbet olsun bunlarda fotograf olsun, profil fotograflari
/// yani GERCEK BIR SOHBET ALANI gibi olsun"*).
///
/// **NEDEN GEREKLI:** tohumdaki hesaplarin HICBIRINDE avatar yoktu; sohbet
/// listesi, sohbet basligi, mesaj balonlari ve kanal profili hep HARFLI
/// daireye dusuyordu. Yani "avatar yuklendi -> imzali adres -> daire icinde
/// cizim" zinciri CIHAZDA HIC SINANMIYORDU (bu projede "yalnizca ikinci
/// hesapta gorunen" medya hatalari DORT KEZ sahaya cikti).
///
/// ⚠️ Uretilen sey bir FOTOGRAF DEGIL, **silüetli bir avatar**tir: gradyan
///	zemin + beyaz bas/govde. Sahte insan fotografi uretmek (AI ile) hem
///	PARA harcar hem de bir insanin yuzunu UYDURMAK olurdu.
/// ⚠️ Deterministik: ayni tohum ayni avatari verir — "gorsel degisti mi"
///	sorusu bir HATA sinyali olur.
/// ⚠️ KARE uretilir: avatar daire icine kirpiliyor; dikdortgen bir kaynak
///	`cover` ile yanlardan KIRPILIRDI.
function avatarUret(tohum, kenar = 512) {
  tohum = tohumSayi(tohum); // ⚠️ metin tohum NaN uretirdi — bkz. tohumSayi
  // ⚠️ Palet kapakla AYNI kaynaktan DEGIL: avatarlar yan yana cizilir
  //	(sohbet listesi) ve birbirinden AYIRT EDILEBILMELI. Doygunluk daha
  //	yuksek, aciklik daha dar bir aralikta.
  const TON = [210, 268, 340, 22, 158, 44, 300, 186];
  const h0 = TON[tohum % TON.length];
  const [r1, g1, b1] = hsl(h0, 0.58, 0.56);
  const [r2, g2, b2] = hsl(h0 + 24, 0.62, 0.34);

  const satirBayt = kenar * 3 + 1;
  const ham = Buffer.alloc(satirBayt * kenar);

  // Silüet olculeri (kenar oranina gore — her boyutta AYNI gorunur).
  const kafaMerkezX = kenar / 2;
  const kafaMerkezY = kenar * 0.38;
  const kafaR = kenar * 0.155;
  // Govde: merkezi asagida olan buyuk bir daire; alt kenardan tasar ve
  // "omuz" izlenimi verir.
  const govdeMerkezX = kenar / 2;
  const govdeMerkezY = kenar * 1.02;
  const govdeR = kenar * 0.35;

  for (let y = 0; y < kenar; y++) {
    const satirBas = y * satirBayt;
    ham[satirBas] = 0; // PNG filtre bayti (0 = None)
    for (let x = 0; x < kenar; x++) {
      // Capraz gradyan
      const t = (x / kenar) * 0.5 + (y / kenar) * 0.5;
      let r = r1 + (r2 - r1) * t;
      let g = g1 + (g2 - g1) * t;
      let b = b1 + (b2 - b1) * t;

      // Silüet: kafa VEYA govde dairesinin icindeyse beyaza dogru karistir.
      const dk = Math.hypot(x - kafaMerkezX, y - kafaMerkezY);
      const dg = Math.hypot(x - govdeMerkezX, y - govdeMerkezY);
      // ⚠️ Yumusak kenar (1,5 px): sert kenar 512 px'te bile TIRTIKLI
      //	gorunuyordu (daire icine kirpilinca daha da belli oluyor).
      const kapama = Math.max(
        Math.min(1, (kafaR - dk) / 1.5),
        Math.min(1, (govdeR - dg) / 1.5),
      );
      if (kapama > 0) {
        const a = Math.min(1, kapama) * 0.92;
        r = r + (255 - r) * a;
        g = g + (255 - g) * a;
        b = b + (255 - b) * a;
      }

      const i = satirBas + 1 + x * 3;
      ham[i] = Math.round(r);
      ham[i + 1] = Math.round(g);
      ham[i + 2] = Math.round(b);
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(kenar, 0);
  ihdr.writeUInt32BE(kenar, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(ham, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

module.exports = { kapakUret, avatarUret, tohumSayi };

// Dogrudan calistirilirsa ornek uretir (elle goz kontrolu icin).
if (require.main === module) {
  const fs = require('fs');
  for (let i = 0; i < 3; i++) {
    const p = `kapak-ornek-${i}.png`;
    fs.writeFileSync(p, kapakUret(i));
    console.log(p, fs.statSync(p).size, 'bayt');
  }
}
