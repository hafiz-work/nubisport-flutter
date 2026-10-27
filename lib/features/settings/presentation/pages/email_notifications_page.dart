import 'package:flutter/material.dart';

import '../widgets/notification_toggle_tile.dart';

class EmailNotificationsPage extends StatefulWidget {
  const EmailNotificationsPage({super.key});

  @override
  State<EmailNotificationsPage> createState() => _EmailNotificationsPageState();
}

class _EmailNotificationsPageState extends State<EmailNotificationsPage> {
  bool _activityUpdates = true;
  bool _weeklySummary = true;
  bool _planReminders = true;
  bool _productNews = false;
  bool _promotions = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Email Notifications')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Choose which emails Nubi sends to your inbox. You can change this anytime.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  NotificationToggleTile(
                    title: 'Activity updates',
                    subtitle: 'Kudos, comments and mentions',
                    value: _activityUpdates,
                    onChanged: (value) => setState(() => _activityUpdates = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Weekly summary',
                    subtitle: 'Your week in review every Monday',
                    value: _weeklySummary,
                    onChanged: (value) => setState(() => _weeklySummary = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Training plan reminders',
                    subtitle: 'Session reminders and plan updates',
                    value: _planReminders,
                    onChanged: (value) => setState(() => _planReminders = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Product news',
                    subtitle: 'New features and Nubi updates',
                    value: _productNews,
                    onChanged: (value) => setState(() => _productNews = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Promotions',
                    subtitle: 'Offers from Nubi partners',
                    value: _promotions,
                    onChanged: (value) => setState(() => _promotions = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Transactional emails such as password resets and receipts are always sent.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
