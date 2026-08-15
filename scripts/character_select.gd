extends Control
## The grid of characters in one set, with the stars earned on each — Step 7.
##
## Reached from the main menu, and the way back out of the tracing scene. It is
## the screen a child spends the most time reading, so every button is the
## character itself at finger size with its stars underneath: nothing to work
## out, and a visible reason to go back to one already written.
##
## Unearned stars are drawn as faint outlines rather than left off, exactly as
## on the score card — what there is to reach for, never a mark against them.
##
## A character with no recorded strokes is shown greyed and cannot be opened.
## It is deliberately not hidden: while the dataset is being filled (Step 8) the
## grid is how you see what is left, and a child seeing a letter appear the week
## after is better than one walking into a screen with nothing to trace.
##
## The grid is built once, in _build(): ~44 buttons each holding a star row is
## not something to rebuild per frame or per star. Nothing here changes while
## the screen is up — the screen is re-instantiated on every visit, so the stars
## are re-read from disk each time instead of being kept in sync by hand.

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const PR := preload("res://scripts/progress.gd")
const SC := preload("res://scripts/scorer.gd")
const SR := preload("res://scripts/star_row.gd")

const SARABUN: FontFile = preload("res://assets/fonts/sarabun/Sarabun-Regular.ttf")
const ANDIKA: FontFile = preload("res://assets/fonts/andika/Andika-Regular.ttf")

## screens.gd listens to both; this scene knows nothing about what comes next.
signal char_chosen(set_id: String, chr: String)
signal back_requested()

const MIN_COLUMNS := 4
const MAX_COLUMNS := 8
## Columns ≈ √(n · SHAPE): a squarer grid than one row per eight, so ten digits
## come out as 5 × 2 rather than 8 + 2.
const COLUMN_SHAPE := 2.2
const SEPARATION := 22.0  ## Must match the Grid's h/v separation in the scene.
## Used only if the grid area has no size yet — the rect it has in the scene.
const FALLBACK_AREA := Vector2(1800, 1024)

## The character and its stars as fractions of the cell, so ten big digits and
## forty-four small consonants are laid out by the same rule.
const CHAR_RATIO := 0.48
const STAR_RATIO := 0.2
const MIN_CHAR_SIZE := 44
const MAX_CHAR_SIZE := 150

const EMPTY_TINT := Color(0.72, 0.72, 0.7)

@onready var _grid: GridContainer = $GridArea/Grid
@onready var _title: Label = $TopBar/Title
@onready var _summary: Label = $TopBar/Summary
@onready var _empty_note: Label = $EmptyNote

var _set_id := ""
var _progress: Dictionary = {}
var _entries: Array = []  ## Recorded entries of this set — which characters are ready.


func _ready() -> void:
	$TopBar/Back.pressed.connect(func() -> void: back_requested.emit())
	_build()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		back_requested.emit()


## Choose the set to show. Called by screens.gd before the scene enters the
## tree, so it must work both before and after _ready() — the same contract as
## the tracing scene's open().
func show_set(set_id: String) -> void:
	_set_id = set_id
	if is_node_ready():
		_build()


# --- building ----------------------------------------------------------------

func _build() -> void:
	for child in _grid.get_children():
		child.free()
	_progress = _load_progress()
	_entries = _load_entries()
	var chars := CS.chars_of(_set_id)
	_title.text = CS.label_of(_set_id)
	_summary.text = _summary_line(chars)
	_empty_note.visible = chars.is_empty()
	_grid.visible = not chars.is_empty()
	if chars.is_empty():
		return
	_grid.columns = clampi(int(ceil(sqrt(float(chars.size()) * COLUMN_SHAPE))),
			MIN_COLUMNS, MAX_COLUMNS)
	var cell := _cell_size(chars.size())
	for chr in chars:
		_grid.add_child(_make_button(chr, cell))


