import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 76b — HIKAYE (STORY) ISTEMCISI.
///
/// ⚠️ "24 SAAT" GORUNURLUKTUR, SILME DEGIL: sunucu satiri SILMEZ, yalnizca
///    `created_at > now() - 24h` suzgeciyle gizler (bu projede VERI SILINMEZ —
///    CLAUDE.md kullanici karari). Istemci acisindan fark yok, ama ileride
///    "hikaye arsivi" ozelligi EK IS GEREKTIRMEYECEK.
class StoryServisi {
  StoryServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  /// Anasayfa seridi — KULLANICI BASINA gruplanmis.
  /// ⚠️ Gruplamayi SUNUCU yapar: istemci de yapsaydi "hepsi izlendi mi" hesabi
  ///    iki yerde yasar ve DRIFT ederdi (turu 72b/H dersi).
  Future<List<StoryKullanici>> serit() async {
    final r = await _api.get('/stories');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['users'] as List?) ?? [])
        .map((e) => StoryKullanici.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Story>> kullanici(String userId) async {
    final r = await _api.get('/stories/$userId');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['stories'] as List?) ?? [])
        .map((e) => Story.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> paylas({
    required String mediaId,
    required String kind,
    String metin = '',
  }) async {
    final r = await _api.post(
      '/stories',
      data: {'media_id': mediaId, 'kind': kind, 'metin': metin},
    );
    return (r.data['id'] ?? '').toString();
  }

  /// ⚠️ IDEMPOTENT — izleyicide ileri-geri gidildikce tekrar cagrilir.
  Future<void> izlendi(String storyId) => _api.post('/stories/$storyId/view');

  Future<List<Map<String, dynamic>>> izleyenler(String storyId) async {
    final r = await _api.get('/stories/$storyId/viewers');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> sil(String storyId) => _api.delete('/stories/$storyId');
}

/// Seritteki TEK halka (bir kullanicinin aktif hikayeleri).
class StoryKullanici {
  StoryKullanici({
    required this.userId,
    required this.ad,
    required this.kullaniciAdi,
    required this.avatarMediaId,
    required this.adet,
    required this.hepsiIzlendi,
    required this.benim,
  });

  final String userId;
  final String ad;
  final String kullaniciAdi;
  final String? avatarMediaId;
  final int adet;

  /// Halka GRI mi RENKLI mi cizilecek.
  bool hepsiIzlendi;
  final bool benim;

  static StoryKullanici json(Map<String, dynamic> m) => StoryKullanici(
    userId: (m['user_id'] ?? '').toString(),
    ad: (m['name'] ?? '').toString(),
    kullaniciAdi: (m['username'] ?? '').toString(),
    avatarMediaId: m['avatar_media_id'] as String?,
    adet: (m['adet'] as num?)?.toInt() ?? 0,
    hepsiIzlendi: m['hepsi_izlendi'] == true,
    benim: m['benim'] == true,
  );
}

class Story {
  Story({
    required this.id,
    required this.mediaId,
    required this.kind,
    required this.metin,
    required this.createdAt,
    required this.izledim,
    required this.izlenme,
  });

  final String id;
  final String mediaId;
  final String kind; // image | video
  final String metin;
  final String createdAt;
  bool izledim;

  /// ⚠️ YALNIZ SAHIBINE doner (baskasinin hikayesinde sunucu bu alani
  ///    GONDERMEZ — Instagram'da da yok).
  final int izlenme;

  bool get videoMu => kind == 'video';

  static Story json(Map<String, dynamic> m) => Story(
    id: (m['id'] ?? '').toString(),
    mediaId: (m['media_id'] ?? '').toString(),
    kind: (m['kind'] ?? 'image').toString(),
    metin: (m['metin'] ?? '').toString(),
    createdAt: (m['created_at'] ?? '').toString(),
    izledim: m['izledim'] == true,
    izlenme: (m['izlenme'] as num?)?.toInt() ?? -1,
  );
}

final storyServisiProvider = Provider<StoryServisi>(StoryServisi.new);
