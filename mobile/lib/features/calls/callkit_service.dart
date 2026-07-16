import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Kilit ekraninda / uygulama kapaliyken gelen arama.
///
/// MIMARI (arastirma sonucu):
///  - iOS: APNs **VoIP push** (PushKit) -> AppDelegate CallKit'e bildirir -> kilit
///    ekraninda gercek arama ekrani. FCM VoIP push GONDEREMEZ, bu yuzden sunucu
///    dogrudan APNs'e gonderiyor (backend/internal/push/apns.go).
///    iOS 13+ KURALI: VoIP push gelince CallKit'e reportNewIncomingCall ZORUNLU;
///    cagirmazsan iOS uygulamayi oldurur ve VoIP push'lari keser.
///  - Android: FCM **data-only** push -> arka plan isleyicisi -> tam ekran arama.
///    ("notification" tipli push'ta kodumuz calismaz, sadece tepside bildirim cikar.)
///
/// Uygulama ACIKKEN gelen arama zaten WebSocket ile geliyor (hizli, calisiyor) —
/// o yol korunuyor; CallKit arka plan/kapali durum icin.
class CallKitService {
  CallKitService._();
  static final CallKitService instance = CallKitService._();

  /// CallKit uzerinden ele alinan aramalar — uygulama one gelince ayni arama
  /// icin ikinci bir "gelen arama" ekrani acilmasin diye.
  static final Set<String> islenenler = {};

  StreamSubscription? _sub;

  /// Kabul edilen arama (uygulama kapaliyken kabul edildiyse acilista da gelir)
  final _kabulController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onKabul => _kabulController.stream;

  /// Kullanicinin KASTEN reddettigi/bitirdigi arama (CallKit Decline/Ended) -> sunucuya bildir.
  final _redController = StreamController<String>.broadcast();
  Stream<String> get onRed => _redController.stream;

  /// 45sn CallKit AUTO-EXPIRE (zaman asimi) — reddet/bitir'den AYRI kanal. KABUL sonrasi
  /// (canli arama) gelirse SPURIOUS'tur (arama suruyor), aramayi bitirmemeli; ringing'de
  /// (kabul edilmemis) gercek cevapsizdir. Tek-bitir-kapisi bu ayrimla korunur.
  final _timeoutController = StreamController<String>.broadcast();
  Stream<String> get onTimeout => _timeoutController.stream;

  /// iOS VoIP token'i (sunucuya kaydedilecek)
  final _voipTokenController = StreamController<String>.broadcast();
  Stream<String> get onVoipToken => _voipTokenController.stream;

  /// Bizim programatik kapattigimiz aramalar. endCall() yeni bir "ended" olayi
  /// uretir; onu tekrar sunucuya "end" olarak GONDERMEMEK icin isaretliyoruz
  /// (yoksa bitir -> endCall -> ended -> end -> ... geri besleme dongusu).
  static final Set<String> _bizBitirdik = {};

  Future<void> baslat() async {
    // onError: ACTION_CALL_TOGGLE_AUDIO_SESSION gibi id'siz olaylar FormatException
    // firlatiyor; yutulmazsa Sentry'e gurultu olarak duser (ses zaten native yonetiliyor).
    _sub ??= FlutterCallkitIncoming.onEvent.listen(_olay, onError: (e, _) {
      debugPrint('callkit olay yutuldu: $e');
    });

    // Uygulama CallKit'ten kabul edilerek SIFIRDAN acilmis olabilir — olay,
    // Flutter motoru hazir olmadan gecmis olabilir. Bekleyeni sor.
    try {
      final aktif = await FlutterCallkitIncoming.activeCalls();
      for (final c in aktif) {
        if (c.isAccepted) {
          islenenler.add(c.id);
          _kabulController.add(_ayikla(c));
        }
      }
    } catch (e) {
      debugPrint('callkit activeCalls: $e');
    }

    await _voipTokeniGonder();
  }

  /// Oturum acildiktan SONRA VoIP token'i yeniden al ve sunucuya gonder. Acilista token
  /// alinip POST edilirken oturum yoktu (401 yutuluyor) -> giris/kayit sonrasi cagrilmali;
  /// yoksa iOS'ta voip_tokens satiri hic olusmaz ve kilit ekraninda arama calmaz.
  Future<void> voipTokeniYenidenGonder() => _voipTokeniGonder();

  Future<void> _voipTokeniGonder() async {
    if (!Platform.isIOS) return;
    try {
      final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (t != null && t.isNotEmpty) _voipTokenController.add(t);
    } catch (e) {
      debugPrint('callkit voip token: $e');
    }
  }

  void _olay(CallEvent? e) {
    switch (e) {
      case CallEventActionCallAccept(:final callKitParams):
        islenenler.add(callKitParams.id);
        _kabulController.add(_ayikla(callKitParams));

      case CallEventActionCallDecline(:final callKitParams):
      case CallEventActionCallEnded(:final callKitParams):
        final id = callKitParams.id;
        islenenler.add(id);
        // BIZ kapattiysak (bitir/call.ended), tekrar sunucuya end gonderme -> dongu kir
        if (_bizBitirdik.remove(id)) break;
        _redController.add(id);

      case CallEventActionCallTimeout(:final id):
        islenenler.add(id);
        _timeoutController.add(id); // 45sn auto-expire — kabul sonrasi SPURIOUS olabilir (onRed DEGIL)

      case CallEventActionDidUpdateDevicePushTokenVoip():
        _voipTokeniGonder(); // token olayla gelmiyor, ayrica sorulmali

      default:
        break;
    }
  }

