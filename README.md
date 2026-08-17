# Writing Practice

A finger-tracing handwriting app for learning Thai and English characters
(Godot 4 + GDScript), built for a touch-screen Surface Go running Fedora 44
and Windows 11.

**Finished 2026-08-16.** All nine steps of `docs/PLAN.md` are built and all
nine gates confirmed by hand on the device, Fedora and Windows 11 both. The
dataset is complete at 137 characters, every one recorded by hand on the touch
screen. See "Building the app" below for the two export commands, and
`docs/PLAN.md` for what was deliberately left out.

## Licences

The code in this repository is MIT — see `LICENSE`.

The fonts are **not** MIT and are not covered by it. Both are redistributed
here under the SIL Open Font License 1.1, with their licence text beside them
and inside every exported build:

| | |
| --- | --- |
| `assets/fonts/sarabun/` | Copyright 2018 The Sarabun Project Authors — OFL 1.1 |
| `assets/fonts/andika/` | Copyright 2004–2022 SIL International — OFL 1.1, Reserved Font Names "Andika" and "SIL" |

They are shipped byte-for-byte as published. If you ever modify one, OFL
requires you to rename it — a Reserved Font Name cannot be carried by a
modified version.

An exported build also embeds the Godot engine (MIT) and its third-party
components — 102 of them. `THIRDPARTY.txt` is their collected notice, generated
from `Engine.get_license_text()` and `Engine.get_copyright_info()`. It and
`LICENSE` are packed **inside both builds** along with the two `OFL.txt`, so a
binary copied off on a USB stick still carries every notice it owes. Regenerate
it if the engine version changes.

The recorded stroke data in `data/strokes/` is original work, authored by hand
on a touch screen, and is MIT along with the code.

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
godot --path /path/to/writing_practice
```

Launches fullscreen (1920×1280 base resolution, `canvas_items` stretch,
Compatibility renderer) on the main menu. Press **Esc** to step back a screen,
and again to quit.

`scenes/main.tscn` is the main scene: a boot router that picks what to start
from the command line (everything after the bare `--` is a user arg).

| Command | Starts |
| --- | --- |
| `godot --path .` | the **main menu** — the app proper |
| `godot --path . -- --tracing` | straight into the **tracing scene** on the first character |
| `godot --path . -- --recorder` | the **Stroke Recorder** authoring tool |
| `godot --path . -- --fonts` | the Step 1 font/touch smoke test |
| `godot --path . -- --tracing --mouse` | …with the mouse drawing as a finger (works with `--recorder` too) |

Every route goes through `scripts/screens.gd`, so a scene started from the
command line is wired up exactly as the menu would have wired it: `--tracing`
records stars and its "back" button reaches the character grid.

The font/touch smoke test shows Thai (Sarabun, looped), English (Andika), and
Thai numerals in large type, and prints every
`InputEventScreenTouch`/`InputEventScreenDrag` to the console while mirroring
the last event on screen.

Touch settings: `emulate_mouse_from_touch = true` (UI buttons respond to
touch); `emulate_touch_from_mouse` stays **off** in the project settings —
`--mouse` turns it on at runtime for desktop work, so real touch handling is
never masked in the app the child uses.

## Building the app (Step 9)

Two presets in `export_presets.cfg`, both a single self-contained file with the
PCK embedded — nothing to install on either machine:

```sh
mkdir -p build/linux build/windows
godot --headless --path . --export-release "Linux"           build/linux/writing_practice.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/writing_practice.exe
ls -la build/linux build/windows          # the only honest check — see below
```

**The `mkdir` is not optional and `godot` will not tell you so.** Godot does
not create the output directory, and on a fresh checkout (`build/` is
gitignored, so every checkout is fresh) the export fails with
`Prepare Template: The given export path doesn't exist` — while **still
exiting 0**. A build script that trusts the exit code will happily ship
whatever was in `build/` before, or nothing at all. Look at the files.

Needs the **export templates** for the exact Godot version installed — see the
Step 0 notes at the top; without them the export fails the same quiet way.

