extends SceneTree
## GATE 3 test suite for the Stroke Recorder — it drives the real scene with
## synthetic touch events, so unlike the other suites it needs a display and
## cannot run headless (a small window opens for a few seconds).
##
## Run: godot --path . -w --resolution 960x640 --script tests/test_recorder.gd
## Exits 0 when every check passes, 1 otherwise.
##
## It points CharSets.stroke_dir at an empty scratch directory under user:// for
## the duration of the run, so it records into throwaway files: the real
## hand-recorded dataset is never written to, and — just as important — the
## assertions do not depend on which characters happen to be recorded yet. (An
## earlier version recorded into the real thai_consonants.json and started
## failing the moment ก was actually recorded.)
##
## Reaching into the recorder's private members is deliberate here: this suite
## stands in for the fingers a headless machine does not have.

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")

const SCRATCH_DIR := "user://test_strokes"
const TEST_SET_PATH := SCRATCH_DIR + "/thai_consonants.json"

var _rec: Node
var _real_dataset: Dictionary = {}  ## path → SHA-256, to prove we never touched it.
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
	_use_scratch_dir()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 640))
	_rec = load("res://scenes/stroke_recorder.tscn").instantiate()
	root.add_child(_rec)
	for i in 6:
		await process_frame

	await test_recording()
	await test_saving()
	await test_undo_and_reload()
	await test_replay()
	await test_navigation()

	_check_real_dataset_untouched()
	print("")
	if _failures == 0:
		print("ALL %d CHECKS PASSED" % _checks)
	else:
		print("%d/%d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func test_recording() -> void:
	print("recording by touch:")
	check(_rec._current_set_id() == "thai_consonants" and _rec._current_char() == "ก",
			"starts on the first character of the first set")
	check(_rec._box().size.is_equal_approx(Vector2(1000, 1000)), "drawing box is 1000×1000")
	# Two ก-ish strokes: the loop, then the tall arch.
	await _draw([Vector2(360, 640), Vector2(300, 560), Vector2(380, 520), Vector2(420, 600),
			Vector2(430, 900)])
	await _draw([Vector2(430, 560), Vector2(700, 470), Vector2(830, 560), Vector2(840, 900)])
	check(_rec._strokes.size() == 2, "two strokes recorded (got %d)" % _rec._strokes.size())
	var in_box := true
	for stroke: PackedVector2Array in _rec._strokes:
		for point in stroke:
			if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
				in_box = false
	check(in_box, "every point normalized inside the 0–1 box")
	check(_rec._strokes[0][0].distance_to(Vector2(0.3, 0.49)) < 0.02,
			"first point lands where the finger went down (got %s)" % _rec._strokes[0][0])
	check(_rec._unsaved, "unsaved work is flagged")

	# A tap is kept as a dot rather than dropped.
	var before: int = _rec._strokes.size()
	_send_touch(Vector2(700, 700), true)
	await process_frame
	_send_touch(Vector2(700, 700), false)
	await process_frame
	check(_rec._strokes.size() == before + 1 and _rec._strokes[-1].size() == 2,
			"a tap is stored as a two-point dot")
	_rec._on_undo()
	await process_frame

	# Touches outside the box must not start a stroke.
	before = _rec._strokes.size()
	await _draw([Vector2(1300, 400), Vector2(1500, 600)])
	check(_rec._strokes.size() == before, "touches outside the drawing box are ignored")


func test_saving() -> void:
	print("saving:")
	_rec._on_save()
	await process_frame
	var loaded: Dictionary = SD.load_set(TEST_SET_PATH)
	check(loaded.ok, "the saved file reloads (error: %s)" % loaded.get("error", ""))
	if not loaded.ok:
		return
	var entry: Dictionary = SD.find_entry(loaded.entries, "ก")
	check(not entry.is_empty(), "the file has an entry for ก")
	check(entry.get("set", "") == "thai_consonants" and entry.get("name", "") == "ก ไก่",
			"entry carries its set id and acrophony name")
	check(entry.get("strokes", []).size() == 2, "both strokes stored, in order")
	check(not _rec._unsaved, "unsaved flag cleared by saving")


func test_undo_and_reload() -> void:
	print("undo / reload:")
	_rec._on_undo()
	await process_frame
	check(_rec._strokes.size() == 1, "undo drops the last stroke")
	_rec._on_undo()
	_rec._on_undo()
	await process_frame
	check(_rec._strokes.is_empty(), "undo past the first stroke is harmless")
	_rec._on_reload()
	await process_frame
	check(_rec._strokes.size() == 2, "reload brings back the saved strokes")


func test_replay() -> void:
	print("replay:")
	_rec._on_replay()
	for i in 8:
		await process_frame
	var first: int = _rec._lines[0].points.size()
	check(first > 1 and first < _rec._screen_stroke(0).size(),
			"the first stroke grows point by point (%d of %d)" % [first, _rec._screen_stroke(0).size()])
	check(_rec._lines[1].points.is_empty(), "later strokes wait their turn")
	for i in 300:
		await process_frame
		if _rec._replay_stroke < 0:
			break
	check(_rec._replay_stroke < 0, "replay ends on its own")
	check(_rec._lines[1].points.size() > 1, "every stroke is drawn by the end")


func test_navigation() -> void:
	print("navigation and the unsaved guard:")
	_rec._on_clear()
	await process_frame
	check(_rec._strokes.is_empty() and _rec._unsaved, "clear empties the canvas and flags it")
	_rec._step_char(1)
	await process_frame
	check(_rec._current_char() == "ก", "the first nav press is blocked while work is unsaved")
	_rec._step_char(1)
	await process_frame
	check(_rec._current_char() == "ข", "pressing again moves on")
	check(_rec._strokes.is_empty(), "an unrecorded character starts empty")
	_rec._step_char(-1)
	await process_frame
	check(_rec._strokes.size() == 2, "going back loads ก's saved strokes from the file")
	_rec._step_set(1)
	await process_frame
	check(_rec._current_set_id() == "english_upper" and _rec._current_char() == "A",
			"set navigation lands on A of the next set")
	check(_rec._strokes.is_empty(), "switching sets clears the canvas")


# --- scratch dataset ---------------------------------------------------------

## Note what the real dataset looks like before redirecting away from it.
func _fingerprint_real_dataset() -> void:
	for id in CS.SET_IDS:
		var path := "%s/%s.json" % [CS.STROKE_DIR, id]
		if FileAccess.file_exists(path):
			_real_dataset[path] = FileAccess.get_sha256(path)


## Redirect every stroke path into an empty directory under user://, so the
## recorder starts from a known-blank dataset whatever has been recorded.
func _use_scratch_dir() -> void:
	var absolute := ProjectSettings.globalize_path(SCRATCH_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	var dir := DirAccess.open(SCRATCH_DIR)
	for file in dir.get_files():
		dir.remove(file)
	CS.stroke_dir = SCRATCH_DIR


func _check_real_dataset_untouched() -> void:
	CS.stroke_dir = CS.STROKE_DIR
	var intact := true
	for path: String in _real_dataset:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != _real_dataset[path]:
			intact = false
	check(intact, "the recorded dataset in %s was never touched" % CS.STROKE_DIR)


# --- synthetic touch ---------------------------------------------------------

func _draw(path: PackedVector2Array) -> void:
	var dense: PackedVector2Array = SD.resample_stroke(path, 14.0)
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
