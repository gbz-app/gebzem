library;

import 'package:flutter/material.dart';

/// ⚠️⚠️⚠️ TURU 99 — YANIT AGACININ **BAGLANTI CIZGISI** (kullanici emri +
///	Threads ekran goruntusu: *"yorumlarda asagi inen okun kivrimi var,
///	bizde duz"*).
///
/// Cizgi avatarin ALTINDAN baslar, asagi iner ve **ALT UCUNDA SAGA KIVRILIR**
/// ("Yanitlari goster" satirina baglanir).
///
/// ⚠️⚠️ **TEK `Path` ZORUNLU.** Ilk akla gelen cozum uc `Container` (dikey +
///	kose + yatay) koymak; birlesme noktalarinda anti-alias DIKISI gorunur
///	ve kivrim "kirik" cizilir. Tek path + `StrokeJoin.round` ile dikis YOK.
/// ⚠️ Yukseklik EBEVEYNDEN gelir (`Expanded` + `IntrinsicHeight`); buraya
///    sabit yukseklik verilirse yazi olcegi 1.3'te cizgi avatardan kopar.
class ThreadCizgi extends CustomPainter {
  const ThreadCizgi({required this.kivrimli, required this.renk});

  // ⚠️ Turu 102: `altPay` KALDIRILDI. Kivrimin bitis noktasi artik cizim
  //    kutusunun KENDI yuksekligiyle veriliyor (`YorumGrubu._segment`);
  //    iki ayri yerde ayni hesabi tutmak drift uretiyordu.

  /// Dalin SON ogesi mi — kivrim yalniz burada cizilir, ara halkalarda
  /// cizgi DUZ devam eder.
  final bool kivrimli;
  final Color renk;

  /// Kivrimin yaricapi ve kivrimden sonraki yatay pay.
  static const double yaricap = 12;
  static const double yatay = 10;
  static const double kalinlik = 2;

  @override
  void paint(Canvas canvas, Size size) {
    // ⚠️ Merkez KUTUDAN turetilir (avatar genisligi verilir) — sabit sayi YOK.
    final cx = size.width / 2;
    final h = size.height;
    final p = Path()..moveTo(cx, 0);
    if (kivrimli && h > yaricap) {
      // ⚠️⚠️⚠️ **QUADRATIC BEZIER — `arcToPoint` DEGIL.**
      //
      //	`arcToPoint` ayni iki nokta + yaricap icin IKI yay uretir ve
      //	`clockwise` bayragi ikisinden birini secer. Iki denemede de
      //	YANLIS yayi cizdi: bir kez disbukey ("ters"), bir kez de kose
      //	yerine DIYAGONAL bir parca. Kullanici ikisini de sahada gordu.
      //
      //	Kontrol noktasi **kosenin TA KENDISI** olan bir quadratic Bezier
      //	tam bir L yuvarlatmasi verir ve BASKA bir yorumu YOKTUR:
      //	  dikey  -> (cx, h - r)
      //	  kontrol-> (cx, h)          <- kose
      //	  bitis  -> (cx + r, h)
      // ⚠️ YAPMA: buraya tekrar `arcToPoint` koyma.
      p
        ..lineTo(cx, h - yaricap)
        ..quadraticBezierTo(cx, h, cx + yaricap, h)
        ..lineTo(cx + yaricap + yatay, h);
    } else {
      p.lineTo(cx, h);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(ThreadCizgi eski) =>
      eski.kivrimli != kivrimli || eski.renk != renk;
}

/// Cizgi rengi — TEK KAYNAK (acik/koyu temada ayri alfa).
Color threadCizgiRengi(BuildContext c) {
  final koyu = Theme.of(c).brightness == Brightness.dark;
  return Theme.of(
    c,
  ).colorScheme.onSurface.withValues(alpha: koyu ? 0.20 : 0.14);
}
