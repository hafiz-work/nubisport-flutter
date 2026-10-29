import '../models/plan.dart';

abstract interface class PlanRepository {
  Future<({int limit, List<CloudPlan> items})> list();

  /// Throws [PlanBuildFailure] when the server rejects the parameters.
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    String? key,
    ({Map<String, String> params, List<String> progress})? previous,
    String? walkUntil,
  });

  /// Throws [PlanQuotaFull] when the quota is used up and [replace] frees nothing.
  Future<void> save({
    required String key,
    required int engine,
    required Map<String, String> data,
    required List<String> progress,
    String? replace,
  });

  Future<void> delete(String key);

  Future<({String? plan, String? walkUntil})> active();

  Future<void> setActive({required String key, required int engine, String? walkUntil});

  /// Read-only: the app never writes the training profile.
  Future<Map<String, String>> trainingProfile();
}
