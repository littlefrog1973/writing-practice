extends SceneTree
## GATE 10 test suite for the counting activity: the numeral→quantity mapping in
## scripts/char_sets.gd, the geometry and the value→object table in
## scripts/object_art.gd, the tapping in scripts/count_objects.gd, and the
## counting notes in scripts/tone_bank.gd.
##
## Run: godot --headless --path . --script tests/test_count_objects.gd
## Exits 0 when every check passes, 1 otherwise.
##
## Headless on purpose. The counting node is driven through tap_at() — the same
## call its _input() makes once it has converted a finger into control-local
## coordinates — so everything about *what counting does* is checked here
## without a screen, and the only thing left for a display is whether a finger
## reaches it, which tests/test_menus.gd covers by touch.
##
## Nothing here reads or writes data/strokes/ or the progress file: counting is
## not scored, and this step must not be able to touch either.

const CS := preload("res://scripts/char_sets.gd")
const OA := preload("res://scripts/object_art.gd")
const CO := preload("res://scripts/count_objects.gd")
const TB := preload("res://scripts/tone_bank.gd")

const BOX := Rect2(0.0, 0.0, 960.0, 800.0)  ## The real overlay's shape.

var _counted: Array[int] = []
var _finished := 0
var _failures := 0
var _checks := 0


func _init() -> void:
	_main()


func check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  %s" % name)
	else:
		_failures += 1
		print("  FAIL  %s" % name)


