# Data Model: Tekto AI MVP

**Branch**: `001-tekto-ai-mvp` | **Date**: 2026-11-09 (revised 2026-11-10)
**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

> **Revision 2026-11-10** — added: `users.timezone`, `consent_at`, `consent_version`; `exercises.contraindications`, caption URLs; `plans.source`, `template_slug`, `start_date`, `last_adapted_week`; `form_check_sessions.flagged_reps`; `exercise_video_downloads.captions_local_paths`; system tables `coach_response_cache` and `plan_templates`; local-only `sync_queue`. Fixed: `set_logs.weight_kg` allows 0 for bodyweight. Delivered by migration `005_clarifications.sql`.

---

## Overview

Tekto's data model has two layers:

1. **Remote (Supabase PostgreSQL)** — authoritative source for all user data, plans, logs, subscriptions. Row Level Security (RLS) ensures users only access their own rows.
2. **Local (Drift / SQLite on-device, encrypted with SQLCipher)** — mirrors the remote for offline-first operation. Synced on connectivity; writes queue locally and flush when online.

Exercise library metadata and videos are read-only content assets; they are managed by the `content/` pipeline and are not user data.

---

## Entities

### 1. User (`users`)

Extends Supabase Auth `auth.users`. Stores application-level profile data.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK, FK → auth.users.id | Supabase Auth user ID |
| `display_name` | text | NOT NULL | Shown in UI |
| `goal` | enum | NOT NULL | `muscle \| strength \| fat_loss \| general_fitness` |
| `level` | enum | NOT NULL | `beginner \| intermediate \| advanced` |
| `days_per_week` | int | 1–7, NOT NULL | Training days per week |
| `session_length_min` | int | 15–120, NOT NULL | Target session duration |
| `equipment` | text[] | NOT NULL | `['barbell','dumbbell','cable','bodyweight','bands']` subset |
| `limitations` | text[] | nullable | Tags from a fixed vocabulary: `knee \| lower_back \| shoulder \| wrist \| elbow \| hip \| ankle \| neck` |
| `limitations_note` | text | nullable | Optional free text; shown to the coach, not used for filtering |
| `strength_estimates` | jsonb | nullable | Optional strength check: `{ "squat": {"weight_kg", "reps"}, "bench_press": {…}, "deadlift": {…} }`; null when skipped (conservative defaults apply) |
| `language` | enum | NOT NULL, default `en` | `en \| fr`; chosen at onboarding (defaults to device locale) |
| `unit` | enum | NOT NULL, default `kg` | `kg \| lb` |
| `timezone` | text | NOT NULL, default `'UTC'` | IANA zone from the device at onboarding; updated on change. Drives the training-week boundary. |
| `health_sync_enabled` | bool | default false | Apple Health / Google Health Connect |
| `consent_at` | timestamptz | NOT NULL after onboarding | When the user gave explicit consent to health-data processing (GDPR Art. 9) |
| `consent_version` | text | NOT NULL after onboarding | Version of the consent text accepted, e.g. `2026-11-v1` |
| `onboarding_completed_at` | timestamptz | nullable | Set when first plan is generated |
| `created_at` | timestamptz | NOT NULL, default now() | |
| `updated_at` | timestamptz | NOT NULL | Auto-updated |

**Validation rules**:
- `days_per_week` must be between 1 and 7.
- `goal` + `level` + `equipment` combination must resolve to at least one valid exercise set.
- `generate-plan` returns `CONSENT_REQUIRED` if `consent_at` is null.
- A new `consent_version` requires re-consent on next app open.

---

### 2. Exercise (`exercises`)

