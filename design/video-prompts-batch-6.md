# Tekto video prompt pack: batch 6 (modern gym equipment)

Status: **0 of 75 delivered** (written 2026-11-21). Waiting for Flow credits.

Batch 6 widens the library to the equipment people find in a modern gym: Smith machine, plate-loaded and selectorized machines (pendulum squat, belt squat, chest-supported row, hip thrust machine, reverse hyper), cable variations, trap bar, landmine (a barbell in a landmine or a corner), suspension straps, and more dumbbell, kettlebell and bodyweight choices. It also adds the variation partners the library was missing (single-leg leg extension, pause squat, deficit deadlift, chin-up, assisted pull-up).

The exercise data (names, cues, mistakes, muscles, equipment, variations, in English and French) is ready in [`content/exercises/pending-batch-6.js`](../content/exercises/pending-batch-6.js). This file is generated from it by `node make-batch6-brief.js`: edit the data, not this file, except for the **Status** column.

**Same rules, settings, base style and negative prompt as [batch 4](video-prompts-batch-4.md).** Clips 133–207. Casting: 45 of 75 leads are Black (at least half, research §16).

**Smith machine clips add to the negative prompt:** "bar tilting, bar leaving the rails, rails bending". **Suspension clips add:** "straps tangling, extra straps".

## When a clip passes review

1. Put it in `design/videos/` and run `cd content/videos && node ingest.js`.
2. Review the movement frame by frame and record the form review (T141). Set the status below.
3. Write `captions/<slug>_en.vtt` and `_fr.vtt` from the cues.
4. `cd content/exercises && node promote.js <slug>`: it moves the exercise into `exercises.json` and maps the clip.

## Tracker

