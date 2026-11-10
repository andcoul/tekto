import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/services/api/supabase_client.dart';
import '../../../shared/services/local_db/database.dart';

/// Calls `video-download-urls` for a plan (contracts/backend-api.md §5) and returns `downloads[]`.
typedef DownloadUrlsFetcher = Future<List<Map<String, dynamic>>> Function(String planId);

/// Downloads [url] to [path] and resolves when the file is complete.
typedef FileDownloader = Future<void> Function(String url, String path, void Function(int received, int total) onProgress);

class ProRequiredException implements Exception {
  const ProRequiredException();
  @override
  String toString() => 'Offline video downloads require Tekto Pro';
}

/// Pro-only offline downloads (FR-015, Constitution I v2.0.0): MP4 + EN/FR WebVTT captions per
/// exercise in the plan. A row is written to the device-only `exercise_video_downloads` table only
/// after the video file has fully downloaded.
class VideoDownloadService {
  VideoDownloadService({
    required AppDatabase db,
    required DownloadUrlsFetcher fetchUrls,
    required FileDownloader download,
    required Future<Directory> Function() storageDir,
  })  : _db = db,
        _fetchUrls = fetchUrls,
        _download = download,
        _storageDir = storageDir;

  /// Production wiring through the authenticated Dio client.
  factory VideoDownloadService.live({required AppDatabase db, required TektoDioClient dio}) => VideoDownloadService(
        db: db,
        fetchUrls: (planId) async {
          final response = await dio.post<Map<String, dynamic>>('/functions/v1/video-download-urls', data: {'plan_id': planId});
          return (response.data?['downloads'] as List? ?? const []).cast<Map<String, dynamic>>();
        },
        download: (url, path, onProgress) => dio.dio.download(url, path, onReceiveProgress: onProgress),
        storageDir: () async => Directory('${(await getApplicationDocumentsDirectory()).path}/videos'),
      );

  final AppDatabase _db;
  final DownloadUrlsFetcher _fetchUrls;
  final FileDownloader _download;
  final Future<Directory> Function() _storageDir;

  /// Downloads every exercise video in [planId]. Throws [ProRequiredException] for free users.
  Stream<DownloadProgress> downloadPlanVideos(String planId, {required bool isPro}) async* {
    if (!isPro) throw const ProRequiredException();

    final List<Map<String, dynamic>> downloads;
    try {
      downloads = await _fetchUrls(planId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) throw const ProRequiredException();
      rethrow;
    }

    final dir = await _storageDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);

    var completed = 0;
    for (final item in downloads) {
      final slug = item['exercise_slug'] as String;
      final videoUrl = item['download_url_front'] as String;
      final captions = (item['captions'] as Map? ?? const {}).cast<String, String>();
      yield DownloadProgress(exerciseSlug: slug, completed: completed, total: downloads.length, status: DownloadStatus.downloading);

      try {
        final videoPath = '${dir.path}/$slug.mp4';
        await _download(videoUrl, videoPath, (_, __) {});

        final captionPaths = <String, String>{};
        for (final MapEntry(key: lang, value: url) in captions.entries) {
          final path = '${dir.path}/${slug}_$lang.vtt';
          try {
            await _download(url, path, (_, __) {});
            captionPaths[lang] = path;
          } on Exception {
            // A missing caption track never blocks the video download.
          }
        }

        await _db.into(_db.exerciseVideoDownloads).insertOnConflictUpdate(
              ExerciseVideoDownloadsCompanion.insert(
                exerciseSlug: slug,
                localPath: videoPath,
                captionsLocalPaths: Value(jsonEncode(captionPaths)),
                fileSizeBytes: Value(File(videoPath).lengthSync()),
              ),
            );
        completed++;
        yield DownloadProgress(exerciseSlug: slug, completed: completed, total: downloads.length, status: DownloadStatus.done);
      } on Exception {
        yield DownloadProgress(exerciseSlug: slug, completed: completed, total: downloads.length, status: DownloadStatus.error);
      }
    }
  }

  /// The downloaded video and caption paths for [exerciseSlug], or null if not downloaded.
  Future<DownloadedVideo?> getDownload(String exerciseSlug) async {
    final row = await (_db.select(_db.exerciseVideoDownloads)..where((d) => d.exerciseSlug.equals(exerciseSlug)))
        .getSingleOrNull();
    if (row == null) return null;
    return DownloadedVideo(
      localPath: row.localPath,
      captions: (jsonDecode(row.captionsLocalPaths) as Map).cast<String, String>(),
    );
  }
}

class DownloadedVideo {
  const DownloadedVideo({required this.localPath, required this.captions});
  final String localPath;

  /// Caption file paths keyed by language code.
  final Map<String, String> captions;
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
