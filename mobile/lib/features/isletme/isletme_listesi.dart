import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
import 'favorilerim_ekrani.dart';
import 'isletme_filtre.dart';
import 'isletme_kart.dart';
import 'isletme_servisi.dart';
import 'kategori_slider.dart';
import 'yakinimda_ekrani.dart';

/// ⚠️⚠️ TURU 77 — ISLETME REHBERI.
///
/// ⚠️⚠️ BU EKRAN, HAMBURGER MENUDEKI KARTLARIN GITTIGI YERDIR.
///    Turu 76b'de Yemek / Restoran / Alisveris kartlari HICBIR YERE gitmiyordu
///    ("yakında" diyordu) — bu projede tekrar eden "olu dogmus ozellik"
///    sinifiydi. Artik gercek bir listeye baglaniyor.
///
/// ⚠️⚠️ TURU 93 — YAN BOSLUK **TEK KAYNAK** (kullanici emri: *"hepsi bir
///    container icinde sol sag bosluk icinde"*). Header, slider, arama
///    kutusu, 60x60 kartlar, filtre satiri ve isletme kartlari AYNI hizada
///    durur.
/// ⚠️ YAPMA: bu ekranda elle 12/14/16 gibi yatay dolgu yazma — bir tanesi
///    guncellenip otekiler unutuldugunda hizalama SESSIZCE bozulur.
const double kYanBosluk = 16;

/// ⚠️⚠️⚠️ TURU 95 — **DIKEY RITIM: TEK KAYNAK.**
///
///	Kullanici: *"slider inputa yapismis; bu bosluklari yukari, sol, sag
///	guzel bir mimari yap, olculeri duzgun yap"*. HAKLIYDI ve sebebi
///	yapisaldi: dikey bosluklar BES AYRI YERDE, birbirinden habersiz
///	sayilarla yaziliydi —
///	  slider  : hic ust dolgu yok
///	  60x60   : icinde `fromLTRB(.., 12, ..)`
///	  arama   : icinde `fromLTRB(.., 4, ..)`
///	  filtre  : icinde `fromLTRB(.., 10, ..)`
///	  liste   : `fromLTRB(.., 6, ..)`
///	Yani iki oge arasindaki mesafe, o iki ogeden BIRININ ic dolgusuydu;
///	sirayi degistirince (input yukari/asagi) bosluk da rastgele degisiyor
///	ve "yapismis" gorunuyordu.
///
///	YENI KURAL: bolumlerin IC DIKEY DOLGUSU YOKTUR. Aralarindaki mesafe
///	YALNIZCA asagidaki sabitle, sliver sirasinda verilir.
/// ⚠️ YAPMA: bu ekrandaki bir bolume tekrar ust/alt dolgu yazma; mesafeyi
///    sliver arasina koy.
///
/// ⚠️⚠️⚠️ TURU 96 — **UC SABIT TEKE INDI** (kullanici emri: *"slider
///	altindaki kategori arasindaki boslugu 2px arttir ve BUTUN SATIRLAR
///	AYNI BOSLUK olsun; yani slider, altindaki kartlar, onlarin altindaki
///	input arasindaki bosluk HEPSI ESIT olmali"*).
///
///	Turu 95'te ritim uc kademeye (10/14/18) ayrilmisti; niyet "gorsel
///	agirlikli bloktan sonra daha genis nefes" idi. Ekranda sonuc AYRI
///	gorunuyordu: bes bolum arasinda UC FARKLI mesafe olunca goz duzenli
///	bir izgara DEGIL, rastgele araliklar goruyordu.
///	Artik **TEK deger: 16** (14 + kullanicinin istedigi 2).
/// ⚠️ YAPMA: buraya ikinci bir bosluk sabiti ekleme; bir bolum icin
///    "biraz daha genis olsun" diye ozel sayi yazma.
const double kBosluk = 16;

/// ⚠️⚠️⚠️ TURU 96 — ARAMA SATIRININ **TEK YUKSEKLIGI** (kullanici emri:
///	*"input ve sagdaki daireler AYNI YUKSEKLIKTE olacak"*).
///
///	Eskiden input yuksekligi DOLAYLIYDI: `contentPadding` 14+14 ustune
///	temanin yazi yuksekligi (M3 `bodyLarge` = 16px x 1.5 = 24) binince
///	**~52px** cikiyordu; yanindaki daireler ise elle 48 yazilmisti. Yani
///	iki komsu oge, birbirinden habersiz iki AYRI yoldan olculuyordu ve
///	kullanicinin gordugu 4px'lik kayma bundan geliyordu.
///
///	Artik ikisi de bu sabitten besleniyor ve input yuksekligi ACIKCA
///	dayatiliyor (`SizedBox`) — yani yazi tipi/tema degisse bile kayamaz.
/// ⚠️ Yaricap buradan TUREMEZ: ekrandaki her oge `kYaricap` kullanir.
/// ⚠️ YAPMA: daire ya da input yuksekligini elle yazma.
const double kInputBoy = 48;

/// ⚠️⚠️⚠️ TURU 96 — ALT KATEGORI KARTININ IKI OLCUSU **ACIKCA** (kullanici
///	emri: *"kartlar vb. bunlar ayni hizada degil; slider vs. HEPSI ayni
///	hizada olmali"*).
///
///	SORUNUN KOKU: gorsel kutu 60, hucre 78 ve kutu hucrenin ORTASINDA.
///	Serit `kYanBosluk`(16) dolguyla cizilince ILK KUTUNUN sol kenari
///	16 + (78-60)/2 = **25**'te basliyordu; slider, arama kutusu ve liste
///	ise 16'da. Yani kod "ayni yan bosluk" veriyordu ama EKRANDA 9px kayma
///	vardi — kullanicinin gordugu tam buydu.
///
///	FIX: seridin dolgusu `kYanBosluk - kAltIcBosluk` olur; boylece ILK
///	KUTUNUN sol kenari tam 16, SON KUTUNUN sag kenari tam `genislik-16`.
/// ⚠️ Serit YATAY KAYDIGI icin bu kucultulmus dolgu gorunmez (kaydirma
///    payidir, gorsel hiza degil).
/// ⚠️ YAPMA: bu ikisinden birini degistirip otekini birakma; hiza
///    `kAltIcBosluk` uzerinden TURETILIYOR.
const double kAltKutu = 60; // gorsel kutu (kare)
const double kAltHucre = 78; // kutu + altindaki yazi alani
const double kAltIcBosluk = (kAltHucre - kAltKutu) / 2; // = 9

/// ⚠️⚠️⚠️ TURU 96 — **BOLUMLERIN IC PAYI ARALIKTAN DUSULUR.**
///
/// Iki bolum DOKUNMA ALANI icin kendi icinde bos pay tasiyor:
///	· header  : dokunma 44, gorsel daire 34 -> altta **5** bos
///	· cip serit: serit 40, cip 32          -> altta/ustte **4** bos
/// Bu paylar KALDIRILAMAZ (Material 48 / Apple 44 kurali), ama sliver
/// araligina `kBosluk` yazilirsa EKRANDA gorunen mesafe 21 ve 20 olur —
/// yani kod "hepsi 16" derken goz "hepsi farkli" gorur. Kullanicinin
/// *"butun satirlar ayni bosluk"* emrinin karsiligi: aralik = `kBosluk`
/// EKSI o bolumun ic payi.
/// ⚠️ YAPMA: bir bolumun dokunma alanini kucultup "duzelttim" deme; payi
///    ARALIKTAN dus.
const double kHeaderPay = 5; // (44 - 34) / 2
const double kCipPay = 4; // (40 - 32) / 2

// ⚠️ `kYuzeyGri` `isletme_kart.dart`a TASINDI (tek kaynak): kart ve bu
//    ekran ayni griyi kullanmak ZORUNDA.

/// [kategori] bos ise TUM isletmeler; doluysa o kategori.
class IsletmeListesiEkrani extends ConsumerStatefulWidget {
  const IsletmeListesiEkrani({super.key, this.kategori = '', this.baslik = ''});

  final String kategori;
  final String baslik;

  @override
  ConsumerState<IsletmeListesiEkrani> createState() =>
      _IsletmeListesiEkraniState();
}

