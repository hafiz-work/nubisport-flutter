import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/brand.dart';
import '../auth/domain/app_user.dart';
import '../auth/presentation/auth_controller.dart';

/// Placeholder after login - proves the session works. Real screens replace it.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(height: 28),
        actions: [
          IconButton(
            tooltip: 'Log keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Hai, ${user.name}', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                user.isMember ? 'Ahli Nubi' : 'Belum ahli',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
