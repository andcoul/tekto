import { requireAuth, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { getAnthropicClient, PLAN_MODEL, CACHE_CONTROL } from '../_shared/claude.ts';
import { validatePlan } from '../_shared/plan-validator.ts';
import type { User, Plan, Session, PlanExercise } from '../_shared/types.ts';

const MAX_RETRIES = 2;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  let userId: string;
  try {
    userId = await requireAuth(req);
  } catch (e: any) {
    return errorResponse(e.message, e.statusCode ?? 401, 'UNAUTHORIZED');
  }

  const db = getDb();

  // 1. Reject if user already has an active plan
  const { data: existingPlan } = await db
    .from('plans')
    .select('id')
    .eq('user_id', userId)
    .eq('status', 'active')
    .maybeSingle();

  if (existingPlan) {
    return errorResponse('User already has an active plan.', 409, 'ACTIVE_PLAN_EXISTS');
  }

  // 2. Fetch user profile
  const { data: user, error: userError } = await db
    .from('users')
    .select('*')
    .eq('id', userId)
    .maybeSingle();

  if (userError || !user) {
    return errorResponse(
      'User profile not found. Complete onboarding first.',
      422,
      'PROFILE_INCOMPLETE',
    );
  }

  // 3. Check subscription tier
  const { data: sub } = await db
    .from('subscriptions')
    .select('tier, is_trial, trial_ends_at, current_period_ends_at')
    .eq('user_id', userId)
    .maybeSingle();

  const isPro = isProSubscription(sub);

  // 4a. Free tier — serve best-matching starter template
  if (!isPro) {
    return await serveFreeTemplate(db, user, userId);
  }

  // 4b. Pro tier — generate via Claude with rule-checker
  return await generateWithAI(db, user, userId);
});

async function serveFreeTemplate(db: any, user: User, userId: string): Promise<Response> {
  const templateName = selectTemplate(user);
  let template: any;

  try {
    // Templates are stored in the Edge Function bundle (Deno.readTextFile)
    const raw = await Deno.readTextFile(`./templates/${templateName}.json`);
    template = JSON.parse(raw);
  } catch {
    return errorResponse('Starter template unavailable. Please try again.', 500, 'AI_UNAVAILABLE');
  }

  // Assign IDs and user_id to the template plan
  const planId = crypto.randomUUID();
  const now = new Date().toISOString();

  const plan = {
    id: planId,
    user_id: userId,
    name: template.name,
    status: 'active',
    weeks_total: template.weeks_total,
    current_week: 1,
    generated_by: `template:${templateName}`,
    rationale_en: template.rationale_en,
    rationale_fr: template.rationale_fr,
    created_at: now,
    updated_at: now,
  };

  const sessions = template.sessions.map((s: any) => ({
    ...s,
    id: crypto.randomUUID(),
    plan_id: planId,
    created_at: now,
  }));

  const planExercises = template.plan_exercises.map((pe: any) => ({
    ...pe,
    id: crypto.randomUUID(),
    session_id: sessions.find((s: any) => s.template_session_ref === pe.template_session_ref)?.id,
  }));

  // Video Gate: validate all exercise slugs before saving
  const slugs = [...new Set(planExercises.map((pe: any) => pe.exercise_slug as string))];
  const { data: exercises } = await db
    .from('exercises')
    .select('slug, video_front_url')
    .in('slug', slugs);

  const noVideo = (exercises ?? []).filter((e: any) => !e.video_front_url);
  if (noVideo.length > 0) {
    return errorResponse(
      `Template exercise(s) missing video: ${noVideo.map((e: any) => e.slug).join(', ')}`,
      500,
      'PLAN_VALIDATION_FAILED',
    );
  }

  // Persist to DB
  await db.from('plans').insert(plan);
  await db.from('sessions').insert(sessions);
  await db.from('plan_exercises').insert(planExercises);

  return jsonResponse({ plan, sessions, plan_exercises: planExercises });
}

