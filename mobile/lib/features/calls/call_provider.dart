import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import 'callkit_service.dart';

/// Gelen arama bilgisi (WebSocket "call.incoming" olayindan)
class IncomingCall {
  IncomingCall({
    required this.callId,
    required this.callerName,
    required this.callerAvatar,
    required this.video,
  });

  final String callId;
  final String callerName;
  final String callerAvatar;
  final bool video;

  factory IncomingCall.fromJson(Map<String, dynamic> j) => IncomingCall(
        callId: j['call_id'] as String,
        callerName: j['caller_name'] as String? ?? 'Bilinmeyen',
        callerAvatar: j['caller_avatar'] as String? ?? '',
        video: (j['type'] as String? ?? 'audio') == 'video',
      );
}

/// Arama servisi: davetleri dinler, arama baslatir/kabul eder/bitirir
class CallService extends StateNotifier<IncomingCall?> {
  CallService(this._ref) : super(null) {
    _sub = _ref.read(wsProvider).events.listen(_onEvent);
  }

  final Ref _ref;
  StreamSubscription? _sub;

  /// Arama bittiginde/reddedildiginde tetiklenir (ekran kapatmak icin)
  final _endedController = StreamController<String>.broadcast();
  Stream<String> get onCallEnded => _endedController.stream;

  /// Karsi taraf kabul edince tetiklenir
  final _answeredController = StreamController<String>.broadcast();
  Stream<String> get onCallAnswered => _answeredController.stream;

  /// Kabul edilmis aramalar. Arama ekrani olayi dinlemeye baslamadan ONCE
  /// "kabul edildi" gelirse kaybolmasin diye tutuluyor.
  final Set<String> kabulEdilenler = {};

  void _onEvent(Map<String, dynamic> ev) {
    final payload = ev['payload'];
    if (payload is! Map) return;
    final p = payload.cast<String, dynamic>();

    switch (ev['type']) {
      case 'call.incoming':
        // iOS: gelen arama HER ZAMAN VoIP push -> CallKit ile gelir (backend her zaman push atar).
        // WS overlay'i de acarsak on planda CIFT gosterim + ses cakismasi olur (Oturum 7).
        // iOS'ta WS call.incoming yok sayilir; arama yalniz CallKit'ten. Android'de on planda
        // WS overlay kullanilir (arka planda FCM data -> CallKit).
        if (Platform.isIOS) return;
        final id = p['call_id'] as String? ?? '';
        // Ayni arama CallKit (kilit ekrani) uzerinden zaten gosterildiyse
        // uygulama ici ekrani ACMA — yoksa cift arama ekrani cikar.
        if (CallKitService.islenenler.contains(id)) return;
        state = IncomingCall.fromJson(p);
      case 'call.answered':
        final id = p['call_id'] as String? ?? '';
        kabulEdilenler.add(id);
        _answeredController.add(id);
      case 'call.ended':
        final id = p['call_id'] as String? ?? '';
        aramaBitti(id);
    }
  }

  /// Arama bitti/iptal edildi. WS "call.ended" VEYA push ("call.cancel"/"call.ended")
  /// ile cagrilir. Hem gelen arama ekranini/CallKit'i hem de AKTIF CallScreen'i kapatir.
  /// Idempotent: state=null noop, CallKit.bitir aktif yoksa noop, _endedController'i
  /// dinleyen _leave tek-seferlik kilitli. Push yedegi de bu tek kapiyi kullanir.
  void aramaBitti(String id) {
    if (id.isEmpty) return;
    if (state?.callId == id) state = null;
    CallKitService.bitir(id);
    _endedController.add(id);
  }