| # | File | Equipment | Lead | In library | Status |
|---|---|---|---|---|---|
| 133 | `chest-smith-bench-press.mp4` | smith_machine + bench | Black man | no | To do |
| 134 | `chest-incline-machine-press.mp4` | machine | Black woman | no | To do |
| 135 | `chest-low-to-high-cable-fly.mp4` | cable | white woman | no | To do |
| 136 | `chest-db-floor-press.mp4` | dumbbell | Black man | no | To do |
| 137 | `chest-db-pullover.mp4` | dumbbell + bench | East Asian man | no | To do |
| 138 | `chest-suspension-push-up.mp4` | suspension + bodyweight | Black woman | no | To do |
| 139 | `chest-single-arm-cable-press.mp4` | cable | Latina woman | no | To do |
| 140 | `chest-smith-incline-press.mp4` | smith_machine + bench | Black man | no | To do |
| 141 | `arms-smith-close-grip-bench.mp4` | smith_machine + bench | South Asian woman | no | To do |
| 142 | `shoulders-smith-press.mp4` | smith_machine + bench | Black woman | no | To do |
| 143 | `back-smith-row.mp4` | smith_machine | Black man | no | To do |
| 144 | `legs-smith-rdl.mp4` | smith_machine | Black woman | no | To do |
| 145 | `legs-smith-split-squat.mp4` | smith_machine | white woman | no | To do |
| 146 | `glutes-smith-hip-thrust.mp4` | smith_machine + bench | Black man | no | To do |
| 147 | `legs-smith-reverse-lunge.mp4` | smith_machine | East Asian man | no | To do |
| 148 | `legs-smith-calf-raise.mp4` | smith_machine | Black woman | no | To do |
| 149 | `back-smith-shrug.mp4` | smith_machine | Latina woman | no | To do |
| 150 | `back-smith-inverted-row.mp4` | smith_machine + bodyweight | Black man | no | To do |
| 151 | `back-chin-up.mp4` | bodyweight + pull_up_bar | South Asian woman | no | To do |
| 152 | `back-assisted-pull-up.mp4` | machine | Black woman | no | To do |
| 153 | `back-chest-supported-db-row.mp4` | dumbbell + bench | Black man | no | To do |
| 154 | `back-machine-row.mp4` | machine | Black woman | no | To do |
| 155 | `back-landmine-row.mp4` | barbell | white woman | no | To do |
| 156 | `back-single-arm-cable-row.mp4` | cable | Black man | no | To do |
| 157 | `back-suspension-row.mp4` | suspension + bodyweight | East Asian man | no | To do |
| 158 | `back-rack-pull.mp4` | barbell | Black woman | no | To do |
| 159 | `back-half-kneeling-pulldown.mp4` | cable | Latina woman | no | To do |
| 160 | `back-db-shrug.mp4` | dumbbell | Black man | no | To do |
| 161 | `legs-trap-bar-deadlift.mp4` | trap_bar | South Asian woman | no | To do |
| 162 | `legs-smith-squat.mp4` | smith_machine | Black woman | no | To do |
| 163 | `legs-pendulum-squat.mp4` | machine | Black man | no | To do |
| 164 | `legs-belt-squat.mp4` | machine | Black woman | no | To do |
| 165 | `legs-single-leg-extension.mp4` | machine | white woman | no | To do |
| 166 | `legs-barbell-reverse-lunge.mp4` | barbell | Black man | no | To do |
| 167 | `legs-pause-squat.mp4` | barbell | East Asian man | no | To do |
| 168 | `legs-deficit-deadlift.mp4` | barbell | Black woman | no | To do |
| 169 | `legs-nordic-curl.mp4` | bodyweight + machine | Latina woman | no | To do |
| 170 | `legs-db-split-squat.mp4` | dumbbell | Black man | no | To do |
| 171 | `legs-landmine-squat.mp4` | barbell | South Asian woman | no | To do |
| 172 | `legs-single-leg-rdl.mp4` | dumbbell | Black woman | no | To do |
| 173 | `legs-cossack-squat.mp4` | bodyweight | Black man | no | To do |
| 174 | `legs-hip-adduction.mp4` | machine | Black woman | no | To do |
| 175 | `legs-hip-adduction-lean.mp4` | machine | white woman | no | To do |
| 176 | `legs-cable-hip-adduction.mp4` | cable | Black man | no | To do |
| 177 | `legs-band-hip-adduction.mp4` | bands | East Asian man | no | To do |
| 178 | `legs-side-lying-adduction.mp4` | bodyweight | Black woman | no | To do |
| 179 | `legs-copenhagen-plank.mp4` | bodyweight + bench | Latina woman | no | To do |
| 180 | `shoulders-machine-press.mp4` | machine | Black man | no | To do |
| 181 | `shoulders-landmine-press.mp4` | barbell | South Asian woman | no | To do |
| 182 | `shoulders-cable-y-raise.mp4` | cable | Black woman | no | To do |
| 183 | `shoulders-cable-rear-delt-fly.mp4` | cable | Black man | no | To do |
| 184 | `shoulders-machine-lateral-raise.mp4` | machine | Black woman | no | To do |
| 185 | `shoulders-z-press.mp4` | barbell | white woman | no | To do |
| 186 | `shoulders-band-face-pull.mp4` | bands | Black man | no | To do |
| 187 | `arms-behind-body-cable-curl.mp4` | cable | East Asian man | no | To do |
| 188 | `arms-spider-curl.mp4` | dumbbell + bench | Black woman | no | To do |
| 189 | `arms-machine-preacher-curl.mp4` | machine | Latina woman | no | To do |
| 190 | `arms-cable-overhead-extension.mp4` | cable | Black man | no | To do |
| 191 | `arms-db-kickback.mp4` | dumbbell + bench | South Asian woman | no | To do |
| 192 | `arms-ez-bar-skull-crusher.mp4` | barbell + bench | Black woman | no | To do |
| 193 | `arms-reverse-curl.mp4` | barbell | Black man | no | To do |
| 194 | `arms-cable-hammer-curl.mp4` | cable | Black woman | no | To do |
| 195 | `arms-suspension-curl.mp4` | suspension + bodyweight | white woman | no | To do |
| 196 | `glutes-machine-hip-thrust.mp4` | machine | Black man | no | To do |
| 197 | `glutes-reverse-hyper.mp4` | machine | East Asian man | no | To do |
| 198 | `glutes-kettlebell-deadlift.mp4` | dumbbell | Black woman | no | To do |
| 199 | `glutes-curtsy-lunge.mp4` | dumbbell | Latina woman | no | To do |
| 200 | `glutes-cable-abduction.mp4` | cable | Black man | no | To do |
| 201 | `glutes-frog-pump.mp4` | bodyweight | South Asian woman | no | To do |
| 202 | `core-hanging-knee-raise.mp4` | bodyweight + pull_up_bar | Black woman | no | To do |
| 203 | `core-cable-woodchop.mp4` | cable | Black man | no | To do |
| 204 | `core-landmine-rotation.mp4` | barbell | Black woman | no | To do |
| 205 | `core-hollow-hold.mp4` | bodyweight | white woman | no | To do |
| 206 | `core-suspension-tuck.mp4` | suspension + bodyweight | Black man | no | To do |
| 207 | `core-machine-crunch.mp4` | machine | East Asian man | no | To do |

## Prompts

Paste the base style first, then the prompt.

**133 · `chest-smith-bench-press.mp4`** (Black man) — Smith Machine Bench Press

> A Black man performs a Smith machine bench press using a matte black Smith machine (bar fixed on two vertical guide rails), a black adjustable bench. Camera: side view, full body in frame. Bench under the bar so it lands on your lower chest. Unhook, lower the bar to the chest with elbows at about 45 degrees. Press straight up and re-hook at the top. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bench too far forward, bar lands on the neck; bouncing the bar off the chest.

