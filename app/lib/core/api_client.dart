import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_store.dart';

class ApiClient {
  final Dio dio;
  final SecureStore store;
  bool _isRefreshing = false;

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  ApiClient({required this.store, String? baseUrl})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? defaultBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await store.accessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final opts = error.requestOptions;
              final token = await store.accessToken();
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    _isRefreshing = true;
    try {
      final refresh = await store.refreshToken();
      if (refresh == null) {
        _isRefreshing = false;
        return false;
      }

      final res = await Dio(BaseOptions(baseUrl: dio.options.baseUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );

      if (res.statusCode == 200 && res.data != null) {
        final newAccess = res.data['access_token'] as String;
        final newRefresh = res.data['refresh_token'] as String;
        await store.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
        _isRefreshing = false;
        return true;
      }
    } catch (_) {
      await store.clearAll();
    }
    _isRefreshing = false;
    return false;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(secureStoreProvider);
  return ApiClient(store: store);
});

