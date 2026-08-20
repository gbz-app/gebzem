// UYGULAMA ICI LOGO HAZIRLIK ARACI
//
// ⚠️ BU ARAC `ikon_uret.dart` ILE KARISTIRILMAMALI:
//	· `ikon_uret.dart` -> UYGULAMA IKONU (telefonun ana ekranindaki kare
//	  tile; `icon.png` + `icon-adaptive-fg.png`, sonra flutter_launcher_icons)
//	· `logo_uret.dart` -> UYGULAMA ICINDEKI LOGO (`assets/icon/logo.png`),
//	  yani alt menunun ortasindaki DAIRE (`alt_menu.dart` -> `_logo`).
//	Ikisi AYRI gorsellerdir ve ayri degisir.
//
// Kullanim (calisma dizini `mobile/`):
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
//	ile cizer. Yani kare gorsel ic kutuya (`kAltMenuLogoIcCap`) oturur ve
//	DAIRESEL kirpilir. Kaynaktaki daire kare kanvasa IC TEGET degilse
//	(kenarlarda saydam dolgu varsa) `cover` o saydam kenari da cizer ve
//	arkadaki GRADIENT HALKA gorunur: halka anormal KALIN, isaret KUCUK
//	gorunur — turu 96m'de tam bu yasandi (*"logonun koseleri sikintili"*).
//
// ⚠️⚠️⚠️ **BU ARAC FAIL-CLOSED'DIR: sozlesme saglanmazsa DOSYA YAZILMAZ.**
//	Turu 116 denetimi ilk yazimda su kusuru buldu: uyari yalnizca `stderr`e
//	yaziliyor, `exitCode` SET EDILMIYOR ve akis devam edip **bozuk logoyu
//	YINE DE YAZIYORDU** (surec 0 ile bitiyordu). Kardes dallar (kaynak yok
//	/ kare degil) `exitCode = 1; return;` yapiyordu — **asimetrinin kendisi
//	hataydi**: bu projede "uyaran ama engellemeyen kapi" defalarca sessizce
//	gecildi. ⚠️ YAPMA: uyari dallarini `return`suz birakma.
//
// ⚠️ ALFA KORUNUR: kose saydamligi gorselin kendi tasarimidir; opaklastirmak
//    siyah cubukta kare bir leke birakirdi.
import 'dart:io';

import 'package:image/image.dart' as img;

/// Uretilen dosyanin kenari (piksel).
///
/// ⚠️ 512 secimi OLCUME dayali: alt menudeki logonun DIS capi
///    `kAltMenuLogoCap = 58 dp`; en yuksek piksel yogunlugunda (dpr 4)
///    gereken 58*4 = **232 px**. 512, ~2,2 kat pay birakir — yani her
///    cihazda keskin, gereksiz buyuk degil.
/// ⚠️ Bu sayi bir zamanlar serhte "52 dp x 4" diye gerekcelendirilmisti;
///    52 dp turu 112'de 58'e cikti ve 52*4 = 208 zaten 512 ETMIYORDU.
///    Gerekce duzeltildi, deger DOGRUYDU.
const _hedefBoy = 512;

/// Mukemmel ic-teget dairenin saydam piksel orani: 1 - pi/4.
const _teorikSaydam = 21.46;

/// Saydam oraninda kabul edilen sapma (puan).
///
/// ⚠️⚠️ BU KONTROL "dolgu = 0"IN YAKALAYAMADIGINI YAKALAR: koseleri
///	yuvarlatilmis bir KARE de dort kenara deger (dolgu 0) ama saydam orani
///	%21 degil ~%5 olur. Yani tek basina dolgu olcumu, "daire mi" sorusunu
///	CEVAPLAMAZ. Iki olcut BIRLIKTE cevaplar.
const _saydamPay = 3.5;

