import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';

class _PlanDetails {
  const _PlanDetails({
    required this.name,
    required this.price,
    required this.period,
    required this.tagline,
    required this.features,
    required this.note,
    this.highlighted = false,
  });

  final String name;
  final String price;
  final String period;
  final String tagline;
  final List<String> features;
  final String note;
  final bool highlighted;
}

const _plans = [
  _PlanDetails(
    name: 'Free',
    price: 'RM0',
    period: 'forever',
    tagline: 'For getting started.',
    features: [
      'Community feed and public activities',
      'Basic 5K plan',
      'Save 1 plan to the cloud',
      'Weekly stats and streaks',
    ],
    note: 'No credit card required.',
  ),
  _PlanDetails(
    name: 'Member',
    price: 'RM15',
    period: '/month',
    tagline: 'For consistent runners.',
    features: [
      'All 5K, 10K and 21K plans',
      'Save 5 plans to the cloud',
      'Full community and feed access',
      'Deeper pace and split analysis',
      'Nubi community support',
    ],
    note: 'Cancel anytime.',
    highlighted: true,
  ),
  _PlanDetails(
    name: 'Annual Member',
    price: 'RM150',
    period: '/year',
    tagline: 'Best value.',
    features: [
      'All Member plan benefits',
      'Save 2 months compared with monthly',
      'Early access to new features',
      'Support the Nubi community all year',
    ],
    note: 'One payment for 12 months.',
  ),
];

/// Mock pricing carousel (no payments yet).
Future<void> showPricingSheet(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final radius = BorderRadius.vertical(top: Radius.circular(AppTheme.radius));
  return FamilyModalSheet.showMaterialDefault<void>(
    context: context,
    contentBackgroundColor: scheme.surface,
    mainContentBorderRadius: radius,
    shape: RoundedRectangleBorder(borderRadius: radius),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _PricingBody(sheetContext: sheetContext),
  );
}

class _PricingBody extends StatefulWidget {
  const _PricingBody({required this.sheetContext});
  final BuildContext sheetContext;

  @override
  State<_PricingBody> createState() => _PricingBodyState();
}

class _PricingBodyState extends State<_PricingBody> {
  final _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(String name) {
    final messenger = ScaffoldMessenger.of(widget.sheetContext);
    Navigator.of(widget.sheetContext).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name: payments are coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Near-full sheet: 0.95 of the screen, minus the drag-handle strip.
    final height = math.max(360.0, MediaQuery.sizeOf(widget.sheetContext).height * 0.95 - 56);

    return SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose your plan', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Sample pricing for now. In-app payments are coming soon.',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(widget.sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _plans.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _PlanCard(plan: _plans[index], onSelect: () => _select(_plans[index].name)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _plans.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.orange : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onSelect});
  final _PlanDetails plan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: plan.highlighted ? scheme.primary.withValues(alpha: 0.07) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: plan.highlighted ? scheme.primary : scheme.outlineVariant,
          width: plan.highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 22))),
              if (plan.highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(plan.tagline, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(plan.price, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 34)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(plan.period, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Includes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final feature in plan.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: AppColors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(feature, style: theme.textTheme.bodySmall)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    plan.note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          plan.highlighted
              ? FilledButton(onPressed: onSelect, child: Text('Choose ${plan.name}'))
              : OutlinedButton(onPressed: onSelect, child: Text('Choose ${plan.name}')),
        ],
      ),
    );
  }
}
