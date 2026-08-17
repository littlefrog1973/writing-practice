# Thai/English Handwriting Practice App (Godot 4) — Gated Implementation Plan

## Context

A finger-tracing app for a child to learn to write Thai and English alphanumeric characters, running fullscreen on a touch-screen Surface Go dual-booting Fedora 44 and Windows 11. Stack chosen by user: **Godot 4.x + GDScript** (user knows Python). First version: letter tracing over guides, stroke-order animation, accuracy feedback with celebration. Character sets: 44 Thai consonants (ก–ฮ), English A–Z upper+lower, digits 0–9 + Thai numerals ๐–๙, Thai vowels/tone marks (~140 characters total).

The project directory is empty (greenfield).

**How to use this plan**: execute one step at a time, in order. Each step ends with a **GATE** — a concrete check that must pass (with the user confirming touch-related gates on the real hardware) before starting the next step. If a gate fails, fix within the step; do not proceed.

### Status (revised 2026-08-16)

**Steps 0–9 are built and their gates passed** — the app ships as a Linux binary and a Windows .exe. Do not re-implement them; they are kept below as the record of what exists.

**Step 10 is the new work**: the digits and Thai-numeral sets teach the *shape* of a number but never its *quantity*. A child can trace "3" perfectly without connecting it to three of anything. Step 10 adds a counting activity to those two sets — objects drawn on screen that the child taps and counts before writing the numeral. Only Step 5's state machine is amended; everything else is additive.

**Step 10 is built (2026-08-16) and the headless half of GATE 10 has passed**: `tests/test_count_objects.gd` (126 checks) plus the eight existing suites (39 / 56 / 58 / 70 / 137-of-137 / 28 / 51 / 56) and both exports rebuilt and booted from their own pack. **The touch half of GATE 10 is waiting on the user** on the Surface Go, Fedora and Windows 11 both. `docs/HANDOFF-step10.md` is the brief.

**Two of Step 10's decisions were overturned on 2026-08-17, after looking at the screen** (the user's call, both of them): **zero draws nothing at all** rather than an empty basket — a basket is a thing, and a child asked "how many?" in front of a thing answers one; the tap that answers "none" is unchanged. And **an object waiting to be counted is a pale wash of its own colour**, not a hollow white outline — hollow read as a diagram of an apple rather than an apple. The "empty basket" wording below is left as written to keep the record straight; `object_art.gd`, `README.md` and `docs/HANDOFF-step10.md` describe what is actually there.

## Key design decisions (apply throughout)

- Godot 4.x (latest stable, ≥4.3), GDScript, **Compatibility renderer** (Surface Go weak iGPU).
- **Thai guide font must be looped (มีหัว)**: Sarabun or Noto Sans Thai Looped — Thai school handwriting teaches looped forms; loopless fonts are wrong for teaching. English/digits: Andika (SIL literacy font). All OFL-licensed.
- **Stroke data format**: one JSON per character set in `data/strokes/`, entries `{ "char": "ก", "set": "thai_consonant", "name": "ก ไก่", "strokes": [[[x,y],...], ...] }`, points normalized to a 0–1 box. Thai strokes start at the loop (หัว) per convention.
- **Stroke authoring** via an in-app dev-only **Stroke Recorder**: reference glyph shown large at low opacity, adult traces each stroke in order on the touch screen, tool saves JSON. This is how ~140 characters get authored without hand-writing SVG paths.
- **Touch input**: handle `InputEventScreenTouch`/`InputEventScreenDrag`; project settings: `input_devices/pointing/emulate_mouse_from_touch = true` (UI buttons work), `emulate_touch_from_mouse = true` only behind a debug flag for desktop testing.
- **Scoring**: per stroke — coverage (fraction of guide points within tolerance of trace), deviation (mean trace→guide polyline distance), direction/order correctness → 1–3 stars. Generous, child-friendly tolerances; retry is encouraged, never a "fail" state.
- **Thai vowels/tone marks**: traced standalone at large size with a dotted placeholder circle where the consonant would sit.
- **No binary assets beyond the two OFL fonts** (added Step 10, but already the practice through Step 9): the score sounds are synthesized in `tone_bank.gd` and the stars and confetti are drawn in code, precisely so that nothing enters the repo whose provenance cannot be reconstructed. Counting artwork follows the same rule — drawn with `_draw()`, not imported.

