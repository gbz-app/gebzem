import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> fontYukle() async {
  for (final w in ['400', '500', '600', '700']) {
    final f = File('assets/fonts/GoogleSans-$w.ttf');
    if (!f.existsSync()) continue;
    final loader = FontLoader('Google Sans')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await loader.load();
  }
}

double genislik(String s, double boy, FontWeight w, double olcek) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Google Sans', fontSize: boy, fontWeight: w),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(olcek),
  )..layout();
  return tp.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('olcum', () async {
    await fontYukle();
    for (final olcek in [1.0, 1.15, 1.3, 1.5]) {
      final a = genislik('Arkadaş', 17, FontWeight.w800, olcek);
      final k = genislik('Keşfet', 17, FontWeight.w800, olcek);
      final m = genislik('Mahalle', 17, FontWeight.w800, olcek);
      // ignore: avoid_print
      print('olcek=$olcek  Arkadas=${a.toStringAsFixed(1)} Kesfet=${k.toStringAsFixed(1)} Mahalle=${m.toStringAsFixed(1)} toplam+dolgu=${(a + k + m + 60).toStringAsFixed(1)}');
    }
  });
}
