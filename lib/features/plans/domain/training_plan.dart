import 'dart:math' as math;

enum PlanLevel { sifar, jalan, fiveK }

enum PlanPhase { asas, dayaTahan, kelajuan, ujian }

enum SessionKind { easy, walkRun, strides, fartlek, intervals, tempo, longRun, test }

extension PlanLevelLabel on PlanLevel {
  String get label => switch (this) {
    PlanLevel.sifar => 'Belum boleh lari 1 km',
    PlanLevel.jalan => 'Boleh jalan-lari 5 km',
    PlanLevel.fiveK => 'Boleh lari 5 km tanpa henti',
  };
}

extension PlanPhaseLabel on PlanPhase {
  String get label => switch (this) {
    PlanPhase.asas => 'Asas',
    PlanPhase.dayaTahan => 'Daya tahan',
    PlanPhase.kelajuan => 'Kelajuan',
    PlanPhase.ujian => 'Ujian',
  };
}

class PlanSession {
  const PlanSession({required this.title, required this.minutes, required this.detail, required this.kind});

  final String title;
  final int minutes;
  final String detail;
  final SessionKind kind;
}

class PlanWeek {
  const PlanWeek({required this.number, required this.phase, required this.light, required this.sessions});

  final int number;
  final PlanPhase phase;
  final bool light;
  final List<PlanSession> sessions;

  int get minutes => sessions.fold(0, (sum, session) => sum + session.minutes);
}

class TrainingPlan {
  const TrainingPlan({
    required this.title,
    required this.level,
    required this.months,
    required this.daysPerWeek,
    required this.targetMinutes,
    required this.weeks,
    required this.note,
  });

  final String title;
  final PlanLevel level;
  final int months;
  final int daysPerWeek;
  final int targetMinutes;
  final List<PlanWeek> weeks;
  final String note;

  int get sessionCount => weeks.fold(0, (sum, week) => sum + week.sessions.length);
  String get targetPace => formatPlanPace(targetMinutes * 60 ~/ 5);
}

/// Builds a progressive 5K plan (2/3/4/6 months, 3-4 days a week) inspired by
/// the web's /plan-5k generator: base -> endurance -> speed, a lighter week
/// every 4th week, then a taper/test week.
TrainingPlan build5kPlan({
  required int months,
  required PlanLevel level,
  required int daysPerWeek,
  required int targetMinutes,
}) {
  final weeks = months * 4;
  final targetPace = targetMinutes * 60 ~/ 5;
  final base = switch (level) {
    PlanLevel.sifar => 60.0,
    PlanLevel.jalan => 80.0,
    PlanLevel.fiveK => 100.0,
  };
  final asasEnd = (weeks * 0.4).round();
  final enduranceEnd = (weeks * 0.75).round();
  final result = <PlanWeek>[];

  for (var week = 1; week <= weeks; week++) {
    final isTest = week == weeks;
    final isLight = !isTest && week % 4 == 0;
    final phase = isTest
        ? PlanPhase.ujian
        : week <= asasEnd
        ? PlanPhase.asas
        : week <= enduranceEnd
        ? PlanPhase.dayaTahan
        : PlanPhase.kelajuan;
    final sessions = <PlanSession>[];

    if (isTest) {
      sessions.add(
        const PlanSession(
          title: 'Lari mudah + langkah laju',
          minutes: 20,
          detail: 'Lari santai 15 min, kemudian 4 × 20 saat langkah laju (rehat jalan 40 saat).',
          kind: SessionKind.easy,
        ),
      );
      if (daysPerWeek == 4) {
        sessions.insert(
          0,
          const PlanSession(
            title: 'Lari mudah',
            minutes: 15,
            detail: 'Lari santai, tak perlu kejar pace. Simpan tenaga untuk hari ujian.',
            kind: SessionKind.easy,
          ),
        );
      }
      sessions.add(
        PlanSession(
          title: 'Hari ujian 5K',
          minutes: targetMinutes + 15,
          detail:
              'Panas badan 10 min. Lari 5 km - km pertama jangan laju. Sejuk badan 5 min. '
              'Sasaran ~${formatPlanPace(targetPace)}/km = bawah $targetMinutes minit.',
          kind: SessionKind.test,
        ),
      );
    } else {
      var total = base * (1 + 0.30 * (week - 1) / math.max(1, weeks - 1));
      if (isLight) total *= 0.6;
      final long = math.max(20, _round5(total * 0.4));
      final easy = math.max(15, _round5(total * 0.28));
      final quality = math.max(15, _round5(total * 0.32));

      sessions.add(_easy(easy, level));
      sessions.add(_quality(quality, phase, level, targetPace, week, isLight));
      sessions.add(_longRun(long, level));
      if (daysPerWeek == 4) {
        sessions.add(
          const PlanSession(
            title: 'Lari mudah tambahan',
            minutes: 20,
            detail: 'Lari santai 20 min. Kalau badan letih, tukar jadi jalan kaki.',
            kind: SessionKind.easy,
          ),
        );
      }
    }

    result.add(PlanWeek(number: week, phase: phase, light: isLight, sessions: sessions));
  }

  return TrainingPlan(
    title: '5K bawah $targetMinutes minit',
    level: level,
    months: months,
    daysPerWeek: daysPerWeek,
    targetMinutes: targetMinutes,
    weeks: result,
    note: 'Panduan umum, bukan nasihat perubatan. Berhenti kalau sakit dada, pening atau sesak nafas.',
  );
}

