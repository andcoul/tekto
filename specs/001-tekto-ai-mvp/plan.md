# Implementation Plan: Tekto AI MVP

**Branch**: `001-tekto-ai-mvp` | **Date**: 2026-11-22 (revised; first version 2026-11-09, major revision 2026-11-10) | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-tekto-ai-mvp/spec.md`, including Clarifications Session 2026-11-10

**Constitution**: v3.0.0 (amended 2026-11-20: §IV and Gate 1 accept reviewed AI-generated video)

---

## Summary

Tekto is a premium, AI-first strength training app for iOS 16+ and Android 10+ phones, built from a single Flutter codebase backed by a Supabase (PostgreSQL + Edge Functions) backend. The MVP delivers four AI pillars — plan generation, video library, AI chat coach, and camera form check — plus full workout tracking and an offline-first experience. Since 2026-11-21 it also ships a Pro plan library of ready-made programs, a modern-equipment exercise library, a friends feed with a weekly leaderboard, muscle recovery, focus muscles, a profile hub and an in-app support chat (FR-047–FR-054).

**Technical approach** (from [research.md](./research.md)):
- **Mobile**: Flutter 3.x (Dart 3), Riverpod, Drift on an encrypted SQLite file (SQLCipher) for offline-first, go_router.
- **Backend**: Supabase (PostgreSQL + RLS + Edge Functions + Auth + pg_cron), pgvector semantic cache.
- **AI**: Anthropic Claude API — `claude-haiku-5-5` for the chat coach and adaptation explanations, `claude-sonnet-5-5` for Pro plan generation. Free plans are rule-based (no AI call).
- **Embeddings** (coach cache only): Supabase Edge Runtime built-in `gte-small` model, 384 dimensions — no third-party embedding vendor.
- **Pose estimation**: Google ML Kit Pose Detection (on-device).
- **Video**: Cloudflare Stream (HLS + MP4 downloads + WebVTT captions).
- **Subscriptions**: RevenueCat (`purchases_flutter`), webhooks to Supabase.

**What changed in this revision** (driven by spec clarifications and `/speckit-analyze` findings):

| Change | Source |
|---|---|
| Offline video is Pro-only; free users get text cues offline plus a non-blocking notice | Clarification Q1; Constitution I (v2.0.0) |
| Free plans: rule-based template builder (equipment → level → goal; days and session length adapted); same validator as AI plans | Clarification Q2; FR-002, FR-002a |
| Weekly adaptation runs on a schedule (Sunday 23:59 local) or on the last logged session; skipped sessions are inputs | Clarification Q3; FR-026 |
| Plan-failure flow: substitute video-less exercises → up to 2 retries → validated template fallback with notice | Clarification Q4; FR-003b; Constitution III |
| Form check required at launch (P1) | Clarification Q5 |
| Local database encrypted at rest | Constitution II; FR-037 |
| GDPR consent captured at onboarding | Constitution II |
| Guardrail eval suite (≥ 20 adversarial prompts, EN + FR) | Constitution III; Gate 1 |
| Captions on every exercise video | Constitution VI; FR-035 |
| Latency/uptime instrumentation for every Performance Standard | Constitution Performance Standards |
| Coach cache limited to generic answers (never personalized ones) | Constitution II (cross-user leak risk) |
| Model IDs moved to the current generation | research.md §2 |
| Analyze runs 5–6 (2026-11-15): progress, plate calculator, welcome, rationale, consent FRs (FR-039–045); volume max on all plans; push:pull check for AI plans; swap for all tiers; onboarding order welcome → auth → disclaimer → consent → quiz → plan → trial | spec Clarifications 2026-11-15 |
| Imagery and casting (2026-11-17): mixed cast with Black men and women in lead roles across photos, thumbnails and filmed content; dark-UI lighting brief | User design request; Constitution VI; research §16 |
| Equipment vocabulary, clip length 4–15 s, second angle only for form-check lifts (2026-11-20) | spec Clarifications 2026-11-20; migration 014 |
| Pro plan library: catalog templates in `plan_templates`, `generate-plan` `program_slug`, fitted and validated like template plans (2026-11-21) | FR-047; research §17 |
| Smith machine, trap bar, suspension straps as equipment; batch-6 exercises wait in `pending-batch-6.js` until their clips pass review; duplicates merged (2026-11-21) | FR-001, FR-013; migration 015; Constitution IV |
| Four tabs, friends feed with fixed reactions, weekly training score, recovery, focus muscles, profile hub, support chat with AI + human hand-off (2026-11-21) | FR-048–FR-054; migration 016; research §18–§20 |
| Workout sharing off until the user turns it on (2026-11-22) | Constitution II; FR-049 |

---

## Technical Context

**Language/Version**: Dart 3 (Flutter 3.x, stable channel) / TypeScript on Deno (Supabase Edge Functions)

**Primary Dependencies** (each carries a one-line justification at its point of use, per Constitution VII):
- Mobile: `flutter_riverpod`, `go_router`, `drift` + `sqlcipher_flutter_libs` (encrypted local DB), `supabase_flutter` (auth + REST), `dio` (Edge Function calls with retry interceptor), `freezed` + `json_serializable`, `video_player` + `chewie`, `camera` + `google_mlkit_pose_detection`, `purchases_flutter`, `health`, `flutter_secure_storage`, `connectivity_plus`, `flutter_downloader`, `fl_chart`, `firebase_crashlytics`
- To remove unless a current requirement is identified: `retrofit` / `retrofit_generator` (Dio is used directly), `lottie`, `haptic_feedback` (Flutter's built-in `HapticFeedback` covers set completion, PRs and reps)
- Backend: `@anthropic-ai/sdk` (Claude), `@supabase/supabase-js`, Supabase built-in `Supabase.ai` (embeddings), `pg_cron` + `pg_net` (weekly adaptation scheduler)

**Storage**: PostgreSQL (Supabase, remote, authoritative) + SQLite via Drift encrypted with SQLCipher (on-device, offline-first; key in `flutter_secure_storage`) + Cloudflare Stream (video and caption files)

**Testing**: `flutter_test` (unit + widget), `integration_test` (Flutter), `deno test` (Edge Function business logic), guardrail eval suite (`deno task eval:guardrails`, runs against the real coach model in staging)

**Target Platform**: iOS 16+, Android 10+; **phones first**. Tablets run the phone layout without clipping; no tablet-specific layouts in the MVP (spec Assumptions)

**Project Type**: Mobile app (cross-platform) + serverless backend (Edge Functions)

**Performance Goals** (Constitution Performance Standards; each has an instrument — see research.md §13):

| Metric | Target | Instrument |
|---|---|---|
| Cold start | < 2 s | Flutter DevTools timeline on iPhone 12 / Pixel 6 |
| Video first frame (4G) | < 1 s | Network Link Conditioner "LTE" |
| Form check frame latency | < 150 ms median | Debug overlay + logged median in `FormCheckService` |
| Coach first token | < 3 s p95 | Structured timing log in `coach-message` (staging) |
| Plan generation | < 30 s | Structured timing log in `generate-plan`; 35 s client timeout |
| Backend / AI uptime | ≥ 99.5 % | External uptime monitor hitting `GET /health` every minute |

**Constraints**:
- Offline for today's workout for every user: logging, rest timer, navigation, text cues. Offline video for Pro only.
- On-device pose estimation; no camera frames leave the device.
- GDPR: consent at onboarding, in-app export and deletion, encrypted local storage.
- Free tier: rule-based plan, 3 coach questions/ISO week, 1 form-check try per lift.

**Scale/Scope**:
- ≥ 150 exercises at launch (84 in `content/exercises/exercises.json` on 2026-11-20 — content workstream must close this gap before Gate 1)
- 4 personas; English and French
- MVP: ~20 screens; 10 Edge Functions; 15 user/content entities (incl. `body_weight_entries`) + 2 system tables (`coach_response_cache`, `plan_templates`) + 1 local-only table (`sync_queue`)

**Unknowns**: none remaining. The embedding provider (previously unresolved; contract referenced an OpenAI model) is resolved in research.md §8.

---

## Constitution Check

*GATE: evaluated against constitution v2.0.1 (2.0.1 only clarifies the wording of §IV; no new checks). Re-checked after Phase 1 design (below) and against v3.0.0 (2026-11-20).*

| Principle | Requirement | Design response | Status |
|---|---|---|---|
| **I. Offline-First** | Core workout actions offline for all users; plan + exercise text on device before first workout; Pro videos offline once downloaded; free users see a non-blocking notice | Drift mirrors the active plan, sessions, plan exercises and the exercise text for every exercise in the plan for all users. Writes go through `sync_queue`. `VideoPlayerWidget` shows the Pro notice offline for free users without blocking. | ✅ PASS |
| **II. Privacy by Default** | Frames on-device; `user_shared` default false; health data encrypted at rest + in transit; in-app export/delete; GDPR consent | SQLCipher on the Drift file (research §9). TLS for all traffic. Consent step after the health disclaimer, stored in `users.consent_at` / `consent_version` (data-model §1). Coach cache stores only answers the model marks as generic (`cacheable: true`), so no user's personalized answer is served to another user (research §8). **Social (2026-11-21):** `users.share_workouts` defaults to `false`; the user turns sharing on with one explicit tap; friends only (mutual acceptance), never public; friends see session summaries and muscles only (no weight, measurements, limitations or notes) through SECURITY DEFINER RPCs; no free text in the feed; friendships, reactions and support chats are in the GDPR export and deleted with the account (research §18). | ✅ PASS |
| **III. AI Safety** | All plans validated; video substitution; ≤ 2 retries; validated fallback with notice; injury referral; adversarial validation before prompt changes; unskippable disclaimer | Single `plan-validator.ts` for AI and template plans. Failure flow in research §12. Guardrail eval suite with ≥ 20 adversarial prompts (EN + FR) gates any change to the coach system prompt (research §14). | ✅ PASS |
| **IV. Video Gate** | Every plan slug resolves to a row with non-null `video_front_url`; videos filmed or AI-generated, each approved in a human form review (v3.0.0); library extended only via `content/` pipeline; swaps reject `EXERCISE_NO_VIDEO` | Clips are generated (Google Flow), reviewed frame by frame, then coach-reviewed; the review is recorded per clip in the content pipeline. Validator + seed-time check in `seed-exercises.js` and `seed-templates.js`; `swap-exercise` and `coach-confirm-change` re-check. Seeding fails if any row lacks video or captions. | ✅ PASS |
| **V. Test-First** | Red-Green-Refactor for `PlanAdaptationService`, `FormScoreCalculator`, `RepCounter`, `CoachQuotaService`, subscription gates; edge cases; widget test per paywall screen; offline flush integration test | `/speckit-tasks` must order each test task **before** its implementation task. New units also covered test-first: `TemplatePlanBuilder`, `ExerciseSubstitution`, `FormCheckFreeTryService`, adaptation scheduler week-boundary logic. Widget tests for `PaywallScreen`, `TrialOfferScreen` and the in-workout paywall bottom sheet. | ✅ PASS (enforced via task order) |
| **VI. Premium UX** | Dark-first tokens; one primary action in workout; purposeful haptics; non-modal AI cards; gym-sized tap targets; Dynamic Type, screen-reader labels, **captions on all videos** | WebVTT captions (EN + FR) required per exercise in the content schema; Cloudflare Stream serves them in HLS; Pro downloads include caption files (research §15). Adaptation and fallback notices are cards, never modals. **Design tokens:** the original charcoal `#1A1A1A` + orange `#FF6B2C` theme was replaced by **Midnight & Glacier** (Night `#0F1014`, Midnight `#16171D`, Glacier `#9DB8FF` as the one bold accent, Mint `#7EE0B8` for records only; no yellow or red), explicitly approved by the product owner on 2026-11-16 as the design deviation Constitution VI requires; tokens live in `mobile/lib/core/theme/app_theme.dart`. | ✅ PASS |
| **VII. Simplicity** | Spec-driven abstractions; Edge Functions only; justified dependencies; logged tech debt | No new services beyond Supabase + Cloudflare + Anthropic + RevenueCat (friends, feed and support chat are Postgres tables, RPCs and one Edge Function; recovery, streak and badges are computed on the device). Built-in `gte-small` avoids a fourth AI vendor. Three unjustified packages flagged for removal (Technical Context). | ✅ PASS |
| **Performance Standards** | All six metrics verified on reference devices before each release | One instrument per metric (Technical Context table; research §13). | ✅ PASS |
| **Quality Gates** | Gate 1 items (5 journeys, perf, GDPR, ≥ 20 adversarial prompts, disclaimer, 150+ videos, privacy audit) | Each item maps to a validation scenario in [quickstart.md](./quickstart.md). 150+ videos is a content dependency outside engineering (see Scale/Scope). | ⚠️ PASS with tracked risk (content volume) |

