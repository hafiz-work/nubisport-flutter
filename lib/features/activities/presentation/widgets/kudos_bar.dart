import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Strava's "Be the first to give kudos!" line + evenly spaced kudos/share icons.
/// [onKudos] null = own activity (the API allows no self-kudos).
class KudosBar extends StatelessWidget {
  const KudosBar({
    super.key,
    required this.count,
    required this.mine,
    required this.onKudos,
    required this.onShare,
  });
  final int count;
  final bool mine;
  final VoidCallback? onKudos;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = count == 0
        ? (onKudos == null ? 'No kudos yet' : 'Be the first to give kudos!')
        : '$count ${count == 1 ? 'kudo' : 'kudos'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            text,
            key: ValueKey(text),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: mine ? 'Take back kudos' : 'Give kudos',
              onPressed: onKudos,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                  child: child,
                ),
                child: Icon(
                  mine ? Icons.thumb_up : Icons.thumb_up_outlined,
                  key: ValueKey(mine),
                  color: mine
                      ? AppColors.orange
                      : (onKudos == null ? scheme.outline : scheme.onSurface),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Share activity',
              onPressed: onShare,
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ),
      ],
    );
  }
}
