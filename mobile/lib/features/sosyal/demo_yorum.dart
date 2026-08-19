library;

import 'yorum_satiri.dart';

/// ⚠️⚠️⚠️ TURU 102 — **DEMO YANIT ICERIGI** (kullanici emri: *"ona gore
///	gonderiler paylas dedim sana, boyle anlasilmaz ki"*).
///
/// Kullanicinin gonderdigi UC Threads ekran goruntusu UC AYRI durumu
/// gosteriyordu ve turu 101'de bunlarin yalnizca BIRI ekranda goruluyordu:
///
///	(1) akista gonderinin ALTINDA **YAZI** yaniti, duz dikey cizgiyle bagli
///	(2) ayni yer, ama yanit **GORSEL** tasiyor
///	(3) detayda kok yorum + kivrimli cizgi + "Yanıtları göster"
///
/// ⚠️⚠️ **TURU 101'IN OLCULEN KUSURU:** `demoAkisYaniti` yaniti
///	`gonderiId.length % 2` ile dagitiyordu; sonuc: **uc gonderi de AYNI
///	yorumu** gosteriyordu (foto·galeri·yazi -> hepsi `l.first`), gorselli
///	ve videolu yanit akista **HIC CIKMIYORDU**. Ustelik `demoYorumlar`
///	parametresini KULLANMIYOR, her gonderinin detayinda AYNI ALTI yorumu
///	aciyordu. Yani mimari dogruydu ama EKRANDA GORUNMUYORDU.
///
/// **YENI KURAL: dagitim ACIK MATRISTIR** (`switch`), tesaduf degil. Bir
/// gonderinin hangi yaniti gosterecegi ve detayinda hangi yorumlarin
/// bulunacagi burada TEK TEK yazilidir.
///
/// ⚠️ **BU BIR GORUNUM DEMOSUDUR.** Sunucudaki gercek yorum hatti
///	(`post_comments` + `YorumlarSayfasi`) DEGISMEDI; bu dosya yalnizca
///	`kDemoAkis` acikken cizilir.
/// ⚠️ Gercek ozellik yazilirken sunucunun donmesi gerekenler: yorumun
///	`onayli` bayragi · ALT YANIT LISTESI · yorum medyasi · yazarin
///	begenisi · repost/paylas sayaclari. Bugun bunlarin HICBIRI donmuyor.
class DemoYorum {
  const DemoYorum({
    required this.ad,
    required this.kullaniciAdi,
    required this.zaman,
    required this.metin,
    this.onayli = false,
    this.begeni = 0,
    this.yorum = 0,
    this.repost = 0,
    this.paylas = 0,
    this.begendim = false,
    this.sahipBegendi = false,
    this.yanitlar = const [],
    this.medya = const [],
    this.medyaTur = const [],
    this.akista = false,
  });

  final String ad;
  final String kullaniciAdi;
  final String zaman;
  final String metin;

  /// Mavi tik.
  final bool onayli;

  final int begeni;
  final int yorum;
  final int repost;
  final int paylas;

  /// **BEN** begendim (kalp dolu baslar).
  final bool begendim;

  /// ⚠️⚠️ **GONDERI SAHIBI** bu yaniti begendi (Threads: kucuk kirmizi kalp +
  ///	yazarin minik avatari). Turu 101'de bu alan YOKTU ve cevirici
  ///	`sahipBegendi: d.begendim` yaziyordu — ikisi FARKLI SEYDIR; "ben
  ///	begendim" ile "yazar begendi" ayni kaynaktan beslenince rozet
  ///	kullanicinin kendi dokunusuyla belirir gorunuyordu.
  final bool sahipBegendi;

  final List<DemoYorum> yanitlar;

  /// ⚠️ Yorumda medya. Kimlikler `demo-` onekli oldugu icin gri yer tutucu
  ///    cizilir; sahte fotograf uretilmez.
  final List<String> medya;

  /// `image` | `video` — ⚠️ **OKUNMASI ZORUNLU**: turu 101'de bu alan
  /// tasiniyordu ama hicbir yerde okunmuyordu ve videolu yorum
  /// `MedyaGorsel`e dusup KIRIK GORSEL ciziyordu (turu 83b dersinin
  /// tekrari). `YorumSatiri` artik tur kontrolu yapar.
  final List<String> medyaTur;

