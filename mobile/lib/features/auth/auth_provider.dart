import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/push.dart';
import '../../core/storage.dart';
import '../../core/ws.dart';

/// Oturum durumu: null = kontrol ediliyor, '' = cikis yapilmis, dolu = girisli
class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final token = await _ref.read(storageProvider).token;
    state = token ?? '';
  }

  /// Kayit baslat — dev modda OTP kodu doner (SMS yerine)
  Future<String?> register(
      String phone, String password, String name, String username) async {
    final res = await _ref.read(apiProvider).post('/auth/register', data: {
      'phone': phone,
      'password': password,
      'name': name,
      'username': username,
    });
    return res.data['dev_otp'] as String?;
  }

  /// OTP dogrula — basarili olursa oturum acilir (test modu)
  Future<void> verify(String phone, String code) async {
    final res = await _ref.read(apiProvider).post('/auth/verify', data: {
      'phone': phone,
      'code': code,
    });
    await _saveSession(res.data);
  }

  // NOT: Firebase Phone Auth KALDIRILDI — magaza disi kurulumlarda iOS'ta cokuyor,
  // Android'de tarayiciya (reCAPTCHA) atiyordu. SMS'i artik kendi sunucumuz gonderiyor.

  Future<void> login(String phone, String password) async {
    final res = await _ref.read(apiProvider).post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    await _saveSession(res.data);
  }

  /// Sifre sifirlama kodu iste — dev modda kod doner
  Future<String?> forgot(String phone) async {
    final res = await _ref.read(apiProvider).post('/auth/forgot', data: {'phone': phone});
    return res.data['dev_otp'] as String?;
  }

  Future<void> reset(String phone, String code, String newPassword) async {
    await _ref.read(apiProvider).post('/auth/reset', data: {
      'phone': phone,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async {
    // ONEMLI: cikmadan ONCE bu cihazin oturumunu TAM kapat. Yoksa ayni cihazda
    // yeni giren kullanici, oncekinin WebSocket'inde ve push kaydinda kalir
    // (A'nin mesajlari/aramalari B'de gorunur, profilde A'nin numarasi).
    try {
      await _ref.read(pushProvider).unregister(); // bu cihazin token'ini sunucudan sil
    } catch (_) {}
    await _ref.read(wsProvider).close(); // canli soketi kapat
    await _ref.read(storageProvider).clear();
    state = '';
    // Kullaniciya bagli saglayicilari sifirla (eski verinin ekranda kalmamasi icin)
    _ref.invalidate(wsProvider);
    _ref.invalidate(pushProvider);
  }

  Future<void> _saveSession(dynamic data) async {
    final token = data['token'] as String;
    final userId = data['user_id'] as String;
    await _ref.read(storageProvider).saveSession(token, userId);
    state = token;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, String?>(AuthNotifier.new);

/// Girisli kullanicinin id'si (senkron erisim icin ayrica tutulur)
final myUserIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(authProvider); // oturum degisince yenile
  return ref.read(storageProvider).userId;
});
