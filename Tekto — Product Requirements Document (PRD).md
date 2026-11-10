# Tekto — Product Requirements Document (PRD)

Nov 9, 2026 · @Andy Coul · Draft v0.1

## Overview

Tekto is a premium, AI-first strength training app for iOS and Android that builds a personal program, shows every exercise on real filmed video, checks form through the camera and answers questions through an AI coach.

**Problem.** Most lifters train without a plan that adapts to them. Beginners do not know what to do or how to do it safely; experienced lifters stall because their program never adjusts. Human coaching fixes both but is a high monthly cost most people cannot sustain.

**Vision.** A personal strength coach in your pocket: it plans, demonstrates, watches and adapts, for the price of a gym snack per week.

**Positioning.** Premium look and feel, science-based programming, and AI that does real work (planning, form feedback, coaching), not a chatbot bolted on.

**Name.** Tekto comes from the Greek *tekton*, "builder". Tagline: *Tekto — Build your strength.*

**Platforms.** iOS and Android from one cross-platform codebase, global launch in English and French.

## Goals and success metrics

Year-one goal: a paying base that proves people will pay for AI coaching, measured by trial conversion and 90-day retention. The targets below are starting assumptions to validate during the beta.

| Metric | Definition | Target (first 12 months) |
| --- | --- | --- |
| Onboarding completion | Installs that finish onboarding and get a plan | ≥ 70% |
| Trial start rate | New users who start the Pro free trial | ≥ 30% |
| Trial to paid | Trials that convert to a paid Pro plan | ≥ 35% |
| Week-4 retention | Users still logging workouts 4 weeks after signup | ≥ 40% |
| Workouts per active user | Logged sessions per active user per week | ≥ 3 |
| Form-check usage | Pro users who run at least one camera check per week | ≥ 50% |
| Coach satisfaction | Thumbs-up rate on AI coach answers | ≥ 85% |
| App Store rating | Average rating on both stores | ≥ 4.6 |

North-star metric: **weekly completed workouts per paying user**, because it ties revenue to real training.

## Target users and personas

Tekto serves four personas from day one; onboarding detects the level and adapts the experience, so one app fits all four without separate modes.

| Persona | Who they are | Main need | What Tekto gives them |
| --- | --- | --- | --- |
| Beginner | New to the gym, unsure what to do, fears injury or looking awkward | Clear guidance and confidence | Simple full-body plans, real video for every move, camera form check, coach answers to basic questions |
| Intermediate lifter | Trains 3 to 5 times a week, has plateaued | Structure and progression | Periodized plans, auto-progression of weights and reps, weekly adjustments from logged performance |
| Advanced lifter | Years of training, follows hypertrophy or strength science | Control and deep data | Editable programs, RPE/RIR tracking, volume per muscle, e1RM trends, deload logic |
| Home-gym user | Trains at home with dumbbells, bands or bodyweight | A plan that fits limited equipment | Equipment-aware plans, substitutions for every exercise, short sessions |

All personas: smartphone users aged 18 to 45, global, English or French speakers, willing to pay for a premium experience.

## Core features and MVP scope

The MVP ships four AI pillars plus the tracking that feeds them. P0 = must ship at launch, P1 = launch if ready, otherwise first update.

### 1. AI plan generator (P0)

- Onboarding quiz: goal (muscle, strength, fat loss, general fitness), level, days per week, session length, equipment, injuries or limits.
- Generates a 4 to 12 week program with splits, exercises, sets, reps, rest and target effort (RPE/RIR).
- Adapts weekly from logged results: progresses load when targets are hit, adjusts when sessions are missed or too hard.
- Exercise swap with equivalent alternatives (same muscle, available equipment).
- Must: every generated exercise exists in the video library; no plan references a movement without a video.

### 2. Real exercise video library (P0)

- Filmed demonstrations, not 3D animations: front and side angles, looped, 5 to 15 seconds.
- 150+ exercises at launch covering gym, dumbbell, band and bodyweight.
- Per exercise: target muscles, step-by-step cues, common mistakes, easier and harder variations.
- Offline download of the videos in the current plan.

### 3. AI chat coach (P0)

