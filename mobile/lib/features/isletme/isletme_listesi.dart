import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
import 'favorilerim_ekrani.dart';
import 'isletme_filtre.dart';
import 'isletme_kart.dart';
import 'isletme_servisi.dart';
import 'konum_secici.dart';
import 'kategori_slider.dart';
import 'yakinimda_ekrani.dart';

/// ⚠️⚠️ TURU 77 — ISLETME REHBERI.
///
/// ⚠️⚠️ BU EKRAN, HAMBURGER MENUDEKI KARTLARIN GITTIGI YERDIR.
///    Turu 76b'de Yemek / Restoran / Alisveris kartlari HICBIR YERE gitmiyordu
///    ("yakında" diyordu) — bu projede tekrar eden "olu dogmus ozellik"
///    sinifiydi. Artik gercek bir listeye baglaniyor.
///
// ⚠️ `kYanBosluk` `isletme_kart.dart`a TASINDI: slider da ayni sabiti
//    kullanmak ZORUNDA (peek orani ondan turuyor) ve bu dosyayi import
//    etmesi dongu olurdu.

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
/// Kesif kartlari (4 x 2) — bkz. `_kesifIzgarasi`.
/// ⚠️ TURU 96c — 60 -> **78** (kullanici emri: *"kartin yuksekligini
///    arttir"*). Kutu ICI BOS oldugu icin (ikonlar kaldirildi) alcak bir
///    kutu "yer tutucu" gibi duruyordu.
/// ⚠️ Kutu yuksekligi SABIT, genislik EKRANDAN turer: dorduncu kart dar
///    telefonda tasmasin.
const double kKesifKutu = 78;
/// ⚠️ Kutular kac px DARALIR (kullanici emri). Yatay aralik bundan TURER.
const double kKesifDaralt = 10;
/// Iki satir arasindaki dikey bosluk.
const double kKesifSatirAralik = 12;

// ⚠️⚠️ TURU 96e — kullanici emri: kutu **+10px** (60 -> 70), kutular arasi
//    bosluk **+2px** (10 -> 12). Aralik hucre ile kutu farkindan turer:
//    hucre 82 - kutu 70 = 12.
const double kAltKutu = 70; // gorsel kutu (kare)
const double kAltHucre = 82; // kutu + altindaki yazi alani
const double kAltIcBosluk = (kAltHucre - kAltKutu) / 2; // = 6

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
/// ⚠️ TURU 96b — daire kaldirilip ikon 24'e cikinca **5 -> 10** oldu.
///    Pay, dokunma alani ile GORSEL oge arasindaki farkin yarisidir.
const double kHeaderPay = (44 - 24) / 2; // = 10
const double kCipPay = (40 - 32) / 2; // = 4

/// ⚠️ Header ikonlarinin GLIF ICI boslugu — ekrandan OLCULDU (bkz. header
///    dolgusu serhi). Ikon degisirse yeniden olc.
const double kNavOptik = 1.6; // navigation (konum dugmesi, olculdu)
const double kKalpOptik = 0.8; // heart

/// ⚠️ Bolum basliklarinin ("Mutfaklar", "İşletmeler (N)") GLIF ICI boslugu.
///    Ikisi de ekrandan 17.1 dp olculdu; kutular 16.0. Metin sabit oldugu
///    icin (bas harfleri degismez) telafi guvenli.
/// ⚠️ Baslik metni degisirse yeniden olc.
const double kBaslikOptik = 1.1;

/// ⚠️⚠️⚠️ TURU 96j — GORUNUM SECICI (liste · kart · harita).
///
///	Kullanici once *"ikonlari minimalist yapar misin, bir tik ustunde de
///	olsun"* dedi; dis kutu kaldirildi ve bu REDDEDILDI:
///	*"ikonlarin ARKASINDA BORDER YOK; hepsi BIR SEYIN ICINDE border olacak,
///	aktif ikon ARKA RENGI olacakti"*.
///	Yani **KUTU KALIR**; sadelestirme ikonun KENDISINDE yapilir.
///
/// ⚠️⚠️⚠️ **KUTU, FILTRE BUTONUYLA AYNI YUKSEKLIKTE** (kullanici emri:
///	*"filtre butonu genislik yuksekliginde olsun, gorunum alani cok
///	buyuk"*).
///
///	Onceki olcu 44x40'lik hucrelerdi ve kutu toplam **48 dp** oluyordu;
///	yanindaki `Filtre` cipi ise **40 dp**. Ayni satirda iki cerceve vardi ve
///	biri otekinden 8 dp daha yuksekti — goz bunu "gorunum alani cok buyuk"
///	diye okuyor.
///
/// ⚠️⚠️⚠️ **OLCUT: CIPIN *GORUNEN* YUKSEKLIGI (32), DOKUNMA ALANI (40)
///	DEGIL.** Bu ayrim ekrandan OLCULEREK bulundu:
///	  Filtre cipi — dugum kutusu **40** dp, GORUNEN murekkep **31.6** dp
///	  (aradaki 8 dp `kCipPay`, yani goze GORUNMEYEN dokunma payi)
///	Ilk denemede kutu 40'a esitlendi ve kullanici HAKLI olarak "hala buyuk"
///	dedi: goz murekkebi kiyasliyor, dokunma alanini DEGIL.
///
/// ⚠️ **HESAP TERSTEN KURULUR** (gorunen yukseklik SABIT hedeftir):
///	  kutu = hucre + kSegDolgu*2 + kenarlik*2
///	  32   = 26    + 2*2         + 1*2          ✔ cipin murekkebiyle BIREBIR
///	`kSegHucreBoy` degistirilirse `kSegDolgu` da yeniden hesaplanmali;
///	ikisi bagimsiz sayilar DEGILDIR (muhafiz bunu zorluyor).
/// ⚠️ HUCRE **KARE** (26x26): kullanici *"genislik yuksekliginde olsun"*
///	dedi. Kutu 140 -> **84 dp**; yanindaki cip 88.8 dp, yani satirdaki iki
///	oge artik ayni agirlikta.
/// ⚠️⚠️ DOKUNMA ALANI 26x26 = Material 48 kuralinin ALTINDA. **BILINCLI
///	TAVIZ**: kullanici alanin kucultulmesini IKI KEZ acikca istedi ve kutu
///	ancak hucre kadar kucultulebiliyor. Zararini sinirlayan sey, uc hedefin
///	YAN YANA ve hepsinin `HitTestBehavior.opaque` olmasi: iska giden dokunus
///	komsu GORUNUME duser (tek dokunusla geri alinir), oluye gitmez.
/// ⚠️ YAPMA: hucreyi daha da kucultme (ikon 16 ve 26'lik hucrede zaten 5 dp
///    pay kaliyor).
/// ⚠️ Aktif gri zemin hucrenin TAMAMINI doldurur: kutu dolgusu (`kSegDolgu`)
///    zaten bosluk veriyor, ikinci bir ic bosluk zemini "yuzen" gosterirdi.
/// ⚠️ Dis kutunun GORUNEN sag kenari `kYanBosluk`ta durur; kutu bir CIZGI
///    oldugu icin glif telafisi (turu 96b `kNavOptik` deseni) GEREKMEZ —
///    kenarlik zaten murekkebin ta kendisidir.
const double kSegHucre = 26; // dokunma alani (genislik) — KARE
const double kSegHucreBoy = 26; // dokunma alani (yukseklik)
const double kSegBoy = 26; // aktif zemin hucreyi doldurur
const double kSegIkon = 16; // GORUNEN ikon (26'lik hucrede optik denge)
const double kSegDolgu = 2; // kutu ile segmentler arasi

