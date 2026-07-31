import Flutter
import UIKit
import PushKit
import CallKit
import AVFAudio
import AVFoundation              // AVSampleBufferDisplayLayer (PiP kare besleme)
import AVKit                      // iOS sistem PiP (AVPictureInPictureController)
import WebRTC                     // WebRTC-SDK pod -> modul adi "WebRTC". Derleme riski burada;
                                  // patlarsa Podfile'a :modular_headers => true (bkz. Podfile notu).
import flutter_callkit_incoming

// KILIT EKRANINDA GELEN ARAMA (iOS) — CallKit + PushKit + WebRTC ses koprusu.
//
// ASIL DUZELTME (ses yok sorunu): iOS'ta CallKit AVAudioSession'i aktive eder ama
// WebRTC/LiveKit'in ses birimine "artik baslat" diyen kimse yoktu -> mic gidiyor
// (loglarda mediaTrack published) ama uzak ses DUYULMUYORDU.
// Cozum: RTCAudioSession.useManualAudio=true + CallKit didActivateAudioSession'da
// isAudioEnabled=true. Boylece CallKit'in oturumunu LiveKit devralir.
//
// iOS 13+ KURALI: VoIP push alinca AYNI dongude CallKit'e reportNewIncomingCall
// (showCallkitIncoming) ZORUNLU; yoksa iOS uygulamayi oldurur.
@main
@objc class AppDelegate: FlutterAppDelegate,
    FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ses birimi baslamadan ONCE manuel moda al (yoksa WebRTC oturumu kendi acmaya calisip
    // CallKit ile cakisir).
    RTCAudioSession.sharedInstance().useManualAudio = true
    RTCAudioSession.sharedInstance().isAudioEnabled = false

    // TEST TURU 37: kamera kancasi UYGULAMA ACILIRKEN kurulur — ilk kamera acilisindan
    // ONCE hazir olmali (Apple: bayrak capture session BASLATILMADAN once yazilmali).
    if #available(iOS 16.0, *) {
      GebzemKameraKanca.kur()
      GebzemPip.shared.kesintileriDinle()
    }

    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // UYGULAMA ACIK aramada (CallKit YOK, WS overlay yolu) sesi Dart'tan elle ac/kapat.
    // useManualAudio=true global oldugu icin CallKit didActivate gelmeyen (foreground)
    // aramalarda ses acilmaz -> bu kanal onu cozer.
    let ch = FlutterMethodChannel(
      name: "gebzem/audio",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "gebzem.audio")!.messenger())
    ch.setMethodCallHandler { call, result in
      if call.method == "setAudioEnabled" {
        let ac = (call.arguments as? Bool) ?? false
        let s = RTCAudioSession.sharedInstance()
        if ac {
          // KOK GARANTI (grup-host mic-sessiz fix'i, wf_32afbd46): birim baslamadan ONCE
          // oturumu DETERMINISTIK hazirla + aktive et. CallKit'siz yolda (grup hostu /
          // giden arama) oturumu playAndRecord'la aktive eden tek yer burasi olur;
          // CallKit'li yolda config zaten uygulanmis + oturum aktif -> fark-kontrolu
          // sayesinde NO-OP. webRTC() KASITLI: livekit ayni paylasilan config nesnesini
          // mutasyonlar -> sonraki configureAudio gecisleri fark yaratmaz (elle opsiyon
          // YAZMA — canli VPIO'da gercek kategori degisikligi tetiklerdi).
          s.lockForConfiguration()
          do { try s.setConfiguration(RTCAudioSessionConfiguration.webRTC(), active: true) }
          catch { NSLog("gebzem/audio hazirlik hatasi: \(error)") }
          s.unlockForConfiguration()
          // FAZ-7 ILK-ARAMA-SES FIX'I (19 Tem kaniti: sent=0 + enerji=0 + kategori DOGRU):
          // CallKit didActivate, isAudioEnabled=true'yu WebRTC audio unit HENUZ YOKKEN
          // yapmis olabilir -> unit OLU dogar; buradaki duz atama setter fark-kontroluyle
          // NO-OP kalir ve olu unit asla yeniden kurulmaz. ZORLA TOGGLE: bayrak zaten
          // true ise once false'a cek (unit'i sok), sonra true (temiz kur). Saglikli
          // aramada bedeli ~50-150ms yeniden kurulum — sesin hic olmamasina tercih edilir.
          if s.isAudioEnabled {
            NSLog("gebzem/audio unit rebuild (zorla toggle)")
            s.isAudioEnabled = false
          }
          s.isAudioEnabled = true
        } else {
          s.isAudioEnabled = false
        }
        result(nil)
      } else if call.method == "getAudioState" {
        // TESHIS: iOS ses cikis durumu. "paket geliyor ama ses duyulmuyor" -> burada
        // audioEnabled=false / active=false / route yanlis gorunur (KESIN iOS cikis sorunu).
        let s = RTCAudioSession.sharedInstance()
        let av = AVAudioSession.sharedInstance()
        let route = av.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        result([
          "audioEnabled": s.isAudioEnabled,
          "active": s.isActive,
          "category": av.category.rawValue,
          "route": route.isEmpty ? "yok" : route,
        ])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // iOS SISTEM PiP kanali (gebzem/pip — Android ile AYNI ad; pip_service.dart iki platform).
    // Ses birimine DOKUNMAZ. iOS<15 / desteksiz -> hazir=false, istemci kamera-mute avatara duser.
    let pipCh = FlutterMethodChannel(
      name: "gebzem/pip",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "gebzem.pip")!.messenger())
    // TEST TURU 9: kanali GebzemPip'e ver -> PiP basladi/durdu/basarisiz delegate callback'leri
    // Flutter'a geri bildirir (kamera-mute yedegi PiP durumuna gore ayarlanir).
    if #available(iOS 15.0, *) { GebzemPip.shared.kanal = pipCh }
    pipCh.setMethodCallHandler { call, result in
      guard #available(iOS 15.0, *) else {
        // iOS<15: PiP yok
        if call.method == "iosPipHazirMi" { result(false) }
        else if call.method == "iosCokluGorevKamera" { result(false) }
        else { result(nil) }
        return
      }
      switch call.method {
      case "iosPipHazirMi":
        result(AVPictureInPictureController.isPictureInPictureSupported())
      case "iosPipKur":
        let arg = call.arguments as? [String: Any]
        let tid = arg?["trackId"] as? String ?? ""
        let yid = arg?["yerelTrackId"] as? String
        let kaynak = arg?["kaynak"] as? String ?? "yerel"
        result(tid.isEmpty ? false : GebzemPip.shared.kur(trackId: tid, yerelTrackId: yid, kaynak: kaynak))
      case "iosPipBirak":
        GebzemPip.shared.birak()
        result(true)
      case "iosPipYerel":
        // TEST TURU 27: kucuk pencerenin ALT gorunumu (kendi kameram) — controller'a dokunmaz
        let ya = call.arguments as? [String: Any]
        result(GebzemPip.shared.yerelAyarla(
          trackId: ya?["trackId"] as? String, harf: ya?["harf"] as? String ?? "?"))
      case "iosPipEkKaynaklar":
        // TEST TURU 52: kucuk pencere IZGARASI — ANA video disindaki uzak katilimcilar.
        // Controller'a DOKUNMAZ (pencere kapanmaz), yalniz `yigin` yeniden dizilir.
        let ea = call.arguments as? [String: Any]
        let idler = (ea?["trackIdler"] as? [Any])?.compactMap { $0 as? String } ?? []
        result(GebzemPip.shared.ekKaynaklarAyarla(trackIdler: idler))
      case "iosPipKaynak":
        // TEST TURU 39: pencereyi KAPATMADAN gosterilen videoyu degistir
        let a = call.arguments as? [String: Any]
        result(GebzemPip.shared.kaynakDegistir(
          trackId: a?["trackId"] as? String ?? "", kaynak: a?["kaynak"] as? String ?? "uzak"))
      case "iosPipKareBosalt":
        // TEST TURU 38: kamera kapatilirken donmus kare yerine "Kamera duraklatildi"
        // TEST TURU 48: `yalnizYerel:true` ise SADECE kose kutusu (kendi kameram) bosalir.
        if (call.arguments as? Bool) == true {
          GebzemPip.shared.yereliBosalt()
        } else {
          GebzemPip.shared.kareyiBosalt()
        }
        result(true)
      case "iosPipDurdur":
        GebzemPip.shared.durdur()
        result(true)
      case "iosPipBaslat":
        // TEST TURU 20: Dart, uygulama arka plana giderken (lifecycle inactive/paused)
        // cagirir -> PiP telefon Ayarindan BAGIMSIZ acilir.
        GebzemPip.shared.baslat()
        result(true)
      case "iosCokluGorevKamera":
        // TEST TURU 9: kamerayi PiP/arka planda CAPTURE'a devam ettir (karsi taraf beni gorur)
        result(GebzemPip.shared.cokluGorevKameraAc())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - CallkitIncomingAppDelegate (plugin UIApplication.shared.delegate uzerinden cagirir)
  // CallKit sesi aktive edince WebRTC'ye devret + ses birimini AC (asil duzeltme).
  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    NSLog("gebzem/audio didActivate") // FAZ-7 teshis: _sesiAc(true) ile sira izlenir
    RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = true
  }
  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = false
  }
  func providerDidReset() {
    RTCAudioSession.sharedInstance().isAudioEnabled = false
  }
  // action.fulfill() -> CallKit didActivateAudioSession'i tetikler
  func onAccept(_ call: Call, _ action: CXAnswerCallAction) { action.fulfill() }
  func onDecline(_ call: Call, _ action: CXEndCallAction) { action.fulfill() }
  func onEnd(_ call: Call, _ action: CXEndCallAction) { action.fulfill() }
  func onTimeOut(_ call: Call) {}

  // MARK: - PKPushRegistryDelegate
  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }
  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType, completion: @escaping () -> Void) {
    let d = payload.dictionaryPayload
    let callId = (d["call_id"] as? String) ?? UUID().uuidString

    // IPTAL push'u: arama karsi tarafca kapatildi/cevapsiz -> asili CallKit ekranini kapat.
    // iOS zorunlulugu geregi yine de reportNewIncomingCall (showCallkitIncoming) yapip
    // HEMEN endCall ediyoruz (yoksa iOS uygulamayi oldurur).
    if (d["type"] as? String) == "call.cancel" {
      // Isim DOLU olmali: bos isimde CallKit, CXHandle'daki sifreli blob'u (base64)
      // gosteriyordu -> ekranda "karmasik harfler". Ayni callId zaten gosteriliyorsa
      // reportNewIncomingCall ikinci UI acmaz, mevcut aramayi gunceller; endCall kapatir.
      let nm = (d["caller_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Gebzem"
      let data = flutter_callkit_incoming.Data(id: callId, nameCaller: nm, handle: nm, type: 0)
      data.appName = "Gebzem"
      // iOS 13+ KURALI: completion, reportNewIncomingCall (showCallkitIncoming) BITTIKTEN
      // SONRA cagrilmali. Erken cagirmak ihlal -> iOS art arda aramalarda VoIP push'u KESER.
      // Bu yuzden endCall + completion, showCallkitIncoming'in closure'i ICINDE.
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true) {
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
        completion()
      }
      return
    }

    // Normal gelen arama
    let callerName = (d["caller_name"] as? String) ?? "Bilinmeyen"
    let isVideo = ((d["call_type"] as? String) ?? "audio") == "video"
    let data = flutter_callkit_incoming.Data(
      id: callId, nameCaller: callerName, handle: callerName, type: isVideo ? 1 : 0)
    data.appName = "Gebzem"
    // TEST TURU 18 — ARAMA BEKLETME ACILDI: aktif arama "beklenebilir" bildirilirse iOS
    // ikinci aramada "Beklet ve Kabul / Bitir ve Kabul / Reddet" ekranini KENDISI cizer
    // (kullanici istegi). Eskiden false idi cunku beklet olayi ISLENMIYORDU ve GSM
    // beklet-swap'inde ses geri gelmiyordu; artik CXSetHeldCallAction -> Dart
    // (CallEventActionCallToggleHold) -> medya durur/geri acilir + ses birimi tazelenir.
    // GERI ALMA (sorun cikarsa): asagidaki satiri `false` yap + Dart IOSParams.supportsHolding.
    data.supportsHolding = true
    data.supportsGrouping = false
    data.supportsVideo = true
    data.duration = 45000
    // TEST TURU 35: GRUP bayragi ve sohbet basligi da tasinir — kilitli iPhone'da kabul
    // edildiginde "bu bir grup aramasi" bilgisi olmadan davet ("Katil") ekrani cizilemiyordu.
    // Backend bunlari VoIP govdesinde zaten gonderiyor (handler.go); burada DUSURULUYORDU.
    // ⚠️ YAPMA: bu iki alani extras'tan cikarma.
    let grupMu = (d["is_group"] as? Bool) ?? ((d["is_group"] as? String) == "true")
    data.extra = [
      "call_id": callId, "call_type": isVideo ? "video" : "audio", "caller_name": callerName,
      "is_group": grupMu, "chat_title": (d["chat_title"] as? String) ?? "",
    ] as NSDictionary
    // iOS 13+ KURALI: completion, reportNewIncomingCall (showCallkitIncoming) tamamlandiktan
    // SONRA cagrilmali. Erken cagirmak ihlal -> iOS art arda aramalarda 2. VoIP push'u KESER
    // (kilit ekranina dusmuyor). Bu yuzden completion showCallkitIncoming closure'i ICINDE.
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true) {
      completion()
    }
  }
}

