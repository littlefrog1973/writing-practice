extends SceneTree
## GATE 7 test suite for the menus: main menu → character select → tracing →
## back, plus the stars surviving a restart. It drives the real scenes with
## synthetic touch events, so like the recorder and tracing suites it needs a
## display and cannot run headless (a small window opens for a few seconds).
##
## Run: godot --path . -w --resolution 960x640 --script tests/test_menus.gd
## Exits 0 when every check passes, 1 otherwise.
##
## **Every button here is pressed by touch**, never by emitting `pressed` and
## never with a key — that is the whole of GATE 7. A button that is off-screen,
## behind something, or too small for a finger fails these checks the way it
## would fail a five-year-old.
##
## It redirects both files it touches: CharSets.stroke_dir to a scratch
## directory (as the recorder and tracing suites do) and Progress.path to a
## scratch progress file, then checks the real dataset's SHA-256s and the real
## user://progress.json afterwards. The second matters more than the first —
## the stars in that file are the only thing here nobody can regenerate.

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const PR := preload("res://scripts/progress.gd")
const SC := preload("res://scripts/scorer.gd")
const SNS := preload("res://scripts/screens.gd")
const TR := preload("res://scripts/tracing.gd")

const SCRATCH_DIR := "user://test_menus_strokes"
const SCRATCH_PROGRESS := "user://test_menus/progress.json"

const TEST_SET := "digits"
const OTHER_SET := "thai_consonants"
## In the catalog since Step 8, but with no stroke file in the scratch dataset —
## the state every set is in between being catalogued and being recorded.
const UNRECORDED_SET := "thai_vowels"
const TRACED_CHAR := "1"
const SECOND_CHAR := "2"
const UNRECORDED_CHAR := "3"

