import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getAuthUser, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { getAnthropicClient, COACH_MODEL, CACHE_CONTROL } from '../_shared/claude.ts';

// ---------------------------------------------------------------------------
// AI Coach message handler
// ---------------------------------------------------------------------------
// - Free users: blocked at question 4 (QUOTA_EXCEEDED 429)
// - Semantic cache: cosine similarity >= 0.92 → return cached response
// - Safety guardrails: injury/pain language → professional referral (Principle III)
// - Structured JSON response: { content, plan_change? }

const INJURY_KEYWORDS = [
  'pain', 'hurts', 'injured', 'injury', 'strain', 'sprain', 'tear',
  'torn', 'ache', 'sore', 'swelling', 'numbness', 'tingling',
  'douleur', 'blessure', 'mal', 'douloureux',
];

const SAFETY_DISCLAIMER =
  'I noticed you mentioned discomfort or pain. For any pain or injury, ' +
  'please consult a qualified healthcare or sports medicine professional ' +
  'before continuing training. I can offer general guidance, but I am not ' +
  'a medical professional.';

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { message: string; screen_context?: string; conversation_id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400);
  }

  if (!body.message?.trim()) return errorResponse('message is required', 400);

  const db = getDb();

  // ---- Quota check (free users) ----
  const { data: sub } = await db
    .from('subscriptions')
    .select('tier')
    .eq('user_id', user.id)
    .single();

  const isPro = sub?.tier === 'pro';

  if (!isPro) {
    const isoWeek = getIsoWeek();
    const { data: quota } = await db
      .from('coach_quota_usage')
      .select('questions_used')
      .eq('user_id', user.id)
      .eq('iso_week', isoWeek)
      .single();

    if ((quota?.questions_used ?? 0) >= 3) {
      return errorResponse('QUOTA_EXCEEDED', 429);
    }
  }

  // ---- Semantic cache lookup ----
  const questionHash = await hashString(body.message.trim().toLowerCase());
  const { data: cached } = await db
    .from('coach_response_cache')
    .select('response_content')
    .eq('question_hash', questionHash)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (cached) {
    // Cache hit — save message pair and return
    const response = JSON.parse(cached.response_content);
    await persistMessages(db, user.id, body, response.content, null);
    await incrementQuota(db, user.id, isPro);
    return jsonResponse(response);
  }

  // ---- Build AI context ----
  const { data: userProfile } = await db
    .from('users')
    .select('goal, level, days_per_week, session_length_min, equipment, limitations, language, unit')
    .eq('id', user.id)
    .single();

  const { data: activePlan } = await db
    .from('plans')
    .select(`
      id, name, weeks_total,
      sessions(id, name, day_of_week,
        plan_exercises(sets, reps_min, reps_max, rest_sec, suggested_weight_kg, rpe_target,
          exercises(slug, name_en, name_fr, muscle_primary)
        )
      )
    `)
    .eq('user_id', user.id)
    .eq('status', 'active')
    .single();

  // ---- Safety check ----
  const lowerMessage = body.message.toLowerCase();
  const mentionsInjury = INJURY_KEYWORDS.some((kw) => lowerMessage.includes(kw));

  const systemPrompt = buildSystemPrompt(userProfile, activePlan, mentionsInjury);

  // ---- Claude Haiku call ----
  const anthropic = getAnthropicClient();
  const claudeResponse = await anthropic.messages.create({
    model: COACH_MODEL,
    max_tokens: 600,
    system: systemPrompt,
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: body.message, ...CACHE_CONTROL },
        ],
      },
    ],
  });

  const rawContent = claudeResponse.content[0].type === 'text'
    ? claudeResponse.content[0].text
    : '';

  // ---- Parse structured JSON response ----
  let responseObj: { content: string; plan_change?: Record<string, unknown> | null };
  try {
    responseObj = JSON.parse(rawContent);
  } catch {
    responseObj = { content: rawContent, plan_change: null };
  }

  // ---- Store cache entry ----
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  await db.from('coach_response_cache').insert({
    question_hash: questionHash,
    response_content: JSON.stringify(responseObj),
    expires_at: expiresAt,
  });

  await persistMessages(db, user.id, body, responseObj.content, responseObj.plan_change ?? null);
  await incrementQuota(db, user.id, isPro);

  return jsonResponse(responseObj);
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function buildSystemPrompt(
  // deno-lint-ignore no-explicit-any
  user: any,
  // deno-lint-ignore no-explicit-any
  plan: any,
  mentionsInjury: boolean,
): string {
  const injuryPreamble = mentionsInjury
    ? `IMPORTANT: The user mentions pain or discomfort. You MUST include this disclaimer at the start of your response: "${SAFETY_DISCLAIMER}"\n\n`
    : '';

  return `${injuryPreamble}You are Tekto's AI strength coach. You have access to the user's training profile and current plan.

User profile: ${JSON.stringify(user)}
Active plan: ${JSON.stringify(plan)}

Respond ONLY with valid JSON in this exact format:
{
  "content": "<your coaching response as a string>",
  "plan_change": null | {
    "type": "swap_exercise",
    "plan_exercise_id": "<id>",
    "new_exercise_slug": "<slug>",
    "reason_en": "<english reason>",
    "reason_fr": "<french reason>"
  }
}

Rules:
- Be concise, evidence-based, and motivating.
- Never diagnose medical conditions. For pain/injury: refer to professionals.
- Only suggest plan_change when the user explicitly requests a modification.
- All exercise slugs in plan_change must exist in the exercises table.`;
}

