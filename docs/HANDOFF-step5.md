# Hand-off: implement Step 5 — the tracing scene (demo + trace)

Read this first, then the plan file `docs/PLAN.md` (Step 5 section). Stop at
GATE 5 for user confirmation on the Surface Go before touching Step 6.

Start the session by running the four suites below (about a minute, one opens a
window) — that confirms the environment before anything is changed.

Step 5 is the first step whose output the child actually uses. It is also the
first one with a real performance requirement: GATE 5 is judged by eye on a
weak iGPU, not by a test.

## Where the project stands (verified)

Steps 0–4 are **done and gated**; GATE 4 was confirmed by the user on
2026-08-16 (replays of L, ฃ, C, O, 4 and a multi-stroke letter all looked
right).

The project is a **git repository** (`main`). Commit as you go; the stroke data
is hand-authored on a touch screen and cannot be regenerated.

The starter dataset is complete and validating clean — **do not clobber it**:

| Set | Recorded |
| --- | --- |
| `data/strokes/digits.json` | 10/10 — complete |
| `data/strokes/english_upper.json` | 26/26 — complete |
| `data/strokes/thai_consonants.json` | 10/44 — the ก–ช starter subset |
| `english_lower`, `thai_numerals`, `thai_vowels` | empty until Step 8 |

Total 46/116. Step 5 does not need more data; the remaining characters are
Step 8 and are not a blocker.

- Godot **4.7.1-stable** at `~/.local/bin/godot`; export templates installed.
- Main scene is `scenes/main.tscn` (`scripts/main.gd`), a boot router on
  `OS.get_cmdline_user_args()`:
  - `godot --path .` → `scenes/font_test.tscn` (Step 1 diagnostics; keep it)
  - `godot --path . -- --recorder` → the Stroke Recorder
  - add `--mouse` to draw with the mouse (sets `Input.emulate_touch_from_mouse`
    at runtime; the project setting itself stays off)
  - **add a `--tracing` route in this step** so the new scene can be launched
    without the menus, which do not exist until Step 7.
- Project: fullscreen (mode 3), 1920×1280 base, `canvas_items` stretch,
  `gl_compatibility`, `emulate_mouse_from_touch=true`.
- Fonts: `assets/fonts/sarabun/` (looped Thai — never substitute a loopless
  font), `assets/fonts/andika/` (English/digits).

Run the suites:

```sh
godot --headless --path . --script tests/test_stroke_data.gd    # 36 checks
godot --headless --path . --script tests/test_char_sets.gd      # 41 checks
godot --headless --path . --script tests/validate_dataset.gd    # the dataset
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
```

## What Step 4 added

- `scripts/dataset_validator.gd` (`DatasetValidator`, all static) holds the
  dataset rules; `tests/validate_dataset.gd` is the headless runner
  (`-- --missing <set id>` lists what is still unrecorded). Problems fail,
  warnings (a stroke under 2% of the box — a dot) pass.
  `tests/test_char_sets.gd` calls `check_entries()` rather than keeping a
  second copy of the rules.
- **`CharSets.stroke_dir` is a static var** (defaulting to the `STROKE_DIR`
  const) that exists purely as a test seam. `tests/test_recorder.gd` points it
  at `user://test_strokes` for the duration of its run.

  **Any new test that drives a scene which reads or writes stroke files must do
  the same.** The recorder suite originally recorded into the real
  `thai_consonants.json` and asserted an empty dataset; it broke the moment the
  user recorded ก, ข and A, and a crash mid-run could have destroyed hand-made
  data. A tracing test that loads ก from the real file will rot the same way
  when Step 8 re-records it.

## What to build in Step 5

`scenes/tracing.tscn` + `scripts/tracing.gd` (state machine and input) +
`scripts/stroke_animator.gd` (the demo animation), per the plan.

State machine: **demo → trace → score → next character**. Step 5 implements
demo and trace; the score state is a **stub** (show something placeholder and
a "next" button) — stars, sounds and particles are Step 6, and `scorer.gd`
does not exist yet. Do not start scoring here.

### The one hard constraint

