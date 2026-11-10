import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/exercise_model.dart';
import '../../../core/di/providers.dart';
import '../data/exercise_repository.dart';
import '../data/video_download_service.dart';

part 'exercise_provider.g.dart';

@riverpod
ExerciseRepository exerciseRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = Supabase.instance.client;
  return ExerciseRepository.supabase(db: db, supabase: supabase);
}

@riverpod
Future<List<ExerciseModel>> exercises(Ref ref) {
  return ref.watch(exerciseRepositoryProvider).getAll();
}

@riverpod
class FilteredExercises extends _$FilteredExercises {
  @override
  Future<List<ExerciseModel>> build({
    String? equipment,
    String? muscle,
    String? query,
  }) async {
    var all = await ref.watch(exercisesProvider.future);

    if (equipment != null) {
      all = all.where((e) => e.equipment.contains(equipment)).toList();
    }
    if (muscle != null) {
      all = all
          .where((e) =>
              e.musclePrimary.contains(muscle) ||
              e.muscleSecondary.contains(muscle))
          .toList();
    }
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      all = all
          .where((e) =>
              e.nameEn.toLowerCase().contains(q) ||
              e.nameFr.toLowerCase().contains(q) ||
              e.musclePrimary.any((m) => m.contains(q)))
          .toList();
    }
    return all;
  }
}

// Forward the appDatabaseProvider so it doesn't need an import in this file.
// The actual provider lives in core/di/providers.dart — referenced here via
// generated code after build_runner runs.

@Riverpod(keepAlive: true)
VideoDownloadService videoDownloadService(Ref ref) =>
    VideoDownloadService.live(db: ref.watch(appDatabaseProvider), dio: ref.watch(dioClientProvider));

/// The offline copy of [slug]'s video, if one was downloaded on this device.
@riverpod
Future<DownloadedVideo?> exerciseDownload(Ref ref, String slug) =>
    ref.watch(videoDownloadServiceProvider).getDownload(slug);
