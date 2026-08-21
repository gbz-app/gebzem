// ⚠️⚠️⚠️ TURU 120 — UYGULAMA IKONU HAZIRLIK ARACI (kullanici emri:
//	*"uygulama logosu telefondan, onu da YENI UYGULAMA LOGOSU ile
//	degistir"*).
//
// KAYNAK: `assets/icon/logo.png` — uygulama ici logo (512x512, SEFFAF
// koseli, MOR GRADYANLI DAIRE + ortada BEYAZ ok).
// ⚠️ Eski kaynak `kaynak.jpg` (siyah kanvas + mor kare) ARTIK KULLANILMIYOR:
//    uygulama ici logo ile ana ekrandaki ikon FARKLI iki marka gosteriyordu.
//    Tek kaynak artik `logo.png` — o degisirse ikon da bu araçla yenilenir.
//
// ═══════════ URETILEN UC DOSYA ═══════════
//
//  1) `icon.png` (1024, OPAK) — iOS + Android legacy.
//     ⚠️⚠️ Daire OLDUGU GIBI KULLANILMAZ. iOS ikona kendi "squircle"
//	maskesini uygular; icine bir DAIRE koymak kenarlarda bos bir halka
//	birakir ve ikon "cikartma yapistirilmis" gibi durur. Bunun yerine
//	dairenin **IC TEGET KARESI** kirpilir (kenar = cap/√2): sonuc
//	KOSEDEN KOSEYE gradyan + ortada ok, yani gercek bir uygulama ikonu.
//	⚠️ Ic teget karesi TAMAMEN dairenin icinde kaldigi icin cikti
//	   %100 OPAKTIR — `remove_alpha_ios` beyaz dolgu yapamaz.
//
//  2) `icon-adaptive-bg.png` (1024) — Android 8+ adaptive ARKA katman:
//     ayni kirpim ama **OK CIKARILMIS**, yani saf gradyan.
//
//  3) `icon-adaptive-fg.png` (1024, SEFFAF) — adaptive ON katman: yalniz
//     BEYAZ OK, kanvasin **%40**'i kadar.
//     ⚠️ Neden %40: adaptive ikonda launcher maskesi kanvasin yalniz ic
//	~%66'sini gosterir. Ok kanvasin %40'i ise GORUNEN alanin ~%60'i olur
//	— Apple/Google'in onerdigi glif orani.
//     ⚠️⚠️ `pubspec.yaml`da **`adaptive_icon_foreground_inset: 0`** ZORUNLU.
//	Varsayilan 16 idi ve `mipmap-anydpi-v26/ic_launcher.xml` icine
//	`<inset android:inset="16%">` yaziyordu; bu, KENDI hesapladigimiz
//	oranin USTUNE ikinci bir kucultme uyguluyor ve ok kanvasin
//	%40 x 0.68 = **%27**'sine dusuyordu (ana ekranda minicik ikon).
//
// KULLANIM: `dart run tool/ikon_uret.dart`
//    sonra: `dart run flutter_launcher_icons`
//    ⚠️ Ardindan `mobile/ios/Runner.xcodeproj/project.pbxproj` icindeki
//       `GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` bozulmasini
//       `git checkout` ile geri al (arac hatasi, CLAUDE.md'de yazili).
//
// ⚠️⚠️⚠️ **FAIL-CLOSED**: her kapi basarisiz oldugunda `exitCode = 1` ve
//	**HICBIR DOSYA YAZILMAZ**. `logo_uret.dart` ilk yaziminda uyari basip
//	bozuk dosyayi YINE DE yaziyordu (fail-open) ve hata sessizce sahaya
//	cikacakti; o ders burada bastan uygulandi.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _kaynakYol = 'assets/icon/logo.png';
const _ikonYol = 'assets/icon/icon.png';
const _bgYol = 'assets/icon/icon-adaptive-bg.png';
const _fgYol = 'assets/icon/icon-adaptive-fg.png';

/// Cikti kanvasi.
const _boy = 1024;

/// Adaptive on katmanda okun kanvasa orani (bkz. dosya serhi).
const _okOrani = 0.40;

void hata(String m) {
  stderr.writeln('HATA: $m');
  exitCode = 1;
}