**Gate result**: PASS. No unjustified violations. The one open risk (exercise content volume: 83 of 150 on 2026-11-21 after one duplicate was merged; 9 batch-4 and 75 batch-6 exercises are written and wait for their clips) is a dependency, not a design violation; it is tracked in Complexity Tracking and must be closed before Gate 1.

**Post-design re-check (after Phase 1)**: re-evaluated against the updated [data-model.md](./data-model.md), [contracts/](./contracts/) and [quickstart.md](./quickstart.md). No new violations introduced. Status unchanged. Re-checked 2026-11-17 after research §16 (imagery and casting): content and design only, so no new violations, and VI (Premium UX) is strengthened. Re-checked 2026-11-22 after FR-047–FR-054: the only finding was workout sharing on by default, which conflicted with II and was changed to opt-in; all other principles unchanged (the support assistant follows the same safety rules as the coach: no medical advice, hand-off to a person).

---

## Project Structure

### Documentation (this feature)

```
specs/001-tekto-ai-mvp/
├── plan.md              ← This file
├── spec.md              ← Feature specification (with Clarifications)
├── research.md          ← Technology decisions
├── data-model.md        ← Entity definitions and relationships
├── quickstart.md        ← End-to-end validation guide
├── contracts/
│   ├── backend-api.md   ← Edge Function HTTP contracts
│   └── ai-services.md   ← Claude API + embeddings + ML Kit + RevenueCat contracts
├── checklists/
│   ├── requirements.md  ← Specification quality checklist
│   └── gate1.md         ← Gate 1 validation record
└── tasks.md             ← /speckit-tasks output (regenerated 2026-11-10; remediations since)
```

