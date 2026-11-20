# Tekto video prompt pack: batch 5

Status: **brief, 0 of 31 second-angle clips delivered** (written 2026-11-20). New exercises to reach 150 (FR-013) are listed at the end and still need prompts.

Batch 5 has two parts:
1. **Second-angle clips (102–132).** Spec FR-014 (clarified 2026-11-20): the 8 form-check lifts and their variants need a second video from another angle. No side-angle clip exists yet; the 11 `video_side_url` values in the library are placeholder Cloudflare addresses written before any clip was made.
2. **New exercises** for the 150-exercise launch minimum and for missing variations.

## Rules

Same rules as [`video-prompts-batch-4.md`](video-prompts-batch-4.md): the **Base style** and **Negative prompt** are shared and copied from there unchanged; at least half of the *new exercise* clips have Black leads (research.md §16); clip numbers and file names never change once set.

**Second-angle clips keep the lead, set, clothes, equipment and tempo of the main clip.** Make each one from a frame of the main clip (`design/videos/<main>.mp4`), not from a new photo, so both angles show the same person doing the same set.

**Which angle:** the angle that shows what the main clip can't.
- Squats, deadlifts, hip thrusts, glute bridges, rows, presses and push-ups: **side-on**, so depth, back angle and bar path are visible. If the main clip is already side-on, use a **45° front** view.
- Lunges and split squats: **45° front**, so knee tracking over the foot is visible. If the main clip is already 45°, use side-on.

**Naming:** `<main clip name>-side.mp4`, whatever the actual angle. The ingest step does not read second-angle clips yet: `name-map.json` maps one clip per exercise. Extending it (a `sides` map that fills `video_side_url` at upload, T114) is a small follow-up before these clips can be used.

**Review:** as for every clip, frame by frame, then the coach form review (constitution §IV, T141).

## Prompt template (second angle)

Paste the batch-4 **Base style**, then:

> Same athlete, same outfit, same equipment and same gym as the reference frame. Camera moved to a **[side-on / 45° front]** view at hip height, locked off. [Exercise] for two slow controlled reps, ending exactly where it started. Show [the form point: depth below parallel / neutral back / bar path over mid-foot / knee over the foot / full hip extension / elbows at 45°].

Then the batch-4 **Negative prompt**, plus: *different person, changed clothes, changed equipment*.

## Tracker — second angle

