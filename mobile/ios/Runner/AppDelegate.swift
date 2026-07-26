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
        result(GebzemPip.shared.yerelAyarla(
          trackId: (call.arguments as? [String: Any])?["trackId"] as? String))
      case "iosPipKaynak":
        // TEST TURU 39: pencereyi KAPATMADAN gosterilen videoyu degistir
        let a = call.arguments as? [String: Any]
        result(GebzemPip.shared.kaynakDegistir(
          trackId: a?["trackId"] as? String ?? "", kaynak: a?["kaynak"] as? String ?? "uzak"))
      case "iosPipKareBosalt":
        // TEST TURU 38: kamera kapatilirken donmus kare yerine "Kamera duraklatildi"
        GebzemPip.shared.kareyiBosalt()
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
  private var kurulanId: String?
  private var iptalIstendi = false // turu 29: on plana donuldu -> bekleyen baslatmayi iptal et

  // ---- TEST TURU 39: KARE GOZCUSU + SICAK KAYNAK DEGISIMI ----
  /// Pencerede su an KIMIN videosu var ("yerel" = kendi kameram, "uzak" = karsi taraf).
  private(set) var kurulanKaynak = "yerel"
  private var gozcu: Timer?
  private var sonGorulenKare = -1
  private var sabitTik = 0
  /// ON PLAN kare sayisi (PiP baslarken okunur) — teshis icin.
  private var onPlanKare = 0
  private var gozcuDuyurdu = false

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
    if session.isMultitaskingCameraAccessEnabled { return true }
    // Kanca herhangi bir sebeple kurulamadiysa (selector degisti vb.) son care olarak dene.
    session.beginConfiguration()
    session.isMultitaskingCameraAccessEnabled = true
    session.commitConfiguration()
    let ok = session.isMultitaskingCameraAccessEnabled
    NSLog("gebzem/pip coklu-gorev kamera (GEC yazim, etkisiz olabilir) = \(ok)")
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

  /// TEST TURU 38 — KESIN OLCUM: PiP basladiktan 3sn sonra KAC KARE aktigini Dart'a bildir.
  /// Kullanici iki turdur "yine donuyor" diyor; bu sayi tahmini bitirir:
  /// kare=0 -> capture gercekten durmus; kare>0 -> goruntu akiyor, sorun baska yerde.
  func kareOlcumuBaslat() {
    // TEST TURU 39 — IKI TARAFLI OLCUM. Turu 38'in tek yonlu olcumu (yalniz arka plan) su
    // ayrimi YAPAMIYORDU: (a) renderer hic canli track'e baglanmamis (ON PLAN da 0),
    // (b) track dogru ama arka planda capture duruyor (on plan >0, arka 0).
    onPlanKare = renderer?.toplamKare ?? 0
    renderer?.sayaciSifirla()
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self = self else { return }
      let arka = self.renderer?.toplamKare ?? -1
      var oturum = false
      var coklu = false
      if #available(iOS 16.0, *),
         let s = FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer?.captureSession {
        oturum = s.isRunning
        coklu = s.isMultitaskingCameraAccessEnabled
      }
      NSLog("gebzem/pip olcum on=\(self.onPlanKare) arka=\(arka) kaynak=\(self.kurulanKaynak) oturum=\(oturum) coklu=\(coklu)")
      self.kanal?.invokeMethod("iosPipOlcum", arguments: [
        "on": self.onPlanKare, "arka": arka, "kaynak": self.kurulanKaynak,
        "oturum": oturum, "coklu": coklu,
      ])
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
      let ham = (n.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue ?? -1
      NSLog("gebzem/pip kamera KESINTI reason=\(ham)")
      self?.videoView?.kareKesildi()
      self?.yerelGorunum?.kareKesildi()
      self?.kanal?.invokeMethod("iosKameraKesinti", arguments: ham)
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
    vc.preferredContentSize = CGSize(width: 120, height: 213)
    // TEST TURU 27 — DOGRU YONTEMLE BOLUNME: dikey yigin (UIStackView). UZAK video USTTE
    // SABIT durur; KENDI kameram alta `yerelAyarla` ile SONRADAN eklenir/cikarilir.
    // KRITIK FARK (turu 24 hatasi): PiP controller BIR KEZ kurulur ve kimlik SADECE uzak
    // track'tir — alt gorunum degisse bile controller'a DOKUNULMAZ. Eskiden kimlik
    // "uzak|yerel" oldugu icin kamera arka planda kapaninca kurulum yikilip yeniden
    // kuruluyor ve pencere HIC acilmiyordu.
    let yigin = UIStackView(arrangedSubviews: [vv])
    yigin.axis = .vertical
    yigin.distribution = .fillEqually
    yigin.spacing = 1
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
  func baslat() {
    guard let c = pipController else { return }
    if c.isPictureInPictureActive { return }
    iptalIstendi = false // yeni baslatma istegi: bekleyen iptali temizle
    // isPictureInPicturePossible false ise (ilk kare henuz gelmemis) cagri sessizce duser;
    // delegate failedToStart -> Dart kamera-mute yedegine gecer (mevcut davranis).
    c.startPictureInPicture()
  }

  /// TEST TURU 27 — ALT GORUNUM (kendi kamera) EKLE/CIKAR. PiP controller'a DOKUNMAZ:
  /// yalniz dikey yigina gorunum eklenir/cikarilir; pencere kurulumu bozulmaz, kapanmaz.
  /// [trackId] nil/bos -> alt gorunum kaldirilir (tek video).
  @discardableResult
  func yerelAyarla(trackId: String?) -> String {
    // TEST TURU 32: SESSIZ BASARISIZLIK BITTI — sonuc metni Dart'a doner, Dart Sentry'e yazar.
    // Kullanici "alttaki goruntu gelmiyor" dedi ve bu fonksiyon her hata yolunda SESSIZCE
    // donuyordu; artik hangi adimda durdugunu KESIN biliyoruz.
    guard let yigin = yigin else { return "yigin-yok" }
    // Ayni track zaten ekli ise dokunma
    if let mevcut = yerelTrackId, mevcut == trackId { return "ayni" }
    // Once eskiyi sok
    if let yt = yerelTrack, let yr = yerelRenderer { yt.remove(yr) }
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
    if bulunan == nil, let defter = eklenti?.localTracks {
      for anahtarAny in defter.allKeys {
        guard let anahtar = anahtarAny as? String else { continue }
        if let v = eklenti?.track(forId: anahtar, peerConnectionId: nil) as? RTCVideoTrack {
          bulunan = v
          NSLog("gebzem/pip alt gorunum: id eslesmedi, defterden bulundu anahtar=\(anahtar)")
          break
        }
      }
    }
    guard let yerel = bulunan else {
      NSLog("gebzem/pip alt gorunum: track BULUNAMADI id=\(tid)")
      return "track-yok"
    }
    let yv = PipVideoView(frame: CGRect(x: 0, y: 0, width: 120, height: 200))
    let yr = PipRenderer(view: yv)
    yerel.add(yr)
    yigin.addArrangedSubview(yv)
    yigin.layoutIfNeeded()
    yerelGorunum = yv
    yerelRenderer = yr
    yerelTrack = yerel
    yerelTrackId = tid
    NSLog("gebzem/pip alt gorunum EKLENDI id=\(tid)")
    return "eklendi"
  }

  /// TEST TURU 25: uygulama ON PLANA donunce PiP penceresini KAPAT. iOS gecici "inactive"
  /// anlarinda (bildirim/kontrol merkezi, izin uyarisi) PiP basliyor, uygulama geri gelince
  /// pencere ASILI kaliyordu (kullanici: "iPhone'da yine PiP kucuk ekranin ustunde cikiyor").
  /// TEST TURU 29 (kullanici: "iPhone'da PiP kucuk ekranin UZERINDE cikiyor"): artik
  /// KOSULSUZ. Eskiden `isPictureInPictureActive` guard'i vardi; PiP acilis ANIMASYONU
  /// surerken bu bayrak false oldugu icin durdurma NO-OP kaliyor, pencere uygulamanin
  /// USTUNDE asili kaliyordu. `iptalIstendi` ile GEC gelen didStart da durdurulur.
  func durdur() {
    iptalIstendi = true
    pipController?.stopPictureInPicture()
  }

  func birak() {
    gozcuDur()
    pipController?.stopPictureInPicture()
    if let t = uzakTrack, let r = renderer { t.remove(r) }
    if let yt = yerelTrack, let yr = yerelRenderer { yt.remove(yr) }
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
    // TEST TURU 29: PiP acilisi ANIMASYONLUDUR; bu sirada kullanici uygulamaya donmus
    // olabilir (Kontrol Merkezi, bildirim seridi, izin uyarisi da 'inactive' uretir ->
    // baslat cagrilir). Uygulama ON PLANDAYSA pencereyi ANINDA kapat; boylece arayuzun
    // ustunde asili kalmaz. ⚠️ YAPMA: bu kontrolu kaldirma (ust uste binme geri gelir).
    if iptalIstendi || UIApplication.shared.applicationState == .active {
      NSLog("gebzem/pip iOS PiP basladi ama uygulama ON PLANDA -> kapatiliyor")
      iptalIstendi = false
      c.stopPictureInPicture()
      return
    }
    NSLog("gebzem/pip iOS PiP basladi")
    kanal?.invokeMethod("iosPipDurum", arguments: true)
    kareOlcumuBaslat() // turu 38: 3sn sonra kac kare aktigini bildir
  }
  func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
    NSLog("gebzem/pip iOS PiP durdu")
    kanal?.invokeMethod("iosPipDurum", arguments: false)
  }
  func pictureInPictureController(_ c: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error) {
    NSLog("gebzem/pip iOS baslatma hatasi: \(error.localizedDescription)")
    // PiP baslatilamadi -> Dart kamerayi kapatir (arka planda donuk kare yerine avatar)
    kanal?.invokeMethod("iosPipBasarisiz", arguments: nil)
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

  override init(frame: CGRect) {
    super.init(frame: frame)
    displayLayer.videoGravity = .resizeAspectFill
    backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    etiket.text = "Kamera duraklatıldı"
    etiket.textColor = UIColor(white: 1, alpha: 0.75)
    etiket.font = .systemFont(ofSize: 9, weight: .semibold)
    etiket.textAlignment = .center
    etiket.numberOfLines = 2
    etiket.translatesAutoresizingMaskIntoConstraints = false
    addSubview(etiket)
    NSLayoutConstraint.activate([
      etiket.centerXAnchor.constraint(equalTo: centerXAnchor),
      etiket.centerYAnchor.constraint(equalTo: centerYAnchor),
      etiket.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
      etiket.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
    ])
  }

  /// Kare akiyor mu bilgisi (PipRenderer cagirir; ana kuyrukta).
  func kareGeldi() {
    if etiket.isHidden { return }
    etiket.isHidden = true
  }

  func kareKesildi() {
    if !etiket.isHidden { return }
    etiket.isHidden = false
  }

  required init?(coder: NSCoder) { fatalError() }
}

@available(iOS 15.0, *)
final class PipRenderer: NSObject, RTCVideoRenderer {
  private weak var view: PipVideoView?
  private let kuyruk = DispatchQueue(label: "gebzem.pip.frame", qos: .userInteractive)
  private var sayac = 0
  /// TEST TURU 38: OLCUM — kac kare geldi (PiP basladiktan sonraki 3sn icin).
  private(set) var toplamKare = 0
  func sayaciSifirla() { toplamKare = 0 }

  init(view: PipVideoView) { self.view = view }
  func setSize(_ size: CGSize) {}

  func renderFrame(_ frame: RTCVideoFrame?) {
    guard let frame = frame else { return }
    toplamKare += 1
    sayac += 1
    if sayac % 2 != 0 { return }
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
    let attrs: [CFString: Any] = [
      kCVPixelBufferIOSurfacePropertiesKey: [:],
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]
    var pb: CVPixelBuffer?
    guard CVPixelBufferCreate(kCFAllocatorDefault, w, h,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs as CFDictionary, &pb) == kCVReturnSuccess,
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
