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
    // ⚠️⚠️ TURU 126 — SAYFA **GEBZEMAI DILINE** cevrildi (kullanici emri:
    //	*"goruntulu aramada kameran yerine GebzemAI ile ilgili bir seyler
    //	yaz"*). Sayfanin gorseli ZATEN AI sohbetiydi (`aiTelefon`) — metin
    //	kameradan bahsederken ekranda yapay zeka sohbeti akiyordu, yani
    //	YAZIYLA RESIM CELISIYORDU.
    // ⚠️⚠️ **IZIN AYNEN KALDI** (`kamera`): metin degisti, istenen izin
    //	DEGISMEDI. Kamera izni goruntulu arama ve hikaye icin ZORUNLU ve
    //	bu, onboardingde istendigi TEK yer.
    // ⚠️ Metin izni de SOYLUYOR: istenmeyen bir izin diyalogu cikarsa
    //    kullanici "neden kamera istiyor" der. Son cumle tam bunu kapatir.
    _Sayfa(
      // ⚠️ TURU 126 — baslik ve aciklama KISALDI (kullanici: *"cok uzun,
      //    daha profesyonel guzel olsun"*). Baslik iki satirdan TEK satira
      //    indi; aciklama uc cumleden IKIYE.
      // ⚠️ Kamera izni cumlesi KALDI ama tek kelimeye indi: bu sayfa kamera
      //    iznini istiyor ve sebebini SOYLEMEDEN diyalog acmak olmaz.
      baslik: 'Sor, Gebzem',
      vurgu: 'cevaplasın',
      alt:
          'Nöbetçi eczane, hafta sonu programı, akşam nerede yenir — '
          'Gebze’ye dair her şeyi bilir. Görüntülü görüşme için kamera izni.',
      ikonlar: [
        LucideIcons.sparkles,
        LucideIcons.messageCircle,
        LucideIcons.video,
      ],
      gorsel: _Gorsel.aiTelefon,
      izin: _OnboardIzin.kamera,
    ),
    // ⚠️⚠️ TURU 126 — SAYFA **HIZMET DILINE** cevrildi (kullanici emri:
    //	*"gelen aramayi kacirma onboardingi kaldir, onun yerine
    //	hizmetlerle ilgili bir sey yap"*).
    // ⚠️⚠️ **IZIN AYNEN KALDI** (`bildirim`): metin degisti, istenen izin
    //	DEGISMEDI. Bildirim izni olmadan mesaj/arama/teklif bildirimi HIC
    //	gelmez; sayfayi izinsiz birakmak o izni istenmeyen tek yer
    //	(Ayarlar > IZINLER) haline getirirdi.
    // ⚠️ Metin ARTIK YALNIZ ARAMADAN bahsetmiyor ama BILDIRIMDEN
    //    bahsediyor — istenen izinle SOYLENEN sey ortusuyor.
    _Sayfa(
      baslik: 'Teklifler ve mesajlar',
      vurgu: 'anında',
      alt:
          'Hizmet talebine gelen teklifleri, randevu onaylarını ve '
          'mesajları anında görebilmen için bildirim izni gerekiyor.',
      ikonlar: [
        LucideIcons.bell,
        LucideIcons.messageCircle,
        LucideIcons.handshake,
      ],
      gorsel: _Gorsel.mesajKartlari,
      izin: _OnboardIzin.bildirim,
    ),
    // ⚠️⚠️⚠️ TURU 120 — **KONUM SAYFASI** (kullanici emri: *"konumla ilgili,
    //	YAKINIMDA ile ilgili onboardinge ekle"*).
    //
    // ⚠️ NEDEN BURADA (4. SIRA): konum diyalogu sistem AYARLARINI ACMAZ,
    //    yani sirasi serbest. Ama TAM EKRAN BILDIRIMDEN ONCE olmak ZORUNDA —
    //    o sayfa Ayarlar'a sicrar ve Activity duraklar; sonrasina konulan
    //    her izin diyalogu GOSTERILMEZDI (turu 56 dersi).
    // ⚠️ `Permission.locationWhenInUse` — `konum_servisi.dart` ile AYNI izin.
    //    `location` (her zaman) ISTENMEZ: uygulama arka planda konum
    //    kullanmiyor ve "her zaman" istemek magaza incelemesinde gerekce
    //    ister, ustelik kullanicilarin reddetme orani cok yuksektir.
    _Sayfa(
      baslik: 'Yakınındakileri',
      vurgu: 'keşfet',
      alt:
          'Çevrendeki işletmeleri, mahallendeki paylaşımları ve en yakın '
          'nöbetçi eczaneyi görebilmen için konum izni gerekiyor. '
          'Konumun yalnızca uygulamayı kullanırken okunur.',
      ikonlar: [LucideIcons.mapPin, LucideIcons.compass, LucideIcons.store],
      gorsel: _Gorsel.konumHarita,
      izin: _OnboardIzin.konum,
    ),
    // ⚠️⚠️⚠️ TURU 126 — **TAM EKRAN BILDIRIM SAYFASI KALDIRILDI**
    //	(kullanici emri: *"telefon kilitliyken arama yerine ILANLARLA ve
    //	ETKINLIKLER ile ilgili onboarding ekle"*).
    //
    // ⚠️⚠️ **BEKLEYEN IS — GERCEK BEDELI VAR:** o izin, telefon KILITLIYKEN
    //	gelen arama ekraninin acilmasini sagliyordu (turu 89: izin
    //	alinmadiginda ekran HIC ACILMIYORDU). Artik onboardingde
    //	ISTENMIYOR; kalan tek yol **Ayarlar > IZINLER**. Kullanici oraya
    //	gitmezse kilitli telefonda arama ekrani ACILMAZ.
    // ⚠️ YAPMA: bu iki yeni sayfaya izin BAGLAMA — ikisi de TANITIM
    //    sayfasidir, istenecek bir izinleri yok.
    _Sayfa(
      baslik: 'Alım satım',
      vurgu: 'komşunla',
      alt:
          'İkinci el eşyandan iş ilanına kadar her şeyi Gebze’de yayınla; '
          'aradığını mahallendekilerden bul.',
      ikonlar: [LucideIcons.tag, LucideIcons.store, LucideIcons.briefcase],
      gorsel: _Gorsel.ilanKartlari,
    ),
    _Sayfa(
      baslik: 'Şehrinde ne var',
      vurgu: 'kaçırma',
      alt:
          'Konserler, atölyeler, maçlar ve mahalle etkinlikleri tek yerde. '
          'İlgini çekeni takvimine ekle.',
      ikonlar: [
        LucideIcons.calendarDays,
        LucideIcons.ticket,
        LucideIcons.partyPopper,
      ],
      gorsel: _Gorsel.etkinlikKartlari,
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// ⚠️⚠️⚠️ TURU 126 — **TAM EKRAN BILDIRIM + PIL MUAFIYETI BURADA.**
  ///
  ///	Bu iki izin, kaldirilan "Telefon kilitliyken arama ekrani"
  ///	sayfasina bagliydi ve sayfayla birlikte **HIC ISTENMEZ**
  ///	olmustu (denetimde yakalandi). Bedeli somut: tam ekran bildirim
  ///	izni olmadan telefon KILITLIYKEN gelen arama ekrani ACILMAZ
  ///	(turu 89) ve pil muafiyeti olmadan Android sureci dondurur.
  ///
  /// ⚠️⚠️ **AKISIN EN SONUNDA** istenir — turu 56/89 kurali: bu cagri
  ///	sistem AYARLAR ekranini acar ve Activity duraklar; ORTADA
  ///	olsaydi sonraki izin diyalogu HIC GOSTERILMEZDI.
  /// ⚠️ Kendi SAYFASI YOK (kullanici o sayfayi kaldirdi) — kullaniciya
  ///    bir sey ANLATMADIGIMIZ icin ekstra bir vaatte de bulunmuyoruz;
  ///    reddedilirse akis AYNEN devam eder.
  /// ⚠️ `bildirimIste: false`: POST_NOTIFICATIONS teklifler sayfasinda
  ///    ZATEN istendi. Tekrar istemek turu 87 carpismasini uretir
  ///    (READ_PHONE_STATE sessizce `denied`).
  Future<void> _sonIzinler() async {
    try {
      await CallKitService.izinleriIste(bildirimIste: false);
    } catch (_) {}
    if (!Platform.isAndroid) return;
    try {
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}
  }

  Future<void> _bitir() async {
    // ⚠️ Bayrak ONCE yazilir, sonra yonlendirilir: ters sirada olsaydi
    //    yonlendirme sirasinda uygulama oldurulurse onboarding TEKRAR cikardi.
    await tercihler.onboardingGorulduYaz();
    await _sonIzinler();
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
          case _OnboardIzin.konum:
            // ⚠️ TURU 120 —  ile AYNI izin;
            //    iki izin katmani tutmak kacinilmaz olarak DRIFT eder.
            await Permission.locationWhenInUse.request();
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
        // ⚠️ TURU 120 — 260 -> 200 ms (kullanici: *"biraz hizli gecis
        //    yapsin"*). Altina inmek gecisi "atlama" gibi gosteriyor.
        duration: const Duration(milliseconds: 200),
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
                    // ⚠️⚠️ TURU 120 — RADIUS **SIFIR** (emulatorde goruldu).
                    //	Giris ve kayit ekranlarindaki ana dugmeler turu
                    //	119'da duz koseye cevrildi; onboarding ATLANMISTI ve
                    //	ayni akista arka arkaya gelen iki dugme (Devam ->
                    //	Giris yap) FARKLI dilde konusuyordu.
                    //	⚠️ Asimetrinin kendisi hataydi (turu 90b dersi).
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
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
enum _OnboardIzin { bildirim, mikrofon, kamera, konum, tamEkran }

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
          // ⚠️⚠️ TURU 120 — 0.60 -> **0.66** (EMULATORDE OLCULDU).
          //	Kullanicinin olcusu %60 idi ve o oran turu 118'de dogruydu;
          //	ama bu turda kartlar 78 -> 84 dp'ye, telefon %14 buyudu ve
          //	yazi blogu ile alt gostergeler arasinda **ekranin ~%17'si
          //	kadar BOS ALAN** kaldi (1080x2400'de olculdu: yazi 1400 px'de
          //	bitiyor, noktalar 1740 px'de basliyor).
          //	%66 ile bosluk ~%8'e iner ve sayfa "yarim kalmis" gorunmez.
          // ⚠️ `Expanded` ile bosluk PAYLASTIRILAMAZ: govde bir
          //    `SingleChildScrollView` cocugu, yani dikey kisit SINIRSIZ ve
          //    `Expanded` orada **assertion** atar.
          child: _icerik(scheme, kisit.maxHeight * 0.66),
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
    _Gorsel.konumHarita => const _KonumHarita(),
    _Gorsel.aramaTelefon => const _Telefon(tur: _TelefonTuru.arama),
    _Gorsel.ilanKartlari => const _KartAkisi(tur: _AkisTuru.ilan),
    _Gorsel.etkinlikKartlari => const _KartAkisi(tur: _AkisTuru.etkinlik),
  };

  // ⚠️ TURU 89 — `_kart()` (mor gradyanli ikon karti) SILINDI: kullanici
  //    "ikonlari ve arkasindaki kartlari kaldir" dedi. Bayrakla kapatilmadi,
  //    cunku geri istenirse tasarim ZATEN bastan konusulacak.
}

