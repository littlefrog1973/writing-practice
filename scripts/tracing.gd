extends Control
## Step 5 tracing scene — the first screen the child actually uses.
##
## Launch: godot --path . -- --tracing    (add --mouse to trace with a mouse)
##
## State machine, one character at a time:
##   DEMO   the character draws itself stroke by stroke, numbered in order;
##          "watch again" replays it, keeping whatever has been traced already.
##   TRACE  the current stroke is a dotted guide with a start marker and a
##          direction arrow, strokes still to come are dimmed, finished ones
##          are the child's own ink. Lifting the finger ends a stroke.
##   SCORE  a placeholder with a "next" button — stars, sounds and scorer.gd
##          are Step 6. Nothing here judges how good the tracing was.
##
## There is no fail state anywhere: a finished stroke always advances, however
## it looks. The only thing that does not advance is a stroke shorter than
## MIN_TRACE_LENGTH — a stray tap, not an attempt — and even that is skipped
## when the guide stroke is itself a dot (the dot on an "i").
##
## The reference glyph goes through GlyphGuide into a *square* box, exactly as
## the Stroke Recorder does. Stroke points are normalized against the box, not
## against their own bounding box, so a box of a different aspect ratio would
## slide every recorded stroke off the glyph.

## Preloaded rather than referenced by class_name: the global class cache lives
## in the gitignored .godot/ directory and is only written by the editor, so a
## fresh checkout run straight from the CLI would not resolve the names.
const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const GG := preload("res://scripts/glyph_guide.gd")

const SARABUN: FontFile = preload("res://assets/fonts/sarabun/Sarabun-Regular.ttf")
const ANDIKA: FontFile = preload("res://assets/fonts/andika/Andika-Regular.ttf")

enum State {
	EMPTY,  ## The character has no recorded strokes — nothing to trace.
	DEMO,
	TRACE,
	SCORE,
}

const INK_WIDTH := 20.0
const INK_COLOR := Color(0.11, 0.36, 0.72)
const LIVE_COLOR := Color(0.15, 0.5, 0.85)
const UPCOMING_WIDTH := 10.0
const UPCOMING_COLOR := Color(0.45, 0.5, 0.62, 0.22)

const RESAMPLE_SPACING := 6.0  ## Screen px between kept points; tames touch density.
const DOT_LENGTH := 6.0  ## A touch that travels less than this is stored as a dot.
const DOT_OFFSET := Vector2(1.0, 1.0)  ## Gives a dot two points so it renders.
const DOT_GUIDE_RATIO := 0.02  ## A guide stroke this short is a dot, not a line.
const MIN_TRACE_LENGTH := 24.0  ## Below this a touch is a stray tap, not a stroke.

@onready var _draw_box: Panel = $DrawBox
@onready var _glyph: Label = $DrawBox/Glyph
@onready var _upcoming: Node2D = $GuideLayer/Upcoming
@onready var _dotted: Node2D = $GuideLayer/Dotted
@onready var _demo: Node2D = $Demo
@onready var _ink_layer: Node2D = $InkLayer
@onready var _char_name: Label = $TopBar/CharName
@onready var _set_label: Label = $TopBar/SetLabel
@onready var _stroke_info: Label = $TopBar/StrokeInfo
@onready var _progress: Label = $SidePanel/Margin/VBox/Progress
@onready var _status: Label = $Status
@onready var _score_overlay: Control = $ScoreOverlay
@onready var _score_message: Label = $ScoreOverlay/Card/Margin/VBox/Message

var _set_ids := PackedStringArray()
var _set_index := 0
var _char_index := 0
var _entries: Array = []  ## Entries of the current set's file.
var _strokes: Array = []  ## Array[PackedVector2Array], normalized, the guide.
var _state: State = State.EMPTY
var _stroke_index := 0  ## The stroke being traced now.

var _traced: Array = []  ## The child's strokes so far, normalized — Step 6 scores these.
var _ink_lines: Array[Line2D] = []
var _guide_lines: Array[Line2D] = []
var _live := PackedVector2Array()  ## Screen-space points of the stroke in progress.
var _live_line: Line2D
var _touch := -1  ## Touch index owning the stroke in progress, -1 when idle.

var _pending_set := ""  ## Character requested before the scene was ready.
var _pending_char := ""


func _ready() -> void:
	_set_ids = CS.recordable_ids()
	_live_line = _make_line(_ink_layer, LIVE_COLOR, INK_WIDTH)
	_demo.finished.connect(_on_demo_finished)
	_connect_buttons()
	if _set_ids.is_empty():
		_say("No character sets with characters in the catalog — nothing to trace.")
		return
	# Wait one frame so the drawing box has its final on-screen rect before any
	# stored strokes are mapped into it.
	await get_tree().process_frame
	if _pending_set.is_empty():
		_load_set(0)
		_open_char(0)
	else:
		open(_pending_set, _pending_char)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)


