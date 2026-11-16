import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tekto/features/coach/domain/coach_quota_service.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockCoachDao extends Mock implements CoachDao {}

/// Wednesday of ISO week 2026-W46.
final _now = DateTime(2026, 11, 11, 9);
const _week = '2026-W46';

// ---------------------------------------------------------------------------
// Tests — T072 (extended by T069)
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => registerFallbackValue(CoachQuotaUsageCompanion.insert(userId: '', isoWeek: '')));

  group('CoachQuotaService', () {
    late _MockCoachDao dao;
    late CoachQuotaService service;

    setUp(() {
      dao = _MockCoachDao();
      service = CoachQuotaService(dao: dao, clock: () => _now);
    });

    // ---- canSendMessage ----

    test('canSendMessage returns true for Pro user regardless of usage', () async {
      final result = await service.canSendMessage('user-1', isPro: true);
      expect(result, isTrue);
      verifyNever(() => dao.getQuota(any(), any()));
    });

    test('canSendMessage returns true when free user has used 0 questions', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => null);

      expect(await service.canSendMessage('user-1', isPro: false), isTrue);
    });

    test('canSendMessage returns true when free user has used 2 questions', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => _quota('user-1', 2));

      expect(await service.canSendMessage('user-1', isPro: false), isTrue);
    });

    test('canSendMessage returns false when free user has used 3 questions', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => _quota('user-1', 3));

      expect(await service.canSendMessage('user-1', isPro: false), isFalse);
    });

    test('canSendMessage returns false when free user has used more than 3 questions', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => _quota('user-1', 5));

      expect(await service.canSendMessage('user-1', isPro: false), isFalse);
    });

    // ---- recordReply: the local count mirrors the server (T069, contracts/backend-api.md) ----

    group('recordReply', () {
      setUp(() => when(() => dao.upsertQuota(any())).thenAnswer((_) async {}));

      CoachQuotaUsageCompanion saved() =>
          verify(() => dao.upsertQuota(captureAny())).captured.single as CoachQuotaUsageCompanion;

      test('an answered question stores the server count for this ISO week', () async {
        await service.recordReply('user-1', statusCode: 200, quotaRemaining: 2);

        final write = saved();
        expect(write.isoWeek.value, _week);
        expect(write.questionsUsed.value, 1);
      });

      test('quota_remaining 2 → 1 → 0 across three answered questions', () async {
        for (final remaining in [2, 1, 0]) {
          await service.recordReply('user-1', statusCode: 200, quotaRemaining: remaining);
        }
        final writes = verify(() => dao.upsertQuota(captureAny())).captured.cast<CoachQuotaUsageCompanion>();
        expect(writes.map((c) => c.questionsUsed.value), [1, 2, 3]);
      });

      test('AI_UNAVAILABLE (503) does not consume quota', () async {
        await service.recordReply('user-1', statusCode: 503);
        verifyNever(() => dao.upsertQuota(any()));
      });

      test('other failures do not consume quota', () async {
        for (final code in [400, 404, 500]) {
          await service.recordReply('user-1', statusCode: code);
        }
        verifyNever(() => dao.upsertQuota(any()));
      });

      test('QUOTA_EXCEEDED (429) blocks locally until the next ISO week', () async {
        await service.recordReply('user-1', statusCode: 429);
        expect(saved().questionsUsed.value, CoachQuotaService.freeWeeklyLimit);
      });

      test('Pro replies (quota_remaining null) store nothing', () async {
        await service.recordReply('user-1', statusCode: 200);
        verifyNever(() => dao.upsertQuota(any()));
      });
    });

    test('blocked at 3 questions this week, allowed again on Monday of the next ISO week', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => _quota('user-1', 3));
      when(() => dao.getQuota('user-1', '2026-W47')).thenAnswer((_) async => null);

      expect(await service.canSendMessage('user-1', isPro: false), isFalse);

      final nextMonday = CoachQuotaService(dao: dao, clock: () => DateTime(2026, 11, 16, 0, 5));
      expect(await nextMonday.canSendMessage('user-1', isPro: false), isTrue);
      expect(await nextMonday.questionsRemaining('user-1', isPro: false), 3);
    });

    test('Sunday night is still the same ISO week', () async {
      final sunday = CoachQuotaService(dao: dao, clock: () => DateTime(2026, 11, 15, 23, 59));
      expect(sunday.currentIsoWeekForTest(), _week);
    });

    // ---- ISO week boundary ----

    test('currentIsoWeek returns the week of the injected clock in YYYY-Www format', () {
      expect(service.currentIsoWeekForTest(), _week);
    });

    test('isoWeekOf follows ISO 8601 at year boundaries', () {
      expect(CoachQuotaService.isoWeekOf(DateTime(2026, 12, 31)), '2026-W53');
      expect(CoachQuotaService.isoWeekOf(DateTime(2027, 1, 4)), '2027-W01');
      expect(CoachQuotaService.isoWeekOf(DateTime(2024, 12, 30)), '2025-W01');
    });

    test('questionsRemaining returns null for Pro users', () async {
      expect(await service.questionsRemaining('user-1', isPro: true), isNull);
    });

    test('questionsRemaining returns correct count for free user', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => _quota('user-1', 1));

      expect(await service.questionsRemaining('user-1', isPro: false), 2);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CoachQuotaUsageData _quota(String userId, int used) => CoachQuotaUsageData(
      userId: userId,
      isoWeek: _week,
      questionsUsed: used,
      updatedAt: _now,
    );
