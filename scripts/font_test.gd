extends Control
## Step 1 font/touch smoke-test scene.
## Verifies looped Thai rendering and that real touches arrive as
## InputEventScreenTouch (printed to console and mirrored on screen).

@onready var touch_status: Label = $VBox/TouchStatus


func _ready() -> void:
	touch_status.text = "Touch the screen with a finger… (Esc quits)"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var phase := "down" if event.pressed else "up"
		print("InputEventScreenTouch (%s) index=%d pos=%s" % [phase, event.index, event.position])
		touch_status.text = "InputEventScreenTouch %s at %s (finger %d)" % [phase, event.position.round(), event.index]
	elif event is InputEventScreenDrag:
		print("InputEventScreenDrag index=%d pos=%s" % [event.index, event.position])
		touch_status.text = "InputEventScreenDrag at %s (finger %d)" % [event.position.round(), event.index]
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
