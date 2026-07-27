import Flutter
import UIKit

/// TEST TURU 49 — PiP'I EN ERKEN ANDA BASLAT, AMA **ASENKRON**.
///
/// TARIHCE (bu dosya iki kez degisti, ikisinin de sebebi olculdu):
/// · TURU 43: buraya SENKRON `GebzemPip.shared.baslat()` konuldu -> kamera arka planda
///   YASADI (`oturum=true`), ama kullanici "alta alirken zorlaniyorum, ekran kayiyor ama
///   inmiyor" dedi. Sebep: iOS'ta home hareketi INTERAKTIFTIR; `sceneWillResignActive`
///   parmak HENUZ EKRANDAYKEN gelir ve o callout'un ICINDE senkron pencere acmak sistemin
///   gecisini keser.
/// · TURU 46: kanca tamamen KALDIRILDI -> takilma gecti (`cagri=1 msMax=0`) ama kamera
///   arka planda OLDU (`oturum=false`), kose kutusu dondu.
/// · TURU 48: Dart tarafina 1200ms'lik tekrar penceresi + native `.background` kapisi
///   kondu -> OLCUM `kesinti ... pip=FALSE` dedi: pencere HIC acilmadi (kapi, tek gercek
///   denemeyi de yuttu; Dart tetigi method channel uzerinden GEC iniyor).
///
/// SONUC: erken baslatma GEREKLI (Apple arka planda kamerayi yalniz PiP AKTIFKEN surdurur),
/// ama SENKRON olmamali. `DispatchQueue.main.async` UIKit gecis callout'unu ANINDA serbest
/// birakir; cagri ayni run loop turunun sonunda, hareket bloklanmadan calisir.
///
/// EK KORUMALAR:
/// · `GebzemPip.baslat()` icinde tek-istek kilidi var (`baslatIstendi`) -> Dart tetigiyle
///   CIFT acilma olmaz; olcumde `cagri` 1 kalmali.
/// · Pencere kurulu degilse (`pipController == nil`) `baslat()` zaten hemen doner.
/// · Hareket IPTAL edilirse (`.active`e donus) Dart'in `resumed` dalindaki kosulsuz
///   `iosPipDurdur()` pencereyi kapatir.
///
/// ⚠️ YAPMA: bu cagriyi SENKRON hale getirme (turu 43 takilmasi doner).
/// ⚠️ YAPMA: kancayi tamamen kaldirma (turu 46: arka planda kamera olur, kose kutusu donar).
class SceneDelegate: FlutterSceneDelegate {

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    DispatchQueue.main.async {
      GebzemPip.shared.baslat()
    }
  }
}
