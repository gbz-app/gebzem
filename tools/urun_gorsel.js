#!/usr/bin/env node
/* Tohumdaki URUNLERE gorsel ekler — turu 181.
 *
 * ⚠️⚠️⚠️ NEDEN VAR: turu 180ag'de isletme kartinin altina MENU SERIDI kondu
 *	(resim + ad + fiyat). Emulatorde bakildiginda serit calisiyordu ama
 *	TUM gorsel alanlari BOS GRI kutuydu; olculdu:
 *
 *	  McDonald's      -> 18 urun, MEDYALI 0
 *	  Usta Doner&Pide ->  5 urun, MEDYALI 0
 *
 *	Cunku `tools/tohum.js` urunlerin `media_ids` alanini HIC doldurmuyor.
 *	Yani "urun gorseli" yolu (yukle -> liste yaniti -> imzali adres ->
 *	seritte cizim) CIHAZDA HIC SINANMIYORDU. Bu projede "yalnizca ikinci
 *	hesapta gorunen" medya hatalari DORT KEZ sahaya cikti.
 *
 * ⚠️ Uretilen gorsel bir FOTOGRAF DEGIL, urun adindan turetilmis desenli
 *	bir karttir (`kapak_uret.js` ile ayni karar). Sahte yemek fotografi
 *	kullanmak turu 141'de ACIKCA reddedildi: dort McDonald's fotografi
 *	yanlis kalemlere dusuyordu ("Filtre Kahve"nin yaninda PATATES) ve
 *	**YANLIS GORSEL, GORSELSIZDEN KOTUDUR**.
 * ⚠️ AI ile uretmek de reddedildi: PARA harcar, gunluk kotayi yer ve
 *	`/ai/gorsel` `kind='image'` uretse de her urun icin ayri cagri
 *	demektir.
 *
 * ⚠️⚠️ **`UrunGuncelle` ARTIK `media_ids` KABUL EDIYOR** (turu 181).
 *	Once etmiyordu ve `tools/oda_galeri.js` bunu "tek yol urunu kaldir,
 *	yeniden ekle" diye yaziyordu. Bu arac o duzeltmeye BAGLI.
 *
 * KULLANIM:
 *   node tools/urun_gorsel.js                 # canli, tum tohum isletmeleri
 *   node tools/urun_gorsel.js --kuru          # HICBIR SEY YAZMAZ, ne yapacagini soyler
 *   GEBZEM_API=http://localhost:8080 node tools/urun_gorsel.js
 *
 * ⚠️ IDEMPOTENT: `media_ids` DOLU olan urun ATLANIR. Betigi iki kez kosmak
 *	ikinci gorsel eklemez (turu 178'de `tohum.js` urun tarafinda tam bu
 *	yuzden katalogu ciftlemisti).
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const API = process.env.GEBZEM_API || process.env.API_URL || 'https://api.gebzem.app';
const KURU = process.argv.includes('--kuru');

// ⚠️ Tohum hesaplarinin sifresi `tools/tohum.js` ile AYNI olmak ZORUNDA;
//	ayrisirsa bu betik sessizce hicbir isletmeye giremez.
const SIFRE = process.env.TOHUM_SIFRE || 'Gebzem2026!';

const { kapakUret } = require('./kapak_uret.js');

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
  return { w: bayt.readUInt32BE(16), h: bayt.readUInt32BE(20) };
}

async function medyaYukle(token, bayt, ad) {
  const { w, h } = pngOlc(bayt);
  const md5 = crypto.createHash('md5').update(bayt).digest('base64');
  const p = await jsonIstek('/media/upload', {
    yontem: 'POST', token,
    govde: {
      kind: 'image', mime: 'image/png', bytes: bayt.length, md5,
      file_name: ad, width: w, height: h,
      thumb_bytes: 0, thumb_md5: '', duration_ms: 0,
    },
  });
  if (p.kod !== 200) throw new Error('presign ' + p.kod + ': ' + p.ham.slice(0, 160));

  // ⚠️ Medya API'DEN GECMEZ (turu 75): R2'ye DOGRUDAN PUT.
  //	`Content-MD5` imzaya DAHIL (turu 74b) — atlanirsa 403 doner.
  const put = await fetch(p.d.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/png', 'Content-MD5': md5 },
    body: bayt,
  });
  if (!put.ok) throw new Error('R2 PUT ' + put.status);

  const c = await jsonIstek('/media/' + p.d.media_id + '/commit', { yontem: 'POST', token });
  if (c.kod !== 200) throw new Error('commit ' + c.kod + ': ' + c.ham.slice(0, 160));
  return p.d.media_id;
}

(async () => {
  console.log('API: ' + API + (KURU ? '   [KURU CALISMA — hicbir sey yazilmaz]' : ''));

  // Tohum hesaplarini `tohum.js`in bastigi tablodan degil, SUNUCUDAN al:
  // hangi isletmelerin urunu oldugunu ancak sunucu bilir.
  // ⚠️ Admin ucu KULLANILMAZ: bu betik urunlere kullanicinin KENDI
  //	hesabiyla yaziyor (medya sahipligi kapisi o hesabi bekliyor).
  const telefonlar = (process.env.TOHUM_TELEFONLAR || '').split(',')
    .map((s) => s.trim()).filter(Boolean);

  if (!telefonlar.length) {
    console.log(
      'TOHUM_TELEFONLAR bos.\n' +
      'Kullanim: TOHUM_TELEFONLAR="+905551010001,+905551010002" node tools/urun_gorsel.js\n' +
      'Telefonlar `node tools/tohum.js` ciktisindaki tabloda.');
    process.exit(1);
  }

  let toplamUrun = 0, yuklenen = 0, atlanan = 0, hata = 0;

  for (const tel of telefonlar) {
    const giris = await jsonIstek('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: SIFRE },
    });
    if (giris.kod !== 200) {
      console.log('  ATLA ' + tel + ' -> giris ' + giris.kod);
      hata++;
      continue;
    }
    const token = giris.d.token;
    const benID = giris.d.user_id || (giris.d.user && giris.d.user.id);

    const liste = await jsonIstek('/users/' + benID + '/urunler', { token });
    if (liste.kod !== 200) {
      console.log('  ATLA ' + tel + ' -> urun listesi ' + liste.kod);
      hata++;
      continue;
    }
    const urunler = (liste.d && liste.d.urunler) || [];
    const ad = tel;
    console.log('\n' + ad + ' -> ' + urunler.length + ' urun');

    for (const u of urunler) {
      toplamUrun++;
      if (u.durum === 'kaldirildi') { atlanan++; continue; }
      // ⚠️ IDEMPOTENT KAPISI: gorseli OLAN urune DOKUNMA.
      if ((u.media_ids || []).length > 0) {
        atlanan++;
        continue;
      }
      if (KURU) {
        console.log('  [kuru] ' + u.ad + ' -> gorsel EKLENECEK');
        yuklenen++;
        continue;
      }
      try {
        // ⚠️ Tohum urun ADI: ayni ad DAIMA ayni deseni uretir (deterministik),
        //	yani betik iki kez kossa bile gorsel "degismis" gorunmez.
        // ⚠️ 4:3 — menu seridi `kMenuGorselBoy = kMenuOgeEn * 3 / 4` ile
        //	AYNI orani cizer; farkli oran `BoxFit.cover` ile KIRPILIRDI.
        const png = kapakUret(u.ad, 800, 600);
        const mid = await medyaYukle(token, png, 'urun.png');
        const g = await jsonIstek('/isletme/urunler/' + u.id, {
          yontem: 'PATCH', token, govde: { media_ids: [mid] },
        });
        if (g.kod !== 200) throw new Error('PATCH ' + g.kod + ': ' + g.ham.slice(0, 120));
        console.log('  OK   ' + u.ad);
        yuklenen++;
      } catch (e) {
        console.log('  HATA ' + u.ad + ' -> ' + e.message);
        hata++;
      }
    }
  }

  console.log('\n════════════════════════════════');
  console.log('urun: ' + toplamUrun + '   yuklenen: ' + yuklenen +
              '   atlanan(zaten var/kaldirilmis): ' + atlanan + '   hata: ' + hata);
  process.exit(hata ? 1 : 0);
})();
