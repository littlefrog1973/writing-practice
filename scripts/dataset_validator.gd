class_name DatasetValidator
extends RefCounted
## Checks the recorded stroke dataset in data/strokes/ against the catalog.
##
## Run it from the command line through tests/validate_dataset.gd; it is also
## the gate Step 8 uses to know the dataset is complete, and tests/test_char_sets.gd
## calls check_entries() so the in-catalog/normalized rules have one definition.
##
## Two severities:
## - **problems** fail the run: data the app cannot trust (unknown set, character
##   not in the catalog, a stroke with fewer than 2 points, a point outside the
##   0–1 box, a duplicate character).
## - **warnings** are printed but pass: a stroke shorter than MIN_STROKE_LENGTH
##   is usually a stray tap, but the dot on an "i" is a legitimate one, so this
##   is a judgement call for the person reading the report, not a rule.

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")

## Fraction of the box a stroke must span before it stops looking like a stray
## tap. A dot is stored as two points DOT_OFFSET apart, so it lands far below.
const MIN_STROKE_LENGTH := 0.02

## Fewest points a real stroke can have — one point cannot describe a direction.
const MIN_POINTS := 2


## Validate every stroke file in the dataset directory.
## Returns {
##   "ok": bool,                  ## false when problems is non-empty
##   "problems": PackedStringArray,
##   "warnings": PackedStringArray,
##   "coverage": Array,           ## [{ "id", "label", "recorded", "total" }, …]
##   "files": int,                ## stroke files found
## }
static func validate_all() -> Dictionary:
	var problems := PackedStringArray()
	var warnings := PackedStringArray()
	var coverage: Array = []
	var recorded_by_set: Dictionary = {}
	var files := 0

	for path in _stroke_files():
		files += 1
		var id := path.get_file().get_basename()
		if not CS.has_set(id):
			problems.append("%s: \"%s\" is not a set in the catalog (stray or misnamed file)"
					% [path, id])
			continue
		var loaded: Dictionary = SD.load_set(path)
		if not loaded.ok:
			problems.append("%s: %s" % [path, loaded.error])
			continue
		var result := check_entries(id, loaded.entries, path)
		problems.append_array(result.problems)
		warnings.append_array(result.warnings)
		recorded_by_set[id] = (loaded.entries as Array).size()

	for id in CS.SET_IDS:
		coverage.append({
			"id": id,
			"label": CS.label_of(id),
			"recorded": recorded_by_set.get(id, 0),
			"total": CS.chars_of(id).size(),
		})

	return {
		"ok": problems.is_empty(),
		"problems": problems,
		"warnings": warnings,
		"coverage": coverage,
		"files": files,
	}


## Check the entries of one set. `where` only decorates the messages, so tests
## can pass a file path or any other label.
## Returns { "problems": PackedStringArray, "warnings": PackedStringArray }.
static func check_entries(id: String, entries: Array, where: String = "") -> Dictionary:
	var problems := PackedStringArray()
	var warnings := PackedStringArray()
	var label := where if not where.is_empty() else id
	var chars: PackedStringArray = CS.chars_of(id)
	var seen: Dictionary = {}

	for entry: Dictionary in entries:
		var chr: String = entry["char"]
		var at := "%s: \"%s\"" % [label, chr]

		if seen.has(chr):
			problems.append("%s appears more than once in the file" % at)
		seen[chr] = true

		if entry["set"] != id:
			problems.append("%s carries set \"%s\" but lives in the %s file"
					% [at, entry["set"], id])
		if not chars.has(chr):
			# Nothing else about the entry can be judged against the catalog.
			problems.append("%s is not one of the %d characters in \"%s\""
					% [at, chars.size(), id])
			continue

		var expected_name := CS.name_of(id, chr)
		if entry["name"] != expected_name:
			problems.append("%s is named \"%s\" but the catalog says \"%s\""
					% [at, entry["name"], expected_name])

		var strokes: Array = entry["strokes"]
		if strokes.is_empty():
			problems.append("%s has no strokes" % at)
			continue

		for i in strokes.size():
			var stroke: PackedVector2Array = strokes[i]
			var n := i + 1
			if stroke.size() < MIN_POINTS:
				problems.append("%s stroke %d has %d point(s); a stroke needs at least %d"
						% [at, n, stroke.size(), MIN_POINTS])
				continue
			var outside := PackedStringArray()
			for point in stroke:
				if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
					outside.append(str(point))
			if not outside.is_empty():
				problems.append("%s stroke %d leaves the 0–1 box at %s%s"
						% [at, n, ", ".join(outside.slice(0, 3)),
						"…" if outside.size() > 3 else ""])
			var length := SD.stroke_length(stroke)
			if length < MIN_STROKE_LENGTH:
				warnings.append("%s stroke %d is only %.3f of the box long — a dot? (allowed)"
						% [at, n, length])

	return {"problems": problems, "warnings": warnings}


## Every *.json in the dataset directory, sorted. Returns [] when the directory
## does not exist yet.
static func _stroke_files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(CS.stroke_dir)
	if dir == null:
		return out
	for file in dir.get_files():
		# An exported build serves "foo.json.remap"; harmless to tolerate here.
		if file.ends_with(".remap"):
			file = file.get_basename()
		if file.get_extension().to_lower() == "json":
			out.append("%s/%s" % [CS.stroke_dir, file])
	out.sort()
	return out
