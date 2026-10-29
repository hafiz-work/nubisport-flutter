import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../../domain/models/plan.dart';
import '../controllers/plan_providers.dart';
import 'plan_form_page.dart';

class TrainingPlansPage extends ConsumerWidget {
  const TrainingPlansPage({super.key});

  /// No saved plans: just the catalog. With plans: "Plans | My plans" tabs, opening on My plans.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPlans = ref.watch(cloudPlansProvider);
    const title = Text('Training Plans');
    // Wait for the first answer so the page doesn't jump from catalog to tabs.
    if (myPlans.isLoading && !myPlans.hasValue) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final data = myPlans.value;
    if (data == null || data.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: SafeArea(
          top: false,
          child: _catalog(
            context,
            header: myPlans.hasError
                ? Row(
                    children: [
                      const Expanded(child: Text("Couldn't load your plans.")),
                      TextButton(
                        onPressed: () => ref.invalidate(cloudPlansProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Plans'),
              Tab(text: 'My plans (${data.items.length}/${data.limit})'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _catalog(context),
              _MyPlans(plans: data.items),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catalog(BuildContext context, {Widget? header}) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
    itemCount: _plans.length + (header == null ? 0 : 1),
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (context, index) {
      if (header != null && index == 0) return header;
      final plan = _plans[index - (header == null ? 0 : 1)];
      return _PlanCard(plan: plan, onTap: () => _openPlan(context, plan.kind));
    },
  );

  void _openPlan(BuildContext context, _TrainingPlanKind kind) {
    switch (kind) {
      case _TrainingPlanKind.race:
        _showRacePlan(context);
      case _TrainingPlanKind.improve5k:
        _showImprove5k(context);
      case _TrainingPlanKind.startRunning:
        _showStartRunning(context);
      case _TrainingPlanKind.general:
        _showGeneralTraining(context);
      case _TrainingPlanKind.distance:
        _showDistancePlans(context);
    }
  }

  void _showRacePlan(BuildContext context) {
    _showPlanSheet(
      context,
      content: const _RacePlanSheet(),
      onContinue: () =>
          AppNavigator.planBuilder(context, const PlanFormArgs(raceDate: true)),
    );
  }

  void _showImprove5k(BuildContext context) {
    _showPlanSheet(
      context,
      content: const _Improve5kSheet(),
      onContinue: () => AppNavigator.planBuilder(
        context,
        const PlanFormArgs(kind: PlanKind.fiveK, tahap: '5k'),
      ),
    );
  }

  void _showStartRunning(BuildContext context) {
    _showPlanSheet(
      context,
      content: const _StartRunningSheet(),
      onContinue: () => AppNavigator.planBuilder(
        context,
        const PlanFormArgs(kind: PlanKind.fiveK, tahap: 'sifar'),
      ),
    );
  }

  void _showGeneralTraining(BuildContext context) {
    _showPlanSheet(
      context,
      content: const _GeneralTrainingSheet(),
      onContinue: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('General training builder is coming soon.'),
            ),
          );
      },
    );
  }

  void _showDistancePlans(BuildContext context) {
    _showPlanSheet(
      context,
      content: const _DistancePlansSheet(),
      onContinue: () => AppNavigator.planBuilder(context),
    );
  }

  void _showPlanSheet(
    BuildContext context, {
    required Widget content,
    required VoidCallback onContinue,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screen = MediaQuery.sizeOf(context);
    FamilyModalSheet.showMaterialDefault<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      contentBackgroundColor: scheme.surface,
      builder: (sheetContext) => SizedBox(
        height: screen.height * 0.95,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: content,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onContinue();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _plans = [
  _PlanDefinition(
    kind: _TrainingPlanKind.race,
    title: 'Race',
    description: 'Build a personalized training plan for your next race.',
    badge: '21K',
    icon: Icons.flag_outlined,
    colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
    popular: true,
  ),
  _PlanDefinition(
    kind: _TrainingPlanKind.improve5k,
    title: '5k improvement plan',
    description:
        'Chase your next PR - this plan helps you to your best 5k yet.',
    badge: '5K',
    icon: Icons.trending_up,
    colors: [Color(0xFFD4A017), Color(0xFF7C4A00)],
  ),
  _PlanDefinition(
    kind: _TrainingPlanKind.startRunning,
    title: 'Start running',
    description: 'New to running? This plan guides you every step of the way.',
    badge: 'SR',
    icon: Icons.directions_run,
    colors: [Color(0xFF15803D), Color(0xFF14532D)],
  ),
  _PlanDefinition(
    kind: _TrainingPlanKind.general,
    title: 'General training',
    description: 'These plans build fitness, strength, and consistency.',
    badge: 'GT',
    icon: Icons.fitness_center,
    colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
  ),
  _PlanDefinition(
    kind: _TrainingPlanKind.distance,
    title: 'Distance Plans',
    description: 'Fully customize a plan for any distance: 5K, 10K, 21K, 42K.',
    badge: '10K',
    icon: Icons.route_outlined,
    colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
  ),
];

enum _TrainingPlanKind { race, improve5k, startRunning, general, distance }

class _PlanDefinition {
  const _PlanDefinition({
    required this.kind,
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
    required this.colors,
    this.popular = false,
  });

  final _TrainingPlanKind kind;
  final String title;
  final String description;
  final String badge;
  final IconData icon;
  final List<Color> colors;
  final bool popular;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final _PlanDefinition plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (plan.popular) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: _PopularTag(),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlanBadge(
                  label: plan.badge,
                  icon: plan.icon,
                  colors: plan.colors,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: ValueKey('explore-${plan.title}'),
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: scheme.onSurface,
                backgroundColor: scheme.surfaceContainerLowest,
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: const Text('Explore training plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularTag extends StatelessWidget {
  const _PopularTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: const Text(
        'Most popular',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.colors,
    this.icon = Icons.directions_run,
    this.size = 58,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final height = size * 1.16;
    return SizedBox(
      width: size,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, height),
            painter: _ShieldPainter(colors),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  color: Colors.white,
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Icon(icon, size: size * 0.18, color: Colors.white70),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter(this.colors);
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.9, 0)
      ..lineTo(w, h * 0.12)
      ..lineTo(w, h * 0.62)
      ..quadraticBezierTo(w, h * 0.82, w / 2, h)
      ..quadraticBezierTo(0, h * 0.82, 0, h * 0.62)
      ..lineTo(0, h * 0.12)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.45), 5, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.18),
      w * 0.46,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _RacePlanSheet extends StatelessWidget {
  const _RacePlanSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PlanBadge(
              label: '42.2',
              icon: Icons.flag_outlined,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            ),
            const SizedBox(width: 4),
            const _PlanBadge(
              label: '21.1',
              icon: Icons.flag_outlined,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
              size: 72,
            ),
            const SizedBox(width: 4),
            const _PlanBadge(
              label: '10K',
              icon: Icons.route_outlined,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            ),
          ],
        ),
        const SizedBox(height: 22),
        _Hero(
          title: 'Any race. One plan.',
          subtitle:
              'Tell us your race, and we\'ll build a plan around your ability and schedule.',
        ),
        const SizedBox(height: 24),
        const _WeekPreviewCard(
          workouts: 4,
          distance: '21km',
          items: [
            _WorkoutItem(
              day: 'Mo',
              title: 'Easy run',
              detail: '6km',
              color: Color(0xFF84CC16),
            ),
            _WorkoutItem(
              day: 'Tu',
              title: 'Intervals',
              detail: '5km',
              color: AppColors.orange,
            ),
            _WorkoutItem(
              day: 'Fr',
              title: 'Strength',
              detail: '20min',
              color: Color(0xFF60A5FA),
            ),
            _WorkoutItem(
              day: 'Sa',
              title: 'Long run',
              detail: '10km',
              color: Color(0xFFA78BFA),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your race time prediction',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nubi predicts your race time as you go',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const _PlanBadge(
                      label: '21.1',
                      icon: Icons.flag_outlined,
                      colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On race day',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '1:55:00 - 1:59:00',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Improve5kSheet extends StatelessWidget {
  const _Improve5kSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: _PlanBadge(
            label: '5K',
            icon: Icons.trending_up,
            colors: [Color(0xFFD4A017), Color(0xFF7C4A00)],
            size: 82,
          ),
        ),
        const SizedBox(height: 20),
        _Hero(
          title: 'Improve your 5k.',
          subtitle:
              'Structured training for a stronger 5k. We\'ll build your plan around your ability and schedule.',
        ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ValueBlock(label: 'Distance', value: '5k'),
                    ),
                    Expanded(
                      child: _ValueBlock(label: 'Length', value: '6-8 weeks'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'Workout Types',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkoutTypeChip(label: 'Easy', color: Color(0xFF84CC16)),
                    _WorkoutTypeChip(label: 'Tempo', color: Color(0xFFEAB308)),
                    _WorkoutTypeChip(
                      label: 'Intervals',
                      color: AppColors.orange,
                    ),
                    _WorkoutTypeChip(
                      label: 'Strength',
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _WeekPreviewCard(
          workouts: 3,
          distance: '17km',
          items: [
            _WorkoutItem(
              day: 'Mo',
              title: 'Easy run',
              detail: '4km',
              color: Color(0xFF84CC16),
            ),
            _WorkoutItem(
              day: 'Tu',
              title: 'Intervals',
              detail: '6km',
              color: AppColors.orange,
            ),
            _WorkoutItem(
              day: 'Sa',
              title: 'Long run',
              detail: '7km',
              color: Color(0xFFA78BFA),
            ),
          ],
        ),
      ],
    );
  }
}

class _StartRunningSheet extends StatelessWidget {
  const _StartRunningSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: _PlanBadge(
            label: 'NTR',
            icon: Icons.directions_run,
            colors: [Color(0xFF15803D), Color(0xFF14532D)],
            size: 82,
          ),
        ),
        const SizedBox(height: 20),
        const _Hero(
          title: 'New To Running plan',
          subtitle:
              'From zero to your first 5k. We\'ll build your plan around your ability and schedule.',
        ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ValueBlock(label: 'Goal distance', value: '5k'),
                    ),
                    Expanded(
                      child: _ValueBlock(
                        label: 'Length',
                        value: '8 - 12 weeks',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'Workout Types',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkoutTypeChip(label: 'Easy', color: Color(0xFF84CC16)),
                    _WorkoutTypeChip(
                      label: 'Walk Run',
                      color: Color(0xFF22C55E),
                    ),
                    _WorkoutTypeChip(
                      label: 'Strength',
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ExampleWeekRow(
          current: 2,
          total: 3,
          weeklyCurrent: 4,
          weeklyGoal: 7,
          rows: [
            _ProgressRow(
              icon: Icons.directions_walk,
              label: 'Walk Run',
              done: 1,
              total: 2,
              color: Color(0xFF22C55E),
            ),
            _ProgressRow(
              icon: Icons.fitness_center,
              label: 'Strength',
              done: 1,
              total: 1,
              color: Color(0xFF60A5FA),
            ),
          ],
        ),
      ],
    );
  }
}

class _GeneralTrainingSheet extends StatelessWidget {
  const _GeneralTrainingSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PlanBadge(
              label: 'TYW',
              icon: Icons.directions_walk,
              colors: [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
            ),
            const SizedBox(width: 4),
            const _PlanBadge(
              label: 'RF',
              icon: Icons.speed,
              colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
              size: 72,
            ),
            const SizedBox(width: 4),
            const _PlanBadge(
              label: 'RM',
              icon: Icons.self_improvement,
              colors: [Color(0xFFE11D48), Color(0xFF881337)],
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _Hero(
          title: 'Built around you.',
          subtitle:
              'Run further, faster, or simply keep moving. We\'ll shape your plan around your ability and schedule.',
        ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Three plans to choose from:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const _PlanChoice(
                  name: 'Run Faster',
                  detail: 'Speed & tempo work',
                ),
                const SizedBox(height: 8),
                const _PlanChoice(
                  name: 'Run Further',
                  detail: 'Mileage & endurance',
                ),
                const SizedBox(height: 8),
                const _PlanChoice(
                  name: 'Run To Maintain',
                  detail: 'Easy & flexible running',
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'Workout Types',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkoutTypeChip(label: 'Easy', color: Color(0xFF84CC16)),
                    _WorkoutTypeChip(label: 'Tempo', color: Color(0xFFEAB308)),
                    _WorkoutTypeChip(
                      label: 'Intervals',
                      color: AppColors.orange,
                    ),
                    _WorkoutTypeChip(
                      label: 'Strength',
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ExampleWeekRow(
          current: 3,
          total: 4,
          weeklyCurrent: 12,
          weeklyGoal: 17,
          rows: [
            _ProgressRow(
              icon: Icons.directions_run,
              label: 'Run',
              done: 2,
              total: 3,
              color: AppColors.orange,
            ),
            _ProgressRow(
              icon: Icons.fitness_center,
              label: 'Strength',
              done: 1,
              total: 1,
              color: Color(0xFF60A5FA),
            ),
          ],
        ),
      ],
    );
  }
}

class _DistancePlansSheet extends StatelessWidget {
  const _DistancePlansSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PlanBadge(
              label: '10K',
              icon: Icons.route_outlined,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            ),
            const SizedBox(width: 4),
            const _PlanBadge(
              label: '5K',
              icon: Icons.flag_outlined,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
              size: 72,
            ),
            const SizedBox(width: 4),
            const _PlanBadge(
              label: '21.1',
              icon: Icons.flag_outlined,
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _Hero(
          title: 'Pick Your Distance.',
          subtitle:
              'Fully customize a plan for any distance: 5K, 10K, 21K, 42K.',
        ),
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ValueBlock(
                        label: 'Distance',
                        value: '5K, 10K, 21K, 42K',
                      ),
                    ),
                    Expanded(
                      child: _ValueBlock(label: 'Length', value: '6+ weeks'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'Workout Types',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkoutTypeChip(label: 'Easy', color: Color(0xFF84CC16)),
                    _WorkoutTypeChip(label: 'Tempo', color: Color(0xFFEAB308)),
                    _WorkoutTypeChip(
                      label: 'Intervals',
                      color: AppColors.orange,
                    ),
                    _WorkoutTypeChip(
                      label: 'Long Run',
                      color: Color(0xFFA78BFA),
                    ),
                    _WorkoutTypeChip(
                      label: 'Strength',
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ExampleWeekRow(
          current: 3,
          total: 4,
          weeklyCurrent: 12,
          weeklyGoal: 17,
          rows: [
            _ProgressRow(
              icon: Icons.directions_run,
              label: 'Run',
              done: 2,
              total: 3,
              color: AppColors.orange,
            ),
            _ProgressRow(
              icon: Icons.fitness_center,
              label: 'Strength',
              done: 1,
              total: 1,
              color: Color(0xFF60A5FA),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanChoice extends StatelessWidget {
  const _PlanChoice({required this.name, required this.detail});
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRow {
  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.total,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int done;
  final int total;
  final Color color;
}

class _ExampleWeekRow extends StatelessWidget {
  const _ExampleWeekRow({
    required this.current,
    required this.total,
    required this.weeklyCurrent,
    required this.weeklyGoal,
    required this.rows,
  });

  final int current;
  final int total;
  final int weeklyCurrent;
  final int weeklyGoal;
  final List<_ProgressRow> rows;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ExampleWeekCard(current: current, total: total, rows: rows),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _WeeklyTotalCard(completed: weeklyCurrent, goal: weeklyGoal),
          ),
        ],
      ),
    );
  }
}

class _ExampleWeekCard extends StatelessWidget {
  const _ExampleWeekCard({
    required this.current,
    required this.total,
    required this.rows,
  });

  final int current;
  final int total;
  final List<_ProgressRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Example week',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$current/$total',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ProgressRowView(row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRowView extends StatelessWidget {
  const _ProgressRowView({required this.row});
  final _ProgressRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(row.icon, size: 13, color: scheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            row.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 30,
          child: Row(
            children: [
              for (var i = 0; i < row.total; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < row.done ? row.color : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${row.done}/${row.total}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _WeeklyTotalCard extends StatelessWidget {
  const _WeeklyTotalCard({required this.completed, required this.goal});

  final int completed;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly total',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: CustomPaint(
                    painter: _WeeklyRingPainter(
                      completed: completed.toDouble(),
                      goal: goal.toDouble(),
                      start: const Color(0xFF84CC16),
                      end: const Color(0xFFEAB308),
                      track: scheme.outlineVariant,
                    ),
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$completed',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: '/$goal km',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyRingPainter extends CustomPainter {
  const _WeeklyRingPainter({
    required this.completed,
    required this.goal,
    required this.start,
    required this.end,
    required this.track,
  });

  final double completed;
  final double goal;
  final Color start;
  final Color end;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 6,
    );
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    final fraction = goal <= 0 ? 0.0 : (completed / goal).clamp(0.0, 1.0);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [start, end],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _WeeklyRingPainter oldDelegate) =>
      oldDelegate.completed != completed ||
      oldDelegate.goal != goal ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.track != track;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 32,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 28)),
      ],
    );
  }
}

class _WorkoutTypeChip extends StatelessWidget {
  const _WorkoutTypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutItem {
  const _WorkoutItem({
    required this.day,
    required this.title,
    required this.detail,
    required this.color,
  });

  final String day;
  final String title;
  final String detail;
  final Color color;
}

class _WeekPreviewCard extends StatelessWidget {
  const _WeekPreviewCard({
    required this.workouts,
    required this.distance,
    required this.items,
  });

  final int workouts;
  final String distance;
  final List<_WorkoutItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What your week could look like',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '$workouts workouts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  distance,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < workouts; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _WorkoutRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.item});
  final _WorkoutItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 24,
          child: Text(
            item.day,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          item.detail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The saved plans, active one marked; tap to open.
class _MyPlans extends ConsumerWidget {
  const _MyPlans({required this.plans});
  final List<CloudPlan> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeKey = ref.watch(activePlanProvider).value?.plan;
    return RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(cloudPlansProvider);
        ref.invalidate(activePlanProvider);
        await ref.read(cloudPlansProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: plans.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final plan = plans[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              title: Text(plan.kind?.code.toUpperCase() ?? plan.key),
              subtitle: Text('${plan.progress.length} sessions done'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (plan.key == activeKey) const Chip(label: Text('Active')),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => AppNavigator.planView(context, plan),
            ),
          );
        },
      ),
    );
  }
}
