import 'dart:io';
import 'dart:typed_data';
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

void main() {
  testWidgets('gercek tema ile alt cubuk', (t) async {
    await fontYukle();
    t.view.devicePixelRatio = 1.0;
    for (final g in [360.0, 393.0, 411.0]) {
      for (final o in [1.0, 1.3]) {
        t.view.physicalSize = Size(g, 800);
        await t.pumpWidget(const SizedBox.shrink());
        final h = <String>[];
        final onc = FlutterError.onError;
        FlutterError.onError = (d) => h.add(d.exceptionAsString());
        await t.pumpWidget(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(o)),
          child: MaterialApp(
            key: ValueKey('$g-$o'),
            theme: lightTheme,
            home: Scaffold(
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Geri')),
                      const Spacer(),
                      const Text('3/3 · Çalışma saatleri',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      FilledButton(
                          onPressed: () {},
                          child: const Text('İşletme hesabını aç')),
                    ],
                  ),
                ),
              ),
              body: const SizedBox(),
            ),
          ),
        ));
        await t.pump();
        FlutterError.onError = onc;
        final ts = h.where((x) => x.contains('overflow')).toList();
        // ignore: avoid_print
        print('TEMA W=$g olcek=$o -> ${ts.isEmpty ? "TEMIZ" : ts.first.split("\n").first}');
      }
    }
    t.view.resetPhysicalSize();
  });
}
