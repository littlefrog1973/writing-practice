extends Control
## Step 3 Stroke Recorder — the dev-only tool that authors the stroke dataset.
##
## Launch: godot --path . -- --recorder    (add --mouse to draw with a mouse)
##
## Trace the faint reference glyph inside the drawing box with a finger, one
## stroke per touch; strokes are numbered in the order they were drawn. Save
## writes the character into res://data/strokes/<set>.json, replacing any entry
## that set already had for it.
##
## Points are stored normalized against the drawing box (never against the
## stroke's own bounding box), so where a glyph sits inside the box is part of
## the data — Thai tone marks belong high, descenders low. The tracing scene
## (Step 5) must show its reference glyph in a box of the same shape and set it
## up through GlyphGuide, or recorded strokes will not sit on the glyph.

## Preloaded rather than referenced by class_name: the global class cache lives
## in the gitignored .godot/ directory and is only written by the editor, so a
## fresh checkout run straight from the CLI would not resolve the names.
const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const GG := preload("res://scripts/glyph_guide.gd")

const SARABUN: FontFile = preload("res://assets/fonts/sarabun/Sarabun-Regular.ttf")
const ANDIKA: FontFile = preload("res://assets/fonts/andika/Andika-Regular.ttf")

const INK_WIDTH := 16.0
const INK_COLOR := Color(0.11, 0.36, 0.72)
const LIVE_COLOR := Color(0.15, 0.5, 0.85)
const MARK_COLOR := Color(0.85, 0.35, 0.1)
const NUMBER_FONT_SIZE := 46
const RESAMPLE_SPACING := 6.0  ## Screen px between kept points; tames touch density.
const DOT_LENGTH := 6.0  ## A touch that travels less than this is stored as a dot.
const DOT_OFFSET := Vector2(1.0, 1.0)  ## Gives a dot two points so it renders.
const REPLAY_SPEED := 700.0  ## Px per second.
const REPLAY_PAUSE := 0.35  ## Seconds between strokes.

@onready var _draw_box: Panel = $DrawBox
@onready var _glyph: Label = $DrawBox/Glyph
@onready var _ink_layer: Node2D = $InkLayer
@onready var _marks: Control = $Marks
@onready var _set_label: Label = $TopBar/SetLabel
@onready var _char_name: Label = $TopBar/CharName
@onready var _stroke_count: Label = $TopBar/StrokeCount
@onready var _progress: Label = $SidePanel/Margin/VBox/Progress
@onready var _status: Label = $Status

var _set_ids := PackedStringArray()
var _set_index := 0
var _char_index := 0
var _entries: Array = []  ## Entries of the current set's file.
var _load_failed := false  ## Set file exists but is unreadable — refuse to save over it.
var _strokes: Array = []  ## Array[PackedVector2Array], normalized 0–1, this character.
var _unsaved := false
var _confirm_discard := false  ## Second press of a nav button discards unsaved work.

var _live := PackedVector2Array()  ## Screen-space points of the stroke in progress.
var _live_line: Line2D
var _touch := -1  ## Touch index owning the stroke in progress, -1 when idle.

var _lines: Array[Line2D] = []  ## One per finished stroke, screen space.
var _dots: Array[Line2D] = []  ## Start-point marker per stroke.
var _numbers: Array[Label] = []  ## Stroke-order number per stroke.

var _replay_stroke := -1  ## Stroke being replayed, -1 when not replaying.
var _replay_dist := 0.0
var _replay_pause := 0.0


func _ready() -> void:
	set_process(false)
	var catalog: Dictionary = CS.validate()
	if not catalog.ok:
		push_error("[recorder] character catalog is broken: %s" % catalog.error)
	_set_ids = CS.recordable_ids()
	_live_line = _make_line(LIVE_COLOR)
	_connect_buttons()
	if _set_ids.is_empty():
		_say("No character sets with characters in the catalog — nothing to record.")
		return
	# Wait one frame so the drawing box has its final on-screen rect before any
	# saved strokes are mapped into it.
	await get_tree().process_frame
	_open_set(0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)


func _process(delta: float) -> void:
	if _replay_stroke < 0:
		return
	if _replay_pause > 0.0:
		_replay_pause -= delta
		return
	var points := _screen_stroke(_replay_stroke)
	_replay_dist += REPLAY_SPEED * delta
	_lines[_replay_stroke].points = SD.partial_stroke(points, _replay_dist)
	_dots[_replay_stroke].visible = true
	_numbers[_replay_stroke].visible = true
	if _replay_dist >= SD.stroke_length(points):
		_lines[_replay_stroke].points = points
		_replay_stroke += 1
		_replay_dist = 0.0
		_replay_pause = REPLAY_PAUSE
		if _replay_stroke >= _strokes.size():
			_stop_replay()
			_say("Replay finished.")


