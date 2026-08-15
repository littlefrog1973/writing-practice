extends SceneTree
## Dataset check for the recorded strokes in data/strokes/.
## Run: godot --headless --path . --script tests/validate_dataset.gd
## Exits 0 when the dataset is trustworthy, 1 when anything failed.
##
## Unlike the test suites this checks *data*, not code, so it is the tool to run
## after a recording batch — and the one Step 8 uses to know the dataset is
## finished. Warnings (very short strokes) are printed but do not fail the run.
##
## Pass a set id to see which characters of that set are still missing:
##   godot --headless --path . --script tests/validate_dataset.gd -- --missing digits

const CS := preload("res://scripts/char_sets.gd")
const SD := preload("res://scripts/stroke_data.gd")
const DV := preload("res://scripts/dataset_validator.gd")


func _init() -> void:
	var result: Dictionary = DV.validate_all()

	print("dataset: %s (%d stroke file%s)"
			% [CS.stroke_dir, result.files, "" if result.files == 1 else "s"])

	print("\ncoverage:")
	var recorded_total := 0
	var chars_total := 0
	for set_info: Dictionary in result.coverage:
		recorded_total += set_info.recorded
		chars_total += set_info.total
		var note := ""
		if set_info.total == 0:
			note = "  (empty in the catalog — filled in Step 8)"
		elif set_info.recorded == set_info.total:
			note = "  complete"
		print("  %-16s %3d/%-3d%s" % [set_info.id, set_info.recorded, set_info.total, note])
	print("  %-16s %3d/%-3d" % ["TOTAL", recorded_total, chars_total])

	if not result.warnings.is_empty():
		print("\n%d warning%s (allowed):"
				% [result.warnings.size(), "" if result.warnings.size() == 1 else "s"])
		for warning in result.warnings:
			print("  WARN  %s" % warning)

	if not result.problems.is_empty():
		print("\n%d problem%s:"
				% [result.problems.size(), "" if result.problems.size() == 1 else "s"])
		for problem in result.problems:
			print("  FAIL  %s" % problem)

	_print_missing()

	print("")
	if result.ok:
		print("DATASET OK — %d of %d characters recorded." % [recorded_total, chars_total])
	else:
		print("DATASET INVALID — %d problem%s to fix."
				% [result.problems.size(), "" if result.problems.size() == 1 else "s"])
	quit(0 if result.ok else 1)


## `--missing <set id>` lists the characters of that set with no entry yet, so a
## recording session knows exactly what is left.
func _print_missing() -> void:
	var args := OS.get_cmdline_user_args()
	var index := Array(args).find("--missing")
	if index == -1:
		return
	if index + 1 >= args.size():
		print("\n--missing needs a set id, one of: %s" % ", ".join(CS.recordable_ids()))
		return
	var id: String = args[index + 1]
	if not CS.has_set(id):
		print("\nUnknown set \"%s\". Known sets: %s" % [id, ", ".join(CS.SET_IDS)])
		return

	var recorded: Dictionary = {}
	var loaded: Dictionary = SD.load_set(CS.path_of(id))
	if loaded.ok:
		for entry: Dictionary in loaded.entries:
			recorded[entry["char"]] = true
	var missing := PackedStringArray()
	for chr in CS.chars_of(id):
		if not recorded.has(chr):
			missing.append(chr)

	print("\nstill to record in %s (%d):" % [CS.label_of(id), missing.size()])
	print("  %s" % (" ".join(missing) if not missing.is_empty() else "— nothing, this set is done"))
