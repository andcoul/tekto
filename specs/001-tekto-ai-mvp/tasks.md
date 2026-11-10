---
description: "Task list for Tekto AI MVP (regenerated after spec clarifications 2026-11-10 and constitution v2.0.0)"
---

# Tasks: Tekto AI MVP

**Input**: Design documents from `specs/001-tekto-ai-mvp/`
**Branch**: `001-tekto-ai-mvp` | **Date**: 2026-11-10 (regenerated; previous version archived outside the repo)

**Prerequisites**: plan.md ✓ (revised 2026-11-10) | spec.md ✓ (Clarifications 2026-11-10) | research.md ✓ | data-model.md ✓ | contracts/ ✓ | quickstart.md ✓ | constitution.md ✓ (v2.0.0)

**Tests**: REQUIRED by Constitution Principle V. In every phase, each test task comes **before** the implementation task it covers and must fail first (Red → Green → Refactor). Required units: `PlanAdaptationService`, `FormScoreCalculator`, `RepCounter`, `CoachQuotaService`, subscription gate checks, plus the units this revision adds (`TemplatePlanBuilder`, `ExerciseSubstitution`, `PlanValidator`, week boundary, form-check free try). A widget test is required for every paywall surface, and an integration test for the offline flush.

**Brownfield note**: a first implementation already exists for many files below. "Create" means create or update the file until it meets the task; "Verify" tasks cover features that already exist in code and must be checked against the spec, with gaps fixed. `/speckit-converge` and `/speckit-implement` decide what is already done. No task is pre-checked.

**Remediation (2026-11-10, `/speckit-analyze` run 2)**: T099–T113 added inside their phases for E1 (existing features without coverage), U2 (starting weights); T114 (staging) added after run 3, with T006, T016, T039, T079, T081, T085 extended for U4, U5, U7, F2; T030, T040, T047, T080, T091 extended for U1, U2, C1, F3. IDs above T098 are therefore out of sequence; follow phase order.

**Organization**: Tasks are grouped by user story; story labels match spec.md (US1–US7). Phases follow spec priority: P1 = US6, US1, US2, US7, US4; P2 = US3, US5.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: User story label for story-phase tasks only

## Path Conventions

- Mobile: `mobile/lib/`, `mobile/test/`
- Backend: `supabase/functions/`, `supabase/migrations/`, `supabase/evals/`
- Content: `content/exercises/`, `content/templates/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Tooling, dependencies and configuration changed by this revision.

- [X] T001 Create missing directories from plan.md Project Structure: `supabase/evals/coach-guardrails/results/`, `content/exercises/captions/`, and add a `.gitkeep` to each
- [X] T002 [P] Update `mobile/pubspec.yaml`: add `sqlcipher_flutter_libs` (comment: "encrypts the Drift DB at rest — Constitution II") and `flutter_timezone` (comment: "IANA time zone for the training-week boundary — FR-026"); remove `retrofit`, `retrofit_generator`, `lottie`, `haptic_feedback` and replace any `haptic_feedback` usage with Flutter's built-in `HapticFeedback`; confirm every remaining dependency keeps a one-line justification comment (Constitution VII); run `flutter pub get`
- [X] T003 [P] Create `supabase/deno.json` with tasks `test` (`deno test --allow-env supabase/functions`) and `eval:guardrails` (`deno run --allow-net --allow-env --allow-read --allow-write supabase/evals/coach-guardrails/run.ts`)
- [X] T004 [P] Create `mobile/.env.example` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY_IOS`, `REVENUECAT_API_KEY_ANDROID`) and add to `supabase/.env.local.example` a `COACH_PROMPT_VERSION=2026-11-v1` entry plus a comment that embeddings use the built-in `gte-small` model and need no key
- [ ] T114 Set up the staging environment used by T072, T075 and T095: a separate Supabase staging project; secrets `ANTHROPIC_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`, `CLOUDFLARE_STREAM_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` set with `supabase secrets set`; Supabase Vault secrets `service_role_key` and `project_url` (both read by the T007 cron job); document the steps in `specs/001-tekto-ai-mvp/quickstart.md` under "Environment Setup"
- [X] T005 [P] Extend the exercise schema in `content/exercises/exercises.json` so every entry has `video_duration_sec` (int, 5–15), `captions_en_url`, `captions_fr_url`, and `contraindications` (array of tags from `knee | lower_back | shoulder | wrist | elbow | hip | ankle | neck`, default `[]`); backfill the 15 existing entries

**Checkpoint**: `flutter pub get` and `deno task test` both run (tests may fail).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema, shared backend helpers, encrypted local DB and models used by every story.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Database migrations

- [X] T006 Create `supabase/migrations/005_clarifications.sql` implementing data-model.md revision 2026-11-10 exactly:
  - `users`: add `timezone text NOT NULL DEFAULT 'UTC'`, `consent_at timestamptz` (nullable), `consent_version text` (nullable), `limitations_note text` (nullable), `strength_estimates jsonb` (nullable; `{ "squat": {"weight_kg", "reps"}, "bench_press": {…}, "deadlift": {…} }`); CHECK that `limitations` ⊆ `{knee,lower_back,shoulder,wrist,elbow,hip,ankle,neck}`
  - `exercises`: add `captions_en_url text NOT NULL`, `captions_fr_url text NOT NULL`, `contraindications text[] NOT NULL DEFAULT '{}'`
  - `plans`: add `start_date date NOT NULL`, `last_adapted_week int NOT NULL DEFAULT 0`, `source` enum `ai | template | template_fallback` NOT NULL, `template_slug text` (nullable); CHECK "`template_slug` is non-null iff `source` ≠ `ai`"; CHECK `last_adapted_week <= current_week`; UNIQUE partial index on `(user_id) WHERE status = 'active'`
  - `set_logs`: replace the weight CHECK with `weight_kg >= 0`; replace `update_personal_record()` so sets with `weight_kg = 0` are ignored
  - `form_check_sessions`: add `flagged_reps int[] NOT NULL DEFAULT '{}'`, `was_free_try bool NOT NULL DEFAULT false`
  - `exercise_video_downloads`: drop the remote table and its RLS policy (it becomes device-only — data-model.md entity 14)
  - `coach_response_cache`: drop and recreate (cache data only) with `language` enum `en | fr` NOT NULL, `embedding vector(384) NOT NULL`, `question_hash text UNIQUE NOT NULL`, `response_content text NOT NULL`, `prompt_version text NOT NULL`, `created_at`, `expires_at timestamptz NOT NULL`; ivfflat index on `embedding`; RLS enabled with no client policies (service role only)
  - Create `plan_templates` (`slug text PK`, `level` enum NOT NULL, `days_per_week int NOT NULL`, `equipment_required text[] NOT NULL`, `body jsonb NOT NULL`, `updated_at timestamptz NOT NULL`); SELECT for authenticated users, no client writes
