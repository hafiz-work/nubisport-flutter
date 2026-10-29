import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/plans/data/repositories/plan_repository_provider.dart';
import 'package:nubisport_flutter/features/plans/domain/models/plan.dart';
import 'package:nubisport_flutter/features/plans/domain/repositories/plan_repository.dart';
import 'package:nubisport_flutter/features/plans/presentation/controllers/plan_controller.dart';
import 'package:nubisport_flutter/features/plans/presentation/controllers/plan_providers.dart';

BuiltPlan _built(String key, {List<String>? progress}) => BuiltPlan(
  engine: 1,
  key: key,
  params: const {'mula': '2026-11-02'},
  warnings: const [],
  progress: progress,
  weeks: const [],
);

class _Repo implements PlanRepository {
  final saved = <CloudPlan>[
    CloudPlan(
      key: 'k',
      engine: 1,
      data: const {'mula': '2026-10-01'},
      progress: const ['w1d1'],
      updatedAt: DateTime(2026),
    ),
  ];
  final builds = <({Map<String, String> params, List<String> progress})?>[];
  final writes = <String>[];
  var lists = 0;

  @override
  Future<({int limit, List<CloudPlan> items})> list() async {
    lists++;
    return (limit: 3, items: saved);
  }

  @override
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    String? key,
    ({Map<String, String> params, List<String> progress})? previous,
    String? walkUntil,
  }) async {
    builds.add(previous);
    return _built('k', progress: const ['w1d1-remapped']);
  }

  @override
  Future<void> save({
    required String key,
    required int engine,
    required Map<String, String> data,
    required List<String> progress,
    String? replace,
  }) async => writes.add('save $key ${progress.join(',')}');

  @override
  Future<void> delete(String key) async => writes.add('delete $key');

  @override
  Future<({String? plan, String? walkUntil})> active() async =>
      (plan: null, walkUntil: null);

  @override
  Future<void> setActive({
    required String key,
    required int engine,
    String? walkUntil,
  }) async => writes.add('active $key $walkUntil');

  @override
  Future<Map<String, String>> trainingProfile() async => const {};
}

void main() {
  test(
    'a new plan with a saved plan\'s key keeps and remaps its ticks, then refreshes the list',
    () async {
      final repo = _Repo();
      final c = ProviderContainer(
        overrides: [planRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      await c.read(cloudPlansProvider.future);

      final stored = await c
          .read(planControllerProvider)
          .saveBuilt(_built('k'), kind: PlanKind.fiveK);

      expect(repo.builds.single?.progress, ['w1d1']);
      expect(stored.progress, ['w1d1-remapped']);
      expect(repo.writes, ['save k w1d1-remapped']);
      await c.read(cloudPlansProvider.future);
      expect(
        repo.lists,
        3,
        reason: 'listed for the key check, then the list provider reloaded',
      );
    },
  );

  test('a new key saves as is, without a rebuild', () async {
    final repo = _Repo();
    final c = ProviderContainer(
      overrides: [planRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);

    final stored = await c
        .read(planControllerProvider)
        .saveBuilt(_built('other'), kind: PlanKind.fiveK);

    expect(repo.builds, isEmpty);
    expect(stored.progress, isEmpty);
    expect(repo.writes, ['save other ']);
  });

  test(
    'delete and set active write through and refresh what shows them',
    () async {
      final repo = _Repo();
      final c = ProviderContainer(
        overrides: [planRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final plans = c.read(planControllerProvider);

      await plans.setActive(
        repo.saved.first,
        engine: 1,
        walkUntil: '2026-11-08',
      );
      await plans.delete('k');

      expect(repo.writes, ['active k 2026-11-08', 'delete k']);
    },
  );
}
