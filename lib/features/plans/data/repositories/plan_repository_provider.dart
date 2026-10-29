import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/plan_repository.dart';
import 'api_plan_repository.dart';
import 'mock_plan_repository.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  if (ref.watch(appConfigProvider).isMock) return MockPlanRepository();
  return ApiPlanRepository(ref.watch(dioProvider));
});
