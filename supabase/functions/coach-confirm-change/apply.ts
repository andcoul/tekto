// T074 — apply or reject a coach-proposed plan change (FR-018; Constitution IV;
// contracts/backend-api.md §3). Pure over injected ports; tested by apply.test.ts (T071).
// Nothing changes until the user confirms; every change type is checked against the
// user's active plan, and swaps follow the same rules as a user swap (swap-exercise).
import { WORK_SEC_PER_SET } from '../_shared/plan-draft.ts';
import type { CoachPlanChange, CoachPlanChangeType } from '../_shared/types.ts';
import { handleSwap, type SwapDeps } from '../swap-exercise/handler.ts';

export interface PendingMessage {
  id: string;
  /** Owner of the conversation the message belongs to. */
  user_id: string;
  plan_change_proposed: CoachPlanChange | null;
  plan_change_applied: boolean;
  plan_change_rejected_at: string | null;
}

/** One plan exercise of the user's active plan, with its session's week. */
export interface PlanExerciseRow {
  id: string;
  session_id: string;
  week_number: number;
  exercise_slug: string;
  sort_order: number;
  sets: number;
  reps_min: number;
  reps_max: number;
  rest_sec: number;
  suggested_weight_kg: number | null;
}

export type PlanExercisePatch = Partial<Pick<PlanExerciseRow, 'sets' | 'reps_min' | 'reps_max' | 'suggested_weight_kg'>>;

export interface ConfirmDeps {
  now(): Date;
  loadMessage(id: string): Promise<PendingMessage | null>;
  /** Every plan exercise of the user's active plan (empty when there is none). */
  loadActivePlanExercises(userId: string): Promise<PlanExerciseRow[]>;
  updatePlanExercise(id: string, patch: PlanExercisePatch): Promise<void>;
  deletePlanExercises(ids: string[]): Promise<void>;
  updateSessionEstimate(sessionId: string, minutes: number): Promise<void>;
  markApplied(messageId: string): Promise<void>;
  markRejected(messageId: string, at: Date): Promise<void>;
  swap: SwapDeps;
}

export interface ConfirmRequest {
  message_id?: string;
  confirmed?: boolean;
}

export interface ConfirmResult {
  status: number;
  // deno-lint-ignore no-explicit-any -- JSON body: the contract response or { error, code }
  body: any;
}

const fail = (status: number, code: string, error: string): ConfirmResult => ({ status, body: { error, code } });

/** Contract §3: sessions keep at least 3 exercises after shortening. */
export const MIN_EXERCISES_AFTER_SHORTEN = 3;
export const DELOAD_SET_FACTOR = 0.6; // sets −40 %
export const DELOAD_WEIGHT_FACTOR = 0.9; // weight −10 %
const WEIGHT_STEP_KG = 0.5;

export function estimateMinutes(rows: Pick<PlanExerciseRow, 'sets' | 'rest_sec'>[]): number {
  return Math.ceil(rows.reduce((sum, r) => sum + r.sets * (WORK_SEC_PER_SET + r.rest_sec), 0) / 60);
}

function out(r: PlanExerciseRow) {
  return {
    plan_exercise_id: r.id,
    session_id: r.session_id,
    exercise_slug: r.exercise_slug,
    sets: r.sets,
    reps_min: r.reps_min,
    reps_max: r.reps_max,
    suggested_weight_kg: r.suggested_weight_kg,
  };
}

const ok = (type: CoachPlanChangeType, rows: PlanExerciseRow[], extra: Record<string, unknown> = {}): ConfirmResult => ({
  status: 200,
  body: { applied: true, change_type: type, updated_plan_exercises: rows.map(out), ...extra },
});

export async function handleConfirm(userId: string, req: ConfirmRequest, deps: ConfirmDeps): Promise<ConfirmResult> {
  if (!req.message_id || typeof req.confirmed !== 'boolean') {
    return fail(400, 'INVALID_REQUEST', 'message_id and confirmed are required');
  }

  const message = await deps.loadMessage(req.message_id);
  if (!message || message.user_id !== userId) return fail(404, 'MESSAGE_NOT_FOUND', 'Message not found');
  const change = message.plan_change_proposed;
  if (!change || message.plan_change_applied || message.plan_change_rejected_at) {
    return fail(400, 'NO_PENDING_CHANGE', 'No pending plan change on this message');
  }

  if (!req.confirmed) {
    await deps.markRejected(message.id, deps.now());
    return { status: 200, body: { applied: false } };
  }

  const result = await apply(userId, change, deps);
  if (result.status === 200) await deps.markApplied(message.id);
  return result;
}

async function apply(userId: string, change: CoachPlanChange, deps: ConfirmDeps): Promise<ConfirmResult> {
  switch (change.type) {
    case 'exercise_swap':
      return swap(userId, change, deps);
    case 'session_shorten':
      return shorten(userId, change, deps);
    case 'deload':
      return deload(userId, change, deps);
    case 'weight_adjustment':
      return adjustWeight(userId, change, deps);
    default:
      return fail(400, 'INVALID_CHANGE', `Unsupported change type: ${(change as { type: string }).type}`);
  }
}

