/// ⚠️⚠️⚠️ TURU 115 — HARITA ISARETI **DAIRE** (kullanici emri: *"konumdaki
///	pinler DAIRE seklinde yap, border ACIK RENKLER kullan"*).
///
/// Google Maps'in varsayilan isareti kirmizi bir DAMLA. Daire istendigi icin
/// `google_maps_flutter`a bir `BitmapDescriptor` vermek gerekiyor — yani
/// gorseli BIZ ciziyoruz.
///
/// ⚠️ Bu dosya `harita_pin.dart` ile KARISTIRILMAMALI: o dosya "haritadan pin
///    secme EKRANI"dir (turu 96g), burasi yalnizca ISARET GORSELI uretir.
///    ⚠️ Ilk denemede `harita_pin.dart`in UZERINE yazildi ve
///       `haritadanPinSec` ile `haritadanSecilebilir` kayboldu; `konum_secici`
///       derlenmedi. **DERS: var olan bir dosyayi OKUMADAN ustune yazma.**
///
/// ═══════════ NEDEN ASSET DEGIL, CALISMA ANINDA CIZIM ═══════════
///
/// Bir PNG asset'i (a) her ekran yogunlugu icin ayri dosya, (b) renk degisince
/// yeniden uretim, (c) secili/normal iki hal icin iki dosya ister. `dart:ui`
/// ile cizmek bunlarin hicbirini gerektirmez ve TEMA RENGINI dogrudan kullanir.
///
/// ⚠️⚠️ **SONUC ONBELLEKLENIR**: `BitmapDescriptor` uretimi PNG kodlamasi
///	yapar. Onbelleksiz her cizimde 60 isaret icin 60 kodlama olur ve harita
///	gorunur sekilde takilir.
/// ⚠️ `devicePixelRatio` ile carpilir; carpilmazsa yuksek yogunluklu ekranda
///    isaret BULANIK cikar (turu 91 `memCacheWidth` dersinin aynisi).
///
/// ═══════════ ⚠️⚠️⚠️ TURU 138 — YENIDEN CIZILDI (kullanici emri) ═══════════
///
///	*"haritadaki pinlerde BEYAZLIGI 1 TIK INCELT, arkadaki GOLGEYI KALDIR,
///	renkler daha ACIK MODERN olsun ve ICINE ICON koy"*
///
///	· halka **3 -> 2 -> 1.5 dp** (kullanici IKI KEZ inceltti)
///	· **GOLGE KALDIRILDI** (`drawCircle` + `MaskFilter.blur` bloku SILINDI)
///	· ic renge **ikon** cizilir (`ikon` parametresi)
///	· cap 22 -> **26 dp**: ikonun okunabilmesi icin ic alan gerekiyordu.
///	  ⚠️ Buyutmenin bedeli var — 60 pin yan yana geldiginde harita
///	     kalabaliklasir; 26 dp bu iki kaygi arasindaki denge.
/// ⚠️ **GOLGESIZ HALKA ACIK ZEMINDE KAYBOLABILIR**; eski serh bunu
///	soyluyordu. Telafi: halka **TAM BEYAZ** ve ic renk artik daha ACIK,
///	yani halka ile ic arasindaki kontrast korunuyor. Kullanici golgesiz
///	gorunumu ACIKCA istedi — karar ONUN.
/// ⚠️ YAPMA: golgeyi geri koyup halkayi da inceltme; ikisi birlikte pini
///    bulaniklastirir.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final Map<String, BitmapDescriptor> _onbellek = {};

