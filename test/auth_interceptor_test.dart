import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/network/api_client.dart';
import 'package:nubisport_flutter/core/storage/token_storage.dart';

import 'auth_test.dart' show MemoryTokenStorage;
import 'support/fake_adapter.dart';

/// /me answers 401 (expired access token); /auth/refresh answers [refreshStatus].
({Dio dio, MemoryTokenStorage storage, List<int> expired}) _client(
  int refreshStatus,
) {
  final routes = {
    'GET /me': (401, {'success': false, 'error': 'Unauthorized'}),
    'POST /auth/refresh': (refreshStatus, {'success': false, 'error': 'nope'}),
  };
  final storage = MemoryTokenStorage()
    ..value = const AuthTokens(accessToken: 'a1', refreshToken: 'r1');
  final expired = <int>[];
  final dio = Dio()..httpClientAdapter = FakeAdapter(routes);
  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      refreshClient: Dio()..httpClientAdapter = FakeAdapter(routes),
      retryClient: dio,
      onSessionExpired: () => expired.add(1),
    ),
  );
  return (dio: dio, storage: storage, expired: expired);
}

void main() {
  test('refresh failing with a server error keeps the session', () async {
    final c = _client(503);
    await expectLater(
      c.dio.get<Object?>('/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          503,
        ),
      ),
    );
    expect(c.storage.value?.refreshToken, 'r1');
    expect(c.expired, isEmpty);
  });

  test(
    'refresh rejected with 401 clears the session and signals expiry',
    () async {
      final c = _client(401);
      await expectLater(
        c.dio.get<Object?>('/me'),
        throwsA(isA<DioException>()),
      );
      expect(c.storage.value, isNull);
      expect(c.expired, [1]);
    },
  );
}
