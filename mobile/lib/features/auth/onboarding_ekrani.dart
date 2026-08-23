import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (durum cubugu)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/tercihler.dart';
import '../calls/callkit_service.dart';
import 'permissions_screen.dart' show izinSorulduIsaretle;

/// ⚠️⚠️⚠️ TURU 127 — **ONBOARDING BASTAN YAZILDI (KULLANICI EMRI).**
///
/// Kullanici: *"onboardingin hepsini kaldir, izinleri kaldirma — izinler
/// kalsin sadece gorunmesin, hiz icin. Sor Gebzem cevaplasin ekranindaki
/// gibi olsun: telefon ALTA sifir, ustte yazi, gecis slideri kaldir,
/// Devam kaldir, Atla kaldir. Sol/sag Instagram gibi tiklayinca gecsin,
/// gecmezse 5 saniye sonra kendi otomatik gecsin. 6 tane olsun, hepsinde
/// farkli yazsin. Telefon icinde bir sey olmasin."*
///
/// ═══════════ ONCEKI HALDEN FARKI ═══════════
///   · **IZIN SAYFALARI YOK.** Izinler DURUYOR ama artik akisin SONUNDA,
///     tek seferde isteniyor (bkz. `_izinleriIste`). Kullanici sayfalari
///     gormuyor, izinler kaybolmuyor.
///   · Nokta gostergesi · "Devam" · "Atla" **KALDIRILDI**.
///   · Her sayfada UST YAZI + KALIN BASLIK; altta **ekranin dibine yapisik**
///     bos telefon cercevesi.
///   · Gecis: sol yariya dokun -> geri, sag yariya dokun -> ileri; hicbir
///     dokunus gelmezse **5 sn** sonra kendiliginden ilerler.
///   · Kod ile cizilen kart akislari / harita / AI sahnesi **SILINDI**:
///     telefon artik BOS, dolayisiyla o ~1300 satirin karsiligi kalmadi.
///
/// ⚠️⚠️ **IZINLER NEDEN AKIS SONUNDA VE SIRAYLA?** Android ayni anda TEK
///	izin kumesi kabul eder; ust uste istenirse ikincisi SESSIZCE `denied`
///	doner (turu 87'de olculdu: READ_PHONE_STATE 36 tur boyunca hic
///	alinamadi). Bu yuzden her istek `await` ile SIRAYLA yapilir.
/// ⚠️⚠️ **TAM EKRAN BILDIRIM + PIL EN SONDA:** bu cagri sistem AYARLAR
///	ekranini acar ve Activity DURAKLAR; ortada olsaydi sonraki diyalog
///	HIC GOSTERILMEZDI (turu 56/89).
/// ⚠️ Izin REDDEDILSE BILE akis devam eder — zorlamak App Store
///    incelemesinde kotu karsilanir ve kullaniciyi ilk ekranda kaybettirir.
///    Reddeden kullanici Ayarlar > Izinler'den verebilir.
///
/// ⚠️ EMOJI YOK — kullanici emri (turu 62).
/// ⚠️⚠️ "GORULDU" BAYRAGI **CIKISTA** yazilir, son sayfada degil: kullanici
///	akisi yarida birakirsa da bir daha gormemeli.
class OnboardingEkrani extends ConsumerStatefulWidget {
  const OnboardingEkrani({super.key, required this.onBitti});

  /// ⚠️ Yonlendirmeyi EKRAN YAPMAZ, cagiran yapar (router tek kaynak).
  final VoidCallback onBitti;

  @override
  ConsumerState<OnboardingEkrani> createState() => _OnboardingEkraniState();
}

/// Bir onboarding sayfasi: ust satir + kalin baslik.
///
/// ⚠️ Ikon/gorsel/izin ALANI YOK. Telefon cercevesi TUM sayfalarda ayni ve
///    BOS; sayfayi ayiran tek sey METINDIR.
class _Sayfa {
  const _Sayfa(this.ust, this.baslik);

  /// Ince ust satir — baglami verir.
  final String ust;

