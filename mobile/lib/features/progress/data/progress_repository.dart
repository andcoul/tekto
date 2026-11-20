import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/sync/sync_queue.dart';

const _uuid = Uuid();

/// Free users see this many days of history and trends (FR-040).
const kFreeProgressDays = 28;

/// Same push/pull groups as the plan validator's balance rule (FR-002a).
const _push = {'chest', 'shoulders', 'front_deltoid', 'triceps', 'upper_chest'};
const _pull = {'lats', 'rhomboids', 'rear_deltoid', 'biceps', 'traps'};

class HistoryEntry {
  const HistoryEntry(
      {required this.workoutLogId,
      required this.finishedAt,
      required this.sessionNameEn,
      required this.sessionNameFr,
      required this.totalVolumeKg});
  final String workoutLogId;
  final DateTime finishedAt;
  final String sessionNameEn;
  final String sessionNameFr;
  final double totalVolumeKg;
}

class RecordEntry {
  const RecordEntry(
      {required this.exerciseSlug,
      required this.exerciseNameEn,
      required this.exerciseNameFr,
      required this.bestWeightKg,
      required this.bestReps,
      required this.bestE1rmKg,
      required this.achievedAt});
  final String exerciseSlug;
  final String exerciseNameEn;
  final String exerciseNameFr;
  final double bestWeightKg;
  final int bestReps;
  final double bestE1rmKg;
  final DateTime achievedAt;
}

class E1rmPoint {
  const E1rmPoint(this.day, this.e1rmKg);
  final DateTime day;
  final double e1rmKg;
}

class WeekVolume {
  const WeekVolume(this.weekStart, this.setsByMuscle);

  /// Monday 00:00 local.
  final DateTime weekStart;
  final Map<String, int> setsByMuscle;
}

class MuscleBalance {
  const MuscleBalance(this.pushSets, this.pullSets);
  final int pushSets;
  final int pullSets;
}

class BodyWeightPoint {
  const BodyWeightPoint(this.day, this.weightKg);
  final DateTime day;
  final double weightKg;
}

class ProgressData {
  const ProgressData(
      {required this.limited,
      required this.history,
      required this.records,
      required this.e1rmTrend,
      required this.weeklySets,
      required this.balance,
      required this.bodyWeight,
      required this.exerciseNames});

  /// True for free users: history and trends are limited to [kFreeProgressDays].
  final bool limited;

  /// Newest first.
  final List<HistoryEntry> history;
  final List<RecordEntry> records;

  /// Per exercise slug, oldest first.
  final Map<String, List<E1rmPoint>> e1rmTrend;

  /// Oldest week first.
  final List<WeekVolume> weeklySets;

  /// Pro only (FR-040); null for free users.
  final MuscleBalance? balance;

  /// Oldest first; not limited by tier.
  final List<BodyWeightPoint> bodyWeight;

  /// slug → (en, fr) for labels.
  final Map<String, (String, String)> exerciseNames;
}

/// History, records, e1RM trends, weekly sets per muscle and body weight from the device DB
/// (FR-039–FR-041). Works offline; body-weight writes go through the sync queue.
class ProgressRepository {
  ProgressRepository({required AppDatabase db, required SyncQueue syncQueue, required DateTime Function() clock})
      : _db = db,
        _queue = syncQueue,
        _clock = clock;

  final AppDatabase _db;
  final SyncQueue _queue;
  final DateTime Function() _clock;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
  static DateTime _monday(DateTime t) => _day(t).subtract(Duration(days: t.weekday - DateTime.monday));
  static double _e1rm(double kg, int reps) => kg * (1 + reps / 30);

