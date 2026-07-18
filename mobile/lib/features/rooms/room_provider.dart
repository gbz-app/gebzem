import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// SPACES (sesli oda) REST kopruleri — oda-yayin-plani.md Bolum 1 sozlesmesi.
/// WS olaylari (room.*) RoomScreen'de wsProvider.events uzerinden dinlenir
/// (ws.dart olay-agnostik; yeni tip eklemek icin ws'e dokunmak GEREKMEZ).
class RoomsApi {
  RoomsApi(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> olustur(String baslik) async {
    final res = await _ref.read(apiProvider).post('/rooms', data: {'title': baslik});
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> katil(String id) async {
    final res = await _ref.read(apiProvider).post('/rooms/$id/join');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> detay(String id) async {
    final res = await _ref.read(apiProvider).get('/rooms/$id');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> ayril(String id) => _post('/rooms/$id/leave');
  Future<void> elKaldir(String id, bool kalkik) =>
      _post('/rooms/$id/raise-hand', {'raised': kalkik});
  Future<void> konusmaciYap(String id, String userId) =>
      _post('/rooms/$id/promote', {'user_id': userId});
  Future<void> dinleyiciYap(String id, String userId) =>
      _post('/rooms/$id/demote', {'user_id': userId});
  Future<void> sustur(String id, String userId) =>
      _post('/rooms/$id/mute', {'user_id': userId});
  Future<void> at(String id, String userId) =>
      _post('/rooms/$id/remove', {'user_id': userId});
  Future<void> bitir(String id) => _post('/rooms/$id/end');

  Future<void> _post(String yol, [Map<String, dynamic>? data]) async {
    await _ref.read(apiProvider).post(yol, data: data);
  }
}

final roomsApiProvider = Provider<RoomsApi>(RoomsApi.new);

/// Kesfet listesi (canli odalar). Sekme acilinca + pull-to-refresh + periyodik invalidate.
final roomsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiProvider).get('/rooms');
  return (res.data as List).cast<Map<String, dynamic>>();
});
