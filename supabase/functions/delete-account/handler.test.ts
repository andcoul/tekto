// T090 — account deletion (FR-037, Constitution II; contracts/backend-api.md §8).
import { assertEquals } from 'jsr:@std/assert@1';
import { type DeleteDeps, handleDelete } from './handler.ts';

function setup(opts: { revenueCatFails?: boolean; storageFails?: boolean; authFails?: boolean } = {}) {
  const calls: string[] = [];
  const deps: DeleteDeps = {
    deleteRevenueCatCustomer: () => {
      calls.push('revenuecat');
      return opts.revenueCatFails ? Promise.reject(new Error('rc down')) : Promise.resolve();
    },
    deleteExportFiles: () => {
      calls.push('exports');
      return opts.storageFails ? Promise.reject(new Error('storage down')) : Promise.resolve();
    },
    deleteAuthUser: () => {
      calls.push('auth');
      return opts.authFails ? Promise.reject(new Error('auth down')) : Promise.resolve();
    },
  };
  return { deps, calls };
}

Deno.test('requires { "confirm": true } and deletes nothing otherwise', async () => {
  for (const body of [{}, { confirm: false }, { confirm: 'yes' }, null]) {
    const { deps, calls } = setup();
    const res = await handleDelete('u1', body, deps);
    assertEquals([res.status, res.body.code], [400, 'CONFIRMATION_REQUIRED'], JSON.stringify(body));
    assertEquals(calls, []);
  }
});

Deno.test('deletes the RevenueCat customer, the export files, then the account (cascade)', async () => {
  const { deps, calls } = setup();
  const res = await handleDelete('u1', { confirm: true }, deps);
  assertEquals([res.status, res.body], [200, { deleted: true }]);
  assertEquals(calls, ['revenuecat', 'exports', 'auth']);
});

Deno.test('RevenueCat or storage failures do not block deletion of the account', async () => {
  const { deps, calls } = setup({ revenueCatFails: true, storageFails: true });
  const res = await handleDelete('u1', { confirm: true }, deps);
  assertEquals(res.status, 200);
  assertEquals(calls, ['revenuecat', 'exports', 'auth']);
});

Deno.test('if the account itself cannot be deleted the request fails (the app keeps its data)', async () => {
  const { deps } = setup({ authFails: true });
  const res = await handleDelete('u1', { confirm: true }, deps);
  assertEquals([res.status, res.body.code], [500, 'DELETE_FAILED']);
});
