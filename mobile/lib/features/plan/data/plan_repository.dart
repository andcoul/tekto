import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/plan_model.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/plan_dao.dart';

class PlanRepository {
  PlanRepository({required AppDatabase db, required SupabaseClient supabase})
      : _planDao = PlanDao(db),
        _supabase = supabase;

  final PlanDao _planDao;
  final SupabaseClient _supabase;

  Future<PlanModel?> getActivePlan(String userId) async {
    try {
      final row = await _supabase
          .from('plans')
          .select('*, sessions(*,plan_exercises(*))')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (row != null) {
        await _cachePlanLocally(row);
        return PlanModel.fromJson(row);
      }
    } catch (_) {}

    // Fallback to local
    final local = await _planDao.getActivePlan(userId);
    if (local == null) return null;
    return _planFromDrift(local);
  }

  /// Fetches the active plan with all sessions and exercises and caches them on the device, so
  /// the plan works offline (Constitution I). Throws when offline; callers keep the local copy.
  Future<void> refreshActivePlan(String userId) async {
    final row = await _supabase
        .from('plans')
        .select('*, sessions(*, plan_exercises(*))')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) return;
    await _cachePlanLocally(row);
    await _cacheSessions(row);
    await _planDao.archiveOtherPlans(userId, keepPlanId: row['id'] as String);
  }

  Stream<PlanModel?> watchActivePlan(String userId) {
    return _planDao.watchActivePlan(userId).map(
          (p) => p == null ? null : _planFromDrift(p),
        );
  }

  Future<void> archivePlan(String planId) async {
    await _supabase.from('plans').update({'status': 'archived'}).eq('id', planId);
    await _planDao.archivePlan(planId);
  }

  Future<void> _cachePlanLocally(Map<String, dynamic> row) async {
    await _planDao.upsertPlan(PlansCompanion.insert(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      status: Value(row['status'] as String? ?? 'active'),
      weeksTotal: row['weeks_total'] as int,
      currentWeek: Value(row['current_week'] as int? ?? 1),
      startDate: Value(DateTime.tryParse(row['start_date'] as String? ?? '')),
      lastAdaptedWeek: Value(row['last_adapted_week'] as int? ?? 0),
      source: Value(row['source'] as String? ?? 'ai'),
      templateSlug: Value(row['template_slug'] as String?),
    ));
  }

  Future<void> _cacheSessions(Map<String, dynamic> planRow) async {
    final sessions = (planRow['sessions'] as List? ?? const []).cast<Map<String, dynamic>>();
    await _planDao.upsertSessions([
      for (final s in sessions)
        SessionsCompanion.insert(
          id: s['id'] as String,
          planId: planRow['id'] as String,
          weekNumber: s['week_number'] as int,
          dayOfWeek: s['day_of_week'] as int,
          nameEn: s['name_en'] as String,
          nameFr: s['name_fr'] as String,
          muscleGroups: jsonEncode(s['muscle_groups'] ?? const []),
          estimatedMin: Value(s['estimated_min'] as int?),
        ),
    ]);
    await _planDao.upsertPlanExercises([
      for (final s in sessions)
        for (final e in (s['plan_exercises'] as List? ?? const []).cast<Map<String, dynamic>>())
          PlanExercisesCompanion.insert(
            id: e['id'] as String,
            sessionId: s['id'] as String,
            exerciseSlug: e['exercise_slug'] as String,
            sortOrder: Value(e['sort_order'] as int? ?? 0),
            sets: e['sets'] as int,
            repsMin: e['reps_min'] as int,
            repsMax: e['reps_max'] as int,
            rpeTarget: Value((e['rpe_target'] as num?)?.toDouble()),
            restSec: Value(e['rest_sec'] as int? ?? 90),
            suggestedWeightKg: Value((e['suggested_weight_kg'] as num?)?.toDouble()),
          ),
    ]);
  }

  static PlanModel _planFromDrift(Plan p) => PlanModel(
        id: p.id,
        userId: p.userId,
        name: p.name,
        status: p.status,
        weeksTotal: p.weeksTotal,
        currentWeek: p.currentWeek,
        startDate: p.startDate ?? p.createdAt,
        lastAdaptedWeek: p.lastAdaptedWeek,
        source: p.source,
        templateSlug: p.templateSlug,
        rationaleEn: p.rationaleEn,
        rationaleFr: p.rationaleFr,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      );
}
