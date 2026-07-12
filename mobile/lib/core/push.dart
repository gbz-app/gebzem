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
      // Izin akisi karari (ozellik listesi): bildirim izni GIRISTE istenir
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await fm.getToken();
      if (token == null) return;
      await _save(token);
      _registered = true;

      // Cift abonelik olmasin (cikis/giris sonrasi register tekrar cagrilabilir)
      _refreshSub ??= fm.onTokenRefresh.listen(_save);
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
