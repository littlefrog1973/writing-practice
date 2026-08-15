extends SceneTree
## GATE 7 test suite for scripts/progress.gd — the stars the child keeps.
##
## Run: godot --headless --path . --script tests/test_progress.gd
## Exits 0 when every check passes, 1 otherwise.
##
## progress.gd is static and its only impurity is one file, so this needs no
## display and no scene. It points Progress.path at a scratch file under user://
## for the run and checks the **real** user://progress.json afterwards: unlike a
## stroke file, that one holds something no one can re-record — an actual
## child's actual stars — and a test that overwrites it has done real damage.
##
## The awkward cases are the point. A missing file, a truncated one, a JSON
## array where an object should be, star counts from a build that scored out of
## five: all of them have to end with a child who can still write letters.

const CS := preload("res://scripts/char_sets.gd")
const PR := preload("res://scripts/progress.gd")
const SC := preload("res://scripts/scorer.gd")

const SCRATCH := "user://test_progress/progress.json"
const SET := "thai_consonants"
const OTHER_SET := "digits"

var _real_sha := ""  ## SHA-256 of the child's own progress file, if there is one.
var failures := 0
var checks := 0


func _init() -> void:
	_fingerprint_real_progress()
	PR.path = SCRATCH
	test_missing_file()
	test_round_trip()
	test_best_of()
	test_bad_results()
	test_corrupt_file()
	test_junk_contents()
	test_merge()
	test_summary()
	test_record_and_save()
	test_clear()
	PR.path = PR.DEFAULT_PATH
	test_real_progress_untouched()
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


func test_missing_file() -> void:
	print("a child who has not played yet:")
	_remove_scratch()
	var loaded := PR.load_progress()
	check(loaded.ok, "a missing file is not an error")
	check(loaded.has("data"), "and still comes with a progress dictionary")
	check((loaded["data"]["sets"] as Dictionary).is_empty(), "which is empty")
	check(PR.stars_of(loaded["data"], SET, "ก") == 0,
			"every character starts at no stars")
	check(not PR.is_traced(loaded["data"], SET, "ก"), "and nothing is written yet")
	check(PR.total_stars(loaded["data"]) == 0, "nothing earned across the catalog")


func test_round_trip() -> void:
	print("saving and loading:")
	var data := PR.empty()
	PR.record(data, SET, "ก", 3)
	PR.record(data, SET, "ข", 1)
	PR.record(data, OTHER_SET, "7", 2)
	check(PR.save_progress(data).ok, "the file saves")
	check(FileAccess.file_exists(SCRATCH), "and is on disk where it was asked for")
	var loaded := PR.load_progress()
	check(loaded.ok, "it loads again")
	var back: Dictionary = loaded["data"]
	check(PR.stars_of(back, SET, "ก") == 3 and PR.stars_of(back, SET, "ข") == 1,
			"with every character's stars intact")
	check(PR.stars_of(back, OTHER_SET, "7") == 2, "across sets")
	check(int(back["version"]) == PR.VERSION, "and a version to read it by")
	check(PR.total_stars(back) == 6, "six stars in total (got %d)" % PR.total_stars(back))
	# The stars survive a restart because they survive the process: this is the
	# same read the next launch does.
	check(PR.load_progress()["data"] == back, "a second load reads the same thing")


func test_best_of() -> void:
	print("keeping the best, never the latest:")
	var data := PR.empty()
	check(PR.record(data, SET, "ก", 2), "a first result is an improvement")
	check(PR.stars_of(data, SET, "ก") == 2, "and is kept")
	check(PR.record(data, SET, "ก", 3), "a better result is an improvement")
	check(PR.stars_of(data, SET, "ก") == 3, "and replaces it")
	check(not PR.record(data, SET, "ก", 1), "a worse result is not an improvement")
	check(PR.stars_of(data, SET, "ก") == 3,
			"and does not take the stars away (got %d)" % PR.stars_of(data, SET, "ก"))
	check(not PR.record(data, SET, "ก", 3), "the same result again changes nothing")
	check(PR.stars_of(data, SET, "ข") == 0, "one character's score is its own")


func test_bad_results() -> void:
	print("results that are not results:")
	var data := PR.empty()
	check(not PR.record(data, SET, "ก", 0), "zero stars is not a result to record")
	check(not PR.record(data, SET, "ก", -2), "nor is a negative one")
	check(PR.stars_of(data, SET, "ก") == 0, "and neither leaves a trace")
	check(not PR.record(data, "", "ก", 3), "a result with no set is refused")
	check(not PR.record(data, SET, "", 3), "a result with no character is refused")
	PR.record(data, SET, "ก", 99)
	check(PR.stars_of(data, SET, "ก") == SC.MAX_STARS,
			"more stars than exist is clamped to %d" % SC.MAX_STARS)
	check(PR.mastered_stars() == SC.stars_for(1.0),
			"\"mastered\" is asked of the scorer, not written down twice")


func test_corrupt_file() -> void:
	print("a file that cannot be read:")
	_write_raw("{\"version\": 1, \"sets\": {\"thai_consonants\": {\"ก\":")
	var loaded := PR.load_progress()
	check(not loaded.ok, "a truncated file is reported")
	check(not String(loaded.error).is_empty(), "with something an adult can read")
	check((loaded["data"]["sets"] as Dictionary).is_empty(),
			"and still hands back an empty progress dictionary, never nothing")

	_write_raw("[1, 2, 3]")
	loaded = PR.load_progress()
	check(not loaded.ok, "so is a file of the wrong shape")
	check((loaded["data"]["sets"] as Dictionary).is_empty(), "with the same empty start")

	# The way out of a broken file: the next star written replaces it.
	var result := PR.record_and_save(SET, "ก", 2)
	check(result.improved, "the next result is still recorded")
	check(PR.load_progress().ok, "and the file is readable again")
	check(PR.stars_of(PR.load_progress()["data"], SET, "ก") == 2,
			"a corrupt file costs the old stars, never the app")


