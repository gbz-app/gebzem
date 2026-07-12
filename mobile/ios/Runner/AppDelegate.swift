import Flutter
import UIKit
import PushKit
import CallKit
import flutter_callkit_incoming

// KILIT EKRANINDA GELEN ARAMA (iOS)
//
// iOS 13+ MUTLAK KURALI: VoIP push (PushKit) alindiginda, pushRegistry(...) icinde
// AYNI calisma dongusunde CallKit'e "yeni gelen arama" bildirilmek ZORUNDADIR.
// Bildirilmezse iOS uygulamayi oldurur ("never posted an incoming call to the system
// after receiving a PushKit VoIP push") ve tekrarlarsa VoIP push teslimatini KESER.
// Bu yuzden asagida KOSULLU CIKIS (guard/return) YOKTUR — payload bozuk olsa bile
// bos degerlerle arama ekrani gosterilir.
//
// Ses oturumu: CallKit AVAudioSession'i kendi yonetir. WebRTC/LiveKit'in odaya
// baglanmasi, kullanici KABUL ETTIKTEN sonra (Dart tarafinda actionCallAccept
// olayinda) yapilir — boylece iki taraf ses oturumu icin kavga etmez.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // PushKit (VoIP) kaydi
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - PKPushRegistryDelegate

  /// VoIP token'i olustu/yenilendi -> Dart tarafina bildirilir, oradan sunucuya kaydedilir
  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials,
                    for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry,
                    didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  /// VoIP push geldi -> CallKit'e HEMEN bildir (kosulsuz!)
  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType,
                    completion: @escaping () -> Void) {

    let d = payload.dictionaryPayload
    let callId = (d["call_id"] as? String) ?? UUID().uuidString
    let callerName = (d["caller_name"] as? String) ?? "Bilinmeyen"
    let isVideo = ((d["call_type"] as? String) ?? "audio") == "video"

    let data = flutter_callkit_incoming.Data(
      id: callId,
      nameCaller: callerName,
      handle: callerName,
      type: isVideo ? 1 : 0
    )
    data.appName = "Gebzem"
    data.supportsVideo = true
    data.duration = 45000
    // Not: textAccept/textDecline iOS'ta YOK (CallKit buton metinlerini sistem verir);
    // onlar Android'e ozel (AndroidParams).
    data.extra = [
      "call_id": callId,
      "call_type": isVideo ? "video" : "audio",
      "caller_name": callerName,
    ] as NSDictionary

    // fromPushKit: true -> CallKit'e reportNewIncomingCall yapar (ZORUNLU)
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
    completion()
  }
}
