import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';

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

  void _onEvent(Map<String, dynamic> ev) {
    final payload = ev['payload'];
    if (payload is! Map) return;
    final p = payload.cast<String, dynamic>();

    switch (ev['type']) {
      case 'call.incoming':
        state = IncomingCall.fromJson(p);
      case 'call.answered':
        _answeredController.add(p['call_id'] as String? ?? '');
      case 'call.ended':
        final id = p['call_id'] as String? ?? '';
        if (state?.callId == id) state = null; // gelen arama ekranini kapat
        _endedController.add(id);
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

  /// Gelen aramayi kabul et.
  /// DIKKAT: burada state'i SIFIRLAMIYORUZ. Sifirlarsak gelen arama ekrani
  /// agactan silinir, onu cagiran widget dispose olur ve arama ekrani hic
  /// acilmaz (kabul eden taraf odaya girmez). Once ekran acilir, sonra
  /// dismiss() cagrilir.
  Future<Map<String, dynamic>> answer(String callId) async {
    final res = await _ref.read(apiProvider).post('/calls/$callId/answer');
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Aramayi bitir / reddet
  Future<void> end(String callId) async {
    state = null;
    try {
      await _ref.read(apiProvider).post('/calls/$callId/end');
    } catch (_) {
      // zaten bitmis olabilir
    }
  }

  void dismiss() => state = null;

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
