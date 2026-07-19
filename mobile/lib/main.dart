import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'core/ws.dart';
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
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_fcmArkaPlan);
  } catch (_) {
    // Firebase baslatilamazsa uygulama pushsuz calisir
  }
  // iOS DAHIL: terminated CallKit reddet/bitir/cevapsiz olaylarini yakalayacak arka plan
  // handler'ini KOSULSUZ kaydet. iOS'ta aramalar FCM ile GELMEZ (VoIP push) -> _fcmArkaPlan'daki
  // kayit iOS'ta calismaz; burada kaydedince iOS reddi de arka plandan sunucuya ulasabilir
  // (arayanin sonsuza "Caliyor"da takilmasini onler).
  try {
    await FlutterCallkitIncoming.onBackgroundMessage(_callkitArkaPlan);
  } catch (_) {}

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
  }

  /// Davet push yonlendirmesi: tepsideki davet bildirimine dokunuldu.
  /// - Uygulama KAPALIYKEN acildi -> getInitialMessage
  /// - ARKA PLANDAYKEN dokunuldu -> onMessageOpenedApp
  /// Iki yol da ayni katilma akisina (davetiAc) gider; muhafizlar orada.
  Future<void> _davetPushBaslat() async {
    void ac(RemoteMessage m) {
      final tip = m.data['type'];
      if (tip != 'stream.invite' && tip != 'room.invite') return;
      final id = (tip == 'stream.invite' ? m.data['stream_id'] : m.data['room_id'])
              as String? ??
          '';
      if (id.isEmpty) return;
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

    // iOS VoIP token'i -> sunucuya (kilit ekraninda arama caldirmak icin sart)
    _voipSub = svc.onVoipToken.listen((token) async {
      try {
        await ref.read(apiProvider).post('/users/me/voip-token', data: {'token': token});
      } catch (_) {
        // giris yapilmamis olabilir; girisden sonra tekrar denenir
      }
    });

    await svc.baslat();

    // ANDROID KILIT EKRANI SART KOSULU: bildirim + "tam ekran bildirim" izni.
    // Izin ekraninda "Simdilik atla" denirse bu izinler hic istenmiyordu ->
    // gelen arama servisi basliyor (yesil mikrofon) ama EKRAN GORUNMUYORDU.
    // Her acilista idempotent iste (verilmisse tekrar sormaz).
    if (Platform.isAndroid) {
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

    Map<String, dynamic>? info;
    try {
      info = await notifier.answer(callId); // ONCE sunucuya kabul bildir
    } catch (e) {
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
      notifier.dismiss();
      return;
    }

    // FAZ-C: mantik controller'da baslar (Navigator'i beklemez — ses/sure hemen kurulur)
    final ctrl = ref.read(activeCallProvider);
    unawaited(ctrl.baslat(AramaBilgisi(
      callId: callId,
      url: info['url'] as String,
      token: info['token'] as String,
      video: c['video'] as bool? ?? false,
      peerName: c['caller_name'] as String? ?? '',
      outgoing: false,
      // GRUP: answer() cevabindan is_group/chat_title -> CallKit'ten kabul edilen grup
      // aramasi da grup moduyla acilir (yoksa 1:1 arayuz + ilk ayrilan kapatirdi).
      isGroup: info['is_group'] == true,
      chatTitle: info['chat_title'] as String? ?? '',
      elapsedMs: (info['elapsed_ms'] as num?)?.toInt(), // sure senkronu: gecen-sure baslangici
    )));

    // SONRA Navigator hazir olsun (soguk baslangicta daha uzun: 100x100ms = 10 sn)
    for (var i = 0; i < 100 && rootNavigatorKey.currentState == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    ctrl.ekraniAc(); // ekran saf gorunum — navigator gec kalsa da arama zaten yasiyor
    notifier.dismiss(); // uygulama ici gelen arama ekrani varsa kaldir (EN SON — overlay tuzagi)
  }

  @override
  void dispose() {
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
      themeMode: ThemeMode.system, // karanlik mod: sistem ayarini izler (ayarlar Faz 2)
      routerConfig: router,
      // Gelen arama ekrani her sayfanin uzerinde belirir
      builder: (context, child) =>
          IncomingCallOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
