import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_navigator.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../activities/domain/models/activity.dart';
import '../activities/presentation/activity_format.dart';
import '../activities/presentation/controllers/activity_providers.dart';
import '../activities/presentation/widgets/activity_card.dart';
import '../auth/domain/models/app_user.dart';

/// Post-login dashboard. Summary and recent runs come from the activity
/// repository (mock for now), scoped to the signed-in account.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.user, this.onOpenProfile, this.onOpenFeed, this.onOpenActivities});

  final AppUser user;

  /// Lets the shell switch tabs from the matching shortcut.
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenFeed;
  final VoidCallback? onOpenActivities;

  void _openDetail(BuildContext context, String id) {
    AppNavigator.activityDetail(context, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void comingSoon(String label) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon.')));

    final activities = ref.watch(myActivitiesProvider);
    final items = activities.value ?? const <Activity>[];
    final week = _lastSevenDays(items);
    final totalKm = week.fold<double>(0, (sum, activity) => sum + activity.distanceKm);
    final totalTime = week.fold<Duration>(Duration.zero, (sum, activity) => sum + activity.duration);
    final recent = items.take(2).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nubi Sport')),
      body: ListView(
        // Extra room so the floating iOS glass bar never covers the last card.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          _GreetingCard(user: user),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Last 7 days summary'),
          const SizedBox(height: 10),
          _StatsRow(runs: '${week.length}', distance: formatDistance(totalKm), time: formatDuration(totalTime)),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Shortcuts'),
          const SizedBox(height: 10),
          _QuickActions(
            onTap: (label) {
              if (label == 'Profile' && onOpenProfile != null) {
                onOpenProfile!();
                return;
              }
              if (label == 'Community' && onOpenFeed != null) {
                onOpenFeed!();
                return;
              }
              if (label == 'Training plan') {
                AppNavigator.push<void>(context, AppRoutes.trainingPlans);
                return;
              }
              comingSoon(label);
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Recent activities',
            trailing: items.isEmpty ? null : 'See all',
            onTrailingTap: items.isEmpty ? null : onOpenActivities,
          ),
          const SizedBox(height: 10),
          if (activities.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (recent.isEmpty)
            const _EmptyActivity()
          else
            for (final activity in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActivityCard(activity: activity, onTap: () => _openDetail(context, activity.id)),
              ),
        ],
      ),
    );
  }
}

List<Activity> _lastSevenDays(List<Activity> items) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  return items.where((activity) => !activity.startedAt.isBefore(start)).toList();
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.user});
  final AppUser user;

  String get _initial {
    final name = user.name.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  String get _status {
    if (user.role == 'owner') return 'Pemilik';
    if (user.role == 'admin' || user.apps['nubi'] == 'admin') {
      return 'Admin';
    }
    if (user.isMember) return 'Nubi Member';
    return 'Not a member';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = user.isMember || user.role != 'user';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navy2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            child: Text(
              _initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Barlow Condensed',
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onDarkMuted)),
                const SizedBox(height: 2),
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: highlighted ? AppColors.orange : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing, this.onTrailingTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkColor = theme.brightness == Brightness.dark ? AppColors.orangeHover : AppColors.orangeInk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18))),
        if (trailing != null)
          if (onTrailingTap == null)
            Text(trailing!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: linkColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: linkColor,
                ),
              ),
            ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.runs, required this.distance, required this.time});
  final String runs;
  final String distance;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(icon: Icons.directions_run, value: runs, label: 'Run'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(icon: Icons.route_outlined, value: distance, label: 'Distance'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(icon: Icons.timer_outlined, value: time, label: 'Time'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onTap});
  final void Function(String label) onTap;

  static const _actions = [
    (label: 'Start run', icon: Icons.play_circle_outline),
    (label: 'Training plan', icon: Icons.event_note_outlined),
    (label: 'Community', icon: Icons.groups_outlined),
    (label: 'Profile', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in _actions)
              SizedBox(
                width: width,
                child: _QuickAction(label: action.label, icon: action.icon, onTap: () => onTap(action.label)),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No activities yet', style: theme.textTheme.titleLarge?.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            'Your runs and plans will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
