// ⚠️⚠️⚠️ TURU 120 — ACILIS (SPLASH) KATMANI MUHAFIZI.
//
// ═══════════ NEDEN EMULATOR YETMEDI ═══════════
//
// Bu katmani emulatorde EKRAN GORUNTUSUYLE dogrulamak MUMKUN OLMADI:
// Android 12+ kendi acilis ekranini (`windowSplashScreenBackground` + ORTADA
// UYGULAMA IKONU) uygulamanin ILK KARESINE kadar tutar; debug derlemede
// `am start -W` **14,5 saniye** olctu. Yani cekilen her kare SISTEM ekranini
// gosteriyordu ve ikisi birbirine COK BENZIYOR (ikisinde de siyah zemin +
// ortada logo). "Akse Digital yok" diye bakip KOD HATASI sanmak cok kolaydi.
//
// ⚠️⚠️ **DERS:** iki katman ayni seye benziyorsa, ekran goruntusu HANGISININ
//	cizildigini KANITLAMAZ. Olcum, katmani DOGRUDAN kuran bir testle
//	yapilir. (Turu 96n'in *"egri kenari tek pikselden olcme"* dersinin
//	kardesi: yanlis yuzeyi olcmek.)
//
// ⚠️ Bu test emulator gerektirmez ve her `flutter test` kosusunda calisir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/auth/acilis_ekrani.dart';

Widget _kur() => MaterialApp(
  home: const AcilisKatmani(child: Scaffold(body: Text('UYGULAMA'))),
);

void main() {
  testWidgets('⚠️ ACILISTA "Akse Digital" CIZILIR', (t) async {
    await t.pumpWidget(_kur());
    await t.pump();
    expect(
      find.text('Akse Digital'),
      findsOneWidget,
      reason: 'Acilis katmaninda marka imzasi YOK.',
    );
  });

  testWidgets('⚠️ IMZA 23 px (kullanici emri: +10 px)', (t) async {
    await t.pumpWidget(_kur());
    await t.pump();
    final yazi = t.widget<Text>(find.text('Akse Digital'));
    expect(
      yazi.style?.fontSize,
      23,
      reason:
          'Kullanici *"giristeki Akseyi 10 pixel daha buyut"* dedi (13 -> 23). '
          'Deger degistiyse bu test guncellenmeli.',
    );
    // ⚠️ Sistem yazi olcegi UYGULANMAMALI: 23 x 2.0 = 46 dp olur ve imza
    //    iki satira sarar. Marka ekrani her cihazda AYNI durmali.
    expect(
      yazi.textScaler,
      TextScaler.noScaling,
      reason: 'Imza sistem yazi olceginden BAGIMSIZ olmali.',
    );
  });

  testWidgets('⚠️ LOGO da cizilir ve `kAcilisLogo` ile AYNI varlik', (t) async {
    await t.pumpWidget(_kur());
    await t.pump();
    final gorseller = t
        .widgetList<Image>(find.byType(Image))
        .where((g) => g.image is AssetImage)
        .map((g) => (g.image as AssetImage).assetName)
        .toList();
    expect(
      gorseller.contains(kAcilisLogo),
      isTrue,
      reason:
          'Acilis logosu cizilmiyor ya da `precacheImage` ile CIZILEN varlik '
          'ayristi — on bellekleme o zaman hicbir ise yaramaz.',
    );
  });

  testWidgets('⚠️ KATMAN SOLUP KAYBOLUR (uygulama mahsur kalmaz)', (t) async {
    await t.pumpWidget(_kur());
    await t.pump();
    // Baslangicta TAM OPAK.
    expect(
      t
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity,
      1.0,
    );
    // ⚠️ En az sure + solma suresinden SONRA opaklik 0 olmali. Aksi halde
    //    katman dokunuslari yutmaya devam ederdi ("uygulama takildi").
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(seconds: 1));
    expect(
      t
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity,
      0.0,
      reason: 'Acilis katmani KAPANMIYOR — uygulama arkasinda mahsur kalir.',
    );
  });
}
