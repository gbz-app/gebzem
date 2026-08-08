// UCTAN UCA DOGRULAMA — canli sunucuda, GERCEK istemci akisiyla.
//
// ⚠️ AMAC: turu 75b'nin EN AGIR bulgusunun (akistaki gorsel IZLEYICIYE 403
//    donuyordu) sahada GERCEKTEN kapandigini kanitlamak. O hata TEK CIHAZDA
//    GORULMEZ — paylasan kendi gorselini kisa devreyle gorur. Bu yuzden test
//    IKI AYRI HESAP kullanir ve gorseli B'nin gozunden ister.
//
// ⚠️ Olusturdugu veri testten sonra DB TRUNCATE ile temizlenecek (surum rutini).
const API = 'https://api.gebzem.app';
const crypto = require('crypto');

// 1x1 gecerli JPEG (sunucu icerik SNIFF ediyor — sahte bayt kabul edilmez)
const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof' +
  'Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAAB' +
  'AAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64');

async function j(yol, { yontem = 'GET', govde, token } = {}) {
  const h = { 'Content-Type': 'application/json' };
  if (token) h.Authorization = 'Bearer ' + token;
  const r = await fetch(API + yol, {
    method: yontem, headers: h,
    body: govde === undefined ? undefined : JSON.stringify(govde),
  });
  const t = await r.text();
  let d = null;
  try { d = JSON.parse(t); } catch { d = t; }
  return { kod: r.status, d };
}

const rastgele = () => Math.floor(Math.random() * 900000 + 100000);

async function kullaniciAc(etiket) {
  const tel = '+90555' + rastgele() + String(rastgele()).slice(0, 1);
  const kadi = 'e2e' + rastgele();
  const kayit = await j('/auth/register', {
    yontem: 'POST',
    govde: { phone: tel, password: 'Test12345!', name: etiket, username: kadi },
  });
  if (kayit.kod >= 300) throw new Error(etiket + ' kayit: ' + kayit.kod + ' ' + JSON.stringify(kayit.d));
  const otp = kayit.d.dev_otp;
  if (!otp) throw new Error(etiket + ' dev_otp YOK (DEV_MODE kapali?): ' + JSON.stringify(kayit.d));
  const dog = await j('/auth/verify', { yontem: 'POST', govde: { phone: tel, code: String(otp) } });
  if (dog.kod >= 300) throw new Error(etiket + ' verify: ' + dog.kod + ' ' + JSON.stringify(dog.d));
  const token = dog.d.token || dog.d.access_token;
  const me = await j('/users/me', { token });
  return { etiket, tel, kadi, token, id: me.d.id };
}

const sonuclar = [];
const kontrol = (ad, gecti, ek = '') => {
  sonuclar.push({ ad, gecti, ek });
  console.log((gecti ? 'GECTI ' : 'KALDI ') + ad + (ek ? '  | ' + ek : ''));
};

