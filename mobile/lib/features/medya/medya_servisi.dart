import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';

/// ⚠️⚠️ TURU 74 — MEDYA YUKLEME SERVISI (presign -> PUT -> commit).
///
/// AKIS:
///   1. `POST /media/upload` — sunucu presigned PUT URL'i doner.
///   2. Dosya **DOGRUDAN R2'ye** yuklenir (API'den GECMEZ).
///   3. `POST /media/{id}/commit` — sunucu boyut/tip/GPS dogrular.
///
/// ⚠️⚠️ AYRI Dio ORNEGI (`_r2`) KULLANILIR — bu KRITIK:
///   Projenin ana Dio'sunda `Authorization` basligi ve Sentry araclari var.
///   · `Authorization` R2'ye giderse **imza BOZULUR** (403 SignatureDoesNotMatch) —
///     SigV4 imzalanan basliklarin disinda fazladan yetkilendirme basligi kabul etmez.
///   · Sentry aracı imzali URL'i breadcrumb'a yazar -> **imza SIZAR** (o URL'le
///     herkes dosyayi okuyabilir/yazabilir).
/// ⚠️ YAPMA: R2 isteklerini `apiProvider`daki Dio ile yapma.
class MedyaServisi {
  MedyaServisi(this._ref);

  final Ref _ref;

