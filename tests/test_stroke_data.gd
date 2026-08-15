extends SceneTree
## GATE 2 test suite for scripts/stroke_data.gd.
## Run: godot --headless --path . --script tests/test_stroke_data.gd
## Exits 0 when every check passes, 1 otherwise.

const SD := preload("res://scripts/stroke_data.gd")

const EPS := 1e-5

var failures := 0
var checks := 0


func _init() -> void:
	test_round_trip()
	test_resampling()
	test_normalization()
	test_entry_merge()
	test_partial_stroke()
	test_malformed_json()
	test_sample_file()
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


func test_round_trip() -> void:
	print("save -> load round trip:")
	var strokes_a: Array = [
		PackedVector2Array([Vector2(0.35, 0.25), Vector2(0.55, 0.1), Vector2(0.55, 0.9)]),
	]
	var strokes_k: Array = [
		PackedVector2Array([Vector2(0.2, 0.3), Vector2(0.25, 0.25), Vector2(0.2, 0.2), Vector2(0.2, 0.9)]),
		PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.8, 0.9)]),
	]
	var entries: Array = [
		SD.make_entry("1", "digits", "one", strokes_a),
		SD.make_entry("ก", "thai_consonant", "ก ไก่", strokes_k),
	]
	var path := "user://test_round_trip.json"
	var saved: Dictionary = SD.save_set(path, entries)
	check(saved.ok, "save_set succeeds")
	var loaded: Dictionary = SD.load_set(path)
	check(loaded.ok, "load_set succeeds")
	if not loaded.ok:
		return
	check(loaded.entries.size() == 2, "entry count preserved")
	for i in entries.size():
		var orig: Dictionary = entries[i]
		var back: Dictionary = loaded.entries[i]
		check(back["char"] == orig["char"] and back["set"] == orig["set"]
				and back["name"] == orig["name"], "entry %d metadata preserved" % i)
		var strokes_match: bool = back["strokes"].size() == orig["strokes"].size()
		if strokes_match:
			for s in orig["strokes"].size():
				var os: PackedVector2Array = orig["strokes"][s]
				var bs: PackedVector2Array = back["strokes"][s]
				if bs.size() != os.size():
					strokes_match = false
					break
				for p in os.size():
					if os[p].distance_to(bs[p]) > EPS:
						strokes_match = false
						break
		check(strokes_match, "entry %d stroke points preserved" % i)


func test_resampling() -> void:
	print("resampling:")
	var line := PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	var res: PackedVector2Array = SD.resample_stroke(line, 0.1)
	check(res.size() == 11, "straight line 0..1 at spacing 0.1 gives 11 points (got %d)" % res.size())
	check(res[0].is_equal_approx(Vector2.ZERO) and res[-1].is_equal_approx(Vector2(1, 0)),
			"endpoints preserved")
	var even := true
	for i in range(1, res.size()):
		if absf(res[i - 1].distance_to(res[i]) - 0.1) > EPS:
			even = false
	check(even, "consecutive distances all equal spacing")

	# L-shaped polyline: spacing is measured along the path, so every gap is
	# exactly `spacing` except the chord that cuts the corner and the final
	# remainder, which may only be shorter — never longer.
	var ell := PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 0.5)])
	var res_l: PackedVector2Array = SD.resample_stroke(ell, 0.07)
	var short_gaps := 0
	var bad_gaps := 0
	for i in range(1, res_l.size()):
		var gap := res_l[i - 1].distance_to(res_l[i])
		if gap > 0.07 + 1e-4:
			bad_gaps += 1
		elif gap < 0.07 - 1e-4:
			short_gaps += 1
	check(bad_gaps == 0 and short_gaps <= 2,
			"L-shape: even spacing along path (no gap > spacing; %d short gaps at corner/end)" % short_gaps)
	check(res_l[-1].is_equal_approx(Vector2(0.5, 0.5)), "L-shape: final endpoint kept")
	check(res_l[0].distance_to(res_l[-1]) > 0.0 and res_l.size() > 10,
			"L-shape: sensible point count (got %d)" % res_l.size())

	var single := PackedVector2Array([Vector2(0.3, 0.3)])
	check(SD.resample_stroke(single, 0.1).size() == 1, "single-point stroke returned as-is")


func test_normalization() -> void:
	print("normalize / denormalize:")
	var box := Rect2(100, 200, 800, 800)
	var screen := PackedVector2Array([Vector2(100, 200), Vector2(500, 600), Vector2(900, 1000)])
	var norm: PackedVector2Array = SD.normalize_stroke(screen, box)
	check(norm[0].is_equal_approx(Vector2(0, 0)) and norm[1].is_equal_approx(Vector2(0.5, 0.5))
			and norm[2].is_equal_approx(Vector2(1, 1)), "normalize maps box corners to 0..1")
	var back: PackedVector2Array = SD.denormalize_stroke(norm, box)
	var ok := true
	for i in screen.size():
		if screen[i].distance_to(back[i]) > 1e-3:
			ok = false
	check(ok, "denormalize inverts normalize")