/// ⚠️ "Bir tik ustte" — kullanicinin istedigi kaydirma. `Transform` ile
///    uygulanir (yerlesimi DEGISTIRMEZ, bkz. `_listeBasligi`).
const double kSegYukari = 2;

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
  // ⚠️ TURU 96d — **FINAL**: ekran ici kategori degistirme kaldirildi
  //    (bkz. `_kategoriSec` serhi). Degisken kalsaydi analiz uyarisi
  //    verirdi ve "burasi degisebilir" yanilgisi surerdi.
  late final String _kategori = widget.kategori;

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

  /// ⚠️⚠️ TURU 96 — KART MESAFESI ICIN KONUM (kullanici emri).
  ///    `null` = konum bilinmiyor -> kartlarda mesafe CIZILMEZ.
  (double, double)? _konumum;

  /// Header'da yazan konum adi. Bos = kayitli konum yok ("Konum seç").
  String _konumAdi = '';

  /// ⚠️⚠️⚠️ TURU 96f — **KAYITLI KONUM, GPS'TEN ONCELIKLI.**
  ///
  ///	Kullanici bir konum sectiyse (Ev/İş) mesafe ONA gore hesaplanir;
  ///	kayitli konum yoksa cihazin GPS'ine dusulur. Tersi olsaydi kullanici
  ///	"Ev"i secer ama kartlar hala bulundugu yerden uzakligi gosterirdi —
  ///	secim GORUNURDE calisir, FIILEN hicbir sey yapmazdi.
  /// ⚠️ Sunucunun doldurdugu `km` (Yakınımda ucu) YINE de kazanir; bu
  ///    fonksiyon yalnizca `_konumum`u belirler.
  Future<void> _kayitliKonumuOku() async {
    final k = await KonumDeposu.secili(ref.read(apiProvider));
    if (!mounted || k == null) return;
    setState(() => _konumAdi = k.ad);
    _konumuUygula(k.enlem, k.boylam);
  }

  /// Konum panelini acar; secim degistiyse mesafeleri yeniden hesaplar.
  Future<void> _konumSec() async {
    await konumSeciciAc(context);
    if (!mounted) return;
    final k = await KonumDeposu.secili(ref.read(apiProvider));
    if (!mounted) return;
    setState(() => _konumAdi = k?.ad ?? '');
    if (k != null) {
      _konumuUygula(k.enlem, k.boylam);
    }
  }

  @override
  void initState() {
    super.initState();
    _ilceyiOgren();
    _kesfiYukle();
    _yukle();
    // ⚠️ ONCE kayitli konum (varsa mesafe ANINDA cizilir), SONRA GPS.
    _kayitliKonumuOku();
    _konumuAl();
  }

  /// ⚠️⚠️⚠️ TURU 96 — KART MESAFESI ICIN KONUM.
  ///
  /// ⚠️⚠️ **IZIN BURADA ISTENIR** (ilk yazimda ISTENMIYORDU ve bu bir
  ///	HATAYDI): kullanici *"isletme kartlarinda 1 km / 300 m gibi mesafeler
  ///	gorunsun"* dedi. Ilk surumde izin YALNIZ "Yakınımda" cipine
  ///	dokunulunca isteniyordu; yani TEMIZ KURULUMDA hicbir kartta mesafe
  ///	GORUNMUYORDU ve kullanici bunu ozelligin yapilmadigi sanabilirdi.
  ///	Mesafe bu ekranin ANA vaadi — Getir/Yemeksepeti de tam bu noktada
  ///	izin ister.
  /// ⚠️ **BLOKLAMAZ**: izin reddedilirse liste normal calisir, yalnizca
  ///    mesafe cizilmez. Hicbir yerde hata gosterilmez.
  /// ⚠️ `deniedForever` ise TEKRAR SORULMAZ (sistem zaten gostermez);
  ///    ayarlara yonlendiren bir diyalog da acilmaz — kullanici bir kez
  ///    "bir daha sorma" dediyse ona uyulur.
  ///
  /// ⚠️⚠️ **ONCE `getLastKnownPosition`**: cihazda genelde saniyeler oncesine
  ///	ait bir konum ZATEN vardir; onu okumak ANINDA doner ve GPS'i hic
  ///	uyandirmaz. `getCurrentPosition` kapali alanda 8 saniyeye kadar
  ///	bekleyebilir ve o sure boyunca kartlarda mesafe GORUNMEZDI.
  ///	Taze olcum yine de arkadan alinir ve degeri gunceller.
  Future<void> _konumuAl() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin != LocationPermission.always &&
          izin != LocationPermission.whileInUse) {
        return;
      }
      // ⚠️⚠️ KAYITLI KONUM VARSA GPS **EZMEZ**: kullanici "Ev"i sectiyse
      //    mesafe ona gore kalmali (bkz.  serhi).
      if (_konumAdi.isNotEmpty) return;
      // 1) Hizli yol — varsa aninda ciz.
      final son = await Geolocator.getLastKnownPosition();
      if (son != null) _konumuUygula(son.latitude, son.longitude);
      // 2) Taze olcum — gelince degeri tazeler.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _konumuUygula(p.latitude, p.longitude);
    } catch (_) {
      // ⚠️ SESSIZ: konum alinamazsa yalnizca mesafe cizilmez.
    }
  }

  /// Konumu kaydeder ve ELDEKI listeye uygular.
  ///
  /// ⚠️ Liste konumdan ONCE gelmis olabilir; bu yuzden mevcut kayitlara da
  ///    uygulanir. Yalniz `_konumum`u yazmak yetmezdi (bir sonraki `_yukle`ye
  ///    kadar mesafe gorunmezdi).
  void _konumuUygula(double enlem, double boylam) {
    if (!mounted) return;
    _konumum = (enlem, boylam);
    final l = _liste;
    if (l != null) mesafeleriDoldur(l, enlem, boylam);
    setState(() {});
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
  ///
  /// ⚠️⚠️⚠️ TURU 96d — METOT **SILINDI**, cunku EKRAN ICINDE KATEGORI
  ///	DEGISTIREN YOL KALMADI:
  ///	  · secili kategori cipi ("Yemek ✕") kullanici emriyle KALDIRILDI
  ///	    (ona basmak TUM kategorileri getiriyordu — doktor, otel...),
  ///	  · filtre paneline kategori bolumu HIC konmadi (gerekce
  ///	    `_filtreSheet` serhinde).
  ///	`_kategori` artik ekran omru boyunca SABIT: hangi kategoriyle
  ///	acildiysa o. Kategori degisimi hamburger menusunden YENI EKRAN acar.
  ///
  /// ⚠️ YAPMA: `_kategori`ye elle atama yapan bir yol ekleme. Ekran ici
  ///    kategori degistirme geri gelirse bu metodu AYNEN geri getir —
  ///    `_altSecili` sifirlamasi ve `_kesfiYukle` cagrisi ONUN icindeydi.

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
            // ⚠️⚠️ TURU 96h — SUZGECLER **SUNUCUYA** gonderilir (LIMIT 60
            //    sorunu icin; gerekce `isletme_filtre.dart` `uygula`da).
            //    "Gece Kuşu" ve "Şu an açık" ISTEMCIDE kalir (saat dilimi).
            minTutarKurus: _filtre.minTutarTavanKurus ?? 0,
            puanTaban: _filtre.puanTaban ?? 0,
            teslimatTavanDk: _filtre.teslimatTavanDk ?? 0,
            kampanyali: _filtre.kampanyali,
            puansiz: _filtre.puansiz,
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
                    // ── HEADER -> ARAMA ──
                    // ⚠️ Header'in ALTINDA kendi payi var (bkz. `kHeaderPay`):
                    //    ekranda gorunen bosluk yine 16.
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk - kHeaderPay)),

                    // ── ARAMA ──
                    // ⚠️⚠️ TURU 96f — ARAMA **HEADER ALTINA, SLIDER USTUNE**
                    //	tasindi (kullanici emri). Onceden kesif kartlarinin
                    //	ALTINDAYDI; artik ekrana girer girmez gorunuyor.
                    // ⚠️ Gorunum ve harita dugmeleri BURADA DEGIL, liste
                    //    basliginda (turu 96c) — input satirin TAMAMI.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kYanBosluk),
                        child: _aramaKutusu(),
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk)),

                    // ⚠️⚠️ SLAYT YOKSA SLIDER HIC CIZILMEZ: istek patlarsa
                    //    `_slaytlar` bos kalir ve `PageView` 0 ogeyle
                    //    cizilir -> ekranin tepesinde ICI BOS gri dikdortgen.
                    if (_slaytlar.isNotEmpty) ...[
                      // ⚠️⚠️ **DOLGU YOK — SLIDER TAM GENISLIK** (turu 96b).
                      //    Yandaki slaytlarin sarkmasi icin viewport ekranin
                      //    TAMAMI olmali; yan bosluk slider'in KENDI
                      //    `viewportFraction` hesabindan geliyor ve aktif
                      //    kartin sol kenari yine tam `kYanBosluk`ta duruyor.
                      // ⚠️ YAPMA: burayi tekrar `Padding` ile sarma — kart
                      //    16 yerine ~35 dp'ye kayar (olculdu).
                      SliverToBoxAdapter(
                        child: KategoriSlider(slaytlar: _slaytlar),
                      ),
                      // ⚠️ TURU 96 — bu bosluk artik OTEKILERLE BIREBIR AYNI
                      //    (kullanici emri); slider'a ozel genis nefes YOK.
                      const SliverToBoxAdapter(
                          child: SizedBox(height: kBosluk)),
                    ],

                    // ── KESIF KARTLARI (4 x 2) ──
                    // ⚠️ Kullanici emri: 60x60 seridinin ESKI YERINE, daha
                    //    buyuk 8 kart (bkz. `_kesifIzgarasi`).
                    SliverToBoxAdapter(child: _kesifIzgarasi()),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk)),

                    // ⚠️ Alt kategori seridi VARSA tam bosluk; YOKSA hemen
                    //    altta cip seridi geliyor demektir ve onun kendi
                    //    4px payi DUSULUR (bkz. `kCipPay`).
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: _altKategoriler.isNotEmpty
                                ? kBosluk
                                : kBosluk - kCipPay)),

                    // ── "MUTFAKLAR" + ALT KATEGORI SERIDI (60x60) ──
                    // ⚠️ Kullanici emri: *"döner kebap vs. bunlari isletme ara
                    //    ALTINA al, sol uste MUTFAKLAR yazsin"*.
                    // ⚠️ Baslik YALNIZ serit varken cizilir: bos bir "Mutfaklar"
                    //    basligi, altinda hicbir sey yokken tuhaf durur
                    //    (her kategoride alt kategori tanimli degil).
                    if (_altKategoriler.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          // ⚠️ Baslik metninin GLIF ICI boslugu telafi edilir
                          //    (bkz. `kBaslikOptik`): kutular 16'da hizaliyken
                          //    yazi 17.1'de basliyordu.
                          padding: EdgeInsets.only(
                              left: kYanBosluk - kBaslikOptik),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Mutfaklar',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(child: _altKategoriSeridi()),
                      // ⚠️ Cip seridinin USTUNDE 4px kendi payi var
                      //    (bkz. `kCipPay`): gorunen bosluk yine 16.
                      const SliverToBoxAdapter(
                          child: SizedBox(height: kBosluk - kCipPay)),
                    ],

                    // ── HIZLI SUZGECLER ──
                    SliverToBoxAdapter(child: _filtreSatiri()),
                    // ⚠️ Cip seridinin ALTINDA da 4px pay var.
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk - kCipPay)),

                    // ── "İşletmeler (N)" + GORUNUM + HARITA ──
                    if (l != null && l.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _listeBasligi(l.length)),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: kBosluk)),
                    ],

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
                                    _suzgecDegistir(_filtre.temizle),
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
                        // ⚠️ TURU 96e — yatay dolgu `kYanBosluk`a GERI
                        //    DONDU (kartlar daralmisti). Kartlar arasi dikey
                        //    bosluk kartin KENDI alt marjindan geliyor.
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
        //	FIX: dolgudan o ic pay DUSULUR. Boylece SOLDA ikonun sol kenari
        //	tam 16, SAGDA da (pay simetrik oldugu icin) sag kenari tam
        //	`genislik - 16`.
        // ⚠️⚠️ TURU 96b — DAIRE KALKTI, IKON 24 OLDU -> pay `(44-34)/2 = 5`
        //    DEGIL artik **`(44-24)/2 = 10`**. Eski 5 birakilsaydi ikonlar
        //    5px ICERIDE kalir ve hiza YENIDEN bozulurdu.
        // ⚠️ YAPMA: burayi sabit bir sayiya donme; ikon ya da dokunma olcusu
        //    degisirse `kHeaderPay` uzerinden yeniden turer.
        // ⚠️⚠️⚠️ TURU 96e — **OPTIK TELAFI** (kullanici: *"sol sag container
        //	icinde olanlar ayni hizada degil"* — HAKLIYDI, ekrandan olculdu).
        //
        //	Ikonun YERLESIM kutusu tam 16 dp'de basliyor ama CIZILEN glif
        //	kutunun icinde bosluk (side bearing) tasiyor: olcum
        //	  · arrow-left : 19.8 dp'de basliyor -> **3.8 dp** ic bosluk
        //	  · heart      : sagdan 16.8 dp -> **0.8 dp** ic bosluk
        //	Sonuc: slider, input ve kartlar 16'da hizaliyken header 4 dp
        //	SAGA kayik gorunuyordu. Daire varken sorun yoktu (dairenin
        //	KENDISI 16'da basliyordu); daireler kalkinca glif ortaya cikti.
        //
        // ⚠️ Telafi IKI YAN ICIN AYRI: bearing degerleri ikona OZEL.
        // ⚠️ Ikonlar degisirse bu iki sayi YENIDEN OLCULMELI (ekrandan;
        //    tahmin etme). Olcum araci: scratchpad/hiza.js
        padding: const EdgeInsets.only(
          // ⚠️⚠️ TURU 96f — SOL TARAF YENIDEN OLCULDU. Geri tusu (44dp kutuda
          //	ortali ikon) yerine artik konum dugmesi var ve o bir `Row`:
          //	dolgunun BASINDAN basliyor, yani `kHeaderPay` SOLDA GECERSIZ.
          //	Eski telafi birakilinca ikon **3.8 dp**ye kaydi (olculdu).
          // ⚠️ SAG hala `_headerDaire` -> orada ikisi de gecerli.
          left: kYanBosluk - kNavOptik,
          right: kYanBosluk - kHeaderPay - kKalpOptik,
        ),
        // ⚠️⚠️⚠️ TURU 96g — BASLIK **GERCEK MERKEZDE** (kullanici emri:
        //	*"Yemek yazisi ortada olacak"*).
        //
        //	ONCEKI HAL `Row` + `Expanded` idi: soldaki konum dugmesi ile
        //	sagdaki kalp ESIT GENISLIKTE OLMADIGI icin "orta" kayiyordu.
        //	`Stack` + `Center` yapisal cozum: baslik yanindakilerden
        //	BAGIMSIZ, header'in gercek ortasinda durur.
        // ⚠️ Ayni hata filtre panelinde de vardi ve kullanici orada da fark
        //    etti — cozum ayni.
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              if (widget.baslik.isNotEmpty)
                Center(
                  child: Text(
                    widget.baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // ⚠️ DIKEY DENGE: yazi tipinin ascent'i descent'ten
                    //    buyuk oldugu icin varsayilan satir kutusunda glif
                    //    YUKARI kayik oturur (kullanici: *"alt kismi kisa
                    //    kaliyor"*). `height: 1.0` + `even` esit dagitir.
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                ),
              // ⚠️⚠️ GERI TUSU YERINE **KONUM SECICI** (turu 96f).
              //	Geri dugmesi yok; Android'de donanim/jest geri, iOS'ta
              //	kenardan cekme CALISMAYA DEVAM EDER.
              // ⚠️ YAPMA: bu satiri "sadelestirme" adina kaldirma — ekranda
              //    baska cikis yolu yok.
              Align(alignment: Alignment.centerLeft, child: _konumDugmesi()),
              Align(
                alignment: Alignment.centerRight,
                child: _headerDaire(
                  LucideIcons.heart,
                  'Favorilerim',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FavorilerimEkrani()),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// ⚠️⚠️ TURU 96f — KONUM DUGMESI: navigator ikonu + secili konumun ADI.
  ///
  /// ⚠️ Kayitli konum YOKSA **"Konum seç"** yazar. "Ev" yazmak SAHTE olurdu:
  ///    kullanicinin kayitli bir evi yok ve dokununca bos liste gorurdu.
  ///    Ilk konum eklenirken ad alani ZATEN "Ev" ile dolu geliyor.
  /// ⚠️ Ad UZUNSA kirpilir (`Flexible` + ellipsis): "Babaannemin Evi" gibi
  ///    bir ad header'i tasirdi.
  /// ⚠️ Dokunma alani ikon + yazinin TAMAMI (`opaque`): yalniz ikon
  ///    dokunulabilir olsaydi kullanici yaziya basip "calismiyor" derdi.
  Widget _konumDugmesi() => Semantics(
        button: true,
        label: 'Konum: ${_konumAdi.isEmpty ? "seçilmedi" : _konumAdi}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _konumSec,
          // ⚠️⚠️ TURU 96g — **GENISLIK TAVANI** (kullanici emri: *"belirli
          //	bir yazidan sonra ... olmasi gerekiyor, ortadaki Yemek
          //	yazisina cok yaklasmasin"*).
          //
          //	Baslik artik `Stack` icinde ORTALI, yani konum dugmesi
          //	buyudukce onu ITMEZ — UZERINE BINER. Tavan olmadan "Babaannemin
          //	Evi" gibi bir ad basligin altina girerdi.
          // ⚠️ Oran ekrandan turer (%32): sabit dp dar telefonda cok yer
          //    kaplar, genis telefonda gereksiz erken kirpardi.
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.32),
            child: SizedBox(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ Ikonun sol GLIF boslugu header dolgusunda telafi ediliyor
                //    (bkz. `kNavOptik`) — deger `navigation` icin olculdu.
                Icon(LucideIcons.navigation, size: 22, color: _notrYazi),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    _konumAdi.isEmpty ? 'Konum seç' : _konumAdi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _notrYazi,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(LucideIcons.chevronDown, size: 15, color: _notrYazi),
              ],
            ),
          ),
          ),
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
            // ⚠️ Dokunma alani 44 KALIR (Material 48 / Apple 44 kurali):
            //    daire kalksa da dokunulabilir alan KUCULMEZ.
            width: 44,
            height: 44,
            child: Center(
              // ⚠️⚠️ TURU 96b — **DAIRE KALDIRILDI** (kullanici emri: *"geri
              //	ve kalp arkasindaki daireleri kaldir, o ikonlari 4px daha
              //	buyut"*). Ikon artik sayfa zemini uzerinde ciplak duruyor.
              // ⚠️ 20 -> **24**: daire kalkinca ikon kucuk kaliyordu; 4px
              //    buyume o boslugu dolduruyor.
              child: Icon(ikon, size: 24, color: _notrYazi),
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
    // ⚠️⚠️ TURU 96c — YAZI **1px KUCUK, BIR TIK KALIN** (kullanici emri:
    //	*"isletme ara yazisini 1px ufalt ve 1 tik kalinlastir"*).
    //	Varsayilan `bodyLarge` 16/w400 idi -> **15/w500**.
    // ⚠️ Ipucu ve GERCEK METIN **AYNI** stili kullanir: farkli olsalardi
    //    kullanici yazmaya basladigi an yazi boyu ZIPLARDI.
    const yaziStili = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    return TextField(
      controller: _arama,
      onChanged: _aramaDegisti,
      style: yaziStili,
      decoration: InputDecoration(
        hintText: 'Ne Aramıştın?',
        hintStyle: yaziStili.copyWith(
            color: (koyu ? Colors.white : Colors.black).withValues(alpha: 0.45)),
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
        // ⚠️⚠️⚠️ TURU 96d — YUKSEKLIGI ARTIK **BU KUTU** BELIRLIYOR.
        //	Filtre ikonu (suffix) cip seridine tasindi; o kutu inputun
        //	yuksekligini tasiyordu (bkz. ustteki serh). Bu \n        //	olmadan cerceve 48 -> **33 dp**ye duser ve input yanindaki
        //	olculerle yeniden AYRISIRDI.
        // ⚠️ YAPMA: bu i kaldirma.
        prefixIcon: SizedBox(
          height: kInputBoy,
          child: Padding(
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
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        isDense: true,
        // ⚠️ DIKEY DOLGU **0**: yukseklik suffix kutusundan geliyor (bkz.
        //    `kInputBoy`). Burada da deger yazilsaydi ikisi TOPLANIR ve
        //    input dairelerden UZUN olurdu.
        contentPadding: const EdgeInsets.only(right: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap(kInputBoy)),
          borderSide: BorderSide(color: bos),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap(kInputBoy)),
          borderSide: BorderSide(color: odak, width: 1.6),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96b — **KESIF KARTLARI: 4 x 2 = 8** (kullanici emri:
  ///	*"döner kebap kartlari yerine 4 tane soldan saga dogru, ama daha
  ///	buyuk kart seklinde 'Ne Yesem?', 'İndirimli Restoranlar' gibi; 4
  ///	altina 4, 8 tane kart olacak, isimlerini sen bul"*).
  ///
  /// ⚠️⚠️ **SEKIZININ DE ARKASINDA GERCEK BIR DAVRANIS VAR.** Bu projede
  ///	"arayuz var, veri yok" en pahali hata sinifi (filtre panelinde
  ///	"Ödeme Yöntemleri"ni tam bu yuzden cizmedik). Her kart, ZATEN
  ///	calisan bir suzgece/siralamaya/ekrana baglandi:
  ///	  Ne Yesem?     -> listeden RASTGELE bir isletme acar
  ///	  İndirimli     -> `kampanyali` suzgeci
  ///	  Yüksek Puanlı -> `puan >= 4,5`
  ///	  En Hızlı      -> teslimat suresine gore siralama
  ///	  Yakınımda     -> mesafeye gore siralama
  ///	  Şu An Açık    -> calisma saatine gore suzgec
  ///	  Uygun Fiyatlı -> `min. tutar <= 150 TL`
  ///	  Favorilerim   -> favoriler ekrani
  /// ⚠️ YAPMA: buraya davranisi olmayan "guzel duran" bir kart ekleme.
  ///
  /// ⚠️⚠️ ETIKETLER ISTEMCIDE (alt kategorilerin AKSINE) ve bu BILINCLI:
  ///	alt kategoriler VERIDIR (her kategoride baska mutfaklar var, sunucu
  ///	doldurur — turu 92 kurali). Bunlar ise DAVRANIS: her biri istemcideki
  ///	bir suzgec alanina baglaniyor, sunucudan gelen bir metin o alani
  ///	YARATAMAZ. Suzgecler sunucuya tasindiginda bu liste de oraya taşınır.
  /// ⚠️ "Ne Yesem?" YALNIZ yemek kategorisinde; digerlerinde "Sürpriz"
  ///    (kuaförde "Ne Yesem?" yazmak sacma olurdu).
  Widget _kesifIzgarasi() {
    final f = _filtre;
    final kartlar = <({String ad, bool secili, VoidCallback ac})>[
      (
        ad: _kategori == 'yemek' ? 'Ne Yesem?' : 'Sürpriz',
        secili: false,
        ac: _rastgeleAc,
      ),
      (
        ad: 'İndirimli',
        secili: f.kampanyali,
        ac: () => _suzgecDegistir(() => f.kampanyali = !f.kampanyali),
      ),
      // ⚠️ ETIKET **4+** oldugu icin esik de 4.5 -> **4.0**: kart "4+" deyip
      //    4.5 suzseydi etiket YALAN SOYLERDI.
      (
        ad: '4+',
        secili: f.puanTaban == 4.0,
        ac: () => _suzgecDegistir(() => f.puanTaban = f.puanTaban == 4.0 ? null : 4.0),
      ),
      (
        ad: 'Şimşek',
        secili: f.siralama == Siralama.teslimat,
        ac: () => _suzgecDegistir(() => f.siralama = f.siralama == Siralama.teslimat
            ? Siralama.onerilen
            : Siralama.teslimat),
      ),
      (
        ad: 'Yakınımda',
        secili: f.siralama == Siralama.mesafe,
        ac: () => _suzgecDegistir(() => f.siralama = f.siralama == Siralama.mesafe
            ? Siralama.onerilen
            : Siralama.mesafe),
      ),
      // ⚠️⚠️ "Gece Kuşu" = **GEC SAATE KADAR ACIK**, "su an acik" DEGIL.
      //	Etiket degisince YUKLEM DE degisti: bir kart "Gece Kuşu" deyip
      //	ogle vakti acik olan her yeri gostersendi ad YALAN olurdu.
      //	Olcut `calisma`dan turuyor (kapanis >= 23:00 ya da gece yarisini
      //	asan mesai) — yeni veri GEREKMEDI.
      (
        ad: 'Gece Kuşu',
        secili: f.geceAcik,
        ac: () => _suzgecDegistir(() => f.geceAcik = !f.geceAcik),
      ),
      // ⚠️⚠️⚠️ "Yeni Restourant" — **DURUST SINIR**. Sunucu liste sorgusu
      //	`ORDER BY u.onayli DESC, u.name ASC` ile siraliyor ve yanitta
      //	KAYIT TARIHI YOK; yani "en yeni" gercekten hesaplanamiyor.
      //	Elde kalan tek durust gosterge: **puani henuz olmayan** isletme
      //	(yeni acilan yerin degerlendirmesi olmaz).
      // ⚠️ Kart bos donebilir ve bu BOZUKLUK DEGIL: tohum verisindeki tum
      //    isletmelere puan yazili. Gercek yeni kayitta gorunur.
      // ⚠️ TAM COZUM: liste yanitina `created_at` eklemek (tek sutun,
      //    `enlem`/`boylam` ile ayni desen) — backend turuna birakildi.
      // ⚠️ YAPMA: bu karti "min. tutar <= 150"e baglayip "Yeni" demek —
      //    etiketle yuklem AYRISIR ve kullanici yanlis bilgi alir.
      (
        ad: 'Yeni Restourant',
        secili: f.puansiz,
        ac: () => _suzgecDegistir(() => f.puansiz = !f.puansiz),
      ),
      (
        ad: 'Favori',
        secili: false,
        ac: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FavorilerimEkrani()),
        ),
      ),
    ];
    // ⚠️ Hucre genisligi EKRANDAN turetilir: sabit yazilsaydi 360dp'lik
    //    telefonda dorduncu kart TASARDI.
    // ⚠️⚠️⚠️ TURU 96e — KUTU 10px DAR **AMA HIZA BOZULMADAN**.
    //
    //	ILK DENEME kutuya `margin: horizontal 5` vermekti ve HIZAYI BOZDU:
    //	kutunun sol kenari 16 yerine **21 dp**ye kayiyordu — kullanici
    //	fark etti (*"sol sag container icinde olanlar ayni hizada degil"*).
    //
    //	DOGRUSU: hucreyi daralt, ARTAN YERI ARALIGA VER. Boylece ilk
    //	kutunun sol kenari tam `kYanBosluk`, sonuncununki tam `W-kYanBosluk`
    //	kalir ve kutular gercekten 10px darallir.
    // ⚠️ Aralik SABIT DEGIL, TURETILIR: dar ekranda da dort kutu tam otursun.
    final alan = MediaQuery.sizeOf(context).width - kYanBosluk * 2;
    final en = alan / 4 - kKesifDaralt;
    final aralik = (alan - en * 4) / 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: Column(
        children: [
          for (var satir = 0; satir < 2; satir++) ...[
            if (satir > 0) const SizedBox(height: kKesifSatirAralik),
            Row(
              // ⚠️⚠️⚠️ TURU 96g — **`start` ZORUNLU** (kullanici: *"Yeni
              //	Restourant karti yukari kalmis, onu duzelt"*).
              //
              //	`Row`un varsayilani `center`: hucreler FARKLI YUKSEKLIKTE
              //	oldugunda (etiket bir satir mi iki satir mi) dikeyde
              //	ORTALANIR. "Yeni Restourant" iki satira sardigi icin o
              //	hucre daha uzun, ORTALANINCA da GRI KUTUSU yukari kaydi.
              //	`start` ile tum kutular AYNI ust hizada; farkli olan
              //	yalnizca etiketin alt tarafi.
              // ⚠️ YAPMA: bunu kaldirma; iki satirlik bir etiket eklendigi
              //    an ayni kayma geri gelir.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var s = 0; s < 4; s++) ...[
                  if (s > 0) SizedBox(width: aralik),
                  SizedBox(
                    width: en,
                    child: _kesifKarti(kartlar[satir * 4 + s]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Tek kesif karti — gri kutu + ikon, ALTINDA ad.
  ///
  /// ⚠️ Ad kutunun ICINE yazilmaz: "Yüksek Puanlı" ~89dp'lik bir kutuya tek
  ///    satirda SIGMAZ; disarida iki satira sarabilir (60x60 kartlarla ayni
  ///    desen).
  /// ⚠️ Secili hal **KENARLIK** (yesil dolgu DEGIL — bkz. `kVurgu`), ve
  ///    kutuyu BUYUTMEZ.
  Widget _kesifKarti(
      ({String ad, bool secili, VoidCallback ac}) k) {
    final vurgu = kVurgu(context);
    return Semantics(
      button: true,
      selected: k.secili,
      label: k.ad,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: k.ac,
        child: Column(
          children: [
            Container(
              height: kKesifKutu,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kYuzeyGri(context),
                borderRadius: BorderRadius.circular(kYaricap(kKesifKutu)),
                border:
                    k.secili ? Border.all(color: vurgu, width: 1.6) : null,
              ),
              // ⚠️⚠️ TURU 96c — **IKON KALDIRILDI** (kullanici emri: *"ne
              //	yesem vb. kartlardaki ikonlari kaldir"*). Kutu artik salt
              //	bir yuzey; ad ALTINDA yaziyor — 60x60 mutfak kartlariyla
              //	BIREBIR ayni dil.
              // ⚠️ YAPMA: buraya ikon ya da harf geri koyma (kullanici bu
              //    ekranda kutu icine kondan HER SEYI uc kez kaldirtti).
            ),
            const SizedBox(height: 5),
            Text(
              k.ad,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // ⚠️ TURU 96g — 12 -> **14** (kullanici emri: *"slider
                //    altindaki kartlardaki yazilari 2px buyut"*).
                fontSize: 14,
                height: 1.15,
                // ⚠️ KALINLIK SABIT: degisseydi metin genisleyip satiri
                //    kaydirirdi (ciplerde yasanan hata).
                fontWeight: FontWeight.w600,
                color: k.secili ? vurgu : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96h — SUZGEC DEGISTIRMENIN **TEK KAPISI**.
  ///
  ///	Suzgecler artik SUNUCUDA uygulaniyor (LIMIT 60 sorunu). Kesif
  ///	kartlari eskiden yalniz setState cagiriyordu; sunucuya tasindiktan
  ///	sonra bu, kartin GORUNURDE secilip listenin DEGISMEMESI demek
  ///	olurdu — yani "kart calismiyor".
  /// ⚠️ Istek YALNIZ sunucu imzasi degistiyse atilir: siralama ve saat
  ///    suzgecleri istemcide uygulaniyor, bosuna ag trafigi olurdu.
  /// ⚠️ YAPMA: kart/cip icinde dogrudan setState ile filtre alani yazma;
  ///    bu kapidan gec.
  void _suzgecDegistir(void Function() degistir) {
    final onceki = _filtre.sunucuImzasi;
    setState(degistir);
    if (_filtre.sunucuImzasi != onceki) _yukle();
  }

  /// "Ne Yesem?" — elindeki listeden RASTGELE bir isletme acar.
  ///
  /// ⚠️ Liste BOSSA hicbir sey yapmaz ama kullaniciya SEBEP soylenir:
  ///    sessizce hicbir sey olmamasi "dugme bozuk" hissi verirdi.
  /// ⚠️ **SUZULMUS** listeden secer (`_gosterilen`): kullanici bir filtre
  ///    acmissa "rastgele" onun disina cikmamali.
  void _rastgeleAc() {
    final l = _gosterilen ?? const <IsletmeOzet>[];
    if (l.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Önce listede işletme olmalı.'),
      ));
      return;
    }
    final o = l[DateTime.now().microsecondsSinceEpoch % l.length];
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
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
          final renk = kVurgu(context);
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
                        borderRadius: BorderRadius.circular(kYaricap(kAltKutu)),
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
                        color: kYuzeyGri(context),
                        // ⚠️⚠️ SECILI HAL **KENARLIK** (kullanici emri: *"dönere
                        //	tikladigimda yesil oluyor, SIYAH olacak ya da eskisi
                        //	gibi GRIMSI BORDER icinde"*).
                        //
                        //	Onceki hal kutuyu yesile boyuyordu. Artik zemin
                        //	DEGISMEZ, cevresine siyah bir kenarlik cizilir —
                        //	filtre cipleriyle AYNI dil.
                        // ⚠️ Kenarlik kutuyu BUYUTMEZ: `BoxDecoration.border`
                        //    ic tarafa cizilir, olculer sabit kalir.
                        border: secili
                            ? Border.all(color: renk, width: 1.6)
                            : null,
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
                        // ⚠️ KALINLIK SABIT: degisseydi metin genisler ve
                        //    serit yana KAYARDI (ciplerde yasanan hata).
                        fontWeight: FontWeight.w600,
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
                  // ⚠️⚠️⚠️ TURU 96d — FILTRE **BURAYA TASINDI** (kullanici
                  //	emri: *"inputtaki filtreyi Yakinimda vb. soluna ekle,
                  //	ikonun yanina Filtre yaz"*). Arama kutusunun icindeki
                  //	ikon KALDIRILDI.
                  // ⚠️ Kardes ciplerle AYNI bilesen (`_hizliCip` degil ama
                  //    ayni olcu/yaricap): serit tek bir dil konusmali.
                  // ⚠️ Aktif suzgec varsa **NOKTA** cizilir — kullanici
                  //    listenin neden kisaldigini gorebilmeli.
                  _filtreCipi(),
                  // ⚠️⚠️⚠️ TURU 96g — CIPLER ARTIK **FILTRE PANELININ BOLUM
                  //	BASLIKLARI** (kullanici emri: *"filtreler sagindaki
                  //	butonlara filtrelerdeki basliklar olsun, ekstra olarak
                  //	Onayli butonu olsun"*).
                  //
                  //	Her cip bir BOLUMU temsil eder; o bolumde secim varsa
                  //	**DEGERI YAZAR** ("Puan" -> "4,0+") ve kenarligi siyah
                  //	olur. Dokununca filtre panelini acar.
                  // ⚠️ Cip KENDI BASINA SUZMEZ: tek dokunusla "Puan"in hangi
                  //    esik olacagi (4+ mi 3+ mi) secilemez. Paneli acmak TEK
                  //    durust davranis; aksi halde cip bir degeri kendiliginden
                  //    secer ve kullanici sebebini bilemezdi.
                  // ⚠️ "Yakınımda" cipi KALDIRILDI: ayni is hem kesif kartinda
                  //    hem "Sıralama > Mesafe"de var; ucuncu kapi gereksizdi.
                  _bolumCipi(
                    'Sıralama',
                    LucideIcons.arrowUpDown,
                    _filtre.siralama == Siralama.onerilen
                        ? ''
                        : siralamaAdi(_filtre.siralama),
                  ),
                  _bolumCipi(
                    'Min. tutar',
                    LucideIcons.wallet,
                    _filtre.minTutarTavanKurus == null
                        ? ''
                        : '${_filtre.minTutarTavanKurus! ~/ 100} TL',
                  ),
                  _bolumCipi(
                    'Puan',
                    LucideIcons.star,
                    _filtre.puanTaban == null
                        ? ''
                        : '${_puanYaz(_filtre.puanTaban!)}+',
                  ),
                  _bolumCipi(
                    'Teslimat',
                    LucideIcons.clock,
                    _filtre.teslimatTavanDk == null
                        ? ''
                        : '${_filtre.teslimatTavanDk} dk',
                  ),
                  // ⚠️ "Onaylı" KENDI BASINA SUZER: tek degerli (acik/kapali),
                  //    panele gerek yok. Kullanici acikca istedi.
                  _hizliCip('onayli', 'Onaylı', LucideIcons.badgeCheck),
                  if (_benimIlce.isNotEmpty)
                    _hizliCip('sehrimde', _benimIlce, LucideIcons.mapPin),
                  // ⚠️ Kategori CIPLERI buraya TASINDI: eskiden ayri bir
                  //    44px'lik serit vardi ve ekranin ustunde ARKA ARKAYA
                  //    UC yatay serit (hizli kartlar + arama + kategoriler)
                  //    olusuyordu. Tek satirda birlesince liste 80px daha
                  //    erken basliyor.
                  // ⚠️⚠️ TURU 96d — SECILI KATEGORI CIPI ("Yemek x")
                  //	**KALDIRILDI** (kullanici emri: *"oradaki Yemek x
                  //	kaldir; tikladigimda doktor vb. geliyor, bunu
                  //	duzelt"*).
                  //
                  //	HAKLIYDI ve sebep yapisaldi: cipin isi kategoriyi
                  //	KALDIRMAKTI (`_kategoriSec('')`), yani "Yemek"
                  //	ekranindayken ona basmak TUM KATEGORILERI getiriyordu
                  //	— doktor, otel, kuafor hepsi. Kullanici bir SUZGEC
                  //	cipine bastigini sanip ekranin KIMLIGINI kaybediyordu.
                  // ⚠️ Kategori zaten header basliginda yazili ve hamburger
                  //    menusunden degistiriliyor; ucuncu bir kapiya gerek yok.
                  // ⚠️ YAPMA: bu cipi geri koyma.
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

  /// Filtre cipi — serit BASINDA, panel acar.
  ///
  /// ⚠️ Kardes ciplerle **AYNI OLCU** (32 boy, `kYaricap(32)`, ayni dolgu):
  ///    serit tek bir dil konusmali. `_hizliCip` KULLANILAMAZ cunku bu cip
  ///    bir SUZGEC DEGIL, bir EKRAN acar — secili durumu yoktur.
  /// ⚠️ Aktif suzgec varsa **NOKTA**: kullanici listenin neden kisaldigini
  ///    gorebilmeli (eski input-ici ikonun rozeti buraya tasindi).
  Widget _filtreCipi() {
    final aktif = _filtre.aktifSayi > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: 'Filtre',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _filtreSheet,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kYaricap(32)),
                border: Border.all(color: aktif ? _notrYazi : _notrKenar),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cipIkon(LucideIcons.slidersHorizontal),
                  const SizedBox(width: 5),
                  Text(
                    'Filtre',
                    style: TextStyle(
                      fontSize: 13,
                      color: _notrYazi,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (aktif) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: _notrYazi, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filtre panelinin bir BOLUMUNU temsil eden cip.
  ///
  /// [deger] bos ise yalniz baslik yazar (notr kenarlik); doluysa
  /// "Baslik · deger" yazar ve kenarlik SIYAH olur.
  /// ⚠️ Dokununca filtre panelini acar — cip kendi basina suzmez (gerekce
  ///    cagri yerindeki serhte).
  /// ⚠️ Kardes ciplerle AYNI olcu (32 boy, `kYaricap(32)`, ayni dolgu).
  Widget _bolumCipi(String baslik, IconData ikon, String deger) {
    final aktif = deger.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: aktif,
        label: aktif ? '$baslik: $deger' : baslik,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _filtreSheet,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kYaricap(32)),
                border: Border.all(color: aktif ? _notrYazi : _notrKenar),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cipIkon(ikon),
                  const SizedBox(width: 5),
                  Text(
                    aktif ? '$baslik · $deger' : baslik,
                    style: TextStyle(
                      fontSize: 13,
                      color: _notrYazi,
                      // ⚠️ KALINLIK SABIT: degisseydi metin genisler ve serit
                      //    yana KAYARDI (ciplerde yasanan hata).
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

  /// ⚠️⚠️ TURU 96g — CIP IKONLARI **BIR TIK KALIN** (kullanici emri:
  ///	*"ikonlar 1px kalinlastirirsin"*).
  ///
  ///	`lucide_icons_flutter` ikonlari bir **FONT** olarak sunar (glif),
  ///	SVG degil — `strokeWidth` YOKTUR ve yazilsa DERLENMEZ. Kalinlik ayni
  ///	renkte ±0.4px kaydirilmis DORT golgeyle simule edilir; glif kendi
  ///	uzerine hafifce yayilir ve cizgi kalinlasir.
  /// ⚠️ TEK KAYNAK: serit uzerindeki HER cip bunu kullanir. Ayri ayri
  ///    yazilsaydi biri guncellenip otekiler ince kalirdi.
  /// ⚠️ TURU 96j — GOVDE `isletme_kart.dart`taki **`kalinIkon`**a tasindi
  ///    (TEK KAYNAK). Kullanici kart meta ikonlarinin da "filtre gibi"
  ///    olmasini isteyince ayni teknik iki dosyada birden gerekti; kopya
  ///    birakilsaydi biri guncellenip oteki ince kalirdi.
  /// ⚠️ YAPMA: buraya golge listesini geri kopyalama.
  Widget _cipIkon(IconData ikon) =>
      kalinIkon(ikon, olcu: 13, renk: _notrYazi);

  /// "4.0" -> "4,0" (Turkce ondalik ayraci).
  String _puanYaz(double p) => p.toStringAsFixed(1).replaceAll('.', ',');

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
              borderRadius: BorderRadius.circular(kYaricap(32)),
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
                _cipIkon(ikon),
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
    final onceki = _filtre.sunucuImzasi;
    await isletmeFiltreAc(context, _filtre);
    // ⚠️ Sunucuya YENI ISTEK ATILMAZ: suzgecler istemcide uygulaniyor ve ham
    //    liste degismiyor; yalnizca yeniden cizilir (nokta + liste guncel
    //    kalsin). Suzgecler sunucuya tasindiginda BURAYA `_yukle()` gelecek.
    if (!mounted) return;
    // ⚠️⚠️ TURU 96h — SUNUCU SUZGECI DEGISTIYSE **YENIDEN SORULUR**.
    //    Suzme artik sunucuda; yalniz yeniden cizmek eski listeyi
    //    gosterirdi ve kullanici "filtre calismiyor" derdi.
    // ⚠️ Yalniz SIRALAMA/saat suzgeci degistiyse istek ATILMAZ: onlar
    //    istemcide uygulaniyor ve bosuna ag trafigi olurdu.
    if (_filtre.sunucuImzasi != onceki) {
      _yukle();
    } else {
      setState(() {});
    }
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
      borderRadius: BorderRadius.circular(kYaricapBuyuk),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kYaricapBuyuk),
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

  // ⚠️ TURU 96d — `_gorunumAnahtari` ve `_daireDugme` SILINDI: gorunum
  //    artik `_gorunumSecici` segment kutusunda, harita da onun ucuncu
  //    segmenti. Iki gri daire kalmadi.

  /// ⚠️⚠️⚠️ TURU 96c — LISTE BASLIGI (kullanici emri: *"arama inputun
  ///	sagindaki gorunumleri isletme kartinin SOL USTUNDE 'İşletmeler (2)',
  ///	EN SAGDA gorunum ikonlari olsun"*).
  ///
  /// ⚠️ SAYI **SUZULMUS** listeden gelir: kullanici bir filtre acinca kacini
  ///    gordugunu ANINDA bilmeli. Ham listeden verilseydi "İşletmeler (14)"
  ///    yazip altta 2 kart cizerdi.
  Widget _listeBasligi(int adet) => Padding(
        // ⚠️ Solda baslik metni (glif telafili), sagda segment KUTUSU.
        // ⚠️ Kutunun kenarligi murekkeptir: sag dolgu dogrudan `kYanBosluk`,
        //    boylece cerceve alttaki kartlarin kenariyla AYNI hizada durur.
        //    (Kutu kaldirilmis surumde `kSegYan + kSegOptik` telafisi
        //    gerekiyordu; kutu geri gelince o telafi GECERSIZ.)
        padding: const EdgeInsets.only(
            left: kYanBosluk - kBaslikOptik, right: kYanBosluk),
        child: Row(
          children: [
            Text(
              '${_listeAdi()} ($adet)',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            // ⚠️⚠️ TURU 96j — "BIR TIK USTTE" (kullanici emri). `Transform`
            //	KULLANILDI, dolgu DEGIL: dolgu satirin yuksekligini degistirir
            //	ve altindaki kart listesi asagi kayardi. `Transform.translate`
            //	YALNIZ cizimi tasir, yerlesim BIREBIR ayni kalir.
            // ⚠️ Dokunma alani da birlikte tasinir (`Transform` hit-test'i
            //    donusturur) — ikon nerede gorunuyorsa orada basiliyor.
            Transform.translate(
              offset: const Offset(0, -kSegYukari),
              child: _gorunumSecici(),
            ),
          ],
        ),
      );

  /// ⚠️⚠️ TURU 96g — LISTE BASLIGI **KATEGORIYE OZEL** (kullanici emri:
  ///	*"İşletmeler (2) yerine Restoranlar olarak yazabilirsin"*).
  ///
  /// ⚠️ Cogul adlar ISTEMCIDE ve bu bilincli bir GECICI: sunucudaki
  ///    `Kategoriler` haritasi TEKIL ad tutuyor ("Yemek"), cogulunu
  ///    ("Restoranlar") tutmuyor. Sunucuya eklemek bir alan + deploy
  ///    demekti; bu tur SALT ARAYUZ turu.
  /// ⚠️ **BACKEND TURUNDA** bu harita `altkategori.go`ya tasinmali —
  ///    yeni bir kategori eklendiginde istemci guncellemesi gerekmesin
  ///    (turu 77 kurali).
  /// ⚠️ Bilinmeyen kategori "İşletmeler"e duser: eksik bir anahtar yuzunden
  ///    baslik BOS kalmaz.
  String _listeAdi() {
    const adlar = {
      'yemek': 'Restoranlar',
      'kafe': 'Kafeler',
      'doktor': 'Doktorlar',
      'diyetisyen': 'Diyetisyenler',
      'kuafor': 'Kuaförler',
      'guzellik': 'Güzellik Merkezleri',
      'otel': 'Oteller',
      'eczane': 'Eczaneler',
      'emlak': 'Emlak Ofisleri',
      'giyim': 'Mağazalar',
      'teknoloji': 'Teknoloji Mağazaları',
      'eglence': 'Eğlence Mekânları',
      'hizmet': 'Hizmetler',
    };
    return adlar[_kategori] ?? 'İşletmeler';
  }

  /// ⚠️⚠️⚠️ TURU 96d — GORUNUM SECICI **TEK KUTU** (kullanici emri:
  ///	*"isletmelerin sagindaki ikonlari TEK BIR DIVIN ICINE al, tikladiginda
  ///	gecis yapsin, divin icinde AKTIF olunca arka plan hafif gri olacak"*).
  ///
  /// ⚠️ Onceki hal IKI AYRI gri daireydi ve gorunum anahtari **HEDEFI**
  ///    cizyordu (izgaradayken "liste" ikonu): kullanici hangi gorunumde
  ///    oldugunu ikondan ANLAYAMIYORDU. Segment kutusunda IKISI DE gorunur,
  ///    aktif olan gri zeminle isaretlenir — durum artik OKUNABILIR.
  ///
  /// ⚠️⚠️ HARITA SEGMENTININ **AKTIF HALI YOKTUR** ve bu bilincli: liste ile
  ///	kart bir GORUNUM DURUMU, harita ise AYRI BIR EKRAN. Ona gri zemin
  ///	verilseydi "haritadayim" der ama ekran zaten degismis olurdu.
  /// ⚠️ Kutu `kYuzeyGri`nin BIR TIK ACIGI ile cerceveleniyor; aktif segment
  ///    tam `kYuzeyGri`. Ikisi ayni ton olsaydi aktiflik GORUNMEZDI.
  /// ⚠️ **DALGA YOK**: `GestureDetector` (kullanici "titreme olmasin" dedi).
  Widget _gorunumSecici() {
    // ⚠️⚠️ TURU 96g — KUTU ZEMINI **BEYAZ + KENARLIK** (kullanici emri:
    //	*"sagdaki ikonlari arkasi beyaz, filtre butonu gibi; neye tikladiysam
    //	arkasi gri olacak"*).
    //
    //	Onceki hal kutuyu hafif GRI boyuyordu; aktif segment de gri olunca
    //	ikisi birbirine cok yakin kaliyor ve hangisinin secili oldugu zor
    //	anlasiliyordu. Artik kutu ZEMINLE AYNI (seffaf) + cip kenarligi,
    //	aktif segment ise dolu gri -> kontrast net.
    // ⚠️ Kenarlik cipler ile AYNI kaynaktan (`_notrKenar`).
    // ⚠️⚠️⚠️ TURU 96j — **KUTU GERI GELDI** (kullanici DUZELTMESI).
    //
    //	Once *"ikonlari minimalist yapar misin"* dendi ve dis kutu (kenarlik +
    //	dolgu) KALDIRILDI. Kullanici bunu REDDETTI:
    //	  *"Restoranlar sagdaki ikonlarin ARKASINDA BORDER YOK; hepsi BIR
    //	   SEYIN ICINDE border olacak, ikonlari icinde, AKTIF ikon ARKA
    //	   RENGI olacakti"*
    //	Yani "minimalist" istegi KUTUYU DEGIL, ikonlarin kendisini
    //	sadelestirmeyi kastediyordu. Segment kutusu bu ekranin TASARIM
    //	DILIDIR: uc gorunum TEK bir cerceve icinde yasar, aktif olan gri
    //	zeminle isaretlenir (turu 96d'de "hangi gorunumdeyim anlayamiyorum"
    //	sikayetinin cozumu buydu).
    // ⚠️ YAPMA: kutuyu bir daha kaldirma. Sadelestirme gerekiyorsa ikon
    //    OLCUSU/kalinligi ile oyna, CERCEVEYI silme.
    // ⚠️ Kenarlik cipler ile AYNI kaynaktan (`_notrKenar`) — satirdaki iki
    //    cerceve (Filtre cipi ve bu kutu) ayni tonda olmak ZORUNDA.
    Widget segment(IconData ikon, String ipucu, bool aktif, VoidCallback ac) =>
        Semantics(
          button: true,
          selected: aktif,
          label: ipucu,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ac,
            child: SizedBox(
              width: kSegHucre,
              height: kSegHucreBoy,
              child: Center(
                child: Container(
                  width: kSegHucre,
                  height: kSegBoy,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: aktif ? kYuzeyGri(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(kYaricap(kSegBoy)),
                  ),
                  child: Icon(ikon, size: kSegIkon, color: _notrYazi),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(kSegDolgu),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            kYaricap(kSegHucreBoy + kSegDolgu * 2)),
        border: Border.all(color: _notrKenar),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⚠️ TURU 96j — ILK IKON `list` -> **`layoutList`** (kullanici emri:
          //	*"ilk gorunum ikonunu degistir"*).
          //	`list` duz uc cizgiydi ve yanindaki `layoutGrid` ile AYNI DILI
          //	konusmuyordu (biri "madde isareti", oteki "yerlesim"). `layoutList`
          //	ile ikisi ayni ailedendir: solda gorsel bloklari, sagda satirlar —
          //	kullanici iki gorunumu YAN YANA kiyaslayabiliyor.
          segment(LucideIcons.layoutList, 'Liste görünümü', !_izgara,
              () => setState(() => _izgara = false)),
          segment(LucideIcons.layoutGrid, 'Kart görünümü', _izgara,
              () => setState(() => _izgara = true)),
          segment(
            LucideIcons.map,
            'Haritada gör',
            false,
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => YakinimdaEkrani(kategori: _kategori),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
