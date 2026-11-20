# Tekto video prompt pack: batch 2

Status: **done and frozen** (2026-11-18). 22 clips are delivered and in the library. The dead bug (42) was dropped after repeated failed tries and is replaced by `core-reverse-crunch.mp4` in [batch 3](video-prompts-batch-3.md). New clips go in batch 3, not here. Written 2026-11-18. Batch 1 is in [`video-prompts.md`](video-prompts.md); it is done and frozen.

## Rules for whoever works on this file (person or agent)

**You may change:**
- the clip prompts in Part A and Part B: wording, casting details or form cues, if a generation keeps failing;
- the **Status** column of the tracker below;
- nothing else: this batch is closed. Add new clips to [`video-prompts-batch-3.md`](video-prompts-batch-3.md).

**Do not change:**
- `video-prompts.md` (batch 1) or any clip in `design/videos/` that is already there, except `chest-bench-press.mp4` (Part A) and the four *Redo* clips in Part C, which are replaced;
- **file names** of existing entries: the ingest script (`content/videos/name-map.json`) and the app match clips by file name;
- the **Base style** and **Negative prompt**: they are shared with batch 1, so every clip in the app looks the same. You may only *add* words to the negative prompt for one clip, as Part A does;
- the **casting balance**: at least half of the clips have Black leads (research.md §16). If you change a lead, keep the totals at the end of this file true;
- clip **numbers**.

**When you add a clip:**
1. Add it to `content/videos/name-map.json` under `exercises`, mapped to its library slug, or `null` if it isn't in the library yet.
2. Add a row to the tracker.

**When clips are delivered:**
1. Put them in `design/videos/`.
2. Run `cd content/videos && node ingest.js`.
3. Set each delivered clip's tracker status to *Delivered* (passed ingest) or *Redo* (failed, with the reason).

## Tracker

| # | File | Lead | In library | Status |
|---|---|---|---|---|
| 01 | `chest-bench-press.mp4` (redo) | Black man | yes | Delivered |
| 24 | `legs-front-squat.mp4` | Black woman | yes (`front-squat`) | Delivered |
| 25 | `legs-deadlift.mp4` | Black man | yes (`deadlift`) | Delivered |
| 26 | `legs-bulgarian-split-squat.mp4` | white woman | yes (`bulgarian-split-squat`) | Delivered |
| 27 | `legs-leg-press.mp4` | Black man | yes (`leg-press`) | Delivered. Review 5 (2026-11-19): redone with Veo 3.1 Fast from a legs-extended start frame, better lit; knees to 90° then legs pushed straight; sped to 6.8 s |
| 28 | `legs-calf-raise.mp4` | South Asian man | yes (`calf-raise`) | Delivered |
| 29 | `legs-lying-leg-curl.mp4` | Black woman | yes (`lying-leg-curl`) | Delivered |
| 30 | `legs-bodyweight-squat.mp4` | East Asian man | yes (`bodyweight-squat`) | Delivered |
| 31 | `chest-db-bench-press.mp4` | Black woman | yes (`dumbbell-bench-press`) | Delivered |
| 32 | `chest-cable-fly.mp4` | Latino man | yes (`cable-fly`) | Delivered |
| 33 | `chest-dip.mp4` | Black man | yes (`chest-dip`) | Review 3 (2026-11-19, user remarks): redone from a bottom start frame; upper arms reach parallel |
| 34 | `chest-incline-push-up.mp4` | Black woman | yes (`incline-push-up`) | Delivered |
| 35 | `back-db-row.mp4` | Black woman | yes (`dumbbell-row`) | Delivered |
| 36 | `back-seated-cable-row.mp4` | East Asian woman | yes (`seated-cable-row`) | Delivered |
| 37 | `back-face-pull.mp4` | Black man | yes (`face-pull`) | Review 3 (2026-11-19, user remarks): redone standing about 1.5 m back so the cable stays taut; full arm extension |
| 38 | `shoulders-db-shoulder-press.mp4` | Black man | yes (`dumbbell-shoulder-press`) | Delivered |
| 39 | `shoulders-rear-delt-fly.mp4` | Middle Eastern woman | yes (`rear-delt-fly`) | Delivered (redo, Part C) |
| 40 | `arms-hammer-curl.mp4` | Black woman | yes (`hammer-curl`) | Delivered (redo, Part C) |
| 41 | `arms-overhead-triceps-extension.mp4` | white man | yes (`overhead-triceps-extension`) | Delivered |
| 42 | `core-dead-bug.mp4` | Black woman | no | **Dropped**: 8 tries never got the opposite arm and leg right. Replaced by 46 `core-reverse-crunch.mp4` in batch 3. Takes archived in `design/models test videos/first-takes/`. |
| 43 | `core-pallof-press.mp4` | Black man | yes (`pallof-press`) | Delivered |
| 44 | `glutes-glute-bridge.mp4` | Latina woman | yes (`glute-bridge`) | Delivered (redo, Part C) |
| 45 | `glutes-kettlebell-swing.mp4` | Black man | yes (`kettlebell-swing`) | Delivered |
"In library: no" means the clip is converted, but the app can't show it until the exercise is added to `content/exercises/exercises.json` with cues and captions in English and French (Video Gate).

