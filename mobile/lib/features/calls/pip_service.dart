import 'dart:io';

import 'package:flutter/services.dart';

/// FAZ-6: Android sistem PiP koprusu ('gebzem/pip' — MainActivity.kt ile birebir).
/// Yalniz Android; iOS/hata durumlari sessizce yutulur (PiP olmayan cihazda arama
/// akisi ETKILENMEZ — kamera-mute yedegi lifecycle'da).
class PipService {
  static const _ch = MethodChannel('gebzem/pip');
  static bool _dinleyiciKuruldu = false;
  static bool _iosDinleyiciKuruldu = false;

  /// PiP'e girilebilir mi (yalniz BAGLI GORUNTULU aramada true gonderilir).
  /// API 31+'da autoEnter parametresini de gunceller.
  static Future<void> pipIzinli(bool izinli) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('setPipIzinli', izinli);
    } catch (_) {}
  }

  /// Native 'pipDegisti' olayini dinle (true=PiP'e girildi, false=cikildi). Android'e ozel
  /// (iOS sistem PiP ayri native pencere -> Flutter'a durum bildirimi gerekmez).
  static void dinle(void Function(bool pipModunda) cb) {
    if (!Platform.isAndroid || _dinleyiciKuruldu) return;
    _dinleyiciKuruldu = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'pipDegisti') {
        cb(call.arguments == true);
      }
    });
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

  /// Uzak video track'i icin PiP controller'i kur (auto-enter). Basari doner. Kurulamazsa
  /// (track yok/hata) false -> istemci kamera-mute avatar davranisinda kalir (zararsiz).
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

  /// iOS sistem PiP DURUM geri bildirimi (test turu 9): native GebzemPip delegate
  /// 'iosPipDurum' (true=basladi/false=durdu) + 'iosPipBasarisiz' (baslatilamadi) gonderir.
  /// Android 'pipDegisti' ayri handler'da (dinle) — iki platform runtime'da ayrisir, tek
  /// kanalda cakisma yok. Android/iOS ayni _ch olsa da yalniz o platformun handler'i kurulur.
  static void iosDinle(
      {required void Function(bool pipAktif) onDurum,
      required void Function() onBasarisiz}) {
    if (!Platform.isIOS || _iosDinleyiciKuruldu) return;
    _iosDinleyiciKuruldu = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'iosPipDurum') {
        onDurum(call.arguments == true);
      } else if (call.method == 'iosPipBasarisiz') {
        onBasarisiz();
      }
    });
  }

  /// iOS16+ COKLU-GOREV KAMERA (test turu 9): AVCaptureSession.isMultitaskingCameraAccessEnabled
  /// -> kamera PiP/arka planda CAPTURE'a devam eder (karsi taraf beni gorur). Entitlement
  /// GEREKMEZ (iOS18+ property; iOS16-17 cihaza bagli). Desteksiz -> false -> kamera-mute avatar.
  static Future<bool> iosCokluGorevKamera() async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>('iosCokluGorevKamera')) ?? false;
    } catch (_) {
      return false;
    }
  }
}
