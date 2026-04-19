extends CanvasLayer

@onready var weapons_label = $MarginContainer/VBoxContainer/HBoxContainer/WeaponsBox/Label
@onready var passives_label = $MarginContainer/VBoxContainer/HBoxContainer/PassivesBox/Label
@onready var ultimate_label = $MarginContainer/VBoxContainer/HBoxContainer/UltimateBox/Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var res_btn = $MarginContainer/VBoxContainer/Buttons/ResumeButton
	var quit_btn = $MarginContainer/VBoxContainer/Buttons/QuitButton
	res_btn.pressed.connect(_on_resume_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _process(_delta: float) -> void:
	if visible:
		_refresh_data()

func _refresh_data() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
		
	# Weapons
	var w_text = "[font_size=24][color=#ffd700]Weapons[/color][/font_size]\n\n"
	var mgr = player.get_node_or_null("WeaponManager")
	if mgr:
		for w in mgr.equipped_weapons:
			var w_data = WeaponDB.WEAPONS.get(w["id"], {})
			var w_name = w_data.get("name", "Unknown")
			var level = w.get("level", 1)
			var max_lv = w_data.get("max_level", 12)
			if level >= max_lv:
				w_text += "• %s [color=#44ff44]MAX[/color]\n" % w_name
			else:
				w_text += "• %s [color=#aaaaaa](Lv.%d)[/color]\n" % [w_name, level]
	weapons_label.text = w_text
	
	# Passives
	var p_text = "[font_size=24][color=#00d7ff]Passives[/color][/font_size]\n\n"
	if player.active_passives.size() == 0:
		p_text += "[color=#666666]No passives equipped.[/color]\n"
	else:
		for pid in player.active_passives:
			var p_data = PassiveDB.PASSIVES.get(pid, {})
			var p_name = p_data.get("name", "Unknown")
			var desc = p_data.get("desc", "")
			p_text += "• %s\n  [color=#999999][font_size=14]%s[/font_size][/color]\n\n" % [p_name, desc]
	passives_label.text = p_text
	
	# Ultimate
	var u_text = "[font_size=24][color=#ff3366]Ultimate[/color][/font_size]\n\n"
	var u_id = player._ultimate_id
	if u_id == "temporal_shift":
		u_text += "Temporal Shift\n[color=#999999][font_size=14]Slows time and grants invincibility.[/font_size][/color]"
	elif u_id == "aegis":
		u_text += "Aegis Shield\n[color=#999999][font_size=14]Absorbs 200 damage instantly.[/font_size][/color]"
	elif u_id == "sniper_mode":
		u_text += "Sniper Mode\n[color=#999999][font_size=14]Next 8 shots deal 5x damage.[/font_size][/color]"
	else:
		u_text += u_id
	ultimate_label.text = u_text

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_quit_pressed() -> void:
	GameManager.quit_run()
