// ═══════════════════ SOSYAL TOHUM (turu 180w) ═══════════════════
//
// Kullanici emri: *"sosyal medya sifirla her seyi sifirla; gonderi, reels
// vs paylasabilelim, yorum atabilelim, bildirimler gelsin — yorum yapti,
// begendi, mesaj bildirimleri hepsi TAM CALISIR sekilde"*.
//
// ⚠️⚠️ NEDEN GEREKLI: `kDemoAkis` bu turda **KAPATILDI**, yani akis · hikaye
//    seridi · sohbet listesi · bildirimler artik YALNIZ sunucudan besleniyor.
//    Bos bir veritabaninda kullanici uygulamayi acinca dort ekran birden
//    BOMBOS gorunur ve "sosyal medya calismiyor" der. Bu modul o ekranlari
//    **GERCEK** kayitlarla doldurur.
//
// ⚠️ Uretilen HER SEY GERCEKTIR: gercek `posts` satirlari, gercek yorumlar,
//    gercek begeniler, gercek `bildirimler` satirlari (sunucu uretir),
//    gercek sohbet + mesajlar, gercek hikaye. Sahte/`demo-` onekli hicbir
//    kayit YOK.
//
// ⚠️ MEDYA presign -> R2 PUT -> commit zincirinden gecer (API'den GECMEZ,
//    turu 75 kurali). Gorseller `kapak_uret.js` ile URETILIR — internetten
//    indirilmez, telif riski yok.
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { kapakUret, avatarUret } = require('./kapak_uret');
const { sohbetTohum } = require('./sohbet_tohum');

