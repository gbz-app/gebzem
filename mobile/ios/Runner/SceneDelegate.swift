import Flutter
import UIKit

/// TEST TURU 43 — SCENE TABANLI YASAM DONGUSU.
///
/// KRITIK KESIF: bu uygulama SCENE tabanli (Info.plist'te UIApplicationSceneManifest var).
/// Apple: *"If you're using scenes, UIKit will not call this method"* — yani AppDelegate'e
/// yazilacak `applicationDidEnterBackground` / `WillResignActive` kancalari OLU KODDUR.
/// Yasam dongusu kancalarinin DOGRU yeri burasidir.
///
/// NEDEN GEREKLI: PiP'i bugune kadar Dart'taki lifecycle olayindan baslatiyorduk
/// (`inactive` -> method channel -> `GebzemPip.baslat()`). Bu yol bir kare + kanal
/// gidis-donusu (~50-150ms) gecikme tasir; iOS bu arada kamerayi kesebiliyor.
/// Native taraftan, arka plana GECMEDEN ONCE baslatmak o boslugu kapatir.
/// Dart'taki tetik YEDEK olarak KALIYOR; `baslat()` idempotenttir
/// (`isPictureInPictureActive` kontrolu) ve on planda basladiysa `didStart` icindeki
/// kapi pencereyi aninda kapatir.
///
/// ⚠️ YAPMA: buradan `stopPictureInPicture` cagirma — ust uste binme mantigi
/// `active_call_controller` resumed dalinda yonetiliyor.
class SceneDelegate: FlutterSceneDelegate {

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    if #available(iOS 15.0, *) {
      GebzemPip.shared.baslat()
    }
  }
}