  Future<ProgressData> load(String userId, {required bool isPro}) async {
    final since = isPro ? null : _day(_clock()).subtract(const Duration(days: kFreeProgressDays - 1));

    final logsQuery = _db.select(_db.workoutLogs)
      ..where((w) => w.userId.equals(userId) & w.finishedAt.isNotNull())
      ..orderBy([(w) => OrderingTerm.desc(w.finishedAt)]);
    if (since != null) logsQuery.where((w) => w.finishedAt.isBiggerOrEqualValue(since));
    final logs = await logsQuery.get();
    final logIds = logs.map((l) => l.id).toList();

    final sessions = {for (final s in await _db.select(_db.sessions).get()) s.id: s};
    final planExercises = {for (final p in await _db.select(_db.planExercises).get()) p.id: p};
    final exercises = {for (final e in await _db.select(_db.exercises).get()) e.slug: e};
    final sets = logIds.isEmpty
        ? const <SetLog>[]
        : await (_db.select(_db.setLogs)..where((s) => s.workoutLogId.isIn(logIds))).get();
    final setsByLog = <String, List<SetLog>>{};
    for (final s in sets) {
      (setsByLog[s.workoutLogId] ??= []).add(s);
    }

    final history = [
      for (final l in logs)
        HistoryEntry(
          workoutLogId: l.id,
          finishedAt: l.finishedAt!,
          sessionNameEn: sessions[l.sessionId]?.nameEn ?? '',
          sessionNameFr: sessions[l.sessionId]?.nameFr ?? '',
          totalVolumeKg:
              l.totalVolumeKg ?? (setsByLog[l.id] ?? const []).fold(0.0, (sum, s) => sum + s.weightKg * s.reps),
        ),
    ];

    String? slugOf(SetLog s) => planExercises[s.planExerciseId]?.exerciseSlug;
    List<String> musclesOf(String? slug) {
      final e = slug == null ? null : exercises[slug];
      return e == null ? const [] : (jsonDecode(e.musclePrimary) as List).cast<String>();
    }

    // e1RM trend: best loaded set per exercise per day.
    final bestByDay = <String, Map<DateTime, double>>{};
    for (final s in sets) {
      final slug = slugOf(s);
      if (slug == null || s.weightKg <= 0 || s.reps <= 0) continue;
      final day = _day(s.loggedAt);
      final perDay = bestByDay[slug] ??= {};
      final v = _e1rm(s.weightKg, s.reps);
      if (v > (perDay[day] ?? 0)) perDay[day] = v;
    }
    final e1rmTrend = {
      for (final entry in bestByDay.entries)
        entry.key: (entry.value.entries.map((d) => E1rmPoint(d.key, d.value)).toList()
          ..sort((a, b) => a.day.compareTo(b.day))),
    };

    // Weekly working sets per primary muscle.
    final weeks = <DateTime, Map<String, int>>{};
    for (final s in sets) {
      final perMuscle = weeks[_monday(s.loggedAt)] ??= {};
      for (final m in musclesOf(slugOf(s))) {
        perMuscle[m] = (perMuscle[m] ?? 0) + 1;
      }
    }
    final weeklySets = (weeks.entries.map((w) => WeekVolume(w.key, w.value)).toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart)));

    MuscleBalance? balance;
    if (isPro) {
      var push = 0, pull = 0;
      for (final w in weeklySets) {
        for (final m in w.setsByMuscle.entries) {
          if (_push.contains(m.key)) push += m.value;
          if (_pull.contains(m.key)) pull += m.value;
        }
      }
      balance = MuscleBalance(push, pull);
    }

    final records = [
      for (final r in await (_db.select(_db.personalRecords)..where((r) => r.userId.equals(userId))).get())
        RecordEntry(
          exerciseSlug: r.exerciseSlug,
          exerciseNameEn: exercises[r.exerciseSlug]?.nameEn ?? r.exerciseSlug,
          exerciseNameFr: exercises[r.exerciseSlug]?.nameFr ?? r.exerciseSlug,
          bestWeightKg: r.bestWeightKg,
          bestReps: r.bestReps,
          bestE1rmKg: r.bestE1rm,
          achievedAt: r.achievedAt,
        ),
    ]..sort((a, b) => a.exerciseNameEn.compareTo(b.exerciseNameEn));

    final bodyWeight = [
      for (final b in await (_db.select(_db.bodyWeightEntries)
            ..where((b) => b.userId.equals(userId))
            ..orderBy([(b) => OrderingTerm.asc(b.measuredOn)]))
          .get())
        BodyWeightPoint(b.measuredOn, b.weightKg),
    ];

    return ProgressData(
      limited: !isPro,
      history: history,
      records: records,
      e1rmTrend: e1rmTrend,
      weeklySets: weeklySets,
      balance: balance,
      bodyWeight: bodyWeight,
      exerciseNames: {for (final e in exercises.values) e.slug: (e.nameEn, e.nameFr)},
    );
  }

  /// Saves today's body weight in kg (FR-041). One entry per day: a second entry the same day
  /// replaces the first locally and on the server (same id, queued as an update).
  Future<void> logBodyWeight(String userId, double weightKg, {required DateTime day}) async {
    if (weightKg <= 0) throw ArgumentError.value(weightKg, 'weightKg', 'must be > 0');
    final measuredOn = _day(day);
    final dateText = '${measuredOn.year.toString().padLeft(4, '0')}-'
        '${measuredOn.month.toString().padLeft(2, '0')}-${measuredOn.day.toString().padLeft(2, '0')}';
    final existing = await (_db.select(_db.bodyWeightEntries)
          ..where((b) => b.userId.equals(userId) & b.measuredOn.equals(measuredOn)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.bodyWeightEntries)..where((b) => b.id.equals(existing.id)))
          .write(BodyWeightEntriesCompanion(weightKg: Value(weightKg)));
      await _queue.enqueue(
        operation: 'update',
        tableName: 'body_weight_entries',
        payload: {'id': existing.id, 'weight_kg': weightKg},
      );
      return;
    }
    final id = _uuid.v4();
    await _db.into(_db.bodyWeightEntries).insert(
          BodyWeightEntriesCompanion.insert(id: id, userId: userId, weightKg: weightKg, measuredOn: measuredOn),
        );
    await _queue.enqueue(
      operation: 'insert',
      tableName: 'body_weight_entries',
      payload: {'id': id, 'user_id': userId, 'weight_kg': weightKg, 'measured_on': dateText},
    );
  }
}
