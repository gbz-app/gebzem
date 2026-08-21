/// ⚠️⚠️⚠️ TURU 84 — ADIMLI KAYIT EKRANI.
///
/// Kullanici emri: *"kayit sayfasi da step step: ilk telefon, sonra otp, sonra
/// kisisel bilgiler seklinde olacak"*.
///
/// ═══════════ BES ADIM (turu 120) ═══════════
///   0 · TELEFON        -> `/auth/kayit/telefon`  (hesap OLUSTURULMAZ)
///   1 · KOD            -> `/auth/kayit/dogrula`  (kayit jetonu alinir)
///   2 · KISISEL BILGI  -> yalniz DOGRULANIR
///   3 · SENI TANIYALIM -> yas · ilgi alanlari · takim   (turu 120, OPSIYONEL)
///   4 · FOTOGRAF       -> `/auth/kayit/tamamla` (hesap olusur, OTURUM ACILIR)
///
/// ⚠️⚠️ HESAP **SON ADIMDA** kurulur: yas/ilgi/takim ve fotograf tek istekte
///	gider. Adim basina kaydetseydik, akisi ortada birakan kullanici yarim
///	bir hesap birakirdi (turu 114'te isletme sihirbazinda alinan ayni karar).
///
/// ⚠️⚠️⚠️ TURU 89 — **IZIN ADIMI KALDIRILDI.** Izinler artik
///    `onboarding_ekrani.dart`ta aliniyor — her sayfa kendi iznini istiyor.
///    Kurtarma yolu: **Ayarlar > IZINLER**.
///    ⚠️ YAPMA: buraya izin ekrani geri koyma.
///
/// ═══════════ TASARIM ═══════════
/// Onboarding ile AYNI dil: **beyaz zemin · yazilar SOLDA · baslik + kisa
/// aciklama**. Renkler SABIT (temadan alinmaz) — zemin sabit beyaz oldugu icin
/// koyu temada beyaz-uzeri-beyaz yazi cikardi (turu 81b kontrast dersi).
/// ⚠️⚠️ TURU 120 — ALAN BICIMLERI **`auth_stil.dart`TAN** gelir (telefon on
///	eki, sifre daireleri, olculer, hata satiri). Bu dosyada IKINCI bir
///	`InputDecoration` govdesi YAZILMAZ.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'auth_provider.dart';
import 'auth_stil.dart';
import 'profil_secenekleri.dart';

const Color _yazi = authYazi;
const Color _altYazi = authAltYazi;
const Color _cizgi = authCizgi;

/// Kirpma dairesinin capi.
const double _kKirpCap = 250;

/// Toplam adim sayisi (ilerleme cubugu + son adim karari BURADAN turer).
///
/// ⚠️ TEK SABIT: turu 119'da `List.generate(4, ...)` ve `i == 3` ayri ayri
///    yaziliydi; adim eklerken ikisinden birini unutmak ilerleme cubugunu
///    sessizce bozardi.
const int _kAdimSayisi = 5;

class KayitAkisi extends ConsumerStatefulWidget {
  const KayitAkisi({super.key});

  @override
  ConsumerState<KayitAkisi> createState() => _KayitAkisiState();
}

class _KayitAkisiState extends ConsumerState<KayitAkisi> {
  int _adim = 0;

  /// Secilen ham fotograf (kirpilmamis).
  File? _fotoHam;

  /// ⚠️⚠️ TURU 120 — SECILEN FOTOGRAFIN EN-BOY ORANI (genislik/yukseklik).
  ///	Kirpma sinirlari BUNDAN turetilir; bilinmeden `boundaryMargin`
  ///	dogru hesaplanamaz (bkz. `_kirpAlani` serhi).
  double? _fotoOran;

  /// ⚠️ Kirpma alanini YAKALAMAK icin. `RepaintBoundary` + `toImage()`
  ///    ile daire viewport oldugu gibi goruntulenir — yani kullanicinin
  ///    EKRANDA GORDUGU kare ne ise yuklenen o olur.
  final _kirpAnahtar = GlobalKey();

  /// Surukleme/yakinlastirma durumu.
  final _kirpKontrol = TransformationController();
  bool _mesgul = false;

  /// ⚠️ TURU 120 — denetleyici YALNIZ HANELERI tutar; `+90` on eki
  ///    `AuthTelefonAlani` icinde cizilir ve SILINEMEZ.
  final _haneler = TextEditingController();
  final _kod = TextEditingController();
  final _ad = TextEditingController();
  final _kullaniciAdi = TextEditingController();
  final _sifre = TextEditingController();

  /// Numara eksik/gecersizken alanin ALTINA konan aciklama.
  String? _telefonNotu;

  // ── TURU 120: "Seni tanıyalım" adimi ──
  /// ⚠️ `null` = BELIRTMEDI. Tekerlegin ilk ogesi bilerek bos ("—"):
  ///    varsayilan bir yasla baslasaydik, tekerlege HIC dokunmayan kullanici
  ///    icin o deger sunucuya gercekmis gibi giderdi.
  int? _yas;
  final Set<String> _ilgiler = <String>{};
  String _takim = '';

  /// ⚠️ Adim 2'de alinir, adim 4'te kullanilir. 15 dk gecerli.
  String _kayitJetonu = '';

  /// Sunucuda TUKETILEN OTP. Geri donup ayni kodu tekrar gondermeyi engeller
  /// (bkz. `_koduDogrula` basindaki kapi).
  String _dogrulananKod = '';

  @override
  void dispose() {
    _kirpKontrol.dispose();
    _haneler.dispose();
    _kod.dispose();
    _ad.dispose();
    _kullaniciAdi.dispose();
    _sifre.dispose();
    super.dispose();
  }