/// ⚠️⚠️⚠️ TURU 155 — **YON KONISI** (kullanici emri: *"Konum
///	Yandex'teki gibi DAIRE + YON OKU olsun, telefonu oynattikca yonu
///	gostersin, cevresinde hafif beyaz daire var bunun gibi olsun"*).
///
/// ⚠️⚠️ **AYRI BIR MARKER OLARAK CIZILIR, PUCK'IN ICINE DEGIL.**
///	Sebep: yon `Marker.rotation` ile veriliyor ve rotation MARKERIN
///	TAMAMINI dondurur. Koni puck ile ayni bitmap'te olsaydi,
///	kullanici donduğunde **PROFIL FOTOGRAFI DA TERS DONERDI**.
///	Iki marker: alta donen koni, uste sabit fotograf.
///
/// ⚠️⚠️ Bitmap MERKEZI puck'in merkezidir ve koni YUKARI (0°) bakar;
///	`Marker(rotation: yon, anchor: Offset(0.5, 0.5))` bu merkez
///	etrafinda dondurur. Koni bitmap'in kenarina cizilseydi donerken
///	puck'tan KOPARDI.
///
/// ⚠️ `flat: true` ZORUNLU: marker haritaya YATIK cizilir ve harita
///    dondurulurse (bearing) koni de doner. `false` olsaydi koni ekrana
///    sabit kalir, harita donunce YANLIS yonu gosterirdi.
/// ⚠️ Koni SAYDAM bir gradyan degil DUZ bir ucgendir: `dart:ui`
///    gradyanlari her uretimde yeniden hesaplanir ve kazanci gorunmez.
Future<BitmapDescriptor> yonKonisi({
  required Color renk,
  required double pikselOrani,
}) async {
  final anahtar = 'yon|${renk.toARGB32()}|$pikselOrani';
  final hazir = _onbellek[anahtar];
  if (hazir != null) return hazir;

  // ⚠️ Tuval puck'tan (29 dp) BUYUK olmak zorunda: koni disarida.
  const tamDp = 58.0;
  const merkez = tamDp / 2;
  // Koninin ic ve dis yaricapi (puck kenari ~14.5 dp).
  const icR = 15.0;
  const disR = 27.0;
  // Koninin yarim acisi (radyan) — ~26°, Yandex'e yakin.
  const yariAci = 0.45;

  final px = (tamDp * pikselOrani).ceilToDouble();
  final kayit = ui.PictureRecorder();
  final tuval = Canvas(kayit);
  tuval.scale(pikselOrani);

  final yol = Path()
    ..moveTo(merkez, merkez - disR)
    ..lineTo(merkez + icR * math.sin(yariAci),
        merkez - icR * math.cos(yariAci))
    ..lineTo(merkez - icR * math.sin(yariAci),
        merkez - icR * math.cos(yariAci))
    ..close();

  // Beyaz kontur: koni koyu zeminde de acik zeminde de gorunmeli.
  tuval.drawPath(
    yol,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true,
  );
  tuval.drawPath(
    yol,
    Paint()
      ..color = renk
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  final resim = await kayit.endRecording().toImage(px.toInt(), px.toInt());
  final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
  resim.dispose();
  final b = BitmapDescriptor.bytes(bayt!.buffer.asUint8List(),
      width: tamDp, height: tamDp);
  _onbellek[anahtar] = b;
  return b;
}

/// Daire isaret uretir. [kenar] ACIK bir renk olmalidir.
///
/// ⚠️ Kenarlik ZORUNLU: harita zemini her renkte olabilir (yol beyaz, park
///    yesil, su mavi). Acik bir halka isareti her zeminde ayirir.
/// ⚠️ [ikon] verilirse dairenin ICINE cizilir. Ikon bir FONT glifi oldugu
///    icin `TextPainter` ile ciziliyor — `Icon` widget'i `dart:ui` tuvaline
///    cizilemez.
///    ⚠️⚠️ `fontFamily` VE `fontPackage` BIRLIKTE verilmek ZORUNDA: Lucide
///       ikonlari bir PAKETTEN gelir ve paket adi yazilmazsa glif
///       BULUNAMAZ, yerine "tofu" (bos kare) cizilir.
Future<BitmapDescriptor> daireIsaret({
  required Color ic,
  required Color kenar,
  required double pikselOrani,
  IconData? ikon,
  ui.Image? foto,
  String fotoAnahtar = '',
}) async {
  // ⚠️⚠️ ONBELLEK ANAHTARI FOTOGRAFI DA ICERMEK ZORUNDA: kullanici profil
  //	fotografini degistirdiginde ayni anahtar ESKI pini dondururdu.
  //	`ui.Image`in kendisi anahtar olamaz (her cozumde yeni nesne) — cagiran
  //	KARARLI bir kimlik verir (bkz. `fotoAnahtar`).
  final anahtar = '${ic.toARGB32()}|${kenar.toARGB32()}|$pikselOrani|'
      '${ikon?.codePoint ?? 0}|$fotoAnahtar';
  final hazir = _onbellek[anahtar];
  if (hazir != null) return hazir;

  // ⚠️ TURU 138 — cap 22 -> 26 (ikon icin ic alan), halka 3 -> 2 (kullanici
  //    emri), golge 3 -> 0 (kullanici emri).
  const cap = 26.0; // mantiksal (dp)
  // ⚠️ TURU 139 — 2.0 -> 1.5 (kullanici: *"beyaz border 1 tik daha incelt"*).
  const halka = 1.5;
  const tamDp = cap + halka * 2;

  final px = (tamDp * pikselOrani).ceilToDouble();
  final kayit = ui.PictureRecorder();
  final tuval = Canvas(kayit);
  final merkez = Offset(px / 2, px / 2);
  final yaricap = (cap / 2) * pikselOrani;
  final halkaPx = halka * pikselOrani;

  // ⚠️ GOLGE YOK (turu 138, kullanici emri). Onceki surumde burada
  //    `MaskFilter.blur` ile bir golge dairesi vardi.
  tuval.drawCircle(merkez, yaricap + halkaPx, Paint()..color = kenar);
  tuval.drawCircle(merkez, yaricap, Paint()..color = ic);

  // ⚠️⚠️⚠️ TURU 139 — **KENDI KONUMDA PROFIL FOTOGRAFI** (kullanici emri:
  //	*"bizim kendi navigasyonumuz yerine de resmimiz olsun, mevcut
  //	profildeki resmi koy"*).
  //
  // ⚠️ `clipPath` ZORUNLU: fotograf KARE gelir, kirpilmazsa dairenin
  //    disina tasar ve halkayi ORTER.
  // ⚠️ `BoxFit.cover` mantigi ELLE: kaynagin KISA kenarindan kare bir
  //    parca alinir. `drawImageRect`e tam gorseli verseydik dikdortgen
  //    avatar EZILIRDI (yuz sikismis gorunur).
  // ⚠️ Fotograf varsa IKON CIZILMEZ (asagidaki `ikon != null && foto == null`):
  //    ikisi ust uste binerdi.
  if (foto != null) {
    tuval.save();
    tuval.clipPath(Path()..addOval(Rect.fromCircle(center: merkez, radius: yaricap)));
    final kisa = foto.width < foto.height ? foto.width : foto.height;
    final kx = (foto.width - kisa) / 2;
    final ky = (foto.height - kisa) / 2;
    tuval.drawImageRect(
      foto,
      Rect.fromLTWH(kx.toDouble(), ky.toDouble(), kisa.toDouble(), kisa.toDouble()),
      Rect.fromCircle(center: merkez, radius: yaricap),
      Paint()..filterQuality = FilterQuality.medium,
    );
    tuval.restore();
  }

  if (ikon != null && foto == null) {
    // ⚠️ Ikon boyu capin ~%54'u: daha buyugu halkaya deger, daha kucugu
    //    okunmaz. Deger OLCULEREK secildi (26 dp pinde 14 dp glif).
    final boy = cap * 0.54 * pikselOrani;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(ikon.codePoint),
        style: TextStyle(
          fontSize: boy,
          fontFamily: ikon.fontFamily,
          package: ikon.fontPackage,
          color: kenar,
          // ⚠️ `height: 1` ZORUNLU: font metrikleri glifin uzerine bosluk
          //    ekliyor ve ikon dairenin ICINDE asagi kayiyordu.
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      tuval,
      Offset(merkez.dx - tp.width / 2, merkez.dy - tp.height / 2),
    );
  }

  final resim = await kayit.endRecording().toImage(px.toInt(), px.toInt());
  final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
  resim.dispose();
  // ⚠️ Kodlama basarisiz olursa VARSAYILAN isarete duseriz: isaretsiz bir
  //    harita, kirmizi damladan KOTUDUR.
  if (bayt == null) return BitmapDescriptor.defaultMarker;

  final d = BitmapDescriptor.bytes(
    bayt.buffer.asUint8List(),
    // ⚠️ `width` MANTIKSAL olcudur: verilmezse eklenti ham pikseli dp sanar ve
    //    isaret yuksek yogunluklu ekranda DEV cikar.
    width: tamDp,
  );
  _onbellek[anahtar] = d;
  return d;
}
