extends Node
## Boot router: picks the screen to start from the command line.
##
##   godot --path .                  → the main menu (the app proper)
##   godot --path . -- --tracing     → straight into tracing, first character
##   godot --path . -- --recorder    → the Stroke Recorder authoring tool
##   godot --path . -- --fonts       → the Step 1 font/touch smoke test
##   godot --path . -- --tracing --mouse
##                                   → …with the mouse drawing as a finger
##                                     (desktop dev only; never enabled for the
##                                     real app, so real touch handling is never
##                                     masked)
##
## Every route goes through screens.gd rather than change_scene_to_file, so a
## scene started from the command line is wired up exactly as the menu would
## have wired it — `--tracing` records stars in user://progress.json and its
## "back" button reaches the character grid, with nothing special about it.
##
## Note the bare `--`: everything after it lands in OS.get_cmdline_user_args().

const SNS := preload("res://scripts/screens.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--mouse"):
		Input.emulate_touch_from_mouse = true
		print("[main] --mouse: mouse events are emulated as touch (dev only)")
	# One frame of breathing room: swapping the scene from inside _ready() runs
	# while the tree is still busy adding this node.
	await get_tree().process_frame
	if args.has("--recorder"):
		print("[main] starting the stroke recorder")
		SNS.go(get_tree(), SNS.RECORDER)
	elif args.has("--fonts"):
		print("[main] starting the font/touch smoke test")
		SNS.go(get_tree(), SNS.FONT_TEST)
	elif args.has("--tracing"):
		print("[main] starting the tracing scene")
		SNS.go_trace(get_tree())
	else:
		print("[main] starting the main menu")
		SNS.go_menu(get_tree())
