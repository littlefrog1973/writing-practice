extends Control
## The tap-to-count activity that comes before writing a numeral — Step 10.
##
## set_count(n) puts n objects in the control, faint and waiting. Each tap fills
## one in with a pop and emits `counted` with how many are now counted; when the
## last one lands — after its pop, not before, so the child sees the thing they
## just counted — `finished` follows once.
##
## Zero is its own case: an empty basket, finished by a single tap anywhere.
## Zero is a quantity, and a screen that skipped it would be teaching that it is
## not.
##
## Taps in any order. The child is counting a set, not following a route, and
## being told "wrong one" for touching the second apple first would be teaching
## obedience rather than number.
##
## One node, like star_row.gd: everything is drawn in _draw() and nothing is
## allocated while it animates — _process only advances a clock and asks for a
## redraw, then switches itself off. That rule is why the app is smooth on the
## Surface Go's iGPU, and a pop that ran at 9 objects would be exactly the place
## to break it.
##
## Touch is read in _input() gated on the control's rect, not _gui_input(), for
## the same reason the recorder and the tracing scene do it: it is the path this
## project has actually driven with a finger, and it sidesteps every subtlety of
## mouse emulation over GUI focus. tap_at() below is the whole decision, in
## control-local coordinates, so the headless suite can count without a screen.

const OA := preload("res://scripts/object_art.gd")

## Emitted as each new object is counted, carrying the running total (1…N).
signal counted(count: int)

## Emitted once, a beat after the last object lands.
signal finished()

const POP_TIME := 0.28  ## Seconds an object takes to swell into place.
const OVERSHOOT := 1.7  ## How far past full size the pop swells (ease-out-back).
const FINISH_DELAY := 0.55  ## Pause after the last object before `finished`.
const TAP_SLACK := 1.25  ## A tap counts within this much of an object's radius.

var _count := 0
var _tapped: Array[bool] = []  ## One flag per object, in layout order.
var _pop_at: Array[float] = []  ## When each object was tapped, in _time seconds.
var _time := 0.0
var _done := 0
var _finished := false
var _centres := PackedVector2Array()
var _radius := 0.0


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout)


func _process(delta: float) -> void:
	_time += delta
	if not _finished and _done >= _target() and _time >= _last_pop() + FINISH_DELAY:
		_finished = true
		finished.emit()
	queue_redraw()
	# Nothing to animate and nothing to wait for: stop until the next tap. The
	# clock simply freezes — the next pop starts from wherever it left off.
	if _time >= _last_pop() + POP_TIME and (_finished or _done < _target()):
		set_process(false)


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed:
		return
	if not is_visible_in_tree():
		return
	var rect := get_global_rect()
	if not rect.has_point(event.position):
		return
	if tap_at(event.position - rect.position) >= 0:
		get_viewport().set_input_as_handled()


## Start counting `count` objects (0–9). Resets everything: a character opened
## twice is counted from the beginning both times.
func set_count(count: int) -> void:
	_count = maxi(count, 0)
	_tapped.clear()
	_pop_at.clear()
	for i in _count:
		_tapped.append(false)
		_pop_at.append(0.0)
	_time = 0.0
	_done = 0
	_finished = false
	_relayout()
	set_process(false)


## Count the object under `point` (in this control's own coordinates). Returns
## the index counted, or -1 when the tap hit nothing new — a miss between two
## objects, or one that has already been counted. Zero's basket counts on any
## tap and returns 0.
##
## The whole decision lives here rather than in _input so that the headless
## suite can tap without a display; _input does nothing but convert coordinates.
func tap_at(point: Vector2) -> int:
	if _finished:
		return -1
	if _count == 0:
		_done = 1  ## Nothing to count, but the tap is the child's answer.
		counted.emit(0)
		_pop_at.append(_time)
		set_process(true)
		return 0
	var index := nearest(point)
	if index < 0 or _tapped[index]:
		return -1
	_tapped[index] = true
	_pop_at[index] = _time
	_done += 1
	counted.emit(_done)
	set_process(true)
	queue_redraw()
	return index


## The object `point` falls on, or -1. A little slack around the drawn radius:
## the gap between two objects belongs to the nearer of them, and a five-year-old
## aiming at an apple should not have to hit it exactly — but the slack stays
## under half the spacing, so no tap can be ambiguous between two objects.
func nearest(point: Vector2) -> int:
	var best := -1
	var best_distance := _radius * TAP_SLACK
	for i in _centres.size():
		var distance := _centres[i].distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = i
	return best


## How many objects have been counted so far.
func counted_so_far() -> int:
	return _done


func centres() -> PackedVector2Array:
	return _centres


func radius() -> float:
	return _radius


func _draw() -> void:
	if _count == 0:
		OA.draw_basket(self, size * 0.5, OA.radius_for(0, Rect2(Vector2.ZERO, size)))
		return
	var kind := OA.kind_for_value(_count)
	for i in _centres.size():
		var scale := _pop_scale(i)
		if scale <= 0.0:
			continue
		OA.draw_object(self, kind, _centres[i], _radius * scale, _tapped[i])


func _relayout() -> void:
	var box := Rect2(Vector2.ZERO, size)
	_centres = OA.layout(_count, box)
	_radius = OA.radius_for(_count, box)
	queue_redraw()


## How big object `index` is right now: full size while it waits, then the
## ease-out-back swell of its pop. An uncounted object is always there at full
## size — it is what the child is aiming at next, not something to be revealed.
func _pop_scale(index: int) -> float:
	if not _tapped[index]:
		return 1.0
	var t := clampf((_time - _pop_at[index]) / POP_TIME, 0.0, 1.0)
	if t >= 1.0:
		return 1.0
	var back := t - 1.0
	return 1.0 + back * back * ((OVERSHOOT + 1.0) * back + OVERSHOOT)


## When the most recent object was tapped — the clock `finished` waits on.
func _last_pop() -> float:
	var latest := 0.0
	for at in _pop_at:
		latest = maxf(latest, at)
	return latest


## How many taps finish the activity. Zero has no objects but still takes one
## tap: the child answers "none", and the app does not answer for them.
func _target() -> int:
	return maxi(_count, 1)
