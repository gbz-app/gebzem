/// ⚠️⚠️ TURU 82b — ASAGI-CEK-YENILE GOSTERGESI. **TEK KAYNAK.**
///
/// Kullanici emri: *"yukaridan asagi yenilemede 3 tane nokta olsun, sirayla
/// havaya kalkip insin, basit cok basit bir animasyonla"*.
///
/// Material'in varsayilan `RefreshIndicator`i donen bir halka cizer; bu dosya
/// onu **UC NOKTA**yla degistirir. Noktalar sirayla (faz kaymali) yukari
/// kalkip iner.
///
/// ⚠️ NEDEN `RefreshIndicator`I TAMAMEN DEGISTIRMEDIK: `RefreshIndicator`
///    yalnizca bir gorsel degil, **jest + kaydirma protokolu**dur
///    (`ScrollNotification` dinler, `onRefresh` Future'ini bekler, asiri
///    cekmeyi sonlandirir). Kendi jestimizi yazmak o protokolu bastan yazmak
///    demekti. Bunun yerine Flutter'in resmi uzanti noktasi kullanildi:
///    `RefreshIndicator` sarmalanip `indicatorBuilder` YERINE, gostergeyi
///    saydamlastirip USTUNE kendi noktalarimizi ciziyoruz.
/// ⚠️ YAPMA: `RefreshIndicator`i cikarip elle `GestureDetector` yazma.
library;

import 'package:flutter/material.dart';

/// Uc noktanin sirayla ziplamasi.
///
/// ⚠️ Animasyon **SUREKLI** kosar ama yalnizca gosterge gorunurken agacta
///    olur — `RefreshIndicator` cekilmedigi surece bu widget CIZILMEZ, yani
///    bostayken CPU harcanmaz.
class UcNokta extends StatefulWidget {
  const UcNokta({super.key, this.renk, this.cap = 7});

  final Color? renk;
  final double cap;

  @override
  State<UcNokta> createState() => _UcNoktaState();
}

