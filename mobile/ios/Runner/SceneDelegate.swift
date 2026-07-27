import Flutter
import UIKit

/// TEST TURU 46 — TURU 43'TEKI `sceneWillResignActive` KANCASI GERI ALINDI.
///
/// KULLANICI: "goruntulu aramada uygulamayi normal alta ALAMIYORUM; ekran kayiyor ama
/// inmiyor, en sonunda ZORLA yukari kaldirip indirmeye calisiyorum."
///
/// KOK NEDEN (zaman cizelgesi + iOS davranisi):
/// · Sikayet TAM turu 43 build'inden sonra basladi; turu 43'te buraya SENKRON
///   `GebzemPip.shared.baslat()` (yani `startPictureInPicture()`) eklenmisti.
/// · iOS'ta home hareketi INTERAKTIFTIR: `sceneWillResignActive` parmak daha EKRANDAYKEN,
///   surukleme BASLADIGI anda gelir (kullanici vazgecerse uygulama on planda kalir).
///   Tam o anda ana is parcaciginda PiP penceresi acmak, sistemin interaktif gecisini
///   keserek surtunme/geri tepme uretiyor — kullanicinin tarif ettigi "kayiyor ama inmiyor".
/// · Ustelik ARTIK GEREKSIZ: bu kanca, "arka planda kamera kesiliyor" sorununu cozmek icin
///   eklenmisti; gercek sebep DEPLOYMENT TARGET (15.0 -> 16.0) cikti ve turu 44 olcumuyle
///   kanitlandi (`oturum=true`, kesinti kaydi YOK). Yani kancanin sagladigi bir kazanim yok.
///
/// PiP baslatma YOLU DEGISMEDI: Dart tarafi lifecycle `inactive` aninda
/// `PipService.iosPipBaslat()` cagiriyor (turu 20'den beri calisan yol; turu 20-42 boyunca
/// bu sikayet HIC olmadi).
///
/// ⚠️ YAPMA: buraya tekrar SENKRON `startPictureInPicture()` koyma (alta alma takilir).
/// Native tarafta gerekirse `sceneDidEnterBackground` denenebilir — ama o an Apple
/// startPictureInPicture'a izin vermeyebilir; once OLC, sonra ekle.
class SceneDelegate: FlutterSceneDelegate {

}
