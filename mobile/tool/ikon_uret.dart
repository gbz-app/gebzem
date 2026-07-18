// UYGULAMA IKONU HAZIRLIK ARACI
//
// Kaynak: assets/icon/kaynak.jpg — kullanicinin tasarimi: siyah kanvas ustunde
// yuvarlak koseli mor kare + beyaz kivrimli logo.
//
// Uretim (dart run tool/ikon_uret.dart):
//  1) assets/icon/icon.png            — siyah kenar bosluklari OTOMATIK kirpilmis
//     tam-kare (1024x1024). iOS + Android legacy ikon bundan uretilir: iOS kendi
//     kose maskesini uygular, kirpmadan verilirse logo tile icinde kucuk kalirdi.
//  2) assets/icon/icon-adaptive-fg.png — Android 8+ adaptive icon FOREGROUND:
//     1024 kanvas, SEFFAF zemin, kirpilmis kare ortada %66 (guvenli bolge; launcher
//     daire/squircle maskesi kenardan tasani keser). Background katmani pubspec'te
//     duz #000000 — kaynak gorselin kenar rengiyle ayni, sonuc orijinal tasarimla es.
//
// Sonra: dart run flutter_launcher_icons  (mipmap'ler + AppIcon.appiconset yazilir)
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final kaynak = img.decodeImage(File('assets/icon/kaynak.jpg').readAsBytesSync())!;

  // Icerigin (siyah olmayan piksellerin) sinir kutusunu bul. JPEG gurultusu ve
  // mor parlama (glow) icin dusuk esik: luminance > 10/255.
  int minX = kaynak.width, minY = kaynak.height, maxX = 0, maxY = 0;
  for (var y = 0; y < kaynak.height; y++) {
    for (var x = 0; x < kaynak.width; x++) {
      final p = kaynak.getPixel(x, y);
      final lum = (p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000;
      if (lum > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  // Kare kirp (genis kenari esas al, ortala) — glow kaybolmasin diye kutu AYNEN alinir.
  final kenar = (maxX - minX + 1) > (maxY - minY + 1) ? (maxX - minX + 1) : (maxY - minY + 1);
  final cx = (minX + maxX) ~/ 2, cy = (minY + maxY) ~/ 2;
  var x0 = cx - kenar ~/ 2, y0 = cy - kenar ~/ 2;
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x0 + kenar > kaynak.width) x0 = kaynak.width - kenar;
  if (y0 + kenar > kaynak.height) y0 = kaynak.height - kenar;
  final kirpik = img.copyCrop(kaynak, x: x0, y: y0, width: kenar, height: kenar);
  stdout.writeln('icerik kutusu: ($minX,$minY)-($maxX,$maxY) -> kare $kenar px @($x0,$y0)');

  // 1) icon.png — 1024 tam kare
  final ikon = img.copyResize(kirpik, width: 1024, height: 1024,
      interpolation: img.Interpolation.cubic);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(ikon));
  stdout.writeln('yazildi: assets/icon/icon.png (1024)');

  // 2) adaptive foreground — seffaf 1024 kanvas, tile ortada %66
  final fg = img.Image(width: 1024, height: 1024, numChannels: 4); // seffaf
  const hedef = 676; // 1024 * 0.66
  final tile = img.copyResize(kirpik, width: hedef, height: hedef,
      interpolation: img.Interpolation.cubic);
  img.compositeImage(fg, tile, dstX: (1024 - hedef) ~/ 2, dstY: (1024 - hedef) ~/ 2);
  File('assets/icon/icon-adaptive-fg.png').writeAsBytesSync(img.encodePng(fg));
  stdout.writeln('yazildi: assets/icon/icon-adaptive-fg.png (1024, fg %66)');
}
