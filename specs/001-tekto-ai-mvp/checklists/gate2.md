# Gate 2 — Beta Metrics Before Public Launch

**Purpose**: Record the beta metrics against the PRD Goals targets before submitting for general availability (Constitution: Quality Gates → Gate 2; spec Success Criteria).
**Source**: aggregate-only views from `supabase/migrations/007_metrics_views.sql` (service role only; no analytics SDK — Constitution VII). Weeks are ISO weeks in UTC.
**How to read**: run each query in the Supabase SQL editor of the production project, over the full beta period unless noted, and copy the result here with the date.

## Inputs from the stores (not in the database)

| Input | Source | Value | Date |
|---|---|---|---|
| Installs during the beta (iOS) | App Store Connect → Analytics → Units | | |
| Installs during the beta (Android) | Play Console → Statistics → Installs | | |

## Metrics

| Metric | Target | Query | Value | Pass? |
|---|---|---|---|---|
| Onboarding completion (SC-001) | ≥ 70 % | `select sum(first_plan) from v_onboarding_funnel;` ÷ installs above | | |
| Trial start rate (SC-006) | ≥ 30 % | `select sum(trial_starts)::numeric / sum(new_users) from v_trial_start_rate;` | | |
| Trial to paid (SC-007) | ≥ 35 % | `select sum(converted)::numeric / sum(trials_ended) from v_trial_to_paid;` | | |
| Week-4 retention (SC-008) | ≥ 40 % | `select sum(retained)::numeric / sum(cohort) from v_week4_retention;` | | |
| Workouts per active user per week (SC-009) | ≥ 3 | `select avg(workouts_per_active_user) from v_workouts_per_active_week;` | | |
| Form-check usage, Pro (SC-010) | ≥ 50 % | `select sum(with_form_check)::numeric / sum(active_pro_users) from v_form_check_weekly_pro;` | | |
| Coach satisfaction (SC-011) | ≥ 85 % | `select sum(thumbs_up)::numeric / sum(rated) from v_coach_thumbs_up;` | | |
| App Store rating (SC-012) | ≥ 4.6 | App Store Connect / Play Console ratings (not in the database) | | |
| Time to first plan, median (SC-016) | < 3 min | `select signup_week, median_minutes from v_onboarding_duration order by 1;` | | |
| North star: workouts per paying user per week | tracked, no target | `select * from v_north_star order by iso_week;` | | |

## Notes

- Constitution Gate 2 currently lists three of these metrics (onboarding completion, trial start rate, week-4 retention); the PRD lists all eight. Aligning the constitution needs its own amendment PR.
- Form-check usage and the north star use the **current** subscription state, since `subscriptions` keeps no tier history; read them during the beta, not long after it.
- Trial metrics use `subscriptions.trial_started_at` / `trial_converted_at`, recorded by the RevenueCat webhook from migration 007 on; trials started before that are not counted.

**Status**: Pending — fill in at the end of the beta.
