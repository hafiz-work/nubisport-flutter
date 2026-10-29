import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../activity_format.dart';
import 'activity_map.dart';
import 'kudos_bar.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.showUser = false,
    this.kudosed = false,
    this.kudosCount,
    this.onKudos,
    this.onShare,
  });

  final Activity activity;
  final VoidCallback onTap;

  /// Feed cards (Strava's layout): who and when, title, stats, full-bleed map, kudos/share row.
  final bool showUser;

  final bool kudosed;

  /// Overrides [Activity.kudos] once the viewer toggled kudos.
  final int? kudosCount;
  final VoidCallback? onKudos;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Strava: runs lead with pace, walks/rides with elevation.
    final metrics = Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Distance',
            value: formatDistance(activity.distanceKm),
          ),
        ),
        if (activity.type == ActivityType.run)
          Expanded(
            child: _Metric(label: 'Pace', value: formatPace(activity.pace)),
          ),
        Expanded(
          child: _Metric(
            label: 'Time',
            value: formatDuration(activity.duration),
          ),
        ),
        if (activity.type != ActivityType.run)
          Expanded(
            child: _Metric(
              label: 'Elev Gain',
              value: '${activity.elevationGainM} m',
            ),
          ),
      ],
    );

    if (!showUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: scheme.outlineVariant),
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompactHeader(activity: activity),
                  const SizedBox(height: 14),
                  metrics,
                ],
              ),
            ),
          ),
        ),
      );
    }

    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final place = activity.location.isNotEmpty
        ? activity.location
        : activityLabel(activity.type);
    // Cards sit on surfaceContainer (the feed's background), so the 8px gap reads like Strava's.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(initial: activity.userInitial),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRelativeDate(activity.startedAt),
                            style: muted,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                activityIcon(activity.type),
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  place,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  activity.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: metrics,
              ),
              // API activities without a shared route have nothing to draw.
              if (activity.route.isNotEmpty)
                RepaintBoundary(
                  child: ActivityMap(
                    activity: activity,
                    height: 250,
                    borderRadius: BorderRadius.zero,
                    onTap: onTap,
                    replayButton: true,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: KudosBar(
                  count: kudosCount ?? activity.kudos,
                  mine: kudosed,
                  onKudos: onKudos,
                  onShare: onShare,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same rounded-square avatar as the detail page.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: AppColors.orange, width: 2),
    ),
    child: Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: AppTheme.displayFont,
      ),
    ),
  );
}

/// Own-list row: sport icon, title, place, chevron.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Icon(
            activityIcon(activity.type),
            size: 22,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 2),
              Text(
                activity.location.isNotEmpty
                    ? activity.location
                    : formatRelativeDate(activity.startedAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

/// Strava stat: small grey label over a large bold value.
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