// ============================================================================
// iOS SISTEM PiP (test turu 7 — internet arastirmasi + videosdk referansi)
// Goruntulu aramada arka plana alininca UZAK katilimcinin videosu Apple sistem PiP
// penceresinde gorunur. flutter_webrtc sharedSingleton -> uzak RTCVideoTrack ->
// RTCVideoRenderer ile kareler AVSampleBufferDisplayLayer'a -> AVPictureInPictureController
// (auto-enter). SES BIRIMINE (RTCAudioSession/AVAudioSession) ASLA DOKUNMAZ. Kurulamazsa
// false doner -> istemci bugunku kamera-mute avatar davranisina duser (YAPI GEREGI zararsiz).
// pbxproj'a AYRI dosya eklememek icin AppDelegate.swift icinde (zaten derlenen dosya).
// ============================================================================

@available(iOS 15.0, *)
final class GebzemPip: NSObject, AVPictureInPictureControllerDelegate {
  static let shared = GebzemPip()

  // TEST TURU 9: Flutter'a PiP durum geri bildirimi (pipCh). AppDelegate set eder. STRONG:
  // singleton kanali app boyu tutar (retain cycle YOK — kanal GebzemPip'i tutmaz).
  var kanal: FlutterMethodChannel?

  private var pipController: AVPictureInPictureController?
  private var callVC: AVPictureInPictureVideoCallViewController?
  private var videoView: PipVideoView?
  private var renderer: PipRenderer?
  private weak var uzakTrack: RTCVideoTrack?
  private weak var yerelTrack: RTCVideoTrack?          // test turu 24: kendi kameram (alt kutu)
  private var yigin: UIStackView?
  private var yerelTrackId: String?
  private var yerelGorunum: PipVideoView?
  private var yerelRenderer: PipRenderer?

  // ---- TEST TURU 52: COKLU UZAK KATILIMCI (kucuk pencere izgarasi) ----
  // Kullanici: "3 kisi oldugunda alta alinca ust/alt olsun, ben sagda kucuk kalayim."
  // ANA video (`videoView`) yigindaki ILK kutudur; buraya EK uzak katilimcilar girer.
  // Kimlik (`kurulanId`) YALNIZ ana track'tir — ek kutular degisse bile `pipController`a
  // DOKUNULMAZ, yani pencere KAPANMAZ (turu 24/26 dersi, `yerelAyarla` ile ayni desen).
  private var ekGorunumler: [PipVideoView] = []
  private var ekRendererlar: [PipRenderer] = []
  private var ekTrackler: [RTCVideoTrack] = []
  private var ekTrackIdler: [String] = []
  private var satirYiginlari: [UIStackView] = []
  // Ek kutular icin kare gozcusu durumu (ana ve kose kutusuyla AYNI mantik).
  // ⚠️ Bu olmadan izgaradaki kutular donunca KIMSE fark etmiyordu — turu 39/48'de
  // kapattigimiz "donmus kare" deligi ek kutular icin YENIDEN acilmis oluyordu.
  private var ekSonKare: [Int] = []
  private var ekSabitTik: [Int] = []
  private var kurulanId: String?
  private var baslatIstendi = false // turu 46: tek baslatma kapisi
  private var baslatKoruma: Timer?
  var baslatCagri = 0   // olcum: kac kez baslatildi
  /// TEST TURU 52 — OLCUM DUZELTMESI. `baslatCagri`nin TEK sifirlama yeri
  /// `kareOlcumuBaslat()`in +3sn blogu; o da YALNIZ didStart'in BASARILI dalindan
  /// cagriliyor. Iptal edilen (uygulama on planda) ve `failedToStart` olan acilislar
  /// sayaci artirip HIC sifirlamiyordu -> `cagri` tek bir alta almayi degil, son BASARILI
  /// olcumden bu yana BIRIKEN tum gecisleri sayiyordu. Kullanicinin gordugu 2 -> 4 -> 10
  /// tam olarak bu birikimdi; "10 kez ust uste istendi" YORUMU YANLISTI.
  /// Artik iptaller AYRI sayilir ve sayaclar HER ARKA PLANA GECISTE sifirlanir.
  /// ⚠️ YAPMA: sayaclari yalniz basarili dalda sifirlamaya donme (olcum yine bulanir).
  var iptalCagri = 0    // olcum: kac acilis iptal edildi (uygulama on planda / failedToStart)
  var baslatMsMax = 0   // olcum: startPictureInPicture ana is parcacigini kac ms blokladi
  private var iptalIstendi = false // turu 29: on plana donuldu -> bekleyen baslatmayi iptal et

  // ---- TEST TURU 39: KARE GOZCUSU + SICAK KAYNAK DEGISIMI ----
  /// Pencerede su an KIMIN videosu var ("yerel" = kendi kameram, "uzak" = karsi taraf).
  private(set) var kurulanKaynak = "yerel"
  private var gozcu: Timer?
  private var sonGorulenKare = -1
  private var sabitTik = 0
  /// ON PLAN kare sayisi (PiP baslarken okunur) — teshis icin.
  private var onPlanKare = 0
  private var yerelOnPlanKare = 0 // turu 48: kose kutusunun on plandaki kare sayisi
  private var gozcuDuyurdu = false
  private var yerelSonKare = -1
  private var yerelSabitTik = 0

  // TEST TURU 9: COKLU-GOREV KAMERA — kamerayi PiP/arka planda CAPTURE'a devam ettir
  // (goruntulu aramada alta alinca KARSI TARAF beni gormeye devam eder). flutter_webrtc
  // videoCapturer PUBLIC property (FlutterWebRTCPlugin.h) + RTCCameraVideoCapturer.captureSession
  // WebRTC SDK'da public. Entitlement GEREKMEZ (iOS16+ property; iOS16-17 destek cihaza bagli).
  // Desteksiz -> false -> Dart kamera-mute avatar yedegine duser. SES BIRIMINE DOKUNMAZ.
  /// TEST TURU 37 — ARTIK YALNIZ DOGRULAMA. Bayragi ASIL yazan yer `GebzemKameraKanca`
  /// (asagida): Apple bayragin capture session BASLATILMADAN ONCE yazilmasini sart kosuyor.
  /// Burada calisan session'a yazmak KABUL EDILIYOR (geri okuma true) ama FIILEN ETKISIZ —
  /// iste "destek=true oldugu halde arka planda kamera duruyor" celiskisinin cevabi budur.
  /// ⚠️ YAPMA: burayi tekrar "asil yazan yer" haline getirme; session'i stopRunning/
  /// startRunning ile bounce etmeye calisma (WebRTC capturer disaridan durdurulmayi
  /// beklemez — siyah kare / track olumu riski).
  func cokluGorevKameraAc() -> Bool {
    guard #available(iOS 16.0, *) else { return false }
    guard let capturer = FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer else { return false }
    let session = capturer.captureSession
    guard session.isMultitaskingCameraAccessSupported else { return false }
    // TEST TURU 48 — TEKRAR SALT OKUMA. Turu 47'de yapilandirma yazmasi ARKA PLAN
    // KUYRUGUNA tasinmisti; OLCUM bunun REGRESYON oldugunu gosterdi:
    //   turu 46: `arka=89` (uzak video PiP'te akiyordu)
    //   turu 47: `arka=0`  (uzak video da AKMIYOR) — kullanici "halen donuyor"
    // Sebep: bu capture session'i webrtc-sdk KENDI kuyrugunda yonetiyor (ustelik
    // `sinif=AVCaptureMultiCamSession` — PAYLASILAN statik oturum). Disaridan ikinci bir
    // kuyruktan `beginConfiguration/commitConfiguration` yapmak medya hattini kilitliyor.
    // ⚠️ YAPMA: bu metotta capture session'i YENIDEN YAPILANDIRMA — ne ana is parcaciginda
    // (turu 45: alta alma takilir), ne arka plan kuyrugunda (turu 47: medya durur).
    // Bayrak zaten `GebzemKameraKanca` swizzle'i ile kamera BASLATILMADAN ONCE yaziliyor
    // (Apple'in sart kostugu tek dogru an) ve olcumde `coklu=true` okunuyor.
    let ok = session.isMultitaskingCameraAccessEnabled
    NSLog("gebzem/pip coklu-gorev kamera (salt okuma) = \(ok)")
    return ok
  }

