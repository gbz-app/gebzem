import 'package:livekit_client/livekit_client.dart';

/// ⚠️⚠️ TURU 72 — ORTAK "MEDYAYI DURAKLAT/DEVAM ETTIR" PRIMITIFI.
///
/// Bu govde arama tarafinda (`ActiveCallController._medyaBeklet`) YILLARDIR kanitli
/// calisiyordu; oda ve canli yayin da AYNI seye ihtiyac duyunca KOPYALAMAK yerine
/// buraya CIKARILDI. Tek kaynak = drift YOK (CLAUDE.md: "mesgulluk kontrolu TEK
/// KAYNAK" dersinin ayni uygulamasi).
///
/// NE YAPAR:
///  · [beklet] = true  -> kendi mikrofon/kameramizi KAPAT + TUM uzak yayinlari
///                        `disable()` ile devre disi birak (ses kulaga GELMEZ).
///  · [beklet] = false -> uzaklari `enable()` + mikrofon/kamerayi [micHedef]/[camHedef]
///                        ile GERI YUKLE.
///
/// ⚠️⚠️ BAGLANTI ACIK KALIR. `disconnect()`/`leave()` YOKTUR — geri donus ANINDA olur,
///     yeniden katilma (ve yeniden izin/token/sunucu kaydi) GEREKMEZ.
///
/// ⚠️ `unsubscribe()` DEGIL `disable()` KULLANILIR: abonelik korunur, yalnizca akis
///     durur. `unsubscribe` ile devam ederken yeniden abonelik pazarligi gerekir ve
///     ses saniyelerce gec gelir.
///
/// ⚠️⚠️ BU FONKSIYON `_sesiAc(false)` CAGIRMAZ ve CAGIRMAMALIDIR:
///     oda/yayin ekranlarindaki `_sesiAc` native `gebzem/audio` uzerinden
///     `RTCAudioSession.sharedInstance().isAudioEnabled = false` yazar — bu PROSES
///     GENELINDE TEK nesnedir ve AKTIF ARAMANIN sesini de OLDURUR.
///     Duraklatma sirasinda ses birimine DOKUNMUYORUZ; yalniz track'leri susturuyoruz.
///
/// ⚠️ Hicbir hata firlatmaz (her adim kendi `try`inde) — cagiran taraf UI'yi
///     guvenle guncelleyebilir. Ama SESSIZ KALMAZ: cagiran, sonucu kendi olcumune yazar.
Future<void> medyaBeklet(
  Room room,
  bool beklet, {
  bool micHedef = true,
  bool camHedef = false,
}) async {
  try {
    await room.localParticipant?.setMicrophoneEnabled(beklet ? false : micHedef);
  } catch (_) {}
  try {
    await room.localParticipant?.setCameraEnabled(beklet ? false : camHedef);
  } catch (_) {}
  for (final p in room.remoteParticipants.values) {
    for (final pub in p.trackPublications.values) {
      try {
        if (beklet) {
          await pub.disable();
        } else {
          await pub.enable();
        }
      } catch (_) {}
    }
  }
}

/// TURU 72: duraklatma SURERKEN odaya/yayina KATILAN birinin yayinini da sustur.
/// ⚠️ ZORUNLU: `TrackSubscribedEvent` dinleyicisinden cagrilmazsa, arama ortasinda
///     odaya giren biri KONUSMAYA BASLAR ve sesi kulaga gelir (duraklatmanin deligi).
/// ⚠️ Tip `RemoteTrackPublication` OLMALI — `disable()` yalniz UZAK yayinlarda vardir
/// (taban `TrackPublication`da YOK). `TrackSubscribedEvent.publication` zaten uzaktir.
Future<void> yeniYayiniSustur(RemoteTrackPublication pub) async {
  try {
    await pub.disable();
  } catch (_) {}
}
