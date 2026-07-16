import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Arama sesleri: gelen aramada ZIL + TITRESIM, giden aramada CALMA TONU.
///
/// NEDEN LiveKit ile cakismiyor:
/// ARAYAN, karsi taraf ACANA KADAR LiveKit odasina hic baglanmaz; ALICI kabul edene kadar
/// odaya girmez. Boylece zil/ton calarken ortada WebRTC ses oturumu OLMAZ. iOS'ta ses
/// kanalina (AVAudioSession) DOKUNMAYIZ (global; WebRTC ile catisir, "ses gitmiyor" krizi).
///
/// NESIL JETONU (art arda arama kok cozumu): tek paylasilan _player + eski ekranin gec
/// dispose'undan tetiklenen durdur(), YENI aramanin baslattigi sesi kesiyordu (kullanicinin
/// "art arda aramada dit/zil yok" semptomu). Her yeni ses _nesil'i artirir; durdur(nesil)
/// yalniz o nesil HALA guncelse durdurur -> eski cagri yeni sesi KESEMEZ.
class CallSounds {
  CallSounds._();

  static final _player = AudioPlayer(playerId: 'gebzem_arama');
  static int _nesil = 0;
  static Timer? _titresim;

  /// Gelen arama: klasik telefon zili (zil.wav) dongude calar + telefon titrer.
  /// NESIL doner — cagiran, durdururken bu nesli vermeli (durdur(nesil)).
  static Future<int> gelenArama() async {
    final n = await _cal('sounds/zil.wav', sesli: true, zil: true);
    _titresimBaslat();
    return n;
  }

  /// Giden arama: "caliyor" tonu (Turkiye: 425 Hz, 2 sn calar 4 sn susar). NESIL doner.
  static Future<int> calmaTonu() async =>
      _cal('sounds/calma.wav', sesli: false, zil: false);

  /// Arama bitti: kisa cift bip (tek sefer)
  static Future<void> bittiSesi() async {
    await durdur();
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/bitti.wav'), volume: 0.6);
    } catch (_) {}
  }

  /// Sesi durdur.
  /// [nesil] VERILIRSE: yalniz o nesil HALA guncelse durdurur — eski ekranin gec dispose
  /// durdur'u YENI baslamis sesi kesemez (art arda arama kok cozumu). Titresim de yalniz o
  /// zaman durur. PARAMETRESIZ (kabul/reddet/kapat): KOSULSUZ her seyi durdur.
  static Future<void> durdur([int? nesil]) async {
    if (nesil != null && nesil != _nesil) return; // yeni ses baslamis; bu eski cagri dokunmasin
    _titresim?.cancel();
    _titresim = null;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<int> _cal(String varlik,
      {required bool sesli, required bool zil}) async {
    final n = ++_nesil; // bu calmanin nesli; onceki nesli gecersiz kilar
    try {
      await _player.stop(); // idempotent restart: onceki sesi temizle (guard yok, HER ZAMAN cal)
      if (n != _nesil) return n; // bu arada yeni bir _cal geldi -> bu cagri vazgecsin
      // ANDROID: zili/tonu MEDYA (STREAM_MUSIC) yerine ZIL/ARAMA kanalindan cal ki kullanici
      // medya sesini kismisken/sessizde bile duysun. Bu zil/ton fazinda WebRTC YOK (arayan
      // kabule kadar, alici kabule kadar odaya baglanmaz) -> catisma yok. iOS'a DOKUNMA
      // (AVAudioSession global; WebRTC ile catisir). iOS gelen zili CallKit'e birakildi.
      if (Platform.isAndroid) {
        await _player.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: zil
                ? AndroidUsageType.notificationRingtone
                : AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ));
      }
      await _player.setReleaseMode(ReleaseMode.loop); // dongu
      await _player.setVolume(sesli ? 1.0 : 0.5);
      await _player.play(AssetSource(varlik));
    } catch (_) {}
    return n;
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
