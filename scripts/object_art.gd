extends RefCounted
## The things a child counts before writing a numeral — Step 10.
##
## Every object here is drawn: a few polygons and circles into whatever
## CanvasItem is passed in. There is no assets/images/, exactly as there is no
## assets/audio/, and for the same reason — the two OFL fonts are the only
## things in this repository that came from outside it, and each arrived with
## its licence beside it. Downloaded clip-art is the easiest way to end up with
## an asset nobody can account for a year later. Drawing also scales to any size
## without a single import setting, which matters when the same apple has to
## look right at three to a row and at nine.
##
## Static and pure — it holds no node and no state, so tests/test_count_objects
## can check the geometry headless, where nothing is ever drawn.
##
## The value → kind table is fixed on purpose. Three is *always* three apples
## and seven is always seven fish, in both numeral systems, so that ๓ and 3 show
## a child the same three things: that sameness is the whole reason both number
## sets got this activity rather than one of them.

enum Kind { APPLE, BALLOON, FISH, BALL, FLOWER, LEAF }

const KIND_NONE := -1  ## Zero has no object — it has an empty basket.

## Which object stands for each quantity. Index is the value, 0–9.
const VALUE_KINDS: Array[int] = [
	KIND_NONE,      # 0 — the empty basket
	Kind.BALLOON,   # 1
	Kind.FISH,      # 2
	Kind.APPLE,     # 3
	Kind.BALL,      # 4
	Kind.FLOWER,    # 5
	Kind.LEAF,      # 6
	Kind.FISH,      # 7
	Kind.BALLOON,   # 8
	Kind.APPLE,     # 9
]

## Fill colours, indexed by Kind. Strong and flat: they are looked at on a
## washed-out laptop screen in daylight, not admired.
const FILLS: Array[Color] = [
	Color(0.90, 0.24, 0.24),  # apple
	Color(0.35, 0.55, 0.92),  # balloon
	Color(0.98, 0.60, 0.16),  # fish
	Color(0.55, 0.35, 0.85),  # ball
	Color(0.95, 0.42, 0.70),  # flower
	Color(0.30, 0.68, 0.35),  # leaf
]

const LEAF_GREEN := Color(0.30, 0.68, 0.35)  ## The apple's leaf and the stalks.
const STALK_BROWN := Color(0.45, 0.32, 0.20)
const FLOWER_MIDDLE := Color(1.0, 0.85, 0.25)
const BASKET_BROWN := Color(0.62, 0.45, 0.26)

## An object still to be counted: the same silhouette, hollow, so the child can
## see what is coming and how many are left without it competing with the ones
## already counted. The hollow fill is opaque rather than translucent — every
## object here is built from overlapping shapes, and translucent ones stack into
## visible seams exactly where the outline should read as a single edge. It is
## the white of the drawing box, near enough to look like nothing.
const EMPTY_LINE := Color(0.60, 0.63, 0.70)
const EMPTY_FILL := Color(0.975, 0.975, 0.985)
const EDGE_WIDTH_RATIO := 0.09  ## Outline width as a fraction of the radius.

## How much of its cell an object fills. The rest is the gap between one target
## and the next: a five-year-old aiming at the wrong apple would count the same
## one twice, which is the one thing this activity must not let happen.
const FILL_RATIO := 0.76

## The biggest an object may be, as a fraction of the shorter side of the box.
const MAX_RADIUS_RATIO := 0.20

const CIRCLE_POINTS := 40  ## Enough that a ball has no visible corners at 300 px.


## The object that stands for `value`, or KIND_NONE for zero and for anything
## outside 0–9.
static func kind_for_value(value: int) -> int:
	if value < 0 or value >= VALUE_KINDS.size():
		return KIND_NONE
	return VALUE_KINDS[value]


