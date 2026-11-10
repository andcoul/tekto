// Subscription gate (Constitution V) — written before entitlement.ts.
import { assertEquals } from 'jsr:@std/assert@1';
import { isPro } from './entitlement.ts';

const now = new Date('2026-11-10T12:00:00Z');
const later = '2026-11-13T00:00:00Z';
const earlier = '2026-11-07T00:00:00Z';

Deno.test('isPro: tier == pro AND (period active OR (trial AND trial active))', () => {
  assertEquals(isPro(null, now), false);
  assertEquals(isPro({ tier: 'free', is_trial: false, current_period_ends_at: later, trial_ends_at: null }, now), false);
  assertEquals(isPro({ tier: 'pro', is_trial: false, current_period_ends_at: later, trial_ends_at: null }, now), true);
  assertEquals(isPro({ tier: 'pro', is_trial: false, current_period_ends_at: earlier, trial_ends_at: null }, now), false);
  assertEquals(isPro({ tier: 'pro', is_trial: true, current_period_ends_at: null, trial_ends_at: later }, now), true);
  assertEquals(isPro({ tier: 'pro', is_trial: true, current_period_ends_at: null, trial_ends_at: earlier }, now), false);
  // Expired trial flag but active paid period → still Pro (the old helper returned false here).
  assertEquals(isPro({ tier: 'pro', is_trial: true, current_period_ends_at: later, trial_ends_at: earlier }, now), true);
  // A trial end date without the trial flag does not grant Pro.
  assertEquals(isPro({ tier: 'pro', is_trial: false, current_period_ends_at: null, trial_ends_at: later }, now), false);
});
