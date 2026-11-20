# Tekto design

All design work for the Tekto app: brand, screens, photos and the prompts used to make them.

## Links

| What | Where |
|---|---|
| App tour and clickable prototype | https://claude.ai/artifact/2TPDSPzsfgC9Y99e8qf7mn. Add `#try` to open the prototype, or `#try-201` to start on a given screen (here 2.01). (private; share it from its Share menu). A local copy is in `app-tour/`. |
| Figma file: mood board, research, onboarding screens, components, photos | https://www.figma.com/design/HVh5cpvoaxvWq1287kA6vC |

## Folders

| Folder | Contents |
|---|---|
| `app-tour/` | The tour page (`index.html`). Open it in a browser. `ob/` holds the 16 onboarding screens cut from the Figma export, `img/` the photos and brand sheets it uses, and `vid/` small copies of the video loops that replace the large photos. |
| `brand/` | The logo as a vector file (`tekto-mark.svg`), the app icon at 1024 px (dark and light versions) and the mark on a transparent background. |
| `logo/` | The logo sheet exported from Figma: mark, lockup, sizes, app icons and the coach avatar. |
| `components/` | The components sheet exported from Figma: status bar, buttons and tab bar. |
| `images/` | The 24 photos: `hero/` (6 screen photos), `avatar/` (profile photo), `ex/<category>/` (17 exercises), and `Imagery.png` showing them all on one sheet. |
| `Onboarding to first plan/` | Figma export of stage 1, screens 1.01–1.16, as one image. |
| `video-prompts.md` | Batch 1, done and frozen: the prompts that made the 23 clips in use, plus the photo-recast prompts. |
| `video-prompts-batch-2.md` | Batch 2, done 2026-11-18: 22 new exercise clips, the bench press redo, and redos of its own (Part C). Frozen; the dropped dead bug is replaced in batch 3. Its rules say what may be changed and what must stay; its tracker shows each clip's status. |
| `video-prompts-batch-3.md` | Batch 3, delivered 2026-11-19 (31 of 32 in the library; the diamond push-up needs a redo): 32 clips covering bands, barbell, dumbbell, kettlebell, cable and machines, and bodyweight, including the dead bug's replacement. It has the same rules and tracker, plus lessons from batches 1 and 2. |
| `video-prompts-batch-4.md` | Batch 4, 1 of 23 delivered (the reverse pec deck); the rest to generate: 23 of the exercises gym members use most that Tekto lacks (decline bench, T-bar row, barbell and preacher curls, hack squat, crunch and others). It has the same rules and tracker. |
| `videos/` | The 77 generated clips (71 exercises, 6 screens). `cd content/videos && node ingest.js` checks and converts them and bundles the welcome and paywall clips with the app. The review and the clip-to-screen mapping are in `videos/README.md`. |
| `tools/` | `render-icon.swift` draws the app icon at any size. `crop-screens.swift` cuts a Figma stage export into single screens. |

## Design rules

- **Theme:** dark first. Constitution VI requires a light theme that follows the system setting, so the app also has one: same tokens, with a deeper blue (`#3D5BD9`) for contrast on white. The designs are drawn in dark.
- **Colours (Midnight & Glacier):**

  | Name | Hex | Used for |
  |---|---|---|
  | night | `#0F1014` | background |
  | mid | `#16171D` | cards |
  | deep | `#1F2129` | inputs |
  | steel | `#2A2D37` | — |
  | line | `#3A3E4B` | borders |
  | frost | `#EEF0F5` | text |
  | mist | `#A2A7B6` | secondary text |
  | glacier | `#9DB8FF` | actions |
  | mint | `#7EE0B8` | records only |

- **Never use** yellow, red LED or dot-matrix displays.
- **Type:** Bricolage Grotesque for titles (ExtraBold uppercase over photos), Geist for interface text and numbers, Geist Mono for small labels.
- **Layout:** follow Ladder's structure and behaviour, with Tekto's own identity. Never copy Ladder, Fitbod or Any Distance logos, colours or footage.
- **Casting:** at least half of each photo or video set shows Black men and women in lead roles. Lighting is a warm key light plus a cool blue rim light, so deep skin tones read well on the dark background. See `specs/001-tekto-ai-mvp/research.md` §16.

## Regenerating

- **App icons:** run `swiftc -O design/tools/render-icon.swift -o /tmp/icon`, then for each size run `/tmp/icon <out.png> <px> 0.62 gradient 0`.
  - Android adaptive foreground: `/tmp/icon <out.png> <px> 0.413 none 1`.
- **Screens from a Figma export:** run `swiftc -O design/tools/crop-screens.swift -o /tmp/crop`, then `/tmp/crop <stage.png> <out.jpg> <x> <y> <w> <h> <outWidth>`.
  - In the onboarding export, screen *i* is at x = 200 + 930·i, y = 723, size 786×1704.
