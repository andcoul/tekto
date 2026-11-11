# Feature Specification: Tekto — AI-First Strength Training App MVP

**Feature Branch**: `001-tekto-ai-mvp`

**Created**: 2026-11-09

**Status**: Draft

**Input**: Tekto PRD v0.1 — full MVP scope

---

## Overview

Tekto is a premium, AI-first strength training app for iOS and Android. It builds a personalized training program, demonstrates every exercise through real filmed video, provides real-time form feedback via the device camera, and answers training questions through an AI coach. The MVP ships four AI pillars: plan generation, video library, AI chat coach, and camera form check, together with full workout tracking.

---

## Clarifications

### Session 2026-11-10

- Q: When a free user is offline in the gym, can they watch the videos for today's workout? → A: No. Offline video stays Pro-only; free users keep offline logging and rest timer. Requires a constitution amendment to Principle I (pending, MAJOR bump).
- Q: How personalized should a free user's first plan be? → A: Rule-based template, no AI: selected by equipment first, then level, then goal; days per week and session length adapted by rules; must pass the plan validator.
- Q: What should the free plan do when a user picks 5–7 training days per week? → A: Cap at 4 sessions and show a non-blocking card that Pro builds 5+ day programs.
- Q: When should the weekly plan update run, especially in a week where the user skipped sessions? → A: At the end of the user's training week (Sunday 23:59 local) or as soon as the last scheduled session is logged, whichever comes first; skipped sessions are inputs.
- Q: If the AI's plan keeps failing the safety check, what should the user see? → A: Video-less exercises are auto-swapped for a validated alternative; other failures get up to 2 retries; if all fail, the user receives the rule-based template plan with a note that they can regenerate later.
- Q: Is camera form check required for the launch, or can it ship in the first update? → A: Required at launch (P1) with the 8 lifts in FR-022; part of Gate 1; more lifts and polish in v1.1.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Onboarding to First Plan (Priority: P1)

A new user opens the app, watches the welcome experience, completes a short onboarding quiz about their goal, training level, available days, session length, equipment and any limitations, and receives a personalized 4–12 week training program in under 3 minutes. They are offered a Pro trial before or after account creation.

**Why this priority**: Without a generated plan the app has no value proposition; this is the entry point for every other feature.

**Independent Test**: A new install can complete onboarding, receive a valid plan, and see the first scheduled workout — with no other feature built.

**Acceptance Scenarios**:

1. **Given** a fresh install, **When** the user completes the onboarding quiz with goal = Muscle, level = Beginner, 3 days/week, 45 min, gym equipment, no limitations, **Then** the app displays a 4–12 week periodized plan with named exercises, sets, reps, rest periods and RPE targets, and every exercise has an associated video.
2. **Given** a user who selects Home gym + dumbbells only, **When** the plan is generated, **Then** all exercises in the plan are achievable with dumbbells or bodyweight, with no barbell movements.
3. **Given** a user who skips the strength-check step, **When** the plan is generated, **Then** conservative starter weights are pre-filled and no error occurs.
4. **Given** a user who dismisses the Pro trial offer, **When** dismissed, **Then** the user proceeds to their plan on the free tier with no paywall blocking.

---

### User Story 2 — Daily Workout Execution (Priority: P1)

An existing user opens the app on a training day, sees today's planned session on the home screen, starts the workout, watches the exercise video for each movement, logs sets with weight and reps, uses the auto-starting rest timer, and finishes with a session summary.

**Why this priority**: Core engagement loop — this drives the north-star metric (weekly completed workouts per paying user).

**Independent Test**: A user with a plan can run a full workout from start to finish, logging all sets, without needing the coach or form check.

**Acceptance Scenarios**:

1. **Given** a logged-in user with an active plan, **When** they open the app on a scheduled training day, **Then** the home screen displays today's session with estimated duration and target muscle groups.
2. **Given** a user who taps Start Workout, **When** each exercise is opened, **Then** the exercise video plays automatically in a loop and the first 3 key technique cues are shown.
3. **Given** a user who logs a set, **When** the set is saved, **Then** the rest timer starts automatically with the target rest duration.
4. **Given** a user who completes all sets for all exercises, **When** the workout is finished, **Then** a summary shows total volume, any personal records hit, and prompts for an effort rating (RPE).
5. **Given** a user who loses internet mid-workout, **When** they continue logging, **Then** all sets are saved locally and synced when connectivity returns.