func test_junk_contents() -> void:
	print("a file somebody has edited:")
	_write_raw(JSON.stringify({
		"version": 1,
		"sets": {
			SET: {"ก": 3, "ข": "three", "ค": 9, "ฅ": 0, "": 2},
			OTHER_SET: "not a set",
			"7": {"1": 1},
		},
	}))
	var loaded := PR.load_progress()
	check(loaded.ok, "well-formed JSON with odd contents still loads")
	var data: Dictionary = loaded["data"]
	check(PR.stars_of(data, SET, "ก") == 3, "the rows that make sense are kept")
	check(PR.stars_of(data, SET, "ข") == 0, "a star count that is not a number is dropped")
	check(PR.stars_of(data, SET, "ค") == SC.MAX_STARS, "one that is too big is clamped")
	check(PR.stars_of(data, SET, "ฅ") == 0, "a zero is not a result")
	check(not (data["sets"] as Dictionary).has(OTHER_SET),
			"a set that is not a set is dropped, not crashed on")
	check((data["sets"] as Dictionary).has("7"),
			"an unknown set id is kept — it may be a set this build has not got")
	check(PR.summary(data, OTHER_SET)["stars"] == 0,
			"and the sets that survived are still countable")


func test_merge() -> void:
	print("merging two histories:")
	var monday := PR.empty()
	PR.record(monday, SET, "ก", 3)
	PR.record(monday, SET, "ข", 1)
	var tuesday := PR.empty()
	PR.record(tuesday, SET, "ข", 3)
	PR.record(tuesday, OTHER_SET, "4", 2)
	var both := PR.merge(monday, tuesday)
	check(PR.stars_of(both, SET, "ก") == 3, "a character only one side has is kept")
	check(PR.stars_of(both, SET, "ข") == 3, "a character both have keeps the better")
	check(PR.stars_of(both, OTHER_SET, "4") == 2, "and so are whole sets")
	check(PR.merge(tuesday, monday) == both, "the order of the two makes no difference")
	check(PR.stars_of(monday, SET, "ข") == 1 and PR.stars_of(tuesday, SET, "ก") == 0,
			"neither original is modified")


func test_summary() -> void:
	print("how a set stands:")
	var data := PR.empty()
	PR.record(data, SET, "ก", 3)
	PR.record(data, SET, "ข", 3)
	PR.record(data, SET, "ค", 1)
	var summary := PR.summary(data, SET)
	check(int(summary["total"]) == CS.chars_of(SET).size(),
			"the total is the catalog's, not the file's")
	check(int(summary["traced"]) == 3, "three characters written (got %s)" % summary["traced"])
	check(int(summary["mastered"]) == 2, "two of them at full stars")
	check(int(summary["stars"]) == 7, "seven stars in the set")
	check(int(summary["possible"]) == CS.chars_of(SET).size() * SC.MAX_STARS,
			"and what the whole set would be worth")
	check(PR.total_stars(data) == 7, "which is the whole total so far")
	var untouched := PR.summary(data, OTHER_SET)
	check(int(untouched["traced"]) == 0 and int(untouched["stars"]) == 0,
			"a set nobody has opened reads as empty, not as an error")
	check(int(PR.summary(data, "thai_vowels")["total"]) == 0,
			"and a set with no characters yet has nothing to write")


func test_record_and_save() -> void:
	print("the round trip the tracing scene makes:")
	_remove_scratch()
	var first := PR.record_and_save(SET, "ง", 2)
	check(first.ok and first.improved, "a first result is written")
	check(int(first.stars) == 2, "and reported back")
	check(PR.stars_of(PR.load_progress()["data"], SET, "ง") == 2, "it is on disk")
	var worse := PR.record_and_save(SET, "ง", 1)
	check(worse.ok and not worse.improved, "a worse result is not an improvement")
	check(int(worse.stars) == 2, "and the best is what comes back")
	check(PR.stars_of(PR.load_progress()["data"], SET, "ง") == 2,
			"the file still holds the better score")
	var better := PR.record_and_save(SET, "ง", 3)
	check(better.improved and PR.stars_of(PR.load_progress()["data"], SET, "ง") == 3,
			"a better one goes through to the file")
	PR.record_and_save(OTHER_SET, "1", 1)
	check(PR.stars_of(PR.load_progress()["data"], SET, "ง") == 3,
			"and recording a second character keeps the first")


func test_clear() -> void:
	print("starting again:")
	check(PR.clear().ok, "progress can be thrown away")
	var loaded := PR.load_progress()
	check(loaded.ok and (loaded["data"]["sets"] as Dictionary).is_empty(),
			"leaving a readable, empty file")


func test_real_progress_untouched() -> void:
	print("the real thing:")
	check(PR.path == PR.DEFAULT_PATH, "the path seam is put back where it was")
	var real := PR.DEFAULT_PATH
	var same := (not FileAccess.file_exists(real)) if _real_sha.is_empty() \
			else (FileAccess.file_exists(real) and FileAccess.get_sha256(real) == _real_sha)
	check(same, "the stars actually earned in %s were never touched" % real)


# --- scratch file ------------------------------------------------------------

func _fingerprint_real_progress() -> void:
	if FileAccess.file_exists(PR.DEFAULT_PATH):
		_real_sha = FileAccess.get_sha256(PR.DEFAULT_PATH)


func _remove_scratch() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


## Write the file behind progress.gd's back — the only way to test what it does
## with something it did not write.
func _write_raw(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(SCRATCH.get_base_dir()))
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
