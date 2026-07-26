import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// FAZ-6: Android sistem PiP koprusu ('gebzem/pip' — MainActivity.kt ile birebir).
/// TEST TURU 15: artik YALNIZ arama degil CANLI YAYIN da PiP kullanabiliyor. Bu yuzden:
///  - Kanal handler'i TEK yerde (burada) kurulur; arama ve yayin ekranlari geri cagirmalarini
///    (callback) kaydeder. (Eskiden ActiveCallController kanali kapiyordu; ikinci dinleyici
///    sessizce yok sayiliyordu.)
///  - `pipModu` herkesin dinleyebilecegi ValueNotifier (yayin ekranlari PiP'te SADE video cizer).
///  - `pipIzinli` SAHIPLIK ister ('arama' | 'yayin'): baska sahibin gec kalan `false` cagrisi
///    aktif sahibin PiP iznini KAPATAMAZ (yaris korumasi).
class PipService {
  static const _ch = MethodChannel('gebzem/pip');

  /// PiP penceresinde miyiz (Android 'pipDegisti' + iOS 'iosPipDurum'). Yayin/arama
  /// ekranlari bunu dinleyip sade gorunume gecer.
  static final ValueNotifier<bool> pipModu = ValueNotifier<bool>(false);

  /// GSM (normal telefon) aramasi var mi — TEST TURU 20. Android'de TelephonyCallback'ten
  /// gelir; true olunca Gebzem aramasi BEKLEMEYE alinir (WhatsApp davranisi).
  static final ValueNotifier<bool> gsmAramada = ValueNotifier<bool>(false);

  static bool _handlerKuruldu = false;
  static void Function(bool)? _androidDurumCb;
  static void Function(String)? _eylemCb;
  static void Function(bool)? _iosDurumCb;
  static void Function()? _iosBasarisizCb;
  static String _sahip = ''; // PiP iznini kim aldi ('arama' | 'yayin')

  static void _handlerKur() {
    if (_handlerKuruldu) return;
    _handlerKuruldu = true;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pipDegisti': // Android
          final v = call.arguments == true;
          pipModu.value = v;
          _androidDurumCb?.call(v);
        case 'pipEylem': // Android PiP penceresindeki dugmeler (mic/kapat)
          _eylemCb?.call(call.arguments as String? ?? '');
        case 'gsmDurum': // TEST TURU 20: GSM aramasi basladi/bitti
          gsmAramada.value = call.arguments == true;
        case 'iosPipDurum':
          final v = call.arguments == true;
          pipModu.value = v;
          _iosDurumCb?.call(v);
        case 'iosPipBasarisiz':
          _iosBasarisizCb?.call();
      }
      return null;
    });
  }

  /// PiP'e girilebilir mi. [sahip]: 'arama' veya 'yayin'. Kapatma yalniz SAHIBINDEN kabul
  /// edilir (arama controller'inin gec kalan false'u yayin PiP'ini kapatmasin).
  static Future<void> pipIzinli(bool izinli, {String sahip = 'arama'}) async {
    if (!Platform.isAndroid) return;
    if (izinli) {
      _sahip = sahip;
    } else {
      if (_sahip != sahip && _sahip.isNotEmpty) return; // baskasinin izni — dokunma
      _sahip = '';
    }
    try {
      await _ch.invokeMethod('setPipIzinli', izinli);
    } catch (_) {}
  }

  /// Android PiP durum/eylem geri cagirmalarini kaydet (arama controller'i).
  static void dinle(void Function(bool pipModunda) cb,
      {void Function(String eylem)? onEylem}) {
    if (!Platform.isAndroid) return;
    _handlerKur();
    _androidDurumCb = cb;
    _eylemCb = onEylem;
  }

  /// PiP dugmesinin ikonunu/etiketini guncelle (mikrofon acik mi). Android'e ozel.
  static Future<void> micDurum(bool acik) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('setMicDurum', acik);
    } catch (_) {}
  }

  /// PiP penceresindeki dugmeleri goster/gizle. CANLI YAYIN PiP'inde arama dugmeleri
  /// (mikrofon/kapat) ANLAMSIZ — yayin sahipken gizlenir.
  static Future<void> dugmeleriGoster(bool goster) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('setPipDugmeler', goster);
    } catch (_) {}
  }

  /// GSM ARAMA DINLEYICISI (test turu 20): Gebzem aramasi basladiginda ac, bitince kapat.
  /// Donus: dinlenebiliyor mu (READ_PHONE_STATE izni yoksa false -> ozellik sessizce kapali).
  static Future<bool> gsmDinle(bool ac) async {
    if (!Platform.isAndroid) return false;
    try {
      _handlerKur();
      final ok = (await _ch.invokeMethod<bool>('gsmDinle', ac)) ?? false;
      if (!ac) gsmAramada.value = false;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Arama bitti ve hala PiP penceresindeysek pencereyi kapat (WhatsApp gibi).
  static Future<void> pipKapat() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('pipKapat');
    } catch (_) {}
  }

  // ---- iOS SISTEM PiP (test turu 7) ----

  /// iOS cihaz PiP destekliyor mu (bir kez sorulur; iOS<15/desteksiz -> false).
  static Future<bool> iosPipHazirMi() async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>('iosPipHazirMi')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Video track'i icin PiP controller'i kur (auto-enter). UZAK track bulunamazsa native
  /// YEREL track'e duser (canli yayin yayincisi kendi kamerasi). Basari doner.
  static Future<bool> iosPipKur(String trackId) async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>('iosPipKur', {'trackId': trackId})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> iosPipBirak() async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod('iosPipBirak');
    } catch (_) {}
  }

  /// TEST TURU 20: PiP'i ELLE baslat (uygulama arka plana giderken). Otomatik giris telefon
  /// Ayarina + Dusuk Guc Modu'na bagli; elle baslatma AYARDAN BAGIMSIZ calisir.
  static Future<void> iosPipBaslat() async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod('iosPipBaslat');
    } catch (_) {}
  }

  /// iOS sistem PiP DURUM geri bildirimi (test turu 9): native GebzemPip delegate
  /// 'iosPipDurum' (true=basladi/false=durdu) + 'iosPipBasarisiz' (baslatilamadi) gonderir.
  static void iosDinle(
      {required void Function(bool pipAktif) onDurum,
      required void Function() onBasarisiz}) {
    if (!Platform.isIOS) return;
    _handlerKur();
    _iosDurumCb = onDurum;
    _iosBasarisizCb = onBasarisiz;
  }

  /// iOS16+ COKLU-GOREV KAMERA (test turu 9): AVCaptureSession.isMultitaskingCameraAccessEnabled
  /// -> kamera PiP/arka planda CAPTURE'a devam eder (karsi taraf / IZLEYICILER beni gorur).
  /// Entitlement GEREKMEZ (iOS18+ property; iOS16-17 cihaza bagli). Desteksiz -> false.
  static Future<bool> iosCokluGorevKamera() async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>('iosCokluGorevKamera')) ?? false;
    } catch (_) {
      return false;
    }
  }
}