  /// ⚠️⚠️ **AKISTA gonderinin ALTINDA gosterilecek yanit BU MU.**
  ///
  ///	Turu 102'de secim listenin **0. ogesi** ile yapiliyordu; ama detay
  ///	siralamasi "yazar once + begeni" oldugu icin listenin sirasi
  ///	DEGISEBILIR ve akistaki yanit sessizce baskasi olurdu. Bayrak, iki
  ///	kullanimi (akis secimi <-> detay sirasi) BIRBIRINDEN AYIRIR.
  /// ⚠️ Her listede EN FAZLA BIR oge `true` olabilir (assert ile korunur).
  final bool akista;
}

// ---------------------------------------------------------------------------
// ⚠️ GONDERI BASINA AYRI YORUM SETI. Ayni ad + ayni metin IKI gonderide
//    tekrarlanmaz: tekrar, listenin "kopyala-yapistir" gorunmesine yol acar
//    ve kullanici mimariyi degil TEKRARI fark eder.
// ⚠️ Akista gosterilecek yanit `akista: true` ILE isaretlenir — SIRAYLA
//    DEGIL. Detay siralamasi (yazar once + begeni) listeyi yeniden dizdigi
//    icin indekse guvenmek akistaki yaniti sessizce degistirirdi.
// ---------------------------------------------------------------------------