/// Tek bir gorseli presign -> PUT -> commit zincirinden gecirir ve
/// `media_id` doner.
///
/// ⚠️ `kind: 'image'`: gonderi/hikaye medyasi. `kapak` YALNIZ profil
///    kapagi icindir ve sunucu bunu 403 ile ayirir (turu 78).
async function gorselYukle(j, token, tohum) {
  const png = kapakUret(tohum, 1080, 1080);
  const md5 = crypto.createHash('md5').update(png).digest('base64');
  const p = await j('/media/upload', {
    yontem: 'POST',
    token,
    govde: {
      kind: 'image',
      mime: 'image/png',
      bytes: png.length,
      md5,
      file_name: 'gonderi.png',
      width: 1080,
      height: 1080,
    },
  });
  if (p.kod !== 200) throw new Error(`gorsel presign ${p.kod}`);
  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/png', 'Content-MD5': md5 },
    body: png,
  });
  if (!put.ok) throw new Error(`gorsel PUT ${put.status}`);
  const c = await j(`/media/${p.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) throw new Error(`gorsel commit ${c.kod}`);
  return p.d.media_id;
}

/// Yerel bir mp4 dosyasini presign -> PUT -> commit zincirinden gecirir.
///
/// UYARI Dosya YOKSA `null` doner ve cagiran ATLAR: bu videolar
///    `.gitignore` sinirinda duran ORNEK/TANITIM iceriktir; temiz bir
///    klonda bulunmayabilir ve tohumun geri kalanini BOZMAMALI.
/// UYARI `kind: video` ZORUNLU — sunucu tavanlari tur basina AYRI
///    (video 100 MB, gorsel cok daha az) ve mime beyaz listesi
///    `video/mp4` bekliyor ('video/mpeg4' vb. REDDEDILIR).
/// ⚠️⚠️⚠️ TURU 180z — TOHUM VIDEOSUNA **POSTER** (kullanici emri:
/// *"videolarda on izleme olsun"*).
///
/// Uygulama posteri gonderim aninda uretiyor (`video_poster.dart` + native
/// kanal), ama TOHUMLA yuklenen videolarin posteri OLMAZDI — kullanici
/// emulator/telefonda kanal ve sohbet videolarinda bos bir oynat rozeti
/// gorur ve "on izleme calismiyor" derdi.
///
/// ⚠️ Kare **ffmpeg ile GERCEK VIDEODAN** cikarilir (1. saniye), uydurma bir
///    gorsel URETILMEZ (turu 135 dersi: sunucuda karsiligi olmayan veriyi
///    gercekmis gibi gosterme).
/// ⚠️ ffmpeg YOKSA `null` doner ve video POSTERSIZ yuklenir — tohum
///    BOZULMAZ (ffmpeg bir gelistirme araci, calisma zamani bagimliligi
///    DEGIL).
function videoPosteriCikar(dosya) {
  const hedef = path.join(
    os.tmpdir(),
    `gebzem_poster_${path.basename(dosya)}.jpg`,
  );
  try {
    // ⚠️ `-ss 1`: bircok videonun ILK karesi siyah bir gecistir ve poster
    //    bombos cikardi (istemci tarafi da 1 sn'den aliyor — AYNI kural).
    execFileSync(
      'ffmpeg',
      ['-y', '-ss', '1', '-i', dosya, '-frames:v', '1',
        '-vf', 'scale=640:-2', '-q:v', '5', hedef],
      { stdio: 'ignore' },
    );
    const b = fs.readFileSync(hedef);
    return b.length > 0 ? b : null;
  } catch (_) {
    return null;
  }
}

async function videoYukle(j, token, dosya) {
  let bayt;
  try {
    bayt = fs.readFileSync(dosya);
  } catch (_) {
    return null;
  }
  const md5 = crypto.createHash('md5').update(bayt).digest('base64');
  const poster = videoPosteriCikar(dosya);
  const posterMd5 = poster
    ? crypto.createHash('md5').update(poster).digest('base64')
    : '';
  const pr = await j('/media/upload', {
    yontem: 'POST',
    token,
    govde: {
      kind: 'video',
      mime: 'video/mp4',
      bytes: bayt.length,
      md5,
      file_name: path.basename(dosya),
      width: 720,
      height: 1280,
      // ⚠️ Sunucu `thumb_bytes > 0` gorurse AYRI bir PUT adresi
      //    (`<anahtar>_t`) verir ve `thumb_key` sutununu doldurur
      //    (`media/handler.go:162-165`). 0 ise poster zinciri HIC kurulmaz.
      thumb_bytes: poster ? poster.length : 0,
      thumb_md5: posterMd5,
    },
  });
  if (pr.kod !== 200) return null;
  const put = await fetch(pr.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'video/mp4', 'Content-MD5': md5 },
    body: bayt,
  });
  if (!put.ok) return null;
  // ⚠️ POSTER PUT'u COMMIT'TEN ONCE: commit dogrulama sirasinda thumb
  //    nesnesini de arar; sonra yuklenirse `thumb_key` dolu ama nesne YOK
  //    olur ve istemci imzali adresten 404 alirdi.
  if (poster && pr.d.thumb_url) {
    const tp = await fetch(pr.d.thumb_url, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': posterMd5 },
      body: poster,
    });
    if (!tp.ok) return null;
  }
  const c = await j(`/media/${pr.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) return null;
  return pr.d.media_id;
}

