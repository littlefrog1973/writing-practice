class_name Progress
extends RefCounted
## What the child has earned, per character — Step 7.
##
## Static and pure apart from the two file calls, like stroke_data.gd: it takes
## a progress dictionary and gives one back, which is what lets
## tests/test_progress.gd cover every case headless.
##
## **Best stars are kept, never the latest.** A child who writes ก beautifully
## on Tuesday and hurriedly on Wednesday has not got worse at ก, and a star that
## can be taken away is a star that is not worth earning. record() only ever
## raises a character's score.
##
## The file lives at user://progress.json because user:// is the only writable
## place in an exported game — res:// is read-only there, so the obvious spot
## next to the stroke data would work in the editor and fail on the Surface Go.
##
## **Nothing here may stop the app.** A missing file is a child who has not
## played yet; a corrupt one is a half-finished write or a full disk, and the
## answer to both is an empty progress dictionary and a message in the console.
## Losing the stars is sad. A five-year-old staring at an error is worse.
##
## Shape on disk, and in memory:
##
##     { "version": 1, "sets": { "thai_consonants": { "ก": 3, "ข": 2 } } }

const CS := preload("res://scripts/char_sets.gd")
const SC := preload("res://scripts/scorer.gd")

const DEFAULT_PATH := "user://progress.json"

## Where load/save go. A test seam, exactly like CharSets.stroke_dir: a suite
## points this at a scratch file under user:// so a test run can never overwrite
## the stars actually earned on this machine.
static var path: String = DEFAULT_PATH

## Bumped only if the shape below ever changes; load() keeps whatever it reads
## so a file written by a newer build is not silently downgraded.
const VERSION := 1


## An empty progress dictionary — the starting point for a child who has not
## written anything yet, and the fallback for a file that cannot be read.
static func empty() -> Dictionary:
	return {"version": VERSION, "sets": {}}


## Read the progress file.
## Returns { "ok": true, "data": … } or { "ok": false, "error": …, "data": … }.
## **"data" is always present and always usable**; on failure it is an empty
## progress dictionary. Callers should log the error and carry on — see the note
## at the top of this file.
static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(path):
		# Not an error: this is what a first run looks like.
		return {"ok": true, "data": empty()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open %s: %s"
				% [path, error_string(FileAccess.get_open_error())])
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _fail("Malformed JSON in %s (line %d): %s"
				% [path, json.get_error_line(), json.get_error_message()])
	if not (json.data is Dictionary):
		return _fail("Malformed progress file %s: top level must be an object" % path)
	return {"ok": true, "data": _sanitize(json.data)}


## Write a progress dictionary. Returns { "ok": true } or { "ok": false, "error": … }.
static func save_progress(data: Dictionary) -> Dictionary:
	var dir := path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write %s: %s"
				% [path, error_string(FileAccess.get_open_error())])
	file.store_string(JSON.stringify(_sanitize(data), "\t"))
	return {"ok": true}


## Stars earned for one character, 0 when it has never been traced.
static func stars_of(data: Dictionary, set_id: String, chr: String) -> int:
	var sets: Dictionary = data.get("sets", {})
	return int((sets.get(set_id, {}) as Dictionary).get(chr, 0))


## Whether a character has been written at all yet.
static func is_traced(data: Dictionary, set_id: String, chr: String) -> bool:
	return stars_of(data, set_id, chr) > 0


## The score that means a character is finished with — the stars a flawless
## trace earns. Asked of the scorer rather than written down again here: the
## star boundaries have exactly one definition, and it is not in this file.
static func mastered_stars() -> int:
	return SC.stars_for(1.0)


## Record a result, keeping the better of it and what is already there.
## `data` is modified in place. Returns true when this was an improvement —
## which is what a menu would celebrate, and what tells a caller a save is
## actually needed.
static func record(data: Dictionary, set_id: String, chr: String, stars: int) -> bool:
	var earned := clampi(stars, 0, SC.MAX_STARS)
	if earned <= 0 or set_id.is_empty() or chr.is_empty():
		return false
	if not data.has("sets"):
		data["sets"] = {}
	var sets: Dictionary = data["sets"]
	if not sets.has(set_id):
		sets[set_id] = {}
	var chars: Dictionary = sets[set_id]
	if earned <= int(chars.get(chr, 0)):
		return false
	chars[chr] = earned
	return true


