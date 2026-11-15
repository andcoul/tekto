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

    // ---- incrementUsage ----

    test('incrementUsage creates a new quota entry when none exists', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => null);
      when(() => dao.upsertQuota(any())).thenAnswer((_) async {});

      await service.incrementUsage('user-1');

      final saved = verify(() => dao.upsertQuota(captureAny())).captured.single as CoachQuotaUsageCompanion;
      expect(saved.isoWeek.value, _week);
      expect(saved.questionsUsed.value, 1);
    });

    test('incrementUsage increments existing counter', () async {
      when(() => dao.getQuota('user-1', _week)).thenAnswer((_) async => _quota('user-1', 2));
      when(() => dao.upsertQuota(any())).thenAnswer((_) async {});

      await service.incrementUsage('user-1');

      final saved = verify(() => dao.upsertQuota(captureAny())).captured.single as CoachQuotaUsageCompanion;
      expect(saved.questionsUsed.value, 3);
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