void main(List<String> arg) {
  // ⚠️ CWD KAPISI EN BASTA: yanlis dizinden calistirilirsa hata, agir piksel
  //    taramasindan SONRA degil, HEMEN ve SEBEBIYLE ciksin.
  if (!Directory('assets/icon').existsSync()) {
    stderr.writeln('HATA: `assets/icon/` yok. Bu araci `mobile/` dizininden '
        'calistir:  dart run tool/logo_uret.dart <kaynak>');
    exitCode = 1;
    return;
  }

  final yol = arg.isNotEmpty ? arg.first : '../logo2.png';
  final dosya = File(yol);
  if (!dosya.existsSync()) {
    stderr.writeln('HATA: kaynak bulunamadi: $yol');
    exitCode = 1;
    return;
  }

  // ⚠️ `!` YERINE ACIK KONTROL: cozulemeyen bir dosyada `!` yalnizca
  //    "Null check operator used on a null value" yigin izi verirdi.
  final kaynak = img.decodeImage(dosya.readAsBytesSync());
  if (kaynak == null) {
    stderr.writeln('HATA: gorsel cozulemedi (bozuk ya da desteklenmeyen '
        'bicim): $yol');
    exitCode = 1;
    return;
  }
  stdout.writeln('kaynak : ${kaynak.width}x${kaynak.height}  '
      '(${dosya.lengthSync()} B)');

  if (kaynak.width != kaynak.height) {
    stderr.writeln('HATA: kaynak KARE DEGIL (${kaynak.width}x${kaynak.height})'
        ' — daire kutuya oturmaz.');
    exitCode = 1;
    return;
  }

  // ⚠️⚠️ ALFA KANALI ZORUNLU (turu 116 denetimi). `image` paketi
  //	`numChannels <= 3` olan gorsellerde `pixel.a` icin **literal 255**
  //	dondurur. Yani alfasiz bir kaynakta (JPEG — `decodeImage` bicimi
  //	KOKLADIGI icin sessizce kabul edilir — ya da alfasiz PNG) asagidaki
  //	sinir kutusu DAIMA tum kareyi kapsar, dolgu DAIMA 0 cikar ve uyari
  //	**YAPISAL OLARAK HIC ATESLEYEMEZ**.
  //	Yani kapi acik gorunur ama hicbir sey olcmez — bu projedeki
  //	"muhafiz YESIL ama olcmesi gerekeni OLCMUYOR" sinifi.
  if (kaynak.numChannels < 4) {
    stderr.writeln('HATA: kaynakta ALFA KANALI YOK '
        '(${kaynak.numChannels} kanal — JPEG mi?). Dairenin kenarlara degip '
        'degmedigi OLCULEMEZ. Saydam koseli bir PNG ver.');
    exitCode = 1;
    return;
  }

  // ── Alfa sinir kutusu + saydam oran ──
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
  if (maxX < 0) {
    stderr.writeln('HATA: kaynak TAMAMEN SAYDAM.');
    exitCode = 1;
    return;
  }

  final dolguSol = minX;
  final dolguUst = minY;
  final dolguSag = kaynak.width - 1 - maxX;
  final dolguAlt = kaynak.height - 1 - maxY;
  final oran = saydam / (kaynak.width * kaynak.height) * 100;
  stdout.writeln('kenar dolgusu: sol=$dolguSol ust=$dolguUst '
      'sag=$dolguSag alt=$dolguAlt');
  stdout.writeln('saydam piksel: %${oran.toStringAsFixed(1)}  '
      '(ic-teget daire = %$_teorikSaydam)');

  final enBuyukDolgu = [dolguSol, dolguUst, dolguSag, dolguAlt]
      .reduce((a, b) => a > b ? a : b);
  // ⚠️ Esik kaynak boyunun %1'i: birkac piksellik anti-alias yumusamasi
  //    dolgu sayilmamali, gercek bosluk sayilmalidir.
  final esik = kaynak.width ~/ 100;
  if (enBuyukDolgu > esik) {
    stderr.writeln('HATA: kaynakta ${enBuyukDolgu}px KENAR BOSLUGU var '
        '(esik $esik px). Daire alt menudeki kutuyu TAM DOLDURMAZ; cevresinde '
        'bosluk olusur ve GRADIENT HALKA kalin gorunur (turu 96m hatasi).\n'
        'DOSYA YAZILMADI.');
    exitCode = 1;
    return;
  }
  if ((oran - _teorikSaydam).abs() > _saydamPay) {
    stderr.writeln('HATA: saydam oran %${oran.toStringAsFixed(1)} — '
        'beklenen %$_teorikSaydam ±$_saydamPay. Gorsel bir TAM DAIRE '
        'olmayabilir (opak kare ya da yuvarlatilmis kare?).\n'
        'DOSYA YAZILMADI.');
    exitCode = 1;
    return;
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
  stdout.writeln('⚠️ Muhafiz: `flutter test test/logo_varlik_test.dart`');
}
