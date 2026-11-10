// T020 — written before the ExerciseRepository update (Constitution V).
// Uses a real in-memory Drift DB and a fake remote, so it exercises the repository itself.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/library/data/exercise_repository.dart';
import 'package:tekto/shared/services/local_db/database.dart';

/// A Supabase `exercises` row as returned by PostgREST (snake_case columns).
Map<String, dynamic> row(String slug, String nameEn, List<String> equipment) => {
      'slug': slug,
      'name_en': nameEn,
      'name_fr': '$nameEn (fr)',
      'equipment': equipment,
      'muscle_primary': ['chest'],
      'muscle_secondary': <String>[],
      'cues_en': ['Cue 1 for $slug', 'Cue 2', 'Cue 3'],
      'cues_fr': ['Consigne 1', 'Consigne 2', 'Consigne 3'],
      'common_mistakes_en': ['Mistake'],
      'common_mistakes_fr': ['Erreur'],
      'video_front_url': 'https://video.test/$slug.m3u8',
      'video_side_url': null,
      'video_duration_sec': 10,
      'captions_en_url': 'https://video.test/$slug.en.vtt',
      'captions_fr_url': 'https://video.test/$slug.fr.vtt',
      'contraindications': ['shoulder'],
      'variation_easier_slug': null,
      'variation_harder_slug': null,
      'form_check_supported': false,
      'form_check_lift_key': null,
    };

final remoteRows = [
  row('push-up', 'Push-up', ['bodyweight']),
  row('dumbbell-row', 'Dumbbell Row', ['dumbbell']),
  row('bench-press', 'Bench Press', ['barbell']),
  row('goblet-squat', 'Goblet Squat', ['dumbbell']),
];

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ExerciseRepository online() => ExerciseRepository(db: db, fetchRemote: () async => remoteRows);
  ExerciseRepository offline() =>
      ExerciseRepository(db: db, fetchRemote: () async => throw Exception('no network'));

  test('online: parses snake_case rows and sorts alphabetically by English name', () async {
    final all = await online().getAll();
    expect(all.map((e) => e.slug), ['bench-press', 'dumbbell-row', 'goblet-squat', 'push-up']);
    expect(all.first.captionsEnUrl, 'https://video.test/bench-press.en.vtt');
    expect(all.first.contraindications, ['shoulder']);
  });

  test('getByEquipment filters by equipment and keeps alphabetical order', () async {
    final dumbbell = await online().getByEquipment(['dumbbell']);
    expect(dumbbell.map((e) => e.slug), ['dumbbell-row', 'goblet-squat']);
  });

  test('offline: serves cached text fields (names, cues, mistakes) — no Pro gating', () async {
    await online().getAll(); // populate the cache while online

    final cached = await offline().getAll();
    expect(cached.map((e) => e.slug), ['bench-press', 'dumbbell-row', 'goblet-squat', 'push-up']);
    final pushUp = cached.last;
    expect(pushUp.nameFr, 'Push-up (fr)');
    expect(pushUp.cuesEn, ['Cue 1 for push-up', 'Cue 2', 'Cue 3']);
    expect(pushUp.cuesFr.length, 3);
    expect(pushUp.commonMistakesEn, ['Mistake']);
  });

  test('offline with an empty cache returns an empty list instead of throwing', () async {
    expect(await offline().getAll(), isEmpty);
  });

  test('getBySlugs returns the cached exercises for a plan when offline', () async {
    await online().getAll();
    final plan = await offline().getBySlugs(['push-up', 'goblet-squat']);
    expect(plan.map((e) => e.slug), ['goblet-squat', 'push-up']);
  });

  test('a refresh online replaces stale cached text', () async {
    await online().getAll();
    final updated = [for (final r in remoteRows) {...r, if (r['slug'] == 'push-up') 'cues_en': ['New cue']}];
    await ExerciseRepository(db: db, fetchRemote: () async => updated).getAll();
    final cached = await offline().getBySlugs(['push-up']);
    expect(cached.single.cuesEn, ['New cue']);
  });
}
