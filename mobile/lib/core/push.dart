import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// Push kaydi: bildirim izni ister, FCM token'i alir, backend'e kaydeder
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _registered = false;

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

      fm.onTokenRefresh.listen(_save);
    } catch (_) {
      // Firebase kurulamadiysa (ör. Google Play Servisleri yok) sessizce gec —
      // mesajlasma WebSocket'le calismaya devam eder
    }
  }

  Future<void> _save(String token) => _ref.read(apiProvider).post(
        '/users/me/fcm-token',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
}

final pushProvider = Provider<PushService>((ref) => PushService(ref));