**134 · `chest-incline-machine-press.mp4`** (Black woman) — Incline Machine Press

> A Black woman performs an incline machine press using a matte black plate-loaded or selectorized machine. Camera: front three-quarter view, full body in frame. Seat set so the handles start level with your upper chest. Press up and forward until the arms are long, without locking. Lower slowly until you feel a stretch across the chest. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: shoulders rolling forward off the pad; cutting the range short at the bottom.

**135 · `chest-low-to-high-cable-fly.mp4`** (white woman) — Low-to-High Cable Fly

> A white woman performs a low-to-high cable fly using a matte black cable station. Camera: front view, full body in frame. Handles on the low pulleys, one step forward, slight bend in the elbows. Sweep the hands up and together to chin height. Lower back along the same arc with control. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bending the elbows into a press; shrugging at the top.

**136 · `chest-db-floor-press.mp4`** (Black man) — Dumbbell Floor Press

> A Black man performs a dumbbell floor press using matte black dumbbells or a kettlebell. Camera: side view, full body in frame. Lie on the floor, knees bent, dumbbells over the chest. Lower until the upper arms touch the floor, elbows at 45 degrees. Pause, then press back up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bouncing the elbows off the floor; flaring the elbows straight out.

**137 · `chest-db-pullover.mp4`** (East Asian man) — Dumbbell Pullover

> An East Asian man performs a dumbbell pullover using matte black dumbbells or a kettlebell, a black adjustable bench. Camera: side view, full body in frame. Upper back across the bench, one dumbbell held over the chest with both hands. Lower it back behind your head with soft elbows until you feel the stretch. Pull it back over the chest along the same arc. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bending the elbows to turn it into a triceps move; arching the lower back to go deeper.

**138 · `chest-suspension-push-up.mp4`** (Black woman) — Suspension Push-Up

> A Black woman performs a suspension push-up using black suspension trainer straps anchored overhead. Camera: side view, full body in frame. Hands in the handles, body leaning forward in a straight line. Lower the chest between the handles, elbows at 45 degrees. Press back up without letting the straps swing out. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips sagging; straps drifting wide at the bottom.

**139 · `chest-single-arm-cable-press.mp4`** (Latina woman) — Single-Arm Cable Press

> A Latina woman performs a single-arm cable press using a matte black cable station. Camera: front three-quarter view, full body in frame. Pulley at chest height, stand facing away in a split stance. Press the handle straight forward without twisting the hips. Return slowly until the hand is beside the chest. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rotating the torso to push; letting the elbow rise above the shoulder.

**140 · `chest-smith-incline-press.mp4`** (Black man) — Smith Machine Incline Press

> A Black man performs a Smith machine incline press using a matte black Smith machine (bar fixed on two vertical guide rails), a black adjustable bench. Camera: side view, full body in frame. Incline bench under the bar so it lands on your upper chest. Unhook and lower the bar to the upper chest, elbows at about 45 degrees. Press straight up and re-hook at the top. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bench set so the bar lands on the neck; lifting the hips off the bench.

**141 · `arms-smith-close-grip-bench.mp4`** (South Asian woman) — Smith Machine Close-Grip Bench Press

> A South Asian woman performs a Smith machine close-grip bench press using a matte black Smith machine (bar fixed on two vertical guide rails), a black adjustable bench. Camera: side view, full body in frame. Hands shoulder-width on the bar, bench set for the lower chest. Lower the bar with the elbows tucked close to the body. Press up until the arms are straight. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hands too close together; elbows flaring out.

**142 · `shoulders-smith-press.mp4`** (Black woman) — Smith Machine Shoulder Press

> A Black woman performs a Smith machine shoulder press using a matte black Smith machine (bar fixed on two vertical guide rails), a black adjustable bench. Camera: side view, full body in frame. Upright bench under the bar, bar just in front of your face. Lower the bar to chin height. Press up until the arms are long, back against the bench. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: arching off the backrest; lowering behind the neck.

**143 · `back-smith-row.mp4`** (Black man) — Smith Machine Bent-Over Row

> A Black man performs a Smith machine bent-over row using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Bar at knee height, hinge forward with a flat back, overhand grip. Row the bar to the lower ribs. Lower until the arms are straight; the torso stays still. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: standing up as you pull; rounding the back.

**144 · `legs-smith-rdl.mp4`** (Black woman) — Smith Machine Romanian Deadlift

> A Black woman performs a Smith machine romanian deadlift using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Stand tall holding the bar, feet hip-width under it. Push the hips back and slide the bar down the thighs, knees soft. Stop below the knees when you feel the stretch, then stand up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rounding the back to go lower; bending the knees into a squat.

