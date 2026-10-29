import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../activity_format.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/activity_providers.dart';
import '../widgets/activity_empty_state.dart';
import '../widgets/activity_map.dart';
import '../widgets/activity_map_3d.dart';
import '../widgets/activity_share_sheet.dart';
import '../widgets/map_style_sheet.dart';

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(activityDetailProvider(activityId));
    return detail.when(
      loading: () => _FallbackScaffold(child: const Center(child: CircularProgressIndicator.adaptive())),
      error: (_, _) => const _FallbackScaffold(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: ActivityEmptyState(
            icon: Icons.cloud_off,
            title: 'Couldn\'t share image.',
            message: 'Check your connection and try again.',
          ),
        ),
      ),
      data: (activity) => activity == null
          ? const _FallbackScaffold(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ActivityEmptyState(
                  icon: Icons.search_off,
                  title: 'Activity not found',
                  message: 'This activity may have been deleted.',
                ),
              ),
            )
          : _ActivityDetail(activity: activity, isMine: ref.watch(authControllerProvider).value?.id == activity.userId),
    );
  }
}

/// Loading/error still need a normal title bar and a way back.
class _FallbackScaffold extends StatelessWidget {
  const _FallbackScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity details')),
    body: child,
  );
}

class _ActivityDetail extends StatefulWidget {
  const _ActivityDetail({required this.activity, required this.isMine});
  final Activity activity;
  final bool isMine;

  @override
  State<_ActivityDetail> createState() => _ActivityDetailState();
}

class _ActivityDetailState extends State<_ActivityDetail> {
  static const _minSheet = 0.16;
  static const _initialSheet = 0.52;
  static const _maxSheet = 0.86;

  final _sheetController = DraggableScrollableController();
  double _sheetSize = _initialSheet;
  double _bodyHeight = 0;
  bool _wasMinimized = false;
  int _focusTrigger = 0;
  bool _show3d = true;
  EdgeInsets _focusPadding = const EdgeInsets.all(48);

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    if ((size - _sheetSize).abs() < 0.004) return;
    final minimized = size <= _minSheet + 0.03;
    final height = _bodyHeight > 0 ? _bodyHeight : MediaQuery.sizeOf(context).height;
    setState(() {
      _sheetSize = size;
      if (minimized && !_wasMinimized) {
        _wasMinimized = true;
        _focusPadding = EdgeInsets.fromLTRB(48, 110, 48, height * _minSheet + 24);
        _focusTrigger++;
      } else if (!minimized && _wasMinimized) {
        // Maximized/restored again: ease back to the wider view.
        _wasMinimized = false;
        _focusPadding = EdgeInsets.fromLTRB(48, 110, 48, height * _initialSheet + 24);
        _focusTrigger++;
      }
    });
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activity = widget.activity;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            _bodyHeight = height;
            // Keep the map's "i"/play just above the sheet while it moves, but
            // stop following once the sheet is high enough to cover them.
            final controlsBottom = math.min(height * (_sheetSize + 0.02), height * 0.58);
            final can3d = theme.platform == TargetPlatform.android || theme.platform == TargetPlatform.iOS;
            final initialFocusPadding = EdgeInsets.fromLTRB(48, 110, 48, height * _initialSheet + 24);

            return Stack(
              children: [
                Positioned.fill(
                  child: activity.route.isEmpty
                      ? ColoredBox(color: theme.colorScheme.surfaceContainer)
                      : can3d
                      ? ActivityMap3D(
                          activity: activity,
                          height: height,
                          animateRoute: true,
                          controlsBottomInset: controlsBottom,
                          initialFocusPadding: initialFocusPadding,
                          focusTrigger: _focusTrigger,
                          focusPadding: _focusPadding,
                          tilted: _show3d,
                        )
                      // Desktop/web fall back to the pure-Flutter vector map.
                      : ActivityMap(
                          activity: activity,
                          height: height,
                          interactive: true,
                          animateRoute: true,
                          borderRadius: BorderRadius.zero,
                          controlsBottomInset: controlsBottom,
                          useVector: true,
                          initialFocusPadding: initialFocusPadding,
                          focusTrigger: _focusTrigger,
                          focusPadding: _focusPadding,
                        ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MapButton(icon: Icons.arrow_back, tooltip: 'Back', onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                        Column(
                          children: [
                            _MapButton(
                              icon: Icons.share_outlined,
                              tooltip: 'Share activity',
                              onTap: () => showActivityShareSheet(context, activity, isMine: widget.isMine),
                            ),
                            _MapButton(
                              icon: Icons.layers_outlined,
                              tooltip: 'Map style',
                              onTap: () => showMapStyleSheet(context),
                            ),
                            if (can3d)
                              _MapButton(
                                // Shows the mode a tap switches to, like Strava's 2D/3D toggle.
                                label: _show3d ? '2D' : '3D',
                                tooltip: _show3d ? 'Switch to 2D map' : 'Switch to 3D map',
                                onTap: () => setState(() => _show3d = !_show3d),
                              ),
                            _MapButton(
                              icon: Icons.my_location,
                              tooltip: 'Refocus route',
                              // Re-fit the whole route above the sheet at its current size.
                              onTap: () => setState(() {
                                // Capped so a fully opened sheet still leaves room to fit the route.
                                _focusPadding = EdgeInsets.fromLTRB(
                                  48,
                                  110,
                                  48,
                                  math.min(height * _sheetSize, height * 0.58) + 24,
                                );
                                _focusTrigger++;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: _initialSheet,
                  minChildSize: _minSheet,
                  maxChildSize: _maxSheet,
                  snap: true,
                  snapSizes: const [_minSheet, _initialSheet, _maxSheet],
                  builder: (context, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AuthorRow(activity: activity),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(activity.title, style: theme.textTheme.headlineMedium)),
                            const SizedBox(width: 10),
                            _TypePill(label: activityLabel(activity.type)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (activity.notes.isNotEmpty) ...[
                          _NotesCard(notes: activity.notes),
                          const SizedBox(height: 24),
                        ],
                        _StatGrid(activity: activity),
                        if (activity.splits.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const _SectionLabel('Splits per KM'),
                          const SizedBox(height: 10),
                          _SplitsCard(activity: activity),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({this.icon, this.label, required this.tooltip, required this.onTap})
    : assert((icon == null) != (label == null));
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surface.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Semantics(
            button: true,
            label: tooltip,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: label != null
                    ? Text(
                        label!,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: scheme.onSurface),
                      )
                    : Icon(icon, size: 22, color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.orange, width: 2),
          ),
          child: Text(
            activity.userInitial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: AppTheme.displayFont,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      formatActivityDate(activity.startedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (activity.location.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        activity.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        label,
        style: TextStyle(color: scheme.primary, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(notes, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (label: 'Distance', value: formatDistance(activity.distanceKm)),
      (label: 'Average pace', value: formatPace(activity.pace)),
      (label: 'Moving time', value: formatDuration(activity.duration)),
      (label: 'Elevation', value: '${activity.elevationGainM} m'),
      (label: 'Calories', value: '${activity.calories} Cal'),
      (label: 'Kudos', value: '${activity.kudos}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 24.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: _Stat(label: stat.label, value: stat.value),
              ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
      ],
    );
  }
}

class _SplitsCard extends StatelessWidget {
  const _SplitsCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < activity.splits.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        'KM ${i + 1}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatSplit(activity.splits[i]),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatPace(Duration(seconds: activity.splits[i].inSeconds)),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (i != activity.splits.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18));
  }
}
