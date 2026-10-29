import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/plan_repository_provider.dart';
import '../../domain/models/plan.dart';
import '../controllers/plan_providers.dart';

class PlanFormArgs {
  const PlanFormArgs({this.kind, this.tahap, this.raceDate = false, this.existing});
  final PlanKind? kind;
  final String? tahap;
  final bool raceDate;
  final CloudPlan? existing;
}

// Engine limits, mirrored from hono-workers engine/{plan-5k,distance-plan}.ts.
const _levels = {
  'sifar': "Can't run 1 km without stopping",
  'jalan': 'Can walk-run 5 km',
  '5k': 'Can run 5 km without stopping',
};
const _months = [2, 3, 4, 6];
const _distanceWeeks = {
  PlanKind.tenK: [8, 10, 12, 14, 16],
  PlanKind.half: [12, 16, 20, 24],
  PlanKind.full: [16, 18, 20, 24],
};
const _defaultWeeks = {PlanKind.tenK: 10, PlanKind.half: 16, PlanKind.full: 18};
// Prerequisite time (minutes) and target time range per distance.
const _timeRange = {
  PlanKind.fiveK: (15, 60),
  PlanKind.tenK: (15, 60),
  PlanKind.half: (35, 110),
  PlanKind.full: (80, 210),
};
const _targetRange = {PlanKind.tenK: (35, 120), PlanKind.half: (75, 240), PlanKind.full: (160, 480)};
const _profileMasa = {
  PlanKind.fiveK: 'masa5k',
  PlanKind.tenK: 'masa5k',
  PlanKind.half: 'masa10k',
  PlanKind.full: 'masa21k',
};
// Params this form sets; on update every other saved param (umur, keadaan, maf...) is kept.
const _formKeys = {'hari', 'tahap', 'masa', 'pace', 'sasaran', 'lumba', 'mula', 'bulan', 'minggu'};
const _raceKinds = {PlanKind.fiveK: '5K', PlanKind.tenK: '10K', PlanKind.half: '21K', PlanKind.full: '42K'};

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PlanFormPage extends ConsumerStatefulWidget {
  const PlanFormPage({super.key, this.args = const PlanFormArgs()});
  final PlanFormArgs args;

  @override
  ConsumerState<PlanFormPage> createState() => _PlanFormPageState();
}

class _PlanFormPageState extends ConsumerState<PlanFormPage> {
  final _masa = TextEditingController();
  final _pace = TextEditingController();
  final _sasaran = TextEditingController();
  late PlanKind _kind;
  late String _tahap;
  late bool _race;
  int _bulan = 3;
  int? _weeks;
  int _hari = 3;
  bool _pemula = false;
  DateTime? _lumba;
  DateTime? _mula;
  Map<String, String> _profile = const {};
  String? _autoMasa;

  String? _error;
  PlanBuildFailure? _failure;
  BuiltPlan? _built;
  bool _busy = false;

