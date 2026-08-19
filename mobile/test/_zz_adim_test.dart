import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';

Future<void> fontYukle() async {
  for (final w in ['400', '500', '600', '700']) {
    final f = File('assets/fonts/GoogleSans-$w.ttf');
    if (!f.existsSync()) continue;
    final l = FontLoader('Google Sans')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await l.load();
  }
}

const adlar = ['Temel bilgiler', 'Adres & konum', 'Çalışma saatleri'];

void main() {
  for (final olcek in [1.0, 1.15, 1.3]) {
    for (var adim = 0; adim < 3; adim++) {
      testWidgets('adim $adim olcek $olcek', (t) async {
        await fontYukle();
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: lightTheme,
            builder: (c, w) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(olcek)),
              child: w!,
            ),
            home: Scaffold(
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (adim > 0)
                        TextButton(onPressed: () {}, child: const Text('Geri')),
                      const Spacer(),
                      Text('${adim + 1}/3 · ${adlar[adim]}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {},
                        child: Text(adim < 2 ? 'Devam' : 'İşletme hesabını aç'),
                      ),
                    ],
                  ),
                ),
              ),
              body: const SizedBox(),
            ),
          ),
        );
        final e = t.takeException();
        // ignore: avoid_print
        print('>>> adim=${adim + 1} olcek=$olcek : ${e == null ? "TEMIZ" : e.toString().split("\n").first}');
      });
    }
  }
}
