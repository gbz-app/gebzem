// McDonald's hesabina ORNEK IS ILANLARI ekler (build GEREKTIRMEZ).
//
// ⚠️ Kullanici emri: *"is ilani ornegi eklememissin, halen bekliyorum"*.
//	Profildeki `İş İlanları` sekmesi `/ilanlar?tur=is&sahibi=<uuid>`
//	okuyor (turu 180) ve o sekme HERKESE acik — yani musteri de gorur.
//
// ⚠️ Kategori ve alan anahtarlari SUNUCUDAN dogrulanarak yazildi
//	(`GET /ilan-kategoriler?tur=is`), Dart'a/JS'e SABIT liste
//	kopyalanmadi (turu 77 kurali): sunucu agaci degisirse burasi
//	SESSIZCE yanlis anahtar gondermesin diye kosarken KONTROL EDILIR.
//
// ⚠️ Maas alani `fiyat_kurus`: is ilaninda "fiyat" = AYLIK UCRET. Ucret
//	yazmak istemiyorsak `fiyat_gizli: true` — istemci o zaman
//	"Belirtilmemiş" yazar, 0 TL DEGIL (turu 122 siralama dersi).
//
// Kullanim: node tools/is_ilani.js [--kuru]
const API = process.env.API_URL || 'https://api.gebzem.app';
const TEL = '+905551070001'; // McDonald's (tools/tohum.js)
const SIFRE = 'Gebzem2026!';
const KURU = process.argv.includes('--kuru');

async function j(yol, { yontem = 'GET', govde, token } = {}) {
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

const ILANLAR = [
  {
    kategori: 'mutfak',
    baslik: 'Mutfak Personeli (Tam Zamanlı)',
    aciklama:
      'Gebze Merkez şubemizde görevlendirilmek üzere mutfak personeli '
      + 'arıyoruz. Hijyen kurallarına uyum ve takım çalışması önceliğimiz. '
      + 'Yemek ve yol ücreti tarafımızdan karşılanır. Vardiya planı haftalık '
      + 'olarak önceden paylaşılır.',
    fiyat_kurus: 3000000, // 30.000 TL
    ozellikler: {
      pozisyon: 'Mutfak Personeli',
      calisma_sekli: 'Tam zamanlı',
      deneyim_yil: 0,
      egitim: 'Fark etmez',
    },
  },
  {
    kategori: 'kasiyer',
    baslik: 'Kasiyer / Ön Kasa (Vardiyalı)',
    aciklama:
      'Ön kasada müşteri karşılama ve sipariş alma görevini üstlenecek '
      + 'ekip arkadaşı arıyoruz. Deneyim şart değil; işbaşı eğitimi '
      + 'tarafımızdan verilir. Hafta içi ve hafta sonu vardiyaları mevcuttur.',
    fiyat_kurus: 2850000, // 28.500 TL
    ozellikler: {
      pozisyon: 'Kasiyer',
      calisma_sekli: 'Vardiyalı',
      deneyim_yil: 0,
      egitim: 'Lise',
    },
  },
  {
    kategori: 'sofor',
    baslik: 'Motorlu Kurye (Yarı Zamanlı)',
    aciklama:
      'Gebze içi paket servisi için motosiklet ehliyetli kurye arıyoruz. '
      + 'Motosiklet ve yakıt tarafımızdan sağlanır. Akşam vardiyası için '
      + 'uygun adaylar önceliklidir.',
    // ⚠️ Ucret PRIM'e bagli oldugu icin SAYI YAZILMADI: uydurma bir rakam
    //    yazmak yerine "belirtilmemis" durustur (proje kurali).
    fiyat_gizli: true,
    ozellikler: {
      pozisyon: 'Motorlu Kurye',
      calisma_sekli: 'Yarı zamanlı',
      deneyim_yil: 1,
      egitim: 'Fark etmez',
    },
  },
];

(async () => {
  const g = await j('/auth/login', { yontem: 'POST', govde: { phone: TEL, password: SIFRE } });
  if (g.kod !== 200 || !g.d?.token) throw new Error(`login ${g.kod}: ${g.ham.slice(0, 200)}`);
  const token = g.d.token;
  const me = (await j('/users/me', { token })).d;
  console.log('giris OK —', me.name);

  // ⚠️ ANAHTAR DOGRULAMASI: sunucunun agacinda olmayan bir kategori/alan
  //    gonderirsek ilan SESSIZCE yanlis dala duser ya da alan kaybolur.
  const kj = (await j('/ilan-kategoriler?tur=is', { token })).d;
  const isTuru = (kj.turler || []).find((x) => x.anahtar === 'is');
  if (!isTuru) throw new Error('sunucu agacinda "is" turu YOK');
  const gecerliKat = new Set(isTuru.kategoriler.map((x) => x.anahtar));
  const gecerliAlan = new Set(isTuru.alanlar.map((x) => x.anahtar));
  for (const i of ILANLAR) {
    if (!gecerliKat.has(i.kategori)) throw new Error('gecersiz kategori: ' + i.kategori);
    for (const a of Object.keys(i.ozellikler)) {
      if (!gecerliAlan.has(a)) throw new Error('gecersiz alan: ' + a);
    }
  }
  console.log('anahtarlar sunucu agaciyla UYUMLU');
  if (KURU) { console.log('KURU CALISMA'); return; }

  let n = 0;
  for (const i of ILANLAR) {
    const r = await j('/ilanlar', {
      yontem: 'POST', token,
      govde: {
        tur: 'is',
        kategori: i.kategori,
        baslik: i.baslik,
        aciklama: i.aciklama,
        fiyat_kurus: i.fiyat_kurus || 0,
        fiyat_gizli: !!i.fiyat_gizli,
        il: 'Kocaeli',
        ilce: 'Gebze',
        media_ids: [],
        ozellikler: i.ozellikler,
      },
    });
    if (r.kod !== 201 && r.kod !== 200) {
      throw new Error(`ilan ${r.kod}: ${r.ham.slice(0, 220)}`);
    }
    n++;
    console.log(`ILAN ${n}/${ILANLAR.length} [${i.kategori}] ${i.baslik}`);
  }
  console.log(`\nTAMAM — ${n} is ilani olusturuldu.`);
})().catch((e) => { console.error('HATA:', e.message); process.exit(1); });