**145 · `legs-smith-split-squat.mp4`** (white woman) — Smith Machine Split Squat

> A white woman performs a Smith machine split squat using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Bar across the upper back, long split stance under the bar. Lower straight down until the back knee nearly touches the floor. Push through the front foot to rise. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: front heel lifting; front knee caving in.

**146 · `glutes-smith-hip-thrust.mp4`** (Black man) — Smith Machine Hip Thrust

> A Black man performs a Smith machine hip thrust using a matte black Smith machine (bar fixed on two vertical guide rails), a black adjustable bench. Camera: side view, full body in frame. Upper back on the bench, bar padded across the hips, feet flat. Drive the hips up until the body is level from shoulders to knees. Lower slowly; chin stays tucked. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: arching the lower back at the top; pushing through the toes.

**147 · `legs-smith-reverse-lunge.mp4`** (East Asian man) — Smith Machine Reverse Lunge

> An East Asian man performs a Smith machine reverse lunge using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Bar across the upper back, feet together under the bar. Step one foot back and lower until the back knee nearly touches the floor. Push through the front foot to bring the feet together again. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: stepping too short; leaning forward.

**148 · `legs-smith-calf-raise.mp4`** (Black woman) — Smith Machine Calf Raise

> A Black woman performs a Smith machine calf raise using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Bar across the upper back, balls of the feet on a plate or step. Rise as high as you can onto the toes and hold for a second. Lower the heels below the step for a full stretch. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bouncing at the bottom; bending the knees.

**149 · `back-smith-shrug.mp4`** (Latina woman) — Smith Machine Shrug

> A Latina woman performs a Smith machine shrug using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: front view, full body in frame. Stand tall holding the bar at arm's length, hands just outside the hips. Lift the shoulders straight up toward the ears. Hold one second, then lower all the way. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rolling the shoulders; bending the elbows.

**150 · `back-smith-inverted-row.mp4`** (Black man) — Smith Machine Inverted Row

> A Black man performs a Smith machine inverted row using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Bar locked at waist height, hang under it with the body straight, heels on the floor. Pull your chest to the bar, elbows at 45 degrees. Lower until the arms are straight; hips stay up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips sagging; half reps.

**151 · `back-chin-up.mp4`** (South Asian woman) — Chin-Up

> A South Asian woman performs a chin-up using a pull-up bar. Camera: front view, full body in frame. Palms facing you, hands shoulder-width, arms long. Pull your chest toward the bar until the chin is over it. Lower all the way until the arms are straight. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: kicking the legs to get up; stopping halfway down.

**152 · `back-assisted-pull-up.mp4`** (Black woman) — Assisted Pull-Up Machine

> A Black woman performs an assisted pull-up machine using a matte black plate-loaded or selectorized machine. Camera: front view, full body in frame. Knees on the pad, hands on the wide handles. Pull your chest up toward the handles, elbows driving down. Lower slowly until the arms are long. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: dropping fast at the bottom; shrugging the shoulders to the ears.

**153 · `back-chest-supported-db-row.mp4`** (Black man) — Chest-Supported Dumbbell Row

> A Black man performs a chest-supported dumbbell row using matte black dumbbells or a kettlebell, a black adjustable bench. Camera: side view, full body in frame. Chest on an incline bench, dumbbells hanging straight down. Row both elbows back until the dumbbells reach your ribs. Lower until the arms are straight; chest stays on the pad. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: lifting the chest off the bench; shrugging instead of rowing.

**154 · `back-machine-row.mp4`** (Black woman) — Chest-Supported Machine Row

> A Black woman performs a chest-supported machine row using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Chest against the pad, handles at arm's length. Pull the handles back until the elbows pass the body. Return slowly; chest stays on the pad. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning back to finish the rep; letting the weight stack slam.

**155 · `back-landmine-row.mp4`** (white woman) — Landmine Row

> A white woman performs a landmine row using a matte black barbell with black plates. Camera: side view, full body in frame. One end of the bar in a landmine or a corner; straddle the bar, hinge forward. Hold just under the plates with both hands, back flat. Row the plates to your chest, then lower until the arms are straight. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rounding the back; standing up taller each rep.

**156 · `back-single-arm-cable-row.mp4`** (Black man) — Single-Arm Cable Row

> A Black man performs a single-arm cable row using a matte black cable station. Camera: front three-quarter view, full body in frame. Pulley at waist height, split stance, one handle in one hand. Row the elbow back past the ribs without twisting. Let the arm reach forward fully before the next rep. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: turning the torso to pull; short reach at the front.

**157 · `back-suspension-row.mp4`** (East Asian man) — Suspension Row