var _real_dataset: Dictionary = {}  ## path → SHA-256, to prove we never touched it.
var _real_progress := ""
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
	_fingerprint_real_files()
	_write_scratch_dataset()
	PR.path = SCRATCH_PROGRESS
	_remove_scratch_progress()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 640))
	# As in test_tracing: a window the compositor thinks is hidden is throttled
	# to a few frames a second, and nothing here is timed against the clock.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	SNS.go_menu(self)
	await _wait_for("MainMenu")

	await test_main_menu()
	await test_character_grid()
	await test_opening_a_character()
	await test_stars_are_kept()
	await test_back_to_the_grid()
	await test_back_to_the_menu()
	await test_a_worse_attempt()
	await test_a_set_not_recorded_yet()

	CS.stroke_dir = CS.STROKE_DIR
	PR.path = PR.DEFAULT_PATH
	test_real_files_untouched()
	print("")
	if _failures == 0:
		print("ALL %d CHECKS PASSED" % _checks)
	else:
		print("%d/%d CHECKS FAILED" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func test_main_menu() -> void:
	print("the main menu:")
	var grid: GridContainer = current_scene.get_node("Grid")
	check(grid.get_child_count() == CS.SET_IDS.size(),
			"one button per set in the catalog (got %d)" % grid.get_child_count())
	var digits := _set_button(TEST_SET)
	check(digits != null and not digits.disabled, "a set with characters can be opened")
	check(_text_of(digits).contains(CS.label_of(TEST_SET)),
			"and says which set it is")
	check(_text_of(digits).contains(TRACED_CHAR),
			"showing one of its own characters")
	var vowels := _set_button(UNRECORDED_SET)
	check(vowels != null and not vowels.disabled,
			"a set that is catalogued but not recorded yet can still be opened")
	check(_text_of(vowels).contains("%d to write" % CS.chars_of(UNRECORDED_SET).size()),
			"and says how much of it there is")
	check(current_scene.get_node("TotalStars").text.begins_with("0 star"),
			"nothing earned yet (\"%s\")" % current_scene.get_node("TotalStars").text)

	await _tap(digits)
	await _wait_for("CharacterSelect")
	check(current_scene.name == "CharacterSelect",
			"tapping a set opens its characters")


func test_character_grid() -> void:
	print("the character grid:")
	check(current_scene.get_node("TopBar/Title").text == CS.label_of(TEST_SET),
			"the grid is the set that was tapped")
	var grid: GridContainer = current_scene.get_node("GridArea/Grid")
	check(grid.get_child_count() == CS.chars_of(TEST_SET).size(),
			"one button per character in the set (got %d)" % grid.get_child_count())
	var one := _char_button(TRACED_CHAR)
	check(one != null and not one.disabled, "a recorded character can be opened")
	check(_text_of(one).contains(TRACED_CHAR), "and shows the character itself")
	check(_stars_of(one) != null, "with a row of stars under it")
	check(_stars_of(one)._stars == 0, "empty until it has been written")
	check(_stars_of(one)._total == SC.MAX_STARS, "and showing what there is to earn")
	var three := _char_button(UNRECORDED_CHAR)
	check(three != null and three.disabled,
			"a character with no strokes yet is visible but cannot be opened")
	check(_text_of(three).contains("soon"), "and says so rather than going nowhere")

	# A disabled button must actually refuse a finger, not merely look grey.
	await _tap(three)
	for i in 4:
		await process_frame
	check(current_scene.name == "CharacterSelect", "tapping it does nothing at all")


func test_opening_a_character() -> void:
	print("opening a character:")
	var one := _char_button(TRACED_CHAR)
	await _tap(one)
	await _wait_for("Tracing")
	var tracing := current_scene
	check(tracing.name == "Tracing", "tapping a character opens the tracing scene")
	check(tracing._current_set_id() == TEST_SET and tracing._current_char() == TRACED_CHAR,
			"on the character that was tapped")
	# Step 10: a numeral is counted before it is written. This is the half of
	# GATE 10 a headless suite cannot reach — whether a finger actually lands on
	# an object drawn into an overlay over the drawing box.
	check(tracing._state == TR.State.COUNT,
			"which starts by asking how many \"%s\" is" % TRACED_CHAR)
	check(tracing._count_overlay.visible and not tracing._glyph.visible,
			"with the objects up and the answer — the guide glyph — hidden")
	check(tracing._count_objects.centres().size() == CS.value_of(TEST_SET, TRACED_CHAR),
			"showing one object per unit (%d)" % tracing._count_objects.centres().size())

	# The demo is watched at speed: what is being tested is the way through the
	# app, not how long a child watches an animation for.
	tracing._demo.speed = 9000.0
	tracing._demo.pause = 0.05
	await _count_them(tracing)
	check(tracing._state == TR.State.DEMO, "counting them all shows how it is written")
	check(not tracing._count_overlay.visible and tracing._glyph.visible,
			"and puts the objects away again")
	await _until(func() -> bool: return tracing._state == TR.State.TRACE, 8.0)
	check(tracing._state == TR.State.TRACE, "and hands over to tracing")

	for i in tracing._strokes.size():
		await _draw(tracing._screen_stroke(i))
	check(tracing._state == TR.State.SCORE, "a full trace reaches the score card")
	check(tracing._stars == 3, "on the guide, so three stars (got %d)" % tracing._stars)


func test_stars_are_kept() -> void:
	print("the stars are written down:")
	# Read the file back rather than any dictionary held in memory: this is
	# exactly what the next launch of the app does.
	var loaded := PR.load_progress()
	check(loaded.ok, "the progress file is written and readable")
	check(PR.stars_of(loaded["data"], TEST_SET, TRACED_CHAR) == 3,
			"with the three stars for \"%s\"" % TRACED_CHAR)
	check(PR.total_stars(loaded["data"]) == 3, "and nothing else")


func test_back_to_the_grid() -> void:
	print("back to the grid:")
	var panel_back: Button = current_scene.get_node("SidePanel/Margin/VBox/Back")
	check(panel_back.get_global_rect().size.y >= 100.0,
			"the way back is a button a child can hit (%.0f px tall)"
					% panel_back.get_global_rect().size.y)
	# The score card is over the side panel, so it is the card's own "back" that
	# has to work here — the panel's is behind it, and is tested below with the
	# card gone.
	var back: Button = current_scene.get_node("ScoreOverlay/Card/Margin/VBox/Buttons/Back")
	check(back.get_global_rect().size.y >= 100.0,
			"and so is the one on the score card (%.0f px tall)"
					% back.get_global_rect().size.y)
	await _tap(back)
	await _wait_for("CharacterSelect")
	check(current_scene.name == "CharacterSelect", "\"back\" leaves the character")
	check(current_scene.get_node("TopBar/Title").text == CS.label_of(TEST_SET),
			"to the set it came from")
	check(_stars_of(_char_button(TRACED_CHAR))._stars == 3,
			"and the character now wears its stars")
	check(_stars_of(_char_button(SECOND_CHAR))._stars == 0,
			"while the others are still waiting")
	check(current_scene.get_node("TopBar/Summary").text.contains("1 of 10"),
			"the set's tally is up to date (\"%s\")"
					% current_scene.get_node("TopBar/Summary").text)


func test_back_to_the_menu() -> void:
	print("back to the menu:")
	await _tap(current_scene.get_node("TopBar/Back"))
	await _wait_for("MainMenu")
	check(current_scene.name == "MainMenu", "\"back\" again reaches the main menu")
	check(current_scene.get_node("TotalStars").text.begins_with("3 star"),
			"which counts the stars earned (\"%s\")"
					% current_scene.get_node("TotalStars").text)
	check(_text_of(_set_button(TEST_SET)).contains("1 of 10 written"),
			"and the set button says how far the child has got")
	check(_text_of(_set_button(OTHER_SET)).contains("44 to write"),
			"a set not started yet is an invitation, not a nought")


func test_a_worse_attempt() -> void:
	print("writing it again, worse:")
	await _tap(_set_button(TEST_SET))
	await _wait_for("CharacterSelect")
	await _tap(_char_button(TRACED_CHAR))
	await _wait_for("Tracing")
	var tracing := current_scene
	tracing._demo.speed = 9000.0
	tracing._demo.pause = 0.05
	await _count_them(tracing)
	await _until(func() -> bool: return tracing._state == TR.State.TRACE, 8.0)
	for i in tracing._strokes.size():
		await _draw(_scribble(tracing), 90.0)
	check(tracing._state == TR.State.SCORE, "a scribble still finishes the character")
	check(tracing._stars < 3, "and scores less (got %d)" % tracing._stars)
	check(PR.stars_of(PR.load_progress()["data"], TEST_SET, TRACED_CHAR) == 3,
			"but the three stars already earned are not taken away")

	# "again" takes the card away, which is what leaves the side panel's own
	# "back" reachable — the other half of the pair tested above.
	await _tap(tracing.get_node("ScoreOverlay/Card/Margin/VBox/Buttons/Again"))
	check(tracing._state == TR.State.TRACE and tracing._traced.is_empty(),
			"\"again\" wipes the ink and offers the character back")
	# A child on their fifth go at a numeral must not have to count it out again.
	check(not tracing._count_overlay.visible,
			"without counting the objects a second time")
	await _tap(tracing.get_node("SidePanel/Margin/VBox/Back"))
	await _wait_for("CharacterSelect")
	check(_stars_of(_char_button(TRACED_CHAR))._stars == 3,
			"and the grid still shows the best the child has done")


## Step 8 puts 21 vowels in the catalog before a single one is recorded, and
## that is not a passing state: every set spends time here, and the vowels stay
## here between recording batches. The grid must fill itself from the catalog,
## refuse every character, and — the part that matters — still let a child out.
func test_a_set_not_recorded_yet() -> void:
	print("a set in the catalog with nothing recorded:")
	await _tap(current_scene.get_node("TopBar/Back"))
	await _wait_for("MainMenu")
	await _tap(_set_button(UNRECORDED_SET))
	await _wait_for("CharacterSelect")
	check(current_scene.get_node("TopBar/Title").text == CS.label_of(UNRECORDED_SET),
			"the set opens without a stroke file to read")
	var grid: GridContainer = current_scene.get_node("GridArea/Grid")
	check(grid.get_child_count() == CS.chars_of(UNRECORDED_SET).size(),
			"with a button per catalogued character (got %d)" % grid.get_child_count())
	var all_soon := grid.get_child_count() > 0
	for chr in CS.chars_of(UNRECORDED_SET):
		var button := _char_button(chr)
		if button == null or not button.disabled or not _text_of(button).contains("soon"):
			all_soon = false
	check(all_soon, "every one of them says \"soon\" and refuses a finger")
	check(_text_of(_char_button("ะ")).contains("◌ะ"),
			"a combining mark is shown on its placeholder, not on its own")
	check(_text_of(_char_button("เ")).contains("เ◌"),
			"and a leading vowel before it, the way it is written")

	await _tap(current_scene.get_node("TopBar/Back"))
	await _wait_for("MainMenu")
	check(current_scene.name == "MainMenu",
			"and \"back\" gets out again — the set is not a dead end")


func test_real_files_untouched() -> void:
	print("the real files:")
	var intact := true
	for path: String in _real_dataset:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != _real_dataset[path]:
			intact = false
	check(intact, "the recorded dataset in %s was never touched" % CS.STROKE_DIR)
	var same := (not FileAccess.file_exists(PR.DEFAULT_PATH)) if _real_progress.is_empty() \
			else (FileAccess.file_exists(PR.DEFAULT_PATH)
					and FileAccess.get_sha256(PR.DEFAULT_PATH) == _real_progress)
	check(same, "and the stars actually earned in %s are as they were" % PR.DEFAULT_PATH)


# --- scratch files -----------------------------------------------------------

func _fingerprint_real_files() -> void:
	for id in CS.SET_IDS:
		var path := "%s/%s.json" % [CS.STROKE_DIR, id]
		if FileAccess.file_exists(path):
			_real_dataset[path] = FileAccess.get_sha256(path)
	if FileAccess.file_exists(PR.DEFAULT_PATH):
		_real_progress = FileAccess.get_sha256(PR.DEFAULT_PATH)


## Two characters of the ten in the set, as straight lines a synthetic finger
## can follow exactly. The third is left unrecorded on purpose: the grid has to
## show a character that is not ready yet, which is what most of the catalog
## looked like until Step 8.
func _write_scratch_dataset() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	var dir := DirAccess.open(SCRATCH_DIR)
	for file in dir.get_files():
		dir.remove(file)
	CS.stroke_dir = SCRATCH_DIR
	var entries: Array = [
		SD.make_entry(TRACED_CHAR, TEST_SET, CS.name_of(TEST_SET, TRACED_CHAR), [
			PackedVector2Array([Vector2(0.35, 0.3), Vector2(0.5, 0.2)]),
			PackedVector2Array([Vector2(0.5, 0.2), Vector2(0.5, 0.8)]),
		]),
		SD.make_entry(SECOND_CHAR, TEST_SET, CS.name_of(TEST_SET, SECOND_CHAR), [
			PackedVector2Array([Vector2(0.3, 0.35), Vector2(0.7, 0.7)]),
		]),
	]
	var result: Dictionary = SD.save_set(CS.path_of(TEST_SET), entries)
	if not result.ok:
		push_error("[test_menus] cannot write the scratch dataset: %s" % result.error)


func _remove_scratch_progress() -> void:
	if FileAccess.file_exists(SCRATCH_PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PROGRESS))


