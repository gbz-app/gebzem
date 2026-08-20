import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (durum cubugu)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/tercihler.dart';
import '../../core/theme.dart';
import '../calls/callkit_service.dart';
import 'permissions_screen.dart' show izinSorulduIsaretle;

/// ⚠️⚠️⚠️ TURU 81 — ILK ACILIS ONBOARDING (4 EKRAN).
///
/// Kullanici emri: *"uygulama ilk acilisinda 4 tane onboarding olsun"* +
/// gonderdigi ekran goruntuleri (kalin baslik, bir kelimesi **italik vurgu**,
/// altinda gorsel/kart kompozisyonu).
///
/// ═══════════ TASARIM KARARLARI ═══════════
///
/// ⚠️ GORSEL ASSET **KULLANILMIYOR**, kompozisyon KOD ILE ciziliyor. Gerekce:
///   · Uygulamada bugun `assets/` altinda YALNIZ ikon kaynagi var; onboarding
///     icin 4 adet yuksek cozunurluklu gorsel eklemek APK'yi buyutur ve her
///     cihaz oraninda dogru gorunmesi icin birden fazla varyant ister.
///   · Kod ile cizilen kompozisyon TEMAYA UYUM SAGLAR (acik/koyu) — sabit
///     gorsel acik temada yanlis kontrastla dururdu.
/// ⚠️ EMOJI YOK — Lucide 2B ikon (kullanici emri, turu 62).
///
/// ⚠️⚠️ "GORULDU" BAYRAGI **SON SAYFADA DEGIL, CIKISTA** yazilir: kullanici
///    "Atla" derse de bir daha gormemeli. Yalniz son sayfada yazilsaydi
///    atlayan kullanici her acilista tekrar gorurdu.
/// ⚠️ Bayrak CIHAZ YERELIDIR (`shared_preferences`) — hesaba bagli degil.
///    Sunucuya yazmak yeni bir uc + migration demekti ve onboarding'in
///    hesaptan ONCE gosterilmesi gerekiyor (henuz oturum YOK).
class OnboardingEkrani extends ConsumerStatefulWidget {
  const OnboardingEkrani({super.key, required this.onBitti});

  /// ⚠️ Yonlendirmeyi EKRAN YAPMAZ, cagiran yapar (router tek kaynak).
  final VoidCallback onBitti;

  @override
  ConsumerState<OnboardingEkrani> createState() => _OnboardingEkraniState();
}

class _OnboardingEkraniState extends ConsumerState<OnboardingEkrani> {
  final _ctrl = PageController();
  int _sayfa = 0;

  /// Izin diyalogu ucustayken "Devam" kilitlenir (bkz. _devam serhi).
  bool _mesgul = false;

