import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> fontYukle() async {
  for (final w in ['400', '500', '600', '700']) {
    final f = File('assets/fonts/GoogleSans-$w.ttf');
    if (!f.existsSync()) continue;
    final l = FontLoader('Google Sans')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await l.load();
  }
}

const _adimAdlari = ['Temel bilgiler', 'Adres & konum', 'Çalışma saatleri'];
const _adimSayisi = 3;

Widget cubuk(BuildContext c, int adim) => SafeArea(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        if (adim > 0) TextButton(onPressed: () {}, child: const Text('Geri')),
        const Spacer(),
        Text('${adim + 1}/$_adimSayisi · ${_adimAdlari[adim]}',
            style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: () {},
          child: Text(adim < _adimSayisi - 1 ? 'Devam' : 'İşletme hesabını aç'),
        ),
      ],
    ),
  ),
);

void main() {
  for (final ekran in [360.0, 411.0]) {
    for (final olcek in [1.0, 1.15, 1.3]) {
      for (final adim in [0, 1, 2]) {
        testWidgets('cubuk ${ekran.toInt()} x$olcek adim$adim', (t) async {
          await fontYukle();
          t.view.physicalSize = Size(ekran, 800);
          t.view.devicePixelRatio = 1.0;
          addTearDown(t.view.reset);
          await t.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'Google Sans'),
            home: MediaQuery(
              data: MediaQueryData(size: Size(ekran, 800), textScaler: TextScaler.linear(olcek)),
              child: Scaffold(bottomNavigationBar: Builder(builder: (c) => cubuk(c, adim))),
            ),
          ));
          final ex = t.takeException();
          // ignore: avoid_print
          print('EKRAN=${ekran.toInt()} OLCEK=$olcek ADIM=$adim TASMA=${ex == null ? "yok" : "VAR"} ${ex ?? ""}'
              .split('\n').first);
        });
      }
    }
  }
}
