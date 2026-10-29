import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../activity_format.dart';
import 'activity_map.dart';

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

  /// Feed cards show who ran, a full-bleed map and the kudos/share row.
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

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showUser) ...[
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.navy,
                child: Text(
                  activity.userInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.displayFont,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      formatActivityDate(activity.startedAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Icon(activityIcon(activity.type), size: 22, color: scheme.primary),
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
                  if (activity.location.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            activity.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!showUser) ...[const SizedBox(width: 8), Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)],
          ],
        ),
      ],
    );

    final metrics = Row(
      children: [
        Expanded(
          child: _Metric(value: formatDistance(activity.distanceKm), label: 'Distance'),
        ),
        Expanded(
          child: _Metric(value: formatDuration(activity.duration), label: 'Time'),
        ),
        Expanded(
          child: _Metric(value: formatPace(activity.pace), label: 'Pace'),
        ),
      ],
    );

    final actionStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
    );

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
          child: showUser
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: header),
                    // API activities without a shared route have nothing to draw.
                    if (activity.route.isNotEmpty)
                      Stack(
                        children: [
                          RepaintBoundary(
                            child: ActivityMap(activity: activity, height: 250, borderRadius: BorderRadius.zero),
                          ),
                          Positioned.fill(
                            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
                          ),
                        ],
                      ),
                    Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: metrics),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: onKudos,
                            icon: Icon(kudosed ? Icons.favorite : Icons.favorite_border, size: 18),
                            label: Text('${kudosCount ?? activity.kudos} kudos'),
                            style: actionStyle.copyWith(
                              foregroundColor: WidgetStatePropertyAll(
                                kudosed
                                    ? (theme.brightness == Brightness.dark
                                          ? AppColors.orangeHover
                                          : AppColors.orangeInk)
                                    : scheme.onSurfaceVariant,
                              ),
                              textStyle: WidgetStatePropertyAll(
                                theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: kudosed ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: onShare,
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Share'),
                            style: actionStyle.copyWith(
                              foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, const SizedBox(height: 14), metrics],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
