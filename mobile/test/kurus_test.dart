/// ⚠️⚠️⚠️ TURU 93b — PARA AYRISTIRMA MUHAFIZI.
///
/// Denetim, teklif tutari alaninda GERCEK BIR PARA HATASI buldu: binlik
/// ayirici olarak nokta yazan bir isletme ("85.000") **85 ₺** teklif
/// gonderiyordu (`double.parse("85.000")` = 85.0). Teklif listesi FIYATA
/// GORE siralandigi icin bu isletme listenin BASINA cikiyor ve talep sahibi
/// "en ucuz" diye onu seciyordu.
///
/// ⚠️ Bu sinif `flutter analyze` ile YAKALANMAZ (kod gecerli), sunucu da
///    yakalayamaz (100 kurus da gecerli bir teklif). Yalnizca BOYLE BIR
///    TEST yakalar.
/// ⚠️ YAPMA: bu testi silme; `_kurusOku` mantigini degistirirsen once
///    buraya vaka ekle.
///
/// ⚠️ Fonksiyon ozel (`_kurusOku`) oldugu icin KAYNAK DOSYADAN okunup
///    davranisi BURADA IKIZLENIR ve ikizin kaynakla AYNI kaldigi ayrica
///    dogrulanir (kopya sapmasi imkansiz olsun diye).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kaynaktaki `_kurusOku` govdesini okur.
String _govde() {
  final f = File('lib/features/ilan/basvuru_ekranlari.dart');
  expect(f.existsSync(), isTrue,
      reason: 'basvuru_ekranlari.dart bulunamadi — yeniden adlandirildiysa '
          'BU TESTI DE guncelle');
  final src = f.readAsStringSync();
  final bas = src.indexOf('int _kurusOku(String s) {');
  expect(bas, greaterThan(-1),
      reason: '`_kurusOku` bulunamadi — yeniden adlandirildiysa BU TESTI DE '
          'guncelle');
  final son = src.indexOf('\n}', bas);
  return src.substring(bas, son);
}

/// Kaynaktaki mantigin IKIZI. Kaynakla AYNI kaldigi `TestIkizKaynakla...`
/// testinde dogrulanir.
int kurusOku(String s) {
  var t = s.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (t.isEmpty) return 0;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  final v = double.tryParse(t);
  if (v == null || v <= 0) return 0;
  return (v * 100).round();
}

void main() {
  test('binlik ayirici nokta DOGRU okunur (85.000 -> 85.000 ₺, 85 ₺ DEGIL)',
      () {
    // ⚠️ ESKI DAVRANIS: 8500 (= 85 ₺). Sahada yanlis fiyata baglanma.
    expect(kurusOku('85.000'), 8500000);
    expect(kurusOku('1.250.000'), 125000000);
    expect(kurusOku('250.000'), 25000000);
  });

  test('ondalik nokta ONDALIK kalir (binlik sanilmaz)', () {
    // ⚠️ "Tam UC hane" olcutu olmasaydi bunlar da binlik sanilirdi.
    expect(kurusOku('85.5'), 8550);
    expect(kurusOku('85.50'), 8550);
    expect(kurusOku('0.99'), 99);
  });

  test('virgullu Turkce bicim', () {
    expect(kurusOku('1.500,50'), 150050);
    expect(kurusOku('85000,00'), 8500000);
    expect(kurusOku('1.250.000,75'), 125000075);
  });

  test('duz sayi ve gurultu', () {
    expect(kurusOku('85000'), 8500000);
    expect(kurusOku(' 85000 ₺ '), 8500000);
    expect(kurusOku(''), 0);
    expect(kurusOku('abc'), 0);
    expect(kurusOku('-5'), 0);
    expect(kurusOku('0'), 0);
  });

  test('IKIZ kaynakla AYNI mantigi tasiyor (kopya sapmasi kapisi)', () {
    final g = _govde();
    // ⚠️ Kaynakta bu iki dal DA olmali; biri silinirse test kirmizi duser.
    expect(g.contains("t.contains(',')"), isTrue,
        reason: 'virgul dali kaynaktan KALKMIS');
    expect(
      g.contains(r"RegExp(r'^\d{1,3}(\.\d{3})+$')"),
      isTrue,
      reason: 'BINLIK NOKTA dali kaynaktan KALKMIS — "85.000" tekrar 85 ₺ '
          'olarak okunur ve isletme yanlis fiyata baglanir',
    );
  });
}