  Map<String, dynamic> _ayikla(CallKitParams p) {
    final extra = Map<String, dynamic>.from(p.extra ?? {});
    return {
      'call_id': p.id,
      'caller_name': p.nameCaller ?? '',
      'video': (p.type ?? 0) == 1 || (extra['call_type'] as String? ?? '') == 'video',
    };
  }

  /// Gelen arama ekranini goster (kilit ekraninda da calisir)
  static Future<void> goster({
    required String callId,
    required String callerName,
    required bool video,
    String avatar = '',
  }) async {
    if (callId.isEmpty) return;
    // TANI: push isleyicisi tetiklendi mi? (kilit ekrani gorunmuyorsa logcat'te ara)
    debugPrint('CALLKIT-GOSTER: callId=$callId video=$video');
    islenenler.add(callId);
    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: callId, // arama id'si zaten UUID — CallKit de UUID ister
      nameCaller: callerName.isEmpty ? 'Bilinmeyen' : callerName,
      appName: 'Gebzem',
      avatar: avatar.isEmpty ? null : avatar,
      handle: callerName,
      type: video ? 1 : 0,
      duration: 45000, // 45 sn sonra kendiliginden kapansin (arama zaten cevapsiz olur)
      extra: <String, dynamic>{
        'call_id': callId,
        'call_type': video ? 'video' : 'audio',
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowFullLockedScreen: true, // KILIT EKRANINDA TAM EKRAN
        isImportant: true,
        // KRITIK: false OLMALI. true iken paket startActivity() cagiriyor -> bu bir
        // "arka plandan Activity baslatma"; Android 10+ ve Xiaomi uygulama kapaliyken
        // bunu SESSIZCE engelliyor ("Background activity launch blocked") -> ekran
        // gorunmuyor, kullanici elle acinca geliyor (yasadigimiz semptom).
        // false iken setFullScreenIntent'li bildirim yayinlaniyor -> USE_FULL_SCREEN_INTENT
        // sayesinde bu engelden MUAF (Google'in kill/kilit ekrani icin onayladigi tek yol).
        isFullScreen: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B141A',
        actionColor: '#25D366',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Gelen aramalar',
        missedCallNotificationChannelName: 'Cevapsiz aramalar',
        textAccept: 'Kabul et',
        textDecline: 'Reddet',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        // Ses oturumunu CallKit yonetsin; LiveKit odaya KABULDEN SONRA baglanir.
        configureAudioSession: true,
        audioSessionMode: 'voiceChat',
        // audioSessionActive:false -> arama CALARKEN AVAudioSession'i AKTIVE ETME. true iken
        // arama daha calarken oturum aktive edilip iOS sistem ZILI BASTIRILIYORDU (kullanicinin
        // "iPhone'da gelen zil calmiyor" semptomu). Ses KABULDEN sonra didActivateAudioSession
        // (AppDelegate) ile aciliyor; configureAudioSession:true bunu garanti eder.
        audioSessionActive: false,
      ),
    ));
  }

  /// Arama iptal edildi/bitti — CallKit ekranini kapat (programatik).
  /// SADECE gercekten gosterilmis bir CallKit aramasi varsa endCall cagir. Yoksa
  /// (uygulama acik/WS ile yuruyorsa CallKit hic gosterilmedi) endCall bos isimli bir
  /// CEVAPSIZ ARAMA bildirimi uretiyor -> ekranda UUID ("karmasik harfler") gorunuyor.
  static Future<void> bitir(String callId) async {
    if (callId.isEmpty) return;
    try {
      final aktif = await FlutterCallkitIncoming.activeCalls();
      final varMi = aktif.any((c) => c.id == callId);
      if (!varMi) return; // hic gosterilmedi -> hayalet bildirim URETME
      _bizBitirdik.add(callId);
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  static Future<void> hepsiniBitir() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
  }

  /// Android 14+: "tam ekran bildirim" AYRI bir ozel izindir. Play Store disi
  /// (sideload) kurulumda OTOMATIK VERILMEZ -> verilmezse kilitli ekranda arama
  /// ekrani HIC acilmaz, sadece bildirim cikar.
  static Future<void> izinleriIste() async {
    if (!Platform.isAndroid) return;
    try {
      final bildirim = await FlutterCallkitIncoming.requestNotificationPermission({
        'title': 'Bildirim izni',
        'rationaleMessagePermission':
            'Gelen aramalari gorebilmek icin bildirim izni gerekiyor.',
        'postNotificationMessageRequired':
            'Bildirim izni olmadan gelen aramalar gosterilemez.',
      });
      var tamEkran = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (!tamEkran) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
        tamEkran = await FlutterCallkitIncoming.canUseFullScreenIntent();
      }
      // TANI: kilit ekrani aramasi gorunmuyorsa ilk bakilacak yer — izin durumu.
      debugPrint('CALLKIT-TANI: bildirim=$bildirim tamEkran=$tamEkran');
      unawaited(Sentry.captureMessage(
          'callkit izin durumu: bildirim=$bildirim tamEkran=$tamEkran'));
    } catch (e) {
      debugPrint('callkit izin: $e');
    }
  }

  void kapat() {
    _sub?.cancel();
    _sub = null;
  }
}