/// `foto` — Ayşe Demir'in sahil fotografi. **Akista YAZI yaniti** (durum 1).
const List<DemoYorum> _foto = [
  DemoYorum(
    ad: 'Mehmet Kaya',
    kullaniciAdi: 'mehmetkaya',
    zaman: '6dk',
    onayli: true,
    akista: true,
    metin: 'Bu manzara için Gebze’ye gelmeye değer.',
    begeni: 825,
    yorum: 2,
    repost: 3,
    paylas: 20,
    sahipBegendi: true,
    yanitlar: [
      DemoYorum(
        ad: 'Zeynep Ak',
        kullaniciAdi: 'zeynepak',
        zaman: '4dk',
        metin: 'Aynen, akşamüstü çok güzel oluyor.',
        begeni: 31,
      ),
      DemoYorum(
        ad: 'Ayşe Demir',
        kullaniciAdi: 'aysedemir',
        zaman: '2dk',
        metin: 'Saat yedi buçuk gibi gidin, en güzel o vakit.',
        begeni: 18,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Selma Duman',
    kullaniciAdi: 'selmaduman',
    zaman: '23sa',
    metin: 'Çok güzelmiş, biz de geçen hafta oradaydık.',
    begeni: 870,
    yorum: 1,
    repost: 2,
    begendim: true,
    medya: ['demo-yorum-foto-1'],
    medyaTur: ['image'],
    yanitlar: [
      DemoYorum(
        ad: 'Ayşe Demir',
        kullaniciAdi: 'aysedemir',
        zaman: '20sa',
        metin: 'Çok iyi olmuş!',
        begeni: 36,
      ),
    ],
  ),
  // ⚠️⚠️ YAZARIN KENDI YORUMUNUN **YANITI OLMALI.** Siralama "yazar once"
  //	oldugu icin bu satir DAIMA en ustte cizilir; yanitsiz birakilirsa
  //	kivrimli cizgi ve "Yanıtları göster" ancak IKINCI satirda gorunur ve
  //	ekrani acan kullanici mimariyi ILK BAKISTA goremez.
  DemoYorum(
    ad: 'Ayşe Demir',
    kullaniciAdi: 'aysedemir',
    zaman: '5dk',
    metin: 'Teşekkürler! Sahil yolunun sonundan çektim.',
    begeni: 96,
    paylas: 2,
    yorum: 1,
    yanitlar: [
      DemoYorum(
        ad: 'Zeynep Ak',
        kullaniciAdi: 'zeynepak',
        zaman: '3dk',
        metin: 'Ben de o saatte denerim.',
        begeni: 7,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Enes Varol',
    kullaniciAdi: 'enesvarol',
    zaman: '2g',
    metin: 'Aynı yerden dün akşam.',
    begeni: 194,
    sahipBegendi: true,
    medya: ['demo-yorum-foto-2'],
    medyaTur: ['video'],
  ),
  DemoYorum(
    ad: 'Ali Yıldız',
    kullaniciAdi: 'aliyildiz',
    zaman: '12dk',
    metin: 'Hangi saatte gittin? Kalabalık mıydı?',
    begeni: 9,
    yorum: 1,
    yanitlar: [
      DemoYorum(
        ad: 'Ayşe Demir',
        kullaniciAdi: 'aysedemir',
        zaman: '10dk',
        metin: 'Yedi buçuk gibiydi, sakindi.',
        begeni: 6,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Gebze Kebap Salonu',
    kullaniciAdi: 'gebzekebap',
    zaman: '20dk',
    metin: 'Dönüşte bekleriz.',
    begeni: 4,
  ),
];

/// `galeri` — Mehmet Kaya'nin kahvalti turu. **Akista GORSELLI yanit**
/// (kullanicinin 2. ekran goruntusu: *"burada yorum yerine resim
/// gosterilmis"*).
const List<DemoYorum> _galeri = [
  DemoYorum(
    ad: 'Buse Aydın',
    kullaniciAdi: 'buseaydin',
    zaman: '35dk',
    akista: true,
    // ⚠️⚠️ **METIN YOK — BILEREK.** Kullanicinin 2. ekran goruntusundeki durum
    //	*"yorum yerine RESIM gosterilmis"*. Metin de olsaydi bu kart 1. durumla
    //	(yazi yaniti) ayni gorunur, iki durum ayirt edilemezdi.
    // ⚠️ `YorumSatiri` bos metni destekler (metin blogu kosullu).
    metin: '',
    begeni: 412,
    yorum: 2,
    repost: 4,
    sahipBegendi: true,
    medya: ['demo-yorum-galeri-1'],
    medyaTur: ['image'],
    yanitlar: [
      DemoYorum(
        ad: 'Mehmet Kaya',
        kullaniciAdi: 'mehmetkaya',
        zaman: '30dk',
        metin: 'Evet, tam orası.',
        begeni: 21,
      ),
      DemoYorum(
        ad: 'Kerem Şahin',
        kullaniciAdi: 'keremsahin',
        zaman: '28dk',
        metin: 'Kişi başı ne tuttu?',
        begeni: 7,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Mehmet Kaya',
    kullaniciAdi: 'mehmetkaya',
    zaman: '1sa',
    metin: 'Üç mekân gezdik, en iyisi sonuncusuydu.',
    begeni: 88,
    paylas: 3,
    yorum: 1,
    yanitlar: [
      DemoYorum(
        ad: 'Kerem Şahin',
        kullaniciAdi: 'keremsahin',
        zaman: '55dk',
        metin: 'Sonuncunun adını yazar mısın?',
        begeni: 6,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Hakan Er',
    kullaniciAdi: 'hakaner',
    zaman: '52dk',
    onayli: true,
    metin: 'Gebze’de kahvaltı işi ciddi.',
    begeni: 233,
    begendim: true,
  ),
  DemoYorum(
    ad: 'Nazlı Toprak',
    kullaniciAdi: 'naztoprak',
    zaman: '44dk',
    metin: 'Adresi paylaşır mısın?',
    begeni: 12,
    yorum: 1,
    yanitlar: [
      DemoYorum(
        ad: 'Mehmet Kaya',
        kullaniciAdi: 'mehmetkaya',
        zaman: '40dk',
        metin: 'Mesajdan attım.',
        begeni: 5,
      ),
    ],
  ),
];

/// `video` — Kuaför Serkan'in acilisi. **Akista VIDEOLU yanit.**
const List<DemoYorum> _video = [
  DemoYorum(
    ad: 'Onur Baş',
    kullaniciAdi: 'onurbas',
    zaman: '3sa',
    akista: true,
    metin: 'Açılıştan bir kare daha.',
    begeni: 176,
    yorum: 1,
    sahipBegendi: true,
    medya: ['demo-yorum-video-1'],
    medyaTur: ['video'],
    yanitlar: [
      DemoYorum(
        ad: 'Kuaför Serkan',
        kullaniciAdi: 'kuaforserkan',
        zaman: '2sa',
        metin: 'Eline sağlık!',
        begeni: 12,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Derya Kılıç',
    kullaniciAdi: 'deryakilic',
    zaman: '4sa',
    onayli: true,
    metin: 'Hayırlı olsun, çok şık olmuş.',
    begeni: 512,
    yorum: 2,
    repost: 6,
    yanitlar: [
      DemoYorum(
        ad: 'Kuaför Serkan',
        kullaniciAdi: 'kuaforserkan',
        zaman: '3sa',
        metin: 'Teşekkür ederim.',
        begeni: 9,
      ),
      DemoYorum(
        ad: 'Sinem Ateş',
        kullaniciAdi: 'sinemates',
        zaman: '3sa',
        metin: 'Randevu alınıyor mu?',
        begeni: 4,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Kuaför Serkan',
    kullaniciAdi: 'kuaforserkan',
    zaman: '5sa',
    metin: 'Gelen herkese teşekkürler.',
    begeni: 143,
    yorum: 1,
    yanitlar: [
      DemoYorum(
        ad: 'Sinem Ateş',
        kullaniciAdi: 'sinemates',
        zaman: '4sa',
        metin: 'Cumartesi uğrayacağım.',
        begeni: 8,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Murat Genç',
    kullaniciAdi: 'muratgenc',
    zaman: '2sa',
    metin: 'Fiyat listesi var mı?',
    begeni: 18,
  ),
];

/// `konum` — Gebze Kebap Salonu. **Akista KISA YAZI yaniti.**
const List<DemoYorum> _konum = [
  DemoYorum(
    ad: 'Sinem Ateş',
    kullaniciAdi: 'sinemates',
    zaman: '18dk',
    akista: true,
    metin: 'Akşam geliyoruz.',
    begeni: 7,
  ),
  DemoYorum(
    ad: 'Murat Genç',
    kullaniciAdi: 'muratgenc',
    zaman: '25dk',
    metin: 'Park yeri var mı?',
    begeni: 5,
    yorum: 1,
    yanitlar: [
      DemoYorum(
        ad: 'Gebze Kebap Salonu',
        kullaniciAdi: 'gebzekebap',
        zaman: '22dk',
        metin: 'Arka sokakta yer bulabilirsiniz.',
        begeni: 3,
      ),
    ],
  ),
];

/// `anket` — Usta Döner & Pide.
const List<DemoYorum> _anket = [
  DemoYorum(
    ad: 'Nazlı Toprak',
    kullaniciAdi: 'naztoprak',
    zaman: '2sa',
    metin: 'Sahil dedim ama merkez de olur.',
    begeni: 64,
  ),
  DemoYorum(
    ad: 'Kerem Şahin',
    kullaniciAdi: 'keremsahin',
    zaman: '3sa',
    metin: 'Havaya bakmak lazım.',
    begeni: 21,
  ),
  DemoYorum(
    ad: 'Usta Döner & Pide',
    kullaniciAdi: 'ustadoner',
    zaman: '1sa',
    metin: 'Oy verenlere teşekkürler, sonuç akşam belli olacak.',
    begeni: 15,
  ),
];

/// `ses` — Zeynep Ak'in ses notu.
const List<DemoYorum> _ses = [
  DemoYorum(
    ad: 'Ali Yıldız',
    kullaniciAdi: 'aliyildiz',
    zaman: '1sa',
    metin: 'Sesin çok net gelmiş.',
    begeni: 11,
  ),
  DemoYorum(
    ad: 'Zeynep Ak',
    kullaniciAdi: 'zeynepak',
    zaman: '50dk',
    metin: 'Telefonla kaydettim, hiç uğraşmadım.',
    begeni: 4,
  ),
];

/// `yazi` — Ali Yıldız'in trafik notu.
const List<DemoYorum> _yazi = [
  DemoYorum(
    ad: 'Hakan Er',
    kullaniciAdi: 'hakaner',
    zaman: '40dk',
    onayli: true,
    metin: 'Sabah yedide çıkanlar bilir.',
    begeni: 33,
  ),
  DemoYorum(
    ad: 'Buse Aydın',
    kullaniciAdi: 'buseaydin',
    zaman: '1sa',
    metin: 'Bugün gerçekten rahattı.',
    begeni: 12,
  ),
  DemoYorum(
    ad: 'Ali Yıldız',
    kullaniciAdi: 'aliyildiz',
    zaman: '30dk',
    metin: 'Akşam ne olacak bakalım.',
    begeni: 5,
  ),
];

/// Gonderi detayinda gosterilecek yorumlar — **her gonderi icin AYRI liste.**
///
/// ⚠️ Turu 101'de bu fonksiyon `gonderiId` parametresini HIC KULLANMIYORDU;
///    kullanici hangi gonderiye girerse girsin AYNI alti yorumu goruyordu.
List<DemoYorum> demoYorumlar(String gonderiId) => switch (gonderiId) {
  // ⚠️ TURU 113 — anahtarlar `demo-` onekli (bkz. `demo_veri.dart` serhi:
  //    demo gonderi kimligi artik onek tasiyor).
  'demo-foto' => _foto,
  'demo-galeri' => _galeri,
  'demo-video' => _video,
  'demo-konum' => _konum,
  'demo-anket' => _anket,
  'demo-ses' => _ses,
  'demo-yazi' => _yazi,
  _ => const [],
};

/// Akista gonderinin ALTINDA gosterilecek TEK yanit (Threads deseni).
///
/// ⚠️⚠️ **ACIK MATRIS.** Kullanici *"anasayfada BAZEN yorumlari gosteriyor"*
///	dedi: sekiz gonderiden **dordu** yanit tasir ve ucu FARKLI TURDEDIR —
///	yazi · gorsel · video · kisa yazi. Boylece kullanici mimarinin uc
///	halini de tek ekranda gorur.
/// ⚠️ Sponsorlu gonderi ve gercek gonderiler cagri yerinde ZATEN eleniyor
///    (`gonderi_karti.dart` `_akisYaniti` kapisi).
DemoYorum? demoAkisYaniti(String gonderiId) {
  final l = demoYorumlar(gonderiId);
  assert(
    l.where((d) => d.akista).length <= 1,
    '$gonderiId: birden fazla akis yaniti isaretli',
  );
  for (final d in l) {
    if (d.akista) return d;
  }
  return null;
}

// ---------------------------------------------------------------------------
// ⚠️⚠️⚠️ TURU 102 — **TEK CEVIRICI** (DemoYorum -> YorumGorunum).
//
//	Denetim bulgusu: ayni cevrim UC yerde (gonderi_detay · yorum_paneli ·
//	gonderi_karti) AYRI AYRI yaziliydi ve UCU DE ayni iki hatayi
//	tasiyordu: `yazarMi: d.sahibi` (bayraktan) ve `sahipBegendi: d.begendim`
//	(anlam kaymasi). Uc kopya kacinilmaz olarak drift eder — bu projede
//	kayitli en sik hata sinifi. Artik TEK KAYNAK.
// ---------------------------------------------------------------------------

/// ⚠️⚠️ **`yazarMi` BAYRAKTAN DEGIL, KARSILASTIRMADAN TURER.**
///
///	Turu 101'de `DemoYorum.sahibi` diye elle isaretlenen bir alan vardi;
///	gercek veride boyle bir alan YOK ve olmayacak da — gercek yorumda
///	"gonderi sahibi mi" bilgisi ancak `yorum.kullaniciAdi ==
///	gonderi.yazarUsername` karsilastirmasindan cikar. Demo da ayni yoldan
///	gecsin ki mekanizma GERCEK VERIDE de calistigi ISPATLANMIS olsun.
YorumGorunum demoYorumGorunumu(
  DemoYorum d, {
  required String gonderiId,
  required String yazarKullaniciAdi,
  String yol = '0',
}) => YorumGorunum(
  // ⚠️ Kimlik YOLDAN uretilir (`0`, `0.1`, ...): ad+zaman birlesimi iki
  //    yorumda ayni olabilir ve `AnimatedSwitcher`/liste anahtarlari carpisir.
  id: 'demo-$gonderiId-$yol',
  ad: d.ad,
  kullaniciAdi: d.kullaniciAdi,
  zaman: d.zaman,
  metin: d.metin,
  onayli: d.onayli,
  yazarMi: d.kullaniciAdi == yazarKullaniciAdi,
  sahipBegendi: d.sahipBegendi,
  begeni: d.begeni,
  yorum: d.yorum,
  repost: d.repost,
  paylas: d.paylas,
  begendim: d.begendim,
  medya: d.medya,
  medyaTur: d.medyaTur,
  yanitlar: [
    for (var i = 0; i < d.yanitlar.length; i++)
      demoYorumGorunumu(
        d.yanitlar[i],
        gonderiId: gonderiId,
        yazarKullaniciAdi: yazarKullaniciAdi,
        yol: '$yol.$i',
      ),
  ],
);

/// Detay ve panel icin hazir liste.
///
/// ⚠️⚠️ **SIRALAMA KARARLI OLMAK ZORUNDA.** Dart'in `List.sort`u kararsizdir
///	(introsort): esit begenili iki yorum her `setState`te YER DEGISTIREBILIR
///	ve kullanici listeyi "titriyor" olarak gorur. Bu yuzden siralama
///	`(anahtar, ozgunIndeks)` ikilisi uzerinden yapilir.
/// ⚠️ Yazarin kendi yanitlari BASA alinir (Threads deseni: gonderi sahibinin
///    cevabi konusmanin baglamidir).
List<YorumGorunum> demoYorumGorunumleri(
  String gonderiId,
  String yazarKullaniciAdi, {
  bool begeniyeGore = true,
}) {
  final ham = demoYorumlar(gonderiId);
  final l = [
    for (var i = 0; i < ham.length; i++)
      demoYorumGorunumu(
        ham[i],
        gonderiId: gonderiId,
        yazarKullaniciAdi: yazarKullaniciAdi,
        yol: '$i',
      ),
  ];
  if (!begeniyeGore) return l;
  final indeks = {for (var i = 0; i < l.length; i++) l[i].id: i};
  l.sort((a, b) {
    if (a.yazarMi != b.yazarMi) return a.yazarMi ? -1 : 1;
    final f = b.begeni.compareTo(a.begeni);
    if (f != 0) return f;
    return indeks[a.id]!.compareTo(indeks[b.id]!);
  });
  return l;
}
