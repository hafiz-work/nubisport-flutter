import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/charts/nubi_line_chart.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../../../activities/domain/models/activity.dart';
import '../../../activities/presentation/activity_format.dart';
import '../../../activities/presentation/controllers/activity_providers.dart';
import '../../../activities/presentation/widgets/activity_card.dart';
import '../../../activities/presentation/widgets/activity_empty_state.dart';
import '../../../activities/presentation/widgets/activity_share_sheet.dart';
import '../../../auth/domain/models/app_user.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _tabIndex = 0;
  ActivityType? _sport;

  AppUser get user => widget.user;

  String get _initial {
    final name = user.name.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  String get _membershipLabel {
    if (user.role == 'owner' || user.role == 'admin' || user.apps['nubi'] == 'admin') return 'Admin';
    if (user.isMember) return 'Active member';
    return 'Not a member';
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.index == _tabIndex) return;
    setState(() => _tabIndex = _tabs.index);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _shareProfile() async {
    final handle = user.username.isEmpty ? null : 'https://nubisport.hafizbahtiar.com/u/${user.username}';
    await SharePlus.instance.share(
      ShareParams(
        text: '${user.name} di Nubi Sport${handle == null ? '' : '\n$handle'}',
        subject: 'Nubi Sport · ${user.name}',
      ),
    );
  }

  void _setSport(ActivityType? type) => setState(() => _sport = type);

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon.')));
  }

  Future<void> _openProgressDetails(List<double> values, DateTime weekStart) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    await FamilyModalSheet.showMaterialDefault<void>(
      context: context,
      contentBackgroundColor: scheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        return SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('Past 12 weeks', style: sheetTheme.textTheme.titleLarge)),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: values.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: sheetTheme.colorScheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final weekIndex = values.length - 1 - index;
                      final start = weekStart.subtract(Duration(days: 7 * index));
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text(_weekRange(start), style: sheetTheme.textTheme.bodyMedium)),
                            Text(
                              formatDistance(values[weekIndex]),
                              style: sheetTheme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activitiesAsync = ref.watch(myActivitiesProvider);
    final allActivities = activitiesAsync.value ?? const <Activity>[];
    final activities = _sport == null
        ? allActivities
        : allActivities.where((activity) => activity.type == _sport).toList();

    final weekStart = _startOfWeek(DateTime.now());
    final week = _activitiesInWeek(activities, weekStart);
    final lastWeek = _activitiesInWeek(activities, weekStart.subtract(const Duration(days: 7)));
    final weekDistance = _distance(week);
    final weekTime = _duration(week);
    final weekElevation = _elevation(week);
    final lastWeekTime = _duration(lastWeek);
    final chart = _weeklyDistances(activities, 12);
    final streak = _weekStreak(chart);
    final activeWeekdays = week.map((activity) => activity.startedAt.weekday).toSet();

    final children = switch (_tabIndex) {
      0 => _progressChildren(
        activities: activities,
        weekStart: weekStart,
        weekDistance: weekDistance,
        weekTime: weekTime,
        weekElevation: weekElevation,
        lastWeekTime: lastWeekTime,
        chart: chart,
        streak: streak,
        activeWeekdays: activeWeekdays,
      ),
      1 => _activityChildren(activitiesAsync, allActivities),
      _ => _moreChildren(context, allActivities),
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => AppNavigator.push<void>(context, AppRoutes.settings),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _ProfileSliverHeader(
                user: user,
                initial: _initial,
                membership: _membershipLabel,
                activityCount: allActivities.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => AppNavigator.editProfile(context, user),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit profile'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareProfile,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share profile'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '0 pengikut · 0 mengikuti',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              background: scheme.surface,
              tabBar: TabBar(
                controller: _tabs,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: AppColors.orange,
                dividerColor: scheme.outlineVariant,
                tabs: const [
                  Tab(icon: Icon(Icons.show_chart), text: 'Progress'),
                  Tab(icon: Icon(Icons.directions_run), text: 'Activities'),
                  Tab(icon: Icon(Icons.menu), text: 'More'),
                ],
              ),
            ),
          ),
          SliverPadding(
            // Activity tab is full-bleed like the feed; other tabs stay inset.
            padding: EdgeInsets.fromLTRB(_tabIndex == 1 ? 0 : 20, 16, _tabIndex == 1 ? 0 : 20, 140),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }

  List<Widget> _progressChildren({
    required List<Activity> activities,
    required DateTime weekStart,
    required double weekDistance,
    required Duration weekTime,
    required int weekElevation,
    required Duration lastWeekTime,
    required List<double> chart,
    required int streak,
    required Set<int> activeWeekdays,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return [
      _SportFilter(selected: _sport, onChanged: _setSport),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              _weekRange(weekStart),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _MiniStat(label: 'Distance', value: formatDistance(weekDistance)),
          ),
          Expanded(
            child: _MiniStat(label: 'Time', value: formatDuration(weekTime)),
          ),
          Expanded(
            child: _MiniStat(label: 'Elev gain', value: '$weekElevation m'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _WeeklyChartCard(values: chart, weekStart: weekStart, onSeeMore: () => _openProgressDetails(chart, weekStart)),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StreakCard(weeks: streak)),
            const SizedBox(width: 12),
            Expanded(
              child: _TrainingLogCard(thisWeek: weekTime, lastWeek: lastWeekTime, activeWeekdays: activeWeekdays),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _InstantWorkoutCard(onTap: () => _comingSoon('Instant workout')),
      const SizedBox(height: 12),
      _PerformanceCard(fiveK: _bestEffort(activities, 5), trend: chart),
      const SizedBox(height: 12),
      _RelativeEffortCard(score: (weekDistance * 8).round()),
      const SizedBox(height: 12),
      _FitnessCard(score: weekDistance.round(), trend: chart),
      const SizedBox(height: 12),
      _SuggestedGoalCard(
        distanceKm: weekDistance,
        onSetGoal: () => _comingSoon('Weekly goal'),
        onCustomize: () => _comingSoon('Customize goal'),
      ),
      const SizedBox(height: 12),
      const _TrainingZonesCard(),
      const SizedBox(height: 12),
      _BestEffortsCard(
        oneK: _bestEffort(activities, 1),
        twoMile: _bestEffort(activities, 3.218),
        fiveK: _bestEffort(activities, 5),
      ),
      const SizedBox(height: 16),
      Card(
        child: _ActionRow(
          icon: Icons.event_note_outlined,
          label: 'Training plan',
          detail: '5K plan and time targets',
          onTap: () => AppNavigator.push<void>(context, AppRoutes.trainingPlans),
        ),
      ),
    ];
  }

  List<Widget> _activityChildren(AsyncValue<List<Activity>> async, List<Activity> activities) => [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _SectionTitle('${activities.length} activities')),
          TextButton(onPressed: () => AppNavigator.push<void>(context, AppRoutes.activities), child: const Text('All')),
        ],
      ),
    ),
    const SizedBox(height: 8),
    if (async.isLoading)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      )
    else if (activities.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: ActivityEmptyState(
          icon: Icons.directions_run,
          title: 'No activities yet',
          message: 'Your runs will appear here.',
        ),
      )
    else
      for (final activity in activities)
        ActivityCard(
          activity: activity,
          showUser: true,
          // Own activities: the API allows no kudos on them.
          kudosed: activity.kudosed,
          onShare: () => showActivityShareSheet(context, activity, isMine: true),
          onTap: () => AppNavigator.activityDetail(context, activity.id),
        ),
  ];

  List<Widget> _moreChildren(BuildContext context, List<Activity> activities) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final yearDistance = activities
        .where((activity) => activity.startedAt.year == DateTime.now().year)
        .fold<double>(0, (sum, activity) => sum + activity.distanceKm);
    return [
      Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            _MenuRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription overview',
              onTap: () => AppNavigator.push<void>(context, AppRoutes.settings),
            ),
            const Divider(height: 1),
            _MenuRow(
              icon: Icons.bar_chart,
              label: 'Statistics',
              detail: 'This year: ${formatDistance(yearDistance)}',
              onTap: () => AppNavigator.push<void>(context, AppRoutes.activities),
            ),
            const Divider(height: 1),
            _MenuRow(icon: Icons.place_outlined, label: 'Segments', detail: '—', onTap: () => _comingSoon('Segments')),
            const Divider(height: 1),
            _MenuRow(
              icon: Icons.directions_bike_outlined,
              label: 'Gear',
              detail: '—',
              onTap: () => _comingSoon('Gear'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('Challenges'),
      const SizedBox(height: 10),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Challenges to find motivation, build habits and earn rewards.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _comingSoon('New Challenges'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                child: const Text('Find new challenges'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(child: _SectionTitle('Trophy Case')),
          Text('4', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
      const SizedBox(height: 14),
      const Row(
        children: [
          Expanded(
            child: _TrophyBadge(value: '10', label: '10th'),
          ),
          Expanded(
            child: _TrophyBadge(value: '5', label: 'Fifth'),
          ),
          Expanded(
            child: _TrophyBadge(value: '3', label: 'Third'),
          ),
          Expanded(
            child: _TrophyBadge(value: '1', label: 'First'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => _comingSoon('All trophies'),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text('All trophies', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ];
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.tabBar, required this.background});
  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: background, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.background != background;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

List<Activity> _activitiesInWeek(List<Activity> activities, DateTime start) {
  final end = start.add(const Duration(days: 7));
  return activities.where((activity) {
    final day = DateTime(activity.startedAt.year, activity.startedAt.month, activity.startedAt.day);
    return !day.isBefore(start) && day.isBefore(end);
  }).toList();
}

String _weekRange(DateTime start) {
  final end = start.add(const Duration(days: 6));
  return '${start.day} ${_months[start.month - 1]} - ${end.day} ${_months[end.month - 1]} ${end.year}';
}

Duration? _bestEffort(List<Activity> activities, double km) {
  Duration? best;
  for (final activity in activities) {
    if (activity.distanceKm <= 0) continue;
    final Duration candidate;
    if (km == 1 && activity.splits.isNotEmpty) {
      candidate = activity.splits.reduce((a, b) => a < b ? a : b);
    } else if (km == km.roundToDouble() && activity.splits.length >= km.round()) {
      candidate = activity.splits.take(km.round()).fold(Duration.zero, (sum, split) => sum + split);
    } else {
      candidate = Duration(seconds: (activity.pace.inSeconds * km).round());
    }
    if (best == null || candidate < best) best = candidate;
  }
  return best;
}

double _distance(List<Activity> activities) => activities.fold(0, (sum, activity) => sum + activity.distanceKm);

Duration _duration(List<Activity> activities) =>
    activities.fold(Duration.zero, (sum, activity) => sum + activity.duration);

int _elevation(List<Activity> activities) => activities.fold(0, (sum, activity) => sum + activity.elevationGainM);

/// Calendar-week distances, oldest first; the last bucket is the current week.
List<double> _weeklyDistances(List<Activity> activities, int weeks) {
  final currentWeek = _startOfWeek(DateTime.now());
  final firstWeek = currentWeek.subtract(Duration(days: 7 * (weeks - 1)));
  final result = List<double>.filled(weeks, 0);
  for (final activity in activities) {
    final week = _startOfWeek(activity.startedAt);
    final index = week.difference(firstWeek).inDays ~/ 7;
    if (index >= 0 && index < weeks) result[index] += activity.distanceKm;
  }
  return result;
}

int _weekStreak(List<double> weeklyDistances) {
  var streak = 0;
  for (var i = weeklyDistances.length - 1; i >= 0; i--) {
    if (weeklyDistances[i] > 0) {
      streak++;
    } else if (i != weeklyDistances.length - 1) {
      break;
    }
  }
  return streak;
}

class _ProfileSliverHeader extends StatelessWidget {
  const _ProfileSliverHeader({
    required this.user,
    required this.initial,
    required this.membership,
    required this.activityCount,
  });
  final AppUser user;
  final String initial;
  final String membership;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = user.isMember || user.role != 'user';
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/profile_cover.jpg', fit: BoxFit.cover, alignment: Alignment.center),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.35), AppColors.navy.withValues(alpha: 0.55), AppColors.navy],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Barlow Condensed',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$activityCount activities',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onDarkMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onDarkMuted),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: highlighted ? AppColors.orange : Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(AppTheme.radius),
                            ),
                            child: Text(
                              membership,
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18));
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
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
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
      ],
    );
  }
}

class _SportFilter extends StatelessWidget {
  const _SportFilter({required this.selected, required this.onChanged});
  final ActivityType? selected;
  final ValueChanged<ActivityType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _chip(context, label: 'All', icon: Icons.all_inclusive, value: null),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chip(context, label: 'Run', icon: Icons.directions_run, value: ActivityType.run),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chip(context, label: 'Walk', icon: Icons.directions_walk, value: ActivityType.walk),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, {required String label, required IconData icon, required ActivityType? value}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = selected == value;
    final radius = BorderRadius.circular(AppTheme.radius);
    return Material(
      color: isSelected ? AppColors.orange.withValues(alpha: 0.14) : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: isSelected ? AppColors.orange : scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.orange : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.orange : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard({required this.values, required this.weekStart, required this.onSeeMore});
  final List<double> values;
  final DateTime weekStart;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    final axisMax = math.max(8.0, (maxValue / 4).ceil() * 4.0);
    final lastValue = values.isEmpty ? 0.0 : values.last;
    final months = [
      _months[weekStart.subtract(const Duration(days: 77)).month - 1],
      _months[weekStart.subtract(const Duration(days: 35)).month - 1],
      _months[weekStart.month - 1],
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Past 12 weeks', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Semantics(
                      label: '12-week distance chart. Latest week ${lastValue.toStringAsFixed(1)} kilometres.',
                      child: NubiLineChart(
                        values: values,
                        axisMax: axisMax,
                        lineColor: AppColors.orange,
                        gridColor: scheme.outlineVariant,
                        markerColor: scheme.onSurface,
                        dotFill: scheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AxisLabel(_kmLabel(axisMax)),
                        _AxisLabel(_kmLabel(axisMax / 2)),
                        const _AxisLabel('0 km'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (final month in months) _MonthLabel(month)],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: onSeeMore, child: const Text('See more progress')),
            ),
          ],
        ),
      ),
    );
  }
}

