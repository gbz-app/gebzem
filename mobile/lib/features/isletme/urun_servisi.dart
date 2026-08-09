import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 77 — ISLETME URUNLERI / MENU + AI.
///
/// ⚠️ AYRI DOSYA (isletme_servisi.dart'a EKLENMEDI): o dosya 200+ satir ve
///    profil sorumlulugu tasiyor; urun + AI ikinci bir sorumluluk olurdu.
class UrunServisi {
  UrunServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<List<Urun>> liste(String isletmeId) async {
    final r = await _api.get('/users/$isletmeId/urunler');
    final m = (r.data as Map).cast<String, dynamic>();
    return ((m['urunler'] as List?) ?? [])
        .map((e) => Urun.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> ekle(Map<String, dynamic> govde) async {
    final r = await _api.post('/isletme/urunler', data: govde);
    return (r.data['id'] ?? '').toString();
  }

  Future<void> guncelle(String id, Map<String, dynamic> govde) =>
      _api.patch('/isletme/urunler/$id', data: govde);

  Future<void> sil(String id) => _api.delete('/isletme/urunler/$id');
}

class Urun {
  Urun({
    required this.id,
    required this.isletmeId,
    required this.ad,
    required this.aciklama,
    required this.bolum,
    required this.fiyatKurus,
    required this.mediaIds,
    required this.sira,
    required this.durum,
  });

  final String id;
  final String isletmeId;
  String ad;
  String aciklama;
  String bolum;
  int fiyatKurus;
  final List<String> mediaIds;
  final int sira;
  String durum;

  String get fiyatMetni {
    if (fiyatKurus <= 0) return '';
    final tl = fiyatKurus ~/ 100;
    final kr = fiyatKurus % 100;
    return kr == 0 ? '$tl ₺' : '$tl,${kr.toString().padLeft(2, '0')} ₺';
  }

  static Urun fromJson(Map<String, dynamic> m) => Urun(
    id: (m['id'] ?? '').toString(),
    isletmeId: (m['isletme_id'] ?? '').toString(),
    ad: (m['ad'] ?? '').toString(),
    aciklama: (m['aciklama'] ?? '').toString(),
    bolum: (m['bolum'] ?? '').toString(),
    fiyatKurus: (m['fiyat_kurus'] as num?)?.toInt() ?? 0,
    mediaIds: ((m['media_ids'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    sira: (m['sira'] as num?)?.toInt() ?? 0,
    durum: (m['durum'] ?? 'yayinda').toString(),
  );
}

/// ⚠️⚠️ AI SERVISI — ozellik SUNUCUDA ACIK DEGILSE ARAYUZDE HIC CIZILMEZ.
///
/// `aiDurumProvider` once `GET /ai/durum` sorar; `acik == false` ise AI
/// dugmeleri GOSTERILMEZ. Bu kapi OLMASAYDI kullanici dugmeye basar ve 503
/// alirdi — bu projede tekrar eden "ozellik var gorunup fiilen yok" hatasi.
class AiServisi {
  AiServisi(this._ref);
  final Ref _ref;

  Dio get _api => _ref.read(apiProvider);

  Future<AiDurum> durum() async {
    try {
      final r = await _api.get('/ai/durum');
      final m = (r.data as Map).cast<String, dynamic>();
      return AiDurum(
        acik: m['acik'] == true,
        kalan: (m['kalan'] as num?)?.toInt() ?? 0,
        kota: (m['gunluk_kota'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      // ⚠️ Hata durumunda KAPALI varsayilir — yanlislikla dugme cizmektense
      //    cizmemek daha durust.
      return const AiDurum(acik: false, kalan: 0, kota: 0);
    }
  }

  /// Menu fotografindan ya da aciklamadan yapilandirilmis menu ONERISI.
  /// ⚠️ Sonuc DOGRUDAN KAYDEDILMEZ; kullanici gozden gecirip onaylar.
  Future<String> menu({String mediaId = '', String metin = ''}) async {
    final r = await _api.post(
      '/ai/menu',
      data: {'media_id': mediaId, 'metin': metin},
    );
    return (r.data['sonuc'] ?? '').toString();
  }

  /// Urun fotografindan/adindan satis metni.
  Future<String> urunMetni({String mediaId = '', String metin = ''}) async {
    final r = await _api.post(
      '/ai/urun-metni',
      data: {'media_id': mediaId, 'metin': metin},
    );
    return (r.data['sonuc'] ?? '').toString();
  }

  /// Fotograftan sorun tespiti.
  Future<String> danisma({required String mediaId, String metin = ''}) async {
    final r = await _api.post(
      '/ai/danisma',
      data: {'media_id': mediaId, 'metin': metin},
    );
    return (r.data['sonuc'] ?? '').toString();
  }
}

class AiDurum {
  const AiDurum({required this.acik, required this.kalan, required this.kota});
  final bool acik;
  final int kalan;
  final int kota;
}

final urunServisiProvider = Provider<UrunServisi>(UrunServisi.new);
final aiServisiProvider = Provider<AiServisi>(AiServisi.new);

/// ⚠️ SUREC OMURLU: AI acik mi sorusu her ekranda tekrar sorulmaz.
final aiDurumProvider = FutureProvider<AiDurum>(
  (ref) => ref.read(aiServisiProvider).durum(),
);
