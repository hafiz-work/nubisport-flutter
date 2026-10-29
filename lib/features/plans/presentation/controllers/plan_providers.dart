import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/plan_repository_provider.dart';
import '../../domain/models/plan.dart';

final cloudPlansProvider = FutureProvider.autoDispose<({int limit, List<CloudPlan> items})>(
  (ref) => ref.watch(planRepositoryProvider).list(),
);

final activePlanProvider = FutureProvider.autoDispose<({String? plan, String? walkUntil})>(
  (ref) => ref.watch(planRepositoryProvider).active(),
);

final builtPlanProvider = FutureProvider.autoDispose.family<BuiltPlan, CloudPlan>((ref, plan) async {
  final kind = plan.kind;
  if (kind == null) throw PlanBuildFailure('Unknown plan kind');
  final active = await ref.watch(activePlanProvider.future);
  return ref
      .watch(planRepositoryProvider)
      .build(
        kind: kind,
        params: plan.data,
        key: plan.key,
        walkUntil: active.plan == plan.key ? active.walkUntil : null,
      );
});