  /// TEST TURU 38 — KAMERA DURDURULDUYSA DONMUS KARE GOSTERME. Dart kamerayi kapatirken
  /// cagirir: katman bosaltilir ve "Kamera duraklatildi" etiketi cikar.
  func kareyiBosalt() {
    videoView?.displayLayer.flushAndRemoveImage()
    videoView?.kareKesildi()
    yerelGorunum?.displayLayer.flushAndRemoveImage()
    yerelGorunum?.kareKesildi()
  }

  /// TEST TURU 48 — YALNIZ KOSE KUTUSUNU bosalt. `kareyiBosalt()` IKI kutuyu birden
  /// siliyordu; oysa "kendi kameram kapandi" durumunda BUYUK kutuda KARSI TARAF akmaya
  /// devam ediyor (olcum: `arka=89`) ve ona "Kamera duraklatildi" yazmak YANLIS.
  /// ⚠️ YAPMA: kendi kamera kapanisinda `kareyiBosalt()` cagirma (karsi tarafin kutusu bozulur).
  func yereliBosalt() {
    yerelGorunum?.displayLayer.flushAndRemoveImage()
    yerelGorunum?.kareKesildi()
  }

  /// TEST TURU 38 — KESIN OLCUM: PiP basladiktan 3sn sonra KAC KARE aktigini Dart'a bildir.
  /// Kullanici iki turdur "yine donuyor" diyor; bu sayi tahmini bitirir:
  /// kare=0 -> capture gercekten durmus; kare>0 -> goruntu akiyor, sorun baska yerde.
  func kareOlcumuBaslat() {
    // TEST TURU 39 — IKI TARAFLI OLCUM. Turu 38'in tek yonlu olcumu (yalniz arka plan) su
    // ayrimi YAPAMIYORDU: (a) renderer hic canli track'e baglanmamis (ON PLAN da 0),
    // (b) track dogru ama arka planda capture duruyor (on plan >0, arka 0).
    // TEST TURU 48 — OLCUM GENISLETILDI. Iki eksigi vardi:
    //  · KOSE KUTUSUNUN (kendi kameram) kare sayisi HIC olculmuyordu — oysa kullanicinin
    //    sikayeti TAM ORASI ("kendi ekranim donuyor"). Artik `yerel` ayri sayiliyor.
    //  · Tek bir 3sn olcumu, "hic baslamadi" ile "basladi sonra durdu"yu ayirt edemiyordu.
    //    Artik 1sn ve 3sn ayri: `arka1/arka3` ve `yerel1/yerel3`.
    // Ayrica `durum` (UIApplication.applicationState: 0=aktif 1=inactive 2=arka plan) ve
    // `pipAktif` — uygulama ASKIYA mi alindi yoksa PiP mi kapandi sorusunu bitirir.
    onPlanKare = renderer?.toplamKare ?? 0
    yerelOnPlanKare = yerelRenderer?.toplamKare ?? 0
    renderer?.sayaciSifirla()
    yerelRenderer?.sayaciSifirla()
    var arka1 = -1
    var yerel1 = -1
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      guard let self = self else { return }
      arka1 = self.renderer?.toplamKare ?? -1
      yerel1 = self.yerelRenderer?.toplamKare ?? -1
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self = self else { return }
      let arka3 = self.renderer?.toplamKare ?? -1
      let yerel3 = self.yerelRenderer?.toplamKare ?? -1
      var oturum = false
      var coklu = false
      if #available(iOS 16.0, *),
         let s = FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer?.captureSession {
        oturum = s.isRunning
        coklu = s.isMultitaskingCameraAccessEnabled
      }
      let durum = UIApplication.shared.applicationState.rawValue
      let pipAktif = self.pipController?.isPictureInPictureActive ?? false
      let ozet = "on=\(self.onPlanKare) arka1=\(arka1) arka3=\(arka3)"
        + " yerelOn=\(self.yerelOnPlanKare) yerel1=\(yerel1) yerel3=\(yerel3)"
        + " kaynak=\(self.kurulanKaynak) oturum=\(oturum) coklu=\(coklu)"
        + " cagri=\(self.baslatCagri) iptal=\(self.iptalCagri) msMax=\(self.baslatMsMax)"
        + " durum=\(durum) pipAktif=\(pipAktif)"
      NSLog("gebzem/pip olcum \(ozet)")
      self.kanal?.invokeMethod("iosPipOlcum", arguments: [
        "on": self.onPlanKare, "arka": arka3, "arka1": arka1,
        "yerelOn": self.yerelOnPlanKare, "yerel1": yerel1, "yerel3": yerel3,
        "kaynak": self.kurulanKaynak, "oturum": oturum, "coklu": coklu,
        // turu 46: tek home hareketinde kac baslatma istegi indi ve en uzun
        // startPictureInPicture cagrisi ana is parcacigini kac ms blokladi
        "cagri": self.baslatCagri, "iptal": self.iptalCagri,
        "msMax": self.baslatMsMax,
        "durum": durum, "pipAktif": pipAktif,
      ])
      self.baslatCagri = 0
      self.iptalCagri = 0
      self.baslatMsMax = 0
    }
  }

  /// TEST TURU 39 — KARE GOZCUSU: 500ms'de bir sayaci kontrol eder; 3 TIK (~1.5sn) boyunca
  /// hic yeni kare gelmediyse katmani BOSALTIR ("Kamera duraklatildi" etiketi cikar) ve
  /// Dart'a haber verir. Boylece DONMUS KARE yapisal olarak IMKANSIZ olur — kok neden ne
  /// olursa olsun kullanici donmus goruntu GORMEZ.
  /// ⚠️ YAPMA: esigi 1 tike dusurme (karanlik ortamda dusuk fps yanlis tetikler).
  func gozcuBaslat() {
    gozcuDur()
    sonGorulenKare = -1
    sabitTik = 0
    gozcuDuyurdu = false
    gozcu = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self, self.pipController != nil else { return }

      // TEST TURU 48 — KOSE KUTUSU KONTROLU EN BASA ALINDI (KRITIK HATA DUZELTMESI).
      // ESKIDEN bu blok, BUYUK kutunun "kare gelmedi" dalinin ALTINDA duruyordu; yani
      // once `if n != sonGorulenKare { ...; return }` erken donusu vardi. Sonuc: KARSI
      // TARAFIN videosu AKTIGI SURECE (kullanicinin tam durumu — olcumde `arka=89`)
      // her tikte erken donuluyor ve KOSE KUTUSUNUN DONMASI HIC FARK EDILMIYORDU.
      // Kullanicinin "kendi ekranim donuyor" sikayetinin GORUNUR sebebi buydu: donmus
      // kare temizlenmiyor, "Sen" etiketine dusulmuyordu.
      // Artik iki kutu BIRBIRINDEN BAGIMSIZ denetlenir.
      // ⚠️ YAPMA: bu blogu tekrar buyuk kutunun dalinin altina tasima.
      if let yr = self.yerelRenderer {
        let yn = yr.toplamKare
        if yn != self.yerelSonKare {
          self.yerelSonKare = yn
          self.yerelSabitTik = 0
        } else {
          self.yerelSabitTik += 1
          if self.yerelSabitTik == 3 {
            self.yerelGorunum?.displayLayer.flushAndRemoveImage()
            self.yerelGorunum?.kareKesildi()
            NSLog("gebzem/pip kose kutusu: kare durdu -> etiket")
          }
        }
      }

      // TURU 52: IZGARADAKI EK KUTULAR — her biri BAGIMSIZ denetlenir (kose kutusuyla
      // ayni desen). 3 tik (~1.5sn) kare gelmezse katman bosaltilir -> donmus kare yerine
      // durust etiket. ⚠️ YAPMA: bu blogu buyuk kutunun erken-donus dalinin ALTINA tasima
      // (turu 48'de tam bu hata yuzunden kose kutusunun donmasi HIC fark edilmemisti).
      for i in 0..<self.ekRendererlar.count where i < self.ekGorunumler.count
        && i < self.ekSonKare.count && i < self.ekSabitTik.count {
        let en = self.ekRendererlar[i].toplamKare
        if en != self.ekSonKare[i] {
          self.ekSonKare[i] = en
          self.ekSabitTik[i] = 0
        } else {
          self.ekSabitTik[i] += 1
          if self.ekSabitTik[i] == 3 {
            self.ekGorunumler[i].displayLayer.flushAndRemoveImage()
            self.ekGorunumler[i].kareKesildi()
            NSLog("gebzem/pip izgara kutusu \(i): kare durdu -> etiket")
          }
        }
      }

      let n = self.renderer?.toplamKare ?? 0
      if n != self.sonGorulenKare {
        self.sonGorulenKare = n
        self.sabitTik = 0
        self.gozcuDuyurdu = false
        return
      }
      self.sabitTik += 1
      if self.sabitTik >= 3 && !self.gozcuDuyurdu {
        self.gozcuDuyurdu = true
        NSLog("gebzem/pip gozcu: KARE DURDU kaynak=\(self.kurulanKaynak)")
        self.videoView?.displayLayer.flushAndRemoveImage()
        self.videoView?.kareKesildi()
        self.kanal?.invokeMethod("iosPipKareDurdu", arguments: self.kurulanKaynak)
      }
    }
  }

  func gozcuDur() {
    gozcu?.invalidate()
    gozcu = nil
  }

  /// TEST TURU 39 — SICAK KAYNAK DEGISIMI: PENCEREYI KAPATMADAN gosterilen videoyu degistir.
  /// YALNIZ sink tasinir; `pipController`/`callVC`/`videoView` DOKUNULMAZ — bu yuzden
  /// `stopPictureInPicture()` cagrilmaz ve pencere KAPANMAZ (turu 24/26 dersi: kimlik
  /// degisince `kur()` -> `birak()` zinciri pencereyi olduruyordu).
  /// Kullanim: kendi kameram arka planda olurse KARSI TARAFIN videosuna dus (o akmaya
  /// devam eder) — pencere bos/donuk kalmasin.
  @discardableResult
  func kaynakDegistir(trackId: String, kaynak: String) -> Bool {
    guard let r = renderer, pipController != nil else { return false }
    if kurulanId == trackId { return true }
    let eklenti = FlutterWebRTCPlugin.sharedSingleton()
    var bulunan = eklenti?.remoteTrack(forId: trackId) as? RTCVideoTrack
    if bulunan == nil {
      bulunan = eklenti?.track(forId: trackId, peerConnectionId: nil) as? RTCVideoTrack
    }
    guard let yeni = bulunan else {
      NSLog("gebzem/pip kaynak degisimi: track BULUNAMADI id=\(trackId)")
      return false
    }
    uzakTrack?.remove(r)
    yeni.add(r)
    uzakTrack = yeni
    kurulanId = trackId
    kurulanKaynak = kaynak
    videoView?.displayLayer.flushAndRemoveImage()
    sonGorulenKare = -1
    sabitTik = 0
    gozcuDuyurdu = false
    NSLog("gebzem/pip kaynak DEGISTI -> \(kaynak)")
    return true
  }

  /// TEST TURU 37 — KAMERA KESINTISI (Apple bildirimi). Arka planda capture GERCEKTEN
  /// durdurulursa `AVCaptureSessionWasInterrupted` gelir. O an Dart'a haber veriyoruz ki
  /// (a) kamerayi DURUSTCE mute edelim -> karsi taraf bulanik "Kamera duraklatildi" gorsun
  /// (donmus kare DEGIL), (b) PiP penceresinde donmus kare yerine etiket cikar.
  func kesintileriDinle() {
    let nc = NotificationCenter.default
    nc.addObserver(forName: .AVCaptureSessionWasInterrupted, object: nil, queue: .main) { [weak self] n in
      guard let self = self else { return }
      let ham = (n.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue ?? -1
      // TEST TURU 43 — KESINTI ANINDA TAM RESIM (tek satirda karar verdirir):
      // uygulama durumu, PiP gercekten aktif mi, bayraklar, oturum sinifi (paylasilan
      // AVCaptureMultiCamSession mi?), oturum calisiyor mu.
      let durum = UIApplication.shared.applicationState == .active ? "aktif"
        : (UIApplication.shared.applicationState == .inactive ? "gecis" : "arka")
      let pipAktif = self.pipController?.isPictureInPictureActive ?? false
      var sinif = "yok"
      var calisiyor = false
      var destek = false
      var acik = false
      if let s = (n.object as? AVCaptureSession)
        ?? FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer?.captureSession {
        sinif = String(describing: type(of: s))
        calisiyor = s.isRunning
        if #available(iOS 16.0, *) {
          destek = s.isMultitaskingCameraAccessSupported
          acik = s.isMultitaskingCameraAccessEnabled
        }
      }
      NSLog("gebzem/pip KESINTI reason=\(ham) durum=\(durum) pip=\(pipAktif) sinif=\(sinif) calisiyor=\(calisiyor) destek=\(destek) acik=\(acik)")
      self.videoView?.kareKesildi()
      self.yerelGorunum?.kareKesildi()
      self.kanal?.invokeMethod("iosKameraKesinti", arguments: [
        "sebep": ham, "durum": durum, "pip": pipAktif, "sinif": sinif,
        "calisiyor": calisiyor, "destek": destek, "acik": acik,
      ])
      // TEST TURU 48 — KURTARMA DENEMESI SILINDI (turu 43'te eklenmis, 47'de "duzeltilmisti").
      // BELGE KANITI (Apple, `videoDeviceNotAvailableInBackground`):
      //   "Camera usage is PROHIBITED while in the background. If you attempt to START
      //    RUNNING a camera while in the background, the capture session sends a
      //    wasInterruptedNotification with this interruption reason. ... when your app comes
      //    back to FOREGROUND, you receive interruptionEndedNotification and your session
      //    starts running."
      // Yani arka planda `startRunning()` cagirmak kamerayi GERI GETIREMEZ; sadece YENI BIR
      // KESINTI daha uretir. Olcum de bunu dogruladi: `kurtarma=null` (hic sonuc donmedi).
      // Kamera ancak ON PLANA DONUNCE (`AVCaptureSessionInterruptionEnded`) geri gelir —
      // o dal asagida zaten var.
      // ⚠️ YAPMA: arka planda `startRunning()` cagiran bir "kurtarma" tekrar ekleme.
    }
    nc.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: nil, queue: .main) { [weak self] _ in
      NSLog("gebzem/pip kamera kesinti BITTI")
      self?.kanal?.invokeMethod("iosKameraKesintiBitti", arguments: nil)
    }
  }

  func kur(trackId: String, yerelTrackId: String? = nil, kaynak: String = "yerel") -> Bool {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }
    guard let kaynakView = Self.kokView() else { return false }
    // TEST TURU 15: UZAK track once (arama/izleyici); bulunamazsa YEREL track (CANLI YAYIN
    // YAYINCISI kendi kamerasini PiP'te gorur — PiP aktifken iOS kamera CAPTURE'i surdurur,
    // yani izleyiciler DONMUS kare gormez). trackForId:peerConnectionId:nil yerel+uzak arar.
    let eklenti = FlutterWebRTCPlugin.sharedSingleton()
    var bulunan = eklenti?.remoteTrack(forId: trackId) as? RTCVideoTrack
    if bulunan == nil {
      bulunan = eklenti?.track(forId: trackId, peerConnectionId: nil) as? RTCVideoTrack
    }
    guard let track = bulunan else { return false }

    if kurulanId == trackId, pipController != nil { return true }
    birak()

    let vv = PipVideoView(frame: CGRect(x: 0, y: 0, width: 120, height: 200))
    let r = PipRenderer(view: vv)
    track.add(r)

    let vc = AVPictureInPictureVideoCallViewController()
    // TEST TURU 34 — GERI ALMA (kullanici: "alta indirdigimde SACMA sekilde UZUN bir ekran
    // olmus"): turu 32'de bolunmus kutular icin 120x400 yapilmisti; pencere asiri dar-uzun
    // gorunuyor. Pencere artik TEK VIDEO gosterdigi icin dogru oran 9:16 portredir.
    // ⚠️ YAPMA: bolunme olmadan preferredContentSize'i uzatma.
    // TEST TURU 53 — PENCERE ORANI (kullanici: "PiP ekranini %10 buyut, orantı olarak bir
    // tik daha genis olsun, iPhone ve Android AYNI olsun").
    // ⚠️ ONEMLI: `preferredContentSize` MUTLAK BOYUT DEGILDIR — iOS yalnizca EN-BOY
    // ORANINI kullanir (120x213 yerine 132x234 yazmak pencereyi BUYUTMEZ). Android'de de
    // `setAspectRatio` disinda boyut API'si YOKTUR. Dolayisiyla "%10 buyut + ikisi ayni"
    // isteginin tek dogru karsiligi ORTAK ve BIR TIK DAHA GENIS bir ORAN secmektir.
    // SECILEN: 5:6 (0.833) — Android'in eski 3:4'unden (0.75) %11 daha genis, iOS'un eski
    // 0.563'unu de ayni degere cikarir. MainActivity.kt `Rational(5, 6)` ile AYNI.
    // ⚠️ YAPMA: bunu calisma aninda degistirme (pencere yeniden boyutlanma animasyonu
    // tetikler = turu 46/49 gecis titremesi riski); iki platformu farkli oranda birakma.
    vc.preferredContentSize = CGSize(width: 5, height: 6)
    // Yigin bosluklari 0 olsa da kutu ARALARINDAN callVC.view'in ATANMAMIS (siyah) zemini
    // gorunebiliyor -> videoyla ayni koyu tona sabitle (kullanici: "gridler arasinda
    // siyahlik olmasin"). ⚠️ YAPMA: bunu seffaf/siyah birakma.
    vc.view.backgroundColor = UIColor(red: 0.09, green: 0.13, blue: 0.16, alpha: 1)
    // TEST TURU 27 — DOGRU YONTEMLE BOLUNME: dikey yigin (UIStackView). UZAK video USTTE
    // SABIT durur; KENDI kameram alta `yerelAyarla` ile SONRADAN eklenir/cikarilir.
    // KRITIK FARK (turu 24 hatasi): PiP controller BIR KEZ kurulur ve kimlik SADECE uzak
    // track'tir — alt gorunum degisse bile controller'a DOKUNULMAZ. Eskiden kimlik
    // "uzak|yerel" oldugu icin kamera arka planda kapaninca kurulum yikilip yeniden
    // kuruluyor ve pencere HIC acilmiyordu.
    let yigin = UIStackView(arrangedSubviews: [vv])
    yigin.axis = .vertical
    yigin.distribution = .fillEqually
    yigin.spacing = 0 // turu 53: kutular arasi SIYAH CIZGI olmasin
    vc.view.pipAddConstrained(yigin)
    self.yigin = yigin

    let source = AVPictureInPictureController.ContentSource(
      activeVideoCallSourceView: kaynakView, contentViewController: vc)
    let controller = AVPictureInPictureController(contentSource: source)
    controller.delegate = self
    controller.canStartPictureInPictureAutomaticallyFromInline = true

    self.videoView = vv
    self.renderer = r
    self.uzakTrack = track
    self.callVC = vc
    self.pipController = controller
    self.kurulanId = trackId
    // Kurulumla BIRLIKTE alt gorunum istendiyse ekle (parametre artik GERCEKTEN kullanilir;
    // turu 28'e kadar olu parametreydi). Kimlik yine SADECE uzak track -> yikim yok.
    if let yid = yerelTrackId, !yid.isEmpty { yerelAyarla(trackId: yid) }
    self.kurulanKaynak = kaynak
    // TEST TURU 39: kare gozcusu — kare akmayi keserse donmus kare yerine etiket + Dart'a
    // haber (Dart karsi tarafin videosuna SICAK gecis yapar, pencere KAPANMADAN).
    gozcuBaslat()
    NSLog("gebzem/pip iOS kuruldu track=\(trackId) kaynak=\(kaynak)")
    return true
  }

  /// TEST TURU 20 — PiP'i ELLE BASLAT (kullanici bulgusu: "iPhone'da alta alinca kucuk pencere
  /// GELMIYOR"). Otomatik giris (canStartPictureInPictureAutomaticallyFromInline) telefonun
  /// Ayarlar > Genel > Resim icinde Resim > "PiP'i Otomatik Baslat" secenegine ve Dusuk Guc
  /// Modu'na baglidir — kullanicinin elinde. Apple, uygulama ON PLANDAYKEN startPictureInPicture()
  /// cagrisina izin verir; bu yuzden uygulama arka plana GECERKEN (willResignActive) PiP'i
  /// kendimiz baslatiyoruz -> AYARDAN BAGIMSIZ kucuk pencere.
  /// TEST TURU 46 — TEK BASLATMA KAPISI (kullanici: "alta alirken zorlaniyorum, ekran
  /// kayiyor ama inmiyor, zorla indiriyorum").
  ///
  /// KOK NEDEN: TEK bir home hareketinde `baslat()` **5 kaynaktan** cagriliyordu:
  ///   1) SceneDelegate `sceneWillResignActive` (turu 43 — KALDIRILDI)
  ///   2) Dart lifecycle `inactive`   -> method channel
  ///   3) Dart lifecycle `hidden`     -> method channel   (Flutter iOS'ta ucunu de gonderir)
  ///   4) Dart lifecycle `paused`     -> method channel
  ///   5) iOS'un KENDI auto-enter'i (`canStartPictureInPictureAutomaticallyFromInline`)
  /// Tek mevcut koruma `isPictureInPictureActive` idi ve o, ACILIS ANIMASYONU boyunca
  /// FALSE doner -> hicbirini durdurmuyordu. Sonuc: sistemin uygulama-kuculme animasyonuyla
  /// AYNI ANDA yarisan birden fazla PiP acilis animasyonu = gorulen surtunme.
  ///
  /// COZUM: bayrakli tek-istek kapisi + 1.5sn emniyet zamanlayicisi. Bayrak
  /// didStart/didStop/failedToStart/durdur/birak dallarinda SIFIRLANIR.
  /// ⚠️ YAPMA: bayragi `isPictureInPicturePossible == false` iken SET ETME — pencere hic
  /// acilamaz duruma gelir (turu 20 regresyonu). Emniyet zamanlayicisini de kaldirma.
  func baslat() {
    guard let c = pipController else { return }
    if c.isPictureInPictureActive { return }
    if baslatIstendi { return } // ayni gecis icin ZATEN istendi
    // TEST TURU 49 — TURU 48'DEKI `.background` KAPISI KALDIRILDI (KANITLI REGRESYON).
    // Turu 48'de buraya `if applicationState == .background { return }` konmustu; teorik
    // olarak dogruydu (Apple manuel start'i on planda bekler) AMA OLCUM tersini soyledi:
    //   turu 46/47: `ios kesinti ... pip=TRUE`   (pencere aciliyordu)
    //   turu 48:    `ios kesinti ... pip=FALSE`  (pencere HIC acilmadi + olcum satiri YOK)
    // Sebep: Dart `inactive` tetigi native'e METHOD CHANNEL uzerinden ASENKRON iner; cagri
    // yerine vardiginda UIKit COKTAN `.background`a gecmis olabiliyor -> tek gercek denememiz
    // de bu kapiya takiliyordu. Pencere acilmayinca kamera kesiliyor (kose kutusu donuyor).
    // ⚠️ YAPMA: bu kapiyi geri koyma. Arka planda basarisiz denemenin kamerayi oldurmesi
    // riski, `failedToStart` dalindaki 800ms'lik teyit gecikmesiyle kapatildi (asagida).
    // Henuz mumkun degilse (ilk kare gelmemis) bayragi SET ETMEDEN cik — sonraki tetik denesin.
    if !c.isPictureInPicturePossible { return }
    iptalIstendi = false // yeni baslatma istegi: bekleyen iptali temizle
    baslatIstendi = true
    baslatCagri += 1
    baslatKoruma?.invalidate()
    baslatKoruma = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
      self?.baslatIstendi = false // delegate hic gelmediyse kilit acilsin
    }
    let t0 = CACurrentMediaTime()
    c.startPictureInPicture()
    let ms = Int((CACurrentMediaTime() - t0) * 1000)
    if ms > baslatMsMax { baslatMsMax = ms }
  }

  /// Baslatma kilidini sifirla (delegate dallarindan cagrilir).
  private func baslatKilidiAc() {
    baslatIstendi = false
    baslatKoruma?.invalidate()
    baslatKoruma = nil
  }

  /// TEST TURU 27 — ALT GORUNUM (kendi kamera) EKLE/CIKAR. PiP controller'a DOKUNMAZ:
  /// yalniz dikey yigina gorunum eklenir/cikarilir; pencere kurulumu bozulmaz, kapanmaz.
  /// [trackId] nil/bos -> alt gorunum kaldirilir (tek video).
  @discardableResult
  func yerelAyarla(trackId: String?, harf: String = "?") -> String {
    // TEST TURU 32: SESSIZ BASARISIZLIK BITTI — sonuc metni Dart'a doner, Dart Sentry'e yazar.
    // Kullanici "alttaki goruntu gelmiyor" dedi ve bu fonksiyon her hata yolunda SESSIZCE
    // donuyordu; artik hangi adimda durdugunu KESIN biliyoruz.
    guard let yigin = yigin, callVC != nil else { return "yigin-yok" }
    // Ayni track zaten ekli ise dokunma
    if let mevcut = yerelTrackId, mevcut == trackId { return "ayni" }
    // Once eskiyi sok — TURU 51: sokulen renderer MEZARLIGA (ucustaki kare cokmesin)
    if let yt = yerelTrack, let yr = yerelRenderer {
      yt.remove(yr)
      PipRenderer.mezaraKoy(yr)
    }
    yerelGorunum?.displayLayer.flushAndRemoveImage()
    yerelGorunum?.kareKesildi()
    if let yg = yerelGorunum {
      yigin.removeArrangedSubview(yg)
      yg.removeFromSuperview()
    }
    yerelGorunum = nil
    yerelRenderer = nil
    yerelTrack = nil
    yerelTrackId = nil
    guard let tid = trackId, !tid.isEmpty else { return "kaldirildi" }
    // Yerel track'i BULMA: once localTracks defteri (track(forId:peerConnectionId:nil)),
    // olmazsa uzak defter. Bulunamazsa ACIKCA raporla (eskiden sessizce donuyordu).
    let eklenti = FlutterWebRTCPlugin.sharedSingleton()
    var bulunan = eklenti?.track(forId: tid, peerConnectionId: nil) as? RTCVideoTrack
    if bulunan == nil { bulunan = eklenti?.remoteTrack(forId: tid) as? RTCVideoTrack }
    // TEST TURU 32 — ID ESLESMEZSE YEDEK YOL: livekit'in yerel kamera track'i eklentinin
    // `localTracks` defterinde BASKA bir anahtarla durabiliyor (Dart'taki mediaStreamTrack.id
    // ile birebir olmayabilir). O yuzden defteri TARAYIP ilk VIDEO track'i aliyoruz —
    // 1:1 aramada yerel video track'i zaten TEK olur. Boylece "alt kutu hic gelmiyor"
    // sikayetinin id-cozumleme kaynakli olma ihtimali kapaniyor.
    // ⚠️ YAPMA: bu yedegi uzak track icin kullanma (yanlis kisiyi cizer).
    // NOT: `localTracks` Objective-C NSMutableDictionary'dir — Swift'te `.keys` YOKTUR,
    // `allKeys` kullanilir ve elemanlar `Any` gelir (String'e cast SART).
    // TURU 51 — KOR SECIM DUZELTMESI (30 Tem denetimi, YUKSEK risk): eskiden defterdeki
    // ILK video track KOSULSUZ aliniyor, `readyState`/`isEnabled` HIC bakilmiyordu ve
    // sonuc "eklendi" donuyordu. Zombi onizleme track'i defterde duruyorsa kose kutusu
    // OLU track'e baglaniyor, Dart "basarili" sayip `_iosPipYerelId`i kilitliyor ve BIR
    // DAHA denemiyordu -> kutu ARAMA BOYUNCA "Sen" etiketinde kaliyordu.
    // Artik: yalniz CANLI (`.live`) track kabul edilir ve BIRDEN FAZLA aday varsa
    // TAHMIN EDILMEZ ("belirsiz" donulur; Dart sonraki tazelemede tekrar dener).
    // NOT: `localTracks` Objective-C NSMutableDictionary — anahtar sirasi deterministik
    // DEGILDIR, o yuzden "ilkini al" yanlis kamerayi da secebiliyordu.
    // ⚠️ YAPMA: canlilik kontrolunu kaldirma; birden fazla adayda tahmin yurutme.
    var belirsiz = false
    if bulunan == nil, let defter = eklenti?.localTracks {
      var adaylar: [RTCVideoTrack] = []
      for anahtarAny in defter.allKeys {
        guard let anahtar = anahtarAny as? String else { continue }
        if let v = eklenti?.track(forId: anahtar, peerConnectionId: nil) as? RTCVideoTrack,
           v.readyState == .live, v.isEnabled {
          adaylar.append(v)
        }
      }
      if adaylar.count == 1 {
        bulunan = adaylar[0]
        NSLog("gebzem/pip kose kutusu: id eslesmedi, defterde TEK canli track bulundu")
      } else if adaylar.count > 1 {
        belirsiz = true
        NSLog("gebzem/pip kose kutusu: \(adaylar.count) canli aday — TAHMIN YOK")
      }
    }
    if belirsiz { return "belirsiz" }
    // Bulunan track OLU ise kabul etme (donmus/bos kutu yerine durust etiket).
    if let b = bulunan, b.readyState != .live {
      NSLog("gebzem/pip kose kutusu: track OLU (readyState=\(b.readyState.rawValue))")
      return "track-olu"
    }
    guard let yerel = bulunan else {
      NSLog("gebzem/pip alt gorunum: track BULUNAMADI id=\(tid)")
      return "track-yok"
    }
    // TEST TURU 42 — KOSE KUTUSU (WhatsApp gorunumu): eskiden dikey yigina eklenip pencereyi
    // IKIYE bolerdik; artik KARSI TARAF tam pencereyi kaplar, BEN sag-altta KUCUK bir kutu
    // olarak ONUN USTUNE binerim. Kullanici: "karsinin goruntusunun uzerine kendi goruntumde
    // var ufak".
    // ⚠️ iOS ARKA PLANDA kamerayi DURDURUR (olcum: oturum=false, kesinti sebep=1). O yuzden
    // kutu DONMUS KARE gostermesin diye kare gozcusu 1.5sn kare gormezse `kareKesildi()`
    // ile etiket/avatar gorunumune duser. Kutu HEP durur, icerigi durusttur.
    // TEST TURU 52 — GORUNUM (kullanici karari 31 Tem):
    //  · CERCEVE (borderWidth/borderColor) KALDIRILDI — buyuk ekrandaki kutuda da yok.
    //  · Kose yaricapi 5 -> 14 (buyuk ekrandaki kutuyla AYNI: call_screen.dart `_videoKutu`).
    //  · YUKSEKLIK %10 KUCULDU: en-boy 4:3 (1.333) -> 6:5 (1.2).
    //  · Genislik carpani 0.34 ve kenar bosluklari (-5) DEGISMEDI.
    //  · Ayni sayilar Android/Flutter tarafinda da (`mini_izgara.dart` `koseli`) kullanilir.
    // ⚠️ YAPMA: cerceveyi geri ekleme; `masksToBounds`u kaldirma (o cerceve degil, kose kirpma).
    let yv = PipVideoView(frame: CGRect(x: 0, y: 0, width: 44, height: 53))
    yv.layer.cornerRadius = 14
    yv.layer.masksToBounds = true
    let yr = PipRenderer(view: yv)
    yerel.add(yr)
    // Yigina DEGIL, pencerenin USTUNE koseye yerlestir (kisitlarla, %34 genislik / 6:5).
    if let kok = callVC?.view {
      yv.translatesAutoresizingMaskIntoConstraints = false
      kok.addSubview(yv)
      NSLayoutConstraint.activate([
        yv.trailingAnchor.constraint(equalTo: kok.trailingAnchor, constant: -5),
        yv.bottomAnchor.constraint(equalTo: kok.bottomAnchor, constant: -5),
        yv.widthAnchor.constraint(equalTo: kok.widthAnchor, multiplier: 0.34),
        yv.heightAnchor.constraint(equalTo: yv.widthAnchor, multiplier: 6.0 / 5.0),
      ])
      kok.layoutIfNeeded()
    } else {
      yigin.addArrangedSubview(yv)
      yigin.layoutIfNeeded()
    }
    yerelGorunum = yv
    yerelRenderer = yr
    yerelTrack = yerel
    yerelTrackId = tid
    NSLog("gebzem/pip kose kutusu EKLENDI id=\(tid)")
    return "eklendi"
  }

  /// TEST TURU 52 — KUCUK PENCERE IZGARASI (coklu uzak katilimci).
  /// [trackIdler]: ANA video DISINDAKI uzak katilimcilarin video track id'leri.
  /// Duzen (ana + ekler = toplam kutu):
  ///   1 kutu  -> tam pencere
  ///   2 kutu  -> UST / ALT  (kullanici: "3 kisi olunca ust alt, ben sagda kucuk")
  ///   3-8     -> 2 sutunlu satirlar; son satirda tek kalirsa TAM GENISLIK
  /// KOSE KUTUSU (ben) bundan BAGIMSIZ — `yerelAyarla` ile `callVC.view` uzerinde durur.
  ///
  /// ⚠️ KRITIK: bu metot `pipController`/`callVC`/`kurulanId`a DOKUNMAZ. Yalniz `yigin`
  /// icindeki gorunumler yeniden dizilir -> `stopPictureInPicture()` CAGRILMAZ, pencere
  /// KAPANMAZ (turu 24/26 dersi; `yerelAyarla` ile birebir ayni guvenli desen).
  /// ⚠️ YAPMA: ana video gorunumunu (`videoView`) yok etme — yalniz yerini degistir;
  /// yok edersen ana renderer'in katmani kopar ve buyuk kutu kararir.
  @discardableResult
  func ekKaynaklarAyarla(trackIdler: [String]) -> String {
    guard let yigin = yigin, let ana = videoView, callVC != nil else { return "yigin-yok" }
    if ekTrackIdler == trackIdler { return "ayni" }

    // ---- Eskiyi sok (renderer'lar MEZARLIGA — ucustaki kare cokmesin, turu 51) ----
    for (i, t) in ekTrackler.enumerated() where i < ekRendererlar.count {
      t.remove(ekRendererlar[i])
      PipRenderer.mezaraKoy(ekRendererlar[i])
    }
    ekTrackler.removeAll()
    ekRendererlar.removeAll()
    ekTrackIdler.removeAll()
    ekSonKare.removeAll()
    ekSabitTik.removeAll()
    for v in ekGorunumler {
      v.displayLayer.flushAndRemoveImage()
      v.removeFromSuperview()
    }
    ekGorunumler.removeAll()
    for s in satirYiginlari {
      yigin.removeArrangedSubview(s)
      s.removeFromSuperview()
    }
    satirYiginlari.removeAll()
    // Ana gorunumu yigindan AYIR (YOK ETME — renderer'i ona kare basmaya devam ediyor)
    yigin.removeArrangedSubview(ana)
    ana.removeFromSuperview()

    // ---- Yeni track'leri coz (yalniz CANLI olanlar; turu 51 kor-secim dersi) ----
    let eklenti = FlutterWebRTCPlugin.sharedSingleton()
    var kutular: [PipVideoView] = [ana]
    for tid in trackIdler {
      var b = eklenti?.remoteTrack(forId: tid) as? RTCVideoTrack
      if b == nil { b = eklenti?.track(forId: tid, peerConnectionId: nil) as? RTCVideoTrack }
      guard let t = b, t.readyState == .live, t.isEnabled else {
        NSLog("gebzem/pip ek kaynak ATLANDI (canli degil) id=\(tid)")
        continue
      }
      let v = PipVideoView(frame: CGRect(x: 0, y: 0, width: 120, height: 100))
      let r = PipRenderer(view: v)
      t.add(r)
      ekGorunumler.append(v)
      ekRendererlar.append(r)
      ekTrackler.append(t)
      ekTrackIdler.append(tid)
      ekSonKare.append(-1) // gozcu durumu (turu 52)
      ekSabitTik.append(0)
      kutular.append(v)
    }

    // ---- Duzen ----
    if kutular.count <= 2 {
      // 1 kutu: tam pencere · 2 kutu: UST / ALT (yigin zaten dikey fillEqually)
      for v in kutular { yigin.addArrangedSubview(v) }
    } else {
      // 3-8 kutu: 2 sutunlu satirlar. Son satirda TEK kutu kalirsa yatay yigin tek
      // eleman icerir ve fillEqually sayesinde TAM GENISLIK olur.
      var i = 0
      while i < kutular.count {
        let son = min(i + 2, kutular.count)
        let satir = UIStackView(arrangedSubviews: Array(kutular[i..<son]))
        satir.axis = .horizontal
        satir.distribution = .fillEqually
        satir.spacing = 0 // turu 53: kutular arasi SIYAH CIZGI olmasin
        yigin.addArrangedSubview(satir)
        satirYiginlari.append(satir)
        i = son
      }
    }
    yigin.layoutIfNeeded()
    NSLog("gebzem/pip izgara: \(kutular.count) kutu (ana + \(ekGorunumler.count) ek)")
    return "eklendi:\(kutular.count)"
  }

  /// TEST TURU 25: uygulama ON PLANA donunce PiP penceresini KAPAT. iOS gecici "inactive"
  /// anlarinda (bildirim/kontrol merkezi, izin uyarisi) PiP basliyor, uygulama geri gelince
  /// pencere ASILI kaliyordu (kullanici: "iPhone'da yine PiP kucuk ekranin ustunde cikiyor").
  /// TEST TURU 29 (kullanici: "iPhone'da PiP kucuk ekranin UZERINDE cikiyor"): artik
  /// KOSULSUZ. Eskiden `isPictureInPictureActive` guard'i vardi; PiP acilis ANIMASYONU
  /// surerken bu bayrak false oldugu icin durdurma NO-OP kaliyor, pencere uygulamanin
  /// USTUNDE asili kaliyordu. `iptalIstendi` ile GEC gelen didStart da durdurulur.
  func durdur() {
    baslatKilidiAc()
    // TURU 52 — OLCUM PENCERESI: `durdur()` uygulama ON PLANA donunce KOSULSUZ cagriliyor
    // (Dart `resumed` dali). Yani burasi "bir arka plan gecisi bitti" anidir. Sayaclari
    // BURADA sifirlamak, `cagri`/`iptal` degerlerinin TEK BIR alta almaya ait olmasini
    // garanti eder. Eskiden yalniz BASARILI olcumde sifirlaniyordu ve degerler
    // birikiyordu (kullanicinin gordugu 2 -> 4 -> 10).
    // ⚠️ YAPMA: bu sifirlamayi kaldirma (olcum yine bulanir ve yanlis teshise goturur).
    baslatCagri = 0
    iptalCagri = 0
    baslatMsMax = 0
    iptalIstendi = true
    // TURU 51: gozcu SADECE `birak()` ve `gozcuBaslat()` basinda duruyordu; `durdur()` ve
    // didStop yolunda calismaya devam edip PiP kapandiktan SONRA da sink ameliyati
    // (flushAndRemoveImage / kareKesildi / invokeMethod) tetikliyordu.
    // ⚠️ YAPMA: bu cagriyi kaldirma.
    gozcuDur()
    pipController?.stopPictureInPicture()
  }

  func birak() {
    baslatKilidiAc()
    gozcuDur()
    pipController?.stopPictureInPicture()
    // TURU 51: sokulen renderer'lar MEZARLIGA — ana is parcaciginda serbest birakip
    // ucustaki kare teslimini cokertmeyelim (Sentry EXC_BAD_ACCESS, alta alma ani).
    if let t = uzakTrack, let r = renderer {
      t.remove(r)
      PipRenderer.mezaraKoy(r)
    }
    if let yt = yerelTrack, let yr = yerelRenderer {
      yt.remove(yr)
      PipRenderer.mezaraKoy(yr)
    }
    // TURU 52: izgaradaki EK uzak kutular da sokulur (sink defterinde sarkmasin)
    for (i, t) in ekTrackler.enumerated() where i < ekRendererlar.count {
      t.remove(ekRendererlar[i])
      PipRenderer.mezaraKoy(ekRendererlar[i])
    }
    ekTrackler.removeAll()
    ekRendererlar.removeAll()
    ekTrackIdler.removeAll()
    ekSonKare.removeAll()
    ekSabitTik.removeAll()
    for v in ekGorunumler {
      v.displayLayer.flushAndRemoveImage()
      v.removeFromSuperview()
    }
    ekGorunumler.removeAll()
    satirYiginlari.removeAll()
    yerelGorunum?.displayLayer.flushAndRemoveImage()
    yerelGorunum?.kareKesildi()
    yerelTrack = nil
    yerelRenderer = nil
    yerelGorunum = nil
    yerelTrackId = nil
    yigin = nil
    videoView?.displayLayer.flushAndRemoveImage()
    callVC?.view.subviews.forEach { $0.removeFromSuperview() }
    pipController = nil
    callVC = nil
    videoView = nil
    renderer = nil
    uzakTrack = nil
    kurulanId = nil
  }

  private static func kokView() -> UIView? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for s in scenes {
      if let w = s.windows.first(where: { $0.isKeyWindow }) ?? s.windows.first,
         let v = w.rootViewController?.view {
        return v
      }
    }
    return nil
  }

  // TEST TURU 9: PiP GERCEKTEN basladi/durdu -> Flutter'a bildir (pipModunda). Boylece
  // kamera-mute yedegi PiP durumuna gore ayarlanir (PiP'te kamera acik kalir).
  func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
    baslatKilidiAc()
    // TEST TURU 29: PiP acilisi ANIMASYONLUDUR; bu sirada kullanici uygulamaya donmus
    // olabilir (Kontrol Merkezi, bildirim seridi, izin uyarisi da 'inactive' uretir ->
    // baslat cagrilir). Uygulama ON PLANDAYSA pencereyi ANINDA kapat; boylece arayuzun
    // ustunde asili kalmaz. ⚠️ YAPMA: bu kontrolu kaldirma (ust uste binme geri gelir).
    if iptalIstendi || UIApplication.shared.applicationState == .active {
      NSLog("gebzem/pip iOS PiP basladi ama uygulama ON PLANDA -> kapatiliyor")
      iptalIstendi = false
      iptalCagri += 1 // turu 52: iptaller AYRI sayilir (olcum bulanmasin)
      c.stopPictureInPicture()
      return
    }
    NSLog("gebzem/pip iOS PiP basladi")
    kanal?.invokeMethod("iosPipDurum", arguments: true)
    kareOlcumuBaslat() // turu 38: 3sn sonra kac kare aktigini bildir
  }
  func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
    baslatKilidiAc()
    // TURU 51: pencere kapandi -> gozcu SUSSUN (yoksa kapanmis pencere icin sink
    // ameliyati tetikleyip Dart'a yanlis `iosPipKareDurdu` gonderiyordu).
    gozcuDur()
    NSLog("gebzem/pip iOS PiP durdu")
    kanal?.invokeMethod("iosPipDurum", arguments: false)
  }
  func pictureInPictureController(_ c: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error) {
    baslatKilidiAc()
    NSLog("gebzem/pip iOS baslatma hatasi: \(error.localizedDescription)")
    // TEST TURU 49 — TEYIT GECIKMESI. `iosPipBasarisiz` Dart tarafinda KAMERAYI KAPATIR.
    // Artik tekrar denemeler oldugu icin (1200ms penceresi) BIR denemenin basarisizligi
    // "PiP hic olmayacak" demek DEGIL — sonraki deneme tutabilir. 800ms bekleyip pencere
    // GERCEKTEN acilmadiysa haber veriyoruz.
    // ⚠️ YAPMA: bu gecikmeyi kaldirip aninda `iosPipBasarisiz` gonderme (basarili bir
    // tekrardan hemen sonra kamera kapanir).
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
      guard let self = self else { return }
      if self.pipController?.isPictureInPictureActive == true { return }
      // ⚠️ TEST TURU 53 — KENDI IPTALIMIZI "BASARISIZLIK" SAYMA (kok neden).
      // `durdur()` (on plana donuste KOSULSUZ cagriliyor) `iptalIstendi = true` yazar ve
      // `stopPictureInPicture()` ile acilis animasyonunu yarida keser; AVKit bunu
      // `failedToStart` olarak bildirir. Eskiden bu Dart'a inip uygulama ON PLANDAYKEN
      // kamerayi kapatiyordu (kullanici: "app switcher'a alinca kamera kapaniyor,
      // WhatsApp'ta kapanmiyor").
      // NOT: bu, turu 49'daki "800ms gecikmeyi kaldirma" kuralini IHLAL ETMEZ — gecikme
      // DURUYOR, yalnizca basina kendi-iptal kontrolu eklendi. Ayrica turu 49'un
      // "`.background` kapisini geri koyma" kurali `baslat()` icindir, BURASI DEGIL.
      // ⚠️ YAPMA: bu kontrolu kaldirma; `baslat()`e `.background` kapisi ekleme.
      if self.iptalIstendi {
        NSLog("gebzem/pip failedToStart ama IPTAL BIZDEN — Dart'a bildirilmiyor")
        return
      }
      self.kanal?.invokeMethod("iosPipBasarisiz", arguments: nil)
    }
  }
  func pictureInPictureController(_ c: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler h: @escaping (Bool) -> Void) {
    h(true)
  }
}

