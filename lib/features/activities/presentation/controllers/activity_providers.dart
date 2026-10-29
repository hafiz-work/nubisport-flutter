import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/activity_repository_provider.dart';
import '../../domain/models/activity.dart';

/// Scoped to the signed-in account: log in as a different demo account and
/// "Aktiviti saya" shows that account's runs.
final myActivitiesProvider = FutureProvider.autoDispose<List<Activity>>((
  ref,
) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return const [];
  return ref.watch(activityRepositoryProvider).myActivities(user: user);
});

final activityFeedProvider = FutureProvider.autoDispose<List<Activity>>((ref) {
  final viewer = ref.watch(authControllerProvider).value;
  return ref.watch(activityRepositoryProvider).feed(viewer: viewer);
});

final activityDetailProvider = FutureProvider.autoDispose
    .family<Activity?, String>((ref, id) {
      final viewer = ref.watch(authControllerProvider).value;
      return ref.watch(activityRepositoryProvider).activity(id, viewer: viewer);
    });