> An East Asian man performs a suspension row using black suspension trainer straps anchored overhead. Camera: side view, full body in frame. Hold the handles, lean back with the body in a straight line. Pull the chest up to the handles, elbows close to the sides. Lower until the arms are straight; keep the hips up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips dropping; pulling with the neck forward.

**158 · `back-rack-pull.mp4`** (Black woman) — Rack Pull

> A Black woman performs a rack pull using a matte black barbell with black plates. Camera: side view, full body in frame. Bar on the safety pins just below the knees. Brace, push the floor away and stand tall with the bar. Lower it back to the pins under control. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning back at the top; rounding the upper back.

**159 · `back-half-kneeling-pulldown.mp4`** (Latina woman) — Half-Kneeling Single-Arm Pulldown

> A Latina woman performs a half-kneeling single-arm pulldown using a matte black cable station. Camera: front view, full body in frame. Kneel on one knee beside a high pulley, handle in the far hand. Pull the elbow down to your side, ribs down. Let the arm rise fully overhead before the next rep. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning away from the cable; pulling with the biceps only.

**160 · `back-db-shrug.mp4`** (Black man) — Dumbbell Shrug

> A Black man performs a dumbbell shrug using matte black dumbbells or a kettlebell. Camera: front view, full body in frame. Stand tall, dumbbells at your sides. Lift the shoulders straight up toward the ears. Hold one second, then lower all the way. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rolling the shoulders in circles; bending the elbows.

**161 · `legs-trap-bar-deadlift.mp4`** (South Asian woman) — Trap Bar Deadlift

> A South Asian woman performs a trap bar deadlift using a matte black hexagonal trap bar with raised handles. Camera: side view, full body in frame. Stand in the middle of the bar, grip the high handles. Hips down, chest up, push the floor away to stand. Lower by bending hips and knees together. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rounding the lower back; hips rising before the chest.

**162 · `legs-smith-squat.mp4`** (Black woman) — Smith Machine Squat

> A Black woman performs a Smith machine squat using a matte black Smith machine (bar fixed on two vertical guide rails). Camera: side view, full body in frame. Bar across the upper back, feet slightly in front of the bar. Squat down until the thighs are level with the floor. Push up through the whole foot. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: feet directly under the bar, heels lifting; knees caving in.

**163 · `legs-pendulum-squat.mp4`** (Black man) — Pendulum Squat

> A Black man performs a pendulum squat using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Back on the pad, shoulders under the pads, feet mid-platform. Sink down as the pad swings until the knees are deeply bent. Drive back up without locking the knees. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: heels lifting off the platform; bouncing out of the bottom.

**164 · `legs-belt-squat.mp4`** (Black woman) — Belt Squat

> A Black woman performs a belt squat using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Belt around the hips, feet on the platform, hands on the rails. Squat straight down with the chest up. Stand back up through the whole foot. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: pulling yourself up with the arms; knees caving in.

**165 · `legs-single-leg-extension.mp4`** (white woman) — Single-Leg Leg Extension

> A white woman performs a single-leg leg extension using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Sit back, one ankle behind the roller. Straighten the leg fully and squeeze for a second. Lower slowly to a bent knee. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: swinging the weight up; hips lifting off the seat.

**166 · `legs-barbell-reverse-lunge.mp4`** (Black man) — Barbell Reverse Lunge

> A Black man performs a barbell reverse lunge using a matte black barbell with black plates. Camera: front three-quarter view, full body in frame. Bar on the upper back, feet hip-width. Step back and lower until the back knee nearly touches the floor. Push through the front foot to step back up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: front knee caving in; leaning far forward.

**167 · `legs-pause-squat.mp4`** (East Asian man) — Pause Squat

> An East Asian man performs a pause squat using a matte black barbell with black plates. Camera: side view, full body in frame. Squat down as usual to at least parallel. Hold still for two seconds, staying braced. Drive up without a bounce. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: relaxing at the bottom; cutting the pause short.

**168 · `legs-deficit-deadlift.mp4`** (Black woman) — Deficit Deadlift

> A Black woman performs a deficit deadlift using a matte black barbell with black plates. Camera: side view, full body in frame. Stand on a low plate or platform, bar over mid-foot. Hips lower than usual, back flat, push the floor away. Lower the bar to the floor the same way. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rounding the back to reach the bar; platform too high.

**169 · `legs-nordic-curl.mp4`** (Latina woman) — Nordic Hamstring Curl

> A Latina woman performs a nordic hamstring curl using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Kneel with the ankles locked under the pad. Lower the body forward as slowly as you can, hips straight. Catch yourself with the hands and pull back up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bending at the hips; dropping fast.

**170 · `legs-db-split-squat.mp4`** (Black man) — Dumbbell Split Squat

