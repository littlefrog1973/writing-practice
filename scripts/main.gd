extends Node
## Boot router: picks the scene to start from the command line.
##
##   godot --path .                  → the font/touch smoke test (later: main menu)
##   godot --path . -- --tracing     → the tracing scene (demo + trace)
##   godot --path . -- --recorder    → the Stroke Recorder authoring tool
##   godot --path . -- --recorder --mouse
##                                   → same, but the mouse also draws (desktop dev
##                                     only; never enabled for the real app, so
##                                     real touch handling is never masked)
##
## `--tracing` exists because the menus that would lead to that scene are not
## built until Step 7; it starts on the first character and has its own
## next/previous buttons.
##
## Note the bare `--`: everything after it lands in OS.get_cmdline_user_args().

const RECORDER_SCENE := "res://scenes/stroke_recorder.tscn"
const TRACING_SCENE := "res://scenes/tracing.tscn"
const FONT_TEST_SCENE := "res://scenes/font_test.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--mouse"):
		Input.emulate_touch_from_mouse = true
		print("[main] --mouse: mouse events are emulated as touch (dev only)")
	var scene := FONT_TEST_SCENE
	if args.has("--recorder"):
		scene = RECORDER_SCENE
	elif args.has("--tracing"):
		scene = TRACING_SCENE
	print("[main] starting %s" % scene)
	# One frame of breathing room: swapping the scene from inside _ready() runs
	# while the tree is still busy adding this node.
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(scene)
	if err != OK:
		push_error("[main] cannot load %s: %s" % [scene, error_string(err)])
