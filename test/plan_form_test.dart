import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/navigation/app_router.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/plans/data/repositories/plan_repository_provider.dart';
import 'package:nubisport_flutter/features/plans/domain/models/plan.dart';
import 'package:nubisport_flutter/features/plans/domain/repositories/plan_repository.dart';
import 'package:nubisport_flutter/features/plans/presentation/pages/plan_form_page.dart';
import 'package:nubisport_flutter/features/plans/presentation/pages/training_plans_page.dart';

class FakeRepo implements PlanRepository {
  FakeRepo({this.profile = const {}, this.items = const []});
  final Map<String, String> profile;
  final List<CloudPlan> items;
  Object? buildError;
  Object? saveError;
  bool noProgress = false;
  Map<String, String> Function(Map<String, String>)? respond;
  final builds = <Map<String, String>>[];
  final saves = <({List<String> progress, String? replace, Map<String, String> data})>[];
  ({Map<String, String> params, List<String> progress})? lastPrevious;

  @override
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    String? key,
    ({Map<String, String> params, List<String> progress})? previous,
    String? walkUntil,
  }) async {
    builds.add(params);
    lastPrevious = previous;
    final e = buildError;
    if (e != null) {
      buildError = null;
      throw e;
    }
    PlanSession s(String id) => PlanSession(
      id: id,
      date: null,
      type: 'run',
      minutes: 30,
      title: 't',
      instructions: '',
      effort: 'easy',
      walk: false,
    );
    return BuiltPlan(
      engine: 1,
      key: key ?? 'pelan-${kind.code}:x',
      params: respond?.call(params) ?? params,
      warnings: const ['careful'],
      progress: previous == null || noProgress ? null : ['remapped'],
      weeks: [
        PlanWeek(no: 1, phase: 'p', light: false, minutes: 60, sessions: [s('1.0'), s('1.1')]),
        PlanWeek(no: 2, phase: 'p', light: false, minutes: 60, sessions: [s('2.0')]),
      ],
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
    final e = saveError;
    if (e != null && replace == null) throw e;
    saves.add((progress: progress, replace: replace, data: data));
  }

  @override
  Future<({int limit, List<CloudPlan> items})> list() async => (limit: 1, items: items);
  @override
  Future<void> delete(String key) async {}
  @override
  Future<({String? plan, String? walkUntil})> active() async => (plan: null, walkUntil: null);
  @override
  Future<void> setActive({required String key, required int engine, String? walkUntil}) async {}
  @override
  Future<Map<String, String>> trainingProfile() async => profile;
}

