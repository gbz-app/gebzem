/// ⚠️⚠️⚠️ TURU 116 — **LOGO VARLIK (ASSET) MUHAFIZI.**
///
/// Alt menunun ortasindaki logo (`features/home/alt_menu.dart` -> `_logo`)
/// `assets/icon/logo.png` dosyasini
///
///	`BoxDecoration(shape: BoxShape.circle)` + `BoxFit.cover`
///
/// ile cizer. Yani gorsel ic kutuya (`kAltMenuLogoIcCap`) oturur ve DAIRESEL
/// kirpilir. Bu, dosya uzerinde bir **SOZLESME** dogurur:
///
///	  gorseldeki daire kare kanvasa **IC TEGET** olmali.
///
/// Degilse `cover` saydam kenari da cizer, arkadaki **gradient halka**
/// gorunur ve sonuc: halka anormal KALIN, isaret KUCUK. Turu 96m'de tam bu
/// yasandi (*"logonun koseleri sikintili"*).
///
/// ⚠️⚠️ **NEDEN AYRI BIR TEST — `alt_menu_test.dart` BUNU YAKALAYAMAZ.**
///	O dosya bir **YERLESIM** muhafizidir: `shape`, `fit`, 54/58 dp olculeri
///	olcer. Bunlarin hepsi WIDGET agacina bakar; **DOSYANIN ICERIGINE
///	BAKMAZ.** Kenarlarinda 8 px saydam dolgu olan bozuk bir `logo.png`
///	o testlerin **HEPSINI GECER**. Turu 116 denetimi bunu olcup gosterdi.
///	⚠️ YAPMA: bu kontrolleri `alt_menu_test.dart`a tasima — kapsamlari ayri.
///
/// ⚠️ Uretim araci (`tool/logo_uret.dart`) ayni sozlesmeyi ZATEN zorluyor ve
///    saglanmazsa dosyayi YAZMIYOR. Bu test IKINCI katman: logo aracı
///    ATLANARAK (elle kopyalanarak) degistirilirse yine yakalanir.
///
/// ⚠️ **DURUST SINIR:** `.github/workflows/{android,ios}.yml` icinde
///    `flutter test` **YOK** — yani bu muhafiz CI'da KOSMAZ. Degeri surum
///    rutinindeki elle `flutter test` adimindadir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Mukemmel ic-teget dairenin saydam piksel orani: 1 - pi/4 = %21.46.
const _teorikSaydam = 21.46;

void main() {
  late img.Image logo;

  setUpAll(() {
    final f = File('assets/icon/logo.png');
    expect(f.existsSync(), isTrue,
        reason: 'assets/icon/logo.png YOK — alt menudeki logo cizilemez.');
    final cozulen = img.decodeImage(f.readAsBytesSync());
    expect(cozulen, isNotNull, reason: 'logo.png cozulemedi (bozuk PNG?).');
    logo = cozulen!;
  });

  test('logo.png 512x512 KARE', () {
    expect(logo.width, logo.height,
        reason: 'Logo KARE olmali: `BoxFit.cover` kare olmayan gorseli '
            'dairesel kutuda KIRPAR (isaretin bir kismi kaybolur).');
    // ⚠️ 512: dis cap 58 dp, dpr 4'te 232 px gerekir; 512 ~2,2 kat pay birakir.
    //    Kucultulurse yuksek yogunlukta BULANIK cikar.
    expect(logo.width, 512,
        reason: 'Logo 512x512 olmali (bkz. tool/logo_uret.dart `_hedefBoy`).');
  });

  test('logo.png ALFA KANALI tasir', () {
    // ⚠️ Alfasiz bir logo, siyah alt menu seridinde daire yerine KARE bir
    //    leke birakir (koseler opak olur).
    // ⚠️ Ayrica alfa yoksa asagidaki iki olcum YAPISAL OLARAK anlamsizdir:
    //    `image` paketi `numChannels <= 3` icin `pixel.a`yi literal 255
    //    dondurur, yani "dolgu" DAIMA 0 cikar.
    expect(logo.numChannels, 4,
        reason: 'logo.png RGBA olmali (saydam koseler gorselin tasarimi).');
  });

  test('⚠️ DAIRE KENARLARA DEGER (kenar dolgusu <= 2 px)', () {
    var minX = logo.width, minY = logo.height, maxX = -1, maxY = -1;
    for (var y = 0; y < logo.height; y++) {
      for (var x = 0; x < logo.width; x++) {
        if (logo.getPixel(x, y).a < 8) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    expect(maxX, greaterThanOrEqualTo(0),
        reason: 'logo.png TAMAMEN SAYDAM.');

    final dolgular = <String, int>{
      'sol': minX,
      'ust': minY,
      'sag': logo.width - 1 - maxX,
      'alt': logo.height - 1 - maxY,
    };
    for (final e in dolgular.entries) {
      // ⚠️ 2 px pay: anti-alias yumusamasi dolgu SAYILMAZ, gercek bosluk sayilir.
      expect(e.value, lessThanOrEqualTo(2),
          reason: '${e.key} kenarinda ${e.value}px SAYDAM DOLGU var. '
              '`BoxFit.cover` bu boslugu da cizer -> arkadaki GRADIENT HALKA '
              'gorunur, halka KALIN ve isaret KUCUK durur (turu 96m hatasi). '
              'Logoyu `dart run tool/logo_uret.dart <kaynak>` ile uret.');
    }
  });

  test('⚠️ GORSEL BIR DAIRE (saydam oran ~%21.46)', () {
    // ⚠️⚠️ BU KONTROL, USTTEKININ YAKALAYAMADIGINI YAKALAR: koseleri
    //	yuvarlatilmis bir KARE de dort kenara deger (dolgu 0) ama saydam
    //	orani %21 degil ~%5 olur. Eski logo (turu 116 oncesi) tam boyleydi:
    //	%7.8 saydam, yuvarlatilmis kare. Iki olcut BIRLIKTE "daire mi"
    //	sorusunu cevaplar; tek basina hicbiri cevaplamaz.
    var saydam = 0;
    for (var y = 0; y < logo.height; y++) {
      for (var x = 0; x < logo.width; x++) {
        if (logo.getPixel(x, y).a < 8) saydam++;
      }
    }
    final oran = saydam / (logo.width * logo.height) * 100;
    expect((oran - _teorikSaydam).abs(), lessThan(3.5),
        reason: 'saydam oran %${oran.toStringAsFixed(1)} — ic-teget daire '
            '%$_teorikSaydam bekler. Gorsel TAM DAIRE olmayabilir '
            '(opak kare ya da yuvarlatilmis kare?).');
  });
}
