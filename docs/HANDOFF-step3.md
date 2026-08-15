# Hand-off: implement Step 3 — Stroke Recorder (authoring tool)

Read this first, then the plan file `docs/PLAN.md` (Step 3 section). Stop at
GATE 3 for user confirmation on the Surface Go before touching Step 4.

## Where the project stands (verified)

Steps 0–2 are done, GATES 0–2 passed (0 and 1 confirmed by the user on
hardware; 2 is the automated test suite).

- Godot **4.7.1-stable** at `~/.local/bin/godot`; export templates installed.
  Run the app: `godot --path /home/littlefrog/projects/writing_practice`.
- Project: fullscreen (mode 3), 1920×1280 base, `canvas_items` stretch,
  `gl_compatibility` renderer, `emulate_mouse_from_touch=true`,
  `emulate_touch_from_mouse=false`.
- Main scene is `scenes/font_test.tscn` — a font/touch smoke test (keep it;
  it doubles as a diagnostics scene).
- Fonts: `assets/fonts/sarabun/` (Sarabun Regular/Bold — **looped Thai, never
  substitute a loopless font**), `assets/fonts/andika/` (Andika Regular/Bold
  for English/digits). OFL licenses alongside.
- Tests: `godot --headless --path . --script tests/test_stroke_data.gd`
  (24 checks, exit 0/1). Keep this green.

## StrokeData API (scripts/stroke_data.gd — use it, don't reinvent)

`class_name StrokeData`, all static. No exceptions — I/O returns result dicts.

- `load_set(path) -> {ok: true, entries: Array} | {ok: false, error: String}`
- `save_set(path, entries) -> {ok: true} | {ok: false, error: String}` —
  pretty-printed JSON, creates parent dirs.
- Runtime entry form:
  `{char: String, set: String, name: String, strokes: Array[PackedVector2Array]}`;
  build with `make_entry(chr, set_name, display_name, strokes)`.
- `resample_stroke(points, spacing)` — arc-length resampling, gap ≤ spacing.
- `normalize_stroke(points, box: Rect2)` / `denormalize_stroke(points, box)` —
  screen ↔ 0–1 box.
- `stroke_length(points)`.

File format (see README): one JSON array per set in `data/strokes/`, points
normalized 0–1 against the on-screen drawing box. **Glyph position inside the
box is meaningful** (tone marks sit high), so normalize against the fixed
drawing box, never the stroke's own bounding box. Thai strokes start at the
loop (หัว). Sample file `data/strokes/digits.json` already has digit "1".

## What to build

`scenes/stroke_recorder.tscn` + `scripts/stroke_recorder.gd`, dev-only.

1. **Launch routing**: create a tiny boot scene (e.g. `scenes/main.tscn` +
   `scripts/main.gd`) as the new main scene: if `"--recorder"` is in
   `OS.get_cmdline_user_args()` → `change_scene_to_file` the recorder, else
   the current font test (later: main menu). Launch:
   `godot --path . -- --recorder` (note the `--` separator).
2. **Layout**: a large square drawing box (the normalization box — make it an
   explicit Rect2 you can pass to StrokeData, e.g. a centered
   `Panel`/`ReferenceRect` ~1000×1000 px with a visible border); the
   reference glyph as a huge Label centered in that box at ~30% opacity
   (Sarabun for Thai sets, Andika for English/digits — font size so the glyph
   nearly fills the box); side/top bar with buttons + labels for current
   set/char and stroke count.
3. **Recording**: on `InputEventScreenTouch` pressed inside the box start a
   stroke; append `InputEventScreenDrag` points; on release, finish the
   stroke (resample lightly to tame point density, then normalize against the
   box, store). Draw live ink as thick rounded `Line2D`s; number each
   finished stroke so order is visible.
4. **Controls**: undo last stroke; clear character; save (build entry with
   `StrokeData.make_entry`, merge into the set's existing file — replace the
   entry for that char if present — and `save_set` to
   `res://data/strokes/<set>.json`); next/prev character within the set; a
   way to switch sets. Writing under `res://` works in dev (non-exported),
   which is all the recorder needs.
5. **Replay preview**: button that redraws the saved/current strokes one by
   one (a simple timer/tween growing each Line2D in order is enough — the
   fancy animator is Step 5's job).
6. Buttons must be big enough for touch; `emulate_mouse_from_touch` is on, so
   normal `BaseButton` presses work by finger.

## Character set catalog

Define once (e.g. `scripts/char_sets.gd`) — recorder iterates these; Steps
4/7/8 reuse them. Set ids must match the JSON `"set"` field / filenames:

- `thai_consonants` (44): ก ข ฃ ค ฅ ฆ ง จ ฉ ช ซ ฌ ญ ฎ ฏ ฐ ฑ ฒ ณ ด ต ถ ท ธ น
  บ ป ผ ฝ พ ฟ ภ ม ย ร ล ว ศ ษ ส ห ฬ อ ฮ — display names use the acrophony
  ("ก ไก่", "ข ไข่", …); fine to store name = char for now and fill
  acrophonies in Step 7/8.
- `english_upper` A–Z, `english_lower` a–z (names = the letter).
- `digits` 0–9 (file exists with "1" — merge, don't clobber).
- `thai_numerals` ๐ ๑ ๒ ๓ ๔ ๕ ๖ ๗ ๘ ๙.
- `thai_vowels` (vowels + tone marks, Step 8 concern): can be stubbed/empty
  in the catalog now; recorder just needs sets to be data-driven. When
  implemented, marks are shown with a dotted placeholder circle at the
  consonant position.

## GATE 3 (user confirms on the Surface Go)

User records **"A"** and **"ก"** by finger; JSON entries land in
`english_upper.json` / `thai_consonants.json`; in-tool replay redraws both
recognizably in the right stroke order; undo works. Fix in-step if not.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`.
- Don't turn on `emulate_touch_from_mouse` globally. If you want mouse
  testing of the recorder on a desktop, gate it behind a
  `--mouse` user arg parsed in the boot script.
- Keep `tests/test_stroke_data.gd` passing; add a test file for any new pure
  logic (e.g. set catalog integrity) in the same `extends SceneTree` style.
- Code style: tabs, typed GDScript, result-dict error handling as in
  `stroke_data.gd`.
- Update `README.md` (how to launch the recorder) and the memory file
  `writing-practice-step-progress` (status + next-step brief) before stopping
  at the gate.
