import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';

/// Manages the free-tier coach question quota.
///
/// Free users are allowed 3 questions per ISO week (Mon–Sun).
/// The quota resets automatically on the first message of a new ISO week.
///
/// Principle V: this class is unit-tested.
class CoachQuotaService {
  const CoachQuotaService({required CoachDao dao}) : _dao = dao;

  final CoachDao _dao;

  static const _freeWeeklyLimit = 3;

  /// Returns `true` if the user may send another message this week.
  ///
  /// Pro users (isPro = true) always return true.
  Future<bool> canSendMessage(String userId, {required bool isPro}) async {
    if (isPro) return true;
    final usage = await _dao.getQuota(userId, isoWeek: _currentIsoWeek());
    return (usage?.questionsUsed ?? 0) < _freeWeeklyLimit;
  }

  /// Increments the question counter for the current ISO week.
  ///
  /// Call this AFTER a message has been accepted and sent.
  Future<void> incrementUsage(String userId) async {
    final week = _currentIsoWeek();
    final existing = await _dao.getQuota(userId, isoWeek: week);
    final updated = CoachQuotaUsageModel(
      userId: userId,
      isoWeek: week,
      questionsUsed: (existing?.questionsUsed ?? 0) + 1,
    );
    await _dao.upsertQuota(updated);
  }

  /// Returns the number of questions remaining this week.
  /// Pro users get [null] (unlimited).
  Future<int?> questionsRemaining(
      String userId, {required bool isPro}) async {
    if (isPro) return null;
    final usage = await _dao.getQuota(userId, isoWeek: _currentIsoWeek());
    final used = usage?.questionsUsed ?? 0;
    return (_freeWeeklyLimit - used).clamp(0, _freeWeeklyLimit);
  }

  /// Returns the ISO week string for today in `YYYY-Www` format.
  String currentIsoWeekForTest() => _currentIsoWeek();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static String _currentIsoWeek() {
    final now = DateTime.now();
    return _isoWeekOf(now);
  }

  static String _isoWeekOf(DateTime date) {
    // ISO 8601: week starts Monday; week 1 contains the first Thursday of Jan.
    final thursday = date.subtract(Duration(days: date.weekday - 4));
    final week1 = _firstMondayOfIsoWeek1(thursday.year);
    final weekNum = ((date.difference(week1).inDays) ~/ 7) + 1;
    return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  static DateTime _firstMondayOfIsoWeek1(int year) {
    // The first ISO week contains January 4.
    var jan4 = DateTime(year, 1, 4);
    // Roll back to the Monday of that week.
    return jan4.subtract(Duration(days: jan4.weekday - 1));
  }
}
