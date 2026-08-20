/// ⚠️⚠️⚠️ TURU 119 — **ACILIS (SPLASH) EKRANI** (kullanici emri:
///	*"uygulamayi kapatip telefonda tekrar actigimda Instagram/WhatsApp/Meta
///	SIYAH EKRAN geliyor, 1 saniye arkada uygulama yuklemelerini yapiyor;
///	bizde de olsun, AKSE DIGITAL yazsin ... siyah arka plan, hafif gri
///	Akse Digital ALTTA ORTADA 100px yukarida, logo 30px yukarida, hafif
///	saydam olacak"*).
///
/// ═══════════ NEDEN BIR EKRAN DEGIL, KATMAN ═══════════
///
/// Bu bir route DEGIL: `main.dart`taki `MaterialApp.router` `builder`inda
/// uygulamanin USTUNE serilen bir katmandir.
/// ⚠️ Route olsaydi yonlendirme (`redirect`) mantigina karismasi gerekirdi:
///    oturum var mi, onboarding gorulmus mu... Katman olarak hicbirine
///    dokunmaz, uygulama ARKADA normal calisir ve hazir oldugunda ustten
///    solar. Kullanicinin tarif ettigi davranis da tam budur
///    (*"arkada uygulama yuklemelerini yapiyor"*).
///
/// ⚠️⚠️ **SURE SABIT DEGIL, EN AZ SURE**: katman `_enAzMs` kadar DURUR ve
///	sonra solar. Amac "1 saniye bekletmek" degil, acilis isleri (tercih
///	okuma, oturum dogrulama, ilk kare) biterken BEYAZ/BOS bir kare
///	gostermemektir. Cihaz hizliysa kullanici yalnizca kisa bir marka
///	ekrani gorur; yavassa katman zaten gerekiyordur.
///
/// ⚠️ Android tarafinda `launch_background.xml` de SIYAHA cevrildi: aksi
///    halde surec baslarken BEYAZ bir kare, hemen ardindan bu SIYAH katman
///    gelir ve acilis "yanip sonuyor" gibi gorunurdu.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Acilis logosu. ⚠️ `_Logo` ve `precacheImage` AYNI sabiti kullanir —
///    ayrisirlarsa on bellege alinan gorsel ile cizilen gorsel FARKLI
///    olur ve on bellekleme HICBIR ISE YARAMAZ.
const kAcilisLogo = 'assets/icon/logo.png';

/// Katmanin ekranda kalacagi EN AZ sure.
const _enAzMs = 1100;

/// Solma suresi.
const _solmaMs = 420;

class AcilisKatmani extends StatefulWidget {
  const AcilisKatmani({super.key, required this.child});

  final Widget child;

  @override
  State<AcilisKatmani> createState() => _AcilisKatmaniState();
}

class _AcilisKatmaniState extends State<AcilisKatmani> {
  bool _bitti = false;
  bool _baslatildi = false;
  Timer? _zamanlayici;

  /// ⚠️⚠️⚠️ SAYAC **LOGO COZULDUKTEN SONRA** BASLAR (emulatorde OLCULDU).
  ///
  ///	ONCEKI HALI `addPostFrameCallback` idi ve SU HATAYI URETIYORDU:
  ///	Flutter ILK KAREYI, Android kendi acilis ekranini HALA GOSTERIRKEN
  ///	cizer. Yani sayac, katman daha KULLANICIYA GORUNMEDEN basliyordu;
  ///	1,1 sn sonra sistem acilis ekrani kalktiginda katman ZATEN
  ///	soluyordu. Ekran goruntusunde **"Akse Digital" vardi ama LOGO
  ///	YOKTU** — cunku gorsel o an henuz COZULMEMISTI.
  ///
  /// ⚠️ `precacheImage` ile gorsel COZULUR, sonra sure baslar: boylece
  ///    logo HER ZAMAN goruntulenir. Hata olsa bile (`catchError`) sayac
  ///    yine baslar — acilis katmani KILITLENEMEZ.
  /// ⚠️ `didChangeDependencies` kullanilir (`initState` DEGIL):
  ///    `precacheImage` bir `BuildContext` ister ve `initState`te
  ///    `dependOnInheritedWidgetOfExactType` cagrilamaz.
  /// ⚠️ `_baslatildi` kapisi: `didChangeDependencies` birden cok kez
  ///    cagrilabilir (tema/olcek degisimi) ve sayac YENIDEN kurulurdu.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_baslatildi) return;
    _baslatildi = true;
    precacheImage(const AssetImage(kAcilisLogo), context)
        .catchError((_) {})
        .whenComplete(_sayaciBaslat);
  }

  void _sayaciBaslat() {
    if (!mounted) return;
    _zamanlayici = Timer(const Duration(milliseconds: _enAzMs), () {
      if (mounted) setState(() => _bitti = true);
    });
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      // ⚠️⚠️ `IgnorePointer` ZORUNLU: katman solarken (420 ms) hala agacta
      //    duruyor. Olmasaydi o sure boyunca dokunuslari YUTAR ve kullanici
      //    "uygulama takildi" sanardi.
      // ⚠️ `TickerMode` DEGIL `Offstage`: solma bitince katman agactan
      //    TAMAMEN cikarilir (`if (!_bitti)` degil `onEnd`), yoksa gorunmez
      //    bir `Stack` cocugu her karede yeniden boyanirdi.
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: _bitti ? 0 : 1,
          duration: const Duration(milliseconds: _solmaMs),
          curve: Curves.easeOut,
          child: const _AcilisGorunumu(),
        ),
      ),
    ],
  );
}