/// ⚠️ TURU 180z — AVATAR/KANAL FOTOGRAFI yukler ve `media_id` DONER.
///
/// ⚠️ `tools/tohum.js` icindeki `avatarYukle` ile KARISTIRMA: o hesabin
///	profiline BAGLAR (PATCH /users/me) ve `bool` doner; bu YALNIZCA
///	yukler, cagiran id'yi istedigi yere baglar (kanal avatari gibi).
/// ⚠️ `kind: 'avatar'` — kanal ucu kontrol etmiyor ama diger yuzeyler bu
///	sozlesmeye gore yazildi; tohum onlardan AYRISMAMALI.
async function avatarYukle(j, token, tohum) {
  const png = avatarUret(tohum);
  const md5 = crypto.createHash('md5').update(png).digest('base64');
  const p = await j('/media/upload', {
    yontem: 'POST',
    token,
    govde: {
      kind: 'avatar', mime: 'image/png', bytes: png.length, md5,
      file_name: 'avatar.png', width: 512, height: 512,
    },
  });
  if (p.kod !== 200) return null;
  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/png', 'Content-MD5': md5 },
    body: png,
  });
  if (!put.ok) return null;
  const c = await j(`/media/${p.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) return null;
  return p.d.media_id;
}

/// Bagimliliksiz, gecerli bir tek sayfalik PDF uretir.
///
/// ⚠️⚠️⚠️ **NEDEN PDF, NEDEN `text/plain` DEGIL — CANLI SUNUCUDA OLCULDU.**
///	Ilk yazim `text/plain` gonderiyordu ve commit **422** ile reddedildi.
///	Sebep: `media/sniff.go` `GercekTip()` icerigi KOKLUYOR ve duz metnin
///	bir imzasi YOK -> "dosya turu taninamadi". Yani sunucu `text/plain`i
///	beyaz listede KABUL ediyor ama commit'te REDDEDIYOR — bu SUNUCU
///	TARAFINDA gercek bir kusur (⏳ backend turu). PDF `%PDF-` imzasiyla
///	kokulanabildigi icin zincirin TAMAMINDAN gecer.
/// ⚠️ Ayni sinif `.xls`te de var: OLE kabi `application/msword` olarak
///	kokulaniyor, beyan `application/vnd.ms-excel` -> "beyanla uyusmuyor".
/// ⚠️ Kutuphane KULLANILMADI: PDF'in minimal govdesi elle yazilabiliyor ve
///	tohumun harici bagimliligi olmamali.
function pdfUret(baslik) {
  const icerik = `BT /F1 14 Tf 72 720 Td (${baslik.replace(/[()\\]/g, '')}) Tj ET`;
  const nesneler = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
      + '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    `<< /Length ${icerik.length} >>\nstream\n${icerik}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let govde = '%PDF-1.4\n';
  const ofsetler = [];
  for (let i = 0; i < nesneler.length; i++) {
    ofsetler.push(govde.length);
    govde += `${i + 1} 0 obj\n${nesneler[i]}\nendobj\n`;
  }
  const xrefKonum = govde.length;
  govde += `xref\n0 ${nesneler.length + 1}\n0000000000 65535 f \n`;
  for (const o of ofsetler) {
    govde += `${String(o).padStart(10, '0')} 00000 n \n`;
  }
  govde += `trailer\n<< /Size ${nesneler.length + 1} /Root 1 0 R >>\n`
    + `startxref\n${xrefKonum}\n%%EOF\n`;
  return Buffer.from(govde, 'latin1');
}