  /// ⚠️ Temiz Dio: interceptor YOK, Authorization YOK, Sentry YOK.
  /// Timeout uzun cunku 16 MB video yavas hatta dakikalar surebilir.
  static final _r2 = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 10),
    receiveTimeout: const Duration(minutes: 2),
    // ⚠️ R2 hata govdesini XML doner; Dio'nun JSON cozmeye calismasini engelle.
    responseType: ResponseType.plain,
    validateStatus: (_) => true, // durum kodunu KENDIMIZ yorumluyoruz
  ));

  /// Gorseli sikistir + EXIF temizle.
  ///
  /// ⚠️ EXIF TEMIZLEME BURADA OLUR VE ZORUNLUDUR: telefon fotografi EXIF'inde
  ///     TAM KOORDINAT tasir ve kullanici bunu BILMEZ. Sunucu da ayrica kontrol
  ///     edip GPS bulursa REDDEDER (422) — yani burasi bozulursa yukleme
  ///     SESSIZCE degil, GORUNUR sekilde basarisiz olur.
  /// ⚠️ `keepExif: false` VARSAYILAN ama ACIKCA yaziyoruz (birisi degistirmesin).
  ///
  /// Hedef: uzun kenar 1600px, kalite 82 -> tipik 3-5 MB foto ~250-400 KB'a duser.
  static Future<File?> gorseliHazirla(File kaynak) async {
    try {
      final dizin = await getTemporaryDirectory();
      final hedef =
          '${dizin.path}/gz_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final sonuc = await FlutterImageCompress.compressAndGetFile(
        kaynak.absolute.path,
        hedef,
        quality: 82,
        minWidth: 1600,
        minHeight: 1600,
        keepExif: false, // ⚠️ GIZLILIK: konum/cihaz bilgisi ATILIR
        format: CompressFormat.jpeg,
      );
      if (sonuc == null) return null;
      return File(sonuc.path);
    } catch (e) {
      unawaited(Sentry.captureMessage('medya sikistirma HATASI: $e'));
      return null;
    }
  }

  /// Yukleme. [ilerleme] 0.0-1.0.
  /// Doner: `media_id` (basarisizsa istisna firlatir — cagiran kullaniciya soyler).
  ///
  /// ⚠️ ISTISNA FIRLATIR (sessizce null DONMEZ): "gonderdim sandim ama gitmemis"
  ///     bu projede defalarca yasandi; hata GORUNUR olmali.
  Future<String> yukle({
    required File dosya,
    required String kind, // image | video | audio | document | avatar
    required String mime,
    String fileName = '',
    int width = 0,
    int height = 0,
    int durationMs = 0,
    String waveform = '',
    File? kucukResim,
    void Function(double)? ilerleme,
    CancelToken? iptal,
  }) async {
    final api = _ref.read(apiProvider);
    final bayt = await dosya.length();

    // ⚠️ Content-MD5 SUNUCUYA BEYAN EDILIR ve IMZAYA girer. Yuklenen icerik
    //     farkliysa R2 `BadDigest` ile REDDEDER — butunluk boylece ag katmaninda
    //     garanti altina alinir (yarim yuklenen dosya "basarili" gorunmez).
    final md5b64 = base64.encode(md5.convert(await dosya.readAsBytes()).bytes);

    int kucukBayt = 0;
    String kucukMd5 = '';
    if (kucukResim != null) {
      kucukBayt = await kucukResim.length();
      kucukMd5 = base64.encode(md5.convert(await kucukResim.readAsBytes()).bytes);
    }

    // ---- 1) presign
    final pres = await api.post('/media/upload', data: {
      'kind': kind,
      'mime': mime,
      'bytes': bayt,
      'md5': md5b64,
      'file_name': fileName,
      'width': width,
      'height': height,
      'duration_ms': durationMs,
      'waveform': waveform,
      'thumb_bytes': kucukBayt,
      'thumb_md5': kucukMd5,
    });
    final mediaId = pres.data['media_id'] as String;
    final yuklemeURL = pres.data['upload_url'] as String;
    final kucukURL = pres.data['thumb_url'] as String?;

    // ---- 2) R2'ye DOGRUDAN PUT
    // ⚠️ Basliklar presign'da IMZALANAN'larla BIREBIR AYNI olmali; tek harf
    //     farki 403 SignatureDoesNotMatch uretir ve sebebini SOYLEMEZ.
    final res = await _r2.put(
      yuklemeURL,
      data: dosya.openRead(),
      cancelToken: iptal,
      options: Options(headers: {
        'Content-Type': mime,
        'Content-MD5': md5b64,
        Headers.contentLengthHeader: bayt,
      }),
      onSendProgress: (g, t) {
        if (t > 0 && ilerleme != null) ilerleme(g / t * 0.95);
      },
    );
    if (res.statusCode != 200) {
      // ⚠️ GERCEK Sentry olayi: 403 = imza sorunu (sunucu tarafi bozulmus olabilir).
      unawaited(Sentry.captureMessage(
          'medya R2 PUT basarisiz: HTTP ${res.statusCode} kind=$kind'));
      throw Exception('Dosya yüklenemedi (${res.statusCode})');
    }

    if (kucukResim != null && kucukURL != null) {
      // ⚠️ Kucuk resim yuklenemezse ANA yukleme IPTAL EDILMEZ — sunucu kucuk resmi
      //     zorunlu tutmaz; balon tam gorseli kucultup gosterir.
      try {
        await _r2.put(kucukURL,
            data: kucukResim.openRead(),
            cancelToken: iptal,
            options: Options(headers: {
              'Content-Type': 'image/jpeg',
              'Content-MD5': kucukMd5,
              Headers.contentLengthHeader: kucukBayt,
            }));
      } catch (_) {}
    }

    // ---- 3) commit (dogrulama SUNUCUDA)
    ilerleme?.call(0.98);
    await api.post('/media/$mediaId/commit');
    ilerleme?.call(1.0);
    return mediaId;
  }

  /// Indirme adresi. ⚠️ 600 saniye gecerli — SAKLAMA.
  /// ⚠️ Onbellek anahtari olarak URL KULLANILAMAZ (her cagrida degisir);
  ///     `media_id` kullanilir (bkz. `medyaOnbellekAnahtari`).
  Future<Map<String, dynamic>> adres(String mediaId) async {
    final res = await _ref.read(apiProvider).get('/media/$mediaId/url');
    return (res.data as Map).cast<String, dynamic>();
  }
}

/// ⚠️ `cached_network_image` varsayilan olarak URL'i onbellek anahtari yapar.
///     Bizim URL'ler HER ISTEKTE FARKLI (imza + zaman damgasi) — varsayilan
///     birakilirsa ayni gorsel HER ACILISTA YENIDEN INDIRILIR (kullanici verisi
///     + R2 Class B ucreti). Anahtar SABIT olmali.
String medyaOnbellekAnahtari(String mediaId, {bool kucuk = false}) =>
    kucuk ? 'gz_t_$mediaId' : 'gz_$mediaId';

final medyaServisiProvider = Provider<MedyaServisi>((ref) => MedyaServisi(ref));
