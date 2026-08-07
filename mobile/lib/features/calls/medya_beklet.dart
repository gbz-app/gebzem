import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// ⚠️⚠️ TURU 73 — iOS SES BIRIMI SAHIPLIK DEFTERI (kullanici emri: "hepsine yap").
///
/// iOS'ta ses birimi `RTCAudioSession.sharedInstance().isAudioEnabled` ile acilir
/// ve bu **PROSES GENELINDE TEK** bayraktir. Turu 72'de duraklatma yalniz Android'de
/// acikti, dolayisiyla iOS'ta arama ile oda/yayin ASLA ayni anda yasamiyordu.
/// iOS acilinca IKI YONLU bir yikim ortaya cikti:
///
///  (1) ARAMA KAPANISI -> `ActiveCallController._odaTemizle` `setAudioEnabled(false)`
///      yazar. Oda/yayin HALA BAGLI ise onun da sesi OLUR ("devam" dedigimizde
///      sessizlik) — turu 72'nin iOS'ta calismamasinin gercek sebebi budur.
///  (2) ODA/YAYIN KAPANISI -> `_kapatOda`/`_cik` `_sesiAc(false)` yazar. Arama HALA
///      SURUYORSA **arama sessize duser** (kullanici odadan cikinca gorusme olur).
///
/// COZUM: her ses tuketicisi burada KAYITLI kalir; kapanirken **BASKA TURDEN bir
/// sahip** varsa ses birimini KAPATMAZ, yalnizca kaydini duser.
///
/// ⚠️ Onekler ZORUNLU ve SABIT: `arama_` · `oda_` · `yayin_`.
/// ⚠️ YAPMA: kapanista `birak()` cagirmayi unutma (kayit asili kalirsa ses birimi
///     BIR DAHA kapanmaz ve iOS mikrofon gostergesi acik kalir).
/// ⚠️ YAPMA: bunu "sayac" yapma — ayni ekran iki kez kaydolursa Set idempotenttir,
///     sayac ise sizar.
class SesSahipligi {
  SesSahipligi._();

  static final Set<String> _sahipler = {};

  static void kaydol(String id) {
    if (id.isNotEmpty) _sahipler.add(id);
  }

  static void birak(String id) => _sahipler.remove(id);

  /// ARAMA kapanirken: hala bagli bir oda/yayin var mi?
  static bool get odaVeyaYayinCanli =>
      _sahipler.any((x) => x.startsWith('oda_') || x.startsWith('yayin_'));

  /// ODA/YAYIN kapanirken: hala suren bir arama var mi?
  static bool get aramaCanli => _sahipler.any((x) => x.startsWith('arama_'));

  /// Olcum/teshis icin (Sentry mesajlarina eklenir).
  static String get ozet => _sahipler.join(',');
}

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
///
/// ⚠️⚠️ TURU 72b (denetim duzeltmesi) — "ses birimine HIC dokunmuyoruz" iddiasi
///     TAM DOGRU DEGILDI, DOGRUSU SUDUR:
///     · **Android'de dokunmaz** (bugun duraklatma zaten YALNIZ Android'de acik).
///     · **iOS'ta DOLAYLI dokunabilir:** `setMicrophoneEnabled(false)` +
///       livekit varsayilani `stopAudioCaptureOnMute: true` -> `onUnpublish` ->
///       MODUL-GLOBAL `_localTrackCount--` -> `_onAudioTrackCountDidChange()` ->
///       iOS dalinda `Native.configureAudio(...)` (proses geneli AVAudioSession).
///       Aktif arama kendi yerel track'ini TUTTUGU surece sayac 0'a DUSMEZ, yani
///       bugun tetiklenmez — ama iOS duraklatmasi acilirsa BURASI ilk bakilacak yer.
/// ⚠️ YAPMA: iOS'u acarken bu notu okumadan `stopAudioCaptureOnMute` varsayilanina guvenme.
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

/// ⚠️⚠️ TURU 73 — iOS SES BIRIMINI **GARANTILE** (turu 64 merdiveninin oda/yayin karsiligi).
///
/// NEDEN GEREKLI: kullanici odada/yayindayken aramayi kabul edip bitirdiginde, arama
/// kapanisi ile bizim "devam" cagrimiz YARIS HALINDEDIR ve iOS ses birimini o anda
/// baska bir sahip (CallKit) tutuyor olabilir. Turu 65'te bu durumun sahada
/// **`!pri` = `AVAudioSessionErrorCodeInsufficientPriority`** (561017449 = 0x21707269)
/// urettigi OLCUMLE KANITLANMISTI: *"ses oturumunu SEN aktive edemezsin."*
///
/// TEK DENEME YETMEZ — ama sinirsiz denemek de olmaz. Artan araliklarla 5 basamak
/// (~4sn) denenir; native `{configOk, active}` DOGRULANIR (turu 60/61 "olcum korlugu"
/// dersi: `getAudioState` bu ucu dondurmez, olcut ayni yoldan gelmelidir).
///
/// ⚠️ HATA YUTULMAZ: tukenirse **GERCEK Sentry olayi** yazilir (breadcrumb DEGIL —
///     breadcrumb ancak baska bir olayla yuklenir; CLAUDE.md tekrarlayan tuzagi).
/// ⚠️ YAPMA: basamak sayisini 1'e dusurme; olcutu `configOk`suz birakma.
/// ⚠️ YAPMA: istisna firlatir hale getirme — cagiran taraf UI akisinda.
///
/// Doner: ses birimi acilabildi mi (Android'de her zaman `true` — orada no-op).
Future<bool> iosSesBirimiAc(MethodChannel kanal, String etiket) async {
  if (!Platform.isIOS) return true;
  const araliklar = <int>[0, 200, 600, 1200, 2000];
  Object? sonHata;
  for (var i = 0; i < araliklar.length; i++) {
    if (araliklar[i] > 0) {
      await Future<void>.delayed(Duration(milliseconds: araliklar[i]));
    }
    try {
      final ham = await kanal.invokeMethod('setAudioEnabled', true);
      final r = (ham as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      if (r != null && r['configOk'] == true && r['active'] == true) {
        if (i > 0) {
          unawaited(Sentry.captureMessage(
              'oda/yayin ses birimi $etiket: ${i + 1}. denemede ACILDI '
              '(sahipler=${SesSahipligi.ozet})'));
        }
        return true;
      }
      sonHata = r?['hata'] ?? 'configOk=${r?['configOk']} active=${r?['active']}';
    } catch (e) {
      sonHata = e;
    }
  }
  unawaited(Sentry.captureMessage(
      'oda/yayin ses birimi ACILAMADI ($etiket): hata=$sonHata '
      'sahipler=${SesSahipligi.ozet}'));
  return false;
}
