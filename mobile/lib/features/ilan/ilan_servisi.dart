import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 77 — ILANLAR + HIZMETLER (kullanici emri: "ilanlar olacak
/// sahibinden gibi araba ev 2.el alim satim vs" + "hizmetler kategorisi").
///
/// ⚠️⚠️ KATEGORI AGACI **SUNUCUDAN** GELIR, ISTEMCIDE KOPYA YOK.
///    Turu 77 denetim bulgusu: bu projede "ayni listenin Go + Dart iki kopyasi"
///    itiraf edilmis bir drift bombasi (turu 72b/H). Ustelik agac `alanlar`
///    dizisi tasidigi icin ILAN VERME FORMU DA sunucudan uretiliyor — yeni bir
///    alan eklemek icin istemci guncellemesi GEREKMIYOR.
/// ⚠️ YAPMA: Dart'a kategori/tur sabiti yazma.
class IlanServisi {
  IlanServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<List<IlanTuru>> agac() async {
    final r = await _api.get('/ilan-kategoriler');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['turler'] as List?) ?? [])
        .map((e) => IlanTuru.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Ilan>> liste({
    String tur = '',
    String kategori = '',
    String il = '',
    String ilce = '',
    String q = '',
    int? minKurus,
    int? maksKurus,
    bool benim = false,
    bool favori = false,
  }) async {
    final r = await _api.get(
      '/ilanlar',
      queryParameters: {
        if (tur.isNotEmpty) 'tur': tur,
        if (kategori.isNotEmpty) 'kategori': kategori,
        if (il.isNotEmpty) 'il': il,
        if (ilce.isNotEmpty) 'ilce': ilce,
        if (q.isNotEmpty) 'q': q,
        if (minKurus != null) 'min': minKurus,
        if (maksKurus != null) 'maks': maksKurus,
        if (benim) 'benim': '1',
        if (favori) 'favori': '1',
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['ilanlar'] as List?) ?? [])
        .map((e) => Ilan.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Ilan> detay(String id) async {
    final r = await _api.get('/ilanlar/$id');
    return Ilan.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<String> olustur(Map<String, dynamic> govde) async {
    final r = await _api.post('/ilanlar', data: govde);
    return (r.data['id'] ?? '').toString();
  }

  Future<void> guncelle(String id, Map<String, dynamic> govde) =>
      _api.patch('/ilanlar/$id', data: govde);

  Future<void> favoriEkle(String id) => _api.post('/ilanlar/$id/favori');
  Future<void> favoriSil(String id) => _api.delete('/ilanlar/$id/favori');
}

class IlanTuru {
  IlanTuru({
    required this.anahtar,
    required this.ad,
    required this.kategoriler,
    required this.alanlar,
  });

  final String anahtar;
  final String ad;
  final List<({String anahtar, String ad})> kategoriler;
  final List<IlanAlani> alanlar;

  static IlanTuru fromJson(Map<String, dynamic> m) => IlanTuru(
    anahtar: (m['anahtar'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    kategoriler: ((m['kategoriler'] as List?) ?? [])
        .map(
          (e) => (
            anahtar: ((e as Map)['anahtar'] ?? '').toString(),
            ad: (e['ad'] ?? '').toString(),
          ),
        )
        .toList(),
    alanlar: ((m['alanlar'] as List?) ?? [])
        .map((e) => IlanAlani.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Tipe ozel alan tanimi — FORM BUNDAN URETILIR.
class IlanAlani {
  IlanAlani({
    required this.anahtar,
    required this.ad,
    required this.tip,
    required this.secenekler,
    required this.birim,
  });

  final String anahtar;
  final String ad;

  /// metin | sayi | secim
  final String tip;
  final List<String> secenekler;
  final String birim;

  static IlanAlani fromJson(Map<String, dynamic> m) => IlanAlani(
    anahtar: (m['anahtar'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    tip: (m['tip'] ?? 'metin').toString(),
    secenekler: ((m['secenekler'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    birim: (m['birim'] ?? '').toString(),
  );
}

class Ilan {
  Ilan({
    required this.id,
    required this.sahibiId,
    required this.sahibiAd,
    required this.sahibiAvatarMediaId,
    required this.tur,
    required this.kategori,
    required this.baslik,
    required this.aciklama,
    required this.fiyatKurus,
    required this.fiyatGizli,
    required this.il,
    required this.ilce,
    required this.mediaIds,
    required this.ozellikler,
    required this.durum,
    required this.goruntulenme,
    required this.createdAt,
    required this.favorim,
  });

  final String id;
  final String sahibiId;
  final String sahibiAd;
  final String? sahibiAvatarMediaId;
  final String tur;
  final String kategori;
  String baslik;
  String aciklama;

  /// ⚠️ KURUS. Ekranda `fiyatMetni` ile bicimlenir.
  int fiyatKurus;
  final bool fiyatGizli;
  final String il;
  final String ilce;
  final List<String> mediaIds;
  final Map<String, dynamic> ozellikler;
  String durum;
  final int goruntulenme;
  final String createdAt;

  /// ⚠️ DEGISEBILIR: iyimser guncelleme (kalp) icin.
  bool favorim;

  String get fiyatMetni {
    if (fiyatGizli || fiyatKurus <= 0) return 'Fiyat belirtilmemiş';
    // ⚠️ Binlik ayirici ELLE: `intl` NumberFormat icin yerel ayar yuklemesi
    //    gerekiyor ve uygulama acilisina yuk bindiriyor.
    final tl = (fiyatKurus ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < tl.length; i++) {
      if (i > 0 && (tl.length - i) % 3 == 0) buf.write('.');
      buf.write(tl[i]);
    }
    return '$buf ₺';
  }

  bool get yayindaMi => durum == 'yayinda';

  static Ilan fromJson(Map<String, dynamic> m) => Ilan(
    id: (m['id'] ?? '').toString(),
    sahibiId: (m['sahibi_id'] ?? '').toString(),
    sahibiAd: (m['sahibi_ad'] ?? '').toString(),
    sahibiAvatarMediaId: m['sahibi_avatar_media_id'] as String?,
    tur: (m['tur'] ?? '').toString(),
    kategori: (m['kategori'] ?? '').toString(),
    baslik: (m['baslik'] ?? '').toString(),
    aciklama: (m['aciklama'] ?? '').toString(),
    fiyatKurus: (m['fiyat_kurus'] as num?)?.toInt() ?? 0,
    fiyatGizli: m['fiyat_gizli'] == true,
    il: (m['il'] ?? '').toString(),
    ilce: (m['ilce'] ?? '').toString(),
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    ozellikler: (m['ozellikler'] as Map?)?.cast<String, dynamic>() ?? {},
    durum: (m['durum'] ?? 'yayinda').toString(),
    goruntulenme: (m['goruntulenme'] as num?)?.toInt() ?? 0,
    createdAt: (m['created_at'] ?? '').toString(),
    favorim: m['favorim'] == true,
  );
}

/// Tur/kategori agaci — SUREC OMURLU onbellek.
/// ⚠️ `FutureProvider`: agac nadiren degisir, her ekranda yeniden cekmek
///    gereksiz. Uygulama yeniden acilinca tazelenir.
final ilanAgaciProvider = FutureProvider<List<IlanTuru>>(
  (ref) => ref.read(ilanServisiProvider).agac(),
);

final ilanServisiProvider = Provider<IlanServisi>(IlanServisi.new);
