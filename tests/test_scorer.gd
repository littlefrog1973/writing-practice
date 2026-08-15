extends SceneTree
## GATE 6 test suite for the pure half of the score screen: scripts/scorer.gd
## and the synthesized sounds in scripts/tone_bank.gd. Both are static and
## touch no node, so this runs headless.
##
## Run: godot --headless --path . --script tests/test_scorer.gd
## Exits 0 when every check passes, 1 otherwise.
##
## The traces here are synthetic and deterministic — an exact trace, a wobbly
## one, a sloppy-but-on-letter one, a backwards stroke, a half-drawn stroke and
## a scribble — because the real question is not "what does this trace score"
## but "do a careful hand and a scribble land where GATE 6 says they should".
## Nothing here reads the recorded dataset, so Step 8 cannot rot it.

const SC := preload("res://scripts/scorer.gd")
const TB := preload("res://scripts/tone_bank.gd")

## An "L": down, then across. Two strokes, in the order a child writes them.
const DOWN_FROM := Vector2(0.3, 0.2)
const DOWN_TO := Vector2(0.3, 0.8)
const ACROSS_TO := Vector2(0.75, 0.8)

var failures := 0
var checks := 0


func _init() -> void:
	test_perfect_trace()
	test_wobbly_trace()
	test_sloppy_trace()
	test_scribble()
	test_backwards_stroke()
	test_unfinished_and_missing_strokes()
	test_dots_and_bad_input()
	test_thresholds_and_determinism()
	test_sounds()
	print("")
	if failures == 0:
		print("ALL %d CHECKS PASSED" % checks)
	else:
		print("%d/%d CHECKS FAILED" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  PASS  %s" % name)
	else:
		failures += 1
		print("  FAIL  %s" % name)


func test_perfect_trace() -> void:
	print("an exact trace:")
	var result: Dictionary = SC.score(guide(), guide())
	check(result.ok, "scores without error")
	check(result.stars == 3, "earns three stars (got %d)" % result.stars)
	check(is_equal_approx(result.coverage, 1.0),
			"covers the whole guide (%.2f)" % result.coverage)
	check(result.deviation < 0.001, "deviates by nothing (%.4f)" % result.deviation)
	check(result.direction_ok, "is drawn the right way round")
	check(result.strokes.size() == 2, "reports one result per guide stroke")
	check(not result.message.is_empty() and not result.hint.is_empty(),
			"comes with something to say")


func test_wobbly_trace() -> void:
	print("a careful but wobbly trace (a real hand):")
	var traced: Array = []
	for stroke in guide():
		traced.append(wobble(stroke, 0.012, 3.0))
	var result: Dictionary = SC.score(guide(), traced)
	check(result.stars == 3,
			"still earns three stars — the tolerances are child-sized (got %d, quality %.2f)"
			% [result.stars, result.quality])
	check(result.deviation > 0.0, "but is measurably off the guide (%.3f)" % result.deviation)


func test_sloppy_trace() -> void:
	print("a sloppy but on-letter trace:")
	var traced: Array = []
	for stroke in guide():
		traced.append(wobble(shorten(stroke, 0.88), 0.07, 2.0))
	var result: Dictionary = SC.score(guide(), traced)
	check(result.stars >= 1 and result.stars <= 2,
			"scores one or two stars, never three (got %d, quality %.2f)"
			% [result.stars, result.quality])
	check(result.coverage < 1.0, "misses part of the guide (%.2f)" % result.coverage)
	check(result.direction_ok, "is still recognisably drawn the right way round")


func test_scribble() -> void:
	print("a scribble:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816
	var traced: Array = []
	for stroke in guide():
		var scribble := PackedVector2Array()
		for i in 40:
			scribble.append(Vector2(rng.randf(), rng.randf()))
		traced.append(scribble)
	var result: Dictionary = SC.score(guide(), traced)
	check(result.stars == 1, "scores one star (got %d, quality %.2f)"
			% [result.stars, result.quality])
	check(result.message == SC.MESSAGES[0] and result.hint == SC.HINTS[0],
			"with encouragement to try again, not a failure: \"%s %s\""
			% [result.message, result.hint])
	check(result.stars >= 1, "there is no zero-star result — no fail state")

	# Scribbling back and forth *along* the guide is the case coverage alone
	# cannot see: every part of the guide has ink beside it, drawn with five
	# times the line.
	var zigzag: Dictionary = SC.score_stroke(guide()[0], wobble(guide()[0], 0.04, 14.0))
	check(zigzag.coverage > 0.8 and zigzag.sprawl < 0.2,
			"scribbling along a stroke covers it (%.2f) with far too much line (%.2f)"
			% [zigzag.coverage, zigzag.sprawl])
	check(zigzag.quality < SC.TWO_STAR, "so it does not earn a second star (%.2f)"
			% zigzag.quality)


func test_backwards_stroke() -> void:
	print("a stroke drawn backwards:")
	var traced: Array = [reverse(guide()[0]), guide()[1]]
	var result: Dictionary = SC.score(guide(), traced)
	check(not result.direction_ok, "is noticed")
	check(not result.strokes[0].direction_ok and result.strokes[1].direction_ok,
			"and blamed on the stroke that was reversed, not the character")
	check(result.strokes[0].coverage > 0.9,
			"even though its shape is perfect (coverage %.2f)" % result.strokes[0].coverage)
	check(result.stars < 3, "so it costs a star (got %d)" % result.stars)
	check(result.stars >= 1, "but is still not a failure")
	# A closed shape has no unambiguous direction from its endpoints alone; the
	# sampled comparison is what tells the two readings apart.
	var circle := ring(false)
	check(SC.score([circle], [ring(true)]).direction_ok == false,
			"a circle traced anticlockwise instead of clockwise is caught too")
	check(SC.score([circle], [circle]).direction_ok,
			"and the same circle traced the right way is not")


func test_unfinished_and_missing_strokes() -> void:
	print("strokes that were not finished:")
	var half: Dictionary = SC.score_stroke(guide()[0], shorten(guide()[0], 0.5))
	check(half.ok and half.coverage > 0.4 and half.coverage < 0.65,
			"half a stroke covers about half the guide (%.2f)" % half.coverage)
	check(half.deviation < 0.01, "and what was drawn is still neat (%.4f)" % half.deviation)

	var missing: Dictionary = SC.score(guide(), [guide()[0]])
	check(missing.ok, "a character with a stroke missing still scores")
	check(not missing.strokes[1].drawn and missing.strokes[1].quality == 0.0,
			"the stroke that was never drawn scores nothing")
	check(missing.stars < 3, "which costs stars (got %d)" % missing.stars)


func test_dots_and_bad_input() -> void:
	print("dots and malformed input:")
	var dot := PackedVector2Array([Vector2(0.5, 0.2), Vector2(0.503, 0.203)])
	var tap := PackedVector2Array([Vector2(0.505, 0.205), Vector2(0.506, 0.206)])
	var dotted: Dictionary = SC.score_stroke(dot, tap)
	check(dotted.ok and dotted.direction_ok,
			"a dot has no direction to get wrong (the dot on an \"i\")")
	check(dotted.quality > 0.9, "and a tap on it is a good dot (%.2f)" % dotted.quality)

	var far: Dictionary = SC.score_stroke(dot, PackedVector2Array(
			[Vector2(0.9, 0.9), Vector2(0.903, 0.903)]))
	check(far.quality < 0.2, "a tap in the wrong place is not (%.2f)" % far.quality)

	check(not SC.score([], []).ok, "an unrecorded character is an error, not a score")
	check(not SC.score([PackedVector2Array([Vector2(0.5, 0.5)])], []).ok,
			"a one-point guide stroke is an error")
	check(SC.score(guide(), []).ok, "but a character nobody traced simply scores badly")
	check(SC.score(guide(), []).stars == 1, "one star, and an invitation to try")


func test_thresholds_and_determinism() -> void:
	print("thresholds:")
	check(SC.stars_for(1.0) == 3 and SC.stars_for(SC.THREE_STAR) == 3,
			"quality at or above %.2f is three stars" % SC.THREE_STAR)
	check(SC.stars_for(SC.THREE_STAR - 0.001) == 2 and SC.stars_for(SC.TWO_STAR) == 2,
			"between %.2f and %.2f is two" % [SC.TWO_STAR, SC.THREE_STAR])
	check(SC.stars_for(SC.TWO_STAR - 0.001) == 1 and SC.stars_for(0.0) == 1,
			"and anything below %.2f is one — never none" % SC.TWO_STAR)
	check(SC.MESSAGES.size() == SC.MAX_STARS and SC.HINTS.size() == SC.MAX_STARS,
			"there is a message and a hint for every star count")

	var traced: Array = [wobble(guide()[0], 0.03, 5.0), guide()[1]]
	var first: Dictionary = SC.score(guide(), traced)
	var second: Dictionary = SC.score(guide(), traced)
	check(is_equal_approx(first.quality, second.quality) and first.stars == second.stars,
			"the same trace always scores the same — nothing random in here")


func test_sounds() -> void:
	print("the synthesized sounds:")
	for i in SC.MAX_STARS:
		var tone: AudioStreamWAV = TB.star_tone(i)
		check(tone.format == AudioStreamWAV.FORMAT_16_BITS and not tone.stereo
				and tone.mix_rate == TB.MIX_RATE,
				"star note %d is 16-bit mono at %d Hz" % [i + 1, TB.MIX_RATE])
		check(tone.get_length() > 0.5, "and lasts %.2f s" % tone.get_length())
		check(absf(peak(tone) - TB.PEAK) < 0.02,
				"and is normalized to about %.2f (got %.2f)" % [TB.PEAK, peak(tone)])
	for stars in range(1, SC.MAX_STARS + 1):
		var fanfare: AudioStreamWAV = TB.fanfare(stars)
		check(fanfare.get_length() > 1.0, "the %d-star flourish is a phrase, not a beep" % stars)
		check(peak(fanfare) > 0.5, "and is audible (peak %.2f)" % peak(fanfare))
	var bell: AudioStreamWAV = TB.star_tone(0)
	check(absf(sample(bell, 0)) < 0.05, "a note starts from silence — no click")
	check(absf(sample(bell, sample_count(bell) - 1)) < 0.05, "and decays away to silence")


# --- synthetic strokes -------------------------------------------------------

func guide() -> Array:
	return [line(DOWN_FROM, DOWN_TO), line(DOWN_TO, ACROSS_TO)]


func line(from: Vector2, to: Vector2, count: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(from.lerp(to, float(i) / float(count - 1)))
	return points


## The first `fraction` of a stroke — a stroke the child stopped drawing early.
func shorten(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var keep := maxi(int(points.size() * fraction), 2)
	return points.slice(0, keep)


## Push the stroke sideways along a sine wave: a hand that follows the shape but
## not the line. Deterministic, so a failure here is always reproducible.
func wobble(points: PackedVector2Array, amount: float, waves: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var t := float(i) / float(points.size() - 1)
		var ahead: Vector2 = points[mini(i + 1, points.size() - 1)]
		var behind: Vector2 = points[maxi(i - 1, 0)]
		var side := (ahead - behind).orthogonal().normalized()
		out.append(points[i] + side * amount * sin(t * waves * TAU))
	return out


func reverse(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.reverse()
	return out


## A closed circle, clockwise or anticlockwise from the same start point.
func ring(anticlockwise: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		if anticlockwise:
			angle = -angle
		points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.25)
	return points


# --- reading the generated audio ---------------------------------------------

func sample_count(stream: AudioStreamWAV) -> int:
	return stream.data.size() / 2


func sample(stream: AudioStreamWAV, index: int) -> float:
	return stream.data.decode_s16(index * 2) / 32767.0


func peak(stream: AudioStreamWAV) -> float:
	var loudest := 0.0
	for i in sample_count(stream):
		loudest = maxf(loudest, absf(sample(stream, i)))
	return loudest
