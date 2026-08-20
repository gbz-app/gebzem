// ⚠️⚠️⚠️ TURU 120 — UYGULAMA IKONU MUHAFIZI.
//
// GERCEK BIR SESSIZ HATADAN DOGDU: `flutter_launcher_icons` varsayilan olarak
// `adaptive_icon_foreground_inset: 16` kullanir ve `ic_launcher.xml` icine
// `<inset android:inset="16%">` yazar. Biz on katmani ZATEN guvenli bolgeye
// (kanvasin %40'i) gore uretiyoruz; ustune %16'lik ikinci bir kucultme
// gelince ok kanvasin **%27**'sine dusuyor ve ana ekranda minicik gorunuyor.
//
// ⚠️ BU HATA **18 TEMMUZ'DAN BERI SAHADAYDI** ve hicbir sey yakalamadi:
//   - `flutter analyze` XML'e bakmaz,
//   - `flutter build` basariyla derler (gecerli bir XML),
//   - emulatorde ikon "biraz kucuk" gorunur, "bozuk" gorunmez.
//   Ancak `dart run flutter_launcher_icons` her calistiginda XML YENIDEN
//   YAZILIR — yani pubspec'teki satir silinirse hata SESSIZCE geri gelir.
//
// ⚠️ YAPMA: bu testi silme; `flutter_launcher_icons` ayarlarini degistirirken
//    buradaki beklentileri de guncelle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String pubspec;
  late String launcherXml;

  setUpAll(() {
    pubspec = File('pubspec.yaml').readAsStringSync();
    launcherXml = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
  });

  test('⚠️ adaptive on katman INSET SIFIR (pubspec)', () {
    expect(
      pubspec.contains(RegExp(r'adaptive_icon_foreground_inset:\s*0\b')),
      isTrue,
      reason:
          'pubspec.yaml icinde `adaptive_icon_foreground_inset: 0` YOK. '
          'Varsayilan 16, ustumuze ikinci bir kucultme uygular ve ana '
          'ekrandaki ok kanvasin %40 yerine %27sine duser.',
    );
  });

  test('⚠️ URETILEN XML gercekten inset="0%" yaziyor', () {
    // ⚠️ Pubspec'i kontrol etmek YETMEZ: XML uretim ANINDA yazilir ve
    //    repodaki hali eski bir kosudan kalmis olabilir. Iki dosya da
    //    ayni seyi soylemeli — ayrisirlarsa sahaya cikan XML'dir.
    expect(
      launcherXml.contains('android:inset="0%"'),
      isTrue,
      reason:
          'ic_launcher.xml hala eski insetle duruyor. '
          '`dart run flutter_launcher_icons` yeniden calistirilmali.',
    );
  });

  test('⚠️ adaptive ARKA katman GORSEL (duz renk degil)', () {
    // Logonun kendi mor gradyani arka katmanda; duz renk olsaydi gradyanli
    // daire siyah bir karenin icinde "cikartma" gibi dururdu.
    expect(
      pubspec.contains('adaptive_icon_background: "assets/icon/icon-adaptive-bg.png"'),
      isTrue,
      reason: 'adaptive_icon_background gorsel olmali (bkz. tool/ikon_uret.dart).',
    );
    expect(
      File('assets/icon/icon-adaptive-bg.png').existsSync(),
      isTrue,
      reason: 'arka katman gorseli yok — `dart run tool/ikon_uret.dart` calistir.',
    );
    expect(
      launcherXml.contains('@drawable/ic_launcher_background'),
      isTrue,
      reason:
          'XML hala `@color/ic_launcher_background` gosteriyor; arka katman '
          'gorseli uretilmemis.',
    );
  });

  test('⚠️ IKON KAYNAGI uygulama ici logoyla AYNI dosya', () {
    // ⚠️ Turu 120 oncesi ikon `assets/icon/kaynak.jpg`ten (siyah kanvas +
    //    mor kare) uretiliyordu; uygulama ici logo ise `logo.png` idi.
    //    Iki farkli marka gorseli tasiniyordu.
    final arac = File('tool/ikon_uret.dart').readAsStringSync();
    expect(
      arac.contains("_kaynakYol = 'assets/icon/logo.png'"),
      isTrue,
      reason: 'ikon araci uygulama ici logodan uretmeli.',
    );
  });
}