func _main() -> void:
	await process_frame
	test_values()
	test_kinds()
	test_layout()
	await test_counting()
	await test_zero()
	await test_taps_that_miss()
	test_tones()
	print("")
	if _failures == 0:
		print("ALL %d CHECKS PASSED" % _checks)
	else:
		print("%d/%d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func test_values() -> void:
	print("what a character is worth:")
	var digits_ok := true
	var thai_ok := true
	for value in 10:
		if CS.value_of("digits", CS.chars_of("digits")[value]) != value:
			digits_ok = false
		if CS.value_of("thai_numerals", CS.chars_of("thai_numerals")[value]) != value:
			thai_ok = false
	check(digits_ok, "every digit 0–9 is worth its own value")
	check(thai_ok, "and so is every Thai numeral ๐–๙")
	check(CS.value_of("digits", "3") == CS.value_of("thai_numerals", "๓"),
			"๓ and 3 are the same quantity — the reason both sets count")
	check(CS.is_numeric("digits") and CS.is_numeric("thai_numerals"),
			"both number sets are marked numeric")
	for id in ["thai_consonants", "english_upper", "english_lower", "thai_vowels"]:
		check(not CS.is_numeric(id) and CS.value_of(id, CS.chars_of(id)[0]) == -1,
				"%s has no quantities — it opens straight into the demo" % id)
	check(CS.value_of("digits", "A") == -1, "a character not in the set is worth nothing")
	check(CS.value_of("nope", "3") == -1, "nor is one from a set that does not exist")
	check(CS.numeral_value("๙") == 9 and CS.numeral_value("9") == 9,
			"a numeral is read from its code point, not its place in a list")
	check(CS.numeral_value("ก") == -1 and CS.numeral_value("") == -1,
			"and anything else is not a numeral at all")
	check(CS.validate().ok, "the catalog still validates with the numeric rule in it")


func test_kinds() -> void:
	print("which objects stand for which number:")
	var same := true
	for value in range(1, 10):
		if OA.kind_for_value(value) != OA.kind_for_value(value):
			same = false
	check(same, "the value→object table is fixed, not random")
	check(OA.kind_for_value(3) == OA.VALUE_KINDS[3] and OA.kind_for_value(7) == OA.VALUE_KINDS[7],
			"three is always the same thing, and so is seven")
	check(OA.kind_for_value(0) == OA.KIND_NONE, "zero has no object — it has a basket")
	check(OA.kind_for_value(-1) == OA.KIND_NONE and OA.kind_for_value(99) == OA.KIND_NONE,
			"and a value outside 0–9 has none either")
	var kinds: Dictionary = {}
	for value in range(1, 10):
		var kind := OA.kind_for_value(value)
		check(kind >= 0 and kind < OA.FILLS.size(), "%d has an object that can be drawn" % value)
		kinds[kind] = true
	check(kinds.size() >= 4, "with enough different objects that the numbers do not blur together")


func test_layout() -> void:
	print("where the objects sit:")
	for count in range(1, 10):
		var centres := OA.layout(count, BOX)
		var radius := OA.radius_for(count, BOX)
		var inside := true
		for centre in centres:
			if not BOX.has_point(centre) \
					or centre.x - radius < BOX.position.x - 0.01 \
					or centre.x + radius > BOX.end.x + 0.01 \
					or centre.y - radius < BOX.position.y - 0.01 \
					or centre.y + radius > BOX.end.y + 0.01:
				inside = false
		var apart := true
		for i in centres.size():
			for j in range(i + 1, centres.size()):
				# Clear of each other, so no tap is ambiguous between two of them.
				if centres[i].distance_to(centres[j]) < radius * 2.0:
					apart = false
		check(centres.size() == count, "%d objects get %d places" % [count, centres.size()])
		check(inside, "all %d inside the box, whole" % count)
		check(apart, "and none of the %d overlapping another (r=%.0f)" % [count, radius])
	check(OA.layout(0, BOX).is_empty(), "zero has no objects to place")
	# A finger, not a mouse pointer: nine objects is the tightest case there is.
	check(OA.radius_for(9, BOX) > 60.0,
			"even nine of them are a comfortable finger target (r=%.0f)"
			% OA.radius_for(9, BOX))


func test_counting() -> void:
	print("counting three of them:")
	var node := _make_node()
	node.set_count(3)
	check(node.centres().size() == 3, "three objects are laid out")
	check(node.counted_so_far() == 0, "none counted before it is touched")

	var centres: PackedVector2Array = node.centres()
	# Tapped out of order on purpose: a child counting a set may start anywhere,
	# and being told "wrong one" would be teaching obedience, not number.
	for i in [2, 0, 1]:
		node.tap_at(centres[i])
	check(_counted == [1, 2, 3], "each tap counts one more, in order (got %s)" % str(_counted))
	check(node.counted_so_far() == 3, "and the node agrees three are counted")

	node.tap_at(centres[1])
	check(_counted.size() == 3, "counting the same object again counts nothing")

	check(_finished == 0, "the last object is still landing")
	await _until(func() -> bool: return _finished > 0, 3.0)
	check(_finished == 1, "then the counting finishes, exactly once (got %d)" % _finished)
	await _wait(0.8)
	check(_finished == 1, "and stays finished")
	node.free()


func test_zero() -> void:
	print("zero:")
	var node := _make_node()
	node.set_count(0)
	check(node.centres().is_empty(), "an empty basket has nothing in it")
	check(_finished == 0, "and does not finish by itself — zero is an answer, not a skip")
	node.tap_at(Vector2(120.0, 300.0))
	check(_counted == [0], "one tap anywhere is the child's answer (got %s)" % str(_counted))
	await _until(func() -> bool: return _finished > 0, 3.0)
	check(_finished == 1, "and moves on to writing the numeral")
	node.free()


func test_taps_that_miss() -> void:
	print("taps that miss:")
	var node := _make_node()
	node.set_count(4)
	var centres: PackedVector2Array = node.centres()
	var radius: float = node.radius()
	check(node.tap_at(Vector2(-500.0, -500.0)) == -1, "a tap far outside counts nothing")
	check(node.tap_at(centres[0] + Vector2(radius * 4.0, 0.0)) == -1,
			"and so does one in the space between objects")
	check(_counted.is_empty(), "nothing has been counted (got %s)" % str(_counted))
	check(node.tap_at(centres[0]) == 0, "a tap on an object counts it")
	check(node.tap_at(centres[0]) == -1, "the second tap on it does not")
	check(node.tap_at(centres[0] + Vector2(radius * 0.9, 0.0)) == -1,
			"a near miss on a counted object is not the one next to it either")
	check(_counted == [1], "so exactly one object is counted (got %s)" % str(_counted))
	node.free()


func test_tones() -> void:
	print("the counting notes:")
	var streams: Array = []
	for i in TB.COUNT_FREQS.size():
		streams.append(TB.count_tone(i))
	check(streams.size() == 9, "nine notes, one per object")
	var all_sound := true
	for stream in streams:
		if stream == null or stream.data.size() < 1000:
			all_sound = false
	check(all_sound, "every one is a real stream with samples in it")
	check(TB.COUNT_FREQS[0] < TB.COUNT_FREQS[8],
			"and the pitch climbs with the count, the way counting aloud does")
	check(streams[0].data != streams[8].data, "the first and the ninth are different notes")
	check(TB.count_tone(99).data.size() > 0, "an index past the scale still rings something")


# --- helpers -----------------------------------------------------------------

func _make_node() -> Control:
	_counted.clear()
	_finished = 0
	var node: Control = CO.new()
	node.size = BOX.size
	root.add_child(node)
	node.counted.connect(func(count: int) -> void: _counted.append(count))
	node.finished.connect(func() -> void: _finished += 1)
	return node


## Wait until `cond` is true, or `seconds` have passed. Frames, never a fixed
## count of them: this suite runs unthrottled and a frame is not a unit of time.
func _until(cond: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _wait(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)
