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

  /// TURU 64 (iOS): gozcunun "hucresel" saydigi aramanin CallKit uuid'si (kucuk harf).
  /// Controller bunu KENDI arama id'siyle karsilastirip kendi kendini beklemeye alma
  /// felaketine karsi IKINCI bir suzgec uygular. Android'de daima bos.
  /// ⚠️ YAPMA: bu alani kaldirma; controller'daki karsilastirmayi silme.
  static String gsmYabanciId = '';

  /// TEST TURU 37: iOS kamera kesinti sebebi (AVCaptureSessionInterruptionReasonKey ham
  /// degeri). 0 = kesinti yok. Teshis icin Sentry'e yazilir.
  static final ValueNotifier<int> kameraKesintiSebebi = ValueNotifier<int>(0);
  static void Function(bool kesintiVar)? _iosKesintiCb;

  /// TEST TURU 43: kesinti anindaki tam resim (Sentry'e ON PLANDA yazilir).
  static Map<String, dynamic>? kesintiBilgi;
  static bool? kurtarmaSonucu;

  /// TEST TURU 38: PiP basladiktan 3sn sonraki kare sayisi (0 = capture durmus).

  static void Function(Map<String, dynamic> olcum)? _iosOlcumCb;
  static void Function(String kaynak)? _iosKareDurduCb;

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
          // Android: duz bool. iOS (turu 64): {'on': bool, 'uuid': String} — uuid,
          // gozcunun "yabanci" saydigi aramanin kimligidir; controller IKINCI bir
          // suzgecte bunu kendi aramasiyla karsilastirir (kendi kendini beklemeye
          // alma felaketine karsi emniyet). ⚠️ YAPMA: uuid'yi tasimayi birakma.
          final a = call.arguments;
          if (a is Map) {
            gsmYabanciId = (a['uuid'] as String? ?? '').toLowerCase();
            gsmAramada.value = a['on'] == true;
          } else {
            gsmYabanciId = '';
            gsmAramada.value = a == true;
          }
        case 'iosPipDurum':
          final v = call.arguments == true;
          pipModu.value = v;
          _iosDurumCb?.call(v);
        case 'iosPipBasarisiz':
          _iosBasarisizCb?.call();
        // TEST TURU 37: iOS kamera KESINTISI (AVCaptureSessionWasInterrupted). Arka planda
        // capture GERCEKTEN durdurulduysa bunu OS soyler — bayraga guvenmek yerine gercek
        // olaya tepki veriyoruz: kamerayi DURUSTCE kapat, karsi taraf donmus kare degil
        // bulanik "Kamera duraklatildi" gorsun.
        case 'iosKameraKesinti':
          // TEST TURU 43: artik TAM RESIM geliyor {sebep, durum, pip, sinif, calisiyor,
          // destek, acik} — eski surumde yalniz sebep kodu vardi.
          final k = Map<String, dynamic>.from(call.arguments as Map);
          kesintiBilgi = k;
          kameraKesintiSebebi.value = (k['sebep'] as int?) ?? -1;
          _iosKesintiCb?.call(true);
        case 'iosKameraKurtarma':
          kurtarmaSonucu = call.arguments == true;
        case 'iosPipOlcum':
          // TEST TURU 39: iki tarafli olcum {on, arka, kaynak, oturum, coklu}
          final m = Map<String, dynamic>.from(call.arguments as Map);
          _iosOlcumCb?.call(m);
        case 'iosPipKareDurdu':
          // TEST TURU 39: pencereye 1.5sn kare akmadi -> kaynak ('yerel'|'uzak')
          _iosKareDurduCb?.call(call.arguments as String? ?? 'yerel');
        case 'iosKameraKesintiBitti':
          kameraKesintiSebebi.value = 0;
          _iosKesintiCb?.call(false);
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

  /// TURU 62 — SES OTURUMUNU YENIDEN KURDUR (yalniz ANDROID).
  ///
  /// GSM aramasi bitince Android ses modunu MODE_NORMAL'a dondurur ve cihaz secimimizi
  /// temizler; flutter_webrtc'nin `AudioSwitch.activate()` gecisi arama boyunca kilitli
  /// oldugu icin bunu geri alan HICBIR SEY yoktu -> ses kulaklik yerine HOPARLORDEN
  /// caliyordu. Native taraf `deactivate()` + (bir dongu turu sonra) `activate()` yapar.
  ///
  /// Donus: tazeleme ONCESINDEKI `AudioManager.mode` (olcum icin; -99 = native hata,
  /// -1 = cagri yapilamadi). ⚠️ YAPMA: bu donusu yok sayma — kok nedenin dogrulanmasi
  /// buna bagli (0=NORMAL 1=RINGTONE 2=IN_CALL 3=IN_COMMUNICATION).
  static Future<int> sesOturumunuTazele() async {
    if (!Platform.isAndroid) return -1;
    try {
      _handlerKur();
      return (await _ch.invokeMethod<int>('sesOturumunuTazele')) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// GSM ARAMA DINLEYICISI (test turu 20): Gebzem aramasi basladiginda ac, bitince kapat.
  /// Donus: dinlenebiliyor mu (Android'de READ_PHONE_STATE izni yoksa false -> ozellik
  /// sessizce kapali).
  ///
  /// ⚠️⚠️ TURU 64 — ARTIK iOS'TA DA CALISIR. Once `if (!Platform.isAndroid) return false;`
  /// vardi; yani iPhone'da hucresel aramayi goren HICBIR SEY yoktu. CallKit yalniz GELEN
  /// hucresel aramada bizim aramamizi bekletir — kullanici KENDISI arama YAPTIGINDA hicbir
  /// olay gelmez (kullanici sikayeti S3). iOS tarafinda ayni isi `CXCallObserver`
  /// (AppDelegate `GebzemGsmGozcu`) yapar.
  /// ⚠️ YAPMA: iOS kapisini geri koyma; `gsmDinle(false)` cagrisini atlama (gozcu acik
  ///     kalirsa sonraki aramaya sarkar).
  /// ⚠️⚠️ [callId] iOS'ta ZORUNLUDUR (Android'de yok sayilir): gozcu BASLAMADAN ONCE
  /// kendi aramamiz deftere yazilir. Aksi halde `baslat()` icindeki ilk degerlendirme
  /// KENDI Gebzem CallKit aramamizi "hucresel" sanar, `gsmAramada` true olur ve uygulama
  /// kendi aramasini beklemeye alir (sesi keser). Sirayi tesadufe birakmiyoruz.
  /// ⚠️ YAPMA: callId'yi bos gecme; kaydi `gsmDinle`den SONRAYA birakma.
  static Future<bool> gsmDinle(bool ac, {String callId = ''}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      _handlerKur();
      // Android tarafi (MainActivity.kt) DUZ BOOL bekler — sozlesmeyi bozma.
      final Object arg = Platform.isIOS ? {'ac': ac, 'callId': callId} : ac;
      final ok = (await _ch.invokeMethod<bool>('gsmDinle', arg)) ?? false;
      if (!ac) {
        gsmAramada.value = false;
        gsmYabanciId = '';
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// TURU 64 (iOS): kendi Gebzem CallKit aramamizi gozcunun defterine yaz/sil.
  /// Defterde OLMAYAN her CallKit aramasi "hucresel" sayilir — bu yuzden kendi
  /// aramalarimizi bildirmek ZORUNLU. Android'de no-op.
  /// ⚠️ YAPMA: bu cagrilari atlamaya calisma — atlanirsa uygulama KENDI aramasini
  ///     hucresel sanip beklemeye alir.
  static Future<void> gebzemAramaKaydet(String callId) async {
    if (!Platform.isIOS || callId.isEmpty) return;
    try {
      _handlerKur();
      await _ch.invokeMethod('gebzemAramaKaydet', callId);
    } catch (_) {}
  }

  static Future<void> gebzemAramaSil(String callId) async {
    if (!Platform.isIOS || callId.isEmpty) return;
    try {
      await _ch.invokeMethod('gebzemAramaSil', callId);
    } catch (_) {}
  }

  /// TEST TURU 32 — SUREN ARAMA ONDEPLAN SERVISI (Android). Kullanici: "uygulamayi alta
  /// alinca / kilitleyince 5-10 saniye sonra gorusme bitiyor".
  /// KOK NEDEN: Android 14+ arka plana gecip "cached" olan sureci **10sn sonra DONDURUR**
  /// (cached apps freezer) -> WebSocket/WebRTC durur -> LiveKit katilimciyi duser -> arama
  /// biter. Ayrica Android 11+ arka planda mikrofon icin `microphone` tipli ondeplan servisi
  /// ZORUNLU. Servis medyaya DOKUNMAZ; yalniz sureci ayakta tutar + kalici bildirim gosterir.
  /// Baslatilamazsa sessizce vazgecilir. iOS'ta no-op (orada `audio`/`voip` arka plan modlari
  /// ve CallKit ayni isi yapar).
  static Future<bool> aramaServisi(bool ac, {bool video = false}) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = ac
          ? await _ch.invokeMethod<bool>('aramaServisiBasla', {'video': video})
          : await _ch.invokeMethod<bool>('aramaServisiDur');
      return ok ?? false;
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
  /// [kaynak]: 'uzak' | 'yerel' — native kare gozcusu raporunda hangi videonun gosterildigi
  /// bilinsin diye (turu 39 olcumu).
  static Future<bool> iosPipKur(String trackId,
      {String? yerelTrackId, String kaynak = 'uzak'}) async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>('iosPipKur', {
            'trackId': trackId,
            'yerelTrackId': yerelTrackId,
            'kaynak': kaynak,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// TEST TURU 28 — iOS kucuk penceresinin ALT gorunumu (KENDI kameram). PiP controller'a
  /// DOKUNMAZ: yalniz native dikey yigina gorunum eklenir/cikarilir. Bu yuzden kamera
  /// acilip kapansa da pencere kurulumu BOZULMAZ (turu 24'te kimlik degisince yikiliyordu).
  /// [trackId] null/bos -> alt gorunum kaldirilir (tek video, tam pencere).
  /// Donus: native sonuc metni ('eklendi' | 'track-yok' | 'yigin-yok' | 'kaldirildi' | 'ayni').
  /// TEST TURU 32: sessiz basarisizlik bitti — Dart bu sonucu Sentry'e yazar.
  /// TEST TURU 52 — KUCUK PENCERE IZGARASI: ANA video DISINDAKI uzak katilimcilarin
  /// video track id'leri. Native taraf `yigin`i yeniden dizer; `pipController`a
  /// DOKUNMAZ, yani pencere KAPANMAZ.
  /// Duzen: 1 kutu tam · 2 kutu UST/ALT · 3-8 kutu 2 sutunlu satirlar.
  /// ⚠️ YAPMA: bunu `iosPipKur` ile yapma (pencere kapanir — turu 24/26 dersi).
  static Future<String> iosPipEkKaynaklar(List<String> trackIdler) async {
    if (!Platform.isIOS) return 'ios-degil';
    try {
      return (await _ch.invokeMethod<String>(
              'iosPipEkKaynaklar', {'trackIdler': trackIdler})) ??
          'bos';
    } catch (e) {
      return 'hata';
    }
  }

  static Future<String> iosPipYerel(String? trackId, {String harf = '?'}) async {
    if (!Platform.isIOS) return 'ios-degil';
    try {
      return (await _ch.invokeMethod<String>(
              'iosPipYerel', {'trackId': trackId, 'harf': harf})) ??
          'bos';
    } catch (e) {
      return 'hata';
    }
  }

  /// TEST TURU 38: kamera kapatilirken PiP katmanini bosalt -> donmus kare yerine
  /// "Kamera duraklatildi" etiketi.
  /// TEST TURU 39: pencereyi KAPATMADAN gosterilen videoyu degistir (sicak kaynak degisimi).
  /// [kaynak]: 'yerel' | 'uzak' — yalniz teshis/etiket icin.
  static Future<bool> iosPipKaynak(String trackId, String kaynak) async {
    if (!Platform.isIOS) return false;
    try {
      return (await _ch.invokeMethod<bool>(
              'iosPipKaynak', {'trackId': trackId, 'kaynak': kaynak})) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// PiP penceresinde donmus kare yerine etiket goster.
  /// turu 48: `yalnizYerel` -> SADECE kose kutusu (kendi kameram). Buyuk kutuda karsi
  /// taraf akmaya devam ederken ona "duraklatildi" yazmak yanlisti.
  static Future<void> iosPipKareBosalt({bool yalnizYerel = false}) async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod('iosPipKareBosalt', yalnizYerel);
    } catch (_) {}
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

  /// TEST TURU 25: uygulama ON PLANA donunce PiP penceresini KAPAT (asili kalmasin).
  static Future<void> iosPipDurdur() async {
    if (!Platform.isIOS) return;
    try {
      await _ch.invokeMethod('iosPipDurdur');
    } catch (_) {}
  }

  /// iOS sistem PiP DURUM geri bildirimi (test turu 9): native GebzemPip delegate
  /// 'iosPipDurum' (true=basladi/false=durdu) + 'iosPipBasarisiz' (baslatilamadi) gonderir.
  static void iosDinle(
      {required void Function(bool pipAktif) onDurum,
      required void Function() onBasarisiz,
      void Function(bool kesintiVar)? onKameraKesinti,
      void Function(Map<String, dynamic> olcum)? onPipOlcum,
      void Function(String kaynak)? onKareDurdu}) {
    if (!Platform.isIOS) return;
    _handlerKur();
    _iosDurumCb = onDurum;
    _iosBasarisizCb = onBasarisiz;
    _iosKesintiCb = onKameraKesinti;
    _iosOlcumCb = onPipOlcum;
    _iosKareDurduCb = onKareDurdu;
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
