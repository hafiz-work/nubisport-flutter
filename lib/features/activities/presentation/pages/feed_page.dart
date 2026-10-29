import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/activity.dart';
import '../controllers/activity_providers.dart';
import '../controllers/kudos_controller.dart';
import '../widgets/activity_card.dart';
import '../widgets/activity_empty_state.dart';
import '../widgets/activity_share_sheet.dart';

/// Community feed: everything from every runner.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  Future<void> _toggleKudos(Activity activity) async {
    if (await ref.read(kudosProvider(activity).notifier).toggle()) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Couldn\'t send kudos. Try again.')),
      );
  }

  void _open(String id) {
    AppNavigator.activityDetail(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(activityFeedProvider);
    final myId = ref.watch(authControllerProvider).value?.id;
    return Scaffold(
      // Cards are surface-coloured; this shows between them as Strava's gap.
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      appBar: AppBar(title: const Text('Feed')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(activityFeedProvider);
          await ref.read(activityFeedProvider.future);
        },
        child: feed.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            children: const [
              ActivityEmptyState(
                icon: Icons.cloud_off,
                title: 'Couldn\'t load feed',
                message: 'Check your connection and try again.',
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  children: const [
                    ActivityEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Feed is empty',
                      message: 'Community activities will appear here.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 140),
                  itemCount: items.length,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(800),
                  itemBuilder: (context, index) {
                    final activity = items[index];
                    final kudos = ref.watch(kudosProvider(activity));
                    return ActivityCard(
                      activity: activity,
                      showUser: true,
                      kudosed: kudos.mine,
                      kudosCount: kudos.count,
                      // The API allows no kudos on your own activity.
                      onKudos: activity.userId != 0 && activity.userId == myId
                          ? null
                          : () => _toggleKudos(activity),
                      onShare: () => showActivityShareSheet(
                        context,
                        activity,
                        isMine: myId == activity.userId,
                      ),
                      onTap: () => _open(activity.id),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
