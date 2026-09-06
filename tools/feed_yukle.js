// feedmc/ altindaki fotograf ve videolari McDonald's hesabina GONDERI olarak yukler.
//
// ⚠️⚠️ **BUILD GEREKTIRMEZ**: medya ve gonderi tamamen SUNUCU tarafinda yasar;
//	uygulama onlari acilista ceker. Kullanici emri: *"bunlari build
//	almadan yukleyebilir misin?"*
//
// ⚠️ Medya API'DEN GECMEZ (turu 75 mimarisi): presign -> R2'ye DOGRUDAN PUT ->
//	commit. Sunucu yalnizca imza uretir ve sonunda dosyanin GERCEK tipini
//	kokleyip dogrular.
// ⚠️ `Content-MD5` IMZAYA DAHIL: base64 md5 gonderilmezse R2 403/BadDigest
//	doner (turu 74b guvenlik karari).
// ⚠️ Olculer ffprobe ile GERCEKTEN olculur: `media_boyut` akis kartinin
//	en-boyunu suruyor (turu 81) ve 0x0 gonderirsek kart yanlis oranda cizilir.
//
// Kullanim: node tools/feed_yukle.js [--kuru]
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

const API = process.env.API_URL || 'https://api.gebzem.app';
const TEL = '+905551070001'; // McDonald's (tools/tohum.js)
const SIFRE = 'Gebzem2026!';
const DIZIN = path.join(__dirname, '..', 'feedmc');
const KURU = process.argv.includes('--kuru');

const FFPROBE = process.env.FFPROBE || [
  process.env.LOCALAPPDATA &&
    path.join(process.env.LOCALAPPDATA,
      'Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe',
      'ffmpeg-8.1.1-full_build/bin/ffprobe.exe'),
  'ffprobe',
].filter(Boolean).find((p) => { try { execFileSync(p, ['-version'], { stdio: 'ignore' }); return true; } catch { return false; } });

const FFMPEG = FFPROBE
    ? FFPROBE.replace(/ffprobe(\.exe)?$/, (m) => m.replace('probe', 'mpeg'))
    : 'ffmpeg';

// ⚠️ Olcu ALINAMAZSA dosya ATLANIR, 0x0 ile YUKLENMEZ: yanlis en-boy akista
//    kirpilmis/gerilmis bir kart demek ve sonradan duzeltmek icin medyayi
//    yeniden yuklemek gerekir.
function olc(dosya) {
  if (!FFPROBE) throw new Error('ffprobe bulunamadi');
  const c = execFileSync(FFPROBE, [
    '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height', '-show_entries', 'format=duration',
    '-of', 'csv=p=0:s=x', dosya,
  ]).toString().trim().split('\n');
  const [w, h] = c[0].split('x').map(Number);
  const sure = Number(c[1] || 0);
  if (!w || !h) throw new Error('olcu okunamadi: ' + dosya);
  return { w, h, sureMs: Math.round(sure * 1000) };
}

// ⚠️⚠️ TURU 180h — **VIDEO POSTER KARESI** (kullanici: *"videolarin ON
//	IZLEME RESMI GORUNMUYOR"*).
//
//	Istemci ZATEN dogru calisiyordu: `MedyaVideo` kapak olarak
//	videonun KENDI `thumb_url`unu istiyor (turu 76). Eksik olan
//	sunucudaki kucuk resimdi — ilk yuklemede `thumb_bytes`
//	gonderilmemisti, `thumb_url` bos donuyor ve kapak koyu bir
//	kutuya dusuyordu.
// ⚠️ Kare **1. saniyeden** alinir: 0. saniye cogu videoda siyah/gecis
//	karesidir. Video 1 sn'den kisaysa basa duseriz.
// ⚠️ JPEG kalite 4 (~0-31 olcegi, kucuk daha iyi): thumb tavani var
//	(ThumbTavan) ve poster yalnizca kart kapagi olarak cizilir.
function posterUret(dosya, sureMs) {
  const cikti = path.join(require('os').tmpdir(),
    'gbz_poster_' + path.basename(dosya).replace(/\W/g, '_') + '.jpg');
  const an = sureMs > 1500 ? '1' : '0';
  execFileSync(FFMPEG, [
    '-v', 'error', '-y', '-ss', an, '-i', dosya,
    '-frames:v', '1', '-q:v', '4', cikti,
  ]);
  const b = fs.readFileSync(cikti);
  fs.unlinkSync(cikti);
  if (!b.length) throw new Error('poster uretilemedi: ' + dosya);
  return b;
}

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

