import 'dart:async';

/// Ayni anda TEK bir LiveKit odasi yasar — ve yeni oda baglanmadan once
/// eskisinin kapanisi TAMAMEN bitmis olur.
///
/// NEDEN: livekit_client 2.8.1'de ses oturumu Room'a degil, MODUL DUZEYINDE
/// (global) ses parcasi sayaclarina bagli:
///  - iOS: sayac 0'a dusunce AVAudioSession 'soloAmbient'e cekilir → uzak ses SUSAR
///    (audio_management.dart: _localTrackCount/_remoteTrackCount global)
///  - Android: Room._cleanUp() → clearAndroidCommunicationDevice() → iletisim cihazi birakilir
/// Eski aramanin GEC biten temizligi, yeni arama bagli iken calisirsa CANLI aramanin
/// sesini oldurur. Kullanicinin gordugu: "2-3. aramada ses gitmiyor".
/// Cozum: butun oda yasam dongusu islemlerini (baglan / kapat) tek sirada calistir.
class CallRoomLock {
  CallRoomLock._();

  static Future<void> _sira = Future<void>.value();

  /// [is] islemi, onceki tum oda islemleri bitmeden BASLAMAZ.
  static Future<T> calistir<T>(Future<T> Function() is_) {
    final tamamlandi = Completer<T>();
    _sira = _sira.then((_) async {
      try {
        tamamlandi.complete(await is_());
      } catch (e, s) {
        tamamlandi.completeError(e, s);
      }
    });
    return tamamlandi.future;
  }
}
