import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const oneriler = <String>[
  "Gebze'nin en iyi kebapçısı",
  "Gebze'de hava nasıl olacak?",
  "Gebze'de akşam nereye gidilir?",
  "Gebze'de nöbetçi eczane",
  "Gebze'de hafta sonu planı",
  "Gebze'de çocukla nereye?",
  "Gebze'de iyi bir kuaför",
  "Gebze'de kahvaltı nerede?",
  "Gebze'de bu hafta etkinlik",
  "Gebze'de nakliyeci arıyorum",
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Google Sans');
    for (final w in ['400', '500', '600', '700']) {
      loader.addFont(Future.value(
          File('assets/fonts/GoogleSans-$w.ttf').readAsBytesSync().buffer.asByteData()));
    }
    await loader.load();
  });

  test('olcu', () {
    for (final olcek in [1.0, 1.3, 1.4, 1.43, 1.5, 2.0]) {
      final ts = TextScaler.linear(olcek);
      double maxW = 0;
      String enUzun = '';
      double h = 0;
      for (final s in oneriler) {
        final tp = TextPainter(
          text: TextSpan(
            text: s,
            style: const TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: ts,
          maxLines: 1,
        )..layout();
        if (tp.width > maxW) { maxW = tp.width; enUzun = s; }
        h = tp.height;
      }
      print('olcek=$olcek  metinYuksekligi=${h.toStringAsFixed(2)} (kutu 26)  '
          'enUzunGenislik=${maxW.toStringAsFixed(1)} ("$enUzun")');
    }
  });
}
