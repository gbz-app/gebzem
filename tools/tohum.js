// ⚠️⚠️⚠️ TURU 90 — TOHUM (SEED) VERI: her DB temizliginden SONRA kosar.
//
// Kullanici emri: *"her db temizliginde artik 2 doktor 2 diyetisyen 2 kuafor
// 2 guzellik merkezi 2 ilan 2 etkinlik 2 otel profili vs olmasi gerekiyor;
// bunlardan RANDEVU ve REZERVASYON almamiz gerekiyor; bu hesaplarin her
// seferinde TELEFON ve SIFRELERINI TABLO seklinde verirsin"*.
//
// ═══════════ NEDEN NODE + GERCEK UCLAR (SQL ya da Go DEGIL) ═══════════
//
// Uc secenek vardi:
//   (a) `seed.sql`     — DB'ye DOGRUDAN yazar
//   (b) `cmd/tohum`    — Go, yine DB'ye dogrudan yazar
//   (c) BU DOSYA       — GERCEK HTTP uclarini cagirir
//
// (a) ve (b) sunucudaki KURALLARI ATLAR: `verified` bayragi, kayit bonusu
// (`coin_ledger`), slot hizasi, calisma saati dogrulamasi, medya sahipligi...
// Turu 85b'de tam bu sinif bir hata "HAYALET HESAP" uretti: `verified`
// yazilmayan hesaplar giris YAPAMIYORDU. Tohum DB'ye dogrudan yazsaydi ayni
// tuzaga her seferinde yeniden duserdik.
//
// (c) ise TERSINE CALISIR: bir uc sozlesmesi degisirse tohum **KIRMIZI
// DUSER** ve bunu ANINDA gorurum. Yani tohum ayni zamanda bir DUMAN TESTIDIR.
//
// ⚠️ `tools/uctan_uca.js` ZATEN bu zinciri kosuyor; buradaki `j()` ve
//    `hesapAc()` onun kanitlanmis desenidir — fark: RASTGELE degil
//    **DETERMINISTIK** telefon/sifre (kullaniciya tablo verilebilsin diye).
//
// KULLANIM:  node tools/tohum.js
// ⚠️ ONCE DB TEMIZLENIR (surum rutini), SONRA bu kosar.

const API = process.env.GEBZEM_API || 'https://api.gebzem.app';

// ⚠️ TEK SIFRE: kullaniciya verilecek tabloyu okunur kilar. Bunlar TEST
//    hesaplaridir ve her surumde SILINIP yeniden kurulur.
const SIFRE = 'Gebzem2026!';

async function j(yol, { yontem = 'GET', govde, token } = {}) {
  const h = { 'Content-Type': 'application/json' };
  if (token) h.Authorization = 'Bearer ' + token;
  const r = await fetch(API + yol, {
    method: yontem,
    headers: h,
    body: govde === undefined ? undefined : JSON.stringify(govde),
  });
  const t = await r.text();
  let d = null;
  try { d = JSON.parse(t); } catch { d = t; }
  return { kod: r.status, d };
}

/// Hesap acar: /auth/register -> dev_otp -> /auth/verify -> token.
///
/// ⚠️ `dev_otp` yalniz DEV_MODE'da yanitta doner; tohum SMS GONDERMEZ.
/// ⚠️ `/auth/verify` `verified=true` yazar ve kayit bonusunu isler — yani
///    hesap GIRIS YAPABILIR dogar (turu 85b "hayalet hesap" dersi).
async function hesapAc({ tel, kadi, ad }) {
  const kayit = await j('/auth/register', {
    yontem: 'POST',
    govde: { phone: tel, password: SIFRE, name: ad, username: kadi },
  });
  if (kayit.kod >= 300) {
    throw new Error(`${ad} kayit: ${kayit.kod} ${JSON.stringify(kayit.d)}`);
  }
  const otp = kayit.d.dev_otp;
  if (!otp) throw new Error(`${ad}: dev_otp YOK (DEV_MODE kapali?)`);
  const dog = await j('/auth/verify', {
    yontem: 'POST',
    govde: { phone: tel, code: String(otp) },
  });
  if (dog.kod >= 300) {
    throw new Error(`${ad} verify: ${dog.kod} ${JSON.stringify(dog.d)}`);
  }
  const token = dog.d.token || dog.d.access_token;
  const me = await j('/users/me', { token });
  return { ad, tel, kadi, token, id: me.d.id };
}

