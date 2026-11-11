import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/services/local_db/database.dart';
import '../domain/live_session.dart';

/// Reads everything a workout needs from the device database — never the network
/// (Constitution I: the active plan and its exercise text are on-device before the
/// first workout).
class WorkoutSessionRepository {
  WorkoutSessionRepository(this._db);

  final AppDatabase _db;

  /// Today's session for [plan]: the session of the plan's current week whose
  /// `day_of_week` (1 = Monday … 7 = Sunday) is [weekday].
  Future<TodayStatus> today({required String planId, required int currentWeek, required int weekday}) async {
    final row = await (_db.select(_db.sessions)
          ..where((s) => s.planId.equals(planId) & s.weekNumber.equals(currentWeek) & s.dayOfWeek.equals(weekday)))
        .getSingleOrNull();
    if (row == null) return const RestDay();
    return TrainingDay(
      sessionId: row.id,
      nameEn: row.nameEn,
      nameFr: row.nameFr,
      muscleGroups: _strings(row.muscleGroups),
      estimatedMin: row.estimatedMin,
    );
  }

  Future<LiveSession> loadSession(String sessionId) async {
    final session = await (_db.select(_db.sessions)..where((s) => s.id.equals(sessionId))).getSingle();
    final slots = await (_db.select(_db.planExercises)
          ..where((p) => p.sessionId.equals(sessionId))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
    final slugs = slots.map((s) => s.exerciseSlug).toSet();
    final exercises = {
      for (final e in await (_db.select(_db.exercises)..where((e) => e.slug.isIn(slugs))).get()) e.slug: e,
    };
    final downloads = {
      for (final d in await (_db.select(_db.exerciseVideoDownloads)..where((d) => d.exerciseSlug.isIn(slugs))).get())
        d.exerciseSlug: d,
    };

    return LiveSession(
      sessionId: session.id,
      nameEn: session.nameEn,
      nameFr: session.nameFr,
      exercises: [
        for (final slot in slots)
          _liveExercise(slot, exercises[slot.exerciseSlug], downloads[slot.exerciseSlug]),
      ],
    );
  }

  /// The unfinished workout for [sessionId], if the app closed mid-workout.
  Future<({String workoutLogId, List<LoggedSet> sets})?> findOpenLog({
    required String userId,
    required String sessionId,
  }) async {
    final log = await (_db.select(_db.workoutLogs)
          ..where((w) => w.userId.equals(userId) & w.sessionId.equals(sessionId) & w.finishedAt.isNull())
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (log == null) return null;
    return (workoutLogId: log.id, sets: await setsFor(log.id));
  }

  Future<List<LoggedSet>> setsFor(String workoutLogId) async {
    final rows = await (_db.select(_db.setLogs)
          ..where((s) => s.workoutLogId.equals(workoutLogId))
          ..orderBy([(s) => OrderingTerm.asc(s.loggedAt), (s) => OrderingTerm.asc(s.setNumber)]))
        .get();
    return [
      for (final r in rows)
        LoggedSet(
          id: r.id,
          planExerciseId: r.planExerciseId,
          setNumber: r.setNumber,
          weightKg: r.weightKg,
          reps: r.reps,
          rpe: r.rpeActual,
          isPr: r.isPr,
        ),
    ];
  }

  Future<WorkoutSummary> summarize(String workoutLogId) async {
    final log = await (_db.select(_db.workoutLogs)..where((w) => w.id.equals(workoutLogId))).getSingle();
    final sets = await setsFor(workoutLogId);
    return WorkoutSummary(
      workoutLogId: workoutLogId,
      startedAt: log.startedAt,
      totalVolumeKg: sets.fold(0.0, (sum, s) => sum + s.weightKg * s.reps),
      exercisesCompleted: sets.map((s) => s.planExerciseId).toSet().length,
      prCount: sets.where((s) => s.isPr).length,
    );
  }

  Future<UserPrefs> userPrefs(String? userId) async {
    if (userId == null) return const UserPrefs();
    final row = await (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (row == null) return const UserPrefs();
    return UserPrefs(unit: row.unit == 'lb' ? 'lb' : 'kg', healthSyncEnabled: row.healthSyncEnabled);
  }

  static LiveExercise _liveExercise(PlanExercise slot, Exercise? e, ExerciseVideoDownload? d) => LiveExercise(
        planExerciseId: slot.id,
        slug: slot.exerciseSlug,
        // Text is cached for every plan exercise; the slug is a last-resort label.
        nameEn: e?.nameEn ?? slot.exerciseSlug,
        nameFr: e?.nameFr ?? slot.exerciseSlug,
        cuesEn: e == null ? const [] : _strings(e.cuesEn),
        cuesFr: e == null ? const [] : _strings(e.cuesFr),
        sets: slot.sets,
        repsMin: slot.repsMin,
        repsMax: slot.repsMax,
        restSec: slot.restSec,
        rpeTarget: slot.rpeTarget,
        suggestedWeightKg: slot.suggestedWeightKg,
        videoUrl: e?.videoFrontUrl,
        captions: {
          if (e?.captionsEnUrl != null) 'en': e!.captionsEnUrl!,
          if (e?.captionsFrUrl != null) 'fr': e!.captionsFrUrl!,
        },
        localVideoPath: d?.localPath,
        localCaptions: d == null ? const {} : (jsonDecode(d.captionsLocalPaths) as Map).cast<String, String>(),
        formCheckSupported: e?.formCheckSupported ?? false,
      );

  static List<String> _strings(String json) => (jsonDecode(json) as List).cast<String>();
}
