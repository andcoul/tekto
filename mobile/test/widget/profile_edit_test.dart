// T131 — editing onboarding answers from Settings (FR-046).
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/onboarding/ui/onboarding_quiz_screen.dart';
import 'package:tekto/features/settings/domain/settings_service.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

class _NoNetwork implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('no network in this test');
}

class _FakeApi implements SettingsApi {
  int regenerations = 0;
  @override
  Future<void> regeneratePlan() async => regenerations++;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late _FakeApi api;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db: db, dio: _NoNetwork(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
    api = _FakeApi();
  });

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  Future<void> seed() => db.into(db.users).insert(UsersCompanion.insert(
        id: 'u-1', goal: 'muscle', level: 'beginner', daysPerWeek: 3, sessionLengthMin: 45,
        equipment: jsonEncode(['dumbbell']), limitations: Value(jsonEncode(['knee'])),
        limitationsNote: const Value('old ACL'), language: const Value('en'),
      ));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/settings/profile', routes: [
      GoRoute(path: '/settings', builder: (_, __) => const Text('SETTINGS'), routes: [
        GoRoute(path: 'profile', builder: (_, __) => const OnboardingQuizScreen(editProfile: true)),
      ]),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u-1'),
        settingsServiceProvider.overrideWithValue(SettingsService(
          db: db, queue: queue, api: api, userId: 'u-1', applyLocale: (_) {}, wipeLocalData: () async {},
        )),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Walks to the last step with "Next" and taps the final button.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 10 && find.text('Save').evaluate().isEmpty; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> queued() async => [
        for (final r in (await db.select(db.syncQueueTable).get()))
          if (r.tableName_ == 'users') jsonDecode(r.payload) as Map<String, dynamic>,
      ];

  testWidgets('starts at the goal step (no language step), prefilled from the profile', (tester) async {
    await tester.runAsync(seed);
    await pump(tester);
    expect(find.text('What is your main goal?'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: 'the saved goal is selected');
  });

  testWidgets('saving updates the profile and queues it; regenerate is offered; cancel leaves the plan', (tester) async {
    await tester.runAsync(seed);
    await pump(tester);
    await tester.tap(find.text('Get stronger'));
    await tester.pumpAndSettle();
    await finish(tester);

    final user = (await tester.runAsync(() => db.select(db.users).getSingle()))!;
    expect(user.goal, 'strength');
    expect(jsonDecode(user.equipment), ['dumbbell'], reason: 'unchanged answers are kept');
    expect(user.limitationsNote, 'old ACL');
    final q = (await tester.runAsync(queued))!;
    expect(q.single['id'], 'u-1');
    expect(q.single['goal'], 'strength');
    expect(q.single.containsKey('language'), isFalse, reason: 'language has its own setting');
    expect(q.single.containsKey('consent_at'), isFalse, reason: 'editing limitations needs no new consent');

    expect(find.text('Regenerate my plan'), findsWidgets);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(api.regenerations, 0, reason: 'the current plan stays until the user confirms');
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('confirming regenerates the plan', (tester) async {
    await tester.runAsync(seed);
    await pump(tester);
    await finish(tester);
    await tester.tap(find.text('Regenerate'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(api.regenerations, 1);
  });
}
