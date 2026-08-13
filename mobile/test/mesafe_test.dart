/// ⚠️⚠️⚠️ TURU 96 — KART MESAFESI MUHAFIZI.
///
/// Kullanici: *"isletme kartlarinda yakinlik 1 km ya da 300 m gibi mesafeler
/// gorunsun"*. Bu ozelligin CIHAZDA gorunmesi konum iznine ve GPS'e bagli;
/// emulatorun sahte GPS'i (`adb emu geo fix`) Play Services goruntusunde
/// fused saglayiciya ULASMIYOR, yani ekranda BAKARAK dogrulanamiyor.
///
/// Bu test o bosluğu kapatir: hesap ve BICIM burada, cihazdan bagimsiz
/// olarak kanitlanir.
/// ⚠️ YAPMA: bu testi silme; mesafe bicimi degisirse (ondalik ayraci,
///    "km"/"m" esigi) burada da guncelle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/isletme/isletme_kart.dart';
import 'package:gebzem/features/isletme/isletme_servisi.dart';

IsletmeOzet _isletme({required double enlem, required double boylam}) =>
    IsletmeOzet.json({
      'id': 'x',
      'name': 'Test',
      'kategori': 'yemek',
      'enlem': enlem,
      'boylam': boylam,
    });

void main() {
  // Gebze merkez — tohum verisinin de referans noktasi.
  const enlem = 40.8028, boylam = 29.4307;

  test('metre esigi: 1 km altinda "m", ustunde "km"', () {
    // ~0.003 derece enlem ≈ 333 m
    final yakin = _isletme(enlem: enlem + 0.003, boylam: boylam);
    // ~0.012 derece enlem ≈ 1,33 km
    final uzak = _isletme(enlem: enlem + 0.012, boylam: boylam);
    mesafeleriDoldur([yakin, uzak], enlem, boylam);

    expect(yakin.mesafeMetni.endsWith(' m'), isTrue,
        reason: '1 km altinda metre yazilmali: ${yakin.mesafeMetni}');
    expect(uzak.mesafeMetni.endsWith(' km'), isTrue,
        reason: '1 km ustunde km yazilmali: ${uzak.mesafeMetni}');
    // ⚠️ ONDALIK AYRACI VIRGUL (Turkce): "1.3 km" degil "1,3 km".
    expect(uzak.mesafeMetni.contains(','), isTrue,
        reason: 'ondalik ayraci virgul olmali: ${uzak.mesafeMetni}');
  });

  test('hesap dogru: 1 derece enlem ~111 km', () {
    final o = _isletme(enlem: enlem + 0.09, boylam: boylam);
    mesafeleriDoldur([o], enlem, boylam);
    // 0.09 derece ≈ 10 km (+/- %2)
    expect(o.km, greaterThan(9.8));
    expect(o.km, lessThan(10.2));
  });

  test('⚠️ KOORDINATSIZ ISLETME ATLANIR (0,0 = Gine Korfezi)', () {
    final o = _isletme(enlem: 0, boylam: 0);
    mesafeleriDoldur([o], enlem, boylam);
    expect(o.km, 0, reason: '0,0 icin mesafe hesaplanmamali');
    expect(o.mesafeMetni, '',
        reason: 'mesafe bilinmiyorsa kartta HICBIR SEY cizilmemeli');
  });

  test('⚠️ SUNUCU DEGERI KAZANIR (Yakinimda siralamasi yalanlanmasin)', () {
    final o = _isletme(enlem: enlem + 0.09, boylam: boylam)..km = 2.5;
    mesafeleriDoldur([o], enlem, boylam);
    expect(o.km, 2.5,
        reason: 'sunucu km doldurduysa istemci UZERINE YAZMAMALI');
  });

  // ⚠️⚠️ ASIL SORU BU: mesafe KARTA CIZILIYOR MU?
  //
  //	Hesabin dogru olmasi yetmez — kullanicinin sikayeti *"min 260 TL gibi
  //	oraya mesafe koy dedim, koymamissin"* idi. Bu iki test, sayinin
  //	kartin ALT SATIRINDA (saat · cuzdan · pin) gercekten gorundugunu
  //	CIHAZDAN BAGIMSIZ kanitlar.
  Future<void> kartiCiz(WidgetTester t, IsletmeOzet o) => t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => vitrinSatiri(c, o, kompakt: false),
            ),
          ),
        ),
      );

  testWidgets('KARTTA mesafe cizilir (min. tutar ve sure ile YAN YANA)',
      (t) async {
    final o = IsletmeOzet.json({
      'id': 'x',
      'name': 'Test',
      'kategori': 'yemek',
      'min_tutar_kurus': 26000,
      'teslimat_dk_min': 25,
      'teslimat_dk_max': 35,
      'puan': 4.5,
      'puan_sayisi': 320,
    })
      ..km = 1.3;
    await kartiCiz(t, o);
    expect(find.text('1,3 km'), findsOneWidget);
    // ⚠️ Yani ucu BIRLIKTE: kullanicinin istedigi satir tam bu.
    expect(find.text('Min. 260 TL'), findsOneWidget);
    expect(find.text('25-35 dk'), findsOneWidget);
  });

  testWidgets('⚠️ MESAFE BILINMIYORSA KARTTA HICBIR SEY CIZILMEZ', (t) async {
    final o = IsletmeOzet.json({
      'id': 'x',
      'name': 'Test',
      'kategori': 'yemek',
      'min_tutar_kurus': 26000,
    });
    await kartiCiz(t, o);
    expect(find.text('Min. 260 TL'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
    expect(find.textContaining(' m'), findsNothing);
  });
}
