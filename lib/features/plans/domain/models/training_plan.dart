import 'dart:math' as math;

enum PlanLevel { sifar, jalan, fiveK }

enum PlanPhase { asas, dayaTahan, kelajuan, ujian }

enum SessionKind { easy, walkRun, strides, fartlek, intervals, tempo, longRun, test }

extension PlanLevelLabel on PlanLevel {
  String get label => switch (this) {
    PlanLevel.sifar => 'Can\'t run 1 km yet',
    PlanLevel.jalan => 'Can walk-run 5 km',
    PlanLevel.fiveK => 'Can run 5 km continuously',
  };
}

extension PlanPhaseLabel on PlanPhase {
  String get label => switch (this) {
    PlanPhase.asas => 'Base',
    PlanPhase.dayaTahan => 'Endurance',
    PlanPhase.kelajuan => 'Speed',
    PlanPhase.ujian => 'Test',
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
          title: 'Easy run + strides',
          minutes: 20,
          detail: 'Easy run 15 min, then 4 × 20 sec strides (40 sec walk recovery).',
          kind: SessionKind.easy,
        ),
      );
      if (daysPerWeek == 4) {
        sessions.insert(
          0,
          const PlanSession(
            title: 'Easy run',
            minutes: 15,
            detail: 'Easy run, no need to chase pace. Save energy for test day.',
            kind: SessionKind.easy,
          ),
        );
      }
      sessions.add(
        PlanSession(
          title: '5K test day',
          minutes: targetMinutes + 15,
          detail:
              'Warm up 10 min. Run 5 km - don\'t go fast in the first km. Cool down 5 min. '
              'Target ~${formatPlanPace(targetPace)}/km = under $targetMinutes minutes.',
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
            title: 'Extra easy run',
            minutes: 20,
            detail: 'Easy run 20 min. If you feel tired, switch to walking.',
            kind: SessionKind.easy,
          ),
        );
      }
    }

    result.add(PlanWeek(number: week, phase: phase, light: isLight, sessions: sessions));
  }

  return TrainingPlan(
    title: '5K under $targetMinutes minutes',
    level: level,
    months: months,
    daysPerWeek: daysPerWeek,
    targetMinutes: targetMinutes,
    weeks: result,
    note: 'General guidance, not medical advice. Stop if you have chest pain, dizziness or shortness of breath.',
  );
}

PlanSession _easy(int minutes, PlanLevel level) => PlanSession(
  title: 'Easy run',
  minutes: minutes,
  detail: level == PlanLevel.sifar
      ? 'Walk 5 min, then jog slowly for $minutes min. Walk when needed - consistency matters.'
      : 'Run $minutes min at an easy pace. You should be able to hold a conversation.',
  kind: SessionKind.easy,
);

PlanSession _longRun(int minutes, PlanLevel level) => PlanSession(
  title: 'Long run',
  minutes: minutes,
  detail: level == PlanLevel.sifar
      ? 'Walk-run $minutes min. Walk 5 min, run 1 min + walk 2 min, repeat. Finish with 5 min walking.'
      : 'Run $minutes min continuously, slower than an easy run. Walk briefly to drink if needed.',
  kind: SessionKind.longRun,
);

PlanSession _quality(int minutes, PlanPhase phase, PlanLevel level, int targetPace, int week, bool light) {
  if (light) {
    return PlanSession(
      title: 'Easy run + strides',
      minutes: minutes,
      detail: 'Light week. Easy run $minutes min, finish with 4 × 20 sec strides.',
      kind: SessionKind.strides,
    );
  }

  if (phase == PlanPhase.asas) {
    if (level == PlanLevel.sifar) {
      return PlanSession(
        title: 'Walk-run',
        minutes: minutes,
        detail: 'Walk 5 min. (Run 1 min + walk 2 min) × ${math.max(3, (minutes - 10) ~/ 3)}. Walk 5 min.',
        kind: SessionKind.walkRun,
      );
    }
    if (level == PlanLevel.jalan) {
      return PlanSession(
        title: 'Light fartlek',
        minutes: minutes,
        detail: 'Warm up 10 min. 6 × 1 min slightly faster, 2 min easy between. Cool down 10 min.',
        kind: SessionKind.fartlek,
      );
    }
    return PlanSession(
      title: 'Easy run + strides',
      minutes: minutes,
      detail: 'Easy run $minutes min. Finish with 6 × 20 sec strides (40 sec walk recovery).',
      kind: SessionKind.strides,
    );
  }

  if (phase == PlanPhase.dayaTahan) {
    if (level == PlanLevel.fiveK) {
      final tempo = math.max(8, minutes - 20);
      return PlanSession(
        title: 'Tempo',
        minutes: minutes,
        detail: 'Warm up 10 min. $tempo min at tempo pace (~${formatPlanPace(targetPace + 10)}/km). Cool down 10 min.',
        kind: SessionKind.tempo,
      );
    }
    return PlanSession(
      title: 'Fartlek',
      minutes: minutes,
      detail: 'Warm up 10 min. 6 × 2 min slightly faster, 2 min easy. Cool down 10 min.',
      kind: SessionKind.fartlek,
    );
  }

  if (level == PlanLevel.fiveK) {
    final sets = math.min(8, 4 + week ~/ 3);
    return PlanSession(
      title: 'Interval',
      minutes: minutes,
      detail:
          'Warm up 10 min. $sets × 400 m fast (target ~${formatPlanPace(targetPace - 20)}/km), '
          '90 sec walk recovery. Cool down 5 min.',
      kind: SessionKind.intervals,
    );
  }
  final tempo = math.max(8, minutes - 20);
  return PlanSession(
    title: 'Light tempo',
    minutes: minutes,
    detail: 'Warm up 10 min. $tempo min at tempo pace (~${formatPlanPace(targetPace + 10)}/km). Cool down 10 min.',
    kind: SessionKind.tempo,
  );
}

int _round5(num value) => (value / 5).round() * 5;

String formatPlanPace(int secondsPerKm) {
  final minutes = secondsPerKm ~/ 60;
  final seconds = secondsPerKm % 60;
  return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
}
