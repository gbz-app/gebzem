import Flutter
import UIKit
import PushKit
import CallKit
import AVFAudio
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
        RTCAudioSession.sharedInstance().isAudioEnabled = (call.arguments as? Bool) ?? false
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
  }

  // MARK: - CallkitIncomingAppDelegate (plugin UIApplication.shared.delegate uzerinden cagirir)
  // CallKit sesi aktive edince WebRTC'ye devret + ses birimini AC (asil duzeltme).
  func didActivateAudioSession(_ audioSession: AVAudioSession) {
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
