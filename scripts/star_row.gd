extends Control
## The row of stars on the score card, drawn rather than typed.
##
## A star is a `draw_colored_polygon`, not a "★" in a label: neither Sarabun nor
## Andika is guaranteed to carry U+2605, and a missing glyph on the one screen
## the whole app is working towards is not worth the risk. Drawing it also makes
## the pop animation possible and keeps the node count fixed at one.
##
## set_stars() then celebrate(): the earned stars swell in one at a time,
## emitting `star_popped` as each lands so the scene can ring a note with it.
## Unearned stars are always there as a faint outline — what the child is
## reaching for next, never a mark against them.
##
## No node is created while it animates: _process() only advances a clock and
## calls queue_redraw(), and it stops itself once the last star has landed.

## Emitted as each earned star finishes popping, in order, starting at 0.
signal star_popped(index: int)

const STAR_POINTS := 5
const INNER_RATIO := 0.44  ## Inner radius of the star as a fraction of the outer.
const GAP_RATIO := 0.34  ## Space between stars as a fraction of a star's width.

const EARNED_COLOR := Color(1.0, 0.78, 0.16)
const EARNED_EDGE := Color(0.85, 0.5, 0.05)
const EMPTY_COLOR := Color(0.78, 0.75, 0.68, 0.35)
const EDGE_WIDTH := 5.0

const POP_TIME := 0.34  ## Seconds one star takes to swell into place.
const POP_DELAY := 0.26  ## Seconds between one star landing and the next starting.
const OVERSHOOT := 1.9  ## How far past full size the pop swells (ease-out-back).

var _stars := 0
var _total := 3
var _time := -1.0  ## Seconds since celebrate(), negative when not animating.
var _popped := 0  ## Stars whose `star_popped` has already been emitted.


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	while _popped < _stars and _time >= _landing_time(_popped):
		_popped += 1
		star_popped.emit(_popped - 1)
	if _popped >= _stars and _time >= _landing_time(maxi(_stars - 1, 0)):
		set_process(false)
	queue_redraw()


## Show `stars` of `total` filled in, with no animation. celebrate() replays it.
func set_stars(stars: int, total: int = 3) -> void:
	_total = maxi(total, 1)
	_stars = clampi(stars, 0, _total)
	_time = -1.0
	_popped = _stars
	set_process(false)
	queue_redraw()


## Pop the earned stars in one at a time from nothing. Emits `star_popped` per
## star; the scene uses that to play a note with each one.
func celebrate() -> void:
	_time = 0.0
	_popped = 0
	queue_redraw()
	if _stars > 0:
		set_process(true)


func _draw() -> void:
	var radius := _radius()
	var centre := Vector2(size.x * 0.5, size.y * 0.5)
	var step := radius * 2.0 * (1.0 + GAP_RATIO)
	var first := centre.x - step * (float(_total) - 1.0) * 0.5
	for i in _total:
		var at := Vector2(first + step * float(i), centre.y)
		if i >= _stars:
			_draw_star(at, radius, EMPTY_COLOR, Color(EMPTY_COLOR, 0.0))
			continue
		var scale := _pop_scale(i)
		if scale > 0.0:
			_draw_star(at, radius * scale, EARNED_COLOR, EARNED_EDGE)


## Size of one star so that `_total` of them plus the gaps fit the control.
func _radius() -> float:
	var by_width := size.x / (float(_total) * 2.0 * (1.0 + GAP_RATIO))
	return minf(by_width, size.y * 0.5) * 0.94


## How big star `index` is right now: 0 before its turn, an ease-out-back swell
## through its pop, 1 once it has landed (and always 1 when not animating).
func _pop_scale(index: int) -> float:
	if _time < 0.0:
		return 1.0
	var start := _landing_time(index) - POP_TIME
	if _time <= start:
		return 0.0
	var t := clampf((_time - start) / POP_TIME, 0.0, 1.0)
	if t >= 1.0:
		return 1.0
	var back := t - 1.0
	return 1.0 + back * back * ((OVERSHOOT + 1.0) * back + OVERSHOOT)


func _landing_time(index: int) -> float:
	return POP_TIME + float(index) * POP_DELAY


func _draw_star(centre: Vector2, radius: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array()
	points.resize(STAR_POINTS * 2)
	for i in STAR_POINTS * 2:
		# Start at -90° so a point of the star faces up, then alternate between
		# the outer and inner radius to walk the ten corners.
		var angle := -PI * 0.5 + PI * float(i) / float(STAR_POINTS)
		var r := radius if i % 2 == 0 else radius * INNER_RATIO
		points[i] = centre + Vector2(cos(angle), sin(angle)) * r
	draw_colored_polygon(points, fill)
	if edge.a > 0.0:
		draw_polyline(points + PackedVector2Array([points[0]]), edge, EDGE_WIDTH, true)
