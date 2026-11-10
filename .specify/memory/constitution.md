# Tekto Constitution

## Core Principles

### I. Offline-First (NON-NEGOTIABLE)

For every user, free or Pro, the core actions of a live workout — logging a
set, starting the rest timer, navigating between exercises, and reading the
technique cues — MUST work with no network connection. The device is the
source of truth for in-progress workout data.

- Local writes are queued and flushed to the backend only when connectivity
  is restored; they are NEVER blocked on a network response.
- The active plan, all sessions in that plan, and all exercise text content
  (names, cues, common mistakes) MUST be available on-device before the first
  workout begins, for every user.
- Offline exercise video is a Pro entitlement. For Pro users, every video in
  the active plan MUST be playable offline once downloaded. For free users
  offline, video areas MUST show a clear "offline video requires Pro" notice
  and MUST NOT block, interrupt, or slow down the workout.
- No feature MAY degrade silently offline without communicating status to the
  user (e.g., coach unavailability MUST show a clear message, not a spinner).

**Rationale**: Gym environments regularly have poor or no connectivity. If the
app fails during a set, users lose trust immediately and churn. This principle
is load-bearing for the week-4 retention metric.

### II. Privacy by Default (NON-NEGOTIABLE)

User health data and camera footage are among the most sensitive data
categories. Tekto MUST handle them with the strongest possible default
protections.

- Camera frames captured during form check MUST be processed entirely
  on-device. No frame bytes MAY be transmitted to any server unless the
  user explicitly initiates a share action.
- `form_check_sessions.user_shared` MUST default to `false` and can only be
  set to `true` by an explicit, confirmed user action — never by a background
  process.
- Health data (workout logs, body metrics, Apple Health / Health Connect
  sync) MUST be encrypted at rest and in transit.
- Users MUST be able to export all their data and permanently delete their
  account from within the app, without contacting support.
- GDPR compliance (data export, deletion cascade, consent at onboarding) is
  not optional and MUST be verified before each major release.

**Rationale**: Camera form check is the most unique feature and the highest
privacy risk. Trust, once broken in this area, cannot be recovered. Upfront
privacy engineering is cheaper than a post-breach rebuild.

### III. AI Safety is Non-Negotiable (NON-NEGOTIABLE)

The AI plan generator and AI coach MUST enforce hard safety rules at every
layer — prompt, backend, and rule-checker — with no exceptions at MVP.

- Every plan, AI-generated or template-based, MUST pass automated rule checks
  (volume per muscle group within bounds, rest days present, every exercise
  has a video, available equipment only, duration feasible) before it reaches
  the user. Exercises without a video MUST be substituted with a validated
  alternative; any other failure MUST be retried at most two times. If all
  attempts fail, the user MUST receive a validated fallback plan with a
  visible notice — never a broken or unvalidated plan.
- The AI coach MUST detect injury, pain, and medical symptom language and
  respond with a referral to a qualified professional. It MUST NOT provide
  a diagnosis, treatment, or prognosis under any prompt variation.
- Safety guardrail prompts MUST be validated against adversarial inputs
  before each release that changes the system prompt.
- The health disclaimer MUST be presented at onboarding before the first
  plan is generated and cannot be skipped.

**Rationale**: A wrong plan or a confident-sounding injury diagnosis can
cause real physical harm. App Store rejection on health safety grounds is an
existential risk. These rules exist to protect users and the product.

### IV. Video Gate (NON-NEGOTIABLE)

A training plan MUST NEVER reference an exercise for which no filmed video
exists in the library. This is enforced at generation time, not at display
time.

- The plan generator's rule-checker MUST validate that every `exercise_slug`
  in a generated plan resolves to an `exercises` row with a non-null
  `video_front_url`. Plans that fail this check MUST be rejected and retried.
- The exercise library MUST only be extended via the controlled content
  pipeline (`content/exercises/`); ad-hoc database inserts that bypass video
  upload are prohibited in production.
- When a user requests an exercise swap, the replacement exercise MUST have a
  video before the swap is applied. The backend MUST reject swaps to
  video-less exercises with `EXERCISE_NO_VIDEO`.

**Rationale**: "Real filmed video for every move" is a core product
differentiator and a trust signal. A plan that sends a user to an exercise
with no demonstration undermines the product's entire value proposition.

### V. Test-First for Business Logic

Business-logic code — plan adaptation, form scoring, quota enforcement,
subscription entitlement, and PR detection — MUST have unit tests written and
passing before the implementation is considered complete.

- The Red-Green-Refactor cycle is enforced for: `PlanAdaptationService`,
  `FormScoreCalculator`, `RepCounter`, `CoachQuotaService`, and subscription
  gate checks.
- Edge cases (e.g., zero completed sessions in a week, all reps failed,
  confidence below threshold) MUST have explicit test coverage before
  merge.
- Widget tests MUST cover each paywall screen to verify that a workout in
  progress is never blocked.
- Integration tests MUST cover the offline write-queue flush scenario
  (write offline → reconnect → verify server state).

**Rationale**: The adaptation algorithm, form scoring, and quota logic are
the product's differentiating intelligence. Bugs here cause direct user harm
(wrong progression) or revenue leakage (quota bypass). Tests are the cheapest
form of insurance for this category.

### VI. Premium UX is a Feature

The interface MUST feel like a luxury product. Visual quality is not
cosmetic — it is the first reason a user believes a subscription is worth it.

