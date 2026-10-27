import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/mock/mock_accounts.dart';
import 'package:nubisport_flutter/features/activities/data/repositories/mock_activity_repository.dart';

void main() {
  group('MockActivityRepository', () {
    late MockActivityRepository repo;

    setUp(() => repo = MockActivityRepository(latency: Duration.zero));

    test('my activities are scoped to the signed-in account, newest first', () async {
      final ahliItems = await repo.myActivities(userId: MockAccounts.ahli.id);

      expect(ahliItems, isNotEmpty);
      expect(ahliItems.every((activity) => activity.userId == MockAccounts.ahli.id), isTrue);
      for (var i = 1; i < ahliItems.length; i++) {
        expect(
          ahliItems[i - 1].startedAt.isAfter(ahliItems[i].startedAt) ||
              ahliItems[i - 1].startedAt.isAtSameMomentAs(ahliItems[i].startedAt),
          isTrue,
        );
      }

      final adminItems = await repo.myActivities(userId: MockAccounts.admin.id);
      expect(adminItems, isNotEmpty);
      expect(adminItems.every((activity) => activity.userId == MockAccounts.admin.id), isTrue);
    });

    test('feed includes other runners and detail resolves by id', () async {
      final feed = await repo.feed();

      expect(feed.any((activity) => activity.userId != MockAccounts.ahli.id), isTrue);
      final detail = await repo.activity(feed.first.id);
      expect(detail?.id, feed.first.id);
      expect(await repo.activity('missing'), isNull);
    });
  });
}
