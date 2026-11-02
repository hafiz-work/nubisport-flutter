import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_share_sheet.dart';

void main() {
  testWidgets('activity share sheet shows the custom template', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final activity = Activity(
      id: 'share-card',
      userId: 1,
      userName: 'Demo Member',
      title: 'Botanic Garden Morning Run',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 25, 6, 30),
      distanceKm: 5.02,
      duration: const Duration(minutes: 28, seconds: 41),
      location: 'Taman Botani, Shah Alam',
      latitude: 3.0733,
      longitude: 101.5185,
      elevationGainM: 42,
      route: const [
        GeoPoint(3.0715, 101.5155),
        GeoPoint(3.0740, 101.5180),
        GeoPoint(3.0755, 101.5210),
        GeoPoint(3.0725, 101.5235),
        GeoPoint(3.0700, 101.5200),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    showActivityShareSheet(context, activity, isMine: true),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share activity'), findsOneWidget);
    expect(find.byType(ActivityShareCard), findsOneWidget);
    expect(find.text('Share image'), findsOneWidget);
    expect(find.text('Copy caption'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);

    // Every template renders without overflow.
    for (final t in ShareTemplate.values) {
      final tile = find.byKey(ValueKey(t));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.textContaining(t.hint), findsOneWidget);
      expect(tester.takeException(), isNull, reason: t.label);
    }
    expect(tester.takeException(), isNull);
  });

  group('save to Photos', () {
    final mine = Activity(
      id: 'save-me',
      userId: 1,
      userName: 'Demo Member',
      title: 'Morning Run',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 25, 6, 30),
      distanceKm: 5,
      duration: const Duration(minutes: 30),
      location: 'Shah Alam',
      latitude: 3.07,
      longitude: 101.51,
      elevationGainM: 10,
      route: const [
        GeoPoint(3.0715, 101.5155),
        GeoPoint(3.0740, 101.5180),
        GeoPoint(3.0755, 101.5210),
      ],
    );
    final original = saveImageToGallery;
    tearDown(() => saveImageToGallery = original);

    Future<void> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showActivityShareSheet(context, mine, isMine: true),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
    }

    // The PNG capture (toImage) runs on the engine, so the tap + save happen inside runAsync.
    Future<void> tapAndWait(WidgetTester tester, Finder button) async {
      await tester.runAsync(() async {
        await tester.tap(button);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();
    }

    testWidgets('saves the selected template as a PNG and says so', (
      tester,
    ) async {
      Uint8List? saved;
      String? name;
      saveImageToGallery = (png, n) async => (saved = png, name = n);
      await openSheet(tester);

      await tapAndWait(tester, find.text('Save image'));

      expect(saved, isNotNull);
      expect(saved!.sublist(0, 4), [
        0x89,
        0x50,
        0x4E,
        0x47,
      ], reason: 'PNG signature');
      expect(name, 'nubi-save-me-classic');
      expect(find.text('Image saved to Photos.'), findsOneWidget);
    });

    testWidgets('a transparent template is saved as a sticker', (tester) async {
      String? name;
      saveImageToGallery = (png, n) async => name = n;
      await openSheet(tester);
      final tile = find.byKey(const ValueKey(ShareTemplate.statsSticker));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();

      await tapAndWait(tester, find.text('Save sticker'));

      expect(name, 'nubi-save-me-statsSticker');
      expect(find.text('Sticker saved to Photos.'), findsOneWidget);
    });

    testWidgets('denied Photos access points to Settings', (tester) async {
      saveImageToGallery = (png, n) async => throw GalException(
        type: GalExceptionType.accessDenied,
        platformException: PlatformException(code: 'ACCESS_DENIED'),
        stackTrace: StackTrace.current,
      );
      await openSheet(tester);

      await tapAndWait(tester, find.text('Save image'));

      expect(
        find.text('Allow Photos access in Settings to save images.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'someone else\'s activity gets the simple sheet without templates',
    (tester) async {
      final activity = Activity(
        id: 'other',
        userId: 2,
        userName: 'Orang Lain',
        title: 'Evening Run',
        type: ActivityType.run,
        startedAt: DateTime(2026, 10, 25, 18),
        distanceKm: 3,
        duration: const Duration(minutes: 18),
        location: 'Shah Alam',
        latitude: 3.07,
        longitude: 101.51,
        elevationGainM: 10,
        route: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showActivityShareSheet(context, activity, isMine: false),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(find.text('Share to'), findsOneWidget);
      expect(find.byType(ActivityShareCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a public activity offers Copy link and puts the link in the caption',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final public = Activity(
        id: '12',
        userId: 1,
        userName: 'Demo Member',
        title: 'Morning Run',
        type: ActivityType.run,
        startedAt: DateTime(2026, 10, 25, 6, 30),
        distanceKm: 5,
        duration: const Duration(minutes: 30),
        location: 'Shah Alam',
        latitude: 3.07,
        longitude: 101.51,
        publicUrl: 'https://nubi.test/a/12',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showActivityShareSheet(context, public, isMine: true),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy link'));
      await tester.pump();
      await tester.tap(find.text('Copy caption'));
      await tester.pump();
      expect(copied.first, 'https://nubi.test/a/12');
      expect(copied.last, contains('https://nubi.test/a/12'));
      expect(find.text('Caption copied.'), findsOneWidget);
    },
  );

  test('share images drop the first and last 200 m of the route', () {
    // ~1.1 km north, a point every ~111 m.
    final route = [
      for (var i = 0; i <= 10; i++) GeoPoint(3.07 + i * 0.001, 101.51),
    ];
    final kept = shareRoute(route);
    expect(kept.first.latitude, closeTo(3.072, 1e-9));
    expect(kept.last.latitude, closeTo(3.078, 1e-9));
    expect(
      shareRoute(route.sublist(0, 3)),
      isEmpty,
    ); // 222 m: nothing safe to draw
    expect(shareRoute(const []), isEmpty);
  });
}
