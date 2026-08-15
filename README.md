# Writing Practice

A finger-tracing handwriting app for learning Thai and English characters
(Godot 4 + GDScript), built for a touch-screen Surface Go running Fedora 44
and Windows 11.

## Tech stack / installation notes (Step 0)

- **Godot 4.7.1-stable** (official standalone binary from godotengine.org,
  installed to `~/.local/bin/godot`). Chosen over dnf/Flatpak to always track
  the current upstream release.
- **Export templates 4.7.1-stable** installed to
  `~/.local/share/godot/export_templates/4.7.1.stable/` (needed for the
  Linux and Windows exports in Step 9).
- **Fonts** (all OFL-licensed, licenses kept alongside the .ttf files):
  - `assets/fonts/sarabun/` — Sarabun Regular/Bold. Thai guide font; it is a
    **looped (มีหัว)** font, which is required for teaching Thai school
    handwriting. Never substitute a loopless font.
  - `assets/fonts/andika/` — Andika Regular/Bold (SIL literacy font) for
    English letters and digits.
- Touch screen: ELAN9038 digitizer, works out of the box on Fedora
  44 / Wayland (multitouch + stylus event nodes present).

## Running

```sh
godot --path /home/littlefrog/projects/writing_practice
```

Launches fullscreen (1920×1280 base resolution, `canvas_items` stretch,
Compatibility renderer). Press **Esc** to quit.

`scenes/main.tscn` is the main scene: a boot router that picks what to start
from the command line (everything after the bare `--` is a user arg).

| Command | Starts |
| --- | --- |
| `godot --path .` | the Step 1 font/touch smoke test (later: the main menu) |
| `godot --path . -- --recorder` | the **Stroke Recorder** authoring tool |
| `godot --path . -- --recorder --mouse` | …with the mouse drawing as a finger |

The font/touch smoke test shows Thai (Sarabun, looped), English (Andika), and
Thai numerals in large type, and prints every
`InputEventScreenTouch`/`InputEventScreenDrag` to the console while mirroring
the last event on screen.

Touch settings: `emulate_mouse_from_touch = true` (UI buttons respond to
touch); `emulate_touch_from_mouse` stays **off** in the project settings —
`--mouse` turns it on at runtime for desktop work, so real touch handling is
never masked in the app the child uses.

## Stroke Recorder (dev tool, Step 3)

```sh
godot --path . -- --recorder
```

Traces the dataset into `data/strokes/<set>.json`. Trace the faint reference
glyph inside the white box with a finger — one stroke per touch, in the order
a child should write them (Thai starts at the loop, หัว). Finished strokes are
numbered from their start point.

- **◀ set / set ▶**, **◀ char / char ▶** — move through the catalog; a
  character that is already recorded loads its strokes for editing.
- **undo** / **clear** — drop the last stroke / empty the canvas. Neither
  touches the file until you press SAVE.
- **replay** — redraw the strokes one by one, in order.
- **reload** — throw away edits and re-read the character from the file.
- **SAVE** — write the character into its set file, replacing any earlier
  version of that character and leaving the rest of the file alone.
- Keyboard equivalents for desktop work: `Z` undo, `C` clear, `S` save,
  `R` replay, ←/→ character, ↑/↓ set, `Esc` quit.

Navigating away from unsaved strokes needs the button pressed twice — the
first press only warns.

Recording a set in one pass is easiest: draw, **SAVE**, **char ▶**, repeat —
the side panel shows `n / 44 recorded` so progress is visible. Stroke *order
and direction* are the point of the data, not just the shape: Thai starts at
the loop (หัว); English follows school handwriting order (A is two diagonals
then the crossbar, top-down and left-to-right). Run the dataset check below
after each batch.

The character catalog (which characters exist, their order, their names) lives
in `scripts/char_sets.gd`; the guide glyph's size and position inside the box
live in `scripts/glyph_guide.gd` and **must** be reused by the tracing scene,
or recorded strokes will not sit on the glyph.

## Tests

Headless suites (no display needed):

```sh
godot --headless --path . --script tests/test_stroke_data.gd
godot --headless --path . --script tests/test_char_sets.gd
```

`test_stroke_data.gd` exercises `scripts/stroke_data.gd` (stroke JSON
load/save/validation, arc-length resampling, 0–1 box normalization, entry
merging, partial strokes). `test_char_sets.gd` checks the character catalog,
that every stroke file agrees with it, and that the dataset validator really
rejects bad entries.

The recorder suite drives the real scene with synthetic touch events, so it
needs a display and opens a small window for a few seconds:

```sh
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd
```

It records into a scratch directory under `user://` (by pointing
`CharSets.stroke_dir` there), so it never writes to — and never depends on
what has been recorded in — `data/strokes/`.

All exit non-zero on failure.

## Dataset check (Step 4)

```sh
godot --headless --path . --script tests/validate_dataset.gd
```

Checks the recorded data rather than the code — run it after every recording
batch, and again in Step 8 to confirm the dataset is finished. It walks every
`data/strokes/*.json`, reports **all** problems at once, and prints a per-set
coverage table:

- the file name, the entry's `"set"` field and the catalog must agree;
- `"char"` must be in that set, with the catalog's `"name"`;
- at least one stroke, at least 2 points each, no duplicate characters;
- every point inside the 0–1 box (the recorder clamps, so a failure here means
  hand-edited or stale data).

A stroke shorter than 2% of the box is reported as a **warning** and still
passes: the dot on an "i" is legitimate, a whole character made of dots is not
— that call is left to the reader.

To see what is left to record in a set:

```sh
godot --headless --path . --script tests/validate_dataset.gd -- --missing thai_consonants
```

The rules live in `scripts/dataset_validator.gd` so `test_char_sets.gd` can
share them instead of keeping a second copy.

## Stroke data format

One JSON file per character set in `data/strokes/` — an array of entries:

```json
{ "char": "ก", "set": "thai_consonant", "name": "ก ไก่",
  "strokes": [ [[x, y], [x, y]], ... ] }
```

Points are normalized to a 0–1 box relative to the on-screen drawing square
(glyph size/position inside the box is meaningful — tone marks sit high).
Thai strokes start at the loop (หัว). Data is authored with the in-app Stroke
Recorder (Step 3), not by hand.

Set ids — and so the file names — come from `scripts/char_sets.gd`:
`thai_consonants`, `english_upper`, `english_lower`, `digits`,
`thai_numerals`, `thai_vowels` (empty until Step 8).
