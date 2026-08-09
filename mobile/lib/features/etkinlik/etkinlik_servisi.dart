import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 77 — ETKINLIKLER (kullanici emri: "etkinlikler olacak, bu etkinlik
/// soldaki menuye tikladiginda ekranda olacak").
///
/// ⚠️ GECMIS ETKINLIK SILINMEZ — "gecmis" bir SORGU SUZGECIDIR (`gecmis=1`).
///    Veri politikasi geregi hicbir sey silinmiyor (CLAUDE.md, 8 Agu karari).
class EtkinlikServisi {
  EtkinlikServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<List<Etkinlik>> liste({
    String kategori = '',
    String q = '',
    String il = '',
    bool gecmis = false,
    bool benim = false,
  }) async {
    final r = await _api.get(
      '/etkinlikler',
      queryParameters: {
        if (kategori.isNotEmpty) 'kategori': kategori,
        if (q.isNotEmpty) 'q': q,
        if (il.isNotEmpty) 'il': il,
        if (gecmis) 'gecmis': '1',
        if (benim) 'benim': '1',
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['etkinlikler'] as List?) ?? [])
        .map((e) => Etkinlik.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Etkinlik> detay(String id) async {
    final r = await _api.get('/etkinlikler/$id');
    return Etkinlik.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<String> olustur(Map<String, dynamic> govde) async {
    final r = await _api.post('/etkinlikler', data: govde);
    return (r.data['id'] ?? '').toString();
  }

  /// [durum]: katiliyor | ilgileniyor | vazgecti
  Future<void> katil(String id, String durum) =>
      _api.post('/etkinlikler/$id/katil', data: {'durum': durum});

  Future<List<Map<String, dynamic>>> katilimcilar(String id) async {
    final r = await _api.get('/etkinlikler/$id/katilimcilar');
    return ((r.data as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> sil(String id) => _api.delete('/etkinlikler/$id');
}

/// ⚠️ `backend/internal/etkinlik/handler.go` ILE AYNI liste olmali.
/// ⚠️ Bu liste YALNIZ SECICIDE kullanilir. Listelerde/detayda gosterilen ad
///    SUNUCUDAN gelir (`kategori_ad`) — boylece sunucuya yeni kategori
///    eklendiginde ESKI SURUM istemciler de dogru adi gosterir ve drift
///    yalnizca "secilebilirlik" ile sinirli kalir.
const etkinlikKategorileri = <String, String>{
  'konser': 'Konser',
  'spor': 'Spor',
  'egitim': 'Eğitim & Atölye',
  'yemek': 'Yemek & İçecek',
  'sanat': 'Sanat & Sergi',
  'festival': 'Festival',
  'is': 'İş & Networking',
  'topluluk': 'Topluluk',
  'cocuk': 'Çocuk & Aile',
  'diger': 'Diğer',
};

class Etkinlik {
  Etkinlik({
    required this.id,
    required this.olusturanId,
    required this.olusturanAd,
    required this.olusturanAvatarMediaId,
    required this.baslik,
    required this.aciklama,
    required this.kategori,
    required this.kategoriAd,
    required this.baslangic,
    required this.bitis,
    required this.konum,
    required this.il,
    required this.ilce,
    required this.mediaIds,
    required this.ucretsiz,
    required this.fiyatKurus,
    required this.kontenjan,
    required this.durum,
    required this.katilanSayisi,
    required this.benimDurumum,
  });

  final String id;
  final String olusturanId;
  final String olusturanAd;
  final String? olusturanAvatarMediaId;
  final String baslik;
  final String aciklama;
  final String kategori;

  /// ⚠️ SUNUCUDAN gelir — yerel sabit listeye guvenilmez (bkz. yukaridaki serh).
  final String kategoriAd;
  final DateTime? baslangic;
  final DateTime? bitis;
  final String konum;
  final String il;
  final String ilce;
  final List<String> mediaIds;
  final bool ucretsiz;

  /// ⚠️ KURUS. Ekranda `fiyatMetni` ile bicimlenir — ham deger gosterilmez.
  final int fiyatKurus;

  /// 0 = sinirsiz.
  final int kontenjan;
  final String durum;
  int katilanSayisi;

  /// '' | katiliyor | ilgileniyor | vazgecti
  String benimDurumum;

  bool get gecmisMi => baslangic != null && baslangic!.isBefore(DateTime.now());

  bool get kontenjanDoldu =>
      kontenjan > 0 &&
      katilanSayisi >= kontenjan &&
      benimDurumum != 'katiliyor';

  String get fiyatMetni {
    if (ucretsiz || fiyatKurus <= 0) return 'Ücretsiz';
    final tl = fiyatKurus ~/ 100;
    final kr = fiyatKurus % 100;
    return kr == 0 ? '$tl ₺' : '$tl,${kr.toString().padLeft(2, '0')} ₺';
  }

  static Etkinlik fromJson(Map<String, dynamic> m) => Etkinlik(
    id: (m['id'] ?? '').toString(),
    olusturanId: (m['olusturan_id'] ?? '').toString(),
    olusturanAd: (m['olusturan_ad'] ?? '').toString(),
    olusturanAvatarMediaId: m['olusturan_avatar_media_id'] as String?,
    baslik: (m['baslik'] ?? '').toString(),
    aciklama: (m['aciklama'] ?? '').toString(),
    kategori: (m['kategori'] ?? 'diger').toString(),
    kategoriAd: (m['kategori_ad'] ?? 'Diğer').toString(),
    baslangic: DateTime.tryParse((m['baslangic'] ?? '').toString())?.toLocal(),
    bitis: DateTime.tryParse((m['bitis'] ?? '').toString())?.toLocal(),
    konum: (m['konum'] ?? '').toString(),
    il: (m['il'] ?? '').toString(),
    ilce: (m['ilce'] ?? '').toString(),
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    ucretsiz: m['ucretsiz'] == true,
    fiyatKurus: (m['fiyat_kurus'] as num?)?.toInt() ?? 0,
    kontenjan: (m['kontenjan'] as num?)?.toInt() ?? 0,
    durum: (m['durum'] ?? 'yayinda').toString(),
    katilanSayisi: (m['katilan_sayisi'] as num?)?.toInt() ?? 0,
    benimDurumum: (m['benim_durumum'] ?? '').toString(),
  );
}

/// "12 Ağustos Sal · 20:00" — etkinlik tarihi.
/// ⚠️ `intl` KULLANILMADI: paket zaten bagimli ama Turkce yerel ayar verisi
///    icin `initializeDateFormatting` gerekiyor ve o uygulama acilisina ek yuk.
///    Sabit Turkce diziler daha ucuz ve daha ongorulebilir.
String etkinlikZamani(DateTime? t) {
  if (t == null) return '';
  const aylar = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  final s =
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
  return '${t.day} ${aylar[t.month - 1]} ${gunler[t.weekday - 1]} · $s';
}

final etkinlikServisiProvider = Provider<EtkinlikServisi>(EtkinlikServisi.new);