## Project structure (target)

```
writing_practice/
├── project.godot
├── assets/
│   ├── fonts/            # Sarabun (or Noto Sans Thai Looped), Andika + OFL licenses
│   └── audio/            # success/star sounds
├── data/strokes/         # thai_consonants.json, english_upper.json, english_lower.json,
│                         # digits.json, thai_numerals.json, thai_vowels.json
├── scenes/
│   ├── main_menu.tscn
│   ├── character_select.tscn
│   ├── tracing.tscn
│   └── stroke_recorder.tscn   # dev-only, launched via --recorder arg or debug menu
└── scripts/
    ├── stroke_data.gd    # load/save stroke JSON, resampling/normalization
    ├── tracing.gd        # input capture, guide rendering, state machine
    ├── stroke_animator.gd# animated stroke-order demo (growing Line2D + finger dot)
    ├── scorer.gd         # accuracy scoring
    ├── progress.gd       # per-character stars → user://progress.json
    ├── count_objects.gd  # (Step 10) tap-to-count panel for the number sets
    └── object_art.gd     # (Step 10) the countable things, drawn in code
```

---

## Step 0 — Tech stack installation (Fedora 44)

1. Install Godot 4.x on Fedora. Preferred: official standalone binary from godotengine.org (always current) unpacked to `~/.local/bin/godot`; alternatives: `sudo dnf install godot` or Flatpak `org.godotengine.Godot`. Pick whichever gives ≥4.3; note the choice in README.
2. Install matching **export templates** (needed later for Linux + Windows builds): via editor UI (Editor → Manage Export Templates) or `godot --headless` download.
3. Download fonts: Sarabun (Google Fonts) or Noto Sans Thai Looped, and Andika (SIL) — keep the OFL license files alongside.
4. Confirm the touch screen works under Fedora/Wayland at OS level (`libinput debug-events` shows touch, or simply touch-scroll in a browser).

**GATE 0**: `godot --version` prints 4.x; the editor opens and creates a throwaway project; export templates for the installed version are present; font files exist on disk; user confirms OS-level touch input works on Fedora.

## Step 1 — Project scaffold

1. Create the Godot project in the project directory: fullscreen window, base resolution 1920×1280 (Surface Go native), `canvas_items` stretch mode, Compatibility renderer, touch settings as per design decisions.
2. Import fonts; make a test scene showing "ก ไก่ A a ๑ 1" in large type using the looped Thai font.
3. Add README noting Godot version and how to run.

**GATE 1**: app launches fullscreen on Fedora; Thai text renders with visible loops and correctly positioned marks (user eyeballs ก ไก่ / อ่ on screen); a touch on the screen registers as `InputEventScreenTouch` (print to console).

## Step 2 — Stroke data module

1. Implement `stroke_data.gd`: JSON schema load/save, point resampling to fixed spacing, normalization to 0–1 box, denormalization to screen rect.
2. Create one hand-made sample file (e.g. digit "1" with one stroke) for testing.

**GATE 2**: a headless test script (`godot --headless --script tests/test_stroke_data.gd`) passes: save→load round-trip preserves data; resampling produces evenly spaced points; malformed JSON is rejected with a clear error.

## Step 3 — Stroke Recorder (authoring tool)

1. Build `stroke_recorder.tscn`: shows reference glyph (large Label, ~30% opacity) for a chosen character, records touch strokes as ordered point lists, undo-last-stroke, clear, save to `data/strokes/<set>.json`, next/prev character in set.
2. Launch via `godot -- --recorder` command-line arg so the child never sees it.
3. Add replay-recorded-strokes preview inside the tool.

**GATE 3**: user records "A" and "ก" by finger on the Surface Go; JSON entries appear in the right files; the in-tool replay redraws both characters recognizably with correct stroke order; undo works.

## Step 4 — Author starter dataset

1. User records strokes for the starter subset: A–Z uppercase, 0–9, first 10 Thai consonants (ก–ช).
2. Add a validation script (headless) checking every entry: ≥1 stroke, points in 0–1 range, no empty strokes.

