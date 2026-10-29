import '../../domain/models/plan.dart';
import '../../domain/repositories/plan_repository.dart';

/// In-memory plans; `build` always returns the same 2-week plan.
class MockPlanRepository implements PlanRepository {
  static const _limit = 3;
  final Map<String, CloudPlan> _plans = {};
  String? _active;
  String? _walkUntil;

  @override
  Future<({int limit, List<CloudPlan> items})> list() async => (limit: _limit, items: _plans.values.toList());

  @override
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    String? key,
    ({Map<String, String> params, List<String> progress})? previous,
    String? walkUntil,
  }) async {
    final start = DateTime.tryParse(params['mula'] ?? '');
    PlanWeek week(int no) => PlanWeek(
      no: no,
      phase: 'Asas',
      light: false,
      minutes: 90,
      sessions: [
        for (var i = 0; i < 3; i++)
          PlanSession(
            id: 'w$no-s$i',
            date: start == null ? null : DateTime(start.year, start.month, start.day + (no - 1) * 7 + i * 2),
            type: 'lari',
            minutes: 30,
            title: 'Lari santai',
            instructions: 'Kekalkan rentak perlahan.',
            effort: 'mudah',
            walk: false,
          ),
      ],
    );
    return BuiltPlan(
      engine: 1,
      key: key ?? 'pelan-${kind.code}:mock',
      params: params,
      warnings: const [],
      progress: previous?.progress,
      weeks: [week(1), week(2)],
    );
  }

  @override
  Future<void> save({
    required String key,
    required int engine,
    required Map<String, String> data,
    required List<String> progress,
    String? replace,
  }) async {
    if (replace != null) _plans.remove(replace);
    if (!_plans.containsKey(key) && _plans.length >= _limit) throw const PlanQuotaFull(_limit);
    _plans[key] = CloudPlan(key: key, engine: engine, data: data, progress: progress, updatedAt: DateTime.now());
  }

  @override
  Future<void> delete(String key) async => _plans.remove(key);

  @override
  Future<({String? plan, String? walkUntil})> active() async => (plan: _active, walkUntil: _walkUntil);

  @override
  Future<void> setActive({required String key, required int engine, String? walkUntil}) async {
    _active = key;
    _walkUntil = walkUntil;
  }

  @override
  Future<Map<String, String>> trainingProfile() async => {};
}
