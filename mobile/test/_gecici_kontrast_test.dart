import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';
import 'package:gebzem/features/isletme/isletme_kart.dart' show kYuzeyGri, kVurgu;

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double oran(Color a, Color b) {
  final l1 = lum(a), l2 = lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

Color uzerine(Color on, Color alt) => Color.from(
      alpha: 1,
      red: on.r * on.a + alt.r * (1 - on.a),
      green: on.g * on.a + alt.g * (1 - on.a),
      blue: on.b * on.a + alt.b * (1 - on.a),
    );

Future<void> olc(WidgetTester t, ThemeData tema, String ad) async {
  late BuildContext ctx;
  await t.pumpWidget(MaterialApp(
    theme: tema,
    home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }),
  ));
  final scheme = Theme.of(ctx).colorScheme;
  final zemin = kYuzeyGri(ctx);
  final vurgu = kVurgu(ctx);
  final alt = uzerine(scheme.onSurface.withValues(alpha: 0.75), zemin);
  final chev = uzerine(scheme.onSurface.withValues(alpha: 0.45), zemin);
  final ikonZemin = uzerine(vurgu.withValues(alpha: 0.14), zemin);
  final sayfa = Theme.of(ctx).scaffoldBackgroundColor;
  // ignore: avoid_print
  print('TEMA=$ad brightness=${Theme.of(ctx).brightness} '
      'zemin=0x${(zemin.toARGB32()).toRadixString(16)} '
      'sayfa=0x${(sayfa.toARGB32()).toRadixString(16)} '
      'baslik=${oran(scheme.onSurface, zemin).toStringAsFixed(2)} '
      'alt12.5=${oran(alt, zemin).toStringAsFixed(2)} '
      'chevron20=${oran(chev, zemin).toStringAsFixed(2)} '
      'ikonGlif=${oran(vurgu, ikonZemin).toStringAsFixed(2)} '
      'kartVsSayfa=${oran(zemin, sayfa).toStringAsFixed(2)}');
}

void main() {
  testWidgets('acik', (t) => olc(t, lightTheme, 'acik'));
  testWidgets('koyu', (t) => olc(t, darkTheme, 'koyu'));
}
