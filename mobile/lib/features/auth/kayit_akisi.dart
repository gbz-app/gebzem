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

class KayitAkisi extends ConsumerStatefulWidget {
  const KayitAkisi({super.key, this.telefon, this.devOtp});

  final String? telefon;
  final String? devOtp;

  @override
  ConsumerState<KayitAkisi> createState() => _KayitAkisiState();
}

class _KayitAkisiState extends ConsumerState<KayitAkisi> {
  int _adim = 0;

  /// ⚠️ Giris ekranindan gelindi mi? Oyleyse TELEFON adimi (0) atlanir ve
  ///    geri oku o adima DEGIL, giris ekranina doner (kullanici: *"geride
  ///    numaran ne ve sifre belirleme alani var, kaldir"*).
  bool _giristenGeldi = false;

  /// "Devam"a basildi ve sifre kurallara uymuyor — kurallar KIRMIZI yanar.
  bool _sifreHatali = false;

  /// Ad/soyad alaninin ALTINA konan hata (SnackBar DEGIL — kullanici emri).
  String? _adHatasi;

  /// Kullanici adi alaninin ALTINA konan hata.
  String? _kullaniciAdiHatasi;

  @override
  void initState() {
    super.initState();
    // ⚠️⚠️⚠️ TURU 126 — **SIFRE ADIMINDAN BASLAR, KODDAN DEGIL (SEVK ENGELI).**
    //	Ilk yazimda `_adim = 2` (KOD) yaziliyordu ve **SIFRE ADIMI TAMAMEN
    //	ATLANIYORDU**: `_sifre` bos kaliyor, son adimda
    //	`/auth/kayit/tamamla` sifresiz gidiyor ve sunucu **400** donuyordu.
    //	Yani giris ekranindan gelen HER kayit basarisiz olurdu.
    // ⚠️ Numara giriste ZATEN alindi ve OTP ZATEN gonderildi; atlanan adim
    //    yalnizca TELEFON (0) olmali.
    final t = widget.telefon;
    if (t != null && t.isNotEmpty) {
      _haneler.text = t;
      if (widget.devOtp != null) _kod.text = widget.devOtp!;
      _adim = 1; // -> SIFRE (telefon atlandi, kod bir sonraki adim)
      _giristenGeldi = true;
    }
  }

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
  /// ⚠️⚠️ TURU 126 — VARSAYILAN **20** (kullanici emri: *"yasta direk 20de
  ///	baslasin"*). Artik `null` OLMAZ: tekerlek 20'de acilir ve kullanici
  ///	degistirmeden gecerse 20 sunucuya gider.
  /// ⚠️ Turu 120'nin "ilk oge BOS olsun" karari BILEREK geri alindi —
  ///    gerekcesi `_yasSecici` icinde yazili.
  int? _yas = kVarsayilanYas;

  /// Tekerlegi 20'ye konumlandirir. `initialItem` olmadan liste BASINDA
  /// (13) acilirdi.
  final _yasKontrol = FixedExtentScrollController(
    initialItem: kVarsayilanYas - kEnKucukYas,
  );
  final Set<String> _ilgiler = <String>{};
  String _takim = '';

  /// ⚠️⚠️⚠️ TURU 126 — **CINSIYET SUNUCUDA YOK** (kullanici emri:
  ///	*"sonra cinsiyet"*). `users` tablosunda cinsiyet sutunu YOKTUR
  ///	(migration 049 yalniz `dogum_yili` · `ilgi_alanlari` · `takim`
  ///	ekledi) ve `/auth/kayit/tamamla` boyle bir alan KABUL ETMEZ.
  /// ⚠️⚠️ CLAUDE.md kural 9: *"sunucuda karsiligi olmayan bir form
  ///	istenirse arayuzu YAP, degeri EKRANDA TUT, sunucuya GONDERME ve
  ///	bekleyen isi LISTEYE YAZ"*. Deger burada tutulur, **HICBIR yere
  ///	gonderilmez**; migration arayuz bitince acilir.
  /// ⚠️ YAPMA: bunun icin arayuz turunda migration acma.
  String _cinsiyet = '';

