package app.gebzem

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * TEST TURU 32 — SUREN ARAMA ONDEPLAN SERVISI (kullanici: "uygulamayi alta alinca /
 * kilitleyince 5-10 saniye sonra gorusme bitiyor, WhatsApp gibi SESLI devam etmeli").
 *
 * KOK NEDEN (belgelenmis platform kurali, tahmin degil):
 *  - Android 14+ : arka plana gecip "cached" duruma dusen surecler **10 saniye sonra
 *    DONDURULUR** (cached apps freezer) -> WebSocket/WebRTC durur -> LiveKit katilimciyi
 *    dusurur -> arama biter. Sure kullanicinin tarif ettigi 5-10sn ile birebir ortusuyor.
 *    https://source.android.com/docs/core/perf/cached-apps-freezer
 *  - Android 11+ : arka planda MIKROFONA erismek icin `microphone` tipli ondeplan servisi
 *    ZORUNLU (arama uygulamalari icin Google'in verdigi ornek tam da budur).
 *    https://developer.android.com/develop/background-work/services/fgs/service-types
 *  - Projede FOREGROUND_SERVICE* izinleri ALINMISTI ama HICBIR servis yoktu (manifestte
 *    tek <service> girdisi yok) — yani izinler bosuna duruyordu.
 *  - Ayrica Android'de PiP yalniz GORUNTULU aramada aciliyor (_pipIstenir), SESLI aramada
 *    hicbir koruma yoktu.
 *
 * TASARIM: servis medyaya DOKUNMAZ; tek isi sureci "foreground" durumda tutup dondurulmasini
 * engellemek ve kullaniciya kalici bir bildirim gostermek. Baslatilamazsa (izin yok, OEM
 * kisiti, ForegroundServiceStartNotAllowedException) SESSIZCE vazgecilir — arama bozulmaz.
 *
 * ⚠️ YAPMA: tip maskesini manifestte bildirilmemis bir tiple cagirma (Android 14'te
 * SecurityException); izin verilmemis tipi maskeye ekleme (ayni hata); servisi leave()
 * disinda bir yerden durdurma (park edilen arama surerken kapanmamali).
 */
class AramaServisi : Service() {

  companion object {
    private const val KANAL = "gebzem_arama"
    private const val BILDIRIM_ID = 7317
    const val EK_VIDEO = "video"
    private const val ETIKET = "gebzem/arama-servisi"

    fun basla(ctx: Context, video: Boolean) {
      val i = Intent(ctx, AramaServisi::class.java).putExtra(EK_VIDEO, video)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        ctx.startForegroundService(i)
      } else {
        ctx.startService(i)
      }
    }

    fun dur(ctx: Context) {
      ctx.stopService(Intent(ctx, AramaServisi::class.java))
    }
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val video = intent?.getBooleanExtra(EK_VIDEO, false) ?: false
    try {
      kanalKur()
      val bildirim = bildirimUret(video)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(BILDIRIM_ID, bildirim, tipMaskesi(video))
      } else {
        startForeground(BILDIRIM_ID, bildirim)
      }
      Log.i(ETIKET, "ondeplan servisi basladi (video=$video)")
    } catch (e: Throwable) {
      // Izin yok / OEM kisiti / arka plandan baslatma yasagi -> SESSIZCE vazgec.
      Log.w(ETIKET, "ondeplan servisi baslatilamadi: ${e.javaClass.simpleName} ${e.message}")
      stopSelf()
    }
    // START_NOT_STICKY: sistem oldururse KENDILIGINDEN dirilmesin (arama zaten bitmistir).
    return START_NOT_STICKY
  }

  /**
   * Tip maskesi CALISMA ZAMANINDA hesaplanir: yalniz GERCEKTEN verilmis izinlerin tipi
   * eklenir. Android 14'te izni olmayan tip -> SecurityException.
   */
  private fun tipMaskesi(video: Boolean): Int {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
    var maske = 0
    if (izinVar(android.Manifest.permission.RECORD_AUDIO)) {
      maske = maske or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
    }
    if (video && izinVar(android.Manifest.permission.CAMERA)) {
      maske = maske or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
    }
    // Hicbir tip yoksa (izinler reddedilmis) tipsiz baslat — yine de donma korumasi saglar.
    return maske
  }

  private fun izinVar(izin: String): Boolean =
    checkSelfPermission(izin) == PackageManager.PERMISSION_GRANTED

  private fun kanalKur() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (nm.getNotificationChannel(KANAL) != null) return
    val kanal = NotificationChannel(KANAL, "Süren arama", NotificationManager.IMPORTANCE_LOW)
    kanal.setShowBadge(false)
    kanal.enableVibration(false)
    kanal.setSound(null, null)
    nm.createNotificationChannel(kanal)
  }

  private fun bildirimUret(video: Boolean): Notification {
    val ac = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
    }
    val bayrak = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    } else {
      PendingIntent.FLAG_UPDATE_CURRENT
    }
    val pi = PendingIntent.getActivity(this, 0, ac, bayrak)
    return NotificationCompat.Builder(this, KANAL)
      .setContentTitle(if (video) "Görüntülü arama sürüyor" else "Sesli arama sürüyor")
      .setContentText("Gebzem — dönmek için dokun")
      .setSmallIcon(android.R.drawable.stat_sys_phone_call)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setCategory(NotificationCompat.CATEGORY_CALL)
      .setOngoing(true)
      .setShowWhen(false)
      .setContentIntent(pi)
      .build()
  }

  override fun onDestroy() {
    Log.i(ETIKET, "ondeplan servisi durdu")
    super.onDestroy()
  }
}