### Source Code (repository root)

```
tekto/
├── mobile/                          # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── theme/               # Dark/light tokens, typography
│   │   │   ├── router/              # go_router routes + guards
│   │   │   ├── di/                  # Riverpod providers (global)
│   │   │   ├── iap/                 # RevenueCat service
│   │   │   └── l10n/                # app_en.arb, app_fr.arb
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── onboarding/          # Welcome, disclaimer, consent, language, quiz, plan generation, trial offer
│   │   │   ├── plan/                # Overview, swap sheet, adaptation summary, plan library (FR-047)
│   │   │   ├── workout/             # Home, live workout (+ plate calculator), summary
│   │   │   ├── library/             # Browse, detail, video download
│   │   │   ├── coach/               # Chat panel, change card, rating
│   │   │   ├── form_check/          # Camera, summary, free-try tracking
│   │   │   ├── progress/            # History, records, e1RM, volume, body weight
│   │   │   ├── settings/            # Preferences, regenerate plan, export/delete, sharing, display name
│   │   │   ├── subscription/        # Paywall, subscription settings
│   │   │   ├── social/              # Feed (Friends / You), friends, leaderboard, invites (FR-049, FR-050)
│   │   │   ├── recovery/            # Recovery formula, local history, screen + card (FR-051)
│   │   │   ├── profile/             # Profile tab: streak, heatmap, badges (FR-053)
│   │   │   └── support/             # Support chat (FR-054)
│   │   └── shared/
│   │       ├── models/              # Freezed data classes
│   │       ├── services/
│   │       │   ├── api/             # Dio client for Edge Functions
│   │       │   ├── local_db/        # Drift database (SQLCipher) + DAOs
│   │       │   ├── sync/            # Offline write queue + history backfill
│   │       │   ├── health/          # HealthKit / Health Connect
│   │       │   └── form_check/      # PoseAnalyzer, RepCounter, CueEngine, FormScoreCalculator
│   │       └── widgets/             # VideoPlayer (+captions), SetLogRow, RestTimer, ProGate, tab bar, MuscleFigure
│   ├── assets/video/                # Bundled welcome + paywall clips (with EN/FR captions)
│   ├── test/
│   │   ├── unit/
│   │   ├── widget/
│   │   └── integration/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── supabase/
│   ├── functions/
│   │   ├── generate-plan/           # AI (Pro) or template (free) plan + fallback flow
│   │   ├── adapt-plan/              # Weekly adaptation (user-triggered or cron batch mode)
│   │   ├── coach-message/           # AI coach
│   │   ├── coach-confirm-change/    # Apply a confirmed coach proposal (all change types)
│   │   ├── swap-exercise/           # User-initiated swap, all tiers (handler.ts + test)
│   │   ├── video-download-urls/     # Signed MP4 + caption URLs (Pro)
│   │   ├── revenuecat-webhook/      # Subscription sync
│   │   ├── export-data/             # GDPR export
│   │   ├── delete-account/          # GDPR deletion
│   │   ├── health/                  # Uptime probe (DB + Anthropic reachability)
│   │   ├── support-message/         # Support chat: instant AI answer, hand-off to the team (FR-054)
│   │   └── _shared/
│   │       ├── types.ts
│   │       ├── auth.ts
│   │       ├── db.ts
│   │       ├── claude.ts            # Anthropic client, model constants, fallbacks, timing logs
│   │       ├── embeddings.ts        # Supabase.ai gte-small wrapper
│   │       ├── plan-validator.ts    # One validator for AI + template plans
│   │       ├── exercise-substitution.ts  # Same muscle + available equipment + has video
│   │       ├── template-plan-builder.ts  # Free-tier plans, library programs, focus sets
│   │       ├── plan-adaptation.ts   # PlanAdaptationService (+ .test.ts)
│   │       └── week-boundary.ts     # Training-week end in user's time zone (+ .test.ts)
│   ├── evals/
│   │   └── coach-guardrails/        # ≥ 20 adversarial prompts (EN + FR) + runner
│   └── migrations/
│       ├── 001_initial_schema.sql
│       ├── 002_rls_policies.sql
│       ├── 003_pgvector_cache.sql   # vector(384) for gte-small
│       ├── 004_pr_trigger.sql
│       ├── 005_clarifications.sql   # timezone, consent, plan source/start_date, contraindications, captions, flagged reps
│       ├── 006_adaptation_cron.sql  # pg_cron + pg_net hourly job
│       ├── 007_metrics_views.sql    # Aggregate-only Gate 2 / SC views
│       ├── 008_body_weight.sql      # body_weight_entries
│       ├── 009_rir_target.sql       # plan_exercises.rir_target
│       ├── 010_coach_rpcs.sql       # increment_coach_quota + coach-message helper RPCs (service role)
│       ├── 011_coach_change_rejection.sql # coach_messages.plan_change_rejected_at
│       ├── 012_exports_bucket.sql   # private storage bucket for GDPR exports
│       ├── 013_activate_plan.sql    # activate_plan(): switch the active plan in one transaction
│       ├── 014_equipment_and_clip_length.sql # equipment vocabulary, clip 4–15 s
│       ├── 015_equipment_smith_trap_bar_suspension.sql
│       └── 016_social_focus_support.sql # friends, reactions, weekly score, focus muscles, support chat
│
├── content/
│   ├── exercises/
│   │   ├── exercises.json           # Master metadata (target ≥ 150 entries)
│   │   ├── captions/                # <slug>_en.vtt, <slug>_fr.vtt
│   │   ├── pending-batch-6.js       # Written exercises waiting for their clip
│   │   ├── promote.js               # Moves one in after its clip passes review
│   │   └── seed-exercises.js        # Fails on missing video or captions
│   └── templates/
│       ├── beginner-full-body-3x.json
│       ├── home-dumbbell-3x.json
│       ├── intermediate-ppl-4x.json
│       ├── bro-split-5x.json …      # + 6 more library programs (`catalog` block)
│       └── seed-templates.js        # Validates and upserts into plan_templates
│
└── specs/
    └── 001-tekto-ai-mvp/
```

