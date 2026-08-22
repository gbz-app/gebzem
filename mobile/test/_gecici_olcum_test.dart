import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/auth/auth_stil.dart';

Future<void> _fontYukle() async {
  for (final e in {
    'assets/fonts/GoogleSans-400.ttf': 'w400',
    'assets/fonts/GoogleSans-500.ttf': 'w500',
  }.entries) {
    final l = FontLoader('Google Sans');
    l.addFont(
      File(e.key).readAsBytes().then(
        (b) => ByteData.view(Uint8List.fromList(b).buffer),
      ),
    );
    await l.load();
  }
}

void main() {
  testWidgets('telefon alani tasma olcumu', (t) async {
    await _fontYukle();
    final rapor = StringBuffer();
    for (final ekran in [360.0, 375.0, 393.0, 412.0]) {
      for (final olcek in [1.0, 1.15, 1.3, 1.5, 2.0]) {
        t.view.physicalSize = Size(ekran * 3, 800 * 3);
        t.view.devicePixelRatio = 3.0;
        t.platformDispatcher.textScaleFactorTestValue = olcek;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        final ctrl = TextEditingController(text: '512 345 67 89');
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Google Sans'),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 17, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [AuthTelefonAlani(controller: ctrl, sade: true)],
                ),
              ),
            ),
          ),
        );
        await t.pump();

        final deko = t.renderObject<RenderBox>(find.byType(InputDecorator));
        final giris = t.renderObject<RenderBox>(find.byType(EditableText));
        final tp = TextPainter(
          text: TextSpan(
            text: '512 345 67 89',
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 30.0 * olcek,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final gizli = tp.width - giris.size.width;
        rapor.writeln(
          'EKRAN ${ekran.toInt()} OLCEK $olcek | alan ${deko.size.width.toStringAsFixed(1)} '
          '| giris ${giris.size.width.toStringAsFixed(1)} | metin ${tp.width.toStringAsFixed(1)} '
          '| GIZLI ${gizli.toStringAsFixed(1)}',
        );
      }
    }
    File('olcum_sonuc.txt').writeAsStringSync(rapor.toString());
  });
}
