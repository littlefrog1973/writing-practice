# Hand-off: implement Step 6 — scoring & feedback

Read this first, then the plan file `docs/PLAN.md` (Step 6 section). Stop at
GATE 6 for user confirmation on the Surface Go before touching Step 7.

Start the session by running the five suites below (about two minutes, two open
a window) — that confirms the environment before anything is changed.

**GATE 5 is not passed yet.** Step 5 is built, tested and committed
(`14abdc3`), but the gate is judged by eye on the Surface Go: the animation
plays smoothly with no visible stutter, a full character traces by finger with
responsive ink and no perceptible lag, stroke progression works, "watch again"
replays. If the user has not confirmed that, do that first — `godot --path .
-- --tracing` — and fix within Step 5 rather than starting Step 6.

## Where the project stands (verified)

Steps 0–5 are built; GATES 0–4 are confirmed by the user, GATE 5 is pending.

The project is a **git repository** (`main`). Commit as you go; the stroke data
is hand-authored on a touch screen and cannot be regenerated.

The dataset is **complete — 116/116 characters, validating clean**. Do not
clobber it. (`thai_vowels` is still an empty catalog stub; filling it is the
remaining part of Step 8.)

- Godot **4.7.1-stable** at `~/.local/bin/godot`; export templates installed.
- Main scene is `scenes/main.tscn` (`scripts/main.gd`), a boot router on
  `OS.get_cmdline_user_args()`:
  - `godot --path .` → `scenes/font_test.tscn` (Step 1 diagnostics; keep it)
  - `godot --path . -- --tracing` → the tracing scene
  - `godot --path . -- --recorder` → the Stroke Recorder
  - add `--mouse` to draw with the mouse (sets `Input.emulate_touch_from_mouse`
    at runtime; the project setting itself stays off)
- Project: fullscreen (mode 3), 1920×1280 base, `canvas_items` stretch,
  `gl_compatibility`, `emulate_mouse_from_touch=true`.
- Fonts: `assets/fonts/sarabun/` (looped Thai — never substitute a loopless
  font), `assets/fonts/andika/` (English/digits).

Run the suites:

```sh
godot --headless --path . --script tests/test_stroke_data.gd    # 39 checks
godot --headless --path . --script tests/test_char_sets.gd      # 45 checks
godot --headless --path . --script tests/validate_dataset.gd    # the dataset
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd   # 31, needs a display
```

## What Step 5 added

- `scenes/tracing.tscn` + `scripts/tracing.gd` — the state machine
  (`State.EMPTY / DEMO / TRACE / SCORE`), touch input, and the guide rendering.
  A 960×960 drawing box at (80,170); the glyph goes through `GG.apply()`, so
  recorded strokes sit on it. `open(set_id, chr)` is the public entry point —
  **Step 7's character-select screen should call that** rather than reaching
  into the scene.
- `scripts/stroke_animator.gd` — the demo, as a reusable node:
  `set_strokes(screen_strokes)`, `play()`, `stop()`, `is_playing()`, and a
  `finished` signal. `speed` (px/s) and `pause` (s) are plain vars, which the
  test turns up to run the demo fast.
- `scripts/dotted_guide.gd` — `Node2D.set_stroke(points)`; draws the dashed
  guide, start ring and direction arrow in `_draw()`. `Line2D` has no dash
  mode; the stroke is resampled to a fixed arc-length spacing and a dot drawn
  at each sample. It redraws only when the stroke changes.
- `tests/test_tracing.gd` — 31 checks, needs a display.

**The performance rule to keep in Step 6**: nodes are allocated per character,
never per frame. The animator only reassigns `Line2D.points` while playing, and
`tracing.gd` builds its dimmed guide lines once in `_build_guide()` and then
just toggles `visible`. Particles and stars in Step 6 must not undo that —
build the celebration nodes once and hide them, and prefer one `GPUParticles2D`
(or `CPUParticles2D` on this iGPU) that is restarted over nodes created per
celebration.

## What to build in Step 6

`scripts/scorer.gd` per the plan's scoring design, and a real score state in
place of the placeholder card.

- **The data to score is already there**: `tracing.gd` keeps the child's
  strokes in `_traced` as normalized `PackedVector2Array`s, in the order drawn
  and one per guide stroke, alongside the guide's `_strokes`. Both are
  normalized against the same box, so the scorer can work entirely in 0–1
  space and never has to care about screen size.
- Per stroke: coverage (fraction of guide points within tolerance of the
  trace), deviation (mean trace→guide polyline distance), direction/order →
  1–3 stars. Generous, child-friendly tolerances.
- **No fail state.** A scribble scores one star and cheerful encouragement to
  try again, never a failure. The trace state deliberately has no correctness
  gate — do not add one in Step 6 by making the score screen block progress.
- The score card lives in `scenes/tracing.tscn` under `ScoreOverlay` (a
  full-rect `Control` that blocks input, a light `Dim`, and a `Card` panel
  placed **over the side panel** so the child's finished writing stays
  visible — that placement was a deliberate fix, keep it). Replace
  `Message`/`Placeholder` with the stars, and `Next` gets an "again" sibling.
- Audio: `assets/audio/` does not exist yet; the plan wants success/star
  sounds. Check licensing as carefully as the fonts were.
- `scorer.gd` should be static and pure like `dataset_validator.gd`, so a
  **headless** suite (`tests/test_scorer.gd`) can score synthetic traces with
  no display: a perfect trace, a sloppy one, a reversed stroke, a scribble.
  Then extend `tests/test_tracing.gd` for the score screen's behaviour.

**GATE 6** (on the Surface Go, by the user): a careful adult trace scores 3
stars; a deliberately sloppy-but-on-letter trace scores 1–2; a random scribble
scores 1 star with encouragement to retry; sounds and particles play.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`.
- Scripts refer to each other with `preload()` constants (`CS`, `SD`, `GG`),
  not by `class_name`: the global class cache lives in the gitignored
  `.godot/` directory and is only written by the editor, so a fresh checkout
  run from the CLI would not resolve bare class names.
- Code style: tabs, typed GDScript, result-dict error handling (`{ok: …}`),
  no exceptions.
- **Any test that drives a scene which reads or writes stroke files must point
  `CharSets.stroke_dir` at a scratch directory under `user://`** and write the
  characters it needs there — `tests/test_recorder.gd` and
  `tests/test_tracing.gd` both do, and both check the real dataset's SHA-256s
  afterwards. A test that loads a real character will rot when Step 8
  re-records it.
- Touch input is handled in `_input` gated on `box.has_point()`, never
  `_gui_input` — that deliberately avoids the mouse-emulation subtleties that
  cost time in Step 3.
- Writing to `res://` works in dev (non-exported). Exports are read-only there;
  progress data goes to `user://` (Step 7).
- A windowed run plus `root.get_texture().get_image()` gives screenshots for
  visual checks — worth doing for the score screen, since the gate is visual.
  `root.get_final_transform()` converts base coords → window coords for
  synthetic input, but is **not** reliable for reading pixels back — measure in
  a SubViewport instead.
- Possible cleanup, not required: the recorder's replay (`_process` in
  `stroke_recorder.gd`) predates `stroke_animator.gd` and does the same job by
  hand. It could use the animator, but it also rebuilds its ink nodes and
  draws its own numbers, so it is not a free swap — and the recorder is gated
  and working.
- Update `README.md` and the memory file `writing-practice-step-progress`
  (status + next-step brief) before stopping at the gate.
