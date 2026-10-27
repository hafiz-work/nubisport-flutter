import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/training_plan.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  int _months = 3;
  PlanLevel _level = PlanLevel.jalan;
  int _target = 30;
  int _days = 3;
  TrainingPlan? _plan;
  final Set<String> _done = {};

  void _build() {
    setState(() {
      _done.clear();
      _plan = build5kPlan(months: _months, level: _level, daysPerWeek: _days, targetMinutes: _target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Training plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          _IntroCard(level: _level, targetMinutes: _target),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChipSection(
                    label: 'Duration',
                    children: [
                      for (final months in const [2, 3, 4, 6])
                        ChoiceChip(
                          label: Text('$months months'),
                          selected: _months == months,
                          onSelected: (_) => setState(() => _months = months),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ChipSection(
                    label: 'Current level',
                    children: [
                      for (final level in PlanLevel.values)
                        ChoiceChip(
                          label: Text(level.label),
                          selected: _level == level,
                          onSelected: (_) => setState(() => _level = level),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ChipSection(
                    label: '5K target',
                    children: [
                      for (final target in const [30, 28, 25])
                        ChoiceChip(
                          label: Text('Under $target minutes'),
                          selected: _target == target,
                          onSelected: (_) => setState(() => _target = target),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ChipSection(
                    label: 'Days per week',
                    children: [
                      for (final days in const [3, 4])
                        ChoiceChip(
                          label: Text('$days days'),
                          selected: _days == days,
                          onSelected: (_) => setState(() => _days = days),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _build,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(plan == null ? 'Build plan' : 'Rebuild plan'),
                  ),
                ],
              ),
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 24),
            _PlanSummary(plan: plan, done: _done.length),
            const SizedBox(height: 12),
            for (final week in plan.weeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WeekCard(
                  week: week,
                  done: _done,
                  onToggle: (key, value) => setState(() {
                    if (value) {
                      _done.add(key);
                    } else {
                      _done.remove(key);
                    }
                  }),
                ),
              ),
            const SizedBox(height: 8),
            Text(plan.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ] else ...[
            const SizedBox(height: 24),
            Text(
              'Choose duration, level, target and days per week, then tap "Build plan". '
              'Plans are stored in this app only.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.level, required this.targetMinutes});
  final PlanLevel level;
  final int targetMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1A33), Color(0xFF12264A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAINING PLAN',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            '5K under $targetMinutes minutes.',
            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Level: ${level.label}. Each week has an easy run, a quality session and a long run, '
            'with a light week every 4th week.',
            style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan, required this.done});
  final TrainingPlan plan;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = plan.sessionCount == 0 ? 0.0 : done / plan.sessionCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(plan.title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '${plan.weeks.length} weeks · ${plan.daysPerWeek} days/week · target ${plan.targetPace}/km',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Text(
              '$done / ${plan.sessionCount} sesi siap',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.done, required this.onToggle});
  final PlanWeek week;
  final Set<String> done;
  final void Function(String key, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: week.number == 1,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Row(
          children: [
            Text('Week ${week.number}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            _Tag(text: week.phase.label, highlight: week.phase == PlanPhase.ujian),
            if (week.light) ...[const SizedBox(width: 6), const _Tag(text: 'Light')],
          ],
        ),
        subtitle: Text(
          '${week.minutes} min · ${week.sessions.length} sesi',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        children: [
          for (var i = 0; i < week.sessions.length; i++)
            Builder(
              builder: (context) {
                final session = week.sessions[i];
                final key = '${week.number}-$i';
                return CheckboxListTile(
                  value: done.contains(key),
                  onChanged: (value) => onToggle(key, value ?? false),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: Icon(_kindIcon(session.kind), size: 20, color: theme.colorScheme.primary),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${session.minutes} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(session.detail, style: theme.textTheme.bodySmall),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary.withValues(alpha: 0.15) : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: highlight ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

IconData _kindIcon(SessionKind kind) => switch (kind) {
  SessionKind.easy => Icons.directions_run,
  SessionKind.walkRun => Icons.directions_walk,
  SessionKind.strides => Icons.bolt,
  SessionKind.fartlek => Icons.speed,
  SessionKind.intervals => Icons.timer_outlined,
  SessionKind.tempo => Icons.whatshot_outlined,
  SessionKind.longRun => Icons.route_outlined,
  SessionKind.test => Icons.flag_outlined,
};
