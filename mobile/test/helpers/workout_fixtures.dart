// Shared fixtures for the Phase 5 (US2) widget tests: one active plan with a
// Wednesday session in week 1 containing a loaded and a bodyweight exercise.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:tekto/shared/models/plan_model.dart';
import 'package:tekto/shared/services/local_db/database.dart';

const kUserId = 'u-1';
const kPlanId = 'p-1';
const kSessionId = 's-wed';

/// Wednesday 11 Nov 2026, 18:00 local — a training day for the fixture plan.
final kWednesday = DateTime(2026, 11, 11, 18);

/// Thursday 12 Nov 2026 — a rest day for the fixture plan.
final kThursday = DateTime(2026, 11, 12, 9);

PlanModel fixturePlan({int currentWeek = 1}) => PlanModel(
      id: kPlanId,
      userId: kUserId,
      name: 'Starter plan',
      status: 'active',
      weeksTotal: 4,
      currentWeek: currentWeek,
      startDate: DateTime(2026, 11, 9),
      source: 'template',
      templateSlug: 'beginner-full-body-3x',
      createdAt: DateTime(2026, 11, 9),
      updatedAt: DateTime(2026, 11, 9),
    );

Future<void> seedWorkoutFixture(AppDatabase db, {String unit = 'kg', bool healthSync = false}) async {
  await db.into(db.users).insert(UsersCompanion.insert(
        id: kUserId,
        goal: 'muscle',
        level: 'beginner',
        daysPerWeek: 3,
        sessionLengthMin: 45,
        equipment: jsonEncode(['dumbbell', 'bodyweight']),
        unit: Value(unit),
        healthSyncEnabled: Value(healthSync),
      ));

  await db.batch((b) {
    b.insertAll(db.exercises, [
      ExercisesCompanion.insert(
        slug: 'goblet-squat',
        nameEn: 'Goblet Squat',
        nameFr: 'Squat gobelet',
        equipment: jsonEncode(['dumbbell']),
        musclePrimary: jsonEncode(['quads']),
        muscleSecondary: jsonEncode(['glutes']),
        cuesEn: jsonEncode(['Hold the bell at your chest', 'Knees track over toes', 'Sit between your heels', 'Fourth cue never shown']),
        cuesFr: jsonEncode(['Tiens l’haltère contre la poitrine', 'Genoux dans l’axe des pieds', 'Assieds-toi entre les talons', 'Quatrième consigne']),
        commonMistakesEn: jsonEncode(['Heels lifting']),
        commonMistakesFr: jsonEncode(['Talons qui décollent']),
        videoFrontUrl: const Value('https://video.example/goblet-squat.m3u8'),
      ),
      ExercisesCompanion.insert(
        slug: 'push-up',
        nameEn: 'Push-up',
        nameFr: 'Pompe',
        equipment: jsonEncode(['bodyweight']),
        musclePrimary: jsonEncode(['chest']),
        muscleSecondary: jsonEncode(['triceps']),
        cuesEn: jsonEncode(['Hands under shoulders', 'Body in one line', 'Chest to the floor']),
        cuesFr: jsonEncode(['Mains sous les épaules', 'Corps aligné', 'Poitrine au sol']),
        commonMistakesEn: jsonEncode(['Sagging hips']),
        commonMistakesFr: jsonEncode(['Hanches qui tombent']),
        videoFrontUrl: const Value('https://video.example/push-up.m3u8'),
      ),
    ]);

    b.insert(db.plans, PlansCompanion.insert(
      id: kPlanId,
      userId: kUserId,
      name: 'Starter plan',
      weeksTotal: 4,
      startDate: Value(DateTime(2026, 11, 9)),
      source: const Value('template'),
      templateSlug: const Value('beginner-full-body-3x'),
    ));

    b.insertAll(db.sessions, [
      SessionsCompanion.insert(
        id: kSessionId,
        planId: kPlanId,
        weekNumber: 1,
        dayOfWeek: DateTime.wednesday,
        nameEn: 'Full Body A',
        nameFr: 'Corps entier A',
        muscleGroups: jsonEncode(['quads', 'chest']),
        estimatedMin: const Value(45),
      ),
      // Same weekday in week 2 — must not show while currentWeek = 1.
      SessionsCompanion.insert(
        id: 's-wed-w2',
        planId: kPlanId,
        weekNumber: 2,
        dayOfWeek: DateTime.wednesday,
        nameEn: 'Full Body A (week 2)',
        nameFr: 'Corps entier A (semaine 2)',
        muscleGroups: jsonEncode(['quads', 'chest']),
        estimatedMin: const Value(50),
      ),
    ]);

    b.insertAll(db.planExercises, [
      PlanExercisesCompanion.insert(
        id: 'pe-squat',
        sessionId: kSessionId,
        exerciseSlug: 'goblet-squat',
        sortOrder: const Value(0),
        sets: 2,
        repsMin: 8,
        repsMax: 10,
        rpeTarget: const Value(7),
        restSec: const Value(90),
        suggestedWeightKg: const Value(16),
      ),
      PlanExercisesCompanion.insert(
        id: 'pe-pushup',
        sessionId: kSessionId,
        exerciseSlug: 'push-up',
        sortOrder: const Value(1),
        sets: 1,
        repsMin: 10,
        repsMax: 12,
        restSec: const Value(60),
        suggestedWeightKg: const Value(0),
      ),
    ]);
  });
}
