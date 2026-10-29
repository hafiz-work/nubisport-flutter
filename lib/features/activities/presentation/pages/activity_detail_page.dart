import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../activity_format.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/activity_repository_provider.dart';
import '../controllers/activity_providers.dart';
import '../widgets/activity_empty_state.dart';
import '../widgets/activity_map.dart';
import '../widgets/activity_map_3d.dart';
import '../widgets/activity_share_sheet.dart';
import '../widgets/activity_stream_chart.dart';
import '../widgets/kudos_bar.dart';
import '../widgets/map_style_sheet.dart';

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(activityDetailProvider(activityId));
    return detail.when(
      loading: () => _FallbackScaffold(
        child: const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const _FallbackScaffold(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: ActivityEmptyState(
            icon: Icons.cloud_off,
            title: 'Couldn\'t load activity',
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
          : _ActivityDetail(
              activity: activity,
              isMine:
                  ref.watch(authControllerProvider).value?.id ==
                  activity.userId,
            ),
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

class _ActivityDetail extends ConsumerStatefulWidget {
  const _ActivityDetail({required this.activity, required this.isMine});
  final Activity activity;
  final bool isMine;

  @override
  ConsumerState<_ActivityDetail> createState() => _ActivityDetailState();
}

class _ActivityDetailState extends ConsumerState<_ActivityDetail> {
  static const _minSheet = 0.16;
  static const _initialSheet = 0.52;
  static const _topBarHeight = 60.0;

  final _sheetController = DraggableScrollableController();

  /// Sheet size per drag frame; only the map inset and top bar listen, so dragging never
  /// rebuilds the sheet content or charts.
  final _sheetSize = ValueNotifier<double>(_initialSheet);
  double _maxSheet = 0.86;

  /// Same instance across rebuilds: a new list makes the sheet re-snap.
  List<double> _snapSizes = const [_minSheet, _initialSheet, 0.86];
  final _fullNotifier = ValueNotifier(false);
  double _bodyHeight = 0;
  bool _show3d = true;

  /// Camera refits: bump trigger + where to fit. Only the map listens, so a refit never
  /// rebuilds the sheet or charts while the camera moves.
  final _focus = ValueNotifier((trigger: 0, padding: EdgeInsets.zero));

  /// Snap size the camera was last fitted for, and the debounce that waits for the sheet to rest.
  double _settledAt = _initialSheet;
  Timer? _settleTimer;
  late var _kudos = (
    count: widget.activity.kudos,
    mine: widget.activity.kudosed,
  );

  /// Optimistic like the feed: flip now, keep the server's answer, roll back on failure.
  Future<void> _toggleKudos() async {
    final before = _kudos;
    final on = !before.mine;
    HapticFeedback.lightImpact();
    setState(() => _kudos = (count: before.count + (on ? 1 : -1), mine: on));
    try {
      final after = await ref
          .read(activityRepositoryProvider)
          .setKudos(widget.activity.id, on: on);
      if (mounted) setState(() => _kudos = after);
      ref.invalidate(activityFeedProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _kudos = before);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Couldn\'t send kudos. Try again.')),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    _sheetSize.value = size;
    _fullNotifier.value = _isFull(size);
    // Refit once the sheet comes to rest on a snap it wasn't on before (minimize, open,
    // back from full) - not on every drag frame, so the camera makes one smooth move.
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_sheetController.isAttached) return;
      final snap = _snapSizes
          .where((s) => (s - _sheetController.size).abs() < 0.01)
          .firstOrNull;
      if (snap == null || snap == _settledAt) return;
      _settledAt = snap;
      // At full height the sheet covers the map: nothing to fit.
      if (!_isFull(snap)) _refit(snap);
    });
  }

  /// The route fits between the top bar and the sheet, clear of the map buttons on the right.
  EdgeInsets _fitPadding(double sheet) {
    final height = _bodyHeight > 0
        ? _bodyHeight
        : MediaQuery.sizeOf(context).height;
    // Tight margins so the route fills the visible map, like Strava; the right side clears
    // the map buttons (42 px wide, 12 px from the edge).
    return EdgeInsets.fromLTRB(
      24,
      MediaQuery.paddingOf(context).top + _topBarHeight + 8,
      62,
      // Capped so a tall sheet still leaves room to fit the route.
      math.min(height * sheet, height * 0.58) + 12,
    );
  }

  void _refit(double sheet) => _focus.value = (
    trigger: _focus.value.trigger + 1,
    padding: _fitPadding(sheet),
  );

  @override
  void dispose() {
    _settleTimer?.cancel();
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _sheetSize.dispose();
    _fullNotifier.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _isFull(double size) => size >= _maxSheet - 0.01;

  void _collapseSheet() => _sheetController.animateTo(
    _initialSheet,
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

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
            final topInset = MediaQuery.paddingOf(context).top;
            // Full height stops right under the top bar, like Strava's full-page sheet.
            final maxSheet = 1 - (topInset + _topBarHeight) / height;
            if (maxSheet != _maxSheet) {
              _maxSheet = maxSheet;
              _snapSizes = [_minSheet, _initialSheet, maxSheet];
            }
            final can3d =
                theme.platform == TargetPlatform.android ||
                theme.platform == TargetPlatform.iOS;
            final initialFocusPadding = _fitPadding(_initialSheet);
            // Built once per real rebuild, reused by every drag frame of the sheet.
            final sheetContent = ListView(
              primary: true,
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
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
                ..._sections(
                  context,
                  activity,
                ).indexed.map((e) => _Reveal(index: e.$1, child: e.$2)),
              ],
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: activity.route.isEmpty
                      ? ColoredBox(color: theme.colorScheme.surfaceContainer)
                      : ListenableBuilder(
                          listenable: Listenable.merge([_sheetSize, _focus]),
                          builder: (context, _) {
                            final size = _sheetSize.value;
                            final focus = _focus.value;
                            // Keep the map's "i"/play just above the sheet while it moves, but
                            // stop following once the sheet is high enough to cover them.
                            final controlsBottom = math.min(
                              height * (size + 0.02),
                              height * 0.58,
                            );
                            return can3d
                                ? ActivityMap3D(
                                    activity: activity,
                                    height: height,
                                    animateRoute: true,
                                    controlsBottomInset: controlsBottom,
                                    initialFocusPadding: initialFocusPadding,
                                    focusTrigger: focus.trigger,
                                    focusPadding: focus.padding,
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
                                    focusTrigger: focus.trigger,
                                    focusPadding: focus.padding,
                                  );
                          },
                        ),
                ),
                // Map controls stacked above the replay button, moving with the sheet like it;
                // capped under the top bar on short screens. The sheet covers them when it rises.
                if (activity.route.isNotEmpty)
                  ValueListenableBuilder<double>(
                    valueListenable: _sheetSize,
                    builder: (context, size, column) {
                      final columnHeight = (can3d ? 3 : 2) * 50.0;
                      final bottom = math.min(
                        math.min(height * (size + 0.02), height * 0.58) + 56,
                        height - topInset - _topBarHeight - columnHeight,
                      );
                      return Positioned(
                        right: 12,
                        bottom: bottom,
                        child: column!,
                      );
                    },
                    child: Column(
                      children: [
                        _MapButton(
                          icon: Icons.layers_outlined,
                          tooltip: 'Map style',
                          onTap: () => showMapStyleSheet(context),
                        ),
                        if (can3d)
                          _MapButton(
                            // Shows the mode a tap switches to, like Strava's 2D/3D toggle.
                            label: _show3d ? '2D' : '3D',
                            tooltip: _show3d
                                ? 'Switch to 2D map'
                                : 'Switch to 3D map',
                            onTap: () => setState(() => _show3d = !_show3d),
                          ),
                        _MapButton(
                          icon: Icons.my_location,
                          tooltip: 'Refocus route',
                          // Re-fit the whole route above the sheet at its current size.
                          onTap: () => _refit(_sheetSize.value),
                        ),
                      ],
                    ),
                  ),
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: _initialSheet,
                  minChildSize: _minSheet,
                  maxChildSize: _maxSheet,
                  snap: true,
                  snapSizes: _snapSizes,
                  builder: (context, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radius),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: PrimaryScrollController(
                      controller: scrollController,
                      child: sheetContent,
                    ),
                  ),
                ),
                // Above the sheet so the back/close button stays tappable at full height.
                ValueListenableBuilder<bool>(
                  valueListenable: _fullNotifier,
                  builder: (context, full, _) => PopScope(
                    // System back at full height closes the sheet first, like the button.
                    canPop: !full,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) _collapseSheet();
                    },
                    child: _TopBar(
                      full: full,
                      title: activityLabel(activity.type),
                      height: topInset + _topBarHeight,
                      onBack: full
                          ? _collapseSheet
                          : () => Navigator.of(context).pop(),
                      trailing: _MapButton(
                        icon: Icons.share_outlined,
                        tooltip: 'Share activity',
                        onTap: () => showActivityShareSheet(
                          context,
                          activity,
                          isMine: widget.isMine,
                        ),
                      ),
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

  /// Sheet content top to bottom, in Strava's order; sections without data are left out.
  List<Widget> _sections(BuildContext context, Activity activity) {
    final theme = Theme.of(context);
    final samples = activity.samples;
    final hasAltitude = samples.where((s) => s.altitudeM != null).length > 1;
    final hasSpeed = samples.where((s) => (s.speedMs ?? 0) > 0.5).length > 1;
    final hasHr = samples.where((s) => s.heartRate != null).length > 1;
    final xKm = [for (final s in samples) s.distanceM / 1000];
    final altitudes = [for (final s in samples) s.altitudeM];
    final maxAltitude = altitudes.whereType<double>().fold<double?>(
      null,
      (m, v) => m == null || v > m ? v : m,
    );
    final elapsed = activity.elapsed > activity.duration
        ? activity.elapsed
        : Duration.zero;
    final fastest = activity.splits.isEmpty
        ? null
        : activity.splits.reduce((a, b) => a < b ? a : b);
    final mine = widget.isMine;

    return [
      _AuthorRow(activity: activity),
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                activity.title,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(width: 10),
            _TypePill(label: activityLabel(activity.type)),
          ],
        ),
      ),
      _StatGrid(activity: activity),
      if (activity.weather case final weather?) _WeatherRow(weather: weather),
      if (activity.notes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _NotesCard(notes: activity.notes),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KudosBar(
              count: _kudos.count,
              mine: _kudos.mine,
              // The API allows no kudos on your own activity.
              onKudos: mine ? null : _toggleKudos,
              onShare: () =>
                  showActivityShareSheet(context, activity, isMine: mine),
            ),
            const Divider(height: 24),
          ],
        ),
      ),
      // Same note as the web: someone else's activity whose .fit couldn't give records.
      if (samples.isEmpty && !mine)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Simple route - splits, elevation and pace appear when the owner shares this activity again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      if (hasAltitude)
        _ChartSection(
          title: 'Elevation',
          chart: ActivityStreamChart(
            xKm: xKm,
            values: altitudes,
            color: theme.colorScheme.onSurfaceVariant,
            format: (v) => v.round().toString(),
            unit: 'm',
          ),
          rows: [
            ('Elevation Gain', '${activity.elevationGainM} m'),
            if (maxAltitude != null)
              ('Max Elevation', '${maxAltitude.round()} m'),
          ],
        ),
      if (hasSpeed)
        _ChartSection(
          title: 'Pace',
          chart: ActivityStreamChart(
            xKm: xKm,
            // shortcut: pace capped at 30:00/km so stops don't flatten the chart; per-km splits stay exact.
            values: [
              for (final s in samples)
                (s.speedMs ?? 0) > 0.5
                    ? math.min(1000 / s.speedMs!, 1800)
                    : null,
            ],
            color: _paceBlue,
            format: (v) => formatSplit(Duration(seconds: v.round())),
            unit: '/km',
            background: hasAltitude ? altitudes : null,
            inverted: true,
          ),
          rows: [
            ('Avg Pace', formatPace(activity.pace)),
            ('Moving Time', formatSplit(activity.duration)),
            if (elapsed > Duration.zero && activity.distanceKm > 0) ...[
              (
                'Avg Elapsed Pace',
                formatPace(
                  Duration(
                    seconds: (elapsed.inSeconds / activity.distanceKm).round(),
                  ),
                ),
              ),
              ('Elapsed Time', formatSplit(elapsed)),
            ],
            if (fastest != null) ('Fastest Split', formatPace(fastest)),
          ],
        )
      else if (activity.distanceKm > 0)
        _ChartSection(
          title: 'Pace',
          rows: [
            ('Avg Pace', formatPace(activity.pace)),
            ('Moving Time', formatSplit(activity.duration)),
            if (elapsed > Duration.zero) ('Elapsed Time', formatSplit(elapsed)),
          ],
        ),
      if (hasHr)
        _ChartSection(
          title: 'Heart Rate',
          chart: ActivityStreamChart(
            xKm: xKm,
            values: [for (final s in samples) s.heartRate],
            color: _heartRed,
            format: (v) => v.round().toString(),
            unit: 'bpm',
          ),
          rows: [
            if (activity.avgHr != null)
              ('Avg Heart Rate', '${activity.avgHr} bpm'),
            if (activity.maxHr != null)
              ('Max Heart Rate', '${activity.maxHr} bpm'),
          ],
        ),
      if (activity.splits.isNotEmpty) ...[
        const SizedBox(height: 28),
        const _SectionLabel('Splits per KM'),
        const SizedBox(height: 10),
        _SplitsCard(activity: activity),
      ],
    ];
  }
}