class _UcNoktaState extends State<UcNokta> with SingleTickerProviderStateMixin {
  /// ⚠️ TEK controller, uc nokta. Her noktaya ayri controller vermek uc kat
  ///    tick maliyeti demekti; faz kaymasi hesapla uretiliyor.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    // ⚠️ ZORUNLU: `repeat()` eden controller dispose edilmezse ticker sonsuza
    //    kadar yasar (turu 82'de olculen `dispose` sizintisi sinifi).
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renk = widget.renk ?? Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          // Faz kaymasi: her nokta bir oncekinden 1/6 tur geride.
          final t = (_c.value + i * (1 / 6)) % 1.0;
          // 0..1 -> 0..1..0 (yukari kalk, in). `sin` yerine ucgen dalga:
          // ⚠️ Ucgen dalga BILINCLI — kullanici "BASIT, cok basit" dedi;
          //    yumusatilmis egri "zipzip" hissini abartir.
          final z = t < 0.5 ? t * 2 : (1 - t) * 2;
          // Yalniz ilk yarida yukselsin, sonra dursun (sirali his).
          final y = -Curves.easeOut.transform(z) * widget.cap * 0.9;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.cap * 0.32),
            child: Transform.translate(
              offset: Offset(0, y),
              child: Container(
                width: widget.cap,
                height: widget.cap,
                decoration: BoxDecoration(
                  // Yukseldikce hafif belirginlesir — "cok hafif" vurgu.
                  color: renk.withValues(alpha: 0.45 + 0.55 * z),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Uygulama genelindeki asagi-cek-yenile sarmali.
///
/// ⚠️ Material gostergesi GORUNMEZ yapilir (`color: transparent` +
///    `backgroundColor: transparent`), yerine `UcNokta` cizilir. Boylece jest
///    ve `onRefresh` protokolu AYNEN korunur.
/// ⚠️ `displacement` noktalarin dikey konumunu belirler.
class YenileSarmali extends StatefulWidget {
  const YenileSarmali({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<YenileSarmali> createState() => _YenileSarmaliState();
}

class _YenileSarmaliState extends State<YenileSarmali> {
  /// Kullanici SU AN listeyi asagi cekiyor (henuz birakmadi).
  bool _cekiliyor = false;

  /// `onRefresh` SU AN kosuyor.
  bool _yenileniyor = false;

  bool get _gorunur => _cekiliyor || _yenileniyor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          // ⚠️⚠️ IKI AYRI DURUM, IKI AYRI BAYRAK — **TEK BAYRAK YETMEZ.**
          //
          //    Ilk yazimda tek bir `_gorunur` vardi ve `OverscrollNotification`
          //    ile true yapiliyor, YALNIZ `onRefresh`in `finally`sinde false
          //    yapiliyordu. Kullanici listeyi BIRAZ cekip yenilemeyi
          //    TETIKLEMEDEN birakirsa `onRefresh` HIC CAGRILMAZ, dolayisiyla
          //    `finally` de kosmaz -> **NOKTALAR EKRANDA SONSUZA KADAR ASILI
          //    KALIRDI** (ustelik `IgnorePointer` oldugu icin kullanicinin
          //    onlari kaldirma yolu da yoktu).
          //
          //    Artik cekme durumu `ScrollEndNotification` ile KAPANIR; asil
          //    yenileme ayri bayrakta izlenir ve ikisinin BIRLESIMI cizilir.
          // ⚠️ YAPMA: bu iki bayragi tek bayraga indirgeme.
          onNotification: (n) {
            // ⚠️⚠️⚠️ **DERINLIK SUZGECI ZORUNLU** (denetim bulgusu).
            //
            //    `RefreshIndicator`in kendi varsayilan suzgeci
            //    (`defaultScrollNotificationPredicate`) YALNIZ `depth == 0`
            //    bildirimlerini kabul eder. Biz bildirimleri KENDI
            //    `NotificationListener`imizle dinledigimiz icin o suzgec
            //    devrede DEGIL — yani IC ICE her kaydirilabilir alan
            //    noktalari tetikliyordu:
            //      · akistaki YATAY galeri seridi (her gonderi kartinda),
            //      · profil izgarasi, sekme seritleri, yatay ek seritleri.
            //    Kullanici galeride saga kaydirirken ekranin ustunde uc nokta
            //    beliriyordu — hicbir yenileme olmadigi halde.
            // ⚠️ YAPMA: bu kapiyi kaldirma.
            if (n.depth != 0) return false;

            // ---- ANDROID yolu: `ClampingScrollPhysics` sinira dayaninca
            //      `OverscrollNotification` uretir.
            if (n is OverscrollNotification && n.overscroll < 0) {
              if (!_cekiliyor) setState(() => _cekiliyor = true);
              return false;
            }
            // ---- ⚠️⚠️⚠️ iOS yolu — **AYRI DAL ZORUNLU** (denetim bulgusu).
            //
            //      iOS'ta gecerli fizik `BouncingScrollPhysics`tir ve onun
            //      `applyBoundaryConditions` metodu **DAIMA 0.0 doner**, yani
            //      liste gercekten hareket eder ve **HICBIR ZAMAN
            //      `OverscrollNotification` DOGMAZ**. Tek dalli haliyle uc
            //      nokta iPhone'da CEKME sirasinda HIC cizilmiyordu — ozellik
            //      kullanicinin gordugu ilk platformda OLU dogacakti.
            //      (`AlwaysScrollableScrollPhysics` bunu DEGISTIRMEZ; Bouncing'i
            //      ebeveyn olarak sarar, sinir davranisi ondan gelir.)
            //
            // ⚠️ `extentBefore == 0` ZORUNLU: onsuz listenin ORTASINDA
            //    kaydirirken de noktalar cizilirdi.
            // ⚠️ `dragDetails != null` ZORUNLU: balistik (parmak kalktiktan
            //    sonraki) kaydirma yenileme DEGILDIR.
            if (n is ScrollUpdateNotification &&
                n.dragDetails != null &&
                n.metrics.extentBefore == 0) {
              if (!_cekiliyor) setState(() => _cekiliyor = true);
              return false;
            }
            if (n is ScrollEndNotification) {
              if (_cekiliyor) setState(() => _cekiliyor = false);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() => _yenileniyor = true);
              try {
                await widget.onRefresh();
              } finally {
                // ⚠️ `finally` ZORUNLU: `onRefresh` firlatirsa noktalar
                //    ekranda ASILI kalirdi.
                if (mounted) setState(() => _yenileniyor = false);
              }
            },
            // Material halkasi GORUNMEZ — yerine noktalar cizilir.
            color: Colors.transparent,
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: widget.child,
          ),
        ),
        if (_gorunur)
          Positioned(
            top: 18,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: UcNokta(cap: 7)),
            ),
          ),
      ],
    );
  }
}
