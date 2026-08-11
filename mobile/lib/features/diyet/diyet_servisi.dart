/// ⚠️⚠️ TURU 91 — DIYET TAKIBI SERVISI.
///
/// Kullanici emri: *"diyetisyende profilde DIYETIM olsun... kalori, yiyecek
/// adi, kalori sayimi, OLCUM vb. olacak; DIYET LISTESI — hangi diyetisyenle
/// calisiyorsan diyet listesi olacak"*.
///
/// ⚠️ SAGLIK VERISI: her okuma sunucuda `diyetErisim()` kapisindan gecer.
///    Istemci tarafinda EK bir kapi YOKTUR ve olmamalidir — iki kapi
///    KACINILMAZ olarak drift eder ve istemci kapisi zaten atlanabilir.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

class DiyetServisi {
  DiyetServisi(this._ref);
  final Ref _ref;
  Dio get _api => _ref.read(apiProvider);

  // ── BAG (RIZA) ──
  Future<void> bagIste({String? diyetisyenID, String? danisanID}) =>
      _api.post('/diyet/bag', data: {
        if (diyetisyenID != null) 'diyetisyen_id': diyetisyenID,
        if (danisanID != null) 'danisan_id': danisanID,
      });

  Future<void> bagDurum(String id, String durum) =>
      _api.patch('/diyet/bag/$id', data: {'durum': durum});

  Future<List<DiyetBag>> baglarim() => _bagListe('/diyet/baglarim');
  Future<List<DiyetBag>> danisanlarim() => _bagListe('/diyet/danisanlarim');