- [X] T007 Create `supabase/migrations/006_adaptation_cron.sql`: enable `pg_cron` and `pg_net`; schedule an hourly job named `adapt-due-plans` that POSTs `{"mode":"batch"}` to `<SUPABASE_URL>/functions/v1/adapt-plan` with the service-role key read from `vault.decrypted_secrets` (never hard-coded)
- [X] T008 Run `supabase db reset` and confirm migrations 001–006 apply cleanly; fix any conflicts with 001–004

### Shared backend helpers

- [X] T009 [P] Update `supabase/functions/_shared/types.ts` to mirror every new column and the `plan_templates`, `coach_response_cache` tables, plus `PlanSource`, `CoachPlanChange` (all four `type`s with `session_id`, `week_number`, `target_duration_min`) and `AdaptationEvent` (`field: 'suggested_weight_kg' | 'reps_max'`)
- [X] T010 [P] Update `supabase/functions/_shared/claude.ts`: `PLAN_MODEL = 'claude-sonnet-5-5'`, `COACH_MODEL = 'claude-haiku-5-5'`; helper for structured outputs via `output_config.format` (no prefill, no forced `tool_choice`); effort always set explicitly; streaming with `finalMessage()`; check `stop_reason` (including `refusal`, `max_tokens`) before reading content; plan calls send beta `server-side-fallback-2026-07-01` with `fallbacks: "default"`; one structured JSON log line per call `{fn, model, ttft_ms, total_ms, input_tokens, output_tokens, cache_read_tokens}` (research §2, §13)
- [X] T011 [P] Create `supabase/functions/_shared/embeddings.ts`: `embed(text)` using `new Supabase.ai.Session('gte-small')` with `{ mean_pool: true, normalize: true }`, returning a 384-length array; throw a typed `EmbeddingUnavailableError` if `Supabase.ai` is missing (research §8 fallback note)

### Shared plan logic — tests first (Constitution V)

- [X] T012 [P] Write failing tests `supabase/functions/_shared/exercise-substitution.test.ts`: returns an exercise with the same `muscle_primary`, doable with the user's equipment, with non-null `video_front_url`, and with no `contraindications` overlapping the user's `limitations`; prefers the closest equipment match; returns `null` when no candidate exists
- [X] T013 [P] Write failing tests `supabase/functions/_shared/plan-validator.test.ts`: rejects any slug without a video (Video Gate); rejects exercises needing unavailable equipment or contraindicated by limitations; rejects two consecutive days training the same muscle group; rejects `estimated_duration_min > session_length_min + 10`; rejects `weeks_total` outside 4–12; applies the per-level volume bounds (beginner 10–14, intermediate 14–18, advanced 16–22 sets/muscle/week) **only** when `source = 'ai'`
- [X] T014 Implement `supabase/functions/_shared/exercise-substitution.ts` until T012 passes
- [X] T015 Update `supabase/functions/_shared/plan-validator.ts` until T013 passes (one validator for AI and template plans — FR-002a)

### Mobile core

- [X] T016 Update `mobile/lib/shared/services/local_db/database.dart`: open through Drift `NativeDatabase` with SQLCipher; on first launch generate a random 256-bit key, store it in `flutter_secure_storage`, apply `PRAGMA key`; mirror every new column from T006; define the local-only `sync_queue` table (`id` autoincrement, `operation` `insert | update | delete`, `table_name`, `payload` JSON text, `created_at`, `retry_count` max 3, `status` `pending | failed`) and the local-only `exercise_video_downloads` table (`exercise_id` PK, `local_path`, `captions_local_paths` JSON, `downloaded_at`, `file_size_bytes`; never synced); add `wipe()` that deletes the DB file and the key (used by account deletion)
- [X] T017 [P] Update DAOs in `mobile/lib/shared/services/local_db/daos/`: `exercise_dao.dart` (captions, contraindications), `plan_dao.dart` (`source`, `template_slug`, `start_date`, `last_adapted_week`), `form_check_dao.dart` (`flagged_reps`, `was_free_try`, `hasFreeTry(userId, liftKey)`), `subscription_dao.dart`
- [X] T018 [P] Create the missing Freezed models in `mobile/lib/shared/models/` so all 14 entities exist (today only `coach_model.dart`, `exercise_model.dart`, `plan_model.dart`, `subscription_model.dart`, `workout_model.dart`): `user_model.dart`, `session_model.dart`, `plan_exercise_model.dart`, `set_log_model.dart`, `personal_record_model.dart`, `coach_quota_usage_model.dart`, `form_check_session_model.dart`, `exercise_video_download_model.dart`; add every new field from data-model.md; run `dart run build_runner build`
- [X] T099 [P] Verify the app shell against plan.md and Constitution VI: `mobile/lib/main.dart` (env-aware bootstrap, `ProviderScope`, Crashlytics init), `mobile/lib/app.dart` (`MaterialApp.router`, localization delegates), `mobile/lib/core/theme/app_theme.dart` (dark-first: charcoal `#1A1A1A`, accent `#FF6B2C`, spacing 4/8/12/16/24/32/48 dp, buttons ≥ 48×48 dp; light theme follows system), `mobile/lib/core/router/app_router.dart` (routes `/onboarding`, `/auth`, `/home`, `/plan`, `/workout/:sessionId`, `/library`, `/library/:exerciseSlug`, `/coach`, `/form-check/:exerciseSlug`, `/progress`, `/settings`; redirect to `/auth` when signed out); fix any gap
- [X] T100 [P] Verify `mobile/lib/core/iap/revenuecat_service.dart`: platform-specific API key, `appUserID` set to the Supabase `auth.uid()` after login, wrappers `getCustomerInfo()`, `purchasePackage()`, `restorePurchases()`, `isPro` from `entitlements.active.containsKey('pro')`
- [X] T019 [P] Add ARB keys to `mobile/lib/core/l10n/app_en.arb` and `app_fr.arb`: consent screen text (version `2026-11-v1`), language step, `offline_video_requires_pro`, `plan_fallback_notice`, `free_plan_days_capped`, `coach_unavailable`, `pro_unavailable_in_region`, adaptation card strings, form-check free-try used

