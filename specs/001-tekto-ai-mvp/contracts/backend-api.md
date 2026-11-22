# Contract: Backend API (Supabase Edge Functions)

**Branch**: `001-tekto-ai-mvp` | **Date**: 2026-11-09 (revised 2026-11-10)
**Research**: [research.md](../research.md) | **Data Model**: [data-model.md](../data-model.md)

> **Revision 2026-11-10**: `generate-plan` gains `source` / `fallback_notice` and never returns `PLAN_VALIDATION_FAILED`; `adapt-plan` drops `WEEK_NOT_COMPLETE` and adds a cron batch mode; `coach-confirm-change` covers all change types; `video-download-urls` returns caption URLs; `export-data` is synchronous; deletion path aligned to `/delete-account`; new `GET /health`.

All Edge Functions are deployed to `https://<project>.supabase.co/functions/v1/`.
All requests require `Authorization: Bearer <supabase_anon_or_user_jwt>`.
All responses are `Content-Type: application/json`.
Errors follow the shape `{ "error": { "code": string, "message": string } }`.

---

## 1. Plan Generation

### `POST /generate-plan`

Generates a personalized training plan from the authenticated user's profile.
- **Free tier**: rule-based plan from `plan_templates` (research §11). No AI call.
- **Pro**: AI plan via `claude-sonnet-5-5`; on repeated validation failure or AI outage, a validated template plan with `fallback_notice: true` (research §12).
- **Pro, plan library** (FR-047, 2026-11-21): with `program_slug`, the chosen program from `plan_templates` (rows with a `catalog` block) is fitted to the user (substitution, session trimming, volume cap, starting weights) and validated; no AI call. Response `source: "template"`, `template_slug` = the program.

**Auth**: Required (user JWT). Called at onboarding and from Settings → "Regenerate my plan" (`force_regenerate: true`, e.g. after an equipment change).

