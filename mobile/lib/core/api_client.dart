import 'dart:async';
import 'package:dio/dio.dart';
import 'env.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// Thin Dio wrapper for the StyloAI backend. Attaches the backend JWT, refreshes
/// it once on a 401/expired response, and normalizes errors into [ApiException]
/// so the UI can map error codes to states. The client is never trusted for
/// money — it only forwards requests and renders server responses.
class ApiClient {
  final Dio _dio;
  final TokenStore tokens;
  Future<void> Function()? onSessionExpired;

  ApiClient(this.tokens)
      : _dio = Dio(BaseOptions(
          baseUrl: '${Env.apiBaseUrl}/v1',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 40),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = tokens.accessToken;
        if (t != null && options.headers['Authorization'] == null) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
    ));
  }

  Dio get raw => _dio;

  Future<Map<String, dynamic>> get(String path,
          {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path,
          {Object? data, Map<String, String>? headers}) =>
      _request(() =>
          _dio.post(path, data: data, options: Options(headers: headers)));

  Future<Map<String, dynamic>> patch(String path, {Object? data}) =>
      _request(() => _dio.patch(path, data: data));

  Future<Map<String, dynamic>> put(String path, {Object? data}) =>
      _request(() => _dio.put(path, data: data));

  Future<Map<String, dynamic>> delete(String path) =>
      _request(() => _dio.delete(path));

  Future<Map<String, dynamic>> _request(
    Future<Response> Function() run, {
    bool retried = false,
  }) async {
    try {
      final res = await run();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data == null || data == '') return <String, dynamic>{};
      return {'data': data};
    } on DioException catch (e) {
      final apiErr = _toApiException(e);
      // Attempt a single refresh on an expired/unauth response.
      if (!retried &&
          (apiErr.code == 'TOKEN_EXPIRED' ||
              apiErr.code == 'UNAUTHENTICATED') &&
          tokens.refreshToken != null) {
        final refreshed = await _tryRefresh();
        if (refreshed) return _request(run, retried: true);
        await onSessionExpired?.call();
      }
      throw apiErr;
    }
  }

  bool _refreshing = false;
  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final res = await _dio.post('/auth/refresh',
          data: {'refresh_token': tokens.refreshToken},
          options: Options(headers: {'Authorization': null}));
      final data = res.data as Map<String, dynamic>;
      await tokens.save(
          data['access_token'] as String, data['refresh_token'] as String);
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  ApiException _toApiException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException.network();
    }
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        (err['code'] ?? 'INTERNAL').toString(),
        (err['message'] ?? 'Something went wrong.').toString(),
        details: (err['details'] as Map?)?.cast<String, dynamic>(),
        status: e.response?.statusCode,
      );
    }
    return ApiException.unknown();
  }
}
