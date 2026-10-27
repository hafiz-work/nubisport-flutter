import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_mode_provider.dart';

class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _ThemeRow(
              mode: ThemeMode.system,
              current: mode,
              label: 'Phone default',
              onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.system),
            ),
            const SizedBox(height: 18),
            _ThemeRow(
              mode: ThemeMode.light,
              current: mode,
              label: 'Light mode',
              onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light),
            ),
            const SizedBox(height: 18),
            _ThemeRow(
              mode: ThemeMode.dark,
              current: mode,
              label: 'Dark mode',
              onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.mode, required this.current, required this.label, required this.onTap});

  final ThemeMode mode;
  final ThemeMode current;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = mode == current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _ThemePreview(mode: mode),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, color: scheme.onSurface)),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 24,
              color: selected ? AppColors.orange : scheme.onSurface.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final isSystem = mode == ThemeMode.system;
    final isDark = mode == ThemeMode.dark;
    return Container(
      width: 74,
      height: 92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      ),
      child: isSystem
          ? const Row(
              children: [
                Expanded(child: _MiniScreen(dark: false)),
                Expanded(child: _MiniScreen(dark: true)),
              ],
            )
          : _MiniScreen(dark: isDark),
    );
  }
}

class _MiniScreen extends StatelessWidget {
  const _MiniScreen({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final line = dark ? Colors.white24 : Colors.black12;
    return Container(
      color: dark ? const Color(0xFF0A0A0A) : Colors.white,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(3)),
                child: const Text(
                  'N',
                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800, height: 1),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(child: Container(height: 2, color: line)),
            ],
          ),
          const SizedBox(height: 5),
          Container(height: 2, width: 26, color: line),
          const SizedBox(height: 3),
          Container(height: 2, width: 18, color: line),
          const Spacer(),
          Container(
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF1E3A5F), Color(0xFF2D6A4F)]
                    : const [Color(0xFFBFDBFE), Color(0xFFBBF7D0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
