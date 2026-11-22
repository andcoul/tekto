// support-message decisions (FR-054; contracts/backend-api.md §10). Pure apart from injected I/O.
export const MAX_BODY_CHARS = 2000;
export const MAX_MESSAGES_PER_HOUR = 20;

export type ThreadStatus = 'open' | 'waiting_agent' | 'closed';
export interface SupportMessage {
  id: string;
  sender: 'user' | 'ai' | 'agent';
  body: string;
  created_at: string;
}
/** What the assistant returns: an answer, and whether a person must take over. */
export interface AiAnswer {
  reply: string;
  needs_human: boolean;
}

export interface SupportDeps {
  openThread: () => Promise<{ id: string; status: ThreadStatus }>;
  messagesLastHour: () => Promise<number>;
  history: (threadId: string) => Promise<SupportMessage[]>;
  insert: (threadId: string, sender: 'user' | 'ai', body: string) => Promise<SupportMessage>;
  setStatus: (threadId: string, status: ThreadStatus) => Promise<void>;
  /** Throws when the model is unavailable. */
  askAi: (history: SupportMessage[], language: 'en' | 'fr') => Promise<AiAnswer>;
}

export type SupportResult =
  | { ok: true; thread_id: string; status: ThreadStatus; messages: SupportMessage[] }
  | { ok: false; status: number; code: 'INVALID_BODY' | 'RATE_LIMITED'; message: string };

const HANDOFF = {
  en: 'Thanks — a member of the Tekto team will reply here as soon as possible. You will get a notification.',
  fr: "Merci — un membre de l'équipe Tekto vous répondra ici dès que possible. Vous recevrez une notification.",
};

export async function handleSupportMessage(
  input: { body: unknown; wantHuman: boolean; language: 'en' | 'fr' },
  deps: SupportDeps,
): Promise<SupportResult> {
  const body = typeof input.body === 'string' ? input.body.trim() : '';
  if (!body || body.length > MAX_BODY_CHARS) {
    return { ok: false, status: 400, code: 'INVALID_BODY', message: `Message must be 1–${MAX_BODY_CHARS} characters.` };
  }
  if ((await deps.messagesLastHour()) >= MAX_MESSAGES_PER_HOUR) {
    return { ok: false, status: 429, code: 'RATE_LIMITED', message: 'Too many messages; please wait a little.' };
  }
  const thread = await deps.openThread();
  const out: SupportMessage[] = [await deps.insert(thread.id, 'user', body)];

  // Already with a person: no AI replies until staff close the thread.
  if (thread.status === 'waiting_agent') return { ok: true, thread_id: thread.id, status: thread.status, messages: out };

  let answer: AiAnswer | null = null;
  if (!input.wantHuman) {
    try {
      answer = await deps.askAi(await deps.history(thread.id), input.language);
    } catch {
      answer = null; // the model is down: a person takes over
    }
  }
  if (answer && !answer.needs_human && answer.reply.trim()) {
    out.push(await deps.insert(thread.id, 'ai', answer.reply.trim()));
    return { ok: true, thread_id: thread.id, status: 'open', messages: out };
  }
  const text = answer?.reply.trim() ? `${answer.reply.trim()}\n\n${HANDOFF[input.language]}` : HANDOFF[input.language];
  out.push(await deps.insert(thread.id, 'ai', text));
  await deps.setStatus(thread.id, 'waiting_agent');
  return { ok: true, thread_id: thread.id, status: 'waiting_agent', messages: out };
}