Master library of all filmed exercises. Read-only for users; managed by content pipeline.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `slug` | text | UNIQUE, NOT NULL | URL-safe identifier, e.g. `barbell-back-squat` |
| `name_en` | text | NOT NULL | English name |
| `name_fr` | text | NOT NULL | French name |
| `equipment` | text[] | NOT NULL | Equipment required |
| `muscle_primary` | text[] | NOT NULL | Primary muscles targeted |
| `muscle_secondary` | text[] | nullable | Secondary muscles |
| `cues_en` | text[] | NOT NULL | 3–5 technique cues (English) |
| `cues_fr` | text[] | NOT NULL | 3–5 technique cues (French) |
| `common_mistakes_en` | text[] | NOT NULL | |
| `common_mistakes_fr` | text[] | NOT NULL | |
| `video_front_url` | text | NOT NULL | Cloudflare Stream URL (front angle) |
| `video_side_url` | text | nullable | Side angle video |
| `video_duration_sec` | int | NOT NULL | 5–15 |
| `captions_en_url` | text | NOT NULL | WebVTT caption track (English) |
| `captions_fr_url` | text | NOT NULL | WebVTT caption track (French) |
| `contraindications` | text[] | NOT NULL, default `{}` | Limitation tags (same vocabulary as `users.limitations`) for which this exercise is excluded from plans |
| `variation_easier_id` | uuid | FK → exercises.id, nullable | |
| `variation_harder_id` | uuid | FK → exercises.id, nullable | |
| `form_check_supported` | bool | NOT NULL, default false | Whether pose estimation is calibrated for this lift |
| `form_check_lift_key` | text | nullable | Key used by PoseAnalyzer (e.g. `squat`, `deadlift`) |
| `created_at` | timestamptz | NOT NULL | |

**Validation rules**:
- Every exercise referenced in any `plan_exercise` row must have `video_front_url` populated.
- Every exercise must have EN and FR captions (seeding fails otherwise — Constitution VI).
- `form_check_lift_key` must be set if `form_check_supported = true`; the 8 launch lift keys are `squat, deadlift, bench_press, overhead_press, row, lunge, hip_thrust, push_up`.
- Plans never include an exercise whose `contraindications` overlap the user's `limitations`.

---

### 3. Plan (`plans`)

A complete 4–12 week training program belonging to a user. A user may have multiple plans over time, but only one `active` plan at a time.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, NOT NULL | RLS: user can only see own plans |
| `status` | enum | NOT NULL | `active \| completed \| archived` |
| `name_en` | text | NOT NULL | e.g. "12-Week Strength Builder" |
| `name_fr` | text | NOT NULL | |
| `goal` | enum | NOT NULL | Snapshot of user goal at generation time |
| `level` | enum | NOT NULL | |
| `weeks_total` | int | 4–12, NOT NULL | |
| `current_week` | int | 1–weeks_total, NOT NULL, default 1 | Advanced at each training-week boundary for all plans |
| `start_date` | date | NOT NULL | Monday of the week the plan started, in `users.timezone`. Week N = `start_date + 7·(N−1)` … `+6`. |
| `last_adapted_week` | int | NOT NULL, default 0 | Highest week already adapted; makes `adapt-plan` idempotent |
| `source` | enum | NOT NULL | `ai \| template \| template_fallback` |
| `template_slug` | text | nullable | Set when `source` is `template` or `template_fallback` |
| `generation_prompt_hash` | text | nullable | For dedup / debugging |
| `adaptation_log` | jsonb | nullable | Array of adaptation events `[{week, sessions_scheduled, sessions_completed, changes, summary_en, summary_fr}]` |
| `created_at` | timestamptz | NOT NULL | |
| `updated_at` | timestamptz | NOT NULL | |

**State transitions**:
```
(none) → active       [plan generation completes — any source]
active → completed    [final week boundary passes]
active → archived     [user regenerates (force_regenerate); old plan archived]
completed → archived  [manual archive]
```

**Validation rules**:
- A user may have at most one plan with `status = 'active'` at any time (UNIQUE partial index).
- `weeks_total` must be between 4 and 12.
- `last_adapted_week ≤ current_week`.
- `template_slug` is non-null iff `source` ≠ `ai`.

---

### 4. Session (`sessions`)

A single training day within a plan.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `plan_id` | uuid | FK → plans.id, NOT NULL | |
| `week_number` | int | 1–12, NOT NULL | |
| `day_number` | int | 1–7, NOT NULL | Day within the week |
| `name_en` | text | NOT NULL | e.g. "Upper A", "Lower Push" |
| `name_fr` | text | NOT NULL | |
| `target_muscles` | text[] | NOT NULL | For home screen display |
| `estimated_duration_min` | int | NOT NULL | |
| `scheduled_date` | date | nullable | Null until user confirms/schedules |
| `created_at` | timestamptz | NOT NULL | |

---

### 5. PlanExercise (`plan_exercises`)

