import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _sessionKey = 'supabase_access_token';

/// Dio client pre-configured for Supabase Edge Function calls.
class TektoDioClient {
  TektoDioClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment('SUPABASE_URL'),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'apikey': const String.fromEnvironment('SUPABASE_ANON_KEY'),
        'Content-Type': 'application/json',
      },
    ))
      ..interceptors.add(_AuthInterceptor(_storage))
      ..interceptors.add(_RetryInterceptor());
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters);

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
  }) =>
      _dio.delete<T>(path, data: data);

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
  }) =>
      _dio.patch<T>(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _sessionKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _RetryInterceptor extends Interceptor {
  static const _maxRetries = 3;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    final retries = (extra['retries'] as int?) ?? 0;

    final shouldRetry = retries < _maxRetries &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            (err.response?.statusCode != null &&
                err.response!.statusCode! >= 500));

    if (shouldRetry) {
      err.requestOptions.extra['retries'] = retries + 1;
      await Future<void>.delayed(Duration(milliseconds: 500 * (retries + 1)));
      try {
        final dio = Dio();
        final response = await dio.fetch<dynamic>(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        // Fall through to handler.next
      }
    }

    handler.next(err);
  }
}
