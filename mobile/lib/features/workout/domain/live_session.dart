/// Read models for a live workout, built from the device cache only (Constitution I).
library;

/// One exercise slot of today's session, with the exercise text in both languages.
class LiveExercise {
  const LiveExercise({
    required this.planExerciseId,
    required this.slug,
    required this.nameEn,
    required this.nameFr,
    required this.cuesEn,
    required this.cuesFr,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restSec,
    this.rpeTarget,
    this.suggestedWeightKg,
    this.videoUrl,
    this.captions = const {},
    this.localVideoPath,
    this.localCaptions = const {},
    this.formCheckSupported = false,
  });

  final String planExerciseId;
  final String slug;
  final String nameEn;
  final String nameFr;
  final List<String> cuesEn;
  final List<String> cuesFr;
  final int sets;
  final int repsMin;
  final int repsMax;
  final int restSec;
  final double? rpeTarget;
  final double? suggestedWeightKg;
  final String? videoUrl;
  final Map<String, String> captions;
  final String? localVideoPath;
  final Map<String, String> localCaptions;
  final bool formCheckSupported;

  String name(String lang) => lang == 'fr' ? nameFr : nameEn;

  /// The first 3 technique cues (US2 acceptance scenario 2).
  List<String> keyCues(String lang) => (lang == 'fr' ? cuesFr : cuesEn).take(3).toList();
}

class LiveSession {
  const LiveSession({required this.sessionId, required this.nameEn, required this.nameFr, required this.exercises});

  final String sessionId;
  final String nameEn;
  final String nameFr;
  final List<LiveExercise> exercises;

  String name(String lang) => lang == 'fr' ? nameFr : nameEn;
}

/// A set already saved on the device.
class LoggedSet {
  const LoggedSet({
    required this.id,
    required this.planExerciseId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.isPr = false,
  });

  final String id;
  final String planExerciseId;
  final int setNumber;
  final double weightKg;
  final int reps;
  final double? rpe;
  final bool isPr;
}

/// Today's entry on the home screen.
sealed class TodayStatus {
  const TodayStatus();
}

class NoActivePlan extends TodayStatus {
  const NoActivePlan();
}

class RestDay extends TodayStatus {
  const RestDay();
}

class TrainingDay extends TodayStatus {
  const TrainingDay({
    required this.sessionId,
    required this.nameEn,
    required this.nameFr,
    required this.muscleGroups,
    required this.estimatedMin,
  });

  final String sessionId;
  final String nameEn;
  final String nameFr;
  final List<String> muscleGroups;
  final int? estimatedMin;

  String name(String lang) => lang == 'fr' ? nameFr : nameEn;
}

/// Totals shown on the workout summary (US2 acceptance scenario 4).
class WorkoutSummary {
  const WorkoutSummary({
    required this.workoutLogId,
    required this.startedAt,
    required this.totalVolumeKg,
    required this.exercisesCompleted,
    required this.prCount,
  });

  final String workoutLogId;
  final DateTime startedAt;

  /// Σ weight × reps over every logged set, in kg.
  final double totalVolumeKg;
  final int exercisesCompleted;
  final int prCount;
}

/// The two profile settings the workout screens need, with safe defaults offline.
class UserPrefs {
  const UserPrefs({this.unit = 'kg', this.healthSyncEnabled = false});

  /// 'kg' | 'lb' (FR-034).
  final String unit;
  final bool healthSyncEnabled;
}
