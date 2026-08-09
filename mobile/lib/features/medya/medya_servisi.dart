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
/// ⚠️⚠️ TURU 76 — ISTEMCI TARAFI BOYUT TAVANLARI.
///
/// ⚠️ SUNUCUYLA (backend/internal/media/limits.go `Tavanlar`) AYNI OLMALI.
///    Ayrisirsa iki yonlu zarar olur: istemci daha genisse kullanici dosyayi
///    yukler ve commit'te 413 yer (bosa giden veri + zaman); istemci daha darsa
///    sunucunun izin verdigi dosyayi reddeder ve sebebi anlasilmaz.
/// ⚠️ Bu tablo TEK KAYNAK: dort cagiran (gonderi, sohbet, kanal, profil) da
///    `yukle()` uzerinden gectigi icin kontrol tek yerde uygulanir.
const kTavanlar = <String, int>{
  'image': 8 << 20,
  'avatar': 4 << 20,
  // ⚠️ TURU 78 — PROFIL KAPAGI. Sunucudaki `media/limits.go` ile AYNI deger
  //    olmali; burada eksik olsaydi istemci tavani BILEMEZ ve kullanici
  //    sunucunun reddettigi dosyayi bosuna yuklemeye baslardi.
  'kapak': 8 << 20,
  'audio': 16 << 20,
  'video': 100 << 20, // kullanici karari 8 Agu
  'document': 32 << 20,
};

class MedyaServisi {
  MedyaServisi(this._ref);

  final Ref _ref;

  /// ⚠️ Temiz Dio: interceptor YOK, Authorization YOK, Sentry YOK.
  ///
  /// ⚠️⚠️ TURU 76 — `sendTimeout` BURADAN KALDIRILDI, ISTEK BASINA veriliyor.
  ///    Dio'da `sendTimeout` gonderimin TOPLAM suresidir (parca arasi bosluk
  ///    degil). Sabit 10 dakika, 100 MB dosya icin **1.40 Mbit/sn ZORUNLU
  ///    MINIMUM HIZ** demekti: kalabalik 4G'de, kenar hucrede ya da kotasi
  ///    dolmus tarifede yukleme 10. dakikada `request.abort()` ile kesilir,
  ///    kullanici "Paylaşılamadı" gorur ve NEDENINI ogrenemezdi.
  ///    Artik sure, sunucunun dondurdugu `expires_sec` ile HIZALANIYOR — yani
  ///    imza ne kadar gecerliyse yukleme o kadar surebilir.
  /// ⚠️ YAPMA: buraya sabit bir `sendTimeout` geri koyma.
  static final _r2 = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
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

  /// Dosyanin MD5'ini AKIS uzerinden hesaplar (base64).
  ///
  /// ⚠️ Bellek SABIT kalir: `openRead()` parcalar halinde besler, `md5.bind`
  ///    her parcayi isler. 100 MB dosyada bile ~64 KB'lik tamponlarla ilerler.
  /// ⚠️ `await for` yerine `.single` kullaniliyor: `Hash.bind` TEK bir `Digest`
  ///    yayan bir akis dondurur.
  static Future<String> _dosyaMd5(File f) async {
    final digest = await md5.bind(f.openRead()).single;
    return base64.encode(digest.bytes);
  }

  static String _mb(int bayt) => '${(bayt / (1 << 20)).round()} MB';

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

    // ⚠️⚠️ TURU 76 — ISTEMCI TARAFI BOYUT KONTROLU. Eskiden HIC YOKTU: kullanici
    //    300 MB'lik bir galeri videosunu secebiliyor, istemci once dosyanin
    //    TAMAMINI okuyup MD5 aliyor (saniyeler + yuzlerce MB RAM), sonra
    //    sunucudan 413 yiyordu. Yani REDDEDILECEGI BASTAN BELLI olan dosya icin
    //    cihaz bosuna yoruluyordu.
    // ⚠️ Tablo SUNUCUYLA AYNI olmali (backend/internal/media/limits.go).
    //    Ayrisirsa kullanici "istemci gecirdi, sunucu reddetti" yasar.
    final tavan = kTavanlar[kind];
    if (tavan != null && bayt > tavan) {
      throw Exception('Dosya çok büyük (en fazla ${_mb(tavan)})');
    }

