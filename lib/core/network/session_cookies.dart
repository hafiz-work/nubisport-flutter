import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// The API never puts tokens in a JSON body - login and refresh return them as Set-Cookie
/// (`access_token`, `refresh_token`). A browser keeps them as httpOnly cookies; the app reads
/// them from the headers once and moves them to secure storage. Null = not both present.
AuthTokens? tokensFromSetCookie(Headers headers) {
  String? access;
  String? refresh;
  for (final line in headers['set-cookie'] ?? const <String>[]) {
    final pair = line.split(';').first;
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    final name = pair.substring(0, eq).trim();
    final value = pair.substring(eq + 1).trim();
    if (value.isEmpty) continue; // a deleted cookie (logout) has an empty value
    if (name == 'access_token') access = value;
    if (name == 'refresh_token') refresh = value;
  }
  return access != null && refresh != null
      ? AuthTokens(accessToken: access, refreshToken: refresh)
      : null;
}
