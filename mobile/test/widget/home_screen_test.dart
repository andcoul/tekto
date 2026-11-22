// T103 — home screen (FR-006, US2 acceptance scenario 1). Written before T104.
import 'package:tekto/features/recovery/data/local_training_history.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/features/workout/ui/home_screen.dart';
import 'package:tekto/shared/models/plan_model.dart';
import 'package:tekto/shared/services/local_db/database.dart';

import '../helpers/workout_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedWorkoutFixture(db);
  });

  tearDown(() => db.close());

  Future<void> pumpHome(
    WidgetTester tester, {
    required DateTime now,
    PlanModel? plan,
    bool noPlan = false,
    Locale locale = const Locale('en'),
  }) async {
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/workout/:sessionId', builder: (_, s) => Text('workout ${s.pathParameters['sessionId']}')),
      GoRoute(path: '/onboarding/disclaimer', builder: (_, __) => const Text('onboarding')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(kUserId),
        clockProvider.overrideWithValue(() => now),
        activePlanProvider.overrideWith((ref) => Stream.value(noPlan ? null : (plan ?? fixturePlan()))),
        unseenAdaptationProvider.overrideWith((ref) => Stream.value(null)), // adaptation_card_test covers it
        // The recovery card (FR-051) has its own tests.
        entitlementProvider.overrideWith((ref) => Stream.value(EntitlementState.free)),
        recoveryProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('training day: today\'s session with duration, target muscles and Start Workout', (tester) async {
    await pumpHome(tester, now: kWednesday);

    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('Quads · Chest'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start workout'), findsOneWidget);
    expect(find.text('Rest day'), findsNothing);
  });

  testWidgets('Start Workout opens the live workout for that session', (tester) async {
    await pumpHome(tester, now: kWednesday);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start workout'));
    await tester.pumpAndSettle();

    expect(find.text('workout $kSessionId'), findsOneWidget);
  });

  testWidgets('rest day: shows the rest-day message and no Start Workout', (tester) async {
    await pumpHome(tester, now: kThursday);

    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('Recovery is part of the plan. See you tomorrow.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start workout'), findsNothing);
  });

  testWidgets('uses the plan\'s current week, not a later week on the same weekday', (tester) async {
    await pumpHome(tester, now: kWednesday, plan: fixturePlan(currentWeek: 2));

    expect(find.text('Full Body A (week 2)'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
    expect(find.text('Full Body A'), findsNothing);
  });

  testWidgets('session name follows the app language', (tester) async {
    await pumpHome(tester, now: kWednesday, locale: const Locale('fr'));

    expect(find.text('Corps entier A'), findsOneWidget);
  });

  testWidgets('no active plan: offers to build one', (tester) async {
    await pumpHome(tester, now: kWednesday, noPlan: true);

    expect(find.text('No active plan'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start workout'), findsNothing);
  });
}