  Future<List<DiyetBag>> _bagListe(String yol) async {
    final r = await _api.get(yol);
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['baglar'] as List?) ?? [])
        .map((e) => DiyetBag.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ── KAYIT ──
  Future<String> kayitEkle({
    required String tur,
    required String tarih,
    String ad = '',
    int kalori = 0,
    Map<String, dynamic> veri = const {},
    String? userID,
  }) async {
    final r = await _api.post('/diyet/kayit', data: {
      'tur': tur,
      'tarih': tarih,
      'ad': ad,
      'kalori': kalori,
      'veri': veri,
      if (userID != null) 'user_id': userID,
    });
    return (r.data['id'] ?? '').toString();
  }

  /// ⚠️ SILME YOK (veri politikasi): `durum='kaldirildi'` ile gizlenir.
  Future<void> kayitKaldir(String id) =>
      _api.patch('/diyet/kayit/$id', data: {'durum': 'kaldirildi'});

  Future<List<DiyetKayit>> kayitlar({
    String? userID,
    String tur = '',
    String bas = '',
    String bit = '',
  }) async {
    final r = await _api.get('/diyet/kayitlar', queryParameters: {
      if (userID != null) 'user_id': userID,
      if (tur.isNotEmpty) 'tur': tur,
      if (bas.isNotEmpty) 'bas': bas,
      if (bit.isNotEmpty) 'bit': bit,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['kayitlar'] as List?) ?? [])
        .map((e) => DiyetKayit.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<DiyetOzet> ozet({String? userID, String bas = '', String bit = ''}) async {
    final r = await _api.get('/diyet/ozet', queryParameters: {
      if (userID != null) 'user_id': userID,
      if (bas.isNotEmpty) 'bas': bas,
      if (bit.isNotEmpty) 'bit': bit,
    });
    return DiyetOzet.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<Besin>> besinler(String q) async {
    final r = await _api.get('/diyet/besinler', queryParameters: {'q': q});
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['besinler'] as List?) ?? [])
        .map((e) => Besin.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// ⚠️ AI kalori TAHMINI — ONERI doner, KAYDETMEZ. Kullanici degeri gorup
  ///    onaylar; AI'nin urettigi bir sayiyi sessizce saglik kaydina yazmak,
  ///    kullanicinin gormedigi bir veriyi ona ait kilardi.
  Future<Besin?> aiKalori({String metin = '', String mediaID = ''}) async {
    final r = await _api.post('/ai/kalori',
        data: {'metin': metin, if (mediaID.isNotEmpty) 'media_id': mediaID});
    final s = r.data['sonuc'];
    if (s is Map) return Besin.fromJson(s.cast<String, dynamic>());
    return null;
  }
}

// ═══════════════════════ MODELLER ═══════════════════════

class DiyetBag {
  DiyetBag({
    required this.id,
    required this.userID,
    required this.ad,
    required this.kullaniciAdi,
    required this.avatarID,
    required this.durum,
    required this.baslatanID,
  });

  final String id;
  final String userID;
  final String ad;
  final String kullaniciAdi;
  final String? avatarID;

  /// bekliyor | aktif | reddedildi | sonlandi
  final String durum;

  /// ⚠️ Istemci "Onayla" dugmesini BUNUNLA cizer: `baslatanID == benimID`
  ///    ise BEKLENEN TARAF KARSISIDIR ve dugme CIZILMEZ. Bu alan olmasaydi
  ///    kullanici kendi istegini onaylamaya calisir ve 404 yerdi.
  final String baslatanID;

  static DiyetBag fromJson(Map<String, dynamic> m) => DiyetBag(
    id: (m['id'] ?? '').toString(),
    userID: (m['user_id'] ?? '').toString(),
    ad: (m['name'] ?? '').toString(),
    kullaniciAdi: (m['username'] ?? '').toString(),
    avatarID: m['avatar_media_id'] as String?,
    durum: (m['durum'] ?? '').toString(),
    baslatanID: (m['baslatan_id'] ?? '').toString(),
  );

  String get durumEtiketi => switch (durum) {
    'bekliyor' => 'Bekliyor',
    'aktif' => 'Aktif',
    'reddedildi' => 'Reddedildi',
    'sonlandi' => 'Sonlandı',
    _ => durum,
  };
}

class DiyetKayit {
  DiyetKayit({
    required this.id,
    required this.userID,
    required this.yazanID,
    required this.tur,
    required this.tarih,
    required this.ad,
    required this.kalori,
    required this.veri,
  });

  final String id;
  final String userID;

  /// ⚠️ `yazanID != userID` ise kaydi DIYETISYEN yazmistir; arayuz
  ///    "Diyetisyeninden" rozeti cizer ve danisan onu SILEMEZ sanmasin diye
  ///    kaldirma yine acik kalir (sunucu ikisine de izin verir).
  final String yazanID;

  /// ogun | olcum | liste
  final String tur;
  final String tarih; // YYYY-MM-DD
  final String ad;
  final int kalori;
  final Map<String, dynamic> veri;

  static DiyetKayit fromJson(Map<String, dynamic> m) => DiyetKayit(
    id: (m['id'] ?? '').toString(),
    userID: (m['user_id'] ?? '').toString(),
    yazanID: (m['yazan_id'] ?? '').toString(),
    tur: (m['tur'] ?? '').toString(),
    tarih: (m['tarih'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    kalori: (m['kalori'] as num?)?.toInt() ?? 0,
    veri: (m['veri'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  /// Ogunun hangi ogun oldugu (kahvalti/ara/ogle/aksam).
  String get ogun => (veri['ogun'] ?? '').toString();
}

class DiyetOzet {
  DiyetOzet({required this.gunler, required this.sonOlcum});

  /// [(tarih, kalori)] — gun basina TOPLAM.
  final List<({String tarih, int kalori})> gunler;
  final Map<String, dynamic> sonOlcum;

  static DiyetOzet fromJson(Map<String, dynamic> m) => DiyetOzet(
    gunler: ((m['gunler'] as List?) ?? [])
        .map((e) => (
              tarih: ((e as Map)['tarih'] ?? '').toString(),
              kalori: (e['kalori'] as num?)?.toInt() ?? 0,
            ))
        .toList(),
    sonOlcum: (m['son_olcum'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  int kaloriGun(String tarih) {
    for (final g in gunler) {
      if (g.tarih == tarih) return g.kalori;
    }
    return 0;
  }
}

class Besin {
  Besin({
    required this.ad,
    required this.kalori,
    required this.gram,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
  });

  final String ad;

  /// ⚠️ Sunucudaki gomulu listede kcal/100g; AI yanitinda ise PORSIYON
  ///    toplamidir. Ikisini ayirt eden sey `gram` alanidir ve hesap
  ///    `ogunKalorisi()` TEK KAYNAGINDA yapilir.
  final int kalori;
  final int gram;
  final double protein;
  final double karbonhidrat;
  final double yag;

  static Besin fromJson(Map<String, dynamic> m) => Besin(
    ad: (m['ad'] ?? '').toString(),
    kalori: (m['kalori'] as num?)?.toInt() ?? 0,
    gram: (m['gram'] as num?)?.toInt() ?? 100,
    protein: (m['protein'] as num?)?.toDouble() ?? 0,
    karbonhidrat: (m['karbonhidrat'] as num?)?.toDouble() ?? 0,
    yag: (m['yag'] as num?)?.toDouble() ?? 0,
  );
}

/// Gomulu liste 100 GRAM basina deger tasir; kullanicinin sectigi miktara
/// gore olceklenir.
///
/// ⚠️ TEK KAYNAK: hesap iki ekranda (ogun ekleme + onizleme) ayri ayri
///    yazilsaydi biri yuvarlama degistirdiginde sayilar TUTMAZDI.
int ogunKalorisi(Besin b, int gram) =>
    gram <= 0 ? 0 : (b.kalori * gram / 100).round();

final diyetServisiProvider = Provider<DiyetServisi>(DiyetServisi.new);
