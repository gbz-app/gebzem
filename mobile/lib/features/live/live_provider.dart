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

  /// Yayina davet (Bolum 5): {"sent": n} doner
  Future<int> davet(String id, List<String> userIds) async {
    final res = await _ref
        .read(apiProvider)
        .post('/streams/$id/invite', data: {'user_ids': userIds});
    return ((res.data as Map)['sent'] as num?)?.toInt() ?? 0;
  }

  // Konuk sistemi + listeler (Bolum 6 I1)
  Future<Map<String, dynamic>> izleyiciler(String id) async {
    final res = await _ref.read(apiProvider).get('/streams/$id/viewers');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> hediyeListesi(String id) async {
    final res = await _ref.read(apiProvider).get('/streams/$id/gifts');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> istekler(String id) async {
    final res = await _ref.read(apiProvider).get('/streams/$id/join-requests');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> katilIstek(String id, {bool cancel = false}) =>
      _post('/streams/$id/join-request', {'cancel': cancel});
  Future<void> konukAl(String id, String userId) =>
      _post('/streams/$id/guest/accept', {'user_id': userId});
  Future<void> konukReddet(String id, String userId) =>
      _post('/streams/$id/guest/decline', {'user_id': userId});
  Future<void> konukCikar(String id, String userId) =>
      _post('/streams/$id/guest/remove', {'user_id': userId});
  Future<void> konukAyril(String id) => _post('/streams/$id/guest/leave');
  Future<void> konukYenile(String id) => _post('/streams/$id/guest/refresh');

  /// TEST TURU 8/11: nabiz sunucudaki GERCEK konuk LISTESINI dondurur — kacan
  /// guest.left/joined sinyalinin mutabakat agi (istemci 15sn'de kendini duzeltir).
  Future<List<String>> nabiz(String id) async {
    final res = await _ref.read(apiProvider).post('/streams/$id/heartbeat');
    return ((res.data as Map?)?['guest_ids'] as List?)?.cast<String>() ?? const [];
  }
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
