extends SceneTree
## GATE 5 test suite for the tracing scene — it drives the real scene with
## synthetic touch events, so like the recorder suite it needs a display and
## cannot run headless (a small window opens for a few seconds).
##
## Run: godot --path . -w --resolution 960x640 --script tests/test_tracing.gd
## Exits 0 when every check passes, 1 otherwise.
##
## It points CharSets.stroke_dir at a scratch directory under user:// and writes
## its own two-character file there, so the hand-recorded dataset in
## res://data/strokes is never read, never written, and — just as important —
## never able to break these assertions when Step 8 re-records a character.
##
## Reaching into the scene's private members is deliberate here: this suite
## stands in for the fingers a build machine does not have.

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const TR := preload("res://scripts/tracing.gd")
const SC := preload("res://scripts/scorer.gd")

const SCRATCH_DIR := "user://test_tracing_strokes"
const TEST_SET := "thai_consonants"

## The two characters this suite invents — the first two of the set, as straight
## lines a synthetic finger can follow exactly. The third is left unrecorded on
## purpose, to check the scene copes with a character that has no strokes.
const TRACED_CHAR := "ก"
const NEXT_CHAR := "ข"
const UNRECORDED_CHAR := "ฃ"

var _tr: Node
var _real_dataset: Dictionary = {}  ## path → SHA-256, to prove we never touched it.
var _awarded: Array = []  ## Every `scored` signal the scene has emitted.
var _pops: Array = []  ## Every star that has landed on the card.
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
	_fingerprint_real_dataset()
	_write_scratch_dataset()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 640))
	# The suite spends most of its time awaiting frames, and a test window the
	# compositor considers hidden is throttled hard. Nothing here is timed
	# against the wall clock, so let the frames run as fast as they like.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_tr = load("res://scenes/tracing.tscn").instantiate()
	root.add_child(_tr)
	for i in 6:
		await process_frame

	await test_opening_demo()
	await test_trace_first_stroke()
	await test_watch_again_keeps_progress()
	await test_score_card()
	await test_again_and_scribble()
	await test_score_and_next()
	await test_unrecorded_character()

	_check_real_dataset_untouched()
	print("")
	if _failures == 0:
		print("ALL %d CHECKS PASSED" % _checks)
	else:
		print("%d/%d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func test_opening_demo() -> void:
	print("the demo:")
	check(_tr._current_set_id() == TEST_SET and _tr._current_char() == TRACED_CHAR,
			"opens on the first character of the first set")
	var box: Rect2 = _tr._box()
	check(is_equal_approx(box.size.x, box.size.y),
			"the drawing box is square, like the recorder's (got %s)" % box.size)
	check(_tr._state == TR.State.DEMO, "it starts by demonstrating the character")

	for i in 8:
		await process_frame
	# Measured along the path, not in points: these test strokes are straight
	# lines of two points, so a partial one has the same point count as a whole.
	var drawn := SD.stroke_length(_tr._demo._lines[0].points)
	var total := SD.stroke_length(_tr._screen_stroke(0))
	check(drawn > 0.0 and drawn < total,
			"the first stroke grows along its path (%.0f of %.0f px)" % [drawn, total])
	check(_tr._demo._lines[1].points.is_empty(), "later strokes wait their turn")
	check(_tr._demo._numbers[0].visible and not _tr._demo._numbers[1].visible,
			"the stroke number appears with its stroke")

	# From here on the demo is run fast — the assertions are about what it does,
	# not how long a child watches it for.
	_tr._demo.speed = 9000.0
	_tr._demo.pause = 0.05
	var second_max := 0.0
	var deadline := Time.get_ticks_msec() + 6000
	while _tr._state == TR.State.DEMO and Time.get_ticks_msec() < deadline:
		await process_frame
		second_max = maxf(second_max, SD.stroke_length(_tr._demo._lines[1].points))
	check(_tr._state == TR.State.TRACE, "the demo ends on its own and hands over to tracing")
	check(is_equal_approx(second_max, SD.stroke_length(_tr._screen_stroke(1))),
			"every stroke is drawn to its end (%.0f px)" % second_max)


func test_trace_first_stroke() -> void:
	print("tracing a stroke:")
	check(_tr._stroke_index == 0, "tracing starts at the first stroke")
	var guide: PackedVector2Array = _tr._screen_stroke(0)
	check(_tr._dotted._points.size() > 1
			and _tr._dotted._points[0].is_equal_approx(guide[0]),
			"the dotted guide shows the stroke to trace, from its start point")
	check(not _tr._guide_lines[0].visible and _tr._guide_lines[1].visible,
			"the current stroke is dotted; the ones still to come stay dimmed")

	# A stray tap is not a stroke: it must not advance anything.
	_send_touch(guide[0], true)
	await process_frame
	_send_touch(guide[0], false)
	await process_frame
	check(_tr._stroke_index == 0 and _tr._traced.is_empty(),
			"a stray tap does not advance the stroke")

	# Nor does anything drawn outside the box.
	await _draw([Vector2(1300, 400), Vector2(1500, 700)])
	check(_tr._traced.is_empty(), "touches outside the drawing box are ignored")

	await _draw(guide)
	check(_tr._stroke_index == 1, "finishing a stroke advances to the next one")
	check(_tr._traced.size() == 1 and _tr._ink_lines.size() == 1,
			"the child's ink is kept as a stroke of its own")
	var in_box := true
	for point in _tr._traced[0]:
		if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
			in_box = false
	check(in_box, "the ink is normalized inside the 0–1 box")
	check(_tr._dotted._points[0].is_equal_approx(_tr._screen_stroke(1)[0]),
			"the dotted guide moves on to the second stroke")


func test_watch_again_keeps_progress() -> void:
	print("watch again:")
	_tr._on_watch_again()
	await process_frame
	check(_tr._state == TR.State.DEMO, "\"watch again\" replays the demo")
	await _until(func() -> bool: return _tr._state != TR.State.DEMO, 6.0)
	check(_tr._state == TR.State.TRACE, "and comes back to tracing")
	check(_tr._stroke_index == 1 and _tr._traced.size() == 1,
			"the strokes traced so far survive the replay")


func test_score_card() -> void:
	print("finishing the character:")
	_tr.scored.connect(func(set_id: String, chr: String, stars: int) -> void:
			_awarded.append([set_id, chr, stars]))
	_tr._score_stars.star_popped.connect(func(index: int) -> void: _pops.append(index))

	await _draw(_tr._screen_stroke(1))
	check(_tr._state == TR.State.SCORE, "the last stroke reaches the score state")
	check(_tr._score_overlay.visible, "the score card is shown")
	check(_tr._traced.size() == 2, "both traced strokes are kept for the scorer")
	check(_tr._stars == 3, "a trace right on the guide earns three stars (got %d)"
			% _tr._stars)
	check(_tr._score_message.text == SC.MESSAGES[2]
			and _tr._score_hint.text == SC.HINTS[2],
			"with the scorer's own words on the card")
	check(_tr._score_stars._stars == 3 and _tr._score_stars._total == SC.MAX_STARS,
			"the star row shows three of three")
	check(_tr._confetti.emitting, "the confetti is thrown")
	check(_tr._fanfare_player.stream != null and _tr._star_players[0].stream != null,
			"the sounds are ready to play")
	check(_awarded.size() == 1 and _awarded[0] == [TEST_SET, TRACED_CHAR, 3],
			"and the scene reports the result for Step 7's progress file")

	# The stars land one at a time, each ringing its own note.
	await _until(func() -> bool: return _pops.size() >= 3, 4.0)
	check(_pops == [0, 1, 2], "the three stars pop in, in order (got %s)" % str(_pops))


func test_again_and_scribble() -> void:
	print("\"again\", and a scribble:")
	_button("Again").pressed.emit()
	await process_frame
	check(_tr._state == TR.State.TRACE and _tr._stroke_index == 0
			and _tr._traced.is_empty() and _tr._ink_lines.is_empty(),
			"\"again\" wipes the ink and starts the character over")
	check(not _tr._score_overlay.visible, "and takes the card away")
	check(not _tr._star_players[0].playing and not _tr._fanfare_player.playing,
			"the celebration stops when the child moves on")

	var pops_before := _pops.size()
	for i in 2:
		await _draw(_scribble(), 90.0)
	check(_tr._state == TR.State.SCORE,
			"a scribble still finishes the character — there is no fail state")
	check(_tr._stars == 1, "and scores one star (got %d)" % _tr._stars)
	check(_tr._score_message.text == SC.MESSAGES[0]
			and _tr._score_hint.text == SC.HINTS[0],
			"with an invitation to try again rather than a verdict")
	check(_tr._confetti.emitting, "the celebration plays anyway — one star is not a failure")
	await _until(func() -> bool: return _pops.size() > pops_before, 2.0)
	check(_pops.size() == pops_before + 1, "one star pops, not three")


func test_score_and_next() -> void:
	print("moving on:")
	_button("Next").pressed.emit()
	await process_frame
	check(_tr._current_char() == NEXT_CHAR, "\"next\" moves on to the next character")
	check(_tr._state == TR.State.DEMO, "which starts with its own demo")
	check(_tr._traced.is_empty() and _tr._ink_lines.is_empty() and _tr._stroke_index == 0,
			"the canvas is wiped for the new character")
	check(not _tr._score_overlay.visible, "the score card is dismissed")
	check(_tr._stars == 0, "and the stars go with it")


func test_unrecorded_character() -> void:
	print("characters with no strokes yet:")
	_tr._step_char(1)
	await process_frame
	check(_tr._current_char() == UNRECORDED_CHAR and _tr._state == TR.State.EMPTY,
			"an unrecorded character is handled instead of crashing")
	await _draw([Vector2(300, 400), Vector2(600, 700)])
	check(_tr._traced.is_empty(), "and cannot be traced")
	_tr.open(TEST_SET, TRACED_CHAR)
	await process_frame
	check(_tr._current_char() == TRACED_CHAR and _tr._state == TR.State.DEMO,
			"open() jumps straight to a character, as the Step 7 menu will")


# --- scratch dataset ---------------------------------------------------------

## Note what the real dataset looks like before redirecting away from it.
func _fingerprint_real_dataset() -> void:
	for id in CS.SET_IDS:
		var path := "%s/%s.json" % [CS.STROKE_DIR, id]
		if FileAccess.file_exists(path):
			_real_dataset[path] = FileAccess.get_sha256(path)


## Write a throwaway two-character file into an empty directory under user://,
## so what the scene traces is fixed by this suite rather than by whatever the
## dataset happens to contain.
func _write_scratch_dataset() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	var dir := DirAccess.open(SCRATCH_DIR)
	for file in dir.get_files():
		dir.remove(file)
	CS.stroke_dir = SCRATCH_DIR
	var entries: Array = [
		SD.make_entry(TRACED_CHAR, TEST_SET, CS.name_of(TEST_SET, TRACED_CHAR), [
			PackedVector2Array([Vector2(0.25, 0.25), Vector2(0.25, 0.75)]),
			PackedVector2Array([Vector2(0.35, 0.3), Vector2(0.8, 0.3), Vector2(0.8, 0.75)]),
		]),
		SD.make_entry(NEXT_CHAR, TEST_SET, CS.name_of(TEST_SET, NEXT_CHAR), [
			PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.7, 0.7)]),
		]),
	]
	var result: Dictionary = SD.save_set(CS.path_of(TEST_SET), entries)
	if not result.ok:
		push_error("[test_tracing] cannot write the scratch dataset: %s" % result.error)