class _AcilisGorunumu extends StatelessWidget {
  const _AcilisGorunumu();

  @override
  Widget build(BuildContext context) {
    // ⚠️ Renkler TEMADAN ALINMAZ: zemin sabit siyah. Temadan alinsaydi acik
    //    temada siyah zemine siyah yazi cizilirdi (turu 81b sinifi).
    //
    // ⚠️⚠️ **`Material` SARMALI ZORUNLU (emulatorde GORULDU).** Bu katman
    //	`MaterialApp.router` `builder`inda, yani `Navigator`/`Scaffold`in
    //	DISINDA yasiyor. Orada `DefaultTextStyle` YOKTUR ve Flutter metni
    //	hata bicimiyle cizer: **monospace + SARI ALT CIZGI**. Ekranda tam
    //	boyle cikti.
    // ⚠️ YAPMA: `Material`i kaldirip yalniz `ColoredBox` birakma.
    return Material(
      color: const Color(0xFF0B0B0F),
      child: const Stack(
        children: [
          // ── LOGO: ORTADAN 30 px YUKARIDA ──
          // ⚠️ Kullanici olcusu: "logo 30px yukarida".
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: _Logo(),
            ),
          ),
          // ── "Akse Digital": ALTTA ORTADA, 100 px YUKARIDA ──
          // ⚠️ `SafeArea` ICINDE DEGIL: kullanici "alttan 100px" dedi;
          //    cihaz centigi degisken oldugu icin `bottom: 100` DOGRUDAN
          //    ekranin altindan olculur ve her cihazda AYNI durur.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 100),
              child: _Imza(),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⚠️ `Padding(bottom: 60)` ile ortadan yukari kaydirilir: `Align.center`
///    cocugu ORTALAR, alttan 60 dp dolgu vermek gorseli 30 dp YUKARI tasir
///    (dolgunun yarisi kadar). Dogrudan `bottom: 30` yazmak 15 dp kaydirirdi.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Image.asset(
    kAcilisLogo,
    width: 96,
    height: 96,
    // ⚠️ `filterQuality` orta: 512 px dosya 96 dp'ye inerken bilineer
    //    ornekleme kenarlarda tirtik uretiyordu.
    filterQuality: FilterQuality.medium,
    // ⚠️ `errorBuilder` ZORUNLU: varlik bir gun yeniden adlandirilirsa
    //    ACILIS EKRANI kirmizi hata kutusu cizerdi — kullanicinin gordugu
    //    ILK kare. Hata halinde sessizce bos birakilir.
    errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 96),
  );
}

class _Imza extends StatelessWidget {
  const _Imza();

  @override
  Widget build(BuildContext context) => const Text(
    'Akse Digital',
    // ⚠️ Sistem yazi olcegi UYGULANMAZ: 23 dp x 2.0 = 46 dp olur, imza iki
    //    satira sarar ve marka ekrani her cihazda FARKLI gorunurdu. Bu bir
    //    okunabilirlik metni degil, LOGO ile ayni siniftan bir marka ogesi.
    textScaler: TextScaler.noScaling,
    // ⚠️ "hafif gri ... hafif saydam" (kullanici): beyazin %55'i. Tam beyaz
    //    bir imza, marka logosuyla dikkat yarisina girerdi.
    // ⚠️⚠️ TURU 120 — **13 -> 23** (kullanici emri: *"giristeki Akseyi
    //	10 pixel daha buyut"*). Olcu SABIT dp'dir, `textScaler`a BAGLI
    //	DEGIL: bu katman `MaterialApp` `builder`inda yasiyor ve sistem yazi
    //	olcegi 2.0'da 46 dp'ye cikip iki satira sarardi. Marka imzasi her
    //	cihazda AYNI durmali.
    style: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w500,
      color: Color(0x8CFFFFFF),
    ),
  );
}
