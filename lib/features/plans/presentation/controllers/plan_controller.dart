import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/plan_repository_provider.dart';
import '../../domain/models/plan.dart';
import '../../domain/repositories/plan_repository.dart';
import 'plan_providers.dart';

/// Plan actions for the plan pages. Every write refreshes the lists that show it. Not autoDispose:
/// the plan page still flushes its last ticks after it is closed.
class PlanController {
  PlanController(this._ref);
  final Ref _ref;

  PlanRepository get _repo => _ref.read(planRepositoryProvider);

  Future<Map<String, String>> trainingProfile() => _repo.trainingProfile();

  Future<List<CloudPlan>> saved() async => (await _repo.list()).items;

  /// Throws [PlanBuildFailure] when the server rejects the parameters.
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    CloudPlan? existing,
  }) => _repo.build(
    kind: kind,
    params: params,
    key: existing?.key,
    previous: existing == null
        ? null
        : (params: existing.data, progress: existing.progress),
  );

  /// Saves a built plan and returns it as stored. A new plan with the key of a saved one (the key
  /// ignores dates) keeps and remaps that plan's ticks, like the web.
  /// Throws [PlanQuotaFull] when the quota is used up and [replace] frees nothing.
  Future<CloudPlan> saveBuilt(
    BuiltPlan built, {
    required PlanKind kind,
    CloudPlan? existing,
    String? replace,
  }) async {
    var plan = built;
    var previous = existing;
    if (previous == null) {
      previous = (await saved()).where((i) => i.key == built.key).firstOrNull;
      if (previous != null) {
        plan = await build(
          kind: kind,
          params: built.params,
          existing: previous,
        );
      }
    }
    final stored = CloudPlan(
      key: plan.key,
      engine: plan.engine,
      data: plan.params,
      progress: plan.progress ?? previous?.progress ?? const [],
      updatedAt: DateTime.now(),
    );
    await _repo.save(
      key: stored.key,
      engine: stored.engine,
      data: stored.data,
      progress: stored.progress,
      replace: replace,
    );
    _ref.invalidate(cloudPlansProvider);
    return stored;
  }

  /// The ticked sessions of [plan].
  Future<void> saveProgress(
    CloudPlan plan, {
    required int engine,
    required List<String> progress,
  }) async {
    await _repo.save(
      key: plan.key,
      engine: engine,
      data: plan.data,
      progress: progress,
    );
    _ref.invalidate(cloudPlansProvider);
  }

  Future<void> delete(String key) async {
    await _repo.delete(key);
    _ref.invalidate(cloudPlansProvider);
    _ref.invalidate(activePlanProvider);
  }

  /// Makes [plan] the active one; [walkUntil] (yyyy-mm-dd) sets or extends walk mode, null ends it.
  Future<void> setActive(
    CloudPlan plan, {
    required int engine,
    String? walkUntil,
  }) async {
    await _repo.setActive(key: plan.key, engine: engine, walkUntil: walkUntil);
    _ref.invalidate(activePlanProvider);
  }
}

final planControllerProvider = Provider<PlanController>(PlanController.new);