// ⚠️ 7 GUNLUK CALISMA SAATI **ZORUNLU**: slot ureteci calisma gunlerinden
//    slot uretir. Tek gun tanimlansaydi randevu YALNIZ o gun alinabilirdi
//    (turu 80b'de e2e tam bu yuzden "kalici yalanci-yesil" veriyordu).
const CALISMA = [1, 2, 3, 4, 5, 6, 7].map((g) => ({
  gun: g, acilis: '09:00', kapanis: '20:00', kapali: false,
}));

// ⚠️ KOORDINAT **ZORUNLU**: "Yakınımda" sorgusu `enlem<>0 OR boylam<>0`
//    suzgeci uygular; koordinatsiz isletme haritada ve listede HIC gorunmez.
//    Gebze merkez cevresine dagitiliyor.
const GEBZE = { enlem: 40.8028, boylam: 29.4307 };
const dagit = (i) => ({
  enlem: GEBZE.enlem + (((i % 5) - 2) * 0.006),
  boylam: GEBZE.boylam + ((Math.floor(i / 5) - 1) * 0.008),
});

/// Isletme profili + randevu ayari + katalog urunu.
async function isletmeKur(h, { kategori, adres, ilce, urunler, i }) {
  const k = dagit(i);
  const r = await j('/users/me/isletme', {
    yontem: 'PUT',
    token: h.token,
    govde: {
      kategori, adres, il: 'Kocaeli', ilce,
      telefon: h.tel, calisma: CALISMA,
      enlem: k.enlem, boylam: k.boylam,
    },
  });
  if (r.kod >= 300) throw new Error(`${h.ad} isletme: ${r.kod} ${JSON.stringify(r.d)}`);

  // ⚠️ RANDEVU AYARI ACILMADAN "Randevu al" dugmesi CIZILMEZ (sunucu
  //    `randevu_acik` donduruyor ve istemci ona bakiyor).
  // ⚠️ `otomatik_onay: true` -> randevu 'bekliyor' yerine 'onaylandi' dogar;
  //    test ederken elle onay beklemek gerekmesin.
  const ay = await j('/isletme/randevu-ayar', {
    yontem: 'PUT',
    token: h.token,
    govde: {
      acik: true, slot_dakika: 30, slot_kapasite: 2,
      ileri_gun: 30, otomatik_onay: true,
    },
  });
  if (ay.kod >= 300) throw new Error(`${h.ad} randevu-ayar: ${ay.kod}`);

  for (const u of urunler || []) {
    const ur = await j('/isletme/urunler', {
      yontem: 'POST', token: h.token, govde: u,
    });
    if (ur.kod >= 300) throw new Error(`${h.ad} urun: ${ur.kod} ${JSON.stringify(ur.d)}`);
  }
  return h;
}

const yarin = () => {
  const d = new Date(Date.now() + 24 * 3600 * 1000);
  return d.toISOString().slice(0, 10);
};

/// Bir isletmeden GERCEK randevu/rezervasyon alir (musait slot secerek).
///
/// ⚠️ SLOT SAATI KENDIMIZ HESAPLAMAYIZ: sunucu `uygun-saatler` ile uretir ve
///    `Olustur` ayni ureteci kullanarak DOGRULAR; elle hesaplanan saat 409
///    dondururdu (turu 80b `SlotVarMi` dersi).
async function randevuAl(musteri, isletmeID, notMetni) {
  const s = await j(
    `/isletmeler/${isletmeID}/uygun-saatler?tarih=${yarin()}`,
    { token: musteri.token });
  const musait = ((s.d && s.d.slotlar) || []).find((x) => x.musait);
  if (!musait) return { atlandi: 'musait slot yok' };
  const r = await j(`/isletmeler/${isletmeID}/randevu`, {
    yontem: 'POST',
    token: musteri.token,
    govde: { baslangic: musait.zaman, kisi_sayisi: 2, not_musteri: notMetni },
  });
  return { kod: r.kod, d: r.d, saat: musait.zaman };
}

