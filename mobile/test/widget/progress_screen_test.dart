// T117 — written before the progress screen (FR-039, FR-040, FR-041). Offline: every value comes
// from the device DB; the fake API fails on any network use.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/progress/ui/progress_screen.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

import '../helpers/workout_fixtures.dart';
import '../unit/progress_repository_test.dart' show kNow, seedHistory;

class _OfflineApi implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('network used while offline: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;

  Future<void> setUpDb({String unit = 'kg'}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedHistory(db);
    if (unit != 'kg') {
      await (db.update(db.users)..where((u) => u.id.equals(kUserId))).write(UsersCompanion(unit: Value(unit)));
    }
    queue = SyncQueue(db: db, dio: _OfflineApi(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
  }

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {bool pro = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/progress', routes: [
      GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
      GoRoute(path: '/paywall', builder: (_, __) => const Text('PAYWALL')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncQueueProvider.overrideWithValue(queue),
        currentUserIdProvider.overrideWithValue(kUserId),
        clockProvider.overrideWithValue(() => kNow),
        entitlementProvider.overrideWith(
            (ref) => Stream.value(pro ? const EntitlementState(isPro: true, isTrial: false) : EntitlementState.free)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await settle(tester);
  }

  testWidgets('history: finished workouts with their volume; free users see the last 4 weeks', (tester) async {
    await setUpDb();
    await pump(tester);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('376 kg'), findsOneWidget);
    expect(find.text('Showing the last 4 weeks'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Pro sees the full history', (tester) async {
    await setUpDb();
    await pump(tester, pro: true);
    expect(find.text('Full Body A'), findsNWidgets(2));
    expect(find.text('Showing the last 4 weeks'), findsNothing);
    await unmount(tester);
  });

  testWidgets('records: best weight × reps and e1RM per exercise', (tester) async {
    await setUpDb();
    await pump(tester);
    await openTab(tester, 'Records');
    expect(find.text('Goblet Squat'), findsOneWidget);
    expect(find.text('22 kg × 8'), findsOneWidget);
    expect(find.text('e1RM 27.9 kg'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('volume: weekly sets per muscle; free gets a non-blocking Pro card instead of balance', (tester) async {
    await setUpDb();
    await pump(tester);
    await openTab(tester, 'Volume');
    expect(find.text('Quadriceps'), findsOneWidget);
    expect(find.text('2 sets'), findsOneWidget);
    expect(find.text('Tekto Pro shows your full history and muscle balance.'), findsOneWidget);
    expect(find.textContaining('Push '), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    await unmount(tester);
  });

  testWidgets('volume: Pro sees push:pull muscle balance', (tester) async {
    await setUpDb();
    await pump(tester, pro: true);
    await openTab(tester, 'Volume');
    expect(find.text('Push 1 · Pull 0'), findsOneWidget);
    expect(find.text('Tekto Pro shows your full history and muscle balance.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('body weight: logged in the user unit, stored in kg', (tester) async {
    await setUpDb(unit: 'lb');
    await pump(tester);
    await openTab(tester, 'Body weight');
    await tester.tap(find.text('Log body weight'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('body-weight-input')), '176');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await settle(tester);
    expect(find.text('176 lb'), findsOneWidget);
    final stored = (await tester.runAsync(() => db.select(db.bodyWeightEntries).getSingle()))!;
    expect(stored.weightKg, closeTo(79.83, 0.01));
    await unmount(tester);
  });
}

/// The tab bar scrolls; bring the tab into view first (the test font is wide).
Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(TabBar), matching: find.text(label));
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await settle(tester);
}

/// Lets Drift reads/writes finish on the real event loop, then rebuilds.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}
