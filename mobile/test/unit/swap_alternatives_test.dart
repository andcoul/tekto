// T087 (client) — the swap sheet lists only alternatives the server will accept (FR-028).
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/plan/domain/swap_alternatives.dart';
import 'package:tekto/shared/models/exercise_model.dart';

ExerciseModel ex(String slug, {List<String> equipment = const ['dumbbell'], List<String> muscles = const ['quadriceps'],
        String? video = 'v.m3u8', List<String> contraindications = const []}) =>
    ExerciseModel(
      slug: slug, nameEn: slug, nameFr: slug, equipment: equipment, musclePrimary: muscles, muscleSecondary: const [],
      cuesEn: const [], cuesFr: const [], commonMistakesEn: const [], commonMistakesFr: const [],
      videoFrontUrl: video, contraindications: contraindications, formCheckSupported: false,
    );

void main() {
  final current = ex('goblet-squat', muscles: ['quadriceps', 'glutes']);
  final library = [
    current,
    ex('dumbbell-lunge', muscles: ['quadriceps', 'glutes']),
    ex('hip-thrust', equipment: ['bodyweight'], muscles: ['glutes']),
    ex('barbell-squat', equipment: ['barbell']),
    ex('no-video-squat', video: null),
    ex('knee-squat', contraindications: ['knee']),
    ex('dumbbell-row', muscles: ['lats']),
  ];

  test('same primary muscle, available equipment, has a video, not contraindicated, not the current one', () {
    final slugs = swapAlternatives(library, current: current, equipment: ['dumbbell'], limitations: ['knee']).map((e) => e.slug);
    expect(slugs, ['dumbbell-lunge', 'hip-thrust']);
  });

  test('bodyweight exercises are always available', () {
    final slugs = swapAlternatives(library, current: current, equipment: const [], limitations: const []).map((e) => e.slug);
    expect(slugs, contains('hip-thrust'));
    expect(slugs, isNot(contains('dumbbell-lunge')));
  });

  test('alternatives sharing more primary muscles come first', () {
    final slugs = swapAlternatives(library, current: current, equipment: ['dumbbell'], limitations: const []).map((e) => e.slug);
    expect(slugs.first, 'dumbbell-lunge');
  });
}
