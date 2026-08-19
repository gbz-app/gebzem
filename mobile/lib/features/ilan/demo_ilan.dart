library;

import '../sosyal/demo_veri.dart' show kDemoAkis;
import 'ilan_servisi.dart';

/// ⚠️⚠️⚠️ TURU 106 — **ORNEK ILANLAR** (kullanici emri: *"is ilanlari, normal
///	ilanlar, ev, araba ORNEK SAYFALAR olsun"*).
///
/// ═══════════ NEDEN ISTEMCIDE, SUNUCUDA DEGIL ═══════════
///
/// Iki yol vardi:
///   (a) `tools/tohum.js` ile GERCEK ilanlar ekmek,
///   (b) burada, `kDemoAkis` bayragi arkasinda GORUNUM ornegi tutmak.
///
/// **(b) secildi.** Gerekce:
///   · Tohum CANLI VERITABANINA yazar; kullanicinin onayi olmadan sunucuya
///     kayit atmak bu projede YASAK (CLAUDE.md kural 4).
///   · Ornekler bir URUN OZELLIGI degil, kullanicinin *"ekrani gorelim"*
///     istegidir; yayinda gorunmemeleri gerekir ve tek bayrakla kapanmalari
///     SART (akis demosuyla ayni gerekce).
///   · Tohumla eklenen ilanlar gercek kullanicilarin ilanlariyla ayni listede
///     karisirdi ve silmek icin ayri bir temizlik gerekirdi.
///
/// ⚠️⚠️ **SUNUCUYA GITMEZ:** kimlikler `demo-` onekli; `demoKimlik()` kapisi
///	favori/mesaj/duzenleme/silme yollarinin hepsinde. Medya kimlikleri de
///	`demo-` onekli oldugu icin `MedyaGorsel` AGA CIKMADAN gri yer tutucu
///	cizer (turu 104).
/// ⚠️ YAPMA: bu ilanlari sunucuya yazma ya da `kDemoAkis`i acik birakip
///    yayin alma.
///
/// ⚠️ Kategoriler ve turler **SUNUCUNUN AGACINDAN** alinmistir
///    (`backend/internal/ilan/handler.go` `Turler`): anahtarlar birebir
///    ayni olmali, yoksa cip suzgeci ornekleri ELEYIP bos liste gosterir.
List<Ilan> _ilan({
  required String id,
  required String tur,
  required String kategori,
  required String baslik,
  required String aciklama,
  required int fiyat,
  required String ilce,
  required Map<String, dynamic> ozellikler,
  int saatOnce = 3,
  int gorsel = 1,
}) => [
  Ilan(
    id: 'demo-$id',
    sahibiId: 'demo-sahip-$id',
    sahibiAd: 'Gebzem Örnek',
    sahibiAvatarMediaId: null,
    tur: tur,
    kategori: kategori,
    baslik: baslik,
    aciklama: aciklama,
    // ⚠️ KURUS: 985.000 TL -> 98_500_000
    fiyatKurus: fiyat * 100,
    fiyatGizli: false,
    il: 'Kocaeli',
    ilce: ilce,
    mediaIds: [for (var i = 0; i < gorsel; i++) 'demo-ilan-$id-$i'],
    mediaKinds: [for (var i = 0; i < gorsel; i++) 'image'],
    ozellikler: ozellikler,
    durum: 'yayinda',
    goruntulenme: 40 + baslik.length * 7,
    createdAt: DateTime.now()
        .subtract(Duration(hours: saatOnce))
        .toIso8601String(),
    favorim: false,
  ),
];

