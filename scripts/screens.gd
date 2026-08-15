class_name Screens
extends RefCounted
## Which screen is on the display, and what happens between them — Step 7.
##
## Three screens, and the way through them is one direction with a way back:
##
##     main menu  ──set──▶  character select  ──character──▶  tracing
##          ◀── back ──          ◀── back ──
##
## The whole of that is here rather than spread through the three scenes, for
## two reasons. Each screen otherwise has to know what comes next, which makes
## three scenes that cannot be opened on their own. And the tracing scene is
## deliberately stateless — it emits `scored` and forgets — so *something* has
## to be listening in order to write the stars down. That listener lives here,
## which means it is wired the same way whether the child came from the menu or
## the scene was launched straight from the command line.
##
## Scenes are swapped by hand (instantiate → free the old one → add → set
## current_scene) rather than with change_scene_to_file, because a screen needs
## its subject set *before* it enters the tree: which set to show, which
## character to trace. The swap is deferred, so calling it from a button's own
## pressed signal is safe — the old screen is not freed underneath the button
## that is still emitting.

const CS := preload("res://scripts/char_sets.gd")
const PR := preload("res://scripts/progress.gd")

const MAIN_MENU := "res://scenes/main_menu.tscn"
const CHARACTER_SELECT := "res://scenes/character_select.tscn"
const TRACING := "res://scenes/tracing.tscn"
const FONT_TEST := "res://scenes/font_test.tscn"
const RECORDER := "res://scenes/stroke_recorder.tscn"


## The set menu — the app's home, and where "back" eventually leads.
static func go_menu(tree: SceneTree) -> void:
	go(tree, MAIN_MENU, func(screen: Node) -> void:
			screen.set_chosen.connect(func(set_id: String) -> void:
					go_chars(tree, set_id)))


## The grid of characters in one set.
static func go_chars(tree: SceneTree, set_id: String) -> void:
	go(tree, CHARACTER_SELECT, func(screen: Node) -> void:
			screen.show_set(set_id)
			screen.char_chosen.connect(func(chosen_set: String, chr: String) -> void:
					go_trace(tree, chosen_set, chr))
			screen.back_requested.connect(func() -> void: go_menu(tree)))


## The tracing scene, on one character. With no arguments it opens the first
## character of the first recorded set — that is the `-- --tracing` route, which
## has no menu behind it to have chosen anything.
static func go_trace(tree: SceneTree, set_id: String = "", chr: String = "") -> void:
	var id := set_id
	if id.is_empty():
		var ids := CS.recordable_ids()
		id = ids[0] if not ids.is_empty() else ""
	var chars := CS.chars_of(id)
	var character := chr
	if character.is_empty() and not chars.is_empty():
		character = chars[0]
	go(tree, TRACING, func(screen: Node) -> void:
			screen.open(id, character)
			screen.scored.connect(record_result)
			screen.back_requested.connect(func(from_set: String) -> void:
					go_chars(tree, from_set)))


## Write a result to user://progress.json, keeping the best. Connected to the
## tracing scene's `scored` signal; static and standing alone so a test can call
## it directly. A file that cannot be written costs the child a star and an
## adult a console line — it never reaches the screen.
static func record_result(set_id: String, chr: String, stars: int) -> void:
	var result := PR.record_and_save(set_id, chr, stars)
	if not result.ok:
		push_error("[screens] cannot record %s %s: %s" % [set_id, chr, result.error])
	elif result.improved:
		print("[screens] %s \"%s\" — best is now %d star(s)" % [set_id, chr, result.stars])


## Put `path` on screen, calling `setup` on the new scene before it enters the
## tree. Deferred: safe to call from a signal emitted by the screen it replaces.
static func go(tree: SceneTree, path: String, setup: Callable = Callable()) -> void:
	_swap.call_deferred(tree, path, setup)


static func _swap(tree: SceneTree, path: String, setup: Callable) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[screens] cannot load %s" % path)
		return
	var screen := packed.instantiate()
	if setup.is_valid():
		# Before add_child, so a screen knows its subject by the time _ready
		# runs and never shows the wrong set for a frame.
		setup.call(screen)
	# Freed rather than queued: two screens alive at once would both draw and
	# both take touches for a frame, and the deferred call is already the safe
	# moment the queue would have waited for.
	var old := tree.current_scene
	if old != null:
		tree.root.remove_child(old)
		old.free()
	tree.root.add_child(screen)
	tree.current_scene = screen
