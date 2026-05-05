import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<void> saveSession(
      {required String accessToken, required String refreshToken}) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'refreshToken', value: refreshToken);
  }

  Future<void> saveChaoxingAccount(
      {required String account, required String password}) async {
    await _storage.write(key: 'chaoxingAccount', value: account);
    await _storage.write(key: 'chaoxingPassword', value: password);
  }

  Future<String?> readChaoxingAccount() =>
      _storage.read(key: 'chaoxingAccount');

  Future<String?> readChaoxingPassword() =>
      _storage.read(key: 'chaoxingPassword');

  Future<String?> readAccessToken() => _storage.read(key: 'accessToken');

  Future<String?> readRefreshToken() => _storage.read(key: 'refreshToken');

  Future<void> saveChaoxingCredentialRef(String credentialRef) {
    return _storage.write(key: 'chaoxingCredentialRef', value: credentialRef);
  }

  Future<void> clear() => _storage.deleteAll();
}
