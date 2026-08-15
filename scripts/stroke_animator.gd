extends Node2D
## The stroke-order demo: the character draws itself one stroke at a time, a
## finger-dot leading each line and the stroke's order number appearing with it.
##
## Reusable on purpose — hand it screen-space strokes with set_strokes(), then
## play(); it emits `finished` when the last stroke is complete. The tracing
## scene uses it for both the opening demo and "watch again".
##
## It allocates nodes only in set_strokes() (once per character): while playing,
## each frame does nothing but reassign `Line2D.points`. Freeing and recreating
## nodes at 60 fps is exactly what "visible stutter" would look like on the
## Surface Go's iGPU, and smoothness there is a gate criterion.

const SD := preload("res://scripts/stroke_data.gd")

## Emitted once the last stroke has been drawn and held for `pause` seconds.
signal finished

const LINE_WIDTH := 18.0
const LINE_COLOR := Color(0.15, 0.5, 0.85)
const FINGER_WIDTH := 38.0
const FINGER_COLOR := Color(0.92, 0.45, 0.12)
const FINGER_OFFSET := Vector2(0.5, 0.5)  ## A Line2D needs two points to draw.
const NUMBER_FONT_SIZE := 48
const NUMBER_COLOR := Color(0.85, 0.35, 0.1)
const NUMBER_OFFSET := Vector2(18.0, -72.0)

var speed := 520.0  ## Px per second the demo hand travels — a child's pace.
var pause := 0.5  ## Seconds of stillness between strokes, and after the last.

var _strokes: Array = []  ## Array[PackedVector2Array], screen space.
var _lengths := PackedFloat32Array()  ## Path length per stroke, precomputed.
var _lines: Array[Line2D] = []
var _numbers: Array[Label] = []
var _finger: Line2D
var _index := -1  ## Stroke being drawn, -1 when idle.
var _dist := 0.0  ## How far along that stroke the hand has travelled.
var _wait := 0.0  ## Seconds left of the pause between strokes.


func _ready() -> void:
	set_process(false)
	_finger = _make_line(FINGER_COLOR, FINGER_WIDTH)
	_finger.visible = false


func _process(delta: float) -> void:
	if _index < 0:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		_finger.visible = true
	# Checked after the pause, not when the last stroke ends, so the finished
	# character is held on screen for a beat (and so `pause = 0` is still safe).
	if _index >= _strokes.size():
		_finish()
		return
	var points: PackedVector2Array = _strokes[_index]
	_numbers[_index].visible = true
	_dist += speed * delta
	var drawn := SD.partial_stroke(points, _dist)
	_lines[_index].points = drawn
	if not drawn.is_empty():
		_move_finger(drawn[-1])
	if _dist < _lengths[_index]:
		return
	# Stroke complete: snap it to its full geometry and rest before the next one.
	_lines[_index].points = points
	_move_finger(points[-1])
	_index += 1
	_dist = 0.0
	_wait = pause
	_finger.visible = false


## Set the strokes to demonstrate (screen space). Rebuilds the drawing nodes,
## so call it when the character changes — not to restart the animation.
func set_strokes(strokes: Array) -> void:
	stop()
	_free_nodes()
	_strokes = strokes
	_lengths.resize(strokes.size())
	for i in strokes.size():
		var points: PackedVector2Array = strokes[i]
		_lengths[i] = SD.stroke_length(points)
		_lines.append(_make_line(LINE_COLOR, LINE_WIDTH))
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE)
		number.add_theme_color_override("font_color", NUMBER_COLOR)
		number.position = points[0] + NUMBER_OFFSET
		number.visible = false
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(number)
		_numbers.append(number)
	# The finger is created before any stroke line, so lift it back on top.
	move_child(_finger, get_child_count() - 1)


## Restart the demo from the first stroke. Allocates nothing.
func play() -> void:
	if _strokes.is_empty():
		return
	_index = 0
	_dist = 0.0
	_wait = 0.0
	for line in _lines:
		line.points = PackedVector2Array()
	for number in _numbers:
		number.visible = false
	_finger.visible = true
	_move_finger(_strokes[0][0])
	set_process(true)


## Stop mid-animation and clear what was drawn. No `finished` signal — that is
## reserved for the demo actually reaching the end.
func stop() -> void:
	if _index < 0:
		return
	_index = -1
	set_process(false)
	_finger.visible = false
	for line in _lines:
		line.points = PackedVector2Array()
	for number in _numbers:
		number.visible = false


func is_playing() -> bool:
	return _index >= 0


func _finish() -> void:
	_index = -1
	set_process(false)
	_finger.visible = false
	finished.emit()


func _move_finger(to: Vector2) -> void:
	_finger.points = PackedVector2Array([to, to + FINGER_OFFSET])


func _make_line(color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	add_child(line)
	return line


func _free_nodes() -> void:
	# Freed immediately rather than queued: a queued node still draws for the
	# rest of the frame, which would ghost the old character over the new one.
	for line in _lines:
		line.free()
	for number in _numbers:
		number.free()
	_lines.clear()
	_numbers.clear()
