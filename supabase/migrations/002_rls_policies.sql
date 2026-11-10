-- Migration 002: Row Level Security policies
-- Enforces per-user data isolation across all user tables.
-- exercises is public read-only (no RLS).

-- ── Helper: enable RLS on all user tables ────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.set_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_quota_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_check_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_video_downloads ENABLE ROW LEVEL SECURITY;

-- exercises: public SELECT, no mutations via RLS (content pipeline uses service role)
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "exercises_public_read" ON public.exercises
  FOR SELECT USING (true);

-- ── users ─────────────────────────────────────────────────────────────────
CREATE POLICY "users_own_row" ON public.users
  FOR ALL USING (auth.uid() = id);

-- ── plans ─────────────────────────────────────────────────────────────────
CREATE POLICY "plans_own" ON public.plans
  FOR ALL USING (auth.uid() = user_id);

-- ── sessions (owned via plan) ─────────────────────────────────────────────
CREATE POLICY "sessions_own_via_plan" ON public.sessions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.plans p
      WHERE p.id = sessions.plan_id AND p.user_id = auth.uid()
    )
  );

-- ── plan_exercises (owned via session via plan) ──────────────────────────
CREATE POLICY "plan_exercises_own_via_session" ON public.plan_exercises
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.sessions s
        JOIN public.plans p ON p.id = s.plan_id
      WHERE s.id = plan_exercises.session_id AND p.user_id = auth.uid()
    )
  );

-- ── workout_logs ─────────────────────────────────────────────────────────
CREATE POLICY "workout_logs_own" ON public.workout_logs
  FOR ALL USING (auth.uid() = user_id);

-- ── set_logs (owned via workout_log) ─────────────────────────────────────
CREATE POLICY "set_logs_own_via_workout_log" ON public.set_logs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.workout_logs wl
      WHERE wl.id = set_logs.workout_log_id AND wl.user_id = auth.uid()
    )
  );

-- ── personal_records ─────────────────────────────────────────────────────
CREATE POLICY "personal_records_own" ON public.personal_records
  FOR ALL USING (auth.uid() = user_id);

-- ── coach_conversations ──────────────────────────────────────────────────
CREATE POLICY "coach_conversations_own" ON public.coach_conversations
  FOR ALL USING (auth.uid() = user_id);

-- ── coach_messages (owned via conversation) ──────────────────────────────
CREATE POLICY "coach_messages_own_via_conversation" ON public.coach_messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.coach_conversations cc
      WHERE cc.id = coach_messages.conversation_id AND cc.user_id = auth.uid()
    )
  );

-- ── coach_quota_usage ────────────────────────────────────────────────────
CREATE POLICY "coach_quota_own" ON public.coach_quota_usage
  FOR ALL USING (auth.uid() = user_id);

-- ── form_check_sessions ──────────────────────────────────────────────────
CREATE POLICY "form_check_own" ON public.form_check_sessions
  FOR ALL USING (auth.uid() = user_id);

-- ── subscriptions ────────────────────────────────────────────────────────
-- Users can read their own subscription; writes are service-role only (RevenueCat webhook)
CREATE POLICY "subscriptions_own_read" ON public.subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- ── exercise_video_downloads ─────────────────────────────────────────────
CREATE POLICY "video_downloads_own" ON public.exercise_video_downloads
  FOR ALL USING (auth.uid() = user_id);
