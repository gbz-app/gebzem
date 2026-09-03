import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/storage.dart';
import 'core/tercihler.dart';
import 'core/theme.dart';
import 'core/ws.dart';
import 'features/ulasim/adres_servisi.dart';
import 'features/ulasim/ulasim_veri.dart';
import 'features/auth/acilis_ekrani.dart';
import 'features/calls/active_call_banner.dart';
import 'features/calls/active_call_controller.dart';
import 'features/calls/call_provider.dart';
import 'features/calls/callkit_service.dart';
import 'features/calls/incoming_call_overlay.dart';
import 'features/invites/davet_provider.dart';
import 'firebase_options.dart';
import 'router.dart';

// Hata telemetrisi: cokme/hata olustugunda dosya+satir+cihaz bilgisiyle Sentry'e duser
const _sentryDsn =
    'https://c31ce51f524ffca25007d386f9ffeea1@o4511719477346304.ingest.de.sentry.io/4511719502118992';

/// UYGULAMA KAPALIYKEN/ARKA PLANDAYKEN calisan TEK kod yolu (Android).
/// Sunucu "data-only" push gonderir (notification DEGIL) — yoksa bu calismaz,
/// sadece tepside sessiz bildirim gorunur ve arama ekrani hic acilmaz.
///
/// @pragma('vm:entry-point') SART: yoksa release derlemede bu fonksiyon
/// tree-shake ile SILINIR ve arka planda hicbir sey olmaz.
/// TERMINATED (uygulama tamamen kapali) Android'de CallKit "Reddet"/bitir/cevapsiz
/// olaylari UI isolate olmadigi icin DUSER (flutter_callkit_incoming bilinen sinirlama:
/// "Reddet" hicbir Activity baslatmaz -> Flutter motoru boot olmaz; "Ac" baslatir, o yuzden
/// calisir). Plugin'in KALICI ARKA PLAN isolate'ine (onBackgroundMessage) kayitli bu handler
/// o olaylari yakalayip DOGRUDAN sunucuya /calls/{id}/end POST eder -> arayan sonsuza calmaz.
/// @pragma vm:entry-point SART (release tree-shake). Riverpod YOK; taze Dio + AppStorage.
@pragma('vm:entry-point')
Future<void> _callkitArkaPlan(CallEvent e) async {
  WidgetsFlutterBinding.ensureInitialized();
  final id = switch (e) {
    CallEventActionCallDecline(:final callKitParams) => callKitParams.id,
    CallEventActionCallEnded(:final callKitParams) => callKitParams.id,
    CallEventActionCallTimeout(:final id) => id,
    _ => '',
  };
  if (id.isEmpty) return;
  final token = await AppStorage().token;
  if (token == null || token.isEmpty) return;
  try {
    final dio = Dio(BaseOptions(
      baseUrl: apiUrl,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    await dio.post('/calls/$id/end');
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> _fcmArkaPlan(RemoteMessage m) async {
  final tip = m.data['type'];
  if (tip == 'call.incoming') {
    // Terminated'da CallKit reddet/bitir/cevapsiz olaylarini yakalayacak arka plan
    // handler'ini goster'DEN ONCE kaydet (zil calarken executor motoru isinsin).
    await FlutterCallkitIncoming.onBackgroundMessage(_callkitArkaPlan);
    await CallKitService.goster(
      callId: m.data['call_id'] ?? '',
      callerName: m.data['caller_name'] ?? 'Bilinmeyen',
      video: (m.data['call_type'] ?? 'audio') == 'video',
      avatar: m.data['caller_avatar'] ?? '',
      // TEST TURU 35: grup bayragi FCM yukunde geliyor ama tasinmiyordu -> Android kilitli/
      // arka planda gelen GRUP aramasinda "Katil" ekrani cizilemiyordu.
      isGroup: (m.data['is_group'] ?? '') == 'true' || m.data['is_group'] == true,
      chatTitle: m.data['chat_title'] ?? '',
      // TEST TURU 55: `waiting` FCM yukunde ZATEN geliyor (handler.go:428) ama
      // tasinmiyordu -> Android arka planda gelen IKINCI arama "Beklet ve Kabul"
      // yerine duz Kabul/Reddet olarak ciziliyordu. ⚠️ YAPMA: bu alani dusurme.
      waiting: (m.data['waiting'] ?? '') == 'true' || m.data['waiting'] == true,
    );
  } else if (tip == 'call.cancel' || tip == 'call.ended') {
    // Arayan vazgecti / baska yerde cevaplandi / arama bitti -> ekran asili kalmasin
    await CallKitService.bitir(m.data['call_id'] ?? '');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uygulama her zaman DIK (portrait) — arama ekrani dahil (kullanici istegi, WhatsApp gibi)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('tr'); // Turkce tarih bicimleri

  // TAZE KURULUM TEMIZLIGI (kritik): iOS'ta uygulama SILINIP yeniden kurulunca
  // Keychain'deki eski token KALIR (iOS onu silmez) -> yeni surum o bayat token'la
  // "belirsiz/bos hesaba" giriyordu. SharedPreferences ise silinir; oradaki bayrak
  // yoksa = taze kurulum -> guvenli depoyu temizle, sifirdan basla.
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('kurulum_tamam') != true) {
      await AppStorage().clear();
      await prefs.setBool('kurulum_tamam', true);
    }
  } catch (_) {}

  // ⚠️⚠️ TURU 81 — TERCIHLER (tema + onboarding) `runApp`tan ONCE yuklenir.
  //    Sonra yuklenseydi ilk kare varsayilan temayla cizilir ve tercih gelince
  //    ekran ANIDEN degisirdi ("tema atlamasi"); onboarding de bir an icin
  //    yanlis ekrani gosterebilirdi.
  // ⚠️ ISTISNA FIRLATMAZ: depo acilamazsa varsayilanlarla devam edilir
  //    (tema tercihi ugruna acilista cokmek kabul edilemez).
  await tercihleriYukle();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_fcmArkaPlan);
  } catch (_) {
    // Firebase baslatilamazsa uygulama pushsuz calisir
  }
  // ⚠️⚠️ TURU 69b — TESHIS DUZELTMESI (denetim): `onBackgroundMessage` eklentinin
  // YALNIZ ANDROID tarafinda uygulanmis; iOS'ta `MissingPluginException` firlatiyor ve
  // asagidaki `catch (_)` onu YUTUYOR. Yani `_callkitArkaPlan` iPHONE'DA HIC CALISMIYOR.
  // Eski yorum ("iOS DAHIL ... iOS reddi de arka plandan sunucuya ulasabilir") YANLISTI
  // ve turu 69'un ilk kok-neden aciklamasi da buna dayaniyordu — DUZELTILDI.
  // ⚠️ YAPMA: bu kaydi iOS'ta bekleyip `await` ile akisi geciktirme; Android'de kaldirma
  //     (terminated Android'de CallKit reddi/bitisi YALNIZ bu yoldan sunucuya ulasir).
  if (Platform.isAndroid) {
    try {
      await FlutterCallkitIncoming.onBackgroundMessage(_callkitArkaPlan);
    } catch (_) {}
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = 'prototype';
      options.tracesSampleRate = 0.2; // performans izleme (istek sureleri)
      options.sendDefaultPii = false; // kullanici verisi gonderme
    },
    appRunner: () => runApp(const ProviderScope(child: GebzemApp())),
  );
}

