import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 75 — KANAL ISTEMCISI (WhatsApp "Kanallar" deseni).
///
/// ⚠️ Kanal, SOHBET hattindan AYRI bir uc kumesi kullanir. Sebep sunucu
///    tarafinda yazili (`internal/kanal/handler.go`): mevcut mesaj hatti her
///    mesajda UYE BASINA `message_receipts` satiri yaziyor; 10.000 aboneli
///    kanalda tek gonderi 10.000 sorgu demek olurdu.
/// ⚠️ YAPMA: kanali `chats_provider` uzerinden gecirmeye calisma.
class KanalServisi {
  KanalServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<String> olustur({
    required String ad,
    String kullaniciAdi = '',
    String aciklama = '',
    String avatarMediaId = '',
  }) async {
    final r = await _api.post(
      '/channels',
      data: {
        'ad': ad,
        'kullanici_adi': kullaniciAdi,
        'aciklama': aciklama,
        'avatar_media_id': avatarMediaId,
      },
    );
    return r.data['id'] as String;
  }

  Future<void> duzenle(
    String id, {
    required String ad,
    String aciklama = '',
    String avatarMediaId = '',
  }) async {
    await _api.patch(
      '/channels/$id',
      data: {'ad': ad, 'aciklama': aciklama, 'avatar_media_id': avatarMediaId},
    );
  }

  Future<void> kapat(String id) => _api.delete('/channels/$id');

  /// Abone oldugum kanallar (okunmamis sayisiyla).
  Future<List<Kanal>> listem() async {
    final r = await _api.get('/channels');
    return ((r.data as List?) ?? [])
        .map((e) => Kanal.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Kanal>> kesfet({String q = ''}) async {
    final r = await _api.get(
      '/channels/kesfet',
      queryParameters: {if (q.isNotEmpty) 'q': q},
    );
    return ((r.data as List?) ?? [])
        .map((e) => Kanal.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Kanal> detay(String id) async {
    final r = await _api.get('/channels/$id');
    return Kanal.json((r.data as Map).cast<String, dynamic>());
  }

  Future<void> aboneOl(String id) => _api.post('/channels/$id/subscribe');
  Future<void> abonelikBirak(String id) =>
      _api.delete('/channels/$id/subscribe');
  Future<void> sessizAyarla(String id, bool sessiz) =>
      _api.patch('/channels/$id/mute', data: {'sessiz': sessiz});
  Future<void> okundu(String id) => _api.post('/channels/$id/read');

  Future<List<KanalGonderi>> gonderiler(String id, {String? before}) async {
    final r = await _api.get(
      '/channels/$id/posts',
      queryParameters: {if (before != null) 'before': before},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['posts'] as List?) ?? [])
        .map((e) => KanalGonderi.json((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<int> gonderiPaylas(
    String id, {
    String metin = '',
    List<String> mediaIds = const [],
  }) async {
    final r = await _api.post(
      '/channels/$id/posts',
      data: {'metin': metin, 'media_ids': mediaIds},
    );
    return (r.data['id'] as num).toInt();
  }

  Future<void> gonderiSil(int postId) => _api.delete('/channel-posts/$postId');
  Future<void> begen(int postId) => _api.post('/channel-posts/$postId/like');
  Future<void> begeniGeriAl(int postId) =>
      _api.delete('/channel-posts/$postId/like');
}

class Kanal {
  Kanal({
    required this.id,
    required this.ad,
    required this.kullaniciAdi,
    required this.aciklama,
    required this.avatarMediaId,
    required this.aboneSayisi,
    required this.gonderiSayisi,
    required this.okunmamis,
    required this.sessiz,
    required this.sonMetin,
    required this.sonZaman,
    required this.aboneMiyim,
    required this.yetkiliMiyim,
    required this.sahipId,
  });

  final String id;
  final String ad;
  final String kullaniciAdi;
  final String aciklama;
  final String? avatarMediaId;
  int aboneSayisi;
  final int gonderiSayisi;
  int okunmamis;
  bool sessiz;
  final String sonMetin;
  final String sonZaman;
  bool aboneMiyim;
  final bool yetkiliMiyim;
  final String sahipId;

  static Kanal json(Map<String, dynamic> m) => Kanal(
    id: (m['id'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    kullaniciAdi: (m['kullanici_adi'] ?? '').toString(),
    aciklama: (m['aciklama'] ?? '').toString(),
    avatarMediaId: m['avatar_media_id'] as String?,
    aboneSayisi: (m['abone_sayisi'] as num?)?.toInt() ?? 0,
    gonderiSayisi: (m['gonderi_sayisi'] as num?)?.toInt() ?? 0,
    okunmamis: (m['okunmamis'] as num?)?.toInt() ?? 0,
    sessiz: m['sessiz'] == true,
    sonMetin: (m['son_metin'] ?? '').toString(),
    sonZaman: (m['son_zaman'] ?? '').toString(),
    // ⚠️ `/channels` (listem) ucu `abone_miyim` DONDURMEZ — o listede zaten
    //    yalniz abone olunan kanallar var. Alan yoksa `true` varsayilir,
    //    yoksa "Abone Ol" dugmesi kendi kanalinda bile gorunurdu.
    aboneMiyim: m.containsKey('abone_miyim') ? m['abone_miyim'] == true : true,
    yetkiliMiyim: m['yetkili_miyim'] == true,
    sahipId: (m['sahip_id'] ?? '').toString(),
  );
}

class KanalGonderi {
  KanalGonderi({
    required this.id,
    required this.metin,
    required this.mediaIds,
    required this.begeniSayisi,
    required this.goruntulenme,
    required this.createdAt,
    required this.yazarId,
    required this.yazarAd,
    required this.begendim,
  });

  final int id;
  final String metin;
  final List<String> mediaIds;
  int begeniSayisi;
  final int goruntulenme;
  final String createdAt;
  final String yazarId;
  final String yazarAd;
  bool begendim;

  static KanalGonderi json(Map<String, dynamic> m) => KanalGonderi(
    id: (m['id'] as num?)?.toInt() ?? 0,
    metin: (m['metin'] ?? '').toString(),
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    begeniSayisi: (m['begeni_sayisi'] as num?)?.toInt() ?? 0,
    goruntulenme: (m['goruntulenme'] as num?)?.toInt() ?? 0,
    createdAt: (m['created_at'] ?? '').toString(),
    yazarId: (m['yazar_id'] ?? '').toString(),
    yazarAd: (m['yazar_ad'] ?? '').toString(),
    begendim: m['begendim'] == true,
  );
}

final kanalServisiProvider = Provider<KanalServisi>((ref) => KanalServisi(ref));
