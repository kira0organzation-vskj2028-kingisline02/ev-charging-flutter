import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/user_model.dart';

class SecureStore {
  final FlutterSecureStorage _storage;

  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserData = 'user_data';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> accessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<String?> refreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveUser(UserModel user) async {
    await _storage.write(
      key: _keyUserData,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<UserModel?> getUser() async {
    final str = await _storage.read(key: _keyUserData);
    if (str == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserData);
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore();
});