/// Sayfanin ust %60'inda oynayan gorsel.
enum _Gorsel {
  isletmeKartlari,
  aiTelefon,
  mesajKartlari,
  konumHarita,
  aramaTelefon,
  // ⚠️ TURU 126 — iki yeni tanitim sayfasi icin. Mevcut bir gorseli
  //    yeniden kullanmak MUMKUNDU ama YANLIS olurdu: ilan sayfasinin
  //    altinda "Yemek · Kafe · Kuafor" kartlari akiyordu (isletme
  //    kategorileri), etkinlik sayfasi da konum haritasini TEKRARLIYORDU.
  ilanKartlari,
  etkinlikKartlari,
}

enum _AkisTuru { isletme, mesaj, ilan, etkinlik }

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
  // ⚠️ Kartlar OKUNABILECEK kadar yavas aksin: cok hizli akan bir serit
  //    "yukleniyor" gibi degil "bozuk" gibi gorunuyor.
  // ⚠️ TURU 120 — 14 -> **11 sn** (kullanici: *"biraz hizli gecis yapsin"*).
  //    Alt sinir denendi: 8 sn'de alt satirdaki kartin ikinci satiri
  //    okunamiyor.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 11),
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

  /// ⚠️⚠️ **UYDURMA KATEGORI YOK.** Dordu de `demo_ilan.dart`teki gercek
  ///	`tur` degerleri (`vasita` · `emlak` · `is` · `ikinci_el`); son iki
  ///	kart da ilan ekranindaki GERCEK ciplerdir (Favorilerim · İlanlarım).
  static const _ilanlar = <(IconData, String, String)>[
    (LucideIcons.car, 'Vasıta', 'Otomobil · Motosiklet'),
    (LucideIcons.building2, 'Emlak', 'Satılık · Kiralık'),
    (LucideIcons.briefcase, 'İş İlanları', 'Gebze’de iş fırsatları'),
    (LucideIcons.tag, 'İkinci El', 'Eşya · Elektronik'),
    (LucideIcons.heart, 'Favorilerim', 'Kaydettiğin ilanlar'),
    (LucideIcons.store, 'İlanlarım', 'Kendi ilanların'),
  ];

  /// ⚠️⚠️ Altisi da `etkinlik_servisi.dart` -> `etkinlikKategorileri`
  ///	haritasindan; adlar BIREBIR ayni (sunucudaki liste ile hizali).
  static const _etkinlikler = <(IconData, String, String)>[
    (LucideIcons.music, 'Konser', 'Canlı müzik'),
    (LucideIcons.dumbbell, 'Spor', 'Maç · Turnuva'),
    (LucideIcons.graduationCap, 'Eğitim & Atölye', 'Kurs · Workshop'),
    (LucideIcons.palette, 'Sanat & Sergi', 'Sergi · Tiyatro'),
    (LucideIcons.partyPopper, 'Festival', 'Şehir festivalleri'),
    (LucideIcons.users, 'İş & Networking', 'Buluşma · Topluluk'),
  ];

  @override
  Widget build(BuildContext context) {
    final veri = switch (widget.tur) {
      _AkisTuru.isletme => _isletmeler,
      _AkisTuru.mesaj => _mesajlar,
      _AkisTuru.ilan => _ilanlar,
      _AkisTuru.etkinlik => _etkinlikler,
    };
    // ⚠️ TURU 120 — 78 -> 84: ikon karesi 48'e cikinca kartin dikey nefesi
    //    (48 + 2x18) daraliyordu ve yazi kutuya YAPISIK duruyordu.
    const kartBoy = 84.0;
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
          // ⚠️⚠️⚠️ TURU 120 — LISTE **`child:` ILE BIR KEZ** KURULUR
          //	(EMULATORDE OLCULDU: `app_time_stats avg=500 ms`, yani ~2 FPS;
          //	sonunda **ANR** — *"Input dispatching timed out ... waited
          //	5026 ms for KeyEvent"*).
          //
          //	ONCEKI HALI listeyi `builder` GOVDESINDE kuruyordu: 14 kart x
          //	(golge + gradyan + ikon + iki metin) **HER KAREDE** yeniden
          //	insa ediliyordu. Golgeler `saveLayer` acar; 60 fps'te bu tek
          //	basina ana is parcacigini doyuruyor.
          //	`child` parametresi ile agac **BIR KEZ** kurulur ve her karede
          //	yalnizca `Transform.translate` ofseti degisir.
          // ⚠️ YAPMA: karti tekrar `builder` govdesine tasima.
          //
          // ⚠️⚠️ `OverflowBox` ZORUNLU: liste sonsuz dongu icin IKI KEZ
          //	ciziliyor, yani `Column` ust alandan (kutu yuksekligi) DAHA
          //	UZUN. Ebeveyn SINIRLI yukseklik verdigi icin Flutter
          //	"RenderFlex overflowed by 664 pixels" atiyor ve ekrana
          //	SARI-SIYAH serit ciziyordu — oysa tasma KASITLI, zaten
          //	ustteki `ClipRect` kirpiyor.
          // ⚠️ `alignment: topCenter`: liste USTTEN baslasin, yoksa
          //    `Transform` ofseti yanlis referanstan hesaplanir.
          child: OverflowBox(
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
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
          builder: (_, cocuk) => Transform.translate(
            offset: Offset(0, -_c.value * tekBoy),
            child: cocuk,
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 120 — KART **MODERNLESTIRILDI** (kullanici emri: *"kartlar
  ///	olsun daha modern bir hale getir"*).
  ///
  /// Degisenler ve GEREKCELERI:
  ///   · yaricap 18 -> **22**, golge 14/0x0F -> **20/0x14** ve daha asagi
  ///     kayik: kart zeminden AYRILIYOR, "duz liste satiri" gibi durmuyor.
  ///   · ikon karesi 46 -> **48**, yaricap 14 -> **16** (kare/yaricap orani
  ///     kartinkiyle hizali; farkli oranlar goze "hizasiz" geliyordu).
  ///   · chevron artik **DAIRE ICINDE**, soluk lavanta zeminde: tek basina
  ///     duran gri bir ok, kartin sag kenarinda "yarim kalmis" duruyordu.
  ///   · kenarlik 0x14 -> **0x0F**: golge guclendigi icin cerceve
  ///     yumusatildi, aksi halde kart "cift cerceveli" gorunuyordu.
  /// ⚠️ Icerik DEGISMEDI: kartlar hala uygulamanin GERCEK kategorileri.
  ///    Sahte isletme adi/puan/mesafe EKLENMEDI (proje kurali).
  Widget _kart(IconData ikon, String ad, String alt, double boy) => Container(
    height: boy,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x0F000000)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B3FFF), Color(0xFF6C2BD9)],
            ),
            borderRadius: BorderRadius.circular(16),
            // ⚠️ Ikon karesinin KENDI golgesi: kartin uzerinde "duruyor"
            //    hissi verir; duz bir kare yapistirilmis gibi gorunuyordu.
            boxShadow: const [
              BoxShadow(
                color: Color(0x386C2BD9),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
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
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF3EFFC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: Color(0xFF6C2BD9),
          ),
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
  // ⚠️ TURU 120 — 7 -> **5 sn** (kullanici: *"biraz hizli gecis yapsin"*).
  //    Sahne artik IKI soru-cevap tasiyor; 7 sn'de tekrar beklemek uzun
  //    geliyordu, 4 sn'nin altinda yanit metni OKUNMADAN kayboluyor.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
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
  /// ⚠️⚠️⚠️ TURU 120 — TELEFON **BUYUTULDU** (kullanici emri: *"AI sohbet
  ///	cektigini DAHA BUYUT"*).
  ///
  /// ═══════════ NEDEN `FractionallySizedBox(0.94)` YETMEDI ═══════════
  /// Cerceve, ust alanin YUKSEKLIGINE gore olculuyordu ve 9:19.5 oran
  /// zorunlulugu yuzunden GENISLIGI cok dar kaliyordu (360 dp'lik bir
  /// telefonda ~190 dp). Yani ekranin buyuk kismi BOSTU ama mockup kucuk
  /// duruyordu.
  ///
  /// ═══════════ YENI OLCUM ═══════════
  ///   1. once alanin **%114'u** kadar yukseklik denenir (bilincli tasma:
  ///      cihazin alt kismi metnin arkasina girer — "cepten cikan telefon"
  ///      gorunumu, modern onboardinglerin standart dili),
  ///   2. genislik alanin **%60'ini** gecemez (dar ekranda cerceve yanlardan
  ///      tasip kirpilmasin),
  ///   3. tasma tavani alanin **%120'si** (kucuk/kisa ekranlarda cihazin
  ///      yarisi kesilmesin).
  /// ⚠️ `ClipRect` + `OverflowBox` ZORUNLU: kutu SINIRLI yukseklik veriyor,
  ///    tasan cocuk `RenderFlex overflowed` sari-siyah seridi cizdirirdi
  ///    (turu 118'de `_KartAkisi`nda birebir bu yasandi). Tasma KASITLI.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, kisit) {
      var boy = kisit.maxHeight * 1.14;
      var en = boy * 9 / 19.5;
      // ⚠️ TURU 126 — telefon once %20 daraltildi (0.60 -> 0.48), sonra
      //    kullanici *"%15 genislet"* dedi: 0.48 x 1.15 = **0.552**.
      //    Oran (9:19.5) hicbir adimda DEGISMEDI, yalniz tavan oynadi.
      final enTavan = kisit.maxWidth * 0.552;
      if (en > enTavan) {
        en = enTavan;
        boy = en * 19.5 / 9;
      }
      final boyTavan = kisit.maxHeight * 1.20;
      if (boy > boyTavan) {
        boy = boyTavan;
        en = boy * 9 / 19.5;
      }
      // ⚠️⚠️ TURU 120 — CERCEVE **ANIMASYONUN DISINDA** kurulur (performans;
      //	`_KartAkisi`daki ANR ile ayni sinif). Cerceve dekorasyonu, golgesi
      //	ve dynamic island'i her karede yeniden insa etmek gereksizdi;
      //	degisen TEK sey sohbet icerigi ve o da `_cerceve()` icinde kendi
      //	`AnimatedBuilder`ina alindi.
      // ⚠️⚠️⚠️ TURU 126 — **`minWidth: 0` ZORUNLU (emulatorde olculdu).**
      //
      //	Ebeveyn `SizedBox(width: double.infinity)` genislikte **TIGHT**
      //	kisit verir. `OverflowBox` `minWidth`/`maxWidth` verilmediginde
      //	o kisiti OLDUGU GIBI asagi gecirir, yani icteki
      //	`SizedBox(width: en)` **YOK SAYILIR** ve cerceve DAIMA tam
      //	genislikte cizilir. Hesaplanan `en` yalnizca `boy`u besliyordu.
      //	Sonuc: "telefonu %20 daralt" emri UYGULANSA DA ekranda hicbir sey
      //	degismiyordu — 0.60 -> 0.48 degisikligi OLU KODDU.
      // ⚠️ `minWidth: 0` kisiti GEVSETIR; `alignment: topCenter` ortalar.
      // ⚠️ YAPMA: `minWidth`i kaldirma.
      return ClipRect(
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: SizedBox(width: en, height: boy, child: _cerceve()),
        ),
      );
    },
  );

  Widget _cerceve() => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xFF14101C),
      borderRadius: BorderRadius.circular(38),
      // ⚠️ TURU 126 — GOLGE KALDIRILDI (kullanici emri: *"oradaki
      //    balonlarin golgesini kaldir"*). Cerceve golgesi de ayni
      //    dildeydi; biri kalsa oteki tek basina yamali gorunurdu.
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
            // ⚠️ Yalnizca SAHNE animasyona bagli: cerceve/island yukarida
            //    BIR KEZ kuruldu (bkz. `build` serhi).
            Expanded(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => widget.tur == _TelefonTuru.ai
                    ? _aiSahnesi()
                    : _aramaSahnesi(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ═══════════ AI SOHBETI ═══════════
  /// ⚠️⚠️ TURU 120 — SAHNE **IKI SORU-CEVABA** cikarildi (kullanici emri:
  ///	*"yazi balonlarini daha DINAMIK yap, biraz hizli gecis yapsin"*).
  ///
  /// Tek soru-cevap 7 saniyeye yayilinca sahnenin yarisi HAREKETSIZ geciyor
  /// ve mockup "donmus" gorunuyordu. Simdi sure 5 sn ve icinde IKI tur var:
  ///
  ///	soru1 -> yaziyor -> yanit1 -> soru2 -> yaziyor -> yanit2 -> kisa bekle
  ///
  /// ⚠️ "Yaziyor" balonu YANIT GELINCE kaybolur (`* (1 - _oran(...))`):
  ///    ikisi ayni anda gorunse sohbet "iki cevap veriyor" gibi olurdu.
  /// ⚠️ Metinler KISA: uzun metin cerceveyi tasirir ve mockup bozuk gorunur.
  /// ⚠️ Sorular UYGULAMANIN GERCEK islerine dair (mekan onerisi, nobetci
  ///    eczane) — uydurma bir yetenek vaat edilmiyor.
  Widget _aiSahnesi() {
    final soru1 = _oran(0.04, 0.12);
    final yaziyor1 = _oran(0.15, 0.20) * (1 - _oran(0.26, 0.30));
    final yanit1 = _oran(0.30, 0.40);
    final soru2 = _oran(0.50, 0.58);
    final yaziyor2 = _oran(0.61, 0.66) * (1 - _oran(0.70, 0.74));
    final yanit2 = _oran(0.74, 0.84);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ TURU 126 — **"GebzemAI" YAZISI KALDIRILDI** (kullanici
          //    emri). Ikon KALDI: yazi olmadan da sohbetin karsi tarafinin
          //    kim oldugunu tek basina o soyluyor.
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B3FFF), Color(0xFF6C2BD9)],
              ),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _balon(
            metin: 'Gebze’de hafta sonu\nne yapılır?',
            benim: true,
            gorunur: soru1,
          ),
          const SizedBox(height: 8),
          if (yaziyor1 > 0.02 && yanit1 < 0.02)
            Opacity(opacity: yaziyor1.clamp(0, 1), child: _yaziyorBalonu()),
          if (yanit1 > 0.02)
            _balon(
              metin: 'Eskihisar’da sahil yürüyüşü,\nakşam merkezde kahve.',
              benim: false,
              gorunur: yanit1,
            ),
          if (soru2 > 0.02) ...[
            const SizedBox(height: 8),
            _balon(metin: 'Nöbetçi eczane?', benim: true, gorunur: soru2),
          ],
          const SizedBox(height: 8),
          if (yaziyor2 > 0.02 && yanit2 < 0.02)
            Opacity(opacity: yaziyor2.clamp(0, 1), child: _yaziyorBalonu()),
          if (yanit2 > 0.02)
            _balon(
              metin: 'En yakını 1,2 km —\nharitada göstereyim mi?',
              benim: false,
              gorunur: yanit2,
            ),
        ],
      ),
    );
  }

  /// ⚠️ Balon ASAGIDAN yukari kayarak + **HAFIF BUYUYEREK** gelir: aninda
  ///    beliren bir balon "hata" gibi gorunuyordu.
  /// ⚠️⚠️ TURU 120 — `easeOutBack` (kucuk bir tasma/geri yaylanma) eklendi:
  ///	kullanici *"balonlari daha DINAMIK yap"* dedi. `easeOutCubic` duz ve
  ///	"kurumsal" duruyordu.
  ///	⚠️ Olcek 0.92'den baslar, 1.0'i **hafifce asar** (easeOutBack) ve
  ///	   oturur. Daha buyuk bir tasma balonu "ziplatiyor" ve ucuz
  ///	   gosteriyordu.
  /// ⚠️ `Opacity` icin AYRI egri (`easeOut`) kullanilir: `easeOutBack` 1'i
  ///    astigi icin opaklik 1'in uzerine cikar ve **assertion** atardi.
  Widget _balon({
    required String metin,
    required bool benim,
    required double gorunur,
  }) {
    final t = gorunur.clamp(0.0, 1.0);
    final hareket = Curves.easeOutBack.transform(t);
    final solma = Curves.easeOut.transform(t);
    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(0, (1 - hareket) * 16),
        child: Transform.scale(
          scale: 0.92 + 0.08 * hareket,
          alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: solma,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 168),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: benim ? const Color(0xFF6C2BD9) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: Radius.circular(benim ? 15 : 4),
                  bottomRight: Radius.circular(benim ? 4 : 15),
                ),
                border: benim
                    ? null
                    : Border.all(color: const Color(0x14000000)),
                // ⚠️ TURU 126 — **BALON GOLGESI KALDIRILDI** (kullanici
                //    emri). Kenarlik DURUYOR: beyaz balonun beyaz zeminden
                //    ayrilmasini golge DEGIL o cizgi sagliyordu.
              ),
              child: Text(
                metin,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: benim ? Colors.white : _kOnboardYazi,
                ),
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

