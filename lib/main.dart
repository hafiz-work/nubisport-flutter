import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'flavors.dart';

/// One entry point for every flavor: `flutter run --flavor dev` / `--flavor prod`.
/// Flutter passes the flavor in as [appFlavor]; no flavor (e.g. widget tests) = dev.
void main() {
  F.appFlavor = Flavor.values.firstWhere(
    (f) => f.name == appFlavor,
    orElse: () => Flavor.dev,
  );
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.forFlavor(F.appFlavor)),
      ],
      child: const NubiApp(),
    ),
  );
}
