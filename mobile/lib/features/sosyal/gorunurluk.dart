import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ⚠️⚠️ TURU 76b — GORUNURLUK GOZCUSU (akista OTOMATIK VIDEO icin).
///
/// Kullanici emri: *"arada videoda olabilir direk otomatik oynuyacak videolar"*.
///
/// **NEDEN AYRI BIR PAKET EKLENMEDI (`visibility_detector`):** bu projede her yeni
/// bagimlilik iOS/Android derleme riskidir (CLAUDE.md'de sentry 8.x, firebase eski
/// surumleri ve pbxproj tuzaklariyla defalarca yasandi). Gereken sey ~60 satir:
/// widget'in kendi `RenderBox`unu kapsayan `Scrollable`in viewport'uyla kesistir.
///
/// ⚠️⚠️ **NEDEN "HEPSI OYNASIN" DEMIYORUZ:** akista 20 kart olabilir. Hepsinde
///    oynatici kurulsaydi (a) cihaz isinir/pil biter, (b) mobil veri yanar,
///    (c) iOS'ta ses oturumu PROSES GENELINDE TEK oldugu icin aramalar sagirlasir
///    (turu 64/65/73). Bu yuzden YALNIZ yeterince gorunen kart oynar.
///
/// ⚠️ KISMA (throttle) ZORUNLU: kaydirma saniyede ~60 bildirim uretir; her birinde
///    `localToGlobal` cagirmak akisi takar. 120ms'de bir olculur — goz bunu
///    fark etmez.
///
/// ⚠️ `dispose`ta dinleyici MUTLAKA birakilir; aksi halde dispose edilmis
///    State'in `setState`i cagrilir ("Cannot use ref after disposed" sinifi).
class Gorunurluk extends StatefulWidget {
  const Gorunurluk({
    super.key,
    required this.child,
    required this.onOran,
    this.kisma = const Duration(milliseconds: 120),
  });

  final Widget child;

  /// 0.0 (hic gorunmuyor) - 1.0 (tamamen gorunuyor).
  final void Function(double oran) onOran;
  final Duration kisma;

  @override
  State<Gorunurluk> createState() => _GorunurlukState();
}

class _GorunurlukState extends State<Gorunurluk> {
  ScrollPosition? _pozisyon;
  Timer? _kisma;
  double _sonOran = -1;

  @override
  void initState() {
    super.initState();
    // ⚠️ Ilk cizimden SONRA: `Scrollable.of` ancak agac kurulduktan sonra bulur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bagla();
      _olc();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bagla();
  }

  void _bagla() {
    final yeni = Scrollable.maybeOf(context)?.position;
    if (identical(yeni, _pozisyon)) return;
    _pozisyon?.removeListener(_kaydirdi);
    _pozisyon = yeni;
    _pozisyon?.addListener(_kaydirdi);
  }

  void _kaydirdi() {
    if (_kisma?.isActive ?? false) return;
    _kisma = Timer(widget.kisma, () {
      if (mounted) _olc();
    });
  }

  void _olc() {
    final kutu = context.findRenderObject() as RenderBox?;
    if (kutu == null || !kutu.attached || !kutu.hasSize) return;
    final yukseklik = kutu.size.height;
    if (yukseklik <= 0) return;

    // Kapsayan viewport'un ekrandaki dikey araligi.
    final ham = RenderAbstractViewport.maybeOf(kutu);
    // ⚠️ `RenderAbstractViewport` bir ARAYUZ; olcum icin `RenderBox` olmasi
    //    gerekiyor. Ayri bir degiskene alip tipini SABITLIYORUZ (dogrudan
    //    `is` yukseltmesi bu arayuz uzerinde derleyiciyi ikna etmiyor).
    final RenderBox? viewport = ham is RenderBox ? ham as RenderBox : null;
    double vUst, vAlt;
    if (viewport != null && viewport.attached) {
      final o = viewport.localToGlobal(Offset.zero);
      vUst = o.dy;
      vAlt = o.dy + viewport.size.height;
    } else {
      // Viewport bulunamadiysa EKRANI kullan — gozcu sessizce olmesin.
      final ekran =
          View.of(context).physicalSize.height /
          View.of(context).devicePixelRatio;
      vUst = 0;
      vAlt = ekran;
    }

    final ust = kutu.localToGlobal(Offset.zero).dy;
    final alt = ust + yukseklik;
    final kesisim = (alt.clamp(vUst, vAlt)) - (ust.clamp(vUst, vAlt));
    final oran = (kesisim / yukseklik).clamp(0.0, 1.0);

    // ⚠️ Sadece ANLAMLI degisimde bildir — her olcumde setState zinciri
    //    tetiklemek gereksiz yeniden cizim uretir.
    if ((oran - _sonOran).abs() < 0.06 &&
        !(oran == 0 && _sonOran > 0) &&
        !(oran == 1 && _sonOran < 1)) {
      return;
    }
    _sonOran = oran;
    widget.onOran(oran);
  }

  @override
  void dispose() {
    _kisma?.cancel();
    _pozisyon?.removeListener(_kaydirdi);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
