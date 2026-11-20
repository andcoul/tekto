import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sse.dart';

export 'sse.dart' show SseEvent;

/// Returns the current access token, or null when signed out.
typedef AccessTokenReader = String? Function();

/// The live Supabase session token; supabase_flutter refreshes it before it expires.
String? currentSupabaseAccessToken() => Supabase.instance.client.auth.currentSession?.accessToken;

/// Dio client pre-configured for Supabase Edge Function calls.
class TektoDioClient {
  /// [baseUrl] and [anonKey] default to the build's `--dart-define` values; the offline-sync
  /// integration test passes the local Supabase stack's values instead.
  TektoDioClient({
    AccessTokenReader accessToken = currentSupabaseAccessToken,
    String baseUrl = const String.fromEnvironment('SUPABASE_URL'),
    String anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
  }) : _accessToken = accessToken {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'apikey': anonKey,
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
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.delete<T>(path, data: data, queryParameters: queryParameters);

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.patch<T>(path, data: data, queryParameters: queryParameters);

  /// POSTs [data] and returns the `text/event-stream` reply as events (coach-message).
  ///
  /// Any status other than 200 throws [ApiStatusException] with the contract error code. The
  /// status is read here rather than raised by Dio, so a 503 (`AI_UNAVAILABLE`) is never
  /// silently retried by the retry interceptor.
  Future<Stream<SseEvent>> postEventStream(String path, {Object? data}) async {
    final response = await _dio.post<ResponseBody>(
      path,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        receiveTimeout: const Duration(seconds: 90),
        headers: {'Accept': 'text/event-stream'},
      ),
    );
    final body = response.data;
    final status = response.statusCode ?? 0;
    if (status != 200 || body == null) {
      throw ApiStatusException(status, body == null ? null : await _errorCode(body.stream));
    }
    return parseSse(body.stream);
  }

  static Future<String?> _errorCode(Stream<List<int>> stream) async {
    try {
      final json = jsonDecode(await utf8.decodeStream(stream));
      if (json is Map) return (json['code'] ?? json['error']) as String?;
    } on FormatException {
      // not JSON
    }
    return null;
  }
}

/// A non-success HTTP status with the contract error code from the body (e.g. `QUOTA_EXCEEDED`).
class ApiStatusException implements Exception {
  const ApiStatusException(this.statusCode, this.code);

  final int statusCode;
  final String? code;

  @override
  String toString() => 'ApiStatusException($statusCode, $code)';
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
