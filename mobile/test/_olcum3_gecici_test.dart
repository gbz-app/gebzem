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

Widget kart(BuildContext context, String ad) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SizedBox(
      height: kKesifKutu,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    const SizedBox(height: 5),
    SizedBox(
      height: MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2,
      child: Center(
        child: Text(
          ad,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Google Sans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('talep izgarasi 360dp', (t) async {
    await fontYukle();
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    for (final olcek in [1.3]) {
      await t.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(olcek),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: kIzgaraAralik,
                          mainAxisSpacing: kIzgaraAralik,
                          childAspectRatio: 0.78,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => kart(c, 'Gelin Arabası'),
                      childCount: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final ex = t.takeException();
      // ignore: avoid_print
      print('olcek=$olcek  hucre=${(360 - 32 - 36) / 4} x ${((360 - 32 - 36) / 4) / 0.78}  '
          'icerik=${kKesifKutu + 5 + 14 * olcek * 1.15 * 2}  istisna=$ex');
    }
  });
}