Usable, but a coach should confirm the range before instructional use: `legs-bulgarian-split-squat.mp4` and `chest-dip.mp4` are both shallow.

No still photos are needed. The ingest makes `poster.jpg` and `thumb.jpg` from each clip, and those are the exercise's photos.

## Settings (same as batch 1)

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

---

## Part A · Redo one batch 1 clip

**01 · `chest-bench-press.mp4` (again)** (Black man, 30s)
The first clip lowered the bar to the neck and locked out over the face. The plates also changed size. Use this stricter prompt and add "bar over the face, bar to the neck, plates changing size" to the negative prompt.
> A muscular Black man in his 30s lies on a flat bench with his eyes directly under the racked bar, feet flat on the floor, performing a barbell bench press. Strict side view from the athlete's left at bench height, so the bar path is clearly visible. At lockout the bar is directly above his shoulders. He lowers it in a slight diagonal to touch his lower chest at nipple level, forearms vertical, elbows about 45 degrees from the torso, then presses it back up to above his shoulders. Both plates stay the same size and the bar stays straight. Two smooth reps, starting and ending at lockout.

## Part B · New exercises (24–45)

These 22 clips extend the library toward the 150 exercises needed at launch (task T022). Four of them match exercises already in the library: the deadlift, dumbbell bench press, dumbbell row and dumbbell shoulder press. 17 of the other 18 were added to the library on 2026-11-18, with cues and captions in English and French. The dead bug was dropped (see the tracker). Use the base style, negative prompt and settings from the top of this file.

### Legs

**24 · `legs-front-squat.mp4`** (Black woman, 30s)
> A strong Black woman in her 30s with her hair in a high bun performs a barbell front squat in a squat rack. The bar rests on the front of her shoulders, elbows high and pointing forward, fingertips under the bar. Side three-quarter view. She squats straight down with an upright torso until her thighs pass parallel, then drives up to standing. Two reps, starting and ending standing tall.

**25 · `legs-deadlift.mp4`** (Black man, 30s)
> A powerful Black man in his 30s performs a conventional barbell deadlift from the floor. Strict side view. Bar over mid-foot, flat back, chest up. He pushes the floor away and stands tall with hips and knees locking together, then lowers the bar back to the floor along his legs. Two reps, the plates resting on the floor at the start and end.

**26 · `legs-bulgarian-split-squat.mp4`** (woman, white, 20s)
> A fit white woman in her 20s holds a dumbbell in each hand, her back foot resting on a flat bench behind her, for a Bulgarian split squat. Side view. She lowers straight down until her front thigh is parallel to the floor, front knee over her toes, torso slightly forward, then stands back up. Two reps on the same leg.

**27 · `legs-leg-press.mp4`** (Black man, 20s)
> A Black man in his 20s sits in a matte black 45-degree leg press machine, feet shoulder-width on the platform. Side view. He lowers the platform under control until his knees reach about 90 degrees, lower back staying flat against the pad, then presses it back up without locking his knees hard. Two reps.

**28 · `legs-calf-raise.mp4`** (man, South Asian, 30s)
> A South Asian man in his 30s stands with the balls of his feet on the edge of a low black step, holding a dumbbell in one hand and a rack upright with the other. Side view, framed from the knees down to the hips so the calves are clear. He lowers his heels below the step, then rises onto his toes and pauses at the top. Two slow reps.

**29 · `legs-lying-leg-curl.mp4`** (Black woman, 20s)
> An athletic Black woman in her 20s lies face down on a matte black leg curl machine, the pad just above her heels. Side view. She curls her heels toward her glutes, hips staying on the pad, then lowers slowly to straight legs. Two reps.

**30 · `legs-bodyweight-squat.mp4`** (man, East Asian, 20s)
> An East Asian man in his 20s performs a bodyweight squat in a dark home-gym corner, arms reaching forward for balance. Front three-quarter view. Feet shoulder-width, he sits down and back until his thighs reach parallel with his chest up, then stands. Two reps.