- LLM coach that knows the user's profile, plan and history.
- Answers training, technique and recovery questions; explains why the plan looks the way it does.
- Can make plan changes on request ("swap squats, my knee hurts", "I only have 30 minutes today") with user confirmation.
- Guardrails: no medical diagnosis; pain or injury questions trigger advice to see a professional.

### 4. Camera form check (P1 at launch, P0 by v1.1)

- On-device pose estimation during a set, phone placed on the floor or a bench.
- Launch set: 8 to 10 key lifts (squat, deadlift, bench press, overhead press, row, lunge, hip thrust, push-up, pull-up).
- Rep counting, range-of-motion check, 2 to 3 real-time cues per lift (knees caving, back rounding, depth).
- Post-set summary with a form score; video never leaves the phone unless the user chooses to share it.

### 5. Workout tracking and progress (P0)

- Live workout screen: sets, reps, weight, rest timer, plate calculator.
- History, personal records, estimated 1RM, volume per muscle group, body weight and photos.
- Apple Health and Google Health Connect sync.

### Out of MVP

- Nutrition tracking, social feed, wearables beyond Health sync, live human coaching, web app.

## User journeys

Five journeys define the MVP; each must be completable in the fewest taps possible.

**Onboarding to first plan (target: under 3 minutes)**

1. Welcome video and value promise.
2. Quiz: goal, level, days per week, session length, equipment, limitations.
3. Optional quick strength check (estimated weights for 3 lifts, or "I don't know").
4. AI generates the plan with a short explanation of why it fits.
5. Pro trial offer, skippable; account created with Apple, Google or email.

**Daily workout**

1. Home shows today's session, duration and target muscles.
2. Start: each exercise opens with its video and 3 key cues.
3. Log sets; rest timer starts automatically; suggested weight shown.
4. Finish: summary, records hit, effort rating; plan adjusts for next time.

**Form check (Pro)**

1. On a supported lift, tap the camera icon.
2. Guided phone placement with a framing outline.
3. Perform the set; Tekto counts reps and shows live cues.
4. Review: form score, the reps flagged, and one tip to fix.

**Ask the coach (Pro)**

1. Open the coach from any screen; context of that screen is passed in.
2. Ask in text or voice; get an answer grounded in the user's plan and history.
3. If the answer changes the plan, confirm before it is applied.

**Upgrade**

1. A free user hits a Pro feature (form check, coach, adaptive plan).
2. Paywall shows the feature's value with a short video.
3. Start a 7-day free trial; cancel anytime from the store.

## Premium UX and design principles

The interface must feel like a luxury product, because the look is the first reason someone believes a subscription is worth it.

- **Dark-first, high contrast.** Deep charcoal base, one bold accent color, generous spacing; a light theme follows the system setting.
- **Video is the hero.** Real footage fills the screen on every exercise; text stays secondary.
- **One action per screen.** During a workout the next step is always obvious and reachable with one thumb.
- **Motion with purpose.** Smooth transitions and haptics on set completion and new records; nothing decorative that slows the user.
- **Calm intelligence.** AI suggestions appear as short, confident cards with a "why" on tap, never pop-ups that interrupt a set.
- **Gym-proof.** Large tap targets, readable at arm's length, works offline in basement gyms.
- **Accessible.** Dynamic type, VoiceOver and TalkBack labels, captions on all videos.
- **Bilingual from day one.** English and French UI, coach answers in the user's language.

## Monetization

Tekto is freemium: the free tier makes the app genuinely useful for training, and Tekto Pro unlocks everything the AI does. Prices below are proposals to test, not decisions.

| Capability | Free | Pro |
| --- | --- | --- |
| Exercise video library | Full | Full + offline download |
| Workout logging, history, records | Yes | Yes |
| Plans | 3 starter templates | Unlimited AI-generated, adaptive plans |
| Weekly plan adaptation | No | Yes |
| AI chat coach | 3 questions per week | Unlimited |
| Camera form check | 1 try per lift | Unlimited |
| Advanced analytics (volume, e1RM, muscle balance) | Basic | Full |

**Proposed pricing (USD, store prices):** Pro monthly 12.99, Pro yearly 79.99 (about 49% saving, the default choice on the paywall), 7-day free trial on both. Use App Store and Google Play regional pricing so lower-income markets (including West Africa) pay local-level prices.

