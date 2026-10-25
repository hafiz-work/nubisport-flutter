import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'session_cookies.dart';

/// Headers every call needs:
/// - `X-App: nubi` - the API ties the session/JWT to the Nubi app (the web's Worker adds it);
/// - `Origin` - the API's CSRF gate rejects writes without an allow-listed origin.
BaseOptions apiOptions(AppConfig config) => BaseOptions(
  baseUrl: config.apiBaseUrl,
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 20),
  contentType: Headers.jsonContentType,
  headers: {'X-App': 'nubi', 'Origin': config.webOrigin},
);

/// Adds the bearer token, and on a 401 refreshes once then retries. Queued: requests that hit
/// 401 together wait for ONE refresh - the refresh token rotates, so a second parallel refresh
/// would use a dead token and sign the user out.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.refreshClient,
    required this.retryClient,
    this.onSessionExpired,
  });

  final TokenStorage storage;

  /// Bare client (no interceptors) for /auth/refresh.
  final Dio refreshClient;

  /// The main client, to replay the original request.
  final Dio retryClient;
  final void Function()? onSessionExpired;

  static const _noAuth = {'/auth/login', '/auth/refresh'};

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_noAuth.contains(options.path)) {
      final tokens = await storage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _noAuth.contains(request.path) ||
        request.extra['retried'] == true) {
      return handler.next(err);
    }
    final stored = await storage.read();
    if (stored == null) return handler.next(err);

    // Another queued request already refreshed: just replay with the new token.
    final usedToken = (request.headers['Authorization'] as String?)
        ?.replaceFirst('Bearer ', '');
    var tokens = stored;
    if (usedToken == stored.accessToken) {
      final refreshed = await _refresh(stored.refreshToken);
      if (refreshed == null) {
        await storage.clear();
        onSessionExpired?.call();
        return handler.next(err);
      }
      await storage.write(refreshed);
      tokens = refreshed;
    }

    try {
      request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      request.extra['retried'] = true;
      handler.resolve(await retryClient.fetch(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<AuthTokens?> _refresh(String refreshToken) async {
    try {
      final res = await refreshClient.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return tokensFromSetCookie(res.headers);
    } on DioException {
      return null;
    }
  }
}

/// Called when the refresh token is dead - the auth controller listens and shows login.
final sessionExpiredProvider = NotifierProvider<SessionExpired, int>(
  SessionExpired.new,
);

class SessionExpired extends Notifier<int> {
  @override
  int build() => 0;
  void fire() => state++;
}

final dioProvider = Provider<Dio>((ref) {
  final options = apiOptions(ref.watch(appConfigProvider));
  final dio = Dio(options);
  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      refreshClient: Dio(options),
      retryClient: dio,
      onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).fire(),
    ),
  );
  return dio;
});
