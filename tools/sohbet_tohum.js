// ═══════════════ ZENGIN SOHBET TOHUMU (turu 180y) ═══════════════
//
// Kullanici emri: *"5-6 tane mesaj olsun, sanki karsilikli konusmusuz gibi;
// resim, video, etkinlik, konum, tek kullanimlik mesajlar atilmis gibi;
// toplulukta bir cok mesaj atilmis gibi; okunmamis, arsivde mesaj — sohbet
// detaylarini test edeyim"*.
//
// ⚠️⚠️ **BACKEND DEGISMEDI.** Her sey MEVCUT uclarla yaziliyor:
//	`POST /chats/direct` · `POST /chats/{id}/messages` (type beyaz listesi:
//	text·image·video·audio·location·document·contact·iban·etkinlik) ·
//	`POST /chats/{id}/read` · `PATCH /chats/{id}` {archived}.
//
// ⚠️⚠️ **"TEK KULLANIMLIK" SUNUCUDA YOKTUR.** Boyle bir mesaj tipi ya da
//	bayragi yok (beyaz liste yukarida). Prototipte gorulebilmesi icin
//	`image` mesajinin ALTYAZISINA `kTekIsaret` isaretcisi konuyor ve
//	istemci o balonu "tek kullanimlik" olarak ciziyor.
//	⏳ GERCEK cozum: `messages`a bir `tek_kullanimlik BOOLEAN` sutunu +
//	   goruntulendikten sonra icerigi bosaltan bir uc. AYRI (backend) TUR.
'use strict';

const fs = require('fs');
const path = require('path');

/// Istemcinin tanidigi isaretci — `mobile/lib/features/chats/models.dart`
/// icindeki `kTekKullanimlikIsaret` ile **BIREBIR AYNI** olmali.
const kTekIsaret = '[1x]';

/// Konum icerigi "enlem,boylam" DUZ METIN (bkz. `KonumServisi` serhi).
const kGebze = '40.8028,29.4307';

async function mesaj(j, cid, h, govde, ozet) {
  const r = await j(`/chats/${cid}/messages`, {
    yontem: 'POST',
    token: h.token,
    govde,
  });
  if (r.kod === 201 || r.kod === 200) {
    ozet.mesaj++;
    return true;
  }
  console.log(`  ! mesaj ${govde.type} -> ${r.kod} ${JSON.stringify(r.d)}`);
  return false;
}

/// Iki kisi arasinda sohbet acar (yoksa) ve `chat_id` doner.
async function sohbetAc(j, h, digerId) {
  const r = await j('/chats/direct', {
    yontem: 'POST',
    token: h.token,
    govde: { user_id: digerId },
  });
  return r.kod === 200 && r.d ? r.d.chat_id : null;
}

/// ⚠️⚠️⚠️ TURU 180z — SOHBETTE **ANKET** (kullanici emri: *"bunlarda
/// ANKETLER video resim belge konum her sey paylasilsin"*).
///
/// ⚠️ Anket AYRI BIR UCTUR (`POST /chats/{id}/polls`), mesaj ucu DEGIL —
///	sunucu kendi `type:'poll'` mesajini URETIYOR (`chat/anket.go:101`).
///	Mesaj ucuna `type:'poll'` gondermek beyaz listeden GECMEZ.
/// ⚠️ Istek govdesi: `{question, options[], multi}` (anket.go:211-214).
///	Tavanlar: soru 300 rune · secenek 100 rune · en fazla 12 secenek.
async function anket(j, cid, h, soru, secenekler, ozet, multi = false) {
  const r = await j(`/chats/${cid}/polls`, {
    yontem: 'POST',
    token: h.token,
    govde: { question: soru, options: secenekler, multi },
  });
  if (r.kod === 201 || r.kod === 200) {
    ozet.mesaj++;
    ozet.anket = (ozet.anket || 0) + 1;
    // ⚠️⚠️ Anket kimligi MESAJ id'si DEGIL: yanit
    //	`{id, type:"poll", content, poll:{id, options:[{id, idx, text}]}}`
    //	seklinde ve oy ucu ANKET id'sini bekler (anket.go:364-372).
    //	`r.d.id` gecilseydi oy HEP 404 alirdi.
    // ⚠️⚠️ SECENEK ID'LERI DE DONER: `/polls/{id}/vote` `option_ids`
    //	alaninda **SECENEK ID** bekler, INDEKS DEGIL (anket.go:399).
    //	Indeks gecilseydi oy sessizce yanlis secenege ya da hicbir
    //	secenege gitmezdi.
    const pl = (r.d && r.d.poll) || null;
    if (!pl) return null;
    return {
      id: pl.id || pl.poll_id,
      secenekIdleri: (pl.options || []).map((o) => o.id),
    };
  }
  console.log(`  ! anket -> ${r.kod} ${JSON.stringify(r.d)}`);
  return null;
}

