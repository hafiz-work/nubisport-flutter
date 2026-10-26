import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';

class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          Text(
            'Pilih rupa aplikasi. Lalai ikut tetapan sistem telefon.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _ThemeOption(
            mode: ThemeMode.system,
            current: mode,
            icon: Icons.brightness_auto_outlined,
            title: 'Ikut sistem',
            detail: 'Tukar automatik bila telefon masuk mod gelap.',
            onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.system),
          ),
          const SizedBox(height: 10),
          _ThemeOption(
            mode: ThemeMode.light,
            current: mode,
            icon: Icons.light_mode_outlined,
            title: 'Cerah',
            detail: 'Latar putih dan navy seperti web Nubi Sport.',
            onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light),
          ),
          const SizedBox(height: 10),
          _ThemeOption(
            mode: ThemeMode.dark,
            current: mode,
            icon: Icons.dark_mode_outlined,
            title: 'Gelap',
            detail: 'Latar navy gelap, sesuai untuk larian malam.',
            onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
          ),
          const SizedBox(height: 20),
          Text(
            'Pilihan ini disimpan untuk sesi app ini sahaja.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.current,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final ThemeMode mode;
  final ThemeMode current;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = mode == current;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