/// ⚠️⚠️⚠️ TURU 120 — **KONUM / YAKINIMDA SAHNESI** (kullanici emri: *"konumla
///	ilgili, YAKINIMDA ile ilgili onboardinge ekle"*).
///
/// Stilize bir harita: ortada nabiz atan konum halkasi, cevresinde SIRAYLA
/// dusen kategori pinleri ve altta yukari kayan "Yakınımda" karti.
///
/// ⚠️⚠️ **GERCEK HARITA CIZILMEZ.** `google_maps_flutter` burada kullanilsaydi:
///	  · onboarding, izin HENUZ ISTENMEDEN once konum servisine dokunurdu,
///	  · harita SDK'si acilista agirlik yapardi (kullanicinin gordugu ilk
///	    ekran),
///	  · anahtarsiz derlemede (`HARITA` bayragi kapali) BOS GRI KUTU cikardi
///	    — turu 87'de tam bu yasandi.
///	Bu bir TANITIM gorseli; harita gibi gorunmesi yeterli, harita OLMASI
///	gerekmiyor.
///
/// ⚠️⚠️ **UYDURMA VERI YOK:** pinlerde isletme adi, puan ya da mesafe YAZMAZ.
///	Yalnizca uygulamanin GERCEK kategori ikonlari (Yemek · Eczane · Kafe)
///	gosterilir. Sahte bir "4,8 puan · 350 m" yazmak, kullaniciya urunun
///	yapmadigi bir seyi vaat etmek olurdu (proje kurali).
class _KonumHarita extends StatefulWidget {
  const _KonumHarita();