**GATE 4**: validation script passes for all starter characters; spot-check replay of 5 random characters looks correct to the user. (Remaining ~100 characters are authored incrementally in Step 8 — not a blocker for Steps 5–7.)

## Step 5 — Tracing scene (demo + trace)

1. Build `tracing.tscn` state machine: **demo** → **trace** → **score** → next character.
2. Demo: `stroke_animator.gd` draws each stroke as a growing Line2D with a moving finger-dot marker and stroke numbers; "watch again" button.
3. Trace: current stroke shown as dotted guide with a start-point marker; child's ink drawn as thick rounded Line2D; stroke advances when finished; other strokes dimmed.

**GATE 5**: on the Surface Go, the animation plays smoothly (no visible stutter); user traces a full character by finger with responsive ink (no perceptible lag); stroke progression works; "watch again" replays.

> **Amended by Step 10** — the only existing step that changes. A `COUNT` state is inserted ahead of `DEMO`, entered only for the `digits` and `thai_numerals` sets. Every other set opens straight into `DEMO` exactly as it does now.

## Step 6 — Scoring & feedback

1. Implement `scorer.gd` per the scoring design; tune thresholds child-friendly.
2. Score screen: 1–3 stars, cheerful sound, particle celebration, big "again" / "next" buttons. No fail state.

**GATE 6**: a careful adult trace scores 3 stars; a deliberately sloppy-but-on-letter trace scores 1–2 stars; a random scribble scores 1 star with encouragement to retry; sounds and particles play.

## Step 7 — Menus, character select, progress

1. `main_menu.tscn`: big buttons for ก ไก่ / ABC / abc / 123+๑๒๓ / vowels.
2. `character_select.tscn`: grid of large character buttons showing earned stars.
3. `progress.gd`: persist best stars per character to `user://progress.json`.

**GATE 7**: full loop works by touch only (no keyboard/mouse): menu → pick character → trace → stars → back; earned stars survive an app restart.

## Step 8 — Complete the dataset

1. User records remaining characters with the Stroke Recorder: rest of Thai consonants, a–z lowercase, Thai numerals ๐–๙, Thai vowels/tone marks (with dotted consonant placeholder in both recorder and tracing scenes).
2. Run the Step 4 validation script over everything.

**GATE 8**: validation passes for all ~140 characters; every character-select grid is fully populated; user spot-checks a handful of Thai vowels render/trace sensibly.

## Step 9 — Packaging for Fedora + Windows 11

1. Export presets: Linux x86_64 binary and Windows Desktop .exe (embedded PCK, single file). Document one-line export commands in README.
2. User copies the .exe to the Windows partition and tests.

**GATE 9 (final)**: Linux export runs standalone (outside the editor) on Fedora with working touch; Windows .exe runs on Win11 on the same machine with working touch, correct Thai rendering, and stars persisting. Performance acceptable (smooth inking) on both.

## Step 10 — Counting objects for the number sets (new)

**Why**: tracing "3" teaches the shape, not the amount. Before writing a numeral the child counts that many things by tapping them, so the quantity and the symbol are learned together. Both number sets get it — `digits` (0–9) and `thai_numerals` (๐–๙) are the same ten quantities, and sharing the activity is what links ๓ to 3.

**Design decisions**

- **Tap-to-count, then trace.** Opening a numeral shows N objects in the drawing box. Each tap fills one in with a pop and a rising note; the caption counts up "1… 2… 3"; when the last one lands it reads the character's own name from the catalog ("three", "สาม") and the tracing demo starts on its own. Taps in any order — the child is counting a set, not following an order.
- **Objects are drawn, not imported** — `object_art.gd`, `_draw()` only, in the manner of `star_row.gd` (`draw_colored_polygon` + `draw_polyline`) and `confetti.gd`. Keeps THIRDPARTY.txt untouched and scales to any size. Half a dozen kinds (apple, balloon, fish, ball, flower, leaf), each a few polygons and circles.
- **One kind per value, fixed.** A value→kind table means 3 is *always* three apples and 7 is always seven fish, so the child recognises the set, while different digits still look different. The same table serves ๓, which is what makes the two numeral systems visibly the same quantity.
- **Zero is an empty basket**, drawn with nothing in it, captioned "nothing — zero!", and finished by a single tap anywhere. Zero is a quantity, and skipping it would teach that it is not.
- **Counting is not scored** and touches no progress data: stars stay a measure of handwriting. `progress.gd` and `scorer.gd` are not modified.
- **Counting plays once per opening.** The score card's "again" and the panel's "watch again" go to tracing and demo as they do today — a child on their fifth attempt at 8 should not have to re-count eight balloons each time.