  /// Kalin ana satir. ⚠️ KISA tutulur: uzun baslik telefon cercevesini
  ///    asagi iter ve "alta sifir" duzeni bozulur.
  final String baslik;
}

/// ⚠️ ALTI SAYFA (kullanici emri). Her biri uygulamanin GERCEK bir islevini
///    anlatir — uydurma ozellik vaat edilmiyor.
/// ⚠️ Sira BILINCLI: once herkesin bildigi (mesaj/arama), sonra Gebzem'i
///    FARKLI kilanlar, en sonda AI.
const _sayfalar = <_Sayfa>[
  _Sayfa('Mesaj, sesli ve görüntülü arama', 'Gebze tek uygulamada'),
  _Sayfa('Çevrendeki işletmeler, nöbetçi eczane', 'Yakınında ne varsa'),
  _Sayfa('İkinci el, emlak, iş ilanı', 'Alım satım komşunla'),
  _Sayfa('Konser, atölye, maç, festival', 'Şehrinde ne var kaçırma'),
  _Sayfa('Randevu al, teklif topla', 'İşini buradan hallet'),
  _Sayfa('Aklına ne takılırsa', 'Sor, Gebzem cevaplasın'),
];

/// ⚠️ Otomatik gecis suresi — kullanici emri: *"gecmezse 5 saniye sonra
///    kendi otomatik gecsin"*.
const Duration _kOtoGecis = Duration(seconds: 5);

const Color _kOnboardZemin = Color(0xFFFFFFFF);
const Color _kOnboardYazi = Color(0xFF14141A);
const Color _kOnboardAltYazi = Color(0xFF6B6B76);
const Color _kCerceve = Color(0xFF14101C);
const Color _kEkran = Color(0xFFF7F6FB);

class _OnboardingEkraniState extends ConsumerState<OnboardingEkrani> {
  final _ctrl = PageController();
  int _sayfa = 0;
  Timer? _sayac;

  /// Cikis TEK KAPIDAN gecer; iki kez calismasin.
  bool _bitiyor = false;

  @override
  void initState() {
    super.initState();
    _sayaciKur();
  }