> A Black man performs a dumbbell split squat using matte black dumbbells or a kettlebell. Camera: side view, full body in frame. Long split stance, dumbbells at your sides. Lower straight down until the back knee nearly touches the floor. Push through the front foot to rise; feet stay put. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: front heel lifting; stance too short.

**171 · `legs-landmine-squat.mp4`** (South Asian woman) — Landmine Squat

> A South Asian woman performs a landmine squat using a matte black barbell with black plates. Camera: front three-quarter view, full body in frame. Hold the end of the bar at your chest, feet shoulder-width. Squat down between the knees, chest up. Stand up as the bar rises along its arc. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: letting the bar pull you forward; heels lifting.

**172 · `legs-single-leg-rdl.mp4`** (Black woman) — Single-Leg Romanian Deadlift

> A Black woman performs a single-leg romanian deadlift using matte black dumbbells or a kettlebell. Camera: side view, full body in frame. One dumbbell in the opposite hand, stand on one leg. Hinge forward as the free leg reaches back, hips square. Stand back up by squeezing the glute. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips opening to the side; rounding the back.

**173 · `legs-cossack-squat.mp4`** (Black man) — Cossack Squat

> A Black man performs a cossack squat. Camera: front view, full body in frame. Very wide stance, toes slightly out. Shift to one side and sit into that hip; the other leg stays straight, toes up. Push back to the middle and repeat on the other side. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: heel of the bent leg lifting; rounding forward.

**174 · `legs-hip-adduction.mp4`** (Black woman) — Hip Adduction Machine

> A Black woman performs a hip adduction machine using a matte black plate-loaded or selectorized machine. Camera: front view, full body in frame. Sit back, pads on the inside of the knees, legs open. Squeeze the knees together. Open slowly until you feel a stretch. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: letting the pads snap open; leaning forward.

**175 · `legs-hip-adduction-lean.mp4`** (white woman) — Hip Adduction Machine, Leaning Forward

> A white woman performs a hip adduction machine, leaning forward using a matte black plate-loaded or selectorized machine. Camera: front view, full body in frame. Sit on the edge of the seat and lean the chest forward, hands on the handles, back flat. Squeeze the knees together; the lean shifts the work to the upper inner thigh. Open slowly until you feel the stretch. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rounding the back; bouncing the pads together.

**176 · `legs-cable-hip-adduction.mp4`** (Black man) — Standing Cable Hip Adduction

> A Black man performs a standing cable hip adduction using a matte black cable station. Camera: front view, full body in frame. Ankle strap on the near leg, low pulley at your side, hold the frame. Pull the leg in and across in front of the standing leg. Let it return slowly out to the side. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning the torso; swinging the leg.

**177 · `legs-band-hip-adduction.mp4`** (East Asian man) — Band Hip Adduction

> An East Asian man performs a band hip adduction using a dark resistance band. Camera: front view, full body in frame. Band anchored low at your side, looped around the near ankle. Pull the leg in past the standing leg. Return slowly against the band. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: twisting the hips; letting the band snap back.

**178 · `legs-side-lying-adduction.mp4`** (Black woman) — Side-Lying Hip Adduction

> A Black woman performs a side-lying hip adduction. Camera: front view, full body in frame. Lie on your side, top foot planted in front of the bottom knee. Lift the straight bottom leg as high as you can. Lower slowly without resting it. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: rolling the hips back; bending the working knee.

**179 · `legs-copenhagen-plank.mp4`** (Latina woman) — Copenhagen Plank

> A Latina woman performs a copenhagen plank using a black adjustable bench. Camera: front view, full body in frame. Side plank on the forearm, top leg resting on the bench, bottom leg free. Lift the hips and bring the bottom leg up to meet the bench. Hold, then lower with control. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips sagging; shoulder shrugging toward the ear.

**180 · `shoulders-machine-press.mp4`** (Black man) — Machine Shoulder Press

> A Black man performs a machine shoulder press using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Seat set so the handles start at shoulder height. Press up until the arms are long, without locking. Lower back to shoulder height. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: arching off the backrest; half reps at the top.

**181 · `shoulders-landmine-press.mp4`** (South Asian woman) — Landmine Press

> A South Asian woman performs a landmine press using a matte black barbell with black plates. Camera: front three-quarter view, full body in frame. Hold the end of the bar at your shoulder in one hand, split stance. Press up and forward along the bar's arc until the arm is long. Lower back to the shoulder. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning back to press; twisting the hips.

**182 · `shoulders-cable-y-raise.mp4`** (Black woman) — Cable Y-Raise

