import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/storage.dart';

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

  /// GERCEK SMS: Firebase telefon dogrulamasi baslat.
  /// SMS gonderilir; [onCodeSent] cagrilinca kullanicidan kod istenir.
  Future<void> sendSms(
    String phone, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
  }) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      // Android'de kod otomatik okunabilir
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          onAutoVerified?.call();
        } catch (_) {}
      },
      verificationFailed: (e) => onError(_smsError(e)),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// GERCEK SMS: kodu dogrula, Firebase kimligiyle backend'e kayit ol / giris yap
  Future<void> confirmSms({
    required String verificationId,
    required String code,
    required String password,
    required String name,
    required String username,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await cred.user?.getIdToken();
    if (idToken == null) throw Exception('Dogrulama basarisiz');

    final res = await _ref.read(apiProvider).post('/auth/verify-firebase', data: {
      'id_token': idToken,
      'password': password,
      'name': name,
      'username': username,
    });
    await FirebaseAuth.instance.signOut(); // kendi oturumumuzu kullaniyoruz
    await _saveSession(res.data);
  }

  String _smsError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Telefon numarasi gecersiz';
      case 'too-many-requests':
        return 'Cok fazla deneme. Biraz sonra tekrar deneyin';
      case 'quota-exceeded':
        return 'SMS kotasi doldu, lutfen sonra deneyin';
      default:
        return e.message ?? 'SMS gonderilemedi';
    }
  }

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
    await _ref.read(storageProvider).clear();
    state = '';
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
