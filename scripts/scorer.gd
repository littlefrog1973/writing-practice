class_name Scorer
extends RefCounted
## Scores a traced character against its recorded guide — Step 6.
##
## Static and pure, like dataset_validator.gd: it takes two arrays of strokes
## and returns a dictionary. No nodes, no scene, no display — which is what lets
## tests/test_scorer.gd run headless over synthetic traces.
##
## Both arrays are normalized to the same 0–1 drawing box (that is how
## tracing.gd stores the guide in _strokes and the child's ink in _traced), so
## every threshold below is a fraction of the box and the scoring is identical
## on a 960 px practice square and a 1440 px one.
##
## Three measurements per stroke:
## - **coverage** — the fraction of the guide that was actually drawn over:
##   guide points resampled at a fixed spacing, each counted when the child's
##   polyline passes within COVERAGE_TOLERANCE. This is what catches a stroke
##   that stops half way.
## - **deviation** — the mean distance from the child's points to the guide
##   polyline. This is what separates neat from wobbly.
## - **direction** — the child's stroke sampled against the guide sampled, and
##   against the guide reversed. Whichever fits better is the direction they
##   drew in. Endpoints alone would be ambiguous on a closed shape like "O".
## - **sprawl** — how far the stroke ran compared with the guide, as a
##   multiplier on the other two. Coverage and deviation between them are still
##   fooled by a scribble drawn *along* the letter: wander over a stroke for
##   long enough and every part of it has ink beside it. Nothing about that is
##   short, so length is what tells it apart from writing.
##
## Stroke *order* cannot be wrong: the trace state hands over one guide stroke
## at a time, so `traced[i]` is always the attempt at `guide[i]`. A stroke the
## child never drew (a short dataset, a cancelled character) simply scores zero
## instead of being an error.
##
## **There is no fail state.** The lowest result is one star with a cheerful
## invitation to try again — never "wrong", never a blocked "next". Thresholds
## are deliberately generous: this is a five-year-old's finger on a screen.

const SD := preload("res://scripts/stroke_data.gd")

const MAX_STARS := 3

## Distance (fraction of the box) within which the child's line counts as
## having covered a point of the guide. 0.05 of a 960 px box is ~48 px — more
## than two finger-widths of the 20 px ink, so a wobbly hand still counts,
## while a line drawn beside the guide rather than on it does not.
const COVERAGE_TOLERANCE := 0.05

## Spacing both polylines are resampled to before measuring, so the result
## depends on the shape drawn and not on how fast the finger moved (a slow
## finger produces far more raw points than a quick one).
const SAMPLE_SPACING := 0.02

## Mean deviation at or below GOOD is perfect; at or above BAD scores nothing.
## ~17 px and ~62 px respectively on a 960 px box: a careful adult hand lands
## near the first, a deliberately sloppy one between them, a scribble past the
## second. Those three are exactly what GATE 6 checks by hand.
const GOOD_DEVIATION := 0.018
const BAD_DEVIATION := 0.065

## How many times the guide's length a stroke may run to before its coverage
## starts to count for less, and where it stops counting at all. A scribble
## covers a surprising amount of the guide by accident — wander over a letter
## for long enough and every part of it has ink near it — but it does so with
## several times the ink. A wobbly line is a little longer than its guide; a
## scribble is multiples of it.
const SPRAWL_FREE := 1.6
const SPRAWL_LOST := 3.0

## Points each stroke is sampled to when deciding which way round it was drawn.
const DIRECTION_SAMPLES := 16

## The reversed reading has to fit this much better before a stroke is called
## backwards — a stroke drawn the right way but sloppily must not trip it.
const DIRECTION_MARGIN := 1.15

## A guide stroke shorter than this is a dot (the dot on an "i"), which has no
## meaningful direction and cannot be "covered" like a line.
const DOT_LENGTH := 0.02

## What a backwards stroke keeps of its quality. A penalty, not a failure: a
## beautifully drawn but reversed stroke still earns most of a star.
const DIRECTION_PENALTY := 0.45