# --- input -------------------------------------------------------------------

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch != -1 or not _box().has_point(event.position):
			return
		_stop_replay()
		_confirm_discard = false
		_touch = event.index
		_live = PackedVector2Array([_clamp_to_box(event.position)])
		_live_line.points = _live
		get_viewport().set_input_as_handled()
	elif event.index == _touch:
		_finish_stroke()
		get_viewport().set_input_as_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch:
		return
	var point := _clamp_to_box(event.position)
	if _live.is_empty() or _live[-1].distance_to(point) >= 1.0:
		_live.append(point)
		_live_line.points = _live
	get_viewport().set_input_as_handled()


func _on_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_Z:
			_on_undo()
		KEY_C:
			_on_clear()
		KEY_S:
			_on_save()
		KEY_R:
			_on_replay()
		KEY_LEFT:
			_step_char(-1)
		KEY_RIGHT:
			_step_char(1)
		KEY_UP:
			_step_set(-1)
		KEY_DOWN:
			_step_set(1)


# --- recording ---------------------------------------------------------------

func _finish_stroke() -> void:
	var points := _live
	_live = PackedVector2Array()
	_live_line.points = _live
	_touch = -1
	if points.is_empty():
		return
	if SD.stroke_length(points) < DOT_LENGTH:
		# A tap, not a stroke: keep it as a dot (the dot on an "i"), two points
		# apart so a round-capped Line2D still draws it.
		points = PackedVector2Array([points[0], points[0] + DOT_OFFSET])
	else:
		points = SD.resample_stroke(points, RESAMPLE_SPACING)
	_strokes.append(SD.normalize_stroke(points, _box()))
	_unsaved = true
	_rebuild_ink()
	_refresh_labels()
	_say("Stroke %d recorded (%d points)." % [_strokes.size(), points.size()])


func _on_undo() -> void:
	_stop_replay()
	if _strokes.is_empty():
		_say("Nothing to undo.")
		return
	_strokes.pop_back()
	_unsaved = true
	_confirm_discard = false
	_rebuild_ink()
	_refresh_labels()
	_say("Removed the last stroke — %d left." % _strokes.size())


func _on_clear() -> void:
	_stop_replay()
	if _strokes.is_empty():
		_say("Already empty.")
		return
	_strokes.clear()
	_unsaved = true
	_confirm_discard = false
	_rebuild_ink()
	_refresh_labels()
	_say("Cleared. (The saved file is untouched until you press SAVE.)")


func _on_reload() -> void:
	_stop_replay()
	_open_char(_char_index)
	_say("Reloaded \"%s\" from %s." % [_current_char(), CS.path_of(_current_set_id())])


func _on_save() -> void:
	_stop_replay()
	var path := CS.path_of(_current_set_id())
	if _load_failed:
		_say("Refusing to save: %s could not be read, so saving would overwrite it. Fix the file first." % path)
		return
	if _strokes.is_empty():
		_say("No strokes to save. Draw the character first.")
		return
	var chr := _current_char()
	var entry := SD.make_entry(chr, _current_set_id(),
			CS.name_of(_current_set_id(), chr), _strokes.duplicate(true))
	var merged := SD.merge_entry(_entries, entry)
	var result: Dictionary = SD.save_set(path, merged)
	if not result.ok:
		push_error("[recorder] %s" % result.error)
		_say("Save failed: %s" % result.error)
		return
	_entries = merged
	_unsaved = false
	_confirm_discard = false
	_refresh_labels()
	_say("Saved \"%s\" (%d strokes) to %s." % [chr, _strokes.size(), path])


func _on_replay() -> void:
	if _strokes.is_empty():
		_say("Nothing to replay.")
		return
	_start_replay()


# --- navigation --------------------------------------------------------------

func _step_char(delta: int) -> void:
	if not _may_leave():
		return
	_open_char(wrapi(_char_index + delta, 0, _chars().size()))


func _step_set(delta: int) -> void:
	if not _may_leave():
		return
	_open_set(wrapi(_set_index + delta, 0, _set_ids.size()))


## Guards navigation away from unsaved strokes; the second press goes through.
func _may_leave() -> bool:
	if not _unsaved or _confirm_discard:
		_confirm_discard = false
		return true
	_confirm_discard = true
	_say("Unsaved strokes! Press SAVE to keep them, or the same button again to discard.")
	return false


func _open_set(index: int) -> void:
	_set_index = wrapi(index, 0, _set_ids.size())
	var path := CS.path_of(_current_set_id())
	var result: Dictionary = SD.load_set(path)
	if result.ok:
		_entries = result.entries
		_load_failed = false
	elif not FileAccess.file_exists(path):
		_entries = []
		_load_failed = false
	else:
		_entries = []
		_load_failed = true
		push_error("[recorder] %s" % result.error)
		_say("Cannot read %s: %s — saving is disabled for this set." % [path, result.error])
	_open_char(0)
	if not _load_failed:
		_say("Set: %s (%d characters, %d recorded)."
				% [CS.label_of(_current_set_id()), _chars().size(), _entries.size()])


