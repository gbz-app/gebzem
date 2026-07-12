import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/theme.dart';
import 'core/ws.dart';
import 'features/calls/call_provider.dart';
import 'features/calls/incoming_call_overlay.dart';
import 'firebase_options.dart';
import 'router.dart';

// Hata telemetrisi: cokme/hata olustugunda dosya+satir+cihaz bilgisiyle Sentry'e duser
const _sentryDsn =
    'https://c31ce51f524ffca25007d386f9ffeea1@o4511719477346304.ingest.de.sentry.io/4511719502118992';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr'); // Turkce tarih bicimleri
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
