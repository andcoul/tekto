// FR-054 — support chat: instant AI answer, hand-off to a person.
import { assertEquals } from 'jsr:@std/assert@1';
import { type AiAnswer, handleSupportMessage, MAX_MESSAGES_PER_HOUR, type SupportDeps, type ThreadStatus } from './logic.ts';

function deps(o: { status?: ThreadStatus; ai?: AiAnswer | Error; sent?: number } = {}) {
  const rows: Array<{ sender: string; body: string }> = [];
  let status: ThreadStatus = o.status ?? 'open';
  let aiCalls = 0;
  const d: SupportDeps = {
    openThread: () => Promise.resolve({ id: 't1', status }),
    messagesLastHour: () => Promise.resolve(o.sent ?? 0),
    history: () => Promise.resolve([]),
    insert: (_t, sender, body) => {
      rows.push({ sender, body });
      return Promise.resolve({ id: `m${rows.length}`, sender, body, created_at: '2026-11-21T10:00:00Z' });
    },
    setStatus: (_t, s) => Promise.resolve(void (status = s)),
    askAi: () => {
      aiCalls++;
      const a = o.ai ?? { reply: 'Go to Settings › Subscription › Restore purchases.', needs_human: false };
      return a instanceof Error ? Promise.reject(a) : Promise.resolve(a);
    },
  };
  return { d, rows, status: () => status, aiCalls: () => aiCalls };
}
const msg = (body: unknown, wantHuman = false) => ({ body, wantHuman, language: 'en' as const });

Deno.test('the assistant answers instantly and the thread stays open', async () => {
  const t = deps();
  const r = await handleSupportMessage(msg('How do I restore my purchase?'), t.d);
  assertEquals(r.ok && r.messages.map((m) => m.sender), ['user', 'ai']);
  assertEquals(t.status(), 'open');
});

Deno.test('asking for a person hands over without calling the AI', async () => {
  const t = deps();
  const r = await handleSupportMessage(msg('I want to talk to someone', true), t.d);
  assertEquals([r.ok && r.status, t.aiCalls(), t.status()], ['waiting_agent', 0, 'waiting_agent']);
  assertEquals(t.rows[1].body.includes('member of the Tekto team'), true);
});

Deno.test('the assistant hands over when it cannot help, keeping its partial answer', async () => {
  const t = deps({ ai: { reply: 'I cannot see payment details.', needs_human: true } });
  const r = await handleSupportMessage(msg('I was charged twice'), t.d);
  assertEquals(r.ok && r.status, 'waiting_agent');
  assertEquals(t.rows[1].body.startsWith('I cannot see payment details.'), true);
});

Deno.test('when the model is down a person takes over', async () => {
  const t = deps({ ai: new Error('down') });
  const r = await handleSupportMessage(msg('Help'), t.d);
  assertEquals(r.ok && r.status, 'waiting_agent');
});

Deno.test('while waiting for a person the AI stays quiet', async () => {
  const t = deps({ status: 'waiting_agent' });
  const r = await handleSupportMessage(msg('Any news?'), t.d);
  assertEquals([r.ok && r.messages.length, t.aiCalls()], [1, 0]);
});

Deno.test('empty, too long and too many messages are refused', async () => {
  for (const body of ['', '   ', 42, 'x'.repeat(2001)]) {
    const r = await handleSupportMessage(msg(body), deps().d);
    assertEquals(!r.ok && r.code, 'INVALID_BODY');
  }
  const r = await handleSupportMessage(msg('hi'), deps({ sent: MAX_MESSAGES_PER_HOUR }).d);
  assertEquals(!r.ok && [r.status, r.code], [429, 'RATE_LIMITED']);
});
