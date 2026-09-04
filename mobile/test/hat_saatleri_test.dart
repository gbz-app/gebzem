/// ⚠️⚠️⚠️ TURU 167 — **HAT SAATLERI SAYFASI MUHAFIZI.**
///
/// Bu sayfa **emulatorde gorulemiyor**: acilis yolu konuma bagli (yakin
/// duraklar -> durak sheet'i -> hat satiri) ve emulatore GPS fix'i HIC
/// gelmiyor (turu 140/142/145'te olculdu). O yuzden yerlesim BURADA,
/// GERCEK varliklarla ve GERCEK bir hatla sinaniyor.
///
/// Neden onemli: bu projede ayni sinif hata BES kez sahaya cikti —
/// `Stack`e 0x0 cocuk (turu 136, EKRANIN TAMAMI silindi), cocuksuz
/// `CustomPaint` (turu 156), `Column` icinde `Flexible` (turu 162).
/// Tasma da sessizdir: `flutter analyze` TEMIZ gecer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/ulasim/ulasim_sayfalari.dart';
import 'package:gebzem/features/ulasim/ulasim_veri.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gEn = 40.8028;
  const gBoy = 29.4307;

  /// Gercek varliklardan hatti OLAN bir durak bulur.
  ///
  /// ⚠️⚠️ `tester.runAsync` ICINDE cagrilmak ZORUNDA: `testWidgets`
  ///    sahte (fake) bir zaman bolgesinde kosar ve GERCEK dosya G/C'si
  ///    (rootBundle + `compute` izolati) orada ASLA tamamlanmaz — test
  ///    sessizce ASILI KALIR ("did not complete", olculdu: 6 dk 55 sn).
  Future<({Durak durak, DurakHatti dh})> ornekBul() async {
    final duraklar = await UlasimVeri.i.yakinDuraklar(gEn, gBoy, adet: 25);
    for (final d in duraklar) {
      final hatlar = await UlasimVeri.i.duraginHatlari(d.id, 1);
      if (hatlar.isNotEmpty) return (durak: d, dh: hatlar.first);
    }
    throw StateError('hatti olan durak bulunamadi');
  }

  /// Sheet'i acar. `pumpAndSettle` KULLANILMAZ: yukleme sirasinda
  /// `CircularProgressIndicator` sonsuz doner ve pumpAndSettle ZAMAN
  /// ASIMINA ugrar.
  Future<void> ac(
    WidgetTester tester, {
    required Durak durak,
    required DurakHatti dh,
    required double olcek,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // ⚠️⚠️ ANAHTAR ZORUNLU: ayni testte ikinci kez cagrilinca element
        //    agaci YENIDEN KULLANILIR ve Navigator'in route yigini AYAKTA
        //    kalir -> onceki sheet ekranda durur, "ac" dugmesine yapilan
        //    dokunus ONA carpar ve ikinci olcek HIC SINANMAZ (yalanci
        //    yesil; ilk kosuda tam bu yasandi, hit-test uyarisiyla
        //    yakalandi).
        key: ValueKey(olcek),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
          child: Scaffold(
            body: Builder(
              builder: (c) => Center(
                child: ElevatedButton(
                  onPressed: () => hatSaatleriAc(
                    c,
                    durak: durak,
                    hat: dh.hat,
                    yon: dh.yon,
                    servis: 1,
                  ),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('⚠️ HAT SAATLERI: iki bolum de CIZILIYOR', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late ({Durak durak, DurakHatti dh}) o;
    // ⚠️ ON ISINMA: varlik bir kez okununca `UlasimVeri` onbellege alir;
    //    widget icindeki ayni cagri artik MIKROTASKTA doner ve `pump`
    //    onu akitabilir.
    await tester.runAsync(() async {
      o = await ornekBul();
      await UlasimVeri.i.duraginHatlari(o.durak.id, 1);
    });
    await ac(tester, durak: o.durak, dh: o.dh, olcek: 1.0);

    expect(tester.takeException(), isNull);
    expect(find.text('Bu duraktan geçiş'), findsOneWidget);
    expect(find.text('İlk duraktan kalkış'), findsOneWidget);
    // Durak adi bolum basliginin ALTINDA yaziyor — hangi liste hangi
    // duraga ait olduguu belirsiz kalmasin (turu 165/166 dersi).
    expect(find.text(o.durak.ad), findsWidgets);
    // Guzergah cizimi bu sayfadan yapiliyor; dugme kaybolursa haritaya
    // ulasmanin YOLU KALMAZ (dokunus artik saatleri aciyor).
    expect(find.text('Güzergâhı haritada göster'), findsOneWidget);
  });

  testWidgets('⚠️ HAT SAATLERI: 360 dp x olcek 1.3 ve 2.0 TASMIYOR',
      (tester) async {
    late ({Durak durak, DurakHatti dh}) o;
    // ⚠️ ON ISINMA: varlik bir kez okununca `UlasimVeri` onbellege alir;
    //    widget icindeki ayni cagri artik MIKROTASKTA doner ve `pump`
    //    onu akitabilir.
    await tester.runAsync(() async {
      o = await ornekBul();
      await UlasimVeri.i.duraginHatlari(o.durak.id, 1);
    });
    for (final olcek in const [1.3, 2.0]) {
      tester.view.physicalSize = const Size(360 * 3, 720 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await ac(tester, durak: o.durak, dh: o.dh, olcek: olcek);
      expect(
        tester.takeException(),
        isNull,
        reason: 'yazi olcegi $olcek tasma/istisna uretti',
      );
    }
  });

  testWidgets('⚠️ SAATLER GTFS ILE BIREBIR (uydurma sayi YOK)',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late ({Durak durak, DurakHatti dh}) o;
    // ⚠️ ON ISINMA: varlik bir kez okununca `UlasimVeri` onbellege alir;
    //    widget icindeki ayni cagri artik MIKROTASKTA doner ve `pump`
    //    onu akitabilir.
    await tester.runAsync(() async {
      o = await ornekBul();
      await UlasimVeri.i.duraginHatlari(o.durak.id, 1);
    });
    await ac(tester, durak: o.durak, dh: o.dh, olcek: 1.0);
    expect(tester.takeException(), isNull);

    // Ekranda gorunen ilk birkac saat, VERIDEKI kalkislarla ayni olmali.
    // ⚠️ Bu, "gosterilen saat hesaplanmiyor, OKUNUYOR" iddiasinin
    //    yasayan kanitidir (turu 166 dogrulamasinin arayuz ayagi).
    var bulunan = 0;
    for (final dk in o.dh.kalkislar.take(6)) {
      if (find.text(UlasimVeri.saatMetni(dk)).evaluate().isNotEmpty) {
        bulunan++;
      }
    }
    expect(bulunan, greaterThan(0),
        reason: 'veri dosyasindaki kalkislardan HICBIRI ekranda yok');
  });

  testWidgets('⚠️ DURAK KARTI: VARIS SAATI ekranda YAZIYOR', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late ({Durak durak, DurakHatti dh}) o;
    await tester.runAsync(() async {
      o = await ornekBul();
      await UlasimVeri.i.duraginHatlari(o.durak.id, 1);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: ElevatedButton(
                onPressed: () => durakDetayAc(
                  c,
                  o.durak,
                  guzergahSec: (_, __) {},
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);

    // ⚠️⚠️ TURU 168 — kullanici ekran goruntusu: saat 09:17, kartta "7 dk",
    //    altinda "Ilk duraktan kalkis: 09:20" -> *"09:20 ama 7 dakika var
    //    diyor"*. Hesap DOGRUYDU ama BU DURAGA VARIS SAATI (09:24) ekranda
    //    HICBIR YERDE YAZMIYORDU; kullanici geri sayimla BASKA bir
    //    buyuklugun saatini karsilastiriyordu.
    expect(
      find.textContaining('Bu duraktan: '),
      findsWidgets,
      reason: 'bu duraga varis saatleri ADIYLA yazmiyor',
    );
    expect(
      find.textContaining('kalkış: '),
      findsWidgets,
      reason: 'ilk duraktan kalkis satiri kayboldu',
    );
  });
}
