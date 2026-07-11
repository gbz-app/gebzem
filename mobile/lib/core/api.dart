import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage.dart';

/// API adresi:
/// - Android emulatoru: 10.0.2.2 bilgisayarin localhost'una gider
/// - Gercek cihaz/uretim: --dart-define=API_URL=https://api.gebzem.app ile degistir
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

/// WebSocket adresi (http -> ws donusumu)
String get wsUrl => '${apiUrl.replaceFirst('http', 'ws')}/ws';

final apiProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(storageProvider).token;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));

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
