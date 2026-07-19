import 'dart:io';

import 'package:flutter/services.dart';

/// FAZ-6: Android sistem PiP koprusu ('gebzem/pip' — MainActivity.kt ile birebir).
/// Yalniz Android; iOS/hata durumlari sessizce yutulur (PiP olmayan cihazda arama
/// akisi ETKILENMEZ — kamera-mute yedegi lifecycle'da).
class PipService {
  static const _ch = MethodChannel('gebzem/pip');
  static bool _dinleyiciKuruldu = false;

  /// PiP'e girilebilir mi (yalniz BAGLI GORUNTULU aramada true gonderilir).
  /// API 31+'da autoEnter parametresini de gunceller.
  static Future<void> pipIzinli(bool izinli) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('setPipIzinli', izinli);
    } catch (_) {}
  }

  /// Native 'pipDegisti' olayini dinle (true=PiP'e girildi, false=cikildi).
  static void dinle(void Function(bool pipModunda) cb) {
    if (!Platform.isAndroid || _dinleyiciKuruldu) return;
    _dinleyiciKuruldu = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'pipDegisti') {
        cb(call.arguments == true);
      }
    });
  }
}
