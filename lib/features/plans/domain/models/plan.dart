enum PlanKind {
  fiveK('5k'),
  tenK('10k'),
  half('21k'),
  full('42k');

  const PlanKind(this.code);
  final String code;

  /// Plan keys look like `pelan-<code>:<params>`.
  static PlanKind? fromKey(String key) {
    for (final k in values) {
      if (key.startsWith('pelan-${k.code}:')) return k;
    }
    return null;
  }
}

class CloudPlan {
  const CloudPlan({
    required this.key,
    required this.engine,
    required this.data,
    required this.progress,
    required this.updatedAt,
  });
  final String key;
  final int engine;
  final Map<String, String> data;
  final List<String> progress;
  final DateTime updatedAt;

  PlanKind? get kind => PlanKind.fromKey(key);
}

class PlanSession {
  const PlanSession({
    required this.id,
    required this.date,
    required this.type,
    required this.minutes,
    required this.title,
    required this.instructions,
    required this.effort,
    required this.walk,
  });
  final String id;
  final DateTime? date;
  final String type;
  final int minutes;
  final String title;
  final String instructions;
  final String effort;
  final bool walk;
}

class PlanWeek {
  const PlanWeek({
    required this.no,
    required this.phase,
    required this.light,
    required this.minutes,
    required this.sessions,
  });
  final int no;
  final String phase;
  final bool light;
  final int minutes;
  final List<PlanSession> sessions;
}

class BuiltPlan {
  const BuiltPlan({
    required this.engine,
    required this.key,
    required this.params,
    required this.warnings,
    required this.progress,
    required this.weeks,
  });
  final int engine;
  final String key;
  final Map<String, String> params;
  final List<String> warnings;
  final List<String>? progress;
  final List<PlanWeek> weeks;

  int get sessionCount => weeks.fold(0, (n, w) => n + w.sessions.length);
}

/// The server refused to build the plan (400); [suggestMonths] / [suggestWeeks] are its counter-offers.
class PlanBuildFailure implements Exception {
  const PlanBuildFailure(this.reason, {this.suggestMonths, this.suggestWeeks});
  final String reason;
  final int? suggestMonths;
  final int? suggestWeeks;

  @override
  String toString() => reason;
}

/// Saving would exceed the plan quota (409).
class PlanQuotaFull implements Exception {
  const PlanQuotaFull(this.limit);
  final int limit;
}