## Open a character by set id and character. The command line has no menus to
## come from until Step 7, so this is how the tests and (later) the character
## select screen choose what to practise.
func open(set_id: String, chr: String) -> void:
	if not is_node_ready():
		_pending_set = set_id
		_pending_char = chr
		return
	var set_at := Array(_set_ids).find(set_id)
	if set_at == -1:
		_say("Unknown character set \"%s\"." % set_id)
		return
	_load_set(set_at)
	var char_at := Array(CS.chars_of(set_id)).find(chr)
	if char_at == -1:
		_say("\"%s\" is not in %s." % [chr, CS.label_of(set_id)])
		return
	_open_char(char_at)


# --- state machine -----------------------------------------------------------

func _enter_demo() -> void:
	_state = State.DEMO
	_cancel_live_stroke()
	_score_overlay.visible = false
	_dotted.clear()
	_upcoming.visible = false
	_ink_layer.visible = false
	_demo.visible = true
	_demo.set_strokes(_screen_strokes())
	_demo.play()
	_refresh_labels()
	_say("Watch how \"%s\" is written." % _current_char())


## Back to tracing at whatever stroke the child had reached: "watch again" in
## the middle of a character must not throw away the strokes already traced.
func _enter_trace() -> void:
	_state = State.TRACE
	_demo.stop()
	_demo.visible = false
	_score_overlay.visible = false
	_upcoming.visible = true
	_ink_layer.visible = true
	_refresh_guide()
	_refresh_labels()
	_say("Your turn — start at the orange dot.")


func _enter_score() -> void:
	_state = State.SCORE
	_cancel_live_stroke()
	_dotted.clear()
	_upcoming.visible = false
	_score_message.text = "You wrote %s!" % _current_char()
	_score_overlay.visible = true
	_refresh_labels()
	_say("Done — stars and sounds arrive in Step 6.")


func _on_demo_finished() -> void:
	if _state == State.DEMO:
		_enter_trace()


# --- input -------------------------------------------------------------------

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _state != State.TRACE or _touch != -1 or not _box().has_point(event.position):
			return
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
		KEY_R:
			_on_watch_again()
		KEY_SPACE:
			_on_start_over()
		KEY_LEFT:
			_step_char(-1)
		KEY_RIGHT:
			_step_char(1)
		KEY_UP:
			_step_set(-1)
		KEY_DOWN:
			_step_set(1)


# --- tracing -----------------------------------------------------------------

func _finish_stroke() -> void:
	var points := _live
	_cancel_live_stroke()
	if points.is_empty() or _stroke_index >= _strokes.size():
		return
	if SD.stroke_length(points) < MIN_TRACE_LENGTH and not _guide_is_dot(_stroke_index):
		# A stray tap — a resting palm, a mis-touch. Not a judgement of the
		# tracing: the stroke stays open so the child can simply draw it.
		_say("Draw along the dots, from the orange dot to the end.")
		return
	if SD.stroke_length(points) < DOT_LENGTH:
		points = PackedVector2Array([points[0], points[0] + DOT_OFFSET])
	else:
		points = SD.resample_stroke(points, RESAMPLE_SPACING)
	_traced.append(SD.normalize_stroke(points, _box()))
	var line := _make_line(_ink_layer, INK_COLOR, INK_WIDTH)
	line.points = points
	_ink_lines.append(line)
	# The live line was created first, so keep it drawn above finished ink.
	_ink_layer.move_child(_live_line, _ink_layer.get_child_count() - 1)
	_stroke_index += 1
	if _stroke_index >= _strokes.size():
		_enter_score()
		return
	_refresh_guide()
	_refresh_labels()
	_say("Stroke %d of %d — next one." % [_stroke_index + 1, _strokes.size()])


func _cancel_live_stroke() -> void:
	_touch = -1
	_live = PackedVector2Array()
	if _live_line != null:
		_live_line.points = _live


# --- buttons -----------------------------------------------------------------

func _on_watch_again() -> void:
	if _state == State.EMPTY:
		return
	_enter_demo()


## Wipe the child's ink and trace the character again from the first stroke.
func _on_start_over() -> void:
	if _state == State.EMPTY:
		return
	_clear_ink()
	_enter_trace()


func _on_next() -> void:
	_step_char(1)


func _step_char(delta: int) -> void:
	if _set_ids.is_empty():
		return
	_open_char(wrapi(_char_index + delta, 0, _chars().size()))


func _step_set(delta: int) -> void:
	if _set_ids.is_empty():
		return
	_load_set(wrapi(_set_index + delta, 0, _set_ids.size()))
	_open_char(0)


# --- loading -----------------------------------------------------------------

func _load_set(index: int) -> void:
	_set_index = wrapi(index, 0, _set_ids.size())
	var path := CS.path_of(_current_set_id())
	var result: Dictionary = SD.load_set(path)
	if result.ok:
		_entries = result.entries
	else:
		_entries = []
		if FileAccess.file_exists(path):
			push_error("[tracing] %s" % result.error)
			_say("Cannot read %s: %s" % [path, result.error])


