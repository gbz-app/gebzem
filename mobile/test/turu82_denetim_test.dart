// GECICI DENETIM TESTI (turu 82) — bittiginde SILINECEK.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────── A) story_izleyici.dart dispose() deseninin BIREBIR kopyasi
class _Cocuk extends StatefulWidget {
  const _Cocuk({required this.onIzlendi});
  final VoidCallback onIzlendi;
  @override
  State<_Cocuk> createState() => _CocukState();
}

class _CocukState extends State<_Cocuk> with SingleTickerProviderStateMixin {
  late AnimationController _ilerleme;
  static bool ilerlemeDisposeEdildi = false;
  static bool superDisposeEdildi = false;

  @override
  void initState() {
    super.initState();
    _ilerleme =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..forward();
  }

  @override
  void dispose() {
    widget.onIzlendi(); // story_izleyici.dart:88
    _ilerleme.dispose(); // story_izleyici.dart:90
    ilerlemeDisposeEdildi = true;
    super.dispose(); // story_izleyici.dart:91
    superDisposeEdildi = true;
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('cocuk'));
}

class _Ebeveyn extends StatefulWidget {
  const _Ebeveyn();
  @override
  State<_Ebeveyn> createState() => _EbeveynState();
}

class _EbeveynState extends State<_Ebeveyn> {
  bool izlendi = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _Cocuk(
              onIzlendi: () {
                // story_seridi.dart:287-289
                if (mounted) setState(() => izlendi = true);
              },
            ),
          ),
        ),
        child: Text('ac $izlendi'),
      ),
    ),
  );
}

// ─────────── B) _bolmeSecici genislik olcumu (akis_ekrani.dart:280-322)
Future<void> _fontYukle() async {
  final l = FontLoader('Google Sans');
  for (final w in ['400', '500', '600', '700']) {
    l.addFont(
      File('assets/fonts/GoogleSans-$w.ttf').readAsBytes().then(
        (b) => ByteData.view(Uint8List.fromList(b).buffer),
      ),
    );
  }
  await l.load();
}

double _yaziGenisligi(String s, double boy, FontWeight w, double olcek) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: boy, fontWeight: w, fontFamily: 'Google Sans'),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(olcek),
  )..layout();
  return tp.width;
}

void main() {
  testWidgets('A) dispose icinden ebeveyn setState', (t) async {
    await t.pumpWidget(const MaterialApp(home: _Ebeveyn()));
    await t.tap(find.byType(ElevatedButton));
    await t.pumpAndSettle();

    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pumpAndSettle();

    final hata = t.takeException();
    // ignore: avoid_print
    print('>>> A/HATA: $hata');
    // ignore: avoid_print
    print(
      '>>> A/_ilerleme.dispose() calisti mi = ${_CocukState.ilerlemeDisposeEdildi}',
    );
    // ignore: avoid_print
    print(
      '>>> A/super.dispose() calisti mi     = ${_CocukState.superDisposeEdildi}',
    );
    expect(hata, isNull, reason: 'dispose icinden setState patlamamali');
  });

  testWidgets('B) bolme secici genislik (17px vs 15px)', (t) async {
    await _fontYukle();
    for (final olcek in [1.0, 1.3, 1.5, 2.0]) {
      for (final boy in [15.0, 17.0]) {
        // secili = w800, pasif = w500
        final a =
            _yaziGenisligi('Takip Ettiklerin', boy, FontWeight.w800, olcek) + 20;
        final b = _yaziGenisligi('Keşfet', boy, FontWeight.w500, olcek) + 20;
        // ignore: avoid_print
        print(
          '>>> B/ olcek=$olcek boy=$boy  toplam=${(a + b).toStringAsFixed(1)}'
          '  (360dp ekranda kullanilabilir = 344)',
        );
      }
    }
  });

  testWidgets('C) etkilesim cubugu genislik (24px kutu vs 22px kutu)', (
    t,
  ) async {
    await _fontYukle();
    double satir({
      required double kutu,
      required bool yazarMi,
      required double olcek,
      required List<int> sayilar,
    }) {
      double oge(int? sayi) {
        var w = 16 + kutu; // yatay dolgu 8+8 + ikon kutusu
        if (sayi != null && sayi > 0) {
          w +=
              6 +
              _yaziGenisligi(
                sayi >= 1000 ? '12.3B' : '$sayi',
                13,
                FontWeight.w600,
                olcek,
              );
        }
        return w;
      }

      var t = oge(sayilar[0]) + oge(sayilar[1]) + oge(null); // kalp,yorum,send
      if (yazarMi) t += oge(sayilar[2]); // istatistik
      t += oge(null); // bookmark
      return t;
    }

    for (final olcek in [1.0, 1.3, 2.0]) {
      for (final kutu in [22.0, 24.0]) {
        final v = satir(
          kutu: kutu,
          yazarMi: true,
          olcek: olcek,
          sayilar: [12300, 12300, 12300],
        );
        // ignore: avoid_print
        print(
          '>>> C/ olcek=$olcek kutu=$kutu yazar=true  toplam=${v.toStringAsFixed(1)}'
          '  (360dp ekran, kart dolgusu 20 -> kullanilabilir 340)',
        );
      }
    }
  });
}
