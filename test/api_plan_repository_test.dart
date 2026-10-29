import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/plans/data/repositories/api_plan_repository.dart';
import 'package:nubisport_flutter/features/plans/domain/models/plan.dart';

import 'support/fake_adapter.dart';

(ApiPlanRepository, FakeAdapter) _repo(Map<String, (int, Object)> routes) {
  final adapter = FakeAdapter(routes);
  return (ApiPlanRepository(Dio()..httpClientAdapter = adapter), adapter);
}

Map<String, Object?> _built({String? date = '2026-11-02'}) => {
  'success': true,
  'data': {
    'engine': 1,
    'key': 'pelan-5k:3-jalan--3',
    'params': {'mula': '2026-11-02'},
    'amaran': ['hati-hati'],
    'weeks': [
      {
        'no': 1,
        'fasa': 'Asas',
        'ringan': false,
        'minit': 90,
        'sesi': [
          {
            'id': 's1',
            'tarikh': date,
            'jenis': 'lari',
            'minit': 30,
            'tajuk': 'Lari santai',
            'arahan': 'Perlahan',
            'usaha': 'mudah',
            'walk': true,
          },
        ],
      },
    ],
  },
};

void main() {
  test('list parses items and limit', () async {
    final (repo, _) = _repo({
      'GET /me/apps/nubi/plan': (
        200,
        {
          'success': true,
          'data': {
            'limit': 3,
            'items': [
              {
                'key': 'pelan-10k:x',
                'engine': 1,
                'data': {'a': 'b'},
                'progress': ['s1'],
                'updatedAt': '2026-10-29T01:00:00Z',
              },
            ],
          },
        },
      ),
    });
    final r = await repo.list();
    expect(r.limit, 3);
    expect(r.items.single.key, 'pelan-10k:x');
    expect(r.items.single.data, {'a': 'b'});
    expect(r.items.single.progress, ['s1']);
    expect(r.items.single.kind, PlanKind.tenK);
  });

  test('build maps weeks and dated sessions', () async {
    final (repo, adapter) = _repo({'POST /me/apps/nubi/plan-build': (200, _built())});
    final plan = await repo.build(kind: PlanKind.fiveK, params: {'mula': '2026-11-02'});
    expect(plan.key, 'pelan-5k:3-jalan--3');
    expect(plan.warnings, ['hati-hati']);
    expect(plan.progress, isNull);
    expect(plan.sessionCount, 1);
    expect(plan.weeks.single.phase, 'Asas');
    expect(plan.weeks.single.sessions.single.date, DateTime(2026, 11, 2));
    expect(plan.weeks.single.sessions.single.walk, isTrue);
    expect(adapter.bodies['POST /me/apps/nubi/plan-build'], {
      'kind': '5k',
      'params': {'mula': '2026-11-02'},
    });
  });

  test('undated plan', () async {
    final (repo, _) = _repo({'POST /me/apps/nubi/plan-build': (200, _built(date: null))});
    final plan = await repo.build(kind: PlanKind.fiveK, params: {});
    expect(plan.weeks.single.sessions.single.date, isNull);
  });

  test('build 400 throws PlanBuildFailure with suggestion', () async {
    final (repo, _) = _repo({
      'POST /me/apps/nubi/plan-build': (400, {'success': false, 'error': 'Terlalu singkat', 'cadanganBulan': 4}),
    });
    expect(
      repo.build(kind: PlanKind.half, params: {}),
      throwsA(
        isA<PlanBuildFailure>()
            .having((e) => e.reason, 'reason', 'Terlalu singkat')
            .having((e) => e.suggestMonths, 'suggestMonths', 4),
      ),
    );
  });

  test('save sends engine/data/progress and replace', () async {
    const path = 'PUT /me/apps/nubi/plan/pelan-5k%3A3-jalan--3?replace=pelan-10k%3Ax';
    final (repo, adapter) = _repo({
      path: (200, {'success': true, 'data': {}}),
    });
    await repo.save(key: 'pelan-5k:3-jalan--3', engine: 1, data: {'a': 'b'}, progress: ['s1'], replace: 'pelan-10k:x');
    expect(adapter.bodies[path], {
      'engine': 1,
      'data': {'a': 'b'},
      'progress': ['s1'],
    });
  });

  test('save 409 throws PlanQuotaFull(limit)', () async {
    final (repo, _) = _repo({
      'PUT /me/apps/nubi/plan/k': (409, {'success': false, 'code': 'quota_full', 'limit': 3}),
    });
    expect(
      repo.save(key: 'k', engine: 1, data: {}, progress: []),
      throwsA(isA<PlanQuotaFull>().having((e) => e.limit, 'limit', 3)),
    );
  });

  test('active empty -> nulls', () async {
    final (repo, _) = _repo({
      'GET /me/apps/nubi/active': (
        200,
        {
          'success': true,
          'data': {'limit': 1, 'items': []},
        },
      ),
    });
    expect(await repo.active(), (plan: null, walkUntil: null));
  });

  test('setActive omits jalan when null', () async {
    const path = 'PUT /me/apps/nubi/active/plan';
    final (repo, adapter) = _repo({
      path: (200, {'success': true, 'data': {}}),
    });
    await repo.setActive(key: 'k', engine: 1);
    expect(adapter.bodies[path], {
      'engine': 1,
      'data': {'plan': 'k'},
      'progress': <String>[],
    });
  });

  test('trainingProfile empty -> {}', () async {
    final (repo, _) = _repo({
      'GET /me/apps/nubi/profil': (
        200,
        {
          'success': true,
          'data': {'limit': 1, 'items': []},
        },
      ),
    });
    expect(await repo.trainingProfile(), isEmpty);
  });
}
