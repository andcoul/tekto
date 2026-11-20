// T111 — coach answer rating (SC-011, Constitution VI).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/coach/ui/widgets/message_rating_widget.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';

class _NoNetwork implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('no network in this test');
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db: db, dio: _NoNetwork(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
  });

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {bool? initial, Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db), syncQueueProvider.overrideWithValue(queue)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: MessageRatingWidget(messageId: 'm-1', initialRating: initial))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('thumbs up and down are offered, localized, and gym-sized (≥ 48 dp)', (tester) async {
    await pump(tester);
    for (final tip in ['Helpful', 'Not helpful']) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await pump(tester, locale: const Locale('fr'));
    expect(find.byTooltip('Utile'), findsOneWidget);
    expect(find.byTooltip('Pas utile'), findsOneWidget);
  });

  testWidgets('one rating per message: the buttons go away after a tap, and the rating is queued for the server',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Helpful'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Helpful'), findsNothing);
    expect(find.byTooltip('Not helpful'), findsNothing);
    expect(find.byIcon(Icons.thumb_up), findsOneWidget);

    final rows = (await tester.runAsync(() => db.select(db.syncQueueTable).get()))!;
    expect(rows.map((r) => (r.operation, r.tableName_)), [('update', 'coach_messages')]);
    expect(jsonDecode(rows.single.payload), {'id': 'm-1', 'satisfaction_rating': true});
  });

  testWidgets('an already rated message shows its rating and no buttons', (tester) async {
    await pump(tester, initial: false);
    expect(find.byTooltip('Helpful'), findsNothing);
    expect(find.byIcon(Icons.thumb_down), findsOneWidget);
  });
}
