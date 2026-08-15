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
| `godot --path . -- --tracing` | the **tracing scene** — demo, then trace |
| `godot --path . -- --recorder` | the **Stroke Recorder** authoring tool |
| `godot --path . -- --tracing --mouse` | …with the mouse drawing as a finger (works with `--recorder` too) |

The font/touch smoke test shows Thai (Sarabun, looped), English (Andika), and
Thai numerals in large type, and prints every
`InputEventScreenTouch`/`InputEventScreenDrag` to the console while mirroring
the last event on screen.

Touch settings: `emulate_mouse_from_touch = true` (UI buttons respond to
touch); `emulate_touch_from_mouse` stays **off** in the project settings —
`--mouse` turns it on at runtime for desktop work, so real touch handling is
never masked in the app the child uses.

## Tracing scene (Step 5)

```sh
godot --path . -- --tracing
```

The first screen the child actually uses. One character at a time, in three
states:

1. **demo** — the character draws itself stroke by stroke, an orange finger-dot
   leading each line and the stroke's order number appearing with it;
2. **trace** — the stroke to draw now is a line of dots with an orange start
   marker and a direction arrow, strokes still to come are dimmed, and finished
   ones are the child's own ink. Lifting the finger ends a stroke and moves on;
3. **score** — 1–3 stars, popping in one at a time with a note each, confetti,
   a cheerful line and big **↺ again** / **next ▶** buttons (Step 6, below).

**▶ watch again** replays the demo and comes back to the same stroke, keeping
what has been traced; **↺ start over** wipes the ink and starts the character
again. **◀ char / char ▶** and **◀ set / set ▶** move through the catalog —
they exist because the menus that will lead here are Step 7. Keyboard
equivalents for desktop work: `R` watch again, `Space` start over, ←/→
character, ↑/↓ set, `Esc` quit.

There is no fail state: a finished stroke always advances, however wobbly. The
one thing that does not advance is a touch shorter than 24 px — a stray tap or
a resting palm rather than an attempt — and even that check is skipped when the
guide stroke is itself a dot (the dot on an "i"). The child's strokes are kept
normalized in `_traced`, which is what the scorer reads.

The reference glyph goes through `scripts/glyph_guide.gd` into a **square** box,
exactly as the recorder does — stroke points are normalized against the box, so
a box of another shape would slide every recorded stroke off the glyph.

`scripts/stroke_animator.gd` is the demo animation as a reusable node
(`set_strokes()`, `play()`, `stop()`, a `finished` signal). It allocates nodes
only in `set_strokes()`; while playing it does nothing per frame but reassign
`Line2D.points`, because freeing and recreating nodes at 60 fps is what visible
stutter on the Surface Go's iGPU looks like. `scripts/dotted_guide.gd` draws the
dotted line — `Line2D` has no dash mode, so the stroke is resampled to a fixed
spacing and a dot is drawn at each sample, redrawn only when the stroke changes.

## Scoring & feedback (Step 6)

When the last stroke is finished, `scripts/scorer.gd` compares what the child
drew with the recorded guide — both are normalized to the same 0–1 box, so the
scoring works in fractions of the drawing square and never sees a screen size.
Per stroke:

- **coverage** — how much of the guide the child's line passed within ~5% of
  the box (≈48 px). This is what notices a stroke that stopped half way.
- **deviation** — the mean distance from the child's line to the guide. This is
  what separates neat from wobbly; a mean of ~1.8% of the box or less is
  perfect, ~6.5% or more scores nothing.
- **direction** — the stroke sampled against the guide, and against the guide
  reversed; the better fit is the way it was drawn. Comparing endpoints alone
  would call a circle drawn backwards correct. Stroke *order* cannot be wrong:
  the trace state asks for one stroke at a time.
- **sprawl** — how long the stroke ran compared with the guide, as a multiplier
  over the rest. Coverage and deviation between them are still fooled by a
  scribble drawn along the letter; nothing about a scribble is short.

Those become 1–3 stars. Thresholds are deliberately child-sized and live at the
top of `scorer.gd` — a careful trace earns three, a sloppy but on-letter one
earns two, a scribble earns one. **One star is the floor**: there is no
zero-star result, no "wrong", and the card never blocks the way on. The message
under the stars for one star is an invitation to watch and try again.

The card itself is `ScoreOverlay` in `scenes/tracing.tscn`, placed over the
side panel rather than the drawing box so the writing being praised stays on
screen. `scripts/star_row.gd` draws the stars as polygons (neither font is
guaranteed to carry "★") and pops them in one at a time; each landing star
rings its own note and the last one brings a flourish.

The sounds are **synthesized in `scripts/tone_bank.gd`**, not shipped as audio
files: a few harmonic partials with an exponential decay, rendered to
`AudioStreamWAV` when the scene loads (~0.6 s, before anything is on screen).
That was a licensing decision as much as a technical one — every other asset
here came with its licence file beside it, and a downloaded sound effect is the
easiest way to end up with an asset nobody can account for later. There is no
`assets/audio/` directory and nothing to attribute.

`scripts/confetti.gd` is one `CPUParticles2D` — configured in the scene,
`restart()`ed per celebration, never a node created per character — that builds
its own particle texture in code for the same reason.

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
godot --headless --path . --script tests/test_scorer.gd
```

`test_stroke_data.gd` exercises `scripts/stroke_data.gd` (stroke JSON
load/save/validation, arc-length resampling, 0–1 box normalization, entry
merging, partial strokes). `test_char_sets.gd` checks the character catalog,
that every stroke file agrees with it, and that the dataset validator really
rejects bad entries. `test_scorer.gd` scores synthetic traces — exact, wobbly,
sloppy, backwards, half-drawn, scribbled — against a synthetic guide, and
checks the generated sounds; both `scorer.gd` and `tone_bank.gd` are static and
pure, which is what lets it run with no display.

The recorder and tracing suites drive the real scenes with synthetic touch
events, so they need a display and open a small window for a few seconds:

```sh
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd
```

`test_tracing.gd` covers the demo advancing stroke by stroke and ending on its
own, "watch again" replaying without losing traced strokes, a stroke advancing
the state machine, ink landing inside the box, stray taps and out-of-box
touches being ignored, the score card (three stars for a trace on the guide,
one for a scribble, the stars popping in order, the confetti, the `scored`
signal), the "again" and "next" buttons, and a character with no strokes yet.
It turns vsync off for the run: a test window the compositor considers hidden
is throttled to a crawl, and with the frames unthrottled the suite takes about
five seconds instead of minutes. Anything the scene does on a clock is waited
for in seconds, never in frames.

Both point `CharSets.stroke_dir` at a scratch directory under `user://`, so
they never write to — and never depend on what has been recorded in —
`data/strokes/`. The tracing suite writes its own two-character file there and
checks the real dataset's SHA-256s afterwards. **Any new test that drives a
scene which reads or writes stroke files must do the same**, or it will start
failing the day that character is re-recorded.

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
