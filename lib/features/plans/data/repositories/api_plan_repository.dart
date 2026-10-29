import 'package:dio/dio.dart';

import '../../domain/models/plan.dart';
import '../../domain/repositories/plan_repository.dart';

/// hono-workers /me/apps/nubi/plan-build, /plan, /active and /profil.
class ApiPlanRepository implements PlanRepository {
  ApiPlanRepository(this._dio);
  final Dio _dio;

  @override
  Future<({int limit, List<CloudPlan> items})> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/apps/nubi/plan');
    final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
    return (limit: (data['limit'] as num?)?.toInt() ?? 0, items: [for (final r in _rows(data)) _cloudPlan(r)]);
  }

  @override
  Future<BuiltPlan> build({
    required PlanKind kind,
    required Map<String, String> params,
    String? key,
    ({Map<String, String> params, List<String> progress})? previous,
    String? walkUntil,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/apps/nubi/plan-build',
        data: {
          'kind': kind.code,
          'params': params,
          'key': ?key,
          if (previous != null) 'previous': {'params': previous.params, 'progress': previous.progress},
          'walkUntil': ?walkUntil,
        },
      );
      return _builtPlan(res.data?['data'] as Map<String, dynamic>? ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode != 400) rethrow;
      final body = e.response?.data;
      final m = body is Map<String, dynamic> ? body : const <String, dynamic>{};
      throw PlanBuildFailure(
        m['error'] as String? ?? '',
        suggestMonths: (m['cadanganBulan'] as num?)?.toInt(),
        suggestWeeks: (m['cadanganMinggu'] as num?)?.toInt(),
      );
    }
  }

  @override
  Future<void> save({
    required String key,
    required int engine,
    required Map<String, String> data,
    required List<String> progress,
    String? replace,
  }) async {
    final query = replace == null ? '' : '?replace=${Uri.encodeComponent(replace)}';
    try {
      await _dio.put<Map<String, dynamic>>(
        '/me/apps/nubi/plan/${Uri.encodeComponent(key)}$query',
        data: {'engine': engine, 'data': data, 'progress': progress},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 409) rethrow;
      final body = e.response?.data;
      throw PlanQuotaFull(body is Map<String, dynamic> ? (body['limit'] as num?)?.toInt() ?? 0 : 0);
    }
  }

  @override
  Future<void> delete(String key) async {
    await _dio.delete<Map<String, dynamic>>('/me/apps/nubi/plan/${Uri.encodeComponent(key)}');
  }

  @override
  Future<({String? plan, String? walkUntil})> active() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/apps/nubi/active');
    final rows = _rows(res.data?['data']);
    final data = rows.isEmpty ? const <String, dynamic>{} : rows.first['data'] as Map<String, dynamic>? ?? const {};
    return (plan: data['plan'] as String?, walkUntil: data['jalan'] as String?);
  }

  @override
  Future<void> setActive({required String key, required int engine, String? walkUntil}) async {
    await _dio.put<Map<String, dynamic>>(
      '/me/apps/nubi/active/plan',
      data: {
        'engine': engine,
        'data': {'plan': key, 'jalan': ?walkUntil},
        'progress': <String>[],
      },
    );
  }

  @override
  Future<Map<String, String>> trainingProfile() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/apps/nubi/profil');
      final rows = _rows(res.data?['data']);
      return rows.isEmpty ? {} : _strings(rows.first['data']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return {};
      rethrow;
    }
  }
}

List<Map<String, dynamic>> _rows(Object? data) =>
    ((data as Map<String, dynamic>?)?['items'] as List? ?? const []).cast<Map<String, dynamic>>();

Map<String, String> _strings(Object? m) => {
  for (final e in (m as Map<String, dynamic>? ?? const {}).entries) e.key: '${e.value}',
};

List<String> _list(Object? l) => [for (final e in (l as List? ?? const [])) '$e'];

CloudPlan _cloudPlan(Map<String, dynamic> json) => CloudPlan(
  key: json['key'] as String,
  engine: (json['engine'] as num?)?.toInt() ?? 0,
  data: _strings(json['data']),
  progress: _list(json['progress']),
  updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
);

BuiltPlan _builtPlan(Map<String, dynamic> json) => BuiltPlan(
  engine: (json['engine'] as num?)?.toInt() ?? 0,
  key: json['key'] as String,
  params: _strings(json['params']),
  warnings: _list(json['amaran']),
  progress: json['progress'] == null ? null : _list(json['progress']),
  weeks: [
    for (final w in (json['weeks'] as List? ?? const []).cast<Map<String, dynamic>>())
      PlanWeek(
        no: (w['no'] as num?)?.toInt() ?? 0,
        phase: w['fasa'] as String? ?? '',
        light: w['ringan'] == true,
        minutes: (w['minit'] as num?)?.toInt() ?? 0,
        sessions: [
          for (final s in (w['sesi'] as List? ?? const []).cast<Map<String, dynamic>>())
            PlanSession(
              id: '${s['id']}',
              date: s['tarikh'] == null ? null : _date(s['tarikh'] as String),
              type: s['jenis'] as String? ?? '',
              minutes: (s['minit'] as num?)?.toInt() ?? 0,
              title: s['tajuk'] as String? ?? '',
              instructions: s['arahan'] as String? ?? '',
              effort: s['usaha'] as String? ?? '',
              walk: s['walk'] == true,
            ),
        ],
      ),
  ],
);

/// "YYYY-MM-DD" as a local calendar day.
DateTime _date(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}
