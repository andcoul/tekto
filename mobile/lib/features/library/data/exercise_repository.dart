import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/exercise_model.dart';
import '../../../shared/services/local_db/daos/exercise_dao.dart';
import '../../../shared/services/local_db/database.dart';

/// Fetches all `exercises` rows (snake_case columns, as returned by PostgREST).
typedef ExerciseRowsFetcher = Future<List<Map<String, dynamic>>> Function();

/// Library access with an offline cache (Constitution I v2.0.0).
///
/// Online, the whole library (≤ a few hundred rows) is fetched and cached, so the text of every
/// exercise in the active plan — names, cues, mistakes — is on the device for **all** users.
/// Offline video is a separate Pro feature (video_download_service.dart).
class ExerciseRepository {
  ExerciseRepository({required AppDatabase db, required ExerciseRowsFetcher fetchRemote})
      : _exerciseDao = ExerciseDao(db),
        _fetchRemote = fetchRemote;

  /// Production wiring: reads `exercises` from Supabase.
  factory ExerciseRepository.supabase({required AppDatabase db, required SupabaseClient supabase}) =>
      ExerciseRepository(
        db: db,
        fetchRemote: () async {
          final rows = await supabase.from('exercises').select().order('name_en');
          return List<Map<String, dynamic>>.from(rows);
        },
      );

  final ExerciseDao _exerciseDao;
  final ExerciseRowsFetcher _fetchRemote;

  /// All exercises sorted by English name; refreshes the cache when online.
  Future<List<ExerciseModel>> getAll() async {
    try {
      final remote = (await _fetchRemote()).map(ExerciseModel.fromJson).toList();
      await _exerciseDao.upsertAll(remote.map(_toCompanion).toList());
      return _sorted(remote);
    } on Exception {
      return _getAllLocal();
    }
  }

  Future<ExerciseModel?> getById(String slug) async {
    final all = await getAll();
    for (final e in all) {
      if (e.slug == slug) return e;
    }
    return null;
  }

  /// Cached exercises for [slugs] (e.g. the active plan), sorted; works offline.
  Future<List<ExerciseModel>> getBySlugs(Iterable<String> slugs) async {
    final rows = await _exerciseDao.getBySlugs(slugs);
    return _sorted(rows.map(_toModel).toList());
  }

  Future<List<ExerciseModel>> getByEquipment(List<String> equipment) async {
    final all = await getAll();
    return all.where((e) => e.equipment.any(equipment.contains)).toList();
  }

  Future<List<ExerciseModel>> getByMuscle(String muscle) async {
    final all = await getAll();
    return all.where((e) => e.musclePrimary.contains(muscle) || e.muscleSecondary.contains(muscle)).toList();
  }

  Future<List<ExerciseModel>> _getAllLocal() async {
    final rows = await _exerciseDao.getAll();
    return rows.map(_toModel).toList();
  }

  static List<ExerciseModel> _sorted(List<ExerciseModel> list) =>
      list..sort((a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()));

  static ExerciseModel _toModel(Exercise row) => ExerciseModel(
        slug: row.slug,
        nameEn: row.nameEn,
        nameFr: row.nameFr,
        equipment: _decode(row.equipment),
        musclePrimary: _decode(row.musclePrimary),
        muscleSecondary: _decode(row.muscleSecondary),
        cuesEn: _decode(row.cuesEn),
        cuesFr: _decode(row.cuesFr),
        commonMistakesEn: _decode(row.commonMistakesEn),
        commonMistakesFr: _decode(row.commonMistakesFr),
        videoFrontUrl: row.videoFrontUrl,
        videoSideUrl: row.videoSideUrl,
        videoDurationSec: row.videoDurationSec,
        captionsEnUrl: row.captionsEnUrl,
        captionsFrUrl: row.captionsFrUrl,
        contraindications: _decode(row.contraindications),
        variationEasierSlug: row.variationEasierSlug,
        variationHarderSlug: row.variationHarderSlug,
        formCheckSupported: row.formCheckSupported,
        formCheckLiftKey: row.formCheckLiftKey,
      );

  static ExercisesCompanion _toCompanion(ExerciseModel m) => ExercisesCompanion.insert(
        slug: m.slug,
        nameEn: m.nameEn,
        nameFr: m.nameFr,
        equipment: jsonEncode(m.equipment),
        musclePrimary: jsonEncode(m.musclePrimary),
        muscleSecondary: jsonEncode(m.muscleSecondary),
        cuesEn: jsonEncode(m.cuesEn),
        cuesFr: jsonEncode(m.cuesFr),
        commonMistakesEn: jsonEncode(m.commonMistakesEn),
        commonMistakesFr: jsonEncode(m.commonMistakesFr),
        videoFrontUrl: Value(m.videoFrontUrl),
        videoSideUrl: Value(m.videoSideUrl),
        videoDurationSec: Value(m.videoDurationSec),
        captionsEnUrl: Value(m.captionsEnUrl),
        captionsFrUrl: Value(m.captionsFrUrl),
        contraindications: Value(jsonEncode(m.contraindications)),
        variationEasierSlug: Value(m.variationEasierSlug),
        variationHarderSlug: Value(m.variationHarderSlug),
        formCheckSupported: Value(m.formCheckSupported),
        formCheckLiftKey: Value(m.formCheckLiftKey),
      );

  static List<String> _decode(String json) => (jsonDecode(json) as List).cast<String>();
}