func test_entry_merge() -> void:
	print("find / merge entries (used by the Stroke Recorder's save):")
	var one := SD.make_entry("1", "digits", "one", [PackedVector2Array([Vector2(0.5, 0.1)])])
	var two := SD.make_entry("2", "digits", "two", [PackedVector2Array([Vector2(0.2, 0.2)])])
	var entries: Array = [one, two]
	check(SD.find_entry(entries, "2")["name"] == "two", "find_entry finds a character")
	check(SD.find_entry(entries, "9").is_empty(), "find_entry returns {} for an unrecorded character")

	var three := SD.make_entry("3", "digits", "three", [PackedVector2Array([Vector2(0.3, 0.3)])])
	var appended: Array = SD.merge_entry(entries, three)
	check(appended.size() == 3 and appended[2]["char"] == "3", "a new character is appended")
	check(entries.size() == 2, "merge_entry leaves the original array alone")

	var new_two := SD.make_entry("2", "digits", "two", [PackedVector2Array([Vector2(0.9, 0.9)])])
	var replaced: Array = SD.merge_entry(entries, new_two)
	check(replaced.size() == 2 and replaced[1]["strokes"][0][0].is_equal_approx(Vector2(0.9, 0.9)),
			"re-recording a character replaces its entry in place")
	check(replaced[0]["char"] == "1", "other entries keep their position")


func test_partial_stroke() -> void:
	print("partial strokes (replay / demo animation):")
	var line := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	var half: PackedVector2Array = SD.partial_stroke(line, 5.0)
	check(half.size() == 2 and half[-1].is_equal_approx(Vector2(5, 0)),
			"stops exactly `distance` along the path")
	var corner: PackedVector2Array = SD.partial_stroke(line, 14.0)
	check(corner.size() == 3 and corner[-1].is_equal_approx(Vector2(10, 4)),
			"keeps the corner point once passed")
	check(absf(SD.stroke_length(SD.partial_stroke(line, 12.5)) - 12.5) < EPS,
			"partial length equals the requested distance")
	check(SD.partial_stroke(line, 999.0).size() == line.size(), "past the end returns the whole stroke")
	check(SD.partial_stroke(line, -1.0).is_empty(), "negative distance draws nothing")
	check(SD.partial_stroke(PackedVector2Array(), 5.0).is_empty(), "empty stroke stays empty")


func test_malformed_json() -> void:
	print("malformed input rejected with clear errors:")
	check(not SD.load_set("user://does_not_exist.json").ok, "missing file rejected")

	_write("user://bad_parse.json", "{ this is not json ]")
	var r1: Dictionary = SD.load_set("user://bad_parse.json")
	check(not r1.ok and "Malformed JSON" in r1.error,
			"unparseable JSON rejected (error: %s)" % r1.get("error", ""))

	_write("user://bad_root.json", "{\"char\": \"x\"}")
	var r2: Dictionary = SD.load_set("user://bad_root.json")
	check(not r2.ok and "array" in r2.error, "non-array root rejected")

	_write("user://bad_entry.json", "[{\"char\": \"x\", \"set\": \"s\", \"name\": \"n\"}]")
	var r3: Dictionary = SD.load_set("user://bad_entry.json")
	check(not r3.ok and "strokes" in r3.error, "entry missing \"strokes\" rejected")

	_write("user://bad_point.json",
			"[{\"char\": \"x\", \"set\": \"s\", \"name\": \"n\", \"strokes\": [[[0.1, \"y\"]]]}]")
	var r4: Dictionary = SD.load_set("user://bad_point.json")
	check(not r4.ok and "point" in r4.error, "non-numeric point rejected")

	_write("user://bad_empty_stroke.json",
			"[{\"char\": \"x\", \"set\": \"s\", \"name\": \"n\", \"strokes\": [[]]}]")
	var r5: Dictionary = SD.load_set("user://bad_empty_stroke.json")
	check(not r5.ok, "empty stroke rejected")


## Reads a real recorded file to prove load_set() copes with data the recorder
## actually produced. It asserts nothing about *which* characters are in there:
## that is the dataset validator's job, and an assertion on the contents would
## go red every time the user records a batch (as an earlier version of this
## test did the moment the digits were recorded).
func test_sample_file() -> void:
	print("a real recorded file:")
	var path := "res://data/strokes/digits.json"
	var r: Dictionary = SD.load_set(path)
	check(r.ok, "%s loads (error: %s)" % [path, r.get("error", "")])
	if not r.ok:
		return
	check(not (r.entries as Array).is_empty(), "it has entries to check")

	var well_formed := true
	for entry: Dictionary in r.entries:
		for key in SD.REQUIRED_KEYS:
			if not entry.has(key):
				well_formed = false
		for stroke in entry["strokes"]:
			if not (stroke is PackedVector2Array) or (stroke as PackedVector2Array).size() < 2:
				well_formed = false
	check(well_formed, "every entry parses into the runtime form with usable strokes")

	# The round trip is the property worth pinning here: whatever the recorder
	# wrote must survive save → load unchanged.
	var round_trip := "user://round_trip.json"
	check(SD.save_set(round_trip, r.entries).ok, "the entries save again")
	var again: Dictionary = SD.load_set(round_trip)
	check(again.ok and _same_entries(r.entries, again.entries),
			"a real file survives a save/load round trip unchanged")


func _same_entries(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if x["char"] != y["char"] or x["set"] != y["set"] or x["name"] != y["name"]:
			return false
		if (x["strokes"] as Array).size() != (y["strokes"] as Array).size():
			return false
		for s in (x["strokes"] as Array).size():
			var sx: PackedVector2Array = x["strokes"][s]
			var sy: PackedVector2Array = y["strokes"][s]
			if sx.size() != sy.size():
				return false
			for p in sx.size():
				if not sx[p].is_equal_approx(sy[p]):
					return false
	return true


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
