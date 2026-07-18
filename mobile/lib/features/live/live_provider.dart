import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// CANLI YAYIN REST kopruleri — oda-yayin-plani.md Bolum 2 sozlesmesi.
/// Yayin ici sinyaller (chat/kalp/hediye/sayac/durum) WS DEGIL LiveKit SendData'dan gelir;
/// istemci data YAYINLAYAMAZ (token kapali) — gonderim hep REST -> sunucu relay.
class LiveApi {
  LiveApi(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> baslat(String baslik) async {
    final res = await _ref.read(apiProvider).post('/streams', data: {'title': baslik});
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> izle(String id) async {
    final res = await _ref.read(apiProvider).post('/streams/$id/watch');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> katalog() async {
    final res = await _ref.read(apiProvider).get('/streams/gifts');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> hediye(String id, String gift, String idem) async {
    final res = await _ref
        .read(apiProvider)
        .post('/streams/$id/gift', data: {'gift': gift, 'idem': idem});
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> nabiz(String id) => _post('/streams/$id/heartbeat');
  Future<void> ayril(String id) => _post('/streams/$id/leave');
  Future<void> bitir(String id) => _post('/streams/$id/end');
  Future<void> chat(String id, String text) => _post('/streams/$id/chat', {'text': text});
  Future<void> kalp(String id) => _post('/streams/$id/heart');
  Future<void> kick(String id, String userId) => _post('/streams/$id/kick', {'user_id': userId});
  Future<void> rapor(String id, String neden) => _post('/streams/$id/report', {'reason': neden});

  Future<void> _post(String yol, [Map<String, dynamic>? data]) async {
    await _ref.read(apiProvider).post(yol, data: data);
  }
}

final liveApiProvider = Provider<LiveApi>(LiveApi.new);

/// Kesfet listesi (canli + durakli yayinlar)
final liveStreamsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiProvider).get('/streams');
  return (res.data as List).cast<Map<String, dynamic>>();
});

/// Hediye katalogu (fiyatlar SUNUCUDAN — UI'da sabit tutulmaz)
final giftKatalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiProvider).get('/streams/gifts');
  return (res.data as List).cast<Map<String, dynamic>>();
});