  CloudPlan? get _existing => widget.args.existing;
  bool get _is5k => _kind == PlanKind.fiveK;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    final d = _existing?.data ?? const <String, String>{};
    _kind = _existing?.kind ?? a.kind ?? (a.raceDate ? PlanKind.half : PlanKind.tenK);
    _tahap = d['tahap'] ?? a.tahap ?? 'jalan';
    _race = a.raceDate || d['lumba'] != null;
    _hari = int.tryParse(d['hari'] ?? '') ?? 3;
    _lumba = DateTime.tryParse(d['lumba'] ?? '');
    _mula = DateTime.tryParse(d['mula'] ?? '');
    _masa.text = d['masa'] ?? '';
    _sasaran.text = d['sasaran'] ?? '';
    final pace = int.tryParse(d['pace'] ?? '');
    if (pace != null) _pace.text = '${pace ~/ 60}:${(pace % 60).toString().padLeft(2, '0')}';
    final bulan = d['bulan'] ?? '';
    if (bulan.endsWith('w')) {
      _weeks = int.tryParse(bulan.substring(0, bulan.length - 1));
    } else if (int.tryParse(bulan) != null) {
      _bulan = int.parse(bulan);
    } else if (_is5k && a.tahap == 'sifar') {
      _bulan = 4; // the web's default for beginners (~16 weeks)
    }
    _weeks = int.tryParse(d['minggu'] ?? '') ?? _weeks;
    if (!_is5k) _weeks ??= _defaultWeeks[_kind];
    // A distance plan saved without a current time was made as a beginner.
    _pemula = _existing != null && !_is5k && d['masa'] == null;
    if (_existing == null) _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ref.read(planRepositoryProvider).trainingProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        final hari = int.tryParse(p['hari'] ?? '');
        if (hari == 3 || hari == 4) _hari = hari!;
        _prefillMasa();
      });
    } catch (_) {} // prefill is a convenience only
  }

  /// Fills masa from the profile unless the user typed something else.
  void _prefillMasa() {
    if (_masa.text.isNotEmpty && _masa.text != _autoMasa) return;
    _autoMasa = _profile[_profileMasa[_kind]];
    _masa.text = _autoMasa ?? '';
  }

  @override
  void dispose() {
    _masa.dispose();
    _pace.dispose();
    _sasaran.dispose();
    super.dispose();
  }

  void _changed(VoidCallback f) => setState(() {
    f();
    _built = null;
    _failure = null;
    _error = null;
  });

  int? _paceSeconds() {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_pace.text.trim());
    return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
  }

  /// Returns the params to send, or sets [_error].
  Map<String, String>? _params() {
    String? err;
    final p = {...?_existing?.data}
      ..removeWhere((k, _) => _formKeys.contains(k))
      ..['hari'] = '$_hari';
    if (_is5k) {
      p['tahap'] = _tahap;
      final masa = int.tryParse(_masa.text.trim());
      final (lo, hi) = _timeRange[_kind]!;
      if (_tahap != 'sifar' && _masa.text.trim().isNotEmpty) {
        if (masa == null || masa < lo || masa > hi) err = '5K time must be $lo-$hi minutes.';
        p['masa'] = '$masa';
      } else if (_tahap == '5k') {
        err = 'Enter your current 5K time.';
      }
      if (_pace.text.trim().isNotEmpty) {
        final s = _paceSeconds();
        if (s == null || s < 240 || s > 540) {
          err ??= 'Target pace must be 4:00-9:00 per km (m:ss).';
        } else {
          p['pace'] = '$s';
        }
      }
    } else {
      if (!_pemula) {
        final masa = int.tryParse(_masa.text.trim());
        final (lo, hi) = _timeRange[_kind]!;
        if (masa == null || masa < lo || masa > hi) err = 'Your current time must be $lo-$hi minutes.';
        p['masa'] = '$masa';
      }
      if (_sasaran.text.trim().isNotEmpty) {
        final s = int.tryParse(_sasaran.text.trim());
        final (lo, hi) = _targetRange[_kind]!;
        if (s == null || s < lo || s > hi) {
          err ??= 'Target time must be $lo-$hi minutes.';
        } else {
          p['sasaran'] = '$s';
        }
      }
    }
    if (_race) {
      // The API turns lumba (+ mula) into minggu and mula; the saved plan uses its returned params.
      final lumba = _lumba;
      if (lumba == null) {
        err ??= 'Pick the race date.';
      } else {
        p['lumba'] = _iso(lumba);
        if (_mula != null) p['mula'] = _iso(_mula!);
      }
    } else {
      if (_mula != null) p['mula'] = _iso(_mula!);
      if (_is5k && _weeks == null) {
        p['bulan'] = '$_bulan';
      } else {
        p['minggu'] = '${_weeks ?? _defaultWeeks[_kind]}';
      }
    }
    setState(() => _error = err);
    return err == null ? p : null;
  }

  Future<void> _preview() async {
    final p = _params();
    if (p == null) return;
    setState(() {
      _busy = true;
      _built = null;
      _failure = null;
    });
    final existing = _existing;
    try {
      final built = await ref
          .read(planRepositoryProvider)
          .build(
            kind: _kind,
            params: p,
            key: existing?.key,
            previous: existing == null ? null : (params: existing.data, progress: existing.progress),
          );
      if (mounted) setState(() => _built = built);
    } on PlanBuildFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({String? replace}) async {
    final b = _built;
    if (b == null) return;
    final repo = ref.read(planRepositoryProvider);
    setState(() => _busy = true);
    try {
      var built = b;
      var previous = _existing;
      if (previous == null) {
        // Same key as a saved plan (the key ignores dates): keep and remap its ticks, like the web.
        previous = (await repo.list()).items.where((i) => i.key == b.key).firstOrNull;
        if (previous != null) {
          built = await repo.build(
            kind: _kind,
            params: b.params,
            key: b.key,
            previous: (params: previous.data, progress: previous.progress),
          );
        }
      }
      final saved = CloudPlan(
        key: built.key,
        engine: built.engine,
        data: built.params,
        progress: built.progress ?? previous?.progress ?? const [],
        updatedAt: DateTime.now(),
      );
      await repo.save(
        key: saved.key,
        engine: saved.engine,
        data: saved.data,
        progress: saved.progress,
        replace: replace,
      );
      ref.invalidate(cloudPlansProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } on PlanQuotaFull catch (q) {
      final items = (await repo.list()).items;
      if (!mounted) return;
      final key = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text('Cloud full (${items.length}/${q.limit}). Replace a plan:'),
          children: [
            for (final i in items)
              SimpleDialogOption(
                onPressed: () => Navigator.of(c).pop(i.key),
                child: Text(
                  [
                    i.kind?.code.toUpperCase() ?? i.key,
                    if (i.data['mula'] case final m?) 'from $m' else if (i.data['minggu'] case final w?) '$w weeks',
                  ].join(' · '),
                ),
              ),
          ],
        ),
      );
      if (key != null) {
        if (mounted) setState(() => _busy = false);
        return _save(replace: key);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the plan. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
  }

  Widget _chips<T>(String label, List<T> values, T? selected, String Function(T) text, void Function(T) onTap) =>
      _Group(
        label,
        Wrap(
          spacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                key: ValueKey('$label-$v'),
                label: Text(text(v)),
                selected: v == selected,
                onSelected: (_) => _changed(() => onTap(v)),
              ),
          ],
        ),
      );

  Widget _date(String label, DateTime? value, void Function(DateTime?) set, {bool clearable = false}) => _Group(
    label,
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: ValueKey(label),
            onPressed: () async {
              final d = await _pickDate(value);
              if (d != null) _changed(() => set(d));
            },
            child: Text(value == null ? 'Pick a date' : _iso(value)),
          ),
        ),
        if (clearable && value != null)
          IconButton(onPressed: () => _changed(() => set(null)), icon: const Icon(Icons.clear)),
      ],
    ),
  );

  Widget _field(String label, TextEditingController c, {String? hint, Key? key}) => _Group(
    label,
    TextField(
      key: key,
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
      onChanged: (_) => _changed(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = _existing;
    final built = _built;
    final tahapOptions = widget.args.tahap == '5k'
        ? ['5k']
        : (widget.args.tahap == 'sifar' ? ['sifar', 'jalan'] : _levels.keys.toList());
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New plan' : 'Update plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (existing == null && widget.args.kind == null)
            _chips<PlanKind>(
              'Distance',
              widget.args.raceDate ? _raceKinds.keys.toList() : [PlanKind.tenK, PlanKind.half, PlanKind.full],
              _kind,
              (k) => _raceKinds[k]!,
              (k) {
                _kind = k;
                _weeks = _is5k ? null : _defaultWeeks[k];
                _prefillMasa();
              },
            ),
          if (_is5k && tahapOptions.length > 1)
            _chips<String>('Current level', tahapOptions, _tahap, (t) => _levels[t]!, (t) => _tahap = t),
          if (_race)
            _date('Race date', _lumba, (d) => _lumba = d)
          else if (_is5k)
            _chips<int>('Duration', _months, _weeks == null ? _bulan : null, (m) => '$m months', (m) {
              _bulan = m;
              _weeks = null;
            })
          else
            _chips<int>('Duration', _distanceWeeks[_kind]!, _weeks, (w) => '$w weeks', (w) => _weeks = w),
          if (!_is5k)
            CheckboxListTile(
              key: const ValueKey('pemula'),
              contentPadding: EdgeInsets.zero,
              title: const Text("I'm a beginner - I don't know my time yet"),
              value: _pemula,
              onChanged: (v) => _changed(() => _pemula = v ?? false),
            ),
          if (_is5k ? _tahap != 'sifar' : !_pemula)
            _field(
              _is5k
                  ? 'Current 5K time (minutes)'
                  : 'Current ${_kind == PlanKind.tenK
                        ? '5K'
                        : _kind == PlanKind.half
                        ? '10K'
                        : '21K'} time (minutes)',
              _masa,
              key: const ValueKey('masa'),
            ),
          if (_is5k)
            _field('Target pace per km (optional, m:ss)', _pace, hint: 'e.g. 5:36', key: const ValueKey('pace'))
          else
            _field('Target time (minutes, optional)', _sasaran, key: const ValueKey('sasaran')),
          _chips<int>('Days per week', const [3, 4], _hari, (h) => '$h days', (h) => _hari = h),
          _date('Start date (optional)', _mula, (d) => _mula = d, clearable: true),
          if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          if (_failure case final f?) ...[
            Text(f.reason, style: TextStyle(color: theme.colorScheme.error)),
            if (f.suggestMonths case final m?)
              TextButton(
                onPressed: () {
                  _changed(() {
                    _race = false;
                    _bulan = m;
                    _weeks = null;
                  });
                  _preview();
                },
                child: Text('Use $m months'),
              ),
            if (f.suggestWeeks case final w? when !(_race && _is5k))
              TextButton(
                onPressed: () {
                  _changed(() {
                    _race = false;
                    _weeks = w;
                  });
                  _preview();
                },
                child: Text('Use $w weeks'),
              ),
          ],
          if (built != null) ...[
            Text('${built.weeks.length} weeks, ${built.sessionCount} sessions', style: theme.textTheme.titleMedium),
            for (final w in built.warnings) Text(w),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _preview, child: const Text('Preview')),
          if (built != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
