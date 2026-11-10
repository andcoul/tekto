import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/exercise_model.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/exercise_dao.dart';

/// Reads exercises from local Drift DB when offline; syncs from Supabase when online.
class ExerciseRepository {
  ExerciseRepository({
    required AppDatabase db,
    required SupabaseClient supabase,
  })  : _exerciseDao = ExerciseDao(db),
        _supabase = supabase;

  final ExerciseDao _exerciseDao;
  final SupabaseClient _supabase;

  Future<List<ExerciseModel>> getAll() async {
    try {
      final remote = await _fetchFromSupabase();
      await _cacheLocally(remote);
      return remote;
    } catch (_) {
      return _getAllLocal();
    }
  }

  Future<ExerciseModel?> getById(String slug) async {
    try {
      final row = await _supabase
          .from('exercises')
          .select()
          .eq('slug', slug)
          .maybeSingle();
      if (row != null) return ExerciseModel.fromJson(row);
    } catch (_) {}
    final local = await _exerciseDao.getBySlug(slug);
    if (local == null) return null;
    return _toModel(local);
  }

  Future<List<ExerciseModel>> getByEquipment(List<String> equipment) async {
    final all = await getAll();
    return all
        .where((e) => e.equipment.any(equipment.contains))
        .toList();
  }

  Future<List<ExerciseModel>> getByMuscle(String muscle) async {
    final all = await getAll();
    return all
        .where((e) => e.musclePrimary.contains(muscle) || e.muscleSecondary.contains(muscle))
        .toList();
  }

  Future<List<ExerciseModel>> _fetchFromSupabase() async {
    final rows = await _supabase.from('exercises').select().order('name_en');
    return (rows as List).map((r) => ExerciseModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> _cacheLocally(List<ExerciseModel> models) async {
    final companions = models.map(_toCompanion).toList();
    await _exerciseDao.upsertAll(companions);
  }

  Future<List<ExerciseModel>> _getAllLocal() async {
    final rows = await _exerciseDao.getAll();
    return rows.map(_toModel).toList();
  }

  static ExerciseModel _toModel(Exercise row) => ExerciseModel(
        slug: row.slug,
        nameEn: row.nameEn,
        nameFr: row.nameFr,
        equipment: _parseList(row.equipment),
        musclePrimary: _parseList(row.musclePrimary),
        muscleSecondary: _parseList(row.muscleSecondary),
        cuesEn: _parseList(row.cuesEn),
        cuesFr: _parseList(row.cuesFr),
        commonMistakesEn: _parseList(row.commonMistakesEn),
        commonMistakesFr: _parseList(row.commonMistakesFr),
        videoFrontUrl: row.videoFrontUrl,
        videoSideUrl: row.videoSideUrl,
        variationEasierSlug: row.variationEasierSlug,
        variationHarderSlug: row.variationHarderSlug,
        formCheckSupported: row.formCheckSupported,
        formCheckLiftKey: row.formCheckLiftKey,
      );

  static ExercisesCompanion _toCompanion(ExerciseModel m) => ExercisesCompanion.insert(
        slug: m.slug,
        nameEn: m.nameEn,
        nameFr: m.nameFr,
        equipment: _encodeList(m.equipment),
        musclePrimary: _encodeList(m.musclePrimary),
        muscleSecondary: _encodeList(m.muscleSecondary),
        cuesEn: _encodeList(m.cuesEn),
        cuesFr: _encodeList(m.cuesFr),
        commonMistakesEn: _encodeList(m.commonMistakesEn),
        commonMistakesFr: _encodeList(m.commonMistakesFr),
        videoFrontUrl: Value(m.videoFrontUrl),
        videoSideUrl: Value(m.videoSideUrl),
        variationEasierSlug: Value(m.variationEasierSlug),
        variationHarderSlug: Value(m.variationHarderSlug),
        formCheckSupported: m.formCheckSupported,
        formCheckLiftKey: Value(m.formCheckLiftKey),
      );

  static List<String> _parseList(String json) {
    // Simple JSON array parse; assumes well-formed input
    final stripped = json.trim().replaceAll(RegExp(r'^\[|\]$'), '');
    if (stripped.isEmpty) return [];
    return stripped
        .split(',')
        .map((s) => s.trim().replaceAll(RegExp(r'^"|"$'), ''))
        .toList();
  }

  static String _encodeList(List<String> list) =>
      '[${list.map((s) => '"$s"').join(',')}]';
}
