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

  // ⚠️⚠️ ISLETME LISTESI **ADMIN UCUNDAN** kesfedilir (turu 181).
  //
  //	Elle telefon listesi istemek, `tohum.js` her kosuldugunda listenin
  //	geride kalmasi demekti. Admin ucu (`/admin/isletmeler`) telefonu
  //	DA donduruyor.
  //
  // ⚠️ Yazma ISLETMENIN KENDI HESABIYLA yapilir, admin ucuyla DEGIL:
  //	medya sahipligi kapisi (`media_assets.owner_id`) o hesabi bekliyor;
  //	admin adina yuklenen bir medya urune baglanamazdi.
  const anahtar = process.env.ADMIN_KEY || '';
  let telefonlar = (process.env.TOHUM_TELEFONLAR || '').split(',')
    .map((s) => s.trim()).filter(Boolean);

  if (!telefonlar.length) {
    if (!anahtar) {
      console.log(
        'ADMIN_KEY ya da TOHUM_TELEFONLAR gerekli.\n' +
        '  ADMIN_KEY=... node tools/urun_gorsel.js        (otomatik kesif)\n' +
        '  TOHUM_TELEFONLAR="+905...,+905..." node tools/urun_gorsel.js');
      process.exit(1);
    }
    const l = await jsonIstek('/admin/isletmeler?limit=200&key=' +
      encodeURIComponent(anahtar));
    if (l.kod !== 200) {
      console.log('admin isletme listesi ' + l.kod + ': ' + l.ham.slice(0, 160));
      process.exit(1);
    }
    telefonlar = (l.d || []).filter((f) => f.urun_sayisi > 0).map((f) => f.phone);
    console.log('kesfedilen (urunu olan) isletme: ' + telefonlar.length);
  }

  let toplamUrun = 0, yuklenen = 0, atlanan = 0, hata = 0, atlananHesap = 0;

  for (const tel of telefonlar) {
    const giris = await jsonIstek('/auth/login', {
      yontem: 'POST', govde: { phone: tel, password: SIFRE },
    });
    if (giris.kod !== 200) {
      // ⚠️ Giris yapilamayan hesap bir HATA DEGIL, ATLAMADIR: listede
      //	tohumla acilmamis GERCEK kullanici hesaplari da olabilir
      //	(olculdu: canlida bir tanesi var). Hata sayilsaydi betik
      //	her kosuda cikis kodu 1 dondurur ve "bozuk" gorunurdu.
      console.log('  ATLA ' + tel + ' -> giris ' + giris.kod +
                  ' (tohum hesabi degil)');
      atlananHesap++;
      continue;
    }
    const token = giris.d.token;
    const benID = giris.d.user_id || (giris.d.user && giris.d.user.id);

    const liste = await jsonIstek('/users/' + benID + '/urunler', { token });
    if (liste.kod !== 200) {
      console.log('  ATLA ' + tel + ' -> urun listesi ' + liste.kod);
      atlananHesap++;
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
        // ⚠️⚠️ **METIN TOHUM ILK YAZIMDA PATLIYORDU** (turu 181, 45/45 urun):
        //	`kapakUret` govdesinde `tohum % PALET.length` var; metin
        //	gecince NaN olup `PALET[NaN]` **undefined** donuyor ve
        //	destructure "undefined is not iterable" ile patliyordu.
        //	Koruma artik CAGRI YERINDE DEGIL **URETECIN ICINDE**
        //	(`tohumSayi`, FNV-1a) — bkz. `tools/kapak_uret.js`.
        // ⚠️ Ayni turda uretecin **desen korelasyonu** da kirildi: palet ve
        //	serit ikisi de tohumdan tureyip `n%6 -> n%3` bagintisi yuzunden
        //	ayni palete dusen HER ad BIREBIR ayni bayti veriyordu (olculdu:
        //	18 ad -> 6 gorsel). Menu seridi ayni isletmenin urunlerini YAN
        //	YANA cizdigi icin bu "hepsi ayni resim" demekti. Simdi 18 -> 15.
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
              '   atlanan(zaten var/kaldirilmis): ' + atlanan +
              '   atlanan hesap: ' + atlananHesap + '   hata: ' + hata);
  process.exit(hata ? 1 : 0);
})();
