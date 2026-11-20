// T084 — weekly plan adaptation (FR-026, FR-027; research §10; contracts/backend-api.md §2).
// Pure orchestration over injected ports; tested by handler.test.ts (T081).
//
// - Week N's logged sets decide week N+1's values (PlanAdaptationService); exercises are matched
//   by session position in the week and exercise slug.
// - Each (plan, week) is claimed once through plans.last_adapted_week, so the early trigger
//   (user mode) and the hourly batch never adapt the same week twice.
// - Batch mode advances current_week for every active plan, reviews each ended, unadapted week
//   in order for Pro plans, and claims it without changes for free plans.
// - The explanation model only words the changes; on any failure the deterministic reasons stay.
import { computeAdaptation, type SetLogRow, type WeekData } from '../_shared/plan-adaptation.ts';
import { weekEnded, weekNumberAt } from '../_shared/week-boundary.ts';

export interface AdaptationRecord {
  plan_exercise_id: string;
  field_changed: 'suggested_weight_kg' | 'reps_max';
  old_value: number;
  new_value: number;
  reason_en: string;
  reason_fr: string;
}

/** One entry of plans.adaptation_log: the stored summary of a reviewed week. */
export interface AdaptationLogEntry {
  week: number;
  adapted_at: string;
  sessions_scheduled: number;
  sessions_completed: number;
  adaptations: AdaptationRecord[];
  summary_en: string;
  summary_fr: string;
}

export interface AdaptPlan {
  id: string;
  user_id: string;
  start_date: string;
  current_week: number;
  weeks_total: number;
  last_adapted_week: number;
  adaptation_log: AdaptationLogEntry[];
  /** users.timezone (IANA). */
  timezone: string;
  /** The owner's server-side entitlement (subscriptions), never the client's claim. */
  pro: boolean;
}

export interface WeekSession {
  id: string;
  day_of_week: number;
  /** Has a workout_logs row with finished_at set. */
  finished: boolean;
  /** workout_logs.effort_rating of that workout (1–10). */
  effort_rating: number | null;
}

export interface WeekExercise {
  id: string;
  session_id: string;
  sort_order: number;
  exercise_slug: string;
  equipment: string[];
  reps_min: number;
  reps_max: number;
  rpe_target: number | null;
  rir_target: number | null;
  suggested_weight_kg: number | null;
}

export interface WeekSnapshot {
  sessions: WeekSession[];
  exercises: WeekExercise[];
  /** Sets of the finished workouts of this week's sessions. */
  setLogs: SetLogRow[];
}

export interface ExplanationInput {
  week: number;
  sessions_scheduled: number;
  sessions_completed: number;
  adaptations: AdaptationRecord[];
}

export interface Explanation {
  reasons: { plan_exercise_id: string; reason_en: string; reason_fr: string }[];
  summary_en: string;
  summary_fr: string;
}

export interface PlanExerciseUpdate {
  plan_exercise_id: string;
  field: 'suggested_weight_kg' | 'reps_max';
  value: number;
}

export interface AdaptDeps {
  now(): Date;
  loadPlan(planId: string): Promise<AdaptPlan | null>;
  listActivePlans(): Promise<AdaptPlan[]>;
  loadWeek(planId: string, week: number): Promise<WeekSnapshot>;
  /** `UPDATE plans SET last_adapted_week = week WHERE id = … AND last_adapted_week < week`; true if claimed. */
  claimWeek(planId: string, week: number): Promise<boolean>;
  setCurrentWeek(planId: string, week: number): Promise<void>;
  applyUpdates(updates: PlanExerciseUpdate[]): Promise<void>;
  appendLog(planId: string, entry: AdaptationLogEntry): Promise<void>;
  /** claude-haiku-5-5, structured output (ai-services §2b). May throw. */
  explain(input: ExplanationInput): Promise<Explanation>;
}

export interface AdaptResult {
  status: number;
  // deno-lint-ignore no-explicit-any -- JSON body: the contract response or { error, code }
  body: any;
}

const fail = (status: number, code: string, error: string): AdaptResult => ({ status, body: { error, code } });

// ---------------------------------------------------------------------------
// User mode
// ---------------------------------------------------------------------------

