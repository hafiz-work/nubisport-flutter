import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/activity.dart';
import '../activity_format.dart';
import '../activity_providers.dart';
import 'activity_detail_page.dart';
import '../widgets/activity_card.dart';
import '../widgets/activity_empty_state.dart';

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
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ActivityDetailPage(activityId: id)));
  }

  Future<void> _share(Activity activity) async {
    final text =
        '${activity.userName} · ${activity.title}\n'
        '${formatDistance(activity.distanceKm)} · ${formatDuration(activity.duration)} · '
        '${formatPace(activity.pace)}/km\n'
        '${activity.location}\n'
        '#NubiSport';
    await SharePlus.instance.share(ShareParams(text: text, subject: activity.title));
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
                title: 'Tak dapat muat feed',
                message: 'Semak sambungan anda dan cuba lagi.',
              ),
            ],
          ),
          data: (items) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Full-bleed feed: no horizontal padding, cards touch the screen edges.
            padding: const EdgeInsets.only(top: 8, bottom: 140),
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: ActivityEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Feed masih kosong',
                    message: 'Aktiviti komuniti akan muncul di sini.',
                  ),
                )
              else
                for (var i = 0; i < items.length; i++) ...[
                  ActivityCard(
                    activity: items[i],
                    showUser: true,
                    kudosed: _kudosed.contains(items[i].id),
                    onKudos: () => _toggleKudos(items[i].id),
                    onShare: () => _share(items[i]),
                    onTap: () => _open(items[i].id),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