/// Tum ornek ilanlar (tur sirasi: vasita · emlak · is · ikinci el).
List<Ilan> get _hepsi => [
  // ═══════════ VASITA (araba) ═══════════
  ..._ilan(
    id: 'focus',
    tur: 'vasita',
    kategori: 'otomobil',
    baslik: '2019 Ford Focus 1.5 TDCi Trend X',
    aciklama:
        'Tek elden, hatasız boyasız. Servis bakımları yetkili serviste '
        'yapıldı. Takas olmaz.',
    fiyat: 985000,
    ilce: 'Gebze',
    saatOnce: 2,
    gorsel: 3,
    ozellikler: {
      'marka': 'Ford',
      'model': 'Focus 1.5 TDCi',
      'yil': 2019,
      'km': 128000,
      'vites': 'Manuel',
      'yakit': 'Dizel',
    },
  ),
  ..._ilan(
    id: 'clio',
    tur: 'vasita',
    kategori: 'otomobil',
    baslik: '2021 Renault Clio Joy 1.0 TCe',
    aciklama: 'İlk sahibinden, garanti devam ediyor.',
    fiyat: 1150000,
    ilce: 'Darıca',
    saatOnce: 9,
    gorsel: 2,
    ozellikler: {
      'marka': 'Renault',
      'model': 'Clio Joy',
      'yil': 2021,
      'km': 46500,
      'vites': 'Otomatik',
      'yakit': 'Benzin',
    },
  ),
  ..._ilan(
    id: 'cb500',
    tur: 'vasita',
    kategori: 'motosiklet',
    baslik: '2017 Honda CB500F',
    aciklama: 'Düşük kilometre, kışın garajda durdu.',
    fiyat: 385000,
    ilce: 'Çayırova',
    saatOnce: 26,
    ozellikler: {'marka': 'Honda', 'model': 'CB500F', 'yil': 2017, 'km': 21400},
  ),
  // ═══════════ EMLAK (ev) ═══════════
  ..._ilan(
    id: 'daire31',
    tur: 'emlak',
    kategori: 'satilik_daire',
    baslik: 'Tatlıkuyu’da 3+1 Satılık Daire · 135 m²',
    aciklama:
        'Site içinde, kapalı otopark ve güvenlik mevcut. Ara kat, geniş '
        'balkon, güneydoğu cephe.',
    fiyat: 3850000,
    ilce: 'Gebze',
    saatOnce: 5,
    gorsel: 4,
    ozellikler: {
      'm2': 135,
      'oda': '3+1',
      'kat': '4. kat',
      'isitma': 'Doğalgaz',
      'esyali': 'Hayır',
    },
  ),
  ..._ilan(
    id: 'daire21',
    tur: 'emlak',
    kategori: 'kiralik_daire',
    baslik: 'Merkezde 2+1 Kiralık Daire · 95 m²',
    aciklama: 'Metrobüs ve çarşıya yürüme mesafesi. Eşyalı kiralanır.',
    fiyat: 18000,
    ilce: 'Gebze',
    saatOnce: 11,
    gorsel: 2,
    ozellikler: {
      'm2': 95,
      'oda': '2+1',
      'kat': '2. kat',
      'isitma': 'Doğalgaz',
      'esyali': 'Evet',
    },
  ),
  ..._ilan(
    id: 'arsa',
    tur: 'emlak',
    kategori: 'arsa',
    baslik: 'Köşe parsel satılık arsa · 480 m²',
    aciklama: 'İmarlı, yola cepheli.',
    fiyat: 2100000,
    ilce: 'Dilovası',
    saatOnce: 30,
    ozellikler: {'m2': 480},
  ),
  // ═══════════ IS ILANI ═══════════
  ..._ilan(
    id: 'garson',
    tur: 'is',
    kategori: 'garson',
    baslik: 'Garson aranıyor (tam zamanlı)',
    aciklama:
        'Merkezdeki restoranımıza deneyimli garson arıyoruz. Sigorta ve '
        'yemek dahildir. Vardiya 11:00–23:00.',
    // ⚠️ Is ilaninda `fiyat_kurus` MAAS anlamina gelir (sunucu serhi).
    fiyat: 32000,
    ilce: 'Gebze',
    saatOnce: 1,
    gorsel: 0,
    ozellikler: {
      'pozisyon': 'Garson',
      'calisma_sekli': 'Tam zamanlı',
      'deneyim_yil': 1,
      'egitim': 'Fark etmez',
    },
  ),
  ..._ilan(
    id: 'kurye',
    tur: 'is',
    kategori: 'sofor',
    baslik: 'Motosikletli kurye',
    aciklama: 'Ehliyet şart, motor tarafımızdan verilir.',
    fiyat: 28000,
    ilce: 'Çayırova',
    saatOnce: 4,
    gorsel: 0,
    ozellikler: {
      'pozisyon': 'Kurye',
      'calisma_sekli': 'Vardiyalı',
      'egitim': 'Fark etmez',
    },
  ),
  ..._ilan(
    id: 'muhasebe',
    tur: 'is',
    kategori: 'ofis',
    baslik: 'Ön muhasebe elemanı',
    aciklama: 'Logo/Netsis bilen, tercihen Gebze ikametli.',
    fiyat: 40000,
    ilce: 'Gebze',
    saatOnce: 20,
    gorsel: 0,
    ozellikler: {
      'pozisyon': 'Ön muhasebe',
      'calisma_sekli': 'Tam zamanlı',
      'deneyim_yil': 2,
      'egitim': 'Ön lisans',
    },
  ),
  // ═══════════ IKINCI EL ═══════════
  ..._ilan(
    id: 'bisiklet',
    tur: 'ikinci_el',
    kategori: 'spor_ekipman',
    baslik: 'Dağ bisikleti 27.5 jant',
    aciklama: 'Az kullanıldı, yeni fren balatası takıldı.',
    fiyat: 9500,
    ilce: 'Darıca',
    saatOnce: 7,
    gorsel: 2,
    ozellikler: {'durum': 'İyi', 'marka': 'Bianchi'},
  ),
  ..._ilan(
    id: 'buzdolabi',
    tur: 'ikinci_el',
    kategori: 'ev_esyasi',
    baslik: 'No-frost buzdolabı',
    aciklama: 'Taşınma sebebiyle satılıktır.',
    fiyat: 7250,
    ilce: 'Gebze',
    saatOnce: 15,
    ozellikler: {'durum': 'Yeni gibi', 'marka': 'Arçelik'},
  ),
];

/// Ekranda gosterilecek ornekler — cip suzgecleriyle UYUMLU.
///
/// ⚠️ Suzgecler SUNUCUDAKIYLE AYNI mantikta uygulanir; aksi halde kullanici
///    "Emlak" cipine basar ve ornekler kaybolur/karisir.
/// ⚠️ `benim`/`favori` acikken ORNEK GOSTERILMEZ: ornekler kullanicinin
///    kendi ilani DEGILDIR ve favorilerinde de degildir; gosterilseydi
///    "benim ilanim" yalani soylenmis olurdu.
List<Ilan> demoIlanlar({
  required String tur,
  required String kategori,
  required String q,
  required bool benim,
  required bool favori,
}) {
  if (!kDemoAkis || benim || favori) return const [];
  final ara = q.trim().toLowerCase();
  return _hepsi.where((i) {
    if (tur.isNotEmpty && i.tur != tur) return false;
    if (kategori.isNotEmpty && i.kategori != kategori) return false;
    if (ara.isEmpty) return true;
    return i.baslik.toLowerCase().contains(ara) ||
        i.aciklama.toLowerCase().contains(ara);
  }).toList();
}
