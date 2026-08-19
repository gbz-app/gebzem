import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const double kYanBosluk = 16, kKesifKutu = 78, kIzgaraAralik = 12;

Future<void> fontYukle() async {
  for (final w in ['400', '500', '600', '700']) {
    final f = File('assets/fonts/GoogleSans-$w.ttf');
    if (!f.existsSync()) continue;
    final l = FontLoader('Google Sans')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await l.load();
  }
}

Widget kart(BuildContext c, String ad) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SizedBox(height: kKesifKutu, child: const DecoratedBox(decoration: BoxDecoration(color: Colors.grey))),
    const SizedBox(height: 5),
    SizedBox(
      height: MediaQuery.textScalerOf(c).scale(14) * 1.15 * 2,
      child: Center(child: Text(ad, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Google Sans', fontSize: 14, fontWeight: FontWeight.w600, height: 1.15))),
    ),
  ],
);

void main() {
  for (final ekran in [360.0, 411.0]) {
    for (final olcek in [1.0, 1.15, 1.3, 1.5]) {
      testWidgets('talep izgara ${ekran.toInt()}dp x $olcek', (t) async {
        await fontYukle();
        t.view.physicalSize = Size(ekran, 800);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        await t.pumpWidget(MediaQuery(
          data: MediaQueryData(size: Size(ekran, 800), textScaler: TextScaler.linear(olcek)),
          child: Directionality(textDirection: TextDirection.ltr,
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: kIzgaraAralik,
                    mainAxisSpacing: kIzgaraAralik, childAspectRatio: 0.78),
                  delegate: SliverChildBuilderDelegate((c, i) => kart(c, 'Gelin Arabası'), childCount: 8),
                ),
              ),
            ]),
          ),
        ));
        final w = (ekran - 32 - 36) / 4;
        final h = w / 0.78;
        final icerik = kKesifKutu + 5 + 14 * olcek * 1.15 * 2;
        final ex = t.takeException();
        // ignore: avoid_print
        print('EKRAN=$ekran OLCEK=$olcek hucre=${w.toStringAsFixed(1)}x${h.toStringAsFixed(2)} '
            'icerik=${icerik.toStringAsFixed(2)} TASMA=${(icerik - h).toStringAsFixed(2)} '
            'istisna=${ex == null ? "YOK" : "VAR"}');
      });
    }
  }
}