---

### User Story 3 — AI Chat Coach (Priority: P2)

A Pro user opens the AI coach from any screen, asks a training or technique question, and receives a contextual answer grounded in their profile, current plan and history. They can request plan adjustments through conversation; changes are shown for confirmation before being applied.

**Why this priority**: Core Pro differentiator; drives trial-to-paid conversion and satisfaction metric.

**Independent Test**: A Pro user can open the coach, ask a free-form question, receive an answer, and request a plan modification — testable independently of form check.

**Acceptance Scenarios**:

1. **Given** a Pro user viewing an exercise, **When** they open the coach and ask "why is this exercise in my program?", **Then** the coach responds with a personalized explanation referencing their goal and plan.
2. **Given** a Pro user who asks "swap squats, my knee hurts", **When** the AI suggests an alternative, **Then** the user sees a confirmation card before the swap is applied to the plan.
3. **Given** a user who asks about a pain or injury ("my lower back hurts"), **When** the coach detects injury/medical language, **Then** the response advises the user to consult a professional and does not make a medical diagnosis.
4. **Given** a free user who taps the coach icon, **When** they have used their 3 free questions this week, **Then** a paywall is shown explaining the Pro benefit without blocking a workout in progress.

---

### User Story 4 — Camera Form Check (Priority: P1)

A Pro user starts a supported lift, taps the camera icon, follows the guided phone placement, performs the set, and receives rep counts, real-time form cues, and a post-set form score with one actionable tip.

**Why this priority**: Key Pro feature for form-check usage metric (≥50% of Pro users per week). Required at launch for the 8 lifts in FR-022 and part of the Gate 1 beta checklist; additional lifts and refinements are deferred to v1.1.

**Independent Test**: A Pro user can run a form check on a squat set end-to-end, with rep count and at least one form cue, without the coach or plan features.

**Acceptance Scenarios**:

1. **Given** a Pro user on a squat exercise, **When** they tap the camera icon, **Then** a guided phone placement screen appears with a framing outline.
2. **Given** correct phone placement, **When** the user performs reps, **Then** the app counts reps and displays up to 3 live cues (e.g., "knees caving").
3. **Given** a completed set, **When** the form check ends, **Then** a summary shows rep count, a form score and one prioritized tip.
4. **Given** low-confidence pose estimation (poor lighting, obstructed view), **When** confidence falls below threshold, **Then** no cues are shown and the user is told to adjust lighting or angle.
5. **Given** any form check session, **When** the session ends, **Then** no camera footage is uploaded to any server unless the user explicitly chooses to share it.

---

### User Story 5 — Adaptive Weekly Plan Updates (Priority: P2)

After completing workouts in a week, a Pro user's plan automatically adjusts for the following week: progressions are applied when targets are hit, volume or intensity is reduced when sessions were missed or rated too hard.

**Why this priority**: Core Pro adaptive plan feature; drives week-4 retention metric.

**Independent Test**: A Pro user who completes three workouts can verify that next week's suggested weights reflect their logged performance.

**Acceptance Scenarios**:

1. **Given** a Pro user who hits all reps at target RPE across a week, **When** the week ends, **Then** next week's plan shows a progressive overload (increased load or reps).
2. **Given** a Pro user who misses two sessions in a week, **When** the week ends (Sunday 23:59 local time), **Then** next week's plan maintains or slightly reduces volume rather than progressing.
3. **Given** a Pro user who rates a workout as "too hard" (high RPE), **When** the plan updates, **Then** the following session is adjusted to be less demanding.
4. **Given** any plan adaptation, **When** the user views next week's plan, **Then** a short explanation card is shown for why the plan changed.

---

### User Story 6 — Exercise Video Library (Priority: P1)

Any user (free or Pro) can browse and view the full exercise video library. Each exercise shows filmed demonstrations from front and side angles, target muscles, step-by-step cues, common mistakes, and easier/harder variations. Pro users can download exercise videos for offline use.

**Why this priority**: Free-tier value anchor; also prerequisite for all other features.

**Independent Test**: A free user can browse to any exercise in the library, watch the video, and read technique cues — with no plan or coach required.

**Acceptance Scenarios**:

1. **Given** any user, **When** they open an exercise in the library, **Then** a looped 5–15 second filmed video plays automatically and technique cues are displayed.
2. **Given** a Pro user with a downloaded plan, **When** they go offline, **Then** all videos in their current plan play without an internet connection.
3. **Given** a free user offline, **When** they attempt to view a non-downloaded exercise video, **Then** a friendly message explains that offline video requires Pro.

---

### User Story 7 — Subscription and Paywall (Priority: P1)

A free user encounters a Pro feature, sees a contextual paywall that communicates value without blocking a workout in progress, and can start a 7-day free trial via App Store or Google Play billing.

**Why this priority**: Monetization gate; directly impacts trial start rate and trial-to-paid conversion.

**Independent Test**: A free user can hit a paywall, start a trial, and unlock Pro features — testable without coach or form check in full detail.

**Acceptance Scenarios**:

1. **Given** a free user who taps the camera form check icon, **When** they have used their free try, **Then** a paywall is shown with a short value video and trial offer; the workout they are on is not interrupted.
2. **Given** a user on the paywall, **When** they tap "Start 7-day free trial", **Then** the native App Store / Google Play subscription sheet is presented.
3. **Given** a user who has previously purchased, **When** they tap "Restore purchases", **Then** their subscription status is restored.
4. **Given** any paywall, **When** displayed, **Then** cancel-anytime instructions and a restore purchases link are always visible.

---

### Edge Cases

- What happens when the AI plan generator produces an exercise that has no video in the library? → The exercise is automatically replaced with a validated alternative that has a video (same primary muscle, available equipment); the plan is never shown with a video-less exercise (FR-003b).
- What happens when an AI-generated plan fails validation for any other reason (volume, rest days, duration)? → The generator retries up to 2 times; if the plan still fails, the user receives the rule-based template plan (FR-002) with a note that they can regenerate their plan later from settings (FR-003b).
- How does the system handle a user with conflicting limitations (e.g., knee injury + lower-body goal)? → The plan avoids contraindicated exercises and the coach proactively explains substitutions.
- What happens when the LLM service is unavailable during a coach session? → The last generated plan continues to function; the coach shows a "temporarily unavailable" message.
- How does form check behave when the device has an older/slower CPU? → Confidence threshold is enforced; if below threshold, cues are suppressed rather than shown incorrectly.
- What happens if a user changes their equipment mid-program? → They can trigger a plan re-generation from settings, or use the coach to request substitutions exercise-by-exercise.
- What happens when a free user starts or continues a workout offline? → Logging, rest timer and text cues work normally; video areas show "Offline video requires Tekto Pro" without blocking the workout (FR-011, FR-030).
- How does the app handle a user in a storefront where no Pro product is available? → Purchase buttons are hidden and a localized "Tekto Pro is not yet available in your region" message is shown; "Restore purchases" stays visible and the free tier is unaffected (FR-031, FR-032). Prices are never hard-coded or converted by the app.

---

## Requirements *(mandatory)*

### Functional Requirements

**Onboarding & Plan Generation**