## Coverage and neatness weigh the same — drawing the whole stroke roughly and
## drawing half of it perfectly are both two-star work.
const COVERAGE_WEIGHT := 0.5

## Quality needed for the third and second star.
const THREE_STAR := 0.80
const TWO_STAR := 0.45

## Headline and advice per star count, indexed by stars - 1. The one-star line
## is an invitation, never a verdict.
const MESSAGES: Array[String] = [
	"Good try!",
	"Well done!",
	"Beautiful writing!",
]
const HINTS: Array[String] = [
	"Watch it once more, then follow the dots from the orange ring.",
	"Nearly perfect — try to stay right on top of the dots.",
	"You followed every stroke. Ready for the next one?",
]


## Score a whole character.
##
## `guide` and `traced` are Arrays of PackedVector2Array in 0–1 box space, one
## traced stroke per guide stroke in the order they were drawn.
##
## Returns {
##   "ok": true,
##   "stars": int,               ## 1–3, never 0 — there is no fail state
##   "quality": float,           ## 0–1, the mean of the per-stroke qualities
##   "coverage": float,          ## 0–1, mean over strokes
##   "deviation": float,         ## fraction of the box, mean over strokes
##   "direction_ok": bool,       ## false if any stroke was drawn backwards
##   "message": String,          ## headline for the score card
##   "hint": String,             ## the encouraging line under it
##   "strokes": Array,           ## per-stroke dicts, see score_stroke()
## }
## or { "ok": false, "error": String } when there is nothing to score against.
static func score(guide: Array, traced: Array) -> Dictionary:
	if guide.is_empty():
		return _fail("Nothing to score: the character has no recorded strokes.")
	var strokes: Array = []
	var quality := 0.0
	var coverage := 0.0
	var deviation := 0.0
	var direction_ok := true
	for i in guide.size():
		var attempt := PackedVector2Array()
		if i < traced.size():
			attempt = traced[i]
		var result := score_stroke(guide[i], attempt)
		if not result.ok:
			return result
		strokes.append(result)
		quality += result.quality
		coverage += result.coverage
		deviation += result.deviation
		direction_ok = direction_ok and result.direction_ok
	var count := float(guide.size())
	quality /= count
	var stars := stars_for(quality)
	return {
		"ok": true,
		"stars": stars,
		"quality": quality,
		"coverage": coverage / count,
		"deviation": deviation / count,
		"direction_ok": direction_ok,
		"message": MESSAGES[stars - 1],
		"hint": HINTS[stars - 1],
		"strokes": strokes,
	}


## Score one stroke against one guide stroke. An empty `traced` is the stroke
## the child never drew: zero, but not an error.
##
## Returns { "ok": true, "coverage": float, "deviation": float,
##           "direction_ok": bool, "sprawl": float, "quality": float,
##           "drawn": bool }.
static func score_stroke(guide: PackedVector2Array,
		traced: PackedVector2Array) -> Dictionary:
	if guide.size() < 2:
		return _fail("A guide stroke needs at least 2 points, got %d." % guide.size())
	if traced.size() < 2:
		return {
			"ok": true, "coverage": 0.0, "deviation": BAD_DEVIATION,
			"direction_ok": true, "sprawl": 1.0, "quality": 0.0, "drawn": false,
		}
	var coverage := _coverage(guide, traced)
	var deviation := _deviation(guide, traced)
	var direction_ok := _direction_ok(guide, traced)
	var sprawl := _sprawl(guide, traced)
	var neatness := clampf(inverse_lerp(BAD_DEVIATION, GOOD_DEVIATION, deviation), 0.0, 1.0)
	var quality := COVERAGE_WEIGHT * coverage + (1.0 - COVERAGE_WEIGHT) * neatness
	quality *= sprawl
	if not direction_ok:
		quality *= DIRECTION_PENALTY
	return {
		"ok": true,
		"coverage": coverage,
		"deviation": deviation,
		"direction_ok": direction_ok,
		"sprawl": sprawl,
		"quality": quality,
		"drawn": true,
	}


