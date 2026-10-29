import 'package:flutter/material.dart';

import '../../domain/models/plan.dart';

class PlanFormArgs {
  const PlanFormArgs({this.kind, this.tahap, this.raceDate = false, this.existing});
  final PlanKind? kind;
  final String? tahap;
  final bool raceDate;
  final CloudPlan? existing;
}

/// Placeholder until the plan form lands.
class PlanFormPage extends StatelessWidget {
  const PlanFormPage({super.key, this.args = const PlanFormArgs()});
  final PlanFormArgs args;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(args.existing == null ? 'New plan' : 'Update plan')));
}
