# Tekto video prompt pack: batch 4

Status: **14 of 23 delivered** (2026-11-20): 78, 81, 82, 83, 85, 86, 87, 88, 89, 90, 92, 93, 96, 97. Still to do: 80 (T-bar row: 7 failed tries, needs real footage) and 79, 84, 91, 94, 95, 98, 99, 100 (women-led). About 15 Flow credits left (resets Dec 17).
- [`video-prompts.md`](video-prompts.md) (batch 1) and [`video-prompts-batch-2.md`](video-prompts-batch-2.md) (batch 2) are done and frozen;
- [`video-prompts-batch-3.md`](video-prompts-batch-3.md) (batch 3) is still to generate.

Batch 4 has 23 clips, numbered 78–100. They are the exercises gym members use most that Tekto doesn't have yet. The list was checked against a popular-exercises list on 2026-11-18: everything else on it is already in the library or in batch 3. Its cardio entries (treadmill, bike, rower and so on) are left out, because the app tracks sets, reps and weight, not time or distance; adding them would need a spec change first.

## Rules for whoever works on this file (person or agent)

**You may change:**
- the clip prompts in this file: wording, casting details or form cues, if a generation keeps failing;
- the **Status** column of the tracker below;
- the fallback for clip 100, as described in its prompt;
- add new clips **at the end of the list**, numbered from 101. Use a file name of the form `<category>-<exercise>.mp4`, where the category is one of chest, back, legs, shoulders, arms, core or glutes. Biceps and triceps moves are `arms`.

**Do not change:**
- batches 1 and 2, or any clip from them in `design/videos/`;
- batch 3, except to point to this file;
- **file names** of clips in this file: the ingest script (`content/videos/name-map.json`) and the app match clips by file name;
- the **Base style** and **Negative prompt**: they are shared with every batch, so every clip in the app looks the same. You may only *add* words to the negative prompt for one clip;
- the **casting balance**: at least half of the clips have Black leads (research.md §16). If you change a lead, keep the totals at the end of this file true;
- clip **numbers**.

**When you add a clip:**
1. Add it to `content/videos/name-map.json` under `exercises`, mapped to `null` until it is in the library.
2. Add a row to the tracker.

**When clips are delivered:**
1. Put them in `design/videos/`.
2. Run `cd content/videos && node ingest.js`.
3. Review each clip frame by frame for the right movement, not only the technical checks.
4. Set each delivered clip's tracker status to *Delivered* (passed review) or *Redo* (failed, with the reason).
5. Add each passed clip to `content/exercises/exercises.json`, with cues and English and French captions (Video Gate). Then map it in `name-map.json`.

**Equipment words in the library:** the app only knows `barbell`, `dumbbell`, `cable`, `bodyweight` and `bands`. Machines (chest press, hack squat, leg curl and so on) are `cable`. The preacher curl's EZ bar is `barbell`.

## Lessons from earlier batches (read before prompting)

- **The movement must be easy to see.** Pick the camera so every moving limb is visible: front or three-quarter for anything that moves sideways, side view for hinges, presses and bar paths.
- **Avoid opposite arm-and-leg patterns and fast alternation.** The dead bug failed 8 tries. Clip 100 (mountain climbers) is the riskiest one here and has a fallback.
- **Rotation is hard.** The Arnold press (83) and Russian twist (99) say exactly what turns and what stays still. Check them closely.
- **Say what stays still.** "Elbows stay pinned", "hips stay on the seat". The hammer curl and rear delt fly only came out right once the prompt named what must not move.
- **Make the range explicit.** Vague prompts give tiny movements: the first glute bridge never left the mat.
- **Machines:** describe the machine's parts (seat, pads, handles, foot plate) and keep it matte black with no brand plate.
- **Two reps, ending where it started,** so the loop is clean.
- **Start frame:** if the first frame is made from text rather than a photo, add this block or it comes out too bright: *"very dark low-key photo, most of the frame near-black charcoal with a deep navy-blue ambient tone; warm key light only on the athlete; no bright walls, no visible lamps, no warm light in the background."*

## Tracker