## Stars for an overall quality, 1–3. Its own function so the score card, the
## tests and (Step 7) the progress file all agree on where the boundaries are.
static func stars_for(quality: float) -> int:
	if quality >= THREE_STAR:
		return 3
	if quality >= TWO_STAR:
		return 2
	return 1


# --- measurements ------------------------------------------------------------

## Fraction of the guide the child's line passed close to.
static func _coverage(guide: PackedVector2Array, traced: PackedVector2Array) -> float:
	var samples := _resample(guide)
	var covered := 0
	for point in samples:
		if _distance_to_polyline(point, traced) <= COVERAGE_TOLERANCE:
			covered += 1
	return float(covered) / float(samples.size())


## 1.0 for a stroke of a sensible length, falling to 0.0 for one several times
## longer than the guide. Guides shorter than a dot are exempt: a tap has no
## length to compare with.
static func _sprawl(guide: PackedVector2Array, traced: PackedVector2Array) -> float:
	var guide_length := SD.stroke_length(guide)
	if guide_length < DOT_LENGTH:
		return 1.0
	var ratio := SD.stroke_length(traced) / guide_length
	return clampf(inverse_lerp(SPRAWL_LOST, SPRAWL_FREE, ratio), 0.0, 1.0)


## Mean distance from the child's line to the guide polyline.
static func _deviation(guide: PackedVector2Array, traced: PackedVector2Array) -> float:
	var samples := _resample(traced)
	var total := 0.0
	for point in samples:
		total += _distance_to_polyline(point, guide)
	return total / float(samples.size())


## True unless the stroke fits the guide reversed clearly better than forwards.
static func _direction_ok(guide: PackedVector2Array, traced: PackedVector2Array) -> bool:
	if SD.stroke_length(guide) < DOT_LENGTH:
		return true  # A dot has no direction to get wrong.
	var g := _sample_evenly(guide, DIRECTION_SAMPLES)
	var t := _sample_evenly(traced, DIRECTION_SAMPLES)
	var forward := 0.0
	var reverse := 0.0
	for i in DIRECTION_SAMPLES:
		forward += t[i].distance_to(g[i])
		reverse += t[i].distance_to(g[DIRECTION_SAMPLES - 1 - i])
	return forward <= reverse * DIRECTION_MARGIN


# --- geometry ----------------------------------------------------------------

## Resample to SAMPLE_SPACING, keeping at least the original endpoints — a
## stroke shorter than the spacing (a dot) still has to be measurable.
static func _resample(points: PackedVector2Array) -> PackedVector2Array:
	if SD.stroke_length(points) < SAMPLE_SPACING:
		return points
	return SD.resample_stroke(points, SAMPLE_SPACING)


## `count` points spread evenly along the path, first and last included.
static func _sample_evenly(points: PackedVector2Array, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(count)
	var total := SD.stroke_length(points)
	if total <= 0.0:
		out.fill(points[0])
		return out
	var step := total / float(count - 1)
	var segment := 1
	var walked := 0.0  ## Path length up to points[segment - 1].
	for i in count:
		var target := step * float(i)
		while segment < points.size() - 1:
			var seg_len := points[segment - 1].distance_to(points[segment])
			if walked + seg_len >= target:
				break
			walked += seg_len
			segment += 1
		var from := points[segment - 1]
		var to := points[segment]
		var length := from.distance_to(to)
		var t := 0.0 if length <= 0.0 else clampf((target - walked) / length, 0.0, 1.0)
		out[i] = from.lerp(to, t)
	return out


## Shortest distance from a point to a polyline (its segments, not its points —
## a straight guide stroke stored as two far-apart points must not read as a
## miss half way along it).
static func _distance_to_polyline(point: Vector2, polyline: PackedVector2Array) -> float:
	if polyline.is_empty():
		return INF
	if polyline.size() == 1:
		return point.distance_to(polyline[0])
	var best := INF
	for i in range(1, polyline.size()):
		best = minf(best, point.distance_to(
				Geometry2D.get_closest_point_to_segment(point, polyline[i - 1], polyline[i])))
	return best


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
