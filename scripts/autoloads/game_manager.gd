extends Node

# Autoloads are never freed — they persist for entire game session

func _ready() -> void:
	# Add self to group so player can call us without a direct reference
	add_to_group("game_manager")

func on_player_died() -> void:
	# Brief pause before showing game over
	# get_tree().paused freezes all _process and _physics_process calls
	get_tree().paused = true
	
	# Load and show the Game Over screen
	var game_over_scene = load("res://scenes/ui/game_over.tscn")
	var game_over = game_over_scene.instantiate()
	
	# Add to root so it renders above everything, unaffected by pause
	get_tree().root.add_child(game_over)

func on_game_won() -> void:
	get_tree().paused = true
	var win_label = Label.new()
	win_label.text = "YOU WIN! BOSS DEFEATED!"
	win_label.add_theme_font_size_override("font_size", 64)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var canvas = CanvasLayer.new()
	canvas.add_child(win_label)
	get_tree().root.add_child(canvas)
