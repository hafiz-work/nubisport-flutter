import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/navigation/app_router.dart';
import 'package:nubisport_flutter/core/navigation/app_routes.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/plans/data/repositories/plan_repository_provider.dart';
import 'package:nubisport_flutter/features/plans/domain/models/plan.dart';
import 'package:nubisport_flutter/features/plans/domain/repositories/plan_repository.dart';
import 'package:nubisport_flutter/features/plans/presentation/pages/plan_view_page.dart';
import 'package:nubisport_flutter/features/plans/presentation/pages/training_plans_page.dart';

class FakeRepo implements PlanRepository {
  FakeRepo({
    this.plans = const [],
    this.activeKey,
    this.builtEngine = 1,
    this.undated = false,
  });
  final List<CloudPlan> plans;
  final String? activeKey;
  final int builtEngine;
  final bool undated;
  bool failSave = false;
  Future<void> Function()? onSave;
  final saves = <List<String>>[];

  @override
  Future<({int limit, List<CloudPlan> items})> list() async =>
      (limit: 3, items: plans);

  @override
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    String? key,
    ({Map<String, String> params, List<String> progress})? previous,
    String? walkUntil,
  }) async => BuiltPlan(
    engine: builtEngine,
    key: key ?? 'k',
    params: params,
    warnings: const [],
    progress: null,
    weeks: [
      PlanWeek(
        no: 1,
        phase: 'Base',
        light: true,
        minutes: 60,
        sessions: [
          PlanSession(
            id: '1.0',
            date: undated ? null : DateTime(2026, 11, 3),
            type: 'run',
            minutes: 30,
            title: 'Easy run',
            instructions: '',
            effort: 'easy',
            walk: false,
          ),
          PlanSession(
            id: '1.1',
            date: null,
            type: 'run',
            minutes: 20,
            title: 'Second run',
            instructions: '',
            effort: 'easy',
            walk: false,
          ),
        ],
      ),
    ],
  );

  @override
  Future<void> save({
    required String key,
    required int engine,
    required Map<String, String> data,
    required List<String> progress,
    String? replace,
  }) async {
    if (failSave) throw Exception('boom');
    saves.add(progress);
    await onSave?.call();
  }

  @override
  Future<void> delete(String key) async {}

  @override
  Future<({String? plan, String? walkUntil})> active() async =>
      (plan: activeKey, walkUntil: null);

  @override
  Future<void> setActive({
    required String key,
    required int engine,
    String? walkUntil,
  }) async {}

  @override
  Future<Map<String, String>> trainingProfile() async => {};
}

CloudPlan plan({int engine = 1, List<String> progress = const []}) => CloudPlan(
  key: 'pelan-10k:a',
  engine: engine,
  data: const {},
  progress: progress,
  updatedAt: DateTime(2026, 10, 1),
);

Widget app(FakeRepo repo, Widget home) => ProviderScope(
  overrides: [planRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.dark,
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: home,
  ),
);

void main() {
  testWidgets('my plans shows quota and active chip', (tester) async {
    final p = plan(progress: ['1.0', '1.1']);
    await tester.pumpWidget(
      app(FakeRepo(plans: [p], activeKey: p.key), const TrainingPlansPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('My plans (1/3)'), findsOneWidget);
    expect(find.text('10K'), findsOneWidget);
    expect(find.text('2 sessions done'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('empty my plans still shows catalog', (tester) async {
    await tester.pumpWidget(app(FakeRepo(), const TrainingPlansPage()));
    await tester.pumpAndSettle();
    expect(find.text('No plans yet - pick one below.'), findsOneWidget);
    expect(find.text('Race'), findsOneWidget);
  });

  testWidgets('tick saves after debounce', (tester) async {
    final repo = FakeRepo();
    await tester.pumpWidget(app(repo, PlanViewPage(plan: plan())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(repo.saves, [
      ['1.0'],
    ]);
  });

  testWidgets('failed tick rolls back', (tester) async {
    final repo = FakeRepo()..failSave = true;
    await tester.pumpWidget(app(repo, PlanViewPage(plan: plan())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
  });

  testWidgets('engine mismatch is read-only', (tester) async {
    await tester.pumpWidget(
      app(FakeRepo(builtEngine: 2), PlanViewPage(plan: plan())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.text(
        'This plan was made with an older version. Open it on the web to continue.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('undated plan', (tester) async {
    await tester.pumpWidget(
      app(FakeRepo(undated: true), PlanViewPage(plan: plan())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);
  });

  testWidgets('planView route opens PlanViewPage', (tester) async {
    final p = plan();
    await tester.pumpWidget(
      app(FakeRepo(plans: [p]), const TrainingPlansPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('10K'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanViewPage), findsOneWidget);
    expect(
      AppRouter.onGenerateRoute(
        RouteSettings(name: AppRoutes.planView, arguments: p),
      ),
      isNotNull,
    );
  });

  testWidgets('pending tick is flushed once when the page is popped', (
    tester,
  ) async {
    final repo = FakeRepo();
    await tester.pumpWidget(
      app(
        repo,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanViewPage(plan: plan()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(repo.saves, [
      ['1.0'],
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tick made while a save is in flight is saved afterwards', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = FakeRepo()..onSave = () => waitFor(gate);
    await tester.pumpWidget(
      app(repo, PlanViewPage(plan: plan(), key: const ValueKey('v'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(repo.saves.length, 1);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pump(const Duration(milliseconds: 1600));
    gate.complete();
    repo.onSave = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(repo.saves.length, 2);
    expect(repo.saves.last.toSet(), {'1.0', '1.1'});
  });
}

Future<void> waitFor(Completer<void> gate) => gate.future;