class GebzemApp extends ConsumerStatefulWidget {
  const GebzemApp({super.key});

  @override
  ConsumerState<GebzemApp> createState() => _GebzemAppState();
}

class _GebzemAppState extends ConsumerState<GebzemApp> with WidgetsBindingObserver {
  StreamSubscription? _kabulSub;
  StreamSubscription? _redSub;
  StreamSubscription? _holdSub; // test turu 18: CallKit beklet
  StreamSubscription? _timeoutSub;
  StreamSubscription? _voipSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callKitBaslat();
    // DAVET SERVISI (Bolum 5 I4): WS stream.invite/room.invite dinleyicisini ayaga kaldir
    // (provider tembel — okunmazsa hic olusmaz, banner gelmez).
    ref.read(davetServisiProvider);
    _davetPushBaslat();
    // ⚠️⚠️ TURU 152 — ADRES SERVISINE `Ref` BAGLANIR.
    //	`AdresServisi` bir singleton (`ConsumerState` degil) ve
    //	`apiProvider`a baska turlu ulasamiyor. BAGLANMAZSA sunucu
    //	(Google Places) dali SESSIZCE atlanir ve arama cihaz
    //	geocoder'ina duser — yani ozellik "calisiyor gibi"
    //	gorunup KOTU sonuc verirdi. Bu projede "servis yazildi ama
    //	CAGIRAN yol yazilmadi" sinifi DOKUZ kez sahaya cikti.
    AdresServisi.i.baglaApi(() => ref.read(apiProvider));
    // ⚠️⚠️⚠️ TURU 160 — **GUZERGAH SEKLINI YOLA OTURTAN BAG.**
    //	`UlasimVeri` saf veri katmani; `AdresServisi`i IMPORT ETMEZ
    //	(Dio + Riverpod bagimliligi girer). Bag BURADA kurulur.
    // ⚠️ BU SATIR UNUTULURSA ozellik SESSIZCE atlanir ve ham (kaba)
    //    sekil cizilir — yani kullanicinin sikayet ettigi "kaldirimin
    //    ustunden gecen cizgi" AYNEN kalir. Ustteki `baglaApi` serhi
    //    ayni sinifi anlatiyor: bu projede "servis yazildi ama CAGIRAN
    //    yol yazilmadi" DOKUZ kez sahaya cikti.
    UlasimVeri.i.baglaSekilOturtucu(AdresServisi.i.sekliOturt);
  }

  /// Davet push yonlendirmesi: tepsideki davet bildirimine dokunuldu.
  /// - Uygulama KAPALIYKEN acildi -> getInitialMessage
  /// - ARKA PLANDAYKEN dokunuldu -> onMessageOpenedApp
  /// Iki yol da ayni katilma akisina (davetiAc) gider; muhafizlar orada.
  Future<void> _davetPushBaslat() async {
    Future<void> ac(RemoteMessage m) async {
      final tip = m.data['type'];
      if (tip != 'stream.invite' && tip != 'room.invite') return;
      final id = (tip == 'stream.invite' ? m.data['stream_id'] : m.data['room_id'])
              as String? ??
          '';
      if (id.isEmpty) return;
      // TARAMA #10: oturum yoksa (cikis yapilmis/taze kurulum) davet acilmaz —
      // yoksa login ekrani ustunde anlamsiz 401 snackbar'i cikiyordu.
      final token = await AppStorage().token;
      if (token == null || token.isEmpty) return;
      unawaited(ref.read(davetServisiProvider).davetiAc(
            tip: tip == 'stream.invite' ? 'yayin' : 'oda',
            id: id,
            baslik: m.data['title'] as String? ?? '',
          ));
    }

    FirebaseMessaging.onMessageOpenedApp.listen(ac);
    try {
      final ilk = await FirebaseMessaging.instance.getInitialMessage();
      if (ilk == null) return;
      // Soguk baslangic: Navigator hazir olana kadar bekle (CallKit kabul deseni)
      for (var i = 0; i < 100 && rootNavigatorKey.currentState == null; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (mounted) ac(ilk);
    } catch (_) {}
  }

  Future<void> _callKitBaslat() async {
    final svc = CallKitService.instance;

    // ON PLAN push yedegi: uygulama acikken WS bir an kopuksa (ya da online/offline
    // sinirinda) gelen arama olaylarini yine de isle. call.incoming'i BURADA ISLEME —
    // WS + CallKit onu zaten gosterir, yoksa cift ekran cikar. Sadece bitir/kabul yedegi.
    FirebaseMessaging.onMessage.listen((m) {
      final tip = m.data['type'];
      // DAVET (on planda push geldi; WS kopuk olabilir) -> ayni banner.
      // call_id kontrolunden ONCE: davet push'unda call_id yok, asagidaki erken
      // donus daveti yutardi (Bolum 5 I4 karari).
      if (tip == 'stream.invite' || tip == 'room.invite') {
        ref.read(davetServisiProvider).pushtanGoster(m.data);
        return;
      }
      final callId = m.data['call_id'] as String? ?? '';
      if (callId.isEmpty) return;
      final notifier = ref.read(callServiceProvider.notifier);
      if (tip == 'call.cancel' || tip == 'call.ended') {
        notifier.aramaBitti(callId); // aktif/gelen arama ekranini kapat
      } else if (tip == 'call.answered') {
        notifier.aramaKabulPush(callId); // arayan: karsi taraf kabul etti (WS yedegi)
      }
    });

    // Kilit ekranindan "Kabul et"e basildi (uygulama kapali bile olabilir)
    _kabulSub = svc.onKabul.listen(_callKitKabul);

    // KULLANICI KASTEN reddetti/bitirdi (CallKit Decline/Ended — kilit ekrani/sistem arama
    // seridi dahil). Aktif konusmada bile aramayi bitir: kullanici gercekten kapatmak istiyor,
    // sistem CallKit "bitir" tusu CALISMALI. (Spurious 45sn auto-expire AYRI kanaldan gelir.)
    _redSub = svc.onRed.listen((callId) {
      // TURU 69b OLCUMU: iki kapatma yolundan (eklenti olayi / native `onEnd` kancasi)
      // hangisi ONCE geliyor? Zaman farki, "ekran neden gec kapaniyordu" sorusunu
      // bir sonraki turda TAHMINLE degil KANITLA cevaplayacak.
      // ⚠️ YAPMA: her olayda gondermeye cevirme (yalniz gercek kapanislarda tetiklenir).
      unawaited(Sentry.captureMessage('callkit bitir: kaynak=eklenti'));
      final notifier = ref.read(callServiceProvider.notifier);
      notifier.aramaBitti(callId);
      notifier.end(callId);
    });

    // 45sn CallKit AUTO-EXPIRE: KABUL EDILIP odaya baglanmis (canli) aramada SPURIOUS'tur —
    // arama suruyor, CallKit'in zaman asimi yaniltir -> aramayi OLDURME (tek-bitir-kapisi).
    // Ringing fazinda (kabul edilmemis) ise gercek cevapsizdir -> bitir. Boylece canli aramayi
    // yalniz kirmizi tus / peer-hangup / kullanici-kasten-CallKit-bitir kapatir; 45sn otomatik
    // zaman asimi konusma ortasinda aramayi 1sn'de OLDURMEZ (regresyonun kaynagi buydu).
    _timeoutSub = svc.onTimeout.listen((callId) {
      final notifier = ref.read(callServiceProvider.notifier);
      if (notifier.aktifKonusmalar.contains(callId)) return;
      notifier.aramaBitti(callId);
      notifier.end(callId);
    });

    // TEST TURU 18 — ARAMA BEKLETME: iOS CallKit "Beklet" (GSM aramasi / "Beklet ve Kabul").
    // Medya durur, oda ACIK kalir; geri alinca ses birimi tazelenir (Apple'in bilinen
    // "hold sonrasi ses gelmiyor" tuzagi). Android'de bu olay gelmez (kendi katmanimiz var).
    _holdSub = svc.onHold.listen((m) {
      final id = m['call_id'] as String? ?? '';
      if (id.isEmpty) return;
      unawaited(ref.read(activeCallProvider).beklemeyeAl(id, m['on'] == true));
    });

    // ⚠️⚠️ TURU 67 — `call.held` ABONELIGI KALDIRILDI (kullanici emri: "bekleme olayi
    // ile ilgili NE VARSA KALDIR").
    // Turu 66'da GONDERME kapatilmisti ama ALMA acik kalmisti: karsi taraf ESKI
    // surumdeyse hold POST'u atabiliyor, bizde turuncu "Karsi taraf beklemeye aldi"
    // seridi cikiyor ve `held_by` NULL'a donmezse arama boyunca YAPISIYORDU —
    // kullanicinin yapamayacagi bir sey icin kalici uyari.
    // ⚠️ YAPMA: `_holdSub`u (yukarida) SILME — o KENDI cihazimizdaki kacak CallKit
    //     hold olayina karsi tek emniyet ve artik aramayi BITIRIYOR.

    // iOS VoIP token'i -> sunucuya (kilit ekraninda arama caldirmak icin SART).
    // TEST TURU 33 (kullanici: "iPhone KILITLIYKEN ekran gelmiyor"): eskiden TEK deneme
    // yapilip hata SESSIZCE yutuluyordu. Oturum henuz acilmamissa (401) ya da ag anlik
    // koptuysa token sunucuya HIC ulasmiyor ve voip_tokens satiri olusmuyordu -> kilitli
    // telefon calmiyordu (uygulama acikken WS yolu calistigi icin sorun gorunmuyordu).
    // Artik artan araliklarla 5 kez denenir. ⚠️ YAPMA: tek denemeye geri donme.
    _voipSub = svc.onVoipToken.listen((token) async {
      for (var i = 0; i < 5; i++) {
        // TEST TURU 35: OTURUM YOKKEN GONDERME. Eskiden oturumsuz POST 401 doner, Dio
        // interceptor'i TUM OTURUMU silip router'i sifirlardi -> kullanici KAYIT ekranindan
        // login'e firlar, izin diyaloglari duserdi. Oturum acilinca auth_provider zaten
        // `voipTokeniYenidenGonder()` cagirir. ⚠️ YAPMA: bu kapiyi kaldirma.
        final oturum = await ref.read(storageProvider).token;
        if (oturum == null || oturum.isEmpty) {
          await Future.delayed(Duration(seconds: 3 * (i + 1)));
          continue;
        }
        try {
          await ref
              .read(apiProvider)
              .post('/users/me/voip-token', data: {'token': token});
          debugPrint('voip token sunucuya kaydedildi');
          return;
        } catch (_) {
          await Future.delayed(Duration(seconds: 3 * (i + 1)));
        }
      }
      debugPrint('voip token KAYDEDILEMEDI (kilit ekraninda arama calmayabilir)');
    });

    await svc.baslat();

    // ANDROID KILIT EKRANI SART KOSULU: bildirim + "tam ekran bildirim" izni.
    // Izin ekraninda "Simdilik atla" denirse bu izinler hic istenmiyordu ->
    // gelen arama servisi basliyor (yesil mikrofon) ama EKRAN GORUNMUYORDU.
    // Her acilista idempotent iste (verilmisse tekrar sormaz).
    //
    // ⚠️⚠️⚠️ TURU 89 — `onboardingGoruldu` KAPISI **ZORUNLU** (SEVK ENGELI).
    //
    //	Turu 89'da izinler onboarding sayfalarina tasindi. Bu cagri KAPISIZ
    //	kalsaydi IKI IZIN AKISI PARALEL kosardi ve `callkit_service.dart`
    //	serhinde belgeli zincir islerdi: Android ayni anda TEK izin kumesi
    //	kabul eder, ikinci istegi **SENKRON BOS SONUCLA** duserur ->
    //	READ_PHONE_STATE sessizce `denied` -> `TelefonDurumu.izinVar()` false
    //	-> **GSM dinleyicisi KAPALI** -> turu 56/63'te kapatilan GIZLILIK
    //	acigi (GSM gorusmesi surerken Gebzem mikrofonunun acik kalmasi)
    //	GERI GELIR. Turu 87'de tam bu carpisma yasandi ve duzeltildi.
    //
    // ⚠️ Kapi onboardingi BITIRENLERI korumaya devam eder: onlar icin bu
    //    cagri hala her acilista idempotent kosar (izin verilmisse sormaz).
    // ⚠️ YAPMA: bu kapiyi kaldirma; onboarding surerken izin isteme.
    if (Platform.isAndroid && tercihler.onboardingGoruldu) {
      await CallKitService.izinleriIste();
    }
  }

  /// CallKit'ten kabul edilen aramayi ac. Uygulama SIFIRDAN acilmis olabilir.
  /// ONEMLI SIRA: ONCE answer (sunucuya "kabul edildi" der, arayan calmayi keser),
  /// SONRA Navigator'i bekle. Eski kod once Navigator'i 6 sn bekliyordu; gelmezse
  /// sessizce cikip answer'i HIC cagirmiyordu -> arama "missed", arayan calmaya devam.
  Future<void> _callKitKabul(Map<String, dynamic> c) async {
    final callId = c['call_id'] as String? ?? '';
    if (callId.isEmpty) return;

    final notifier = ref.read(callServiceProvider.notifier);

    // TEST TURU 35 — GRUP ARAMASINDA "KATIL" EKRANI (kullanici: "grup aramasinda katil
    // seyi yok, direk aciliyor, onu geri getir").
    // Grup davet ekrani YALNIZ "Android + uygulama ON PLANDA + WS call.incoming" yolunda
    // cizilebiliyordu; iOS'ta WS call.incoming kosulsuz atlanir (cift-UI tuzagi) ve Android
    // kilitli/arka planda FCM -> CallKit yolundan gelir. Ikisinde de kabul DOGRUDAN aramayi
    // aciyordu. Artik GRUP ise arama HENUZ cevaplanmaz: davet ekrani acilir, kullanici
    // kamerasini/mikrofonunu ayarlayip "Katil" der; "Yok say" ise arama reddedilir.
    // ⚠️ YAPMA: bu dali 1:1 aramaya acma (kullanici CallKit'te zaten kabul etti, ikinci
    // onay istemek yanlis olur) ve `hazirlaVeAc` hizli-acilis yolunu 1:1'de bozma.
    final grupMu = c['is_group'] == true;
    if (grupMu && !notifier.aktifAramaVar) {
      final ctrlG = ref.read(activeCallProvider);
      if (ctrlG.arama == null) {
        for (var i = 0; i < 60 && rootNavigatorKey.currentState == null; i++) {
          await Future.delayed(const Duration(milliseconds: 16));
        }
        notifier.grupDavetiGoster(IncomingCall(
          callId: callId,
          callerName: c['caller_name'] as String? ?? 'Bilinmeyen',
          callerAvatar: '',
          video: c['video'] as bool? ?? false,
          isGroup: true,
          chatTitle: c['chat_title'] as String? ?? '',
        ));
        return; // answer YOK — kullanici "Katil" deyince _accept calisir
      }
    }

    // FAZ-1C HIZ: izinleri answer REST'iyle PARALEL iste (1B ile ayni desen)
    final izinF = [
      Permission.microphone,
      if (c['video'] as bool? ?? false) Permission.camera,
    ].request();

    // TEST TURU 18 — ARAMA BEKLETME (iOS/CallKit): kullanici zaten bir ARAMADAYKEN
    // CallKit'ten yeni aramayi kabul ettiyse (iOS'ta "Hold & Accept" / "End & Accept"
    // ekranini sistem cizer, secim bize AYNI 'accept' olarak gelir) mevcut aramayi
    // BEKLEMEYE AL ve yeni aramaya gec. Eskiden bu durumda arama "mesgul" sayilip
    // KAPATILIYORDU. Oda/canli yayin ekranlarinda eski davranis (mesgul) korunur.
    final ctrlOn = ref.read(activeCallProvider);
    final bekletildi = ctrlOn.arama != null &&
        ctrlOn.arama!.callId != callId &&
        notifier.aktifAramaVar;
    if (bekletildi) {
      // ⚠️⚠️ TURU 66 — BEKLETME KAPALI: onceki arama PARK EDILMEZ, BITIRILIR.
      // iOS "Bitir ve Kabul" ekranini kendisi cizdigi icin kullanicinin beklentisi
      // zaten budur. ⚠️ YAPMA: `bekletmeAcik` kontrolunu atlayip `parkEt()` cagirma.
      if (ActiveCallController.bekletmeAcik) {
        await ctrlOn.parkEt();
        rootMessengerKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Önceki arama beklemeye alındı'),
            duration: Duration(seconds: 2)));
      } else {
        await ctrlOn.leave(notifyServer: true);
        rootMessengerKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Önceki arama sonlandırıldı'),
            duration: Duration(seconds: 2)));
      }
    }

    // TEST TURU 30 (kullanici: "karsi taraf goruntuyu actiginda ilk once uygulamaya gidip
    // tekrar goruntulu konusmaya geliyor"): ekrani ANINDA ac. Eskiden once answer REST +
    // izin + Navigator beklemesi bitiyordu; o sirada ekranda SON SAYFA (sohbet listesi)
    // duruyordu. Artik "Baglaniliyor..." arama ekrani hemen gorunur, gercek `baslat`
    // hemen ardindan gelir. ⚠️ YAPMA: bu cagriyi answer'in ARKASINA tasima.
    // ⚠️ TURU 66: `bekletildi` sarti KALDIRILDI. Onceki arama artik PARK EDILMIYOR,
    // BITIRILIYOR — yani "geri donulecek bir arama" yok ve hizli ekran acma kisayolu
    // bu yolda da GEREKLI. Eskiden atlaniyordu ve kullanici answer REST'i boyunca
    // sohbet listesinde bekliyordu.
    {
      // Navigator hazir degilse (soguk baslangic) kisa bekle — ama en fazla ~1sn.
      for (var i = 0; i < 60 && rootNavigatorKey.currentState == null; i++) {
        await Future.delayed(const Duration(milliseconds: 16));
      }
      ref.read(activeCallProvider).hazirlaVeAc(AramaBilgisi(
            callId: callId,
            url: '',
            token: '',
            video: c['video'] as bool? ?? false,
            peerName: c['caller_name'] as String? ?? '',
            outgoing: false,
          ));
    }

    Map<String, dynamic>? info;
    try {
      info = await notifier.answer(callId, zorla: bekletildi); // ONCE sunucuya kabul bildir
    } catch (e) {
      ref.read(activeCallProvider).hazirligiBirak();
      unawaited(izinF.catchError((_) => <Permission, PermissionStatus>{}));
      await CallKitService.bitir(callId);
      rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      return;
    }
    if (info == null) {
      // IKI DURUM (dogrulama bulgusu): (a) ayni arama baska yoldan zaten kabul edildi ->
      // ikinci ekran acma, dokunma; (b) ODADAYKEN/aramadayken CallKit'ten kabul -> mesgul:
      // CallKit UI'sini KAPAT (yoksa iOS'ta hayalet arama kalir; kapanisinda
      // didDeactivateAudioSession odanin sesini oldurur) + sunucuya reddet (arayan
      // 45 sn bosuna calmasin, "reddedildi" gorsun).
      if (notifier.baskaIsleMesgul(callId)) {
        unawaited(CallKitService.bitir(callId));
        unawaited(notifier.end(callId));
      }
      unawaited(izinF.catchError((_) => <Permission, PermissionStatus>{}));
      ref.read(activeCallProvider).hazirligiBirak(); // turu 30: acilan gorunumu kapat
      notifier.dismiss();
      return;
    }
    // Android es-zamanli ikinci request firlatir -> baslat oncesi bitmis olsun (FAZ-1C)
    await izinF;

    // TEST TURU 53 — KOK NEDEN (sunucu kaniti 31 Tem): aranan tarafta GORUNTULU arama
    // SESLI gibi baslıyordu. LiveKit logu: 3 aramada (hepsi `type=video`, DB teyitli)
    // aranan iPhone YALNIZ ses yayinladi, video HIC gelmedi ve Sentry'de tek bir iz bile
    // yoktu — cunku `_camOn=false` olunca kamera blogu KOMPLE atlanir (dogrulama dahil).
    // SEBEP: buradaki `video` bayragi CALLKIT YUKUNDEN (`c['video']`) okunuyordu; o yuk
    // `_ayikla` -> `(p.type ?? 0) == 1 || extra['call_type'] == 'video'` zincirine bagli
    // ve CallKit kabul olayinda `type`/`extra` her zaman tam donmuyor (ayni sinif hata
    // turu 34-36'da `is_group` icin yasandi: "CallKit yukunde UC yerde dusuruluyordu").
    // COZUM: SUNUCU OTORITER. `answer()` yaniti ZATEN `"type": callType` donduruyor
    // (backend handler.go:896) — artik ONCE o okunur, CallKit yuku yalnizca YEDEK.
    // ⚠️ YAPMA: bunu tekrar yalniz `c['video']`ya baglama.
    final sunucuTipi = info['type'] as String?;
    final gorusmeVideo = sunucuTipi != null
        ? sunucuTipi == 'video'
        : (c['video'] as bool? ?? false);
    // OLCUM: iki kaynak CELISIYORSA bunu GOR (sessiz kalmasin). Tek satir, dusuk gurultu.
    if (sunucuTipi != null && (sunucuTipi == 'video') != (c['video'] as bool? ?? false)) {
      unawaited(Sentry.captureMessage(
          'arama tipi CELISKI: sunucu=$sunucuTipi callkit=${c['video']}'));
    }

    // FAZ-C: mantik controller'da baslar (Navigator'i beklemez — ses/sure hemen kurulur)
    final ctrl = ref.read(activeCallProvider);
    unawaited(ctrl.baslat(AramaBilgisi(
      callId: callId,
      url: info['url'] as String,
      token: info['token'] as String,
      video: gorusmeVideo,
      peerName: c['caller_name'] as String? ?? '',
      // ⚠️ TURU 76 — AVATAR ICIN KIMLIK. Bu yolda (CallKit kabulu) elimizde
      //    yalnizca CallKit ek alanlari var ve orada kimlik GUVENILIR DEGIL;
      //    `answer` yanitindaki `peer_id` OTORITER kaynak. Yoksa CallKit
      //    ek alanina duseriz.
      peerId: (info['peer_id'] as String?)?.isNotEmpty == true
          ? info['peer_id'] as String
          : (c['caller_id'] as String?),
      outgoing: false,
      // GRUP: answer() cevabindan is_group/chat_title -> CallKit'ten kabul edilen grup
      // aramasi da grup moduyla acilir (yoksa 1:1 arayuz + ilk ayrilan kapatirdi).
      isGroup: info['is_group'] == true,
      chatTitle: info['chat_title'] as String? ?? '',
      elapsedMs: (info['elapsed_ms'] as num?)?.toInt(), // sure senkronu: gecen-sure baslangici
    )));

    // SONRA Navigator hazir olsun (soguk baslangic). TEST TURU 30: adim 100ms -> 16ms
    // (kare suresi); ekran cogu zaman YUKARIDA zaten acilmis olur, bu dongu yalniz
    // soguk baslangic/hazirlik atlanan durumlar icin yedektir. Toplam sinir yine ~10sn.
    for (var i = 0; i < 600 && rootNavigatorKey.currentState == null; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    ctrl.ekraniAc(); // ekran saf gorunum — navigator gec kalsa da arama zaten yasiyor
    notifier.dismiss(); // uygulama ici gelen arama ekrani varsa kaldir (EN SON — overlay tuzagi)
  }

  @override
  void dispose() {
    _holdSub?.cancel();
    _kabulSub?.cancel();
    _redSub?.cancel();
    _timeoutSub?.cancel();
    _voipSub?.cancel();
    CallKitService.instance.kapat();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ws = ref.read(wsProvider);
    if (state == AppLifecycleState.resumed) {
      // On plana donunce: WS'i yeniden bagla + calan arama varsa goster
      ws.connect();
      ref.read(callServiceProvider.notifier).checkActive();
    } else if (state == AppLifecycleState.paused) {
      // Arka plana/kilit ekranina gecince WS'i KAPAT. Sebep: iOS askiya alininca
      // TCP soketi sunucuda "yari-acik" kalip Online()=true yaniltiyor -> gelen arama
      // sadece WS'e gonderiliyor (uygulama isleyemez) -> kilit ekraninda CALMIYOR.
      // goOffline(): once 'bg' cercevesi gonderir (sunucu ANINDA offline dusurur, FIN
      // flush'ini beklemez), sonra kapatir -> arama VoIP push/CallKit ile ANINDA gelir.
      ws.goOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Gebzem',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey, // gelen arama ekrani icin (Navigator disinda)
      theme: lightTheme,
      darkTheme: darkTheme,
      // ⚠️⚠️ TURU 81 — TEMA ARTIK AYARLARDAN SECILIYOR (kullanici emri:
      //    "dark ve beyaz 2 tema olsun, ayarlardan beyaz temayi da secelim").
      //    Onceki surumde bu satir `ThemeMode.system` idi ama FIILEN NO-OP'tu:
      //    `lightTheme` ve `darkTheme` DEGISKENLERININ IKISI DE ayni `_koyu()`
      //    fonksiyonunu cagiriyordu, yani acik tema HIC TANIMLI DEGILDI.
      themeMode: ref.watch(temaProvider),
      // ⚠️⚠️⚠️ TURU 80 — YERELLESTIRME (denetimde bulunan MEVCUT hata).
      //
      //    Bu uc satir OLMADAN Material'in TAKVIM ve SAAT secicileri
      //    **INGILIZCE** aciliyordu: "August", "Mon", "AM/PM".
      //    Sahada kullanan iki ekran VAR ve ikisi de TURKCE bir uygulamanin
      //    ortasinda Ingilizce takvim aciyordu:
      //      · `etkinlik_ekranlari.dart` (etkinlik tarihi/saati)
      //      · `isletme_duzenle.dart`    (calisma saatleri)
      //
      // ⚠️ `locale` SABITLENDI ('tr'): uygulama TURKIYE pazarina ozel ve TUM
      //    metinleri Turkce. Cihaz dili Ingilizce olan bir kullanicida
      //    takvimin Ingilizce, arayuzun Turkce olmasi TUTARSIZ olurdu.
      // ⚠️ YAPMA: bu blogu kaldirma; `supportedLocales`i bosaltma.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Gelen arama ekrani her sayfanin uzerinde; minimize arama banti onun ALTINDA
      // (sarmalama sirasi degismesin — gelen-arama tam ekrani bantin ustunde kalir)
      // ⚠️⚠️⚠️ TURU 85c — UYGULAMA GENELI DURUM CUBUGU VARSAYILANI (denetim).
      //
      //	Onboarding ve adimli kayit ekranlari zemini SABIT BEYAZ yaptigi
      //	icin kendi `AnnotatedRegion`lariyla durum cubugu ikonlarini KOYU
      //	yapiyor. Ama `AnnotatedRegion` **cikista otomatik geri ALINMIYOR**:
      //	`SystemChrome` en son uygulanan stili KORUR. Kayit bitip koyu
      //	temali ana ekrana gecildiginde saat/pil/sinyal KOYU kaliyor ve
      //	koyu zeminde **GORUNMEZ** oluyordu (kullanicinin turu 83'te
      //	sikayet ettigi sinifin kardesi).
      //
      // ⚠️ Cozum EKRAN ICINDE DEGIL BURADA: `AnnotatedRegion` katman
      //    agacinda **EN YAKIN (yaprak)** olani kazanir, yani beyaz ekranlarin
      //    kendi sarmalari BUNU EZMEYE DEVAM EDER; onlardan cikilinca ise
      //    uygulama otomatik olarak DOGRU varsayilana doner.
      // ⚠️ YAPMA: her ekrana tek tek "geri al" kodu yazma (iki kopya drift
      //    eder ve yeni eklenen ekran mutlaka unutulur).
      // ⚠️ Olcut TEMA: acik temada koyu ikon, koyu temada acik ikon.
      builder: (context, child) {
        final koyu = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: koyu ? Brightness.light : Brightness.dark,
            statusBarBrightness: koyu ? Brightness.dark : Brightness.light,
          ),
          // ⚠️⚠️⚠️ TURU 90 — BOSLUGA DOKUNUNCA ODAK BIRAKILIR (kullanici emri).
          //
          //	*"bir inputa tikladigimda YUKARIDA BIR YERE TIKLADIGIMDA
          //	 INPUTTAN CIKMIYOR; mesaj, telefon, HERHANGI BIR SEYDE boyle"*.
          //
          //	Flutter'in VARSAYILAN davranisi budur: `TextField` disina
          //	dokunmak klavyeyi KAPATMAZ. Uygulamada bunu yapan global bir
          //	mekanizma YOKTU — `grep unfocus` yalnizca IKI ekranda elle
          //	yazilmis cagri buluyordu (`isletme_duzenle`, `kesfet_ekrani`).
          //	Yani sorun tek bir ekranda degil, HER ekranda vardi.
          //
          // ⚠️⚠️ `HitTestBehavior.translucent` **ZORUNLU**, `opaque` DEGIL:
          //    `opaque` altindaki her seye dokunusu ENGELLER ve uygulama
          //    KULLANILAMAZ hale gelir. `translucent` ile dokunus hem buraya
          //    hem alttaki bilesenlere ULASIR.
          // ⚠️ Jest arenasi: bir dugme/ListTile kendi `TapGestureRecognizer`i
          //    ile ARENAYI KAZANIR ve buradaki `onTap` CALISMAZ — yani dugme
          //    tiklamalari BOZULMAZ. Yalnizca BOS ALANA dokunus buraya duser.
          // ⚠️ Video oynatici, harita (`EagerGestureRecognizer`) ve kaydirma
          //    jestleri de kendi tanicilariyla kazanir; `onTap` yalniz
          //    HAREKETSIZ dokunusta atesler, kaydirmayi ETKILEMEZ.
          // ⚠️ YAPMA: `behavior`i `opaque` yapma; bu sarmali `Navigator`in
          //    ICINE tasima (o zaman tam ekran route'larda calismaz).
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            // ⚠️ TURU 90b — **OLCULDU**: sarmal olmadan kok semantik dugumde
            //    `tap` eylemi YOK, sarmalla VAR. Yani TalkBack/VoiceOver TUM
            //    EKRANI "etkinlestirilebilir" duyurabiliyordu. Bu sarmal bir
            //    DUGME DEGIL, yalnizca odak birakan bir dinleyicidir.
            excludeFromSemantics: true,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            // ⚠️⚠️ TURU 119 — ACILIS KATMANI **EN DISTA** (gelen arama
            //	katmaninin da USTUNDE). Gerekce: acilisin ilk 1 saniyesinde
            //	gelen bir arama ekranini yarim gostermek yerine, marka
            //	ekrani solduktan SONRA tam haliyle gostermek daha dogru.
            //	Katman zaten `IgnorePointer` (dokunuslari yutmaz) ve solunca
            //	agactan cikar.
            child: AcilisKatmani(
              child: IncomingCallOverlay(
                child: AktifAramaBanner(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
