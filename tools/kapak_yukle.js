// McDonald's isletmesinin KAPAK SLIDERINI doldurur (turu 180k).
//
// Kullanici emri: *"McDonald's isletmesinin header'ina videoh.mp4 koy, header
// slider tarzi; ILK bu video gelsin, 15-20 saniye sonra degissin"*.
//
// ⚠️⚠️ **BUILD GEREKTIRMEZ mi? HAYIR — BU SEFER GEREKIYOR.** `feed_yukle.js`
//	yalnizca veri yaziyordu ve istemci onu ZATEN cizebiliyordu. Kapak
//	slideri ise YENI bir sunucu alani (`isletmeler.kapak_medyalari`,
//	migration 051) ve YENI bir istemci bileseni (`KapakSlider`) ister.
//	Yani: migration + deploy + bu betik + YENI BUILD.
//
// ⚠️ Medya API'DEN GECMEZ (turu 75 mimarisi): presign -> R2'ye DOGRUDAN PUT ->
//	commit. `Content-MD5` imzaya dahildir (turu 74b).
// ⚠️ Poster karesi ZORUNLU (turu 180h): videonun `thumb_url`u bos kalirsa
//	kapak, video hazir olana kadar KOYU BIR KUTU gorunur.
// ⚠️ Olculer ffprobe ile GERCEKTEN olculur (turu 81).
//
// Kullanim: node tools/kapak_yukle.js [--kuru]
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

const API = process.env.API_URL || 'https://api.gebzem.app';
const TEL = '+905551070001'; // McDonald's (tools/tohum.js)
const SIFRE = 'Gebzem2026!';
const KOK = path.join(__dirname, '..');
const KURU = process.argv.includes('--kuru');

// ⚠️ SIRA ONEMLI: kullanici *"ILK bu video gelsin"* dedi. Slider bu diziyi
//    OLDUGU GIBI kullanir (`kapak_medyalari[0]` ilk slayt).
// ⚠️ Ikinci slayt magaza fotografi: tek slaytta `KapakSlider` zamanlayici
//    KURMAZ, yani "15-20 saniye sonra degissin" istegi YERINE GELMEZDI.
const SLAYTLAR = [
  { dosya: 'videoh.mp4', tur: 'video' },
  { dosya: 'slidermc.png', tur: 'foto' },
];

const FFPROBE = [
  process.env.FFPROBE,
  process.env.LOCALAPPDATA &&
    path.join(process.env.LOCALAPPDATA,
      'Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe',
      'ffmpeg-8.1.1-full_build/bin/ffprobe.exe'),
  'ffprobe',
].filter(Boolean).find((p) => {
  try { execFileSync(p, ['-version'], { stdio: 'ignore' }); return true; } catch { return false; }
});
const FFMPEG = FFPROBE
  ? FFPROBE.replace(/ffprobe(\.exe)?$/, (m) => m.replace('probe', 'mpeg'))
  : 'ffmpeg';

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

function posterUret(dosya, sureMs) {
  const cikti = path.join(require('os').tmpdir(),
    'gbz_kapak_' + path.basename(dosya).replace(/\W/g, '_') + '.jpg');
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

// ⚠️⚠️ PNG -> JPEG: ham `slidermc.png` **3,0 MB**. Kapak slaytinda kayipsiz
//	PNG'nin hicbir faydasi yok; turu 178'de ayni dosya icin 1200x800 JPEG
//	uretilmisti (368 KB). Burada da ayni is yapiliyor ki kapak mobil agda
//	saniyelerce yuklenmesin.
function jpegeCevir(yol) {
  const cikti = path.join(require('os').tmpdir(),
    'gbz_kapak_' + path.basename(yol).replace(/\W/g, '_') + '.jpg');
  execFileSync(FFMPEG, [
    '-v', 'error', '-y', '-i', yol,
    '-vf', 'scale=1440:-2', '-q:v', '4', cikti,
  ]);
  return cikti;
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

async function medyaYukle(token, yol, tur) {
  let gercekYol = yol;
  let gecici = null;
  if (tur === 'foto' && /\.png$/i.test(yol)) {
    gecici = jpegeCevir(yol);
    gercekYol = gecici;
  }
  const bayt = fs.readFileSync(gercekYol);
  const md5 = crypto.createHash('md5').update(bayt).digest('base64');
  const mime = tur === 'video' ? 'video/mp4' : 'image/jpeg';
  const { w, h, sureMs } = olc(gercekYol);

  const poster = tur === 'video' ? posterUret(gercekYol, sureMs) : null;
  const posterMd5 = poster
    ? crypto.createHash('md5').update(poster).digest('base64') : '';

  const p = await jsonIstek('/media/upload', {
    yontem: 'POST', token,
    govde: {
      // ⚠️⚠️ `kind` **`kapak` DEGIL**: turu 78'de `media_assets.kind` CHECK'i
      //	`'kapak'` icin acilmisti ama o, `users.kapak_media_id` (TEK
      //	kapak) yolu icin. Slider medyasi `image`/`video` olarak
      //	yuklenir ki `media.erisebilir()` icindeki MEVCUT dallar
      //	(gonderi/urun medyasi) onu ZATEN kapsasin — yeni bir kind
      //	yeni bir erisim dali gerektirirdi ve o dal unutuldugunda
      //	**yukleyenden baska HERKESE 403** donerdi (turu 75b/77/78'de
      //	DORT kez sahaya cikan sinif).
      kind: tur === 'video' ? 'video' : 'image',
      mime, bytes: bayt.length, md5,
      file_name: path.basename(gercekYol),
      width: w, height: h,
      thumb_bytes: poster ? poster.length : 0,
      thumb_md5: posterMd5,
      duration_ms: tur === 'video' ? sureMs : 0,
    },
  });
  if (p.kod !== 200) throw new Error(`presign ${p.kod}: ${p.ham.slice(0, 200)}`);

  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': mime, 'Content-MD5': md5 },
    body: bayt,
  });
  if (!put.ok) throw new Error(`R2 PUT ${put.status}: ${(await put.text()).slice(0, 200)}`);

  if (poster && p.d.thumb_url) {
    const tp = await fetch(p.d.thumb_url, {
      method: 'PUT',
      headers: { 'Content-Type': 'image/jpeg', 'Content-MD5': posterMd5 },
      body: poster,
    });
    if (!tp.ok) throw new Error(`poster PUT ${tp.status}: ${(await tp.text()).slice(0, 200)}`);
  }

  const c = await jsonIstek(`/media/${p.d.media_id}/commit`, { yontem: 'POST', token });
  if (c.kod !== 200) throw new Error(`commit ${c.kod}: ${c.ham.slice(0, 200)}`);
  if (gecici) fs.unlinkSync(gecici);
  return { id: p.d.media_id, w, h, sureMs, bayt: bayt.length };
}

