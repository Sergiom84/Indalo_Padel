import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'padel_token';
  static const _userKey = 'padel_user';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<String?> getUser() async {
    return await _storage.read(key: _userKey);
  }

  static Future<void> saveUser(String userJson) async {
    await _storage.write(key: _userKey, value: userJson);
  }

  static Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  static Future<String?> readValue(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> writeValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<void> deleteValue(String key) async {
    await _storage.delete(key: key);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
