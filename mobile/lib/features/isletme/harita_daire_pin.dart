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
///	· halka **3 -> 2 dp** (daha ince beyaz cerceve)
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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final Map<String, BitmapDescriptor> _onbellek = {};

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
}) async {
  final anahtar = '${ic.toARGB32()}|${kenar.toARGB32()}|$pikselOrani|'
      '${ikon?.codePoint ?? 0}';
  final hazir = _onbellek[anahtar];
  if (hazir != null) return hazir;

  // ⚠️ TURU 138 — cap 22 -> 26 (ikon icin ic alan), halka 3 -> 2 (kullanici
  //    emri), golge 3 -> 0 (kullanici emri).
  const cap = 26.0; // mantiksal (dp)
  const halka = 2.0;
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

  if (ikon != null) {
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