## Where `count` objects sit inside `box`: a grid of ceil(sqrt(n)) columns with
## the last row centred under the others, so five is three and two rather than
## three and two shoved left. Pure geometry, which is what lets the spacing be
## checked headless — on a real screen it is the difference between a tap that
## counts an apple and one that counts the apple beside it.
static func layout(count: int, box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if count <= 0:
		return out
	var columns := _columns(count)
	var rows := int(ceil(float(count) / float(columns)))
	var cell := _cell(count, box)
	var grid_height := cell * float(rows)
	var top := box.position.y + (box.size.y - grid_height) * 0.5
	var placed := 0
	for row in rows:
		var in_row := mini(columns, count - placed)
		var row_width := cell * float(in_row)
		var left := box.position.x + (box.size.x - row_width) * 0.5
		for i in in_row:
			out.append(Vector2(left + cell * (float(i) + 0.5),
					top + cell * (float(row) + 0.5)))
		placed += in_row
	return out


## Radius of one object in that layout. Kept beside layout() rather than derived
## by the caller: the gap between neighbours is FILL_RATIO of a cell either way,
## and two definitions of it would drift apart.
##
## Capped, because a cell is the whole box when there is one thing in it and a
## single balloon the size of the drawing box does not look like one balloon —
## it looks like a mistake. With the cap, one object is much the size of four.
static func radius_for(count: int, box: Rect2) -> float:
	var most := minf(box.size.x, box.size.y) * MAX_RADIUS_RATIO
	if count <= 0:
		return most * 1.3  ## The lone basket may be bigger; nothing sits beside it.
	return minf(_cell(count, box) * 0.5 * FILL_RATIO, most)


## Draw one object. `filled` is the whole of the state a counted object has:
## before the tap it is a faint outline of the same shape and size, after it the
## real thing.
static func draw_object(canvas: CanvasItem, kind: int, centre: Vector2, radius: float,
		filled: bool) -> void:
	match kind:
		Kind.APPLE:
			_apple(canvas, centre, radius, filled)
		Kind.BALLOON:
			_balloon(canvas, centre, radius, filled)
		Kind.FISH:
			_fish(canvas, centre, radius, filled)
		Kind.BALL:
			_ball(canvas, centre, radius, filled)
		Kind.FLOWER:
			_flower(canvas, centre, radius, filled)
		Kind.LEAF:
			_leaf(canvas, centre, radius, filled)
		_:
			_ball(canvas, centre, radius, filled)


## The basket that stands in for zero: drawn empty, and stays empty. Zero is a
## quantity, and a screen that skipped it would be teaching that it is not.
static func draw_basket(canvas: CanvasItem, centre: Vector2, radius: float) -> void:
	var width := radius * EDGE_WIDTH_RATIO * 0.9
	var half := radius
	var top := centre.y - radius * 0.45
	var bottom := centre.y + radius * 0.75
	var body := PackedVector2Array([
		Vector2(centre.x - half, top),
		Vector2(centre.x + half, top),
		Vector2(centre.x + half * 0.72, bottom),
		Vector2(centre.x - half * 0.72, bottom),
	])
	canvas.draw_colored_polygon(body, Color(BASKET_BROWN, 0.22))
	canvas.draw_polyline(body + PackedVector2Array([body[0]]), BASKET_BROWN, width, true)
	# The weave: a few uprights and one band, enough to read as a basket at a
	# glance and cheap enough to redraw every frame of a pop.
	for i in range(1, 4):
		var t := float(i) / 4.0
		canvas.draw_line(body[0].lerp(body[1], t), body[3].lerp(body[2], t),
				Color(BASKET_BROWN, 0.55), width * 0.6, true)
	var band := 0.45
	canvas.draw_line(body[0].lerp(body[3], band), body[1].lerp(body[2], band),
			Color(BASKET_BROWN, 0.55), width * 0.6, true)
	# The handle, drawn as an arc above the rim.
	var handle := PackedVector2Array()
	for i in 17:
		var angle := PI + PI * float(i) / 16.0
		handle.append(Vector2(centre.x + cos(angle) * half * 0.86,
				top + sin(angle) * radius * 0.62))
	canvas.draw_polyline(handle, BASKET_BROWN, width, true)


# --- the objects -------------------------------------------------------------
#
# Each is a handful of shapes in a box of ±radius around `centre`, and each is
# drawn the same way: _blob() lays down the whole silhouette in the edge colour
# and the shapes themselves on top, so an object made of overlapping parts has
# one outline around the outside and no seams through the middle. An apple with
# a line down each lobe is a pumpkin, which is what the first version drew.
#
# The small details — a stalk, an eye, the seams of a ball — are added only once
# the object has been counted. Uncounted it is a plain hollow shape: simpler to
# aim at, and the detail arriving with the tap is part of the reward.
#
# They are deliberately simple. What a child has to tell apart here is *how
# many*, not which fruit, and a detailed drawing at nine to a screen is a smudge.

static func _apple(canvas: CanvasItem, centre: Vector2, radius: float, filled: bool) -> void:
	# One smooth outline rather than a few overlapping circles: the dip at the
	# top and the dimple underneath are pressed into an ellipse, strongest at the
	# middle and fading to nothing at the sides. Built from circles, the union's
	# own bumps show through the silhouette as three lumps along the bottom —
	# which is what this drew until it was looked at rather than reasoned about.
	var points := PackedVector2Array()
	points.resize(CIRCLE_POINTS)
	for i in CIRCLE_POINTS:
		var angle := TAU * float(i) / float(CIRCLE_POINTS)
		var point := Vector2(cos(angle) * radius * 0.92, sin(angle) * radius * 0.84)
		var middle := exp(-pow(point.x / (radius * 0.42), 2.0))
		point.y += radius * (0.24 if point.y < 0.0 else -0.09) * middle
		points[i] = centre + point
	_blob(canvas, [points], Kind.APPLE, filled, centre, radius * EDGE_WIDTH_RATIO)
	if not filled:
		return
	canvas.draw_line(centre + Vector2(0.0, -radius * 0.42),
			centre + Vector2(radius * 0.1, -radius * 0.95),
			STALK_BROWN, radius * 0.12, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(radius * 0.08, -radius * 0.78),
		centre + Vector2(radius * 0.62, -radius * 0.98),
		centre + Vector2(radius * 0.66, -radius * 0.58),
	]), LEAF_GREEN)


