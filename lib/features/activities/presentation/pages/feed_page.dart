import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/activity_providers.dart';
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
  /// Kudos are local for now; the API write lands with the real repository.
  final Set<String> _kudosed = {};

  void _toggleKudos(String id) {
    setState(() {
      if (!_kudosed.remove(id)) _kudosed.add(id);
    });
  }

  void _open(String id) {
    AppNavigator.activityDetail(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(activityFeedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(activityFeedProvider);
          await ref.read(activityFeedProvider.future);
        },
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
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
                    return ActivityCard(
                      activity: activity,
                      showUser: true,
                      kudosed: _kudosed.contains(activity.id),
                      onKudos: () => _toggleKudos(activity.id),
                      onShare: () => showActivityShareSheet(
                        context,
                        activity,
                        isMine: ref.read(authControllerProvider).value?.id == activity.userId,
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
