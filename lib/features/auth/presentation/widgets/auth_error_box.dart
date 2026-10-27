import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Inline error shown under the auth forms; announced to screen readers.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
