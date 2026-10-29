import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/session_cookies.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// HTTP side of auth (hono-workers /auth/* and /me).
abstract interface class AuthRemoteDataSource {
  Future<({AuthTokens tokens, AppUser user})> login({
    required String email,
    required String password,
    String? captchaToken,
  });

  /// No tokens are returned: the account needs email verification before login.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? captchaToken,
  });
  Future<void> forgotPassword({required String email, String? captchaToken});
  Future<AppUser> updateProfile({
    required String name,
    required String username,
    required String location,
    required String bio,
    required bool profilePublic,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
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
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'app': 'nubi',
          'captchaToken': ?captchaToken,
        },
      );
    } on DioException catch (e) {
      throw AuthFailure(registerFailureReason(e));
    }
  }

  @override
  Future<void> forgotPassword({
    required String email,
    String? captchaToken,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {'email': email, 'app': 'nubi', 'captchaToken': ?captchaToken},
      );
    } on DioException catch (e) {
      throw AuthFailure(forgotPasswordFailureReason(e));
    }
  }

  @override
  Future<AppUser> updateProfile({
    required String name,
    required String username,
    required String location,
    required String bio,
    required bool profilePublic,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/me',
        data: {
          'displayName': name,
          'username': username.isEmpty ? null : username,
          'bio': bio,
          'location': location,
          'profilePublic': profilePublic,
        },
      );
      // Re-read /me so the app gets exactly what the server stored.
      return await me();
    } on DioException catch (e) {
      throw AuthFailure(profileFailureReason(e));
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/me/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw AuthFailure(passwordFailureReason(e));
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

AppUser userFromJson(Map<String, dynamic> json) {
  final profile = json['profile'] is Map<String, dynamic>
      ? json['profile'] as Map<String, dynamic>
      : const <String, dynamic>{};
  return AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: (json['role'] as String? ?? 'user').toLowerCase(),
    apps: {
      for (final e
          in (json['apps'] as Map<String, dynamic>? ?? const {}).entries)
        if (e.value is String) e.key: e.value as String,
    },
    username: json['username'] as String? ?? '',
    bio: profile['bio'] as String? ?? '',
    location: profile['location'] as String? ?? '',
    profilePublic: json['profilePublic'] as bool? ?? false,
  );
}

/// No answer from the server. Logged (logcat shows it in release too) because the UI only
/// says "No connection", and the cause - DNS, TLS, timeout - is what fixes it.
AuthFailureReason _network(DioException e) {
  debugPrint(
    'auth: no response from ${e.requestOptions.uri}: ${e.type} ${e.error ?? e.message}',
  );
  return AuthFailureReason.network;
}

/// Same reading of the API's answers as the web login page (nubisport-astro src/pages/login.astro).
AuthFailureReason loginFailureReason(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return _network(e);
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

/// Same reading as the web register form: a 400 carries the offending `field`.
AuthFailureReason registerFailureReason(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return _network(e);
  final body = e.response?.data;
  final field = body is Map ? body['field'] : null;
  final code = body is Map ? body['code'] : null;
  final error = body is Map ? '${body['error'] ?? ''}'.toLowerCase() : '';
  if (error.contains('captcha')) return AuthFailureReason.captcha;
  if (status == 409 || code == 'email_taken') {
    return AuthFailureReason.emailTaken;
  }
  if (status == 400) {
    return switch (field) {
      'name' => AuthFailureReason.invalidName,
      'email' => AuthFailureReason.invalidEmail,
      'password' => AuthFailureReason.weakPassword,
      _ => AuthFailureReason.unknown,
    };
  }
  if (status == 429) return AuthFailureReason.rateLimited;
  return AuthFailureReason.unknown;
}

/// Same reading as the web forgot-password form: a captcha failure, a 400 (bad email) and 429 are special.
AuthFailureReason forgotPasswordFailureReason(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return _network(e);
  final body = e.response?.data;
  final error = body is Map ? '${body['error'] ?? ''}'.toLowerCase() : '';
  if (error.contains('captcha')) return AuthFailureReason.captcha;
  if (status == 400) return AuthFailureReason.invalidEmail;
  if (status == 429) return AuthFailureReason.rateLimited;
  return AuthFailureReason.unknown;
}

/// Web profile edit errors: code `username_taken` / `username_required`, or a bad field.
AuthFailureReason profileFailureReason(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return _network(e);
  final body = e.response?.data;
  final code = body is Map ? body['code'] : null;
  final field = body is Map ? body['field'] : null;
  if (code == 'username_taken') return AuthFailureReason.usernameTaken;
  if (code == 'username_required') return AuthFailureReason.usernameRequired;
  if (field == 'username') return AuthFailureReason.invalidUsername;
  if (field == 'name' || field == 'displayName') {
    return AuthFailureReason.invalidName;
  }
  if (status == 429) return AuthFailureReason.rateLimited;
  return AuthFailureReason.unknown;
}

/// Web password errors: the server says "current password" for a wrong one; other
/// 400s mean the new password failed the rules.
AuthFailureReason passwordFailureReason(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return _network(e);
  final body = e.response?.data;
  final error = body is Map ? '${body['error'] ?? ''}'.toLowerCase() : '';
  if (status == 401 || error.contains('current password')) {
    return AuthFailureReason.wrongPassword;
  }
  if (status == 400) return AuthFailureReason.weakPassword;
  if (status == 429) return AuthFailureReason.rateLimited;
  return AuthFailureReason.unknown;
}
