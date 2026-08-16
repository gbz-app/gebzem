library;

import '../chats/anket.dart';
import 'sosyal_servisi.dart';
import 'story_servisi.dart';

/// ⚠️⚠️⚠️ TURU 98 — **TASARIM DEMOSU** (kullanici emri: *"içeriklerin hepsini
///	sil anasayfadan, gri içerikler olsun; paylaşım, ses dosyası, konum vs
///	hepsi görünsün; story alanında story atmış biri olsun, canlı yayında
///	biri olsun — demo gibi düşün, nasıl durduğuna bakacağım"*).
///
/// **AMAC:** akisin TUM icerik turlerini (yazi · tek foto · galeri · video ·
/// ses · anket · konum) GERCEK kart yerlesimiyle yan yana gormek.
///
/// ⚠️⚠️⚠️ **BU BIR GORUNUM DEMOSUDUR, OZELLIK DEGILDIR.**
///	`kDemoAkis` **`false` OLDUGUNDA HICBIR ETKISI YOKTUR** ve yayina bu
///	sekilde cikar. Bu projede "arayuz var, veri yok" en pahali hata sinifi
///	(CLAUDE.md'de ALTI kez kayitli); sahte icerigin SESSIZCE yayina
///	sizmamasi icin tek bir bayrakla kapatilabilir olmasi SART.
///
/// ⚠️ **MEDYA KIMLIKLERI KASITLI OLARAK GECERSIZ** (`demo-...`): sunucuda
///	karsiligi olmadigi icin `MedyaGorsel` yer tutucu **GRI KUTU** cizer —
///	kullanicinin istedigi *"gri içerikler"* tam olarak budur. Sahte fotograf
///	uretmek yerine bosluk gosterilir; boylece demo, GERCEK icerikle
///	karistirilmaz.
///
/// ⚠️ YAPMA: bu dosyadaki veriyi sunucuya yazma ya da `kDemoAkis`i kalici
///    `true` birakip yayin alma.
/// Demo modu. **Yayinda `false` olmali.**
const bool kDemoAkis = true;

const _kBenimId = 'demo-ben';

Gonderi _g({
  required String id,
  required String tur,
  required String metin,
  List<String> medya = const [],
  List<String> turler = const [],
  String konum = '',
  Anket? anket,
  int begeni = 0,
  int yorum = 0,
  int goruntulenme = 0,
  int paylasim = 0,
  int repost = 0,
  int saatOnce = 1,
  String yazar = 'Ayşe Demir',
  String kullaniciAdi = 'aysedemir',
}) =>
    Gonderi(
      id: id,
      yazarId: 'demo-$id',
      tur: tur,
      metin: metin,
      mediaIds: medya,
      mediaKinds: turler,
      duzenlendi: false,
      konum: konum,
      begeniSayisi: begeni,
      yorumSayisi: yorum,
      goruntulenme: goruntulenme,
      yorumKapali: false,
      createdAt: DateTime.now()
          .subtract(Duration(hours: saatOnce))
          .toIso8601String(),
      yazarAd: yazar,
      yazarUsername: kullaniciAdi,
      yazarAvatar: '',
      yazarAvatarMediaId: null,
      begendim: false,
      kaydettim: false,
      anket: anket,
      paylasimSayisi: paylasim,
      repostSayisi: repost,
    );

