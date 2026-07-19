package app.gebzem

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// FAZ-6 ANDROID SISTEM PiP (WhatsApp paritesi — kullanici bulgusu: "alta alinca kucuk
/// ekran gelmiyor"): GORUNTULU arama aktifken kullanici HOME'a inerse uygulama yuzen
/// pencereye kuculur; kamera acik kalir (PiP = on planda sayilir), karsi taraf DONMAZ.
/// Flutter tarafi 'gebzem/pip' kanaliyla izin verir (yalniz bagli goruntulu arama) ve
/// pip durum degisimini dinler (sade gorunum cizer).
class MainActivity : FlutterActivity() {
    private var pipIzinli = false
    private var kanal: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        kanal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gebzem/pip")
        kanal?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setPipIzinli" -> {
                    pipIzinli = call.arguments == true
                    // API 31+: sistem jesti (home/swipe) aninda otomatik PiP — en akici yol.
                    // setPictureInPictureParams de OEM'lerde patlayabilir -> try/catch (yargic).
                    if (Build.VERSION.SDK_INT >= 31) {
                        try {
                            setPictureInPictureParams(paramsYap())
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "pipDurumu" -> result.success(
                    Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode)
                else -> result.notImplemented()
            }
        }
    }

    private fun paramsYap(): PictureInPictureParams {
        val b = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16)) // dikey arama gorunumu
        if (Build.VERSION.SDK_INT >= 31) {
            b.setAutoEnterEnabled(pipIzinli)
            b.setSeamlessResizeEnabled(false) // video icin onerilen (titreme olmasin)
        }
        return b.build()
    }

    // API 26-30: autoEnter yok — HOME tusunda elle PiP iste. ("Son uygulamalar" tusu
    // onUserLeaveHint uretmez; o durumda Flutter lifecycle kamera-mute yedegi devrede.)
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipIzinli && Build.VERSION.SDK_INT >= 26) {
            try {
                enterPictureInPictureMode(paramsYap())
            } catch (_: Exception) {} // OEM AppOps reddi -> sessizce vazgec (mute yedegi var)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        kanal?.invokeMethod("pipDegisti", isInPictureInPictureMode)
    }
}
