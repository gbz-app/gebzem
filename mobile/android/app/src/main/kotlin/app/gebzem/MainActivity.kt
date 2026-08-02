package app.gebzem

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import com.cloudwebrtc.webrtc.audio.AudioSwitchManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// FAZ-6 ANDROID SISTEM PiP (WhatsApp paritesi — kullanici bulgusu: "alta alinca kucuk
/// ekran gelmiyor"): GORUNTULU arama aktifken kullanici HOME'a inerse uygulama yuzen
/// pencereye kuculur; kamera acik kalir (PiP = on planda sayilir), karsi taraf DONMAZ.
/// Flutter tarafi 'gebzem/pip' kanaliyla izin verir (yalniz bagli goruntulu arama) ve
/// pip durum degisimini dinler (sade gorunum cizer).
///
/// TEST TURU 14: PiP penceresine WhatsApp gibi KONTROL DUGMELERI (RemoteAction) eklendi —
/// mikrofon ac/kapa + kapat. Dugmeye basilinca broadcast -> MethodChannel -> Dart
/// (controller.toggleMic / leave). Pencere orani 9:16 -> 3:4 (sistem daha BUYUK cizer).
class MainActivity : FlutterActivity() {
    private var pipIzinli = false
    private var micAcik = true
    private var dugmelerAcik = true // canli yayin PiP'inde arama dugmeleri gizlenir
    private var kanal: MethodChannel? = null
    private var alici: BroadcastReceiver? = null
    private var telefon: TelefonDurumu? = null // GSM arama dinleyicisi (test turu 20)

    companion object {
        private const val EYLEM = "app.gebzem.PIP_EYLEM"
        private const val ANAHTAR = "eylem"
        private const val MIC = "mic"
        private const val KAPAT = "kapat"
    }

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
                // TEST TURU 15: CANLI YAYIN PiP'inde arama dugmeleri (mikrofon/kapat) anlamsiz
                "setPipDugmeler" -> {
                    val yeni = call.arguments == true
                    if (yeni != dugmelerAcik) {
                        dugmelerAcik = yeni
                        if (Build.VERSION.SDK_INT >= 26) {
                            try { setPictureInPictureParams(paramsYap()) } catch (_: Exception) {}
                        }
                    }
                    result.success(true)
                }
                // TEST TURU 14: mikrofon durumu -> PiP dugmesinin ikonu/etiketi guncellenir
                "setMicDurum" -> {
                    val yeni = call.arguments == true
                    if (yeni != micAcik) {
                        micAcik = yeni
                        if (Build.VERSION.SDK_INT >= 26) {
                            try {
                                setPictureInPictureParams(paramsYap())
                            } catch (_: Exception) {}
                        }
                    }
                    result.success(true)
                }
                // TEST TURU 14: arama bitti + hala PiP penceresindeyiz -> pencereyi KAPAT
                // (WhatsApp gibi). PiP'te finish() uygulamayi oldurur; moveTaskToBack PiP'i
                // kapatip uygulamayi arka plana alir (kullanici ne yapiyorduysa ona doner).
                "pipKapat" -> {
                    if (Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode) {
                        try { moveTaskToBack(true) } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                // TEST TURU 20: GSM arama dinleyicisini ac/kapa (Gebzem aramasi basladiginda
                // acilir, bittiginde kapanir). Izin yoksa false doner -> ozellik sessizce kapali.
                "gsmDinle" -> {
                    val ac = call.arguments == true
                    if (ac) {
                        if (telefon == null) telefon = TelefonDurumu(this, kanal!!)
                        result.success(telefon?.basla() ?: false)
                    } else {
                        telefon?.dur()
                        result.success(true)
                    }
                }
                // ⚠️⚠️ TEST TURU 62 — GSM SONRASI SES OTURUMUNU SAHIBINE YENIDEN KURDURUR.
                //
                // KULLANICI BULGUSU: "beklettikten sonra kapatip konusmaya devam ettigimde
                // sanki SES ARKADAN GELIYOR gibi oluyor" -> ses KULAKLIK (earpiece) yerine
                // arkadaki HOPARLORDEN caliyor.
                //
                // KOK NEDEN: Android'de ses MODU (MODE_IN_COMMUNICATION), AUDIO FOCUS ve
                // cihaz secimi YALNIZCA flutter_webrtc'nin `AudioSwitch.activate()`
                // gecisinde uygulanir. O gecisi tetikleyen `AudioSwitchManager.start()`
                // `if (!isActive)` kilidiyle korunur ve `isActive` ARAMA BOYUNCA true
                // takilidir (stop yalniz son PeerConnection dispose olunca cagrilir).
                // GSM aramasi ses odagini alir, bitince Android modu MODE_NORMAL'a dondurur
                // ve (API31+) `setCommunicationDevice` secimimizi temizler — bizde bunu geri
                // alacak HICBIR SEY YOKTU. Dart tarafindaki `setAndroidAudioConfiguration`
                // YETMEZ: o yalniz DEGERI saklar, uygulamayi `activate()` yapar.
                //
                // ⚠️ YAPMA: burada `am.mode = ...` YAZMA. Activity'nin AudioManager'i
                // AudioService'te AYRI bir istemcidir; birakan kod olmadigi icin arama
                // bitince MODE_IN_COMMUNICATION SIZAR (ses tusu VOICE_CALL'u kontrol eder,
                // sonraki oda/yayin bozuk modu devralir). Modu SAHIBINE yazdiriyoruz.
                //
                // ⚠️⚠️ `stop()` HEMEN ARDINDAN `start()` CAGIRMA — ISE YARAMAZ:
                // ikisi de `handler.removeCallbacksAndMessages(null)` yapar, yani `start()`
                // `stop()`un kuyruga koydugu `deactivate` isini SILER; `isActive` true
                // kalir ve `activate()` `if (!isActive)` kapisinda NO-OP olur.
                // Bu yuzden `start()` BIR SONRAKI dongu turunda cagriliyor.
                // ⚠️ YAPMA: bu gecikmeyi kaldirip iki cagriyi arka arkaya yapma.
                "sesOturumunuTazele" -> {
                    val onceki = try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val m = am.mode // SALT OKUMA — olcum (Dart Sentry'e yazar)
                        AudioSwitchManager.instance?.stop()
                        Handler(Looper.getMainLooper()).postDelayed({
                            try { AudioSwitchManager.instance?.start() } catch (_: Throwable) {}
                        }, 120)
                        m
                    } catch (_: Throwable) {
                        -99 // OEM/surum farki -> ozellik sessizce kapali, arama ETKILENMEZ
                    }
                    result.success(onceki)
                }
                // TEST TURU 32: SUREN ARAMA ONDEPLAN SERVISI (arka planda donma korumasi).
                // Basarisiz olursa SESSIZCE vazgecilir — arama akisi ETKILENMEZ.
                "aramaServisiBasla" -> {
                    val video = (call.arguments as? Map<*, *>)?.get("video") == true
                    try {
                        AramaServisi.basla(this, video)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "aramaServisiDur" -> {
                    try { AramaServisi.dur(this) } catch (_: Throwable) {}
                    result.success(true)
                }
                "pipDurumu" -> result.success(
                    Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode)
                else -> result.notImplemented()
            }
        }
        aliciKur()
    }

