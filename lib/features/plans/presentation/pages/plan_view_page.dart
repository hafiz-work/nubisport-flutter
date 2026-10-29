import 'dart:async';

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
  late final PlanRepository _repo = ref.read(planRepositoryProvider);
  late final ProviderContainer _container = ProviderScope.containerOf(context);
  late final ScaffoldMessengerState _messenger = ScaffoldMessenger.of(context);
  late Set<String> _done = widget.plan.progress.toSet();
  late Set<String> _saved = widget.plan.progress.toSet();
  Timer? _timer;
  int? _engine;
  bool _saving = false;

  @override
  void dispose() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      unawaited(_flush());
    }
    super.dispose();
  }

  void _toggle(String id, bool on) {
    setState(() => on ? _done.add(id) : _done.remove(id));
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), _flush);
  }

  Future<void> _flush() async {
    final engine = _engine;
    if (engine == null || _saving) return;
    final sending = {..._done};
    _saving = true;
    try {
      await _repo.save(key: widget.plan.key, engine: engine, data: widget.plan.data, progress: sending.toList());
      _saved = sending;
      _container.invalidate(cloudPlansProvider);
    } catch (_) {
      if (mounted) setState(() => _done = {..._saved});
      _messenger.showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
    } finally {
      _saving = false;
    }
  }

  Future<void> _onAction(_Action action, BuiltPlan built, ({String? plan, String? walkUntil}) active) async {
    final plan = widget.plan;
    switch (action) {
      case _Action.update:
        return AppNavigator.planBuilder(context, PlanFormArgs(existing: plan));
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
        if (ok != true) return;
        _timer?.cancel();
        await _repo.delete(plan.key);
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
        final current = DateTime.tryParse(active.walkUntil ?? '');
        final base = current != null && !current.isBefore(today) ? current : today.subtract(const Duration(days: 1));
        walkUntil = _ymd(DateTime.utc(base.year, base.month, base.day + 7));
      default:
        walkUntil = null; // set active / end walk mode
    }
    await _repo.setActive(key: plan.key, engine: built.engine, walkUntil: walkUntil);
    _container.invalidate(activePlanProvider);
  }

  @override
  Widget build(BuildContext context) {
    final built = ref.watch(builtPlanProvider(widget.plan));
    final active = ref.watch(activePlanProvider).value ?? (plan: null, walkUntil: null);
    final b = built.value;
    _engine = b?.engine;
    final readOnly = b != null && b.engine != widget.plan.engine;
    final isActive = active.plan == widget.plan.key;
    final walking = isActive && active.walkUntil != null;

    PopupMenuItem<_Action> item(_Action a, String label) => PopupMenuItem(value: a, child: Text(label));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.kind?.code.toUpperCase() ?? 'Plan'),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load this plan."),
              TextButton(onPressed: () => ref.invalidate(builtPlanProvider(widget.plan)), child: const Text('Retry')),
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
