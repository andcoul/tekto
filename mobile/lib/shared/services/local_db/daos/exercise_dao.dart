import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [Exercises])
class ExerciseDao extends DatabaseAccessor<AppDatabase> with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  /// All exercises, sorted alphabetically by English name.
  Future<List<Exercise>> getAll() =>
      (select(exercises)..orderBy([(e) => OrderingTerm.asc(e.nameEn)])).get();

  /// Watch exercises, filtered optionally by equipment and/or muscle group.
  Stream<List<Exercise>> watchFiltered({
    String? equipment,
    String? muscle,
  }) {
    return (select(exercises)
          ..orderBy([(e) => OrderingTerm.asc(e.nameEn)]))
        .watch()
        .map((all) => all.where((e) {
              if (equipment != null && !e.equipment.contains(equipment)) {
                return false;
              }
              if (muscle != null &&
                  !e.musclePrimary.contains(muscle) &&
                  !e.muscleSecondary.contains(muscle)) {
                return false;
              }
              return true;
            }).toList());
  }

  Future<Exercise?> getBySlug(String slug) =>
      (select(exercises)..where((e) => e.slug.equals(slug))).getSingleOrNull();

  /// Exercises for the given slugs (e.g. every exercise in the active plan, cached for offline use).
  Future<List<Exercise>> getBySlugs(Iterable<String> slugs) =>
      (select(exercises)..where((e) => e.slug.isIn(slugs))).get();

  /// Limitation tags that exclude [exercise] from plans and swaps (JSON array column).
  static List<String> contraindicationsOf(Exercise exercise) =>
      (jsonDecode(exercise.contraindications) as List).cast<String>();

  Future<void> upsertAll(List<ExercisesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(exercises, rows));
}