- **FR-001**: The system MUST present an onboarding quiz collecting: goal (muscle, strength, fat loss, general fitness), training level, days per week, session length, available equipment, and physical limitations or injuries.
- **FR-002**: The system MUST generate a 4–12 week periodized training plan with named exercises, sets, reps, rest periods and RPE/RIR targets within 30 seconds of onboarding completion. Pro users receive an AI-generated plan. Free users receive a rule-based plan built from one of the starter templates (FR-029), selected by equipment first, then level, then goal; the system adapts it to the user's chosen days per week (adding or merging sessions, up to a maximum of 4 sessions per week; a user who chooses 5–7 days receives 4 sessions and a non-blocking card explaining that Pro builds programs for 5 or more days) and session length (trimming exercises from the end of each session, keeping at least 3, then reducing sets and rest if needed). No AI call is made for free plans.
- **FR-002a**: Every plan, AI-generated or template-based, MUST pass the same plan validator (every exercise has a video, uses only the user's available equipment, rest days present, session fits within the chosen session length) before it is shown to the user.
- **FR-003b**: When an AI-generated plan fails validation: (1) any exercise without a video MUST be replaced automatically with a validated alternative (same primary muscle, available equipment) without a new AI call; (2) any other validation failure MUST trigger up to 2 retries (3 attempts in total); (3) if every attempt fails, the user MUST receive the rule-based template plan (FR-002) with a visible note that they can regenerate later. Onboarding MUST never end without a valid plan.
- **FR-003**: Every exercise in a generated plan MUST have a corresponding video in the exercise library; no plan may reference a movement without a video.
- **FR-004**: The system MUST offer a 7-day Pro free trial after onboarding, skippable by the user, without blocking access to the generated plan.
- **FR-005**: The system MUST support account creation via Apple Sign-In, Google Sign-In, or email/password.

**Workout Tracking**

- **FR-006**: The system MUST present a home screen showing today's planned workout with estimated duration and target muscle groups.
- **FR-007**: The system MUST provide a live workout screen allowing the user to log sets with weight, reps and an optional RPE rating per set.
- **FR-008**: The system MUST start a configurable rest timer automatically after each logged set.
- **FR-009**: The system MUST display suggested weights based on the user's history and the plan's progression targets.
- **FR-010**: The system MUST detect and display personal records (PR) in real time during a workout.
- **FR-011**: The system MUST work fully offline for the current day's workout for all users (set logging, rest timer, navigation between exercises, technique cues); data syncs when connectivity is restored. Offline exercise video is Pro-only (see FR-015); a free user offline sees the exercise's text cues and a message that offline video requires Pro, and the workout continues uninterrupted.
- **FR-012**: The system MUST sync workout data with Apple Health (iOS) and Google Health Connect (Android).

**Exercise Video Library**

- **FR-013**: The library MUST contain at least 150 exercises at launch, covering gym barbell, dumbbell, cable, bodyweight and resistance-band movements.
- **FR-014**: Each exercise MUST include: filmed video (front and side, looped, 5–15 s), target muscles, step-by-step technique cues, common mistakes, and easier/harder variations.
- **FR-015**: Pro users MUST be able to download the videos for all exercises in their active plan for offline use.

**AI Chat Coach (Pro)**

- **FR-016**: The AI coach MUST be accessible from any screen and receive contextual information about the screen the user is currently on.
- **FR-017**: The coach MUST ground all answers in the user's profile, current plan and training history.
- **FR-018**: The coach MUST support plan modifications on request (exercise swap, session shortening, deload) and require user confirmation before applying any change.
- **FR-019**: The coach MUST detect injury and pain language and respond with advice to consult a professional; it MUST NOT provide medical diagnoses.
- **FR-020**: Free users receive a maximum of 3 coach questions per week; Pro users have unlimited access.

**Camera Form Check (Pro)**

- **FR-021**: The form check MUST run entirely on-device using pose estimation; no camera frames may be transmitted to any server without explicit user action.
- **FR-022**: At launch, the form check MUST support at least 8 key lifts: squat, deadlift, bench press, overhead press, row, lunge, hip thrust, push-up.
- **FR-023**: The system MUST provide real-time rep counting and live form cues during the set, with no more than 3 cues on screen at any moment, ordered by severity.
- **FR-024**: After each set, the system MUST display a form score, the reps flagged, and one prioritized tip.
- **FR-025**: Form cues MUST only be displayed when pose estimation confidence exceeds the defined threshold; below threshold, cues are suppressed and the user is prompted to adjust setup.

**Adaptive Planning (Pro)**

- **FR-026**: The system MUST review logged performance weekly and adjust the following week's plan: progress load/reps when targets are met, maintain or reduce volume when sessions are missed or rated too hard. The review runs once per training week, at whichever comes first: the end of the user's training week (Sunday 23:59 in the user's local time zone) or the moment every session of that training week has been logged. It runs regardless of how many sessions were completed; skipped sessions are treated as missed and are an input to the adjustment, never a reason to skip the review.
- **FR-027**: Every plan adaptation MUST display a brief explanation card to the user explaining what changed and why.
- **FR-028**: Users MUST be able to swap any exercise for an equivalent alternative (same muscle group, available equipment) at any time.

**Monetization**

- **FR-029**: The system MUST enforce free-tier limits (3 starter plan templates, 3 coach questions/week, 1 form-check try per lift) and present a contextual paywall when limits are reached.
- **FR-030**: The paywall MUST NEVER interrupt a workout that is currently in progress.
- **FR-031**: The paywall MUST always display cancel-anytime instructions and a restore-purchases option.
- **FR-032**: The system MUST use App Store and Google Play regional pricing to offer locally appropriate prices.

**Localization & Accessibility**

- **FR-033**: The full UI, coach responses and all copy MUST be available in English and French; the user's language preference is set during onboarding and can be changed in settings.
- **FR-034**: The app MUST support kg and lb unit selection, persisted per user.
- **FR-035**: The app MUST meet WCAG 2.1 AA targets including dynamic type, screen-reader labels (VoiceOver / TalkBack), and captions on all exercise videos.

**Safety & Privacy**

- **FR-036**: A health disclaimer MUST be shown at onboarding before the first plan is generated.
- **FR-037**: All health and body data MUST be encrypted at rest and in transit; users MUST be able to export their data and delete their account from within the app.
- **FR-038**: The app MUST be GDPR-compliant.

---

### Key Entities

- **User**: Profile including goal, training level, equipment, limitations, language, unit preference, subscription status, and health sync settings.
- **Plan**: A structured 4–12 week training program belonging to a user; contains weeks, sessions and exercises; has a generation history and adaptation log.
- **Session**: A single training day within a plan; scheduled date, target muscles, ordered list of exercises with sets/reps/rest/RPE targets.
- **Exercise**: An entry in the master library; has video assets, muscle targets, technique cues, variations, and equipment tags.
- **WorkoutLog**: A user's recorded execution of a session; contains SetLog entries (actual weight, reps, RPE); drives adaptations and PR calculations.
- **SetLog**: One logged set; weight, reps performed, RPE given, timestamp.
- **CoachMessage**: A single turn in a coach conversation; references context (screen, session, plan) at the time of the question.
- **FormCheckSession**: One camera form check; linked to a SetLog; contains rep count, cues shown, form score, and a flag indicating any user-initiated share.
- **Subscription**: User's current plan tier (Free / Pro), store, billing period, trial status, expiry.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 70% of installs complete onboarding and receive a generated plan.
- **SC-002**: The app generates and displays a personalized plan in under 30 seconds after the last onboarding step.
- **SC-003**: Cold start time is under 2 seconds on a mid-range device.
- **SC-004**: Exercise videos begin playing in under 1 second on a 4G connection.
- **SC-005**: Form-check feedback is delivered in under 150 ms per frame on a supported device.
- **SC-006**: At least 30% of new users start the Pro free trial.
- **SC-007**: At least 35% of trials convert to a paid Pro subscription.
- **SC-008**: At least 40% of users are still logging workouts 4 weeks after sign-up.
- **SC-009**: Users log an average of 3 or more workouts per active week.
- **SC-010**: At least 50% of active Pro users run at least one camera form check per week.
- **SC-011**: AI coach answers receive a thumbs-up rating from at least 85% of rated responses.
- **SC-012**: The app achieves an average App Store and Google Play rating of 4.6 or above.
- **SC-013**: The backend and AI services maintain 99.5% uptime; when AI is unavailable, the last generated plan continues to function without error.
- **SC-014**: All user health data is encrypted; no camera frames leave the device without an explicit user action; GDPR compliance is verified before launch.

---

## Assumptions

- The app targets iOS 16+ and Android 10+ from a single cross-platform codebase; web and tablet optimizations are out of scope for the MVP.
- At least 150 filmed exercise videos will be available before launch; video production timeline is a separate workstream with studio/coach resources.
- The specific LLM and on-device pose-estimation library will be determined in the technical design phase (TRD); the spec is agnostic to vendor choices.
- Subscription billing is handled entirely through App Store and Google Play in-app purchase APIs; no direct payment processing is in scope for the MVP.
- Local payment methods (Wave, Orange Money, etc.) are post-MVP.
- English and French are the only supported languages at launch; the architecture supports adding more languages in future releases.
- The trademark clearance for "Tekto" in Classes 9 and 41 is assumed to be completed before launch (open question from PRD).
- Team size, budget, and target launch date are open questions to be resolved outside this spec.
- Nutritional tracking, social features, wearable integrations beyond Apple Health / Google Health Connect, and a web app are explicitly out of scope for the MVP.
- A human-reviewed content safety pass on the AI coach's guardrails will be conducted before launch to satisfy app store compliance.
