import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/api.dart';
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
  } else if (tip == 'call.cancel') {
    // Arayan vazgecti / baska yerde cevaplandi -> ekran asili kalmasin
    await CallKitService.bitir(m.data['call_id'] ?? '');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr'); // Turkce tarih bicimleri
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

    // Kilit ekranindan "Kabul et"e basildi (uygulama kapali bile olabilir)
    _kabulSub = svc.onKabul.listen(_callKitKabul);

    // Kilit ekranindan reddedildi / zaman asimi
    _redSub = svc.onRed.listen((callId) {
      ref.read(callServiceProvider.notifier).end(callId);
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
  }

  /// CallKit'ten kabul edilen aramayi ac. Uygulama SIFIRDAN acilmis olabilir —
  /// Navigator hazir olana kadar (en fazla ~6 sn) bekle.
  Future<void> _callKitKabul(Map<String, dynamic> c) async {
    final callId = c['call_id'] as String? ?? '';
    if (callId.isEmpty) return;

    for (var i = 0; i < 60 && rootNavigatorKey.currentState == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    final notifier = ref.read(callServiceProvider.notifier);
    try {
      final info = await notifier.answer(callId);
      notifier.dismiss(); // uygulama ici gelen arama ekrani varsa kaldir
      unawaited(nav.push(MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          url: info['url'] as String,
          token: info['token'] as String,
          video: c['video'] as bool? ?? false,
          peerName: c['caller_name'] as String? ?? '',
          outgoing: false,
        ),
      )));
    } catch (e) {
      await CallKitService.bitir(callId);
      rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
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

  /// Uygulama on plana donunce: WebSocket'i HEMEN yeniden bagla ve calan arama
  /// varsa goster (bildirime dokunup acan kullanici aramayi kacirmasin).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(wsProvider).resume();
      ref.read(callServiceProvider.notifier).checkActive();
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
