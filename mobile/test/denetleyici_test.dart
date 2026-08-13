import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⚠️⚠️⚠️ TURU 96i — KALICI MUHAFIZ: "diyalogdan hemen sonra dispose".
///
///	SAHADA GORULEN HATA: kullanici konum kaydederken **EKRANIN TAMAMI
///	KIRMIZI** oldu. Kok neden su desendi:
///
///	    final ctrl = TextEditingController();
///	    final x = await showDialog(... TextField(controller: ctrl) ...);
///	    ctrl.dispose();            // <-- COK ERKEN
///
///	`showDialog`/`showModalBottomSheet` future'i **`pop` aninda** cozulur;
///	route'un CIKIS ANIMASYONU surerken alt agac hala cizilir ve
///	`EditableText` denetleyiciye dokunur:
///	*"A TextEditingController was used after being disposed."*
///	Bu bir `build` istisnasidir -> `ErrorWidget` -> tam ekran kirmizi.
///
/// ⚠️⚠️ **BU HATA SESSIZDIR:** `flutter analyze` TEMIZ gecer, uygulama
///	COKMEZ, geri tusuna basilinca ekran KENDILIGINDEN duzelir. Yani ancak
///	GOZLE yakalanir — nitekim KULLANICI SAHADA YAKALADI. Kod tabaninda
///	**ALTI** ayri yerde vardi.
///
/// Cozum: denetleyiciyi diyalogun KENDI agacinda tutan `DenetleyiciSahibi`
/// (bkz. `lib/core/denetleyici_sahibi.dart`). Metin `await`ten hemen sonra
/// SENKRON okunur (nesne hala canli), birakmayi sarmalayici yapar.
///
/// ⚠️ YAPMA: bu testi silme. Yeni bir diyalog yazarken denetleyiciyi
///    `DenetleyiciSahibi`ye ver.
void main() {
  test('diyalogdan hemen sonra TextEditingController.dispose() YOK', () {
    final kok = Directory('lib');
    expect(kok.existsSync(), isTrue, reason: 'test mobile/ dizininden kosar');

    final bulgular = <String>[];

    for (final dosya in kok
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final satirlar = _yorumsuz(dosya.readAsStringSync()).split('\n');

      for (var i = 0; i < satirlar.length; i++) {
        // YEREL denetleyici: `final <ad> = TextEditingController(`
        // (sinif alani `TextEditingController _x = ...` bicimindedir ve
        //  `dispose()` govdesinde birakilir — o DOGRU desendir.)
        final m =
            RegExp(r'final\s+(\w+)\s*=\s*TextEditingController\(')
                .firstMatch(satirlar[i]);
        if (m == null) continue;
        final ad = m.group(1)!;

        // Ayni fonksiyon govdesi icinde (kabaca 120 satir) once bir
        // `await show...` gorulup ARDINDAN `<ad>.dispose()` geliyor mu?
        var diyalogSatiri = -1;
        for (var j = i + 1; j < satirlar.length && j < i + 120; j++) {
          if (diyalogSatiri < 0 &&
              RegExp(r'await\s+show(Dialog|ModalBottomSheet)')
                  .hasMatch(satirlar[j])) {
            diyalogSatiri = j;
            continue;
          }
          if (diyalogSatiri >= 0 &&
              RegExp('\\b$ad\\.dispose\\(\\)').hasMatch(satirlar[j])) {
            bulgular.add('${dosya.path}:${j + 1}  ->  $ad.dispose() '
                '(diyalog ${diyalogSatiri + 1}. satirda)');
            break;
          }
        }
      }
    }

    expect(
      bulgular,
      isEmpty,
      reason: 'Diyalog/sheet KAPANIRKEN denetleyici birakiliyor — cikis '
          'animasyonu sirasinda "used after being disposed" atar ve EKRAN '
          'KIRMIZI olur. Cozum: DenetleyiciSahibi ile sar, dispose satirini '
          'KALDIR.\n${bulgular.join('\n')}',
    );
  });

  test('DenetleyiciSahibi tek kaynak olarak duruyor', () {
    final f = File('lib/core/denetleyici_sahibi.dart');
    expect(f.existsSync(), isTrue,
        reason: 'DenetleyiciSahibi SILINMIS — kirmizi ekran hatasi geri gelir');
    final s = f.readAsStringSync();
    expect(s.contains('void dispose()'), isTrue);
    expect(s.contains('d.dispose()'), isTrue,
        reason: 'sarmalayici artik denetleyicileri birakmiyor');
  });
}

/// Kaynagi yorumlardan temizler.
///
/// ⚠️ ZORUNLU: bu dosyanin ve duzeltilen dosyalarin SERHLERINDE hatali
///    desenin KENDISI ornek olarak yaziliyor. Temizlenmezse muhafiz kendi
///    aciklamasini yakalayip YANLIS ALARM verir (turu 80b/83/86 tuzagi).
String _yorumsuz(String kaynak) => kaynak
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((l) {
      final t = l.trimLeft();
      return (t.startsWith('//') || t.startsWith('///')) ? '' : l;
    })
    .join('\n');
