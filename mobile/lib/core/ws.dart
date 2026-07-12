import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'storage.dart';

/// WebSocket servisi: baglanir, koparsa artan bekleme ile otomatik yeniden baglanir.
/// Gelen tum olaylar [events] akisina duser: {type, chat_id, payload}
class WsService {
  WsService(this._storage);

  final AppStorage _storage;
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _closed = false;
  bool _connected = false;
  int _retry = 0;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  Future<void> connect() async {
    _closed = false;
    if (_connected) return;
    await _open();
  }

  /// Uygulama on plana donunce HEMEN yeniden bagla — yoksa yeniden baglanma
  /// 60 saniyeye kadar gecikebilir ve o sirada gelen arama kacirilir.
  void resume() {
    if (_closed || _connected) return;
    _retry = 0;
    _open();
  }

  Future<void> _open() async {
    if (_closed || _connected) return;
    final token = await _storage.token;
    if (token == null) return;
    try {
      // pingInterval: yarim acik TCP'de (mobil ag degisince) baglantinin oldugunu
      // ~20 sn'de anlar ve yeniden baglanir. Yoksa _connected true kalir, mesaj gelmez.
      _channel = IOWebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
        pingInterval: const Duration(seconds: 20),
      );
      await _channel!.ready;
      _retry = 0;
      _connected = true;
      _channel!.stream.listen(
        (raw) {
          try {
            final map = jsonDecode(raw as String) as Map<String, dynamic>;
            _controller.add(map);
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _connected = false;
    if (_closed) return;
    _retry = (_retry + 1).clamp(1, 6);
    // 2, 4, 8, 16, 32, 60 sn — baglanti gucleninde kaldigi yerden devam
    final wait = Duration(seconds: _retry >= 6 ? 60 : 1 << _retry);
    Timer(wait, _open);
  }

  /// "yaziyor..." olayi gonder
  void sendTyping(String chatId) {
    try {
      _channel?.sink.add(jsonEncode({'type': 'typing', 'chat_id': chatId}));
    } catch (_) {}
  }

  Future<void> close() async {
    _closed = true;
    _connected = false;
    await _channel?.sink.close();
  }
}

final wsProvider = Provider<WsService>((ref) {
  final ws = WsService(ref.read(storageProvider));
  ref.onDispose(ws.close);
  return ws;
});
