extends SceneTree
## GATE 3 test suite for scripts/char_sets.gd (the character catalog) and the
## stroke files it points at.
## Run: godot --headless --path . --script tests/test_char_sets.gd
## Exits 0 when every check passes, 1 otherwise.

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const DV := preload("res://scripts/dataset_validator.gd")

var failures := 0
var checks := 0


func _init() -> void:
	test_integrity()
	test_expected_contents()
	test_lookups()
	test_stroke_files_match_catalog()
	test_validator_catches_bad_entries()
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


func test_integrity() -> void:
	print("catalog integrity:")
	var result: Dictionary = CS.validate()
	check(result.ok, "validate() passes (error: %s)" % result.get("error", ""))
	check(CS.all().size() == CS.SET_IDS.size(), "every listed set is built")
	for id in CS.SET_IDS:
		var set_def: Dictionary = CS.get_set(id)
		check(set_def.get("id", "") == id, "set \"%s\" knows its own id" % id)


func test_expected_contents() -> void:
	print("expected set contents:")
	check(CS.chars_of("thai_consonants").size() == 44,
			"44 Thai consonants (got %d)" % CS.chars_of("thai_consonants").size())
	check(CS.chars_of("english_upper").size() == 26, "26 capitals")
	check(CS.chars_of("english_lower").size() == 26, "26 small letters")
	check(CS.chars_of("digits").size() == 10, "10 digits")
	check(CS.chars_of("thai_numerals").size() == 10, "10 Thai numerals")
	check(CS.chars_of("thai_consonants")[0] == "ก" and CS.chars_of("thai_consonants")[43] == "ฮ",
			"Thai consonants run ก … ฮ")
	check(CS.chars_of("english_upper")[0] == "A" and CS.chars_of("english_upper")[25] == "Z",
			"capitals run A … Z")
	check(CS.chars_of("thai_numerals")[0] == "๐", "Thai numerals start at ๐")
	check(CS.chars_of("thai_vowels").is_empty() and CS.is_combining("thai_vowels"),
			"thai_vowels is an empty combining stub (filled in Step 8)")
	check(not CS.recordable_ids().has("thai_vowels")
			and CS.recordable_ids().size() == CS.SET_IDS.size() - 1,
			"recordable_ids() skips empty sets only")


func test_lookups() -> void:
	print("lookups:")
	check(CS.name_of("thai_consonants", "ก") == "ก ไก่", "acrophony for ก")
	check(CS.name_of("thai_consonants", "ฮ") == "ฮ นกฮูก", "acrophony for ฮ")
	check(CS.name_of("digits", "1") == "one", "digit name")
	check(CS.name_of("english_upper", "A") == "A", "letter names are the letter")
	check(CS.name_of("digits", "!") == "!", "unknown character falls back to itself")
	check(CS.font_of("thai_consonants") == CS.FONT_THAI
			and CS.font_of("english_upper") == CS.FONT_LATIN, "fonts assigned per script")
	check(CS.path_of("digits") == "res://data/strokes/digits.json", "stroke path per set")
	check(CS.get_set("nope").is_empty() and not CS.has_set("nope"), "unknown set id is empty")


## The per-entry rules live in scripts/dataset_validator.gd (one definition,
## also runnable on its own as tests/validate_dataset.gd); this only asserts
## that the shipped files satisfy them.
func test_stroke_files_match_catalog() -> void:
	print("existing stroke files agree with the catalog:")
	for id in CS.SET_IDS:
		var path: String = CS.path_of(id)
		if not FileAccess.file_exists(path):
			continue
		var result: Dictionary = SD.load_set(path)
		check(result.ok, "%s loads (error: %s)" % [path, result.get("error", "")])
		if not result.ok:
			continue
		var problems: PackedStringArray = DV.check_entries(id, result.entries, path).problems
		check(problems.is_empty(), "%s entries pass the dataset validator%s"
				% [path, "" if problems.is_empty() else " — " + problems[0]])


## Guards the validator itself: the rules the suite above leans on must actually
## reject bad data, or it would pass on anything.
func test_validator_catches_bad_entries() -> void:
	print("the dataset validator rejects bad entries:")
	var good := PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.8, 0.8)])

	var wrong_set := [SD.make_entry("A", "digits", "A", [good])]
	check(not DV.check_entries("english_upper", wrong_set).problems.is_empty(),
			"an entry filed under the wrong set")

	var alien := [SD.make_entry("Z", "digits", "Z", [good])]
	check(not DV.check_entries("digits", alien).problems.is_empty(),
			"a character that is not in the set")

	var misnamed := [SD.make_entry("1", "digits", "wun", [good])]
	check(not DV.check_entries("digits", misnamed).problems.is_empty(),
			"a name that disagrees with the catalog")

	var one_point := [SD.make_entry("1", "digits", "one", [PackedVector2Array([Vector2(0.5, 0.5)])])]
	check(not DV.check_entries("digits", one_point).problems.is_empty(),
			"a stroke of a single point")

	var no_strokes := [SD.make_entry("1", "digits", "one", [])]
	check(not DV.check_entries("digits", no_strokes).problems.is_empty(),
			"an entry with no strokes at all")

	var outside := [SD.make_entry("1", "digits", "one",
			[PackedVector2Array([Vector2(0.5, 0.5), Vector2(1.4, -0.2)])])]
	check(not DV.check_entries("digits", outside).problems.is_empty(),
			"a point outside the 0–1 box")

	var twice := [SD.make_entry("1", "digits", "one", [good]),
			SD.make_entry("1", "digits", "one", [good])]
	check(not DV.check_entries("digits", twice).problems.is_empty(),
			"the same character recorded twice in one file")

	var dot := PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.501, 0.501)])
	var tap := DV.check_entries("digits", [SD.make_entry("1", "digits", "one", [good, dot])])
	check(tap.problems.is_empty() and tap.warnings.size() == 1,
			"a dot is warned about but allowed (the dot on an \"i\")")

	var clean := [SD.make_entry("1", "digits", "one", [good])]
	var result: Dictionary = DV.check_entries("digits", clean)
	check(result.problems.is_empty() and result.warnings.is_empty(),
			"a good entry passes clean")
