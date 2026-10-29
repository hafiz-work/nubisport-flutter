import 'package:envied/envied.dart';

part 'env.g.dart';

// Build-time config per flavor (envied reads .env.dev / .env.prod - see .env.example).
// Nothing here is secret: the API URL and web origin are public. Never put an API key in
// the app - anything shipped in a binary can be extracted.

@Envied(path: '.env.dev', name: 'DevEnv')
abstract final class DevEnv {
  @EnviedField(varName: 'API_BASE_URL')
  static const String apiBaseUrl = _DevEnv.apiBaseUrl;
  @EnviedField(varName: 'WEB_ORIGIN')
  static const String webOrigin = _DevEnv.webOrigin;
  @EnviedField(varName: 'IS_MOCK', defaultValue: false)
  static const bool isMock = _DevEnv.isMock;
  @EnviedField(varName: 'TURNSTILE_SITE_KEY', defaultValue: '')
  static const String turnstileSiteKey = _DevEnv.turnstileSiteKey;
}

@Envied(path: '.env.prod', name: 'ProdEnv')
abstract final class ProdEnv {
  @EnviedField(varName: 'API_BASE_URL')
  static const String apiBaseUrl = _ProdEnv.apiBaseUrl;
  @EnviedField(varName: 'WEB_ORIGIN')
  static const String webOrigin = _ProdEnv.webOrigin;
  @EnviedField(varName: 'IS_MOCK', defaultValue: false)
  static const bool isMock = _ProdEnv.isMock;
  @EnviedField(varName: 'TURNSTILE_SITE_KEY', defaultValue: '')
  static const String turnstileSiteKey = _ProdEnv.turnstileSiteKey;
}