class _IsletmeListesiEkraniState extends ConsumerState<IsletmeListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;

  /// Bayat yanit kapisi — yanitlar SIRASIZ donebilir (kesfet ekraniyla ayni desen).
  int _istekNo = 0;

  /// ⚠️⚠️⚠️ **SLIDER HIC CIZILMIYORDU — AYRI SAYAC ZORUNLU.**
  ///
  ///	`_kesfiYukle` ile `_yukle` AYNI `_istekNo` sayacini paylasiyordu ve
  ///	ikisi de `initState`te ARDISIK cagriliyor:
  ///	   `_kesfiYukle()` -> jeton 1 · `_yukle()` -> jeton 2
  ///	Kesif yaniti donunce `1 != 2` cikip **SESSIZCE ATILIYORDU**. Yani
  ///	slider ve 60x60 serit **HICBIR ZAMAN** cizilmiyordu.
  /// ⚠️ YAPMA: bu iki sayaci tekrar birlestirme. Farkli iki istegin bayatlik
  ///    kapisi AYRI olmak ZORUNDA.
  int _kesifNo = 0;

  List<IsletmeOzet>? _liste;
  String? _hata;
  late String _kategori = widget.kategori;

  /// ⚠️⚠️ TURU 78 — HIZLI KARTLAR ("Şehrimde" / "Onaylı").
  ///
  /// Kullanici emri: "altta kucuk kartlar mesela yemekte yakinimda favoriler
  /// vs diye kartlar olsun".
  ///
  /// ⚠️⚠️ "YAKINIMDA" YERINE "ŞEHRİMDE" — bu bilincli ve DURUST bir karar:
  ///    GPS icin `AndroidManifest.xml`de `ACCESS_*_LOCATION`, `Info.plist`te
  ///    `NSLocation*` anahtarlari YOK. Podfile olmadigi icin
  ///    `permission_handler`in TUM izin isleyicileri derleniyor ve anahtar
  ///    eksikken konum istenirse **iOS uygulamayi ANINDA SONLANDIRIR**.
  ///    Ayrica sistemde tek bir gercek koordinat da yok (bkz. FAZ 0 koordinat
  ///    ezme duzeltmesi). Il/ilce ile ayni isi BUGUN goruyoruz; GPS ayri tur.
  ///    ⚠️ YAPMA: izin anahtarlarini eklemeden konum paketi cagirma.
  String _hizli = '';

  /// Kullanicinin kendi ilcesi — "Şehrimde" kartinin kaynagi.
  /// ⚠️ Bos ise kart CIZILMEZ (olu kart birakmiyoruz).
  String _benimIlce = '';

  /// ⚠️⚠️ TURU 92 — KESIF VERISI **SUNUCUDAN** (alt kategoriler + slaytlar).
  ///    Istemciye sabit yazmak turu 77'nin "Dart'a kategori sabiti YAZMA"
  ///    kuralinin ihlali olurdu ve yeni bir alt kategori eklemek MAGAZA
  ///    ONAYI gerektirirdi.
  /// ⚠️ TEK ISTEK: alt kategoriler ve slayt metinleri AYNI uctan gelir —
  ///    ekran acilisinda iki istek atmak turu 91'de olculen "acilistaki
  ///    es zamanli istek" maliyetini artirirdi.
  List<({String ad, String ara})> _altKategoriler = const [];
  List<({String baslik, String alt})> _slaytlar = const [];

  /// Secili alt kategori (arama metni). Bos = hicbiri.
  String _altSecili = '';

  /// ⚠️⚠️ TURU 96 — FILTRE EKRANININ SECIMLERI (kullanici emri).
  ///    Nesne SABIT kalir, icerigi sheet uzerinde degisir; `_gosterilen`
  ///    her cizimde bunu ham listeye UYGULAR.
  final _filtre = IsletmeFiltre();

  /// ⚠️⚠️ EKRANDA CIZILEN LISTE = ham liste + filtre.
  ///
  ///	Suzulmus liste AYRI BIR ALANDA TUTULMAZ: tutulsaydi filtre degisince
  ///	onu tazelemeyi unutmak "filtreyi degistirdim, liste ayni kaldi"
  ///	hatasini uretirdi (bu projede "iki kopya drift eder" sinifi).
  /// ⚠️ Ham liste (`_liste`) DEGISMEZ: "Önerilen"e donuldugunde sunucunun
  ///    dondurdugu sira geri gelmeli.
  List<IsletmeOzet>? get _gosterilen {
    final l = _liste;
    return l == null ? null : _filtre.uygula(l);
  }


  /// ⚠️ TURU 94 — GORUNUM: false = liste (tek sutun), true = kart (iki sutun).
  ///    Varsayilan LISTE: genis kapak + tum bilgiler sigar. Izgara,
  ///    "cok isletme var, hizlica tara" durumu icin ikincil bir gorunum.
  bool _izgara = false;

  /// ⚠️⚠️ TURU 96 — KART MESAFESI ICIN CIHAZ KONUMU (kullanici emri).
  ///    `null` = konum bilinmiyor -> kartlarda mesafe CIZILMEZ.
  (double, double)? _konumum;

  @override
  void initState() {
    super.initState();
    _ilceyiOgren();
    _kesfiYukle();
    _yukle();
    _konumuSessizAl();
  }

  /// ⚠️⚠️⚠️ TURU 96 — KONUM **IZIN ISTEMEDEN** okunur.
  ///
  /// Kartta mesafe gostermek icin konum lazim ama ekrana girer girmez izin
  /// diyalogu acmak SALDIRGAN olurdu: kullanici "İşletmeler"e bakmak istedi,
  /// konum paylasmak istedigini SOYLEMEDI. Bu yuzden yalnizca izin ZATEN
  /// verilmisse konum alinir; verilmemisse hicbir sey sorulmaz ve kartlarda
  /// mesafe cizilmez.
  /// ⚠️ Izin isteyen TEK yol "Yakınımda" cipidir — orada kullanici mesafeyi
  ///    ACIKCA istemis olur.
  /// ⚠️ YAPMA: buraya `requestPermission` ekleme.
  Future<void> _konumuSessizAl() async {
    try {
      final izin = await Geolocator.checkPermission();
      if (izin != LocationPermission.always &&
          izin != LocationPermission.whileInUse) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      _konumum = (p.latitude, p.longitude);
      // ⚠️ Liste konumdan ONCE gelmis olabilir: mevcut kayitlara da uygulanir.
      final l = _liste;
      if (l != null) {
        mesafeleriDoldur(l, p.latitude, p.longitude);
        setState(() {});
      }
    } catch (_) {
      // ⚠️ SESSIZ: konum alinamazsa yalnizca mesafe cizilmez.
    }
  }

  /// Kullanicinin ilcesini KENDI isletme kaydindan ogrenir.
  ///
  /// ⚠️ Bu YALNIZ isletme hesaplarinda dolu olur. Kisisel hesapta ilce bilgisi
  ///    HICBIR YERDE tutulmuyor — o yuzden "Şehrimde" karti onlarda CIZILMEZ.
  ///    Sahte bir varsayilan ("Gebze") koymak YANLIS olurdu: kullanici baska
  ///    ilcedeyse liste yanlis gelir ve sebebini anlamaz.
  Future<void> _ilceyiOgren() async {
    // ⚠️⚠️ TURU 78b — SAGLAYICI HENUZ COZULMEMISSE **BEKLENIR** (denetim).
    //    `myProfileProvider` bir `FutureProvider`dir; `initState`ten cagrilan
    //    bu metot `valueOrNull`u okuyup null bulunca SESSIZCE cikiyordu ve
    //    TEKRAR DENEYEN HICBIR SEY YOKTU -> ekran soguk acildiginda "Şehrimde"
    //    karti KALICI OLARAK cizilmiyordu (ozellik rastgele "yok" gorunuyordu).
    var id = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '').toString();
    if (id.isEmpty) {
      try {
        final p = await ref.read(myProfileProvider.future);
        id = (p['id'] ?? '').toString();
      } catch (_) {
        return; // profil alinamadi: kart cizilmez (durust davranis)
      }
    }
    if (!mounted || id.isEmpty) return;
    try {
      final i = await ref.read(isletmeServisiProvider).detay(id);
      if (mounted && i != null && i.ilce.isNotEmpty) {
        setState(() => _benimIlce = i.ilce);
      }
    } catch (_) {
      // ⚠️ SESSIZ: ilce ogrenilemezse yalnizca "Şehrimde" karti cizilmez.
    }
  }

  /// Alt kategorileri ve slayt metinlerini sunucudan alir.
  ///
  /// ⚠️ HATA SESSIZ: kesif verisi gelmezse slider VARSAYILAN metinlerle
  ///    (sunucu zaten oyle donuyor) ve alt kategori seridi CIZILMEDEN
  ///    calisir. Ekranin ASIL isi (isletme listesi) bundan BAGIMSIZ.
  Future<void> _kesfiYukle() async {
    // ⚠️⚠️ TURU 93b — BAYAT YANIT KAPISI (denetim: kardes metotta VARDI,
    //	BURADA YOKTU).
    //
    //	Kullanici filtre sheet'inde ChoiceChip'ler yan yana oldugu icin
    //	hizlica "Yemek" -> "Kuaför" secebiliyor. Iki `kesif` istegi PARALEL
    //	ucar; Yemek'in yaniti GEC gelirse Kuaför'un uzerine YAZAR. Ekranda
    //	"Kuaför" cipi SECILI gorunur ama alt kategori kartlari
    //	**Döner/Kebap/Pide** olur. Kullanici "Döner"e basar ->
    //	`kategori=kuafor` + `q=döner` -> **KALICI BOS LISTE**, sebebi
    //	ekranda hicbir yerde yazmaz.
    // ⚠️⚠️ **AYRI SAYAC** (`_kesifNo`): `_yukle` ile paylasilirsa ikisi de
    //    `initState`te ardisik cagrildigi icin kesif yaniti DAIMA bayat
    //    sayilir ve slider HIC CIZILMEZ (bkz. `_kesifNo` serhi).
    final jeton = ++_kesifNo;
    try {
      final d = await ref.read(isletmeServisiProvider).kesif(_kategori);
      if (!mounted || jeton != _kesifNo) return;
      setState(() {
        _altKategoriler = d.altKategoriler;
        _slaytlar = d.slaytlar;
      });
    } catch (_) {
      // ⚠️ SESSIZ: slider ve serit cizilmez, ekranin ASIL isi (liste)
      //    bundan bagimsiz calisir. Kurtarma yolu asagi-cek (`_tazele`).
    }
  }

  /// ⚠️⚠️ TURU 93b — KATEGORI DEGISTIRMENIN **TEK KAPISI** (denetim).
  ///
  /// Onceden kategori UC ayri yerde yaziliyordu ve `_altSecili` sifirlamasi
  /// YALNIZ BIRINDE vardi:
  ///   · kategori cipi secimi          -> `_altSecili = ''`  ✓
  ///   · "Tümü" cipi                   -> **YOK**
  ///   · `InputChip.onDeleted` (✕)     -> **YOK**
  ///
  /// Sonuc: "Yemek → Döner" seciliyken "Tümü"ye basan kullanicida
  /// `_altSecili='döner'` KALIYORDU. Yeni kategoride o kart LISTEDE
  /// OLMADIGI icin secili gorunmuyor bile — yani **GORUNMEZ bir suzgec**
  /// takili kaliyor ve kullanici neden az sonuc gordugunu EKRANDA HICBIR
  /// YERDE goremiyordu.
  ///
  /// ⚠️ Duzeltmenin dogru yeri "ucuncu dala da o satiri ekle" DEGIL, tek
  ///    kapiya indirmektir: dordunc bir dal eklendiginde ayni hata
  ///    tekrarlanmasin.
  /// ⚠️ YAPMA: `_kategori`ye bu metodun DISINDA atama yapma.
  void _kategoriSec(String k) {
    setState(() {
      _kategori = k;
      _altSecili = '';
    });
    _gecikme?.cancel();
    _kesfiYukle();
    _yukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final jeton = ++_istekNo;
    try {
      final svc = ref.read(isletmeServisiProvider);

      // ⚠️⚠️ "YAKINIMDA" **AYRI UC** kullanir (`/isletmeler/yakinimda`):
      //	mesafeye gore siralama sunucuda, kaba kutu + Haversine ile
      //	yapiliyor. Istemcide siralamak YANLIS olurdu — sunucu `LIMIT`
      //	donduruyor ve istemci elindeki 60 kaydi siralasa "en yakin"
      //	garantisi OLMAZDI.
      // ⚠️ Konum alinamazsa (izin yok / GPS kapali) cip SESSIZCE
      //    DUSURULMEZ: kullaniciya sebep soylenir ve normal liste gosterilir.
      //    Sessizce normal listeye donmek, "yakinimda calismiyor" hissi
      //    verir ve kullanici sebebini goremezdi.
      if (_hizli == 'yakinimda') {
        final k = await _konumAl();
        if (!mounted || jeton != _istekNo) return;
        if (k != null) {
          // ⚠️ Kullanici burada izni ACIKCA verdi; kartlarda mesafe artik
          //    normal listede de cizilebilir.
          _konumum = k;
          final yl = await svc.yakinimda(
            enlem: k.$1,
            boylam: k.$2,
            kategori: _kategori,
          );
          if (!mounted || jeton != _istekNo) return;
          setState(() {
            _liste = yl;
            _hata = null;
          });
          return;
        }
        // Konum yok: cipi birak, normal listeye dus.
        setState(() => _hizli = '');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Konum alınamadı. Ayarlardan konum iznini açabilirsin.'),
        ));
      }

      final l = await svc
          .liste(
            kategori: _kategori,
            // ⚠️ ALT KATEGORI **ARAMA METNINE** cevrilir (ayri sutun YOK —
            //    gerekce sunucudaki `altkategori.go` serhinde). Kullanici
            //    hem kart secip hem yazi yazabilir; ikisi BIRLESTIRILIR.
            q: [_altSecili, _arama.text.trim()]
                .where((x) => x.isNotEmpty)
                .join(' '),
            // ⚠️ Hizli kart suzgecleri SUNUCUYA gider. Istemcide suzmek YANLIS
            //    olurdu: sunucu `LIMIT 60` donuyor, istemci 3'e dusurseydi
            //    kullanici "sadece 3 isletme var" sanirdi.
            ilce: _hizli == 'sehrimde' ? _benimIlce : '',
            yalnizOnayli: _hizli == 'onayli',
          );
      if (!mounted || jeton != _istekNo) return;
      // ⚠️ MESAFE: sunucu bu ucta hesaplamiyor (siralama mesafeye gore DEGIL),
      //    o yuzden istemcide doldurulur. Konum yoksa hicbir sey yazilmaz.
      final k = _konumum;
      if (k != null) mesafeleriDoldur(l, k.$1, k.$2);
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'İşletmeler alınamadı');
    }
  }

  /// Konumu alir; izin yoksa ister. Basarisizsa `null`.
  ///
  /// ⚠️ `geolocator` ZATEN projede (Yakinimda ekrani kullaniyor) — yeni
  ///    paket eklenmedi.
  /// ⚠️ Hata YUTULUR ama `null` doner: cagiran taraf kullaniciya SEBEP
  ///    gosterir. Sessizce normal listeye dusmek "calismiyor" hissi verirdi.
  Future<(double, double)?> _konumAl() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          // ⚠️ ZAMAN ASIMI ZORUNLU: kapali alanda GPS SONSUZA KADAR
          //    bekleyebilir ve liste "yukleniyor"da kalirdi.
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  void _aramaDegisti(String _) {
    _gecikme?.cancel();
    // ⚠️ 320ms gecikme — her tusa basista istek atmak sunucuyu bosuna yorar.
    _gecikme = Timer(const Duration(milliseconds: 320), _yukle);
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ HAM liste degil **SUZULMUS** liste cizilir (bkz. `_gosterilen`).
    final l = _gosterilen;
    return Scaffold(
      // ⚠️⚠️⚠️ TURU 92 — **APPBAR KALDIRILDI** (kullanici emri: *"'Yemek'
      //    yazisi gerek yok, sadece GERI IKONU"*). Baslik slider'in
      //    kendisinde degil, HIC YOK; geri ve harita ikonlari slider'in
      //    USTUNDE yuzuyor.
      // ⚠️ `extendBodyBehindAppBar` GEREKMEZ cunku AppBar YOK; slider
      //    dogrudan ekranin tepesinden baslar ve durum cubugunun altina
      //    girer — ikonlar `MediaQuery.paddingOf(context).top` ile
      //    guvenli alana konumlanir.
      // ⚠️⚠️ TURU 93 — HER SEY **TEK YATAY DOLGUDA** (kullanici emri:
      //    *"hepsi bir container icinde sol sag bosluk icinde"*).
      //    `kYanBosluk` TEK KAYNAK: header, slider, arama, kartlar ve
      //    filtreler AYNI hizada durur. Ayri ayri sayilar yazilsaydi biri
      //    guncellenip otekiler unutulurdu.
      // ⚠️⚠️⚠️ TURU 93b — GOVDE **KAYDIRILABILIR** OLDU (denetimde yakalanan
      //    IKINCI SEVK ENGELI).
      //
      //	Onceki hal bir `Column` + `Expanded(liste)` idi. `Expanded`in
      //	USTUNDEKI SABIT bloklar olculdu:
      //
      //	   header 48 + bosluk 10 + slider 350 + arama ~58
      //	   + 60x60 serit 92 + filtre satiri 56  =  **614 px**
      //
      //	· 360x800 (en yaygin modern Android, kullanilabilir ~776):
      //	  listeye **162px** kaliyor. Bir kart ~250px (16:9 kapak + ad +
      //	  meta) -> kapagin bir kismi gorunuyor, **AD VE META HIC
      //	  GORUNMUYOR**.
      //	· 360x640 + 3 tus navigasyon (~568): `Expanded` NEGATIF alan alir
      //	  -> **RenderFlex overflowed** sari-siyah serit.
      //	· 414x896 (test cihazi): 238px — yine tek kart bile tam sigmiyor.
      //
      //	Yani "kategori ekrani bastan tasarlandi" denen ekranda kullanici
      //	KAYDIRMADAN TEK BIR ISLETME ADI GOREMIYORDU.
      //
      // ⚠️ FIX: slider + arama + 60x60 serit + filtre satiri artik LISTENIN
      //    KENDISININ parcasi (`CustomScrollView` slaytlari). Yemeksepeti/
      //    Getir de boyle yapar: ust blok yukari kayip gider, liste ekranin
      //    TAMAMINI kullanir.
      // ⚠️ Slider yuksekligi (350) **DEGISTIRILMEDI** — kullanicinin verdigi
      //    olcu. Sorun yuksekligin kendisi degil, SABIT bir dikey butceyi
      //    listeden CALMASIYDI.
      // ⚠️ `AlwaysScrollableScrollPhysics` ZORUNLU: icerik ekrandan kisa
      //    oldugunda (bos liste / hata) asagi-cek-yenile CALISMAZ (turu 83b
      //    dersi — dort kardes ekranda ayni sinif duzeltilmisti).
      // ⚠️ YAPMA: bunu tekrar `Column` + `Expanded`e cevirme.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ⚠️ Header SABIT kalir: geri dugmesi HER ZAMAN erisilebilir
            //    olmali (kaydirinca kaybolan bir geri tusu tuzaktir).
            _header(),
            Expanded(
              child: YenileSarmali(
                // ⚠️ TURU 93b — YENILEME **IKISINI DE** tazeler. Eskiden
                //    yalniz `_yukle` cagriliyordu; kesif istegi hata verirse
                //    350px BOS GRI KUTU kaliyor ve kullanicinin onu
                //    duzeltecek HICBIR yolu olmuyordu.
                onRefresh: _tazele,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── HEADER -> SLIDER ──
                    // ⚠️ Header'in ALTINDA 5px kendi payi var (bkz.
                    //    `kHeaderPay`): ekranda gorunen bosluk yine 16.
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk - kHeaderPay)),

                    // ⚠️⚠️ SLAYT YOKSA SLIDER HIC CIZILMEZ: istek patlarsa
                    //    `_slaytlar` bos kalir ve `PageView` 0 ogeyle
                    //    cizilir -> ekranin tepesinde ICI BOS gri dikdortgen.
                    if (_slaytlar.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kYanBosluk),
                          child: KategoriSlider(slaytlar: _slaytlar),
                        ),
                      ),
                      // ⚠️ TURU 96 — bu bosluk artik OTEKILERLE BIREBIR AYNI
                      //    (kullanici emri); slider'a ozel genis nefes YOK.
                      const SliverToBoxAdapter(
                          child: SizedBox(height: kBosluk)),
                    ],

                    // ── ALT KATEGORI KARTLARI (60x60) ──
                    SliverToBoxAdapter(child: _altKategoriSeridi()),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk)),

                    // ── ARAMA + GORUNUM + HARITA ──
                    // ⚠️ Kullanici emri: *"inputu kartlarin altina koy"*.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kYanBosluk),
                        child: Row(
                          children: [
                            Expanded(child: _aramaKutusu()),
                            const SizedBox(width: 10),
                            _gorunumAnahtari(),
                            const SizedBox(width: 8),
                            // ⚠️ Harita, gorunum anahtariyla ayni dilde:
                            //    gri daire (kullanici emri).
                            _daireDugme(
                              LucideIcons.map,
                              'Haritada gör',
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      YakinimdaEkrani(kategori: _kategori),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ⚠️ Cip seridinin USTUNDE 4px kendi payi var
                    //    (bkz. `kCipPay`): gorunen bosluk yine 16.
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk - kCipPay)),

                    // ── HIZLI SUZGECLER ──
                    SliverToBoxAdapter(child: _filtreSatiri()),
                    // ⚠️ Cip seridinin ALTINDA da 4px pay var.
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk - kCipPay)),

                    if (_hata != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Text(_hata!,
                                  style: const TextStyle(color: Colors.grey)),
                              TextButton(
                                // ⚠️ IKISI BIRDEN: kesif verisi de bu
                                //    hatadan etkilenmis olabilir.
                                onPressed: _tazele,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (l == null)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    // ⚠️⚠️ TURU 96 — BOS MESAJI **SEBEBE GORE** degisir.
                    //	Filtre listeyi bosalttiginda "bu kategoride henuz
                    //	isletme yok, ilk isletme sen ol" demek YANLIS BILGI
                    //	olurdu: isletme VAR, suzgecten gecmedi. Kullanici
                    //	sebebini goremez ve kurtarma yolunu (filtreyi
                    //	temizle) bulamazdi.
                    else if (l.isEmpty && _filtre.aktifSayi > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            children: [
                              const Text(
                                'Seçtiğin filtrelere uyan işletme bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _filtre.temizle()),
                                child: const Text('Filtreleri temizle'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (l.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'Bu kategoride henüz işletme yok.\n'
                            'İlk işletme sen ol: Profil → İşletme hesabı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      // ⚠️ TURU 93 — AYIRICI CIZGI KALDIRILDI: kartlar artik
                      //    kendi golgeleriyle ayriliyor (Yemeksepeti/Getir
                      //    deseni). Cizgi + kart ARADA cift ayirici olurdu.
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            kYanBosluk, 0, kYanBosluk, 24),
                        // ⚠️ IKI GORUNUM (kullanici emri: "kart gorunumu").
                        //    Izgarada IKI SUTUN; ucuncusu 360dp'de kapagi
                        //    ~104px'e dusurup okunamaz yapardi.
                        sliver: _izgara
                            ? SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 20,
                                  // ⚠️ Kapak 16:9 + ad + iki bilgi satiri.
                                  //    Dusuk oran metni kirpar, yuksek oran
                                  //    kartlar arasinda bosluk birakir.
                                  childAspectRatio: 0.86,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _izgaraKarti(l[i]),
                                  childCount: l.length,
                                ),
                              )
                            : SliverList.builder(
                                itemCount: l.length,
                                itemBuilder: (_, i) => IsletmeKarti(o: l[i]),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kesif verisi + liste birlikte tazelenir.
  ///
  /// ⚠️ Asagi-cek YALNIZ `_yukle` cagirsaydi, kesif istegi patlamis bir
  ///    ekranda slider ve 60x60 serit KALICI olarak bos kalirdi ve
  ///    kullanicinin ekrani kapatmaktan baska yolu olmazdi.
  Future<void> _tazele() async {
    await Future.wait([_kesfiYukle(), _yukle()]);
  }

  /// ⚠️⚠️ TURU 93 — HEADER: geri (arrow-left) + harita, DAIRE YOK.
  ///
  /// Kullanici emri: *"header'da geri ikonu ARROW-LEFT olsun, sagdaki harita
  /// kalsin, bunlarin ARKASINDAKI DAIRE KALDIR; bunlar bir HEADER olacak"*.
  ///
  /// ⚠️ Daire (opak beyaz zemin) kalkinca ikonlar SAYFA ZEMINI uzerinde
  ///    duruyor — renk TEMADAN alinir; sabit siyah yazilsaydi koyu temada
  ///    GORUNMEZ olurdu.
  /// ⚠️ `IconButton` 48dp dokunma alanini KORUR (gorsel olarak yalniz ikon
  ///    gorunse de); ciplak `Icon` + `GestureDetector` hedefi 24dp'ye
  ///    dusururdu (Material 48 / Apple 44 kurali).
  /// ⚠️⚠️ HEADER — geri · baslik · favoriler · profil.
  ///
  /// Kullanici emri: *"header'daki ikonlar profil dairesi boyutunda olsun,
  /// o dairenin icinde harf yazmasin, rengi slider renginde olsun"*.
  ///
  /// ⚠️ UC OGE DE **AYNI 34dp DAIRE** ve **AYNI GRI** (`kYuzeyGri`): farkli
  ///    boyut/zemin, ayni satirdaki ogeleri "baska bilesenler" gibi
  ///    gosteriyordu.
  /// ⚠️ Profil dairesinde **HARF YOK**: avatar yoksa duz gri daire cizilir.
  ///    Harf, yanindaki iki ikonla ayni dili konusmuyordu.
  /// ⚠️ Dokunma alani daireden BUYUK (44dp): 34dp gorsel, Material'in 48 /
  ///    Apple'in 44 kuralinin altinda kalirdi.
  Widget _header() => Padding(
        // ⚠️⚠️⚠️ TURU 96 — **GORSEL HIZA** (kullanici emri: *"geri ikonu saga
        //	yatmis, o da alttakilerle ayni hizada olsun"*). HAKLIYDI ve
        //	sebebi olculebilir:
        //
        //	Dokunma alani 44, GORSEL daire 34 ve daire kutunun ORTASINDA
        //	-> daire, kutunun sol kenarindan **5px** iceride basliyor. Dolgu
        //	`kYanBosluk` (16) olsaydi dairenin sol kenari **21px**'te olur,
        //	altindaki slider/kart/input ise 16px'te baslardi: header 5px
        //	SAGA KAYMIS gorunurdu.
        //
        //	FIX: dolgu `kYanBosluk - 5`. Boylece SOLDA dairenin sol kenari
        //	tam 16, SAGDA da (ayni 5px'lik ic bosluk simetrik oldugu icin)
        //	dairenin sag kenari tam `genislik - 16`.
        // ⚠️ YAPMA: burayi `kYanBosluk`a dondurme; ya da daire/dokunma
        //    olculerini degistirirsen bu 5'i de yeniden hesapla ((44-34)/2).
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk - 5),
        child: Row(
          children: [
            _headerDaire(
              LucideIcons.arrowLeft,
              'Geri',
              () => Navigator.of(context).maybePop(),
            ),
            if (widget.baslik.isNotEmpty)
              Expanded(
                child: Text(
                  widget.baslik,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const Spacer(),
            // ⚠️⚠️ TURU 96 — **PROFIL DAIRESI KALDIRILDI** (kullanici emri:
            //	*"sag ustteki profil ikonu kaldir"*).
            //
            //	Profil zaten ALT MENUDE var; header'daki ikinci giris hem
            //	gereksizdi hem de bu satirdaki tek KIMLIK tasiyan oge oldugu
            //	icin yanindaki iki notr ikonla ayni dili konusmuyordu.
            // ⚠️ YAPMA: buraya profil/avatar geri koyma.
            _headerDaire(
              LucideIcons.heart,
              'Favorilerim',
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavorilerimEkrani()),
              ),
            ),
          ],
        ),
      );

  /// Header'daki gri daire — ikonlu.
  Widget _headerDaire(IconData ikon, String ipucu, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: ipucu,
        child: GestureDetector(
          // ⚠️ **DALGA YOK**: kullanici "tikladiginda titreme olmasin" dedi.
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            // ⚠️ Dokunma alani 44, GORSEL daire 34.
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kYuzeyGri(context),
                  shape: BoxShape.circle,
                ),
                // ⚠️ 18 -> **20** (kullanici emri: *"geri ve kalp ikonu 2px
                //    daha buyut"*). Daire 34 KALIR: buyuyen ikon, kutu degil
                //    — kutu buyuseydi header'in sol hizasi (bkz. `-5` serhi)
                //    yeniden kayardi.
                child: Icon(ikon, size: 20, color: _notrYazi),
              ),
            ),
          ),
        ),
      );

  /// ⚠️⚠️ TURU 93 — ARAMA KUTUSU (kullanici emri).
  ///
  /// · Odaklaninca kenarlik **TAM SIYAHIN BIR TIK ACIGI** (`0xFF1A1A1A`).
  ///   Varsayilan Material odak rengi TEMA VURGUSU idi; kullanici notr
  ///   istedi.
  /// · Arama ikonu **BIR TIK KALIN**: `size` 19 -> 21 **+ golge hilesi**.
  ///   ⚠️⚠️ `strokeWidth` YOKTUR: `lucide_icons_flutter` ikonlari bir FONT
  ///      olarak sunar (glif), SVG olarak degil — cizgi kalinligi
  ///      ayarlanamaz. Yalniz `size` buyutmek ikonu BUYUTUR ama oransal
  ///      olarak AYNI incelikte birakir.
  ///   ⚠️ Cozum: ayni renkte, ±0.4px kaydirilmis DORT golge. Glif kendi
  ///      uzerine hafifce yayilir ve cizgi KALINLASIR. Bu, font tabanli
  ///      ikonlarda kalinlik simule etmenin standart yolu.
  ///   ⚠️ YAPMA: `Icon`a `strokeWidth` eklemeye calisma — DERLENMEZ.
  /// · Ikon ile yazi arasi **BIR TIK AZ**: `prefixIconConstraints` ile kutu
  ///   daraltilir. Varsayilan `prefixIcon` 48dp'lik bir kutuya oturur ve
  ///   metin ondan SONRA baslar.
  /// ⚠️ Koyu temada siyah kenarlik GORUNMEZ olurdu — tema parlakligina gore
  ///    secilir.
  Widget _aramaKutusu() {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final odak = koyu ? const Color(0xFFE8E8EA) : const Color(0xFF1A1A1A);
    // ⚠️ TEK KAYNAK: cipler de `_notrKenar` kullaniyor.
    final bos = _notrKenar;
    final ikonRenk = koyu ? Colors.white70 : Colors.black87;
    // ⚠️⚠️⚠️ TURU 96 — YUKSEKLIK **EN UZUN COCUKTAN** gelir (emulatorde
    //	olculdu: 33 dp cikiyordu, yanindaki daireler 48'di).
    //
    //	ILK DENEME `SizedBox(height: 48)` ILE SARMAKTI — **CALISMADI** ve
    //	sebebi ogreticidir: `SizedBox` widget'in KAPLADIGI ALANI 48 yapar,
    //	ama `InputDecorator` KENARLIGI `size`a gore degil kendi hesapladigi
    //	`containerHeight`e gore cizer. Yani kutu 48 yer kapliyor, cerceve
    //	33 cizilmeye devam ediyordu: ekranda hem input kisa gorunuyor hem
    //	de altinda 15 dp GORUNMEZ bosluk kaliyordu (o bosluk da alttaki
    //	cip seridiyle arasindaki mesafeyi 30 dp gosteriyordu).
    //
    //	DOGRU YOL: `containerHeight` = en uzun cocugun boyu. Suffix ikonu
    //	`kInputBoy` yuksekliginde bir kutuya alinir, gri daire onun ICINDE
    //	ortalanir -> cerceve GERCEKTEN 48 olur.
    // ⚠️ YAPMA: burayi tekrar `SizedBox`la sarip cozdum sanma; olcup dogrula.
    return TextField(
      controller: _arama,
      onChanged: _aramaDegisti,
      decoration: InputDecoration(
        hintText: 'İşletme ara',
        // ⚠️⚠️ MESAFELER **ACIKCA** VERILIR (kullanici emri: *"arama ikonu
        //	input soluna dayanmis, bu mesafeleri lutfen mimarisini iyi
        //	ayarla"*).
        //
        //	ONCEKI HAL BIR HACKTI: `prefixIconConstraints` ile 38x38'lik bir
        //	kutu zorlaniyor, ikon O KUTUNUN ORTASINA dusuyordu. Kutunun sol
        //	kenari inputun sol kenariyla CAKISTIGI icin ikon kenara YAPISIK
        //	gorunuyordu ve aradaki bosluk DOLAYLI (kutu genisligi eksi ikon
        //	genisliginin yarisi) belirleniyordu — yani sayilar ekranda ne
        //	oldugunu ANLATMIYORDU.
        //
        //	YENI: kisit SIFIRLANIR, bosluklar ikonun KENDI `Padding`inde
        //	yazilir. Artik sayilar birebir ekranda gordugun mesafedir:
        //	  · sol kenar -> ikon      : **16**
        //	  · ikon -> "İşletme ara"  : **10**
        //	  · dikey (yukseklik ~48)  : **14**
        // ⚠️ `contentPadding` yatayda **0**: yatay bosluklarin TEK sahibi
        //    ustteki `Padding` olsun; iki yerden beslenirse toplam mesafe
        //    "neden 24 cikti" sorusuna donusur.
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(
            LucideIcons.search,
            size: 21,
            color: ikonRenk,
            shadows: [
              for (final d in const [
                Offset(0.4, 0),
                Offset(-0.4, 0),
                Offset(0, 0.4),
                Offset(0, -0.4),
              ])
                Shadow(color: ikonRenk, offset: d),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        // ⚠️⚠️ SAGDAKI IKON: **FILTRE**, arkasi hafif gri (kullanici emri:
        //	*"isletme ara inputun icinde sagda arkasi hafif gri icon olsun"*
        //	-> ilk yazimda TEMIZLE ikonu konmustu, kullanici duzeltti:
        //	*"sagda filtre iconu koymamissin"*).
        //
        // ⚠️ **HER ZAMAN GORUNUR** (temizle ikonu gibi metne bagli DEGIL):
        //    filtre bir kesif aracidir, kullanici once onu gorup sonra
        //    aramayi dusunur. Yazi varken kaybolsaydi "filtre nerede"
        //    sorusu dogardi.
        // ⚠️ AKTIF FILTRE VARSA **NOKTA** cizilir: kullanici neden az sonuc
        //    gordugunu anlayabilmeli — rozetsiz filtre, "hic isletme yok"
        //    yanilgisinin en sik sebebidir (eski "Filtre (2)" rozetinin
        //    isini artik bu nokta goruyor).
        // ⚠️ Ton `kYuzeyGri` — ekrandaki tek gri.
        // ⚠️ Bu kutu inputun YUKSEKLIGINI BELIRLER (bkz. ustteki serh):
        //    `kInputBoy` boyunda, gri daire icinde ORTALI.
        suffixIcon: SizedBox(
          height: kInputBoy,
          child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(
            widthFactor: 1,
            child: GestureDetector(
            onTap: _filtreSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kYuzeyGri(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.slidersHorizontal,
                      size: 17, color: ikonRenk),
                ),
                // ⚠️ TURU 96 — panel suzgecleri de SAYILIR: kullanici
                //    "4,5 ve üstü" secip paneli kapatinca listenin neden
                //    kisaldigini gorebilmeli.
                if (_hizli.isNotEmpty ||
                    _altSecili.isNotEmpty ||
                    _filtre.aktifSayi > 0)
                  Positioned(
                    right: 1,
                    top: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        // ⚠️ Kutu ile ayni renkte cerceve: nokta gri dairenin
                        //    kenarinda "yapisik" gorunmesin.
                        border: Border.all(color: kYuzeyGri(context), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        isDense: true,
        // ⚠️ DIKEY DOLGU **0**: yukseklik suffix kutusundan geliyor (bkz.
        //    `kInputBoy`). Burada da deger yazilsaydi ikisi TOPLANIR ve
        //    input dairelerden UZUN olurdu.
        contentPadding: const EdgeInsets.only(right: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap),
          borderSide: BorderSide(color: bos),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap),
          borderSide: BorderSide(color: odak, width: 1.6),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 92 — ALT KATEGORI KARTLARI (kullanici emri: *"aramanin
  ///    altinda soyle kartlar olacak, UFAK kartlar 60x60 RADIUSLU, iste
  ///    doner kebap gibi"*).
  ///
  /// ⚠️ Kart 60x60 KARE + altinda ad. Ad kutunun ICINE yazilsaydi "Lahmacun"
  ///    gibi uzun kelimeler 60px'e SIGMAZDI; disarida iki satira sarabilir.
  /// ⚠️ Liste BOSSA serit HIC CIZILMEZ — her kategoride alt kategori yok
  ///    (bos yatay bosluk birakmiyoruz).
  /// ⚠️ Secili kart TEK: ikinci karta basmak oncekini kapatir. Coklu secim
  ///    "döner kebap" gibi ikisini birden iceren bir arama uretir ve
  ///    neredeyse DAIMA BOS sonuc doner.
  Widget _altKategoriSeridi() {
    if (_altKategoriler.isEmpty) return const SizedBox.shrink();
    // ⚠️⚠️ TURU 93b — YUKSEKLIK **YAZI OLCEGINDEN TURETILIR** (denetim).
    //
    //	Sabit 92px idi. Icerik: 60 (kutu) + 5 (bosluk) + iki satir metin
    //	(11 x 1.15 x 2 = 25.3) = **90.3** -> pay yalnizca **1.7px**.
    //	Android "Yazi tipi boyutu" ayarinin ILK KADEMESI (1.15) bile
    //	2.1px tasirir ve "Lahmacun / Ev Yemeği / Kahvaltı" gibi IKI SATIRA
    //	SARAN adlarda sari-siyah **RenderFlex** seridi cikar.
    // ⚠️ Iki satir bir KENAR DURUM DEGIL, tasarimin NORMAL dali (serh
    //    zaten "disarida iki satira sarabilir" diyor) — yani tasma nadir
    //    degil, YAYGIN olurdu.
    // ⚠️ `textScaler` ile turetmek `MediaQuery`ye baglamak DEMEK DEGILDIR:
    //    olculen sey EKRAN BOYUTU degil KULLANICININ YAZI TERCIHI.
    final olcek = MediaQuery.textScalerOf(context);
    // ⚠️⚠️⚠️ TURU 96 — SATIR SAYISI **OLCULUR**, VARSAYILMAZ.
    //
    //	Onceki hal KOSULSUZ 2 satir + 14px pay ayiriyordu. Adlarin hepsi tek
    //	satira sigdiginda (Döner/Kebap/Pide/Pizza — TIPIK durum) seridin
    //	altinda **~29dp OLU BOSLUK** kaliyordu; sliver arasindaki 16px'lik
    //	nefes ustune binince kartlar ile arama kutusu arasi ekranda **42dp**
    //	gorunuyordu. Kullanicinin *"butun satirlar ayni bosluk olsun"*
    //	demesinin sebebi buydu: kod esit veriyordu, EKRAN esit degildi.
    //
    // ⚠️ OLCUM **KALIN** (`w700`) stille yapilir: secili kart kalin cizilir
    //    ve kalin yazi DAHA GENISTIR — ince stille olculseydi bir ad
    //    secilince 2 satira sarar ve serit O ANDA tasardi.
    // ⚠️ `maxLines: 2` tavani KALIR: uc satirlik bir ad gelirse kirpilir
    //    (ellipsis), serit buyumez.
    // ⚠️⚠️ YUKSEKLIK `TextPainter.height`TEN OKUNUR, FORMULLE HESAPLANMAZ.
    //    Ilk denemede `satirSayisi * fontSize * height` ile hesaplanmisti ve
    //    emulatorde **BOTTOM OVERFLOW** seridi cikti: satir kutusunun gercek
    //    boyu yazi tipinin ascent/descent metriklerine baglidir, carpimla
    //    birebir tutmaz. `layout()` sonrasi `height` ise `Text` widget'inin
    //    uretecegi DEGERIN TA KENDISIDIR (ayni painter).
    var enYuksek = 0.0;
    for (final a in _altKategoriler) {
      final tp = TextPainter(
        text: TextSpan(
          text: a.ad,
          style: const TextStyle(
              fontSize: 13, height: 1.15, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
        textScaler: olcek,
        maxLines: 2,
      )..layout(maxWidth: kAltHucre);
      if (tp.height > enYuksek) enYuksek = tp.height;
    }
    // ⚠️ `ceilToDouble` — tam sayiya yuvarlama payi (<=1dp, gozle gorunmez);
    //    ondalik yukseklikte Flutter'in yuvarlamasi tasma uretebiliyor.
    final serit = (kAltKutu + 5 + enYuksek).ceilToDouble();
    return SizedBox(
      height: serit,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // ⚠️ TURU 93b — `12` idi; `kYanBosluk` TEK KAYNAK (dosya basindaki
        //    serhin ACIKCA yasakladigi sey elle yazilmisti: 60x60 kartlar
        //    slider ve arama kutusundan **4px solda** duruyordu).
        // ⚠️ Sag dolgu da `kYanBosluk`: yatay serit kaydirildiginda son
        //    kartin kenara YAPISMAMASI icin.
        // ⚠️ IC DIKEY DOLGU YOK (bkz. `kBosluk` serhi): bolumler arasi
        //    mesafe YALNIZCA sliver sirasinda verilir.
        // ⚠️⚠️ YATAY DOLGU `kYanBosluk` **DEGIL**: kutu hucrenin ortasinda
        //    oldugu icin 9px ice kayardi (bkz. `kAltIcBosluk` serhi).
        padding: const EdgeInsets.symmetric(
            horizontal: kYanBosluk - kAltIcBosluk),
        itemCount: _altKategoriler.length,
        itemBuilder: (_, i) {
          final a = _altKategoriler[i];
          final secili = _altSecili == a.ara;
          final renk = Theme.of(context).colorScheme.primary;
          return Padding(
            // ⚠️ Kullanici emri (DORDUNCU kez azaltildi): 10 -> 4 -> 2 -> **0**.
            //    Hucre genisligi 78 KALIR: daraltmak "Lahmacun"u tekrar
            //    kelime ortasindan bolerdi.
            // ⚠️ 0 "kutular yapisik" DEMEK DEGIL: kutu 60, hucre 78 ve kutu
            //    hucrenin ORTASINDA -> iki kutu arasinda hala **18px** var.
            //    Daha da azaltmak icin hucre genisligi dusmeli, o da yaziyi
            //    boler. Bu, mevcut yazi olcusuyle ULASILABILIR EN DAR aralik.
            padding: EdgeInsets.zero,
            child: GestureDetector(
              // ⚠️ `opaque`: kutu ile yazi ARASINDAKI bosluga dokunmak da
              //    secer; aksi halde kullanici "bastim olmadi" der.
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _altSecili = secili ? '' : a.ara);
                // ⚠️ TURU 93b — BEKLEYEN ARAMA ZAMANLAYICISI IPTAL EDILIR:
                //    kullanici yazip hemen karta basarsa 320ms'lik timer
                //    ikinci bir istek daha atardi (jeton kapisi yanlis
                //    veriyi engelliyor ama istek bosuna gidiyordu).
                _gecikme?.cancel();
                _yukle();
              },
              child: SizedBox(
                // ⚠️ 64 -> **78**: yazi 13px olunca "Lahmacun" 64dp'ye
                //    sigmayip KELIME ORTASINDAN bolunuyordu ("Lahmacu/n").
                //    Kutu 60x60 KALIR, yalnizca yazi alani genisler.
                width: kAltHucre,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: kAltKutu,
                      height: kAltKutu,
                      decoration: BoxDecoration(
                        // ⚠️ YUZEY yaricapi — kapak ve slider ile AYNI sabit
                        //    (bkz. `kYaricap` serhi).
                        borderRadius: BorderRadius.circular(kYaricap),
                        // ⚠️ KENARLIK YOK (kullanici emri: *"kucuk kartlarda
                        //    neden border var, onu da kaldir"*). Secili
                        //    kartta da kenarlik cizilmez — secim ZEMIN
                        //    RENGIYLE ve ad kalinligiyla belli olur.
                        // ⚠️ Ton `kYuzeyGri` — kapak ve slider ile AYNI.
                        // ⚠️⚠️ TURU 93b — ALFA KALDIRILDI + KENARLIK EKLENDI
                        //	(denetim: kontrast **~1.06** olculdu).
                        //
                        //	`surfaceContainerHighest` (~#E3E1E6) %50 alfa ile
                        //	acik tema zemini `#F2F2F5` uzerine binince
                        //	**~#EBEAEE** cikiyordu — zeminden 7-8 birim fark.
                        //	Kullanici kartlarin ICINDEKI HARFLERI kaldirttigi
                        //	icin (turu 93) kutunun TEK isi "burada bir kart
                        //	var" demek; gorunmez bir kart o isi YAPMAZ.
                        //	⚠️ Ustelik cevresindeki slider zemini `#E7E7EA`
                        //	   idi: "kart" kendi arka planindan DAHA ACIK
                        //	   kaliyor, gorsel hiyerarsi TERS donuyordu.
                        // ⚠️ Kenarlik filtre cipleriyle AYNI dili konusur
                        //    (`_notrKenar`) — yeni bir sabit renk eklemez.
                        color: secili
                            ? renk.withValues(alpha: 0.16)
                            : kYuzeyGri(context),
                      ),
                      // ⚠️⚠️ TURU 93 — KUTUNUN ICI **BOS** (kullanici emri:
                      //    *"kart icinde yazi olmasin, kartlarin icindeki
                      //    HARFLERI KALDIR"*). Kutu artik salt renkli bir
                      //    yuzey; ad ALTINDA yaziyor.
                      // ⚠️ YAPMA: buraya harf ya da ikon geri koyma.
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.ad,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        // ⚠️ 11 -> **13** (kullanici emri: *"alt kategoriler
                        //    doner kebap bunlari 2px daha buyuk yap yazi"*).
                        // ⚠️ Serit yuksekligi bu degerden TURETILIYOR
                        //    (`olcek.scale(13)`), yani buyutme tasma
                        //    URETMEZ — sabit 92px olsaydi ederdi.
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                        color: secili ? renk : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ⚠️⚠️ TURU 92 — FILTRE SATIRI (kullanici emri: *"altinda FILTRELEME
  ///    BUTONU, saginda da genel olarak kullanilan filtrelemeler"*).
  ///
  /// SOLDA sabit "Filtrele" dugmesi (tum secenekleri alttan sheet'te acar),
  /// SAGINDA yatay kayan SIK KULLANILANLAR.
  /// ⚠️ Solraki dugme KAYMAZ (`Row` + `Expanded`): kullanici filtreyi
  ///    ararken seridi kaydirmak zorunda kalmamali.
  Widget _filtreSatiri() {
    return Padding(
      // ⚠️ TURU 93b — `12` idi -> `kYanBosluk` (dosya basindaki "elle yatay
      //    dolgu YAZMA" serhinin ikinci ihlali; "Filtrele" dugmesi arama
      //    kutusundan 4px solda duruyordu).
      // ⚠️ Sag 0 KALIR: sagdaki serit YATAY KAYIYOR, sag dolgu son cipi
      //    kirpiyormus gibi gosterirdi.
      // ⚠️ IC DIKEY DOLGU YOK; sag 0 KALIR (serit yatay kayiyor, sag dolgu
      //    son cipi kirpiyormus gibi gosterirdi).
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, 0, 0),
      child: Row(
        children: [
          // ⚠️ TURU 94 — "Filtrele" DUGMESI **KALDIRILDI** (kullanici emri).
          //    Kategori secimi artik hamburger menusunden ve secili kategori
          //    cipinden yonetiliyor; ekranda IKI AYRI kategori kapisi vardi.
          // ⚠️ YAPMA: bu satira yeni bir "Filtrele" dugmesi geri koyma.
          Expanded(
            child: SizedBox(
              // ⚠️ TURU 93b — 36 -> 48 (denetim). `FilterChip` varsayilan
              //    `materialTapTargetSize: padded` ile **48dp**lik dokunma
              //    alani ister; ebeveyn 36'ya kesince hedef Material 48 /
              //    Apple 44 kuralinin ALTINA dusuyordu.
              // ⚠️ Eklenen 12px artik bir sorun degil: govde turu 93b'de
              //    KAYDIRILABILIR oldu, yani sabit dikey butce yok.
              // ⚠️ Cipler 32'ye indi; serit de 48 -> 40.
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // ⚠️⚠️ "YAKINIMDA" (kullanici emri: *"orada yakinimdaki vb
                  //	seyler olsun"*).
                  //
                  //	Bu cip HARITAYA GITMEZ; listeyi KONUMA GORE siralar
                  //	(`/isletmeler` yerine `/yakinimda` ucu). Ayri bir
                  //	ekran acsaydi "suzgec" degil "gezinme" olurdu ve
                  //	yanindaki ciplerle ayni dili konusmazdi.
                  // ⚠️ Konum izni YOKSA cip yine cizilir; dokununca izin
                  //    istenir ve reddedilirse durust bir mesaj gosterilir.
                  //    Cizmemek, ozelligin VARLIGINI gizlerdi.
                  // ⚠️ IKON `locateFixed` -> **`navigation`** (kullanici emri:
                  //    *"yakinimda navigator olarak ikonu degistir"*) — yon
                  //    oku, harita uygulamalarinin ortak dili.
                  _hizliCip('yakinimda', 'Yakınımda', LucideIcons.navigation),
                  if (_benimIlce.isNotEmpty)
                    _hizliCip('sehrimde', _benimIlce, LucideIcons.mapPin),
                  _hizliCip('onayli', 'Onaylı', LucideIcons.badgeCheck),
                  // ⚠️ Kategori CIPLERI buraya TASINDI: eskiden ayri bir
                  //    44px'lik serit vardi ve ekranin ustunde ARKA ARKAYA
                  //    UC yatay serit (hizli kartlar + arama + kategoriler)
                  //    olusuyordu. Tek satirda birlesince liste 80px daha
                  //    erken basliyor.
                  if (_kategori.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      // ⚠️⚠️ `InputChip` YERINE ELDE CIZILDI: Material'in
                      //	chip'i `StadiumBorder` verilse bile ic dolgusu ve
                      //	silme ikonunun kutusu yuzunden yan yandaki elde
                      //	cizilmis ciplerle AYNI yuksekligi/yaricapi
                      //	tutturmuyordu — kullanici *"tam radius olmamis"*
                      //	dedi ve HAKLIYDI.
                      // ⚠️ Ayrica dokununca DALGA oynuyordu (ayni "titreme").
                      child: Semantics(
                        button: true,
                        label: '${isletmeKategoriAdi(_kategori)} filtresini kaldır',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // ⚠️ TEK KAPI: `_altSecili` de sifirlanir.
                          onTap: () => _kategoriSec(''),
                          // ⚠️ `Center` ZORUNLU — kardes cipteki gerekcenin
                          //    aynisi (yatay ListView dikeyde TIGHT kisit
                          //    verir, kutu 40'a gerilirdi).
                          child: Center(
                            child: Container(
                            // ⚠️ Kardes ciplerle AYNI olcu.
                            height: 32,
                            padding: const EdgeInsets.fromLTRB(11, 0, 8, 0),
                            decoration: BoxDecoration(
                              // ⚠️ HAP — kardes ciplerle AYNI mantik.
                              borderRadius: BorderRadius.circular(kYaricap),
                              // ⚠️ Bu cip DAIMA "secili" bir durumu temsil
                              //    eder (aktif kategori) -> kenarlik SIYAH,
                              //    tipki secili hizli cip gibi.
                              border: Border.all(color: _notrYazi),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isletmeKategoriAdi(_kategori),
                                  style: TextStyle(
                                      fontSize: 13, color: _notrYazi),
                                ),
                                const SizedBox(width: 5),
                                Icon(LucideIcons.x, size: 13, color: _notrYazi),
                              ],
                            ),
                          ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Notr renkler — arama kutusuyla AYNI dil (kullanici emri: yesil YOK).
  ///
  /// ⚠️ TEK KAYNAK: filtre dugmesi, hizli cipler ve secili kategori cipi
  ///    ayni iki degeri kullanir. Elle yazilsaydi biri guncellenip otekiler
  ///    unutulur ve ekranda IKI FARKLI vurgu rengi olusurdu.
  /// ⚠️⚠️ KENARLIK **ARAMA KUTUSUYLA BIREBIR AYNI** (kullanici emri:
  ///	*"border input gibi olacak"*).
  ///
  ///	Onceden cipler 0.16, arama kutusu 0.14 alfa kullaniyordu. Yan yana
  ///	duran iki eleman icin bu fark GORUNUR: cipler bir tik daha koyu
  ///	cizilip "baska bir bilesen" gibi duruyordu.
  /// ⚠️ Deger **TEK YERDE**: arama kutusu da bunu kullanir. Iki ayri sayi
  ///    yazilsaydi biri guncellenip oteki geride kalirdi — bu ekranda gri
  ///    tonda ZATEN yasandi.
  Color get _notrKenar =>
      (Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: 0.14);

  Color get _notrYazi => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A1A);

  /// Hizli suzgec cipi.
  ///
  /// ⚠️⚠️ `FilterChip` YERINE ELDE CIZILDI (kullanici emri: *"alttaki
  ///	butonlar TAM RADIUS olsun, tikladiginda TITREME vs olmasin"*).
  ///
  ///	Material'in `FilterChip`i iki sorun uretiyordu:
  ///	  · `StadiumBorder` verilse bile ic dolgusu ve `labelPadding`i
  ///	    yuzunden kose yaricapi tam yuvarlak gorunmuyordu;
  ///	  · dokununca **dalga (ripple) + hafif olcek animasyonu** oynuyor,
  ///	    kullanicinin "titreme" dedigi his tam buydu.
  ///	Elde cizilen bir `Container` + `GestureDetector` ikisini de kokten
  ///	kaldirir ve yaricap ACIKCA yuksekligin yarisidir (= tam radius).
  ///
  /// ⚠️ `Semantics(button: true)` ZORUNLU: `FilterChip` bunu kendisi
  ///    veriyordu; ciplak `Container` ekran okuyucuda "dugme" olarak
  ///    duyurulmazdi.
  /// ⚠️ Dokunma alani 40dp — Material 48'in altinda ama serit yataydir ve
  ///    ciplerin arasi 8dp bosluktur; 48 yapmak serit yuksekligini
  ///    gereksiz buyutuyordu.
  Widget _hizliCip(String anahtar, String ad, IconData ikon) {
    final secili = _hizli == anahtar;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: secili,
        label: ad,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // ⚠️ TEK SECIM: ikinci cipe basmak oncekini KAPATIR. Coklu secim
            //    bos sonuclar uretip kullaniciyi "hic isletme yok" sanisina
            //    dusururdu.
            setState(() => _hizli = secili ? '' : anahtar);
            _yukle();
          },
          // ⚠️ DAHA MINIMAL (kullanici emri): 40 -> **32** yukseklik,
          //    yatay dolgu 14 -> 11, ikon 15 -> 13, yazi 14 -> 13.
          //    Yaricap yine yuksekligin yarisi (= tam radius).
          // ⚠️⚠️⚠️ TURU 96 — `Center` **ZORUNLU** (emulatorde olculdu).
          //	YATAY bir `ListView` cocuklarina DIKEYDE **TIGHT** kisit verir
          //	(= seridin yuksekligi, 40). Yani `Container(height: 32)`
          //	SESSIZCE 40'a GERILIYORDU: yaricap 16 kaliyor ama kutu 40
          //	oldugu icin kose "tam hap" DEGIL, kirpik gorunuyordu —
          //	kullanicinin *"radius mantigi ayni olmali"* dedigi sey buydu.
          //	`Center` kisiti GEVSETIR: kutu gercekten 32 olur ve dikeyde
          //	ortalanir; dokunma alani `GestureDetector` `Center`i sardigi
          //	icin 40 KALIR (erisilebilirlik kaybi YOK).
          // ⚠️ YAPMA: bu `Center`i kaldirma; serit yuksekligini cip
          //    yuksekligiyle esitleyerek "cozme" (dokunma alani duser).
          child: Center(
            child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              // ⚠️ Kart/kapak/input ile AYNI hafif yaricap (bkz. `kYaricap`).
              borderRadius: BorderRadius.circular(kYaricap),
              // ⚠️⚠️⚠️ TURU 96 — SECILI HAL **YALNIZ SIYAH KENARLIK**
              //	(kullanici emri: *"yakinimda vb. bunlara tikladiginda
              //	border SIYAH olacak, tikladiginda patlama vb. oynama
              //	olmasin"*).
              //
              //	⚠️ ONCEKI HAL GERCEKTEN "OYNUYORDU": secilince yazi
              //	   `w500 -> w700`a cikiyordu ve **kalin yazi DAHA GENIS**
              //	   oldugu icin cipin genisligi degisiyor, yanindaki tum
              //	   cipler YANA KAYIYORDU. Ustelik zemin de doluyordu.
              //	   Kullanicinin "patlama" dedigi sey bu kaymaydi.
              //	⚠️ Yazi kalinligi artik SABIT (`w600`), zemin dolgusu YOK:
              //	   degisen TEK sey kenarlik rengi -> yerlesim BIREBIR ayni
              //	   kalir.
              // ⚠️ Kenarlik KALINLIGI da sabit (1): `Border.all` kalinligi
              //    kutu genisligine eklenir; 1 -> 1.5 yapmak yine kaydirirdi.
              // ⚠️ YAPMA: buraya `color:` (zemin) ya da degisken
              //    `fontWeight`/`width` geri koyma.
              border: Border.all(color: secili ? _notrYazi : _notrKenar),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikon, size: 13, color: _notrYazi),
                const SizedBox(width: 5),
                Text(
                  ad,
                  style: TextStyle(
                    fontSize: 13,
                    color: _notrYazi,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ FILTRE EKRANI — girisi ARAMA KUTUSUNUN ICINDEKI ikon.
  ///
  /// Kullanici once alttaki "Filtrele" dugmesini kaldirtti, sonra ayni islevi
  /// **input icinde** istedi; turu 96'da da tam sayfa bir panele cevirdi
  /// (%100 genislik, %95 yukseklik). Yani ozellik degil, GIRIS NOKTASI ve
  /// BICIM degisti.
  /// ⚠️ EKRANDA TEK FILTRE KAPISI VAR: burasi (turu 90b `OlusturFab` dersi:
  ///    ayni ise iki giris koymak, birinin ULASILAMAZ kalmasiyla bitiyor).
  /// ⚠️⚠️ KATEGORI SECIMI BU PANELE **KONMADI**: kategori zaten (a) ekranin
  ///    basligi, (b) hamburger menusu ve (c) cip seridindeki "Yemek ×" ile
  ///    yonetiliyor. Panele DORDUNCU bir kapi eklemek, kategori degisiminin
  ///    tetikledigi `_kategoriSec` -> `_kesfiYukle` zincirini (alt
  ///    kategoriler + slaytlar KATEGORIYE OZEL) bir yerden atlamak demekti.
  /// ⚠️ Suzgecler ISTEMCIDE uygulaniyor (gecici) — gerekce ve durust sinir
  ///    `isletme_filtre.dart` dosyasinin basinda YAZILI.
  Future<void> _filtreSheet() async {
    await isletmeFiltreAc(context, _filtre);
    // ⚠️ Sunucuya YENI ISTEK ATILMAZ: suzgecler istemcide uygulaniyor ve ham
    //    liste degismiyor; yalnizca yeniden cizilir (nokta + liste guncel
    //    kalsin). Suzgecler sunucuya tasindiginda BURAYA `_yukle()` gelecek.
    if (mounted) setState(() {});
  }

  /// Kapak da avatar da yoksa: kategori renginde gradyan + isletme adinin
  /// bas harfi.
  ///
  /// ⚠️ Renk ADDAN turetilir (kategoriden DEGIL): ayni kategorideki tum
  ///    kartlar ayni renk olsaydi liste tekduze bir blok gibi gorunurdu.
  /// Izgara gorunumundeki kompakt kart (iki sutun).
  ///
  /// ⚠️ Liste kartinin KOPYASI DEGIL: dar sutunda "Açık · 20:00'a kadar ·
  ///    En uygun 80 ₺ · Gebze" satiri UC SATIRA sarardi. Burada yalnizca
  ///    **puan · sure · min tutar** cizilir; gerisi karta dokununca acilan
  ///    profilde zaten var.
  /// ⚠️ Kapak genisligi: (ekran - 2*yan bosluk - sutun araligi) / 2.
  ///    Verilmezse gorsel iki katindan fazla cozunurlukte decode edilir
  ///    (turu 91 performans dersi).
  Widget _izgaraKarti(IsletmeOzet o) {
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    final hucre = (MediaQuery.sizeOf(context).width - kYanBosluk * 2 - 12) / 2;
    return InkWell(
      borderRadius: BorderRadius.circular(kYaricap),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kYaricap),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: gorselID.isEmpty
                      ? _kapakYerTutucu(o)
                      : MedyaGorsel(
                          mediaId: gorselID,
                          fit: BoxFit.cover,
                          width: hucre,
                        ),
                ),
                kampanyaRozetleri(o),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Flexible(
                child: Text(
                  o.ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (o.dogrulandi)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(LucideIcons.badgeCheck,
                      size: 13, color: kOnayliRengi),
                ),
            ],
          ),
          const SizedBox(height: 2),
          vitrinSatiri(context, o, kompakt: true),
        ],
      ),
    );
  }

  /// ⚠️⚠️ TURU 94 — GORUNUM ANAHTARI (kullanici emri: *"inputun sagina
  ///    gorunum ekle, kart gorunumu"*).
  ///
  /// Iki gorunum: **liste** (tek sutun, genis kapak + tum bilgiler) ve
  /// **kart** (iki sutun, kompakt). Referans uygulamada da ayni ikili var.
  /// ⚠️ Tercih EKRAN OMURLU (diske yazilmiyor): kalici yapmak icin once
  ///    kullanicinin bunu gercekten istedigini gormek gerek — bugun tek
  ///    dokunusla geri alinabiliyor.
  /// Gri daire icinde ikon — gorunum anahtari ve harita AYNI dili konusur.
  ///
  /// ⚠️ TEK KAYNAK: iki dugme ayri ayri yazilsaydi biri guncellenip oteki
  ///    geride kalirdi (bu ekranda gri tonda ZATEN yasandi).
  /// ⚠️ **DALGA/TITREME YOK** (kullanici emri: *"tikladiginda titreme vs
  ///    olmasin"*): `InkWell` yerine `GestureDetector` — Material dalgasi
  ///    dairenin disina tasip "titreme" hissi veriyordu.
  Widget _daireDugme(IconData ikon, String ipucu, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: ipucu,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            // ⚠️ ARAMA KUTUSUYLA **AYNI SABIT** (kullanici emri: *"input ve
            //    sagdaki daireler ayni yukseklikte olacak"*). Elle 48
            //    yazilsaydi input yuksekligi degistiginde bu geride kalirdi.
            width: kInputBoy,
            height: kInputBoy,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kYuzeyGri(context),
              shape: BoxShape.circle,
            ),
            child: Icon(ikon, size: 20, color: _notrYazi),
          ),
        ),
      );

  Widget _gorunumAnahtari() => _daireDugme(
        // ⚠️ IKON **HEDEFI** gosterir, mevcut durumu DEGIL: izgaradayken
        //    "listeye gec" ikonu cizilir.
        _izgara ? LucideIcons.list : LucideIcons.layoutGrid,
        _izgara ? 'Liste görünümü' : 'Kart görünümü',
        () => setState(() => _izgara = !_izgara),
      );


  /// ⚠️⚠️ KAPAK YOKSA **HAFIF GRI** (kullanici emri: *"kapaklardaki renkli
  ///    desenleri kaldir, onun yerine hafif gri slider gibi yap"*).
  ///
  ///	Onceden ADDAN turetilen RENKLI bir gradyan ciziliyordu. Listede alt
  ///	alta duran kirmizi/mor/yesil bloklar dikkati icerikten CALIYOR ve
  ///	referans ekrandaki sakin gorunumden UZAKLASTIRIYORDU.
  /// ⚠️ Ton **slider ile AYNI** (`0xFFE7E7EA` / koyu `0xFF2A2A2E`): ekranda
  ///    iki farkli gri olmasin.
  /// ⚠️ Bas harf KALDI ama artik SOLUK: kartin bos degil "gorseli yok"
  ///    oldugunu gosterir; tamamen bos bir kutu "yukleniyor" gibi durur.
  /// Kapak yoksa: **DUZ HAFIF GRI**, icinde hicbir sey yok.
  ///
  /// ⚠️ Kullanici emri: *"kartlarin neden icine harf koyuyorsun, kaldir"*.
  ///    Onceden ortada bas harf ciziliyordu; kullanici bunu IKI KEZ
  ///    kaldirtti (once 60x60 kartlardan, sonra buradan).
  /// ⚠️ Ton `kYuzeyGri` — slider ve 60x60 kartlarla AYNI.
  Widget _kapakYerTutucu(IsletmeOzet o) => ColoredBox(color: kYuzeyGri(context));


}
