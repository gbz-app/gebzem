// Yayin adimlarini SIRAYLA kosar ve her adimi DOGRULAR.
//
// Kullanim: node tools/indir/yayinla.js <yerel-ipa-yolu>
//
// ⚠️ Sira CLAUDE.md "DAGITIM KONTROL LISTESI" ile AYNI:
//    1) index.html + surum.json uret (ureticinin kendi muhafizlari var)
//    2) ipa + index.html + surum.json -> R2
//    3) Cloudflare purge
//    4) CDN'den indir, **MD5 KARSILASTIR** ("boyut ayni = build eski" DEME)
// ⚠️ Herhangi bir adim patlarsa SUREC DURUR (exit 1): yarim yayin,
//    yayinlamamaktan DAHA KOTU.
const { execFileSync } = require('child_process');
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const DIZIN = __dirname;
const ipa = process.argv[2];
if (!ipa || !fs.existsSync(ipa)) {
  console.error('IPA yolu gerekli: node tools/indir/yayinla.js <ipa>');
  process.exit(1);
}

const kos = (args) =>
  execFileSync(process.execPath, args, { cwd: path.join(DIZIN, '..', '..'), stdio: 'inherit' });

const md5 = (b) => crypto.createHash('md5').update(b).digest('hex');

// 1) sayfa
kos([path.join(DIZIN, 'indir_uret.js')]);

// 2) yukleme
fs.copyFileSync(ipa, path.join(DIZIN, 'gebzem.ipa'));
const yuk = [
  ['gebzem.ipa', 'gebzem.ipa', 'application/octet-stream'],
  ['index.html', 'index.html', 'text/html; charset=utf-8'],
  ['surum.json', 'surum.json', 'application/json'],
];
for (const [dosya, anahtar, tip] of yuk) {
  kos([path.join(DIZIN, 'r2yukle.js'), path.join(DIZIN, dosya), anahtar, tip]);
}

// 3) purge
kos([path.join(DIZIN, 'purge.js')]);

// 4) CDN dogrulama
(async () => {
  let hata = 0;
  for (const [dosya, anahtar] of yuk) {
    const yerel = fs.readFileSync(path.join(DIZIN, dosya));
    const r = await fetch(`https://indir.gebzem.app/${anahtar}?t=${Date.now()}`, {
      cache: 'no-store',
    });
    const uzak = Buffer.from(await r.arrayBuffer());
    const ok = md5(yerel) === md5(uzak);
    console.log(
      `${anahtar.padEnd(12)} ${r.status} yerel=${yerel.length} cdn=${uzak.length} ` +
        `md5 ${md5(yerel).slice(0, 8)}/${md5(uzak).slice(0, 8)} ${ok ? 'BIREBIR' : 'FARKLI!'}`,
    );
    if (!ok) hata++;
  }
  if (hata) {
    console.error('CDN DOGRULAMA BASARISIZ — yayin TAMAMLANMADI');
    process.exit(1);
  }
  const s = JSON.parse(fs.readFileSync(path.join(DIZIN, 'surum.json'), 'utf8'));
  console.log('');
  console.log('ADRES: https://indir.gebzem.app/index.html?v=' + s.v);
})();
