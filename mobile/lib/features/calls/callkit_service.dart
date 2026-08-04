import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'pip_service.dart'; // turu 64: iOS hucresel arama gozcusu defteri

/// Kilit ekraninda / uygulama kapaliyken gelen arama.
///
/// MIMARI (arastirma sonucu):
///  - iOS: APNs **VoIP push** (PushKit) -> AppDelegate CallKit'e bildirir -> kilit
///    ekraninda gercek arama ekrani. FCM VoIP push GONDEREMEZ, bu yuzden sunucu
///    dogrudan APNs'e gonderiyor (backend/internal/push/apns.go).
///    iOS 13+ KURALI: VoIP push gelince CallKit'e reportNewIncomingCall ZORUNLU;
///    cagirmazsan iOS uygulamayi oldurur ve VoIP push'lari keser.
///  - Android: FCM **data-only** push -> arka plan isleyicisi -> tam ekran arama.
///    ("notification" tipli push'ta kodumuz calismaz, sadece tepside bildirim cikar.)
///
/// Uygulama ACIKKEN gelen arama zaten WebSocket ile geliyor (hizli, calisiyor) —
/// o yol korunuyor; CallKit arka plan/kapali durum icin.
class CallKitService {
  CallKitService._();
  static final CallKitService instance = CallKitService._();

  /// CallKit uzerinden ele alinan aramalar — uygulama one gelince ayni arama
  /// icin ikinci bir "gelen arama" ekrani acilmasin diye.
  static final Set<String> islenenler = {};

  /// TEST TURU 57: BIZIM BASLATTIGIMIZ (giden) CallKit aramalari.
  /// Bu id'ler icin gelen "kabul" olaylari YOK SAYILIR — aksi halde arayan taraf
  /// KENDI aramasini cevaplamaya calisir ve sunucu 404 doner (bkz. `_olay`).
  /// `gidenArama()` doldurur, `bitir()` ve `davetSifirla()` bosaltir.
  static final Set<String> gidenler = {};

  StreamSubscription? _sub;

  /// Kabul edilen arama (uygulama kapaliyken kabul edildiyse acilista da gelir)
  final _kabulController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onKabul => _kabulController.stream;

  /// Kullanicinin KASTEN reddettigi/bitirdigi arama (CallKit Decline/Ended) -> sunucuya bildir.
  final _redController = StreamController<String>.broadcast();
  Stream<String> get onRed => _redController.stream;

  /// 45sn CallKit AUTO-EXPIRE (zaman asimi) — reddet/bitir'den AYRI kanal. KABUL sonrasi
  /// (canli arama) gelirse SPURIOUS'tur (arama suruyor), aramayi bitirmemeli; ringing'de
  /// (kabul edilmemis) gercek cevapsizdir. Tek-bitir-kapisi bu ayrimla korunur.
  final _timeoutController = StreamController<String>.broadcast();
  Stream<String> get onTimeout => _timeoutController.stream;

  /// iOS VoIP token'i (sunucuya kaydedilecek)
  final _voipTokenController = StreamController<String>.broadcast();
  Stream<String> get onVoipToken => _voipTokenController.stream;

  /// ARAMA BEKLETME (test turu 18): CallKit "Beklet" (CXSetHeldCallAction) — GSM aramasi
  /// geldiginde ya da kullanici "Beklet ve Kabul" dediginde iOS gonderir. {id, on}
  final _holdController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onHold => _holdController.stream;

  /// Bizim programatik kapattigimiz aramalar. endCall() yeni bir "ended" olayi
  /// uretir; onu tekrar sunucuya "end" olarak GONDERMEMEK icin isaretliyoruz
  /// (yoksa bitir -> endCall -> ended -> end -> ... geri besleme dongusu).
  static final Set<String> _bizBitirdik = {};

  Future<void> baslat() async {
    // onError: ACTION_CALL_TOGGLE_AUDIO_SESSION gibi id'siz olaylar FormatException
    // firlatiyor; yutulmazsa Sentry'e gurultu olarak duser (ses zaten native yonetiliyor).
    _sub ??= FlutterCallkitIncoming.onEvent.listen(_olay, onError: (e, _) {
      debugPrint('callkit olay yutuldu: $e');
    });

    // Uygulama CallKit'ten kabul edilerek SIFIRDAN acilmis olabilir — olay,
    // Flutter motoru hazir olmadan gecmis olabilir. Bekleyeni sor.
    try {
      final aktif = await FlutterCallkitIncoming.activeCalls();
      for (final c in aktif) {
        if (c.isAccepted) {
          islenenler.add(c.id);
          _kabulController.add(_ayikla(c));
        }
      }
    } catch (e) {
      debugPrint('callkit activeCalls: $e');
    }

    await _voipTokeniGonder();
  }