  /// Arayan: "aramam cevaplandi mi / bitti mi" (WS call.answered kaybolursa kurtarma)
  Future<Map<String, dynamic>> callStatus(String callId) async {
    final res = await _ref.read(apiProvider).get('/calls/$callId/status');
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Uygulama acilinca / on plana donunce: beni su an arayan var mi?
  /// (Arka plandayken WebSocket kopuk oldugu icin "call.incoming" olayi kacmis olabilir —
  /// kullanici bildirime dokunup acinca aramayi yine de gormeli.)
  Future<void> checkActive() async {
    if (state != null) return; // zaten gelen arama ekrani acik
    try {
      final res = await _ref.read(apiProvider).get('/calls/active');
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['call_id'] is String) {
        final id = data['call_id'] as String;
        // iOS'ta arama CallKit ile gosterilir; CallKit zaten gosterdiyse uygulama-ici overlay
        // ACMA (cift gosterim olmasin). VoIP push kacirilmis nadir durumda overlay yedek kalir.
        if (Platform.isIOS && CallKitService.islenenler.contains(id)) return;
        state = IncomingCall.fromJson(data);
      }
    } catch (_) {
      // sessiz gec — arama yoksa sorun degil
    }
  }

  /// Arama baslat — LiveKit baglanti bilgilerini doner
  Future<Map<String, dynamic>> start(String calleeId, {required bool video}) async {
    final res = await _ref.read(apiProvider).post('/calls', data: {
      'callee_id': calleeId,
      'video': video,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  // Ayni arama iki yoldan (uygulama ici overlay + CallKit) kabul/bitir edilebilir.
  // callId bazli kilit -> cift answer (409) ve 5-6 kez end REST'ini onler.
  final Set<String> _cevaplanan = {};
  final Set<String> _bitenler = {};

  /// Gelen aramayi kabul et.
  /// DIKKAT: state'i SIFIRLAMIYORUZ (once ekran acilir, sonra dismiss).
  /// null DONERSE: bu arama zaten baska yoldan cevaplandi -> cagiran ekran ACMASIN.
  Future<Map<String, dynamic>?> answer(String callId) async {
    if (!_cevaplanan.add(callId)) return null; // ikinci kabul -> 409 olmadan engelle
    try {
      final res = await _ref.read(apiProvider).post('/calls/$callId/answer');
      return (res.data as Map).cast<String, dynamic>();
    } catch (e) {
      _cevaplanan.remove(callId); // basarisizsa (401 vs) tekrar denenebilsin
      rethrow;
    }
  }

  /// Aramayi bitir / reddet.
  /// KRITIK: guard'i (_bitenler) await ONCESI degil, POST BASARILI olunca isaretle.
  /// Eski kod await'ten once isaretliyor + hatayi yutuyordu -> ilk POST ag hatasiyla
  /// patlarsa callId kalici "bitti" damgalaniyor, bir daha GONDERILMIYOR -> arama sunucuda
  /// 'active' takili kaliyor, o kisi cok uzun sure "mesgul" gorunuyor (2. arama gitmiyor).
  /// Simdi: basarili olana kadar 3 kez dene, YALNIZ basarida isaretle. Sunucu End idempotent
  /// (zaten bitmisse rowsAffected=0 sessiz basari) oldugu icin cift-end zararsiz.
  Future<void> end(String callId) async {
    state = null;
    if (_bitenler.contains(callId)) return; // zaten basariyla bitirildi
    for (var deneme = 0; deneme < 3; deneme++) {
      try {
        await _ref.read(apiProvider).post('/calls/$callId/end');
        _bitenler.add(callId); // yalniz BASARIDA damgala
        return;
      } catch (_) {
        if (deneme < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Push (on plan onMessage) ile "kabul edildi" geldiginde — WS call.answered yedegi.
  void aramaKabulPush(String id) {
    if (id.isEmpty) return;
    kabulEdilenler.add(id);
    _answeredController.add(id);
  }

  void dismiss() => state = null;

  /// Arama gecmisini tazele. Arama ekrani kapanirken cagrilir — ekranin kendi
  /// `ref`'i o an yok edilmis olabilir, bu yuzden servisin kendi Ref'ini kullaniyoruz.
  void gecmisiYenile() => _ref.invalidate(callHistoryProvider);

  @override
  void dispose() {
    _sub?.cancel();
    _endedController.close();
    _answeredController.close();
    super.dispose();
  }
}

final callServiceProvider =
    StateNotifierProvider<CallService, IncomingCall?>(CallService.new);

/// Arama gecmisi
final callHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiProvider).get('/calls');
  return (res.data as List).cast<Map<String, dynamic>>();
});

/// Basit JSON yardimcisi (WS payload'lari icin)
Map<String, dynamic> decodePayload(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
  return {};
}