**Request body**:
```json
{
  "force_regenerate": false
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `force_regenerate` | bool | No | If `true`, archives the current active plan and creates a new one |
| `program_slug` | string | No | Plan library program to start (Pro). Send with `force_regenerate: true` when a plan is active. Errors: `402 PRO_REQUIRED` (free user), `404 PROGRAM_NOT_FOUND` (not a library program), `422 PROGRAM_NOT_SUITABLE` with `details: [string]` (cannot be fitted; the active plan is unchanged) |

**Response `201 Created`**:
```json
{
  "plan": {
    "id": "uuid",
    "name_en": "12-Week Strength Builder",
    "name_fr": "Programme Force 12 Semaines",
    "weeks_total": 12,
    "current_week": 1,
    "start_date": "2026-11-09",
    "source": "ai",
    "template_slug": null,
    "fallback_notice": false,
    "rationale_en": "A 4-day upper/lower split that fits your 45-minute sessions…",
    "rationale_fr": "Un split haut/bas sur 4 jours adapté à vos séances de 45 minutes…",
    "notices": [],
    "sessions": [
      {
        "id": "uuid",
        "week_number": 1,
        "day_number": 1,
        "name_en": "Upper A",
        "name_fr": "Haut A",
        "target_muscles": ["chest", "shoulders", "triceps"],
        "estimated_duration_min": 55,
        "exercises": [
          {
            "plan_exercise_id": "uuid",
            "exercise": {
              "id": "uuid",
              "slug": "barbell-bench-press",
              "name_en": "Barbell Bench Press",
              "name_fr": "Développé couché à la barre",
              "video_front_url": "https://customer-xxx.cloudflarestream.com/abc123/manifest/video.m3u8",
              "muscle_primary": ["chest"],
              "form_check_supported": true,
              "form_check_lift_key": "bench_press"
            },
            "sets": 4,
            "reps_min": 6,
            "reps_max": 8,
            "rest_sec": 180,
            "rpe_target": 8.0,
            "suggested_weight_kg": 60.0
          }
        ]
      }
    ]
  }
}
```

| Response field | Values | Meaning |
|---|---|---|
| `source` | `ai \| template \| template_fallback` | How the plan was built |
| `rationale_en` / `rationale_fr` | string | Why the plan fits (FR-044): from the model for `ai`, from the template JSON for `template` and `template_fallback` |
| `fallback_notice` | bool | `true` only for `template_fallback`; the app shows "We built you a starter plan — you can regenerate it later in Settings" |
| `notices` | string[] | Localization keys for non-blocking cards, e.g. `free_plan_days_capped` when 5–7 days were requested on the free tier |

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `PROFILE_INCOMPLETE` | 400 | User profile missing required fields |
| `CONSENT_REQUIRED` | 403 | `users.consent_at` is null |
| `ACTIVE_PLAN_EXISTS` | 409 | Active plan exists and `force_regenerate` is false |

`AI_UNAVAILABLE` and validation failures are **not** returned: both produce a `template_fallback` plan (FR-003b). Onboarding always ends with a valid plan.

---

## 2. Plan Adaptation

### `POST /adapt-plan`

Reviews one training week (Monday–Sunday in `users.timezone`) and adjusts the following week's `plan_exercises`. Pro plans only. Idempotent per `(plan_id, week)` via `plans.last_adapted_week`: a repeat call returns the stored summary with `already_adapted: true`.

**Triggers** (whichever comes first — FR-026):
1. **User mode** — mobile calls it when every session with that `week_number` has a finished workout log. Auth: user JWT.
2. **Batch mode** — `pg_cron` job (hourly) calls it with the service-role key and `{ "mode": "batch" }`; the function finds every active Pro plan whose week has ended and is not yet adapted. Batch mode also advances `current_week` for free plans.

**Request body (user mode)**:
```json
{
  "plan_id": "uuid",
  "completed_week": 3
}
```

**Request body (batch mode, service role only)**:
```json
{ "mode": "batch" }
```

**Response `200 OK`**:
```json
{
  "adaptations": [
    {
      "plan_exercise_id": "uuid",
      "field_changed": "suggested_weight_kg",
      "old_value": 60.0,
      "new_value": 62.5,
      "reason_en": "You hit all reps at RPE 7.5 — ready to progress.",
      "reason_fr": "Vous avez atteint tous vos reps à RPE 7,5 — prêt à progresser."
    }
  ],
  "sessions_scheduled": 4,
  "sessions_completed": 2,
  "already_adapted": false,
  "summary_en": "Great week! 3 of 4 exercises progressed.",
  "summary_fr": "Super semaine ! 3 exercices sur 4 ont progressé."
}
```

`field_changed` is `suggested_weight_kg` or `reps_max`; both are applied. Skipped sessions are counted in `sessions_completed` and drive the maintain/reduce rules; they never block the review.

Batch-mode response: `{ "processed": 12, "adapted": 9, "advanced_only": 3 }`.

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `WEEK_NOT_ENDED` | 400 | User mode called while a session of that week has no finished workout log and the week boundary has not passed |
| `PRO_REQUIRED` | 403 | User mode on a free plan |
| `PLAN_NOT_FOUND` | 404 | |

If the explanation model is unavailable, deterministic reason strings are used; adaptation still applies.

---

## 3. AI Chat Coach

### `POST /coach-message`

Sends a user message to the AI coach and returns the assistant reply.

**Auth**: Required (user JWT).

**Request body**:
```json
{
  "conversation_id": "uuid",
  "message": "Why is the Romanian deadlift in my program this week?",
  "context": {
    "screen": "exercise_detail",
    "exercise_slug": "romanian-deadlift",
    "session_id": "uuid"
  }
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `conversation_id` | uuid | Yes | Created by the app; the server creates the row on first use. Must not belong to another user |
| `message` | string | Yes | Max 2000 chars |
| `context.screen` | string | No | Current screen identifier |
| `context.exercise_slug` | string | No | Exercise being viewed |
| `context.session_id` | uuid | No | Session being viewed |

**Response `200 OK`** — streamed as server-sent events (`Content-Type: text/event-stream`), so the app shows the reply as it is written (ai-services.md §2, first text < 3 s):

```
event: text
data: {"text":"The Romanian deadlift targets"}

event: text
data: {"text":" your hamstrings and glutes..."}

event: done
data: {"message_id":"uuid","plan_change_proposed":null,"quota_remaining":1}
```

| Event | Data | Notes |
|---|---|---|
| `text` | `{"text": string}` | A piece of the reply; append in order. A cache hit arrives as one `text` event |
| `done` | `{"message_id", "plan_change_proposed", "quota_remaining"}` | Last event of a successful reply. `quota_remaining` is null for Pro users |
| `error` | `{"error": "AI_UNAVAILABLE"}` | The model failed after text started; discard the partial text and show the "Coach temporarily unavailable" message. No quota is consumed |

`plan_change_proposed`, when present, follows ai-services.md §2, e.g.:
```json
{
  "type": "exercise_swap",
  "plan_exercise_id": "uuid",
  "old_exercise_slug": "barbell-back-squat",
  "new_exercise_slug": "leg-press",
  "reason_en": "Knee-friendly alternative targeting the same muscles.",
  "reason_fr": "Alternative sans contrainte pour le genou ciblant les mêmes muscles."
}
```

**Errors** (plain JSON `{"error": code}` with the HTTP status, returned before any event is sent):
| Code | HTTP | Meaning |
|---|---|---|
| `QUOTA_EXCEEDED` | 429 | Free user hit 3 questions/week limit; checked before any cache lookup or model call |
| `CONVERSATION_NOT_FOUND` | 404 | `conversation_id` belongs to another user |
| `MESSAGE_TOO_LONG` | 400 | Message exceeds 2000 chars |
| `AI_UNAVAILABLE` | 503 | LLM down or refused before any text was sent; app shows the localized "Coach temporarily unavailable" message (never a spinner). Does **not** consume free quota. After text has started, the same failure arrives as an `error` event |

Replies are in `users.language`. Free quota is consumed only when a reply is returned (including cache hits).

---

### `POST /coach-confirm-change`

Confirms or rejects a proposed plan modification from the coach.

**Auth**: Required (user JWT).

**Request body**:
```json
{
  "message_id": "uuid",
  "confirmed": true
}
```

**Response `200 OK`**:
```json
{
  "applied": true,
  "change_type": "exercise_swap",
  "updated_plan_exercises": [
    { "plan_exercise_id": "uuid", "exercise": { "...": "..." }, "sets": 3, "suggested_weight_kg": 50.0 }
  ]
}
```

**Supported change types** (FR-018) and how each is applied:

| `type` | Applied as |
|---|---|
| `exercise_swap` | Replace `exercise_id`; replacement must have a video and fit equipment + limitations |
| `session_shorten` | Remove trailing exercises from the target session until it fits `target_duration_min` (min 3 exercises) |
| `deload` | For the target week: sets −40 % (rounded, min 1), `suggested_weight_kg` −10 % |
| `weight_adjustment` | Set `suggested_weight_kg` / `reps_min` / `reps_max` on one plan exercise |

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `NO_PENDING_CHANGE` | 400 | Message has no `plan_change_proposed`, or it was already applied |
| `EXERCISE_NO_VIDEO` | 400 | Swap target has no video (Constitution IV) |
| `EXERCISE_NOT_ALLOWED` | 400 | Swap target needs unavailable equipment or is contraindicated |
| `EXERCISE_NOT_EQUIVALENT` | 400 | Swap target does not train the same primary muscle (same rule as §4) |
| `INVALID_CHANGE` | 400 | The proposal is missing fields for its type, or sets an invalid weight / rep range |
| `PLAN_TARGET_NOT_FOUND` | 404 | The plan exercise, session or week is not in the user's active plan |
| `MESSAGE_NOT_FOUND` | 404 | Unknown message, or one from another user's conversation |

`confirmed: false` records the rejection and returns `{ "applied": false }`. The rejection is stored in `coach_messages.plan_change_rejected_at` (migration 011); an applied or rejected change returns `NO_PENDING_CHANGE` afterwards. `session_shorten` also returns `removed_plan_exercise_ids`.

---

## 4. Exercise Swap

### `POST /swap-exercise`

Swaps a `plan_exercise` for an equivalent alternative selected by the user (from the library or coach suggestion).

**Auth**: Required (user JWT). Available to free and Pro users; never returns `PRO_REQUIRED` (FR-028).

**Request body**:
```json
{
  "plan_exercise_id": "uuid",
  "new_exercise_id": "uuid"
}
```
`new_exercise_slug` (string) may be sent instead of `new_exercise_id`; the app caches exercises by slug.

**Response `200 OK`**:
```json
{
  "plan_exercise_id": "uuid",
  "new_exercise": { "id": "uuid", "slug": "...", "name_en": "...", "name_fr": "..." }
}
```

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `INVALID_REQUEST` | 400 | Missing `plan_exercise_id` or `new_exercise_id` |
| `EXERCISE_NO_VIDEO` | 400 | Replacement exercise has no video (Constitution IV) |
| `EXERCISE_NOT_ALLOWED` | 400 | Replacement needs equipment the user lacks or is contraindicated by their limitations |
| `EXERCISE_NOT_EQUIVALENT` | 400 | Replacement shares no primary muscle with the current exercise |
| `PLAN_NOT_ACTIVE` | 400 | The plan exercise belongs to an archived or completed plan |
| `FORBIDDEN` | 403 | The plan exercise belongs to another user |
| `EXERCISE_NOT_FOUND` | 404 | |
| `PLAN_EXERCISE_NOT_FOUND` | 404 | |

---

## 5. Video Download URLs

### `POST /video-download-urls`

Returns time-limited signed Cloudflare Stream download URLs for all exercises in the user's active plan. Pro only.

**Auth**: Required (user JWT, Pro entitlement).

**Request body**:
```json
{
  "plan_id": "uuid"
}
```

**Response `200 OK`**:
```json
{
  "downloads": [
    {
      "exercise_id": "uuid",
      "slug": "barbell-back-squat",
      "download_url_front": "https://customer-xxx.cloudflarestream.com/abc/downloads/default.mp4?token=...",
      "download_url_side": "https://customer-xxx.cloudflarestream.com/def/downloads/default.mp4?token=...",
      "captions": {
        "en": "https://customer-xxx.cloudflarestream.com/abc/captions/en.vtt?token=...",
        "fr": "https://customer-xxx.cloudflarestream.com/abc/captions/fr.vtt?token=..."
      },
      "expires_at": "2026-11-10T14:00:00Z"
    }
  ]
}
```

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `PRO_REQUIRED` | 403 | User is on free tier |
| `PLAN_NOT_FOUND` | 404 | |

---

## 6. Subscription Webhook (RevenueCat)

### `POST /revenuecat-webhook`

Receives RevenueCat event webhooks and updates the `subscriptions` table.

**Auth**: Shared secret in `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>` header.

**Handled event types**:

RevenueCat reports a trial start as `INITIAL_PURCHASE` with `period_type = "TRIAL"` and a trial conversion as `RENEWAL` with `is_trial_conversion = true`. `TRIAL_STARTED` and `TRIAL_CONVERTED` are accepted as aliases. Rules live in `revenuecat-webhook/handler.ts`; every event computes the next row from the current one, so replays are idempotent.

| Event | Action |
|---|---|
| `INITIAL_PURCHASE` (`period_type` ≠ `TRIAL`) | Upsert `tier = 'pro'`, `is_trial = false`, `current_period_ends_at = expiration_at_ms`, `cancelled_at = null` |
| `INITIAL_PURCHASE` (`period_type = TRIAL`) / `TRIAL_STARTED` | Upsert `tier = 'pro'`, `is_trial = true`, `trial_ends_at = current_period_ends_at = expiration_at_ms` |
| `RENEWAL` | Update `current_period_ends_at`; clear `cancelled_at` |
| `RENEWAL` (`is_trial_conversion = true`) / `TRIAL_CONVERTED` | Also `is_trial = false`, `trial_ends_at = null` |
| `CANCELLATION` | Set `cancelled_at = event_timestamp_ms`; keep `tier` until `EXPIRATION` |
| `UNCANCELLATION` | Clear `cancelled_at` |
| `EXPIRATION` | Set `tier = 'free'`, clear `is_trial`, period, trial and cancellation fields |
| `BILLING_ISSUE` | Log; do not downgrade (grace period) |
| Any other type, or an update event for a user with no row | Acknowledged (`200`), no write |

`revenuecat_customer_id` is the event's `original_app_user_id` (never the event `id`). A storage error returns `500` so RevenueCat retries.

**Response `200 OK`**: `{ "received": true }`

---

## 7. GDPR: Data Export

### `POST /export-data`

Generates a full JSON export of the authenticated user's data.

**Auth**: Required (user JWT).

**Response `200 OK`** (synchronous; MVP data volumes per user are small):
```json
{
  "job_id": "uuid",
  "download_url": "https://<project>.supabase.co/storage/v1/object/sign/exports/<user_id>/<job_id>.json?token=...",
  "expires_at": "2026-11-10T15:00:00Z"
}
```

The export is a single JSON file covering every user-owned table (including `coach_messages` content and consent records), stored in a private bucket and signed for 1 hour.

---

## 8. GDPR: Account Deletion

### `DELETE /delete-account`

Permanently deletes the authenticated user's account and all associated data.

**Auth**: Required (user JWT).

**Request body**:
```json
{
  "confirm": true
}
```

**Response `200 OK`**:
```json
{
  "deleted": true
}
```

**Note**: Cascades to all user data via `ON DELETE CASCADE` foreign keys. RevenueCat customer record is also deleted via RevenueCat REST API. Export files for the user are deleted from storage. The app then wipes the local encrypted database and its key.

---

## 9. Health Probe

### `GET /health`

Used by the external uptime monitor (SC-013). No auth; returns no user data.

**Response `200 OK`**:
```json
{ "status": "ok", "db": "ok", "ai": "ok", "checked_at": "2026-11-10T14:00:00Z" }
```

Returns `503` with the failing component (`"db": "down"` or `"ai": "degraded"`) otherwise. The AI check is a cached reachability probe (at most one real call per 5 minutes), not a model call per request.


## 10. Support chat (FR-054, 2026-11-21)

### `POST /support-message`

Stores the user's message in their open support thread (created if none) and returns the AI assistant's instant reply, unless the thread is waiting for a person.

**Request**: `{ "body": "string (1–2000)", "want_human": false }`

**Response `201`**: `{ "thread_id": "uuid", "status": "open | waiting_agent", "messages": [{ "id", "sender": "user|ai", "body", "created_at" }] }`

- `want_human: true`, or an assistant reply that cannot help, sets `status = waiting_agent`; the assistant then says a person will answer, and no further AI replies are sent until staff close or reopen the thread.
- Staff reply by inserting `sender = 'agent'` rows with the service role (support console); the app receives them through Realtime on `support_messages`.
- Errors: `400 INVALID_BODY`, `401`, `429 RATE_LIMITED` (more than 20 messages an hour).

## 11. Friends (FR-049, FR-050)

Plain PostgREST calls with RLS, plus RPCs: `friend_feed`, `friend_leaderboard`, `weekly_scores`, `add_friend_by_username(username)`, `accept_invite(invite_code)` (see data-model.md, migration 016).
