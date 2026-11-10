# Contract: AI Services

**Branch**: `001-tekto-ai-mvp` | **Date**: 2026-11-09 (revised 2026-11-10)
**Research**: [research.md](../research.md)

> **Revision 2026-11-10**: models moved to `claude-sonnet-5-5` / `claude-haiku-5-5` with structured outputs; plan-failure flow per FR-003b (substitute → ≤ 2 retries → template fallback); coach output gains `cacheable` and fields for every change type; embeddings via Supabase `gte-small`; form summary gains `flaggedReps`; paywall prices come from the store.

This document defines the internal interface contracts between Supabase Edge Functions and the external AI services (Anthropic Claude API for plan generation and coaching, and the on-device ML Kit pose estimation for form check). These are not user-facing APIs; they are integration contracts for the backend and mobile teams.

---

## 1. Plan Generation — Claude API Contract

### Function: `generate-plan` Edge Function → Anthropic Claude

**Model**: `claude-sonnet-5-5` (Pro users only; free users never reach this contract)

**Request settings**:
- `thinking: { type: "adaptive" }`, `output_config: { effort: "high", format: <JSON schema below> }` — structured outputs replace free-form JSON and prefill.
- Streaming with `finalMessage()` (long output); `max_tokens` ≈ 64000.
- Refusal fallback: beta `server-side-fallback-2026-07-01`, `fallbacks: "default"`. Check `stop_reason` before reading content; `refusal` or `max_tokens` counts as a failed attempt.
- Per-attempt timeout chosen so that attempts + fallback fit inside the 30 s budget (SC-002).

**System prompt structure** (sent with each plan generation request):

```
You are Tekto's training plan generator. You create science-based, periodized strength training programs.

USER PROFILE:
- Goal: {goal}
- Level: {level}
- Days per week: {days_per_week}
- Session length: {session_length_min} minutes
- Equipment: {equipment_list}
- Limitations: {limitations_list or "none"}
- Language preference: {language}

AVAILABLE EXERCISES:
{exercise_library_subset_json}
(Only exercises matching the user's equipment, with a video, and not contraindicated by the user's limitations are included)

RULES (non-negotiable):
1. Every exercise in the plan MUST be from the AVAILABLE EXERCISES list above.
2. Total weekly volume per muscle group: beginner 10–14 sets, intermediate 14–18 sets, advanced 16–22 sets.
3. Each session MUST have at least one rest day before the next session in the same week.
4. Warm-up and cool-down sets are not counted toward working sets.
5. Progressive overload: plan weeks must show increasing load OR reps OR intensity across the program.
6. Include RPE targets only for intermediate/advanced users.
7. Output must match the JSON schema below (enforced by structured outputs).
```

**Expected output schema** (Claude must return valid JSON matching this):

```json
{
  "plan": {
    "name_en": "string",
    "name_fr": "string",
    "weeks_total": "integer (4-12)",
    "rationale_en": "string (1-2 sentences explaining why this plan fits the user)",
    "rationale_fr": "string",
    "sessions": [
      {
        "week_number": "integer",
        "day_number": "integer (1-7)",
        "name_en": "string",
        "name_fr": "string",
        "target_muscles": ["string"],
        "estimated_duration_min": "integer",
        "exercises": [
          {
            "exercise_slug": "string (must match available exercise slugs)",
            "sets": "integer",
            "reps_min": "integer",
            "reps_max": "integer",
            "rest_sec": "integer",
            "rpe_target": "number | null",
            "notes_en": "string | null",
            "notes_fr": "string | null"
          }
        ]
      }
    ]
  }
}
```

**Post-generation pipeline** (FR-003b; research §12). One validator (`plan-validator.ts`) serves AI and template plans; the volume rule applies to AI plans only.

| Step | Rule | Action on fail |
|---|---|---|
| 1. Substitute | Slug unknown, has no video, needs unavailable equipment, or is contraindicated | Replace via `exercise-substitution.ts` (same primary muscle, available equipment, has video). No AI call. If no substitute exists, the slug becomes a validation error. |
| 2. Validate | Volume per muscle within level bounds (AI only) | Retry |
| | Rest days: no two consecutive days training the same muscle group | Retry |
| | Duration: `estimated_duration_min` ≤ `session_length_min + 10` | Retry |
| | `weeks_total` between 4 and 12 | Retry |
| 3. Retry | Up to **2 retries** (3 attempts total), each with the retry prompt | After the 3rd failed attempt → step 4 |
| 4. Fallback | Build the rule-based template plan (research §11) | Save with `source = 'template_fallback'`, return `fallback_notice: true` |

`AI_UNAVAILABLE` (5xx, timeout, refusal on every fallback model) skips straight to step 4.

**Retry prompt** (appended on each validation failure):
```
Your previous response had these issues: {validation_errors_list}
Please regenerate the plan correcting these issues. All other rules still apply.
```

---

## 2. AI Coach — Claude API Contract

