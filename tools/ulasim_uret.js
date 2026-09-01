// ⚠️⚠️⚠️ GTFS -> UYGULAMA VARLIGI URETICISI (turu 149)
//
// Kaynak: `otos/otobus/` (KentKart Kocaeli GTFS) + `otos/taksi/`
// Hedef : `mobile/assets/ulasim/`
//
// ⚠️ NEDEN ISTEMCI VARLIGI, BACKEND DEGIL:
//	Gebze bolgesinin TAMAMI (2033 durak · 108 hat · 208 guzergah ·
//	800 bin kalkis) sikistirilmis olarak ~1 MB. Bu veri GUNLUK DEGISMEZ
//	(GTFS takvimi 2100'e kadar gecerli), yani her acilista sunucuya
//	sormanin bir karsiligi yok. Varlik olarak paketlenince:
//	  · fatura YOK, sunucu yuku YOK,
//	  · CEVRIMDISI calisir,
//	  · durak/hat/saat aninda gelir (ag beklemesi yok).
//	⚠️ Sefer saatleri guncellenirse bu betik yeniden kosulur ve YENI
//	   SURUM cikilir; ara guncelleme icin ileride bir uc eklenebilir.
//
// ⚠️ BOLGE KUTUSU: tum Kocaeli 8511 durak; uygulama Gebze odakli oldugu
//    icin yalniz Gebze/Darica/Cayirova/Dilovasi kutusu aliniyor.
//    Genisletmek icin `KUTU`yu buyut ve betigi yeniden kostur.
const fs = require('fs');
const path = require('path');
const rl = require('readline');

const KAYNAK = 'otos/otobus/';
const TAKSI_JSON = 'otos/taksi/taksi_duraklar.json';
const HEDEF = 'mobile/assets/ulasim/';

const KUTU = { g: 40.72, k: 40.90, b: 29.28, d: 29.60 };

// ─────────────────────────────────────────────────────────────────────
// Yardimcilar
// ─────────────────────────────────────────────────────────────────────
function satirlar(dosya) {
  return rl.createInterface({
    input: fs.createReadStream(dosya),
    crlfDelay: Infinity,
  });
}

/// GTFS alanlarini ayirir (tirnak icindeki virgulu KORUR).
function ayir(s) {
  const c = [];
  let cur = '';
  let tir = false;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch === '"') { tir = !tir; continue; }
    if (ch === ',' && !tir) { c.push(cur); cur = ''; continue; }
    cur += ch;
  }
  c.push(cur);
  return c;
}

