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
        let tid = (call.arguments as? [String: Any])?["trackId"] as? String ?? ""
        result(tid.isEmpty ? false : GebzemPip.shared.kur(trackId: tid))
      case "iosPipBirak":
        GebzemPip.shared.birak()
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
    // BEKLET'i KAPAT: Gebzem CallKit aramasi "beklenebilir" (holdable) bildirilmesin. Yoksa arama
    // sirasinda GSM gelince iOS "Beklet ve Kabul" gosterir; kullanici secince beklet-swap
    // (flutter-webrtc #1996 bug) Gebzem'i KOPARIYOR. false olunca yalniz "Bitir ve Kabul" cikar.
    // KRITIK: bu native Data varsayilani supportsHolding=TRUE idi; Dart IOSParams bu kilit-ekrani
    // yoluna HIC ulasmiyordu (kullanicinin "false yaptim ama cikti" sorununun kok nedeni).
    data.supportsHolding = false
    data.supportsGrouping = false
    data.supportsVideo = true
    data.duration = 45000
    data.extra = [
      "call_id": callId, "call_type": isVideo ? "video" : "audio", "caller_name": callerName,
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
  private var kurulanId: String?

  // TEST TURU 9: COKLU-GOREV KAMERA — kamerayi PiP/arka planda CAPTURE'a devam ettir
  // (goruntulu aramada alta alinca KARSI TARAF beni gormeye devam eder). flutter_webrtc
  // videoCapturer PUBLIC property (FlutterWebRTCPlugin.h) + RTCCameraVideoCapturer.captureSession
  // WebRTC SDK'da public. Entitlement GEREKMEZ (iOS16+ property; iOS16-17 destek cihaza bagli).
  // Desteksiz -> false -> Dart kamera-mute avatar yedegine duser. SES BIRIMINE DOKUNMAZ.
  func cokluGorevKameraAc() -> Bool {
    guard #available(iOS 16.0, *) else { return false }
    guard let capturer = FlutterWebRTCPlugin.sharedSingleton()?.videoCapturer else { return false }
    let session = capturer.captureSession
    guard session.isMultitaskingCameraAccessSupported else { return false }
    if session.isMultitaskingCameraAccessEnabled { return true } // zaten acik (idempotent)
    session.beginConfiguration()
    session.isMultitaskingCameraAccessEnabled = true
    session.commitConfiguration()
    NSLog("gebzem/pip coklu-gorev kamera ACIK (arka planda kamera surer)")
    return true
  }

  func kur(trackId: String) -> Bool {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }
    guard let kaynakView = Self.kokView() else { return false }
    guard let track = FlutterWebRTCPlugin.sharedSingleton()?
      .remoteTrack(forId: trackId) as? RTCVideoTrack else { return false }

    if kurulanId == trackId, pipController != nil { return true }
    birak()

    let vv = PipVideoView(frame: CGRect(x: 0, y: 0, width: 120, height: 200))
    let r = PipRenderer(view: vv)
    track.add(r)

    let vc = AVPictureInPictureVideoCallViewController()
    vc.preferredContentSize = CGSize(width: 120, height: 200)
    vc.view.pipAddConstrained(vv)

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
    NSLog("gebzem/pip iOS kuruldu track=\(trackId)")
    return true
  }

  func birak() {
    pipController?.stopPictureInPicture()
    if let t = uzakTrack, let r = renderer { t.remove(r) }
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
    NSLog("gebzem/pip iOS PiP basladi")
    kanal?.invokeMethod("iosPipDurum", arguments: true)
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
final class PipVideoView: UIView {
  override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
  var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
  override init(frame: CGRect) {
    super.init(frame: frame)
    displayLayer.videoGravity = .resizeAspectFill
    backgroundColor = .black
  }
  required init?(coder: NSCoder) { fatalError() }
}

@available(iOS 15.0, *)
final class PipRenderer: NSObject, RTCVideoRenderer {
  private weak var view: PipVideoView?
  private let kuyruk = DispatchQueue(label: "gebzem.pip.frame", qos: .userInteractive)
  private var sayac = 0

  init(view: PipVideoView) { self.view = view }
  func setSize(_ size: CGSize) {}

  func renderFrame(_ frame: RTCVideoFrame?) {
    guard let frame = frame else { return }
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
