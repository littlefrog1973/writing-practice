# Hand-off: implement Step 9 — packaging for Fedora + Windows 11

Read this first, then the plan file `docs/PLAN.md` (Step 9 section). This is
the last step; GATE 9 is the final gate, and half of it can only be judged by
the user on the Surface Go — under Fedora *and* under Windows 11.

Start the session by running the eight suites below (about a minute) — that
confirms the environment before anything is changed.

**GATE 8 is not passed yet.** It is judged by finger on the Surface Go and is
waiting on the user:

- **GATE 8**: the vowel grid is full, and a handful of Thai vowels render and
  trace sensibly — `godot --path .` → Thai vowels & tone marks.

Everything that can be checked without a finger has been: validation is clean
at 137/137, a perfect trace of every one of the 137 scores three stars, the
dotted guide sits on the glyph in screenshots of ◌ิ ◌ื เ◌ ไ◌ ◌่ ◌์, and the
suites pass. What is left is how the small marks feel to draw. If something is
wrong it is most likely one of:

- a mark too small to trace comfortably — that is
  `GlyphGuide.COMBINING_SIZE_RATIO` (0.60), and **raising it needs the vowels
  re-recorded**, because strokes are stored relative to the box and the glyph
  would move under them. Measure before changing it: at 0.76 the tallest marks
  put ink outside the box entirely (see the Step 8 notes below).
- a short stroke being ignored — that is `MIN_TRACE_LENGTH` (24 px) and
  `MIN_TRACE_RATIO` (0.4) in `tracing.gd`, tuning, not redesign.
- a mark scoring badly when it looked right — `scorer.gd`'s thresholds, which
  work in fractions of the box and so are unaffected by the smaller glyph.

## Where the project stands (verified 2026-08-16)

Steps 0–8 are built. GATES 0–7 are confirmed by the user; GATE 8 pending.

**The dataset is finished: 137 of 137 characters, validating clean** — 44 Thai
consonants, 26 capitals, 26 small letters, 10 digits, 10 Thai numerals, 21 Thai
vowels & tone marks. It is hand-authored on a touch screen and cannot be
regenerated; the repository exists mainly for it. Nothing in Step 9 should
write to `data/strokes/`.

- Godot **4.7.1-stable** at `~/.local/bin/godot`; export templates already
  installed at `~/.local/share/godot/export_templates/4.7.1.stable/`.
- Main scene is `scenes/main.tscn` (`scripts/main.gd`), a boot router on
  `OS.get_cmdline_user_args()`; every route goes through `scripts/screens.gd`:
  - `godot --path .` → the **main menu**
  - `godot --path . -- --tracing` → the tracing scene, first character
  - `godot --path . -- --recorder` → the Stroke Recorder
  - `godot --path . -- --fonts` → the Step 1 font diagnostics (keep it)
  - add `--mouse` to draw with the mouse (sets `Input.emulate_touch_from_mouse`
    at runtime; the project setting itself stays off)
- Project: fullscreen (mode 3), 1920×1280 base, `canvas_items` stretch,
  `gl_compatibility`, `emulate_mouse_from_touch=true`.
- Fonts: `assets/fonts/sarabun/` (looped Thai — never substitute a loopless
  font), `assets/fonts/andika/`. There is no `assets/audio/` and deliberately
  should not be — the sounds are synthesized in `scripts/tone_bank.gd`.

Run the suites:

```sh
godot --headless --path . --script tests/test_stroke_data.gd    # 39 checks
godot --headless --path . --script tests/test_char_sets.gd      # 56 checks
godot --headless --path . --script tests/test_scorer.gd         # 58 checks
godot --headless --path . --script tests/test_progress.gd       # 70 checks
godot --headless --path . --script tests/validate_dataset.gd    # 137/137
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd   # 51, needs a display
godot --path . -w --resolution 960x640 --script tests/test_menus.gd     # 51, needs a display
```

## What Step 8 added

- **`CharSets.THAI_VOWEL_CHARS` / `THAI_VOWEL_NAMES`** — the 21 marks the user
  chose, in teaching order: the fifteen สระ in recital order
  (ะ ั า ำ ิ ี ึ ื ุ ู เ แ โ ใ ไ), the four tone marks, then ไม้ไต่คู้ and
  การันต์. One quoted character per line: a run of combining code points in a
  single string cannot be read or edited safely.
- **`CharSets.display_form(set_id, chr)`** — how a character is drawn: itself,
  or the mark on the dotted placeholder ◌ **on the side it is really written**.
  The five leading vowels (`THAI_LEADING_VOWELS` — เ แ โ ใ ไ) come before it,
  everything else after: `เ◌`, but `◌ิ`. The `"◌" + chr` that the three scenes
  each built themselves rendered a third of the set back to front, and was
  found by screenshotting the recorder, not by reading the code.
- **`GlyphGuide.COMBINING_SIZE_RATIO`** (0.60, against `FONT_SIZE_RATIO` 0.76)
  — a placeholder cluster is two characters stacked, and at the letter size the
  tallest marks (◌็, ไ◌, ◌์) put ink up to 0.065 of the box *above* its top
  edge, where the recorder clamps every touch: a guide asking for a stroke
  nobody could draw. All 21 were measured in a SubViewport; at 0.60 every one
  is inside with ≥0.05 of the box to spare. `apply()` derives the ratio from
  the text itself (`size_ratio_for()`), not from an argument each scene passes,
  so no recorded glyph can be resized under its own strokes — `test_char_sets`
  asserts every non-combining character still gets 0.76.