async function swap(userId: string, change: CoachPlanChange, deps: ConfirmDeps): Promise<ConfirmResult> {
  if (!change.plan_exercise_id || !change.new_exercise_slug) {
    return fail(400, 'INVALID_CHANGE', 'exercise_swap needs plan_exercise_id and new_exercise_slug');
  }
  // Same rules as a user swap: Video Gate, equipment, limitations, same primary muscle.
  const res = await handleSwap(
    userId,
    { plan_exercise_id: change.plan_exercise_id, new_exercise_slug: change.new_exercise_slug },
    deps.swap,
  );
  if (res.status !== 200) {
    const code = res.body.code === 'PLAN_EXERCISE_NOT_FOUND' || res.body.code === 'FORBIDDEN' || res.body.code === 'PLAN_NOT_ACTIVE'
      ? 'PLAN_TARGET_NOT_FOUND'
      : res.body.code;
    return fail(code === 'PLAN_TARGET_NOT_FOUND' ? 404 : res.status, code, res.body.error);
  }
  const rows = await deps.loadActivePlanExercises(userId);
  return ok('exercise_swap', rows.filter((r) => r.id === change.plan_exercise_id));
}

async function shorten(userId: string, change: CoachPlanChange, deps: ConfirmDeps): Promise<ConfirmResult> {
  const target = change.target_duration_min;
  if (!change.session_id || !target || target <= 0) {
    return fail(400, 'INVALID_CHANGE', 'session_shorten needs session_id and a positive target_duration_min');
  }
  const rows = (await deps.loadActivePlanExercises(userId))
    .filter((r) => r.session_id === change.session_id)
    .sort((a, b) => a.sort_order - b.sort_order);
  if (rows.length === 0) return fail(404, 'PLAN_TARGET_NOT_FOUND', 'Session is not in your active plan');

  const kept = [...rows];
  const removed: string[] = [];
  while (kept.length > MIN_EXERCISES_AFTER_SHORTEN && estimateMinutes(kept) > target) {
    removed.push(kept.pop()!.id); // trailing exercises are accessories (templates order them last)
  }
  if (removed.length) await deps.deletePlanExercises(removed);
  await deps.updateSessionEstimate(change.session_id, estimateMinutes(kept));
  return ok('session_shorten', kept, { removed_plan_exercise_ids: removed });
}

async function deload(userId: string, change: CoachPlanChange, deps: ConfirmDeps): Promise<ConfirmResult> {
  if (!change.week_number) return fail(400, 'INVALID_CHANGE', 'deload needs week_number');
  const rows = (await deps.loadActivePlanExercises(userId)).filter((r) => r.week_number === change.week_number);
  if (rows.length === 0) return fail(404, 'PLAN_TARGET_NOT_FOUND', `Week ${change.week_number} is not in your active plan`);

  const updated: PlanExerciseRow[] = [];
  for (const r of rows) {
    const patch: PlanExercisePatch = {
      sets: Math.max(1, Math.round(r.sets * DELOAD_SET_FACTOR)),
      suggested_weight_kg: r.suggested_weight_kg === null
        ? null
        : Math.floor((r.suggested_weight_kg * DELOAD_WEIGHT_FACTOR) / WEIGHT_STEP_KG) * WEIGHT_STEP_KG,
    };
    await deps.updatePlanExercise(r.id, patch);
    updated.push({ ...r, ...patch });
  }
  return ok('deload', updated);
}

async function adjustWeight(userId: string, change: CoachPlanChange, deps: ConfirmDeps): Promise<ConfirmResult> {
  if (!change.plan_exercise_id) return fail(400, 'INVALID_CHANGE', 'weight_adjustment needs plan_exercise_id');
  const row = (await deps.loadActivePlanExercises(userId)).find((r) => r.id === change.plan_exercise_id);
  if (!row) return fail(404, 'PLAN_TARGET_NOT_FOUND', 'Plan exercise is not in your active plan');

  const patch: PlanExercisePatch = {};
  if (change.new_weight_kg !== null) patch.suggested_weight_kg = change.new_weight_kg;
  if (change.new_reps_min !== null) patch.reps_min = change.new_reps_min;
  if (change.new_reps_max !== null) patch.reps_max = change.new_reps_max;
  const next = { ...row, ...patch };
  if (
    Object.keys(patch).length === 0 ||
    (next.suggested_weight_kg !== null && next.suggested_weight_kg < 0) ||
    next.reps_min < 1 ||
    next.reps_min > next.reps_max
  ) {
    return fail(400, 'INVALID_CHANGE', 'weight_adjustment must set a weight ≥ 0 and 1 ≤ reps_min ≤ reps_max');
  }
  await deps.updatePlanExercise(row.id, patch);
  return ok('weight_adjustment', [next]);
}