/// Akista gosterilecek demo gonderiler — **her icerik turunden bir ornek**.
List<Gonderi> demoGonderiler() => [
      // 1) TEK FOTOGRAF + yuksek sayilar (kullanici: *"bazı gönderilerde
      //    1.2 bin beğeni yorum paylaşım olsun"*).
      _g(
        id: 'foto',
        tur: 'foto',
        metin: 'Gebze sahilinde gün batımı 🌇 — bugün hava harikaydı.',
        medya: const ['demo-foto-1'],
        turler: const ['image'],
        begeni: 1243,
        yorum: 1200,
        paylasim: 1200,
        repost: 340,
        goruntulenme: 18400,
        saatOnce: 2,
      ),
      // 2) GALERI (3 medya) — yandaki medyanin sarkmasi burada gorunur.
      _g(
        id: 'galeri',
        tur: 'foto',
        metin: 'Hafta sonu kahvaltı turu ☕',
        medya: const ['demo-g-1', 'demo-g-2', 'demo-g-3'],
        turler: const ['image', 'image', 'image'],
        begeni: 312,
        yorum: 47,
        paylasim: 18,
        repost: 7,
        goruntulenme: 5200,
        saatOnce: 5,
        yazar: 'Mehmet Kaya',
        kullaniciAdi: 'mehmetkaya',
      ),
      // 3) VIDEO
      _g(
        id: 'video',
        tur: 'video',
        metin: 'Yeni dükkânın açılışı! 🎉',
        medya: const ['demo-video-1'],
        turler: const ['video'],
        begeni: 1200,
        yorum: 208,
        paylasim: 96,
        repost: 1200,
        goruntulenme: 32100,
        saatOnce: 7,
        yazar: 'Kuaför Serkan',
        kullaniciAdi: 'kuaforserkan',
      ),
      // 4) SES (audio) — ses kartinin akista nasil durdugu.
      _g(
        id: 'ses',
        tur: 'foto',
        metin: 'Kısa bir ses notu 🎧',
        medya: const ['demo-ses-1'],
        turler: const ['audio'],
        begeni: 86,
        yorum: 12,
        goruntulenme: 940,
        saatOnce: 9,
        yazar: 'Zeynep Ak',
        kullaniciAdi: 'zeynepak',
      ),
      // 5) KONUM
      _g(
        id: 'konum',
        tur: 'yazi',
        metin: 'Buradayız, bekleriz!',
        konum: 'Gebze, Kocaeli',
        begeni: 54,
        yorum: 6,
        goruntulenme: 610,
        saatOnce: 11,
        yazar: 'Gebze Kebap Salonu',
        kullaniciAdi: 'gebzekebap',
      ),
      // 6) ANKET
      _g(
        id: 'anket',
        tur: 'yazi',
        metin: 'Akşam nereye gidelim?',
        begeni: 1200,
        yorum: 340,
        goruntulenme: 12800,
        saatOnce: 14,
        yazar: 'Usta Döner & Pide',
        kullaniciAdi: 'ustadoner',
        anket: const Anket(
          id: 1,
          soru: 'Akşam nereye gidelim?',
          olusturanId: _kBenimId,
          coklu: false,
          kapali: false,
          seq: 1,
          toplamOy: 184,
          secenekler: [
            AnketSecenek(id: 1, metin: 'Sahil', oy: 96, benim: false),
            AnketSecenek(id: 2, metin: 'Merkez', oy: 58, benim: false),
            AnketSecenek(id: 3, metin: 'Ev', oy: 30, benim: false),
          ],
        ),
      ),
      // 7) SADECE YAZI
      _g(
        id: 'yazi',
        tur: 'yazi',
        metin:
            'Bugün Gebze’de trafik çok rahat. Sabah çıkanlar şanslı 🙂',
        begeni: 23,
        yorum: 3,
        goruntulenme: 210,
        saatOnce: 16,
        yazar: 'Ali Yıldız',
        kullaniciAdi: 'aliyildiz',
      ),
    ];

/// Hikaye seridi demosu — biri **hikaye atmis**, biri **canli yayinda**.
///
/// ⚠️ `canli` alani `StoryKullanici`de YOKTUR; canli rozeti demo icin
///    kullanici adindan turetilir (bkz. `story_seridi` demo dali).
List<StoryKullanici> demoStoryler() => [
      StoryKullanici(
        userId: 'demo-s1',
        ad: 'Elif',
        kullaniciAdi: 'elif',
        avatarMediaId: null,
        adet: 2,
        hepsiIzlendi: false,
        benim: false,
      ),
      StoryKullanici(
        userId: 'demo-canli',
        ad: 'Burak',
        kullaniciAdi: 'burak',
        avatarMediaId: null,
        adet: 1,
        hepsiIzlendi: false,
        benim: false,
      ),
      StoryKullanici(
        userId: 'demo-s2',
        ad: 'Deniz',
        kullaniciAdi: 'deniz',
        avatarMediaId: null,
        adet: 1,
        hepsiIzlendi: true,
        benim: false,
      ),
    ];

/// ⚠️⚠️ TURU 98b — SERITTEKI **YAYIN DURUMU** (kullanici emri: *"canli
///	yayin KIRMIZI, sesli oda MOR olsun, ikon koy"*).
///
/// ⚠️ Bu bilgi bugun sunucudan GELMIYOR (`StoryKullanici`de boyle bir alan
///    yok). Demo icin kullanici kimliginden turetilir; gercek ozellik
///    yazilirken serit yaniti bir `durum` alani dondurmeli.
/// Degerler: `canli` (yayin) · `oda` (sesli oda) · `null` (sadece hikaye).
String? demoYayinDurumu(String userId) => demoYayin(userId)?.durum;

/// ⚠️⚠️⚠️ TURU 98c — YAYIN OGESI **IKI KISILIK** (kullanici emri + referans
///	gorseli: *"canlinin yanina birini daha ekle, radüslü, iki kisi olacak;
///	oda da oyle"*).
///
/// Gonderilen referansta oge bir DAIRE degil **KAPSUL**: ust uste binen iki
/// avatar, cevresinde renkli halka ve sag ustte izleyici sayisi rozeti.
/// Ilk kisi yayini/odayi ACAN, ikincisi ona KATILAN.
///
/// ⚠️ Bu bilgi bugun sunucudan GELMIYOR (`StoryKullanici`de katilimci alani
///    yok). Gercek ozellik yazilirken serit yaniti katilimci listesi ve
///    izleyici sayisi dondurmeli; istemci burada UYDURMAZ, demo verisi okur.
({String durum, String ikinciAd, int izleyici})? demoYayin(String userId) =>
    switch (userId) {
      'demo-canli' => (durum: 'canli', ikinciAd: 'Cem', izleyici: 12300),
      'demo-s2' => (durum: 'oda', ikinciAd: 'Naz', izleyici: 486),
      _ => null,
    };
