-- 007 — Gate 2 / success-criteria metrics as aggregate-only views (T115; Constitution VII:
-- no analytics SDK). Every view returns counts per signup week or per ISO week (UTC), never a
-- per-user row. Access is service role only: the grants below remove the views from the
-- anon and authenticated API roles. Read them from the SQL editor or with the service key.
--
-- Install counts are not in the database: onboarding completion = first plans ÷ installs,
-- with installs copied from App Store Connect / Play Console into checklists/gate2.md.

-- ── History needed for trial metrics (the subscriptions row only holds the current state) ──
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS trial_started_at   timestamptz,  -- set once by revenuecat-webhook
  ADD COLUMN IF NOT EXISTS trial_converted_at timestamptz;  -- set once on trial conversion

-- Accounts by signup week (ISO week of auth.users.created_at, UTC).
CREATE OR REPLACE VIEW public.v_signups AS
SELECT u.id AS user_id,
       au.created_at AS signed_up_at,
       to_char(au.created_at AT TIME ZONE 'UTC', 'IYYY-"W"IW') AS signup_week
  FROM public.users u
  JOIN auth.users au ON au.id = u.id;
-- v_signups is an internal building block (per user): it is never granted to API roles.

-- SC-001 / PRD onboarding completion: accounts → consent → first plan, by signup week.
CREATE OR REPLACE VIEW public.v_onboarding_funnel AS
SELECT s.signup_week,
       count(*)                                                            AS accounts,
       count(*) FILTER (WHERE u.consent_at IS NOT NULL)                   AS consented,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM public.plans p WHERE p.user_id = s.user_id)) AS first_plan
  FROM public.v_signups s
  JOIN public.users u ON u.id = s.user_id
 GROUP BY s.signup_week;

-- SC-006: users who started the Pro trial ÷ new users, by signup week.
CREATE OR REPLACE VIEW public.v_trial_start_rate AS
SELECT s.signup_week,
       count(*)                                         AS new_users,
       count(sub.trial_started_at)                      AS trial_starts,
       round(count(sub.trial_started_at)::numeric / nullif(count(*), 0), 3) AS rate
  FROM public.v_signups s
  LEFT JOIN public.subscriptions sub ON sub.user_id = s.user_id
 GROUP BY s.signup_week;

-- SC-007: trials converted ÷ trials ended (a 7-day trial has ended 7 days after it started).
CREATE OR REPLACE VIEW public.v_trial_to_paid AS
SELECT to_char(sub.trial_started_at AT TIME ZONE 'UTC', 'IYYY-"W"IW') AS trial_week,
       count(*)                                    AS trials_ended,
       count(sub.trial_converted_at)               AS converted,
       round(count(sub.trial_converted_at)::numeric / nullif(count(*), 0), 3) AS rate
  FROM public.subscriptions sub
 WHERE sub.trial_started_at IS NOT NULL
   AND sub.trial_started_at < now() - interval '7 days'
 GROUP BY 1;

-- SC-008: users with ≥ 1 finished workout in days 22–28 after signup ÷ cohort (complete cohorts only).
CREATE OR REPLACE VIEW public.v_week4_retention AS
SELECT s.signup_week,
       count(*) AS cohort,
       count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM public.workout_logs w
          WHERE w.user_id = s.user_id
            AND w.finished_at >= s.signed_up_at + interval '21 days'
            AND w.finished_at <  s.signed_up_at + interval '28 days'
       )) AS retained,
       round(count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM public.workout_logs w
          WHERE w.user_id = s.user_id
            AND w.finished_at >= s.signed_up_at + interval '21 days'
            AND w.finished_at <  s.signed_up_at + interval '28 days'
       ))::numeric / nullif(count(*), 0), 3) AS rate
  FROM public.v_signups s
 WHERE s.signed_up_at < now() - interval '28 days'
 GROUP BY s.signup_week;

-- Finished workouts per user per ISO week (internal building block, never granted).
CREATE OR REPLACE VIEW public.v_weekly_workouts AS
SELECT w.user_id,
       to_char(w.finished_at AT TIME ZONE 'UTC', 'IYYY-"W"IW') AS iso_week,
       count(*) AS workouts
  FROM public.workout_logs w
 WHERE w.finished_at IS NOT NULL
 GROUP BY w.user_id, 2;

