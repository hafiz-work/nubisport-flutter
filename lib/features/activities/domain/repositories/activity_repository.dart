import '../../../auth/domain/models/app_user.dart';
import '../models/activity.dart';

abstract interface class ActivityRepository {
  /// The signed-in user's own activities, newest first.
  Future<List<Activity>> myActivities({required AppUser user});

  /// Everything from the community feed, newest first. [viewer] names the viewer's own items.
  Future<List<Activity>> feed({AppUser? viewer});

  /// A single activity, or null when it no longer exists. [viewer] as in [feed].
  Future<Activity?> activity(String id, {AppUser? viewer});

  /// Give or take back kudos on someone else's shared activity; the server's new state.
  Future<({int count, bool mine})> setKudos(String id, {required bool on});
}
