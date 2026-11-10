// T028 — Pro-only downloads; rows recorded only after the file exists.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/library/data/video_download_service.dart';
import 'package:tekto/shared/services/local_db/database.dart';

void main() {
  late AppDatabase db;
  late Directory dir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('tekto_videos');
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  VideoDownloadService service({Set<String> failing = const {}}) => VideoDownloadService(
        db: db,
        fetchUrls: (_) async => [
          {'exercise_slug': 'push-up', 'download_url_front': 'https://dl/push-up.mp4',
            'captions': {'en': 'https://c/en.vtt', 'fr': 'https://c/fr.vtt'}},
          {'exercise_slug': 'broken', 'download_url_front': 'https://dl/broken.mp4', 'captions': <String, String>{}},
        ],
        download: (url, path, _) async {
          if (failing.any(url.contains)) throw const HttpException('failed');
          await File(path).writeAsString('bytes of $url');
        },
        storageDir: () async => dir,
      );

  test('free users cannot download', () {
    expect(service().downloadPlanVideos('plan', isPro: false).toList(), throwsA(isA<ProRequiredException>()));
  });

  test('Pro: downloads video + captions and records them; failed videos are not recorded', () async {
    final events = await service(failing: {'broken'}).downloadPlanVideos('plan', isPro: true).toList();
    expect(events.where((e) => e.status == DownloadStatus.done).map((e) => e.exerciseSlug), ['push-up']);
    expect(events.where((e) => e.status == DownloadStatus.error).map((e) => e.exerciseSlug), ['broken']);

    final pushUp = await service().getDownload('push-up');
    expect(pushUp!.localPath, '${dir.path}/push-up.mp4');
    expect(File(pushUp.localPath).existsSync(), isTrue);
    expect(pushUp.captions.keys, containsAll(['en', 'fr']));
    expect(await service().getDownload('broken'), isNull);
  });

  test('a failed caption download keeps the video', () async {
    final events = await service(failing: {'fr.vtt'}).downloadPlanVideos('plan', isPro: true).toList();
    expect(events.any((e) => e.exerciseSlug == 'push-up' && e.status == DownloadStatus.done), isTrue);
    expect((await service().getDownload('push-up'))!.captions.keys, ['en']);
  });
}
