import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';

Future<void> fontYukle() async {
  for (final w in ['400', '500', '600', '700']) {
    final f = File('assets/fonts/GoogleSans-$w.ttf');
    if (!f.existsSync()) continue;
    final loader = FontLoader('Google Sans')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await loader.load();
  }
}

Widget cubuk(int adim) {
  const adimSayisi = 3;
  const adlar = ['Temel bilgiler', 'Adres & konum', 'Çalışma saatleri'];
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          if (adim > 0)
            TextButton(onPressed: () {}, child: const Text('Geri')),
          const Spacer(),
          Text('${adim + 1}/$adimSayisi · ${adlar[adim]}',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {},
            child: Text(
                adim < adimSayisi - 1 ? 'Devam' : 'İşletme hesabını aç'),
          ),
        ],
      ),
    ),
  );
}

void olc(double genislik, double olcek, int adim) {
  testWidgets('w=$genislik olcek=$olcek adim=$adim', (t) async {
    await fontYukle();
    t.view.physicalSize = Size(genislik * 3, 800 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    final hatalar = <String>[];
    final eski = FlutterError.onError;
    FlutterError.onError = (d) => hatalar.add(d.exceptionAsString());
    await t.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
        child: Scaffold(bottomNavigationBar: cubuk(adim)),
      ),
    ));
    FlutterError.onError = eski;
    final tasan = hatalar.where((e) => e.contains('overflow')).toList();
    // ignore: avoid_print
    print('SONUC w=$genislik olcek=$olcek adim=$adim -> '
        '${tasan.isEmpty ? "OK" : tasan.first.split("\n").first}');
  });
}

void main() {
  for (final g in [360.0, 411.0]) {
    for (final o in [1.0, 1.15, 1.3]) {
      for (final a in [0, 1, 2]) {
        olc(g, o, a);
      }
    }
  }
}