**Paywall rules**

- Shown after onboarding once, then only when a free user taps a Pro feature.
- Never blocks finishing a workout already started.
- Restore purchases and cancel instructions always visible.

**Later revenue (post-MVP):** lifetime plan, gift subscriptions, gym and coach partnerships (B2B seats).

## Non-functional requirements

These are the product-level requirements; the TRD will turn them into architecture and engineering choices.

| Area | Requirement |
| --- | --- |
| Platforms | iOS 16+ and Android 10+ from one cross-platform codebase; phones first, tablets supported |
| Performance | Cold start under 2 s; exercise video starts under 1 s on 4G; form-check feedback under 150 ms per frame |
| Offline | Today's workout, its videos and logging work with no connection; sync when back online |
| AI quality | Plans pass rule checks (volume, rest, balance) before reaching the user; coach answers grounded in the user's data |
| Privacy | Camera frames processed on-device; health data encrypted; GDPR-compliant, data export and account deletion in-app |
| Safety | Health disclaimer at onboarding; injury and pain topics routed to "see a professional"; no medical claims |
| Localization | English and French at launch; units in kg or lb; architecture ready for more languages |
| Reliability | 99.5% uptime for backend and AI services; graceful fallback when AI is unavailable (the last plan keeps working) |
| Accessibility | WCAG 2.1 AA targets, dynamic type, screen-reader labels, video captions |
| Store compliance | App Store and Google Play subscription rules, Apple Health and Health Connect data policies |

## Competitive landscape and differentiation

The market already has AI plan apps, form-check apps and AI chat coaches, but few combine all three with real filmed video and a premium design; that combination is Tekto's edge.

| Competitor | Strength | Gap Tekto fills |
| --- | --- | --- |
| Fitbod | Mature adaptive plans, large user base | No camera form check, limited coaching conversation |
| [MyoAdapt](https://apps.apple.com/us/app/-/id6480921131) | Science-based muscle-building plans | No form check or real-video focus |
| [RepWise AI Fitness Coach](https://play.google.com/store/apps/details?id=com.repwise.ai) | Camera rep counting and form cues | Narrow scope, no full adaptive programming |
| [TORQ Fitness](https://apps.apple.com/app/id6762485833) | AI chat coach with wearable integrations | Not built around strength programming and video |
| [Caliber](https://apps.apple.com/NZ/app/id1482405410) | Human coaches and video form reviews | Human coaching is slower and costs more |

**Tekto's differentiators**

1. All four AI pillars in one app: plan, video, form check, coach.
2. Real filmed video for every exercise, not animations.
3. Premium, bilingual (English and French) design, with regional pricing that opens markets competitors ignore, including Francophone Africa.

Competitor details come from their store listings as of November 2026 and should be re-checked before launch.

## Roadmap, risks and open questions

Tekto reaches the stores after two gates: the beta starts only when the core flows work end to end, and launch happens only when beta metrics hit the targets in Goals.

&#91;embedded content: Tekto roadmap · 5 phases, 2 gates\]

Form check ships as P1 at launch and becomes a full P0 feature in v1.1; dates are set in the TRD once team size and budget are known.

### Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Filming 150+ videos takes longer or costs more than planned | Launch slips | Film the most-used lifts first; batch studio shoots |
| Form-check accuracy varies with light, angle and clothing | Wrong cues damage trust | Limit to key lifts, show cues only above a confidence threshold, label as beta |
| LLM cost per user is too high | Margins shrink | Cache answers, use smaller models for routine replies, cap free usage |
| AI gives unsafe advice | User injury, store rejection | Rule-checked plans, safety guardrails, health disclaimer |
| Low conversion in price-sensitive markets | Slower revenue | Regional pricing; study local payment methods |
| Name or trademark conflict | Rebrand cost | Trademark attorney check in Classes 9 and 41 before launch |

### Open questions

- [ ] Team size and budget for the MVP?
- [ ] Target launch date?
- [ ] Who films the videos: in-house, partner coaches or a studio?
- [ ] Which LLM and pose-estimation stack, and what runs on-device vs in the cloud? (TRD)
- [ ] Local payments such as Wave or Orange Money for African markets, beyond store billing?
- [ ] Final prices after beta testing?
