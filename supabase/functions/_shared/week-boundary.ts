// Training weeks: Monday–Sunday in the user's IANA time zone, counted from plans.start_date
// (research §10, data-model plans.start_date). US5 adds the week-end helpers (T079/T082).

export interface LocalDate {
  /** YYYY-MM-DD in the user's zone */
  date: string;
  /** 1 = Monday … 7 = Sunday */
  isoWeekday: number;
}

const WEEKDAYS: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

function safeZone(timeZone: string): string {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone });
    return timeZone;
  } catch {
    return 'UTC';
  }
}

/** The calendar date and weekday of [instant] in [timeZone] (invalid zones fall back to UTC). */
export function localDate(instant: Date, timeZone: string): LocalDate {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: safeZone(timeZone),
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      weekday: 'short',
    }).formatToParts(instant).map((p) => [p.type, p.value]),
  );
  return { date: `${parts.year}-${parts.month}-${parts.day}`, isoWeekday: WEEKDAYS[parts.weekday] };
}

/** Adds [days] to a YYYY-MM-DD date (pure calendar arithmetic). */
export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** Monday of the creation week if created Monday–Wednesday (local), otherwise the next Monday. */
export function planStartDate(createdAt: Date, timeZone: string): string {
  const { date, isoWeekday } = localDate(createdAt, timeZone);
  const thisMonday = addDays(date, 1 - isoWeekday);
  return isoWeekday <= 3 ? thisMonday : addDays(thisMonday, 7);
}
