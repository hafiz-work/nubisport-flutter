import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/activity_repository.dart';
import 'api_activity_repository.dart';
import 'mock_activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  if (ref.watch(appConfigProvider).isMock) return MockActivityRepository();
  return ApiActivityRepository(ref.watch(dioProvider));
});
