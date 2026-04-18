extends CanvasLayer

@onready var timer_label = $MarginContainer/VBoxContainer/HBoxContainer/TimerLabel
@onready var health_bar = $MarginContainer/VBoxContainer/HBoxContainer/HealthBar
@onready var xp_bar = $MarginContainer/VBoxContainer/HBoxContainer/LevelContainer/XPBar
@onready var level_label = $MarginContainer/VBoxContainer/HBoxContainer/LevelContainer/LevelLabel

var time_elapsed: float = 0.0
var draft_panel: PanelContainer = null

func _ready() -> void:
	# Keep running during Level Up pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.xp_changed.connect(_on_player_xp_changed)

func show_draft_menu() -> void:
	get_tree().paused = true
	
	if draft_panel != null:
		draft_panel.queue_free()
		
	draft_panel = PanelContainer.new()
	draft_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(draft_panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	draft_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "LEVEL UP! CHOOSE AN UPGRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var options = generate_draft_options()
	for opt in options:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(250, 300)
		
		var text = ""
		if opt["type"] == "weapon":
			text = "WEAPON\n\n" + opt["data"]["name"] + "\n\nLevel " + str(opt["level"])
		else:
			text = "STAT UP\n\n" + opt["stat_name"]
			
		btn.text = text
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func(): _on_draft_selected(opt))
		hbox.add_child(btn)

func generate_draft_options() -> Array:
	var options = []
	var player = get_tree().get_first_node_in_group("player")
	var internal_manager = player.get_node("WeaponManager") if player else null
	var equipped = []
	if internal_manager: equipped = internal_manager.equipped_weapons
	
	var pool = []
	var equipped_ids = []
	for w in equipped:
		equipped_ids.append(w["id"])
		if w["level"] < WeaponDB.WEAPONS[w["id"]].get("max_level", 12):
			pool.append({"type": "weapon", "id": w["id"], "data": WeaponDB.WEAPONS[w["id"]], "level": w["level"] + 1})
			
	if equipped.size() < 6:
		for key in WeaponDB.WEAPONS.keys():
			if not equipped_ids.has(key):
				pool.append({"type": "weapon", "id": key, "data": WeaponDB.WEAPONS[key], "level": 1})
				
	pool.shuffle()
	
	for i in range(min(3, pool.size())):
		options.append(pool[i])
		
	var stats = [
		{"type": "stat", "stat_id": "max_health", "stat_name": "Max Health +50"},
		{"type": "stat", "stat_id": "speed", "stat_name": "Move Speed +20"},
		{"type": "stat", "stat_id": "heal", "stat_name": "Heal 50% HP"}
	]
	
	while options.size() < 4:
		options.append(stats.pick_random())
		
	options.shuffle()
	return options

func _on_draft_selected(opt: Dictionary) -> void:
	draft_panel.queue_free()
	draft_panel = null
	
	var player = get_tree().get_first_node_in_group("player")
	if opt["type"] == "weapon":
		var manager = player.get_node("WeaponManager")
		manager.add_weapon(opt["id"])
	elif opt["type"] == "stat":
		if opt["stat_id"] == "max_health":
			player.max_health += 50.0
			player.current_health += 50.0
		elif opt["stat_id"] == "speed":
			player.move_speed += 20.0
		elif opt["stat_id"] == "heal":
			player.current_health += player.max_health * 0.5
			if player.current_health > player.max_health:
				player.current_health = player.max_health
		player.health_changed.emit(player.current_health, player.max_health)
		
	get_tree().paused = false

func _process(delta: float) -> void:
	time_elapsed += delta
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_player_xp_changed(current: int, maximum: int, level: int) -> void:
	xp_bar.max_value = maximum
	xp_bar.value = current
	level_label.text = "Level: %d" % level