> A Black woman performs a cable y-raise using a matte black cable station. Camera: front view, full body in frame. Low pulleys crossed, one handle in each hand. Raise the arms up and out into a Y above the head. Lower slowly to the hips. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: shrugging up; swinging the torso.

**183 · `shoulders-cable-rear-delt-fly.mp4`** (Black man) — Cable Rear Delt Fly

> A Black man performs a cable rear delt fly using a matte black cable station. Camera: straight behind, full body in frame. Pulleys at shoulder height, cables crossed, arms in front. Open the arms wide to a T, elbows soft. Return slowly until the hands cross. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: pulling with the elbows bent; leaning back.

**184 · `shoulders-machine-lateral-raise.mp4`** (Black woman) — Machine Lateral Raise

> A Black woman performs a machine lateral raise using a matte black plate-loaded or selectorized machine. Camera: front view, full body in frame. Seat set so the shoulders line up with the pivots, arms against the pads. Raise the arms out to shoulder height. Lower slowly. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: shrugging; letting the weight drop.

**185 · `shoulders-z-press.mp4`** (white woman) — Seated Z-Press

> A white woman performs a seated z-press using a matte black barbell with black plates. Camera: side view, full body in frame. Sit on the floor, legs straight, bar at the front of the shoulders. Press straight overhead, head through at the top. Lower to the shoulders without leaning back. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning back; bar drifting forward.

**186 · `shoulders-band-face-pull.mp4`** (Black man) — Band Face Pull

> A Black man performs a band face pull using a dark resistance band. Camera: front view, full body in frame. Band anchored at face height, hands overhand. Pull toward your forehead, elbows high, hands apart. Return slowly. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: elbows dropping; leaning back.

**187 · `arms-behind-body-cable-curl.mp4`** (East Asian man) — Behind-the-Body Cable Curl

> An East Asian man performs a behind-the-body cable curl using a matte black cable station. Camera: side view, full body in frame. Low pulley behind you, step forward so the arm starts behind the body. Curl the handle up; the elbow stays back. Lower slowly until the arm is long. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: elbow swinging forward; short range.

**188 · `arms-spider-curl.mp4`** (Black woman) — Spider Curl

> A Black woman performs a spider curl using matte black dumbbells or a kettlebell, a black adjustable bench. Camera: side view, full body in frame. Chest on an incline bench, arms hanging straight down. Curl the dumbbells up without moving the upper arms. Lower all the way. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: swinging the arms back; half reps.

**189 · `arms-machine-preacher-curl.mp4`** (Latina woman) — Machine Preacher Curl

> A Latina woman performs a machine preacher curl using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Upper arms flat on the pad, handles at arm's length. Curl up until the forearms are vertical. Lower slowly, stopping just short of locking. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: lifting the elbows off the pad; dropping the weight.

**190 · `arms-cable-overhead-extension.mp4`** (Black man) — Cable Overhead Triceps Extension

> A Black man performs a cable overhead triceps extension using a matte black cable station. Camera: side view, full body in frame. Facing away from a low pulley, rope behind your head, split stance. Straighten the arms forward and up; elbows stay pointed ahead. Bend back until you feel the stretch. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: elbows flaring wide; arching the back.

**191 · `arms-db-kickback.mp4`** (South Asian woman) — Dumbbell Kickback

> A South Asian woman performs a dumbbell kickback using matte black dumbbells or a kettlebell, a black adjustable bench. Camera: side view, full body in frame. One hand and knee on the bench, upper arm along your side. Straighten the arm back until it is fully long. Bend back to 90 degrees; the upper arm stays still. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: upper arm dropping; swinging the dumbbell.

**192 · `arms-ez-bar-skull-crusher.mp4`** (Black woman) — EZ-Bar Skull Crusher

> A Black woman performs an ez-bar skull crusher using a matte black barbell with black plates, a black adjustable bench. Camera: side view, full body in frame. Lie on the bench, EZ bar over the shoulders, narrow grip. Bend the elbows to lower the bar just behind the forehead. Straighten back up; elbows stay pointed up. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: elbows flaring; turning it into a press.

**193 · `arms-reverse-curl.mp4`** (Black man) — Reverse Barbell Curl

> A Black man performs a reverse barbell curl using a matte black barbell with black plates. Camera: front view, full body in frame. Overhand grip, hands shoulder-width, arms long. Curl the bar up with the wrists straight. Lower slowly. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: wrists bending back; swinging the hips.

**194 · `arms-cable-hammer-curl.mp4`** (Black woman) — Rope Hammer Curl

> A Black woman performs a rope hammer curl using a matte black cable station. Camera: front view, full body in frame. Rope on a low pulley, palms facing each other. Curl the rope up, elbows pinned to your sides. Lower until the arms are long. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: elbows drifting forward; leaning back.

