// T137 — saving a generated plan without ever leaving the user without an active plan
// (FR-046, FR-003b). The new plan is inserted as `archived` (invisible to the app, which
// reads only the active plan), filled with its sessions, and only then activated by
// activate_plan() (migration 013), which archives the previous plan in the same transaction.
// Any failure before that discards the staged plan; the previous plan stays active.

export interface PersistDeps<T> {
  /** Inserts the plan row with status `archived`; returns its id. */
  insertStagedPlan(): Promise<string>;
  saveSessions(planId: string): Promise<T[]>;
  /** public.activate_plan(planId): archive the user's active plan and activate this one. */
  activate(planId: string): Promise<void>;
  /** Deletes the staged plan (sessions cascade). */
  discard(planId: string): Promise<void>;
}

export async function persistPlan<T>(deps: PersistDeps<T>): Promise<{ planId: string; sessions: T[] }> {
  const planId = await deps.insertStagedPlan();
  try {
    const sessions = await deps.saveSessions(planId);
    await deps.activate(planId);
    return { planId, sessions };
  } catch (err) {
    await deps.discard(planId).catch((e) => console.error(JSON.stringify({ event: 'plan_discard_failed', error: String(e) })));
    throw err;
  }
}
