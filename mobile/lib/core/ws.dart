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
  StreamSubscription? _sub; // aktif soketin dinleyicisi (yetim baglantiyi onlemek icin)
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
  /// NOT: goOffline() _closed=true birakir; burada _closed'i sifirlamazsak
  /// (connect() gibi) resume() bir daha hic baglanmaz — tutarli olsun diye sifirlaniyor.
  void resume() {
    if (_connected) return;
    _closed = false;
    _retry = 0;
    _open();
  }

  Future<void> _open() async {
    if (_closed || _connected) return;
    final token = await _storage.token;
    if (token == null) return;
    // Yeni soket kurmadan ONCE eski dinleyici + soketi kapat. Yoksa iOS askidan
    // cikan eski soketin GECIKMIS onDone'u, yeni soket aciktayken _scheduleReconnect
    // tetikleyip ikinci (yetim) bir baglanti biraktiriyordu -> sunucu kullaniciyi
    // "online" sanip kilit-ekrani push'unu ~35sn engelliyordu.
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    try {
      // pingInterval: yarim acik TCP'de (mobil ag degisince) baglantinin oldugunu
      // ~20 sn'de anlar ve yeniden baglanir. Yoksa _connected true kalir, mesaj gelmez.
      final ch = IOWebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
        pingInterval: const Duration(seconds: 20),
      );
      _channel = ch;
      await ch.ready;
      _retry = 0;
      _connected = true;
      _sub = ch.stream.listen(
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

  /// Arka plana/kilit ekranina gecerken: SUNUCUYA "offline oluyorum" de, sonra kapat.
  /// NEDEN: iOS/Android surec donunca TCP FIN cogu zaman FLUSH OLMUYOR -> sunucu soketi
  /// ~yari-acik tutup kullaniciyi 35sn "online" saniyor -> gelen aramaya push ATILMIYOR
  /// (kilit ekraninda calmiyor / art arda 2. arama gitmiyor). Zaten kurulu, yazilabilir
  /// sokete tek kucuk 'bg' cercevesi TCP-close el sikismasindan daha guvenilir flush olur;
  /// sunucu bunu alinca ANINDA offline dusurur -> sonraki arama push/VoIP-push alir.
  /// Dinleyici de iptal edilir ki gecikmis onDone yetim baglanti biraktirmasin.
  Future<void> goOffline() async {
    _closed = true;
    _connected = false;
    try {
      _channel?.sink.add(jsonEncode({'type': 'bg'})); // once offline sinyali
    } catch (_) {}
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
  }

  Future<void> close() async {
    _closed = true;
    _connected = false;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    await _channel?.sink.close();
  }
}

final wsProvider = Provider<WsService>((ref) {
  final ws = WsService(ref.read(storageProvider));
  ref.onDispose(ws.close);
  return ws;
});