  /// Oturum acildiktan SONRA VoIP token'i yeniden al ve sunucuya gonder. Acilista token
  /// alinip POST edilirken oturum yoktu (401 yutuluyor) -> giris/kayit sonrasi cagrilmali;
  /// yoksa iOS'ta voip_tokens satiri hic olusmaz ve kilit ekraninda arama calmaz.
  Future<void> voipTokeniYenidenGonder() => _voipTokeniGonder();

  /// TEST TURU 33 — KILITLI iPHONE CALMIYOR (kullanici: "Android'den goruntulu arayinca
  /// iPhone kilitliyken ekran gelmiyor, uygulamadayken geliyor").
  ///
  /// KOK NEDEN: kilit ekraninda arama YALNIZ VoIP push ile gelir; uygulama acikken WS yolu
  /// calisir (o yuzden "uygulamadayken geliyor"). VoIP token'i sunucuya gonderme TEK DENEME
  /// idi: PushKit kaydi ASENKRON oldugu icin giris aninda token HENUZ BOS olabiliyor ->
  /// `getDevicePushTokenVoIP()` bos donuyor -> hicbir sey gonderilmiyor ve BIR DAHA
  /// DENENMIYORDU (token olayi ise girisTEN ONCE tetiklenmis olabilir). Sonuc: voip_tokens
  /// satiri hic olusmuyor, kilitli telefon sessiz kaliyor. Her surumde DB temizlendigi icin
  /// bu durum tekrar tekrar olusuyordu.
  ///
  /// COZUM: token gelene kadar artan araliklarla TEKRAR DENE (2,4,6,8,10sn — toplam ~30sn).
  /// ⚠️ YAPMA: tek denemeye geri donme.
  Future<void> _voipTokeniGonder({int deneme = 0}) async {
    if (!Platform.isIOS) return;
    try {
      final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (t != null && t.isNotEmpty) {
        _voipTokenController.add(t);
        return;
      }
    } catch (e) {
      debugPrint('callkit voip token: $e');
    }
    if (deneme < 5) {
      Future.delayed(Duration(seconds: 2 * (deneme + 1)),
          () => _voipTokeniGonder(deneme: deneme + 1));
    } else {
      debugPrint('callkit voip token: alinamadi (kilit ekraninda arama calmayabilir)');
    }
  }

