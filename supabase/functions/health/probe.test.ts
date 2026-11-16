// T088 — GET /health for the uptime monitor (SC-013; contracts/backend-api.md §9).
import { assertEquals } from 'jsr:@std/assert@1';
import { HealthProbe } from './probe.ts';

function setup(opts: { db?: boolean; ai?: boolean } = {}) {
  let now = Date.parse('2026-11-16T12:00:00Z');
  const calls = { db: 0, ai: 0 };
  const probe = new HealthProbe({
    now: () => now,
    checkDb: () => {
      calls.db++;
      return opts.db === false ? Promise.reject(new Error('db down')) : Promise.resolve();
    },
    checkAi: () => {
      calls.ai++;
      return opts.ai === false ? Promise.reject(new Error('ai down')) : Promise.resolve();
    },
  });
  return { probe, calls, advance: (ms: number) => (now += ms) };
}

Deno.test('200 with every component ok', async () => {
  const { probe } = setup();
  const res = await probe.check();
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: 'ok', db: 'ok', ai: 'ok', checked_at: '2026-11-16T12:00:00.000Z' });
});

Deno.test('503 with db: down when the database fails', async () => {
  const { probe } = setup({ db: false });
  const res = await probe.check();
  assertEquals([res.status, res.body.status, res.body.db, res.body.ai], [503, 'down', 'down', 'ok']);
});

Deno.test('503 with ai: degraded when Anthropic is unreachable', async () => {
  const { probe } = setup({ ai: false });
  const res = await probe.check();
  assertEquals([res.status, res.body.status, res.body.ai], [503, 'degraded', 'degraded']);
});

Deno.test('the AI probe runs at most once per 5 minutes; the DB is checked on every call', async () => {
  const { probe, calls, advance } = setup();
  await probe.check();
  advance(60_000);
  await probe.check();
  advance(3 * 60_000);
  await probe.check();
  assertEquals(calls, { db: 3, ai: 1 });
  advance(60_001); // 5 min after the first probe
  await probe.check();
  assertEquals(calls.ai, 2);
});

Deno.test('a failed AI probe is also cached, so an outage does not multiply calls', async () => {
  const { probe, calls, advance } = setup({ ai: false });
  await probe.check();
  advance(60_000);
  const res = await probe.check();
  assertEquals([calls.ai, res.body.ai], [1, 'degraded']);
});