    /// PiP dugmeleri broadcast gonderir; burada Flutter'a iletilir (arama mantigi Dart'ta).
    private fun aliciKur() {
        if (alici != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                when (i?.getStringExtra(ANAHTAR)) {
                    MIC -> kanal?.invokeMethod("pipEylem", MIC)
                    KAPAT -> kanal?.invokeMethod("pipEylem", KAPAT)
                }
            }
        }
        alici = r
        val filtre = IntentFilter(EYLEM)
        // Android 13+ (API 33) dinamik alicilarda export bayragi ZORUNLU; uygulama-ici
        // broadcast oldugu icin NOT_EXPORTED (guvenli).
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(r, filtre, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(r, filtre)
        }
    }

    override fun onDestroy() {
        telefon?.dur()
        alici?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        alici = null
        super.onDestroy()
    }

    private fun eylemYap(kod: String, ikon: Int, baslik: String, istek: Int): RemoteAction? {
        if (Build.VERSION.SDK_INT < 26) return null
        val niyet = Intent(EYLEM).setPackage(packageName).putExtra(ANAHTAR, kod)
        val bayrak = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pi = PendingIntent.getBroadcast(this, istek, niyet, bayrak)
        return RemoteAction(Icon.createWithResource(this, ikon), baslik, baslik, pi)
    }

    private fun paramsYap(): PictureInPictureParams {
        val b = PictureInPictureParams.Builder()
            // TEST TURU 14: 9:16 (0.56) sistemin en dar dikey orani -> pencere kucuk goruluyordu.
            // 3:4 (0.75) daha genis => AYNI yukseklikte daha BUYUK pencere.
            .setAspectRatio(Rational(5, 6)) // turu 53: iOS ile AYNI oran (%11 daha genis)
        if (Build.VERSION.SDK_INT >= 26) {
            // WhatsApp gibi: mikrofon ac/kapa + kirmizi kapat (yalniz ARAMA PiP'inde).
            // Canli yayin PiP'inde BOS liste ACIKCA verilir (yoksa eski dugmeler asili kalir).
            val eylemler = if (dugmelerAcik) {
                listOfNotNull(
                    eylemYap(
                        MIC,
                        if (micAcik) R.drawable.pip_mic else R.drawable.pip_mic_off,
                        if (micAcik) "Mikrofonu kapat" else "Mikrofonu ac",
                        1),
                    eylemYap(KAPAT, R.drawable.pip_hangup, "Aramayi bitir", 2),
                )
            } else {
                emptyList()
            }
            b.setActions(eylemler)
        }
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
