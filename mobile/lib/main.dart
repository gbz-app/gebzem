import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'core/ws.dart';
import 'features/calls/call_provider.dart';
import 'features/calls/call_screen.dart';
import 'features/calls/callkit_service.dart';
import 'features/calls/incoming_call_overlay.dart';
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
@pragma('vm:entry-point')
Future<void> _fcmArkaPlan(RemoteMessage m) async {
  final tip = m.data['type'];
  if (tip == 'call.incoming') {
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
  StreamSubscription? _voipSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callKitBaslat();
  }

  Future<void> _callKitBaslat() async {
    final svc = CallKitService.instance;

    // ON PLAN push yedegi: uygulama acikken WS bir an kopuksa (ya da online/offline
    // sinirinda) gelen arama olaylarini yine de isle. call.incoming'i BURADA ISLEME —
    // WS + CallKit onu zaten gosterir, yoksa cift ekran cikar. Sadece bitir/kabul yedegi.
    FirebaseMessaging.onMessage.listen((m) {
      final tip = m.data['type'];
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

    // Kilit ekranindan reddedildi / zaman asimi
    _redSub = svc.onRed.listen((callId) {
      final notifier = ref.read(callServiceProvider.notifier);
      // CallKit bildiriminden/kilit ekranindan kapatildi: AKTIF CallScreen'i de kapat
      // (aramaBitti -> _endedController), sonra sunucuya bildir. Yoksa sunucu biter ama
      // kendi ekranin "arama devam ediyor" diye asili kalirdi.
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
      // Arama zaten uygulama ici overlay'den kabul edildi -> ikinci ekran acma
      notifier.dismiss();
      return;
    }

    // SONRA Navigator hazir olsun (soguk baslangicta daha uzun: 100x100ms = 10 sn)
    for (var i = 0; i < 100 && rootNavigatorKey.currentState == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    notifier.dismiss(); // uygulama ici gelen arama ekrani varsa kaldir
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return; // ekran acilamadi ama arama sunucuda "kabul" durumunda

    unawaited(nav.push(MaterialPageRoute(
      builder: (_) => CallScreen(
        callId: callId,
        url: info!['url'] as String,
        token: info['token'] as String,
        video: c['video'] as bool? ?? false,
        peerName: c['caller_name'] as String? ?? '',
        outgoing: false,
      ),
    )));
  }

  @override
  void dispose() {
    _kabulSub?.cancel();
    _redSub?.cancel();
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
      // WS'i kapatinca sunucu offline gorur -> arama VoIP push/CallKit ile gelir.
      ws.close();
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