    // ⚠️ Content-MD5 SUNUCUYA BEYAN EDILIR ve IMZAYA girer. Yuklenen icerik
    //     farkliysa R2 `BadDigest` ile REDDEDER — butunluk boylece ag katmaninda
    //     garanti altina alinir (yarim yuklenen dosya "basarili" gorunmez).
    //
    // ⚠️⚠️ TURU 76 — AKIS UZERINDEN HESAPLANIYOR (`readAsBytes` KALDIRILDI).
    //    Eski kod dosyanin TAMAMINI tek seferde belege okuyordu:
    //     · 100 MB'lik tek `Uint8List` -> dusuk bellekli Android'de uygulama
    //       isletim sistemi tarafindan OLDURULUR,
    //     · saf-Dart MD5 UI is parcaciginda SENKRON kostugu icin arayuz
    //       saniyelerce DONAR (ANR).
    //    `md5.bind(dosya.openRead())` parca parca besler: bellek sabit kalir.
    // ⚠️ YAPMA: `readAsBytes()`e geri donme.
    final md5b64 = await _dosyaMd5(dosya);

    int kucukBayt = 0;
    String kucukMd5 = '';
    if (kucukResim != null) {
      kucukBayt = await kucukResim.length();
      kucukMd5 = await _dosyaMd5(kucukResim);
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

    // ⚠️⚠️ TURU 76 — GONDERIM SURESI SUNUCUYLA HIZALANIR.
    //    Sunucu imza omrunu dosya boyutuna gore hesapliyor (`PresignSuresi`:
    //    20 KB/sn kotu-durum hizina gore, en fazla 90 dk) ve `expires_sec` ile
    //    donduruyordu — ama istemci bu alani HIC OKUMUYORDU ve sabit 10 dakikada
    //    yuklemeyi kesiyordu. Iki sure ayrisinca kullanici, imza hala gecerliyken
    //    "Paylaşılamadı" goruyordu.
    // ⚠️ 30 sn pay: imza dolmadan HEMEN once kesmek yerine, sunucunun 403'unu
    //    gormeyi tercih ederiz (hata mesaji daha anlamli olur).
    final gecerlilik = (pres.data['expires_sec'] as num?)?.toInt() ?? 600;
    final gonderimSuresi = Duration(seconds: gecerlilik > 60 ? gecerlilik - 30 : 60);

    // ---- 2) R2'ye DOGRUDAN PUT
    // ⚠️ Basliklar presign'da IMZALANAN'larla BIREBIR AYNI olmali; tek harf
    //     farki 403 SignatureDoesNotMatch uretir ve sebebini SOYLEMEZ.
    final res = await _r2.put(
      yuklemeURL,
      data: dosya.openRead(),
      cancelToken: iptal,
      options: Options(
        // ⚠️ Sunucunun verdigi imza omruyle hizali (bkz. yukaridaki serh).
        sendTimeout: gonderimSuresi,
        headers: {
          'Content-Type': mime,
          'Content-MD5': md5b64,
          Headers.contentLengthHeader: bayt,
        },
      ),
      onSendProgress: (g, t) {
        if (t > 0 && ilerleme != null) ilerleme(g / t * 0.95);
      },
    );
    if (res.statusCode != 200) {
      // ⚠️ GERCEK Sentry olayi: 403 = imza sorunu (sunucu tarafi bozulmus olabilir).
      unawaited(Sentry.captureMessage(
          'medya R2 PUT basarisiz: HTTP ${res.statusCode} kind=$kind'
          ' bayt=$bayt sure=${gonderimSuresi.inSeconds}sn'));
      // ⚠️ 403 buyuk dosyada GENELDE "imza suresi doldu" demektir — kullaniciya
      //    anlamli mesaj ver, ham durum kodu degil.
      if (res.statusCode == 403 && bayt > (16 << 20)) {
        throw Exception('Yükleme çok uzun sürdü, tekrar deneyin');
      }
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