## Load, record, save — the whole round trip the tracing scene's `scored` signal
## needs, in one call. Reading the file each time rather than holding progress
## in memory keeps two screens from overwriting each other's stars, and the file
## is a few hundred bytes.
##
## Returns { "ok", "improved", "stars", "data" } (+ "error" when a step failed).
## A failed *load* does not stop the save: an unreadable file is replaced by a
## fresh one, which is the only way a child ever gets out of that state.
static func record_and_save(set_id: String, chr: String, stars: int) -> Dictionary:
	var loaded := load_progress()
	var data: Dictionary = loaded["data"]
	var improved := record(data, set_id, chr, stars)
	var result := {
		"ok": loaded.ok,
		"improved": improved,
		"stars": stars_of(data, set_id, chr),
		"data": data,
	}
	if not loaded.ok:
		result["error"] = loaded.error
	if not improved and loaded.ok:
		return result
	var saved := save_progress(data)
	if not saved.ok:
		result["ok"] = false
		result["error"] = saved.error
	return result


## Best-of merge of two progress dictionaries into a new one. Neither argument
## is modified. Used by the tests, and the honest answer if progress is ever
## carried between the Linux and Windows halves of the same machine.
static func merge(first: Dictionary, second: Dictionary) -> Dictionary:
	var out := empty()
	for source in [first, second]:
		var sets: Dictionary = (source as Dictionary).get("sets", {})
		for set_id: String in sets:
			var chars: Dictionary = sets[set_id]
			for chr: String in chars:
				record(out, set_id, chr, int(chars[chr]))
	return out


## How a whole set stands, for the menu buttons:
## { "stars": total earned, "traced": characters written at least once,
##   "mastered": characters at full stars, "total": characters in the set,
##   "possible": stars if every character were mastered }.
static func summary(data: Dictionary, set_id: String) -> Dictionary:
	var top := mastered_stars()
	var chars := CS.chars_of(set_id)
	var out := {"stars": 0, "traced": 0, "mastered": 0, "total": chars.size(),
			"possible": chars.size() * top}
	for chr in chars:
		var stars := stars_of(data, set_id, chr)
		if stars <= 0:
			continue
		out["stars"] = int(out["stars"]) + stars
		out["traced"] = int(out["traced"]) + 1
		if stars >= top:
			out["mastered"] = int(out["mastered"]) + 1
	return out


## Every star earned across the whole catalog.
static func total_stars(data: Dictionary) -> int:
	var total := 0
	for set_id in CS.SET_IDS:
		total += int(summary(data, set_id)["stars"])
	return total


## Throw the file away and start again — the "forget my stars" a second child
## on the same machine would need. Returns { "ok": … }.
static func clear() -> Dictionary:
	return save_progress(empty())


# --- helpers -----------------------------------------------------------------

## Keep what makes sense and quietly drop what does not: a hand-edited file, a
## star count from a build with a different maximum, an entry whose value is a
## string. Salvaging is the point — one bad row must not cost a child the rest
## of their stars, and nothing here is worth an error message.
static func _sanitize(raw: Dictionary) -> Dictionary:
	var out := empty()
	if raw.has("version"):
		out["version"] = int(raw["version"]) if _is_number(raw["version"]) else VERSION
	if not (raw.get("sets") is Dictionary):
		return out
	var sets: Dictionary = raw["sets"]
	var clean: Dictionary = out["sets"]
	for key in sets:
		if not (key is String) or not (sets[key] is Dictionary):
			continue
		var chars: Dictionary = sets[key]
		var kept := {}
		for chr in chars:
			if not (chr is String) or chr.is_empty() or not _is_number(chars[chr]):
				continue
			var stars := clampi(int(chars[chr]), 0, SC.MAX_STARS)
			if stars > 0:
				kept[chr] = stars
		if not kept.is_empty():
			clean[key] = kept
	return out


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": empty()}