static func _balloon(canvas: CanvasItem, centre: Vector2, radius: float, filled: bool) -> void:
	# Everything stays inside ±radius of the centre, string and all: the layout
	# guarantees that much room and no more, and a string hanging past it drew
	# itself over the caption below the box.
	var body := centre - Vector2(0.0, radius * 0.28)
	var points := PackedVector2Array()
	for i in CIRCLE_POINTS:
		var angle := TAU * float(i) / float(CIRCLE_POINTS)
		# Slightly taller than wide, the way a balloon hangs.
		points.append(body + Vector2(cos(angle) * radius * 0.60, sin(angle) * radius * 0.64))
	var knot := body + Vector2(0.0, radius * 0.64)
	_blob(canvas, [points, PackedVector2Array([
		knot + Vector2(-radius * 0.12, -radius * 0.04),
		knot + Vector2(radius * 0.12, -radius * 0.04),
		knot + Vector2(0.0, radius * 0.20),
	])], Kind.BALLOON, filled, centre, radius * EDGE_WIDTH_RATIO)
	# The string, as a slack curve rather than a straight line.
	var string := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		string.append(knot + Vector2(sin(t * PI * 1.4) * radius * 0.14,
				radius * (0.18 + t * 0.44)))
	canvas.draw_polyline(string, _edge(Kind.BALLOON, filled), radius * 0.05, true)


static func _fish(canvas: CanvasItem, centre: Vector2, radius: float, filled: bool) -> void:
	var body := PackedVector2Array()
	for i in CIRCLE_POINTS:
		var angle := TAU * float(i) / float(CIRCLE_POINTS)
		body.append(centre + Vector2(cos(angle) * radius * 0.72, sin(angle) * radius * 0.46))
	var tail := PackedVector2Array([
		centre + Vector2(-radius * 0.42, 0.0),
		centre + Vector2(-radius * 1.02, -radius * 0.62),
		centre + Vector2(-radius * 1.02, radius * 0.62),
	])
	_blob(canvas, [body, tail], Kind.FISH, filled, centre, radius * EDGE_WIDTH_RATIO)
	if filled:
		canvas.draw_circle(centre + Vector2(radius * 0.4, -radius * 0.1), radius * 0.09,
				_edge(Kind.FISH, filled))


static func _ball(canvas: CanvasItem, centre: Vector2, radius: float, filled: bool) -> void:
	_blob(canvas, [_circle(centre, radius * 0.82)], Kind.BALL, filled, centre, radius * EDGE_WIDTH_RATIO)
	if not filled:
		return
	# Two seams, so a counted ball is not just a coloured dot.
	var edge := _edge(Kind.BALL, filled)
	canvas.draw_line(centre + Vector2(-radius * 0.8, 0.0), centre + Vector2(radius * 0.8, 0.0),
			edge, radius * 0.07, true)
	var seam := PackedVector2Array()
	for i in 13:
		var t := -1.0 + 2.0 * float(i) / 12.0
		seam.append(centre + Vector2(t * radius * 0.62, sin(t * PI * 0.5) * radius * 0.62))
	canvas.draw_polyline(seam, edge, radius * 0.07, true)


static func _flower(canvas: CanvasItem, centre: Vector2, radius: float, filled: bool) -> void:
	var petals: Array[PackedVector2Array] = []
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		petals.append(_circle(centre + Vector2(cos(angle), sin(angle)) * radius * 0.52,
				radius * 0.36))
	_blob(canvas, petals, Kind.FLOWER, filled, centre, radius * EDGE_WIDTH_RATIO)
	if filled:
		canvas.draw_colored_polygon(_circle(centre, radius * 0.34), FLOWER_MIDDLE)
		_ring(canvas, centre, radius * 0.34, _edge(Kind.FLOWER, filled), radius * 0.6)


