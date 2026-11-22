// POST /support-message — contracts/backend-api.md §10 (FR-054). Decisions live in logic.ts.
import { z } from 'npm:zod@4.6.7';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { CACHE_CONTROL, callStructured, COACH_MODEL } from '../_shared/claude.ts';
import { getDb } from '../_shared/db.ts';
import { type AiAnswer, handleSupportMessage, type SupportMessage, type ThreadStatus } from './logic.ts';

const AnswerSchema = z.object({ reply: z.string(), needs_human: z.boolean() });

// Stable system prompt (cache prefix).
const SYSTEM = `You are Tekto's support assistant inside the Tekto strength-training app. Answer questions about the app: accounts and sign-in, subscriptions and the 7-day trial (billing is handled by the App Store or Google Play: refunds are requested there), restoring purchases, plans and the plan library, workouts and logging, the exercise library and videos, form check, friends and the feed, privacy, data export and account deletion (Settings › Privacy).
Rules:
- Reply in the user's language, briefly (at most 120 words), with exact menu paths when useful.
- Never give medical advice; for pain or injury, tell the user to stop and see a health professional, and mention the AI coach for training changes.
- Never invent features, prices or policies. Prices: Pro is $12.99 a month or $79.99 a year, with a 7-day free trial.
- Set needs_human to true when the user asks for a person, reports a bug or a billing problem, is upset, or when you are not sure; then say what you can and that a person will follow up.`;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);
  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');
  const body = await req.json().catch(() => ({})) as { body?: unknown; want_human?: unknown };
  const db = getDb();
  const { data: profile } = await db.from('users').select('language').eq('id', user.id).maybeSingle();
  const language = profile?.language === 'fr' ? 'fr' : 'en';

  const result = await handleSupportMessage(
    { body: body.body, wantHuman: body.want_human === true, language },
    {
      openThread: async () => {
        const { data } = await db.from('support_threads').select('id, status').eq('user_id', user.id)
          .neq('status', 'closed').maybeSingle();
        if (data) return data as { id: string; status: ThreadStatus };
        const { data: created, error } = await db.from('support_threads').insert({ user_id: user.id })
          .select('id, status').single();
        if (error || !created) throw new Error(error?.message ?? 'no thread');
        return created as { id: string; status: ThreadStatus };
      },
      messagesLastHour: async () => {
        const since = new Date(Date.now() - 3600_000).toISOString();
        const { count } = await db.from('support_messages').select('id, support_threads!inner(user_id)', { count: 'exact', head: true })
          .eq('support_threads.user_id', user.id).eq('sender', 'user').gte('created_at', since);
        return count ?? 0;
      },
      history: async (threadId) => {
        const { data } = await db.from('support_messages').select('id, sender, body, created_at').eq('thread_id', threadId)
          .order('created_at', { ascending: false }).limit(12);
        return ((data ?? []) as SupportMessage[]).reverse();
      },
      insert: async (threadId, sender, text) => {
        const { data, error } = await db.from('support_messages').insert({ thread_id: threadId, sender, body: text })
          .select('id, sender, body, created_at').single();
        if (error || !data) throw new Error(error?.message ?? 'insert failed');
        await db.from('support_threads').update({ updated_at: new Date().toISOString() }).eq('id', threadId);
        return data as SupportMessage;
      },
      setStatus: async (threadId, status) => {
        await db.from('support_threads').update({ status }).eq('id', threadId);
      },
      askAi: async (history, lang): Promise<AiAnswer> => {
        const { output } = await callStructured({
          fn: 'support-message',
          model: COACH_MODEL,
          system: [{ type: 'text', text: SYSTEM, cache_control: CACHE_CONTROL }],
          messages: [{
            role: 'user',
            content: `Language: ${lang}\nConversation so far (oldest first):\n` +
              history.map((m) => `${m.sender === 'user' ? 'User' : m.sender === 'agent' ? 'Tekto team' : 'Assistant'}: ${m.body}`).join('\n'),
          }],
          schema: AnswerSchema,
          effort: 'low',
          maxTokens: 1024,
          timeoutMs: 15_000,
        });
        return output;
      },
    },
  );
  if (!result.ok) return errorResponse(result.message, result.status, result.code);
  return jsonResponse({ thread_id: result.thread_id, status: result.status, messages: result.messages }, 201);
});
