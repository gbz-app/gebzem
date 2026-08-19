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
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final Map<String, BitmapDescriptor> _onbellek = {};

/// Daire isaret uretir. [kenar] ACIK bir renk olmalidir.
///
/// ⚠️ Kenarlik ZORUNLU: harita zemini her renkte olabilir (yol beyaz, park
///    yesil, su mavi). Acik bir halka isareti her zeminde ayirir.
/// ⚠️ Golge de cizilir — halka tek basina acik zeminde kayboluyordu.
Future<BitmapDescriptor> daireIsaret({
  required Color ic,
  required Color kenar,
  required double pikselOrani,
}) async {
  final anahtar = '${ic.toARGB32()}|${kenar.toARGB32()}|$pikselOrani';
  final hazir = _onbellek[anahtar];
  if (hazir != null) return hazir;

  const cap = 22.0; // mantiksal (dp)
  const halka = 3.0;
  const golge = 3.0;
  const tamDp = cap + halka * 2 + golge * 2;

  final px = (tamDp * pikselOrani).ceilToDouble();
  final kayit = ui.PictureRecorder();
  final tuval = Canvas(kayit);
  final merkez = Offset(px / 2, px / 2);
  final yaricap = (cap / 2) * pikselOrani;
  final halkaPx = halka * pikselOrani;

  tuval.drawCircle(
    merkez.translate(0, pikselOrani),
    yaricap + halkaPx,
    Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * pikselOrani),
  );
  tuval.drawCircle(merkez, yaricap + halkaPx, Paint()..color = kenar);
  tuval.drawCircle(merkez, yaricap, Paint()..color = ic);

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
