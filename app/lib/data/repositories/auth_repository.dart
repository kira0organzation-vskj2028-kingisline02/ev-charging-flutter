import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_store.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStore _store;

  AuthRepository(this._apiClient, this._store);

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String role = 'driver',
    String? phone,
  }) async {
    await _apiClient.dio.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role,
        'phone': phone,
      },
    );
  }

  Future<void> verifyOtp({
    required String email,
    required String code,
  }) async {
    await _apiClient.dio.post(
      '/auth/verify-otp',
      data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
    );
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _apiClient.dio.post(
      '/auth/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = res.data as Map<String, dynamic>;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _store.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    await _store.saveUser(user);
    return user;
  }

  Future<UserModel?> getCurrentUser() async {
    final cached = await _store.getUser();
    try {
      final res = await _apiClient.dio.get('/auth/me');
      final user = UserModel.fromJson(res.data as Map<String, dynamic>);
      await _store.saveUser(user);
      return user;
    } catch (_) {
      return cached;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {}
    await _store.clearAll();
  }

  Future<void> updateFcmToken(String token) async {
    try {
      await _apiClient.dio.put('/auth/fcm-token', data: {'token': token});
    } catch (_) {}
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final store = ref.watch(secureStoreProvider);
  return AuthRepository(client, store);
});