**Structure Decision**: Mobile + serverless backend. `mobile/` is the Flutter app; `supabase/` contains all backend code. Starter templates are seeded into a `plan_templates` table (rather than read from `content/` at runtime) because deployed Edge Functions cannot read the repository's `content/` folder, and seeding reuses the same Video Gate validation as the exercise pipeline.

---

## Complexity Tracking

| Area | Decision | Justification |
|---|---|---|
| Dual runtime (Dart + Deno) | Kept | Flutter for mobile UI + on-device ML; Deno for Edge Functions |
| Semantic cache (pgvector) | Kept, narrowed | Cuts free-tier AI cost on common questions. Limited to answers the model marks `cacheable` (generic, no user data), scoped by language. |
| Offline write queue | Kept | Gym connectivity; minimal queue, not CRDTs |
| pg_cron + pg_net scheduler | Added | FR-026 requires adaptation when sessions are skipped; no client event exists in that case. Stays inside Supabase (Constitution VII). |
| SQLCipher | Added | Constitution II: health data encrypted at rest on device |
| Guardrail eval suite (real API calls) | Added | Constitution III requires adversarial validation. Costs a few cents per run; runs only when the coach prompt or model changes, and before each release. |
| `plan_templates` table | Added | Free-tier plans (FR-002) need templates reachable at runtime; seeding keeps Video Gate checks |
| **Tracked risk: content volume** | 84 of ≥ 150 exercises exist (2026-11-20); the welcome and 4 paywall clips are done (T132) | Blocks Gate 1 and makes the Pro plan validator reject most AI plans for narrow equipment sets. Owner: content workstream. Seeding warns below 150 in dev and fails in production. |
| **Tech debt resolved: tasks.md drift** | tasks.md regenerated on 2026-11-10 with no pre-checked tasks | Progress is tracked in tasks.md; `/speckit-converge` reconciles code against it. |