  void _uyar(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m)));

  // ------------------------------------------------------------ ADIM 0
  Future<void> _telefonGonder() async {
    if (!authTelefonTam(_haneler.text)) {
      setState(
        () => _telefonNotu = 'Numaranı eksiksiz yaz — 5 ile başlayan 10 hane.',
      );
      return;
    }
    setState(() {
      _mesgul = true;
      _telefonNotu = null;
    });
    try {
      final devOtp = await ref
          .read(authProvider.notifier)
          .kayitTelefon(authTamNumara(_haneler.text));
      if (!mounted) return;
      // ⚠️ Test modunda kod yanitta doner ve otomatik dolar (mevcut OTP
      //    ekraniyla AYNI kolaylik). Gercek SMS'te alan BOS kalir.
      if (devOtp != null) _kod.text = devOtp;
      setState(() => _adim = 1);
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  // ------------------------------------------------------------ ADIM 1
  Future<void> _koduDogrula() async {
    final kod = _kod.text.trim();
    if (kod.length != 6) {
      _uyar('6 haneli kodu gir');
      return;
    }
    // ⚠️⚠️ TURU 85c — ELIMDE GECERLI JETON VARSA SUNUCUYA CIKMA (denetim).
    //
    //	`consumeOTP` kodu **TUKETIR** (tek kullanimlik). Kullanici ileri
    //	gidip GERI okuyla adim 1'e donerse kod kutusu HALA DOLUDUR ve
    //	"Doğrula"ya basmak DETERMINISTIK olarak 400 dondururdu; ustelik
    //	`catch` dali elindeki **GECERLI** kayit jetonunu da kullanilamaz
    //	hale getirirdi.
    // ⚠️ YAPMA: bu kisa devreyi kaldirma ya da kod karsilastirmasini atlama.
    if (_kayitJetonu.isNotEmpty && kod == _dogrulananKod) {
      setState(() => _adim = 2);
      return;
    }
    setState(() => _mesgul = true);
    try {
      final jeton = await ref
          .read(authProvider.notifier)
          .kayitDogrula(authTamNumara(_haneler.text), kod);
      if (!mounted) return;
      if (jeton.isEmpty) {
        _uyar('Doğrulama tamamlanamadı, tekrar dene');
        return;
      }
      setState(() {
        _kayitJetonu = jeton;
        _dogrulananKod = kod;
        _adim = 2;
      });
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  // ------------------------------------------------------------ ADIM 2
  /// ⚠️ Dogrulama TEK YERDE (`_bilgilerGecerli`) — `_hesabiKur` icinde TEKRAR
  ///    edilir: kullanici son adimdan geri donup alani BOSALTIP tekrar
  ///    ilerlerse sunucuya bos ad gitmesin. Iki kapi da UCUZ ve ikisi de gerekli.
  void _bilgileriDogrula() {
    if (!_bilgilerGecerli()) return;
    setState(() => _adim = 3);
  }

  bool _bilgilerGecerli() {
    final ad = _ad.text.trim();
    final kadi = _kullaniciAdi.text.trim().toLowerCase();
    if (ad.isEmpty) {
      _uyar('Adını ve soyadını yaz');
      return false;
    }
    if (kadi.length < 3) {
      _uyar('Kullanıcı adı en az 3 karakter olmalı');
      return false;
    }
    if (_sifre.text.length < 6) {
      _uyar('Şifre en az 6 karakter olmalı');
      return false;
    }
    return true;
  }

  /// ⚠️ Hesap SON adimda kurulur; yas/ilgi/takim + fotograf ayni akista gider.
  Future<void> _hesabiKur() async {
    if (!_bilgilerGecerli()) return;
    final ad = _ad.text.trim();
    final kadi = _kullaniciAdi.text.trim().toLowerCase();

    // ⚠️⚠️⚠️ TURU 120b — SERVISLER **TUM `await`LERDEN ONCE** YAKALANIR.
    //
    // ═══════════ SAHADA OLCULEN HATA ═══════════
    //	Emulatorde kayit tamamlandi, hesap acildi, profil goruldu — ama
    //	AVATAR YOKTU. Eklenen olcum sebebi TEK SATIRDA soyledi:
    //	  `KAYIT AVATAR HATASI: yukleme/baglama:
    //	   Bad state: Cannot use "ref" after the widget was disposed.`
    //
    //	`kayitTamamla` OTURUM ACAR; oturum degisince router yeniden cozer ve
    //	bu ekranin `ConsumerState`i SOKULUR. Ondan SONRA cagrilan
    //	`ref.read(...)` **StateError** firlatir, disaridaki `catch` yutar ve
    //	fotograf SESSIZCE kaybolur.
    //
    // ⚠️ Bu, projede DOKUZ kez sahaya cikan sinifin ONUNCU tekrari
    //    (turu 67 arama ekrani · turu 77b hikaye · turu 78b ilan/etkinlik).
    //    Duzeltmesi HER SEFERINDE ayni: **servisi await'ten once yakala.**
    // ⚠️ YAPMA: `ref.read`i tekrar await'lerin altina tasima.
    final medya = ref.read(medyaServisiProvider);
    final api = ref.read(apiProvider);
    final auth = ref.read(authProvider.notifier);

    setState(() => _mesgul = true);

    // ⚠️⚠️ KIRPILMIS KARE DE **HESAPTAN ONCE** yakalanir: `toImage()` CANLI
    //	bir `RenderRepaintBoundary` ister. Hesap kurulduktan sonra ekran
    //	sokulmus olabilir ve yakalama sessizce `null` donerdi.
    //	⚠️ Yukleme yine SONRA yapilir — `presign` OTURUM ister.
    final kirpik = await _kirpilaniYakala();
    if (_fotoHam != null && kirpik == null) {
      _avatarHatasi('kirpma yakalanamadi (RepaintBoundary)');
    }

    try {
      await auth
          .kayitTamamla(
            jeton: _kayitJetonu,
            name: ad,
            username: kadi,
            password: _sifre.text,
            // ⚠️⚠️ YAS DEGIL **DOGUM YILI** gonderilir: yas her yil degisir,
            //	dogum yili sabittir. Sunucu da dogum yilini saklar
            //	(`049_profil_ilgi.sql` serhi).
            // ⚠️ DURUST SINIR: gun/ay sorulmadigi icin yas ±1 yil hatalidir.
            dogumYili: _yas == null ? null : DateTime.now().year - _yas!,
            ilgiAlanlari: _ilgiler.toList(),
            // ⚠️ "Takım tutmuyorum" BOS gider — sunucuda "belirtmedi" ile ayni.
            takim: _takim == kTakimYok ? '' : _takim,
          );
      // ⚠️⚠️⚠️ TURU 119 — PROFIL FOTOGRAFI **HESAPTAN SONRA** yuklenir.
      //	SIRA ZORUNLU: yukleme `POST /media/presign` ile baslar ve o uc
      //	OTURUM ISTER. Hesap kurulmadan once denenirse 401 doner.
      // ⚠️⚠️ **FOTOGRAF HATASI KAYDI BOZMAZ**: hesap ZATEN kuruldu ve oturum
      //	acildi; burada firlatilan bir istisna disaridaki `catch`e duser ve
      //	kullaniciya "kayit basarisiz" gibi gorunurdu — oysa hesabi VAR.
      // ⚠️⚠️ BURADA `if (!mounted) return;` **YOK** (bilincli): oturum
      //	acildigi anda bu ekran sokulmus olabilir ve o kapi fotografi
      //	SESSIZCE atardi. Is artik `ref`e degil, yukarida yakalanan
      //	servislere bagli — ekran gitse bile TAMAMLANIR.
      await _avatariYukle(kirpik, medya, api);
      _bitir();
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  void _bitir() {
    // Oturum zaten acik; router ana ekrana yonlendirir.
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ `AuthSayfa` TEK KAYNAK: durum cubugu ikonlarini KOYU yapar
    //    (beyaz zeminde saat/pil gorunsun — turu 85b) ve ekrani `lightTheme`
    //    ile sarar (koyu temada beyaz zemine beyaz imlec cizilmesin).
    // ⚠️ YAPMA: bu sarmali kaldirip renkleri tek tek yazma.
    return AuthSayfa(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ustCubuk(),
            _ilerlemeCubugu(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: switch (_adim) {
                  0 => _adimTelefon(),
                  1 => _adimKod(),
                  2 => _adimBilgiler(),
                  3 => _adimHakkinda(),
                  _ => _adimFotograf(),
                },
              ),
            ),
            _altDugme(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ORTAK
  Widget _ustCubuk() => SizedBox(
    height: 48,
    child: Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: _yazi),
          onPressed: _mesgul
              ? null
              : () => _adim == 0
                    ? context.go('/login')
                    : setState(() => _adim -= 1),
        ),
      ],
    ),
  );

  /// Ince ilerleme cubugu.
  ///
  /// ⚠️ Yuzde YAZISI YOK: adimlarin kendisi zaten gorunuyor ve yuzde
  ///    kullaniciya bir sey katmiyor (gorsel gurultu).
  Widget _ilerlemeCubugu() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Row(
      children: List.generate(_kAdimSayisi, (i) {
        final dolu = i <= _adim;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            margin: EdgeInsets.only(right: i == _kAdimSayisi - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: dolu ? morLogo : _cizgi,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    ),
  );

  /// ⚠️ TURU 120 — baslik da `auth_stil.authBaslik`a DEVREDILDI. Burada ayri
  ///    bir kopya vardi ve giris ekranindaki olculer buyutulunce kayit ESKI
  ///    olculerde kaldi (`auth_stil.dart`in varlik sebebi).
  Widget _baslik(String b, String aciklama) => authBaslik(b, aciklama);

  // ------------------------------------------------------------ ADIM GOVDELERI
  Widget _adimTelefon() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Telefon numaran',
        'Numaranı doğrulayalım. Sana 6 haneli bir kod göndereceğiz.',
      ),
      AuthTelefonAlani(
        controller: _haneler,
        not: _telefonNotu,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _telefonNotu = null),
        onSubmitted: (_) => _telefonGonder(),
      ),
      const SizedBox(height: 16),
      const Text(
        'Numaran kimseyle paylaşılmaz; yalnızca hesabını doğrulamak ve '
        'seni tanıdıklarının bulabilmesi için kullanılır.',
        style: TextStyle(fontSize: 12.5, height: 1.45, color: _altYazi),
      ),
    ],
  );

  Widget _adimKod() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Kodu gir',
        // ⚠️ GORUNUM bicimi (`+90 555 999 88 77`) — sunucuya giden numara
        //    DEGIL. Sunucuya yalniz `authTamNumara` ile gidilir.
        '${authNumaraGoster(_haneler.text)} numarasına gönderdiğimiz '
            '6 haneli kodu yaz.',
      ),
      TextField(
        controller: _kod,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        // ⚠️ `letterSpacing` BURADA MESRU: CLAUDE.md yasaginin BELGELI
        //    istisnasi (OTP hane araligi). Rakamlar tek tek okunmali.
        style: const TextStyle(
          color: _yazi,
          fontSize: 26,
          letterSpacing: 9,
          fontWeight: FontWeight.w700,
        ),
        decoration: authAlan('6 haneli kod').copyWith(counterText: ''),
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: _mesgul ? null : _telefonGonder,
        style: TextButton.styleFrom(
          foregroundColor: morLogo,
          padding: EdgeInsets.zero,
        ),
        child: const Text('Kod gelmedi mi? Tekrar gönder'),
      ),
    ],
  );

  Widget _adimBilgiler() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Seni tanıyalım', 'Bu bilgiler profilinde görünecek.'),
      TextField(
        controller: _ad,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        style: authDegerStili(),
        decoration: authAlan('Adın soyadın', ipucu: 'Örn. Ahmet Yılmaz'),
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _kullaniciAdi,
        textInputAction: TextInputAction.next,
        style: authDegerStili(),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
        ],
        decoration: authAlan('Kullanıcı adı', ipucu: 'ornek_kullanici'),
      ),
      const SizedBox(height: 18),
      AuthSifreAlani(
        controller: _sifre,
        ipucu: 'En az 6 karakter',
        textInputAction: TextInputAction.done,
      ),
    ],
  );

  // ------------------------------------------------------------ ADIM 3
  /// ⚠️⚠️⚠️ TURU 120 — **YAS · ILGI ALANLARI · TAKIM** (kullanici emri:
  ///	*"kayitta stepte KAC YASINDASIN 28 27 yukari asagi secenek, ILGI
  ///	ALANLARI, TUTTUGU TAKIM vb seyleri de sor"*).
  ///
  /// ⚠️⚠️ **UCU DE OPSIYONEL.** Zorunlu yapmak kayit hunisini kirar ve bu
  ///	alanlar hicbir is kuralini beslemiyor. Kullanici hicbirine dokunmadan
  ///	"Devam" diyebilir; o durumda sunucuya HIC alan gitmez.
  /// ⚠️ Veriyi GERCEKTEN saklayan bir yer var: `users.dogum_yili`,
  ///    `users.ilgi_alanlari`, `users.takim` (migration 049) ve profil ucu
  ///    ucunu de donduruyor. Bu form OLU DEGIL.
  Widget _adimHakkinda() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Biraz da senden',
        'İstersen doldur — profilinde görünür, dilediğin zaman '
            'değiştirebilirsin.',
      ),
      _bolumBasligi('Kaç yaşındasın?'),
      // ⚠️⚠️ TURU 120 — YONERGE SATIRI (emulatorde goruldu). Tekerlek
      //	varsayilan olarak BOS ("—") acildigi icin ekran, kullaniciya
      //	kaydirilabilir bir secici oldugunu SOYLEMIYORDU; bos bir kutu
      //	gibi duruyordu ve adim atlanabilir sanilirdi.
      // ⚠️ Secim yapilinca metin ONAYA doner: "28 yaşındasın" — kullanici
      //    ne sectigini rakama bakmadan da dogrular.
      // ⚠️⚠️ TURU 126 — SATIR TEKERLEGIN **USTUNE** ALINDI (emulatorde
      //	goruldu). Altta dururken kullanici once BOS bir kutu goruyor ve
      //	ne yapacagini ancak asagi bakinca ogreniyordu; ustte, kutuya
      //	bakmadan ONCE okunur.
      // ⚠️ Ayrica **SOLA DAYALI**: kardes iki alt yazi ("En fazla 12 tane
      //    seçebilirsin.") sola dayali; ortada duran TEK satir buydu.
      const SizedBox(height: 4),
      Text(
        _yas == null
            ? 'Listeyi kaydırıp yaşını seç — istersen boş bırak.'
            : '$_yas yaşındasın',
        style: TextStyle(
          fontSize: 12.5,
          color: _yas == null ? _altYazi : morLogo,
          fontWeight: _yas == null ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      _yasSecici(),
      const SizedBox(height: 26),
      _bolumBasligi('İlgi alanların'),
      const SizedBox(height: 4),
      Text(
        _ilgiler.isEmpty
            ? 'En fazla $kEnFazlaIlgi tane seçebilirsin.'
            : '${_ilgiler.length}/$kEnFazlaIlgi seçildi',
        style: const TextStyle(fontSize: 12.5, color: _altYazi),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (ikon, ad) in kIlgiAlanlari)
            _cip(
              etiket: ad,
              ikon: ikon,
              secili: _ilgiler.contains(ad),
              basildi: () => setState(() {
                if (_ilgiler.contains(ad)) {
                  _ilgiler.remove(ad);
                } else if (_ilgiler.length < kEnFazlaIlgi) {
                  _ilgiler.add(ad);
                } else {
                  // ⚠️ SESSIZ DUSURME YOK: tavana takilan dokunusun neden
                  //    ise yaramadigini SOYLE. Sessiz kalsaydi kullanici
                  //    "dokunma calismiyor" sanardi.
                  _uyar('En fazla $kEnFazlaIlgi ilgi alanı seçebilirsin');
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 26),
      _bolumBasligi('Tuttuğun takım'),
      const SizedBox(height: 12),
      // ⚠️ TURU 126 — **TAKIM CIPLERINDE IKON YOK, BU BILINCLI.** Ilgi
      //    alanlari SOYUT kavramlardir (ikon "Yürüyüş" ile "Bisiklet"i
      //    ayirmaya yardim eder); takimlar OZEL ADDIR ve ikon hicbir sey
      //    eklemez — yedi cipe ayni kalkan ikonunu koymak gorsel gurultudur.
      // ⚠️ YAPMA: "ilgi alanlarinda var, burada yok" diye jenerik ikon ekleme.
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in kTakimlar)
            _cip(
              etiket: t,
              secili: _takim == t,
              // ⚠️ Ikinci dokunus SECIMI KALDIRIR: yanlislikla secen
              //    kullanicinin geri donus yolu olmaliydi.
              basildi: () => setState(() => _takim = _takim == t ? '' : t),
            ),
        ],
      ),
    ],
  );

  Widget _bolumBasligi(String b) => Text(
    b,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: _yazi,
    ),
  );

  /// Secim cipi (ilgi alani / takim).
  ///
  /// ⚠️ Dokunma hedefi en az 40 dp yuksekliginde: Material 48 diyor, `Wrap`
  ///    icinde 48 cok seyrek duruyordu; 40 sinirdaki uzlasma ve dikey aralik
  ///    (runSpacing 8) ile efektif hedef 48'e ulasiyor.
  Widget _cip({
    required String etiket,
    required bool secili,
    required VoidCallback basildi,
    IconData? ikon,
  }) => Material(
    color: secili ? morLogo : Colors.white,
    // ⚠️ Yaricap KUTU degil HAP: cipler, alt cizgili alanlarla ayni "duz"
    //    dile ait degil; secilebilir etiketlerin standart bicimi hap.
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: basildi,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: secili ? morLogo : _cizgi, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              Icon(ikon, size: 16, color: secili ? Colors.white : _altYazi),
              const SizedBox(width: 7),
            ],
            Text(
              etiket,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secili ? Colors.white : _yazi,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// ⚠️⚠️ YAS TEKERLEGI (kullanici emri: *"28 27 YUKARI ASAGI secenek"*).
  ///
  /// ⚠️ `ListWheelScrollView` SDK'nin kendi bileseni — yeni paket YOK.
  /// ⚠️⚠️ **ILK OGE BOS ("—") ve VARSAYILAN ODUR.** Bir yasla baslasaydik,
  ///	tekerlege HIC DOKUNMAYAN kullanici icin o deger sunucuya GERCEKMIS
  ///	gibi giderdi — projenin *"olmayan veriyi varmis gibi gosterme"*
  ///	kuralinin ihlali. Bos secenek "belirtmedim" demektir ve `_yas` null
  ///	kalir.
  /// ⚠️ `FixedExtentScrollPhysics` ZORUNLU: olmadan tekerlek ogeye
  ///    OTURMAZ ve iki yas arasinda asili kalir.
  ///
  /// ⚠️⚠️ TURU 126 — **YUKSEKLIK 150 -> 126** (emulatorde olculdu).
  ///	Tekerlek acilista ILK ogededir ("—"), yani secim bandinin USTUNDE
  ///	gosterilecek oge YOKTUR: 150 dp'de bandin ustunde **52 dp OLU ALAN**
  ///	kaliyordu ve ekran "bos bir kutu" gibi duruyordu. 126'da bosluk
  ///	40 dp'ye iner; alttaki komsu yas (46 dp) HALA TAM gorunur, yani
  ///	kaydirilabilirlik ipucu KAYBOLMAZ.
  /// ⚠️ 126'nin ALTINA INME: komsu oge kirpilir ve tekerlek tek satirlik
  ///    bir kutuya benzer — duzeltmeye calistigimiz sorunun ta kendisi.
  Widget _yasSecici() => SizedBox(
    height: 126,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Secim bandi — hangi ogenin secili oldugunu GORSEL olarak soyler.
        // ⚠️ `IgnorePointer`: bandin uzerine gelen dokunuslar tekerlege
        //    gecmeli, yoksa tam ortadan kaydirma calismaz.
        IgnorePointer(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: morLogo.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: morLogo.withValues(alpha: 0.35)),
            ),
          ),
        ),
        // ⚠️⚠️ TURU 126 — KAYDIRMA GOSTERGESI (yalniz secim yokken).
        //	Ekran acilista "—" gosterdigi icin tekerlegin KAYDIGI hicbir
        //	GORSEL isaretten anlasilmiyordu; yonerge satiri tek basina
        //	tasiyordu. Iki chevron bandin sag ucunda o isareti verir.
        // ⚠️ Secim yapilinca KAYBOLUR: isini gormustur, sonrasinda secili
        //    rakamin yanindaki susleme dikkat dagitir.
        // ⚠️ `IgnorePointer`: bandin kendisiyle ayni sebep — dokunus
        //    tekerlege gecmeli.
        if (_yas == null)
          IgnorePointer(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.chevronUp,
                      size: 15,
                      color: morLogo.withValues(alpha: 0.55),
                    ),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 15,
                      color: morLogo.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ListWheelScrollView.useDelegate(
          itemExtent: 46,
          diameterRatio: 1.7,
          perspective: 0.0025,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) =>
              setState(() => _yas = i == 0 ? null : kEnKucukYas + i - 1),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: kEnBuyukYas - kEnKucukYas + 2,
            builder: (_, i) {
              final bos = i == 0;
              final deger = kEnKucukYas + i - 1;
              final secili = bos ? _yas == null : _yas == deger;
              return Center(
                child: Text(
                  bos ? '—' : '$deger',
                  style: TextStyle(
                    fontSize: secili ? 26 : 20,
                    fontWeight: secili ? FontWeight.w800 : FontWeight.w500,
                    color: secili ? morLogo : _altYazi,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  /// Kirpilmis fotografi yukler ve profile baglar. **En iyi caba.**
  ///
  /// ⚠️ `gorseliHazirla` ZORUNLU: EXIF (KONUM) temizligi yapar; sunucu
  ///    GPS bulursa **422** doner (grup/kanal avatarlariyla ayni yol).
  /// ⚠️ Fotograf secilmediyse hicbir sey yapilmaz — adim OPSIYONEL.
  Future<void> _avatariYukle(
    File? kirpik,
    MedyaServisi medya,
    Dio api,
  ) async {
    if (_fotoHam == null || kirpik == null) return;
    // ⚠️⚠️⚠️ TURU 120b — **HATA ARTIK OLCULUYOR** (sahada yakalandi).
    //
    //	Ilk yazimda uc adim da `return`le SESSIZCE cikiyordu ve disarida tek
    //	bir `catch (_) {}` vardi. Emulatorde kayit tamamlandi, profil acildi
    //	ve **avatar YOKTU**; sunucuda `avatar_media_id` bos, `media_assets`te
    //	yeni satir yok — yani zincir daha ILK adimda kirilmis ama HANGISINDE
    //	oldugunu soyleyen HICBIR IZ yoktu.
    //
    // ⚠️ CLAUDE.md dersi (turu 50/56/60/63/64'un ortak koku): *"yeni bir hata
    //    yolu yazarken sor — bu patlarsa TELEMETRIDE gorur muyum? Cevap
    //    hayirsa ONCE olcumu koy."*
    // ⚠️ Kullaniciya HALA hicbir sey gosterilmez (adim opsiyonel, hesap
    //    kuruldu); olcum yalniz Sentry'e gider.
    try {
      // ⚠️⚠️⚠️ TURU 120b — SIKISTIRMA **EN IYI CABA**, ZORUNLU DEGIL.
      //
      //	SAHADA OLCULDU: kayit tamamlandi, hesap acildi, ama sunucuda
      //	`avatar_media_id` BOS ve `media_assets`te yeni satir YOK — yani
      //	`POST /media/presign` HIC CAGRILMAMIS. Zincir `yukle`den ONCE
      //	kirilmis; kalan iki aday `_kirpilaniYakala` ve `gorseliHazirla`.
      //
      // ⚠️ `gorseliHazirla` null donerse ESKIDEN fotograf SESSIZCE
      //    KAYBOLUYORDU. Artik PNG **oldugu gibi** yuklenir:
      //	  · yakalanan kare Flutter'in URETTIGI bir goruntudur, yani
      //	    **EXIF/GPS TASIMAZ** — `gorseliHazirla`nin varlik sebebi olan
      //	    gizlilik temizligi burada ZATEN GEREKSIZ (galeriden gelen ham
      //	    fotograf icin gerekli, bizim kirpimimiz icin degil),
      //	  · olcu ZATEN 625 px (250 dp x 2.5) — kucultmeye gerek yok,
      //	  · `image/png` sunucu beyaz listesinde VAR (`media/sniff.go`).
      // ⚠️ Sikistirma CALISIRSA yine tercih edilir: JPEG dosyasi belirgin
      //    kucuk ve avatar cok sik indiriliyor.
      final hazir = await MedyaServisi.gorseliHazirla(kirpik);
      if (hazir == null) {
        _avatarHatasi('sikistirma null dondu — PNG ham yukleniyor');
      }
      final id = await medya.yukle(
            dosya: hazir ?? kirpik,
            kind: 'avatar',
            mime: hazir == null ? 'image/png' : 'image/jpeg',
          );
      await api.patch('/users/me', data: {'avatar_media_id': id});
    } catch (e) {
      _avatarHatasi('yukleme/baglama: $e');
    }
  }

  /// ⚠️ GERCEK Sentry olayi — `debugPrint`/breadcrumb DEGIL. Breadcrumb
  ///    ancak baska bir olayla birlikte yuklenir; tek basina olan sessiz bir
  ///    hata TELEMETRIDE HIC GORUNMEZ (turu 50'de kamera hatasi tam bu yuzden
  ///    20 tur boyunca fark edilmedi).
  void _avatarHatasi(String neden) {
    debugPrint('KAYIT AVATAR HATASI: $neden');
    unawaited(Sentry.captureMessage('kayit avatari yuklenemedi: $neden'));
  }

  // ------------------------------------------------------------ ADIM 4
  Widget _adimFotograf() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Profil fotoğrafın',
        'İstersen şimdi ekle — sürükleyip yakınlaştırarak çerçeveye '
            'oturtabilirsin.',
      ),
      Center(
        child: Column(
          children: [
            _kirpAlani(),
            const SizedBox(height: 14),
            Text(
              _fotoHam == null
                  ? 'Henüz fotoğraf seçmedin. Bu adımı boş da geçebilirsin.'
                  : 'Sürükle · iki parmakla yakınlaştır',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _altYazi),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _fotoDugme(
                  ikon: LucideIcons.imageUp,
                  etiket: _fotoHam == null ? 'Fotoğraf seç' : 'Değiştir',
                  basildi: _mesgul ? null : _fotoSec,
                  vurgulu: _fotoHam == null,
                ),
                if (_fotoHam != null)
                  _fotoDugme(
                    ikon: LucideIcons.rotateCcw,
                    etiket: 'Sıfırla',
                    // ⚠️ Kirpma cercevesini basa alir; fotografi KALDIRMAZ.
                    basildi: _mesgul ? null : _kirpmayiOrtala,
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  /// ⚠️⚠️⚠️ TURU 120 — **KIRPMA ARTIK BOSLUK BIRAKMIYOR** (kullanici:
  ///	*"fotograf sectikten sonra ekranda yerlestirmede KESTI"*).
  ///
  /// ═══════════ TURU 119'DAKI HATA ═══════════
  /// Cocuk `Image.file(width: 240, height: 240, fit: cover)` idi. `cover`
  /// **LAYOUT ANINDA** kirpar: `InteractiveViewer`in cocugu ZATEN 240x240'lik
  /// KIRPILMIS bir kareydi. Suruklemek gorselin daha fazlasini GOSTERMIYOR,
  /// o kirpilmis kareyi kaydiriyordu -> daire kenarinda **BOS/BEYAZ alan**.
  /// Ustelik `boundaryMargin: EdgeInsets.all(120)` bu bosluga kadar
  /// suruklemeye ACIKCA izin veriyordu.
  ///
  /// ═══════════ DOGRUSU ═══════════
  ///   · `constrained: false` -> cocuk KENDI boyutunu alir,
  ///   · cocuk, dairenin `cover` olcusunde: dikey fotoda `250 x 250/oran`,
  ///   · `boundaryMargin: EdgeInsets.zero` -> viewport DAIMA cocugun icinde
  ///     kalir, yani **daire HER ZAMAN doludur** (yapisal garanti),
  ///   · baslangic donusumu gorseli ORTALAR (`constrained:false` cocugu sol
  ///     ust koseye koyar; ortalanmazsa fotografin kosesi gorunurdu).
  /// ⚠️ Olcek buyudukce `boundaryRect` de olceklenir, yani yakinlastirinca
  ///    surukleme alani KENDILIGINDEN genisler — ek hesap gerekmez.
  /// ⚠️ YAPMA: `constrained`i true'ya, cocugu sabit 250x250 `cover`a ya da
  ///    `boundaryMargin`i sifirdan buyuge dondurme; ucu de boslugu geri getirir.
  Widget _kirpAlani() {
    final oran = _fotoOran;
    final (cocukEn, cocukBoy) = oran == null
        ? (_kKirpCap, _kKirpCap)
        : (oran >= 1 ? _kKirpCap * oran : _kKirpCap,
           oran >= 1 ? _kKirpCap : _kKirpCap / oran);
    return SizedBox(
      width: _kKirpCap,
      height: _kKirpCap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: SizedBox(
              width: _kKirpCap,
              height: _kKirpCap,
              child: _fotoHam == null
                  ? _fotoBos()
                  // ⚠️ `RepaintBoundary` VIEWPORT'U sarar (cocugu DEGIL):
                  //    `toImage()` sinirin KENDI boyutunu (250x250) yakalar,
                  //    yani kullanicinin gordugu kare ne ise o kaydedilir.
                  : RepaintBoundary(
                      key: _kirpAnahtar,
                      child: InteractiveViewer(
                        transformationController: _kirpKontrol,
                        constrained: false,
                        clipBehavior: Clip.none,
                        minScale: 1,
                        maxScale: 4,
                        boundaryMargin: EdgeInsets.zero,
                        child: SizedBox(
                          width: cocukEn,
                          height: cocukBoy,
                          child: Image.file(_fotoHam!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
            ),
          ),
          // ⚠️⚠️ TURU 120 — **YERLESTIRME IZGARASI** (kullanici emri: *"beyaz
          //	hafif GORUNMEZ CIZGILER olsun, daire icinde oynasin"*).
          //	Ucte-bir cizgileri: yuzu ortalamak icin gozle referans verir.
          // ⚠️ `IgnorePointer`: dokunuslar ALTTAKI `InteractiveViewer`a
          //    gecmeli, yoksa surukleme HIC calismaz.
          // ⚠️ `RepaintBoundary`in **DISINDA**: icinde olsaydi izgara
          //    YUKLENEN FOTOGRAFA da cizilirdi.
          if (_fotoHam != null)
            IgnorePointer(
              child: ClipOval(
                child: CustomPaint(
                  size: const Size(_kKirpCap, _kKirpCap),
                  painter: _IzgaraCizer(),
                ),
              ),
            ),
          IgnorePointer(
            child: Container(
              width: _kKirpCap,
              height: _kKirpCap,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _fotoHam == null ? _cizgi : Colors.white,
                  width: 3,
                ),
                // ⚠️ Golge YALNIZ fotograf varken: bos dairede golge, gri
                //    yer tutucuyu "kutu" gibi gosteriyordu.
                boxShadow: _fotoHam == null
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotoBos() => ColoredBox(
    color: const Color(0xFFF2F2F5),
    child: Center(
      child: Icon(LucideIcons.userRound, size: 78, color: _altYazi),
    ),
  );

  /// ⚠️⚠️ TURU 126 — **`vurgulu` (emulatorde goruldu).** Fotograf henuz
  ///	secilmemisken "Fotoğraf seç" bu ekrandaki **TEK EYLEMDIR**, ama solgun
  ///	gri kenarlikla (`_cizgi`) cizildigi icin bos daire ile alt yazinin
  ///	arasinda kayboluyordu: adim, dokunulacak bir sey YOKMUS gibi
  ///	duruyordu ve kullanici dogrudan "Hesabı oluştur"a gidiyordu.
  /// ⚠️ Vurgu yalniz O DURUMDA: fotograf secildikten sonra "Değiştir" ve
  ///    "Sıfırla" IKINCIL eylemlerdir; ikisini birden morlamak, asil isin
  ///    (kirpmayi onaylayip devam etmek) onune gecerdi.
  /// ⚠️ Radius YINE 0 (turu 119 kullanici emri) — degisen yalniz RENK.
  Widget _fotoDugme({
    required IconData ikon,
    required String etiket,
    required VoidCallback? basildi,
    bool vurgulu = false,
  }) => OutlinedButton.icon(
    onPressed: basildi,
    icon: Icon(ikon, size: 17),
    label: Text(etiket),
    style: OutlinedButton.styleFrom(
      foregroundColor: vurgulu ? morLogo : _yazi,
      side: BorderSide(
        color: vurgulu ? morLogo : _cizgi,
        width: vurgulu ? 1.5 : 1,
      ),
      // ⚠️ TURU 119 — radius YOK (kullanici emri, ana dugmeyle ayni dil).
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );

  /// Gorseli daire icinde ORTALAR.
  ///
  /// ⚠️ `constrained: false` cocugu sol UST koseye yerlestirir; bu donusum
  ///    olmadan kullanici fotografin sol ust kosesini gorurdu.
  void _kirpmayiOrtala() {
    final oran = _fotoOran;
    if (oran == null) {
      _kirpKontrol.value = Matrix4.identity();
      return;
    }
    final en = oran >= 1 ? _kKirpCap * oran : _kKirpCap;
    final boy = oran >= 1 ? _kKirpCap : _kKirpCap / oran;
    setState(() {
      _kirpKontrol.value = Matrix4.identity()
        ..translateByDouble(-(en - _kKirpCap) / 2, -(boy - _kKirpCap) / 2, 0, 1);
    });
  }

  Future<void> _fotoSec() async {
    // ⚠️⚠️ `MedyaKapisi` KAPILARI ZORUNLU: arama/oda/yayin sirasinda galeri
    //    acmak donanimi cakistirir. `grup_olustur.dart` ile BIREBIR ayni
    //    desen — ham `ImagePicker` bu kapilarin DISINDA kalirdi (turu 77b).
    if (!MedyaKapisi.donanimSerbest(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda fotoğraf seçilemez');
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      // ⚠️ `finally` ZORUNLU: bayrak asili kalirsa uygulama bir daha
      //    galeri acamaz.
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    final dosya = File(x.path);
    // ⚠️⚠️ ORAN, kirpma sinirlarinin ON KOSULU. `ImageDescriptor.encoded`
    //	yalnizca BASLIGI okur; tam decode 4000x3000 bir fotograf icin
    //	~48 MB gecici RAM demekti (turu 81 dersi).
    final oran = await _oraniOku(dosya);
    if (!mounted) return;
    setState(() {
      _fotoHam = dosya;
      _fotoOran = oran;
    });
    // ⚠️ Yeni fotografta cerceve ORTALANIR: onceki resmin konumu yeni
    //    resimde anlamsiz bir kadraj birakirdi.
    _kirpmayiOrtala();
  }

  /// Gorselin en-boy oranini (genislik/yukseklik) BASLIKTAN okur.
  ///
  /// ⚠️ Hata halinde `null`: kirpma alani o zaman kare varsayar ve surukleme
  ///    kapali kalir — fotograf yine YUKLENIR, ozellik olmez.
  Future<double?> _oraniOku(File f) async {
    try {
      final tampon = await ui.ImmutableBuffer.fromUint8List(
        await f.readAsBytes(),
      );
      final tanim = await ui.ImageDescriptor.encoded(tampon);
      final en = tanim.width, boy = tanim.height;
      tanim.dispose();
      tampon.dispose();
      if (en <= 0 || boy <= 0) return null;
      return en / boy;
    } catch (_) {
      return null;
    }
  }

  /// Daire viewport'u PNG olarak yakalar.
  ///
  /// ⚠️ `pixelRatio: 2.5` -> 250 dp * 2.5 = **625 px**. Avatar icin fazlasiyla
  ///    yeterli; daha yuksegi dosyayi buyutur, dusugu profil ekraninda
  ///    bulaniklastirir.
  /// ⚠️ Hata halinde `null` doner ve KAYIT YINE TAMAMLANIR — fotograf
  ///    OPSIYONEL bir adim; yakalama hatasi hesabi engellememeli.
  Future<File?> _kirpilaniYakala() async {
    try {
      final sinir =
          _kirpAnahtar.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (sinir == null) return null;
      final resim = await sinir.toImage(pixelRatio: 2.5);
      final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
      resim.dispose();
      if (bayt == null) return null;
      final dizin = await getTemporaryDirectory();
      final dosya = File(
        '${dizin.path}/kayit_avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await dosya.writeAsBytes(bayt.buffer.asUint8List(), flush: true);
      return dosya;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ ALT DUGME
  Widget _altDugme() {
    final (etiket, is_) = switch (_adim) {
      0 => ('Kodu gönder', _telefonGonder),
      1 => ('Doğrula', _koduDogrula),
      2 => ('Devam', _bilgileriDogrula),
      3 => ('Devam', () => setState(() => _adim = 4)),
      _ => ('Hesabı oluştur', _hesabiKur),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
      child: authAnaDugme(etiket: etiket, basildi: is_, mesgul: _mesgul),
    );
  }
}

/// ⚠️ TURU 120 — KIRPMA IZGARASI: ucte-bir cizgileri, cok soluk beyaz
///    (kullanici: *"beyaz hafif GORUNMEZ cizgiler"*).
///
/// ⚠️ Renk beyaz + %22 alfa: koyu bir fotografta gorunur, acik bir fotografta
///    zar zor secilir — amac ZATEN referans vermek, dikkat cekmek degil.
/// ⚠️ `shouldRepaint` **false**: cizer durumsuzdur, her karede yeniden
///    boyanmasi gereksiz is olurdu.
class _IzgaraCizer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final firca = Paint()
      ..color = const Color(0x38FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), firca);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), firca);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