(async () => {
  const giris = await jsonIstek('/auth/login', {
    yontem: 'POST', govde: { phone: TEL, password: SIFRE },
  });
  if (giris.kod !== 200) {
    console.error(`giris ${giris.kod}: ${giris.ham.slice(0, 200)}`);
    process.exit(1);
  }
  const token = giris.d.token;
  // ⚠️ Login yaniti `{token, user_id}` doner (`user:{id}` DEGIL — olculdu).
  const benim = giris.d.user_id;
  console.log(`giris OK (${benim})`);

  // ⚠️⚠️ MEVCUT ISLETME BILGISI **ONCE OKUNUR** ve PUT'a AYNEN geri gonderilir.
  //	`PUT /users/me/isletme` bir UPSERT ve `kategori/adres/il/ilce/
  //	telefon/web/calisma` alanlarini KOSULSUZ `EXCLUDED` ile yaziyor
  //	(bkz. handler.go). Yalnizca `kapak_medyalari` gonderirsek adres,
  //	telefon ve 7 gunluk calisma saatleri **BOSA CEKILIR** — turu 77b'de
  //	sahada yasanan veri kaybinin ta kendisi.
  const mevcut = await jsonIstek(`/users/${benim}/isletme`, { token });
  if (mevcut.kod !== 200) {
    console.error(`isletme detayi ${mevcut.kod}: ${mevcut.ham.slice(0, 200)}`);
    process.exit(1);
  }
  const i = mevcut.d;
  console.log(`mevcut: kategori=${i.kategori} adres=${(i.adres || '').slice(0, 40)} ` +
    `calisma=${(i.calisma || []).length} gun slider=${(i.kapak_medyalari || []).length}`);

  if (KURU) {
    console.log('KURU CALISMA — hicbir sey yuklenmedi.');
    for (const s of SLAYTLAR) {
      const yol = path.join(KOK, s.dosya);
      console.log(`  ${s.dosya}: ${fs.existsSync(yol) ? olc(yol).w + 'x' + olc(yol).h : 'DOSYA YOK'}`);
    }
    return;
  }

  const idler = [];
  for (const s of SLAYTLAR) {
    const yol = path.join(KOK, s.dosya);
    if (!fs.existsSync(yol)) throw new Error('dosya yok: ' + yol);
    const m = await medyaYukle(token, yol, s.tur);
    idler.push(m.id);
    console.log(`  ${s.dosya} -> ${m.id} (${m.w}x${m.h}, ${(m.bayt / 1024 / 1024).toFixed(2)} MB` +
      (s.tur === 'video' ? `, ${(m.sureMs / 1000).toFixed(1)} sn)` : ')'));
  }

  const kayit = await jsonIstek('/users/me/isletme', {
    yontem: 'PUT', token,
    govde: {
      kategori: i.kategori, adres: i.adres, il: i.il, ilce: i.ilce,
      telefon: i.telefon, web: i.web, calisma: i.calisma,
      ozellikler: i.ozellikler, odeme: i.odeme,
      // ⚠️ enlem/boylam ISARETCI: gonderilmezse sunucu MEVCUDU KORUR
      //    (turu 85b). Buraya 0 yazmak konumu SILERDI.
      kapak_medyalari: idler,
    },
  });
  if (kayit.kod !== 200) throw new Error(`kaydet ${kayit.kod}: ${kayit.ham.slice(0, 200)}`);

  const son = await jsonIstek(`/users/${benim}/isletme`, { token });
  const sl = son.d.kapak_medyalari || [];
  const tr = son.d.kapak_turleri || [];
  console.log(`\nSLIDER: ${sl.length} slayt`);
  sl.forEach((id, k) => console.log(`  ${k + 1}. ${id}  [${tr[k] || '?'}]`));
  // ⚠️ Veri kaybi KONTROLU: PUT sonrasi adres/calisma yerinde mi?
  console.log(`adres=${(son.d.adres || '').slice(0, 40)} calisma=${(son.d.calisma || []).length} gun`);
  if (!son.d.adres || (son.d.calisma || []).length === 0) {
    console.error('⚠️ VERI KAYBI: adres ya da calisma saatleri BOSALDI!');
    process.exit(1);
  }
})().catch((e) => { console.error('HATA:', e.message); process.exit(1); });
