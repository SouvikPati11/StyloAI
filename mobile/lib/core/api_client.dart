import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    // Diagnostic (non-secret): record which host the build actually targets.
    // This makes a misconfigured base URL (e.g. an emulator loopback left in a
    // release build, or an empty --dart-define) obvious in logcat. Only the
    // scheme/host/port are logged — never paths with data, tokens or secrets.
    final b = Uri.tryParse(Env.apiBaseUrl);
    debugPrint('[api] baseUrl target=${b == null ? '(unparseable)' : '${b.scheme}://${b.host}:${b.hasPort ? b.port : '(default)'}'} flavor=${Env.flavor}');

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = tokens.accessToken;
        if (t != null && options.headers['Authorization'] == null) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        // Diagnostic (non-secret): method + host + path only. Never the query,
        // body, or Authorization header (those can carry tokens).
        debugPrint('[api] request=${options.method} '
            '${options.uri.host}:${options.uri.port}${options.uri.path}');
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
    final u = e.requestOptions.uri;
    final where = '${u.host}:${u.port}${u.path}';

    // An HTTP response was received → this is NEVER "No connection". Classify by
    // status (401/403/404/500…) and surface the backend's error envelope when
    // present. This guarantees a 4xx/5xx is never mislabeled as a network error.
    final resp = e.response;
    if (resp != null) {
      final status = resp.statusCode;
      final data = resp.data;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        final code = (err['code'] ?? 'HTTP_$status').toString();
        debugPrint('[api] http-error status=$status code=$code path=${u.path}');
        return ApiException(
          code,
          (err['message'] ?? 'Something went wrong.').toString(),
          details: (err['details'] as Map?)?.cast<String, dynamic>(),
          status: status,
          diag: 'HTTP_$status',
        );
      }
      debugPrint('[api] http-error status=$status (no envelope) path=${u.path}');
      return ApiException('HTTP_$status', _httpMessage(status),
          status: status, diag: 'HTTP_$status');
    }

    // No response → a genuine transport failure. Classify the precise cause so
    // the logcat pinpoints it (DNS / refused / timeout / cleartext / TLS).
    final diag = _classifyTransport(e);
    debugPrint('[api] transport-error=$diag target=$where '
        'dioType=${e.type.name} cause=${e.error?.runtimeType ?? 'unknown'}');
    return ApiException.network(diag: diag);
  }

  /// Maps a transport-level [DioException] to a precise, non-secret code.
  String _classifyTransport(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'CONNECTION_TIMEOUT';
    }
    final blob = '${e.error}'.toLowerCase();
    if (blob.contains('failed host lookup') ||
        blob.contains('nodename nor servname') ||
        blob.contains('name or service not known')) {
      return 'DNS_FAILURE';
    }
    if (blob.contains('cleartext')) return 'CLEARTEXT_BLOCKED';
    if (blob.contains('handshake') ||
        blob.contains('certificate') ||
        blob.contains('tls') ||
        blob.contains('ssl')) {
      return 'TLS_ERROR';
    }
    if (blob.contains('connection refused')) return 'CONNECTION_REFUSED';
    if (blob.contains('timed out') || blob.contains('timeout')) {
      return 'CONNECTION_TIMEOUT';
    }
    if (blob.contains('network is unreachable') ||
        blob.contains('no route to host')) {
      return 'NETWORK_UNREACHABLE';
    }
    return 'SOCKET_ERROR';
  }

  String _httpMessage(int? status) {
    switch (status) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You don’t have access to this.';
      case 404:
        return 'Not found.';
      case 429:
        return 'Too many requests. Please try again shortly.';
      default:
        if (status != null && status >= 500) {
          return 'The server had a problem. Please try again.';
        }
        return 'Something went wrong. Please try again.';
    }
  }
}