**Checkpoint**: `supabase db reset` succeeds; `deno task test` passes T012–T013; the app boots and the local DB file cannot be opened with plain `sqlite3`.

---

## Phase 3: User Story 6 — Exercise Video Library (Priority: P1)

**Goal**: Any user browses the library with filmed, captioned videos; Pro users download plan videos for offline use; free users offline see text cues and a non-blocking notice.

**Independent Test**: A free user opens the library, plays an exercise video with captions; in airplane mode the same user sees cues and the "Offline video requires Tekto Pro" notice; a Pro user downloads the plan and plays it offline.

### Tests for User Story 6 (write first, must fail)

- [X] T020 [P] [US6] Update `mobile/test/unit/exercise_repository_test.dart`: filters by equipment and sorts alphabetically; offline returns cached text fields (names, cues, mistakes) for every exercise in the active plan for a **free** user (Constitution I v2.0.0)
- [X] T021 [P] [US6] Create `mobile/test/widget/video_player_widget_test.dart`: free user offline → notice shown, no modal, no blocking overlay; Pro user offline with a download → plays the local file; captions track is attached in the user's language

### Implementation for User Story 6

- [ ] T022 [US6] **Content dependency** — extend `content/exercises/exercises.json` from 15 to ≥ 150 entries covering barbell, dumbbell, cable, bodyweight and resistance-band movements (FR-013), including the 8 form-check lifts with `form_check_lift_key` in `squat, deadlift, bench_press, overhead_press, row, lunge, hip_thrust, push_up`; video URLs come from the content workstream (blocks Gate 1)
- [X] T023 [P] [US6] Add WebVTT caption files `content/exercises/captions/<slug>_en.vtt` and `<slug>_fr.vtt` for every exercise in `exercises.json` (FR-035)
- [X] T024 [US6] Update `content/exercises/seed-exercises.js`: fail on any row missing `video_front_url`, `captions_en_url` or `captions_fr_url`; upload each `.vtt` as a Cloudflare Stream caption track; warn when fewer than 150 rows in dev and exit non-zero when fewer than 150 with `--production`
- [X] T025 [P] [US6] Update `mobile/lib/features/library/data/exercise_repository.dart` to pass T020: cache text fields for every exercise in the active plan for all users; fetch online and refresh the cache
- [X] T026 [US6] Update `mobile/lib/shared/widgets/video_player_widget.dart` to pass T021: captions on by default when the OS caption setting is on; Pro offline uses `ExerciseVideoDownload.local_path` and `captions_local_paths`; free offline shows `offline_video_requires_pro` inline
- [X] T027 [US6] Update `supabase/functions/video-download-urls/index.ts` per contracts/backend-api.md §5: add signed `captions.en` / `captions.fr` URLs (24 h expiry); `PRO_REQUIRED` (403) for free users
- [X] T028 [US6] Update `mobile/lib/features/library/data/video_download_service.dart`: download MP4 + both `.vtt` files for Pro users only; write `local_path`, `captions_local_paths`, `file_size_bytes`; show progress per exercise
- [X] T029 [P] [US6] Update `mobile/lib/features/library/ui/exercise_detail_screen.dart`: front/side toggle, captions toggle, download button for Pro only

**Checkpoint**: Quickstart Scenario 7 and the free-offline part of Scenario 2 pass.

---

## Phase 4: User Story 1 — Onboarding to First Plan (Priority: P1) 🎯 MVP

**Goal**: A new user passes the disclaimer and consent, picks a language, completes the quiz and gets a valid plan in < 30 s — rule-based for free users, AI for Pro, with a validated fallback that never ends onboarding in an error.

**Independent Test**: Quickstart Scenario 1 — dumbbell-only intermediate user with a `knee` limitation gets `home-dumbbell-3x`-based plan with 4 sessions ≤ 45 min, no barbell or knee-contraindicated exercises; forced AI failure yields `template_fallback` with the notice card.

### Tests for User Story 1 (write first, must fail)

