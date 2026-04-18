extends CanvasLayer

func _ready() -> void:
	# Find the button by node path and connect its pressed signal
	$Button.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	# Unpause before reloading — otherwise the new scene starts frozen
	get_tree().paused = false
	queue_free()  # destroy this screen first, THEN reload
	# Reload the current scene from scratch — full clean state
	get_tree().reload_current_scene()
