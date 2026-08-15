# Hand-off: implement Step 8 — Thai vowels & tone marks

Read this first, then the plan file `docs/PLAN.md` (Step 8 section). Stop at
GATE 8 for user confirmation on the Surface Go before touching Step 9.

Start the session by running the eight suites below (about a minute) — that
confirms the environment before anything is changed.

**GATE 7 is not passed yet.** It is judged by finger on the Surface Go and is
waiting on the user:

- **GATE 7**: `godot --path .` — the full loop works by touch only, no keyboard
  and no mouse: menu → pick a set → pick a character → trace → stars → back →
  back. Earned stars survive quitting and relaunching the app.

If the user has not confirmed it, do that first and fix within Step 7 rather
than starting Step 8. The suite `tests/test_menus.gd` already walks that exact
path with synthetic touches and passes, so a GATE 7 failure is most likely
about size, reach or clarity on a real 10" screen — a layout number in
`main_menu.gd` / `character_select.gd`, not a design to rework.

Note that the tracing scene's buttons changed after GATES 5 and 6 were passed:
all three child-facing scenes now share `assets/theme/app_theme.tres`, so its
buttons are white rounded cards instead of Godot's default grey slabs. Nothing
about the layout, the drawing box or the score card moved, but it is worth a
second look at the same time as GATE 7.

## Where the project stands (verified)

Steps 0–7 are built; GATES 0–6 are confirmed by the user, GATE 7 pending.

The project is a **git repository** (`main`). Commit as you go; the stroke data
is hand-authored on a touch screen and cannot be regenerated.

The dataset is **116/116 characters, validating clean** — every set except
`thai_vowels`, which is an empty catalog stub. **Filling it is the whole of
Step 8.** Do not clobber the rest.

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
godot --headless --path . --script tests/test_char_sets.gd      # 45 checks
godot --headless --path . --script tests/test_scorer.gd         # 58 checks
godot --headless --path . --script tests/test_progress.gd       # 70 checks
godot --headless --path . --script tests/validate_dataset.gd    # the dataset
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd   # 47, needs a display
godot --path . -w --resolution 960x640 --script tests/test_menus.gd     # 45, needs a display
```

## What Step 7 added

- `scripts/progress.gd` (`Progress`, static) — the stars the child keeps, in
  `user://progress.json`. `load_progress()` / `save_progress()` /
  `record(data, set, chr, stars)` / `record_and_save()` / `merge()` /
  `summary(data, set)` / `total_stars()` / `clear()`. **Best stars, never the
  latest**; a missing, corrupt or hand-edited file always ends in a usable
  (possibly empty) dictionary and a console line, never a stopped app.
  `Progress.path` is a **test seam** exactly like `CharSets.stroke_dir`.
- `scripts/screens.gd` (`Screens`, static) — the navigation graph and the
  scene swapping, in one place. `go_menu()`, `go_chars(set)`,
  `go_trace(set, chr)`, and `record_result()`, which is what connects the
  tracing scene's `scored` signal to the progress file. Scenes are swapped by
  hand (instantiate → `setup` → free the old → add → set `current_scene`) so a
  screen knows its subject *before* `_ready()`; the swap is deferred, so
  calling it from a button's own `pressed` signal is safe.
- `scenes/main_menu.tscn` + `scripts/main_menu.gd` — a button per set, built
  from the catalog, with the set's own first character in the set's own font.
  Signal `set_chosen(set_id)`.
- `scenes/character_select.tscn` + `scripts/character_select.gd` — the grid,
  built once per set. `show_set(id)` (works before or after `_ready`, like the
  tracing scene's `open()`), signals `char_chosen(set_id, chr)` and
  `back_requested()`. Columns = √(n · 2.2) clamped to 4–8; cells never taller
  than wide; the character's font size and star height scale with the cell.
  It reuses `star_row.gd` per button (`SR.new()`), and reads the set's stroke
  file to tell recorded characters from ones not ready yet.
- `scripts/tracing.gd` — new signal **`back_requested(set_id)`**, a big "◀ back"
  at the bottom of the side panel, and a third button on the score card. That
  last one is not decoration: the card sits over the side panel on purpose, so
  it covers the panel's "back", and without its own the only ways out of a
  celebration were "again" and "next". `test_menus.gd` is what caught it.
  `◀ set / set ▶` are gone (the menu owns that decision); `◀ char / char ▶`
  stayed; Esc now steps back a screen instead of quitting.
- `tests/test_progress.gd` (70 checks, headless) and `tests/test_menus.gd`
  (45 checks, needs a display).

## What to build in Step 8

Per the plan: the remaining characters are **Thai vowels and tone marks**, and
they need to be put in the catalog before they can be recorded.

1. **Fill `thai_vowels` in `scripts/char_sets.gd`.** It is currently
   `_make_set(..., PackedStringArray(), PackedStringArray(), true)` — an empty
   stub with `combining = true`. Which vowels and tone marks belong there is a
   teaching decision, so **ask the user** rather than choosing from Unicode:
   the usual school set is the สระ (–ะ –า –ิ –ี –ึ –ื –ุ –ู เ– แ– โ– ใ– ไ– …)
   plus the four tone marks (–่ –้ –๊ –๋), but which forms a five-year-old is
   taught first, in what order, and under what names is theirs to say.
   `tests/test_char_sets.gd` will check the names array matches the chars.
2. **Record them** with the Stroke Recorder — the user's hands, on the Surface
   Go: `godot --path . -- --recorder`, then ↑/↓ to the vowel set. **Both the
   recorder and the tracing scene already draw combining marks on the dotted
   placeholder circle** (`"◌" + chr` when `CS.is_combining(id)`), and so does
   the new character-select grid, so nothing needs adding for that.
3. **Validate**: `godot --headless --path . --script tests/validate_dataset.gd`
   after each batch, and `-- --missing thai_vowels` to see what is left.

Notes that matter here:

- Vowels sit high or low against the placeholder rather than filling the box.
  `glyph_guide.gd` places the *glyph*, and stroke points are normalized to the
  box, not to their own bounding box — so a mark recorded high stays high. Do
  not "helpfully" re-centre anything.
- Several marks are a single small stroke. `dataset_validator.gd` warns (and
  allows) a stroke under 2% of the box; expect more of those warnings than in
  the other sets, and read them rather than silencing them.
- A tiny mark is also the case where the tracing scene's `MIN_TRACE_LENGTH`
  (24 px) and the scorer's `DOT_LENGTH` matter most. Trace a couple by finger
  and check a legitimate short stroke is not being treated as a stray tap.
- The menus need nothing: as soon as `thai_vowels` has characters, the main
  menu button stops being greyed and the grid fills itself from the catalog.
  Characters not yet recorded show as "soon" until they are.

**GATE 8**: validation passes for all ~140 characters; every character-select
grid is fully populated; the user spot-checks a handful of Thai vowels for
sensible rendering and tracing.

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
  visual checks — worth doing for anything laid out in code.
  `root.get_final_transform()` converts base coords → window coords for
  synthetic input, but is **not** reliable for reading pixels back.
- Update `README.md` and the memory file `writing-practice-step-progress`
  (status + next-step brief) before stopping at the gate.