**195 · `arms-suspension-curl.mp4`** (white woman) — Suspension Biceps Curl

> A white woman performs a suspension biceps curl using black suspension trainer straps anchored overhead. Camera: side view, full body in frame. Hold the handles palms up, lean back with arms straight. Curl the hands toward your forehead; elbows stay high and still. Lower back to straight arms with the body in a line. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips sagging; elbows dropping.

**196 · `glutes-machine-hip-thrust.mp4`** (Black man) — Machine Hip Thrust

> A Black man performs a machine hip thrust using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Upper back on the pad, belt or pad across the hips, feet flat. Drive the hips up until the body is level from shoulders to knees. Lower slowly; chin stays tucked. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: arching the lower back at the top; feet too far forward.

**197 · `glutes-reverse-hyper.mp4`** (East Asian man) — Reverse Hyperextension

> An East Asian man performs a reverse hyperextension using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Lie face down on the pad, hips at the edge, legs hanging. Lift both legs straight back until level with the body. Lower with control; don't swing. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: swinging the legs; arching high above level.

**198 · `glutes-kettlebell-deadlift.mp4`** (Black woman) — Kettlebell Deadlift

> A Black woman performs a kettlebell deadlift using matte black dumbbells or a kettlebell. Camera: side view, full body in frame. Kettlebell between the feet, hinge and grip the handle. Back flat, push the floor away and stand tall. Hinge back down and set the bell on the floor. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: squatting instead of hinging; rounding the back.

**199 · `glutes-curtsy-lunge.mp4`** (Latina woman) — Dumbbell Curtsy Lunge

> A Latina woman performs a dumbbell curtsy lunge using matte black dumbbells or a kettlebell. Camera: front view, full body in frame. Dumbbells at your sides, feet hip-width. Step one leg back and across behind the other, then lower. Push through the front foot to return; switch sides. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: front knee caving in; twisting the shoulders.

**200 · `glutes-cable-abduction.mp4`** (Black man) — Standing Cable Hip Abduction

> A Black man performs a standing cable hip abduction using a matte black cable station. Camera: front view, full body in frame. Ankle strap on the far leg, low pulley, hold the frame. Lift the leg out to the side, toes forward. Return slowly without touching the other foot. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: leaning the torso away; turning the toes up.

**201 · `glutes-frog-pump.mp4`** (South Asian woman) — Frog Pump

> A South Asian woman performs a frog pump. Camera: side view, full body in frame. Lie on your back, soles of the feet together, knees open. Drive the hips up and squeeze the glutes. Lower to just above the floor. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: arching the lower back; knees closing.

**202 · `core-hanging-knee-raise.mp4`** (Black woman) — Hanging Knee Raise

> A Black woman performs a hanging knee raise using a pull-up bar. Camera: side view, full body in frame. Hang from the bar with straight arms. Bring the knees up to the chest, curling the pelvis. Lower slowly without swinging. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: swinging; only lifting to hip height.

**203 · `core-cable-woodchop.mp4`** (Black man) — Cable Woodchop

> A Black man performs a cable woodchop using a matte black cable station. Camera: front view, full body in frame. High pulley to one side, both hands on the handle. Pull down and across to the opposite hip, turning through the torso. Return slowly along the same line. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: pulling with the arms only; feet twisting.

**204 · `core-landmine-rotation.mp4`** (Black woman) — Landmine Rotation

> A Black woman performs a landmine rotation using a matte black barbell with black plates. Camera: front view, full body in frame. Hold the end of the bar overhead with both hands, arms long. Swing it down in an arc to one hip, hips turning a little. Bring it back over the head and to the other side. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: bending the arms; arching the lower back.

**205 · `core-hollow-hold.mp4`** (white woman) — Hollow Body Hold

> A white woman performs a hollow body hold. Camera: side view, full body in frame. Lie on your back, press the lower back into the floor. Lift the shoulders and straight legs a few centimetres. Hold, breathing slowly; lower back stays down. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: lower back lifting; holding the breath.

**206 · `core-suspension-tuck.mp4`** (Black man) — Suspension Knee Tuck

> A Black man performs a suspension knee tuck using black suspension trainer straps anchored overhead. Camera: side view, full body in frame. Feet in the straps, hands under the shoulders in a high plank. Pull the knees to the chest, hips rising a little. Push the legs back to a straight plank. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: hips sagging at the back; shoulders drifting behind the hands.

**207 · `core-machine-crunch.mp4`** (East Asian man) — Machine Crunch

> An East Asian man performs a machine crunch using a matte black plate-loaded or selectorized machine. Camera: side view, full body in frame. Sit in the machine, hold the handles, feet under the pads. Curl the chest down toward the hips. Return slowly until upright. Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: pulling with the arms; letting the stack slam.