/// ⚠️ TURU 180z — ankete OY VERME (`POST /polls/{id}/vote`). Oy verilmis bir
///	anket, cubuklarin ve yuzdelerin GERCEK veriyle cizildigini gosterir;
///	bos anket "calismiyor" gibi gorunurdu.
async function anketOy(j, p, h, sira) {
  if (!p || !p.id || !p.secenekIdleri || !p.secenekIdleri[sira]) return;
  const r = await j(`/polls/${p.id}/vote`, {
    yontem: 'POST',
    token: h.token,
    // ⚠️ Alan adi `option_ids` ve **SECENEK ID DIZISI** (anket.go:399);
    //	indeks ya da `options` KABUL EDILMEZ. Semantik "istenen TAM
    //	kume": bos dizi TUM oylari geri ceker.
    govde: { option_ids: [p.secenekIdleri[sira]] },
  });
  if (r.kod >= 300) console.log(`  ! anket oy -> ${r.kod}`);
}

/// ⚠️ `A` = ana test kullanicisi (Ali). Sohbetlerin cogunda SON MESAJ
///	karsi taraftan gelir ve A **OKUMAZ** -> sohbet listesinde GERCEK
///	okunmamis rozetleri olusur (rozet mantigi ancak boyle gorulebilir).
async function sohbetTohum(j, A, B, isletmeler, medya) {
  const ozet = { sohbet: 0, mesaj: 0, arsiv: 0, toplulukGonderi: 0 };
  const I = (i) => (isletmeler || [])[i] || null;

  // ═════ 1) ZEYNEP — EN ZENGIN SOHBET (her mesaj tipi burada) ═════
  const c1 = await sohbetAc(j, A, B.id);
  if (c1) {
    ozet.sohbet++;
    await mesaj(j, c1, A, { type: 'text', content: 'Selam! Yarin sahilde yuruyuse var misin?' }, ozet);
    await mesaj(j, c1, B, { type: 'text', content: 'Varim, saat 19:00 uygun mu?' }, ozet);
    await mesaj(j, c1, A, { type: 'text', content: 'Uygun. Cay ocaginin oradan baslayalim.' }, ozet);
    if (medya.foto1) {
      await mesaj(j, c1, B, { type: 'image', content: 'Gecen hafta ayni yerde cektim', media_id: medya.foto1 }, ozet);
    }
    await mesaj(j, c1, A, { type: 'text', content: 'Cok guzel olmus!' }, ozet);
    await mesaj(j, c1, A, { type: 'location', content: kGebze }, ozet);
    await mesaj(j, c1, B, { type: 'text', content: 'Aldim konumu, orada bulusuruz.' }, ozet);
    if (medya.video) {
      await mesaj(j, c1, A, { type: 'video', content: '', media_id: medya.video }, ozet);
      await mesaj(j, c1, B, { type: 'text', content: 'Videoyu izledim, harika :)' }, ozet);
    }
    if (medya.foto2) {
      // ⚠️ TEK KULLANIMLIK — sunucuda karsiligi YOK, altyazi isaretcisi
      //    ile prototipte gorunur (dosya basindaki serh).
      await mesaj(j, c1, B, { type: 'image', content: kTekIsaret, media_id: medya.foto2 }, ozet);
    }
    // ⚠️ TURU 180z — ANKET (AYRI UC: POST /chats/{id}/polls).
    const p1 = await anket(j, c1, A, 'Cumartesi nerede bulusalim?',
      ['Sahil', 'Cay ocagi', 'Park'], ozet);
    // ⚠️ Oy verilmis anket: cubuklar ve yuzdeler GERCEK veriyle cizilir.
    //	Bos bir anket 'calismiyor' gibi gorunurdu.
    await anketOy(j, p1, B, 1);
    await anketOy(j, p1, A, 1);
    await mesaj(j, c1, B, { type: 'text', content: 'Ben cay ocagini sectim, orasi daha yakin.' }, ozet);
    // ⚠️⚠️ TURU 180z — KISI PAYLASIMI. Icerik **'<userId>|<ad>'**
    //	(chat_screen.dart:479 `notifier.send('|', type:'contact')`).
    //	Ilk yazimda 'ad|telefon' gonderilmisti ve balon KIMLIK yerine
    //	ADI id sanip basliga TELEFONU yaziyordu; 'Profili gör' de var
    //	olmayan bir profile giderdi (emulatorde gorundu).
    const paylasilanKisi = isletmeler.find((x) => (x.ad || '').includes('Kuaför'));
    if (paylasilanKisi) {
      await mesaj(j, c1, A, {
        type: 'contact',
        content: `${paylasilanKisi.id}|${paylasilanKisi.ad}`,
      }, ozet);
    }
    if (medya.belgeIcin) {
      // ⚠️ TURU 180z — BELGE. Medya GONDERENE ait olmali (403 kapisi).
      const bl = await medya.belgeIcin(B, 'yuruyus-rotasi');
      if (bl) {
        await mesaj(j, c1, B, { type: 'document', content: 'Yuruyus rotasi', media_id: bl }, ozet);
      }
    }
    await mesaj(j, c1, B, { type: 'text', content: 'Bu arada cumartesi etkinlik var, sana da atiyorum.' }, ozet);
    if (medya.etkinlik) {
      await mesaj(j, c1, B, { type: 'etkinlik', content: `${medya.etkinlik.id}|${medya.etkinlik.baslik}` }, ozet);
    }
    // A OKUMAZ -> okunmamis rozeti
  }

  // ═════ 2) McDONALD'S — isletme sohbeti, gorselli, OKUNMAMIS ═════
  const mc = I(0);
  if (mc) {
    const c2 = await sohbetAc(j, A, mc.id);
    if (c2) {
      ozet.sohbet++;
      await mesaj(j, c2, A, { type: 'text', content: 'Merhaba, aksam kacta kapaniyorsunuz?' }, ozet);
      await mesaj(j, c2, mc, { type: 'text', content: 'Merhaba! Hafta ici 23:00, hafta sonu 01:00.' }, ozet);
      if (medya.foto3) {
        await mesaj(j, c2, mc, { type: 'image', content: 'Bu haftanin menusu', media_id: medya.foto3 }, ozet);
      }
      await mesaj(j, c2, mc, { type: 'text', content: 'Menu icin fiyatlarimizi da gonderdim, bekleriz.' }, ozet);
      if (medya.belgeIcin) {
        const mnu = await medya.belgeIcin(mc, 'menu-fiyat-listesi');
        if (mnu) {
          await mesaj(j, c2, mc, { type: 'document', content: 'Fiyat listesi', media_id: mnu }, ozet);
        }
      }
      const p2 = await anket(j, c2, mc, 'Yeni menude hangisini istersiniz?',
        ['Tavuk burger', 'Kofte burger', 'Vejetaryen'], ozet);
      await anketOy(j, p2, A, 0);
    }
  }

  // ═════ 3) KUAFOR — randevu + konum ═════
  const kuafor = isletmeler.find((x) => (x.ad || '').includes('Kuaför')) || I(8);
  if (kuafor) {
    const c3 = await sohbetAc(j, A, kuafor.id);
    if (c3) {
      ozet.sohbet++;
      await mesaj(j, c3, A, { type: 'text', content: 'Cumartesi 14:00 icin yer var mi?' }, ozet);
      await mesaj(j, c3, kuafor, { type: 'text', content: 'Var, adiniza yazdim.' }, ozet);
      await mesaj(j, c3, kuafor, { type: 'location', content: kGebze }, ozet);
      if (medya.belgeIcin) {
        const fl = await medya.belgeIcin(kuafor, 'hizmet-fiyat-listesi');
        if (fl) {
          await mesaj(j, c3, kuafor, { type: 'document', content: 'Hizmet listesi', media_id: fl }, ozet);
        }
      }
      await mesaj(j, c3, A, { type: 'text', content: 'Tesekkurler, gorusmek uzere.' }, ozet);
      await j(`/chats/${c3}/read`, { yontem: 'POST', token: A.token });
    }
  }

  // ═════ 4) OTEL — IBAN paylasimi ═════
  const otel = isletmeler.find((x) => (x.ad || '').includes('Otel'));
  if (otel) {
    const c4 = await sohbetAc(j, A, otel.id);
    if (c4) {
      ozet.sohbet++;
      await mesaj(j, c4, A, { type: 'text', content: 'Hafta sonu icin cift kisilik oda ayirtabilir miyim?' }, ozet);
      await mesaj(j, c4, otel, { type: 'text', content: 'Tabii, kapora icin hesap bilgimizi gonderiyorum.' }, ozet);
      if (medya.fotoIcin) {
        const oda = await medya.fotoIcin(otel, 81);
        if (oda) {
          await mesaj(j, c4, otel, { type: 'image', content: 'Cift kisilik odamiz', media_id: oda }, ozet);
        }
      }
      await mesaj(j, c4, otel, { type: 'iban', content: 'TR330006100519786457841326|Gebze Park Otel' }, ozet);
      await mesaj(j, c4, A, { type: 'text', content: 'Kapora yarin gonderiyorum.' }, ozet);
    }
  }

  // ═════ 5) KAHVE MOLASI — video ═════
  //
  // ⚠️⚠️ **MEDYA GONDERENE AIT OLMALI**: sunucu `media_assets.owner_id` ile
  //	mesaji atani karsilastirir ve uymuyorsa **403 "geçersiz medya"**
  //	doner (ilk kosuda tam bunu aldik: A'nin yukledigi videoyu KAFE
  //	gondermeye calisiyordu). Bu yuzden video kafenin KENDI tokeniyle
  //	yukleniyor.
  const kafe = isletmeler.find((x) => (x.ad || '').includes('Kahve'));
  if (kafe) {
    const c5 = await sohbetAc(j, A, kafe.id);
    if (c5) {
      ozet.sohbet++;
      await mesaj(j, c5, kafe, { type: 'text', content: 'Yeni tatlilarimiz geldi, bir bakin :)' }, ozet);
      const kafeVideo = medya.videoIcin ? await medya.videoIcin(kafe) : null;
      if (kafeVideo) {
        await mesaj(j, c5, kafe, { type: 'video', content: '', media_id: kafeVideo }, ozet);
      }
      await mesaj(j, c5, A, { type: 'text', content: 'Aksam ugrarim.' }, ozet);
      await j(`/chats/${c5}/read`, { yontem: 'POST', token: A.token });
    }
  }

  // ═════ 6) DOKTOR — ARSIVLENMIS sohbet ═════
  const dr = isletmeler.find((x) => (x.ad || '').includes('Dr.'));
  if (dr) {
    const c6 = await sohbetAc(j, A, dr.id);
    if (c6) {
      ozet.sohbet++;
      await mesaj(j, c6, A, { type: 'text', content: 'Kontrol randevusu icin tesekkurler.' }, ozet);
      await mesaj(j, c6, dr, { type: 'text', content: 'Rica ederim, gecmis olsun.' }, ozet);
      await j(`/chats/${c6}/read`, { yontem: 'POST', token: A.token });
      // ⚠️ `PATCH /chats/{id}` {archived:true} — 001'den beri var olan
      //    `chat_members.archived` sutununu YAZAN uc (turu 76).
      const ar = await j(`/chats/${c6}`, {
        yontem: 'PATCH',
        token: A.token,
        govde: { archived: true },
      });
      if (ar.kod === 200 || ar.kod === 204) ozet.arsiv++;
    }
  }

  return ozet;
}

module.exports = { sohbetTohum, kTekIsaret };