### Function: `coach-message` Edge Function → Anthropic Claude

**Model**: `claude-haiku-5-5`

**Request settings**:
- `output_config: { effort: "low", format: <coach output schema below> }` — set effort explicitly (Haiku 5.5 defaults to `medium`); low keeps first token under 3 s.
- Streaming; the app renders `content` as it arrives.
- Prompt caching: system prompt + user context before the breakpoint; recent history and the new question after it.
- Check `stop_reason`; a `refusal` returns `AI_UNAVAILABLE` (Haiku 5.5 has no server-side fallback).
- `claude.ts` logs `ttft_ms`, `total_ms`, tokens and cache-read tokens for every call (research §13).

**Pre-filter** (deterministic, before the model call): a bilingual keyword list (e.g. *pain, hurts, injury, sprain, numb, chest pain, dizzy / douleur, mal, blessure, entorse, engourdi, vertige*) sets `injury_flag = true`. When set, the system prompt adds an explicit instruction to lead with the professional-referral sentence, and the message bypasses the semantic cache.

**System prompt structure**:

```
You are Tekto's AI strength coach. You help users understand their training program, improve technique, and stay consistent.

USER CONTEXT:
- Name: {display_name}
- Goal: {goal}
- Level: {level}
- Language: {language} (always reply in this language)
- Current week: {current_week} of {weeks_total}

CURRENT PLAN SUMMARY:
{plan_summary_json}
(Today's session, this week's exercises, recent PRs)

RECENT TRAINING HISTORY (last 2 weeks):
{recent_logs_summary}

SCREEN CONTEXT: {screen} {optional: "viewing exercise: {exercise_name}"}

RULES:
1. Always reply in {language}.
2. Keep replies under 150 words unless a detailed explanation is explicitly requested.
3. If the user mentions pain, injury, or medical symptoms, respond: "I'm not a medical professional — please see a doctor or physiotherapist for pain or injury concerns. I can suggest gentler exercise alternatives in the meantime." Do NOT diagnose.
4. If the user asks to change their plan, propose the change as JSON in the `plan_change` field (see output schema). Never apply changes silently.
5. Ground all answers in the user's actual plan and history. Do not invent exercises or loads.
6. Be encouraging but honest. Do not over-promise results.
7. Set "cacheable" to true ONLY if your answer is general training knowledge that would be identical for any user (it uses none of the profile, plan, history or screen context above). Otherwise false.
8. Only suggest replacement exercises from ALLOWED ALTERNATIVES (exercises with video that match the user's equipment and limitations).

OUTPUT FORMAT (JSON, enforced by structured outputs):
{
  "content": "string (the reply to show the user)",
  "cacheable": "boolean",
  "plan_change": {
    "type": "exercise_swap | session_shorten | deload | weight_adjustment",
    "plan_exercise_id": "uuid | null      (exercise_swap, weight_adjustment)",
    "session_id": "uuid | null            (session_shorten)",
    "week_number": "integer | null        (deload)",
    "target_duration_min": "integer | null (session_shorten)",
    "old_exercise_slug": "string | null",
    "new_exercise_slug": "string | null",
    "new_weight_kg": "number | null",
    "new_reps_min": "integer | null",
    "new_reps_max": "integer | null",
    "reason_en": "string",
    "reason_fr": "string"
  } | null
}
```

**Conversation history** passed as Claude `messages[]` array (last 10 turns):
```json
[
  { "role": "user", "content": "Why is the Romanian deadlift in my program?" },
  { "role": "assistant", "content": "{ \"content\": \"...\", \"plan_change\": null }" }
]
```

**Semantic cache** (Supabase `pgvector`; research §8):
- Skip entirely when `injury_flag = true`.
- Embed the user message with the Edge Runtime built-in model: `new Supabase.ai.Session('gte-small')`, `{ mean_pool: true, normalize: true }` → 384-d vector.
- Query `coach_response_cache` filtered by `language` and current `prompt_version`, cosine similarity ≥ 0.92, not expired.
- Cache hit: return cached `response_content` with `plan_change: null`.
- Cache miss: call Claude; store the reply **only if** `cacheable = true` and `plan_change = null`.
- TTL: 7 days; purge on `prompt_version` change.

**Guardrail eval** (Constitution III; research §14): `supabase/evals/coach-guardrails/` must pass 100 % before any release that changes this system prompt or the model ID.

---

## 2b. Adaptation Explanations — Claude API Contract

**Function**: `adapt-plan` → Anthropic Claude. **Model**: `claude-haiku-5-5`, effort `low`, structured output `{ "reasons": [{ "plan_exercise_id", "reason_en", "reason_fr" }], "summary_en", "summary_fr" }`.

Input: the `AdaptationEvent[]` computed by `PlanAdaptationService` (the model only words them; it never decides changes). On any failure, the deterministic `reasonEn` / `reasonFr` from the service are used.

---

## 3. On-Device Pose Estimation — Mobile Contract

