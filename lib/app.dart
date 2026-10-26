import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'flavors.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/main/main_shell.dart';
import 'shared/widgets/brand.dart';

class NubiApp extends ConsumerWidget {
  const NubiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final auth = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: F.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Dev builds wear a corner ribbon so they are never mistaken for production.
      builder: (context, child) => config.flavor == Flavor.prod
          ? child!
          : Banner(message: F.name.toUpperCase(), location: BannerLocation.topEnd, child: child),
      home: auth.when(
        loading: () => const _Restoring(),
        error: (_, _) => const LoginPage(),
        data: (user) => user == null ? const LoginPage() : MainShell(user: user),
      ),
    );
  }
}

/// While the stored session is checked (right after the native splash): the crest, same as the splash.
class _Restoring extends StatelessWidget {
  const _Restoring();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: BrandCrest(size: 140)));
}