The reference glyph **must** be rendered through `GG.apply()`
(`scripts/glyph_guide.gd`) into a drawing box of the same shape as the
recorder's — a **square**. Stroke points are normalized against the box, not
against their own bounding box, so a box of a different aspect ratio will put
the recorded strokes off the glyph. The recorder uses 1000×1000 at (60,150) in
the 1920×1280 base resolution; the tracing scene can use a different *size*
(it needs room for buttons) as long as it stays square and the glyph goes
through `GlyphGuide`.

`GlyphGuide` ratios (font 0.76 of box height, lifted 0.125 of the font size,
label allowed to overflow so descenders are not clipped) were tuned by
measuring rendered ink. Do not re-tune them to make one character look better.

### Reuse rather than reinvent

- `SD.partial_stroke(points, distance)` is the geometry for a stroke being
  drawn on — the recorder's replay (`_process` in `stroke_recorder.gd`) is a
  working reference for the demo animator, including the pause between
  strokes. `stroke_animator.gd` should be a reusable node rather than a copy.
- `SD.denormalize_stroke(points, box)` maps stored 0–1 points into the box.
- `SD.resample_stroke(points, spacing)` — the recorder uses 6 px for the
  child's ink; reuse that rather than storing every touch sample.
- `CS.chars_of()`, `name_of()`, `font_of()`, `is_combining()` for what to show.
  Combining marks (Step 8) render on the dotted placeholder "◌" — the recorder
  already does this in `_refresh_glyph()`.

### Known problems to plan for

- **Touch input**: handle it in `_input` gated on `box.has_point()`, as the
  recorder does. This deliberately avoids `_gui_input` and the mouse-emulation
  subtleties that cost time in Step 3.
- **A dotted guide line is not built in.** `Line2D` has no dash mode. The
  options are a tiled texture (`texture_mode = LINE_TEXTURE_TILE`), drawing
  the dots as a series of points, or a custom `_draw()`. Pick one early — this
  is the only genuinely unsolved rendering problem in the step.
- **Performance is a gate criterion.** The recorder rebuilds its ink nodes
  (`_rebuild_ink()` frees and recreates every `Line2D`, dot and `Label`) only
  when a stroke is finished, never per frame. The animator must update
  `line.points` in place each frame instead — freeing and allocating nodes at
  60 fps on the Surface Go's iGPU is what "visible stutter" in GATE 5 will
  look like.
- **Stroke advance**: the plan says the current stroke is a dotted guide with a
  start marker, other strokes dimmed, and the stroke advances when the child
  finishes it. What counts as "finished" is a judgement call — lifting the
  finger is the simple answer, and Step 6's scorer decides whether it was any
  good. Do not silently add a correctness gate here that stops a child
  progressing; the plan is explicit that there is no fail state.

### Testing

Add `tests/test_tracing.gd` in the style of `tests/test_recorder.gd`: drive the
real scene with synthetic `InputEventScreenTouch`/`Drag`, needs a display.
Point `CharSets.stroke_dir` at a scratch directory and write the character it
traces there — see the warning above. Worth covering: the demo advances stroke
by stroke and ends; "watch again" restarts it; a traced stroke advances the
state; ink lands inside the box; the state machine reaches the score stub.

Add it to the README test list.

**GATE 5** (on the Surface Go, by the user): the animation plays smoothly with
no visible stutter; the user traces a full character by finger with responsive
ink and no perceptible lag; stroke progression works; "watch again" replays.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`.
- Scripts refer to each other with `preload()` constants (`CS`, `SD`, `GG`),
  not by `class_name`: the global class cache lives in the gitignored
  `.godot/` directory and is only written by the editor, so a fresh checkout
  run from the CLI would not resolve bare class names.
- Code style: tabs, typed GDScript, result-dict error handling (`{ok: …}`),
  no exceptions.
- Writing to `res://` works in dev (non-exported). Exports are read-only there;
  progress data goes to `user://` (Step 7).
- A windowed run plus `root.get_texture().get_image()` gives screenshots for
  visual checks. `root.get_final_transform()` converts base coords → window
  coords for synthetic input, but is **not** reliable for reading pixels back —
  measure in a SubViewport instead.
- Update `README.md` and the memory file `writing-practice-step-progress`
  (status + next-step brief) before stopping at the gate.
