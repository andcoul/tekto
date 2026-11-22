// Profile tab (FR-053): streak, heatmap levels and badges, computed from local workouts.
import 'dart:math';

import '../../social/domain/weekly_score.dart';

/// One finished workout.
class WorkoutDay {
  const WorkoutDay(this.finishedAt, this.volumeKg);
  final DateTime finishedAt;
  final double volumeKg;
}

/// Consecutive weeks meeting [perWeek] sessions, counted back from last week; this week adds one
/// once it is met (an unfinished current week does not break the streak).
int streakWeeks(List<WorkoutDay> workouts, int perWeek, DateTime now) {
  final target = max(1, perWeek);
  final counts = <DateTime, int>{};
  for (final w in workouts) {
    final k = weekStartOf(w.finishedAt);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final thisWeek = weekStartOf(now);
  var streak = (counts[thisWeek] ?? 0) >= target ? 1 : 0;
  for (var wk = thisWeek.subtract(const Duration(days: 7));; wk = wk.subtract(const Duration(days: 7))) {
    if ((counts[wk] ?? 0) < target) break;
    streak++;
  }
  return streak;
}

/// Heatmap level 0–4 per day: 0 = rest, then quartiles of the year's training-day volumes.
Map<DateTime, int> heatmapLevels(List<WorkoutDay> workouts, int year) {
  final byDay = <DateTime, double>{};
  for (final w in workouts.where((w) => w.finishedAt.year == year)) {
    final d = DateTime(w.finishedAt.year, w.finishedAt.month, w.finishedAt.day);
    byDay[d] = (byDay[d] ?? 0) + w.volumeKg;
  }
  if (byDay.isEmpty) return const {};
  final sorted = byDay.values.toList()..sort();
  double q(double p) => sorted[min(sorted.length - 1, (p * (sorted.length - 1)).round())];
  final cuts = [q(.25), q(.5), q(.75)];
  return byDay.map((d, v) => MapEntry(d, v <= cuts[0] ? 1 : (v <= cuts[1] ? 2 : (v <= cuts[2] ? 3 : 4))));
}

/// What badges are earned from.
class BadgeStats {
  const BadgeStats({
    required this.workouts,
    required this.bestStreakWeeks,
    required this.recordLifts,
    required this.friends,
    required this.totalVolumeKg,
  });
  final int workouts;
  final int bestStreakWeeks;

  /// Form-check lift keys with at least one record (squat, bench_press, deadlift, …).
  final Set<String> recordLifts;
  final int friends;
  final double totalVolumeKg;
}

enum BadgeKind { streak, workouts, record, friends, volume }

class BadgeDef {
  const BadgeDef(this.id, this.kind, this.threshold, {this.lift});
  final String id;
  final BadgeKind kind;
  final num threshold;
  final String? lift;

  bool earned(BadgeStats s) => switch (kind) {
        BadgeKind.streak => s.bestStreakWeeks >= threshold,
        BadgeKind.workouts => s.workouts >= threshold,
        BadgeKind.record => s.recordLifts.contains(lift),
        BadgeKind.friends => s.friends >= threshold,
        BadgeKind.volume => s.totalVolumeKg >= threshold,
      };
}

/// The 24 launch badges (FR-053).
final kBadges = List<BadgeDef>.unmodifiable([
  for (final w in [1, 2, 3, 4, 8, 12, 26, 52]) BadgeDef('streak_$w', BadgeKind.streak, w),
  for (final n in [1, 10, 25, 50, 100, 250]) BadgeDef('workouts_$n', BadgeKind.workouts, n),
  for (final l in ['squat', 'bench_press', 'deadlift', 'overhead_press', 'row', 'hip_thrust'])
    BadgeDef('record_$l', BadgeKind.record, 1, lift: l),
  const BadgeDef('friends_1', BadgeKind.friends, 1),
  const BadgeDef('friends_5', BadgeKind.friends, 5),
  const BadgeDef('volume_10t', BadgeKind.volume, 10000),
  const BadgeDef('volume_100t', BadgeKind.volume, 100000),
]);

List<BadgeDef> earnedBadges(BadgeStats s) => kBadges.where((b) => b.earned(s)).toList();