(async () => {
  // ---------- kullanicilar
  const A = await kullaniciAc('E2E Yazar');
  const B = await kullaniciAc('E2E Okur');
  kontrol('iki hesap acildi', !!A.id && !!B.id, A.kadi + ' / ' + B.kadi);

  // ---------- MEDYA: presign -> PUT -> commit
  const md5 = crypto.createHash('md5').update(JPEG).digest('base64');
  const pres = await j('/media/upload', {
    yontem: 'POST', token: A.token,
    govde: { kind: 'image', mime: 'image/jpeg', bytes: JPEG.length, md5, file_name: 'e2e.jpg' },
  });
  kontrol('medya presign', pres.kod === 200 && !!pres.d.upload_url,
    'HTTP ' + pres.kod + (pres.kod !== 200 ? ' ' + JSON.stringify(pres.d) : ''));
  if (pres.kod !== 200) throw new Error('presign basarisiz — MEDYA KAPALI olabilir');

  const put = await fetch(pres.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': md5 },
    body: JPEG,
  });
  kontrol('R2 PUT (dogrudan bucket)', put.status === 200, 'HTTP ' + put.status);

  const commit = await j('/media/' + pres.d.media_id + '/commit', { yontem: 'POST', token: A.token });
  kontrol('medya commit (sunucu dogrulamasi)', commit.kod === 200,
    'HTTP ' + commit.kod + (commit.kod !== 200 ? ' ' + JSON.stringify(commit.d) : ''));

  // ---------- GONDERI
  const post = await j('/posts', {
    yontem: 'POST', token: A.token,
    govde: { tur: 'foto', metin: 'e2e test', media_ids: [pres.d.media_id] },
  });
  kontrol('foto gonderisi olusturuldu', post.kod === 201, 'HTTP ' + post.kod);

  // ⚠️ Turu 75b: `nil` dilim NULL gonderiyordu -> HER YAZI GONDERISI 500 doner.
  const yazi = await j('/posts', {
    yontem: 'POST', token: A.token,
    govde: { tur: 'yazi', metin: 'sadece metin', media_ids: [] },
  });
  kontrol('YAZI gonderisi (nil-dilim regresyonu)', yazi.kod === 201, 'HTTP ' + yazi.kod);

  // ---------- B, A'yi takip eder
  const takip = await j('/users/' + A.id + '/follow', { yontem: 'POST', token: B.token });
  kontrol('takip et', takip.kod === 200, 'HTTP ' + takip.kod + ' durum=' + (takip.d && takip.d.durum));

  // ---------- B'nin AKISI
  const akis = await j('/feed', { token: B.token });
  const gonderiler = (akis.d && akis.d.posts) || [];
  kontrol('B akisinda A gonderilerini goruyor', akis.kod === 200 && gonderiler.length >= 2,
    'adet=' + gonderiler.length);

  const fotoG = gonderiler.find((g) => (g.media_ids || []).length > 0);
  kontrol('akis media_ids donduruyor', !!fotoG, fotoG ? fotoG.media_ids[0] : '-');

  // ---------- ⚠️⚠️ ASIL SINAV: B, A'nin MEDYASINA erisebiliyor mu?
  if (fotoG) {
    const url = await j('/media/' + fotoG.media_ids[0] + '/url', { token: B.token });
    kontrol('BASKA KULLANICI medya adresi alabiliyor (turu 75b sevk engeli)',
      url.kod === 200 && !!url.d.url, 'HTTP ' + url.kod);
    if (url.kod === 200) {
      const indir = await fetch(url.d.url);
      const bayt = Buffer.from(await indir.arrayBuffer());
      kontrol('imzali adresten gorsel INDI ve BIREBIR ayni',
        indir.status === 200 && bayt.equals(JPEG),
        'HTTP ' + indir.status + ' bayt=' + bayt.length + '/' + JPEG.length);
    }
  }

  // ---------- ETKILESIM
  const pid = fotoG ? fotoG.id : null;
  if (pid) {
    kontrol('begeni', (await j('/posts/' + pid + '/like', { yontem: 'POST', token: B.token })).kod === 200);
    const yorum = await j('/posts/' + pid + '/comments', {
      yontem: 'POST', token: B.token, govde: { metin: 'e2e yorum' },
    });
    kontrol('yorum', yorum.kod === 201, 'HTTP ' + yorum.kod);
    kontrol('kaydet', (await j('/posts/' + pid + '/save', { yontem: 'POST', token: B.token })).kod === 200);
    const kayitli = await j('/users/me/saved', { token: B.token });
    kontrol('KAYDEDILENLER listesi (yeni uc)',
      kayitli.kod === 200 && ((kayitli.d.posts || []).length === 1),
      'HTTP ' + kayitli.kod + ' adet=' + ((kayitli.d.posts || []).length));
  }

  // ---------- ⚠️ ENGEL KAPISI: /users/{id}/posts (turu 75b sevk engeli)
  const oncePosts = await j('/users/' + A.id + '/posts', { token: B.token });
  kontrol('engelden ONCE B, A gonderilerini goruyor',
    oncePosts.kod === 200 && (oncePosts.d.posts || []).length >= 2,
    'adet=' + ((oncePosts.d.posts || []).length));

  const engelle = await j('/users/' + A.id + '/block', { yontem: 'POST', token: B.token });
  kontrol('engelle', engelle.kod === 200, 'HTTP ' + engelle.kod);

  const sonraPosts = await j('/users/' + A.id + '/posts', { token: B.token });
  kontrol('ENGELDEN SONRA profil gonderileri BOS (turu 75b sevk engeli)',
    sonraPosts.kod === 200 && (sonraPosts.d.posts || []).length === 0,
    'adet=' + ((sonraPosts.d.posts || []).length));

  const engelliAkis = await j('/feed', { token: B.token });
  kontrol('engelliden sonra AKIS da temiz',
    ((engelliAkis.d && engelliAkis.d.posts) || []).length === 0,
    'adet=' + (((engelliAkis.d && engelliAkis.d.posts) || []).length));

  await j('/users/' + A.id + '/block', { yontem: 'DELETE', token: B.token });

  // ---------- KANAL
  const kanal = await j('/channels', {
    yontem: 'POST', token: A.token,
    govde: { ad: 'E2E Kanal', kullanici_adi: 'e2e' + rastgele(), aciklama: 'test' },
  });
  kontrol('kanal olustur', kanal.kod === 201, 'HTTP ' + kanal.kod);
  if (kanal.kod === 201) {
    const kid = kanal.d.id;
    const kpost = await j('/channels/' + kid + '/posts', {
      yontem: 'POST', token: A.token, govde: { metin: 'kanal e2e', media_ids: [] },
    });
    kontrol('kanal gonderisi (nil-dilim regresyonu)', kpost.kod === 201, 'HTTP ' + kpost.kod);
    kontrol('abone ol', (await j('/channels/' + kid + '/subscribe', { yontem: 'POST', token: B.token })).kod === 200);
    const kdetay = await j('/channels/' + kid, { token: B.token });
    kontrol('kanal detayi `sessiz` alanini donduruyor (turu 75b)',
      kdetay.kod === 200 && Object.prototype.hasOwnProperty.call(kdetay.d, 'sessiz'),
      'alanlar=' + Object.keys(kdetay.d || {}).join(','));
    const klist = await j('/channels', { token: B.token });
    kontrol('kanal listesi + okunmamis sayaci',
      klist.kod === 200 && (klist.d || []).length === 1,
      'okunmamis=' + ((klist.d || [])[0] || {}).okunmamis);
    const kesfet = await j('/channels/kesfet', { token: A.token });
    kontrol('KESFET kendi kanalini gostermiyor (turu 75b)',
      (kesfet.d || []).every((k) => k.id !== kid),
      'adet=' + ((kesfet.d || []).length));
  }

  // ---------- REELS + BILDIRIM
  kontrol('reels ucu', (await j('/reels', { token: B.token })).kod === 200);
  const bild = await j('/notifications', { token: A.token });
  kontrol('bildirimler (takip+begeni+yorum dustu)',
    bild.kod === 200 && (bild.d || []).length >= 2, 'adet=' + ((bild.d || []).length));

  // ---------- OZET
  const kalan = sonuclar.filter((s) => !s.gecti);
  console.log('\n==================================');
  console.log('TOPLAM ' + sonuclar.length + ' kontrol · GECTI ' +
    (sonuclar.length - kalan.length) + ' · KALDI ' + kalan.length);
  if (kalan.length) {
    console.log('BASARISIZ:');
    kalan.forEach((s) => console.log('  - ' + s.ad + '  ' + s.ek));
    process.exit(1);
  }
  console.log('TUM UCTAN UCA KONTROLLER GECTI');
})().catch((e) => { console.error('PATLADI: ' + e.message); process.exit(1); });