/// Google "encoded polyline" varint kodlamasi (tek sayi).
/// ⚠️ Hem koordinat hem DAKIKA farklari icin kullaniliyor: ikisi de
///    kucuk tam sayi dizisi ve bu kodlama onlari ~1 karaktere indiriyor.
function varint(sayi) {
  let v = sayi < 0 ? ~(sayi << 1) : (sayi << 1);
  let s = '';
  while (v >= 0x20) {
    s += String.fromCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  s += String.fromCharCode(v + 63);
  return s;
}

/// Nokta dizisini encoded polyline'a cevirir (1e5 hassasiyet).
function polyKodla(noktalar) {
  let s = '';
  let sonLat = 0;
  let sonLon = 0;
  for (const [lat, lon] of noktalar) {
    const la = Math.round(lat * 1e5);
    const lo = Math.round(lon * 1e5);
    s += varint(la - sonLat) + varint(lo - sonLon);
    sonLat = la;
    sonLon = lo;
  }
  return s;
}

/// Artan tam sayi dizisini FARK olarak kodlar.
function dizeKodla(artanDizi) {
  let s = '';
  let onceki = 0;
  for (const d of artanDizi) {
    s += varint(d - onceki);
    onceki = d;
  }
  return s;
}

/// "HH:MM:SS" -> gece yarisindan itibaren DAKIKA.
/// ⚠️ GTFS'te saat 24'u ASABILIR (gece yarisini gecen seferler: "25:10:00").
///    Deger OLDUGU GIBI korunur; istemci 24'u asani "ertesi gun" sayar.
function dakika(hhmmss) {
  const p = hhmmss.split(':');
  if (p.length < 2) return -1;
  const s = parseInt(p[0], 10);
  const d = parseInt(p[1], 10);
  if (!Number.isFinite(s) || !Number.isFinite(d)) return -1;
  return s * 60 + d;
}

// ─────────────────────────────────────────────────────────────────────
// TAKSI: TUREF/TM30 (EPSG:5254) -> WGS84
// ─────────────────────────────────────────────────────────────────────
// ⚠️ Veri ESRI bicimde ve koordinatlar PROJEKSIYONLU (x/y metre).
//    Ters Transverse Mercator ile enlem/boylama cevriliyor.
//    Parametreler: GRS80 · merkez meridyen 30°E · k0=1 · FE=500000 · FN=0
function tm30ToWgs(x, y) {
  const a = 6378137.0;
  const f = 1 / 298.257222101; // GRS80
  const e2 = f * (2 - f);
  const e1 = (1 - Math.sqrt(1 - e2)) / (1 + Math.sqrt(1 - e2));
  const k0 = 1.0;
  const FE = 500000.0;
  const FN = 0.0;
  const lon0 = (30 * Math.PI) / 180;

  const M = (y - FN) / k0;
  const mu = M / (a * (1 - e2 / 4 - (3 * e2 * e2) / 64 - (5 * e2 * e2 * e2) / 256));
  const J1 = (3 * e1) / 2 - (27 * e1 ** 3) / 32;
  const J2 = (21 * e1 ** 2) / 16 - (55 * e1 ** 4) / 32;
  const J3 = (151 * e1 ** 3) / 96;
  const J4 = (1097 * e1 ** 4) / 512;
  const fp = mu + J1 * Math.sin(2 * mu) + J2 * Math.sin(4 * mu) +
    J3 * Math.sin(6 * mu) + J4 * Math.sin(8 * mu);

  const e2p = e2 / (1 - e2);
  const C1 = e2p * Math.cos(fp) ** 2;
  const T1 = Math.tan(fp) ** 2;
  const R1 = (a * (1 - e2)) / (1 - e2 * Math.sin(fp) ** 2) ** 1.5;
  const N1 = a / Math.sqrt(1 - e2 * Math.sin(fp) ** 2);
  const D = (x - FE) / (N1 * k0);

  const Q1 = (N1 * Math.tan(fp)) / R1;
  const Q2 = (D * D) / 2;
  const Q3 = ((5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2p) * D ** 4) / 24;
  const Q4 = ((61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 3 * C1 * C1 - 252 * e2p) * D ** 6) / 720;
  const lat = fp - Q1 * (Q2 - Q3 + Q4);

  const Q5 = D;
  const Q6 = ((1 + 2 * T1 + C1) * D ** 3) / 6;
  const Q7 = ((5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2p + 24 * T1 * T1) * D ** 5) / 120;
  const lon = lon0 + (Q5 - Q6 + Q7) / Math.cos(fp);

  return [(lat * 180) / Math.PI, (lon * 180) / Math.PI];
}

// ─────────────────────────────────────────────────────────────────────
(async () => {
  fs.mkdirSync(HEDEF, { recursive: true });

  // ── 1) DURAKLAR (bolge kutusu) ──
  const durak = new Map(); // stop_id -> {ad, lat, lon}
  let ilk = true;
  for await (const l of satirlar(KAYNAK + 'stops.txt')) {
    if (ilk) { ilk = false; continue; }
    if (!l.trim()) continue;
    const c = ayir(l);
    const lat = parseFloat(c[2]);
    const lon = parseFloat(c[3]);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    if (lat < KUTU.g || lat > KUTU.k || lon < KUTU.b || lon > KUTU.d) continue;
    durak.set(c[0], { ad: c[1].trim(), lat, lon });
  }
  console.log(`durak (bolge): ${durak.size}`);

  // ── 2) HATLAR ──
  const hat = new Map(); // route_id -> {kisa, uzun, renk}
  ilk = true;
  for await (const l of satirlar(KAYNAK + 'routes.txt')) {
    if (ilk) { ilk = false; continue; }
    if (!l.trim()) continue;
    const c = ayir(l);
    hat.set(c[0], {
      kisa: (c[2] || '').trim(),
      uzun: (c[3] || '').trim(),
      tur: c[4],
      renk: (c[6] || '').trim(),
    });
  }

  // ── 3) TRIPS ──
  const trip = new Map(); // trip_id -> {hat, servis, yon, shape, basli}
  ilk = true;
  for await (const l of satirlar(KAYNAK + 'trips.txt')) {
    if (ilk) { ilk = false; continue; }
    if (!l.trim()) continue;
    const c = ayir(l);
    trip.set(c[2], {
      hat: c[0],
      servis: c[1],
      yon: c[3] === '1' ? 1 : 0,
      shape: c[4],
      basli: (c[5] || '').trim(),
    });
  }
  console.log(`trip: ${trip.size}`);

  // ── 4) STOP_TIMES -> durak basina kalkislar ──
  // kalkis[stopId][routeId][servis][yon] = [dakika...]
  const kalkis = new Map();
  const kullanilanHat = new Set();
  const kullanilanShape = new Map(); // "route|yon" -> Map(shapeId -> adet)
  ilk = true;
  let okunan = 0;
  for await (const l of satirlar(KAYNAK + 'stop_times.txt')) {
    if (ilk) { ilk = false; continue; }
    if (!l.trim()) continue;
    okunan++;
    const c = ayir(l);
    const sid = c[3];
    if (!durak.has(sid)) continue;
    const t = trip.get(c[0]);
    if (!t) continue;
    const dk = dakika(c[2] || c[1]);
    if (dk < 0) continue;

    kullanilanHat.add(t.hat);
    const sk = `${t.hat}|${t.yon}`;
    if (t.shape) {
      if (!kullanilanShape.has(sk)) kullanilanShape.set(sk, new Map());
      const m = kullanilanShape.get(sk);
      m.set(t.shape, (m.get(t.shape) || 0) + 1);
    }

    if (!kalkis.has(sid)) kalkis.set(sid, new Map());
    const h = kalkis.get(sid);
    if (!h.has(t.hat)) h.set(t.hat, new Map());
    const sv = h.get(t.hat);
    const anahtar = `${t.servis}|${t.yon}`;
    if (!sv.has(anahtar)) sv.set(anahtar, []);
    sv.get(anahtar).push(dk);
  }
  console.log(`stop_times okunan: ${okunan} · kalkisi olan durak: ${kalkis.size} · hat: ${kullanilanHat.size}`);

  // ── 5) Her (hat,yon) icin EN COK KULLANILAN shape ──
  // ⚠️ Bir hatta birden fazla shape olabilir (sefer varyantlari). En cok
  //    kullanilani "ana guzergah" kabul ediliyor; uydurma degil, veriden.
  const anaShape = new Map(); // "route|yon" -> shapeId
  for (const [sk, m] of kullanilanShape) {
    let enIyi = null;
    let enCok = -1;
    for (const [sid, adet] of m) {
      if (adet > enCok) { enCok = adet; enIyi = sid; }
    }
    if (enIyi) anaShape.set(sk, enIyi);
  }
  const gerekliShape = new Set(anaShape.values());
  console.log(`ana guzergah: ${anaShape.size} · farkli shape: ${gerekliShape.size}`);

  // ── 6) SHAPES ──
  const shapeNokta = new Map(); // shapeId -> [[seq, lat, lon]...]
  ilk = true;
  for await (const l of satirlar(KAYNAK + 'shapes.txt')) {
    if (ilk) { ilk = false; continue; }
    if (!l.trim()) continue;
    const c = ayir(l);
    if (!gerekliShape.has(c[0])) continue;
    const lat = parseFloat(c[1]);
    const lon = parseFloat(c[2]);
    const seq = parseInt(c[3], 10);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    if (!shapeNokta.has(c[0])) shapeNokta.set(c[0], []);
    shapeNokta.get(c[0]).push([seq, lat, lon]);
  }
  const sekiller = {};
  let toplamNokta = 0;
  for (const [sid, arr] of shapeNokta) {
    arr.sort((a, b) => a[0] - b[0]);
    toplamNokta += arr.length;
    sekiller[sid] = polyKodla(arr.map((x) => [x[1], x[2]]));
  }
  console.log(`shape noktasi: ${toplamNokta}`);

  // ── 7) Hat basligi (yon adi) — en sik kullanilan headsign ──
  const basliklar = new Map(); // "route|yon" -> Map(baslik -> adet)
  for (const t of trip.values()) {
    if (!kullanilanHat.has(t.hat)) continue;
    const sk = `${t.hat}|${t.yon}`;
    if (!basliklar.has(sk)) basliklar.set(sk, new Map());
    const m = basliklar.get(sk);
    const b = t.basli || '';
    m.set(b, (m.get(b) || 0) + 1);
  }
  function enSikBaslik(sk) {
    const m = basliklar.get(sk);
    if (!m) return '';
    let e = '';
    let c = -1;
    for (const [b, a] of m) if (a > c) { c = a; e = b; }
    return e;
  }

  // ── 8) YAZ ──
  // duraklar: [id, latE5, lonE5, ad]
  const dOut = [];
  for (const [id, d] of durak) {
    if (!kalkis.has(id)) continue; // sefer ugramayan duragi TASIMA
    dOut.push([id, Math.round(d.lat * 1e5), Math.round(d.lon * 1e5), d.ad]);
  }
  fs.writeFileSync(HEDEF + 'duraklar.json', JSON.stringify({ v: 1, d: dOut }));

  // hatlar: {routeId: {k, u, r, y:{0,1}, s:{0,1}}}
  const hOut = {};
  for (const rid of kullanilanHat) {
    const h = hat.get(rid);
    if (!h) continue;
    const y = {};
    const s = {};
    for (const yon of [0, 1]) {
      const sk = `${rid}|${yon}`;
      const b = enSikBaslik(sk);
      if (b) y[yon] = b;
      const sh = anaShape.get(sk);
      if (sh) s[yon] = sh;
    }
    hOut[rid] = { k: h.kisa, u: h.uzun, r: h.renk, t: h.tur, y, s };
  }
  fs.writeFileSync(HEDEF + 'hatlar.json', JSON.stringify({ v: 1, h: hOut }));

  fs.writeFileSync(HEDEF + 'sekiller.json', JSON.stringify({ v: 1, s: sekiller }));

  // seferler: {stopId: {routeId: {"servis|yon": "kodlanmisDakikalar"}}}
  const sOut = {};
  let kalkisAdet = 0;
  for (const [sid, hm] of kalkis) {
    const o = {};
    for (const [rid, sv] of hm) {
      const p = {};
      for (const [k, dizi] of sv) {
        dizi.sort((a, b) => a - b);
        kalkisAdet += dizi.length;
        p[k] = dizeKodla(dizi);
      }
      o[rid] = p;
    }
    sOut[sid] = o;
  }
  fs.writeFileSync(HEDEF + 'seferler.json', JSON.stringify({ v: 1, k: sOut }));

  // ── 9) TAKSI ──
  const ham = JSON.parse(fs.readFileSync(TAKSI_JSON, 'utf8'));
  const tOut = [];
  for (const f of ham.features || []) {
    const a = f.attributes || {};
    const g = f.geometry || {};
    if (typeof g.x !== 'number' || typeof g.y !== 'number') continue;
    const [lat, lon] = tm30ToWgs(g.x, g.y);
    if (lat < KUTU.g || lat > KUTU.k || lon < KUTU.b || lon > KUTU.d) continue;
    tOut.push([
      Math.round(lat * 1e5),
      Math.round(lon * 1e5),
      (a.adi || '').trim(),
      (a.ILCE_ADI || '').trim(),
      (a.adres || '').trim(),
    ]);
  }
  fs.writeFileSync(HEDEF + 'taksi.json', JSON.stringify({ v: 1, t: tOut }));

  // ── OZET ──
  console.log('--- YAZILDI ---');
  for (const f of ['duraklar', 'hatlar', 'sekiller', 'seferler', 'taksi']) {
    const b = fs.statSync(HEDEF + f + '.json').size;
    console.log(`  ${f}.json  ${(b / 1024).toFixed(0)} KB`);
  }
  console.log(`  durak=${dOut.length} hat=${Object.keys(hOut).length} sekil=${Object.keys(sekiller).length} kalkis=${kalkisAdet} taksi=${tOut.length}`);
})();
