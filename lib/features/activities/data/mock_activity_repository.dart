import '../../../core/mock/mock_accounts.dart';
import '../domain/activity.dart';
import '../domain/activity_repository.dart';

/// Seeded activities for the UI until the training API exists.
///
/// Every `userId`/`userName` comes from [MockAccounts], so signing in as any
/// demo account shows that account's own runs in "Aktiviti saya".
class MockActivityRepository implements ActivityRepository {
  MockActivityRepository({this.latency = const Duration(milliseconds: 450)});

  /// Stand-in for network time; tests pass [Duration.zero].
  final Duration latency;

  static final List<Activity> _activities = [
    Activity(
      id: 'a1',
      userId: MockAccounts.ahli.id,
      userName: MockAccounts.ahli.name,
      title: 'Larian Subuh Taman Botani',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 25, 6, 30),
      distanceKm: 5.02,
      duration: const Duration(minutes: 28, seconds: 41),
      location: 'Taman Botani, Shah Alam',
      latitude: 3.0733,
      longitude: 101.5185,
      route: const [
        GeoPoint(3.0715, 101.5155),
        GeoPoint(3.0740, 101.5180),
        GeoPoint(3.0755, 101.5210),
        GeoPoint(3.0725, 101.5235),
        GeoPoint(3.0700, 101.5200),
      ],
      elevationGainM: 42,
      calories: 310,
      kudos: 12,
      notes: 'Kaki rasa ringan hari ini. Simpan pace mudah, fokus pernafasan.',
      splits: const [
        Duration(minutes: 5, seconds: 12),
        Duration(minutes: 5, seconds: 38),
        Duration(minutes: 5, seconds: 49),
        Duration(minutes: 5, seconds: 46),
        Duration(minutes: 6, seconds: 16),
      ],
    ),
    Activity(
      id: 'a2',
      userId: MockAccounts.ahli.id,
      userName: MockAccounts.ahli.name,
      title: 'Easy Run Sungai Klang',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 22, 18, 45),
      distanceKm: 8.1,
      duration: const Duration(minutes: 47, seconds: 5),
      location: 'Taman Tasik Titiwangsa',
      latitude: 3.1785,
      longitude: 101.7000,
      route: const [
        GeoPoint(3.1760, 101.6960),
        GeoPoint(3.1800, 101.6990),
        GeoPoint(3.1815, 101.7035),
        GeoPoint(3.1775, 101.7050),
        GeoPoint(3.1745, 101.7010),
      ],
      elevationGainM: 18,
      calories: 480,
      kudos: 8,
      notes: 'Larian santai selepas kerja. Cuaca elok, tak panas.',
      splits: const [
        Duration(minutes: 5, seconds: 48),
        Duration(minutes: 5, seconds: 52),
        Duration(minutes: 5, seconds: 45),
        Duration(minutes: 5, seconds: 50),
        Duration(minutes: 5, seconds: 57),
        Duration(minutes: 5, seconds: 55),
        Duration(minutes: 6, seconds: 2),
        Duration(minutes: 5, seconds: 56),
      ],
    ),
    Activity(
      id: 'a3',
      userId: MockAccounts.ahli.id,
      userName: MockAccounts.ahli.name,
      title: 'Long Run Bukit Cahaya',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 19, 6, 10),
      distanceKm: 15.3,
      duration: const Duration(hours: 1, minutes: 38, seconds: 20),
      location: 'Bukit Cahaya Seri Alam',
      latitude: 3.1833,
      longitude: 101.5167,
      route: const [
        GeoPoint(3.1790, 101.5110),
        GeoPoint(3.1825, 101.5145),
        GeoPoint(3.1860, 101.5175),
        GeoPoint(3.1880, 101.5210),
        GeoPoint(3.1840, 101.5230),
      ],
      elevationGainM: 210,
      calories: 980,
      kudos: 21,
      notes: 'Long run pertama untuk blok 21K. Simpan tenaga di separuh kedua.',
      splits: const [
        Duration(minutes: 6, seconds: 10),
        Duration(minutes: 6, seconds: 14),
        Duration(minutes: 6, seconds: 21),
        Duration(minutes: 6, seconds: 28),
        Duration(minutes: 6, seconds: 35),
        Duration(minutes: 6, seconds: 42),
      ],
    ),
    Activity(
      id: 'a4',
      userId: MockAccounts.aina.id,
      userName: MockAccounts.aina.name,
      title: 'Interval 6x400m',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 26, 6, 5),
      distanceKm: 4.82,
      duration: const Duration(minutes: 24, seconds: 10),
      location: 'Stadium Mini Seksyen 13',
      latitude: 3.0667,
      longitude: 101.5000,
      route: const [
        GeoPoint(3.0655, 101.4985),
        GeoPoint(3.0675, 101.4990),
        GeoPoint(3.0680, 101.5015),
        GeoPoint(3.0660, 101.5020),
        GeoPoint(3.0655, 101.4985),
      ],
      elevationGainM: 5,
      calories: 290,
      kudos: 34,
      notes: 'Split konsisten 1:38–1:42. Rehat 90s antara set.',
    ),
    Activity(
      id: 'a5',
      userId: MockAccounts.haziq.id,
      userName: MockAccounts.haziq.name,
      title: 'Trail Run Bukit Gasing',
      type: ActivityType.hike,
      startedAt: DateTime(2026, 10, 25, 7, 15),
      distanceKm: 10.62,
      duration: const Duration(hours: 1, minutes: 12, seconds: 40),
      location: 'Bukit Gasing, Petaling Jaya',
      latitude: 3.1017,
      longitude: 101.6500,
      route: const [
        GeoPoint(3.0990, 101.6460),
        GeoPoint(3.1025, 101.6485),
        GeoPoint(3.1045, 101.6515),
        GeoPoint(3.1010, 101.6540),
        GeoPoint(3.0980, 101.6510),
      ],
      elevationGainM: 330,
      calories: 720,
      kudos: 27,
      notes: 'Denai licin lepas hujan. Kasut trail memang berbaloi.',
    ),
    Activity(
      id: 'a6',
      userId: MockAccounts.meiLing.id,
      userName: MockAccounts.meiLing.name,
      title: 'Recovery Walk',
      type: ActivityType.walk,
      startedAt: DateTime(2026, 10, 24, 20, 10),
      distanceKm: 3.2,
      duration: const Duration(minutes: 35, seconds: 20),
      location: 'KLCC Park',
      latitude: 3.1578,
      longitude: 101.7120,
      route: const [
        GeoPoint(3.1555, 101.7095),
        GeoPoint(3.1585, 101.7105),
        GeoPoint(3.1595, 101.7140),
        GeoPoint(3.1565, 101.7150),
        GeoPoint(3.1545, 101.7120),
      ],
      elevationGainM: 8,
      calories: 140,
      kudos: 15,
      notes: 'Jalan santai untuk kurangkan sakit otot.',
    ),
    Activity(
      id: 'a7',
      userId: MockAccounts.farid.id,
      userName: MockAccounts.farid.name,
      title: 'Ride Santai Putrajaya',
      type: ActivityType.ride,
      startedAt: DateTime(2026, 10, 23, 17, 0),
      distanceKm: 24.5,
      duration: const Duration(hours: 1, minutes: 5),
      location: 'Presint 2, Putrajaya',
      latitude: 2.9264,
      longitude: 101.6964,
      route: const [
        GeoPoint(2.9210, 101.6900),
        GeoPoint(2.9270, 101.6920),
        GeoPoint(2.9310, 101.6970),
        GeoPoint(2.9265, 101.7010),
        GeoPoint(2.9205, 101.6980),
      ],
      elevationGainM: 120,
      calories: 520,
      kudos: 9,
      notes: 'Kayuh perlahan, banyak berhenti ambil gambar.',
    ),
    Activity(
      id: 'a8',
      userId: MockAccounts.admin.id,
      userName: MockAccounts.admin.name,
      title: 'Shakeout Run Presint 1',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 21, 6, 20),
      distanceKm: 4.2,
      duration: const Duration(minutes: 23, seconds: 50),
      location: 'Presint 1, Putrajaya',
      latitude: 2.9270,
      longitude: 101.6900,
      route: const [
        GeoPoint(2.9240, 101.6870),
        GeoPoint(2.9280, 101.6890),
        GeoPoint(2.9300, 101.6925),
        GeoPoint(2.9260, 101.6940),
        GeoPoint(2.9235, 101.6905),
      ],
      elevationGainM: 30,
      calories: 260,
      kudos: 6,
      notes: 'Shakeout santai sebelum sesi komuniti hujung minggu.',
    ),
  ];

  @override
  Future<List<Activity>> myActivities({required int userId}) async {
    await _wait();
    return _sorted(_activities.where((activity) => activity.userId == userId));
  }

  @override
  Future<List<Activity>> feed() async {
    await _wait();
    return _sorted(_activities);
  }

  @override
  Future<Activity?> activity(String id) async {
    await _wait();
    for (final activity in _activities) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  List<Activity> _sorted(Iterable<Activity> items) {
    final list = items.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  Future<void> _wait() => Future<void>.delayed(latency);
}
