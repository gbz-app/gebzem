import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

Widget sheetIcerik() => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ListTile(
            leading: Icon(LucideIcons.messageCirclePlus),
            title: Text('Yeni sohbet'),
            subtitle: Text('Bir kişiyle mesajlaş'),
          ),
          ListTile(
            leading: Icon(LucideIcons.users),
            title: Text('Yeni grup'),
            subtitle: Text('Birden fazla kişiyle mesajlaş'),
          ),
          ListTile(
            leading: Icon(LucideIcons.radio),
            title: Text('Topluluk oluştur'),
            subtitle: Text('Sen yazarsın, üyeler okur ve yorumlar'),
          ),
          ListTile(
            leading: Icon(LucideIcons.compass),
            title: Text('Toplulukları keşfet'),
            subtitle: Text('Var olan topluluklara katıl'),
          ),
        ],
      ),
    );

void main() {
  testWidgets('yeni sohbet sheet tasmasi', (t) async {
    await fontYukle();
    t.view.devicePixelRatio = 1.0;
    t.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
    for (final boy in [640.0, 732.0, 800.0, 896.0]) {
      for (final o in [1.0, 1.15, 1.3, 1.5]) {
        t.view.physicalSize = Size(360, boy);
        await t.pumpWidget(const SizedBox.shrink());
        final h = <String>[];
        final onc = FlutterError.onError;
        FlutterError.onError = (d) => h.add(d.exceptionAsString());
        await t.pumpWidget(MaterialApp(
          key: ValueKey('$boy-$o'),
          theme: lightTheme,
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(o)),
            child: w!,
          ),
          home: Builder(builder: (c) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<String>(
                    context: c,
                    showDragHandle: true,
                    builder: (_) => sheetIcerik(),
                  ),
                  child: const Text('ac'),
                ),
              ),
            );
          }),
        ));
        await t.pump();
        await t.tap(find.text('ac'));
        await t.pumpAndSettle();
        FlutterError.onError = onc;
        final ts = h.where((x) => x.contains('overflow')).toList();
        // ignore: avoid_print
        print('SHEET boy=$boy olcek=$o -> ${ts.isEmpty ? "TEMIZ" : ts.first.split("\n").first}');
      }
    }
    t.view.resetPhysicalSize();
  });
}
