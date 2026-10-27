import 'package:flutter/material.dart';

import '../widgets/notification_toggle_tile.dart';

class PushNotificationsPage extends StatefulWidget {
  const PushNotificationsPage({super.key});

  @override
  State<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends State<PushNotificationsPage> {
  bool _activityUpdates = true;
  bool _newFollowers = true;
  bool _planReminders = true;
  bool _weeklyGoal = true;
  bool _communityMentions = true;
  bool _marketing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notifications')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Choose the notifications you want on this device.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  NotificationToggleTile(
                    title: 'Activity updates',
                    subtitle: 'Kudos and comments on your activities',
                    value: _activityUpdates,
                    onChanged: (value) => setState(() => _activityUpdates = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'New followers',
                    subtitle: 'When someone starts following you',
                    value: _newFollowers,
                    onChanged: (value) => setState(() => _newFollowers = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Training plan reminders',
                    subtitle: 'Reminders for today\'s session',
                    value: _planReminders,
                    onChanged: (value) => setState(() => _planReminders = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Weekly goal',
                    subtitle: 'Progress towards your weekly target',
                    value: _weeklyGoal,
                    onChanged: (value) => setState(() => _weeklyGoal = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Community mentions',
                    subtitle: 'When someone mentions you in the feed',
                    value: _communityMentions,
                    onChanged: (value) => setState(() => _communityMentions = value),
                  ),
                  const Divider(height: 1),
                  NotificationToggleTile(
                    title: 'Marketing',
                    subtitle: 'Offers, events and product news',
                    value: _marketing,
                    onChanged: (value) => setState(() => _marketing = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You can also manage notification permissions in your phone settings.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