| # | File | Equipment | Lead | In library | Status |
|---|---|---|---|---|---|
| 78 | `chest-decline-bench-press.mp4` | barbell | Black man | yes | Delivered (2026-11-19) with Veo 3.1 Fast from a start frame at the hardest point; sped to 6.8 s |
| 79 | `chest-machine-chest-press.mp4` | machine | white woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: turned into a fly, not a press |
| 80 | `back-t-bar-row.mp4` | machine | Black man | no | **Redo** (user review 2026-11-20): the chest-supported machine take was rejected as very bad; pulled. Seven Veo tries in total (5 landmine, 2 machine; the 2nd machine take split the lever and sent a second set of plates flying past his head). Needs real footage (T022) |
| 81 | `back-back-extension.mp4` | bodyweight | Latina woman | yes | Delivered (2026-11-19): start frame made by EDITING an existing batch-3 photo of a woman (new women-led prompts were refused that day); Veo 3.1 Fast; sped to 6.8 s |
| 82 | `shoulders-reverse-pec-deck.mp4` | machine | Black man | yes | Delivered early (2026-11-19) from the batch 3 pec deck clip, at the user's request; not the prompt below — coach check: he sits with his back to the pad rather than chest on the pad. Review 5 (2026-11-19): replaced with a proper reverse pec deck (Veo 3.1 Fast): facing the machine, chest on the pad, arms opening wide; sped to 6.8 s. Review 6 (2026-11-19): straight-behind symmetric take; both arms come forward and open to a T together. Review 7 (2026-11-19): starts with hands together in front and opens only to a T in line with the shoulders (no over-stretch); hands stay on the handles |
| 83 | `shoulders-arnold-press.mp4` | dumbbell | South Asian man | yes | Delivered (2026-11-19) on redo: take 1 had no wrist rotation (plain shoulder press); redo from a palms-facing-in start frame (Nano Banana 2.1) rotates correctly; sped to 6.8 s |
| 84 | `shoulders-upright-row.mp4` | barbell | Black woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: she squats and the bar tilts |
| 85 | `arms-barbell-curl.mp4` | barbell | Black man | yes | Delivered (2026-11-19) with Veo 3.1 Fast from a start frame at the hardest point; sped to 6.8 s (front three-quarter view) |
| 86 | `arms-preacher-curl.mp4` | barbell (EZ bar) | East Asian man | yes | Delivered (2026-11-19) with Veo 3.1 Fast from a start frame at the hardest point; sped to 6.8 s |
| 87 | `arms-concentration-curl.mp4` | dumbbell | Black woman | yes | Delivered (2026-11-19): start frame made by EDITING an existing batch-3 photo of a woman (new women-led prompts were refused that day); Veo 3.1 Fast; sped to 6.8 s |
| 88 | `arms-incline-db-curl.mp4` | dumbbell | Middle Eastern man | yes | Delivered (2026-11-19) with Veo 3.1 Fast from a start frame at the hardest point; sped to 6.8 s |
| 89 | `arms-triceps-pushdown.mp4` | cable | Black man | yes | Delivered (2026-11-19) on redo: take 1 moved only from thighs to belly; redo with explicit full range; sped to 6.8 s |
| 90 | `arms-bench-dip.mp4` | bodyweight | white man | yes | Delivered (2026-11-19) with Veo 3.1 Fast from a start frame at the hardest point; sped to 6.8 s |
| 91 | `arms-assisted-dip.mp4` | machine | Black woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: almost no movement |
| 92 | `legs-seated-leg-curl.mp4` | machine | Latino man | yes | Delivered on redo (2026-11-20): new legs-straight start frame with the ankles on top of the roller; heels curl down and back under the seat; Veo 3.1 Fast; sped to 6.8 s |
| 93 | `legs-hack-squat.mp4` | machine | Black man | yes | Delivered on redo (2026-11-20): new near-top start frame; the sled carriage now slides down and up the rails with him; Veo 3.1 Fast; sped to 6.8 s |
| 94 | `legs-seated-calf-raise.mp4` | machine | East Asian woman | no | To do — edited start frame is weak (a bench, not a calf raise machine); not animated |
| 95 | `glutes-hip-abduction.mp4` | machine | Black woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: knees barely move |
| 96 | `glutes-cable-pull-through.mp4` | cable | white woman | yes | Delivered (2026-11-19): start frame made by EDITING an existing batch-3 photo of a woman (new women-led prompts were refused that day); Veo 3.1 Fast; sped to 6.8 s — coach check: hinge depth is moderate |
| 97 | `core-crunch.mp4` | bodyweight | Black man | yes | Delivered on redo (2026-11-19): first take barely moved; second from a lying-flat start frame (edit) curls up and back; Veo; sped to 6.8 s |
| 98 | `core-sit-up.mp4` | bodyweight | South Asian woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: small movement, never lies back |
| 99 | `core-russian-twist.mp4` | dumbbell | Black woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: no rotation (mirror plan: one twist to the right, then mirrored) |
| 100 | `core-mountain-climber.mp4` | bodyweight | Latina woman | no | Redo — start frame made by editing a batch-3 woman photo (2026-11-19), but the Veo take failed: the leg kicks out sideways |