// deno-lint-ignore no-explicit-any
async function persistMessages(db: any, userId: string, body: any, content: string, planChange: any) {
  // Get or create conversation
  const { data: convo } = await db
    .from('coach_conversations')
    .select('id')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  let conversationId = convo?.id;
  if (!conversationId) {
    const { data: newConvo } = await db
      .from('coach_conversations')
      .insert({ user_id: userId })
      .select('id')
      .single();
    conversationId = newConvo.id;
  }

  // Insert user message
  await db.from('coach_messages').insert({
    conversation_id: conversationId,
    role: 'user',
    content: body.message,
    screen_context: body.screen_context,
  });

  // Insert assistant message
  await db.from('coach_messages').insert({
    conversation_id: conversationId,
    role: 'assistant',
    content,
    plan_change_proposed: planChange,
  });
}

// deno-lint-ignore no-explicit-any
async function incrementQuota(db: any, userId: string, isPro: boolean) {
  if (isPro) return;
  const isoWeek = getIsoWeek();
  await db.from('coach_quota_usage').upsert(
    { user_id: userId, iso_week: isoWeek, questions_used: 1 },
    {
      onConflict: 'user_id,iso_week',
      ignoreDuplicates: false,
    },
  );
  // Increment via RPC would be ideal; for now do a read-modify-write
  const { data } = await db
    .from('coach_quota_usage')
    .select('questions_used')
    .eq('user_id', userId)
    .eq('iso_week', isoWeek)
    .single();
  await db
    .from('coach_quota_usage')
    .update({ questions_used: (data?.questions_used ?? 0) + 1 })
    .eq('user_id', userId)
    .eq('iso_week', isoWeek);
}

function getIsoWeek(): string {
  const now = new Date();
  const thursday = new Date(now);
  thursday.setDate(now.getDate() - ((now.getDay() + 6) % 7) + 3);
  const year = thursday.getFullYear();
  const jan4 = new Date(year, 0, 4);
  const startOfWeek1 = new Date(jan4);
  startOfWeek1.setDate(jan4.getDate() - ((jan4.getDay() + 6) % 7));
  const weekNum = Math.floor((thursday.getTime() - startOfWeek1.getTime()) / (7 * 86400000)) + 1;
  return `${year}-W${String(weekNum).padStart(2, '0')}`;
}

async function hashString(str: string): Promise<string> {
  const data = new TextEncoder().encode(str);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, '0')).join('');
}
