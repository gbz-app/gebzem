import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// Push kaydi: bildirim izni ister, FCM token'i alir, backend'e kaydeder
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _registered = false;
  StreamSubscription<String>? _refreshSub;
  String? _lastToken;

  Future<void> register() async {
    if (_registered) return;
    try {
      final fm = FirebaseMessaging.instance;
      // onTokenRefresh'i ONCE kur: taze kurulumda ilk getToken() null donse bile,
      // Firebase token'i sonradan uretince _save yakalar (yoksa kalici gecikme).
      _refreshSub ??= fm.onTokenRefresh.listen(_save);

      // Izin akisi karari (ozellik listesi): bildirim izni GIRISTE istenir
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // TAZE KURULUM: getToken() ilk kez Google'a kaydolurken ~10-30sn surebilir ve
      // null donebilir. Callee token'i DB'ye dusene kadar arama ona ULASMAZ (30sn semptomu).
      // Kisa artan backoff'la yeniden dene; getToken VEYA POST hatasinda tekrar dener.
      for (var i = 0; i < 4; i++) {
        try {
          final token = await fm.getToken();
          if (token != null) {
            await _save(token);
            _registered = true;
            return;
          }
        } catch (_) {}
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
      // 4 deneme de yetmezse: onTokenRefresh (yukarida) hazir -> token gelince kaydeder.
    } catch (_) {
      // Firebase kurulamadiysa (ör. Google Play Servisleri yok) sessizce gec —
      // mesajlasma WebSocket'le calismaya devam eder
    }
  }

  /// Cikis yaparken: bu cihazin token'ini SUNUCUDAN sil (yoksa yeni giren
  /// kullanici, onceki kullanicinin bildirimlerini/aramalarini alir) ve
  /// yeniden kayda hazir ol.
  Future<void> unregister() async {
    _registered = false;
    final token = _lastToken;
    if (token == null) return;
    _lastToken = null;
    try {
      await _ref.read(apiProvider).delete('/users/me/fcm-token',
          data: {'token': token});
    } catch (_) {
      // cikis yine de tamamlanmali
    }
  }

  Future<void> _save(String token) async {
    _lastToken = token;
    await _ref.read(apiProvider).post(
          '/users/me/fcm-token',
          data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
        );
  }

  void dispose() {
    _refreshSub?.cancel();
  }
}

final pushProvider = Provider<PushService>((ref) => PushService(ref));