  void _olay(CallEvent? e) {
    switch (e) {
      // ⚠️⚠️ TEST TURU 57 — KOK NEDEN (turu 55 REGRESYONU, sunucu loguyla kanitli):
      // Turu 55'te GIDEN aramayi da CallKit'e kaydetmeye basladik (`gidenArama`).
      // Bunun beklenmeyen sonucu: ARAYAN tarafta da CallKit'te aktif bir arama olusuyor
      // ve CallKit "kabul" olayi uretince biz KENDI GIDEN ARAMAMIZI cevaplamaya
      // calisiyorduk -> `POST /calls/{id}/answer` sunucuda 404 "arama bulunamadi"
      // (cunku `callee_id` BIZ DEGILIZ). Kanit: 2 Agu testinde 6 kez 404, hepsi arayanin
      // cihazindan ve aramanin ZATEN cevaplanmasindan saniyeler sonra.
      // ZINCIRLEME HASAR: 404 -> `main.dart` catch dali -> `CallKitService.bitir(callId)`
      // -> CallKit kaydimiz YOK EDILIYOR -> iOS ses oturumunu birakiyor ve GERI VERMIYOR
      // -> GSM bekletmesinden sonra Gebzem SESSIZ kaliyor ("kaldigi yerden devam etmiyor").
      // FIX: kendi BASLATTIGIMIZ aramalarin kabul olaylari YOK SAYILIR.
      // ⚠️ YAPMA: bu kapiyi kaldirma; `gidenler` kumesini `gidenArama` disinda doldurma.
      case CallEventActionCallAccept(:final callKitParams):
        if (gidenler.contains(callKitParams.id)) {
          debugPrint('CALLKIT: kendi GIDEN aramamizin kabul olayi — yok sayildi');
          return;
        }
        islenenler.add(callKitParams.id);
        _kabulController.add(_ayikla(callKitParams));

      case CallEventActionCallDecline(:final callKitParams):
      case CallEventActionCallEnded(:final callKitParams):
        final id = callKitParams.id;
        islenenler.add(id);
        // BIZ kapattiysak (bitir/call.ended), tekrar sunucuya end gonderme -> dongu kir
        if (_bizBitirdik.remove(id)) break;
        _redController.add(id);

      case CallEventActionCallTimeout(:final id):
        islenenler.add(id);
        _timeoutController.add(id); // 45sn auto-expire — kabul sonrasi SPURIOUS olabilir (onRed DEGIL)

      // TEST TURU 18: iOS CallKit "Beklet" (CXSetHeldCallAction) -> medyayi durdur/geri ac
      // ⚠️⚠️ TEST TURU 56 — KOK NEDEN (36 turdur sessizce bozuktu):
      // Bu olay eklentiden `action.callUUID.uuidString` ile geliyor ve Foundation
      // `UUID.uuidString`i **BUYUK HARF** dondurur ("E621E1F8-..."). Bizim callId'lerimiz
      // Postgres `gen_random_uuid()` = **KUCUK HARF**. Dart tarafinda `beklemeyeAl`
      // TAM ESITLIK karsilastirdigi icin ESLESMIYOR ve metot SESSIZCE return ediyordu:
      // GSM aramasi kabul edilse bile medya DURMUYOR, sunucuya `hold` GITMIYOR.
      // (Kabul/Reddet/Bitir olaylari etkilenmiyor cunku onlar BIZIM gonderdigimiz orijinal
      //  string'i tasiyor — YALNIZ hold ve mute olaylari uuidString kullaniyor.)
      // ⚠️ YAPMA: burada ham `id`yi dogrudan yayinlama.
      case CallEventActionCallToggleHold(:final id, :final isOnHold):
        _holdController.add({'call_id': _asilId(id), 'on': isOnHold == true});

      case CallEventActionDidUpdateDevicePushTokenVoip():
        _voipTokeniGonder(); // token olayla gelmiyor, ayrica sorulmali

      default:
        break;
    }
  }

  /// TEST TURU 56: CallKit'ten BUYUK HARF gelen uuid'i, bizim bildigimiz ORIJINAL
  /// callId'ye cevirir. `islenenler` kumesi hem `goster()` (gelen) hem `gidenArama()`
  /// (giden) tarafindan doldurulur, yani her iki yonde de dogru kaynaktir.
  /// Eslesme yoksa ham degeri dondurur (davranis bozulmaz).
  /// ⚠️ YAPMA: bu cevrimi kaldirma (hold/mute olaylari bir daha eslesmez).
  static String _asilId(String ham) {
    for (final k in islenenler) {
      if (k.toLowerCase() == ham.toLowerCase()) return k;
    }
    return ham;
  }

  Map<String, dynamic> _ayikla(CallKitParams p) {
    final extra = Map<String, dynamic>.from(p.extra ?? {});
    // TEST TURU 35 (kullanici: "grup aramasinda KATIL ekranini kaldirmissin"): grup bayragi
    // CallKit yukunde TASINMIYORDU — backend gonderiyor (handler.go is_group/chat_title) ama
    // istemci UC yerde dusuruyordu (native extras, goster extras, burasi). Sonuc: kilitli /
    // arka plan yolunda "bu bir grup" bilgisi kabul aninda YOK -> davet ekrani cizilemiyordu.
    // ⚠️ YAPMA: is_group/chat_title'i bu haritadan tekrar dusurme.
    final grup = extra['is_group'] == true || extra['is_group'] == 'true';
    return {
      'call_id': p.id,
      'caller_name': p.nameCaller ?? '',
      'video': (p.type ?? 0) == 1 || (extra['call_type'] as String? ?? '') == 'video',
      'is_group': grup,
      'chat_title': extra['chat_title'] as String? ?? '',
      // turu 55: ikinci arama mi (beklet / bitir-kabul yolu)
      'waiting': extra['waiting'] == true || extra['waiting'] == 'true',
    };
  }

