import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the current access token, or null when signed out.
typedef AccessTokenReader = String? Function();

/// The live Supabase session token; supabase_flutter refreshes it before it expires.
String? currentSupabaseAccessToken() => Supabase.instance.client.auth.currentSession?.accessToken;

/// Dio client pre-configured for Supabase Edge Function calls.
class TektoDioClient {
  TektoDioClient({AccessTokenReader accessToken = currentSupabaseAccessToken}) : _accessToken = accessToken {
    _dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment('SUPABASE_URL'),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'apikey': const String.fromEnvironment('SUPABASE_ANON_KEY'),
        'Content-Type': 'application/json',
      },
    ))
      ..interceptors.add(_AuthInterceptor(_accessToken))
      ..interceptors.add(_RetryInterceptor());
  }

  final AccessTokenReader _accessToken;
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

/// Attaches the live session token. (A copy kept in secure storage went stale after the hourly
/// refresh and was never written for OAuth sign-ins.)
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._accessToken);
  final AccessTokenReader _accessToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _accessToken();
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