An ordered exercise slot within a session, with prescribed sets/reps/rest/RPE.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `session_id` | uuid | FK → sessions.id, NOT NULL | |
| `exercise_id` | uuid | FK → exercises.id, NOT NULL | Must have a video |
| `order_index` | int | NOT NULL | 0-based display order |
| `sets` | int | 1–10, NOT NULL | |
| `reps_min` | int | NOT NULL | Lower bound of rep range |
| `reps_max` | int | NOT NULL | Upper bound |
| `rest_sec` | int | NOT NULL | Recommended rest in seconds |
| `rpe_target` | numeric(3,1) | 1.0–10.0, nullable | Target perceived exertion |
| `rir_target` | int | 0–5, nullable | Target reps-in-reserve |
| `suggested_weight_kg` | numeric(5,2) | nullable | Pre-filled from history or estimate |
| `notes_en` | text | nullable | Technique reminder for this slot |
| `notes_fr` | text | nullable | |

**Validation rules**:
- `reps_min ≤ reps_max`.
- Exactly one of `rpe_target` or `rir_target` should be set (or neither for beginner plans).
- `exercise_id` must reference an exercise with a non-null `video_front_url`.

---

### 6. WorkoutLog (`workout_logs`)

Records a user's execution of a session.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, NOT NULL | RLS |
| `session_id` | uuid | FK → sessions.id, NOT NULL | |
| `plan_id` | uuid | FK → plans.id, NOT NULL | Denormalized for analytics |
| `started_at` | timestamptz | NOT NULL | |
| `finished_at` | timestamptz | nullable | Null if workout abandoned |
| `effort_rating` | int | 1–10, nullable | Post-workout RPE rating |
| `notes` | text | nullable | Optional user note |
| `synced_to_health` | bool | default false | Whether synced to Apple Health / Health Connect |
| `created_at` | timestamptz | NOT NULL | |

**State**: A `WorkoutLog` with `finished_at = null` is "in progress". Only one in-progress log per user at a time.

---

### 7. SetLog (`set_logs`)

One logged set within a workout.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `workout_log_id` | uuid | FK → workout_logs.id, NOT NULL | |
| `plan_exercise_id` | uuid | FK → plan_exercises.id, NOT NULL | |
| `set_number` | int | NOT NULL | 1-based |
| `weight_kg` | numeric(6,2) | NOT NULL | Stored always in kg; displayed in user's unit preference |
| `reps` | int | NOT NULL | |
| `rpe_actual` | numeric(3,1) | nullable | Actual perceived exertion |
| `is_pr` | bool | NOT NULL, default false | Computed at log time |
| `logged_at` | timestamptz | NOT NULL | |

**Computed fields** (not stored):
- `e1rm`: Epley formula `weight × (1 + reps/30)` — computed on read for analytics.

**Validation rules**:
- `weight_kg ≥ 0` (bodyweight exercises use `0.0`; the previous `> 0` rule contradicted this and must be corrected in migration 005).
- `reps ≥ 1`.
- PR detection ignores sets with `weight_kg = 0` (e1RM is undefined for unloaded sets).

---

### 8. PersonalRecord (`personal_records`)

Denormalized cache of a user's best set per exercise for fast PR detection.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | uuid | PK component, FK → users.id | |
| `exercise_id` | uuid | PK component, FK → exercises.id | |
| `best_weight_kg` | numeric(6,2) | NOT NULL | |
| `best_reps_at_weight` | int | NOT NULL | |
| `best_e1rm` | numeric(6,2) | NOT NULL | |
| `achieved_at` | timestamptz | NOT NULL | |
| `set_log_id` | uuid | FK → set_logs.id | Source set |

**Update rule**: Updated by a database trigger on `set_logs` insert when the new `e1rm` exceeds the stored best.

---

### 9. CoachConversation (`coach_conversations`)

A thread of AI coach messages for a user. One active conversation per user; archived when a new plan is generated.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, NOT NULL | RLS |
| `plan_id` | uuid | FK → plans.id, nullable | Plan in context at conversation start |
| `status` | enum | NOT NULL | `active \| archived` |
| `created_at` | timestamptz | NOT NULL | |

---

### 10. CoachMessage (`coach_messages`)

A single turn in a coach conversation.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `conversation_id` | uuid | FK → coach_conversations.id, NOT NULL | |
| `role` | enum | NOT NULL | `user \| assistant` |
| `content` | text | NOT NULL | Message text |
| `context_screen` | text | nullable | e.g. `workout`, `exercise_detail`, `plan_overview` |
| `context_session_id` | uuid | FK → sessions.id, nullable | Session in view when asked |
| `plan_change_proposed` | jsonb | nullable | Proposed change awaiting confirmation |
| `plan_change_applied` | bool | default false | Whether the change was confirmed and applied |
| `satisfaction_rating` | bool | nullable | Thumbs up/down; null if not rated |
| `created_at` | timestamptz | NOT NULL | |

