// T137 — a regenerated plan replaces the active one only once it is fully saved (FR-046,
// FR-003b: never leave the user without a valid plan).
import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { persistPlan, type PersistDeps } from './persist.ts';

function setup(fail: { insert?: boolean; sessions?: boolean; activate?: boolean } = {}) {
  const log: string[] = [];
  const deps: PersistDeps<string> = {
    insertStagedPlan: () => {
      log.push('insert');
      return fail.insert ? Promise.reject(new Error('insert failed')) : Promise.resolve('new-plan');
    },
    saveSessions: (id) => {
      log.push(`sessions:${id}`);
      return fail.sessions ? Promise.reject(new Error('sessions failed')) : Promise.resolve(['s1']);
    },
    activate: (id) => {
      log.push(`activate:${id}`);
      return fail.activate ? Promise.reject(new Error('activate failed')) : Promise.resolve();
    },
    discard: (id) => {
      log.push(`discard:${id}`);
      return Promise.resolve();
    },
  };
  return { deps, log };
}

Deno.test('the new plan is staged, filled, then activated (the old one is archived only at that point)', async () => {
  const { deps, log } = setup();
  assertEquals(await persistPlan(deps), { planId: 'new-plan', sessions: ['s1'] });
  assertEquals(log, ['insert', 'sessions:new-plan', 'activate:new-plan']);
});

Deno.test('if saving sessions fails, the staged plan is discarded and the old plan stays active', async () => {
  const { deps, log } = setup({ sessions: true });
  await assertRejects(() => persistPlan(deps), Error, 'sessions failed');
  assertEquals(log, ['insert', 'sessions:new-plan', 'discard:new-plan']);
});

Deno.test('if activation fails, the staged plan is discarded', async () => {
  const { deps, log } = setup({ activate: true });
  await assertRejects(() => persistPlan(deps), Error, 'activate failed');
  assertEquals(log.at(-1), 'discard:new-plan');
});

Deno.test('if the plan row cannot be inserted, nothing else happens', async () => {
  const { deps, log } = setup({ insert: true });
  await assertRejects(() => persistPlan(deps), Error, 'insert failed');
  assertEquals(log, ['insert']);
});
