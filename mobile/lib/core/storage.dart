import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token ve kullanici kimligi guvenli depoda tutulur (Keychain/Keystore)
class AppStorage {
  // iOS: first_unlock -> cihaz ilk kilit acilistan SONRA (kilitliyken bile) okunabilir.
  // Varsayilan (whenUnlocked) kilitliyken PlatformException -25308 firlatiyordu ->
  // VoIP/CallKit ile kilit ekranindan kabul edilen aramada token okunamiyor, answer patlar.
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kToken = 'auth_token';
  static const _kUserId = 'user_id';

  Future<String?> get token async {
    try {
      return await _storage.read(key: _kToken);
    } on PlatformException {
      return null; // ilk-unlock oncesi / migration durumunda guvenli varsayilan
    }
  }

  Future<String?> get userId async {
    try {
      return await _storage.read(key: _kUserId);
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveSession(String token, String userId) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUserId, value: userId);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserId);
  }
}

final storageProvider = Provider<AppStorage>((ref) => AppStorage());