No still photos are needed. The ingest makes `poster.jpg` and `thumb.jpg` from each clip, and those are the exercise's photos.

**Credits:** 23 clips × 15 credits = 345 Flow credits, plus redos. There are enough (topped up on 2026-11-18).

## Settings (same as every batch)

- 9:16 vertical, 1080×1920 if possible (at least 720×1280).
- 5 seconds (4–6 is fine), 24 or 30 fps.
- Lowest motion setting, with the camera locked.
- MP4 (H.264), saved with the exact file name from the tracker.
- Check before saving:
  - same person throughout;
  - the first and last frames match;
  - the form looks right: the bar path is clear and the plates don't change size;
  - there's no text or logo.

## Base style (paste first, every time)

> Cinematic vertical 9:16 fitness footage, photoreal, shot on a 35mm lens at chest height, locked-off tripod camera with no camera movement. A dark, moody premium gym: near-black charcoal background (#0F1014) with soft haze. Lighting is a warm key light on the athlete's face and body, plus a cool pale-blue rim light (#9DB8FF) outlining the silhouette, keeping deep skin tones rich, detailed and well exposed against the dark background. Fitted gym clothing in black, charcoal or slate grey. Matte black equipment. Calm, controlled, slow tempo. Seamless loop: the final frame matches the first frame. Single athlete, no other people. No text, no logos, no brand marks, no watermarks.

## Negative prompt

> text, captions, logos, brand names, watermark, yellow, red, neon, extra limbs, extra fingers, distorted hands, warped barbell, bending bar, morphing weights, face changing, camera shake, zoom, cuts, crowd, mirror reflections, rounded lower back, knees caving inward, jerky motion, slow motion blur, overexposed skin, underexposed face

**Machine clips add:** "brand plate, logo on the machine, chrome, colourful upholstery, weight stack numbers".

---

## Chest (78–79)

**78 · `chest-decline-bench-press.mp4`** (Black man, 30s)
> A muscular Black man in his 30s lies on a decline bench, head lower than his hips, his legs hooked under the foot pads, pressing a loaded barbell. Strict side view at bench height. From lockout over his shoulders, he lowers the bar to his lower chest, elbows about 45 degrees from his body, then presses it back up over his shoulders. Two reps, starting and ending at lockout. Both plates stay the same size.

**79 · `chest-machine-chest-press.mp4`** (woman, white, 30s)
> A white woman in her 30s sits upright on a matte black seated chest press machine, back against the pad, holding the two handles beside her chest. Side three-quarter view. She presses the handles forward until her arms are straight, then lets them come back slowly beside her chest. Two reps. Her back stays against the pad.

## Back (80–81)

**80 · `back-t-bar-row.mp4`** (Black man, 20s)
> An athletic Black man in his 20s stands astride a landmine barbell, one end fixed to the floor behind him and plates on the free end in front. He holds a V-handle under the plates with both hands, hinged forward to about 45 degrees with a flat back and soft knees. Strict side view. He rows the plates up toward his chest, squeezing his shoulder blades together, then lowers them to straight arms. Two reps. His torso angle stays the same.

**81 · `back-back-extension.mp4`** (woman, Latina, 30s)
> A Latina woman in her 30s is on a matte black 45-degree back extension bench, her hips on the pad, ankles locked under the foot pads, arms crossed over her chest. Strict side view. From her body in one straight line, she hinges at the hips to lower her torso toward the floor with a flat back, then raises it back up to a straight line from head to heels, without arching past it. Two reps.

## Shoulders (82–84)

**82 · `shoulders-reverse-pec-deck.mp4`** (Black woman, 30s)
> A Black woman in her 30s sits facing the pad of a matte black pec deck machine, chest against the pad, holding the two handles straight in front of her at shoulder height, arms almost straight. Rear three-quarter view, so both arms and her upper back are visible. Keeping her arms almost straight, she opens them out to the sides until they are in line with her shoulders, squeezing her shoulder blades, then brings them slowly back in front. Two reps. Her chest stays on the pad.

**83 · `shoulders-arnold-press.mp4`** (man, South Asian, 30s)
> A South Asian man in his 30s sits on an upright bench holding two dumbbells in front of his shoulders, palms facing him, elbows in front of his body. Front view. As he presses the dumbbells overhead, he turns his wrists so his palms face forward at the top with arms straight. He lowers them back down, turning his palms back toward him, to the start in front of his shoulders. Two reps. Only his wrists and arms turn; his torso stays still and faces the camera.

**84 · `shoulders-upright-row.mp4`** (Black woman, 20s)
> A Black woman in her 20s stands tall holding a barbell in front of her thighs with an overhand grip, hands shoulder-width apart. Front three-quarter view. Leading with her elbows, she pulls the bar straight up along her body to just below chest height, elbows no higher than her shoulders, then lowers it slowly to her thighs. Two reps. The bar stays close to her body.

## Arms (85–91)

**85 · `arms-barbell-curl.mp4`** (Black man, 30s)
> A muscular Black man in his 30s stands tall holding a barbell in front of his thighs with an underhand grip, hands shoulder-width apart. Side view. Elbows pinned to his sides, he curls the bar up to his shoulders, then lowers it slowly to straight arms. Two reps. His body does not swing.

**86 · `arms-preacher-curl.mp4`** (man, East Asian, 20s)
> An East Asian man in his 20s sits at a matte black preacher curl bench, the backs of his upper arms flat on the angled pad, holding an EZ curl bar with an underhand grip, arms almost straight. Strict side view. Keeping his upper arms on the pad, he curls the bar up toward his shoulders, then lowers it slowly until his arms are almost straight. Two reps.

**87 · `arms-concentration-curl.mp4`** (Black woman, 30s)
> A Black woman in her 30s sits on the end of a flat bench, legs apart, leaning slightly forward, her right elbow braced against the inside of her right thigh, a dumbbell hanging at arm's length. Front three-quarter view. Keeping her elbow on her thigh, she curls the dumbbell up toward her shoulder, then lowers it slowly to a straight arm. Two reps with the right arm only. Her upper arm does not move.

**88 · `arms-incline-db-curl.mp4`** (man, Middle Eastern, 30s)
> A Middle Eastern man in his 30s lies back on a bench set to about 45 degrees, arms hanging straight down behind his torso, a dumbbell in each hand, palms forward. Side view. Keeping his upper arms still and pointing at the floor, he curls both dumbbells up toward his shoulders, then lowers them slowly to straight arms. Two reps. His elbows do not move forward.

**89 · `arms-triceps-pushdown.mp4`** (Black man, 40s)
> A Black man in his 40s stands facing a cable tower, holding a short straight bar attached to the high pulley with an overhand grip at chest height, elbows bent and tucked to his sides. Side view. Keeping his upper arms still against his body, he pushes the bar down until his arms are straight, then lets it rise slowly back to chest height. Two reps.

**90 · `arms-bench-dip.mp4`** (man, white, 20s)
> A white man in his 20s sits on the edge of a flat bench with his hands on the edge beside his hips, fingers forward, then moves his hips off the bench with his legs straight out in front and heels on the floor. Strict side view. Keeping his back close to the bench, he bends his elbows to lower his hips until his upper arms are level with the floor, then pushes back up to straight arms. Two reps.

**91 · `arms-assisted-dip.mp4`** (Black woman, 40s)
> A Black woman in her 40s kneels on the padded platform of a matte black assisted dip machine, gripping the two dip handles with straight arms, torso upright. Strict side view. She bends her elbows to lower her body until her upper arms are level with the floor, the platform moving down with her, then presses back up to straight arms. Two reps. Her elbows stay pointing back.

## Legs (92–94)

**92 · `legs-seated-leg-curl.mp4`** (man, Latino, 30s)
> A Latino man in his 30s sits on a matte black seated leg curl machine, back against the pad, thigh pad locked over his knees, the lower pad behind his ankles with legs straight. Strict side view. He curls his heels down and back under the seat, then lets his legs return slowly to straight. Two reps. His hips stay on the seat.

**93 · `legs-hack-squat.mp4`** (Black man, 30s)
> A strong Black man in his 30s stands in a matte black hack squat machine, his back flat against the angled back pad and his shoulders under the shoulder pads, feet shoulder-width on the foot plate. Strict side view. He squats down along the machine's angle until his thighs are level with the foot plate, then pushes back up without locking his knees. Two reps. His back stays on the pad.

**94 · `legs-seated-calf-raise.mp4`** (woman, East Asian, 30s)
> An East Asian woman in her 30s sits on a matte black seated calf raise machine, the knee pad resting on her lower thighs, the balls of her feet on the foot bar with her heels hanging off. Strict side view, close enough to see her ankles clearly. She lowers her heels below the bar, then rises as high as she can onto the balls of her feet, and lowers again. Two reps. Her knees stay at 90 degrees.

## Glutes (95–96)

**95 · `glutes-hip-abduction.mp4`** (Black woman, 20s)
> A Black woman in her 20s sits upright on a matte black hip abduction machine, back against the pad, the outside of her knees against the two leg pads, knees together. Front view, so both legs are visible. She pushes her knees out to the sides against the pads as wide as she can, holds, then lets them come back together slowly. Two reps. Her back stays against the pad.

**96 · `glutes-cable-pull-through.mp4`** (woman, white, 30s)
> A white woman in her 30s stands facing away from a cable tower, feet wider than her hips, holding a rope attached to the low pulley between her legs with both hands. Strict side view. With a flat back and soft knees, she hinges at the hips so the rope travels back between her legs, then drives her hips forward to stand tall, squeezing her glutes, the rope ending in front of her hips. Two reps. Her arms stay straight; the hips do the work.

## Core (97–100)

**97 · `core-crunch.mp4`** (Black man, 20s)
> An athletic Black man in his 20s lies on his back on a dark mat, knees bent, feet flat, fingertips lightly behind his ears. Strict side view at floor level. He curls his shoulders up off the mat toward his knees, his lower back staying on the mat, then lowers his shoulders slowly back down. Two reps. He does not pull on his head.

**98 · `core-sit-up.mp4`** (woman, South Asian, 20s)
> A South Asian woman in her 20s lies on her back on a dark mat, knees bent, feet flat and anchored, arms crossed over her chest. Strict side view at floor level. She curls all the way up until her chest is near her knees, then lowers her back slowly to the mat. Two reps. Her feet stay on the floor.

**99 · `core-russian-twist.mp4`** (Black woman, 30s)
> A Black woman in her 30s sits on a dark mat, knees bent and heels on the floor, leaning back to about 45 degrees with a straight back, holding one dumbbell with both hands in front of her chest. Front view, so both sides of her body are visible. She turns her shoulders and chest to her right, bringing the dumbbell beside her right hip, then turns back through the centre to her left hip, and returns to the centre. Two slow turns each side. Her hips and knees stay still; only her shoulders and chest turn.

**100 · `core-mountain-climber.mp4`** (woman, Latina, 20s)
> A Latina woman in her 20s holds a high plank on a dark mat, hands under her shoulders, body in one straight line. Strict side view at floor level. Slowly and with control, she brings her right knee forward under her chest, then returns it to the plank. Then she brings her left knee forward under her chest and returns it. One rep each side at a slow tempo. Her hips stay level with her shoulders.

*Fallback for 100:* if the alternating legs fail after two tries, generate `core-plank-knee-tuck.mp4` instead, numbered 101, and mark 100 *Dropped*. It is the same plank, with one knee tucked under the chest and returned, using the same leg twice. Add it to the tracker and the name map.

---

## Totals

Batch 4 has 23 clips:
- **12 Black leads** (7 men, 5 women), at numbers 78, 80, 82, 84, 85, 87, 89, 91, 93, 95, 97 and 99 (82 is now a man: its clip came early from batch 3);
- **11 leads from other backgrounds.**

By equipment:
- barbell: 5;
- dumbbell: 4;
- cable and machines: 9;
- bodyweight: 5.

With batches 1–3, the library would reach 93 exercises, short of the 150 FR-013 needs at launch (task T022).

A coach must check the form before any clip is used as an instruction video. The upright row (84) needs a shoulder contraindication in the library, and the bench dip (90) needs shoulder and wrist ones.
