// T089 — GDPR export covers every user-owned table (FR-037, FR-038, Constitution II).
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { buildExport, EXPORTED_TABLES, NOT_USER_DATA, type ExportDeps } from './export.ts';

/** Tables created by the migrations and still present (minus those dropped later). */
async function liveTables(): Promise<string[]> {
  const dir = new URL('../../migrations/', import.meta.url);
  const created = new Set<string>();
  const files = [...Deno.readDirSync(dir)].map((f) => f.name).filter((n) => n.endsWith('.sql')).sort();
  for (const name of files) {
    const sql = await Deno.readTextFile(new URL(name, dir));
    for (const m of sql.matchAll(/CREATE TABLE (?:IF NOT EXISTS )?public\.(\w+)/g)) created.add(m[1]);
    for (const m of sql.matchAll(/DROP TABLE (?:IF EXISTS )?public\.(\w+)/g)) {
      // A table dropped and re-created in the same file stays (coach_response_cache in 005).
      const recreated = new RegExp(`DROP TABLE (?:IF EXISTS )?public\\.${m[1]}[\\s\\S]*CREATE TABLE (?:IF NOT EXISTS )?public\\.${m[1]}\\b`).test(sql);
      if (!recreated) created.delete(m[1]);
    }
  }
  return [...created].sort();
}

Deno.test('every table in the schema is either exported or declared as not user data', async () => {
  const known = new Set<string>([...EXPORTED_TABLES, ...NOT_USER_DATA]);
  const missing = (await liveTables()).filter((t) => !known.has(t));
  assertEquals(missing, [], 'add new user-owned tables to EXPORTED_TABLES (or NOT_USER_DATA)');
});

Deno.test('nested tables are fetched through their parents, and only the user rows', async () => {
  const db: Record<string, Record<string, unknown>[]> = {
    users: [{ id: 'u1', consent_at: '2026-11-01T10:00:00Z', consent_version: '2026-11-v1' }, { id: 'u2' }],
    plans: [{ id: 'p1', user_id: 'u1' }, { id: 'p2', user_id: 'u2' }],
    sessions: [{ id: 's1', plan_id: 'p1' }, { id: 's2', plan_id: 'p2' }],
    plan_exercises: [{ id: 'pe1', session_id: 's1' }, { id: 'pe2', session_id: 's2' }],
    workout_logs: [{ id: 'wl1', user_id: 'u1' }],
    set_logs: [{ id: 'sl1', workout_log_id: 'wl1' }, { id: 'sl2', workout_log_id: 'other' }],
    personal_records: [{ id: 'pr1', user_id: 'u1' }],
    coach_conversations: [{ id: 'c1', user_id: 'u1' }],
    coach_messages: [{ id: 'm1', conversation_id: 'c1', content: 'hi' }, { id: 'm2', conversation_id: 'c9' }],
    coach_quota_usage: [{ user_id: 'u1', iso_week: '2026-W46' }],
    form_check_sessions: [{ id: 'f1', user_id: 'u1' }],
    subscriptions: [{ id: 'sub1', user_id: 'u1' }],
    body_weight_entries: [{ id: 'bw1', user_id: 'u1' }],
  };
  const deps: ExportDeps = {
    select: (table, column, values) =>
      Promise.resolve((db[table] ?? []).filter((r) => values.includes(String(r[column])))),
  };
  const out = await buildExport('u1', deps);
  assertEquals(Object.keys(out).sort(), [...EXPORTED_TABLES].sort());
  assertEquals(out.users, [db.users[0]], 'consent fields are part of the users row');
  assertEquals(out.sessions.map((r) => r.id), ['s1']);
  assertEquals(out.plan_exercises.map((r) => r.id), ['pe1']);
  assertEquals(out.set_logs.map((r) => r.id), ['sl1']);
  assertEquals(out.coach_messages.map((r) => r.id), ['m1']);
  for (const t of ['workout_logs', 'personal_records', 'coach_quota_usage', 'form_check_sessions', 'subscriptions', 'body_weight_entries'] as const) {
    assertEquals(out[t].length, 1, t);
  }
});

Deno.test('a user with no plans or logs gets empty child tables, without querying with an empty list', async () => {
  const queried: string[] = [];
  const deps: ExportDeps = {
    select: (table, _column, values) => {
      queried.push(table);
      assert(values.length > 0, `${table} queried with an empty id list`);
      return Promise.resolve(table === 'users' ? [{ id: 'u1' }] : []);
    },
  };
  const out = await buildExport('u1', deps);
  assertEquals(out.sessions, []);
  assertEquals(out.set_logs, []);
  assertEquals(out.coach_messages, []);
  assert(!queried.includes('sessions'));
});