@available(iOS 15.0, *)
// ============================================================================
// TEST TURU 37 — ARKA PLANDA KAMERA: BAYRAGI *BASLATMADAN ONCE* YAZAN KANCA
//
// KULLANICI: "iPhone'da alta aldigimda ekran YINE DONUYOR."
//
// KOK NEDEN (Apple resmi dokumani):
//   "If the value of isMultitaskingCameraAccessSupported is true, you can enable
//    multitasking camera access by setting this value to true PRIOR TO STARTING
//    THE CAPTURE SESSION."
//   https://developer.apple.com/documentation/avfoundation/avcapturesession/ismultitaskingcameraaccessenabled
// Bizim eski kodumuz bayragi session ZATEN CALISIRKEN yaziyordu. iOS yazmayi KABUL ediyor
// (geri okuma true doner) ama FIILEN ETKISIZ kaliyor -> arka planda capture duruyor ->
// PiP penceresi SON KAREDE donuyor ve karsi taraf da donmus kare goruyor. Ustelik bayrak
// "true" gorundugu icin uygulamanin "durust mute" yedegi de devre disi kaliyordu.
//
// COZUM: flutter_webrtc kamerayi `RTCCameraVideoCapturer.startCaptureWithDevice:...` ile
// baslatir; capture session bu cagridan ONCE (capturer init'inde) yaratilmis olur. Bu
// metodu swizzle edip ORIJINAL cagrilmadan HEMEN ONCE bayragi yaziyoruz. Boylece kamera
// her (yeniden) acilista dogru sirayla yapilandirilir — kamera ac/kapa, arka plandan
// donus, track restart dahil. Bu ayni zamanda "her mute/unmute YENI session yaratir,
// bayrak sifirlanir" sorununu da kokten kapatir.
//
// ⚠️ YAPMA: bu kancayi kaldirip bayragi yalniz Dart'tan (calisan session'a) yazmaya donme;
// pbxproj'a AYRI dosya EKLEME (BOM tuzagi — kod AppDelegate.swift icinde kalir);
// flutter_webrtc'yi fork'lamak yerine bu kanca tercih edildi (bagimlilik yonetimi basit).
@available(iOS 16.0, *)
enum GebzemKameraKanca {
  static func kur() {
    let cls: AnyClass = RTCCameraVideoCapturer.self
    let orijinalSel = #selector(RTCCameraVideoCapturer.startCapture(with:format:fps:completionHandler:))
    let bizimSel = #selector(RTCCameraVideoCapturer.gebzem_startCapture(with:format:fps:completionHandler:))
    guard let a = class_getInstanceMethod(cls, orijinalSel),
          let b = class_getInstanceMethod(cls, bizimSel) else {
      NSLog("gebzem/pip kamera kancasi KURULAMADI (selector bulunamadi)")
      return
    }
    method_exchangeImplementations(a, b)
    NSLog("gebzem/pip kamera kancasi kuruldu (bayrak start ONCESI yazilacak)")
  }
}

