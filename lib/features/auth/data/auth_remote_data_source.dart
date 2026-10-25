import 'package:dio/dio.dart';

import '../../../core/network/session_cookies.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// HTTP side of auth (hono-workers /auth/* and /me).
abstract interface class AuthRemoteDataSource {
  Future<({AuthTokens tokens, AppUser user})> login({
    required String email,
    required String password,
    String? captchaToken,
  });
  Future<AppUser> me();
  Future<void> logout();
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<({AuthTokens tokens, AppUser user})> login({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'app': 'nubi',
          'captchaToken': ?captchaToken,
        },
      );
      final tokens = tokensFromSetCookie(res.headers);
      if (tokens == null) throw const AuthFailure(AuthFailureReason.unknown);
      return (
        tokens: tokens,
        user: userFromJson(
          res.data?['data']?['user'] as Map<String, dynamic>? ?? const {},
        ),
      );
    } on DioException catch (e) {
      throw AuthFailure(loginFailureReason(e));
    }
  }

  @override
  Future<AppUser> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return userFromJson(res.data?['data'] as Map<String, dynamic>? ?? const {});
  }

  @override
  Future<void> logout() => _dio.post<Object?>('/auth/logout');
}

AppUser userFromJson(Map<String, dynamic> json) => AppUser(
  id: (json['id'] as num?)?.toInt() ?? 0,
  name: json['name'] as String? ?? '',
  email: json['email'] as String? ?? '',
  role: (json['role'] as String? ?? 'user').toLowerCase(),
  apps: {
    for (final e in (json['apps'] as Map<String, dynamic>? ?? const {}).entries)
      if (e.value is String) e.key: e.value as String,
  },
);

/// Same reading of the API's answers as the web login page (nubisport-astro src/pages/login.astro).
AuthFailureReason loginFailureReason(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return AuthFailureReason.network;
  final body = e.response?.data;
  final code = body is Map ? body['code'] : null;
  final error = body is Map ? '${body['error'] ?? ''}'.toLowerCase() : '';
  if (status == 403 && code == 'email_unverified') {
    return AuthFailureReason.emailUnverified;
  }
  if (status == 403 && code == 'account_banned') {
    return AuthFailureReason.banned;
  }
  if (error.contains('captcha')) return AuthFailureReason.captcha;
  if (status == 400 || status == 401) {
    return AuthFailureReason.invalidCredentials;
  }
  if (status == 429) return AuthFailureReason.rateLimited;
  return AuthFailureReason.unknown;
}
