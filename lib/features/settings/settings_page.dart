import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import '../plans/presentation/plans_page.dart';
import '../profile/change_password_page.dart';
import 'pricing_sheet.dart';
import 'theme_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _autoplayVideo = true;

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label akan datang.')));
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _logout() async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final confirmed = await FamilyModalSheet.show<bool>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Icon(Icons.logout, color: scheme.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Log keluar?', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Anda perlu log masuk semula untuk meneruskan.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
              child: const Text('Log keluar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.of(sheetContext).pop(false), child: const Text('Batal')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = ref.watch(themeModeProvider);
    final email = ref.watch(authControllerProvider).value?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const _SectionHeader('Subscriptions'),
          _SettingsRow(
            leading: _IconTile(icon: Icons.workspace_premium, color: AppColors.orange),
            title: '30-Day Subscription Preview',
            subtitle: 'Subscribe now to keep the best of Nubi.',
            showChevron: true,
            onTap: () => showPricingSheet(context),
          ),
          _SettingsRow(
            leading: const _IconTile(icon: Icons.directions_run, color: Color(0xFF14B8A6)),
            title: 'Training Plans',
            subtitle: 'Discover personalized running plans, from 5K to marathon',
            showChevron: true,
            onTap: () => _open(const PlansPage()),
          ),
          _SectionHeader(email.isEmpty ? 'Account' : 'Account $email'),
          _SettingsRow(
            leading: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
            title: 'Change Password',
            subtitle: 'All sessions will be signed out.',
            showChevron: true,
            onTap: () => _open(const ChangePasswordPage()),
          ),
          _SettingsRow(
            leading: Icon(Icons.sensors, color: scheme.onSurface),
            title: 'Connect an app or device',
            subtitle: 'Upload directly to Nubi with almost any fitness app or device',
            showChevron: true,
            onTap: () => _comingSoon('Sambungan peranti'),
          ),
          _SettingsRow(
            leading: Icon(Icons.auto_awesome, color: scheme.onSurface),
            title: 'AI Assistants',
            subtitle: 'Connect an AI assistant for personalized conversations on your activities and training',
            showChevron: true,
            onTap: () => _comingSoon('Pembantu AI'),
          ),
          _SettingsRow(
            title: 'Manage apps and devices',
            showChevron: true,
            onTap: () => _comingSoon('Urus app dan peranti'),
          ),
          _SettingsRow(title: 'Restore Purchases', onTap: () => _comingSoon('Pulihkan pembelian')),
          _SettingsRow(title: 'Change Email', showChevron: true, onTap: () => _comingSoon('Tukar e-mel')),
          _SettingsRow(
            title: 'Phone Number',
            subtitle: '••••••••0074',
            showChevron: true,
            onTap: () => _comingSoon('Nombor telefon'),
          ),
          _SettingsRow(title: 'Help', showChevron: true, onTap: () => _comingSoon('Bantuan')),
          const _SectionHeader('Preferences'),
          _SettingsRow(title: 'Appearance', trailingText: themeModeLabel(mode), onTap: () => _open(const ThemePage())),
          _SettingsRow(
            title: 'Privacy Controls',
            trailing: const _NewBadge(),
            onTap: () => _comingSoon('Kawalan privasi'),
          ),
          _SettingsRow(title: 'Units of Measurement', trailingText: 'Metric', onTap: () => _comingSoon('Unit ukuran')),
          _SettingsRow(title: 'Temperature', trailingText: 'Celsius', onTap: () => _comingSoon('Suhu')),
          _SettingsRow(
            title: 'Default Highlight Image',
            subtitle: 'Highlight the map or a photo to represent your uploaded activities in the feed.',
            trailingText: 'Photo',
            onTap: () => _comingSoon('Imej sorotan'),
          ),
          _SettingsRow(
            title: 'Autoplay Video',
            trailing: Switch(value: _autoplayVideo, onChanged: (value) => setState(() => _autoplayVideo = value)),
          ),
          _SettingsRow(title: 'Default Maps', showChevron: true, onTap: () => _comingSoon('Peta lalai')),
          _SettingsRow(
            title: 'Feed Ordering',
            subtitle: 'Change how activities are ordered in your feed',
            showChevron: true,
            onTap: () => _comingSoon('Susunan feed'),
          ),
          _SettingsRow(
            title: 'Training Zones',
            subtitle: 'Customize your training zones',
            showChevron: true,
            onTap: () => _comingSoon('Zon latihan'),
          ),
          _SettingsRow(title: 'Siri & Shortcuts', showChevron: true, onTap: () => _comingSoon('Siri & Shortcuts')),
          _SettingsRow(title: 'Beacon', showChevron: true, onTap: () => _comingSoon('Beacon')),
          _SettingsRow(title: 'Partner Integrations', showChevron: true, onTap: () => _comingSoon('Integrasi rakan')),
          _SettingsRow(title: 'Weather', showChevron: true, onTap: () => _comingSoon('Cuaca')),
          _SettingsRow(title: 'Health Data', showChevron: true, onTap: () => _comingSoon('Data kesihatan')),
          _SettingsRow(title: 'Contacts', showChevron: true, onTap: () => _comingSoon('Kenalan')),
          _SettingsRow(title: 'Push Notifications', showChevron: true, onTap: () => _comingSoon('Notifikasi push')),
          _SettingsRow(title: 'Email Notifications', showChevron: true, onTap: () => _comingSoon('Notifikasi e-mel')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
              ),
              child: const Text('Log Out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      color: scheme.brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.35) : scheme.surfaceContainerLow,
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 12),
                Text(trailingText!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(AppTheme.radius)),
      child: const Text(
        'NEW',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