Widget app(FakeRepo repo, Widget home) => ProviderScope(
  overrides: [planRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(theme: AppTheme.dark, onGenerateRoute: AppRouter.onGenerateRoute, home: home),
);

Future<void> open(WidgetTester t, FakeRepo repo, PlanFormArgs args) async {
  t.view.physicalSize = const Size(600, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(app(repo, PlanFormPage(args: args)));
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text));
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

const fiveK = PlanFormArgs(kind: PlanKind.fiveK, tahap: '5k');

void main() {
  testWidgets('5k preview shows session count', (t) async {
    final repo = FakeRepo();
    await open(t, repo, fiveK);
    await t.enterText(find.byKey(const ValueKey('masa')), '30');
    await tapText(t, 'Preview');
    expect(find.text('2 weeks, 3 sessions'), findsOneWidget);
    expect(find.text('careful'), findsOneWidget);
    expect(repo.builds.single, {'tahap': '5k', 'bulan': '3', 'hari': '3', 'masa': '30'});
  });

  testWidgets('engine refusal shows reason and suggestion button', (t) async {
    final repo = FakeRepo()..buildError = const PlanBuildFailure('Terlalu singkat', suggestMonths: 4);
    await open(t, repo, fiveK);
    await t.enterText(find.byKey(const ValueKey('masa')), '30');
    await tapText(t, 'Preview');
    expect(find.text('Terlalu singkat'), findsOneWidget);
    await tapText(t, 'Use 4 months');
    expect(repo.builds.last['bulan'], '4');
    expect(find.text('2 weeks, 3 sessions'), findsOneWidget);
  });

  testWidgets('save new plan sends empty progress', (t) async {
    final repo = FakeRepo();
    await open(t, repo, fiveK);
    await t.enterText(find.byKey(const ValueKey('masa')), '30');
    await tapText(t, 'Preview');
    await tapText(t, 'Save');
    expect(repo.saves.single.progress, isEmpty);
    expect(repo.saves.single.replace, isNull);
  });

  testWidgets('update sends remapped progress', (t) async {
    final repo = FakeRepo();
    final existing = CloudPlan(
      key: 'pelan-5k:3:5k:30:3',
      engine: 1,
      data: const {'tahap': '5k', 'bulan': '3', 'hari': '3', 'masa': '30'},
      progress: const ['1.0'],
      updatedAt: DateTime(2026, 10, 1),
    );
    await open(t, repo, PlanFormArgs(kind: PlanKind.fiveK, existing: existing));
    expect(find.widgetWithText(TextField, '30'), findsOneWidget);
    await tapText(t, 'Preview');
    expect(repo.lastPrevious?.progress, ['1.0']);
    await tapText(t, 'Save');
    expect(repo.saves.single.progress, ['remapped']);
  });

  testWidgets('quota full offers replace', (t) async {
    final other = CloudPlan(
      key: 'pelan-10k:old',
      engine: 1,
      data: const {'mula': '2026-11-02'},
      progress: const [],
      updatedAt: DateTime(2026, 10, 1),
    );
    final repo = FakeRepo(items: [other])..saveError = const PlanQuotaFull(1);
    await open(t, repo, fiveK);
    await t.enterText(find.byKey(const ValueKey('masa')), '30');
    await tapText(t, 'Preview');
    await tapText(t, 'Save');
    expect(find.textContaining('Cloud full (1/1)'), findsOneWidget);
    await t.tap(find.text('10K · from 2026-11-02'));
    await t.pumpAndSettle();
    expect(repo.saves.single.replace, 'pelan-10k:old');
  });

  testWidgets('pemula hides masa and does not send it', (t) async {
    final repo = FakeRepo();
    await open(t, repo, const PlanFormArgs(kind: PlanKind.tenK));
    expect(find.byKey(const ValueKey('masa')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('pemula')));
    await t.tap(find.byKey(const ValueKey('pemula')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('masa')), findsNothing);
    await tapText(t, 'Preview');
    expect(repo.builds.single.containsKey('masa'), isFalse);
    expect(repo.builds.single.containsKey('pemula'), isFalse);
    expect(repo.builds.single['minggu'], '10');
  });

  testWidgets('prefills hari and masa from training profile', (t) async {
    final repo = FakeRepo(profile: {'hari': '4', 'masa5k': '28', 'masa10k': '55'});
    await open(t, repo, const PlanFormArgs(kind: PlanKind.half));
    expect(find.widgetWithText(TextField, '55'), findsOneWidget);
    await tapText(t, 'Preview');
    expect(repo.builds.single['hari'], '4');
    expect(repo.builds.single['masa'], '55');
  });

  testWidgets('race plan requires a race date', (t) async {
    final repo = FakeRepo();
    await open(t, repo, const PlanFormArgs(raceDate: true));
    await tapText(t, '5K');
    await t.tap(find.byKey(const ValueKey('masa')));
    await t.enterText(find.byKey(const ValueKey('masa')), '30');
    await tapText(t, 'Preview');
    // no race date picked yet: nothing is built
    expect(repo.builds, isEmpty);
    expect(find.text('Pick the race date.'), findsOneWidget);
  });

  Future<void> pickRace(WidgetTester t) async {
    await tapText(t, '5K');
    await t.enterText(find.byKey(const ValueKey('masa')), '33');
    await t.ensureVisible(find.byKey(const ValueKey('Race date')));
    await t.tap(find.byKey(const ValueKey('Race date')));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.edit_outlined));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '01/20/2027');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
  }

  testWidgets('race date happy path sends lumba only and saves the built params', (t) async {
    final repo = FakeRepo()..respond = (p) => {...p, 'mula': '2026-11-06', 'minggu': '11', 'bulan': '11w'};
    await open(t, repo, const PlanFormArgs(raceDate: true));
    await pickRace(t);
    await tapText(t, 'Preview');
    expect(repo.builds.single, {'tahap': 'jalan', 'hari': '3', 'masa': '33', 'lumba': '2027-01-20'});
    await tapText(t, 'Save');
    expect(repo.saves.single.data['minggu'], '11');
    expect(repo.saves.single.data['mula'], '2026-11-06');
    expect(repo.saves.single.data['bulan'], '11w');
  });

  testWidgets('5k race refusal offers no weeks suggestion', (t) async {
    final repo = FakeRepo()..buildError = const PlanBuildFailure('Terlalu singkat', suggestWeeks: 12);
    await open(t, repo, const PlanFormArgs(raceDate: true));
    await pickRace(t);
    await tapText(t, 'Preview');
    expect(find.text('Terlalu singkat'), findsOneWidget);
    expect(find.textContaining('Use 12 weeks'), findsNothing);
  });

  testWidgets('update keeps existing ticks when the API cannot remap', (t) async {
    final repo = FakeRepo()..noProgress = true;
    final existing = CloudPlan(
      key: 'pelan-5k:3:5k:30:3',
      engine: 1,
      data: const {'tahap': '5k', 'bulan': '3', 'hari': '3', 'masa': '30'},
      progress: const ['1.0', '2.1'],
      updatedAt: DateTime(2026, 10, 1),
    );
    await open(t, repo, PlanFormArgs(kind: PlanKind.fiveK, existing: existing));
    await tapText(t, 'Preview');
    await tapText(t, 'Save');
    expect(repo.saves.single.progress, ['1.0', '2.1']);
  });

  testWidgets('catalog cards open the form with mapped args', (t) async {
    final repo = FakeRepo();
    t.view.physicalSize = const Size(600, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(app(repo, const TrainingPlansPage()));
    await t.pumpAndSettle();
    Future<PlanFormArgs> go(String title) async {
      await t.ensureVisible(find.byKey(ValueKey('explore-$title')));
      await t.tap(find.byKey(ValueKey('explore-$title')));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      final args = t.widget<PlanFormPage>(find.byType(PlanFormPage)).args;
      Navigator.of(t.element(find.byType(PlanFormPage))).pop();
      await t.pumpAndSettle();
      return args;
    }

    var a = await go('Race');
    expect((a.raceDate, a.kind, a.tahap), (true, null, null));
    a = await go('5k improvement plan');
    expect((a.raceDate, a.kind, a.tahap), (false, PlanKind.fiveK, '5k'));
    a = await go('Start running');
    expect((a.raceDate, a.kind, a.tahap), (false, PlanKind.fiveK, 'sifar'));
    a = await go('Distance Plans');
    expect((a.raceDate, a.kind, a.tahap), (false, null, null));
  });

  testWidgets('new plan with the key of a saved plan keeps and remaps its ticks', (t) async {
    final same = CloudPlan(
      key: 'pelan-5k:x',
      engine: 1,
      data: const {'tahap': '5k', 'bulan': '3', 'hari': '3', 'masa': '30', 'mula': '2026-10-01'},
      progress: const ['1.0'],
      updatedAt: DateTime(2026, 10, 1),
    );
    final repo = FakeRepo(items: [same]);
    await open(t, repo, fiveK);
    await t.enterText(find.byKey(const ValueKey('masa')), '30');
    await tapText(t, 'Preview');
    await tapText(t, 'Save');
    expect(repo.lastPrevious?.progress, ['1.0']);
    expect(repo.lastPrevious?.params['mula'], '2026-10-01');
    expect(repo.saves.single.progress, ['remapped']);
  });

  testWidgets('update keeps params the form does not show', (t) async {
    final repo = FakeRepo();
    final existing = CloudPlan(
      key: 'pelan-5k:3:5k:30:3',
      engine: 1,
      data: const {'tahap': '5k', 'bulan': '3', 'hari': '3', 'masa': '30', 'umur': '30', 'keadaan': 'konsisten'},
      progress: const [],
      updatedAt: DateTime(2026, 10, 1),
    );
    await open(t, repo, PlanFormArgs(kind: PlanKind.fiveK, existing: existing));
    await tapText(t, '4 days');
    await tapText(t, 'Preview');
    expect(repo.builds.single, {
      'tahap': '5k',
      'bulan': '3',
      'hari': '4',
      'masa': '30',
      'umur': '30',
      'keadaan': 'konsisten',
    });
    await tapText(t, 'Save');
    expect(repo.saves.single.data['umur'], '30');
  });

  testWidgets('update of a beginner distance plan starts as beginner', (t) async {
    final repo = FakeRepo();
    final existing = CloudPlan(
      key: 'pelan-10k:10-0--3',
      engine: 1,
      data: const {'minggu': '10', 'hari': '3', 'jarak': '10k'},
      progress: const [],
      updatedAt: DateTime(2026, 10, 1),
    );
    await open(t, repo, PlanFormArgs(existing: existing));
    expect(find.byKey(const ValueKey('masa')), findsNothing);
    await tapText(t, 'Preview');
    expect(repo.builds.single.containsKey('masa'), isFalse);
  });
}
