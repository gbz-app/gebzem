import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token ve kullanici kimligi guvenli depoda tutulur (Keychain/Keystore)
class AppStorage {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kUserId = 'user_id';

  Future<String?> get token => _storage.read(key: _kToken);
  Future<String?> get userId => _storage.read(key: _kUserId);

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
