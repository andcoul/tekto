-- Migration 005: spec clarifications 2026-11-10 + constitution v2.0.0
-- Implements data-model.md revision 2026-11-10 against the slug-keyed schema of 001.
-- Note: generate-plan must set plans.source / start_date (T037); until then its inserts fail.

-- ── Enums ────────────────────────────────────────────────────────────────
CREATE TYPE plan_source AS ENUM ('ai', 'template', 'template_fallback');

-- ── users ────────────────────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN timezone           text NOT NULL DEFAULT 'UTC',   -- IANA zone; drives the training-week boundary
  ADD COLUMN consent_at         timestamptz,                   -- NOT NULL after onboarding (enforced by generate-plan: CONSENT_REQUIRED)
  ADD COLUMN consent_version    text,                          -- e.g. '2026-11-v1'
  ADD COLUMN limitations_note   text,                          -- free text for the coach; not used for filtering
  ADD COLUMN strength_estimates jsonb,                         -- {"squat":{"weight_kg","reps"},"bench_press":{…},"deadlift":{…}}; null = skipped
  ADD CONSTRAINT users_limitations_vocab CHECK (
    limitations IS NULL OR limitations <@ ARRAY['knee','lower_back','shoulder','wrist','elbow','hip','ankle','neck']::text[]
  );

-- ── exercises ────────────────────────────────────────────────────────────
ALTER TABLE public.exercises
  ADD COLUMN video_duration_sec int NOT NULL CHECK (video_duration_sec BETWEEN 5 AND 15),
  ADD COLUMN captions_en_url    text NOT NULL,                 -- WebVTT (Constitution VI)
  ADD COLUMN captions_fr_url    text NOT NULL,
  ADD COLUMN contraindications  text[] NOT NULL DEFAULT '{}'
    CHECK (contraindications <@ ARRAY['knee','lower_back','shoulder','wrist','elbow','hip','ankle','neck']::text[]);

-- ── plans ────────────────────────────────────────────────────────────────
ALTER TABLE public.plans
  ADD COLUMN start_date        date NOT NULL,                  -- a Monday in users.timezone (research §10)
  ADD COLUMN last_adapted_week int  NOT NULL DEFAULT 0,        -- idempotency for adapt-plan
  ADD COLUMN source            plan_source NOT NULL,
  ADD COLUMN template_slug     text,
  ADD CONSTRAINT plans_template_slug_iff_template
    CHECK ((source = 'ai') = (template_slug IS NULL)),
  ADD CONSTRAINT plans_last_adapted_le_current
    CHECK (last_adapted_week <= current_week),
  ADD CONSTRAINT plans_start_date_is_monday
    CHECK (EXTRACT(ISODOW FROM start_date) = 1);

COMMENT ON COLUMN public.plans.generated_by IS 'Deprecated: superseded by source/template_slug (migration 005); drop once generate-plan stops writing it.';

-- One active plan per user (already created in 001; kept idempotent)
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_plan_per_user
  ON public.plans (user_id) WHERE status = 'active';

-- ── set_logs: bodyweight sets are logged at 0 kg ─────────────────────────
ALTER TABLE public.set_logs DROP CONSTRAINT IF EXISTS set_logs_weight_kg_check;
ALTER TABLE public.set_logs ADD CONSTRAINT set_logs_weight_kg_check CHECK (weight_kg >= 0);

-- PR trigger ignores unloaded sets (e1RM undefined at 0 kg)
CREATE OR REPLACE FUNCTION public.update_personal_record()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id       uuid;
  v_exercise_slug text;
  v_new_e1rm      numeric(8,2);
  v_existing_e1rm numeric(8,2);
BEGIN
  IF NEW.weight_kg = 0 THEN
    RETURN NEW;
  END IF;

  SELECT wl.user_id, pe.exercise_slug
    INTO v_user_id, v_exercise_slug
    FROM public.workout_logs wl
    JOIN public.plan_exercises pe ON pe.id = NEW.plan_exercise_id
    WHERE wl.id = NEW.workout_log_id;

  IF v_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_new_e1rm := NEW.weight_kg * (1.0 + NEW.reps / 30.0);

  SELECT best_e1rm INTO v_existing_e1rm
    FROM public.personal_records
    WHERE user_id = v_user_id AND exercise_slug = v_exercise_slug;

  IF v_existing_e1rm IS NULL OR v_new_e1rm > v_existing_e1rm THEN
    INSERT INTO public.personal_records (
      user_id, exercise_slug, best_weight_kg, best_reps, best_e1rm, achieved_at
    )
    VALUES (
      v_user_id, v_exercise_slug, NEW.weight_kg, NEW.reps, v_new_e1rm, NEW.logged_at
    )
    ON CONFLICT (user_id, exercise_slug)
    DO UPDATE SET
      best_weight_kg = EXCLUDED.best_weight_kg,
      best_reps      = EXCLUDED.best_reps,
      best_e1rm      = EXCLUDED.best_e1rm,
      achieved_at    = EXCLUDED.achieved_at;

    UPDATE public.set_logs SET is_pr = true WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

-- ── form_check_sessions ──────────────────────────────────────────────────
ALTER TABLE public.form_check_sessions
  ADD COLUMN flagged_reps int[] NOT NULL DEFAULT '{}',          -- 1-based reps with ≥ 1 cue (FR-024)
  ADD COLUMN was_free_try bool  NOT NULL DEFAULT false;         -- free tier: 1 try per lift (FR-029)

CREATE INDEX IF NOT EXISTS idx_form_check_free_try
  ON public.form_check_sessions (user_id, exercise_slug) WHERE was_free_try;

-- ── exercise_video_downloads becomes device-only (data-model entity 14) ──
DROP TABLE IF EXISTS public.exercise_video_downloads;          -- also drops its RLS policy and index

-- ── coach_response_cache: gte-small (384-d), per language, per prompt version
DROP TABLE IF EXISTS public.coach_response_cache;              -- cache data only

CREATE TABLE public.coach_response_cache (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  language         app_language NOT NULL,
  embedding        vector(384) NOT NULL,                       -- Supabase.ai gte-small
  question_hash    text UNIQUE NOT NULL,                       -- hash of normalized question + language
  response_content text NOT NULL,
  prompt_version   text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz NOT NULL DEFAULT now() + INTERVAL '7 days'
);

CREATE INDEX coach_cache_embedding_idx
  ON public.coach_response_cache
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX coach_cache_lang_version_idx
  ON public.coach_response_cache (language, prompt_version);

-- Service role only: RLS on, no client policies
ALTER TABLE public.coach_response_cache ENABLE ROW LEVEL SECURITY;

-- ── plan_templates (content; seeded by content/templates/seed-templates.js)
CREATE TABLE public.plan_templates (
  slug               text PRIMARY KEY,
  level              training_level NOT NULL,
  days_per_week      int NOT NULL,
  equipment_required text[] NOT NULL,
  body               jsonb NOT NULL,                           -- same schema as the generate-plan plan body
  updated_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.plan_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "plan_templates_read_authenticated" ON public.plan_templates
  FOR SELECT TO authenticated USING (true);