  /// OTP kutusunun odagi — 6 hane GORSEL olarak cizilir, gercek giris
  /// gorunmez bir `TextField`tir (bkz. `_otpAlani`).
  final _kodOdak = FocusNode();

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
    _kodOdak.dispose();
    _yasKontrol.dispose();
    super.dispose();
  }

  void _uyar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
      setState(() => _adim = 1); // -> SIFRE
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
      setState(() => _adim = 3); // -> ISIM
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
        _adim = 3; // -> ISIM
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
  /// ⚠️⚠️⚠️ TURU 126 — **HEDEF 3 -> 4.** Akis 8 adima cikinca ISIM adimi
  ///	3 oldu; bu metot hala `_adim = 3` yaziyordu, yani KENDI ADIMINA
  ///	gidiyordu ve "Devam"a basmak EKRANI HIC DEGISTIRMIYORDU.
  ///	Emulatorde goruldu: kullanici icin dugme SESSIZCE calismiyordu.
  /// ⚠️ Adim ekleyip cikarirken bu SABIT SAYILARI tek tek gozden gecir —
  ///    derleyici bunlari YAKALAMAZ.
  /// ⚠️⚠️ TURU 126 — **SOYAD DA ZORUNLU** (kullanici emri: *"soyad yazmazsa
  ///	altta alert ciksin"*). Olcut: bosluktan sonra en az 2 harf.
  /// ⚠️ Sunucu YALNIZ "bos olmasin" diyor; bu kural ISTEMCIDE DAHA KATI.
  ///    Katilik bilincli: profilde tek isim goruntuyu bozuyor ve kullanici
  ///    sonradan duzeltmiyor.
  /// ⚠️ Mesaj SnackBar DEGIL alanin ALTINDA (kullanici emri) — SnackBar
  ///    4 saniyede kayboluyor ve hangi alani isaret ettigi belirsiz kaliyor.
  void _adiDogrula() {
    final ad = _ad.text.trim();
    if (ad.isEmpty) {
      setState(() => _adHatasi = 'Adını ve soyadını yaz.');
      return;
    }
    final parcalar = ad.split(RegExp(r'\s+')).where((p) => p.length >= 2);
    if (parcalar.length < 2) {
      setState(() => _adHatasi = 'Soyadını da yaz — örneğin "Ahmet Yılmaz".');
      return;
    }
    setState(() {
      _adHatasi = null;
      _adim = 4; // -> KULLANICI ADI
    });
  }

  /// ⚠️ Mesaj SnackBar DEGIL alanin ALTINDA (kullanici emri: *"az karakter
  ///    yazinca bunda da alert versin"*).
  void _kullaniciAdiniDogrula() {
    final k = _kullaniciAdi.text;
    if (k.length < 3) {
      setState(() => _kullaniciAdiHatasi = 'En az 3 karakter yaz.');
      return;
    }
    if (!_kullaniciAdiBicimi(k)) {
      setState(
        () => _kullaniciAdiHatasi =
            'En fazla 20 karakter · yalnızca küçük harf, rakam ve alt çizgi.',
      );
      return;
    }
    setState(() {
      _kullaniciAdiHatasi = null;
      _adim = 5; // -> YAS
    });
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
      await auth.kayitTamamla(
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
    // ⚠️ TURU 126 — klavye acilinca UST ICERIK OYNAMAZ (bkz. `AuthSayfa`
    //    serhi); yalniz alt dugme `viewInsets` kadar yukari cikar.
    return AuthSayfa(
      klavyeyeGoreKuculme: false,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ustCubuk(),
            // ⚠️ TURU 126 — **STEP CIZGILERI KALDIRILDI** (kullanici emri).
            //    `_ilerlemeCubugu` ve `_kAdimSayisi` DURUYOR: adim sayisi
            //    hala son-adim kararini besliyor.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: switch (_adim) {
                  0 => _adimTelefon(),
                  1 => _adimSifre(),
                  2 => _adimKod(),
                  3 => _adimIsim(),
                  4 => _adimKullaniciAdi(),
                  5 => _adimYas(),
                  6 => _adimCinsiyet(),
                  7 => _adimIlgi(),
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
        // ⚠️⚠️ TURU 126 — OK **BASLIKLA AYNI HIZADA** (kullanici emri).
        //	`IconButton` varsayilan 48 dp kutuda ikonu ORTALAR: 24 dp ikon
        //	sola 12 dp uzakta cizilir ve govde dolgusundan (28) 16 dp DAHA
        //	SOLDA kalir. Dolgu sifirlanip disaridan 16 verildi.
        // ⚠️ Kalinlik: `strokeWidth` YOKTUR (lucide FONT) — dort golge.
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(
              LucideIcons.arrowLeft,
              color: _yazi,
              shadows: [
                Shadow(color: _yazi, offset: Offset(0.4, 0)),
                Shadow(color: _yazi, offset: Offset(-0.4, 0)),
                Shadow(color: _yazi, offset: Offset(0, 0.4)),
                Shadow(color: _yazi, offset: Offset(0, -0.4)),
              ],
            ),
            onPressed: _mesgul
                ? null
                : () => _adim == 0 || (_giristenGeldi && _adim == 1)
                      ? context.go('/login')
                      : setState(() => _adim -= 1),
          ),
        ),
      ],
    ),
  );

  // ⚠️⚠️ TURU 126 — **ILERLEME CUBUGU SILINDI** (kullanici emri:
  //	*"step cizgilerini de kaldir"*). Onunla birlikte `_kAdimSayisi` de
  //	kaldirildi: cubuk gidince o sabiti okuyan HICBIR YER kalmadi.
  // ⚠️ Adim govdeleri ve alt dugme `switch (_adim)` ile eslesiyor; SON adim
  //    ikisinde de VARSAYILAN dal (`_ =>`). Yani yeni adim eklerken
  //    guncellenecek yer IKI switch'tir, bir sayac degil.

  Widget _baslik(String ust, String baslik) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        ust,
        style: TextStyle(
          fontSize: 20,
          height: 1.35,
          color: _altYazi.withValues(alpha: 0.85),
        ),
      ),
      const SizedBox(height: 8),
      authBaslik(baslik, null, 23),
    ],
  );

  // ------------------------------------------------------------ ADIM GOVDELERI
  Widget _adimTelefon() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Başlayalım', 'Numaran ne?'),
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

  /// ⚠️⚠️⚠️ TURU 126 — **OTP: 3 ALT CIZGI · TIRE · 3 ALT CIZGI**
  ///	(kullanici emri). Haneler GORSEL olarak cizilir; gercek giris
  ///	ALTTA duran, metni SAYDAM bir `TextField`tir.
  ///
  /// ⚠️⚠️ **GORUNMEZ ALAN `Opacity(0)` DEGIL**: `Opacity` widget'i
  ///	yine de YER KAPLAR ve dokunuslari yutardi. Bunun yerine metin
  ///	ve imlec SAYDAM, dekorasyon YOK — alan tam olarak hanelerin
  ///	uzerinde durur, klavye normal acilir, secim/yapistirma calisir.
  /// ⚠️ Cizim `_kod` denetleyicisini DINLER (`ValueListenableBuilder`);
  ///    ebeveynin `setState` cagirmasina bagli olsaydi haneler yazarken
  ///    guncellenmezdi (turu 120'de `AuthTelefonAlani`da yasanan sinif).
  Widget _otpAlani() {
    const hane = 44.0;
    const yukseklik = 58.0;
    return GestureDetector(
      // ⚠️ Hanelerin herhangi bir yerine dokunmak alani odaklar.
      behavior: HitTestBehavior.opaque,
      onTap: _kodOdak.requestFocus,
      child: SizedBox(
        height: yukseklik,
        child: Stack(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _kod,
              builder: (_, deger, _) {
                final kod = deger.text;
                Widget kutu(int i) {
                  final dolu = i < kod.length;
                  return SizedBox(
                    width: hane,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dolu ? kod[i] : '',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _yazi,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(height: 2, color: dolu ? _yazi : _cizgi),
                      ],
                    ),
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    kutu(0),
                    kutu(1),
                    kutu(2),
                    // ⚠️ TURU 126 — TIRE YERINE **BOSLUK** (kullanici emri:
                    //    *"arada - olmasin, normal telefon inputu gibi sadece
                    //    arada bosluk olsun"*).
                    const SizedBox(width: 22),
                    kutu(3),
                    kutu(4),
                    kutu(5),
                  ],
                );
              },
            ),
            // ⚠️ Gercek giris: metin ve imlec SAYDAM (bkz. serh).
            Positioned.fill(
              child: TextField(
                controller: _kod,
                focusNode: _kodOdak,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                cursorColor: Colors.transparent,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _koduDogrula(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adimKod() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ⚠️ GORUNUM bicimi — sunucuya giden numara DEGIL.
      // ⚠️ TURU 126 — ust satir numarayi TEK BASINA degil, NE OLDUGUYLA
      //    birlikte soyler (kullanici: *"daha profesyonel, bir tik daha
      //    fazlasi bir yazi olsun"*).
      _baslik(
        '${authNumaraGoster(_haneler.text)} numarasına gönderdik',
        'Doğrulama kodun',
      ),
      _otpAlani(),
      // ⚠️⚠️ TURU 126 — **"Kod gelmedi mi? Tekrar gönder" KALDIRILDI**
      //	(kullanici emri).
      // ⚠️⚠️ **BEKLEYEN IS:** bu, kodu YENIDEN ISTEMENIN TEK yoluydu. SMS
      //	ulasmayan kullanici artik geri okuyla telefon adimina donup
      //	"Devam"a basmak ZORUNDA — o yol calisir (`_telefonGonder` yeniden
      //	kod gonderir) ama kullaniciya HICBIR YERDE soylenmiyor.
      //	Gercek SMS'e gecildiginde bu bir SEVK ENGELI olur.
      // ⚠️ YAPMA: `_telefonGonder`i "artik cagrilmiyor" sanip silme —
      //    telefon adimi ve giris ekrani ONU kullaniyor.
    ],
  );

  // ------------------------------------------------------------ ADIM 1
  /// ⚠️⚠️ TURU 126 — **SIFRE, OTP'DEN ONCE** (kullanici emri: *"sifreden
  ///	sonra otp istesin"*). Ekranda burada alinir; SUNUCUYA EN SONDA
  ///	(`/auth/kayit/tamamla`) gider — sunucu sirasi DEGISMEDI.
  /// ⚠️ OTP bir onceki adimda ZATEN gonderildi; kullanici sifreyi yazarken
  ///    SMS yolda olur.
  Widget _adimSifre() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Güvenlik için', 'Bir şifre belirle'),
      // ⚠️ TURU 126 — SADE MOD: "Şifre" etiketi CIZILMEZ (kullanici emri) ve
      //    daireler GIRIS EKRANIYLA AYNI olur (ikisi de ayni tabani okur).
      AuthSifreAlani(
        controller: _sifre,
        ipucu: 'Şifren',
        sade: true,
        hataliMi: _sifreHatali,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _sifreHatali = false),
        onSubmitted: (_) => _sifreyiDogrula(),
      ),
      // ⚠️ Kurallar alanin ALTINDA ve DURUMA gore renklenir (bkz.
      //    `AuthSifreKurallari` serhi).
      AuthSifreKurallari(sifre: _sifre.text, hataliMi: _sifreHatali),
    ],
  );

  void _sifreyiDogrula() {
    // ⚠️⚠️ Kural TEK KAYNAKTAN (`AuthSifreKurallari.gecerli`): ekranda
    //	GOSTERILEN kurallarla DOGRULANAN kurallar ayri yazilsaydi biri
    //	degisince oteki geride kalir ve kullanici tumu yesilken "Devam"da
    //	takilirdi.
    // ⚠️ SnackBar YOK: eksik kural ZATEN ekranda, alanin altinda kirmiziya
    //    doner — ustune bir de kaybolan bir mesaj koymak gurultu olurdu.
    if (!AuthSifreKurallari.gecerli(_sifre.text)) {
      setState(() => _sifreHatali = true);
      return;
    }
    setState(() => _adim = 2); // -> KOD
  }

  // ------------------------------------------------------------ ADIM 3
  /// ⚠️⚠️ **KULLANICI ADI DA BURADA** (kullanici yalniz *"isim"* dedi).
  ///	Sunucu `/auth/kayit/tamamla` kullanici adini **ZORUNLU** tutuyor
  ///	(3-20 karakter, `^[a-z0-9_]+$`); kaldirilsaydi kayit HIC
  ///	tamamlanamazdi. Adi otomatik turetmek de secilmedi: cakisma
  ///	**409** doner ve kullanici SEBEBINI goremeden takilirdi.
  /// ⚠️ BEKLEYEN: kullanici adini isimden otomatik uretmek istenirse
  ///    sunucuda "musait mi" ucu + cakismada son ek mantigi gerekir.
  Widget _adimIsim() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Seni tanıyalım', 'Adın ne?'),
      TextField(
        controller: _ad,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: authDegerStili(),
        onChanged: (_) => setState(() => _adHatasi = null),
        decoration: authAlan(
          // ⚠️ TURU 126 — ETIKET CIZILMEZ (kullanici emri: *"Adin soyadini da
          //    kaldir"*); ipucu "Ad Soyad" alanin ne istedigini soyluyor.
          'Adın soyadın',
          ipucu: 'Ad Soyad',
          hataliMi: _adHatasi != null,
          // ⚠️ Dolu alanin cizgisi SIYAH kalir (bkz. `authAlan` serhi).
          sadeKoyuCizgi: _ad.text.isNotEmpty,
        ).copyWith(labelText: null),
      ),
      if (_adHatasi != null) authNot(_adHatasi!),
    ],
  );

  // ------------------------------------------------------------ ADIM 4
  /// ⚠️⚠️⚠️ **YESIL TIK "MUSAIT" DEMEK DEGIL, "BICIM DOGRU" DEMEK.**
  ///	Kullanici emri: *"en saginda yesilde daire icinde olsun ya da kirmizi
  ///	carp"*. Ancak sunucuda **"bu kullanici adi musait mi"** diye soran bir
  ///	uc YOK: `/users/search` OTURUM ISTER (kayitta oturum yoktur) ve
  ///	cakisma ancak son adimda `/auth/kayit/tamamla` **409** ile ogrenilir.
  /// ⚠️⚠️ Bu yuzden gosterge YALNIZCA BICIMI olcer — sunucunun DAYATTIGI
  ///	kuralin birebir aynisi. Musaitlik IDDIA ETMEZ; etseydi kullanici
  ///	yesil tik gorup son adimda 409 yiyecek ve uygulamanin YALAN
  ///	soyledigini dusunecekti.
  /// ⚠️ BEKLEYEN: gercek musaitlik icin OTURUMSUZ bir kontrol ucu gerekir
  ///    (arayuz turu oldugu icin acilmadi).
  Widget _adimKullaniciAdi() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Sana nasıl ulaşsınlar', 'Kullanıcı adın'),
      TextField(
        controller: _kullaniciAdi,
        textInputAction: TextInputAction.done,
        style: authDegerStili(),
        // ⚠️ Sunucu YALNIZ kucuk harf kabul ediyor (`^[a-z0-9_]{3,20}$`);
        //    buyuk harfe izin verilseydi kullanici yazabilir ama son adimda
        //    400 yerdi.
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
        ],
        onChanged: (_) => setState(() => _kullaniciAdiHatasi = null),
        decoration: authAlan(
          // ⚠️ TURU 126 — ETIKET CIZILMEZ (kullanici emri); ipucu ve
          //    altindaki kural satiri alanin ne istedigini soyluyor.
          'Kullanıcı adı',
          ipucu: 'ornek_kullanici',
          hataliMi: _kullaniciAdiHatasi != null,
          // ⚠️ Dolu alanin cizgisi SIYAH kalir (bkz. `authAlan` serhi).
          sadeKoyuCizgi: _kullaniciAdi.text.isNotEmpty,
        ).copyWith(labelText: null, suffixIcon: _kullaniciAdiGosterge()),
      ),
      if (_kullaniciAdiHatasi != null)
        authNot(_kullaniciAdiHatasi!)
      else ...[
        const SizedBox(height: 10),
        const Text(
          '3-20 karakter · küçük harf, rakam ve alt çizgi',
          style: TextStyle(fontSize: 13, color: _altYazi),
        ),
      ],
    ],
  );

  /// ⚠️ Bos iken HICBIR SEY cizilmez: taze bir alani kirmiziya boyamak
  ///    "bir sey yanlis yaptim" hissi verir (turu 120 dersi).
  Widget? _kullaniciAdiGosterge() {
    final k = _kullaniciAdi.text;
    if (k.isEmpty) return null;
    final gecerli = _kullaniciAdiBicimi(k);
    return Icon(
      gecerli ? LucideIcons.circleCheck : LucideIcons.circleX,
      size: 22,
      color: gecerli ? const Color(0xFF129D5A) : authHata,
    );
  }

  /// ⚠️ Sunucunun kurali BIREBIR (`kayit_adimli.go`): `^[a-z0-9_]{3,20}$`.
  ///    Gevsetilirse kullanici yesil tik gorur, son adimda 400 yer.
  bool _kullaniciAdiBicimi(String k) =>
      RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(k);

  // ------------------------------------------------------------ ADIM 4
  Widget _adimYas() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Biraz da senden', 'Kaç yaşındasın?'),
      // ⚠️ TURU 126 — BOLUM BASLIGI KALDIRILDI: yas artik KENDI ADIMI ve
      //    sayfa basligi ZATEN "Kaç yaşındasın?" — ayni cumle ust uste
      //    IKI KEZ yaziyordu (emulatorde goruldu).
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
      // ⚠️⚠️ TURU 126 — **ONAY/YONERGE SATIRI KALDIRILDI** (kullanici emri:
      //	*"20 yaşında yazmasın"*). Tekerlek artik BOS ("—") degil **20**`de
      //	aciliyor: kaydirilabilir oldugu, ustunde ve altinda duran komsu
      //	yaslardan ZATEN anlasiliyor — yonergenin varlik sebebi bos kutuydu.
      _yasSecici(),
    ],
  );

  // ------------------------------------------------------------ ADIM 5
  /// ⚠️⚠️⚠️ **CINSIYET SUNUCUYA GONDERILMIYOR** — sutun YOK (bkz.
  ///	`_cinsiyet` serhi). Deger yalnizca EKRANDA tutulur.
  /// ⚠️ Secenekler `profil_secenekleri.dart`ta DEGIL burada: sunucuda
  ///    karsiligi olmadigi icin paylasilan bir sabit gibi durmasi,
  ///    ileride "bu zaten var" yanilgisi yaratirdi.
  Widget _adimCinsiyet() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Paylaşmak istersen', 'Cinsiyetin'),
      // ⚠️ TURU 126 — "Belirtmek istemiyorum" KALDIRILDI (kullanici emri).
      //    Adim ZATEN opsiyonel: hicbirine dokunmadan "Devam" denebilir,
      //    yani ayri bir "belirtmek istemiyorum" secenegi GEREKSIZDI.
      for (final c in const ['Kadın', 'Erkek']) ...[
        _cinsiyetSecenegi(c),
        const SizedBox(height: 10),
      ],
    ],
  );

  /// ⚠️ TURU 126 — **1 px KENARLIKLI TAM GENISLIK DUGME** (kullanici emri:
  ///    *"cinsiyet ama buton 1px border gibi"*). Secilince kenarlik ve yazi
  ///    MARKA MORUNA doner; kalinlik 1 px KALIR — degisseydi dugme yuksekligi
  ///    oynar ve alttakiler 1 px ZIPLARDI.
  Widget _cinsiyetSecenegi(String etiket) {
    final secili = _cinsiyet == etiket;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        // ⚠️ Ikinci dokunus secimi KALDIRIR (kardes `_cip` ile ayni kural).
        onPressed: () => setState(() => _cinsiyet = secili ? '' : etiket),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: secili ? morLogo : _yazi,
          side: BorderSide(color: secili ? morLogo : _cizgi),
          // ⚠️ TURU 126 — YARICAP 12 (kullanici emri: *"seceneklerde radus
          //    olacak"*). Ana dugme DUZ KOSE kalir (turu 119 emri): bunlar
          //    SECIM ogesi, o EYLEM dugmesi.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Text(
          etiket,
          style: TextStyle(
            fontSize: 16,
            fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ADIM 6
  Widget _adimIlgi() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Neleri seversin', 'İlgi alanların'),
      // ⚠️ TURU 126 — BOLUM BASLIGI KALDIRILDI (sayfa basligiyla ayni).
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
      // ⚠️⚠️ TURU 126 — **"Tuttuğun takım" KALDIRILDI** (kullanici emri).
      //	`users.takim` sutunu (migration 049) ve `_takim` alani DURUYOR:
      //	profil duzenlemede hala doldurulabiliyor, yani sutun OLU DEGIL —
      //	yalnizca KAYIT AKISINDAN cikarildi.
      // ⚠️ YAPMA: sutunu "kullanilmiyor" sanip migration ile dusurme.
    ],
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
        // ⚠️⚠️ TURU 126 — **MOR ZEMIN VE YARICAP KALDIRILDI** (kullanici emri:
        //	*"kac yasindaki secildiginde mor arka plan radusu kaldir"*).
        //	Geriye yalniz UST/ALT ince cizgi kaldi — iOS tekerleginin dili.
        //	Secili rakam ZATEN mor, 26 px ve w800; bandin ayrica boyanmasina
        //	gerek yoktu.
        IgnorePointer(
          child: Container(
            height: 46,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: _cizgi),
                bottom: BorderSide(color: _cizgi),
              ),
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
        ListWheelScrollView.useDelegate(
          controller: _yasKontrol,
          itemExtent: 46,
          diameterRatio: 1.7,
          perspective: 0.0025,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) => setState(() => _yas = kEnKucukYas + i),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: kEnBuyukYas - kEnKucukYas + 1,
            builder: (_, i) {
              final deger = kEnKucukYas + i;
              final secili = _yas == deger;
              return Center(
                child: Text(
                  '$deger',
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
  Future<void> _avatariYukle(File? kirpik, MedyaServisi medya, Dio api) async {
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
        'Neredeyse bitti',
        // ⚠️ TURU 126 — METIN KISALDI (kullanici: *"yazilar cok uzun"*).
        //    Surukle/yakinlastir yonergesi ZATEN dairenin ALTINDA yaziyor.
        'Profil fotoğrafın',
      ),
      // ⚠️⚠️ TURU 126 — **DAIRE BASLIK ILE DUGME ARASINDA DIKEY ORTALI**
      //	(kullanici emri: *"o alani ortala, profil fotograf yazi ve buton
      //	arasinda"*). Onceden basligin hemen ALTINA yapisiyor, altta buyuk
      //	bir bosluk kaliyordu.
      // ⚠️ `Expanded` DEGIL: govde bir `SingleChildScrollView` icinde ve
      //    orada dikey kisit SINIRSIZ — `Expanded` "BoxConstraints forces an
      //    infinite height" ile PATLARDI (turu 117'de olculdu).
      //    Bunun yerine ekran yuksekliginden turetilen bir bosluk konuyor.
      SizedBox(height: MediaQuery.sizeOf(context).height * 0.06),
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
        : (
            oran >= 1 ? _kKirpCap * oran : _kKirpCap,
            oran >= 1 ? _kKirpCap : _kKirpCap / oran,
          );
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
                // ⚠️⚠️ TURU 126 — **BOS DAIREDE KENARLIK YOK** (kullanici emri:
                //	*"buyuk dairede border yok"*). Fotograf VARKEN beyaz halka
                //	KALIR: kirpma sinirini gosteren tek isaret odur; kaldirsak
                //	kullanici nereye kadar kirpildigini goremezdi.
                border: _fotoHam == null
                    ? null
                    // ⚠️⚠️ TURU 126 — **FOTOGRAF VARKEN DE KENARLIK/GOLGE YOK**
                    //	(kullanici emri: *"profil fotograf gelince etrafinda
                    //	blur vs golge border olmayacak"*).
                    // ⚠️ Kirpma sinirini artik YALNIZCA dairenin KENDISI
                    //    gosteriyor (`ClipOval`); halka gorsel bir susleme
                    //    olarak duruyordu, yapisal bir isaret degil.
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ TURU 126 — **IKON KALDIRILDI** (kullanici emri: *"profil resmi
  ///    icindeki dairenin ikonunu kaldir"*). Daire artik duz gri bir yer
  ///    tutucu; ne yapilacagini ALTINDAKI "Fotoğraf seç" dugmesi soyluyor.
  Widget _fotoBos() => const ColoredBox(color: Color(0xFFF2F2F5));

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
      // ⚠️⚠️ TURU 126 — **SIYAH** (kullanici emri: *"fotograf sec siyah olacak,
      //	border ikon vs hepsi"*). Onceki turda `vurgulu` ile MOR yapilmisti;
      //	kullanici GERI ALDI. `vurgulu` bayragi artik yalnizca KALINLIGI
      //	degistiriyor — ilk eylem hala bir tik belirgin.
      foregroundColor: _yazi,
      side: BorderSide(color: _yazi, width: vurgulu ? 1.5 : 1),
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
        ..translateByDouble(
          -(en - _kKirpCap) / 2,
          -(boy - _kKirpCap) / 2,
          0,
          1,
        );
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
      0 => ('Devam', _telefonGonder),
      1 => ('Devam', _sifreyiDogrula),
      2 => ('Doğrula', _koduDogrula),
      3 => ('Devam', _adiDogrula),
      4 => ('Devam', _kullaniciAdiniDogrula),
      5 => ('Devam', () => setState(() => _adim = 6)),
      6 => ('Devam', () => setState(() => _adim = 7)),
      7 => ('Devam', () => setState(() => _adim = 8)),
      _ => ('Hesabı oluştur', _hesabiKur),
    };
    return Padding(
      // ⚠️ `viewInsets` YALNIZ BURADA okunur: `build`in basinda okunsaydi
      //    klavye animasyonunun HER KARESINDE tum sayfa yeniden kurulurdu.
      padding: EdgeInsets.fromLTRB(
        28,
        8,
        28,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
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
