import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/theme.dart';
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

class GebzemApp extends ConsumerWidget {
  const GebzemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Gebzem',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // karanlik mod: sistem ayarini izler (ayarlar Faz 2)
      routerConfig: router,
    );
  }
}
