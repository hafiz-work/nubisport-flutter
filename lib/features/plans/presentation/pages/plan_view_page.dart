import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../data/repositories/plan_repository_provider.dart';
import '../../domain/models/plan.dart';
import '../../domain/repositories/plan_repository.dart';
import '../controllers/plan_providers.dart';
import 'plan_form_page.dart';

enum _Action { setActive, walk7, walk14, extend7, endWalk, update, delete }

/// Today's date in Malaysia (UTC+8, no DST).
DateTime _malaysiaToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime.utc(now.year, now.month, now.day);
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _detail(PlanSession s) => '${s.minutes} min${s.date == null ? '' : ' · ${s.date!.day}/${s.date!.month}'}';

class PlanViewPage extends ConsumerStatefulWidget {
  const PlanViewPage({super.key, required this.plan});
  final CloudPlan plan;

  @override
  ConsumerState<PlanViewPage> createState() => _PlanViewPageState();
}

class _PlanViewPageState extends ConsumerState<PlanViewPage> {
  late final PlanRepository _repo;
  late final ProviderContainer _container;
  late ScaffoldMessengerState _messenger;

  /// Replaced by the saved plan after "Update plan", so later ticks write its params.
  late CloudPlan _plan = widget.plan;
  late Set<String> _done = widget.plan.progress.toSet();
  late Set<String> _saved = widget.plan.progress.toSet();
  Timer? _timer;
  int? _engine;
  Future<void>? _inflight;
  bool _saving = false;
  bool _deleting = false;
  bool _updating = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(planRepositoryProvider);
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _disposed = true;
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      unawaited(_flush());
    }
    super.dispose();
  }

  void _toggle(String id, bool on) {
    // A tick while updating or deleting would be overwritten by the form's save or resurrect the plan.
    if (_updating || _deleting) return;
    setState(() => on ? _done.add(id) : _done.remove(id));
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), _flush);
  }

  /// Joins the save in flight (which re-sends ticks made meanwhile) instead of starting a second one.
  Future<void> _flush() => _saving ? _inflight! : _inflight = _send();

  /// Cancels the debounce, waits for the save in flight and sends any pending ticks.
  Future<void> _settle() async {
    _timer?.cancel();
    if (_saving) await _inflight;
    if (!setEquals(_done, _saved)) await _flush();
  }

  Future<void> _send() async {
    final engine = _engine;
    if (engine == null) return;
    final sending = {..._done};
    _saving = true;
    var ok = false;
    try {
      await _repo.save(key: _plan.key, engine: engine, data: _plan.data, progress: sending.toList());
      _saved = sending;
      _container.invalidate(cloudPlansProvider);
      ok = true;
    } catch (_) {
      if (!_disposed) setState(() => _done = {..._saved});
      _messenger.showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
    } finally {
      _saving = false;
    }
    // A tick made while this save was in flight was skipped; send it now.
    if (ok && !_deleting && !setEquals(_done, _saved)) await _flush();
  }

  Future<void> _onAction(_Action action, BuiltPlan built, ({String? plan, String? walkUntil}) active) async {
    final plan = _plan;
    switch (action) {
      case _Action.update:
        _updating = true;
        final CloudPlan? saved;
        try {
          await _settle();
          if (!mounted) return;
          final current = CloudPlan(
            key: plan.key,
            engine: plan.engine,
            data: plan.data,
            progress: _saved.toList(),
            updatedAt: plan.updatedAt,
          );
          saved = await AppNavigator.planBuilder(context, PlanFormArgs(existing: current));
        } finally {
          _updating = false;
        }
        if (saved case final s? when mounted) {
          setState(() {
            _plan = s;
            _done = s.progress.toSet();
            _saved = s.progress.toSet();
          });
        }
        return;
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this plan?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        );
        if (ok != true || _deleting) return;
        // A save landing after the DELETE would bring the plan back.
        _timer?.cancel();
        _deleting = true;
        if (_saving) await _inflight;
        try {
          await _repo.delete(plan.key);
        } catch (_) {
          _deleting = false;
          if (!setEquals(_done, _saved)) unawaited(_flush());
          _messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete. Try again.")));
          return;
        }
        _container.invalidate(cloudPlansProvider);
        _container.invalidate(activePlanProvider);
        if (mounted) Navigator.of(context).pop();
        return;
      default:
    }
    final today = _malaysiaToday();
    final String? walkUntil;
    switch (action) {
      case _Action.walk7:
        walkUntil = _ymd(today.add(const Duration(days: 6)));
      case _Action.walk14:
        walkUntil = _ymd(today.add(const Duration(days: 13)));
      case _Action.extend7:
        // Parse as UTC like `today`, so a window ending today still counts in UTC+8.
        final current = DateTime.tryParse('${active.walkUntil}T00:00:00Z');
        final base = current != null && !current.isBefore(today) ? current : today.subtract(const Duration(days: 1));
        walkUntil = _ymd(DateTime.utc(base.year, base.month, base.day + 7));
      default:
        walkUntil = null; // set active / end walk mode
    }
    try {
      await _repo.setActive(key: plan.key, engine: built.engine, walkUntil: walkUntil);
    } catch (_) {
      _messenger.showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
      return;
    }
    _container.invalidate(activePlanProvider);
  }

  @override
  Widget build(BuildContext context) {
    final built = ref.watch(builtPlanProvider(_plan));
    final active = ref.watch(activePlanProvider).value ?? (plan: null, walkUntil: null);
    final b = built.value;
    _engine = b?.engine;
    final readOnly = b != null && b.engine != _plan.engine;
    final isActive = active.plan == _plan.key;
    final walking = isActive && active.walkUntil != null;

    PopupMenuItem<_Action> item(_Action a, String label) => PopupMenuItem(value: a, child: Text(label));

    return Scaffold(
      appBar: AppBar(
        title: Text(_plan.kind?.code.toUpperCase() ?? 'Plan'),
        actions: [
          if (b != null)
            PopupMenuButton<_Action>(
              onSelected: (a) => _onAction(a, b, active),
              itemBuilder: (_) => readOnly
                  ? [item(_Action.delete, 'Delete')]
                  : [
                      if (!isActive) item(_Action.setActive, 'Set as active'),
                      if (isActive) ...[
                        if (!walking) ...[
                          item(_Action.walk7, 'Walk mode 7 days'),
                          item(_Action.walk14, 'Walk mode 14 days'),
                        ] else ...[
                          item(_Action.extend7, 'Extend 7 days'),
                          item(_Action.endWalk, 'End walk mode'),
                        ],
                      ],
                      item(_Action.update, 'Update plan'),
                      item(_Action.delete, 'Delete'),
                    ],
            ),
        ],
      ),
      body: built.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load this plan."),
              TextButton(onPressed: () => ref.invalidate(builtPlanProvider(_plan)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (plan) => ListView(
          children: [
            if (readOnly)
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('This plan was made with an older version. Open it on the web to continue.'),
              ),
            for (final w in plan.weeks)
              ExpansionTile(
                title: Text('Week ${w.no} · ${w.phase}'),
                subtitle: w.light ? const Text('Light') : null,
                children: [
                  for (final s in w.sessions)
                    if (readOnly)
                      ListTile(title: Text(s.title), subtitle: Text(_detail(s)))
                    else
                      CheckboxListTile(
                        value: _done.contains(s.id),
                        onChanged: (v) => _toggle(s.id, v ?? false),
                        title: Text(s.title),
                        subtitle: Text(_detail(s)),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
