import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 75 — SOSYAL KATMAN ISTEMCISI (gonderi + akis + etkilesim + takip).
///
/// ⚠️ TEK KAYNAK: gonderi/profil/takip ile ilgili HER REST cagrisi buradan gecer.
///    Ekranlara `api.post('/posts/...')` DAGITMA — bu projede ayni mantigin
///    kopyalanmasi defalarca "drift" uretti (turu 56 mesgulluk kontrolu dersi).
class SosyalServisi {
  SosyalServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  // ---------------- GONDERI ----------------

  /// Gonderi olustur. [tur]: foto | video | reels | yazi.
  /// ⚠️ Sunucu tutarliligi dogrular (medya tipiyse medya ZORUNLU, yazi ise
  ///    medya OLMAZ) — istemci de once kontrol eder ki kullanici bosuna beklemesin.
  Future<String> gonderiOlustur({
    required String tur,
    String metin = '',
    List<String> mediaIds = const [],
    bool yorumKapali = false,
  }) async {
    final r = await _api.post(
      '/posts',
      data: {
        'tur': tur,
        'metin': metin,
        'media_ids': mediaIds,
        'yorum_kapali': yorumKapali,
      },
    );
    return r.data['id'] as String;
  }

  Future<void> gonderiSil(String id) => _api.delete('/posts/$id');

