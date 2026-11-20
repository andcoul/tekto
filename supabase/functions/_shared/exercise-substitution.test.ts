// T012 — written before exercise-substitution.ts (Constitution V).
import { assertEquals } from 'jsr:@std/assert@1';
import { findSubstitute, isAllowed } from './exercise-substitution.ts';
import { LIBRARY, profile } from './test-fixtures.ts';

const dumbbellOnly = profile({ equipment: ['dumbbell', 'bodyweight'] });

Deno.test('substitutes a barbell lift with the same-muscle dumbbell lift', () => {
  assertEquals(findSubstitute('barbell-squat', dumbbellOnly, LIBRARY)?.slug, 'goblet-squat');
});

Deno.test('never returns an exercise contraindicated by the user limitations', () => {
  const knee = profile({ equipment: ['dumbbell', 'bodyweight'], limitations: ['knee'] });
  // goblet-squat is knee-contraindicated; leg-press needs a machine; nothing else is quad-primary.
  assertEquals(findSubstitute('barbell-squat', knee, LIBRARY), null);
});

Deno.test('never returns an exercise without a video (Video Gate)', () => {
  const p = profile({ equipment: ['cable', 'bodyweight'], limitations: ['shoulder'] });
  assertEquals(findSubstitute('bench-press', p, LIBRARY)?.slug, 'push-up');
  const p2 = profile({ equipment: ['cable', 'bodyweight'], limitations: ['shoulder', 'wrist'] });
  // Only cable-fly is left for chest, and it has no video.
  assertEquals(findSubstitute('bench-press', p2, LIBRARY), null);
});

Deno.test('prefers the closest equipment: a loaded lift over bodyweight for a loaded original', () => {
  assertEquals(findSubstitute('bench-press', dumbbellOnly, LIBRARY)?.slug, 'dumbbell-bench-press');
});

Deno.test('respects the exclude set', () => {
  const sub = findSubstitute('bench-press', dumbbellOnly, LIBRARY, { exclude: new Set(['dumbbell-bench-press']) });
  assertEquals(sub?.slug, 'push-up');
});

Deno.test('never returns the original exercise', () => {
  const full = profile({ equipment: ['barbell', 'dumbbell', 'bodyweight'] });
  assertEquals(findSubstitute('bench-press', full, LIBRARY)?.slug, 'dumbbell-bench-press');
});

Deno.test('unknown slug uses the muscle hint, or returns null without one', () => {
  assertEquals(findSubstitute('made-up-move', dumbbellOnly, LIBRARY), null);
  assertEquals(findSubstitute('made-up-move', dumbbellOnly, LIBRARY, { muscle: 'lats' })?.slug, 'dumbbell-row');
});

Deno.test('isAllowed: equipment must be available, bodyweight always is; limitations exclude', () => {
  const p = profile({ equipment: ['dumbbell'] });
  assertEquals(isAllowed(LIBRARY.get('push-up')!, p), true);
  assertEquals(isAllowed(LIBRARY.get('bench-press')!, p), false);
  assertEquals(isAllowed(LIBRARY.get('dumbbell-row')!, p), true);
  assertEquals(isAllowed(LIBRARY.get('dumbbell-rdl')!, profile({ limitations: ['lower_back'] })), false);
});

// T142 — equipment beyond the loaded basics (FR-001, FR-013, spec Edge Cases; clarified 2026-11-20).
Deno.test('isAllowed: bar, dip station, bench and machine moves need that equipment', () => {
  const dumbbells = profile({ equipment: ['dumbbell', 'bodyweight'] });
  for (const slug of ['pull-up', 'chest-dip', 'bench-dip', 'incline-dumbbell-press', 'leg-press']) {
    assertEquals(isAllowed(LIBRARY.get(slug)!, dumbbells), false, slug);
  }
  assertEquals(isAllowed(LIBRARY.get('leg-press')!, profile({ equipment: ['cable'] })), false, 'cable is not machine');
  assertEquals(isAllowed(LIBRARY.get('leg-press')!, profile({ equipment: ['machine'] })), true);
  assertEquals(isAllowed(LIBRARY.get('pull-up')!, profile({ equipment: ['pull_up_bar'] })), true);
  assertEquals(isAllowed(LIBRARY.get('incline-dumbbell-press')!, profile({ equipment: ['dumbbell', 'bench'] })), true);
});

Deno.test('a dumbbell-only user is never offered a bar or dip-station substitute', () => {
  const dumbbells = profile({ equipment: ['dumbbell', 'bodyweight'] });
  assertEquals(findSubstitute('barbell-row', dumbbells, LIBRARY)?.slug, 'dumbbell-row');
  assertEquals(findSubstitute('barbell-row', dumbbells, LIBRARY, { exclude: new Set(['dumbbell-row']) }), null);
  const noShoulder = profile({ equipment: ['dumbbell', 'bodyweight', 'dip_station'] });
  assertEquals(findSubstitute('bench-press', noShoulder, LIBRARY, { exclude: new Set(['dumbbell-bench-press', 'push-up']) })?.slug, 'chest-dip');
});