  /// ⚠️⚠️ TURU 84 — ACIKLAMALAR **KISALTILDI** (kullanici emri: *"baslik alta
  ///    KISA PROFESYONEL aciklama"*). Onceki metinler iki cumleydi ve ozellik
  ///    SAYIYORDU ("gruplar, sesli odalar, canli yayin da burada").
  ///    Yeni metinler TEK CUMLE ve **faydayi** soyluyor, ozellik listelemiyor —
  ///    profesyonel onboarding dili budur.
  /// ⚠️ YAPMA: buraya ozellik listesi geri koyma; her satir tek cumle kalsin.
  static const _sayfalar = <_Sayfa>[
    // ⚠️⚠️ TURU 89 — HER SAYFA KENDI IZNINI ISTER (kullanici emri).
    //    Aciklama metinleri IZNIN NEDEN GEREKTIGINI soyluyor; kullanici
    //    diyalogu gormeden ONCE gerekceyi okumus oluyor (App Store'un da
    //    bekledigi desen).
    _Sayfa(
      baslik: 'Sesli ve görüntülü',
      vurgu: 'konuş',
      alt:
          'Görüşme yapabilmek için mikrofona erişmemiz gerekiyor. '
          'Yalnızca sen arama başlattığında veya bir aramayı kabul '
          'ettiğinde kullanılır.',
      ikonlar: [LucideIcons.phone, LucideIcons.mic, LucideIcons.video],
      gorsel: _Gorsel.isletmeKartlari,
      izin: _OnboardIzin.mikrofon,
    ),
    _Sayfa(
      baslik: 'Görüntülü aramada',
      vurgu: 'kameran',
      alt:
          'Görüntülü görüşme ve hikâye paylaşımı için kamera izni. '
          'Kamerayı yalnızca sen açtığında çalışır.',
      ikonlar: [LucideIcons.video, LucideIcons.camera, LucideIcons.images],
      gorsel: _Gorsel.aiTelefon,
      izin: _OnboardIzin.kamera,
    ),
    _Sayfa(
      baslik: 'Gelen aramayı',
      vurgu: 'kaçırma',
      alt:
          'Mesaj ve aramaları görebilmen için bildirim izni gerekiyor. '
          'İzin vermezsen telefonun çalmaz.',
      ikonlar: [
        LucideIcons.bell,
        LucideIcons.messageCircle,
        LucideIcons.phoneIncoming,
      ],
      gorsel: _Gorsel.mesajKartlari,
      izin: _OnboardIzin.bildirim,
    ),
    // ⚠️ TAM EKRAN BILDIRIM EN SON: sistem AYARLAR ekranini acar ve Activity
    //    duraklar. Ortada olsaydi sonraki izin diyalogu GOSTERILMEZDI
    //    (turu 56'da tam bu yuzden READ_PHONE_STATE 36 tur boyunca hic
    //    alinamadi).
    _Sayfa(
      baslik: 'Telefon kilitliyken',
      vurgu: 'arama ekranı',
      alt:
          'Telefonun kilitliyken gelen aramanın ekranda açılabilmesi için '
          'son bir izin. Bir sonraki adımda ayarlar açılabilir.',
      ikonlar: [
        LucideIcons.smartphone,
        LucideIcons.bellRing,
        LucideIcons.circleCheck,
      ],
      gorsel: _Gorsel.aramaTelefon,
      izin: _OnboardIzin.tamEkran,
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bitir() async {
    // ⚠️ Bayrak ONCE yazilir, sonra yonlendirilir: ters sirada olsaydi
    //    yonlendirme sirasinda uygulama oldurulurse onboarding TEKRAR cikardi.
    await tercihler.onboardingGorulduYaz();
    // ⚠️ TURU 89 — izin akisinin KOSTUGU isaretlenir; `HomeScreen` kapisi
    //    ayni oturumda izin ekranini bir daha ACMAZ (o ekran zaten silindi
    //    ama bayrak kapiyi da susturur).
    await izinSorulduIsaretle();
    if (mounted) widget.onBitti();
  }

  /// ⚠️⚠️⚠️ TURU 89 — "DEVAM": once SAYFANIN IZNI istenir, SONRA gecilir.
  ///
  ///	Kullanici emri: *"o izin ekrani icin ayri sayfayi kaldir, onboardingte
  ///	SIRAYLA GECERKEN izin alinsin"*.
  ///
  /// ⚠️ IZIN REDDEDILSE BILE AKIS DEVAM EDER. Zorlamak (a) App Store
  ///    incelemesinde kotu karsilanir, (b) kullaniciyi ilk ekranda kaybettirir.
  ///    Reddeden kullanici izinleri sonra Ayarlar > İzinler'den verebilir.
  /// ⚠️ `_mesgul` kapisi ZORUNLU: izin diyalogu acikken "Devam"a tekrar
  ///    basmak IKINCI bir istek gonderir ve Android ayni anda TEK izin kumesi
  ///    kabul ettigi icin ikincisi SESSIZCE `denied` doner (turu 87 carpismasi).
  /// ⚠️ Her adim KENDI `try` blogunda: biri firlarsa sonrakiler ve sayfa
  ///    gecisi ETKILENMEZ.
  Future<void> _devam(bool son) async {
    if (_mesgul) return;
    final izin = _sayfalar[_sayfa].izin;
    if (izin != null) {
      setState(() => _mesgul = true);
      try {
        switch (izin) {
          case _OnboardIzin.bildirim:
            await Permission.notification.request();
          case _OnboardIzin.mikrofon:
            await Permission.microphone.request();
          case _OnboardIzin.kamera:
            await Permission.camera.request();
          case _OnboardIzin.tamEkran:
            // ⚠️ `bildirimIste: false` — POST_NOTIFICATIONS bir onceki
            //    sayfada ZATEN istendi. Tekrar istemek turu 87'de belgelenen
            //    carpismayi (READ_PHONE_STATE sessizce `denied`) uretir.
            await CallKitService.izinleriIste(bildirimIste: false);
            // Pil optimizasyonu muafiyeti: kapaliyken arama alabilmek icin.
            if (Platform.isAndroid) {
              try {
                if (!await Permission.ignoreBatteryOptimizations.isGranted) {
                  await Permission.ignoreBatteryOptimizations.request();
                }
              } catch (_) {}
            }
        }
      } catch (_) {
        // Izin reddi ya da platform hatasi AKISI DURDURMAZ.
      }
      if (!mounted) return;
      setState(() => _mesgul = false);
    }
    if (!mounted) return;
    if (son) {
      await _bitir();
    } else {
      await _ctrl.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final son = _sayfa == _sayfalar.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // ⚠️ TURU 85b — beyaz zeminde durum cubugu ikonlari KOYU olmali;
      //    gerekcenin tamami `kayit_akisi.dart` build() serhinde.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      // ⚠️ TURU 85b — acik temaya sarilir; gerekce `kayit_akisi.dart` build()
      //    serhinde (beyaz zemin + koyu tema = gorunmez metin/imlec).
      child: Theme(data: lightTheme, child: _govde(son)),
    );
  }

  Widget _govde(bool son) {
    return Scaffold(
      // ⚠️⚠️ TURU 84 — **ZEMIN BEYAZ** (kullanici emri: "arka plan beyaz").
      //
      //    Tema `scaffoldBackgroundColor`i KULLANILMAZ: koyu temada zemin
      //    `0xFF1C1C1E` olurdu ve kullanicinin acikca istedigi beyaz tasarim
      //    yalnizca acik temadaki kullanicilarda gorunurdu.
      // ⚠️ ZEMIN SABITLENDIGI ICIN YAZI RENKLERI DE SABIT (`_kOnboardYazi` /
      //    `_kOnboardAltYazi`). Temadan alinsaydi koyu temada BEYAZ yazi
      //    BEYAZ zemine cizilirdi — turu 81b'de sohbet balonlarinda yasanan
      //    1.23:1 kontrast hatasinin birebir aynisi.
      // ⚠️ YAPMA: buradaki renkleri temaya baglama.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              // ⚠️ Renk SABIT: temadan alinsaydi koyu temada BEYAZ olur ve
              //    beyaz zeminde GORUNMEZDI (zemin artik sabit beyaz).
              child: TextButton(
                onPressed: _bitir,
                style: TextButton.styleFrom(foregroundColor: _kOnboardAltYazi),
                child: const Text('Atla'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _sayfalar.length,
                onPageChanged: (i) => setState(() => _sayfa = i),
                itemBuilder: (_, i) => _SayfaGorunumu(s: _sayfalar[i]),
              ),
            ),
            // Nokta gostergesi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sayfalar.length, (i) {
                final aktif = i == _sayfa;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: aktif ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    // ⚠️ Pasif nokta rengi de SABIT (zemin beyaz — temadan
                    //    alinsaydi koyu temada beyaz nokta beyaz zemine
                    //    cizilir ve gosterge KAYBOLURDU).
                    color: aktif
                        ? morLogo
                        : _kOnboardAltYazi.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  // ⚠️ TURU 89 — izin ONCE istenir, sonra gecilir/bitirilir
                  //    (bkz. `_devam` serhi).
                  onPressed: _mesgul ? null : () => _devam(son),
                  style: FilledButton.styleFrom(
                    backgroundColor: morLogo,
                    // ⚠️⚠️ TURU 85b — `foregroundColor` ACIKCA BEYAZ (denetim).
                    //    Verilmezse `FilledButton` yazi rengini
                    //    `colorScheme.onPrimary`den alir; KOYU temada bu deger
                    //    KOYU olduğu icin mor dugmenin uzerinde ~1.9:1
                    //    kontrast cikiyor ve **"Devam"/"Başla" yazisi
                    //    okunamiyordu**. Zemin sabit beyaz yapildigi icin bu
                    //    ekran temanin geri kalanindan KOPUKTUR; renkler de
                    //    sabit olmak ZORUNDA (turu 81b dersi).
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    son ? 'Başla' : 'Devam',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚠️ Onboarding zemini SABIT BEYAZ oldugu icin yazi renkleri de SABIT.
///    Temadan alinsalardi koyu temada beyaz-uzeri-beyaz cikardi.
const Color _kOnboardYazi = Color(0xFF14141A);
const Color _kOnboardAltYazi = Color(0xFF6B6B76);

class _Sayfa {
  const _Sayfa({
    required this.baslik,
    required this.gorsel,
    required this.vurgu,
    required this.alt,
    required this.ikonlar,
    this.izin,
  });

  final String baslik;

  /// ⚠️ TURU 118 — sayfanin UST %60'inda oynayan animasyon.
  final _Gorsel gorsel;

  /// Baslikta AYRI cizilen kelime.
  /// ⚠️ TURU 89: artik italik/mor DEGIL — baslikla birlestirilip SIYAH cizilir
  ///    (kullanici emri). Alan KORUNDU: metin ayrimi okunakli kaliyor.
  final String vurgu;
  final String alt;
  final List<IconData> ikonlar;

  /// ⚠️⚠️ TURU 89 — SAYFANIN ISTEDIGI IZIN (kullanici emri: *"o izin ekrani
  ///    icin ayri sayfayi kaldir, onboardingte SIRAYLA GECERKEN izin
  ///    alinsin"*).
  ///
  /// "Devam"a basildiginda, BIR SONRAKI sayfaya gecmeden ONCE bu izin
  /// istenir. `null` ise izin istenmez.
  /// ⚠️ Izin REDDEDILSE BILE akis DEVAM EDER — zorlama yok (App Store
  ///    incelemesinde de kotu karsilanir ve kullaniciyi kaybettirir).
  final _OnboardIzin? izin;
}

/// Onboarding sayfalarinin isteyebilecegi izinler.
///
/// ⚠️ `tamEkran` (Android 14+ tam ekran bildirim) BILEREK EN SONA konuldu:
///    o izin SISTEM AYARLAR EKRANINI acar ve Activity duraklar. Ortada
///    istenirse `PageView` durumu bozulur ve ardindan gelen izin diyalogu
///    GOSTERILMEZ (turu 56 dersi: "ayar ekranina sicrama EN SON").
enum _OnboardIzin { bildirim, mikrofon, kamera, tamEkran }

class _SayfaGorunumu extends StatelessWidget {
  const _SayfaGorunumu({required this.s});

  final _Sayfa s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ⚠️⚠️ TURU 85b — SAYFA **KAYDIRILABILIR** (denetim bulgusu).
    //    Govde sabit yuksekliklerden olusuyor (168 gorsel + 40 bosluk + 30px
    //    baslik + aciklama). Sistem yazi olcegi 1.5 ve ustunde toplam
    //    yukseklik viewport'u asiyor ve `Column` **RenderFlex OVERFLOW**
    //    sari-siyah seridini ciziyordu — kullanicinin gordugu ILK ekranda.
    //    Kayit akisi (`kayit_akisi.dart`) `SingleChildScrollView` ile
    //    ZATEN korunmustu; onboarding ATLANMISTI (asimetri = hatanin kendisi).
    // ⚠️ `ConstrainedBox` + `IntrinsicHeight` DEGIL: `minHeight` ile
    //    `mainAxisAlignment: center` normal cihazlarda ORTALAMAYI KORUR,
    //    yalnizca sigmadiginda kaydirma devreye girer.
    // ⚠️ `ClampingScrollPhysics` degil `AlwaysScrollable...`: `PageView`
    //    icindeki dikey kaydirma yatay sayfa gecisiyle CAKISMAZ (eksenler ayri).
    return LayoutBuilder(
      builder: (_, kisit) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: kisit.maxHeight),
          child: _icerik(scheme, kisit.maxHeight * 0.6),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 89 — SADE KARSILAMA (kullanici emri).
  ///
  ///	*"onboarding ekranindaki IKONLARI ve arkasindaki KARTLARI kaldir ·
  ///	yazilarda EGIM vs olmasin · SOL USTTE yazsin SIYAH, altinda aciklama"*.
  ///
  /// KALDIRILANLAR:
  ///   · uc adet mor gradyanli ikon karti (`_kart`) ve 168px'lik alani,
  ///   · basligin ikinci parcasindaki `FontStyle.italic` (EGIM),
  ///   · vurgu parcasinin MOR rengi -> baslik TAMAMEN SIYAH.
  ///
  /// ⚠️ Dikey hizalama `center` -> `start`: kullanici **"SOL USTTE"** dedi.
  ///    Yalniz `crossAxisAlignment` degistirilseydi yazi SOLDA ama DIKEY
  ///    ORTADA kalirdi (iki eksen AYRI ayarlanir).
  /// ⚠️ Baslik artik tek parca `Text` — `RichText` GEREKMIYOR cunku iki
  ///    parcanin bicimi ayni. `_Sayfa.vurgu` alani KORUNDU: metin ayrimi
  ///    okunakli kaliyor ve vurgu ileride geri istenirse yerinde duruyor.
  /// ⚠️ YAPMA: buraya ikon/kart/gradyan geri koyma; egim (italic) ekleme.
  /// ⚠️⚠️⚠️ TURU 118 — UST **%60**'TA ANIMASYON (kullanici emri:
  ///	*"loading animasyonlu olsun giris ekraninda ... ekran
  ///	yuksekliginden %60 alanda ornegin YEMEK alanindaki firmalar KART
  ///	seklinde ASAGIDAN YUKARI dogru gelsin ... diger onboardingde
  ///	CEKIN IPHONE olsun, yapay zekaya soru soruyoruz o da cevapliyor"*).
  ///
  /// ⚠️ Yukseklik EKRANDAN turetilir (`kisit.maxHeight * 0.6`), sabit dp
  ///    DEGIL: kucuk telefonda sabit bir sayi yaziyi ekran disina iterdi.
  /// ⚠️ Animasyonlar `RepaintBoundary` icinde: surekli donen bir katman,
  ///    altindaki yazilari her karede yeniden boyamasin.
  Widget _icerik(ColorScheme scheme, double alanYuksekligi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: alanYuksekligi,
          width: double.infinity,
          child: RepaintBoundary(child: _gorselAlani()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                [s.baslik, s.vurgu].where((x) => x.isNotEmpty).join(' '),
                textAlign: TextAlign.left,
                style: const TextStyle(
                  // ⚠️ TURU 118: 30 -> 26. Gorsel alani yuksekligin %60'ini
                  //    aldigi icin yaziya kalan alan daraldi; 30 px, kucuk
                  //    telefonlarda iki satirlik baslikta aciklamayi ekran
                  //    disina itiyordu.
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  // ⚠️ SIYAH ve SABIT: zemin sabit beyaz oldugu icin renk TEMADAN
                  //    alinamaz (koyu temada beyaz yazi beyaz zemine cizilirdi —
                  //    turu 81b kontrast hatasi).
                  color: _kOnboardYazi,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.alt,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: _kOnboardAltYazi,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gorselAlani() => switch (s.gorsel) {
    _Gorsel.isletmeKartlari => const _KartAkisi(tur: _AkisTuru.isletme),
    _Gorsel.mesajKartlari => const _KartAkisi(tur: _AkisTuru.mesaj),
    _Gorsel.aiTelefon => const _Telefon(tur: _TelefonTuru.ai),
    _Gorsel.aramaTelefon => const _Telefon(tur: _TelefonTuru.arama),
  };

  // ⚠️ TURU 89 — `_kart()` (mor gradyanli ikon karti) SILINDI: kullanici
  //    "ikonlari ve arkasindaki kartlari kaldir" dedi. Bayrakla kapatilmadi,
  //    cunku geri istenirse tasarim ZATEN bastan konusulacak.
}

/// Sayfanin ust %60'inda oynayan gorsel.
enum _Gorsel { isletmeKartlari, aiTelefon, mesajKartlari, aramaTelefon }

enum _AkisTuru { isletme, mesaj }

/// ⚠️⚠️⚠️ TURU 118 — **ASAGIDAN YUKARI AKAN KARTLAR** (kullanici emri:
///	*"ornegin yemek alanindaki firmalar KART seklinde ASAGIDAN YUKARI
///	dogru gelsin, onlar gorunsun"*).
///
/// ⚠️⚠️ **SONSUZ DONGU ICIN LISTE IKI KEZ CIZILIR.** Kaydirma miktari
///	`ilerleme * tekBoy` kadar yukari gider; `tekBoy`a ulastiginda ikinci
///	kopya tam ilk kopyanin yerine oturur ve denetleyici basa sardiginda
///	GORSEL SICRAMA OLMAZ. Tek kopyayla dongunun sonunda liste bir anda
///	asagi ziplardi.
///
/// ⚠️ Kenarlarda `ShaderMask` ile SOLMA var: kartlar aniden belirip
///    kaybolmak yerine yumusakca giriyor/cikiyor (`BlendMode.dstIn` +
///    saydam uclu gradyan = alfa maskesi).
///    ⚠️ `ShaderMask` bir `saveLayer` acar; agac bu yuzden `RepaintBoundary`
///       icinde cizilir (bkz. `_icerik`).
///
/// ⚠️⚠️ **VERI UYDURULMADI:** kartlar uygulamanin GERCEK kategorilerini
///	gosterir (menudeki izgarayla ayni adlar). Sahte isletme adi, sahte
///	puan ya da sahte mesafe YAZILMAZ — tanitim gorseli olsa bile proje
///	kurali "olmayan veriyi varmis gibi gosterme" diyor.
class _KartAkisi extends StatefulWidget {
  const _KartAkisi({required this.tur});

  final _AkisTuru tur;

  @override
  State<_KartAkisi> createState() => _KartAkisiState();
}

class _KartAkisiState extends State<_KartAkisi>
    with SingleTickerProviderStateMixin {
  // ⚠️ 14 sn: kartlar OKUNABILECEK kadar yavas aksin. Hizli akan bir serit
  //    "yukleniyor" gibi degil "bozuk" gibi gorunuyor.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _isletmeler = <(IconData, String, String)>[
    // ⚠️ TURU 119 — kullanici emri: *"yakinimdayi da koyalim"*.
    (LucideIcons.mapPin, 'Yakınımda', 'Çevrendeki işletmeler'),
    (LucideIcons.utensils, 'Yemek', 'Restoran · Döner · Pide'),
    (LucideIcons.coffee, 'Kafe', 'Kahve · Tatlı'),
    (LucideIcons.scissors, 'Kuaför', 'Saç · Bakım'),
    (LucideIcons.pill, 'Eczane', 'Nöbetçi eczane'),
    (LucideIcons.shoppingBag, 'Alışveriş', 'Market · Giyim'),
    (LucideIcons.wrench, 'Hizmet', 'Tamir · Temizlik'),
  ];

  static const _mesajlar = <(IconData, String, String)>[
    (LucideIcons.messageCircle, 'Mesajlar', 'Sohbet ve gruplar'),
    (LucideIcons.radio, 'Topluluklar', 'Sen yazarsın, üyeler okur'),
    (LucideIcons.phoneIncoming, 'Aramalar', 'Sesli ve görüntülü'),
    (LucideIcons.bellRing, 'Bildirimler', 'Hiçbir şeyi kaçırma'),
    (LucideIcons.audioLines, 'Sesli oda', 'Canlı sohbet'),
    (LucideIcons.mapPin, 'Mahalle', 'Çevrendeki paylaşımlar'),
  ];

  @override
  Widget build(BuildContext context) {
    final veri = widget.tur == _AkisTuru.isletme ? _isletmeler : _mesajlar;
    const kartBoy = 78.0;
    const ara = 12.0;
    final tekBoy = veri.length * (kartBoy + ara);

    return ClipRect(
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.16, 0.80, 1.0],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: AnimatedBuilder(
          animation: _c,
          // ⚠️⚠️ `OverflowBox` ZORUNLU: liste sonsuz dongu icin IKI KEZ
          //	ciziliyor, yani `Column` ust alandan (kutu yuksekligi) DAHA
          //	UZUN. Ebeveyn SINIRLI yukseklik verdigi icin Flutter
          //	"RenderFlex overflowed by 664 pixels" atiyor ve ekrana
          //	SARI-SIYAH serit ciziyordu — oysa tasma KASITLI, zaten
          //	ustteki `ClipRect` kirpiyor.
          //	`OverflowBox` cocuga SINIRSIZ yukseklik verir.
          // ⚠️ `alignment: topCenter`: liste USTTEN baslasin, yoksa
          //    `Transform` ofseti yanlis referanstan hesaplanir.
          builder: (_, _) => OverflowBox(
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -_c.value * tekBoy),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ⚠️ Liste IKI KEZ: sonsuz dongu icin (bkz. sinif serhi).
                  for (var tekrar = 0; tekrar < 2; tekrar++)
                    for (final v in veri)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, ara),
                        child: _kart(v.$1, v.$2, v.$3, kartBoy),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kart(IconData ikon, String ad, String alt, double boy) => Container(
    height: boy,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x14000000)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B3FFF), Color(0xFF6C2BD9)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(ikon, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ad,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _kOnboardYazi,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                alt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: _kOnboardAltYazi),
              ),
            ],
          ),
        ),
        const Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: Color(0x40000000),
        ),
      ],
    ),
  );
}