async function generateWithAI(db: any, user: User, userId: string): Promise<Response> {
  // Fetch exercise library filtered by user's equipment
  const { data: exercises } = await db
    .from('exercises')
    .select('slug, name_en, equipment, muscle_primary, muscle_secondary, video_front_url')
    .contains('equipment', user.equipment.length > 0 ? user.equipment : ['barbell'])
    .not('video_front_url', 'is', null); // Video Gate: only include exercises with video

  if (!exercises || exercises.length === 0) {
    return errorResponse(
      'No exercises found for the selected equipment.',
      422,
      'PROFILE_INCOMPLETE',
    );
  }

  const exerciseLibraryJson = JSON.stringify(
    exercises.map((e: any) => ({
      slug: e.slug,
      name: e.name_en,
      equipment: e.equipment,
      primary: e.muscle_primary,
      secondary: e.muscle_secondary,
    })),
  );

  const systemPrompt = buildSystemPrompt(user, exerciseLibraryJson);

  const anthropic = getAnthropicClient();
  let lastError = '';

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const errorFeedback = attempt > 0
      ? `\n\nPrevious attempt failed validation. Fix these issues:\n${lastError}`
      : '';

    const message = await anthropic.messages.create({
      model: PLAN_MODEL,
      max_tokens: 4096,
      system: [{ type: 'text', text: systemPrompt, cache_control: CACHE_CONTROL }],
      messages: [
        {
          role: 'user',
          content: `Generate a ${user.weeks_total ?? 8}-week training plan in JSON format following the schema provided.${errorFeedback}`,
        },
      ],
    });

    const responseText = message.content[0].type === 'text' ? message.content[0].text : '';

    let planPayload: any;
    try {
      // Extract JSON from code block if present
      const jsonMatch = responseText.match(/```json\n?([\s\S]*?)\n?```/) ?? [null, responseText];
      planPayload = JSON.parse(jsonMatch[1]!);
    } catch {
      lastError = 'Response was not valid JSON.';
      continue;
    }

    // Run rule-checker (Principle IV: Video Gate; volume; rest days; duration)
    const validation = await validatePlan({
      sessions: planPayload.sessions,
      plan_exercises: planPayload.plan_exercises,
      user_days_per_week: user.days_per_week,
      user_session_length_min: user.session_length_min,
    });

    if (!validation.valid) {
      lastError = validation.errors.join('\n');
      continue;
    }

    // Persist to DB
    const planId = crypto.randomUUID();
    const now = new Date().toISOString();

    const plan = {
      id: planId,
      user_id: userId,
      name: planPayload.name ?? `${user.goal} plan`,
      status: 'active',
      weeks_total: planPayload.weeks_total ?? 8,
      current_week: 1,
      generated_by: 'ai',
      rationale_en: planPayload.rationale_en,
      rationale_fr: planPayload.rationale_fr,
      created_at: now,
      updated_at: now,
    };

    const sessions = planPayload.sessions.map((s: any) => ({ ...s, plan_id: planId }));
    const planExercises = planPayload.plan_exercises;

    await db.from('plans').insert(plan);
    await db.from('sessions').insert(sessions);
    await db.from('plan_exercises').insert(planExercises);

    return jsonResponse({ plan, sessions, plan_exercises: planExercises });
  }

  return errorResponse(
    `Plan validation failed after ${MAX_RETRIES} attempts: ${lastError}`,
    500,
    'PLAN_VALIDATION_FAILED',
  );
}

function buildSystemPrompt(user: User, exerciseLibraryJson: string): string {
  return `You are an expert strength and conditioning coach. Generate a personalized training plan.

USER PROFILE:
- Goal: ${user.goal}
- Level: ${user.level}
- Days/week: ${user.days_per_week}
- Session length: ${user.session_length_min} minutes
- Equipment: ${user.equipment.join(', ')}
- Limitations: ${user.limitations?.join(', ') ?? 'none'}
- Language: ${user.language}

EXERCISE LIBRARY (only use slugs from this list):
${exerciseLibraryJson}

OUTPUT FORMAT (strict JSON):
{
  "name": "Plan name",
  "weeks_total": 8,
  "rationale_en": "Brief explanation of the plan design",
  "rationale_fr": "Brève explication de la conception du programme",
  "sessions": [
    {
      "id": "<uuid>",
      "week_number": 1,
      "day_of_week": 1,
      "name_en": "Session name",
      "name_fr": "Nom de la séance",
      "muscle_groups": ["quadriceps", "glutes"],
      "estimated_min": 60
    }
  ],
  "plan_exercises": [
    {
      "id": "<uuid>",
      "session_id": "<session uuid>",
      "exercise_slug": "barbell-squat",
      "sort_order": 0,
      "sets": 4,
      "reps_min": 6,
      "reps_max": 8,
      "rpe_target": 8.0,
      "rest_sec": 180,
      "suggested_weight_kg": null
    }
  ]
}

RULES (MUST follow, or plan will be rejected):
1. Every exercise_slug MUST exist in the exercise library above.
2. Each week must have at least 1 rest day (session count < 7).
3. Session count per week must equal ${user.days_per_week}.
4. Total session duration must be estimable within ${user.session_length_min + 10} minutes.
5. No muscle group should exceed ~20 sets per week.`;
}

function selectTemplate(user: User): string {
  if (user.level === 'beginner') return 'beginner-full-body-3x';
  if (user.equipment.includes('bodyweight') && !user.equipment.includes('barbell')) {
    return 'home-dumbbell-3x';
  }
  if (user.goal === 'general_fitness') return 'home-dumbbell-3x';
  return 'intermediate-ppl-4x';
}

function isProSubscription(sub: any): boolean {
  if (!sub || sub.tier !== 'pro') return false;
  const now = Date.now();
  if (sub.is_trial && sub.trial_ends_at) {
    return new Date(sub.trial_ends_at).getTime() > now;
  }
  if (sub.current_period_ends_at) {
    return new Date(sub.current_period_ends_at).getTime() > now;
  }
  return false;
}
