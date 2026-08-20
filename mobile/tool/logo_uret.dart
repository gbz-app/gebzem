// UYGULAMA ICI LOGO HAZIRLIK ARACI
//
// ⚠️ BU ARAC `ikon_uret.dart` ILE KARISTIRILMAMALI:
//	· `ikon_uret.dart` -> UYGULAMA IKONU (telefonun ana ekranindaki kare
//	  tile; `icon.png` + `icon-adaptive-fg.png`, sonra flutter_launcher_icons)
//	· `logo_uret.dart` -> UYGULAMA ICINDEKI LOGO (`assets/icon/logo.png`),
//	  yani alt menunun ortasindaki DAIRE (`alt_menu.dart:497`).
//	Ikisi AYRI gorsellerdir ve ayri degisir.
//
// Kullanim:
//	dart run tool/logo_uret.dart ../logo2.png
//
// ⚠️⚠️ NEDEN ELLE `copyResize` DEGIL DE BIR ARAC: kaynak 1600x1600, hedef
//	512x512. Elle "kucuk bir PNG kaydet" demek, her seferinde farkli bir
//	yeniden orneklemeyle FARKLI bir dosya uretmek demektir. Arac, logonun
//	her degistiginde AYNI donusumden gecmesini garanti eder ve olcumleri
//	basar — boylece "daire kutuyu tam dolduruyor mu" sorusu TAHMIN degil
//	OLCUM olur.
//
// ⚠️⚠️⚠️ **KRITIK SOZLESME — DAIRE KENARLARA DEGMELI.**
//	`alt_menu.dart` logoyu `BoxDecoration(shape: circle)` + `BoxFit.cover`
//	ile cizer. Yani kare gorsel 52 dp'lik kutuya oturur ve DAIRESEL
//	kirpilir. Kaynaktaki daire kare kanvasa IC TEGET degilse (kenarlarda
//	saydam dolgu varsa) ekranda logonun cevresinde BOSLUK HALKASI olusur ve
//	logo kardeslerinden kucuk gorunur — turu 96m'de tam bu yasandi
//	(*"logonun koseleri sikintili"*).
//	Bu yuzden arac kenar dolgusunu OLCER ve sifir degilse **UYARIR**.
//
// ⚠️ ALFA KORUNUR: kose saydamligi gorselin kendi tasarimidir; opaklastirmak
//    siyah cubukta kare bir leke birakirdi.
import 'dart:io';

import 'package:image/image.dart' as img;

const _hedefBoy = 512; // alt_menu 52 dp x en fazla 4x piksel yogunlugu

void main(List<String> arg) {
  final yol = arg.isNotEmpty ? arg.first : '../logo2.png';
  final dosya = File(yol);
  if (!dosya.existsSync()) {
    stderr.writeln('kaynak bulunamadi: $yol');
    exitCode = 1;
    return;
  }

  final kaynak = img.decodeImage(dosya.readAsBytesSync())!;
  stdout.writeln('kaynak : ${kaynak.width}x${kaynak.height}  '
      '(${dosya.lengthSync()} B)');

  if (kaynak.width != kaynak.height) {
    stderr.writeln('⚠️ KAYNAK KARE DEGIL — daire kutuya oturmaz.');
    exitCode = 1;
    return;
  }

  // ── Alfa sinir kutusu: daire gercekten kenarlara degiyor mu? ──
  var minX = kaynak.width, minY = kaynak.height, maxX = -1, maxY = -1;
  var saydam = 0;
  for (var y = 0; y < kaynak.height; y++) {
    for (var x = 0; x < kaynak.width; x++) {
      if (kaynak.getPixel(x, y).a < 8) {
        saydam++;
        continue;
      }
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  final dolguSol = minX;
  final dolguUst = minY;
  final dolguSag = kaynak.width - 1 - maxX;
  final dolguAlt = kaynak.height - 1 - maxY;
  stdout.writeln('kenar dolgusu: sol=$dolguSol ust=$dolguUst '
      'sag=$dolguSag alt=$dolguAlt');
  stdout.writeln('saydam piksel: %'
      '${(saydam / (kaynak.width * kaynak.height) * 100).toStringAsFixed(1)}');

  final enBuyukDolgu = [dolguSol, dolguUst, dolguSag, dolguAlt]
      .reduce((a, b) => a > b ? a : b);
  // ⚠️ Esik kaynak boyunun %1'i: birkac piksellik anti-alias yumusamasi
  //    dolgu sayilmamali, gercek bosluk sayilmalidir.
  final esik = kaynak.width ~/ 100;
  if (enBuyukDolgu > esik) {
    stderr.writeln('⚠️⚠️ UYARI: kaynakta ${enBuyukDolgu}px KENAR BOSLUGU var '
        '(esik $esik). Daire alt menudeki kutuyu TAM DOLDURMAZ ve cevresinde '
        'bosluk halkasi olusur (turu 96m hatasi).');
  }

  // ── 512x512 uret ──
  // ⚠️ `cubic`: `ikon_uret.dart` ile AYNI enterpolasyon. Farkli olsaydi ayni
  //    kaynaktan uretilen iki gorsel farkli keskinlikte cikardi.
  final kucuk = img.copyResize(
    kaynak,
    width: _hedefBoy,
    height: _hedefBoy,
    interpolation: img.Interpolation.cubic,
  );

  final hedef = File('assets/icon/logo.png');
  hedef.writeAsBytesSync(img.encodePng(kucuk));
  stdout.writeln('yazildi: ${hedef.path} '
      '($_hedefBoy x $_hedefBoy, ${hedef.lengthSync()} B)');
}
