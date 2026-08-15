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

## Font size as a fraction of the box height. Chosen so that the tallest
## characters (ฐ, ฎ, ป) just fit the box; ordinary ones are proportionally
## smaller, exactly as they are on a handwriting practice sheet.
const FONT_SIZE_RATIO := 0.76

## Upward shift of the text, as a fraction of the *font size* — it cancels a
## line-metric offset, so it has to scale with the font, not with the box.
const LIFT_RATIO := 0.125

## Extra room around the box (fraction of box size) so nothing is clipped.
const OVERFLOW_RATIO := 0.5


## Configure `label` — a full-rect child of the drawing box — to draw `text`
## as the guide glyph for a box of `box_size` pixels.
static func apply(label: Label, box_size: Vector2, font: Font, text: String) -> void:
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", roundi(box_size.y * FONT_SIZE_RATIO))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	var pad := box_size * OVERFLOW_RATIO
	var lift := box_size.y * FONT_SIZE_RATIO * LIFT_RATIO
	label.offset_left = -pad.x
	label.offset_top = -pad.y - lift
	label.offset_right = pad.x
	label.offset_bottom = pad.y - lift
