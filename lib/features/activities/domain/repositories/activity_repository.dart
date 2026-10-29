import '../models/activity.dart';

abstract interface class ActivityRepository {
  /// The signed-in user's own activities, newest first.
  Future<List<Activity>> myActivities({required int userId});

  /// Everything from the community feed, newest first.
  Future<List<Activity>> feed();

  /// A single activity, or null when it no longer exists.
  Future<Activity?> activity(String id);

  /// Give or take back kudos on someone else's shared activity; the server's new state.
  Future<({int count, bool mine})> setKudos(String id, {required bool on});
}
