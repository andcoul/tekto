import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/form_check/domain/form_check_free_try_service.dart';
import 'package:tekto/shared/services/local_db/daos/form_check_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

// ---------------------------------------------------------------------------
// T061 — free form-check try: one per lift for free users (FR-029)
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late FormCheckFreeTryService service;
  const user = 'user-1';

  Future<void> addExercise(String slug, String liftKey) => db.into(db.exercises).insert(ExercisesCompanion.insert(
        slug: slug,
        nameEn: slug,
        nameFr: slug,
        equipment: '[]',
        musclePrimary: '[]',
        muscleSecondary: '[]',
        cuesEn: '[]',
        cuesFr: '[]',
        commonMistakesEn: '[]',
        commonMistakesFr: '[]',
        formCheckSupported: const Value(true),
        formCheckLiftKey: Value(liftKey),
      ));

  Future<void> addSession(String slug, {required bool wasFreeTry, String userId = user}) =>
      db.into(db.formCheckSessions).insert(FormCheckSessionsCompanion.insert(
            id: '$userId-$slug-${DateTime.now().microsecondsSinceEpoch}',
            userId: userId,
            exerciseSlug: slug,
            wasFreeTry: Value(wasFreeTry),
          ));

  setUp(() async {
    // In-memory database only: the decision never touches the network.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = FormCheckFreeTryService(dao: FormCheckDao(db));
    await addExercise('barbell-back-squat', 'squat');
    await addExercise('goblet-squat', 'squat');
    await addExercise('barbell-deadlift', 'deadlift');
  });

  tearDown(() => db.close());

  test('free user: the first try on a lift is allowed as a free try', () async {
    final access = await service.check(userId: user, liftKey: 'squat', isPro: false);
    expect(access, FormCheckAccess.freeTry);
    expect(access.allowed, isTrue);
    expect(access.wasFreeTry, isTrue);
  });

  test('free user: the second try on the same lift is blocked', () async {
    await addSession('barbell-back-squat', wasFreeTry: true);
    final access = await service.check(userId: user, liftKey: 'squat', isPro: false);
    expect(access, FormCheckAccess.blocked);
    expect(access.allowed, isFalse);
  });

  test('free user: the lift is used up whichever exercise variant was tried', () async {
    await addSession('goblet-squat', wasFreeTry: true);
    expect(await service.check(userId: user, liftKey: 'squat', isPro: false), FormCheckAccess.blocked);
  });

  test('free user: a different lift is still allowed once', () async {
    await addSession('barbell-back-squat', wasFreeTry: true);
    expect(await service.check(userId: user, liftKey: 'deadlift', isPro: false), FormCheckAccess.freeTry);
    await addSession('barbell-deadlift', wasFreeTry: true);
    expect(await service.check(userId: user, liftKey: 'deadlift', isPro: false), FormCheckAccess.blocked);
  });

  test('sessions run while Pro do not use up the free try', () async {
    await addSession('barbell-back-squat', wasFreeTry: false);
    expect(await service.check(userId: user, liftKey: 'squat', isPro: false), FormCheckAccess.freeTry);
  });

  test("another user's free try does not count", () async {
    await addSession('barbell-back-squat', wasFreeTry: true, userId: 'someone-else');
    expect(await service.check(userId: user, liftKey: 'squat', isPro: false), FormCheckAccess.freeTry);
  });

  test('Pro: always allowed, never recorded as a free try', () async {
    await addSession('barbell-back-squat', wasFreeTry: true);
    final access = await service.check(userId: user, liftKey: 'squat', isPro: true);
    expect(access, FormCheckAccess.pro);
    expect(access.allowed, isTrue);
    expect(access.wasFreeTry, isFalse);
  });
}
