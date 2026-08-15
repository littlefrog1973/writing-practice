class_name GlyphGuide
extends RefCounted
## Places the faint reference glyph inside a drawing box — the one definition
## of how a character is drawn as a tracing guide.
##
## Every scene that shows a guide glyph (the Stroke Recorder, and the tracing
## scene from Step 5 on) must configure its Label through here: recorded
## strokes are stored relative to the drawing box, so if a scene rendered the
## glyph at a different size or offset the strokes would no longer sit on it.
##
## Why the Label is not simply stretched over the box: a Label centres text by
## line metrics, and Thai fonts reserve a lot of the line above and below the
## consonant band for vowels and tone marks. Centring on those metrics parks
## the glyph low and clips descenders on the box edge, so the label is given
## room to overflow the box and is lifted by a fraction of the box height.

const CS := preload("res://scripts/char_sets.gd")

## Font size as a fraction of the box height. Chosen so that the tallest
## characters (ฐ, ฎ, ป) just fit the box; ordinary ones are proportionally
## smaller, exactly as they are on a handwriting practice sheet.
const FONT_SIZE_RATIO := 0.76

## The same, for a mark shown on its dotted placeholder (Step 8's vowels and
## tone marks). Such a glyph is a two-character cluster with the mark stacked
## above or below the circle, so it needs far more of the line than a single
## letter: at FONT_SIZE_RATIO the tallest of them (◌็) put ink 0.065 of the box
## *above* the top edge — where the recorder clamps touches and no stroke can be
## recorded, so the guide would be asking for something impossible to trace.
## Measured over all 21 marks, 0.60 keeps every one inside with at least 0.05 of
## the box to spare (the tightest is ◌็ at 0.052; the lowest is ◌ู at 0.868).
const COMBINING_SIZE_RATIO := 0.60

## Upward shift of the text, as a fraction of the *font size* — it cancels a
## line-metric offset, so it has to scale with the font, not with the box.
const LIFT_RATIO := 0.125

## Extra room around the box (fraction of box size) so nothing is clipped.
const OVERFLOW_RATIO := 0.5


## Configure `label` — a full-rect child of the drawing box — to draw `text`
## as the guide glyph for a box of `box_size` pixels.
static func apply(label: Label, box_size: Vector2, font: Font, text: String) -> void:
	# The ratio follows from the text itself rather than from an argument the
	# scenes pass: the recorder, the grid and the tracing scene must all size a
	# glyph identically, and a character already recorded must never be resized
	# under its strokes. No recorded character contains the placeholder.
	var ratio := size_ratio_for(text)
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", roundi(box_size.y * ratio))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	var pad := box_size * OVERFLOW_RATIO
	var lift := box_size.y * ratio * LIFT_RATIO
	label.offset_left = -pad.x
	label.offset_top = -pad.y - lift
	label.offset_right = pad.x
	label.offset_bottom = pad.y - lift


## Font size ratio for a guide glyph: smaller for a mark drawn on its dotted
## placeholder, which is two characters tall rather than one.
static func size_ratio_for(text: String) -> float:
	return COMBINING_SIZE_RATIO if text.contains(CS.PLACEHOLDER) else FONT_SIZE_RATIO