  @override
  void dispose() {
    _sayac?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// ⚠️ Her sayfa degisiminde YENIDEN kurulur: kullanici elle gecerse sayac
  ///    SIFIRDAN baslar, yoksa yeni sayfa yarim surede kayardi.
  void _sayaciKur() {
    _sayac?.cancel();
    _sayac = Timer(_kOtoGecis, _ileri);
  }

  void _ileri() {
    if (_bitiyor) return;
    if (_sayfa >= _sayfalar.length - 1) {
      _bitir();
      return;
    }
    _ctrl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _geri() {
    if (_bitiyor || _sayfa == 0) return;
    _ctrl.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// ⚠️⚠️ IZINLER **AKISIN SONUNDA, SIRAYLA** istenir (bkz. sinif serhi).
  ///	Her adim KENDI `try` blogunda: biri firlarsa sonrakiler ETKILENMEZ.
  Future<void> _izinleriIste() async {
    try {
      await Permission.microphone.request();
    } catch (_) {}
    try {
      await Permission.camera.request();
    } catch (_) {}
    try {
      await Permission.notification.request();
    } catch (_) {}
    try {
      // ⚠️ `locationWhenInUse`: uygulama kullanilirken. Arka plan konumu
      //    ISTENMEZ — magaza incelemesinde gerekce sorulur ve boyle bir
      //    ozelligimiz YOK.
      await Permission.locationWhenInUse.request();
    } catch (_) {}
    // ⚠️⚠️ EN SON: bu cagri sistem AYARLAR ekranini acar ve Activity duraklar.
    try {
      // ⚠️ `bildirimIste: false` — POST_NOTIFICATIONS yukarida ZATEN istendi.
      //    Tekrar istemek turu 87 carpismasini uretir.
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
    if (_bitiyor) return;
    _bitiyor = true;
    _sayac?.cancel();
    // ⚠️ Bayrak ONCE yazilir: ters sirada olsaydi yonlendirme sirasinda
    //    uygulama oldurulurse onboarding TEKRAR cikardi.
    await tercihler.onboardingGorulduYaz();
    await izinSorulduIsaretle();
    // ⚠️⚠️ IZINLER **YONLENDIRMEDEN ONCE**: sonra istenseydi diyaloglar giris
    //	ekraninin uzerine biner ve kullanici ne oldugunu anlamaz.
    await _izinleriIste();
    if (mounted) widget.onBitti();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ TURU 85b — beyaz zeminde durum cubugu ikonlari KOYU olmali.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kCerceve,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kOnboardZemin,
        // ⚠️⚠️ `SafeArea` **ALTTA KAPALI**: telefon cercevesi ekranin dibine
        //	SIFIR yapisik olmali (kullanici emri: *"telefon alta sifir"*).
        //	Acik birakilsaydi jest cubugu kadar bosluk kalirdi.
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: _sayfalar.length,
                onPageChanged: (i) {
                  setState(() => _sayfa = i);
                  _sayaciKur();
                },
                itemBuilder: (_, i) => _SayfaGorunumu(s: _sayfalar[i]),
              ),
              // ⚠️⚠️ **INSTAGRAM HIKAYE DESENI** (kullanici emri): sol yari
              //	geri, sag yari ileri. Dokunus jesti kaydirmayi YUTMAZ —
              //	parmagini surukleyen kullanici PageView'i normal sekilde
              //	kaydirmaya devam eder.
              // ⚠️ `HitTestBehavior.opaque` ZORUNLU: seffaf alan dokunus
              //    ALMAZ ve tiklama PageView'a duserdi.
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _geri,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _ileri,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TEK SAYFA: ustte metin, altta ekranin dibine yapisik BOS telefon.
class _SayfaGorunumu extends StatelessWidget {
  const _SayfaGorunumu({required this.s});

  final _Sayfa s;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, kisit) {
        // ⚠️⚠️ **GENISLIK BIRINCIL OLCU** (turu 126 dersi): genisligi
        //	yukseklikten turetmek, tavan baglayici olmaktan cikinca sayiyi
        //	degistirmeyi ETKISIZ birakiyordu.
        // ⚠️ 0.78: metin blogu ustte durdugu icin cerceve genis olabilir;
        //    dar ekranda bile yanlarda nefes kalir.
        final en = kisit.maxWidth * 0.78;
        final boy = en * 19.5 / 9;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.ust,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      color: _kOnboardAltYazi,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ⚠️ Kalin satir **32 px** (kullanici: *"alttaki kalin yazi
                  //    biraz daha fazla"*). Daha buyugu iki satiri asiyor ve
                  //    cerceveyi asagi itiyor.
                  Text(
                    s.baslik,
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: _kOnboardYazi,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // ⚠️⚠️ `Expanded` + `bottomCenter`: cerceve KALAN alanin DIBINE
            //	oturur. `ClipRect` + `OverflowBox` ile alttan tasar — "cepten
            //	cikan telefon" dili ve tasma KASITLI.
            // ⚠️ `minWidth: 0` ZORUNLU (turu 126'da olculdu): ebeveyn
            //    genislikte TIGHT kisit verir; `OverflowBox` onu oldugu gibi
            //    gecirirse `SizedBox(width: en)` YOK SAYILIR.
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: en,
                    height: boy,
                    child: const _BosTelefon(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ⚠️ TURU 127 — **ICI BOS TELEFON** (kullanici emri: *"telefon icinde bir
///    sey olmasin"*). Sahne/animasyon YOK; her karede yeniden cizilen bir
///    agac kalmadigi icin onboarding artik fiilen bedelsiz.
/// ⚠️ Alt koseler yuvarlak KALIR ama ekranin dibinde kaldiklari icin
///    gorunmezler; yaricapi kaldirmak UST koseleri de bozardi.
class _BosTelefon extends StatelessWidget {
  const _BosTelefon();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: _kCerceve,
      borderRadius: BorderRadius.circular(38),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(31),
      child: ColoredBox(
        color: _kEkran,
        child: Column(
          children: [
            // ── DYNAMIC ISLAND ──
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Container(
                width: 62,
                height: 17,
                decoration: BoxDecoration(
                  color: _kCerceve,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
