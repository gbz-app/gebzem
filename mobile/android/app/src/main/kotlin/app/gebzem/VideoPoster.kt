package app.gebzem

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/// ⚠️⚠️⚠️ TURU 180z — VIDEO POSTERI (ILK KARE) — kullanici emri:
/// *"videolarda on izleme olsun"*.
///
/// **NEDEN NATIVE, NEDEN HARICI PAKET DEGIL (OLCULDU):**
/// `video_thumbnail` (compileSdkVersion **33**) ve bakimli forku
/// `flutter_video_thumbnail_plus` (**34**) denendi; ikisi de Gradle'i
/// `:...:checkDebugAarMetadata` ile PATLATTI —
///   *"Dependency ':flutter_plugin_android_lifecycle' requires ... version 36
///    or later ... is currently compiled against android-34."*
/// Root `build.gradle.kts`'te `subprojects { plugins.withId ... }` ile
/// eklentilerin `compileSdk`ini yukseltmek DE tutmadi (AGP 9 + Flutter'in
/// `dev.flutter.flutter-plugin-loader` duzeni). Ayni sinif turu 87'de
/// `geocoding 3.0.0` ile yasandi.
///
/// Bu yuzden poster **projenin KENDI kanal deseniyle** uretiliyor
/// (`Pusula.kt` / `TelefonDurumu.kt` ile ayni yaklasim): ucuncu parti riski
/// YOK, `compileSdk` catismasi YAPISAL OLARAK imkansiz.
///
/// ⚠️ `MediaMetadataRetriever` Android API 10'dan beri var; ek izin
///    GEREKTIRMEZ (dosya yolu zaten secicinin verdigi gecici kopya).
/// ⚠️ `release()` **`finally`de** cagrilir: birakilmazsa native kod-cozucu
///    ornegi SIZAR ve birkac videodan sonra secici acilmaz olur.
object VideoPoster {

    /// [videoYolu]'ndaki videodan bir kare cikarip [hedefYolu]'na JPEG yazar.
    /// Basarisizsa `null` doner — cagiran POSTERSIZ devam eder (en iyi caba).
    fun uret(videoYolu: String, hedefYolu: String, enBoy: Int, kalite: Int): String? {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(videoYolu)
            // ⚠️ Kare **1 SANIYEDEN** alinir, 0'dan DEGIL: bircok videonun ilk
            //    karesi siyah bir gecistir ve poster bombos cikardi.
            //    Video 1 sn'den kisaysa `OPTION_CLOSEST_SYNC` en yakin anahtar
            //    kareye duser — yani kisa videoda da bir kare GARANTIDIR.
            val kare: Bitmap = r.getFrameAtTime(
                1_000_000L,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            ) ?: return null

            // ⚠️ Olcekleme ZORUNLU: ham kare 1080x1920 olabilir ve poster
            //    kullanicinin AYLIK DEPOLAMA kotasindan duser; balon/izgara
            //    en fazla ~320 dp cizer.
            val olcekli = if (kare.width > enBoy) {
                val oran = enBoy.toFloat() / kare.width
                Bitmap.createScaledBitmap(
                    kare,
                    enBoy,
                    (kare.height * oran).toInt().coerceAtLeast(1),
                    true,
                )
            } else {
                kare
            }

            FileOutputStream(File(hedefYolu)).use { cikti ->
                olcekli.compress(Bitmap.CompressFormat.JPEG, kalite, cikti)
            }
            if (olcekli !== kare) olcekli.recycle()
            kare.recycle()
            return hedefYolu
        } catch (_: Exception) {
            return null
        } finally {
            try {
                r.release()
            } catch (_: Exception) {
            }
        }
    }
}
