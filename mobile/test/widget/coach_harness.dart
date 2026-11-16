import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/coach/ui/coach_screen.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/subscription/domain/pro_offers.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';
import 'package:tekto/features/workout/domain/workout_controller.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';

/// Shared setup for the coach screen widget tests (T077, T116).

class FakeCoachApi extends TektoDioClient {
  FakeCoachApi() : super(accessToken: () => null, baseUrl: 'http://localhost', anonKey: 'test');

  StreamController<SseEvent> events = StreamController<SseEvent>();
  Object? error;

  @override
  Future<Stream<SseEvent>> postEventStream(String path, {Object? data}) async {
    if (error != null) throw error!;
    return events.stream;
  }
}

class FakeWorkout extends WorkoutController {
  FakeWorkout(this.active);
  final bool active;
  @override
  WorkoutState build() => WorkoutState(isWorkoutActive: active);
}

class CoachHarness {
  CoachHarness() : db = AppDatabase.forTesting(NativeDatabase.memory());

  final AppDatabase db;
  final api = FakeCoachApi();
  final fullScreenPaywalls = <PaywallFeature>[];

  Future<void> pump(WidgetTester tester, {bool pro = false, bool workoutActive = false, Locale? locale}) async {
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        dioClientProvider.overrideWithValue(api),
        currentUserIdProvider.overrideWithValue('user-1'),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        entitlementProvider.overrideWith(
            (ref) => Stream.value(pro ? const EntitlementState(isPro: true, isTrial: false) : EntitlementState.free)),
        workoutControllerProvider.overrideWith(() => FakeWorkout(workoutActive)),
        proOffersProvider.overrideWith((ref) async => const [ProOffer(isAnnual: true, priceString: '79,99 €', price: 79.99)]),
        proPurchaseProvider.overrideWithValue((_) async {}),
        proRestoreProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(children: [
            const Text('WORKOUT SCREEN'),
            Expanded(child: CoachScreen(screenContext: 'live_workout', onShowPaywall: fullScreenPaywalls.add)),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(find.byType(TextField), question);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();
  }
}
