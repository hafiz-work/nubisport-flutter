import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ActivityEmptyState extends StatelessWidget {
  const ActivityEmptyState({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

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
          Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 17), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
