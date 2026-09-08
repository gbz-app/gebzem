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
const path = require('path');
const { kapakUret } = require('./kapak_uret');
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
async function videoYukle(j, token, dosya) {
  let bayt;
  try {
    bayt = fs.readFileSync(dosya);
  } catch (_) {
    return null;
  }
  const md5 = crypto.createHash('md5').update(bayt).digest('base64');
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
    },
  });
  if (pr.kod !== 200) return null;
  const put = await fetch(pr.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'video/mp4', 'Content-MD5': md5 },
    body: bayt,
  });
  if (!put.ok) return null;
  const c = await j(`/media/${pr.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) return null;
  return pr.d.media_id;
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
    etkinlik: (etkinlikler || [])[0] || null,
  };
  const sh = await sohbetTohum(j, A, B, isletmeler || [], sohbetMedya);
  ozet.mesaj += sh.mesaj;
  ozet.sohbet = sh.sohbet;
  ozet.arsiv = sh.arsiv;

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
    ]],
  ];
  ozet.topluluk = 0;
  ozet.toplulukGonderi = 0;
  for (const [h, govde, gonderiler] of TOPLULUKLAR) {
    const k = await j('/channels', { yontem: 'POST', token: h.token, govde });
    // ⚠️ 409 = ad ALINMIS (betik ikinci kez kosuldu). Tohum PATLAMAZ:
    //    diger adimlar calismaya devam etmeli.
    if (k.kod !== 201 && k.kod !== 200) continue;
    const kid = k.d && (k.d.id || k.d.channel_id);
    if (!kid) continue;
    ozet.topluluk++;
    for (const metin of gonderiler) {
      const g = await j(`/channels/${kid}/posts`, {
        yontem: 'POST',
        token: h.token,
        govde: { metin, media_ids: [] },
      });
      if (g.kod === 201 || g.kod === 200) ozet.toplulukGonderi++;
    }
  }

  return ozet;
}

module.exports = { sosyalTohum, gorselYukle, videoYukle };
