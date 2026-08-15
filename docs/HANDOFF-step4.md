# Hand-off: implement Step 4 — author the starter dataset

Read this first, then the plan file `docs/PLAN.md` (Step 4 section). Stop at
GATE 4 for user confirmation before touching Step 5.

Start the session by running the three test suites below (30 seconds, one
opens a window) — that confirms the environment before anything is changed.

Step 4 is mostly *the user's* work — they record characters by finger — plus a
small validation script. Do not record strokes on their behalf.

## Where the project stands (verified)

Steps 0–3 are **done and gated**: GATES 0–3 all passed, GATE 3 confirmed by the
user on the Surface Go on 2026-08-15 (recorder used by finger; nothing needed
fixing).

Already recorded and validating clean — do not clobber these:

| File | Entries |
| --- | --- |
| `data/strokes/thai_consonants.json` | ก (1 stroke), ข (1 stroke) |
| `data/strokes/english_upper.json` | A (2 strokes) |
| `data/strokes/digits.json` | 1 (the hand-written Step 2 sample, 3 points — worth re-recording properly) |

- Godot **4.7.1-stable** at `~/.local/bin/godot`; export templates installed.
- Main scene is now `scenes/main.tscn` (`scripts/main.gd`) — a boot router:
  - `godot --path .` → `scenes/font_test.tscn` (Step 1 diagnostics; keep it)
  - `godot --path . -- --recorder` → the Stroke Recorder
  - add `--mouse` to draw with the mouse (sets `Input.emulate_touch_from_mouse`
    at runtime; the project setting itself stays off)
- Project: fullscreen (mode 3), 1920×1280 base, `canvas_items` stretch,
  `gl_compatibility`, `emulate_mouse_from_touch=true`.
- Fonts: `assets/fonts/sarabun/` (looped Thai — never substitute a loopless
  font), `assets/fonts/andika/` (English/digits).

## What Step 3 added

- `scripts/char_sets.gd` (`class_name CharSets`, all static, lazily built
  catalog). Sets, in order: `thai_consonants` (44, with acrophony names),
  `english_upper`, `english_lower`, `digits` (names "zero"…"nine"),
  `thai_numerals` (Thai number words), `thai_vowels` (empty stub, combining,
  filled in Step 8). API: `all()`, `get_set(id)`, `has_set(id)`,
  `recordable_ids()` (skips empty sets), `chars_of(id)`, `name_of(id, chr)`,
  `label_of(id)`, `font_of(id)` → `FONT_THAI`/`FONT_LATIN`, `is_combining(id)`,
  `path_of(id)` → `res://data/strokes/<id>.json`, `validate()` → result dict.
- `scripts/glyph_guide.gd` (`class_name GlyphGuide`): `apply(label, box_size,
  font, text)` — the single definition of how the faint guide glyph is sized
  and positioned inside a drawing box (`FONT_SIZE_RATIO` 0.76 of box height,
  lifted `LIFT_RATIO` 0.125 of the font size, label allowed to overflow the box
  so descenders are not clipped). **Step 5's tracing scene must render its
  reference glyph through this helper**, or recorded strokes will not sit on
  the glyph. Ratios were tuned by measuring rendered ink: the tallest glyphs
  (ฐ ฎ ป) reach ~0.10–0.96 of the box, ordinary ones ~45–55% of its height,
  proportions preserved as on a practice sheet.
- `scripts/stroke_data.gd` gained `find_entry(entries, chr)`,
  `merge_entry(entries, entry)` (replace-in-place, returns a new array) and
  `partial_stroke(points, distance)` (leading part of a stroke — reuse this for
  Step 5's demo animator).
- `scenes/stroke_recorder.tscn` + `scripts/stroke_recorder.gd`: 1000×1000
  drawing box at (60,150), side panel of touch-sized buttons, guide glyph,
  live ink as round `Line2D`s, numbered strokes with start dots, replay,
  set/character navigation, save-with-merge, an unsaved-work guard (a nav
  button must be pressed twice to discard), and a refusal to save over a set
  file that failed to parse.
- Tests: `tests/test_char_sets.gd` (28 checks, headless) and
  `tests/test_recorder.gd` (28 checks, **needs a display**: it feeds synthetic
  `InputEventScreenTouch`/`Drag` into the real scene, then restores the stroke
  file it wrote). `tests/test_stroke_data.gd` grew to 36 checks.

Run them:

```sh
godot --headless --path . --script tests/test_stroke_data.gd
godot --headless --path . --script tests/test_char_sets.gd
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd
```

## GATE 3 — passed 2026-08-15

The user recorded ก, ข and A by finger on the Surface Go; entries landed in the
right files, replay redrew them in order, undo worked. No fixes were needed, so
the recorder is trusted as-is going into Step 4.

## What to build in Step 4

### 1. The dataset validator (your work — do this first)

A headless script, `tests/validate_dataset.gd`, in the same
`extends SceneTree` style as the other suites. It walks every
`data/strokes/*.json` and checks each entry:

- the file name matches the `"set"` field, and `CharSets.has_set()` knows it;
- `"char"` is in that set's `chars_of()`, and `"name"` equals
  `CharSets.name_of(set, char)`;
- at least one stroke, no empty strokes, at least 2 points per stroke;
- every point inside 0–1 (recorder clamps, so a failure means hand-edited or
  stale data);
- no duplicate `"char"` within a file;
- a sanity floor on stroke length (e.g. `StrokeData.stroke_length` > 0.02 of
  the box) so a stray tap saved as a dot is *reported but allowed* — the dot
  on an "i" is legitimate, a whole character made of dots is not.

It must report **every** problem (not stop at the first), print a per-set
coverage summary (`thai_consonants: 12/44`), and exit non-zero if anything
failed. `tests/test_char_sets.gd` already does a light version of the
in-catalog/normalized checks — move that logic into the validator and have the
test call it, rather than maintaining two copies.

Add it to the README test list. It is also the tool Step 8 uses to know when
the dataset is complete.

### 2. Support the user's recording session (their work)

The starter subset from the plan: **A–Z**, **0–9**, and the **first ten Thai
consonants ก–ช**. Already done: ก, ข, A. Note `digits.json`'s "1" is the
hand-written Step 2 sample (3 points) — have the user re-record it.

Practical notes for the session:

- Suggest recording a whole set in one pass (`char ▶` after each SAVE) — the
  recorder shows `n / 44 recorded` in the side panel, so progress is visible.
- Stroke *order and direction* are the whole point of the data: Thai starts at
  the loop (หัว), English follows school handwriting order (e.g. A = two
  diagonals then the crossbar, top-down, left-to-right).
- Run the validator after each batch and report what is still missing.
- Expect recorder papercuts to surface here — fix them in place in the
  recorder rather than working around them in the data, and re-run
  `tests/test_recorder.gd` after any recorder change.

**GATE 4**: the validator passes over the starter characters; the user
spot-checks replay of five random characters and is happy with them.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`.
- Scripts refer to each other with `preload()` constants (`CS`, `SD`, `GG`),
  not by `class_name`: the global class cache lives in the gitignored
  `.godot/` directory and is only written by the editor, so a fresh checkout
  run from the CLI would not resolve bare class names.
- Code style: tabs, typed GDScript, result-dict error handling (`{ok: …}`),
  no exceptions.
- Writing to `res://` works in dev (non-exported) — that is all the recorder
  needs. Exports are read-only there; progress data goes to `user://`
  (Step 7).
- Update `README.md` and the memory file `writing-practice-step-progress`
  (status + next-step brief) before stopping at the gate.