/// ⚠️⚠️⚠️ TURU 180z — **BELGE YUKLEME** (kanal profilindeki "Belgeler"
/// bolumunu besler).
///
/// ⚠️ `width/height` GONDERILMEZ: belge bir gorsel degil.
async function belgeYukle(j, token, kanalAdi) {
  const govde = pdfUret(`${kanalAdi} - kanal duyuru metni`);
  const md5 = crypto.createHash('md5').update(govde).digest('base64');
  const p = await j('/media/upload', {
    yontem: 'POST',
    token,
    govde: {
      kind: 'document',
      mime: 'application/pdf',
      bytes: govde.length,
      md5,
      file_name: 'kanal-duyuru.pdf',
    },
  });
  if (p.kod !== 200) throw new Error(`belge presign ${p.kod}`);
  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/pdf', 'Content-MD5': md5 },
    body: govde,
  });
  if (!put.ok) throw new Error(`belge PUT ${put.status}`);
  const c = await j(`/media/${p.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) throw new Error(`belge commit ${c.kod}`);
  return p.d.media_id;
}

/// Gonderi metinleri — Gebze'de yasayan gercek insanlarin yazacagi dilde.
///
/// ⚠️ Marka adi ve gercek kisi adi YOK: tohum verisi yayina sizsa bile
///    kimseye ait olmayan notr icerik kalir.
const GONDERILER = [
  {
    tur: 'foto',
    metin: 'Sabah sahilde yurudum, hava harikaydi. Gebze bugun cok guzel. ☀️',
    gorsel: true,
  },
  {
    tur: 'yazi',
    metin:
      'Komsular, Osman Yilmaz mahallesinde guvenilir bir tesisatci ariyorum. '
      + 'Oneriniz var mi?',
    gorsel: false,
  },
  {
    tur: 'foto',
    metin: 'Yeni acilan kahveci gercekten iyi. Filtre kahve tavsiye ederim.',
    gorsel: true,
  },
];

const IKINCI_GONDERILER = [
  {
    tur: 'foto',
    metin: 'Bugun cocuklarla parktaydik. Hafta sonu programi tamam. 🌳',
    gorsel: true,
  },
  {
    tur: 'yazi',
    metin: 'Aksam 19:00 sonrasi sahilde yuruyus grubu kuralim mi?',
    gorsel: false,
  },
];

const YORUMLAR = [
  'Cok guzel olmus, ellerine saglik!',
  'Ben de oradaydim, harika bir gundu.',
  'Katiliyorum, kesinlikle tavsiye ederim.',
];

/// Sosyal katmani GERCEK verilerle doldurur.
///
/// [kullanicilar] en az IKI hesap ister (karsilikli takip, yorum, begeni ve
/// mesaj icin); [isletmeler] varsa ilk isletme de akisa katilir ki akis tek
/// kisilik gorunmesin.
///
/// ⚠️ SIRA ONEMLI: once TAKIP, sonra gonderi. Ters olsaydi akis sorgusu
///    (takip ettiklerini gosterir) bos donerdi ve "gonderi paylastim,
///    akiste yok" izlenimi olusurdu.
async function sosyalTohum(j, kullanicilar, isletmeler, etkinlikler) {
  if (!kullanicilar || kullanicilar.length < 2) {
    throw new Error('sosyal tohum EN AZ iki kullanici ister');
  }
  const [A, B] = kullanicilar;
  const C = (isletmeler || [])[0] || null;
  const ozet = { gonderi: 0, yorum: 0, begeni: 0, mesaj: 0, hikaye: 0, reels: 0 };

  // ── 1) KARSILIKLI TAKIP (+ bir isletme)
  //
  // ⚠️ Takip bir BILDIRIM uretir ("seni takip etmeye basladi") — yani
  //    bildirimler ekrani da bu adimdan besleniyor.
  await j(`/users/${A.id}/follow`, { yontem: 'POST', token: B.token });
  await j(`/users/${B.id}/follow`, { yontem: 'POST', token: A.token });
  if (C) {
    await j(`/users/${C.id}/follow`, { yontem: 'POST', token: A.token });
    await j(`/users/${C.id}/follow`, { yontem: 'POST', token: B.token });
  }

  // ── 2) GONDERILER
  const yaz = async (h, tanim, tohum) => {
    const media = tanim.gorsel
      ? [await gorselYukle(j, h.token, tohum)]
      : [];
    const r = await j('/posts', {
      yontem: 'POST',
      token: h.token,
      govde: { tur: tanim.tur, metin: tanim.metin, media_ids: media },
    });
    if (r.kod !== 201) throw new Error(`gonderi ${r.kod}`);
    ozet.gonderi++;
    return r.d.id;
  };

  const aPost = [];
  for (let i = 0; i < GONDERILER.length; i++) {
    aPost.push(await yaz(A, GONDERILER[i], 40 + i));
  }
  const bPost = [];
  for (let i = 0; i < IKINCI_GONDERILER.length; i++) {
    bPost.push(await yaz(B, IKINCI_GONDERILER[i], 50 + i));
  }
  if (C) {
    await yaz(C, {
      tur: 'foto',
      metin: 'Bugun tum menude %10 indirim var. Bekleriz!',
      gorsel: true,
    }, 60);
  }

  // ── 3) BEGENI + YORUM (bildirim uretir)
  //
  // ⚠️ Etkilesim KARSI TARAFTAN gelir: kendi gonderini begenmek bildirim
  //    URETMEZ (sunucu `alici == aktor` durumunda yazmaz) ve bildirimler
  //    ekrani yine bos kalirdi.
  for (const pid of aPost) {
    const be = await j(`/posts/${pid}/like`, { yontem: 'POST', token: B.token });
    if (be.kod === 200) ozet.begeni++;
  }
  for (const pid of bPost) {
    const be = await j(`/posts/${pid}/like`, { yontem: 'POST', token: A.token });
    if (be.kod === 200) ozet.begeni++;
  }
  for (let i = 0; i < aPost.length && i < YORUMLAR.length; i++) {
    const y = await j(`/posts/${aPost[i]}/comments`, {
      yontem: 'POST',
      token: B.token,
      govde: { metin: YORUMLAR[i] },
    });
    if (y.kod === 201) ozet.yorum++;
  }
  if (bPost.length) {
    const y = await j(`/posts/${bPost[0]}/comments`, {
      yontem: 'POST',
      token: A.token,
      govde: { metin: 'Ben de gelmek isterim, saat kacta?' },
    });
    if (y.kod === 201) ozet.yorum++;
  }
  // ⚠️ Bir gonderi KAYDEDILIR: "Kaydedilenler" sekmesi de bos kalmasin.
  if (aPost.length) {
    await j(`/posts/${aPost[0]}/save`, { yontem: 'POST', token: B.token });
  }

  // ── 3b) REELS (dikey kisa video)
  //
  // UYARI Reels sekmesi YALNIZ `tur: reels` gonderileri gosterir; tek
  //    bir kayit yoksa ekran BOMBOS acilir ve kullanici ozelligi
  //    "calismiyor" sanir.
  // UYARI Video dosyalari repoda ORNEK icerik olarak duruyor; yoksa bu
  //    adim SESSIZCE atlanir (tohumun geri kalani bozulmaz).
  const REELS = [
    { dosya: 'feedmc/33.mp4', sahip: A, metin: 'Hafta sonu Gebze turu 🎬' },
    { dosya: 'feedmc/44.mp4', sahip: B, metin: 'Sahilde gun batimi 🌅' },
  ];
  for (const r of REELS) {
    const mid = await videoYukle(j, r.sahip.token, r.dosya);
    if (!mid) continue;
    const g = await j('/posts', {
      yontem: 'POST',
      token: r.sahip.token,
      govde: { tur: 'reels', metin: r.metin, media_ids: [mid] },
    });
    if (g.kod === 201) {
      ozet.gonderi++;
      ozet.reels = (ozet.reels || 0) + 1;
      // Karsi taraftan GERCEK begeni (reels sayaci dolu gorunsun).
      const digeri = r.sahip === A ? B : A;
      const be = await j(`/posts/${g.d.id}/like`, {
        yontem: 'POST',
        token: digeri.token,
      });
      if (be.kod === 200) ozet.begeni++;
    }
  }

  // ── 4) HIKAYE (24 saatlik pencere — serit dolu gorunsun)
  try {
    const mid = await gorselYukle(j, A.token, 70);
    const st = await j('/stories', {
      yontem: 'POST',
      token: A.token,
      govde: { media_id: mid, kind: 'image', metin: 'Gunaydin Gebze!' },
    });
    if (st.kod === 201) ozet.hikaye++;
  } catch (_) {
    // ⚠️ SESSIZ: hikaye ekranin ASIL isi degil; medya patlarsa tohumun
    //    geri kalani BOZULMAMALI.
  }

  // ── 5) ZENGIN SOHBETLER (turu 180y — kullanici emri)
  //
  // ⚠️ Mesaj bildirimi PUSH ile gider (`bildirimler` tablosuna YAZILMAZ —
  //    WhatsApp/Instagram da DM'leri bildirim sekmesine koymaz). Buradaki
  //    amac SOHBET LISTESININ dolu olmasi ve okunmamis rozetinin GERCEK
  //    bir sayidan gelmesi.
  //
  // ⚠️⚠️ Alti sohbet + her mesaj tipi + arsiv `tools/sohbet_tohum.js`te;
  //    burada TEKRARLANMAZ (tek kaynak).
  const sohbetMedya = {
    foto1: await gorselYukle(j, B.token, 71).catch(() => null),
    foto2: await gorselYukle(j, B.token, 72).catch(() => null),
    foto3: C ? await gorselYukle(j, C.token, 73).catch(() => null) : null,
    video: await videoYukle(j, A.token, 'feedmc/33.mp4').catch(() => null),
    // ⚠️ Medya GONDERENE ait olmali (sunucu 403 "geçersiz medya" doner);
    //    her gonderen icin AYRI yukleme.
    videoIcin: (h) =>
      videoYukle(j, h.token, 'feedmc/33.mp4').catch(() => null),
    // ⚠️ TURU 180z — BELGE ve EK FOTOGRAF da GONDERENE ait olmali
    //	(ayni 403 kapisi). Her cagri AYRI bir yukleme yapar.
    belgeIcin: (h, ad) => belgeYukle(j, h.token, ad).catch(() => null),
    fotoIcin: (h, t) => gorselYukle(j, h.token, t).catch(() => null),
    etkinlik: (etkinlikler || [])[0] || null,
  };
  const sh = await sohbetTohum(j, A, B, isletmeler || [], sohbetMedya);
  ozet.mesaj += sh.mesaj;
  ozet.sohbet = sh.sohbet;
  ozet.arsiv = sh.arsiv;
  // ⚠️ Anket sayaci sohbet tohumundan gelir (ozet birlestirme).
  ozet.anket = sh.anket || 0;

  // ── 7) TOPLULUKLAR (turu 180x)
  //
  // ⚠️ Topluluk = `channels` tablosu; `GET /chats` onlari YAPISAL OLARAK
  //    dondurmez. Sohbet listesindeki "Topluluklar" bolumu ve "Yeni mesaj"
  //    ekranindaki oneriler `/channels` ve `/channels/kesfet` ile besleniyor
  //    -> tohumda EN AZ IKI topluluk olmali:
  //      · A'nin kurdugu   -> A'nin listesinde (ABONE oldugu icin)
  //      · B'nin kurdugu   -> A'nin KESFET listesinde (abone DEGIL)
  //    Tek topluluk olsaydi iki yuzeyden biri DAIMA bos gorunur ve ozellik
  //    kirik sanilirdi.
  const TOPLULUKLAR = [
    [A, {
      ad: 'Gebze Komsulari',
      kullanici_adi: 'gebzekomsulari',
      aciklama: 'Mahalle duyurulari, kayip esya, komsu yardimlasmasi.',
    }, [
      // ⚠️ TURU 180y — kullanici emri: *"toplulukta bir cok mesaj atilmis
      //    gibi"*. Tek gonderili bir topluluk "calismiyor" gibi gorunuyordu.
      'Merhaba komsular! Bu topluluk mahalle duyurulari icin.',
      'Cumartesi 10:00da parkta temizlik etkinligi var, bekleriz.',
      'Sokak lambasi arizasi belediyeye bildirildi, bu hafta onarilacak.',
      'Pazar kurulumu bu hafta 07:00-16:00 arasinda.',
      'Kayip kedi: turuncu tekir, Osman Yilmaz mahallesi civari.',
      'Su kesintisi 14:00-17:00 arasi olacak, deponuzu doldurun.',
      'Apartman gorevlisi ilani veren komsumuz ulasabilir.',
      'Bu ayki mahalle toplantisi carsamba 20:00, muhtarlikta.',
      // ⚠️ TURU 180z — kullanici emri: *"kanal olsun icinde BIR SURU
      //	gonderi"*. 8 -> 14 gonderi: izgara, begeni sayaclari ve
      //	sayfalama ancak dolu bir kanalda gorulebilir.
      'Yeni acilan firinin ekmegi cok iyi, tavsiye ederim.',
      'Cocuk parkindaki salincak onarildi, tesekkurler muhtarim.',
      'Yarin sabah 08:00de cop toplama arabasi gelecek.',
      'Aidat makbuzlari apartman girisine birakildi.',
      'Kis hazirligi icin kalorifer peteklerini kontrol ettirin.',
      'Mahallemize yeni bir eczane aciliyor, hayirli olsun.',
    ]],
    [B, {
      ad: 'Gebze Etkinlik',
      kullanici_adi: 'gebzeetkinlik',
      aciklama: 'Sehirdeki konser, tiyatro ve festival duyurulari.',
    }, [
      'Bu hafta sonu sahilde acik hava sinemasi var.',
      'Cuma aksami kultur merkezinde tiyatro: bilet 100 TL.',
      'Kitap gunleri basliyor, yazar soylesileri programda.',
      'Akustik konser icin son biletler kaldi.',
      'Pazar sabahi sahilde yoga etkinligi var, katilim ucretsiz.',
      'Genclik merkezinde fotograf sergisi bu hafta aciliyor.',
      'Cocuklar icin tiyatro gosterisi cumartesi 11:00de.',
    ]],
  ];
  ozet.topluluk = 0;
  ozet.toplulukGonderi = 0;
  for (const [h, govde, gonderiler] of TOPLULUKLAR) {
    // ⚠️⚠️ TURU 180z — KANAL AVATARI (kullanici emri: *"profil
    //	fotograflari yani gercek bir sohbet alani gibi olsun"*).
    //	Avatarsiz kanal sohbet listesinde ve profilde HARFLI daireye
    //	dusuyordu.
    // ⚠️ Sunucu kanal avatarinda medya `kind` alanini KONTROL ETMIYOR
    //	(yalniz owner_id + status) — yine de sozlesme geregi `avatar`
    //	kind'i yukleniyor: istemci ve diger yuzeyler o kurala gore
    //	yazildi ve tohum onlardan AYRISMAMALI.
    let kanalAvatar = null;
    try {
      kanalAvatar = await avatarYukle(j, h.token, ozet.topluluk + 40);
    } catch (_) {}
    const k = await j('/channels', {
      yontem: 'POST',
      token: h.token,
      govde: kanalAvatar ? { ...govde, avatar_media_id: kanalAvatar } : govde,
    });
    // ⚠️ 409 = ad ALINMIS (betik ikinci kez kosuldu). Tohum PATLAMAZ:
    //    diger adimlar calismaya devam etmeli.
    if (k.kod !== 201 && k.kod !== 200) continue;
    const kid = k.d && (k.d.id || k.d.channel_id);
    if (!kid) continue;
    ozet.topluluk++;
    // ⚠️⚠️ TURU 180z — KANAL GONDERILERINE GORSEL (kanal profilindeki
    //	"Paylasilan gorseller" izgarasi bunlardan TURETILIYOR). Medyasiz
    //	tohumda izgara DAIMA bos cikiyor ve ozellik kirik sanilirdi.
    // ⚠️ Gorsel KANAL SAHIBININ token'iyla yuklenir: sunucu medyanin
    //	yukleyene ait olmasini SART kosuyor (baskasinin id'siyle gonderi
    //	**403 "gecersiz medya"** doner — sohbet tohumunda olculdu).
    // ⚠️⚠️ TURU 180z — KANALA **VIDEO ve BELGE** de konur (kullanici:
    //	*"kanalda sadece gorsel degil video belge vs de paylasiliyor"*).
    //	Kanal profilindeki "Paylasilan medya" izgarasi ve "Belgeler"
    //	bolumu bunlardan besleniyor; yalniz gorsel konsaydi iki yuzeyden
    //	biri DAIMA bos gorunur ve ozellik kirik sanilirdi.
    const kanalGorsel = [];
    for (let i = 0; i < 3; i++) {
      try {
        // ⚠️ `kapakUret` tohumu SAYI bekler: string gecilirse `tohum % PALET.length`
        //	**NaN** olur ve `PALET[NaN]` undefined donup destructure PATLAR.
        kanalGorsel.push(await gorselYukle(j, h.token, ozet.toplulukGonderi + i));
      } catch (_) {
        // en iyi caba: gorsel yuklenemezse gonderiler METINLE atilir
      }
    }
    // Kanal sahibinin token'iyla bir VIDEO ve bir BELGE.
    // ⚠️ Medya YUKLEYENE ait olmali: baskasinin id'siyle gonderi 403
    //	"gecersiz medya" doner (sohbet tohumunda olculdu).
    let kanalVideo = null;
    try {
      kanalVideo = await videoYukle(j, h.token, 'feedmc/33.mp4');
    } catch (_) {}
    let kanalBelge = null;
    try {
      kanalBelge = await belgeYukle(j, h.token, govde.ad);
    } catch (_) {}
    const ekMedya = [kanalVideo, kanalBelge].filter(Boolean);
    for (let i = 0; i < gonderiler.length; i++) {
      const g = await j(`/channels/${kid}/posts`, {
        yontem: 'POST',
        token: h.token,
        govde: {
          metin: gonderiler[i],
          // ⚠️ Once gorseller, sonra video/belge: ilk gonderiler
          //	izgarayi, sondakiler "Belgeler" bolumunu doldurur.
          media_ids: i < kanalGorsel.length
            ? [kanalGorsel[i]]
            : (i - kanalGorsel.length < ekMedya.length
                ? [ekMedya[i - kanalGorsel.length]]
                : []),
        },
      });
      if (g.kod === 201 || g.kod === 200) {
        ozet.toplulukGonderi++;
        // ⚠️⚠️⚠️ TURU 180z — KANAL GONDERILERI **BEGENILIR** (kullanici
        //	emri: *"kanal olsun icinde bir suru gonderi, bu gonderiler
        //	BEGENILSIN"*). Begenisiz bir kanalda kalp DAIMA bos ve sayac
        //	0 kalir; begeni yolu (POST /channel-posts/{id}/like) cihazda
        //	HIC sinanmazdi.
        // ⚠️ Begeni KARSI TARAFTAN gelir: kendi gonderisini begenmek
        //	sayaci artirir ama 'baskasi begendi' gorunumunu VERMEZ.
        //	Her gonderiyi degil, DEGISKEN sayida begeni: hepsi ayni sayida
        //	olsaydi sahte bir duzen izlenimi olurdu.
        const pid = g.d && g.d.id;
        if (pid) {
          const begenenler = [];
          if (i % 2 === 0) begenenler.push(A);
          if (i % 3 === 0) begenenler.push(B);
          if (C && i % 4 === 0) begenenler.push(C);
          for (const bh of begenenler) {
            if (bh.id === h.id) continue;
            // ⚠️⚠️⚠️ BEGENI ICIN **ABONELIK ZORUNLU** (kod okundu:
            //	`channel_subscribers` EXISTS kapisi, degilse **403**).
            //	Abone edilmeseydi TUM begeniler sessizce duserdi ve
            //	kanalda kalpler yine BOS kalirdi.
            //	⚠️ Idempotent: zaten aboneyse ikinci cagri zarar vermez.
            await j(`/channels/${kid}/subscribe`, {
              yontem: 'POST', token: bh.token,
            }).catch(() => {});
            const be = await j(`/channel-posts/${pid}/like`, {
              yontem: 'POST', token: bh.token,
            });
            if (be.kod === 200 || be.kod === 201) {
              ozet.toplulukBegeni = (ozet.toplulukBegeni || 0) + 1;
            }
          }
        }
      }
    }
  }

  return ozet;
}

module.exports = { sosyalTohum, gorselYukle, videoYukle, belgeYukle };
