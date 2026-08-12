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

/// `tohum` sayisina gore DETERMINISTIK bir kapak uretir.
/// ⚠️ Deterministik olmasi SART: ayni isletme her tohumlamada AYNI kapagi
///    alir, yani "gorsel degisti mi" sorusu bir HATA sinyali olur.
function kapakUret(tohum, genislik = 1200, yukseklik = 675) {
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
  const serit = 46 + (tohum % 3) * 14; // serit araligi kapaktan kapaga degisir
  const ix = genislik * 0.72;
  const iy = yukseklik * 0.18;
  const iR = Math.min(genislik, yukseklik) * 0.85;

  for (let y = 0; y < yukseklik; y++) {
    const satirBas = y * satirBayt;
    ham[satirBas] = 0;
    for (let x = 0; x < genislik; x++) {
      // 1) capraz gradyan
      let k = (x / genislik) * 0.62 + (y / yukseklik) * 0.38;

      // 2) capraz seritler (ince, koyu/acik dalgalanma)
      const s = ((x + y) % serit) / serit;
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

module.exports = { kapakUret };

// Dogrudan calistirilirsa ornek uretir (elle goz kontrolu icin).
if (require.main === module) {
  const fs = require('fs');
  for (let i = 0; i < 3; i++) {
    const p = `kapak-ornek-${i}.png`;
    fs.writeFileSync(p, kapakUret(i));
    console.log(p, fs.statSync(p).size, 'bayt');
  }
}
