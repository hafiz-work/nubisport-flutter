import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../controllers/activity_providers.dart';
import '../widgets/activity_card.dart';
import '../widgets/activity_empty_state.dart';

/// The signed-in user's own runs.
class ActivitiesPage extends ConsumerWidget {
  const ActivitiesPage({super.key});

  void _open(BuildContext context, String id) {
    AppNavigator.activityDetail(context, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(myActivitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My activities')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(myActivitiesProvider);
          await ref.read(myActivitiesProvider.future);
        },
        child: activities.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            children: const [
              ActivityEmptyState(
                icon: Icons.cloud_off,
                title: 'Couldn\'t share image.',
                message: 'Check your connection and try again.',
              ),
            ],
          ),
          data: (items) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            children: [
              if (items.isEmpty)
                const ActivityEmptyState(
                  icon: Icons.directions_run,
                  title: 'No activities yet',
                  message: 'Your runs and workouts will appear here.',
                )
              else
                for (final activity in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActivityCard(
                      activity: activity,
                      onTap: () => _open(context, activity.id),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
