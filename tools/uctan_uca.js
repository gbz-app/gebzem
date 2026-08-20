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
  // ⚠️⚠️⚠️ TURU 96i — `tur` (Content-Type) DONDURULUYOR.
  //	Bu betik `JSON.parse` kullanir ve **BASLIGA BAKMAZ**; yani sunucu
  //	`text/plain` dondurse bile 200 + dogru govde ile YESIL gecerdi.
  //	Sahada tam bu oldu: `/users/me/adresler` basliksiz donuyordu, e2e
  //	365/365 gecti, ama **Dio govdeyi String okudu** ve "Konumun" paneli
  //	sunucuda adres VARKEN "Kayıtlı konumun yok" dedi.
  //	⚠️ DERS: govdenin dogrulugu, ISTEMCININ okuyabildigi anlamina gelmez.
  return { kod: r.status, d, tur: r.headers.get('content-type') || '' };
}

/// JSON dondurmesi beklenen bir yanitin basligini dogrular.
const jsonMu = (y) => (y.tur || '').toLowerCase().includes('application/json');

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
    govde: {
      kind: 'image', mime: 'image/jpeg', bytes: JPEG.length, md5,
      file_name: 'e2e.jpg',
      // ⚠️⚠️ TURU 81 — OLCU. Bu iki alan turu 81'in MANSET isinin on kosulu:
      //    istemci medyanin ORANINI bilmezse kirpmak zorunda kalir. Sutun
      //    015'ten beri VARDI ama HIC DOLDURULMUYORDU — bu arac da
      //    doldurmuyordu, yani zincir e2e'de SINANMIYORDU.
      width: 1080, height: 1350,
    },
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

  // ⚠️⚠️ ESKI VARSAYIM DUZELTILDI (turu 76): burada "akis TAMAMEN BOS" beklemek
  //    YANLIS. Engelleme takibi de DUSURUYOR (turu 75, `Block` -> `takibiKaldir`
  //    iki yonlu) -> kullanicinin takip ettigi kimse kalmaz -> `/feed` SOGUK
  //    BASLANGIC dalina duser ve KESFET doner. Bos DB'de bu tesadufen 0 idi;
  //    veri varken 0 DEGIL. Dogru olcut: **engellenenin gonderisi YOK**.
  const engelliAkis = await j('/feed', { token: B.token });
  const engelliPostlar = (engelliAkis.d && engelliAkis.d.posts) || [];
  kontrol('engelliden sonra AKISTA engellenenin gonderisi YOK',
    engelliPostlar.every((g) => g.author_id !== A.id),
    'toplam=' + engelliPostlar.length + ' kesfet=' + (engelliAkis.d && engelliAkis.d.kesfet));

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

  // ---------- TURU 76 ----------
  //
  // ⚠️ BU BOLUM NEDEN VAR: `media_kinds` alt sorgusu (`unnest(...) WITH
  //    ORDINALITY` + `array_agg`) GERCEK BIR POSTGRES'TE HIC KOSMAMISTI.
  //    Tip/sozdizim hatasi olsaydi **HER gonderi sorgusu 500 dondururdu** =
  //    akis, profil, kesfet, reels, kaydedilenler TAMAMEN olu. Statik denetim
  //    bunu YAKALAYAMAZ.
  {
    // A, B'yi engellemisti — sosyal yuzeyler icin engeli kaldir.
    await j('/users/' + B.id + '/block', { yontem: 'DELETE', token: A.token });

    // 1) media_kinds gercekten doner mi + SIRA korunur mu
    const akis76 = await j('/feed', { token: A.token });
    const kendi = ((akis76.d && akis76.d.posts) || [])
      .filter((g) => (g.media_ids || []).length > 0);
    kontrol('TURU 76: media_kinds alani DONUYOR (SQL gercek DB de kosuyor)',
      akis76.kod === 200 && kendi.length > 0 && Array.isArray(kendi[0].media_kinds),
      'HTTP ' + akis76.kod + ' ornek=' + JSON.stringify(kendi[0] && kendi[0].media_kinds));
    kontrol('TURU 76: media_kinds uzunlugu media_ids ile AYNI (sira eslesmesi)',
      kendi.length > 0 &&
      kendi.every((g) => g.media_kinds.length === g.media_ids.length),
      kendi.map((g) => g.media_ids.length + '/' + g.media_kinds.length).join(' '));
    kontrol('TURU 76: media_kinds degeri DOGRU (image)',
      kendi.length > 0 && kendi[0].media_kinds[0] === 'image',
      String(kendi[0] && kendi[0].media_kinds[0]));

    // 2) KAYDEDILENLER — sevk engelinin ta kendisi (16 vs 18 sutun)
    const kayit = await j('/users/me/saved', { token: B.token });
    const kayitli = (kayit.d && kayit.d.posts) || [];
    kontrol('TURU 76: KAYDEDILENLER BOS DONMUYOR (sutun sayisi sevk engeli)',
      kayit.kod === 200 && kayitli.length >= 1, 'adet=' + kayitli.length);
    kontrol('TURU 76: kaydedilenlerde de media_kinds var',
      kayitli.length > 0 && Array.isArray(kayitli[0].media_kinds));

    // 3) KESFET ucu
    const kesfet76 = await j('/kesfet', { token: B.token });
    kontrol('TURU 76: GET /kesfet calisiyor + yalniz MEDYALI gonderi',
      kesfet76.kod === 200 &&
      ((kesfet76.d && kesfet76.d.posts) || []).every((g) => (g.media_ids || []).length > 0),
      'HTTP ' + kesfet76.kod + ' adet=' + ((kesfet76.d && kesfet76.d.posts) || []).length);

    // 4) DUZENLEME
    const pid76 = kendi.length > 0 ? kendi[0].id : null;
    if (pid76) {
      const duz = await j('/posts/' + pid76, {
        yontem: 'PATCH', token: A.token, govde: { metin: 'duzenlenmis metin' },
      });
      kontrol('TURU 76: PATCH /posts/{id} (duzenleme)', duz.kod === 200, 'HTTP ' + duz.kod);
      const sonra = await j('/posts/' + pid76, { token: A.token });
      kontrol('TURU 76: metin degisti + `duzenlendi` bayragi TRUE',
        sonra.kod === 200 && sonra.d.metin === 'duzenlenmis metin' &&
        sonra.d.duzenlendi === true,
        'metin=' + sonra.d.metin + ' duzenlendi=' + sonra.d.duzenlendi);

      // ⚠️ BASKASININ gonderisini duzenleyememeli — 404 (403 DEGIL)
      const izinsiz = await j('/posts/' + pid76, {
        yontem: 'PATCH', token: B.token, govde: { metin: 'ele gecirdim' },
      });
      kontrol('TURU 76: BASKASI duzenleyemez (404)', izinsiz.kod === 404, 'HTTP ' + izinsiz.kod);

      // 5) ISTATISTIK — yalniz yazar
      const ist = await j('/posts/' + pid76 + '/istatistik', { token: A.token });
      kontrol('TURU 76: /istatistik yazara doner',
        ist.kod === 200 && typeof ist.d.goruntulenme === 'number',
        'HTTP ' + ist.kod + ' ' + JSON.stringify(ist.d));
      const istBaskasi = await j('/posts/' + pid76 + '/istatistik', { token: B.token });
      kontrol('TURU 76: /istatistik BASKASINA 404', istBaskasi.kod === 404,
        'HTTP ' + istBaskasi.kod);

      // 6) GORUNTULENME gercekten artiyor mu (detay ucu)
      const once = (await j('/posts/' + pid76 + '/istatistik', { token: A.token })).d.goruntulenme;
      await j('/posts/' + pid76, { token: B.token });
      const sonrasi = (await j('/posts/' + pid76 + '/istatistik', { token: A.token })).d.goruntulenme;
      kontrol('TURU 76: goruntulenme detay acilinca ARTIYOR',
        sonrasi > once, once + ' -> ' + sonrasi);
    }

    // 7) KULLANICI OZETI (avatar kok cozumu)
    const ozet = await j('/users/ozet?ids=' + A.id + ',' + B.id, { token: B.token });
    kontrol('TURU 76: GET /users/ozet coklu kimlik cozuyor',
      ozet.kod === 200 && Array.isArray(ozet.d) && ozet.d.length === 2,
      'HTTP ' + ozet.kod + ' adet=' + ((ozet.d || []).length));
    const bozuk = await j('/users/ozet?ids=BOZUK-DEGER,' + A.id, { token: B.token });
    kontrol('TURU 76: /users/ozet BOZUK uuid ile PATLAMIYOR (bicim suzgeci)',
      bozuk.kod === 200 && (bozuk.d || []).length === 1,
      'HTTP ' + bozuk.kod + ' adet=' + ((bozuk.d || []).length));

    // 8) ENGEL — ozet ucu de engel taniyor mu
    await j('/users/' + B.id + '/block', { yontem: 'POST', token: A.token });
    const ozetEngelli = await j('/users/ozet?ids=' + A.id, { token: B.token });
    kontrol('TURU 76: /users/ozet ENGELLIYI GOSTERMIYOR',
      ozetEngelli.kod === 200 && (ozetEngelli.d || []).length === 0,
      'adet=' + ((ozetEngelli.d || []).length));
    const kesfetEngelli = await j('/kesfet', { token: B.token });
    kontrol('TURU 76: /kesfet ENGELLIYI GOSTERMIYOR',
      kesfetEngelli.kod === 200 &&
      ((kesfetEngelli.d && kesfetEngelli.d.posts) || []).every((g) => g.author_id !== A.id));
    await j('/users/' + B.id + '/block', { yontem: 'DELETE', token: A.token });

    // 9) COKLU / KARMA GALERI
    // ⚠️ AYNI medya id'sini iki kez vermek CALISMAZ ve bu DOGRUDUR: sunucu
    //    `RowsAffected() != len(media_ids)` kontrolu yapiyor, tekrar eden id
    //    tek satir doner. Bu yuzden IKINCI BIR MEDYA yukleniyor.
    const md5b = crypto.createHash('md5').update(JPEG).digest('base64');
    const pres2 = await j('/media/upload', {
      yontem: 'POST', token: A.token,
      govde: { kind: 'image', mime: 'image/jpeg', bytes: JPEG.length, md5: md5b, file_name: 'e2e2.jpg' },
    });
    await fetch(pres2.d.upload_url, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': md5b },
      body: JPEG,
    });
    await j('/media/' + pres2.d.media_id + '/commit', { yontem: 'POST', token: A.token });

    const karma = await j('/posts', {
      yontem: 'POST', token: A.token,
      govde: {
        tur: 'foto', metin: 'karma galeri',
        media_ids: [pres.d.media_id, pres2.d.media_id],
      },
    });
    kontrol('TURU 76: GALERI (tur=foto, 2 AYRI medya) kabul ediliyor',
      karma.kod === 201, 'HTTP ' + karma.kod + ' ' + JSON.stringify(karma.d));

    if (karma.kod === 201) {
      const kg = await j('/posts/' + karma.d.id, { token: A.token });
      kontrol('TURU 76: galeride media_kinds 2 ELEMAN ve SIRALI',
        kg.kod === 200 && (kg.d.media_kinds || []).length === 2 &&
        kg.d.media_ids[0] === pres.d.media_id &&
        kg.d.media_ids[1] === pres2.d.media_id,
        JSON.stringify(kg.d.media_kinds));
    }

    const cokluVideo = await j('/posts', {
      yontem: 'POST', token: A.token,
      govde: { tur: 'video', metin: 'x', media_ids: [pres.d.media_id, pres2.d.media_id] },
    });
    kontrol('TURU 76: tur=video ile COKLU medya HALA reddediliyor',
      cokluVideo.kod === 400, 'HTTP ' + cokluVideo.kod);
  }

  // ---------- TURU 76b ----------
  //
  // ⚠️ EN KRITIK: `stories` sorgulari (BOOL_AND + GROUP BY + 24 saat penceresi)
  //    ve kanal `media_kinds` alt sorgusu GERCEK POSTGRES'TE HIC KOSMAMISTI.
  //    Tip/sozdizim hatasi olsaydi hikaye seridi ve kanal akisi 500 dondururdu.
  {
    // ⚠️⚠️ TAKIBI GERI KUR — bu testin kendi sirasindan dogan bir tuzak:
    //    yukarida B, A'yi ENGELLEDI ve engelleme TAKIBI DE DUSURUR (turu 75,
    //    `Block` -> `takibiKaldir`, iki yonlu). Engel kaldirilsa bile takip
    //    GERI GELMEZ. Hikaye seridi "takip ettiklerim" uzerinden calistigi
    //    icin bu adim olmadan serit HAKLI OLARAK bos doner.
    // ⚠️ YAPMA: bunu "hikaye bozuk" diye yorumlama; once takip durumuna bak.
    await j('/users/' + A.id + '/follow', { yontem: 'POST', token: B.token });

    // Yeni medya (hikaye icin) — ayni id iki kayda baglanmasin.
    const md5c = crypto.createHash('md5').update(JPEG).digest('base64');
    const pres3 = await j('/media/upload', {
      yontem: 'POST', token: A.token,
      govde: { kind: 'image', mime: 'image/jpeg', bytes: JPEG.length, md5: md5c, file_name: 'story.jpg' },
    });
    await fetch(pres3.d.upload_url, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': md5c },
      body: JPEG,
    });
    await j('/media/' + pres3.d.media_id + '/commit', { yontem: 'POST', token: A.token });

    // 1) HIKAYE PAYLAS
    const st = await j('/stories', {
      yontem: 'POST', token: A.token,
      govde: { media_id: pres3.d.media_id, kind: 'image', metin: 'e2e hikaye' },
    });
    kontrol('TURU 76b: POST /stories (hikaye paylas)', st.kod === 201,
      'HTTP ' + st.kod + ' ' + JSON.stringify(st.d));

    // 2) SERIT — B, A'yi takip ediyor -> A'nin hikayesini GORMELI
    const serit = await j('/stories', { token: B.token });
    const kullanicilar = (serit.d && serit.d.users) || [];
    kontrol('TURU 76b: GET /stories serit (SQL gercek DB de kosuyor)',
      serit.kod === 200 && kullanicilar.some((u) => u.user_id === A.id),
      'HTTP ' + serit.kod + ' adet=' + kullanicilar.length);
    const aSatir = kullanicilar.find((u) => u.user_id === A.id);
    kontrol('TURU 76b: serit adet + hepsi_izlendi=FALSE (henuz izlenmedi)',
      !!aSatir && aSatir.adet === 1 && aSatir.hepsi_izlendi === false,
      JSON.stringify(aSatir && { adet: aSatir.adet, izlendi: aSatir.hepsi_izlendi }));

    // 3) IZLEYICI
    const liste = await j('/stories/' + A.id, { token: B.token });
    const hikayeler = (liste.d && liste.d.stories) || [];
    kontrol('TURU 76b: GET /stories/{userId}', liste.kod === 200 && hikayeler.length === 1,
      'HTTP ' + liste.kod + ' adet=' + hikayeler.length);
    kontrol('TURU 76b: IZLENME sayisi BASKASINA DONMUYOR (gizlilik)',
      hikayeler.length > 0 && hikayeler[0].izlenme === undefined);

    if (hikayeler.length > 0) {
      const sid = hikayeler[0].id;
      kontrol('TURU 76b: izlendi isareti',
        (await j('/stories/' + sid + '/view', { yontem: 'POST', token: B.token })).kod === 200);
      // idempotent mi
      kontrol('TURU 76b: izlendi IDEMPOTENT (ikinci cagri da 200)',
        (await j('/stories/' + sid + '/view', { yontem: 'POST', token: B.token })).kod === 200);

      const serit2 = await j('/stories', { token: B.token });
      const a2 = ((serit2.d && serit2.d.users) || []).find((u) => u.user_id === A.id);
      kontrol('TURU 76b: izledikten SONRA hepsi_izlendi=TRUE (halka griye doner)',
        !!a2 && a2.hepsi_izlendi === true, JSON.stringify(a2 && a2.hepsi_izlendi));

      const izl = await j('/stories/' + sid + '/viewers', { token: A.token });
      kontrol('TURU 76b: izleyenler SAHIBINE doner', izl.kod === 200 && (izl.d || []).length === 1,
        'HTTP ' + izl.kod + ' adet=' + ((izl.d || []).length));
      const izlBaskasi = await j('/stories/' + sid + '/viewers', { token: B.token });
      kontrol('TURU 76b: izleyenler BASKASINA 404', izlBaskasi.kod === 404, 'HTTP ' + izlBaskasi.kod);

      // 4) SAHIBININ izlenme sayisi
      const kendi = await j('/stories/' + A.id, { token: A.token });
      kontrol('TURU 76b: SAHIBI izlenme sayisini GORUR',
        ((kendi.d && kendi.d.stories) || [])[0]?.izlenme === 1,
        JSON.stringify(((kendi.d && kendi.d.stories) || [])[0]?.izlenme));

      // 5) ENGEL — engelli taraf hikayeyi GOREMEZ
      await j('/users/' + B.id + '/block', { yontem: 'POST', token: A.token });
      const engelliSerit = await j('/stories', { token: B.token });
      kontrol('TURU 76b: ENGELLI taraf hikayeyi GORMEZ',
        !((engelliSerit.d && engelliSerit.d.users) || []).some((u) => u.user_id === A.id));
      const engelliListe = await j('/stories/' + A.id, { token: B.token });
      kontrol('TURU 76b: ENGELLI taraf hikaye listesini de GORMEZ',
        ((engelliListe.d && engelliListe.d.stories) || []).length === 0);
      await j('/users/' + B.id + '/block', { yontem: 'DELETE', token: A.token });

      // 6) SIL — satir FIZIKSEL silinmez, durum='silindi'
      kontrol('TURU 76b: kendi hikayeni sil',
        (await j('/stories/' + sid, { yontem: 'DELETE', token: A.token })).kod === 200);
      const sonra = await j('/stories/' + A.id, { token: A.token });
      kontrol('TURU 76b: silinen hikaye listede YOK',
        ((sonra.d && sonra.d.stories) || []).length === 0);
    }

    // 7) BASKASININ MEDYASIYLA hikaye acilamaz
    const calinti = await j('/stories', {
      yontem: 'POST', token: B.token,
      govde: { media_id: pres.d.media_id, kind: 'image' },
    });
    kontrol('TURU 76b: BASKASININ medyasiyla hikaye ACILAMAZ (403)',
      calinti.kod === 403, 'HTTP ' + calinti.kod);

    // 8) KANAL — media_kinds + istatistik
    const kanalId = kanal.kod === 201 ? kanal.d.id : null;
    if (kanalId) {
      const kposts = await j('/channels/' + kanalId + '/posts', { token: A.token });
      const kp = (kposts.d && kposts.d.posts) || [];
      kontrol('TURU 76b: KANAL gonderileri media_kinds donduruyor (SQL kosuyor)',
        kposts.kod === 200 && kp.length > 0 && Array.isArray(kp[0].media_kinds),
        'HTTP ' + kposts.kod + ' ' + JSON.stringify(kp[0] && kp[0].media_kinds));
      if (kp.length > 0) {
        const kist = await j('/channel-posts/' + kp[0].id + '/istatistik', { token: A.token });
        kontrol('TURU 76b: KANAL gonderi istatistigi (sahibe)',
          kist.kod === 200 && typeof kist.d.goruntulenme === 'number',
          'HTTP ' + kist.kod + ' ' + JSON.stringify(kist.d));
        const kistB = await j('/channel-posts/' + kp[0].id + '/istatistik', { token: B.token });
        kontrol('TURU 76b: KANAL istatistigi BASKASINA 404', kistB.kod === 404,
          'HTTP ' + kistB.kod);
      }
    }
  }

  // ---------- TURU 77: YENI DIKEYLER ----------
  //
  // ⚠️⚠️ EN KRITIK: `media.erisebilir()` dallari. Hikaye/etkinlik/ilan/urun
  //    gorselleri icin dal YAZILMAZSA medya PAYLASANDAN BASKA HERKESE 403
  //    doner ve bu TEK CIHAZDA GORULMEZ (sahip kisa devreyle gorur).
  //    Turu 75b'de akistaki TUM gorsellerde, turu 77'de hikayede yasandi.
  //    Bu yuzden HER dikeyin medyasi **B'NIN GOZUNDEN** isteniyor.
  {
    // A ve B birbirini engellememis olmali (yukaridaki testler engel acti/kapatti).
    await j('/users/' + B.id + '/block', { yontem: 'DELETE', token: A.token });
    await j('/users/' + A.id + '/block', { yontem: 'DELETE', token: B.token });

    // Yardimci: yeni medya yukle
    // ⚠️⚠️ TURU 81 — OLCU (width/height) GONDERILIYOR.
    //    Gonderilmezse sutun 0 kalir ve `media_boyut` "0x0" doner; o durumda
    //    istemci varsayilana duser ve turu 81'in MANSET isi (kirpmasiz,
    //    ORANDAN genislik) SESSIZCE eski davranisa doner. Bu arac gercek
    //    zinciri kanitlamali: presign -> sutun -> gonderi sorgusu -> istemci.
    // ⚠️ Degerler GERCEK JPEG'in olculeri DEGIL (test resmi 1x1); amac
    //    ZINCIRIN calistigini gostermek, kod cozucuyu sinamak degil.
    // ⚠️⚠️ TURU 93 — `kind` PARAMETRELESTIRILDI (varsayilan 'image', mevcut
    //    cagiranlar ETKILENMEZ).
    //
    //	SEBEP: kapak medyasi 'image' olarak yuklenemez. Sunucu
    //	`PATCH /users/me` icinde `kind='kapak'` sartini **403 ile**
    //	uyguluyor (turu 78 kapisi: aksi halde bir avatar kapak, bir kapak
    //	avatar yapilabilirdi ve `limits.go`daki AYRI boyut tavanlari
    //	ANLAMINI YITIRIRDI). Ilk yazimda 'image' gecmistim ve e2e KIRMIZI
    //	dustu — yani bu kontrol ISE YARADI: sunucunun kapisini KANITLADI.
    async function medyaYukle(token, ad, w = 1080, h = 1350, kind = 'image') {
      const md5x = crypto.createHash('md5').update(JPEG).digest('base64');
      const p = await j('/media/upload', {
        yontem: 'POST', token,
        govde: {
          kind, mime: 'image/jpeg', bytes: JPEG.length, md5: md5x,
          file_name: ad, width: w, height: h,
        },
      });
      if (p.kod !== 200) return null;
      await fetch(p.d.upload_url, {
        method: 'PUT',
        headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': md5x },
        body: JPEG,
      });
      await j('/media/' + p.d.media_id + '/commit', { yontem: 'POST', token });
      return p.d.media_id;
    }

    // ---------- 1) HIKAYE EDITORU (katmanlar + metin hikayesi)
    const sm = await medyaYukle(A.token, 'story2.jpg');
    const katmanli = await j('/stories', {
      yontem: 'POST', token: A.token,
      govde: {
        media_id: sm, kind: 'image',
        katmanlar: [{
          metin: 'Merhaba', x: 0.5, y: 0.4, boyut: 32,
          renk: '#FF3B5C', font: 'kalin', hiza: 'orta', kutu: 'dolu', aci: 0.1,
        }],
      },
    });
    kontrol('TURU 77: hikaye KATMANLI paylasildi', katmanli.kod === 201,
      'HTTP ' + katmanli.kod);

    const metinH = await j('/stories', {
      yontem: 'POST', token: A.token,
      govde: {
        kind: 'metin', arka_plan: 'okyanus',
        katmanlar: [{ metin: 'Sadece yazi', boyut: 40, renk: '#FFFFFF' }],
      },
    });
    kontrol('TURU 77: MEDYASIZ metin hikayesi (media_id NULL olabiliyor)',
      metinH.kod === 201, 'HTTP ' + metinH.kod + ' ' + JSON.stringify(metinH.d));

    const bosMetin = await j('/stories', {
      yontem: 'POST', token: A.token,
      govde: { kind: 'metin', arka_plan: 'mor', katmanlar: [] },
    });
    kontrol('TURU 77: BOS metin hikayesi reddediliyor', bosMetin.kod === 400,
      'HTTP ' + bosMetin.kod);

    await j('/users/' + A.id + '/follow', { yontem: 'POST', token: B.token });
    const hl = await j('/stories/' + A.id, { token: B.token });
    const hikayeler = (hl.d && hl.d.stories) || [];
    const katmanliH = hikayeler.find((s) => (s.katmanlar || []).length > 0);
    kontrol('TURU 77: katmanlar GERI DONUYOR (JSONB tarama)',
      !!katmanliH && katmanliH.katmanlar[0].metin === 'Merhaba',
      JSON.stringify(katmanliH && katmanliH.katmanlar));
    const metinliH = hikayeler.find((s) => s.kind === 'metin');
    kontrol('TURU 77: metin hikayesi media_id NULL + arka_plan dolu',
      !!metinliH && !metinliH.media_id && metinliH.arka_plan === 'okyanus',
      JSON.stringify(metinliH && { m: metinliH.media_id, a: metinliH.arka_plan }));

    // ⚠️⚠️ SEVK ENGELI KONTROLU: B, A'nin hikaye medyasini ALABILIYOR MU?
    if (sm) {
      const hm = await j('/media/' + sm + '/url', { token: B.token });
      kontrol('TURU 77: HIKAYE MEDYASI ikinci hesapta ACILIYOR (e dali)',
        hm.kod === 200, 'HTTP ' + hm.kod);
    }

    // ---------- 2) ISLETME
    const isl = await j('/users/me/isletme', {
      yontem: 'PUT', token: A.token,
      govde: {
        kategori: 'yemek', adres: 'Test Cad. 1', il: 'Kocaeli', ilce: 'Gebze',
        telefon: '02620000000', web: 'https://ornek.test',
        // ⚠️⚠️⚠️ TURU 80b — YEDI GUN BIRDEN (denetim: KALICI YALANCI-YESIL).
        //
        //	Eskiden burada YALNIZ `gun: 1` (Pazartesi) vardi. Turu 80'in
        //	randevu blogu "yarin" icin slot istiyor; yani slotlar HAFTADA
        //	YALNIZ BIR GUN uretiliyordu. Sonuc: testin randevu bolumu
        //	haftanin ALTI GUNU ya kirmizi ya da `if (musait)` kapisinda
        //	ATLANIYORDU — ve 172/172 gecmesinin sebebi, kosuldugu gunun
        //	(9 Agustos Pazar) yarininin PAZARTESI olmasiydi. Yani yesil,
        //	kodun dogrulugunu DEGIL takvimi olcuyordu.
        // ⚠️ YAPMA: bunu tekrar tek gune indirme; e2e HANGI GUN kosulursa
        //    kosulsun ayni sonucu vermeli.
        calisma: [1, 2, 3, 4, 5, 6, 7].map((g) => ({
          gun: g, acilis: '09:00', kapanis: '22:00', kapali: false,
        })),
      },
    });
    kontrol('TURU 77: isletme hesabina gecis', isl.kod === 200, 'HTTP ' + isl.kod);
    const islD = await j('/users/' + A.id + '/isletme', { token: B.token });
    kontrol('TURU 77: isletme detayi (kategori_ad sunucudan)',
      islD.kod === 200 && islD.d.kategori === 'yemek' && islD.d.kategori_ad === 'Yemek',
      'HTTP ' + islD.kod);
    const islL = await j('/isletmeler?kategori=yemek', { token: B.token });
    kontrol('TURU 77: isletme REHBERI (menu kartlarinin gittigi yer)',
      islL.kod === 200 && ((islL.d && islL.d.isletmeler) || []).some((x) => x.id === A.id),
      'adet=' + (((islL.d && islL.d.isletmeler) || []).length));
    const me2 = await j('/users/me', { token: A.token });
    kontrol('TURU 77: /users/me hesap_turu donduruyor',
      me2.d.hesap_turu === 'isletme', String(me2.d.hesap_turu));

    // ═════ TURU 93: ISLETME LISTESI `kapak_media_id` DONDURUYOR ═════
    //
    // ⚠️⚠️ NEDEN KONTROL EDILIYOR: turu 93 kartlari **16:9 BUYUK GORSEL**
    //    cizyor. Avatar 46px'lik daire icin uretilmis; o kutuya konsaydi
    //    BULANIK cikardi. Bu yuzden liste sorgusuna `u.kapak_media_id`
    //    eklendi — SELECT + Scan + YANIT HARITASI **UCU BIRLIKTE**.
    //    Yanit haritasina koymayi unutmak, projede DORT KEZ sahaya cikmis
    //    bir sinif (turu 78 `Profile()` kapak/onayli): Scan CALISIR,
    //    derleyici SUSAR, alan istemciye HIC ULASMAZ ve kartlar sessizce
    //    gradyan yer tutucuya duser (= "kapak ozelligi yok" gibi gorunur).
    {
      const kpk = await medyaYukle(A.token, 'kapak93.jpg', 1600, 900, 'kapak');
      const pk93 = await j('/users/me', {
        yontem: 'PATCH', token: A.token, govde: { kapak_media_id: kpk },
      });
      kontrol('TURU 93: kapak PATCH kabul edildi', pk93.kod === 200,
        'HTTP ' + pk93.kod);

      // ⚠️ KIND KAPISI: 'image' bir medya KAPAK YAPILAMAZ. Bu kapi olmasaydi
      //    `limits.go`daki ayri boyut tavanlari (avatar 2 MB / kapak 8 MB)
      //    anlamini yitirirdi.
      const yanlisKind = await medyaYukle(A.token, 'yanlis.jpg', 1600, 900);
      const rd = await j('/users/me', {
        yontem: 'PATCH', token: A.token,
        govde: { kapak_media_id: yanlisKind },
      });
      kontrol("TURU 93: kind='image' medya KAPAK YAPILAMIYOR (403)",
        rd.kod === 403, 'HTTP ' + rd.kod);
      const l93 = await j('/isletmeler?kategori=yemek', { token: B.token });
      const ben = (((l93.d && l93.d.isletmeler) || [])
        .find((x) => x.id === A.id)) || {};
      kontrol('TURU 93: ISLETME LISTESI kapak_media_id DONDURUYOR (kart kapagi)',
        l93.kod === 200 && ben.kapak_media_id === kpk,
        'donen=' + JSON.stringify(ben.kapak_media_id) + ' beklenen=' + kpk);

      // ⚠️ Kapak BASKA HESAPTAN da erisilebilir olmali: kart listeyi ACAN
      //    herkese cizilir. `media.erisebilir()` kapak dalini turu 78'de
      //    almisti; burada REGRESYON muhafizi olarak duruyor.
      const im = await j('/media/' + kpk + '/url', { token: B.token });
      kontrol('TURU 93: kart kapagi IKINCI HESAPTAN acilabiliyor',
        im.kod === 200 && !!(im.d && im.d.url), 'HTTP ' + im.kod);
    }

    // ---------- 3) ETKINLIK
    const em = await medyaYukle(A.token, 'etkinlik.jpg');
    const yarin = new Date(Date.now() + 86400000).toISOString();
    const etk = await j('/etkinlikler', {
      yontem: 'POST', token: A.token,
      govde: {
        baslik: 'E2E Konser', aciklama: 'test', kategori: 'konser',
        baslangic: yarin, konum: 'Sahne', il: 'Kocaeli', ilce: 'Gebze',
        media_ids: [em], ucretsiz: false, fiyat_kurus: 15000, kontenjan: 2,
      },
    });
    kontrol('TURU 77: etkinlik olusturuldu', etk.kod === 201, 'HTTP ' + etk.kod);
    const eid = etk.d && etk.d.id;
    const eList = await j('/etkinlikler', { token: B.token });
    kontrol('TURU 77: YAKLASAN etkinlikler listesi (SQL gercek DB de kosuyor)',
      eList.kod === 200 && ((eList.d && eList.d.etkinlikler) || []).some((x) => x.id === eid),
      'HTTP ' + eList.kod + ' adet=' + (((eList.d && eList.d.etkinlikler) || []).length));
    const eGecmis = await j('/etkinlikler?gecmis=1', { token: B.token });
    kontrol('TURU 77: GECMIS suzgeci yaklasani GOSTERMIYOR',
      eGecmis.kod === 200 &&
      !((eGecmis.d && eGecmis.d.etkinlikler) || []).some((x) => x.id === eid));
    if (eid) {
      const kat = await j('/etkinlikler/' + eid + '/katil', {
        yontem: 'POST', token: B.token, govde: { durum: 'katiliyor' },
      });
      kontrol('TURU 77: etkinlige katil', kat.kod === 200, 'HTTP ' + kat.kod);
      const eD = await j('/etkinlikler/' + eid, { token: B.token });
      kontrol('TURU 77: katilan sayisi 2 (olusturan + B) + benim_durumum',
        eD.d.katilan_sayisi === 2 && eD.d.benim_durumum === 'katiliyor',
        'sayi=' + eD.d.katilan_sayisi + ' durum=' + eD.d.benim_durumum);
      kontrol('TURU 77: fiyat KURUS donuyor', eD.d.fiyat_kurus === 15000,
        String(eD.d.fiyat_kurus));
      // kontenjan 2 -> A ve B dolu; olusturan kendi etkinliginden ayrilamaz
      const ayril = await j('/etkinlikler/' + eid + '/katil', {
        yontem: 'POST', token: A.token, govde: { durum: 'vazgecti' },
      });
      kontrol('TURU 77: OLUSTURAN kendi etkinliginden ayrilamaz',
        ayril.kod === 400, 'HTTP ' + ayril.kod);
      // ⚠️ medya (f) dali
      if (em) {
        const emu = await j('/media/' + em + '/url', { token: B.token });
        kontrol('TURU 77: ETKINLIK MEDYASI ikinci hesapta ACILIYOR (f dali)',
          emu.kod === 200, 'HTTP ' + emu.kod);
      }
    }

    // ---------- 4) ILAN
    const agac = await j('/ilan-kategoriler', { token: A.token });
    // ⚠️ TURU 90 — SAYI YERINE KUME: burasi eskiden `length === 4` diyordu ve
    //    turu 90'da BESINCI tur ('is') eklenince KIRMIZIYA dustu. Oysa kontrolun
    //    ASIL amaci "agac SUNUCUDAN geliyor" idi, "tam dort tur var" degil.
    //    Sabit sayi, her yeni turde YANLIS ALARM verip gercek bir bulguyu
    //    gurultuye gomerdi. Artik BEKLENEN TURLERIN HEPSI VAR MI diye bakilir
    //    (biri DUSERSE yine kirmizi olur — koruma kaybolmaz).
    {
      const t = ((agac.d && agac.d.turler) || []).map((x) => x.anahtar);
      const beklenen = ['vasita', 'emlak', 'ikinci_el', 'hizmet', 'is'];
      kontrol('TURU 77: ilan kategori AGACI sunucudan (istemcide kopya yok)',
        agac.kod === 200 && beklenen.every((b) => t.includes(b)) &&
        ((agac.d.turler[0] || {}).alanlar || []).length > 0,
        'turler=' + t.join(','));
    }
    const im = await medyaYukle(A.token, 'ilan.jpg');
    const ilanR = await j('/ilanlar', {
      yontem: 'POST', token: A.token,
      govde: {
        tur: 'vasita', kategori: 'otomobil', baslik: 'E2E Araba',
        aciklama: 'test', fiyat_kurus: 75000000, il: 'Kocaeli', ilce: 'Gebze',
        media_ids: [im],
        ozellikler: { marka: 'Ford', model: 'Focus', yil: 2018, yakit: 'Dizel' },
      },
    });
    kontrol('TURU 77: ilan olusturuldu (fiyat 750.000 TL = BIGINT kurus)',
      ilanR.kod === 201, 'HTTP ' + ilanR.kod);
    const iid = ilanR.d && ilanR.d.id;
    const iL = await j('/ilanlar?tur=vasita', { token: B.token });
    kontrol('TURU 77: ilan listesi + tur suzgeci',
      iL.kod === 200 && ((iL.d && iL.d.ilanlar) || []).some((x) => x.id === iid),
      'adet=' + (((iL.d && iL.d.ilanlar) || []).length));
    if (iid) {
      const iD = await j('/ilanlar/' + iid, { token: B.token });
      kontrol('TURU 77: JSONB ozellikler geri donuyor',
        iD.kod === 200 && iD.d.ozellikler && iD.d.ozellikler.marka === 'Ford',
        JSON.stringify(iD.d.ozellikler));
      kontrol('TURU 77: ilan fiyati BIGINT tasmadan donuyor',
        iD.d.fiyat_kurus === 75000000, String(iD.d.fiyat_kurus));
      kontrol('TURU 77: favori ekle',
        (await j('/ilanlar/' + iid + '/favori', { yontem: 'POST', token: B.token })).kod === 200);
      const fav = await j('/ilanlar?favori=1', { token: B.token });
      kontrol('TURU 77: FAVORILERIM listesi (uc + ekran ayni turda)',
        ((fav.d && fav.d.ilanlar) || []).some((x) => x.id === iid),
        'adet=' + (((fav.d && fav.d.ilanlar) || []).length));
      const satildi = await j('/ilanlar/' + iid, {
        yontem: 'PATCH', token: A.token, govde: { durum: 'satildi' },
      });
      kontrol('TURU 77: ilan SATILDI (satir SILINMEZ)', satildi.kod === 200);
      const bakalim = await j('/ilanlar?tur=vasita', { token: B.token });
      kontrol('TURU 77: satilan ilan genel listede YOK',
        !((bakalim.d && bakalim.d.ilanlar) || []).some((x) => x.id === iid));
      const benimIlan = await j('/ilanlar?benim=1', { token: A.token });
      kontrol('TURU 77: ILANLARIM satilani da GOSTERIYOR (gecmis korunur)',
        ((benimIlan.d && benimIlan.d.ilanlar) || []).some((x) => x.id === iid));
      const baskasi = await j('/ilanlar/' + iid, {
        yontem: 'PATCH', token: B.token, govde: { durum: 'kaldirildi' },
      });
      kontrol('TURU 77: BASKASI ilani duzenleyemez (404)', baskasi.kod === 404,
        'HTTP ' + baskasi.kod);
      // ⚠️ medya (g) dali
      if (im) {
        const imu = await j('/media/' + im + '/url', { token: B.token });
        kontrol('TURU 77: ILAN MEDYASI ikinci hesapta ACILIYOR (g dali)',
          imu.kod === 200, 'HTTP ' + imu.kod);
      }
    }

    // ---------- 5) ISLETME URUNU
    const um = await medyaYukle(A.token, 'urun.jpg');
    const urun = await j('/isletme/urunler', {
      yontem: 'POST', token: A.token,
      govde: {
        ad: 'E2E Lahmacun', aciklama: 'test', bolum: 'Ana Yemekler',
        fiyat_kurus: 12500, media_ids: [um],
      },
    });
    kontrol('TURU 77: isletme urunu eklendi', urun.kod === 201, 'HTTP ' + urun.kod);
    const uL = await j('/users/' + A.id + '/urunler', { token: B.token });
    kontrol('TURU 77: urun katalogu/menusu',
      uL.kod === 200 && ((uL.d && uL.d.urunler) || []).length >= 1,
      'adet=' + (((uL.d && uL.d.urunler) || []).length));
    // Kisisel hesap urun EKLEYEMEZ
    const izinsizUrun = await j('/isletme/urunler', {
      yontem: 'POST', token: B.token, govde: { ad: 'olmaz' },
    });
    kontrol('TURU 77: KISISEL hesap urun ekleyemez (403)',
      izinsizUrun.kod === 403, 'HTTP ' + izinsizUrun.kod);
    // ⚠️ medya (h) dali
    if (um) {
      const umu = await j('/media/' + um + '/url', { token: B.token });
      kontrol('TURU 77: URUN MEDYASI ikinci hesapta ACILIYOR (h dali)',
        umu.kod === 200, 'HTTP ' + umu.kod);
    }

    // ---------- 6) AI KAPISI
    const aiD = await j('/ai/durum', { token: A.token });
    kontrol('TURU 77: /ai/durum calisiyor', aiD.kod === 200,
      'acik=' + (aiD.d && aiD.d.acik));
    if (aiD.d && aiD.d.acik === false) {
      const aiM = await j('/ai/menu', {
        yontem: 'POST', token: A.token, govde: { metin: 'test' },
      });
      kontrol('TURU 77: AI KAPALIYKEN uc 503 doner (istemci dugmeyi cizmez)',
        aiM.kod === 503, 'HTTP ' + aiM.kod);
    }

    // ---------- 7) ENGEL — yeni dikeylerde de gecerli mi
    await j('/users/' + A.id + '/block', { yontem: 'POST', token: B.token });
    const eEngel = await j('/etkinlikler', { token: B.token });
    kontrol('TURU 77: ENGELLI taraf etkinligi GORMEZ',
      !((eEngel.d && eEngel.d.etkinlikler) || []).some((x) => x.olusturan_id === A.id));
    const iEngel = await j('/ilanlar', { token: B.token });
    kontrol('TURU 77: ENGELLI taraf ilani GORMEZ',
      !((iEngel.d && iEngel.d.ilanlar) || []).some((x) => x.sahibi_id === A.id));
    const islEngel = await j('/isletmeler', { token: B.token });
    kontrol('TURU 77: ENGELLI taraf isletmeyi GORMEZ',
      !((islEngel.d && islEngel.d.isletmeler) || []).some((x) => x.id === A.id));
    const uEngel = await j('/users/' + A.id + '/urunler', { token: B.token });
    kontrol('TURU 77: ENGELLI taraf urun katalogunu GORMEZ (404)',
      uEngel.kod === 404, 'HTTP ' + uEngel.kod);
    await j('/users/' + A.id + '/block', { yontem: 'DELETE', token: B.token });
  }

  // ---------- TURU 78: KAPAK · ONAYLI · DUZENLEME · VIDEO · SOHBET · KADRO
  //
  // ⚠️ Bu blogun EN KRITIK kontrolleri, STATIK DENETIMIN GORMEDIGI seylerdir:
  //    · yeni sutunun yanit JSON'una GERCEKTEN konup konmadigi (turu 78'de
  //      `kapak_media_id`/`onayli` Scan ediliyor ama haritaya konmuyordu),
  //    · yeni `kind` degerinin DB CHECK'inden gecip gecmedigi (turu 78'de
  //      `media_assets.kind` 'kapak' kabul etmiyordu -> presign PATLIYORDU),
  //    · yeni SQL'lerin GERCEK POSTGRES'te kosup kosmadigi.
  {
    async function medyaYukle2(token, ad, kind) {
      const md5x = crypto.createHash('md5').update(JPEG).digest('base64');
      const p = await j('/media/upload', {
        yontem: 'POST', token,
        govde: { kind, mime: 'image/jpeg', bytes: JPEG.length, md5: md5x, file_name: ad },
      });
      if (p.kod !== 200) return { hata: p.kod, id: null };
      await fetch(p.d.upload_url, {
        method: 'PUT',
        headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': md5x },
        body: JPEG,
      });
      await j('/media/' + p.d.media_id + '/commit', { yontem: 'POST', token });
      return { hata: 0, id: p.d.media_id };
    }

    // ---------- 1) KAPAK GORSELI
    // ⚠️ Bu kontrol `media_assets.kind` CHECK'ini SINAR. Turu 78'de kisit
    //    'kapak' kabul etmiyordu ve presign 500 doneceki = ozellik %100 olu.
    const kap = await medyaYukle2(A.token, 'kapak.jpg', 'kapak');
    kontrol("TURU 78: kind='kapak' PRESIGN gecti (media_assets CHECK'i kabul ediyor)",
      kap.hata === 0 && !!kap.id, 'HTTP ' + kap.hata);

    if (kap.id) {
      const pk = await j('/users/me', {
        yontem: 'PATCH', token: A.token, govde: { kapak_media_id: kap.id },
      });
      kontrol('TURU 78: PATCH /users/me kapak baglaniyor', pk.kod === 200,
        'HTTP ' + pk.kod);
      kontrol('TURU 78: /users/me kapak_media_id donduruyor',
        pk.d && pk.d.kapak_media_id === kap.id, String(pk.d && pk.d.kapak_media_id));

      // ⚠️⚠️ EN KRITIK: profil ucu kapagi GERCEKTEN doner mu? Turu 78'de sutun
      //    SELECT edilip Scan ediliyor ama YANIT HARITASINA KONMUYORDU —
      //    kapak HICBIR PROFILDE gorunmeyecekti.
      const pr = await j('/users/' + A.id + '/profile', { token: B.token });
      kontrol('TURU 78: PROFIL UCU kapak_media_id DONDURUYOR (yanit haritasi)',
        pr.kod === 200 && pr.d.kapak_media_id === kap.id,
        'donen=' + JSON.stringify(pr.d && pr.d.kapak_media_id));
      kontrol('TURU 78: PROFIL UCU onayli alanini DONDURUYOR',
        pr.kod === 200 && typeof pr.d.onayli === 'boolean',
        'tur=' + typeof (pr.d && pr.d.onayli));

      // ⚠️ Medya (i) dali: kapak IKINCI HESAPTA acilmali (turu 75b/77 sinifi).
      const km = await j('/media/' + kap.id + '/url', { token: B.token });
      kontrol('TURU 78: KAPAK MEDYASI ikinci hesapta ACILIYOR (erisim dali)',
        km.kod === 200, 'HTTP ' + km.kod);

      // Kaldirma NOBETCISI: bos dize = SIL (null "degistirme" demek).
      const ks = await j('/users/me', {
        yontem: 'PATCH', token: A.token, govde: { kapak_media_id: '' },
      });
      kontrol("TURU 78: kapak KALDIRMA nobetcisi ('' = sil) calisiyor",
        ks.kod === 200 && !ks.d.kapak_media_id,
        'donen=' + JSON.stringify(ks.d && ks.d.kapak_media_id));
      // geri koy (sonraki kontroller icin)
      await j('/users/me', {
        yontem: 'PATCH', token: A.token, govde: { kapak_media_id: kap.id },
      });
    }

    // ---------- 2) ILAN DUZENLEME + VIDEO
    const im2 = await medyaYukle2(A.token, 'ilan2.jpg', 'image');
    const yeniIlan = await j('/ilanlar', {
      yontem: 'POST', token: A.token,
      govde: {
        tur: 'vasita', kategori: 'otomobil', baslik: 'Duzenlenecek arac',
        aciklama: 'ilk', fiyat_kurus: 50000000, il: 'Kocaeli', ilce: 'Gebze',
        media_ids: [im2.id], ozellikler: { marka: 'Fiat', yil: 2015 },
      },
    });
    const dId = yeniIlan.d && yeniIlan.d.id;
    kontrol('TURU 78: duzenleme icin ilan olusturuldu', yeniIlan.kod === 201);

    if (dId) {
      const d0 = await j('/ilanlar/' + dId, { token: A.token });
      kontrol('TURU 78: yeni ilanda duzenlendi_at NULL', d0.d.duzenlendi_at == null,
        String(d0.d.duzenlendi_at));
      kontrol('TURU 78: ilan media_kinds donduruyor',
        Array.isArray(d0.d.media_kinds) && d0.d.media_kinds[0] === 'image',
        JSON.stringify(d0.d.media_kinds));

      // TAM duzenleme: kategori + il + ilce + ozellikler + media_ids
      const g1 = await j('/ilanlar/' + dId, {
        yontem: 'PATCH', token: A.token,
        govde: {
          baslik: 'Duzenlendi', kategori: 'suv', il: 'Kocaeli', ilce: 'Darica',
          fiyat_kurus: 45000000, ozellikler: { marka: 'Fiat', yil: 2016 },
        },
      });
      kontrol('TURU 78: ilan TAM duzenleme (kategori/il/ilce/ozellikler)',
        g1.kod === 200, 'HTTP ' + g1.kod);
      const d1 = await j('/ilanlar/' + dId, { token: A.token });
      kontrol('TURU 78: duzenleme alanlari GERCEKTEN degisti',
        d1.d.baslik === 'Duzenlendi' && d1.d.kategori === 'suv' &&
        d1.d.ilce === 'Darica' && d1.d.ozellikler.yil === 2016,
        JSON.stringify({ b: d1.d.baslik, k: d1.d.kategori, i: d1.d.ilce }));
      kontrol('TURU 78: duzenlendi_at ARTIK DOLU (alici guveni etiketi)',
        d1.d.duzenlendi_at != null, String(d1.d.duzenlendi_at));

      // ⚠️ `durum` degisimi DUZENLEME SAYILMAZ — etiket anlamini yitirmesin.
      const oncekiDamga = d1.d.duzenlendi_at;
      await j('/ilanlar/' + dId, {
        yontem: 'PATCH', token: A.token, govde: { durum: 'satildi' },
      });
      const d2 = await j('/ilanlar/' + dId, { token: A.token });
      kontrol('TURU 78: sadece DURUM degisimi duzenlendi_at DAMGASINI DEGISTIRMEZ',
        d2.d.duzenlendi_at === oncekiDamga, String(d2.d.duzenlendi_at));
      await j('/ilanlar/' + dId, {
        yontem: 'PATCH', token: A.token, govde: { durum: 'yayinda' },
      });

      // Baskasinin medyasini baglama denemesi (erisim dalini somurme yolu)
      const bMedya = await medyaYukle2(B.token, 'bskns.jpg', 'image');
      const kotu = await j('/ilanlar/' + dId, {
        yontem: 'PATCH', token: A.token, govde: { media_ids: [bMedya.id] },
      });
      kontrol('TURU 78: BASKASININ medyasi ilana BAGLANAMAZ (403)',
        kotu.kod === 403, 'HTTP ' + kotu.kod);

      // ---------- 3) ILAN SOHBETI
      const s1 = await j('/ilanlar/' + dId + '/sohbet', {
        yontem: 'POST', token: B.token,
      });
      kontrol('TURU 78: ilan sohbeti acildi', s1.kod === 200 && !!s1.d.chat_id,
        'HTTP ' + s1.kod);
      const s2 = await j('/ilanlar/' + dId + '/sohbet', {
        yontem: 'POST', token: B.token,
      });
      kontrol('TURU 78: AYNI ilan icin AYNI sohbet doner (yeni satir acmaz)',
        s2.d && s2.d.chat_id === s1.d.chat_id);

      const kendi = await j('/ilanlar/' + dId + '/sohbet', {
        yontem: 'POST', token: A.token,
      });
      kontrol('TURU 78: KENDI ilanina mesaj ACILAMAZ (400)', kendi.kod === 400,
        'HTTP ' + kendi.kod);

      // ⚠️ Sohbet listesi ILAN BASLIGINI tasimali — yoksa satici hangi ilan
      //    icin yazildigini goremez ve ozellik YARIM kalir.
      const liste = await j('/chats', { token: A.token });
      const ilanSohbeti = (Array.isArray(liste.d) ? liste.d : [])
        .find((c) => c.ilan_id === dId);
      kontrol('TURU 78: SOHBET LISTESI ilan_id + ilan_baslik donduruyor',
        !!ilanSohbeti && ilanSohbeti.ilan_baslik === 'Duzenlendi',
        JSON.stringify(ilanSohbeti && ilanSohbeti.ilan_baslik));

      // ⚠️ KISISEL sohbet ILAN sohbetine DUSMEMELI (`ilan_id IS NULL` yuklemi).
      const kisisel = await j('/chats/direct', {
        yontem: 'POST', token: B.token, govde: { user_id: A.id },
      });
      kontrol('TURU 78: KISISEL sohbet ILAN sohbetinden AYRI (ilan_id IS NULL)',
        kisisel.kod === 200 && kisisel.d.chat_id !== s1.d.chat_id,
        'kisisel=' + (kisisel.d && kisisel.d.chat_id));
    }

    // ---------- 4) ETKINLIK DUZENLEME + BITIS + KADRO
    const yarin2 = new Date(Date.now() + 2 * 86400000).toISOString();
    const bitis2 = new Date(Date.now() + 2 * 86400000 + 7200000).toISOString();
    const ye = await j('/etkinlikler', {
      yontem: 'POST', token: A.token,
      govde: {
        baslik: 'Duzenlenecek konser', aciklama: 'ilk', kategori: 'konser',
        baslangic: yarin2, konum: 'Sahne', il: 'Kocaeli', ilce: 'Gebze',
        ucretsiz: true,
      },
    });
    const eId2 = ye.d && ye.d.id;
    kontrol('TURU 78: duzenleme icin etkinlik olusturuldu', ye.kod === 201);

    if (eId2) {
      const eg = await j('/etkinlikler/' + eId2, {
        yontem: 'PATCH', token: A.token,
        govde: { baslik: 'Konser (yeni)', konum: 'Yeni sahne', bitis: bitis2 },
      });
      kontrol('TURU 78: PATCH /etkinlikler/{id} (uc YENI)', eg.kod === 200,
        'HTTP ' + eg.kod);
      const ed = await j('/etkinlikler/' + eId2, { token: A.token });
      kontrol('TURU 78: etkinlik duzenlemesi uygulandi + BITIS yazildi',
        ed.d.baslik === 'Konser (yeni)' && ed.d.bitis != null,
        JSON.stringify({ b: ed.d.baslik, bit: ed.d.bitis }));

      // Bos dize = bitisi KALDIR nobetcisi
      await j('/etkinlikler/' + eId2, {
        yontem: 'PATCH', token: A.token, govde: { bitis: '' },
      });
      const ed2 = await j('/etkinlikler/' + eId2, { token: A.token });
      kontrol("TURU 78: bitis KALDIRMA nobetcisi ('' = sil)", ed2.d.bitis == null,
        String(ed2.d.bitis));

      const bg = await j('/etkinlikler/' + eId2, {
        yontem: 'PATCH', token: B.token, govde: { baslik: 'ele gecirildi' },
      });
      kontrol('TURU 78: BASKASI etkinligi duzenleyemez (404)', bg.kod === 404,
        'HTTP ' + bg.kod);

      // KADRO
      const k1 = await j('/etkinlikler/' + eId2 + '/kadro', {
        yontem: 'POST', token: A.token,
        govde: { ad: 'Ornek Sanatci', rol: 'Sanatçı' },
      });
      kontrol('TURU 78: kadroya KAYITSIZ kisi eklendi (user_id ZORUNLU DEGIL)',
        k1.kod === 201, 'HTTP ' + k1.kod);
      const k2 = await j('/etkinlikler/' + eId2 + '/kadro', {
        yontem: 'POST', token: A.token,
        govde: { user_id: B.id, rol: 'Konuşmacı', ad: 'SAHTE AD' },
      });
      kontrol('TURU 78: kadroya KAYITLI kisi eklendi', k2.kod === 201,
        'HTTP ' + k2.kod);
      const kl = await j('/etkinlikler/' + eId2 + '/kadro', { token: B.token });
      const kayitli = ((kl.d && kl.d.kadro) || []).find((x) => x.user_id === B.id);
      kontrol('TURU 78: kadro listesi donuyor (2 kisi)',
        ((kl.d && kl.d.kadro) || []).length === 2,
        'adet=' + (((kl.d && kl.d.kadro) || []).length));
      // ⚠️ KIMLIK TAKLIDI KAPISI: kayitli kisinin adi SUNUCUDAN gelir.
      kontrol('TURU 78: kayitli kisinin adi SUNUCUDAN (istemcinin "SAHTE AD"i YOK)',
        !!kayitli && kayitli.ad === 'E2E Okur', String(kayitli && kayitli.ad));

      const kb = await j('/etkinlikler/' + eId2 + '/kadro', {
        yontem: 'POST', token: B.token, govde: { ad: 'izinsiz' },
      });
      kontrol('TURU 78: BASKASI kadroya ekleyemez (404)', kb.kod === 404,
        'HTTP ' + kb.kod);
      const ks2 = await j(
        '/etkinlikler/' + eId2 + '/kadro/' + (k1.d && k1.d.id),
        { yontem: 'DELETE', token: A.token });
      kontrol('TURU 78: kadrodan silme', ks2.kod === 200, 'HTTP ' + ks2.kod);
    }

    // ---------- 5) VITRIN + AI
    const v1 = await j('/vitrin?dikey=yemek', { token: B.token });
    kontrol('TURU 78: GET /vitrin calisiyor (isletme dali)',
      v1.kod === 200 && Array.isArray(v1.d.slaytlar),
      'HTTP ' + v1.kod + ' adet=' + ((v1.d && v1.d.slaytlar || []).length));
    const v2 = await j('/vitrin?dikey=etkinlik', { token: B.token });
    kontrol('TURU 78: GET /vitrin etkinlik dali (SQL gercek Postgres de kosuyor)',
      v2.kod === 200 && Array.isArray(v2.d.slaytlar), 'HTTP ' + v2.kod);

    // ⚠️ Yeni filtre parametreleri (hizli kartlarin ON KOSULU)
    const fi = await j('/isletmeler?dogrulandi=1', { token: B.token });
    kontrol('TURU 78: /isletmeler?dogrulandi=1 suzgeci calisiyor', fi.kod === 200,
      'HTTP ' + fi.kod);
    const fe = await j('/etkinlikler?bas_min=' + encodeURIComponent(yarin2),
      { token: B.token });
    kontrol('TURU 78: /etkinlikler?bas_min= suzgeci calisiyor (timestamptz cast)',
      fe.kod === 200, 'HTTP ' + fe.kod);

    const ai = await j('/ai/durum', { token: A.token });
    kontrol('TURU 78: /ai/durum', ai.kod === 200, 'acik=' + (ai.d && ai.d.acik));

    // ---------- TURU 79: AI GORSEL URETME (BAGLANTI kontrolu — PARA HARCAMAZ)
    //
    // ⚠️⚠️ BURADA GERCEK URETIM **CAGRILMAZ**. Uretim her surumde kosulsaydi
    //    her uctan uca calistirmasi PARA harcar ve kullanicinin gunluk gorsel
    //    kotasindan duserdi. Onun yerine ucun DOGRU BAGLANDIGI ve kapilarin
    //    calistigi, ucret dogurmayan yollardan dogrulanir.
    // ⚠️ Gercek uretim ELLE sinanir: `scratchpad/gorsel_test.js`
    //    (canli dogrulandi: 21 sn, 1,6 MB PNG, imzali adresten indi).
    kontrol('TURU 79: /ai/durum GORSEL alanlarini donduruyor',
      ai.kod === 200 && typeof ai.d.gorsel === 'boolean' &&
      typeof ai.d.gorsel_kalan === 'number' &&
      typeof ai.d.gorsel_gunluk_kota === 'number',
      JSON.stringify({
        g: ai.d && ai.d.gorsel,
        k: ai.d && ai.d.gorsel_kalan,
        q: ai.d && ai.d.gorsel_gunluk_kota,
      }));

    // ⚠️ GORSEL KOTASI METINDEN **AYRI** olmali (bir gorsel metinden cok daha
    //    pahali). Ayni sayi cikarsa tek havuz kullaniliyor demektir.
    kontrol('TURU 79: gorsel kotasi metin kotasindan AYRI',
      ai.kod === 200 && ai.d.gorsel_gunluk_kota !== ai.d.gunluk_kota,
      'gorsel=' + (ai.d && ai.d.gorsel_gunluk_kota) +
      ' metin=' + (ai.d && ai.d.gunluk_kota));

    // ⚠️ BOS METIN 400 dondurmeli — **kota rezervasyonundan ONCE**. Bu kontrol
    //    ucun BAGLI oldugunu (404 degil) kanitlar ve kurus harcamaz.
    const bos = await j('/ai/gorsel', {
      yontem: 'POST', token: A.token, govde: { metin: '   ' },
    });
    kontrol('TURU 79: POST /ai/gorsel BAGLI ve bos metni 400 ile reddediyor',
      bos.kod === 400, 'HTTP ' + bos.kod);

    // ⚠️ Bos istek KOTA YAKMAMALI: reddin kota rezervasyonundan ONCE oldugunu
    //    kanitlar. Yakiyorsa kullanici yazim hatasiyla hakkini tuketirdi.
    const ai2 = await j('/ai/durum', { token: A.token });
    kontrol('TURU 79: gecersiz istek KOTA YAKMIYOR',
      ai2.kod === 200 && ai2.d.gorsel_kalan === ai.d.gorsel_kalan,
      'once=' + (ai.d && ai.d.gorsel_kalan) + ' sonra=' + (ai2.d && ai2.d.gorsel_kalan));

    // ⚠️⚠️⚠️ TURU 79b — **METIN UCU GORSEL KOTASINI YEMEMELI** (denetim: SEVK
    //    ENGELI, kok neden turu 79'da BENIM yaptigim degisiklikti).
    //
    //    `tur` turu 77'de yalnizca bir ETIKETTI; turu 79'da onu "pahali gorsel
    //    kotasi" olcutune cevirdim ama `UrunMetni` hala turu 77'den kalma
    //    "gorsel" etiketini geciyordu. Sonuc: "Yapay zekâ ile açıklama yaz"
    //    dugmesine her dokunus, turun MANSET OZELLIGI olan gorsel uretiminden
    //    bir hak yakiyordu. Onceki kontrol bunu YAKALAYAMIYORDU (yalnizca iki
    //    kotanin FARKLI SAYI oldugunu olcuyordu — 10 != 20 gecer).
    //
    // ⚠️ `/ai/urun-metni` UCUZ bir metin cagrisidir; e2e'de calistirmak kabul
    //    edilebilir (~$0.001). Gorsel uretimi ise HALA cagrilmiyor.
    const um = await j('/ai/urun-metni', {
      yontem: 'POST', token: A.token, govde: { metin: 'Adana kebap' },
    });
    const ai3 = await j('/ai/durum', { token: A.token });
    kontrol('TURU 79b: /ai/urun-metni GORSEL kotasini YEMIYOR',
      ai3.kod === 200 && ai3.d.gorsel_kalan === ai.d.gorsel_kalan,
      'gorsel once=' + (ai.d && ai.d.gorsel_kalan) +
      ' sonra=' + (ai3.d && ai3.d.gorsel_kalan) + ' (uc HTTP ' + um.kod + ')');
    kontrol('TURU 79b: /ai/urun-metni METIN kotasindan DUSUYOR',
      ai3.kod === 200 && um.kod === 200 && ai3.d.kalan === ai.d.kalan - 1,
      'metin once=' + (ai.d && ai.d.kalan) + ' sonra=' + (ai3.d && ai3.d.kalan));

    // ---------- TURU 80: REZERVASYON + RANDEVU
    //
    // ⚠️ A ZATEN ISLETME (yukaridaki turu 77 blogu onu isletmeye gecirdi) ve
    //    calisma saatleri dolu. B musteri olacak.
    {
      // --- ayar: ozelligi AC
      const ay = await j('/isletme/randevu-ayar', {
        yontem: 'PUT', token: A.token,
        govde: { acik: true, slot_dakika: 30, slot_kapasite: 2, ileri_gun: 14 },
      });
      kontrol('TURU 80: randevu ayari kaydedildi',
        ay.kod === 200 && ay.d.acik === true, 'HTTP ' + ay.kod);
      kontrol('TURU 80: tur KATEGORIDEN turetiliyor (yemek -> rezervasyon)',
        ay.d && ay.d.tur === 'rezervasyon', String(ay.d && ay.d.tur));

      // ⚠️ ISLETME DETAYI randevu bilgisini DONDURMELI — istemci dugmeyi BUNA
      //    gore ciziyor. Yanit haritasina konmamis olsaydi dugme HIC cizilmezdi
      //    (turu 78'de kapak icin tam bu yasandi).
      const det = await j('/users/' + A.id + '/isletme', { token: B.token });
      kontrol('TURU 80: isletme detayi randevu_acik + randevu_turu donduruyor',
        det.kod === 200 && det.d.randevu_acik === true &&
        det.d.randevu_turu === 'rezervasyon',
        JSON.stringify({ a: det.d && det.d.randevu_acik, t: det.d && det.d.randevu_turu }));

      // --- musait saatler
      const yarinTarih = new Date(Date.now() + 86400000)
        .toISOString().slice(0, 10);
      const us = await j('/isletmeler/' + A.id + '/uygun-saatler?tarih=' + yarinTarih,
        { token: B.token });
      kontrol('TURU 80: uygun saatler ucu calisiyor (slot uretimi SUNUCUDA)',
        us.kod === 200 && us.d.acik === true && Array.isArray(us.d.slotlar),
        'HTTP ' + us.kod + ' adet=' + ((us.d && us.d.slotlar || []).length));

      const musait = ((us.d && us.d.slotlar) || []).find((s) => s.musait);
      kontrol('TURU 80: en az bir MUSAIT slot var (calisma saatleri okundu)',
        !!musait, 'ilk=' + JSON.stringify(musait && musait.saat));

      if (musait) {
        // --- randevu olustur
        const r1 = await j('/isletmeler/' + A.id + '/randevu', {
          yontem: 'POST', token: B.token,
          govde: { baslangic: musait.zaman, kisi_sayisi: 4, not_musteri: 'Pencere kenarı' },
        });
        kontrol('TURU 80: randevu olusturuldu', r1.kod === 201 && !!r1.d.id,
          'HTTP ' + r1.kod);
        kontrol('TURU 80: durum BEKLIYOR (otomatik onay KAPALI)',
          r1.d && r1.d.durum === 'bekliyor', String(r1.d && r1.d.durum));
        kontrol('TURU 80: tur SUNUCUDAN geldi (istemci gondermedi)',
          r1.d && r1.d.tur === 'rezervasyon', String(r1.d && r1.d.tur));

        // ⚠️ KAPASITE: slot_kapasite=2, bir tane alindi -> HALA musait olmali.
        const us2 = await j('/isletmeler/' + A.id + '/uygun-saatler?tarih=' + yarinTarih,
          { token: B.token });
        const ayniSlot = ((us2.d && us2.d.slotlar) || [])
          .find((s) => s.zaman === musait.zaman);
        kontrol('TURU 80: kapasite 2 iken 1 randevu slotu KAPATMIYOR',
          !!ayniSlot && ayniSlot.musait === true,
          'musait=' + (ayniSlot && ayniSlot.musait));

        // --- kendi isletmesinden randevu ALAMAZ
        const kendi = await j('/isletmeler/' + A.id + '/randevu', {
          yontem: 'POST', token: A.token, govde: { baslangic: musait.zaman },
        });
        kontrol('TURU 80: kendi isletmenden randevu ALINAMAZ (400)',
          kendi.kod === 400, 'HTTP ' + kendi.kod);

        // --- GECMIS saate randevu
        const gecmis = await j('/isletmeler/' + A.id + '/randevu', {
          yontem: 'POST', token: B.token,
          govde: { baslangic: new Date(Date.now() - 3600000).toISOString() },
        });
        kontrol('TURU 80: GECMIS saate randevu ALINAMAZ (400)',
          gecmis.kod === 400, 'HTTP ' + gecmis.kod);

        // --- listeler
        const ben = await j('/randevularim', { token: B.token });
        kontrol('TURU 80: /randevularim (musteri) listeliyor',
          ben.kod === 200 && (ben.d.randevular || []).length === 1,
          'adet=' + ((ben.d && ben.d.randevular || []).length));
        kontrol('TURU 80: musteri listesinde ISLETME adi var (JOIN)',
          !!(ben.d && ben.d.randevular[0] && ben.d.randevular[0].karsi_ad),
          String(ben.d && ben.d.randevular[0] && ben.d.randevular[0].karsi_ad));

        const gk = await j('/isletme/randevular', { token: A.token });
        kontrol('TURU 80: /isletme/randevular (gelen kutusu) listeliyor',
          gk.kod === 200 && (gk.d.randevular || []).length === 1,
          'adet=' + ((gk.d && gk.d.randevular || []).length));

        // --- YETKI: musteri kendini "onayladi" YAPAMAZ
        const yetkisiz = await j('/randevular/' + r1.d.id + '/durum', {
          yontem: 'POST', token: B.token, govde: { durum: 'onaylandi' },
        });
        kontrol('TURU 80: MUSTERI randevuyu ONAYLAYAMAZ (403)',
          yetkisiz.kod === 403, 'HTTP ' + yetkisiz.kod);

        // --- isletme ONAYLAR
        const onay = await j('/randevular/' + r1.d.id + '/durum', {
          yontem: 'POST', token: A.token, govde: { durum: 'onaylandi' },
        });
        kontrol('TURU 80: ISLETME randevuyu onayladi', onay.kod === 200,
          'HTTP ' + onay.kod);

        // ⚠️ AYNI GECIS IKINCI KEZ YAPILAMAZ (yaris kapisi).
        const tekrar = await j('/randevular/' + r1.d.id + '/durum', {
          yontem: 'POST', token: A.token, govde: { durum: 'onaylandi' },
        });
        kontrol('TURU 80: ayni gecis IKINCI KEZ yapilamaz (409)',
          tekrar.kod === 409, 'HTTP ' + tekrar.kod);

        // --- musteri IPTAL edebilir
        const ipt = await j('/randevular/' + r1.d.id + '/durum', {
          yontem: 'POST', token: B.token, govde: { durum: 'iptal' },
        });
        kontrol('TURU 80: MUSTERI iptal edebilir', ipt.kod === 200,
          'HTTP ' + ipt.kod);

        // ⚠️ VERI SILINMEZ: iptal SATIR SILMEZ, durum yazar.
        const sonra = await j('/randevularim', { token: B.token });
        const kayit = (sonra.d && sonra.d.randevular || [])[0];
        kontrol('TURU 80: iptal SATIRI SILMEZ, durum yazar (veri politikasi)',
          !!kayit && kayit.durum === 'iptal', String(kayit && kayit.durum));

        // --- bildirim gitti mi (isletmeye "yeni randevu")
        // ⚠️ Uc `/notifications`; yanit `{items:[...]}` ya da duz dizi olabilir
        //    — ikisini de kabul ediyoruz ki bicim degisirse test PATLAMASIN,
        //    KIRMIZI dussun.
        const bil = await j('/notifications', { token: A.token });
        const ham = bil.d;
        const dizi = Array.isArray(ham)
          ? ham
          : (ham && (ham.items || ham.notifications || ham.bildirimler)) || [];
        const rb = (Array.isArray(dizi) ? dizi : [])
          .filter((x) => String(x.tur || x.type || '').startsWith('randevu'));
        kontrol('TURU 80: randevu BILDIRIMI olustu (tek kaynak bildirim servisi)',
          rb.length > 0, 'adet=' + rb.length + ' HTTP ' + bil.kod);

        // ⚠️⚠️ TURU 80b — IPTAL BILDIRIMI **ALICIYA GORE AYRI TUR** olmali.
        //
        //	`iptal` gecisini MUSTERI yapar ve alici ISLETMEDIR. Once iki
        //	yon de "randevu_iptal" gonderiyordu; istemci turden aliciyi
        //	turetemedigi icin isletme, bildirime dokununca KENDI musteri
        //	listesine dusuyor ve iptali GOREMIYORDU.
        //	Burada A = ISLETME; B (musteri) az once `iptal` etti, yani
        //	A'nin kutusunda `randevu_iptal_musteri` OLMALI.
        const iptalB = rb.filter((x) =>
          String(x.tur || x.type || '') === 'randevu_iptal_musteri');
        kontrol('TURU 80b: MUSTERI iptalinde ISLETMEYE ozel tur gidiyor',
          iptalB.length > 0,
          'turler=' + JSON.stringify(rb.map((x) => x.tur || x.type)));
      }

      // --- KAPALI GUN (bayram/tatil)
      const yarin2 = new Date(Date.now() + 2 * 86400000).toISOString().slice(0, 10);
      const kap = await j('/isletme/randevu-kapali', {
        yontem: 'POST', token: A.token, govde: { tarih: yarin2, kapali: true },
      });
      kontrol('TURU 80: kapali gun isaretlendi', kap.kod === 200, 'HTTP ' + kap.kod);
      const us3 = await j('/isletmeler/' + A.id + '/uygun-saatler?tarih=' + yarin2,
        { token: B.token });
      kontrol('TURU 80: KAPALI GUNDE slot URETILMEZ (calisma saati "acik" dese de)',
        us3.kod === 200 && (us3.d.slotlar || []).length === 0,
        'adet=' + ((us3.d && us3.d.slotlar || []).length));

      // ⚠️⚠️⚠️ TURU 80b — TAKVIM KURALLARI **YAZMA YOLUNDA** DA GECERLI Mi?
      //
      //	Denetim bulgusu: `Olustur` kapali gun / calisma saati / slot
      //	hizasi kurallarinin HICBIRINI dogrulamiyordu; bunlar YALNIZ okuma
      //	yolunda (`UygunSaatler`) vardi. Yani istemci takvimi HIC ACMADAN
      //	dogrudan POST atarak bayramda saat 03:17'ye randevu yazdirabilirdi.
      //	Arayuzun kurala uymasi, kuralin UYGULANDIGI anlamina gelmez.
      // ⚠️ Bu UC kontrol o deligi kalici olarak kapatir.
      const kapaliAn = yarin2 + 'T12:00:00Z';
      const rKapali = await j('/isletmeler/' + A.id + '/randevu', {
        yontem: 'POST', token: B.token, govde: { baslangic: kapaliAn },
      });
      kontrol('TURU 80b: KAPALI GUNE dogrudan POST REDDEDILIR (arayuz atlanamaz)',
        rKapali.kod === 409 || rKapali.kod === 400, 'HTTP ' + rKapali.kod);

      const mesaiDisi = new Date(Date.now() + 86400000);
      mesaiDisi.setUTCHours(1, 0, 0, 0); // 04:00 TR — calisma 09:00-22:00
      const rMesai = await j('/isletmeler/' + A.id + '/randevu', {
        yontem: 'POST', token: B.token,
        govde: { baslangic: mesaiDisi.toISOString() },
      });
      kontrol('TURU 80b: CALISMA SAATI DISINA randevu REDDEDILIR',
        rMesai.kod === 409 || rMesai.kod === 400, 'HTTP ' + rMesai.kod);

      const hizasiz = new Date(Date.now() + 86400000);
      hizasiz.setUTCHours(9, 7, 0, 0); // :07 -> 30 dk'lik slot hizasinda YOK
      const rHiza = await j('/isletmeler/' + A.id + '/randevu', {
        yontem: 'POST', token: B.token,
        govde: { baslangic: hizasiz.toISOString() },
      });
      kontrol('TURU 80b: SLOT HIZASINDA OLMAYAN saat REDDEDILIR (14:07)',
        rHiza.kod === 409 || rHiza.kod === 400, 'HTTP ' + rHiza.kod);

      // ⚠️⚠️⚠️ TURU 80b — KISMI AYAR KAYDI DIGER AYARLARI KORUMALI.
      //
      //	SEVK ENGELIYDI: `ON CONFLICT ... COALESCE(EXCLUDED.x, mevcut)`
      //	OLU KODDU (EXCLUDED zaten `COALESCE($n,varsayilan)` sonucudur,
      //	yani ASLA NULL olamaz). Sonuc: arayuz alanlari TEK TEK gonderdigi
      //	icin isletme "Randevu suresi"ni degistirince `acik` FALSE'a
      //	dusuyor ve ozellik KENDINI KAPATIYORDU.
      //	⚠️ ESKI E2E BUNU GOREMEZDI: tum alanlari TEK cagrida gonderiyordu,
      //	   yani hicbir parametre NULL olmuyor ve COALESCE yedegi HIC
      //	   sinanmiyordu. Kontrol bu yuzden KISMI govde gonderir.
      const kismi = await j('/isletme/randevu-ayar', {
        yontem: 'PUT', token: A.token, govde: { slot_dakika: 45 },
      });
      kontrol('TURU 80b: KISMI ayar kaydi diger ayarlari KORUR (acik/kapasite/ileri_gun)',
        kismi.kod === 200 && kismi.d.acik === true &&
        kismi.d.slot_dakika === 45 && kismi.d.slot_kapasite === 2 &&
        kismi.d.ileri_gun === 14,
        JSON.stringify(kismi.d));

      // ⚠️ Kapali gun LISTELENEBILIYOR mu (arayuzun okudugu uc).
      const kapL = await j('/isletme/randevu-kapali', { token: A.token });
      const kapDizi = (kapL.d && (kapL.d.gunler || kapL.d)) || [];
      kontrol('TURU 80b: kapali gunler LISTELENIYOR (KapaliGunlerEkrani ucu)',
        kapL.kod === 200 && Array.isArray(kapDizi) && kapDizi.includes(yarin2),
        'HTTP ' + kapL.kod + ' ' + JSON.stringify(kapDizi));

      // ⚠️⚠️⚠️ TURU 80b — GECE YARISINI ASAN CALISMA SAATI (SEVK ENGELIYDI).
      //
      //	`Slotlar(gun)` "22:00-02:00" gibi saatlerde gece yarisini ASAR ve
      //	ERTESI takvim gunune tasan slotlari da uretir. Yazma yolundaki
      //	dogrulama ise anin KENDI takvim gunune bakiyordu -> 11 Agu 00:30
      //	slotu 10 Agu'nun calisma gunune ait oldugu halde 11 Agu'nun
      //	listesinde araniyor, BULUNAMIYOR ve arayuzun GOSTERDIGI her
      //	gece slotu POST'ta **409** donuyordu. Bar/restoran gibi gece
      //	calisan mekanlar randevu ALAMAZDI.
      // ⚠️ Bu kontrol AMPIRIK: isletmenin saatleri gecici olarak gece
      //    vardiyasina cevrilir, uretilen bir gece-yarisi-sonrasi slot
      //    POST edilir ve 201 beklenir. Sonunda saatler GERI ALINIR.
      const geceSaat = [1, 2, 3, 4, 5, 6, 7].map((g) => ({
        gun: g, acilis: '22:00', kapanis: '02:00', kapali: false,
      }));
      await j('/users/me/isletme', {
        yontem: 'PUT', token: A.token,
        govde: {
          kategori: 'yemek', adres: 'Test Cad. 1', il: 'Kocaeli', ilce: 'Gebze',
          telefon: '02620000000', web: 'https://ornek.test', calisma: geceSaat,
        },
      });
      const geceGun = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
      const gs = await j('/isletmeler/' + A.id + '/uygun-saatler?tarih=' + geceGun,
        { token: B.token });
      const geceSlotlar = (gs.d && gs.d.slotlar) || [];
      // Gece yarisindan SONRAKI slot: yerel saati 00:00-02:00 arasinda olan.
      const sonrasi = geceSlotlar.find((s) => {
        const h = parseInt(String(s.saat).split(':')[0], 10);
        return s.musait && h >= 0 && h < 2;
      });
      kontrol('TURU 80b: gece vardiyasinda GECE YARISI SONRASI slot URETILIYOR',
        !!sonrasi, 'adet=' + geceSlotlar.length +
        ' saatler=' + JSON.stringify(geceSlotlar.slice(0, 3).map((s) => s.saat)));
      if (sonrasi) {
        const rGece = await j('/isletmeler/' + A.id + '/randevu', {
          yontem: 'POST', token: B.token,
          govde: { baslangic: sonrasi.zaman, kisi_sayisi: 2 },
        });
        kontrol('TURU 80b: GECE YARISI SONRASI slot POST ile KABUL EDILIYOR',
          rGece.kod === 201, 'HTTP ' + rGece.kod + ' saat=' + sonrasi.saat);
      }
      // ⚠️ Saatleri GERI AL — sonraki kontroller gunduz penceresine dayaniyor.
      await j('/users/me/isletme', {
        yontem: 'PUT', token: A.token,
        govde: {
          kategori: 'yemek', adres: 'Test Cad. 1', il: 'Kocaeli', ilce: 'Gebze',
          telefon: '02620000000', web: 'https://ornek.test',
          calisma: [1, 2, 3, 4, 5, 6, 7].map((g) => ({
            gun: g, acilis: '09:00', kapanis: '22:00', kapali: false,
          })),
        },
      });

      // ⚠️ Kapali gun GERI ALINABILIYOR mu (silme yolu da yasamali).
      const kapSil = await j('/isletme/randevu-kapali', {
        yontem: 'POST', token: A.token, govde: { tarih: yarin2, kapali: false },
      });
      const us4 = await j('/isletmeler/' + A.id + '/uygun-saatler?tarih=' + yarin2,
        { token: B.token });
      kontrol('TURU 80b: kapali gun KALDIRILINCA slotlar GERI GELIR',
        kapSil.kod === 200 && us4.kod === 200 &&
        (us4.d.slotlar || []).length > 0,
        'adet=' + ((us4.d && us4.d.slotlar || []).length));
    }

    // ---------- 6) GRUP SOHBETI AVATARI (turu 78b denetimi: SEVK ENGELIYDI)
    //
    // ⚠️⚠️ BU KONTROL **ANCAK IKI HESAPLA** ANLAMLIDIR. Medya kapisi
    //    `if sahip != userID && !erisebilir(...)` seklinde: grubu KURAN kendi
    //    fotografini HER ZAMAN gorur (kisa devre). `erisebilir()`de dal
    //    olmadigi icin gruptaki DIGER HERKESE 403 donuyordu ve tek cihazda
    //    test edilse ASLA gorunmezdi. Ayni sinif turu 75b (akis), 77 (hikaye)
    //    ve 78 (kapak) icin de sahaya cikti — bu DORDUNCU tekrardi.
    const gAvatar = await medyaYukle2(A.token, 'grup.jpg', 'avatar');
    kontrol('TURU 78b: grup avatari yuklendi', gAvatar.hata === 0 && !!gAvatar.id,
      'HTTP ' + gAvatar.hata);
    if (gAvatar.id) {
      const grup = await j('/chats/group', {
        yontem: 'POST', token: A.token,
        govde: {
          title: 'E2E Grup', member_ids: [B.id], avatar_media_id: gAvatar.id,
        },
      });
      kontrol('TURU 78b: grup olusturuldu (avatarli)',
        grup.kod === 200 || grup.kod === 201, 'HTTP ' + grup.kod);

      // ⚠️ ASIL KONTROL: UYE olan B, grubun fotografini acabiliyor mu?
      const gm = await j('/media/' + gAvatar.id + '/url', { token: B.token });
      kontrol('TURU 78b: GRUP AVATARI **UYEYE** ACILIYOR (erisebilir (i) dali)',
        gm.kod === 200, 'HTTP ' + gm.kod);

      // ⚠️ GIZLILIK: uye OLMAYAN gormemeli — dal "herkese acik"a gevsetilmis mi?
      const C = await kullaniciAc('E2E Yabanci');
      const gy = await j('/media/' + gAvatar.id + '/url', { token: C.token });
      kontrol('TURU 78b: grup avatari UYE OLMAYANA KAPALI (403)',
        gy.kod === 403, 'HTTP ' + gy.kod);
    }
  }

  // ---------- TURU 81: MEDYA OLCUSU · SOHBET EKLERI · ANKET · ZAMANLANMIS
  {
    // ⚠️⚠️ MEDYA OLCUSU: `media_boyut` alani AKISTA DONUYOR MU?
    //    Donmezse istemci orani bilemez ve turu 81'in MANSET isi (kirpmasiz,
    //    degisken genislikli medya) SESSIZCE eski davranisa duser.
    const ak = await j('/feed', { token: A.token });
    const ilkMedyali = ((ak.d && ak.d.posts) || [])
      .find((p) => (p.media_ids || []).length > 0);
    kontrol('TURU 81: akis `media_boyut` alanini donduruyor',
      !!ilkMedyali && Array.isArray(ilkMedyali.media_boyut),
      'alan=' + JSON.stringify(ilkMedyali && ilkMedyali.media_boyut));
    // ⚠️ Dizi UZUNLUGU `media_ids` ile AYNI olmali — hizalama bozulursa
    //    istemci YANLIS medyaya YANLIS oran uygular.
    if (ilkMedyali) {
      kontrol('TURU 81: media_boyut ile media_ids AYNI uzunlukta (hizali)',
        (ilkMedyali.media_boyut || []).length === ilkMedyali.media_ids.length,
        'boyut=' + (ilkMedyali.media_boyut || []).length +
        ' ids=' + ilkMedyali.media_ids.length);
      // ⚠️ Bicim "WxH" olmali; "0x0" bilinmeyen olcu (eski medya) demektir.
      kontrol('TURU 81: media_boyut bicimi "WxH"',
        (ilkMedyali.media_boyut || []).every((s) => /^\d+x\d+$/.test(String(s))),
        JSON.stringify(ilkMedyali.media_boyut));
      // ⚠️⚠️ ZINCIRIN TAMAMI: presign'da gonderilen olcu, media_assets'e
      //    YAZILIP gonderi sorgusundan GERI DONUYOR mu? "0x0" gorursek sutun
      //    doldurulmuyor demektir ve turu 81'in manset isi SESSIZCE eski
      //    davranisa duser (kirpma geri gelir) — hicbir yerde hata gorunmez.
      kontrol('TURU 81: GERCEK olcu ZINCIRDEN geciyor (presign -> sutun -> akis)',
        (ilkMedyali.media_boyut || []).includes('1080x1350'),
        JSON.stringify(ilkMedyali.media_boyut));
    }

    // ---- SOHBET EKLERI (yeni mesaj tipleri, migration 039)
    const sohbet = await j('/chats/direct', {
      yontem: 'POST', token: A.token, govde: { user_id: B.id },
    });
    const chatId = sohbet.d && sohbet.d.chat_id;
    kontrol('TURU 81: sohbet acildi (ek tipler icin)', !!chatId,
      'HTTP ' + sohbet.kod);

    if (chatId) {
      // ⚠️ 'location' tipi 015'ten beri CHECK'te VARDI ama GONDEREN yol yoktu
      //    (olu ozellik sinifinin 8. ornegi). Artik kabul edilmeli.
      const konum = await j('/chats/' + chatId + '/messages', {
        yontem: 'POST', token: A.token,
        govde: { type: 'location', content: '41.008200,28.978400' },
      });
      kontrol('TURU 81: KONUM mesaji kabul ediliyor (location)',
        konum.kod === 201 || konum.kod === 200, 'HTTP ' + konum.kod);

      // ⚠️ 'contact' de 015'te VARDI ama Go beyaz listesi REDDEDIYORDU.
      const kisi = await j('/chats/' + chatId + '/messages', {
        yontem: 'POST', token: A.token,
        govde: { type: 'contact', content: B.id + '|E2E Okur' },
      });
      kontrol('TURU 81: KISI mesaji kabul ediliyor (contact)',
        kisi.kod === 201 || kisi.kod === 200, 'HTTP ' + kisi.kod);

      // ⚠️ 'iban' ve 'etkinlik' migration 039 ile CHECK'e eklendi. Bu kontrol
      //    ayni zamanda 039'un CANLI DB'de UYGULANDIGINI kanitlar — CHECK
      //    eksik olsaydi 500 donerdi (turu 78'de bu tuzaga IKI KEZ dusuldu).
      const iban = await j('/chats/' + chatId + '/messages', {
        yontem: 'POST', token: A.token,
        govde: { type: 'iban', content: 'TR330006100519786457841326|E2E' },
      });
      kontrol('TURU 81: IBAN mesaji kabul ediliyor (039 CHECK canlida)',
        iban.kod === 201 || iban.kod === 200, 'HTTP ' + iban.kod);

      const etk = await j('/chats/' + chatId + '/messages', {
        yontem: 'POST', token: A.token,
        govde: { type: 'etkinlik', content: 'x|E2E Etkinlik' },
      });
      kontrol('TURU 81: ETKINLIK mesaji kabul ediliyor (039 CHECK canlida)',
        etk.kod === 201 || etk.kod === 200, 'HTTP ' + etk.kod);

      // ⚠️ SOHBET LISTESI ONIZLEMESI: yapisal tipin HAM icerigi SIZMAMALI.
      //    Sizsaydi kullanici kilit ekraninda IBAN gorurdu (gizlilik).
      const liste = await j('/chats', { token: A.token });
      const satir = ((liste.d) || []).find((c) => c.id === chatId);
      const onizleme = satir && (satir.last_message || satir.last_content || '');
      kontrol('TURU 81: onizlemede HAM IBAN SIZMIYOR',
        !String(onizleme).includes('TR33000610051978645784'),
        'onizleme=' + JSON.stringify(onizleme));

      // ---- ANKET (migration 040)
      const anket = await j('/chats/' + chatId + '/polls', {
        yontem: 'POST', token: A.token,
        govde: {
          question: 'Bu aksam nerede bulusalim?',
          options: ['Sahil', 'Kafe', 'Evde'],
          multi: false,
        },
      });
      kontrol('TURU 81: ANKET olusturuldu (migration 040 canlida)',
        anket.kod === 201 && anket.d && anket.d.poll,
        'HTTP ' + anket.kod);

      const pollId = anket.d && anket.d.poll && anket.d.poll.id;
      if (pollId) {
        kontrol('TURU 81: anket UC secenekle dondu',
          (anket.d.poll.options || []).length === 3,
          'adet=' + (anket.d.poll.options || []).length);

        // ⚠️ SIRA KORUNUYOR MU (idx ile): `id`ye guvenilemez, BIGSERIAL
        //    GLOBAL bir dizidir ve es zamanli anketlerde CAPRAZLASIR.
        kontrol('TURU 81: secenek SIRASI korunuyor (idx)',
          (anket.d.poll.options || []).map((o) => o.text).join(',') ===
          'Sahil,Kafe,Evde',
          (anket.d.poll.options || []).map((o) => o.text).join(','));

        const sec1 = anket.d.poll.options[0].id;
        const oy = await j('/polls/' + pollId + '/vote', {
          yontem: 'POST', token: B.token, govde: { option_ids: [sec1] },
        });
        kontrol('TURU 81: B oy verdi', oy.kod === 200, 'HTTP ' + oy.kod);
        kontrol('TURU 81: oy sayildi ve vote_seq ARTTI',
          oy.d && oy.d.total_votes === 1 && oy.d.vote_seq > 0,
          'oy=' + (oy.d && oy.d.total_votes) + ' seq=' + (oy.d && oy.d.vote_seq));

        // ⚠️ TEK SECIMLIK ankette IKI secenek REDDEDILMELI (istemci hatasi
        //    sessizce ilkini almak yerine ACIKCA reddediliyor).
        const cift = await j('/polls/' + pollId + '/vote', {
          yontem: 'POST', token: B.token,
          govde: { option_ids: [sec1, anket.d.poll.options[1].id] },
        });
        kontrol('TURU 81: tek secimlikte IKI secenek REDDEDILIR (400)',
          cift.kod === 400, 'HTTP ' + cift.kod);

        // ⚠️ Oy GERI CEKME: bos kume = tum oylarimi sil.
        const geri = await j('/polls/' + pollId + '/vote', {
          yontem: 'POST', token: B.token, govde: { option_ids: [] },
        });
        kontrol('TURU 81: bos kume TUM oylari geri ceker',
          geri.kod === 200 && geri.d.total_votes === 0,
          'oy=' + (geri.d && geri.d.total_votes));

        // ⚠️ KAPATMAYI YALNIZ OLUSTURAN yapabilir.
        const yabanciKapat = await j('/polls/' + pollId + '/close', {
          yontem: 'POST', token: B.token,
        });
        kontrol('TURU 81: anketi BASKASI kapatamaz (403)',
          yabanciKapat.kod === 403, 'HTTP ' + yabanciKapat.kod);

        const kapat = await j('/polls/' + pollId + '/close', {
          yontem: 'POST', token: A.token,
        });
        kontrol('TURU 81: olusturan anketi kapatti',
          kapat.kod === 200 && kapat.d.closed === true, 'HTTP ' + kapat.kod);

        const kapaliOy = await j('/polls/' + pollId + '/vote', {
          yontem: 'POST', token: B.token, govde: { option_ids: [sec1] },
        });
        kontrol('TURU 81: KAPALI ankete oy verilemez (409)',
          kapaliOy.kod === 409, 'HTTP ' + kapaliOy.kod);
      }

      // ⚠️⚠️ ANKET MESAJ LISTESINDE `poll` ALANIYLA DONUYOR MU?
      //    Donmezse balon YALNIZ yeni mesajda cizilir ve sohbete tekrar
      //    girildiginde duz SORU METNI gorunur — yani ozellik yeniden
      //    acilista OLU olur.
      const msjlar = await j('/chats/' + chatId + '/messages', { token: A.token });
      const anketMsj = ((msjlar.d) || []).find((m) => m.type === 'poll');
      kontrol('TURU 81: mesaj listesi anketi `poll` alaniyla donduruyor',
        !!anketMsj && !!anketMsj.poll &&
        (anketMsj.poll.options || []).length === 3,
        'poll=' + JSON.stringify(anketMsj && anketMsj.poll && anketMsj.poll.id));
    }

    // ---- ZAMANLANMIS PAYLASIM (migration 041)
    const gelecek = new Date(Date.now() + 3600000).toISOString();
    const zg = await j('/posts', {
      yontem: 'POST', token: A.token,
      govde: { tur: 'yazi', metin: 'E2E ZAMANLANMIS', yayin_at: gelecek },
    });
    kontrol('TURU 81: zamanlanmis gonderi olusturuldu (041 canlida)',
      zg.kod === 201 && !!zg.d.id, 'HTTP ' + zg.kod);

    if (zg.d && zg.d.id) {
      // ⚠️⚠️ EN KRITIK: zamanlanmis gonderi BASKASININ akisinda GORUNMEMELI.
      //    Yuklem tek bir sorguda eksik kalsa bile burada YAKALANIR.
      const bAkis = await j('/feed', { token: B.token });
      const sizdi = ((bAkis.d && bAkis.d.posts) || [])
        .some((p) => p.id === zg.d.id);
      kontrol('TURU 81: ZAMANLANMIS gonderi BASKASININ AKISINDA GORUNMEZ',
        !sizdi, 'sizdi=' + sizdi);

      const bKesfet = await j('/kesfet', { token: B.token });
      const sizdi2 = ((bKesfet.d && bKesfet.d.posts) || [])
        .some((p) => p.id === zg.d.id);
      kontrol('TURU 81: ZAMANLANMIS gonderi KESFET\'te GORUNMEZ',
        !sizdi2, 'sizdi=' + sizdi2);

      const bProfil = await j('/users/' + A.id + '/posts', { token: B.token });
      const sizdi3 = ((bProfil.d && bProfil.d.posts) || [])
        .some((p) => p.id === zg.d.id);
      kontrol('TURU 81: ZAMANLANMIS gonderi BASKASININ gozunde PROFILDE GORUNMEZ',
        !sizdi3, 'sizdi=' + sizdi3);

      // ⚠️ YAZAR KENDI zamanladigini GORMELI (yoksa "kayboldu" sanar).
      const aProfil = await j('/users/' + A.id + '/posts', { token: A.token });
      const yazarGoruyor = ((aProfil.d && aProfil.d.posts) || [])
        .some((p) => p.id === zg.d.id);
      kontrol('TURU 81: YAZAR kendi zamanladigi gonderiyi PROFILINDE GORUR',
        yazarGoruyor, 'goruyor=' + yazarGoruyor);

      // ⚠️ Yayinlanmamis gonderi ETKILESIME KAPALI (muhafizin buldugu bosluk).
      const bBegeni = await j('/posts/' + zg.d.id + '/like', {
        yontem: 'POST', token: B.token,
      });
      kontrol('TURU 81: ZAMANLANMIS gonderi BEGENILEMEZ (403)',
        bBegeni.kod === 403, 'HTTP ' + bBegeni.kod);
    }

    // ================= TURU 83: GONDERI ANKETI (migration 042) =================
    //
    // ⚠️ EN KRITIK: anket SOHBET hattina civiliydi (`polls.message_id NOT NULL`).
    //    042 onu gevsetti. Bu blok zincirin UCUNU birden sinar:
    //    olusturma -> akista DONME -> oy -> YETKI -> kapatma.
    const ga = await j('/posts', {
      yontem: 'POST', token: A.token,
      govde: {
        tur: 'yazi', metin: '',
        anket: {
          question: 'E2E gonderi anketi?',
          options: ['Evet', 'Hayir', 'Belki'],
          multi: false,
        },
      },
    });
    kontrol('TURU 83: ANKETLI gonderi olusturuldu (042 canlida)',
      ga.kod === 201 && !!ga.d.id, 'HTTP ' + ga.kod);
    // ⚠️ Metin BOS ama anket VAR -> kabul edilmeli (anketin sorusu icerik tasir).
    kontrol('TURU 83: METINSIZ ama ANKETLI gonderi KABUL EDILIYOR',
      ga.kod === 201, 'HTTP ' + ga.kod);
    kontrol('TURU 83: yanit anket_id donduruyor',
      !!(ga.d && ga.d.anket_id), 'anket_id=' + (ga.d && ga.d.anket_id));

    if (ga.d && ga.d.id && ga.d.anket_id) {
      const pollID = ga.d.anket_id;

      // ⚠️⚠️ ZINCIRIN EN DEGERLI HALKASI: anket AKISTA donuyor mu?
      //    `satirlariOku` imzasi degistirildi (ctx+userID) ve anketler TEK
      //    sorguda ekleniyor; bu adim o zincirin CALISTIGINI kanitlar.
      //    Donmeseydi kullanici anketi HIC goremezdi (sessiz olu ozellik).
      // ⚠️ **PROFIL** sorgusu kullanilir, `/kesfet` DEGIL: Keşfet bir IZGARA
      //    ve `cardinality(p.media_ids) > 0` suzguyor — medyasiz bir anket
      //    gonderisi oraya TANIM GEREGI girmez. (Ilk yazimda `/kesfet`
      //    kullanilmis ve kontrol KIRMIZI dusmustu; kod degil TESTIN YUZEYI
      //    yanlisti. Turu 80b dersi: "bir testin kirmizisi de yesili de once
      //    DOGRU YUZEYDE mi diye sorulmali.")
      const aProfilAnket = await j('/users/' + A.id + '/posts', {
        token: A.token,
      });
      const ap = ((aProfilAnket.d && aProfilAnket.d.posts) || [])
        .find((p) => p.id === ga.d.id);
      kontrol('TURU 83: anket AKIS SORGUSUNDA donuyor (satirlariOku zinciri)',
        !!(ap && ap.anket), 'anket=' + !!(ap && ap.anket));
      kontrol('TURU 83: anket UC secenekle donuyor',
        !!(ap && ap.anket && (ap.anket.options || []).length === 3),
        'adet=' + ((ap && ap.anket && (ap.anket.options || []).length) || 0));

      // ⚠️ B (baska hesap) oy verebilmeli — gorunurluk kapisi `GorunurMu`.
      //    `chat.SetGonderiGorunur` BAGLANMAMIS olsaydi burada 403 alirdik;
      //    yani bu kontrol main.go'daki BAGI da dogruluyor.
      const opt = ap && ap.anket && ap.anket.options && ap.anket.options[0];
      if (opt) {
        const oy = await j('/polls/' + pollID + '/vote', {
          yontem: 'POST', token: B.token, govde: { option_ids: [opt.id] },
        });
        kontrol('TURU 83: BASKA HESAP gonderi anketine oy verebiliyor',
          oy.kod === 200, 'HTTP ' + oy.kod);
        kontrol('TURU 83: oy sayildi',
          !!(oy.d && (oy.d.options || []).some((o) => o.votes === 1)),
          'sayim=' + JSON.stringify((oy.d && oy.d.options || []).map((o) => o.votes)));
      }

      // ⚠️ Anketi YALNIZ olusturan kapatabilir.
      const kapatB = await j('/polls/' + pollID + '/close', {
        yontem: 'POST', token: B.token,
      });
      kontrol('TURU 83: gonderi anketini BASKASI KAPATAMAZ (403)',
        kapatB.kod === 403, 'HTTP ' + kapatB.kod);
      const kapatA = await j('/polls/' + pollID + '/close', {
        yontem: 'POST', token: A.token,
      });
      kontrol('TURU 83: olusturan gonderi anketini kapatti',
        kapatA.kod === 200, 'HTTP ' + kapatA.kod);
    }

    // ⚠️ GECERSIZ anket (tek secenek) 400 donmeli — dogrulama SOHBETLE AYNI
    //    sabitlerden geliyor (`chat.GonderiAnketiYaz`).
    const kotuAnket = await j('/posts', {
      yontem: 'POST', token: A.token,
      govde: {
        tur: 'yazi', metin: 'kotu',
        anket: { question: 'Tek secenek', options: ['Evet'], multi: false },
      },
    });
    kontrol('TURU 83: TEK secenekli anket REDDEDILIYOR (400)',
      kotuAnket.kod === 400, 'HTTP ' + kotuAnket.kod);

    // ================= TURU 83: GONDERIDE SES =================
    //
    // ⚠️ Ses icin MIGRATION GEREKMEDI (`media_assets.kind` 037'den beri
    //    'audio' kabul ediyor). Bu kontrol o varsayimin CANLIDA da dogru
    //    oldugunu kanitlar: presign 'audio' ile GECMELI.
    // ⚠️ Uc adi `/media/upload` (presign DEGIL) — ilk yazimda `/media/presign`
    //    denenmis ve 404 alinmisti. Yol adi kaynaktan dogrulandi (main.go).
    const sesPre = await j('/media/upload', {
      yontem: 'POST', token: A.token,
      govde: {
        kind: 'audio', mime: 'audio/mp4',
        bytes: 4096, file_name: 'e2e.m4a',
        md5: 'AAAAAAAAAAAAAAAAAAAAAA==',
      },
    });
    kontrol('TURU 83: kind=audio presign KABUL EDILIYOR (CHECK gecti)',
      sesPre.kod === 200 || sesPre.kod === 201,
      'HTTP ' + sesPre.kod + ' ' + JSON.stringify(sesPre.d).slice(0, 120));
  }

  // ================= TURU 84: ADIMLI KAYIT (telefon -> OTP -> bilgiler) =====
  //
  // ⚠️ Zincirin UCU birden sinanir. En kritik olan ADIM 3'un telefonu
  //    **JETONDAN** almasi: istekten alsaydi biri kendi numarasini dogrulayip
  //    BASKASININ numarasina hesap acabilirdi.
  {
    const tel = '+9055' + String(Date.now()).slice(-8);
    const a1 = await j('/auth/kayit/telefon', { yontem: 'POST', govde: { phone: tel } });
    kontrol('TURU 84: adim 1 telefon kabul edildi', a1.kod === 200, 'HTTP ' + a1.kod);
    kontrol('TURU 84: test modunda dev_otp donuyor', !!(a1.d && a1.d.dev_otp),
      'dev_otp=' + !!(a1.d && a1.d.dev_otp));

    // ⚠️ Hesap HENUZ OLUSMAMALI — eski /register'dan EN ONEMLI fark.
    const erken = await j('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: 'herhangi123' },
    });
    kontrol('TURU 84: adim 1 sonrasi HESAP YOK (giris basarisiz)',
      erken.kod === 401 || erken.kod === 400, 'HTTP ' + erken.kod);

    const kod = a1.d && a1.d.dev_otp;
    const yanlis = await j('/auth/kayit/dogrula', {
      yontem: 'POST', govde: { phone: tel, code: '000000' },
    });
    kontrol('TURU 84: YANLIS kod reddediliyor', yanlis.kod === 400, 'HTTP ' + yanlis.kod);

    const a2 = await j('/auth/kayit/dogrula', {
      yontem: 'POST', govde: { phone: tel, code: kod },
    });
    kontrol('TURU 84: adim 2 kod dogrulandi', a2.kod === 200, 'HTTP ' + a2.kod);
    kontrol('TURU 84: KAYIT JETONU donuyor', !!(a2.d && a2.d.kayit_jetonu),
      'jeton=' + !!(a2.d && a2.d.kayit_jetonu));

    // ⚠️ AYNI kod IKINCI KEZ kullanilamaz (consumeOTP tuketir).
    const tekrar = await j('/auth/kayit/dogrula', {
      yontem: 'POST', govde: { phone: tel, code: kod },
    });
    kontrol('TURU 84: kod IKINCI KEZ kullanilamaz', tekrar.kod === 400, 'HTTP ' + tekrar.kod);

    const jeton = a2.d && a2.d.kayit_jetonu;
    // ⚠️ GECERSIZ jeton reddedilmeli (imza kontrolu + alg kilidi).
    const sahte = await j('/auth/kayit/tamamla', {
      yontem: 'POST',
      govde: {
        kayit_jetonu: 'sahte.jeton.imza', name: 'X',
        username: 'x' + String(Date.now()).slice(-6), password: 'abc123',
      },
    });
    kontrol('TURU 84: SAHTE kayit jetonu reddediliyor (401)', sahte.kod === 401,
      'HTTP ' + sahte.kod);

    const kadi = 'e2e' + String(Date.now()).slice(-7);
    const a3 = await j('/auth/kayit/tamamla', {
      yontem: 'POST',
      govde: {
        kayit_jetonu: jeton, name: 'E2E Adimli',
        username: kadi, password: 'gizli123',
        // TURU 120 — kayit akisinin "Biraz da senden" adimi.
        // ⚠️ YAS DEGIL DOGUM YILI: yas her yil degisir.
        dogum_yili: new Date().getFullYear() - 28,
        ilgi_alanlari: ['Futbol', 'Kahve', 'futbol', '  '],
        takim: 'Kocaelispor',
      },
    });
    kontrol('TURU 84: adim 3 hesap olustu', a3.kod === 200, 'HTTP ' + a3.kod);
    kontrol('TURU 84: oturum jetonu donuyor', !!(a3.d && a3.d.token),
      'token=' + !!(a3.d && a3.d.token));

    // ⚠️ Telefon JETONDAN mi geldi? Olusan hesabin telefonu adim 1'deki olmali.
    kontrol('TURU 84: hesap DOGRULANMIS telefonla acildi',
      !!(a3.d && a3.d.user && a3.d.user.phone === tel),
      'phone=' + (a3.d && a3.d.user && a3.d.user.phone));

    // ⚠️ Ayni numara IKINCI kez kayit BASLATAMAZ (adim 1 kapisi) — kullanici
    //    uc adim doldurup EN SONDA duvara toslamasin diye burada kontrol edilir.
    const tekrarKayit = await j('/auth/kayit/telefon', {
      yontem: 'POST', govde: { phone: tel },
    });
    kontrol('TURU 84: KAYITLI numara ile kayit baslatilamaz (409)',
      tekrarKayit.kod === 409, 'HTTP ' + tekrarKayit.kod);

    // ---------- TURU 120: YAS · ILGI ALANLARI · TAKIM ----------
    // ⚠️ Bu blok, kayit akisinin "Biraz da senden" adiminin OLU OLMADIGINI
    //    dogrular: alanlar sunucuya gidiyor, SAKLANIYOR ve GERI DONUYOR.
    //    Bu projede "sutun/uc var ama onu kullanan yol yok" sinifi DOKUZ
    //    kez sahaya cikti.
    if (a3.kod === 200 && a3.d && a3.d.token) {
      const jt = a3.d.token;
      const me = await j('/users/me', { token: jt });
      const buYil = new Date().getFullYear();
      kontrol('TURU 120: /users/me DOGUM YILI donduruyor',
        me.kod === 200 && me.d && me.d.dogum_yili === buYil - 28,
        'dogum_yili=' + (me.d && me.d.dogum_yili));

      // ⚠️ TemizIlgi: bosluk ATILIR, harf duyarsiz TEKRAR elenir.
      //    Gonderilen ['Futbol','Kahve','futbol','  '] -> ['Futbol','Kahve'].
      const ilgi = (me.d && me.d.ilgi_alanlari) || [];
      kontrol('TURU 120: ILGI ALANLARI tekrarsiz + bosluksuz saklandi',
        Array.isArray(ilgi) && ilgi.length === 2 && ilgi[0] === 'Futbol' &&
        ilgi[1] === 'Kahve', 'ilgi=' + JSON.stringify(ilgi));

      kontrol('TURU 120: TAKIM saklandi',
        me.d && me.d.takim === 'Kocaelispor', 'takim=' + (me.d && me.d.takim));

      // ⚠️⚠️ PROFIL UCU (herkese acik) DA dondurmeli: yalniz /users/me
      //    donseydi ozellik BASKA HIC KIMSEDE gorunmezdi — turu 78`de
      //    kapak + onayli rozeti tam boyle kaybolmustu (SELECT + Scan
      //    vardi, YANIT HARITASINDA anahtar YOKTU).
      const uid = a3.d.user_id || (a3.d.user && a3.d.user.id);
      const pr = await j('/users/' + uid + '/profile', { token: A.token });
      kontrol('TURU 120: PROFIL ucu yas/ilgi/takim donduruyor',
        pr.kod === 200 && pr.d && pr.d.dogum_yili === buYil - 28 &&
        pr.d.takim === 'Kocaelispor' &&
        Array.isArray(pr.d.ilgi_alanlari) && pr.d.ilgi_alanlari.length === 2,
        'HTTP ' + pr.kod + ' d=' + JSON.stringify(pr.d && {
          y: pr.d.dogum_yili, t: pr.d.takim, i: pr.d.ilgi_alanlari,
        }));

      // ⚠️⚠️ SADECE ADI DEGISTIREN BIR PATCH, yas/ilgi/takim alanlarini
      //    EZMEMELI. Turu 85b`de `isletme_duzenle` tam bunu yapiyordu:
      //    adres/il/ilce SESSIZCE bosa cekiliyordu.
      await j('/users/me', {
        yontem: 'PATCH', token: jt, govde: { name: 'E2E Adimli 2' },
      });
      const me2 = await j('/users/me', { token: jt });
      kontrol('TURU 120: kismi PATCH yas/ilgi/takim ALANLARINI KORUR',
        me2.kod === 200 && me2.d && me2.d.dogum_yili === buYil - 28 &&
        me2.d.takim === 'Kocaelispor' &&
        (me2.d.ilgi_alanlari || []).length === 2,
        'y=' + (me2.d && me2.d.dogum_yili) + ' t=' + (me2.d && me2.d.takim) +
        ' i=' + JSON.stringify(me2.d && me2.d.ilgi_alanlari));

      // ⚠️ Bos dizi = TEMIZLE (dokunma DEGIL). `*[]string` bu iki durumu
      //    ayirmak icin secildi.
      await j('/users/me', {
        yontem: 'PATCH', token: jt, govde: { ilgi_alanlari: [], takim: '' },
      });
      const me3 = await j('/users/me', { token: jt });
      kontrol('TURU 120: bos dizi ILGI ALANLARINI TEMIZLER',
        me3.kod === 200 && me3.d && (me3.d.ilgi_alanlari || []).length === 0 &&
        me3.d.takim === '',
        'i=' + JSON.stringify(me3.d && me3.d.ilgi_alanlari) +
        ' t=' + (me3.d && me3.d.takim));

      // ⚠️ MAKUL ARALIK DISI dogum yili SESSIZCE DUSURULUR (400 DEGIL):
      //    alan opsiyonel ve istemci secicisi araligi zaten kisitliyor;
      //    reddetmek kullaniciyi kayit akisinda MAHSUR birakirdi.
      await j('/users/me', {
        yontem: 'PATCH', token: jt, govde: { dogum_yili: 1800 },
      });
      const me4 = await j('/users/me', { token: jt });
      kontrol('TURU 120: SACMA dogum yili (1800) SESSIZCE DUSURULUR',
        me4.kod === 200 && me4.d && me4.d.dogum_yili === buYil - 28,
        'dogum_yili=' + (me4.d && me4.d.dogum_yili));

      // ⚠️ TAVAN: sunucu en fazla 12 ilgi alani saklar. Tavansiz birakmak
      //    profile 10 KB metin yazdirmaya izin verirdi.
      const cok = [];
      for (let i = 0; i < 30; i++) cok.push('ilgi' + i);
      await j('/users/me', {
        yontem: 'PATCH', token: jt, govde: { ilgi_alanlari: cok },
      });
      const me5 = await j('/users/me', { token: jt });
      kontrol('TURU 120: ILGI ALANI TAVANI 12 (30 gonderildi)',
        me5.kod === 200 && me5.d && (me5.d.ilgi_alanlari || []).length === 12,
        'adet=' + ((me5.d && me5.d.ilgi_alanlari) || []).length);
    }
  }

  // ================= TURU 85: YAKINIMDA + YENI KATEGORILER ==============
  //
  // ON KOSUL: isletmeler.enlem/boylam 028 ten beri VARDI ama HICBIR KAYITTA
  // DOLU DEGILDI (turu 78 notu). Turu 85 koordinat girisini ekledi; bu blok
  // zincirin UCUNU sinar: kaydet -> yakinimda -> mesafe -> siralama.
  {
    const konumlu = await j('/users/me/isletme', {
      yontem: 'PUT', token: A.token,
      govde: {
        kategori: 'eczane', adres: 'E2E Eczane', il: 'Kocaeli', ilce: 'Gebze',
        enlem: 40.8020, boylam: 29.4300,
      },
    });
    kontrol('TURU 85: YENI KATEGORI (eczane) kabul ediliyor',
      konumlu.kod === 200 || konumlu.kod === 201, 'HTTP ' + konumlu.kod);

    const otel = await j('/users/me/isletme', {
      yontem: 'PUT', token: B.token,
      govde: {
        kategori: 'otel', adres: 'E2E Otel', il: 'Kocaeli', ilce: 'Gebze',
        enlem: 40.8100, boylam: 29.4400,
      },
    });
    kontrol('TURU 85: YENI KATEGORI (otel) kabul ediliyor',
      otel.kod === 200 || otel.kod === 201, 'HTTP ' + otel.kod);

    const yak = await j('/isletmeler/yakinimda?lat=40.8020&lng=29.4300&km=10',
      { token: A.token });
    kontrol('TURU 85: /isletmeler/yakinimda calisiyor', yak.kod === 200,
      'HTTP ' + yak.kod);
    const liste = (yak.d && yak.d.isletmeler) || [];
    kontrol('TURU 85: yakindaki isletmeler donuyor', liste.length >= 1,
      'adet=' + liste.length);

    // MESAFE SUNUCUDA hesaplanip donuyor (istemcide tekrar hesaplamak
    // "ayni kuralin iki kopyasi" olurdu ve siralamayla AYRISABILIRDI).
    kontrol('TURU 85: her kayitta km alani var',
      liste.length > 0 && liste.every((x) => typeof x.km === 'number'),
      'adet=' + liste.length);

    let sirali = true;
    for (let i = 1; i < liste.length; i++) {
      if (liste[i].km < liste[i - 1].km) sirali = false;
    }
    kontrol('TURU 85: liste MESAFEYE gore sirali', sirali, 'sirali=' + sirali);

    // Yanit anahtari dogrulandi olmali - ilk yazimda onayli yazilmisti ve
    // istemci dogrulandi okudugu icin onayli rozeti HIC cizilmezdi.
    kontrol('TURU 85: yanit dogrulandi anahtarini tasiyor',
      liste.length > 0 && liste.every((x) => 'dogrulandi' in x),
      'anahtar=' + (liste[0] ? Object.keys(liste[0]).join(',') : '-'));

    // KONUMSUZ isletme listede CIKMAMALI (0,0 = Gine Korfezi).
    const K = await kullaniciAc('E2E Konumsuz');
    await j('/users/me/isletme', {
      yontem: 'PUT', token: K.token,
      govde: { kategori: 'market', adres: 'Konumsuz', il: 'Kocaeli',
               ilce: 'Gebze' },
    });
    const yak2 = await j('/isletmeler/yakinimda?lat=40.8020&lng=29.4300&km=50',
      { token: A.token });
    const l2 = (yak2.d && yak2.d.isletmeler) || [];
    kontrol('TURU 85: KONUMSUZ isletme listede CIKMIYOR',
      !l2.some((x) => x.id === K.id),
      'sizdi=' + l2.some((x) => x.id === K.id));

    // Cok uzak bir noktadan bakinca liste BOSALMALI (Ankara).
    const uzak = await j('/isletmeler/yakinimda?lat=39.9208&lng=32.8541&km=5',
      { token: A.token });
    kontrol('TURU 85: UZAK noktadan bakinca liste bos (mesafe suzgeci)',
      ((uzak.d && uzak.d.isletmeler) || []).length === 0,
      'adet=' + ((uzak.d && uzak.d.isletmeler) || []).length);

    const konumsuzIstek = await j('/isletmeler/yakinimda', { token: A.token });
    kontrol('TURU 85: konumsuz istek REDDEDILIYOR (400)',
      konumsuzIstek.kod === 400, 'HTTP ' + konumsuzIstek.kod);

    const kotuKat = await j(
      '/isletmeler/yakinimda?lat=40.80&lng=29.43&kategori=yokboyle',
      { token: A.token });
    kontrol('TURU 85: gecersiz kategori REDDEDILIYOR (400)',
      kotuKat.kod === 400, 'HTTP ' + kotuKat.kod);
  }

  // ================= TURU 85b: KONUM KALDIRMA + VITRIN DIKEYI ===========
  {
    const Z = await kullaniciAc('E2E KonumSil');
    // Konumlu isletme olustur.
    await j('/users/me/isletme', {
      yontem: 'PUT', token: Z.token,
      govde: { kategori: 'otel', adres: 'Konum silinecek', il: 'Kocaeli',
               ilce: 'Gebze', enlem: 40.8050, boylam: 29.4350 },
    });
    const v1 = await j('/isletmeler/yakinimda?lat=40.8050&lng=29.4350&km=5',
      { token: A.token });
    kontrol('TURU 85b: konumlu isletme listede GORUNUYOR',
      ((v1.d && v1.d.isletmeler) || []).some((x) => x.id === Z.id),
      'var=' + ((v1.d && v1.d.isletmeler) || []).some((x) => x.id === Z.id));

    // ⚠️ BASKA bir alani guncelle, KONUM GONDERME -> konum KORUNMALI.
    await j('/users/me/isletme', {
      yontem: 'PUT', token: Z.token,
      govde: { kategori: 'otel', adres: 'Adres degisti', il: 'Kocaeli',
               ilce: 'Gebze' },
    });
    const v2 = await j('/isletmeler/yakinimda?lat=40.8050&lng=29.4350&km=5',
      { token: A.token });
    kontrol('TURU 85b: konum GONDERILMEYINCE KORUNUYOR (COALESCE)',
      ((v2.d && v2.d.isletmeler) || []).some((x) => x.id === Z.id),
      'korundu=' + ((v2.d && v2.d.isletmeler) || []).some((x) => x.id === Z.id));

    // ⚠️ ACIKCA 0 gonder -> konum SIFIRLANMALI ("Konumu kaldir" dugmesi).
    //    Onceden istemci 0 i HIC GONDERMIYORDU ve dugme OLU IDI.
    await j('/users/me/isletme', {
      yontem: 'PUT', token: Z.token,
      govde: { kategori: 'otel', adres: 'Adres degisti', il: 'Kocaeli',
               ilce: 'Gebze', enlem: 0, boylam: 0 },
    });
    const v3 = await j('/isletmeler/yakinimda?lat=40.8050&lng=29.4350&km=5',
      { token: A.token });
    kontrol('TURU 85b: ACIKCA 0 gonderilince konum SIFIRLANIYOR (kaldirma)',
      !((v3.d && v3.d.isletmeler) || []).some((x) => x.id === Z.id),
      'silindi=' + !((v3.d && v3.d.isletmeler) || []).some((x) => x.id === Z.id));

    // ⚠️ VITRIN DIKEYI: yeni kategoriler `isletmeDikeyleri`nden TURETILIYOR.
    //    Elle yazilan eski kopya guncellenmemisti ve /vitrin?dikey=eczane
    //    sessizce "yaklasan etkinlikler" daline dusuyordu.
    const vitEczane = await j('/vitrin?dikey=eczane', { token: A.token });
    kontrol('TURU 85b: /vitrin?dikey=eczane calisiyor (dikey taniniyor)',
      vitEczane.kod === 200, 'HTTP ' + vitEczane.kod);
    const vitOtel = await j('/vitrin?dikey=otel', { token: A.token });
    kontrol('TURU 85b: /vitrin?dikey=otel calisiyor', vitOtel.kod === 200,
      'HTTP ' + vitOtel.kod);
  }

  // ============= TURU 85c: ADIMLI KAYIT (telefon -> OTP -> bilgiler) =====
  {
    const tel = '+90555' + rastgele() + String(rastgele()).slice(0, 1);
    const kadi = 'e2e' + rastgele();

    // --- ADIM 1: telefon
    const a1 = await j('/auth/kayit/telefon', {
      yontem: 'POST', govde: { phone: tel },
    });
    kontrol('TURU 85c: adim 1 (telefon) SMS kodu uretiyor',
      a1.kod === 200 && !!a1.d.dev_otp, 'HTTP ' + a1.kod);

    // ⚠️ ADIM 1 HESAP OLUSTURMAZ — eski /auth/register den EN ONEMLI farki.
    const erken = await j('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: 'Test12345!' },
    });
    kontrol('TURU 85c: adim 1 HESAP OLUSTURMUYOR (giris yok)',
      erken.kod >= 400, 'HTTP ' + erken.kod);

    // --- ADIM 2: OTP -> kayit jetonu
    const a2 = await j('/auth/kayit/dogrula', {
      yontem: 'POST', govde: { phone: tel, code: String(a1.d.dev_otp) },
    });
    kontrol('TURU 85c: adim 2 (OTP) kayit jetonu veriyor',
      a2.kod === 200 && !!a2.d.kayit_jetonu, 'HTTP ' + a2.kod);

    // ⚠️ Yanlis kod REDDEDILMELI.
    const kotuKod = await j('/auth/kayit/dogrula', {
      yontem: 'POST', govde: { phone: tel, code: '000000' },
    });
    kontrol('TURU 85c: yanlis OTP reddediliyor', kotuKod.kod >= 400,
      'HTTP ' + kotuKod.kod);

    // ⚠️ TURU 85b: 72 BAYT TAVANI (eski ucta vardi, yenisinde ATLANMISTI ->
    //    uzun sifre bcrypt hatasina, oradan jenerik 500 e dusuyordu).
    const uzun = await j('/auth/kayit/tamamla', {
      yontem: 'POST',
      govde: { kayit_jetonu: a2.d.kayit_jetonu, name: 'Uzun',
               username: kadi, password: 'x'.repeat(80) },
    });
    kontrol('TURU 85c: 72 bayttan uzun sifre 400 doner (500 DEGIL)',
      uzun.kod === 400, 'HTTP ' + uzun.kod);

    // --- ADIM 3: bilgiler -> hesap + oturum
    // ⚠️ Kullanici adi @ ON EKIYLE gonderiliyor: form onu gosteriyor ve
    //    kullanicilar yaziyor; eski uc kirpiyordu, yenisi ATLAMISTI.
    const a3 = await j('/auth/kayit/tamamla', {
      yontem: 'POST',
      govde: { kayit_jetonu: a2.d.kayit_jetonu, name: 'E2E Adimli',
               username: '@' + kadi, password: 'Test12345!' },
    });
    kontrol('TURU 85c: adim 3 hesabi olusturuyor', a3.kod === 200,
      'HTTP ' + a3.kod);

    // ⚠️⚠️ SEVK ENGELIYDI: istemci `user_id` okuyor; alan YOKSA TypeError
    //    firlatir, oturum HIC kaydedilmez ve kayit ASLA tamamlanamaz.
    kontrol('TURU 85c: yanit `user_id` ICERIYOR (istemci sozlesmesi)',
      typeof (a3.d || {}).user_id === 'string' && a3.d.user_id.length > 0,
      'anahtarlar=' + Object.keys(a3.d || {}).join(','));
    kontrol('TURU 85c: yanit oturum jetonu ICERIYOR',
      !!(a3.d && a3.d.token), 'token=' + !!(a3.d && a3.d.token));

    kontrol('TURU 85c: `@` on eki KIRPILIYOR (kullanici adi kaydedildi)',
      ((a3.d && a3.d.user && a3.d.user.username) || '') === kadi,
      'kadi=' + ((a3.d && a3.d.user && a3.d.user.username) || '-'));

    // ⚠️⚠️⚠️ SEVK ENGELIYDI: `verified` yazilmiyordu -> yeni akisla acilan
    //    HER hesap giris yapamiyordu (Login: !verified -> 403) ve kurtarma
    //    yolu da yoktu (Forgot/Reset de `verified=true` istiyor).
    const giris = await j('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: 'Test12345!' },
    });
    kontrol('TURU 85c: ADIMLI KAYITLA ACILAN HESAP GIRIS YAPABILIYOR',
      giris.kod === 200 && !!giris.d.token, 'HTTP ' + giris.kod);

    // ⚠️ Kayit bonusu defterine yazilmali (bakiye ile defter ayrismasin).
    const ben = await j('/users/me', { token: a3.d.token });
    kontrol('TURU 85c: yeni hesap /users/me okuyabiliyor',
      ben.kod === 200 && ben.d.id === a3.d.user_id, 'HTTP ' + ben.kod);

    // ⚠️⚠️ TURU 85b: JETON TEKRAR OYNATMA. Ayni jetonla ikinci cagri
    //    hesabin SIFRESINI EZMEMELI; yeniden deneme icin oturum DONER.
    const tekrar = await j('/auth/kayit/tamamla', {
      yontem: 'POST',
      govde: { kayit_jetonu: a2.d.kayit_jetonu, name: 'SALDIRGAN',
               username: kadi, password: 'BaskaSifre999!' },
    });
    const eskiSifre = await j('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: 'Test12345!' },
    });
    kontrol('TURU 85c: jeton TEKRAR OYNATILINCA sifre EZILMIYOR',
      eskiSifre.kod === 200,
      'tekrar=' + tekrar.kod + ' eskiSifreGiris=' + eskiSifre.kod);
    const yeniSifre = await j('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: 'BaskaSifre999!' },
    });
    kontrol('TURU 85c: tekrar oynatmadaki YENI sifre GECERSIZ',
      yeniSifre.kod >= 400, 'HTTP ' + yeniSifre.kod);

    // ⚠️ Adim 1 artik `verified` olcutunu kullaniyor (girisle AYNI olcut).
    const tekrarKayit = await j('/auth/kayit/telefon', {
      yontem: 'POST', govde: { phone: tel },
    });
    kontrol('TURU 85c: tamamlanmis numara icin adim 1 REDDEDIYOR (409)',
      tekrarKayit.kod === 409, 'HTTP ' + tekrarKayit.kod);

    // ⚠️ Gecersiz jetonla adim 3 -> 401 (telefon JETONDAN okunuyor).
    const sahte = await j('/auth/kayit/tamamla', {
      yontem: 'POST',
      govde: { kayit_jetonu: 'sahte.jeton.imza', name: 'X',
               username: 'e2e' + rastgele(), password: 'Test12345!' },
    });
    kontrol('TURU 85c: sahte kayit jetonu 401', sahte.kod === 401,
      'HTTP ' + sahte.kod);
  }

  // ============= TURU 85c: YAKINIMDA KABA KUTU (cos duzeltmesi) =========
  {
    // ⚠️⚠️ Kutu boylamda `111.0`a bolunuyordu; Gebze enleminde 1 derece
    //    boylam ~84 km oldugu icin kutu ~%24 DAR kaliyor ve yaricap
    //    ICINDEKI isletmeler SESSIZCE eleniyordu. Bu kontrol tam o
    //    araliga bir isletme koyar: DUZ 111.0 ile KIRMIZI duser.
    const D = await kullaniciAc('E2E Dogu');
    const lat = 40.8000, lng = 29.4000;
    // 8 km dogusu: 8 / (111 * cos(40.8)) = ~0.0952 derece.
    // Yanlis (duz) kutu yalniz 8/111 = 0.0721 derece kapsardi -> ELERDI.
    const dLng = 8.0 / (111.0 * Math.cos((lat * Math.PI) / 180));
    await j('/users/me/isletme', {
      yontem: 'PUT', token: D.token,
      govde: { kategori: 'eczane', adres: 'Dogudaki eczane', il: 'Kocaeli',
               ilce: 'Gebze', enlem: lat, boylam: lng + dLng },
    });
    const y = await j(
      '/isletmeler/yakinimda?lat=' + lat + '&lng=' + lng + '&km=10',
      { token: D.token });
    const bulundu = ((y.d && y.d.isletmeler) || []).some((x) => x.id === D.id);
    kontrol('TURU 85c: KABA KUTU boylamda cos duzeltmesi yapiyor',
      bulundu, 'bulundu=' + bulundu + ' dLng=' + dLng.toFixed(4));

    // ⚠️ NaN koordinat 400 donmeli (ParseFloat NaN i KABUL EDER ve NaN her
    //    karsilastirmadan gecer -> eskiden SESSIZ BOS liste donuyordu).
    const nan = await j('/isletmeler/yakinimda?lat=NaN&lng=29.4&km=5',
      { token: D.token });
    kontrol('TURU 85c: NaN koordinat 400 (sessiz bos liste DEGIL)',
      nan.kod === 400, 'HTTP ' + nan.kod);
  }

  // ============= TURU 89: KATEGORIYE OZEL ISLETME MODULLERI ============
  {
    const O = await kullaniciAc('E2E Otel');

    // --- Modul haritasi ucu
    const mods = await j('/isletme-modulleri', { token: O.token });
    kontrol('TURU 89: GET /isletme-modulleri calisiyor', mods.kod === 200,
      'HTTP ' + mods.kod);
    const otelM = ((mods.d || {}).moduller || {}).otel || {};
    kontrol('TURU 89: otel modulu ODALAR', otelM.ad === 'Odalar' && otelM.tur === 'oda',
      'ad=' + otelM.ad + ' tur=' + otelM.tur);
    const saglikM = ((mods.d || {}).moduller || {}).saglik || {};
    kontrol('TURU 89: saglik modulu HIZMETLER',
      saglikM.ad === 'Hizmetler' && saglikM.tur === 'hizmet',
      'ad=' + saglikM.ad + ' tur=' + saglikM.tur);
    // ⚠️ Otel modulunun ALANLARI sunucudan gelmeli (istemci form uretir).
    const alanlar = (otelM.alanlar || []).map((a) => a.anahtar);
    kontrol('TURU 89: otel modulu ALAN TANIMI tasiyor (kapasite/yatak)',
      alanlar.includes('kapasite') && alanlar.includes('yatak'),
      'alanlar=' + alanlar.join(','));

    // --- Isletme ac (otel) ve Detay yanitinda modul gelsin
    await j('/users/me/isletme', {
      yontem: 'PUT', token: O.token,
      govde: { kategori: 'otel', adres: 'Sahil yolu', il: 'Kocaeli',
               ilce: 'Gebze', enlem: 40.7900, boylam: 29.4300 },
    });
    const det = await j('/users/' + O.id + '/isletme', { token: O.token });
    const dm = (det.d || {}).modul || {};
    kontrol('TURU 89: Detay yaniti MODUL iceriyor (istemci sozlesmesi)',
      dm.ad === 'Odalar' && dm.tur === 'oda',
      'modul=' + JSON.stringify(dm.ad || null));

    // --- Oda ekle: tur + ozellikler ZINCIRI (istek -> sutun -> liste)
    const oda = await j('/isletme/urunler', {
      yontem: 'POST', token: O.token,
      govde: { ad: 'Deniz manzarali suit', aciklama: 'Balkonlu',
               bolum: 'Suit', fiyat_kurus: 450000, tur: 'oda',
               ozellikler: { kapasite: '2', yatak: 'Çift kişilik',
                             kahvalti: 'Dahil' } },
    });
    kontrol('TURU 89: oda eklenebiliyor', oda.kod === 201, 'HTTP ' + oda.kod);

    const kat = await j('/users/' + O.id + '/urunler', { token: O.token });
    const ilk = (((kat.d || {}).urunler) || [])[0] || {};
    kontrol('TURU 89: listede `tur` DONUYOR (SELECT+Scan+yanit zinciri)',
      ilk.tur === 'oda', 'tur=' + ilk.tur);
    kontrol('TURU 89: listede `ozellikler` DONUYOR ve DEGERLERI KORUYOR',
      ilk.ozellikler && ilk.ozellikler.kapasite === '2' &&
      ilk.ozellikler.yatak === 'Çift kişilik',
      'ozellikler=' + JSON.stringify(ilk.ozellikler || null));

    // ⚠️ GECERSIZ tur BEYAZ LISTEDEN GECMELI (DB CHECK yok, Go suzer).
    const kotu = await j('/isletme/urunler', {
      yontem: 'POST', token: O.token,
      govde: { ad: 'Bilinmeyen tur', fiyat_kurus: 100, tur: 'zirva' },
    });
    const kat2 = await j('/users/' + O.id + '/urunler', { token: O.token });
    const zirva = (((kat2.d || {}).urunler) || []).find((x) => x.ad === 'Bilinmeyen tur');
    kontrol('TURU 89: gecersiz tur `urun`a DUSUYOR (500 DEGIL)',
      kotu.kod === 201 && zirva && zirva.tur === 'urun',
      'HTTP ' + kotu.kod + ' tur=' + (zirva ? zirva.tur : '-'));

    // ⚠️ GUNCELLEMEDE `ozellikler` GONDERILMEZSE MEVCUT KORUNMALI
    //    (COALESCE + isaretci sozlesmesi; turu 85b koordinat dersi).
    await j('/isletme/urunler/' + ilk.id, {
      yontem: 'PATCH', token: O.token, govde: { ad: 'Suit (yenilendi)' },
    });
    const kat3 = await j('/users/' + O.id + '/urunler', { token: O.token });
    const g = (((kat3.d || {}).urunler) || []).find((x) => x.id === ilk.id) || {};
    kontrol('TURU 89: ozellikler GONDERILMEYINCE KORUNUYOR',
      g.ozellikler && g.ozellikler.kapasite === '2' && g.tur === 'oda',
      'tur=' + g.tur + ' kapasite=' + ((g.ozellikler || {}).kapasite));

    // ⚠️ Bilinmeyen kategori VARSAYILAN module dusmeli (yeni kategori
    //    eklemek modul.go degistirmeyi ZORUNLU kilmasin).
    const vars_ = (mods.d || {}).varsayilan || {};
    kontrol('TURU 89: varsayilan modul TANIMLI',
      vars_.tur === 'urun' && !!vars_.ad, 'ad=' + vars_.ad);
  }

  // ============= TURU 90: IS ILANI BASVURUSU + GONDERIDE KONUM =========
  {
    const I = await kullaniciAc('E2E Isveren');
    const B = await kullaniciAc('E2E Basvuran');

    // --- IS ILANI turu sunucudan geliyor mu
    const agac = await j('/ilan-kategoriler', { token: I.token });
    const turler = ((agac.d && agac.d.turler) || []).map((t) => t.anahtar);
    kontrol('TURU 90: `is` ilan turu TANIMLI', turler.includes('is'),
      'turler=' + turler.join(','));

    // --- Is ilani olustur (ISLETME HESABI GEREKMEZ)
    const ilan = await j('/ilanlar', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'is', kategori: 'garson', baslik: 'E2E Garson araniyor',
               aciklama: 'Deneme', fiyat_kurus: 3000000,
               il: 'Kocaeli', ilce: 'Gebze',
               ozellikler: { pozisyon: 'Garson', calisma_sekli: 'Tam zamanlı' } },
    });
    kontrol('TURU 90: is ilani NORMAL kullanici tarafindan acilabiliyor',
      ilan.kod === 201, 'HTTP ' + ilan.kod);
    const ilanID = (ilan.d || {}).id;

    // ⚠️⚠️ TURU 114 — ILAN LISTESI **SAHIBININ HESAP TURUNU** DONDURMELI.
    //
    //	Kart uzerindeki "İşletme" rozeti bu alandan cizilir. Sunucu
    //	dondurmezse rozet SESSIZCE kaybolur: istemci patlamaz, log dusmez,
    //	`flutter analyze` temiz gecer — kullanici yalnizca "kim satiyor
    //	yazmiyor" der. Turu 78'de `Profile()` kapak/onayli alanlarini yanit
    //	haritasina koymayi atlamis ve hata TAM BOYLE gorunmustu.
    // ⚠️ `sutun_test.go` SELECT/Scan/yanit UCLUSUNU olcer ama ucu birden
    //    silinirse yesil kalir; bu kontrol UCTAN UCA bakar.
    const ilanListe = await j('/ilanlar?tur=is', { token: B.token });
    const ilanlar = ((ilanListe.d || {}).ilanlar) || [];
    const bizim = ilanlar.find((x) => x.id === ilanID);
    kontrol('TURU 114: ilan listesi sahibi_hesap_turu ve sahibi_onayli donduruyor',
      !!bizim && typeof bizim.sahibi_hesap_turu === 'string' &&
        bizim.sahibi_hesap_turu !== '' &&
        typeof bizim.sahibi_onayli === 'boolean',
      'tur=' + (bizim || {}).sahibi_hesap_turu +
      ' onayli=' + (bizim || {}).sahibi_onayli);

    // --- Basvuru
    const bas = await j('/ilanlar/' + ilanID + '/basvuru', {
      yontem: 'POST', token: B.token, govde: { not: 'Ilgileniyorum' },
    });
    kontrol('TURU 90: is ilanina basvurulabiliyor', bas.kod === 200,
      'HTTP ' + bas.kod);

    // ⚠️ TEKRAR BASVURU HATA DEGIL (ON CONFLICT DO NOTHING).
    const bas2 = await j('/ilanlar/' + ilanID + '/basvuru', {
      yontem: 'POST', token: B.token, govde: { not: 'Tekrar' },
    });
    kontrol('TURU 90: tekrar basvuru HATA DEGIL (200)', bas2.kod === 200,
      'HTTP ' + bas2.kod);

    // ⚠️ KENDI ilanina basvuru 400.
    const kendi = await j('/ilanlar/' + ilanID + '/basvuru', {
      yontem: 'POST', token: I.token, govde: {} });
    kontrol('TURU 90: kendi ilanina basvuru REDDEDILIYOR', kendi.kod === 400,
      'HTTP ' + kendi.kod);

    // --- Sahibi basvurulari GORUR
    const liste = await j('/ilanlar/' + ilanID + '/basvurular', { token: I.token });
    const adaylar = ((liste.d && liste.d.basvurular) || []);
    kontrol('TURU 90: ilan sahibi basvurulari GORUYOR',
      liste.kod === 200 && adaylar.length === 1 && adaylar[0].user_id === B.id,
      'HTTP ' + liste.kod + ' adet=' + adaylar.length);

    // ⚠️ BASKASI 404 (403 DEGIL — 403 basvuru VARLIGINI sizdirirdi).
    const yabanci = await j('/ilanlar/' + ilanID + '/basvurular', { token: B.token });
    const yList = ((yabanci.d && yabanci.d.basvurular) || []);
    kontrol('TURU 90: baskasi basvurulari GOREMIYOR', yList.length === 0,
      'adet=' + yList.length);

    // --- Durum degistirme (yalniz sahibi)
    const dur = await j('/ilanlar/' + ilanID + '/basvurular/' + adaylar[0].id, {
      yontem: 'PATCH', token: I.token, govde: { durum: 'olumlu' } });
    kontrol('TURU 90: sahibi basvuru durumunu degistirebiliyor', dur.kod === 200,
      'HTTP ' + dur.kod);

    // --- Basvuran KENDI basvurularini gorur
    const benim = await j('/users/me/basvurular', { token: B.token });
    const bList = ((benim.d && benim.d.basvurular) || []);
    kontrol('TURU 90: kullanici KENDI basvurularini goruyor',
      bList.length === 1 && bList[0].durum === 'olumlu',
      'adet=' + bList.length + ' durum=' + (bList[0] || {}).durum);

    // ⚠️ IS OLMAYAN ilana basvuru 400.
    const arac = await j('/ilanlar', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'vasita', kategori: 'otomobil', baslik: 'E2E Araba' } });
    const yanlis = await j('/ilanlar/' + arac.d.id + '/basvuru', {
      yontem: 'POST', token: B.token, govde: {} });
    kontrol('TURU 90: is OLMAYAN ilana basvuru REDDEDILIYOR',
      yanlis.kod === 400, 'HTTP ' + yanlis.kod);

    // ============= GONDERIDE KONUM =============
    const gk = await j('/posts', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'yazi', metin: 'E2E konumlu gonderi',
               konum: 'Gebze, Kocaeli', enlem: 40.8028, boylam: 29.4307 },
    });
    kontrol('TURU 90: konumlu gonderi olusturulabiliyor', gk.kod === 201,
      'HTTP ' + gk.kod);

    const det = await j('/posts/' + gk.d.id, { token: I.token });
    const d = det.d || {};
    kontrol('TURU 90: gonderi KONUM alanlarini DONDURUYOR (7 sorgu zinciri)',
      d.konum === 'Gebze, Kocaeli' && Math.abs((d.enlem || 0) - 40.8028) < 0.0001,
      'konum=' + d.konum + ' enlem=' + d.enlem);

    // ⚠️ KONUMSUZ gonderi 0,0 + bos ad donmeli (sozlesme: 0,0 = YOK).
    const gk2 = await j('/posts', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'yazi', metin: 'E2E konumsuz' } });
    const det2 = await j('/posts/' + gk2.d.id, { token: I.token });
    kontrol('TURU 90: konumsuz gonderi 0,0 donuyor',
      (det2.d || {}).enlem === 0 && (det2.d || {}).konum === '',
      'enlem=' + (det2.d || {}).enlem + ' konum=' + JSON.stringify((det2.d || {}).konum));

    // ⚠️ AKISTA da konum gelmeli (sabit YEDI sorguya eklendi).
    // ⚠️ YANIT ANAHTARI `posts` — `gonderiler` DEGIL. Ilk yazimda `gonderiler`
    //    yazmistim; kontrol KIRMIZI dustu ve BOS NESNEYI olcuyordu. Yani yanlis
    //    anahtar bir kontrolu SESSIZ YESILE degil, GURULTULU KIRMIZIYA cevirdi —
    //    ama tersi de olabilirdi. ⚠️ Yeni kontrol yazarken YANIT ANAHTARINI
    //    handler kaynagindan DOGRULA (turu 85b'nin `user_id` drift dersi).
    // ⚠️ UC `/feed` — `/posts/feed` DEGIL (main.go:330 civari; dosyanin
    //    geri kalani da `/feed` kullaniyor).
    const akis = await j('/feed', { token: I.token });
    const akisListe = ((akis.d && akis.d.posts) || []);
    const akisG = akisListe.find((x) => x.id === gk.d.id) || {};
    kontrol('TURU 90: AKIS sorgusu da konum donduruyor',
      akisListe.length > 0 && akisG.konum === 'Gebze, Kocaeli',
      'adet=' + akisListe.length + ' konum=' + JSON.stringify(akisG.konum));

    // ═══════ TURU 90b — DENETIMIN BULDUGU KOR NOKTALAR ═══════

    // ⚠️⚠️ GERI CEKME -> YENIDEN BASVURU. Ilk yazimda `DO NOTHING` vardi ve
    //    geri ceken kullaniciyi o ise KALICI KILITLIYORDU: uc 200 doner ama
    //    satir DEGISMEZ, ilan sahibi basvuruyu HIC GORMEZ. E2E bunu HIC
    //    SINAMIYORDU — bu yuzden yesilden KACTI.
    await j('/ilanlar/' + ilanID + '/basvuru', {
      yontem: 'DELETE', token: B.token });
    const cekildi = await j('/ilanlar/' + ilanID + '/basvurular', { token: I.token });
    kontrol('TURU 90b: geri cekilen basvuru sahibin listesinden CIKIYOR',
      (((cekildi.d || {}).basvurular) || []).length === 0,
      'adet=' + (((cekildi.d || {}).basvurular) || []).length);

    const tekrar = await j('/ilanlar/' + ilanID + '/basvuru', {
      yontem: 'POST', token: B.token, govde: { not: 'Yeniden basvuruyorum' } });
    const geriGeldi = await j('/ilanlar/' + ilanID + '/basvurular', { token: I.token });
    const gg = (((geriGeldi.d || {}).basvurular) || []);
    kontrol('TURU 90b: GERI CEKEN kullanici YENIDEN BASVURABILIYOR',
      tekrar.kod === 200 && gg.length === 1 && gg[0].durum === 'bekliyor' &&
      gg[0].not === 'Yeniden basvuruyorum',
      'HTTP ' + tekrar.kod + ' adet=' + gg.length +
      ' durum=' + (gg[0] || {}).durum + ' not=' + JSON.stringify((gg[0] || {}).not));

    // ⚠️ SAHIBI geri cekilmis basvuruyu DIRILTEMEZ (rizanin geri alinmasi
    //    karsi tarafca iptal edilemez).
    await j('/ilanlar/' + ilanID + '/basvuru', { yontem: 'DELETE', token: B.token });
    const diriltme = await j('/ilanlar/' + ilanID + '/basvurular/' + gg[0].id, {
      yontem: 'PATCH', token: I.token, govde: { durum: 'olumlu' } });
    const sonrasi = await j('/users/me/basvurular', { token: B.token });
    const sb = (((sonrasi.d || {}).basvurular) || [])[0] || {};
    kontrol('TURU 90b: sahibi GERI CEKILMIS basvuruyu DIRILTEMIYOR',
      diriltme.kod === 404 && sb.durum === 'geri_cekildi',
      'HTTP ' + diriltme.kod + ' durum=' + sb.durum);

    // ⚠️ CAPRAZ-ILAN YETKI ASIMI: baska bir ilanin basvuru id'si ile PATCH.
    const ilan2 = await j('/ilanlar', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'is', kategori: 'garson', baslik: 'E2E ikinci is' } });
    const capraz = await j('/ilanlar/' + ilan2.d.id + '/basvurular/' + gg[0].id, {
      yontem: 'PATCH', token: I.token, govde: { durum: 'olumlu' } });
    kontrol('TURU 90b: CAPRAZ-ILAN basvuru guncellemesi REDDEDILIYOR',
      capraz.kod === 404, 'HTTP ' + capraz.kod);

    // ⚠️ KALDIRILMIS ilana basvuru 404 (400 DEGIL — 400 ilanin VAR OLDUGUNU
    //    ve KALDIRILDIGINI dogrulardi).
    await j('/ilanlar/' + ilan2.d.id, {
      yontem: 'PATCH', token: I.token, govde: { durum: 'kaldirildi' } });
    const kapali = await j('/ilanlar/' + ilan2.d.id + '/basvuru', {
      yontem: 'POST', token: B.token, govde: {} });
    kontrol('TURU 90b: KALDIRILMIS ilana basvuru 404 (varlik SIZDIRMAZ)',
      kapali.kod === 404, 'HTTP ' + kapali.kod);

    // ═══════ KOORDINAT DOGRULAMASI (Create VE Update) ═══════

    // ⚠️ YARIM KOORDINAT: istemci olcutu `enlem != 0 || boylam != 0` oldugu
    //    icin gonderi "konumlu" sayilir ve cipe dokunanin haritasi ANLAMSIZ
    //    bir noktada acilirdi.
    const yarim = await j('/posts', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'yazi', metin: 'yarim koordinat', enlem: 41.0 } });
    kontrol('TURU 90b: YARIM koordinat REDDEDILIYOR (Create)',
      yarim.kod === 400, 'HTTP ' + yarim.kod);

    const arali = await j('/posts', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'yazi', metin: 'aralik disi', enlem: -999, boylam: 29.4 } });
    kontrol('TURU 90b: ARALIK DISI koordinat REDDEDILIYOR (Create)',
      arali.kod === 400, 'HTTP ' + arali.kod);

    // ⚠️ ONDALIK KIRPMA: `COALESCE($8, 0)` ciplak tamsayiyla yazilsaydi
    //    Postgres tipi INTEGER'a cozer ve 40.8028 -> 40 olurdu (~90 km).
    const hassas = await j('/posts', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'yazi', metin: 'hassasiyet', konum: 'Gebze',
               enlem: 40.8028, boylam: 29.4307 } });
    const hd = (await j('/posts/' + hassas.d.id, { token: I.token })).d || {};
    kontrol('TURU 90b: koordinat ONDALIGI KORUNUYOR (INTEGER kirpmasi YOK)',
      Math.abs(hd.enlem - 40.8028) < 1e-9 && Math.abs(hd.boylam - 29.4307) < 1e-9,
      'enlem=' + hd.enlem + ' boylam=' + hd.boylam);

    // ⚠️ KONUM DUZENLEMEDEN KALDIRILABILIR (gizlilik): onceden tek care
    //    gonderiyi SILMEKTI.
    await j('/posts/' + hassas.d.id, {
      yontem: 'PATCH', token: I.token,
      govde: { enlem: 0, boylam: 0, konum: '' } });
    const temiz = (await j('/posts/' + hassas.d.id, { token: I.token })).d || {};
    kontrol('TURU 90b: gonderi konumu DUZENLEMEDEN KALDIRILABILIYOR',
      temiz.enlem === 0 && temiz.boylam === 0 && temiz.konum === '',
      'enlem=' + temiz.enlem + ' konum=' + JSON.stringify(temiz.konum));

    // ⚠️ KONUM GONDERILMEYINCE KORUNUR (kismi guncelleme).
    const kal = await j('/posts', {
      yontem: 'POST', token: I.token,
      govde: { tur: 'yazi', metin: 'korunacak', konum: 'Darıca',
               enlem: 40.7669, boylam: 29.3897 } });
    await j('/posts/' + kal.d.id, {
      yontem: 'PATCH', token: I.token, govde: { metin: 'metin degisti' } });
    const kd = (await j('/posts/' + kal.d.id, { token: I.token })).d || {};
    kontrol('TURU 90b: konum GONDERILMEYINCE KORUNUYOR',
      kd.konum === 'Darıca' && Math.abs(kd.enlem - 40.7669) < 1e-9,
      'konum=' + kd.konum + ' enlem=' + kd.enlem);

    // ═══════ ISLETME MODULLERI: YENI KATEGORILER ═══════
    // ⚠️ turu 90 `Kategoriler`e `diyetisyen`+`guzellik` ekledi ama
    //    `moduller`e EKLEMEDI -> ikisi de "Ürünler"e dusuyordu.
    // ⚠️ UC HARITA DONDURUYOR (`{moduller: {kategori: {...}}}`), sorgu
    //    parametresi ALMIYOR — turu 89 kontrolu (satir ~2102) ayni sekilde
    //    okuyor. Ilk yazimda `?kategori=` + `.modul` denendi ve `undefined`
    //    olctu. ⚠️ Yeni kontrol yazarken YANIT SEKLINI mevcut kontrolden ya da
    //    handler kaynagindan DOGRULA.
    const modHarita = await j('/isletme-modulleri', { token: I.token });
    for (const kat of ['diyetisyen', 'guzellik']) {
      const md = ((modHarita.d || {}).moduller || {})[kat] || {};
      kontrol('TURU 90b: `' + kat + '` modulu HIZMETLER (varsayilana DUSMUYOR)',
        md.ad === 'Hizmetler' &&
        (md.alanlar || []).some((a) => a.anahtar === 'sure_dakika'),
        'ad=' + md.ad + ' alanlar=' +
        ((md.alanlar || []).map((a) => a.anahtar).join(',')));
    }
  }

  // ═══════════ TURU 91: TEKLIF AKISI + DIYET ═══════════
  {
    const M = await kullaniciAc('E2E Musteri');       // talep sahibi (kisisel)
    const I1 = await kullaniciAc('E2E Kuafor');       // teklif veren isletme
    const I2 = await kullaniciAc('E2E Fotografci');   // ikinci isletme
    const K = await kullaniciAc('E2E Kisisel');       // teklif VEREMEZ

    // Iki isletmeyi isletme hesabina gecir.
    for (const [h, kat] of [[I1, 'kuafor'], [I2, 'eglence']]) {
      await j('/users/me/isletme', {
        yontem: 'PUT', token: h.token,
        govde: { kategori: kat, adres: 'Gebze', il: 'Kocaeli', ilce: 'Gebze',
                 telefon: '+905550000000',
                 calisma: [1,2,3,4,5,6,7].map((g) => ({
                   gun: g, acilis: '09:00', kapanis: '20:00', kapali: false })) },
      });
    }

    // --- `talep` turu sunucudan geliyor mu
    const agac91 = await j('/ilan-kategoriler', { token: M.token });
    const t91 = ((agac91.d && agac91.d.turler) || []).find((x) => x.anahtar === 'talep');
    kontrol('TURU 91: \`talep\` turu TANIMLI', !!t91,
      'turler=' + ((agac91.d && agac91.d.turler) || []).map((x) => x.anahtar).join(','));
    // ⚠️ ADIM ADIM FORM sunucudan gelmezse sihirbaz TEK ADIMA duser.
    kontrol('TURU 91: talep alanlari ADIM tasiyor (adim adim form)',
      !!t91 && (t91.alanlar || []).some((a) => (a.adim || 0) > 0),
      'adimlar=' + ((t91 && t91.alanlar) || []).map((a) => a.adim || 0).join(','));
    kontrol('TURU 91: dugun kategorileri VAR',
      !!t91 && (t91.kategoriler || []).some((k) => k.anahtar === 'dugun_organizasyon'),
      'adet=' + ((t91 && t91.kategoriler) || []).length);

    // --- Talep olustur
    const talep = await j('/ilanlar', {
      yontem: 'POST', token: M.token,
      govde: { tur: 'talep', kategori: 'sac_makyaj', baslik: 'Düğün saç & makyaj',
               aciklama: 'E2E talep', il: 'Kocaeli', ilce: 'Gebze',
               ozellikler: { tarih: '01.09.2026', kisi_sayisi: '150' } },
    });
    kontrol('TURU 91: talep olusturulabiliyor', talep.kod === 201, 'HTTP ' + talep.kod);
    const talepID = (talep.d || {}).id;

    // ⚠️⚠️ SIZINTI MUHAFIZI: talep GENEL ilan listesini KIRLETMEMELI.
    const genel = await j('/ilanlar', { token: I1.token });
    const genelListe = ((genel.d && genel.d.ilanlar) || []);
    kontrol('TURU 91: talep GENEL ilan listesinde GORUNMUYOR (sizinti muhafizi)',
      !genelListe.some((x) => x.id === talepID),
      'adet=' + genelListe.length);

    const talepListe = await j('/ilanlar?tur=talep', { token: I1.token });
    kontrol('TURU 91: \`?tur=talep\` ile GORUNUYOR',
      ((talepListe.d && talepListe.d.ilanlar) || []).some((x) => x.id === talepID),
      'adet=' + ((talepListe.d && talepListe.d.ilanlar) || []).length);

    // --- Teklif kapilari
    const kisiselTeklif = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: K.token, govde: { not: 'ben', fiyat_kurus: 100000 } });
    kontrol('TURU 91: KISISEL hesap teklif VEREMIYOR (403)',
      kisiselTeklif.kod === 403, 'HTTP ' + kisiselTeklif.kod);

    const fiyatsiz = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: I1.token, govde: { not: 'fiyatsiz' } });
    kontrol('TURU 91: FIYATSIZ teklif REDDEDILIYOR (400)',
      fiyatsiz.kod === 400, 'HTTP ' + fiyatsiz.kod);

    const kendi91 = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: M.token, govde: { not: 'x', fiyat_kurus: 1 } });
    kontrol('TURU 91: KENDI talebine teklif REDDEDILIYOR',
      kendi91.kod === 400, 'HTTP ' + kendi91.kod);

    const tk1 = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: I1.token, govde: { not: 'Uygunuz', fiyat_kurus: 250000 } });
    const tk2 = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: I2.token, govde: { not: 'Biz de', fiyat_kurus: 180000 } });
    kontrol('TURU 91: isletmeler teklif verebiliyor',
      tk1.kod === 200 && tk2.kod === 200, 'HTTP ' + tk1.kod + '/' + tk2.kod);

    // --- Sahibi teklifleri gorur, FIYATA GORE SIRALI
    const teklifler = await j('/ilanlar/' + talepID + '/basvurular', { token: M.token });
    const tl = ((teklifler.d && teklifler.d.basvurular) || []);
    kontrol('TURU 91: teklifler FIYAT alanini DONDURUYOR (yanit haritasi)',
      tl.length === 2 && tl.every((x) => typeof x.fiyat_kurus === 'number'),
      'adet=' + tl.length + ' fiyatlar=' + tl.map((x) => x.fiyat_kurus).join(','));
    kontrol('TURU 91: teklifler UCUZDAN PAHALIYA sirali',
      tl.length === 2 && tl[0].fiyat_kurus === 180000,
      'ilk=' + (tl[0] || {}).fiyat_kurus);
    kontrol('TURU 91: \`guncellendi_at\` yanitta VAR (revize etiketi icin)',
      tl.every((x) => !!x.guncellendi_at), JSON.stringify((tl[0] || {}).guncellendi_at));

    // ⚠️ REVIZE: created_at KORUNUR, guncellendi_at DEGISIR.
    const oncekiOlus = tl[0].created_at;
    await new Promise((r) => setTimeout(r, 1100));
    const revize = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: I2.token, govde: { not: 'indirim', fiyat_kurus: 150000 } });
    const t2 = ((await j('/ilanlar/' + talepID + '/basvurular', { token: M.token })).d || {}).basvurular || [];
    const revizeli = t2.find((x) => x.user_id === I2.id) || {};
    kontrol('TURU 91: teklif REVIZE edilebiliyor, created_at KORUNUYOR',
      revize.kod === 200 && revizeli.fiyat_kurus === 150000 &&
      revizeli.created_at === oncekiOlus,
      'HTTP ' + revize.kod + ' fiyat=' + revizeli.fiyat_kurus +
      ' created_at ayni=' + (revizeli.created_at === oncekiOlus));

    // ⚠️ BASKASI teklifleri GOREMEZ.
    const yabanci91 = await j('/ilanlar/' + talepID + '/basvurular', { token: I1.token });
    kontrol('TURU 91: baskasi teklif listesini GOREMIYOR',
      (((yabanci91.d || {}).basvurular) || []).length === 0,
      'adet=' + (((yabanci91.d || {}).basvurular) || []).length);

    // --- SECIM: tek islemde uc yan etki
    const kazananID = revizeli.id;
    const sec = await j('/ilanlar/' + talepID + '/basvurular/' + kazananID, {
      yontem: 'PATCH', token: M.token, govde: { durum: 'secildi' } });
    const sonrasi91 = ((await j('/ilanlar/' + talepID + '/basvurular', { token: M.token })).d || {}).basvurular || [];
    const detay91 = (await j('/ilanlar/' + talepID, { token: M.token })).d || {};
    kontrol('TURU 91: teklif SECILDI + digerleri ELENDI + talep KAPANDI',
      sec.kod === 200 &&
      sonrasi91.find((x) => x.id === kazananID).durum === 'secildi' &&
      sonrasi91.filter((x) => x.id !== kazananID).every((x) => x.durum === 'elendi') &&
      detay91.durum === 'satildi',
      'HTTP ' + sec.kod + ' talepDurum=' + detay91.durum +
      ' durumlar=' + sonrasi91.map((x) => x.durum).join(','));

    // ⚠️ KAPANMIS talebe yeni teklif 404.
    const kapali91 = await j('/ilanlar/' + talepID + '/basvuru', {
      yontem: 'POST', token: I1.token, govde: { not: 'gec', fiyat_kurus: 90000 } });
    kontrol('TURU 91: KAPANMIS talebe teklif 404', kapali91.kod === 404,
      'HTTP ' + kapali91.kod);

    // --- Tekliflerim (tur suzgeci)
    const benimTeklif = await j('/users/me/basvurular?tur=talep', { token: I2.token });
    const bt = (((benimTeklif.d || {}).basvurular) || []);
    kontrol('TURU 91: "Tekliflerim" tur suzgeciyle calisiyor + fiyat tasiyor',
      bt.length === 1 && bt[0].fiyat_kurus === 150000 && bt[0].durum === 'secildi',
      'adet=' + bt.length + ' fiyat=' + (bt[0] || {}).fiyat_kurus);

    // ═══════════ DIYET ═══════════
    const DN = await kullaniciAc('E2E Danisan');
    const DY = await kullaniciAc('E2E Diyetisyen');
    const DY2 = await kullaniciAc('E2E Diyetisyen2');
    for (const h of [DY, DY2]) {
      await j('/users/me/isletme', {
        yontem: 'PUT', token: h.token,
        govde: { kategori: 'diyetisyen', adres: 'Gebze', il: 'Kocaeli',
                 ilce: 'Gebze', telefon: '+905550000001',
                 calisma: [1,2,3,4,5,6,7].map((g) => ({
                   gun: g, acilis: '09:00', kapanis: '20:00', kapali: false })) },
      });
    }

    // ⚠️ Diyetisyen OLMAYAN birine bag istegi 400.
    const yanlisBag = await j('/diyet/bag', {
      yontem: 'POST', token: DN.token, govde: { diyetisyen_id: M.id } });
    kontrol('TURU 91: diyetisyen OLMAYANA bag istegi REDDEDILIYOR',
      yanlisBag.kod === 400, 'HTTP ' + yanlisBag.kod);

    const bag = await j('/diyet/bag', {
      yontem: 'POST', token: DN.token, govde: { diyetisyen_id: DY.id } });
    kontrol('TURU 91: bag istegi olusturuluyor',
      bag.kod === 200 && (bag.d || {}).durum === 'bekliyor',
      'HTTP ' + bag.kod + ' durum=' + (bag.d || {}).durum);
    const bagID = (bag.d || {}).id;

    // ⚠️⚠️ RIZA KAPISI: KENDI istegini KENDISI onaylayamaz.
    const kendiOnay = await j('/diyet/bag/' + bagID, {
      yontem: 'PATCH', token: DN.token, govde: { durum: 'aktif' } });
    kontrol('TURU 91: KENDI bag istegini KENDISI onaylayamiyor (riza kapisi)',
      kendiOnay.kod === 404, 'HTTP ' + kendiOnay.kod);

    // ⚠️ BAG YOKKEN diyetisyen kayitlari GOREMEZ.
    const bagsizOku = await j('/diyet/kayitlar?user_id=' + DN.id, { token: DY.token });
    kontrol('TURU 91: BAG YOKKEN saglik verisi GORUNMUYOR (404)',
      bagsizOku.kod === 404, 'HTTP ' + bagsizOku.kod);

    const onay = await j('/diyet/bag/' + bagID, {
      yontem: 'PATCH', token: DY.token, govde: { durum: 'aktif' } });
    kontrol('TURU 91: KARSI TARAF bagi onaylayabiliyor', onay.kod === 200,
      'HTTP ' + onay.kod);

    // --- Danisan kendi ogununu ekler
    const bugun91 = new Date().toISOString().slice(0, 10);
    const ogun = await j('/diyet/kayit', {
      yontem: 'POST', token: DN.token,
      govde: { tur: 'ogun', tarih: bugun91, ad: 'Yulaf', kalori: 320,
               veri: { ogun: 'kahvalti', gram: 80 } } });
    kontrol('TURU 91: ogun kaydi eklenebiliyor', ogun.kod === 201,
      'HTTP ' + ogun.kod);

    // ⚠️⚠️ `user_id` GOVDEDE GELSE BILE YOK SAYILIR (kendine yazilir).
    const baskasina = await j('/diyet/kayit', {
      yontem: 'POST', token: DN.token,
      govde: { tur: 'ogun', tarih: bugun91, ad: 'Sahte', kalori: 5000,
               user_id: DY.id } });
    const dyKayit = await j('/diyet/kayitlar?tur=ogun', { token: DY.token });
    kontrol('TURU 91: baskasinin gunune ogun YAZILAMIYOR (user_id yok sayilir)',
      baskasina.kod === 201 &&
      !(((dyKayit.d || {}).kayitlar) || []).some((k) => k.ad === 'Sahte'),
      'HTTP ' + baskasina.kod);

    // --- Bagli diyetisyen okuyabiliyor
    const dyOku = await j('/diyet/kayitlar?user_id=' + DN.id, { token: DY.token });
    kontrol('TURU 91: BAGLI diyetisyen danisanin kayitlarini GORUYOR',
      dyOku.kod === 200 && (((dyOku.d || {}).kayitlar) || []).length >= 1,
      'HTTP ' + dyOku.kod);

    // ⚠️ BASKA diyetisyen GOREMEZ.
    const dy2Oku = await j('/diyet/kayitlar?user_id=' + DN.id, { token: DY2.token });
    kontrol('TURU 91: BASKA diyetisyen GOREMIYOR (404)', dy2Oku.kod === 404,
      'HTTP ' + dy2Oku.kod);

    // --- Liste yazma: yalniz BAGLI diyetisyen
    const liste = await j('/diyet/kayit', {
      yontem: 'POST', token: DY.token,
      govde: { tur: 'liste', tarih: bugun91, ad: 'Haftalik plan',
               user_id: DN.id, veri: { metin: 'Pazartesi: ...' } } });
    kontrol('TURU 91: BAGLI diyetisyen danisana LISTE yazabiliyor',
      liste.kod === 201, 'HTTP ' + liste.kod);

    const yanlisListe = await j('/diyet/kayit', {
      yontem: 'POST', token: DY2.token,
      govde: { tur: 'liste', tarih: bugun91, ad: 'Izinsiz', user_id: DN.id } });
    kontrol('TURU 91: BAGLI OLMAYAN diyetisyen liste YAZAMIYOR (403)',
      yanlisListe.kod === 403, 'HTTP ' + yanlisListe.kod);

    // --- Ozet: gun `tarih` sutunundan gruplanir
    const ozet = await j('/diyet/ozet', { token: DN.token });
    const gunler = (((ozet.d || {}).gunler) || []);
    kontrol('TURU 91: gunluk ozet \`tarih\` sutunundan gruplaniyor',
      gunler.some((g) => g.tarih === bugun91 && g.kalori >= 320),
      'gunler=' + JSON.stringify(gunler.slice(0, 3)));

    // --- Besin listesi (Turkce arama)
    const besin = await j('/diyet/besinler?q=yulaf', { token: DN.token });
    kontrol('TURU 91: besin aramasi calisiyor (Turkce)',
      (((besin.d || {}).besinler) || []).some((b) => /Yulaf/i.test(b.ad)),
      'adet=' + (((besin.d || {}).besinler) || []).length);

    // ⚠️ SILME YOK: kaldirilan kayit listede GORUNMEZ ama satir DURUR.
    await j('/diyet/kayit/' + ogun.d.id, {
      yontem: 'PATCH', token: DN.token, govde: { durum: 'kaldirildi' } });
    const kalan = await j('/diyet/kayitlar?tur=ogun', { token: DN.token });
    kontrol('TURU 91: kaldirilan kayit listede GORUNMUYOR (satir SILINMEZ)',
      !((((kalan.d || {}).kayitlar) || []).some((k) => k.id === ogun.d.id)),
      'adet=' + (((kalan.d || {}).kayitlar) || []).length);

    // ⚠️ BAG SONLANINCA erisim BITER.
    await j('/diyet/bag/' + bagID, {
      yontem: 'PATCH', token: DN.token, govde: { durum: 'sonlandi' } });
    const sonra = await j('/diyet/kayitlar?user_id=' + DN.id, { token: DY.token });
    kontrol('TURU 91: BAG SONLANINCA diyetisyen erisimi BITIYOR (404)',
      sonra.kod === 404, 'HTTP ' + sonra.kod);

    // --- /users/me isletme_kategori (profil menusu buna bagli)
    const ben91 = await j('/users/me', { token: DY.token });
    kontrol('TURU 91: /users/me \`isletme_kategori\` donduruyor (profil girisi)',
      (ben91.d || {}).isletme_kategori === 'diyetisyen',
      'kategori=' + JSON.stringify((ben91.d || {}).isletme_kategori));

    // --- AI kalori: kapaliysa 503, acikSA metin kotasindan duser
    const aiDurum = await j('/ai/durum', { token: DN.token });
    if ((aiDurum.d || {}).acik) {
      // ⚠️ UC `/ai/durum` — `/ai/kota` YOKTUR. Ilk yazimda yanlis uc
      //    cagrilmis ve kontrol `undefined === undefined` ile YALANCI
      //    YESIL vermisti: HICBIR SEY OLCMUYORDU. Turu 89 dersi ("bir
      //    muhafizin yesil olmasi GERCEKTEN OLCTUGU anlamina gelmez").
      const once = await j('/ai/durum', { token: DN.token });
      const kal = await j('/ai/kalori', {
        yontem: 'POST', token: DN.token, govde: { metin: 'bir elma' } });
      const sonraK = await j('/ai/durum', { token: DN.token });
      // ⚠️ UC KOSUL BIRDEN: (a) cagri basarili, (b) METIN kotasi DUSTU,
      //    (c) GORSEL kotasi DEGISMEDI. Yalniz (c) bakilsaydi, kota
      //    okunamadiginda da (undefined===undefined) YESIL olurdu.
      kontrol('TURU 91: /ai/kalori METIN kotasindan duser, GORSEL kotasi DEGISMEZ',
        kal.kod === 200 &&
        typeof (once.d || {}).kalan === 'number' &&
        (sonraK.d || {}).kalan === (once.d || {}).kalan - 1 &&
        (sonraK.d || {}).gorsel_kalan === (once.d || {}).gorsel_kalan,
        'metin ' + (once.d || {}).kalan + '->' + (sonraK.d || {}).kalan +
        ' | gorsel ' + (once.d || {}).gorsel_kalan + '->' + (sonraK.d || {}).gorsel_kalan);
    } else {
      const kal = await j('/ai/kalori', {
        yontem: 'POST', token: DN.token, govde: { metin: 'elma' } });
      kontrol('TURU 91: AI kapaliyken /ai/kalori 503', kal.kod === 503,
        'HTTP ' + kal.kod);
    }
  }


  // ═══════════ TURU 92: KATEGORI KESIF (alt kategoriler + slider) ═══════
  {
    const Z = await kullaniciAc('E2E Kesif');
    const y = await j('/isletme-kesif?kategori=yemek', { token: Z.token });
    const alt = ((y.d || {}).alt_kategoriler) || [];
    const sl = ((y.d || {}).slaytlar) || [];
    kontrol('TURU 92: yemek ALT KATEGORILERI donuyor (doner/kebap)',
      y.kod === 200 && alt.some((a) => a.ad === 'Döner') &&
      alt.every((a) => a.ara && a.ara.length > 0),
      'adet=' + alt.length + ' ilk=' + JSON.stringify((alt[0] || {}).ad));
    kontrol('TURU 92: slider 3-4 slayt + baslik/alt metin donuyor',
      sl.length >= 3 && sl.length <= 4 &&
      sl.every((x) => x.baslik && x.alt),
      'adet=' + sl.length + ' ilk=' + JSON.stringify((sl[0] || {}).baslik));

    // ⚠️ HER KATEGORI FARKLI (kullanici emri): yemek ile kuafor AYNI
    //    listeyi dondurmemeli.
    // ⚠️ Varsayilan slaytlar: "her kategori farkli" kontrolunun TABANI.
    const bos0 = await j('/isletme-kesif?kategori=yokboyle',
      { token: Z.token });
    const k = await j('/isletme-kesif?kategori=kuafor', { token: Z.token });
    const kAlt = ((k.d || {}).alt_kategoriler) || [];
    kontrol('TURU 92: HER KATEGORI FARKLI (yemek != kuafor)',
      kAlt.length > 0 &&
      JSON.stringify(kAlt.map((a) => a.ad)) !==
        JSON.stringify(alt.map((a) => a.ad)),
      'kuafor=' + kAlt.map((a) => a.ad).join(','));

    // ⚠️ Alt kategori ARAMAYA cevriliyor: `q` ile suzgec CALISMALI
    //    (kart bir arama kisayolu; calismazsa 'dugme var ama etkisiz').
    const arama = await j('/isletmeler?kategori=yemek&q=döner', { token: Z.token });
    kontrol('TURU 92: alt kategori aramasi UC TARAFINDAN kabul ediliyor',
      arama.kod === 200, 'HTTP ' + arama.kod);

    // ═══════ TURU 93b: KART GERCEKTEN SONUC DONDURUYOR MU ═══════
    //
    // ⚠️⚠️⚠️ DENETIMIN BULDUGU SEVK ENGELI TAM BURADAYDI: turu 92 kartlari
    //	arama kisayoludur ("Saç Kesim" -> `q=saç`) ama sunucudaki yuklem
    //	YALNIZ `u.name`/`u.username`e bakiyordu. Eslesmesi gereken metin
    //	(`Saç kesimi`) URUN KATALOGUNDA; isletme adi "Kuaför Serkan" ve
    //	icinde "saç" GECMEZ. Tohum verisiyle sayildi: veri bulunan bes
    //	kategoride **25 kartin 25'i de BOS** donuyordu.
    //
    // ⚠️⚠️ BIRIM TESTI BUNU YAPISAL OLARAK OLCEMEZ: `altkategori_test.go`
    //	yalniz `Ara` alaninin DOLU oldugunu sinar. **Hicbir seyle
    //	eslesmeyen dolu bir `Ara`, kullanici acisindan BOS `Ara` ile
    //	BIREBIR AYNIDIR.** Bu ancak GERCEK VERIYLE, CANLI olculur.
    // ⚠️ YAPMA: bu kontrolu silme; yeni alt kategori eklerken calistir.
    {
      // Urun katalogunda "saç" gecen bir kuafor kur.
      const K = await kullaniciAc('E2E Kuafor');
      await j('/users/me/isletme', {
        yontem: 'PUT', token: K.token,
        govde: {
          kategori: 'kuafor', adres: 'Test', il: 'Kocaeli', ilce: 'Gebze',
          telefon: '02620000001',
          calisma: [1, 2, 3, 4, 5, 6, 7].map((g) => ({
            gun: g, acilis: '09:00', kapanis: '20:00', kapali: false,
          })),
        },
      });
      // ⚠️ Isletme ADINDA "saç" GECMIYOR ("E2E Kuafor") — eslesme YALNIZ
      //    urun katalogundan gelebilir. Kontrolun degeri tam burada.
      const ur = await j('/isletme/urunler', {
        yontem: 'POST', token: K.token,
        govde: { ad: 'Saç kesimi', bolum: 'Saç', fiyat_kurus: 35000,
                 tur: 'hizmet' },
      });

      const kart = await j('/isletmeler?kategori=kuafor&q=' +
        encodeURIComponent('saç'), { token: Z.token });
      const bulundu = (((kart.d || {}).isletmeler) || [])
        .some((x) => x.id === K.id);
      kontrol('TURU 93b: ALT KATEGORI KARTI GERCEKTEN SONUC DONDURUYOR ' +
        '(eslesme URUN KATALOGUNDAN)',
        ur.kod < 300 && kart.kod === 200 && bulundu,
        'urun HTTP ' + ur.kod + ' | liste HTTP ' + kart.kod +
        ' | adet=' + (((kart.d || {}).isletmeler) || []).length);

      // ⚠️ COK KELIMELI ARAMA (kart + yazi birlikte): eskiden tek bitisik
      //    alt dize araniyordu (`ILIKE '%saç kuafor%'`) ve "E2E Kuafor"
      //    ESLESMIYORDU -> liste KALICI BOS kaliyordu.
      const cift = await j('/isletmeler?kategori=kuafor&q=' +
        encodeURIComponent('saç kuafor'), { token: Z.token });
      kontrol('TURU 93b: KART + YAZI birlikte calisiyor (kelime kelime AND)',
        cift.kod === 200 &&
        (((cift.d || {}).isletmeler) || []).some((x) => x.id === K.id),
        'adet=' + (((cift.d || {}).isletmeler) || []).length);

      // ⚠️ AND semantigi GERCEKTEN AND mi: eslesmeyen bir kelime eklenince
      //    sonuc DUSMELI (aksi halde yuklem OR gibi davraniyor demektir).
      const olmayan = await j('/isletmeler?kategori=kuafor&q=' +
        encodeURIComponent('saç zurafa'), { token: Z.token });
      kontrol('TURU 93b: eslesmeyen kelime sonucu ELER (OR degil AND)',
        olmayan.kod === 200 &&
        !(((olmayan.d || {}).isletmeler) || []).some((x) => x.id === K.id),
        'adet=' + (((olmayan.d || {}).isletmeler) || []).length);
    }

    // ⚠️ TURU 93b — HER KATEGORININ **KENDI SLIDER METNI** OLMALI
    //    (kullanici emri: *"butun kategoriler AYRI olmali"*). Varsayilana
    //    dusen kategori, baska kategorilerle BIREBIR AYNI ekrani gosterir.
    {
      const katL = await j('/isletme-kategorileri', { token: Z.token });
      const anahtarlar = Object.keys(
        ((katL.d || {}).kategoriler) || {});
      const varsayilan = JSON.stringify(
        ((bos0.d || {}).slaytlar) || []);
      const ayniOlanlar = [];
      for (const a of anahtarlar) {
        if (a === 'diger') continue; // bilincli muaf (sunucu serhinde yazili)
        const r = await j('/isletme-kesif?kategori=' + a, { token: Z.token });
        if (JSON.stringify(((r.d || {}).slaytlar) || []) === varsayilan) {
          ayniOlanlar.push(a);
        }
      }
      kontrol('TURU 93b: HER KATEGORININ KENDI SLIDER METNI VAR',
        ayniOlanlar.length === 0,
        'varsayilana dusen: ' + (ayniOlanlar.join(',') || 'yok'));
    }

    // ⚠️ BILINMEYEN kategori: slider VARSAYILANA duser, serit BOS doner
    //    (350px bos gri kutu OLMAMALI).
    const bos = await j('/isletme-kesif?kategori=yokboyle', { token: Z.token });
    kontrol('TURU 92: bilinmeyen kategoride slider VARSAYILANA dusuyor',
      bos.kod === 200 && (((bos.d || {}).slaytlar) || []).length >= 3 &&
      (((bos.d || {}).alt_kategoriler) || []).length === 0,
      'slayt=' + (((bos.d || {}).slaytlar) || []).length +
      ' alt=' + (((bos.d || {}).alt_kategoriler) || []).length);

    // ⚠️⚠️⚠️ TURU 96h — SUZGECLER **SUNUCUDA** (arayuzdeki filtre paneli).
    //
    //	Turu 96'da suzme ISTEMCIDE yapiliyordu ve sunucu `LIMIT 60`
    //	donduruyordu: "60'in icinden suzulmus" sonuc "hepsinden suzulmus"ten
    //	FARKLI olabiliyordu. Bu kontroller yuklemin GERCEKTEN calistigini
    //	kanitlar — yalnizca "200 dondu" degil, SAYININ DEGISTIGI olculur.
    const hepsi = await j('/isletmeler?kategori=yemek', { token: Z.token });
    const hepsiAdet = (((hepsi.d || {}).isletmeler) || []).length;

    // puan >= 4.5 -> tohumda yalniz bir restoran (4.5); oteki 3.6.
    const puanli = await j('/isletmeler?kategori=yemek&puan=4.5',
      { token: Z.token });
    const puanliListe = ((puanli.d || {}).isletmeler) || [];
    kontrol('TURU 96h: puan suzgeci SUNUCUDA calisiyor',
      puanli.kod === 200 && puanliListe.length > 0 &&
      puanliListe.length < hepsiAdet &&
      puanliListe.every((o) => (o.puan || 0) >= 4.5),
      'hepsi=' + hepsiAdet + ' suzulmus=' + puanliListe.length);

    // ⚠️ PUANI OLMAYAN KAYIT ELENMELI: istemcideki kural buydu, sunucuya
    //    BIREBIR tasindi. Gecirseydi suzgec ETKISIZ gorunurdu.
    const puansizVar = await j('/isletmeler?kategori=doktor&puan=4.5',
      { token: Z.token });
    kontrol('TURU 96h: puani NULL olan kayit suzgecten GECMEZ',
      puansizVar.kod === 200 &&
      (((puansizVar.d || {}).isletmeler) || [])
        .every((o) => o.puan !== null && o.puan !== undefined),
      'adet=' + (((puansizVar.d || {}).isletmeler) || []).length);

    // min tutar: tohumda restoranlarin ikisi de 260 TL -> 150 TL tavani BOS
    const ucuz = await j('/isletmeler?kategori=yemek&min_tutar=15000',
      { token: Z.token });
    kontrol('TURU 96h: min. tutar suzgeci SUNUCUDA calisiyor',
      ucuz.kod === 200 && (((ucuz.d || {}).isletmeler) || []).length === 0,
      'adet=' + (((ucuz.d || {}).isletmeler) || []).length);

    // ⚠️ BOZUK DEGER 400 DEGIL, "suzme yok"a duser: bir yazim hatasi
    //    yuzunden listenin HIC gelmemesindense suzgecsiz gelmesi yeglenir.
    const bozuk = await j('/isletmeler?kategori=yemek&puan=abc&min_tutar=-5',
      { token: Z.token });
    kontrol('TURU 96h: BOZUK suzgec degeri listeyi OLDURMEZ (suzme yok)',
      bozuk.kod === 200 &&
      (((bozuk.d || {}).isletmeler) || []).length === hepsiAdet,
      'adet=' + (((bozuk.d || {}).isletmeler) || []).length);

    // kampanyali
    const kamp = await j('/isletmeler?kategori=yemek&kampanyali=1',
      { token: Z.token });
    kontrol('TURU 96h: kampanyali suzgeci SUNUCUDA calisiyor',
      kamp.kod === 200 &&
      (((kamp.d || {}).isletmeler) || [])
        .every((o) => (o.kampanyalar || []).length > 0),
      'adet=' + (((kamp.d || {}).isletmeler) || []).length);

    // ⚠️ created_at: "Yeni Restourant" kartinin GERCEK olcutu buna baglanacak.
    kontrol('TURU 96h: liste yaniti created_at donduruyor',
      hepsiAdet > 0 && typeof
        (((hepsi.d || {}).isletmeler) || [])[0].created_at === 'string',
      'ornek=' + ((((hepsi.d || {}).isletmeler) || [])[0] || {}).created_at);

    // ── KAYITLI ADRESLER (migration 048) ──
    const bosAdres = await j('/users/me/adresler', { token: Z.token });
    kontrol('TURU 96i: adres yaniti application/json BASLIGI tasiyor',
      jsonMu(bosAdres),
      'tur=' + bosAdres.tur);
    kontrol('TURU 96h: adres listesi BOS baslar',
      bosAdres.kod === 200 &&
      (((bosAdres.d || {}).adresler) || []).length === 0,
      'HTTP ' + bosAdres.kod);

    const ekle1 = await j('/users/me/adresler', {
      yontem: 'POST', token: Z.token,
      govde: { ad: 'Ev', enlem: 40.8028, boylam: 29.4307 },
    });
    const ekle2 = await j('/users/me/adresler', {
      yontem: 'POST', token: Z.token,
      govde: { ad: 'İş', enlem: 40.81, boylam: 29.44 },
    });
    kontrol('TURU 96h: adres eklenebiliyor',
      ekle1.kod === 201 && ekle2.kod === 201,
      'ev=' + ekle1.kod + ' is=' + ekle2.kod);
    kontrol('TURU 96i: adres EKLEME yaniti da application/json',
      jsonMu(ekle1) && jsonMu(ekle2),
      'ev=' + ekle1.tur + ' is=' + ekle2.tur);

    // ⚠️⚠️ AYNI ANDA TEK SECILI ADRES — kisimli tekil indeks bunu VERITABANI
    //    seviyesinde dayatir. Uygulama katmaninda "once hepsini false yap"
    //    iki deyimdir ve arada bir istek girerse IKI SECILI kalirdi.
    const iki = await j('/users/me/adresler', { token: Z.token });
    const ikiListe = ((iki.d || {}).adresler) || [];
    kontrol('TURU 96h: AYNI ANDA TEK adres secili (son eklenen)',
      ikiListe.length === 2 &&
      ikiListe.filter((a) => a.secili).length === 1 &&
      (ikiListe.find((a) => a.secili) || {}).ad === 'İş',
      'secili=' + ikiListe.filter((a) => a.secili).map((a) => a.ad).join(','));

    const evId = (ikiListe.find((a) => a.ad === 'Ev') || {}).id;
    const sec = await j('/users/me/adresler/' + evId + '/sec',
      { yontem: 'POST', token: Z.token });
    const sonra = await j('/users/me/adresler', { token: Z.token });
    const sonraListe = ((sonra.d || {}).adresler) || [];
    kontrol('TURU 96h: adres secimi degistirilebiliyor',
      sec.kod === 204 &&
      sonraListe.filter((a) => a.secili).length === 1 &&
      (sonraListe.find((a) => a.secili) || {}).ad === 'Ev',
      'secili=' + sonraListe.filter((a) => a.secili).map((a) => a.ad).join(','));

    // ⚠️⚠️ YATAY YETKI: BASKASININ adresini secmek/silmek 404 olmali.
    //    Sorgular `user_id` ile bagli; olmasaydi id bilen herkes baskasinin
    //    adresini degistirebilirdi.
    const baskasi = await j('/users/me/adresler/' + evId + '/sec',
      { yontem: 'POST', token: A.token });
    kontrol('TURU 96h: BASKASININ adresi secilemez (yatay yetki)',
      baskasi.kod === 404, 'HTTP ' + baskasi.kod);
    const baskasiSil = await j('/users/me/adresler/' + evId,
      { yontem: 'DELETE', token: A.token });
    kontrol('TURU 96h: BASKASININ adresi silinemez (yatay yetki)',
      baskasiSil.kod === 404, 'HTTP ' + baskasiSil.kod);

    // ⚠️ NaN/aralik disi koordinat 400: `ParseFloat("NaN")` hata DONDURMEZ ve
    //    NaN her karsilastirmadan gecer (turu 85b dersi).
    const bozukKoord = await j('/users/me/adresler', {
      yontem: 'POST', token: Z.token,
      govde: { ad: 'Bozuk', enlem: 999, boylam: 0 },
    });
    kontrol('TURU 96h: aralik disi koordinat 400',
      bozukKoord.kod === 400, 'HTTP ' + bozukKoord.kod);

    // ⚠️ AYNI AD ikinci kez -> GUNCELLENIR (istemci "Ev"i yeniden secebilmeli)
    const tekrar = await j('/users/me/adresler', {
      yontem: 'POST', token: Z.token,
      govde: { ad: 'Ev', enlem: 41.0, boylam: 29.0 },
    });
    const guncel = await j('/users/me/adresler', { token: Z.token });
    const ev = (((guncel.d || {}).adresler) || []).find((a) => a.ad === 'Ev');
    kontrol('TURU 96h: AYNI AD ikinci kez gonderilince GUNCELLENIR',
      tekrar.kod === 201 && (((guncel.d || {}).adresler) || []).length === 2 &&
      Math.abs((ev || {}).enlem - 41.0) < 0.001,
      'adet=' + (((guncel.d || {}).adresler) || []).length +
      ' enlem=' + ((ev || {}).enlem));

    const sil = await j('/users/me/adresler/' + evId,
      { yontem: 'DELETE', token: Z.token });
    kontrol('TURU 96h: adres silinebiliyor', sil.kod === 204,
      'HTTP ' + sil.kod);

    // ⚠️⚠️⚠️ TURU 96 — LISTE YANITI **KOORDINAT DONDURMELI**.
    //
    //	Kart altindaki "1,2 km" mesafesi ISTEMCIDE hesaplaniyor (Haversine)
    //	ve girdisi bu iki alan. Sunucu bunlari dondurmeyi birakirsa mesafe
    //	SESSIZCE KAYBOLUR: istemci patlamaz, log dusmez, `flutter analyze`
    //	temiz gecer — kullanici yalnizca "mesafe yok" der (nitekim bir kez
    //	oyle oldu, cunku alanlar bastan YOKTU).
    // ⚠️ `sutun_test.go` SELECT/Scan/yanit UCLUSUNU olcer ama ucu birden
    //    silinirse yesil kalir; bu kontrol UCTAN UCA bakar.
    const koord = await j('/isletmeler?kategori=yemek', { token: Z.token });
    const kliste = ((koord.d || {}).isletmeler) || [];
    const koordVar = kliste.length > 0 &&
      kliste.every((o) => typeof o.enlem === 'number' &&
        typeof o.boylam === 'number') &&
      kliste.some((o) => o.enlem !== 0 || o.boylam !== 0);
    kontrol('TURU 96: liste yaniti KOORDINAT donduruyor (kart mesafesi buna bagli)',
      koordVar,
      'adet=' + kliste.length + ' ilk=' +
      (kliste[0] ? kliste[0].enlem + ',' + kliste[0].boylam : '-'));

    // ══════════════════════════════════════════════════════════════════
    // TURU 114 — "MAHALLE" AKISI (akistaki ucuncu bolme)
    // ══════════════════════════════════════════════════════════════════
    //
    // ⚠️ Bu blok MEKANSAL SUZGECI GERCEKTEN OLCER: yakina bir gonderi, uzaga
    //    bir gonderi atilir ve YALNIZ yakindakinin dondugu dogrulanir. Yalniz
    //    "200 dondu mu" bakmak, yuklem BOZUK olsa bile yesil kalirdi
    //    (turu 93b dersi: "dolu alan, IS GOREN alan demek DEGILDIR").
    const MLAT = 40.8028, MLNG = 29.4300;

    const yakinG = await j('/posts', {
      token: Z.token, yontem: 'POST',
      govde: { tur: 'yazi', metin: 'mahalle testi YAKIN', enlem: MLAT, boylam: MLNG },
    });
    kontrol('TURU 114: konumlu gonderi olusturulabiliyor',
      yakinG.kod === 201, 'HTTP ' + yakinG.kod);

    // ⚠️ ~55 km kuzey: 15 km VARSAYILAN yaricapin acikca disinda ama sunucu
    //    TAVANININ (100 km) ICINDE. Tavanin USTUNE cikilsaydi asagidaki
    //    "genis yaricap" kontrolu YAPISAL OLARAK gecemezdi (ilk yazimda
    //    1.1 derece = ~122 km secilmisti ve test HAKLI OLARAK kirmizi dustu).
    const uzakG = await j('/posts', {
      token: Z.token, yontem: 'POST',
      govde: {
        tur: 'yazi', metin: 'mahalle testi UZAK',
        enlem: MLAT + 0.5, boylam: MLNG,
      },
    });

    const mah = await j('/mahalle?lat=' + MLAT + '&lng=' + MLNG, { token: Z.token });
    const mPosts = ((mah.d || {}).posts) || [];
    const mIds = mPosts.map((p) => p.id);
    kontrol('TURU 114: /mahalle YAKINDAKI gonderiyi donduruyor',
      mah.kod === 200 && mIds.includes((yakinG.d || {}).id),
      'HTTP ' + mah.kod + ' adet=' + mPosts.length);

    // ⚠️ ASIL KANIT: kaba kutu + Haversine GERCEKTEN eliyor mu?
    kontrol('TURU 114: /mahalle UZAKTAKI gonderiyi ELIYOR (mekansal suzgec calisiyor)',
      !mIds.includes((uzakG.d || {}).id),
      'uzak id listede mi=' + mIds.includes((uzakG.d || {}).id));

    // ⚠️ Yaricap BUYUTULUNCE uzak gonderi GELMELI — yoksa suzgec "her seyi
    //    eliyor" olabilirdi ve ustteki kontrol YANLIS SEBEPTEN gecerdi.
    const mahGenis = await j('/mahalle?lat=' + MLAT + '&lng=' + MLNG + '&km=100',
      { token: Z.token });
    const mgIds = (((mahGenis.d || {}).posts) || []).map((p) => p.id);
    kontrol('TURU 114: km buyutulunce UZAK gonderi de geliyor (elemenin sebebi MESAFE)',
      mahGenis.kod === 200 && mgIds.includes((uzakG.d || {}).id),
      'HTTP ' + mahGenis.kod + ' adet=' + mgIds.length);

    // ⚠️ KONUMSUZ gonderi mahallede HIC gorunmemeli (enlem=0 AND boylam=0).
    const konumsuz = await j('/posts', {
      token: Z.token, yontem: 'POST',
      govde: { tur: 'yazi', metin: 'mahalle testi KONUMSUZ' },
    });
    const mah2 = await j('/mahalle?lat=' + MLAT + '&lng=' + MLNG + '&km=100',
      { token: Z.token });
    const m2Ids = (((mah2.d || {}).posts) || []).map((p) => p.id);
    kontrol('TURU 114: KONUMSUZ gonderi mahallede GORUNMEZ',
      !m2Ids.includes((konumsuz.d || {}).id),
      'konumsuz id listede mi=' + m2Ids.includes((konumsuz.d || {}).id));

    // ⚠️ Koordinatsiz istek 400 — koordinatsiz bir "mahalle" tanimsizdir.
    const mahBos = await j('/mahalle', { token: Z.token });
    kontrol('TURU 114: /mahalle konumsuz istekte 400',
      mahBos.kod === 400, 'HTTP ' + mahBos.kod);

    // ⚠️⚠️ `NaN` SESSIZ BOS LISTE URETMEMELI: `ParseFloat("NaN")` HATA
    //    DONDURMEZ ve NaN her karsilastirmadan false ile gecer. 400 bekleriz.
    const mahNaN = await j('/mahalle?lat=NaN&lng=29.4', { token: Z.token });
    kontrol('TURU 114: /mahalle NaN koordinati 400 ile REDDEDER',
      mahNaN.kod === 400, 'HTTP ' + mahNaN.kod);
  }

  // ==================== TURU 115: /ara (ARAMA UCU) ====================
  //
  // ⚠️⚠️ BU UCUN KAPSAMI **SIFIRDI** (denetim bulgusu). Uc turu 115'te
  //	yazildi, istemcinin BES ARAMA SEKMESINDEN DORDU ona bagli, ama 375
  //	kontrolun HICBIRI ona bakmiyordu.
  //	Bu projede turu 113 ve 114'te SQL hatalarini YALNIZ canli e2e yakaladi
  //	(`go build`+`go vet`+birim testler UCU DE TEMIZ geciyordu) — yani
  //	kapsamsiz bir uc, sessizce 500 donebilecek bir uctur.
  {
    const araG = await j('/posts', {
      token: A.token, yontem: 'POST',
      // ⚠️ KOORDINAT ZORUNLU: `tur=konum` yuklemi `enlem <> 0 OR boylam <> 0
      //    diyor, yani "Yerler" = GERCEKTEN KONUMU OLAN gonderi. Ilk
      //    yazimda yalniz `konum` adi verilmisti ve kontrol KIRMIZI dustu —
      //    sunucu HAKLIYDI: adi olup pini olmayan gonderi bir YER degildir.
      govde: {
        tur: 'yazi', metin: 'ara testi zurafali kelime',
        konum: 'Gebze Merkez', enlem: 40.8, boylam: 29.43,
      },
    });
    const araId = (araG.d || {}).id;

    const a1 = await j('/ara?q=zurafali', { token: A.token });
    const a1Ids = (((a1.d || {}).posts) || []).map((x) => x.id);
    kontrol('TURU 115: /ara metin aramasi calisiyor',
      a1.kod === 200 && a1Ids.includes(araId),
      'HTTP ' + a1.kod + ' adet=' + a1Ids.length);

    // ⚠️ ASIL KANIT: yuklem KELIME BAZLI **AND** mi? Iki kelime de gecmeli.
    //    Turu 93b'de ayni sinif yasandi: iki terim TEK BITISIK ALT DIZE
    //    araniyordu ve liste KALICI bosaliyordu.
    const a2 = await j('/ara?q=zurafali%20kelime', { token: A.token });
    kontrol('TURU 115: /ara COK KELIMELI arama (AND) calisiyor',
      a2.kod === 200 && (((a2.d || {}).posts) || []).map((x) => x.id).includes(araId),
      'HTTP ' + a2.kod);

    // ⚠️ TERS YON: kelimelerden BIRI eslesmiyorsa sonuc BOS olmali (OR degil AND).
    const a3 = await j('/ara?q=zurafali%20kangurulu', { token: A.token });
    kontrol('TURU 115: /ara AND yuklemi — eslesmeyen kelime sonucu ELER',
      a3.kod === 200 && !(((a3.d || {}).posts) || []).map((x) => x.id).includes(araId),
      'HTTP ' + a3.kod);

    // ⚠️ KONUM ADI da aranabilir olmali (istemcideki "Yerler" sekmesi buna bagli).
    const a4 = await j('/ara?q=Merkez&tur=konum', { token: A.token });
    kontrol('TURU 115: /ara?tur=konum konum adinda ariyor',
      a4.kod === 200 && (((a4.d || {}).posts) || []).map((x) => x.id).includes(araId),
      'HTTP ' + a4.kod);

    // ⚠️ TEK HARF reddedilmeli: `ILIKE '%a%'` TUM tabloyu tarardi.
    const a5 = await j('/ara?q=a', { token: A.token });
    kontrol('TURU 115: /ara tek karakterli sorguyu 400 ile REDDEDER',
      a5.kod === 400, 'HTTP ' + a5.kod);

    // ⚠️ BILINMEYEN `tur` reddedilmeli (beyaz liste); sessizce yok saymak
    //    kullaniciya BOS liste gosterip sebebini gizlerdi.
    const a6 = await j('/ara?q=zurafali&tur=zurafa', { token: A.token });
    kontrol('TURU 115: /ara gecersiz turu 400 ile REDDEDER',
      a6.kod === 400, 'HTTP ' + a6.kod);

    // ⚠️ Content-Type — turu 96i dersi: dogru govde, YANLIS baslik = istemci
    //    ayristiramaz ve hatayi YUTAR.
    kontrol('TURU 115: /ara yaniti application/json BASLIGI tasiyor',
      String(a1.tur || '').includes('application/json'), 'tur=' + a1.tur);
  }

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
