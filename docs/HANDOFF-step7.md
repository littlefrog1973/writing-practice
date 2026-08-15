# Hand-off: implement Step 7 — menus, character select, progress

Read this first, then the plan file `docs/PLAN.md` (Step 7 section). Stop at
GATE 7 for user confirmation on the Surface Go before touching Step 8.

Start the session by running the six suites below (under a minute now) — that
confirms the environment before anything is changed.

**GATES 5 and 6 are not passed yet.** Both are judged by eye and by finger on
the Surface Go, and both are waiting on the user:

- **GATE 5**: `godot --path . -- --tracing` — the animation plays smoothly with
  no visible stutter, a full character traces by finger with responsive ink and
  no perceptible lag, stroke progression works, "watch again" replays.
- **GATE 6**: on the same screen — a careful adult trace scores 3 stars; a
  deliberately sloppy-but-on-letter trace scores 1–2; a random scribble scores
  1 star with encouragement to retry; sounds and particles play.

If the user has not confirmed those, do that first and fix within Steps 5–6
rather than starting Step 7. GATE 6's thresholds are all named constants at the
top of `scripts/scorer.gd` (`COVERAGE_TOLERANCE`, `GOOD_DEVIATION`,
`BAD_DEVIATION`, `SPRAWL_FREE`/`SPRAWL_LOST`, `THREE_STAR`, `TWO_STAR`) — if
the real hardware says an adult's careful trace only earns two stars, that is a
number to tune, not a design to rework. `tests/test_scorer.gd` prints the
quality of each synthetic trace, so retune against it.

## Where the project stands (verified)

Steps 0–6 are built; GATES 0–4 are confirmed by the user, GATES 5 and 6 pending.

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
  - **Step 7 changes the default route**: `godot --path .` should land on the
    main menu, with the font test kept behind a flag of its own.
- Project: fullscreen (mode 3), 1920×1280 base, `canvas_items` stretch,
  `gl_compatibility`, `emulate_mouse_from_touch=true`.
- Fonts: `assets/fonts/sarabun/` (looped Thai — never substitute a loopless
  font), `assets/fonts/andika/` (English/digits). There is no `assets/audio/`
  and deliberately should not be — see below.

Run the suites:

```sh
godot --headless --path . --script tests/test_stroke_data.gd    # 39 checks
godot --headless --path . --script tests/test_char_sets.gd      # 45 checks
godot --headless --path . --script tests/test_scorer.gd         # 58 checks
godot --headless --path . --script tests/validate_dataset.gd    # the dataset
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd   # 47, needs a display
```

## What Step 6 added

- `scripts/scorer.gd` — static and pure, like `dataset_validator.gd`. Its
  entry point is `score(guide, traced)` → `{ok, stars, quality, coverage,
  deviation, direction_ok, message, hint, strokes}`; `score_stroke()` scores
  one stroke, `stars_for(quality)` is the single definition of where the star
  boundaries are (**Step 7's progress file should call it rather than
  re-deriving them**). Four measurements per stroke, all in 0–1 box space:
  coverage, deviation, direction (sampled forwards and reversed, so a circle
  drawn backwards is caught) and sprawl (length relative to the guide — the
  one that catches a scribble drawn *along* the letter, which coverage and
  deviation between them happily accept).
- `scripts/star_row.gd` — `set_stars(n, total)` then `celebrate()`; draws the
  stars as polygons and pops them in, emitting `star_popped(index)` as each
  lands. It animates without allocating: `_process` advances a clock and calls
  `queue_redraw()`, then stops itself.
- `scripts/tone_bank.gd` — the sounds, synthesized (`star_tone(i)`,
  `fanfare(stars)` → `AudioStreamWAV`). **Do not add downloaded audio in Step 7
  without licensing it as carefully as the fonts were**; the reason there is no
  `assets/audio/` is written at the top of that file.
- `scripts/confetti.gd` — one `CPUParticles2D`, `celebrate()` restarts it, and
  it builds its own particle texture in code.
- `scripts/tracing.gd` — a real `_enter_score()`, the `ScoreOverlay` card
  (stars, message, hint, "again"/"next"), and `_hush()` for leaving the
  celebration early. **New signal `scored(set_id, chr, stars)`** — that is the
  hook Step 7's `progress.gd` is meant to listen to; the scene keeps no state
  of its own beyond the character in front of the child.
- `scripts/stroke_animator.gd` — `MAX_DELTA` clamps the frame delta, so a stall
  slows the demo down instead of teleporting the hand through a stroke.
