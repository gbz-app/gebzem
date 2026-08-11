import 'dart:io';

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
      alt: 'Görüşme yapabilmek için mikrofona erişmemiz gerekiyor. '
          'Yalnızca sen arama başlattığında veya bir aramayı kabul '
          'ettiğinde kullanılır.',
      ikonlar: [LucideIcons.phone, LucideIcons.mic, LucideIcons.video],
      izin: _OnboardIzin.mikrofon,
    ),
    _Sayfa(
      baslik: 'Görüntülü aramada',
      vurgu: 'kameran',
      alt: 'Görüntülü görüşme ve hikâye paylaşımı için kamera izni. '
          'Kamerayı yalnızca sen açtığında çalışır.',
      ikonlar: [LucideIcons.video, LucideIcons.camera, LucideIcons.images],
      izin: _OnboardIzin.kamera,
    ),
    _Sayfa(
      baslik: 'Gelen aramayı',
      vurgu: 'kaçırma',
      alt: 'Mesaj ve aramaları görebilmen için bildirim izni gerekiyor. '
          'İzin vermezsen telefonun çalmaz.',
      ikonlar: [
        LucideIcons.bell,
        LucideIcons.messageCircle,
        LucideIcons.phoneIncoming,
      ],
      izin: _OnboardIzin.bildirim,
    ),
    // ⚠️ TAM EKRAN BILDIRIM EN SON: sistem AYARLAR ekranini acar ve Activity
    //    duraklar. Ortada olsaydi sonraki izin diyalogu GOSTERILMEZDI
    //    (turu 56'da tam bu yuzden READ_PHONE_STATE 36 tur boyunca hic
    //    alinamadi).
    _Sayfa(
      baslik: 'Telefon kilitliyken',
      vurgu: 'arama ekranı',
      alt: 'Telefonun kilitliyken gelen aramanın ekranda açılabilmesi için '
          'son bir izin. Bir sonraki adımda ayarlar açılabilir.',
      ikonlar: [
        LucideIcons.smartphone,
        LucideIcons.bellRing,
        LucideIcons.circleCheck,
      ],
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
    required this.vurgu,
    required this.alt,
    required this.ikonlar,
    this.izin,
  });

  final String baslik;

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
          child: _icerik(scheme),
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
  Widget _icerik(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            [s.baslik, s.vurgu].where((x) => x.isNotEmpty).join(' '),
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 30,
              height: 1.22,
              fontWeight: FontWeight.w800,
              // ⚠️ SIYAH ve SABIT: zemin sabit beyaz oldugu icin renk TEMADAN
              //    alinamaz (koyu temada beyaz yazi beyaz zemine cizilirdi —
              //    turu 81b kontrast hatasi).
              color: _kOnboardYazi,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.alt,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: _kOnboardAltYazi,
            ),
          ),
        ],
      ),
    );
  }

  // ⚠️ TURU 89 — `_kart()` (mor gradyanli ikon karti) SILINDI: kullanici
  //    "ikonlari ve arkasindaki kartlari kaldir" dedi. Bayrakla kapatilmadi,
  //    cunku geri istenirse tasarim ZATEN bastan konusulacak.
}
