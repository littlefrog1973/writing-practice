# Hand-off: implement Step 9 — packaging for Fedora + Windows 11

Read this first, then the plan file `docs/PLAN.md` (Step 9 section). This is
the last step; GATE 9 is the final gate, and half of it can only be judged by
the user on the Surface Go — under Fedora *and* under Windows 11.

Start the session by running the eight suites below (about a minute) — that
confirms the environment before anything is changed.

**GATE 8 passed** (user confirmed by finger on the Surface Go, 2026-08-16).

**Step 9 is built.** Both presets export and the Linux build was checked
against itself; what remains is GATE 9, which only the user can judge — and it
needs the Windows partition as well as Fedora. See "What is left" below.

## Where the project stands (verified 2026-08-16)

Steps 0–9 are built. GATES 0–8 are confirmed by the user; GATE 9 pending.

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

## What Step 9 added

`export_presets.cfg` (committed — it is what defines the build) with two
presets, each a single self-contained file with the PCK embedded:

```sh
godot --headless --path . --export-release "Linux"           build/linux/writing_practice.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/writing_practice.exe
```

`build/` is gitignored (76 MB and 112 MB, rebuilt in seconds).

- **`include_filter="data/strokes/*.json,assets/fonts/*/OFL.txt"`** is the
  preset line that matters. **Godot does not import `.json` as a resource**, so
  `export_filter="all_resources"` ships a build with the entire recorded
  dataset missing — a failure that looks perfect in every log and only appears
  when a child taps a character and gets nothing. The OFL licences are plain
  text for the same reason and must travel with the fonts.
- `exclude_filter="docs/*,tests/*"`: the suites are `.gd` files and were being
  packed into the app a child runs.
- Verified against the built binary rather than the export log — it boots from
  its own embedded pack and reports the dataset:

  ```sh
  build/linux/writing_practice.x86_64 --quit-after 120 -- --recorder
  # [recorder] Set: Thai consonants (44 characters, 44 recorded).
  ```

  `--quit-after` is load-bearing: an exported build's stdout is block-buffered
  when redirected, so one stopped with `timeout` or Ctrl-C dies without
  flushing a line and looks completely silent. That cost half an hour here.
  The same goes for `user://logs/`, which is written on a clean exit.

## What is left: GATE 9 (final), on the device

Only the user can judge it, and it needs both operating systems on the Surface
Go:

- **Fedora**: `build/linux/writing_practice.x86_64` run standalone, outside the
  editor — touch working, Thai rendering with the looped Sarabun, smooth
  inking, stars persisting across a relaunch of the *exported* binary.
- **Windows 11**: copy `build/windows/writing_practice.exe` to the Windows
  partition and run it there. Same checks.

Worth knowing before that session:

- `user://progress.json` is the only file the app writes (in an export `res://`
  is read-only, which is exactly why progress does not live beside the stroke
  data). It resolves per operating system —
  `~/.local/share/godot/app_userdata/Writing Practice/` on Fedora,
  `%APPDATA%\Godot\app_userdata\Writing Practice\` on Windows — so **booting
  Windows does not lose the Fedora stars; it starts a second, separate
  collection of them.** If that surprises the child, it is a design decision to
  revisit, not a bug to hunt.
- The log file in that same directory is the only console an exported build
  has. Ask for it before theorising.
- `gl_compatibility` and the Surface Go's iGPU are why nothing in the app
  allocates nodes per frame. If the export stutters, look for a new per-frame
  allocation before looking at engine settings.
- Nothing in Step 9 touched the app's behaviour, so a failure that is not about
  packaging is a Step 5–8 fix, and the eight suites still cover it.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`. Export output belongs in `build/`
  (gitignored), not in `/tmp`: the two builds are 188 MB together.
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
