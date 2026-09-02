import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (durum cubugu)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/tercihler.dart';
import '../calls/callkit_service.dart';
import 'permissions_screen.dart' show izinSorulduIsaretle;
import '../medya/konum_servisi.dart';

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

  /// ⚠️⚠️ **PARMAKLA KAYDIRMA** (denetim widget testiyle olctu: ortu
  ///	`PageView`i hit-test'ten DUSURUYOR, kaydirma TAMAMEN oluydu).
  ///	Surukleme dogrudan `PageController`a devrediliyor.
  /// ⚠️ Isaret TERS: parmagi SOLA suruklemek sonraki sayfaya gecer,
  ///    yani ofset ARTAR.
  /// ⚠️ `hasClients` kapisi: ilk karede controller henuz bir viewport'a
  ///    bagli olmayabilir ve `position` okumak PATLAR.
  void _suruklendi(DragUpdateDetails d) {
    if (_bitiyor || !_ctrl.hasClients) return;
    _ctrl.jumpTo(_ctrl.position.pixels - d.delta.dx);
  }

  /// ⚠️ Birakinca EN YAKIN sayfaya yaslanir; hizli bir fling ise yonune
  ///    gore komsu sayfaya gecer (esik 300 px/sn).
  /// ⚠️ Yaslanma sonrasi sayaci `onPageChanged` yeniden kurar; burada
  ///    elle kurmak IKI zamanlayici uretirdi.
  void _suruklemeBitti(DragEndDetails d) {
    if (_bitiyor || !_ctrl.hasClients) return;
    final hiz = d.velocity.pixelsPerSecond.dx;
    final simdi = _ctrl.page ?? _sayfa.toDouble();
    var hedef = simdi.round();
    if (hiz < -300) {
      hedef = simdi.floor() + 1;
    } else if (hiz > 300) {
      hedef = simdi.ceil() - 1;
    }
    hedef = hedef.clamp(0, _sayfalar.length - 1);
    _ctrl.animateToPage(
      hedef,
      duration: const Duration(milliseconds: 240),
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
      // ⚠️⚠️⚠️ TURU 159 - **TEK KAPIDAN** (`KonumServisi.konumIzni`).
      //	Burasi dogrudan `request()` cagiriyordu ve `konum_servisi`
      //	icindeki serh bunu ACIKCA yasakliyordu. Sonuc: onboardingde
      //	"Bir Kez Izin Ver" secen kullaniciya harita acilir acilmaz
      //	IKINCI bir diyalog cikiyordu (kullanici sahada gordu).
      await KonumServisi.konumIzni();
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
        // ⚠️⚠️ TURU 127 — **JEST CUBUGU GORUNMEZ** (kullanici emri:
        //	*"telefonun altinda celtik cizgisi var, onu kaldir"*).
        //	Cubuk KALDIRILAMAZ (sistem cizer) ama telefon cercevesiyle
        //	AYNI RENGE burunur: koyu zemin + koyu cubuk = gorunmez.
        // ⚠️ `systemNavigationBarContrastEnforced: false` ZORUNLU:
        //    Android 10+ aksi halde cubugun arkasina YARI SAYDAM bir
        //    katman koyar ve cizgi yine belli olur.
        // ⚠️⚠️⚠️ **IKONLAR ACIK OLMAK ZORUNDA** (denetim buldu).
        //	`Brightness.dark` = KOYU ikon; zemin de koyu (`_kCerceve`)
        //	oldugu icin **3 TUSLU GEZINME** kullanan cihazlarda
        //	Geri/Ana ekran/Son uygulamalar tuslari GORUNMEZ oluyordu
        //	ve kullanici 30 saniye boyunca korlemesine basmak zorunda
        //	kaliyordu.
        //	Jest cubugu (2 tuslu/jest) yine gorunmez: o INCE BIR CIZGI
        //	ve `light` ikon parlakligi onu etkilemez — kullanicinin
        //	istegi korunur, tuslar da kaybolmaz.
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
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
              // ⚠️⚠️⚠️ **KAYDIRMA DA CALISMAK ZORUNDA** (denetim widget
              //	testiyle olctu: ortu VARKEN fling sonrasi sayfa = 0,
              //	ortu YOKKEN = 1). Tam ekran opaque bir
              //	`GestureDetector` `PageView`i hit-test`ten DUSURUYOR;
              //	ustelik parmak dokunma esigini asinca `onTap` da
              //	geri cekiliyordu — yani kullanici ne kaydirabiliyor ne
              //	dokunusla ilerleyebiliyor, 5 saniyelik otomatik gecisi
              //	BEKLEMEK zorunda kaliyordu (6 sayfa = 30 sn).
              //
              // ⚠️ COZUM: yatay surukleme ortuye de baglandi ve DOGRUDAN
              //    `PageController`a devrediliyor. Iki jest ayni
              //    `GestureDetector`da oldugu icin arena onlari birbirine
              //    karsi degil, DOGAL olarak ayirir (dokunus = tap,
              //    surukleme = drag).
              // ⚠️ YAPMA: `onTap`i kaldirip yalniz kaydirma birakma
              //    (kullanici ACIKCA "sol sag Instagram gibi tiklayinca
              //    gecsin" dedi).
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _geri,
                        onHorizontalDragUpdate: _suruklendi,
                        onHorizontalDragEnd: _suruklemeBitti,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _ileri,
                        onHorizontalDragUpdate: _suruklendi,
                        onHorizontalDragEnd: _suruklemeBitti,
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
        // ⚠️⚠️ TURU 127 — **METIN BLOGU SABIT YUKSEKLIK** (kullanici emri:
        //	*"hepsinde ayni esitlikte olsun, hepsi ayni hizada"*).
        //
        //	Basliklar farkli uzunlukta: "Yakınında ne varsa" TEK satir,
        //	"Şehrinde ne var kaçırma" IKI satir. Blok icerikten
        //	buyudugu icin telefon her sayfada BASKA bir yukseklikte
        //	basliyordu ve sayfalar arasi gecis ZIPLIYORDU.
        //	Artik blok DAIMA iki satirlik yer kaplar; tek satirlik
        //	sayfada altta bosluk kalir ve telefon YERINDEN OYNAMAZ.
        // ⚠️ Yukseklik yazi olceginden TURETILIR, sabit dp DEGIL:
        //    olcek 1.3/2.0 da sabit sayi tasardi.
        // ⚠️⚠️⚠️ **SABIT YUKSEKLIK TASIYORDU** (denetim gercek Google Sans
        //	fontuyla `TextPainter` ile olctu): formul basligin IKI SATIR
        //	oldugunu VARSAYIYOR, ama 360 dp genislikte bazi basliklar UC
        //	satira sariyor. Olcek 1.15`te 24.5 dp, olcek 2.0`da ALTI
        //	sayfanin ALTISI birden 86-148 dp TASIYOR ve basligin son
        //	satiri telefon cercevesinin ARKASINDA kaliyordu.
        //
        // ⚠️ COZUM: yukseklik artik bir **TABAN** (`minHeight`), TAVAN
        //    DEGIL. Hizalama korunur (tek satirlik sayfalarda blok yine
        //    iki satirlik yer kaplar, telefon YERINDEN OYNAMAZ) ama
        //    uzun baslik gerektiginde blok BUYUR ve KIRPILMAZ.
        // ⚠️ YAPMA: `SizedBox(height:)`e geri donme.
        final olcek = MediaQuery.textScalerOf(context);
        final ustBoy = olcek.scale(16) * 1.35 + 6 + olcek.scale(32) * 1.15 * 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: ustBoy,
                  minWidth: double.infinity,
                ),
                child: Column(
                  // ⚠️⚠️ TURU 127 — **ICERIK BLOGUN ALTINA HIZALI.**
                  //	Blok iki satirlik SABIT yer kapliyor (hizalama icin);
                  //	ust hizali olsaydi TEK SATIRLIK basliklarda altta bir
                  //	satirlik BOSLUK kalir ve yazi ile telefon arasi ~43 px
                  //	gorunurdu — kullanici "bosluk fazla" dedigi seydi.
                  //	Artik kisa baslik ASAGI iner: bosluk USTE kayar,
                  //	telefonla arasi HER SAYFADA 6 px kalir.
                  mainAxisAlignment: MainAxisAlignment.end,
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
            ),
            // ⚠️ TURU 127 — yazi-telefon araligi: 22 -> 18 (%20) -> **6**
            //    (kullanici 18 i de fazla buldu). Sifir YAPILMADI: kalin
            //    baslik ile cerceve YAPISIK durur ve metin cerceveye
            //    degiyormus gibi okunurdu.
            const SizedBox(height: 6),
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
                  // ⚠️ TURU 127 — cerceve **%20 GOMULU** (kullanici emri:
                  //    *"telefonlar gomulu olsun %20 kadar asagi"*).
                  //    `ClipRect` tasan kismi kirpar; tasma KASITLI.
                  child: Transform.translate(
                    offset: Offset(0, boy * 0.20),
                    child: SizedBox(
                      width: en,
                      height: boy,
                      child: const _BosTelefon(),
                    ),
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
      // ⚠️ TURU 127 — **DYNAMIC ISLAND (ses celtigi) KALDIRILDI**
      //    (kullanici emri: *"telefondaki ses celtigini kaldir"*).
      //    Cerceve artik TAMAMEN bos: yalniz koyu kenar + acik ekran.
      child: const ColoredBox(color: _kEkran, child: SizedBox.expand()),
    ),
  );
}
