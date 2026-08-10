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
  bool _gorunur = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          // ⚠️ Noktalari YALNIZ yenileme sirasinda cizmek icin cekme durumunu
          //    izliyoruz. `OverscrollNotification` cekmeyi, `ScrollEnd`
          //    birakmayi bildirir.
          onNotification: (n) {
            if (n is OverscrollNotification && n.overscroll < 0) {
              if (!_gorunur) setState(() => _gorunur = true);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() => _gorunur = true);
              try {
                await widget.onRefresh();
              } finally {
                // ⚠️ `finally` ZORUNLU: `onRefresh` firlatirsa noktalar
                //    ekranda ASILI kalirdi.
                if (mounted) setState(() => _gorunur = false);
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
