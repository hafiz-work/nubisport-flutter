import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';

class TrainingZonesPage extends StatefulWidget {
  const TrainingZonesPage({super.key});

  @override
  State<TrainingZonesPage> createState() => _TrainingZonesPageState();
}

class _TrainingZonesPageState extends State<TrainingZonesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _maxHeartRate;
  late final TextEditingController _ftp;

  bool _heartAuto = true;
  bool _powerAuto = true;
  bool _paceAuto = true;
  int _heartMode = 0;
  String? _paceEvent;
  Duration? _paceTime;

  static const _events = ['1 Mile', '5 km', '10 km', 'Half-Marathon', 'Marathon'];
  static const _eventKm = {'1 Mile': 1.609, '5 km': 5.0, '10 km': 10.0, 'Half-Marathon': 21.0975, 'Marathon': 42.195};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _maxHeartRate = TextEditingController(text: '190');
    _ftp = TextEditingController(text: '133');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _maxHeartRate.dispose();
    _ftp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Zones'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.orange,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: scheme.onSurface,
          unselectedLabelColor: scheme.onSurfaceVariant,
          dividerColor: scheme.outlineVariant,
          tabs: const [
            Tab(text: 'Heart Rate'),
            Tab(text: 'Power'),
            Tab(text: 'Pace'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(controller: _tabs, children: [_heartRateTab(context), _powerTab(context), _paceTab(context)]),
      ),
    );
  }

  Widget _heartRateTab(BuildContext context) {
    final max = int.tryParse(_maxHeartRate.text) ?? 190;
    final z5 = (max * 0.97).ceil();
    final z4 = (max * 0.89).ceil();
    final z3 = (max * 0.82).floor();
    final z2 = (max * 0.66).floor();
    final zones = [
      _Zone('Zone 5', 'Anaerobic', '$z5 - Max', const Color(0xFFEF4444)),
      _Zone('Zone 4', 'Threshold', '$z4 - ${z5 - 1}', const Color(0xFFF87171)),
      _Zone('Zone 3', 'Tempo', '$z3 - ${z4 - 1}', const Color(0xFFFCA5A5)),
      _Zone('Zone 2', 'Endurance', '$z2 - ${z3 - 1}', const Color(0xFFFECACA)),
      _Zone('Zone 1', 'Recovery', 'Rest - ${z2 - 1}', const Color(0xFFFEE2E2)),
    ];

    return _TabBody(
      saveLabel: 'Save heart rate zones',
      onSave: () => _saved('Heart rate zones saved.'),
      children: [
        const _Intro('You can edit your max heart rate below and we\'ll auto-calculate your new zones based on that.'),
        const SizedBox(height: 20),
        _SegmentedToggle(
          value: _heartMode,
          labels: const ['Default', 'Ride'],
          onChanged: (value) => setState(() => _heartMode = value),
        ),
        const SizedBox(height: 20),
        _LabelWithInfo(
          label: 'Max Heart Rate (bpm)',
          onInfo: () => _showInfo(
            'What is max heart rate?',
            'Max heart rate is the highest number of beats per minute your heart can reach during maximum effort. '
                'We use it to calculate your heart rate zones.',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _maxHeartRate,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '190'),
        ),
        const SizedBox(height: 20),
        _AutoCalculateRow(
          value: _heartAuto,
          subtitle: 'Each zone is based on your max heart rate',
          onChanged: (value) => setState(() => _heartAuto = value),
        ),
        const SizedBox(height: 18),
        for (final zone in zones) _ZoneRow(zone: zone),
      ],
    );
  }

  Widget _powerTab(BuildContext context) {
    final ftp = int.tryParse(_ftp.text) ?? 133;
    final z7 = (ftp * 1.51).ceil();
    final z6 = (ftp * 1.21).ceil();
    final z5 = (ftp * 1.06).ceil();
    final z4 = (ftp * 0.91).floor();
    final z3 = (ftp * 0.76).floor();
    final z2 = (ftp * 0.56).floor();
    final zones = [
      _Zone('Zone 7', 'Neuromuscular', '$z7 - Max', const Color(0xFF7C3AED)),
      _Zone('Zone 6', 'Anaerobic', '$z6 - ${z7 - 1}', const Color(0xFF8B5CF6)),
      _Zone('Zone 5', 'VO2Max', '$z5 - ${z6 - 1}', const Color(0xFFA78BFA)),
      _Zone('Zone 4', 'Threshold', '$z4 - ${z5 - 1}', const Color(0xFFC4B5FD)),
      _Zone('Zone 3', 'Tempo', '$z3 - ${z4 - 1}', const Color(0xFFDDD6FE)),
      _Zone('Zone 2', 'Endurance', '$z2 - ${z3 - 1}', const Color(0xFFEDE9FE)),
      _Zone('Zone 1', 'Recovery', '0 - ${z2 - 1}', const Color(0xFFF5F3FF)),
    ];

    return _TabBody(
      saveLabel: 'Save power zones',
      onSave: () => _saved('Power zones saved.'),
      children: [
        const _Intro(
          'We estimate your Functional Threshold Power (FTP) using power data. '
          'You can edit this number and we\'ll auto-calculate your new zones.',
        ),
        const SizedBox(height: 20),
        _LabelWithInfo(
          label: 'Functional Threshold Power (Watts)',
          onInfo: () => _showInfo(
            'What is FTP?',
            'Your FTP is an estimate of the maximum watts you could maintain for 60 minutes.',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ftp,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '133'),
        ),
        const SizedBox(height: 20),
        _AutoCalculateRow(
          value: _powerAuto,
          subtitle: 'Each zone is a % of FTP',
          onChanged: (value) => setState(() => _powerAuto = value),
        ),
        const SizedBox(height: 18),
        for (final zone in zones) _ZoneRow(zone: zone),
      ],
    );
  }

  Widget _paceTab(BuildContext context) {
    final hasPace = _paceEvent != null && _paceTime != null && _paceTime!.inSeconds > 0;
    final zones = hasPace ? _paceZones() : const <_Zone>[];

    return _TabBody(
      saveLabel: 'Save pace zones',
      enabled: hasPace,
      onSave: () => _saved('Pace zones saved.'),
      children: [
        const _Intro(
          'We estimate your running pace zones based on a recent running event. '
          'Select your event distance and completion time. We\'ll calculate your zones.',
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  _PickerField(text: _paceEvent ?? 'Distance', muted: _paceEvent == null, onTap: _pickEvent),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Time', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  _PickerField(
                    text: _paceTime == null ? '00:00:00' : _formatTime(_paceTime!),
                    muted: _paceTime == null,
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _AutoCalculateRow(
          value: _paceAuto,
          subtitle: 'Each zone is a % of your event pace',
          onChanged: (value) => setState(() => _paceAuto = value),
        ),
        const SizedBox(height: 18),
        if (!hasPace)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Column(
              children: [
                Icon(Icons.timer_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 14),
                Text(
                  'Add your event and time to\nsee your paces for each zone.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          )
        else
          for (final zone in zones) _ZoneRow(zone: zone),
      ],
    );
  }

  List<_Zone> _paceZones() {
    final km = _eventKm[_paceEvent] ?? 5.0;
    final base = _paceTime!.inSeconds / km;
    String pace(double multiplier) {
      final total = (base * multiplier).round();
      return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
    }

    return [
      _Zone('Zone 6', 'Anaerobic', 'Min - ${pace(0.838)}', const Color(0xFF3B82F6)),
      _Zone('Zone 5', 'VO2Max', '${pace(0.838)} - ${pace(0.891)}', const Color(0xFF60A5FA)),
      _Zone('Zone 4', 'Threshold', '${pace(0.891)} - ${pace(0.953)}', const Color(0xFF93C5FD)),
      _Zone('Zone 3', 'Tempo', '${pace(0.953)} - ${pace(1.06)}', const Color(0xFFBFDBFE)),
      _Zone('Zone 2', 'Endurance', '${pace(1.06)} - ${pace(1.232)}', const Color(0xFFDBEAFE)),
      _Zone('Zone 1', 'Recovery', '${pace(1.232)} - Max', const Color(0xFFEFF6FF)),
    ];
  }

  Future<void> _pickEvent() async {
    final selected = await FamilyModalSheet.showMaterialDefault<String>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) => _EventSheet(initial: _paceEvent),
    );
    if (selected != null) setState(() => _paceEvent = selected);
  }

  Future<void> _pickTime() async {
    final selected = await FamilyModalSheet.showMaterialDefault<Duration>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) => _TimeSheet(initial: _paceTime ?? Duration.zero),
    );
    if (selected != null) setState(() => _paceTime = selected);
  }

  void _saved(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInfo(String title, String body) {
    FamilyModalSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Close')),
            ],
          ),
        );
      },
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.children, required this.saveLabel, required this.onSave, this.enabled = true});

  final List<Widget> children;
  final String saveLabel;
  final VoidCallback onSave;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onSave : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
              child: Text(saveLabel),
            ),
          ),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.value, required this.labels, required this.onChanged});
  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == i ? scheme.surfaceContainerLowest : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radius - 2),
                  ),
                  child: Text(
                    labels[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: value == i ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelWithInfo extends StatelessWidget {
  const _LabelWithInfo({required this.label, required this.onInfo});
  final String label;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline, size: 18),
          visualDensity: VisualDensity.compact,
          tooltip: 'More info',
        ),
      ],
    );
  }
}

class _AutoCalculateRow extends StatelessWidget {
  const _AutoCalculateRow({required this.value, required this.subtitle, required this.onChanged});
  final bool value;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto-calculate my ranges',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.text, required this.onTap, this.muted = false});
  final String text;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted ? scheme.onSurfaceVariant : scheme.onSurface),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _EventSheet extends StatefulWidget {
  const _EventSheet({required this.initial});
  final String? initial;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late String _selected = widget.initial ?? '5 km';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 500,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Distance', style: theme.textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  for (final event in _TrainingZonesPageState._events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selected = event),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selected == event ? theme.colorScheme.surfaceContainerHigh : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                          ),
                          child: Text(
                            event,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _selected == event
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial});
  final Duration initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late Duration _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 360,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Time', style: theme.textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms,
                initialTimerDuration: _selected,
                onTimerDurationChanged: (value) => setState(() => _selected = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Zone {
  const _Zone(this.name, this.description, this.range, this.color);
  final String name;
  final String description;
  final String range;
  final Color color;
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone});
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(color: zone.color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(zone.description, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(zone.range, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _formatTime(Duration duration) {
  final h = duration.inHours;
  final m = duration.inMinutes % 60;
  final s = duration.inSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
