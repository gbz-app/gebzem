/// ⚠️⚠️⚠️ TURU 155 — **PUSULA (CIHAZIN BAKTIGI YON).**
///
/// Kullanici emri: *"Konum yandextedki gibi daire yon oku olsun, **telefonu
/// oynattikca yonu gostersin**, cevresinde hafif beyaz daire var bunun gibi
/// olsun"*.
///
/// ═══════════ NEDEN `geolocator.Position.heading` DEGIL ═══════════
///
/// ⚠️⚠️ `Position.heading` **PUSULA DEGIL**, GPS'in *gidis yonudur* (course
///	over ground). Resmi dokuman: *"The course over ground (direction of
///	travel) in degrees."* Android altta `Location.getBearing()` — ve o da
///	acikca *"is **not related to the device orientation**"* diyor.
///
/// ⚠️⚠️ **CIHAZ DURUYORKEN GECERSIZDIR**: hiz ~0 iken GPS gidis yonu
///	uretemez; Android'de `hasBearing()` false doner ve deger **0.0** olur,
///	iOS'ta `course` **negatif** olur. Yani kullanici yerinde durup telefonu
///	cevirdiginde ok HIC DONMEZDI — tam da istenen sey.
///
/// ═══════════ NEDEN UCUNCU PARTI PAKET DEGIL ═══════════
///
/// ⚠️ `flutter_compass`: son surumu ~2 yil once, 44 acik issue ve bilinen
///    ***"Compass doesn't move on iPhone 12 or above"*** sorunu var —
///    kullanici iPhone'da test ediyor. Ayrica iOS tarafi `trueHeading` -1
///    dondugunde `magneticHeading`e DUSMUYOR (bkz. asagidaki -1 tuzagi).
/// ⚠️ `flutter_rotation_sensor` 0.4.0: `intl ^0.20.3` istiyor, Flutter SDK ise
///    `flutter_localizations` uzerinden `intl 0.20.2`'ye SABITLIYOR —
///    **cozulemiyor** (denendi, `pub get` basarisiz).
///
/// Bu yuzden pusula projenin KENDI kanal deseniyle yazildi (`GebzemPip`,
/// `TelefonDurumu` ile ayni idiom): ucuncu parti riski YOK ve iOS'un -1
/// tuzagini KENDIMIZ ele alabiliyoruz.
///
/// ═══════════ ⚠️⚠️ FAIL-SOFT: OK ASLA YALAN SOYLEMEZ ═══════════
///
/// Kanal yoksa (`MissingPluginException`), sensor yoksa ya da deger
/// gelmiyorsa akis **hicbir sey yaymaz** ve cagiran yon okunu CIZMEZ.
/// Yanlis bir yon gostermektense HIC gostermemek dogrudur.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// ⚠️⚠️ Kanal adi **NATIVE TARAFLA BIREBIR** ayni olmak zorunda
///	(`Pusula.kt` ve `AppDelegate.swift`). Turu 65b'de bir native `case`
///	YANLIS kanala yazilmis ve `MissingPluginException` `catch` tarafindan
///	yutuldugu icin ozellik **HIC CALISMAMISTI**; hata derleme zamani
///	yakalanmaz.
const String kPusulaKanali = 'gebzem/pusula';

/// Ham pusula degeri gurultuludur; kac derecelik degisim yayilsin.
///
/// ⚠️ Cok kucuk olursa ok titrer, cok buyuk olursa donus takik gorunur.
const double _esikDerece = 1.5;

/// Ustel yumusatma katsayisi (1'e yakin = daha agir/durgun).
const double _alfa = 0.82;

class PusulaServisi {
  PusulaServisi._();
  static final PusulaServisi i = PusulaServisi._();

  static const MethodChannel _kanal = MethodChannel(kPusulaKanali);

  StreamController<double>? _denetleyici;
  double? _sinS;
  double? _cosS;
  double? _sonYayilan;
  bool _kuruldu = false;

  /// Cihazin baktigi yon (derece, 0 = kuzey, saat yonu).
  ///
  /// ⚠️ Akis DINLENMEYE BASLANINCA sensor acilir, IPTAL EDILINCE kapanir —
  ///    pusulayi bosuna acik tutmak pil yakar (manyetometre ucuz olsa da
  ///    kalibrasyon rutini tepe anlarda ~6000 uW cekiyor).
  Stream<double> akis() {
    final mevcut = _denetleyici;
    if (mevcut != null && !mevcut.isClosed) return mevcut.stream;
    final d = StreamController<double>.broadcast(
      onListen: _basla,
      onCancel: _dur,
    );
    _denetleyici = d;
    return d.stream;
  }

  void _kur() {
    if (_kuruldu) return;
    _kuruldu = true;
    _kanal.setMethodCallHandler((cagri) async {
      if (cagri.method != 'yon') return null;
      final ham = cagri.arguments;
      final derece = ham is Map ? (ham['derece'] as num?)?.toDouble() : null;
      if (derece == null || derece.isNaN || derece < 0) return null;
      _yut(derece);
      return null;
    });
  }

  /// ⚠️⚠️⚠️ **ACILARI DOGRUDAN ORTALAMA/YUMUSATMA — YANLISTIR.**
  ///
  ///	358° ile 0°'i 0.5 katsayiyla ortalarsan **179°** cikar (TAM TERS YON),
  ///	oysa iki aci birbirine 2 derece uzaktir. Dogru yol: degeri **sin/cos
  ///	alanina** tasi, orada filtrele, `atan2` ile geri cevir.
  void _yut(double derece) {
    final r = derece * math.pi / 180;
    final s = math.sin(r), c = math.cos(r);
    _sinS = _sinS == null ? s : _alfa * _sinS! + (1 - _alfa) * s;
    _cosS = _cosS == null ? c : _alfa * _cosS! + (1 - _alfa) * c;
    var d = math.atan2(_sinS!, _cosS!) * 180 / math.pi;
    if (d < 0) d += 360;
    final onceki = _sonYayilan;
    // ⚠️ Fark DAIRESEL hesaplanir: 359 ile 1 arasi 2 derecedir, 358 degil.
    if (onceki != null) {
      final fark = (d - onceki).abs();
      final dairesel = fark > 180 ? 360 - fark : fark;
      if (dairesel < _esikDerece) return;
    }
    _sonYayilan = d;
    final dn = _denetleyici;
    if (dn != null && !dn.isClosed) dn.add(d);
  }

  Future<void> _basla() async {
    _kur();
    try {
      await _kanal.invokeMethod<void>('basla');
    } catch (_) {
      // ⚠️ Kanal yoksa/sensor yoksa SESSIZ: akis hicbir sey yaymaz ve
      //    cagiran yon okunu CIZMEZ (bkz. dosya basi "fail-soft").
    }
  }

  Future<void> _dur() async {
    _sinS = null;
    _cosS = null;
    _sonYayilan = null;
    try {
      await _kanal.invokeMethod<void>('dur');
    } catch (_) {
      // yok sayilir
    }
  }
}