## The size of one button: as wide as the columns allow, never taller than it is
## wide. Without the cap, a set of ten digits gets two rows of half-metre-tall
## buttons — filling the space is not the same as using it.
func _cell_size(count: int) -> Vector2:
	var area: Vector2 = $GridArea.size
	if area.x < 1.0 or area.y < 1.0:
		area = FALLBACK_AREA
	var columns := _grid.columns
	var rows := int(ceil(float(count) / float(columns)))
	var width := (area.x - float(columns - 1) * SEPARATION) / float(columns)
	var height := (area.y - float(rows - 1) * SEPARATION) / float(rows)
	return Vector2(width, minf(height, width))


## One character's button: the character itself at finger size, its stars
## underneath. The stack is a child of the Button because the character wants
## the set's font at cell size and the stars are drawn, not typed — see
## star_row.gd.
func _make_button(chr: String, cell: Vector2) -> Button:
	var char_size := clampi(int(cell.y * CHAR_RATIO), MIN_CHAR_SIZE, MAX_CHAR_SIZE)
	var star_height := int(cell.y * STAR_RATIO)
	var recorded := not SD.find_entry(_entries, chr).is_empty()
	var button := Button.new()
	button.custom_minimum_size = cell
	button.name = "Char_%d" % chr.unicode_at(0)  ## Node names cannot be Thai.
	button.tooltip_text = CS.name_of(_set_id, chr)
	if recorded:
		var set_id := _set_id
		button.pressed.connect(func() -> void: char_chosen.emit(set_id, chr))
	else:
		button.disabled = true
		button.modulate = EMPTY_TINT

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 10
	box.offset_bottom = -10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)

	# Combining marks cannot stand alone: the dotted placeholder circle Thai
	# teaching materials use, the same one the recorder and tracing scene show.
	var text := ("◌" + chr) if CS.is_combining(_set_id) else chr
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",
			SARABUN if CS.font_of(_set_id) == CS.FONT_THAI else ANDIKA)
	label.add_theme_font_size_override("font_size", char_size)
	label.add_theme_color_override("font_color", Color(0.13, 0.3, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	if recorded:
		# SR.new() rather than a scene instance: star_row.gd is a plain Control
		# script with no scene of its own, and this keeps its type — and so
		# set_stars() — checked at compile time.
		var stars := SR.new()
		stars.custom_minimum_size = Vector2(0, star_height)
		stars.name = "Stars"
		box.add_child(stars)
		# After add_child: set_stars() only queues a redraw, but star_row's own
		# _ready is what makes it ignore the mouse, and the button needs that.
		stars.set_stars(PR.stars_of(_progress, _set_id, chr), SC.MAX_STARS)
	else:
		var soon := Label.new()
		soon.text = "soon"
		soon.custom_minimum_size = Vector2(0, star_height)
		soon.add_theme_font_size_override("font_size", maxi(int(star_height * 0.8), 20))
		soon.add_theme_color_override("font_color", Color(0.5, 0.49, 0.46))
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(soon)
	return button


func _summary_line(chars: PackedStringArray) -> String:
	if chars.is_empty():
		return ""
	var summary := PR.summary(_progress, _set_id)
	return "%d of %d written · %d star%s" % [summary["traced"], summary["total"],
			summary["stars"], "" if int(summary["stars"]) == 1 else "s"]


# --- loading -----------------------------------------------------------------

func _load_progress() -> Dictionary:
	var loaded := PR.load_progress()
	if not loaded.ok:
		push_error("[characters] %s" % loaded.error)
	return loaded["data"]


## The recorded strokes of this set — read only to tell which characters are
## ready to trace. A missing file is not an error: it is a set nobody has
## recorded yet, and every character in it shows as "soon".
func _load_entries() -> Array:
	if _set_id.is_empty():
		return []
	var path := CS.path_of(_set_id)
	var result: Dictionary = SD.load_set(path)
	if result.ok:
		return result.entries
	if FileAccess.file_exists(path):
		push_error("[characters] %s" % result.error)
	return []
