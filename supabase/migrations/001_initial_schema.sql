-- Migration 001: Initial schema
-- Creates all 14 entities for the Tekto AI MVP

-- ── Extensions ───────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Enums ────────────────────────────────────────────────────────────────
CREATE TYPE training_goal AS ENUM ('muscle', 'strength', 'fat_loss', 'general_fitness');
CREATE TYPE training_level AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE app_language AS ENUM ('en', 'fr');
CREATE TYPE unit_pref AS ENUM ('kg', 'lb');
CREATE TYPE plan_status AS ENUM ('active', 'completed', 'archived');
CREATE TYPE subscription_tier AS ENUM ('free', 'pro');
CREATE TYPE coach_message_role AS ENUM ('user', 'assistant', 'system');

-- ── 1. users (extends auth.users) ────────────────────────────────────────
CREATE TABLE public.users (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  goal            training_goal NOT NULL,
  level           training_level NOT NULL,
  days_per_week   int NOT NULL CHECK (days_per_week BETWEEN 1 AND 7),
  session_length_min int NOT NULL CHECK (session_length_min BETWEEN 15 AND 120),
  equipment       text[] NOT NULL DEFAULT '{}',
  limitations     text[],
  language        app_language NOT NULL DEFAULT 'en',
  unit            unit_pref NOT NULL DEFAULT 'kg',
  health_sync_enabled bool NOT NULL DEFAULT false,
  onboarding_completed_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 2. exercises (read-only content, no RLS needed) ──────────────────────
CREATE TABLE public.exercises (
  slug                    text PRIMARY KEY,
  name_en                 text NOT NULL,
  name_fr                 text NOT NULL,
  equipment               text[] NOT NULL DEFAULT '{}',
  muscle_primary          text[] NOT NULL DEFAULT '{}',
  muscle_secondary        text[] NOT NULL DEFAULT '{}',
  cues_en                 text[] NOT NULL DEFAULT '{}',
  cues_fr                 text[] NOT NULL DEFAULT '{}',
  common_mistakes_en      text[] NOT NULL DEFAULT '{}',
  common_mistakes_fr      text[] NOT NULL DEFAULT '{}',
  video_front_url         text,          -- NULL = no video → blocked by Video Gate
  video_side_url          text,
  variation_easier_slug   text REFERENCES public.exercises(slug),
  variation_harder_slug   text REFERENCES public.exercises(slug),
  form_check_supported    bool NOT NULL DEFAULT false,
  form_check_lift_key     text,
  created_at              timestamptz NOT NULL DEFAULT now()
);

-- ── 3. plans ─────────────────────────────────────────────────────────────
CREATE TABLE public.plans (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name            text NOT NULL,
  status          plan_status NOT NULL DEFAULT 'active',
  weeks_total     int NOT NULL CHECK (weeks_total BETWEEN 4 AND 12),
  current_week    int NOT NULL DEFAULT 1,
  generated_by    text NOT NULL DEFAULT 'ai',    -- 'ai' | 'template:<name>'
  rationale_en    text,
  rationale_fr    text,
  adaptation_log  jsonb NOT NULL DEFAULT '[]',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Only one active plan per user
CREATE UNIQUE INDEX unique_active_plan_per_user
  ON public.plans (user_id)
  WHERE status = 'active';

-- ── 4. sessions ──────────────────────────────────────────────────────────
CREATE TABLE public.sessions (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  plan_id         uuid NOT NULL REFERENCES public.plans(id) ON DELETE CASCADE,
  week_number     int NOT NULL,
  day_of_week     int NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Mon
  name_en         text NOT NULL,
  name_fr         text NOT NULL,
  muscle_groups   text[] NOT NULL DEFAULT '{}',
  estimated_min   int,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 5. plan_exercises ────────────────────────────────────────────────────
CREATE TABLE public.plan_exercises (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id          uuid NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  exercise_slug       text NOT NULL REFERENCES public.exercises(slug),
  sort_order          int NOT NULL DEFAULT 0,
  sets                int NOT NULL CHECK (sets BETWEEN 1 AND 10),
  reps_min            int NOT NULL CHECK (reps_min >= 1),
  reps_max            int NOT NULL,
  rpe_target          numeric(3,1),
  rest_sec            int NOT NULL DEFAULT 90,
  suggested_weight_kg numeric(6,2),
  CONSTRAINT reps_range CHECK (reps_min <= reps_max)
);

-- ── 6. workout_logs ──────────────────────────────────────────────────────
CREATE TABLE public.workout_logs (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  session_id      uuid NOT NULL REFERENCES public.sessions(id),
  started_at      timestamptz NOT NULL DEFAULT now(),
  finished_at     timestamptz,
  effort_rating   int CHECK (effort_rating BETWEEN 1 AND 10),
  total_volume_kg numeric(10,2),
  synced_to_health bool NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ── 7. set_logs ──────────────────────────────────────────────────────────
CREATE TABLE public.set_logs (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  workout_log_id      uuid NOT NULL REFERENCES public.workout_logs(id) ON DELETE CASCADE,
  plan_exercise_id    uuid NOT NULL REFERENCES public.plan_exercises(id),
  set_number          int NOT NULL,
  weight_kg           numeric(6,2) NOT NULL CHECK (weight_kg > 0),
  reps                int NOT NULL CHECK (reps >= 1),
  rpe_actual          numeric(3,1),
  is_pr               bool NOT NULL DEFAULT false,
  logged_at           timestamptz NOT NULL DEFAULT now()
);

-- ── 8. personal_records ──────────────────────────────────────────────────
CREATE TABLE public.personal_records (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  exercise_slug   text NOT NULL REFERENCES public.exercises(slug),
  best_weight_kg  numeric(6,2) NOT NULL,
  best_reps       int NOT NULL,
  best_e1rm       numeric(8,2) NOT NULL,
  achieved_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, exercise_slug)
);

-- ── 9. coach_conversations ────────────────────────────────────────────────
CREATE TABLE public.coach_conversations (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan_id     uuid REFERENCES public.plans(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ── 10. coach_messages ───────────────────────────────────────────────────
CREATE TABLE public.coach_messages (
  id                      uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id         uuid NOT NULL REFERENCES public.coach_conversations(id) ON DELETE CASCADE,
  role                    coach_message_role NOT NULL,
  content                 text NOT NULL,
  context_screen          text,
  context_exercise_slug   text,
  plan_change_proposed    jsonb,
  plan_change_applied     bool NOT NULL DEFAULT false,
  satisfaction_rating     bool,                -- true=thumbs-up, false=thumbs-down, NULL=not rated
  created_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT plan_change_applied_requires_proposed
    CHECK (NOT plan_change_applied OR plan_change_proposed IS NOT NULL)
);

-- ── 11. coach_quota_usage ────────────────────────────────────────────────
CREATE TABLE public.coach_quota_usage (
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  iso_week        text NOT NULL,              -- format: 'YYYY-Www'
  questions_used  int NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, iso_week)
);

-- ── 12. form_check_sessions ──────────────────────────────────────────────
CREATE TABLE public.form_check_sessions (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  exercise_slug       text NOT NULL REFERENCES public.exercises(slug),
  workout_log_id      uuid REFERENCES public.workout_logs(id),
  rep_count           int NOT NULL DEFAULT 0,
  form_score          int CHECK (form_score BETWEEN 0 AND 100),
  cues_shown          text[] NOT NULL DEFAULT '{}',
  top_tip_en          text,
  top_tip_fr          text,
  user_shared         bool NOT NULL DEFAULT false,  -- Principle II: defaults false
  created_at          timestamptz NOT NULL DEFAULT now()
);

-- ── 13. subscriptions ────────────────────────────────────────────────────
CREATE TABLE public.subscriptions (
  id                      uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                 uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  tier                    subscription_tier NOT NULL DEFAULT 'free',
  is_trial                bool NOT NULL DEFAULT false,
  trial_ends_at           timestamptz,
  current_period_ends_at  timestamptz,
  cancelled_at            timestamptz,
  revenuecat_customer_id  text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- ── 14. exercise_video_downloads ─────────────────────────────────────────
CREATE TABLE public.exercise_video_downloads (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  exercise_slug   text NOT NULL REFERENCES public.exercises(slug),
  plan_id         uuid NOT NULL REFERENCES public.plans(id) ON DELETE CASCADE,
  local_path      text,
  file_size_bytes bigint,
  downloaded_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, exercise_slug, plan_id)
);

-- ── Indexes for common query patterns ────────────────────────────────────
CREATE INDEX idx_plans_user_id ON public.plans(user_id);
CREATE INDEX idx_sessions_plan_id ON public.sessions(plan_id);
CREATE INDEX idx_plan_exercises_session_id ON public.plan_exercises(session_id);
CREATE INDEX idx_workout_logs_user_id ON public.workout_logs(user_id);
CREATE INDEX idx_set_logs_workout_log_id ON public.set_logs(workout_log_id);
CREATE INDEX idx_personal_records_user_exercise ON public.personal_records(user_id, exercise_slug);
CREATE INDEX idx_coach_messages_conversation_id ON public.coach_messages(conversation_id);
CREATE INDEX idx_coach_quota_user_week ON public.coach_quota_usage(user_id, iso_week);
CREATE INDEX idx_form_check_user_id ON public.form_check_sessions(user_id);
CREATE INDEX idx_downloads_user_plan ON public.exercise_video_downloads(user_id, plan_id);
