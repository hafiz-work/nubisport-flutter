import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/plans/domain/models/training_plan.dart';

void main() {
  test('builds a 12-week 3-day plan ending with the 5K test', () {
    final plan = build5kPlan(months: 3, level: PlanLevel.jalan, daysPerWeek: 3, targetMinutes: 30);

    expect(plan.weeks.length, 12);
    expect(plan.daysPerWeek, 3);
    expect(plan.targetPace, "6'00\"");
    expect(plan.weeks.last.phase, PlanPhase.ujian);
    expect(plan.weeks.last.sessions.any((session) => session.kind == SessionKind.test), isTrue);
    for (final week in plan.weeks) {
      expect(week.sessions, isNotEmpty);
      expect(week.minutes, greaterThan(0));
    }
  });

  test('a 4-day plan adds the extra easy session', () {
    final three = build5kPlan(months: 2, level: PlanLevel.sifar, daysPerWeek: 3, targetMinutes: 30);
    final four = build5kPlan(months: 2, level: PlanLevel.sifar, daysPerWeek: 4, targetMinutes: 30);

    expect(three.weeks.first.sessions.length, 3);
    expect(four.weeks.first.sessions.length, 4);
  });
}
