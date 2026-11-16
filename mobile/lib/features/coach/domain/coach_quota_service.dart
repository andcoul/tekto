import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tekto/core/di/providers.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

/// Manages the free-tier coach question quota.
///
/// Free users are allowed 3 questions per ISO week (Mon–Sun).
/// The quota resets automatically on the first message of a new ISO week.
///
/// Principle V: this class is unit-tested.
class CoachQuotaService {
  const CoachQuotaService({required CoachDao dao, DateTime Function() clock = DateTime.now})
      : _dao = dao,
        _clock = clock;

  final CoachDao _dao;
  final DateTime Function() _clock;

  static const freeWeeklyLimit = 3;

  /// Returns `true` if the user may send another message this week.
  ///
  /// Pro users (isPro = true) always return true.
  Future<bool> canSendMessage(String userId, {required bool isPro}) async {
    if (isPro) return true;
    final usage = await _dao.getQuota(userId, _currentIsoWeek());
    return (usage?.questionsUsed ?? 0) < freeWeeklyLimit;
  }

  /// Mirrors the server's answer to one coach question in the local count. The server is the
  /// authority (contracts/backend-api.md `coach-message`); this copy only lets the app show
  /// the remaining questions and the paywall without a round trip.
  ///
  /// - 200 with [quotaRemaining]: a reply was returned; store `limit - quotaRemaining`.
  /// - 200 without it: a Pro user; quota is not tracked.
  /// - 429 `QUOTA_EXCEEDED`: the limit is reached for this ISO week.
  /// - anything else, including 503 `AI_UNAVAILABLE`: no reply, nothing is consumed.
  Future<void> recordReply(String userId, {required int statusCode, int? quotaRemaining}) async {
    final int used;
    if (statusCode == 200 && quotaRemaining != null) {
      used = (freeWeeklyLimit - quotaRemaining).clamp(0, freeWeeklyLimit);
    } else if (statusCode == 429) {
      used = freeWeeklyLimit;
    } else {
      return;
    }
    await _dao.upsertQuota(CoachQuotaUsageCompanion.insert(
      userId: userId,
      isoWeek: _currentIsoWeek(),
      questionsUsed: Value(used),
      updatedAt: Value(_clock()),
    ));
  }

  /// Returns the number of questions remaining this week.
  /// Pro users get [null] (unlimited).
  Future<int?> questionsRemaining(String userId, {required bool isPro}) async {
    if (isPro) return null;
    final usage = await _dao.getQuota(userId, _currentIsoWeek());
    final used = usage?.questionsUsed ?? 0;
    return (freeWeeklyLimit - used).clamp(0, freeWeeklyLimit);
  }

  /// Returns the ISO week string for today in `YYYY-Www` format.
  String currentIsoWeekForTest() => _currentIsoWeek();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  String _currentIsoWeek() => isoWeekOf(_clock());

  /// ISO 8601 week of [date] as `YYYY-Www` (week starts Monday; week 1 holds January 4).
  static String isoWeekOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final thursday = day.subtract(Duration(days: day.weekday - 4));
    final week1 = _firstMondayOfIsoWeek1(thursday.year);
    final weekNum = (day.difference(week1).inDays ~/ 7) + 1;
    return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  static DateTime _firstMondayOfIsoWeek1(int year) {
    final jan4 = DateTime(year, 1, 4);
    return jan4.subtract(Duration(days: jan4.weekday - 1));
  }
}

final coachQuotaServiceProvider = Provider<CoachQuotaService>(
  (ref) => CoachQuotaService(
    dao: CoachDao(ref.watch(appDatabaseProvider)),
    clock: ref.watch(clockProvider),
  ),
);
