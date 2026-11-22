// FR-050–FR-053 (2026-11-21): weekly score, recovery, streak, heatmap, badges, figure shapes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/profile/domain/profile_stats.dart';
import 'package:tekto/features/recovery/domain/recovery.dart';
import 'package:tekto/features/social/domain/weekly_score.dart';
import 'package:tekto/shared/models/muscle_groups.dart';
import 'package:tekto/shared/widgets/muscle_figure.dart';

void main() {
  group('weekly score (FR-050)', () {
    test('20 per session up to 7, 1 per set, 10 per record', () {
      expect(weeklyScore(sessions: 1, sets: 2, records: 1), 32, reason: 'same case as the SQL check');
      expect(weeklyScore(sessions: 9, sets: 0, records: 0), 140);
    });
    test('weeks start on Monday', () {
      expect(weekStartOf(DateTime(2026, 11, 23, 18)), DateTime(2026, 11, 23));
      expect(weekStartOf(DateTime(2026, 11, 22, 23)), DateTime(2026, 11, 16));
    });
  });

  group('recovery (FR-051)', () {
    final now = DateTime(2026, 11, 19, 9);
    test('hours needed: big muscles 72 h, small 48 h, scaled by sets and effort', () {
      expect(hoursNeeded('chest', 10, 7), 72);
      expect(hoursNeeded('biceps', 10, 7), 48);
      expect(hoursNeeded('chest', 3, null), 36, reason: 'load factor floors at 0.5');
      expect(hoursNeeded('chest', 30, null), 108, reason: 'load factor caps at 1.5');
      expect(hoursNeeded('chest', 10, 9), closeTo(86.4, 1e-9));
      expect(hoursNeeded('chest', 10, 5), closeTo(57.6, 1e-9));
    });
    test('percent grows with time; the least recovered session wins; old sessions are ignored', () {
      final r = computeRecovery([
        TrainedMuscle(group: 'shoulders', sets: 16, finishedAt: now.subtract(const Duration(hours: 44)), effort: 8),
        TrainedMuscle(group: 'chest', sets: 10, finishedAt: now.subtract(const Duration(hours: 36))),
        TrainedMuscle(group: 'chest', sets: 10, finishedAt: now.subtract(const Duration(hours: 70))),
        TrainedMuscle(group: 'quads', sets: 12, finishedAt: now.subtract(const Duration(days: 8))),
      ], now);
      expect(r['shoulders']!.percent, 61); // 44 h of 48 h × 1.5
      expect(r['chest']!.percent, 50);
      expect(r.containsKey('quads'), isFalse);
      expect(recoveryPercent(r, 'quads'), 100);
      expect(r['chest']!.readyAt, now.add(const Duration(hours: 36)));
    });
    test('a muscle is ready at 100 % and never above', () {
      final r = computeRecovery(
          [TrainedMuscle(group: 'biceps', sets: 6, finishedAt: now.subtract(const Duration(hours: 60)))], now);
      expect(r['biceps']!.percent, 100);
      expect(r['biceps']!.ready, isTrue);
    });
    test('every library muscle used for recovery maps to a group', () {
      for (final m in ['quadriceps', 'lats', 'rhomboids', 'upper_chest', 'front_deltoid', 'core', 'erectors']) {
        expect(muscleGroupOf(m), isNotNull, reason: m);
      }
    });
  });

  group('profile stats (FR-053)', () {
    final now = DateTime(2026, 11, 19); // Wednesday
    List<WorkoutDay> days(List<DateTime> d) => [for (final x in d) WorkoutDay(x, 5000)];
    test('streak counts full weeks back from last week, plus this week once met', () {
      final w = days([
        DateTime(2026, 11, 17), DateTime(2026, 11, 18), // this week: 2 of 3
        DateTime(2026, 11, 10), DateTime(2026, 11, 12), DateTime(2026, 11, 14),
        DateTime(2026, 11, 3), DateTime(2026, 11, 5), DateTime(2026, 11, 7),
        DateTime(2026, 10, 27), // a short week ends the streak
      ]);
      expect(streakWeeks(w, 3, now), 2);
      expect(streakWeeks([...w, WorkoutDay(DateTime(2026, 11, 19), 1)], 3, now), 3);
      expect(streakWeeks(const [], 3, now), 0);
    });
    test('heatmap levels are quartiles of the year', () {
      final lv = heatmapLevels([
        for (var i = 1; i <= 8; i++) WorkoutDay(DateTime(2026, 3, i), i * 1000.0),
        WorkoutDay(DateTime(2025, 3, 1), 9000),
      ], 2026);
      expect(lv.length, 8);
      expect(lv[DateTime(2026, 3, 1)], 1);
      expect(lv[DateTime(2026, 3, 8)], 4);
    });
    test('24 badges, earned from stats', () {
      expect(kBadges.length, 24);
      expect(kBadges.map((b) => b.id).toSet().length, 24);
      final earned = earnedBadges(const BadgeStats(
          workouts: 118, bestStreakWeeks: 3, recordLifts: {'squat'}, friends: 5, totalVolumeKg: 120000));
      expect(earned.map((b) => b.id),
          containsAll(['streak_3', 'workouts_100', 'record_squat', 'friends_5', 'volume_100t']));
      expect(earned.map((b) => b.id), isNot(contains('workouts_250')));
    });
  });

  group('muscle figure', () {
    test('every group has a tile and parts in at least one view', () {
      for (final g in kMuscleGroups) {
        expect(kGroupTiles[g], isNotNull, reason: g);
        expect(kGroupParts[g]!.values.expand((p) => p), isNotEmpty, reason: g);
      }
    });
    test('the shape parser reads paths, ellipses and rounded rectangles', () {
      expect(parseShape('M0 0 L10 0 Q10 10 0 10 Z').getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
      expect(parseShape('E50,50,10,5').getBounds(), const Rect.fromLTRB(40, 45, 60, 55));
      expect(parseShape('R1,2,3,4,1').getBounds(), const Rect.fromLTWH(1, 2, 3, 4));
    });
    test('group levels become part levels per view', () {
      expect(partLevels({'shoulders': 2, 'glutes': 3}, FigureView.back), {'rdelts': 2, 'glutes': 3});
      expect(partLevels({'shoulders': 2, 'glutes': 3}, FigureView.front), {'delts': 2});
    });
  });
}
