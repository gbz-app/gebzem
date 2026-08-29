// GECICI OLCUM — denetim sonunda SILINECEK.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> yukle(String yol, String aile) async {
  final b = File(yol).readAsBytesSync();
  final fl = FontLoader(aile)..addFont(Future.value(b.buffer.asByteData()));
  await fl.load();
}

int satir(String s, TextStyle st, double olcek, double en) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(olcek),
  )..layout(maxWidth: en);
  return tp.computeLineMetrics().length;
}

double gen(String s, TextStyle st, double olcek) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(olcek),
  )..layout();
  return tp.width;
}

String kirp(String s, TextStyle st, double olcek, double en, int maxSatir) {
  int lo = 0, hi = s.length;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    final tp = TextPainter(
      text: TextSpan(text: s.substring(0, mid) + '\u2026', style: st),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(olcek),
    )..layout(maxWidth: en);
    if (tp.computeLineMetrics().length <= maxSatir) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return s.substring(0, lo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gercek font ile olcum', () async {
    await yukle('assets/fonts/GoogleSans-700.ttf', 'GS700');
    await yukle('assets/fonts/GoogleSans-500.ttf', 'GS500');

    const bStil = TextStyle(
        fontFamily: 'GS700',
        fontSize: 14.5,
        height: 1.2,
        fontWeight: FontWeight.w700);
    const aStil = TextStyle(
        fontFamily: 'GS500',
        fontSize: 12.5,
        height: 1.25,
        fontWeight: FontWeight.w500);

    final vakalar = {
      'kisisel': ['İşletmen mi var?', 'Ücretsiz ekle, müşterilerin seni burada bulsun'],
      'isletme': ['İşletmeni yönet', 'Bilgilerini, saatlerini ve menünü güncelle'],
    };

    for (final w in [320.0, 360.0, 375.0, 411.0]) {
      final expanded = w - 2 * 16 - 24 - (38 + 12 + 8 + 20);
      for (final o in [1.0, 1.15, 1.3, 2.0]) {
        for (final e in vakalar.entries) {
          final b = e.value[0];
          final a = e.value[1];
          final bg = gen(b, bStil, o);
          final bKesik = bg > expanded + 0.01;
          final aSat = satir(a, aStil, o, expanded);
          final aKesik = aSat > 2;
          final gorunen = aKesik ? kirp(a, aStil, o, expanded, 2) : a;
          // ignore: avoid_print
          print('W=$w o=$o ${e.key} | exp=${expanded.toStringAsFixed(0)}'
              ' | baslik=${bg.toStringAsFixed(1)} KESIK=$bKesik'
              '${bKesik ? " -> \"${kirp(b, bStil, o, expanded, 1)}…\"" : ""}'
              ' | altSatir=$aSat KESIK=$aKesik'
              '${aKesik ? " -> \"$gorunen…\"" : ""}');
        }
      }
    }
  });
}
