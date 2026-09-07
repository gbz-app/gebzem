// Otele COK FOTOGRAFLI bir oda ekler (turu 180o galeri dogrulamasi).
//
// Kullanici sorusu: *"otel odasinda galeri vs bu galeriler aciliyor mu,
// her sey var mi?"* — cevabi kanitlamak icin GERCEK veri gerekiyordu:
// `tools/tohum.js` urunlerin `media_ids` alanini BOS birakiyor, yani
// galeriyi gosterecek tek bir kayit bile yoktu.
//
// ⚠️ BUILD GEREKTIRMEZ mi? Bu betik yalniz VERI yazar; galeriyi cizen
//	arayuz turu 180o'da eklendi, yani onu gormek icin YENI BUILD sart.
// ⚠️ Medya API'DEN GECMEZ (turu 75): presign -> R2'ye DOGRUDAN PUT ->
//	commit. `Content-MD5` imzaya dahildir (turu 74b).
// ⚠️ Urun PATCH'i medyaya DOKUNMAZ (urun.go): mevcut bir odanin
//	fotograflari DEGISTIRILEMEZ, bu yuzden YENI oda eklenir.
//
// Kullanim: node tools/oda_galeri.js
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const API = process.env.API_URL || 'https://api.gebzem.app';
const TEL = '+905551050001'; // Gebze Park Otel (tools/tohum.js)
const SIFRE = 'Gebzem2026!';
const KOK = path.join(__dirname, '..');

// ⚠️ Elimizde otel odasi fotografi YOK; `assets/marka` altindaki menu
//	gorselleri ORNEK/TANITIM verisidir ve yalniz galeriyi KANITLAMAK
//	icin kullanilir. Gercek yayin oncesi bu kayit da kaldirilmali.
const FOTOLAR = [
  'mobile/assets/marka/menu_bigmac.png',
  'mobile/assets/marka/menu_cheeseburger.png',
  'mobile/assets/marka/menu_patates.png',
  'mobile/assets/marka/menu_tavuk.png',
];

async function jsonIstek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(API + yol, {
    method: yontem,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: 'Bearer ' + token } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const t = await r.text();
  let d = null;
  try { d = JSON.parse(t); } catch { /* metin */ }
  return { kod: r.status, d, ham: t };
}

// ⚠️ Olcu GERCEKTEN okunur (turu 81): `media_assets.width/height` bos
//	kalirsa istemci medya kutusunu ORANSIZ cizer.
function pngOlc(bayt) {
  // PNG IHDR: 8 bayt imza + 4 uzunluk + 4 tip, sonra 4+4 genislik/yukseklik.
  return { w: bayt.readUInt32BE(16), h: bayt.readUInt32BE(20) };
}

async function medyaYukle(token, yol) {
  const tam = path.join(KOK, yol);
  const bayt = fs.readFileSync(tam);
  const { w, h } = pngOlc(bayt);
  const md5 = crypto.createHash('md5').update(bayt).digest('base64');

  const p = await jsonIstek('/media/upload', {
    yontem: 'POST', token,
    govde: {
      kind: 'image', mime: 'image/png', bytes: bayt.length, md5,
      file_name: path.basename(tam), width: w, height: h,
      thumb_bytes: 0, thumb_md5: '', duration_ms: 0,
    },
  });
  if (p.kod !== 200) throw new Error('presign ' + p.kod + ': ' + p.ham.slice(0, 200));

  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/png', 'Content-MD5': md5 },
    body: bayt,
  });
  if (!put.ok) throw new Error('R2 PUT ' + put.status);

  const c = await jsonIstek('/media/' + p.d.media_id + '/commit', { yontem: 'POST', token });
  if (c.kod !== 200) throw new Error('commit ' + c.kod + ': ' + c.ham.slice(0, 200));
  return { id: p.d.media_id, w, h, bayt: bayt.length };
}

(async () => {
  const giris = await jsonIstek('/auth/login', {
    yontem: 'POST', govde: { phone: TEL, password: SIFRE },
  });
  if (giris.kod !== 200) throw new Error('giris ' + giris.kod + ': ' + giris.ham.slice(0, 200));
  const token = giris.d.token;
  const benim = giris.d.user_id;
  console.log('giris OK  kullanici=' + benim);

  const idler = [];
  for (const f of FOTOLAR) {
    const m = await medyaYukle(token, f);
    idler.push(m.id);
    console.log('  yuklendi ' + path.basename(f) + '  ' + m.w + 'x' + m.h + '  ' + m.bayt + ' B  id=' + m.id);
  }

  const eklendi = await jsonIstek('/isletme/urunler', {
    yontem: 'POST', token,
    govde: {
      ad: 'Deluxe Suit (galeri testi)',
      aciklama: 'Deniz manzarali, genis balkonlu suit. Dort fotografli GALERI ornegi.',
      bolum: 'Suit',
      fiyat_kurus: 450000,
      tur: 'oda',
      ozellikler: { kapasite: '3', yatak: 'Cift kisilik', kahvalti: 'Dahil', metrekare: '45' },
      media_ids: idler,
    },
  });
  if (eklendi.kod !== 200 && eklendi.kod !== 201) {
    throw new Error('urun ' + eklendi.kod + ': ' + eklendi.ham.slice(0, 300));
  }
  console.log('oda eklendi: ' + eklendi.ham.slice(0, 160));

  // ⚠️ DOGRULAMA: kayit GERCEKTEN dort medya tasiyor mu? Sunucu diziyi
  //	sessizce kirpiyor olabilirdi.
  // ⚠️ Uc KIMLIK ISTER (token'siz 401 doner) ve yanit `{urunler: [...]}`
  //	bicimindedir — ilk yazimda ikisi de varsayilmisti ve dogrulama
  //	PATLADI (kayit ZATEN yazilmisti). Varsayma, YANITA BAK.
  const liste = await jsonIstek('/users/' + benim + '/urunler', { token });
  const oda = (liste.d.urunler || [])
    .find((u) => u.ad && u.ad.indexOf('Deluxe Suit') === 0);
  if (!oda) throw new Error('eklenen oda listede BULUNAMADI');
  console.log('DOGRULAMA: media_ids adedi = ' + (oda.media_ids || []).length);
  if ((oda.media_ids || []).length !== FOTOLAR.length) {
    throw new Error('medya sayisi UYUSMUYOR');
  }
  console.log('TAMAM');
})().catch((e) => { console.error('HATA:', e.message); process.exit(1); });