`build/` is gitignored; `export_presets.cfg` is committed, because it is what
defines the build. Copy the `.exe` to the Windows partition and run it there —
it is the same machine, so touch, fonts and stars all behave as on Fedora.

To move the Linux build to **another Fedora machine**, copy the one file and
`chmod +x` it. It links against nothing but glibc 2.28 or newer (librt,
libpthread, libdl, libm, libc); OpenGL, X11/Wayland and audio are opened at
runtime. To bring the child's stars along, copy `progress.json` from the
directory in the table below as well — it is the only file the app writes.

Two things the presets have to say out loud:

- **`include_filter="data/strokes/*.json,assets/fonts/*/OFL.txt"`.** Godot does
  not import `.json` as a resource, so `export_filter="all_resources"` leaves
  the entire recorded dataset out of the build and the app ships with nothing
  to trace. The font licences are plain text for the same reason and must
  travel with the fonts they cover. Ask the build itself after any preset
  change, rather than trusting the export log:

  ```sh
  build/linux/writing_practice.x86_64 --quit-after 120 -- --recorder
  # [recorder] Set: Thai consonants (44 characters, 44 recorded).
  ```

  `--quit-after` matters as much as the route does: an exported build's stdout
  is block-buffered when redirected, so a build stopped with `timeout` or
  Ctrl-C dies without flushing a line of it and looks silent. Let it quit on
  its own, or read the log file below.
- **`exclude_filter="docs/*,tests/*"`.** The test suites are `.gd` files and
  would otherwise be packed into the app a child runs.

When something goes wrong in an exported build there is no console to watch.
The app writes one instead, on a clean exit:

| | |
| --- | --- |
| Fedora | `~/.local/share/godot/app_userdata/Writing Practice/logs/` |
| Windows | `%APPDATA%\Godot\app_userdata\Writing Practice\logs\` |

`user://progress.json` — the child's stars — lives in the same directory, one
per operating system. Booting Windows does not lose the Fedora stars; it starts
a second, separate collection of them.

## Tracing scene (Step 5)

```sh
godot --path . -- --tracing
```

The first screen the child actually uses. One character at a time. A numeral
starts in a state of its own — **count** (Step 10, below), where the child taps
out that many objects before writing the numeral — and every other character
starts at the demo:

1. **demo** — the character draws itself stroke by stroke, an orange finger-dot
   leading each line and the stroke's order number appearing with it;
2. **trace** — the stroke to draw now is a line of dots with an orange start
   marker and a direction arrow, strokes still to come are dimmed, and finished
   ones are the child's own ink. Lifting the finger ends a stroke and moves on;
3. **score** — 1–3 stars, popping in one at a time with a note each, confetti,
   a cheerful line and big **◀ back** / **↺ again** / **next ▶** buttons
   (Step 6, below).

**▶ watch again** replays the demo and comes back to the same stroke, keeping
what has been traced; **↺ start over** wipes the ink and starts the character
again; **◀ back** returns to the character grid. **◀ char / char ▶** move to
the neighbouring character in the set — they stayed after Step 7 because
finishing "ก" and wanting "ข" should not mean a trip back to the grid, while
changing *set* is a decision the menu now owns. Keyboard equivalents for
desktop work: `R` watch again, `Space` start over, ←/→ character, ↑/↓ set,
`Esc` back.