# --- finding things on screen ------------------------------------------------

## The main menu builds its buttons from the catalog and names them by set id.
func _set_button(set_id: String) -> Button:
	var grid := current_scene.get_node_or_null("Grid")
	if grid == null:
		return null
	return grid.get_node_or_null(set_id) as Button


## Character buttons are named by code point — a node name cannot be "ก".
func _char_button(chr: String) -> Button:
	var grid := current_scene.get_node_or_null("GridArea/Grid")
	if grid == null:
		return null
	return grid.get_node_or_null("Char_%d" % chr.unicode_at(0)) as Button


## The star row inside a character's button, or null when it has none.
func _stars_of(button: Button) -> Node:
	for child in button.get_child(0).get_children():
		if child.name == "Stars":
			return child
	return null


## Everything written on a button, wherever it is in the stack of labels inside.
func _text_of(button: Button) -> String:
	var parts := PackedStringArray([button.text])
	for child in button.get_child(0).get_children():
		if child is Label:
			parts.append((child as Label).text)
	return " ".join(parts)


# --- waiting -----------------------------------------------------------------

## Screens are swapped on a deferred call, so a tap is followed by a wait for
## the scene to arrive rather than by a fixed number of frames.
func _wait_for(scene_name: String, seconds: float = 5.0) -> void:
	await _until(func() -> bool:
			return current_scene != null and current_scene.name == scene_name, seconds)
	for i in 3:
		await process_frame


