// T108 — written before handler.ts (contracts/backend-api.md §6). RevenueCat reports a trial as
// INITIAL_PURCHASE with period_type TRIAL and its conversion as RENEWAL with is_trial_conversion;
// the contract's TRIAL_STARTED / TRIAL_CONVERTED names are accepted as aliases.
import { assertEquals } from 'jsr:@std/assert@1';
import { handleWebhook, type SubscriptionRow, type WebhookDeps } from './handler.ts';

const SECRET = 'rc-secret';
const T0 = Date.UTC(2026, 10, 15, 10); // purchase
const DAY = 86_400_000;

function store() {
  const rows = new Map<string, SubscriptionRow>();
  const deps: WebhookDeps = {
    load: (userId) => Promise.resolve(rows.get(userId) ?? null),
    save: (row) => {
      rows.set(row.user_id, { ...row });
      return Promise.resolve();
    },
  };
  return { rows, deps };
}

const event = (type: string, o: Record<string, unknown> = {}) => ({
  event: {
    id: `evt-${type}`, type, app_user_id: 'u1', original_app_user_id: '$RCAnonymousID:abc',
    period_type: 'NORMAL', purchased_at_ms: T0, expiration_at_ms: T0 + 30 * DAY, event_timestamp_ms: T0, ...o,
  },
});

const send = (deps: WebhookDeps, body: unknown, auth = `Bearer ${SECRET}`) =>
  handleWebhook({ authorization: auth, body, secret: SECRET }, deps);

const iso = (ms: number) => new Date(ms).toISOString();

Deno.test('rejects a wrong or missing secret', async () => {
  const { deps, rows } = store();
  assertEquals((await send(deps, event('INITIAL_PURCHASE'), 'Bearer nope')).status, 401);
  assertEquals((await handleWebhook({ authorization: `Bearer ${SECRET}`, body: event('INITIAL_PURCHASE'), secret: '' }, deps)).status, 401);
  assertEquals(rows.size, 0);
});

Deno.test('INITIAL_PURCHASE (normal period) → pro, not a trial, period end set', async () => {
  const { deps, rows } = store();
  assertEquals((await send(deps, event('INITIAL_PURCHASE'))).status, 200);
  const r = rows.get('u1')!;
  assertEquals([r.tier, r.is_trial, r.current_period_ends_at, r.trial_ends_at], ['pro', false, iso(T0 + 30 * DAY), null]);
  assertEquals(r.revenuecat_customer_id, '$RCAnonymousID:abc', 'the customer id, never the event id');
});

Deno.test('a trial: INITIAL_PURCHASE with period_type TRIAL, or the TRIAL_STARTED alias', async () => {
  for (const e of [event('INITIAL_PURCHASE', { period_type: 'TRIAL', expiration_at_ms: T0 + 7 * DAY }),
    event('TRIAL_STARTED', { expiration_at_ms: T0 + 7 * DAY })]) {
    const { deps, rows } = store();
    await send(deps, e);
    const r = rows.get('u1')!;
    assertEquals([r.tier, r.is_trial, r.trial_ends_at, r.current_period_ends_at], ['pro', true, iso(T0 + 7 * DAY), iso(T0 + 7 * DAY)]);
  }
});

Deno.test('RENEWAL updates the period end; a trial conversion clears the trial', async () => {
  const { deps, rows } = store();
  await send(deps, event('INITIAL_PURCHASE', { period_type: 'TRIAL', expiration_at_ms: T0 + 7 * DAY }));
  await send(deps, event('RENEWAL', { is_trial_conversion: true, expiration_at_ms: T0 + 37 * DAY }));
  let r = rows.get('u1')!;
  assertEquals([r.tier, r.is_trial, r.trial_ends_at, r.current_period_ends_at], ['pro', false, null, iso(T0 + 37 * DAY)]);

  await send(deps, event('RENEWAL', { expiration_at_ms: T0 + 67 * DAY }));
  r = rows.get('u1')!;
  assertEquals(r.current_period_ends_at, iso(T0 + 67 * DAY));
});

Deno.test('TRIAL_CONVERTED alias behaves like a trial-conversion renewal', async () => {
  const { deps, rows } = store();
  await send(deps, event('TRIAL_STARTED', { expiration_at_ms: T0 + 7 * DAY }));
  await send(deps, event('TRIAL_CONVERTED', { expiration_at_ms: T0 + 37 * DAY }));
  const r = rows.get('u1')!;
  assertEquals([r.tier, r.is_trial, r.trial_ends_at], ['pro', false, null]);
});

