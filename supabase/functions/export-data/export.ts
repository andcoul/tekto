// T089 — GDPR export: every user-owned table in one JSON document (FR-037, FR-038,
// Constitution II; contracts/backend-api.md §7). Pure over one generic select port.
// export.test.ts checks this list against the migrations, so a new table cannot be forgotten.

/** Rows of [table] whose [column] is one of [values]. */
export interface ExportDeps {
  select(table: string, column: string, values: string[]): Promise<Record<string, unknown>[]>;
}

/** Tables owned by a user, directly (user_id) or through a parent row. */
export const EXPORTED_TABLES = [
  'users',
  'plans',
  'sessions',
  'plan_exercises',
  'workout_logs',
  'set_logs',
  'personal_records',
  'coach_conversations',
  'coach_messages',
  'coach_quota_usage',
  'form_check_sessions',
  'subscriptions',
  'body_weight_entries',
  'friendships',
  'workout_reactions',
  'support_threads',
  'support_messages',
] as const;

/** Shared content and caches: nothing in them belongs to one user. */
export const NOT_USER_DATA = ['exercises', 'plan_templates', 'coach_response_cache'] as const;

export type UserExport = Record<(typeof EXPORTED_TABLES)[number], Record<string, unknown>[]>;

const DIRECT_BY_USER_ID = [
  'plans',
  'workout_logs',
  'personal_records',
  'coach_conversations',
  'coach_quota_usage',
  'form_check_sessions',
  'subscriptions',
  'body_weight_entries',
  'workout_reactions', // reactions the user gave
  'support_threads',
] as const;

export async function buildExport(userId: string, deps: ExportDeps): Promise<UserExport> {
  const children = async (table: string, column: string, parents: Record<string, unknown>[]) => {
    const ids = parents.map((r) => String(r.id));
    return ids.length ? deps.select(table, column, ids) : [];
  };

  const direct = Object.fromEntries(
    await Promise.all(DIRECT_BY_USER_ID.map(async (t) => [t, await deps.select(t, 'user_id', [userId])] as const)),
  ) as Record<(typeof DIRECT_BY_USER_ID)[number], Record<string, unknown>[]>;

  const users = await deps.select('users', 'id', [userId]); // includes consent_at / consent_version
  const sessions = await children('sessions', 'plan_id', direct.plans);
  const planExercises = await children('plan_exercises', 'session_id', sessions);
  const setLogs = await children('set_logs', 'workout_log_id', direct.workout_logs);
  const coachMessages = await children('coach_messages', 'conversation_id', direct.coach_conversations);
  const supportMessages = await children('support_messages', 'thread_id', direct.support_threads);
  // Friendships where the user is either side (FR-049).
  const friendships = [
    ...(await deps.select('friendships', 'requester_id', [userId])),
    ...(await deps.select('friendships', 'addressee_id', [userId])),
  ];

  return {
    users,
    ...direct,
    sessions,
    plan_exercises: planExercises,
    set_logs: setLogs,
    coach_messages: coachMessages,
    support_messages: supportMessages,
    friendships,
  };
}