### Library: Google ML Kit Pose Detection (Flutter)

**Interface**: `PoseDetector` from `google_mlkit_pose_detection` package, integrated into `FormCheckService` in the Flutter app.

#### Input
```dart
// Called per camera frame in the workout screen
PoseDetectorInput {
  InputImage inputImage;  // from camera plugin CameraImage
  PoseDetectionMode mode; // PoseDetectionMode.stream (real-time)
}
```

#### Output (per frame)
```dart
PoseFrame {
  List<Pose> poses;        // 0 or 1 pose detected
  double confidence;       // 0.0–1.0; suppress cues below 0.6
  int frameTimestampMs;
}
```

#### PoseAnalyzer contract (internal service)

```dart
abstract class PoseAnalyzer {
  /// Processes a pose frame and returns form state for the given lift.
  FormFrameResult analyze(Pose pose, String liftKey);
}

class FormFrameResult {
  final List<FormCue> activeCues;   // cues to display this frame (max 3)
  final bool repDetected;            // true when a rep threshold is crossed
  final double jointAngleSnapshot;   // primary angle for rep detection
}

class FormCue {
  final String key;           // e.g. 'knees_caving', 'back_rounding'
  final String textEn;
  final String textFr;
  final CueSeverity severity; // warning | error
}
```

#### RepCounter state machine

```
State: NEUTRAL
  → DESCENDING  when primary angle decreases past start threshold
  → (ignore)

State: DESCENDING
  → BOTTOM      when primary angle ≤ bottom threshold AND depth criterion met
  → NEUTRAL     if angle reverses early (no-rep)

State: BOTTOM
  → ASCENDING   when primary angle increases past bottom threshold

State: ASCENDING
  → NEUTRAL     when primary angle ≥ start threshold → REP COUNTED
```

#### FormScoreCalculator contract

```dart
class FormScoreCalculator {
  /// Called at end of set with all frame results.
  /// Returns score 0–100 and the single most impactful tip.
  FormSetSummary calculate(List<FormFrameResult> frames, String liftKey, String language);
}

class FormSetSummary {
  final int score;            // 0–100
  final List<String> cuesShown;
  final List<int> flaggedReps; // 1-based reps with ≥ 1 cue (FR-024)
  final String topTipEn;
  final String topTipFr;
  final int repCount;
}
```

#### Free-try gate
```dart
// Before opening the camera for a free user:
bool canStart = isPro || !formCheckDao.hasFreeTry(userId, liftKey);
// On session save for a free user: was_free_try = true.
// If !canStart → ProGate shows the paywall as a bottom sheet (never interrupts the workout).
```

#### Confidence gating rule
```
if (pose.confidence < 0.6) {
  → suppress all cues
  → show UI message: "Adjust lighting or phone position for better tracking"
  → continue rep counting (best-effort)
}
```

#### Privacy rule
```
// CameraImage bytes are NEVER written to disk or transmitted over the network.
// Only FormSetSummary fields are persisted (to FormCheckSession).
// The camera stream is memory-only during the session.
```

---

## 4. Subscription Entitlement — RevenueCat Contract

### Mobile SDK (`purchases_flutter`)

#### Initialization
```dart
await Purchases.configure(
  PurchasesConfiguration('<REVENUECAT_API_KEY_IOS or ANDROID>')
    ..appUserID = supabaseUser.id,  // use Supabase user UUID as RevenueCat customer ID
);
```

#### Entitlement check (called on app start + foreground)
```dart
CustomerInfo info = await Purchases.getCustomerInfo();
bool isPro = info.entitlements.active.containsKey('pro');
```

#### Purchase flow
```dart
// Fetch offerings
Offerings offerings = await Purchases.getOfferings();
Package monthlyPackage = offerings.current!.monthly!;
Package annualPackage = offerings.current!.annual!;

// Display prices from the store — never hard-coded (FR-032)
String monthlyPrice = monthlyPackage.storeProduct.priceString; // regional, localized
String annualPrice  = annualPackage.storeProduct.priceString;
// If offerings.current is null (product not available in this storefront), hide purchase
// buttons and show "Pro is not yet available in your region" — restore stays visible.

// Purchase
CustomerInfo result = await Purchases.purchasePackage(monthlyPackage);
bool isPro = result.entitlements.active.containsKey('pro');
```

#### Restore purchases
```dart
CustomerInfo restored = await Purchases.restorePurchases();
```

#### Webhook → Supabase sync
RevenueCat sends events to `POST /revenuecat-webhook` (see backend-api.md §6).
The Edge Function updates the `subscriptions` table, which is the server-side source of truth for free-tier enforcement.

#### Free-tier limit enforcement
- Mobile: optimistic check via `isPro` flag from RevenueCat SDK.
- Server: `coach-message` Edge Function reads `subscriptions.tier` from DB (authoritative).
- Mismatch (e.g., trial expired but mobile cache stale): server returns `QUOTA_EXCEEDED`; mobile refreshes entitlements.