extension RTCCameraVideoCapturer {
  /// Swizzle edilmis giris noktasi. Govdedeki `gebzem_startCapture` cagrisi, takas
  /// sonrasi ORIJINAL implementasyona gider (sonsuz dongu DEGILDIR).
  @objc func gebzem_startCapture(with device: AVCaptureDevice,
                                 format: AVCaptureDevice.Format,
                                 fps: Int,
                                 completionHandler: ((Error?) -> Void)?) {
    if #available(iOS 16.0, *) {
      let s = self.captureSession
      if s.isMultitaskingCameraAccessSupported && !s.isMultitaskingCameraAccessEnabled {
        s.beginConfiguration()
        s.isMultitaskingCameraAccessEnabled = true
        s.commitConfiguration()
        NSLog("gebzem/pip bayrak START ONCESI yazildi=\(s.isMultitaskingCameraAccessEnabled)")
      }
    }
    self.gebzem_startCapture(with: device, format: format, fps: fps,
                             completionHandler: completionHandler)
  }
}

final class PipVideoView: UIView {
  override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
  var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }

  /// TEST TURU 32 — SIYAH KUTU YERINE YEDEK GORUNUM (kullanici: "ust/alt bolunme GORUNUYOR,
  /// karsinin goruntusu var ama BENIMKI yok"). Bolunme goruntugune gore alt kutu OLUSUYOR
  /// ama icine KARE AKMIYOR (kamera arka planda durmus). Bos siyah kutu yerine "Kamera
  /// duraklatildi" yazisi cizilir; ilk kare gelince kendiliginden gizlenir.
  private let etiket = UILabel()
  /// TEST TURU 52 — TUTARLI GORUNUM (kullanici: "yazinin arkasinda BAZEN mor daire var,
  /// hep ayni olsun, uygulama icindeki gibi"). Turu 43'te eklenen MOR DAIRE kaldirildi;
  /// artik Flutter'daki `BeklemedeOrtusu` ile AYNI dil: koyu zemin + SIYAH SEFFAF HAP
  /// icinde beyaz yazi. Boylece uygulama ici, iOS PiP ve Android PiP AYNI gorunur.
  /// NOT: `UIVisualEffectView` (blur) EKLENMEDI — katman `flushAndRemoveImage()` ile
  /// bosaltildigi icin bulaniklastirilacak goruntu KALMIYOR (blur'un gorsel etkisi olmaz)
  /// ve AVSampleBufferDisplayLayer uzerine blur bindirmek risklidir.
  /// ⚠️ YAPMA: mor daireyi geri ekleme; buraya UIVisualEffectView koyma.
  private let hap = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    displayLayer.videoGravity = .resizeAspectFill
    backgroundColor = UIColor(red: 0.09, green: 0.13, blue: 0.16, alpha: 1)

    hap.backgroundColor = UIColor(white: 0, alpha: 0.55)
    hap.layer.cornerRadius = 9
    hap.layer.masksToBounds = true
    hap.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hap)

    etiket.text = "Kamera duraklatıldı"
    etiket.textColor = .white
    etiket.font = .systemFont(ofSize: 9, weight: .semibold)
    etiket.textAlignment = .center
    etiket.numberOfLines = 2
    etiket.translatesAutoresizingMaskIntoConstraints = false
    hap.addSubview(etiket)
    NSLayoutConstraint.activate([
      hap.centerXAnchor.constraint(equalTo: centerXAnchor),
      hap.centerYAnchor.constraint(equalTo: centerYAnchor),
      hap.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
      hap.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
      etiket.topAnchor.constraint(equalTo: hap.topAnchor, constant: 4),
      etiket.bottomAnchor.constraint(equalTo: hap.bottomAnchor, constant: -4),
      etiket.leadingAnchor.constraint(equalTo: hap.leadingAnchor, constant: 7),
      etiket.trailingAnchor.constraint(equalTo: hap.trailingAnchor, constant: -7),
    ])
  }

  /// Etiket metnini degistir. TURU 52: tum kutular AYNI yaziyi gosterdigi icin bu artik
  /// yalniz ozel durumlar icin duruyor (kose kutusu da varsayilan yaziyi kullanir).
  func etiketiAyarla(_ metin: String) {
    etiket.text = metin
  }

  func kareGeldi() {
    if etiket.isHidden { return }
    etiket.isHidden = true
    hap.isHidden = true
  }

  func kareKesildi() {
    if !etiket.isHidden { return }
    etiket.isHidden = false
    hap.isHidden = false
  }

  required init?(coder: NSCoder) { fatalError() }
}

