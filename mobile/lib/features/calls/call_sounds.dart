import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Arama sesleri: gelen aramada ZIL + TITRESIM, giden aramada CALMA TONU.
///
/// NEDEN LiveKit ile cakismiyor:
/// iOS'ta surec basina TEK bir AVAudioSession var ve livekit_client, mikrofon
/// yayinlanir yayinlanmaz oturumu playAndRecord'a (mixWithOthers OLMADAN) cekiyor;
/// bu da bizim zil sesimizi susturur (LiveKit issue #791 — "cozulmeyecek" diye kapatildi).
/// Cozum hack degil, akis: ARAYAN, karsi taraf ACANA KADAR LiveKit odasina hic
/// baglanmaz. Boylece calma tonu calarken ortada WebRTC ses oturumu OLMAZ.
/// ALICI zaten kabul edene kadar odaya girmez → gelen arama zili de serbest calar.
class CallSounds {
  CallSounds._();

  static final _player = AudioPlayer(playerId: 'gebzem_arama');
  static bool _calan = false;
  static Timer? _titresim;

  /// Gelen arama: zil dongude calar + telefon titrer
  static Future<void> gelenArama() async {
    await _cal('sounds/zil.wav', sesli: true);
    _titresimBaslat();
  }

  /// Giden arama: "caliyor" tonu (Turkiye: 425 Hz, 2 sn calar 4 sn susar)
  static Future<void> calmaTonu() async {
    await _cal('sounds/calma.wav', sesli: false);
  }

  /// Arama bitti: kisa cift bip (tek sefer)
  static Future<void> bittiSesi() async {
    await durdur();
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/bitti.wav'), volume: 0.6);
    } catch (_) {}
  }

  /// Her sey susar (kabul/reddet/kapat aninda MUTLAKA cagrilmali)
  static Future<void> durdur() async {
    _calan = false;
    _titresim?.cancel();
    _titresim = null;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> _cal(String varlik, {required bool sesli}) async {
    if (_calan) return;
    _calan = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop); // dongu
      // Gelen aramada zil sesi telefonun zil kanalindan, giden tonda daha kisik
      await _player.setVolume(sesli ? 1.0 : 0.5);
      await _player.play(AssetSource(varlik));
    } catch (_) {
      _calan = false;
    }
  }

  static void _titresimBaslat() {
    _titresim?.cancel();
    _titresim = Timer.periodic(const Duration(milliseconds: 2200), (_) async {
      try {
        if (await Vibration.hasVibrator()) {
          // Uzun-kisa-uzun: klasik arama titresimi
          if (Platform.isIOS) {
            Vibration.vibrate(duration: 600);
          } else {
            Vibration.vibrate(pattern: [0, 600, 300, 600]); // uzun-kisa-uzun
          }
        }
      } catch (_) {}
    });
    // Ilk titresim hemen
    Vibration.hasVibrator().then((v) {
      if (v) Vibration.vibrate(duration: 600);
    }).catchError((_) => null);
  }
}
