import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

void main() {
  testWidgets('appbar title alani', (t) async {
    await fontYukle();
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    double? alan;
    await t.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          appBar: AppBar(
            leadingWidth: 16 * 2 + 26 - 5,
            leading: IconButton(
              iconSize: 26,
              icon: const Icon(LucideIcons.squarePlus),
              onPressed: () {},
            ),
            centerTitle: true,
            titleSpacing: 0,
            title: LayoutBuilder(
              builder: (c, k) {
                alan = k.maxWidth;
                return const SizedBox();
              },
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: IconButton(
                  iconSize: 26,
                  icon: const Icon(LucideIcons.bell),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // ignore: avoid_print
    print('TITLE ALANI = $alan');
  });
}
