package app.gebzem

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/// TEST TURU 20 — GSM ARAMA BEKLETME (kullanici bulgusu: "WhatsApp'ta normal arama gelince
/// gorusme beklemeye aliniyor, bizde arkada devam ediyor").
///
/// Telefon (GSM) arama durumunu dinler ve Flutter'a bildirir:
///   RINGING/OFFHOOK -> Gebzem aramasi BEKLEMEYE alinir (medya durur, arama OLMEZ)
///   IDLE            -> Gebzem aramasi kaldigi yerden DEVAM eder
///
/// API 31+ : TelephonyCallback.CallStateListener (PhoneStateListener deprecated)
/// API <31 : PhoneStateListener
/// Ikisi de READ_PHONE_STATE ister; izin YOKSA hicbir sey yapilmaz (ozellik sessizce kapali,
/// arama akisi bozulmaz).
class TelefonDurumu(private val ctx: Context, private val kanal: MethodChannel) {
    private var eskiDinleyici: PhoneStateListener? = null
    private var yeniDinleyici: Any? = null // TelephonyCallback (API 31+)
    private var sonDurum = TelephonyManager.CALL_STATE_IDLE

    private fun izinVar(): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_PHONE_STATE) ==
            PackageManager.PERMISSION_GRANTED

    private fun tm(): TelephonyManager? =
        ctx.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

    private fun bildir(durum: Int) {
        if (durum == sonDurum) return
        sonDurum = durum
        // Dart tarafi: true = GSM aramasi var (beklet), false = bitti (devam et)
        kanal.invokeMethod("gsmDurum", durum != TelephonyManager.CALL_STATE_IDLE)
    }

    fun basla(): Boolean {
        if (!izinVar()) return false
        val t = tm() ?: return false
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                if (yeniDinleyici != null) return true
                val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) = bildir(state)
                }
                yeniDinleyici = cb
                t.registerTelephonyCallback(ctx.mainExecutor, cb)
            } else {
                if (eskiDinleyici != null) return true
                @Suppress("DEPRECATION")
                val l = object : PhoneStateListener() {
                    @Deprecated("API 31 oncesi tek yol")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) = bildir(state)
                }
                eskiDinleyici = l
                @Suppress("DEPRECATION")
                t.listen(l, PhoneStateListener.LISTEN_CALL_STATE)
            }
            return true
        } catch (_: Exception) {
            return false // OEM kisitlari -> ozellik kapali, arama etkilenmez
        }
    }

    fun dur() {
        val t = tm()
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                (yeniDinleyici as? TelephonyCallback)?.let { t?.unregisterTelephonyCallback(it) }
            } else {
                @Suppress("DEPRECATION")
                eskiDinleyici?.let { t?.listen(it, PhoneStateListener.LISTEN_NONE) }
            }
        } catch (_: Exception) {}
        yeniDinleyici = null
        eskiDinleyici = null
        sonDurum = TelephonyManager.CALL_STATE_IDLE
    }
}
