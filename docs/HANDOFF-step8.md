# Hand-off: Step 8 — Thai vowels & tone marks

Read this first, then the plan file `docs/PLAN.md` (Step 8 section). Stop at
GATE 8 for user confirmation on the Surface Go before touching Step 9.

Start the session by running the eight suites below (about a minute) — that
confirms the environment before anything is changed.

**GATE 7 passed** (user confirmed by finger on the Surface Go, 2026-08-16).

**Step 8 is half done.** The catalog half is built and committed (`eddf6be`);
the recording half needs the user's hands and is what remains:

- **Done**: `thai_vowels` holds the 21 marks, the scenes draw them on the right
  side of the dotted placeholder at a size that fits the box, and the suites
  cover the state the set is in now.
- **To do**: record the 21 with the Stroke Recorder, then GATE 8.

## Where the project stands (verified 2026-08-16)

Steps 0–7 built and gated; Step 8's catalog work built, its recordings not.

The project is a **git repository** (`main`). Commit as you go; the stroke data
is hand-authored on a touch screen and cannot be regenerated.

The dataset is **116 of 137 characters, validating clean**. The 21 missing are
exactly the vowels. **Do not clobber the rest.**

- Godot **4.7.1-stable** at `~/.local/bin/godot`; export templates installed.
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
  font), `assets/fonts/andika/` (English/digits). There is no `assets/audio/`
  and deliberately should not be — the sounds are synthesized in
  `scripts/tone_bank.gd`.

Run the suites:

```sh
godot --headless --path . --script tests/test_stroke_data.gd    # 39 checks
godot --headless --path . --script tests/test_char_sets.gd      # 54 checks
godot --headless --path . --script tests/test_scorer.gd         # 58 checks
godot --headless --path . --script tests/test_progress.gd       # 70 checks
godot --headless --path . --script tests/validate_dataset.gd    # the dataset
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd   # 47, needs a display
godot --path . -w --resolution 960x640 --script tests/test_menus.gd     # 51, needs a display
```

## What the catalog half added

- **`CharSets.THAI_VOWEL_CHARS` / `THAI_VOWEL_NAMES`** — 21 marks in teaching
  order: the fifteen สระ in recital order (ะ ั า ำ ิ ี ึ ื ุ ู เ แ โ ใ ไ), the
  four tone marks, then ไม้ไต่คู้ and การันต์. The user chose the list and the
  order; it is a teaching decision, not a Unicode one. Listed one quoted
  character per line, because a run of combining code points in a single string
  cannot be read or edited safely.
- **`CharSets.display_form(set_id, chr)`** — how a character is drawn: itself,
  or the mark on the dotted placeholder ◌ **on the side it is really written**.
  The five leading vowels (`CharSets.THAI_LEADING_VOWELS` — เ แ โ ใ ไ) come
  before it, everything else after: `เ◌`, but `◌ิ`. The old `"◌" + chr` in the
  three scenes rendered a third of the set back to front. The recorder, the
  character grid, the tracing scene and `--missing` all ask here now.
- **`GlyphGuide.COMBINING_SIZE_RATIO`** (0.60, against `FONT_SIZE_RATIO` 0.76)
  — a placeholder cluster is two characters stacked, and at the letter size the
  tallest marks (◌็, ไ◌, ◌์) put ink up to 0.065 of the box **above the top
  edge**. The recorder clamps every touch to the box, so that guide was asking
  for a stroke nobody could draw. All 21 were measured in a SubViewport; at
  0.60 every one is inside with at least 0.05 of the box to spare (tightest ◌็
  at 0.052 from the top, lowest ◌ู at 0.868). **`GlyphGuide.apply()` picks the
  ratio from the text itself** (`size_ratio_for()`, keyed on the placeholder)
  rather than from an argument each scene passes: three call sites is three
  chances to disagree, and a glyph resized under strokes already recorded
  against it is silent damage. No recorded character contains the placeholder,
  so the 116 are untouched — `test_char_sets.gd` asserts exactly that.
- **`tests/validate_dataset.gd`** prints missing combining marks on their
  placeholder too; bare, they attach to the separating space and the list comes
  out as one smear.
- Test updates: `test_char_sets.gd` (+9, now 54) covers the 21, that every one
  is a single code point in U+0E30…U+0E4C, the names lining up with their
  marks, `display_form` on both sides, and the guide-sizing invariant.
  `test_menus.gd` (+6, now 51) replaces the "empty set is greyed" checks with
  the state the set is really in — catalogued, nothing recorded — and walks
  into it: the grid fills from the catalog, every character says "soon" and
  refuses a finger, a leading vowel reads `เ◌`, **and "back" gets out again**.
  That last one is the point: a set is in this state between every catalog
  entry and its recording, and it must not be a dead end. `test_progress.gd`
  swapped `thai_vowels` for an unknown set id in its "nothing to write" check.

## What is left: record the 21

```sh
godot --path . -- --recorder      # then ↑/↓ to "Thai vowels & tone marks"
```

Draw, **SAVE**, **char ▶**, repeat; the side panel counts `n / 21 recorded`.
After each batch:

```sh
godot --headless --path . --script tests/validate_dataset.gd
godot --headless --path . --script tests/validate_dataset.gd -- --missing thai_vowels
```

Then **commit the batch** — this is the only data in the project nobody can
regenerate.

Notes that matter while recording:

- Stroke order and direction are the data, not the shape. The recording
  conventions already chosen: Thai consonants are one stroke starting at the
  loop (หัว); English capitals lift only where the pen must; digits 1 and 4 are
  two strokes, the rest one. Whatever is chosen for the vowels, keep it
  consistent across the set — `scorer.gd` compares stroke by stroke.
- Marks sit high or low against the placeholder rather than filling the box.
  Stroke points are normalized to the **box**, not to the mark's own bounding
  box, so a mark recorded high stays high. Do not "helpfully" re-centre it.
- Several marks are a single small stroke. `dataset_validator.gd` warns (and
  allows) a stroke under 2% of the box; expect more of those warnings here than
  in any other set, and read them rather than silencing them.
- A tiny mark is also where the tracing scene's `MIN_TRACE_LENGTH` (24 px) and
  the scorer's `DOT_LENGTH` matter most. **Trace ◌่ and ◌์ by finger early** —
  before recording all 21 — and check a legitimate short stroke is not being
  treated as a stray tap. If it is, that is a threshold to tune, not a design
  to rework, and better found on the first mark than the twenty-first.
- The menus need nothing. Each character stops saying "soon" as it is recorded.

**GATE 8**: validation passes at 137/137; every character-select grid is fully
populated; the user spot-checks a handful of Thai vowels for sensible rendering
and tracing on the Surface Go.

## Pitfalls / conventions

- `/tmp` is a 3.9 GB tmpfs shared with the tool harness — never download or
  extract big files there; use `/home`.
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
