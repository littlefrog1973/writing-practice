class_name StrokeData
extends RefCounted
## Stroke data I/O and geometry helpers.
##
## File format — one JSON file per character set (e.g. data/strokes/digits.json):
## [
##   { "char": "1", "set": "digits", "name": "one",
##     "strokes": [ [[x, y], [x, y], ...], ... ] },
##   ...
## ]
## Points are normalized to a 0–1 box (recorded relative to the on-screen
## drawing square, so a glyph's size and position inside the box are kept —
## e.g. tone marks sit high). Thai strokes start at the loop (หัว).
##
## Runtime entry form used by callers:
## { "char": String, "set": String, "name": String,
##   "strokes": Array of PackedVector2Array }

const REQUIRED_KEYS: Array[String] = ["char", "set", "name", "strokes"]


## Load a character-set file.
## Returns { "ok": true, "entries": Array } on success,
## { "ok": false, "error": String } on any problem.
static func load_set(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("File does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open %s: %s" % [path, error_string(FileAccess.get_open_error())])
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _fail("Malformed JSON in %s (line %d): %s"
				% [path, json.get_error_line(), json.get_error_message()])
	if not (json.data is Array):
		return _fail("Malformed stroke file %s: top level must be an array of entries" % path)
	var entries: Array = []
	for i in json.data.size():
		var parsed := _entry_from_json(json.data[i], "%s entry %d" % [path, i])
		if not parsed.ok:
			return _fail(parsed.error)
		entries.append(parsed.entry)
	return {"ok": true, "entries": entries}


## Save runtime entries to a character-set file (pretty-printed JSON).
## Returns { "ok": true } or { "ok": false, "error": String }.
static func save_set(path: String, entries: Array) -> Dictionary:
	var out: Array = []
	for entry in entries:
		out.append(_entry_to_json(entry))
	var dir := path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
	file.store_string(JSON.stringify(out, "\t"))
	return {"ok": true}


static func make_entry(chr: String, set_name: String, display_name: String,
		strokes: Array) -> Dictionary:
	return {"char": chr, "set": set_name, "name": display_name, "strokes": strokes}


## The entry for `chr` in `entries`, or {} when the character is not recorded.
static func find_entry(entries: Array, chr: String) -> Dictionary:
	for entry in entries:
		if entry["char"] == chr:
			return entry
	return {}


## Insert `entry` into `entries`, replacing an existing entry for the same
## character in place. Returns a new array; `entries` is left untouched.
static func merge_entry(entries: Array, entry: Dictionary) -> Array:
	var out := entries.duplicate()
	for i in out.size():
		if out[i]["char"] == entry["char"]:
			out[i] = entry
			return out
	out.append(entry)
	return out


## Resample a polyline so consecutive points sit a fixed distance apart along
## the path. First and last points are preserved; the final gap may be shorter
## than `spacing`.
static func resample_stroke(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	if points.size() < 2 or spacing <= 0.0:
		return points.duplicate()
	var result := PackedVector2Array([points[0]])
	var carry := 0.0
	var prev := points[0]
	for i in range(1, points.size()):
		var seg_end := points[i]
		var seg_len := prev.distance_to(seg_end)
		while seg_len > 0.0 and carry + seg_len >= spacing:
			prev = prev.lerp(seg_end, (spacing - carry) / seg_len)
			result.append(prev)
			seg_len = prev.distance_to(seg_end)
			carry = 0.0
		carry += seg_len
		prev = seg_end
	if carry > spacing * 0.001:
		result.append(points[-1])
	return result


## Map screen-space points into the 0–1 box defined by `box`.
static func normalize_stroke(points: PackedVector2Array, box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = (points[i] - box.position) / box.size
	return out


## Map 0–1 points back into the screen-space rect `box`.
static func denormalize_stroke(points: PackedVector2Array, box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = box.position + points[i] * box.size
	return out


## The leading part of a stroke, `distance` along its path — the geometry
## behind a stroke being drawn on: the last point sits exactly `distance` from
## the start, so the polyline grows smoothly. An empty result means the stroke
## has not started yet; `distance` past the total length returns the whole
## stroke. Used by the recorder's replay and (Step 5) the demo animator.
static func partial_stroke(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	if points.is_empty() or distance < 0.0:
		return PackedVector2Array()
	if points.size() == 1:
		return points.duplicate()
	var out := PackedVector2Array([points[0]])
	var travelled := 0.0
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if travelled + seg >= distance:
			if seg > 0.0:
				out.append(points[i - 1].lerp(points[i], (distance - travelled) / seg))
			return out
		travelled += seg
		out.append(points[i])
	return out


## Total polyline length of a stroke.
static func stroke_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _entry_from_json(raw: Variant, where: String) -> Dictionary:
	if not (raw is Dictionary):
		return _fail("%s: entry must be an object" % where)
	for key in REQUIRED_KEYS:
		if not raw.has(key):
			return _fail("%s: missing required key \"%s\"" % [where, key])
	if not (raw["char"] is String) or (raw["char"] as String).is_empty():
		return _fail("%s: \"char\" must be a non-empty string" % where)
	if not (raw["strokes"] is Array) or (raw["strokes"] as Array).is_empty():
		return _fail("%s: \"strokes\" must be a non-empty array" % where)
	var strokes: Array = []
	for s in (raw["strokes"] as Array).size():
		var raw_stroke: Variant = raw["strokes"][s]
		if not (raw_stroke is Array) or (raw_stroke as Array).is_empty():
			return _fail("%s: stroke %d must be a non-empty array of points" % [where, s])
		var stroke := PackedVector2Array()
		stroke.resize(raw_stroke.size())
		for p in (raw_stroke as Array).size():
			var pt: Variant = raw_stroke[p]
			if not (pt is Array) or pt.size() != 2 \
					or not (pt[0] is float or pt[0] is int) \
					or not (pt[1] is float or pt[1] is int):
				return _fail("%s: stroke %d point %d must be a [x, y] number pair"
						% [where, s, p])
			stroke[p] = Vector2(pt[0], pt[1])
		strokes.append(stroke)
	return {
		"ok": true,
		"entry": make_entry(raw["char"], str(raw["set"]), str(raw["name"]), strokes),
	}


static func _entry_to_json(entry: Dictionary) -> Dictionary:
	var strokes_json: Array = []
	for stroke in entry["strokes"]:
		var stroke_json: Array = []
		for pt in stroke:
			stroke_json.append([pt.x, pt.y])
		strokes_json.append(stroke_json)
	return {
		"char": entry["char"],
		"set": entry["set"],
		"name": entry["name"],
		"strokes": strokes_json,
	}
