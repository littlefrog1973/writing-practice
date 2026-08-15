# Thai/English Handwriting Practice App (Godot 4) — Gated Implementation Plan

## Context

A finger-tracing app for a child to learn to write Thai and English alphanumeric characters, running fullscreen on a touch-screen Surface Go dual-booting Fedora 44 and Windows 11. Stack chosen by user: **Godot 4.x + GDScript** (user knows Python). First version: letter tracing over guides, stroke-order animation, accuracy feedback with celebration. Character sets: 44 Thai consonants (ก–ฮ), English A–Z upper+lower, digits 0–9 + Thai numerals ๐–๙, Thai vowels/tone marks (~140 characters total).

Project directory `/home/littlefrog/projects/writing_practice/` is empty (greenfield).

**How to use this plan**: execute one step at a time, in order. Each step ends with a **GATE** — a concrete check that must pass (with the user confirming touch-related gates on the real hardware) before starting the next step. If a gate fails, fix within the step; do not proceed.

## Key design decisions (apply throughout)

- Godot 4.x (latest stable, ≥4.3), GDScript, **Compatibility renderer** (Surface Go weak iGPU).
- **Thai guide font must be looped (มีหัว)**: Sarabun or Noto Sans Thai Looped — Thai school handwriting teaches looped forms; loopless fonts are wrong for teaching. English/digits: Andika (SIL literacy font). All OFL-licensed.
- **Stroke data format**: one JSON per character set in `data/strokes/`, entries `{ "char": "ก", "set": "thai_consonant", "name": "ก ไก่", "strokes": [[[x,y],...], ...] }`, points normalized to a 0–1 box. Thai strokes start at the loop (หัว) per convention.
- **Stroke authoring** via an in-app dev-only **Stroke Recorder**: reference glyph shown large at low opacity, adult traces each stroke in order on the touch screen, tool saves JSON. This is how ~140 characters get authored without hand-writing SVG paths.
- **Touch input**: handle `InputEventScreenTouch`/`InputEventScreenDrag`; project settings: `input_devices/pointing/emulate_mouse_from_touch = true` (UI buttons work), `emulate_touch_from_mouse = true` only behind a debug flag for desktop testing.
- **Scoring**: per stroke — coverage (fraction of guide points within tolerance of trace), deviation (mean trace→guide polyline distance), direction/order correctness → 1–3 stars. Generous, child-friendly tolerances; retry is encouraged, never a "fail" state.
- **Thai vowels/tone marks**: traced standalone at large size with a dotted placeholder circle where the consonant would sit.

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
    └── progress.gd       # per-character stars → user://progress.json
```

---

## Step 0 — Tech stack installation (Fedora 44)

1. Install Godot 4.x on Fedora. Preferred: official standalone binary from godotengine.org (always current) unpacked to `~/.local/bin/godot`; alternatives: `sudo dnf install godot` or Flatpak `org.godotengine.Godot`. Pick whichever gives ≥4.3; note the choice in README.
2. Install matching **export templates** (needed later for Linux + Windows builds): via editor UI (Editor → Manage Export Templates) or `godot --headless` download.
3. Download fonts: Sarabun (Google Fonts) or Noto Sans Thai Looped, and Andika (SIL) — keep the OFL license files alongside.
4. Confirm the touch screen works under Fedora/Wayland at OS level (`libinput debug-events` shows touch, or simply touch-scroll in a browser).

**GATE 0**: `godot --version` prints 4.x; the editor opens and creates a throwaway project; export templates for the installed version are present; font files exist on disk; user confirms OS-level touch input works on Fedora.

## Step 1 — Project scaffold

1. Create the Godot project in `/home/littlefrog/projects/writing_practice/`: fullscreen window, base resolution 1920×1280 (Surface Go native), `canvas_items` stretch mode, Compatibility renderer, touch settings as per design decisions.
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

## Out of scope (future)

- Voice clips for character names (ก ไก่ spoken aloud).
- Word/spelling practice; vowels attached to real consonants.
- Android/tablet export.