- Dark-first design is the default; light theme follows the system setting.
  The dark theme MUST use the defined design tokens (charcoal base, one bold
  accent, generous spacing) — deviations require explicit design approval.
- During a live workout, only one primary action MUST be visible and
  reachable with one thumb at any time.
- Transitions and haptics MUST be used purposefully: set completion, new PR,
  and rep detection warrant feedback; decorative animations that add latency
  are prohibited.
- AI suggestions MUST appear as short, confident cards with a "why" on tap.
  They MUST NOT interrupt a set with a modal or alert.
- All tap targets MUST meet a minimum size that is readable and tappable at
  arm's length in a gym environment.
- Accessibility is part of premium: Dynamic Type, VoiceOver/TalkBack labels,
  and captions on all exercise videos MUST be implemented before each release,
  targeting WCAG 2.1 AA.

**Rationale**: The app competes on design as much as on AI. A premium look
is the first conversion lever before a user even reaches the paywall. Cutting
UX corners during MVP to ship faster has historically damaged retention more
than it has saved time.

### VII. Simplicity Over Abstraction

Build only what is needed for the current requirement. No premature
abstractions, no gold-plating, no speculative infrastructure.

- A feature MUST exist in the spec before its supporting abstraction is
  built. No "we'll need this later" layers.
- If three similar code paths exist, consider an abstraction. Two similar
  paths do not justify one.
- The backend MUST remain on Supabase Edge Functions until a specific,
  measured performance or capability ceiling is reached. No migration to
  custom servers "in case."
- Dependencies MUST be justified by a concrete current requirement. Each new
  package added to `pubspec.yaml` or `package.json` MUST have a one-line
  justification comment at the point of use.
- Technical debt MUST be logged (as a task or comment) rather than
  silently accumulated, so it can be intentionally prioritized.

**Rationale**: Tekto is an MVP. Complexity kills MVPs. Every abstraction
added before it is needed is a maintenance surface that slows the next
feature and obscures the product's actual complexity.

## Performance Standards

These are non-negotiable product-level targets; they MUST be verified on
a mid-range reference device (iPhone 12 / Pixel 6) before each release.

| Metric | Target | Enforcement |
|---|---|---|
| Cold start | < 2 s | Flutter DevTools timeline; CI performance test |
| Exercise video first frame (4G) | < 1 s | Network Link Conditioner test in release CI |
| Form check frame latency | < 150 ms | Debug overlay in `FormCheckService`; measured median |
| AI coach reply (first token) | < 3 s | Measured p95 in staging |
| Plan generation | < 30 s | Edge Function log; user-facing timeout fallback |
| Backend / AI uptime | ≥ 99.5% | Supabase status + uptime monitoring alert |

A release that regresses any of these targets MUST be held until the
regression is resolved or a justified exception is documented in the
PR description.

## Quality Gates & Development Workflow

### Gate 1 — Before Beta Launch

All of the following MUST be true before the app enters public beta:

- [ ] All five core user journeys pass end-to-end on both iOS and Android
  (onboarding → plan, daily workout, form check, AI coach, paywall).
- [ ] All performance standards pass on reference devices.
- [ ] GDPR data export and account deletion are functional.
- [ ] Safety guardrails tested against a minimum of 20 adversarial prompts.
- [ ] Health disclaimer present and unskippable at onboarding.
- [ ] All 150+ exercises have filmed videos with `video_front_url` populated.
- [ ] Privacy audit: no camera frames logged or transmitted in test runs.

### Gate 2 — Before Public Launch

All beta metrics MUST meet or exceed targets from the PRD Goals section
before the app is submitted to the stores for general availability:

- Onboarding completion ≥ 70 %
- Trial start rate ≥ 30 %
- Week-4 retention ≥ 40 %

### Development Workflow

- Features follow the Spec Kit lifecycle:
  `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-implement` → `/speckit-converge`.
- No implementation work begins without a completed `spec.md` and `plan.md`
  for the feature.
- Pull requests for business-logic changes MUST include a test coverage
  summary. PRs that reduce coverage on the five tested services listed in
  Principle V MUST be held until coverage is restored.
- Branch naming follows the feature directory prefix: `001-tekto-ai-mvp`,
  `002-next-feature`, etc.

## Governance

This constitution is the highest-level governing document for Tekto's
engineering and product practices. It supersedes all other norms, style
guides, and informal agreements.

**Amendment procedure**:
1. Propose the amendment as a PR that edits only `.specify/memory/constitution.md`.
2. State the version bump (MAJOR / MINOR / PATCH) and rationale in the PR
   description using the Sync Impact Report format.
3. The PR requires explicit approval before merge; a comment is not sufficient.
4. After merge, update `LAST_AMENDED_DATE` and `CONSTITUTION_VERSION` in the
   file footer.

**Versioning policy**:
- MAJOR: A principle is removed, renamed with changed meaning, or made
  materially less restrictive.
- MINOR: A new principle or section is added, or an existing one is
  materially expanded.
- PATCH: Wording clarifications, typo fixes, example updates — no semantic
  change.

**Compliance**: All PRs MUST be reviewed for constitution compliance.
Violations require either a spec amendment with justification (documenting
why the violation is necessary and time-bound) or a code change to restore
compliance. Silent violations are not acceptable.

**Version**: 2.0.0 | **Ratified**: 2026-11-09 | **Last Amended**: 2026-11-10
