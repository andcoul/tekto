// T110 — the coach opens from any primary screen with that screen's context (FR-016,
// Constitution VI). The button lives in each screen's app bar; this tests the shared launcher.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/coach/ui/coach_launcher.dart';
import 'package:tekto/features/coach/ui/coach_screen.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class _CapturingApi extends TektoDioClient {
  _CapturingApi() : super(accessToken: () => null, baseUrl: 'http://localhost', anonKey: 'test');

  Map<String, dynamic>? sent;
  final events = StreamController<SseEvent>();

  @override
  Future<Stream<SseEvent>> postEventStream(String path, {Object? data}) async {
    sent = Map<String, dynamic>.from(data! as Map);
    return events.stream;
  }
}

void main() {
  late AppDatabase db;
  late _CapturingApi api;
  late SyncQueue queue;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _CapturingApi();
    queue = SyncQueue(db: db, dio: api, connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
  });

  tearDown(() async {
    // Not awaited: close() completes only once a listener drains the stream, and the first
    // tests never open one.
    unawaited(api.events.close());
    queue.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget button) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        dioClientProvider.overrideWithValue(api),
        syncQueueProvider.overrideWithValue(queue),
        currentUserIdProvider.overrideWithValue('user-1'),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        entitlementProvider.overrideWith((ref) => Stream.value(const EntitlementState(isPro: true, isTrial: false))),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(title: const Text('SCREEN'), actions: [button]), body: const Text('BODY')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Ends the reply stream and lets the controller finish before the scope is disposed.
  Future<void> endStream(WidgetTester tester) async {
    await tester.runAsync(() => api.events.close());
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  testWidgets('the coach button is a 48 dp, labelled icon button', (tester) async {
    await pump(tester, const CoachButton(screen: 'home'));
    final size = tester.getSize(find.byTooltip('Coach'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('tapping it opens the coach as a slide-up sheet over the current screen', (tester) async {
    await pump(tester, const CoachButton(screen: 'home'));
    await tester.tap(find.byTooltip('Coach'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachScreen), findsOneWidget);
    expect(find.text('SCREEN'), findsOneWidget, reason: 'the screen stays underneath');
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('a question sends the screen, exercise and session it was asked from', (tester) async {
    await pump(tester, const CoachButton(screen: 'live_workout', exerciseSlug: 'goblet-squat', sessionId: 'sess-1'));
    await tester.tap(find.byTooltip('Coach'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Why is this in my plan?');
    await tester.tap(find.byIcon(Icons.send));
    for (var i = 0; i < 200 && api.sent == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(api.sent?['context'], {'screen': 'live_workout', 'exercise_slug': 'goblet-squat', 'session_id': 'sess-1'});
    await endStream(tester);
  });

  testWidgets('without an exercise or session only the screen is sent', (tester) async {
    await pump(tester, const CoachButton(screen: 'progress'));
    await tester.tap(find.byTooltip('Coach'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Am I improving?');
    await tester.tap(find.byIcon(Icons.send));
    for (var i = 0; i < 200 && api.sent == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(api.sent?['context'], {'screen': 'progress'});
    await endStream(tester);
  });
}
