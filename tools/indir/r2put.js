// R2'ye dosya yukler (S3 SigV4, harici bagimlilik YOK).
// Kullanim: node r2put.js <yerel-dosya> <anahtar> [content-type]
//
// ⚠️ .env.infra'da satir-sonu YORUMLARI var — deger okurken `\s+#.*` KESILIR
//    (CLAUDE.md kurali; yoksa imza bozulur ve 403 alinir).
// ⚠️ Cache-Control: no-cache -> CDN eski dosyayi tutmasin. Purge YINE DE SART.
const fs = require('fs');
const crypto = require('crypto');
const https = require('https');
const path = require('path');

const KOK = 'c:/Users/gebze/OneDrive/Desktop/gbz-a3';

function env() {
  const s = fs.readFileSync(path.join(KOK, '.env.infra'), 'utf8');
  const o = {};
  for (const satir of s.split(/\r?\n/)) {
    const m = satir.match(/^([A-Za-z0-9_]+)=(.*)$/);
    if (!m) continue;
    // ⚠️ satir-sonu yorumunu KES
    o[m[1]] = m[2].replace(/\s+#.*$/, '').trim().replace(/^["']|["']$/g, '');
  }
  return o;
}

const E = env();
const AKID = E.R2_ACCESS_KEY_ID;
const SECRET = E.R2_SECRET_ACCESS_KEY;
const ENDPOINT = E.R2_ENDPOINT.replace(/^https?:\/\//, '').replace(/\/$/, '');
const BUCKET = process.env.R2_TARGET_BUCKET || E.R2_DIST_BUCKET || 'gebzem-dist';
const REGION = 'auto';
const SERVICE = 's3';

function hmac(key, data) {
  return crypto.createHmac('sha256', key).update(data).digest();
}
function sha256hex(b) {
  return crypto.createHash('sha256').update(b).digest('hex');
}

function yukle(dosya, anahtar, ctype) {
  const govde = fs.readFileSync(dosya);
  const payloadHash = sha256hex(govde);
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const tarih = amzDate.slice(0, 8);

  const host = ENDPOINT;
  const canonicalUri = `/${BUCKET}/${anahtar}`;
  const cc = 'no-cache, no-store, must-revalidate';
  const basliklar = {
    'cache-control': cc,
    'content-type': ctype,
    host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
  };
  const imzaliAdlar = Object.keys(basliklar).sort();
  const canonicalHeaders =
    imzaliAdlar.map((k) => `${k}:${basliklar[k]}\n`).join('');
  const signedHeaders = imzaliAdlar.join(';');
  const canonical = [
    'PUT', canonicalUri, '', canonicalHeaders, signedHeaders, payloadHash,
  ].join('\n');

  const kapsam = `${tarih}/${REGION}/${SERVICE}/aws4_request`;
  const imzalanacak = [
    'AWS4-HMAC-SHA256', amzDate, kapsam, sha256hex(Buffer.from(canonical)),
  ].join('\n');

  let k = hmac(`AWS4${SECRET}`, tarih);
  k = hmac(k, REGION);
  k = hmac(k, SERVICE);
  k = hmac(k, 'aws4_request');
  const imza = crypto.createHmac('sha256', k).update(imzalanacak).digest('hex');

  const auth =
    `AWS4-HMAC-SHA256 Credential=${AKID}/${kapsam}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${imza}`;

  return new Promise((cz, rd) => {
    const req = https.request(
      {
        host, path: canonicalUri, method: 'PUT',
        headers: { ...basliklar, 'content-length': govde.length, authorization: auth },
      },
      (res) => {
        let c = '';
        res.on('data', (d) => (c += d));
        res.on('end', () =>
          res.statusCode === 200
            ? cz(`${anahtar} -> ${govde.length} bayt (md5 ${crypto.createHash('md5').update(govde).digest('hex').slice(0, 8)})`)
            : rd(new Error(`${res.statusCode}: ${c.slice(0, 400)}`)));
      },
    );
    req.on('error', rd);
    req.end(govde);
  });
}

const [dosya, anahtar, ctype] = process.argv.slice(2);
if (!dosya || !anahtar) {
  console.error('kullanim: node r2put.js <dosya> <anahtar> [content-type]');
  process.exit(1);
}
yukle(dosya, anahtar, ctype || 'application/octet-stream')
  .then((m) => console.log('OK', m))
  .catch((e) => { console.error('HATA', e.message); process.exit(1); });
