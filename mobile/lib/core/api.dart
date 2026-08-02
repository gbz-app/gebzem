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
      // TEST TURU 35 — KAYIT EKRANINDAN ATILMA (kullanici: "ilk giriste kayit olurken
      // patliyor, izinler bazen gelmiyor"): VoIP/FCM token uclari OTURUMDAN BAGIMSIZ
      // tekrar dongulerinden cagriliyor (uygulama acilisinda, giris yapilmadan once de).
      // 401 gelince burasi TUM OTURUMU siliyor + authProvider'i invalidate ediyordu ->
      // GoRouter sifirdan kuruluyor -> kullanici KAYIT ekranindan LOGIN'e firlatiliyor ve
      // acik izin diyaloglari dusuyordu. Turu 33'te tekrar sayisi 5'e cikinca 5 KAT
      // siklasti. Bayat oturum tespiti `/users/me` ve diger tum uclardan zaten yapiliyor.
      // ⚠️ YAPMA: bu iki muafiyeti kaldirma.
      if (e.response?.statusCode == 401 &&
          !path.startsWith('/auth/') &&
          !path.startsWith('/calls/') &&
          !path.startsWith('/users/me/voip-token') &&
          !path.startsWith('/users/me/fcm-token') &&
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
  // Uygulama-ici kural hatalari (or. "Zaten bir aramadasınız") kullaniciya AYNEN gosterilir.
  if (error is StateError) return error.message;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Sunucuya ulaşılamıyor. İnternet bağlantınızı kontrol edin.';
    }
  }
  return 'Bir şeyler ters gitti, tekrar deneyin.';
}
