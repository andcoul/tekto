// T091 — settings: language, units, health sync, time zone, regenerate, export, delete
// (FR-033, FR-034, FR-012, FR-026, FR-037, FR-038).
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/settings/domain/settings_service.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

class _NoNetwork implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('no network in this test');
}

class _FakeApi implements SettingsApi {
  final calls = <String>[];
  String zone = 'Europe/Paris';
  bool failDelete = false;

  @override
  Future<void> regeneratePlan() async => calls.add('regenerate');
  @override
  Future<ExportLink> exportData() async {
    calls.add('export');
    return ExportLink(url: Uri.parse('https://example.test/export.json'), expiresAt: DateTime.utc(2026, 11, 16, 13));
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('delete');
    if (failDelete) throw StateError('server refused');
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
  @override
  Future<String> deviceTimezone() async => zone;
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late _FakeApi api;
  late List<String> appliedLocales;
  late bool wiped;
  late SettingsService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db: db, dio: _NoNetwork(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
    api = _FakeApi();
    appliedLocales = [];
    wiped = false;
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'u-1', goal: 'muscle', level: 'beginner', daysPerWeek: 3, sessionLengthMin: 45, equipment: '[]',
          timezone: const Value('UTC'),
        ));
    service = SettingsService(
      db: db,
      queue: queue,
      api: api,
      userId: 'u-1',
      applyLocale: appliedLocales.add,
      wipeLocalData: () async => wiped = true,
    );
  });

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  Future<List<Map<String, dynamic>>> queuedUserUpdates() async => [
        for (final r in await db.select(db.syncQueueTable).get())
          if (r.tableName_ == 'users' && r.operation == 'update') jsonDecode(r.payload) as Map<String, dynamic>,
      ];

  Future<User> user() => (db.select(db.users)..where((u) => u.id.equals('u-1'))).getSingle();

  test('current settings come from the local profile', () async {
    final s = await service.watch().first;
    expect([s!.language, s.unit, s.healthSyncEnabled], ['en', 'kg', false]);
  });

  test('language: saved locally, queued for the server, and applied to the app at once (FR-033)', () async {
    await service.setLanguage('fr');
    expect((await user()).language, 'fr');
    expect(await queuedUserUpdates(), [
      {'id': 'u-1', 'language': 'fr'},
    ]);
    expect(appliedLocales, ['fr']);
  });

  test('units: saved locally (every weight display reads it) and queued (FR-034)', () async {
    await service.setUnit('lb');
    expect((await user()).unit, 'lb');
    expect(await queuedUserUpdates(), [
      {'id': 'u-1', 'unit': 'lb'},
    ]);
  });

  test('health sync toggle is saved and queued (FR-012)', () async {
    await service.setHealthSync(true);
    expect((await user()).healthSyncEnabled, isTrue);
    expect(await queuedUserUpdates(), [
      {'id': 'u-1', 'health_sync_enabled': true},
    ]);
  });

  test('invalid values are refused', () async {
    expect(() => service.setLanguage('de'), throwsArgumentError);
    expect(() => service.setUnit('stone'), throwsArgumentError);
  });

  test('time zone: updated only when the device zone differs from the stored one (FR-026)', () async {
    expect(await service.syncTimezone(), isTrue);
    expect((await user()).timezone, 'Europe/Paris');
    expect(await queuedUserUpdates(), [
      {'id': 'u-1', 'timezone': 'Europe/Paris'},
    ]);
    expect(await service.syncTimezone(), isFalse, reason: 'unchanged: nothing queued again');
    expect((await queuedUserUpdates()).length, 1);
  });

  test('applySavedLanguage sets the app locale from the profile (survives restarts)', () async {
    await (db.update(db.users)..where((u) => u.id.equals('u-1'))).write(const UsersCompanion(language: Value('fr')));
    await service.applySavedLanguage();
    expect(appliedLocales, ['fr']);
  });

  test('regenerate and export go to the server', () async {
    await service.regeneratePlan();
    final link = await service.exportData();
    expect(api.calls, ['regenerate', 'export']);
    expect(link.url.toString(), 'https://example.test/export.json');
  });

  test('delete account: server first, then sign-out and the local wipe (FR-037)', () async {
    await service.deleteAccount();
    expect(api.calls, ['delete', 'signOut']);
    expect(wiped, isTrue);
  });

  test('if the server refuses, nothing local is wiped', () async {
    api.failDelete = true;
    await expectLater(service.deleteAccount(), throwsStateError);
    expect(wiped, isFalse);
    expect(api.calls, ['delete']);
  });
}