static func _leaf(canvas: CanvasItem, centre: Vector2, radius: float, filled: bool) -> void:
	# Set at an angle and given a stalk. Drawn flat and level it is a lens, and
	# six lenses in a row read as six eyes rather than six leaves.
	var axis := Vector2(0.82, -0.57)
	var across := Vector2(-axis.y, axis.x)
	var points := PackedVector2Array()
	for side in [1.0, -1.0]:
		# The second edge is walked back the other way: both in the same
		# direction would cross the shape into a bowtie.
		for i in 13:
			var step := i if side > 0.0 else 12 - i
			var t := -1.0 + 2.0 * float(step) / 12.0
			# Wider towards the stalk than the tip, the way a leaf is.
			var half := cos(t * PI * 0.5) * radius * 0.40 * (1.0 - t * 0.25)
			points.append(centre + axis * (t * radius * 0.82) + across * (half * side))
	_blob(canvas, [points], Kind.LEAF, filled, centre, radius * EDGE_WIDTH_RATIO)
	var edge := _edge(Kind.LEAF, filled)
	canvas.draw_line(centre - axis * radius * 0.82, centre - axis * radius * 1.02,
			STALK_BROWN if filled else edge, radius * 0.08, true)
	if filled:
		canvas.draw_line(centre - axis * radius * 0.74, centre + axis * radius * 0.74,
				edge, radius * 0.06, true)


# --- helpers -----------------------------------------------------------------

## Columns in the grid: ceil(sqrt(n)), which keeps 9 a 3×3 square and 6 a 3×2
## block rather than a long line nobody can count along.
static func _columns(count: int) -> int:
	return maxi(int(ceil(sqrt(float(count)))), 1)


## The square cell one object gets, sized so the whole grid fits the box.
static func _cell(count: int, box: Rect2) -> float:
	var columns := _columns(count)
	var rows := int(ceil(float(count) / float(columns)))
	return minf(box.size.x / float(columns), box.size.y / float(rows))


## Draw an object made of `parts` as one shape: every point of every part pushed
## `width` further out from the object's centre and drawn in the edge colour
## first, then every part at its real size in the fill colour on top. The pushed
## copies merge into a single silhouette, so the outline runs round the outside
## only — drawing each part's own outline is what turns an apple's two lobes into
## the ribs of a pumpkin, which is what the first version of this drew.
##
## Pushing each point out by a fixed distance rather than scaling the whole shape
## keeps the outline the same width all the way round; scaling makes it thin
## across a flat object like a leaf and fat along it. Geometry2D.offset_polygon
## would be the proper tool and is not used: at these sizes its arc tolerance
## leaves a visible ripple along every curve, and a 300 px apple with a wavy
## edge looks like a mistake rather than a drawing.
static func _blob(canvas: CanvasItem, parts: Array, kind: int, filled: bool,
		centre: Vector2, width: float) -> void:
	var edge := _edge(kind, filled)
	for part: PackedVector2Array in parts:
		var grown := PackedVector2Array()
		grown.resize(part.size())
		for i in part.size():
			var out := part[i] - centre
			var distance := out.length()
			grown[i] = part[i] + (out / distance * width if distance > 0.001 else Vector2.ZERO)
		canvas.draw_colored_polygon(grown, edge)
	var fill := _fill(kind, filled)
	for part: PackedVector2Array in parts:
		canvas.draw_colored_polygon(part, fill)


static func _circle(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(CIRCLE_POINTS)
	for i in CIRCLE_POINTS:
		var angle := TAU * float(i) / float(CIRCLE_POINTS)
		points[i] = centre + Vector2(cos(angle), sin(angle)) * radius
	return points


static func _ring(canvas: CanvasItem, centre: Vector2, radius: float, color: Color,
		scale_by: float) -> void:
	var points := _circle(centre, radius)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), color,
			scale_by * EDGE_WIDTH_RATIO, true)


static func _fill(kind: int, filled: bool) -> Color:
	return FILLS[clampi(kind, 0, FILLS.size() - 1)] if filled else EMPTY_FILL


static func _edge(kind: int, filled: bool) -> Color:
	return FILLS[clampi(kind, 0, FILLS.size() - 1)].darkened(0.35) if filled else EMPTY_LINE