void main() {
  // ── KAPI 1: dogru dizinde miyiz ──
  if (!File('pubspec.yaml').existsSync()) {
    hata('`mobile/` dizininden calistir (pubspec.yaml bulunamadi).');
    return;
  }
  final kaynakDosya = File(_kaynakYol);
  if (!kaynakDosya.existsSync()) {
    hata('kaynak yok: $_kaynakYol');
    return;
  }
  final kaynak = img.decodeImage(kaynakDosya.readAsBytesSync());
  if (kaynak == null) {
    hata('kaynak cozulemedi: $_kaynakYol');
    return;
  }
  if (kaynak.width != kaynak.height) {
    hata('kaynak KARE degil: ${kaynak.width}x${kaynak.height}');
    return;
  }
  if (kaynak.numChannels < 4) {
    hata('kaynakta ALFA KANALI yok (kanal=${kaynak.numChannels}) — '
        'daire kirpimi dogrulanamaz.');
    return;
  }

  final n = kaynak.width;

  // ── KAPI 2: gorsel gercekten bir DAIRE mi ──
  // ⚠️ Kirpim gecerliligi buna BAGLI: ic teget karesi ancak sekil daire ise
  //    tamamen opak kalir. Kare bir logoda bu arac YANLIS is yapardi.
  var saydam = 0;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      if (kaynak.getPixel(x, y).a < 8) saydam++;
    }
  }
  final saydamYuzde = saydam * 100.0 / (n * n);
  const beklenen = 21.46; // 1 - pi/4
  if ((saydamYuzde - beklenen).abs() > 3.5) {
    hata('kaynak DAIRE gorunmuyor: saydam oran %${saydamYuzde.toStringAsFixed(2)} '
        '(beklenen ~%$beklenen). Ic teget kirpimi gecersiz olur.');
    return;
  }

  // ── 1) IC TEGET KARESI ──
  // Kenar = cap / sqrt(2); kutu tamamen dairenin icinde kalir.
  final kenar = (n / math.sqrt2).floor();
  final x0 = ((n - kenar) / 2).round();
  final kare = img.copyCrop(kaynak, x: x0, y: x0, width: kenar, height: kenar);

  // ── KAPI 3: kirpim GERCEKTEN opak mi ──
  var kirpikSaydam = 0;
  for (var y = 0; y < kare.height; y++) {
    for (var x = 0; x < kare.width; x++) {
      if (kare.getPixel(x, y).a < 250) kirpikSaydam++;
    }
  }
  if (kirpikSaydam > 0) {
    hata('ic teget kirpiminda $kirpikSaydam SAYDAM piksel var — '
        'iOS ikonu seffaf kose uretirdi.');
    return;
  }

  // ── 2) SATIR BAZLI ZEMIN RENGI (gradyan dikey) ──
  // ⚠️ Ok, zeminden **satir zeminine gore** ayristirilir: gradyan yalnizca
  //    y ile degistigi icin her satirin kendi zemin rengi vardir. Sabit bir
  //    esikle ("beyaza yakin") ayristirmak, gradyanin ACIK ALT UCUNDA
  //    (lavanta, luminans ~182) yanlis pozitif verirdi.
  final zemin = List<List<int>>.generate(kare.height, (_) => [0, 0, 0]);
  for (var y = 0; y < kare.height; y++) {
    // Satirin SOL ve SAG uclarindan ornek al (ok daima ORTADA).
    final r = <int>[], g = <int>[], b = <int>[];
    for (var k = 0; k < 12; k++) {
      for (final x in [k, kare.width - 1 - k]) {
        final p = kare.getPixel(x, y);
        r.add(p.r.toInt());
        g.add(p.g.toInt());
        b.add(p.b.toInt());
      }
    }
    r.sort();
    g.sort();
    b.sort();
    zemin[y] = [r[r.length ~/ 2], g[g.length ~/ 2], b[b.length ~/ 2]];
  }

  // ── 3) OK MASKESI (en kucuk kareler ile alfa) ──
  // P = a*BEYAZ + (1-a)*ZEMIN  ->  a = Σ(255-Z)(P-Z) / Σ(255-Z)²
  // ⚠️ Kanal basina AYRI hesaplayip ortalamak GURULTULU olurdu: mavi
  //    kanalda (255 - 217) = 38 gibi kucuk bir bolen, tek piksellik bir
  //    sapmayi buyutur. Agirlikli (en kucuk kareler) cozum bunu onler.
  final maske = img.Image(
    width: kare.width,
    height: kare.height,
    numChannels: 4,
  );
  var okPiksel = 0;
  var minX = kare.width, minY = kare.height, maxX = -1, maxY = -1;
  for (var y = 0; y < kare.height; y++) {
    final z = zemin[y];
    var pay = 0.0, bolen = 0.0;
    for (var c = 0; c < 3; c++) {
      bolen += (255 - z[c]) * (255 - z[c]).toDouble();
    }
    if (bolen < 1) continue; // zemin zaten beyaz — olamaz ama korunalim
    for (var x = 0; x < kare.width; x++) {
      final p = kare.getPixel(x, y);
      final pk = [p.r.toInt(), p.g.toInt(), p.b.toInt()];
      pay = 0;
      for (var c = 0; c < 3; c++) {
        pay += (255 - z[c]) * (pk[c] - z[c]).toDouble();
      }
      var a = pay / bolen;
      if (a < 0.06) a = 0; // gradyan gurultusu
      if (a > 1) a = 1;
      maske.setPixelRgba(x, y, 255, 255, 255, (a * 255).round());
      if (a > 0.5) {
        okPiksel++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  // ── KAPI 4: ok makul bir alan kapliyor mu ──
  final okYuzde = okPiksel * 100.0 / (kare.width * kare.height);
  if (okYuzde < 4 || okYuzde > 45) {
    hata('ok maskesi makul degil: kirpimin %${okYuzde.toStringAsFixed(1)}i. '
        'Kaynak degistiyse ayristirma varsayimi (beyaz ok / renkli zemin) '
        'gecersiz olabilir.');
    return;
  }
  final okEn = maxX - minX + 1;
  final okBoy = maxY - minY + 1;
  final okKenar = math.max(okEn, okBoy);
  if (okKenar < kare.width * 0.25 || okKenar > kare.width * 0.85) {
    hata('ok sinir kutusu makul degil: ${okEn}x$okBoy (kirpim ${kare.width}).');
    return;
  }

  // ── 4) CIKTI: icon.png (opak, ok DAHIL) ──
  final ikon = img.copyResize(
    kare,
    width: _boy,
    height: _boy,
    interpolation: img.Interpolation.cubic,
  );
  File(_ikonYol).writeAsBytesSync(img.encodePng(ikon));

  // ── 5) CIKTI: adaptive ARKA (ok CIKARILMIS saf gradyan) ──
  // ⚠️ Ok "silinmez", her piksel KENDI SATIRININ zemin rengiyle DOLDURULUR:
  //    boylece gradyan kesintisiz kalir ve maskenin kenarinda hale olusmaz.
  final bg = img.Image(width: kare.width, height: kare.height, numChannels: 4);
  for (var y = 0; y < kare.height; y++) {
    final z = zemin[y];
    for (var x = 0; x < kare.width; x++) {
      bg.setPixelRgba(x, y, z[0], z[1], z[2], 255);
    }
  }
  File(_bgYol).writeAsBytesSync(
    img.encodePng(
      img.copyResize(
        bg,
        width: _boy,
        height: _boy,
        interpolation: img.Interpolation.cubic,
      ),
    ),
  );

  // ── 6) CIKTI: adaptive ON (yalniz beyaz ok, seffaf kanvas) ──
  final okKirpik = img.copyCrop(
    maske,
    x: minX,
    y: minY,
    width: okEn,
    height: okBoy,
  );
  final hedef = (_boy * _okOrani).round();
  final olcek = hedef / okKenar;
  final yeniEn = (okEn * olcek).round();
  final yeniBoy = (okBoy * olcek).round();
  final okOlcekli = img.copyResize(
    okKirpik,
    width: yeniEn,
    height: yeniBoy,
    interpolation: img.Interpolation.cubic,
  );
  final fg = img.Image(width: _boy, height: _boy, numChannels: 4); // seffaf
  img.compositeImage(
    fg,
    okOlcekli,
    dstX: (_boy - yeniEn) ~/ 2,
    dstY: (_boy - yeniBoy) ~/ 2,
  );
  File(_fgYol).writeAsBytesSync(img.encodePng(fg));

  stdout
    ..writeln('kaynak      : $_kaynakYol (${n}x$n, saydam '
        '%${saydamYuzde.toStringAsFixed(2)})')
    ..writeln('ic teget    : ${kare.width}x${kare.height} @($x0,$x0) — '
        'saydam piksel 0')
    ..writeln('ok maskesi  : ${okEn}x$okBoy '
        '(kirpimin %${okYuzde.toStringAsFixed(1)}i)')
    ..writeln('yazildi     : $_ikonYol  ($_boy, opak)')
    ..writeln('yazildi     : $_bgYol  ($_boy, saf gradyan)')
    ..writeln('yazildi     : $_fgYol  ($_boy, ok %'
        '${(_okOrani * 100).round()})')
    ..writeln('SIRADAKI    : dart run flutter_launcher_icons');
}