enum _TelefonTuru { ai, arama }

/// ⚠️⚠️⚠️ TURU 118 — **TELEFON MOCKUP** (kullanici emri: *"diger
///	onboardingde CEKIN IPHONE olsun, yapay zekaya soru soruyoruz o da
///	cevapliyor, bu sekilde"*).
///
/// Cerceve ELLE cizilir (gorsel dosyasi YOK): bir PNG telefon cercevesi hem
/// paket boyutu hem de olcek/tema uyumu sorunu demekti.
///
/// ⚠️ Sahne bir ZAMAN CIZELGESI: soru balonu -> "yaziyor" noktalari -> yanit
///    balonu -> bekle -> basa sar. Tek `AnimationController`; her parca kendi
///    araligini `_oran(bas, son)` ile okur.
/// ⚠️ Yanit metni KISA tutuldu: uzun metin telefon cercevesini tasirdi ve
///    mockup "bozuk" gorunurdu.
class _Telefon extends StatefulWidget {
  const _Telefon({required this.tur});

  final _TelefonTuru tur;

  @override
  State<_Telefon> createState() => _TelefonState();
}

class _TelefonState extends State<_Telefon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [bas]-[son] araliginda 0..1 oran; disinda 0 ya da 1.
  double _oran(double bas, double son) {
    final t = _c.value;
    if (t <= bas) return 0;
    if (t >= son) return 1;
    return (t - bas) / (son - bas);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: _c,
      // ⚠️ Sabit ORAN (9:19.5 = iPhone): ust alan yuksekligi cihazdan cihaza
      //    degisse de cerceve ORANINI KORUR, yani hicbir ekranda ezilmez.
      builder: (_, _) => FractionallySizedBox(
        heightFactor: 0.94,
        child: AspectRatio(aspectRatio: 9 / 19.5, child: _cerceve()),
      ),
    ),
  );

  Widget _cerceve() => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xFF14101C),
      borderRadius: BorderRadius.circular(38),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 26,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(31),
      child: ColoredBox(
        color: const Color(0xFFF7F6FB),
        child: Column(
          children: [
            // ── DYNAMIC ISLAND ──
            Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 6),
              child: Container(
                width: 62,
                height: 17,
                decoration: BoxDecoration(
                  color: const Color(0xFF14101C),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            Expanded(
              child: widget.tur == _TelefonTuru.ai
                  ? _aiSahnesi()
                  : _aramaSahnesi(),
            ),
          ],
        ),
      ),
    ),
  );

  // ═══════════ AI SOHBETI ═══════════
  Widget _aiSahnesi() {
    final soru = _oran(0.10, 0.24);
    final yaziyor = _oran(0.30, 0.36) * (1 - _oran(0.46, 0.52));
    final yanit = _oran(0.52, 0.66);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B3FFF), Color(0xFF6C2BD9)],
                  ),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'GebzemAI',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _kOnboardYazi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _balon(
            metin: 'Gebze’de hafta sonu\nne yapılır?',
            benim: true,
            gorunur: soru,
          ),
          const SizedBox(height: 9),
          if (yaziyor > 0.02 && yanit < 0.02)
            Opacity(opacity: yaziyor.clamp(0, 1), child: _yaziyorBalonu()),
          if (yanit > 0.02)
            _balon(
              metin:
                  'Eskihisar’da sahil yürüyüşü,\nakşam merkezde kahve —\n'
                  'listeyi çıkarayım mı?',
              benim: false,
              gorunur: yanit,
            ),
        ],
      ),
    );
  }

  /// ⚠️ Balon ASAGIDAN yukari kayarak gelir + solar: aninda beliren bir balon
  ///    "hata" gibi gorunuyordu.
  Widget _balon({
    required String metin,
    required bool benim,
    required double gorunur,
  }) {
    final o = Curves.easeOutCubic.transform(gorunur.clamp(0, 1));
    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(0, (1 - o) * 14),
        child: Opacity(
          opacity: o,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 152),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: benim ? const Color(0xFF6C2BD9) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(benim ? 14 : 4),
                bottomRight: Radius.circular(benim ? 4 : 14),
              ),
              border: benim ? null : Border.all(color: const Color(0x14000000)),
            ),
            child: Text(
              metin,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: benim ? Colors.white : _kOnboardYazi,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _yaziyorBalonu() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14),
        topRight: Radius.circular(14),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(14),
      ),
      border: Border.all(color: const Color(0x14000000)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
            child: Opacity(
              // ⚠️ Uc nokta SIRAYLA yanar: faz `i` ile kaydiriliyor.
              opacity:
                  (0.35 +
                          0.65 *
                              (0.5 + 0.5 * math.sin(_c.value * 22 - i * 1.1)))
                      .clamp(0.0, 1.0),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B3FFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ═══════════ KILIT EKRANINDA GELEN ARAMA ═══════════
  Widget _aramaSahnesi() {
    final gel = _oran(0.12, 0.30);
    final o = Curves.easeOutCubic.transform(gel.clamp(0, 1));
    // ⚠️ Nabiz: arama "caliyor" hissi (1.00 - 1.06 arasi).
    final nabiz = 1 + 0.06 * (0.5 + 0.5 * math.sin(_c.value * 26));
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A1B4D), Color(0xFF14101C)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                '9:41',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              Text(
                'Salı, 20 Ağustos',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 22,
          child: Transform.translate(
            offset: Offset(0, (1 - o) * 40),
            child: Opacity(
              opacity: o,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: nabiz,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF8B3FFF), Color(0xFF6C2BD9)],
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.phoneIncoming,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Gebzem',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Görüntülü arama',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: _aramaDugmesi(
                            const Color(0xFFE5484D),
                            LucideIcons.phoneOff,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _aramaDugmesi(
                            const Color(0xFF2FBF71),
                            LucideIcons.phone,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _aramaDugmesi(Color renk, IconData ikon) => Container(
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: renk,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(ikon, size: 15, color: Colors.white),
  );
}