Deno.test('CANCELLATION sets cancelled_at at the event time and keeps Pro until expiry; UNCANCELLATION clears it', async () => {
  const { deps, rows } = store();
  await send(deps, event('INITIAL_PURCHASE'));
  await send(deps, event('CANCELLATION', { event_timestamp_ms: T0 + 3 * DAY }));
  let r = rows.get('u1')!;
  assertEquals([r.tier, r.cancelled_at], ['pro', iso(T0 + 3 * DAY)]);
  await send(deps, event('UNCANCELLATION'));
  r = rows.get('u1')!;
  assertEquals(r.cancelled_at, null);
});

Deno.test('EXPIRATION → free with period fields cleared', async () => {
  const { deps, rows } = store();
  await send(deps, event('INITIAL_PURCHASE', { period_type: 'TRIAL' }));
  await send(deps, event('EXPIRATION'));
  const r = rows.get('u1')!;
  assertEquals([r.tier, r.is_trial, r.current_period_ends_at, r.trial_ends_at, r.cancelled_at], ['free', false, null, null, null]);
});

Deno.test('BILLING_ISSUE is logged and never downgrades', async () => {
  const { deps, rows } = store();
  await send(deps, event('INITIAL_PURCHASE'));
  const before = { ...rows.get('u1')! };
  assertEquals((await send(deps, event('BILLING_ISSUE'))).status, 200);
  assertEquals(rows.get('u1'), before);
});

Deno.test('replaying the same event leaves the same row (idempotent)', async () => {
  const { deps, rows } = store();
  const e = event('INITIAL_PURCHASE', { period_type: 'TRIAL' });
  await send(deps, e);
  const once = { ...rows.get('u1')! };
  await send(deps, e);
  assertEquals(rows.get('u1'), once);
});

Deno.test('unknown events and events for a user with no row are acknowledged without writes', async () => {
  const { deps, rows } = store();
  assertEquals((await send(deps, event('SUBSCRIBER_ALIAS'))).status, 200);
  assertEquals((await send(deps, event('RENEWAL'))).status, 200, 'renewal with no row: nothing to update');
  assertEquals(rows.size, 0);
});

Deno.test('malformed bodies are 400', async () => {
  const { deps } = store();
  assertEquals((await send(deps, {})).status, 400);
  assertEquals((await send(deps, { event: { type: 'RENEWAL' } })).status, 400);
});

// ---- T115: history needed by the Gate 2 metrics (trial start rate SC-006, trial-to-paid SC-007) ----

Deno.test('a trial start is recorded once, and kept through conversion and expiry', async () => {
  const { deps, rows } = store();
  await send(deps, event('INITIAL_PURCHASE', { period_type: 'TRIAL', expiration_at_ms: T0 + 7 * DAY }));
  assertEquals(rows.get('u1')!.trial_started_at, iso(T0));

  await send(deps, event('RENEWAL', { is_trial_conversion: true, expiration_at_ms: T0 + 37 * DAY, event_timestamp_ms: T0 + 7 * DAY }));
  assertEquals(rows.get('u1')!.trial_converted_at, iso(T0 + 7 * DAY));

  await send(deps, event('EXPIRATION', { event_timestamp_ms: T0 + 40 * DAY }));
  const r = rows.get('u1')!;
  assertEquals([r.tier, r.trial_started_at, r.trial_converted_at], ['free', iso(T0), iso(T0 + 7 * DAY)]);
});

Deno.test('replaying a trial start or conversion keeps the first timestamps', async () => {
  const { deps, rows } = store();
  await send(deps, event('TRIAL_STARTED', { expiration_at_ms: T0 + 7 * DAY }));
  await send(deps, event('TRIAL_STARTED', { expiration_at_ms: T0 + 7 * DAY, event_timestamp_ms: T0 + DAY }));
  assertEquals(rows.get('u1')!.trial_started_at, iso(T0));
  await send(deps, event('TRIAL_CONVERTED', { expiration_at_ms: T0 + 37 * DAY, event_timestamp_ms: T0 + 7 * DAY }));
  await send(deps, event('TRIAL_CONVERTED', { expiration_at_ms: T0 + 37 * DAY, event_timestamp_ms: T0 + 8 * DAY }));
  assertEquals(rows.get('u1')!.trial_converted_at, iso(T0 + 7 * DAY));
});

Deno.test('a purchase without a trial records neither timestamp', async () => {
  const { deps, rows } = store();
  await send(deps, event('INITIAL_PURCHASE'));
  const r = rows.get('u1')!;
  assertEquals([r.trial_started_at, r.trial_converted_at], [null, null]);
});