// ═══════════════════════ TOHUM TANIMI ═══════════════════════
//
// ⚠️ Telefonlar SABIT ve OKUNUR: +90555 + 3 haneli grup kodu + sira.
//    Boylece kullaniciya verilen tablo her surumde AYNI kalir.
const ISLETMELER = [
  { grup: 'Doktor', kategori: 'saglik', ad: 'Dr. Ayşe Yılmaz', kadi: 'drayse', tel: '+905551010001',
    adres: 'Hürriyet Cd. No:12', ilce: 'Gebze',
    urunler: [
      { ad: 'Genel muayene', bolum: 'Muayene', fiyat_kurus: 90000, tur: 'hizmet', ozellikler: { sure_dakika: '20' } },
      { ad: 'Kontrol', bolum: 'Muayene', fiyat_kurus: 50000, tur: 'hizmet', ozellikler: { sure_dakika: '15' } },
    ] },
  { grup: 'Doktor', kategori: 'saglik', ad: 'Dr. Mehmet Kaya', kadi: 'drmehmet', tel: '+905551010002',
    adres: 'İstasyon Cd. No:5', ilce: 'Gebze',
    urunler: [
      { ad: 'Dahiliye muayene', bolum: 'Muayene', fiyat_kurus: 100000, tur: 'hizmet', ozellikler: { sure_dakika: '30' } },
    ] },

  { grup: 'Diyetisyen', kategori: 'diyetisyen', ad: 'Dyt. Elif Demir', kadi: 'dytelif', tel: '+905551020001',
    adres: 'Bağdat Cd. No:44', ilce: 'Gebze',
    urunler: [
      { ad: 'Beslenme danışmanlığı', bolum: 'Danışmanlık', fiyat_kurus: 80000, tur: 'hizmet', ozellikler: { sure_dakika: '45' } },
      { ad: 'Takip seansı', bolum: 'Danışmanlık', fiyat_kurus: 45000, tur: 'hizmet', ozellikler: { sure_dakika: '20' } },
    ] },
  { grup: 'Diyetisyen', kategori: 'diyetisyen', ad: 'Dyt. Burak Şahin', kadi: 'dytburak', tel: '+905551020002',
    adres: 'Atatürk Bul. No:8', ilce: 'Darıca',
    urunler: [
      { ad: 'Sporcu beslenmesi', bolum: 'Danışmanlık', fiyat_kurus: 120000, tur: 'hizmet', ozellikler: { sure_dakika: '60' } },
    ] },

  { grup: 'Kuaför', kategori: 'kuafor', ad: 'Kuaför Serkan', kadi: 'kuaforserkan', tel: '+905551030001',
    adres: 'Çarşı Cd. No:21', ilce: 'Gebze',
    urunler: [
      { ad: 'Saç kesimi', bolum: 'Saç', fiyat_kurus: 35000, tur: 'hizmet', ozellikler: { sure_dakika: '30' } },
      { ad: 'Sakal tıraşı', bolum: 'Saç', fiyat_kurus: 20000, tur: 'hizmet', ozellikler: { sure_dakika: '15' } },
    ] },
  { grup: 'Kuaför', kategori: 'kuafor', ad: 'Kuaför Deniz', kadi: 'kuafordeniz', tel: '+905551030002',
    adres: 'Yeni Mah. 3. Sk. No:2', ilce: 'Çayırova',
    urunler: [
      { ad: 'Saç boyama', bolum: 'Saç', fiyat_kurus: 90000, tur: 'hizmet', ozellikler: { sure_dakika: '90' } },
    ] },

  { grup: 'Güzellik', kategori: 'guzellik', ad: 'Güzellik Merkezi Nur', kadi: 'guzelliknur', tel: '+905551040001',
    adres: 'Osman Yılmaz Mah. No:17', ilce: 'Gebze',
    urunler: [
      { ad: 'Cilt bakımı', bolum: 'Bakım', fiyat_kurus: 150000, tur: 'hizmet', ozellikler: { sure_dakika: '60' } },
      { ad: 'Manikür', bolum: 'Bakım', fiyat_kurus: 40000, tur: 'hizmet', ozellikler: { sure_dakika: '30' } },
    ] },
  { grup: 'Güzellik', kategori: 'guzellik', ad: 'Güzellik Merkezi Ela', kadi: 'guzellikela', tel: '+905551040002',
    adres: 'Mustafa Paşa Mah. No:9', ilce: 'Darıca',
    urunler: [
      { ad: 'Lazer epilasyon', bolum: 'Bakım', fiyat_kurus: 250000, tur: 'hizmet', ozellikler: { sure_dakika: '45' } },
    ] },

  { grup: 'Otel', kategori: 'otel', ad: 'Gebze Park Otel', kadi: 'gebzeparkotel', tel: '+905551050001',
    adres: 'Sahil Yolu No:1', ilce: 'Gebze',
    urunler: [
      { ad: 'Standart Oda', bolum: 'Standart', fiyat_kurus: 180000, tur: 'oda',
        ozellikler: { kapasite: '2', yatak: 'Çift kişilik', kahvalti: 'Dahil', metrekare: '22' } },
      { ad: 'Deniz Manzaralı Suit', bolum: 'Suit', fiyat_kurus: 420000, tur: 'oda',
        ozellikler: { kapasite: '3', yatak: 'Çift kişilik', kahvalti: 'Dahil', metrekare: '45' } },
    ] },
  { grup: 'Otel', kategori: 'otel', ad: 'Marmara Konak Otel', kadi: 'marmarakonak', tel: '+905551050002',
    adres: 'Liman Cd. No:30', ilce: 'Darıca',
    urunler: [
      { ad: 'Ekonomi Oda', bolum: 'Standart', fiyat_kurus: 120000, tur: 'oda',
        ozellikler: { kapasite: '1', yatak: 'Tek kişilik', kahvalti: 'Dahil değil', metrekare: '16' } },
    ] },
];

