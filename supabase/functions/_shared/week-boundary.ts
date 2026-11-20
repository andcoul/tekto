// Training weeks: Monday–Sunday in the user's IANA time zone, counted from plans.start_date
// (research §10, data-model plans.start_date). Week-end helpers: T079/T082 (FR-026).

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

/** Days from [from] to [to] (YYYY-MM-DD), negative when [to] is earlier. */
function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

/** Week [week] (1-based) of a plan starting on [startDate]: Monday to Sunday, local dates. */
export function trainingWeek(startDate: string, week: number): { first: string; last: string } {
  const first = addDays(startDate, 7 * (week - 1));
  return { first, last: addDays(first, 6) };
}

/**
 * True once week [week] is over: its Sunday 23:59 has passed in [timeZone], i.e. the user's
 * local date is after that Sunday. Comparing local dates keeps DST weeks exact.
 */
export function weekEnded(startDate: string, week: number, timeZone: string, now: Date): boolean {
  return localDate(now, timeZone).date > trainingWeek(startDate, week).last;
}

/** The training week [now] falls in for the user; days before [startDate] count as week 1. */
export function weekNumberAt(startDate: string, timeZone: string, now: Date): number {
  const days = daysBetween(startDate, localDate(now, timeZone).date);
  return days < 0 ? 1 : Math.floor(days / 7) + 1;
}
