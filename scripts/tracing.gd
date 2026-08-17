extends Control
## Step 5 tracing scene — the first screen the child actually uses.
##
## Reached from the character-select screen, or with
## `godot --path . -- --tracing` for the first character of the first set (add
## --mouse to trace with a mouse).
##
## State machine, one character at a time:
##   COUNT  numerals only (Step 10): that many objects to tap, one at a time,
##          before the character is written. Tracing "3" teaches the shape, not
##          the amount, and the two are learned together or not at all. Every
##          other set opens straight into DEMO.
##   DEMO   the character draws itself stroke by stroke, numbered in order;
##          "watch again" replays it, keeping whatever has been traced already.
##   TRACE  the current stroke is a dotted guide with a start marker and a
##          direction arrow, strokes still to come are dimmed, finished ones
##          are the child's own ink. Lifting the finger ends a stroke.
##   SCORE  scorer.gd rates the tracing 1–3 stars; the stars pop in one at a
##          time with a note each, confetti falls, and the card offers "again"
##          or "next".
##
## There is no fail state anywhere: a finished stroke always advances, however
## it looks, and the score card never blocks the way on. One star is the floor,
## not a failure — it comes with an invitation to write the character again.
## The only thing that does not advance is a stroke shorter than
## MIN_TRACE_LENGTH — a stray tap, not an attempt — and even that floor is never
## more than MIN_TRACE_RATIO of the stroke being asked for, and is skipped
## entirely when the guide stroke is itself a dot (the dot on an "i").
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
const SC := preload("res://scripts/scorer.gd")
const TB := preload("res://scripts/tone_bank.gd")

const SARABUN: FontFile = preload("res://assets/fonts/sarabun/Sarabun-Regular.ttf")
const ANDIKA: FontFile = preload("res://assets/fonts/andika/Andika-Regular.ttf")

## Emitted when a character has been traced and scored. progress.gd is the
## intended listener (screens.gd connects it): this scene deliberately keeps no
## state of its own beyond the character in front of the child.
signal scored(set_id: String, chr: String, stars: int)

## Emitted when the child asks to leave — the big "back" button, or Esc.
## screens.gd takes them to the character grid of the set they came from; the
## set is carried in the signal because this scene does not know how they
## arrived. Nothing is saved here on the way out: a character is scored when its
## last stroke is finished, and a half-written one is not a result.
signal back_requested(set_id: String)