### Chest

**31 · `chest-db-bench-press.mp4`** (Black woman, 30s)
> A strong Black woman in her 30s lies on a flat bench holding two dumbbells for a dumbbell bench press. Side three-quarter view. She lowers the dumbbells to the sides of her chest, elbows about 45 degrees from her torso, then presses them up over her shoulders. Two reps.

**32 · `chest-cable-fly.mp4`** (man, Latino, 30s)
> A Latino man in his 30s stands between two cable towers, holding a handle in each hand at shoulder height, one foot slightly forward. Front three-quarter view. With a soft bend in his elbows, he brings his hands together in front of his chest in a wide hugging arc, then opens back out under control. Two reps.

**33 · `chest-dip.mp4`** (Black man, 20s)
> A lean, muscular Black man in his 20s supports himself on parallel dip bars with straight arms. Side view. Leaning slightly forward, he lowers himself until his upper arms are about parallel to the floor, then pushes back up to straight arms. Two reps, no swinging.

**34 · `chest-incline-push-up.mp4`** (Black woman, 20s)
> A Black woman in her 20s performs push-ups with her hands on a flat bench. Side view. Her body stays in one straight line from head to heels; she lowers her chest to the edge of the bench, then pushes back to straight arms. Two reps.

### Back

**35 · `back-db-row.mp4`** (Black woman, 30s)
> A Black woman in her 30s performs a single-arm dumbbell row, one knee and one hand on a flat bench, back flat and parallel to the floor. Side view. She pulls the dumbbell to her hip, elbow close to her body, then lowers it to a straight arm. Two reps on the same side.

**36 · `back-seated-cable-row.mp4`** (woman, East Asian, 30s)
> An East Asian woman in her 30s sits at a seated cable row with a V-handle, knees slightly bent, torso upright. Side view. She pulls the handle to her lower ribs, squeezing her shoulder blades together, then lets her arms straighten forward without rounding her back. Two reps.

**37 · `back-face-pull.mp4`** (Black man, 30s)
> A Black man in his 30s stands facing a cable tower, holding a rope attachment set at face height. Front three-quarter view. He pulls the rope toward his face, hands splitting apart beside his ears and elbows high, then returns to straight arms. Two reps.

### Shoulders

**38 · `shoulders-db-shoulder-press.mp4`** (Black man, 20s)
> An athletic Black man in his 20s sits on an upright bench holding two dumbbells at shoulder height, palms forward. Front three-quarter view. He presses them overhead until his arms are straight, then lowers them back to his shoulders. Two reps.

**39 · `shoulders-rear-delt-fly.mp4`** (woman, Middle Eastern, 30s)
> A Middle Eastern woman in her 30s hinges forward at the hips with a flat back, a light dumbbell in each hand hanging below her chest. Side three-quarter view. With a soft bend in her elbows, she raises the dumbbells out to the sides to shoulder height, then lowers them slowly. Two reps.

### Arms

**40 · `arms-hammer-curl.mp4`** (Black woman, 20s)
> A Black woman in her 20s with long braids stands holding a dumbbell in each hand, palms facing her body. Front three-quarter view. Elbows pinned to her sides, she curls both dumbbells up with her palms still facing in, then lowers them to straight arms. Two reps.

**41 · `arms-overhead-triceps-extension.mp4`** (man, white, 30s)
> A white man in his 30s sits on an upright bench holding one dumbbell overhead with both hands. Side view. Keeping his upper arms still beside his head, he lowers the dumbbell behind his head by bending his elbows, then extends back to straight arms. Two reps.

### Core

**42 · `core-dead-bug.mp4`** (Black woman, 30s)
> A Black woman in her 30s lies on her back on a dark mat, arms reaching to the ceiling and knees bent at 90 degrees over her hips. Side view at floor level. Lower back pressed into the mat, she slowly extends her right arm overhead and her left leg out straight, returns, then repeats on the other side. One rep each side.

**43 · `core-pallof-press.mp4`** (Black man, 20s)
> A Black man in his 20s stands side-on to a cable tower holding a handle at the centre of his chest, feet shoulder-width. Front view. He presses the handle straight out in front of him and holds, resisting the cable pulling him sideways, then brings it back to his chest. Two reps, his torso not rotating.

### Glutes

**44 · `glutes-glute-bridge.mp4`** (woman, Latina, 20s)
> A Latina woman in her 20s lies on her back on a dark mat, knees bent and feet flat. Side view at floor level. She drives her hips up until her knees, hips and shoulders form a straight line, squeezes at the top, then lowers. Two reps.

