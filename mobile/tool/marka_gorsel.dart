// Tek seferlik yardimci: kullanicinin verdigi ham gorselleri paket olcusune
// indirger. `dart run tool/marka_gorsel.dart` ile calistirilir.
//
// ⚠️ 3 MB'lik bir PNG kapak, APK/IPA'ya OLDUGU GIBI girer (turu 116b:
//    varliklar `Stored` ile saklanir, sikistirilmaz). JPEG'e cevirmek
//    zorunlu.
import 'dart:io';
import 'package:image/image.dart' as im;

void main() {
  _uret('../slidermc.png', 'assets/marka/mcdonalds_kapak.jpg', 1200, 82);
  _uret('../mcdonaldslogo.jpg', 'assets/marka/mcdonalds.jpg', 512, 88);
}

void _uret(String kaynak, String hedef, int en, int kalite) {
  final b = File(kaynak).readAsBytesSync();
  final g = im.decodeImage(b);
  if (g == null) {
    stderr.writeln('COZULEMEDI: $kaynak');
    exitCode = 1;
    return;
  }
  final k = g.width > en ? im.copyResize(g, width: en) : g;
  final cikti = im.encodeJpg(k, quality: kalite);
  File(hedef).writeAsBytesSync(cikti);
  stdout.writeln(
    '$hedef  ${k.width}x${k.height}  ${b.length} -> ${cikti.length} B',
  );
}
