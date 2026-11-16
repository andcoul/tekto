import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/features/coach/domain/coach_provider.dart';
import 'package:tekto/features/coach/domain/coach_quota_service.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

// ---------------------------------------------------------------------------
// Coach reply streaming (contracts/backend-api.md `POST /coach-message`, server-sent events)
// ---------------------------------------------------------------------------

/// Returns whatever the test puts in [events], or throws [error] before any event.
class _FakeApi extends TektoDioClient {
  _FakeApi() : super(accessToken: () => null, baseUrl: 'http://localhost', anonKey: 'test');

  final events = StreamController<SseEvent>();
  Object? error;
  Map<String, dynamic>? sent;

  @override
  Future<Stream<SseEvent>> postEventStream(String path, {Object? data}) async {
    sent = data as Map<String, dynamic>?;
    if (error != null) throw error!;
    return events.stream;
  }
}

final _now = DateTime(2026, 11, 11, 9);

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApi();
    c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      dioClientProvider.overrideWithValue(api),
      currentUserIdProvider.overrideWithValue('user-1'),
      clockProvider.overrideWithValue(() => _now),
      entitlementProvider.overrideWith((ref) => Stream.value(EntitlementState.free)),
    ]);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  CoachState state() => c.read(coachControllerProvider);
  CoachController ctrl() => c.read(coachControllerProvider.notifier);
  Future<void> settle() => Future<void>.delayed(Duration.zero);
  Future<int?> usedThisWeek() async =>
      (await CoachDao(db).getQuota('user-1', CoachQuotaService.isoWeekOf(_now)))?.questionsUsed;

  test('text events fill the reply as they arrive; done stores it under the server id', () async {
    final sending = ctrl().sendMessage('How long should I rest?', screenContext: 'home');
    await settle();

    api.events.add(const SseEvent('text', {'text': 'Rest 2'}));
    await settle();
    expect(state().messages.last.id, CoachController.streamingMessageId);
    expect(state().messages.last.content, 'Rest 2');
    expect(state().status, CoachStatus.loading);

    api.events
      ..add(const SseEvent('text', {'text': ' minutes.'}))
      ..add(const SseEvent('done', {'message_id': 'srv-1', 'plan_change_proposed': null, 'quota_remaining': 2}));
    await api.events.close();
    await sending;

    final reply = state().messages.last;
    expect(reply.id, 'srv-1');
    expect(reply.content, 'Rest 2 minutes.');
    expect(state().status, CoachStatus.idle);
    expect(state().quotaRemaining, 2);
    expect(await usedThisWeek(), 1);
    expect(api.sent!['context'], {'screen': 'home'});

    final stored = await CoachDao(db).watchMessages(state().conversationId!).first;
    expect(stored.map((m) => (m.role, m.content)), [('user', 'How long should I rest?'), ('assistant', 'Rest 2 minutes.')]);
  });

  test('an error event drops the partial reply and consumes no quota', () async {
    final sending = ctrl().sendMessage('Explain RPE');
    await settle();
    api.events
      ..add(const SseEvent('text', {'text': 'RPE is'}))
      ..add(const SseEvent('error', {'error': 'AI_UNAVAILABLE'}));
    await api.events.close();
    await sending;

    expect(state().messages.map((m) => m.role), ['user']);
    expect(state().status, CoachStatus.error);
    expect(state().errorMessage, 'AI_UNAVAILABLE');
    expect(await usedThisWeek(), isNull);
  });

  test('a stream that closes before done is treated as AI_UNAVAILABLE', () async {
    final sending = ctrl().sendMessage('Explain RPE');
    await settle();
    api.events.add(const SseEvent('text', {'text': 'RPE'}));
    await api.events.close();
    await sending;

    expect(state().errorMessage, 'AI_UNAVAILABLE');
    expect(state().messages.any((m) => m.id == CoachController.streamingMessageId), isFalse);
  });

  test('QUOTA_EXCEEDED (429) before any event blocks locally for the week', () async {
    api.error = const ApiStatusException(429, 'QUOTA_EXCEEDED');
    await ctrl().sendMessage('One more?');

    expect(state().errorMessage, 'QUOTA_EXCEEDED');
    expect(await usedThisWeek(), CoachQuotaService.freeWeeklyLimit);
    expect(state().messages.map((m) => m.role), ['user']);
  });

  test('AI_UNAVAILABLE (503) before any event consumes no quota', () async {
    api.error = const ApiStatusException(503, 'AI_UNAVAILABLE');
    await ctrl().sendMessage('Hello');

    expect(state().errorMessage, 'AI_UNAVAILABLE');
    expect(await usedThisWeek(), isNull);
  });
}