  /// Ana sayfa akisi. [before] imlec (son gonderinin `created_at` degeri).
  ///
  /// ⚠️ IMLEC (cursor) sayfalama — `offset` DEGIL. Offset olsaydi biz kaydirirken
  ///    yeni gonderi gelince tum satirlar KAYAR ve ayni gonderi iki kez gorunurdu.
  Future<({List<Gonderi> gonderiler, bool kesfet})> akis({
    String? before,
  }) async {
    final r = await _api.get(
      '/feed',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return (
      gonderiler: ((m['posts'] as List?) ?? [])
          .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
          .toList(),
      kesfet: m['kesfet'] == true,
    );
  }

  /// Tek gonderi (bildirimden / derin baglantidan acilir).
  Future<Gonderi> gonderiGetir(String id) async {
    final r = await _api.get('/posts/$id');
    return Gonderi.json((r.data as Map).cast<String, dynamic>());
  }

  /// Reels akisi — takipten BAGIMSIZ (TikTok/Instagram deseni).
  Future<List<Gonderi>> reels({String? before}) async {
    final r = await _api.get(
      '/reels',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Gonderi>> kullaniciGonderileri(
    String userId, {
    String? before,
    String? tur,
  }) async {
    final r = await _api.get(
      '/users/$userId/posts',
      queryParameters: {
        if (before != null) 'before': before,
        if (tur != null) 'tur': tur,
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---------------- ETKILESIM ----------------

  Future<void> begen(String postId) => _api.post('/posts/$postId/like');
  Future<void> begeniGeriAl(String postId) =>
      _api.delete('/posts/$postId/like');
  Future<void> kaydet(String postId) => _api.post('/posts/$postId/save');
  Future<void> kaydetKaldir(String postId) =>
      _api.delete('/posts/$postId/save');

  /// Kaydettiklerim.
  /// ⚠️ Sunucu erisimi YENIDEN degerlendirir (yazar sonradan gizli hesaba
  ///    gecmis ya da engellemis olabilir) — liste kaydettigimden AZ olabilir.
  Future<List<Gonderi>> kaydedilenler({String? before}) async {
    final r = await _api.get(
      '/users/me/saved',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => Gonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> begenenler(String postId) async {
    final r = await _api.get('/posts/$postId/likes');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Yorum>> yorumlar(String postId) async {
    final r = await _api.get('/posts/$postId/comments');
    return ((r.data as List?) ?? [])
        .map((e) => Yorum.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<int> yorumYaz(String postId, String metin, {int? parentId}) async {
    final r = await _api.post(
      '/posts/$postId/comments',
      data: {'metin': metin, if (parentId != null) 'parent_id': parentId},
    );
    return (r.data['id'] as num).toInt();
  }

  Future<void> yorumSil(int yorumId) => _api.delete('/comments/$yorumId');

  // ---------------- TAKIP / PROFIL ----------------

  /// Doner: `true` = onayli takip, `false` = istek BEKLEMEDE (gizli hesap).
  Future<bool> takipEt(String userId) async {
    final r = await _api.post('/users/$userId/follow');
    return (r.data is Map) && r.data['durum'] == 'onayli';
  }

  Future<void> takibiBirak(String userId) =>
      _api.delete('/users/$userId/follow');
  Future<void> istekOnayla(String userId) =>
      _api.post('/users/$userId/follow/approve');
  Future<void> istekReddet(String userId) =>
      _api.delete('/users/$userId/follow/approve');

  Future<Profil> profil(String userId) async {
    final r = await _api.get('/users/$userId/profile');
    return Profil.json((r.data as Map).cast<String, dynamic>());
  }

  /// [tur]: followers | following
  Future<List<Map<String, dynamic>>> takipListesi(
    String userId,
    String tur,
  ) async {
    final r = await _api.get('/users/$userId/$tur');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> takipIstekleri() async {
    final r = await _api.get('/users/me/follow-requests');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> gizlilikAyarla(bool gizli) =>
      _api.patch('/users/me/privacy', data: {'gizli_hesap': gizli});

  // ---------------- BILDIRIM ----------------

  Future<List<Map<String, dynamic>>> bildirimler() async {
    final r = await _api.get('/notifications');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> bildirimleriOkudum() => _api.post('/notifications/read');
}

/// ⚠️ DEGISTIRILEBILIR (mutable) MODEL — bilincli karar.
///    Begeni/kaydetme "iyimser guncelleme" ile ANINDA cizilir; immutable olsaydi
///    her dokunusta tum liste yeniden kurulur ve kaydirma konumu ZIPLARDI.
class Gonderi {
  Gonderi({
    required this.id,
    required this.yazarId,
    required this.tur,
    required this.metin,
    required this.mediaIds,
    required this.begeniSayisi,
    required this.yorumSayisi,
    required this.goruntulenme,
    required this.yorumKapali,
    required this.createdAt,
    required this.yazarAd,
    required this.yazarUsername,
    required this.yazarAvatar,
    required this.yazarAvatarMediaId,
    required this.begendim,
    required this.kaydettim,
  });

  final String id;
  final String yazarId;
  final String tur;
  final String metin;
  final List<String> mediaIds;
  int begeniSayisi;
  int yorumSayisi;

  /// ⚠️ Yalniz REELS ve GONDERI DETAYINDA artar (akista artmaz — orada 20 kart
  ///    tek istekte gelir ama cogu HIC gorulmez, saymak sayiyi YALAN yapardi).
  final int goruntulenme;
  final bool yorumKapali;
  final String createdAt;
  final String yazarAd;
  final String yazarUsername;
  final String yazarAvatar;
  final String? yazarAvatarMediaId;
  bool begendim;
  bool kaydettim;

  bool get videoMu => tur == 'video' || tur == 'reels';

  static Gonderi json(Map<String, dynamic> m) => Gonderi(
    id: (m['id'] ?? '').toString(),
    yazarId: (m['author_id'] ?? '').toString(),
    tur: (m['tur'] ?? 'yazi').toString(),
    metin: (m['metin'] ?? '').toString(),
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    begeniSayisi: (m['begeni_sayisi'] as num?)?.toInt() ?? 0,
    yorumSayisi: (m['yorum_sayisi'] as num?)?.toInt() ?? 0,
    goruntulenme: (m['goruntulenme'] as num?)?.toInt() ?? 0,
    yorumKapali: m['yorum_kapali'] == true,
    createdAt: (m['created_at'] ?? '').toString(),
    yazarAd: (m['yazar_ad'] ?? '').toString(),
    yazarUsername: (m['yazar_username'] ?? '').toString(),
    yazarAvatar: (m['yazar_avatar'] ?? '').toString(),
    yazarAvatarMediaId: m['yazar_avatar_media_id'] as String?,
    begendim: m['begendim'] == true,
    kaydettim: m['kaydettim'] == true,
  );
}

class Yorum {
  Yorum({
    required this.id,
    required this.parentId,
    required this.metin,
    required this.begeniSayisi,
    required this.createdAt,
    required this.yazarId,
    required this.yazarAd,
    required this.yazarUsername,
    required this.yazarAvatar,
    required this.yazarAvatarMediaId,
    required this.begendim,
  });

  final int id;
  final int? parentId;
  final String metin;
  int begeniSayisi;
  final String createdAt;
  final String yazarId;
  final String yazarAd;
  final String yazarUsername;
  final String yazarAvatar;
  final String? yazarAvatarMediaId;
  bool begendim;

  static Yorum json(Map<String, dynamic> m) => Yorum(
    id: (m['id'] as num?)?.toInt() ?? 0,
    parentId: (m['parent_id'] as num?)?.toInt(),
    metin: (m['metin'] ?? '').toString(),
    begeniSayisi: (m['begeni_sayisi'] as num?)?.toInt() ?? 0,
    createdAt: (m['created_at'] ?? '').toString(),
    yazarId: (m['yazar_id'] ?? '').toString(),
    yazarAd: (m['yazar_ad'] ?? '').toString(),
    yazarUsername: (m['yazar_username'] ?? '').toString(),
    yazarAvatar: (m['yazar_avatar'] ?? '').toString(),
    yazarAvatarMediaId: m['yazar_avatar_media_id'] as String?,
    begendim: m['begendim'] == true,
  );
}

class Profil {
  Profil({
    required this.id,
    required this.username,
    required this.ad,
    required this.hakkinda,
    required this.avatarUrl,
    required this.avatarMediaId,
    required this.gizli,
    required this.baglanti,
    required this.takipciSayisi,
    required this.takipSayisi,
    required this.gonderiSayisi,
    required this.takipEdiyorum,
    required this.istekBekliyor,
    required this.beniTakipEdiyor,
    required this.engelledim,
  });

  final String id;
  final String username;
  final String ad;
  final String hakkinda;
  final String avatarUrl;
  final String? avatarMediaId;
  final bool gizli;
  final String baglanti;
  int takipciSayisi;
  final int takipSayisi;
  final int gonderiSayisi;
  bool takipEdiyorum;
  bool istekBekliyor;
  final bool beniTakipEdiyor;
  bool engelledim;

  /// Gizli hesabin gonderilerini goremiyoruz (kendisi ya da onayli takipci degilsek).
  bool get icerikKilitli => gizli && !takipEdiyorum;

  static Profil json(Map<String, dynamic> m) {
    final il = ((m['iliski'] as Map?) ?? {}).cast<String, dynamic>();
    return Profil(
      id: (m['id'] ?? '').toString(),
      username: (m['username'] ?? '').toString(),
      ad: (m['name'] ?? '').toString(),
      hakkinda: (m['about'] ?? '').toString(),
      avatarUrl: (m['avatar_url'] ?? '').toString(),
      avatarMediaId: m['avatar_media_id'] as String?,
      gizli: m['gizli_hesap'] == true,
      baglanti: (m['baglanti'] ?? '').toString(),
      takipciSayisi: (m['takipci_sayisi'] as num?)?.toInt() ?? 0,
      takipSayisi: (m['takip_sayisi'] as num?)?.toInt() ?? 0,
      gonderiSayisi: (m['gonderi_sayisi'] as num?)?.toInt() ?? 0,
      // ⚠️ ALAN ADLARI backend `takipDurumResp` json etiketleriyle BIREBIR:
      //    takip_ediyor_mu · bekliyor_mu · beni_takip_ediyor_mu · engelli.
      //    (Yanlis ad SESSIZCE `false` uretir — dugme "Takip Et" gorunur ve
      //     kullanici zaten takip ettigi kisiyi tekrar takip etmeye calisir.)
      takipEdiyorum: il['takip_ediyor_mu'] == true,
      istekBekliyor: il['bekliyor_mu'] == true,
      beniTakipEdiyor: il['beni_takip_ediyor_mu'] == true,
      engelledim: il['engelli'] == true,
    );
  }
}

final sosyalServisiProvider = Provider<SosyalServisi>(
  (ref) => SosyalServisi(ref),
);
