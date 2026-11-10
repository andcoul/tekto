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
1. **User mode** — mobile calls it after the last scheduled session of the week is logged. Auth: user JWT.
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
| `WEEK_NOT_ENDED` | 400 | User mode called before the last scheduled session is logged and before the week boundary |
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
| `conversation_id` | uuid | Yes | Must belong to the authenticated user |
| `message` | string | Yes | Max 2000 chars |
| `context.screen` | string | No | Current screen identifier |
| `context.exercise_slug` | string | No | Exercise being viewed |
| `context.session_id` | uuid | No | Session being viewed |

**Response `200 OK`**:
```json
{
  "message_id": "uuid",
  "content": "The Romanian deadlift targets your hamstrings and glutes...",
  "plan_change_proposed": null,
  "quota_remaining": null
}
```

When a plan change is proposed:
```json
{
  "message_id": "uuid",
  "content": "Sure, I can swap squats for leg press given your knee discomfort. Here's what would change:",
  "plan_change_proposed": {
    "type": "exercise_swap",
    "plan_exercise_id": "uuid",
    "old_exercise_slug": "barbell-back-squat",
    "new_exercise_slug": "leg-press",
    "reason_en": "Knee-friendly alternative targeting the same muscles.",
    "reason_fr": "Alternative sans contrainte pour le genou ciblant les mêmes muscles."
  },
  "quota_remaining": null
}
```

For free-tier users (quota tracked):
```json
{
  "message_id": "uuid",
  "content": "...",
  "plan_change_proposed": null,
  "quota_remaining": 1
}
```

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `QUOTA_EXCEEDED` | 429 | Free user hit 3 questions/week limit |
| `CONVERSATION_NOT_FOUND` | 404 | |
| `MESSAGE_TOO_LONG` | 400 | Message exceeds 2000 chars |
| `AI_UNAVAILABLE` | 503 | LLM temporarily down or refused; app shows the localized "Coach temporarily unavailable" message (never a spinner). Does **not** consume free quota. |

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
| `MESSAGE_NOT_FOUND` | 404 | |

`confirmed: false` records the rejection and returns `{ "applied": false }`.

---

## 4. Exercise Swap

### `POST /swap-exercise`

Swaps a `plan_exercise` for an equivalent alternative selected by the user (from the library or coach suggestion).

**Auth**: Required (user JWT).

**Request body**:
```json
{
  "plan_exercise_id": "uuid",
  "new_exercise_id": "uuid"
}
```

**Response `200 OK`**:
```json
{
  "plan_exercise_id": "uuid",
  "new_exercise": { "id": "uuid", "slug": "...", "name_en": "..." }
}
```

**Errors**:
| Code | HTTP | Meaning |
|---|---|---|
| `EXERCISE_NO_VIDEO` | 400 | Replacement exercise has no video |
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

| Event | Action |
|---|---|
| `INITIAL_PURCHASE` | Set `tier = 'pro'`, `is_trial = false` |
| `RENEWAL` | Update `current_period_ends_at` |
| `TRIAL_STARTED` | Set `is_trial = true`, `trial_ends_at` |
| `TRIAL_CONVERTED` | Set `is_trial = false`, `tier = 'pro'` |
| `CANCELLATION` | Set `cancelled_at`; keep tier until period ends |
| `EXPIRATION` | Set `tier = 'free'`, clear period fields |
| `BILLING_ISSUE` | Log; do not immediately downgrade (grace period) |

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