@available(iOS 15.0, *)
final class PipRenderer: NSObject, RTCVideoRenderer {
  private weak var view: PipVideoView?
  /// TURU 52 — TEK PAYLASILAN KUYRUK. Eskiden her PipRenderer KENDI `.userInteractive`
  /// kuyrugunu aciyordu; izgarada 8 kutu = 8 yuksek oncelikli kuyruk, hepsi ayni anda
  /// kare donusturuyor ve arka planda CPU'yu doyuruyordu. Artik hepsi TEK seri kuyrukta
  /// sirayla islenir (`.userInitiated` yeterli — 30fps video icin fazlasiyla hizli).
  /// ⚠️ YAPMA: bunu tekrar ornek-basina kuyruga cevirme.
  private static let kuyruk =
    DispatchQueue(label: "gebzem.pip.frame", qos: .userInitiated)
  private var kuyruk: DispatchQueue { Self.kuyruk }

  /// TURU 52 — PIKSEL ARABELLEK HAVUZU: `i420ToPixelBuffer` her karede YENI CVPixelBuffer
  /// ayiriyordu (8 kutu x 30fps = saniyede 240 ayirma/serbest birakma). Havuz ile ayni
  /// arabellek yeniden kullanilir. ⚠️ YAPMA: havuzu kaldirip her karede CVPixelBufferCreate'e donme.
  private var havuz: CVPixelBufferPool?
  private var havuzEn = 0
  private var havuzBoy = 0

