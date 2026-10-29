import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/data/repositories/activity_repository_provider.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/domain/repositories/activity_repository.dart';
import 'package:nubisport_flutter/features/activities/presentation/controllers/kudos_controller.dart';
import 'package:nubisport_flutter/features/auth/domain/models/app_user.dart';

class _Repo implements ActivityRepository {
  _Repo({this.fail = false});
  final bool fail;
  final sent = <bool>[];

  @override
  Future<({int count, bool mine})> setKudos(
    String id, {
    required bool on,
  }) async {
    sent.add(on);
    if (fail) throw Exception('offline');
    return (count: on ? 9 : 8, mine: on); // the server's count wins
  }

  @override
  Future<List<Activity>> myActivities({required AppUser user}) =>
      throw UnimplementedError();
  @override
  Future<List<Activity>> feed({AppUser? viewer}) => throw UnimplementedError();
  @override
  Future<Activity?> activity(String id, {AppUser? viewer}) =>
      throw UnimplementedError();
}

final _activity = Activity(
  id: '5',
  userId: 0,
  userName: 'Mira',
  title: 'Run',
  type: ActivityType.run,
  startedAt: DateTime(2026, 10, 26),
  distanceKm: 5,
  duration: const Duration(minutes: 30),
  location: '',
  latitude: 0,
  longitude: 0,
  route: const [],
  elevationGainM: 0,
  kudos: 2,
);

void main() {
  test('kudos flips at once, then keeps the server count', () async {
    final repo = _Repo();
    final c = ProviderContainer(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(kudosProvider(_activity), (_, _) {});

    final sending = c.read(kudosProvider(_activity).notifier).toggle();
    expect(sub.read(), (count: 3, mine: true));
    expect(await sending, isTrue);
    expect(sub.read(), (count: 9, mine: true));
    expect(repo.sent, [true]);
  });

  test('a failed kudos rolls back and reports it', () async {
    final c = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(_Repo(fail: true)),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(kudosProvider(_activity), (_, _) {});

    expect(await c.read(kudosProvider(_activity).notifier).toggle(), isFalse);
    expect(sub.read(), (count: 2, mine: false));
  });

  test(
    'a toggled count survives nobody watching it (feed row scrolled away)',
    () async {
      final c = ProviderContainer(
        overrides: [activityRepositoryProvider.overrideWithValue(_Repo())],
      );
      addTearDown(c.dispose);
      final sub = c.listen(kudosProvider(_activity), (_, _) {});
      await c.read(kudosProvider(_activity).notifier).toggle();
      sub.close();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(kudosProvider(_activity)), (count: 9, mine: true));
    },
  );
}