**Validation rule**: `plan_change_applied` can only be `true` if `plan_change_proposed` is non-null.

---

### 11. CoachQuotaUsage (`coach_quota_usage`)

Tracks free-tier coach question consumption per user per ISO week.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | uuid | PK component, FK → users.id | |
| `iso_week` | text | PK component | Format `YYYY-Www`, e.g. `2026-W45` |
| `questions_used` | int | NOT NULL, default 0 | Incremented on each `user` message |

**Rule**: Free-tier users blocked when `questions_used ≥ 3` for the current ISO week.

---

### 12. FormCheckSession (`form_check_sessions`)

Records one camera form check session. All processing is on-device; only the summary is stored remotely.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, NOT NULL | RLS |
| `workout_log_id` | uuid | FK → workout_logs.id, nullable | |
| `set_log_id` | uuid | FK → set_logs.id, nullable | Linked after set completion |
| `exercise_id` | uuid | FK → exercises.id, NOT NULL | |
| `lift_key` | text | NOT NULL | e.g. `squat` |
| `rep_count` | int | NOT NULL | Reps detected |
| `flagged_reps` | int[] | NOT NULL, default `{}` | 1-based rep numbers with at least one form cue (FR-024) |
| `form_score` | int | 0–100, NOT NULL | |
| `cues_shown` | text[] | NOT NULL | Cues displayed during the set |
| `top_tip_en` | text | NOT NULL | Post-set improvement tip |
| `top_tip_fr` | text | NOT NULL | |
| `was_free_try` | bool | NOT NULL, default false | True when run by a free user under the 1-try-per-lift allowance |
| `user_shared` | bool | NOT NULL, default false | Whether user chose to share footage |
| `created_at` | timestamptz | NOT NULL | |

**Privacy rule**: No video frames are stored server-side. `user_shared` = false means zero footage was transmitted.

**Free-try rule (FR-029)**: a free user may start a form check for a `lift_key` only if no `form_check_sessions` row exists for that user and `lift_key` with `was_free_try = true`. Checked on device against the local mirror (works offline) and re-checked server-side on sync; no separate table is needed.

---

### 13. Subscription (`subscriptions`)

Tracks the user's current subscription state, synced from RevenueCat webhooks.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | uuid | PK, FK → users.id | One row per user |
| `tier` | enum | NOT NULL, default `free` | `free \| pro` |
| `store` | enum | nullable | `app_store \| google_play` |
| `revenuecat_customer_id` | text | nullable | RevenueCat customer ID |
| `product_id` | text | nullable | Store product identifier |
| `is_trial` | bool | NOT NULL, default false | Currently in 7-day trial |
| `trial_started_at` | timestamptz | nullable | |
| `trial_ends_at` | timestamptz | nullable | |
| `current_period_ends_at` | timestamptz | nullable | Null for free tier |
| `cancelled_at` | timestamptz | nullable | Set when user cancels; access continues until period end |
| `updated_at` | timestamptz | NOT NULL | |

**Rule**: `tier = 'pro'` when `current_period_ends_at > now()` OR `is_trial = true AND trial_ends_at > now()`.

---

### 14. ExerciseVideoDownload (`exercise_video_downloads`)

Tracks which exercises a Pro user has downloaded for offline use.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | uuid | PK component, FK → users.id | |
| `exercise_id` | uuid | PK component, FK → exercises.id | |
| `local_path` | text | NOT NULL | On-device file path |
| `captions_local_paths` | jsonb | NOT NULL | `{ "en": "<path>", "fr": "<path>" }` |
| `downloaded_at` | timestamptz | NOT NULL | |
| `file_size_bytes` | int | NOT NULL | |

**Rule**: rows are created only for Pro users (Constitution I v2.0.0). On downgrade to free, downloaded files are kept but not played offline until the user is Pro again.

---

### 15. CoachResponseCache (`coach_response_cache`) — system table