enum State {
	EMPTY,  ## The character has no recorded strokes — nothing to trace.
	COUNT,  ## Numerals only: count the objects before writing the numeral.
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

## …but never more than this much of the stroke being asked for. Step 8's tone
## marks brought the first short strokes into the dataset: before them the
## shortest real stroke anywhere was Q's tail at 184 px, and the third stroke of
## ◌ื is 41 px. A flat 24 px floor would demand 58% of that stroke before it
## counted at all, and a child who fell short would get nothing but the same
## instruction again. The floor stays where it was for every ordinary stroke.
const MIN_TRACE_RATIO := 0.4

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
@onready var _score_stars: Control = $ScoreOverlay/Card/Margin/VBox/Stars
@onready var _score_message: Label = $ScoreOverlay/Card/Margin/VBox/Message
@onready var _score_hint: Label = $ScoreOverlay/Card/Margin/VBox/Hint
@onready var _confetti: CPUParticles2D = $ScoreOverlay/Confetti
@onready var _count_overlay: Control = $CountOverlay
@onready var _count_objects: Control = $CountOverlay/Objects
@onready var _count_caption: Label = $CountOverlay/Caption
@onready var _count_player: AudioStreamPlayer = $Sounds/Count
@onready var _fanfare_player: AudioStreamPlayer = $Sounds/Fanfare
## One player per star so the three notes can ring together as a chord.
@onready var _star_players: Array[AudioStreamPlayer] = [
	$Sounds/Star1 as AudioStreamPlayer,
	$Sounds/Star2 as AudioStreamPlayer,
	$Sounds/Star3 as AudioStreamPlayer,
]

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

var _stars := 0  ## Stars awarded for the character on screen, 0 before scoring.
## One flourish per star count, synthesized once at startup rather than per
## celebration — building a couple of seconds of audio mid-animation is exactly
## the kind of hitch the demo was kept allocation-free to avoid.
var _fanfares: Array[AudioStreamWAV] = []

## One note per object counted, synthesized once beside the score sounds.
var _count_tones: Array[AudioStreamWAV] = []


func _ready() -> void:
	_set_ids = CS.recordable_ids()
	_live_line = _make_line(_ink_layer, LIVE_COLOR, INK_WIDTH)
	_demo.finished.connect(_on_demo_finished)
	_score_stars.star_popped.connect(_on_star_popped)
	_count_objects.counted.connect(_on_counted)
	_count_objects.finished.connect(_on_counting_finished)
	_build_sounds()
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


## Open a character by set id and character — the public way into this scene.
## The character-select screen and the tests both come through here, and it
## tolerates being called before the scene is in the tree, which is what lets
## screens.gd set the subject before _ready() runs.
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

## Count the objects before writing the numeral. Only reached for a character
## the catalog gives a value to — the digits and the Thai numerals, which are
## the same ten quantities and therefore show the same objects: ๓ and 3 are
## three apples both times, and that is what ties the two numeral systems
## together for a child who is learning both at once.
##
## Nothing here is scored and nothing is written down. Stars are a measure of
## handwriting, and counting is not handwriting.
func _enter_count(value: int) -> void:
	_state = State.COUNT
	_cancel_live_stroke()
	_score_overlay.visible = false
	_dotted.clear()
	_upcoming.visible = false
	_ink_layer.visible = false
	_demo.stop()
	_demo.visible = false
	# The guide glyph is the answer to the question being asked. It comes back
	# the moment the counting is done.
	_glyph.visible = false
	var box := _box()
	_count_overlay.position = box.position
	_count_overlay.size = box.size
	_count_overlay.visible = true
	_count_objects.set_count(value)
	_count_caption.text = "how many?"
	_refresh_labels()
	_say("Count them, then write \"%s\"." % _current_char())


## A new object has just been counted: ring the next note up the scale and say
## the number. The last one adds the character's own name from the catalog —
## "3 — three", "๓ — สาม" — which is the moment the quantity and the symbol are
## put side by side.
func _on_counted(count: int) -> void:
	_count_player.stream = _count_tones[clampi(count - 1, 0, _count_tones.size() - 1)]
	_count_player.play()
	var value: int = CS.value_of(_current_set_id(), _current_char())
	var name := CS.name_of(_current_set_id(), _current_char())
	if count >= value:
		# Zero is named for what it is rather than shown as a count of nothing:
		# "0 — zero" beside an empty box says less than "nothing — zero!".
		_count_caption.text = ("nothing — %s!" % name) if value == 0 \
				else "%s — %s" % [_current_char(), name]
		_say("%d — %s." % [value, name])
	else:
		_count_caption.text = str(count)


func _on_counting_finished() -> void:
	if _state == State.COUNT:
		_enter_demo()


## Put the counting away: the overlay goes and the guide glyph comes back.
## Called by every state that follows COUNT, because "start over" can jump
## straight from counting to tracing.
func _hide_count() -> void:
	_count_player.stop()
	_count_overlay.visible = false
	_glyph.visible = true


func _enter_demo() -> void:
	_state = State.DEMO
	_hide_count()
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
	_hide_count()
	_demo.stop()
	_demo.visible = false
	_score_overlay.visible = false
	_upcoming.visible = true
	_ink_layer.visible = true
	_refresh_guide()
	_refresh_labels()
	_say("Your turn — start at the orange dot.")


## Score what the child drew and celebrate it. The card sits over the side
## panel, not over the drawing box, so the writing being praised stays in sight.
func _enter_score() -> void:
	_state = State.SCORE
	_cancel_live_stroke()
	_dotted.clear()
	_upcoming.visible = false
	var result: Dictionary = SC.score(_strokes, _traced)
	if not result.ok:
		# Nothing here is worth stopping a child for: keep the card cheerful and
		# leave the diagnosis in the console.
		push_error("[tracing] %s" % result.error)
		result = {"stars": 1, "message": "You wrote %s!" % _current_char(), "hint": ""}
	_stars = result.stars
	_score_message.text = result.message
	_score_hint.text = result.hint
	_score_stars.set_stars(_stars, SC.MAX_STARS)
	_score_overlay.visible = true
	_score_stars.celebrate()
	_confetti.celebrate()
	_fanfare_player.stream = _fanfares[_stars - 1]
	_refresh_labels()
	# Plain words, not "★": the status line uses the Thai guide font, which
	# carries no such glyph and would draw a tofu box.
	_say("%d %s — %s" % [_stars, "star" if _stars == 1 else "stars", result.message])
	scored.emit(_current_set_id(), _current_char(), _stars)


func _on_demo_finished() -> void:
	if _state == State.DEMO:
		_enter_trace()


## A star has just landed on the card: ring its note, and let the flourish
## follow the last one.
func _on_star_popped(index: int) -> void:
	if index < _star_players.size():
		_star_players[index].play()
	if index == _stars - 1:
		_fanfare_player.play()


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
			_on_back()
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
	if SD.stroke_length(points) < _stray_tap_floor(_stroke_index) \
			and not _guide_is_dot(_stroke_index):
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
	_hush()
	if _state == State.EMPTY:
		return
	_enter_demo()


## Wipe the child's ink and trace the character again from the first stroke.
## This is also the score card's "again" button.
func _on_start_over() -> void:
	_hush()
	if _state == State.EMPTY:
		return
	_clear_ink()
	_enter_trace()


func _on_next() -> void:
	_step_char(1)


## Leave the character. The celebration is stopped first: walking out while the
## stars are still landing must not leave notes ringing over the next screen.
func _on_back() -> void:
	_hush()
	back_requested.emit(_current_set_id())


# --- celebration -------------------------------------------------------------

## Synthesize the score sounds once, at startup. See tone_bank.gd for why they
## are generated rather than shipped as audio files.
func _build_sounds() -> void:
	for i in _star_players.size():
		_star_players[i].stream = TB.star_tone(i)
	for stars in range(1, SC.MAX_STARS + 1):
		_fanfares.append(TB.fanfare(stars))
	# Nine counting notes: half a second each, and built here with the rest
	# rather than when a numeral is opened — synthesizing audio mid-activity is
	# what once teleported the demo hand through its first stroke.
	for i in TB.COUNT_FREQS.size():
		_count_tones.append(TB.count_tone(i))


## End the celebration early — the child pressed "again" or moved on while the
## stars were still landing. Settling the star row also stops the pops that
## would otherwise keep ringing notes over the next character.
func _hush() -> void:
	for player in _star_players:
		player.stop()
	_fanfare_player.stop()
	_count_player.stop()
	_stars = 0
	_score_stars.set_stars(0, SC.MAX_STARS)


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
	_hush()
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
		_hide_count()
		_upcoming.visible = false
		_demo.visible = false
		_refresh_labels()
		_say("\"%s\" has not been recorded yet — try the next character."
				% _current_char())
		return
	# A numeral is counted out before it is written; everything else opens
	# straight into the demo, exactly as it did before Step 10.
	var value: int = CS.value_of(_current_set_id(), _current_char())
	if value >= 0:
		_enter_count(value)
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
	# Combining marks cannot stand alone; the catalog knows which side of the
	# dotted placeholder circle each one is written on.
	var text := CS.display_form(id, _current_char())
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
	# While the objects are being counted the character's name is the answer to
	# the question on screen — the guide glyph is hidden for the same reason.
	_char_name.text = "how many?" if _state == State.COUNT else CS.name_of(id, chr)
	match _state:
		State.COUNT:
			_stroke_info.text = "count them"
		State.DEMO:
			_stroke_info.text = "watch"
		State.TRACE:
			_stroke_info.text = "stroke %d of %d" % [_stroke_index + 1, _strokes.size()]
		State.SCORE:
			_stroke_info.text = "%d of %d stars" % [_stars, SC.MAX_STARS]
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


## How short a touch has to be before it is read as a stray tap rather than an
## attempt at stroke `index` — never more of the stroke than MIN_TRACE_RATIO.
func _stray_tap_floor(index: int) -> float:
	return minf(MIN_TRACE_LENGTH,
			SD.stroke_length(_screen_stroke(index)) * MIN_TRACE_RATIO)


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
	# ◀ char / char ▶ stay now that there are menus: finishing "ก" and wanting
	# "ข" should not mean a trip back to the grid. Moving between *sets* is what
	# the menus took over — that is a decision, not a place to practise.
	vbox.get_node("CharNav/PrevChar").pressed.connect(_step_char.bind(-1))
	vbox.get_node("CharNav/NextChar").pressed.connect(_step_char.bind(1))
	vbox.get_node("Back").pressed.connect(_on_back)
	var buttons := $ScoreOverlay/Card/Margin/VBox/Buttons
	# "again" is the same action as "start over": wipe the ink and trace the
	# character again — no demo first, they have just watched and written it.
	buttons.get_node("Again").pressed.connect(_on_start_over)
	buttons.get_node("Next").pressed.connect(_on_next)
	# The card covers the side panel — deliberately, so the writing stays in
	# sight — which takes the panel's "back" with it. Without this button the
	# only ways out of the celebration are "again" and "next", and a child who
	# has finished with a letter would have to open another one to leave.
	buttons.get_node("Back").pressed.connect(_on_back)