- `tests/test_scorer.gd` (58 checks, headless) and eight more checks in
  `tests/test_tracing.gd` (47 now).

## What to build in Step 7

Per the plan: `main_menu.tscn` (big buttons per set), `character_select.tscn`
(a grid of large character buttons showing earned stars), `progress.gd`
(per-character best stars persisted to `user://progress.json`).

- **Entry points already exist.** `tracing.gd`'s `open(set_id, chr)` is the
  public way in — call that, do not reach into the scene. `CharSets` is the
  catalog for every grid: `SET_IDS`, `chars_of()`, `name_of()`, `label_of()`,
  `font_of()`, `is_combining()`, `recordable_ids()`.
- Connect `scored` to `progress.gd` and keep the **best** stars per character,
  never the latest — a child who scores three then two has not got worse.
- Characters with no recorded strokes should be visible but obviously not ready
  (the tracing scene already copes with them, see the EMPTY state) — that
  matters while `thai_vowels` is still empty.
- The tracing scene's `◀ char / char ▶` and `◀ set / set ▶` buttons exist only
  because there were no menus; once there are, decide deliberately whether to
  keep them and give the scene a way back to the menu (a "back" that a child
  can find, big and in a corner).
- `user://` is the only writable place in an export — `res://` is read-only
  there, which is why progress goes to `user://progress.json`. Use the same
  result-dict error handling as `stroke_data.gd`; a corrupt or missing progress
  file must start an empty one, never stop the app.
- Tests: a headless suite for `progress.gd` (save/load/merge/best-of, corrupt
  file, missing file) and a display suite for the menus driven by synthetic
  touch, in the shape of `test_tracing.gd`.

**GATE 7**: the full loop works by touch only (no keyboard/mouse): menu → pick
character → trace → stars → back; earned stars survive an app restart.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`.
- Scripts refer to each other with `preload()` constants (`CS`, `SD`, `GG`,
  `SC`, `TB`), not by `class_name`: the global class cache lives in the
  gitignored `.godot/` directory and is only written by the editor, so a fresh
  checkout run from the CLI would not resolve bare class names.
- Code style: tabs, typed GDScript, result-dict error handling (`{ok: …}`),
  no exceptions.
- **Any test that drives a scene which reads or writes stroke files must point
  `CharSets.stroke_dir` at a scratch directory under `user://`** and write the
  characters it needs there — `tests/test_recorder.gd` and
  `tests/test_tracing.gd` both do, and both check the real dataset's SHA-256s
  afterwards. A test that loads a real character will rot when Step 8
  re-records it. **A progress test needs the same treatment for
  `user://progress.json`** — give `progress.gd` a `path` static var as a test
  seam, the way `CharSets.stroke_dir` is one.
- Suites that open a window should turn vsync off
  (`DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)`): a test
  window the compositor considers hidden is throttled to a few frames a second,
  which is what made the tracing suite take minutes. With frames unthrottled,
  **never wait for a fixed number of them** — wait in seconds
  (`test_tracing.gd`'s `_until()`).
- Godot's stdout is buffered when redirected. A suite that appears to hang with
  an empty log is usually just buffered — `stdbuf -o0 godot …` to watch it
  live. A suite that genuinely hangs with no error is usually a runtime error
  inside an awaited function: the coroutine dies and `quit()` is never reached.
- Touch input is handled in `_input` gated on `box.has_point()`, never
  `_gui_input` — that deliberately avoids the mouse-emulation subtleties that
  cost time in Step 3. The score card is the exception: it is a `Control` with
  `mouse_filter = STOP` and ordinary `Button`s, which works because
  `emulate_mouse_from_touch` is on.
- Nodes are allocated per character, never per frame — `stroke_animator.gd`,
  `dotted_guide.gd`, `star_row.gd` and `confetti.gd` all hold to that, and it
  is why the demo is smooth on the Surface Go's iGPU. A menu grid of ~140
  buttons should be built once per set, not rebuilt per frame or per star
  update.
- A windowed run plus `root.get_texture().get_image()` gives screenshots for
  visual checks — worth doing for the menus, since the gate is visual.
  `root.get_final_transform()` converts base coords → window coords for
  synthetic input, but is **not** reliable for reading pixels back — measure in
  a SubViewport instead.
- Update `README.md` and the memory file `writing-practice-step-progress`
  (status + next-step brief) before stopping at the gate.