const _paceBlue = Color(0xFF5B9BE6);
const _heartRed = Color(0xFFE5484D);

/// Fades and lifts a sheet section in, each one a beat after the one above.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = math.min(index, 8) * 60;
    final total = 380 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _WeatherRow extends StatelessWidget {
  const _WeatherRow({required this.weather});
  final ActivityWeather weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = weather;
    final parts = [
      if (w.temperatureC != null) '${w.temperatureC!.round()} °C',
      if (w.feelsLikeC != null) 'Feels like ${w.feelsLikeC!.round()} °C',
      if (w.humidityPct != null) 'Humidity ${w.humidityPct!.round()}%',
      if (w.windSpeedMs != null)
        'Wind ${(w.windSpeedMs! * 3.6).toStringAsFixed(1)} km/h'
            '${w.windDirectionDeg == null ? '' : ' from ${_compass(w.windDirectionDeg!)}'}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.thermostat_outlined,
            size: 24,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${parts.join('. ')}.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  static String _compass(double deg) => const [
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW',
  ][((deg % 360) / 45).round() % 8];
}

/// Title, optional chart, then label/value rows - one Strava detail block.
class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, this.chart, required this.rows});
  final String title;
  final Widget? chart;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(title),
          if (chart != null) ...[const SizedBox(height: 16), chart!],
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