- [X] T030 [P] [US1] Write failing tests `supabase/functions/_shared/template-plan-builder.test.ts` (research §11): selection order — no barbell → `home-dumbbell-3x`; `beginner` → `beginner-full-body-3x`; `intermediate`/`advanced` with goal `muscle` or `strength` → `intermediate-ppl-4x`; otherwise `beginner-full-body-3x`; days 1–2 → first 2 sessions; 3 → 3 sessions; 4 → 4-day template or 3-day + repeat of session A; 5–7 → 4 sessions plus notice `free_plan_days_capped`; each session trimmed from the end to `estimated_duration_min ≤ session_length_min`, keeping ≥ 3 exercises; disallowed or contraindicated exercises substituted; when 3 exercises still exceed the session length, reduce sets (to a minimum of 2 per exercise) and then rest (to a minimum of 60 s) before giving up — a 15-minute session must still produce a valid plan; every `plan_exercise` gets a `suggested_weight_kg` from `starting-weights.ts` (T112); output passes `plan-validator.ts` with `source = 'template'`
- [X] T031 [P] [US1] Write failing tests `supabase/functions/generate-plan/flow.test.ts` with a mocked Claude client (research §12): video-less slug replaced with no extra AI call; validation failure retried at most 2 times (3 attempts); after the 3rd failure → `source = 'template_fallback'`, `fallback_notice = true`; Claude 5xx/timeout/refusal → straight to fallback; `PLAN_VALIDATION_FAILED` and `AI_UNAVAILABLE` are never returned; `CONSENT_REQUIRED` (403) when `users.consent_at` is null; `ACTIVE_PLAN_EXISTS` (409) unless `force_regenerate`; free users never call Claude
- [X] T112 [P] [US1] Write failing tests `supabase/functions/_shared/starting-weights.test.ts` (US1 scenario 3, FR-009): with strength-check answers (estimated working weight × reps for squat, bench press, deadlift), each plan exercise's `suggested_weight_kg` is derived from the matching lift's e1RM scaled to the prescribed rep range at RPE ≤ 7, then mapped to related exercises by a fixed ratio table; with the strength check skipped, conservative defaults by `level` and equipment apply (e.g. barbell beginner = empty bar 20 kg, dumbbell beginner = 4 kg per hand, bodyweight = 0); every value is rounded down to the equipment increment (2.5 kg barbell, 1 kg dumbbell); no value is negative; output never errors on missing answers
- [X] T101 [P] [US1] Create `mobile/test/widget/auth_screen_test.dart` (FR-005): Apple Sign-In (iOS), Google Sign-In and email/password options are present; no "Continue as guest" option unless the spec adds one
- [X] T032 [P] [US1] Create `mobile/test/widget/onboarding_gate_test.dart`: health disclaimer has no skip path; quiz cannot start until consent is accepted; language step defaults to the device locale
- [X] T033 [P] [US1] Create `mobile/test/widget/trial_offer_screen_test.dart` (paywall surface — Constitution V): "Skip for now" always visible and leads to the plan; "Restore purchases" and cancel-anytime text always visible; prices rendered from `storeProduct.priceString`, never hard-coded

### Implementation for User Story 1

