extends Control
## The home screen — Step 7. One big button per character set.
##
## Launch: godot --path .    (this is now the default route)
##
## The buttons are built from the catalog rather than laid out in the scene, so
## a set added to char_sets.gd appears here with no scene to edit — the same
## rule the recorder and the tracing scene already follow. A set with no
## characters yet (thai_vowels, until Step 8) is shown greyed rather than
## hidden: a child can see there is more coming, and an adult can see at a
## glance that it is not finished.
##
## Each button carries the set's own first character in the set's own font, the
## name, and how far the child has got. Nothing here is rebuilt per frame: the
## buttons are made once in _ready(), and this screen is re-instantiated on
## every visit anyway, which is what keeps the stars on it current.

const CS := preload("res://scripts/char_sets.gd")
const PR := preload("res://scripts/progress.gd")

const SARABUN: FontFile = preload("res://assets/fonts/sarabun/Sarabun-Regular.ttf")
const ANDIKA: FontFile = preload("res://assets/fonts/andika/Andika-Regular.ttf")

## Emitted when a set is chosen. screens.gd listens; the scene itself does not
## know what a character-select screen is.
signal set_chosen(set_id: String)

const COLUMNS := 3
const SAMPLE_SIZE := 132  ## Font size of the set's sample character on its button.
const READY_TINT := Color(1, 1, 1)
const EMPTY_TINT := Color(0.72, 0.72, 0.7)

@onready var _grid: GridContainer = $Grid
@onready var _total: Label = $TotalStars

var _progress: Dictionary = {}


func _ready() -> void:
	var loaded := PR.load_progress()
	if not loaded.ok:
		# An unreadable file means no stars on the buttons, and that is all it
		# means — see the note at the top of progress.gd.
		push_error("[menu] %s" % loaded.error)
	_progress = loaded["data"]
	_grid.columns = COLUMNS
	for id in CS.SET_IDS:
		_grid.add_child(_make_button(id))
	var stars := PR.total_stars(_progress)
	_total.text = "%d star%s so far" % [stars, "" if stars == 1 else "s"]
	$Quit.pressed.connect(get_tree().quit.bind(0))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		get_tree().quit()


## One set's button: sample character, name, and progress, stacked. The stack is
## a child of the Button rather than its own text because the sample and the
## name want different fonts and wildly different sizes, and a Button has one of
## each. Everything inside ignores the mouse so the Button still gets the touch.
func _make_button(set_id: String) -> Button:
	var chars := CS.chars_of(set_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 330)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.name = set_id
	button.tooltip_text = CS.label_of(set_id)
	if chars.is_empty():
		# Nothing to practise yet: visible, obviously not ready, not a dead end
		# a child can walk into.
		button.disabled = true
		button.modulate = EMPTY_TINT
	else:
		button.pressed.connect(func() -> void: set_chosen.emit(set_id))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 16
	box.offset_bottom = -16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)

	var sample := _label(chars[0] if not chars.is_empty() else "…", SAMPLE_SIZE,
			Color(0.13, 0.3, 0.6))
	sample.add_theme_font_override("font",
			SARABUN if CS.font_of(set_id) == CS.FONT_THAI else ANDIKA)
	sample.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sample)

	box.add_child(_label(CS.label_of(set_id), 42, Color(0.15, 0.15, 0.2)))
	box.add_child(_label(_progress_line(set_id), 30, Color(0.38, 0.4, 0.47)))
	return button


## "12 of 44 written · 30 stars", or an honest blank for a set with nothing in
## it yet. Never "0 of 44" as a reproach — a set not started reads as an
## invitation.
func _progress_line(set_id: String) -> String:
	var chars := CS.chars_of(set_id)
	if chars.is_empty():
		return "coming soon"
	var summary := PR.summary(_progress, set_id)
	if int(summary["traced"]) == 0:
		return "%d to write" % chars.size()
	return "%d of %d written · %d star%s" % [summary["traced"], summary["total"],
			summary["stars"], "" if int(summary["stars"]) == 1 else "s"]


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
