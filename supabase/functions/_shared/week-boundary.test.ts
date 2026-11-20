// start_date rule (data-model plans.start_date) and the week-end cases of T079 (FR-026).
import { assertEquals } from 'jsr:@std/assert@1';
import { localDate, planStartDate, trainingWeek, weekEnded, weekNumberAt } from './week-boundary.ts';

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

// ---- T079: week ranges and week end (FR-026) ----

Deno.test('week N spans start_date + 7·(N−1) to +6, Monday to Sunday', () => {
  assertEquals(trainingWeek('2026-11-09', 1), { first: '2026-11-09', last: '2026-11-15' });
  assertEquals(trainingWeek('2026-11-09', 3), { first: '2026-11-23', last: '2026-11-29' });
  assertEquals(trainingWeek('2026-12-28', 1), { first: '2026-12-28', last: '2027-01-03' }); // across the year
});

for (const [zone, lastMinuteUtc, firstMondayMinuteUtc] of [
  // Sunday 15 Nov 2026 23:59 local, and Monday 16 Nov 00:00 local, in UTC.
  ['Europe/Paris', '2026-11-15T22:59:00Z', '2026-11-15T23:00:00Z'],
  ['Africa/Abidjan', '2026-11-15T23:59:00Z', '2026-11-16T00:00:00Z'],
  ['America/New_York', '2026-11-16T04:59:00Z', '2026-11-16T05:00:00Z'],
  ['Pacific/Auckland', '2026-11-15T10:59:00Z', '2026-11-15T11:00:00Z'],
] as const) {
  Deno.test(`week 1 ends at Sunday 23:59 local in ${zone}`, () => {
    assertEquals(weekEnded('2026-11-09', 1, zone, new Date(lastMinuteUtc)), false, 'still Sunday');
    assertEquals(weekEnded('2026-11-09', 1, zone, new Date(firstMondayMinuteUtc)), true, 'Monday 00:00');
  });
}

Deno.test('a DST-change week still ends at local Sunday 23:59 (Paris, clocks back on 25 Oct 2026)', () => {
  // Week Mon 19 – Sun 25 Oct 2026; on Sunday Paris goes from UTC+2 to UTC+1.
  assertEquals(weekEnded('2026-10-19', 1, 'Europe/Paris', new Date('2026-10-25T22:59:00Z')), false);
  assertEquals(weekEnded('2026-10-19', 1, 'Europe/Paris', new Date('2026-10-25T23:00:00Z')), true);
  // New York springs forward on 8 Mar 2026: the week ends Sunday 23:59 EDT = 03:59 UTC Monday.
  assertEquals(weekEnded('2026-03-02', 1, 'America/New_York', new Date('2026-03-09T03:59:00Z')), false);
  assertEquals(weekEnded('2026-03-02', 1, 'America/New_York', new Date('2026-03-09T04:00:00Z')), true);
});

Deno.test('weekNumberAt counts local weeks from start_date; days before it count toward week 1', () => {
  const tz = 'Europe/Paris';
  assertEquals(weekNumberAt('2026-11-16', tz, new Date('2026-11-13T10:00:00Z')), 1, 'Friday before start_date');
  assertEquals(weekNumberAt('2026-11-16', tz, new Date('2026-11-16T10:00:00Z')), 1);
  assertEquals(weekNumberAt('2026-11-16', tz, new Date('2026-11-22T22:30:00Z')), 1, 'Sunday 23:30 Paris');
  assertEquals(weekNumberAt('2026-11-16', tz, new Date('2026-11-22T23:30:00Z')), 2, 'Monday 00:30 Paris');
  assertEquals(weekNumberAt('2026-11-16', tz, new Date('2026-12-07T10:00:00Z')), 4);
});