func _until(condition: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not condition.call():
		await process_frame


# --- synthetic touch ---------------------------------------------------------

## Press a control with a finger, in the middle of it. Nothing in this suite
## reaches for `pressed.emit()`: GATE 7 is about what a finger can reach, and a
## button the touch does not land on is exactly the failure worth catching.
func _tap(control: Control) -> void:
	var centre := control.get_global_rect().get_center()
	_send_touch(centre, true)
	await process_frame
	_send_touch(centre, false)
	for i in 3:
		await process_frame


## Count every object with a finger — a real touch on each one where it is
## drawn, not a call into the node — then wait for the demo the last one starts.
## Nothing about the counting is scored, so this is only ever the way through.
func _count_them(tracing: Node) -> void:
	var objects: Control = tracing._count_objects
	var origin := objects.get_global_rect().position
	# Zero has no objects: its basket takes one tap anywhere in the overlay.
	var centres: PackedVector2Array = objects.centres()
	if centres.is_empty():
		centres = PackedVector2Array([objects.size * 0.5])
	for centre in centres:
		_send_touch(origin + centre, true)
		await process_frame
		_send_touch(origin + centre, false)
		await process_frame
	await _until(func() -> bool: return tracing._state != TR.State.COUNT, 5.0)


func _draw(path: PackedVector2Array, spacing: float = 14.0) -> void:
	var dense: PackedVector2Array = SD.resample_stroke(path, spacing)
	_send_touch(dense[0], true)
	await process_frame
	for i in range(1, dense.size()):
		_send_drag(dense[i - 1], dense[i])
		await process_frame
	_send_touch(dense[-1], false)
	await process_frame


## A stroke that is not writing: corner to corner across the box, several times
## the length of anything in the character.
func _scribble(tracing: Node) -> PackedVector2Array:
	var box: Rect2 = tracing._box()
	var path := PackedVector2Array()
	for point in [Vector2(0.15, 0.85), Vector2(0.85, 0.2), Vector2(0.2, 0.35),
			Vector2(0.9, 0.9), Vector2(0.1, 0.6)]:
		path.append(box.position + box.size * point)
	return path


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