/// Back button + share over the map; at full sheet height it becomes Strava's bar:
/// solid background, title, and the back arrow turns down into "close sheet".
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.full,
    required this.title,
    required this.height,
    required this.onBack,
    required this.trailing,
  });
  final bool full;
  final String title;
  final double height;
  final VoidCallback onBack;
  final Widget trailing;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        IgnorePointer(
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            height: height,
            color: full ? scheme.surface : scheme.surface.withValues(alpha: 0),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 18),
            child: AnimatedOpacity(
              duration: _duration,
              opacity: full ? 1 : 0,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                _MapButton(
                  // arrow_back turned a quarter counter-clockwise points down.
                  tooltip: full ? 'Close sheet' : 'Back',
                  onTap: onBack,
                  child: AnimatedRotation(
                    turns: full ? -0.25 : 0,
                    duration: _duration,
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                trailing,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    this.icon,
    this.label,
    this.child,
    required this.tooltip,
    required this.onTap,
  }) : assert(
         (icon == null ? 0 : 1) +
                 (label == null ? 0 : 1) +
                 (child == null ? 0 : 1) ==
             1,
       );
  final IconData? icon;
  final String? label;

  /// Custom content, e.g. an animated icon.
  final Widget? child;
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
                child:
                    child ??
                    (label != null
                        ? Text(
                            label!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.onSurface,
                            ),
                          )
                        : Icon(icon, size: 22, color: scheme.onSurface)),
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      formatRelativeDate(activity.startedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (activity.location.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        activity.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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
        style: TextStyle(
          color: scheme.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
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
    // Each value counts up from zero as the sheet opens.
    final stats = <({String label, String Function(double t) value})>[
      (
        label: 'Distance',
        value: (t) => formatDistance(activity.distanceKm * t),
      ),
      (label: 'Avg Pace', value: (t) => formatPace(activity.pace)),
      (label: 'Moving Time', value: (t) => formatSplit(activity.duration * t)),
      (
        label: 'Elevation Gain',
        value: (t) => '${(activity.elevationGainM * t).round()} m',
      ),
      if (activity.avgHr != null)
        (
          label: 'Avg Heart Rate',
          value: (t) => '${(activity.avgHr! * t).round()} bpm',
        ),
      if (activity.calories > 0)
        (
          label: 'Calories',
          value: (t) => '${(activity.calories * t).round()} Cal',
        ),
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
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) =>
                      _Stat(label: stat.label, value: stat.value(t)),
                ),
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
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatSplit(activity.splits[i]),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatPace(
                        Duration(seconds: activity.splits[i].inSeconds),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
    return Text(
      text,
      style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
    );
  }
}
