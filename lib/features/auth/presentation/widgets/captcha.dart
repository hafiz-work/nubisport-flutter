import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';

/// Gets a Turnstile token for [action] (`login`, `register` or `reset`); null when the check
/// fails. A provider so tests can swap the WebView out.
typedef CaptchaSolver = Future<String?> Function(String action);

final captchaSolverProvider = Provider<CaptchaSolver>((ref) {
  final config = ref.watch(appConfigProvider);
  // Mock repositories ignore the token, so there is nothing to check.
  if (config.isMock) return (_) async => 'mock';
  return (action) async {
    // Invisible widget in a hidden WebView; baseUrl becomes the token's hostname, which the
    // API checks against TURNSTILE_HOSTNAMES.
    final turnstile = CloudflareTurnstile.invisible(
      siteKey: config.turnstileSiteKey,
      action: action,
      baseUrl: config.webOrigin,
    );
    try {
      return await turnstile.getToken();
    } on TurnstileException {
      return null;
    } finally {
      await turnstile.dispose();
    }
  };
});
