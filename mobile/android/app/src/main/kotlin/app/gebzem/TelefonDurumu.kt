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
///   OFFHOOK -> GSM gorusmesi SURUYOR -> Gebzem BEKLEMEYE alinir (medya durur, arama OLMEZ)
///   IDLE    -> Gebzem aramasi kaldigi yerden DEVAM eder
///   RINGING -> HICBIR SEY (zil calarken kesme YOK; karar latch'lenir — turu 62)
///
/// API 31+ : TelephonyCallback.CallStateListener (PhoneStateListener deprecated)
/// API <31 : PhoneStateListener
/// Ikisi de READ_PHONE_STATE ister; izin YOKSA hicbir sey yapilmaz (ozellik sessizce kapali,
/// arama akisi bozulmaz).
class TelefonDurumu(private val ctx: Context, private val kanal: MethodChannel) {
    private var eskiDinleyici: PhoneStateListener? = null
    private var yeniDinleyici: Any? = null // TelephonyCallback (API 31+)
    private var sonDurum = TelephonyManager.CALL_STATE_IDLE

    /// TURU 62: Dart'a EN SON bildirilen KARAR (beklet mi?). Ham `sonDurum`dan AYRI
    /// tutulur, cunku RINGING artik karari DEGISTIRMIYOR — dedup ham durumdan yapilamaz.
    private var sonBildirilen = false

    private fun izinVar(): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_PHONE_STATE) ==
            PackageManager.PERMISSION_GRANTED

    private fun tm(): TelephonyManager? =
        ctx.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

    private fun bildir(durum: Int) {
        if (durum == sonDurum) return
        sonDurum = durum
        // ⚠️⚠️ TURU 62 — KULLANICI BULGUSU: "biri arama attiginda DIREK beklemeye aliyor;
        // yani ben telefonu ACTIGIMDA almasi gerekiyor."
        // ESKIDEN `durum != CALL_STATE_IDLE` gonderiliyordu; sabitler IDLE=0, RINGING=1,
        // OFFHOOK=2 oldugu icin telefon SADECE CALARKEN de bekletme baslıyordu. Kullanici
        // GSM'i REDDEDERSE veya arama KACARSA Gebzem gorusmesi bos yere kesilip geri
        // aciliyor, karsi tarafta "Beklemede" rozeti yanip sonuyordu.
        //
        // YENI KARAR TABLOSU:
        //   OFFHOOK -> GSM gorusmesi FIILEN SURUYOR (kabul edildi VEYA giden GSM) -> BEKLET
        //   IDLE    -> hicbir GSM aramasi yok -> DEVAM ET
        //   RINGING -> yalnizca CALIYOR; karar DEGISMEZ (latch)
        //
        // ⚠️⚠️ RINGING NEDEN `false` DEGIL DE LATCH: Android `CALL_STATE_RINGING`i
        // "zaten aktif bir gorusme varken ikinci cagri geldi" (GSM cagri bekletme)
        // durumunda DA uretir. `false` yazsaydik SUREN GSM gorusmesinin ORTASINDA
        // mikrofonu geri acardik ve karsi taraf GSM konusmasini DUYARDI — turu 56'da
        // kapatilan GIZLILIK aciginin aynisi.
        // ⚠️ YAPMA: RINGING dalini `false` yapma.
        val beklet = when (durum) {
            TelephonyManager.CALL_STATE_OFFHOOK -> true
            TelephonyManager.CALL_STATE_IDLE -> false
            else -> sonBildirilen // RINGING: karari KORU
        }
        if (beklet == sonBildirilen) return
        sonBildirilen = beklet
        // Dart tarafi: true = GSM gorusmesi SURUYOR (beklet), false = bitti (devam et)
        kanal.invokeMethod("gsmDurum", beklet)
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
        // ⚠️⚠️ TURU 62 — KARARI DA SIFIRLA (ZORUNLU, sus payi DEGIL).
        // `TelefonDurumu` nesnesi MainActivity'de aramalar arasi YASAR
        // (`if (telefon == null) telefon = TelefonDurumu(...)`). Bunu sifirlamazsak:
        // GSM gorusmesi SURERKEN Gebzem aramasi bitip yenisi baslarsa, `basla()`nin
        // registerTelephonyCallback ANINDA teslim ettigi OFFHOOK icin
        // `beklet(true) == sonBildirilen(true)` olur, olay YUTULUR ve yeni arama
        // GSM konusmasi boyunca MIKROFON ACIK kalir = turu 56 gizlilik acigi geri gelir.
        // ⚠️ YAPMA: bu satiri kaldirma.
        sonBildirilen = false
    }
}