async function medyaYukle(token, dosya, tur) {
  const yol = path.join(DIZIN, dosya);
  const bayt = fs.readFileSync(yol);
  const md5 = crypto.createHash('md5').update(bayt).digest('base64');
  const mime = tur === 'video' ? 'video/mp4' : 'image/jpeg';
  const { w, h, sureMs } = olc(yol);

  // ⚠️ Poster YALNIZ videoda: fotografin kendisi zaten kapaktir.
  const poster = tur === 'video' ? posterUret(yol, sureMs) : null;
  const posterMd5 = poster ? crypto.createHash('md5').update(poster).digest('base64') : '';

  const p = await jsonIstek('/media/upload', {
    yontem: 'POST', token,
    govde: {
      kind: tur, mime, bytes: bayt.length, md5, file_name: dosya,
      width: w, height: h,
      thumb_bytes: poster ? poster.length : 0,
      thumb_md5: posterMd5,
      // ⚠️ Sure YALNIZ videoda: fotografta ffprobe 0.04 gibi anlamsiz bir
      //    deger donduruyor (tek karelik "sure").
      duration_ms: tur === 'video' ? sureMs : 0,
    },
  });
  if (p.kod !== 200) throw new Error(`presign ${p.kod}: ${p.ham.slice(0, 160)}`);

  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': mime, 'Content-MD5': md5 },
    body: bayt,
  });
  if (!put.ok) throw new Error(`R2 PUT ${put.status}: ${(await put.text()).slice(0, 160)}`);

  // ⚠️⚠️ Poster COMMIT'TEN ONCE yuklenir: commit yalnizca ASIL nesneyi
  //	dogrular ama imzali thumb adresi presign suresiyle sinirli.
  //	Sonraya birakilirsa yavas bir agda sure dolabilir ve medya
  //	POSTERSIZ kalir (sonradan eklemenin yolu YOK — thumb anahtari
  //	presign aninda uretiliyor).
  if (poster && p.d.thumb_url) {
    const tp = await fetch(p.d.thumb_url, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': posterMd5 },
      body: poster,
    });
    if (!tp.ok) throw new Error(`poster PUT ${tp.status}: ${(await tp.text()).slice(0, 160)}`);
  }

  const c = await jsonIstek(`/media/${p.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) throw new Error(`commit ${c.kod}: ${c.ham.slice(0, 160)}`);
  return { id: p.d.media_id, w, h, sureMs, bayt: bayt.length, poster: poster ? poster.length : 0 };
}

// ⚠️ Metinler McDonald's'in KENDI menusunden ve tohum verisinden turetildi;
//    uydurma bir kampanya/fiyat YAZILMADI (proje kurali).
const GONDERILER = [
  { tur: 'foto',  dosyalar: ['1.jpg', '2.jpg', '3.jpg'],
    metin: 'Gebze Merkez şubemizden kareler. Menülerimiz her gün taze.' },
  { tur: 'foto',  dosyalar: ['4.jpg'],
    metin: 'Big Mac — efsane tarif, hiç değişmedi.' },
  { tur: 'foto',  dosyalar: ['5.jpg', '6.jpg'],
    metin: 'Tatlı bölümümüz: McFlurry ve sıcak elmalı turta.' },
  { tur: 'video', dosyalar: ['11.mp4'], metin: 'Mutfakta bir gün.' },
  { tur: 'reels', dosyalar: ['22.mp4'], metin: 'Cheeseburger nasıl hazırlanıyor?' },
  { tur: 'reels', dosyalar: ['33.mp4'], metin: 'Patateslerimiz sıcacık servis edilir.' },
  { tur: 'video', dosyalar: ['44.mp4'], metin: 'Gebze şubemize hoş geldiniz.' },
  { tur: 'reels', dosyalar: ['55.mp4'], metin: 'McMenü hazırlanıyor.' },
  { tur: 'video', dosyalar: ['66.mp4'], metin: 'Serpme değil, klasik kahvaltı bizde yok — ama McMuffin var.' },
];

(async () => {
  console.log('ffprobe:', FFPROBE ? 'VAR' : 'YOK');
  const g = await jsonIstek('/auth/login', {
    yontem: 'POST', govde: { phone: TEL, password: SIFRE },
  });
  if (g.kod !== 200 || !g.d?.token) {
    throw new Error(`login ${g.kod}: ${g.ham.slice(0, 200)}`);
  }
  const token = g.d.token;
  console.log('giris OK — McDonald\'s');

  // ⚠️ Once TUM olculer alinir: bir dosya bozuksa HICBIR SEY yuklenmeden dururuz
  //    (yarim yuklenmis medya R2'de YETIM kalirdi).
  for (const p of GONDERILER) {
    for (const d of p.dosyalar) {
      const o = olc(path.join(DIZIN, d));
      console.log(`  olcu ${d}: ${o.w}x${o.h}` + (o.sureMs > 100 ? ` ${(o.sureMs / 1000).toFixed(1)}s` : ''));
    }
  }
  if (KURU) { console.log('KURU CALISMA — yukleme yapilmadi'); return; }

  let n = 0;
  for (const p of GONDERILER) {
    const ids = [];
    for (const d of p.dosyalar) {
      const tur = d.endsWith('.mp4') ? 'video' : 'image';
      const m = await medyaYukle(token, d, tur);
      ids.push(m.id);
      console.log(`  yuklendi ${d} -> ${m.id} (${(m.bayt / 1048576).toFixed(2)} MB` +
        (m.poster ? `, poster ${(m.poster / 1024).toFixed(0)} KB)` : ')'));
    }
    const r = await jsonIstek('/posts', {
      yontem: 'POST', token,
      govde: { tur: p.tur, metin: p.metin, media_ids: ids },
    });
    if (r.kod !== 201 && r.kod !== 200) {
      throw new Error(`gonderi ${r.kod}: ${r.ham.slice(0, 200)}`);
    }
    n++;
    console.log(`GONDERI ${n}/${GONDERILER.length} [${p.tur}] ${p.metin.slice(0, 40)}…`);
  }
  console.log(`\nTAMAM — ${n} gonderi olusturuldu.`);
})().catch((e) => { console.error('HATA:', e.message); process.exit(1); });
