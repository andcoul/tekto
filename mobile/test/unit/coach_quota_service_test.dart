import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tekto/features/coach/domain/coach_quota_service.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockCoachDao extends Mock implements CoachDao {}

// ---------------------------------------------------------------------------
// Tests — T072
// ---------------------------------------------------------------------------

void main() {
  group('CoachQuotaService', () {
    late _MockCoachDao dao;
    late CoachQuotaService service;

    setUp(() {
      dao = _MockCoachDao();
      service = CoachQuotaService(dao: dao);
    });

    // ---- canSendMessage ----

    test('canSendMessage returns true for Pro user regardless of usage', () async {
      // Pro users are never quota-checked
      final result = await service.canSendMessage('user-1', isPro: true);
      expect(result, isTrue);
      verifyNever(() => dao.getQuota(any(), isoWeek: any(named: 'isoWeek')));
    });

    test('canSendMessage returns true when free user has used 0 questions', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => null);

      final result = await service.canSendMessage('user-1', isPro: false);
      expect(result, isTrue);
    });

    test('canSendMessage returns true when free user has used 2 questions', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => _quota('user-1', 2));

      final result = await service.canSendMessage('user-1', isPro: false);
      expect(result, isTrue);
    });

    test('canSendMessage returns false when free user has used 3 questions', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => _quota('user-1', 3));

      final result = await service.canSendMessage('user-1', isPro: false);
      expect(result, isFalse);
    });

    test('canSendMessage returns false when free user has used more than 3 questions', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => _quota('user-1', 5));

      final result = await service.canSendMessage('user-1', isPro: false);
      expect(result, isFalse);
    });

    // ---- incrementUsage ----

    test('incrementUsage creates a new quota entry when none exists', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => null);
      when(() => dao.upsertQuota(any())).thenAnswer((_) async {});

      await service.incrementUsage('user-1');

      final captured = verify(() => dao.upsertQuota(captureAny())).captured;
      final saved = captured.first as CoachQuotaUsageModel;
      expect(saved.questionsUsed, equals(1));
    });

    test('incrementUsage increments existing counter', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => _quota('user-1', 2));
      when(() => dao.upsertQuota(any())).thenAnswer((_) async {});

      await service.incrementUsage('user-1');

      final captured = verify(() => dao.upsertQuota(captureAny())).captured;
      final saved = captured.first as CoachQuotaUsageModel;
      expect(saved.questionsUsed, equals(3));
    });

    // ---- ISO week boundary ----

    test('currentIsoWeek returns non-empty string in YYYY-Www format', () {
      final week = service.currentIsoWeekForTest();
      expect(week, matches(RegExp(r'^\d{4}-W\d{2}$')));
    });

    test('questionsRemaining returns null for Pro users', () async {
      final remaining = await service.questionsRemaining('user-1', isPro: true);
      expect(remaining, isNull);
    });

    test('questionsRemaining returns correct count for free user', () async {
      when(() => dao.getQuota('user-1', isoWeek: any(named: 'isoWeek')))
          .thenAnswer((_) async => _quota('user-1', 1));

      final remaining =
          await service.questionsRemaining('user-1', isPro: false);
      expect(remaining, equals(2));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CoachQuotaUsageModel _quota(String userId, int used) => CoachQuotaUsageModel(
      userId: userId,
      isoWeek: '2026-W45',
      questionsUsed: used,
    );