- **`MIN_TRACE_RATIO`** (0.4) in `tracing.gd` — the stray-tap floor is now
  never more than 40% of the stroke being asked for. Before the vowels the
  shortest real stroke anywhere was Q's tail at 184 px, against a 24 px floor;
  ◌ื's third stroke is 41 px, where a flat floor demands 58% of the stroke
  before it counts. The dot exemption stays: a tap has no length at all, so a
  ratio alone would reject the dot on an "i".
- Suites: `test_char_sets.gd` 56, `test_tracing.gd` 51, `test_menus.gd` 51.
  The menu suite now walks into a set that is in the catalog but not yet
  recorded and checks it is not a dead end; the tracing suite traces a stroke
  short enough for the floor to give way.

## What to build in Step 9

1. **Export presets** — Linux x86_64 and Windows Desktop, embedded PCK, one
   file each. `export_presets.cfg` is a project file and should be committed;
   the *output* must not be, so add the export directory to `.gitignore`
   before the first export (there is no entry yet — `.gitignore` currently has
   only `.godot/`).
2. **Document the one-line export commands** in the README, next to the run
   commands, e.g.
   `godot --headless --path . --export-release "Linux/X11" build/writing_practice`.
3. **The user copies the .exe to the Windows partition and tests it there.**

Things worth checking before handing over a build:

- `user://progress.json` is the only file the app writes, and in an export
  `res://` is read-only — that is exactly why progress does not live beside the
  stroke data. Confirm the stars persist across a relaunch of the *exported*
  binary, not just the editor run.
- Stroke files are loaded through `CharSets.path_of()`; an exported build
  serves `foo.json.remap`, which `dataset_validator.gd` already tolerates but
  `stroke_data.gd` reads through `FileAccess` on the `res://` path. Check a set
  actually loads in the export rather than assuming it.
- The fonts and their OFL licences are in `assets/`; keep the licence files in
  the export.
- `gl_compatibility` and the Surface Go's iGPU are why nothing allocates nodes
  per frame. If the export stutters, look for that before looking at settings.

**GATE 9 (final)**: the Linux export runs standalone on Fedora with working
touch; the Windows .exe runs on Win11 on the same machine with working touch,
correct Thai rendering (looped Sarabun) and stars persisting; inking is smooth
on both.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`. Export output belongs under the project
  (gitignored), not in `/tmp`.
- Scripts refer to each other with `preload()` constants (`CS`, `SD`, `GG`,
  `SC`, `TB`, `PR`, `SR`, `SNS`), not by `class_name`: the global class cache
  lives in the gitignored `.godot/` directory and is only written by the
  editor, so a fresh checkout run from the CLI would not resolve bare names.
- Code style: tabs, typed GDScript, result-dict error handling (`{ok: …}`),
  no exceptions.
- **Any test that drives a scene which reads or writes stroke files must point
  `CharSets.stroke_dir` at a scratch directory under `user://`** and write the
  characters it needs there — `test_recorder.gd`, `test_tracing.gd` and
  `test_menus.gd` all do, and all check the real dataset's SHA-256s afterwards.
  **Anything touching progress must do the same with `Progress.path`**, and
  check `user://progress.json` afterwards: a stroke file can be re-recorded, a
  child's stars cannot.
- Suites that open a window should turn vsync off
  (`DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)`): a test
  window the compositor considers hidden is throttled to a few frames a second.
  With frames unthrottled, **never wait for a fixed number of them** — wait in
  seconds (`_until()`), or for the thing itself (`_wait_for()`).
- Godot's stdout is buffered when redirected. A suite that appears to hang with
  an empty log is usually just buffered — `stdbuf -o0 godot …` to watch it
  live. A suite that genuinely hangs with no error is usually a runtime error
  inside an awaited function: the coroutine dies and `quit()` is never reached.
- Touch input in the drawing scenes is handled in `_input` gated on
  `box.has_point()`, never `_gui_input`. The menus and the score card are the
  exception: ordinary `Button`s, which work under a finger because
  `emulate_mouse_from_touch` is on. Test them with real synthetic touches
  (`test_menus.gd`'s `_tap`) rather than `pressed.emit()` — that is the only
  way a covered or unreachable button ever shows up.
- Nodes are allocated per character, never per frame — `stroke_animator.gd`,
  `dotted_guide.gd`, `star_row.gd`, `confetti.gd` and the two menu grids all
  hold to that, and it is why everything is smooth on the Surface Go's iGPU.
- A windowed run plus `root.get_texture().get_image()` gives screenshots for
  visual checks — worth doing for anything laid out in code, and it is how the
  backwards `◌เ` was spotted. For *measuring* rendered ink, render into a
  SubViewport instead: `root.get_final_transform()` converts base coords →
  window coords for synthetic input but is not reliable for reading pixels back.
- Update `README.md` and the memory file `writing-practice-step-progress`
  (status + next-step brief) before stopping at the gate.
