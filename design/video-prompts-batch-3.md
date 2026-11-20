# Tekto video prompt pack: batch 3

Status: **32 of 32 in the library** (2026-11-20; the diamond push-up was redone on 2026-11-19); coach checks are noted in the tracker. Written 2026-11-18. [Batch 4](video-prompts-batch-4.md) (the most-used gym exercises) goes first. Batches 1 and 2 are in [`video-prompts.md`](video-prompts.md) and [`video-prompts-batch-2.md`](video-prompts-batch-2.md); both are done and frozen.

Batch 3 has 32 clips, numbered 46–77:
- **46** replaces the dead bug (batch 2, clip 42), which failed 8 tries; see [Why the dead bug was dropped](#why-the-dead-bug-was-dropped).
- **47–77** widen the library across every kind of equipment the app offers. These are barbell, dumbbell, cable and machines, bodyweight, and resistance bands; FR-013 asks for bands, and the library has none yet.

## Rules for whoever works on this file (person or agent)

**You may change:**
- the clip prompts in this file: wording, casting details or form cues, if a generation keeps failing;
- the **Status** column of the tracker below;
- nothing else: numbers 78–100 belong to batch 4. Add new clips to [`video-prompts-batch-4.md`](video-prompts-batch-4.md), numbered from 101.

**Do not change:**
- `video-prompts.md` (batch 1), `video-prompts-batch-2.md` (batch 2), or any clip from those batches in `design/videos/`;
- **file names** of clips in this file: the ingest script (`content/videos/name-map.json`) and the app match clips by file name;
- the **Base style** and **Negative prompt**: they are shared with batches 1 and 2, so every clip in the app looks the same. You may only *add* words to the negative prompt for one clip, as the band clips do;
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

**Equipment words in the library:** the app only knows `barbell`, `dumbbell`, `cable`, `bodyweight` and `bands`.
- Machines (leg extension, pec deck) are `cable`.
- The kettlebell clip is `dumbbell`; its cues say "kettlebell or one dumbbell".

## Lessons from batches 1 and 2 (read before prompting)

- **The movement must be easy to see.** Pick the camera so every moving limb is visible: front or three-quarter for anything that moves sideways, side view for hinges, presses and bar paths.
- **Avoid opposite arm-and-leg patterns.** The models can't do them: the dead bug failed 8 tries, as the archive in `design/models test videos/first-takes/` shows. Prefer moves where both sides do the same thing, or where only one limb moves.
- **Say what stays still.** "Elbows stay pinned", "the torso does not rotate", "the dumbbells stay vertical". The hammer curl and rear delt fly only came out right once the prompt named what must not move.
- **Make the range explicit.** "Hips rise until knees, hips and shoulders form a line", "until the thighs are level". Vague prompts give tiny movements: the first glute bridge never left the mat.
- **Two reps, ending where it started,** so the loop is clean.
- **Start frame:** if the first frame is made from text rather than a photo, add this block or it comes out too bright: *"very dark low-key photo, most of the frame near-black charcoal with a deep navy-blue ambient tone; warm key light only on the athlete; no bright walls, no visible lamps, no warm light in the background."*
- **Bands:** say the band colour every time. Use matte black or slate blue: never yellow, red or green, which most real bands are.

## Tracker

| # | File | Equipment | Lead | In library | Status |
|---|---|---|---|---|---|
| 46 | `core-reverse-crunch.mp4` | bodyweight | Black woman | yes | Delivered |
| 47 | `back-band-pull-apart.mp4` | bands | Black man | yes | Delivered on redo 2 (takes 1–2: one arm moved or arms barely moved; fixed by a T-pose start frame) |
| 48 | `glutes-band-lateral-walk.mp4` | bands | East Asian woman | yes | Delivered (band slides a little on the thighs) |
| 49 | `arms-band-curl.mp4` | bands | Black woman | yes | Delivered |
| 50 | `arms-band-triceps-pushdown.mp4` | bands | white man | yes | Delivered (athlete small in frame) |
| 51 | `chest-band-chest-press.mp4` | bands | Black man | yes | Delivered |
| 52 | `back-band-row.mp4` | bands | South Asian woman | yes | Delivered |
| 53 | `shoulders-band-overhead-press.mp4` | bands | Black woman | yes | Delivered on redo 1 (take 1: hands opened, handles vanished) |
| 54 | `legs-sumo-deadlift.mp4` | barbell | Black woman | yes | Review 3 (2026-11-19, user remarks): redone from a lockout start frame; full lockout, hips through, bar to the floor |
| 55 | `chest-incline-bench-press.mp4` | barbell | Latino man | yes | Delivered |
| 56 | `back-pendlay-row.mp4` | barbell | Black man | yes | Delivered |
| 57 | `chest-close-grip-bench-press.mp4` | barbell | white woman | yes | Delivered |
| 58 | `shoulders-push-press.mp4` | barbell | Black man | yes | Review 3 (2026-11-19, user remarks): redone from a locked-out start frame (side view); dip, drive and full lockout |
| 59 | `legs-dumbbell-rdl.mp4` | dumbbell | Middle Eastern man | yes | Review 3 (2026-11-19, user remarks): redone from a bottom start frame; torso within about 15–20° of parallel, dumbbells at mid-shin. Review 4 (2026-11-19): redone with Veo 3.1 Fast; stands fully upright and hinges to about parallel; sped to 6.8 s |
| 60 | `legs-dumbbell-step-up.mp4` | dumbbell | Black woman | yes | Review 3 (2026-11-19, user remarks): redone on a lower box; box leg straightens and the trailing foot returns flat to the floor each rep. Review 4 (2026-11-19): alternating legs requested but failed 3 times (Omni side view, Veo side view, Veo front view): kept the single-leg clip; cues say do all reps on one leg, then switch. Needs real footage for an alternating version. Review 5 (2026-11-19): now ALTERNATES legs: one front-view right-leg rep from Veo, then the same rep mirrored (left leg), joined with 0.4 s crossfades and sped to 6.7 s. Review 6 (2026-11-19): knee-height box, brisk natural single rep, mirrored to alternate legs, 6.9 s. Review 7 (2026-11-19): mirror seams changed from crossfades (ghosting) to hard cuts while she stands still; 7.0 s |
| 61 | `shoulders-front-raise.mp4` | dumbbell | East Asian man | yes | Delivered |
| 62 | `arms-db-skull-crusher.mp4` | dumbbell | Black man | yes | Delivered on redo 3 (takes 1–3: elbows barely bent or it turned into a press; fixed by a new start frame with the dumbbells beside his head) |
| 63 | `chest-db-fly.mp4` | dumbbell | Latina woman | yes | Delivered |
| 64 | `legs-kettlebell-sumo-squat.mp4` | kettlebell | Black woman | yes | Review 3 (2026-11-19, user remarks): redone with Veo 3.1 Fast (Omni failed 4 more times: it either stood fully or squatted deep, never both); one full rep (deep squat, full stand) trimmed at the loop point and slowed to 4.9 s |
| 65 | `legs-leg-extension.mp4` | machine | white man | yes | Delivered on redo 3 (start frame with legs straight) — coach check: lowers only to about 45°, not to vertical shins. Review 4 (2026-11-19): redone with Veo 3.1 Fast; knees bend to about 90° at the bottom and legs lock straight; sped to 6.8 s |
| 66 | `back-straight-arm-pulldown.mp4` | cable | Black man | yes | Delivered |
| 67 | `arms-cable-curl.mp4` | cable | South Asian man | yes | Delivered |
| 68 | `core-cable-crunch.mp4` | cable | Black woman | yes | Review 3 (2026-11-19, user remarks): redone kneeling an arm's length back; cable runs in front of her head; elbows reach the thighs. Review 4 (2026-11-19): redone with Veo 3.1 Fast from a deeper start frame; head curls down close to the mat; sped to 6.8 s |
| 69 | `glutes-cable-kickback.mp4` | cable | Latina woman | yes | Delivered on redo 2 (take 3); cable faint but visible |
| 70 | `chest-pec-deck.mp4` | machine | Black man | yes | Review 3 (2026-11-19, user remarks): redone as a true chest fly from an arms-wide start frame; the old clip became shoulders-reverse-pec-deck.mp4 (batch 4 #82). Review 4 (2026-11-19): redone with Veo 3.1 Fast; hands meet in front of the chest; sped to 6.8 s. Review 5 (2026-11-19): redone with Veo 3.1 Fast from an arms-stretched-wide start frame; full stretch out and hands meet; sped to 6.8 s. Review 6 (2026-11-19): three-quarter high view; arms stay nearly straight and meet at arm's length in front |
| 71 | `shoulders-cable-lateral-raise.mp4` | cable | white woman | yes | Delivered |
| 72 | `legs-bodyweight-lunge.mp4` | bodyweight | Black man | yes | Delivered on redo 1 (take 1: feet cropped, too bright) |
| 73 | `chest-diamond-push-up.mp4` | bodyweight | East Asian woman | yes | Delivered on redo (2026-11-19) with Veo 3.1 Fast from the hands-close start frame: hands stay together in a diamond under the chest, two full reps; sped to 6.8 s. Wide-hands take archived as first-takes/chest-diamond-push-up-wide-hands.mp4 |
| 74 | `core-side-plank.mp4` | bodyweight | Black woman | yes | Delivered on redo 1 (take 1: never rendered; animated the wrong image). Straight-arm side plank |
| 75 | `back-inverted-row.mp4` | bodyweight | Middle Eastern woman | yes | Review 3 (2026-11-19, user remarks): redone on an empty Smith bar locked in its hooks (safer than a loose barbell in a rack). Review 4 (2026-11-19): redone with Veo 3.1 Fast on a fixed welded bar station; the bar stays still; sped to 6.8 s. Review 5 (2026-11-19): redone with Veo 3.1 Fast on a barbell resting on power rack safety arms; full pulls, body straight; sped to 6.8 s. Review 6 (2026-11-19): switched to a suspension-strap row (no bar, so nothing can pass through the head); realistic pull, body straight. Review 7 (2026-11-19): back to a bar (user preference): barbell in two separate squat stands, side view; chest to the bar, head clear. Review 8: the bar lifted ~16 px in the first rep; kept only the steady second rep, played twice with a hard cut (bar now within 2 px), 7.0 s |
| 76 | `glutes-single-leg-hip-thrust.mp4` | bodyweight | Black woman | yes | Delivered on redo 2 (start frame hips up) — coach check: top is a little short of full hip extension |
| 77 | `core-ab-wheel-rollout.mp4` | bodyweight | Black man | yes | Delivered on redo 3 (start frame fully rolled out; lead recast from a white man to a Black man in the redo prompt) |

Several of these fill links the library already points to but doesn't have yet:
- `bodyweight-lunge` and `dumbbell-rdl` are listed as easier versions;
- `pendlay-row`, `close-grip-bench-press`, `push-press`, `diamond-push-up` and `single-leg-hip-thrust` are listed as harder versions.

No still photos are needed. The ingest makes `poster.jpg` and `thumb.jpg` from each clip, and those are the exercise's photos.

**Credits:** 32 clips × 15 credits = 480 Flow credits, plus redos. Credits were topped up on 2026-11-18 (more than 2,000), so any order works. Clip 46 is still the most useful to do first, because it brings the core category back to full.

## Settings (same as batches 1 and 2)

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

**Band clips (47–53) add:** "band snapping, band disappearing, band changing colour, band passing through the body, green band, yellow band, red band".

---

## Replacement for the dead bug

### Why the dead bug was dropped

Every try of `core-dead-bug.mp4` got the opposite arm and leg wrong. Some moved only the near arm, some had the far arm stuck, some moved both arms together, and some were wrong from overhead too. The takes are in `design/models test videos/first-takes/`. The reverse crunch trains the same lower abs with both legs moving together, which the models handle well (see the hanging leg raise).

**46 · `core-reverse-crunch.mp4`** (Black woman, 30s)
> A Black woman in her 30s lies on her back on a dark mat, arms flat at her sides, knees bent at 90 degrees above her hips with both legs together. Strict side view at floor level. Keeping her knees together and her arms still, she curls her hips up off the mat, bringing her knees toward her chest, then lowers her hips slowly back to the mat with her knees still above her hips. Two reps, starting and ending in the same position. Her head stays on the mat.

## Resistance bands (47–53)

Every band is matte black or slate blue. Add the band words to the negative prompt.

**47 · `back-band-pull-apart.mp4`** (Black man, 20s)
> An athletic Black man in his 20s stands tall holding a matte black resistance band in front of his chest with both hands, arms straight, hands shoulder-width apart. Front view. Keeping his arms straight, he pulls the band apart by moving his hands out to the sides until the band touches his chest and his arms form a T, then slowly lets his hands come back together in front. Two reps. His shoulders stay down.

**48 · `glutes-band-lateral-walk.mp4`** (woman, East Asian, 20s)
> An East Asian woman in her 20s stands in a half squat with a short slate-blue loop band around both legs just above the knees, hands together at her chest. Front view, full body. Staying low, she takes two slow side steps to her right, keeping the band tight and her knees pushed out, then two side steps back to her left to the starting spot. Her feet never come fully together.

**49 · `arms-band-curl.mp4`** (Black woman, 20s)
> A Black woman in her 20s stands on the middle of a matte black resistance band, holding one end in each hand at her sides, palms facing forward. Front three-quarter view. Elbows pinned to her sides, she curls both hands up to her shoulders, stretching the band, then lowers them slowly to straight arms. Two reps. Her elbows never move forward.

**50 · `arms-band-triceps-pushdown.mp4`** (man, white, 40s)
> A white man in his 40s stands facing a squat rack with a matte black resistance band looped over the top bar, holding both ends at chest height, elbows bent and tucked to his sides. Side view. Keeping his upper arms still against his body, he pushes his hands down until his arms are straight, then lets them rise back to chest height. Two reps.

**51 · `chest-band-chest-press.mp4`** (Black man, 30s)
> A Black man in his 30s stands in a split stance with a matte black resistance band around his upper back, holding one end in each hand beside his chest, elbows bent. Side three-quarter view. He presses both hands straight forward until his arms are straight in front of his chest, then brings them back slowly beside his chest. Two reps. His torso stays upright.

**52 · `back-band-row.mp4`** (woman, South Asian, 30s)
> A South Asian woman in her 30s sits on the floor with her legs straight, a slate-blue resistance band looped around the soles of her feet, holding one end in each hand with straight arms. Strict side view at floor level. Sitting tall, she rows both hands to her lower ribs, squeezing her shoulder blades together, then lets her arms return to straight. Two reps. She does not lean back.

**53 · `shoulders-band-overhead-press.mp4`** (Black woman, 30s)
> A Black woman in her 30s stands on the middle of a matte black resistance band, holding one end in each hand at shoulder height, palms forward. Front view. She presses both hands straight overhead until her arms are straight, then lowers them slowly back to her shoulders. Two reps. Her lower back does not arch.

## Barbell (54–58)

**54 · `legs-sumo-deadlift.mp4`** (Black woman, 20s)
> A strong Black woman in her 20s stands with a very wide stance, toes turned out, gripping a loaded barbell on the floor with her hands inside her knees, arms straight. Front three-quarter view. With a flat back and chest up, she pushes her knees out and stands up tall with the bar, then lowers it back to the floor the same way. Two reps. Both plates stay the same size and the bar stays straight.

**55 · `chest-incline-bench-press.mp4`** (man, Latino, 30s)
> A Latino man in his 30s lies on a bench set to about 30 degrees, pressing a loaded barbell. Strict side view at bench height. From lockout over his shoulders he lowers the bar to his upper chest, just below the collarbones, elbows about 45 degrees from his body, then presses it back up over his shoulders. Two reps, starting and ending at lockout.

**56 · `back-pendlay-row.mp4`** (Black man, 30s)
> A Black man in his 30s stands bent over with his torso parallel to the floor, flat back, a loaded barbell resting on the floor under his shoulders. Strict side view. He pulls the bar explosively from the floor to his lower chest, then lowers it back to rest on the floor, his torso staying parallel the whole time. Two reps.

**57 · `chest-close-grip-bench-press.mp4`** (woman, white, 30s)
> A white woman in her 30s lies on a flat bench pressing a loaded barbell, her hands shoulder-width apart, closer than a normal bench press. Strict side view at bench height. Elbows tucked close to her body, she lowers the bar to her lower chest, then presses it back up over her shoulders. Two reps, starting and ending at lockout.

**58 · `shoulders-push-press.mp4`** (Black man, 20s)
> An athletic Black man in his 20s stands with a loaded barbell resting on his front shoulders, hands just outside them. Side view, full body. He dips a few centimetres by bending his knees with his torso upright, then drives up through his legs and presses the bar straight overhead to locked arms, then lowers it back to his shoulders. Two reps. His heels stay down at the dip.

## Dumbbell and kettlebell (59–64)

**59 · `legs-dumbbell-rdl.mp4`** (man, Middle Eastern, 30s)
> A Middle Eastern man in his 30s stands holding a dumbbell in each hand in front of his thighs, knees slightly bent. Strict side view. He pushes his hips back and slides the dumbbells down the front of his legs to mid-shin with a flat back, then drives his hips forward to stand tall. Two reps. His knee bend stays the same throughout.

**60 · `legs-dumbbell-step-up.mp4`** (Black woman, 30s)
> A Black woman in her 30s stands facing a sturdy knee-height plyo box, a dumbbell in each hand at her sides, her right foot flat on the box. Side view, full body. She pushes through her right foot to stand up tall on the box, bringing her left foot up beside it, then steps the left foot back down to the floor under control, her right foot staying on the box. Two reps on the same leg.

**61 · `shoulders-front-raise.mp4`** (man, East Asian, 30s)
> An East Asian man in his 30s stands tall holding a dumbbell in each hand in front of his thighs, palms facing his body. Side three-quarter view. With straight arms, he raises both dumbbells in front of him to shoulder height, then lowers them slowly. Two reps. His torso does not lean back.

**62 · `arms-db-skull-crusher.mp4`** (Black man, 40s)
> A Black man in his 40s lies on a flat bench holding a dumbbell in each hand above his chest, arms straight, palms facing each other. Strict side view at bench height. Keeping his upper arms still and pointing at the ceiling, he bends only his elbows to lower the dumbbells beside his head, then straightens his arms back up. Two reps.

**63 · `chest-db-fly.mp4`** (woman, Latina, 30s)
> A Latina woman in her 30s lies on a flat bench holding two dumbbells above her chest, palms facing each other, a soft bend in her elbows. Front view from the foot of the bench, so both arms are visible. Keeping the same elbow bend, she opens her arms wide out to the sides until her hands are level with the bench, then brings them back together above her chest. Two reps.

**64 · `legs-kettlebell-sumo-squat.mp4`** (Black woman, 40s)
> A Black woman in her 40s stands with a wide stance, toes turned out, holding one matte black kettlebell by the handle with both hands, arms straight down between her legs. Front view, full body. Chest up, she sits straight down until her thighs are level with the floor, knees pushed out over her toes, then stands back up. Two reps.

## Cable and machines (65–71)

**65 · `legs-leg-extension.mp4`** (man, white, 20s)
> A white man in his 20s sits on a matte black leg extension machine, back against the pad, the roller pad on the front of his ankles, knees bent at 90 degrees. Strict side view. He straightens both legs until they are level with the floor, squeezes, then lowers slowly back to 90 degrees. Two reps. His hips stay on the seat.

**66 · `back-straight-arm-pulldown.mp4`** (Black man, 30s)
> A Black man in his 30s stands facing a cable tower, hinged slightly forward, holding a straight bar attached to the high pulley with straight arms at eye level. Strict side view. Keeping his arms straight, he sweeps the bar down in an arc to his thighs, then lets it rise slowly back to eye level. Two reps. His elbows never bend.

**67 · `arms-cable-curl.mp4`** (man, South Asian, 20s)
> A South Asian man in his 20s stands facing a cable tower, holding a straight bar attached to the low pulley with an underhand grip, arms straight. Side view. Elbows pinned to his sides, he curls the bar up to his shoulders, then lowers it slowly to straight arms. Two reps. His body does not rock.

**68 · `core-cable-crunch.mp4`** (Black woman, 20s)
> A Black woman in her 20s kneels facing a cable tower, holding a rope attached to the high pulley beside her head with both hands. Strict side view. Keeping her hips still, she curls her torso down, bringing her elbows toward her knees, then rises slowly back to upright kneeling. Two reps. Her hips do not move back and forth.

**69 · `glutes-cable-kickback.mp4`** (woman, Latina, 20s)
> A Latina woman in her 20s faces a cable tower, hands holding the frame, an ankle strap on her left ankle attached to the low pulley. Strict side view, her left leg nearest the camera. Hips square and torso slightly forward, she kicks her straight left leg back and up behind her, squeezing her glute, then returns it slowly beside her right foot. Two reps with the left leg only. Her lower back does not arch.

**70 · `chest-pec-deck.mp4`** (Black man, 40s)
> A Black man in his 40s sits upright on a matte black pec deck machine, his forearms and hands on the two padded arms out to his sides at shoulder height. Front view, so both arms are visible. He brings the padded arms together in front of his chest, squeezes, then lets them open slowly back out to his sides. Two reps. His back stays against the pad.

**71 · `shoulders-cable-lateral-raise.mp4`** (woman, white, 20s)
> A white woman in her 20s stands side-on to a cable tower, holding a handle attached to the low pulley in her far hand, the cable crossing in front of her body, arm straight at her side. Front view, so the raising arm is clearly visible. With a slight bend in the elbow, she raises her arm out to the side up to shoulder height, then lowers it slowly. Two reps with the same arm.

## Bodyweight (72–77)

**72 · `legs-bodyweight-lunge.mp4`** (Black man, 20s)
> An athletic Black man in his 20s stands tall, hands on his hips. Side view, full body. He steps his right foot back into a reverse lunge, lowering until both knees reach about 90 degrees with his back knee just above the floor and his torso upright, then pushes through his front foot to return to standing. Two reps with the right leg stepping back each time.

**73 · `chest-diamond-push-up.mp4`** (woman, East Asian, 30s)
> An East Asian woman in her 30s holds a push-up position with her hands close together under her chest, thumbs and index fingers touching in a diamond shape, body in one straight line. Side three-quarter view at floor level. She lowers her chest to her hands, elbows staying close to her body, then pushes back up to straight arms. Two reps. Her hips do not sag.

**73 · redo (2026-11-19).** The delivered take has her hands shoulder-width apart, so it is a normal push-up. Start from a close-up start frame of the hands, and add "hands shoulder-width apart, wide hand position, normal push-up" to the negative prompt.
> Start frame: an East Asian woman in her 30s in a high push-up position on a dark mat, seen from a low front three-quarter angle. Both hands are together directly under her breastbone, the thumbs touching and the index fingers touching so the hands form a diamond-shaped gap. The hands are clearly visible in the foreground. Animate: she lowers her chest until it almost touches her hands, her elbows brushing her ribs, then pushes back up to straight arms. Her hands never move apart. Two reps.

**74 · `core-side-plank.mp4`** (Black woman, 30s)
> A Black woman in her 30s holds a side plank on her right forearm, elbow under her shoulder, feet stacked, body in one straight line from head to heels, left hand on her hip. Front view, so her whole body faces the camera. She slowly lowers her hips a few centimetres toward the mat, then lifts them back up into a straight line. Two slow reps, starting and ending in the straight side plank.

**75 · `back-inverted-row.mp4`** (woman, Middle Eastern, 20s)
> A Middle Eastern woman in her 20s hangs under a barbell set at waist height in a squat rack, gripping it with straight arms, heels on the floor and her body in one straight line. Strict side view. She pulls her chest up to the bar, squeezing her shoulder blades together, then lowers to straight arms. Two reps. Her hips do not sag.

**76 · `glutes-single-leg-hip-thrust.mp4`** (Black woman, 20s)
> A Black woman in her 20s sits on the floor with her upper back against a flat bench, her left foot flat on the floor and her right knee pulled in toward her chest. Strict side view. Pushing through her left heel, she lifts her hips until her left knee, hips and shoulders form a straight line, holds, then lowers her hips toward the floor. Two reps, the right knee held up the whole time.

**77 · `core-ab-wheel-rollout.mp4`** (man, Black, 30s)
> A Black man in his 30s with dark skin and a short beard is at the far end of an ab wheel rollout on a dark mat: knees on the mat, arms stretched straight forward past his head holding a matte black ab wheel on the floor far in front of him, body long and low, back flat. Strict side view at floor level. Keeping his back flat and his knees on the mat, he pulls the wheel slowly back until it is under his shoulders, then rolls it far forward again until he is fully stretched out. Two reps. Ends fully stretched out, as it started. (Redo 3 prompt: starting at full extension is what made the wheel travel; earlier takes that started kneeling only rolled a few centimetres.)

---

## Totals

Batch 3 has 32 clips:
- **18 Black leads** (9 men, 9 women), at numbers 46, 47, 49, 51, 53, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72, 74, 76 and 77 (77 was recast in its redo);
- **14 leads from other backgrounds.**

By equipment:
- bands: 7;
- barbell: 5;
- dumbbell: 5;
- kettlebell: 1;
- cable and machines: 7;
- bodyweight: 7.

With batches 1 and 2, the library would reach 70 exercises.

A coach must check the form before any clip is used as an instruction video.
