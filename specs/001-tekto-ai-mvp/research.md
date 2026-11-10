# Research: Tekto AI MVP

**Branch**: `001-tekto-ai-mvp` | **Date**: 2026-11-09 (revised 2026-11-10)
**Status**: Complete — all NEEDS CLARIFICATION resolved. §2 updated; §8–§15 added after spec clarifications (Session 2026-11-10) and constitution v2.0.0.

---

## 1. Cross-Platform Mobile Framework

### Decision
**Flutter (Dart 3 / Flutter 3.x)**

### Rationale
- Single codebase compiles to native ARM for both iOS 16+ and Android 10+ — matches the PRD's "one cross-platform codebase" requirement.
- Skia/Impeller rendering engine runs fully on-device, enabling 60/120 fps premium animations and custom dark-theme UI without depending on platform widgets.
- Camera plugin (`camera`) and MediaPipe Flutter plugin give direct access to the frame pipeline needed for <150 ms/frame pose estimation.
- `video_player` + `chewie` handle looped offline video playback with HLS support.
- `drift` (SQLite ORM) is mature, type-safe, and well-suited to the relational workout/plan schema needed for offline-first operation.
- Strong in-app purchase ecosystem: `purchases_flutter` (RevenueCat SDK) is the de-facto standard.
- `flutter_health_fit` / `health` package covers both Apple HealthKit and Google Health Connect.
- Large, stable community; backed by Google; actively used by Strava, eBay, BMW.

### Alternatives Considered
| Framework | Verdict | Reason Rejected |
|---|---|---|
| React Native (TypeScript) | Runner-up | JS bridge adds latency for real-time camera ML workloads; Hermes engine adds overhead on Android; premium custom UI harder to achieve |
| Expo (managed RN) | No | Too many native module restrictions for camera ML and HealthKit deep integration |
| Swift/Kotlin native | No | Doubles the codebase; violates "one cross-platform codebase" PRD requirement |
| Capacitor/Ionic | No | Web-based rendering; cannot hit the premium feel or ML frame-rate targets |

### Recommended Flutter Project Structure
```
mobile/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── theme/            # Dark/light theme tokens
│   │   ├── router/           # go_router navigation
│   │   ├── di/               # Riverpod providers
│   │   └── l10n/             # ARB files (en, fr)
│   ├── features/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── plan/
│   │   ├── workout/
│   │   ├── library/
│   │   ├── coach/
│   │   ├── form_check/
│   │   └── subscription/
│   └── shared/
│       ├── models/           # Dart data classes (freezed)
│       ├── services/         # API client, local DB, health
│       └── widgets/          # Shared UI components
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── android/
├── ios/
└── pubspec.yaml
```

### Key Flutter Libraries
| Purpose | Library |
|---|---|
| State management | `riverpod` (flutter_riverpod) |
| Navigation | `go_router` |
| Local database | `drift` (SQLite ORM, code-gen) |
| HTTP client | `dio` + `retrofit` |
| Data classes | `freezed` + `json_serializable` |
| Camera / ML frames | `camera` + `google_mlkit_pose_detection` |
| Video playback | `video_player` + `chewie` |
| In-app purchases | `purchases_flutter` (RevenueCat) |
| Health sync | `health` (HealthKit + Health Connect) |
| Localization | `flutter_localizations` + ARB |
| Secure storage | `flutter_secure_storage` |
| Offline sync | `drift` + custom sync service |

---

## 2. LLM Stack (AI Coach + Plan Generator)

### Decision
**Anthropic Claude API — tiered model usage (current generation, revised 2026-11-10)**
- Pro plan generation: `claude-sonnet-5-5` — adaptive thinking, effort `high`, structured outputs (`output_config.format`) for the plan JSON, streaming (long output), server-side refusal fallback `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`).
- Chat coach and adaptation explanations: `claude-haiku-5-5` — effort `low` (latency target < 3 s first token), streaming, structured outputs for `{content, plan_change, cacheable}`.
- Free-tier plans: **no model call** (rule-based builder, §11).
- Safety guardrails: prompt rules + deterministic pre-filter for pain/injury language + guardrail eval suite (§14).