Semantic cache of generic coach answers. Not user data; no `user_id`.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | uuid | PK | |
| `language` | enum | NOT NULL | `en \| fr`; lookups filter by language |
| `embedding` | vector(384) | NOT NULL | `gte-small` embedding of the question |
| `question_hash` | text | UNIQUE, NOT NULL | Hash of normalized question + language |
| `response_content` | text | NOT NULL | Generic answer |
| `prompt_version` | text | NOT NULL | Coach system-prompt version; cache purged when it changes |
| `created_at` | timestamptz | NOT NULL | |
| `expires_at` | timestamptz | NOT NULL | `created_at + 7 days` |

**Rules**: only answers with `cacheable = true` and `plan_change = null` are inserted; messages flagged by the pain/injury pre-filter are never cached. Not readable by clients (service role only).

---

### 16. PlanTemplate (`plan_templates`) — content table

Starter templates for free-tier plans and the Pro fallback. Seeded from `content/templates/` by `seed-templates.js`.

| Field | Type | Constraints | Notes |
|---|---|---|---|
| `slug` | text | PK | e.g. `home-dumbbell-3x` |
| `level` | enum | NOT NULL | Target level |
| `days_per_week` | int | NOT NULL | 3 or 4 at launch |
| `equipment_required` | text[] | NOT NULL | Minimum equipment set |
| `body` | jsonb | NOT NULL | Same schema as the `generate-plan` plan body (weeks, sessions, exercises with `exercise_slug`) |
| `updated_at` | timestamptz | NOT NULL | |

**Rules**: seeding fails if any `exercise_slug` lacks a video (Constitution IV). Read-only to clients.

---

### Local-only: SyncQueue (`sync_queue`, Drift only)

| Field | Type | Notes |
|---|---|---|
| `id` | int | Autoincrement; flush order |
| `operation` | text | `insert \| update \| delete` |
| `table_name` | text | Target remote table |
| `payload` | text (JSON) | Row data |
| `created_at` | datetime | |
| `retry_count` | int | Max 3, then `failed` for manual review |
| `status` | text | `pending \| failed` |

---

## Entity Relationships

```
users ─────────────────────────────────────────────┐
  │                                                 │
  ├── plans (1:many)                                │
  │     └── sessions (1:many per plan)              │
  │           └── plan_exercises (1:many per session)│
  │                 └── exercises (many:1)           │
  │                                                 │
  ├── workout_logs (1:many)                         │
  │     └── set_logs (1:many per log)               │
  │           └── plan_exercises (many:1)           │
  │                                                 │
  ├── personal_records (1:many, one per exercise)   │
  ├── coach_conversations (1:many)                  │
  │     └── coach_messages (1:many per conversation)│
  ├── coach_quota_usage (1:many, one per week)      │
  ├── form_check_sessions (1:many)                  │
  ├── subscriptions (1:1)                           │
  └── exercise_video_downloads (1:many)             │
                                                    │
exercises ──────────────────────────────────────────┘
  (read-only master library; no user FK on exercises itself)

plan_templates ── referenced by plans.template_slug (content, read-only)
coach_response_cache ── standalone system table (no user FK)
```

---

## Offline Sync Strategy

**Drift (SQLite, SQLCipher-encrypted) mirrors**: `plans`, `sessions`, `plan_exercises`, `exercises` (text fields for every exercise in the active plan, for **all** users — Constitution I), `workout_logs`, `set_logs`, `personal_records`, `form_check_sessions` (summaries, for the free-try check), `subscriptions`, `coach_quota_usage`.

**Write queue**: Any write that occurs offline is appended to a `sync_queue` local table with `{operation, table, payload, created_at}`. On connectivity restore, the queue is flushed in order to Supabase REST API.

**Conflict resolution**: Last-write-wins for `workout_logs` and `set_logs` (append-only); plans are always read from server when online.

**Local-only tables** (never synced): `form_check_sessions` frames buffer (transient), `exercise_video_downloads` (local file paths).

---

## Privacy & GDPR

- Explicit consent to health-data processing is captured at onboarding (`users.consent_at`, `consent_version`) after the health disclaimer and before the first plan.
- On-device data is encrypted at rest with SQLCipher; the key lives in the OS keystore via `flutter_secure_storage`.
- All user rows are protected by Supabase RLS policies: `auth.uid() = user_id`.
- Data export: Edge Function generates a JSON archive of all user rows and returns a download URL.
- Account deletion: Edge Function deletes the `auth.users` row (cascades to all user data via FK ON DELETE CASCADE).
- Form check: no video bytes stored remotely; `user_shared = false` is auditable.
- `coach_messages.content` is PII; included in export; purged on deletion.