  @override
  State<_KonumHarita> createState() => _KonumHaritaState();
}

class _KonumHaritaState extends State<_KonumHarita>
    with SingleTickerProviderStateMixin {
  // ⚠️ 6 sn: pinlerin sirayla dusmesi + kartin gelmesi + kisa bir bekleme.
  //    Daha kisasi pinleri "firlatiyor" gibi gosteriyordu.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _oran(double bas, double son) {
    final t = _c.value;
    if (t <= bas) return 0;
    if (t >= son) return 1;
    return (t - bas) / (son - bas);
  }

  /// Pin konumlari — kutunun ORANI olarak (sabit dp DEGIL): kutu her cihazda
  /// farkli boyda ve sabit ofsetler kucuk ekranda kenardan tasardi.
  static const _pinler = <(double, double, IconData, String)>[
    (0.24, 0.30, LucideIcons.utensils, 'Yemek'),
    (0.76, 0.24, LucideIcons.pill, 'Eczane'),
    (0.70, 0.62, LucideIcons.coffee, 'Kafe'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, kisit) {
      final en = kisit.maxWidth;
      final boy = kisit.maxHeight;
      return Stack(
        children: [
          // ⚠️⚠️ TURU 120 — ZEMIN **ANIMASYONUN DISINDA**: yol agi hic
          //	degismiyor, her karede yeniden cizmek gereksiz is
          //	(`_KartAkisi`daki ANR ile ayni sinif).
          const Positioned.fill(child: CustomPaint(painter: _HaritaZemini())),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                // Nabiz 0..1 arasi gidip gelir (iki tam dongu / tur).
                final nabiz = 0.5 + 0.5 * math.sin(_c.value * math.pi * 4);
                return Stack(
                  children: [
                    // ── PINLER ──
                    for (var i = 0; i < _pinler.length; i++) _pin(i, en, boy),
                    // ── KONUMUM: nabiz halkasi + nokta ──
                    Positioned(
                      left: en * 0.46 - 60,
                      top: boy * 0.46 - 60,
                      width: 120,
                      height: 120,
                      child: IgnorePointer(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // ⚠️ Halka BUYURKEN SOLAR: sabit opaklikta buyuyen bir
                            //    daire "yukleniyor" degil "hata" gibi duruyordu.
                            Container(
                              width: 44 + 62 * nabiz,
                              height: 44 + 62 * nabiz,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: morLogo.withValues(
                                  alpha: 0.10 * (1 - nabiz),
                                ),
                                border: Border.all(
                                  color: morLogo.withValues(
                                    alpha: 0.35 * (1 - nabiz),
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: morLogo,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x556C2BD9),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── ALTTA "Yakınımda" KARTI ──
                    _altKart(),
                  ],
                );
              },
            ),
          ),
        ],
      );
    },
  );

  /// ⚠️ Pinler SIRAYLA duser (`i * 0.06` gecikme): hepsi ayni anda belirseydi
  ///    hareket "yanip sonme" gibi gorunurdu.
  /// ⚠️ `easeOutBack` — pin yere degip hafifce yaylanir; duz bir egri
  ///    "yapistirilmis" duruyordu.
  Widget _pin(int i, double en, double boy) {
    final (x, y, ikon, ad) = _pinler[i];
    final bas = 0.10 + i * 0.06;
    final t = _oran(bas, bas + 0.14);
    if (t <= 0) return const SizedBox.shrink();
    final h = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    return Positioned(
      left: en * x - 44,
      top: boy * y - 30,
      width: 88,
      child: Opacity(
        opacity: Curves.easeOut.transform(t.clamp(0.0, 1.0)),
        child: Transform.translate(
          offset: Offset(0, (1 - h) * -26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x0F000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ikon, size: 14, color: morLogo),
                    const SizedBox(width: 6),
                    Text(
                      ad,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kOnboardYazi,
                      ),
                    ),
                  ],
                ),
              ),
              // Pin ucu — kartin haritadaki NOKTAYA baglandigini gosterir.
              Container(width: 2, height: 12, color: const Color(0x33000000)),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x66000000),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _altKart() {
    final t = _oran(0.40, 0.54);
    if (t <= 0) return const SizedBox.shrink();
    final h = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    return Positioned(
      left: 28,
      right: 28,
      bottom: 6,
      child: Opacity(
        opacity: h,
        child: Transform.translate(
          offset: Offset(0, (1 - h) * 30),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x0F000000)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B3FFF), Color(0xFF6C2BD9)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    LucideIcons.mapPin,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Yakınımda',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kOnboardYazi,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Çevrendeki işletmeler',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _kOnboardAltYazi,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3EFFC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Color(0xFF6C2BD9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stilize harita zemini: yumusak zemin + birkac "yol" seridi.
///
/// ⚠️ Gercek bir harita karosu DEGIL (bkz. `_KonumHarita` serhi). Amac,
///    pinlerin bosluga degil bir ZEMINE oturdugu hissini vermek.
/// ⚠️ `shouldRepaint` false: cizer durumsuz. Ust katmandaki nabiz zaten
///    `AnimatedBuilder` icinde yeniden cizilir.
class _HaritaZemini extends CustomPainter {
  const _HaritaZemini();

  @override
  void paint(Canvas canvas, Size size) {
    final cerceve = RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 8, size.width - 32, size.height - 16),
      const Radius.circular(26),
    );
    canvas.drawRRect(cerceve, Paint()..color = const Color(0xFFF6F4FB));
    canvas.save();
    canvas.clipRRect(cerceve);
    final yol = Paint()
      ..color = const Color(0xFFE7E2F4)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    // Capraz ve dikey birkac serit — sehir izlenimi icin yeterli.
    canvas.drawLine(
      Offset(-20, size.height * 0.30),
      Offset(size.width + 20, size.height * 0.22),
      yol,
    );
    canvas.drawLine(
      Offset(-20, size.height * 0.72),
      Offset(size.width + 20, size.height * 0.80),
      yol,
    );
    canvas.drawLine(
      Offset(size.width * 0.34, -20),
      Offset(size.width * 0.22, size.height + 20),
      yol,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, -20),
      Offset(size.width * 0.92, size.height + 20),
      yol,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