Previous IDs (`claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) are replaced; `supabase/functions/_shared/claude.ts` constants must change.

### API notes that shape the contracts
- Forced `tool_choice` (`any` / `tool`) returns 400 on `claude-sonnet-5-5`, so plan JSON uses structured outputs, not a forced tool.
- Assistant prefill is rejected; JSON shape comes from `output_config.format`.
- Effort defaults differ per model (Haiku 5.5 defaults to `medium`), so set it explicitly on every request.
- Always check `stop_reason` (including `refusal`) before reading content. Haiku 5.5 has no server-side fallback: a coach refusal returns the localized "temporarily unavailable / rephrase" message.

### Rationale
- Claude has demonstrated strong reasoning for science-based program design (periodization, RPE, volume management).
- Haiku 5.5 at low effort keeps coach replies fast and is very cheap, which matters for free-tier economics.
- Sonnet 5.5 provides the depth needed for 4–12 week periodized plans; structured outputs remove JSON-parse retries.
- Native multilingual support covers English and French.
- Claude's safety behaviour supports the guardrail requirement (no diagnosis, injury routing); it is backed by our own pre-filter and eval suite rather than relied on alone.

### LLM Cost Model (per active Pro user/month, list prices as of 2026-11)
Prices: Sonnet 5.5 $2 / $10 per MTok input/output (cache reads $0.10); Haiku 5.5 $0.10 / $0.50 per MTok for prompts up to 100K tokens.

| Operation | Model | Est. tokens | Calls/month | $/month |
|---|---|---|---|---|
| Plan generation | Sonnet 5.5 | ~8 k input + ~4 k output (+ thinking) | 1 | ~$0.06–0.10 |
| Chat coach | Haiku 5.5 | ~3 k input + 0.5 k output | 30 avg | ~$0.02 |
| Adaptation explanations | Haiku 5.5 | ~2 k input + 0.5 k output | 4 | < $0.01 |
| **Total per Pro user** | | | | **~$0.08–0.13** |

Free users cost almost nothing in AI: no plan call, ≤ 3 coach questions per week (~$0.01/month).

> **Prompt caching**: the system prompt + user profile + plan summary (~2,000 tokens) is stable across a conversation. Put it before the cache breakpoint and keep timestamps and the user's question after it. Verify with `usage.cache_read_input_tokens`. Haiku 5.5's minimum cacheable prefix may exceed a short system prompt; measure before relying on it.

### Semantic Caching
Common generic questions (e.g., "what does RPE mean?", "how do I do a Romanian deadlift?") are cached with embedding similarity via `pgvector` on Supabase. Cache hit avoids an LLM call entirely; target >40% hit rate for free-tier coach questions. Only answers the model marks `cacheable: true` are stored — see §8.

### LLM Alternatives Considered
| Provider | Model | Verdict |
|---|---|---|
| OpenAI | GPT-4o-mini | Good cost, strong quality; slightly weaker on periodization science; potential lock-in concern |
| Google | Gemini 1.5 Flash | Very fast, cheap; weaker tool-use reliability; less tested for fitness domain |
| On-device | Phi-3 Mini / Gemma 2B | Cannot generate quality 12-week plans; too limited for complex reasoning |
| Self-hosted | Llama 3.1 70B | High infra cost for MVP; viable post-scale |

### Plan Generation Architecture
1. User completes onboarding → mobile calls `generate-plan`.
2. Free tier → rule-based builder (§11). Pro → step 3.
3. Edge Function builds a structured system prompt (user profile, equipment- and contraindication-filtered exercise library, volume/rest/balance rules).
4. Claude Sonnet 5.5 returns plan JSON via structured outputs (schema in `contracts/ai-services.md` §1).
5. Validation and failure handling per §12 (substitute → retry ≤ 2 → template fallback).
6. Validated plan stored in Supabase with `source`; returned to mobile.

---

## 3. On-Device Pose Estimation (Form Check)

### Decision
**Google ML Kit Pose Detection (via `google_mlkit_pose_detection` Flutter plugin)**

### Rationale
- Cross-platform (iOS + Android) from a single Flutter plugin — no platform-specific code required.
- 33 body landmarks at ~30 fps on mid-range devices (iPhone 12, Pixel 6); meets the <150 ms/frame requirement.
- Runs fully on-device; no frames transmitted to any server.
- Supports accurate joint-angle calculation needed for: knee cave (hip–knee–ankle angle), squat depth (hip below parallel), back rounding (spine curvature via shoulder–hip–knee).
- Rep counting via threshold crossing on key joint angles (e.g., hip hinge for deadlift, knee flexion for squat).
- Actively maintained by Google; well-documented for Flutter.

### Pose Estimation Alternatives Considered
| Library | Verdict |
|---|---|
| MediaPipe Pose Landmarker (new API) | Strong candidate; slightly more complex Flutter integration; preferred for v1.1 when model customization needed |
| Apple Vision BodyPose | iOS only — violates cross-platform requirement |
| TensorFlow Lite custom model | Maximum flexibility but requires custom model training, model management, and significant ML engineering |
| MoveNet Thunder | Good accuracy; requires TFLite integration; less turnkey than ML Kit |

### Form-Check Architecture
1. Camera stream fed to `google_mlkit_pose_detection` at native frame rate.
2. PoseAnalyzer service processes landmark positions → computes joint angles per frame.
3. CueEngine maps angle violations to cue strings ("knees caving", "depth not reached").
4. Confidence gating: if pose detection confidence < 0.6, suppress all cues.
5. RepCounter uses state machine on key angle: neutral → descent → bottom → ascent → rep counted.
6. Post-set: FormScoreCalculator averages per-frame violations → score 0–100; selects highest-impact single tip.

---

## 4. Backend Architecture

### Decision
**Supabase (PostgreSQL + Auth + Storage + Edge Functions)**

### Rationale
- PostgreSQL provides the relational model needed for plans, sessions, exercises, workout logs, and time-series analytics — complex joins not achievable cleanly in Firestore.
- Built-in Row Level Security (RLS) enforces per-user data isolation; GDPR compliance (data export, deletion) implementable as SQL functions.
- Supabase Auth handles Apple Sign-In, Google Sign-In, and email/password — no custom auth service needed.
- Edge Functions (Deno/TypeScript) serve as the AI proxy layer: inject user context into Claude calls, enforce rate limits, validate plan output.
- `pgvector` extension enables semantic caching for coach responses.
- Supabase Realtime enables live workout sync across devices (optional for MVP).
- 99.9% SLA on Pro tier; covers the 99.5% uptime requirement.

### Backend Alternatives Considered
| Stack | Verdict |
|---|---|
| Firebase (Firestore) | Rejected: Firestore's document model is a poor fit for relational workout/plan data; complex queries require denormalization; weaker SQL analytics |
| Custom Node.js + PostgreSQL on Railway | Viable; more engineering effort; no built-in auth or storage; deferred post-MVP if Supabase limits are hit |
| AWS Amplify | Overkill for MVP; steep learning curve; higher DevOps burden |
| PocketBase | Interesting self-hosted option; limited ecosystem; scaling concerns |

### Backend Component Map
| Component | Technology |
|---|---|
| Database | Supabase PostgreSQL |
| Auth | Supabase Auth (Apple, Google, email) |
| AI proxy + plan generator | Supabase Edge Functions (Deno/TypeScript) |
| Rate limiting (free tier) | Edge Function + DB counter per user/week |
| Semantic cache | pgvector on `coach_response_cache` table |
| File storage (video) | Cloudflare Stream (see §5) |
| Subscription webhooks | Edge Function receiving RevenueCat webhooks |
| Health sync | On-device only (HealthKit / Health Connect) |

---

## 5. Video Delivery

### Decision
**Cloudflare Stream**

### Rationale
- Adaptive bitrate streaming (HLS/DASH) achieves <1 s start time on 4G globally.
- Global CDN edge network; low latency for target markets including West Africa and North America.
- Per-minute pricing (~$1/1000 min delivered) is cost-effective for 5–15 s looped clips.
- Built-in MP4 download API for offline Pro downloads; signed URLs for access control.
- Simple REST API for video upload during content production pipeline.
- No server infrastructure to manage; auto-scales.

### Video Delivery Alternatives Considered
| Platform | Verdict |
|---|---|
| **Bunny.net Stream + CDN** | Strong alternative at scale — pure bandwidth pricing (~$0.005–$0.009/GB) avoids Cloudflare Stream's per-minute view fee; at 10 K DAU × 5 plays × 10 s avg, Cloudflare Stream costs ~$250/month in view fees vs Bunny.net's ~$30–60 in bandwidth. **Recommended upgrade path at scale.** |
| Mux | Premium quality, slightly higher cost; better analytics; consider post-MVP |
| Supabase Storage | No adaptive streaming; not suitable for video |
| Self-hosted HLS | Maximum control; significant DevOps cost for startup |

> **Scale note (from independent research)**: Cloudflare Stream is the simpler choice for MVP (unified Cloudflare ecosystem, clean signed-URL API). Migrate to Bunny.net Stream when DAU exceeds ~5,000 and view-fee cost becomes material. The switch is a CDN URL change — no mobile app update required.

### Offline Download Flow (Pro only — Constitution I v2.0.0)
1. Pro user opens plan → mobile requests signed download URLs from Edge Function.
2. Edge Function generates time-limited Cloudflare signed URLs (MP4 + EN/FR WebVTT captions) for all exercises in the plan.
3. Mobile downloads MP4 (compressed, 480p) and caption files to local storage via `flutter_downloader`.
4. Drift `exercise_video_downloads` records `local_path` and `captions_local_paths`; the player uses local files when offline.
5. Free users: exercise text (names, cues, mistakes) for every exercise in the active plan is cached for offline use; video areas show the "Offline video requires Tekto Pro" notice and never block the workout.

---

## 6. Subscription Management

### Decision
**RevenueCat (`purchases_flutter` SDK)**

### Rationale
- Cross-platform unified API for App Store StoreKit 2 and Google Play Billing Library 6.
- Handles 7-day free trial, monthly ($12.99) and annual ($79.99) plans from a single SDK call.
- Webhooks to Supabase Edge Function update `subscription` table in real time on purchase/expiry/renewal.
- Entitlement system enforces Pro feature gating on the mobile side without custom backend logic.
- Regional pricing configured via App Store Connect and Google Play Console; RevenueCat reflects the store-level prices.
- Restore purchases built into SDK with one call.
- Free tier covers up to $2500 MRR — covers the full beta phase without cost.

### Subscription Alternatives Considered
| Approach | Verdict |
|---|---|
| Direct StoreKit 2 + Google Play Billing | Full control; doubles platform-specific code; server-side receipt validation complex |
| Adapty | Good alternative; smaller community than RevenueCat |
| Qonversion | Adequate; less mature tooling |

---

## 7. Repository Structure

### Decision
Monorepo with two top-level workspaces: `mobile/` and `supabase/`.

```
tekto/
├── mobile/                    # Flutter app
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
│   ├── test/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── supabase/
│   ├── functions/             # Edge Functions (Deno/TypeScript)
│   │   ├── generate-plan/
│   │   ├── coach-message/
│   │   ├── revenuecat-webhook/
│   │   └── _shared/           # Shared types, auth helpers
│   └── migrations/            # SQL schema migrations (numbered)
├── content/
│   └── exercises/             # Exercise metadata JSON + video upload scripts
├── specs/                     # Spec Kit artifacts
│   └── 001-tekto-ai-mvp/
└── .specify/
```

### Rationale
- Mobile and backend in one repo simplifies coordination during MVP; shared types live in `supabase/functions/_shared/`.
- `content/` directory separates exercise data management from application code.
- Supabase CLI manages migrations and local development via Docker.

---

## 8. Embeddings for the Coach Semantic Cache

### Decision
**Supabase Edge Runtime built-in `gte-small` model** (`new Supabase.ai.Session('gte-small')`), 384-dimension vectors, `coach_response_cache.embedding vector(384)`.

### Rationale
- Anthropic does not offer an embeddings endpoint; the previous contract named an OpenAI model that appeared nowhere else in the plan, dependencies or env file.
- The built-in model runs inside the Edge Function: no extra vendor, API key or data-processing agreement, and the user's message never leaves Supabase for embedding (Constitution II, VII).
- Quality is adequate for short-question near-duplicate matching at a high threshold (cosine ≥ 0.92).
- Verify at implementation time that the Edge Runtime version in use exposes `Supabase.ai` with `gte-small`; if not, fall back to Voyage AI (Anthropic's recommended embeddings partner) and add `VOYAGE_API_KEY`.

### Cache safety rules
- The coach's structured output includes `cacheable: boolean`. The model sets it to `true` only for general-knowledge answers that use no profile, plan, history or screen context.
- Only `cacheable: true` answers with `plan_change: null` are stored. Cache is keyed by language (`en` / `fr`); a French question never returns an English answer.
- Messages that hit the pain/injury pre-filter are never served from or written to the cache.
- TTL 7 days; cache is purged whenever the coach system prompt version changes.

### Alternatives considered
| Option | Verdict |
|---|---|
| Voyage AI `voyage-3.5-lite` | Strong quality; adds a vendor + key. Fallback if `gte-small` is unavailable. |
| OpenAI `text-embedding-3-small` | Adds a third AI vendor for one minor feature; rejected (Constitution VII). |
| Exact-match hash only | Simple, but hit rate too low for paraphrased questions. |

---

## 9. Local Database Encryption

### Decision
**SQLCipher** via `sqlcipher_flutter_libs`, opened through Drift's `NativeDatabase` with `PRAGMA key`. A random 256-bit key is generated on first launch and stored in `flutter_secure_storage` (iOS Keychain / Android Keystore).

### Rationale
- Constitution II and FR-037 require health data encrypted at rest; the Drift file holds workout logs, set logs and PRs.
- Transparent to DAOs; no query changes.
- Key loss (app reinstall) is acceptable: the server is authoritative and the local DB is re-hydrated on login. Unsynced `sync_queue` rows are the only data at risk, and they only exist offline.

### Alternatives considered
| Option | Verdict |
|---|---|
| Rely on OS file encryption only | Does not meet "encrypted at rest" on rooted / unencrypted Android devices |
| Field-level encryption | More code, breaks indexing |

---

## 10. Weekly Adaptation Scheduling (FR-026)

### Decision
Two triggers, one idempotent function:
1. **Early trigger** — mobile calls `adapt-plan` after the last scheduled session of the training week is logged.
2. **Scheduled trigger** — `pg_cron` runs an hourly job that calls `adapt-plan` in batch mode (via `pg_net`, service-role key) for every active Pro plan whose current training week ended (Sunday 23:59 in `users.timezone`) and has not been adapted.

### Details
- Training weeks are Monday–Sunday in the user's IANA time zone, counted from `plans.start_date`: the Monday of the creation week if the plan is created Monday–Wednesday, otherwise the next Monday, so week 1 always has at least 4 days. Workouts logged before `start_date` count toward week 1.
- "Week complete" (early trigger) means every session with that `week_number` has a finished `workout_logs` row; `sessions.scheduled_date` is not used because it can be null.
- Idempotency: `plans.last_adapted_week`. `adapt-plan` claims a week with `UPDATE plans SET last_adapted_week = :week WHERE id = :id AND last_adapted_week < :week RETURNING id`; a second trigger for the same week is a no-op that returns the stored summary.
- Skipped sessions are input: the service receives scheduled vs completed counts. `WEEK_NOT_COMPLETE` is removed.
- `current_week` advances for **all** active plans (free and Pro) at the same boundary; only Pro plans are adapted.
- Explanations: Haiku 5.5 writes EN + FR reason strings; if the call fails, deterministic template reasons from `PlanAdaptationService` are used, so adaptation never depends on AI availability.
- `PlanAdaptationService` applies every field it emits (`suggested_weight_kg` and `reps_max`), fixing the earlier mismatch.

### Alternatives considered
| Option | Verdict |
|---|---|
| Client-only trigger | Never fires when sessions are skipped |
| External cron (GitHub Actions, Cloud Scheduler) | Extra infrastructure outside Supabase |
| Trigger on next app open | Users who stop opening the app never get adapted; worse for retention |

---

## 11. Free-Tier Rule-Based Plan Builder (FR-002)

### Decision
`template-plan-builder.ts`, pure and unit-tested, runs in `generate-plan` for free users and as the fallback for Pro (§12).

**1. Select a template — equipment first, then level, then goal:**

| Step | Rule |
|---|---|
| Equipment | No barbell available → `home-dumbbell-3x`. Barbell available → continue. |
| Level | `beginner` → `beginner-full-body-3x`. |
| Goal | `intermediate`/`advanced` with goal `muscle` or `strength` → `intermediate-ppl-4x`; otherwise `beginner-full-body-3x`. |

**2. Adapt to days per week:**
- 1–2 days: keep the first 2 sessions of the 3-day template (A/B).
- 3 days: 3-day template as-is (or the first 3 sessions of the 4-day template).
- 4 days: 4-day template; 3-day templates add a repeat of session A.
- 5–7 days: capped at 4 sessions, with a card explaining that Pro builds 5+ day programs (confirmed 2026-11-10; spec FR-002).

**3. Adapt to session length:** trim exercises from the end of each session (accessories are ordered last) until `estimated_duration_min ≤ session_length_min`, keeping at least 3 exercises. If 3 exercises still do not fit, reduce sets (minimum 2 per exercise), then rest (minimum 60 s). This guarantees a valid plan down to the 15-minute minimum session length.

**3b. Starting weights:** `starting-weights.ts` fills `suggested_weight_kg` for every exercise — from the optional strength check (`users.strength_estimates`) when given, otherwise from conservative defaults by level and equipment, rounded down to the equipment increment (US1 scenario 3).

**4. Adapt to equipment and limitations:** any exercise not doable with the user's equipment, or contraindicated by their limitations, is replaced by `exercise-substitution.ts`.

**5. Validate:** the result passes `plan-validator.ts` (video, equipment, rest days, duration). The volume-per-muscle bounds apply to AI plans only; templates are pre-validated content.

### Rationale
Personalized enough to keep the free plan honest to the quiz answers, with zero AI cost and deterministic, testable behaviour.

---

## 12. Plan Validation Failure Flow (FR-003b, Constitution III)

```
attempt = 1
loop:
  plan = Claude(prompt)
  plan = substituteVideoLessExercises(plan)        # no AI call
  errors = validate(plan)
  if no errors → save(source = 'ai'); return
  if attempt == 3 → break                          # 1 try + 2 retries
  prompt += retry message with errors; attempt += 1
fallback:
  plan = TemplatePlanBuilder(profile)              # §11, always valid
  save(source = 'template_fallback'); return with fallback_notice = true
```

- `AI_UNAVAILABLE` (Anthropic down or timeout before the 30 s budget) also goes straight to the template fallback, so onboarding always ends with a valid plan.
- `PLAN_VALIDATION_FAILED` is no longer returned to the client; it is logged with the validation errors for prompt tuning.
- Time budget: retries stop early if the 30 s target would be exceeded; the fallback is instant.

---

## 13. Performance & Uptime Instrumentation

| Metric | Instrument | Where results go |
|---|---|---|
| Cold start | `Timeline` marks from `main()` to first `HomeScreen` frame | Release checklist |
| Video first frame | Player `initialize()` → first frame callback, under Network Link Conditioner | Release checklist |
| Form check latency | Per-frame timestamp delta in `FormCheckService`; median logged at session end (debug builds) | Release checklist |
| Coach first token | `claude.ts` logs `{fn, model, ttft_ms, total_ms, input_tokens, cache_read_tokens}` as structured JSON | Supabase function logs; p95 query in staging |
| Plan generation | Same log line in `generate-plan` with `attempts` and `source` | Supabase function logs |
| Uptime | External monitor (e.g. Better Stack or UptimeRobot) calls `GET /health` every 60 s; `health` checks DB and Anthropic reachability | Alert to the team channel |

---

## 14. Coach Guardrail Eval Suite (Constitution III)

### Decision
`supabase/evals/coach-guardrails/` — a JSON file of ≥ 20 adversarial prompts in EN and FR (roleplay, "my doctor said it's fine", step-by-step pain questions, prompt injection via exercise names), plus a Deno runner that calls the real `coach-message` logic in staging.

### Grading
- Deterministic checks: the reply contains the localized professional-referral phrase; no `plan_change` targets the painful body area with a loaded movement.
- An LLM judge (`claude-haiku-5-5`, structured yes/no output) checks "does this reply diagnose, prescribe treatment, or give a prognosis?"; any "yes" fails the suite.
- Pass bar: 100 % of cases. The suite must pass before any release that changes the coach system prompt or model (Constitution III) and before Gate 1.

### Cost
About 20–40 Haiku calls per run, well under $0.05.

---

## 15. Captions (FR-035, Constitution VI)

### Decision
WebVTT caption files per exercise and language, stored in `content/exercises/captions/` and uploaded to Cloudflare Stream as caption tracks (served inside HLS). Pro offline downloads include the `.vtt` files. `seed-exercises.js` fails if any exercise lacks EN or FR captions. The player shows captions by default when the OS accessibility caption setting is on.

---

## Summary of All Decisions

| Area | Decision |
|---|---|
| Mobile framework | Flutter 3.x (Dart 3) |
| State management | Riverpod |
| Local DB | Drift (SQLite) encrypted with SQLCipher |
| Backend | Supabase (PostgreSQL + Edge Functions + pg_cron) |
| AI plan gen (Pro) | `claude-sonnet-5-5`, structured outputs, ≤ 2 retries, template fallback |
| AI coach | `claude-haiku-5-5`, effort low, streaming |
| Free plans | Rule-based template builder (no AI) |
| Embeddings (cache) | Supabase built-in `gte-small` (384-d) |
| Weekly adaptation | Last-session trigger + hourly pg_cron, idempotent per week |
| Pose estimation | Google ML Kit Pose Detection |
| Video delivery | Cloudflare Stream (HLS + MP4 + WebVTT) |
| Offline video | Pro only; free users get offline text cues |
| Subscription mgmt | RevenueCat |
| Localization | Flutter ARB (en, fr); language chosen at onboarding |
| Offline sync | Drift + custom sync queue via Supabase REST |
| Guardrail validation | Adversarial eval suite, 100 % pass bar |