func _check_real_dataset_untouched() -> void:
	CS.stroke_dir = CS.STROKE_DIR
	var intact := true
	for path: String in _real_dataset:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != _real_dataset[path]:
			intact = false
	check(intact, "the recorded dataset in %s was never touched" % CS.STROKE_DIR)


# --- synthetic touch ---------------------------------------------------------

## Await frames until `condition` holds, giving up after `seconds`. Frames are
## not a unit of time here — vsync is off, so a fixed count of them can pass in
## a blink or take a second, and anything the scene does on a clock (the demo,
## the stars landing) has to be waited for in seconds.
func _until(condition: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not condition.call():
		await process_frame


## A button on the score card, by name — pressed through its own signal, so the
## wiring in the scene is part of what is being tested.
func _button(name: String) -> Button:
	return _tr.get_node("ScoreOverlay/Card/Margin/VBox/Buttons/%s" % name)


## A stroke that is not writing: corner to corner across the box, several times
## the length of anything in the character.
func _scribble() -> PackedVector2Array:
	var box: Rect2 = _tr._box()
	var path := PackedVector2Array()
	for point in [Vector2(0.15, 0.85), Vector2(0.85, 0.2), Vector2(0.2, 0.35),
			Vector2(0.9, 0.9), Vector2(0.1, 0.6)]:
		path.append(box.position + box.size * point)
	return path


func _draw(path: PackedVector2Array, spacing: float = 14.0) -> void:
	var dense: PackedVector2Array = SD.resample_stroke(path, spacing)
	_send_touch(dense[0], true)
	await process_frame
	for i in range(1, dense.size()):
		_send_drag(dense[i - 1], dense[i])
		await process_frame
	_send_touch(dense[-1], false)
	await process_frame


func _send_touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = _to_window(position)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_drag(from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _to_window(to)
	event.relative = _to_window(to) - _to_window(from)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Base-resolution point → the window coordinates an OS touch would carry.
func _to_window(point: Vector2) -> Vector2:
	return root.get_final_transform() * point