// ⚠️ ILAN ve ETKINLIK icin ISLETME HESABI GEREKMEZ (`Olustur` yalnizca
//    oturum ister) — bu yuzden ayri "normal kullanici" hesaplari acilir.
const KULLANICILAR = [
  { ad: 'Ali Vural', kadi: 'alivural', tel: '+905551060001' },
  { ad: 'Zeynep Ak', kadi: 'zeynepak', tel: '+905551060002' },
];

async function main() {
  const satirlar = [];
  const isletmeler = [];

  console.log('TOHUM baslatiliyor:', API);

  // ---- 10 ISLETME
  for (let i = 0; i < ISLETMELER.length; i++) {
    const t = ISLETMELER[i];
    const h = await hesapAc({ tel: t.tel, kadi: t.kadi, ad: t.ad });
    await isletmeKur(h, { ...t, i });
    isletmeler.push({ ...h, grup: t.grup, kategori: t.kategori });
    satirlar.push({ Rol: t.grup, Ad: t.ad, Telefon: t.tel, Sifre: SIFRE });
    console.log('  isletme OK:', t.ad);
  }

  // ---- 2 NORMAL KULLANICI
  const kullanicilar = [];
  for (const u of KULLANICILAR) {
    const h = await hesapAc(u);
    kullanicilar.push(h);
    satirlar.push({ Rol: 'Kullanıcı', Ad: u.ad, Telefon: u.tel, Sifre: SIFRE });
    console.log('  kullanici OK:', u.ad);
  }

  // ---- 2 ILAN (biri IS ILANI — turu 90) + 2 ETKINLIK
  const ilanlar = [
    { tur: 'vasita', kategori: 'otomobil', baslik: 'Sahibinden 2019 Ford Focus',
      aciklama: 'Hatasız, boyasız. 68.000 km.', fiyat_kurus: 89000000,
      il: 'Kocaeli', ilce: 'Gebze',
      ozellikler: { marka: 'Ford', model: 'Focus', yil: '2019', km: '68000', vites: 'Otomatik', yakit: 'Dizel' } },
    { tur: 'is', kategori: 'garson', baslik: 'Restoranımıza garson aranıyor',
      aciklama: 'Deneyimli, güler yüzlü ekip arkadaşı arıyoruz. Sigorta + yemek.',
      fiyat_kurus: 3000000, il: 'Kocaeli', ilce: 'Gebze',
      ozellikler: { pozisyon: 'Garson', calisma_sekli: 'Tam zamanlı', deneyim_yil: '1', egitim: 'Fark etmez' } },
  ];
  for (let i = 0; i < ilanlar.length; i++) {
    const sahip = kullanicilar[i % kullanicilar.length];
    const r = await j('/ilanlar', { yontem: 'POST', token: sahip.token, govde: ilanlar[i] });
    if (r.kod >= 300) throw new Error(`ilan: ${r.kod} ${JSON.stringify(r.d)}`);
    console.log('  ilan OK:', ilanlar[i].baslik);
    // ⚠️ IS ILANINA GERCEK BASVURU: ozelligin uctan uca calistigini kanitlar.
    if (ilanlar[i].tur === 'is') {
      const basvuran = kullanicilar[(i + 1) % kullanicilar.length];
      const b = await j(`/ilanlar/${r.d.id}/basvuru`, {
        yontem: 'POST', token: basvuran.token,
        govde: { not: 'Merhaba, 2 yıl deneyimim var. İlgileniyorum.' },
      });
      console.log('  is ilanina basvuru:', b.kod);
    }
  }

  const yarinISO = new Date(Date.now() + 36 * 3600 * 1000).toISOString();
  const etkinlikler = [
    { baslik: 'Gebze Kitap Günleri', aciklama: 'Yazar söyleşileri ve imza günü.',
      kategori: 'kultur', baslangic: yarinISO, konum: 'Gebze Kültür Merkezi',
      il: 'Kocaeli', ilce: 'Gebze', ucretsiz: true, kontenjan: 200 },
    { baslik: 'Akustik Konser', aciklama: 'Sahilde açık hava konseri.',
      kategori: 'konser', baslangic: yarinISO, konum: 'Eskihisar Sahil',
      il: 'Kocaeli', ilce: 'Gebze', ucretsiz: false, fiyat_kurus: 25000, kontenjan: 150 },
  ];
  for (let i = 0; i < etkinlikler.length; i++) {
    const sahip = kullanicilar[i % kullanicilar.length];
    const r = await j('/etkinlikler', { yontem: 'POST', token: sahip.token, govde: etkinlikler[i] });
    if (r.kod >= 300) throw new Error(`etkinlik: ${r.kod} ${JSON.stringify(r.d)}`);
    console.log('  etkinlik OK:', etkinlikler[i].baslik);
  }

  // ---- GERCEK RANDEVU + REZERVASYON (kullanici emri)
  // ⚠️ Doktordan RANDEVU, otelden REZERVASYON: `randevu.TurBul` kategoriden
  //    turetir ve turu 90'da 'otel' -> rezervasyon eklendi.
  const doktor = isletmeler.find((x) => x.grup === 'Doktor');
  const otel = isletmeler.find((x) => x.grup === 'Otel');
  const r1 = await randevuAl(kullanicilar[0], doktor.id, 'Baş ağrısı şikayeti');
  console.log('  RANDEVU (doktor):', JSON.stringify(r1.kod ?? r1.atlandi));
  const r2 = await randevuAl(kullanicilar[1], otel.id, '2 kişi, 1 gece');
  console.log('  REZERVASYON (otel):', JSON.stringify(r2.kod ?? r2.atlandi));

  // ---- KULLANICIYA VERILECEK TABLO
  const g = (s, n) => String(s).padEnd(n);
  console.log('');
  console.log('| ' + g('Rol', 11) + '| ' + g('Ad', 24) + '| ' + g('Telefon', 15) + '| Şifre');
  console.log('|' + '-'.repeat(12) + '|' + '-'.repeat(25) + '|' + '-'.repeat(16) + '|' + '-'.repeat(14));
  for (const s of satirlar) {
    console.log('| ' + g(s.Rol, 11) + '| ' + g(s.Ad, 24) + '| ' + g(s.Telefon, 15) + '| ' + s.Sifre);
  }
  console.log('');
  console.log(`TOHUM TAMAM: ${isletmeler.length} isletme · ${kullanicilar.length} kullanici · ` +
    `${ilanlar.length} ilan (1 is ilani + basvuru) · ${etkinlikler.length} etkinlik · randevu + rezervasyon`);
}

main().catch((e) => {
  console.error('TOHUM HATASI:', e.message);
  process.exit(1);
});
