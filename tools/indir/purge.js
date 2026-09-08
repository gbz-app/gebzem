// Cloudflare zone purge — indir.gebzem.app.
//
// ⚠️ Global API Key ile: `X-Auth-Email` + `X-Auth-Key` (Bearer CALISMAZ).
// ⚠️ `.env.infra`da satir-sonu YORUMLARI var — deger okurken `\s+#.*` KESILIR.
// ⚠️ Purge OLMADAN CDN eski dosyayi servis eder (dagitim kontrol listesi md 4).
const fs = require('fs');
const https = require('https');
const path = require('path');

const KOK = 'c:/Users/gebze/OneDrive/Desktop/gbz-a3';
const ZONE = 'a8af9ee51c2c3ed70cc30d705038abfd';

function env() {
  const s = fs.readFileSync(path.join(KOK, '.env.infra'), 'utf8');
  const o = {};
  for (const satir of s.split(/\r?\n/)) {
    const m = satir.match(/^([A-Za-z0-9_]+)=(.*)$/);
    if (!m) continue;
    o[m[1]] = m[2].replace(/\s+#.*$/, '').trim().replace(/^["']|["']$/g, '');
  }
  return o;
}

const E = env();
const govde = JSON.stringify({ purge_everything: true });
const istek = https.request(
  {
    host: 'api.cloudflare.com',
    path: `/client/v4/zones/${ZONE}/purge_cache`,
    method: 'POST',
    headers: {
      'X-Auth-Email': E.CF_GLOBAL_EMAIL,
      'X-Auth-Key': E.CF_GLOBAL_KEY,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(govde),
    },
  },
  (y) => {
    let g = '';
    y.on('data', (d) => (g += d));
    y.on('end', () => {
      let ok = false;
      try {
        ok = JSON.parse(g).success === true;
      } catch (_) {}
      console.log('purge', y.statusCode, ok ? 'OK' : g.slice(0, 200));
      if (!ok) process.exit(1);
    });
  },
);
istek.on('error', (e) => {
  console.error('purge HATA:', e.message);
  process.exit(1);
});
istek.end(govde);