func _open_char(index: int) -> void:
	_stop_replay()
	_char_index = wrapi(index, 0, _chars().size())
	_unsaved = false
	_confirm_discard = false
	_strokes = []
	var saved := SD.find_entry(_entries, _current_char())
	if not saved.is_empty():
		_strokes = (saved["strokes"] as Array).duplicate(true)
	_refresh_glyph()
	_rebuild_ink()
	_refresh_labels()


# --- display -----------------------------------------------------------------

func _refresh_glyph() -> void:
	var id := _current_set_id()
	# Combining marks cannot stand alone; show them on the dotted placeholder
	# circle Thai teaching materials use.
	var text := ("◌" + _current_char()) if CS.is_combining(id) else _current_char()
	GG.apply(_glyph, _box().size,
			SARABUN if CS.font_of(id) == CS.FONT_THAI else ANDIKA, text)


func _refresh_labels() -> void:
	var id := _current_set_id()
	var chr := _current_char()
	_set_label.text = "%s  %d/%d" % [CS.label_of(id), _char_index + 1, _chars().size()]
	_char_name.text = "%s   %s" % [chr, CS.name_of(id, chr)]
	var state := "unsaved" if _unsaved else (
			"saved" if not SD.find_entry(_entries, chr).is_empty() else "not recorded")
	_stroke_count.text = "%d strokes (%s)" % [_strokes.size(), state]
	_progress.text = "%d / %d recorded in %s" % [_entries.size(), _chars().size(),
			CS.label_of(id)]


func _rebuild_ink() -> void:
	# Freed immediately rather than queued: a queued node still draws for the
	# rest of the frame, which would ghost over the rebuilt strokes.
	for line in _lines:
		line.free()
	for dot in _dots:
		dot.free()
	for number in _numbers:
		number.free()
	_lines.clear()
	_dots.clear()
	_numbers.clear()
	for i in _strokes.size():
		var points := _screen_stroke(i)
		var line := _make_line(INK_COLOR)
		line.points = points
		_lines.append(line)
		var dot := _make_line(MARK_COLOR)
		dot.width = INK_WIDTH * 1.7
		dot.points = PackedVector2Array([points[0], points[0] + DOT_OFFSET])
		_dots.append(dot)
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE)
		number.add_theme_color_override("font_color", MARK_COLOR)
		number.position = points[0] + Vector2(14.0, -NUMBER_FONT_SIZE - 18.0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marks.add_child(number)
		_numbers.append(number)
	# The live line is created before any stroke, so keep it drawn on top.
	_ink_layer.move_child(_live_line, _ink_layer.get_child_count() - 1)


func _start_replay() -> void:
	_replay_stroke = 0
	_replay_dist = 0.0
	_replay_pause = 0.0
	_rebuild_ink()
	for line in _lines:
		line.points = PackedVector2Array()
	for dot in _dots:
		dot.visible = false
	for number in _numbers:
		number.visible = false
	set_process(true)
	_say("Replaying %d strokes in order…" % _strokes.size())


func _stop_replay() -> void:
	if _replay_stroke < 0:
		return
	_replay_stroke = -1
	set_process(false)
	_rebuild_ink()


func _say(message: String) -> void:
	_status.text = message
	print("[recorder] %s" % message)


# --- helpers -----------------------------------------------------------------

func _make_line(color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = INK_WIDTH
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	_ink_layer.add_child(line)
	return line


## The drawing box in screen space — the normalization box for every stroke.
func _box() -> Rect2:
	return _draw_box.get_global_rect()


func _clamp_to_box(point: Vector2) -> Vector2:
	var box := _box()
	return point.clamp(box.position, box.end)


func _screen_stroke(index: int) -> PackedVector2Array:
	return SD.denormalize_stroke(_strokes[index], _box())


func _current_set_id() -> String:
	return _set_ids[_set_index]


func _chars() -> PackedStringArray:
	return CS.chars_of(_current_set_id())


func _current_char() -> String:
	return _chars()[_char_index]


func _connect_buttons() -> void:
	var vbox := $SidePanel/Margin/VBox
	vbox.get_node("SetNav/PrevSet").pressed.connect(_step_set.bind(-1))
	vbox.get_node("SetNav/NextSet").pressed.connect(_step_set.bind(1))
	vbox.get_node("CharNav/PrevChar").pressed.connect(_step_char.bind(-1))
	vbox.get_node("CharNav/NextChar").pressed.connect(_step_char.bind(1))
	vbox.get_node("EditRow/Undo").pressed.connect(_on_undo)
	vbox.get_node("EditRow/Clear").pressed.connect(_on_clear)
	vbox.get_node("ToolRow/Replay").pressed.connect(_on_replay)
	vbox.get_node("ToolRow/Reload").pressed.connect(_on_reload)
	vbox.get_node("Save").pressed.connect(_on_save)
	vbox.get_node("Quit").pressed.connect(get_tree().quit.bind(0))
