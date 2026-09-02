package app.gebzem

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.MethodChannel

/// ⚠️⚠️⚠️ TURU 155 — PUSULA (kullanici emri: "konum ... telefonu oynattikca
/// yonu gostersin"). Cihazin BAKTIGI yonu Dart'a bildirir.
///
/// ⚠️⚠️ `geolocator`in `Position.heading`i BURADAKI DEGER DEGILDIR: o GPS'in
///	GIDIS yonu (course over ground) ve cihaz duruyorken 0.0 doner.
///	Android dokumani da acikca "not related to the device orientation" diyor.
///
/// SENSOR SECIMI (siraya dikkat):
///   1) TYPE_ROTATION_VECTOR            — jiroskop dahil, en kararli
///   2) TYPE_GEOMAGNETIC_ROTATION_VECTOR — jiroskopsuz cihazlarda; AOSP guc
///      dokumaninda "low power" listesinde, yani pil dostu
/// Ikisi de yoksa hicbir sey yapilmaz: Dart tarafi deger gelmeyince yon okunu
/// CIZMEZ (yanlis yon gostermektense hic gostermemek dogrudur).
///
/// ⚠️ **MANYETIK KUZEY**: `getOrientation` azimuth'u manyetik kuzeye goredir;
///    `GeomagneticField` ile deklinasyon UYGULANMIYOR. Gebze'de fark ~5-6
///    derece — yaya navigasyonu icin onemsiz, ama iOS `trueHeading`
///    kullandigi icin iki platform bu kadar AYRISIR. Bilincli kabul.
///
/// ⚠️ `SENSOR_DELAY_UI` (~60ms) secildi: `SENSOR_DELAY_GAME`/`FASTEST` bu is
///    icin gereksiz sik ve pil yakar; Dart tarafi zaten yumusatiyor.
class Pusula(private val ctx: Context, private val kanal: MethodChannel) :
    SensorEventListener {

    private var sm: SensorManager? = null
    private var sensor: Sensor? = null
    private val matris = FloatArray(9)
    private val aci = FloatArray(3)

    /// Son gonderim zamani — Dart'a saniyede ~10 olaydan fazlasi gitmesin.
    /// ⚠️ Kanal cagrilari ana is parcaciginda kosar; kismamak arayuzu bogar.
    private var sonGonderim = 0L

    fun basla() {
        if (sm != null) return
        val m = ctx.getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
        val s = m.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: m.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            ?: return
        sm = m
        sensor = s
        // ⚠️ Varsayilan handler ile kaydolunca olaylar ANA IS PARCACIGINA
        //    duser; `MethodChannel.invokeMethod` baska bir parcacikta
        //    cagrilirsa Flutter PATLAR.
        m.registerListener(this, s, SensorManager.SENSOR_DELAY_UI)
    }

    fun dur() {
        sm?.unregisterListener(this)
        sm = null
        sensor = null
        sonGonderim = 0L
    }

    override fun onAccuracyChanged(s: Sensor?, dogruluk: Int) {
        // Kullanilmiyor: dogruluk bilgisini Dart tarafi ISTEMIYOR. Kalibrasyon
        // uyarisi gostermek AYRI bir urun karari olurdu.
    }

    override fun onSensorChanged(olay: SensorEvent?) {
        val o = olay ?: return
        if (o.sensor.type != Sensor.TYPE_ROTATION_VECTOR &&
            o.sensor.type != Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR
        ) return
        val simdi = System.currentTimeMillis()
        if (simdi - sonGonderim < 100L) return
        sonGonderim = simdi

        SensorManager.getRotationMatrixFromVector(matris, o.values)
        SensorManager.getOrientation(matris, aci)
        var derece = Math.toDegrees(aci[0].toDouble())
        if (derece < 0) derece += 360.0
        kanal.invokeMethod("yon", mapOf("derece" to derece))
    }
}