  /// Gelen arama ekranini goster (kilit ekraninda da calisir)
  static Future<void> goster({
    required String callId,
    required String callerName,
    required bool video,
    String avatar = '',
    bool isGroup = false, // turu 35: grup davet ("Katil") ekrani icin SART
    String chatTitle = '',
    // TEST TURU 55: ARAMA BEKLETME. Backend UC kanalda da `waiting` gonderiyor
    // (WS/FCM/VoIP) ama istemci UC yerde birden DUSURUYORDU — turu 34-36'da `is_group`
    // icin yasanan hatanin AYNISI. `waiting` dusunce ikinci arama "beklet" ekrani yerine
    // duz Kabul/Reddet olarak cizilir. ⚠️ YAPMA: bu alani tekrar dusurme.
    bool waiting = false,
  }) async {
    if (callId.isEmpty) return;
    // TANI: push isleyicisi tetiklendi mi? (kilit ekrani gorunmuyorsa logcat'te ara)
    debugPrint('CALLKIT-GOSTER: callId=$callId video=$video');
    islenenler.add(callId);
    // TURU 64: hucresel arama gozcusu (iOS) bu aramayi "GSM" SAYMAMALI.
    unawaited(PipService.gebzemAramaKaydet(callId));
    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: callId, // arama id'si zaten UUID — CallKit de UUID ister
      nameCaller: callerName.isEmpty ? 'Bilinmeyen' : callerName,
      appName: 'Gebzem',
      avatar: avatar.isEmpty ? null : avatar,
      handle: callerName,
      type: video ? 1 : 0,
      duration: 45000, // 45 sn sonra kendiliginden kapansin (arama zaten cevapsiz olur)
      extra: <String, dynamic>{
        'call_id': callId,
        'call_type': video ? 'video' : 'audio',
        'is_group': isGroup, // turu 35: kabul aninda grup oldugunu bilelim
        'chat_title': chatTitle,
        'waiting': waiting, // turu 55: ikinci arama -> "Beklet ve Kabul" yolu
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowFullLockedScreen: true, // KILIT EKRANINDA TAM EKRAN
        isImportant: true,
        // KRITIK: false OLMALI. true iken paket startActivity() cagiriyor -> bu bir
        // "arka plandan Activity baslatma"; Android 10+ ve Xiaomi uygulama kapaliyken
        // bunu SESSIZCE engelliyor ("Background activity launch blocked") -> ekran
        // gorunmuyor, kullanici elle acinca geliyor (yasadigimiz semptom).
        // false iken setFullScreenIntent'li bildirim yayinlaniyor -> USE_FULL_SCREEN_INTENT
        // sayesinde bu engelden MUAF (Google'in kill/kilit ekrani icin onayladigi tek yol).
        isFullScreen: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B141A',
        actionColor: '#25D366',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Gelen aramalar',
        missedCallNotificationChannelName: 'Cevapsız aramalar',
        textAccept: 'Kabul et',
        textDecline: 'Reddet',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        // TEST TURU 18 — ARAMA BEKLETME: iOS "Beklet ve Kabul / Bitir ve Kabul / Reddet"
        // ekranini SISTEM cizer; sarti aktif aramanin BEKLENEBILIR olmasi + grup basina
        // en az 2 arama. (Eskiden 1/false idi -> ozellik KAPALIYDI.) Beklet olayini artik
        // KENDIMIZ isliyoruz (medya durur, oda ACIK kalir; donuste ses birimi tazelenir) —
        // eski "GSM beklet-swap aramayi koparıyor" sorununun kok nedeni islenmemesiydi.
        // ⚠️⚠️ TURU 66 — BEKLETME KAPATILDI (kullanici emri 4 Agu: "beklemeyi
        // yapmayalim, kabul et ve bitir olsun"). `supportsHolding:false` ile iOS
        // ikinci aramada "Beklet ve Kabul" YERINE **"Bitir ve Kabul"** cizer — hem
        // Gebzem hem HUCRESEL aramalar icin. Gerekce: bekletmeden CIKIS bizim
        // kontrolumuzde degil (turu 65 kaniti: CallKit ses oturumunu geri vermiyor,
        // bizim aktive denememiz `!pri` ile reddediliyor).
        // ⚠️ YAPMA: kullanici emri olmadan `true` yapma; `maximumCallsPerCallGroup`i
        //     1'in ustune cikarma (ikisi birlikte "beklet" ekranini geri getirir).
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        // Ses oturumunu CallKit yonetsin; LiveKit odaya KABULDEN SONRA baglanir.
        configureAudioSession: true,
        audioSessionMode: 'voiceChat',
        // audioSessionActive:false -> arama CALARKEN AVAudioSession'i AKTIVE ETME. true iken
        // arama daha calarken oturum aktive edilip iOS sistem ZILI BASTIRILIYORDU (kullanicinin
        // "iPhone'da gelen zil calmiyor" semptomu). Ses KABULDEN sonra didActivateAudioSession
        // (AppDelegate) ile aciliyor; configureAudioSession:true bunu garanti eder.
        audioSessionActive: false,
      ),
    ));
  }

  /// Arama iptal edildi/bitti — CallKit ekranini kapat (programatik).
  /// SADECE gercekten gosterilmis bir CallKit aramasi varsa endCall cagir. Yoksa
  /// (uygulama acik/WS ile yuruyorsa CallKit hic gosterilmedi) endCall bos isimli bir
  /// CEVAPSIZ ARAMA bildirimi uretiyor -> ekranda UUID ("karmasik harfler") gorunuyor.
  /// ⚠️⚠️ TEST TURU 55 — GIDEN ARAMAYI CALLKIT'E KAYDET (iOS).
  ///
  /// KULLANICI SIKAYETI (ekran goruntusuyle): "birebirde konusurken baskasi aradiginda
  /// 'Bitir ve Kabul / Reddet / Beklet ve Kabul' ekrani GELMIYOR; biz bunu yapmistik."
  ///
  /// KOK NEDEN: o ekrani **iOS'un kendisi** cizer ve sarti, CallKit'te `supportsHolding`
  /// olan **AKTIF bir arama** bulunmasidir. Kod tabaninda `startCall` HIC YOKTU: CallKit'e
  /// yalnizca GELEN aramalar bildiriliyordu. Yani:
  ///   · Seni ARADILARSA  -> CallKit'te aktif arama VAR  -> ikinci aramada ekran CIKAR ✓
  ///   · SEN ARADIYSAN    -> CallKit bos                 -> duz Kabul/Reddet cikar ✗
  /// Fark sesli/goruntulu DEGIL, **ARAYAN/ARANAN** farkiydi (kullanici goruntuluyu
  /// genelde kendi baslattigi icin "goruntuluede gelmiyor" gibi gorunuyordu).
  ///
  /// SES RISKI YOK (kontrol edildi): `AppDelegate` `setAudioEnabled(true)` hem CallKit'li
  /// hem CallKit'siz yolda dogru calisir — CallKit'li yolda `setConfiguration` fark
  /// kontroluyle NO-OP kalir. Yani 19 Tem'deki "grup-host sessiz mic" hatasi GERI GELMEZ.
  ///
  /// YALNIZ iOS: Android'de ikinci arama UI'sini BIZ ciziyoruz (`incoming_call_overlay`
  /// `waiting` daliyla) ve `startCall` orada ondeplan servisiyle cakisan ikinci bir
  /// bildirim uretebilir.
  /// ⚠️ YAPMA: bunu Android'de de cagirma; `endCall`i atlamak (arama bitince `bitir()`
  /// zaten kapatir — hayalet CallKit araması kalmasin).
  static Future<void> gidenArama({
    required String callId,
    required String peerAd,
    required bool video,
  }) async {
    if (!Platform.isIOS || callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.startCall(CallKitParams(
        id: callId,
        nameCaller: peerAd.isEmpty ? 'Arama' : peerAd,
        appName: 'Gebzem',
        handle: peerAd,
        type: video ? 1 : 0,
        extra: <String, dynamic>{'call_id': callId},
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: true,
          // "Beklet ve Kabul" ekraninin SARTI — gelen arama tarafiyla AYNI degerler.
          // TURU 66: GIDEN arama tarafi da AYNI degerlerde olmali (bkz. yukaridaki serh).
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          configureAudioSession: true,
          audioSessionMode: 'voiceChat',
          audioSessionActive: false,
        ),
      ));
      islenenler.add(callId); // cift-UI kapisi: bu arama CallKit'te KAYITLI
      gidenler.add(callId); // turu 57: kendi giden aramamiz — kabul olaylari YOK SAYILIR
      // TURU 64: hucresel arama gozcusu (iOS) bu aramayi "GSM" SAYMAMALI.
      unawaited(PipService.gebzemAramaKaydet(callId));
    } catch (e) {
      debugPrint('CALLKIT-GIDEN hata: $e');
    }
  }

  /// TEST TURU 56 — GIDEN ARAMAYI "BAGLANDI" OLARAK BILDIR (iOS).
  /// `startCall` aramayi CallKit'te "araniyor/connecting" durumunda birakir; eklenti
  /// `connectedAt` bildirimini YALNIZ `setCallConnected` cagrilinca yapar ve biz hic
  /// cagirmiyorduk. iOS BAGLI OLMAYAN bir aramayi HOLD EDILEBILIR saymaz — yani GSM
  /// aramasi gelince "Beklet ve Kabul" secenegi cikmayabilir (turu 55'in eksik halkasi).
  /// Karsi taraf kabul edip odaya baglaninca BIR KEZ cagrilir.
  /// ⚠️ YAPMA: gelen aramalarda cagirma (CXAnswerCallAction zaten bagli sayar).
  static Future<void> baglandi(String callId) async {
    if (!Platform.isIOS || callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (e) {
      debugPrint('CALLKIT-BAGLANDI hata: $e');
    }
  }

  static Future<void> bitir(String callId) async {
    if (callId.isEmpty) return;
    // TURU 64: gozcu defterinden CIKAR. ⚠️ `varMi` kapisinin USTUNDE — kayit CallKit'te
    // hic gorunmese bile deftere yazilmis olabilir, orada asili birakma.
    unawaited(PipService.gebzemAramaSil(callId));
    try {
      final aktif = await FlutterCallkitIncoming.activeCalls();
      final varMi = aktif.any((c) => c.id == callId);
      if (!varMi) return; // hic gosterilmedi -> hayalet bildirim URETME
      _bizBitirdik.add(callId);
      gidenler.remove(callId); // turu 57: kayit kapandi
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  static Future<void> hepsiniBitir() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
  }

  /// Android 14+: "tam ekran bildirim" AYRI bir ozel izindir. Play Store disi
  /// (sideload) kurulumda OTOMATIK VERILMEZ -> verilmezse kilitli ekranda arama
  /// ekrani HIC acilmaz, sadece bildirim cikar.
  static Future<void> izinleriIste() async {
    if (!Platform.isAndroid) return;
    try {
      final bildirim = await FlutterCallkitIncoming.requestNotificationPermission({
        'title': 'Bildirim izni',
        'rationaleMessagePermission':
            'Gelen aramaları görebilmek için bildirim izni gerekiyor.',
        'postNotificationMessageRequired':
            'Bildirim izni olmadan gelen aramalar gösterilemez.',
      });
      // ⚠️⚠️ TEST TURU 56 — SIRA KRITIK (36 turdur GSM BEKLETME HIC CALISMIYORDU).
      // KOK NEDEN: `requestFullIntentPermission()` fire-and-forget SISTEM AYARLAR
      // EKRANINI ACAR. Eskiden `Permission.phone.request()` ONDAN SONRA cagriliyordu;
      // Ayarlar ekrani ustteyken (MainActivity duraklamis) Android izin diyalogunu
      // GOSTERMEZ, `onRequestPermissionsResult` HIC gelmez ve Future ASILI KALIR ->
      // READ_PHONE_STATE **ASLA** verilmez -> `TelefonDurumu.izinVar()` false ->
      // GSM dinleyicisi sessizce KAPALI. Android 14+ sideload'da her acilista tekrarlar.
      // FIX: telefon izni ONCE (henuz hicbir harici Activity acilmamisken), tam-ekran
      // bildirim ayar ekranina sicrama EN SON.
      // ⚠️ YAPMA: bu iki blogun sirasini tekrar degistirme.
      var telefonIzni = false;
      try {
        telefonIzni = await Permission.phone.isGranted;
        if (!telefonIzni) {
          telefonIzni = (await Permission.phone.request()) == PermissionStatus.granted;
        }
      } catch (_) {}

      var tamEkran = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (!tamEkran) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
        tamEkran = await FlutterCallkitIncoming.canUseFullScreenIntent();
      }
      // TANI: kilit ekrani aramasi gorunmuyorsa ilk bakilacak yer — izin durumu.
      debugPrint(
          'CALLKIT-TANI: bildirim=$bildirim tamEkran=$tamEkran telefon=$telefonIzni');
      unawaited(Sentry.captureMessage('callkit izin durumu: bildirim=$bildirim '
          'tamEkran=$tamEkran telefon=$telefonIzni'));
    } catch (e) {
      debugPrint('callkit izin: $e');
    }
  }

  void kapat() {
    _sub?.cancel();
    _sub = null;
  }
}