  // ---- TEST TURU 51 — COKME ONLEME (Sentry kaniti: 29 Tem 18:39, son iz
  // `app.lifecycle: background`, EXC_BAD_ACCESS KERN_INVALID_ADDRESS 0x6c8, yigin
  // AVCaptureVideoDataOutput._processSampleBuffer -> AdaptedVideoTrackSource::OnFrame
  // -> Runner). KOK: kare teslimi WebRTC/capture is parcaciginda kosarken, ANA is
  // parcacigi `track.remove(renderer)` yapip referansi nil'liyordu; UCUSTAKI teslim
  // sirasinda nesne serbest kalinca kucuk-ofsetli erisim ihlali olusuyordu.
  // Cozum iki katmanli: (1) `aktif` bayragi kilitle korunur ve sokme aninda kapatilir,
  // (2) sokulen renderer MEZARLIGA alinir (2sn) — yani ucustaki kare bitmeden nesne
  // ASLA serbest birakilmaz.
  // ⚠️ YAPMA: bu kilidi/mezarligi kaldirma; sayaclari kilitsiz okumaya donme.
  private let durumKilidi = NSLock()
  private var aktif = true
  private var sayac = 0
  private var _toplamKare = 0

  /// TEST TURU 38: OLCUM — kac kare geldi (PiP basladiktan sonraki 3sn icin).
  var toplamKare: Int {
    durumKilidi.lock()
    defer { durumKilidi.unlock() }
    return _toplamKare
  }