**45 · `glutes-kettlebell-swing.mp4`** (Black man, 30s)
> A Black man in his 30s performs a two-handed kettlebell swing with a black kettlebell. Strict side view. He hinges at the hips with a flat back, swinging the kettlebell between his legs, then snaps his hips forward so it floats to chest height with straight arms. Two reps, the hips driving the movement, not the arms.

## Part C · Redo after review (2026-11-18)

The first versions of these four clips showed the wrong movement. The redos of 39, 40 and 44 passed review on 2026-11-18; 42 kept failing and was dropped; it is replaced in batch 3. Generate them again with these prompts, keeping the same number, file name and lead, and add the extra words to the negative prompt for that clip only. Save over the old file in `design/videos/`.

**39 · `shoulders-rear-delt-fly.mp4` (again)** (woman, Middle Eastern, 30s)
Extra negative prompt: "rowing, elbows bending to 90 degrees, dumbbells pulled to the ribs".
> A Middle Eastern woman in her 30s stands bent forward at the hips, torso almost parallel to the floor, flat back, a light dumbbell in each hand hanging straight down under her shoulders, palms facing each other. Front view, so both arms are visible. Keeping her arms almost straight, with only a slight fixed bend in the elbows, she opens her arms out to the sides like wings until her hands are level with her shoulders, making a T shape, then lowers them slowly back under her shoulders. Her elbows never bend further and the dumbbells never come toward her body. Two reps.

**40 · `arms-hammer-curl.mp4` (again)** (Black woman, 20s)
Extra negative prompt: "palms facing up, wrists rotating, supinated grip".
> A Black woman in her 20s with long braids stands holding a dumbbell in each hand at her sides, the dumbbells vertical like hammers, thumbs pointing forward and palms facing her thighs. Front view. Elbows pinned to her sides, she curls both dumbbells up to her shoulders while the dumbbells stay vertical and her thumbs point up at the top; her wrists never turn. She lowers them to straight arms. Two reps.

**42 · `core-dead-bug.mp4` (again)** (Black woman, 30s)
Extra negative prompt: "both arms moving together, both legs moving together, crunch, sit-up".
> A Black woman in her 30s lies on her back on a dark mat, both arms pointing straight up at the ceiling and both knees bent at 90 degrees above her hips, shins parallel to the floor. Side view at floor level. Lower back pressed into the mat, she slowly lowers only her right arm back behind her head and, at the same time, straightens only her left leg out low above the floor, while her left arm and right leg stay still. She returns to the start, then does the same with her left arm and right leg. One rep each side, ending in the start position.

**42 · `core-dead-bug.mp4` (second redo, dropped: kept for the record)** (Black woman, 30s)
The first redo moved the legs correctly, but only the arm nearest the camera moved; the far arm stayed pointing at the ceiling. A pure side view hides the far arm, so this prompt uses a high three-quarter view where both arms are visible.
Extra negative prompt: "both arms moving together, both legs moving together, one arm staying still the whole time, crunch, sit-up".
> A Black woman in her 30s lies on her back on a dark mat, both arms pointing straight up at the ceiling and both knees bent at 90 degrees above her hips, shins parallel to the floor. Camera high, at a three-quarter angle from her feet, so both arms and both legs are clearly visible. Lower back pressed into the mat. First she lowers her RIGHT arm back behind her head and, at the same time, straightens her LEFT leg out low above the floor, while her left arm and right knee stay still. She returns to the start. Then she lowers her LEFT arm behind her head and straightens her RIGHT leg, while her right arm and left knee stay still, and returns to the start. Each arm moves once, always with the leg on the opposite side. Ends in the start position.

**44 · `glutes-glute-bridge.mp4` (again)** (woman, Latina, 20s)
Extra negative prompt: "hips staying on the floor, lying still, no movement".
> A Latina woman in her 20s lies on her back on a dark mat, knees bent and feet flat about hip-width apart, arms flat at her sides. Strict side view at floor level. Pressing through her heels, she lifts her hips clearly off the mat, high enough that her knees, hips and shoulders form one straight diagonal line, holds for one second while squeezing her glutes, then lowers her hips back down to touch the mat. Two full reps with a clear rise and fall, starting and ending with her hips on the mat.

---

## Totals

Batch 2 has 22 new clips, plus the bench press redo:
- **14 Black leads** (7 men, 7 women), at numbers 24, 25, 27, 29, 31, 33, 34, 35, 37, 38, 40, 42, 43 and 45;
- **8 leads from other backgrounds.**

With batch 1, 28 of the 45 clips have Black leads.

A coach must check the form before any clip is used as an instruction video (see the notes in `video-prompts.md`).
