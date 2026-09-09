import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// ⚠️⚠️⚠️ TURU 180z — **VIDEO POSTERI (ILK KARE)** — kullanici emri:
/// *"videolarda on izleme olsun"*.
///
/// **NEDEN GONDERIM ANINDA URETILIYOR:**
/// Sunucu ffmpeg CALISTIRMIYOR; `POST /media/upload` yalnizca `thumb_bytes`
/// gonderilirse AYRI bir PUT adresi (`<anahtar>_t`) veriyor ve `thumb_key`
/// sutununu dolduruyor (`media/handler.go:162-165`). Yani posteri **ISTEMCI**
/// uretip yuklemek zorunda.
///
/// ⚠️⚠️ **BALONDA CANLI OYNATICI KURULAMAZ**: `video_player` iOS'ta
///	`initialize()` sirasinda AVAudioSession'a dokunur ve **SUREN ARAMAYI
///	SAGIRLASTIRIR** (turu 76b/77b'de olculdu). Bu yuzden liste/balon
///	tarafinda kareyi oynaticidan almak YASAK — poster tek cikis yolu.
///
/// ⚠️⚠️⚠️ **NEDEN HARICI PAKET DEGIL (OLCULDU):**
///	`video_thumbnail` (**compileSdkVersion 33**) ve bakimli forku
///	`flutter_video_thumbnail_plus` (**34**) denendi; ikisi de Gradle'i
///	`:...:checkDebugAarMetadata` ile PATLATTI —
///	  *"Dependency ':flutter_plugin_android_lifecycle' requires ... version
///	   36 or later ... is currently compiled against android-34."*
///	Root `build.gradle.kts`'ten `compileSdk` yukseltmek de AGP 9 +
///	`dev.flutter.flutter-plugin-loader` duzeninde TUTMADI.
///	Ayni sinif turu 87'de `geocoding 3.0.0` ile yasandi.
///	Bu yuzden poster projenin **KENDI KANAL DESENIYLE** uretiliyor
///	(`Pusula.kt` / `GebzemPusula` ile ayni yaklasim): ucuncu parti riski
///	YOK, `compileSdk` catismasi YAPISAL OLARAK imkansiz.
///	⚠️ YAPMA: bunun icin harici bir thumbnail paketi ekleme.
///
/// ⚠️ **EN IYI CABA**: uretim patlarsa `null` doner ve video POSTERSIZ
///	yuklenir (eski davranis). Poster yuzunden bir video gonderiminin
///	basarisiz olmasi kabul edilemez.
///
/// ⚠️ Kanal adi UC YERDE BIREBIR ayni olmak zorunda — uyusmazlik DERLEME
///	ZAMANI YAKALANMAZ, `MissingPluginException` olarak calisma aninda
///	cikar ve asagida `catch` ile yutulur (turu 65b dersi):
///	  · burasi (`kPosterKanali`)
///	  · `android/.../MainActivity.kt`
///	  · `ios/Runner/AppDelegate.swift`
const kPosterKanali = 'gebzem/poster';

const _kanal = MethodChannel(kPosterKanali);

Future<File?> videoPosteriUret(File video) async {
  try {
    final dizin = await getTemporaryDirectory();
    // ⚠️ Ad CAKISMAZ: ayni oturumda iki video gonderilirse ikinci poster
    //	birincinin uzerine yazip YANLIS kareyi yukleyebilirdi.
    final hedef =
        '${dizin.path}/poster_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final yol = await _kanal.invokeMethod<String>('uret', {
      'video': video.path,
      'hedef': hedef,
      // ⚠️ 640 px: balon/izgara en fazla ~320 dp cizer (dpr 2'de 640 px).
      //	Daha buyugu bedava degil — poster de kotadan DUSER ve her
      //	acilista indirilir.
      'enBoy': 640,
      'kalite': 70,
    });
    if (yol == null) return null;
    final f = File(yol);
    if (!await f.exists()) return null;
    // ⚠️ 0 baytlik dosya: sunucu `thumb_bytes: 0` gorurse thumb adresi
    //	URETMEZ ve zincir sessizce postersiz devam eder — ama once BURADA
    //	elemek daha durust (bos PUT'a hic girilmez).
    if (await f.length() <= 0) return null;
    return f;
  } catch (e) {
    // ⚠️ GERCEK Sentry olayi DEGIL, breadcrumb: poster uretilememesi bir
    //	ariza degil, kabul edilen bir DEGRADASYON. Gurultu yapmasin.
    Sentry.addBreadcrumb(Breadcrumb(message: 'video posteri uretilemedi: $e'));
    return null;
  }
}
