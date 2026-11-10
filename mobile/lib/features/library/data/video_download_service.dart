import 'dart:convert';
import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/api/supabase_client.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/exercise_dao.dart';

const _uuid = Uuid();

class VideoDownloadService {
  VideoDownloadService({
    required TektoDioClient dio,
    required AppDatabase db,
    required String userId,
  })  : _dio = dio,
        _db = db,
        _userId = userId;

  final TektoDioClient _dio;
  final AppDatabase _db;
  final String _userId;

  /// Downloads all exercise videos for the given plan.
  /// Returns a stream of [DownloadProgress] updates.
  Stream<DownloadProgress> downloadPlanVideos(String planId) async* {
    // 1. Request signed URLs from Edge Function
    final response = await _dio.post<Map<String, dynamic>>(
      '/functions/v1/video-download-urls',
      data: {'plan_id': planId},
    );

    final downloads =
        (response.data?['downloads'] as List? ?? []).cast<Map<String, dynamic>>();

    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${dir.path}/videos');
    if (!videosDir.existsSync()) videosDir.createSync(recursive: true);

    int completed = 0;
    for (final item in downloads) {
      final slug = item['exercise_slug'] as String;
      final signedUrl = item['signed_url'] as String;

      yield DownloadProgress(
        exerciseSlug: slug,
        completed: completed,
        total: downloads.length,
        status: DownloadStatus.downloading,
      );

      final fileName = '$slug.mp4';
      final localPath = '${videosDir.path}/$fileName';

      try {
        await FlutterDownloader.enqueue(
          url: signedUrl,
          savedDir: videosDir.path,
          fileName: fileName,
          showNotification: false,
          openFileFromNotification: false,
        );

        // Record in Drift DB
        await _db.into(_db.exerciseVideoDownloads).insertOnConflictUpdate(
              ExerciseVideoDownloadsCompanion.insert(
                id: _uuid.v4(),
                userId: _userId,
                exerciseSlug: slug,
                planId: planId,
                localPath: Value(localPath),
              ),
            );

        completed++;
        yield DownloadProgress(
          exerciseSlug: slug,
          completed: completed,
          total: downloads.length,
          status: DownloadStatus.done,
        );
      } catch (_) {
        yield DownloadProgress(
          exerciseSlug: slug,
          completed: completed,
          total: downloads.length,
          status: DownloadStatus.error,
        );
      }
    }
  }

  /// Returns the local file path for a downloaded video, or null if not downloaded.
  Future<String?> getLocalPath(String exerciseSlug, String planId) async {
    final row = await (_db.select(_db.exerciseVideoDownloads)
          ..where((d) =>
              d.exerciseSlug.equals(exerciseSlug) &
              d.planId.equals(planId) &
              d.userId.equals(_userId)))
        .getSingleOrNull();
    return row?.localPath;
  }
}

enum DownloadStatus { downloading, done, error }

class DownloadProgress {
  const DownloadProgress({
    required this.exerciseSlug,
    required this.completed,
    required this.total,
    required this.status,
  });

  final String exerciseSlug;
  final int completed;
  final int total;
  final DownloadStatus status;

  int get percentage => total == 0 ? 0 : ((completed / total) * 100).round();
}
