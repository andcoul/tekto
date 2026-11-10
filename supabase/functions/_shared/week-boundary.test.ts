// start_date rule (data-model plans.start_date). The week-end cases of T079 are added with US5.
import { assertEquals } from 'jsr:@std/assert@1';
import { localDate, planStartDate } from './week-boundary.ts';

Deno.test('localDate uses the user time zone, not UTC', () => {
  // 2026-11-10 23:30 UTC is already Wednesday 11 Nov in Auckland (UTC+13) and still Tuesday in New York.
  const t = new Date('2026-11-10T23:30:00Z');
  assertEquals(localDate(t, 'Pacific/Auckland'), { date: '2026-11-11', isoWeekday: 3 });
  assertEquals(localDate(t, 'America/New_York'), { date: '2026-11-10', isoWeekday: 2 });
  assertEquals(localDate(t, 'Africa/Abidjan'), { date: '2026-11-10', isoWeekday: 2 });
});

Deno.test('created Monday–Wednesday → this Monday', () => {
  assertEquals(planStartDate(new Date('2026-11-09T08:00:00Z'), 'Europe/Paris'), '2026-11-09'); // Mon
  assertEquals(planStartDate(new Date('2026-11-11T20:00:00Z'), 'Europe/Paris'), '2026-11-09'); // Wed
});

Deno.test('created Thursday–Sunday → next Monday (no 1–3 day week 1)', () => {
  assertEquals(planStartDate(new Date('2026-11-12T08:00:00Z'), 'Europe/Paris'), '2026-11-16'); // Thu
  assertEquals(planStartDate(new Date('2026-11-15T22:00:00Z'), 'Europe/Paris'), '2026-11-16'); // Sun 23:00 Paris
});

Deno.test('the local day decides, across a month and year boundary', () => {
  // Wed 31 Dec 2025 23:30 in Paris is already Thu 1 Jan 2026 in Auckland → next Monday is 5 Jan.
  assertEquals(planStartDate(new Date('2025-12-31T11:30:00Z'), 'Pacific/Auckland'), '2026-01-05');
  assertEquals(planStartDate(new Date('2025-12-31T11:30:00Z'), 'Europe/Paris'), '2025-12-29');
});

Deno.test('an invalid time zone falls back to UTC', () => {
  assertEquals(planStartDate(new Date('2026-11-09T08:00:00Z'), 'Not/AZone'), '2026-11-09');
});