- [X] T034 [P] [US1] Update `content/templates/beginner-full-body-3x.json`, `home-dumbbell-3x.json`, `intermediate-ppl-4x.json`: only slugs present in `exercises.json` with a video; accessories ordered last in each session; `level`, `days_per_week`, `equipment_required` metadata at top level
- [X] T035 [US1] Create `content/templates/seed-templates.js`: validate every `exercise_slug` resolves to an exercise with `video_front_url` (fail otherwise — Constitution IV) and upsert into `plan_templates`
- [X] T113 [US1] Create `supabase/functions/_shared/starting-weights.ts` until T112 passes; used by the template builder (T036) and by `generate-plan/flow.ts` (T037) for AI plans that omit weights
- [X] T102 [US1] Verify `mobile/lib/features/auth/data/auth_service.dart` and `mobile/lib/features/auth/ui/auth_screen.dart` until T101 passes: `signInWithApple()`, `signInWithGoogle()`, `signInWithEmail()`, `signUp()`, `signOut()`, `currentUser` stream; session persisted in `flutter_secure_storage`; deep-link redirect `tekto://auth/callback`
- [X] T036 [US1] Create `supabase/functions/_shared/template-plan-builder.ts` until T030 passes
- [X] T037 [US1] Create `supabase/functions/generate-plan/flow.ts` until T031 passes, and update `supabase/functions/generate-plan/index.ts` to call it and return the contracts/backend-api.md §1 response (`start_date`, `source`, `template_slug`, `fallback_notice`, `notices[]`); system prompt filters the library by equipment, video and contraindications (contracts/ai-services.md §1)
- [X] T038 [P] [US1] Create `mobile/lib/features/onboarding/ui/consent_screen.dart`: shown after `health_disclaimer_screen.dart` and before the quiz; explicit health-data consent text version `2026-11-v1`; "I agree" required; saves `users.consent_at` and `consent_version`
- [X] T039 [US1] Update `mobile/lib/features/onboarding/ui/onboarding_quiz_screen.dart`: first step is language (`en | fr`, default device locale, switches app locale immediately); limitations as tags from `knee | lower_back | shoulder | wrist | elbow | hip | ankle | neck` plus optional free-text note; keep goal, level, days 1–7, session 15–120 min, equipment; optional strength-check step collecting a recent working weight (in the user's unit, stored in kg) and reps for `squat`, `bench_press` and `deadlift`, each with an "I don't know" option that leaves that lift out of `strength_estimates` (skipping the whole step stores null)
- [X] T040 [US1] Update `mobile/lib/features/onboarding/domain/onboarding_controller.dart`: save profile including `language`, `limitations_note`, `timezone` (from `flutter_timezone`) and `strength_estimates` (null when the strength check is skipped); call `generate-plan`; pass `fallback_notice` and `notices` to the next screen
- [X] T041 [US1] Update `mobile/lib/features/onboarding/ui/plan_generation_screen.dart`: remove the `AI_UNAVAILABLE` retry path (server always returns a plan); keep a 35 s client timeout with a retry button for network failure only
- [X] T042 [US1] Update `mobile/lib/features/plan/data/plan_repository.dart` and `mobile/lib/features/plan/ui/plan_overview_screen.dart`: store and show `source`, `start_date`, "Week X of Y"; show `plan_fallback_notice` and `free_plan_days_capped` as dismissible cards (never modals — Constitution VI)
- [X] T043 [US1] Update `mobile/lib/features/onboarding/ui/trial_offer_screen.dart` until T033 passes: prices from RevenueCat `priceString`; if `offerings.current` is null, hide purchase buttons and show `pro_unavailable_in_region` with restore still visible
- [X] T044 [US1] Update `mobile/lib/core/router/app_router.dart`: add `/onboarding/consent`; guard so the quiz route requires disclaimer + consent; re-consent when the stored `consent_version` is older than the current one

**Checkpoint**: Quickstart Scenario 1 passes on iOS and Android. This is the MVP increment.

---

## Phase 5: User Story 2 — Daily Workout Execution (Priority: P1)

**Goal**: A full workout runs offline for every user, with video (Pro offline / everyone online), set logging, rest timer, PR detection and summary.

**Independent Test**: Quickstart Scenario 2 — airplane-mode workout logs and syncs; free user offline keeps logging with the video notice.

### Tests for User Story 2 (write first, must fail)

- [ ] T045 [P] [US2] Update `mobile/test/unit/pr_detection_service_test.dart`: e1RM `weight × (1 + reps/30)`; true above stored best, false below; sets with `weight_kg = 0` never count as PRs; zero-reps edge case
- [ ] T046 [P] [US2] Update `mobile/test/integration/offline_sync_test.dart`: log 3 sets offline, reconnect, `SyncQueue.flush()`, assert 3 `set_logs` rows in the local Supabase instance; a row failing 3 times becomes `status = 'failed'` and does not block later rows
- [ ] T047 [P] [US2] Create `mobile/test/widget/live_workout_screen_test.dart`: free user offline can log a set and the rest timer starts automatically with `plan_exercises.rest_sec` (FR-008); weight, reps and optional RPE (1–10, 0.5 steps) can be logged (FR-007); video area shows the inline notice; exactly one primary action visible
- [ ] T103 [P] [US2] Create `mobile/test/widget/home_screen_test.dart` (FR-006, US2 scenario 1): on a training day shows today's session with estimated duration and target muscle groups and a "Start Workout" action; on a rest day shows the rest-day message
- [ ] T106 [P] [US2] Create `mobile/test/unit/health_sync_service_test.dart` (FR-012): writes a strength-training workout on finish only when `users.health_sync_enabled` is true; sets `workout_logs.synced_to_health = true` on success; never blocks finishing a workout when the health API fails

### Implementation for User Story 2

- [ ] T048 [P] [US2] Update `mobile/lib/features/workout/domain/pr_detection_service.dart` until T045 passes
- [ ] T049 [P] [US2] Update `mobile/lib/shared/services/sync/sync_queue.dart` until T046 passes (ordered flush, 3 retries, `failed` status)
- [ ] T050 [US2] Update `mobile/lib/features/workout/ui/live_workout_screen.dart` until T047 passes: cues from the local cache, suggested weight pre-filled from `plan_exercises.suggested_weight_kg`, `RestTimerWidget` after each set
- [ ] T051 [P] [US2] Update `mobile/lib/shared/widgets/set_log_row.dart` to use Flutter's `HapticFeedback` on "Done" and on PR (no third-party haptics package)
- [ ] T104 [US2] Verify `mobile/lib/features/workout/ui/home_screen.dart` until T103 passes
- [ ] T105 [US2] Verify `mobile/lib/features/workout/ui/workout_summary_screen.dart` (US2 scenario 4): total volume in the user's unit, exercises completed, PRs hit, effort rating 1–10; "Finish" calls `WorkoutLogRepository.finishWorkout()` then `HealthSyncService`
- [ ] T107 [US2] Verify `mobile/lib/shared/services/health/health_sync_service.dart` until T106 passes (HealthKit on iOS, Health Connect on Android)

**Checkpoint**: Quickstart Scenario 2 passes (online, airplane mode, free offline).

---

## Phase 6: User Story 7 — Subscription and Paywall (Priority: P1)

**Goal**: Contextual paywalls with store-localized prices that never interrupt a workout; trial, restore and cancel-anytime always available.

**Independent Test**: Quickstart Scenario 6 — free user hits a limit, bottom-sheet paywall during workout, sandbox trial unlocks Pro, € prices in a French storefront.

### Tests for User Story 7 (write first, must fail)

- [ ] T052 [P] [US7] Update `mobile/test/widget/paywall_screen_test.dart`: "Restore purchases" and cancel-anytime always rendered; prices from `priceString`; null offerings → purchase hidden, region message shown, restore still visible
- [ ] T053 [P] [US7] Move `mobile/test/unit/pro_gate_widget_test.dart` to `mobile/test/widget/pro_gate_widget_test.dart` and assert: when `WorkoutController.isWorkoutActive == true` the paywall is a bottom sheet and the workout screen stays visible; otherwise the full paywall opens
- [ ] T054 [P] [US7] Create `mobile/test/unit/entitlement_test.dart`: `isPro` is `tier == 'pro' AND (current_period_ends_at > now() OR (is_trial AND trial_ends_at > now()))`; server `subscriptions.tier` wins over the RevenueCat cache on mismatch
- [ ] T108 [P] [US7] Write failing tests `supabase/functions/revenuecat-webhook/handler.test.ts` per contracts/backend-api.md §6: rejects a wrong `Authorization` secret; `INITIAL_PURCHASE` → `tier = 'pro'`, `is_trial = false`; `RENEWAL` → `current_period_ends_at` updated; `TRIAL_STARTED` → `is_trial = true`, `trial_ends_at` set; `TRIAL_CONVERTED` → `is_trial = false`, `tier = 'pro'`; `CANCELLATION` → `cancelled_at` set, tier unchanged; `EXPIRATION` → `tier = 'free'`, period fields cleared; `BILLING_ISSUE` → logged, no downgrade; replays of the same event are idempotent

### Implementation for User Story 7

- [ ] T055 [US7] Update `mobile/lib/features/subscription/ui/paywall_screen.dart` until T052 passes: remove hard-coded `$12.99` / `$79.99`; annual package selected by default
- [ ] T056 [P] [US7] Update `mobile/lib/shared/widgets/pro_gate_widget.dart` until T053 passes
- [ ] T057 [P] [US7] Update `mobile/lib/features/subscription/domain/entitlement_provider.dart` and `mobile/lib/features/subscription/data/subscription_repository.dart` until T054 passes
- [ ] T109 [US7] Extract `supabase/functions/revenuecat-webhook/handler.ts` and update `revenuecat-webhook/index.ts` until T108 passes; verify `mobile/lib/features/subscription/ui/subscription_settings_screen.dart` shows tier, trial end, period end, "Manage subscription" deep link and "Restore purchases"

**Checkpoint**: Quickstart Scenario 6 passes in the App Store and Play sandboxes.

---

## Phase 7: User Story 4 — Camera Form Check (Priority: P1)

**Goal**: On-device rep counting, live cues and a post-set score with flagged reps for the 8 launch lifts; 1 free try per lift; no frames leave the device.

**Independent Test**: Quickstart Scenario 4 on a physical device — 5 squats with knee cave on reps 2 and 4 → `rep_count = 5`, `flagged_reps = {2,4}`, `user_shared = false`; free try rule holds per lift.

### Tests for User Story 4 (write first, must fail)

- [ ] T058 [P] [US4] Update `mobile/test/unit/rep_counter_test.dart`: exactly 5 clean squat reps counted; a partial rep reversing before the bottom threshold is not counted; one passing case per launch lift key (`squat, deadlift, bench_press, overhead_press, row, lunge, hip_thrust, push_up`)
- [ ] T059 [P] [US4] Update `mobile/test/unit/form_score_calculator_test.dart`: score 100 for zero violations, 0 for all violations; `topTip` is the most frequent cue; `flaggedReps` lists 1-based reps with ≥ 1 cue
- [ ] T060 [P] [US4] Confirm `mobile/test/unit/cue_engine_test.dart`: confidence 0.5 → no cues + `adjust_lighting`; 0.65 → cues returned; never more than 3 cues per frame
- [ ] T061 [P] [US4] Create `mobile/test/unit/form_check_free_try_test.dart`: free user's first try on a lift is allowed, the second on the same lift is blocked, a different lift is allowed once; Pro always allowed; decision made from the local DAO with no network

### Implementation for User Story 4

- [ ] T062 [P] [US4] Update `mobile/lib/shared/services/form_check/rep_counter.dart` and `pose_analyzer.dart` until T058 passes for all 8 lift keys
- [ ] T063 [P] [US4] Update `mobile/lib/shared/services/form_check/form_score_calculator.dart` until T059 passes (`FormSetSummary.flaggedReps`)
- [ ] T064 [P] [US4] Create `mobile/lib/features/form_check/domain/form_check_free_try_service.dart` until T061 passes
- [ ] T065 [US4] Update `mobile/lib/features/form_check/data/form_check_repository.dart`: save `flagged_reps` and `was_free_try` (true for free users); `user_shared` always false unless set by an explicit, confirmed user action; sync via the queue
- [ ] T066 [US4] Update `mobile/lib/features/form_check/ui/form_check_screen.dart`: gate entry through `FormCheckFreeTryService` + `ProGateWidget` (bottom sheet during a workout); keep guided placement and the "Adjust lighting" message
- [ ] T067 [P] [US4] Update `mobile/lib/features/form_check/ui/form_summary_screen.dart` to list flagged reps
- [ ] T068 [US4] Update `mobile/lib/shared/services/form_check/form_check_service.dart`: record per-frame processing delta; log the median at session end in debug builds (Performance Standards < 150 ms); frames stay memory-only

**Checkpoint**: Quickstart Scenario 4 passes on a physical iPhone and Android phone.

---

## Phase 8: User Story 3 — AI Chat Coach (Priority: P2)

**Goal**: Grounded coach answers in the user's language, safe injury handling, a cache that never leaks personalized answers, and confirmable plan changes of all four types.

**Independent Test**: Quickstart Scenario 3 plus Scenario 8 (guardrail eval passes 100 %).

### Tests for User Story 3 (write first, must fail)

- [ ] T069 [P] [US3] Update `mobile/test/unit/coach_quota_service_test.dart`: blocked when `questions_used >= 3` in the current ISO week (`YYYY-Www`); resets on a new ISO week; an `AI_UNAVAILABLE` reply does not consume quota
- [ ] T070 [P] [US3] Write failing tests `supabase/functions/coach-message/logic.test.ts`: EN and FR pain/injury keywords set `injury_flag` and bypass the cache; cache lookup filters by `language` and current `prompt_version` with cosine ≥ 0.92 and unexpired rows; a reply is cached only when `cacheable = true` and `plan_change = null`; quota counted only when a reply is returned; refusal → `AI_UNAVAILABLE`
- [ ] T071 [P] [US3] Write failing tests `supabase/functions/coach-confirm-change/apply.test.ts`: `exercise_swap` (video and equipment/contraindication checks → `EXERCISE_NO_VIDEO`, `EXERCISE_NOT_ALLOWED`); `session_shorten` removes trailing exercises to fit `target_duration_min`, keeping ≥ 3; `deload` sets −40 % (rounded, min 1) and `suggested_weight_kg` −10 % for the target week; `weight_adjustment`; `NO_PENDING_CHANGE` when nothing is pending or already applied; `confirmed: false` records rejection
- [ ] T072 [US3] Create the guardrail eval suite in `supabase/evals/coach-guardrails/`: `cases.json` with ≥ 20 adversarial prompts split across EN and FR (roleplay, "my doctor said it's fine", stepwise pain questions, prompt injection via exercise names); `run.ts` that runs each case through the `coach-message` logic in staging, checks the localized referral sentence, checks no loaded-movement `plan_change` for the painful area, and asks a `claude-haiku-5-5` judge (structured yes/no) whether the reply diagnoses, prescribes treatment or gives a prognosis; writes `results/<date>.json`; exits non-zero below 100 %

### Implementation for User Story 3

- [ ] T073 [US3] Create `supabase/functions/coach-message/logic.ts` until T070 passes, and update `coach-message/index.ts` per contracts/ai-services.md §2: `claude-haiku-5-5`, effort `low`, streaming, structured output `{content, cacheable, plan_change}`, prompt caching with stable prefix, replies in `users.language`, embeddings from `_shared/embeddings.ts`
- [ ] T074 [US3] Create `supabase/functions/coach-confirm-change/apply.ts` until T071 passes, and update `coach-confirm-change/index.ts` to return `{applied, change_type, updated_plan_exercises[]}`
- [ ] T075 [US3] Run `deno task eval:guardrails` against staging until it passes 100 %; commit the results file
- [ ] T076 [US3] Update `mobile/lib/features/coach/domain/coach_quota_service.dart` until T069 passes
- [ ] T077 [US3] Update `mobile/lib/features/coach/ui/coach_screen.dart`: render streamed content as it arrives; show `coach_unavailable` as an inline message (never a spinner) on `AI_UNAVAILABLE`
- [ ] T078 [P] [US3] Update `mobile/lib/features/coach/ui/plan_change_pending_card.dart` to describe all four change types (swap old → new, shortened session length, deload week, new weight/reps)
- [ ] T110 [US3] Verify coach access from any screen (FR-016): a global coach entry point in the app shell opens the slide-up `coach_screen.dart` from every primary screen and passes `context.screen` plus `exercise_slug` / `session_id` when applicable; during a live workout it never covers the primary action (Constitution VI)
- [ ] T111 [P] [US3] Verify `mobile/lib/features/coach/ui/widgets/message_rating_widget.dart` (SC-011): thumbs up/down on each finished assistant message; one rating per message (buttons disable after tap); saves `coach_messages.satisfaction_rating`; never prompted or required

**Checkpoint**: Quickstart Scenarios 3 and 8 pass.

---

## Phase 9: User Story 5 — Adaptive Weekly Plan Updates (Priority: P2)

**Goal**: Pro plans adapt once per training week — after the last session or at Sunday 23:59 local, whichever comes first — with skipped sessions as input and an explanation for every change.

**Independent Test**: Quickstart Scenario 5 Paths A–C, including a second batch run producing no second adaptation.

### Tests for User Story 5 (write first, must fail)

- [ ] T079 [P] [US5] Write failing tests `supabase/functions/_shared/week-boundary.test.ts`: week N spans `start_date + 7·(N−1)` to `+6` (Monday–Sunday); week end is Sunday 23:59 in the user's IANA zone for `Europe/Paris`, `Africa/Abidjan`, `America/New_York`, `Pacific/Auckland`, including a DST-change week; `start_date` is the Monday of the creation week when the plan is created Monday–Wednesday (local), otherwise the next Monday; workouts logged before `start_date` count toward week 1
- [ ] T080 [P] [US5] Update `supabase/functions/_shared/plan-adaptation.test.ts`: (a) progress weight when all reps hit at ≤ RPE target and increment ≤ 10 % e1RM; (b) `reps_max + 1` instead when the increment would exceed 10 % e1RM; (c) 2+ missed sessions → maintain or reduce, never progress; (d) avg RPE > target + 1 → reduce one increment; (e) zero completed sessions; (f) all reps failed — every logged set below `reps_min` → weight reduced one increment or held, never progressed (Constitution V named edge case); every event carries deterministic `reasonEn` / `reasonFr`
- [ ] T081 [P] [US5] Write failing tests `supabase/functions/adapt-plan/handler.test.ts`: claim via `last_adapted_week` is idempotent (second call → `already_adapted: true`, no changes); batch mode adapts only active Pro plans whose week ended and is unadapted, and advances `current_week` for free plans without changing exercises; both `suggested_weight_kg` and `reps_max` events are applied; user mode returns `WEEK_NOT_ENDED` (400) unless every session with that `week_number` has a `workout_logs` row with `finished_at` set or the week boundary has passed and `PRO_REQUIRED` (403) on free plans; explanation model failure falls back to deterministic reasons

### Implementation for User Story 5

- [ ] T082 [P] [US5] Create `supabase/functions/_shared/week-boundary.ts` until T079 passes
- [ ] T083 [P] [US5] Update `supabase/functions/_shared/plan-adaptation.ts` until T080 passes (inputs: sessions scheduled vs completed)
- [ ] T084 [US5] Create `supabase/functions/adapt-plan/handler.ts` until T081 passes, and update `adapt-plan/index.ts` per contracts/backend-api.md §2 (user and batch modes; service-role check for batch; `claude-haiku-5-5` explanations per contracts/ai-services.md §2b; appends to `plans.adaptation_log`)
- [ ] T085 [US5] Update `mobile/lib/features/plan/domain/adaptation_provider.dart`: call `adapt-plan` right after the workout that completes the week is finished — i.e. every session with that `week_number` now has a finished `workout_logs` row (`sessions.scheduled_date` is not used, since it can be null); on app open, fetch and show any summary produced by the batch run
- [ ] T086 [P] [US5] Update `mobile/lib/features/plan/ui/adaptation_summary_screen.dart`: show sessions completed of scheduled and old → new values with reasons
- [ ] T087 [US5] Update `supabase/functions/swap-exercise/index.ts` and `mobile/lib/features/plan/ui/exercise_swap_sheet.dart`: alternatives filtered by same `muscle_primary`, the user's equipment and `contraindications`; server returns `EXERCISE_NO_VIDEO` or `EXERCISE_NOT_ALLOWED` (FR-028)

**Checkpoint**: Quickstart Scenario 5 passes (Paths A, B, C).

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: GDPR, uptime, accessibility, localization, performance and Gate 1 evidence.

- [ ] T088 [P] Create `supabase/functions/health/index.ts` per contracts/backend-api.md §9: no auth, checks DB and a cached (≤ 1 call / 5 min) Anthropic reachability probe; 200 or 503 with the failing component
- [ ] T089 [P] Update `supabase/functions/export-data/index.ts` to the synchronous contract (§7): one JSON file of every user-owned table including consent fields, private bucket, signed 1-hour URL
- [ ] T090 [P] Update `supabase/functions/delete-account/index.ts` to the `DELETE /delete-account` contract (§8): require `{ "confirm": true }`, delete the RevenueCat customer, delete export files, delete `auth.users` (cascade)
- [ ] T091 Update `mobile/lib/features/settings/ui/settings_screen.dart`: language toggle EN/FR saved to `users.language` and applied immediately (FR-033); unit toggle kg/lb saved to `users.unit` and used by every weight display and input (FR-034); health sync toggle saved to `users.health_sync_enabled`; "Regenerate my plan" (`force_regenerate: true`, confirm dialog); refresh `users.timezone` when the device zone changes; export shows the download link; delete account uses a two-step confirmation, then calls `AppDatabase.wipe()` and returns to the welcome screen
- [ ] T092 Configure an external uptime monitor on `GET /health` every 60 s with alerts; record the monitor URL in `specs/001-tekto-ai-mvp/checklists/gate1.md`
- [ ] T093 [P] Accessibility pass on all primary screens: `Semantics` labels, Dynamic Type up to the largest size without clipping, tap targets ≥ 48×48 dp, VoiceOver and TalkBack walkthrough (FR-035, Constitution VI)
- [ ] T094 [P] Localization audit of `app_en.arb` / `app_fr.arb`: no hard-coded user-facing strings in `mobile/lib/`; French copy reviewed by a native speaker
- [ ] T095 Performance run on iPhone 12 and Pixel 6 — cold start < 2 s, video first frame < 1 s (LTE profile), form-check median < 150 ms, coach first token < 3 s p95 (≥ 50 staging messages), plan generation < 30 s — and record results in `specs/001-tekto-ai-mvp/checklists/gate1.md`
- [ ] T096 Privacy audit per quickstart Scenario 9 steps 1–2 (encrypted local DB, zero network bytes during form check); record results in `checklists/gate1.md`
- [ ] T097 Add rows for quickstart Scenarios 8 and 9 to `specs/001-tekto-ai-mvp/checklists/gate1.md`, then run Scenarios 1–9 on iOS 16 and Android 10 and record pass/fail for each
- [ ] T098 [P] Create App Store and Google Play listings (EN + FR): title "Tekto — Build Your Strength", short and full descriptions, 6 screenshots per platform (onboarding, plan, workout, library, coach, form check), privacy policy URL, health-data disclosures

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → no dependencies
- **Foundational (Phase 2)** → depends on Phase 1; blocks every story
- **US6 (Phase 3)** → Phase 2. T022 (content volume) is an external dependency; development can proceed with the current 15 exercises
- **US1 (Phase 4)** → Phase 2 + seeded exercises (T024) for template validation
- **US2 (Phase 5)** → US1 (needs an active plan)
- **US7 (Phase 6)** → Phase 2; parallel with US2
- **US4 (Phase 7)** → Phase 2 + US7 (`ProGateWidget`)
- **US3 (Phase 8)** → Phase 2 + US7 (quota needs subscription state)
- **US5 (Phase 9)** → US2 (workout logs) + US7 (Pro gate); T087 reuses `exercise-substitution.ts` (T014)
- **Polish (Phase 10)** → all stories; T092 needs T088

### Story Independence

| Story | Can start after | Depends on |
|---|---|---|
| US6 Video Library | Phase 2 | — |
| US1 Onboarding/Plan | Phase 2 + T024 | Seeded exercises |
| US2 Workout | US1 | Active plan |
| US7 Subscription | Phase 2 | — |
| US4 Form Check | US7 | Pro gate |
| US3 Coach | US7 | Subscription state |
| US5 Adaptation | US2 + US7 | Workout logs, Pro gate |

### Within Each Story

Tests → make them fail → implementation → tests pass → story checkpoint (quickstart scenario).

---

## Parallel Examples

### Phase 2

```
# After T006–T008 (migrations, sequential):
T009 types.ts · T010 claude.ts · T011 embeddings.ts · T012 substitution tests · T013 validator tests
T017 DAOs · T018 Freezed models · T019 ARB keys
# Then: T014 → T015 (shared logic), T016 (encrypted DB)
```

### User Story 1

```
T030 builder tests · T031 flow tests · T032 onboarding gate test · T033 trial offer test · T034 templates
# Then: T035 seed → T036 builder → T037 generate-plan; in parallel T038 consent screen
```

### User Story 4

```
T058 · T059 · T060 · T061 (tests)
# Then: T062 · T063 · T064 (in parallel) → T065 → T066 → T067 · T068
```

### User Story 5

```
T079 · T080 · T081 (tests)
# Then: T082 · T083 (in parallel) → T084 → T085 · T086 → T087
```

---

## Implementation Strategy

### MVP first (US6 + US1)

1. Phases 1–2 (setup, migrations, shared logic, encrypted DB).
2. Phase 3 US6 → Phase 4 US1.
3. **Stop and validate** quickstart Scenario 1 and Scenario 7: a new user gets a valid, personalized plan in < 30 s, every exercise has a captioned video.

### P1 launch scope

4. US2 (workout) and US7 (subscription) in parallel → US4 (form check, required at launch per Clarification Q5).
5. Internal beta with all P1 stories.

### P2 additions

6. US3 (coach, including the guardrail eval) and US5 (adaptation) in parallel.
7. Phase 10 → Gate 1 checklist complete → public beta.

### Parallel team (if staffed)

- Dev A: US6 → US1 → US2
- Dev B: US7 → US4
- Dev C: shared backend (T009–T015) → US3 → US5
- Content: T022 + T023 from day one (longest lead time)

---

## Notes

- **Total tasks**: 114 (T001–T098, plus T099–T114 added by remediation and placed inside their phases).
- Additional test-first pairs from remediation: starting weights (T112 → T113), RevenueCat webhook (T108 → T109), auth screen (T101 → T102), home screen (T103 → T104), health sync (T106 → T107).
- Every Principle V unit has its test task before its implementation: `PlanAdaptationService` (T080 → T083), `FormScoreCalculator` (T059 → T063), `RepCounter` (T058 → T062), `CoachQuotaService` (T069 → T076), subscription gates (T053/T054 → T056/T057), plus `ExerciseSubstitution` (T012 → T014), `PlanValidator` (T013 → T015), `TemplatePlanBuilder` (T030 → T036), generate-plan flow (T031 → T037), week boundary (T079 → T082), free try (T061 → T064).
- Paywall widget tests: `PaywallScreen` (T052), `TrialOfferScreen` (T033), in-workout bottom sheet (T053).
- Constitution IV (Video Gate) enforced in T013/T015, T024, T035, T037, T071/T074, T087.
- Constitution III: T031/T037 (fallback flow), T072/T075 (guardrail eval), T032 (unskippable disclaimer).
- Constitution II: T016 (SQLCipher), T038 (consent), T065 (`user_shared`), T070 (no personalized cache), T096 (privacy audit).
- Use branch `001-tekto-ai-mvp`; commit after each task or logical group.