func _open_char(index: int) -> void:
	_demo.stop()
	_score_overlay.visible = false
	_char_index = wrapi(index, 0, _chars().size())
	_strokes = []
	var saved := SD.find_entry(_entries, _current_char())
	if not saved.is_empty():
		_strokes = (saved["strokes"] as Array).duplicate(true)
	_clear_ink()
	_refresh_glyph()
	_build_guide()
	if _strokes.is_empty():
		_state = State.EMPTY
		_upcoming.visible = false
		_demo.visible = false
		_refresh_labels()
		_say("\"%s\" has not been recorded yet — try the next character."
				% _current_char())
		return
	_enter_demo()


func _clear_ink() -> void:
	# Freed immediately rather than queued: a queued node still draws for the
	# rest of the frame, which would ghost the old ink over the fresh canvas.
	for line in _ink_lines:
		line.free()
	_ink_lines.clear()
	_traced.clear()
	_stroke_index = 0
	_cancel_live_stroke()


# --- display -----------------------------------------------------------------

func _refresh_glyph() -> void:
	var id := _current_set_id()
	# Combining marks cannot stand alone; show them on the dotted placeholder
	# circle Thai teaching materials use.
	var text := ("◌" + _current_char()) if CS.is_combining(id) else _current_char()
	GG.apply(_glyph, _box().size,
			SARABUN if CS.font_of(id) == CS.FONT_THAI else ANDIKA, text)


## One dimmed line per stroke, built once per character; tracing only toggles
## their visibility, so no nodes are created while the child is drawing.
func _build_guide() -> void:
	for line in _guide_lines:
		line.free()
	_guide_lines.clear()
	_dotted.clear()
	for i in _strokes.size():
		var line := _make_line(_upcoming, UPCOMING_COLOR, UPCOMING_WIDTH)
		line.points = _screen_stroke(i)
		_guide_lines.append(line)


func _refresh_guide() -> void:
	for i in _guide_lines.size():
		# Strokes already traced are covered by the child's own ink; the current
		# one is drawn as dots instead.
		_guide_lines[i].visible = i > _stroke_index
	if _stroke_index < _strokes.size():
		_dotted.set_stroke(_screen_stroke(_stroke_index))
	else:
		_dotted.clear()


func _refresh_labels() -> void:
	var id := _current_set_id()
	var chr := _current_char()
	_set_label.text = "%s  %d/%d" % [CS.label_of(id), _char_index + 1, _chars().size()]
	_char_name.text = CS.name_of(id, chr)
	match _state:
		State.DEMO:
			_stroke_info.text = "watch"
		State.TRACE:
			_stroke_info.text = "stroke %d of %d" % [_stroke_index + 1, _strokes.size()]
		State.SCORE:
			_stroke_info.text = "done!"
		_:
			_stroke_info.text = "—"
	_progress.text = "%d of %d recorded in %s" % [_entries.size(), _chars().size(),
			CS.label_of(id)]


func _say(message: String) -> void:
	_status.text = message
	print("[tracing] %s" % message)


# --- helpers -----------------------------------------------------------------

func _make_line(parent: Node2D, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	parent.add_child(line)
	return line


## The drawing box in screen space — the normalization box for every stroke.
## Square, and the same shape as the recorder's, or the data will not fit.
func _box() -> Rect2:
	return _draw_box.get_global_rect()


func _clamp_to_box(point: Vector2) -> Vector2:
	var box := _box()
	return point.clamp(box.position, box.end)


func _screen_stroke(index: int) -> PackedVector2Array:
	return SD.denormalize_stroke(_strokes[index], _box())


func _screen_strokes() -> Array:
	var out: Array = []
	for i in _strokes.size():
		out.append(_screen_stroke(i))
	return out


## True when the guide stroke is a dot (the dot on an "i") rather than a line —
## the one case where a tap is the correct way to trace it.
func _guide_is_dot(index: int) -> bool:
	return SD.stroke_length(_screen_stroke(index)) < _box().size.y * DOT_GUIDE_RATIO


func _current_set_id() -> String:
	return _set_ids[_set_index]


func _chars() -> PackedStringArray:
	return CS.chars_of(_current_set_id())


func _current_char() -> String:
	return _chars()[_char_index]


func _connect_buttons() -> void:
	var vbox := $SidePanel/Margin/VBox
	vbox.get_node("WatchAgain").pressed.connect(_on_watch_again)
	vbox.get_node("StartOver").pressed.connect(_on_start_over)
	vbox.get_node("CharNav/PrevChar").pressed.connect(_step_char.bind(-1))
	vbox.get_node("CharNav/NextChar").pressed.connect(_step_char.bind(1))
	vbox.get_node("SetNav/PrevSet").pressed.connect(_step_set.bind(-1))
	vbox.get_node("SetNav/NextSet").pressed.connect(_step_set.bind(1))
	vbox.get_node("Quit").pressed.connect(get_tree().quit.bind(0))
	$ScoreOverlay/Card/Margin/VBox/Next.pressed.connect(_on_next)
