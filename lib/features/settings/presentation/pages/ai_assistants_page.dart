import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class AiAssistantsPage extends StatelessWidget {
  const AiAssistantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8A65), AppColors.orange],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text('Claude', style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, color: scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Get more from your training with Claude',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30, height: 1.1),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect to Claude to ask questions about your training, spot patterns, '
              'get ideas for what to do next, and more. Included with your Nubi membership.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 28),
            Text('How to connect', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const _Step(number: '1', text: 'Tap Connect to Claude'),
            const _Step(number: '2', text: 'Tap Add to Claude for Nubi connector'),
            const _Step(number: '3', text: 'Sign in to Nubi if prompted'),
            const _Step(number: '4', text: 'Tap Authorize to connect your Nubi account'),
            const _Step(number: '5', text: 'Open Claude to start chatting'),
            const SizedBox(height: 18),
            Text(
              'Once connected, Claude can read your Nubi activity history to answer your questions. '
              'You can disconnect anytime from Settings or Claude Connectors.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Claude connector is coming soon.')));
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                child: const Text('Connect to Claude'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Disconnect at anytime',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              number,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