String _kmLabel(double value) => value % 1 == 0 ? '${value.toInt()} km' : '${value.toStringAsFixed(1)} km';

class _MonthLabel extends StatelessWidget {
  const _MonthLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: 10,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 9.5),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.weeks});
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Streaks'),
            const SizedBox(height: 18),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.local_fire_department, size: 62, color: scheme.onSurface.withValues(alpha: 0.9)),
                  Text(
                    '$weeks',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.surface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('Weeks', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingLogCard extends StatelessWidget {
  const _TrainingLogCard({required this.thisWeek, required this.lastWeek, required this.activeWeekdays});
  final Duration thisWeek;
  final Duration lastWeek;
  final Set<int> activeWeekdays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Training Log'),
            const SizedBox(height: 12),
            Text('This week', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            Text(formatDuration(thisWeek), style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeWeekdays.contains(weekday) || weekday == DateTime.now().weekday
                              ? const Color(0xFF84CC16)
                              : scheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Last week', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Text(formatDuration(lastWeek), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstantWorkoutCard extends StatelessWidget {
  const _InstantWorkoutCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardHeader(title: 'Instant Workouts', trailing: 'This week'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          right: 6,
                          top: 6,
                          child: Icon(Icons.directions_run, color: Colors.white70, size: 46),
                        ),
                        const Positioned(
                          left: 10,
                          bottom: 10,
                          child: Text(
                            '6.0 km',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recovery Run', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Keep the legs moving without adding stress.',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.fiveK, required this.trend});
  final Duration? fiveK;
  final List<double> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Performance Predictions', trailing: 'Past 1 month'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('5K', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            fiveK == null ? '—' : formatSplit(fiveK!),
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                          ),
                          if (fiveK != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                              ),
                              child: const Text(
                                'PB',
                                style: TextStyle(color: AppColors.orange, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 44,
                  child: CustomPaint(
                    painter: _SparklinePainter(values: trend, color: const Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RelativeEffortCard extends StatelessWidget {
  const _RelativeEffortCard({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const purple = Color(0xFF7C3AED);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Relative Effort', trailing: 'This week'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '$score',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ),
                Text('16-32', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final fraction = (score / 48).clamp(0.0, 1.0);
                return SizedBox(
                  height: 18,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: 4,
                        bottom: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [purple.withValues(alpha: 0.18), purple]),
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (constraints.maxWidth - 3) * fraction,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: scheme.onSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FitnessCard extends StatelessWidget {
  const _FitnessCard({required this.score, required this.trend});
  final int score;
  final List<double> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Fitness', trailing: 'Past 1 month'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Score', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '$score',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 44,
                  child: CustomPaint(
                    painter: _SparklinePainter(values: trend, color: AppColors.orange),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedGoalCard extends StatelessWidget {
  const _SuggestedGoalCard({required this.distanceKm, required this.onSetGoal, required this.onCustomize});
  final double distanceKm;
  final VoidCallback onSetGoal;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Suggested Goal'),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
                  child: const Icon(Icons.directions_run, color: AppColors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('5 km per week', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${distanceKm.toStringAsFixed(2)} km / 5 km run',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: LinearProgressIndicator(
                value: (distanceKm / 5).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: scheme.outlineVariant,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: onSetGoal, child: const Text('Set goal')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(onPressed: onCustomize, child: const Text('Customize')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingZonesCard extends StatelessWidget {
  const _TrainingZonesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Training Zones', trailing: 'Past 1 month'),
            const SizedBox(height: 16),
            Text('Most time in pace zones', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              '46% in Zone 1',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const _ZoneBar(label: 'Z1', percent: 46, highlighted: true),
            const _ZoneBar(label: 'Z2', percent: 30),
            const _ZoneBar(label: 'Z3', percent: 18),
            const _ZoneBar(label: 'Z4', percent: 6),
          ],
        ),
      ),
    );
  }
}

class _ZoneBar extends StatelessWidget {
  const _ZoneBar({required this.label, required this.percent, this.highlighted = false});
  final String label;
  final int percent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = highlighted ? const Color(0xFF93C5FD) : scheme.onSurfaceVariant.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestEffortsCard extends StatelessWidget {
  const _BestEffortsCard({required this.oneK, required this.twoMile, required this.fiveK});
  final Duration? oneK;
  final Duration? twoMile;
  final Duration? fiveK;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(title: 'Best Efforts', trailing: 'Past 1 month'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _EffortBadge(label: '5K', value: fiveK, color: const Color(0xFFFACC15)),
                ),
                Expanded(
                  child: _EffortBadge(label: '2 mile', value: twoMile, color: const Color(0xFFCBD5E1)),
                ),
                Expanded(
                  child: _EffortBadge(label: '1K', value: oneK, color: const Color(0xFFD97706)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EffortBadge extends StatelessWidget {
  const _EffortBadge({required this.label, required this.value, required this.color});
  final String label;
  final Duration? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Icon(Icons.emoji_events, size: 38, color: color),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value == null ? '—' : formatSplit(value!),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) ...[
          Text(trailing!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 2),
        ],
        Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = math.max(1.0, values.reduce(math.max));
    const top = 4.0;
    final bottom = size.height - 4;
    final stepX = size.width / math.max(1, values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++) Offset(i * stepX, bottom - (values[i] / maxValue) * (bottom - top)),
    ];
    if (points.length < 2) return;

    final area = Path()
      ..moveTo(points.first.dx, bottom)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      area.lineTo(point.dx, point.dy);
    }
    area
      ..lineTo(points.last.dx, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.detail, required this.onTap});
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _TrophyBadge extends StatelessWidget {
  const _TrophyBadge({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CustomPaint(size: Size(58, 58), painter: _OctagonPainter()),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _OctagonPainter extends CustomPainter {
  const _OctagonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cut = w * 0.3;
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(w - cut, 0)
      ..lineTo(w, cut)
      ..lineTo(w, h - cut)
      ..lineTo(w - cut, h)
      ..lineTo(cut, h)
      ..lineTo(0, h - cut)
      ..lineTo(0, cut)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy2, AppColors.navy],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _OctagonPainter oldDelegate) => false;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.detail, required this.onTap});
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
