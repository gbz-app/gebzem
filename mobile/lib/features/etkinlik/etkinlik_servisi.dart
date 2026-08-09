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

  /// ⚠️⚠️ TURU 78b — `basMin`/`basMaks` EKLENDI (denetim: OLU YETENEK).
  ///    Sunucu bu iki suzgeci turu 77'den beri destekliyordu ama istemci
  ///    **HIC GONDERMIYORDU**; serhi "hizli kartlarin on kosulu" diyordu ama
  ///    o kartlar hicbir ekranda yoktu. Bu, projede alti kez tekrarlayan
  ///    "sunucuda var, ekranda yok" sinifiydi. Artik "Bugün" / "Bu hafta sonu"
  ///    kartlari bunlari kullaniyor.
  Future<List<Etkinlik>> liste({
    String kategori = '',
    String q = '',
    String il = '',
    bool gecmis = false,
    bool benim = false,
    DateTime? basMin,
    DateTime? basMaks,
  }) async {
    final r = await _api.get(
      '/etkinlikler',
      queryParameters: {
        if (kategori.isNotEmpty) 'kategori': kategori,
        if (q.isNotEmpty) 'q': q,
        if (il.isNotEmpty) 'il': il,
        if (gecmis) 'gecmis': '1',
        if (benim) 'benim': '1',
        // ⚠️ Sunucu timestamptz bekliyor — UTC ISO-8601 gonderilir.
        if (basMin != null) 'bas_min': basMin.toUtc().toIso8601String(),
        if (basMaks != null) 'bas_maks': basMaks.toUtc().toIso8601String(),
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

  /// ⚠️ TURU 78 — DUZENLEME. Sunucuda bu uc HIC YOKTU: bir yazim hatasini
  ///    duzeltmenin tek yolu etkinligi silip yeniden acmakti ve o zaman TUM
  ///    KATILIMCILAR kayboluyordu.
  Future<void> guncelle(String id, Map<String, dynamic> govde) =>
      _api.patch('/etkinlikler/$id', data: govde);

  // ---- KADRO (oyuncu / sarkici / konusmaci)
  //
  // ⚠️ "Kadro" ile "katilimci" AYRI kavramlar: kadro SAHNEDEKILER, katilim RSVP.
  Future<List<Kadro>> kadro(String id) async {
    final r = await _api.get('/etkinlikler/$id/kadro');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['kadro'] as List?) ?? [])
        .map((e) => Kadro.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> kadroEkle(
    String id, {
    required String ad,
    String rol = '',
    String? userId,
  }) => _api.post(
    '/etkinlikler/$id/kadro',
    data: {'ad': ad, 'rol': rol, if (userId != null) 'user_id': userId},
  );

  Future<void> kadroSil(String id, String kadroId) =>
      _api.delete('/etkinlikler/$id/kadro/$kadroId');
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
    required this.mediaKinds,
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

  /// TURU 78 — mediaKinds[i] <-> mediaIds[i] (image/video/yok).
  /// ⚠️ Sunucu SIRA KORUYARAK donduruyor; istemci indeksle eslestirir.
  final List<String> mediaKinds;
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
    mediaKinds: ((m['media_kinds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
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

/// Etkinlik KADROSU — sahnedeki kisi (sarkici / oyuncu / konusmaci).
///
/// ⚠️⚠️ [userId] NULL OLABILIR ve bu KASITLI: kadroya yazilacak kisi genelde
///    unlu biridir ve uygulamaya KAYITLI DEGILDIR. Zorunlu olsaydi ozellik
///    pratikte kullanilamazdi (bir konsere sarkicinin adini yazamazdiniz).
///    Kayitliysa profiline baglanir.
///
/// ⚠️ AYRI FOTOGRAF ALANI YOK: kayitli kisi kendi avatarini kullanir, kayitsiz
///    kisi harf avatari alir. Yeni bir `media_id` sutunu `media.erisebilir()`
///    icine yeni bir dal gerektirirdi ve o dal unutuldugunda medya
///    YUKLEYENDEN BASKA HERKESE 403 doner (turu 75b/77 sinifi). Risk YAPISAL
///    OLARAK kaldirildi.
class Kadro {
  Kadro({
    required this.id,
    required this.userId,
    required this.ad,
    required this.rol,
    required this.username,
    required this.avatarMediaId,
  });

  final String id;
  final String? userId;
  final String ad;
  final String rol;
  final String username;
  final String? avatarMediaId;

  static Kadro fromJson(Map<String, dynamic> m) => Kadro(
    id: (m['id'] ?? '').toString(),
    userId: m['user_id'] as String?,
    ad: (m['ad'] ?? '').toString(),
    rol: (m['rol'] ?? '').toString(),
    username: (m['username'] ?? '').toString(),
    avatarMediaId: m['avatar_media_id'] as String?,
  );
}
