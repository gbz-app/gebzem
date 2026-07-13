import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_dio/sentry_dio.dart';

import '../features/auth/auth_provider.dart';
import 'storage.dart';

/// API adresi:
/// - Android emulatoru: 10.0.2.2 bilgisayarin localhost'una gider
/// - Gercek cihaz/uretim: --dart-define=API_URL=https://api.gebzem.app ile degistir
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

/// WebSocket adresi (http -> ws donusumu)
String get wsUrl => '${apiUrl.replaceFirst('http', 'ws')}/ws';

/// Gercek SMS dogrulamasi (Firebase Phone Auth).
/// false ise test modu: kod ekranda otomatik dolar, SMS gitmez.
/// Derlemede kapatmak icin: --dart-define=REAL_SMS=false
const useRealSms = bool.fromEnvironment('REAL_SMS', defaultValue: true);

final apiProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // 401 oturum-sonlandirmayi TEK SEFER tetikle. Yoksa: token dogrulama (_init) +
  // interceptor birbirini tetikliyordu -> saniyede onlarca /users/me 401 ->
  // SONSUZ DONGU -> uygulama "belirsiz hesap"ta takiliyor, login'e ulasamiyor.
  var oturumBitiyor = false;

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(storageProvider).token;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (e, handler) async {
      final path = e.requestOptions.path;
      // Arama uclari haric (kilit ekrani answer 401'i tum oturumu silmesin).
      if (e.response?.statusCode == 401 &&
          !path.startsWith('/auth/') &&
          !path.startsWith('/calls/') &&
          !oturumBitiyor) {
        oturumBitiyor = true;
        await ref.read(storageProvider).clear();
        ref.invalidate(authProvider); // router otomatik olarak /login'e gonderir
        // Yeni giris/kayittan sonra tekrar tetiklenebilsin
        Future.delayed(const Duration(seconds: 3), () => oturumBitiyor = false);
      }
      handler.next(e);
    },
  ));

  // Basarisiz API istekleri Sentry'e duser (hangi uc, hangi hata kodu)
  dio.addSentry();

  return dio;
});

/// API hatasindan kullaniciya gosterilecek Turkce mesaji cikarir
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Sunucuya ulasilamiyor. Internet baglantinizi kontrol edin.';
    }
  }
  return 'Bir seyler ters gitti, tekrar deneyin.';
}
