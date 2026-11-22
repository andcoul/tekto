// Muscle recovery (FR-051): per muscle group, from logged sets, session effort and time since.
import 'dart:math';

import '../../../shared/models/muscle_groups.dart';

/// Sets one workout gave one muscle group.
class TrainedMuscle {
  const TrainedMuscle({required this.group, required this.sets, required this.finishedAt, this.effort});
  final String group;
  final int sets;
  final DateTime finishedAt;

  /// Session effort 1–10 (RPE), when the user rated it.
  final int? effort;
}

class MuscleRecovery {
  const MuscleRecovery({required this.group, required this.percent, required this.readyAt});
  final String group;

  /// 0–100; 100 = fresh.
  final int percent;
  final DateTime readyAt;
  bool get ready => percent >= 100;
}

/// Look-back window: older sessions count as fully recovered.
const recoveryWindow = Duration(days: 7);

/// Hours a group needs after [sets] at [effort] (FR-051).
double hoursNeeded(String group, int sets, int? effort) {
  final base = kBigMuscleGroups.contains(group) ? 72.0 : 48.0;
  final load = (sets / 10).clamp(0.5, 1.5);
  final e = effort == null ? 1.0 : (effort >= 9 ? 1.2 : (effort <= 6 ? 0.8 : 1.0));
  return base * load * e;
}

/// Recovery for every group trained in the window; the least recovered session wins.
Map<String, MuscleRecovery> computeRecovery(Iterable<TrainedMuscle> trained, DateTime now) {
  final out = <String, MuscleRecovery>{};
  for (final t in trained) {
    if (t.sets <= 0 || now.difference(t.finishedAt) > recoveryWindow) continue;
    final need = hoursNeeded(t.group, t.sets, t.effort);
    final elapsed = max(0, now.difference(t.finishedAt).inMinutes) / 60;
    final pct = min(100, (elapsed / need * 100).floor());
    final r = MuscleRecovery(
      group: t.group,
      percent: pct,
      readyAt: t.finishedAt.add(Duration(minutes: (need * 60).round())),
    );
    final prev = out[t.group];
    if (prev == null || r.percent < prev.percent) out[t.group] = r;
  }
  return out;
}

/// Percent for [group], 100 when it was not trained in the window.
int recoveryPercent(Map<String, MuscleRecovery> r, String group) => r[group]?.percent ?? 100;