**Work**

1. `scripts/char_sets.gd` — add the numeral→quantity mapping to the catalog, which is already the single source of truth for what a character *is*: a `numeric: bool` flag on the two number sets and `value_of(id, chr) -> int` (returns −1 for non-numeric sets). Extend `validate()` so a numeric set whose characters do not map to 0–9 is an error. No new set ids, no data-file changes — `data/strokes/` is untouched by this step.
2. `scripts/object_art.gd` — new, static and pure, no nodes: `KINDS` table, `kind_for_value(value) -> int`, `draw_object(canvas, kind, centre, radius, filled)`, `draw_basket(canvas, centre, radius)`, plus `layout(count, box) -> PackedVector2Array` computing centres on a `ceil(sqrt(n))`-column grid with the last row centred, sized so every target is a comfortable finger tap in the 960 px box. `layout()` being pure geometry is what lets the tests check spacing headless.
3. `scripts/count_objects.gd` — new `Control`, modelled on `star_row.gd`: holds `_count`, `_tapped`, and a pop clock; `_draw()` renders untapped objects as faint outlines and tapped ones filled; `_gui_input()` handles `InputEventScreenTouch` and maps a press to the nearest centre within its radius; emits `counted(n)` per new object and `finished` once all N are in (or on the first tap when N is 0). One node, nothing allocated mid-animation.
4. `scripts/tone_bank.gd` — add `count_tone(index) -> AudioStreamWAV`, one rising bell per object using the existing `_bell()`; a nine-note scale so the pitch climbs with the count.
5. `scenes/tracing.tscn` — add `CountOverlay` (Control over the DrawBox rect, holding the `CountObjects` node and a `Caption` Label) and a `Sounds/Count` player. Hidden for every non-numeric set.
6. `scripts/tracing.gd` — add `State.COUNT`; `_open_char()` enters it instead of `_enter_demo()` when `CS.value_of()` is ≥ 0; `_enter_count()` sizes the overlay to `_box()`, hides the guide glyph and demo, and wires `counted`/`finished`; `finished` → `_enter_demo()`. `_on_touch()` already ignores everything outside `State.TRACE`, so tracing input needs no change; `_refresh_labels()` gains a `COUNT` case ("count them"), and `_hush()` stops the count player.
7. `tests/test_count_objects.gd` — new headless test: `value_of()` across both number sets and −1 elsewhere; `layout()` returns N centres, all inside the box and none overlapping; a simulated tap sequence emits `counted` 1…N in order and `finished` exactly once; out-of-range taps are ignored; N = 0 finishes on the first tap; `count_tone()` returns a non-empty stream. Register it wherever the existing suite is listed.
8. `README.md` — a "Counting objects (Step 10)" section beside the existing per-step sections, and Step 9's export commands re-run to refresh both builds.

**GATE 10**: headless — `tests/test_count_objects.gd` passes and the whole existing suite plus the dataset validator still pass untouched. On the Surface Go by finger: opening "3" shows three tappable objects; each tap pops one with a rising note and the count updates; after the third, the name shows and the tracing demo starts by itself; "๓" shows the same three objects with "สาม"; "0" shows an empty basket and one tap moves on; a Thai consonant and an English letter open straight into the demo with no counting overlay and no visual change from today; the score card's "again" returns to tracing without re-counting. Finally, both exports rebuilt and the Windows .exe re-checked on Win11 (GATE 9 re-run).

## Out of scope (future)

- Voice clips for character names (ก ไก่ spoken aloud), and counting aloud.
- Counting above 9, arithmetic, or quantity practice detached from writing.
- Word/spelling practice; vowels attached to real consonants.
- Android/tablet export.
