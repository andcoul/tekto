// T090 — account deletion (FR-037, Constitution II; contracts/backend-api.md §8).
// Order: RevenueCat customer, export files, then auth.users (ON DELETE CASCADE removes every
// user-owned row). Only the last step can fail the request: the account must really be gone
// before the app wipes its local database.

export interface DeleteDeps {
  deleteRevenueCatCustomer(userId: string): Promise<void>;
  /** Every file under exports/<user_id>/ in the private exports bucket. */
  deleteExportFiles(userId: string): Promise<void>;
  deleteAuthUser(userId: string): Promise<void>;
}

export interface DeleteResult {
  status: number;
  // deno-lint-ignore no-explicit-any -- JSON body
  body: any;
}

export async function handleDelete(userId: string, body: unknown, deps: DeleteDeps): Promise<DeleteResult> {
  if (!body || typeof body !== 'object' || (body as { confirm?: unknown }).confirm !== true) {
    return { status: 400, body: { error: 'Explicit { "confirm": true } body required', code: 'CONFIRMATION_REQUIRED' } };
  }

  for (const [step, run] of [
    ['revenuecat', deps.deleteRevenueCatCustomer],
    ['exports', deps.deleteExportFiles],
  ] as const) {
    try {
      await run(userId);
    } catch (err) {
      // Logged without user data; the account deletion below still happens.
      console.warn(JSON.stringify({ event: 'delete_account_step_failed', step, error: String(err) }));
    }
  }

  try {
    await deps.deleteAuthUser(userId);
  } catch (err) {
    console.error(JSON.stringify({ event: 'delete_account_failed', error: String(err) }));
    return { status: 500, body: { error: 'Failed to delete account', code: 'DELETE_FAILED' } };
  }
  return { status: 200, body: { deleted: true } };
}