There is no fail state: a finished stroke always advances, however wobbly. The
one thing that does not advance is a touch shorter than 24 px — a stray tap or
a resting palm rather than an attempt. That floor is never more than **40% of
the stroke being asked for**, though, and is skipped entirely when the guide
stroke is itself a dot (the dot on an "i"): Step 8's tone marks are short
enough that a flat 24 px would reject better than half of a real attempt, and
being ignored is the one response the app must never give. The child's strokes
are kept normalized in `_traced`, which is what the scorer reads.

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
screen — which is why it carries its own **◀ back**: it covers the panel's one,
and "again" and "next" must not be the only ways out of a celebration. `scripts/star_row.gd` draws the stars as polygons (neither font is
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

## Menus and progress (Step 7)

```sh
godot --path .
```

Three screens, one direction with a way back at every step:

```
main menu  ──set──▶  character select  ──character──▶  tracing
     ◀──── back ────         ◀──── back ────
```

- **`scenes/main_menu.tscn`** — one big button per set, each showing the set's
  own first character in the set's own font, its name, and how far the child
  has got. The buttons are built from `char_sets.gd`, not laid out in the
  scene, so a set added to the catalog appears here with nothing to edit. A set
  with no characters at all in the catalog would be greyed and say "coming
  soon" rather than be hidden; since Step 8 there is no longer such a set.
- **`scenes/character_select.tscn`** — the grid of characters in one set, each
  with its earned stars underneath and unearned ones as faint outlines, exactly
  as on the score card. The number of columns comes from the size of the set
  (√(n · 2.2), clamped to 4–8), and cells are never taller than they are wide,
  so ten digits are five big buttons by two rather than two half-metre rows.
  A character with **no recorded strokes** is greyed, marked "soon" and cannot
  be opened — visible so the grid shows what is left to record, disabled so a
  child never walks into a screen with nothing to trace.
- **`assets/theme/app_theme.tres`** — the one Theme all three child-facing
  scenes use: the Thai guide font as the default font, and buttons as white
  rounded cards rather than Godot's default grey slabs. It is a file rather
  than a sub-resource of each scene because it was three copies before,
  drifting apart by a corner radius at a time. The Stroke Recorder is
  deliberately left unthemed — it is an authoring tool for an adult, and
  looking different from the app is a feature there.
- **`scripts/screens.gd`** — which screen is on the display, and the wiring
  between them, in one place. Scenes are swapped by hand rather than with
  `change_scene_to_file` because a screen needs its subject *before* it enters
  the tree (which set, which character); the swap is deferred, so calling it
  from a button's own `pressed` signal is safe. It is also what listens to the
  tracing scene's `scored` signal — that scene stays stateless, and the same
  wiring applies however it was launched.

Progress lives in **`scripts/progress.gd`** and is written to
`user://progress.json`:

```json
{ "version": 1, "sets": { "thai_consonants": { "ก": 3, "ข": 2 } } }
```

- **Best stars are kept, never the latest.** A child who writes ก beautifully
  on Tuesday and hurriedly on Wednesday has not got worse at ก, and a star that
  can be taken away is not worth earning. `record()` only ever raises a score.
- `user://` because it is the only writable place in an export — `res://` is
  read-only there, so the obvious spot beside the stroke data would work in the
  editor and fail on the Surface Go.
- **Nothing in it may stop the app.** A missing file is a child who has not
  played yet; a corrupt one is a half-finished write, and the answer to both is
  an empty progress dictionary and a line in the console. A file somebody has
  hand-edited is salvaged row by row — a bad entry is dropped, an impossible
  star count is clamped — because one bad row must not cost the rest.
- Where the star boundaries are is `scorer.gd`'s business, not this file's:
  `mastered_stars()` asks it what a flawless trace earns rather than writing 3
  down a second time.

## Thai vowels & tone marks (Step 8)

The last set in the catalog, and the only one whose characters cannot stand on
their own. Twenty-one of them, in the order they are taught: the fifteen สระ in
recital order (ะ ั า ำ ิ ี ึ ื ุ ู เ แ โ ใ ไ), the four tone marks
(ไม้เอก ไม้โท ไม้ตรี ไม้จัตวา), then ไม้ไต่คู้ and การันต์.

A mark is shown on the **dotted placeholder ◌** that Thai teaching materials
use — and on the side of it the mark is really written. Text is stored in the
order it is written, so the five leading vowels (เ แ โ ใ ไ) come *before* the
placeholder and everything else after it: `เ◌`, but `◌ิ`. Putting them all on
one side would teach half the set back to front, so which side each takes is a
property of the character, in `CharSets.display_form()`, and the recorder, the
character grid and the tracing scene all ask it rather than each building the
string themselves.

A placeholder cluster is also **drawn smaller** than a letter
(`GlyphGuide.COMBINING_SIZE_RATIO`, 0.60 against 0.76): it is two characters
stacked, and at the letter size the tallest marks put ink above the top of the
drawing box — where the recorder clamps every touch, so the guide would be
asking for a stroke that cannot be drawn. The ratio follows from the text
itself, not from an argument each scene passes, because a glyph resized under
strokes already recorded against it is silent damage; no recorded character
contains the placeholder, so nothing outside this set can move.

Vowels sit high or low against the placeholder rather than filling the box, and
several are a single small stroke: the third stroke of ◌ื is 41 px in a 960 px
box, where the shortest real stroke in the other five sets is Q's tail at
184 px. That is what the stray-tap floor above is proportional for. None of
them is short enough to be warned about by the dataset check.

With them recorded the dataset is **complete: 137 of 137 characters**.

## Counting objects (Step 10)

Tracing "3" teaches the shape, not the amount. Before a **numeral** is written,
that many things appear in the drawing box and the child taps them one at a
time; each tap fills one in with a pop and a note a step higher than the last,
the caption counts up, and when the last one lands it reads the character's own
name from the catalog — "3 — three", "๓ — สาม" — and the tracing demo starts on
its own.

Both number sets get it. `digits` (0–9) and `thai_numerals` (๐–๙) are the same
ten quantities written twice, and **the objects are the same for both**: ๓ and 3
are three apples, seven is always seven fish. That sameness is the point — it is
what ties the two numeral systems together for a child learning them at once.

- **Which characters count** is the catalog's business, not the scene's: a set
  is marked `numeric` and `CharSets.value_of(set_id, chr)` gives the quantity,
  or −1 for everything else. `validate()` rejects a numeric set that is not the
  ten quantities 0–9, each exactly once, and the value comes from the
  character's own code point (๓ is three because it is U+0E53) rather than from
  where it sits in a list. Every other set opens straight into the demo, exactly
  as it did before, and `data/strokes/` is untouched by any of this.
- **Zero is an empty box** — nothing is drawn at all — finished by a single tap
  anywhere and captioned "nothing — zero!". Zero is a quantity; skipping it
  would teach that it is not, and so would a basket: a basket is a thing, and a
  child asked "how many?" in front of a thing answers one. Nothing is the only
  honest picture of none.
- **An object waiting to be counted is pale, not hollow.** It is drawn in a wash
  of its own colour (`PALE_FILL_MIX`), with its outline washed out less so the
  shape still holds; the tap brings the full colour and the details — the
  stalk, the eye, the seams — together. A hollow outline on white was the first
  version and read as a diagram of an apple rather than an apple.
- **Taps in any order.** The child is counting a set, not following a route, and
  "wrong one" for touching the second apple first teaches obedience, not number.
- **Counting is never scored** and writes nothing: stars stay a measure of
  handwriting, and neither `progress.gd` nor `scorer.gd` was touched.
- **Counting plays once per opening.** The score card's "again" and the panel's
  "watch again" go to tracing and to the demo as they always did — a child on
  their fifth go at 8 must not have to re-count eight balloons each time.

The objects are **drawn in code** (`scripts/object_art.gd`), like the stars and
the confetti and for the same reason: there is no `assets/images/` any more than
there is an `assets/audio/`, so there is nothing to licence and nothing to
account for later. Half a dozen kinds — apple, balloon, fish, ball, flower, leaf
— each a handful of polygons, laid out on a `ceil(√n)`-column grid with the last
row centred. Three things there were found by screenshotting it rather than by
reading it: an object built from overlapping circles needs **one** silhouette
drawn behind it (outlining each part turns an apple into a pumpkin), a lone
object gets a **capped** radius, or one balloon fills the whole box and hangs its
string over the caption below, and an uncounted object wants a pale wash of its
own colour rather than a hollow outline — a picture of the thing, not a diagram
of it.

`scripts/count_objects.gd` is the node — one `Control`, everything in `_draw()`,
nothing allocated while it animates, the rule the demo animator set. Touch is
read in `_input()` gated on its own rect, as the recorder and the tracing scene
do, and the decision itself is `tap_at()` in control-local coordinates, which is
what lets the headless suite count without a screen. The notes are
`ToneBank.count_tone()`, nine bells up a C major scale, synthesized with the
score sounds when the scene loads.

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
godot --headless --path . --script tests/test_progress.gd
godot --headless --path . --script tests/test_count_objects.gd
```

`test_stroke_data.gd` exercises `scripts/stroke_data.gd` (stroke JSON
load/save/validation, arc-length resampling, 0–1 box normalization, entry
merging, partial strokes). `test_char_sets.gd` checks the character catalog,
that every stroke file agrees with it, and that the dataset validator really
rejects bad entries. `test_scorer.gd` scores synthetic traces — exact, wobbly,
sloppy, backwards, half-drawn, scribbled — against a synthetic guide, and
checks the generated sounds; both `scorer.gd` and `tone_bank.gd` are static and
pure, which is what lets it run with no display. `test_progress.gd` covers the
stars a child keeps: best-of-not-latest, a missing file, a truncated one, JSON
of the wrong shape, a hand-edited one, merging two histories, and the whole
load-record-save round trip the tracing scene makes. `test_count_objects.gd`
covers the counting: what each numeral is worth in both sets and that nothing
else is worth anything, the object layout (n places, all inside the box, none
overlapping), a tap sequence counting 1…n in order and finishing once, taps that
miss or repeat counting nothing, zero drawing nothing and finishing on a single
tap, the pale wash being paler than the counted colour but still that colour,
and the nine notes. It drives the node through `tap_at()`, so it needs no display; whether a
finger actually reaches an object is checked by touch in `test_menus.gd`.

The recorder, tracing and menu suites drive the real scenes with synthetic
touch events, so they need a display and open a small window for a few seconds:

```sh
godot --path . -w --resolution 960x640 --script tests/test_recorder.gd
godot --path . -w --resolution 960x640 --script tests/test_tracing.gd
godot --path . -w --resolution 960x640 --script tests/test_menus.gd
```

`test_tracing.gd` covers the demo advancing stroke by stroke and ending on its
own, "watch again" replaying without losing traced strokes, a stroke advancing
the state machine, ink landing inside the box, stray taps and out-of-box
touches being ignored, the score card (three stars for a trace on the guide,
one for a scribble, the stars popping in order, the confetti, the `scored`
signal), the "again" and "next" buttons, a character with no strokes yet, and a
stroke short enough (a tone mark) that the stray-tap floor has to give way.
It turns vsync off for the run: a test window the compositor considers hidden
is throttled to a crawl, and with the frames unthrottled the suite takes about
five seconds instead of minutes. Anything the scene does on a clock is waited
for in seconds, never in frames.

`test_menus.gd` walks the whole of GATE 7 — main menu → character grid →
tracing → score → back → back — and **presses every button with a synthetic
finger**, never by emitting `pressed` and never with a key: a button that is
off-screen, covered or too small fails these checks the way it would fail a
five-year-old. (It is what caught the score card covering the side panel's
"back".) It also checks that the stars are on disk by reading the file back,
which is exactly what the next launch does. Since Step 10 it also counts the
objects of a numeral with real touches on its way into the tracing scene — the
half of the counting activity a headless suite cannot reach.

All three point `CharSets.stroke_dir` at a scratch directory under `user://`,
so they never write to — and never depend on what has been recorded in —
`data/strokes/`; the tracing and menu suites write their own small stroke files
there and check the real dataset's SHA-256s afterwards. **Any new test that
drives a scene which reads or writes stroke files must do the same**, or it
will start failing the day that character is re-recorded. The same goes for
progress: `test_progress.gd` and `test_menus.gd` point `Progress.path` at a
scratch file and check `user://progress.json` is untouched, because unlike a
stroke file it holds something nobody can re-record — a real child's real
stars.

All exit non-zero on failure.

## Dataset check (Step 4)

```sh
godot --headless --path . --script tests/validate_dataset.gd
```

Checks the recorded data rather than the code — run it after every recording
batch. It is what confirmed the dataset finished at 137/137 in Step 8, and it
stays the check to run against any re-recording. It walks every
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
`thai_numerals`, `thai_vowels`.
