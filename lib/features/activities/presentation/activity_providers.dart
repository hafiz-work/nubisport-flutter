import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/activity_repository_provider.dart';
import '../domain/activity.dart';

/// Scoped to the signed-in account: log in as a different demo account and
/// "Aktiviti saya" shows that account's runs.
final myActivitiesProvider = FutureProvider.autoDispose<List<Activity>>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return const [];
  return ref.watch(activityRepositoryProvider).myActivities(userId: user.id);
});

final activityFeedProvider = FutureProvider.autoDispose<List<Activity>>((ref) {
  return ref.watch(activityRepositoryProvider).feed();
});

final activityDetailProvider = FutureProvider.autoDispose.family<Activity?, String>((ref, id) {
  return ref.watch(activityRepositoryProvider).activity(id);
});