PlanSession _easy(int minutes, PlanLevel level) => PlanSession(
  title: 'Lari mudah',
  minutes: minutes,
  detail: level == PlanLevel.sifar
      ? 'Jalan 5 min, kemudian lari perlahan $minutes min. Boleh jalan bila perlu - yang penting konsisten.'
      : 'Lari $minutes min pada rentak santai. Boleh bercakap ayat penuh.',
  kind: SessionKind.easy,
);

PlanSession _longRun(int minutes, PlanLevel level) => PlanSession(
  title: 'Larian panjang',
  minutes: minutes,
  detail: level == PlanLevel.sifar
      ? 'Jalan-lari $minutes min. Jalan 5 min, lari 1 min + jalan 2 min, ulang. Habiskan dengan jalan 5 min.'
      : 'Lari $minutes min tanpa henti, lebih perlahan daripada larian mudah. Boleh jalan sekejap untuk minum.',
  kind: SessionKind.longRun,
);

PlanSession _quality(int minutes, PlanPhase phase, PlanLevel level, int targetPace, int week, bool light) {
  if (light) {
    return PlanSession(
      title: 'Lari mudah + langkah laju',
      minutes: minutes,
      detail: 'Minggu ringan. Lari mudah $minutes min, akhiri dengan 4 × 20 saat langkah laju.',
      kind: SessionKind.strides,
    );
  }

  if (phase == PlanPhase.asas) {
    if (level == PlanLevel.sifar) {
      return PlanSession(
        title: 'Jalan-lari',
        minutes: minutes,
        detail: 'Jalan 5 min. (Lari 1 min + jalan 2 min) × ${math.max(3, (minutes - 10) ~/ 3)}. Jalan 5 min.',
        kind: SessionKind.walkRun,
      );
    }
    if (level == PlanLevel.jalan) {
      return PlanSession(
        title: 'Fartlek ringan',
        minutes: minutes,
        detail: 'Panas 10 min. 6 × 1 min sedikit laju, 2 min mudah antara. Sejuk 10 min.',
        kind: SessionKind.fartlek,
      );
    }
    return PlanSession(
      title: 'Lari mudah + langkah laju',
      minutes: minutes,
      detail: 'Lari mudah $minutes min. Akhiri dengan 6 × 20 saat langkah laju (rehat jalan 40 saat).',
      kind: SessionKind.strides,
    );
  }

  if (phase == PlanPhase.dayaTahan) {
    if (level == PlanLevel.fiveK) {
      final tempo = math.max(8, minutes - 20);
      return PlanSession(
        title: 'Tempo',
        minutes: minutes,
        detail: 'Panas 10 min. $tempo min pada rentak tempo (~${formatPlanPace(targetPace + 10)}/km). Sejuk 10 min.',
        kind: SessionKind.tempo,
      );
    }
    return PlanSession(
      title: 'Fartlek',
      minutes: minutes,
      detail: 'Panas 10 min. 6 × 2 min sedikit laju, 2 min mudah. Sejuk 10 min.',
      kind: SessionKind.fartlek,
    );
  }

  if (level == PlanLevel.fiveK) {
    final sets = math.min(8, 4 + week ~/ 3);
    return PlanSession(
      title: 'Interval',
      minutes: minutes,
      detail:
          'Panas 10 min. $sets × 400 m laju (sasaran ~${formatPlanPace(targetPace - 20)}/km), '
          'rehat 90 saat jalan. Sejuk 5 min.',
      kind: SessionKind.intervals,
    );
  }
  final tempo = math.max(8, minutes - 20);
  return PlanSession(
    title: 'Tempo ringan',
    minutes: minutes,
    detail: 'Panas 10 min. $tempo min pada rentak tempo (~${formatPlanPace(targetPace + 10)}/km). Sejuk 10 min.',
    kind: SessionKind.tempo,
  );
}

int _round5(num value) => (value / 5).round() * 5;

String formatPlanPace(int secondsPerKm) {
  final minutes = secondsPerKm ~/ 60;
  final seconds = secondsPerKm % 60;
  return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
}
