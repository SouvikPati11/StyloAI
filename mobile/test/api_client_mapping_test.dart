import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/core/api_client.dart';

/// Tests the ACTUAL error-mapping logic the app runs on every failed request
/// (ApiClient.mapDioException / classifyTransport), using synthetic Dio errors.
/// This is what guarantees an HTTP 4xx/5xx is never shown as "No connection",
/// and that transport failures are classified precisely for diagnostics.
void main() {
  final ro = RequestOptions(path: '/v1/auth/google', baseUrl: 'https://api.souvikpati.in');

  DioException transport({DioExceptionType? type, Object? error}) => DioException(
        requestOptions: ro,
        type: type ?? DioExceptionType.connectionError,
        error: error,
      );

  DioException http(int status, {Object? data}) => DioException(
        requestOptions: ro,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: ro, statusCode: status, data: data),
      );

  group('classifyTransport (real transport diagnostics)', () {
    test('connection timeout', () {
      expect(ApiClient.classifyTransport(transport(type: DioExceptionType.connectionTimeout)),
          'CONNECTION_TIMEOUT');
      expect(ApiClient.classifyTransport(transport(type: DioExceptionType.receiveTimeout)),
          'CONNECTION_TIMEOUT');
    });
    test('DNS failure', () {
      expect(
          ApiClient.classifyTransport(
              transport(error: const SocketException('Failed host lookup: api.souvikpati.in'))),
          'DNS_FAILURE');
    });
    test('TLS failure', () {
      expect(
          ApiClient.classifyTransport(transport(error: const HandshakeException('handshake failed'))),
          'TLS_ERROR');
    });
    test('connection refused', () {
      expect(
          ApiClient.classifyTransport(transport(error: const SocketException('Connection refused'))),
          'CONNECTION_REFUSED');
    });
    test('cleartext blocked', () {
      expect(
          ApiClient.classifyTransport(
              transport(error: 'CLEARTEXT communication to host not permitted')),
          'CLEARTEXT_BLOCKED');
    });
    test('unknown socket error falls back to SOCKET_ERROR', () {
      expect(ApiClient.classifyTransport(transport(error: const SocketException('weird'))),
          'SOCKET_ERROR');
    });
  });

  group('mapDioException (HTTP status is never network)', () {
    for (final s in [400, 401, 403, 404, 409, 422, 500]) {
      test('HTTP $s → coded, not network, status preserved', () {
        final ex = ApiClient.mapDioException(http(s));
        expect(ex.isNetwork, isFalse, reason: 'HTTP $s must not be network');
        expect(ex.status, s);
        expect(ex.code, 'HTTP_$s');
        expect(ex.diag, 'HTTP_$s');
      });
    }

    test('backend error envelope is surfaced (code + status)', () {
      final ex = ApiClient.mapDioException(http(401, data: {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'bad token'}
      }));
      expect(ex.isNetwork, isFalse);
      expect(ex.code, 'UNAUTHENTICATED');
      expect(ex.status, 401);
      expect(ex.isAuth, isTrue);
    });

    test('transport failure (no response) → NETWORK with precise diag', () {
      final ex = ApiClient.mapDioException(
          transport(type: DioExceptionType.connectionTimeout));
      expect(ex.isNetwork, isTrue);
      expect(ex.diag, 'CONNECTION_TIMEOUT');
      expect(ex.message.toLowerCase(), contains('connection'));
    });
  });
}
