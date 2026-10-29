import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/activity_repository_provider.dart';
import '../../domain/models/activity.dart';

typedef Kudos = ({int count, bool mine});

/// Kudos on one loaded activity: flips at once, then keeps the server's answer, or rolls back.
/// Keyed by the [Activity] instance, so a reloaded list starts again from the server's counts.
class KudosController extends Notifier<Kudos> {
  KudosController(this._activity);
  final Activity _activity;

  @override
  Kudos build() => (count: _activity.kudos, mine: _activity.kudosed);

  /// false = not sent (offline or refused); the count is back to what it was.
  Future<bool> toggle() async {
    // Differs from the loaded activity from here on: survive the feed row scrolling away.
    ref.keepAlive();
    final before = state;
    final on = !before.mine;
    state = (count: before.count + (on ? 1 : -1), mine: on);
    try {
      final after = await ref
          .read(activityRepositoryProvider)
          .setKudos(_activity.id, on: on);
      if (ref.mounted) state = after;
      return true;
    } catch (_) {
      if (ref.mounted) state = before;
      return false;
    }
  }
}

final kudosProvider = NotifierProvider.autoDispose
    .family<KudosController, Kudos, Activity>(KudosController.new);
