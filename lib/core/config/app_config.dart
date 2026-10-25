import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../flavors.dart';
import 'env.dart';

/// Runtime config for the current flavor. Overridden in main.dart; tests pass their own.
class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl, required this.webOrigin});

  factory AppConfig.forFlavor(Flavor flavor) => switch (flavor) {
        Flavor.dev => AppConfig(flavor: flavor, apiBaseUrl: DevEnv.apiBaseUrl, webOrigin: DevEnv.webOrigin),
        Flavor.prod => AppConfig(flavor: flavor, apiBaseUrl: ProdEnv.apiBaseUrl, webOrigin: ProdEnv.webOrigin),
      };

  final Flavor flavor;
  final String apiBaseUrl;
  final String webOrigin;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider is overridden in main.dart'),
);