  func sayaciSifirla() {
    durumKilidi.lock()
    _toplamKare = 0
    durumKilidi.unlock()
  }

  /// Sink defterinden sokulurken cagrilir: bundan sonra gelen kareler YOK SAYILIR.
  func kapat() {
    durumKilidi.lock()
    aktif = false
    durumKilidi.unlock()
  }

  /// Sokulen renderer'lari kisa sure canli tutan mezarlik (bkz. yukaridaki not).
  private static var mezarlik: [PipRenderer] = []
  private static let mezarlikKilidi = NSLock()
  static func mezaraKoy(_ r: PipRenderer?) {
    guard let r = r else { return }
    r.kapat()
    mezarlikKilidi.lock()
    mezarlik.append(r)
    mezarlikKilidi.unlock()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      mezarlikKilidi.lock()
      if let i = mezarlik.firstIndex(where: { $0 === r }) { mezarlik.remove(at: i) }
      mezarlikKilidi.unlock()
    }
  }

  init(view: PipVideoView) { self.view = view }
  func setSize(_ size: CGSize) {}

  func renderFrame(_ frame: RTCVideoFrame?) {
    guard let frame = frame else { return }
    durumKilidi.lock()
    guard aktif else { durumKilidi.unlock(); return }
    _toplamKare += 1
    sayac += 1
    let atla = sayac % 2 != 0
    durumKilidi.unlock()
    if atla { return }
    kuyruk.async { [weak self] in
      guard let self = self else { return }
      autoreleasepool {
        guard let sb = self.sampleBuffer(frame) else { return }
        DispatchQueue.main.async { [weak self] in
          guard let v = self?.view else { return }
          if v.displayLayer.status == .failed { v.displayLayer.flush() }
          // PiP-DONMA FIX (test turu 8): layer hazir degilken enqueue etmek layer'i
          // failed'a surukluyordu -> pencere ILK karede kaliyordu. Hazir degilse kareyi
          // birak (canli yayin — sonraki kare 66ms sonra zaten gelir).
          guard v.displayLayer.isReadyForMoreMediaData else { return }
          v.displayLayer.enqueue(sb)
          v.kareGeldi() // turu 32: ilk kare geldi -> "Kamera duraklatildi" yazisi gizlensin
        }
      }
    }
  }

  private func sampleBuffer(_ frame: RTCVideoFrame) -> CMSampleBuffer? {
    var pixelBuffer: CVPixelBuffer?
    if let b = frame.buffer as? RTCCVPixelBuffer {
      pixelBuffer = b.pixelBuffer
    } else if let b = frame.buffer as? RTCI420Buffer {
      pixelBuffer = i420ToPixelBuffer(b)
    }
    guard let pb = pixelBuffer else { return nil }

    var fmt: CMVideoFormatDescription?
    guard CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault, imageBuffer: pb, formatDescriptionOut: &fmt) == noErr,
      let fmt = fmt else { return nil }

    // PiP-DONMA FIX (test turu 8, kok neden): PTS frame.timeStampNs idi — WebRTC'nin RTP
    // tabanli saati, AVSampleBufferDisplayLayer'in host-clock timebase'iyle ALAKASIZ ->
    // layer ilk kareyi gosterip PTS'i "gelecekte/gecmiste" kalan kareleri BEKLETIYORDU
    // (klasik "PiP ilk karede donuyor" belirtisi). Referans desen (videosdk/react-native-
    // webrtc): host clock PTS + kCMSampleAttachmentKey_DisplayImmediately=true.
    let ts = CMTimeMakeWithSeconds(CACurrentMediaTime(), preferredTimescale: 1_000_000_000)
    var timing = CMSampleTimingInfo(
      duration: .invalid, presentationTimeStamp: ts, decodeTimeStamp: .invalid)
    var sb: CMSampleBuffer?
    guard CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault, imageBuffer: pb, formatDescription: fmt,
      sampleTiming: &timing, sampleBufferOut: &sb) == noErr, let buf = sb else { return nil }
    if let atts = CMSampleBufferGetSampleAttachmentsArray(buf, createIfNecessary: true),
       CFArrayGetCount(atts) > 0 {
      let dict = unsafeBitCast(CFArrayGetValueAtIndex(atts, 0), to: CFMutableDictionary.self)
      CFDictionarySetValue(dict,
        Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
    }
    return buf
  }

  private func i420ToPixelBuffer(_ b: RTCI420Buffer) -> CVPixelBuffer? {
    let w = Int(b.width), h = Int(b.height)
    // TURU 52: HAVUZ — cozunurluk degismedikce ayni arabellekler yeniden kullanilir.
    // Eskiden her karede CVPixelBufferCreate cagriliyordu; izgarada 8 kutu x 30fps =
    // saniyede ~240 ayirma. Havuz bunu neredeyse sifira indirir.
    if havuz == nil || havuzEn != w || havuzBoy != h {
      let attrs: [CFString: Any] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        kCVPixelBufferWidthKey: w,
        kCVPixelBufferHeightKey: h,
      ]
      var yeni: CVPixelBufferPool?
      guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil,
        attrs as CFDictionary, &yeni) == kCVReturnSuccess, let yeni = yeni else { return nil }
      havuz = yeni
      havuzEn = w
      havuzBoy = h
    }
    var pb: CVPixelBuffer?
    guard let h0 = havuz,
      CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, h0, &pb) == kCVReturnSuccess,
      let pb = pb else { return nil }
    guard CVPixelBufferLockBaseAddress(pb, []) == kCVReturnSuccess else { return nil }
    defer { CVPixelBufferUnlockBaseAddress(pb, []) }

    if let yDest = CVPixelBufferGetBaseAddressOfPlane(pb, 0) {
      let dStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
      let sStride = Int(b.strideY)
      for row in 0..<h {
        memcpy(yDest.advanced(by: row * dStride), b.dataY + row * sStride, min(sStride, w))
      }
    }
    if let uvDest = CVPixelBufferGetBaseAddressOfPlane(pb, 1) {
      let dStride = CVPixelBufferGetBytesPerRowOfPlane(pb, 1)
      let uvW = w / 2, uvH = h / 2
      let uStride = Int(b.strideU), vStride = Int(b.strideV)
      for row in 0..<uvH {
        let dst = uvDest.advanced(by: row * dStride).assumingMemoryBound(to: UInt8.self)
        let uRow = b.dataU + row * uStride
        let vRow = b.dataV + row * vStride
        for col in 0..<uvW {
          dst[col * 2] = uRow[col]
          dst[col * 2 + 1] = vRow[col]
        }
      }
    }
    return pb
  }
}

private extension UIView {
  // NOT (turu 28): UST/ALT bolunme artik UIStackView ile (GebzemPip.kur + yerelAyarla).
  // Eski `pipAddStacked` kaldirildi — kisitlarla kurulan sabit duzen, alt gorunum
  // sonradan eklenince yeniden kurulum gerektiriyordu.
  func pipAddConstrained(_ sub: UIView) {
    addSubview(sub)
    sub.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      sub.leadingAnchor.constraint(equalTo: leadingAnchor),
      sub.trailingAnchor.constraint(equalTo: trailingAnchor),
      sub.topAnchor.constraint(equalTo: topAnchor),
      sub.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}