export async function handleUserMode(
  userId: string,
  req: { plan_id?: unknown; completed_week?: unknown },
  deps: AdaptDeps,
): Promise<AdaptResult> {
  if (typeof req.plan_id !== 'string' || !Number.isInteger(req.completed_week)) {
    return fail(400, 'INVALID_REQUEST', 'plan_id and an integer completed_week are required');
  }
  const week = req.completed_week as number;

  const plan = await deps.loadPlan(req.plan_id);
  if (!plan || plan.user_id !== userId) return fail(404, 'PLAN_NOT_FOUND', 'Plan not found');
  if (!plan.pro) return fail(403, 'PRO_REQUIRED', 'Weekly adaptation is a Pro feature');
  if (week < 1 || week > plan.weeks_total) return fail(400, 'INVALID_REQUEST', `Week ${week} is not in this plan`);

  if (plan.last_adapted_week >= week) return { status: 200, body: stored(plan, week) };

  const snapshot = await deps.loadWeek(plan.id, week);
  const allFinished = snapshot.sessions.length > 0 && snapshot.sessions.every((s) => s.finished);
  if (!allFinished && !weekEnded(plan.start_date, week, plan.timezone, deps.now())) {
    return fail(400, 'WEEK_NOT_ENDED', `Week ${week} is still running and has unfinished sessions`);
  }

  // The claim requires last_adapted_week ≤ current_week (DB CHECK).
  if (plan.current_week < week) {
    await deps.setCurrentWeek(plan.id, week);
    plan.current_week = week;
  }
  const entry = await reviewWeek(plan, week, snapshot, deps);
  if (!entry) return { status: 200, body: stored(await deps.loadPlan(plan.id) ?? plan, week) };
  return { status: 200, body: { ...summaryBody(entry), already_adapted: false } };
}

// ---------------------------------------------------------------------------
// Batch mode (hourly pg_cron, service role)
// ---------------------------------------------------------------------------

export async function handleBatch(deps: AdaptDeps): Promise<AdaptResult> {
  const now = deps.now();
  let processed = 0;
  let adapted = 0;
  let advancedOnly = 0;

  for (const plan of await deps.listActivePlans()) {
    processed += 1;
    const current = Math.min(plan.weeks_total, weekNumberAt(plan.start_date, plan.timezone, now));
    if (current > plan.current_week) {
      await deps.setCurrentWeek(plan.id, current);
      plan.current_week = current;
    }

    let reviewedAny = false;
    for (let week = plan.last_adapted_week + 1; week <= plan.weeks_total; week++) {
      if (!weekEnded(plan.start_date, week, plan.timezone, now)) break;
      if (plan.pro) {
        const entry = await reviewWeek(plan, week, await deps.loadWeek(plan.id, week), deps);
        if (entry) reviewedAny = true;
      } else if (await deps.claimWeek(plan.id, week)) {
        reviewedAny = true; // free plan: the week passes, exercises unchanged
      }
      plan.last_adapted_week = week;
    }
    if (reviewedAny) plan.pro ? adapted++ : advancedOnly++;
  }

  return { status: 200, body: { processed, adapted, advanced_only: advancedOnly } };
}

// ---------------------------------------------------------------------------
// One week
// ---------------------------------------------------------------------------