| # | File | Exercise | Form-check family | Main clip | Side video today | Status |
|---|---|---|---|---|---|---|
| 102 | `legs-back-squat-side.mp4` | Barbell Back Squat | squat | `legs-back-squat.mp4` | placeholder URL only | To do |
| 103 | `legs-goblet-squat-side.mp4` | Goblet Squat | squat | `legs-goblet-squat.mp4` | placeholder URL only | To do |
| 104 | `legs-front-squat-side.mp4` | Barbell Front Squat | squat | `legs-front-squat.mp4` | none | To do |
| 105 | `legs-bodyweight-squat-side.mp4` | Bodyweight Squat | squat | `legs-bodyweight-squat.mp4` | none | To do |
| 106 | `legs-kettlebell-sumo-squat-side.mp4` | Kettlebell Sumo Squat | squat | `legs-kettlebell-sumo-squat.mp4` | none | To do |
| 107 | `legs-deadlift-side.mp4` | Conventional Deadlift | deadlift | `legs-deadlift.mp4` | placeholder URL only | To do |
| 108 | `legs-romanian-deadlift-side.mp4` | Romanian Deadlift | deadlift | `legs-romanian-deadlift.mp4` | placeholder URL only | To do |
| 109 | `legs-sumo-deadlift-side.mp4` | Sumo Deadlift | deadlift | `legs-sumo-deadlift.mp4` | none | To do |
| 110 | `legs-dumbbell-rdl-side.mp4` | Dumbbell Romanian Deadlift | deadlift | `legs-dumbbell-rdl.mp4` | none | To do |
| 111 | `chest-bench-press-side.mp4` | Barbell Bench Press | bench press | `chest-bench-press.mp4` | placeholder URL only | To do |
| 112 | `chest-db-bench-press-side.mp4` | Dumbbell Bench Press | bench press | `chest-db-bench-press.mp4` | placeholder URL only | To do |
| 113 | `chest-incline-bench-press-side.mp4` | Incline Bench Press | bench press | `chest-incline-bench-press.mp4` | none | To do |
| 114 | `chest-close-grip-bench-press-side.mp4` | Close-Grip Bench Press | bench press | `chest-close-grip-bench-press.mp4` | none | To do |
| 115 | `chest-incline-db-press-side.mp4` | Incline Dumbbell Press | bench press | `chest-incline-db-press.mp4` | none | To do |
| 116 | `chest-decline-bench-press-side.mp4` | Decline Bench Press | bench press | `chest-decline-bench-press.mp4` | none | To do |
| 117 | `shoulders-overhead-press-side.mp4` | Barbell Overhead Press | overhead press | `shoulders-overhead-press.mp4` | placeholder URL only | To do |
| 118 | `shoulders-db-shoulder-press-side.mp4` | Dumbbell Shoulder Press | overhead press | `shoulders-db-shoulder-press.mp4` | none | To do |
| 119 | `shoulders-push-press-side.mp4` | Push Press | overhead press | `shoulders-push-press.mp4` | none | To do |
| 120 | `shoulders-arnold-press-side.mp4` | Arnold Press | overhead press | `shoulders-arnold-press.mp4` | none | To do |
| 121 | `back-barbell-row-side.mp4` | Barbell Bent-Over Row | row | `back-barbell-row.mp4` | placeholder URL only | To do |
| 122 | `back-db-row-side.mp4` | Single-Arm Dumbbell Row | row | `back-db-row.mp4` | none | To do |
| 123 | `back-pendlay-row-side.mp4` | Pendlay Row | row | `back-pendlay-row.mp4` | none | To do |
| 124 | `legs-walking-lunge-side.mp4` | Dumbbell Walking Lunge | lunge | `legs-walking-lunge.mp4` | none | To do |
| 125 | `legs-bodyweight-lunge-side.mp4` | Bodyweight Reverse Lunge | lunge | `legs-bodyweight-lunge.mp4` | none | To do |
| 126 | `legs-bulgarian-split-squat-side.mp4` | Bulgarian Split Squat | lunge | `legs-bulgarian-split-squat.mp4` | none | To do |
| 127 | `glutes-hip-thrust-side.mp4` | Barbell Hip Thrust | hip thrust | `glutes-hip-thrust.mp4` | placeholder URL only | To do |
| 128 | `glutes-single-leg-hip-thrust-side.mp4` | Single-Leg Hip Thrust | hip thrust | `glutes-single-leg-hip-thrust.mp4` | none | To do |
| 129 | `glutes-glute-bridge-side.mp4` | Glute Bridge | hip thrust | `glutes-glute-bridge.mp4` | none | To do |
| 130 | `chest-push-up-side.mp4` | Push-Up | push up | `chest-push-up.mp4` | placeholder URL only | To do |
| 131 | `chest-incline-push-up-side.mp4` | Incline Push-Up | push up | `chest-incline-push-up.mp4` | none | To do |
| 132 | `chest-diamond-push-up-side.mp4` | Diamond Push-Up | push up | `chest-diamond-push-up.mp4` | none | To do |

## New exercises (prompts to write)

- **Variation partners the library is missing** (FR-014: every exercise needs at least one variation):
  - `leg-extension` has no easier or harder partner: add a **single-leg leg extension** (machine).
  - `calf-raise` and `band-lateral-walk` get theirs from batch 4 (79–100: seated calf raise, hip abduction) once those clips are delivered.
  - Harder variations that were cleared because the exercise does not exist: **pause squat**, **deficit deadlift**, **weighted pull-up**, **barbell lunge**.
- **Count for FR-013:** 84 in the library today, 93 after batch 4 is finished. Batch 5 needs about **57 more** exercises, chosen across all equipment (including the new `machine`, `pull_up_bar`, `dip_station` and `bench` tags) to reach 150.