-- SC-009: finished workouts per active user (≥ 1 finished workout that week).
CREATE OR REPLACE VIEW public.v_workouts_per_active_week AS
SELECT iso_week,
       count(*)                                  AS active_users,
       sum(workouts)                             AS workouts,
       round(sum(workouts)::numeric / nullif(count(*), 0), 2) AS workouts_per_active_user
  FROM public.v_weekly_workouts
 GROUP BY iso_week;

-- SC-010: active Pro users (a finished workout that week) who ran ≥ 1 form check that week.
-- "Pro" is the current subscription state (the table keeps no tier history).
CREATE OR REPLACE VIEW public.v_form_check_weekly_pro AS
SELECT ww.iso_week,
       count(*) AS active_pro_users,
       count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM public.form_check_sessions f
          WHERE f.user_id = ww.user_id
            AND to_char(f.created_at AT TIME ZONE 'UTC', 'IYYY-"W"IW') = ww.iso_week
       )) AS with_form_check,
       round(count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM public.form_check_sessions f
          WHERE f.user_id = ww.user_id
            AND to_char(f.created_at AT TIME ZONE 'UTC', 'IYYY-"W"IW') = ww.iso_week
       ))::numeric / nullif(count(*), 0), 3) AS rate
  FROM public.v_weekly_workouts ww
  JOIN public.subscriptions sub ON sub.user_id = ww.user_id AND sub.tier = 'pro'
 GROUP BY ww.iso_week;

-- SC-011: thumbs-up ÷ rated coach answers, by ISO week of the answer.
CREATE OR REPLACE VIEW public.v_coach_thumbs_up AS
SELECT to_char(m.created_at AT TIME ZONE 'UTC', 'IYYY-"W"IW') AS iso_week,
       count(*)                                              AS rated,
       count(*) FILTER (WHERE m.satisfaction_rating)         AS thumbs_up,
       round(count(*) FILTER (WHERE m.satisfaction_rating)::numeric / nullif(count(*), 0), 3) AS rate
  FROM public.coach_messages m
 WHERE m.role = 'assistant' AND m.satisfaction_rating IS NOT NULL
 GROUP BY 1;

-- North star: finished workouts per paying user per ISO week (paying = Pro, not in trial;
-- current subscription state).
CREATE OR REPLACE VIEW public.v_north_star AS
WITH paying AS (
  SELECT user_id FROM public.subscriptions WHERE tier = 'pro' AND NOT is_trial
)
SELECT ww.iso_week,
       (SELECT count(*) FROM paying)              AS paying_users,
       sum(ww.workouts)                           AS workouts,
       round(sum(ww.workouts)::numeric / nullif((SELECT count(*) FROM paying), 0), 2) AS workouts_per_paying_user
  FROM public.v_weekly_workouts ww
  JOIN paying p ON p.user_id = ww.user_id
 GROUP BY ww.iso_week;

-- SC-016: median minutes from account creation to the first plan, by signup week.
CREATE OR REPLACE VIEW public.v_onboarding_duration AS
SELECT s.signup_week,
       count(*) AS users_with_plan,
       round((percentile_cont(0.5) WITHIN GROUP (
         ORDER BY extract(epoch FROM (fp.first_plan_at - s.signed_up_at)) / 60
       ))::numeric, 1) AS median_minutes
  FROM public.v_signups s
  JOIN (SELECT user_id, min(created_at) AS first_plan_at FROM public.plans GROUP BY user_id) fp
    ON fp.user_id = s.user_id
 GROUP BY s.signup_week;

-- ── Service role only ─────────────────────────────────────────────────────
REVOKE ALL ON
  public.v_signups, public.v_onboarding_funnel, public.v_trial_start_rate, public.v_trial_to_paid,
  public.v_week4_retention, public.v_weekly_workouts, public.v_workouts_per_active_week,
  public.v_form_check_weekly_pro, public.v_coach_thumbs_up, public.v_north_star,
  public.v_onboarding_duration
FROM PUBLIC, anon, authenticated;