/** Reviews [week] and applies its changes to week + 1; null if another trigger claimed it first. */
async function reviewWeek(plan: AdaptPlan, week: number, snapshot: WeekSnapshot, deps: AdaptDeps): Promise<AdaptationLogEntry | null> {
  const scheduled = snapshot.sessions.length;
  const completed = snapshot.sessions.filter((s) => s.finished).length;
  const effortBySession = new Map(snapshot.sessions.map((s) => [s.id, s.effort_rating]));

  const weekData: WeekData[] = snapshot.exercises.map((e) => ({
    planExercise: e,
    setLogs: snapshot.setLogs.filter((s) => s.plan_exercise_id === e.id),
    plannedSessionCount: scheduled,
    completedSessionCount: completed,
    sessionEffort: effortBySession.get(e.session_id) ?? null,
  }));
  const events = computeAdaptation(weekData);

  const next = events.length && week < plan.weeks_total ? await deps.loadWeek(plan.id, week + 1) : null;
  const targets = next ? matchNextWeek(snapshot, next) : new Map<string, WeekExercise>();
  const records: AdaptationRecord[] = [];
  for (const e of events) {
    const target = targets.get(e.planExerciseId);
    if (!target) continue; // no matching exercise next week (last week, or a different session layout)
    records.push({
      plan_exercise_id: target.id,
      field_changed: e.field,
      old_value: e.oldValue,
      new_value: e.newValue,
      reason_en: e.reasonEn,
      reason_fr: e.reasonFr,
    });
  }

  if (!(await deps.claimWeek(plan.id, week))) return null;

  let summaryEn = deterministicSummary('en', completed, scheduled, records.length);
  let summaryFr = deterministicSummary('fr', completed, scheduled, records.length);
  if (records.length) {
    try {
      const words = await deps.explain({ week, sessions_scheduled: scheduled, sessions_completed: completed, adaptations: records });
      const byId = new Map(words.reasons.map((r) => [r.plan_exercise_id, r]));
      for (const r of records) {
        const w = byId.get(r.plan_exercise_id);
        if (w?.reason_en?.trim() && w.reason_fr?.trim()) {
          r.reason_en = w.reason_en.trim();
          r.reason_fr = w.reason_fr.trim();
        }
      }
      if (words.summary_en?.trim() && words.summary_fr?.trim()) {
        summaryEn = words.summary_en.trim();
        summaryFr = words.summary_fr.trim();
      }
    } catch {
      // Deterministic reasons and summary stay (contract §2: adaptation never depends on AI).
    }
    await deps.applyUpdates(records.map((r) => ({ plan_exercise_id: r.plan_exercise_id, field: r.field_changed, value: r.new_value })));
  }

  const entry: AdaptationLogEntry = {
    week,
    adapted_at: deps.now().toISOString(),
    sessions_scheduled: scheduled,
    sessions_completed: completed,
    adaptations: records,
    summary_en: summaryEn,
    summary_fr: summaryFr,
  };
  await deps.appendLog(plan.id, entry);
  plan.last_adapted_week = week;
  return entry;
}

/** Maps each plan exercise of [week] to the same slot next week: session position + slug + occurrence. */
function matchNextWeek(week: WeekSnapshot, next: WeekSnapshot): Map<string, WeekExercise> {
  const keyed = (snap: WeekSnapshot) => {
    const order = [...snap.sessions].sort((a, b) => a.day_of_week - b.day_of_week || a.id.localeCompare(b.id));
    const position = new Map(order.map((s, i) => [s.id, i]));
    const seen = new Map<string, number>();
    const out = new Map<string, WeekExercise>();
    for (const e of [...snap.exercises].sort((a, b) => (position.get(a.session_id)! - position.get(b.session_id)!) || a.sort_order - b.sort_order)) {
      const base = `${position.get(e.session_id)}|${e.exercise_slug}`;
      const n = (seen.get(base) ?? 0) + 1;
      seen.set(base, n);
      out.set(`${base}|${n}`, e);
    }
    return out;
  };
  const from = keyed(week);
  const to = keyed(next);
  const result = new Map<string, WeekExercise>();
  for (const [key, e] of from) {
    const target = to.get(key);
    if (target) result.set(e.id, target);
  }
  return result;
}

function deterministicSummary(lang: 'en' | 'fr', completed: number, scheduled: number, changes: number): string {
  if (lang === 'en') {
    const done = `${completed} of ${scheduled} sessions done.`;
    return changes === 0 ? `${done} No changes for next week.` : `${done} ${changes} change${changes > 1 ? 's' : ''} for next week.`;
  }
  const done = `Séances faites : ${completed} sur ${scheduled}.`;
  return changes === 0
    ? `${done} Aucun changement pour la semaine prochaine.`
    : `${done} ${changes} changement${changes > 1 ? 's' : ''} pour la semaine prochaine.`;
}

function summaryBody(entry: AdaptationLogEntry) {
  return {
    week: entry.week,
    adaptations: entry.adaptations,
    sessions_scheduled: entry.sessions_scheduled,
    sessions_completed: entry.sessions_completed,
    summary_en: entry.summary_en,
    summary_fr: entry.summary_fr,
  };
}

/** The stored summary of an already reviewed week (a free-plan week has none: empty summary). */
function stored(plan: AdaptPlan, week: number) {
  const entry = plan.adaptation_log.find((e) => e.week === week);
  if (entry) return { ...summaryBody(entry), already_adapted: true };
  return {
    week,
    adaptations: [],
    sessions_scheduled: 0,
    sessions_completed: 0,
    summary_en: '',
    summary_fr: '',
    already_adapted: true,
  };
}
