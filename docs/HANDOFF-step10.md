# Hand-off: Step 10 — counting objects for the number sets

Read this first, then `docs/PLAN.md` (Step 10 at the end, and the "Amended by
Step 10" note on Step 5). `docs/HANDOFF-step9.md` remains the map of the app as
it stood when the project was first finished — everything in it is still true
except where this document says otherwise.

**Status: Step 10 is built. The headless half of GATE 10 has passed. The touch
half is waiting on the user** — it can only be judged with a finger on the
Surface Go, under Fedora and under Windows 11 (GATE 9 is re-run as part of it,
because both builds were rebuilt).

Nothing in this step wrote to `data/strokes/` and nothing can: the dataset is
still 137 of 137, validating clean, and `progress.gd` and `scorer.gd` were not
touched. Counting is never scored.

## What to check by finger (GATE 10)

On the Surface Go, from the main menu:

1. **Digits → "3"** — three apples appear, faint, with "how many?" above them.
   Each tap fills one in with a pop and a note a step higher than the last, and
   the caption counts 1… 2… 3. After the third it reads **"3 — three"**, and
   half a second later the tracing demo starts on its own.
2. **Thai numerals → "๓"** — the *same three apples*, and the caption ends
   **"๓ — สาม"**. That the two numeral systems show the same objects for the
   same quantity is the point of the step.
3. **Digits → "0"** — an empty basket, and one tap anywhere on it moves on,
   captioned "nothing — zero!".
4. **A Thai consonant and an English letter** — open straight into the demo,
   with no counting overlay and nothing changed from before.
5. **The score card's "again"** — back to tracing, *without* counting again. So
   does "start over"; "watch again" replays the demo, also without counting.
6. Nine objects (write "9") are still a comfortable finger target, and no tap
   ever counts the object next to the one aimed at.

Then rebuild nothing — both builds are already rebuilt from this code — and run
`build/windows/writing_practice.exe` on the Windows 11 partition once more, as
GATE 9 asks: touch, looped Thai, inking, stars persisting.

If the objects are too small, too big, or the wrong things, it is
`scripts/object_art.gd` alone: `MAX_RADIUS_RATIO`, `FILL_RATIO`, `VALUE_KINDS`.
If a tap is hard to land, `TAP_SLACK` in `scripts/count_objects.gd`. If the
counting is unwelcome for one of the sets, `numeric` in `scripts/char_sets.gd`
turns it off for that set and nothing else changes.

## What Step 10 added

- **`CharSets`** — sets carry a `numeric` flag (`digits`, `thai_numerals`);
  `is_numeric(id)`, `value_of(id, chr)` (−1 for everything that is not a
  numeral of a numeric set) and `numeral_value(chr)`, which reads the quantity
  from the **code point** (๓ is three because it is U+0E53) rather than from
  where the character sits in a list. `validate()` now rejects a numeric set
  that is not the ten quantities 0–9, each exactly once.
- **`scripts/object_art.gd`** — new, static and pure, no nodes: `VALUE_KINDS`
  (the fixed value → object table), `kind_for_value()`, `layout()`,
  `radius_for()`, `draw_object()`, `draw_basket()`. Six kinds — apple, balloon,
  fish, ball, flower, leaf — drawn in `_draw()` calls, no imported art, for the
  same reason `tone_bank.gd` synthesizes its sounds.
- **`scripts/count_objects.gd`** — new `Control`. `set_count(n)`, signals
  `counted(n)` and `finished`, `tap_at(local_point)` as the whole decision.
  One node, everything in `_draw()`, nothing allocated while it animates, and
  `_process` switches itself off when there is nothing to animate.
- **`ToneBank.count_tone(index)`** — nine bells up a C major scale, built with
  the score sounds when the scene loads.
- **`scenes/tracing.tscn`** — `CountOverlay` (a `Caption` label and the
  `Objects` node) sized to the drawing box in code, and `Sounds/Count`.
- **`scripts/tracing.gd`** — `State.COUNT` ahead of `DEMO`, entered from
  `_open_char()` only when `CS.value_of()` is ≥ 0. The guide glyph and the
  top-bar name are hidden while counting (both are the answer to the question on
  screen). `_hide_count()` is called by every state that can follow.
- **`tests/test_count_objects.gd`** — 80 checks, headless.

## Things worth knowing before changing any of it

- **An object built from overlapping shapes needs one silhouette, not an
  outline per part.** `_blob()` draws every part pushed out from the object's
  centre in the edge colour, then every part at its real size on top. Outlining
  each circle separately turned the apple into a pumpkin; that was found by
  screenshotting the screen, not by reading the code — as the backwards `◌เ`
  was in Step 8. **Screenshot anything drawn in code before believing it.**
- `Geometry2D.offset_polygon()` is the proper way to grow an outline and is
  deliberately *not* used: at these sizes its arc tolerance leaves a visible
  ripple along every curve. Pushing each point out from the centre by a fixed
  distance is what keeps the outline smooth *and* an even width — plain scaling
  makes it thin across a flat object like a leaf and fat along it.
- **A lone object needs a capped radius** (`MAX_RADIUS_RATIO`): a cell is the
  whole box when there is one thing in it, and the first version drew one
  balloon the size of the drawing box with its string hanging over the caption
  below. Every object must stay inside ±radius of its centre — that is what the
  layout guarantees room for, and what the suite's spacing checks assume.
- The overlay reads touch in **`_input()` gated on its own rect**, like the
  recorder and the tracing scene, not `_gui_input()`. `tap_at()` holds the
  decision in control-local coordinates so the headless suite can count without
  a display; `test_menus.gd` proves a real finger reaches it.
- `finished` is emitted **after** the last pop (`FINISH_DELAY`), not on the tap,
  so the child sees the thing they just counted before the screen changes.
- `test_menus.gd` counts its way into the tracing scene now (its test set is
  `digits`). Any suite that opens a numeral must do the same or it will sit in
  `State.COUNT` waiting for a finger. `test_tracing.gd` uses `thai_consonants`
  and was not affected — which is itself the check that nothing else changed.

## Running everything (about two minutes)

```sh
godot --headless --path . --script tests/test_stroke_data.gd     # 39 checks
godot --headless --path . --script tests/test_char_sets.gd       # 56 checks
godot --headless --path . --script tests/test_scorer.gd          # 58 checks
godot --headless --path . --script tests/test_progress.gd        # 70 checks
godot --headless --path . --script tests/test_count_objects.gd   # 80 checks
godot --headless --path . --script tests/validate_dataset.gd     # 137/137
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd  # 28, needs a display
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd   # 51, needs a display
godot --path . -w --resolution 960x640 --script tests/test_menus.gd     # 56, needs a display
```

Rebuilding the two exports (**`mkdir -p` first — Godot will not create the
directory, and it fails while still exiting 0**):

```sh
mkdir -p build/linux build/windows
godot --headless --path . --export-release "Linux"           build/linux/writing_practice.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/writing_practice.exe
build/linux/writing_practice.x86_64 --quit-after 200 -- --tracing   # boots from its own pack
```
