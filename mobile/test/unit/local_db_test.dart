// Verifies the foundational local DB work (T016, T017): SQLCipher is the bundled SQLite,
// the free-try query is per lift, and isPro follows the data-model rule.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/local_db/daos/form_check_dao.dart';
import 'package:tekto/shared/services/local_db/daos/subscription_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the bundled SQLite is SQLCipher (Constitution II)', () async {
    final row = await db.customSelect('PRAGMA cipher_version;').getSingleOrNull();
    expect(row, isNotNull, reason: 'pubspec hooks must build sqlite3 with source: sqlcipher');
  });

  test('a keyed database file is not readable as plain SQLite', () async {
    final dir = await Directory.systemTemp.createTemp('tekto_db');
    final file = File('${dir.path}/enc.sqlite');
    final enc = AppDatabase.forTesting(NativeDatabase(file, setup: (raw) => raw.execute("PRAGMA key = 'abc123';")));
    await enc.into(enc.users).insert(UsersCompanion.insert(
          id: 'u1', goal: 'muscle', level: 'beginner', daysPerWeek: 3, sessionLengthMin: 45, equipment: '[]',
        ));
    await enc.close();
    final header = String.fromCharCodes((await file.readAsBytes()).take(15));
    expect(header, isNot('SQLite format 3'), reason: 'plain SQLite files start with this header');
    await dir.delete(recursive: true);
  });

  group('FormCheckDao.hasFreeTry', () {
    late FormCheckDao dao;

    setUp(() async {
      dao = FormCheckDao(db);
      for (final (slug, lift) in [('barbell-squat', 'squat'), ('goblet-squat', 'squat'), ('deadlift', 'deadlift')]) {
        await db.into(db.exercises).insert(ExercisesCompanion.insert(
              slug: slug, nameEn: slug, nameFr: slug, equipment: '[]', musclePrimary: '[]',
              muscleSecondary: '[]', cuesEn: '[]', cuesFr: '[]', commonMistakesEn: '[]', commonMistakesFr: '[]',
              formCheckSupported: const Value(true), formCheckLiftKey: Value(lift),
            ));
      }
    });

    test('false before any try', () async {
      expect(await dao.hasFreeTry('u1', 'squat'), isFalse);
    });

    test('a free try on one squat variation uses up the squat lift, not deadlift', () async {
      await dao.insertSession(FormCheckSessionsCompanion.insert(
        id: 's1', userId: 'u1', exerciseSlug: 'goblet-squat', wasFreeTry: const Value(true),
      ));
      expect(await dao.hasFreeTry('u1', 'squat'), isTrue);
      expect(await dao.hasFreeTry('u1', 'deadlift'), isFalse);
      expect(await dao.hasFreeTry('u2', 'squat'), isFalse);
    });

    test('Pro sessions (was_free_try = false) do not count', () async {
      await dao.insertSession(FormCheckSessionsCompanion.insert(id: 's2', userId: 'u1', exerciseSlug: 'deadlift'));
      expect(await dao.hasFreeTry('u1', 'deadlift'), isFalse);
    });
  });

  group('SubscriptionDao.isPro', () {
    final now = DateTime.utc(2026, 11, 10);
    Subscription sub({String tier = 'pro', bool trial = false, DateTime? trialEnds, DateTime? periodEnds}) =>
        Subscription(
          id: 'x', userId: 'u', tier: tier, isTrial: trial, trialEndsAt: trialEnds,
          currentPeriodEndsAt: periodEnds, createdAt: now, updatedAt: now,
        );

    test('follows tier == pro AND (period active OR trial active)', () {
      final dao = SubscriptionDao(db);
      final later = now.add(const Duration(days: 3));
      final earlier = now.subtract(const Duration(days: 3));
      expect(dao.isPro(null, now: now), isFalse);
      expect(dao.isPro(sub(tier: 'free', periodEnds: later), now: now), isFalse);
      expect(dao.isPro(sub(periodEnds: later), now: now), isTrue);
      expect(dao.isPro(sub(periodEnds: earlier), now: now), isFalse);
      expect(dao.isPro(sub(trial: true, trialEnds: later), now: now), isTrue);
      expect(dao.isPro(sub(trial: true, trialEnds: earlier), now: now), isFalse);
      // A trial flag with an expired trial but an active period is still Pro.
      expect(dao.isPro(sub(trial: true, trialEnds: earlier, periodEnds: later), now: now), isTrue);
    });
  });
}
