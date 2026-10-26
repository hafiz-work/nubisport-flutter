import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'flavors.dart';

/// One entry point for every flavor: `flutter run --flavor dev` / `--flavor prod`.
/// Flutter passes the flavor in as [appFlavor]; no flavor (e.g. widget tests) = dev.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  F.appFlavor = Flavor.values.firstWhere((f) => f.name == appFlavor, orElse: () => Flavor.dev);

  final app = ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(AppConfig.forFlavor(F.appFlavor))],
    child: const NubiApp(),
  );

  // Liquid Glass powers the iOS tab bar. Other platforms keep Material widgets,
  // so only warm up (and wrap) where the shaders are actually used.
  final usesLiquidGlass = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
  if (usesLiquidGlass) {
    await LiquidGlassWidgets.initialize();
    runApp(LiquidGlassWidgets.wrap(child: app, brightnessResolver: Theme.maybeBrightnessOf));
  } else {
    runApp(app);
  }
}
