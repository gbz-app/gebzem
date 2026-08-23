import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// gebzem_ai.dart:1607-1660 govdesinin BIREBIR kopyasi
Widget govde(String gorunen) {
  final beyaz = Colors.white;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
    child: SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.trendingUp, size: 17, color: beyaz.withValues(alpha: 0.55)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              gorunen,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: beyaz.withValues(alpha: 0.72),
              ),
            ),
          ),
          Container(
            width: 1.5,
            height: 16,
            margin: const EdgeInsets.only(left: 2),
            color: beyaz.withValues(alpha: 0.45),
          ),
        ],
      ),
    ),
  );
}

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

  const soru = "Gebze'de akşam nereye gidilir?";

  for (final olcek in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('olcek $olcek', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Google Sans'),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: govde(soru)),
          ),
        ),
      ));
      final rp = t.renderObject<RenderParagraph>(find.descendant(of: find.byType(Flexible), matching: find.byType(RichText)));
      final tp = TextPainter(
        text: rp.text,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(olcek),
        maxLines: 1,
      )..layout();
      final kutu = rp.size;
      print('olcek=$olcek  CIZILEN_KUTU=${kutu.width.toStringAsFixed(1)}x'
          '${kutu.height.toStringAsFixed(1)}  GEREKEN=${tp.width.toStringAsFixed(1)}x'
          '${tp.height.toStringAsFixed(1)}  '
          'yatayKirpma=${(tp.width - kutu.width).toStringAsFixed(1)}  '
          'dikeyKirpma=${(tp.height - kutu.height).toStringAsFixed(1)}');
      // gercekten clip layer'i kuruluyor mu?
      final katmanVar = rp.debugLayer != null || tp.width > kutu.width || tp.height > kutu.height;
      print('   tasma_var=$katmanVar');
    });
  }
}
